-- Edifícios de serviço do mapa v2: hospital, delegacia, bombeiros, escola, prefeitura, biblioteca (agente E4).
-- Contrato: docs/mapa-v2.md §5. Frente = −Z local; piso do térreo em Y local = yb (0,1); andar = 12; laje 0,9.
-- Móveis só via Mob (mobilia.luau); caminhão via Props.

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Enum = roblox.Enum
local Instance = roblox.Instance
local UDim2 = roblox.UDim2

local Mob = require("./mobilia")
local Props = require("./props")

local abs, floor, max, min, pi = math.abs, math.floor, math.max, math.min, math.pi

local M = { catalogo = {} }

local ALT = 12 -- pé-direito
local ESP_EXT = 1 -- parede externa
local PORTA = 5.5 -- vão livre das portas internas
local PASSADA = 1.2 -- escada compacta (degrau 1 × 1,2): 12 de subida em 14,4 de comprimento
local C_METAL = { 70, 72, 74 }

-- ---------------------------------------------------------------------------------------------------------------
-- Paletas. Chaves: parede/matParede (fachada), interna/matInterna, piso/matPiso, porta, detalhe (molduras, cornija),
-- telhado (parapeito/cobertura), acento (letreiro, faixas), escada.
-- ---------------------------------------------------------------------------------------------------------------
local function pal(t)
	t.matParede = t.matParede or "Concrete"
	t.interna = t.interna or t.parede
	t.matInterna = t.matInterna or "Concrete"
	t.matPiso = t.matPiso or "Concrete"
	t.escada = t.escada or { 112, 112, 108 }
	t.telhado = t.telhado or { 60, 45, 42 }
	return t
end

local PAL = {
	hospital = {
		pal({
			parede = { 128, 140, 132 },
			interna = { 150, 154, 148 },
			piso = { 118, 124, 120 },
			porta = { 84, 104, 112 },
			detalhe = { 190, 192, 188 },
			telhado = { 78, 82, 82 },
			acento = { 150, 40, 40 },
		}),
		pal({
			parede = { 108, 122, 136 },
			interna = { 146, 150, 150 },
			piso = { 110, 116, 120 },
			porta = { 70, 84, 100 },
			detalhe = { 184, 188, 190 },
			telhado = { 66, 72, 80 },
			acento = { 148, 44, 40 },
		}),
		pal({
			parede = { 156, 148, 128 },
			interna = { 164, 160, 148 },
			piso = { 120, 112, 100 },
			porta = { 98, 82, 66 },
			detalhe = { 196, 190, 176 },
			telhado = { 80, 66, 58 },
			acento = { 140, 38, 36 },
		}),
		pal({
			parede = { 124, 126, 124 },
			interna = { 154, 156, 152 },
			piso = { 104, 106, 104 },
			porta = { 88, 96, 92 },
			detalhe = { 200, 200, 196 },
			telhado = { 70, 70, 72 },
			acento = { 146, 42, 42 },
		}),
		pal({
			parede = { 92, 110, 98 },
			interna = { 140, 148, 140 },
			piso = { 100, 108, 100 },
			porta = { 66, 84, 76 },
			detalhe = { 178, 184, 178 },
			telhado = { 58, 64, 62 },
			acento = { 150, 46, 40 },
		}),
	},
	delegacia = {
		pal({
			parede = { 98, 110, 128 },
			interna = { 140, 142, 140 },
			piso = { 96, 98, 100 },
			porta = { 52, 62, 82 },
			detalhe = { 176, 180, 188 },
			telhado = { 54, 58, 66 },
			acento = { 56, 84, 150 },
		}),
		pal({
			parede = { 130, 126, 116 },
			interna = { 150, 148, 140 },
			piso = { 100, 96, 90 },
			porta = { 60, 66, 84 },
			detalhe = { 190, 186, 176 },
			telhado = { 66, 60, 56 },
			acento = { 60, 86, 150 },
		}),
		pal({
			parede = { 112, 70, 62 },
			matParede = "Brick",
			interna = { 142, 138, 130 },
			piso = { 92, 92, 94 },
			porta = { 50, 58, 78 },
			detalhe = { 178, 174, 166 },
			telhado = { 56, 48, 46 },
			acento = { 58, 82, 146 },
		}),
		pal({
			parede = { 112, 116, 112 },
			interna = { 146, 148, 144 },
			piso = { 90, 92, 90 },
			porta = { 58, 70, 66 },
			detalhe = { 186, 188, 184 },
			telhado = { 58, 60, 58 },
			acento = { 54, 80, 140 },
		}),
	},
	bombeiros = {
		pal({
			parede = { 138, 70, 60 },
			matParede = "Brick",
			interna = { 150, 144, 134 },
			piso = { 96, 94, 92 },
			porta = { 150, 50, 42 },
			detalhe = { 186, 180, 168 },
			telhado = { 56, 50, 48 },
			acento = { 170, 52, 44 },
		}),
		pal({
			parede = { 150, 142, 126 },
			interna = { 154, 148, 136 },
			piso = { 100, 98, 94 },
			porta = { 146, 48, 40 },
			detalhe = { 196, 190, 176 },
			telhado = { 62, 54, 50 },
			acento = { 164, 50, 42 },
		}),
		pal({
			parede = { 120, 124, 122 },
			interna = { 148, 150, 146 },
			piso = { 92, 94, 92 },
			porta = { 150, 52, 44 },
			detalhe = { 186, 188, 184 },
			telhado = { 58, 58, 60 },
			acento = { 166, 54, 46 },
		}),
		pal({
			parede = { 118, 62, 56 },
			matParede = "Brick",
			interna = { 146, 140, 130 },
			piso = { 94, 92, 90 },
			porta = { 176, 168, 150 },
			detalhe = { 190, 184, 170 },
			telhado = { 50, 44, 44 },
			acento = { 160, 48, 40 },
		}),
	},
	escola = {
		pal({
			parede = { 156, 142, 108 },
			interna = { 160, 154, 134 },
			piso = { 110, 98, 80 },
			matPiso = "WoodPlanks",
			porta = { 84, 70, 54 },
			detalhe = { 198, 192, 174 },
			telhado = { 70, 54, 48 },
			acento = { 150, 52, 44 },
		}),
		pal({
			parede = { 132, 112, 96 },
			matParede = "Brick",
			interna = { 158, 152, 138 },
			piso = { 104, 94, 80 },
			matPiso = "WoodPlanks",
			porta = { 66, 82, 78 },
			detalhe = { 188, 182, 168 },
			telhado = { 62, 50, 46 },
			acento = { 72, 106, 96 },
		}),
		pal({
			parede = { 120, 134, 112 },
			interna = { 156, 160, 146 },
			piso = { 102, 100, 92 },
			porta = { 90, 76, 60 },
			detalhe = { 192, 192, 178 },
			telhado = { 64, 62, 56 },
			acento = { 170, 140, 56 },
		}),
		pal({
			parede = { 138, 142, 146 },
			interna = { 158, 160, 158 },
			piso = { 96, 98, 100 },
			porta = { 60, 78, 104 },
			detalhe = { 196, 198, 200 },
			telhado = { 62, 64, 70 },
			acento = { 66, 96, 148 },
		}),
		pal({
			parede = { 150, 124, 110 },
			interna = { 160, 152, 140 },
			piso = { 106, 92, 82 },
			matPiso = "WoodPlanks",
			porta = { 74, 94, 84 },
			detalhe = { 196, 186, 172 },
			telhado = { 66, 54, 50 },
			acento = { 146, 60, 48 },
		}),
	},
	prefeitura = {
		pal({
			parede = { 168, 164, 150 },
			matParede = "Limestone",
			interna = { 164, 160, 148 },
			piso = { 140, 136, 128 },
			matPiso = "Marble",
			porta = { 76, 58, 44 },
			detalhe = { 200, 198, 188 },
			telhado = { 70, 66, 64 },
			acento = { 150, 126, 60 },
		}),
		pal({
			parede = { 150, 130, 112 },
			matParede = "Brick",
			interna = { 162, 154, 140 },
			piso = { 128, 122, 114 },
			matPiso = "Marble",
			porta = { 60, 52, 48 },
			detalhe = { 196, 190, 176 },
			telhado = { 60, 54, 52 },
			acento = { 142, 118, 56 },
		}),
		pal({
			parede = { 138, 146, 142 },
			matParede = "Limestone",
			interna = { 160, 162, 156 },
			piso = { 124, 128, 124 },
			matPiso = "Marble",
			porta = { 62, 72, 80 },
			detalhe = { 198, 200, 196 },
			telhado = { 62, 66, 68 },
			acento = { 128, 138, 154 },
		}),
		pal({
			parede = { 176, 168, 146 },
			matParede = "Sandstone",
			interna = { 168, 162, 146 },
			piso = { 134, 128, 116 },
			matPiso = "Marble",
			porta = { 88, 62, 46 },
			detalhe = { 204, 198, 180 },
			telhado = { 74, 64, 58 },
			acento = { 150, 54, 46 },
		}),
	},
	biblioteca = {
		pal({
			parede = { 122, 78, 66 },
			matParede = "Brick",
			interna = { 150, 140, 122 },
			piso = { 82, 58, 42 },
			matPiso = "WoodPlanks",
			porta = { 64, 46, 36 },
			detalhe = { 186, 176, 156 },
			telhado = { 54, 44, 42 },
			acento = { 150, 120, 60 },
		}),
		pal({
			parede = { 96, 110, 98 },
			interna = { 146, 148, 134 },
			piso = { 78, 56, 40 },
			matPiso = "WoodPlanks",
			porta = { 70, 52, 40 },
			detalhe = { 184, 182, 164 },
			telhado = { 56, 48, 44 },
			acento = { 140, 112, 58 },
		}),
		pal({
			parede = { 142, 134, 116 },
			matParede = "Limestone",
			interna = { 156, 150, 134 },
			piso = { 86, 62, 46 },
			matPiso = "WoodPlanks",
			porta = { 62, 56, 52 },
			detalhe = { 196, 190, 172 },
			telhado = { 60, 50, 46 },
			acento = { 128, 98, 56 },
		}),
		pal({
			parede = { 104, 112, 124 },
			interna = { 148, 148, 142 },
			piso = { 76, 56, 42 },
			matPiso = "WoodPlanks",
			porta = { 60, 52, 56 },
			detalhe = { 180, 182, 186 },
			telhado = { 54, 52, 58 },
			acento = { 136, 108, 60 },
		}),
	},
}

