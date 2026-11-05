--!strict
-- MonstroArrombar: o Rastejador acha uma parede de construção, bate nela e abre um buraco permanente (docs/rastejador.md §5.3).
-- Parede = peça de Mapa.Construcoes classificada por TAMANHO em tempo de execução (Regras.paredeArrombavel) e destrutível para a
-- Destruicao; nada no mapa muda. O dano, o escurecer e o buraco são da Destruicao (docs/destruicao.md); aqui fica só a decisão
-- do monstro (qual parede, quando desistir) e o registro dos vãos. Estado por monstro em d.cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Rastejador) :: any
local Malhas = require(Shared.Config.MonstrosMalhas) :: any
local Regras = require(Shared.Regras.Rastejador)

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
local construcoesAtual: Instance? = nil
local classe: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- cache: peça -> arrombável

local function atualizar(): boolean
	local mapa = workspace:FindFirstChild("Mapa")
	local c = mapa and mapa:FindFirstChild("Construcoes")
	if c ~= construcoesAtual then
		construcoesAtual = c
		params.FilterDescendantsInstances = if c then { c } else {}
	end
	return c ~= nil
end

local function horizontal(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function arrombavel(p: Instance): boolean
	local c = classe[p]
	if c ~= nil then
		return c
	end
	local ok = false
	local D = destruicao()
	if D and p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Parede" and D.ehDestrutivel(p) then -- Parede, ParedeLonga, ParedeCurta
		local s = p.Size
		ok = Regras.paredeArrombavel({ s.X, s.Y, s.Z }, false, p:GetAttributes(), Cfg) -- só "Parede" chega aqui: piso/laje/telhado têm outro nome
	end
	classe[p] = ok
	return ok
end

-- Há construção em cima do ponto? (teto/laje): alvo "dentro de construção".
function MonstroArrombar.dentro(ponto: Vector3): boolean
	if not atualizar() then
		return false
	end
	return workspace:Raycast(ponto + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), params) ~= nil
end

-- Primeira parede arrombável no caminho reto do monstro até `alvo` (até 3 acertos seguidos, o raio segue de dentro da peça).
local function acharParede(d: any, alvo: Vector3): (BasePart?, Vector3?, Vector3?)
	if not atualizar() then
		return nil
	end
	local origem: Vector3 = d.hrp.Position
	local dir = alvo - origem
	if dir.Magnitude < 0.5 then
		return nil
	end
	dir = dir.Unit * math.min((alvo - origem).Magnitude, Cfg.arrombar.alcanceRaio)
	local pos = origem
	for _ = 1, 3 do
		local r = workspace:Raycast(pos, dir, params)
		if not r then
			return nil
		end
		if arrombavel(r.Instance) then
			return r.Instance :: BasePart, r.Position, r.Normal
		end
		pos = r.Position + dir.Unit * 0.2
		dir = (origem + dir - pos)
		if dir.Magnitude < 0.5 then
			return nil
		end
	end
	return nil
end

-- Candidato "parede" para o objetivo: em andamento, ou nova (caminho sem entrada curta / travado 3x) em direção a `alvo`.
function MonstroArrombar.candidato(d: any, alvo: Vector3, agora: number): any?
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
			precisa = Regras.precisaArrombar(cam.estado, cam.comprimento, reta, MonstroArrombar.dentro(alvo), Cfg)
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
	local peca, ponto, normal = acharParede(d, alvo)
	if not (peca and ponto and normal) then
		return nil
	end
	local ruins = cap.paredesRuins
	if ruins and (ruins[peca] or 0) > agora then
		return nil
	end
	-- material duro demais para a garra (concreto, metal): não perde tempo; tenta outra parede mais tarde
	if D.golpesPara(peca, Cfg.arrombar.dano, "garra") > Cfg.arrombar.golpesMax then
		cap.paredesRuins = ruins or {}
		cap.paredesRuins[peca] = agora + 30
		return nil
	end
	cap.parede = { peca = peca, ponto = ponto, normal = normal, desde = agora, proximoGolpe = 0 }
	return { tipo = "parede", distancia = horizontal(ponto - d.hrp.Position) }
end

local avisos = 0

-- Impacto do golpe (atrasoImpacto depois do início do clipe): dá o dano à Destruicao, que escurece a parede e, a 0 de vida, abre o vão.
local function impacto(d: any, p: any)
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
		tipo = "garra",
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
	p.proximoGolpe = agora + Cfg.arrombar.intervalo
	d.golpeAte = agora
		+ math.max(Malhas[d.especie.id] and Malhas[d.especie.id].duracao.Attack or 1, Cfg.arrombar.intervalo)
	if ctx.animar then
		ctx.animar(d, agora, true)
	end
	task.delay(Cfg.golpe.atrasoImpacto, function()
		local ok, erro = pcall(impacto, d, p)
		if not ok and avisos < 5 then
			avisos += 1
			warn("[MonstroArrombar] erro no impacto: " .. tostring(erro))
		end
	end)
end

-- Um passo com objetivo "parede": devolve o ponto para onde andar (encostar na parede) e bate quando perto.
function MonstroArrombar.passo(d: any, agora: number): (Vector3?, boolean?)
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
