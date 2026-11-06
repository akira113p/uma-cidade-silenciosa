local util = require("./util")
local R = require("../src/shared/Regras/FiltroRetro")

-- potenciaValida: bordas, empate sobe, lixo cai no padrão 4
util.igual(R.potenciaValida(2), 2, "2")
util.igual(R.potenciaValida(1), 2, "1 sobe para 2")
util.igual(R.potenciaValida(-5), 2, "negativo")
util.igual(R.potenciaValida(3), 4, "3: empate entre 2 e 4 sobe")
util.igual(R.potenciaValida(4), 4, "4")
util.igual(R.potenciaValida(5), 4, "5 mais perto de 4")
util.igual(R.potenciaValida(6), 8, "6: empate entre 4 e 8 sobe")
util.igual(R.potenciaValida(7), 8, "7")
util.igual(R.potenciaValida(10), 8, "10 mais perto de 8")
util.igual(R.potenciaValida(12), 16, "12: empate entre 8 e 16 sobe")
util.igual(R.potenciaValida(16), 16, "16")
util.igual(R.potenciaValida(99), 16, "99 limitado a 16")
util.igual(R.potenciaValida(0 / 0), 4, "nan vira 4")
util.igual(R.potenciaValida("x" :: any), 4, "texto vira 4")
util.igual(R.potenciaValida(nil :: any), 4, "nil vira 4")

-- bayer: n=2 exato, primeira linha de 4, valores únicos no intervalo para todos os tamanhos
local b2 = R.bayer(2)
util.igual(b2[1][1], 0, "b2[1][1]")
util.igual(b2[1][2], 2, "b2[1][2]")
util.igual(b2[2][1], 3, "b2[2][1]")
util.igual(b2[2][2], 1, "b2[2][2]")
local b4 = R.bayer(4)
local esperada = { 0, 8, 2, 10 }
for j = 1, 4 do
	util.igual(b4[1][j], esperada[j], "b4 linha 1 col " .. j)
end
-- segunda linha de M4 conferida à mão: {12, 4, 14, 6}
local linha2 = { 12, 4, 14, 6 }
for j = 1, 4 do
	util.igual(b4[2][j], linha2[j], "b4 linha 2 col " .. j)
