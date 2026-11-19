-- BracosViewmodel: rig R15 mínimo dos braços em 1ª pessoa (docs/personagens.md, Parte A2). Dono: A2.
-- Monta, para o viewmodel, um Model local com HumanoidRootPart (âncora, invisível) > LowerTorso > UpperTorso (invisíveis) e
-- os dois braços (UpperArm, LowerArm, Hand) ligados por Motor6D com os MESMOS C0/C1 do personagem real (copiados dele), mais
-- um AnimationController + Animator. Os clipes são os da 3ª pessoa (`Animacao.trilha(animator, "armas/<classe>", clipe)`, do
-- agente A1). A aparência dos 6 segmentos vem de `PersonagemVisual.criarParte` (agente S) com o PersonagemId do personagem;
-- sem esse módulo, blocos nas cores de Config/Aparencia. Quem POSICIONA o rig a cada quadro (câmera + molas) é o
-- ArmasViewmodel; aqui só se constrói, prende arma/item na mão, calibra pela primeira pose do clipe e cuida do IK da mão esquerda.
-- Tudo tolerante: qualquer falha devolve nil e o ArmasViewmodel cai no plano B (blocos movidos por poses).
-- Nenhuma Instance nova é criada por quadro; só `posicionar` (uma atribuição de CFrame) e `atualizarIK` rodam no render.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgAparencia = require(Config:WaitForChild("Aparencia"))
local CfgAnim = require(Config:WaitForChild("ArmasAnim"))
local CfgVista = require(Config:WaitForChild("ArmasVista"))

local BracosViewmodel = {}

export type Rig = {
	modelo: Model,
	raiz: BasePart, -- HumanoidRootPart: a única peça ancorada; mover a raiz move o rig inteiro
	animator: Animator,
	controle: AnimationController,
	maoD: BasePart,
	maoE: BasePart,
	juntas: { [string]: Motor6D }, -- pelo nome da peça que a junta move (Part1): "RightUpperArm", "LeftHand"...
	kInv: CFrame, -- raiz = tronco * kInv (a raiz fica atrás do UpperTorso pelas juntas Root e Waist)
	personagemId: string,
	ladoEsquerdo: { BasePart },
	esquerdaVisivel: boolean,
	ik: IKControl?,
	ikPeso: number,
	calibracao: { [string]: CFrame? },
}

