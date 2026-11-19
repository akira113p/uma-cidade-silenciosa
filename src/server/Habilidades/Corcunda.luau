-- Habilidades do Corcunda (docs/monstros/logica.md §5): visão curta, empurrão que derruba, abrir/fechar porta, emboscada e imitação.
-- Números em PresetsMonstro.corcunda.habilidades.{visao,empurrao,portas,emboscada}. Sem o serviço Portas ele trata porta como parede
-- (a habilidade de porta simplesmente não acontece); sem Movimento.derrubar o empurrão só dá o dano.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared.Regras.Habilidades)

local M = {}

local ctx: any = {}
local U: any = {}
local random = Random.new()

function M.configurar(c: any, util: any)
	ctx, U = c, util
end

function M.iniciar(d: any)
	d.hab = {
		visaoProx = 0,
		empurrou = false, -- já empurrou neste encontro
		emboscadaGolpe = false, -- o próximo empurrão veio de emboscada: o golpe seguinte é dobrado
		emboscada = nil, -- { fase, pos, fim, proxImit, retomar }
		emboscadaProx = 0,
		memoria = {},
		abertas = {}, -- { { porta, quando } } portas que ele abriu
		portaCheck = 0,
		portaAte = 0,
	}
end

local function vec(v: Vector3): any
	return { x = v.X, y = v.Y, z = v.Z }
end

local function olho(d: any): Vector3
	return d.hrp.Position + Vector3.new(0, d.hrp.Size.Y * 0.3, 0)
end

local function rnd(): number
	return random:NextNumber()
end

-- Visão (§5.1) ----------------------------------------------------------------------------------------------------------

local function ver(d: any, agora: number, c: any)
	local h, v = d.hab, d.preset.habilidades.visao
	if agora < h.visaoProx then
		return
	end
	h.visaoProx = agora + v.cada
	local noite = Regras.ehNoite(Lighting.ClockTime, v.diaInicio, v.diaFim)
	local o = olho(d)
	local frente = d.hrp.CFrame.LookVector
	for _, j in c.jogadores do
		if (j.pos - d.hrp.Position).Magnitude <= v.raioMax then
			local char = j.jogador.Character
			local cabeca = U.parteDoJogador(j.jogador, "Head")
			local alvo = if cabeca then cabeca.Position else j.pos
			local estado = {
				agachado = U.agachado(j.jogador),
				deitado = U.deitado(j.jogador),
				noite = noite,
				lanterna = char ~= nil and char:GetAttribute("LanternaLigada") == true,
			}
			-- cone e alcance primeiro (barato); o raycast só se passou
			if Regras.veJogador(v, vec(o), vec(frente), vec(alvo), estado, true) and U.linhaLivre(o, alvo) then
				ctx.ouvirSom(d, ctx.Config.estados.investigaAte, j.pos, agora)
			end
		end
	end
end

-- Empurrão (§5.2) -------------------------------------------------------------------------------------------------------

-- Primeiro golpe de cada encontro: derruba com impulso. Os seguintes são o Attack normal (o Monstros faz).
function M.aoGolpear(d: any, jogador: Player, agora: number): boolean
	local h, e = d.hab, d.preset.habilidades.empurrao
	if h.empurrou then
		return false
	end
	h.empurrou = true
	ctx.tocarAcao(d, "Empurrao", agora, e.duracao)
	task.delay(ctx.evento(d, "Empurrao", "impacto", e.impacto), function()
		if not d.vivo or not ctx.estaVivo(jogador) then
			return
		end
		local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
		if not hrp then
			return
		end
		local origem = d.hrp.Position
		if not Regras.noCone(vec(origem), vec(d.hrp.CFrame.LookVector), vec(hrp.Position), e.cone, e.acerto) then
			return -- saiu da frente ou do alcance: errou
		end
		local delta = Vector3.new(hrp.Position.X - origem.X, 0, hrp.Position.Z - origem.Z)
		local dir = if delta.Magnitude > 0.1 then delta.Unit else d.hrp.CFrame.LookVector
		local mov = ctx.servico("Movimento")
		if mov and mov.derrubar then
			mov.derrubar(jogador, e.derrubado, dir * e.forca + Vector3.new(0, e.subida, 0))
		end
		U.danoJogador(jogador, nil, e.dano, dir)
		local sons = ctx.servico("Sons")
		if sons then
			sons.tocar("Empurrao", d.hrp)
		end
		local ruido = ctx.servico("Ruido")
		if ruido then
			ruido.emitir(d.hrp.Position, e.db, "empurrao", d.modelo)
		end
		if h.emboscadaGolpe then
			h.emboscadaGolpe = false
			d.danoMult = e.danoDobrado
		end
	end)
	local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
	if hrp then
		ctx.ouvirSom(d, ctx.Config.estados.investigaAte, hrp.Position, agora)
	end
	return true
end

-- Portas (§5.3) ---------------------------------------------------------------------------------------------------------

