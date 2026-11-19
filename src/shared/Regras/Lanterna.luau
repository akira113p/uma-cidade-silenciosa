--!strict
-- Regras da lanterna (S7): direção suavizada, cintilação e balanço. Puras: sem Roblox. Números: Config/Lanterna.

local Lanterna = {}

export type Vec = { x: number, y: number, z: number }
export type CfgCintilacao = {
	intervalo: number,
	janela: number,
	duracao: number,
	profundidadeMin: number,
	profundidadeMax: number,
	fracaoDescida: number,
}
export type CfgBalanco = {
	amplitudeY: number,
	amplitudeX: number,
	frequencia: number,
	velocidadeRef: number,
	fatorMaximo: number,
}

local PADRAO_CINTILACAO: CfgCintilacao = {
	intervalo = 8,
	janela = 4,
	duracao = 0.3,
	profundidadeMin = 0.05,
	profundidadeMax = 0.15,
	fracaoDescida = 0.15,
}

local function normalizar(v: Vec): Vec?
	local m = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if m < 1e-6 or m ~= m then
		return nil
	end
	return { x = v.x / m, y = v.y / m, z = v.z / m }
end

-- A direção `atual` persegue `alvo` com meia-vida `meiaVida` (s): a cada meia-vida, metade do ÂNGULO que falta
-- (interpolação esférica). Independe do dt: dois passos de 0.01 s dão o mesmo que um de 0.02 s. Devolve vetor unitário.
-- Sem direção válida em `atual` (ou exatamente oposta ao alvo, onde não há rota única), vale o alvo.
function Lanterna.suavizarDirecao(atual: Vec, alvo: Vec, dt: number, meiaVida: number): Vec
	local a = normalizar(atual)
	local b = normalizar(alvo)
	if not b then
		return a or { x = 0, y = 0, z = -1 }
	end
	if not a or meiaVida <= 0 then
		return b
	end
	local k = 1 - 0.5 ^ (math.max(dt, 0) / meiaVida)
	local cosseno = math.clamp(a.x * b.x + a.y * b.y + a.z * b.z, -1, 1)
	local angulo = math.acos(cosseno)
	local seno = math.sin(angulo)
	if angulo < 1e-5 then
		return b
	end
	if seno < 1e-5 then
		return b -- opostos
	end
	local pa = math.sin((1 - k) * angulo) / seno
	local pb = math.sin(k * angulo) / seno
	return normalizar({ x = a.x * pa + b.x * pb, y = a.y * pa + b.y * pb, z = a.z * pa + b.z * pb }) or b
end

-- Inteiro pseudoaleatório determinístico em [0, 2147483646) a partir de (n, semente).
local function embaralhar(n: number, semente: number): number
	local x = (n * 16807 + semente * 48271 + 12345) % 2147483647
	x = (x * 16807) % 2147483647
	x = (x * 48271 + 977) % 2147483647
	x = (x * 16807) % 2147483647
	return x
end

local function fracao(n: number, semente: number, canal: number): number
	return embaralhar(n * 3 + canal, semente) / 2147483647
end

-- Multiplicador de brilho em [1 - profundidadeMax, 1]. Em cada janela de `intervalo` s há UMA queda curta, num instante
-- sorteado dentro dos primeiros `janela` s; o intervalo entre quedas fica então em [intervalo - janela, intervalo + janela]
-- (4..12 s no padrão) e a queda nunca cruza para a janela seguinte. Determinística em (t, semente).
function Lanterna.cintilacao(t: number, semente: number, cfg: CfgCintilacao?): number
	local c = cfg or PADRAO_CINTILACAO
	if t ~= t or t < 0 then
		return 1
	end
	local n = math.floor(t / c.intervalo)
	local inicio = n * c.intervalo + fracao(n, semente, 0) * c.janela
	local tau = (t - inicio) / c.duracao
	if tau < 0 or tau >= 1 then
		return 1
	end
	local profundidade = c.profundidadeMin + (c.profundidadeMax - c.profundidadeMin) * fracao(n, semente, 1)
	-- queda rápida (fracaoDescida da duração) e volta suave
	local forma = if tau < c.fracaoDescida then tau / c.fracaoDescida else (1 - tau) / (1 - c.fracaoDescida)
	return 1 - profundidade * forma
end

-- FALHAS (2026-11-17, pedido do usuário; ritmo do `FlickerRoutine` do Gold Bright, pesquisa/gold-bright.md §8) ------------------
export type CfgFalha = {
	intervalo: { number }, -- {min, max} s acesa até a próxima falha
	chanceApagar: number, -- 0..1: a falha termina com a lanterna APAGADA (precisa F de novo); senão só pisca
	chanceFalharAoLigar: number, -- 0..1: ao ligar, falha um pouco antes de acender de vez
}
export type PadraoFalha = { t: { number }, f: { number }, duracao: number, final: number }