end
for _, n in { 2, 4, 8, 16 } do
	local m = R.bayer(n)
	util.igual(#m, n, "linhas " .. n)
	local visto = {}
	for i = 1, n do
		util.igual(#m[i], n, "colunas " .. n)
		for j = 1, n do
			local v = m[i][j]
			assert(v >= 0 and v <= n * n - 1 and v == math.floor(v), "valor fora do intervalo em " .. n)
			assert(not visto[v], "valor repetido " .. v .. " em " .. n)
			visto[v] = true
		end
	end
end
-- n inválido é normalizado, não quebra
util.igual(#R.bayer(3), 4, "bayer(3) normaliza para 4")

-- limiarBayer
util.perto(R.limiarBayer(0, 2), 0.125, "limiar 0/2")
util.perto(R.limiarBayer(3, 2), 0.875, "limiar 3/2")
util.perto(R.limiarBayer(0, 4), 0.5 / 16, "limiar 0/4")
util.perto(R.limiarBayer(255, 16), 255.5 / 256, "limiar 255/16")

-- texelDither: lado do 0.5 decide a cor; alfa = 2·a·|d|
local cor, alfa = R.texelDither(0, 2, 0.12)
util.igual(cor, 0, "texel 0 preto")
util.perto(alfa, 0.09, "texel 0 alfa", 1e-9)
cor, alfa = R.texelDither(3, 2, 0.12)
util.igual(cor, 255, "texel 3 branco")
util.perto(alfa, 0.09, "texel 3 alfa", 1e-9)
cor, alfa = R.texelDither(1, 2, 0.12)
util.igual(cor, 0, "texel 1 preto")
util.perto(alfa, 0.03, "texel 1 alfa", 1e-9)
cor, alfa = R.texelDither(2, 2, 0.12)
util.igual(cor, 255, "texel 2 branco")
util.perto(alfa, 0.03, "texel 2 alfa", 1e-9)
cor, alfa = R.texelDither(0, 2, 10)
util.igual(alfa, 1, "alfa limitado a 1")
cor, alfa = R.texelDither(0, 2, 0)
util.igual(alfa, 0, "amplitude 0 = transparente")

-- texturaDither 2×2 conferida à mão: alfas 0.09*255=22.95->23 e 0.03*255=7.65->8
local t2 = R.texturaDither(2, 0.12)
local alvo = { 0, 0, 0, 23, 255, 255, 255, 8, 255, 255, 255, 23, 0, 0, 0, 8 }
util.igual(#t2, 16, "textura 2x2 tamanho")
for i = 1, 16 do
	util.igual(t2[i], alvo[i], "textura 2x2 byte " .. i)
end
for _, n in { 2, 4, 8, 16 } do
	for _, amp in { 0, 0.12, 0.5, 5 } do
		local t = R.texturaDither(n, amp)
		util.igual(#t, n * n * 4, "textura tamanho " .. n)
		for i, v in t do
			assert(v >= 0 and v <= 255 and v == math.floor(v), "byte inválido em " .. n .. " idx " .. i)
			if i % 4 ~= 0 then
				assert(v == 0 or v == 255, "cor só preta ou branca")
			end
		end
		-- r = g = b em todo texel
		for k = 0, n * n - 1 do
			assert(t[k * 4 + 1] == t[k * 4 + 2] and t[k * 4 + 2] == t[k * 4 + 3], "r=g=b")
		end
	end
end
-- sem viés: metade dos texels brancos e metade pretos (a média do dither é neutra)
do
	local t = R.texturaDither(8, 0.12)
	local brancos = 0
	for k = 0, 63 do
		if t[k * 4 + 1] == 255 then
			brancos += 1
		end
	end
	util.igual(brancos, 32, "metade branca")
end

-- escalaForca
util.perto(R.escalaForca(50), 0.5, "forca 50")
util.perto(R.escalaForca(100), 1, "forca 100")
util.perto(R.escalaForca(0), 0, "forca 0")
util.perto(R.escalaForca(150), 1, "forca >100 limitada")
util.perto(R.escalaForca(-5), 0, "forca <0 limitada")
util.perto(R.escalaForca(0 / 0), 0, "forca nan")
util.perto(R.escalaForca(nil :: any), 0, "forca nil")

-- cicloScanDuraPx / periodoScanSuavePx
util.perto(R.cicloScanDuraPx(1080, 360, 2), 3, "ciclo dura 1080")
util.perto(R.cicloScanDuraPx(360, 360, 2), 2, "ciclo dura 360 no piso")
util.perto(R.cicloScanDuraPx(200, 360, 2), 2, "ciclo dura pequena no piso")
util.perto(R.cicloScanDuraPx(1080, 0, 2), 2, "ciclo dura contagem 0")
util.perto(R.periodoScanSuavePx(1080, 360, 6), 1080 * 2 * math.pi / 360, "periodo suave 1080", 1e-9)
util.perto(R.periodoScanSuavePx(100, 360, 6), 6, "periodo suave no piso")
util.perto(R.periodoScanSuavePx(1080, 0, 6), 6, "periodo suave contagem 0")

-- alfaScanDura: 1ª metade escura, 2ª clara
util.perto(R.alfaScanDura(0, 0.7, 1), 0.3, "dura frac 0", 1e-9)
util.perto(R.alfaScanDura(0.25, 0.7, 1), 0.3, "dura frac 0.25", 1e-9)
util.perto(R.alfaScanDura(0.4999, 0.7, 1), 0.3, "dura logo antes do meio", 1e-9)
util.perto(R.alfaScanDura(0.5, 0.7, 1), 0, "dura frac 0.5", 1e-9)
util.perto(R.alfaScanDura(0.9, 0.7, 1), 0, "dura frac 0.9", 1e-9)

-- alfaScanSuave: seno de 0 (meio) ao máximo
util.perto(R.alfaScanSuave(0, 0.7, 1), 0.15, "suave frac 0", 1e-9)
util.perto(R.alfaScanSuave(0.25, 0.7, 1), 0, "suave pico claro", 1e-9)
util.perto(R.alfaScanSuave(0.5, 0.7, 1), 0.15, "suave frac 0.5", 1e-9)
util.perto(R.alfaScanSuave(0.75, 0.7, 1), 0.3, "suave pico escuro", 1e-9)
util.perto(R.alfaScanSuave(1, 0.7, 1), R.alfaScanSuave(0, 0.7, 1), "suave periódica", 1e-9)

-- brilhoBandas: sempre entre mínimo e máximo; valores conferidos à mão
util.perto(R.brilhoBandas(0, 0, 0.5, 5, 0.8, 1), 0.9, "bandas y=0 t=0", 1e-9)
-- (t*v + y)*f = pi/2 -> sen = 1 -> máximo: y = pi/10, t = 0
util.perto(R.brilhoBandas(math.pi / 10, 0, 0.5, 5, 0.8, 1), 1, "bandas pico", 1e-9)
util.perto(R.brilhoBandas(3 * math.pi / 10, 0, 0.5, 5, 0.8, 1), 0.8, "bandas vale", 1e-9)
-- avançar t por uma unidade de y com velocidade 1 equivale a avançar y
util.perto(R.brilhoBandas(0.1, 0.2, 1, 5, 0.8, 1), R.brilhoBandas(0.3, 0, 1, 5, 0.8, 1), "bandas t equivale a y", 1e-9)
for i = 0, 200 do
	local v = R.brilhoBandas(i / 37, i / 11, 0.1, 5, 0.8, 1)
	assert(v >= 0.8 - 1e-9 and v <= 1 + 1e-9, "brilho fora de [min,max]")
end

-- periodoBandasPx / deslocBandasPx
util.perto(R.periodoBandasPx(1000, 5), 1000 * 2 * math.pi / 5, "periodo bandas", 1e-9)
util.perto(R.deslocBandasPx(1, 0.1, 1000, 1256.637), 100, "desloc t=1")
util.perto(R.deslocBandasPx(20, 0.1, 1000, 1256.637), 2000 - 1256.637, "desloc dá a volta", 1e-9)
util.perto(R.deslocBandasPx(0, 0.1, 1000, 1256.637), 0, "desloc t=0")
util.perto(R.deslocBandasPx(5, 0.1, 1000, 0), 0, "desloc período 0")
util.perto(R.deslocBandasPx(5, 0.1, 1000, -3), 0, "desloc período negativo")
for i = 0, 100 do
	local d = R.deslocBandasPx(i * 7.3, 0.1, 1080, 1357)
	assert(d >= 0 and d < 1357, "desloc dentro do período")
end

-- alfaBandas
util.perto(R.alfaBandas(0, 0.8, 1), 0.1, "alfaBandas frac 0", 1e-9)
util.perto(R.alfaBandas(0.25, 0.8, 1), 0, "alfaBandas pico claro", 1e-9)
util.perto(R.alfaBandas(0.75, 0.8, 1), 0.2, "alfaBandas pico escuro", 1e-9)

-- texturaPerfilVertical: tamanho, preto, alfa conferido à mão, de cima para baixo
local p = R.texturaPerfilVertical(4, function(f)
	return f
end, 1)
util.igual(#p, 16, "perfil 1x4 tamanho")
local alfas = { 32, 96, 159, 223 } -- 0.125, 0.375, 0.625, 0.875 vezes 255, arredondado
for i = 1, 4 do
	util.igual(p[(i - 1) * 4 + 1], 0, "perfil R")
	util.igual(p[(i - 1) * 4 + 2], 0, "perfil G")
	util.igual(p[(i - 1) * 4 + 3], 0, "perfil B")
	util.igual(p[(i - 1) * 4 + 4], alfas[i], "perfil alfa " .. i)
end
local meio = R.texturaPerfilVertical(4, function(f)
	return f
end, 0.5)
util.igual(meio[4], 16, "perfil escala 0.5 (0.0625*255=15.9)")
local zero = R.texturaPerfilVertical(4, function(f)
	return f
end, 0)
for i = 1, 4 do
	util.igual(zero[i * 4], 0, "perfil escala 0 transparente")
end
-- alfa fora de 0..1 é limitado
local lim = R.texturaPerfilVertical(2, function(_f)
	return 3
end, 1)
util.igual(lim[4], 255, "perfil limita a 1")
local neg = R.texturaPerfilVertical(2, function(_f)
	return -3
end, 1)
util.igual(neg[4], 0, "perfil limita a 0")
-- perfil real do shader: todos os bytes 0..255 e tamanho certo
for _, altura in { 8, 64 } do
	local d = R.texturaPerfilVertical(altura, function(f)
		return R.alfaScanDura(f, 0.7, 1)
	end, 1)
	local s = R.texturaPerfilVertical(altura, function(f)
		return R.alfaScanSuave(f, 0.7, 1)
	end, 0.8)
	local bd = R.texturaPerfilVertical(altura, function(f)
		return R.alfaBandas(f, 0.8, 1)
	end, 0.5)
	for _, t in { d, s, bd } do
		util.igual(#t, altura * 4, "perfil tamanho " .. altura)
		for _, v in t do
			assert(v >= 0 and v <= 255 and v == math.floor(v), "byte do perfil inválido")
		end
	end
end
-- scan dura com 8 texels: 4 escuros (0.3*255=76.5->77) e 4 transparentes
do
	local t = R.texturaPerfilVertical(8, function(f)
		return R.alfaScanDura(f, 0.7, 1)
	end, 1)
	for i = 1, 4 do
		util.igual(t[i * 4], 77, "scan dura texel escuro " .. i)
	end
	for i = 5, 8 do
		util.igual(t[i * 4], 0, "scan dura texel claro " .. i)
	end
end

-- vhsDeslocPx
util.perto(R.vhsDeslocPx(0.002, 1920), 3.84, "vhs padrão do .mat")
util.perto(R.vhsDeslocPx(0.01, 1000), 10, "vhs máximo")
util.perto(R.vhsDeslocPx(0.5, 1000), 10, "vhs limitado em cima")
util.perto(R.vhsDeslocPx(-1, 1000), -10, "vhs limitado embaixo")
util.perto(R.vhsDeslocPx(0, 1920), 0, "vhs zero")
