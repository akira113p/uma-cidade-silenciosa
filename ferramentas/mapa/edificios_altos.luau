-- Edifícios altos da cidade central (agente E2): apartamentos, escritorio, torre, hotel, predio_misto, garagem.
-- Contrato: docs/mapa-v2.md §5 e catalogo_contrato.luau. Todos compartilham o mesmo motor (fachada em faixas + pilastras,
-- laje com furo, escada em U contínua até o telhado, casa de escada) e mudam de planta, térreo, coroamento e paleta.
-- Móveis só via Mob; carros da garagem via Props.carro. Aleatoriedade só por spec.rng.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Enum = roblox.Enum
local CFrame = roblox.CFrame

local Contrato = require("./catalogo_contrato")
local Mob = require("./mobilia")
local Props = require("./props")

local min, max, abs, floor, pi = math.min, math.max, math.abs, math.floor, math.pi

local M = { catalogo = {} }

local H = 12 -- pé-direito (um andar)
local LAJE = 0.9 -- espessura da laje entre andares
local PD = H - LAJE -- altura das paredes internas (encostam na laje de cima)
local TOPO0 = 0.04 -- topo do piso do térreo (acima do pad, sem z-fight)
local ESCADA = { 120, 118, 112 }

-- ---------------------------------------------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------------------------------------------
local function letreiroTexto(parte, texto: string, cor, face: string?)
	pcall(function()
		local gui = Instance.new("SurfaceGui")
		gui.Face = (Enum.NormalId :: any)[face or "Front"]
		gui.Parent = parte
		local t = Instance.new("TextLabel")
		t.Size = (roblox :: any).UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Text = texto
		t.TextColor3 = (roblox :: any).Color3.fromRGB(cor[1], cor[2], cor[3])
		t.TextScaled = true
		t.Parent = gui
	end)
end

local function dim(nome: string, op)
	local t = Mob.tam[nome]
	local w, d = t.w, t.d
	if t.var and op then
		w = op.w or w
		d = op.d or d
	end
	return w, d
end

-- Sala retangular (limites = faces internas das paredes) com controle de ocupação: móveis só entram onde cabem.
local function novaSala(E, x0: number, x1: number, z0: number, z1: number, y: number)
	local S = { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y = y, obst = {} }
	function S.bloq(a0, a1, b0, b1)
		table.insert(S.obst, { a0, a1, b0, b1 })
	end
	local function livre(a0, a1, b0, b1)
		if a0 < x0 - 0.01 or a1 > x1 + 0.01 or b0 < z0 - 0.01 or b1 > z1 + 0.01 then
			return false
		end
		for _, o in S.obst do
			if a0 < o[2] and a1 > o[1] and b0 < o[4] and b1 > o[3] then
				return false
			end
		end
		return true
	end
	-- porta no lado `lado`, centro c (ao longo da parede), largura l: reserva 5,5 st à frente
	function S.porta(lado: string, c: number, l: number)
		local m, prof = l / 2 + 0.5, 5.5
		if lado == "-z" then
			S.bloq(c - m, c + m, z0, z0 + prof)
		elseif lado == "+z" then
			S.bloq(c - m, c + m, z1 - prof, z1)
		elseif lado == "-x" then
			S.bloq(x0, x0 + prof, c - m, c + m)
		else
			S.bloq(x1 - prof, x1, c - m, c + m)
		end
	end
	function S.poe(nome: string, x: number, z: number, rot: number, op)
		local w, d = dim(nome, op)
		local q = abs(math.sin(rot)) > 0.5
		local ex, ez = (if q then d else w) / 2, (if q then w else d) / 2
		if not livre(x - ex, x + ex, z - ez, z + ez) then
			return nil
		end
		op = op or {}
		op.rng = op.rng or E.rng
		local m = Mob.colocar(E.ctx, E.modelo, nome, E.cf, x, S.y, z, rot, op)
		E.nMov += 1
		S.bloq(x - ex - 0.15, x + ex + 0.15, z - ez - 0.15, z + ez + 0.15)
		return m
	end
	-- encosta na parede `lado`; t em 0..1 ao longo dela
	function S.parede(nome: string, lado: string, t: number, op, folga: number?)
		local w = dim(nome, op)
		local lo, hi
		if lado == "-z" or lado == "+z" then
			lo, hi = x0 + w / 2 + 0.2, x1 - w / 2 - 0.2
		else
			lo, hi = z0 + w / 2 + 0.2, z1 - w / 2 - 0.2
		end
		if hi < lo then
			return nil
		end
		local x, z, rot = Mob.paraParede(nome, lado, lo + (hi - lo) * t, S, folga)
		return S.poe(nome, x, z, rot, op)
	end
	-- peça fixa na parede (quadro, relógio): a origem fica na face da parede
	function S.noMuro(nome: string, lado: string, ao: number, alt: number, op)
		local x, z, rot
		if lado == "+z" then
			x, z, rot = ao, z1, 0
		elseif lado == "-z" then
			x, z, rot = ao, z0, pi
		elseif lado == "-x" then
			x, z, rot = x0, ao, -pi / 2
		else
			x, z, rot = x1, ao, pi / 2
		end
		op = op or {}
		op.rng = op.rng or E.rng
		E.nMov += 1
		return Mob.colocar(E.ctx, E.modelo, nome, E.cf, x, S.y + alt, z, rot, op)
	end
	function S.loot(x: number, z: number, tabela: string?): boolean
		if not livre(x - 1.5, x + 1.5, z - 1.5, z + 1.5) then
			return false
		end
		table.insert(E.loot, { x = x, y = S.y, z = z, tabela = tabela })
		S.bloq(x - 1.5, x + 1.5, z - 1.5, z + 1.5)
		return true
	end
	return S
end

