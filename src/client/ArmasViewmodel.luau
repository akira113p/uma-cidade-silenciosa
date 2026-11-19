-- ArmasViewmodel: primeira pessoa das armas (docs/armas.md §10.2) e dos itens na mão. Dono: A5; refatorado pela A2
-- (docs/personagens.md, Parte A2).
-- Só VISUAL e só local. Dois caminhos para os braços:
--   * RIG (preferido): rig R15 mínimo de src/client/BracosViewmodel.luau preso à câmera, que toca os MESMOS clipes da 3ª pessoa
--     (Animacao.trilha "armas/<classe>"), com a arma presa à RightHand (JuntaArma). As molas de coice/balanço/sway e o recuo
--     de parede movem o rig inteiro por cima do clipe. Item que não é arma (ItemNaMao) usa o clipe corpo/mao.
--   * PLANO B: sem clipe (Animacao ainda não existe ou devolveu nil), os braços de blocos movidos por poses + IK analítico de
--     antes (Config/ArmasVista + Regras/Braco). Nada para de funcionar enquanto os clipes não chegam.
-- Os braços reais, a `ArmaNaMao` e o `ItemNaMao` do próprio personagem ficam invisíveis SÓ para o dono
-- (LocalTransparencyModifier) enquanto o viewmodel está ativo; ao ir para a 3ª pessoa, desarmar, morrer ou sentar num carro,
-- tudo volta como estava. Nada aqui decide acerto, dano ou pente: escuta os sinais de ArmasSinais (disparados por ArmasCliente).
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
local RegrasBracos = require(Shared:WaitForChild("Regras"):WaitForChild("BracosVista"))
local CfgAnim = require(Config:WaitForChild("ArmasAnim"))
local ArmasSinais = require(script.Parent.ArmasSinais)
local BracosViewmodel = require(script.Parent.BracosViewmodel)
local ViewmodelGB = require(script.Parent.ViewmodelGB) -- armas do Gold Bright: ele assume e este cede a vez

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

-- Rig com clipes (nil = plano B de blocos, ou nenhum viewmodel montado)
local rig: BracosViewmodel.Rig? = nil
local grupoRig = "" -- "armas/<classe>" ou o grupo do item
local idleRig: AnimationTrack? = nil
local clipeRig: { nome: string, trilha: AnimationTrack }? = nil -- Equip/Fire/Golpe/Recarga em andamento (para o IK e o braço esquerdo)
local tuboRig: { t0: number, etapas: { RegrasBracos.Etapa }, proxima: number }? = nil
local caboRelativo: CFrame? = nil -- onde o Cabo (ou a mão do item) fica em relação ao tronco do rig na 1ª pose do Idle
local equipPendente = false -- o sinal "equipou" chegou e o Equip ainda não tocou (o rig nasce no quadro seguinte)
local modoItem = false -- viewmodel de um item que não é arma
local itensReais: { [string]: Model? } = {} -- ItemNaMao reais do personagem, por lado ("direita"/"esquerda")
local itensSujo = true
local itensMontados: { [string]: Model? } = {}
local itemIndisponivel = false -- sem clipe corpo/mao: não tenta montar de novo até o próximo personagem
local idMontado = "" -- PersonagemId com que o viewmodel foi montado
local paramsParede: RaycastParams? = nil
local avisouPlanoB = false

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
local provisorio = false -- montado com o bloco provisório (malha ainda baixando): remonta quando ArmaModelo.pronta
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
			-- arma/item na mão: sempre visível de novo (o valor guardado podia ser 1, se foi guardado já escondido num remonte)
			local naMao = parte:FindFirstAncestor("ArmaNaMao") or parte:FindFirstAncestor("ItemNaMao")
			parte.LocalTransparencyModifier = if naMao then 0 else antes
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
	for _, filho in personagem:GetChildren() do
		if filho.Name == "ArmaNaMao" or filho.Name == "ItemNaMao" then
			table.insert(raizes, filho)
		end
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
	-- o rig mora dentro de `modelo` (Destroy acima já o levou); só esquece as referências
	rig, idleRig, clipeRig, tuboRig, caboRelativo = nil, nil, nil, nil, nil
	modoItem = false
	itensMontados = {}
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

