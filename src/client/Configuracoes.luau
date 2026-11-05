-- Configuracoes: painel de preferências (tecla P). Só pede ao servidor (SalvarPreferencias) e mostra o atributo
-- Pref_* quando ele volta. Dono: P2. Contrato: docs/arquitetura.md §P2.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Config = Shared:WaitForChild("Config")
local ConfigCamera = require(Config:WaitForChild("Camera"))
local ConfigMovimento = require(Config:WaitForChild("Movimento"))

local Configuracoes = {}

local COR_FUNDO = Color3.fromRGB(18, 18, 20)
local COR_BORDA = Color3.fromRGB(92, 92, 98)
local COR_TEXTO = Color3.fromRGB(222, 222, 214)
local COR_BOTAO = Color3.fromRGB(44, 44, 48)
local COR_ATIVO = Color3.fromRGB(86, 128, 84)
local FONTE = Enum.Font.Code

local ALTURA_LINHA = 48 -- >= 44 px de alvo de toque
local INTERVALO_ENVIO = 1.05 -- o servidor aceita 1 SalvarPreferencias por segundo
local VALIDADE_PEDIDO = 2 -- s que um pedido enviado vale como base do próximo clique

local INTENSIDADES = { 0, 25, 50, 75, 100 }

local jogador = Players.LocalPlayer
local painel: Frame
local atualizadores: { () -> () } = {}

local pendente: { [string]: any } = {} -- ainda não enviado
local pedido: { [string]: { valor: any, tempo: number } } = {} -- último valor pedido por chave
local ultimoEnvio = 0
local envioAgendado = false

local function tocarClique()
	pcall(function()
		require(script.Parent.SonsLocal).tocar("Clique")
	end)
end

-- Valor em que o próximo clique se baseia: o último pedido (se recente, o atributo ainda não voltou) ou o atributo.
local function valorBase(chave: string): any
	local p = pedido[chave]
	if p and os.clock() - p.tempo < VALIDADE_PEDIDO then
		return p.valor
	end
	local v = jogador:GetAttribute(chave)
	if v == nil then
		return ConfigCamera.preferenciasPadrao[chave]
	end
	return v
end

-- Cliques seguidos viram um único envio (o servidor limita a 1/s e descartaria o resto).
local function enviar()
	envioAgendado = false
	if next(pendente) == nil then
		return
	end
	local lote = pendente
	pendente = {}
	ultimoEnvio = os.clock()
	Rede.evento("SalvarPreferencias"):FireServer(lote)
end

local function pedir(chave: string, valor: any)
	tocarClique()
	pendente[chave] = valor
	pedido[chave] = { valor = valor, tempo = os.clock() }
	if envioAgendado then
		return
	end
	envioAgendado = true
	task.delay(math.max(0, ultimoEnvio + INTERVALO_ENVIO - os.clock()), enviar)
end

local function criar(classe: string, propriedades: { [string]: any }, pai: Instance?): any
	local inst = Instance.new(classe)
	for k, v in propriedades do
		(inst :: any)[k] = v
	end
	inst.Parent = pai
	return inst
end

local function botao(texto: string, pai: Instance, propriedades: { [string]: any }?): TextButton
	local b = criar("TextButton", {
		Text = texto,
		Font = FONTE,
		TextSize = 20,
		TextColor3 = COR_TEXTO,
		BackgroundColor3 = COR_BOTAO,
		BorderSizePixel = 1,
		BorderColor3 = COR_BORDA,
		AutoButtonColor = true,
		Size = UDim2.fromScale(1, 1),
	}, pai)
	if propriedades then
		for k, v in propriedades do
			(b :: any)[k] = v
		end
	end
	return b
end

local function marcar(b: TextButton, ativo: boolean)
	b.BackgroundColor3 = if ativo then COR_ATIVO else COR_BOTAO
end

-- Linha com rótulo à esquerda e um contêiner de controle à direita.
local function linha(ordem: number, rotulo: string, lista: Instance): Frame
	local l = criar("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ALTURA_LINHA),
		LayoutOrder = ordem,
	}, lista)
	criar("TextLabel", {
		BackgroundTransparency = 1,
		Text = rotulo,
		Font = FONTE,
		TextSize = 18,
		TextColor3 = COR_TEXTO,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.fromScale(0.4, 1),
	}, l)
	return criar("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.6, 1),
	}, l)
end

local function linhaLigaDesliga(ordem: number, rotulo: string, chave: string, lista: Instance)
	local b = botao("", linha(ordem, rotulo, lista))
	b.Activated:Connect(function()
		pedir(chave, not valorBase(chave))
	end)
	table.insert(atualizadores, function()
		local ligado = valorBase(chave) ~= false
		b.Text = if ligado then "Ligado" else "Desligado"
		marcar(b, ligado)
	end)
end