-- ---------------------------------------------------------------------------------------------------------------
-- Motor do edifício
-- ---------------------------------------------------------------------------------------------------------------
local function nova(ctx, spec, variante: string, extra: number)
	local ct = Contrato[variante]
	local n = spec.andares or ct.andares[1]
	n = max(ct.andares[1], min(ct.andares[2], n))
	local E = {
		ctx = ctx,
		spec = spec,
		cf = spec.cf,
		w = ct.w,
		d = ct.d,
		n = n,
		variante = variante,
		loot = {},
		nMov = 0,
		topo = n * H,
	}
	E.rng = spec.rng or ctx.rng("altos_" .. variante)
	local paletas = M.catalogo[variante].paletas
	E.P = spec.paleta or E.rng.escolher(paletas)
	E.modelo = ctx.modeloConstrucao(spec, ct.tipo, variante, ct.w, ct.d, n * H + extra, n)
	E.hx, E.hz = ct.w / 2 - 1.5, ct.d / 2 - 1.5 -- linhas centrais das paredes externas (espessura 1)
	E.lados = {
		{ id = "F", h = true, c = -E.hz, a = -E.hx - 0.5, b = E.hx + 0.5, n = -1, ga = -E.hx + 0.5, gb = E.hx - 0.5 },
		{ id = "B", h = true, c = E.hz, a = -E.hx - 0.5, b = E.hx + 0.5, n = 1, ga = -E.hx + 0.5, gb = E.hx - 0.5 },
		{ id = "L", h = false, c = -E.hx, a = -E.hz + 0.5, b = E.hz - 0.5, n = -1, ga = -E.hz + 0.5, gb = E.hz - 0.5 },
		{ id = "R", h = false, c = E.hx, a = -E.hz + 0.5, b = E.hz - 0.5, n = 1, ga = -E.hz + 0.5, gb = E.hz - 0.5 },
	}
	E.entX = 0

	function E.caixa(nome, x0, x1, y0, y1, z0, z1, cor, mat, op)
		return ctx.bloco(
			E.modelo,
			E.cf,
			nome,
			(x0 + x1) / 2,
			(y0 + y1) / 2,
			(z0 + z1) / 2,
			x1 - x0,
			y1 - y0,
			z1 - z0,
			cor,
			mat or "Concrete",
			op
		)
	end
	function E.cil(nome, cx, cy, cz, diam, comp, cor, mat, op)
		return ctx.cilindro(E.modelo, E.cf, nome, cx, cy, cz, diam, comp, cor, mat or "Metal", op)
	end
	function E.parede(nome, ax, az, bx, bz, base, alt, esp, cor, mat, ab, op)
		return ctx.parede(E.modelo, E.cf, nome, { ax, az }, { bx, bz }, base, alt, esp, cor, mat, ab, op)
	end
	-- paredes internas: endereçadas por centro (c) das aberturas em coordenada local
	function E.pX(nome, x0, x1, z, yb, ab, cor, mat)
		local l = {}
		for _, a in ab or {} do
			table.insert(
				l,
				{ de = a.c - x0, larg = a.larg, tipo = a.tipo or "vao", alt = a.alt, peitoril = a.peit, cor = a.cor }
			)
		end
		return E.parede(nome, x0, z, x1, z, yb, PD, 1, cor, mat or "Concrete", l, { ext = 0 })
	end
	function E.pZ(nome, x, z0, z1, yb, ab, cor, mat)
		local l = {}
		for _, a in ab or {} do
			table.insert(
				l,
				{ de = a.c - z0, larg = a.larg, tipo = a.tipo or "vao", alt = a.alt, peitoril = a.peit, cor = a.cor }
			)
		end
		return E.parede(nome, x, z0, x, z1, yb, PD, 1, cor, mat or "Concrete", l, { ext = 0 })
	end
	function E.sala(x0, x1, z0, z1, y)
		return novaSala(E, x0, x1, z0, z1, y)
	end

	-- faixa no plano da parede externa do lado s (off = deslocamento para fora; a,b = trecho)
	function E.faixa(s, y0, y1, nome, cor, mat, esp, off, op, a, b)
		local c = s.c + s.n * (off or 0)
		a, b = a or s.a, b or s.b
		if s.h then
			return E.caixa(nome, a, b, y0, y1, c - esp / 2, c + esp / 2, cor, mat, op)
		end
		return E.caixa(nome, c - esp / 2, c + esp / 2, y0, y1, a, b, cor, mat, op)
	end

	-- postes de canto (altura total) e pilastras (full-height) nos lados pedidos
	function E.postes(cor, mat)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				E.caixa(
					"Canto",
					sx * E.hx - 0.6,
					sx * E.hx + 0.6,
					0,
					E.topo + 3.2,
					sz * E.hz - 0.6,
					sz * E.hz + 0.6,
					cor,
					mat
				)
			end
		end
	end
	function E.pilastras(cor, mat, pw, passo, lados, y0, y1, dentro)
		y0 = y0 or 0
		y1 = y1 or (E.topo + 3.2)
		for _, s in E.lados do
			if string.find(lados, s.id, 1, true) then
				local comp = (if s.h then s.gb - s.ga else s.b - s.a)
				local ini = (if s.h then s.ga else s.a)
				local c = max(2, floor(comp / passo + 0.5))
				for i = 1, c do
					local p = ini + comp * (i - 0.5) / c
					local skip = (s.id == "F" and abs(p - E.entX) < 5.2)
					if not skip then
						E.faixa(s, y0, y1, "Pilastra", cor, mat, 1, 1, nil, p - pw / 2, p + pw / 2)
					end
				end
			end
		end
	end

	-- vidro corrido de um andar acima do térreo e faixas de peitoril
	function E.vidro(s, y0, y1)
		return E.faixa(
			s,
			y0,
			y1,
			"Vidro",
			E.P.vidro,
			"Glass",
			0.3,
			0,
			{ transparencia = 0.55, sombra = false },
			s.ga,
			s.gb
		)
	end
	function E.fachada(o)
		o = o or {}
		local P = E.P
		local sill, jan, par = o.sill or 3.4, o.jan or 5.8, o.parapeito or 3.2
		local mat = o.mat or P.mat
		for _, s in E.lados do
			local cor = o.cor or P.faixa
			E.faixa(s, H, H + sill, "Peitoril", cor, mat, 1, 0)
			for k = 1, E.n - 1 do
				E.vidro(s, k * H + sill, k * H + sill + jan)
				if k < E.n - 1 then
					E.faixa(s, k * H + sill + jan, (k + 1) * H + sill, "Faixa", cor, mat, 1, 0)
				end
			end
			E.faixa(s, (E.n - 1) * H + sill + jan, E.topo + par, "Parapeito", cor, mat, 1, 0)
		end
	end
	function E.cornija(cor, mat, extra)
		local y0 = E.topo + 3.2
		for _, s in E.lados do
			local a, b = s.a, s.b
			if s.h then
				a, b = a - 1, b + 1
			end
			E.faixa(s, y0, y0 + 0.8 + (extra or 0), "Cornija", cor, mat or "Concrete", 2, 0.5, nil, a, b)
		end
	end

	-- laje do andar k (k = n: telhado), com furos
	function E.laje(k, furos, cor, mat)
		local y = if k == 0 then TOPO0 else k * H
		local esp = if k == 0 then 0.4 else LAJE
		return ctx.piso(
			E.modelo,
			E.cf,
			"Laje",
			-E.hx - 0.5,
			E.hx + 0.5,
			-E.hz - 0.5,
			E.hz + 0.5,
			y,
			esp,
			cor,
			mat or "Concrete",
			furos
		)
	end

	-- térreo: paredes externas de 12 de altura com aberturas {centro, larg, tipo, alt, peitoril, cor}
	function E.terreoParedes(cor, mat, ab)
		local hx, hz = E.hx, E.hz
		local function conv(lado, lista)
			local out = {}
			for _, a in lista or {} do
				local de = (if lado == "F" or lado == "B" then a[1] + hx else a[1] + hz)
				local tipo = a[3] or "janela"
				table.insert(out, {
					de = de,
					larg = a[2],
					tipo = tipo,
					alt = a[4] or (if tipo == "janela" then 5.5 else nil),
					peitoril = a[5] or (if tipo == "janela" then 2.5 else nil),
					cor = a[6],
				})
			end
			return out
		end
		E.parede("Terreo", -hx, -hz, hx, -hz, 0, H, 1, cor, mat, conv("F", ab.F))
		E.parede("Terreo", -hx, hz, hx, hz, 0, H, 1, cor, mat, conv("B", ab.B))
		E.parede("Terreo", -hx, -hz, -hx, hz, 0, H, 1, cor, mat, conv("L", ab.L), { ext = -0.5 })
		E.parede("Terreo", hx, -hz, hx, hz, 0, H, 1, cor, mat, conv("R", ab.R), { ext = -0.5 })
	end

	-- marquise sobre a entrada principal (face −Z), degraus, placa de letreiro e número
	function E.entrada(cx, larg, texto, o)
		o = o or {}
		local P = E.P
		E.entX = cx
		local z0 = -E.hz - 0.5
		local prof = 2.5
		local y = o.y or 8.6
		E.caixa("Marquise", cx - larg / 2, cx + larg / 2, y, y + 0.8, z0 - prof, z0, P.cornija, "Concrete")
		E.caixa(
			"MarquiseBorda",
			cx - larg / 2,
			cx + larg / 2,
			y + 0.8,
			y + 1.4,
			z0 - prof,
			z0 - prof + 0.4,
			P.letreiro,
			"Metal"
		)
		for _, s in { -1, 1 } do
			E.caixa(
				"ApoioMarquise",
				cx + s * (larg / 2 - 0.9) - 0.35,
				cx + s * (larg / 2 - 0.9) + 0.35,
				0,
				y,
				z0 - prof + 0.3,
				z0 - prof + 1.0,
				P.cornija,
				"Concrete"
			)
		end
		E.caixa("Degrau", cx - larg / 2 + 1.2, cx + larg / 2 - 1.2, 0, 0.5, z0 - 1.4, z0, P.terreo, "Concrete")
		-- placa
		local sw = o.placa or 12
		local pl = E.caixa(
			"Letreiro",
			cx - sw / 2,
			cx + sw / 2,
			y + 1.6,
			y + 3.4,
			z0 - 0.5,
			z0 - 0.1,
			o.corPlaca or { 30, 30, 32 },
			"Metal",
			{ consulta = false }
		)
		letreiroTexto(pl, texto, o.corTexto or P.letreiro)
	end

	-- caixa d'água, antena e ar-condicionado de cobertura
	function E.tanque(x, z, diam, alt, cor)
		local y0 = E.topo
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				E.caixa(
					"PernaTanque",
					x + sx * diam / 2 * 0.7 - 0.3,
					x + sx * diam / 2 * 0.7 + 0.3,
					y0,
					y0 + 4,
					z + sz * diam / 2 * 0.7 - 0.3,
					z + sz * diam / 2 * 0.7 + 0.3,
					{ 80, 78, 74 },
					"Metal"
				)
			end
		end
		E.cil("Tanque", x, y0 + 4 + alt / 2, z, diam, alt, cor or { 110, 104, 96 }, "CorrodedMetal")
		E.cil("TampaTanque", x, y0 + 4 + alt + 0.3, z, diam * 0.7, 0.6, { 70, 68, 66 }, "Metal", { consulta = false })
	end
	function E.antena(x, z, alt, neon)
		local y0 = E.topo
		E.cil("Mastro", x, y0 + alt / 2, z, 0.8, alt, { 70, 70, 74 }, "Metal")
		E.caixa(
			"Braco",
			x - 3,
			x + 3,
			y0 + alt * 0.7,
			y0 + alt * 0.7 + 0.3,
			z - 0.15,
			z + 0.15,
			{ 70, 70, 74 },
			"Metal",
			{
				colide = false,
			}
		)
		E.caixa(
			"Braco",
			x - 0.15,
			x + 0.15,
			y0 + alt * 0.85,
			y0 + alt * 0.85 + 0.3,
			z - 2,
			z + 2,
			{ 70, 70, 74 },
			"Metal",
			{
				colide = false,
			}
		)
		if neon then
			E.cil("Luz", x, y0 + alt + 0.4, z, 0.9, 0.9, { 150, 40, 40 }, "Neon", { colide = false, consulta = false })
		end
	end
	function E.condicionador(x, z, rot)
		local y0 = E.topo
		E.caixa("Condicionador", x - 2, x + 2, y0, y0 + 3, z - 1.5, z + 1.5, { 150, 150, 148 }, "Metal")
		E.cil(
			"Ventilador",
			x,
			y0 + 3.05,
			z,
			2.4,
			0.2,
			{ 60, 60, 62 },
			"Metal",
			{ colide = false, consulta = false, sombra = false }
		)
		return rot
	end

	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- Escada em U (2 lances por andar). Origem (ox, oz) = centro da borda de entrada (no piso do andar); `dir` = sentido
-- do primeiro lance. Os dois lances partem/chegam na borda de entrada, o patamar fica no fundo.
-- ---------------------------------------------------------------------------------------------------------------
local OPOSTO = { ["+z"] = "-z", ["-z"] = "+z", ["+x"] = "-x", ["-x"] = "+x" }
local EIXOS = { ["+z"] = { 0, 1, 1, 0 }, ["-z"] = { 0, -1, -1, 0 }, ["+x"] = { 1, 0, 0, 1 }, ["-x"] = { -1, 0, 0, -1 } }

local function escadaU(E, ox: number, oz: number, dir: string)
	local ctx = E.ctx
	local e = EIXOS[dir]
	local ax, az, lx, lz = e[1], e[2], e[3], e[4]
	local S = { larg = 4.6, gap = 0.8, patamar = 4.5, ox = ox, oz = oz, dir = dir }
	S.W = 2 * S.larg + S.gap
	S.L1 = ctx.comprimentoEscada(H / 2)
	S.pv = (S.larg + S.gap) / 2
	function S.P(u, v)
		return ox + ax * u + lx * v, oz + az * u + lz * v
	end
	local function ret(u0, v0, u1, v1)
		local xa, za = S.P(u0, v0)
		local xb, zb = S.P(u1, v1)
		return { x0 = min(xa, xb), x1 = max(xa, xb), z0 = min(za, zb), z1 = max(za, zb) }
	end
	S.ret = ret
	S.furo = ret(0, S.pv - S.larg / 2, S.L1, S.pv + S.larg / 2)
	S.area = ret(0, -S.W / 2, S.L1 + S.patamar, S.W / 2)
	function S.andar(y: number)
		local cor = ESCADA
		local x1, z1 = S.P(0, -S.pv)
		ctx.escada(E.modelo, E.cf, "Degrau", x1, z1, dir, y, H / 2, S.larg, cor, "Concrete")
		local x2, z2 = S.P(S.L1, S.pv)
		ctx.escada(E.modelo, E.cf, "Degrau", x2, z2, OPOSTO[dir], y + H / 2, H / 2, S.larg, cor, "Concrete")
		local p = ret(S.L1, -S.W / 2, S.L1 + S.patamar, S.W / 2)
		E.caixa("Patamar", p.x0, p.x1, y + H / 2 - 1.2, y + H / 2, p.z0, p.z1, cor, "Concrete")
		local c = ret(0, -S.gap / 2, S.L1, S.gap / 2)
		E.caixa("Eixo", c.x0, c.x1, y, y + PD, c.z0, c.z1, { 100, 98, 94 }, "Concrete")
	end
	return S
