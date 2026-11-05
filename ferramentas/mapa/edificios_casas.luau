-- Edifícios residenciais (agente E1): casa_pequena, casa_media, casa_grande, sobrado, cabana. Contrato: docs/mapa-v2.md §5.
-- Todas as plantas são escritas em coordenadas locais "desespelhadas"; B.px espelha em X por rng (2 plantas por variante).
-- Móveis só via Mob (mobilia.luau). Pé-direito 12, laje de 1 (livre 11), degraus de 1 st.

local roblox = require("@lune/roblox")
local CFrame, Instance = roblox.CFrame, roblox.Instance
local UDim2 = roblox.UDim2
local Enum = roblox.Enum

local Mob = require("./mobilia")
local Props = require("./props")

local PI = math.pi
local M = { catalogo = {} }

-- ------------------------------------------------------------------------------------------------------------------
-- Paletas
-- ------------------------------------------------------------------------------------------------------------------
local function pal(parede, interna, telhado, porta, moldura, piso, base, tijolo, extra)
	local p = {
		parede = parede,
		interna = interna,
		telhado = telhado,
		porta = porta,
		moldura = moldura,
		coluna = moldura,
		piso = piso,
		base = base,
		tijolo = tijolo,
		metal = { 90, 92, 95 },
		forro = { 108, 106, 98 },
		ladrilho = { 150, 152, 148 },
	}
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end

local PAL_CASA = {
	pal(
		{ 96, 110, 98 },
		{ 104, 116, 104 },
		{ 60, 45, 42 },
		{ 95, 60, 45 },
		{ 190, 190, 184 },
		{ 70, 48, 36 },
		{ 66, 72, 66 },
		{ 118, 84, 70 }
	),
	pal(
		{ 150, 138, 115 },
		{ 138, 126, 104 },
		{ 72, 50, 44 },
		{ 64, 80, 76 },
		{ 172, 168, 152 },
		{ 78, 54, 40 },
		{ 96, 88, 72 },
		{ 120, 86, 70 }
	),
	pal(
		{ 120, 122, 118 },
		{ 112, 114, 110 },
		{ 44, 48, 54 },
		{ 112, 72, 44 },
		{ 200, 198, 190 },
		{ 62, 46, 38 },
		{ 80, 82, 80 },
		{ 110, 90, 80 }
	),
	pal(
		{ 92, 104, 120 },
		{ 100, 110, 122 },
		{ 62, 46, 46 },
		{ 150, 140, 118 },
		{ 185, 186, 184 },
		{ 74, 52, 40 },
		{ 60, 68, 80 },
		{ 120, 88, 74 }
	),
	pal(
		{ 128, 100, 90 },
		{ 122, 106, 96 },
		{ 50, 44, 46 },
		{ 70, 70, 66 },
		{ 186, 180, 168 },
		{ 66, 46, 36 },
		{ 84, 66, 60 },
		{ 110, 82, 70 },
		{ mat = "Brick" }
	),
}

local function palCabana(parede, telhado, porta)
	return pal(
		parede,
		{ parede[1] * 0.92, parede[2] * 0.92, parede[3] * 0.92 },
		telhado,
		porta,
		{ 150, 130, 100 },
		{ 80, 58, 42 },
		{ 110, 108, 104 },
		{ 120, 118, 112 },
		{
			mat = "Wood",
			coluna = { parede[1] * 0.8, parede[2] * 0.8, parede[3] * 0.8 },
			matTelhado = "WoodPlanks",
		}
	)
end
local PAL_CABANA = {
	palCabana({ 110, 80, 58 }, { 52, 44, 40 }, { 70, 50, 38 }),
	palCabana({ 118, 110, 98 }, { 60, 52, 46 }, { 90, 66, 48 }),
	palCabana({ 120, 78, 60 }, { 48, 42, 40 }, { 60, 56, 50 }),
	palCabana({ 96, 92, 66 }, { 56, 50, 44 }, { 100, 70, 50 }),
	palCabana({ 150, 128, 98 }, { 70, 58, 46 }, { 80, 60, 44 }),
}

-- ------------------------------------------------------------------------------------------------------------------
-- Construtor comum
-- ------------------------------------------------------------------------------------------------------------------
local function J(de, larg, extra)
	local t = { de = de, larg = larg or 4, tipo = "janela" }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end
local function P(de, larg)
	return { de = de, larg = larg or 5.5, tipo = "porta" }
end
local function PI_(de)
	return { de = de, larg = 5.2, tipo = "porta" }
end

