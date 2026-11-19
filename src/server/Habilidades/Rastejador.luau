-- Habilidades do Rastejador (docs/monstros/logica.md §3): Pulso no chão (audição pelo chão, docs/som.md §6.4) e Busca dentro da casa. O arrombar mais forte são só números
-- (PresetsMonstro.quadrupedeArrombador.arrombar). Números em PresetsMonstro.<preset>.habilidades.{pulso,busca}.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared.Regras.Habilidades)

local M = {}

local ctx: any = {}
local U: any = {}
local random = Random.new()

function M.configurar(c: any, util: any)
	ctx, U = c, util
	-- Vão aberto por um Rastejador: guarda onde, para a Busca começar do lado de dentro quando ele passar.
	local D = ctx.servico("Destruicao")
	if D and D.aoQuebrar then
		D.aoQuebrar(function(ev: any)
			local fonte = ev.fonte
			if typeof(fonte) ~= "Instance" then
				return
			end
			local d = ctx.porModelo(fonte)
			if d and d.especie.id == "Rastejador" and d.hab then
				d.hab.vaoAberto = { pos = ev.centro, quando = os.clock() }
			end
		end)
	end
end

function M.iniciar(d: any)
	d.hab = {
		pulsoUltimo = -math.huge,
		pulso = nil, -- { de, ate, parado }
		busca = nil,
		saida = nil, -- { alvo, ate }
		vaoAberto = nil,
		proxCheck = 0,
		ultimaBusca = nil, -- { modelo, ate }
		proximoGolpePorta = 0,
	}
end

local function pe(d: any): number
	return d.hrp.Position.Y - d.hrp.Size.Y / 2 - d.humanoid.HipHeight
end

-- Pulso -----------------------------------------------------------------------------------------------------------------

local function iniciarPulso(d: any, agora: number)
	local h, c = d.hab, d.preset.habilidades.pulso
	h.pulsoUltimo = agora
	local dur = ctx.tocarAcao(d, "Pulso", agora, c.duracao)
	local de = agora + ctx.evento(d, "Pulso", "encostou", c.encostou)
	h.pulso = { de = de, ate = de + c.janela, parado = agora + dur }
	local sons = ctx.servico("Sons")
	if sons then
		sons.tocar("PulsoChao", d.hrp, { db = c.db })
	end
	local ruido = ctx.servico("Ruido")
	if ruido then
		ruido.emitir(d.hrp.Position, c.db, "pulsoChao", d.modelo)
	end
end

-- Busca -----------------------------------------------------------------------------------------------------------------

local function iniciarBusca(d: any, modelo: Model, entrada: Vector3, agora: number)
	local h, c = d.hab, d.preset.habilidades.busca
	local cf, tam = modelo:GetBoundingBox()
	local caixa = { cx = cf.Position.X, cz = cf.Position.Z, sx = tam.X, sz = tam.Z }
	local cands = Regras.candidatosBusca(caixa, c.grade, { x = entrada.X, z = entrada.Z }, function()
		return random:NextNumber()
	end)
	local params = U.paramsSolido()
	local chao = pe(d)
	local pontos: { Vector3 } = {}
	for _, p in cands do
		if #pontos >= c.pontosMax then
			break
		end
		local r = workspace:Raycast(
			Vector3.new(p.x, chao + c.alturaAndar, p.z),
			Vector3.new(0, -c.alturaAndar * 2, 0),
			params
		)
		if
			r and not workspace:Raycast(r.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, c.livreAcima, 0), params)
		then
			table.insert(pontos, r.Position + Vector3.new(0, 0.5, 0))
		end
	end
	h.ultimaBusca = { modelo = modelo, ate = agora + c.duracaoMax + 30 }
	if #pontos == 0 then
		return
	end
	h.busca = { pontos = pontos, i = 1, entrada = entrada, inicio = agora, chegouEm = nil }
end

local function terminarBusca(d: any, agora: number)
	local h, c = d.hab, d.preset.habilidades.busca
	local b = h.busca
	h.busca = nil
	ctx.acalmar(d, agora)
	h.saida = { alvo = b.entrada, ate = agora + c.saida }
end

-- Porta fechada na frente (peça "Folha" de Construcoes): arromba. true = bateu (parado neste tick).
local function golpearPorta(d: any, agora: number, destino: Vector3): boolean
	local h, a = d.hab, d.preset.arrombar
	local D = ctx.servico("Destruicao")
	if not D or agora < h.proximoGolpePorta then
		return false
	end
	local pos = d.hrp.Position
	local dir = destino - pos
	if dir.Magnitude < 0.5 then
		return false
	end
	local r = workspace:Raycast(pos, dir.Unit * (a.distanciaGolpe + a.raioFolga), U.paramsSolido())
	if not (r and r.Instance.Name == "Folha" and D.ehDestrutivel(r.Instance)) then
		return false
	end
	h.proximoGolpePorta = agora + a.intervalo
	ctx.tocarAcao(d, a.clipe, agora, a.intervalo)
	local folha, ponto, normal = r.Instance, r.Position, r.Normal
	task.delay(ctx.evento(d, a.clipe, "impacto", a.atrasoImpacto), function()
		if d.vivo and folha.Parent then
			D.dano(
				folha,
				a.dano,
				{ tipo = a.tipoDano, ponto = ponto, normal = normal, fonte = d.modelo, ruido = "paredeQuebrando" }
			)
		end
	end)
	return true
