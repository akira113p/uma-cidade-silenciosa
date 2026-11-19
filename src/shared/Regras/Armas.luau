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
	engatilhar: string?,
	tempoEngatilhar: number?,
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
	-- arma de pente recarregada VAZIA: a câmara está vazia, então o fim da recarga inclui engatilhar (docs/armas.md §13.3)
	local extra = if cfg.engatilhar == "auto" and pente <= 0 then (cfg.tempoEngatilhar or 0) else 0
	return (r.tempo or 0) + extra
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

----------------------------------------------------------------------------------------------- pane, engatilhar, recarga
-- docs/armas.md §13 e pesquisa/gold-bright-armas.md. Tudo puro: o servidor guarda `engatilhada`/`travada` e sorteia; o cliente
-- usa as mesmas funções só para prever (nunca para decidir).

export type CfgPane = { chanceSemi: number, chanceAuto: number, tempoDestravar: number }
export type CfgRapida = { janelaDe: number, janelaAte: number, fator: number, minimoApos: number, penalidade: number }
export type CfgEngatilhar = { engatilhar: string?, modo: string?, tempoEngatilhar: number? }

-- A arma usa engatilhar? ("auto" = pente, "manual" = bomba; o lançador não tem).
function Armas.usaEngatilhar(cfg: CfgEngatilhar): boolean
	return cfg.engatilhar == "auto" or cfg.engatilhar == "manual"
end

-- Só arma de pente (engatilha sozinha) pode travar.
function Armas.podePanear(cfg: CfgEngatilhar): boolean
	return cfg.engatilhar == "auto"
end

-- Chance de travar a cada tiro: automática 1,25%, semiautomática 5% (valores do Gold Bright; Config/Armas.pane).
function Armas.chancePane(cfg: CfgEngatilhar, pane: CfgPane): number
	if not Armas.podePanear(cfg) then
		return 0
	end
	return if cfg.modo == "auto" then pane.chanceAuto else pane.chanceSemi
end

-- Travou neste tiro? `penteDepois` = balas que sobraram DEPOIS do tiro; `sorteio` em [0, 1). Nunca trava a última bala
-- nem duas vezes no mesmo pente. O Gold Bright sorteia e trava quando o valor passa de 1 - chance.
function Armas.travou(
	cfg: CfgEngatilhar,
	pane: CfgPane,
	travadaNestePente: boolean,
	penteDepois: number,
	sorteio: number
): boolean
	if travadaNestePente or penteDepois < 1 or not finito(sorteio) then
		return false
	end
	local chance = Armas.chancePane(cfg, pane)
	return chance > 0 and sorteio > 1 - chance
end

-- A arma fica engatilhada depois do tiro? Pente: sim, salvo se travou. Bomba: não (engatilhar na mão). Lançador: sempre pronto.
function Armas.engatilhadaAposTiro(cfg: CfgEngatilhar, travou: boolean): boolean
	if cfg.engatilhar == "auto" then
		return not travou
	end
	if cfg.engatilhar == "manual" then
		return false
	end
	return true
end

-- Ao equipar: engatilhada se há bala (guardada pronta). Sem bala, não.
function Armas.engatilhadaAoEquipar(cfg: CfgEngatilhar, pente: number): boolean
	if not Armas.usaEngatilhar(cfg) then
		return true
	end
	return pente >= 1
end

-- Por que não dá para atirar além de pente/recarga: "engatilhando" (a mão está ocupada), "travada" ou "desengatilhada".
function Armas.bloqueioDeTiro(
	cfg: CfgEngatilhar,
	engatilhada: boolean?,
	travada: boolean?,
	engatilhando: boolean?
): string?
	if engatilhando == true then
		return "engatilhando"
	end
	if travada == true then
		return "travada"
	end
	if Armas.usaEngatilhar(cfg) and engatilhada == false then
		return "desengatilhada"
	end
	return nil
end

-- O que a tecla de engatilhar faz agora? Devolve (acao, segundos):
--   "vazio" (sem balas: só o clique), "nada" (já engatilhada e sem pane), "destravar" (pane: tira a bala presa) ou "engatilhar".
function Armas.engatilhar(
	cfg: CfgEngatilhar,
	pente: number,
	engatilhada: boolean,
	travada: boolean,
	pane: CfgPane
): (string, number)
	if not Armas.usaEngatilhar(cfg) then
		return "nada", 0
	end
	if pente < 1 then
		return "vazio", 0
	end
	if travada then
		return "destravar", pane.tempoDestravar
	end
	if engatilhada then
		return "nada", 0
	end
	return "engatilhar", cfg.tempoEngatilhar or 0
