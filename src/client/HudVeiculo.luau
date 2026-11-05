-- HudVeiculo: painel que só existe dentro do carro (motorista e passageiro): km/h, motor, gasolina, 4 pneus, 4 vidros e
-- dica de teclas. Mais a etiqueta flutuante de gasolina na Tampa mais próxima (a pé ou dentro do carro).
-- Só lê atributos do modelo (Motor, MotorLigado, Combustivel, Tanque, SemCombustivel, Pneu_*, Vidro_*) e Direcao.estado.
-- Contrato: docs/veiculos.md e docs/combustivel.md §8.1/§8.2.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgSom = require(Config:WaitForChild("Som"))
local Direcao = require(script.Parent.Direcao)

local HudVeiculo = {}

local jogador = Players.LocalPlayer

local FONTE = Enum.Font.Code
local COR_FUNDO = Color3.fromRGB(20, 20, 22)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)
local COR_TEXTO = Color3.fromRGB(235, 235, 230)
local COR_OK = Color3.fromRGB(80, 185, 80)
local COR_AVISO = Color3.fromRGB(220, 200, 60)
local COR_RUIM = Color3.fromRGB(200, 50, 40)
local COR_MUDO = Color3.fromRGB(70, 70, 74)
local COR_FUNDO_ALERTA = Color3.fromRGB(90, 20, 16) -- fundo da barra de gasolina no ciclo "aceso" do pisca
local PISCA_HZ = 2 -- pisca da gasolina crítica (docs/combustivel.md §8.1)
local DECIMAL_ABAIXO = 10 -- L: abaixo disto o texto mostra 1 casa decimal
local INTERVALO = 0.1 -- s (10 Hz)

local PNEUS = { { "FE", 0, 0 }, { "FD", 1, 0 }, { "TE", 0, 1 }, { "TD", 1, 1 } }
local VIDROS = { { "ParaBrisa", "P" }, { "Traseiro", "T" }, { "JanelaE", "E" }, { "JanelaD", "D" } }

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
		TextSize = 14,
	}
	for nome, valor in propriedades do
		base[nome] = valor
	end
	return criar("TextLabel", base, pai)
end

local function contorno(pai: Instance)
	criar("UIStroke", { Thickness = 1.5, Color = COR_CONTORNO }, pai)
end

local function corPeca(valor: any): Color3
	if valor == "faltando" then
		return COR_RUIM
	elseif valor == "furado" or valor == "quebrado" then
		return COR_AVISO
	elseif valor == "ok" then
		return COR_OK
	end
	return COR_MUDO -- atributo ainda não chegou (streaming)
end

local function nomeTecla(lista: any, padrao: string): string
	if type(lista) == "table" and type(lista[1]) == "string" then
		return lista[1]
	end
	return padrao
end

-- Gasolina de um Model de carro, a partir dos atributos Combustivel/Tanque/SemCombustivel.
-- Devolve (litros, tanque, semCombustivel); tanque = 0 se o carro ainda não trouxe o atributo Tanque (streaming).
local function ler(modelo: Model): (number, number, boolean)
	local tanque = modelo:GetAttribute("Tanque")
	local atual = modelo:GetAttribute("Combustivel")
	if type(tanque) ~= "number" or tanque <= 0 then
		return 0, 0, false
	end
	local vazio = modelo:GetAttribute("SemCombustivel") == true
	if type(atual) ~= "number" then
		atual = 0
	end
	return if vazio then 0 else atual, tanque, vazio
end

