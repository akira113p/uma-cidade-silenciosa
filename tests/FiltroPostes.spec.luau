local util = require("./util")
local Regras = require("../src/shared/Regras/FiltroPostes")
local cfg = require("../src/shared/Config/Filtro/Postes")

-- proporções num lote grande de posições (grade 20000 postes)
local total, quebradas, piscam = 0, 0, 0
for i = 0, 199 do
	for j = 0, 99 do
		local x, z = i * 13.7 - 1300, j * 9.3 - 450
		local e = Regras.estadoLampada(x, z, cfg)
		assert(e == "normal" or e == "pisca" or e == "quebrada", "estado válido")
		total += 1
		if e == "quebrada" then
			quebradas += 1
		elseif e == "pisca" then
			piscam += 1
		end
	end
end
util.perto(quebradas / total, cfg.fracaoQuebrada, "proporção quebrada", 0.015)
util.perto(piscam / total, cfg.fracaoPisca, "proporção pisca", 0.015)

-- determinismo
for k = 1, 50 do
	local x, z = k * 3.3 - 70, k * -7.1
	util.igual(Regras.estadoLampada(x, z, cfg), Regras.estadoLampada(x, z, cfg), "estado determinístico")
	util.igual(Regras.brilhoPisca(k * 0.37, x, z), Regras.brilhoPisca(k * 0.37, x, z), "brilho determinístico")
end

-- frações extremas
util.igual(Regras.estadoLampada(5, 5, { fracaoQuebrada = 0, fracaoPisca = 0 }), "normal", "sem defeitos")
util.igual(Regras.estadoLampada(5, 5, { fracaoQuebrada = 1, fracaoPisca = 0 }), "quebrada", "todas quebradas")
util.igual(Regras.estadoLampada(5, 5, { fracaoQuebrada = 0, fracaoPisca = 1 }), "pisca", "todas piscam")

-- brilho entre 0 e 1, varia no tempo, e mais da metade do tempo está aceso
local aceso, n, minimo, maximo = 0, 0, 1, 0
for k = 0, 5999 do
	local b = Regras.brilhoPisca(k * 0.05, 120.5, -33)
	assert(b >= 0 and b <= 1, "brilho fora de 0..1")
	minimo, maximo = math.min(minimo, b), math.max(maximo, b)
	n += 1
	if b > 0.5 then
		aceso += 1
	end
end
assert(minimo < 0.5 and maximo == 1, "brilho varia")
assert(aceso / n > 0.6, "pisca fica aceso na maior parte do tempo")
-- postes diferentes não piscam em sincronia
local difere = false
for k = 0, 200 do
	if Regras.brilhoPisca(k * 0.1, 10, 10) ~= Regras.brilhoPisca(k * 0.1, 400, -90) then
		difere = true
	end
end
assert(difere, "postes dessincronizados")

-- maisPerto
local d = { 50, 10, 30, 10, 99 }
local r = Regras.maisPerto(d, 3)
util.igual(#r, 3, "maisPerto tamanho")
util.igual(r[1], 2, "empate: índice menor primeiro")
util.igual(r[2], 4, "empate: segundo")
util.igual(r[3], 3, "terceiro")
util.igual(#Regras.maisPerto(d, 20), 5, "n maior que a lista devolve todos")
util.igual(#Regras.maisPerto({}, 4), 0, "lista vazia")
util.igual(#Regras.maisPerto(d, 0), 0, "n 0")
util.igual(d[1], 50, "não altera a entrada")

-- fades do cone
util.perto(Regras.fatorProximidadeCone(0, 9, 22), 0, "proximidade no eixo")
util.perto(Regras.fatorProximidadeCone(9, 9, 22), 0, "proximidade em perto")
util.perto(Regras.fatorProximidadeCone(15.5, 9, 22), 0.5, "proximidade no meio")
util.perto(Regras.fatorProximidadeCone(22, 9, 22), 1, "proximidade em longe")
util.perto(Regras.fatorProximidadeCone(80, 9, 22), 1, "proximidade além")
util.perto(Regras.fatorAnguloCone(0, 0.55, 0.85), 1, "angulo horizontal")
util.perto(Regras.fatorAnguloCone(0.55, 0.55, 0.85), 1, "angulo em minimo")
util.perto(Regras.fatorAnguloCone(0.7, 0.55, 0.85), 0.5, "angulo no meio")
util.perto(Regras.fatorAnguloCone(0.85, 0.55, 0.85), 0, "angulo em maximo")
util.perto(Regras.fatorAnguloCone(-1, 0.55, 0.85), 0, "angulo olhando para baixo (sinal)")

print("FiltroPostes.spec ok")