local function linhaOpcoes(ordem: number, rotulo: string, chave: string, valores: { number }, lista: Instance)
	local area = linha(ordem, rotulo, lista)
	criar("UIGridLayout", {
		CellSize = UDim2.new(1 / #valores, -4, 1, 0),
		CellPadding = UDim2.fromOffset(4, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, area)
	local botoes = {}
	for i, valor in valores do
		local b = botao(tostring(valor), area, { LayoutOrder = i, TextSize = 16 })
		b.Activated:Connect(function()
			pedir(chave, valor)
		end)
		botoes[valor] = b
	end
	table.insert(atualizadores, function()
		local atual = jogador:GetAttribute(chave)
		for valor, b in botoes do
			marcar(b, valor == atual)
		end
	end)
end

local function linhaPasso(ordem: number, rotulo: string, chave: string, passo: number, lista: Instance)
	local area = linha(ordem, rotulo, lista)
	local faixa = ConfigCamera.limitesPreferencias[chave]
	local menos = botao("-", area, { Size = UDim2.new(0, 52, 1, 0) })
	local mais = botao("+", area, {
		Size = UDim2.new(0, 52, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
	})
	local valorLabel = criar("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONTE,
		TextSize = 20,
		TextColor3 = COR_TEXTO,
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -112, 1, 0),
	}, area)
	local function mudar(delta: number)
		pedir(chave, math.clamp(valorBase(chave) + delta, faixa[1], faixa[2]))
	end
	menos.Activated:Connect(function()
		mudar(-passo)
	end)
	mais.Activated:Connect(function()
		mudar(passo)
	end)
	table.insert(atualizadores, function()
		local v = jogador:GetAttribute(chave)
		valorLabel.Text = if type(v) == "number" then tostring(v) else "?"
	end)
end

local function construir(): ScreenGui
	local gui = criar("ScreenGui", {
		Name = "Configuracoes",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)

	painel = criar("Frame", {
		Name = "Painel",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.9),
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 2,
		BorderColor3 = COR_BORDA,
	}, gui)
	criar("UISizeConstraint", { MaxSize = Vector2.new(460, 440) }, painel)

	criar("TextLabel", {
		Name = "Titulo",
		Text = "Configurações",
		Font = FONTE,
		TextSize = 24,
		TextColor3 = COR_TEXTO,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, painel)

	local rolagem = criar("ScrollingFrame", {
		Name = "Lista",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 1, -60),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
	}, painel)
	criar("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, rolagem)

	linhaLigaDesliga(1, "Tremor da câmera", "Pref_Tremor", rolagem)
	linhaOpcoes(2, "Intensidade (%)", "Pref_Intensidade", INTENSIDADES, rolagem)
	linhaPasso(3, "Campo de visão", "Pref_FOV", 5, rolagem)
	linhaLigaDesliga(4, "Filtro de imagem", "Pref_FiltroPS1", rolagem)
	linhaLigaDesliga(5, "Aberração cromática", "Pref_Aberracao", rolagem)
	linhaLigaDesliga(6, "Distorção de lente (gráfico alto)", "Pref_Lente", rolagem)
	linhaLigaDesliga(7, "Neblina em camadas", "Pref_NeblinaVolume", rolagem)
	linhaPasso(8, "Volume (%)", "Pref_Volume", 10, rolagem)

	local fechar = botao("Fechar", rolagem, { Size = UDim2.new(1, 0, 0, ALTURA_LINHA), LayoutOrder = 9 })
	fechar.Activated:Connect(function()
		tocarClique()
		Configuracoes.fechar()
	end)

	-- Celular não tem a tecla P: botão pequeno no canto abre o painel.
	if UserInputService.TouchEnabled then
		local abrir = botao("Config", gui, {
			Name = "Abrir",
			Size = UDim2.fromOffset(72, 44),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 60),
		})
		abrir.Activated:Connect(function()
			tocarClique()
			Configuracoes.alternar()
		end)
	end

	return gui
end

local function atualizarTudo()
	for _, f in atualizadores do
		f()
	end
end

-- O cursor é do módulo Mouse: livre só com o painel aberto.
local function definirVisivel(visivel: boolean)
	painel.Visible = visivel
	local ok, Mouse = pcall(require, script.Parent.Mouse)
	if ok then
		if visivel then
			Mouse.pedir("Configuracoes")
		else
			Mouse.liberar("Configuracoes")
		end
	end
end

function Configuracoes.abrir()
	definirVisivel(true)
end

function Configuracoes.fechar()
	definirVisivel(false)
end

function Configuracoes.alternar()
	definirVisivel(not painel.Visible)
end

function Configuracoes.iniciar()
	local gui = construir()
	for chave in ConfigCamera.preferenciasPadrao do
		jogador:GetAttributeChangedSignal(chave):Connect(atualizarTudo)
	end
	atualizarTudo()
	gui.Parent = jogador:WaitForChild("PlayerGui")

	require(script.Parent.Teclas).ligar("configuracoes", ConfigMovimento.teclas.configuracoes, Configuracoes.alternar)
end

return Configuracoes
