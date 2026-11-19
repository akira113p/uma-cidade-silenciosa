local util = require("./util")
local Veiculo = require("../src/shared/Regras/Veiculo")
local cfg = require("../src/shared/Config/Veiculos")

-- Tipos e condições do Config
for nome, t in cfg.tipos do
	util.igual(t.modelo ~= nil and t.massa > 0 and t.velMax > 0 and t.assentos >= 2, true, "tipo completo " .. nome)
end
util.igual(cfg.condicoes.inteiro.peso < cfg.condicoes.avariado.peso, true, "inteiro é raro")

-- sortear: cada condição respeita o Config, em muitas sementes
local contagem = { inteiro = 0, avariado = 0, destruido = 0, queimado = 0 }
local rngLongo = util.rng(7) -- um só rng: sementes sequenciais dão primeiros valores correlacionados
for _ = 1, 400 do
	local e = Veiculo.sortear("sedan", rngLongo, cfg)
	local c = cfg.condicoes[e.condicao]
	contagem[e.condicao] += 1
	util.igual(e.motor == 0 or (e.motor >= c.motor[1] and e.motor <= c.motor[2]), true, "motor na faixa " .. e.condicao)
	util.igual(e.carroceria >= c.carroceria[1] and e.carroceria <= c.carroceria[2], true, "carroceria na faixa")
	util.igual(e.queimado, c.queimado, "queimado do Config")
	if e.condicao == "inteiro" then
		util.igual(e.pneus.FE ~= "faltando" and e.vidros.ParaBrisa ~= "faltando", true, "inteiro sem peça faltando")
	end
	if e.queimado then
		util.igual(Veiculo.podeDirigir(e), false, "queimado não dirige")
		util.igual(e.pneus.FE, "faltando", "queimado sem pneu")
	end
end
util.igual(contagem.inteiro < contagem.avariado and contagem.inteiro < contagem.destruido, true, "inteiro raro")

-- determinismo
local a = Veiculo.sortear("suv", util.rng(5), cfg)
local b = Veiculo.sortear("suv", util.rng(5), cfg)
util.igual(
	a.motor == b.motor and a.condicao == b.condicao and a.pneus.TD == b.pneus.TD,
	true,
	"mesmo rng, mesmo estado"
)

local function bom(): any
	return {
		tipo = "sedan",
		condicao = "inteiro",
		queimado = false,
		motor = 100,
		carroceria = 100,
		pneus = { FE = "ok", FD = "ok", TE = "ok", TD = "ok" },
		vidros = { ParaBrisa = "ok", Traseiro = "ok", JanelaE = "ok", JanelaD = "ok" },
		faltando = {},
		amassado = { Frente = false, Tras = false, Esquerda = false, Direita = false },
		combustivel = 30,
	}
end

-- podeLigar e gasolina: sem gasolina não liga e não gasta sorteio
util.igual(Veiculo.podeLigar(bom()), true, "podeLigar: inteiro com gasolina")
local seco = bom()
seco.combustivel = 0
util.igual(Veiculo.podeLigar(seco), false, "podeLigar: sem gasolina")
local fioDeGas = bom()
fioDeGas.combustivel = 0.01
util.igual(Veiculo.podeLigar(fioDeGas), true, "podeLigar: com um fio de gasolina")
local queimGas = bom()
queimGas.queimado = true
util.igual(Veiculo.podeLigar(queimGas), false, "podeLigar: queimado com gasolina")
local chamadas = 0
local rngContado = function()
	chamadas += 1
	return 0
end
util.igual(Veiculo.tentarLigar(seco, rngContado, cfg), false, "tentarLigar: sem gasolina não liga")
util.igual(chamadas, 0, "tentarLigar: sem gasolina não gasta sorteio")
util.igual(Veiculo.tentarLigar(bom(), rngContado, cfg), true, "tentarLigar: com gasolina liga")
util.igual(chamadas, 1, "tentarLigar: com gasolina gasta 1 sorteio")

