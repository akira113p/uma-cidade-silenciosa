-- ArmasViewmodel: primeira pessoa das armas (docs/armas.md §10.2). Dono: A5.
-- Só VISUAL e só local: braços em blocos + a arma (Shared/ArmaModelo) presos à câmera, com molas (coice, balanço, sway),
-- recuo de parede e poses de sacar/recarregar/bombear/golpear como dado (Config/ArmasVista). Os braços reais e a
-- `ArmaNaMao` do próprio personagem ficam invisíveis SÓ para o dono (LocalTransparencyModifier) enquanto o viewmodel está
-- ativo; ao ir para a 3ª pessoa, desarmar, morrer ou sentar num carro, tudo volta como estava.
-- Nada aqui decide acerto, dano ou pente: escuta os sinais de ArmasSinais (disparados por ArmasCliente).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgAparencia = require(Config:WaitForChild("Aparencia"))
local CfgCamera = require(Config:WaitForChild("Camera"))
local CfgSom = require(Config:WaitForChild("Som"))
local CfgVista = require(Config:WaitForChild("ArmasVista"))
local RegrasCamera = require(Shared:WaitForChild("Regras"):WaitForChild("Camera"))
local Mola = require(Shared:WaitForChild("Regras"):WaitForChild("Mola"))
local Braco = require(Shared:WaitForChild("Regras"):WaitForChild("Braco"))
local ArmasSinais = require(script.Parent.ArmasSinais)

local ArmasViewmodel = {}

local jogador = Players.LocalPlayer

local PRIORIDADE = Enum.RenderPriority.Camera.Value + 4 -- depois da Camera (+1) e da Cabine (+2)
local DESCANSO_ESQ = Vector3.new(-0.7, -2, 0.5) -- espaço da arma: onde a mão livre fica "escondida" em arma de uma mão
local ESPERA_FALHA = 2 -- s entre tentativas de construir o viewmodel quando ArmaModelo falha
local LIMITE_GIRO = 0.5 -- rad por quadro: giro maior que isto (teleporte, respawn) não vira sway
local PARTES_CORPO = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }

type Passo = {
	t: number,
	pos: Vector3,
	rot: Vector3,
	esqPos: Vector3?,
	esqPeso: number,
	esqDelta: Vector3,
}
type Pose = { pos: Vector3, rot: Vector3, esqPos: Vector3?, esqPeso: number, esqDelta: Vector3 }
type Clipe = {
	nome: string,
	inicio: number,
	duracao: number,
	lista: { Passo }?,
	tubo: { inicio: number, porCartucho: number, fim: number }?,
}
type Lado = { Superior: Part, Inferior: Part, Mao: Part, l1: number, l2: number, maoCompr: number }

-- Estado --------------------------------------------------------------------------------------------------------------

local armaId: string? = nil
local armaCfg: any = nil
local vista: any = nil -- CfgVista.classes[classe]

local modelo: Model? = nil
local arma: Model? = nil
local cabo: BasePart? = nil
local bocaLocal: CFrame? = nil
local ejecaoLocal: CFrame? = nil
local apoioLocal: Vector3? = nil
local clarao: Part? = nil
local clarearAte = 0
local braco: { D: Lado?, E: Lado? } = {}
local personagemMontado: Model? = nil
local ligado = false

local molaPos = Mola.novo()
local molaRot = Mola.novo()
local clipe: Clipe? = nil
local saida: { t0: number, pose: Pose }? = nil
local ultimaPose: Pose? = nil
local ultimoCabo: CFrame? = nil -- onde o Cabo ficou no último quadro (para a boca e a ejeção)
local personagemObservado: Model? = nil
local bombarEm = math.huge
local camAnterior: CFrame? = nil
local fase = 0
local balanco = 0
local modoBalanco = "andar"
local corrida = 0
local paredeK = 0
local rng = Random.new()
local avisouModelo = false
local falhouEm = -math.huge -- última tentativa de construir que falhou (não tenta de novo antes de ESPERA_FALHA)

