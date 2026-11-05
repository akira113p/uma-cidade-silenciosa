--!strict
-- Regras puras dos itens no chão (docs/itens-no-mundo.md §3-B): sorteio por ponto Loot, leque de morte e limite de itens.
-- Sem Instance nem Vector3: vetores são tabelas {x,y,z} (como nas outras Regras).

-- No Roblox o require é por instância; no Lune (testes) é por caminho relativo ao arquivo.
local function carregar(nome: string): any
	if typeof(script) == "Instance" then
		return require((script :: any).Parent:WaitForChild(nome))
	end
	return (require :: any)("./" .. nome)
end

local Loot: { sortear: (tabela: any, rng: () -> number) -> { { id: string, qtd: number } } } = carregar("Loot")

export type Vec = { x: number, y: number, z: number }
export type Sorteio = { id: string, qtd: number }
export type ConfigEspalhar = { raioMin: number, raioMax: number, cima: number }
export type ItemChao = { t: number, id: any, largado: boolean }

local JITTER = 0.25 -- fração do setor angular (360°/n) sorteada para mais ou para menos

local ItensChao = {}

-- Com probabilidade `chance` sorteia na tabela de loot e fica com a 1ª entrada (um item por ponto); senão nil.
-- Ordem do rng: a chance primeiro, depois Loot.sortear.
function ItensChao.sortearPonto(tabela: any, rng: () -> number, chance: number): Sorteio?
	if tabela == nil then
		return nil
	end
	local r = rng()
	if chance <= 0 or (chance < 1 and r >= chance) then
		return nil
	end
	local itens = Loot.sortear(tabela, rng)
	local primeiro = itens[1]
	if primeiro == nil then
		return nil
	end
	return { id = primeiro.id, qtd = primeiro.qtd }
end

-- n velocidades {x,y,z} para o leque da morte: ângulos uniformes em 360° (fase sorteada) com jitter de ±25% do setor, para
-- nunca se sobreporem. Horizontal = raio × 2 com raio em [raioMin, raioMax]; vertical = cima.
function ItensChao.velocidadesEspalhar(n: number, rng: () -> number, cfg: ConfigEspalhar): { Vec }
	local saida: { Vec } = {}
	local contagem = math.max(0, math.floor(n))
	if contagem == 0 then
		return saida
	end
	local setor = 2 * math.pi / contagem
	local fase = rng() * 2 * math.pi
	for i = 1, contagem do
		local angulo = fase + (i - 1) * setor + (rng() * 2 - 1) * JITTER * setor
		local raio = cfg.raioMin + rng() * (cfg.raioMax - cfg.raioMin)
		local horizontal = raio * 2
		table.insert(saida, { x = math.cos(angulo) * horizontal, y = cfg.cima, z = math.sin(angulo) * horizontal })
	end
	return saida
end

-- Ids dos itens `largado` mais antigos (menor t primeiro) que excedem `max` vivos. Só largados entram na lista; item de ponto
-- conta no total mas nunca é removido (se só sobrar de ponto acima do limite, devolve vazio).
function ItensChao.removerExcedente(itens: { ItemChao }, max: number): { any }
	local remover: { any } = {}
	local excesso = #itens - math.max(0, math.floor(max))
	if excesso <= 0 then
		return remover
	end
	local largados: { ItemChao } = {}
	for _, item in itens do
		if item.largado then
			table.insert(largados, item)
		end
	end
	table.sort(largados, function(a, b)
		return a.t < b.t
	end)
	for i = 1, math.min(excesso, #largados) do
		table.insert(remover, largados[i].id)
	end
	return remover
end

return ItensChao
