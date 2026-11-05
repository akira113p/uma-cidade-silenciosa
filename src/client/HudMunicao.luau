-- HudMunicao: canto inferior direito, "PENTE / RESERVA" da arma de fogo na mão, nome da arma, calibre e uma barra fina de
-- recarga. Some sem arma de fogo. Dono: A5 (docs/armas.md §10.3). Só mostra: lê os atributos Pente, Reserva, ArmaEquipada
-- e os sinais de ArmasSinais; o contador do pente usa a previsão de ArmasCliente para não atrasar na rajada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgItens = require(Config:WaitForChild("Itens"))
local ArmasSinais = require(script.Parent.ArmasSinais)

local HudMunicao = {}

local jogador = Players.LocalPlayer

-- Mesmo visual dos outros HUDs (HudVida): fonte Code, contorno único de 1,5 px, texto mínimo 14.
local FONTE = Enum.Font.Code
local TEXTO_MIN = 14
local TEXTO_GRANDE = 34
local CONTORNO = 1.5
local COR_FUNDO = Color3.fromRGB(20, 20, 22)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)
local COR_TEXTO = Color3.fromRGB(235, 235, 230)
local COR_SUAVE = Color3.fromRGB(170, 170, 165)
local COR_BAIXO = Color3.fromRGB(220, 200, 60)
local COR_VAZIO = Color3.fromRGB(200, 55, 45)
local COR_RECARGA = Color3.fromRGB(190, 190, 80)
local FRACAO_BAIXO = 0.25 -- pente igual ou abaixo desta fração da capacidade fica amarelo

local function criar(classe: string, propriedades: { [string]: any }, pai: Instance?): any
	local inst = Instance.new(classe)
	for nome, valor in propriedades do
		(inst :: any)[nome] = valor
	end
	inst.Parent = pai
	return inst
end

local function texto(pai: Instance, propriedades: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = FONTE,
		TextColor3 = COR_TEXTO,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = COR_CONTORNO,
		TextSize = TEXTO_MIN,
	}
	for nome, valor in propriedades do
		base[nome] = valor
	end
	return criar("TextLabel", base, pai)
end

local recargaInicio = 0
local recargaDuracao = 0
local recarregando = false

function HudMunicao.iniciar()
	local tela = criar("ScreenGui", {
		Name = "HudMunicao",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, jogador:WaitForChild("PlayerGui"))

	local painel = criar("Frame", {
		Name = "Painel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(220, 84),
	}, tela)

	local contagem = texto(painel, {
		Name = "Contagem",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = TEXTO_GRANDE,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local nomeArma = texto(painel, {
		Name = "Nome",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local calibre = texto(painel, {
		Name = "Calibre",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = COR_SUAVE,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local fundoBarra = criar("Frame", {
		Name = "BarraRecarga",
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 78),
		Size = UDim2.new(1, 0, 0, 5),
		Visible = false,
	}, painel)
	criar("UIStroke", { Thickness = CONTORNO, Color = COR_CONTORNO }, fundoBarra)
	local enchimento = criar("Frame", {
		Name = "Cheio",
		BackgroundColor3 = COR_RECARGA,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, fundoBarra)

	-- ArmasCliente tem o contador previsto; se faltar, vale só o atributo.
	local ArmasCliente: any = nil
	local okRequire, modulo = pcall(function()
		return require(script.Parent.ArmasCliente)
	end)
	if okRequire then
		ArmasCliente = modulo
	end

	local ultimoTexto = ""
	local ultimaCor = COR_TEXTO
	local ultimaArma: string? = nil

	local function atualizar()
		local id = jogador:GetAttribute("ArmaEquipada")
		local arma = if type(id) == "string" then CfgArmas.armas[id] else nil
		local visivel = arma ~= nil and arma.tipo == "fogo" and jogador:GetAttribute("Morto") ~= true
		tela.Enabled = visivel
		if not visivel or not arma then
			ultimaArma = nil
			return
		end

		if id ~= ultimaArma then
			ultimaArma = id
			nomeArma.Text = arma.nome
			local municao = CfgItens.itens[arma.municao]
			calibre.Text = if municao then municao.nome else tostring(arma.municao)
		end

		local pente: number? = nil
		if ArmasCliente and ArmasCliente.pente then
			pente = ArmasCliente.pente()
		end
		if pente == nil then
			local servidor = jogador:GetAttribute("Pente")
			pente = if type(servidor) == "number" then servidor else nil
		end
		local reserva = jogador:GetAttribute("Reserva")
		local t = string.format(
			"%s / %s",
			if pente then tostring(math.max(0, math.floor(pente))) else "--",
			if type(reserva) == "number" then tostring(math.max(0, math.floor(reserva))) else "--"
		)
		local corTexto = COR_TEXTO
		if pente ~= nil then
			if pente <= 0 then
				corTexto = COR_VAZIO
			elseif pente / arma.pente <= FRACAO_BAIXO then
				corTexto = COR_BAIXO
			end
		end
		if t ~= ultimoTexto then
			ultimoTexto = t
			contagem.Text = t
		end
		if corTexto ~= ultimaCor then
			ultimaCor = corTexto
			contagem.TextColor3 = corTexto
		end

		if recarregando and recargaDuracao > 0 then
			fundoBarra.Visible = true
			enchimento.Size = UDim2.fromScale(math.clamp((os.clock() - recargaInicio) / recargaDuracao, 0, 1), 1)
		elseif fundoBarra.Visible then
			fundoBarra.Visible = false
		end
	end

	ArmasSinais.ouvir("recarregou", function(_id: string, duracao: number)
		recarregando = true
		recargaInicio = os.clock()
		recargaDuracao = duracao
	end)
	ArmasSinais.ouvir("recargaFim", function()
		recarregando = false
	end)
	ArmasSinais.ouvir("equipou", function()
		recarregando = false
	end)

	RunService.Heartbeat:Connect(atualizar)
	atualizar()
end

return HudMunicao
