--!strict
-- Regras do loot: sorteio do conteúdo de uma caixa e retirada de itens de um conteúdo. Puro (sem Roblox). Dono: P6.

local Loot = {}

-- `pente` (opcional): balas no pente de uma arma de fogo achada no chão (docs/armas.md §7.4)
export type Item = { id: string, qtd: number, pente: number? }
export type Entrada = { id: string, peso: number, qtd: { number } }
export type Tabela = { rolagens: { number }, itens: { Entrada } }

-- Inteiro em [min, max] com rng em [0, 1). Aceita rng que devolva 1.
local function inteiroEntre(min: number, max: number, rng: () -> number): number
	local a = math.floor(min)
	local b = math.max(a, math.floor(max))
	local r = math.clamp(rng(), 0, 0.999999999)
	return a + math.floor(r * (b - a + 1))
end

local function escolher(entradas: { Entrada }, total: number, rng: () -> number): Entrada?
	local alvo = math.clamp(rng(), 0, 0.999999999) * total
	local ultimo: Entrada? = nil
	for _, e in entradas do
		if e.peso > 0 then
			ultimo = e
			alvo -= e.peso
			if alvo < 0 then
				return e
			end
		end
	end
	return ultimo
end

-- N rolagens (rolagens = {min, max}); cada uma escolhe um item por peso e uma qtd em {min, max} (no mínimo 1).
-- Itens repetidos somam num só (na ordem em que apareceram). Ordem de uso do rng: nº de rolagens; depois, por
-- rolagem, o item e a quantidade.
function Loot.sortear(tabela: Tabela, rng: () -> number): { Item }
	local total = 0
	for _, e in tabela.itens do
		total += math.max(0, e.peso)
	end
	local saida: { Item } = {}
	if total <= 0 then
		return saida
	end
	local rolagens = inteiroEntre(tabela.rolagens[1], tabela.rolagens[2], rng)
	local posicao: { [string]: Item } = {}
	for _ = 1, rolagens do
		local e = escolher(tabela.itens, total, rng)
		if e then
			local qtd = math.max(1, inteiroEntre(e.qtd[1], e.qtd[2], rng))
			local existente = posicao[e.id]
			if existente then
				existente.qtd += qtd
			else
				local novo = { id = e.id, qtd = qtd }
				posicao[e.id] = novo
				table.insert(saida, novo)
			end
		end
	end
	return saida
end

-- Pente de uma arma achada no chão: fração sorteada em faixa = {min, max} (Itens.penteLoot) da capacidade,
-- arredondada e no mínimo 1 bala (o lançador de 1 tiro nunca nasce vazio). rng em [0, 1).
function Loot.penteSorteado(capacidade: number, faixa: { number }, rng: () -> number): number
	local minimo = math.clamp(faixa[1], 0, 1)
	local maximo = math.clamp(faixa[2], minimo, 1)
	local fracao = minimo + math.clamp(rng(), 0, 1) * (maximo - minimo)
	return math.clamp(math.floor(capacidade * fracao + 0.5), 1, math.max(1, math.floor(capacidade)))
end

-- Tira `quanto` (nil = tudo) da entrada `indice`; some a entrada se zerar. Devolve (novo conteúdo, retirado).
-- Índice inválido ou quanto < 1: (cópia, nil). Não muta a entrada.
function Loot.retirar(conteudo: { Item }, indice: number, quanto: number?): ({ Item }, Item?)
	local novo: { Item } = {}
	for _, item in conteudo do
		table.insert(novo, { id = item.id, qtd = item.qtd, pente = item.pente })
	end
	if indice ~= indice or indice % 1 ~= 0 or indice < 1 or indice > #novo then
		return novo, nil
	end
	local item = novo[indice]
	local tira = item.qtd
	if quanto ~= nil then
		if quanto ~= quanto then
			return novo, nil
		end
		tira = math.min(item.qtd, math.floor(quanto))
	end
	if tira < 1 then
		return novo, nil
	end
	local retirado: Item = { id = item.id, qtd = tira, pente = item.pente }
	item.qtd -= tira
	if item.qtd <= 0 then
		table.remove(novo, indice)
	end
	return novo, retirado
end

return Loot
