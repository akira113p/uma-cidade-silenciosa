-- RespiracaoMinigame: o minigame de segurar a respiração (docs/som.md §13). O servidor abre ("iniciar"), atualiza a proximidade e fecha ("fim");
-- aqui o jogador segura a tecla para manter o marcador (o pulmão) dentro da zona. Tensão cheia = arfou: avisa o servidor (RespiracaoFalhou).
-- O cliente NUNCA diz "venci": o sucesso é o servidor fechar o minigame (monstro foi embora, fôlego acabou etc.). Regra pura: Regras/Respiracao.
-- Ligado por HudSom.iniciar (o init do cliente não o lista). A UI é montada por código; a spec do ui-roblox ficou como pendência.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Respiracao"))
local CfgMovimento = require(Shared.Config:WaitForChild("Movimento"))
local R = require(Shared:WaitForChild("Regras"):WaitForChild("Respiracao"))
local SonsLocal = require(script.Parent.SonsLocal)

local RespiracaoMinigame = {}

local ACAO = "RespiracaoJogo"
local DT_MAXIMO = 0.1 -- s: um engasgo do quadro não pode estourar a tensão de uma vez
local PRETO = Color3.fromRGB(0, 0, 0)
local COR_BARRA = Color3.fromRGB(18, 18, 20)
local COR_ZONA = Color3.fromRGB(150, 196, 150)
local COR_MARCADOR = Color3.fromRGB(240, 240, 232)
local COR_TENSAO_BAIXA = Color3.fromRGB(214, 184, 64)
local COR_TENSAO_ALTA = Color3.fromRGB(204, 64, 52)
local COR_TEXTO = Color3.fromRGB(230, 230, 224)
local NOME_EQUALIZADOR = "AbafarRespiracao"
local GRUPOS_ABAFADOS = { "Efeitos", "Local_Efeitos" }

type Sessao = {
	estado: R.Estado,
	segurando: boolean,
	gui: ScreenGui,
	atualizar: (R.Estado) -> (),
	conexao: RBXScriptConnection,
	avisou: boolean,
	proximidade: number,
}

local jogador = Players.LocalPlayer
local rng = Random.new()
local sessao: Sessao? = nil
local dicaMostrada = false -- a dica de 1 linha só aparece na primeira vez

local function teclas(): { Enum.KeyCode }
	local lista = {}
	for _, nome in CfgMovimento.teclas.prenderRespiracao do
		local tecla = (Enum.KeyCode :: any)[nome]
		if tecla then
			table.insert(lista, tecla)
		else
			warn("[RespiracaoMinigame] tecla desconhecida em Config/Movimento: " .. nome)
		end
	end
	return lista
end

local function frame(pai: Instance, nome: string, cor: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BackgroundColor3 = cor
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = pai
	return f
end

-- Uma borda da vinheta: escura na ponta e transparente para dentro da tela (UIGradient). A opacidade geral sobe com a tensão.
local function borda(
	pai: Instance,
	nome: string,
	ancora: Vector2,
	posicao: UDim2,
	tamanho: UDim2,
	rotacao: number
): Frame
	local f = frame(pai, nome, PRETO)
	f.AnchorPoint = ancora
	f.Position = posicao
	f.Size = tamanho
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotacao
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	return f
end

-- Monta a tela e devolve a função que a redesenha a cada quadro.
local function montarGui(): (ScreenGui, (R.Estado) -> ())
	local c = Cfg.cliente
	local gui = Instance.new("ScreenGui")
	gui.Name = "RespiracaoMinigame"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = jogador:WaitForChild("PlayerGui")

	local l = c.vinhetaLargura
	local bordas = {
		borda(gui, "Esquerda", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(l, 1), 0),
		borda(gui, "Direita", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(l, 1), 180),
		borda(gui, "Topo", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, l * 0.6), 90),
		borda(gui, "Base", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, l * 0.6), 270),
	}

	local barra = frame(gui, "Barra", COR_BARRA)
	barra.AnchorPoint = Vector2.new(0.5, 0.5)
	barra.Position = UDim2.new(0.5, c.barra.deslocamentoX, 0.5, 0)
	barra.Size = UDim2.fromOffset(c.barra.largura, c.barra.altura)
	barra.BackgroundTransparency = 0.25

	local zona = frame(barra, "Zona", COR_ZONA)
	zona.Size = UDim2.fromScale(1, Cfg.jogo.larguraLonge)

	local marcador = frame(barra, "Marcador", COR_MARCADOR)
	marcador.AnchorPoint = Vector2.new(0.5, 0.5)
	marcador.Size = UDim2.new(1.5, 0, 0, 6)
	marcador.ZIndex = 2

	-- tensão: faixa fina ao lado da barra, enche de baixo para cima
	local fundoTensao = frame(gui, "Tensao", COR_BARRA)
	fundoTensao.AnchorPoint = Vector2.new(0, 0.5)
	fundoTensao.Position = UDim2.new(0.5, c.barra.deslocamentoX + c.barra.largura / 2 + 8, 0.5, 0)
	fundoTensao.Size = UDim2.fromOffset(6, c.barra.altura)
	fundoTensao.BackgroundTransparency = 0.25
	local enchimento = frame(fundoTensao, "Enchimento", COR_TENSAO_BAIXA)
	enchimento.AnchorPoint = Vector2.new(0, 1)
	enchimento.Position = UDim2.fromScale(0, 1)
	enchimento.Size = UDim2.fromScale(1, 0)

	-- dica de 1 linha, só na primeira vez
	if not dicaMostrada then
		dicaMostrada = true
		local dica = Instance.new("TextLabel")
		dica.Name = "Dica"
		dica.BackgroundTransparency = 1
		dica.Font = Enum.Font.Code
		dica.Text = c.dica
		dica.TextSize = 16
		dica.TextColor3 = COR_TEXTO
		dica.TextStrokeTransparency = 0.5
		dica.AnchorPoint = Vector2.new(0.5, 1)
		dica.Position = UDim2.new(0.5, c.barra.deslocamentoX, 0.5, -c.barra.altura / 2 - 12)
		dica.Size = UDim2.fromOffset(340, 22)
		dica.Parent = gui
		task.delay(c.avisoSegundos, function()
			dica:Destroy()
		end)
	end

	local function atualizar(e: R.Estado)
		local w = R.largura(e.proximidade, Cfg)
		zona.Size = UDim2.fromScale(1, w)
		zona.Position = UDim2.fromScale(0, 1 - (e.zona + w / 2))
		marcador.Position = UDim2.fromScale(0.5, 1 - e.p)
		enchimento.Size = UDim2.fromScale(1, math.clamp(e.tensao, 0, 1))
		enchimento.BackgroundColor3 = COR_TENSAO_BAIXA:Lerp(COR_TENSAO_ALTA, math.clamp(e.tensao, 0, 1))
		local opacidade = c.vinhetaMax * math.clamp(e.tensao, 0, 1)
		for _, b in bordas do
			b.BackgroundTransparency = 1 - opacidade
		end
	end
	return gui, atualizar
