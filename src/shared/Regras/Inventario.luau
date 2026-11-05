--!strict
-- Regras do inventário: lista de posições com pilhas. Puro (sem Roblox): quem chama passa Config/Itens.itens. Dono: P6.
-- Posição vazia = false (não nil), para o tamanho do inventário ser #inv. Nenhuma função muta a entrada.

local Inventario = {}

-- `pente` (opcional): balas no pente de uma arma de fogo (docs/armas.md §7.4). nil = nunca foi usada/equipada.
export type Pilha = { id: string, qtd: number, pente: number? }
export type Inv = { [number]: Pilha | false }
export type Itens = { [string]: { pilha: number? } }

export type Ocupado = { slot: number, id: string, qtd: number, pente: number? }

local function copiar(inv: Inv): Inv
	local novo: Inv = {}
	for i = 1, #inv do
		local p = inv[i]
		novo[i] = if p then { id = p.id, qtd = p.qtd, pente = p.pente } else false
	end
	return novo
end

-- Tamanho máximo da pilha; nil se o item não existe.
local function tamanhoPilha(itens: Itens, id: string, padrao: number?): number?
	local def = itens[id]
	if def == nil then
		return nil
	end
	return math.max(1, math.floor(def.pilha or padrao or 1))
end

function Inventario.novo(slots: number): Inv
	local inv: Inv = {}
	for i = 1, math.max(0, math.floor(slots)) do
		inv[i] = false
	end
	return inv
end

-- Empilha primeiro nas pilhas do mesmo item, depois nas posições vazias. Devolve (novo, sobra que não coube).
-- Item desconhecido: nada entra e a sobra é a quantidade inteira. qtd < 1 ou NaN: nada muda, sobra 0.
-- `pente` (opcional) vai em cada posição nova criada e só empilha em pilha de mesmo pente (armas têm pilha 1).
function Inventario.adicionar(
	inv: Inv,
	id: string,
	qtd: number,
	itens: Itens,
	padrao: number?,
	pente: number?
): (Inv, number)
	local novo = copiar(inv)
	local maximo = tamanhoPilha(itens, id, padrao)
	if qtd ~= qtd then
		return novo, 0
	end
	local resta = math.floor(qtd)
	if resta < 1 then
		return novo, 0
	end
	if maximo == nil then
		return novo, resta
	end
	for i = 1, #novo do
		local p = novo[i]
		if resta > 0 and p and p.id == id and p.pente == pente and p.qtd < maximo then
			local cabe = math.min(maximo - p.qtd, resta)
			p.qtd += cabe
			resta -= cabe
		end
	end
	for i = 1, #novo do
		if resta > 0 and not novo[i] then
			local poe = math.min(maximo, resta)
			novo[i] = { id = id, qtd = poe, pente = pente }
			resta -= poe
		end
	end
	return novo, resta
end

-- Quanto de `id` ainda cabe (pilhas incompletas + posições vazias).
function Inventario.espaco(inv: Inv, id: string, itens: Itens, padrao: number?): number
	local maximo = tamanhoPilha(itens, id, padrao)
	if maximo == nil then
		return 0
	end
	local total = 0
	for i = 1, #inv do
		local p = inv[i]
		if not p then
			total += maximo
		elseif p.id == id then
			total += math.max(0, maximo - p.qtd)
		end
	end
	return total
end

function Inventario.contar(inv: Inv, id: string): number
	local total = 0
	for i = 1, #inv do
		local p = inv[i]
		if p and p.id == id then
			total += p.qtd
		end
	end
	return total
end

-- Tira `qtd` de `id`, das primeiras posições para as últimas. Tem menos do que isso (ou qtd < 1): (cópia, false).
function Inventario.remover(inv: Inv, id: string, qtd: number): (Inv, boolean)
	local novo = copiar(inv)
	if qtd ~= qtd or qtd < 1 or qtd % 1 ~= 0 or Inventario.contar(inv, id) < qtd then
		return novo, false
	end
	local resta = qtd
	for i = 1, #novo do
		local p = novo[i]
		if resta > 0 and p and p.id == id then
			local tira = math.min(p.qtd, resta)
			p.qtd -= tira
			resta -= tira
			if p.qtd <= 0 then
				novo[i] = false
			end
		end
	end
	return novo, true
end

-- Transforma 1 `deId` em 1 `paraId` (ex.: galão vazio -> galão cheio), atômico: se não tem `deId`, `paraId` é
-- desconhecido ou o resultado não cabe, devolve (cópia do ORIGINAL, false), sem meia troca.
-- O item novo vai para a pilha incompleta do mesmo id ou para a primeira posição livre (que pode não ser a do `deId`).
function Inventario.trocar(inv: Inv, deId: string, paraId: string, itens: Itens, padrao: number?): (Inv, boolean)
	if tamanhoPilha(itens, paraId, padrao) == nil then
		return copiar(inv), false
	end
	local semDe, removeu = Inventario.remover(inv, deId, 1)
	if not removeu then
		return copiar(inv), false
	end
	local novo, sobra = Inventario.adicionar(semDe, paraId, 1, itens, padrao)
	if sobra > 0 then
		return copiar(inv), false
	end
	return novo, true
end

-- Tira de uma posição: tudo (qtd nil) ou até `qtd`. Posição inválida ou vazia: (cópia, nil).
function Inventario.retirarSlot(inv: Inv, slot: number, qtd: number?): (Inv, Pilha?)
	local novo = copiar(inv)
	if slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > #novo then
		return novo, nil
	end
	local p = novo[slot]
	if not p then
		return novo, nil
	end
	local tira = p.qtd
	if qtd ~= nil then
		if qtd ~= qtd then
			return novo, nil
		end
		tira = math.min(p.qtd, math.floor(qtd))
	end
	if tira < 1 then
		return novo, nil
	end
	local tirado: Pilha = { id = p.id, qtd = tira, pente = p.pente }
	p.qtd -= tira
	if p.qtd <= 0 then
		novo[slot] = false
	end
	return novo, tirado
end

-- Pente da arma na posição `slot` (nil: posição vazia ou arma que nunca foi usada).
function Inventario.pente(inv: Inv, slot: number): number?
	local p = inv[slot]
	return if p then p.pente else nil
end

-- Cópia com o pente da posição `slot` trocado (inteiro >= 0). Posição vazia ou valor inválido: cópia igual.
function Inventario.definirPente(inv: Inv, slot: number, pente: number): Inv
	local novo = copiar(inv)
	local p = novo[slot]
	if p and pente == pente and pente >= 0 and pente < math.huge then
		p.pente = math.floor(pente)
	end
	return novo
end

-- Pilhas na ordem das posições, sem as vazias.
function Inventario.lista(inv: Inv): { Pilha }
	local saida: { Pilha } = {}
	for i = 1, #inv do
		local p = inv[i]
		if p then
			table.insert(saida, { id = p.id, qtd = p.qtd, pente = p.pente })
		end
	end
	return saida
end

-- Igual a lista, mas com o número da posição (o cliente precisa dele para as teclas 1..8).
function Inventario.ocupados(inv: Inv): { Ocupado }
	local saida: { Ocupado } = {}
	for i = 1, #inv do
		local p = inv[i]
		if p then
			table.insert(saida, { slot = i, id = p.id, qtd = p.qtd, pente = p.pente })
		end
	end
	return saida
end

return Inventario
