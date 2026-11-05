local Corpo = require("../src/shared/Regras/Corpo")
local cfg = require("../src/shared/Config/Corpo")
local Monstros = require("../src/shared/Config/Monstros")
local util = require("./util")

-- novo: vida cheia em todas as partes
local c = Corpo.novo(cfg)
util.igual(c.Cabeca, 30, "cabeça cheia")
util.igual(c.Torso, 60, "torso cheio")
util.igual(c.BracoE, 35, "braço cheio")
util.igual(c.PernaD, 40, "perna cheia")

-- dano simples, sem mutar a entrada
local c2, morto = Corpo.dano(c, "BracoE", 10, cfg)
util.igual(c2.BracoE, 25, "braço depois de 10")
util.igual(c.BracoE, 35, "entrada intacta")
util.igual(morto, false, "braço não mata")

-- transbordo: braço 35 recebe 45 -> braço 0, torso -5
local c3, morto3 = Corpo.dano(c, "BracoD", 45, cfg)
util.igual(c3.BracoD, 0, "braço zerado")
util.igual(c3.Torso, 55, "torso -5 pelo transbordo")
util.igual(morto3, false, "transbordo pequeno não mata")

-- parte já zerada: o golpe inteiro transborda
local c4 = Corpo.dano(c3, "BracoD", 10, cfg)
util.igual(c4.Torso, 50, "golpe em parte zerada transborda metade")

-- mortes
local _, mortoCabeca = Corpo.dano(c, "Cabeca", 30, cfg)
util.igual(mortoCabeca, true, "cabeça 0 -> morreu")
local _, mortoTorso = Corpo.dano(c, "Torso", 60, cfg)
util.igual(mortoTorso, true, "torso 0 -> morreu")
local _, mortoTransbordo = Corpo.dano(c, "PernaE", 40 + 120, cfg)
util.igual(mortoTransbordo, true, "transbordo que zera o torso mata")
local cTorso = Corpo.dano(c, "Torso", 200, cfg)
util.igual(cTorso.Torso, 0, "torso não fica negativo")

-- valor <= 0 não muda nada
local cZero = Corpo.dano(c, "Torso", 0, cfg)
util.igual(cZero.Torso, 60, "dano 0")
local cNeg = Corpo.dano(c, "Torso", -5, cfg)
util.igual(cNeg.Torso, 60, "dano negativo não cura")

-- pernas
util.perto(Corpo.multVelocidade(c, cfg), 1, "sem perna zerada")
local umaPerna = Corpo.dano(c, "PernaE", 40, cfg)
util.perto(Corpo.multVelocidade(umaPerna, cfg), 0.6, "uma perna zerada")
util.igual(Corpo.podeCorrer(umaPerna), false, "uma perna zerada não corre")
local duasPernas = Corpo.dano(umaPerna, "PernaD", 40, cfg)
util.perto(Corpo.multVelocidade(duasPernas, cfg), 0.36, "duas pernas zeradas")
util.igual(Corpo.podeCorrer(c), true, "corpo cheio corre")

-- braços
util.igual(Corpo.bracoZerado(c), false, "braços inteiros")
util.igual(Corpo.bracoZerado(c3), true, "braço direito zerado")

-- queda: 12 -> 0, 20 -> 24
util.perto(Corpo.danoQueda(12, cfg), 0, "queda 12")
util.perto(Corpo.danoQueda(5, cfg), 0, "queda 5")
util.perto(Corpo.danoQueda(20, cfg), 24, "queda 20")

-- cura: escolhe a parte com maior fração faltando; devolve o nome
local ferido = Corpo.dano(Corpo.dano(c, "BracoE", 35, cfg), "Cabeca", 5, cfg) -- braço 0%, cabeça 83%
local curado, parte = Corpo.curar(ferido, 15, cfg)
util.igual(parte, "BracoE", "cura vai para a parte mais ferida")
util.igual(curado.BracoE, 15, "braço +15")
util.igual(ferido.BracoE, 0, "cura não muta a entrada")
local _, nada = Corpo.curar(c, 15, cfg)
util.igual(nada, nil, "corpo cheio não cura")
local limitado = Corpo.curar(Corpo.dano(c, "Cabeca", 3, cfg), 40, cfg)
util.igual(limitado.Cabeca, 30, "cura não passa do máximo")
local _, semValor = Corpo.curar(ferido, 0, cfg)
util.igual(semValor, nil, "cura 0")

-- sorteio de parte
util.igual(Corpo.sortearParte(Monstros.sorteioParte, util.seq({ 0 })), "Torso", "rng 0 -> primeira")
util.igual(Corpo.sortearParte(Monstros.sorteioParte, util.seq({ 0.999999 })), "Cabeca", "rng ~1 -> última")
local rng = util.rng(7)
local contagem: { [string]: number } = {}
local N = 20000
for _ = 1, N do
	local p = Corpo.sortearParte(Monstros.sorteioParte, rng)
	contagem[p] = (contagem[p] or 0) + 1
end
for _, e in Monstros.sorteioParte do
	util.perto((contagem[e.parte] or 0) / N, e.peso, "frequência " .. e.parte, 0.015)
end

print("Corpo.spec ok")
