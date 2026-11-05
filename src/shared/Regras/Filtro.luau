-- Regras puras do filtro visual (docs/filtro.md §4): decaimento dos pulsos, quadros e deslocamento do grão,
-- sorteio do próximo glitch, histerese da qualidade automática. Sem Instance: testado no Lune (tests/Filtro.spec.luau).
local Filtro = {}

local function limitar(v: number, minimo: number, maximo: number): number
	return math.max(minimo, math.min(maximo, v))
end

-- xorshift32 sobre inteiros: determinístico, sem estado, cabe em bit32 (sem estourar a precisão do double).
local function mexer(entrada: number, sal: number): number
	local x = bit32.bxor(entrada % 4294967296, sal)
	if x == 0 then
		x = 1
	end
	for _ = 1, 2 do
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
	end
	return x
end

-- Interpolação linear com f limitado a 0..1.
function Filtro.mistura(a: number, b: number, f: number): number
	return a + (b - a) * limitar(f, 0, 1)
end

-- Decaimento exponencial por meia-vida (s). dt <= 0 mantém; meia-vida <= 0 zera de uma vez.
function Filtro.decair(valor: number, dt: number, meiaVida: number): number
	if valor <= 0 then
		return 0
	end
	if dt <= 0 then
		return valor
	end
	if meiaVida <= 0 then
		return 0
	end
	return valor * 0.5 ^ (dt / meiaVida)
end

-- Aproxima `atual` de `alvo` com a mesma meia-vida (suavização independente do FPS).
function Filtro.suavizar(atual: number, alvo: number, dt: number, meiaVida: number): number
	return alvo + (atual - alvo) * (if dt <= 0 then 1 elseif meiaVida <= 0 then 0 else 0.5 ^ (dt / meiaVida))
end

-- Índice do quadro de grão (1..nQuadros) no instante t. Troca a cada 1/fps, sorteado por quadro e nunca repete o
-- anterior: quadros pares usam as posições pares e os ímpares as ímpares (2 * sorteio + paridade).
function Filtro.quadroGrao(t: number, fps: number, nQuadros: number): number
	if nQuadros < 2 or fps <= 0 or t ~= t then
		return 1
	end
	local k = math.floor(t * fps)
	local grupos = math.floor(nQuadros / 2)
	return 2 * (mexer(k, 0x9E3779B9) % grupos) + (k % 2) + 1
end

-- Deslocamento (px, 0..tamanho-1) do grão no quadro de t; igual dentro do mesmo quadro, muda entre quadros.
function Filtro.deslocGrao(t: number, fps: number, tamanho: number): (number, number)
	if tamanho < 1 or fps <= 0 or t ~= t then
		return 0, 0
	end
	local k = math.floor(t * fps)
	return mexer(k, 0x85EBCA6B) % tamanho, mexer(k, 0xC2B2AE35) % tamanho
end

-- Instante do próximo glitch. cfg = Config.Filtro.Geral.glitch: o intervalo (s) sorteado vai de intervaloDia a
-- intervaloNoite conforme `noite` (0..1) e é dividido por (1 + caca * (divisorCaca - 1)).
function Filtro.proximoGlitch(agora: number, noite: number, caca: number, cfg: any, rng: any): number
	local sorteio = if type(rng) == "function" then rng() else rng:NextNumber()
	local f = limitar(noite, 0, 1)
	local minimo = Filtro.mistura(cfg.intervaloDia[1], cfg.intervaloNoite[1], f)
	local maximo = Filtro.mistura(cfg.intervaloDia[2], cfg.intervaloNoite[2], f)
	local intervalo = minimo + (maximo - minimo) * limitar(sorteio, 0, 1)
	intervalo /= 1 + limitar(caca, 0, 1) * (cfg.divisorCaca - 1)
	return agora + intervalo
end

-- Instante da próxima rajada de estalos de fita. cfg = Config.Filtro.Moldura.estalos: intervalo sorteado em
-- [intervalo[1], intervalo[2]] s, dividido por divisorNoite (à noite) e por divisorCaca (em caça), interpolados.
function Filtro.proximoEstalo(agora: number, noite: number, caca: number, cfg: any, rng: any): number
	local sorteio = if type(rng) == "function" then rng() else rng:NextNumber()
	local intervalo = cfg.intervalo[1] + (cfg.intervalo[2] - cfg.intervalo[1]) * limitar(sorteio, 0, 1)
	intervalo /= 1 + limitar(noite, 0, 1) * (cfg.divisorNoite - 1)
	intervalo /= 1 + limitar(caca, 0, 1) * (cfg.divisorCaca - 1)
	return agora + intervalo
end

-- Qualidade automática 0..3 com histerese. segAbaixo = segundos seguidos com a média abaixo do mínimo do nível atual;
-- segAcima = segundos seguidos com a média acima do mínimo do nível seguinte mais a folga.
-- cfg = Config.Filtro.Geral.qualidade { minimo = {[1],[2],[3]}, folga, segDescer, segSubir }. Muda um nível por chamada.
function Filtro.nivelPorFps(nivel: number, mediaFps: number, segAbaixo: number, segAcima: number, cfg: any): number
	if mediaFps ~= mediaFps or mediaFps <= 0 then
		return nivel
	end
	if nivel > 0 and mediaFps < cfg.minimo[nivel] and segAbaixo >= cfg.segDescer then
		return nivel - 1
	end
	if nivel < 3 and mediaFps >= cfg.minimo[nivel + 1] + cfg.folga and segAcima >= cfg.segSubir then
		return nivel + 1
	end
	return nivel
end

-- Quanto um monstro em Caça a `dist` studs pesa: 1 a `perto` ou menos, 0 a `longe` ou mais, linear no meio.
function Filtro.intensidadeCaca(dist: number, perto: number, longe: number): number
	if longe <= perto then
		return if dist <= perto then 1 else 0
	end
	return limitar((longe - dist) / (longe - perto), 0, 1)
end

return Filtro