local function criarClarao(pai: Instance): Part
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
	f.Parent = pai
	return f
end

local function idDoPersonagem(personagem: Model?): string
	local id = personagem and personagem:GetAttribute("PersonagemId")
	return if type(id) == "string" then id else ""
end

local function tocarRig(nome: string, velocidade: number, fade: number): AnimationTrack?
	local r = rig
	if not r then
		return nil
	end
	local t = BracosViewmodel.trilha(r, grupoRig, nome)
	if not t then
		return nil
	end
	if t.IsPlaying then
		t.TimePosition = 0
		t:AdjustSpeed(velocidade)
	else
		t:Play(fade, 1, velocidade)
	end
	if nome ~= "Idle" then
		clipeRig = { nome = nome, trilha = t }
	end
	return t
end

-- Tenta montar o rig com clipes para a arma. Devolve o rig e a trilha Idle, ou nil (plano B) sem destruir nada que já exista.
local function tentarRig(personagem: Model?, camera: Camera, clipeBase: string): (BracosViewmodel.Rig?, AnimationTrack?)
	if not personagem then
		return nil, nil
	end
	local novo, motivo = BracosViewmodel.criar(personagem, camera)
	if not novo then
		if not avisouPlanoB then
			avisouPlanoB = true
			warn("[ArmasViewmodel] braços em blocos (plano B): " .. tostring(motivo))
		end
		return nil, nil
	end
	local idle = BracosViewmodel.trilha(novo, grupoRig, clipeBase)
	if not idle then
		if not avisouPlanoB then
			avisouPlanoB = true
			warn("[ArmasViewmodel] braços em blocos (plano B): sem o clipe " .. grupoRig .. "/" .. clipeBase)
		end
		BracosViewmodel.destruir(novo)
		return nil, nil
	end
	return novo, idle
end

local function construir(personagem: Model?, camera: Camera): boolean
	destruirModelo()
	if not (armaId and vista and armaCfg) then
		return false
	end
	falhouEm = os.clock() -- vale até construir terminar bem (zerado no fim)
	local ArmaModelo = carregarArmaModelo()
	if not ArmaModelo then
		return false
	end
	provisorio = ArmaModelo.pronta ~= nil and not ArmaModelo.pronta(armaId)
	local ok, criada = pcall(ArmaModelo.criar, armaId)
	if not (ok and typeof(criada) == "Instance" and criada:IsA("Model")) then
		if not avisouModelo then
			avisouModelo = true
			warn("[ArmasViewmodel] ArmaModelo.criar falhou para " .. armaId .. ": " .. tostring(criada))
		end
		return false
	end
	local pc = criada:FindFirstChild("Cabo", true)
	if not (pc and pc:IsA("BasePart")) then
		criada:Destroy()
		if not avisouModelo then
			avisouModelo = true
			warn("[ArmasViewmodel] a arma " .. armaId .. " não tem Cabo")
		end
		return false
	end

	-- Rig com clipes se der; senão o plano B (modelo próprio com braços de blocos e arma ancorada).
	grupoRig = "armas/" .. armaCfg.classe
	local novoRig, idle = tentarRig(personagem, camera, "Idle")
	local m: Model
	if novoRig then
		m = novoRig.modelo
	else
		m = Instance.new("Model")
		m.Name = "ArmasViewmodel"
	end
	criada.Parent = m
	arma = criada
	pc.PivotOffset = CFrame.identity -- o pivô do modelo passa a ser exatamente o Cabo (a empunhadura)
	criada.PrimaryPart = pc
	cabo = pc
	bocaLocal = localAoCabo(criada, "Boca")
	ejecaoLocal = localAoCabo(criada, "Ejecao")
	local ap = localAoCabo(criada, "ApoioEsquerdo")
	apoioLocal = if ap then ap.Position elseif vista.apoioPadrao then v3(vista.apoioPadrao) else nil
	personagemMontado = personagem
	idMontado = idDoPersonagem(personagem)

	if novoRig then
		BracosViewmodel.prenderArma(novoRig, criada, pc, armaCfg.classe)
		if vista.duasMaos then
			local apoio = criada:FindFirstChild("ApoioEsquerdo", true)
			-- modelo sem ApoioEsquerdo (machado): cria no Cabo em `apoioPadrao`, senão a mão esquerda fica solta no ar
			local caboArma = criada.PrimaryPart
			if not apoio and vista.apoioPadrao and caboArma then
				local novo = Instance.new("Attachment")
				novo.Name = "ApoioEsquerdo"
				novo.Position = v3(vista.apoioPadrao)
				novo.Parent = caboArma
				apoio = novo
			end
			BracosViewmodel.prepararIK(novoRig, if apoio and apoio:IsA("Attachment") then apoio else nil)
		end
		BracosViewmodel.precarregar(novoRig, grupoRig, armaCfg.classe)
		local c0 = (CfgAnim.mao.porClasse :: any)[armaCfg.classe] or CfgAnim.mao.C0
		caboRelativo = BracosViewmodel.relativo(novoRig, grupoRig, "Idle", "direita", c0)
		rig, idleRig, clipeRig, tuboRig = novoRig, idle, nil, nil
		modoItem = false
		idle:Play(CfgVista.rig.fade.idle, 1, 1)
		if equipPendente then
			equipPendente = false
			tocarRig(
				"Equip",
				RegrasBracos.velocidade(
					(CfgAnim.duracao :: any)[armaCfg.classe].Equip or vista.sacarDuracao,
					vista.sacarDuracao,
					CfgVista.rig.velocidade.minimo,
					CfgVista.rig.velocidade.maximo
				),
				CfgVista.rig.fade.equip
			)
		end
	else
		equipPendente = false -- sem rig o clipe de poses "sacar" (aoEquipar) já cuida do sacar
		for _, d in criada:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		pc.Anchored = true
		braco.D = criarLado(m, "Right", personagem)
		braco.E = criarLado(m, "Left", personagem)
	end

	clarao = criarClarao(m)
	modelo = m
	falhouEm = -math.huge
	return true
