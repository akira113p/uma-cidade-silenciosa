--!strict
-- Fórmulas da câmera em primeira pessoa (docs/calculos.md §5). Puras: sem Roblox. Dono: P2.

local Camera = {}

-- sin(fase/2) repete a cada 4π e |sin(fase)| a cada π; 4π serve para os dois.
local PERIODO = 4 * math.pi

export type ModoCfg = { amplitude: number, inclinacao: number, fov: number }
export type Cfg = {
	modos: { [string]: ModoCfg },
	aterrissagem: { divisorVelocidade: number, maximo: number, duracao: number },
}

-- fase += passos/s × π × dt. Quem chama só avança quando o personagem anda.
function Camera.avancarFase(fase: number, passosPorSegundo: number, dt: number): number
	-- π por passo: |sin(fase)| tem um fundo (pé no chão) por passo do Ruido; o balanço lateral (fase/2) fecha em 2 passos
	return (fase + passosPorSegundo * math.pi * dt) % PERIODO
end

-- intensidade em 0..100 (percentual, como Pref_Intensidade); multiplica as três saídas.
-- Devolve (dy studs, dx studs, roll graus). Modo desconhecido ou "parado" = 0.
function Camera.offset(fase: number, modo: string, intensidade: number, cfg: Cfg): (number, number, number)
	local m = cfg.modos[modo]
	if not m then
		return 0, 0, 0
	end
	local k = math.clamp(intensidade, 0, 100) / 100
	local metade = math.sin(fase / 2)
	local dy = m.amplitude * math.abs(math.sin(fase)) * k
	local dx = m.amplitude * 0.5 * metade * k
	local roll = m.inclinacao * metade * k
	return dy, dx, roll
end

-- Decaimento linear: amplitude em t = 0, zero em t >= duracao.
function Camera.tremor(amplitude: number, t: number, duracao: number): number
	if duracao <= 0 or t >= duracao then
		return 0
	end
	return amplitude * (1 - math.max(t, 0) / duracao)
end

-- min(velocidade vertical / divisor, 1) × máximo. Sinal da velocidade não importa (queda é negativa no Roblox).
function Camera.tremorAterrissagem(velVertical: number, cfg: Cfg): number
	local a = cfg.aterrissagem
	return math.min(math.abs(velVertical) / a.divisorVelocidade, 1) * a.maximo
end

-- FOV alvo: base (Pref_FOV) + diferença do modo para "parado" (correr = +8 no Config).
function Camera.fovAlvo(modo: string, base: number, cfg: Cfg): number
	local m = cfg.modos[modo]
	local parado = cfg.modos.parado
	if not m or not parado then
		return base
	end
	return base + (m.fov - parado.fov)
end

-- Modo de balanço: agachado vence correr; sem movimento = parado.
function Camera.modo(agachado: boolean, correndo: boolean, movendo: boolean): string
	if not movendo then
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

return Camera
