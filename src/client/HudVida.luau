-- HudVida: barras de fome/sede/calor/estamina, boneco de 6 partes, flash de dano, tela de morte e avisos. Dono: P5.
-- Só mostra: lê atributos do Player (Estamina, Fome, Sede, Calor, Vida_*, Morto, Correndo, Agachado) e eventos
-- Dano, Morreu e Aviso de Rede.luau. Contrato: docs/arquitetura.md §P5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgCorpo = require(Shared:WaitForChild("Config"):WaitForChild("Corpo"))
local CfgSobrevivencia = require(Shared:WaitForChild("Config"):WaitForChild("Sobrevivencia"))

local HudVida = {}

local jogador = Players.LocalPlayer

local FONTE = Enum.Font.Code
local TEXTO_MIN = 14 -- skill ui-roblox: nenhum texto abaixo disto
local CONTORNO = 1.5 -- espessura única de contorno de toda a UI do HUD
local DURACAO_AVISO = 3
local MAX_AVISOS = 3
local TEMPO_REAPARECER = 10 -- = Players.RespawnTime do projeto (fallback se a leitura falhar)

local COR_FUNDO = Color3.fromRGB(20, 20, 22)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)
local COR_TEXTO = Color3.fromRGB(235, 235, 230)
local COR_BAIXO = Color3.fromRGB(200, 55, 45)
local COR_VERDE = Color3.fromRGB(80, 185, 80)
local COR_AMARELO = Color3.fromRGB(220, 200, 60)
local COR_VERMELHO = Color3.fromRGB(200, 50, 40)
local COR_ZERADA = Color3.fromRGB(12, 12, 12)

-- barra → cor cheia, rótulo, valor abaixo do qual vira alerta
local BARRAS = {
	{ nome = "Fome", rotulo = "Fome", cor = Color3.fromRGB(205, 140, 60), baixo = CfgSobrevivencia.estamina.fomeBaixa },
	{ nome = "Sede", rotulo = "Sede", cor = Color3.fromRGB(70, 140, 205), baixo = CfgSobrevivencia.estamina.fomeBaixa },
	{ nome = "Calor", rotulo = "Calor", cor = Color3.fromRGB(215, 105, 55), baixo = CfgSobrevivencia.calorBaixo },
	{
		nome = "Estamina",
		rotulo = "Estamina",
		cor = Color3.fromRGB(190, 190, 80),
		baixo = CfgSobrevivencia.estamina.minimoParaVoltarACorrer,
	},
}

-- boneco visto de frente, em px dentro de 56×100: parte → x, y, largura, altura
local BONECO = {
	Cabeca = { 19, 0, 18, 18 },
	Torso = { 15, 20, 26, 36 },
	BracoE = { 3, 20, 10, 34 },
	BracoD = { 43, 20, 10, 34 },
	PernaE = { 15, 58, 12, 40 },
	PernaD = { 29, 58, 12, 40 },
}

local CAUSAS = {
	monstro = "Um monstro te pegou.",
	jogador = "Outro jogador te matou.",
	queda = "Você caiu de muito alto.",
	fome = "Você morreu de fome.",
	sede = "Você morreu de sede.",
	frio = "Você morreu de frio.",
	vazio = "Você caiu no vazio.",
}

local function criar(classe: string, propriedades: { [string]: any }, pai: Instance?): any
	local inst = Instance.new(classe)
	for nome, valor in propriedades do
		(inst :: any)[nome] = valor
	end
	inst.Parent = pai
	return inst
end

local function contorno(pai: Instance)
	criar("UIStroke", { Thickness = CONTORNO, Color = COR_CONTORNO }, pai)
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

-- verde (cheio) → amarelo → vermelho; zerada = preto
local function corDaVida(fracao: number): Color3
	if fracao <= 0 then
		return COR_ZERADA
	elseif fracao >= 0.5 then
		return COR_AMARELO:Lerp(COR_VERDE, (fracao - 0.5) / 0.5)
	end
	return COR_VERMELHO:Lerp(COR_AMARELO, fracao / 0.5)
end

local function tempoDeReaparecer(): number
	local ok, valor = pcall(function()
		return Players.RespawnTime
	end)
	if ok and type(valor) == "number" and valor > 0 then
		return math.floor(valor + 0.5)
	end
	return TEMPO_REAPARECER
end

