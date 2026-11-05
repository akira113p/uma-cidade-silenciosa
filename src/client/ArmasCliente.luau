-- ArmasCliente: entrada (clique/botão/R), previsão local de pente e recarga, sinais para os módulos visuais, coice,
-- mira central com abertura e marcador de acerto. Dono: A5 (docs/armas.md §10.1; versão antiga: P7).
-- O cliente só pede (Atacar, Recarregar) e mostra; quem decide cadência, pente, dano e ruído é o servidor
-- (src/server/Armas.luau). Nada aqui é verdade de jogo: o contador de pente é só previsão e se corrige pelo atributo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Config = Shared:WaitForChild("Config")
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgCorpo = require(Config:WaitForChild("Corpo"))
local CfgMovimento = require(Config:WaitForChild("Movimento"))
local CfgVista = require(Config:WaitForChild("ArmasVista"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Armas"))
local Camera = require(script.Parent.Camera)
local Mouse = require(script.Parent.Mouse)
local SonsLocal = require(script.Parent.SonsLocal)
local Teclas = require(script.Parent.Teclas)
local ArmasSinais = require(script.Parent.ArmasSinais)

local ArmasCliente = {}

local jogador = Players.LocalPlayer
local FOLGA_LOCAL = 0.02 -- s: espera um pouco além da cadência para o servidor nunca rejeitar por jitter
local FOLGA_QUADRO = 0.034 -- s: atraso de até 2 quadros ainda conta como "no ritmo" (não perde cadência por arredondar)
local JANELA_CLIQUE = 0.25 -- s: clique de arma semiautomática feito um pouco antes da cadência vale quando ela liberar
local SINCRONIA_PENTE = 0.3 -- s sem atirar para o contador local voltar a seguir o atributo Pente do servidor
local INTERVALO_VAZIO = 0.35 -- s entre cliques de gatilho vazio
local ESPERA_SERVIDOR = 0.8 -- s: se o servidor não confirmou a recarga (Recarregando) até aqui, o pedido foi recusado
local FOLGA_FIM_RECARGA = 0.35 -- s além da duração para dar a recarga por encerrada mesmo sem o servidor avisar
local FIM_NORMAL = 0.2 -- s: Recarregando falso mais cedo que (duração - isto) conta como recarga cancelada
local DISTANCIA_MIRA = 500 -- studs: ponto visado na 3ª pessoa quando o raio não acerta nada
local LIMIAR_ANDAR = 1 -- studs/s horizontais para a mira abrir como "andando"
local COR_ACERTO = Color3.fromRGB(255, 255, 255)
local COR_CABECA = Color3.fromRGB(255, 70, 60)

local segurando = false
local ultimoLocal = -math.huge
local ultimoVazio = -math.huge
local ultimoTiro = -math.huge
local penteLocal: number? = nil
local bloom = 0 -- graus; espelho visual do bloom do servidor (só estética da mira)
local indiceGolpe = 1 -- faca alterna estocada (1) e corte (2)
local idEquipado: string? = nil

local recarregandoLocal = false
local recargaId = ""
local recargaInicio = 0
local recargaDuracao = 0
local recargaConfirmada = false -- o servidor já mostrou Recarregando = true

local mira: Frame
local marcador: Frame
local ticks: { Frame } = {} -- cima, baixo, esquerda, direita
local gapMira = 8 -- px entre o centro e cada tick (suavizado)
local botaoRecarga: TextButton? = nil
local riscos: { Frame } = {}
local tween: Tween?
local rng = Random.new()

local function armaAtual()
	local id = jogador:GetAttribute("ArmaEquipada")
	if type(id) == "string" then
		return CfgArmas.armas[id]
	end
	return nil
end

local function ehFogo(arma: any): boolean
	return arma ~= nil and arma.tipo == "fogo"
end

local function podeAgir(): boolean
	return armaAtual() ~= nil
		and jogador:GetAttribute("Morto") ~= true
		and jogador:GetAttribute("Usando") ~= true
		and not Mouse.menuAberto()
end

-- Pente que o cliente acredita ter. nil = sem informação do servidor (não bloqueia o gatilho).
local function penteAtual(): number?
	local servidor = jogador:GetAttribute("Pente")
	if type(servidor) ~= "number" then
		penteLocal = nil
		return nil
	end
	if penteLocal ~= nil and os.clock() - ultimoTiro < SINCRONIA_PENTE then
		return penteLocal
	end
	penteLocal = nil
	return servidor
end

function ArmasCliente.pente(): number?
	return penteAtual()
end

function ArmasCliente.recarregando(): boolean
	return recarregandoLocal or jogador:GetAttribute("Recarregando") == true
end

-- Origem e direção do ataque. Em 1ª pessoa é a câmera (contrato). Em 3ª pessoa a câmera fica longe da cabeça e o
-- servidor rejeitaria a origem: parte da cabeça e mira no ponto que a câmera enxerga no centro da tela.
local function origemEDirecao(): (Vector3?, Vector3?)
	local camera = workspace.CurrentCamera
	local personagem = jogador.Character
	local cabeca = personagem and personagem:FindFirstChild("Head")
	if not (camera and personagem and cabeca and cabeca:IsA("BasePart")) then
		return nil, nil
	end
	local cf = camera.CFrame
	if (cf.Position - cabeca.Position).Magnitude <= 3 then
		return cf.Position, cf.LookVector
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personagem }
	local r = workspace:Raycast(cf.Position, cf.LookVector * DISTANCIA_MIRA, params)
	local alvo = if r then r.Position else cf.Position + cf.LookVector * DISTANCIA_MIRA
	local d = alvo - cabeca.Position
	if d.Magnitude < 0.01 then
		return nil, nil
	end
	return cabeca.Position, d.Unit
end

-- Recarga ----------------------------------------------------------------------------------------------------------

local function finalizarRecarga(cancelada: boolean)
	if not recarregandoLocal then
		return
	end
	recarregandoLocal = false
	recargaConfirmada = false
	penteLocal = nil -- o servidor acabou de mexer no pente: volta a seguir o atributo
	ultimoTiro = -math.huge
	ArmasSinais.disparar("recargaFim", recargaId, cancelada)
end

local function recarregar()
	local arma = armaAtual()
	local id = jogador:GetAttribute("ArmaEquipada")
	if not ehFogo(arma) or type(id) ~= "string" or not podeAgir() or ArmasCliente.recarregando() then
		return
	end
	local pente = penteAtual()
	local reserva = jogador:GetAttribute("Reserva")
	local nPente = pente or 0
	local nReserva = if type(reserva) == "number" then reserva else math.huge
	if nPente >= arma.pente or nReserva < 1 then
		return -- cheio ou sem munição: o servidor também recusaria (e avisaria)
	end
	local duracao = Regras.tempoRecarga(arma, nPente, nReserva)
	if duracao <= 0 or duracao == math.huge then
		return
	end
	recarregandoLocal = true
	recargaConfirmada = false
	recargaId = id
	recargaInicio = os.clock()
	recargaDuracao = duracao
	segurando = false
	ArmasSinais.disparar("recarregou", id, duracao)
	Rede.evento("Recarregar"):FireServer()
end

-- Disparo / golpe --------------------------------------------------------------------------------------------------

-- Devolve "ok" (pedido enviado), "cadencia" (ainda não liberou) ou "bloqueado" (vazio, recarregando, sem origem).
local function tentar(): string
	local arma = armaAtual()
	local id = jogador:GetAttribute("ArmaEquipada")
	if not arma or type(id) ~= "string" or not podeAgir() then
		return "bloqueado"
	end
	local agora = os.clock()
	if agora - ultimoLocal < arma.cadencia + FOLGA_LOCAL then
		return "cadencia"
	end

	local fogo = ehFogo(arma)
	local pente: number? = nil
	if fogo then
		pente = penteAtual()
		if ArmasCliente.recarregando() then
			-- Tubo: atirar interrompe a recarga e mantém o que já entrou (docs/armas.md §7.2). Pente: nega.
			if arma.recarga.tipo == "cartucho" and (pente or 0) > 0 then
				finalizarRecarga(true)
			else
				return "bloqueado"
			end
		end
		if pente ~= nil and pente <= 0 then
			if agora - ultimoVazio >= INTERVALO_VAZIO then
				ultimoVazio = agora
				ArmasSinais.disparar("vazio", id)
				-- o servidor nunca vê este gatilho (o cliente nem pede), então o clique é local
				if arma.somVazio then
					pcall(function()
						SonsLocal.tocar(arma.somVazio)
					end)
				end
			end
			return "bloqueado"
		end
	end

	local origem, direcao = origemEDirecao()
	if not (origem and direcao) then
		return "bloqueado"
	end

	-- Cadência sem perder quadros: se o tiro saiu no máximo 2 quadros depois de liberar, o relógio anda o período certo.
	local periodo = arma.cadencia + FOLGA_LOCAL
	ultimoLocal = if agora - ultimoLocal - periodo < FOLGA_QUADRO then ultimoLocal + periodo else agora

	if fogo then
		if pente ~= nil then
			penteLocal = pente - 1
		end
		ultimoTiro = agora
		bloom = Regras.bloomAposTiro(arma, bloom)
		ArmasSinais.disparar("disparou", id, origem, direcao)
		local coice = arma.coice
		if coice then
			local lado = if rng:NextNumber() < 0.5 then -1 else 1
			Camera.coice(coice.vertical, coice.horizontal * lado * rng:NextNumber(0.4, 1))
		end
	else
		local indice = 1
		if arma.classe == "faca" then
			indice = indiceGolpe
			indiceGolpe = 3 - indiceGolpe
		end
		ArmasSinais.disparar("golpeou", id, indice)
	end
	Rede.evento("Atacar"):FireServer(origem, direcao)
	return "ok"
end

local function comecar()
	if segurando then
		return
	end
	local arma = armaAtual()
	if not arma then
		return
	end
	segurando = true
	-- Semiautomática (e lançador): um pedido por clique, mas um clique um pouco adiantado espera a cadência liberar.
	local semi = ehFogo(arma) and arma.modo ~= "auto"
	local limite = os.clock() + JANELA_CLIQUE
	task.spawn(function()
		while segurando and podeAgir() do
			local resultado = tentar()
			if semi and (resultado == "ok" or resultado == "bloqueado" or os.clock() > limite) then
				break
			end
			task.wait()
		end
		segurando = false
	end)
end

-- Interface --------------------------------------------------------------------------------------------------------

local function criarRisco(rotacao: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(16, 2)
	f.Rotation = rotacao
	f.BorderSizePixel = 0
	f.BackgroundColor3 = COR_ACERTO
	f.BackgroundTransparency = 1
	return f
end

local function criarTick(pai: Instance, horizontal: boolean): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = if horizontal
		then UDim2.fromOffset(CfgVista.mira.tick, CfgVista.mira.espessura)
		else UDim2.fromOffset(CfgVista.mira.espessura, CfgVista.mira.tick)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Active = false
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = 1
	contorno.Color = Color3.new(0, 0, 0)
	contorno.Parent = f
	f.Parent = pai
	return f
end

local function criarInterface()
	local playerGui = jogador:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Mira"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false

	mira = Instance.new("Frame")
	mira.Name = "Ponto"
	mira.AnchorPoint = Vector2.new(0.5, 0.5)
	mira.Position = UDim2.fromScale(0.5, 0.5)
	mira.Size = UDim2.fromOffset(4, 4)
	mira.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	mira.BackgroundTransparency = 0.1
	mira.BorderSizePixel = 0
	mira.Active = false
	mira.Parent = gui
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = 1
	contorno.Color = Color3.new(0, 0, 0)
	contorno.Parent = mira

	-- Quatro ticks que se afastam do centro conforme o espalhamento (só arma de fogo).
	for i = 1, 4 do
		local t = criarTick(gui, i > 2)
		t.Name = "Tick" .. i
		table.insert(ticks, t)
	end

	marcador = Instance.new("Frame")
	marcador.Name = "MarcadorAcerto"
	marcador.AnchorPoint = Vector2.new(0.5, 0.5)
	marcador.Position = UDim2.fromScale(0.5, 0.5)
	marcador.Size = UDim2.fromOffset(16, 16)
	marcador.BackgroundTransparency = 1
	marcador.Active = false
	marcador.Parent = gui
	for _, rot in { 45, -45 } do
		local risco = criarRisco(rot)
		risco.Position = UDim2.fromScale(0.5, 0.5)
		risco.Parent = marcador
		table.insert(riscos, risco)
	end

	gui.Parent = playerGui

	-- Celular: botão grande no canto direito, só com arma equipada; o de recarga fica ao lado, só com arma de fogo.
	if UserInputService.TouchEnabled then
		local guiBotao = Instance.new("ScreenGui")
		guiBotao.Name = "BotaoAtaque"
		guiBotao.ResetOnSpawn = false
		guiBotao.DisplayOrder = 20
		guiBotao.Enabled = false
		local b = Instance.new("TextButton")
		b.Name = "Atacar"
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -24, 1, -120)
		b.Size = UDim2.fromOffset(84, 84)
		b.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
		b.BackgroundTransparency = 0.3
		b.BorderSizePixel = 0
		b.Text = "ATACAR"
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextSize = 16
		b.Font = Enum.Font.SourceSansBold
		b.AutoButtonColor = true
		b.Parent = guiBotao
		local cantos = Instance.new("UICorner")
		cantos.CornerRadius = UDim.new(1, 0)
		cantos.Parent = b
		b.InputBegan:Connect(function(entrada)
			if
				entrada.UserInputType == Enum.UserInputType.Touch
				or entrada.UserInputType == Enum.UserInputType.MouseButton1
			then
				comecar()
			end
		end)
		b.InputEnded:Connect(function(entrada)
			if
				entrada.UserInputType == Enum.UserInputType.Touch
				or entrada.UserInputType == Enum.UserInputType.MouseButton1
			then
				segurando = false
			end
		end)

		local r = Instance.new("TextButton")
		r.Name = "Recarregar"
		r.AnchorPoint = Vector2.new(1, 1)
		r.Position = UDim2.new(1, -24 - 84 - 12, 1, -120)
		r.Size = UDim2.fromOffset(60, 60)
		r.BackgroundColor3 = Color3.fromRGB(40, 48, 66)
		r.BackgroundTransparency = 0.3
		r.BorderSizePixel = 0
		r.Text = "R"
		r.TextColor3 = Color3.new(1, 1, 1)
		r.TextSize = 22
		r.Font = Enum.Font.SourceSansBold
		r.AutoButtonColor = true
		r.Visible = false
		r.Parent = guiBotao
		local cantosR = Instance.new("UICorner")
		cantosR.CornerRadius = UDim.new(1, 0)
		cantosR.Parent = r
		r.Activated:Connect(recarregar)
		botaoRecarga = r

		guiBotao.Parent = playerGui
	end
end

local function atualizarVisibilidade()
	local arma = armaAtual()
	local armado = arma ~= nil
	local playerGui = jogador:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("Mira")
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = armado
	end
	for _, t in ticks do
		t.Visible = ehFogo(arma)
	end
	local guiBotao = playerGui and playerGui:FindFirstChild("BotaoAtaque")
	if guiBotao and guiBotao:IsA("ScreenGui") then
		guiBotao.Enabled = armado
	end
	if botaoRecarga then
		botaoRecarga.Visible = ehFogo(arma)
	end
	if not armado then
		segurando = false
	end
end

local function aoMudarArma()
	local id = jogador:GetAttribute("ArmaEquipada")
	local novo = if type(id) == "string" and CfgArmas.armas[id] then id else nil
	atualizarVisibilidade()
	if novo == idEquipado then
		return
	end
	finalizarRecarga(true) -- trocar de arma cancela (o servidor também)
	idEquipado = novo
	-- o servidor não toca somEquipar (ninguém o designou, ver pendências "Armas"): sacar é um som local
	local cfg = if novo then CfgArmas.armas[novo] else nil
	if cfg and cfg.somEquipar then
		pcall(function()
			SonsLocal.tocar(cfg.somEquipar)
		end)
	end
	penteLocal = nil
	ultimoTiro = -math.huge
	bloom = 0
	indiceGolpe = 1
	segurando = false
	ArmasSinais.disparar("equipou", novo)
end

local function piscarAcerto(_alvoEhJogador: boolean, parte: string?)
	if tween then
		tween:Cancel()
	end
	local cor = if parte == "Cabeca" then COR_CABECA else COR_ACERTO
	for _, risco in riscos do
		risco.BackgroundColor3 = cor
		risco.BackgroundTransparency = 0
	end
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local ultimo: Tween?
	for _, risco in riscos do
		ultimo = TweenService:Create(risco, info, { BackgroundTransparency = 1 })
		ultimo:Play()
	end
	tween = ultimo
end

-- Estado do atirador só para a abertura da mira (o servidor decide o real).
local function estadoVisual(): string
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local horizontal = 0
	if raiz and raiz:IsA("BasePart") then
		local v = raiz.AssemblyLinearVelocity
		horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	return Regras.estadoDoAtirador(
		jogador:GetAttribute("Agachado") == true,
		jogador:GetAttribute("Correndo") == true,
		horizontal,
		LIMIAR_ANDAR
	)
end

-- A cada quadro: bloom decai, ticks da mira acompanham o espalhamento, recarga sem resposta do servidor se encerra.
local function passo(dt: number)
	local arma = armaAtual()
	if ehFogo(arma) then
		bloom = Regras.bloomRecuperado(arma, bloom, dt)
		local camera = workspace.CurrentCamera
		if camera then
			local graus = Regras.espalhamentoTotal(
				arma,
				bloom,
				estadoVisual(),
				jogador:GetAttribute("BracoZerado") == true,
				CfgArmas,
				CfgCorpo
			)
			local metadeFov = math.rad(camera.FieldOfView / 2)
			local px = math.tan(math.rad(graus)) / math.tan(metadeFov) * (camera.ViewportSize.Y / 2)
			local alvo = math.max(CfgVista.mira.folgaMinima, px)
			gapMira += (alvo - gapMira) * (1 - math.exp(-CfgVista.mira.suavizar * dt))
			local g = gapMira
			ticks[1].Position = UDim2.new(0.5, 0, 0.5, -g)
			ticks[2].Position = UDim2.new(0.5, 0, 0.5, g)
			ticks[3].Position = UDim2.new(0.5, -g, 0.5, 0)
			ticks[4].Position = UDim2.new(0.5, g, 0.5, 0)
		end
	end

	if recarregandoLocal then
		local decorrido = os.clock() - recargaInicio
		if not recargaConfirmada and decorrido > ESPERA_SERVIDOR then
			finalizarRecarga(true) -- o servidor recusou (cheio, sem munição, usando item...)
		elseif decorrido > recargaDuracao + FOLGA_FIM_RECARGA then
			finalizarRecarga(false)
		end
	end
end

function ArmasCliente.iniciar()
	criarInterface()
	atualizarVisibilidade()
	jogador:GetAttributeChangedSignal("ArmaEquipada"):Connect(aoMudarArma)
	aoMudarArma()

	-- O servidor marca Recarregando: confirma o pedido e, ao baixar, encerra (cancelada se veio antes da hora).
	jogador:GetAttributeChangedSignal("Recarregando"):Connect(function()
		if not recarregandoLocal then
			return
		end
		if jogador:GetAttribute("Recarregando") == true then
			recargaConfirmada = true
		elseif recargaConfirmada then
			local decorrido = os.clock() - recargaInicio
			finalizarRecarga(decorrido < recargaDuracao - FIM_NORMAL)
		end
	end)
	jogador:GetAttributeChangedSignal("Morto"):Connect(function()
		if jogador:GetAttribute("Morto") == true then
			segurando = false
			finalizarRecarga(true)
		end
	end)
	jogador:GetAttributeChangedSignal("Usando"):Connect(function()
		if jogador:GetAttribute("Usando") == true then
			segurando = false
		end
	end)

	local teclasRecarga = (CfgMovimento.teclas :: any).recarregar or { "R" }
	Teclas.ligar("recarregar", teclasRecarga, recarregar)

	UserInputService.InputBegan:Connect(function(entrada, processado)
		if processado then
			return
		end
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 and not Mouse.menuAberto() then
			comecar()
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 then
			segurando = false
		end
	end)

	RunService.RenderStepped:Connect(passo)
	Rede.evento("Acerto").OnClientEvent:Connect(piscarAcerto)
end

return ArmasCliente
