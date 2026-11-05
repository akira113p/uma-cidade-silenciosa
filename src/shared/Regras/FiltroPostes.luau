-- Regras puras dos postes do filtro (docs/filtro.md §4). Sem Instance; testável no Lune.
local FiltroPostes = {}

local MOD = 4294967296 -- 2^32

-- Hash 0..1 da posição (quantizada a 0,25 stud) e de um sal. Determinístico.
local function hash01(x: number, z: number, sal: number): number
	local ix = math.floor(x * 4 + 0.5)
	local iz = math.floor(z * 4 + 0.5)
	local h = (ix * 73856093 + iz * 19349663 + sal * 83492791) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = (h * 1664525 + 1013904223) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 1664525 + 1013904223) % MOD
	return h / MOD
end

-- "normal" | "pisca" | "quebrada". cfg.fracaoQuebrada e cfg.fracaoPisca (0..1).
function FiltroPostes.estadoLampada(x: number, z: number, cfg): string
	local h = hash01(x, z, 1)
	if h < cfg.fracaoQuebrada then
		return "quebrada"
	elseif h < cfg.fracaoQuebrada + cfg.fracaoPisca then
		return "pisca"
	end
	return "normal"
end

-- Brilho 0..1 de uma lâmpada que pisca: luz firme, com rajadas curtas de tremida e apagão.
function FiltroPostes.brilhoPisca(t: number, x: number, z: number): number
	local periodo = 2.5 + hash01(x, z, 2) * 3 -- s
	local p = (t / periodo + hash01(x, z, 3)) % 1
	if p < 0.12 then
		-- rajada: liga e desliga rápido
		return if math.floor(p * 100) % 2 == 0 then 0.1 else 0.85
	elseif p < 0.18 then
		return 0 -- apagão curto
	end
	return 1
end

-- Índices (1..#distancias) dos n menores valores, do mais perto ao mais longe. Empate: índice menor primeiro.
-- n maior que a lista devolve todos.
function FiltroPostes.maisPerto(distancias: { number }, n: number): { number }
	local indices = table.create(#distancias)
	for i = 1, #distancias do
		indices[i] = i
	end
	table.sort(indices, function(a, b)
		local da, db = distancias[a], distancias[b]
		if da == db then
			return a < b
		end
		return da < db
	end)
	local limite = math.max(0, math.min(math.floor(n), #indices))
	local saida = table.create(limite)
	for i = 1, limite do
		saida[i] = indices[i]
	end
	return saida
end

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Fade do cone pela proximidade do eixo: 0 até `perto`, 1 a partir de `longe` (smoothstep). distHoriz em studs.
function FiltroPostes.fatorProximidadeCone(distHoriz: number, perto: number, longe: number): number
	if longe <= perto then
		return if distHoriz >= longe then 1 else 0
	end
	return suave((distHoriz - perto) / (longe - perto))
end

-- Fade do cone pelo ângulo de visão: dot = |LookVector . eixo|. 1 até `minimo`, 0 a partir de `maximo` (smoothstep).
function FiltroPostes.fatorAnguloCone(dot: number, minimo: number, maximo: number): number
	if maximo <= minimo then
		return if dot <= minimo then 1 else 0
	end
	return 1 - suave((math.abs(dot) - minimo) / (maximo - minimo))
end

return FiltroPostes
