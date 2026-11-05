-- HudSom: medidor de decibéis no canto inferior direito (barra 0..120 dB, marca do ambiente, último ruído próprio).
-- Dono: P3. Contrato: docs/arquitetura.md §P3 e docs/calculos.md §1.6.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))

local HudSom = {}

local DB_MAXIMO = 120
local DECAIMENTO = 1 -- s para a barra esvaziar
local LARGURA = 220
local COR_VERDE = Color3.fromRGB(96, 168, 96)
local COR_AMARELA = Color3.fromRGB(214, 184, 64)
local COR_VERMELHA = Color3.fromRGB(204, 64, 52)
local COR_TEXTO = Color3.fromRGB(230, 230, 224)
local COR_FUNDO = Color3.fromRGB(16, 16, 18)

local ultimoDb = 0
local ultimoTempo = -math.huge
local ultimoAmbiente: number = CfgSom.ambiente.noite
local ultimoAlcance = 0
local corAtual = COR_VERDE

local function corPara(db: number, ambiente: number): Color3
	if db < ambiente then
		return COR_VERDE
	elseif db <= ambiente + CfgSom.medidor.amareloAte then
		return COR_AMARELA
	end
	return COR_VERMELHA
end

local function rotulo(pai: Instance, texto: string, tamanho: number, posicao: UDim2, tamanhoBox: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Code
	l.Text = texto
	l.TextSize = tamanho
	l.TextColor3 = COR_TEXTO
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = posicao
	l.Size = tamanhoBox
	l.Parent = pai
	return l
end

function HudSom.iniciar()
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudSom"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = jogador:WaitForChild("PlayerGui")

	local caixa = Instance.new("Frame")
	caixa.Name = "Caixa"
	caixa.AnchorPoint = Vector2.new(1, 1)
	caixa.Position = UDim2.new(1, -16, 1, -16)
	caixa.Size = UDim2.fromOffset(LARGURA, 72)
	caixa.BackgroundColor3 = COR_FUNDO
	caixa.BackgroundTransparency = 0.35
	caixa.BorderSizePixel = 0
	caixa.Active = false
	caixa.Parent = gui

	local valor = rotulo(caixa, "-- dB", 20, UDim2.fromOffset(8, 4), UDim2.fromOffset(90, 22))
	local ambienteTexto =
		rotulo(caixa, "ambiente 20 dB", 14, UDim2.fromOffset(96, 4), UDim2.fromOffset(LARGURA - 104, 22))
	ambienteTexto.TextXAlignment = Enum.TextXAlignment.Right
	local alcanceTexto = rotulo(caixa, "alcance 0 studs", 14, UDim2.fromOffset(8, 48), UDim2.new(1, -16, 0, 20))

	local fundoBarra = Instance.new("Frame")
	fundoBarra.Name = "Barra"
	fundoBarra.Position = UDim2.fromOffset(8, 30)
	fundoBarra.Size = UDim2.new(1, -16, 0, 14)
	fundoBarra.BackgroundColor3 = Color3.fromRGB(44, 44, 48)
	fundoBarra.BorderSizePixel = 0
	fundoBarra.Parent = caixa

	local enchimento = Instance.new("Frame")
	enchimento.Name = "Enchimento"
	enchimento.Size = UDim2.fromScale(0, 1)
	enchimento.BackgroundColor3 = COR_VERDE
	enchimento.BorderSizePixel = 0
	enchimento.Parent = fundoBarra

	local marca = Instance.new("Frame")
	marca.Name = "MarcaAmbiente"
	marca.AnchorPoint = Vector2.new(0.5, 0.5)
	marca.Size = UDim2.new(0, 3, 1, 6)
	marca.BackgroundColor3 = Color3.fromRGB(245, 245, 240)
	marca.BorderSizePixel = 0
	marca.ZIndex = 2
	marca.Parent = fundoBarra

	local function mostrarAmbiente(db: number)
		ultimoAmbiente = db
		marca.Position = UDim2.fromScale(math.clamp(db / DB_MAXIMO, 0, 1), 0.5)
		ambienteTexto.Text = string.format("ambiente %d dB", math.floor(db + 0.5))
	end
	local inicial = workspace:GetAttribute("AmbienteDb")
	mostrarAmbiente(if type(inicial) == "number" then inicial else ultimoAmbiente)
	workspace:GetAttributeChangedSignal("AmbienteDb"):Connect(function()
		local db = workspace:GetAttribute("AmbienteDb")
		if type(db) == "number" then
			mostrarAmbiente(db)
		end
	end)

	Rede.evento("MeuRuido").OnClientEvent:Connect(function(db: number, ambiente: number, alcance: number)
		if type(db) ~= "number" or type(ambiente) ~= "number" then
			return
		end
		ultimoDb = db
		ultimoTempo = os.clock()
		ultimoAlcance = if type(alcance) == "number" then alcance else 0
		corAtual = corPara(db, ambiente)
		mostrarAmbiente(ambiente)
		valor.Text = string.format("%d dB", math.floor(db + 0.5))
		alcanceTexto.Text = string.format("alcance %d studs", math.floor(ultimoAlcance + 0.5))
	end)

	RunService.RenderStepped:Connect(function()
		local fracao = math.clamp(1 - (os.clock() - ultimoTempo) / DECAIMENTO, 0, 1)
		enchimento.Size = UDim2.fromScale(math.clamp(ultimoDb / DB_MAXIMO, 0, 1) * fracao, 1)
		enchimento.BackgroundColor3 = corAtual
		valor.TextTransparency = 0.5 * (1 - fracao)
	end)
end

return HudSom
