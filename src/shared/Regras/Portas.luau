--!strict
-- Regras puras das portas (docs/monstros/logica.md §2.1): ruído por modo, dobradiça a partir da folha entreaberta,
-- posição fechada e interseção do caminho com a porta. Sem Instance; pontos são { x, z } no plano horizontal.

export type P2 = { x: number, z: number }

local Portas = {}

-- Modo: "abrir" | "fechar" | "bater". Abrir agachado/silencioso usa a linha própria. Devolve (db, tipo).
function Portas.ruido(modo: string, silencioso: boolean, cfg: any): (number, string)
	local chave = modo
	if modo == "abrir" and silencioso then
		chave = "abrirAgachado"
	end
	local r = cfg.ruido[chave]
	assert(r, "Portas.ruido: modo desconhecido " .. tostring(modo))
	return r.db, r.tipo
end

function Portas.duracao(modo: string, cfg: any): number
	if modo == "bater" then
		return cfg.duracaoBater
	elseif modo == "fechar" then
		return cfg.duracaoFechar
	end
	return cfg.duracaoAbrir
end

-- Estado: a porta só muda se o pedido for diferente do atual (e passou o cooldown).
function Portas.podeMudar(aberta: boolean, queAbrir: boolean, ultimo: number, agora: number, cfg: any): boolean
	return aberta ~= queAbrir and agora - ultimo >= cfg.cooldown
end

local function dist2(a: P2, b: P2): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Folha de comprimento `len`, centro `c`, eixo do comprimento `r` (unitário). A folha do mapa está presa à lateral do vão e aberta
-- para dentro: a dobradiça é a ponta com maior afastamento do centro do batente MEDIDO AO LONGO DA PAREDE (`eixo`, unitário; a
-- ponta livre, aberta a 75°, fica mais perto do meio do vão). Sem eixo usa a distância reta; sem batente, a ponta -r.
function Portas.dobradica(c: P2, r: P2, len: number, batente: P2?, eixo: P2?): P2
	local a = { x = c.x - r.x * len / 2, z = c.z - r.z * len / 2 }
	local b = { x = c.x + r.x * len / 2, z = c.z + r.z * len / 2 }
	if not batente then
		return a
	end
	local function afastamento(p: P2): number
		if eixo then
			return math.abs((p.x - batente.x) * eixo.x + (p.z - batente.z) * eixo.z)
		end
		return dist2(p, batente)
	end
	if afastamento(b) > afastamento(a) then
		return b
	end
	return a
end

-- Gira o ponto `p` em torno de `h` por `rad` no sentido de CFrame.Angles(0, rad, 0) (Roblox, Y para cima).
function Portas.girar(p: P2, h: P2, rad: number): P2
	local dx, dz = p.x - h.x, p.z - h.z
	local c, s = math.cos(rad), math.sin(rad)
	return { x = h.x + dx * c + dz * s, z = h.z - dx * s + dz * c }
end

-- Ângulo (rad, com sinal) que leva a folha da posição entreaberta à fechada, a `anguloMapa` graus. A folha fechada fica ao
-- longo da parede: a ponta livre cai dentro do batente. Escolhe o sinal cuja ponta livre fica mais perto do centro do batente.
function Portas.anguloParaFechar(c: P2, h: P2, batente: P2?, anguloMapaGraus: number): number
	local th = math.rad(anguloMapaGraus)
	local livre = { x = 2 * c.x - h.x, z = 2 * c.z - h.z } -- ponta oposta à dobradiça
	if not batente then
		return th
	end
	local mais = Portas.girar(livre, h, th)
	local menos = Portas.girar(livre, h, -th)
	if dist2(mais, batente) <= dist2(menos, batente) then
		return th
	end
	return -th
end

-- Centro da folha fechada.
function Portas.centroFechado(c: P2, h: P2, rad: number): P2
	return Portas.girar(c, h, rad)
end

local function distPontoSegmento(p: P2, a: P2, b: P2): number
	local dx, dz = b.x - a.x, b.z - a.z
	local q = dx * dx + dz * dz
	local t = 0
	if q > 1e-9 then
		t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / q, 0, 1)
	end
	return dist2(p, { x = a.x + dx * t, z = a.z + dz * t })
end

local function cruza(a: P2, b: P2, c: P2, d: P2): boolean
	local function o(p: P2, q: P2, r: P2): number
		return (q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x)
	end
	local o1, o2, o3, o4 = o(a, b, c), o(a, b, d), o(c, d, a), o(c, d, b)
	return (o1 * o2 < 0) and (o3 * o4 < 0)
end

-- Distância mínima entre os segmentos a-b e c-d (0 se cruzam).
function Portas.distSegmentos(a: P2, b: P2, c: P2, d: P2): number
	if cruza(a, b, c, d) then
		return 0
	end
	return math.min(
		distPontoSegmento(a, c, d),
		distPontoSegmento(b, c, d),
		distPontoSegmento(c, a, b),
		distPontoSegmento(d, a, b)
	)
end

-- O caminho de -> ate (a `raio` de folga) corta a porta fechada de dobradiça `h` e ponta livre `fim`?
function Portas.cortaCaminho(de: P2, ate: P2, h: P2, fim: P2, raio: number): boolean
	return Portas.distSegmentos(de, ate, h, fim) <= raio
end

-- Célula do índice espacial.
function Portas.celula(x: number, z: number, tamanho: number): (number, number)
	return math.floor(x / tamanho), math.floor(z / tamanho)
end

return Portas