-- ---------------------------------------------------------------------------------------------------------------
-- Kit de construção: um K por edifício (modelo + helpers de paredes, lajes, móveis, loot, letreiros)
-- ---------------------------------------------------------------------------------------------------------------
local function janelas(comp: number, passo: number, larg: number, res)
	local lista = {}
	local n = floor(comp / passo)
	if n < 1 then
		return lista
	end
	local off = (comp - n * passo) / 2
	for i = 1, n do
		local c = off + (i - 0.5) * passo
		local ok = c - larg / 2 > 2.2 and c + larg / 2 < comp - 2.2
		for _, r in res do
			if abs(c - r[1]) < r[2] + larg / 2 + 0.8 then
				ok = false
			end
		end
		if ok then
			table.insert(lista, { de = c, larg = larg, tipo = "janela" })
		end
	end
	return lista
end

local function novoK(ctx, spec, tipo: string, variante: string, w: number, d: number, extraAlt: number, yb: number?)
	local rng = spec.rng or ctx.rng("edif_" .. variante)
	local K = { ctx = ctx, spec = spec, cf = spec.cf, w = w, d = d, rng = rng, n = spec.andares, yb = yb or 0.1 }
	K.pal = spec.paleta or rng.escolher(PAL[variante])
	K.loots = {}
	K.m = ctx.modeloConstrucao(spec, tipo, variante, w, d, K.n * ALT + K.yb + extraAlt, K.n)
	local pal_ = K.pal

	function K.Y(k: number): number
		return k * ALT + K.yb
	end
	function K.b(nome: string, cx, cy, cz, sx, sy, sz, cor, mat: string, op)
		return ctx.bloco(K.m, K.cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end
	function K.cil(nome: string, cx, cy, cz, dia, comp, cor, mat: string, op)
		return ctx.cilindro(K.m, K.cf, nome, cx, cy, cz, dia, comp, cor, mat, op)
	end
	function K.par(a, b, base: number, alt: number, esp: number, cor, mat: string, ab, op)
		return ctx.parede(K.m, K.cf, "Parede", a, b, base, alt, esp, cor, mat, ab, op)
	end

	local function abertas(centros, de0: number, larg: number?, tipo: string?, alt: number?)
		local ab = {}
		for _, c in centros or {} do
			table.insert(
				ab,
				{ de = c - de0, larg = larg or PORTA, tipo = tipo or "porta", cor = pal_.porta, alt = alt }
			)
		end
		return ab
	end
	-- parede interna ao longo de X (z fixo) ou de Z (x fixo); centros = coordenadas absolutas das portas.
	-- altExtra: sobe a parede além do pé-direito (vãos duplos).
	function K.paredeZ(
		k: number,
		z: number,
		x0: number,
		x1: number,
		centros,
		larg: number?,
		tipo: string?,
		altExtra: number?
	)
		return K.par(
			{ x0, z },
			{ x1, z },
			K.Y(k),
			ALT - 0.9 + (altExtra or 0),
			0.8,
			pal_.interna,
			pal_.matInterna,
			abertas(centros, x0, larg, tipo)
		)
	end
	function K.paredeX(
		k: number,
		x: number,
		z0: number,
		z1: number,
		centros,
		larg: number?,
		tipo: string?,
		altExtra: number?
	)
		return K.par(
			{ x, z0 },
			{ x, z1 },
			K.Y(k),
			ALT - 0.9 + (altExtra or 0),
			0.8,
			pal_.interna,
			pal_.matInterna,
			abertas(centros, z0, larg, tipo)
		)
	end
	-- porta externa (base 0): alt cobre o soco
	function K.portaExt(de: number, larg: number, tipo: string?)
		return { de = de, larg = larg, tipo = tipo or "porta", cor = pal_.porta, alt = K.yb + 7.5 }
	end

	-- laje/piso com topo em Y(k); a de k = 0 é fina (sobre o pad)
	function K.laje(k: number, x0, x1, z0, z1, furos, cor, mat: string?)
		return ctx.piso(
			K.m,
			K.cf,
			if k == 0 then "Piso" else "Laje",
			x0,
			x1,
			z0,
			z1,
			K.Y(k),
			if k == 0 then 0.1 else 0.9,
			cor or pal_.piso,
			mat or pal_.matPiso,
			furos
		)
	end

	-- casca externa do andar k. g: X0,X1,Z0,Z1, portas = {frente=,tras=,oeste=,leste=} (aberturas, `de` desde o início da
	-- parede), res = reservas de janela {centro, meiaLarg}, sem = {frente=true...}, passo, larg, janelaAlt, peitoril
	function K.casca(k: number, g)
		local lados = {
			{ "frente", { g.X0, g.Z0 }, { g.X1, g.Z0 }, g.X1 - g.X0 },
			{ "tras", { g.X0, g.Z1 }, { g.X1, g.Z1 }, g.X1 - g.X0 },
			{ "oeste", { g.X0, g.Z0 }, { g.X0, g.Z1 }, g.Z1 - g.Z0 },
			{ "leste", { g.X1, g.Z0 }, { g.X1, g.Z1 }, g.Z1 - g.Z0 },
		}
		for _, l in lados do
			local nome = l[1]
			local ab, res = {}, {}
			for _, a in (g.portas and g.portas[nome]) or {} do
				table.insert(ab, a)
				table.insert(res, { a.de, a.larg / 2 + 0.5 })
			end
			for _, r in (g.res and g.res[nome]) or {} do
				table.insert(res, r)
			end
			if not (g.sem and g.sem[nome]) then
				for _, j in janelas(l[4], g.passo or 10, g.larg or 4.4, res) do
					j.alt = g.janelaAlt or 3.8
					j.peitoril = K.yb + (g.peitoril or 3.2)
					j.cor = pal_.detalhe
					table.insert(ab, j)
				end
			end
			K.par(l[2], l[3], k * ALT, ALT + K.yb, ESP_EXT, pal_.parede, pal_.matParede, ab)
		end
	end

	-- soco externo (faixa baixa) com cortes nas portas: cortes = { frente = { {x0,x1} } }
	function K.rodape(g, cortes, cor)
		cor = cor or pal_.detalhe
		local h, e = 1.4, 0.4
		local function faixa(nome, cx, cz, sx, sz)
			K.b(nome, cx, h / 2, cz, sx, h, sz, cor, "Concrete", { sombra = false })
		end
		local fx0, fx1 = g.X0 - ESP_EXT / 2 - e, g.X1 + ESP_EXT / 2 + e
		local segs = { { fx0, fx1 } }
		for _, c in (cortes and cortes.frente) or {} do
			local novos = {}
			for _, s in segs do
				if c[2] <= s[1] or c[1] >= s[2] then
					table.insert(novos, s)
				else
					if c[1] > s[1] then
						table.insert(novos, { s[1], c[1] })
					end
					if c[2] < s[2] then
						table.insert(novos, { c[2], s[2] })
					end
				end
			end
			segs = novos
		end
		for _, s in segs do
			faixa("Rodape", (s[1] + s[2]) / 2, g.Z0 - ESP_EXT / 2 - e / 2, s[2] - s[1], e)
		end
		faixa("Rodape", (g.X0 + g.X1) / 2, g.Z1 + ESP_EXT / 2 + e / 2, fx1 - fx0, e)
		faixa("Rodape", g.X0 - ESP_EXT / 2 - e / 2, (g.Z0 + g.Z1) / 2, e, g.Z1 - g.Z0 + 1)
		faixa("Rodape", g.X1 + ESP_EXT / 2 + e / 2, (g.Z0 + g.Z1) / 2, e, g.Z1 - g.Z0 + 1)
	end

	-- parapeito de cobertura plana no topo (Y(n)) + coroamento
	function K.parapeito(g, k: number, altP: number?, cor)
		local y = K.Y(k)
		local a = altP or 3
		cor = cor or pal_.telhado
		local e = 1.2
		local x0, x1, z0, z1 = g.X0, g.X1, g.Z0, g.Z1
		local function p(nome, cx, cz, sx, sz, c, h, yy)
			K.b(nome, cx, yy + h / 2, cz, sx, h, sz, c, "Concrete", { sombra = false })
		end
		p("Parapeito", (x0 + x1) / 2, z0, x1 - x0 + e, e, cor, a, y)
		p("Parapeito", (x0 + x1) / 2, z1, x1 - x0 + e, e, cor, a, y)
		p("Parapeito", x0, (z0 + z1) / 2, e, z1 - z0 - e, cor, a, y)
		p("Parapeito", x1, (z0 + z1) / 2, e, z1 - z0 - e, cor, a, y)
		local c2 = pal_.detalhe
		p("Coroa", (x0 + x1) / 2, z0, x1 - x0 + e + 0.6, e + 0.6, c2, 0.4, y + a)
		p("Coroa", (x0 + x1) / 2, z1, x1 - x0 + e + 0.6, e + 0.6, c2, 0.4, y + a)
		p("Coroa", x0, (z0 + z1) / 2, e + 0.6, z1 - z0 - e, c2, 0.4, y + a)
		p("Coroa", x1, (z0 + z1) / 2, e + 0.6, z1 - z0 - e, c2, 0.4, y + a)
	end

	-- escada reta de Y(k) a Y(k+1): devolve o retângulo (furo da laje de cima)
	function K.escada(k: number, x: number, z: number, dir: string, larg: number)
		return ctx.escada(
			K.m,
			K.cf,
			"Degrau",
			x,
			z,
			dir,
			K.Y(k),
			ALT,
			larg,
			pal_.escada,
			"Concrete",
			{ passada = PASSADA, sombra = false }
		)
	end

	function K.corrimao(k: number, x0, x1, z0, z1)
		local sx, sz = max(x1 - x0, 0.3), max(z1 - z0, 0.3)
		return K.b(
			"Corrimao",
			(x0 + x1) / 2,
			K.Y(k) + 1.6,
			(z0 + z1) / 2,
			sx,
			3.2,
			sz,
			C_METAL,
			"Metal",
			{ sombra = false }
		)
	end

	-- letreiro com texto (SurfaceGui na face da frente); fundo e texto em {r,g,b}
	function K.letreiro(texto: string, cx, cy, cz, sx, sy, corFundo, corTexto, esp: number?)
		local p = K.b("Letreiro", cx, cy, cz, sx, sy, esp or 0.5, corFundo, "SmoothPlastic", { sombra = false })
		pcall(function()
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.Parent = p
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = texto
			t.TextColor3 = ctx.rgb(corTexto)
			t.TextScaled = true
			t.Parent = g
		end)
		return p
	end

	-- mobília: sempre via Mob. dy = altura acima do piso (itens fixos em parede/mesa)
	function K.mov(nome: string, x: number, z: number, rot: number?, k: number, op, dy: number?)
		op = op or {}
		op.rng = op.rng or rng
		return Mob.colocar(ctx, K.m, nome, K.cf, x, K.Y(k) + (dy or 0), z, rot or 0, op)
	end
	function K.naParede(nome: string, lado: string, ao: number, sala, k: number, op, folga: number?, dy: number?)
		local x, z, r = Mob.paraParede(nome, lado, ao, sala, folga)
		return K.mov(nome, x, z, r, k, op, dy)
	end

	-- sala em coordenadas de centro de parede → faces internas
	function K.sala(x0: number, x1: number, z0: number, z1: number)
		return { x0 = x0 + 0.5, x1 = x1 - 0.5, z0 = z0 + 0.5, z1 = z1 - 0.5 }
	end

	function K.loot(x: number, z: number, k: number)
		table.insert(K.loots, { x = x, y = K.Y(k), z = z })
	end

	function K.info(xp: number, zp: number)
		return { loot = K.loots, frente = { xp, -(K.d / 2) - 4 }, portaria = { xp, zp } }
	end

	return K
end

-- ---------------------------------------------------------------------------------------------------------------
-- HOSPITAL 64×44, 2–3 andares. Térreo: hall (recepção) na frente, alas atrás; poço de escada no leste (duas colunas
-- de escada, uma por lance); andares: ala de leitos / centro cirúrgico / UTI + corredor nos fundos.
-- ---------------------------------------------------------------------------------------------------------------
local function hospital(ctx, spec)
	local K = novoK(ctx, spec, "hospital", "hospital", 64, 44, 6)
	local n, pal_, rng = K.n, K.pal, K.rng
	local X0, X1, Z0, Z1 = -30, 30, -18, 20
	local XA, XB, XW = -10, 10, 19.5
	local ZH, ZC = -6, 10
	local planta = rng.inteiro(1, 2)
	local Xe = if planta == 1 then -1 else 3 -- porta de entrada
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6, janelaAlt = 4, peitoril = 3.2 }

	-- lances: par → coluna A (+z), ímpar → coluna B (−z)
	local furos = {}
	for j = 0, n - 2 do
		if j % 2 == 0 then
			furos[j] = K.escada(j, 22.3, -8, "+z", 4.8)
		else
			furos[j] = K.escada(j, 27.1, 9.4, "-z", 4.8)
		end
	end

	K.laje(0, X0, X1, Z0, Z1)
	for k = 1, n do
		local f = if k < n then nil else nil
		K.laje(k, X0, X1, Z0, Z1, if furos[k - 1] then { furos[k - 1] } else nil)
		local _ = f
	end
	for k = 1, n - 1 do
		local f = furos[k - 1]
		if k % 2 == 1 then
			K.corrimao(k, f.x0, f.x1, f.z0 - 0.15, f.z0 + 0.15)
			K.corrimao(k, f.x1 - 0.15, f.x1 + 0.15, f.z0, f.z1)
		else
			K.corrimao(k, f.x0, f.x1, f.z1 - 0.15, f.z1 + 0.15)
			K.corrimao(k, f.x0 - 0.15, f.x0 + 0.15, f.z0, f.z1)
		end
	end

	-- ---------- salas (funções de mobiliar) -----------
	local function zf(sala, lado: string, t: number): number -- t = distância da parede do fundo para dentro
		return if lado == "z0" then sala.z1 - t else sala.z0 + t
	end
	local function leitos(sala, k, lado)
		for i = 0, 1 do
			K.naParede("cama_hospital", "-x", zf(sala, lado, 1.9 + i * 6.2), sala, k)
		end
		K.mov("cortina_hospital", sala.x0 + 3.7, zf(sala, lado, 5), 0, k)
		K.loot((sala.x0 + sala.x1) / 2 + 2, zf(sala, lado, 20.5), k)
	end
	local function triagem(sala, k, lado)
		K.naParede("maca_hospital", "-x", zf(sala, lado, 4), sala, k)
		local zm = zf(sala, lado, 1.6)
		local cx = (sala.x0 + sala.x1) / 2
		K.mov("mesa_escritorio", cx, zm, if lado == "z0" then 0 else pi, k)
		K.mov("computador", cx, zm, if lado == "z0" then 0 else pi, k, nil, 2.7)
		K.mov("cadeira_escritorio", cx, zf(sala, lado, 4.4), if lado == "z0" then pi else 0, k)
		K.loot(cx + 3.5, zf(sala, lado, 15), k)
	end
	local function cirurgia(sala, k, lado)
		local cx = (sala.x0 + sala.x1) / 2
		for _, dx in { -4.5, 4.5 } do
			K.mov("mesa_cirurgia", cx + dx, zf(sala, lado, 9), 0, k)
		end
		for _, dx in { -6.5, 6.5 } do
			K.naParede("armario_medico", if lado == "z0" then "+z" else "-z", cx + dx, sala, k)
		end
		K.loot(cx + 6, zf(sala, lado, 19.5), k)
	end
	local function uti(sala, k, lado)
		K.naParede("cama_hospital", "-x", zf(sala, lado, 3.5), sala, k)
		K.naParede("maca_hospital", "-x", zf(sala, lado, 11), sala, k)
	end
	local function farmacia(sala, k, lado)
		local op = { d = 1.8 }
		K.naParede("balcao_loja", "-x", zf(sala, lado, 9), sala, k, op)
		K.naParede("armario_medico", "+x", zf(sala, lado, 2), sala, k)
		K.naParede("armario_medico", if lado == "z0" then "+z" else "-z", sala.x0 + 4, sala, k)
		K.loot((sala.x0 + sala.x1) / 2 + 1.5, zf(sala, lado, 15), k)
	end

	-- ---------- térreo ----------
	g.portas = { frente = { K.portaExt(Xe - X0, 7) } }
	g.res = {
		tras = { { XA - X0, 1 }, { XB - X0, 1 }, { XW - X0, 1 } },
		oeste = { { ZH - Z0, 1 } },
		frente = {},
	}
	K.casca(0, g)
	K.paredeZ(0, ZH, X0, XW, { -20, 0, 14.75 })
	K.paredeX(0, XA, ZH, Z1)
	K.paredeX(0, XB, ZH, Z1)
	K.paredeX(0, XW, Z0, Z1, { -13 })

	local hall = K.sala(X0, XW, Z0, ZH)
	K.mov("balcao_recepcao", -13, -11.8, 0, 0)
	K.mov("computador", -15.5, -11.8, pi, 0, nil, 3.6)
	K.naParede("sofa_recepcao", "-z", -24, hall, 0)
	K.naParede("sofa_recepcao", "-z", Xe + 10.5, hall, 0)
	K.mov("cadeira_rodas", -27.5, -8.6, 0.5, 0)
	K.naParede("bebedouro", "-x", -15.5, hall, 0)
	K.mov("planta_vaso", Xe - 7.5, -16.4, 0, 0)
	K.loot(-5, -14, 0)

	local ordem = if planta == 1 then { "leitos", "triagem" } else { "triagem", "leitos" }
	local salasT = { leitos = leitos, triagem = triagem }
	salasT[ordem[1]](K.sala(X0, XA, ZH, Z1), 0, "z0")
	salasT[ordem[2]](K.sala(XA, XB, ZH, Z1), 0, "z0")
	farmacia(K.sala(XB, XW, ZH, Z1), 0, "z0")

	-- ---------- andares ----------
	for k = 1, n - 1 do
		local ultimo = k == n - 1
		local gk = {
			X0 = X0,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			janelaAlt = 4,
			peitoril = 3.2,
			res = {
				frente = { { XA - X0, 1 }, { XB - X0, 1 }, { XW - X0, 1 } },
				tras = { { XW - X0, 1 } },
				oeste = { { ZC - Z0, 1 } },
			},
		}
		K.casca(k, gk)
		K.paredeZ(k, ZC, X0, XW, { -20, 0, 14.75 })
		K.paredeX(k, XA, Z0, ZC)
		K.paredeX(k, XB, Z0, ZC)
		K.paredeX(k, XW, Z0, Z1, { 16 })
		local corr = K.sala(X0, XW, ZC, Z1)
		K.mov("cadeira_rodas", -26.5, 18.3, pi, k)
		local _ = corr
		K.loot(-13, 14.5, k)
		local meio = if ultimo then cirurgia else leitos
		local oeste = if planta == 1 then leitos else triagem
		oeste(K.sala(X0, XA, Z0, ZC), k, "z1")
		meio(K.sala(XA, XB, Z0, ZC), k, "z1")
		if not (n == 3 and k == 2) then
			uti(K.sala(XB, XW, Z0, ZC), k, "z1")
		end
	end

	-- ---------- fachada, marquise, cruz, cobertura ----------
	K.rodape(g, { frente = { { Xe - 4, Xe + 4 } } })
	K.parapeito(g, n, 3)
	K.letreiro("HOSPITAL", Xe, K.Y(n) + 1.5, Z0 - 0.9, 22, 2.6, { 56, 60, 62 }, { 230, 230, 226 }, 0.4)
	-- marquise de ambulância
	local ym = 9.6
	K.b("Marquise", Xe, ym, -20, 18, 0.5, 4, pal_.detalhe, "Concrete", { sombra = false })
	K.b("Marquise", Xe, ym + 0.5, -21.9, 18, 1, 0.3, pal_.acento, "Concrete", { sombra = false })
	for _, dx in { -8, 8 } do
		K.b("Pilar", Xe + dx, ym / 2, -21.4, 1, ym, 1, pal_.detalhe, "Concrete")
	end
	K.letreiro("URGENCIA", Xe, ym + 0.5, -22.1, 12, 0.9, { 150, 40, 40 }, { 238, 232, 228 }, 0.15)
	-- cruz de neon no 1º andar da fachada (sobre a marquise)
	if n >= 2 then
		K.b("PlacaCruz", Xe, 19, Z0 - 0.7, 12, 10, 0.4, { 200, 200, 196 }, "Concrete", { sombra = false })
		K.b(
			"Cruz",
			Xe,
			19,
			Z0 - 1,
			8,
			2.4,
			0.3,
			pal_.acento,
			"Neon",
			{ colide = false, consulta = false, sombra = false }
		)
		K.b(
			"Cruz",
			Xe,
			19,
			Z0 - 1,
			2.4,
			8,
			0.3,
			pal_.acento,
			"Neon",
			{ colide = false, consulta = false, sombra = false }
		)
	end
	-- heliponto e equipamentos no telhado
	local yt = K.Y(n)
	K.cil("Heliponto", -14, yt + 0.1, 3, 18, 0.2, { 70, 74, 76 }, "Concrete", { sombra = false, consulta = false })
	K.b(
		"H",
		-14 - 2.4,
		yt + 0.25,
		3,
		1.2,
		0.1,
		7,
		{ 220, 214, 150 },
		"Concrete",
		{ colide = false, consulta = false, sombra = false }
	)
	K.b(
		"H",
		-14 + 2.4,
		yt + 0.25,
		3,
		1.2,
		0.1,
		7,
		{ 220, 214, 150 },
		"Concrete",
		{ colide = false, consulta = false, sombra = false }
	)
	K.b(
		"H",
		-14,
		yt + 0.25,
		3,
		4.8,
		0.1,
		1.2,
		{ 220, 214, 150 },
		"Concrete",
		{ colide = false, consulta = false, sombra = false }
	)
	K.b("CasaMaquinas", 4, yt + 2.2, 14, 9, 4.4, 7, pal_.parede, "Concrete")
	K.b("Exaustor", 14, yt + 1.1, 12, 3, 2.2, 3, { 120, 122, 120 }, "Metal")
	K.cil("CaixaDagua", 24, yt + 2.8, 14, 5, 5.6, { 110, 112, 110 }, "Metal")
	K.cil("Antena", 8, yt + 6, 2, 0.5, 12, C_METAL, "Metal", { sombra = false })
	-- placa da escada no telhado (saída)
	K.b("CasaEscada", 24.7, yt + 2.2, 0, 10.4, 4.4, 14, pal_.parede, "Concrete", { colide = true })

	return K.m, K.info(Xe, Z0)
