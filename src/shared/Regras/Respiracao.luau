--!strict
-- Regra pura do minigame de segurar a respiração (docs/som.md §13). O cliente roda `passo` a cada quadro; o servidor usa as funções de
-- decisão (podeAbrir, motivoFim, folego, proximidade). `cfg` = Config/Respiracao inteiro. Sem Instance, sem os.clock: tempo e sorteio entram.
--
-- Uma barra vertical (0 embaixo, 1 em cima): uma zona clara anda sozinha e o marcador (o pulmão) cai sem parar. Segurar a tecla o empurra para
-- cima. Fora da zona a tensão sobe; tensão cheia = arfou. O sucesso não existe aqui: só vem dos fins do servidor (§13.3).

export type Estado = {
	p: number, -- posição do marcador (0..1)
	v: number, -- velocidade do marcador
	zona: number, -- centro da zona (0..1)
	alvo: number, -- para onde o centro da zona anda
	espera: number, -- s até sortear outro alvo
	tensao: number, -- 0..1; >= 1 = arfou
	tempo: number, -- s desde o início
	proximidade: number, -- 0 (monstro em `raio`) .. 1 (colado)
	cansado: boolean, -- estamina baixa: a zona anda mais depressa
	falhou: boolean,
	dentro: boolean, -- o marcador está dentro da zona
}

-- Contexto de decisão do servidor. distancia = do monstro "em busca" mais perto (nil = nenhum).
export type ContextoAbrir = {
	vivo: boolean,
	emCarro: boolean,
	ativo: boolean,
	desdeUltimo: number, -- s desde o fim do último minigame (math.huge = nunca)
	modo: string, -- "parado" | "deitado" | "agachado" | "andar" | "correr"
	distancia: number?,
	dy: number,
}
export type ContextoFim = {
	modo: string,
	emCarro: boolean,
	tempo: number, -- s desde o início
	folego: number, -- s de fôlego do jogador
	distanciaBusca: number?, -- do monstro em busca mais perto dentro de raio + saidaExtra (nil = nenhum)
	cacando: boolean, -- algum monstro a <= raio + saidaExtra entrou em Caça/Ataque
}

local Respiracao = {}

local PARADOS = { parado = true, agachado = true, deitado = true }

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Largura da zona: `larguraLonge` com o monstro em `raio`, `larguraPerto` colado.
function Respiracao.largura(proximidade: number, cfg: any): number
	local j = cfg.jogo
	return lerp(j.larguraLonge, j.larguraPerto, math.clamp(proximidade, 0, 1))
end

-- 1 colado (<= longe), 0 em `raio` (ou mais longe).
function Respiracao.proximidade(distancia: number, cfg: any): number
	return 1 - math.clamp((distancia - cfg.longe) / (cfg.raio - cfg.longe), 0, 1)
end

-- Fôlego máximo em segundos: quem corre e depois se esconde aguenta menos, de propósito.
function Respiracao.folego(estamina: number, cfg: any): number
	return cfg.folegoBase + cfg.folegoEstamina * math.clamp(estamina, 0, 100) / 100
end

function Respiracao.novo(proximidade: number, estamina: number, cfg: any): Estado
	local j = cfg.jogo
	return {
		p = j.inicio,
		v = 0,
		zona = j.inicio,
		alvo = j.inicio,
		espera = 0,
		tensao = 0,
		tempo = 0,
		proximidade = math.clamp(proximidade, 0, 1),
		cansado = estamina < j.cansadoAbaixo,
		falhou = false,
		dentro = true,
	}
end

-- Mesma situação com outra proximidade (o servidor avisa a cada `proximidadeCada` s).
function Respiracao.comProximidade(e: Estado, proximidade: number): Estado
	local novo = table.clone(e)
	novo.proximidade = math.clamp(proximidade, 0, 1)
	return novo
end

-- Um passo de `dt` segundos. `rng` devolve [0, 1). Devolve um estado novo (o recebido não muda). Depois de falhar, o estado congela.
function Respiracao.passo(e: Estado, segurando: boolean, dt: number, rng: () -> number, cfg: any): Estado
	if e.falhou then
		return e
	end
	local j = cfg.jogo
	-- marcador
	local v = e.v + (if segurando then j.empurrao else -j.gravidade) * dt
	v *= math.max(0, 1 - j.amortecimento * dt)
	local p = e.p + v * dt
	if p <= 0 then
		p, v = 0, 0
	elseif p >= 1 then
		p, v = 1, 0
	end

	-- zona: a cada [trocaMin, trocaMax] s sorteia um alvo em [w/2, 1 − w/2]; o centro anda até ele a velZona/s
	local w = Respiracao.largura(e.proximidade, cfg)
	local alvo, espera = e.alvo, e.espera - dt
	if espera <= 0 then
		alvo = lerp(w / 2, 1 - w / 2, rng())
		espera = lerp(j.trocaMin, j.trocaMax, rng())
	end
	local vel = j.velZona * (if e.cansado then j.velZonaCansado else 1)
	local zona = e.zona + math.clamp(alvo - e.zona, -vel * dt, vel * dt)
	zona = math.clamp(zona, w / 2, 1 - w / 2) -- a largura pode ter mudado com a proximidade

	-- tensão
	local dentro = math.abs(p - zona) <= w / 2
	local tensao = if dentro then math.max(0, e.tensao - j.alivio * dt) else e.tensao + j.subida * dt
	return {
		p = p,
		v = v,
		zona = zona,
		alvo = alvo,
		espera = espera,
		tensao = tensao,
		tempo = e.tempo + dt,
		proximidade = e.proximidade,
		cansado = e.cansado,
		falhou = tensao >= 1,
		dentro = dentro,
	}
end

-- O servidor abre o minigame? (§13.1) Vivo, fora de carro, sem outro ativo, recarga cumprida, parado/agachado/deitado, monstro em busca
-- a <= raio na horizontal e |Δy| <= alturaMax.
function Respiracao.podeAbrir(c: ContextoAbrir, cfg: any): boolean
	return cfg.ligado
		and c.vivo
		and not c.emCarro
		and not c.ativo
		and c.desdeUltimo >= cfg.recarga
		and PARADOS[c.modo] == true
		and c.distancia ~= nil
		and c.distancia <= cfg.raio
		and math.abs(c.dy) <= cfg.alturaMax
end

-- Por que o minigame acaba AGORA (§13.3), ou nil se continua. Ordem: o jogador se mexeu > monstro em Caça > monstro se afastou > fôlego.
-- "moveu", "cacou" e "afastou" são silenciosos; "folego" solta o ar (som); o "arfou" vem do cliente (RespiracaoFalhou).
function Respiracao.motivoFim(c: ContextoFim, cfg: any): string?
	if c.emCarro or not PARADOS[c.modo] then
		return "moveu"
	end
	if c.cacando then
		return "cacou"
	end
	if c.distanciaBusca == nil or c.distanciaBusca > cfg.raio + cfg.saidaExtra then
		return "afastou"
	end
	if c.tempo >= c.folego then
		return "folego"
	end
	return nil
end

return Respiracao
