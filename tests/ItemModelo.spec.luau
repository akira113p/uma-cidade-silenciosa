local util = require("./util")
local Regra = require("../src/shared/Regras/ItemModelo")
local Dados = require("../src/shared/Config/ItensModelos")
local Itens = require("../src/shared/Config/Itens")

local function parte(forma: string, tam: { number }, pos: { number }?, rot: { number }?): any
	return {
		nome = "P",
		forma = forma,
		tam = tam,
		pos = pos or { 0, 0, 0 },
		rot = rot or { 0, 0, 0 },
		cor = { 100, 100, 100 },
		material = "Plastic",
	}
end

local function modeloDe(partes: { any }, chaoRot: { number }?, escala: number?): any
	return {
		partes = partes,
		mao = { pos = { 0, 0, 0 }, rot = { 0, 0, 0 } },
		chao = { rot = chaoRot or { 0, 0, 0 } },
		escalaChao = escala,
	}
end

local function tamanho(c: any, i: number): number
	return c.max[i] - c.min[i]
end

-- Todo item tem modelo válido (e nenhum modelo sobra sem item) --------------------------------------------------
local ids = 0
for id in Itens.itens do
	ids += 1
	local m = Dados.modelos[id]
	assert(m ~= nil, "item sem modelo: " .. id)
	local ok, motivo = Regra.validar(m)
	assert(ok, id .. ": " .. tostring(motivo))
	assert(#m.partes >= 2 and #m.partes <= 6, id .. ": precisa de 2 a 6 partes")
end
for id in Dados.modelos do
	assert(Itens.itens[id] ~= nil, "modelo sem item: " .. id)
end
assert(ids >= 12, "Config/Itens perdeu itens?")

-- Altura de repouso, tamanho e lanterna ----------------------------------------------------------------------------
for id, m in Dados.modelos do
	local r = Regra.repouso(m)
	assert(r.altura > 0, id .. ": altura de repouso <= 0 (" .. r.altura .. ")")
	assert(r.altura < 1, id .. ": altura de repouso absurda (" .. r.altura .. ")")
	util.igual(r.rot, m.chao.rot, id .. ": repouso devolve chao.rot")
	for _, rot in { { 0, 0, 0 }, m.chao.rot } do
		local c = Regra.caixa(m, rot)
		for i = 1, 3 do
			assert(tamanho(c, i) <= 3.0, string.format("%s: %.2f studs no eixo %d (máximo 3,0)", id, tamanho(c, i), i))
		end
	end
	-- a origem (onde a mão segura) fica dentro da caixa do modelo, senão a mão segura o vazio
	local c = Regra.caixa(m, { 0, 0, 0 })
	for i = 1, 3 do
		assert(c.min[i] <= 0 and c.max[i] >= 0, id .. ": origem fora da caixa no eixo " .. i)
	end
end
util.igual(Dados.modelos.lanterna.lado, "esquerda", "lanterna na mão esquerda")
util.igual(Dados.modelos.faca.lado, nil, "faca: lado padrão (direita)")
local lente
for _, p in Dados.modelos.lanterna.partes do
	if p.material == "Neon" then
		lente = p
	end
end
assert(lente ~= nil and lente.pos[3] < 0, "lanterna: lente Neon na frente (-Z)")

-- Tamanhos de referência (docs/itens-no-mundo.md §2), com folga ------------------------------------------------------
local c = Regra.caixa(Dados.modelos.machado)
util.perto(tamanho(c, 3), 2.45, "machado ≈ 2,4 de comprimento", 0.3)
c = Regra.caixa(Dados.modelos.peDeCabra)
util.perto(tamanho(c, 3), 2.2, "pé de cabra ≈ 2,2", 0.2)
c = Regra.caixa(Dados.modelos.faca)
util.perto(tamanho(c, 3), 1.2, "faca ≈ 1,2", 0.2)
c = Regra.caixa(Dados.modelos.enlatado)
util.perto(tamanho(c, 2), 0.7, "enlatado 0,7 de altura", 0.05)
util.perto(tamanho(c, 1), 0.52, "enlatado Ø0,5", 0.05)

-- Caixa: matemática da rotação ------------------------------------------------------------------------------------
local cubo = modeloDe({ parte("Block", { 1, 2, 1 }) })
c = Regra.caixa(cubo)
util.perto(c.min[2], -1, "cubo 1x2x1 sem giro: min y")
util.perto(c.max[2], 1, "cubo 1x2x1 sem giro: max y")
c = Regra.caixa(cubo, { 90, 0, 0 })
util.perto(c.max[2], 0.5, "girado 90 em X: max y 0,5")
util.perto(c.max[3], 1, "girado 90 em X: z vira 2")
util.perto(c.max[1], 0.5, "girado 90 em X: x intacto")
c = Regra.caixa(cubo, { 0, 0, 90 })
util.perto(c.max[1], 1, "girado 90 em Z: x vira 2")
util.perto(c.max[2], 0.5, "girado 90 em Z: y vira 1")
c = Regra.caixa(cubo, { 0, 90, 0 })
util.perto(c.max[2], 1, "girado 90 em Y: y intacto")
util.perto(c.max[1], 0.5, "girado 90 em Y: x e z trocam")
-- 45 graus em Z: quadrado de 1 vira losango de meia-diagonal 0,5+0,5 vezes cos45 em cada lado
c = Regra.caixa(modeloDe({ parte("Block", { 1, 1, 1 }) }), { 0, 0, 45 })
util.perto(c.max[1], math.sqrt(0.5), "45 em Z: x = raiz(2)/2")

-- Ordem dos eixos é a de CFrame.Angles (Rx * Ry * Rz: o Z gira primeiro): parte 1x2x3, rot {90, 0, 90}
c = Regra.caixa(modeloDe({ parte("Block", { 1, 2, 3 }) }), { 90, 0, 90 })
util.perto(c.max[1], 1, "ordem XYZ: x = 1")
util.perto(c.max[2], 1.5, "ordem XYZ: y = 1,5")
util.perto(c.max[3], 0.5, "ordem XYZ: z = 0,5")

-- Posição também gira: parte em (0,2,0) com o conjunto girado 90 em X vai para z = 2
c = Regra.caixa(modeloDe({ parte("Block", { 1, 1, 1 }, { 0, 2, 0 }) }), { 90, 0, 0 })
util.perto(c.min[3], 1.5, "posição gira com o conjunto: min z")
util.perto(c.max[3], 2.5, "posição gira com o conjunto: max z")
util.perto(c.max[2], 0.5, "posição gira com o conjunto: max y")

-- Rotação da parte e do conjunto se compõem: parte deitada em Z (90) e conjunto em X (90): x do bloco vai a y e depois a z
c = Regra.caixa(modeloDe({ parte("Block", { 4, 2, 2 }, nil, { 0, 0, 90 }) }), { 90, 0, 0 })
util.perto(c.max[3], 2, "parte e conjunto compostos: z = 2")
util.perto(c.max[2], 1, "parte e conjunto compostos: y = 1")

-- Cilindro: eixo no X da peça. De pé (rot z 90): altura = comprimento; deitado: altura = diâmetro.
local lata = modeloDe({ parte("Cylinder", { 0.7, 0.5, 0.5 }, nil, { 0, 0, 90 }) })
c = Regra.caixa(lata)
util.perto(c.max[2], 0.35, "cilindro de pé: meia altura")
util.perto(c.max[1], 0.25, "cilindro de pé: raio em x")
c = Regra.caixa(modeloDe({ parte("Cylinder", { 0.7, 0.5, 0.5 }) }))
util.perto(c.max[1], 0.35, "cilindro deitado: eixo no X")
util.perto(c.max[2], 0.25, "cilindro deitado: raio em y")
-- cilindro inclinado 45 em Z: extensão exata = cos45 * meio comprimento + sin45 * raio (< caixa de bloco)
c = Regra.caixa(modeloDe({ parte("Cylinder", { 2, 1, 1 }, nil, { 0, 0, 45 }) }))
util.perto(c.max[2], math.sqrt(0.5) * 1 + math.sqrt(0.5) * 0.5, "cilindro a 45", 1e-6)
-- bola: raio em qualquer giro
c = Regra.caixa(modeloDe({ parte("Ball", { 1, 1, 1 }) }), { 30, 40, 50 })
util.perto(c.max[2], 0.5, "bola não muda de tamanho girada", 1e-6)

-- Repouso: altura e escalaChao -------------------------------------------------------------------------------------
local r = Regra.repouso(modeloDe({ parte("Block", { 1, 2, 1 }) }))
util.perto(r.altura, 1, "repouso do cubo 1x2x1 em pé")
r = Regra.repouso(modeloDe({ parte("Block", { 1, 2, 1 }) }, { 90, 0, 0 }))
util.perto(r.altura, 0.5, "repouso do cubo 1x2x1 deitado (90 em X)")
util.igual(r.rot[1], 90, "repouso devolve a rot")
r = Regra.repouso(modeloDe({ parte("Block", { 1, 2, 1 }) }, { 90, 0, 0 }, 2))
util.perto(r.altura, 1, "escalaChao 2 dobra a altura")
-- a parte mais baixa decide (parte fora da origem)
r = Regra.repouso(modeloDe({ parte("Block", { 1, 1, 1 }), parte("Block", { 1, 1, 1 }, { 0, -2, 0 }) }))
util.perto(r.altura, 2.5, "repouso pela peça mais baixa")

-- Validação rejeita dado ruim ---------------------------------------------------------------------------------------
local function invalido(mut: (any) -> (), texto: string)
	local m = modeloDe({ parte("Block", { 1, 1, 1 }) })
	mut(m)
	local ok, motivo = Regra.validar(m)
	util.igual(ok, false, "deveria rejeitar: " .. texto)
	assert(type(motivo) == "string" and #motivo > 0, "rejeição sem motivo: " .. texto)
end
util.igual((Regra.validar(modeloDe({ parte("Block", { 1, 1, 1 }) }))), true, "modelo mínimo é válido")
invalido(function(m)
	m.partes[1].forma = "Triangulo"
end, "forma inexistente")
invalido(function(m)
	m.partes[1].forma = "block"
end, "forma com caixa errada")
invalido(function(m)
	m.partes[1].material = "Ouro"
end, "material inexistente")
invalido(function(m)
	m.partes[1].material = nil
end, "sem material")
invalido(function(m)
	m.partes = {}
end, "sem partes")
invalido(function(m)
	m.partes[1].tam = { 1, 0, 1 }
end, "tam zero")
invalido(function(m)
	m.partes[1].tam = { 1, -1, 1 }
end, "tam negativo")
invalido(function(m)
	m.partes[1].tam = { 1, 0.05, 1 }
end, "peça menor que 0,08")
invalido(function(m)
	m.partes[1].tam = { 1, 1 }
end, "tam com 2 números")
invalido(function(m)
	m.partes[1].pos = { 0, 0, 0 / 0 }
end, "pos NaN")
invalido(function(m)
	m.partes[1].rot = { 0, 0, math.huge }
end, "rot infinita")
invalido(function(m)
	m.partes[1].cor = { 300, 0, 0 }
end, "cor acima de 255")
invalido(function(m)
	m.partes[1].cor = { 0, -1, 0 }
end, "cor negativa")
invalido(function(m)
	m.partes[1].transp = 1.5
end, "transparência acima de 1")
invalido(function(m)
	m.partes[1].nome = ""
end, "parte sem nome")
invalido(function(m)
	m.partes[2] = parte("Block", { 1, 1, 1 })
end, "nome de parte repetido")
invalido(function(m)
	m.partes = { 1 }
end, "parte que não é tabela")
invalido(function(m)
	m.lado = "meio"
end, "lado inválido")
invalido(function(m)
	m.mao = nil
end, "sem mao")
invalido(function(m)
	m.chao = { rot = { 0, 0 } }
end, "chao.rot incompleto")
invalido(function(m)
	m.escalaChao = 0
end, "escalaChao zero")
invalido(function(m)
	m.partes = { parte("Block", { 1, 1, 1 }), parte("Block", { 1, 1, 1 }) }
	for i, p in m.partes do
		p.nome = "P" .. i
	end
	for i = 3, 7 do
		table.insert(m.partes, parte("Block", { 1, 1, 1 }))
		m.partes[i].nome = "P" .. i
	end
end, "mais de 6 partes")
util.igual((Regra.validar(nil)), false, "nil não é modelo")
util.igual((Regra.validar("x")), false, "string não é modelo")

print("ItemModelo.spec ok")