end

-- Passo ---------------------------------------------------------------------------------------------------------------------

function M.passo(d: any, agora: number, c: any): boolean
	local h, cf = d.hab, d.preset.habilidades
	if not h then
		return false
	end

	-- efeito do pulso (docs/som.md §6.4): durante a janela, depois do evento `encostou`, o chão fica mais sensível (audição, não varredura):
	-- quem anda por perto vira ruído ouvido pelo chão em Monstros.processarRuido. Agachado/deitado não conta (ignorarAgachado).
	if h.pulso then
		if agora >= h.pulso.ate then
			h.pulso = nil
			d.audicaoExtra = nil
		elseif agora >= h.pulso.de and not d.audicaoExtra then
			d.audicaoExtra = { chao = cf.pulso.bonusChao, ignorarAgachado = cf.pulso.ignorarAgachado }
		end
	end
	if h.pulso and agora < h.pulso.parado then
		d.semGolpeNormal = true
		ctx.parar(d) -- o corpo desce até o chão: parado durante o clipe
		return true
	end

	-- saindo da casa depois de uma busca sem achar ninguém
	if h.saida then
		local s = h.saida
		if d.perc.estado ~= "Calmo" or agora > s.ate or ctx.horizontal(s.alvo - d.hrp.Position) <= 4 then
			h.saida = nil
		else
			ctx.seguirAlvo(d, s.alvo, agora)
			return true
		end
	end

	-- busca em andamento
	local b = h.busca
	if b then
		if
			d.perc.ultimoSom > b.inicio
			or d.perc.estado == "Caca"
			or agora - b.inicio > cf.busca.duracaoMax
			or b.i > #b.pontos
		then
			if d.perc.ultimoSom > b.inicio or d.perc.estado == "Caca" then
				h.busca = nil -- percebeu alguém: vira caça normal
			else
				terminarBusca(d, agora)
			end
			return false
		end
		-- a Percepção segue em Investiga enquanto a busca durar
		d.perc = {
			estado = "Investiga",
			alvo = d.perc.alvo,
			ultimoSom = d.perc.ultimoSom,
			sons = d.perc.sons,
			desde = agora,
		}
		local p = b.pontos[b.i]
		local pos = d.hrp.Position
		if not b.chegouEm and ctx.horizontal(p - pos) > cf.busca.chegou then
			if golpearPorta(d, agora, p) then
				ctx.parar(d)
			else
				ctx.seguirAlvo(d, p, agora)
			end
			return true
		end
		if not b.chegouEm then
			b.chegouEm = agora
			if Regras.pronto(h.pulsoUltimo, agora, cf.pulso.recarga) then
				iniciarPulso(d, agora)
			end
		end
		ctx.parar(d)
		if agora - b.chegouEm >= cf.busca.olharCada then
			b.i += 1
			b.chegouEm = nil
		end
		return true
	end

	local ativo = c.distPerto <= d.preset.objetivo.distanciaAtiva

	-- começa a busca: em Investiga/Caça, sem percepção nova há `entrarSemPercepcao` s, dentro de uma construção
	if ativo and d.perc.estado ~= "Calmo" and agora >= h.proxCheck then
		h.proxCheck = agora + cf.busca.checarCada
		if agora - d.perc.ultimoSom >= cf.busca.entrarSemPercepcao then
			local pos = d.hrp.Position
			local modelo = U.construcaoEm(pos, cf.busca.raioConstrucao)
			local ub = h.ultimaBusca
			if modelo and U.dentroDe(modelo, pos) and not (ub and ub.modelo == modelo and agora < ub.ate) then
				local vao = h.vaoAberto
				local entrada = if vao and agora - vao.quando <= cf.busca.vaoValeAte then vao.pos else pos
				iniciarBusca(d, modelo, entrada, agora)
				if h.busca then
					return true
				end
			end
		end
	end

	-- Pulso ao chegar no ponto estimado sem achar ninguém
	local alvo = d.perc.alvo
	if
		ativo
		and d.perc.estado == "Investiga"
		and alvo
		and c.distPerto > ctx.Config.estados.distanciaAtaque
		and ctx.horizontal(Vector3.new(alvo.x, alvo.y, alvo.z) - d.hrp.Position) <= cf.pulso.chegou
		and Regras.pronto(h.pulsoUltimo, agora, cf.pulso.recarga)
	then
		iniciarPulso(d, agora)
		d.semGolpeNormal = true
		ctx.parar(d)
		return true
	end
	return false
end

return M
