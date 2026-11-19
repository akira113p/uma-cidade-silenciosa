local Cfg = require("../src/shared/Config/Portas")
local R = require("../src/shared/Regras/Portas")
local util = require("./util")

-- ruído por modo
local db, tipo = R.ruido("abrir", false, Cfg)
util.igual(db, 45, "abrir 45 dB")
util.igual(tipo, "portaAbrir", "tipo abrir")
db, tipo = R.ruido("abrir", true, Cfg)
util.igual(db, 25, "abrir agachado 25 dB")
util.igual(tipo, "portaAbrir", "tipo abrir agachado")
db, tipo = R.ruido("fechar", false, Cfg)
util.igual(db, 50, "fechar 50 dB")
util.igual(tipo, "portaFechar", "tipo fechar")
db, tipo = R.ruido("bater", false, Cfg)
util.igual(db, 65, "bater 65 dB")
util.igual(tipo, "portaBater", "tipo bater")
db = R.ruido("fechar", true, Cfg)
util.igual(db, 50, "fechar agachado não muda (só abrir)")

-- durações
util.perto(R.duracao("abrir", Cfg), 0.35, "abrir 0,35 s")
util.perto(R.duracao("fechar", Cfg), 0.35, "fechar 0,35 s")
util.perto(R.duracao("bater", Cfg), 0.15, "bater 0,15 s")

-- estado e cooldown
assert(R.podeMudar(true, false, 0, 1, Cfg), "aberta -> fechar")
assert(not R.podeMudar(true, true, 0, 1, Cfg), "já aberta: não abre de novo")
assert(not R.podeMudar(true, false, 0.9, 1, Cfg), "cooldown")

-- Dobradiça de uma folha conhecida: vão ao longo de X de -3 a 3 (largura 6), batente centrado em (0, 0).
-- Folha presa à lateral esquerda (x = -2.8), comprimento 5,6, aberta a 75° para +Z: direção (cos75 em x, sen75 em z).
local th = math.rad(75)
local len = 5.6
local hinge = { x = -2.8, z = 0 }
local r = { x = math.cos(th), z = math.sin(th) }
local centro = { x = hinge.x + r.x * len / 2, z = hinge.z + r.z * len / 2 }
local eixo = { x = 1, z = 0 } -- a parede corre ao longo de X
local h = R.dobradica(centro, r, len, { x = 0, z = 0 }, eixo)
util.perto(h.x, hinge.x, "dobradiça x")
util.perto(h.z, hinge.z, "dobradiça z")
-- com o eixo invertido (-r) a dobradiça continua a mesma (a ponta longe do batente)
local h2 = R.dobradica(centro, { x = -r.x, z = -r.z }, len, { x = 0, z = 0 }, eixo)
util.perto(h2.x, hinge.x, "dobradiça com eixo invertido x")
util.perto(h2.z, hinge.z, "dobradiça com eixo invertido z")

-- ângulo para fechar: a ponta livre cai ao longo da parede (z = 0), dentro do batente
local ang = R.anguloParaFechar(centro, h, { x = 0, z = 0 }, 75)
local centroF = R.centroFechado(centro, h, ang)
util.perto(centroF.z, 0, "fechada: sobre a parede (z)", 0.01)
util.perto(centroF.x, hinge.x + len / 2, "fechada: centro x", 0.01)
-- vão espelhado (folha aberta para -Z): o sinal muda, o resultado não
local rE = { x = math.cos(th), z = -math.sin(th) }
local centroE = { x = hinge.x + rE.x * len / 2, z = hinge.z + rE.z * len / 2 }
local angE = R.anguloParaFechar(centroE, hinge, { x = 0, z = 0 }, 75)
assert(angE == -ang, "sinal oposto no espelho")
local fE = R.centroFechado(centroE, hinge, angE)
util.perto(fE.z, 0, "espelho fechada z", 0.01)
util.perto(fE.x, hinge.x + len / 2, "espelho fechada x", 0.01)

-- porta fechada corta o caminho que a atravessa; não corta o que passa ao lado
local fim = { x = hinge.x + len, z = 0 }
assert(R.cortaCaminho({ x = 0, z = -4 }, { x = 0, z = 4 }, hinge, fim, 0.1), "atravessa")
assert(not R.cortaCaminho({ x = 0, z = -4 }, { x = 0, z = -1 }, hinge, fim, 0.1), "para antes")
assert(R.cortaCaminho({ x = 0, z = -4 }, { x = 0, z = -0.5 }, hinge, fim, 0.6), "folga raio")
assert(not R.cortaCaminho({ x = 4, z = -4 }, { x = 4, z = 4 }, hinge, fim, 0.1), "passa depois da ponta")

-- índice espacial
local cx, cz = R.celula(-0.1, 63.9, 32)
util.igual(cx, -1, "célula x negativa")
util.igual(cz, 1, "célula z")
print("Portas.spec ok")