end

-- casa de escada / casa de máquinas sobre o fim da escada, com porta voltada para o terraço
local function casaEscada(E, S, cor, mat, corTeto, alt)
	alt = alt or 8
	local y = E.topo
	local W = S.W
	local function pUV(u0, v0, u1, v1, ab, op)
		local xa, za = S.P(u0, v0)
		local xb, zb = S.P(u1, v1)
		E.parede("CasaEscada", xa, za, xb, zb, y, alt, 1, cor, mat, ab, op)
	end
	local ext = S.L1 + S.patamar + 1
	local vmax = W / 2 + 0.5
	pUV(-0.5, -vmax, -0.5, vmax, { { de = S.pv + vmax, larg = 5.6, tipo = "porta", alt = 7.5, cor = { 60, 60, 62 } } })
	pUV(ext, -vmax, ext, vmax)
	pUV(-0.5, -vmax, ext, -vmax, nil, { ext = -0.5 })
	pUV(-0.5, vmax, ext, vmax, nil, { ext = -0.5 })
	local r = S.ret(-1, -vmax - 0.5, ext + 0.5, vmax + 0.5)
	E.caixa("TetoCasa", r.x0, r.x1, y + alt, y + alt + 0.9, r.z0, r.z1, corTeto, "Concrete")
end

-- ---------------------------------------------------------------------------------------------------------------
-- Planta com corredor ao longo de X e núcleo de escada ao fundo (apartamentos, escritorio)
-- ---------------------------------------------------------------------------------------------------------------
local function bannheiroCelula(E, yb, sx, sz, cor, mobiliar)
	-- célula 5,5 × 5,5 no canto externo (x = sx, z = sz); parede com vão voltada para o apartamento
	local hxi, hzi = E.hx - 0.5, E.hz - 0.5
	local zw = sz * (hzi - 6)
	local xw = sx * (hxi - 6)
	E.pX("Banheiro", min(sx * hxi, xw + sx * 0.5), max(sx * hxi, xw + sx * 0.5), zw, yb, {
		{ c = sx * (hxi - 2.75), larg = 4.2 },
	}, cor)
	E.pZ("Banheiro", xw, min(sz * hzi, zw - sz * 0.5), max(sz * hzi, zw - sz * 0.5), yb, nil, cor)
	local S = E.sala(
		min(sx * hxi, xw - sx * 0.5),
		max(sx * hxi, xw - sx * 0.5),
		min(sz * hzi, zw - sz * 0.5),
		max(sz * hzi, zw - sz * 0.5),
		yb
	)
	local ladoPorta = if sz > 0 then "-z" else "+z"
	S.porta(ladoPorta, sx * (hxi - 2.75), 4.2)
	if mobiliar then
		S.parede("vaso_sanitario", if sz > 0 then "+z" else "-z", if sx > 0 then 0.15 else 0.85)
		S.parede("lavatorio", if sx > 0 then "+x" else "-x", 0.5)
	end
	return {
		x0 = min(sx * hxi, xw - sx * 0.5),
		x1 = max(sx * hxi, xw - sx * 0.5),
		z0 = min(sz * hzi, zw - sz * 0.5),
		z1 = max(sz * hzi, zw - sz * 0.5),
	}
end

-- ---------------------------------------------------------------------------------------------------------------
-- APARTAMENTOS (36×36, 4–6 andares)
-- ---------------------------------------------------------------------------------------------------------------
local function apartamentos(ctx, spec)
	local E = nova(ctx, spec, "apartamentos", 22)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local zA, zB = -4.9, 1.4
	local S = escadaU(E, 0, zB + 0.5, "+z")
	E.entX = 0

	-- fachada
	E.postes(P.pilastra, P.mat)
	E.fachada()
	E.pilastras(P.pilastra, P.mat, 1.8, 6.4, "FBLR")
	E.cornija(P.cornija, "Concrete")
	E.terreoParedes(P.terreo, P.matTerreo, {
		F = { { -10.5, 8, "janela" }, { 0, 6, "porta", 7.5, 0, P.porta }, { 10.5, 8, "janela" } },
		B = { { -10, 8, "janela" }, { 10, 8, "janela" } },
		L = { { -9, 7, "janela" }, { 9, 6, "janela" } },
		R = { { -9, 7, "janela" }, { 9, 6, "janela" } },
	})
	E.entrada(0, 11, "RESIDENCIAL", { placa = 10 })
	-- sacadas decorativas na frente
	for k = 1, n - 1 do
		for _, cx in { -9, 9 } do
			local y = k * H
			E.caixa("Sacada", cx - 3.4, cx + 3.4, y - 0.5, y + 0.2, -hz - 2.5, -hz - 0.5, P.cornija, "Concrete")
			E.caixa("GradeSacada", cx - 3.4, cx + 3.4, y + 0.2, y + 3.0, -hz - 2.5, -hz - 2.2, P.letreiro, "Metal", {
				colide = false,
			})
		end
	end

	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		E.laje(k, if k > 0 then { S.area } else nil, P.piso, P.pisoMat)
		S.andar(yb)
		local pc = P.parede
		-- parede frontal do corredor
		if k == 0 then
			E.pX("Corredor", -hx + 0.5, hx - 0.5, zA, yb, { { c = 0, larg = 10 } }, pc)
		else
			E.pX("Corredor", -hx + 0.5, hx - 0.5, zA, yb, {
				{ c = -8, larg = 5.2, tipo = "porta", cor = P.porta },
				{ c = 8, larg = 5.2, tipo = "porta", cor = P.porta },
			}, pc)
			E.pZ("Divisoria", 0, -hz + 0.5, zA - 0.5, yb, nil, pc)
			-- elevador decorativo
			E.caixa(
				"ElevadorQuadro",
				-3.4,
				3.4,
				yb,
				yb + 7.8,
				zA + 0.5,
				zA + 0.65,
				{ 55, 55, 58 },
				"DiamondPlate",
				{ colide = false }
			)
			E.caixa(
				"ElevadorPortas",
				-3,
				3,
				yb,
				yb + 7.2,
				zA + 0.65,
				zA + 0.75,
				{ 150, 150, 148 },
				"Metal",
				{ colide = false }
			)
			E.caixa(
				"ElevadorFresta",
				-0.06,
				0.06,
				yb,
				yb + 7.2,
				zA + 0.75,
				zA + 0.8,
				{ 40, 40, 42 },
				"Metal",
				{ colide = false, consulta = false }
			)
		end
		-- fundo do corredor, núcleo
		local aberB = { { c = 0, larg = 10.6 } }
		if k == 0 then
			table.insert(aberB, { c = -10.5, larg = 5.2, tipo = "porta", cor = P.porta })
			table.insert(aberB, { c = 10.5, larg = 5.2, tipo = "porta", cor = P.porta })
		else
			table.insert(aberB, { c = -10.5, larg = 5.2, tipo = "porta", cor = P.porta })
			table.insert(aberB, { c = 10.5, larg = 5.2, tipo = "porta", cor = P.porta })
		end
		E.pX("Nucleo", -hx + 0.5, hx - 0.5, zB, yb, aberB, pc)
		E.pZ("Nucleo", -5.6, zB + 0.5, hz - 0.5, yb, nil, pc)
		E.pZ("Nucleo", 5.6, zB + 0.5, hz - 0.5, yb, nil, pc)

		if k == 0 then
			-- hall de entrada
			local sh = E.sala(-hx + 0.5, hx - 0.5, -hz + 0.5, zA - 0.5, yb)
			sh.porta("-z", 0, 6)
			sh.bloq(-4, 4, -hz + 0.5, -hz + 4)
			sh.loot(-12, -9)
			sh.loot(12, -9)
			sh.parede("sofa", "+z", 0.12)
			sh.parede("sofa", "+z", 0.88)
			sh.parede("planta_vaso", "-x", 0.3)
			sh.parede("planta_vaso", "+x", 0.3)
			sh.parede("planta_vaso", "-x", 0.9)
			sh.noMuro("quadro", "+z", -12, 5.5)
			sh.noMuro("quadro", "+z", 12, 5.5)
			-- caixas de correio
			E.caixa(
				"CaixasCorreio",
				-hx + 1.2,
				hx - 1.2,
				yb + 3.6,
				yb + 5.6,
				zA - 1.0,
				zA - 0.5,
				{ 80, 84, 86 },
				"Metal",
				{ colide = false }
			)
			-- apartamentos do térreo: zelador e depósito
			for _, sx in { -1, 1 } do
				local r =
					E.sala(if sx < 0 then -hx + 0.5 else 6.1, if sx < 0 then -6.1 else hx - 0.5, zB + 0.5, hz - 0.5, yb)
				r.porta("-z", sx * 10.5, 5.2)
				r.loot(sx * 11, 12)
				if sx < 0 then
					r.parede("cama_solteiro", "+z", 0.1)
					r.parede("geladeira", "-x", 0.9)
					r.parede("mesa_cozinha", "-z", 0.9)
				else
					r.parede("estante_livros", "+z", 0.5)
					r.parede("caixa_papelao", "+x", 0.2)
					r.parede("caixa_papelao", "+x", 0.8)
				end
			end
		else
			-- 4 apartamentos
			local temLoot = rng.chance(0.45)
			for _, ap in
				{
					{ sx = -1, sz = -1, x0 = -hx + 0.5, x1 = -0.5, z0 = -hz + 0.5, z1 = zA - 0.5, pl = "+z", pc = -8 },
					{ sx = 1, sz = -1, x0 = 0.5, x1 = hx - 0.5, z0 = -hz + 0.5, z1 = zA - 0.5, pl = "+z", pc = 8 },
					{ sx = -1, sz = 1, x0 = -hx + 0.5, x1 = -6.1, z0 = zB + 0.5, z1 = hz - 0.5, pl = "-z", pc = -10.5 },
					{ sx = 1, sz = 1, x0 = 6.1, x1 = hx - 0.5, z0 = zB + 0.5, z1 = hz - 0.5, pl = "-z", pc = 10.5 },
				}
			do
				local ocupado = rng.chance(0.65)
				local cel = bannheiroCelula(E, yb, ap.sx, ap.sz, pc, ocupado)
				local r = E.sala(ap.x0, ap.x1, ap.z0, ap.z1, yb)
				r.porta(ap.pl, ap.pc, 5.2)
				r.bloq(cel.x0 - 0.6, cel.x1 + 1.2, cel.z0 - 1.2, cel.z1 + 1.2)
				if temLoot and ocupado and ap.sz < 0 then
					r.loot(ap.pc, (ap.z0 + ap.z1) / 2)
				end
				local lado = if ap.sz < 0 then "-z" else "+z"
				if ocupado then
					r.parede("cama_casal", lado, if ap.sx < 0 then 0.75 else 0.25)
					r.parede("criado_mudo", lado, if ap.sx < 0 then 0.98 else 0.02)
					r.parede("sofa", if ap.sx < 0 then "+x" else "-x", 0.5)
					r.parede("geladeira", if ap.sx < 0 then "-x" else "+x", if ap.sz < 0 then 0.85 else 0.15)
				elseif rng.chance(0.5) then
					r.parede("caixa_papelao", lado, 0.5)
				end
			end
		end
	end

	-- telhado
	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 8)
	local lado = if rng.chance(0.5) then -1 else 1
	E.tanque(lado * 11, 10, 7, 6, nil)
	E.condicionador(-lado * 11, -8)
	E.condicionador(-lado * 11, -13)
	E.antena(lado * 11, -10, 14, false)
	E.antena(-lado * 8, 13, 9, false)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- ESCRITÓRIO (40×40, 6–10 andares)
