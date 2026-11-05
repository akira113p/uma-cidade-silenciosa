-- Filtro: orquestrador do filtro visual (referência Silent Hill). Contrato: docs/filtro.md §3.
-- Cria Ctx e Estado, inicia as camadas (pcall por camada), atualiza todas num BindToRenderStep depois da câmera,
-- cuida de preferências, pulsos (dano, susto, glitch) e qualidade automática por FPS.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Filtro = {}

local ORDEM = { "Ceu", "Neblina", "Lente", "Aberracao", "Postes", "Grao", "Moldura" }
-- Preferência própria de cada camada (as ausentes seguem só o filtro geral)
local PREF_CAMADA = { Aberracao = "Pref_Aberracao", Lente = "Pref_Lente", Neblina = "Pref_NeblinaVolume" }
local ESTADOS_CACA = { Caca = true, ["Caça"] = true }

type Camada = {
	nome: string,
	modulo: any,
	ligada: boolean?,
	quebrada: boolean,
}

local pulsos = { dano = 0, susto = 0, glitch = 0 }
local estado: any = {
	t = 0,
	dt = 0,
	noite = 0,
	clima = "limpo",
	fov = 70,
	interior = 0,
	primeiraPessoa = false,
	caca = 0,
	pulsos = pulsos,
	nivel = 3,
}
local iniciado = false

-- API pública: dispara um pulso 0..1. Dano soma (teto 1); susto e glitch ficam com o maior.
function Filtro.pulso(tipo: string, forca: number)
	local atual = pulsos[tipo]
	if atual == nil or type(forca) ~= "number" or forca ~= forca then
		return
	end
	forca = math.clamp(forca, 0, 1)
	if tipo == "dano" then
		pulsos.dano = math.min(1, atual + forca)
	else
		pulsos[tipo] = math.max(atual, forca)
	end
end

function Filtro.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	task.spawn(function()
		local ok, erro = pcall(Filtro._montar)
		if not ok then
			warn("[Filtro] falhou ao montar: " .. tostring(erro))
		end
	end)
end