-- Porta fechada na linha até o próximo ponto: para e abre (com barulho). true = parado abrindo.
local function portaAdiante(d: any, agora: number): boolean
	local h, pc = d.hab, d.preset.habilidades.portas
	local P = ctx.servico("Portas")
	if not P or agora < h.portaCheck then
		return false
	end
	h.portaCheck = agora + pc.cada
	if d.humanoid.MoveDirection.Magnitude < 0.1 then
		return false
	end
	local pos = d.hrp.Position
	local porta = P.naLinha(pos, d.humanoid.WalkToPoint, pc.raioLinha)
	if not porta or ctx.horizontal(P.posicao(porta) - pos) > pc.abrirDist then
		return false
	end
	local dur = ctx.tocarAcao(d, "AbrirPorta", agora, pc.duracao)
	h.portaAte = agora + dur
	task.delay(ctx.evento(d, "AbrirPorta", "porta", pc.porta), function()
		if d.vivo and not P.estaAberta(porta) then
			P.abrir(porta, d.modelo)
			table.insert(h.abertas, { porta = porta, quando = os.clock() })
		end
	end)
	ctx.parar(d)
	return true
end

-- Fecha as portas que ele abriu depois de passar (>= passouDist e atrás dele), salvo em Caça.
local function fecharPortas(d: any, agora: number)
	local h, pc = d.hab, d.preset.habilidades.portas
	local P = ctx.servico("Portas")
	if not P or #h.abertas == 0 then
		return
	end
	local pos = d.hrp.Position
	local look = d.hrp.CFrame.LookVector
	for i = #h.abertas, 1, -1 do
		local e = h.abertas[i]
		if agora - e.quando > pc.validade or not P.estaAberta(e.porta) then
			table.remove(h.abertas, i)
		elseif d.perc.estado ~= "Caca" then
			local delta = P.posicao(e.porta) - pos
			if ctx.horizontal(delta) >= pc.passouDist and delta:Dot(look) < 0 then
				P.fechar(e.porta, d.modelo, false) -- nunca bate a porta
				table.remove(h.abertas, i)
			end
		end
	end
end

-- Emboscada e imitação (§5.4) --------------------------------------------------------------------------------------------