end
M.catalogo.hospital = { paletas = PAL.hospital, construir = hospital }

-- ---------------------------------------------------------------------------------------------------------------
-- DELEGACIA 44×34, 1–2 andares. Térreo: recepção/baias na frente; celas, arsenal e sala dos fundos. Andar: dormitório,
-- reunião, gabinete e corredor. Escada no leste (só com 2 andares).
-- ---------------------------------------------------------------------------------------------------------------
local function delegacia(ctx, spec)
	local K = novoK(ctx, spec, "delegacia", "delegacia", 44, 34, 3)
	local n, pal_ = K.n, K.pal
	local X0, X1, Z0, Z1 = -20, 20, -14, 16
	local XE = if n == 2 then 14 else 20
	local XA, XB, ZR, ZC = -3, 6, -2, 9.5
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6 }
	local f = if n == 2 then K.escada(0, 16.95, -5, "+z", 5) else nil

	K.laje(0, X0, X1, Z0, Z1)
	for k = 1, n do
		K.laje(k, X0, X1, Z0, Z1, if k == 1 and f then { f } else nil)
	end
	if f then
		K.corrimao(1, f.x0, f.x1, f.z0 - 0.15, f.z0 + 0.15)
	end

	-- térreo
	g.portas = { frente = { K.portaExt(0 - X0, 6) } }
	g.res = {
		tras = { { XA - X0, 1 }, { XB - X0, 1 }, { XE - X0, 1 } },
		oeste = { { ZR - Z0, 1 } },
		frente = if n == 2 then { { XE - X0, 1 } } else {},
	}
	K.casca(0, g)
	K.paredeZ(0, ZR, X0, XE, { -11, 1.5, (XB + XE) / 2 })
	K.paredeX(0, XA, ZR, Z1)
	K.paredeX(0, XB, ZR, Z1)
	if n == 2 then
		K.paredeX(0, XE, Z0, Z1, { -10 })
	end

	local hall = K.sala(X0, XE, Z0, ZR)
	K.mov("balcao_recepcao", -13.5, -6.5, 0, 0)
	K.naParede("sofa_recepcao", "-z", -14, hall, 0)
	K.mov("mesa_delegacia", 8.5, -8.5, 0, 0)
	K.mov("cadeira_escritorio", 8.5, -6.2, 0, 0)
	K.loot(-4, -10, 0)
	if n == 1 then
		K.mov("mesa_delegacia", 15, -8.5, 0, 0)
		K.loot(17, -4.2, 0)
	else
		K.loot(4.5, -11, 0)
	end
	local celas = K.sala(X0, XA, ZR, Z1)
	K.mov("cela_grade", -15.4, celas.z1 - 4.1, 0, 0)
	K.mov("cela_grade", -7.4, celas.z1 - 4.1, 0, 0)
	K.loot(-11, 3, 0)
	local arsenal = K.sala(XA, XB, ZR, Z1)
	K.naParede("armario_armas", "+z", -0.6, arsenal, 0)
	K.naParede("armario_armas", "+z", 3.4, arsenal, 0)
	K.loot(1.5, 4, 0)
	local sala3 = K.sala(XB, XE, ZR, Z1)
	local cx3 = (sala3.x0 + sala3.x1) / 2
	K.mov("mesa_delegacia", cx3, 9, 0, 0)
	K.mov("cadeira_escritorio", cx3, 11.4, pi, 0)
	K.loot(cx3, 3.5, 0)
	if n == 1 then
		K.loot(cx3 + 4, 11.5, 0)
	end

	if n == 2 then
		local g1 = {
			X0 = X0,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			res = {
				frente = { { XA - X0, 1 }, { XB - X0, 1 }, { XE - X0, 1 } },
				tras = { { XE - X0, 1 } },
				oeste = { { ZC - Z0, 1 } },
			},
		}
		K.casca(1, g1)
		K.paredeZ(1, ZC, X0, XE, { -11, 1.5, 10 })
		K.paredeX(1, XA, Z0, ZC)
		K.paredeX(1, XB, Z0, ZC)
		K.paredeX(1, XE, Z0, Z1, { 12.5 })
		local dorm = K.sala(X0, XA, Z0, ZC)
		K.naParede("beliche", "-x", -6, dorm, 1)
		K.naParede("guarda_roupa", "+x", -8, dorm, 1)
		K.loot(-10, 3, 1)
		local reu = K.sala(XA, XB, Z0, ZC)
		K.mov("mesa_reuniao", 1.5, -3, 0, 1, { w = 6 })
		K.naParede("quadro_branco", "-z", 1.5, reu, 1, nil, nil, 4.5)
		K.loot(1.5, 5.5, 1)
		K.mov("mesa_escritorio", 10, -7, 0, 1)
		K.loot(10, 4, 1)
		K.loot(-12, 13, 1)
	end

	-- fachada
	K.rodape(g, { frente = { { -3.6, 3.6 } } })
	K.parapeito(g, n, 3)
	K.letreiro("DELEGACIA", 0, K.Y(n) + 1.5, Z0 - 0.9, 20, 2.6, { 30, 40, 70 }, { 226, 228, 232 }, 0.4)
	K.b("Marquise", 0, 9.2, -15.5, 14, 0.5, 3, pal_.detalhe, "Concrete", { sombra = false })
	for _, dx in { -6.5, 6.5 } do
		K.b("Pilar", dx, 4.6, -16.2, 0.9, 9.2, 0.9, pal_.detalhe, "Concrete")
	end
	K.b(
		"Lampada",
		0,
		10.6,
		-14.7,
		2.4,
		1.4,
		0.8,
		pal_.acento,
		"Neon",
		{ colide = false, consulta = false, sombra = false }
	)
	K.cil("Mastro", 14, 7.1, -15.5, 0.4, 14.2, C_METAL, "Metal", { sombra = false })
	K.b(
		"Bandeira",
		14,
		12.6,
		-15.5,
		0.1,
		2,
		3.4,
		{ 120, 60, 56 },
		"Fabric",
		{ colide = false, consulta = false, sombra = false }
	)
	local yt = K.Y(n)
	K.b("ArCondicionado", 10, yt + 1.2, 6, 4, 2.4, 3, { 120, 122, 120 }, "Metal")
	K.b("ArCondicionado", -8, yt + 1.2, 6, 4, 2.4, 3, { 120, 122, 120 }, "Metal")
	return K.m, K.info(0, Z0)
