--!strict
-- Regra pura do som (docs/som.md §3; resumo em docs/calculos.md §1): composição de camadas em bandas, propagação pelo ar e pelo chão,
-- mascaramento, alcance, modo de passo. Mantém as funções de número único (emitido, recebido, alcance, excesso) do som v1.
-- Dono: P3. Sem game/Instance: lê só Config/Som e Config/Tempo (tabelas de números), que o Roblox e o Lune carregam.

export type Bandas = { grave: number, medio: number, agudo: number } -- dB a 1 m, por banda
export type Camada = { nome: string?, nivel: number, perfil: Bandas, chao: number? }
export type Composto = { bandas: Bandas, chao: number?, db: number, dominante: string? }
export type Limiar = { grave: number, medio: number, agudo: number, chao: number? }
export type AmbienteBandas = { grave: number, medio: number, agudo: number, chao: number }

type PerfilAcao = { perfil: Bandas, chao: number? }
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
	ambienteBandas: { [string]: AmbienteBandas },
	velocidadeMinimaPasso: number,
	absorcao: Bandas,
	parede: Bandas,
	chao: { atenuacao: number, alturaMesmoPiso: number, outroPiso: number },
	alcanceIteracoes: number,
	queda: {
		alturaRef: number,
		padrao: string,
		porTipo: { [string]: string },
		classes: { [string]: { nivel: number, perfil: Bandas } },
	},
	perfilPadrao: Bandas,
	perfisAcao: { [string]: PerfilAcao },
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

export type ModoPasso = "parado" | "deitado" | "agachado" | "andar" | "correr"

local BANDAS = { "grave", "medio", "agudo" }
local SEM_LIMIAR: Limiar = { grave = 0, medio = 0, agudo = 0 } -- ouvinte de referência: limiar 0 em todas as bandas, sem chão

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
-- (som v1, número único; o som v2 usa propagarAr/propagarChao por banda)
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

-- Ruído ambiente por banda (e pelo chão) da condição (docs/som.md §3.4). Condição desconhecida cai no dia.
function Som.ambienteBandas(condicao: string): AmbienteBandas
	return cfg.ambienteBandas[condicao] or cfg.ambienteBandas.dia
end

-- `deitado` vem por último e é opcional: quem chama com 3 argumentos (som v1) continua valendo. Deitado vence agachado (o servidor liga os dois).
function Som.modoPasso(velocidade: number, agachado: boolean, correndo: boolean, deitado: boolean?): ModoPasso
	if velocidade < cfg.velocidadeMinimaPasso then
		return "parado"
	end
	if deitado == true then
		return "deitado"
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

-- Som v2 -----------------------------------------------------------------------------------------------------------------

-- Soma de energia (§3.1): duas camadas iguais = +3 dB; uma 10 dB abaixo soma +0,4 dB. Lista vazia = -inf.
function Som.somar(niveis: { number }): number
	if #niveis == 0 then
		return -math.huge
	end
	local soma = 0
	for _, n in niveis do
		soma += 10 ^ (n / 10)
	end
	return 10 * log10(soma)
end

-- Compõe camadas { nome?, nivel, perfil, chao? } em bandas, vibração pelo chão e db = max(bandas). `dominante` = nome da camada de maior pico.
function Som.compor(camadas: { Camada }): Composto
	local porBanda: { [string]: { number } } = { grave = {}, medio = {}, agudo = {} }
	local chaos: { number } = {}
	local melhor, dominante = -math.huge, nil :: string?
	for _, c in camadas do
		for _, b in BANDAS do
			table.insert(porBanda[b], c.nivel + (c.perfil :: any)[b])
		end
		if c.chao ~= nil then
			table.insert(chaos, c.chao)
		end
		local pico = c.nivel + math.max(c.perfil.grave, c.perfil.medio, c.perfil.agudo)
		if pico > melhor then
			melhor, dominante = pico, c.nome
		end
	end
	local bandas: Bandas = {
		grave = Som.somar(porBanda.grave),
		medio = Som.somar(porBanda.medio),
		agudo = Som.somar(porBanda.agudo),
	}
	return {
		bandas = bandas,
		chao = if #chaos > 0 then Som.somar(chaos) else nil,
		db = math.max(bandas.grave, bandas.medio, bandas.agudo),
		dominante = dominante,
	}
end