end

-- Item que não é arma (ItemNaMao): rig + cópia do modelo na mão certa + clipe corpo/mao. false = sem clipe/rig (nada aparece).
local function construirItem(personagem: Model, camera: Camera): boolean
	destruirModelo()
	falhouEm = os.clock()
	local cfgItem = CfgVista.item
	grupoRig = cfgItem.grupo
	local novo, seg = tentarRig(personagem, camera, cfgItem.clipe)
	if not (novo and seg) then
		itemIndisponivel = true
		return false
	end
	local montados: { [string]: Model? } = {} -- o ItemNaMao REAL de cada lado que ganhou cópia no rig
	for _, lado in { "direita", "esquerda" } do
		local real = itensReais[lado]
		if real and BracosViewmodel.prenderItem(novo, personagem, real, lado) then
			montados[lado] = real
		end
	end
	if not (montados.direita or montados.esquerda) then
		BracosViewmodel.destruir(novo)
		return false
	end
	local ladoPrincipal = if montados.direita then "direita" else "esquerda"
	caboRelativo = BracosViewmodel.relativo(novo, cfgItem.grupo, cfgItem.clipe, ladoPrincipal, nil)
	-- o clipe de segurar o item faz o papel do Idle
	rig, idleRig, clipeRig, tuboRig = novo, seg, nil, nil
	modelo = novo.modelo
	modoItem = true
	itensMontados = montados
	personagemMontado = personagem
	idMontado = idDoPersonagem(personagem)
	falhouEm = -math.huge
	BracosViewmodel.mostrarEsquerda(novo, montados.esquerda ~= nil or montados.direita == nil)
	seg:Play(CfgVista.rig.fade.idle, 1, 1)
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
	equipPendente = true -- com rig, o Equip toca assim que ele nascer (próximo quadro ativo); sem rig vale o clipe de poses abaixo
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
	if rig and not modoItem then
		-- o clipe Fire do rig já traz o coice do braço (e o bombear da escopeta); as molas acima seguem por cima
		local nativa = (CfgAnim.duracao :: any)[armaCfg.classe].Fire
		tocarRig(
			"Fire",
			RegrasBracos.velocidadeTiro(nativa, armaCfg.cadencia, CfgVista.rig.tiroMaximo),
			CfgVista.rig.fade.tiro
		)
	elseif vista.bombear then
		bombarEm = os.clock() + vista.bombear.atraso
	end