end
M.catalogo.delegacia = { paletas = PAL.delegacia, construir = delegacia }

-- ---------------------------------------------------------------------------------------------------------------
-- BOMBEIROS 52×40, 1–2 andares. Garagem alta à esquerda com dois portões abertos, caminhão e van; bloco leste com
-- escritório, cozinha, dormitório (térreo ou andar); torre de mangueiras sobre o canto da garagem.
-- ---------------------------------------------------------------------------------------------------------------
local function bombeiros(ctx, spec)
	local K = novoK(ctx, spec, "bombeiros", "bombeiros", 52, 40, 4)
	local n, pal_, rng = K.n, K.pal, K.rng
	local X0, X1, Z0, Z1 = -24, 24, -17, 18
	local XG = 4
	local XE = if n == 2 then 18 else 24
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6 }
	local f = if n == 2 then K.escada(0, 20.95, -8, "+z", 5) else nil

	K.laje(0, X0, X1, Z0, Z1)
	K.laje(1, X0, X1, Z0, Z1, if f then { f } else nil)
	if n == 2 then
		K.laje(2, XG, X1, Z0, Z1)
		K.corrimao(1, f.x0, f.x1, f.z0 - 0.15, f.z0 + 0.15)
	end

	-- portões abertos (vãos de 10 × 10,5) com rolo enrolado em cima
	g.portas = { frente = {} }
	for _, x in { -15, -3 } do
		local ab = K.portaExt(x - X0, 10, "vao")
		ab.alt = 10.5
		table.insert(g.portas.frente, ab)
		K.cil(
			"Rolo",
			x,
			11.3,
			Z0 + 0.9,
			1.2,
			10,
			{ 130, 130, 126 },
			"Metal",
			{ eixo = "x", consulta = false, sombra = false }
		)
	end
	g.res = {
		tras = { { XG - X0, 1 }, { XE - X0, 1 } },
		leste = { { -4 - Z0, 1 }, { 8 - Z0, 1 } },
		frente = { { XG - X0, 1 }, { XE - X0, 1 } },
	}
	K.casca(0, g)
	K.paredeX(0, XG, Z0, Z1, { -10, 2, 13 })
	K.paredeZ(0, -4, XG, XE, nil)
	K.paredeZ(0, 8, XG, XE, nil)
	if n == 2 then
		K.paredeX(0, XE, Z0, Z1, { -11 })
	end

	-- garagem
	local gar = K.sala(X0, XG, Z0, Z1)
	K.naParede("bancada_ferramentas", "-x", 12, gar, 0)
	K.naParede("prateleira_garagem", "+z", -9, gar, 0)
	K.mov("pilha_pneus", -2, 15.5, 0, 0)
	K.loot(-21, 17, 0)
	K.loot(0, 12, 0)
	Props.caminhao(ctx, K.m, K.cf * CFrame.new(-15, K.yb, 0), { cor = { 150, 40, 36 }, rng = rng })
	Props.carro(ctx, K.m, K.cf * CFrame.new(-3, K.yb, 4), { variante = 4, cor = { 150, 52, 44 }, rng = rng })

	-- escritório, cozinha, dormitório
	local r1 = K.sala(XG, XE, Z0, -4)
	K.mov("mesa_escritorio", (r1.x0 + r1.x1) / 2, -11, 0, 0)
	K.naParede("arquivo", "+x", -6.5, r1, 0)
	K.loot(r1.x0 + 3, -13, 0)
	local r2 = K.sala(XG, XE, -4, 8)
	K.naParede("geladeira", "+x", 5.5, r2, 0)
	K.naParede("fogao", "+x", 2.4, r2, 0)
	K.mov("mesa_jantar", r2.x0 + 6.5, 1, 0, 0)
	K.loot(r2.x0 + 3, 5.5, 0)
	local r3 = K.sala(XG, XE, 8, Z1)
	K.naParede("beliche", "+z", r3.x0 + 4, r3, 0)
	K.naParede("beliche", "+z", r3.x0 + 8, r3, 0)
	K.loot(r3.x0 + 6, 9.6, 0)

	if n == 2 then
		local g1 = {
			X0 = XG,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			res = {
				frente = { { XE - XG, 1 } },
				tras = { { XE - XG, 1 } },
				oeste = { { 4 - Z0, 1 } },
			},
		}
		K.casca(1, g1)
		K.paredeZ(1, 4, XG, XE, { 11 })
		K.paredeX(1, XE, Z0, Z1, { 12 })
		local dorm = K.sala(XG, XE, Z0, 4)
		K.naParede("beliche", "-x", -12, dorm, 1)
		K.naParede("beliche", "-x", -6, dorm, 1)
		K.naParede("guarda_roupa", "+x", -10, dorm, 1)
		K.loot(11, -6, 1)
		local estar = K.sala(XG, XE, 4, Z1)
		K.naParede("sofa", "+z", 10, estar, 1)
		K.loot(14, 9, 1)
	end

	-- torre de mangueiras sobre o canto de fundo da garagem
	local y1 = K.Y(1)
	K.b("Torre", -19.5, y1 + 9, 13, 8, 18, 8, pal_.parede, pal_.matParede)
	K.b("TorreCornija", -19.5, y1 + 18.3, 13, 9.2, 0.7, 9.2, pal_.detalhe, "Concrete", { sombra = false })
	for _, dy in { 5, 11 } do
		K.b(
			"TorreJanela",
			-19.5,
			y1 + dy,
			13 - 4.05,
			1.6,
			3,
			0.2,
			{ 20, 24, 28 },
			"Glass",
			{ consulta = false, sombra = false }
		)
	end
	K.b("TorreTopo", -19.5, y1 + 19.6, 13, 6, 1.8, 6, pal_.telhado, "Concrete")
	K.cil("Sirene", -19.5, y1 + 21.4, 13, 1.6, 1.8, pal_.acento, "Metal", { sombra = false })

	-- fachada
	K.rodape(g, { frente = { { -20, -10 }, { -8, 2 } } })
	if n == 2 then
		K.parapeito({ X0 = X0, X1 = XG, Z0 = Z0, Z1 = Z1 }, 1, 3)
		K.parapeito({ X0 = XG, X1 = X1, Z0 = Z0, Z1 = Z1 }, 2, 3)
	else
		K.parapeito(g, 1, 3)
	end
	K.letreiro("BOMBEIROS", -9, y1 + 1.5, Z0 - 0.9, 24, 2.6, pal_.acento, { 236, 232, 224 }, 0.4)
	return K.m, K.info(-9, Z0)
