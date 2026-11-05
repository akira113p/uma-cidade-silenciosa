local util = require("./util")
local Combustivel = require("../src/shared/Regras/Combustivel")
local Veiculo = require("../src/shared/Regras/Veiculo")
local cfg = require("../src/shared/Config/Combustivel")
local cfgVeiculos = require("../src/shared/Config/Veiculos")
local cfgItens = require("../src/shared/Config/Itens")

local TANQUE = 55

-- consumo: parado < máximo; velMax com pedal a fundo = tanque / autonomiaMaxSeg; parado = tanque / autonomiaParadoSeg
local parado = Combustivel.consumoLps(TANQUE, 0, 0, cfg)
local maximo = Combustivel.consumoLps(TANQUE, 1, 1, cfg)
util.perto(parado, TANQUE / cfg.autonomiaParadoSeg, "consumo parado", 1e-9)
util.perto(maximo, TANQUE / cfg.autonomiaMaxSeg, "consumo na velMax", 1e-9)
util.igual(parado < maximo, true, "parado consome menos que a velMax")
util.perto(Combustivel.consumoLps(TANQUE, 0, 1, cfg), parado, "acelerar parado consome só o parado", 1e-9)
util.igual(Combustivel.consumoLps(TANQUE, 1, 0, cfg) < maximo, true, "velMax sem pedal consome menos que com pedal")
util.igual(Combustivel.consumoLps(TANQUE, 1, 0, cfg) > parado, true, "velMax sem pedal consome mais que parado")
util.perto(Combustivel.consumoLps(TANQUE, 1, -1, cfg), maximo, "pedal negativo (ré/freio) conta pelo módulo", 1e-9)
util.perto(Combustivel.consumoLps(TANQUE, 5, 9, cfg), maximo, "fracVel e pedal têm teto", 1e-9)
util.perto(Combustivel.consumoLps(TANQUE, -3, 0, cfg), parado, "fracVel negativa vale 0", 1e-9)
util.igual(
	Combustivel.consumoLps(TANQUE, 0.8, 1, cfg) > Combustivel.consumoLps(TANQUE, 0.4, 1, cfg),
	true,
	"consumo cresce com a velocidade"
)
-- tanque maior gasta mais litros, mas dura o mesmo tempo
util.perto(
	Combustivel.consumoLps(80, 1, 1, cfg) / 80,
	Combustivel.consumoLps(40, 1, 1, cfg) / 40,
	"autonomia independe do tanque",
	1e-9
)

-- consumir: duração em segundos bate com a autonomia e nunca passa de 0
util.perto(
	Combustivel.consumir(TANQUE, cfg.autonomiaParadoSeg, TANQUE, 0, 0, cfg),
	0,
	"tanque cheio parado acaba na autonomia parado",
	1e-6
)
util.perto(
	Combustivel.consumir(TANQUE, cfg.autonomiaMaxSeg, TANQUE, 1, 1, cfg),
	0,
	"tanque cheio na velMax acaba na autonomia máxima",
	1e-6
)
util.perto(Combustivel.consumir(TANQUE, 10, TANQUE, 0, 0, cfg), TANQUE - parado * 10, "consumir 10 s parado", 1e-9)
util.igual(Combustivel.consumir(0.001, 100, TANQUE, 1, 1, cfg), 0, "consumir não passa de 0")
util.igual(Combustivel.consumir(0, 1, TANQUE, 1, 1, cfg), 0, "vazio continua vazio")
util.igual(Combustivel.consumir(20, -5, TANQUE, 1, 1, cfg), 20, "dt negativo não devolve gasolina")
util.igual(Combustivel.consumir(20, 0 / 0, TANQUE, 1, 1, cfg), 20, "dt NaN não muda o nível")

-- encher: aceita até o tanque, o resto é sobra
local novo, aceito, sobra = Combustivel.encher(10, TANQUE, 5)
util.perto(novo, 15, "encher: novo nível")
util.perto(aceito, 5, "encher: aceito")
util.perto(sobra, 0, "encher: sem sobra")
novo, aceito, sobra = Combustivel.encher(52, TANQUE, 5)
util.perto(novo, TANQUE, "encher com sobra: tanque cheio")
util.perto(aceito, 3, "encher com sobra: aceito")
util.perto(sobra, 2, "encher com sobra: sobra")
novo, aceito, sobra = Combustivel.encher(TANQUE, TANQUE, 5)
util.perto(aceito, 0, "tanque cheio não aceita nada")
util.perto(sobra, 5, "tanque cheio: tudo sobra")
novo, aceito, sobra = Combustivel.encher(10, TANQUE, -4)
util.perto(novo, 10, "quantidade negativa não tira gasolina")
util.perto(aceito + sobra, 0, "quantidade negativa: nada aceito nem sobra")
novo, aceito, sobra = Combustivel.encher(0, TANQUE, 0.5)
util.perto(novo, 0.5, "encher vazio com garrafa")
util.perto(aceito + sobra, 0.5, "aceito + sobra = quantidade")

-- fracao e reserva
util.perto(Combustivel.fracao(27.5, 55), 0.5, "fração")
util.igual(Combustivel.fracao(100, 55), 1, "fração tem teto 1")
util.igual(Combustivel.fracao(-3, 55), 0, "fração tem piso 0")
util.igual(Combustivel.fracao(5, 0), 0, "tanque 0 não divide por zero")
util.igual(Combustivel.reserva(TANQUE * cfg.fracaoReserva, TANQUE, cfg), true, "reserva no limite")
util.igual(Combustivel.reserva(0, TANQUE, cfg), true, "vazio está na reserva")
util.igual(Combustivel.reserva(TANQUE * (cfg.fracaoReserva + 0.05), TANQUE, cfg), false, "acima da reserva")
util.igual(Combustivel.reserva(TANQUE, TANQUE, cfg), false, "cheio não está na reserva")

