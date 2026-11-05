--!strict
-- Contas puras da névoa em camadas (docs/filtro.md §4). Sem Roblox. Dono: S3.

local FiltroNeblina = {}

export type Celula = { chave: string, x: number, z: number }

-- Células da grade fixa no mundo (pontos em múltiplos de `espacamento`) cuja distância ao centro (cx, cz) fica em
-- [raioInt, raioExt]. A chave "i,j" é o índice inteiro da célula (estável: a mesma célula tem sempre a mesma chave).
function FiltroNeblina.anel(cx: number, cz: number, espacamento: number, raioInt: number, raioExt: number): { Celula }
	local lista: { Celula } = {}
	local i0 = math.floor((cx - raioExt) / espacamento)
	local i1 = math.ceil((cx + raioExt) / espacamento)
	local j0 = math.floor((cz - raioExt) / espacamento)
	local j1 = math.ceil((cz + raioExt) / espacamento)
	local int2, ext2 = raioInt * raioInt, raioExt * raioExt
	for i = i0, i1 do
		for j = j0, j1 do
			local x, z = i * espacamento, j * espacamento
			local d2 = (x - cx) ^ 2 + (z - cz) ^ 2
			if d2 >= int2 and d2 <= ext2 then
				table.insert(lista, { chave = i .. "," .. j, x = x, z = z })
			end
		end
	end
	return lista
end

-- Deslocamento determinístico (dx, dz) em [-amplitude, amplitude], a partir da chave. Mesmo texto, mesmo resultado.
function FiltroNeblina.jitter(chave: string, amplitude: number): (number, number)
	local h = 7
	for k = 1, #chave do
		h = (h * 31 + string.byte(chave, k)) % 2147483647
	end
	local a = (h * 16807) % 2147483647
	local b = (a * 16807) % 2147483647
	return ((a - 1) / 2147483646 * 2 - 1) * amplitude, ((b - 1) / 2147483646 * 2 - 1) * amplitude
end

-- 0 até raioInt, sobe linear em `rampaInt`, 1 no meio, desce linear em `rampaExt` até 0 em raioExt.
function FiltroNeblina.fade(dist: number, raioInt: number, rampaInt: number, raioExt: number, rampaExt: number): number
	if dist <= raioInt or dist >= raioExt then
		return 0
	end
	local f = 1
	if rampaInt > 0 and dist < raioInt + rampaInt then
		f = math.min(f, (dist - raioInt) / rampaInt)
	end
	if rampaExt > 0 and dist > raioExt - rampaExt then
		f = math.min(f, (raioExt - dist) / rampaExt)
	end
	return math.clamp(f, 0, 1)
end

-- Arredonda v (0..1) para múltiplos de 1/niveis; poucos valores distintos = poucas NumberSequence em cache.
function FiltroNeblina.quantizar(v: number, niveis: number): number
	return math.floor(math.clamp(v, 0, 1) * niveis + 0.5) / niveis
end

return FiltroNeblina