end

-- Áudio abafado (agudo cortado) nos grupos de efeitos enquanto o minigame durar, para vender a tensão.
local function abafar(ligado: boolean)
	for _, nome in GRUPOS_ABAFADOS do
		local grupo = SoundService:FindFirstChild(nome)
		if grupo and grupo:IsA("SoundGroup") then
			local existente = grupo:FindFirstChild(NOME_EQUALIZADOR)
			if ligado and not existente then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.Name = NOME_EQUALIZADOR
				eq.HighGain = Cfg.cliente.abafar.HighGain
				eq.Parent = grupo
			elseif not ligado and existente then
				existente:Destroy()
			end
		end
	end
end

-- Batimento: o loop do coração, mais rápido com a proximidade.
local function batimento(ligado: boolean, proximidade: number)
	SonsLocal.loop("Coracao", ligado)
	local som = SoundService:FindFirstChild("Coracao")
	if ligado and som and som:IsA("Sound") then
		som.PlaybackSpeed = Cfg.cliente.batimento.base + Cfg.cliente.batimento.extra * proximidade
	end
end

local function fechar()
	local s = sessao
	if not s then
		return
	end
	sessao = nil
	s.conexao:Disconnect()
	ContextActionService:UnbindAction(ACAO)
	s.gui:Destroy()
	abafar(false)
	batimento(false, 0)
end

local function aoTecla(_nome: string, estado: Enum.UserInputState)
	local s = sessao
	if not s then
		return Enum.ContextActionResult.Pass
	end
	if estado == Enum.UserInputState.Begin then
		s.segurando = true
	elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
		s.segurando = false
	end
	-- engole a tecla (Espaço): durante o minigame ela não pula
	return Enum.ContextActionResult.Sink
end

local function abrir(dados: any)
	if sessao then
		fechar()
	end
	if type(dados) ~= "table" or type(dados.proximidade) ~= "number" then
		return
	end
	local estamina = if type(dados.estamina) == "number" then dados.estamina else 100
	local gui, atualizar = montarGui()
	local estadoInicial = R.novo(dados.proximidade, estamina, Cfg)
	local nova: Sessao = {
		estado = estadoInicial,
		segurando = false,
		gui = gui,
		atualizar = atualizar,
		avisou = false,
		proximidade = dados.proximidade,
		conexao = RunService.RenderStepped:Connect(function(dt)
			local s = sessao
			if not s then
				return
			end
			s.estado = R.passo(s.estado, s.segurando, math.min(dt, DT_MAXIMO), function()
				return rng:NextNumber()
			end, Cfg)
			s.atualizar(s.estado)
			if s.estado.falhou and not s.avisou then
				s.avisou = true
				Rede.evento("RespiracaoFalhou"):FireServer()
				-- o servidor fecha com "arfou"; se ele ignorar (cedo demais), fecha aqui para não travar a tela
				local minha = s
				task.delay(1, function()
					if sessao == minha then
						fechar()
					end
				end)
			end
		end),
	}
	sessao = nova
	atualizar(estadoInicial)
	-- prioridade alta: passa na frente do pulo do PlayerModule (jumpAction, prioridade padrão) enquanto o minigame durar
	ContextActionService:BindActionAtPriority(
		ACAO,
		aoTecla,
		true,
		Enum.ContextActionPriority.High.Value,
		table.unpack(teclas())
	)
	ContextActionService:SetTitle(ACAO, Cfg.cliente.botaoTitulo) -- botão de toque "Segurar"
	abafar(true)
	batimento(true, dados.proximidade)
end

function RespiracaoMinigame.iniciar()
	Rede.evento("Respiracao").OnClientEvent:Connect(function(acao: string, dados: any)
		if acao == "iniciar" then
			abrir(dados)
		elseif acao == "proximidade" then
			local s = sessao
			if s and type(dados) == "number" then
				s.proximidade = dados
				s.estado = R.comProximidade(s.estado, dados)
				batimento(true, dados)
			end
		elseif acao == "fim" then
			fechar()
		end
	end)
	-- morrer ou trocar de personagem com o minigame aberto: fecha
	jogador.CharacterRemoving:Connect(fechar)
end

return RespiracaoMinigame
