local BracosVista = require("../src/shared/Regras/BracosVista")
local util = require("./util")

-- velocidade: nativa / alvo, com limites; dado ruim = 1
util.perto(BracosVista.velocidade(2.6, 1.3, 0.4, 4), 2, "recarga mais curta que o clipe acelera")
util.perto(BracosVista.velocidade(2.6, 5.2, 0.4, 4), 0.5, "recarga mais longa desacelera")
util.perto(BracosVista.velocidade(2.6, 0.1, 0.4, 4), 4, "limite máximo")
util.perto(BracosVista.velocidade(0.2, 5, 0.4, 4), 0.4, "limite mínimo")
util.perto(BracosVista.velocidade(0, 1, 0.4, 4), 1, "nativa zero = 1")
util.perto(BracosVista.velocidade(1, 0, 0.4, 4), 1, "alvo zero = 1")
util.perto(BracosVista.velocidade(1, 0 / 0, 0.4, 4), 1, "alvo NaN = 1")

-- tiro: nunca abaixo de 1, sobe se a cadência é menor que o clipe
util.perto(BracosVista.velocidadeTiro(0.12, 0.1, 4), 1.2, "fuzil: clipe 0,12 s com cadência 0,1 s")
util.perto(BracosVista.velocidadeTiro(0.12, 0.5, 4), 1, "cadência lenta não desacelera o tiro")
util.perto(BracosVista.velocidadeTiro(0.7, 0.05, 4), 4, "limite do tiro")

-- golpe: o impacto do clipe cai no atrasoImpacto
util.perto(BracosVista.velocidadeGolpe(0.35, 0.35, 1, 1.2, 0.5, 2.5), 1, "machado: impacto já casa")
util.perto(BracosVista.velocidadeGolpe(0.35, 0.175, 1, 1.2, 0.5, 2.5), 2, "impacto cedo = clipe acelerado")
-- o golpe inteiro tem de caber em 95% da cadência
local v = BracosVista.velocidadeGolpe(0.25, 0.25, 0.7, 0.35, 0.5, 2.5)
assert(0.7 / v <= 0.35 * 0.95 + 1e-6, "golpe cabe na cadência")
util.perto(
	BracosVista.velocidadeGolpe(nil, 0.3, 1, 1, 0.5, 2.5),
	1.0526,
	"sem marcador: só o teto da cadência",
	0.001
)

-- escolha do clipe de golpe
util.igual(BracosVista.clipeGolpe("faca", 1), "Golpe1", "faca 1")
util.igual(BracosVista.clipeGolpe("faca", 2), "Golpe2", "faca 2")
util.igual(BracosVista.clipeGolpe("faca", nil), "Golpe1", "faca sem índice")
util.igual(BracosVista.clipeGolpe("machado", 2), "Golpe", "machado tem um só")

-- etapas da recarga por cartucho
local e = BracosVista.etapasTubo(0.5, 0.55, 0.4, 0.5 + 0.55 * 3 + 0.4)
util.igual(#e, 5, "início + 3 cartuchos + fim")
util.igual(e[1].clipe, "RecargaInicio", "primeira etapa")
util.igual(e[2].clipe, "RecargaCartucho", "cartucho")
util.igual(e[5].clipe, "RecargaFim", "última etapa")
util.perto(e[2].inicio, 0.5, "cartucho 1 começa depois do início")
util.perto(e[5].inicio, 0.5 + 0.55 * 3, "fim começa depois dos cartuchos")
local zero = BracosVista.etapasTubo(0.5, 0.55, 0.4, 0.9)
util.igual(#zero, 2, "sem cartuchos: só início e fim")

-- compensação de FOV
util.perto(BracosVista.compensarFov(70, 70), 1, "mesmo FOV")
assert(BracosVista.compensarFov(78, 70) > 1, "FOV maior afasta do centro")
assert(BracosVista.compensarFov(60, 70) < 1, "FOV menor aproxima do centro")
util.perto(BracosVista.compensarFov(0, 70), 1, "FOV inválido")

-- IK da mão esquerda
local regras = { desligar = { Equip = true, Reload = true }, janelas = { Fire = { 0.2, 0.58 } } }
assert(BracosVista.ikDesejado(regras, true, nil, 0), "duas mãos parado: IK ligado")
assert(not BracosVista.ikDesejado(regras, false, nil, 0), "uma mão: sem IK")
assert(not BracosVista.ikDesejado(regras, true, "Reload", 0.5), "recarga anima a mão: IK desligado")
assert(BracosVista.ikDesejado(regras, true, "Fire", 0.1), "antes da janela do tiro: IK ligado")
assert(not BracosVista.ikDesejado(regras, true, "Fire", 0.3), "dentro da janela: IK desligado")
assert(BracosVista.ikDesejado(regras, true, "Fire", 0.7), "depois da janela: IK ligado")
assert(BracosVista.ikDesejado(nil, true, "Fire", 0.3), "sem regras da classe: ligado")

print("BracosVista.spec ok")
