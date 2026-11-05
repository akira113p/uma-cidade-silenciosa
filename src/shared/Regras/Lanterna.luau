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

return Lanterna
