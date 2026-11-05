-- Camera: primeira pessoa dinâmica (balanço por passo, tremores, FOV) e tecla V para terceira pessoa. Dono: P2.
-- Fórmulas em Regras/Camera. Lê Agachado/Correndo/Pref_* do jogador; nunca decide valor de jogo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Config = Shared:WaitForChild("Config")
local ConfigCamera = require(Config:WaitForChild("Camera"))
local Teclas = require(script.Parent.Teclas)
local ConfigMovimento = require(Config:WaitForChild("Movimento"))
local ConfigSom = require(Config:WaitForChild("Som"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Camera"))

local Camera = {}

local VELOCIDADE_MIN_MOVENDO = 1 -- studs/s horizontais para contar como andando
local SUAVIZAR_BALANCO = 8 -- 1/s: rapidez com que o balanço entra e sai ao começar/parar
local SUAVIZAR_AGACHAR = 10 -- 1/s: rapidez da descida da câmera ao agachar
local TREMOR_MINIMO = 0.01 -- studs; abaixo disso nem entra na lista
local TREMOR_MAXIMO = 1 -- studs; teto da soma dos tremores
local VARREDURA_CACA = 0.25 -- s (4 Hz)
local ESTADOS_CACA = { Caca = true, ["Caça"] = true } -- §3 usa "Caca"; calculos.md escreve "Caça"

local jogador = Players.LocalPlayer
local camera = workspace.CurrentCamera

local fase = 0
local balanco = 0 -- 0..1: quanto do balanço está ativo (suaviza começar/parar)
local modoBalanco = "andar" -- último modo andando, para o balanço sair no mesmo ritmo em que entrou
local deslocAgachado = 0 -- offset Y atual da altura dos olhos
local fovAtual: number? = nil
local velocidadeQueda = 0
local cacando = false
local ultimaVarredura = 0
local terceiraPessoa = false
local zoomOriginal = { min = 0.5, max = 128 }

local tremores: { { amplitude: number, inicio: number, duracao: number } } = {}

-- Coice de arma: o alvo sobe na hora a cada tiro (graus) e decai; o valor aplicado acompanha o alvo rápido. É só um
-- deslocamento visual por cima da câmera do Roblox (que não sabe de coice); a mira real é a câmera já deslocada.
local COICE_SEGUE = 45 -- 1/s: rapidez com que a câmera acompanha o alvo (subida seca)
local COICE_RECUPERA = 7 -- 1/s: rapidez com que o alvo volta a zero (graus que ficam entre tiros seguidos)
local COICE_MAXIMO = 14 -- graus: teto do acúmulo vertical em rajada
local coiceAlvoV, coiceAlvoH = 0, 0
local coiceV, coiceH = 0, 0

-- Pode ser chamada por outras partes (ex.: coice de arma). Respeita as preferências no momento de aplicar.
function Camera.tremer(amplitude: number, duracao: number)
	if amplitude < TREMOR_MINIMO or duracao <= 0 then
		return
	end
	table.insert(tremores, { amplitude = amplitude, inicio = os.clock(), duracao = duracao })
end

-- Respeita Pref_Tremor/Pref_Intensidade (e some na 3ª pessoa) no momento do tiro. vertical > 0 sobe; horizontal > 0 vira
-- para a esquerda (rotação em Y positiva). Chamada pelo ArmasCliente a cada tiro previsto.
function Camera.coice(vertical: number, horizontal: number)
	local ligado, intensidade = jogador:GetAttribute("Pref_Tremor") ~= false, jogador:GetAttribute("Pref_Intensidade")
	if type(intensidade) ~= "number" then
		intensidade = ConfigCamera.preferenciasPadrao.Pref_Intensidade
	end
	if not ligado or intensidade <= 0 or terceiraPessoa then
		return
	end
	local k = intensidade / 100
	coiceAlvoV = math.min(coiceAlvoV + vertical * k, COICE_MAXIMO)
	coiceAlvoH = math.clamp(coiceAlvoH + horizontal * k, -COICE_MAXIMO, COICE_MAXIMO)
end

local function preferencias(): (boolean, number)
	local ligado = jogador:GetAttribute("Pref_Tremor") ~= false
	local intensidade = jogador:GetAttribute("Pref_Intensidade")
	if type(intensidade) ~= "number" then
		intensidade = ConfigCamera.preferenciasPadrao.Pref_Intensidade
	end
	return ligado, intensidade
end

-- Soma dos tremores ainda ativos (remove os vencidos).
local function tremorAtual(agora: number): number
	local total = 0
	for i = #tremores, 1, -1 do
		local t = tremores[i]
		local valor = Regras.tremor(t.amplitude, agora - t.inicio, t.duracao)
		if valor <= 0 then
			table.remove(tremores, i)
		else
			total += valor
		end
	end
	return total
end

local function varrerMonstros()
	cacando = false
	local pasta = workspace:FindFirstChild("Monstros")
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not pasta or not raiz or not raiz:IsA("BasePart") then
		return
	end
	local alcance = ConfigCamera.monstroCacando.distancia
	for _, monstro in pasta:GetChildren() do
		if monstro:IsA("Model") and ESTADOS_CACA[monstro:GetAttribute("Estado") :: any] then
			if (monstro:GetPivot().Position - raiz.Position).Magnitude <= alcance then
				cacando = true
				return
			end
		end
	end
end

local function alternarTerceiraPessoa()
	terceiraPessoa = not terceiraPessoa
	if terceiraPessoa then
		jogador.CameraMode = Enum.CameraMode.Classic
		jogador.CameraMinZoomDistance = ConfigCamera.terceiraPessoa.distancia
		jogador.CameraMaxZoomDistance = ConfigCamera.terceiraPessoa.distancia
	else
		jogador.CameraMaxZoomDistance = zoomOriginal.max
		jogador.CameraMinZoomDistance = zoomOriginal.min
		jogador.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

-- Usado pelo gancho de teste do Studio (init.client) além da tecla.
function Camera.alternar()
	alternarTerceiraPessoa()
end

local function aoAterrissar()
	local pref, intensidade = preferencias()
	if pref and intensidade > 0 then
		Camera.tremer(Regras.tremorAterrissagem(velocidadeQueda, ConfigCamera), ConfigCamera.aterrissagem.duracao)
	end
	velocidadeQueda = 0
end

local ligadoAoHumanoide: Humanoid? = nil
local conexaoEstado: RBXScriptConnection? = nil

-- StateChanged do Humanoid atual (muda a cada respawn).
local function seguirHumanoide(humanoide: Humanoid?)
	if humanoide == ligadoAoHumanoide then
		return
	end
	if conexaoEstado then
		conexaoEstado:Disconnect()
		conexaoEstado = nil
	end
	ligadoAoHumanoide = humanoide
	velocidadeQueda = 0
	if humanoide then
		conexaoEstado = humanoide.StateChanged:Connect(function(antigo, novo)
			if antigo == Enum.HumanoidStateType.Freefall and novo == Enum.HumanoidStateType.Landed then
				aoAterrissar()
			end
		end)
	end
end

local function passo(dt: number)
	local agora = os.clock()
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not humanoide or not raiz or not raiz:IsA("BasePart") then
		return
	end
	seguirHumanoide(humanoide)

	local cam = workspace.CurrentCamera
	if cam ~= camera then
		camera = cam
	end

	local velocidade = raiz.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z).Magnitude
	local noAr = humanoide.FloorMaterial == Enum.Material.Air
	if humanoide:GetState() == Enum.HumanoidStateType.Freefall then
		velocidadeQueda = math.max(velocidadeQueda, -velocidade.Y)
	end

	local morto = jogador:GetAttribute("Morto") == true or humanoide.Health <= 0
	local agachado = jogador:GetAttribute("Agachado") == true
	local correndo = jogador:GetAttribute("Correndo") == true
	local movendo = horizontal > VELOCIDADE_MIN_MOVENDO and not noAr and not morto
	local modo = Regras.modo(agachado, correndo, movendo)
	local tremorLigado, intensidade = preferencias()
	if not tremorLigado or terceiraPessoa or morto then
		intensidade = 0
	end

	-- Balanço: a fase só avança andando no chão; a amplitude entra e sai suave.
	if movendo then
		modoBalanco = modo
		local ritmo = ConfigSom.passosPorSegundo[modo] or ConfigSom.passosPorSegundo.andar
		fase = Regras.avancarFase(fase, ritmo, dt)
	end
	local alvoBalanco = if movendo then 1 else 0
	balanco += (alvoBalanco - balanco) * (1 - math.exp(-SUAVIZAR_BALANCO * dt))
	local dy, dx, roll = Regras.offset(fase, modoBalanco, intensidade, ConfigCamera)
	dy *= balanco
	dx *= balanco
	roll *= balanco

	-- Tremores: aterrissagem, golpe e coração acelerado (monstro em caça por perto).
	local amplitude = tremorAtual(agora)
	if cacando then
		amplitude += ConfigCamera.monstroCacando.amplitude
	end
	local tx, ty = 0, 0
	if intensidade > 0 then
		amplitude = math.min(amplitude, TREMOR_MAXIMO) * intensidade / 100
		-- ruído suave em vez de random puro: evita estalos de quadro a quadro
		tx = math.noise(agora * 37, 1.7, 0) * 2 * amplitude
		ty = math.noise(agora * 37, 9.3, 0) * 2 * amplitude
	end

	-- Altura dos olhos agachado (não é tremor: continua com Pref_Tremor desligado).
	local alvoAgachado = if agachado and not morto then ConfigCamera.alturaOlhosAgachado else 0
	deslocAgachado += (alvoAgachado - deslocAgachado) * (1 - math.exp(-SUAVIZAR_AGACHAR * dt))

	humanoide.CameraOffset = Vector3.new(dx + tx, deslocAgachado + dy + ty, 0)
	if roll ~= 0 then
		cam.CFrame *= CFrame.Angles(0, 0, math.rad(roll))
	end

	-- Coice: alvo decai, o aplicado o segue. Tudo em graus; a câmera recebe o deslocamento depois do balanço.
	coiceAlvoV *= math.exp(-COICE_RECUPERA * dt)
	coiceAlvoH *= math.exp(-COICE_RECUPERA * dt)
	coiceV += (coiceAlvoV - coiceV) * (1 - math.exp(-COICE_SEGUE * dt))
	coiceH += (coiceAlvoH - coiceH) * (1 - math.exp(-COICE_SEGUE * dt))
	if math.abs(coiceV) > 0.001 or math.abs(coiceH) > 0.001 then
		cam.CFrame *= CFrame.Angles(math.rad(coiceV), math.rad(coiceH), 0)
	end

	-- FOV: Pref_FOV de base, +8 correndo; aproximação exponencial que fecha ~95% em transicaoFov.
	local base = jogador:GetAttribute("Pref_FOV")
	if type(base) ~= "number" then
		base = ConfigCamera.preferenciasPadrao.Pref_FOV
	end
	local alvoFov = Regras.fovAlvo(modo, base, ConfigCamera)
	local atual = fovAtual or alvoFov
	atual += (alvoFov - atual) * (1 - math.exp(-3 / ConfigCamera.transicaoFov * dt))
	fovAtual = atual
	cam.FieldOfView = atual

	if agora - ultimaVarredura >= VARREDURA_CACA then
		ultimaVarredura = agora
		varrerMonstros()
	end
end

function Camera.iniciar()
	zoomOriginal.min = jogador.CameraMinZoomDistance
	zoomOriginal.max = jogador.CameraMaxZoomDistance

	Rede.evento("Dano").OnClientEvent:Connect(function()
		local pref, intensidade = preferencias()
		if pref and intensidade > 0 then
			Camera.tremer(ConfigCamera.golpe.amplitude, ConfigCamera.golpe.duracao)
		end
	end)

	Teclas.ligar("terceiraPessoa", ConfigMovimento.teclas.terceiraPessoa, alternarTerceiraPessoa)

	-- Respawn: volta ao estado de partida (de pé, sem tremor pendente).
	jogador.CharacterAdded:Connect(function()
		table.clear(tremores)
		coiceAlvoV, coiceAlvoH, coiceV, coiceH = 0, 0, 0, 0
		fase = 0
		balanco = 0
		deslocAgachado = 0
		velocidadeQueda = 0
		cacando = false
	end)

	RunService:BindToRenderStep("CameraDinamica", Enum.RenderPriority.Camera.Value + 1, passo)
end

return Camera