end
M.catalogo.bombeiros = { paletas = PAL.bombeiros, construir = bombeiros }

-- empena em degraus (triângulo de blocos) para frontões e oitões: eixo "x" = plano perpendicular a X
local function empena(
	K,
	cx,
	cy,
	cz,
	largBase: number,
	alt: number,
	passos: number,
	esp: number,
	cor,
	mat: string,
	eixoX: boolean
)
	local h = alt / passos
	for i = 1, passos do
		local wd = largBase * (1 - (i - 0.5) / passos)
		local y = cy + (i - 0.5) * h
		if eixoX then
			K.b("Empena", cx, y, cz, esp, h, wd, cor, mat, { sombra = false })
		else
			K.b("Empena", cx, y, cz, wd, h, esp, cor, mat, { sombra = false })
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- ESCOLA 60×40, 1–2 andares. Corredor E–W; salas de aula na frente (hall central), nos fundos: sala/escadaria, refeitório
-- e quadra coberta (vazada no 2º andar).
-- ---------------------------------------------------------------------------------------------------------------
local function escola(ctx, spec)
	local K = novoK(ctx, spec, "escola", "escola", 60, 40, 4)
	local n, pal_ = K.n, K.pal
	local X0, X1, Z0, Z1 = -28, 28, -16, 19
	local ZF, ZR = -5, 4
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6 }
	local quadra = { x0 = 6.4, x1 = 28, z0 = 4.4, z1 = 19 }
	local f = if n == 2 then K.escada(0, -27.2, 11.8, "+x", 5) else nil

	K.laje(0, X0, X1, Z0, Z1)
	for k = 1, n do
		local furos = nil
		if k == 1 and n == 2 then
			furos = { f, quadra }
		end
		K.laje(k, X0, X1, Z0, Z1, furos)
	end
	if f then
		K.corrimao(1, f.x0, f.x0 + 8, f.z0 - 0.15, f.z0 + 0.15)
		K.corrimao(1, f.x0, f.x0 + 8, f.z1 - 0.15, f.z1 + 0.15)
	end

	local function aula(sala, k, lousa: string, portaZ1: boolean, loot: boolean)
		local cz = (sala.z0 + sala.z1) / 2
		K.naParede("lousa", lousa, cz, sala, k, nil, nil, 4)
		local dir = if lousa == "+x" then -1 else 1
		local xw = if lousa == "+x" then sala.x1 else sala.x0
		local dp = if portaZ1 then 1 else -1
		K.mov("mesa_professor", xw + dir * 3, cz, if lousa == "+x" then pi / 2 else -pi / 2, k)
		for _, dist in { 6, 8.6 } do
			for _, dz in { 2.9, 0.1 } do
				K.mov("carteira_escolar", xw + dir * dist, cz - dp * dz, if lousa == "+x" then -pi / 2 else pi / 2, k)
			end
		end
		if loot then
			K.loot(xw + dir * 5.5, cz + dp * 3.8, k)
		end
	end

	-- térreo
	g.portas = { frente = { K.portaExt(0 - X0, 6) } }
	g.res = {
		frente = { { -17 - X0, 1 }, { -6 - X0, 1 }, { 6 - X0, 1 }, { 17 - X0, 1 } },
		tras = { { -12 - X0, 1 }, { 6 - X0, 1 } },
		oeste = { { ZF - Z0, 1 }, { ZR - Z0, 1 } },
		leste = { { ZF - Z0, 1 }, { ZR - Z0, 1 } },
	}
	K.casca(0, g)
	-- hall central aberto para o corredor (sem parede entre -6 e 6)
	K.paredeZ(0, ZF, X0, -6, { -22.5, -11.5 })
	K.paredeZ(0, ZF, 6, X1, { 11.5, 22.5 })
	K.paredeZ(0, ZR, X0, 6, { -20, -3 })
	K.paredeZ(0, ZR, 6, X1, { 17 }, nil, nil, if n == 2 then ALT else 0)
	for _, x in { -17, -6, 6, 17 } do
		K.paredeX(0, x, Z0, ZF)
	end
	K.paredeX(0, -12, ZR, Z1)
	K.paredeX(0, 6, ZR, Z1, nil, nil, nil, if n == 2 then ALT else 0)

	local hall = K.sala(-6, 6, Z0, ZF)
	K.naParede("bebedouro", "-x", -10, hall, 0)
	K.mov("planta_vaso", 4, -14, 0, 0)
	aula(K.sala(-17, -6, Z0, ZF), 0, "-x", true, true)
	aula(K.sala(6, 17, Z0, ZF), 0, "+x", true, true)
	aula(K.sala(-28, -17, Z0, ZF), 0, "+x", true, false)
	aula(K.sala(17, 28, Z0, ZF), 0, "-x", true, false)
	if n == 1 then
		aula(K.sala(-28, -12, ZR, Z1), 0, "+x", false, false)
	end

	local ref = K.sala(-12, 6, ZR, Z1)
	K.naParede("geladeira", "+z", -9, ref, 0)
	K.naParede("fogao", "+z", -6, ref, 0)
	K.mov("mesa_jantar", -7, 10, 0, 0)
	K.mov("mesa_jantar", 0, 10, 0, 0)
	K.loot(4.2, 6.5, 0)

	-- quadra coberta: linhas, tabelas, arquibancada
	local yq = K.Y(0)
	local cor = { 190, 188, 176 }
	local op = { colide = false, consulta = false, sombra = false }
	K.b("QuadraLinha", 17, yq + 0.04, 6, 18, 0.06, 0.4, cor, "Concrete", op)
	K.b("QuadraLinha", 17, yq + 0.04, 16, 18, 0.06, 0.4, cor, "Concrete", op)
	K.b("QuadraLinha", 8.2, yq + 0.04, 11, 0.4, 0.06, 10, cor, "Concrete", op)
	K.b("QuadraLinha", 25.8, yq + 0.04, 11, 0.4, 0.06, 10, cor, "Concrete", op)
	K.b("QuadraLinha", 17, yq + 0.04, 11, 0.4, 0.06, 10, cor, "Concrete", op)
	for _, x in { 7.2, 26.8 } do
		K.b("TabelaPoste", x, yq + 4, 11, 0.5, 8, 0.5, C_METAL, "Metal")
		K.b("Tabela", x + (if x < 17 then 0.9 else -0.9), yq + 8, 11, 0.3, 3, 4.4, { 200, 200, 196 }, "SmoothPlastic")
	end
	for i, d in { 3, 2, 1 } do
		K.b(
			"Arquibancada",
			17,
			yq + i / 2 * 1 + 0.0,
			Z1 - 0.5 - d / 2,
			16,
			i,
			d,
			{ 110, 84, 60 },
			"WoodPlanks",
			{ sombra = false }
		)
	end
	K.loot(17, 11, 0)

	-- andar
	if n == 2 then
		local g1 = {
			X0 = X0,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			res = {
				frente = { { -17 - X0, 1 }, { -6 - X0, 1 }, { 6 - X0, 1 }, { 17 - X0, 1 } },
				tras = { { -12 - X0, 1 }, { 6 - X0, 1 } },
				oeste = { { ZF - Z0, 1 }, { ZR - Z0, 1 } },
				leste = { { ZF - Z0, 1 }, { ZR - Z0, 1 } },
			},
		}
		K.casca(1, g1)
		K.paredeZ(1, ZF, X0, -6, { -22.5, -11.5 })
		K.paredeZ(1, ZF, 6, X1, { 11.5, 22.5 })
		K.paredeZ(1, ZR, X0, 6, { -20, -3 })
		for _, x in { -17, -6, 6, 17 } do
			K.paredeX(1, x, Z0, ZF)
		end
		K.paredeX(1, -12, ZR, Z1)
		aula(K.sala(-28, -17, Z0, ZF), 1, "+x", true, false)
		aula(K.sala(-17, -6, Z0, ZF), 1, "-x", true, true)
		local sp = K.sala(6, 17, Z0, ZF)
		K.mov("mesa_escritorio", 11.5, -11, 0, 1)
		K.naParede("estante_biblioteca", "+x", -10, sp, 1)
		K.loot(11.5, -8, 1)
		K.mov("mesa_jantar", 0, -11, 0, 1)
		K.mov("mesa_jantar", 0, 10, 0, 1)
	end

	-- fachada
	K.rodape(g, { frente = { { -3.6, 3.6 } } })
	K.parapeito(g, n, 3)
	K.letreiro("ESCOLA MUNICIPAL", 0, 10.6, Z0 - 0.7, 16, 2, pal_.acento, { 236, 232, 222 }, 0.3)
	K.b("Marquise", 0, 9.4, -17.2, 12, 0.5, 2.4, pal_.detalhe, "Concrete", { sombra = false })
	for _, dx in { -5.5, 5.5 } do
		K.b("Pilar", dx, 4.7, -18, 0.9, 9.4, 0.9, pal_.detalhe, "Concrete")
	end
	K.cil("Mastro", 12, 7.1, -17.5, 0.4, 14.2, C_METAL, "Metal", { sombra = false })
	K.b(
		"Bandeira",
		12,
		12.6,
		-17.5,
		0.1,
		2,
		3.4,
		{ 70, 100, 80 },
		"Fabric",
		{ colide = false, consulta = false, sombra = false }
	)
	K.b("Sino", -20, K.Y(n) + 2.5, -4, 2.4, 5, 2.4, pal_.detalhe, "Concrete")
	return K.m, K.info(0, Z0)