end

local function aoGolpear(id: string, indice: number?)
	if id ~= armaId or not (armaCfg and vista) then
		return
	end
	if rig and not modoItem then
		local classe = armaCfg.classe
		local nome = RegrasBracos.clipeGolpe(classe, indice)
		local nativas = (CfgAnim.duracao :: any)[classe]
		local impactos = (CfgAnim.impacto :: any)[classe]
		local v = RegrasBracos.velocidadeGolpe(
			impactos and impactos[nome],
			armaCfg.atrasoImpacto,
			nativas and nativas[nome] or 1,
			armaCfg.cadencia,
			CfgVista.rig.velocidade.minimo,
			CfgVista.rig.velocidade.maximo
		)
		tocarRig(nome, v, CfgVista.rig.fade.golpe)
		return
	end
	if not vista.golpes then
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

local recargaIniciouEm = 0 -- os.clock() do último "recarregou" (para a recarga rápida/falha reajustar a trilha)

local function aoRecarregar(id: string, duracao: number)
	if id ~= armaId or not (armaCfg and vista) then
		return
	end
	recargaIniciouEm = os.clock()
	bombarEm = math.huge
	local r = armaCfg.recarga
	if rig and not modoItem then
		local classe = armaCfg.classe
		local nativas = (CfgAnim.duracao :: any)[classe]
		local vel = CfgVista.rig.velocidade
		tuboRig = nil
		if r.tipo == "pente" then
			tocarRig(
				"Reload",
				RegrasBracos.velocidade(nativas.Reload, duracao, vel.minimo, vel.maximo),
				CfgVista.rig.fade.recarga
			)
		else
			-- por cartucho: Inicio, N x Cartucho, Fim, tocados em sequência pelo relógio do quadro (ver `passo`)
			tuboRig = {
				t0 = os.clock(),
				etapas = RegrasBracos.etapasTubo(r.inicio, r.porCartucho, r.fim, duracao),
				proxima = 1,
			}
		end
		return
	end
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
	if rig and not modoItem and armaCfg then
		tuboRig = nil
		local fade = if cancelada then CfgVista.rig.fade.cancelar else 0.1
		for _, nome in { "Reload", "RecargaInicio", "RecargaCartucho", "RecargaFim" } do
			local t = BracosViewmodel.trilha(rig, grupoRig, nome)
			if t and t.IsPlaying then
				t:Stop(fade)
			end
		end
		return
	end
	if cancelada and clipe and clipe.nome == "recarga" then
		cancelarClipe()
	end
end

-- Engatilhar/bombear/destravar (Q): a arma recua e volta ao longo de `tempo` s; destravar é mais brusco. Só molas (sem clipe novo).
local function aoEngatilhar(id: string, tempo: number, destravar: boolean)
	if id ~= armaId then
		return
	end
	Mola.impulso(molaPos, 0, 0, 0.55)
	Mola.impulso(molaRot, if destravar then 6 else 3, 0, if destravar then 4 else 0)
	task.delay(tempo * 0.5, function()
		if id ~= armaId then
			return
		end
		Mola.impulso(molaPos, 0, 0, -0.6)
		Mola.impulso(molaRot, -2, 0, 0)
	end)
end

-- Checar a munição (Z): a arma gira de lado e baixa para mostrar o pente, e volta.
local function aoChecar(id: string, duracao: number)
	if id ~= armaId then
		return
	end
	Mola.impulso(molaPos, -0.3, 0.15, 0.1)
	Mola.impulso(molaRot, 4, 0, -14)
	task.delay(duracao * 0.55, function()
		if id ~= armaId then
			return
		end
		Mola.impulso(molaPos, 0.3, -0.1, 0)
		Mola.impulso(molaRot, -3, 0, 12)
	end)