function HudVeiculo.iniciar()
	local cfg: any = nil
	local modulo = Config:WaitForChild("Veiculos", 10)
	if modulo then
		local ok, valor = pcall(require, modulo)
		if ok then
			cfg = valor
		end
	end
	local teclas = if type(cfg) == "table" and type(cfg.teclas) == "table" then cfg.teclas else {}
	local cfgComb: any = nil
	local Regra: any = nil
	do
		local m = Config:WaitForChild("Combustivel", 10)
		local r = Shared:WaitForChild("Regras"):WaitForChild("Combustivel", 10)
		if m and r then
			local ok1, v1 = pcall(require, m)
			local ok2, v2 = pcall(require, r)
			if ok1 and ok2 then
				cfgComb = v1
				Regra = v2
			else
				warn("[HudVeiculo] combustível indisponível: " .. tostring(if ok1 then v2 else v1))
			end
		end
	end
	-- limite do pisca: fracaoCritica do Config, ou um terço da reserva (0,15 / 3 = 5%) enquanto o Config não a traz
	local fracaoCritica: number = 0
	if cfgComb then
		fracaoCritica = if type(cfgComb.fracaoCritica) == "number"
			then cfgComb.fracaoCritica
			else cfgComb.fracaoReserva / 3
	end

	-- Estilo da gasolina (barra do HUD e etiqueta): fração, cor da barra, fundo da barra, cor do texto, texto.
	local function estiloGasolina(atual: number, tanque: number): (number, Color3, Color3, Color3, string)
		local fracao = Regra.fracao(atual, tanque)
		local n = if atual < DECIMAL_ABAIXO
			then string.format("%.1f", atual)
			else string.format("%d", math.floor(atual + 0.5))
		local legenda = string.format("%s/%d L", n, math.floor(tanque + 0.5))
		if atual <= 0 or fracao <= fracaoCritica then
			local aceso = math.floor(os.clock() * PISCA_HZ * 2) % 2 == 0
			if aceso then
				return fracao, COR_RUIM, COR_FUNDO_ALERTA, COR_RUIM, legenda
			end
			return fracao, COR_MUDO, COR_FUNDO, COR_TEXTO, legenda
		elseif Regra.reserva(atual, tanque, cfgComb) then
			return fracao, COR_AVISO, COR_FUNDO, COR_TEXTO, legenda
		end
		return fracao, COR_OK, COR_FUNDO, COR_TEXTO, legenda
	end

	local metrosPorStud = if type(CfgSom.metrosPorStud) == "number" then CfgSom.metrosPorStud else 0.28

	local tela = criar("ScreenGui", {
		Name = "HudVeiculo",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, jogador:WaitForChild("PlayerGui"))

	local painel = criar("Frame", {
		Name = "Painel",
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(232, 198),
	}, tela)
	contorno(painel)

	local velocidade = texto(painel, {
		Name = "Velocidade",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.fromOffset(130, 34),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0 km/h",
	})

	local situacao = texto(painel, {
		Name = "Situacao",
		Position = UDim2.fromOffset(132, 10),
		Size = UDim2.fromOffset(92, 20),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Desligado",
	})

	local fundoMotor = criar("Frame", {
		Name = "Motor",
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.fromOffset(216, 22),
	}, painel)
	contorno(fundoMotor)
	local cheioMotor = criar("Frame", {
		Name = "Cheio",
		BackgroundColor3 = COR_OK,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, fundoMotor)
	local rotuloMotor = texto(fundoMotor, {
		Name = "Rotulo",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Text = "Motor",
	})

	-- gasolina: barra com o texto por cima, mesma forma da barra do motor
	local fundoGas = criar("Frame", {
		Name = "Gasolina",
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 68),
		Size = UDim2.fromOffset(216, 22),
	}, painel)
	contorno(fundoGas)
	local cheioGas = criar("Frame", {
		Name = "Cheio",
		BackgroundColor3 = COR_MUDO,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, fundoGas)
	local rotuloGas = texto(fundoGas, {
		Name = "Rotulo",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -8, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Text = "Gasolina  --",
	})

	-- pneus em 2x2 (frente em cima), vidros em fila
	local caixaPneus = criar("Frame", {
		Name = "Pneus",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 96),
		Size = UDim2.fromOffset(52, 56),
	}, painel)
	local quadrosPneu: { [string]: Frame } = {}
	for _, p in PNEUS do
		local q = criar("Frame", {
			Name = p[1],
			BackgroundColor3 = COR_MUDO,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(p[2] * 30, p[3] * 30),
			Size = UDim2.fromOffset(22, 26),
		}, caixaPneus)
		contorno(q)
		quadrosPneu[p[1]] = q
	end
	texto(painel, {
		Position = UDim2.fromOffset(8, 152),
		Size = UDim2.fromOffset(52, 16),
		Text = "Pneus",
		TextSize = 14,
	})

	local caixaVidros = criar("Frame", {
		Name = "Vidros",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(78, 96),
		Size = UDim2.fromOffset(146, 56),
	}, painel)
	local quadrosVidro: { [string]: Frame } = {}
	for i, v in VIDROS do
		local q = criar("Frame", {
			Name = v[1],
			BackgroundColor3 = COR_MUDO,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((i - 1) * 37, 12),
			Size = UDim2.fromOffset(31, 30),
		}, caixaVidros)
		contorno(q)
		texto(q, { Size = UDim2.fromScale(1, 1), Text = v[2], TextColor3 = COR_FUNDO, TextStrokeTransparency = 1 })
		quadrosVidro[v[1]] = q
	end
	texto(painel, {
		Position = UDim2.fromOffset(78, 152),
		Size = UDim2.fromOffset(146, 16),
		Text = "Vidros",
		TextSize = 14,
	})

	local dica = texto(painel, {
		Name = "Dica",
		Position = UDim2.fromOffset(8, 168),
		Size = UDim2.fromOffset(216, 28),
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	local textoBanco = string.format("%s trocar de banco", nomeTecla(teclas.trocarBanco, "F"))
	local textoDica = string.format(
		"%s sair   %s ligar   %s buzina\n%s",
		nomeTecla(teclas.sair, "E"),
		nomeTecla(teclas.ligar, "G"),
		nomeTecla(teclas.buzina, "H"),
		textoBanco
	)
	local textoDicaPassageiro = string.format("%s sair\n%s", nomeTecla(teclas.sair, "E"), textoBanco)

	local acumulado = 0
	local function atualizar()
		local est = Direcao.estado
		local modeloAtual = est.modelo
		if not est.ativo or not modeloAtual then
			return
		end
		local kmh = math.abs(est.velocidade) * metrosPorStud * 3.6
		velocidade.Text = string.format("%d km/h%s", math.floor(kmh + 0.5), if est.velocidade < -1 then " R" else "")

		local ligado = modeloAtual:GetAttribute("MotorLigado") == true
		local motor = modeloAtual:GetAttribute("Motor")
		if type(motor) ~= "number" then
			motor = 100
		end
		local fracao = math.clamp(motor / 100, 0, 1)
		cheioMotor.Size = UDim2.fromScale(fracao, 1)
		cheioMotor.BackgroundColor3 = if fracao <= 0 then COR_RUIM elseif fracao < 0.35 then COR_AVISO else COR_OK
		rotuloMotor.Text =
			string.format("Motor  %d%s", math.floor(motor + 0.5), if fracao <= 0 then "  quebrado" else "")
		situacao.Text = if ligado then "Ligado" else "Desligado"
		situacao.TextColor3 = if ligado then COR_OK else COR_AVISO
		if not est.motorista then
			dica.Text = textoDicaPassageiro
		elseif ligado then
			dica.Text = textoDica
		else
			dica.Text = "Aperte " .. nomeTecla(teclas.ligar, "G") .. " para ligar\n" .. textoBanco
		end

		local atualGas, tanque, vazio = ler(modeloAtual)
		if Regra and tanque > 0 then
			local frac, corBarra, corFundo, corTexto, txt = estiloGasolina(atualGas, tanque)
			cheioGas.Size = UDim2.fromScale(frac, 1)
			cheioGas.BackgroundColor3 = corBarra
			fundoGas.BackgroundColor3 = corFundo
			rotuloGas.TextColor3 = corTexto
			rotuloGas.Text = "Gasolina  " .. txt .. (if vazio then "  vazio" else "")
		else
			cheioGas.Size = UDim2.fromScale(0, 1)
			fundoGas.BackgroundColor3 = COR_FUNDO
			rotuloGas.TextColor3 = COR_TEXTO
			rotuloGas.Text = "Gasolina  --"
		end

		for nome, quadro in quadrosPneu do
			quadro.BackgroundColor3 = corPeca(modeloAtual:GetAttribute("Pneu_" .. nome))
		end
		for nome, quadro in quadrosVidro do
			quadro.BackgroundColor3 = corPeca(modeloAtual:GetAttribute("Vidro_" .. nome))
		end
	end

	-- Etiqueta externa (docs/combustivel.md §8.2): uma BillboardGui só, reaproveitada, na Tampa mais próxima.
	-- Tampas descobertas pela tag "Tampa" (CollectionService); a distância é conferida a 5 Hz, o texto a 10 Hz.
	local etiquetaDistancia = if cfgComb and type(cfgComb.carro) == "table"
		then cfgComb.carro.etiquetaDistancia
		else nil
	local tampas: { [BasePart]: boolean } = {}
	local etiqueta: BillboardGui? = nil
	local cheioEtiqueta: Frame? = nil
	local fundoEtiqueta: Frame? = nil
	local rotuloEtiqueta: TextLabel? = nil
	local tampaEtiqueta: BasePart? = nil
	local modeloEtiqueta: Model? = nil
	local acumuladoEscolha = 0

	local function ocultarEtiqueta()
		if etiqueta then
			etiqueta.Enabled = false
			etiqueta.Adornee = nil
		end
		tampaEtiqueta = nil
		modeloEtiqueta = nil
	end

	if cfgComb and Regra and type(etiquetaDistancia) == "number" then
		local gui = criar("BillboardGui", {
			Name = "EtiquetaGasolina",
			AlwaysOnTop = true,
			Enabled = false,
			Size = UDim2.fromOffset(132, 34),
			StudsOffset = Vector3.new(0, 1, 0),
			MaxDistance = etiquetaDistancia,
			ResetOnSpawn = false,
		}, jogador:WaitForChild("PlayerGui"))
		local fundo = criar("Frame", {
			BackgroundColor3 = COR_FUNDO,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, gui)
		contorno(fundo)
		rotuloEtiqueta = texto(fundo, {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0, 16),
			TextSize = 12,
			Text = "Gasolina",
		})
		local fundoBarra = criar("Frame", {
			BackgroundColor3 = COR_FUNDO,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 22),
			Size = UDim2.new(1, -12, 0, 6),
		}, fundo)
		contorno(fundoBarra)
		cheioEtiqueta = criar("Frame", {
			BackgroundColor3 = COR_MUDO,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
		}, fundoBarra)
		fundoEtiqueta = fundoBarra
		etiqueta = gui

		local function adicionar(inst: Instance)
			if inst:IsA("BasePart") then
				tampas[inst] = true
			end
		end
		for _, inst in CollectionService:GetTagged("Tampa") do
			adicionar(inst)
		end
		CollectionService:GetInstanceAddedSignal("Tampa"):Connect(adicionar)
		CollectionService:GetInstanceRemovedSignal("Tampa"):Connect(function(inst)
			if inst:IsA("BasePart") then
				tampas[inst] = nil
				if inst == tampaEtiqueta then
					ocultarEtiqueta()
				end
			end
		end)
	end

	local function escolherTampa()
		local personagem = jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if not (raiz and raiz:IsA("BasePart")) then
			ocultarEtiqueta()
			return
		end
		local origem = raiz.Position
		local melhor: BasePart? = nil
		local melhorDist = etiquetaDistancia :: number
		for tampa in tampas do
			if tampa.Parent then
				local d = (tampa.Position - origem).Magnitude
				if d <= melhorDist then
					melhor = tampa
					melhorDist = d
				end
			end
		end
		if melhor ~= tampaEtiqueta then
			tampaEtiqueta = melhor
			modeloEtiqueta = if melhor then melhor:FindFirstAncestorOfClass("Model") else nil
			if etiqueta then
				etiqueta.Adornee = melhor
				etiqueta.Enabled = melhor ~= nil
			end
		end
	end

	local function atualizarEtiqueta()
		local modelo = modeloEtiqueta
		if not (etiqueta and cheioEtiqueta and fundoEtiqueta and rotuloEtiqueta and modelo) then
			return
		end
		local atualGas, tanque = ler(modelo)
		if tanque <= 0 then
			etiqueta.Enabled = false -- atributos ainda não chegaram
			return
		end
		etiqueta.Enabled = true
		local frac, corBarra, corFundo, corTexto, txt = estiloGasolina(atualGas, tanque)
		cheioEtiqueta.Size = UDim2.fromScale(frac, 1)
		cheioEtiqueta.BackgroundColor3 = corBarra
		fundoEtiqueta.BackgroundColor3 = corFundo
		rotuloEtiqueta.TextColor3 = corTexto
		rotuloEtiqueta.Text = "Gasolina " .. txt
	end

	Direcao.aoMudar(function(ativo)
		tela.Enabled = ativo
		if ativo then
			acumulado = INTERVALO
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado < INTERVALO then
			return
		end
		acumulado = 0
		if tela.Enabled then
			local ok, erro = pcall(atualizar)
			if not ok then
				warn("[HudVeiculo] " .. tostring(erro))
			end
		end
		if etiqueta then
			acumuladoEscolha += INTERVALO
			local ok, erro = pcall(function()
				if acumuladoEscolha >= 0.2 then
					acumuladoEscolha = 0
					escolherTampa()
				end
				atualizarEtiqueta()
			end)
			if not ok then
				warn("[HudVeiculo] etiqueta: " .. tostring(erro))
			end
		end
	end)
end

return HudVeiculo
