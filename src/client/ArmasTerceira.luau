-- ArmasTerceira: animação do corpo R15 em 3ª pessoa (docs/armas.md §9). Dono: A4.
-- Toca os clipes de Config/ArmasAnim (por classe de arma) no Animator do PRÓPRIO personagem a partir dos sinais de ArmasSinais
-- (a animação replica sozinha para os outros jogadores), liga a mão esquerda por IKControl no ApoioEsquerdo da arma
-- (ArmaNaMao.Cabo.ApoioEsquerdo, criado por Shared/ArmaModelo) e aplica a camada de MIRA (pitch da câmera em Cintura/Pescoço/
-- ombros, também nos outros jogadores a até `mira.alcance` studs) enviando o pitch ao servidor (evento Mira, 8 Hz).
-- Os clipes vêm de Shared/Animacao: id publicado de Config/ArmasAnim se existir, senão a KeyframeSequence montada do JSON
-- (assets/animacoes/armas) e registrada em runtime, então funciona sem upload. Cada cliente toca os clipes também nos OUTROS
-- jogadores (seção "Outros jogadores"): equipar/mira por atributos do Player (ArmaEquipada, MiraPitch), tiro pelo evento Disparo,
-- recarga por Recarregando, golpe por GolpeSeq (o servidor sobe esse contador a cada golpe aceito, server/Armas.luau).
-- Tolerante: sem dado/clipe, sem Animator, sem Apoio ou sem o evento Mira = simplesmente não faz aquela parte, sem erro.
-- Nada aqui decide acerto, dano, pente ou ruído.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgAnim = require(Config:WaitForChild("ArmasAnim"))
local Animacao = require(Shared:WaitForChild("Animacao"))
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

-- Gancho de teste no Studio: atributo do jogador com o id de uma KeyframeSequence registrada, sem upload.
local function idTeste(c: string, clipe: string): string?
	if RunService:IsStudio() then
		local teste = jogador:GetAttribute("AnimTeste_" .. c .. "_" .. clipe)
		if type(teste) == "string" and teste ~= "" then
			return teste
		end
	end
	return nil
end

-- Trilha do clipe (carrega uma vez por personagem); nil se o clipe não existe/não carregou. Prioridade e laço vêm do JSON.
local function trilha(c: string, clipe: string): AnimationTrack?
	local chave = c .. "/" .. clipe
	local t = trilhas[chave]
	if t then
		return t
	end
	if not animator then
		return nil
	end
	local nova = Animacao.trilha(animator, "armas/" .. c, clipe, { id = idTeste(c, clipe) })
	if not nova then
		if not semId[chave] then
			semId[chave] = true
		end
		return nil
	end
	trilhas[chave] = nova
	return nova
end

local function duracaoNativa(c: string, clipe: string): number
	local d = Animacao.duracao("armas/" .. c, clipe)
	if d > 0 then
		return d
	end
	local porClasse = (CfgAnim.duracao :: any)[c]
	return porClasse and porClasse[clipe] or 1
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

-- Outros jogadores ---------------------------------------------------------------------------------------------------------
-- Cada cliente toca os clipes no Animator dos outros (o registro em runtime só vale em quem registrou). Estado vindo do servidor:
-- Player.ArmaEquipada (arma na mão), Recarregando (bool), GolpeSeq (sobe a cada golpe corpo a corpo aceito) e o evento Disparo
-- (só chega a quem está perto). Sem IKControl nos outros: a mão de apoio vem só do clipe.

type Remoto = {
	jogador: Player,
	personagem: Model?,
	animator: Animator?,
	armaId: string?,
	classe: string?,
	recargaId: number,
	recarregando: boolean,
	ultimoTiro: number,
	tocadas: { [AnimationTrack]: boolean },
	ligacoes: { RBXScriptConnection },
}
local remotos: { [Player]: Remoto } = {}
local CLIPES_RECARGA = { "Reload", "RecargaInicio", "RecargaCartucho", "RecargaFim" }

local function remotoTocar(r: Remoto, clipe: string, velocidade: number, fade: number): AnimationTrack?
	if not (r.classe and r.animator) then
		return nil
	end
	local t = Animacao.trilha(r.animator, "armas/" .. r.classe, clipe)
	if not t then
		return nil
	end
	r.tocadas[t] = true
	if t.IsPlaying then
		t.TimePosition = 0
		t:AdjustSpeed(velocidade)
	else
		t:Play(fade, 1, velocidade)
	end
	return t
end

local function remotoPararRecarga(r: Remoto, fade: number)
	if not (r.classe and r.animator) then
		return
	end
	for _, nome in CLIPES_RECARGA do
		local t = Animacao.trilha(r.animator, "armas/" .. r.classe, nome)
		if t and t.IsPlaying then
			t:Stop(fade)
		end
	end
end

local function remotoEquipar(r: Remoto, id: string?)
	if id == r.armaId then
		return
	end
	r.recargaId += 1
	r.recarregando = false
	for t in r.tocadas do
		if t.IsPlaying then
			t:Stop(FADE)
		end
	end
	table.clear(r.tocadas)
	local c = if id then (CfgArmas.armas :: any)[id] else nil
	r.armaId = if c then id else nil
	r.classe = if c then c.classe else nil
	if not r.classe then
		return
	end
	remotoTocar(r, "Idle", 1, 0.2)
	remotoTocar(r, "Equip", 1, 0.08)
end

