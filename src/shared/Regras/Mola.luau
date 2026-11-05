--!strict
-- Mola amortecida em 3D para o viewmodel (balanço, sway, coice). Puro, sem Instance. Contrato: docs/armas.md §5. Dono: A1.
-- Integração semi-implícita de Euler com subpassos: estável para dt grande (um frame lento de 0,05 s não explode).

export type Estado = { x: number, y: number, z: number, vx: number, vy: number, vz: number }
export type Alvo = { x: number, y: number, z: number }

local Mola = {}

local PASSO_MAX = 1 / 240 -- s por subpasso
local DT_MAX = 0.1 -- dt maior que isto é cortado (aba em segundo plano, engasgo)
local SUBPASSOS_MAX = 40

function Mola.novo(x: number?, y: number?, z: number?): Estado
	return { x = x or 0, y = y or 0, z = z or 0, vx = 0, vy = 0, vz = 0 }
end

-- a = rigidez × (alvo - x) - amortecimento × v. Muda `estado` no lugar e devolve ele.
-- Rigidez ~ 100..400 e amortecimento ~ 2·√rigidez é amortecimento crítico (sem oscilar).
function Mola.passo(estado: Estado, alvo: Alvo, rigidez: number, amortecimento: number, dt: number): Estado
	if not (dt == dt) or dt <= 0 then
		return estado
	end
	if dt > DT_MAX then
		dt = DT_MAX
	end
	local n = math.clamp(math.ceil(dt / PASSO_MAX), 1, SUBPASSOS_MAX)
	local h = dt / n
	for _ = 1, n do
		estado.vx += (rigidez * (alvo.x - estado.x) - amortecimento * estado.vx) * h
		estado.vy += (rigidez * (alvo.y - estado.y) - amortecimento * estado.vy) * h
		estado.vz += (rigidez * (alvo.z - estado.z) - amortecimento * estado.vz) * h
		estado.x += estado.vx * h
		estado.y += estado.vy * h
		estado.z += estado.vz * h
	end
	return estado
end

-- Empurrão instantâneo (coice): soma à velocidade.
function Mola.impulso(estado: Estado, x: number, y: number, z: number)
	estado.vx += x
	estado.vy += y
	estado.vz += z
end

return Mola
