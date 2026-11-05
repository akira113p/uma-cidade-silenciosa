local util = require("./util")
local Arremesso = require("../src/shared/Regras/Arremesso")

local G = 196.2
local DT = 1 / 30

-- piso falso em y = 0: acerta quando o segmento cruza y = 0 de cima para baixo
local function piso(a, b)
	if a.y > 0 and b.y <= 0 then
		local t = a.y / (a.y - b.y)
		return { x = a.x + (b.x - a.x) * t, y = 0, z = a.z + (b.z - a.z) * t }, { x = 0, y = 1, z = 0 }
	end
	return nil, nil
end

local function semAcerto(_a, _b)
	return nil, nil
end

-- queda reta: para em y = 0, no mesmo x/z, com a origem como primeiro ponto
local reta = Arremesso.simular({ x = 3, y = 5, z = -2 }, { x = 0, y = 0, z = 0 }, G, DT, 90, piso)
util.igual(reta.tocouChao, true, "queda reta: tocou o chão")
util.perto(reta.repouso.x, 3, "queda reta: x")
util.perto(reta.repouso.y, 0, "queda reta: y")
util.perto(reta.repouso.z, -2, "queda reta: z")
util.perto(reta.normal.y, 1, "queda reta: normal")
util.igual(reta.pontos[1].y, 5, "pontos incluem a origem")
local ultimo = reta.pontos[#reta.pontos]
util.perto(ultimo.y, reta.repouso.y, "último ponto = repouso")
for i = 2, #reta.pontos do
	assert(reta.pontos[i].y <= reta.pontos[i - 1].y + 1e-9, "queda reta nunca sobe")
end
-- sinal da gravidade é ignorado
local neg = Arremesso.simular({ x = 3, y = 5, z = -2 }, { x = 0, y = 0, z = 0 }, -G, DT, 90, piso)
util.igual(#neg.pontos, #reta.pontos, "gravidade negativa dá o mesmo resultado")

-- arco: avança em x e cai mais longe
local arco = Arremesso.simular({ x = 0, y = 2, z = 0 }, { x = 12, y = 6, z = 0 }, G, DT, 90, piso)
util.igual(arco.tocouChao, true, "arco: tocou o chão")
assert(arco.repouso.x > 1.5, "arco avançou em x")
util.perto(arco.repouso.z, 0, "arco: z fica")

-- determinística
local arco2 = Arremesso.simular({ x = 0, y = 2, z = 0 }, { x = 12, y = 6, z = 0 }, G, DT, 90, piso)
util.igual(#arco2.pontos, #arco.pontos, "determinística: mesmo nº de pontos")
util.igual(arco2.repouso.x, arco.repouso.x, "determinística: mesmo repouso")

-- sem chão: acaba em maxPassos, tocouChao=false, repouso = último ponto
local sem = Arremesso.simular({ x = 0, y = 10, z = 0 }, { x = 1, y = 0, z = 0 }, G, DT, 10, semAcerto)
util.igual(sem.tocouChao, false, "sem chão: não tocou")
util.igual(#sem.pontos, 11, "sem chão: origem + maxPassos pontos")
util.igual(sem.repouso.y, sem.pontos[11].y, "sem chão: repouso = último ponto")
util.igual(sem.repouso.x, sem.pontos[11].x, "sem chão: repouso x")
assert(sem.repouso.y < 10, "sem chão: caiu")
local zero = Arremesso.simular({ x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = 0 }, G, DT, 0, piso)
util.igual(zero.tocouChao, false, "maxPassos 0: termina")
util.igual(#zero.pontos, 1, "maxPassos 0: só a origem")

-- parede em x = 0,8 (normal -x): escorrega sem quicar de volta; depois cai no piso
local function mundo(a, b)
	if a.x < 0.8 and b.x >= 0.8 then
		local t = (0.8 - a.x) / (b.x - a.x)
		return { x = 0.8, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t }, { x = -1, y = 0, z = 0 }
	end
	return piso(a, b)
end
local parede = Arremesso.simular({ x = 0, y = 3, z = 0 }, { x = 12, y = 0, z = 4 }, G, DT, 90, mundo)
util.igual(parede.tocouChao, true, "parede: acaba no chão")
assert(parede.repouso.x < 0.8, "parede: não atravessa")
assert(parede.repouso.x > 0.7, "parede: não quica de volta")
assert(parede.repouso.z > 0, "parede: ainda escorrega ao longo dela")
for _, p in parede.pontos do
	assert(p.x < 0.8, "parede: nenhum ponto dentro da parede")
end

-- teto em y = 4 (normal -y): perde a subida e volta a cair
local function comTeto(a, b)
	if a.y < 4 and b.y >= 4 then
		local t = (4 - a.y) / (b.y - a.y)
		return { x = a.x + (b.x - a.x) * t, y = 4, z = a.z + (b.z - a.z) * t }, { x = 0, y = -1, z = 0 }
	end
	return piso(a, b)
end
local teto = Arremesso.simular({ x = 0, y = 1, z = 0 }, { x = 6, y = 40, z = 0 }, G, DT, 90, comTeto)
util.igual(teto.tocouChao, true, "teto: acaba no chão")
for _, p in teto.pontos do
	assert(p.y < 4, "teto: nenhum ponto passa do teto")
end
assert(teto.repouso.x > 0, "teto: guarda a velocidade horizontal")

-- acerto sem normal conta como chão
local semNormal = Arremesso.simular({ x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = 0 }, G, DT, 90, function(a, b)
	if b.y <= 0 then
		return { x = a.x, y = 0, z = a.z }, nil
	end
	return nil, nil
end)
util.igual(semNormal.tocouChao, true, "acerto sem normal: chão")

-- termina sempre, mesmo se o raio acerta toda hora numa parede
local sempre = Arremesso.simular({ x = 0, y = 1, z = 0 }, { x = 1, y = 1, z = 0 }, G, DT, 90, function(a, _b)
	return { x = a.x, y = a.y, z = a.z }, { x = 0, y = -1, z = 0 }
end)
util.igual(sempre.tocouChao, false, "raio sempre acerta teto: termina sem chão")
assert(#sempre.pontos <= 91, "raio sempre acerta: limitado a maxPassos")

print("Arremesso.spec ok")