local function remotoRecarga(r: Remoto)
	local id, cl = r.armaId, r.classe
	local cfgArma = if id then (CfgArmas.armas :: any)[id] else nil
	if not (cfgArma and cl and cfgArma.recarga) then
		return
	end
	local ativo = r.jogador:GetAttribute("Recarregando") == true
	local estava = r.recarregando
	r.recarregando = ativo
	r.recargaId += 1
	local meu = r.recargaId
	local rec = cfgArma.recarga
	if not ativo then
		if estava and rec.tipo == "cartucho" then
			remotoPararRecarga(r, 0.05)
			remotoTocar(r, "RecargaFim", duracaoNativa(cl, "RecargaFim") / math.max(rec.fim, 0.05), 0.08)
		else
			remotoPararRecarga(r, 0.15)
		end
		return
	end
	if rec.tipo == "pente" then
		remotoTocar(r, "Reload", duracaoNativa(cl, "Reload") / math.max(rec.tempo, 0.1), 0.15)
		return
	end
	task.spawn(function()
		local function passo(clipe: string, tempo: number): boolean
			remotoTocar(r, clipe, duracaoNativa(cl, clipe) / math.max(tempo, 0.05), 0.08)
			task.wait(tempo)
			return meu == r.recargaId
		end
		if not passo("RecargaInicio", rec.inicio) then
			return
		end
		while passo("RecargaCartucho", rec.porCartucho) do
			-- repete o cartucho enquanto o servidor diz que ainda recarrega (o fim troca recargaId e sai do laço)
			if not r.recarregando then
				return
			end
		end
	end)
end

local function remotoGolpe(r: Remoto)
	local cl = r.classe
	local seq = r.jogador:GetAttribute("GolpeSeq")
	if not cl or type(seq) ~= "number" then
		return
	end
	if cl == "faca" then
		remotoTocar(r, "Golpe" .. (seq % 2 + 1), 1, 0.04)
	else
		remotoTocar(r, "Golpe", 1, 0.05)
	end
end

local function remotoDisparo(atirador: Player, idArma: string)
	local r = remotos[atirador]
	if not (r and r.classe and r.armaId == idArma) then
		return
	end
	local agora = os.clock()
	if agora - r.ultimoTiro < 0.05 then
		return -- escopeta manda um Disparo por chumbinho agrupado
	end
	r.ultimoTiro = agora
	local cfgArma = (CfgArmas.armas :: any)[idArma]
	local dur = duracaoNativa(r.classe, "Fire")
	remotoTocar(r, "Fire", math.max(1, dur / math.max(cfgArma and cfgArma.cadencia or dur, 0.05)), 0.02)
end

local function desligarRemoto(p: Player)
	local r = remotos[p]
	if not r then
		return
	end
	remotos[p] = nil
	for _, l in r.ligacoes do
		l:Disconnect()
	end
	for t in r.tocadas do
		if t.IsPlaying then
			t:Stop(0)
		end
	end
end

local function ligarRemoto(p: Player)
	if p == jogador or remotos[p] then
		return
	end
	local r: Remoto = {
		jogador = p,
		personagem = nil,
		animator = nil,
		armaId = nil,
		classe = nil,
		recargaId = 0,
		recarregando = false,
		ultimoTiro = 0,
		tocadas = {},
		ligacoes = {},
	}
	remotos[p] = r
	local function aoPersonagemRemoto(c: Model?)
		r.personagem = c
		r.animator = nil
		r.armaId = nil
		r.classe = nil
		r.recargaId += 1
		r.recarregando = false
		table.clear(r.tocadas)
		if not c then
			return
		end
		task.spawn(function()
			local h = c:WaitForChild("Humanoid", 10)
			local a = h and h:WaitForChild("Animator", 10)
			if r.personagem == c and a and a:IsA("Animator") then
				r.animator = a
				local id = p:GetAttribute("ArmaEquipada")
				remotoEquipar(r, if type(id) == "string" then id else nil)
				if p:GetAttribute("Recarregando") == true then
					remotoRecarga(r)
				end
			end
		end)
	end
	table.insert(r.ligacoes, p.CharacterAdded:Connect(aoPersonagemRemoto))
	table.insert(
		r.ligacoes,
		p:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
			if r.animator then
				local id = p:GetAttribute("ArmaEquipada")
				remotoEquipar(r, if type(id) == "string" then id else nil)
			end
		end)
	)
	table.insert(
		r.ligacoes,
		p:GetAttributeChangedSignal("Recarregando"):Connect(function()
			if r.animator then
				remotoRecarga(r)
			end
		end)
	)
	table.insert(
		r.ligacoes,
		p:GetAttributeChangedSignal("GolpeSeq"):Connect(function()
			if r.animator then
				remotoGolpe(r)
			end
		end)
	)
	aoPersonagemRemoto(p.Character)
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

	-- os outros jogadores: o corpo deles também ganha os clipes (cada cliente toca no Animator que vê)
	for _, p in Players:GetPlayers() do
		ligarRemoto(p)
	end
	Players.PlayerAdded:Connect(ligarRemoto)
	Players.PlayerRemoving:Connect(desligarRemoto)
	local okDisparo, eventoDisparo = pcall(Rede.evento, "Disparo")
	if okDisparo then
		eventoDisparo.OnClientEvent:Connect(function(atirador: Player, idArma: string)
			remotoDisparo(atirador, idArma)
		end)
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