-- Corpo real escondido (valores anteriores, para devolver exatamente como estavam)
local guardadasPartes: { [BasePart]: number } = {}
local guardadasGuis: { [SurfaceGui]: boolean } = {}
local partesCorpo: { BasePart } = {}
local guisCorpo: { SurfaceGui } = {}
local corpoSujo = true
local conexoesCorpo: { RBXScriptConnection } = {}

-- Dados em Vector3 (a Config é só números) --------------------------------------------------------------------------------

local function v3(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local cachePassos: { [any]: { Passo } } = {}

local function preparar(lista: any): { Passo }
	local pronto = cachePassos[lista]
	if pronto then
		return pronto
	end
	pronto = {}
	for _, p in lista do
		local esq = p.esq
		table.insert(pronto, {
			t = p.t,
			pos = v3(p.pos),
			rot = v3(p.rot),
			esqPos = if esq and esq.pos then v3(esq.pos) else nil,
			esqPeso = if esq then esq.peso else 0,
			esqDelta = if esq and esq.delta then v3(esq.delta) else Vector3.zero,
		})
	end
	cachePassos[lista] = pronto
	return pronto
end

local function poseZero(): Pose
	return { pos = Vector3.zero, rot = Vector3.zero, esqPos = nil, esqPeso = 0, esqDelta = Vector3.zero }
end

local function misturar(a: Passo, b: Passo, u: number): Pose
	local ep: Vector3? = nil
	if a.esqPos and b.esqPos then
		ep = a.esqPos:Lerp(b.esqPos, u)
	else
		ep = a.esqPos or b.esqPos
	end
	return {
		pos = a.pos:Lerp(b.pos, u),
		rot = a.rot:Lerp(b.rot, u),
		esqPos = ep,
		esqPeso = a.esqPeso + (b.esqPeso - a.esqPeso) * u,
		esqDelta = a.esqDelta:Lerp(b.esqDelta, u),
	}
end

-- Pose em `f` (0..1) de uma lista de passos, com smoothstep entre vizinhos.
local function amostrar(lista: { Passo }, f: number): Pose
	f = math.clamp(f, 0, 1)
	local n = #lista
	if f <= lista[1].t then
		return misturar(lista[1], lista[1], 0)
	end
	for i = 1, n - 1 do
		local a, b = lista[i], lista[i + 1]
		if f <= b.t then
			local u = math.clamp((f - a.t) / math.max(b.t - a.t, 1e-6), 0, 1)
			return misturar(a, b, u * u * (3 - 2 * u))
		end
	end
	return misturar(lista[n], lista[n], 0)
end

local function escalarPose(p: Pose, k: number): Pose
	return {
		pos = p.pos * k,
		rot = p.rot * k,
		esqPos = p.esqPos,
		esqPeso = p.esqPeso * k,
		esqDelta = p.esqDelta * k,
	}
end

-- Preferências (mesma regra do coice da câmera) ---------------------------------------------------------------------------

local function intensidade(): number
	local ligadoTremor = jogador:GetAttribute("Pref_Tremor") ~= false
	local valor = jogador:GetAttribute("Pref_Intensidade")
	if type(valor) ~= "number" then
		valor = CfgCamera.preferenciasPadrao.Pref_Intensidade
	end
	return if ligadoTremor then math.clamp(valor, 0, 100) / 100 else 0
end

-- Corpo real escondido -------------------------------------------------------------------------------------------------

local function restaurarCorpo()
	for parte, antes in guardadasPartes do
		if parte.Parent then
			parte.LocalTransparencyModifier = antes
		end
	end
	table.clear(guardadasPartes)
	for gui, antes in guardadasGuis do
		if gui.Parent then
			gui.Enabled = antes
		end
	end
	table.clear(guardadasGuis)
end

local function marcarCorpoSujo()
	corpoSujo = true
end

local function observarPersonagem(personagem: Model?)
	for _, c in conexoesCorpo do
		c:Disconnect()
	end
	table.clear(conexoesCorpo)
	restaurarCorpo()
	corpoSujo = true
	if personagem then
		table.insert(conexoesCorpo, personagem.DescendantAdded:Connect(marcarCorpoSujo))
		table.insert(conexoesCorpo, personagem.DescendantRemoving:Connect(marcarCorpoSujo))
	end
end

local function reunirAlvosCorpo(personagem: Model)
	table.clear(partesCorpo)
	table.clear(guisCorpo)
	local raizes: { Instance } = {}
	for _, nome in PARTES_CORPO do
		local p = personagem:FindFirstChild(nome)
		if p then
			table.insert(raizes, p)
		end
	end
	local naMao = personagem:FindFirstChild("ArmaNaMao")
	if naMao then
		table.insert(raizes, naMao)
	end
	for _, raiz in raizes do
		local itens = raiz:GetDescendants()
		table.insert(itens, raiz)
		for _, d in itens do
			if d:IsA("BasePart") then
				table.insert(partesCorpo, d)
			elseif d:IsA("SurfaceGui") then
				table.insert(guisCorpo, d)
			end
		end
	end
	corpoSujo = false
end

-- Aplicado a cada quadro (o controlador de transparência do Roblox pode reescrever a peça); só mexe nos valores
-- guardados na primeira vez, para restaurar depois.
local function esconderCorpo(personagem: Model)
	if corpoSujo then
		reunirAlvosCorpo(personagem)
	end
	for _, parte in partesCorpo do
		if guardadasPartes[parte] == nil then
			guardadasPartes[parte] = parte.LocalTransparencyModifier
		end
		parte.LocalTransparencyModifier = 1
	end
	for _, gui in guisCorpo do
		if guardadasGuis[gui] == nil then
			guardadasGuis[gui] = gui.Enabled
		end
		gui.Enabled = false
	end
end

-- Construção --------------------------------------------------------------------------------------------------------------

local function cor(nome: string): Color3
	local c = CfgAparencia.cores[nome]
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function novoBloco(nome: string, corBloco: Color3, tecido: boolean, pai: Instance): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = corBloco
	p.Material = if tecido then Enum.Material.Fabric else Enum.Material.SmoothPlastic
	p.Size = Vector3.new(0.5, 0.5, 1)
	p.Parent = pai
	return p
end

-- Tamanho da peça R15 do personagem (largura, comprimento, profundidade) ou a medida de reserva.
local function medidaR15(personagem: Model?, nome: string, reserva: { x: number, y: number, z: number }): Vector3
	local p = personagem and personagem:FindFirstChild(nome)
	if p and p:IsA("BasePart") then
		return p.Size
	end
	return v3(reserva)
end

local function criarLado(pai: Instance, prefixo: string, personagem: Model?): Lado
	local esc = CfgVista.escalaBraco
	local res = CfgVista.bracoReserva
	local sup = medidaR15(personagem, prefixo .. "UpperArm", res.superior)
	local inf = medidaR15(personagem, prefixo .. "LowerArm", res.inferior)
	local mao = medidaR15(personagem, prefixo .. "Hand", res.mao)
	local maoCompr = math.max(mao.Y, 0.5)
	local lado = {
		Superior = novoBloco("Superior", cor("suter"), true, pai),
		Inferior = novoBloco("Inferior", cor("suter"), true, pai),
		Mao = novoBloco("Mao", cor("pele"), false, pai),
		l1 = sup.Y,
		l2 = inf.Y + maoCompr / 2,
		maoCompr = maoCompr,
	}
	lado.Superior.Size = Vector3.new(sup.X * esc, sup.Z * esc, sup.Y)
	lado.Inferior.Size = Vector3.new(inf.X * esc, inf.Z * esc, inf.Y)
	lado.Mao.Size = Vector3.new(mao.X * esc, mao.Z * esc, maoCompr)
	return lado :: Lado
end

local function destruirModelo()
	if modelo then
		modelo:Destroy()
	end
	modelo, arma, cabo, bocaLocal, ejecaoLocal, apoioLocal, clarao = nil, nil, nil, nil, nil, nil, nil
	braco = {}
	personagemMontado = nil
end

-- Posição de um Attachment da arma no espaço do Cabo (independe de em qual peça o Attachment foi posto).
local function localAoCabo(modeloArma: Model, nome: string): CFrame?
	local att = modeloArma:FindFirstChild(nome, true)
	if att and att:IsA("Attachment") and cabo then
		return cabo.CFrame:ToObjectSpace(att.WorldCFrame)
	end
	return nil
end

local function carregarArmaModelo(): any
	local ok, resultado = pcall(function()
		local modulo = Shared:FindFirstChild("ArmaModelo") -- sem esperar: isto roda dentro do passo de render
		assert(modulo, "ArmaModelo não existe em Shared")
		return require(modulo)
	end)
	if ok then
		return resultado
	end
	if not avisouModelo then
		avisouModelo = true
		warn("[ArmasViewmodel] Shared/ArmaModelo indisponível: sem viewmodel (" .. tostring(resultado) .. ")")
	end
	return nil
end

local function construir(personagem: Model?): boolean
	destruirModelo()
	if not (armaId and vista) then
		return false
	end
	falhouEm = os.clock() -- vale até construir terminar bem (zerado no fim)
	local ArmaModelo = carregarArmaModelo()
	if not ArmaModelo then
		return false
	end
	local ok, criada = pcall(ArmaModelo.criar, armaId)
	if not (ok and typeof(criada) == "Instance" and criada:IsA("Model")) then
		if not avisouModelo then
			avisouModelo = true
			warn("[ArmasViewmodel] ArmaModelo.criar falhou para " .. armaId .. ": " .. tostring(criada))
		end
		return false
	end
	local m = Instance.new("Model")
	m.Name = "ArmasViewmodel"
	for _, d in criada:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	criada.Parent = m
	arma = criada
	local pc = criada:FindFirstChild("Cabo", true)
	if not (pc and pc:IsA("BasePart")) then
		m:Destroy()
		arma = nil
		if not avisouModelo then
			avisouModelo = true
			warn("[ArmasViewmodel] a arma " .. armaId .. " não tem Cabo")
		end
		return false
	end
	pc.PivotOffset = CFrame.identity -- o pivô do modelo passa a ser exatamente o Cabo (a empunhadura)
	criada.PrimaryPart = pc
	cabo = pc
	bocaLocal = localAoCabo(criada, "Boca")
	ejecaoLocal = localAoCabo(criada, "Ejecao")
	local ap = localAoCabo(criada, "ApoioEsquerdo")
	apoioLocal = if ap then ap.Position elseif vista.apoioPadrao then v3(vista.apoioPadrao) else nil

	braco.D = criarLado(m, "Right", personagem)
	braco.E = criarLado(m, "Left", personagem)
	personagemMontado = personagem

	local c = CfgVista.clarao
	local f = Instance.new("Part")
	f.Name = "Clarao"
	f.Anchored = true
	f.CanCollide = false
	f.CanQuery = false
	f.CanTouch = false
	f.CastShadow = false
	f.Material = Enum.Material.Neon
	f.Color = Color3.fromRGB(c.cor[1], c.cor[2], c.cor[3])
	f.Size = Vector3.new(c.tamanho, c.tamanho, c.tamanho)
	f.Transparency = 1
	local luz = Instance.new("PointLight")
	luz.Range = c.luz.alcance
	luz.Brightness = c.luz.brilho
	luz.Color = f.Color
	luz.Shadows = false
	luz.Enabled = false
	luz.Parent = f
	f.Parent = m
	clarao = f
	modelo = m
	falhouEm = -math.huge
	return true
end

-- Clipes --------------------------------------------------------------------------------------------------------------------

local function iniciarClipe(nome: string, duracao: number, lista: { Passo }?, tubo: any?)
	clipe = { nome = nome, inicio = os.clock(), duracao = math.max(duracao, 0.05), lista = lista, tubo = tubo }
	saida = nil
end

-- Pose do clipe em andamento (nil se não há). Encerra o clipe quando o tempo acaba.
local function poseDoClipe(agora: number): Pose?
	local c = clipe
	if not c then
		return nil
	end
	local e = agora - c.inicio
	if e >= c.duracao then
		clipe = nil
		return nil
	end
	if c.tubo and vista.recargaTubo then
		local rt = vista.recargaTubo
		local t = c.tubo
		if e < t.inicio then
			return amostrar(preparar(rt.inicio), e / math.max(t.inicio, 1e-6))
		elseif e >= c.duracao - t.fim then
			return amostrar(preparar(rt.fim), (e - (c.duracao - t.fim)) / math.max(t.fim, 1e-6))
		end
		local ciclo = ((e - t.inicio) % t.porCartucho) / t.porCartucho
		return amostrar(preparar(rt.cartucho), ciclo)
	end
	if c.lista then
		return amostrar(c.lista, e / c.duracao)
	end
	return nil
end

local function cancelarClipe()
	if clipe and ultimaPose then
		saida = { t0 = os.clock(), pose = ultimaPose }
	end
	clipe = nil
end

local function aoEquipar(id: string?)
	armaId = id
	armaCfg = if id then CfgArmas.armas[id] else nil
	vista = if armaCfg then CfgVista.classes[armaCfg.classe] else nil
	if not (id and vista) then
		armaId, armaCfg, vista = nil, nil, nil
		clipe, saida, ultimaPose, bombarEm = nil, nil, nil, math.huge
		destruirModelo()
		return
	end
	destruirModelo() -- reconstrói no próximo quadro ativo com a arma nova
	falhouEm = -math.huge
	clipe, saida, bombarEm = nil, nil, math.huge
	molaPos, molaRot = Mola.novo(), Mola.novo()
	corpoSujo = true
	iniciarClipe("sacar", vista.sacarDuracao, preparar(vista.sacar))
end

local function aoDisparar(id: string, _origem: Vector3, _direcao: Vector3)
	if id ~= armaId or not (armaCfg and vista) then
		return
	end
	local c = CfgVista.coice
	local vertical = armaCfg.coice and armaCfg.coice.vertical or 1
	local horizontal = armaCfg.coice and armaCfg.coice.horizontal or 0
	local k = math.max(c.minimo, intensidade())
	local wPos = math.sqrt(CfgVista.molaPos.rigidez) * 1.2
	local wRot = math.sqrt(CfgVista.molaRot.rigidez) * 1.2
	Mola.impulso(molaPos, 0, c.subidaPorGrau * vertical * wPos * k, c.recuoPorGrau * vertical * wPos * k)
	local lado = if rng:NextNumber() < 0.5 then -1 else 1
	Mola.impulso(
		molaRot,
		c.pitchPorGrau * vertical * wRot * k,
		c.guinadaPorGrau * horizontal * wRot * k * lado,
		lado * horizontal * wRot * k * 0.6
	)
	clarearAte = os.clock() + CfgVista.clarao.duracao
	if vista.bombear then
		bombarEm = os.clock() + vista.bombear.atraso
	end
end

local function aoGolpear(id: string, indice: number?)
	if id ~= armaId or not (armaCfg and vista and vista.golpes) then
		return
	end
	local n = #vista.golpes
	local lista = vista.golpes[(((indice or 1) - 1) % n) + 1]
	local duracao = armaCfg.atrasoImpacto / vista.impactoT
	duracao = math.min(duracao, armaCfg.cadencia * 0.95)
	iniciarClipe("golpe", duracao, preparar(lista))
end

local function aoVazio(id: string)
	if id ~= armaId then
		return
	end
	Mola.impulso(molaPos, 0, 0, 0.35)
	Mola.impulso(molaRot, 3, 0, 0)
end

local function aoRecarregar(id: string, duracao: number)
	if id ~= armaId or not (armaCfg and vista) then
		return
	end
	bombarEm = math.huge
	local r = armaCfg.recarga
	if r.tipo == "cartucho" and vista.recargaTubo then
		iniciarClipe("recarga", duracao, nil, { inicio = r.inicio, porCartucho = r.porCartucho, fim = r.fim })
	elseif vista.recarga then
		iniciarClipe("recarga", duracao, preparar(vista.recarga))
	end
end

local function aoFimRecarga(id: string, cancelada: boolean)
	if id ~= armaId then
		return
	end
	if cancelada and clipe and clipe.nome == "recarga" then
		cancelarClipe()
	end
end

-- Quadro --------------------------------------------------------------------------------------------------------------------

local function desativar()
	if not ligado then
		return
	end
	ligado = false
	if modelo then
		modelo.Parent = nil
	end
	observarPersonagem(nil) -- desconecta e devolve o corpo real
	personagemObservado = nil
	camAnterior = nil
	ultimoCabo = nil
end

local function emPrimeiraPessoa(personagem: Model, camera: Camera): (boolean, Humanoid?)
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	local cabeca = personagem:FindFirstChild("Head")
	if not (humanoide and cabeca and cabeca:IsA("BasePart")) then
		return false, nil
	end
	if humanoide.Health <= 0 or jogador:GetAttribute("Morto") == true or humanoide.SeatPart ~= nil then
		return false, nil
	end
	local perto = (camera.CFrame.Position - cabeca.Position).Magnitude < CfgAparencia.distanciaPrimeiraPessoa
	return perto, humanoide
end

-- Recuo se há parede perto: raio curto da câmera para frente. Devolve 0..1.
local function proximidadeParede(camera: Camera, personagem: Model): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personagem, camera }
	params.IgnoreWater = true
	local d = CfgVista.parede.distancia
	local r = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * d, params)
	if not r then
		return 0
	end
	return math.clamp(1 - r.Distance / d, 0, 1)
