--!strict
-- Regras puras do Rastejador (docs/rastejador.md §4). Sem Instance, sem os.clock. `cfg` = Config/Rastejador.
-- O dano, a vida e o buraco da parede são da Destruicao (docs/destruicao.md); aqui só a decisão do monstro.

export type Cfg = any
export type Candidato = {
	tipo: string, -- "jogador" | "veiculo" | "parede" | "som"
	distancia: number,
	idade: number?, -- veículo: s desde o último som dele
	ocupado: boolean?, -- veículo com gente dentro
}

local Rastejador = {}

function Rastejador.classificarDegrau(altura: number, folga: number, cfg: Cfg): string
	local d = cfg.degrau
	if altura <= d.andar then
		return "andar"
	end
	if altura <= d.saltoMax and folga >= d.folgaMin then
		return "saltar"
	end
	return "parede"
end

function Rastejador.alturaDoSalto(altura: number, cfg: Cfg): number
	return math.min(altura + cfg.degrau.margemSalto, cfg.degrau.saltoMax)
end

function Rastejador.precisaArrombar(
	estadoCaminho: string,
	comprimento: number,
	retaHoriz: number,
	alvoDentro: boolean,
	cfg: Cfg
): boolean
	if not alvoDentro then
		return false
	end
	local a = cfg.arrombar
	if estadoCaminho == "NoPath" then
		return true
	end
	return comprimento > retaHoriz * a.fatorDesvio + a.folgaDesvio
end

-- tam = tamanho da peça {x,y,z} em studs; atributos = { Indestrutivel: boolean? }.
function Rastejador.paredeArrombavel(tam: { number }, ehPiso: boolean, atributos: { [string]: any }?, cfg: Cfg): boolean
	if ehPiso then
		return false
	end
	if atributos and atributos.Indestrutivel == true then
		return false
	end
	local a = cfg.arrombar
	return math.min(tam[1], tam[3]) <= a.espessuraMax and tam[2] >= a.alturaMin
end

-- Velocidade do Rastejador no estado visível (Calmo/Investiga/Caca/Ataque); nil se o estado não está na tabela.
function Rastejador.velocidade(estado: string, cfg: Cfg): number?
	return cfg.velocidade[estado]
end

-- Entre paredes arrombáveis { golpes, distancia }, a de menos golpes (<= golpesMax); desempate pela menor distância.
function Rastejador.escolherParede(candidatas: { { golpes: number, distancia: number } }, cfg: Cfg): number?
	local melhor: number? = nil
	for i, c in candidatas do
		if c.golpes <= cfg.arrombar.golpesMax then
			local m = if melhor then candidatas[melhor] else nil
			if not m or c.golpes < m.golpes or (c.golpes == m.golpes and c.distancia < m.distancia) then
				melhor = i
			end
		end
	end
	return melhor
end

local PRIORIDADE: { [string]: number } = { jogador = 1, veiculo = 2, parede = 3, som = 4 }

function Rastejador.escolherObjetivo(candidatos: { Candidato }, cfg: Cfg): Candidato?
	local melhor: Candidato? = nil
	for _, c in candidatos do
		local p = PRIORIDADE[c.tipo]
		if not p then
			continue
		end
		if c.tipo == "veiculo" and not (c.ocupado == true or (c.idade or math.huge) <= cfg.veiculo.memoria) then
			continue
		end
		if melhor == nil then
			melhor = c
		else
			local pm = PRIORIDADE[melhor.tipo]
			if p < pm or (p == pm and c.distancia < melhor.distancia) then
				melhor = c
			end
		end
	end
	return melhor
end

-- sorteio em [0,1). Vidro só conta com ocupante: sem ele o peso do vidro não entra no sorteio.
function Rastejador.parteDoVeiculo(sorteio: number, ocupado: boolean, cfg: Cfg): string
	local p = cfg.veiculo.pesos
	local pneu, vidro = p.pneu, if ocupado then p.vidro else 0
	local x = sorteio * (pneu + vidro + p.carroceria)
	if x < pneu then
		return "pneu"
	end
	if x < pneu + vidro then
		return "vidro"
	end
	return "carroceria"
end

function Rastejador.acao(
	estado: string,
	atacando: boolean,
	subindo: boolean,
	velocidade: number,
	morto: boolean,
	cfg: Cfg
): string
	if morto then
		return "Death"
	end
	if atacando then
		return "Attack"
	end
	if velocidade < cfg.animacao.parado then
		return "Idle"
	end
	if subindo or estado == "Caca" or estado == "Ataque" then
		return "Run"
	end
	return "Walk"
end

-- Velocidade de reprodução do ciclo: velocidade real ÷ nativa, limitada. Ações sem velocidade tocam a 1.
function Rastejador.velocidadeAnim(acao: string, velocidade: number, cfg: Cfg): number
	local nativa = cfg.animacao.nativas[acao]
	if not nativa then
		return 1
	end
	return math.clamp(velocidade / nativa, cfg.animacao.velMin, cfg.animacao.velMax)
end

return Rastejador
