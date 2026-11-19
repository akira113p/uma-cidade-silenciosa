--!strict
-- Regras puras do bloqueio de pistola pelo MonstroPS1 (docs/monstros/logica.md §6.5). Vetores como { x, y, z }.

export type V3 = { x: number, y: number, z: number }

local Aparar = {}

-- `frente` = LookVector do monstro; `direcaoTiro` = direção em que a bala viaja. O atirador está no lado OPOSTO da direção do
-- tiro, então o tiro vem da frente se -direcaoTiro cai dentro de cone/2 graus de `frente` (só no plano horizontal).
function Aparar.vemDaFrente(frente: V3, direcaoTiro: V3, cone: number): boolean
	local fx, fz = frente.x, frente.z
	local dx, dz = -direcaoTiro.x, -direcaoTiro.z
	local m = math.sqrt(fx * fx + fz * fz) * math.sqrt(dx * dx + dz * dz)
	if m < 1e-6 then
		return false
	end
	local c = math.clamp((fx * dx + fz * dz) / m, -1, 1)
	return math.deg(math.acos(c)) <= cone / 2
end

function Aparar.ehTronco(nome: string, naoTronco: { string }): boolean
	local n = string.lower(nome)
	for _, trecho in naoTronco do
		if string.find(n, trecho, 1, true) then
			return false
		end
	end
	return true
end

function Aparar.emEstado(estado: unknown, estados: { string }): boolean
	return type(estado) == "string" and table.find(estados, estado) ~= nil
end

-- Multiplicador de dano final (1 = sem bloqueio).
function Aparar.multiplicador(
	classe: string,
	estado: unknown,
	nomeParte: string,
	frente: V3,
	direcaoTiro: V3,
	cfg: any
): number
	if
		table.find(cfg.classesBloqueadas, classe)
		and Aparar.emEstado(estado, cfg.estados)
		and Aparar.ehTronco(nomeParte, cfg.naoTronco)
		and Aparar.vemDaFrente(frente, direcaoTiro, cfg.cone)
	then
		return cfg.multiplicador
	end
	return 1
end

return Aparar
