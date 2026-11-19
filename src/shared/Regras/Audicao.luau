--!strict
-- Regra pura da audição por espécie (docs/som.md §3.5, §3.7, §6): quanto um monstro ouve de um evento de som (excesso em dB, por banda e
-- pelo chão), com limiar da espécie, atenção do estado e extras de habilidade. Sem Instance: lê Config/Audicao e Config/Som.

export type Bandas = { grave: number, medio: number, agudo: number }
export type AmbienteBandas = { grave: number, medio: number, agudo: number, chao: number }
-- limiar = dB acima do ambiente por banda; chao = limiar da vibração (nil = não sente o chão); erro = erroPorDistancia da espécie (nil = padrão).
export type Perfil = { limiar: Bandas, chao: number?, erro: number? }
-- Evento mínimo para ouvir. `modo`/`tipo` só servem à regra do Pulso (agachado/deitado não usa a via chão).
export type Evento = {
	bandas: Bandas,
	chao: number?,
	ambienteBandas: AmbienteBandas,
	modo: string?,
	tipo: string?,
}
-- Extras de habilidade (d.audicaoExtra): somam ao limiar (negativo = ouve melhor). ignorarAgachado = o passo agachado/deitado não usa o chão.
export type Extra = { grave: number?, medio: number?, agudo: number?, chao: number?, ignorarAgachado: boolean? }

-- No Roblox o require é por instância; no Lune (testes) é por caminho relativo ao arquivo.
local function carregar(nome: string, pasta: string): any
	if typeof(script) == "Instance" then
		local base = (script :: any).Parent
		if pasta == "Config" then
			base = base.Parent:WaitForChild("Config")
		end
		return require(base:WaitForChild(nome))
	end
	return (require :: any)((if pasta == "Config" then "../Config/" else "./") .. nome)
end

local cfg = carregar("Audicao", "Config")
local cfgSom = carregar("Som", "Config")
local Som = carregar("Som", "Regras")

local BANDAS = { "grave", "medio", "agudo" }

local Audicao = {}

local porEspecie: { [string]: Perfil } = {}
local porNivel: { [number]: Perfil } = {}

-- Perfil de audição da espécie; sem perfil no Config, o limiar plano da margem do nível (= hoje), sem chão e com o erro padrão.
-- `config` opcional (testes); o padrão é Config/Audicao. Os perfis devolvidos são compartilhados: não mudar.
function Audicao.perfil(especieId: string, nivel: number, config: any?): Perfil
	local c = config or cfg
	local e = c.porEspecie[especieId]
	if e then
		if config ~= nil then
			return { limiar = e.limiar, chao = e.chao, erro = e.erroPorDistancia }
		end
		local feito = porEspecie[especieId]
		if not feito then
			feito = { limiar = e.limiar, chao = e.chao, erro = e.erroPorDistancia }
			porEspecie[especieId] = feito
		end
		return feito
	end
	local margem = c.porNivel[nivel] or c.porNivel[1]
	if config ~= nil then
		return { limiar = { grave = margem, medio = margem, agudo = margem } }
	end
	local feito = porNivel[nivel]
	if not feito then
		feito = { limiar = { grave = margem, medio = margem, agudo = margem } }
		porNivel[nivel] = feito
	end
	return feito
end

-- T (§6.3): atenção do estado ("Calmo" | "Investiga" | "Caca" | "Ataque") + o bônus de parado (velocidade horizontal < velocidadeParado).
function Audicao.atencao(estado: string, velocidade: number): number
	local a = cfg.atencao
	local t = a[estado] or 0
	if velocidade < a.velocidadeParado then
		t += a.parado
	end
	return t
end

-- Raio do erro da posição estimada (§3.7): distância × erro da espécie (ou o padrão) × erroBanda[banda]. `banda` pode ser "chao".
function Audicao.raioErro(distancia: number, perfil: Perfil, banda: string, erroPadrao: number): number
	return math.max(0, distancia) * (perfil.erro or erroPadrao) * (cfgSom.erroBanda[banda] or 1)
end

function Audicao.erroBanda(banda: string): number
	return cfgSom.erroBanda[banda] or 1
end

local function extraDe(extra: Extra?, banda: string): number
	if extra == nil then
		return 0
	end
	return (extra :: any)[banda] or 0
end

-- Excesso pelo ar (melhor banda) e pelo chão (nil se o ouvinte não sente o chão, o evento não toca o chão ou a regra do Pulso o corta).
-- `paredes` só mexe no ar. dy = diferença de altura entre ouvinte e fonte (studs).
function Audicao.vias(
	evento: Evento,
	perfil: Perfil,
	distancia: number,
	paredes: number,
	dy: number,
	atencao: number,
	extra: Extra?
): (number, string, number?)
	local ar, bandaAr = -math.huge, "medio"
	for _, b in BANDAS do
		local recebido = Som.propagarAr((evento.bandas :: any)[b], b, distancia, paredes)
		local x = recebido
			- ((evento.ambienteBandas :: any)[b] + (perfil.limiar :: any)[b] + extraDe(extra, b) + atencao)
		if x > ar then
			ar, bandaAr = x, b
		end
	end
	local chao: number? = nil
	if evento.chao ~= nil and perfil.chao ~= nil then
		local cortado = extra ~= nil
			and extra.ignorarAgachado == true
			and evento.tipo == "passo"
			and (evento.modo == "agachado" or evento.modo == "deitado")
		if not cortado then
			local recebido = Som.propagarChao(evento.chao, distancia, dy)
			chao = recebido - (evento.ambienteBandas.chao + perfil.chao + extraDe(extra, "chao") + atencao)
		end
	end
	return ar, bandaAr, chao
end

-- Excesso final (§3.5) = máximo entre as bandas do ar e o chão, e a banda que o deu ("grave" | "medio" | "agudo" | "chao").
function Audicao.excesso(
	evento: Evento,
	perfil: Perfil,
	distancia: number,
	paredes: number,
	dy: number,
	atencao: number,
	extra: Extra?
): (number, string)
	local ar, banda, chao = Audicao.vias(evento, perfil, distancia, paredes, dy, atencao, extra)
	if chao ~= nil and chao > ar then
		return chao, "chao"
	end
	return ar, banda
end

-- Vale a pena pagar raycast de paredes (§6.2 passo 3)? Só se o ar, sem paredes, passa do limiar E passa do chão (o chão ignora parede:
-- se ele já vence, as paredes não mudam o resultado).
function Audicao.precisaParedes(
	evento: Evento,
	perfil: Perfil,
	distancia: number,
	dy: number,
	atencao: number,
	extra: Extra?
): boolean
	local ar, _, chao = Audicao.vias(evento, perfil, distancia, 0, dy, atencao, extra)
	return ar >= 0 and (chao == nil or ar > chao)
end

-- Alcance (studs) do evento para este ouvinte (§8), com `paredes` no caminho. via = "ar" | "chao" | nil (as duas).
function Audicao.alcance(
	evento: Evento,
	perfil: Perfil,
	paredes: number,
	dy: number,
	atencao: number,
	extra: Extra?,
	via: string?
): number
	return Som.buscarAlcance(function(d)
		local ar, _, chao = Audicao.vias(evento, perfil, d, paredes, dy, atencao, extra)
		if via == "ar" then
			return ar
		elseif via == "chao" then
			return chao or -math.huge
		end
		return math.max(ar, chao or -math.huge)
	end)
end

return Audicao
