local Cfg = require("../src/shared/Config/ArmasMonstro").aparar
local A = require("../src/shared/Regras/Aparar")
local util = require("./util")

local frente = { x = 0, y = 0, z = -1 } -- monstro olha para -Z; atirador em -Z atira para +Z
local paraMonstro = { x = 0, y = 0, z = 1 }
assert(A.vemDaFrente(frente, paraMonstro, Cfg.cone), "de frente")
local lado = { x = 1, y = 0, z = 0 }
assert(not A.vemDaFrente(frente, lado, Cfg.cone), "de lado")
assert(not A.vemDaFrente(frente, { x = 0, y = 0, z = -1 }, Cfg.cone), "pelas costas")
-- limite do cone (30° de cada lado)
local a = math.rad(29)
assert(A.vemDaFrente(frente, { x = math.sin(a), y = 0, z = math.cos(a) }, Cfg.cone), "29° dentro")
a = math.rad(31)
assert(not A.vemDaFrente(frente, { x = math.sin(a), y = 0, z = math.cos(a) }, Cfg.cone), "31° fora")

assert(A.ehTronco("Torso", Cfg.naoTronco) and A.ehTronco("UpperTorso", Cfg.naoTronco), "tronco")
assert(not A.ehTronco("Head", Cfg.naoTronco) and not A.ehTronco("LeftArm", Cfg.naoTronco), "cabeça e braço não")

util.perto(A.multiplicador("pistola", "Caca", "Torso", frente, paraMonstro, Cfg), 0.5, "pistola bloqueada")
util.perto(A.multiplicador("pistola", "Calmo", "Torso", frente, paraMonstro, Cfg), 1, "calmo: dano cheio")
util.perto(A.multiplicador("fuzil", "Caca", "Torso", frente, paraMonstro, Cfg), 1, "fuzil: dano cheio")
util.perto(A.multiplicador("pistola", "Caca", "Head", frente, paraMonstro, Cfg), 1, "cabeça: dano cheio")
util.perto(A.multiplicador("pistola", "Caca", "Torso", frente, lado, Cfg), 1, "de lado: dano cheio")
print("Aparar.spec ok")
