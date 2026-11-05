-- ItensChaoCliente: mira e coleta dos itens soltos no chão (docs/itens-no-mundo.md §3-D).
-- A 10 Hz escolhe, entre os modelos com a tag "ItemChao" já streamados, o que está mais perto da mira (raio da câmera) e dentro
-- do alcance da cabeça. UM Highlight e UM BillboardGui são reusados (troca de Adornee), nunca um por item.
-- Pegar: tecla de Config/Movimento.teclas.interagir (E) ou toque no rótulo -> evento PegarDoChao; o servidor valida tudo.
-- Não pega com menu aberto (Mouse.menuAberto, inclui o Tab) nem dentro do carro (Direcao.estado.ativo). Sem ProximityPrompt.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("ItensChao"))
local CfgItens = require(Shared.Config:WaitForChild("Itens"))
local CfgMovimento = require(Shared.Config:WaitForChild("Movimento"))
local Mouse = require(script.Parent.Mouse)

local ItensChaoCliente = {}

local TAG = "ItemChao"
local INTERVALO = 0.1 -- s: 10 Hz
local INTERVALO_PEDIDO = 0.15 -- s entre pedidos de pegar (o servidor também limita)

local COR_FUNDO = Color3.fromRGB(22, 22, 26)
local COR_TEXTO = Color3.fromRGB(236, 236, 238)
local COR_DESTAQUE = Color3.fromRGB(255, 160, 40)
local FONTE_NEGRITO = Font.fromEnum(Enum.Font.GothamBold)

local jogador = Players.LocalPlayer

local itens: { [Model]: boolean } = {} -- modelos com a tag que existem neste cliente (streaming)
local candidato: Model? = nil
local chave = "" -- id|qtd do candidato mostrado: só reescreve o texto quando muda
local ultimoPedido = 0
local destaque: Highlight
local rotulo: BillboardGui
local botao: TextButton
local Direcao: any = nil -- pcall: sem ela só não se sabe se está no carro

local function nomeTecla(): string
	if UserInputService.KeyboardEnabled then
		return CfgMovimento.teclas.interagir[1] or "E"
	end
	return "Tocar"
end

-- Quem decide se pode pegar agora: menu aberto, carro ou morto bloqueiam.
local function bloqueado(): boolean
	if Mouse.menuAberto() or jogador:GetAttribute("Morto") == true then
		return true
	end
	return Direcao ~= nil and Direcao.estado ~= nil and Direcao.estado.ativo == true
end

local function pecaDe(modelo: Model): BasePart?
	if modelo.PrimaryPart then
		return modelo.PrimaryPart
	end
	return modelo:FindFirstChildWhichIsA("BasePart", true)
end

-- Interface (uma instância de cada) -----------------------------------------------------------------------------

local function criarInterface()
	destaque = Instance.new("Highlight")
	destaque.Name = "ItemChaoDestaque"
	destaque.FillColor = COR_TEXTO
	destaque.FillTransparency = 0.85
	destaque.OutlineColor = COR_TEXTO
	destaque.OutlineTransparency = 0
	destaque.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	destaque.Adornee = nil

	rotulo = Instance.new("BillboardGui")
	rotulo.Name = "ItemChaoRotulo"
	rotulo.Size = UDim2.fromOffset(200, 54)
	rotulo.StudsOffset = Vector3.new(0, 1.4, 0)
	rotulo.AlwaysOnTop = true
	rotulo.LightInfluence = 0
	rotulo.MaxDistance = Cfg.alcance * 3
	rotulo.ResetOnSpawn = false
	rotulo.Active = true
	rotulo.Enabled = false

	botao = Instance.new("TextButton")
	botao.Name = "Texto"
	botao.Size = UDim2.fromScale(1, 1)
	botao.BackgroundColor3 = COR_FUNDO
	botao.BackgroundTransparency = 0.25
	botao.AutoButtonColor = false
	botao.FontFace = FONTE_NEGRITO
	botao.TextSize = 15
	botao.TextColor3 = COR_TEXTO
	botao.TextWrapped = true
	botao.RichText = true
	botao.Text = ""
	botao.Parent = rotulo

	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 6)
	canto.Parent = botao
	local contorno = Instance.new("UIStroke")
	contorno.Color = COR_DESTAQUE
	contorno.Transparency = 0.4
	contorno.Thickness = 1
	contorno.Parent = botao
end

local function mostrar(modelo: Model, parte: BasePart)
	local camera = workspace.CurrentCamera
	if camera and destaque.Parent ~= camera then
		destaque.Parent = camera
	end
	if rotulo.Parent == nil then
		rotulo.Parent = jogador:WaitForChild("PlayerGui")
	end
	destaque.Adornee = modelo
	rotulo.Adornee = parte
	rotulo.Enabled = true
end

local function esconder()
	candidato = nil
	chave = ""
	destaque.Adornee = nil
	rotulo.Adornee = nil
	rotulo.Enabled = false
