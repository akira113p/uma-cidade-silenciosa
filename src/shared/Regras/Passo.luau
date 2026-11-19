--!strict
-- Regra pura do passo do jogador em camadas (docs/som.md §4): pisada, equipamento (carga), respiração (estamina) e vegetação,
-- somadas por Regras/Som.compor. Mais a aterrissagem (§4.5) e o ofego parado (§4.4). `cfg` = Config/Som inteiro. Sem Instance.

export type Bandas = { grave: number, medio: number, agudo: number }
export type Camada = { nome: string?, nivel: number, perfil: Bandas, chao: number? }
-- modo: "deitado" | "agachado" | "andar" | "correr". superficie = nome em Config/Som.superficies (desconhecida = padrão).
-- carga em kg, estamina 0..100. prendendo = true durante o minigame de segurar a respiração (docs/som.md §13.3): a respiração some.
export type Estado = {
	modo: string,
	superficie: string,
	carga: number,
	estamina: number,
	vegetacao: boolean,
	prendendo: boolean?,
}

local Passo = {}

local function log10(x: number): number
	return math.log(x, 10)
end

local function superficieDe(nome: string, cfg: any): any
	return cfg.superficies[nome] or cfg.superficies[cfg.superficiePadrao]
end

local function fracaoCansaco(estamina: number): number
	return 1 - math.clamp(estamina, 0, 100) / 100
end

-- Nível da respiração em `modo` ("parado" incluído): base do modo + respCansaco × (1 − estamina/100).
function Passo.nivelRespiracao(modo: string, estamina: number, cfg: any): number
	return cfg.passo.resp[modo] + cfg.passo.respCansaco * fracaoCansaco(estamina)
end

-- Camadas de um passo (§4.1). A pisada leva a vibração do chão; as outras só tocam o ar.
function Passo.camadas(estado: Estado, cfg: any): { Camada }
	local p = cfg.passo
	local modo = estado.modo
	local sup = superficieDe(estado.superficie, cfg)
	local nivelPisada = p.pisada[modo] + sup.db
	local camadas: { Camada } = {
		{ nome = "pisada", nivel = nivelPisada, perfil = sup.perfil, chao = nivelPisada + p.chaoModo[modo] + sup.chao },
	}
	if p.equipamento.ligado then
		table.insert(camadas, {
			nome = "equipamento",
			nivel = p.equip[modo] + 10 * log10(1 + math.max(0, estado.carga) / p.cargaRef),
			perfil = p.equipamento.perfil,
		})
	end
	if estado.prendendo ~= true then
		table.insert(camadas, {
			nome = "respiracao",
			nivel = Passo.nivelRespiracao(modo, estado.estamina, cfg),
			perfil = p.respiracaoPerfil,
		})
	end
	if estado.vegetacao then
		table.insert(camadas, { nome = "vegetacao", nivel = p.vegetacao[modo], perfil = p.vegetacaoPerfil })
	end
	return camadas
end

-- Ofego parado (§4.4): a camada de respiração se o nível >= respiracao.minimo (estamina abaixo de ~32%); nil se não faz barulho.
function Passo.respiracaoParado(estamina: number, prendendo: boolean, cfg: any): Camada?
	if not cfg.respiracao.ligado or prendendo then
		return nil
	end
	local nivel = Passo.nivelRespiracao("parado", estamina, cfg)
	if nivel < cfg.respiracao.minimo then
		return nil
	end
	return { nome = "respiracao", nivel = nivel, perfil = cfg.passo.respiracaoPerfil }
end

-- Aterrissagem (§4.5): nível = acoes.aterrissar + 10·log10(altura/alturaRef); vibração = chaoBase + superfície.chao + o mesmo termo.
function Passo.aterrissagem(altura: number, superficie: string, cfg: any): Camada
	local a = cfg.aterrissagem
	local termo = 10 * log10(math.max(1, altura / a.alturaRef))
	return {
		nome = "aterrissar",
		nivel = cfg.acoes.aterrissar + termo,
		perfil = a.perfil,
		chao = a.chaoBase + superficieDe(superficie, cfg).chao + termo,
	}
end

return Passo
