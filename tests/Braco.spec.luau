local Braco = require("../src/shared/Regras/Braco")
local util = require("./util")

local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local ombro = { x = 0, y = 0, z = 0 }
local l1, l2 = 1.2, 1.1

-- alvo alcançável: mão no alvo, ossos com o comprimento certo
local alvo = { x = 0.5, y = -0.3, z = -1.4 }
local cot, mao = Braco.resolver2Ossos(ombro, alvo, { x = 0, y = -1, z = 0 }, l1, l2)
util.perto(dist(mao, alvo), 0, "mão no alvo", 1e-6)
util.perto(dist(ombro, cot), l1, "osso 1", 1e-6)
util.perto(dist(cot, mao), l2, "osso 2", 1e-6)

-- polo escolhe o lado do cotovelo (polo para baixo vs para cima)
local cotBaixo = Braco.resolver2Ossos(ombro, alvo, { x = 0, y = -1, z = 0 }, l1, l2)
local cotCima = Braco.resolver2Ossos(ombro, alvo, { x = 0, y = 1, z = 0 }, l1, l2)
assert(cotBaixo.y < cotCima.y, "cotovelo vai para o lado do polo")
local cotFora = Braco.resolver2Ossos(ombro, alvo, { x = 1, y = 0, z = 0 }, l1, l2)
local cotDentro = Braco.resolver2Ossos(ombro, alvo, { x = -1, y = 0, z = 0 }, l1, l2)
assert(cotFora.x > cotDentro.x, "polo lateral")
-- os dois lados são simétricos em relação ao eixo ombro-alvo: osso 1 igual
util.perto(dist(ombro, cotCima), l1, "osso 1 no outro lado", 1e-6)

-- polo parcialmente paralelo ao eixo: só a parte perpendicular conta
local cotPolo = Braco.resolver2Ossos(ombro, { x = 0, y = 0, z = -1.5 }, { x = 0, y = -1, z = -5 }, l1, l2)
assert(cotPolo.y < 0, "polo inclinado ainda dobra para baixo")

-- alvo longe demais: estica
local longe = { x = 0, y = 0, z = -10 }
local cotL, maoL = Braco.resolver2Ossos(ombro, longe, { x = 0, y = -1, z = 0 }, l1, l2)
util.perto(dist(ombro, maoL), l1 + l2, "esticado: mão a l1 + l2", 1e-6)
util.perto(dist(ombro, cotL), l1, "esticado: osso 1", 1e-6)
util.perto(dist(cotL, maoL), l2, "esticado: osso 2", 1e-6)
util.perto(maoL.z, -(l1 + l2), "esticado na direção do alvo", 1e-6)
util.perto(cotL.y, 0, "esticado: cotovelo na linha", 1e-6)

-- alvo no limite exato
local _, maoLim = Braco.resolver2Ossos(ombro, { x = 0, y = 0, z = -(l1 + l2) }, { x = 0, y = -1, z = 0 }, l1, l2)
util.perto(maoLim.z, -(l1 + l2), "no limite", 1e-6)

-- alvo perto demais (dentro de |l1 - l2|): mão em |l1 - l2|, ossos preservados
local cotP, maoP = Braco.resolver2Ossos(ombro, { x = 0, y = 0, z = -0.01 }, { x = 0, y = -1, z = 0 }, l1, l2)
util.perto(dist(ombro, maoP), math.abs(l1 - l2), "perto demais: mão no mínimo", 1e-6)
util.perto(dist(ombro, cotP), l1, "perto demais: osso 1", 1e-6)
util.perto(dist(cotP, maoP), l2, "perto demais: osso 2", 1e-6)

-- alvo em cima do ombro e polo nulo: sem NaN
local cotZ, maoZ = Braco.resolver2Ossos(ombro, ombro, { x = 0, y = 0, z = 0 }, l1, l2)
for _, v in { cotZ, maoZ } do
	assert(v.x == v.x and v.y == v.y and v.z == v.z, "sem NaN com alvo no ombro")
end

-- polo paralelo ao eixo: perpendicular estável, sem NaN, ossos corretos
local cotPar, maoPar = Braco.resolver2Ossos(ombro, { x = 0, y = 0, z = -1.5 }, { x = 0, y = 0, z = -1 }, l1, l2)
util.perto(dist(ombro, cotPar), l1, "polo paralelo: osso 1", 1e-6)
util.perto(dist(cotPar, maoPar), l2, "polo paralelo: osso 2", 1e-6)
local cotPar2 = Braco.resolver2Ossos(ombro, { x = 0, y = 0, z = -1.5 }, { x = 0, y = 0, z = -1 }, l1, l2)
util.perto(dist(cotPar, cotPar2), 0, "polo paralelo é determinístico", 1e-9)

-- eixo vertical (ombro acima do alvo): sem NaN
local cotV, maoV = Braco.resolver2Ossos(ombro, { x = 0, y = -1.5, z = 0 }, { x = 0, y = 0, z = 0 }, l1, l2)
util.perto(dist(cotV, maoV), l2, "eixo vertical: osso 2", 1e-6)

-- ombro deslocado: resultado é relativo ao ombro
local o2 = { x = 10, y = 5, z = -3 }
local cot2, mao2 = Braco.resolver2Ossos(o2, { x = 10.5, y = 4.7, z = -4.4 }, { x = 0, y = -1, z = 0 }, l1, l2)
util.perto(dist(cot2, o2), l1, "ombro deslocado: osso 1", 1e-6)
util.perto(dist(mao2, { x = 10.5, y = 4.7, z = -4.4 }), 0, "ombro deslocado: mão no alvo", 1e-6)

-- entrada inválida: nunca NaN
local cotN, maoN = Braco.resolver2Ossos(ombro, { x = 0 / 0, y = 0, z = 0 }, { x = 0, y = -1, z = 0 }, l1, l2)
assert(cotN.x == cotN.x and maoN.z == maoN.z, "alvo NaN não propaga")
local cotI, maoI = Braco.resolver2Ossos(ombro, alvo, { x = 0, y = -1, z = 0 }, 0, l2)
assert(cotI.x == cotI.x and maoI.z == maoI.z, "osso de comprimento 0 não propaga NaN")

print("Braco.spec ok")
