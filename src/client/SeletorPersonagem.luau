-- SeletorPersonagem (cliente): tela de escolha do personagem. Abre ao entrar (depois das preferências carregarem) e pelo
-- botão "Trocar personagem" da tela de morte (HudVida). Só pede ao servidor (EscolherPersonagem) e mostra o resultado
-- (PersonagemEscolhido). Cartões com prévia 3D (ViewportFrame com um rig R15 estático vestido por PersonagemVisual),
-- teclado/gamepad (setas/D-pad, Enter/A confirma, Esc/B volta) e rodapé com os créditos CC BY 4.0.
-- Escolher NÃO muda atributo nenhum do jogo: só a aparência. Dono: parte S. Contrato: docs/personagens.md §2.
-- UI em código puro (sem spec da skill ui-roblox): texto >= 14, alvos >= 44 px, sem emoji, contorno único de 2.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Personagens"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Personagens"))
local PersonagemVisual = require(Shared:WaitForChild("PersonagemVisual"))
local Mouse = require(script.Parent:WaitForChild("Mouse"))

local SeletorPersonagem = {}

local jogador = Players.LocalPlayer

local FONTE = Enum.Font.Code
local TEXTO_MIN = 14
local CONTORNO = 2
local LARGURA_CARTAO = 190
local ESPERA_PREFERENCIAS = 20 -- s esperando o atributo PrefCarregadas antes de abrir com o padrão
local ESPERA_RESPOSTA = 8 -- s sem resposta do servidor: libera o botão Confirmar de novo
local DURACAO_AVISO = 4 -- s que a mensagem de recusa fica no subtítulo
local NOME_ACAO = "SeletorPersonagem"

local COR_FUNDO = Color3.fromRGB(8, 8, 10)
local COR_PAINEL = Color3.fromRGB(20, 20, 22)
local COR_CARTAO = Color3.fromRGB(30, 30, 33)
local COR_CARTAO_SEL = Color3.fromRGB(44, 38, 38)
local COR_BORDA = Color3.fromRGB(92, 92, 98)
local COR_SEL = Color3.fromRGB(190, 62, 52)
local COR_TEXTO = Color3.fromRGB(222, 222, 214)
local COR_TEXTO_FRACO = Color3.fromRGB(160, 160, 154)
local COR_ERRO = Color3.fromRGB(220, 110, 90)
local COR_BOTAO = Color3.fromRGB(44, 44, 48)
local COR_CONFIRMA = Color3.fromRGB(120, 44, 38)
local COR_VIEWPORT = Color3.fromRGB(14, 14, 16)

local SUBTITULO = "Só muda a aparência: vida, velocidade e dano são iguais para todos."

type Cartao = {
	n: number,
	botao: TextButton,
	traco: UIStroke,
	nome: TextLabel,
	rig: Model?,
	centro: Vector3?,
}

local lista = Regras.ordenar(Cfg.lista)
local creditos = table.concat(Regras.creditos(Cfg.lista), "\n")

local tela: ScreenGui
local subtitulo: TextLabel
local rodapeCreditos: TextLabel
local botaoConfirmar: TextButton
local botaoVoltar: TextButton
local cartoes: { Cartao } = {}

local aberto = false
local modo = "entrada" -- "entrada" (primeiro personagem) | "morte" (trocar depois de morrer)
local selecionado = 1
local enviando = false
local fichaEnvio = 0
local fichaAviso = 0
local giro: RBXScriptConnection? = nil

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
		TextSize = TEXTO_MIN,
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = COR_FUNDO,
	}
	for nome, valor in propriedades do
		base[nome] = valor
	end
	return criar("TextLabel", base, pai)
end

local function jaEscolheu(): boolean
	return jogador:GetAttribute("PersonagemId") ~= nil
end