-- ---------------------------------------------------------------------------------------------------------------
local function escritorio(ctx, spec)
	local E = nova(ctx, spec, "escritorio", 30)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local zA, zB = -4.2, 2.2
	local S = escadaU(E, 0, zB + 0.5, "+z")

	E.postes(P.pilastra, P.mat)
	E.fachada({ sill = 3.2, jan = 6.2 })
	E.pilastras(P.pilastra, P.mat, 3.0, 6.6, "FBLR")
	E.cornija(P.cornija, "Concrete", 0.4)
	E.terreoParedes(P.terreo, P.matTerreo, {
		F = { { -11, 10, "janela", 6, 2 }, { 0, 7, "porta", 7.5, 0, P.porta }, { 11, 10, "janela", 6, 2 } },
		B = { { -9, 10, "janela" }, { 9, 10, "janela" } },
		L = { { -8, 9, "janela" }, { 9, 9, "janela" } },
		R = { { -8, 9, "janela" }, { 9, 9, "janela" } },
	})
	E.entrada(0, 14, "ESCRITORIOS", { y = 8.8, placa = 14 })
	-- friso inferior em pedra no térreo
	for _, s in E.lados do
		if s.id ~= "F" then
			E.faixa(s, 0, 1.6, "Rodape", P.terreo, "Granite", 1, 1, { consulta = false })
		end
	end

	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		E.laje(k, if k > 0 then { S.area } else nil, P.piso, P.pisoMat)
		S.andar(yb)
		local pc = P.parede
		-- parede frontal do corredor: dois vãos largos para o salão
		if k == 0 then
			E.pX("Corredor", -hx + 0.5, hx - 0.5, zA, yb, { { c = 0, larg = 14 } }, pc)
		else
			E.pX("Corredor", -hx + 0.5, hx - 0.5, zA, yb, { { c = -9, larg = 8 }, { c = 9, larg = 8 } }, pc)
			E.caixa(
				"ElevadorQuadro",
				-3.4,
				3.4,
				yb,
				yb + 7.8,
				zA + 0.5,
				zA + 0.65,
				{ 55, 55, 58 },
				"DiamondPlate",
				{ colide = false }
			)
			E.caixa(
				"ElevadorPortas",
				-3,
				3,
				yb,
				yb + 7.2,
				zA + 0.65,
				zA + 0.75,
				{ 150, 150, 148 },
				"Metal",
				{ colide = false }
			)
			E.caixa(
				"ElevadorFresta",
				-0.06,
				0.06,
				yb,
				yb + 7.2,
				zA + 0.75,
				zA + 0.8,
				{ 40, 40, 42 },
				"Metal",
				{ colide = false, consulta = false }
			)
		end
		E.pX("Nucleo", -hx + 0.5, hx - 0.5, zB, yb, {
			{ c = -12, larg = 5.2, tipo = "porta", cor = P.porta },
			{ c = 0, larg = 10.6 },
			{ c = 12, larg = 5.2, tipo = "porta", cor = P.porta },
		}, pc)
		E.pZ("Nucleo", -5.6, zB + 0.5, hz - 0.5, yb, nil, pc)
		E.pZ("Nucleo", 5.6, zB + 0.5, hz - 0.5, yb, nil, pc)

		local salao = E.sala(-hx + 0.5, hx - 0.5, -hz + 0.5, zA - 0.5, yb)
		salao.bloq(-5.6, 5.6, zA - 5, zA - 0.5)
		if k == 0 then
			-- lobby com recepção
			salao.bloq(-4.5, 4.5, -hz + 0.5, -hz + 4.5)
			salao.poe("balcao_recepcao", 0, -9.5, 0, nil)
			salao.parede("sofa_recepcao", "-x", 0.25)
			salao.parede("sofa_recepcao", "+x", 0.25)
			salao.parede("planta_vaso", "-x", 0.9)
			salao.parede("planta_vaso", "+x", 0.9)
			salao.parede("bebedouro", "-z", 0.97)
			salao.loot(-13, -9)
			salao.loot(13, -9)
			local rb = E.sala(-hx + 0.5, -6.1, zB + 0.5, hz - 0.5, yb)
			rb.porta("-z", -12, 5.2)
			rb.parede("arquivo_alto", "+z", 0.2)
			rb.parede("copiadora", "-x", 0.6)
			rb.parede("caixa_papelao", "+z", 0.9)
			local rd = E.sala(6.1, hx - 0.5, zB + 0.5, hz - 0.5, yb)
			rd.porta("-z", 12, 5.2)
			rd.parede("escrivaninha", "+z", 0.5)
			rd.parede("cadeira_escritorio", "+x", 0.7)
			rd.parede("arquivo", "+x", 0.15)
			rd.loot(12, 8)
		else
			-- salão de baias
			local baias = if rng.chance(0.3) then 2 else rng.inteiro(0, 1)
			local xs = { -13, -5, 13, 5 }
			for i = 1, baias do
				salao.poe("baia_escritorio", xs[i], -hz + 4.6, 0, nil)
			end
			if rng.chance(0.2) then
				salao.parede("copiadora", "-x", 0.55)
			end
			if rng.chance(0.2) then
				salao.parede("bebedouro", "+x", 0.8)
			end
			if k % 3 == 1 or rng.chance(0.2) then
				salao.loot(rng.escolher({ -12, 12 }), -9)
			end
			-- sala de reuniões e diretoria
			local rb = E.sala(-hx + 0.5, -6.1, zB + 0.5, hz - 0.5, yb)
			rb.porta("-z", -12, 5.2)
			if k % 3 == 1 then
				rb.poe("mesa_reuniao", -12, 10.5, pi / 2, nil)
				rb.noMuro("quadro_branco", "-x", 10.5, 4.5, nil)
			else
				rb.parede("arquivo_alto", "+z", 0.3)
			end
			local rd = E.sala(6.1, hx - 0.5, zB + 0.5, hz - 0.5, yb)
			rd.porta("-z", 12, 5.2)
			if k == n - 1 then
				rd.parede("sofa_recepcao", "+z", 0.5)
				rd.parede("mesa_escritorio", "+x", 0.2)
			else
				rd.parede("mesa_escritorio", "+z", 0.5)
			end
			if rng.chance(0.4) then
				rd.loot(12, 8)
			end
		end
	end

	-- cobertura: casa de máquinas, chillers, antena, letreiro de topo
	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 9)
	local lado = if rng.chance(0.5) then -1 else 1
	E.condicionador(lado * 12, -10)
	E.condicionador(lado * 12, -15)
	E.condicionador(-lado * 12, 12)
	E.tanque(-lado * 12, -11, 6, 5, nil)
	E.antena(-lado * 14, 14, 18, true)
	local sg = E.caixa(
		"LetreiroTopo",
		-9,
		9,
		E.topo + 4.2,
		E.topo + 7.4,
		-hz - 0.3,
		-hz + 0.3,
		{ 30, 30, 32 },
		"Metal",
		{ colide = false }
	)
	letreiroTexto(sg, "ESCRITORIOS", P.letreiro)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- TORRE (44×44, 10–14 andares)
