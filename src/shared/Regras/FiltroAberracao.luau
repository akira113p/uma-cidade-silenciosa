--!strict
-- Contas da aberração cromática (docs/filtro.md §4). Puras: sem Roblox. Dono: S2.

local FiltroAberracao = {}

local FOV_MIN = 1 -- limites de Camera.FieldOfView
local FOV_MAX = 120

export type Cfg = {
	base: number,
	extraDano: number,
	extraSusto: number,
	extraCaca: number,
	fovDelta: number,
	pesoCor: number,
}

local function limitar(v: number, a: number, b: number): number
	return math.max(a, math.min(b, v))
end

-- Intensidade 0..1 do quadro: base + pulsos, limitada a 1.
function FiltroAberracao.intensidade(cfg: Cfg, dano: number, susto: number, caca: number): number
	local i = cfg.base + dano * cfg.extraDano + susto * cfg.extraSusto + caca * cfg.extraCaca
	return limitar(i, 0, 1)
end

-- (fovVermelho, fovCiano) em graus; vermelho < base < ciano. Intensidade 0 → os dois iguais à base.
function FiltroAberracao.fovs(fovBase: number, intensidade: number, cfg: Cfg): (number, number)
	local delta = cfg.fovDelta * limitar(intensidade, 0, 1)
	return limitar(fovBase - delta, FOV_MIN, FOV_MAX), limitar(fovBase + delta, FOV_MIN, FOV_MAX)
end

-- ImageTransparency (vermelho, ciano). Camadas compostas por alfa: o vermelho fica EMBAIXO e o ciano POR CIMA
-- (ZIndex 1 e 2). Com w = pesoCor × intensidade: ciano pesa 1 - tC = w; vermelho pesa tC(1 - tR) = w (iguais);
-- a cena real fica com tC × tR = 1 - 2w. Intensidade 0 → (1, 1), invisíveis.
function FiltroAberracao.transparencias(intensidade: number, cfg: Cfg): (number, number)
	local w = cfg.pesoCor * limitar(intensidade, 0, 1)
	local tC = 1 - w
	return 1 - w / tC, tC
end

-- Fração de névoa (0..1) a dist da câmera: 0 antes de fogStart, 1 depois de fogEnd, linear no meio.
function FiltroAberracao.fatorNevoa(dist: number, fogStart: number, fogEnd: number): number
	if fogEnd <= fogStart then
		return if dist >= fogStart then 1 else 0
	end
	return limitar((dist - fogStart) / (fogEnd - fogStart), 0, 1)
end

-- 1 até `perto`, 0 a partir de `longe`, smoothstep entre eles.
function FiltroAberracao.fatorFranja(dist: number, perto: number, longe: number): number
	if longe <= perto then
		return if dist <= perto then 1 else 0
	end
	local t = limitar((dist - perto) / (longe - perto), 0, 1)
	return 1 - t * t * (3 - 2 * t)
end

-- Distância da câmera à caixa alinhada aos eixos (centro c, tamanho s); 0 se dentro.
function FiltroAberracao.distanciaCaixa(
	camX: number,
	camY: number,
	camZ: number,
	cx: number,
	cy: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number
): number
	local dx = math.max(math.abs(camX - cx) - sx / 2, 0)
	local dy = math.max(math.abs(camY - cy) - sy / 2, 0)
	local dz = math.max(math.abs(camZ - cz) - sz / 2, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Mistura a cor (r,g,b) com a da névoa (fr,fg,fb) pelo fator 0..1.
function FiltroAberracao.corNevoa(
	r: number,
	g: number,
	b: number,
	fr: number,
	fg: number,
	fb: number,
	fator: number
): (number, number, number)
	local f = limitar(fator, 0, 1)
	return r + (fr - r) * f, g + (fg - g) * f, b + (fb - b) * f
end

-- Até onde um monstro ganha clone: raioDinamico, mas não além de fracao da rampa da névoa.
function FiltroAberracao.alcanceDinamico(raio: number, fogStart: number, fogEnd: number, fracao: number): number
	return math.min(raio, fogStart + (fogEnd - fogStart) * fracao)
end

-- Superfície grande e plana (chão, calçada): menor dimensão < espessura e maior > ladoMax.
function FiltroAberracao.ehPlano(x: number, y: number, z: number, espessura: number, ladoMax: number): boolean
	return math.min(x, y, z) < espessura and math.max(x, y, z) > ladoMax
end

export type Pos = { X: number, Y: number, Z: number }

-- Índice inteiro da célula que contém a coordenada.
function FiltroAberracao.indice(v: number, tamanho: number): number
	return math.floor(v / tamanho)
end

function FiltroAberracao.chave(ix: number, iz: number): string
	return ix .. "," .. iz
end

-- Chaves "x,z" (índices inteiros) das células cujo quadrado toca o círculo (raio) em torno de pos no plano XZ.
-- Sem duplicata, da mais perto para a mais longe (a fila de clonagem começa pelo que está debaixo da câmera).
function FiltroAberracao.celulas(pos: Pos, tamanho: number, raio: number): { string }
	local minX = FiltroAberracao.indice(pos.X - raio, tamanho)
	local maxX = FiltroAberracao.indice(pos.X + raio, tamanho)
	local minZ = FiltroAberracao.indice(pos.Z - raio, tamanho)
	local maxZ = FiltroAberracao.indice(pos.Z + raio, tamanho)
	local achadas: { { chave: string, d2: number } } = {}
	for ix = minX, maxX do
		local dx = math.max(ix * tamanho - pos.X, 0, pos.X - (ix + 1) * tamanho)
		for iz = minZ, maxZ do
			local dz = math.max(iz * tamanho - pos.Z, 0, pos.Z - (iz + 1) * tamanho)
			local d2 = dx * dx + dz * dz
			if d2 <= raio * raio then
				table.insert(achadas, { chave = FiltroAberracao.chave(ix, iz), d2 = d2 })
			end
		end
	end
	table.sort(achadas, function(a, b)
		if a.d2 ~= b.d2 then
			return a.d2 < b.d2
		end
		return a.chave < b.chave
	end)
	local chaves = table.create(#achadas)
	for i, a in achadas do
		chaves[i] = a.chave
	end
	return chaves
end

return FiltroAberracao
