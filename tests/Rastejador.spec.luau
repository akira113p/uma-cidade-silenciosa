local Cfg = require("../src/shared/Config/PresetsMonstro").quadrupedeArrombador
local R = require("../src/shared/Regras/Rastejador")
local util = require("./util")

-- degraus
util.igual(R.classificarDegrau(0.4, 10, Cfg), "andar", "degrau 0.4")
util.igual(
	R.classificarDegrau(0.9, 10, Cfg),
	"andar",
	"degrau 0.9 (o Humanoid sobe até Cfg.degrau.andar = 1.4, medido)"
)
util.igual(R.classificarDegrau(3.5, 10, Cfg), "saltar", "degrau 3.5")
util.igual(R.classificarDegrau(5.0, 10, Cfg), "parede", "degrau 5.0")
util.igual(R.classificarDegrau(3.5, 1, Cfg), "parede", "sem folga")
util.igual(R.classificarDegrau(Cfg.degrau.andar, 0, Cfg), "andar", "limite andar")
util.perto(R.alturaDoSalto(2.0, Cfg), 2.0 + Cfg.degrau.margemSalto, "salto margem")
util.perto(R.alturaDoSalto(3.5, Cfg), Cfg.degrau.saltoMax, "salto limitado")

-- arrombar
assert(R.precisaArrombar("NoPath", 0, 20, true, Cfg), "NoPath dentro arromba")
assert(not R.precisaArrombar("NoPath", 0, 20, false, Cfg), "alvo fora nunca arromba")
assert(not R.precisaArrombar("Success", 30, 20, true, Cfg), "caminho curto não arromba")
assert(R.precisaArrombar("Success", 500, 20, true, Cfg), "desvio enorme arromba")
assert(not R.precisaArrombar("Success", 500, 20, false, Cfg), "desvio enorme fora não arromba")

-- parede arrombável
assert(R.paredeArrombavel({ 20, 10, 1 }, false, nil, Cfg), "parede fina e alta")
assert(not R.paredeArrombavel({ 20, 10, 3 }, false, nil, Cfg), "grossa")
assert(not R.paredeArrombavel({ 20, 3, 1 }, false, nil, Cfg), "baixa")
assert(not R.paredeArrombavel({ 20, 10, 1 }, true, nil, Cfg), "piso")
assert(not R.paredeArrombavel({ 20, 10, 1 }, false, { Indestrutivel = true }, Cfg), "indestrutível")
-- objetivo
local function c(t: string, d: number, idade: number?, ocupado: boolean?)
	return { tipo = t, distancia = d, idade = idade, ocupado = ocupado }
end
local function tipoEscolhido(lista: { any }): string
	local r = R.escolherObjetivo(lista, Cfg)
	assert(r, "esperava candidato")
	return r.tipo
end
util.igual(
	tipoEscolhido({ c("som", 1), c("parede", 2), c("veiculo", 9, 1), c("jogador", 20) }),
	"jogador",
	"jogador primeiro"
)
util.igual(tipoEscolhido({ c("som", 1), c("parede", 2), c("veiculo", 9, 1) }), "veiculo", "veículo ruidoso")
util.igual(tipoEscolhido({ c("som", 1), c("parede", 2) }), "parede", "parede")
util.igual(tipoEscolhido({ c("som", 1), c("veiculo", 2, 99) }), "som", "veículo antigo perde")
util.igual(tipoEscolhido({ c("som", 1), c("veiculo", 2, 99, true) }), "veiculo", "veículo ocupado vale")
local perto = R.escolherObjetivo({ c("veiculo", 9, 1), c("veiculo", 3, 1) }, Cfg)
assert(perto and perto.distancia == 3, "desempate por distância")
assert(R.escolherObjetivo({}, Cfg) == nil, "sem candidatos")

-- parte do veículo
util.igual(R.parteDoVeiculo(0.1, true, Cfg), "pneu", "pneu")
util.igual(R.parteDoVeiculo(0.4, true, Cfg), "vidro", "vidro com ocupante")
util.igual(R.parteDoVeiculo(0.9, true, Cfg), "carroceria", "carroceria")
util.igual(R.parteDoVeiculo(0.5, false, Cfg), "carroceria", "sem ocupante não há vidro")
util.igual(R.parteDoVeiculo(0.2, false, Cfg), "pneu", "pneu sem ocupante")

-- ação
util.igual(R.acao("Caca", true, false, 14, true, Cfg), "Death", "morto")
util.igual(R.acao("Caca", true, false, 14, false, Cfg), "Attack", "ataque")
util.igual(R.acao("Calmo", false, false, 0, false, Cfg), "Idle", "parado")
util.igual(R.acao("Calmo", false, false, 6, false, Cfg), "Walk", "andando")
util.igual(R.acao("Caca", false, false, 14, false, Cfg), "Run", "caça")
util.igual(R.acao("Calmo", false, true, 6, false, Cfg), "Run", "subindo")
util.perto(R.velocidadeAnim("Walk", Cfg.animacao.nativas.Walk, Cfg), 1, "anim walk")
util.perto(R.velocidadeAnim("Run", 1000, Cfg), Cfg.animacao.velMax, "anim limite")
util.perto(R.velocidadeAnim("Idle", 6, Cfg), 1, "anim idle")

-- velocidade por espécie (Corcunda/Esfolado não usam)
util.igual(R.velocidade("Caca", Cfg), 20, "velocidade Caca")
util.igual(R.velocidade("Ataque", Cfg), 20, "velocidade Ataque")
util.igual(R.velocidade("Calmo", Cfg), 8, "velocidade Calmo")
util.igual(R.velocidade("Investiga", Cfg), 8, "velocidade Investiga")
assert(R.velocidade("Inexistente", Cfg) == nil, "estado desconhecido")
assert(Cfg.velocidade.Caca > 16, "Caça mais rápida que o jogador correndo")
util.perto(
	R.velocidadeAnim("Run", Cfg.velocidade.Caca, Cfg),
	Cfg.velocidade.Caca / Cfg.animacao.nativas.Run,
	"Run a 20 sem limite"
)

-- parede mais fraca
util.igual(R.escolherParede({ { golpes = 20, distancia = 5 }, { golpes = 8, distancia = 30 } }, Cfg), 2, "menos golpes")
util.igual(
	R.escolherParede({ { golpes = 8, distancia = 30 }, { golpes = 8, distancia = 5 } }, Cfg),
	2,
	"empate: mais perto"
)
assert(R.escolherParede({ { golpes = 1000, distancia = 1 } }, Cfg) == nil, "acima de golpesMax ignora")
assert(R.escolherParede({}, Cfg) == nil, "sem candidatas")
util.igual(R.escolherParede({ { golpes = Cfg.arrombar.golpesMax, distancia = 1 } }, Cfg), 1, "no limite aceita")

print("Rastejador.spec ok")
