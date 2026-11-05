local util = require("./util")
local Loot = require("../src/shared/Regras/Loot")
local Config = require("../src/shared/Config/Itens")

local tabela = {
	rolagens = { 2, 2 },
	itens = {
		{ id = "enlatado", peso = 1, qtd = { 1, 3 } },
		{ id = "agua", peso = 1, qtd = { 2, 2 } },
	},
}

-- Determinístico: ordem do rng = nº de rolagens, depois (item, qtd) por rolagem.
-- 0.0 -> 2 rolagens (min = max, mas consome o rng); 0.1 -> enlatado; 0.99 -> qtd 3; 0.9 -> agua; qtd fixa 2.
local r = Loot.sortear(tabela, util.seq({ 0.0, 0.1, 0.99, 0.9, 0.5 }))
util.igual(#r, 2, "dois itens")
util.igual(r[1].id, "enlatado", "primeiro: enlatado")
util.igual(r[1].qtd, 3, "primeiro: qtd 3")
util.igual(r[2].id, "agua", "segundo: agua")
util.igual(r[2].qtd, 2, "segundo: qtd 2")

-- rng que devolve sempre o mesmo valor repete o resultado
local de1 = Loot.sortear(tabela, util.seq({ 0.3 }))
local de2 = Loot.sortear(tabela, util.seq({ 0.3 }))
util.igual(#de1, #de2, "mesmo rng, mesmo tamanho")
-- mesmo item sorteado duas vezes soma num só
util.igual(#de1, 1, "repetido soma num item")
util.igual(de1[1].id, "enlatado", "repetido: id")

-- rng no extremo superior (1.0) não estoura
local topo = Loot.sortear(tabela, util.seq({ 1, 1, 1 }))
util.igual(#topo >= 1, true, "rng 1.0 devolve algo")
util.igual(topo[1].id, "agua", "rng 1.0 pega o último")

-- número de rolagens respeita {min, max}
local tres = { rolagens = { 3, 3 }, itens = { { id = "agua", peso = 1, qtd = { 1, 1 } } } }
util.igual(Loot.sortear(tres, util.rng(1))[1].qtd, 3, "3 rolagens do mesmo item somam 3")

-- peso 0 nunca sai; tabela sem peso devolve vazio
local zero = {
	rolagens = { 5, 5 },
	itens = { { id = "agua", peso = 0, qtd = { 1, 1 } }, { id = "barra", peso = 3, qtd = { 1, 1 } } },
}
for i = 1, 50 do
	local x = Loot.sortear(zero, util.rng(i))
	util.igual(#x, 1, "só um id")
	util.igual(x[1].id, "barra", "peso 0 não sai")
end
util.igual(#Loot.sortear({ rolagens = { 1, 2 }, itens = {} }, util.rng(1)), 0, "tabela vazia")

-- Todas as tabelas do Config: ids existem, qtd dentro da faixa, nunca 0
local rng = util.rng(12345)
local vistos: { [string]: boolean } = {}
for nome, t in Config.tabelas do
	local maxPossivel = t.rolagens[2]
	for _ = 1, 300 do
		local saida = Loot.sortear(t, rng)
		assert(#saida >= 1, nome .. ": nenhum item")
		assert(#saida <= maxPossivel, nome .. ": mais itens que rolagens")
		for _, item in saida do
			assert(Config.itens[item.id] ~= nil, nome .. ": id inexistente " .. item.id)
			assert(item.qtd >= 1, nome .. ": qtd 0 em " .. item.id)
			assert(item.qtd % 1 == 0, nome .. ": qtd fracionada")
			vistos[nome .. ":" .. item.id] = true
		end
	end
	-- todo item da tabela aparece em 300 sorteios
	for _, e in t.itens do
		assert(vistos[nome .. ":" .. e.id], nome .. ": nunca sorteou " .. e.id)
	end
end

-- retirar
local conteudo = { { id = "enlatado", qtd = 3 }, { id = "agua", qtd = 2 } }
local n1, t1 = Loot.retirar(conteudo, 1)
util.igual((t1 :: any).qtd, 3, "retirar tudo")
util.igual(#n1, 1, "entrada some")
util.igual(n1[1].id, "agua", "a outra sobe")
util.igual(#conteudo, 2, "entrada intacta")
util.igual(conteudo[1].qtd, 3, "entrada intacta: qtd")
local n2, t2 = Loot.retirar(conteudo, 1, 2)
util.igual((t2 :: any).qtd, 2, "retirar parte")
util.igual(n2[1].qtd, 1, "sobrou 1")
util.igual(#n2, 2, "entrada continua")
local _, t3 = Loot.retirar(conteudo, 2, 99)
util.igual((t3 :: any).qtd, 2, "mais do que tem leva o que tem")
local _, t4 = Loot.retirar(conteudo, 3)
util.igual(t4, nil, "índice fora")
local _, t5 = Loot.retirar(conteudo, 0)
util.igual(t5, nil, "índice 0")
local _, t6 = Loot.retirar(conteudo, 1.5)
util.igual(t6, nil, "índice fracionado")
local _, t7 = Loot.retirar(conteudo, 1, 0)
util.igual(t7, nil, "quanto 0")
local _, t8 = Loot.retirar(conteudo, 1, 0 / 0)
util.igual(t8, nil, "quanto NaN")

-- pente da arma no conteúdo (docs/armas.md §7.4): retirar preserva o pente do item levado e dos que ficam
local armas = { { id = "pistola", qtd = 1, pente = 6 }, { id = "pistola", qtd = 1, pente = 14 } }
local restante, levada = Loot.retirar(armas, 2)
util.igual((levada :: any).pente, 14, "retirar leva o pente do item")
util.igual(restante[1].pente, 6, "o que fica mantém o pente")
util.igual(armas[2].pente, 14, "entrada intacta")

-- penteSorteado: faixa 40%-100% da capacidade
util.igual(Loot.penteSorteado(30, { 0.4, 1 }, util.seq({ 0 })), 12, "mínimo: 40% de 30")
util.igual(Loot.penteSorteado(30, { 0.4, 1 }, util.seq({ 1 })), 30, "máximo: cheio")
util.igual(Loot.penteSorteado(17, { 0.4, 1 }, util.seq({ 0.5 })), 12, "meio: 70% de 17 arredondado")
util.igual(Loot.penteSorteado(1, { 0.4, 1 }, util.seq({ 0 })), 1, "lançador de 1 tiro nunca nasce vazio")
util.igual(Loot.penteSorteado(5, { 0.4, 1 }, util.seq({ 0 })), 2, "tubo de 5: 40% = 2")
util.igual(Loot.penteSorteado(30, { 0.4, 1 }, util.seq({ 5 })), 30, "rng fora de faixa é limitado")
for i = 1, 50 do
	local n = Loot.penteSorteado(15, { 0.4, 1 }, util.rng(i))
	util.igual(n >= 6 and n <= 15, true, "pente sorteado dentro da faixa")
end

print("Loot.spec ok")
