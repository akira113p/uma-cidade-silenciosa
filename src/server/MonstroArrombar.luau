--!strict
-- MonstroArrombar: o Rastejador acha uma parede de construção, bate nela e abre um buraco permanente (docs/rastejador.md §5.3).
-- Parede = peça de Mapa.Construcoes (ou ZonaTeste.Construcoes) classificada por TAMANHO em tempo de execução (Regras.paredeArrombavel) e destrutível para a
-- Destruicao; nada no mapa muda. O dano, o escurecer e o buraco são da Destruicao (docs/destruicao.md); aqui fica só a decisão
-- do monstro (qual parede, quando desistir) e o registro dos vãos. Estado por monstro em d.cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Malhas = require(Shared.Config.MonstrosMalhas) :: any
local Regras = require(Shared.Regras.Rastejador)
local Raizes = require(Shared.Raizes)

local MonstroArrombar = {}

-- Preenchido pelo Monstros (animar, servico): evita depender de funções locais dele.
local ctx: any = {}

-- Destruicao é serviço opcional: sem ela o Rastejador não arromba (não há buraco sem o sistema).
local function destruicao(): any
	return ctx.servico and ctx.servico("Destruicao")
end

function MonstroArrombar.configurar(c: any)
	ctx = c
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = true
local construcoesAtual: { Instance } = {}
local classe: { [any]: { [Instance]: boolean } } = setmetatable({}, { __mode = "k" }) :: any -- cache: preset -> peça -> arrombável

local function atualizar(): boolean
	local lista = Raizes.obter("Construcoes") -- Mapa e ZonaTeste; sem cache, a pasta pode surgir ou sumir
	if not Raizes.iguais(lista, construcoesAtual) then
		construcoesAtual = lista
		params.FilterDescendantsInstances = lista
	end
	return #lista > 0
end

local function horizontal(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function arrombavel(Cfg: any, p: Instance): boolean
	local cache = classe[Cfg]
	if not cache then
		cache = setmetatable({}, { __mode = "k" }) :: any
		classe[Cfg] = cache
	end
	local c = cache[p]
	if c ~= nil then
		return c
	end
	local ok = false
	local D = destruicao()
	if D and p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Parede" and D.ehDestrutivel(p) then -- Parede, ParedeLonga, ParedeCurta
		local s = p.Size
		ok = Regras.paredeArrombavel({ s.X, s.Y, s.Z }, false, p:GetAttributes(), Cfg) -- só "Parede" chega aqui: piso/laje/telhado têm outro nome
	end
	cache[p] = ok
	return ok
end

-- Há construção em cima do ponto? (teto/laje): alvo "dentro de construção".
function MonstroArrombar.dentro(ponto: Vector3, erro: number?): boolean
	if not atualizar() then
		return false
	end
	local function teto(p: Vector3): boolean
		return workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), params) ~= nil
	end
	if teto(ponto) then
		return true
	end
	-- o alvo é o som ESTIMADO (erro de até erroPorDistancia x distância): vale "dentro" se algum ponto do disco de erro tem teto
	if erro and erro > 1 then
		for i = 0, 5 do
			local a = i * math.pi / 3
			if teto(ponto + Vector3.new(math.cos(a) * erro, 0, math.sin(a) * erro)) then
				return true
			end
		end
	end
	return false
end

-- Primeira parede arrombável ao longo de um raio (até 5 acertos seguidos, o raio segue de dentro da peça).
local function primeiraParede(Cfg: any, origem: Vector3, dir0: Vector3): (BasePart?, Vector3?, Vector3?)
	local pos = origem
	local fim = origem + dir0
	local dir = dir0
	for _ = 1, 5 do
		local r = workspace:Raycast(pos, dir, params)
		if not r then
			return nil
		end
		if arrombavel(Cfg, r.Instance) then
			return r.Instance :: BasePart, r.Position, r.Normal
		end
		pos = r.Position + dir.Unit * 0.2
		dir = fim - pos
		if dir.Magnitude < 0.5 then
			return nil
		end
	end
	return nil
end