end

-- Recarga rápida (acaba antes) ou falha (demora mais): reajusta a velocidade da trilha de recarga para ela terminar junto com o servidor.
local function aoReajustarRecarga(id: string, duracaoNova: number)
	if id ~= armaId or not (rig and not modoItem) then
		return
	end
	local trilha = BracosViewmodel.trilha(rig, grupoRig, "Reload")
	if trilha and trilha.IsPlaying and trilha.Length > 0 then
		local restanteTrilha = math.max(0.05, trilha.Length - trilha.TimePosition)
		local restanteReal = math.max(0.1, recargaIniciouEm + duracaoNova - os.clock())
		trilha:AdjustSpeed(math.clamp(restanteTrilha / restanteReal, 0.25, 4))
	end
	-- bate o pente no lugar: um tranco curto
	Mola.impulso(molaPos, 0, -0.2, 0.3)
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
	local params = paramsParede
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		paramsParede = params
	end
	local filtro = (params :: RaycastParams).FilterDescendantsInstances
	if filtro[1] ~= personagem or filtro[2] ~= camera then
		(params :: RaycastParams).FilterDescendantsInstances = { personagem, camera }
	end
	local d = CfgVista.parede.distancia
	local r = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * d, params :: RaycastParams)
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

-- Lado ("direita"/"esquerda") em que o ItemNaMao está soldado; nil enquanto a solda ainda não replicou.
local function ladoDoItem(item: Model): string?
	local primaria = item.PrimaryPart
	local solda = primaria and primaria:FindFirstChild("SoldaMao")
	if solda and solda:IsA("WeldConstraint") and solda.Part0 then
		return if solda.Part0.Name == "LeftHand" then "esquerda" else "direita"
	end
	return nil
end

local function lerItens(personagem: Model)
	itensSujo = false
	local novos: { [string]: Model? } = {}
	for _, filho in personagem:GetChildren() do
		if filho.Name == "ItemNaMao" and filho:IsA("Model") then
			local lado = ladoDoItem(filho)
			if lado then
				novos[lado] = filho
			else
				itensSujo = true -- a solda ainda não chegou: olha de novo no próximo quadro
			end
		end
	end
	itensReais = novos
end

-- Recarga em andamento (para mostrar o braço esquerdo de uma arma de uma mão).
local function recarregandoNoRig(): boolean
	local c = clipeRig
	if not (c and c.trilha.IsPlaying) then
		return false
	end
	return c.nome == "Reload" or string.sub(c.nome, 1, 7) == "Recarga"
end

