--!strict
-- Regra pura do som (docs/calculos.md §1): ruído emitido, propagação, alcance, ambiente e modo de passo.
-- Dono: P3. Sem game/Instance: lê só Config/Som e Config/Tempo (tabelas de números), que o Roblox e o Lune carregam.

type ConfigSom = {
	metrosPorStud: number,
	tetoAlcance: number,
	dbPorParede: number,
	maxParedes: number,
	acoes: { [string]: number },
	passosPorSegundo: { [string]: number },
	superficies: { [string]: { db: number, materiais: { string } } },
	superficiePadrao: string,
	ambiente: { [string]: number },
	velocidadeMinimaPasso: number,
}

type ConfigTempo = {
	noiteComeca: number,
	noiteTermina: number,
}

-- No Roblox o require é por instância; no Lune (testes) é por caminho relativo ao arquivo.
local function carregar(nome: string): any
	if typeof(script) == "Instance" then
		local config = (script :: any).Parent.Parent:WaitForChild("Config")
		return require(config:WaitForChild(nome))
	end
	return (require :: any)("../Config/" .. nome)
end

local cfg: ConfigSom = carregar("Som")
local tempo: ConfigTempo = carregar("Tempo")

export type ModoPasso = "parado" | "agachado" | "andar" | "correr"

local Som = {}

-- material (nome do Enum) → superfície, montado uma vez a partir de Config/Som.superficies
local superficiePorMaterial: { [string]: string } = {}
for nomeSuperficie, def in cfg.superficies do
	for _, material in def.materiais do
		superficiePorMaterial[material] = nomeSuperficie
	end
end

local function log10(x: number): number
	return math.log(x, 10)
end

function Som.superficieDeMaterial(nomeMaterial: string): string
	return superficiePorMaterial[nomeMaterial] or cfg.superficiePadrao
end

-- "gramaBaixa" → "PassoGramaBaixa" (nome do catálogo Config/Sons)
function Som.nomePasso(superficie: string): string
	return "Passo" .. string.upper(string.sub(superficie, 1, 1)) .. string.sub(superficie, 2)
end

-- dB emitido = base da ação + modificador da superfície (a superfície só entra quando informada: passos)
function Som.emitido(acao: string, superficie: string?): number
	local base = cfg.acoes[acao]
	assert(base ~= nil, "Som.emitido: ação desconhecida: " .. tostring(acao))
	if superficie == nil then
		return base
	end
	local def = cfg.superficies[superficie] or cfg.superficies[cfg.superficiePadrao]
	return base + def.db
end

-- Lei do inverso do quadrado: -6 dB a cada dobro de distância; distância < 1 m vale 1 m; cada parede -10 dB (máx. 3).
function Som.recebido(emitido: number, distanciaStuds: number, paredes: number): number
	local metros = math.max(1, distanciaStuds * cfg.metrosPorStud)
	local usadas = math.clamp(math.floor(paredes), 0, cfg.maxParedes)
	return emitido - 20 * log10(metros) - cfg.dbPorParede * usadas
end

-- Distância (studs) até onde um ouvinte com `margem` ainda percebe o som. 0 = inaudível nem a 1 m. Teto de Config.
function Som.alcance(emitido: number, ambiente: number, margem: number): number
	local folga = emitido - ambiente - margem
	-- folga 0 também é inaudível: a tabela 1.4 trata o empate (ex.: 25 dB em ambiente 25) como 0, não como 3,6 studs
	if folga <= 0 then
		return 0
	end
	local studs = 10 ^ (folga / 20) / cfg.metrosPorStud
	return math.min(studs, cfg.tetoAlcance)
end

-- >= 0 → o ouvinte percebe o som
function Som.excesso(recebido: number, ambiente: number, margem: number): number
	return recebido - (ambiente + margem)
end

-- Chuva/tempestade vêm do clima; senão dia/noite pelo relógio (ClockTime 0..24).
function Som.condicao(clockTime: number, clima: string?): string
	if clima == "chuva" or clima == "tempestade" then
		return clima
	end
	if clockTime >= tempo.noiteComeca or clockTime < tempo.noiteTermina then
		return "noite"
	end
	return "dia"
end

function Som.ambiente(condicao: string): number
	return cfg.ambiente[condicao] or cfg.ambiente.dia
end

function Som.modoPasso(velocidade: number, agachado: boolean, correndo: boolean): ModoPasso
	if velocidade < cfg.velocidadeMinimaPasso then
		return "parado"
	end
	if agachado then
		return "agachado"
	end
	if correndo then
		return "correr"
	end
	return "andar"
end

-- RmsLevel do AudioAnalyzer (0..1) → dB do jogo
function Som.vozParaDb(rms: number): number
	if not (rms > 0) then
		return 0
	end
	return math.clamp(20 * log10(rms) + 90, 0, 120)
end

return Som
