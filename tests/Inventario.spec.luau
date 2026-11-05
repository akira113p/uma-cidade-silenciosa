local util = require("./util")
local Inventario = require("../src/shared/Regras/Inventario")
local Config = require("../src/shared/Config/Itens")

local itens = Config.itens
local padrao = Config.empilhamentoPadrao

local function qtdNo(inv: any, slot: number): number
	local p = inv[slot]
	return if p then p.qtd else 0
end

-- novo
local inv = Inventario.novo(Config.slots)
util.igual(#inv, 8, "tamanho")
util.igual(#Inventario.lista(inv), 0, "começa vazio")

-- empilhamento: enlatado tem pilha 3
local a, sobraA = Inventario.adicionar(inv, "enlatado", 2, itens, padrao)
util.igual(sobraA, 0, "sem sobra")
util.igual(Inventario.contar(a, "enlatado"), 2, "contou 2")
util.igual(Inventario.contar(inv, "enlatado"), 0, "entrada intacta")
local b, sobraB = Inventario.adicionar(a, "enlatado", 2, itens, padrao)
util.igual(sobraB, 0, "sem sobra 2")
util.igual(Inventario.contar(b, "enlatado"), 4, "contou 4")
util.igual(qtdNo(b, 1), 3, "primeira pilha cheia")
util.igual(qtdNo(b, 2), 1, "segunda pilha")
util.igual(Inventario.contar(a, "enlatado"), 2, "entrada de adicionar intacta")

-- completa a pilha parcial antes de abrir outra
local c = Inventario.adicionar(b, "enlatado", 2, itens, padrao)
util.igual(qtdNo(c, 2), 3, "completou a pilha parcial")
util.igual(qtdNo(c, 3), 0, "não abriu pilha à toa")

-- sobra: 8 posições de pilha 1 (faca); a 9ª não cabe
local cheio = inv
for _ = 1, 8 do
	cheio = Inventario.adicionar(cheio, "faca", 1, itens, padrao)
end
util.igual(Inventario.contar(cheio, "faca"), 8, "8 facas")
local depois, sobraCheio = Inventario.adicionar(cheio, "faca", 3, itens, padrao)
util.igual(sobraCheio, 3, "sobra total quando cheio")
util.igual(Inventario.contar(depois, "faca"), 8, "nada entrou")
local _, sobraBarra = Inventario.adicionar(cheio, "enlatado", 1, itens, padrao)
util.igual(sobraBarra, 1, "outro item também sobra")

-- sobra parcial: 1 posição livre de pilha 30 (munição) recebe 30 de 45
local quase = inv
for _ = 1, 7 do
	quase = Inventario.adicionar(quase, "faca", 1, itens, padrao)
end
local munido, sobraMun = Inventario.adicionar(quase, "municaoPistola", 45, itens, padrao)
util.igual(sobraMun, 15, "sobra parcial")
util.igual(Inventario.contar(munido, "municaoPistola"), 30, "entrou uma pilha")

-- espaço
util.igual(Inventario.espaco(inv, "enlatado", itens, padrao), 24, "espaço vazio: 8 x 3")
util.igual(Inventario.espaco(b, "enlatado", itens, padrao), 6 * 3 + 2, "espaço com pilha parcial")
util.igual(Inventario.espaco(cheio, "faca", itens, padrao), 0, "espaço cheio")
util.igual(Inventario.espaco(inv, "naoExiste", itens, padrao), 0, "espaço de item desconhecido")

-- item desconhecido e quantidades inválidas
local x, sobraX = Inventario.adicionar(inv, "naoExiste", 2, itens, padrao)
util.igual(sobraX, 2, "item desconhecido não entra")
util.igual(#Inventario.lista(x), 0, "nada entrou")
util.igual(select(2, Inventario.adicionar(inv, "enlatado", 0, itens, padrao)), 0, "qtd 0")
util.igual(select(2, Inventario.adicionar(inv, "enlatado", -3, itens, padrao)), 0, "qtd negativa")
util.igual(select(2, Inventario.adicionar(inv, "enlatado", 0 / 0, itens, padrao)), 0, "qtd NaN")
-- sem `padrao` e sem `pilha` no item: pilha 1
local so1 = Inventario.adicionar(inv, "x", 3, { x = {} }, nil)
util.igual(qtdNo(so1, 1), 1, "pilha padrão 1")
util.igual(Inventario.contar(so1, "x"), 3, "3 posições")

-- remover
local r, ok = Inventario.remover(c, "enlatado", 5)
util.igual(ok, true, "removeu")
util.igual(Inventario.contar(r, "enlatado"), 1, "restou 1")
util.igual(Inventario.contar(c, "enlatado"), 6, "entrada de remover intacta")
util.igual(r[1], false, "posição esvaziada")
local r2, ok2 = Inventario.remover(c, "enlatado", 7)
util.igual(ok2, false, "remover mais do que tem")
util.igual(Inventario.contar(r2, "enlatado"), 6, "e não muda")
local _, ok3 = Inventario.remover(c, "enlatado", 0)
util.igual(ok3, false, "remover 0")
local _, ok4 = Inventario.remover(c, "enlatado", 1.5)
util.igual(ok4, false, "remover fracionado")
local _, ok5 = Inventario.remover(c, "agua", 1)
util.igual(ok5, false, "remover o que não tem")

-- retirarSlot
local s1, t1 = Inventario.retirarSlot(c, 1)
util.igual((t1 :: any).id, "enlatado", "retirou tudo: id")
util.igual((t1 :: any).qtd, 3, "retirou tudo: qtd")
util.igual(s1[1], false, "posição esvaziada")
util.igual(qtdNo(c, 1), 3, "entrada de retirarSlot intacta")
local s2, t2 = Inventario.retirarSlot(c, 1, 2)
util.igual((t2 :: any).qtd, 2, "retirou 2")
util.igual(qtdNo(s2, 1), 1, "sobrou 1")
local _, t3 = Inventario.retirarSlot(c, 1, 99)
util.igual((t3 :: any).qtd, 3, "retirar mais que tem leva o que tem")
local _, t4 = Inventario.retirarSlot(c, 5)
util.igual(t4, nil, "posição vazia")
local _, t5 = Inventario.retirarSlot(c, 0)
util.igual(t5, nil, "posição 0")
local _, t6 = Inventario.retirarSlot(c, 9)
util.igual(t6, nil, "posição 9")
local _, t7 = Inventario.retirarSlot(c, 1.5)
util.igual(t7, nil, "posição fracionada")
local _, t8 = Inventario.retirarSlot(c, 1, 0)
util.igual(t8, nil, "qtd 0")

-- lista e ocupados
local mix = Inventario.adicionar(Inventario.adicionar(inv, "agua", 1, itens, padrao), "faca", 1, itens, padrao)
local l = Inventario.lista(mix)
util.igual(#l, 2, "lista: 2 pilhas")
util.igual(l[1].id, "agua", "lista: ordem das posições")
local semPrimeira = Inventario.retirarSlot(mix, 1)
local o = Inventario.ocupados(semPrimeira)
util.igual(#o, 1, "ocupados: 1")
util.igual(o[1].slot, 2, "ocupados: guarda a posição")
util.igual(o[1].id, "faca", "ocupados: id")

-- todo item do Config cabe sozinho num inventário vazio
for id in itens do
	local _, sobraItem = Inventario.adicionar(inv, id, 1, itens, padrao)
	util.igual(sobraItem, 0, "cabe " .. id)
end

-- pente da arma (docs/armas.md §7.4): preservado em adicionar, retirarSlot, lista, ocupados, remover de outro item
local comPente = Inventario.adicionar(inv, "pistola", 1, itens, padrao, 7)
util.igual(Inventario.pente(comPente, 1), 7, "pente guardado ao adicionar")
util.igual(Inventario.pente(inv, 1), nil, "entrada intacta (sem pente)")
util.igual(Inventario.pente(comPente, 2), nil, "posição vazia sem pente")
local semPente = Inventario.adicionar(inv, "pistola", 1, itens, padrao)
util.igual(Inventario.pente(semPente, 1), nil, "arma sem pente = nil")
local novoPente = Inventario.definirPente(comPente, 1, 3.9)
util.igual(Inventario.pente(novoPente, 1), 3, "definirPente trunca")
util.igual(Inventario.pente(comPente, 1), 7, "definirPente não muta a entrada")
util.igual(Inventario.pente(Inventario.definirPente(comPente, 1, 0), 1), 0, "pente 0 vale")
util.igual(Inventario.pente(Inventario.definirPente(comPente, 1, -1), 1), 7, "pente negativo ignorado")
util.igual(Inventario.pente(Inventario.definirPente(comPente, 1, 0 / 0), 1), 7, "pente NaN ignorado")
util.igual(Inventario.pente(Inventario.definirPente(comPente, 5, 4), 5), nil, "posição vazia: nada muda")
local retirada, tirada = Inventario.retirarSlot(comPente, 1)
util.igual((tirada :: any).pente, 7, "largar leva o pente")
util.igual(retirada[1], false, "slot esvaziado")
local devolta = Inventario.adicionar(retirada, tirada.id, tirada.qtd, itens, padrao, tirada.pente)
util.igual(Inventario.pente(devolta, 1), 7, "pegar de volta traz o mesmo pente")
util.igual(Inventario.lista(comPente)[1].pente, 7, "lista leva o pente")
util.igual(Inventario.ocupados(comPente)[1].pente, 7, "ocupados leva o pente")
local duas = Inventario.adicionar(comPente, "pistola", 1, itens, padrao, 12)
util.igual(Inventario.pente(duas, 1), 7, "duas armas: pente próprio (1)")
util.igual(Inventario.pente(duas, 2), 12, "duas armas: pente próprio (2)")
local comMun = Inventario.adicionar(comPente, "municaoPistola", 10, itens, padrao)
local semMun = Inventario.remover(comMun, "municaoPistola", 4)
util.igual(Inventario.pente(semMun, 1), 7, "remover munição não mexe no pente da arma")
util.igual(Inventario.contar(semMun, "municaoPistola"), 6, "munição removida")

-- trocar (recipientes de gasolina): atômico, sem meia troca
local comGalao = Inventario.adicionar(inv, "galaoVazio", 1, itens, padrao)
local cheioG, okT = Inventario.trocar(comGalao, "galaoVazio", "galaoGasolina", itens, padrao)
util.igual(okT, true, "trocar: galão vazio vira cheio")
util.igual(Inventario.contar(cheioG, "galaoGasolina"), 1, "trocar: tem o cheio")
util.igual(Inventario.contar(cheioG, "galaoVazio"), 0, "trocar: perdeu o vazio")
util.igual(Inventario.contar(comGalao, "galaoVazio"), 1, "trocar: entrada intacta")
-- pilha: 2 garrafas vazias -> 1 cheia + 1 vazia
local duasG = Inventario.adicionar(inv, "garrafaVazia", 2, itens, padrao)
local umaCheia, okG = Inventario.trocar(duasG, "garrafaVazia", "garrafaGasolina", itens, padrao)
util.igual(okG, true, "trocar: garrafa de pilha")
util.igual(Inventario.contar(umaCheia, "garrafaVazia"), 1, "trocar: sobrou 1 vazia")
util.igual(Inventario.contar(umaCheia, "garrafaGasolina"), 1, "trocar: ganhou 1 cheia")
util.igual(Inventario.contar(duasG, "garrafaVazia"), 2, "trocar: entrada de pilha intacta")
-- não tem o item de origem
local semOrigem, okS = Inventario.trocar(inv, "galaoVazio", "galaoGasolina", itens, padrao)
util.igual(okS, false, "trocar: sem o item de origem")
util.igual(#Inventario.lista(semOrigem), 0, "trocar sem origem: inventário igual")
-- item de destino desconhecido
local desconhecido, okD = Inventario.trocar(comGalao, "galaoVazio", "naoExiste", itens, padrao)
util.igual(okD, false, "trocar: destino desconhecido")
util.igual(Inventario.contar(desconhecido, "galaoVazio"), 1, "trocar destino desconhecido: sem meia troca")
-- inventário lotado: a troca de um item de pilha 1 libera o próprio lugar e cabe
local lotado = inv
for _ = 1, 7 do
	lotado = Inventario.adicionar(lotado, "faca", 1, itens, padrao)
end
lotado = Inventario.adicionar(lotado, "galaoVazio", 1, itens, padrao)
util.igual(#Inventario.lista(lotado), 8, "trocar: inventário lotado")
local trocouLotado, okL = Inventario.trocar(lotado, "galaoVazio", "galaoGasolina", itens, padrao)
util.igual(okL, true, "trocar: lotado, mas a troca libera o próprio lugar")
util.igual(Inventario.contar(trocouLotado, "galaoGasolina"), 1, "trocar lotado: ganhou o cheio")
util.igual(Inventario.contar(trocouLotado, "faca"), 7, "trocar lotado: facas intactas")
-- não cabe: 6 facas + pilha cheia de garrafas de gasolina + 2 garrafas vazias (8 posições). Trocar 1 vazia deixa a
-- pilha de vazias ocupada e não há posição nem pilha incompleta para o cheio: nada muda.
local semEspaco = inv
for _ = 1, 6 do
	semEspaco = Inventario.adicionar(semEspaco, "faca", 1, itens, padrao)
end
semEspaco = Inventario.adicionar(semEspaco, "garrafaGasolina", 3, itens, padrao) -- pilha cheia (3)
semEspaco = Inventario.adicionar(semEspaco, "garrafaVazia", 2, itens, padrao) -- 8 posições ocupadas
util.igual(Inventario.espaco(semEspaco, "garrafaGasolina", itens, padrao), 0, "trocar: sem espaço para o cheio")
local intacto, okN = Inventario.trocar(semEspaco, "garrafaVazia", "garrafaGasolina", itens, padrao)
util.igual(okN, false, "trocar: não cabe, devolve false")
util.igual(Inventario.contar(intacto, "garrafaVazia"), 2, "trocar sem espaço: sem meia troca (vazias intactas)")
util.igual(Inventario.contar(intacto, "garrafaGasolina"), 3, "trocar sem espaço: nada de cheio novo")
util.igual(Inventario.contar(intacto, "faca"), 6, "trocar sem espaço: facas intactas")

print("Inventario.spec ok")
