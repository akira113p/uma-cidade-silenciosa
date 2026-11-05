-- Relevo (T1): chão do mapa como grade de lajes grossas inclinadas (pasta Chao), colinas por ruído determinístico,
-- rios escavados (plano.profundidadeRio) e as Parts invisíveis `Agua` (pasta Rios) que o servidor transforma em Terrain.
-- Define ctx.altura(x,z) = superfície real das lajes. Contrato: docs/mapa-v2.md §8 T1.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local floor, ceil, min, max, abs, sqrt, sin = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt, math.sin

local M = {}

local SOBREPOSICAO = 2 -- quanto cada laje passa da sua célula (cobre as frestas entre lajes vizinhas)
local DISTANCIA_AMORTECE = 80 -- as colinas só crescem a esta distância da margem de um rio
local NIVEL_AGUA = -0.8 -- topo da água
local BALDE = 16 -- grade de busca de ctx.altura
local SUBIDA = 2.5 -- a subida a partir das áreas planas leva SUBIDA × margemPlano (curvatura baixa: evita degraus entre lajes vizinhas)

local COR = {
	Grass = { 58, 74, 52 },
	Ground = { 84, 72, 54 },
	Mud = { 62, 52, 42 },
	Rock = { 90, 90, 86 },
	Sand = { 118, 108, 84 },
}

local function suave(t: number): number
	t = max(0, min(1, t))
	return t * t * (3 - 2 * t)
end

