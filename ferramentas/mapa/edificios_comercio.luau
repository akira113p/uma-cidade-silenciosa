-- Edifícios de comércio (agente E3): mercado, lojas, farmácia, restaurante, bar, banco, posto, lanchonete, motel, oficina.
-- Contrato: docs/mapa-v2.md §5 e catalogo_contrato.luau. Tudo em coordenadas LOCAIS ao spec.cf (frente = −Z).
-- Cada planta é escrita num "mundo de projeto"; o rng espelha em X (E.s = ±1) e as funções E.* aplicam o espelho.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum
local UDim2 = roblox.UDim2

local Mob = require("./mobilia")
local Props = require("./props")

local PI = math.pi
local H = 12 -- pé-direito
local PISO_Y = 0.1 -- topo do piso interno do térreo (o pad fica em 0)

local M = { catalogo = {} }

-- ---------------------------------------------------------------------------------------------------------------
-- Paletas
-- ---------------------------------------------------------------------------------------------------------------
-- parede, rodapé/moldura, toldo A, toldo B, piso interno
local BASES = {
	{ { 150, 138, 115 }, { 110, 70, 55 }, { 125, 45, 42 }, { 185, 178, 160 }, { 98, 94, 88 } },
	{ { 120, 128, 122 }, { 70, 85, 95 }, { 50, 85, 110 }, { 175, 180, 175 }, { 92, 95, 98 } },
	{ { 160, 150, 130 }, { 95, 100, 70 }, { 85, 110, 70 }, { 180, 175, 150 }, { 100, 92, 80 } },
	{ { 135, 125, 120 }, { 120, 60, 50 }, { 150, 90, 45 }, { 190, 175, 150 }, { 95, 88, 84 } },
	{ { 110, 118, 108 }, { 60, 75, 65 }, { 70, 70, 95 }, { 160, 160, 150 }, { 90, 92, 88 } },
	{ { 142, 140, 132 }, { 88, 62, 52 }, { 100, 55, 70 }, { 175, 170, 165 }, { 86, 84, 80 } },
}

