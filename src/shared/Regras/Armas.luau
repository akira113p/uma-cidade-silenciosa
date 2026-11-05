--!strict
-- Regras puras das armas: cadência, origem do ataque, direção, espalhamento e dano. Dono: P7.
-- Contrato: docs/arquitetura.md §P7. Números em Config/Armas e Config/Corpo; aqui só a fórmula.

export type Vec = { x: number, y: number, z: number }

local Armas = {}

local function finito(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

local function vecFinito(v: Vec): boolean
	return finito(v.x) and finito(v.y) and finito(v.z)
end

local function comprimento(v: Vec): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function cruz(a: Vec, b: Vec): Vec
	return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x }
end

-- Vetor unitário, ou nil se for nulo ou não finito.
local function unitario(v: Vec): Vec?
	if not vecFinito(v) then
		return nil
	end
	local m = comprimento(v)
	if m < 1e-9 then
		return nil
	end
	return { x = v.x / m, y = v.y / m, z = v.z / m }
end

-- Cadência guardada no servidor: só ataca se passou `cadencia` desde o último ataque aceito.
function Armas.podeAtacar(ultimoAtaque: number, agora: number, cadencia: number): boolean
	if not (finito(agora) and finito(cadencia)) or ultimoAtaque ~= ultimoAtaque then
		return false
	end
	return agora - ultimoAtaque >= cadencia - 1e-9 -- folga de ponto flutuante
end

-- A origem enviada pelo cliente tem que estar perto da cabeça do atacante (senão atirava de dentro de uma parede).
function Armas.origemValida(origem: Vec, cabeca: Vec, tolerancia: number): boolean
	if not (vecFinito(origem) and vecFinito(cabeca) and finito(tolerancia)) then
		return false
	end
	return comprimento({ x = origem.x - cabeca.x, y = origem.y - cabeca.y, z = origem.z - cabeca.z }) <= tolerancia
end

-- Direção do cliente: magnitude plausível (minimo..maximo) e finita; devolve unitária ou nil.
function Armas.normalizarDirecao(direcao: Vec, minimo: number, maximo: number): Vec?
	if not vecFinito(direcao) then
		return nil
	end
	local m = comprimento(direcao)
	if m < minimo or m > maximo then
		return nil
	end
	return unitario(direcao)
end

-- Desvia a direção dentro de um cone de `graus` (distribuição uniforme no disco). Devolve unitário.
function Armas.espalhar(direcao: Vec, graus: number, rng: () -> number): Vec
	local d = unitario(direcao) or { x = 0, y = 0, z = -1 }
	if graus <= 0 then
		return d
	end
	local auxiliar: Vec = if math.abs(d.y) < 0.99 then { x = 0, y = 1, z = 0 } else { x = 1, y = 0, z = 0 }
	local u = unitario(cruz(auxiliar, d)) :: Vec
	local v = cruz(d, u)
	local theta = math.rad(graus) * math.sqrt(rng())
	local phi = 2 * math.pi * rng()
	local st, ct = math.sin(theta), math.cos(theta)
	local cp, sp = math.cos(phi), math.sin(phi)
	return {
		x = d.x * ct + (u.x * cp + v.x * sp) * st,
		y = d.y * ct + (u.y * cp + v.y * sp) * st,
		z = d.z * ct + (u.z * cp + v.z * sp) * st,
	}
end

-- Dano da arma na parte do jogo (Cabeca, Torso...): cabeça × multCabecaArma.
function Armas.dano(arma: { dano: number }, parteJogo: string, cfgCorpo: { multCabecaArma: number }): number
	if parteJogo == "Cabeca" then
		return arma.dano * cfgCorpo.multCabecaArma
	end
	return arma.dano
end

-- Espalhamento da mira × multMiraBracoZerado com um braço zerado.
function Armas.multEspalhamento(bracoZerado: boolean, cfgCorpo: { multMiraBracoZerado: number }): number
	if bracoZerado then
		return cfgCorpo.multMiraBracoZerado
	end
	return 1
end

----------------------------------------------------------------------------------------------- pente, queda, bloom
-- docs/armas.md §5. Tudo puro: o servidor guarda `bloom`, `pente` e os relógios e chama estas funções.

export type Queda = { inicio: number, minimo: number }
export type CfgQueda = { dano: number, alcance: number, queda: Queda? }
export type CfgBloom = { bloom: { porTiro: number, maximo: number, recuperacao: number } }
export type CfgRecarga = {
	pente: number,
	recarga: { tipo: string, tempo: number?, inicio: number?, porCartucho: number?, fim: number? },
}