-- Varre raios monstro->alvo (Cfg.arrombar.angulos) e devolve a parede arrombável que abre com menos golpes (Regras.escolherParede).
local function acharParede(
	d: any,
	alvo: Vector3,
	ruins: { [Instance]: number }?,
	agora: number
): (BasePart?, Vector3?, Vector3?)
	if not atualizar() then
		return nil
	end
	local Cfg = d.preset
	local D = destruicao()
	local origem: Vector3 = d.hrp.Position
	local base = alvo - origem
	if not D or base.Magnitude < 0.5 then
		return nil
	end
	base = base.Unit * math.min(base.Magnitude, Cfg.arrombar.alcanceRaio)
	local pecas: { { peca: BasePart, ponto: Vector3, normal: Vector3 } } = {}
	local cands: { { golpes: number, distancia: number } } = {}
	local vistas: { [Instance]: boolean } = {}
	for _, graus in Cfg.arrombar.angulos do
		local a = math.rad(graus)
		local dir = CFrame.Angles(0, a, 0):VectorToWorldSpace(base)
		local peca, ponto, normal = primeiraParede(Cfg, origem, dir)
		if peca and ponto and normal and not vistas[peca] and not (ruins and (ruins[peca] or 0) > agora) then
			vistas[peca] = true
			table.insert(pecas, { peca = peca, ponto = ponto, normal = normal })
			table.insert(cands, {
				golpes = D.golpesPara(peca, Cfg.arrombar.dano, Cfg.arrombar.tipoDano),
				distancia = horizontal(ponto - origem),
			})
		end
	end
	local k = Regras.escolherParede(cands, Cfg)
	if not k then
		return nil
	end
	local c = pecas[k]
	return c.peca, c.ponto, c.normal
end

-- Candidato "parede" para o objetivo: em andamento, ou nova (caminho sem entrada curta / travado 3x) em direção a `alvo`.
function MonstroArrombar.candidato(d: any, alvo: Vector3, agora: number, erro: number?): any?
	if d.especie.capacidades.arrombar ~= true then
		return nil -- Corcunda, MonstroPS1 e Florescida (fachada própria) não arrombam
	end
	local Cfg = d.preset
	local cap = d.cap
	local p = cap.parede
	if p then
		local sumiu = p.peca ~= nil and not p.peca.Parent -- outro monstro já quebrou esta peça
		if sumiu or agora - p.desde > Cfg.arrombar.desistir then
			cap.parede = nil
			cap.proxBusca = agora + Cfg.arrombar.reprocurar
			if p.peca and p.peca.Parent then
				cap.paredesRuins = cap.paredesRuins or {}
				cap.paredesRuins[p.peca] = agora + 30 -- não insiste na mesma peça por um tempo
			end
			return nil
		end
		return { tipo = "parede", distancia = horizontal(p.ponto - d.hrp.Position) }
	end
	local D = destruicao()
	if not D or agora < (cap.proxBusca or 0) then
		return nil
	end
	local precisa = cap.forcarParede == true
	if not precisa then
		local cam = cap.caminho
		if cam then
			local reta = horizontal(alvo - d.hrp.Position)
			precisa = Regras.precisaArrombar(cam.estado, cam.comprimento, reta, MonstroArrombar.dentro(alvo, erro), Cfg)
		end
	end
	if not precisa then
		return nil
	end
	cap.forcarParede = false
	cap.proxBusca = agora + Cfg.arrombar.reprocurar
	-- buraco que já existe e leva ao alvo: usa em vez de bater de novo
	local buraco = D.vaoUtil(d.hrp.Position, alvo, 60)
	if buraco then
		cap.parede = { buraco = buraco, ponto = buraco.pos, desde = agora }
		return { tipo = "parede", distancia = horizontal(buraco.pos - d.hrp.Position) }
	end
	-- varre vários raios e fica com a parede de menos golpes (<= golpesMax); sem nenhuma, tenta de novo em `reprocurar` s
	local peca, ponto, normal = acharParede(d, alvo, cap.paredesRuins, agora)
	if not (peca and ponto and normal) then
		return nil
	end
	cap.parede = { peca = peca, ponto = ponto, normal = normal, desde = agora, proximoGolpe = 0 }
	return { tipo = "parede", distancia = horizontal(ponto - d.hrp.Position) }
end

local avisos = 0

