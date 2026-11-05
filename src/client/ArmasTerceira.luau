-- ArmasTerceira: animação do corpo R15 em 3ª pessoa (docs/armas.md §9). Dono: A4.
-- Toca os clipes de Config/ArmasAnim (por classe de arma) no Animator do PRÓPRIO personagem a partir dos sinais de ArmasSinais
-- (a animação replica sozinha para os outros jogadores), liga a mão esquerda por IKControl no ApoioEsquerdo da arma
-- (ArmaNaMao.Cabo.ApoioEsquerdo, criado por Shared/ArmaModelo) e aplica a camada de MIRA (pitch da câmera em Cintura/Pescoço/
-- ombros, também nos outros jogadores a até `mira.alcance` studs) enviando o pitch ao servidor (evento Mira, 8 Hz).
-- Tolerante: clipe sem id (Config/ArmasAnim.animacoes = false, enquanto não há upload), sem Animator, sem Apoio ou sem o evento
-- Mira = simplesmente não faz aquela parte, sem erro. Nada aqui decide acerto, dano, pente ou ruído.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgAnim = require(Config:WaitForChild("ArmasAnim"))
local ArmasSinais = require(script.Parent.ArmasSinais)

local ArmasTerceira = {}

local jogador = Players.LocalPlayer

local TEMPO_IK = 0.25 -- s: peso do IK sobe/desce neste tempo
local FADE = 0.12 -- s: entrada/saída de clipes

-- Estado do personagem próprio -----------------------------------------------------------------------------------------
local personagem: Model? = nil
local animator: Animator? = nil
local trilhas: { [string]: AnimationTrack? } = {} -- "classe/Clipe" -> trilha (false-like = sem id)
local semId: { [string]: boolean } = {} -- clipes sem id já avisados (um aviso só)
local armaId: string? = nil
local classe: string? = nil
local cfg: any = nil
local idleTrilha: AnimationTrack? = nil
local clipeAtual: { nome: string, trilha: AnimationTrack }? = nil -- Equip/Reload/Golpe em andamento (para o IK)
local recargaId = 0 -- sobe a cada recarga/cancelamento (cancela a sequência do tubo)
local alternaFaca = 1
local ik: IKControl? = nil
local ikPeso = 0
local ikAlvo = 0
local ikProcura = 0
local polo: Attachment? = nil

-- Util -----------------------------------------------------------------------------------------------------------------

local function idDe(c: string, clipe: string): string?
	-- gancho de teste no Studio: atributo do jogador (id de KeyframeSequence registrada), sem upload
	if RunService:IsStudio() then
		local teste = jogador:GetAttribute("AnimTeste_" .. c .. "_" .. clipe)
		if type(teste) == "string" and teste ~= "" then
			return teste
		end
	end
	local porClasse = (CfgAnim.animacoes :: any)[c]
	local id = porClasse and porClasse[clipe]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

-- Trilha do clipe (carrega uma vez por personagem); nil se o clipe não tem id/animator.
local function trilha(c: string, clipe: string): AnimationTrack?
	local chave = c .. "/" .. clipe
	local t = trilhas[chave]
	if t then
		return t
	end
	if not animator then
		return nil
	end
	local id = idDe(c, clipe)
	if not id then
		if not semId[chave] then
			semId[chave] = true
		end
		return nil
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, nova = pcall(function()
		return (animator :: Animator):LoadAnimation(a)
	end)
	if not ok or not nova then
		return nil
	end
	local nomePrio = clipe == "Idle" and "Action"
		or (string.find(clipe, "Recarga") or clipe == "Reload") and "Action3"
		or "Action2"
	nova.Priority = (Enum.AnimationPriority :: any)[nomePrio]
	nova.Looped = clipe == "Idle"
	trilhas[chave] = nova
	return nova :: AnimationTrack
end

local function duracaoNativa(c: string, clipe: string): number
	local d = (CfgAnim.duracao :: any)[c]
	return d and d[clipe] or 1
end

local function pararTodas(fade: number)
	for _, t in trilhas do
		if t and t.IsPlaying then
			t:Stop(fade)
		end
	end
	clipeAtual = nil
end

-- IK da mão esquerda -----------------------------------------------------------------------------------------------------

local function procurarApoio(): Attachment?
	local p = personagem
	local arma = p and p:FindFirstChild("ArmaNaMao")
	local cabo = arma and arma:FindFirstChild("Cabo")
	local apoio = cabo and cabo:FindFirstChild("ApoioEsquerdo")
	if apoio and apoio:IsA("Attachment") then
		return apoio
	end
	return nil