local JUNTAS =
	{ "Root", "Waist", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist" }
local PARTES_BRACO = { "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand" }
local TEMPO_IK = 0.25 -- s: o peso do IK sobe/desce neste tempo (igual à 3ª pessoa)

-- Módulos dos outros agentes, carregados na hora e uma vez: se faltarem, o viewmodel cai no plano B (ou usa blocos de cor).
local modulos: { [string]: any } = {}
local avisados: { [string]: boolean } = {}

local function avisar(chave: string, texto: string)
	if not avisados[chave] then
		avisados[chave] = true
		warn("[BracosViewmodel] " .. texto)
	end
end

local function modulo(nome: string): any
	local m = modulos[nome]
	if m == nil then
		local arquivo = Shared:FindFirstChild(nome)
		m = false
		if arquivo then
			local ok, resultado = pcall(require, arquivo)
			if ok then
				m = resultado
			else
				avisar("req_" .. nome, nome .. " falhou ao carregar: " .. tostring(resultado))
			end
		end
		modulos[nome] = m
	end
	return m or nil
end

-- Animacao (A1): API de clipes em runtime. nil = ainda não entregue.
local function animacao(): any
	return modulo("Animacao")
end

-- PersonagemVisual (S): peça visual por personagem. nil = ainda não entregue (blocos de cor da pele/suéter).
local function personagemVisual(): any
	return modulo("PersonagemVisual")
end

function BracosViewmodel.temAnimacao(): boolean
	return animacao() ~= nil
end

-- Peças -------------------------------------------------------------------------------------------------------------------

local function ajustarPeca(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

local function pecaInvisivel(nome: string, tamanho: Vector3, pai: Instance): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamanho
	p.Transparency = 1
	ajustarPeca(p)
	p.Parent = pai
	return p
end

local function cor(nome: string): Color3
	local c = CfgAparencia.cores[nome]
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- opcoes de PersonagemVisual.criarParte: a raiz do corpo REAL (a peça `original` é do personagem real, então o modelo dela
-- já é o certo; passo explícito para a malha nunca ancorar em outro lugar).
local function opcoesVisual(original: BasePart): { raiz: BasePart? }
	local modelo = original.Parent
	local raiz = modelo and modelo:FindFirstChild("HumanoidRootPart")
	return { raiz = if raiz and raiz:IsA("BasePart") then raiz else nil }
end

-- CFrame da peça em relação à HumanoidRootPart na pose de repouso (juntas sem Transform), pela cadeia de juntas até a raiz.
-- Cada junta leva a peça filha à posição Part0 * C0 * C1⁻¹. nil se a cadeia não chegar à raiz.

local aquecidos: { [string]: boolean } = {}
local aquecendo: { [string]: boolean } = {}

-- Baixa as malhas dos 6 segmentos do personagem `id` fora do render (PersonagemVisual guarda o molde em cache) e marca como pronto.
-- Sem malhas (visual "bloco") não precisa. `modelo` das peças reais serve só de medida; as peças criadas aqui são descartadas.
function BracosViewmodel.aquecer(id: string, original: BasePart)
	if aquecidos[id] or aquecendo[id] then
		return
	end
	aquecendo[id] = true
	task.spawn(function()
		local PV = personagemVisual()
		if PV and PV.criarParte then
			for _, nome in PARTES_BRACO do
				local ok, r = pcall(PV.criarParte, id, nome, original, opcoesVisual(original))
				if ok and typeof(r) == "Instance" then
					r:Destroy()
				end
			end
		end
		aquecidos[id] = true
		aquecendo[id] = nil
	end)
end

-- Peça visual de um segmento do braço: PersonagemVisual.criarParte (id do personagem) ou um bloco de cor. Mesmo tamanho da peça
-- R15 real (as juntas dependem disso), com X e Z afinados por CfgVista.rig.espessura.
local function pecaDeBraco(nome: string, original: BasePart, personagemId: string, pai: Instance): (BasePart, BasePart)
	local parte: BasePart? = nil
	local PV = personagemVisual()
	-- criarParte com malhas pode ESPERAR o download (rende), e este código roda no passo de render (não pode render):
	-- enquanto a malha do personagem não foi aquecida, os braços saem em blocos de cor e o aquecimento corre em paralelo.
	if PV and PV.criarParte and PV.visual and PV.visual(personagemId) == "malhas" and not aquecidos[personagemId] then
		BracosViewmodel.aquecer(personagemId, original)
		PV = nil
	end
	if PV and PV.criarParte then
		local ok, r = pcall(PV.criarParte, personagemId, nome, original, opcoesVisual(original))
		if ok and typeof(r) == "Instance" and r:IsA("BasePart") then
			parte = r
		else
			avisar("criarParte_" .. nome, "PersonagemVisual.criarParte falhou para " .. nome .. ": " .. tostring(r))
		end
	end
	if not parte then
		local bloco = Instance.new("Part")
		local mao = string.find(nome, "Hand", 1, true) ~= nil
		bloco.Color = cor(if mao then "pele" else "suter")
		bloco.Material = if mao then Enum.Material.SmoothPlastic else Enum.Material.Fabric
		bloco.TopSurface = Enum.SurfaceType.Smooth
		bloco.BottomSurface = Enum.SurfaceType.Smooth
		parte = bloco
	end
	local p = parte :: BasePart
	if p:IsA("MeshPart") then
		-- Malha (visual "malhas"): criarParte devolve a MeshPart no espaço do corpo real, com Size nativo e deslocada da peça R15.
		-- O segmento do rig continua uma peça invisível com a medida R15 (as juntas dependem dela); a malha vai soldada nela
		-- com o deslocamento fixo que tinha em relação à peça real, sem mexer no Size.
		-- O deslocamento é medido na pose de REPOUSO (cadeia de juntas C0 * C1⁻¹ até a raiz), não na pose atual do braço real:
		-- o viewmodel é montado com o clipe da arma tocando, e a pose atual deslocaria a malha.
		-- No viewmodel a malha vai CENTRADA no segmento R15 (a arma prende na mão R15: assim a mão de malha fica no cabo).
		-- O braço superior fica invisível: preso à câmera, ele tapava a tela.
		local deslocamento = CFrame.identity
		-- antebraço também: preso à câmera e apontando para o ombro (ao lado da câmera), virava um bloco enorme na tela
		if string.find(nome, "UpperArm", 1, true) or string.find(nome, "LowerArm", 1, true) then
			p.LocalTransparencyModifier = 1
		end
		local segmento = pecaInvisivel(nome, original.Size, pai)
		p.Name = "Malha"
		p.Transparency = 0
		ajustarPeca(p)
		p.CFrame = segmento.CFrame * deslocamento
		local solda = Instance.new("WeldConstraint")
		solda.Part0 = segmento
		solda.Part1 = p
		solda.Parent = p
		p.Parent = segmento
		return segmento, p
	end
	p.Name = nome
	local e = CfgVista.rig.espessura
	p.Size = Vector3.new(original.Size.X * e, original.Size.Y, original.Size.Z * e)
	p.Transparency = 0
	ajustarPeca(p)
	p.Parent = pai
	return p, p
end

-- O R15 do Studio novo usa AnimationConstraint nas juntas (sem Motor6D); o antigo, Motor6D. As duas têm Part0/Part1/C0/C1.
local function juntaReal(personagem: Model, nome: string): (Motor6D | AnimationConstraint)?
	local j = personagem:FindFirstChild(nome, true)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and j.Part0 and j.Part1 then
		return j
	end
	return nil
end

-- Construção --------------------------------------------------------------------------------------------------------------

-- Monta o rig a partir do personagem real e o põe em `pai` (a câmera: o Animator só toca com o rig no Workspace).
-- Devolve nil + motivo se algo do R15 real faltar ou o módulo Animacao não existir.
function BracosViewmodel.criar(personagem: Model, pai: Instance): (Rig?, string?)
	if not animacao() then
		return nil, "módulo Animacao ainda não existe"
	end
	local reais: { [string]: Motor6D | AnimationConstraint } = {}
	for _, nome in JUNTAS do
		local j = juntaReal(personagem, nome)
		if not j then
			return nil, "personagem sem a junta " .. nome
		end
		reais[nome] = j
	end
	local originais: { [string]: BasePart } = {}
	for _, nome in PARTES_BRACO do
		local p = personagem:FindFirstChild(nome)
		if not (p and p:IsA("BasePart")) then
			return nil, "personagem sem a peça " .. nome
		end
		originais[nome] = p
	end
	local personagemId = personagem:GetAttribute("PersonagemId")
	if type(personagemId) ~= "string" or personagemId == "" then
		personagemId = "male_casual"
	end

	local modelo = Instance.new("Model")
	modelo.Name = "ArmasViewmodel"
	local controle = Instance.new("AnimationController")
	controle.Name = "Controle"
	controle.Parent = modelo
	local animator = Instance.new("Animator")
	animator.Parent = controle

	-- tronco invisível (mesmas medidas do real, para as juntas baterem)
	local function medida(nome: string, reserva: Vector3): Vector3
		local p = personagem:FindFirstChild(nome)
		return if p and p:IsA("BasePart") then p.Size else reserva
	end
	local pecas: { [string]: BasePart } = {}
	local visuais: { [string]: BasePart } = {} -- o que se vê de cada segmento (ele mesmo, ou a MeshPart filha)
	pecas.HumanoidRootPart = pecaInvisivel("HumanoidRootPart", medida("HumanoidRootPart", Vector3.new(2, 2, 1)), modelo)
	pecas.LowerTorso = pecaInvisivel("LowerTorso", medida("LowerTorso", Vector3.new(2, 0.4, 1)), modelo)
	pecas.UpperTorso = pecaInvisivel("UpperTorso", medida("UpperTorso", Vector3.new(2, 1.6, 1)), modelo)
	pecas.HumanoidRootPart.Anchored = true
	for _, nome in PARTES_BRACO do
		pecas[nome], visuais[nome] = pecaDeBraco(nome, originais[nome], personagemId, modelo)
	end
	modelo.PrimaryPart = pecas.HumanoidRootPart

	-- juntas: mesmos C0/C1 do real, Part0/Part1 pelos nomes das peças que o real liga
	local juntas: { [string]: Motor6D } = {}
	for _, nome in JUNTAS do
		local real = reais[nome]
		local p0, p1 = pecas[real.Part0.Name], pecas[real.Part1.Name]
		if not (p0 and p1) then
			modelo:Destroy()
			return nil,
				"a junta " .. nome .. " liga peças fora do rig (" .. real.Part0.Name .. " > " .. real.Part1.Name .. ")"
		end
		local j = Instance.new("Motor6D")
		j.Name = nome
		j.Part0 = p0
		j.Part1 = p1
		j.C0 = real.C0
		j.C1 = real.C1
		j.Parent = p1
		juntas[real.Part1.Name] = j
	end

	-- pontas de agarrar e pólo do IK
	for _, nome in { "RightGripAttachment", "LeftGripAttachment" } do
		local lado = if string.sub(nome, 1, 1) == "R" then "RightHand" else "LeftHand"
		local at = originais[lado]:FindFirstChild(nome)
		if at and at:IsA("Attachment") then
			at:Clone().Parent = pecas[lado]
		end
	end

	local raiz = juntas.LowerTorso :: Motor6D
	local cintura = juntas.UpperTorso :: Motor6D
	local k = raiz.C0 * raiz.C1:Inverse() * cintura.C0 * cintura.C1:Inverse()

	modelo.Parent = pai
	local rig: Rig = {
		modelo = modelo,
		raiz = pecas.HumanoidRootPart,
		animator = animator,
		controle = controle,
		maoD = pecas.RightHand,
		maoE = pecas.LeftHand,
		juntas = juntas,
		kInv = k:Inverse(),
		personagemId = personagemId,
		ladoEsquerdo = { visuais.LeftUpperArm, visuais.LeftLowerArm, visuais.LeftHand },
		esquerdaVisivel = true,
		ik = nil,
		ikPeso = 0,
		calibracao = {},
	}
	return rig, nil
end

function BracosViewmodel.destruir(rig: Rig?)
	if rig then
		rig.modelo:Destroy()
	end
end

-- Clipes ------------------------------------------------------------------------------------------------------------------

-- Trilha do clipe no Animator do rig (cache e prioridade/loop são da Animacao). nil se o clipe não existe.
function BracosViewmodel.trilha(rig: Rig, grupo: string, clipe: string): AnimationTrack?
	local A = animacao()
	if not A then
		return nil
	end
	local ok, t = pcall(A.trilha, rig.animator, grupo, clipe)
	if ok and t then
		return t
	end
	if not ok then
		avisar("trilha_" .. grupo .. clipe, "Animacao.trilha(" .. grupo .. ", " .. clipe .. ") falhou: " .. tostring(t))
	end
	return nil
end

-- Carrega (sem tocar) todos os clipes conhecidos do grupo, para o primeiro tiro/recarga não engasgar.
function BracosViewmodel.precarregar(rig: Rig, grupo: string, classe: string)
	local duracoes = (CfgAnim.duracao :: any)[classe]
	if duracoes then
		for clipe in duracoes do
			BracosViewmodel.trilha(rig, grupo, clipe)
		end
	end
end

-- Calibração -----------------------------------------------------------------------------------------------------------------

-- CFrame do ponto `extra` da mão (RightHand ou LeftHand; `extra` por exemplo o C0 do Cabo) em relação ao UpperTorso do rig,
-- na PRIMEIRA pose do clipe (cinemática direta com os C0/C1 do rig e as poses da KeyframeSequence). O ArmasViewmodel
-- posiciona o tronco como `alvoDoPonto * relativo:Inverse()`, e assim o Cabo cai exatamente em `base` com o Idle. nil se
-- o clipe não tem KeyframeSequence legível.
function BracosViewmodel.relativo(rig: Rig, grupo: string, clipe: string, lado: string, extra: CFrame?): CFrame?
	local chave = grupo .. "/" .. clipe .. "/" .. lado
	local pronto = rig.calibracao[chave]
	if pronto ~= nil then
		return pronto
	end
	local A = animacao()
	if not (A and A.sequencia) then
		return nil
	end
	local ok, seq = pcall(A.sequencia, grupo, clipe)
	if not (ok and typeof(seq) == "Instance" and seq:IsA("KeyframeSequence")) then
		return nil
	end
	local primeiro: Keyframe? = nil
	for _, kf in seq:GetKeyframes() do
		if kf:IsA("Keyframe") and (primeiro == nil or kf.Time < primeiro.Time) then
			primeiro = kf
		end
	end
	if not primeiro then
		return nil
	end
	local poses: { [string]: CFrame } = {}
	local function coletar(p: Instance)
		if p:IsA("Pose") then
			poses[p.Name] = p.CFrame
			for _, filho in p:GetSubPoses() do
				coletar(filho)
			end
		end
	end
	for _, p in primeiro:GetPoses() do
		coletar(p)
	end
	local prefixo = if lado == "esquerda" then "Left" else "Right"
	local rel = CFrame.identity
	for _, nome in { prefixo .. "UpperArm", prefixo .. "LowerArm", prefixo .. "Hand" } do
		local j = rig.juntas[nome]
		if not j then
			return nil
		end
		rel = rel * j.C0 * (poses[nome] or CFrame.identity) * j.C1:Inverse()
	end
	if extra then
		rel = rel * extra
	end
	rig.calibracao[chave] = rel
	return rel
end

-- Move o rig inteiro: `tronco` é o CFrame desejado do UpperTorso.
function BracosViewmodel.posicionar(rig: Rig, tronco: CFrame)
	rig.raiz.CFrame = tronco * rig.kInv
end

-- Arma e item na mão ---------------------------------------------------------------------------------------------------------

-- Solda a arma (Cabo) à RightHand do rig por Motor6D `JuntaArma` com o C0 de Config/ArmasAnim.mao (o mesmo do servidor/3ª pessoa).
function BracosViewmodel.prenderArma(rig: Rig, arma: Model, cabo: BasePart, classe: string)
	for _, d in arma:GetDescendants() do
		if d:IsA("BasePart") then
			ajustarPeca(d)
		end
	end
	ajustarPeca(cabo)
	local c0 = (CfgAnim.mao.porClasse :: any)[classe] or CfgAnim.mao.C0
	local j = Instance.new("Motor6D")
	j.Name = "JuntaArma"
	j.Part0 = rig.maoD
	j.Part1 = cabo
	j.C0 = c0
	j.C1 = CFrame.identity
	j.Parent = cabo
end

-- Copia o ItemNaMao real (blocos, ItemModelo) para a mão do rig, com o mesmo deslocamento que ele tem na mão real.
function BracosViewmodel.prenderItem(rig: Rig, personagem: Model, real: Model, lado: string): Model?
	local primaria = real.PrimaryPart
	local maoReal = personagem:FindFirstChild(if lado == "esquerda" then "LeftHand" else "RightHand")
	if not (primaria and maoReal and maoReal:IsA("BasePart")) then
		return nil
	end
	local deslocamento = maoReal.CFrame:ToObjectSpace(primaria.CFrame)
	local copia = real:Clone()
	local nova = copia.PrimaryPart
	if not nova then
		copia:Destroy()
		return nil
	end
	for _, d in copia:GetDescendants() do
		local solda = d:IsA("WeldConstraint") and d.Name == "SoldaMao" -- apontava para a mão real
		if solda or d:IsA("Light") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- luz e comportamento ficam só no item real
		elseif d:IsA("BasePart") then
			ajustarPeca(d)
			d.LocalTransparencyModifier = 0
		end
	end
	ajustarPeca(nova)
	nova.LocalTransparencyModifier = 0
	local j = Instance.new("Motor6D")
	j.Name = "JuntaItem"
	j.Part0 = if lado == "esquerda" then rig.maoE else rig.maoD
	j.Part1 = nova
	j.C0 = deslocamento
	j.C1 = CFrame.identity
	j.Parent = nova
	copia.Name = "Item_" .. lado
	copia.Parent = rig.modelo
	return copia
end

-- Braço esquerdo ---------------------------------------------------------------------------------------------------------------

function BracosViewmodel.mostrarEsquerda(rig: Rig, visivel: boolean)
	if rig.esquerdaVisivel == visivel then
		return
	end
	rig.esquerdaVisivel = visivel
	for _, p in rig.ladoEsquerdo do
		p.Transparency = if visivel then 0 else 1
	end
end

-- IK da mão esquerda no ApoioEsquerdo da arma (mesma ideia do ArmasTerceira) ---------------------------------------------------

-- Cria o IKControl uma vez por rig. Se o Roblox recusar (rig sem Humanoid, propriedade nova), o braço fica só com o clipe.
function BracosViewmodel.prepararIK(rig: Rig, apoio: Attachment?)
	if rig.ik or not apoio then
		return
	end
	local ok, erro = pcall(function()
		local ombro = rig.juntas.LeftUpperArm.Part1 :: BasePart
		local ponta: Instance = rig.maoE:FindFirstChild("LeftGripAttachment") or rig.maoE
		local polo = Instance.new("Attachment")
		polo.Name = "PoloMaoEsquerda"
		polo.Position = Vector3.new(-1.6, -1.4, 0.5) -- o cotovelo dobra para fora e para baixo
		polo.Parent = rig.juntas.UpperTorso.Part1
		local c = Instance.new("IKControl")
		c.Name = "ApoioEsquerdo"
		c.Type = Enum.IKControlType.Position
		c.ChainRoot = ombro
		c.EndEffector = ponta
		c.Pole = polo
		c.Target = apoio
		c.SmoothTime = 0.05
		c.Weight = 0
		c.Enabled = false
		c.Parent = rig.controle
		rig.ik = c
	end)
	if not ok then
		avisar("ik", "IKControl da mão esquerda indisponível no viewmodel: " .. tostring(erro))
	end
end

local c0Ombro: { [any]: CFrame } = setmetatable({}, { __mode = "k" }) :: any -- C0 original do ombro esquerdo por rig

function BracosViewmodel.atualizarIK(rig: Rig, dt: number, desejado: boolean)
	local c = rig.ik
	if not c then
		return
	end
	local alvo = if desejado then 1 else 0
	rig.ikPeso += math.clamp(alvo - rig.ikPeso, -dt / TEMPO_IK, dt / TEMPO_IK)
	c.Weight = rig.ikPeso
	c.Enabled = rig.ikPeso > 0.001 or desejado
	-- Alcance: no viewmodel o apoio da mão esquerda costuma ficar além do braço (medido: AK-74 2,49 studs do ombro, braço
	-- 2,19). Tronco e braço superior são invisíveis aqui, então o ombro esquerdo avança na direção do apoio o que faltar.
	local ombro = rig.juntas.LeftUpperArm
	local alvoAt = c.Target
	if not ombro then
		return
	end
	local base = c0Ombro[rig] or ombro.C0
	c0Ombro[rig] = base
	local antebraco, mao = rig.juntas.LeftLowerArm, rig.juntas.LeftHand
	if not (alvoAt and alvoAt:IsA("Attachment") and antebraco and mao and ombro.Part0 and ombro.Part1) then
		ombro.C0 = base
		return
	end
	local tronco = ombro.Part0 :: BasePart
	local alcance = (ombro.Part1.Size.Y + (antebraco.Part1 :: BasePart).Size.Y + (mao.Part1 :: BasePart).Size.Y * 0.5)
		* 0.95
	local v = alvoAt.WorldPosition - tronco.CFrame * base.Position
	local falta = v.Magnitude - alcance
	if falta > 0 and rig.ikPeso > 0.001 then
		ombro.C0 = base + tronco.CFrame:VectorToObjectSpace(v.Unit) * falta * rig.ikPeso
	else
		ombro.C0 = base
	end
end

return BracosViewmodel
