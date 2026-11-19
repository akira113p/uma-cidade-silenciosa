-- MonstroEfeitos: efeitos de cliente dos monstros novos. Dono: agente C. Contrato: docs/monstros/logica.md §2.2, §7.2, §7.3.
--   * HUD "Derrubado" enquanto o atributo Derrubado do jogador (workspace:GetServerTimeNow() do fim) estiver no futuro.
--   * Tremor(intensidade 0..1, duracao s): tremor de câmera pelo Camera.tremer (que já respeita Pref_Tremor/Pref_Intensidade).
--   * Névoa esverdeada perto de uma flor da Florescida (workspace.Flores, atributo Flor): uma ColorCorrectionEffect própria
--     por cima do filtro (src/client/Filtro não é tocado).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))

local Camera = require(script.Parent.Camera)

local MonstroEfeitos = {}

local AMPLITUDE_TREMOR_MAX = 0.6 -- studs de Camera.tremer para intensidade 1
local DURACAO_TREMOR_MAX = 5 -- s; teto contra valor absurdo vindo da rede
local TREMOR_DERRUBADO = { amplitude = 0.3, duracao = 0.35 } -- ao começar a ficar derrubado
local IMPULSO_MAXIMO = 120 -- studs/s; teto do vetor recebido
local VARREDURA = 0.1 -- s (10 Hz): derrubado e flores
local RAIO_FLOR = 25 -- studs: a névoa começa aqui
local RAIO_FLOR_CHEIO = 10 -- studs: névoa no máximo daqui para dentro
local TINTA_FLOR = Color3.fromRGB(205, 255, 195) -- verde leve (branco = sem efeito)
local SATURACAO_FLOR = -0.1
local SUAVIZAR_FLOR = 3 -- 1/s
local FONTE = Enum.Font.Code
local COR_TEXTO = Color3.fromRGB(235, 235, 230)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)

local jogador = Players.LocalPlayer
local rotuloDerrubado: TextLabel? = nil
local correcao: ColorCorrectionEffect? = nil
local forcaFlor = 0
local alvoFlor = 0
local derrubadoAntes = false

local function derrubadoAgora(): boolean
	local fim = jogador:GetAttribute("Derrubado")
	return type(fim) == "number" and workspace:GetServerTimeNow() < fim
end

local function criarHud()
	local g = Instance.new("ScreenGui")
	g.Name = "MonstroEfeitos"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 19
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local t = Instance.new("TextLabel")
	t.Name = "Derrubado"
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.62)
	t.Size = UDim2.fromOffset(300, 36)
	t.Font = FONTE
	t.Text = "Derrubado"
	t.TextSize = 28
	t.TextColor3 = COR_TEXTO
	t.TextStrokeColor3 = COR_CONTORNO
	t.TextStrokeTransparency = 0.2
	t.Visible = false
	t.Parent = g
	g.Parent = jogador:WaitForChild("PlayerGui")
	rotuloDerrubado = t
end

local function criarCorrecao()
	local c = Lighting:FindFirstChild("NevoaFlor")
	if not (c and c:IsA("ColorCorrectionEffect")) then
		c = Instance.new("ColorCorrectionEffect")
		c.Name = "NevoaFlor"
		c.Parent = Lighting
	end
	local cc = c :: ColorCorrectionEffect
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Saturation = 0
	cc.Enabled = false
	correcao = cc
end

-- Distância da câmera à flor mais próxima (nil se não há flores).
local function distanciaFlor(): number?
	local pasta = workspace:FindFirstChild("Flores")
	if not pasta then
		return nil
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local pos = cam.CFrame.Position
	local melhor: number? = nil
	for _, flor in pasta:GetChildren() do
		if flor:GetAttribute("Flor") == true and (flor:IsA("Model") or flor:IsA("BasePart")) then
			local d = (flor:GetPivot().Position - pos).Magnitude
			if melhor == nil or d < melhor then
				melhor = d
			end
		end
	end
	return melhor
end

local function varrer()
	-- Derrubado
	local derrubado = derrubadoAgora()
	if rotuloDerrubado then
		rotuloDerrubado.Visible = derrubado
	end
	if derrubado and not derrubadoAntes then
		Camera.tremer(TREMOR_DERRUBADO.amplitude, TREMOR_DERRUBADO.duracao)
	end
	derrubadoAntes = derrubado

	-- Flores
	local d = distanciaFlor()
	if d and d <= RAIO_FLOR then
		alvoFlor = math.clamp((RAIO_FLOR - d) / (RAIO_FLOR - RAIO_FLOR_CHEIO), 0, 1)
	else
		alvoFlor = 0
	end
end

local function aplicarFlor(dt: number)
	if not correcao then
		return
	end
	forcaFlor += (alvoFlor - forcaFlor) * (1 - math.exp(-SUAVIZAR_FLOR * dt))
	if forcaFlor < 0.01 and alvoFlor == 0 then
		forcaFlor = 0
		correcao.Enabled = false
		return
	end
	correcao.Enabled = true
	correcao.TintColor = Color3.new(1, 1, 1):Lerp(TINTA_FLOR, forcaFlor)
	correcao.Saturation = SATURACAO_FLOR * forcaFlor
end

function MonstroEfeitos.iniciar()
	criarHud()
	criarCorrecao()

	Rede.evento("Tremor").OnClientEvent:Connect(function(intensidade: number, duracao: number)
		if
			type(intensidade) ~= "number"
			or type(duracao) ~= "number"
			or intensidade ~= intensidade
			or duracao ~= duracao
		then
			return
		end
		Camera.tremer(math.clamp(intensidade, 0, 1) * AMPLITUDE_TREMOR_MAX, math.clamp(duracao, 0, DURACAO_TREMOR_MAX))
	end)

	Rede.evento("Impulso").OnClientEvent:Connect(function(vetor: Vector3)
		if typeof(vetor) ~= "Vector3" or vetor ~= vetor then
			return
		end
		local personagem = jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not (raiz and raiz:IsA("BasePart")) or not humanoide or humanoide.Health <= 0 or humanoide.SeatPart then
			return
		end
		if vetor.Magnitude > IMPULSO_MAXIMO then
			vetor = vetor.Unit * IMPULSO_MAXIMO
		end
		raiz.AssemblyLinearVelocity += vetor
	end)

	jogador:GetAttributeChangedSignal("Derrubado"):Connect(varrer)
	jogador.CharacterAdded:Connect(function()
		derrubadoAntes = false
		alvoFlor = 0
	end)

	local acumulado = 0
	RunService.RenderStepped:Connect(function(dt)
		acumulado += dt
		if acumulado >= VARREDURA then
			acumulado = 0
			varrer()
		end
		aplicarFlor(dt)
	end)
end

return MonstroEfeitos