end

local function criarIK()
	local p = personagem
	if not p or ik then
		return
	end
	local humanoide = p:FindFirstChildOfClass("Humanoid")
	local ombro = p:FindFirstChild("LeftUpperArm")
	local mao = p:FindFirstChild("LeftHand")
	local tronco = p:FindFirstChild("UpperTorso")
	if not (humanoide and ombro and mao and tronco) then
		return
	end
	local ponta = mao:FindFirstChild("LeftGripAttachment") or mao
	polo = Instance.new("Attachment")
	polo.Name = "PoloMaoEsquerda"
	polo.Position = Vector3.new(-1.6, -1.4, 0.5) -- o cotovelo dobra para fora e para baixo
	polo.Parent = tronco
	local c = Instance.new("IKControl")
	c.Name = "ApoioEsquerdo"
	c.Type = Enum.IKControlType.Position
	c.ChainRoot = ombro :: BasePart
	c.EndEffector = ponta
	c.Pole = polo
	c.SmoothTime = 0.05
	c.Weight = 0
	c.Enabled = false
	c.Parent = humanoide
	ik = c
end

local function destruirIK()
	if ik then
		ik:Destroy()
		ik = nil
	end
	if polo then
		polo:Destroy()
		polo = nil
	end
	ikPeso = 0
	ikAlvo = 0
end

-- IK desejado agora? (arma de duas mãos com Apoio, e o clipe em andamento não anima a mão esquerda)
local function ikDesejado(): boolean
	if not cfg or not cfg.duasMaos or not classe then
		return false
	end
	local regras = (CfgAnim.ik :: any)[classe]
	local atual = clipeAtual
	if atual and atual.trilha.IsPlaying then
		if regras and regras.desligar[atual.nome] then
			return false
		end
		local janela = regras and regras.janelas[atual.nome]
		if janela then
			local t = atual.trilha.TimePosition
			if t >= janela[1] and t <= janela[2] then
				return false
			end
		end
	end
	return true
end

-- Clipes -----------------------------------------------------------------------------------------------------------------

local function tocar(clipe: string, velocidade: number?, fade: number?): AnimationTrack?
	if not classe then
		return nil
	end
	local t = trilha(classe, clipe)
	if not t then
		return nil
	end
	if t.IsPlaying then
		t.TimePosition = 0
		t:AdjustSpeed(velocidade or 1)
	else
		t:Play(fade or FADE, 1, velocidade or 1)
	end
	if clipe ~= "Idle" then
		clipeAtual = { nome = clipe, trilha = t }
	end
	return t
end

local function equipar(id: string?)
	if id == armaId and (id == nil or idleTrilha ~= nil or classe ~= nil) then
		return
	end
	recargaId += 1
	pararTodas(FADE)
	idleTrilha = nil
	armaId = id
	cfg = id and (CfgArmas.armas :: any)[id] or nil
	classe = cfg and cfg.classe or nil
	if not cfg or not classe then
		armaId = nil
		classe = nil
		cfg = nil
		if ik then
			ik.Enabled = false
		end
		ikAlvo = 0
		return
	end
	idleTrilha = trilha(classe, "Idle")
	if idleTrilha and not idleTrilha.IsPlaying then
		idleTrilha:Play(0.2, 1, 1)
	end
	tocar("Equip", 1, 0.08)
	if cfg.duasMaos then
		criarIK()
	end
end

local function aoDisparar(id: string)
	if id ~= armaId or not classe or not cfg then
		return
	end
	local dur = duracaoNativa(classe, "Fire")
	local velocidade = math.max(1, dur / math.max(cfg.cadencia or dur, 0.05))
	tocar("Fire", velocidade, 0.02)
end

-- `indice` (1/2) vem do ArmasCliente (a faca alterna estocada e corte, igual ao viewmodel); sem ele alterna aqui.
local function aoGolpear(id: string, indice: number?)
	if id ~= armaId or not classe then
		return
	end
	if classe == "faca" then
		local i = if indice == 1 or indice == 2 then indice else alternaFaca
		alternaFaca = 3 - i
		tocar("Golpe" .. i, 1, 0.04)
	else
		tocar("Golpe", 1, 0.05)
	end
end