-- Impacto do golpe (atrasoImpacto depois do início do clipe): dá o dano à Destruicao, que escurece a parede e, a 0 de vida, abre o vão.
local function impacto(d: any, p: any)
	local Cfg = d.preset
	local peca: BasePart = p.peca
	if not (d.vivo and peca.Parent) then
		return
	end
	if horizontal(p.ponto - d.hrp.Position) > Cfg.arrombar.distanciaGolpe + Cfg.arrombar.raioFolga + 1.5 then
		return -- foi afastado antes do impacto
	end
	local D = destruicao()
	if not D then
		return
	end
	local res = D.dano(peca, Cfg.arrombar.dano, {
		tipo = Cfg.arrombar.tipoDano,
		ponto = p.ponto,
		normal = p.normal,
		fonte = d.modelo,
		largura = d.hrp.Size.X * Cfg.arrombar.folgaLargura,
		altura = Cfg.arrombar.alturaBuraco,
		ruido = "paredeQuebrando",
	})
	if res and res.quebrou then
		-- caminho novo: o navmesh lê a geometria no ComputeAsync; espera um pouco antes de recalcular
		d.alvoCaminho = nil
		d.waypoints = nil
		d.ultimoCalculo = os.clock() + Cfg.arrombar.esperaNavmesh
		d.cap.parede = nil
		d.cap.proxBusca = os.clock() + Cfg.arrombar.esperaNavmesh
	end
end

local function bater(d: any, p: any, agora: number)
	local Cfg = d.preset
	-- (o desistir é de MonstroArrombar.candidato)
	-- preset com `arrombar.recuperacao` (cabeçada do Wrapper): próxima batida só depois do impacto + recuperação, parado e vulnerável
	local espera = if Cfg.arrombar.recuperacao
		then (Cfg.arrombar.atrasoImpacto or Cfg.golpe.atrasoImpacto) + Cfg.arrombar.recuperacao
		else Cfg.arrombar.intervalo
	p.proximoGolpe = agora + espera
	local clipe = Cfg.arrombar.clipe
	local malha = Malhas[d.especie.id]
	local duracaoClipe = malha and (malha.duracao[clipe] or malha.duracao.Attack)
	if ctx.tocarAcao then
		ctx.tocarAcao(d, clipe, agora, Cfg.arrombar.intervalo, math.max(duracaoClipe or 1, Cfg.arrombar.intervalo))
	end
	local padraoImpacto = Cfg.arrombar.atrasoImpacto or Cfg.golpe.atrasoImpacto
	local atraso = if ctx.evento then ctx.evento(d, clipe, "impacto", padraoImpacto) else padraoImpacto
	task.delay(atraso, function()
		local ok, erro = pcall(impacto, d, p)
		if not ok and avisos < 5 then
			avisos += 1
			warn("[MonstroArrombar] erro no impacto: " .. tostring(erro))
		end
	end)
end

-- Um passo com objetivo "parede": devolve o ponto para onde andar (encostar na parede) e bate quando perto.
function MonstroArrombar.passo(d: any, agora: number): (Vector3?, boolean?)
	local Cfg = d.preset
	local p = d.cap.parede
	if not p then
		return nil
	end
	if p.buraco then
		-- vai até o lado de fora do buraco e atravessa em linha reta; já do lado de dentro, termina
		local pos: Vector3 = d.hrp.Position
		local b = p.buraco
		local lado = (pos - b.pos):Dot(b.normal)
		if lado < -1.5 then
			d.cap.parede = nil
			d.cap.proxBusca = agora + Cfg.arrombar.reprocurar
			return nil
		end
		local fora = b.pos + b.normal * 2.5
		if lado > 0.5 and horizontal(fora - pos) > 1 then
			return fora, true -- alinha com o vão (MoveTo direto: seguirAlvo pararia a 3 studs)
		end
		return b.pos - b.normal * 4, true
	end
	if
		horizontal(p.ponto - d.hrp.Position) <= Cfg.arrombar.distanciaGolpe + Cfg.arrombar.raioFolga
		and agora >= p.proximoGolpe
	then
		bater(d, p, agora)
	end
	return Vector3.new(p.ponto.X, d.hrp.Position.Y, p.ponto.Z), false -- empurra contra a parede (olha para ela)
end

function MonstroArrombar.furos(): number
	local D = destruicao()
	return D and D.furos() or 0
end

return MonstroArrombar
