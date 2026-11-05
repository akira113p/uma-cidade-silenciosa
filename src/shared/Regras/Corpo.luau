--!strict
-- Corpo: dano, cura e efeitos por partes (docs/calculos.md §3). Pura: não muta a entrada. Dono: P5.

export type Corpo = { [string]: number }
export type CfgCorpo = {
	partes: { [string]: { vida: number, fatal: boolean } },
	ordem: { string },
	transbordoParaTorso: number,
	multPernaZerada: number,
	queda: { alturaSegura: number, danoPorStud: number },
}

local Corpo = {}

local function copiar(c: Corpo): Corpo
	return table.clone(c)
end

local function morreu(c: Corpo, cfg: CfgCorpo): boolean
	for _, parte in cfg.ordem do
		if cfg.partes[parte].fatal and c[parte] <= 0 then
			return true
		end
	end
	return false
end

function Corpo.novo(cfg: CfgCorpo): Corpo
	local c = {}
	for _, parte in cfg.ordem do
		c[parte] = cfg.partes[parte].vida
	end
	return c
end

-- Devolve (novo corpo, morreu). O que passa da vida da parte vai em `transbordoParaTorso` para o torso.
function Corpo.dano(c: Corpo, parte: string, valor: number, cfg: CfgCorpo): (Corpo, boolean)
	assert(cfg.partes[parte] ~= nil and c[parte] ~= nil, "Corpo.dano: parte desconhecida: " .. tostring(parte))
	local novo = copiar(c)
	if valor > 0 then
		local sobra = novo[parte] - valor
		novo[parte] = math.max(0, sobra)
		if sobra < 0 and parte ~= "Torso" then
			novo.Torso = math.max(0, novo.Torso + sobra * cfg.transbordoParaTorso)
		end
	end
	return novo, morreu(novo, cfg)
end

-- Cura a parte com maior fração de vida faltando (empate: ordem do Config). Devolve (novo, parte curada ou nil).
function Corpo.curar(c: Corpo, valor: number, cfg: CfgCorpo): (Corpo, string?)
	local novo = copiar(c)
	if valor <= 0 then
		return novo, nil
	end
	local melhor: string? = nil
	local maiorFalta = 1e-9
	for _, parte in cfg.ordem do
		local maximo = cfg.partes[parte].vida
		local falta = (maximo - novo[parte]) / maximo
		if falta > maiorFalta then
			melhor = parte
			maiorFalta = falta
		end
	end
	if melhor == nil then
		return novo, nil
	end
	novo[melhor] = math.min(cfg.partes[melhor].vida, novo[melhor] + valor)
	return novo, melhor
end

function Corpo.sortearParte(sorteio: { { parte: string, peso: number } }, rng: () -> number): string
	assert(#sorteio > 0, "Corpo.sortearParte: sorteio vazio")
	local total = 0
	for _, e in sorteio do
		total += e.peso
	end
	local alvo = rng() * total
	local acumulado = 0
	for _, e in sorteio do
		acumulado += e.peso
		if alvo < acumulado then
			return e.parte
		end
	end
	return sorteio[#sorteio].parte
end

function Corpo.multVelocidade(c: Corpo, cfg: CfgCorpo): number
	local mult = 1
	for _, parte in { "PernaE", "PernaD" } do
		if c[parte] <= 0 then
			mult *= cfg.multPernaZerada
		end
	end
	return mult
end

function Corpo.podeCorrer(c: Corpo): boolean
	return c.PernaE > 0 and c.PernaD > 0
end

function Corpo.bracoZerado(c: Corpo): boolean
	return c.BracoE <= 0 or c.BracoD <= 0
end

-- Dano total da queda (a Vida divide entre as duas pernas).
function Corpo.danoQueda(altura: number, cfg: CfgCorpo): number
	return math.max(0, (altura - cfg.queda.alturaSegura) * cfg.queda.danoPorStud)
end

return Corpo