end

-- Um bloco entre dois pontos (o Z do bloco aponta de a para b).
local function esticar(parte: Part, a: Vector3, b: Vector3)
	local comp = (b - a).Magnitude
	if comp < 1e-3 then
		parte.Transparency = 1
		return
	end
	parte.Transparency = 0
	parte.Size = Vector3.new(parte.Size.X, parte.Size.Y, comp)
	parte.CFrame = CFrame.lookAt((a + b) / 2, b)
end

local function vec(v: Vector3): { x: number, y: number, z: number }
	return { x = v.X, y = v.Y, z = v.Z }
end

local function desvec(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function desenharBraco(lado: Lado, ombro: Vector3, alvo: Vector3, polo: Vector3)
	local cotoveloT, maoT = Braco.resolver2Ossos(vec(ombro), vec(alvo), vec(polo), lado.l1, lado.l2)
	local cotovelo, mao = desvec(cotoveloT), desvec(maoT)
	local dir = mao - cotovelo
	if dir.Magnitude < 1e-3 then
		dir = (alvo - ombro)
	end
	local u = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
	local punho = mao - u * (lado.maoCompr / 2)
	esticar(lado.Superior, ombro, cotovelo)
	esticar(lado.Inferior, cotovelo, punho)
	esticar(lado.Mao, punho, punho + u * lado.maoCompr)
end

local function esconderLado(lado: Lado)
	lado.Superior.Transparency = 1
	lado.Inferior.Transparency = 1
	lado.Mao.Transparency = 1
end

local function passo(dt: number)
	local personagem = jogador.Character
	local camera = workspace.CurrentCamera
	if not (armaId and vista and personagem and camera) then
		desativar()
		return
	end
	if personagem ~= personagemMontado and modelo then
		destruirModelo() -- novo personagem (respawn): refaz com as medidas dele
	end
	local primeira, humanoide = emPrimeiraPessoa(personagem, camera)
	if not primeira or not humanoide then
		desativar()
		return
	end
	if not modelo then
		if os.clock() - falhouEm < ESPERA_FALHA or not construir(personagem) then
			desativar()
			return
		end
	end
	local m = modelo :: Model

	ligado = true
	if m.Parent ~= camera then
		m.Parent = camera
	end
	if personagemObservado ~= personagem then
		personagemObservado = personagem
		observarPersonagem(personagem)
	end
	esconderCorpo(personagem)

	local agora = os.clock()
	local camCF = camera.CFrame
	local k = intensidade()

	-- Movimento do personagem
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local horizontal = 0
	if raiz and raiz:IsA("BasePart") then
		local v = raiz.AssemblyLinearVelocity
		horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	local noAr = humanoide.FloorMaterial == Enum.Material.Air
	local movendo = horizontal > 1 and not noAr
	local agachado = jogador:GetAttribute("Agachado") == true
	local correndo = jogador:GetAttribute("Correndo") == true
	local modo = RegrasCamera.modo(agachado, correndo, movendo)

	-- Balanço de passo (mesma fase da câmera: mesmo ritmo de Config/Som)
	if movendo then
		modoBalanco = modo
		local ritmo = CfgSom.passosPorSegundo[modo] or CfgSom.passosPorSegundo.andar
		fase = RegrasCamera.avancarFase(fase, ritmo, dt)
	end
	balanco += ((if movendo then 1 else 0) - balanco) * (1 - math.exp(-8 * dt))
	local bal = CfgVista.balanco[if modoBalanco == "correr"
		then "correr"
		elseif modoBalanco == "agachado" then "agachado"
		else "andar"]
	local respira = math.sin(agora * math.pi * 2 * CfgVista.respiracao.hz) * CfgVista.respiracao.amplitude
	local alvoPosX = math.sin(fase / 2) * bal.x * balanco * k
	local alvoPosY = -math.abs(math.sin(fase)) * bal.y * balanco * k + respira * (1 - balanco)
	local alvoRotZ = math.sin(fase / 2) * bal.roll * balanco * k

	-- Corrida: arma abaixada
	local alvoCorrida = if correndo and movendo then 1 else 0
	corrida += (alvoCorrida - corrida) * (1 - math.exp(-CfgVista.suavizarCorrida * dt))

	-- Parede perto
	local proximidade = proximidadeParede(camera, personagem)
	paredeK += (proximidade - paredeK) * (1 - math.exp(-CfgVista.parede.suavizar * dt))

	-- Sway: a arma fica para trás do giro da câmera
	if camAnterior then
		local rx, ry = camAnterior:ToObjectSpace(camCF):ToEulerAnglesYXZ()
		if math.abs(rx) < LIMITE_GIRO and math.abs(ry) < LIMITE_GIRO then
			local s = CfgVista.sway
			molaRot.x = math.clamp(molaRot.x - math.deg(rx) * s.ganho * k, -s.maximo, s.maximo)
			molaRot.y = math.clamp(molaRot.y - math.deg(ry) * s.ganho * k, -s.maximo, s.maximo)
		end
	end
	camAnterior = camCF

	-- Molas: alvo = balanço; coice e sway entram como estado/velocidade
	Mola.passo(
		molaPos,
		{ x = alvoPosX, y = alvoPosY, z = 0 },
		CfgVista.molaPos.rigidez,
		CfgVista.molaPos.amortecimento,
		dt
	)
	Mola.passo(molaRot, { x = 0, y = 0, z = alvoRotZ }, CfgVista.molaRot.rigidez, CfgVista.molaRot.amortecimento, dt)

	-- Bombear (escopeta) agendado pelo tiro
	if agora >= bombarEm and vista.bombear then
		bombarEm = math.huge
		if not (clipe and (clipe.nome == "recarga" or clipe.nome == "sacar")) then
			iniciarClipe("bombear", vista.bombear.duracao, preparar(vista.bombear.passos))
		end
	end

	-- Pose do clipe (ou da saída suave de um clipe cancelado)
	local pose = poseDoClipe(agora)
	if pose then
		ultimaPose = pose
	elseif saida then
		local f = (agora - saida.t0) / CfgVista.suavizarSaida
		if f >= 1 then
			saida = nil
		else
			pose = escalarPose(saida.pose, 1 - f * f * (3 - 2 * f))
		end
	end
	pose = pose or poseZero()

	-- Arma: base + clipe + mola + corrida + parede
	local base = vista.base
	local pos = v3(base.pos) + pose.pos + Vector3.new(molaPos.x, molaPos.y, molaPos.z)
	local rot = v3(base.rot) + pose.rot + Vector3.new(molaRot.x, molaRot.y, molaRot.z)
	if corrida > 0.001 then
		pos += v3(vista.correr.pos) * corrida
		rot += v3(vista.correr.rot) * corrida
	end
	if paredeK > 0.001 then
		pos += Vector3.new(0, 0, CfgVista.parede.recuo * paredeK)
		rot += Vector3.new(CfgVista.parede.subida * paredeK, 0, 0)
	end
	local armaCF = camCF
		* CFrame.new(pos)
		* CFrame.fromEulerAnglesYXZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	if arma then
		(arma :: Model):PivotTo(armaCF)
	end

	-- Braços
	local ombroD = camCF:PointToWorldSpace(v3(CfgVista.ombro.D))
	local ombroE = camCF:PointToWorldSpace(v3(CfgVista.ombro.E))
	local poloD = camCF:VectorToWorldSpace(v3(CfgVista.polo.D))
	local poloE = camCF:VectorToWorldSpace(v3(CfgVista.polo.E))
	if braco.D then
		local palma = armaCF:PointToWorldSpace(v3(vista.maoD))
		desenharBraco(braco.D, ombroD, palma, poloD)
	end
	local ladoE = braco.E
	if ladoE then
		local livre = pose.esqPeso > 0.02
		if vista.duasMaos or livre then
			local ponto: Vector3
			if vista.duasMaos then
				local apoio = apoioLocal or Vector3.new(0, 0, -1)
				ponto = apoio:Lerp(pose.esqPos or apoio, pose.esqPeso) + pose.esqDelta
			else
				ponto = DESCANSO_ESQ:Lerp(pose.esqPos or DESCANSO_ESQ, pose.esqPeso)
			end
			desenharBraco(ladoE, ombroE, armaCF:PointToWorldSpace(ponto), poloE)
		else
			esconderLado(ladoE)
		end
	end

	-- Clarão do tiro
	local f = clarao
	if f and bocaLocal then
		if agora < clarearAte then
			f.Transparency = 0
			local s = CfgVista.clarao.tamanho * rng:NextNumber(0.7, 1.3)
			f.Size = Vector3.new(s, s, s)
			f.CFrame = armaCF * (bocaLocal :: CFrame) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
			local luz = f:FindFirstChildOfClass("PointLight")
			if luz then
				luz.Enabled = true
			end
		elseif f.Transparency < 1 then
			f.Transparency = 1
			local luz = f:FindFirstChildOfClass("PointLight")
			if luz then
				luz.Enabled = false
			end
		end
	end
	ultimoCabo = armaCF
end

-- Interface para EfeitosArma -----------------------------------------------------------------------------------------------

function ArmasViewmodel.ativo(): boolean
	return ligado
end

-- CFrame mundial da boca da arma do viewmodel (nil se não há viewmodel ativo).
function ArmasViewmodel.bocaMundo(): CFrame?
	if ligado and bocaLocal and ultimoCabo then
		return ultimoCabo * (bocaLocal :: CFrame)
	end
	return nil
end

function ArmasViewmodel.ejecaoMundo(): CFrame?
	if ligado and ejecaoLocal and ultimoCabo then
		return ultimoCabo * (ejecaoLocal :: CFrame)
	end
	return nil
end

function ArmasViewmodel.iniciar()
	ArmasSinais.ouvir("equipou", aoEquipar)
	ArmasSinais.ouvir("disparou", aoDisparar)
	ArmasSinais.ouvir("golpeou", aoGolpear)
	ArmasSinais.ouvir("vazio", aoVazio)
	ArmasSinais.ouvir("recarregou", aoRecarregar)
	ArmasSinais.ouvir("recargaFim", aoFimRecarga)
	jogador.CharacterAdded:Connect(function()
		destruirModelo()
		desativar()
		fase, balanco, corrida, paredeK = 0, 0, 0, 0
	end)
	RunService:BindToRenderStep("ArmasViewmodel", PRIORIDADE, passo)
end

return ArmasViewmodel
