-- Edifícios especiais: igreja, capela, cripta, posto da guarda florestal (catálogo) e as áreas cemitério e acampamento.
-- Contrato em docs/mapa-v2.md §5/§8 (E5). Coordenadas locais: origem no centro da pegada, Y = topo do pad, frente −Z.

local roblox = require("@lune/roblox")
local CFrame, Instance, Vector2, UDim2, Enum = roblox.CFrame, roblox.Instance, roblox.Vector2, roblox.UDim2, roblox.Enum

local Mob = require("./mobilia")
local Props = require("./props")
local Cat = require("./catalogo")

local pi, cos, sin, atan2, abs, ceil, max, min, sqrt =
	math.pi, math.cos, math.sin, math.atan2, math.abs, math.ceil, math.max, math.min, math.sqrt

local M = { catalogo = {}, areas = {} }

local NC = { colide = false, consulta = false, sombra = false }

-- ---------------------------------------------------------------------------------------------------------------
-- Ajudantes
-- ---------------------------------------------------------------------------------------------------------------
local function placa(ctx, pai, cf, cx, cy, cz, sx, sy, texto, fundo, corTexto)
	local p = ctx.bloco(pai, cf, "Placa", cx, cy, cz, sx, sy, 0.4, fundo, "SmoothPlastic")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(sx * 50, sy * 50)
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = texto
	t.TextColor3 = ctx.rgb(corTexto)
	t.TextScaled = true
	t.Parent = gui
	return p
end

-- folha de porta aberta, presa em (hx,hz) local; ang = direção no plano XZ (0 = +X)
local function folha(ctx, pai, cf, hx, hz, ang, comp, alt, cor, mat)
	local dx, dz = cos(ang), sin(ang)
	ctx.bloco(pai, cf, "Folha", hx + dx * comp / 2, alt / 2, hz + dz * comp / 2, comp, alt, 0.3, cor, mat, {
		colide = false,
		consulta = false,
		rotY = atan2(-dz, dx),
	})
end

-- triângulo de oitão em degraus sob um telhado de duas águas (meia = meia largura na base)
local function oitao(ctx, pai, cf, cx, z, meia, yBase, altura, esp, cor, mat)
	local n = max(2, ceil(altura / 1.5))
	local h = altura / n
	for i = 1, n - 1 do
		ctx.bloco(pai, cf, "Oitao", cx, yBase + (i - 0.5) * h, z, 2 * meia * (1 - i / n), h, esp, cor, mat)
	end
end

local function vitral(ctx, pai, cf, x, z, yc, alt, larg, cor)
	ctx.bloco(pai, cf, "Vitral", x, yc, z, 0.15, alt, larg, cor, "Glass", {
		transparencia = 0.4,
		colide = false,
		sombra = false,
	})
end

local PAL_IGREJA = {
	{
		parede = { 175, 175, 172 },
		telhado = { 50, 44, 44 },
		piso = { 70, 50, 38 },
		detalhe = { 140, 140, 136 },
		banco = { 100, 72, 52 },
		tapete = { 110, 36, 36 },
		vitral = { { 150, 40, 40 }, { 40, 70, 140 }, { 190, 150, 50 }, { 50, 110, 70 } },
	},
	{
		parede = { 176, 168, 146 },
		telhado = { 60, 45, 42 },
		piso = { 64, 46, 36 },
		detalhe = { 130, 120, 100 },
		banco = { 92, 66, 48 },
		tapete = { 40, 60, 100 },
		vitral = { { 170, 60, 50 }, { 60, 90, 150 }, { 200, 170, 70 }, { 80, 120, 80 } },
	},
	{
		parede = { 168, 140, 126 },
		telhado = { 46, 40, 42 },
		piso = { 76, 54, 40 },
		detalhe = { 128, 104, 92 },
		banco = { 104, 76, 56 },
		tapete = { 90, 40, 60 },
		vitral = { { 140, 50, 60 }, { 50, 60, 120 }, { 180, 140, 60 }, { 60, 100, 90 } },
	},
	{
		parede = { 150, 156, 162 },
		telhado = { 42, 48, 56 },
		piso = { 58, 54, 52 },
		detalhe = { 116, 122, 128 },
		banco = { 84, 62, 48 },
		tapete = { 100, 36, 36 },
		vitral = { { 120, 40, 40 }, { 40, 80, 130 }, { 170, 150, 60 }, { 50, 100, 80 } },
	},
	{
		parede = { 170, 156, 128 },
		telhado = { 56, 44, 38 },
		piso = { 72, 52, 36 },
		detalhe = { 134, 120, 96 },
		banco = { 96, 70, 50 },
		tapete = { 60, 70, 50 },
		vitral = { { 160, 50, 40 }, { 60, 80, 130 }, { 190, 160, 60 }, { 70, 110, 70 } },
	},
}

local BRONZE = { 128, 98, 52 }