-- Multiplicador de dano pela distância: 1 até queda.inicio, linear até queda.minimo no alcance (e além). Sem queda: 1.
function Armas.fatorQueda(cfg: CfgQueda, distancia: number): number
	local queda = cfg.queda
	if queda == nil or not finito(distancia) then
		return 1
	end
	if distancia <= queda.inicio then
		return 1
	end
	if distancia >= cfg.alcance then
		return queda.minimo
	end
	local t = (distancia - queda.inicio) / (cfg.alcance - queda.inicio)
	return 1 + (queda.minimo - 1) * t
end

function Armas.danoNaDistancia(cfg: CfgQueda, distancia: number): number
	return cfg.dano * Armas.fatorQueda(cfg, distancia)
end

-- Graus de espalhamento: (cone + bloom) × estado do atirador × braço zerado. Estado desconhecido vale 1.
function Armas.espalhamentoTotal(
	cfg: { espalhamento: number },
	bloom: number,
	estado: string,
	bracoZerado: boolean,
	cfgArmas: { multEstado: { [string]: number } },
	cfgCorpo: { multMiraBracoZerado: number }
): number
	local mult = cfgArmas.multEstado[estado] or 1
	return (cfg.espalhamento + bloom) * mult * Armas.multEspalhamento(bracoZerado, cfgCorpo)
end

function Armas.bloomAposTiro(cfg: CfgBloom, bloom: number): number
	return math.min(bloom + cfg.bloom.porTiro, cfg.bloom.maximo)
end

function Armas.bloomRecuperado(cfg: CfgBloom, bloom: number, dt: number): number
	if not finito(dt) or dt < 0 then
		dt = 0
	end
	return math.max(0, bloom - cfg.bloom.recuperacao * dt)
end

-- Estado do atirador para `multEstado`. Correndo vence tudo (precisa estar se movendo); agachado vale se não está
-- correndo (parado ou andando devagar, o agachado já limita a velocidade); andando = velocidade horizontal > limiar.
function Armas.estadoDoAtirador(
	agachado: boolean,
	correndo: boolean,
	velocidadeHoriz: number,
	limiarAndar: number
): string
	local movendo = velocidadeHoriz > limiarAndar
	if correndo and movendo then
		return "correndo"
	end
	if agachado then
		return "agachado"
	end
	if movendo then
		return "andando"
	end
	return "parado"
end

-- Pode disparar? Devolve false + motivo "vazio" | "recarregando" | "usando". Recarregando vem antes de vazio
-- (o pente zerado é o normal no meio da recarga). `cfg` fica na assinatura para regras por arma no futuro.
function Armas.podeDisparar(_cfg: any, pente: number, recarregando: boolean, usando: boolean): (boolean, string?)
	if usando then
		return false, "usando"
	end
	if recarregando then
		return false, "recarregando"
	end
	if pente < 1 then
		return false, "vazio"
	end
	return true, nil
end

-- Recarga de pente: completa até a capacidade com o que a reserva permitir. Devolve (pente, reserva, movidas).
function Armas.recarregarPente(pente: number, capacidade: number, reserva: number): (number, number, number)
	local falta = math.max(0, capacidade - pente)
	local movidas = math.min(falta, math.max(0, reserva))
	return pente + movidas, reserva - movidas, movidas
end

-- Recarga de tubo: 1 cartucho por chamada (0 se cheio ou sem reserva).
function Armas.cartuchoParaTubo(pente: number, capacidade: number, reserva: number): (number, number, number)
	if pente >= capacidade or reserva < 1 then
		return pente, reserva, 0
	end
	return pente + 1, reserva - 1, 1
end

-- Duração total da recarga. Pente: tempo fixo. Tubo: inicio + n × porCartucho + fim, n = cartuchos que cabem e há
-- (n = 0 → 0, nada a recarregar).
function Armas.tempoRecarga(cfg: CfgRecarga, pente: number, reserva: number): number
	local r = cfg.recarga
	if r.tipo == "cartucho" then
		local n = math.min(math.max(0, cfg.pente - pente), math.max(0, reserva))
		if n <= 0 then
			return 0
		end
		return (r.inicio or 0) + n * (r.porCartucho or 0) + (r.fim or 0)
	end
	return r.tempo or 0
end

-- Chumbinhos por disparo (1 para armas comuns).
function Armas.pelotas(cfg: { projeteis: number? }): number
	return cfg.projeteis or 1
end

-- Dano da explosão: linear de danoCentro (d = 0) a danoCentro × fatorBorda (d = raio); 0 fora do raio.
function Armas.danoExplosao(distancia: number, raio: number, danoCentro: number, fatorBorda: number): number
	if not finito(distancia) or distancia < 0 or raio <= 0 or distancia > raio then
		return 0
	end
	local t = distancia / raio
	return danoCentro * (1 + (fatorBorda - 1) * t)
end

return Armas