-- ligar
local zero = bom()
zero.motor = 0
util.igual(Veiculo.tentarLigar(zero, util.seq({ 0 }), cfg), false, "motor 0 nunca liga")
local queim = bom()
queim.queimado = true
util.igual(Veiculo.tentarLigar(queim, util.seq({ 0 }), cfg), false, "queimado nunca liga")
util.igual(Veiculo.tentarLigar(bom(), util.seq({ 0.5 }), cfg), true, "motor bom liga")
local fraco = bom()
fraco.motor = 10
util.igual(Veiculo.tentarLigar(fraco, util.seq({ 0.9 }), cfg), false, "motor fraco falha com rng alto")

-- limites
local l0 = Veiculo.limites(bom(), cfg)
util.perto(l0.velMax, cfg.tipos.sedan.velMax, "velMax inteiro")
util.perto(l0.puxa, 0, "sem puxão")
local um = bom()
um.pneus.FE = "furado"
local l1 = Veiculo.limites(um, cfg)
util.igual(l1.velMax < l0.velMax, true, "furado reduz velMax")
util.igual(l1.puxa < 0, true, "pneu esquerdo ruim puxa para a esquerda")
util.igual(l1.aderencia < l0.aderencia, true, "furado reduz aderência")
local falta = bom()
falta.pneus.FE = "faltando"
util.igual(Veiculo.limites(falta, cfg).velMax < l1.velMax, true, "faltando reduz mais que furado")
local dir = bom()
dir.pneus.TD = "furado"
util.igual(Veiculo.limites(dir, cfg).puxa > 0, true, "pneu direito ruim puxa para a direita")
local todos = bom()
for k in todos.pneus do
	todos.pneus[k] = "faltando"
end
util.igual(Veiculo.limites(todos, cfg).velMax > 0, true, "velMax nunca zera")
util.igual(math.abs(Veiculo.limites(todos, cfg).puxa) <= 1, true, "puxa limitado")
local fracoM = bom()
fracoM.motor = 20
util.igual(Veiculo.limites(fracoM, cfg).velMax < l0.velMax, true, "motor ruim reduz velMax")

-- dbMotor
local ocioso = Veiculo.dbMotor(bom(), 0, cfg)
local maximo = Veiculo.dbMotor(bom(), 1, cfg)
util.igual(maximo > ocioso, true, "mais rápido, mais alto")
util.igual(Veiculo.dbMotor(fracoM, 0, cfg) > ocioso, true, "motor ruim faz mais barulho")

-- direcaoBatida
util.igual(Veiculo.direcaoBatida(0, -3), "Frente", "frente")
util.igual(Veiculo.direcaoBatida(0.5, 3), "Tras", "trás")
util.igual(Veiculo.direcaoBatida(-3, 0.5), "Esquerda", "esquerda")
util.igual(Veiculo.direcaoBatida(3, -0.5), "Direita", "direita")