local function tocarClique()
	pcall(function()
		require(script.Parent.SonsLocal).tocar("Clique")
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- Prévia 3D
----------------------------------------------------------------------------------------------------------------------

-- Enquadra o rig: câmera de frente (o personagem olha para -Z), distância que cabe em altura e largura.
local function enquadrar(viewport: ViewportFrame, camera: Camera, rig: Model)
	local cf, tamanho = rig:GetBoundingBox()
	local metade = math.rad(Cfg.previa.fov / 2)
	local tamanhoPixels = viewport.AbsoluteSize
	local aspecto = if tamanhoPixels.Y > 0 then tamanhoPixels.X / tamanhoPixels.Y else 0.9
	local porAltura = tamanho.Y / 2 * Cfg.previa.margem / math.tan(metade)
	local porLargura = math.max(tamanho.X, tamanho.Z) / 2 * Cfg.previa.margem / (math.tan(metade) * aspecto)
	local distancia = math.max(porAltura, porLargura) + math.max(tamanho.X, tamanho.Z) / 2
	local alvo = cf.Position
	camera.CFrame = CFrame.lookAt(alvo + Vector3.new(0, 0, -distancia), alvo)
end

local function montarPrevia(cartao: Cartao, entrada: Regras.Entrada, viewport: ViewportFrame, aviso: TextLabel)
	task.spawn(function()
		local ok, erro = pcall(function()
			local rig = PersonagemVisual.criarRigPrevia()
			PersonagemVisual.revestir(rig, entrada.id, { previa = true })
			local cf = rig:GetBoundingBox()
			rig.WorldPivot = cf
			rig.Parent = viewport
			local camera = criar("Camera", { FieldOfView = Cfg.previa.fov }, viewport)
			viewport.CurrentCamera = camera
			enquadrar(viewport, camera, rig)
			viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				enquadrar(viewport, camera, rig)
			end)
			cartao.rig = rig
			cartao.centro = cf.Position
		end)
		if ok then
			aviso:Destroy()
		else
			aviso.Text = "Sem prévia"
			warn("[SeletorPersonagem] prévia de " .. entrada.id .. ": " .. tostring(erro))
		end
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- Estado visual
----------------------------------------------------------------------------------------------------------------------

local function atualizarMarcacao()
	for _, c in cartoes do
		local sel = c.n == selecionado
		c.traco.Color = if sel then COR_SEL else COR_BORDA
		c.botao.BackgroundColor3 = if sel then COR_CARTAO_SEL else COR_CARTAO
		c.nome.TextColor3 = if sel then COR_SEL else COR_TEXTO
	end
end

local function selecionar(n: number)
	if n ~= selecionado then
		tocarClique()
	end
	selecionado = n
	atualizarMarcacao()
end

local function mover(passo: number)
	local indice = 1
	for i, e in lista do
		if e.n == selecionado then
			indice = i
		end
	end
	selecionar(lista[Regras.vizinho(#lista, indice, passo)].n)
end

local function liberarEnvio()
	enviando = false
	botaoConfirmar.Text = "Confirmar"
	botaoConfirmar.BackgroundColor3 = COR_CONFIRMA
end

local function avisar(mensagem: string)
	fichaAviso += 1
	local minha = fichaAviso
	subtitulo.Text = mensagem
	subtitulo.TextColor3 = COR_ERRO
	task.delay(DURACAO_AVISO, function()
		if fichaAviso == minha then
			subtitulo.Text = SUBTITULO
			subtitulo.TextColor3 = COR_TEXTO_FRACO
		end
	end)
end

----------------------------------------------------------------------------------------------------------------------
-- Abrir / fechar
----------------------------------------------------------------------------------------------------------------------

local function fechar()
	if not aberto then
		return
	end
	aberto = false
	tela.Enabled = false
	Mouse.liberar("Seletor")
	ContextActionService:UnbindAction(NOME_ACAO)
	if giro then
		giro:Disconnect()
		giro = nil
	end
	if modo == "morte" then
		Rede.evento("SeletorEstado"):FireServer(false)
	end
	fichaAviso += 1
end

local function confirmar()
	if not aberto or enviando then
		return
	end
	enviando = true
	fichaEnvio += 1
	local minha = fichaEnvio
	botaoConfirmar.Text = "Aguarde..."
	botaoConfirmar.BackgroundColor3 = COR_BOTAO
	tocarClique()
	Rede.evento("EscolherPersonagem"):FireServer(selecionado)
	task.delay(ESPERA_RESPOSTA, function()
		if enviando and fichaEnvio == minha then
			liberarEnvio()
			avisar("O servidor não respondeu. Tente de novo.")
		end
	end)
end

local function voltar()
	if aberto and modo == "morte" then
		tocarClique()
		fechar()
	end
end

local function aoTecla(_: string, estado: Enum.UserInputState, entrada: InputObject): Enum.ContextActionResult
	if estado ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local k = entrada.KeyCode
	if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then
		mover(-1)
	elseif k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then
		mover(1)
	elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter or k == Enum.KeyCode.ButtonA then
		confirmar()
	elseif k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB then
		if modo ~= "morte" then
			return Enum.ContextActionResult.Pass -- Esc abre o menu do Roblox como sempre
		end
		voltar()
	end
	return Enum.ContextActionResult.Sink
end

local function girarPrevias()
	local angulo = os.clock() * Cfg.previa.giro
	for _, c in cartoes do
		if c.rig and c.centro then
			c.rig:PivotTo(CFrame.new(c.centro) * CFrame.Angles(0, angulo, 0))
		end
	end
end

-- opcoes.modo: "entrada" (padrão) ou "morte"; opcoes.selecionado: n marcado ao abrir.
function SeletorPersonagem.abrir(opcoes: { modo: string?, selecionado: number? }?)
	if aberto or not tela then
		return
	end
	modo = if opcoes and opcoes.modo == "morte" then "morte" else "entrada"
	if modo == "entrada" and jaEscolheu() then
		return
	end

	local atual = Regras.porId(Cfg.lista, jogador:GetAttribute("PersonagemId"))
	local inicial = if opcoes and opcoes.selecionado
		then opcoes.selecionado
		elseif modo == "morte" and atual then atual.n
		else Regras.nInicial(Cfg.lista, jogador:GetAttribute("Pref_Personagem"), Cfg.padrao)
	selecionado = (Regras.validarEscolha(Cfg.lista, inicial) or Regras.porId(Cfg.lista, Cfg.padrao) or lista[1]).n
	atualizarMarcacao()
	liberarEnvio()
	subtitulo.Text = SUBTITULO
	subtitulo.TextColor3 = COR_TEXTO_FRACO
	botaoVoltar.Visible = modo == "morte"
	rodapeCreditos.Size = UDim2.new(1, if modo == "morte" then -320 else -190, 1, 0)

	aberto = true
	tela.Enabled = true
	Mouse.pedir("Seletor")
	ContextActionService:BindActionAtPriority(
		NOME_ACAO,
		aoTecla,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.Escape,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB
	)
	giro = RunService.RenderStepped:Connect(girarPrevias)
	if modo == "morte" then
		Rede.evento("SeletorEstado"):FireServer(true)
	end
end

function SeletorPersonagem.aberto(): boolean
	return aberto
end

----------------------------------------------------------------------------------------------------------------------
-- Construção
----------------------------------------------------------------------------------------------------------------------

local function criarCartao(entrada: Regras.Entrada, pai: Instance, ordem: number)
	local botao = criar("TextButton", {
		Name = entrada.id,
		LayoutOrder = ordem,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = COR_CARTAO,
		BorderSizePixel = 0,
		Size = UDim2.new(0, LARGURA_CARTAO, 1, -12),
	}, pai)
	local traco = criar("UIStroke", { Thickness = CONTORNO, Color = COR_BORDA }, botao)
	local viewport = criar("ViewportFrame", {
		Name = "Previa",
		BackgroundColor3 = COR_VIEWPORT,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0.55, 0),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 240, 225),
		LightDirection = Vector3.new(0.3, -0.6, 1),
		Active = false,
	}, botao)
	local aviso = texto(viewport, {
		Name = "Carregando",
		Size = UDim2.fromScale(1, 1),
		Text = "...",
		TextColor3 = COR_TEXTO_FRACO,
	})
	local nome = texto(botao, {
		Name = "Nome",
		Position = UDim2.new(0, 8, 0.55, 12),
		Size = UDim2.new(1, -16, 0, 22),
		Text = entrada.nome,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	texto(botao, {
		Name = "Descricao",
		Position = UDim2.new(0, 8, 0.55, 36),
		Size = UDim2.new(1, -16, 0.45, -40),
		Text = entrada.descricao,
		TextColor3 = COR_TEXTO_FRACO,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local cartao: Cartao = { n = entrada.n, botao = botao, traco = traco, nome = nome, rig = nil, centro = nil }
	table.insert(cartoes, cartao)
	botao.Activated:Connect(function()
		selecionar(entrada.n)
	end)
	montarPrevia(cartao, entrada, viewport, aviso)
end

local function criarBotao(
	pai: Instance,
	nome: string,
	rotulo: string,
	cor: Color3,
	x: number,
	largura: number
): TextButton
	local botao = criar("TextButton", {
		Name = nome,
		AutoButtonColor = true,
		Text = rotulo,
		Font = FONTE,
		TextSize = 20,
		TextColor3 = COR_TEXTO,
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(largura, 48),
	}, pai)
	criar("UIStroke", { Thickness = CONTORNO, Color = COR_BORDA }, botao)
	return botao
end

local function construir()
	tela = criar("ScreenGui", {
		Name = "SeletorPersonagem",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, jogador:WaitForChild("PlayerGui"))

	criar("Frame", {
		Name = "Fundo",
		BackgroundColor3 = COR_FUNDO,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true, -- engole os cliques para o jogo atrás
	}, tela)

	local painel = criar("Frame", {
		Name = "Painel",
		BackgroundColor3 = COR_PAINEL,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.92),
	}, tela)
	criar("UIStroke", { Thickness = CONTORNO, Color = COR_BORDA }, painel)
	criar("UISizeConstraint", { MaxSize = Vector2.new(1100, 720) }, painel)
	criar("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}, painel)

	texto(painel, {
		Name = "Titulo",
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Escolha seu personagem",
		TextSize = 28,
	})
	subtitulo = texto(painel, {
		Name = "Subtitulo",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		Text = SUBTITULO,
		TextColor3 = COR_TEXTO_FRACO,
		TextWrapped = true,
	})

	local faixa = criar("ScrollingFrame", {
		Name = "Lista",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -128),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
	}, painel)
	criar("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, faixa)
	for i, entrada in lista do
		criarCartao(entrada, faixa, i)
	end

	local rodape = criar("Frame", {
		Name = "Rodape",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56),
	}, painel)
	rodapeCreditos = texto(rodape, {
		Name = "Creditos",
		Size = UDim2.new(1, -190, 1, 0),
		Text = creditos,
		TextColor3 = COR_TEXTO_FRACO,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	botaoConfirmar = criarBotao(rodape, "Confirmar", "Confirmar", COR_CONFIRMA, 0, 170)
	botaoVoltar = criarBotao(rodape, "Voltar", "Voltar", COR_BOTAO, -182, 120)
	botaoVoltar.Visible = false
	botaoConfirmar.Activated:Connect(confirmar)
	botaoVoltar.Activated:Connect(voltar)
end

-- Espera as preferências do servidor (para abrir já marcando o personagem salvo) e abre o seletor.
local function abrirNaEntrada()
	local t0 = os.clock()
	while jogador:GetAttribute("PrefCarregadas") ~= true and os.clock() - t0 < ESPERA_PREFERENCIAS do
		task.wait(0.2)
	end
	if not jaEscolheu() then
		SeletorPersonagem.abrir({ modo = "entrada" })
	end
end

function SeletorPersonagem.iniciar()
	construir()

	Rede.evento("PersonagemEscolhido").OnClientEvent:Connect(function(ok: unknown, _n: unknown, mensagem: unknown)
		if ok == true then
			fechar()
		else
			liberarEnvio()
			avisar(if type(mensagem) == "string" and mensagem ~= "" then mensagem else "Não foi possível escolher.")
		end
	end)
	Rede.evento("AbrirSeletor").OnClientEvent:Connect(function(salvo: unknown)
		if not jaEscolheu() then
			SeletorPersonagem.abrir({ modo = "entrada", selecionado = if type(salvo) == "number" then salvo else nil })
		end
	end)
	-- Aberto pela morte e o personagem nasceu (tempo acabou): fecha sozinho.
	jogador.CharacterAdded:Connect(function()
		if aberto and modo == "morte" then
			fechar()
		end
	end)

	task.spawn(abrirNaEntrada)
end

return SeletorPersonagem