function M.gerar(ctx)
	local Mundo, P = ctx.Mundo, ctx.plano
	local R = Mundo.relevo
	local meio = Mundo.tamanho / 2
	local semente = (Mundo.semente or 1) % 100003
	local esp = R.espessuraLaje

	-- -------------------------------------------------------------------------------------------------------------
	-- Ruído de valor (hash por seno) com 3 oitavas: 0..1, determinístico
	-- -------------------------------------------------------------------------------------------------------------
	local function hash(ix: number, iz: number, o: number): number
		local s = sin(ix * 127.1 + iz * 311.7 + o * 74.7 + semente * 0.01731) * 43758.5453
		return s - floor(s)
	end
	local function valor(x: number, z: number, o: number): number
		local ix, iz = floor(x), floor(z)
		local fx, fz = x - ix, z - iz
		fx = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
		fz = fz * fz * fz * (fz * (fz * 6 - 15) + 10)
		local a, b = hash(ix, iz, o), hash(ix + 1, iz, o)
		local c, d = hash(ix, iz + 1, o), hash(ix + 1, iz + 1, o)
		return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz
	end
	local function colinas(x: number, z: number): number -- 0..1
		local l = R.comprimentoOnda
		local f = valor(x / l, z / l, 1) * 0.62
			+ valor(x / (l / 2) + 17.3, z / (l / 2) + 9.1, 2) * 0.28
			+ valor(x / (l / 4) + 3.7, z / (l / 4) + 41.9, 3) * 0.10
		return max(0, min(1, (f - 0.25) / 0.5)) ^ 1.4
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Cota do terreno num ponto (com cache): altura da superfície e profundidade do rio ali
	-- -------------------------------------------------------------------------------------------------------------
	local cacheH, cacheP = {}, {}
	local function cota(x: number, z: number): (number, number)
		local chave = (floor(x * 2 + 0.5) + 8000) * 20000 + (floor(z * 2 + 0.5) + 8000)
		local h = cacheH[chave]
		if h then
			return h, cacheP[chave]
		end
		local dp = P.distPlano(x, z)
		local folga = P.folgaRio(x, z)
		local prof = 0
		if folga < 0 then
			prof = P.profundidadeRio(x, z)
		end
		-- dentro das áreas planas o chão fica 0,2 abaixo do pad (Y 0,5) para não brigar com ele
		local base0 = 0.3 + 0.2 * min(1, dp / 6)
		h = base0
			+ R.amplitude * colinas(x, z) * suave(dp / (R.margemPlano * SUBIDA)) * suave(folga / DISTANCIA_AMORTECE)
		if prof > 0 then
			h = base0 * (1 - min(1, prof / 2)) - prof -- o leito fica exatamente em −profundidade
		end
		cacheH[chave], cacheP[chave] = h, prof
		return h, prof
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Lajes
	-- -------------------------------------------------------------------------------------------------------------
	local baldes = {}
	local function chaveBalde(i: number, j: number): number
		return (i + 400) * 1000 + (j + 400)
	end
	local pasta = ctx.pastas.Chao
	local rngCor = ctx.rng("relevo")
	local contagem, inclMax, hMin, hMax = 0, 0, math.huge, -math.huge
	local porMaterial = {}

	local function laje(x0: number, x1: number, z0: number, z1: number, rio)
		local h00, p00 = cota(x0, z0)
		local h10, p10 = cota(x1, z0)
		local h01, p01 = cota(x0, z1)
		local h11, p11 = cota(x1, z1)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local _, pc = cota(cx, cz)
		local w, d = x1 - x0, z1 - z0
		-- plano ajustado aos 4 cantos
		local ha = (h00 + h10 + h01 + h11) / 4
		local gx = ((h10 + h11) - (h00 + h01)) / (2 * w)
		local gz = ((h01 + h11) - (h00 + h10)) / (2 * d)
		local incl = sqrt(gx * gx + gz * gz)
		inclMax = max(inclMax, incl)
		hMin, hMax = min(hMin, ha - incl * max(w, d) / 2), max(hMax, ha + incl * max(w, d) / 2)

		-- material e cor
		local pm = max(p00, p10, p01, p11, pc)
		local material
		if pm >= 0.4 then
			local fundo = pm / (if rio then rio.profundidade else 6)
			material = if fundo >= 0.6 then "Sand" else "Mud"
		elseif incl > 0.5 then
			material = "Rock"
		elseif incl > 0.3 then
			material = "Ground"
		else
			local mancha = valor(cx / 70 + 5.5, cz / 70 + 2.5, 4)
			material = if mancha > 0.78 then "Ground" elseif mancha < 0.14 then "Mud" else "Grass"
		end
		local cor = ctx.variar(COR[material], 0.09, rngCor)
		porMaterial[material] = (porMaterial[material] or 0) + 1

		-- orientação: x ao longo da encosta em X; y = normal; z = x × y
		local xv = Vector3.new(1, gx, 0).Unit
		local yv = Vector3.new(-gx, 1, -gz).Unit
		local zv = xv:Cross(yv)
		local lx = sqrt(1 + gx * gx)
		local ln = sqrt(1 + gx * gx + gz * gz)
		local ov = 2 * SOBREPOSICAO
		local tz = (d + ov) * lx * ln / (1 + gx * gx) -- comprimento local em Z que cobre a célula
		local desvio = (d + ov) * abs(gx * gz) / (1 + gx * gx) -- a laje inclinada entorta a pegada: cobre com folga
		local tx = (w + ov + desvio) * lx
		local centro = Vector3.new(cx, ha, cz) - yv * (esp / 2)
		ctx.bloco(
			pasta,
			CFrame.new(),
			"Chao",
			centro.X,
			centro.Y,
			centro.Z,
			tx,
			esp,
			tz,
			cor,
			material,
			{ rot = CFrame.fromMatrix(Vector3.new(0, 0, 0), xv, yv, zv) }
		)
		contagem += 1

		local rec = {
			x0 = x0 - SOBREPOSICAO,
			x1 = x1 + SOBREPOSICAO,
			z0 = z0 - SOBREPOSICAO,
			z1 = z1 + SOBREPOSICAO,
			h = ha,
			gx = gx,
			gz = gz,
			cx = cx,
			cz = cz,
		}
		for i = floor(rec.x0 / BALDE), floor(rec.x1 / BALDE) do
			for j = floor(rec.z0 / BALDE), floor(rec.z1 / BALDE) do
				local k = chaveBalde(i, j)
				local l = baldes[k]
				if not l then
					l = {}
					baldes[k] = l
				end
				table.insert(l, rec)
			end
		end
	end

	-- ctx.altura: maior plano de laje que cobre o ponto; fora das lajes (áreas planas puladas) vale o nível dos pads
	ctx.altura = function(x: number, z: number): number
		x, z = max(-meio, min(meio, x)), max(-meio, min(meio, z))
		local l = baldes[chaveBalde(floor(x / BALDE), floor(z / BALDE))]
		local melhor = nil
		if l then
			for _, r in l do
				if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
					local h = r.h + r.gx * (x - r.cx) + r.gz * (z - r.cz)
					if melhor == nil or h > melhor then
						melhor = h
					end
				end
			end
		end
		return melhor or ctx.NIVEL_PAD
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Grade grossa; refina (sub-células) onde o rio toca a célula; pula células inteiras em área plana
	-- -------------------------------------------------------------------------------------------------------------
	local n = ceil(Mundo.tamanho / R.celula)
	local c = Mundo.tamanho / n
	local puladas, refinadas = 0, 0
	for i = 0, n - 1 do
		local x0 = -meio + i * c
		for j = 0, n - 1 do
			local z0 = -meio + j * c
			local cx, cz = x0 + c / 2, z0 + c / 2
			local folga, rio = P.folgaRio(cx, cz)
			if folga < c * 0.55 and rio then
				refinadas += 1
				local f = if rio.largura < 20 then 4 else 3
				local s = c / f
				for a = 0, f - 1 do
					for b = 0, f - 1 do
						laje(x0 + a * s, x0 + (a + 1) * s, z0 + b * s, z0 + (b + 1) * s, rio)
					end
				end
			else
				local dentro = false
				for _, r in P.planos do
					if
						x0 - 2 * SOBREPOSICAO >= r.x0
						and x0 + c + 2 * SOBREPOSICAO <= r.x1
						and z0 - 2 * SOBREPOSICAO >= r.z0
						and z0 + c + 2 * SOBREPOSICAO <= r.z1
					then
						dentro = true
						break
					end
				end
				if dentro then
					puladas += 1
				else
					laje(x0, x0 + c, z0, z0 + c, nil)
				end
			end
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Água: uma Part invisível por trecho da linha central (o Terrain é preenchido por src/server/Rios.luau)
	-- -------------------------------------------------------------------------------------------------------------
	local nAgua = 0
	for _, r in P.rios do
		local dn = r.denso
		-- largura da superfície a Y = NIVEL_AGUA: o perfil do leito (cosseno) cruza essa cota um pouco além do canal
		local t = 0
		if r.profundidade > -NIVEL_AGUA then
			t = math.acos(max(-1, min(1, 2 * -NIVEL_AGUA / r.profundidade - 1))) / math.pi
		end
		local largura = 2 * (r.largura / 2 + t * r.margem) + 2
		local altura = r.profundidade + NIVEL_AGUA + 1
		for k = 1, #dn - 1 do
			local a, b = dn[k], dn[k + 1]
			local comp = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			if comp > 0.01 then
				local cy = NIVEL_AGUA - altura / 2
				local p = Instance.new("Part")
				p.Name = "Agua"
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Transparency = 1
				p.Size = Vector3.new(largura, altura, comp + 2)
				p.CFrame =
					CFrame.lookAt(Vector3.new((a[1] + b[1]) / 2, cy, (a[2] + b[2]) / 2), Vector3.new(b[1], cy, b[2]))
				p:SetAttribute("Rio", r.nome)
				p.Parent = ctx.pastas.Rios
				nAgua += 1
			end
		end
	end

	local partes = {}
	for m, q in porMaterial do
		table.insert(partes, m .. "=" .. q)
	end
	table.sort(partes)
	print(
		string.format(
			"[relevo] Chao %d lajes (células %d×%d de %.1f; %d refinadas, %d puladas); cota %.1f..%.1f; inclinação máx %.1f°; Agua %d | %s",
			contagem,
			n,
			n,
			c,
			refinadas,
			puladas,
			hMin,
			hMax,
			math.deg(math.atan(inclMax)),
			nAgua,
			table.concat(partes, " ")
		)
	)
end

return M
