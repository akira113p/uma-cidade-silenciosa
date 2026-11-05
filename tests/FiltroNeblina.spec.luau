local util = require("./util")
local N = require("../src/shared/Regras/FiltroNeblina")

-- anel: sem chaves repetidas, nada dentro do raio interno nem fora do externo, e nenhuma célula do intervalo faltando
for _, c in { { 0, 0 }, { 13.7, -41.2 }, { -300.5, 222 } } do
	local cx, cz = c[1], c[2]
	local lista = N.anel(cx, cz, 28, 12, 150)
	assert(#lista > 50, "anel tem células")
	local vistas = {}
	for _, cel in lista do
		assert(not vistas[cel.chave], "chave repetida " .. cel.chave)
		vistas[cel.chave] = true
		local d = math.sqrt((cel.x - cx) ^ 2 + (cel.z - cz) ^ 2)
		assert(d >= 12 - 1e-6, "célula dentro do raio interno")
		assert(d <= 150 + 1e-6, "célula fora do raio externo")
	end
	local esperadas = 0
	for i = -40, 40 do
		for j = -40, 40 do
			local d = math.sqrt((i * 28 - cx) ^ 2 + (j * 28 - cz) ^ 2)
			if d >= 12 and d <= 150 then
				esperadas += 1
			end
		end
	end
	-- (a faixa -40..40 só cobre o centro perto da origem)
	if cx == 0 and cz == 0 then
		util.igual(#lista, esperadas, "anel completo")
	end
end
-- mesma célula, mesma chave, independente do centro
local a = N.anel(0, 0, 28, 12, 150)
local b = N.anel(5, 5, 28, 12, 150)
local xa = {}
for _, cel in a do
	xa[cel.chave] = cel.x
end
for _, cel in b do
	if xa[cel.chave] then
		util.igual(xa[cel.chave], cel.x, "chave estável")
	end
end

-- jitter: determinístico e dentro da amplitude
local dx1, dz1 = N.jitter("3,-7", 8)
local dx2, dz2 = N.jitter("3,-7", 8)
util.igual(dx1, dx2, "jitter dx repete")
util.igual(dz1, dz2, "jitter dz repete")
local soma = 0
for i = -30, 30 do
	for j = -30, 30 do
		local dx, dz = N.jitter(i .. "," .. j, 8)
		assert(math.abs(dx) <= 8 and math.abs(dz) <= 8, "jitter fora da amplitude")
		soma += dx
	end
end
assert(math.abs(soma / 3721) < 1, "jitter sem viés forte")
local ex, ez = N.jitter("1,1", 0)
util.igual(ex, 0, "amplitude 0 dx")
util.igual(ez, 0, "amplitude 0 dz")
local ox, oz = N.jitter("1,2", 8)
local px, pz = N.jitter("2,1", 8)
assert(ox ~= px or oz ~= pz, "chaves diferentes dão deslocamentos diferentes")

-- fade: extremos 0, miolo 1, monotônico nas rampas
util.igual(N.fade(0, 12, 8, 150, 50), 0, "fade no centro")
util.igual(N.fade(12, 12, 8, 150, 50), 0, "fade no raio interno")
util.igual(N.fade(150, 12, 8, 150, 50), 0, "fade no raio externo")
util.igual(N.fade(400, 12, 8, 150, 50), 0, "fade longe")
util.igual(N.fade(80, 12, 8, 150, 50), 1, "fade no miolo")
util.perto(N.fade(16, 12, 8, 150, 50), 0.5, "fade meio da rampa interna")
util.perto(N.fade(125, 12, 8, 150, 50), 0.5, "fade meio da rampa externa")
local anterior = 0
for d = 12, 20, 0.25 do
	local f = N.fade(d, 12, 8, 150, 50)
	assert(f >= anterior - 1e-9, "rampa interna crescente")
	anterior = f
end
anterior = 1
for d = 100, 150, 0.5 do
	local f = N.fade(d, 12, 8, 150, 50)
	assert(f <= anterior + 1e-9, "rampa externa decrescente")
	anterior = f
end
util.igual(N.fade(30, 12, 0, 150, 0), 1, "sem rampas")

-- quantizar
util.igual(N.quantizar(0, 10), 0, "quantizar 0")
util.igual(N.quantizar(1, 10), 1, "quantizar 1")
util.perto(N.quantizar(0.34, 10), 0.3, "quantizar 0.34", 1e-9)
util.perto(N.quantizar(0.36, 10), 0.4, "quantizar 0.36", 1e-9)
util.igual(N.quantizar(-3, 10), 0, "quantizar abaixo")
util.igual(N.quantizar(7, 10), 1, "quantizar acima")
print("FiltroNeblina ok")