end

local function escrever(modelo: Model)
	local id = modelo:GetAttribute("Item")
	local qtd = modelo:GetAttribute("Qtd")
	local nova = tostring(id) .. "|" .. tostring(qtd)
	if nova == chave then
		return
	end
	chave = nova
	local def = if type(id) == "string" then CfgItens.itens[id] else nil
	local nome = if def then def.nome else tostring(id)
	local sufixo = if type(qtd) == "number" and qtd > 1 then "  x" .. tostring(math.floor(qtd)) else ""
	botao.Text = nome .. sufixo .. '\n<font color="rgb(255,160,40)">[' .. nomeTecla() .. "]</font>"
end

-- Escolha do candidato -------------------------------------------------------------------------------------------

-- Distância do ponto ao raio (origem, direção unitária) e a posição ao longo do raio.
local function distanciaAoRaio(ponto: Vector3, origem: Vector3, direcao: Vector3): (number, number)
	local v = ponto - origem
	local t = v:Dot(direcao)
	if t < 0 then
		return v.Magnitude, t -- atrás da câmera: distância ao próprio ponto de origem (nunca vence)
	end
	return (v - direcao * t).Magnitude, t
end

local function escolher(): (Model?, BasePart?)
	local camera = workspace.CurrentCamera
	local personagem = jogador.Character
	local cabeca = personagem and (personagem:FindFirstChild("Head") or personagem:FindFirstChild("HumanoidRootPart"))
	if not (camera and cabeca and cabeca:IsA("BasePart")) then
		return nil, nil
	end
	local origem = camera.CFrame.Position
	local direcao = camera.CFrame.LookVector
	local posCabeca = cabeca.Position
	local melhor, melhorParte, melhorDist = nil, nil, math.huge
	for modelo in itens do
		if modelo.Parent == nil then
			continue
		end
		local parte = pecaDe(modelo)
		if not parte then
			continue
		end
		local pos = modelo:GetPivot().Position
		if (pos - posCabeca).Magnitude > Cfg.alcance then
			continue
		end
		local dist, t = distanciaAoRaio(pos, origem, direcao)
		if t >= 0 and dist <= Cfg.raioMira and dist < melhorDist then
			melhor, melhorParte, melhorDist = modelo, parte, dist
		end
	end
	return melhor, melhorParte
end

local function varrer()
	if bloqueado() then
		if candidato then
			esconder()
		end
		return
	end
	local modelo, parte = escolher()
	if not (modelo and parte) then
		if candidato then
			esconder()
		end
		return
	end
	if candidato ~= modelo then
		candidato = modelo
		chave = ""
		mostrar(modelo, parte)
	end
	escrever(modelo)
end

-- Pegar ----------------------------------------------------------------------------------------------------------

local function pegar()
	local modelo = candidato
	if not modelo or modelo.Parent == nil or bloqueado() then
		return
	end
	local agora = os.clock()
	if agora - ultimoPedido < INTERVALO_PEDIDO then
		return
	end
	ultimoPedido = agora
	-- PegarDoChao é declarado em Rede.luau pela parte C: se ainda não existir, o pedido só falha em silêncio.
	local ok, erro = pcall(function()
		Rede.evento("PegarDoChao"):FireServer(modelo)
	end)
	if not ok then
		warn("[ItensChaoCliente] " .. tostring(erro))
	end
end

function ItensChaoCliente.iniciar()
	local okDirecao, resultado = pcall(require, script.Parent.Direcao)
	if okDirecao then
		Direcao = resultado
	end

	criarInterface()

	local function registrar(inst: Instance)
		if inst:IsA("Model") then
			itens[inst] = true
		end
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		registrar(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(registrar)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			itens[inst] = nil
			if candidato == inst then
				esconder()
			end
		end
	end)

	-- Teclas do mapa do projeto (Config/Movimento.teclas.interagir). BindAction com Pass, e não Teclas.ligar (que dá
	-- Sink): o E também fecha a caixa aberta (InventarioUI) e aciona o ProximityPrompt das caixas.
	local codigos: { Enum.KeyCode } = {}
	for _, nome in CfgMovimento.teclas.interagir do
		local codigo = (Enum.KeyCode :: any)[nome]
		if codigo then
			table.insert(codigos, codigo)
		else
			warn("[ItensChaoCliente] tecla desconhecida: " .. tostring(nome))
		end
	end
	if #codigos > 0 then
		ContextActionService:BindAction("PegarDoChao", function(_, estado)
			if estado == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
				pegar()
			end
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(codigos))
	end

	botao.Activated:Connect(pegar)

	task.spawn(function()
		while true do
			local ok, erro = pcall(varrer)
			if not ok then
				warn("[ItensChaoCliente] " .. tostring(erro))
			end
			task.wait(INTERVALO)
		end
	end)
end

return ItensChaoCliente