-- ---------------------------------------------------------------------------------------------------------------
local function torre(ctx, spec)
	local E = nova(ctx, spec, "torre", 36)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local S = escadaU(E, 0, -6.25, "+z")

	E.postes(P.pilastra, P.mat)
	E.fachada({ sill = 2.6, jan = 7.0 })
	E.pilastras(P.pilastra, P.mat, 1.1, 5.4, "FBLR")
	E.cornija(P.cornija, "Concrete", 0.4)
	E.terreoParedes(P.terreo, P.matTerreo, {
		F = { { -12, 12, "janela", 7, 2 }, { 0, 8, "porta", 7.5, 0, P.porta }, { 12, 12, "janela", 7, 2 } },
		B = { { -10, 12, "janela" }, { 10, 12, "janela" } },
		L = { { -10, 12, "janela" }, { 10, 12, "janela" } },
		R = { { -10, 12, "janela" }, { 10, 12, "janela" } },
	})
	E.entrada(0, 16, "TORRE CENTRAL", { y = 8.8, placa = 14 })
	-- núcleo sólido (elevadores à esquerda, serviço à direita), em altura total
	E.caixa("NucleoElev", -13, -6.1, 0, E.topo + 1, -7.25, 8.25, P.nucleo, "Concrete")
	E.caixa("NucleoServ", 6.1, 13, 0, E.topo + 1, -7.25, 8.25, P.nucleo, "Concrete")
	E.caixa("NucleoFundo", -13, 13, 0, E.topo + 1, 7.25, 8.25, P.nucleo, "Concrete")
	-- pilares do salão
	local pilares = {
		{ -16, -15 },
		{ -16, -4 },
		{ -16, 5 },
		{ -16, 15 },
		{ 16, -15 },
		{ 16, -4 },
		{ 16, 5 },
		{ 16, 15 },
		{ 0, -15 },
		{ 0, 15 },
	}
	for _, p in pilares do
		E.caixa("Pilar", p[1] - 0.9, p[1] + 0.9, 0, E.topo, p[2] - 0.9, p[2] + 0.9, P.pilastra, "Concrete")
	end

	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		E.laje(k, if k > 0 then { S.area } else nil, P.piso, P.pisoMat)
		S.andar(yb)
		E.pX("NucleoPorta", -6.1, 6.1, -6.75, yb, { { c = 0, larg = 10.6 } }, P.parede)
		if k > 0 then
			-- portas de elevador (decorativas) no bloco da esquerda
			E.caixa(
				"ElevadorQuadro",
				-12,
				-7.2,
				yb,
				yb + 7.8,
				-7.45,
				-7.25,
				{ 55, 55, 58 },
				"DiamondPlate",
				{ colide = false }
			)
			E.caixa(
				"ElevadorPortas",
				-11.6,
				-7.6,
				yb,
				yb + 7.2,
				-7.55,
				-7.45,
				{ 150, 150, 148 },
				"Metal",
				{ colide = false }
			)
			E.caixa(
				"ElevadorFresta",
				-9.66,
				-9.54,
				yb,
				yb + 7.2,
				-7.6,
				-7.55,
				{ 40, 40, 42 },
				"Metal",
				{ colide = false, consulta = false }
			)
		end
		local sala = E.sala(-hx + 0.5, hx - 0.5, -hz + 0.5, hz - 0.5, yb)
		sala.bloq(-13.5, 13.5, -7.8, 8.8)
		for _, p in pilares do
			sala.bloq(p[1] - 1.2, p[1] + 1.2, p[2] - 1.2, p[2] + 1.2)
		end
		sala.bloq(-6, 6, -hz + 0.5, -hz + 4)
		if k == 0 then
			sala.bloq(-5, 5, -hz + 0.5, -hz + 5)
			sala.poe("balcao_recepcao", 0, -12, 0, { w = 12 })
			sala.poe("sofa_recepcao", -15, -8.5, pi / 2, nil)
			sala.poe("sofa_recepcao", 15, -8.5, -pi / 2, nil)
			sala.poe("planta_vaso", -8, -hz + 2, 0, nil)
			sala.poe("planta_vaso", 8, -hz + 2, 0, nil)
			sala.poe("planta_vaso", -hx + 2, 14, 0, nil)
			sala.poe("planta_vaso", hx - 2, 14, 0, nil)
			sala.poe("bebedouro", 17, 17, 0, nil)
			sala.loot(-12, 14)
			sala.loot(12, 14)
			sala.loot(0, 14)
		else
			local nivel = rng.inteiro(0, 3)
			if nivel >= 1 then
				sala.poe("baia_escritorio", -10, -14, 0, nil)
			end
			if nivel >= 2 then
				sala.poe("baia_escritorio", 8, -14, 0, nil)
			end
			if nivel >= 3 then
				sala.poe("mesa_reuniao", 0, 15, 0, nil)
			end
			if rng.chance(0.3) then
				sala.poe("copiadora", hx - 2.5, 0, -pi / 2, nil)
			end
			if k % 3 == 1 or rng.chance(0.08) then
				sala.loot(rng.escolher({ -14, 14 }), rng.escolher({ -12, 11 }))
			end
		end
	end

	-- coroamento: degrau recuado, casa de máquinas, antenas
	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 9)
	local y0 = E.topo
	E.caixa("Coroa", -hx + 3, hx - 3, y0, y0 + 5.5, -hz + 3, hz - 3 - 14, P.nucleo, "Concrete")
	E.caixa("CoroaTeto", -hx + 2.4, hx - 2.4, y0 + 5.5, y0 + 6.4, -hz + 2.4, hz - 2.4 - 14, P.cornija, "Concrete")
	E.antena(0, -hz + 3, 30, true)
	E.antena(-10, -hz + 8, 20, true)
	E.antena(10, -hz + 8, 20, false)
	E.tanque(hx - 6, hz - 6, 7, 6, nil)
	E.condicionador(-hx + 6, hz - 5)
	E.condicionador(-hx + 6, hz - 11)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- Planta com corredor ao longo de X e escada na ponta esquerda (hotel, predio_misto)
-- ---------------------------------------------------------------------------------------------------------------
-- cfg: xs = borda de entrada da escada (dir "-x"); xp = x da parede entre o vestíbulo e os quartos
local function plantaLinha(E, S, k, yb, cfg)
	local hx, hz, P = E.hx, E.hz, E.P
	local pc = P.parede
	local xi, zi = hx - 0.5, hz - 0.5
	local xp = cfg.xp
	-- paredes do vestíbulo da escada (z = ±5,5) e do corredor (z = ±3,4)
	local suiteDoor = { { c = cfg.xs + 1.2, larg = 4.5, tipo = "porta", cor = P.porta } }
	E.pX("Vestibulo", -xi, xp, -5.5, yb, if k >= 0 then suiteDoor else nil, pc)
	E.pX("Vestibulo", -xi, xp, 5.5, yb, suiteDoor, pc)
	E.pZ("Divisoria", xp, -zi, -3.9, yb, nil, pc)
	E.pZ("Divisoria", xp, 3.9, zi, yb, nil, pc)
	-- paredes do corredor com portas dos quartos
	local nd = cfg.nDiv
	local larg = (xi - (xp + 0.5)) / nd
	local abF, abB = {}, {}
	for i = 1, nd do
		local c = xp + 0.5 + larg * (i - 0.5)
		table.insert(abF, { c = c, larg = 4.6, tipo = "porta", cor = P.porta })
		table.insert(abB, { c = c, larg = 4.6, tipo = "porta", cor = P.porta })
	end
	E.pX("Corredor", xp + 0.5, xi, -3.4, yb, abF, pc)
	E.pX("Corredor", xp + 0.5, xi, 3.4, yb, abB, pc)
	for i = 1, nd - 1 do
		local x = xp + 0.5 + larg * i
		E.pZ("Quarto", x, -zi, -3.9, yb, nil, pc)
		E.pZ("Quarto", x, 3.9, zi, yb, nil, pc)
	end
	-- divisória entre as suítes da esquerda e os quartos
	return larg
end

-- mobília de um quarto de hotel/apartamento: lado da porta `pl`, ocupação sorteada
local function quarto(E, x0, x1, z0, z1, yb, pl, pcx, pcz, ocup, comKit)
	local rng = E.rng
	local r = E.sala(x0, x1, z0, z1, yb)
	if pl == "+z" or pl == "-z" then
		r.porta(pl, pcx, 4.6)
	else
		r.porta(pl, pcz, 4.6)
	end
	if ocup then
		local lado = if pl == "+z" then "-z" else "+z"
		r.parede("cama_casal", lado, 0.5)
		if rng.chance(0.7) then
			r.parede("criado_mudo", lado, 0.97)
		end
		if comKit and rng.chance(0.5) then
			r.parede("guarda_roupa", "-x", 0.2)
		end
	end
	return r
end

-- ---------------------------------------------------------------------------------------------------------------
-- HOTEL (40×32, 5–7 andares)
-- ---------------------------------------------------------------------------------------------------------------
local function hotel(ctx, spec)
	local E = nova(ctx, spec, "hotel", 20)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local xs, xp = -4, 0
	local S = escadaU(E, xs, 0, "-x")

	E.postes(P.pilastra, P.mat)
	E.fachada({ sill = 3.4, jan = 5.6 })
	E.pilastras(P.pilastra, P.mat, 1.6, 6.2, "FB")
	E.pilastras(P.pilastra, P.mat, 1.6, 8.0, "LR")
	E.cornija(P.cornija, "Concrete", 0.4)
	E.terreoParedes(P.terreo, P.matTerreo, {
		F = { { -12, 9, "janela", 6, 2 }, { 0, 7, "porta", 7.5, 0, P.porta }, { 12, 9, "janela", 6, 2 } },
		B = { { -10, 8, "janela" }, { 10, 8, "janela" } },
		L = { { -6, 8, "janela" }, { 6, 8, "janela" } },
		R = { { -6, 8, "janela" }, { 6, 8, "janela" } },
	})
	E.entrada(0, 14, "HOTEL", { y = 8.8, placa = 8, corPlaca = { 40, 22, 22 } })
	-- toldo listrado do restaurante, no canto da frente (faixas inclinadas)
	for i, cx in { -14.5, -11, 11, 14.5 } do
		E.caixa(
			"Toldo",
			cx - 1.5,
			cx + 1.5,
			8.4 - (i % 2) * 0.2,
			8.9 - (i % 2) * 0.2,
			-hz - 2.2,
			-hz - 0.5,
			if i % 2 == 0 then P.letreiro else P.cornija,
			"Fabric",
			{ colide = false }
		)
	end
	-- letreiro vertical no canto
	local vert = E.caixa(
		"PlacaVertical",
		-hx - 0.5,
		-hx + 0.1,
		16,
		27,
		-hz - 1.2,
		-hz - 0.8,
		{ 30, 22, 22 },
		"Metal",
		{ colide = false }
	)
	letreiroTexto(vert, "H\nO\nT\nE\nL", P.letreiro)

	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		E.laje(k, if k > 0 then { S.area } else nil, P.piso, P.pisoMat)
		S.andar(yb)
		if k == 0 then
			-- térreo: recepção na frente, restaurante ao fundo, cozinha
			local pc = P.parede
			E.pX("Vestibulo", -hx + 0.5, xp, -5.5, yb, { { c = -8, larg = 8 } }, pc)
			E.pX("Vestibulo", -hx + 0.5, xp, 5.5, yb, { { c = -8, larg = 8 } }, pc)
			E.pX("Cozinha", xp + 0.5, hx - 0.5, 4.5, yb, { { c = 12, larg = 5.2, tipo = "porta", cor = P.porta } }, pc)
			local rec = E.sala(-hx + 0.5, hx - 0.5, -hz + 0.5, -5.0, yb)
			rec.bloq(-4, 4, -hz + 0.5, -hz + 4.5)
			rec.poe("balcao_recepcao", 6, -hz + 4.5 + 1.3, 0, { w = 8 })
			rec.parede("sofa_recepcao", "-z", 0.12)
			rec.parede("sofa_recepcao", "-z", 0.88)
			rec.parede("planta_vaso", "-x", 0.5)
			rec.parede("planta_vaso", "+x", 0.5)
			rec.noMuro("quadro", "+z", -12, 5.5)
			rec.loot(-13, -9)
			rec.loot(13, -9)
			local rest = E.sala(-hx + 0.5, hx - 0.5, 5.0, hz - 0.5, yb)
			rest.bloq(-6, 5, 5.0, 10)
			rest.bloq(xp - 0.5, hx - 0.5, 4.5, 10)
			rest.poe("balcao_bar", -9, hz - 2.2, 0, { w = 10 })
			rest.poe("mesa_restaurante", 4, 10, 0, nil)
			rest.poe("mesa_restaurante", 11, 10, 0, nil)
			rest.poe("mesa_restaurante", 15, 6, 0, nil)
			rest.loot(10, 12.5)
			local coz = E.sala(xp + 0.5, hx - 0.5, 5.0, hz - 0.5, yb)
			coz.parede("fogao", "-z", 0.2)
			coz.parede("geladeira", "+x", 0.7)
		else
			-- andar de quartos: 4 quartos pelo corredor + 2 suítes junto da escada
			local larg = plantaLinha(E, S, k, yb, { xs = xs, xp = xp, nDiv = 2 })
			local xi, zi = hx - 0.5, hz - 0.5
			for i = 1, 2 do
				local a, b =
					xp + 0.5 + larg * (i - 1) + (if i > 1 then 0.5 else 0),
					xp + 0.5 + larg * i - (if i < 2 then 0.5 else 0)
				local cx = (xp + 0.5) + larg * (i - 0.5)
				quarto(E, a, b, -zi, -3.9, yb, "+z", cx, nil, rng.chance(0.7), true)
				quarto(E, a, b, 3.9, zi, yb, "-z", cx, nil, rng.chance(0.7), true)
				-- número do quarto
				for _, lado in { -1, 1 } do
					local pl = E.caixa(
						"Numero",
						cx - 0.9,
						cx + 0.9,
						yb + 7.9,
						yb + 8.9,
						lado * 3.4 - 0.1 + (if lado > 0 then 0 else 0.2),
						lado * 3.4 + 0.1 + (if lado > 0 then 0 else 0.2),
						{ 25, 25, 25 },
						"Metal",
						{ colide = false, consulta = false }
					)
					letreiroTexto(
						pl,
						tostring(k * 10 + i + (if lado > 0 then 2 else 0)),
						{ 220, 200, 150 },
						if lado > 0 then "Back" else "Front"
					)
				end
			end
			-- suítes
			for _, sz in { -1, 1 } do
				local suite = E.sala(-xi, -0.5, if sz < 0 then -zi else 6.0, if sz < 0 then -6.0 else zi, yb)
				suite.porta(if sz < 0 then "+z" else "-z", cfgSuiteX or -2.85, 4.5)
				local oc = rng.chance(0.65)
				if oc then
					suite.parede("cama_casal", if sz < 0 then "-z" else "+z", 0.3)
					suite.parede("sofa", "-x", 0.5)
					if rng.chance(0.5) then
						suite.parede("criado_mudo", if sz < 0 then "-z" else "+z", 0.55)
					end
				end
				if rng.chance(0.6) then
					suite.loot(-14, sz * 10)
				end
			end
		end
	end

	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 8)
	local lado = if rng.chance(0.5) then -1 else 1
	E.tanque(lado * 10 + 6, 10, 7, 6, nil)
	E.condicionador(lado * 12, -10)
	E.condicionador(lado * 12, -5)
	E.antena(-lado * 6, 8, 14, false)
	local sg = E.caixa(
		"LetreiroTopo",
		-7,
		7,
		E.topo + 4.2,
		E.topo + 7.4,
		-hz - 0.3,
		-hz + 0.3,
		{ 40, 22, 22 },
		"Metal",
		{ colide = false }
	)
	letreiroTexto(sg, "HOTEL", P.letreiro)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- PRÉDIO MISTO (36×30, 3–5 andares): loja no térreo, apartamentos em cima