-- letreiros: { fundo, letra }
local function paletasDe(offset: number, n: number, letreiros)
	local lista = {}
	for i = 1, n do
		local b = BASES[(offset + i - 2) % #BASES + 1]
		local l = letreiros[(i - 1) % #letreiros + 1]
		table.insert(lista, {
			parede = b[1],
			rodape = b[2],
			toldoA = b[3],
			toldoB = b[4],
			piso = b[5],
			letreiro = l[1],
			letra = l[2],
		})
	end
	return lista
end

-- ---------------------------------------------------------------------------------------------------------------
-- Ambiente de construção (E): tudo espelhado em X por E.s
-- ---------------------------------------------------------------------------------------------------------------
local function texto(ctx, parte, txt: string, cor, face: string?)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId[face or "Front"]
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 36
	g.Parent = parte
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = txt
	t.TextScaled = true
	t.TextColor3 = ctx.rgb(cor)
	t.Parent = g
end

local function novoEnv(ctx, spec, variante: string, tipo: string, w: number, d: number, andaresPad: number, paletas)
	local rng = spec.rng or ctx.rng("comercio_" .. variante)
	local base = spec.paleta or rng.escolher(paletas)
	local A = spec.andares or andaresPad
	local s = if rng.chance(0.5) then -1 else 1
	local planta = rng.inteiro(1, 2)
	local cf = spec.cf
	local modelo = ctx.modeloConstrucao(spec, tipo, variante, w, d, A * H + 5, A)

	local p = {}
	for k, v in base do
		p[k] = v
	end
	p.telhado = p.telhado or { 62, 58, 56 }
	p.ferro = p.ferro or { 70, 72, 74 }
	p.interna = p.interna or ctx.misturar(p.parede, { 128, 126, 118 }, 0.4)
	p.moldura = p.moldura or p.rodape
	p.porta = p.porta or p.ferro

	local E = {
		ctx = ctx,
		rng = rng,
		p = p,
		w = w,
		d = d,
		andares = A,
		planta = planta,
		s = s,
		cf = cf,
		modelo = modelo,
		lootLista = {},
	}

	function E.limites(x0: number, x1: number, z0: number, z1: number)
		E.x0, E.x1, E.z0, E.z1 = x0, x1, z0, z1
		E.ix0, E.ix1, E.iz0, E.iz1 = x0 + 0.5, x1 - 0.5, z0 + 0.5, z1 - 0.5
		E.sala = { x0 = E.ix0, x1 = E.ix1, z0 = E.iz0, z1 = E.iz1 }
	end
	E.limites(-w / 2 + 1, w / 2 - 1, -d / 2 + 3.5, d / 2 - 1)

	local function copiaOp(op, ...)
		if not op then
			return nil
		end
		local o = {}
		for k, v in op do
			o[k] = v
		end
		if o.rotY then
			o.rotY = o.rotY * s
		end
		return o
	end

	function E.bl(nome: string, cx, cy, cz, sx, sy, sz, cor, mat: string, op)
		return ctx.bloco(modelo, cf, nome, cx * s, cy, cz, sx, sy, sz, cor, mat, copiaOp(op))
	end
	function E.cil(nome: string, cx, cy, cz, diam, comp, cor, mat: string, op)
		return ctx.cilindro(modelo, cf, nome, cx * s, cy, cz, diam, comp, cor, mat, op)
	end
	function E.rampa(nome: string, x0, y0, z0, x1, y1, z1, larg, esp, cor, mat: string, op)
		return ctx.rampa(modelo, cf, nome, x0 * s, y0, z0, x1 * s, y1, z1, larg, esp, cor, mat, op)
	end

	-- parede de (x,z) a (x,z) de projeto. op: nome, base, alt, esp, cor, mat, ext
	function E.parede(a, b, ab, op)
		op = op or {}
		local o = nil
		if op.ext ~= nil then
			o = { ext = op.ext }
		end
		return ctx.parede(
			modelo,
			cf,
			op.nome or "Parede",
			{ a[1] * s, a[2] },
			{ b[1] * s, b[2] },
			op.base or 0,
			op.alt or H,
			op.esp or 1,
			op.cor or p.interna,
			op.mat or "Concrete",
			ab,
			o
		)
	end

	function E.piso(nome: string, x0, x1, z0, z1, topo, esp, cor, mat: string, furos, op)
		local fs = nil
		if furos then
			fs = {}
			for _, f in furos do
				table.insert(
					fs,
					{ x0 = math.min(f.x0 * s, f.x1 * s), x1 = math.max(f.x0 * s, f.x1 * s), z0 = f.z0, z1 = f.z1 }
				)
			end
		end
		return ctx.piso(
			modelo,
			cf,
			nome,
			math.min(x0 * s, x1 * s),
			math.max(x0 * s, x1 * s),
			z0,
			z1,
			topo,
			esp,
			cor,
			mat,
			fs,
			op
		)
	end

	-- devolve o retângulo (projeto) ocupado
	function E.escada(nome: string, x, z, dir: string, yBase, altura, larg, cor, mat: string, op)
		local d2 = dir
		if s < 0 then
			d2 = if dir == "+x" then "-x" elseif dir == "-x" then "+x" else dir
		end
		local r = ctx.escada(modelo, cf, nome, x * s, z, d2, yBase, altura, larg, cor, mat, op)
		if s < 0 then
			r = { x0 = -r.x1, x1 = -r.x0, z0 = r.z0, z1 = r.z1, comprimento = r.comprimento }
		end
		return r
	end

	-- mobília: x,z de projeto; y = topo do piso (padrão PISO_Y)
	function E.mob(nome: string, x, z, rot, op, y)
		local o = op or {}
		o.rng = o.rng or rng
		return Mob.colocar(ctx, modelo, nome, cf, x * s, y or PISO_Y, z, (rot or 0) * s, o)
	end
	function E.mobParede(nome: string, lado: string, aoLongo, sala, op, y, folga)
		local x, z, rot = Mob.paraParede(nome, lado, aoLongo, sala or E.sala, folga)
		return E.mob(nome, x, z, rot, op, y)
	end

	function E.carro(x, z, rot, variante: number, y)
		local op = { variante = variante, rng = rng }
		return Props.carro(ctx, modelo, cf * CFrame.new(x * s, y or PISO_Y, z) * CFrame.Angles(0, rot * s, 0), op)
	end

	function E.loot(x, z, y, tabela)
		table.insert(E.lootLista, { x = x * s, y = y or PISO_Y, z = z, tabela = tabela })
	end

	function E.texto(parte, txt: string, cor, face: string?)
		texto(ctx, parte, txt, cor, face)
	end

	return E
end

-- ---------------------------------------------------------------------------------------------------------------
-- Janelas e seus enfeites (tapume, grade, caco de vidro)
-- ---------------------------------------------------------------------------------------------------------------
local function sortearEstado(E, pOk: number)
	local r = E.rng.rnd()
	if r < pOk then
		return "ok"
	elseif r < pOk + (1 - pOk) * 0.45 then
		return "quebrada"
	elseif r < pOk + (1 - pOk) * 0.8 then
		return "tapume"
	end
	return "grade"
end

-- plano "z": parede ao longo de X na linha z = linha; plano "x": parede ao longo de Z em x = linha.
-- sinal = lado de fora (−1 → −Z/−X, +1 → +Z/+X), em coordenadas de projeto.
local function adornoJanela(E, plano: string, pos, linha, sinal, larg, yc, alt, est: string)
	local fora = linha + sinal * 0.7
	local dentro = linha - sinal * 1.6
	local madeira = { 92, 74, 56 }
	if est == "tapume" then
		local ang = math.atan2(alt, larg)
		local comp = math.sqrt(larg * larg + alt * alt) + 0.6
		for _, a in { ang, -ang } do
			if plano == "z" then
				E.bl("Tapume", pos, yc, fora, comp, 0.7, 0.3, madeira, "WoodPlanks", {
					colide = false,
					rot = CFrame.Angles(0, 0, a * E.s),
				})
			else
				E.bl("Tapume", fora, yc, pos, 0.3, 0.7, comp, madeira, "WoodPlanks", {
					colide = false,
					rot = CFrame.Angles(-a, 0, 0),
				})
			end
		end
	elseif est == "grade" then
		if plano == "z" then
			E.bl("GradeJanela", pos, yc + alt * 0.2, fora, larg + 0.4, alt * 0.6, 0.25, E.p.ferro, "Metal", {
				colide = false,
				consulta = false,
			})
		else
			E.bl("GradeJanela", fora, yc + alt * 0.2, pos, 0.25, alt * 0.6, larg + 0.4, E.p.ferro, "Metal", {
				colide = false,
				consulta = false,
			})
		end
	elseif est == "quebrada" then
		local vidro = { 150, 175, 190 }
		for i = 1, 3 do
			local k = (i - 2) * larg * 0.28
			local t = (E.rng.rnd() - 0.5) * 0.8
			if plano == "z" then
				E.bl("Caco", pos + k, 0.15, dentro + t, 0.9, 0.12, 0.6, vidro, "Glass", {
					colide = false,
					consulta = false,
					sombra = false,
					transparencia = 0.5,
					rotY = i,
				})
			else
				E.bl("Caco", dentro + t, 0.15, pos + k, 0.6, 0.12, 0.9, vidro, "Glass", {
					colide = false,
					consulta = false,
					sombra = false,
					transparencia = 0.5,
					rotY = i,
				})
			end
		end
	end
end

-- parede lateral/fundo com janelas. lista de { pos, larg, est?, peit?, alt? }; extra = aberturas adicionais
-- (com de relativo ao início ini). Devolve nada. plano "z": parede em z=linha de x=ini a x=fim.
local function paredeJanelas(E, plano: string, linha, ini, fim, base, lista, extra, sinal, ext, cor)
	local p = E.p
	local ab = {}
	for _, e in extra or {} do
		table.insert(ab, e)
	end
	local deco = {}
	for _, j in lista or {} do
		local est = j.est or sortearEstado(E, 0.5)
		local peit, ja = j.peit or 3.6, j.alt or 4
		table.insert(ab, {
			de = j.pos - ini,
			larg = j.larg,
			tipo = "janela",
			peitoril = peit,
			alt = ja,
			vidro = est == "ok" or est == "grade",
			cor = p.moldura,
		})
		table.insert(deco, { pos = j.pos, larg = j.larg, yc = base + peit + ja / 2, alt = ja, est = est })
	end
	local a, b
	if plano == "z" then
		a, b = { ini, linha }, { fim, linha }
	else
		a, b = { linha, ini }, { linha, fim }
	end
	E.parede(a, b, ab, { nome = "Parede", base = base, alt = H, cor = cor or p.parede, mat = p.parMat, ext = ext })
	for _, dc in deco do
		adornoJanela(E, plano, dc.pos, linha, sinal, dc.larg, dc.yc, dc.alt, dc.est)
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Fachada (frente) padrão: porta de vidro, vitrines, letreiro, toldo, grade de enrolar
-- ---------------------------------------------------------------------------------------------------------------
local function letreiro(E, cx, yc, largura, altura, z, txt: string)
	local p = E.p
	local placa = E.bl("Letreiro", cx, yc, z, largura, altura, 0.8, p.letreiro, "Metal")
	local neon = E.ctx.escurecer(p.letra, 0.4)
	local op = { colide = false, consulta = false, sombra = false }
	E.bl("NeonBorda", cx, yc + altura / 2 - 0.25, z - 0.45, largura - 0.8, 0.18, 0.12, neon, "Neon", op)
	E.bl("NeonBorda", cx, yc - altura / 2 + 0.25, z - 0.45, largura - 0.8, 0.18, 0.12, neon, "Neon", op)
	E.texto(placa, txt, E.ctx.escurecer(p.letra, 0.82))
	return placa
end

local function toldo(E, cx, larg, zParede, yAlto)
	local p = E.p
	local n = 6
	local fatia = larg / n
	for i = 1, n do
		local x = cx - larg / 2 + (i - 0.5) * fatia
		local cor = if i % 2 == 1 then p.toldoA else p.toldoB
		E.rampa("Toldo", x, yAlto, zParede - 0.6, x, yAlto - 1.5, zParede - 3.0, fatia, 0.25, cor, "Fabric", {
			colide = false,
			consulta = false,
			sombra = false,
		})
	end
	E.bl("ToldoBarra", cx, yAlto - 1.5 - 0.5, zParede - 3.1, larg, 0.9, 0.2, p.toldoA, "Fabric", {
		colide = false,
		consulta = false,
		sombra = false,
	})
end

local function portaVidro(E, pt, zParede)
	local p = E.p
	local alt = pt.alt or 7.8
	local op = { colide = false, consulta = false }
	local xe, xd = pt.x - pt.larg / 2, pt.x + pt.larg / 2
	E.bl("Batente", xe, alt / 2, zParede - 0.4, 0.5, alt, 0.5, p.ferro, "Metal", op)
	E.bl("Batente", xd, alt / 2, zParede - 0.4, 0.5, alt, 0.5, p.ferro, "Metal", op)
	if pt.enrolar then
		-- porta de enrolar: rolo no alto e lâmina a meia altura
		E.cil(
			"Rolo",
			pt.x,
			alt + 0.7,
			zParede - 0.9,
			1.2,
			pt.larg + 1,
			p.ferro,
			"Metal",
			{ eixo = "x", colide = false }
		)
		E.bl(
			"GradeEnrolar",
			pt.x,
			alt - alt * 0.22,
			zParede - 0.7,
			pt.larg - 0.4,
			alt * 0.44,
			0.25,
			{ 88, 84, 78 },
			"CorrodedMetal",
			op
		)
		E.bl("GradeBarra", pt.x, alt - alt * 0.44, zParede - 0.7, pt.larg - 0.4, 0.4, 0.4, p.ferro, "Metal", op)
	else
		-- folha de vidro entreaberta presa ao batente esquerdo
		local comp = pt.larg / 2 - 0.3
		E.bl(
			"FolhaVidro",
			xe + 0.4 + comp * 0.34,
			alt / 2 - 0.2,
			zParede - 0.4 - comp * 0.47,
			0.15,
			alt - 0.4,
			comp,
			{ 150, 175, 190 },
			"Glass",
			{
				colide = false,
				consulta = false,
				transparencia = 0.55,
				rotY = -0.35,
			}
		)
		E.bl("Barra", xe + 0.4 + comp * 0.34, 3.4, zParede - 0.4 - comp * 0.47, 0.25, 0.25, comp, p.ferro, "Metal", {
			colide = false,
			consulta = false,
			sombra = false,
			rotY = -0.35,
		})
		if pt.grade then
			-- grade de enrolar levantada pela metade, só visual
			E.cil(
				"Rolo",
				pt.x,
				alt + 0.7,
				zParede - 0.9,
				1.0,
				pt.larg + 0.6,
				p.ferro,
				"Metal",
				{ eixo = "x", colide = false }
			)
			E.bl(
				"GradeEnrolar",
				pt.x,
				alt - alt * 0.22,
				zParede - 0.7,
				pt.larg - 0.2,
				alt * 0.44,
				0.2,
				{ 88, 84, 78 },
				"CorrodedMetal",
				op
			)
		end
	end
end

local function frente(E, o)
	local p, A = E.p, E.andares
	local pt = o.porta
	local alt = pt.alt or 7.8
	local ab = { { de = pt.x - E.x0, larg = pt.larg, tipo = "vao", alt = alt } }
	local deco = {}
	for _, j in o.janelasFrente or {} do
		local est = j.est or sortearEstado(E, 0.55)
		local peit, ja = j.peit or 1.6, j.alt or 5.4
		table.insert(ab, {
			de = j.x - E.x0,
			larg = j.larg,
			tipo = "janela",
			peitoril = peit,
			alt = ja,
			vidro = est == "ok" or est == "grade",
			cor = p.moldura,
		})
		table.insert(deco, { x = j.x, larg = j.larg, yc = peit + ja / 2, alt = ja, est = est })
	end
	E.parede({ E.x0, E.z0 }, { E.x1, E.z0 }, ab, { nome = "Fachada", cor = p.parede, mat = p.parMat })
	for _, dc in deco do
		adornoJanela(E, "z", dc.x, E.z0, -1, dc.larg, dc.yc, dc.alt, dc.est)
	end
	-- andares de cima: só janelas
	for f = 2, A do
		local lista = {}
		local x = E.x0 + 6
		while x < E.x1 - 4 do
			table.insert(lista, { pos = x, larg = 5, peit = 3.6, alt = 4.4 })
			x += 9
		end
		paredeJanelas(E, "z", E.z0, E.x0, E.x1, (f - 1) * H, lista, nil, -1, nil, p.parede)
	end
	portaVidro(E, pt, E.z0)
	-- rodapé de cor, dos dois lados da porta
	local ro = { colide = false, consulta = false, sombra = false }
	local ea, eb = pt.x - pt.larg / 2, pt.x + pt.larg / 2
	E.bl("Rodape", (E.x0 - 0.5 + ea) / 2, 0.6, E.z0 - 0.6, ea - E.x0 + 0.5, 1.2, 0.2, p.rodape, "Concrete", ro)
	E.bl("Rodape", (eb + E.x1 + 0.5) / 2, 0.6, E.z0 - 0.6, E.x1 + 0.5 - eb, 1.2, 0.2, p.rodape, "Concrete", ro)
	-- letreiro e toldo
	if o.nome then
		letreiro(E, pt.x, 11.4, math.min(E.x1 - E.x0 - 6, o.letreiroLarg or 24), 3.2, E.z0 - 0.95, o.nome)
	end
	if o.toldo ~= false then
		toldo(E, pt.x, math.min(E.x1 - E.x0 - 6, o.toldoLarg or 26), E.z0, 9.4)
	end
	-- calçada de entrada
	local zi = -E.d / 2
	E.bl(
		"Calcada",
		0,
		0.12,
		(zi + E.z0 - 0.5) / 2,
		E.x1 - E.x0 + 1,
		0.25,
		E.z0 - 0.5 - zi,
		{ 118, 118, 112 },
		"Concrete"
	)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Casco: piso, paredes laterais e do fundo, lajes entre andares, telhado plano com parapeito
-- o: porta, janelasFrente, janelasLado (z), janelasFundo (x), fundo = {x}, nome, frenteCustom, furos = {[f] = {rects}}
-- ---------------------------------------------------------------------------------------------------------------
local function telhado(E)
	local p, A = E.p, E.andares
	local topo = A * H + 1
	E.piso("Teto", E.x0 - 0.5, E.x1 + 0.5, E.z0 - 0.5, E.z1 + 0.5, topo, 1, p.telhado, "Slate")
	local par = { 66, 62, 60 }
	local x0, x1, z0, z1 = E.x0 - 0.5, E.x1 + 0.5, E.z0 - 0.5, E.z1 + 0.5
	E.bl("Parapeito", 0, topo + 0.7, z0 + 0.3, x1 - x0, 1.4, 0.6, par, "Concrete")
	E.bl("Parapeito", 0, topo + 0.7, z1 - 0.3, x1 - x0, 1.4, 0.6, par, "Concrete")
	E.bl("Parapeito", x0 + 0.3, topo + 0.7, (z0 + z1) / 2, 0.6, 1.4, z1 - z0 - 1.2, par, "Concrete")
	E.bl("Parapeito", x1 - 0.3, topo + 0.7, (z0 + z1) / 2, 0.6, 1.4, z1 - z0 - 1.2, par, "Concrete")
	-- ar-condicionado, ventilação, caixa-d'água
	local r = E.rng
	local zc = (E.z0 + E.z1) / 2
	for i = 1, 2 do
		local x = r.entre(E.x0 + 4, E.x1 - 4)
		local z = r.entre(zc, E.z1 - 3)
		E.bl("ArCondicionado", x, topo + 1.2, z, 3.4, 2.4, 2.4, { 120, 122, 120 }, "Metal")
		E.cil("Ventilador", x, topo + 2.5, z, 1.8, 0.2, { 50, 52, 54 }, "Metal", { colide = false })
		E.bl("DutoTeto", x + 3, topo + 0.35, z, 2.6, 0.7, 0.9, { 90, 90, 88 }, "Metal", { colide = false })
	end
	E.cil("CaixaDagua", r.entre(E.x0 + 5, E.x1 - 5), topo + 1.6, E.z1 - 2.5, 2.8, 3.2, { 100, 96, 90 }, "Metal")
end

local function casco(E, o)
	local p, A = E.p, E.andares
	E.piso("Piso", E.x0, E.x1, E.z0, E.z1, PISO_Y, 0.5, p.piso, p.pisoMat or "Concrete")
	-- paredes laterais (z ao longo), por andar
	local esq = o.janelasLado or {}
	for f = 1, A do
		local base = (f - 1) * H
		local lado = {}
		for _, z in esq do
			table.insert(lado, { pos = z, larg = o.larguraJanelaLado or 4 })
		end
		paredeJanelas(E, "x", E.x0, E.z0, E.z1, base, lado, nil, -1, -0.5, p.parede)
		local lado2 = {}
		for _, z in esq do
			table.insert(lado2, { pos = z, larg = o.larguraJanelaLado or 4 })
		end
		paredeJanelas(E, "x", E.x1, E.z0, E.z1, base, lado2, nil, 1, -0.5, p.parede)
		-- fundo
		local fundo = {}
		for _, x in o.janelasFundo or {} do
			table.insert(fundo, { pos = x, larg = 4 })
		end
		local extra = nil
		if f == 1 and o.fundo then
			extra = { { de = o.fundo.x - E.x0, larg = 5, tipo = "porta", cor = p.porta } }
		end
		paredeJanelas(E, "z", E.z1, E.x0, E.x1, base, fundo, extra, 1, nil, p.parede)
	end
	if not o.frenteCustom then
		frente(E, o)
	end
	-- lajes entre andares
	for f = 1, A - 1 do
		local furos = o.furos and o.furos[f] or nil
		E.piso("Laje", E.x0, E.x1, E.z0, E.z1, f * H, 1, p.pisoCima or p.piso, p.pisoMat or "Concrete", furos)
	end
	telhado(E)
	-- manchas de óleo/sujeira na calçada
	E.bl("Mancha", E.rng.entre(-8, 8), 0.27, -E.d / 2 + 1.6, 4, 0.04, 2, { 40, 40, 38 }, "Asphalt", {
		colide = false,
		consulta = false,
		sombra = false,
	})
end

local function finalizar(E, o)
	local x = E.s * (o.porta and o.porta.x or 0)
	return E.modelo, {
		loot = E.lootLista,
		frente = { x, -E.d / 2 + 1.5 },
		portaria = { x, E.z0 },
	}
end

local function nomeDe(E, lista)
	return E.rng.escolher(lista)
end

-- ===============================================================================================================
-- MERCADO 56×44
-- ===============================================================================================================
local function interiorMercado(E)
	local p = E.p
	local S = E.sala
	-- caixas e carrinhos na frente
	for _, x in { -18, -10, 10, 18 } do
		E.mob("balcao_caixa", x, -15)
	end
	E.mob("carrinho_compras", -6, -11.5, 0.3)
	E.mob("carrinho_compras", 6.5, -11.5, -0.4)
	E.mob("cesta_compras", 3.4, -12)
	-- corredores
	for _, fila in { { -7, PI }, { 1, 0 } } do
		for _, x in { -17, -8, 8, 17 } do
			E.mob("prateleira_mercado", x, fila[1], fila[2])
		end
	end
	E.mob("pilha_produtos", -24, -2)
	for _, z in { -8, -2, 4 } do
		E.mobParede("geladeira_expositora", "+x", z, S)
	end
	-- açougue
	E.mobParede("balcao_acougue", "-x", 14, S)
	E.mob("pilha_produtos", -18, 15)
	-- depósito (centro, fundo) e câmara fria (direita, fundo)
	local porta = p.porta
	E.parede({ -8, 11 }, { 8, 11 }, { { de = 8, larg = 5.5, tipo = "porta", cor = porta } })
	E.parede({ -8, 11 }, { -8, E.z1 }, nil)
	E.parede({ 8, 9 }, { 8, E.z1 }, nil)
	E.parede({ 8, 9 }, { E.x1, 9 }, { { de = 9, larg = 5.5, tipo = "porta", cor = porta } })
	local dep = { x0 = -7.5, x1 = 7.5, z0 = 11.5, z1 = E.iz1 }
	E.mobParede("estante_industrial", "+z", 3.5, dep)
	E.mob("pilha_caixotes", 5, 14, 0, { w = 4.6, d = 4.6 })
	E.mob("palete", -4.5, 14.3, 0)
	local cam = { x0 = 8.5, x1 = E.ix1, z0 = 9.5, z1 = E.iz1 }
	E.mobParede("geladeira_expositora", "+z", 13, cam)
	E.mobParede("geladeira_expositora", "+z", 20, cam)
	E.mobParede("freezer_horizontal", "+x", 13, cam)
	E.mob("barril", 10, 11.5)
	-- sujeira
	E.mob("pilha_produtos", 2, 6, 0.6)
	E.loot(0, -3)
	E.loot(-17, 6)
	E.loot(0, 16)
	E.loot(13, 14.5)
	E.loot(-12, 6)
	E.loot(13, -10.5)
end

local function mercado()
	local paletas = paletasDe(1, 5, {
		{ { 40, 62, 46 }, { 150, 175, 140 } },
		{ { 70, 36, 34 }, { 210, 180, 150 } },
		{ { 36, 46, 66 }, { 170, 190, 210 } },
		{ { 62, 52, 36 }, { 205, 180, 110 } },
		{ { 48, 48, 52 }, { 190, 190, 175 } },
	})
	local nomes = { "MERCADO BOM PREÇO", "SUPER ECONOMIA", "MERCADO SÃO JOSÉ", "SUPERMERCADO ALVORADA" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "mercado", "mercado", 56, 44, 1, paletas)
			local o = {
				porta = { x = 0, larg = 7, grade = true },
				janelasFrente = { { x = -15.5, larg = 10 }, { x = 15.5, larg = 10 } },
				janelasLado = { -8, 2, 12 },
				janelasFundo = { -18 },
				fundo = { x = -4.5 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 30,
				toldoLarg = 34,
			}
			casco(E, o)
			interiorMercado(E)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.mercado = mercado()

-- ===============================================================================================================
-- LOJA DE CONVENIÊNCIA 34×26
-- ===============================================================================================================
local function lojaConveniencia()
	local paletas = paletasDe(2, 5, {
		{ { 30, 60, 56 }, { 180, 210, 190 } },
		{ { 70, 34, 30 }, { 225, 190, 140 } },
		{ { 28, 44, 70 }, { 190, 210, 230 } },
		{ { 66, 58, 30 }, { 225, 210, 130 } },
	})
	local nomes = { "CONVENIÊNCIA 24H", "LOJA DA ESQUINA", "MINI MERCADO", "EXPRESS 24 HORAS" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "loja_conveniencia", "loja", 34, 26, 1, paletas)
			local S = E.sala
			local o = {
				porta = { x = -6, larg = 6, grade = true },
				janelasFrente = { { x = 7.5, larg = 9 } },
				janelasLado = { -2, 6 },
				janelasFundo = { 10 },
				fundo = { x = 12 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 22,
				toldoLarg = 24,
			}
			casco(E, o)
			E.mob("balcao_loja", 8.5, -6.8, 0)
			E.mob("computador", 10, -6.6, 0, nil, PISO_Y + 3.4)
			E.mobParede("maquina_venda", "+x", 3, S)
			E.mobParede("maquina_venda", "+x", 6.8, S)
			for _, x in { -12.5, -6.5, -0.5 } do
				E.mobParede("geladeira_expositora", "+z", x, S)
			end
			E.mob("prateleira_loja", -6, 2, 0)
			E.mob("prateleira_loja", 0.5, 2, 0)
			E.mob("freezer_horizontal", 9, 1.5, 0)
			E.mob("pilha_produtos", -12.5, 2.5, 0.4)
			E.mob("cesta_compras", 13, -3)
			E.loot(-12, 5)
			E.loot(3, 5.5)
			E.loot(13.5, -9.5 + 5)
			E.loot(-8, -5)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.loja_conveniencia = lojaConveniencia()

-- ===============================================================================================================
-- LOJA DE ROUPAS 36×28
-- ===============================================================================================================
local function lojaRoupas()
	local paletas = paletasDe(3, 5, {
		{ { 58, 36, 50 }, { 220, 180, 200 } },
		{ { 30, 38, 52 }, { 200, 200, 215 } },
		{ { 62, 46, 30 }, { 225, 200, 150 } },
		{ { 40, 56, 52 }, { 190, 220, 205 } },
	})
	local nomes = { "MODA ELEGANTE", "BOUTIQUE LUZ", "CASA DA MODA", "ROUPAS & CIA" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "loja_roupas", "loja", 36, 28, 1, paletas)
			local S = E.sala
			local o = {
				porta = { x = 0, larg = 6, grade = true },
				janelasFrente = { { x = -9.5, larg = 8 }, { x = 9.5, larg = 8 } },
				janelasLado = { 0, 8 },
				janelasFundo = { 10 },
				fundo = { x = 12 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 22,
				toldoLarg = 26,
			}
			casco(E, o)
			for _, x in { -11, -7.5, 7.5, 11 } do
				E.mob("manequim", x, -8.5, E.rng.entre(-0.6, 0.6))
			end
			E.mob("balcao_loja", 12, -4.4, 0)
			for _, x in { -12, -6, 6, 12 } do
				E.mob("arara_roupas", x, 0, 0)
			end
			E.mob("arara_roupas", 6, 7, 0)
			E.mob("arara_roupas", 12, 7, 0)
			E.mobParede("prateleira_loja", "+x", 2, S)
			E.mobParede("prateleira_loja", "+x", 8.5, S)
			-- provadores: fundo à esquerda
			local pa = { cor = nil }
			E.parede(
				{ -16.5, 8 },
				{ -1.5, 8 },
				{ { de = 3.75, larg = 6, tipo = "vao" }, { de = 11.25, larg = 6, tipo = "vao" } },
				{ esp = 0.8, nome = "Provador", ext = 0 }
			)
			E.parede({ -9, 8 }, { -9, E.z1 }, nil, { esp = 0.8, ext = 0, nome = "Provador" })
			E.parede({ -1.5, 8 }, { -1.5, E.z1 }, nil, { esp = 0.8, ext = 0, nome = "Provador" })
			for _, x in { -12.75, -5.25 } do
				E.mob("cortina", x, 8.6, 0, { w = 6.2 })
				E.mob("espelho_parede", x, E.iz1, 0, nil, PISO_Y + 2)
			end
			E.mob("cesto_lixo", -3, 11.2)
			E.mob("cadeira", -15.3, 10.8, 0.4)
			E.loot(0, 4.5)
			E.loot(-9, 4.5)
			E.loot(-5.25, 11)
			E.loot(11, 10)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.loja_roupas = lojaRoupas()

-- ===============================================================================================================
-- LOJA DE FERRAGENS 40×30
-- ===============================================================================================================
local function lojaFerragens()
	local paletas = paletasDe(4, 5, {
		{ { 54, 46, 32 }, { 225, 190, 110 } },
		{ { 40, 44, 50 }, { 220, 150, 80 } },
		{ { 62, 34, 28 }, { 215, 205, 190 } },
		{ { 34, 54, 44 }, { 215, 215, 150 } },
	})
	local nomes = { "FERRAGENS ALMEIDA", "CASA DAS FERRAMENTAS", "FERRAGEM E TINTAS", "DEPÓSITO DO ZÉ" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "loja_ferragens", "loja", 40, 30, 1, paletas)
			local S = E.sala
			local o = {
				porta = { x = 0, larg = 6, grade = true },
				janelasFrente = { { x = -12, larg = 9 }, { x = 12, larg = 9 } },
				janelasLado = { -2, 8 },
				janelasFundo = { -10 },
				fundo = { x = 14 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 24,
				toldoLarg = 28,
			}
			casco(E, o)
			for _, fila in { { 0, PI }, { 7, 0 } } do
				for _, x in { -12, -5 } do
					E.mob("prateleira_loja", x, fila[1], fila[2])
				end
			end
			E.mob("balcao_loja", 10, -7.5, 0)
			E.mob("computador", 11.5, -7.4, 0, nil, PISO_Y + 3.4)
			E.mobParede("expositor_pneus", "+x", -2, S)
			E.mobParede("expositor_pneus", "+x", 3, S)
			E.mobParede("bancada_trabalho", "+z", 10, S)
			E.mobParede("tambor_oleo", "-x", -9.5, S)
			E.mobParede("tambor_oleo", "-x", -7.3, S)
			E.mobParede("caixa_ferramentas", "+z", -15, S)
			E.mob("pilha_pneus", 16, 6.5)
			E.mob("galao", 15.5, -8.5)
			E.mob("galao", 16.7, -8.2)
			E.loot(-8.5, 3.5)
			E.loot(6, 3)
			E.loot(0, 10)
			E.loot(14, 5.5)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.loja_ferragens = lojaFerragens()

-- ===============================================================================================================
-- FARMÁCIA 30×26
-- ===============================================================================================================
local function farmacia()
	local paletas = paletasDe(5, 5, {
		{ { 30, 62, 50 }, { 205, 235, 215 } },
		{ { 32, 52, 70 }, { 210, 225, 235 } },
		{ { 66, 40, 40 }, { 235, 215, 210 } },
		{ { 40, 40, 44 }, { 160, 220, 175 } },
	})
	local nomes = { "FARMÁCIA SAÚDE", "DROGARIA POPULAR", "FARMÁCIA CENTRAL", "DROGARIA SÃO PAULO" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "farmacia", "farmacia", 30, 26, 1, paletas)
			local S = E.sala
			local o = {
				porta = { x = -6, larg = 6, grade = true },
				janelasFrente = { { x = 7.5, larg = 9 } },
				janelasLado = { 2 },
				janelasFundo = { 8 },
				fundo = { x = -6 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 20,
				toldoLarg = 22,
			}
			casco(E, o)
			E.mobParede("vitrine", "-z", 5.5, S)
			E.mobParede("vitrine", "-z", 10.5, S)
			E.mob("prateleira_loja", 4.2, -4.2, PI)
			E.mob("prateleira_loja", 10.4, -4.2, PI)
			-- balcão da farmácia
			E.mob("balcao_loja", 4, 3.5, 0, { w = 10 })
			E.mob("computador", 3, 3.5, 0, nil, PISO_Y + 3.4)
			E.mob("prateleira_loja", 0.5, 10.5, PI)
			E.mob("prateleira_loja", 6.5, 10.5, PI)
			E.mobParede("armario_medico", "+z", 11.7, S)
			for _, z in { -6, -3, 0 } do
				E.mobParede("cadeira", "-x", z, S, nil, nil, 0.2)
			end
			E.mob("cesto_lixo", -11.5, 7)
			E.mob("pilha_produtos", 12, 0.5, 0, nil)
			E.loot(-8, 3.5)
			E.loot(-8, 8.5)
			E.loot(9.5, 7.5)
			E.loot(-2, -3)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.farmacia = farmacia()

-- ===============================================================================================================
-- RESTAURANTE 42×32
-- ===============================================================================================================
local function restaurante()
	local paletas = paletasDe(1, 5, {
		{ { 66, 36, 30 }, { 230, 205, 160 } },
		{ { 40, 52, 40 }, { 225, 210, 170 } },
		{ { 52, 40, 60 }, { 220, 195, 210 } },
		{ { 34, 44, 62 }, { 225, 215, 190 } },
	})
	local nomes = { "RESTAURANTE SABOR CASEIRO", "CANTINA DA NONNA", "RESTAURANTE BELA VISTA", "COZINHA DO CHEF" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "restaurante", "restaurante", 42, 32, 1, paletas)
			local p = E.p
			local S = E.sala
			local o = {
				porta = { x = 0, larg = 6, grade = true },
				janelasFrente = { { x = -12, larg = 10 }, { x = 12, larg = 10 } },
				janelasLado = { -6, 8 },
				janelasFundo = { -14 },
				fundo = { x = -12 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 28,
				toldoLarg = 30,
			}
			casco(E, o)
			-- salão
			for _, x in { -9.5, 9.5 } do
				for _, z in { -7, 0 } do
					E.mob("mesa_restaurante", x, z, 0)
				end
			end
			E.mobParede("cabine_restaurante", "-x", -7.5, S)
			E.mobParede("cabine_restaurante", "-x", 0, S)
			E.mobParede("cabine_restaurante", "+x", -7.5, S)
			E.mobParede("cabine_restaurante", "+x", 0, S)
			E.mob("balcao_caixa", -2.5, -10, 0, nil)
			E.mob("planta_vaso", -4.2, 1.8)
			E.mob("planta_vaso", 4.2, 1.8)
			-- divisória salão/cozinha/banheiros
			E.parede({ E.x0, 4 }, { E.x1, 4 }, {
				{ de = -6 - E.x0, larg = 5.5, tipo = "porta", cor = p.porta },
				{ de = 9.5 - E.x0, larg = 5, tipo = "porta", cor = p.porta },
				{ de = 16.5 - E.x0, larg = 5, tipo = "porta", cor = p.porta },
			})
			E.parede({ 6, 4 }, { 6, E.z1 }, nil)
			E.parede({ 13, 4 }, { 13, E.z1 }, nil)
			-- cozinha
			local coz = { x0 = E.ix0, x1 = 5.5, z0 = 4.5, z1 = E.iz1 }
			E.mobParede("geladeira", "-x", 7.5, coz)
			E.mobParede("fogao", "+z", -15, coz)
			E.mobParede("fogao", "+z", -11.5, coz)
			E.mobParede("pia_cozinha", "+z", -6.5, coz)
			E.mob("bancada_cozinha", -8, 9.8, 0, { w = 8 })
			E.mobParede("armario_cozinha_alto", "+z", -2.5, coz, nil, PISO_Y + 5.5)
			E.mobParede("estante_industrial", "+x", 10, coz)
			E.mob("barril", -18, 11.5)
			E.mob("cesto_lixo", 1, 6)
			-- banheiros
			local b1 = { x0 = 6.5, x1 = 12.5, z0 = 4.5, z1 = E.iz1 }
			local b2 = { x0 = 13.5, x1 = E.ix1, z0 = 4.5, z1 = E.iz1 }
			for _, b in { b1, b2 } do
				E.mobParede("vaso_sanitario", "+z", b.x0 + 2, b)
				E.mobParede("lavatorio", "+x", 9, b)
				E.mobParede("espelho_banheiro", "+x", 9, b, nil, PISO_Y + 4)
			end
			E.loot(0, -3.5)
			E.loot(-14, 8)
			E.loot(9.5, 10)
			E.loot(16.5, 12)
			E.loot(0, 1.2)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.restaurante = restaurante()

-- ===============================================================================================================
-- BAR 34×26 (1–2 andares)
-- ===============================================================================================================
local function bar()
	local paletas = paletasDe(2, 5, {
		{ { 56, 30, 34 }, { 225, 150, 100 } },
		{ { 28, 44, 52 }, { 130, 210, 190 } },
		{ { 50, 40, 28 }, { 230, 190, 110 } },
		{ { 40, 34, 56 }, { 210, 160, 215 } },
	})
	local nomes = { "BAR DO ZECA", "BOTECO DA ESQUINA", "BAR & SINUCA", "TAVERNA DO PORTO" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "bar", "bar", 34, 26, 1, paletas)
			local p = E.p
			local S = E.sala
			local A = E.andares
			local o = {
				porta = { x = 0, larg = 6, grade = true },
				janelasFrente = { { x = -10, larg = 7 }, { x = 10, larg = 7 } },
				janelasLado = { -3, 5 },
				janelasFundo = { 8 },
				fundo = { x = 12.5 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 22,
				toldoLarg = 24,
				furos = {},
			}
			local pisoBaixo = PISO_Y
			local escada = nil
			if A >= 2 then
				-- escada junto à parede do fundo, subindo para +x
				escada = { x = E.ix0 + 0.1, z = 9 }
				-- calcula o retângulo sem construir (espelho do comprimento do ctx.escada)
				local comp = ctx.comprimentoEscada(H - pisoBaixo, { passada = 1.2 })
				o.furos[1] = { { x0 = escada.x, x1 = escada.x + comp, z0 = escada.z - 2.5, z1 = escada.z + 2.5 } }
			end
			casco(E, o)
			if escada then
				E.escada(
					"Degrau",
					escada.x,
					escada.z,
					"+x",
					pisoBaixo,
					H - pisoBaixo,
					5,
					p.piso,
					"Concrete",
					{ passada = 1.2 }
				)
			end
			-- térreo
			E.mob("balcao_bar", 9.5, 7, 0, { w = 10 })
			for i = 0, 4 do
				E.mob("banqueta", 5.7 + i * 2.2, 4.4)
			end
			E.mob("mesa_sinuca", -8, 1.5, 0)
			E.mobParede("jukebox", "+x", -3, S)
			E.mobParede("maquina_venda", "+x", -7, S)
			E.mob("mesa_restaurante", -9, -5.5, 0)
			E.mob("mesa_restaurante", 9, -5.5, 0)
			E.mobParede("prateleira_parede", "+z", 4, S, { w = 8 }, PISO_Y + 6)
			E.mobParede("geladeira_expositora", "+z", 12.3, S)
			if A < 2 then
				E.mob("mesa_restaurante", -11, 8.5, 0)
				E.mob("mesa_restaurante", -4.5, 8.5, 0)
			end
			E.mob("barril", -14, -8)
			E.loot(0, 1.5)
			E.loot(-4, -6)
			E.loot(11, -0.5)
			E.loot(6.5, 10)
			-- andar de cima: dormitório e sala do dono
			if A >= 2 then
				local y = H
				E.parede({ 2, E.z0 }, { 2, E.z1 }, { { de = -2 - E.z0, larg = 5, tipo = "porta", cor = p.porta } }, {
					base = y,
					ext = 0,
				})
				local esq = { x0 = E.ix0, x1 = 1.5, z0 = E.iz0, z1 = E.iz1 }
				local dir = { x0 = 2.5, x1 = E.ix1, z0 = E.iz0, z1 = E.iz1 }
				E.mobParede("cama_casal", "-x", -4, esq, nil, y)
				E.mobParede("criado_mudo", "-x", -8, esq, nil, y)
				E.mobParede("guarda_roupa", "-x", 2.5, esq, nil, y)
				E.mobParede("sofa", "+x", 0, dir, nil, y)
				E.mob("mesa_centro", 9.5, 0, PI / 2, nil, y)
				E.mobParede("movel_tv", "-x", 6, dir, nil, y)
				E.mob("poltrona", 12, -6, 0.5, nil, y)
				E.mob("tapete", 9.5, 0, 0, { w = 7, d = 5 }, y)
				E.loot(6, -5, y)
				E.loot(-9, 4, y)
			end
			return finalizar(E, o)
		end,
	}
end
M.catalogo.bar = bar()

-- ===============================================================================================================
-- BANCO 40×32 (1–2 andares)
-- ===============================================================================================================
local function banco()
	local paletas = paletasDe(3, 5, {
		{ { 34, 44, 38 }, { 200, 205, 170 } },
		{ { 36, 40, 56 }, { 200, 200, 215 } },
		{ { 58, 40, 34 }, { 225, 205, 170 } },
		{ { 42, 42, 42 }, { 205, 190, 130 } },
	})
	local nomes = { "BANCO NACIONAL", "BANCO DO VALE", "BANCO UNIÃO", "CAIXA POPULAR" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "banco", "banco", 40, 32, 1, paletas)
			local p = E.p
			local S = E.sala
			local A = E.andares
			local o = {
				porta = { x = 0, larg = 7, grade = true },
				janelasFrente = { { x = -11, larg = 6, est = "grade" }, { x = 11, larg = 6, est = "grade" } },
				janelasLado = { -4, 8 },
				janelasFundo = { 4 },
				fundo = { x = -14 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 26,
				toldoLarg = 28,
				furos = {},
			}
			local escada = { x = E.ix0 + 0.1, z = 12.25 }
			if A >= 2 then
				local comp = ctx.comprimentoEscada(H - PISO_Y, { passada = 1.2 })
				o.furos[1] = { { x0 = escada.x, x1 = escada.x + comp, z0 = escada.z - 2.25, z1 = escada.z + 2.25 } }
			end
			casco(E, o)
			-- saguão
			E.mobParede("sofa_recepcao", "-x", -3.5, S)
			E.mobParede("sofa_recepcao", "+x", -3.5, S)
			E.mob("planta_vaso", -17, -10.8)
			E.mobParede("bebedouro", "-z", 12.5, S, nil, nil, 0.2)
			E.mobParede("maquina_venda", "-z", 16.8, S)
			E.mob("mesa_escritorio", 8, -7.5, 0)
			-- guichês
			for _, x in { -13.5, -2.5, 8.5 } do
				E.mob("balcao_recepcao", x, 1.5, 0, { w = 10 })
			end
			E.bl("Cancela", 15.7, 1.5, 1.5, 0.3, 2.6, 2.2, p.ferro, "Metal", { colide = false })
			-- área dos funcionários
			for _, x in { -13.5, -2.5, 4 } do
				E.mob("mesa_escritorio", x, 6.2, 0)
				E.mob("computador", x, 6.2, 0, nil, PISO_Y + 2.7)
				E.mob("cadeira_escritorio", x, 8.8, PI)
			end
			-- cofre: paredes grossas e porta pesada
			E.parede(
				{ 7, 9 },
				{ 7, E.z1 },
				nil,
				{ esp = 2, ext = 0, mat = "Concrete", cor = { 96, 96, 94 }, nome = "Cofre" }
			)
			E.parede(
				{ 7, 9 },
				{ E.x1, 9 },
				{ { de = 13.25 - 7, larg = 5.5, tipo = "vao", alt = 7.5 } },
				{ esp = 2, ext = 0, mat = "Concrete", cor = { 96, 96, 94 }, nome = "Cofre" }
			)
			E.bl("PortaCofre", 10.9, 3.9, 6.6, 1.2, 7.5, 5, { 74, 78, 80 }, "Metal", { colide = false })
			E.bl(
				"RodaCofre",
				10.9,
				4.2,
				4.0,
				0.3,
				2.2,
				2.2,
				{ 120, 120, 112 },
				"Metal",
				{ colide = false, consulta = false }
			)
			E.bl(
				"PisoCofre",
				13.5,
				PISO_Y + 0.05,
				12.25,
				10.6,
				0.1,
				5,
				{ 70, 72, 74 },
				"DiamondPlate",
				{ colide = false, consulta = false }
			)
			local cofre = { x0 = 8.2, x1 = E.ix1, z0 = 10.2, z1 = E.iz1 }
			E.mobParede("arquivo_alto", "+z", 10, cofre)
			E.mobParede("arquivo_alto", "+z", 13, cofre)
			E.mobParede("bau", "+x", 12.5, cofre)
			if A < 2 then
				E.mob("arquivo_alto", -14, 13.2)
				E.mob("arquivo_alto", -11, 13.2)
				E.mob("arquivo_alto", -1, 13.2)
				E.mob("quadro_branco", -11, E.iz1, 0, nil, PISO_Y + 4.5)
			else
				E.escada(
					"Degrau",
					escada.x,
					escada.z,
					"+x",
					PISO_Y,
					H - PISO_Y,
					4.5,
					p.piso,
					"Concrete",
					{ passada = 1.2 }
				)
			end
			E.loot(-9, -5)
			E.loot(-8, 8, PISO_Y)
			E.loot(14, 12.5)
			E.loot(9, -3.5)
			-- andar de cima: escritórios
			if A >= 2 then
				local y = H
				for _, x in { -12, 12 } do
					for _, z in { -8, 3 } do
						E.mob("baia_escritorio", x, z, 0, nil, y)
					end
				end
				E.mob("mesa_reuniao", 12.5, 11.5, 0, nil, y)
				E.mobParede("quadro_branco", "+z", 12.5, S, nil, y + 4.5)
				E.mobParede("arquivo_alto", "-x", 0, S, nil, y)
				E.mob("copiadora", 1.5, 3, PI, nil, y)
				E.loot(0, -3, y)
				E.loot(3, 11.5, y)
			end
			return finalizar(E, o)
		end,
	}
end
M.catalogo.banco = banco()

-- ===============================================================================================================
-- POSTO 54×44: marquise com 4 bombas na frente + loja de conveniência + banheiros + placa de preços
-- ===============================================================================================================
local function posto()
	local paletas = paletasDe(4, 5, {
		{ { 52, 36, 28 }, { 230, 200, 120 } },
		{ { 30, 54, 46 }, { 215, 230, 170 } },
		{ { 62, 30, 28 }, { 235, 215, 150 } },
		{ { 30, 42, 66 }, { 225, 225, 215 } },
	})
	local nomes = { "POSTO SÃO CRISTÓVÃO", "AUTO POSTO ESTRELA", "POSTO RODOVIA", "POSTO IPIRANGA NORTE" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "posto", "posto", 54, 44, 1, paletas)
			local p = E.p
			E.limites(-17, 17, 3, 21)
			local S = E.sala
			local nome = nomeDe(E, nomes)
			local o = {
				porta = { x = 0, larg = 6, grade = true },
				janelasFrente = { { x = -10, larg = 9 }, { x = 10, larg = 9 } },
				janelasLado = { 9 },
				janelasFundo = { -10 },
				nome = nome,
				letreiroLarg = 22,
				toldo = false,
			}
			casco(E, o)
			-- marquise
			local cz0, cz1 = -20, -2
			E.bl("Marquise", 0, 13.75, (cz0 + cz1) / 2, 48, 1.5, cz1 - cz0, p.telhado, "Metal")
			E.bl("MarquiseFaixa", 0, 13.25, cz0 - 0.15, 48.2, 2.6, 0.4, p.toldoA, "Metal")
			E.bl("MarquiseFaixa", 0, 13.25, cz1 + 0.15, 48.2, 2.6, 0.4, p.toldoB, "Metal")
			for _, x in { -22, 22 } do
				for _, z in { -19, -4 } do
					E.bl("ColunaMarquise", x, 6.5, z, 1.6, 13, 1.6, { 110, 110, 105 }, "Concrete")
					E.bl("BaseColuna", x, 0.7, z, 2.4, 1.4, 2.4, p.toldoA, "Concrete")
				end
			end
			local neon = ctx.escurecer(p.letra, 0.4)
			for _, x in { -15, -5, 5, 15 } do
				E.bl(
					"Luminaria",
					x,
					12.9,
					-11,
					3,
					0.2,
					0.8,
					neon,
					"Neon",
					{ colide = false, consulta = false, sombra = false }
				)
			end
			-- ilhas e bombas
			for _, x in { -15, -5, 5, 15 } do
				E.bl("Ilha", x, 0.3, -11, 4, 0.6, 8, { 150, 140, 90 }, "Concrete")
				E.mob("bomba_combustivel", x, -11, 0, nil, 0.6)
			end
			E.carro(-10, -13.5, 0.15, 1 + E.rng.inteiro(0, 4))
			E.bl(
				"ManchaOleo",
				3,
				0.04,
				-16,
				5,
				0.04,
				3,
				{ 36, 34, 32 },
				"Asphalt",
				{ colide = false, consulta = false, sombra = false }
			)
			-- placa de preços alta no canto
			E.cil("PosteSinal", 23, 14, -21, 1, 28, { 100, 100, 98 }, "Metal")
			local placa = E.bl("PrecosPlaca", 23, 23, -21.9, 8, 6, 0.8, { 24, 26, 28 }, "Metal")
			E.texto(placa, "GASOLINA 6,49\nETANOL 4,89\nDIESEL 5,99", { 170, 175, 140 })
			local logo = E.bl("PostoNome", 23, 27.6, -21.9, 8, 2.6, 0.8, p.letreiro, "Metal")
			E.texto(logo, "POSTO", ctx.escurecer(p.letra, 0.85))
			E.mob("expositor_pneus", 21.5, 8, -PI / 2)
			E.mob("tambor_oleo", 22.3, 14)
			E.mob("tambor_oleo", 24.2, 14.4)
			E.mob("compressor", 21.5, 4.5, -PI / 2)
			-- loja de conveniência
			E.mobParede("balcao_caixa", "-z", 9, S)
			E.mobParede("prateleira_loja", "-x", 7.5, S)
			E.mobParede("prateleira_loja", "-x", 13.5, S)
			for _, x in { -12.5, -6.5, -0.5 } do
				E.mobParede("geladeira_expositora", "+z", x, S)
			end
			E.mobParede("maquina_venda", "+x", 6.5, S)
			E.mobParede("maquina_venda", "+x", 10.2, S)
			E.mob("pilha_produtos", -8, 10, 0.5)
			E.mob("pilha_produtos", -3, 7, 1)
			-- banheiros
			local porta = p.porta
			E.parede({ 3, 14 }, { E.x1, 14 }, {
				{ de = 6.5 - 3, larg = 5, tipo = "porta", cor = porta },
				{ de = 13.5 - 3, larg = 5, tipo = "porta", cor = porta },
			})
			E.parede({ 3, 14 }, { 3, E.z1 }, nil)
			E.parede({ 10, 14 }, { 10, E.z1 }, nil)
			local b1 = { x0 = 3.5, x1 = 9.5, z0 = 14.5, z1 = E.iz1 }
			local b2 = { x0 = 10.5, x1 = E.ix1, z0 = 14.5, z1 = E.iz1 }
			for _, b in { b1, b2 } do
				E.mobParede("vaso_sanitario", "+z", b.x0 + 2, b)
				E.mobParede("lavatorio", "+x", 18.2, b)
			end
			E.loot(-8, 5.5)
			E.loot(-3, 12.5)
			E.loot(0, -11)
			E.loot(12, 11.5)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.posto = posto()

-- ===============================================================================================================
-- LANCHONETE DE ESTRADA 36×28 (diner)
-- ===============================================================================================================
local function lanchonete()
	local paletas = paletasDe(5, 5, {
		{ { 48, 30, 28 }, { 230, 160, 120 } },
		{ { 28, 52, 54 }, { 210, 235, 200 } },
		{ { 60, 52, 30 }, { 235, 215, 130 } },
		{ { 40, 36, 52 }, { 220, 180, 210 } },
	})
	local nomes = { "DINER DA ESTRADA", "LANCHES 24H", "PARADA DO CAMINHONEIRO", "ROAD GRILL" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "lanchonete_estrada", "lanchonete", 36, 28, 1, paletas)
			local p = E.p
			local S = E.sala
			local o = {
				porta = { x = -9, larg = 6, grade = true },
				janelasFrente = {
					{ x = 2, larg = 12, peit = 2, alt = 4.8 },
					{ x = 12.5, larg = 6, peit = 2, alt = 4.8 },
				},
				janelasLado = { -4, 4 },
				janelasFundo = { 4 },
				fundo = { x = 5 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 22,
				toldoLarg = 24,
			}
			casco(E, o)
			E.mobParede("cabine_restaurante", "-z", 4, S)
			E.mobParede("cabine_restaurante", "-z", 12, S)
			E.mobParede("cabine_restaurante", "-x", -5, S)
			E.mobParede("cabine_restaurante", "-x", 3, S)
			E.mob("balcao_bar", 3.5, 3.5, 0, { w = 12 })
			for i = 0, 4 do
				E.mob("banqueta", -1 + i * 2.4, 0.9)
			end
			E.mobParede("jukebox", "+x", -3, S)
			-- cozinha atrás do balcão
			E.mobParede("bancada_cozinha", "+z", -3, S, { w = 8 })
			E.mobParede("fogao", "+z", 4, S)
			E.mobParede("fogao", "+z", 7, S)
			E.mobParede("geladeira", "+x", 7.5, S)
			E.mobParede("pia_cozinha", "+z", 11.5, S)
			E.mobParede("armario_cozinha_alto", "+z", -3, S, nil, PISO_Y + 5.5)
			-- banheiro
			E.parede({ E.x0, 7 }, { -9, 7 }, { { de = -13 - E.x0, larg = 5, tipo = "porta", cor = p.porta } })
			E.parede({ -9, 7 }, { -9, E.z1 }, nil)
			local b = { x0 = E.ix0, x1 = -9.5, z0 = 7.5, z1 = E.iz1 }
			E.mobParede("vaso_sanitario", "+z", -12.5, b)
			E.mobParede("lavatorio", "-x", 9.2, b)
			E.loot(-3, -3)
			E.loot(11.5, 6)
			E.loot(-11.5, 9.5)
			E.loot(10, -4)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.lanchonete_estrada = lanchonete()

-- ===============================================================================================================
-- MOTEL 56×30 (1–2 andares): recepção + 3 quartos com porta para fora
-- ===============================================================================================================
local function motel()
	local paletas = paletasDe(1, 5, {
		{ { 62, 30, 44 }, { 230, 150, 190 } },
		{ { 30, 52, 60 }, { 150, 220, 225 } },
		{ { 62, 54, 30 }, { 235, 215, 120 } },
		{ { 40, 40, 58 }, { 190, 190, 235 } },
	})
	local nomes = { "MOTEL VÉNUS", "MOTEL ESTRELA", "MOTEL DA ESTRADA", "MOTEL LUA CHEIA" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "motel", "motel", 56, 30, 1, paletas)
			local p = E.p
			local A = E.andares
			local portaX = { -8, 6, 20 } -- portas dos quartos (centro c + 3,5... ver abaixo)
			local cs = { -8, 6, 20 } -- centro dos três quartos (14 de largura)
			local recX = -21 -- centro da recepção (x -27..-15)
			local o = {
				porta = { x = recX + 1.5, larg = 6 },
				frenteCustom = true,
				janelasLado = { 4 },
				larguraJanelaLado = 4,
				janelasFundo = { -21, 6 },
				nome = nil,
				furos = {},
			}
			local escada = { x = -24.2, z = 14 }
			if A >= 2 then
				local comp = ctx.comprimentoEscada(H - PISO_Y, { passada = 1.2 })
				o.furos[1] = { { x0 = escada.x - 2.25, x1 = escada.x + 2.25, z0 = escada.z - comp, z1 = escada.z } }
			end
			casco(E, o)
			local x0, x1, z0 = E.x0, E.x1, E.z0
			-- frente por andar: recepção (vitrine + porta) e quartos (porta para fora)
			local ab = { { de = recX + 1.5 - x0, larg = 6, tipo = "vao", alt = 7.8 } }
			local deco = {}
			table.insert(ab, {
				de = recX - 5.5 - x0,
				larg = 5,
				tipo = "janela",
				peitoril = 1.8,
				alt = 5,
				vidro = true,
				cor = p.moldura,
			})
			for _, c in cs do
				table.insert(ab, { de = c + 3.5 - x0, larg = 5, tipo = "porta", cor = p.porta })
				table.insert(ab, {
					de = c - 3.5 - x0,
					larg = 3.4,
					tipo = "janela",
					peitoril = 3.6,
					alt = 3.8,
					vidro = false,
					cor = p.moldura,
				})
				table.insert(deco, { x = c - 3.5, larg = 3.4 })
			end
			E.parede({ x0, z0 }, { x1, z0 }, ab, { nome = "Fachada", cor = p.parede })
			for _, dc in deco do
				adornoJanela(
					E,
					"z",
					dc.x,
					z0,
					-1,
					dc.larg,
					3.6 + 1.9,
					3.8,
					if E.rng.chance(0.5) then "tapume" else "quebrada"
				)
			end
			portaVidro(E, { x = recX + 1.5, larg = 6 }, z0)
			-- números nas portas
			for i, c in cs do
				local n = E.bl(
					"Numero",
					c + 3.5,
					8.8,
					z0 - 0.6,
					1.2,
					0.9,
					0.2,
					{ 20, 20, 20 },
					"Metal",
					{ colide = false, consulta = false }
				)
				E.texto(n, tostring(100 + i), { 200, 190, 160 })
			end
			if A >= 2 then
				-- segundo andar: janelas e portas dos quartos dando para a galeria
				local abU = { { de = recX + 1.5 - x0, larg = 5, tipo = "porta", cor = p.porta } }
				for _, c in cs do
					table.insert(abU, { de = c + 3.5 - x0, larg = 5, tipo = "porta", cor = p.porta })
					table.insert(abU, {
						de = c - 3.5 - x0,
						larg = 3.4,
						tipo = "janela",
						peitoril = 3.6,
						alt = 3.8,
						vidro = true,
						cor = p.moldura,
					})
				end
				E.parede({ x0, z0 }, { x1, z0 }, abU, { nome = "Fachada", cor = p.parede, base = H })
				-- galeria: laje na frente e guarda-corpo
				E.bl(
					"Galeria",
					0,
					H - 0.5,
					(z0 - 5.5 + z0 - 0.5) / 2,
					x1 - x0 + 1,
					1,
					5.0,
					{ 104, 102, 98 },
					"Concrete"
				)
				E.bl("GuardaCorpo", 0, H + 1.9, z0 - 5.3, x1 - x0 + 1, 0.3, 0.3, p.ferro, "Metal")
				E.bl("GuardaCorpo", 0, H + 3.2, z0 - 5.3, x1 - x0 + 1, 0.3, 0.3, p.ferro, "Metal")
				for x = x0, x1, 4 do
					E.bl("GradeGuarda", x, H + 1.9, z0 - 5.3, 0.3, 3.8, 0.3, p.ferro, "Metal")
				end
				for _, x in { x0 + 0.5, -15, -1, 13, x1 - 0.5 } do
					E.bl("PilarGaleria", x, 6, z0 - 5.3, 0.9, 12, 0.9, { 112, 110, 104 }, "Concrete")
				end
			else
				-- marquise simples sobre as portas
				for _, c in cs do
					toldo(E, c + 1, 14, z0, 9.4)
				end
				toldo(E, recX + 1.5, 12, z0, 9.4)
			end
			-- letreiro alto
			local nome = nomeDe(E, nomes)
			letreiro(E, recX + 1.5, A * H + 2.6, 12, 3.2, z0 - 0.95, nome)
			E.bl(
				"Calcada",
				0,
				0.12,
				(-E.d / 2 + z0 - 0.5) / 2,
				x1 - x0 + 1,
				0.25,
				z0 - 0.5 + E.d / 2,
				{ 118, 118, 112 },
				"Concrete"
			)
			-- divisórias entre unidades
			local ox = { -15, -1, 13 }
			for _, x in ox do
				E.parede({ x, z0 }, { x, E.z1 }, nil, { nome = "Divisoria" })
			end
			-- quartos
			local function quarto(c, y, comBanho, simples)
				local S = { x0 = c - 6.5, x1 = c + 6.5, z0 = z0 + 0.5, z1 = E.iz1 }
				E.mobParede("cama_casal", "-x", -3, S, nil, y)
				E.mobParede("criado_mudo", "-x", -7.2, S, nil, y)
				if not simples then
					E.mobParede("criado_mudo", "-x", 0.8, S, nil, y)
				end
				-- banheiro no canto do fundo
				if not simples then
					local bx = c + 1
					E.parede({ bx, 3 }, { bx, E.z1 }, nil, { nome = "Banho", base = y, ext = 0 })
					E.parede(
						{ bx, 3 },
						{ c + 7, 3 },
						{ { de = 3.5, larg = 5, tipo = "porta", cor = p.porta } },
						{ nome = "Banho", base = y, ext = 0 }
					)
					local b = { x0 = c + 1.5, x1 = c + 6.5, z0 = 3.5, z1 = E.iz1 }
					E.mobParede("vaso_sanitario", "+z", c + 2.5, b, nil, y)
					E.mobParede("lavatorio", "+x", 6, b, nil, y)
					if comBanho and not simples then
						E.mobParede("box_chuveiro", "+z", c + 4.9, b, nil, y)
					end
				end
				if not simples then
					E.mobParede("movel_tv", "+z", c - 3.5, S, nil, y)
					E.mobParede("escrivaninha", "-x", 8.5, S, nil, y)
					E.mob("cadeira", c - 3, 8.5, -PI / 2, nil, y)
					E.mob("tapete", c - 1.5, -3, 0, { w = 7, d = 5 }, y)
				end
			end
			for _, c in cs do
				quarto(c, PISO_Y, true)
			end
			-- recepção
			local R = { x0 = x0 + 0.5, x1 = -15.5, z0 = z0 + 0.5, z1 = E.iz1 }
			E.mobParede("balcao_recepcao", "-x", -4, R, { w = 7 })
			E.mob("computador", -25.2, -4, -PI / 2, nil, PISO_Y + 3.6)
			E.mobParede("sofa_recepcao", "+x", -4, R)
			E.mobParede("arquivo_alto", "+z", recX + 4, R)
			E.mob("planta_vaso", -16.5, -8)
			if A >= 2 then
				local y = H
				E.escada(
					"Degrau",
					escada.x,
					escada.z,
					"-z",
					PISO_Y,
					H - PISO_Y,
					4.5,
					p.piso,
					"Concrete",
					{ passada = 1.2 }
				)
				for _, c in cs do
					quarto(c, y, false, true)
				end
				E.mobParede("cama_solteiro", "+x", 6, R, nil, y)
				E.loot(cs[1] - 3, 9, y)
				E.loot(cs[3] - 3, 9, y)
			end
			for _, c in cs do
				E.loot(c - 3, 9.5)
			end
			E.loot(recX + 3, 5)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.motel = motel()

-- ===============================================================================================================
-- OFICINA 40×32
-- ===============================================================================================================
local function oficina()
	local paletas = paletasDe(6, 5, {
		{ { 52, 52, 54 }, { 215, 175, 70 } },
		{ { 62, 34, 28 }, { 220, 205, 180 } },
		{ { 30, 44, 60 }, { 220, 220, 200 } },
		{ { 44, 54, 38 }, { 225, 200, 100 } },
	})
	local nomes = { "OFICINA MECÂNICA", "AUTO CENTER SILVA", "MECÂNICA DO PEDRO", "FUNILARIA & PINTURA" }
	return {
		paletas = paletas,
		construir = function(ctx, spec)
			local E = novoEnv(ctx, spec, "oficina", "oficina", 40, 32, 1, paletas)
			local p = E.p
			local S = E.sala
			local o = {
				porta = { x = 0, larg = 12, alt = 9, enrolar = true },
				janelasFrente = { { x = -13, larg = 6 }, { x = 13, larg = 6 } },
				janelasLado = { -2, 6 },
				janelasFundo = { -10 },
				fundo = { x = 4 },
				nome = nomeDe(E, nomes),
				letreiroLarg = 24,
				toldo = false,
			}
			casco(E, o)
			-- baias com elevadores
			E.mob("elevador_oficina", -9, 2, 0)
			E.carro(-9, 2, PI / 2, 1 + E.rng.inteiro(0, 4), 3.6)
			E.mob("elevador_oficina", 9, 2, 0)
			E.mob("caixa_ferramentas", 9, 6.5, 0.4)
			E.mobParede("bancada_trabalho", "+z", -12, S)
			E.mobParede("bancada_trabalho", "+z", -3.5, S)
			E.mobParede("compressor", "+z", 3, S)
			E.mobParede("expositor_pneus", "+x", -8, S)
			E.mobParede("expositor_pneus", "+x", -3, S)
			E.mobParede("quadro_eletrico", "-x", 7, S, nil, PISO_Y + 3)
			E.mob("tambor_oleo", -17.7, -9)
			E.mob("tambor_oleo", -17.7, -6.8)
			E.mob("pilha_pneus", -17, -3)
			E.mob("galao", -15.5, 8)
			E.mob("pilha_caixotes", -16.5, 1.5, 0, { w = 4, d = 4 })
			-- escritório
			E.parede({ 10, 7 }, { E.x1, 7 }, { { de = 4.5, larg = 5, tipo = "porta", cor = p.porta } })
			E.parede({ 10, 7 }, { 10, E.z1 }, nil)
			local es = { x0 = 10.5, x1 = E.ix1, z0 = 7.5, z1 = E.iz1 }
			E.mobParede("mesa_escritorio", "+z", 15.5, es)
			E.mob("computador", 15.5, 13.7, 0, nil, PISO_Y + 2.7)
			E.loot(0, -4)
			E.loot(-3, 8)
			E.loot(-14, 7)
			E.loot(16.5, 10)
			return finalizar(E, o)
		end,
	}
end
M.catalogo.oficina = oficina()

return M
