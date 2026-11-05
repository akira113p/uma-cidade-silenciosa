local util = require("./util")
local Filtro = require("../src/shared/Regras/Filtro")
local geral = require("../src/shared/Config/Filtro/Geral")

-- mistura
util.perto(Filtro.mistura(2, 6, 0.5), 4, "mistura meio")
util.perto(Filtro.mistura(2, 6, -1), 2, "mistura f<0 limitado")
util.perto(Filtro.mistura(2, 6, 5), 6, "mistura f>1 limitado")

-- decair
util.perto(Filtro.decair(1, 0.5, 0.5), 0.5, "meia-vida")
util.perto(Filtro.decair(1, 1, 0.5), 0.25, "duas meias-vidas")
util.perto(Filtro.decair(0.8, 0, 0.5), 0.8, "dt 0 mantém")
util.perto(Filtro.decair(0.8, 1, 0), 0, "meia-vida 0 zera")
util.perto(Filtro.decair(-1, 1, 1), 0, "negativo vira 0")
util.perto(Filtro.suavizar(0, 1, 0.4, 0.4), 0.5, "suavizar meia-vida")
util.perto(Filtro.suavizar(0.3, 1, 0, 0.4), 0.3, "suavizar dt 0")

-- quadroGrao: dentro de 1..n, igual no mesmo quadro, nunca repete o anterior
local visto = {}
local anterior = 0
for k = 0, 5000 do
	local q = Filtro.quadroGrao((k + 0.5) / 13, 13, 4)
	assert(q >= 1 and q <= 4 and q == math.floor(q), "quadro fora de 1..4: " .. q)
	assert(q ~= anterior, "quadroGrao repetiu o anterior no quadro " .. k)
	anterior = q
	visto[q] = true
end
for q = 1, 4 do
	assert(visto[q], "quadro nunca usado: " .. q)
end
util.igual(Filtro.quadroGrao(1.01, 13, 4), Filtro.quadroGrao(1.02, 13, 4), "mesmo quadro")
util.igual(Filtro.quadroGrao(3, 0, 4), 1, "fps 0 evitado")
util.igual(Filtro.quadroGrao(3, 13, 1), 1, "um quadro só")
util.igual(Filtro.quadroGrao(0 / 0, 13, 4), 1, "t NaN")
for k = 0, 200 do
	local q = Filtro.quadroGrao(k / 10, 10, 3)
	assert(q >= 1 and q <= 3, "n=3 fora da faixa")
end

-- deslocGrao
for k = 0, 500 do
	local x, y = Filtro.deslocGrao(k / 13 + 0.01, 13, 256)
	assert(x >= 0 and x < 256 and y >= 0 and y < 256, "desloc fora de 0..255")
end
local ax, ay = Filtro.deslocGrao(2.01, 13, 256)
local bx, by = Filtro.deslocGrao(2.02, 13, 256)
assert(ax == bx and ay == by, "desloc igual no mesmo quadro")
local diferentes = 0
for k = 0, 99 do
	local x1, y1 = Filtro.deslocGrao((k + 0.5) / 13, 13, 256)
	local x2, y2 = Filtro.deslocGrao((k + 1.5) / 13, 13, 256)
	if x1 ~= x2 or y1 ~= y2 then
		diferentes += 1
	end
end
assert(diferentes >= 95, "desloc quase sempre muda entre quadros")
local zx, zy = Filtro.deslocGrao(1, 0, 256)
assert(zx == 0 and zy == 0, "fps 0 devolve 0,0")

-- proximoGlitch
local cfg = geral.glitch
local function media(noite: number, caca: number): number
	local rng = util.rng(7)
	local soma = 0
	for _ = 1, 400 do
		soma += Filtro.proximoGlitch(100, noite, caca, cfg, rng) - 100
	end
	return soma / 400