-- ---------------------------------------------------------------------------------------------------------------
local function predioMisto(ctx, spec)
	local E = nova(ctx, spec, "predio_misto", 20)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local xs, xp = -2, 1.5
	local S = escadaU(E, xs, 0, "-x")

	E.postes(P.pilastra, P.mat)
	E.fachada({ sill = 3.4, jan = 5.8 })
	E.pilastras(P.pilastra, P.mat, 1.8, 6.0, "FB")
	E.pilastras(P.pilastra, P.mat, 1.8, 7.0, "LR")
	E.cornija(P.cornija, "Concrete")
	E.terreoParedes(P.terreo, P.matTerreo, {
		F = { { -9, 12, "janela", 6.5, 1.2 }, { 8.5, 7, "porta", 7.5, 0, P.porta } },
		B = { { -8, 9, "janela" }, { 8, 9, "janela" } },
		L = { { 0, 8, "janela" } },
		R = { { 0, 8, "janela" } },
	})
	E.entX = 8.5
	-- toldo da loja
	for i = 0, 3 do
		E.caixa(
			"Toldo",
			-15 + i * 3.9,
			-11.2 + i * 3.9,
			8.5 - 0.1 * i,
			9.1 - 0.1 * i,
			-hz - 2.4,
			-hz - 0.5,
			if i % 2 == 0 then P.letreiro else P.cornija,
			"Fabric",
			{ colide = false }
		)
	end
	E.entrada(8.5, 8, "LOJA", { y = 8.6, placa = 8 })
	local pl = E.caixa(
		"PlacaLoja",
		-15,
		-3,
		9.6,
		11.4,
		-hz - 0.5,
		-hz - 0.1,
		{ 30, 30, 32 },
		"Metal",
		{ consulta = false }
	)
	letreiroTexto(pl, "MERCEARIA", P.letreiro)

	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		E.laje(k, if k > 0 then { S.area } else nil, P.piso, P.pisoMat)
		S.andar(yb)
		local pc = P.parede
		if k == 0 then
			-- loja na frente (inclui a área ao lado da escada), depósito atrás
			E.pX(
				"Fundos",
				-hx + 0.5,
				hx - 0.5,
				3.5,
				yb,
				{ { c = 8, larg = 5.2, tipo = "porta", cor = P.porta }, { c = -8, larg = 5.2 } },
				pc
			)
			E.pX("Escada", -hx + 0.5, -2, -5.5, yb, { { c = -10, larg = 5.2 } }, pc)
			local loja = E.sala(-hx + 0.5, hx - 0.5, -hz + 0.5, 3.0, yb)
			loja.bloq(4, 13, -hz + 0.5, -hz + 4.5)
			loja.bloq(-hx + 0.5, -1, -6, 3.0)
			loja.poe("balcao_loja", 8, -2, 0, nil)
			loja.parede("prateleira_loja", "+x", 0.35)
			loja.parede("prateleira_loja", "-z", 0.88)
			loja.poe("vitrine", 4, -7.5, 0, nil)
			loja.parede("arara_roupas", "-z", 0.4)
			loja.loot(-9, -9)
			loja.loot(11, 0.5)
			local dep = E.sala(-hx + 0.5, hx - 0.5, 4.0, hz - 0.5, yb)
			dep.porta("-z", 8, 5.2)
			dep.porta("-z", -8, 5.2)
			dep.parede("pilha_caixotes", "+z", 0.2)
			dep.parede("pilha_caixotes", "+z", 0.8)
			dep.parede("estante_industrial", "+x", 0.5)
			dep.loot(0, 9)
		else
			local larg = plantaLinha(E, S, k, yb, { xs = xs, xp = xp, nDiv = 1 })
			local xi, zi = hx - 0.5, hz - 0.5
			local cx = xp + 0.5 + larg * 0.5
			for _, sz in { -1, 1 } do
				local ocup = rng.chance(0.7)
				local r = quarto(
					E,
					xp + 0.5,
					xi,
					if sz < 0 then -zi else 3.9,
					if sz < 0 then -3.9 else zi,
					yb,
					if sz < 0 then "+z" else "-z",
					cx,
					nil,
					ocup,
					true
				)
				if ocup then
					r.parede("sofa", if sz < 0 then "+z" else "-z", 0.1)
					r.parede("geladeira", "+x", 0.5)
				end
				if rng.chance(0.75) then
					for _, lx in { 14.5, 4.5, 8, 12 } do
						if r.loot(lx, sz * 11.2) or r.loot(lx, sz * 6.5) then
							break
						end
					end
				end
				-- suíte da esquerda
				local suite = E.sala(-xi, 0.9, if sz < 0 then -zi else 6.0, if sz < 0 then -6.0 else zi, yb)
				suite.porta(if sz < 0 then "+z" else "-z", xs - 1.0, 4.5)
				if rng.chance(0.65) then
					suite.parede("cama_casal", if sz < 0 then "-z" else "+z", 0.3)
					suite.parede("guarda_roupa", "-x", 0.5)
				end
			end
		end
	end

	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 8)
	local lado = if rng.chance(0.5) then -1 else 1
	E.tanque(lado * 9 + 4, 8, 6, 5, nil)
	E.condicionador(lado * 11, -6)
	E.antena(-lado * 10, 8, 12, false)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- GARAGEM (44×36, 3–4 andares): andares abertos com pilares, rampa de carros e escada