end
M.catalogo.escola = { paletas = PAL.escola, construir = escola }

-- ---------------------------------------------------------------------------------------------------------------
-- PREFEITURA 56×40, 2–3 andares. Sobre soco de 2,7 com escadaria e pórtico de colunas; hall central com colunas,
-- gabinetes nas alas, salão com relógio; escadas nas salas dos fundos das alas; torre de relógio no telhado.
-- ---------------------------------------------------------------------------------------------------------------
local function prefeitura(ctx, spec)
	local YB = 2.7
	local K = novoK(ctx, spec, "prefeitura", "prefeitura", 56, 40, 12, YB)
	local n, pal_ = K.n, K.pal
	local X0, X1, Z0, Z1 = -26, 26, -11, 18
	local XL, XR = -10, 10
	local ZW = 3
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6, janelaAlt = 4.4 }

	-- soco, porta e escadaria
	K.b("Soco", 0, (YB - 0.1) / 2, (Z0 + Z1) / 2, X1 - X0 + 1, YB - 0.1, Z1 - Z0 + 1, pal_.detalhe, "Concrete")
	K.b("Patamar", 0, (YB - 0.1) / 2, -13.7, 32, YB - 0.1, 5, pal_.detalhe, "Concrete")
	K.b("Degrau", 0, 0.9 / 2, -17.3, 22, 0.9, 1.6, pal_.detalhe, "Concrete")
	K.b("Degrau", 0, 1.8 / 2, -15.9, 22, 1.8, 1.6, pal_.detalhe, "Concrete")

	local furos = {}
	for j = 0, n - 2 do
		if j % 2 == 0 then
			furos[j] = K.escada(j, 10.9, 11.8, "+x", 5)
		else
			furos[j] = K.escada(j, -10.9, 11.8, "-x", 5)
		end
	end
	K.laje(0, X0, X1, Z0, Z1)
	for k = 1, n do
		K.laje(k, X0, X1, Z0, Z1, if furos[k - 1] then { furos[k - 1] } else nil)
	end
	for k = 1, n - 1 do
		local f = furos[k - 1]
		if k % 2 == 1 then
			K.corrimao(k, f.x0, f.x0 + 8, f.z0 - 0.15, f.z0 + 0.15)
			K.corrimao(k, f.x0, f.x0 + 8, f.z1 - 0.15, f.z1 + 0.15)
		else
			K.corrimao(k, f.x1 - 8, f.x1, f.z0 - 0.15, f.z0 + 0.15)
			K.corrimao(k, f.x1 - 8, f.x1, f.z1 - 0.15, f.z1 + 0.15)
		end
	end

	-- térreo
	g.portas = { frente = { K.portaExt(0 - X0, 7) } }
	g.res = {
		frente = { { XL - X0, 1 }, { XR - X0, 1 } },
		tras = { { XL - X0, 1 }, { XR - X0, 1 } },
		oeste = { { ZW - Z0, 1 } },
		leste = { { ZW - Z0, 1 } },
	}
	K.casca(0, g)
	K.paredeX(0, XL, Z0, Z1, { -4, 6 })
	K.paredeX(0, XR, Z0, Z1, { -4, 6 })
	K.paredeZ(0, ZW, X0, XL)
	K.paredeZ(0, ZW, XR, X1)
	local hall = K.sala(XL, XR, Z0, Z1)
	for _, p in { { -5.5, -3 }, { 5.5, -3 }, { -5.5, 6 }, { 5.5, 6 } } do
		K.cil("Coluna", p[1], YB + 5.5, p[2], 1.6, 11, pal_.detalhe, "Marble")
	end
	K.naParede("relogio_pe", "+z", 0, hall, 0)
	K.mov("sofa_recepcao", 0, 0, pi, 0)
	K.loot(-1, -7, 0)
	local gab1 = K.sala(X0, XL, Z0, ZW)
	K.mov("mesa_escritorio", -18, -3, 0, 0)
	K.mov("cadeira_escritorio", -18, -0.6, 0, 0)
	K.naParede("arquivo_alto", "-x", -7, gab1, 0)
	K.loot(-22, -7, 0)
	local gab2 = K.sala(X0, XL, ZW, Z1)
	K.naParede("arquivo_alto", "+z", -22, gab2, 0)
	K.naParede("arquivo_alto", "+z", -18, gab2, 0)
	K.mov("mesa_escritorio", -18, 9, 0, 0)
	K.loot(-22, 8, 0)
	local gab3 = K.sala(XR, X1, Z0, ZW)
	K.mov("mesa_reuniao", 18, -4, 0, 0, { w = 9 })
	K.naParede("quadro_branco", "-z", 18, gab3, 0, nil, nil, 4.5)
	K.loot(15, 0, 0)

	-- andares
	for k = 1, n - 1 do
		local gk = {
			X0 = X0,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			janelaAlt = 4.4,
			res = g.res,
		}
		gk.res = {
			frente = { { XL - X0, 1 }, { XR - X0, 1 } },
			tras = { { XL - X0, 1 }, { XR - X0, 1 } },
			oeste = { { ZW - Z0, 1 } },
			leste = { { ZW - Z0, 1 } },
		}
		K.casca(k, gk)
		K.paredeX(k, XL, Z0, Z1, { -4, 6 })
		K.paredeX(k, XR, Z0, Z1, { -4, 6 })
		K.paredeZ(k, ZW, X0, XL)
		K.paredeZ(k, ZW, XR, X1)
		K.mov("mesa_reuniao", 0, -2, 0, k, { w = 12 })
		K.loot(-3, 6, k)
		K.mov("mesa_escritorio", -18, -4, 0, k)
		K.mov("cadeira_escritorio", -18, -1.6, 0, k)
		K.mov("mesa_escritorio", 18, -4, 0, k)
		K.naParede("estante_livros", "+z", 16, K.sala(XR, X1, ZW, Z1), k)
		if k == 1 then
			K.naParede("arquivo_alto", "+z", -22, K.sala(X0, XL, ZW, Z1), k)
		end
		if k >= 1 and k % 2 == 0 then
			K.naParede("arquivo_alto", "+z", 22, K.sala(XR, X1, ZW, Z1), k)
		end
	end

	-- pórtico: colunas, friso, frontão
	for _, x in { -12, -6, 6, 12 } do
		K.cil("ColunaPortico", x, YB + 6, -14.3, 2, 12, pal_.detalhe, "Marble")
	end
	K.b("Friso", 0, YB + 12.6, -13.7, 33, 1.2, 5.6, pal_.detalhe, "Concrete")
	K.letreiro("PREFEITURA", 0, YB + 12.6, -16.55, 14, 1.0, { 60, 56, 50 }, { 226, 222, 210 }, 0.2)
	empena(K, 0, YB + 13.2, -16.2, 30, 4.2, 4, 0.8, pal_.detalhe, "Concrete", false)
	ctx.telhadoDuasAguas(K.m, K.cf, "Frontao", 0, -13.7, 31, 5.6, YB + 13.2, 4.4, 0.3, 0.5, pal_.telhado, "Slate", true)

	-- cobertura e torre do relógio
	K.rodape(g, { frente = { { -4, 4 } } }, pal_.detalhe)
	K.parapeito(g, n, 3.2)
	local yt = K.Y(n)
	K.b("TorreRelogio", 0, yt + 6, -3, 9, 12, 9, pal_.parede, pal_.matParede)
	K.b("TorreCornija", 0, yt + 12.3, -3, 10.4, 0.8, 10.4, pal_.detalhe, "Concrete", { sombra = false })
	K.cil(
		"RelogioMostrador",
		0,
		yt + 7.5,
		-7.6,
		5.4,
		0.5,
		{ 214, 210, 196 },
		"SmoothPlastic",
		{ eixo = "z", consulta = false, sombra = false }
	)
	K.b(
		"PonteiroH",
		0,
		yt + 7.5,
		-8,
		0.4,
		2.4,
		0.2,
		{ 30, 30, 30 },
		"SmoothPlastic",
		{ colide = false, consulta = false, sombra = false }
	)
	K.b(
		"PonteiroM",
		0.9,
		yt + 7.5,
		-8,
		1.8,
		0.35,
		0.2,
		{ 30, 30, 30 },
		"SmoothPlastic",
		{ colide = false, consulta = false, sombra = false }
	)
	ctx.telhadoDuasAguas(K.m, K.cf, "TorreTelhado", 0, -3, 9, 9, yt + 12.7, 5, 0.6, 0.5, pal_.telhado, "Slate", true)
	empena(K, 0, yt + 12.7, -7.8, 9.6, 5, 3, 0.6, pal_.parede, "Concrete", false)
	K.cil("MastroPref", -22, yt + 5, 14, 0.4, 10, C_METAL, "Metal", { sombra = false })
	return K.m, K.info(0, Z0)
