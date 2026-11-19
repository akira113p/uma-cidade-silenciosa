local Cfg = require("../src/shared/Config/PresetsMonstro").corpoAriete
local L = require("../src/shared/Regras/Lunge")
local util = require("./util")

-- alcance
assert(L.deveIniciarLunge(Cfg.golpe.alcanceInicio, Cfg), "no limite inicia")
assert(not L.deveIniciarLunge(Cfg.golpe.alcanceInicio + 0.1, Cfg), "longe não inicia")
assert(L.impactoAcerta(Cfg.golpe.alcanceImpacto, Cfg), "no limite acerta")
assert(not L.impactoAcerta(Cfg.golpe.alcanceImpacto + 0.1, Cfg), "recuou: erra")

-- máquina: acerta
local m = L.novo()
util.igual(L.passo(m, 0, 20, Cfg), nil, "longe: nada")
util.igual(m.fase, "Aproximar", "ainda aproximando")
util.igual((L.passo(m, 1, 5, Cfg)), "iniciar", "inicia")
util.igual(m.fase, "Lunge", "em lunge")
assert(not L.podeGolpear(m), "em lunge não golpeia de novo")
util.igual(L.passo(m, 1 + Cfg.golpe.atrasoImpacto - 0.05, 5, Cfg), nil, "antes do impacto")
local ev, acertou = L.passo(m, 1 + Cfg.golpe.atrasoImpacto, 5, Cfg)
util.igual(ev, "impacto", "impacto")
util.igual(acertou, true, "acertou")
util.igual(m.fase, "Recuperar", "recuperando")
-- recuperação bloqueia golpe novo mesmo com o alvo colado
local tImp = 1 + Cfg.golpe.atrasoImpacto
util.igual(L.passo(m, tImp + Cfg.golpe.recuperacao - 0.1, 1, Cfg), nil, "recuperando: sem golpe")
assert(not L.podeGolpear(m), "recuperando não golpeia")
util.igual((L.passo(m, tImp + Cfg.golpe.recuperacao, 1, Cfg)), "fim", "fim da recuperação")
assert(L.podeGolpear(m), "volta a poder golpear")
util.igual((L.passo(m, tImp + Cfg.golpe.recuperacao + 0.1, 1, Cfg)), "iniciar", "novo golpe")

-- máquina: alvo recua e escapa
local m2 = L.novo()
L.passo(m2, 0, 5, Cfg)
local ev2, ac2 = L.passo(m2, Cfg.golpe.atrasoImpacto, Cfg.golpe.alcanceImpacto + 3, Cfg)
util.igual(ev2, "impacto", "impacto mesmo errando")
util.igual(ac2, false, "errou")
util.igual(m2.fase, "Recuperar", "errar também recupera")

-- sortearParte: sem braços e respeita os pesos
local tabela = Cfg.sorteioParte
local soma = 0
for _, e in tabela do
	assert(e.parte ~= "BracoE" and e.parte ~= "BracoD", "tabela sem braço")
	soma += e.peso
end
util.perto(soma, 1, "pesos somam 1")
util.igual(
	L.sortearParte(tabela, function()
		return 0
	end),
	"Torso",
	"rnd 0 = Torso"
)
util.igual(
	L.sortearParte(tabela, function()
		return 0.6
	end),
	"Cabeca",
	"rnd 0.6 = Cabeca"
)
util.igual(
	L.sortearParte(tabela, function()
		return 0.99
	end),
	"PernaD",
	"rnd 0.99 = PernaD"
)
local rng = util.rng(7)
for _ = 1, 2000 do
	local p = L.sortearParte(tabela, rng)
	assert(p ~= "BracoE" and p ~= "BracoD", "nunca braço")
end

-- preset: lunge e herança do Rastejador
util.igual(Cfg.golpe.tipo, "lunge", "tipo lunge")
util.igual(Cfg.altura.jogadorStuds, 5.234, "herda altura do jogador")
util.igual(Cfg.degrau.andar, 2.7, "herda degrau")
util.igual(Cfg.arrombar.golpesMax, 40, "golpesMax do corpoAriete")
util.igual(Cfg.arrombar.fatorDesvio, 2.5, "herda fatorDesvio")
print("Lunge.spec ok")