local function aoRecarregar(id: string, duracao: number)
	if id ~= armaId or not classe or not cfg or not cfg.recarga then
		return
	end
	recargaId += 1
	local meu = recargaId
	local r = cfg.recarga
	if r.tipo == "pente" then
		local dur = duracaoNativa(classe, "Reload")
		tocar("Reload", dur / math.max(duracao, 0.1), 0.15)
		return
	end
	-- tubo: Inicio, N x Cartucho, Fim (N pelo tempo total que o servidor mandou)
	local n = math.max(0, math.floor((duracao - r.inicio - r.fim) / r.porCartucho + 0.5))
	task.spawn(function()
		-- sem id o clipe não toca, mas o tempo do passo corre igual (o servidor manda no mesmo ritmo)
		local function passo(clipe: string, tempoCfg: number): boolean
			tocar(clipe, duracaoNativa(classe :: string, clipe) / math.max(tempoCfg, 0.05), 0.08)
			task.wait(tempoCfg)
			return meu == recargaId
		end
		if not passo("RecargaInicio", r.inicio) then
			return
		end
		for _ = 1, n do
			if not passo("RecargaCartucho", r.porCartucho) then
				return
			end
		end
		passo("RecargaFim", r.fim)
	end)
end

local function aoFimRecarga(id: string, cancelada: boolean)
	if id ~= armaId then
		return
	end
	if cancelada then
		recargaId += 1
	end
	if not classe then
		return
	end
	for _, nome in { "Reload", "RecargaInicio", "RecargaCartucho", "RecargaFim" } do
		local t = trilhas[classe .. "/" .. nome]
		if t and t.IsPlaying then
			t:Stop(if cancelada then 0.15 else 0.1)
		end
	end
	if clipeAtual and not clipeAtual.trilha.IsPlaying then
		clipeAtual = nil
	end
end

-- Mira (pitch) -----------------------------------------------------------------------------------------------------------

type Estado = { base: CFrame, escrito: CFrame }
local estados: { [Instance]: Estado } = {} -- por junta: o que o Animator deu (base) e o que EU escrevi por cima (escrito)
local juntasDe: { [Model]: { [string]: Instance? } } = setmetatable({}, { __mode = "k" }) :: any
local pitchSuave: { [Player]: number } = {}
local pitchEnviado = 0
local ultimoEnvio = 0
local eventoMira: RemoteEvent? = nil

local function junta(p: Model, nome: string): Instance?
	local cache = juntasDe[p]
	if not cache then
		cache = {}
		juntasDe[p] = cache
	end
	local j = (cache :: any)[nome]
	if j and j.Parent then
		return j
	end
	for _, d in p:GetDescendants() do
		if d.Name == nome and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
			(cache :: any)[nome] = d
			return d
		end
	end
	return nil
end

-- Pré-multiplica uma rotação de pitch no Transform da junta SEM acumular: se o Animator reescreveu o Transform neste quadro, a
-- base é o valor novo; se ninguém mexeu (Transform == o que escrevi), a base continua a do quadro anterior.
local function girar(j: Instance, graus: number)
	local jj = j :: any
	local atual: CFrame = jj.Transform
	local est = estados[j]
	local base = atual
	if est and atual == est.escrito then
		base = est.base
	end
	local novo = CFrame.Angles(math.rad(graus), 0, 0) * base
	jj.Transform = novo
	estados[j] = { base = base, escrito = novo }
end

local function soltar(p: Model)
	for _, nome in { "Waist", "Neck", "LeftShoulder", "RightShoulder" } do
		local j = junta(p, nome)
		local est = j and estados[j]
		if j and est then
			if (j :: any).Transform == est.escrito then
				(j :: any).Transform = est.base
			end
			estados[j] = nil
		end
	end
end

local function aplicarMira(p: Model, pitch: number, cfgArma: any)
	local m = CfgAnim.mira
	local cintura = math.clamp(pitch * m.cintura, -m.maxCintura, m.maxCintura)
	local pescoco = math.clamp(pitch * m.pescoco, -m.maxPescoco, m.maxPescoco)
	local waist = junta(p, "Waist")
	if waist then
		girar(waist, cintura)
	end
	local neck = junta(p, "Neck")
	if neck then
		girar(neck, pescoco)
	end
	if cfgArma and cfgArma.tipo == "fogo" then
		local ombro = math.clamp(pitch * m.ombros, -m.maxOmbro, m.maxOmbro)
		local d = junta(p, "RightShoulder")
		if d then
			girar(d, ombro)
		end
		if cfgArma.duasMaos then
			local e = junta(p, "LeftShoulder")
			if e then
				girar(e, ombro)
			end
		end
	end
