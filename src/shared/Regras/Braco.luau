--!strict
-- IK analítico de 2 ossos (ombro → cotovelo → mão) para os braços do viewmodel. Puro, vetores {x,y,z}.
-- Contrato: docs/armas.md §5 e §10.2. Dono: A1.

export type Vec = { x: number, y: number, z: number }

local Braco = {}

local EPS = 1e-6

local function finito(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

local function sub(a: Vec, b: Vec): Vec
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function soma(a: Vec, b: Vec): Vec
	return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

local function escala(a: Vec, k: number): Vec
	return { x = a.x * k, y = a.y * k, z = a.z * k }
end

local function ponto(a: Vec, b: Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function cruz(a: Vec, b: Vec): Vec
	return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x }
end

local function comprimento(a: Vec): number
	return math.sqrt(ponto(a, a))
end

local function unitario(a: Vec): Vec?
	local m = comprimento(a)
	if not finito(m) or m < EPS then
		return nil
	end
	return escala(a, 1 / m)
end

local function vecFinito(v: Vec): boolean
	return finito(v.x) and finito(v.y) and finito(v.z)
end

-- `polo` é uma DIREÇÃO (não um ponto): o cotovelo se dobra para o lado dela (para fora/baixo no viewmodel).
-- Só a parte de `polo` perpendicular ao eixo ombro→alvo conta; se `polo` é nulo ou paralelo ao eixo, escolhe um
-- perpendicular estável (sempre o mesmo para a mesma entrada, sem tremer).
-- Alvo além de l1 + l2: o braço estica em linha reta e a mão fica em l1 + l2 do ombro (não alcança o alvo).
-- Alvo mais perto que |l1 - l2|: a mão fica em |l1 - l2| do ombro, na direção do alvo.
-- Devolve (cotovelo, mão). Entrada não finita devolve o braço esticado para -Z (nunca NaN).
function Braco.resolver2Ossos(ombro: Vec, alvo: Vec, polo: Vec, l1: number, l2: number): (Vec, Vec)
	if
		not (vecFinito(ombro) and vecFinito(alvo) and vecFinito(polo) and finito(l1) and finito(l2))
		or l1 <= 0
		or l2 <= 0
	then
		local o: Vec = if vecFinito(ombro) then ombro else { x = 0, y = 0, z = 0 }
		local reto: Vec = { x = 0, y = 0, z = -1 }
		local a = if finito(l1) and l1 > 0 then l1 else 0
		local b = if finito(l2) and l2 > 0 then l2 else 0
		return soma(o, escala(reto, a)), soma(o, escala(reto, a + b))
	end

	local aOmbro = sub(alvo, ombro)
	local distReal = comprimento(aOmbro)
	local dir = unitario(aOmbro)
	if dir == nil then
		-- alvo em cima do ombro: eixo arbitrário mas fixo
		dir = { x = 0, y = 0, z = -1 }
	end
	local eixo = dir :: Vec

	local minimo = math.abs(l1 - l2)
	local maximo = l1 + l2
	local dist = math.clamp(distReal, minimo, maximo)

	-- perpendicular ao eixo mais próximo de `polo`
	local perp = unitario(sub(polo, escala(eixo, ponto(polo, eixo))))
	if perp == nil then
		local auxiliar: Vec = if math.abs(eixo.y) < 0.99 then { x = 0, y = 1, z = 0 } else { x = 1, y = 0, z = 0 }
		perp = unitario(cruz(auxiliar, eixo)) :: Vec
		-- cruz(auxiliar, eixo) aponta para a esquerda do eixo; para y-up queremos "baixo" como padrão do cotovelo
		perp = escala(perp :: Vec, -1)
	end
	local p = perp :: Vec

	-- triângulo ombro, cotovelo, mão: `a` = projeção do cotovelo no eixo, `h` = altura
	local a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h2 = l1 * l1 - a * a
	local h = if h2 > 0 then math.sqrt(h2) else 0
	local cotovelo = soma(soma(ombro, escala(eixo, a)), escala(p, h))
	local mao = soma(ombro, escala(eixo, dist))
	return cotovelo, mao
end

return Braco