-- bater
local e0 = bom()
local fraca, rf = Veiculo.bater(e0, cfg.batida.limiarDeltaV - 1, "Frente", util.seq({ 0 }), cfg)
util.igual(fraca, e0, "batida fraca devolve a mesma entrada")
util.igual(#rf.vidros + #rf.pneus, 0, "batida fraca sem resultado")
util.igual(rf.amassou, nil, "batida fraca não amassa")
local forte, rs = Veiculo.bater(e0, 50, "Frente", util.seq({ 0 }), cfg)
util.igual(e0.carroceria, 100, "entrada não mutada (carroceria)")
util.igual(e0.vidros.ParaBrisa, "ok", "entrada não mutada (vidro)")
util.igual(e0.amassado.Frente, false, "entrada não mutada (amassado)")
util.igual(forte.carroceria < 100, true, "carroceria cai")
util.igual(forte.vidros.ParaBrisa, "quebrado", "para-brisa quebra")
util.igual(rs.amassou, "Frente", "amassou a frente")
util.igual(forte.pneus.FE, "furado", "pneu da frente fura")
util.igual(forte.pneus.TE, "ok", "pneu de trás intacto")
util.igual(forte.motor < 100 and not rs.motorQuebrou, true, "motor bom só estraga na batida")
local fm = bom()
fm.motor = 30
local _, rmq = Veiculo.bater(fm, 50, "Frente", util.seq({ 0 }), cfg)
util.igual(rmq.motorQuebrou, true, "motor fraco quebra na frente")
local _, r2 = Veiculo.bater(forte, 50, "Frente", util.seq({ 0 }), cfg)
util.igual(#r2.vidros + #r2.pneus, 0, "o que já quebrou não quebra de novo")
util.igual(r2.amassou, nil, "lado já amassado")

-- acertar
local _, rp = Veiculo.acertar(bom(), "Pneu_FE", 20, util.seq({ 0 }), cfg)
util.igual(rp.pneus[1], "FE", "tiro fura pneu")
local ev = bom()
ev.vidros.ParaBrisa = "quebrado"
local sv, rv = Veiculo.acertar(ev, "Vidro_ParaBrisa", 50, util.seq({ 0 }), cfg)
util.igual(#rv.vidros, 0, "vidro quebrado não gera resultado")
util.igual(sv.vidros.ParaBrisa, "quebrado", "vidro continua quebrado")
local ev2, rv2 = Veiculo.acertar(bom(), "Vidro_Traseiro", 20, util.seq({ 0 }), cfg)
util.igual(rv2.vidros[1], "Traseiro", "tiro quebra vidro")
util.igual(ev2.vidros.Traseiro, "quebrado", "vidro quebrado")
local ep = bom()
ep.pneus.FE = "faltando"
local _, rpf = Veiculo.acertar(ep, "Pneu_FE", 50, util.seq({ 0 }), cfg)
util.igual(#rpf.pneus, 0, "pneu faltando não fura")
local sm, rm = Veiculo.acertar(bom(), "Motor", 500, util.seq({ 0 }), cfg)
util.igual(sm.motor, 0, "motor destruído")
util.igual(rm.motorQuebrou, true, "motorQuebrou")
local sc = Veiculo.acertar(bom(), "Carroceria", 10, util.seq({ 0 }), cfg)
util.igual(sc.carroceria < 100, true, "carroceria leva dano")
util.igual(Veiculo.acertar(e0, "Banco", 10, util.seq({ 0 }), cfg), e0, "peça desconhecida não muda")

-- danoOcupante
util.igual(Veiculo.danoOcupante(cfg.batida.limiarDeltaV - 1, cfg), 0, "sem dano abaixo do limiar")
util.igual(Veiculo.danoOcupante(60, cfg) > Veiculo.danoOcupante(30, cfg), true, "dano cresce com deltaV")
util.igual(Veiculo.danoOcupante(10000, cfg) <= cfg.batida.danoOcupante.maximo, true, "dano tem teto")

-- montar (menu de admin): padrão perfeito, validação e queimado
local m0 = Veiculo.montar("sedan", nil, cfg)
util.igual(
	m0 ~= nil and m0.motor == 100 and m0.carroceria == 100 and not m0.queimado,
	true,
	"montar sem pedido = perfeito"
)
util.igual(
	m0 ~= nil and m0.pneus.FE == "ok" and m0.vidros.JanelaE == "ok" and m0.faltando.Capo == false,
	true,
	"montar: nada quebrado"
)
util.igual(Veiculo.montar("nave", {}, cfg), nil, "montar: tipo desconhecido")
util.igual(Veiculo.montar(5, {}, cfg), nil, "montar: tipo não string")
local m1 = Veiculo.montar("pickup", {
	motor = -30,
	carroceria = 250,
	pneus = { FE = "furado", TD = "faltando", FD = "explodido" },
	vidros = { ParaBrisa = "quebrado", JanelaD = "faltando", Traseiro = 7 },
	faltando = { Capo = true, PortaE = "sim", Banco = true },
}, cfg)
util.igual(m1 ~= nil and m1.motor == 0 and m1.carroceria == 100, true, "montar: números com clamp")
util.igual(
	m1 ~= nil and m1.pneus.FE == "furado" and m1.pneus.TD == "faltando" and m1.pneus.FD == "ok",
	true,
	"montar: pneus"
)
util.igual(m1 ~= nil and m1.vidros.ParaBrisa == "quebrado" and m1.vidros.JanelaD == "faltando", true, "montar: vidros")
util.igual(m1 ~= nil and m1.vidros.Traseiro == "ok", true, "montar: vidro inválido vira ok")
util.igual(m1 ~= nil and m1.faltando.Capo == true and m1.faltando.PortaE == false, true, "montar: só true vale")
util.igual(m1 ~= nil and m1.faltando.Banco == nil, true, "montar: peça desconhecida ignorada")
local m2 = Veiculo.montar("van", { queimado = true, motor = 90 }, cfg)
util.igual(
	m2 ~= nil and m2.queimado and m2.motor == 0 and m2.condicao == "queimado",
	true,
	"montar: queimado zera o motor"
)
util.igual(m2 ~= nil and Veiculo.podeDirigir(m2), false, "montar: queimado não dirige")
local m3 = Veiculo.montar("suv", { motor = "alto", pneus = "todos" }, cfg)
util.igual(m3 ~= nil and m3.motor == 100 and m3.pneus.FE == "ok", true, "montar: tipos errados viram padrão")

-- combustível: tanque por tipo, sortear, montar, copiar
for nome, t in cfg.tipos do
	util.igual(type(t.tanque) == "number" and t.tanque > 0, true, "tipo com tanque " .. nome)
end
util.igual(cfg.condicoes.combustivel.min < cfg.condicoes.combustivel.max, true, "faixa de gasolina válida")
util.igual(cfg.teclas.trocarBanco[1], "F", "tecla de trocar de banco")
local rngGas = util.rng(21)
local nomesTipos = { "sedan", "compacto", "suv", "pickup", "van", "esportivo" }
local secos, comGas = 0, 0
for _ = 1, 400 do
	local tipo = nomesTipos[math.floor(rngGas() * #nomesTipos) + 1]
	local e = Veiculo.sortear(tipo, rngGas, cfg)
	util.igual(
		e.combustivel >= 0 and e.combustivel <= cfg.tipos[tipo].tanque,
		true,
		"sortear: gasolina dentro do tanque"
	)
	if e.combustivel == 0 then
		secos += 1
	else
		comGas += 1
		util.igual(
			e.combustivel <= cfg.tipos[tipo].tanque * cfg.condicoes.combustivel.max + 1e-9,
			true,
			"sortear: não passa do máximo do Config"
		)
		util.igual(e.queimado, false, "sortear: queimado nunca tem gasolina")
	end
end
util.igual(secos > 0 and comGas > 0, true, "sortear: às vezes vazio")
local mg0 = Veiculo.montar("sedan", nil, cfg)
util.igual(mg0 ~= nil and mg0.combustivel == cfg.tipos.sedan.tanque, true, "montar sem pedido: tanque cheio")
local mg1 = Veiculo.montar("van", { combustivel = 0.5 }, cfg)
util.perto(mg1 and mg1.combustivel or -1, cfg.tipos.van.tanque * 0.5, "montar: meio tanque")
local mg2 = Veiculo.montar("van", { combustivel = 0 }, cfg)
util.igual(mg2 ~= nil and mg2.combustivel == 0 and not Veiculo.podeLigar(mg2), true, "montar: vazio não liga")
local mg3 = Veiculo.montar("suv", { combustivel = 7 }, cfg)
util.igual(mg3 ~= nil and mg3.combustivel == cfg.tipos.suv.tanque, true, "montar: fração acima de 1 vira cheio")
local mg4 = Veiculo.montar("suv", { combustivel = -1 }, cfg)
util.igual(mg4 ~= nil and mg4.combustivel == 0, true, "montar: fração negativa vira vazio")
local mg5 = Veiculo.montar("suv", { combustivel = "cheio" }, cfg)
util.igual(mg5 ~= nil and mg5.combustivel == cfg.tipos.suv.tanque, true, "montar: tipo errado vira cheio")
local mg6 = Veiculo.montar("suv", { combustivel = 0 / 0 }, cfg)
util.igual(mg6 ~= nil and mg6.combustivel == cfg.tipos.suv.tanque, true, "montar: NaN vira cheio")
local mg7 = Veiculo.montar("suv", { queimado = true, combustivel = 1 }, cfg)
util.igual(mg7 ~= nil and mg7.combustivel == 0, true, "montar: queimado nasce vazio")
-- bater/acertar copiam o estado: a gasolina sobrevive à cópia
local batido = Veiculo.bater(bom(), 50, "Frente", util.seq({ 0 }), cfg)
util.igual(batido.combustivel, 30, "bater preserva a gasolina (copiar)")
local atirado = Veiculo.acertar(bom(), "Carroceria", 10, util.seq({ 0 }), cfg)
util.igual(atirado.combustivel, 30, "acertar preserva a gasolina (copiar)")

-- Condução dinâmica / freio de mão / derrapagem (2026-11-14)
-- guinadaAlvo: direita (ângulo +) gira negativo; ré inverte; freio de mão exagera; teto respeitado
util.igual(Veiculo.guinadaAlvo(0, 40, 10, 1, 2.6), 0, "guinada: rodas retas, sem giro")
util.igual(
	Veiculo.guinadaAlvo(20, 30, 10, 1, 9) < 0,
	true,
	"guinada: volante à direita gira para a direita (negativo)"
)
util.igual(Veiculo.guinadaAlvo(-20, 30, 10, 1, 9) > 0, true, "guinada: volante à esquerda gira positivo")
util.igual(Veiculo.guinadaAlvo(20, -30, 10, 1, 9) > 0, true, "guinada: ré inverte o giro")
util.perto(
	Veiculo.guinadaAlvo(20, 30, 10, 1.4, 9),
	Veiculo.guinadaAlvo(20, 30, 10, 1, 9) * 1.4,
	"guinada: o fator do freio de mão multiplica o giro"
)
util.igual(Veiculo.guinadaAlvo(34, 80, 4, 1.4, 2.6), -2.6, "guinada: respeita o teto")
util.igual(
	Veiculo.guinadaAlvo(20, 30, 0, 1, 99) == Veiculo.guinadaAlvo(20, 30, 1, 1, 99),
	true,
	"guinada: entre-eixos 0 não divide por zero"
)
-- contraVolante: nada abaixo do limiar, cresce depois, vira para o lado da deriva, teto
util.igual(Veiculo.contraVolante(2, 3, 0.45, 14), 0, "contraVolante: abaixo do limiar não corrige")
util.igual(Veiculo.contraVolante(-3, 3, 0.45, 14), 0, "contraVolante: no limiar não corrige")
util.perto(Veiculo.contraVolante(7, 3, 0.5, 14), 2, "contraVolante: cresce a partir do limiar")
util.perto(Veiculo.contraVolante(-7, 3, 0.5, 14), -2, "contraVolante: deriva para a esquerda, volante para a esquerda")
util.igual(Veiculo.contraVolante(500, 3, 0.45, 14), 14, "contraVolante: respeita o teto")
-- derrapando: precisa de velocidade E deslize
util.igual(Veiculo.derrapando(30, 15, cfg), true, "derrapando: rápido e de lado")
util.igual(Veiculo.derrapando(30, -15, cfg), true, "derrapando: deslize para a esquerda também conta")
util.igual(Veiculo.derrapando(30, 2, cfg), false, "derrapando: sem deslize não")
util.igual(Veiculo.derrapando(3, 15, cfg), false, "derrapando: devagar não")
-- Config novo
util.igual(table.find(cfg.teclas.freioMao, "LeftShift") ~= nil, true, "Config: freio de mão no Shift")
util.igual(cfg.teclas.farol[1], "L", "Config: farol no L")
util.igual(
	cfg.farol.angulo > 0 and cfg.farol.alcance <= 60 and cfg.farol.brilho > 0,
	true,
	"Config: farol válido (Range <= 60)"
)
util.igual(
	cfg.derrapagem.intervalo > 0 and cfg.derrapagem.velMin > 0 and cfg.derrapagem.deslizeMin > 0,
	true,
	"Config: derrapagem válida"
)