-- Bandas e vibração de uma ação de número único (Ruido.emitir): `db` + perfil de Config/Som.perfisAcao[tipo] (tipo sem entrada = plano, sem chão).
function Som.bandasDeAcao(db: number, tipo: string): (Bandas, number?)
	local def = cfg.perfisAcao[tipo]
	local p = if def then def.perfil else cfg.perfilPadrao
	local bandas: Bandas = { grave = db + p.grave, medio = db + p.medio, agudo = db + p.agudo }
	return bandas, if def and def.chao ~= nil then db + def.chao else nil
end

-- Banda `banda` ("grave" | "medio" | "agudo") a `distanciaStuds` do emissor, com `paredes` no caminho (§3.2).
function Som.propagarAr(nivel: number, banda: string, distanciaStuds: number, paredes: number): number
	local metros = math.max(1, distanciaStuds * cfg.metrosPorStud)
	local usadas = math.clamp(math.floor(paredes), 0, cfg.maxParedes)
	return nivel - 20 * log10(metros) - (cfg.absorcao :: any)[banda] * metros - (cfg.parede :: any)[banda] * usadas
end

-- Vibração pelo chão (§3.3): cai o dobro do ar, ignora parede, outro andar (|Δy| > alturaMesmoPiso) tira `outroPiso`.
function Som.propagarChao(nivel: number, distanciaStuds: number, dy: number): number
	local metros = math.max(1, distanciaStuds * cfg.metrosPorStud)
	local penalidade = if math.abs(dy) > cfg.chao.alturaMesmoPiso then cfg.chao.outroPiso else 0
	return nivel - cfg.chao.atenuacao * log10(metros) - penalidade
end

-- Maior distância (studs) em que `excessoEm(d) >= 0`, de 0 a tetoAlcance, para uma função monótona decrescente (§3.6). Busca binária.
function Som.buscarAlcance(excessoEm: (number) -> number): number
	if excessoEm(0) <= 0 then
		return 0
	end
	if excessoEm(cfg.tetoAlcance) >= 0 then
		return cfg.tetoAlcance
	end
	local baixo, alto = 0, cfg.tetoAlcance
	for _ = 1, cfg.alcanceIteracoes do
		local meio = (baixo + alto) / 2
		if excessoEm(meio) >= 0 then
			baixo = meio
		else
			alto = meio
		end
	end
	return baixo
end

-- Alcance (studs, sem paredes) de um evento para um ouvinte com `limiar` (padrão: referência, limiar 0 e sem chão = o nível 1 de hoje), e a
-- banda que vence ("grave" | "medio" | "agudo" | "chao"). É o que o HUD, o debug e o RollOffMaxDistance mostram.
function Som.alcanceEvento(bandas: Bandas, chao: number?, ambiente: AmbienteBandas, limiar: Limiar?): (number, string)
	local lim = limiar or SEM_LIMIAR
	local function melhor(d: number): (number, string)
		local x, qual = -math.huge, "medio"
		for _, b in BANDAS do
			local v = Som.propagarAr((bandas :: any)[b], b, d, 0) - ((ambiente :: any)[b] + (lim :: any)[b])
			if v > x then
				x, qual = v, b
			end
		end
		if chao ~= nil and lim.chao ~= nil then
			local v = Som.propagarChao(chao, d, 0) - (ambiente.chao + lim.chao)
			if v > x then
				x, qual = v, "chao"
			end
		end
		return x, qual
	end
	local alcance = Som.buscarAlcance(function(d)
		return (melhor(d))
	end)
	local _, qual = melhor(alcance * 0.999)
	return alcance, qual
end

-- Nível de um item que cai (§5.4): base da classe + 10·log10(max(1, altura / alturaRef)). `classe` desconhecida cai em `padrao`.
function Som.nivelQueda(classe: string, altura: number): (number, Bandas)
	local def = cfg.queda.classes[classe] or cfg.queda.classes[cfg.queda.padrao]
	return def.nivel + 10 * log10(math.max(1, altura / cfg.queda.alturaRef)), def.perfil
end

-- Chave do rótulo do HUD (Config/Som.medidor.rotulos): o dominante, se tiver rótulo; senão o tipo; senão nil.
function Som.chaveRotulo(tipo: string, dominante: string?, rotulos: { [string]: string }): string?
	if dominante ~= nil and rotulos[dominante] ~= nil then
		return dominante
	end
	if rotulos[tipo] ~= nil then
		return tipo
	end
	return nil
end

return Som