function HudVida.iniciar()
	local tela = criar("ScreenGui", {
		Name = "HudVida",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, jogador:WaitForChild("PlayerGui"))

	-- Painel inferior esquerdo: status, boneco e barras
	local painel = criar("Frame", {
		Name = "Painel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(240, 128),
	}, tela)

	local status = texto(painel, {
		Name = "Status",
		Position = UDim2.fromOffset(66, -20),
		Size = UDim2.fromOffset(174, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local boneco = criar("Frame", {
		Name = "Boneco",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.fromOffset(56, 100),
	}, painel)
	local quadrosBoneco: { [string]: Frame } = {}
	for _, parte in CfgCorpo.ordem do
		local medidas = BONECO[parte]
		local quadro = criar("Frame", {
			Name = parte,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(medidas[1], medidas[2]),
			Size = UDim2.fromOffset(medidas[3], medidas[4]),
		}, boneco)
		contorno(quadro)
		quadrosBoneco[parte] = quadro
	end

	local lista = criar("Frame", {
		Name = "Barras",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.fromOffset(174, 128),
	}, painel)
	criar("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, lista)

	local barras: { [string]: { fundo: Frame, cheio: Frame, rotulo: TextLabel, dados: any } } = {}
	for i, dados in BARRAS do
		local fundo = criar("Frame", {
			Name = dados.nome,
			LayoutOrder = i,
			BackgroundColor3 = COR_FUNDO,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 26),
		}, lista)
		contorno(fundo)
		local cheio = criar("Frame", {
			Name = "Cheio",
			BackgroundColor3 = dados.cor,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, fundo)
		local rotulo = texto(fundo, {
			Name = "Rotulo",
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		})
		barras[dados.nome] = { fundo = fundo, cheio = cheio, rotulo = rotulo, dados = dados }
	end

	local function atualizarBarra(nome: string)
		local barra = barras[nome]
		local valor = jogador:GetAttribute(nome)
		if type(valor) ~= "number" then
			valor = CfgSobrevivencia.maximo
		end
		local fracao = math.clamp(valor / CfgSobrevivencia.maximo, 0, 1)
		barra.cheio.Size = UDim2.fromScale(fracao, 1)
		barra.cheio.BackgroundColor3 = if valor < barra.dados.baixo then COR_BAIXO else barra.dados.cor
		barra.rotulo.Text = string.format("%s  %d", barra.dados.rotulo, math.floor(valor + 0.5))
	end

	local function atualizarParte(parte: string)
		local valor = jogador:GetAttribute("Vida_" .. parte)
		if type(valor) ~= "number" then
			valor = CfgCorpo.partes[parte].vida
		end
		quadrosBoneco[parte].BackgroundColor3 = corDaVida(valor / CfgCorpo.partes[parte].vida)
	end

	local function atualizarStatus()
		if jogador:GetAttribute("Correndo") == true then
			status.Text = "Correndo"
		elseif jogador:GetAttribute("Deitado") == true then
			status.Text = "Deitado"
		elseif jogador:GetAttribute("Agachado") == true then
			status.Text = "Agachado"
		else
			status.Text = ""
		end
	end

	for _, dados in BARRAS do
		jogador:GetAttributeChangedSignal(dados.nome):Connect(function()
			atualizarBarra(dados.nome)
		end)
		atualizarBarra(dados.nome)
	end
	for _, parte in CfgCorpo.ordem do
		jogador:GetAttributeChangedSignal("Vida_" .. parte):Connect(function()
			atualizarParte(parte)
		end)
		atualizarParte(parte)
	end
	jogador:GetAttributeChangedSignal("Correndo"):Connect(atualizarStatus)
	jogador:GetAttributeChangedSignal("Agachado"):Connect(atualizarStatus)
	jogador:GetAttributeChangedSignal("Deitado"):Connect(atualizarStatus)
	atualizarStatus()

	-- Flash vermelho nas bordas (CanvasGroup para transparecer as quatro faixas juntas)
	local flash = criar("CanvasGroup", {
		Name = "Flash",
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 3,
	}, tela)
	local faixas = {
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.2), Rotation = 90 },
		{ Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.2), Rotation = 270 },
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.15, 1), Rotation = 0 },
		{ Position = UDim2.fromScale(0.85, 0), Size = UDim2.fromScale(0.15, 1), Rotation = 180 },
	}
	for _, faixa in faixas do
		local quadro = criar("Frame", {
			BackgroundColor3 = COR_VERMELHO,
			BorderSizePixel = 0,
			Position = faixa.Position,
			Size = faixa.Size,
		}, flash)
		criar("UIGradient", {
			Transparency = NumberSequence.new(0, 1),
			Rotation = faixa.Rotation,
		}, quadro)
	end
	local tweenFlash: Tween? = nil
	local function piscar(valor: number)
		if tweenFlash then
			tweenFlash:Cancel()
		end
		local intensidade = math.clamp(valor / 40, 0.35, 1)
		flash.GroupTransparency = 1 - intensidade * 0.85
		tweenFlash = TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
		tweenFlash:Play()
	end

	-- Tela de morte
	local morte = criar("Frame", {
		Name = "Morte",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = false,
		ZIndex = 5,
	}, tela)
	texto(morte, {
		Name = "Titulo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(500, 60),
		Text = "Você morreu",
		TextSize = 48,
		TextColor3 = COR_BAIXO,
		TextStrokeTransparency = 0,
		ZIndex = 6,
	})
	local causa = texto(morte, {
		Name = "Causa",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(500, 30),
		TextSize = 22,
		ZIndex = 6,
	})
	local contagem = texto(morte, {
		Name = "Contagem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(500, 26),
		TextSize = 20,
		ZIndex = 6,
	})

	-- Botão "Trocar personagem" (seletor, parte S): o cursor fica livre enquanto a tela de morte aparece.
	local trocar = criar("TextButton", {
		Name = "TrocarPersonagem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(240, 48),
		BackgroundColor3 = Color3.fromRGB(44, 44, 48),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = FONTE,
		Text = "Trocar personagem",
		TextSize = 20,
		TextColor3 = COR_TEXTO,
		ZIndex = 7,
	}, morte)
	contorno(trocar)
	trocar.Activated:Connect(function()
		local ok, Seletor = pcall(function()
			return require(script.Parent.SeletorPersonagem)
		end)
		if ok and Seletor and Seletor.abrir then
			Seletor.abrir({ modo = "morte" })
		end
	end)
	local mouseLivre = false
	local function liberarMouse(livre: boolean)
		if livre == mouseLivre then
			return
		end
		mouseLivre = livre
		local ok, Mouse = pcall(function()
			return require(script.Parent.Mouse)
		end)
		if ok and Mouse then
			if livre then
				Mouse.pedir("Morte")
			else
				Mouse.liberar("Morte")
			end
		end
	end

	local fichaMorte = 0 -- invalida a contagem anterior quando a tela some ou reaparece
	local function esconderMorte()
		fichaMorte += 1
		morte.Visible = false
		morte.BackgroundTransparency = 1
		liberarMouse(false)
	end
	local function mostrarMorte(motivo: string)
		fichaMorte += 1
		local minha = fichaMorte
		liberarMouse(true)
		causa.Text = CAUSAS[motivo] or "Você morreu."
		morte.BackgroundTransparency = 1
		morte.Visible = true
		TweenService:Create(morte, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.25 }):Play()
		task.spawn(function()
			for segundos = tempoDeReaparecer(), 1, -1 do
				if fichaMorte ~= minha then
					return
				end
				contagem.Text = string.format("Reaparecendo em %d", segundos)
				task.wait(1)
			end
			if fichaMorte == minha then
				contagem.Text = "Reaparecendo..."
			end
		end)
	end
	jogador.CharacterAdded:Connect(esconderMorte)
	jogador:GetAttributeChangedSignal("Morto"):Connect(function()
		if jogador:GetAttribute("Morto") ~= true then
			esconderMorte()
		end
	end)

	-- Avisos: centro inferior, acima da barra de slots do inventário
	local avisos = criar("Frame", {
		Name = "Avisos",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150), -- acima da barra de slots e da barra de uso do InventarioUI
		Size = UDim2.fromOffset(440, 100),
	}, tela)
	criar("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2),
	}, avisos)
	local ordemAviso = 0
	local function mostrarAviso(mensagem: string)
		ordemAviso += 1
		local atuais = {}
		for _, filho in avisos:GetChildren() do
			if filho:IsA("TextLabel") then
				table.insert(atuais, filho)
			end
		end
		table.sort(atuais, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #atuais >= MAX_AVISOS do
			table.remove(atuais, 1):Destroy()
		end
		local etiqueta = texto(avisos, {
			LayoutOrder = ordemAviso,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = mensagem,
			TextSize = 16,
			TextWrapped = true,
		})
		task.delay(DURACAO_AVISO, function()
			if etiqueta.Parent == nil then
				return
			end
			local saida =
				TweenService:Create(etiqueta, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
			saida.Completed:Once(function()
				etiqueta:Destroy()
			end)
			saida:Play()
		end)
	end

	Rede.evento("Dano").OnClientEvent:Connect(function(_parte: string, valor: number)
		piscar(type(valor) == "number" and valor or 10)
	end)
	Rede.evento("Morreu").OnClientEvent:Connect(function(motivo: string)
		mostrarMorte(tostring(motivo))
	end)
	Rede.evento("Aviso").OnClientEvent:Connect(function(mensagem: string)
		if type(mensagem) == "string" and mensagem ~= "" then
			mostrarAviso(mensagem)
		end
	end)
end

return HudVida
