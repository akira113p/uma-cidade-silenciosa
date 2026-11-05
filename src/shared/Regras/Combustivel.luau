--!strict
-- Regras do combustível: consumo do motor, encher o tanque, reserva, dados de recipiente. Puro (sem Roblox).
-- Contrato: docs/combustivel.md §3 e §10. `cfg` = Config/Combustivel. Nenhuma função muda a entrada.
-- Unidades: litros, segundos.

local Combustivel = {}

export type Recipiente = { litros: number?, capacidade: number?, enche: string?, despeja: string? }

local function finito(n: number): number
	if n ~= n then
		return 0
	end
	return n
end

local function consumoParadoLps(tanque: number, cfg: any): number
	return tanque / cfg.autonomiaParadoSeg
end

local function consumoMaxLps(tanque: number, cfg: any): number
	return tanque / cfg.autonomiaMaxSeg
end

-- L/s com o motor ligado. fracVel = |velocidade ao longo do chassi| / velMax (0..1); pedal = -1..1.
-- Parado (fracVel 0) gasta só o consumo parado, mesmo com o pedal pisado; na velMax com pedal a fundo gasta o máximo.
function Combustivel.consumoLps(tanque: number, fracVel: number, pedal: number, cfg: any): number
	local parado = consumoParadoLps(tanque, cfg)
	local maximo = consumoMaxLps(tanque, cfg)
	local f = math.clamp(finito(fracVel), 0, 1)
	local p = math.clamp(math.abs(finito(pedal)), 0, 1)
	return parado + (maximo - parado) * f * (0.4 + 0.6 * p)
end

-- Novo nível do tanque depois de `dt` segundos de motor ligado (nunca abaixo de 0).
function Combustivel.consumir(
	litros: number,
	dt: number,
	tanque: number,
	fracVel: number,
	pedal: number,
	cfg: any
): number
	local gasto = Combustivel.consumoLps(tanque, fracVel, pedal, cfg) * math.max(0, finito(dt))
	return math.max(0, litros - gasto)
end

-- Põe `quantidade` L no tanque. Devolve (novo nível, quanto foi aceito, sobra que não coube).
function Combustivel.encher(atual: number, tanque: number, quantidade: number): (number, number, number)
	local q = math.max(0, finito(quantidade))
	local nivel = math.clamp(finito(atual), 0, math.max(0, tanque))
	local novo = math.min(math.max(0, tanque), nivel + q)
	local aceito = novo - nivel
	return novo, aceito, q - aceito
end

-- 0..1 (tanque 0 vale 0).
function Combustivel.fracao(atual: number, tanque: number): number
	if tanque <= 0 then
		return 0
	end
	return math.clamp(finito(atual) / tanque, 0, 1)
end

-- true se o tanque está na reserva (fração <= cfg.fracaoReserva), inclusive vazio.
function Combustivel.reserva(atual: number, tanque: number, cfg: any): boolean
	return Combustivel.fracao(atual, tanque) <= cfg.fracaoReserva
end

-- Dados do recipiente `id` em cfg.recipientes (nil se o item não é recipiente).
function Combustivel.recipiente(id: string, cfg: any): Recipiente?
	return cfg.recipientes[id]
end

-- Id do item depois de uma ação: "encher" (vazio vira cheio) ou "despejar" (cheio vira vazio). nil se não se aplica.
function Combustivel.trocarRecipiente(id: string, cfg: any, acao: string): string?
	local r = Combustivel.recipiente(id, cfg)
	if r == nil then
		return nil
	end
	if acao == "encher" then
		return r.enche
	elseif acao == "despejar" then
		return r.despeja
	end
	return nil
end

return Combustivel