-- ---------------------------------------------------------------------------------------------------------------
-- IGREJA 30×54: torre sineira na frente, nave comprida atrás. Placa na frente, dentro da pegada.
-- ---------------------------------------------------------------------------------------------------------------
local function igreja(ctx, spec)
	local rng = spec.rng or ctx.rng("igreja")
	local p = spec.paleta or PAL_IGREJA[1]
	local m = ctx.modeloConstrucao(spec, "igreja", "igreja", 30, 54, 48, 1)
	local cf = spec.cf
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
		return ctx.bloco(m, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end
	local function parede(nome, a, c, base, alt, esp, cor, mat, ab, op)
		return ctx.parede(m, cf, nome, a, c, base, alt, esp, cor, mat, ab, op)
	end
	local lado = rng.sinal()
	local ZF, ZT, ZB, NH = -23, -9, 27, 18
	local zc = (ZF + ZT) / 2
	local tij, det = p.parede, p.detalhe

	-- torre
	parede("Torre", { -6.5, ZF + 0.5 }, { 6.5, ZF + 0.5 }, 0, 16, 1, tij, "Brick", {
		{ de = 6.5, larg = 7, tipo = "vao", alt = 8.5 },
	})
	local janelaAlta = { { de = 6.5, larg = 3.2, tipo = "janela", peitoril = 10, alt = 6, vidro = false, cor = det } }
	parede("Torre", { -6.5, ZF + 0.5 }, { 6.5, ZF + 0.5 }, 16, 24, 1, tij, "Brick", janelaAlta)
	for _, s in { -1, 1 } do
		parede("Torre", { s * 6.5, ZF + 0.5 }, { s * 6.5, ZT - 0.5 }, 0, 16, 1, tij, "Brick")
		parede("Torre", { s * 6.5, ZF + 0.5 }, { s * 6.5, ZT - 0.5 }, 16, 24, 1, tij, "Brick", janelaAlta)
	end
	parede("Torre", { -6.5, ZT - 0.5 }, { 6.5, ZT - 0.5 }, 18, 22, 1, tij, "Brick", janelaAlta)
	b("TetoVestibulo", 0, 15.6, zc, 12.4, 0.8, 12.4, det, "Concrete")
	for _, f in { { 0, ZF - 0.3, 14.8, 0.6 }, { -7.3, zc, 0.6, 14.4 }, { 7.3, zc, 0.6, 14.4 } } do
		b("Friso", f[1], 16.2, f[2], f[3], 0.5, f[4], det, "Limestone")
		b("Cornija", f[1], 39.7, f[2], f[3], 0.7, f[4], det, "Limestone")
	end
	-- telhado da torre em degraus
	for i, t in { 15.4, 11.6, 7.8, 4 } do
		b("TelhadoTorre", 0, 40 + (i - 0.5) * 1.2, zc, t, 1.2, t, p.telhado, "Slate")
	end
	b("Cruz", 0, 46.6, zc, 0.5, 3.4, 0.5, det, "Granite")
	b("Cruz", 0, 47, zc, 2, 0.5, 0.5, det, "Granite")
	-- sino
	b("TravessaSino", 0, 33.3, zc, 12, 0.8, 0.8, { 70, 50, 38 }, "Wood", { colide = false })
	ctx.cilindro(m, cf, "Sino", 0, 30.6, zc, 3.2, 3, BRONZE, "Metal", { colide = false })
	ctx.esfera(m, cf, "Badalo", 0, 28.8, zc, 1, BRONZE, "Metal", { colide = false })

	-- porta dupla + degraus
	folha(ctx, m, cf, -3.4, ZF + 0.5, -1.0, 3.4, 8, p.banco, "WoodPlanks")
	folha(ctx, m, cf, 3.4, ZF + 0.5, -pi + 1.0, 3.4, 8, p.banco, "WoodPlanks")
	b("Verga", 0, 8.9, ZF - 0.2, 8.6, 0.5, 1.4, det, "Limestone", { colide = false })
	b("Degrau", 0, 0.25, ZF - 1.2, 9, 0.5, 2, det, "Concrete")

	-- nave
	local abLado = {}
	local vit = {}
	for i, z in { -5, 1.5, 8, 21.5 } do
		table.insert(abLado, { de = z - (ZT - 0.5), larg = 3.2, tipo = "janela", peitoril = 5.5, alt = 7, cor = det })
		vit[i] = z
	end
	for _, s in { -1, 1 } do
		parede("Nave", { s * 10.5, ZT - 0.5 }, { s * 10.5, ZB - 0.5 }, 0, NH, 1, tij, "Brick", abLado)
		for i, z in vit do
			vitral(ctx, m, cf, s * 10.05, z, 9, 6.6, 3, p.vitral[i])
		end
		for _, z in { -1.75, 4.75, 14.75 } do
			b("Contraforte", s * 11.4, 8.8, z, 0.8, 17.6, 1.4, tij, "Brick")
		end
		b("Cornija", s * 11.3, 17.5, (ZT + ZB) / 2, 1.2, 0.8, 37, det, "Limestone")
	end
	parede("Nave", { -10.5, ZT - 0.5 }, { 10.5, ZT - 0.5 }, 0, NH, 1, tij, "Brick", {
		{ de = 10.5, larg = 6, tipo = "vao", alt = 9 },
	})
	parede("Nave", { -10.5, ZB - 0.5 }, { 10.5, ZB - 0.5 }, 0, NH, 1, tij, "Brick")
	ctx.telhadoDuasAguas(m, cf, "Telhado", 0, (ZT + ZB) / 2, 22, ZB - ZT, NH, 8, 1, 0.8, p.telhado, "Slate", true)
	oitao(ctx, m, cf, 0, ZB - 0.5, 12, NH, 8, 1, tij, "Brick")
	oitao(ctx, m, cf, 0, ZT - 0.2, 12, NH, 8, 0.6, tij, "Brick")
	b("Forro", 0, 17.7, (ZT + ZB) / 2, 20, 0.6, ZB - ZT - 1, { 56, 44, 36 }, "WoodPlanks")
	for _, z in { 0, 9, 18 } do
		b("Viga", 0, 17.1, z, 20, 0.7, 0.7, { 70, 50, 38 }, "Wood", NC)
	end

	-- interior
	ctx.piso(m, cf, "Piso", -6, 6, ZF + 1, ZT, 0.2, 0.2, p.piso, "WoodPlanks")
	ctx.piso(m, cf, "Piso", -10, 10, ZT, ZB - 1, 0.2, 0.2, p.piso, "WoodPlanks")
	b("Tapete", 0, 0.23, 3.7, 3.4, 0.06, 23.4, p.tapete, "Fabric", NC)
	b("Altar1", 0, 0.5, 21.1, 18, 0.6, 9.8, det, "Concrete")
	b("Altar2", 0, 0.8, 23, 15, 1.2, 6, det, "Concrete")
	local mob = { rng = rng }
	local function mobil(nome, x, y, z, rot, op)
		return Mob.colocar(ctx, m, nome, cf, x, y, z, rot, op or mob)
	end
	mobil("altar", 0, 1.4, 23.3, 0)
	mobil("cruz_parede", 0, 10, ZB - 1, 0)
	for _, c in { { -6, 1.4, 24.5 }, { 6, 1.4, 24.5 }, { -9, 0.2, 12 }, { 9, 0.2, 12 } } do
		mobil("candelabro", c[1], c[2], c[3], 0)
	end
	for _, s in { -1, 1 } do
		for i = 0, 4 do
			mobil("banco_igreja", s * 6.55, 0.2, -7.4 + 4.4 * i, pi, { rng = rng, w = 7.6, cor = p.banco })
		end
	end
	mobil("pulpito", lado * 8.6, 0.2, 13, lado * pi / 2)
	mobil("confessionario", -lado * 8.4, 0.2, 13.8, -lado * pi / 2)
	mobil("pia_batismal", -lado * 4.6, 0.2, -14, 0)

	local info = {
		loot = {
			{ x = 0, y = 0.2, z = 3 },
			{ x = 0, y = 0.2, z = 11 },
			{ x = 6.5, y = 1.4, z = 21 },
			{ x = lado * 4.6, y = 0.2, z = -17 },
		},
		frente = { 0, ZF - 6 },
		portaria = { 0, ZF },
	}
	return m, info
end
M.catalogo.igreja = { paletas = PAL_IGREJA, construir = igreja }

-- ---------------------------------------------------------------------------------------------------------------
-- CAPELA 20×28
-- ---------------------------------------------------------------------------------------------------------------
local function capela(ctx, spec)
	local rng = spec.rng or ctx.rng("capela")
	local p = spec.paleta or PAL_IGREJA[1]
	local m = ctx.modeloConstrucao(spec, "capela", "capela", 20, 28, 22, 1)
	local cf = spec.cf
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
		return ctx.bloco(m, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end
	local lado = rng.sinal()
	local tij, det = p.parede, p.detalhe
	local H = 12
	local ab = {}
	for i, z in { -4.5, 3.5 } do
		table.insert(ab, { de = z + 12.5, larg = 2.8, tipo = "janela", peitoril = 4.5, alt = 5.5, cor = det })
		ab[i].z = z
	end
	for _, s in { -1, 1 } do
		ctx.parede(m, cf, "Parede", { s * 8.5, -12.5 }, { s * 8.5, 12.5 }, 0, H, 1, tij, "Brick", ab)
		for i, z in { -4.5, 3.5 } do
			vitral(ctx, m, cf, s * 8.05, z, 7.25, 5.3, 2.6, p.vitral[i + 1])
		end
	end
	ctx.parede(m, cf, "Parede", { -8.5, -12.5 }, { 8.5, -12.5 }, 0, H, 1, tij, "Brick", {
		{ de = 8.5, larg = 7, tipo = "vao", alt = 8 },
	})
	ctx.parede(m, cf, "Parede", { -8.5, 12.5 }, { 8.5, 12.5 }, 0, H, 1, tij, "Brick")
	ctx.telhadoDuasAguas(m, cf, "Telhado", 0, 0, 18, 26, H, 5, 1, 0.7, p.telhado, "Slate", true)
	oitao(ctx, m, cf, 0, 12.5, 10, H, 5, 1, tij, "Brick")
	oitao(ctx, m, cf, 0, -12.5, 10, H, 5, 1, tij, "Brick")
	b("Forro", 0, 11.7, 0, 16, 0.6, 24, { 56, 44, 36 }, "WoodPlanks")
	-- sineira sobre a fachada
	for _, x in { -2, 2 } do
		for _, z in { -12.2, -9.6 } do
			b("PilarSino", x, 15.5, z, 0.8, 7, 0.8, tij, "Brick")
		end
	end
	b("TetoSino", 0, 19.3, -10.9, 5.4, 0.8, 4.2, p.telhado, "Slate")
	ctx.cilindro(m, cf, "Sino", 0, 16.4, -10.9, 2.2, 2.2, BRONZE, "Metal", { colide = false })
	b("Cruz", 0, 20.9, -10.9, 0.4, 2.4, 0.4, det, "Granite")
	folha(ctx, m, cf, -3.4, -12.5, -1.0, 3.4, 7.6, p.banco, "WoodPlanks")
	folha(ctx, m, cf, 3.4, -12.5, -pi + 1.0, 3.4, 7.6, p.banco, "WoodPlanks")
	b("Degrau", 0, 0.25, -13.6, 7, 0.5, 1.2, det, "Concrete")

	ctx.piso(m, cf, "Piso", -8, 8, -12, 12, 0.2, 0.2, p.piso, "WoodPlanks")
	b("Tapete", 0, 0.23, -2, 3, 0.06, 18, p.tapete, "Fabric", NC)
	b("Altar1", 0, 0.5, 9.8, 12, 0.6, 4.4, det, "Concrete")
	local function mobil(nome, x, y, z, rot, op)
		return Mob.colocar(ctx, m, nome, cf, x, y, z, rot, op or { rng = rng })
	end
	mobil("altar", 0, 0.8, 10, 0)
	mobil("cruz_parede", 0, 9, 11.5, 0)
	mobil("candelabro", -4.8, 0.8, 10.5, 0)
	mobil("candelabro", 4.8, 0.8, 10.5, 0)
	for _, s in { -1, 1 } do
		for i = 0, 2 do
			mobil("banco_igreja", s * 5.3, 0.2, -6.5 + 4.4 * i, pi, { rng = rng, w = 5.2, cor = p.banco })
		end
	end
	mobil("pia_batismal", lado * 5.5, 0.2, -10, 0)
	mobil("pulpito", -lado * 6.7, 0.2, 5, -lado * pi / 2)
	return m,
		{
			loot = { { x = 0, y = 0.2, z = -1 }, { x = 0, y = 0.2, z = 5.5 } },
			frente = { 0, -18 },
			portaria = { 0, -12.5 },
		}
end
M.catalogo.capela = { paletas = PAL_IGREJA, construir = capela }

-- ---------------------------------------------------------------------------------------------------------------
-- CRIPTA 16×18 (mausoléu)
-- ---------------------------------------------------------------------------------------------------------------
local PAL_CRIPTA = {
	{
		material = "Granite",
		parede = { 108, 110, 108 },
		telhado = { 84, 86, 88 },
		piso = { 80, 80, 82 },
		detalhe = { 128, 128, 124 },
	},
	{
		material = "Limestone",
		parede = { 150, 146, 132 },
		telhado = { 112, 108, 100 },
		piso = { 96, 92, 86 },
		detalhe = { 170, 164, 150 },
	},
	{
		material = "Basalt",
		parede = { 70, 72, 76 },
		telhado = { 52, 54, 58 },
		piso = { 58, 58, 62 },
		detalhe = { 96, 98, 102 },
	},
	{
		material = "Sandstone",
		parede = { 138, 118, 92 },
		telhado = { 98, 82, 66 },
		piso = { 90, 78, 64 },
		detalhe = { 156, 136, 108 },
	},
	{
		material = "Marble",
		parede = { 168, 170, 168 },
		telhado = { 120, 124, 126 },
		piso = { 110, 112, 114 },
		detalhe = { 190, 190, 186 },
	},
}

local function cripta(ctx, spec)
	local rng = spec.rng or ctx.rng("cripta")
	local p = spec.paleta or PAL_CRIPTA[1]
	local m = ctx.modeloConstrucao(spec, "cripta", "cripta", 16, 18, 17, 1)
	local cf = spec.cf
	local mat = p.material
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mt, op)
		return ctx.bloco(m, cf, nome, cx, cy, cz, sx, sy, sz, cor, mt or mat, op)
	end
	local planta = rng.inteiro(1, 2)
	local H = 10
	ctx.parede(m, cf, "Parede", { -6.5, -7 }, { 6.5, -7 }, 0, H, 1, p.parede, mat, {
		{ de = 6.5, larg = 8, tipo = "vao", alt = 8.2 },
	})
	ctx.parede(m, cf, "Parede", { -6.5, 8 }, { 6.5, 8 }, 0, H, 1, p.parede, mat)
	for _, s in { -1, 1 } do
		ctx.parede(m, cf, "Parede", { s * 6.5, -7 }, { s * 6.5, 8 }, 0, H, 1, p.parede, mat)
		b("Pilastra", s * 7.2, 5.4, -7.6, 1.2, 10.8, 1.2, p.detalhe)
		b("Pilastra", s * 7.2, 5.4, 8.4, 1.2, 10.8, 1.2, p.detalhe)
		ctx.cilindro(m, cf, "Coluna", s * 5.2, 4.9, -8.3, 1.6, 9.8, p.detalhe, mat)
		b("Batente", s * 4.3, 4.2, -7.6, 0.6, 8.4, 1.4, p.detalhe, mat, { colide = false })
	end
	b("Arquitrave", 0, 10.6, -8.2, 14.4, 1.2, 1.8, p.detalhe)
	oitao(ctx, m, cf, 0, -8.1, 7.2, 11.2, 3.6, 1.2, p.detalhe, mat)
	b("Cruz", 0, 15.6, -8.1, 0.5, 2.4, 0.5, p.detalhe)
	b("Cruz", 0, 16, -8.1, 1.6, 0.5, 0.5, p.detalhe)
	ctx.telhadoDuasAguas(m, cf, "Telhado", 0, 0.5, 14, 16, H, 3.4, 0.8, 0.8, p.telhado, mat, true)
	b("Forro", 0, 9.7, 0.5, 12, 0.6, 14, p.piso)
	b("Degrau", 0, 0.2, -8.9, 12, 0.4, 1.6, p.detalhe)
	b("Degrau", 0, 0.45, -8.2, 9, 0.9, 0.9, p.detalhe, mat, { colide = false })
	-- grade de ferro aberta
	folha(ctx, m, cf, -4, -7.2, -1.2, 4, 8, { 38, 38, 40 }, "Metal")
	folha(ctx, m, cf, 4, -7.2, -pi + 1.2, 4, 8, { 38, 38, 40 }, "Metal")

	ctx.piso(m, cf, "Piso", -6, 6, -7, 7.5, 0.2, 0.2, p.piso, mat)
	local function mobil(nome, x, y, z, rot)
		return Mob.colocar(ctx, m, nome, cf, x, y, z, rot, { rng = rng })
	end
	mobil("caixao", -3.9, 0.2, -1.5, 0)
	mobil("caixao", 3.9, 0.2, -1.5, 0)
	if planta == 1 then
		mobil("caixao", 0, 0.2, 5.6, pi / 2)
	else
		mobil("altar", 0, 0.2, 5.4, 0)
	end
	mobil("candelabro", -5.2, 0.2, 6.2, 0)
	mobil("candelabro", 5.2, 0.2, 6.2, 0)
	mobil("cruz_parede", 0, 6.5, 7.4, 0)
	return m,
		{
			loot = { { x = 0, y = 0.2, z = -3.5 }, { x = 0, y = 0.2, z = 2 } },
			frente = { 0, -13 },
			portaria = { 0, -7 },
		}
end
M.catalogo.cripta = { paletas = PAL_CRIPTA, construir = cripta }

-- ---------------------------------------------------------------------------------------------------------------
-- GUARDA 40×30: posto florestal de madeira (escritório, alojamento, arsenal) + torre de vigia de 30 st
-- ---------------------------------------------------------------------------------------------------------------
local PAL_GUARDA = {
	{
		parede = { 112, 88, 64 },
		telhado = { 52, 40, 34 },
		piso = { 78, 58, 42 },
		detalhe = { 80, 62, 46 },
		torre = { 96, 76, 56 },
	},
	{
		parede = { 98, 94, 86 },
		telhado = { 46, 44, 44 },
		piso = { 70, 56, 44 },
		detalhe = { 70, 66, 60 },
		torre = { 86, 82, 74 },
	},
	{
		parede = { 86, 100, 78 },
		telhado = { 48, 42, 36 },
		piso = { 72, 58, 44 },
		detalhe = { 62, 74, 56 },
		torre = { 78, 90, 70 },
	},
	{
		parede = { 124, 82, 66 },
		telhado = { 50, 38, 36 },
		piso = { 76, 54, 42 },
		detalhe = { 90, 56, 46 },
		torre = { 104, 70, 56 },
	},
	{
		parede = { 138, 124, 98 },
		telhado = { 60, 48, 40 },
		piso = { 82, 64, 46 },
		detalhe = { 102, 88, 66 },
		torre = { 120, 106, 82 },
	},
}

local function guarda(ctx, spec)
	local rng = spec.rng or ctx.rng("guarda")
	local p = spec.paleta or PAL_GUARDA[1]
	local m = ctx.modeloConstrucao(spec, "guarda", "guarda", 40, 30, 41, 1)
	local cf = spec.cf
	local par, WP = p.parede, "WoodPlanks"
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mt, op)
		return ctx.bloco(m, cf, nome, cx, cy, cz, sx, sy, sz, cor, mt or WP, op)
	end
	local function parede(nome, a, c, base, alt, esp, ab)
		return ctx.parede(m, cf, nome, a, c, base, alt, esp, par, WP, ab)
	end
	local function jan(de, larg, extra)
		local j = { de = de, larg = larg, tipo = "janela", cor = p.detalhe }
		for k, v in extra or {} do
			j[k] = v
		end
		return j
	end
	local planta = rng.inteiro(1, 2)
	local H = 11

	-- prédio: x −20..2, z −12..15
	parede("Parede", { -19.5, -11.5 }, { 1.5, -11.5 }, 0, H, 1, {
		jan(4.5, 3.5),
		jan(9.5, 3.5),
		{ de = 17.2, larg = 5.5, tipo = "porta", cor = p.detalhe },
	})
	parede(
		"Parede",
		{ -19.5, 14.5 },
		{ 1.5, 14.5 },
		0,
		H,
		1,
		{ jan(5.5, 3.5), jan(17.5, 1.8, { alt = 2, peitoril = 6, vidro = false }) }
	)
	parede("Parede", { -19.5, -11.5 }, { -19.5, 14.5 }, 0, H, 1, { jan(6.5, 3.5), jan(19.5, 3.5) })
	parede("Parede", { 1.5, -11.5 }, { 1.5, 14.5 }, 0, H, 1, { { de = 21.5, larg = 5, tipo = "vao", alt = 6.2 } })
	parede("Divisoria", { -6, -11 }, { -6, 1 }, 0, H, 0.8, { { de = 6, larg = 5, tipo = "porta", cor = p.detalhe } })
	parede("Divisoria", { -19, 1 }, { 1, 1 }, 0, H, 0.8, {
		{ de = 5.3, larg = 5, tipo = "porta", cor = p.detalhe },
		{ de = 15.7, larg = 5, tipo = "porta", cor = p.detalhe },
	})
	parede("Divisoria", { -8, 1 }, { -8, 14 }, 0, H, 0.8)
	ctx.piso(m, cf, "Piso", -19, 1, -11, 14, 0.2, 0.2, p.piso, WP)
	b("Forro", -9, 10.7, 1.5, 20, 0.6, 25, p.detalhe)
	ctx.telhadoDuasAguas(m, cf, "Telhado", -9, 1.5, 22, 27, H, 5, 0.8, 0.8, p.telhado, "Wood", true)
	oitao(ctx, m, cf, -9, -11.5, 11.8, H, 5, 1, par, WP)
	oitao(ctx, m, cf, -9, 14.5, 11.8, H, 5, 1, par, WP)
	b("Chamine", -14.5, 14, 8, 2.4, 8, 2.4, { 120, 100, 90 }, "Brick")
	-- varanda
	b("Varanda", -2.5, 0.2, -13.4, 13, 0.4, 2.8, p.piso)
	for _, x in { -8.5, 3.5 } do
		b("PostVaranda", x, 4.5, -14.4, 0.8, 9, 0.8, p.detalhe)
	end
	b("TetoVaranda", -2.5, 9.25, -13.2, 14.5, 0.5, 3.4, p.telhado, "Wood")
	placa(ctx, m, cf, -2.3, 10.2, -12.25, 8, 1.4, "Posto da Guarda Florestal", { 40, 56, 40 }, { 220, 220, 205 })
	for i = 0, 5 do
		ctx.cilindro(
			m,
			cf,
			"Lenha",
			-16.5,
			0.6 + (i // 3) * 1.1,
			-14 + (i % 3) * 1.25,
			1.2,
			4,
			{ 96, 70, 46 },
			"Wood",
			{ eixo = "x" }
		)
	end

	-- torre: x 2..20, z −3..15; interior 3..19 × −2..14
	local ix0, ix1, iz0, iz1 = 3, 19, -2, 14
	local faixas = { { 0, 8 }, { 8, 16 }, { 16, 24 }, { 24, 30 } }
	local lados = {
		{ { 2.5, -2.5 }, { 19.5, -2.5 } },
		{ { 2.5, 14.5 }, { 19.5, 14.5 } },
		{ { 2.5, -2.5 }, { 2.5, 14.5 } },
		{ { 19.5, -2.5 }, { 19.5, 14.5 } },
	}
	for li, l in lados do
		for fi, f in faixas do
			local ab = { jan(8.5, 1.8, { peitoril = 2.6, alt = 3.2, vidro = false }) }
			if li == 1 and fi == 1 then
				ab = { { de = 10, larg = 5.5, tipo = "porta", cor = p.detalhe } }
			end
			if li == 3 and fi == 1 then
				ab = { { de = 12.5, larg = 5, tipo = "vao", alt = 6.2 } }
			end
			ctx.parede(m, cf, "Torre", l[1], l[2], f[1], f[2] - f[1], 1, p.torre, WP, ab)
		end
		ctx.parede(m, cf, "Cabine", l[1], l[2], 30, 7.5, 1, p.torre, WP, {
			jan(3.2, 4.2, { peitoril = 2.8, alt = 3.4 }),
			jan(8.5, 4.2, { peitoril = 2.8, alt = 3.4 }),
			jan(13.8, 4.2, { peitoril = 2.8, alt = 3.4 }),
		})
	end
	ctx.piso(m, cf, "PisoTorre", ix0, ix1, iz0, iz1, 0.2, 0.2, p.piso, WP)
	b("Soleira", 2, 0.1, 10, 2.4, 0.2, 5, p.piso, WP)
	-- escada em espiral por dentro: 4 lances de 7,5 (degrau 0,94 × 1,0), patamares nos cantos
	local op = { subida = 1, passada = 1 }
	local c = p.detalhe
	local r1 = ctx.escada(m, cf, "Degrau", 5, iz0, "+z", 0, 7.5, 4, c, WP, op)
	b("Patamar", 5, 7.1, (r1.z1 + iz1) / 2, 4, 0.8, iz1 - r1.z1, c)
	local r2 = ctx.escada(m, cf, "Degrau", 7, 12, "+x", 7.5, 7.5, 4, c, WP, op)
	b("Patamar", (r2.x1 + ix1) / 2, 14.6, 12, ix1 - r2.x1, 0.8, 4, c)
	local r3 = ctx.escada(m, cf, "Degrau", 17, 10, "-z", 15, 7.5, 4, c, WP, op)
	b("Patamar", 17, 22.1, (iz0 + r3.z0) / 2, 4, 0.8, r3.z0 - iz0, c)
	local r4 = ctx.escada(m, cf, "Degrau", 15, 0, "-x", 22.5, 7.5, 4, c, WP, op)
	for _, pl in { { 3.5, 13.5, 7.5 }, { 18.5, 13.5, 15 }, { 18.5, -1.5, 22.5 } } do
		b("PilarPatamar", pl[1], (pl[3] - 0.8) / 2, pl[2], 1, pl[3] - 0.8, 1, p.torre)
	end
	ctx.piso(m, cf, "PisoCabine", ix0, ix1, iz0, iz1, 30, 0.8, p.piso, WP, { r4 })
	-- cobertura, holofote apagado e sino
	b("TetoCabine", 11, 37.9, 6, 19.6, 0.8, 19.6, p.telhado, "Wood")
	b("TetoCabine", 11, 38.8, 6, 13, 1, 13, p.telhado, "Wood")
	b("TetoCabine", 11, 39.6, 6, 7, 0.8, 7, p.telhado, "Wood")
	b("Mastro", 11, 42, 6, 0.4, 5, 0.4, { 50, 50, 52 }, "Metal")
	b("Pedestal", 6, 31.1, 12.2, 2.4, 2.2, 2.4, { 60, 60, 62 }, "Metal")
	ctx.cilindro(m, cf, "Holofote", 6, 33.1, 11.7, 2.6, 2.4, { 40, 42, 44 }, "Metal", { eixo = "z" })
	ctx.cilindro(
		m,
		cf,
		"Lente",
		6,
		33.1,
		10.45,
		2.2,
		0.2,
		{ 20, 22, 24 },
		"Glass",
		{ eixo = "z", transparencia = 0.3, colide = false }
	)
	b("TravessaSino", 14.5, 36.9, 6, 0.8, 0.8, 8, { 70, 50, 38 }, "Wood", { colide = false })
	ctx.cilindro(m, cf, "Sino", 14.5, 35.2, 6, 2.6, 2.6, BRONZE, "Metal", { colide = false })
	ctx.esfera(m, cf, "Badalo", 14.5, 33.7, 6, 0.8, BRONZE, "Metal", { colide = false })
	Mob.colocar(ctx, m, "mesa_mapas", cf, 7, 30.8, 6.5, 0, { rng = rng })
	Mob.colocar(ctx, m, "cadeira_escritorio", cf, 10.5, 30.8, 9, 0, { rng = rng })

	-- mobília
	local function mobil(nome, x, z, rot, op2, y)
		return Mob.colocar(ctx, m, nome, cf, x, y or 0.2, z, rot, op2 or { rng = rng })
	end
	local salaEsc = { x0 = -19, x1 = -6.4, z0 = -11, z1 = 0.6 }
	mobil("escrivaninha", -13.5, -3.5, 0)
	mobil("cadeira_escritorio", -13.5, -0.5, 0)
	mobil("arquivo", -17.6, -8.5, -pi / 2)
	mobil("arquivo", -17.6, -0.8, -pi / 2)
	local x, z, r = Mob.paraParede("estante_livros", "+z", -9, salaEsc)
	mobil("estante_livros", x, z, r)
	mobil("caixa_papelao", -9.5, -9.5, 0)
	mobil("cabideiro", 0.4, -8.6, 0)
	mobil("cesto_lixo", -4.8, -9.8, 0)
	local salaAloj = { x0 = -19, x1 = -8.4, z0 = 1.4, z1 = 14 }
	local xb = if planta == 1 then -17.2 else -10.2
	mobil("beliche", xb, 7.5, 0)
	mobil("cama_solteiro", if planta == 1 then -10.4 else -17.4, 10.5, 0)
	x, z, r = Mob.paraParede("guarda_roupa", "+z", -14, salaAloj)
	mobil("guarda_roupa", x, z, r)
	mobil("criado_mudo", -14, 12.9, 0)
	local salaArs = { x0 = -7.6, x1 = 1, z0 = 1.4, z1 = 14 }
	x, z, r = Mob.paraParede("estante_armas", "+z", -3.3, salaArs)
	mobil("estante_armas", x, z, r)
	x, z, r = Mob.paraParede("armario_armas", "-x", 8, salaArs)
	mobil("armario_armas", x, z, r)
	mobil("caixa_municao", 0, 3.2, math.pi / 2)
	mobil("caixa_municao", 0, 5.6, math.pi / 2)
	mobil("caixa_municao", -6.2, 3.2, math.pi / 2)

	return m,
		{
			loot = {
				{ x = -10, y = 0.2, z = -6 },
				{ x = -12.5, y = 0.2, z = 5 },
				{ x = -3.3, y = 0.2, z = 7 },
				{ x = -3.3, y = 0.2, z = 10.5 },
				{ x = 14, y = 30, z = 9 },
			},
			frente = { -2.3, -19 },
			portaria = { -2.3, -11.5 },
		}
end
M.catalogo.guarda = { paletas = PAL_GUARDA, construir = guarda }

-- ---------------------------------------------------------------------------------------------------------------
-- ÁREAS
-- ---------------------------------------------------------------------------------------------------------------
local FERRO = { 34, 34, 36 }
local W0 = CFrame.new()

local function modeloEm(ctx, nome)
	local mo = Instance.new("Model")
	mo.Name = nome
	mo.Parent = ctx.pastas.Props
	return mo
end

local function girar(lx, lz, rot)
	return lx * cos(rot) + lz * sin(rot), -lx * sin(rot) + lz * cos(rot)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Cemitério Maple Rise (160×160; a estrada chega pelo leste, portão em x máximo)
-- ---------------------------------------------------------------------------------------------------------------
local function arvoreSeca(ctx, pai, rng, x, z)
	local T = ctx.NIVEL_PAD
	local h = rng.entre(9, 13)
	local cf = CFrame.new(x, T, z)
	ctx.cilindro(ctx.pastas.Vegetacao, cf, "Tronco", 0, h / 2, 0, rng.entre(1.4, 1.9), h, { 58, 48, 40 }, "Wood")
	for i = 1, 6 do
		local ry = rng.entre(0, 2 * pi)
		local rz = rng.entre(0.5, 1.1)
		local yb = h * rng.entre(0.55, 0.95)
		local L = rng.entre(3.5, 6)
		local dx, dy, dz = cos(rz) * cos(ry), sin(rz), -cos(rz) * sin(ry)
		ctx.bloco(
			ctx.pastas.Vegetacao,
			cf,
			"Galho",
			dx * L / 2,
			yb + dy * L / 2,
			dz * L / 2,
			L,
			0.5,
			0.5,
			{ 52, 44, 38 },
			"Wood",
			{
				rot = CFrame.Angles(0, ry, 0) * CFrame.Angles(0, 0, rz),
				colide = false,
				consulta = false,
				sombra = false,
			}
		)
	end
end

function M.areas.cemiterio(ctx, ret)
	local rng = ctx.rng("cemiterio")
	local T = ctx.NIVEL_PAD
	local cx, cz = (ret.x0 + ret.x1) / 2, (ret.z0 + ret.z1) / 2
	local raiz = modeloEm(ctx, "Cemiterio")
	local fx0, fx1, fz0, fz1 = ret.x0 + 6, ret.x1 - 6, ret.z0 + 6, ret.z1 - 6
	local MEIO_PORTAO = 7.5
	local PEDRA = { 118, 116, 110 }

	-- cerca de ferro: trilhos que colidem + grades decorativas
	local function cerca(x0, z0, x1, z1)
		local horiz = z0 == z1
		local comp = if horiz then abs(x1 - x0) else abs(z1 - z0)
		local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
		local function ao(t) -- t em [0, comp] a partir de (x0,z0)
			if horiz then
				return x0 + (if x1 > x0 then t else -t), z0
			end
			return x0, z0 + (if z1 > z0 then t else -t)
		end
		for _, y in { 1, 3, 5, 7 } do
			if horiz then
				ctx.bloco(
					raiz,
					W0,
					"Trilho",
					mx,
					T + y,
					mz,
					comp,
					0.35,
					0.35,
					FERRO,
					"Metal",
					{ consulta = false, sombra = false }
				)
			else
				ctx.bloco(
					raiz,
					W0,
					"Trilho",
					mx,
					T + y,
					mz,
					0.35,
					0.35,
					comp,
					FERRO,
					"Metal",
					{ consulta = false, sombra = false }
				)
			end
		end
		for i = 0, ceil(comp / 8) do
			local px, pz = ao(min(comp, i * 8))
			ctx.bloco(raiz, W0, "Poste", px, T + 4.4, pz, 1, 8.8, 1, FERRO, "Metal", { consulta = false })
			ctx.bloco(
				raiz,
				W0,
				"Ponta",
				px,
				T + 9.1,
				pz,
				1.4,
				0.6,
				1.4,
				{ 60, 60, 62 },
				"Metal",
				{ colide = false, consulta = false, sombra = false }
			)
		end
		for t = 2, comp - 1, 2 do
			local px, pz = ao(t)
			ctx.bloco(
				raiz,
				W0,
				"Grade",
				px,
				T + 4.3,
				pz,
				0.3,
				8.6,
				0.3,
				FERRO,
				"Metal",
				{ colide = false, consulta = false, sombra = false }
			)
		end
		local ex0, ex1 = min(x0, x1), max(x0, x1)
		local ez0, ez1 = min(z0, z1), max(z0, z1)
		ctx.inserirObstaculo(ex0 - 0.6, ex1 + 0.6, ez0 - 0.6, ez1 + 0.6)
	end
	cerca(fx0, fz0, fx1, fz0)
	cerca(fx0, fz1, fx1, fz1)
	cerca(fx0, fz0, fx0, fz1)
	cerca(fx1, fz0, fx1, cz - MEIO_PORTAO)
	cerca(fx1, cz + MEIO_PORTAO, fx1, fz1)

	-- portão (quadro local: frente −Z = +X do mundo, para a estrada)
	local cfG = CFrame.new(fx1, T, cz) * CFrame.Angles(0, -pi / 2, 0)
	local function g(nome, cx2, cy, cz2, sx, sy, sz, cor, mat, op)
		return ctx.bloco(raiz, cfG, nome, cx2, cy, cz2, sx, sy, sz, cor, mat, op)
	end
	for _, s in { -1, 1 } do
		g("PilarPortao", s * 8.3, 5.5, 0, 2, 11, 2, PEDRA, "Granite")
		g("CapaPilar", s * 8.3, 11.4, 0, 2.6, 0.8, 2.6, { 90, 90, 88 }, "Granite")
		local hx = s * 7.2
		local ang = if s < 0 then -1.2 else -pi + 1.2
		local dx, dz = cos(ang), sin(ang)
		for k = 0, 3 do
			local px, pz = hx + dx * (0.3 + k * 1.9), dz * (0.3 + k * 1.9)
			g("GradePortao", px, 4.4, pz, 0.35, 8.4, 0.35, FERRO, "Metal", { colide = false, consulta = false })
		end
		g(
			"QuadroPortao",
			hx + dx * 3.2,
			7.6,
			dz * 3.2,
			6.6,
			0.35,
			0.35,
			FERRO,
			"Metal",
			{ colide = false, consulta = false, rotY = atan2(-dz, dx) }
		)
		g(
			"QuadroPortao",
			hx + dx * 3.2,
			1.2,
			dz * 3.2,
			6.6,
			0.35,
			0.35,
			FERRO,
			"Metal",
			{ colide = false, consulta = false, rotY = atan2(-dz, dx) }
		)
	end
	g("ArcoPortao", 0, 11.2, 0, 17, 0.6, 0.6, FERRO, "Metal", { consulta = false })
	g("PendurePlaca", -6, 11.8, -0.1, 0.2, 1.6, 0.2, FERRO, "Metal", { colide = false, consulta = false })
	g("PendurePlaca", 6, 11.8, -0.1, 0.2, 1.6, 0.2, FERRO, "Metal", { colide = false, consulta = false })
	placa(ctx, raiz, cfG, 0, 13, -0.1, 13, 2.2, "Cemitério Maple Rise", { 20, 20, 22 }, { 200, 200, 195 })
	ctx.inserirObstaculo(fx1 - 3.5, fx1 + 3.5, cz - 10, cz - 6.5)
	ctx.inserirObstaculo(fx1 - 3.5, fx1 + 3.5, cz + 6.5, cz + 10)

	-- alamedas de pedra (retângulos sem sobreposição)
	local alamedas = {
		{ fx0 + 31, ret.x1, cz - 4, cz + 4 },
		{ cx - 3, cx + 3, fz0 + 2, cz - 4 },
		{ cx - 3, cx + 3, cz + 4, fz1 - 2 },
		{ fx0 + 4, cx - 3, cz - 52, cz - 44 },
		{ cx + 3, fx1 - 4, cz - 52, cz - 44 },
		{ fx0 + 4, cx - 3, cz + 44, cz + 52 },
		{ cx + 3, fx1 - 4, cz + 44, cz + 52 },
	}
	for i, a in alamedas do
		ctx.laje("Chao", "Alameda", a[1], a[2], a[3], a[4], T + 0.2, 0.2, PEDRA, "Cobblestone")
		alamedas[i] = { a[1], a[2], a[3], a[4] }
	end

	-- capela ao fundo (porta para o leste) e mausoléus voltados para as alamedas menores
	local ocupados = {}
	local function construir(variante, x, z, rotY, w, d)
		local spec = {
			cf = CFrame.new(x, T, z) * CFrame.Angles(0, rotY, 0),
			zona = "floresta",
			local_ = ret.nome,
			andares = 1,
			rng = ctx.rng("cem_" .. variante .. math.floor(x) .. math.floor(z)),
		}
		local modelo, info = Cat.construir(ctx, variante, spec)
		modelo.Parent = raiz
		ctx.registrarConstrucao(spec, modelo, info)
		local x0, x1, z0, z1 = ctx.caixaMundo(spec.cf, w, d)
		table.insert(ocupados, { x0 - 5, x1 + 5, z0 - 5, z1 + 5 })
	end
	construir("capela", fx0 + 3 + 14, cz, -pi / 2, 20, 28)
	construir("cripta", cx - 50, fz0 + 13, pi, 16, 18)
	construir("cripta", cx + 45, fz0 + 13, pi, 16, 18)
	construir("cripta", cx - 45, fz1 - 13, 0, 16, 18)
	construir("cripta", cx + 50, fz1 - 13, 0, 16, 18)

	-- lápides em fileiras irregulares
	local function livre(x, z)
		local x0, x1, z0, z1 = x - 1.8, x + 1.8, z - 1, z + 7.6
		if x0 < fx0 + 5 or x1 > fx1 - 5 or z0 < fz0 + 5 or z1 > fz1 - 4 then
			return false
		end
		for _, a in alamedas do
			if x1 > a[1] - 3 and x0 < a[2] + 3 and z1 > a[3] - 3 and z0 < a[4] + 3 then
				return false
			end
		end
		for _, o in ocupados do
			if x1 > o[1] and x0 < o[2] and z1 > o[3] and z0 < o[4] then
				return false
			end
		end
		return not (x1 > fx1 - 24 and z1 > cz - 16 and z0 < cz + 16)
	end
	local function gerarCandidatos(escala)
		local lista = {}
		local z = fz0 + 10
		while z < fz1 - 8 do
			local dens = min(1, rng.entre(0.25, 0.9) * escala)
			local x = fx0 + 8 + rng.entre(0, 3)
			while x < fx1 - 8 do
				local px, pz = x + rng.entre(-0.7, 0.7), z + rng.entre(-1, 1)
				if livre(px, pz) then
					table.insert(lista, { px, pz, rng.rnd() < dens })
				end
				x += 5.4
			end
			z += 9
		end
		return lista
	end
	local cand = gerarCandidatos(1)
	local sel, libres = {}, {}
	for _, c in cand do
		table.insert(if c[3] then sel else libres, c)
	end
	while #sel > 112 do
		table.insert(libres, table.remove(sel, rng.inteiro(1, #sel)))
	end
	while #sel < 70 and #libres > 0 do
		table.insert(sel, table.remove(libres, rng.inteiro(1, #libres)))
	end
	for _, c in sel do
		local rot = rng.entre(-0.15, 0.15)
		local x, z = c[1], c[2]
		if rng.chance(0.18) then
			Props.colocar(ctx, raiz, "cruz_cemiterio", x, z, rot, { rng = rng })
		else
			Props.colocar(ctx, raiz, "lapide", x, z, rot, { variante = rng.inteiro(1, 5), rng = rng })
		end
		ctx.bloco(
			raiz,
			W0,
			"Cova",
			x + 3.6 * sin(rot),
			T + 0.17,
			z + 3.6 * cos(rot),
			2.4,
			0.34,
			6,
			{ 52, 40, 30 },
			"Ground",
			{
				rotY = rot,
				colide = false,
				consulta = false,
				sombra = false,
			}
		)
		ctx.inserirObstaculo(x - 1.5, x + 1.5, z - 0.8, z + 7)
	end

	-- covas abertas
	local abertas = {}
	for _ = 1, 3 do
		if #libres == 0 then
			break
		end
		local c = table.remove(libres, rng.inteiro(1, #libres))
		local x, z = c[1], c[2]
		table.insert(abertas, c)
		Props.colocar(ctx, raiz, "lapide", x, z, 0, { variante = rng.inteiro(1, 5), rng = rng })
		ctx.bloco(
			raiz,
			W0,
			"CovaAberta",
			x,
			T + 0.06,
			z + 3.6,
			3,
			0.12,
			6.4,
			{ 18, 14, 12 },
			"Mud",
			{ colide = false, consulta = false }
		)
		ctx.bloco(raiz, W0, "Terra", x + 3.4, T + 0.5, z + 3.6, 3.4, 1, 6.6, { 66, 50, 38 }, "Ground")
		ctx.bloco(
			raiz,
			W0,
			"Tabua",
			x,
			T + 0.2,
			z + 2,
			0.9,
			0.2,
			4.4,
			{ 80, 62, 46 },
			"WoodPlanks",
			{ rotY = 1.5708, colide = false, consulta = false }
		)
		ctx.inserirObstaculo(x - 1.8, x + 5.5, z - 0.8, z + 7.2)
		ctx.loot(x - 3.2, T, z + 3.6, "casa", "floresta")
	end
	if abertas[1] then
		Mob.colocar(ctx, raiz, "caixao", W0, abertas[1][1] - 5, T, abertas[1][2] + 3, 0.2, { rng = rng })
	end

	-- árvores secas, longe das lápides
	local arvores = {}
	for _ = 1, 40 do
		if #arvores >= 14 or #libres == 0 then
			break
		end
		local c = libres[rng.inteiro(1, #libres)]
		local ok = true
		for _, a in arvores do
			if (a[1] - c[1]) ^ 2 + (a[2] - c[2]) ^ 2 < 144 then
				ok = false
			end
		end
		for _, s in sel do
			if (s[1] - c[1]) ^ 2 + (s[2] - c[2]) ^ 2 < 36 then
				ok = false
			end
		end
		if ok then
			table.insert(arvores, c)
			arvoreSeca(ctx, raiz, rng, c[1], c[2])
			ctx.inserirObstaculo(c[1] - 1.2, c[1] + 1.2, c[2] - 1.2, c[2] + 1.2)
		end
	end

	-- loot de área: portão, alamedas, capela, árvore
	ctx.loot(fx1 - 8, T, cz + 10, "casa", "floresta")
	ctx.loot(cx + 8, T, cz - 8, "casa", "floresta")
	ctx.loot(cx - 8, T, cz + 8, "casa", "floresta")
	ctx.loot(fx0 + 36, T, cz + 9, "casa", "floresta")
	if arvores[1] then
		ctx.loot(arvores[1][1] + 2.5, T, arvores[1][2], "casa", "floresta")
	end
	ctx.inserirObstaculo(ret.x0, ret.x1, ret.z0, ret.z1)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Acampamento Halvorsen (200×200; estrada pelo leste, portão em x máximo)
-- ---------------------------------------------------------------------------------------------------------------
local function torreVigia(ctx, pai, x, z, rotY)
	local T = ctx.NIVEL_PAD
	local cf = CFrame.new(x, T, z) * CFrame.Angles(0, rotY, 0)
	local MAD, MAD2 = { 70, 54, 40 }, { 86, 68, 50 }
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
		return ctx.bloco(pai, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat or "Wood", op)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			b("Perna", sx * 3.7, 7, sz * 3.7, 0.9, 14, 0.9, MAD)
			b("Poste", sx * 4.4, 17.9, sz * 4.4, 0.5, 7.8, 0.5, MAD)
		end
	end
	local ang = math.atan(12 / 7.4)
	local L = sqrt(7.4 ^ 2 + 12 ^ 2)
	b("Travessa", 0, 7, 3.9, L, 0.3, 0.3, MAD2, "WoodPlanks", { rot = CFrame.Angles(0, 0, ang), consulta = false })
	b("Travessa", 0, 7, -3.9, L, 0.3, 0.3, MAD2, "WoodPlanks", { rot = CFrame.Angles(0, 0, -ang), consulta = false })
	b("Travessa", 3.9, 7, 0, 0.3, 0.3, L, MAD2, "WoodPlanks", { rot = CFrame.Angles(ang, 0, 0), consulta = false })
	b("Travessa", -3.9, 7, 0, 0.3, 0.3, L, MAD2, "WoodPlanks", { rot = CFrame.Angles(-ang, 0, 0), consulta = false })
	b("Plataforma", 0, 13.7, 0, 9.6, 0.6, 9.6, MAD2, "WoodPlanks")
	for _, y in { 15.6, 17.4 } do
		b("Guarda", 0, y, 4.5, 9.4, 0.3, 0.3, MAD2, "WoodPlanks", { consulta = false })
		b("Guarda", 4.5, y, 0, 0.3, 0.3, 9.4, MAD2, "WoodPlanks", { consulta = false })
		b("Guarda", -4.5, y, 0, 0.3, 0.3, 9.4, MAD2, "WoodPlanks", { consulta = false })
		b("Guarda", -3.3, y, -4.5, 2.8, 0.3, 0.3, MAD2, "WoodPlanks", { consulta = false })
		b("Guarda", 3.3, y, -4.5, 2.8, 0.3, 0.3, MAD2, "WoodPlanks", { consulta = false })
	end
	ctx.telhadoDuasAguas(pai, cf, "Telhado", 0, 0, 9.6, 9.6, 21.7, 2.4, 0.8, 0.4, { 74, 66, 58 }, "CorrodedMetal", true)
	local comp = ctx.comprimentoEscada(14, { passada = 0.75 })
	ctx.escada(pai, cf, "Degrau", 0, -4.8 - comp, "+z", 0, 14, 3.6, MAD2, "WoodPlanks", { subida = 1, passada = 0.75 })
	-- holofote apagado
	b("BaseHolofote", 2.6, 14.7, 2.6, 1.6, 1.4, 1.6, { 60, 60, 62 }, "Metal")
	ctx.cilindro(pai, cf, "Holofote", 2.6, 16, 2.6, 2, 2, { 40, 42, 44 }, "Metal", { eixo = "z" })
	ctx.cilindro(
		pai,
		cf,
		"Lente",
		2.6,
		16,
		1.5,
		1.7,
		0.2,
		{ 20, 22, 24 },
		"Glass",
		{ eixo = "z", colide = false, transparencia = 0.3 }
	)
	local w0x, w0z = girar(0, 0, rotY)
	ctx.inserirObstaculo(x - 5 + w0x, x + 5 + w0x, z - 5 + w0z, z + 5 + w0z)
	ctx.loot(x, T + 14, z, "guarda", "floresta")
end

local function containerEscritorio(ctx, pai, x, z, rotY, rng)
	local T = ctx.NIVEL_PAD
	local cf = CFrame.new(x, T, z) * CFrame.Angles(0, rotY, 0)
	local COR = { 74, 92, 90 }
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
		return ctx.bloco(pai, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end
	ctx.parede(pai, cf, "Container", { -9.6, -3.6 }, { 9.6, -3.6 }, 0, 8.4, 0.8, COR, "CorrodedMetal", {
		{ de = 4, larg = 5, tipo = "porta", cor = { 50, 60, 58 } },
		{ de = 13, larg = 3.6, tipo = "janela", cor = { 50, 60, 58 } },
	})
	ctx.parede(pai, cf, "Container", { -9.6, 3.6 }, { 9.6, 3.6 }, 0, 8.4, 0.8, COR, "CorrodedMetal", {
		{ de = 10, larg = 3.6, tipo = "janela", cor = { 50, 60, 58 } },
	})
	for _, s in { -1, 1 } do
		ctx.parede(pai, cf, "Container", { s * 9.6, -3.6 }, { s * 9.6, 3.6 }, 0, 8.4, 0.8, COR, "CorrodedMetal")
	end
	b("Teto", 0, 8.7, 0, 20.2, 0.6, 8.6, { 64, 76, 74 }, "CorrodedMetal")
	ctx.piso(pai, cf, "Piso", -9.2, 9.2, -3.2, 3.2, 0.3, 0.3, { 70, 56, 44 }, "WoodPlanks")
	for i = -3, 3 do
		b(
			"Nervura",
			i * 2.9,
			4.2,
			-4.05,
			0.3,
			8,
			0.2,
			{ 60, 76, 74 },
			"CorrodedMetal",
			{ colide = false, consulta = false, sombra = false }
		)
	end
	local function mobil(nome, mx, my, mz, rot)
		return Mob.colocar(ctx, pai, nome, cf, mx, my, mz, rot, { rng = rng })
	end
	mobil("mesa_escritorio", 4, 0.3, 0, 0)
	mobil("computador", 4, 3, 0.2, 0)
	mobil("cadeira_escritorio", 4, 0.3, 2.3, 0)
	mobil("arquivo", -8, 0.3, 2.3, pi)
	mobil("arquivo", -5.6, 0.3, 2.3, pi)
	mobil("quadro_branco", -1, 4.8, 3.2, 0)
	mobil("lampiao", -8, 0.3, -1.5, 0)
	local x0, x1, z0, z1 = ctx.caixaMundo(cf, 20, 8)
	ctx.inserirObstaculo(x0, x1, z0, z1)
	local wx, wz = girar(-1, 0, rotY)
	ctx.loot(x - wx * 2, T + 0.3, z - wz * 2, "guarda", "floresta")
end

-- cobertura de lona sobre postes: devolve nada; (x,z) centro, w×d, h altura dos postes, eixo X como cumeeira
local function lona(ctx, pai, x, z, w, d, h, cor, rotY)
	local T = ctx.NIVEL_PAD
	local cf = CFrame.new(x, T, z) * CFrame.Angles(0, rotY or 0, 0)
	local nx = max(2, ceil(w / 12) + 1)
	for i = 0, nx - 1 do
		local px = -w / 2 + 0.5 + i * (w - 1) / (nx - 1)
		for _, sz in { -1, 1 } do
			ctx.bloco(pai, cf, "PosteLona", px, h / 2, sz * (d / 2 - 0.5), 0.6, h, 0.6, { 70, 54, 40 }, "Wood")
		end
	end
	ctx.telhadoDuasAguas(pai, cf, "Lona", 0, 0, w, d, h, 2.8, 0.6, 0.3, cor, "Fabric", false)
	return cf
end

function M.areas.acampamento(ctx, ret)
	local rng = ctx.rng("acampamento")
	local T = ctx.NIVEL_PAD
	local cx, cz = (ret.x0 + ret.x1) / 2, (ret.z0 + ret.z1) / 2
	local raiz = modeloEm(ctx, "Acampamento")
	local OLIVA = { 76, 84, 62 }
	local function obs(x, z, w, d, rot)
		local x0, x1, z0, z1 = ctx.caixaMundo(CFrame.new(x, 0, z) * CFrame.Angles(0, rot or 0, 0), w, d)
		ctx.inserirObstaculo(x0, x1, z0, z1)
	end
	local function mobil(nome, x, z, rot, op, y)
		return Mob.colocar(ctx, raiz, nome, W0, x, y or T, z, rot, op or { rng = rng })
	end

	-- cerca de arame com portão a leste
	local H = 90
	local function linha(x0, z0, x1, z1)
		local comp = abs(x1 - x0) + abs(z1 - z0)
		local n = ceil(comp / 24)
		local rot = if z0 == z1 then 0 else pi / 2
		for i = 1, n do
			local t = (i - 0.5) / n
			local px, pz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			Props.colocar(ctx, raiz, "cerca_arame", px, pz, rot, { w = comp / n, rng = rng, obstaculo = false })
		end
		obs((x0 + x1) / 2, (z0 + z1) / 2, abs(x1 - x0) + 1, abs(z1 - z0) + 1)
	end
	linha(cx - H, cz - H, cx + H, cz - H)
	linha(cx - H, cz + H, cx + H, cz + H)
	linha(cx - H, cz - H, cx - H, cz + H)
	linha(cx + H, cz - H, cx + H, cz - 8)
	linha(cx + H, cz + 8, cx + H, cz + H)
	-- portão aberto, pilares e placa
	local cfG = CFrame.new(cx + H, T, cz) * CFrame.Angles(0, -pi / 2, 0)
	for _, s in { -1, 1 } do
		ctx.bloco(raiz, cfG, "PilarPortao", s * 8.4, 5, 0, 1.2, 10, 1.2, { 70, 54, 40 }, "Wood")
		ctx.bloco(
			raiz,
			cfG,
			"PortaoAberto",
			s * 8.4,
			2.6,
			3.2,
			0.3,
			5,
			6.4,
			{ 90, 90, 88 },
			"Metal",
			{ colide = false, consulta = false, transparencia = 0.3 }
		)
	end
	ctx.bloco(raiz, cfG, "Travessa", 0, 10.2, 0, 17.6, 0.5, 0.5, { 70, 54, 40 }, "Wood", { consulta = false })
	placa(
		ctx,
		raiz,
		cfG,
		0,
		12,
		0,
		12,
		2.4,
		"Acampamento Halvorsen\nAbrigo de sobreviventes",
		{ 30, 38, 28 },
		{ 225, 225, 210 }
	)
	obs(cx + H, cz - 9.2, 3, 3)
	obs(cx + H, cz + 9.2, 3, 3)

	-- caminhos de terra
	ctx.laje("Chao", "Praca", cx - 18, cx + 18, cz - 18, cz + 18, T + 0.12, 0.12, { 70, 56, 44 }, "Ground")
	ctx.laje("Chao", "Caminho", cx + 18, cx + H + 2, cz - 4, cz + 4, T + 0.12, 0.12, { 76, 62, 48 }, "Ground")

	-- torres de vigia ladeando o portão (escada voltada para dentro)
	torreVigia(ctx, raiz, cx + 84, cz - 34, pi / 2)
	torreVigia(ctx, raiz, cx + 84, cz + 34, pi / 2)

	-- barricadas de saco de areia: chicana na entrada e abrigos nos cantos
	local function barricada(x, z, rot, n, cor)
		for i = 0, n - 1 do
			local ox, oz = girar((i - (n - 1) / 2) * 4.9, 0, rot)
			mobil("saco_areia", x + ox, z + oz, rot, { rng = rng, cor = cor })
		end
		obs(x, z, if rot == 0 then n * 5 else 2, if rot == 0 then 2 else n * 5, 0)
	end
	barricada(cx + 76, cz - 14, pi / 2, 3)
	barricada(cx + 62, cz + 14, pi / 2, 3)
	for _, c in { { -80, -80 }, { -80, 80 }, { 80, -80 } } do
		barricada(cx + c[1] * 0.9, cz + c[2] * 0.9 + (if c[2] < 0 then 6 else -6), 0, 3)
	end
	barricada(cx + 80 * 0.9, cz + 80 * 0.9 - 6, 0, 3)

	-- fogueira central com toras de assento
	mobil("fogueira", cx, cz, 0)
	for k = 0, 3 do
		local a = k * pi / 2 + 0.4
		ctx.cilindro(
			raiz,
			W0,
			"Tora",
			cx + cos(a) * 6.5,
			T + 0.6,
			cz + sin(a) * 6.5,
			1.2,
			4.4,
			{ 82, 62, 44 },
			"Wood",
			{ eixo = if k % 2 == 0 then "z" else "x" }
		)
	end
	obs(cx, cz, 5, 5)
	mobil("lampiao", cx + 3, cz + 3, 0)

	-- barracas em duas fileiras, camas de campanha dentro
	local cores = { OLIVA, { 110, 98, 72 }, { 84, 90, 76 } }
	local tendas = 0
	for _, fila in { { dz = -68, rot = pi }, { dz = 68, rot = 0 } } do
		for i, dx in { -70, -55, -40, -25 } do
			local x, z = cx + dx, cz + fila.dz
			tendas += 1
			mobil("barraca", x, z, fila.rot, { rng = rng, cor = cores[(i + tendas) % 3 + 1] })
			for _, lx in { -2.9, 2.9 } do
				local ox, oz = girar(lx, 0.5, fila.rot)
				mobil("cama_campanha", x + ox, z + oz, fila.rot, { rng = rng })
			end
			local lx, lz = girar(5.2, -5.6, fila.rot)
			mobil("lampiao", x + lx, z + lz, 0)
			obs(x, z, 9, 10, 0)
			if tendas == 2 or tendas == 7 then
				local lx, lz = girar(0, -8, fila.rot)
				ctx.loot(x + lx, T, z + lz, "guarda", "floresta")
			end
		end
	end

	-- refeitório de lona
	local rx, rz = cx + 30, cz - 40
	lona(ctx, raiz, rx, rz, 24, 14, 8, { 92, 98, 78 })
	for _, p in { { -6, -3.2 }, { 6, -3.2 }, { -6, 3.2 }, { 6, 3.2 } } do
		mobil("mesa_dobravel", rx + p[1], rz + p[2], 0)
	end
	for _, p in
		{ { -8, -5.4 }, { -4, -5.4 }, { 4, -5.4 }, { 8, -5.4 }, { -8, 5.4 }, { -4, 5.4 }, { 4, 5.4 }, { 8, 5.4 } }
	do
		mobil("cadeira", rx + p[1], rz + p[2], if p[2] < 0 then pi else 0)
	end
	mobil("barril", rx + 10.5, rz, 0)
	obs(rx, rz, 25, 15)
	ctx.loot(rx, T, rz, "casa", "floresta")

	-- container-escritório
	containerEscritorio(ctx, raiz, cx + 30, cz + 40, 0, rng)

	-- tenda de comando com mesa de mapas
	local mx, mz = cx - 10, cz - 45
	lona(ctx, raiz, mx, mz, 12, 10, 7, OLIVA)
	mobil("mesa_mapas", mx, mz, 0)
	mobil("lampiao", mx + 1.5, mz + 0.5, 0, nil, T + 2.9)
	mobil("cadeira", mx - 4, mz + 3, 0)
	obs(mx, mz, 13, 11)
	ctx.loot(mx + 3.5, T, mz + 2.5, "guarda", "floresta")

	-- arsenal: abrigo aberto com estantes de armas e munição
	local ax, az = cx - 40, cz + 5
	local cfA = CFrame.new(ax, T, az)
	ctx.bloco(raiz, cfA, "ParedeFundo", 0, 3.5, 3.6, 14, 7, 0.6, { 78, 62, 46 }, "WoodPlanks")
	for _, s in { -1, 1 } do
		ctx.bloco(raiz, cfA, "ParedeLado", s * 6.8, 3.5, 0.6, 0.6, 7, 6, { 78, 62, 46 }, "WoodPlanks")
		ctx.bloco(raiz, cfA, "PosteFrente", s * 6.8, 3.9, -4.2, 0.6, 7.8, 0.6, { 70, 54, 40 }, "Wood")
	end
	ctx.rampa(raiz, cfA, "Lona", 0, 7.8, 3.9, 0, 6.6, -4.8, 15, 0.3, { 84, 90, 70 }, "Fabric")
	mobil("estante_armas", ax - 3.5, az + 2.9, 0)
	mobil("estante_armas", ax + 3.5, az + 2.9, 0)
	for k = 0, 3 do
		mobil("caixa_municao", ax - 5 + k * 2.6, az - 1.5, 0)
	end
	mobil("barril", ax + 5.8, az - 1.5, 0)
	obs(ax, az, 15, 9)
	ctx.loot(ax - 2, T, az - 3, "guarda", "floresta")
	ctx.loot(ax + 2.5, T, az - 3.2, "guarda", "floresta")

	-- gerador, barris e cabo
	mobil("gerador", cx - 10, cz + 48, 0)
	for k = 0, 2 do
		mobil("barril", cx - 15 + k * 2.4, cz + 52, 0)
	end
	ctx.bloco(raiz, W0, "Cabo", cx - 10, T + 0.15, cz + 25, 0.3, 0.2, 44, { 20, 20, 20 }, "Plastic", NC)
	obs(cx - 10, cz + 50, 12, 8)

	-- depósito de containers junto à cerca oeste
	local cores2 = { { 90, 50, 40 }, { 50, 70, 90 }, { 80, 84, 60 } }
	for i, dz in { -32, -10, 12 } do
		Props.colocar(ctx, raiz, "container_carga", cx - 77, cz + dz, pi / 2, { cor = cores2[i], rng = rng })
		obs(cx - 77, cz + dz, 8, 20)
	end
	ctx.inserirObstaculo(ret.x0, ret.x1, ret.z0, ret.z1)
end

return M