-- Gerador pseudoaleatório por semente (LCG de 32 bits): o servidor e todos os clientes derivam o MESMO padrão da semente.
local function sorteador(semente: number)
	local x = ((math.floor(math.abs(semente)) % 4294967296) * 69069 + 12345) % 4294967296 -- mistura (sementes vizinhas se afastam)
	local function passo(): number
		x = (x * 1664525 + 1013904223) % 4294967296 -- produto < 2^53: exato em double
		return x / 4294967296
	end
	for _ = 1, 4 do
		passo() -- descarta os primeiros: dependem pouco da semente
	end
	return passo
end

local function entre(u: number, a: number, b: number): number
	return a + (b - a) * u
end

-- Padrão de brilho de uma falha: `t[i]` = instante (s desde o início) em que o fator vira `f[i]` (degraus). `final` = fator depois
-- de `duracao` (1 = volta ao normal, 0 = apagada). Tipos: "piscar" 2-4 piscadas (apaga 0,05-0,15 s, acende 0,05-0,20 s) e fica a 60 %
-- por 0,1 s; "apagar" 3-6 falhas cada vez mais fracas e morre; "ligar" 1-3 falhas começando no escuro e acende.
function Lanterna.padraoFalha(semente: number, tipo: string): PadraoFalha
	local u = sorteador(semente)
	local t: { number }, f: { number } = {}, {}
	local relogio = 0
	local function degrau(fator: number, dur: number)
		table.insert(t, relogio)
		table.insert(f, fator)
		relogio += dur
	end
	if tipo == "apagar" then
		local n = 3 + math.floor(u() * 4) -- 3..6
		for i = 1, n do
			degrau(0, entre(u(), 0.04, 0.18))
			degrau(entre(u(), 0.9, 1) - 0.5 * (i - 1) / n, entre(u(), 0.04, 0.25))
		end
		degrau(0, 0)
		return { t = t, f = f, duracao = relogio, final = 0 }
	end
	if tipo == "ligar" then
		local n = 1 + math.floor(u() * 3) -- 1..3
		for _ = 1, n do
			degrau(0, entre(u(), 0.06, 0.2))
			degrau(entre(u(), 0.3, 0.8), entre(u(), 0.05, 0.15))
		end
		degrau(1, 0)
		return { t = t, f = f, duracao = relogio, final = 1 }
	end
	local n = 2 + math.floor(u() * 3) -- 2..4
	for _ = 1, n do
		degrau(0, entre(u(), 0.05, 0.15))
		degrau(1, entre(u(), 0.05, 0.2))
	end
	degrau(0.6, 0.1)
	degrau(1, 0)
	return { t = t, f = f, duracao = relogio, final = 1 }
end

-- Fator de brilho (0..1) `dt` s depois do início da falha. Antes (dt < 0) vale 1; depois de `duracao` vale `final`.
function Lanterna.fatorFalha(p: PadraoFalha, dt: number): number
	if dt ~= dt or dt < 0 then
		return 1
	end
	if dt >= p.duracao then
		return p.final
	end
	local fator = 1
	for i = 1, #p.t do
		if p.t[i] <= dt then
			fator = p.f[i]
		else
			break
		end
	end
	return fator
end

-- Quanto tempo aceso até a próxima falha: `u` em [0, 1) sorteado pelo chamador.
function Lanterna.proximaFalha(cfg: CfgFalha, u: number): number
	return entre(math.clamp(u, 0, 1), cfg.intervalo[1], cfg.intervalo[2])
end

-- Tipo da falha que acontece agora: "apagar" com `chanceApagar`, senão "piscar". `u` em [0, 1).
function Lanterna.tipoFalha(cfg: CfgFalha, u: number): string
	return if u < cfg.chanceApagar then "apagar" else "piscar"
end

-- Balanço da lanterna ao andar. Devolve (dx, dy) em studs, no espaço da câmera. Parado = (0, 0).
-- A amplitude cresce com a velocidade (studs/s) até `fatorMaximo`; o lateral oscila na metade da frequência vertical.
function Lanterna.balanco(t: number, velocidade: number, cfg: CfgBalanco): (number, number)
	if velocidade ~= velocidade or velocidade <= 0 then
		return 0, 0
	end
	local fator = math.min(velocidade / cfg.velocidadeRef, cfg.fatorMaximo)
	local fase = t * cfg.frequencia * 2 * math.pi
	return math.sin(fase / 2) * cfg.amplitudeX * fator, math.sin(fase) * cfg.amplitudeY * fator
end

-- Compensação pela distância da superfície no centro do facho (2026-11-17): de perto a luz estoura em branco e apaga a parede,
-- de longe some. Fator = (d / distRef) ^ expoente, entre `minimo` e 1. d = nil (nada à frente) = 1.
export type CfgCompensacao = { distRef: number, expoente: number, minimo: number, meiaVida: number }
function Lanterna.fatorDistancia(d: number?, cfg: CfgCompensacao): number
	if d == nil then
		return 1
	end
	local x = math.max(d, 0) / cfg.distRef
	return math.clamp(x ^ cfg.expoente, cfg.minimo, 1)
end

return Lanterna
