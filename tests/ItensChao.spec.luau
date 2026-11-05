local util = require("./util")
local ItensChao = require("../src/shared/Regras/ItensChao")
local Config = require("../src/shared/Config/ItensChao")
local Itens = require("../src/shared/Config/Itens")

local tabela = {
	rolagens = { 1, 1 },
	itens = { { id = "enlatado", peso = 1, qtd = { 2, 2 } } },
}

-- sortearPonto: chance 0 nunca, chance 1 sempre
for i = 1, 50 do
	util.igual(ItensChao.sortearPonto(tabela, util.rng(i), 0), nil, "chance 0 nunca sorteia")
	local s = ItensChao.sortearPonto(tabela, util.rng(i), 1)
	util.igual(s ~= nil, true, "chance 1 sempre sorteia")
end
local s1 = ItensChao.sortearPonto(tabela, util.seq({ 1 }), 1)
util.igual((s1 :: any).id, "enlatado", "chance 1 com rng 1.0: id")
util.igual((s1 :: any).qtd, 2, "chance 1 com rng 1.0: qtd")

-- chance parcial: rng abaixo da chance sorteia, acima não
util.igual(ItensChao.sortearPonto(tabela, util.seq({ 0.1, 0.5 }), 0.35) ~= nil, true, "rng 0.1 < 0.35")
util.igual(ItensChao.sortearPonto(tabela, util.seq({ 0.9, 0.5 }), 0.35), nil, "rng 0.9 >= 0.35")

-- tabela inexistente ou vazia
util.igual(ItensChao.sortearPonto(nil, util.rng(1), 1), nil, "tabela nil")
util.igual(ItensChao.sortearPonto({ rolagens = { 1, 2 }, itens = {} }, util.rng(1), 1), nil, "tabela sem itens")

-- 1ª entrada de uma tabela com várias rolagens; ids e qtd válidos nas tabelas reais
local varias = {
	rolagens = { 3, 3 },
	itens = { { id = "agua", peso = 1, qtd = { 1, 1 } }, { id = "barra", peso = 1, qtd = { 1, 1 } } },
}
local v = ItensChao.sortearPonto(varias, util.seq({ 0, 0, 0.1, 0, 0.1, 0, 0.9, 0 }), 1)
util.igual((v :: any).id, "agua", "fica com a 1ª entrada")
util.igual((v :: any).qtd, 2, "1ª entrada soma repetidos (agua duas vezes)")
local rng = util.rng(7)
for nome, t in Itens.tabelas do
	for _ = 1, 100 do
		local r = ItensChao.sortearPonto(t, rng, 1)
		assert(r ~= nil and Itens.itens[r.id] ~= nil and r.qtd >= 1, nome .. ": sorteio inválido")
	end
end

-- velocidadesEspalhar: n distintas, em leque, dentro da config
local cfg = Config.espalhar
for _, n in { 1, 4, 8 } do
	local vs = ItensChao.velocidadesEspalhar(n, util.rng(100 + n), cfg)
	util.igual(#vs, n, "n velocidades: " .. n)
	local vistos: { [string]: boolean } = {}
	for _, vel in vs do
		util.igual(vel.y, cfg.cima, "vertical = cima")
		local h = math.sqrt(vel.x * vel.x + vel.z * vel.z)
		assert(h >= cfg.raioMin * 2 - 1e-6 and h <= cfg.raioMax * 2 + 1e-6, "horizontal dentro de raio × 2")
		local chave = string.format("%.3f,%.3f", vel.x, vel.z)
		assert(not vistos[chave], "velocidades distintas")
		vistos[chave] = true
	end
	if n > 1 then
		-- leque: ângulos consecutivos separados por pelo menos metade do setor
		local setor = 2 * math.pi / n
		for i = 1, n do
			local a = vs[i]
			local b = vs[i % n + 1]
			local d = math.atan2(b.z, b.x) - math.atan2(a.z, a.x)
			d = (d % (2 * math.pi))
			assert(d >= setor * 0.4 and d <= setor * 1.6, "ângulos em leque, sem sobrepor")
		end
	end
end
util.igual(#ItensChao.velocidadesEspalhar(0, util.rng(1), cfg), 0, "n=0 vazio")
-- determinística
local a1 = ItensChao.velocidadesEspalhar(5, util.rng(9), cfg)
local a2 = ItensChao.velocidadesEspalhar(5, util.rng(9), cfg)
util.igual(a1[3].x, a2[3].x, "mesma semente, mesmo leque")

-- removerExcedente
local function lista(...: any)
	return { ... }
end
local itens = lista(
	{ t = 5, id = "e", largado = true },
	{ t = 1, id = "a", largado = true },
	{ t = 3, id = "c", largado = true },
	{ t = 0, id = "p", largado = false },
	{ t = 4, id = "d", largado = true }
)
local fora = ItensChao.removerExcedente(itens, 3)
util.igual(#fora, 2, "5 itens, max 3: remove 2")
util.igual(fora[1], "a", "remove o mais antigo primeiro")
util.igual(fora[2], "c", "depois o seguinte")
util.igual(#ItensChao.removerExcedente(itens, 5), 0, "no limite: nada")
util.igual(#ItensChao.removerExcedente(itens, 10), 0, "abaixo do limite: nada")
util.igual(#itens, 5, "não muta a lista")
-- item de ponto nunca sai, mesmo mais antigo
local fora2 = ItensChao.removerExcedente(itens, 4)
util.igual(#fora2, 1, "max 4: remove 1")
util.igual(fora2[1], "a", "o de ponto (t=0, mais antigo) não é removido")
-- só de ponto acima do limite: vazio
local soPonto = lista({ t = 1, id = "x", largado = false }, { t = 2, id = "y", largado = false })
util.igual(#ItensChao.removerExcedente(soPonto, 1), 0, "só de ponto acima do limite: vazio")
-- excesso maior que os largados: leva só os largados
local misto = lista(
	{ t = 1, id = "p1", largado = false },
	{ t = 2, id = "p2", largado = false },
	{ t = 3, id = "l", largado = true }
)
local fora3 = ItensChao.removerExcedente(misto, 1)
util.igual(#fora3, 1, "excesso 2, só 1 largado: remove só ele")
util.igual(fora3[1], "l", "o largado")

-- Config: tempos e alcance vêm de Config/Itens
util.igual(Config.largadoDuracao, Itens.bolsaDuracao, "largadoDuracao = bolsaDuracao")
util.igual(Config.reposicao, Itens.reposicao, "reposicao = Itens.reposicao")
util.igual(Config.alcance, Itens.alcanceInteracao, "alcance = Itens.alcanceInteracao")

print("ItensChao.spec ok")