local function paramsPiso(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.IgnoreWater = true
	local lista: { Instance } = {}
	for _, nome in { "Monstros", "ItensChao", "SonsSoltos", "Flores" } do
		local f = workspace:FindFirstChild(nome)
		if f then
			table.insert(lista, f)
		end
	end
	for _, j in game:GetService("Players"):GetPlayers() do
		if j.Character then
			table.insert(lista, j.Character)
		end
	end
	p.FilterDescendantsInstances = lista
	return p
end

-- Ponto a <= raioEsconderijo com piso, de onde o ponto do som não é visível, de preferência dentro de construção.
local function acharEsconderijo(d: any, ponto: Vector3): Vector3?
	local e = d.preset.habilidades.emboscada
	local origem = d.hrp.Position
	local pp = paramsPiso()
	local cands, pontos = {}, {}
	local alto = Vector3.new(0, e.alturaOlho, 0)
	for _, anel in e.aneis do
		for k = 0, e.angulos - 1 do
			local a = k * 2 * math.pi / e.angulos
			local x = origem.X + math.cos(a) * anel * e.raioEsconderijo
			local z = origem.Z + math.sin(a) * anel * e.raioEsconderijo
			local r = workspace:Raycast(Vector3.new(x, origem.Y + 6, z), Vector3.new(0, -20, 0), pp)
			if r then
				local p = r.Position
				table.insert(pontos, p)
				table.insert(cands, {
					oculto = not U.linhaLivre(p + alto, ponto + alto),
					dentro = workspace:Raycast(p + Vector3.new(0, 0.5, 0), Vector3.new(0, 60, 0), U.paramsSolido())
						~= nil,
					dist = ctx.horizontal(p - origem),
				})
			end
		end
	end
	local i = Regras.escolherEsconderijo(cands)
	return if i then pontos[i] + Vector3.new(0, 0.5, 0) else nil
end

local function imitar(d: any, agora: number)
	local h, e = d.hab, d.preset.habilidades.emboscada
	local sons = ctx.servico("Sons")
	local ruido = ctx.servico("Ruido")
	local mem = Regras.memoriaEscolher(h.memoria, agora, e, rnd)
	local nome = if mem then Regras.somDoTipo(mem.tipo, e.sons) else nil
	local fala = rnd() < e.chanceFala or nome == nil
	local db = if fala then e.falaDb else mem.db
	local pitch = if fala then 1 else e.pitchDefeito
	if fala then
		nome = "VozCorcunda_" .. random:NextInteger(1, e.numeroFalas)
	end
	local dur = ctx.tocarAcao(d, "Imitar", agora, e.imitarDuracao)
	h.emboscada.retomar = agora + dur
	if sons and nome then
		local som = sons.tocar(nome, d.hrp, { db = db })
		if som and pitch ~= 1 then
			som.PlaybackSpeed *= pitch -- o defeito audível
		end
	end
	if ruido then
		ruido.emitir(d.hrp.Position, db, "imitacao", d.modelo) -- monstros ignoram "imitacao"; jogador ouve como outro som
	end
end

local function encerrarEmboscada(d: any, agora: number)
	local h = d.hab
	h.emboscada = nil
	d.golpeAte = agora
	d.clipe = nil
end

-- Mantém a Percepção em Investiga enquanto a emboscada durar (senão o timeout de 12 s a derruba para Calmo).
local function segurarInvestiga(d: any, agora: number)
	d.perc =
		{ estado = "Investiga", alvo = d.perc.alvo, ultimoSom = d.perc.ultimoSom, sons = d.perc.sons, desde = agora }
end

local function emboscada(d: any, agora: number, c: any): boolean
	local h, e = d.hab, d.preset.habilidades.emboscada
	local em = h.emboscada
	local pos = d.hrp.Position
	if not em then
		local alvo = d.perc.alvo
		if
			d.perc.estado == "Investiga"
			and alvo
			and agora >= h.emboscadaProx
			and c.distPerto > ctx.Config.estados.distanciaAtaque
			and ctx.horizontal(Vector3.new(alvo.x, alvo.y, alvo.z) - pos) <= e.chegouAlvo
		then
			local ponto = Vector3.new(alvo.x, alvo.y, alvo.z)
			local esc = acharEsconderijo(d, ponto)
			if not esc then
				h.emboscadaProx = agora + 10
				return false
			end
			h.emboscada = { fase = "indo", pos = esc, ponto = ponto, fim = 0, proxImit = 0, retomar = nil }
			return true
		end
		return false
	end

	if d.perc.estado == "Caca" then
		encerrarEmboscada(d, agora) -- percebeu alguém de longe: caça normal
		return false
	end
	segurarInvestiga(d, agora)

	if em.fase == "indo" then
		if ctx.horizontal(em.pos - pos) <= e.chegou then
			em.fase = "esperando"
			em.fim = agora + e.duracao
			em.proxImit = agora + e.imitarMin + rnd() * (e.imitarMax - e.imitarMin)
			ctx.tocarAcao(d, "Emboscada", agora, e.duracao, e.duracao)
			ctx.parar(d)
		else
			ctx.seguirAlvo(d, em.pos, agora)
		end
		return true
	end

	-- esperando: jogador a <= gatilho (visto ou ouvido) dispara o empurrão imediato, com o golpe seguinte dobrado
	local o = olho(d)
	for _, j in c.jogadores do
		if (j.pos - pos).Magnitude <= e.gatilho then
			local cabeca = U.parteDoJogador(j.jogador, "Head")
			local visto = U.linhaLivre(o, if cabeca then cabeca.Position else j.pos)
			if visto or agora - d.perc.ultimoSom < 2 then
				h.emboscadaGolpe = true
				h.empurrou = false
				encerrarEmboscada(d, agora)
				ctx.ouvirSom(d, ctx.Config.estados.investigaAte, j.pos, agora)
				return false
			end
		end
	end
	if agora >= em.fim then
		encerrarEmboscada(d, agora)
		h.emboscadaProx = agora + e.duracao
		ctx.acalmar(d, agora) -- 30 s sem ninguém: Calmo
		return false
	end
	if em.retomar and agora >= em.retomar then
		em.retomar = nil
		ctx.tocarAcao(d, "Emboscada", agora, e.duracao, em.fim - agora)
	end
	if agora >= em.proxImit and not em.retomar then
		em.proxImit = agora + e.imitarMin + rnd() * (e.imitarMax - e.imitarMin)
		imitar(d, agora)
	end
	d.semGolpeNormal = true
	ctx.parar(d)
	return true
end

-- Ouvir: memória dos sons de jogador imitáveis ---------------------------------------------------------------------------

function M.aoOuvir(d: any, ev: any)
	local e = d.preset.habilidades.emboscada
	if ev.jogador and ev.tipo and e.sons[ev.tipo] then
		d.hab.memoria =
			Regras.memoriaRegistrar(d.hab.memoria, { tipo = ev.tipo, db = ev.db, quando = ev.agora }, ev.agora, e)
	end
end

-- Passo -------------------------------------------------------------------------------------------------------------------

function M.passo(d: any, agora: number, c: any): boolean
	local h, cf = d.hab, d.preset.habilidades
	if not h then
		return false
	end
	-- intervalo de golpe mais curto enquanto o jogador está no chão
	d.intervaloGolpe = if c.maisPerto and U.derrubado(c.maisPerto.jogador) then cf.empurrao.intervaloNoChao else nil
	-- o encontro acaba depois de `encontroAte` s sem percepção
	if h.empurrou and agora - d.perc.ultimoSom > cf.empurrao.encontroAte then
		h.empurrou = false
		h.emboscadaGolpe = false
	end
	ver(d, agora, c)
	if agora < h.portaAte then
		d.semGolpeNormal = true
		ctx.parar(d)
		return true
	end
	fecharPortas(d, agora)
	if portaAdiante(d, agora) then
		return true
	end
	return emboscada(d, agora, c)
end

return M