-- Rig com clipes: Idle sempre tocando, etapas da recarga por cartucho, IK e braço esquerdo.
local function manterRig(r: BracosViewmodel.Rig, dt: number, agora: number)
	local idle = idleRig
	if idle and not idle.IsPlaying then
		idle:Play(0.1, 1, 1) -- o rig voltou da 3ª pessoa/carro (ou o clipe acabou): retoma a pose
	end
	local c = clipeRig
	if c and not c.trilha.IsPlaying then
		clipeRig = nil
		c = nil
	end
	local t = tuboRig
	if t and armaCfg then
		local decorrido = agora - t.t0
		local etapa = t.etapas[t.proxima]
		while etapa and decorrido >= etapa.inicio do
			local nativa = (CfgAnim.duracao :: any)[armaCfg.classe][etapa.clipe]
			local vel = CfgVista.rig.velocidade
			tocarRig(
				etapa.clipe,
				RegrasBracos.velocidade(nativa, etapa.duracao, vel.minimo, vel.maximo),
				CfgVista.rig.fade.recarga
			)
			t.proxima += 1
			etapa = t.etapas[t.proxima]
		end
		local ultima = t.etapas[#t.etapas]
		if not etapa and decorrido >= ultima.inicio + ultima.duracao then
			tuboRig = nil
		end
	end
	if modoItem or not (armaCfg and vista) then
		return
	end
	if r.ik then
		local regras = (CfgAnim.ik :: any)[armaCfg.classe]
		local nome = if c then c.nome else nil
		local tempo = if c then c.trilha.TimePosition else 0
		BracosViewmodel.atualizarIK(r, dt, RegrasBracos.ikDesejado(regras, vista.duasMaos, nome, tempo))
	end
	BracosViewmodel.mostrarEsquerda(r, vista.duasMaos or not CfgVista.rig.esquerdaSoNaRecarga or recarregandoNoRig())
end

local function passo(dt: number)
	local personagem = jogador.Character
	local camera = workspace.CurrentCamera
	if armaId and ViewmodelGB.assumiu(armaId) then
		desativar() -- o ViewmodelGB desenha esta arma (docs/gold-bright-import.md)
		if modelo then
			destruirModelo()
		end
		return
	end
	if not (personagem and camera) then
		desativar()
		return
	end
	-- Sem arma, só um item na mão (lanterna, galão, garrafa, comida) pode ligar o viewmodel
	local emItem = false
	if not (armaId and vista) then
		if itemIndisponivel then
			desativar()
			return
		end
		if itensSujo then
			lerItens(personagem)
		end
		if not (itensReais.direita or itensReais.esquerda) then
			desativar() -- devolve o corpo real (idempotente)
			if modelo then
				destruirModelo()
			end
			return
		end
		emItem = true
	end
	if modelo and (personagem ~= personagemMontado or idDoPersonagem(personagem) ~= idMontado) then
		destruirModelo() -- novo personagem (respawn, troca de personagem): refaz com as medidas e o visual dele
	end
	if modelo and modoItem then
		if
			not emItem
			or itensMontados.direita ~= itensReais.direita
			or itensMontados.esquerda ~= itensReais.esquerda
		then
			destruirModelo()
		end
	end
	local primeira, humanoide = emPrimeiraPessoa(personagem, camera)
	if not primeira or not humanoide then
		desativar()
		return
	end
	if modelo and provisorio and not emItem and armaId then
		local AM = carregarArmaModelo()
		if AM and AM.pronta and AM.pronta(armaId) then
			provisorio = false
			destruirModelo() -- a malha chegou: remonta já com ela
		end
	end
	if not modelo then
		if os.clock() - falhouEm < ESPERA_FALHA then
			desativar()
			return
		end
		local construiu = if emItem then construirItem(personagem, camera) else construir(personagem, camera)
		if not construiu then
			desativar()
			return
		end
	end
	local m = modelo :: Model
	local ref: any = if emItem then CfgVista.item else vista

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

	local r = rig
	local pose: Pose
	if r then
		pose = poseZero() -- os clipes do rig fazem o papel das poses; as molas e a corrida seguem por cima
		manterRig(r, dt, agora)
	else
		-- Bombear (escopeta) agendado pelo tiro
		if agora >= bombarEm and vista.bombear then
			bombarEm = math.huge
			if not (clipe and (clipe.nome == "recarga" or clipe.nome == "sacar")) then
				iniciarClipe("bombear", vista.bombear.duracao, preparar(vista.bombear.passos))
			end
		end

		-- Pose do clipe (ou da saída suave de um clipe cancelado)
		local atual = poseDoClipe(agora)
		if atual then
			ultimaPose = atual
		elseif saida then
			local f = (agora - saida.t0) / CfgVista.suavizarSaida
			if f >= 1 then
				saida = nil
			else
				atual = escalarPose(saida.pose, 1 - f * f * (3 - 2 * f))
			end
		end
		pose = atual or poseZero()
	end

	-- Onde o Cabo (ou a mão do item) fica: base + clipe + mola + corrida + parede
	local base = ref.base
	local baseX, baseY = base.pos.x, base.pos.y
	if r then
		if emItem and not itensReais.direita then
			baseX = -baseX -- item só na mão esquerda: espelha
		end
		if CfgVista.rig.compensarFov then
			local escala = RegrasBracos.compensarFov(camera.FieldOfView, CfgVista.rig.fovReferencia)
			baseX *= escala
			baseY *= escala
		end
	end
	local basePos = Vector3.new(baseX, baseY, base.pos.z)
	local pos = basePos + pose.pos + Vector3.new(molaPos.x, molaPos.y, molaPos.z)
	local rot = v3(base.rot) + pose.rot + Vector3.new(molaRot.x, molaRot.y, molaRot.z)
	if corrida > 0.001 then
		pos += v3(ref.correr.pos) * corrida
		rot += v3(ref.correr.rot) * corrida
	end
	if paredeK > 0.001 then
		pos += Vector3.new(0, 0, CfgVista.parede.recuo * paredeK)
		rot += Vector3.new(CfgVista.parede.subida * paredeK, 0, 0)
	end
	local armaCF = camCF
		* CFrame.new(pos)
		* CFrame.fromEulerAnglesYXZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	local caboMundo = armaCF
	if r then
		-- O tronco do rig vai para onde faz o Cabo (1ª pose do Idle) cair em armaCF; os clipes movem o braço a partir daí.
		local tronco: CFrame
		if caboRelativo then
			tronco = armaCF * (caboRelativo :: CFrame):Inverse()
		else
			local res = CfgVista.rig.torsoReserva
			tronco = camCF
				* CFrame.new(v3(res.pos) + pos - basePos)
				* CFrame.fromEulerAnglesYXZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		end
		BracosViewmodel.posicionar(r, tronco)
		if cabo then
			caboMundo = (cabo :: BasePart).CFrame -- onde o clipe realmente deixou a empunhadura
		end
	else
		if arma then
			(arma :: Model):PivotTo(armaCF)
		end

		-- Braços de blocos (plano B)
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
	end

	-- Clarão do tiro
	local f = clarao
	if f and bocaLocal then
		if agora < clarearAte then
			f.Transparency = 0
			local s = CfgVista.clarao.tamanho * rng:NextNumber(0.7, 1.3)
			f.Size = Vector3.new(s, s, s)
			f.CFrame = caboMundo * (bocaLocal :: CFrame) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
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
	ultimoCabo = caboMundo
end

-- Interface para EfeitosArma -----------------------------------------------------------------------------------------------

function ArmasViewmodel.ativo(): boolean
	return ligado or ViewmodelGB.ativo()
end

-- CFrame mundial da boca da arma do viewmodel (nil se não há viewmodel ativo).
function ArmasViewmodel.bocaMundo(): CFrame?
	if ViewmodelGB.ativo() then
		return ViewmodelGB.bocaMundo()
	end
	if ligado and bocaLocal and ultimoCabo then
		-- com rig, o Cabo é a peça de verdade (o clipe do tiro pode ter mexido nela depois do último quadro)
		local c = if rig and cabo then (cabo :: BasePart).CFrame else ultimoCabo
		return c * (bocaLocal :: CFrame)
	end
	return nil
end

function ArmasViewmodel.ejecaoMundo(): CFrame?
	if ligado and ejecaoLocal and ultimoCabo then
		local c = if rig and cabo then (cabo :: BasePart).CFrame else ultimoCabo
		return c * (ejecaoLocal :: CFrame)
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
	ArmasSinais.ouvir("engatilhou", aoEngatilhar)
	ArmasSinais.ouvir("checou", aoChecar)
	ArmasSinais.ouvir("recargaRapida", aoReajustarRecarga)
	ArmasSinais.ouvir("recargaFalhou", aoReajustarRecarga)
	local function observarItens(personagem: Model)
		itensSujo = true
		itensReais = {}
		itemIndisponivel = false
		personagem.ChildAdded:Connect(function()
			itensSujo = true
		end)
		personagem.ChildRemoved:Connect(function()
			itensSujo = true
		end)
	end
	jogador.CharacterAdded:Connect(function(personagem)
		destruirModelo()
		desativar()
		fase, balanco, corrida, paredeK = 0, 0, 0, 0
		observarItens(personagem)
	end)
	if jogador.Character then
		observarItens(jogador.Character)
	end
	RunService:BindToRenderStep("ArmasViewmodel", PRIORIDADE, passo)
end

return ArmasViewmodel