end

-- Capacidade da recarga: com bala na câmara (arma de pente engatilhada, sem pane, pente >= 1) cabe +1. Arma vazia, bomba e
-- lançador: a capacidade normal.
function Armas.capacidadeRecarga(
	cfg: { pente: number, engatilhar: string? },
	pente: number,
	engatilhada: boolean?,
	travada: boolean?
): number
	if cfg.engatilhar == "auto" and engatilhada == true and travada ~= true and pente >= 1 then
		return cfg.pente + 1
	end
	return cfg.pente
end

-- Dá para recarregar? Há espaço (pente abaixo da capacidade) e reserva.
function Armas.podeRecarregar(
	cfg: { pente: number, engatilhar: string? },
	pente: number,
	reserva: number,
	engatilhada: boolean?,
	travada: boolean?
): boolean
	return reserva >= 1 and pente < Armas.capacidadeRecarga(cfg, pente, engatilhada, travada)
end

-- R de novo durante a recarga de PENTE: "rapida" (dentro da janela), "falha" (fora, uma vez só) ou "ignorar".
-- `decorrido` e `duracao` em s; `jaAtrapalhou`/`jaFoiRapida` evitam repetir.
function Armas.cliqueNaRecarga(
	cfg: { recarga: { tipo: string } },
	rapida: CfgRapida,
	decorrido: number,
	duracao: number,
	jaAtrapalhou: boolean,
	jaFoiRapida: boolean
): string
	if cfg.recarga.tipo ~= "pente" or jaAtrapalhou or jaFoiRapida or duracao <= 0 or not finito(decorrido) then
		return "ignorar"
	end
	local f = decorrido / duracao
	if f >= rapida.janelaDe and f <= rapida.janelaAte then
		return "rapida"
	end
	return "falha"
end

-- Nova duração TOTAL (a partir do início da recarga) depois do clique: rápida = fator × duração (mas nunca antes de
-- decorrido + minimoApos); falha = duração + penalidade.
function Armas.duracaoAposClique(acao: string, rapida: CfgRapida, decorrido: number, duracao: number): number
	if acao == "rapida" then
		return math.max(duracao * rapida.fator, decorrido + rapida.minimoApos)
	end
	if acao == "falha" then
		return duracao + rapida.penalidade
	end
	return duracao
end

-- Balas do pente velho que caem no chão na recarga rápida: tudo menos a bala da câmara (que fica na arma). Arma de pente
-- engatilhada e sem pane guarda 1; senão o pente inteiro cai. Devolve (balasNoChao, balasQueFicamNaArma).
function Armas.penteVelho(pente: number, engatilhada: boolean?, travada: boolean?): (number, number)
	local camara = if engatilhada == true and travada ~= true and pente >= 1 then 1 else 0
	return math.max(0, pente - camara), camara
end

-- Frase do pente na checagem de munição (sem número, como no jogo de referência): o jogador "olha" o pente.
function Armas.frasePente(pente: number, capacidade: number): string
	if pente <= 0 then
		return "Vazio."
	end
	local f = pente / math.max(1, capacidade)
	if f <= 0.2 then
		return "Só restam algumas balas."
	elseif f <= 0.45 then
		return "Menos da metade."
	elseif f <= 0.7 then
		return "Mais ou menos metade."
	elseif f < 0.999 then
		return "Quase cheio."
	end
	return "Cheio."
end

-- Frase da reserva em "pentes" da arma na mão (arredonda para meio pente para baixo).
function Armas.fraseReserva(reserva: number, capacidade: number): string
	if reserva <= 0 then
		return "Sem reserva."
	end
	local pentes = math.floor(reserva / math.max(1, capacidade) * 2) / 2
	if pentes < 1 then
		return "Reserva: menos de um pente."
	end
	local inteiro = math.floor(pentes)
	local meio = pentes - inteiro >= 0.5
	local nome = if inteiro == 1 and not meio then "pente" else "pentes"
	return string.format("Reserva: %d%s %s.", inteiro, if meio then " e meio" else "", nome)
end

return Armas