end
local dia, noite, noiteCaca = media(0, 0), media(1, 0), media(1, 1)
assert(dia > noite, "glitch mais frequente à noite")
assert(noite > noiteCaca, "glitch mais frequente com caça")
util.perto(
	Filtro.proximoGlitch(10, 0, 0, cfg, function()
		return 0
	end),
	10 + cfg.intervaloDia[1],
	"mínimo de dia"
)
util.perto(
	Filtro.proximoGlitch(10, 1, 0, cfg, function()
		return 1
	end),
	10 + cfg.intervaloNoite[2],
	"máximo de noite"
)
util.perto(
	Filtro.proximoGlitch(0, 0, 1, cfg, function()
		return 0
	end),
	cfg.intervaloDia[1] / cfg.divisorCaca,
	"caça divide o intervalo"
)
assert(Filtro.proximoGlitch(5, 0.5, 0, cfg, util.rng(1)) > 5, "sempre no futuro")
assert(Filtro.proximoGlitch(5, 9, -3, cfg, util.rng(1)) > 5, "entradas fora de faixa limitadas")

-- proximoEstalo
local est = require("../src/shared/Config/Filtro/Moldura").estalos
local function mediaEstalo(noite: number, caca: number): number
	local rng = util.rng(11)
	local soma = 0
	for _ = 1, 400 do
		soma += Filtro.proximoEstalo(50, noite, caca, est, rng) - 50
	end
	return soma / 400
end
assert(mediaEstalo(0, 0) > mediaEstalo(1, 0), "estalo mais frequente à noite")
assert(mediaEstalo(1, 0) > mediaEstalo(1, 1), "estalo mais frequente com caça")
util.perto(
	Filtro.proximoEstalo(0, 0, 0, est, function()
		return 0
	end),
	est.intervalo[1],
	"estalo mínimo"
)
util.perto(
	Filtro.proximoEstalo(0, 0, 0, est, function()
		return 1
	end),
	est.intervalo[2],
	"estalo máximo"
)
assert(Filtro.proximoEstalo(5, 9, 9, est, util.rng(3)) > 5, "estalo sempre no futuro")

-- nivelPorFps: histerese
local q = geral.qualidade
util.igual(Filtro.nivelPorFps(3, 60, 0, 0, q), 3, "no teto fica")
util.igual(Filtro.nivelPorFps(3, 30, 1, 0, q), 3, "abaixo mas pouco tempo")
util.igual(Filtro.nivelPorFps(3, 30, q.segDescer, 0, q), 2, "abaixo tempo suficiente desce")
util.igual(Filtro.nivelPorFps(0, 5, 99, 0, q), 0, "no chão fica")
util.igual(Filtro.nivelPorFps(2, q.minimo[3] + q.folga, 0, q.segSubir, q), 3, "sobe com folga")
util.igual(Filtro.nivelPorFps(2, q.minimo[3] + 1, 0, 99, q), 2, "sem folga não sobe")
util.igual(Filtro.nivelPorFps(2, 0, 99, 99, q), 2, "fps 0 ignorado")
util.igual(Filtro.nivelPorFps(2, 0 / 0, 99, 99, q), 2, "fps NaN ignorado")
-- simulação: FPS estável entre os limites não oscila
local nivel = 3
local abaixo, acima = 0, 0
local mudancas = 0
for _ = 1, 200 do
	local fps = 40 -- entre minimo[3]=45 e minimo[2]+... : deve assentar em 2
	abaixo = if nivel > 0 and fps < q.minimo[nivel] then abaixo + q.janelaFps else 0
	acima = if nivel < 3 and fps >= q.minimo[nivel + 1] + q.folga then acima + q.janelaFps else 0
	local novo = Filtro.nivelPorFps(nivel, fps, abaixo, acima, q)
	if novo ~= nivel then
		mudancas += 1
		nivel = novo
		abaixo, acima = 0, 0
	end
end
util.igual(nivel, 2, "assenta em 2")
util.igual(mudancas, 1, "não oscila")

-- intensidadeCaca
util.perto(Filtro.intensidadeCaca(10, 15, 60), 1, "caça perto")
util.perto(Filtro.intensidadeCaca(70, 15, 60), 0, "caça longe")
util.perto(Filtro.intensidadeCaca(37.5, 15, 60), 0.5, "caça no meio")
util.perto(Filtro.intensidadeCaca(5, 10, 10), 1, "perto == longe, dentro")
util.perto(Filtro.intensidadeCaca(15, 10, 10), 0, "perto == longe, fora")

print("Filtro.spec ok")