end
M.catalogo.prefeitura = { paletas = PAL.prefeitura, construir = prefeitura }

-- ---------------------------------------------------------------------------------------------------------------
-- BIBLIOTECA 44×34, 1–2 andares. Foyer com balcão, salão de estantes em fileiras, mesas de leitura (ou escada para o
-- mezanino no leste). Telhado de duas águas com oitões.
-- ---------------------------------------------------------------------------------------------------------------
local function biblioteca(ctx, spec)
	local K = novoK(ctx, spec, "biblioteca", "biblioteca", 44, 34, 8)
	local n, pal_ = K.n, K.pal
	local X0, X1, Z0, Z1 = -20, 20, -13, 15
	local ZF = -4
	local g = { X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1, passo = 12, larg = 4.6, janelaAlt = 4.4 }
	local f = if n == 2 then K.escada(0, 17, -2, "+z", 5) else nil

	K.laje(0, X0, X1, Z0, Z1)
	for k = 1, n do
		K.laje(k, X0, X1, Z0, Z1, if k == 1 and f then { f } else nil)
	end
	if f then
		K.corrimao(1, f.x0, f.x1, f.z0 - 0.15, f.z0 + 0.15)
		K.corrimao(1, f.x0 - 0.15, f.x0 + 0.15, f.z0, f.z0 + 8)
	end

	g.portas = { frente = { K.portaExt(0 - X0, 6) } }
	g.res = { oeste = { { ZF - Z0, 1 } }, leste = { { ZF - Z0, 1 } } }
	K.casca(0, g)
	K.paredeZ(0, ZF, X0, X1, { -8, 6 }, 7, "vao")

	local foyer = K.sala(X0, X1, Z0, ZF)
	K.naParede("balcao_recepcao", "-z", -12, foyer, 0)
	K.mov("computador", -14, Z0 + 2.4, pi, 0, nil, 3.6)
	K.mov("planta_vaso", 12, -11.5, 0, 0)
	K.loot(8, -9, 0)

	local salao = K.sala(X0, X1, ZF, Z1)
	for _, x in { -14, -7, 0 } do
		K.mov("estante_biblioteca", x, 3, pi, 0)
		K.mov("estante_biblioteca", x, 10, 0, 0)
	end
	K.naParede("estante_biblioteca", "-x", 4, salao, 0)
	K.naParede("estante_biblioteca", "-x", 11, salao, 0)
	K.loot(-16, 6.5, 0)
	K.loot(5, 12.5, 0)
	if n == 1 then
		K.mov("mesa_reuniao", 14.5, 4, pi / 2, 0, { w = 7 })
		K.mov("mesa_reuniao", 14.5, 11, pi / 2, 0, { w = 7 })
		K.mov("cadeira", 11.6, 4, -pi / 2, 0)
		K.mov("cadeira", 17.4, 11, pi / 2, 0)
		K.loot(16, 0, 0)
	end

	if n == 2 then
		local g1 = {
			X0 = X0,
			X1 = X1,
			Z0 = Z0,
			Z1 = Z1,
			passo = 12,
			larg = 4.6,
			janelaAlt = 4.4,
		}
		K.casca(1, g1)
		local mz = K.sala(X0, X1, Z0, Z1)
		for _, x in { -14, -7, 0 } do
			K.mov("estante_biblioteca", x, -3, pi, 1)
			K.mov("estante_biblioteca", x, 4, 0, 1)
		end
		K.naParede("estante_biblioteca", "-x", 10, mz, 1)
		K.mov("mesa_reuniao", 8, -8, 0, 1, { w = 7 })
		K.mov("cadeira", 3.4, -8, -pi / 2, 1)
		K.loot(-12, 11, 1)
		K.loot(8, 11, 1)
	end

	-- fachada, marquise e telhado de duas águas com oitões
	K.rodape(g, { frente = { { -3.6, 3.6 } } })
	K.b("Marquise", 0, 9.2, -14.6, 12, 0.5, 2.6, pal_.detalhe, "Concrete", { sombra = false })
	for _, dx in { -5.5, 5.5 } do
		K.b("Pilar", dx, 4.6, -15.6, 0.9, 9.2, 0.9, pal_.detalhe, "Concrete")
	end
	K.letreiro("BIBLIOTECA", 0, 11, Z0 - 0.7, 14, 2, { 56, 44, 36 }, { 226, 214, 184 }, 0.3)
	local yt = K.Y(n)
	ctx.telhadoDuasAguas(K.m, K.cf, "Telhado", 0, 1, 40, 28, yt, 6, 1.4, 0.6, pal_.telhado, "Slate", false)
	for _, x in { -20.2, 20.2 } do
		empena(K, x, yt, 1, 28, 6, 4, 0.8, pal_.parede, pal_.matParede, true)
	end
	K.b("Chamine", 12, yt + 5, 6, 2.4, 8, 2.4, pal_.parede, "Brick")
	return K.m, K.info(0, Z0)
end
M.catalogo.biblioteca = { paletas = PAL.biblioteca, construir = biblioteca }

return M