function Filtro._montar()
	local jogador = Players.LocalPlayer
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local ConfigPasta = Shared:WaitForChild("Config")
	local config = require(ConfigPasta:WaitForChild("Filtro"))
	local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Filtro"))
	local geral = config.Geral
	local pg = jogador:WaitForChild("PlayerGui", 10)
	if not pg then
		warn("[Filtro] PlayerGui ausente")
		return
	end

	-- Regras/Luz é da parte S5; se faltar, noite fica 0
	local luzDaHora: ((number) -> number)? = nil
	local okLuz, Luz = pcall(function()
		return require(Shared:WaitForChild("Regras"):WaitForChild("Luz", 5))
	end)
	if okLuz and type(Luz) == "table" and Luz.luzDaHora then
		luzDaHora = Luz.luzDaHora
	else
		warn("[Filtro] Regras/Luz ausente: Estado.noite fica 0")
	end

	-- Preferências padrão: Config/Camera.preferenciasPadrao, com a tabela do Geral de reserva
	local prefPadrao: any = geral.prefPadrao
	local okCam, cfgCamera = pcall(function()
		return require(ConfigPasta:WaitForChild("Camera"))
	end)
	if okCam and type(cfgCamera) == "table" and type(cfgCamera.preferenciasPadrao) == "table" then
		prefPadrao = cfgCamera.preferenciasPadrao
	end
	local function pref(nome: string): boolean
		local v = jogador:GetAttribute(nome)
		if type(v) == "boolean" then
			return v
		end
		local p = prefPadrao[nome]
		if p == nil then
			p = geral.prefPadrao[nome]
		end
		return p ~= false
	end

	-- Ctx
	local function criarGui(nome: string, ordem: number): ScreenGui
		local gui = Instance.new("ScreenGui")
		gui.Name = nome
		gui.DisplayOrder = ordem
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = pg
		return gui
	end
	local camera = workspace.CurrentCamera
	local pastaMundo = Instance.new("Folder")
	pastaMundo.Name = "Filtro"
	pastaMundo.Parent = camera

	local emStudio = RunService:IsStudio()
	local cameraModulo: any = nil
	local ctx: any = {
		config = config,
		jogador = jogador,
		camera = camera,
		guiTela = criarGui("FiltroTela", 100),
		guiMundo = criarGui("FiltroMundo", -10),
		pastaMundo = pastaMundo,
		ajuste = function(chave: string, padrao: any): any
			if emStudio then
				local v = jogador:GetAttribute("Filtro_" .. chave)
				if v ~= nil then
					return v
				end
			end
			return padrao
		end,
		camera_tremer = function(amplitude: number, duracao: number)
			if not cameraModulo then
				local ok, m = pcall(require, script.Parent:WaitForChild("Camera"))
				cameraModulo = if ok then m else false
			end
			if cameraModulo and cameraModulo.tremer then
				cameraModulo.tremer(amplitude, duracao)
			end
		end,
	}

	-- Camadas
	local camadas: { Camada } = {}
	for _, nome in ORDEM do
		local arquivo = script:FindFirstChild(nome)
		if not arquivo then
			warn("[Filtro] camada ausente: " .. nome)
			continue
		end
		local okReq, modulo = pcall(require, arquivo)
		if not okReq then
			warn("[Filtro] erro ao carregar " .. nome .. ": " .. tostring(modulo))
			continue
		end
		local okIni, erroIni = pcall(modulo.iniciar, ctx)
		if not okIni then
			warn("[Filtro] erro ao iniciar " .. nome .. ": " .. tostring(erroIni))
			continue
		end
		table.insert(camadas, { nome = nome, modulo = modulo, ligada = nil, quebrada = false })
	end

	local function chamar(c: Camada, funcao: string, ...: any)
		if c.quebrada then
			return
		end
		local f = c.modulo[funcao]
		if type(f) ~= "function" then
			return
		end
		local ok, err = pcall(f, ...)
		if not ok then
			warn("[Filtro] " .. c.nome .. "." .. funcao .. " falhou, camada desligada: " .. tostring(err))
			c.quebrada = true
			if funcao ~= "ligar" then
				pcall(c.modulo.ligar, false)
			end
		end
	end

	-- Preferências: filtro geral + Lighting.Retro/Cor + preferência de cada camada
	local function aplicarPrefs()
		local geralLigado = pref("Pref_FiltroPS1")
		local retro = Lighting:FindFirstChild("Retro")
		local cor = Lighting:FindFirstChild("Cor")
		if retro and retro:IsA("ColorGradingEffect") then
			retro.Enabled = geralLigado
		end
		if cor and cor:IsA("ColorCorrectionEffect") then
			cor.Enabled = geralLigado
		end
		for _, c in camadas do
			local nomePref = PREF_CAMADA[c.nome]
			local querLigar = geralLigado and (nomePref == nil or pref(nomePref))
			if c.ligada ~= querLigar then
				c.ligada = querLigar
				chamar(c, "ligar", querLigar)
			end
		end
	end
	aplicarPrefs()
	for _, nome in { "Pref_FiltroPS1", "Pref_Aberracao", "Pref_Lente", "Pref_NeblinaVolume" } do
		jogador:GetAttributeChangedSignal(nome):Connect(aplicarPrefs)
	end

	local function aplicarNivel(n: number)
		estado.nivel = n
		for _, c in camadas do
			chamar(c, "nivel", n)
		end
	end
	aplicarNivel(geral.qualidade.nivelInicial)

	-- Dano: perda de vida do humanoide local
	local ligacaoVida: RBXScriptConnection? = nil
	local function seguirPersonagem(personagem: Model?)
		if ligacaoVida then
			ligacaoVida:Disconnect()
			ligacaoVida = nil
		end
		if not personagem then
			return
		end
		local humanoide = personagem:WaitForChild("Humanoid", 10)
		if not humanoide or not humanoide:IsA("Humanoid") then
			return
		end
		local ultima = humanoide.Health
		ligacaoVida = humanoide.HealthChanged:Connect(function(vida)
			local perda = ultima - vida
			ultima = vida
			if perda > 0 then
				Filtro.pulso("dano", perda / geral.danoParaPulsoCheio)
			end
		end)
	end
	jogador.CharacterAdded:Connect(function(p)
		task.spawn(seguirPersonagem, p)
	end)
	if jogador.Character then
		task.spawn(seguirPersonagem, jogador.Character)
	end

	-- Estado que se calcula a baixa frequência
	local rng = Random.new()
	local proximoGlitch = os.clock() + geral.glitch.primeiro
	local cacaAlvo = 0
	local interiorAlvo = 0
	local ultimaCaca = 0
	local ultimoInterior = 0
	local cacando: { [Instance]: boolean } = {}
	local paramsRaio = RaycastParams.new()
	paramsRaio.FilterType = Enum.RaycastFilterType.Exclude

	local function varrerCaca()
		local pasta = workspace:FindFirstChild("Monstros")
		local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		local maisForte = 0
		if pasta and raiz and raiz:IsA("BasePart") then
			local g = geral.caca
			for _, m in pasta:GetChildren() do
				if m:IsA("Model") and ESTADOS_CACA[m:GetAttribute("Estado") :: any] then
					local d = (m:GetPivot().Position - raiz.Position).Magnitude
					maisForte = math.max(maisForte, Regras.intensidadeCaca(d, g.perto, g.longe))
					if d <= g.distSusto and not cacando[m] then
						cacando[m] = true
						Filtro.pulso("susto", 1)
					elseif d > g.longe then
						cacando[m] = nil
					end
				else
					cacando[m] = nil
				end
			end
		end
		cacaAlvo = maisForte
	end

	local function varrerInterior(cam: Camera)
		local personagem = jogador.Character
		paramsRaio.FilterDescendantsInstances = if personagem then { personagem, pastaMundo } else { pastaMundo }
		local r = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, geral.interior.alcance, 0), paramsRaio)
		interiorAlvo = if r then 1 else 0
	end

	-- Qualidade automática
	local q = geral.qualidade
	local quadros, tempoJanela = 0, 0
	local segAbaixo, segAcima = 0, 0
	local inicio = os.clock()

	local function passo(dt: number)
		local agora = os.clock()
		if workspace.CurrentCamera ~= ctx.camera and workspace.CurrentCamera then
			ctx.camera = workspace.CurrentCamera
			pastaMundo.Parent = ctx.camera
		end
		local cam: Camera = ctx.camera

		for tipo, valor in pulsos do
			local meia = if tipo == "dano"
				then geral.pulsos.meiaVidaDano
				elseif tipo == "susto" then geral.pulsos.meiaVidaSusto
				else geral.pulsos.meiaVidaGlitch
			pulsos[tipo] = Regras.decair(valor, dt, meia)
			if pulsos[tipo] < 0.001 then
				pulsos[tipo] = 0
			end
		end

		if agora - ultimaCaca >= geral.caca.varredura then
			ultimaCaca = agora
			varrerCaca()
		end
		if agora - ultimoInterior >= geral.interior.varredura then
			ultimoInterior = agora
			varrerInterior(cam)
		end

		local personagem = jogador.Character
		local cabeca = personagem and personagem:FindFirstChild("Head")
		local clima = workspace:GetAttribute("Clima")

		estado.t = agora
		estado.dt = dt
		estado.noite = if luzDaHora then 1 - math.clamp(luzDaHora(Lighting.ClockTime), 0, 1) else 0
		estado.clima = if type(clima) == "string" then clima else "limpo"
		estado.fov = cam.FieldOfView
		estado.caca = Regras.suavizar(estado.caca, cacaAlvo, dt, geral.caca.suavizar)
		estado.interior = Regras.suavizar(estado.interior, interiorAlvo, dt, geral.interior.suavizar)
		estado.primeiraPessoa = cabeca ~= nil
			and cabeca:IsA("BasePart")
			and (cam.CFrame.Position - cabeca.Position).Magnitude < geral.distanciaPrimeiraPessoa

		-- glitch agendado (só com o filtro geral ligado)
		if agora >= proximoGlitch then
			if pref("Pref_FiltroPS1") then
				Filtro.pulso("glitch", geral.glitch.forca)
			end
			proximoGlitch = Regras.proximoGlitch(agora, estado.noite, estado.caca, geral.glitch, rng)
		end

		-- qualidade automática
		local forcado = ctx.ajuste("nivel", nil)
		if type(forcado) == "number" then
			local n = math.clamp(math.floor(forcado), 0, 3)
			if n ~= estado.nivel then
				aplicarNivel(n)
			end
		elseif dt > 0 then
			quadros += 1
			tempoJanela += dt
			if tempoJanela >= q.janelaFps then
				local media = quadros / tempoJanela
				local janela = tempoJanela
				quadros, tempoJanela = 0, 0
				if agora - inicio >= q.carencia then
					local n = estado.nivel
					segAbaixo = if n > 0 and media < q.minimo[n] then segAbaixo + janela else 0
					segAcima = if n < 3 and media >= q.minimo[n + 1] + q.folga then segAcima + janela else 0
					local novo = Regras.nivelPorFps(n, media, segAbaixo, segAcima, q)
					if novo ~= n then
						segAbaixo, segAcima = 0, 0
						aplicarNivel(novo)
					end
				end
			end
		end

		for _, c in camadas do
			if c.ligada then
				chamar(c, "atualizar", estado)
			end
		end
	end

	RunService:BindToRenderStep("Filtro", Enum.RenderPriority.Camera.Value + geral.prioridadeRender, passo)
end

return Filtro