-- recipientes: cada item "recipiente" tem entrada no Config e vice-versa; enche/despeja fecham o ciclo
for id, def in cfgItens.itens do
	if def.tipo == "recipiente" then
		util.igual(Combustivel.recipiente(id, cfg) ~= nil, true, "item recipiente com entrada no Config: " .. id)
	end
end
for id, r in cfg.recipientes do
	local item = cfgItens.itens[id]
	util.igual(item ~= nil and item.tipo == "recipiente", true, "entrada do Config é item recipiente: " .. id)
	util.igual((r.capacidade == nil) ~= (r.litros == nil), true, "vazio tem capacidade ou cheio tem litros: " .. id)
	local alvo = r.enche or r.despeja
	util.igual(alvo ~= nil and cfg.recipientes[alvo] ~= nil, true, "troca aponta para recipiente conhecido: " .. id)
	if r.enche then
		local cheio = cfg.recipientes[r.enche]
		util.igual(cheio.despeja, id, "despeja volta ao vazio: " .. id)
		util.perto(cheio.litros, r.capacidade, "litros do cheio = capacidade do vazio: " .. id)
	end
end
util.igual(Combustivel.recipiente("enlatado", cfg), nil, "item comum não é recipiente")
util.igual(Combustivel.trocarRecipiente("galaoVazio", cfg, "encher"), "galaoGasolina", "encher galão")
util.igual(Combustivel.trocarRecipiente("galaoGasolina", cfg, "despejar"), "galaoVazio", "despejar galão")
util.igual(Combustivel.trocarRecipiente("garrafaVazia", cfg, "encher"), "garrafaGasolina", "encher garrafa")
util.igual(Combustivel.trocarRecipiente("garrafaGasolina", cfg, "despejar"), "garrafaVazia", "despejar garrafa")
util.igual(Combustivel.trocarRecipiente("galaoVazio", cfg, "despejar"), nil, "vazio não despeja")
util.igual(Combustivel.trocarRecipiente("galaoGasolina", cfg, "encher"), nil, "cheio não enche")
util.igual(Combustivel.trocarRecipiente("enlatado", cfg, "encher"), nil, "não recipiente")
util.igual(Combustivel.trocarRecipiente("galaoVazio", cfg, "beber"), nil, "ação desconhecida")

-- tampa do carro: valores existem e são números
local t = cfg.carro.tampa
util.igual(type(t.fx) == "number" and type(t.fy) == "number" and type(t.fz) == "number", true, "tampa: fx, fy, fz")
util.igual(type(t.saliencia) == "number" and t.saliencia >= 0, true, "tampa: saliência")
util.igual(
	#t.tamanho == 3 and t.tamanho[1] > 0 and t.tamanho[2] > 0 and t.tamanho[3] > 0,
	true,
	"tampa: tamanho 3 eixos"
)
util.igual(t.fx < 0, true, "tampa no lado esquerdo (-X)")
util.igual(t.fz > 0, true, "tampa na metade de trás (+Z)")
util.igual(cfg.carro.etiquetaDistancia > 0, true, "etiqueta com distância")

-- números do Config coerentes
util.igual(cfg.autonomiaParadoSeg > cfg.autonomiaMaxSeg, true, "parado dura mais que na velMax")
util.igual(cfg.fracaoReserva > 0 and cfg.fracaoReserva < 1, true, "reserva entre 0 e 1")
util.igual(cfg.mangueira.segmentos >= 2 and cfg.mangueira.comprimento > 0, true, "mangueira válida")
util.igual(cfg.mangueira.vazaoLps > 0, true, "vazão positiva")

-- todo tipo de carro tem tanque, e o sorteio do mapa respeita o Config de Veiculos
for nome, tipo in cfgVeiculos.tipos do
	util.igual(type(tipo.tanque) == "number" and tipo.tanque > 0, true, "tipo com tanque: " .. nome)
end
local gas = cfgVeiculos.condicoes.combustivel
local rng = util.rng(11)
local vazios, cheios = 0, 0
for _ = 1, 400 do
	local e = Veiculo.sortear("pickup", rng, cfgVeiculos)
	util.igual(
		e.combustivel >= 0 and e.combustivel <= cfgVeiculos.tipos.pickup.tanque,
		true,
		"sortear: dentro do tanque"
	)
	if e.combustivel == 0 then
		vazios += 1
	else
		cheios += 1
		util.igual(
			e.combustivel >= gas.min * 80 - 1e-9 and e.combustivel <= gas.max * 80 + 1e-9,
			true,
			"sortear: faixa min..max"
		)
	end
end
util.igual(vazios > 0 and cheios > 0, true, "sortear: às vezes vazio, às vezes com gasolina")
-- rng sempre 0: condição "inteiro" e sorteio abaixo de chanceVazio -> nasce vazio
local seco = Veiculo.sortear("sedan", util.seq({ 0 }), cfgVeiculos)
util.igual(seco.condicao == "inteiro" and seco.combustivel == 0, true, "rng baixo: carro nasce vazio")
-- carro queimado nasce sempre vazio, mesmo com sorteio de gasolina alto
local queimados = 0
for _ = 1, 400 do
	local e = Veiculo.sortear("sedan", rng, cfgVeiculos)
	if e.queimado then
		queimados += 1
		util.igual(e.combustivel, 0, "queimado nasce vazio")
	end
end
util.igual(queimados > 0, true, "amostra teve carro queimado")

print("Combustivel.spec ok")