local function novo(ctx, spec, def)
	local rng = spec.rng or ctx.rng("casas_" .. def.variante)
	local B = { ctx = ctx, rng = rng, cf = spec.cf, def = def, c = def.corpo }
	B.pal = spec.paleta or rng.escolher(def.paletas)
	B.andares = spec.andares or def.andares
	B.espelho = rng.chance(0.5)
	B.modelo =
		ctx.modeloConstrucao(spec, def.tipo, def.variante, def.w, def.d, B.andares * 12 + def.telhadoAlt + 2, B.andares)
	B.loots = {}
	local c, modelo, cf, pl = B.c, B.modelo, B.cf, B.pal
	local mat = pl.mat or "Concrete"

	local function px(x)
		return if B.espelho then -x else x
	end
	B.px = px
	local function topo(a)
		return if a == 0 then 0.2 else a * 12
	end
	B.topo = topo

	function B.bloco(nome, cx, cy, cz, sx, sy, sz, cor, m, op)
		return ctx.bloco(modelo, cf, nome, px(cx), cy, cz, sx, sy, sz, cor, m, op)
	end

	-- parede interna/externa em coordenadas desespelhadas
	function B.parede(x0, z0, x1, z1, andar, esp, cor, m, ab, op)
		return ctx.parede(modelo, cf, "Parede", { px(x0), z0 }, { px(x1), z1 }, andar * 12, 11, esp, cor, m, ab, op)
	end
	function B.divisoria(x0, z0, x1, z1, andar, ab)
		return B.parede(x0, z0, x1, z1, andar, 0.8, pl.interna, "Concrete", ab)
	end

	-- paredes externas de um andar. lados = { frente, tras, esq, dir } (listas de aberturas)
	function B.ext(andar, lados)
		local defs = {
			{ "frente", c.x0, c.z0, c.x1, c.z0, 0, -1 },
			{ "tras", c.x0, c.z1, c.x1, c.z1, 0, 1 },
			{ "esq", c.x0, c.z0, c.x0, c.z1, -1, 0 },
			{ "dir", c.x1, c.z0, c.x1, c.z1, 1, 0 },
		}
		for _, d in defs do
			local ab = lados[d[1]] or {}
			for _, a in ab do
				a.cor = a.cor or (if a.tipo == "porta" then pl.porta else pl.moldura)
			end
			B.parede(d[2], d[3], d[4], d[5], andar, 1, pl.parede, mat, ab)
			local horiz = d[3] == d[5]
			for _, a in ab do
				if a.tipo == "janela" and rng.chance(0.14) then
					local cx = if horiz then d[2] + a.de else d[2]
					local cz = if horiz then d[3] else d[3] + a.de
					local yc = andar * 12 + 3.4 + 1.8
					local nx, nz = d[6] * 0.7, d[7] * 0.7
					for _, s in { -1, 1 } do
						local op = { colide = false, consulta = false, sombra = false }
						if horiz then
							op.rot = CFrame.Angles(0, 0, s * 0.38)
							ctx.bloco(
								modelo,
								cf,
								"Tapume",
								px(cx + nx),
								yc,
								cz + nz,
								a.larg + 1.2,
								0.55,
								0.25,
								{ 98, 74, 52 },
								"WoodPlanks",
								op
							)
						else
							op.rot = CFrame.Angles(s * 0.38, 0, 0)
							ctx.bloco(
								modelo,
								cf,
								"Tapume",
								px(cx + nx),
								yc,
								cz + nz,
								0.25,
								0.55,
								a.larg + 1.2,
								{ 98, 74, 52 },
								"WoodPlanks",
								op
							)
						end
					end
				end
			end
		end
	end

	-- piso. andar 0: assoalho fino; andar ≥ 1: laje de 1 cobrindo a pegada do corpo (furos em coordenadas REAIS)
	function B.laje(andar, furos, ultimo)
		if andar == 0 then
			ctx.piso(modelo, cf, "Piso", c.x0, c.x1, c.z0, c.z1, 0.2, 0.2, pl.piso, "WoodPlanks")
		else
			ctx.piso(
				modelo,
				cf,
				"Laje",
				c.x0 - 0.5,
				c.x1 + 0.5,
				c.z0 - 0.5,
				c.z1 + 0.5,
				andar * 12,
				1,
				pl.piso,
				"WoodPlanks",
				furos
			)
		end
	end
	function B.forro(andares)
		ctx.piso(
			modelo,
			cf,
			"Forro",
			c.x0 - 0.5,
			c.x1 + 0.5,
			c.z0 - 0.5,
			c.z1 + 0.5,
			andares * 12,
			1,
			pl.forro,
			"Concrete"
		)
	end
	-- ladrilho (banheiro/cozinha) sobre o piso
	function B.ladrilho(andar, x0, x1, z0, z1)
		local y = topo(andar) + 0.04
		local ax, bx = px(x0), px(x1)
		ctx.piso(
			modelo,
			cf,
			"Ladrilho",
			math.min(ax, bx),
			math.max(ax, bx),
			z0,
			z1,
			y + 0.04,
			0.08,
			pl.ladrilho,
			"Marble"
		)
	end

	function B.escada(andar, x, z, dir, larg)
		local d = dir
		if B.espelho and (dir == "+x" or dir == "-x") then
			d = if dir == "+x" then "-x" else "+x"
		end
		local yb = topo(andar)
		return ctx.escada(
			modelo,
			cf,
			"Degrau",
			px(x),
			z,
			d,
			yb,
			(andar + 1) * 12 - yb,
			larg,
			pl.piso,
			"WoodPlanks",
			{ subida = 1, passada = 1 }
		)
	end
	function B.corrimao(x0, z0, x1, z1, andar)
		local ax, bx = px(x0), px(x1)
		ctx.bloco(
			modelo,
			cf,
			"Guarda",
			(ax + bx) / 2,
			andar * 12 + 1.5,
			(z0 + z1) / 2,
			math.max(0.3, math.abs(bx - ax)),
			3,
			math.max(0.3, z1 - z0),
			pl.coluna,
			"WoodPlanks",
			{ consulta = false, sombra = false }
		)
	end

	-- mobília
	function B.mov(nome, andar, x, z, rot, op)
		op = op or {}
		op.rng = op.rng or rng
		local r = rot or 0
		return Mob.colocar(ctx, modelo, nome, cf, px(x), topo(andar), z, if B.espelho then -r else r, op)
	end
	function B.enc(nome, andar, lado, ao, sala, op, folga)
		local x, z, r = Mob.paraParede(nome, lado, ao, sala, folga)
		return B.mov(nome, andar, x, z, r, op)
	end
	-- peça de parede (fixo = "parede"): lado = parede à qual encosta (-z: sala fica em +z)
	function B.nParede(nome, andar, lado, x, z, alt, op)
		local rot = ({ ["-z"] = PI, ["+z"] = 0, ["-x"] = -PI / 2, ["+x"] = PI / 2 })[lado]
		op = op or {}
		op.rng = op.rng or rng
		local r = rot
		return Mob.colocar(ctx, modelo, nome, cf, px(x), topo(andar) + alt, z, if B.espelho then -r else r, op)
	end
	function B.loot(andar, x, z)
		table.insert(B.loots, { x = px(x), y = topo(andar), z = z })
	end

	-- varanda frontal com colunas, cobertura e guarda-corpos
	function B.varanda(x0, x1, prof, portaX, altCob)
		local zf = c.z0 - 0.5
		local z0 = zf - prof
		local cob = altCob or 10
		B.bloco("Varanda", (x0 + x1) / 2, 0.2, (z0 + zf) / 2, x1 - x0, 0.4, prof, pl.piso, "WoodPlanks")
		for _, x in { x0 + 0.5, x1 - 0.5 } do
			B.bloco("Coluna", x, cob / 2, z0 + 0.6, 0.9, cob, 0.9, pl.coluna, mat == "Wood" and "Wood" or "WoodPlanks")
		end
		B.bloco(
			"Cobertura",
			(x0 + x1) / 2,
			cob + 0.3,
			(z0 + zf) / 2 - 0.2,
			x1 - x0 + 0.8,
			0.6,
			prof + 0.4,
			pl.telhado,
			pl.matTelhado or "Slate"
		)
		local op = { colide = false, consulta = false, sombra = false }
		for _, y in { 1.2, 2.8 } do
			local a, b = x0 + 0.5, portaX - 3
			if b - a > 0.4 then
				B.bloco("Corrimao", (a + b) / 2, y, z0 + 0.6, b - a, 0.3, 0.3, pl.coluna, "WoodPlanks", op)
			end
			a, b = portaX + 3, x1 - 0.5
			if b - a > 0.4 then
				B.bloco("Corrimao", (a + b) / 2, y, z0 + 0.6, b - a, 0.3, 0.3, pl.coluna, "WoodPlanks", op)
			end
		end
		for _, x in { x0 + 0.5, x1 - 0.5 } do
			B.bloco("Corrimao", x, 2.0, (z0 + zf) / 2, 0.3, 0.3, prof - 0.4, pl.coluna, "WoodPlanks", op)
		end
	end

	-- plinto, calha, número, caixa de correio
	function B.acabamento(portaX, numX, caixaX)
		local op = { colide = false, consulta = false, sombra = false }
		local W, D = c.x1 - c.x0 + 1.2, c.z1 - c.z0 + 1.2
		local zc, xc = (c.z0 + c.z1) / 2, (c.x0 + c.x1) / 2
		B.bloco("Plinto", xc, 0.6, c.z0 - 0.62, W, 1.2, 0.25, pl.base, "Concrete", op)
		B.bloco("Plinto", xc, 0.6, c.z1 + 0.62, W, 1.2, 0.25, pl.base, "Concrete", op)
		B.bloco("Plinto", c.x0 - 0.62, 0.6, zc, 0.25, 1.2, D, pl.base, "Concrete", op)
		B.bloco("Plinto", c.x1 + 0.62, 0.6, zc, 0.25, 1.2, D, pl.base, "Concrete", op)
		-- número
		local n = rng.inteiro(11, 98)
		local p = ctx.bloco(
			modelo,
			cf,
			"Numero",
			px(numX),
			6.4,
			c.z0 - 0.58,
			1.6,
			1.0,
			0.12,
			{ 205, 205, 195 },
			"SmoothPlastic",
			op
		)
		pcall(function()
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = tostring(n)
			t.TextColor3 = roblox.Color3.fromRGB(30, 30, 30)
			t.TextScaled = true
			t.Parent = g
			g.Parent = p
		end)
		-- caixa de correio
		local zf = -B.def.d / 2 + 0.8
		B.bloco("PosteCorreio", caixaX, 1.6, zf, 0.4, 3.2, 0.4, pl.metal, "Metal", op)
		B.bloco("CaixaCorreio", caixaX, 3.5, zf, 1.2, 0.9, 1.6, { 70, 80, 90 }, "Metal", op)
	end

	-- telhado, oitões, chaminé e calhas
	function B.telhado(cumeeiraZ, beiral, chamX, chamZ)
		local H = B.def.telhadoAlt
		local yb = B.andares * 12
		local W, D = c.x1 - c.x0 + 1, c.z1 - c.z0 + 1
		local xc, zc = (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2
		ctx.telhadoDuasAguas(
			modelo,
			cf,
			"Telhado",
			0,
			zc,
			W,
			D,
			yb,
			H,
			beiral,
			0.8,
			pl.telhado,
			pl.matTelhado or "Slate",
			cumeeiraZ
		)
		-- oitões em degraus
		local meia = if cumeeiraZ then W / 2 + beiral else D / 2 + beiral
		local corpoMeia = if cumeeiraZ then W / 2 else D / 2
		local n = 5
		for i = 1, n - 1 do
			local hw = math.min(corpoMeia, meia * (1 - i / n))
			if hw > 0.4 then
				local y = yb + (i - 0.5) * H / n
				if cumeeiraZ then
					for _, z in { c.z0, c.z1 } do
						ctx.bloco(modelo, cf, "Oitao", px(0), y, z, hw * 2, H / n, 1, pl.parede, mat)
					end
				else
					for _, x in { c.x0, c.x1 } do
						ctx.bloco(modelo, cf, "Oitao", px(x), y, zc, 1, H / n, hw * 2, pl.parede, mat)
					end
				end
			end
		end
		if chamX then
			local t = if cumeeiraZ then math.abs(chamX) / meia else math.abs(chamZ - zc) / meia
			local topoTel = yb + H * (1 - t)
			local alto = topoTel + 2.2 - (yb - 1)
			B.bloco("Chamine", chamX, yb - 1 + alto / 2, chamZ, 2.4, alto, 2.4, pl.tijolo, "Brick")
			B.bloco("ChamineTopo", chamX, topoTel + 2.4, chamZ, 3.0, 0.4, 3.0, pl.base, "Concrete")
		end
		-- calhas e tubo de queda
		local op = { colide = false, consulta = false, sombra = false }
		if cumeeiraZ then
			for _, s in { -1, 1 } do
				ctx.cilindro(
					modelo,
					cf,
					"Calha",
					px(s * (W / 2 + beiral - 0.2)),
					yb - 0.7,
					zc,
					0.6,
					D + 2 * beiral - 0.4,
					pl.metal,
					"Metal",
					{ eixo = "z", colide = false, consulta = false, sombra = false }
				)
			end
			ctx.cilindro(
				modelo,
				cf,
				"Tubo",
				px(c.x1 + 0.9),
				(yb - 0.7) / 2,
				c.z0 + 0.8,
				0.5,
				yb - 0.7,
				pl.metal,
				"Metal",
				op
			)
		else
			for _, s in { -1, 1 } do
				ctx.cilindro(
					modelo,
					cf,
					"Calha",
					px(0),
					yb - 0.7,
					zc + s * (D / 2 + beiral - 0.2),
					0.6,
					W + 2 * beiral - 0.4,
					pl.metal,
					"Metal",
					{ eixo = "x", colide = false, consulta = false, sombra = false }
				)
			end
			ctx.cilindro(
				modelo,
				cf,
				"Tubo",
				px(c.x1 + 0.9),
				(yb - 0.7) / 2,
				c.z0 - 0.9,
				0.5,
				yb - 0.7,
				pl.metal,
				"Metal",
				op
			)
		end
	end

	function B.fim(portaX, prof)
		return B.modelo,
			{
				loot = B.loots,
				frente = { px(portaX), c.z0 - 0.5 - (prof or 2) / 2 },
				portaria = { px(portaX), c.z0 },
			}
	end
	return B
end

local function tipoDe(variante, w, d, andares, tipo, corpo, tel, paletas)
	return {
		variante = variante,
		w = w,
		d = d,
		andares = andares,
		tipo = tipo,
		corpo = corpo,
		telhadoAlt = tel,
		paletas = paletas,
	}
end

-- clutter discreto: caixa de papelão em ponto livre, por rng
local function bagunca(B, andar, x, z, chance)
	if B.rng.chance(chance) then
		B.mov("caixa_papelao", andar, x, z, B.rng.entre(0, PI))
	end
end

-- ------------------------------------------------------------------------------------------------------------------
-- casa_pequena 24×20
-- ------------------------------------------------------------------------------------------------------------------
local DEF_PEQ = tipoDe("casa_pequena", 24, 20, 1, "casa", { x0 = -10, x1 = 10, z0 = -7, z1 = 8 }, 5.5, PAL_CASA)
DEF_PEQ.paletas = PAL_CASA

M.catalogo.casa_pequena = {
	paletas = PAL_CASA,
	construir = function(ctx, spec)
		local B = novo(ctx, spec, DEF_PEQ)
		B.laje(0)
		B.ext(0, {
			frente = { J(4), P(13.5) },
			tras = { J(11.4) },
			esq = { J(11.8, 3) },
			dir = { J(6) },
		})
		B.divisoria(-1.5, -7, -1.5, 8, 0, { PI_(3.6), PI_(11.8) })
		B.divisoria(-10, 1.6, -1.5, 1.6, 0, {})
		B.forro(1)
		B.ladrilho(0, -9.5, -1.9, 2.0, 7.5)
		B.varanda(-9.5, 9.5, 2.5, 3.5)
		B.acabamento(3.5, 8.5, 10.5)
		B.telhado(false, 1.5, 6.5, 3)
		local Q = { x0 = -9.5, x1 = -1.9, z0 = -6.5, z1 = 1.2 }
		local Bn = { x0 = -9.5, x1 = -1.9, z0 = 2.0, z1 = 7.5 }
		local S = { x0 = -1.1, x1 = 9.5, z0 = -6.5, z1 = 7.5 }
		-- quarto
		B.enc("cama_solteiro", 0, "-z", -7.9, Q)
		B.enc("criado_mudo", 0, "-z", -5.3, Q)
		B.mov("cesto_roupa", 0, -3.2, 0.2, 0)
		-- banheiro
		B.enc("banheira", 0, "+z", -6.5, Bn)
		B.enc("vaso_sanitario", 0, "-x", 3.3, Bn)
		B.enc("lavatorio", 0, "-z", -5.0, Bn)
		B.nParede("espelho_banheiro", 0, "-z", -5.0, 2.0, 4.6)
		-- sala + cozinha
		B.enc("geladeira", 0, "+z", 8.0, S)
		B.enc("fogao", 0, "+z", 5.3, S)
		B.enc("pia_cozinha", 0, "+z", 1.4, S)
		B.mov("mesa_cozinha", 0, 3.5, 1.5, 0)
		B.mov("cadeira", 0, 1.1, 1.5, -PI / 2)
		B.mov("cadeira", 0, 5.9, 1.5, PI / 2)
		B.enc("sofa_pequeno", 0, "+x", -1, S)
		B.mov("mesa_centro", 0, 5.2, -1, PI / 2)
		B.mov("poltrona", 0, 7.8, -5.0, PI)
		B.mov("planta_vaso", 0, -0.1, -5.6, 0)
		B.nParede("quadro", 0, "-x", -1.1, 3.5, 6.5)
		bagunca(B, 0, 3.2, -2.5, 0.6)
		B.loot(0, 7.5, 3.0)
		B.loot(0, -5.0, -1.5)
		B.loot(0, 2.2, -3.0)
		return B.fim(3.5, 2.5)
	end,
}

-- ------------------------------------------------------------------------------------------------------------------
-- casa_media 30×24 (1–2 andares)
-- ------------------------------------------------------------------------------------------------------------------
local DEF_MED = tipoDe("casa_media", 30, 24, 1, "casa", { x0 = -13, x1 = 13, z0 = -7, z1 = 10 }, 6, PAL_CASA)

M.catalogo.casa_media = {
	paletas = PAL_CASA,
	construir = function(ctx, spec)
		DEF_MED.andares = spec.andares or 1
		local B = novo(ctx, spec, DEF_MED)
		local n = B.andares
		local st = nil
		B.laje(0)
		B.ext(0, {
			frente = { J(3, 4), P(10), J(20) },
			tras = { J(9), J(24, 3) },
			esq = { J(2, 3.5) },
			dir = { J(3) },
		})
		B.divisoria(2, -7, 2, 10, 0, { PI_(4.5), PI_(14) })
		B.divisoria(2, 3.6, 13, 3.6, 0, {})
		B.ladrilho(0, 2.4, 12.5, 4.0, 9.5)
		if n >= 2 then
			st = B.escada(0, -10.25, -2.5, "+z", 4.5)
		end
		-- térreo
		local Sa = { x0 = -12.5, x1 = 1.6, z0 = -6.5, z1 = 9.5 }
		local Co = { x0 = 2.4, x1 = 12.5, z0 = -6.5, z1 = 3.2 }
		local La = { x0 = 2.4, x1 = 12.5, z0 = 4.0, z1 = 9.5 }
		B.mov("sofa", 0, -6.8, 2.0, -PI / 2)
		B.mov("mesa_centro", 0, -3.4, 2.0, PI / 2)
		B.enc("pia_cozinha", 0, "+z", 4.9, Co)
		B.enc("geladeira", 0, "+z", 8.9, Co)
		B.enc("fogao", 0, "+x", 1.0, Co)
		B.mov("mesa_cozinha", 0, 6.5, -2.5, 0)
		B.enc("vaso_sanitario", 0, "+z", 6.5, La)
		B.enc("lavatorio", 0, "+z", 10.2, La)
		B.loot(0, -4.5, -1.5)
		B.loot(0, 9.5, -2.0)
		if n == 1 then
			B.mov("arquivo", 0, -11, 8.5, PI)
			B.mov("cabideiro", 0, -9.5, 8.8, 0)
			B.mov("caixa_papelao", 0, -11, 4, 0)
		else
			-- andar de cima
			local furoReal = { x0 = st.x0, x1 = st.x1, z0 = st.z0, z1 = st.z1 }
			B.laje(1, { furoReal })
			B.ext(1, {
				frente = { J(3.5 + 13, 4), J(9.5 + 13, 4) },
				tras = { J(15), J(22.5 + 0, 3) },
				esq = { J(2, 3.5) },
				dir = { J(4) },
			})
			B.divisoria(-2.5, -7, -2.5, 10, 1, { PI_(4), PI_(12.6) })
			B.divisoria(-2.5, 1.6, 13, 1.6, 1, {})
			B.divisoria(6.4, 1.6, 6.4, 10, 1, { PI_(4.2) })
			B.ladrilho(1, 6.8, 12.5, 2.0, 9.5)
			B.corrimao(-8.0, -2.5, -7.8, 5.0, 1)
			B.corrimao(-12.5, -2.7, -8.0, -2.5, 1)
			local Qb = { x0 = -2.1, x1 = 12.5, z0 = -6.5, z1 = 1.2 }
			local Qc = { x0 = -2.1, x1 = 6.0, z0 = 2.0, z1 = 9.5 }
			local Ba = { x0 = 6.8, x1 = 12.5, z0 = 2.0, z1 = 9.5 }
			B.enc("cama_casal", 1, "+x", -3.0, Qb)
			B.enc("criado_mudo", 1, "+x", 0.2, Qb)
			B.enc("guarda_roupa", 1, "+z", 2.0, Qb)
			B.enc("cama_solteiro", 1, "+z", 3.8, Qc)
			B.enc("banheira", 1, "+x", 6.2, Ba)
			B.enc("lavatorio", 1, "-z", 9.3, Ba)
			B.enc("vaso_sanitario", 1, "+z", 9.0, Ba)
			bagunca(B, 1, -5, 4, 0.5)
			B.loot(1, 5.0, -3.0)
			B.loot(1, 2.0, 6.5)
			B.loot(1, -10.5, -4.5)
		end
		B.forro(n)
		B.varanda(-8, 2, 4.4, -3)
		B.acabamento(-3, -7.2, 11)
		B.telhado(true, 1.5, 9, 4)
		return B.fim(-3, 4.4)
	end,
}

-- ------------------------------------------------------------------------------------------------------------------
-- casa_grande 36×28 (2 andares, garagem integrada)
-- ------------------------------------------------------------------------------------------------------------
local DEF_GRA = tipoDe("casa_grande", 36, 28, 2, "casa", { x0 = -16, x1 = 16, z0 = -9, z1 = 12 }, 7, PAL_CASA)

M.catalogo.casa_grande = {
	paletas = PAL_CASA,
	construir = function(ctx, spec)
		local B = novo(ctx, spec, DEF_GRA)
		B.laje(0)
		B.ext(0, {
			frente = { P(7), J(14.5), { de = 26.2, larg = 10, tipo = "vao", alt = 8.5 } },
			tras = { J(13.5) },
			esq = { J(3.5) },
			dir = {},
		})
		-- porta de enrolar aberta
		B.bloco(
			"PortaEnrolar",
			10.2,
			9.1,
			-9.5,
			10.4,
			1.0,
			0.7,
			{ 150, 150, 145 },
			"CorrodedMetal",
			{ colide = false, consulta = false }
		)
		B.divisoria(4.4, -9, 4.4, 12, 0, { PI_(9) })
		B.divisoria(-10.8, 4.5, 4.4, 4.5, 0, { { de = 7.6, larg = 9, tipo = "arco" } })
		local st = B.escada(0, -13.25, -4.5, "+z", 4.5)
		local Sa = { x0 = -10.8, x1 = 4.0, z0 = -8.5, z1 = 4.1 }
		local Co = { x0 = -10.8, x1 = 4.0, z0 = 4.9, z1 = 11.5 }
		local Ga = { x0 = 4.8, x1 = 15.5, z0 = -8.5, z1 = 11.5 }
		B.mov("sofa", 0, -3.0, -5.3, -PI / 2)
		B.mov("mesa_centro", 0, -0.3, -5.3, PI / 2)
		B.enc("geladeira", 0, "+z", -9.4, Co)
		B.enc("fogao", 0, "+z", -6.5, Co)
		B.enc("pia_cozinha", 0, "+z", -2.5, Co)
		B.mov("mesa_cozinha", 0, 1.9, 7.8, 0)
		B.ladrilho(0, -10.8, 4.0, 4.9, 11.5)
		local carro = Props.carro(
			ctx,
			B.modelo,
			B.cf * CFrame.new(B.px(10.15), 0.2, -2),
			{ variante = B.rng.inteiro(1, 5), rng = B.rng }
		)
		B.enc("prateleira_garagem", 0, "+z", 8, Ga)
		B.enc("bancada_ferramentas", 0, "+x", 6.5, Ga)
		B.loot(0, -5, -1)
		B.loot(0, -4, 8)
		B.loot(0, 11, 8)
		-- andar de cima
		B.laje(1, { st })
		B.ext(1, {
			frente = { J(3, 3), J(15.5, 4), J(27, 4) },
			tras = { J(15.5), J(27, 3) },
			esq = {},
			dir = { J(3), J(17, 3) },
		})
		B.divisoria(-5.4, -9, -5.4, 12, 1, { PI_(3.5), { de = 9.7, larg = 5.4, tipo = "vao" }, PI_(16.8) })
		B.divisoria(-5.4, -2.2, 16, -2.2, 1, { PI_(15.6) })
		B.divisoria(-5.4, 3.6, 16, 3.6, 1, { PI_(15.6) })
		B.divisoria(4.7, -9, 4.7, -2.2, 1, {})
		B.divisoria(4.7, 3.6, 4.7, 12, 1, {})
		B.corrimao(-11.0, -4.5, -10.8, 3.0, 1)
		B.corrimao(-15.5, -4.7, -11.0, -4.5, 1)
		local Q1 = { x0 = -5.0, x1 = 4.3, z0 = -8.5, z1 = -2.6 }
		local Q2 = { x0 = 5.1, x1 = 15.5, z0 = -8.5, z1 = -2.6 }
		local Q3 = { x0 = -5.0, x1 = 4.3, z0 = 4.0, z1 = 11.5 }
		local Ba = { x0 = 5.1, x1 = 15.5, z0 = 4.0, z1 = 11.5 }
		B.ladrilho(1, 5.1, 15.5, 4.0, 11.5)
		B.enc("cama_casal", 1, "+x", -5.8, Q1)
		B.enc("cama_solteiro", 1, "+x", -7.0, Q2)
		B.enc("cama_casal", 1, "+z", 1.5, Q3)
		B.enc("guarda_roupa", 1, "-z", -1.5, Q3)
		B.enc("banheira", 1, "+z", 12.0, Ba)
		B.enc("vaso_sanitario", 1, "+x", 6.5, Ba)
		B.enc("lavatorio", 1, "-z", 13.0, Ba)
		B.loot(1, 7.0, -5.0)
		B.loot(1, 7.5, 8.0)
		B.loot(1, 1.5, 0.7)
		B.loot(1, -8.0, 9.5)
		B.forro(2)
		B.varanda(-13, -4, 4.4, -9)
		B.acabamento(-9, -2, 14.5)
		B.telhado(false, 1.5, 12, 6)
		return B.fim(-9, 4.4)
	end,
}

-- ------------------------------------------------------------------------------------------------------------------
-- sobrado 20×26 (2–3 andares; térreo comércio ou sala)
-- ------------------------------------------------------------------------------------------------------------------
local DEF_SOB = tipoDe("sobrado", 20, 26, 2, "casa", { x0 = -8.5, x1 = 8.5, z0 = -9, z1 = 11.5 }, 5.5, PAL_CASA)

M.catalogo.sobrado = {
	paletas = PAL_CASA,
	construir = function(ctx, spec)
		DEF_SOB.andares = spec.andares or 2
		local B = novo(ctx, spec, DEF_SOB)
		local n = B.andares
		local loja = B.rng.chance(0.5)
		B.laje(0)
		B.ext(0, {
			frente = { P(6), if loja then J(13, 6) else J(13, 4) },
			tras = { J(5, 4) },
			esq = { J(3) },
			dir = {},
		})
		local st = B.escada(0, 5.75, -1, "+z", 4.5)
		local T = { x0 = -8, x1 = 3.2, z0 = -8.5, z1 = 11 }
		if loja then
			B.enc("prateleira_loja", 0, "-x", -3.0, T)
			B.enc("prateleira_loja", 0, "-x", 4.0, T)
			B.enc("balcao_loja", 0, "+z", -2.5, T)
			B.enc("vitrine", 0, "-z", 1.5, T)
			B.mov("caixa_papelao", 0, -1, -3, 0.4)
		else
			B.enc("sofa_pequeno", 0, "-x", -3.0, T)
			B.enc("geladeira", 0, "+z", 1.5, T)
			B.enc("fogao", 0, "+z", -1.5, T)
			B.enc("pia_cozinha", 0, "+z", -5.5, T)
			B.mov("mesa_cozinha", 0, -4.5, 6, 0)
		end
		B.loot(0, -1, 2)
		B.loot(0, -4.5, 3)
		for a = 1, n - 1 do
			local ultimo = a == n - 1
			B.laje(a, { st })
			-- escada do andar a ao a+1: começa na ponta da frente (laje maciça) e passa sobre o furo da de baixo
			if a < n - 1 then
				st = B.escada(a, 5.75, -8, "+z", 4.5)
			end
			local frente = { J(3, 4) }
			B.ext(a, { frente = frente, tras = { J(4.5, 3) }, esq = { J(15, 3) }, dir = { J(4) } })
			B.divisoria(-2.0, -9, -2.0, 11.5, a, { PI_(4.5), PI_(15) })
			B.divisoria(-8.5, 0.8, -2.0, 0.8, a, {})
			if a == 1 then
				B.corrimao(3.4, -1, 3.6, 7.0, a)
				B.corrimao(3.4, -1.2, 8.0, -1, a)
			end
			local F = { x0 = -8, x1 = -2.4, z0 = -8.5, z1 = 0.4 }
			local K = { x0 = -8, x1 = -2.4, z0 = 1.2, z1 = 11 }
			if a == 1 then
				B.enc("cama_solteiro", a, "-z", -6.0, F)
				B.ladrilho(a, -8, -2.4, 1.2, 11)
				B.enc("banheira", a, "-x", 5.7, K)
				B.enc("vaso_sanitario", a, "+z", -5.0, K)
				B.enc("lavatorio", a, "-z", -5.0, K)
			else
				B.enc("cama_solteiro", a, "-z", -6.0, F)
				B.enc("escrivaninha", a, "+z", -5.0, K)
			end
			B.loot(a, -5.5, -0.8)
			B.loot(a, 0.5, 4)
			if ultimo then
				B.mov("planta_vaso", a, 5.5, -6.5, 0)
			end
		end
		B.forro(n)
		B.varanda(-6, 2, 3.0, -2.5)
		B.acabamento(-2.5, -5.5, 8.8)
		B.telhado(true, 1.0, -6, 2)
		return B.fim(-2.5, 3.0)
	end,
}

-- ------------------------------------------------------------------------------------------------------------------
-- cabana 22×18
-- ------------------------------------------------------------------------------------------------------------------
local DEF_CAB = tipoDe("cabana", 22, 18, 1, "cabana", { x0 = -9.5, x1 = 9.5, z0 = -5, z1 = 7.5 }, 5, PAL_CABANA)

M.catalogo.cabana = {
	paletas = PAL_CABANA,
	construir = function(ctx, spec)
		local B = novo(ctx, spec, DEF_CAB)
		local pl = B.pal
		B.laje(0)
		B.ext(0, {
			frente = { J(3, 3.5), P(9), J(16, 3.5) },
			tras = { J(10.5, 3), J(3.5, 3) },
			esq = { J(4, 3) },
			dir = {},
		})
		B.divisoria(-2.0, 1.0, -2.0, 8, 0, {})
		B.divisoria(-10, 1.0, -2.0, 1.0, 0, { PI_(4.3) })
		-- troncos: poste nos cantos e faixas de tora
		local op = { colide = false, consulta = false, sombra = false }
		for _, x in { -9.9, 9.9 } do
			for _, z in { -5.4, 7.9 } do
				ctx.cilindro(B.modelo, B.cf, "Tora", B.px(x), 5.5, z, 1.6, 11, pl.coluna, "Wood", { colide = false })
			end
		end
		for _, y in { 3, 7 } do
			B.bloco("Faixa", 0, y, -5.62, 19, 0.5, 0.25, pl.coluna, "Wood", op)
			B.bloco("Faixa", 0, y, 8.12, 19, 0.5, 0.25, pl.coluna, "Wood", op)
		end
		-- chaminé de pedra do lado de fora
		B.bloco("ChamineExt", 11.0, 6.5, 1.5, 2.0, 13, 3.0, pl.tijolo, "Cobblestone")
		B.forro(1)
		B.varanda(-6, 6, 3.4, -0.5, 9)
		B.acabamento(-0.5, -4.6, 9.8)
		B.telhado(true, 1.0)
		local Mr = { x0 = -9, x1 = 9, z0 = -4.5, z1 = 7 }
		local Qr = { x0 = -9, x1 = -2.4, z0 = 1.4, z1 = 7 }
		B.enc("lareira", 0, "+x", 1.5, Mr)
		B.mov("sofa_pequeno", 0, 3.0, 1.5, -PI / 2)
		B.mov("poltrona", 0, 4.2, -2.8, -PI / 2)
		B.mov("tapete", 0, 4.8, 1.5, PI / 2)
		B.enc("pia_cozinha", 0, "+z", 1.0, Mr)
		B.enc("fogao", 0, "+z", 5.4, Mr)
		B.enc("geladeira", 0, "+z", 8.0, Mr)
		B.mov("mesa_cozinha", 0, -6.5, -2.5, 0)
		B.mov("cadeira", 0, -8.2, -2.5, -PI / 2)
		B.mov("cadeira", 0, -4.8, -2.5, PI / 2)
		B.enc("cama_solteiro", 0, "-x", 5.5, Qr)
		B.enc("bau", 0, "+z", -3.5, Qr)
		bagunca(B, 0, 8.2, -4.6, 0.6)
		B.loot(0, 0, 3.5)
		B.loot(0, -6, 3.0)
		B.loot(0, -1.0, 0.0)
		return B.fim(-0.5, 3.4)
	end,
}

return M