-- ---------------------------------------------------------------------------------------------------------------
local function garagem(ctx, spec)
	local E = nova(ctx, spec, "garagem", 14)
	local P, rng, n = E.P, E.rng, E.n
	local hx, hz = E.hx, E.hz
	local xi, zi = hx - 0.5, hz - 0.5
	local S = escadaU(E, 0, 2.0, "+z")

	-- casca aberta: mureta, grade, viga alta e pilastras nos quatro lados
	E.postes(P.pilastra, P.mat)
	for _, s in E.lados do
		for k = 0, n - 1 do
			local y = k * H + (if k == 0 then TOPO0 else 0)
			if not (k == 0 and s.id == "F") then
				E.faixa(s, y, y + 4.2, "Mureta", P.faixa, P.mat, 1, 0)
				E.faixa(s, y + 6.4, y + 7.0, "Grade", P.cornija, "Metal", 0.6, 0, { colide = true })
			end
			E.faixa(s, k * H + 9.4, (k + 1) * H, "Viga", P.faixa, P.mat, 1, 0)
		end
		E.faixa(s, E.topo, E.topo + 3.6, "Parapeito", P.faixa, P.mat, 1, 0)
	end
	E.pilastras(P.pilastra, P.mat, 1.8, 7.5, "BLR")
	E.pilastras(P.pilastra, P.mat, 1.8, 7.5, "F", H, nil)
	E.cornija(P.cornija, "Concrete")
	-- térreo: frente aberta com a boca da garagem (cancela, cabine de pagamento) e pilares de entrada
	local F = E.lados[1]
	E.faixa(F, 0, 2.2, "MuretaF", P.faixa, P.mat, 1, 0, nil, -hx - 0.5, -9)
	E.faixa(F, 0, 2.2, "MuretaF", P.faixa, P.mat, 1, 0, nil, 9, hx + 0.5)
	E.faixa(F, 9.4, H, "VigaF", P.faixa, P.mat, 1, 0, nil, F.a, F.b)
	E.faixa(F, 7.4, 9.4, "VigaPlaca", P.terreo, "Concrete", 1.2, 0.1, nil, -9, 9)
	local pl = E.caixa(
		"PlacaGaragem",
		-6,
		6,
		7.9,
		9.0,
		-hz - 0.9,
		-hz - 0.6,
		{ 30, 30, 32 },
		"Metal",
		{ consulta = false }
	)
	letreiroTexto(pl, "ESTACIONAMENTO", P.letreiro)
	-- cabine de pagamento e cancela
	E.caixa("Cabine", -8.8, -6, 0, 7.4, -hz + 2, -hz + 5.5, { 130, 134, 130 }, "Metal")
	E.caixa(
		"CabineJanela",
		-8.5,
		-6.2,
		3.8,
		6.2,
		-hz + 1.85,
		-hz + 2.0,
		{ 60, 80, 90 },
		"Glass",
		{ transparencia = 0.5, colide = false }
	)
	E.caixa("CabineTeto", -9.4, -5.4, 7.4, 8.0, -hz + 1.4, -hz + 6.1, P.cornija, "Concrete")
	E.caixa("Cancela", -6, -0.5, 4.3, 4.7, -hz + 3.6, -hz + 4.0, { 200, 190, 60 }, "Metal", { colide = false })

	-- pilares internos (altura total)
	local pil = {}
	for _, x in { -14, 0, 14 } do
		for _, z in { -10, 4, 14 } do
			table.insert(pil, { x, z })
			E.caixa("Pilar", x - 0.9, x + 0.9, 0, E.topo, z - 0.9, z + 0.9, P.pilastra, "Concrete")
		end
	end

	local carros = 0
	local cores =
		{ { 110, 40, 36 }, { 40, 70, 90 }, { 150, 150, 140 }, { 52, 52, 56 }, { 100, 90, 50 }, { 60, 90, 70 } }
	for k = 0, n - 1 do
		local yb = if k == 0 then TOPO0 else k * H
		-- rampas alternadas: sobem do andar k ao andar k+1 (esquerda nos pares, direita nos ímpares)
		local colunaX = if k % 2 == 0 then -16.5 else 16.5
		local furos = {}
		if k > 0 then
			local anterior = if (k - 1) % 2 == 0 then -16.5 else 16.5
			table.insert(furos, { x0 = anterior - 4.0, x1 = anterior + 4.0, z0 = -12.6, z1 = 12.6 })
			table.insert(furos, S.area)
		end
		E.laje(k, if k > 0 then furos else nil, P.piso, P.pisoMat)
		S.andar(yb)
		-- paredes do núcleo da escada
		E.pX("NucleoEscada", -5.6, 5.6, 1.0, yb, { { c = 0, larg = 10.6 } }, P.parede)
		E.pZ("NucleoEscada", -5.6, 1.5, zi, yb, nil, P.parede)
		E.pZ("NucleoEscada", 5.6, 1.5, zi, yb, nil, P.parede)
		if k < n - 1 then
			-- rampa de carros até o próximo andar
			local z0, z1 = -12, 12
			if k % 2 == 1 then
				z0, z1 = 12, -12
			end
			ctx.rampa(E.modelo, E.cf, "Rampa", colunaX, yb, z0, colunaX, (k + 1) * H, z1, 8.0, 0.9, P.faixa, "Concrete")
			E.caixa(
				"MeioFioRampa",
				colunaX + 4.0,
				colunaX + 4.4 + (if colunaX > 0 then -0.0 else 0),
				yb,
				yb + 1.2,
				-12.5,
				12.5,
				P.cornija,
				"Concrete",
				{ colide = true }
			)
		end
		-- vagas: marcações e carros
		local fileiras = { { -9.5 }, { 8 } }
		local sala = E.sala(-xi, xi, -zi, zi, yb)
		sala.bloq(-6.5, 6.5, 0.5, zi)
		for _, p in pil do
			sala.bloq(p[1] - 1.5, p[1] + 1.5, p[2] - 1.5, p[2] + 1.5)
		end
		sala.bloq(colunaX - 5, colunaX + 5, -zi, zi)
		if k == 0 then
			sala.bloq(-hx, hx, -zi, -zi + 7.5)
		end
		sala.loot(if colunaX < 0 then 8 else -8, if k % 2 == 0 then -3 else 6)
		for _, z in { -4.2, 8.5, 6.0 } do
			local linhaX = {}
			for i = -1, 1 do
				table.insert(linhaX, 7 * i + (if i == 0 then 0 else (if i < 0 then -1 else 1)) * 7)
			end
			if z ~= 6.0 and rng.chance(0.85) then
				for i, x in { -9.5, 9.5, 17.5, -17.5 } do
					if carros < 14 and rng.chance(0.4) and abs(x - colunaX) > 7.5 then
						local rot = (if z < 0 then 0 else pi) + (if rng.chance(0.1) then pi / 2 else 0)
						local ok = true
						for _, o in sala.obst do
							local ex = (if abs(math.sin(rot)) > 0.5 then 11 else 5.6) / 2
							local ez = (if abs(math.sin(rot)) > 0.5 then 5.6 else 11) / 2
							if x - ex < o[2] and x + ex > o[1] and z - ez < o[4] and z + ez > o[3] then
								ok = false
							end
						end
						if ok and abs(x) <= xi - 3 then
							Props.carro(ctx, E.modelo, E.cf * CFrame.new(x, yb, z) * CFrame.Angles(0, rot, 0), {
								variante = rng.inteiro(1, 5),
								cor = rng.escolher(cores),
								rng = rng,
							})
							carros += 1
							E.nMov += 1
							sala.bloq(x - 2.9, x + 2.9, z - 5.7, z + 5.7)
						end
					end
				end
			end
		end
		-- marcas de vaga (finas, sem colisão)
		for i = -3, 3 do
			E.caixa(
				"MarcaVaga",
				i * 6.4 - 0.15,
				i * 6.4 + 0.15,
				yb + 0.02,
				yb + 0.06,
				-zi + 0.5,
				-zi + 11,
				{ 190, 190, 120 },
				"Concrete",
				{ colide = false, consulta = false, sombra = false }
			)
		end
		fileiras = fileiras
	end

	E.laje(n, { S.area }, P.topo, "Concrete")
	casaEscada(E, S, P.topo, "Concrete", P.cornija, 8)
	E.antena(-14, -10, 12, false)
	E.condicionador(14, 12)
	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- Paletas (4–6 por variante) e registro
-- ---------------------------------------------------------------------------------------------------------------
local function pal(t)
	return t
end

local PAL_APT = {
	pal({
		mat = "Brick",
		matTerreo = "Concrete",
		faixa = { 124, 84, 70 },
		pilastra = { 140, 100, 82 },
		cornija = { 150, 140, 125 },
		terreo = { 96, 92, 88 },
		vidro = { 70, 90, 98 },
		topo = { 90, 86, 82 },
		letreiro = { 215, 190, 120 },
		porta = { 70, 52, 40 },
		parede = { 150, 138, 115 },
		piso = { 70, 48, 36 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Brick",
		faixa = { 96, 110, 98 },
		pilastra = { 120, 126, 118 },
		cornija = { 140, 142, 136 },
		terreo = { 108, 84, 72 },
		vidro = { 66, 84, 90 },
		topo = { 84, 88, 84 },
		letreiro = { 190, 210, 160 },
		porta = { 60, 70, 60 },
		parede = { 120, 122, 118 },
		piso = { 64, 52, 42 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 150, 138, 115 },
		pilastra = { 166, 154, 130 },
		cornija = { 176, 168, 150 },
		terreo = { 110, 100, 88 },
		vidro = { 72, 86, 92 },
		topo = { 100, 94, 86 },
		letreiro = { 220, 140, 90 },
		porta = { 90, 60, 44 },
		parede = { 150, 138, 115 },
		piso = { 80, 66, 52 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 120, 122, 118 },
		pilastra = { 138, 140, 136 },
		cornija = { 160, 160, 154 },
		terreo = { 78, 80, 82 },
		vidro = { 64, 82, 94 },
		topo = { 92, 94, 94 },
		letreiro = { 200, 200, 190 },
		porta = { 54, 58, 62 },
		parede = { 130, 130, 126 },
		piso = { 70, 70, 68 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Brick",
		matTerreo = "Brick",
		faixa = { 104, 78, 64 },
		pilastra = { 122, 92, 76 },
		cornija = { 140, 128, 112 },
		terreo = { 84, 66, 56 },
		vidro = { 60, 78, 84 },
		topo = { 80, 70, 64 },
		letreiro = { 200, 170, 110 },
		porta = { 50, 40, 34 },
		parede = { 140, 130, 110 },
		piso = { 66, 44, 34 },
		pisoMat = "WoodPlanks",
	}),
}

local PAL_ESC = {
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 112, 116, 114 },
		pilastra = { 138, 140, 136 },
		cornija = { 168, 168, 160 },
		terreo = { 70, 72, 76 },
		vidro = { 60, 90, 112 },
		topo = { 84, 86, 88 },
		letreiro = { 170, 210, 235 },
		porta = { 44, 46, 52 },
		parede = { 160, 160, 154 },
		piso = { 90, 90, 92 },
		pisoMat = "Slate",
	}),
	pal({
		mat = "Limestone",
		matTerreo = "Granite",
		faixa = { 160, 154, 138 },
		pilastra = { 178, 170, 150 },
		cornija = { 190, 184, 166 },
		terreo = { 80, 74, 66 },
		vidro = { 78, 96, 90 },
		topo = { 104, 100, 92 },
		letreiro = { 220, 200, 140 },
		porta = { 60, 48, 36 },
		parede = { 170, 164, 148 },
		piso = { 100, 92, 80 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Marble",
		faixa = { 74, 80, 86 },
		pilastra = { 96, 102, 108 },
		cornija = { 130, 134, 138 },
		terreo = { 150, 150, 146 },
		vidro = { 56, 76, 98 },
		topo = { 70, 74, 80 },
		letreiro = { 130, 190, 230 },
		porta = { 38, 42, 50 },
		parede = { 140, 144, 146 },
		piso = { 80, 84, 90 },
		pisoMat = "Slate",
	}),
	pal({
		mat = "Sandstone",
		matTerreo = "Granite",
		faixa = { 150, 126, 100 },
		pilastra = { 168, 142, 112 },
		cornija = { 182, 158, 128 },
		terreo = { 90, 70, 56 },
		vidro = { 76, 92, 94 },
		topo = { 110, 94, 80 },
		letreiro = { 230, 170, 100 },
		porta = { 70, 50, 38 },
		parede = { 168, 150, 126 },
		piso = { 92, 76, 60 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 96, 108, 100 },
		pilastra = { 118, 130, 122 },
		cornija = { 146, 154, 148 },
		terreo = { 64, 76, 70 },
		vidro = { 62, 94, 90 },
		topo = { 82, 92, 88 },
		letreiro = { 170, 230, 200 },
		porta = { 40, 52, 48 },
		parede = { 150, 158, 152 },
		piso = { 84, 90, 86 },
		pisoMat = "Slate",
	}),
}

