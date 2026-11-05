--!strict
-- Balística do item largado (docs/itens-no-mundo.md §3-B). Pura: sem Instance nem Vector3 (as Regras do projeto
-- usam tabelas {x,y,z}; o servidor converte de/para Vector3 ao chamar). Determinística e sempre termina (maxPassos).

export type Vec = { x: number, y: number, z: number }
-- Raio de a até b: devolve (ponto do acerto, normal unitária) ou nil se não acertou.
export type Raio = (a: Vec, b: Vec) -> (Vec?, Vec?)
export type Resultado = { pontos: { Vec }, repouso: Vec, normal: Vec, tocouChao: boolean }

local CHAO_NORMAL_Y = 0.7 -- normal.y >= isto: é chão, o item para
local RESTO_PAREDE = 0.3 -- fração da velocidade que sobra ao escorregar numa parede/teto
local AFASTAR = 0.05 -- studs: recomeça do acerto + normal × isto

local Arremesso = {}

-- gravidade: aceleração para baixo em studs/s² (workspace.Gravity; o sinal é ignorado).
function Arremesso.simular(
	origem: Vec,
	velocidade: Vec,
	gravidade: number,
	passo: number,
	maxPassos: number,
	raio: Raio
): Resultado
	local g = math.abs(gravidade)
	local px, py, pz = origem.x, origem.y, origem.z
	local vx, vy, vz = velocidade.x, velocidade.y, velocidade.z
	local pontos: { Vec } = { { x = px, y = py, z = pz } }

	for _ = 1, maxPassos do
		vy -= g * passo
		local nx, ny, nz = px + vx * passo, py + vy * passo, pz + vz * passo
		local acerto, normal = raio({ x = px, y = py, z = pz }, { x = nx, y = ny, z = nz })
		if acerto then
			local n: Vec = normal or { x = 0, y = 1, z = 0 }
			if n.y >= CHAO_NORMAL_Y then
				table.insert(pontos, { x = acerto.x, y = acerto.y, z = acerto.z })
				return { pontos = pontos, repouso = acerto, normal = n, tocouChao = true }
			end
			-- parede/teto: tira a componente na normal, o resto perde força; segue de acerto + normal × AFASTAR
			local dot = vx * n.x + vy * n.y + vz * n.z
			vx = (vx - n.x * dot) * RESTO_PAREDE
			vy = (vy - n.y * dot) * RESTO_PAREDE
			vz = (vz - n.z * dot) * RESTO_PAREDE
			px, py, pz = acerto.x + n.x * AFASTAR, acerto.y + n.y * AFASTAR, acerto.z + n.z * AFASTAR
		else
			px, py, pz = nx, ny, nz
		end
		table.insert(pontos, { x = px, y = py, z = pz })
	end

	return { pontos = pontos, repouso = { x = px, y = py, z = pz }, normal = { x = 0, y = 1, z = 0 }, tocouChao = false }
end

return Arremesso