end

local function pitchDaCamera(): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	return math.clamp(math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1))), -80, 80)
end

local alcanceAoQuadrado = CfgAnim.mira.alcance * CfgAnim.mira.alcance
local comArma: { [Player]: boolean } = {}

local function quadro(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local origem = cam.CFrame.Position
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local raiz = c and c:FindFirstChild("HumanoidRootPart")
		local id = p:GetAttribute("ArmaEquipada")
		local armada = c ~= nil and raiz ~= nil and type(id) == "string"
		if armada and ((raiz :: BasePart).Position - origem).Magnitude ^ 2 <= alcanceAoQuadrado then
			local alvo
			if p == jogador then
				alvo = pitchDaCamera()
				pitchSuave[p] = alvo
			else
				alvo = tonumber(p:GetAttribute("MiraPitch")) or 0
				local atual = pitchSuave[p] or alvo
				atual += (alvo - atual) * math.min(1, dt * CfgAnim.mira.suavizar)
				pitchSuave[p] = atual
				alvo = atual
			end
			aplicarMira(c :: Model, alvo, (CfgArmas.armas :: any)[id])
			comArma[p] = true
		elseif comArma[p] then
			comArma[p] = nil
			if c then
				soltar(c)
			end
		end
	end
end

local function enviarMira(agora: number)
	if not armaId or not eventoMira then
		return
	end
	if agora - ultimoEnvio < 1 / CfgAnim.mira.hz then
		return
	end
	local pitch = pitchDaCamera()
	if math.abs(pitch - pitchEnviado) < 0.5 and agora - ultimoEnvio < 1 then
		return
	end
	ultimoEnvio = agora
	pitchEnviado = pitch
	eventoMira:FireServer(pitch)
end

-- IK por quadro: peso suave e Apoio atual ------------------------------------------------------------------------------
local function atualizarIK(dt: number, agora: number)
	local c = ik
	if not c then
		return
	end
	if agora - ikProcura > 0.2 then
		ikProcura = agora
		local apoio = procurarApoio()
		if apoio ~= c.Target then
			c.Target = apoio
		end
	end
	ikAlvo = (c.Target ~= nil and ikDesejado()) and 1 or 0
	ikPeso += math.clamp(ikAlvo - ikPeso, -dt / TEMPO_IK, dt / TEMPO_IK)
	c.Weight = ikPeso
	c.Enabled = ikPeso > 0.001 or ikAlvo > 0
end

-- Personagem -----------------------------------------------------------------------------------------------------------

local function aoPersonagem(p: Model)
	personagem = p
	trilhas = {}
	semId = {}
	armaId = nil
	classe = nil
	cfg = nil
	idleTrilha = nil
	clipeAtual = nil
	destruirIK()
	recargaId += 1
	animator = nil
	task.spawn(function()
		local h = p:WaitForChild("Humanoid", 10)
		local a = h and h:WaitForChild("Animator", 10)
		if p == personagem and a and a:IsA("Animator") then
			animator = a
			-- já com arma ao nascer (respawn com o atributo ainda setado): entra no Idle
			local id = jogador:GetAttribute("ArmaEquipada")
			if type(id) == "string" then
				equipar(id)
			end
		end
	end)
end

function ArmasTerceira.iniciar()
	local ok, ev = pcall(Rede.evento, "Mira")
	if ok then
		eventoMira = ev
	end

	ArmasSinais.ouvir("equipou", equipar)
	ArmasSinais.ouvir("disparou", aoDisparar)
	ArmasSinais.ouvir("golpeou", aoGolpear)
	ArmasSinais.ouvir("recarregou", aoRecarregar)
	ArmasSinais.ouvir("recargaFim", aoFimRecarga)

	-- rede de segurança: se o atributo mudar sem o sinal (respawn, servidor desequipou), o Idle acompanha
	jogador:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
		local id = jogador:GetAttribute("ArmaEquipada")
		equipar(if type(id) == "string" then id else nil)
	end)

	jogador.CharacterAdded:Connect(aoPersonagem)
	if jogador.Character then
		aoPersonagem(jogador.Character)
	end

	-- depois da Camera e do Animator: o Transform já veio do clipe/IK neste quadro
	RunService:BindToRenderStep("ArmasTerceira", Enum.RenderPriority.Camera.Value + 5, function(dt)
		local agora = os.clock()
		quadro(dt)
		atualizarIK(dt, agora)
		enviarMira(agora)
	end)
end

return ArmasTerceira