local PAL_TORRE = {
	pal({
		mat = "Concrete",
		matTerreo = "Marble",
		faixa = { 52, 58, 66 },
		pilastra = { 80, 86, 94 },
		cornija = { 120, 126, 134 },
		terreo = { 150, 150, 148 },
		vidro = { 54, 84, 108 },
		topo = { 66, 70, 76 },
		nucleo = { 96, 98, 100 },
		letreiro = { 150, 205, 240 },
		porta = { 36, 40, 46 },
		parede = { 150, 152, 150 },
		piso = { 150, 150, 146 },
		pisoMat = "Marble",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 60, 62, 60 },
		pilastra = { 92, 94, 90 },
		cornija = { 130, 130, 124 },
		terreo = { 44, 46, 48 },
		vidro = { 64, 96, 84 },
		topo = { 72, 74, 72 },
		nucleo = { 100, 100, 96 },
		letreiro = { 190, 230, 170 },
		porta = { 34, 38, 38 },
		parede = { 150, 150, 144 },
		piso = { 70, 74, 74 },
		pisoMat = "Marble",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Marble",
		faixa = { 84, 70, 60 },
		pilastra = { 120, 100, 84 },
		cornija = { 156, 136, 112 },
		terreo = { 130, 116, 100 },
		vidro = { 76, 90, 100 },
		topo = { 90, 78, 68 },
		nucleo = { 110, 98, 88 },
		letreiro = { 230, 190, 120 },
		porta = { 54, 42, 34 },
		parede = { 160, 146, 126 },
		piso = { 140, 124, 104 },
		pisoMat = "Marble",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 40, 48, 60 },
		pilastra = { 70, 80, 96 },
		cornija = { 108, 118, 134 },
		terreo = { 56, 62, 72 },
		vidro = { 50, 78, 112 },
		topo = { 58, 64, 74 },
		nucleo = { 84, 90, 100 },
		letreiro = { 120, 180, 245 },
		porta = { 30, 36, 46 },
		parede = { 140, 144, 150 },
		piso = { 110, 114, 120 },
		pisoMat = "Slate",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Marble",
		faixa = { 108, 108, 104 },
		pilastra = { 136, 136, 130 },
		cornija = { 170, 168, 160 },
		terreo = { 160, 156, 148 },
		vidro = { 70, 94, 106 },
		topo = { 96, 96, 92 },
		nucleo = { 120, 120, 116 },
		letreiro = { 220, 220, 200 },
		porta = { 50, 50, 52 },
		parede = { 168, 166, 158 },
		piso = { 170, 166, 156 },
		pisoMat = "Marble",
	}),
}

local PAL_HOTEL = {
	pal({
		mat = "Brick",
		matTerreo = "Granite",
		faixa = { 120, 84, 70 },
		pilastra = { 150, 112, 92 },
		cornija = { 172, 156, 130 },
		terreo = { 70, 54, 48 },
		vidro = { 76, 80, 84 },
		topo = { 90, 78, 72 },
		letreiro = { 230, 170, 90 },
		porta = { 70, 36, 30 },
		parede = { 160, 140, 118 },
		piso = { 90, 40, 36 },
		pisoMat = "Fabric",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Marble",
		faixa = { 150, 140, 120 },
		pilastra = { 174, 164, 142 },
		cornija = { 190, 180, 156 },
		terreo = { 120, 110, 96 },
		vidro = { 80, 88, 90 },
		topo = { 110, 102, 90 },
		letreiro = { 235, 200, 120 },
		porta = { 76, 56, 40 },
		parede = { 170, 158, 134 },
		piso = { 80, 64, 90 },
		pisoMat = "Fabric",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 96, 106, 112 },
		pilastra = { 122, 132, 138 },
		cornija = { 156, 162, 166 },
		terreo = { 56, 64, 72 },
		vidro = { 66, 88, 104 },
		topo = { 80, 88, 94 },
		letreiro = { 150, 200, 230 },
		porta = { 40, 52, 62 },
		parede = { 150, 156, 158 },
		piso = { 60, 84, 96 },
		pisoMat = "Fabric",
	}),
	pal({
		mat = "Brick",
		matTerreo = "Brick",
		faixa = { 98, 76, 60 },
		pilastra = { 120, 94, 74 },
		cornija = { 150, 130, 104 },
		terreo = { 76, 58, 46 },
		vidro = { 70, 80, 82 },
		topo = { 84, 72, 62 },
		letreiro = { 220, 150, 80 },
		porta = { 56, 40, 30 },
		parede = { 150, 130, 108 },
		piso = { 70, 90, 66 },
		pisoMat = "Fabric",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 94, 112, 100 },
		pilastra = { 116, 134, 120 },
		cornija = { 150, 164, 150 },
		terreo = { 64, 80, 70 },
		vidro = { 64, 90, 90 },
		topo = { 80, 94, 86 },
		letreiro = { 200, 230, 180 },
		porta = { 44, 60, 52 },
		parede = { 150, 160, 148 },
		piso = { 96, 70, 60 },
		pisoMat = "Fabric",
	}),
}

local PAL_MISTO = {
	pal({
		mat = "Brick",
		matTerreo = "Concrete",
		faixa = { 132, 96, 74 },
		pilastra = { 150, 112, 88 },
		cornija = { 170, 154, 126 },
		terreo = { 88, 78, 70 },
		vidro = { 76, 86, 90 },
		topo = { 92, 80, 72 },
		letreiro = { 220, 180, 110 },
		porta = { 66, 46, 34 },
		parede = { 156, 140, 114 },
		piso = { 74, 52, 38 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Brick",
		faixa = { 126, 128, 118 },
		pilastra = { 146, 148, 138 },
		cornija = { 168, 168, 156 },
		terreo = { 120, 80, 68 },
		vidro = { 70, 88, 94 },
		topo = { 96, 98, 92 },
		letreiro = { 210, 120, 100 },
		porta = { 58, 62, 54 },
		parede = { 150, 150, 140 },
		piso = { 68, 56, 44 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 104, 120, 106 },
		pilastra = { 126, 142, 126 },
		cornija = { 156, 168, 150 },
		terreo = { 78, 92, 82 },
		vidro = { 68, 90, 90 },
		topo = { 88, 100, 90 },
		letreiro = { 200, 220, 150 },
		porta = { 46, 60, 50 },
		parede = { 140, 150, 134 },
		piso = { 70, 58, 46 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Brick",
		matTerreo = "Brick",
		faixa = { 110, 82, 70 },
		pilastra = { 134, 102, 86 },
		cornija = { 160, 146, 126 },
		terreo = { 70, 58, 52 },
		vidro = { 72, 80, 84 },
		topo = { 84, 72, 66 },
		letreiro = { 180, 200, 210 },
		porta = { 48, 52, 58 },
		parede = { 154, 140, 120 },
		piso = { 72, 54, 42 },
		pisoMat = "WoodPlanks",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Granite",
		faixa = { 152, 140, 116 },
		pilastra = { 170, 158, 132 },
		cornija = { 186, 176, 150 },
		terreo = { 82, 78, 74 },
		vidro = { 74, 86, 90 },
		topo = { 108, 100, 88 },
		letreiro = { 230, 160, 90 },
		porta = { 80, 56, 42 },
		parede = { 160, 148, 124 },
		piso = { 84, 66, 50 },
		pisoMat = "WoodPlanks",
	}),
}

local PAL_GAR = {
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 120, 122, 118 },
		pilastra = { 140, 140, 136 },
		cornija = { 164, 164, 156 },
		terreo = { 96, 98, 96 },
		vidro = { 70, 80, 84 },
		topo = { 100, 102, 100 },
		letreiro = { 230, 200, 80 },
		porta = { 60, 62, 62 },
		parede = { 130, 132, 128 },
		piso = { 84, 86, 84 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 104, 108, 112 },
		pilastra = { 124, 128, 132 },
		cornija = { 150, 154, 158 },
		terreo = { 80, 84, 90 },
		vidro = { 66, 78, 88 },
		topo = { 90, 94, 98 },
		letreiro = { 120, 190, 240 },
		porta = { 48, 52, 58 },
		parede = { 120, 124, 128 },
		piso = { 72, 76, 80 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Concrete",
		matTerreo = "Concrete",
		faixa = { 138, 128, 108 },
		pilastra = { 156, 146, 124 },
		cornija = { 176, 168, 146 },
		terreo = { 108, 100, 88 },
		vidro = { 74, 82, 84 },
		topo = { 112, 104, 92 },
		letreiro = { 230, 130, 80 },
		porta = { 70, 60, 48 },
		parede = { 140, 132, 114 },
		piso = { 90, 84, 72 },
		pisoMat = "Concrete",
	}),
	pal({
		mat = "Brick",
		matTerreo = "Concrete",
		faixa = { 112, 84, 70 },
		pilastra = { 134, 104, 88 },
		cornija = { 158, 142, 124 },
		terreo = { 88, 82, 78 },
		vidro = { 70, 80, 84 },
		topo = { 96, 86, 78 },
		letreiro = { 220, 190, 90 },
		porta = { 60, 48, 40 },
		parede = { 134, 124, 108 },
		piso = { 78, 74, 70 },
		pisoMat = "Concrete",
	}),
}

local function registrar(nome: string, paletas, fn)
	M.catalogo[nome] = {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = fn(ctx, spec)
			M.ultimaContagem = { moveis = E.nMov, andares = E.n }
			return E.modelo,
				{
					loot = E.loot,
					frente = { E.entX or 0, -(E.d / 2 + 2) },
					portaria = { E.entX or 0, -E.hz },
				}
		end,
	}
end

registrar("apartamentos", PAL_APT, apartamentos)
registrar("escritorio", PAL_ESC, escritorio)
registrar("torre", PAL_TORRE, torre)
registrar("hotel", PAL_HOTEL, hotel)
registrar("predio_misto", PAL_MISTO, predioMisto)
registrar("garagem", PAL_GAR, garagem)

return M
