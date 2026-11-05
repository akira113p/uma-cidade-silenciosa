-- Edifícios industriais e rurais: galpões (máquinas, estoque, oficina), celeiro, galpão de serraria; estruturas (chaminé,
-- silo, tanques, torre d'água, moinho, guindaste); áreas (fazenda, serraria, ferro-velho, pátio da fábrica). Agente E6.
-- Contrato em docs/mapa-v2.md §5 e §8. Tudo em coordenadas locais ao `cf` (frente = −Z); aleatoriedade só por spec.rng/ctx.rng.

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local Mob = require("./mobilia")
local Props = require("./props")

local pi, floor, ceil, abs, max, min, sqrt = math.pi, math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt

local M = { catalogo = {}, estruturas = {}, areas = {}, tamanhos = {} }

local ESP = 0.8 -- espessura das paredes
local PISO = 0.05 -- topo do piso interno (Y local); o pad está em 0

local ESCURO = { 40, 40, 44 }
local ACO = { 70, 74, 80 }
local CONCRETO = { 112, 112, 108 }

-- ---------------------------------------------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------------------------------------------
local function ferr(ctx, pai, cf)
	local function b(nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
		return ctx.bloco(pai, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end
	local function c(nome, cx, cy, cz, diam, comp, cor, mat, op)
		return ctx.cilindro(pai, cf, nome, cx, cy, cz, diam, comp, cor, mat, op)
	end
	return b, c
end

local MINI = { consulta = false, sombra = false }
local DECOR = { colide = false, consulta = false, sombra = false }

local function esc(cor, k)
	return { cor[1] * k, cor[2] * k, cor[3] * k }
end

local function pal(mat, parede, telhado, portao, extra)
	local p = {
		mat = mat,
		parede = parede,
		faixa = esc(parede, 0.78),
		telhado = telhado,
		estrutura = { 66, 70, 74 },
		portao = portao,
		detalhe = { 172, 150, 62 },
		piso = { 94, 94, 90 },
		matTeto = "CorrodedMetal",
	}
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

local function mobiliar(ctx, m, cf, y, lista, rng)
	for _, it in lista do
		local op = { rng = rng }
		if it[5] then
			for k, v in it[5] do
				op[k] = v
			end
		end
		Mob.colocar(ctx, m, it[1], cf, it[2], y, it[3], it[4] or 0, op)
	end
end

-- trechos sólidos de [0, comp] fora das aberturas ({de, larg})
local function solidos(comp, aberturas)
	local lst = {}
	for _, a in aberturas do
		table.insert(lst, { a.de - a.larg / 2, a.de + a.larg / 2 })
	end
	table.sort(lst, function(p, q)
		return p[1] < q[1]
	end)
	local res, cur = {}, 0
	for _, r in lst do
		if r[1] - cur > 0.5 then
			table.insert(res, { cur, r[1] })
		end
		cur = max(cur, r[2])
	end
	if comp - cur > 0.5 then
		table.insert(res, { cur, comp })
	end
	return res
end

local function bloqueado(lista, p, margem)
	for _, it in lista or {} do
		local larg = it.larg or (if it.tipo == "porta" then 5.5 elseif it.tipo == "janela" then 0 else 14)
		if abs(p - it.pos) < larg / 2 + (margem or 0.8) then
			return true
		end
	end
	return false
end

-- guarda-corpo entre dois pontos (eixo X ou Z), base em y
local function corrimao(b, ax, az, bx, bz, y, cor)
	local horiz = abs(az - bz) < 0.01
	local len = if horiz then abs(bx - ax) else abs(bz - az)
	local mx, mz = (ax + bx) / 2, (az + bz) / 2
	local sx, sz = if horiz then len else 0.3, if horiz then 0.3 else len
	b("Corrimao", mx, y + 3.4, mz, sx, 0.3, sz, cor, "Metal", MINI)
	b("Corrimao", mx, y + 1.7, mz, sx, 0.25, sz, cor, "Metal", MINI)
	local n = max(1, ceil(len / 6))
	for i = 0, n do
		local t = i / n
		b("Montante", ax + (bx - ax) * t, y + 1.75, az + (bz - az) * t, 0.35, 3.5, 0.35, cor, "Metal", MINI)
	end
end

-- oitões em degraus sob o telhado de duas águas
local function oitoes(b, p, hx, hz, H, alt, cumZ, n)
	for _, s in { -1, 1 } do
		for i = 1, n do
			local f = 1 - (i - 0.5) / n
			local y = H + (i - 0.5) * alt / n
			if cumZ then
				b("Oitao", 0, y, s * hz, (2 * hx + ESP) * f, alt / n, ESP, p.parede, p.mat)
			else
				b("Oitao", s * hx, y, 0, ESP, alt / n, (2 * hz + ESP) * f, p.parede, p.mat)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Parede de galpão: parede + rodapé de concreto + nervuras de perfil por fora + portões de correr.
-- lado: "f" (−Z), "t" (+Z), "e" (−X), "d" (+X). lista: { pos (coordenada ao longo da parede, 0 = centro), tipo =
-- "portao"|"vao"|"porta"|"janela", larg?, alt?, peitoril? }
-- ---------------------------------------------------------------------------------------------------------------
local function muro(ctx, m, cf, cfg, p, lado, lista)
	local b = ferr(ctx, m, cf)
	local hx, hz = cfg.w / 2 - 1, cfg.d / 2 - 1
	local horiz = lado == "f" or lado == "t"
	local meia = if horiz then hx else hz
	local fixo, nx
	if lado == "f" then
		fixo, nx = -hz, -1
	elseif lado == "t" then
		fixo, nx = hz, 1
	elseif lado == "e" then
		fixo, nx = -hx, -1
	else
		fixo, nx = hx, 1
	end
	-- em "t" e "e" a parede é percorrida ao contrário para a folha da porta abrir para dentro
	local flip = lado == "t" or lado == "e"
	local s0 = if flip then meia else -meia
	local a = if horiz then { s0, fixo } else { fixo, s0 }
	local bb = if horiz then { -s0, fixo } else { fixo, -s0 }
	local function ao(t)
		return if flip then meia - t else -meia + t
	end
	local comp = 2 * meia
	local ab, nivel, todas = {}, {}, {}
	for _, it in lista do
		local de = if flip then meia - it.pos else it.pos + meia
		local e
		if it.tipo == "portao" then
			e = { de = de, larg = it.larg or 14, tipo = "vao", alt = cfg.altPortao }
		elseif it.tipo == "vao" then
			e = { de = de, larg = it.larg, tipo = "vao", alt = it.alt or cfg.altPortao }
		elseif it.tipo == "porta" then
			e = { de = de, larg = 5.5, tipo = "porta", alt = 7.5, cor = p.portao }
		else
			e = {
				de = de,
				larg = it.larg or 6,
				tipo = "janela",
				alt = it.alt or 3.5,
				peitoril = it.peitoril or 11,
				cor = p.estrutura,
			}
		end
		table.insert(ab, e)
		table.insert(todas, e)
		if it.tipo ~= "janela" then
			table.insert(nivel, e)
		end
	end
	ctx.parede(m, cf, "Parede", a, bb, 0, cfg.H, ESP, p.parede, p.mat, ab)

	-- peça alinhada à parede: `ao` = posição ao longo, `off` = deslocamento para fora a partir do eixo da parede
	local function P(nome, ao, y, off, sa, sy, so, cor, mat, op)
		if horiz then
			return b(nome, ao, y, fixo + nx * off, sa, sy, so, cor, mat, op)
		end
		return b(nome, fixo + nx * off, y, ao, so, sy, sa, cor, mat, op)
	end

	for _, s in solidos(comp, nivel) do
		P("Rodape", ao((s[1] + s[2]) / 2), 0.75, ESP / 2 + 0.3, s[2] - s[1], 1.5, 0.6, CONCRETO, "Concrete")
	end
	if not cfg.semNervuras then
		local t = 5
		while t < comp - 3 do
			local ok = true
			for _, e in todas do
				if abs(t - e.de) < e.larg / 2 + 0.9 then
					ok = false
				end
			end
			if ok then
				P("Nervura", ao(t), cfg.H / 2, ESP / 2 + 0.5, 0.9, cfg.H, 1.0, p.estrutura, "Metal")
			end
			t += 10
		end
	end
	if lado == "f" then
		P(
			"Faixa",
			0,
			cfg.altPortao + 1.6,
			ESP / 2 + 1.2,
			2 * meia - 6,
			0.8,
			0.2,
			p.detalhe,
			"Concrete",
			{ colide = false, sombra = false }
		)
	end

	-- portões de correr abertos, recolhidos por fora sobre a parede
	for _, it in lista do
		if it.tipo == "portao" then
			local larg = it.larg or 14
			local lados = if it.pos == 0 then { -1, 1 } else { if it.pos < 0 then -1 else 1 }
			local pw = if it.pos == 0 then larg / 2 else larg / 2 + 0.5
			local alt = cfg.altPortao - 0.5
			for _, l in lados do
				local c0 = it.pos + l * (larg / 2 + 0.5 + pw / 2)
				local off = ESP / 2 + 1.6
				P("PortaoCorrer", c0, alt / 2, off, pw, alt, 0.4, p.portao, "CorrodedMetal")
				P(
					"PortaoFaixa",
					c0,
					5.5,
					off + 0.25,
					pw - 0.4,
					0.8,
					0.1,
					p.detalhe,
					"Concrete",
					{ colide = false, consulta = false, sombra = false }
				)
				if cfg.xbrace and horiz then
					local ang = math.atan2(alt, pw)
					local len = sqrt(alt * alt + pw * pw)
					for _, sg in { -1, 1 } do
						b(
							"Cruz",
							c0,
							alt / 2,
							fixo + nx * (off + 0.25),
							len,
							0.5,
							0.15,
							p.estrutura,
							"WoodPlanks",
							{ rot = CFrame.Angles(0, 0, sg * ang), colide = false, consulta = false }
						)
					end
				end
				local e0 = it.pos + l * (larg / 2 - 0.5)
				local e1 = c0 + l * pw / 2
				P("TrilhoPortao", (e0 + e1) / 2, cfg.altPortao + 0.6, off - 0.4, abs(e1 - e0), 0.5, 0.6, ACO, "Metal")
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Casca de galpão/celeiro: Model, piso, 4 paredes, telhado de duas águas, oitões, tesouras de telhado, respiros.
-- ---------------------------------------------------------------------------------------------------------------
local function casca(ctx, spec, cfg, paredes)
	local p = spec.paleta
	local w, d, H, alt = cfg.w, cfg.d, cfg.H, cfg.alt
	local m = ctx.modeloConstrucao(spec, cfg.tipo, cfg.variante, w, d, H + alt, 1)
	local cf = spec.cf
	local b, c = ferr(ctx, m, cf)
	local hx, hz = w / 2 - 1, d / 2 - 1
	local cumZ = d > w
	ctx.piso(m, cf, "Piso", -hx - 0.4, hx + 0.4, -hz - 0.4, hz + 0.4, PISO, 0.6, p.piso, cfg.pisoMat or "Concrete")
	for _, lado in { "f", "t", "e", "d" } do
		muro(ctx, m, cf, cfg, p, lado, paredes[lado] or {})
	end
	ctx.telhadoDuasAguas(
		m,
		cf,
		"Telhado",
		0,
		0,
		2 * hx + ESP,
		2 * hz + ESP,
		H,
		alt,
		1.0,
		0.6,
		p.telhado,
		p.matTeto,
		cumZ
	)
	oitoes(b, p, hx, hz, H, alt, cumZ, cfg.passosOitao or 8)
	-- cumeeira e respiros
	local lc = if cumZ then 2 * hz + 2 else 2 * hx + 2
	local cumeSx, cumeSz = if cumZ then 1.4 else lc, if cumZ then lc else 1.4
	b("Cumeeira", 0, H + alt + 0.15, 0, cumeSx, 0.5, cumeSz, esc(p.telhado, 0.7), p.matTeto)
	if cfg.respiros then
		for _, q in { -1, 0, 1 } do
			local rx, rz = if cumZ then 0 else q * (hx * 0.6), if cumZ then q * (hz * 0.6) else 0
			c("Respiro", rx, H + alt + 1.1, rz, 3.2, 2.0, ACO, "Metal")
			b("RespiroTampa", rx, H + alt + 2.3, rz, 4.2, 0.4, 4.2, esc(p.telhado, 0.6), "Metal")
		end
	end
	-- tesouras
	local lim = if cumZ then hz else hx
	local atra = if cumZ then hx else hz -- meia largura transversal
	local fmax = floor((lim - 3) / 10) * 10
	for q = -fmax, fmax, 10 do
		local ax = if cumZ then { 0, q } else { q, 0 }
		if cumZ then
			b("Tirante", 0, H - 0.45, q, 2 * atra - 1, 0.7, 0.7, p.estrutura, "Metal", MINI)
		else
			b("Tirante", q, H - 0.45, 0, 0.7, 0.7, 2 * atra - 1, p.estrutura, "Metal", MINI)
		end
		b("Pendural", ax[1], H + (alt - 1.2) / 2 - 0.1, ax[2], 0.6, alt - 1.2, 0.6, p.estrutura, "Metal", MINI)
		for _, s in { -1, 1 } do
			if cumZ then
				ctx.rampa(
					m,
					cf,
					"Caibro",
					s * (atra - 0.6),
					H - 0.4,
					q,
					0,
					H + alt - 1.0,
					q,
					0.5,
					0.5,
					p.estrutura,
					"Metal"
				)
			else
				ctx.rampa(
					m,
					cf,
					"Caibro",
					q,
					H - 0.4,
					s * (atra - 0.6),
					q,
					H + alt - 1.0,
					0,
					0.5,
					0.5,
					p.estrutura,
					"Metal"
				)
			end
		end
	end
	return m, cf, b, c, hx, hz
end

local function infoPadrao(w, d, hz, xPorta)
	return { frente = { xPorta or 0, -(d / 2 + 4) }, portaria = { xPorta or 0, -hz } }
end

-- ---------------------------------------------------------------------------------------------------------------
-- galpao_maquinas (70×50, pé-direito 18)
-- ---------------------------------------------------------------------------------------------------------------
local PAL_MAQUINAS = {
	pal("Metal", { 112, 120, 116 }, { 84, 92, 90 }, { 128, 72, 56 }),
	pal("CorrodedMetal", { 104, 116, 100 }, { 70, 80, 74 }, { 150, 140, 110 }, { piso = { 88, 88, 84 } }),
	pal("Metal", { 98, 110, 128 }, { 74, 80, 92 }, { 140, 96, 60 }),
	pal("CorrodedMetal", { 150, 140, 118 }, { 100, 90, 80 }, { 96, 110, 100 }),
	pal("CorrodedMetal", { 128, 94, 74 }, { 86, 70, 62 }, { 90, 100, 108 }, { detalhe = { 160, 130, 56 } }),
}

local function maquinas(ctx, spec)
	local rng = spec.rng
	local p = spec.paleta
	local cfg = {
		tipo = "galpao",
		variante = "galpao_maquinas",
		w = 70,
		d = 50,
		H = 18,
		alt = 5,
		altPortao = 13,
		respiros = true,
	}
	local paredes = {
		f = { { pos = -18, tipo = "portao" }, { pos = 0, tipo = "porta" }, { pos = 18, tipo = "portao" } },
		t = { { pos = 12, tipo = "porta" }, { pos = 26, tipo = "janela", peitoril = 9 } },
		e = { { pos = -15, tipo = "janela" }, { pos = 0, tipo = "janela" } },
		d = { { pos = -15, tipo = "janela" }, { pos = 0, tipo = "janela" }, { pos = 15, tipo = "janela" } },
	}
	local m, cf, b, c, hx, hz = casca(ctx, spec, cfg, paredes)

	-- ponte rolante em trilhos
	local zr = hz - 0.85
	for _, s in { -1, 1 } do
		b("TrilhoPonte", 14, 13.0, s * zr, 38, 1.2, 0.9, p.estrutura, "Metal")
		for _, q in { 0, 10, 20, 30 } do
			if not bloqueado(paredes[if s < 0 then "f" else "t"], q) then
				b("Coluna", q, 6.2, s * zr, 0.9, 12.4, 0.9, p.estrutura, "Metal")
			end
		end
	end
	local bx = 8
	b("PonteRolante", bx, 14.5, 0, 1.2, 1.8, 2 * zr, p.detalhe, "Metal")
	for _, s in { -1, 1 } do
		b("TruquePonte", bx, 14.1, s * zr, 2.6, 1.0, 2.6, p.estrutura, "Metal")
	end
	b("Carrinho", bx, 12.7, -2, 2.8, 1.6, 3, p.detalhe, "Metal")
	c("Cabo", bx, 9.9, -2, 0.3, 4.2, ESCURO, "Metal", DECOR)
	b("Gancho", bx, 7.2, -2, 0.9, 1.2, 0.9, ESCURO, "Metal", { colide = false })

	-- escritório suspenso (mezanino) no canto de trás à esquerda
	local zf, xe = 7, -6
	ctx.piso(m, cf, "Mezanino", -hx + 0.4, xe, zf, hz - 0.4, 9, 0.8, { 100, 100, 96 }, "DiamondPlate")
	for _, pp in { { -31, 9.5 }, { -19, 9.5 }, { -7, 9.5 }, { -19, 22 }, { -7, 22 } } do
		b("PilarMezanino", pp[1], 4.3, pp[2], 1.0, 8.6, 1.0, p.estrutura, "Metal")
	end
	local esc_ = ctx.escada(m, cf, "Escada", -9, -6.5, "+z", PISO, 9 - PISO, 5, p.estrutura, "DiamondPlate")
	for _, xx in { -11.8, -6.2 } do
		ctx.rampa(m, cf, "CorrimaoEscada", xx, PISO + 3.2, -6.5, xx, 9 + 3.4, 7, 0.3, 0.3, p.estrutura, "Metal", MINI)
	end
	corrimao(b, -14, zf, -11.8, zf, 9, p.estrutura)
	corrimao(b, -6.2, zf, -6.2, hz - 0.4, 9, p.estrutura)
	corrimao(b, -11.8, zf, -6.2, zf, 9, p.estrutura) -- extremo da escada (fecha o lado aberto)
	local corOf = esc(p.faixa, 1.15)
	ctx.parede(m, cf, "Escritorio", { -hx + 0.4, zf }, { -14, zf }, 9, 7.5, ESP, corOf, "Concrete", {
		{ de = 6, larg = 5, tipo = "janela", alt = 3.5, peitoril = 3.4, cor = p.estrutura },
		{ de = 14, larg = 5, tipo = "janela", alt = 3.5, peitoril = 3.4, cor = p.estrutura },
	})
	ctx.parede(m, cf, "Escritorio", { -14, zf }, { -14, hz - 0.4 }, 9, 7.5, ESP, corOf, "Concrete", {
		{ de = 8, larg = 5.5, tipo = "porta", cor = p.portao },
		{ de = 13.5, larg = 4, tipo = "janela", alt = 3.5, peitoril = 3.4, cor = p.estrutura },
	})
	ctx.piso(m, cf, "ForroEscritorio", -hx + 0.4, -13.6, zf - 0.4, hz - 0.4, 17.0, 0.5, esc(corOf, 0.9), "Concrete")
	local sala = { x0 = -hx + 0.4, x1 = -14.4, z0 = zf + 0.4, z1 = hz - 0.4 }
	local mx, mz, mr = Mob.paraParede("mesa_escritorio", "+z", -26, sala, 0.1)
	mobiliar(ctx, m, cf, 9, {
		{ "mesa_escritorio", mx, mz, mr },
		{ "cadeira_escritorio", -26, 19.2, 0.4 },
		{ "arquivo_alto", -31.5, hz - 0.4 - 1.3, pi },
		{ "arquivo_alto", -19.5, hz - 0.4 - 1.3, pi },
		{ "mesa_reuniao", -22, 11.5, 0, { w = 8 } },
		{ "caixa_papelao", -33.6 + 1.6, 9.5, 0.3 },
	}, rng)
	Mob.colocar(ctx, m, "computador", cf, mx, 9 + 2.7, mz, mr, { rng = rng })
	Mob.colocar(ctx, m, "quadro_branco", cf, -33.6 + 0.05, 9 + 4.5, 15, -pi / 2, { rng = rng })

	-- piso de fábrica
	local f = {
		{ "maquina_industrial", -28, -12, 0, { variante = 1 } },
		{ "maquina_industrial", -20, -12, 0, { variante = 2 } },
		{ "maquina_industrial", 22, -12, 0, { variante = 3 } },
		{ "maquina_industrial", 30, -12, 0, { variante = 1 } },
		{ "maquina_industrial", -2, 8, 0, { variante = 2 } },
		{ "esteira", 14, 8, 0, { w = 24 } },
		{ "maquina_industrial", 30, 8, 0, { variante = 3 } },
		{ "maquina_industrial", -27, 15, 0, { variante = 2 } },
		{ "maquina_industrial", -17, 15, 0, { variante = 3 } },
		{ "pilha_caixotes", 8, -2, rng.entre(-0.2, 0.2) },
		{ "palete", -24, -2, 0.1 },
		{ "barril", -31, -4, 0 },
		{ "barril", -29, -4.5, 0 },
		{ "barril", -30.5, -1.8, 0 },
		{ "tubulacao", 32.6, 9, pi / 2, { w = 36 } },
		{ "quadro_eletrico", 33.6, PISO + 3 - PISO, -6, pi / 2 },
		{ "caldeira", 27, 19, 0 },
		{ "bancada_trabalho", 8, 20, 0 },
	}
	-- quadro elétrico e bancada: yPiso próprio
	for i = #f, 1, -1 do
		if f[i][1] == "quadro_eletrico" then
			table.remove(f, i)
		end
	end
	mobiliar(ctx, m, cf, PISO, f, rng)
	Mob.colocar(ctx, m, "quadro_eletrico", cf, 33.6, PISO + 3, -6, pi / 2, { rng = rng })
	Mob.colocar(ctx, m, "quadro_eletrico", cf, -33.6, PISO + 3, -6, -pi / 2, { rng = rng })

	local info = infoPadrao(70, 50, hz, 0)
	info.loot = {
		{ x = -20, y = 9, z = 17.5 },
		{ x = 30, y = PISO, z = -3 },
		{ x = -2, y = PISO, z = 19 },
		{ x = -26, y = PISO, z = 2 },
		{ x = 22, y = PISO, z = -3 },
	}
	local _ = esc_
	return m, info
end
M.catalogo.galpao_maquinas = { paletas = PAL_MAQUINAS, construir = maquinas }

-- ---------------------------------------------------------------------------------------------------------------
-- galpao_estoque (70×50, pé-direito 16)
-- ---------------------------------------------------------------------------------------------------------------
local PAL_ESTOQUE = {
	pal("Metal", { 126, 124, 112 }, { 90, 92, 88 }, { 96, 112, 100 }),
	pal("CorrodedMetal", { 96, 108, 120 }, { 72, 78, 88 }, { 150, 100, 64 }),
	pal("Metal", { 140, 134, 116 }, { 100, 96, 86 }, { 90, 100, 112 }),
	pal("CorrodedMetal", { 110, 100, 90 }, { 80, 74, 68 }, { 116, 126, 110 }),
	pal("Metal", { 100, 116, 104 }, { 74, 86, 80 }, { 140, 130, 100 }),
}

local function estoque(ctx, spec)
	local rng = spec.rng
	local p = spec.paleta
	local cfg = {
		tipo = "armazem",
		variante = "galpao_estoque",
		w = 70,
		d = 50,
		H = 16,
		alt = 4.5,
		altPortao = 12,
		respiros = true,
	}
	local paredes = {
		f = { { pos = -16, tipo = "portao" }, { pos = 0, tipo = "porta" }, { pos = 16, tipo = "portao" } },
		t = {
			{ pos = -20, tipo = "vao", larg = 8, alt = 8 },
			{ pos = -2, tipo = "vao", larg = 8, alt = 8 },
			{ pos = 18, tipo = "vao", larg = 8, alt = 8 },
		},
		e = { { pos = -10, tipo = "janela", peitoril = 9 }, { pos = 10, tipo = "janela", peitoril = 9 } },
		d = { { pos = -10, tipo = "janela", peitoril = 9 }, { pos = 10, tipo = "janela", peitoril = 9 } },
	}
	local m, cf, b = casca(ctx, spec, cfg, paredes)
	-- docas de carga atrás: plataforma de concreto
	for _, x in { -20, -2, 18 } do
		b("Doca", x, 0.4, 24 + 2.2, 9, 0.9, 2.6, CONCRETO, "Concrete", { colide = true })
	end
	local f = {}
	for fila, z in { -8, 2, 12 } do
		for _, x in { -28, -18, -8, 2 } do
			table.insert(f, { "estante_industrial", x, z, if fila % 2 == 0 then pi else 0, { w = 10 } })
		end
	end
	for _, it in
		{
			{ "palete", 18, -8, 0 },
			{ "pilha_caixotes", 18, -8 + 0, 0 },
			{ "palete", 26, -8, 0.1 },
			{ "pilha_caixotes", 26, -8, 0.3 },
			{ "palete", 18, 4, 0 },
			{ "pilha_caixotes", 18, 4, -0.2 },
			{ "palete", 26, 4, 0 },
			{ "barril", 31, 12, 0 },
			{ "barril", 29.5, 13, 0 },
			{ "barril", 31, 14.5, 0 },
			{ "empilhadeira", 26, 18, 0.6 },
			{ "palete", 14, 19, 0 },
			{ "bancada_trabalho", -6, 22, 0 },
		}
	do
		table.insert(f, it)
	end
	-- caixotes sobre os paletes: yPiso extra
	local sobre = {}
	for i = #f, 1, -1 do
		if f[i][1] == "pilha_caixotes" then
			table.insert(sobre, table.remove(f, i))
		end
	end
	mobiliar(ctx, m, cf, PISO, f, rng)
	for _, it in sobre do
		Mob.colocar(ctx, m, it[1], cf, it[2], PISO + 0.9, it[3], it[4], { rng = rng })
	end
	-- caixas no topo de algumas estantes
	for _, q in { { -28, -8 }, { -8, 2 }, { -18, 12 }, { 2, 12 } } do
		Mob.colocar(ctx, m, "caixa_papelao", cf, q[1], PISO + 7, q[2], rng.entre(-0.3, 0.3), { rng = rng })
	end
	Mob.colocar(ctx, m, "quadro_eletrico", cf, 33.6, PISO + 3, -12, pi / 2, { rng = rng })
	Mob.colocar(ctx, m, "quadro_eletrico", cf, -33.6, PISO + 3, 6, -pi / 2, { rng = rng })

	local info = infoPadrao(70, 50, 24, 0)
	info.loot = {
		{ x = -23, y = PISO, z = 7 },
		{ x = -13, y = PISO, z = -3 },
		{ x = 30, y = PISO, z = -16 },
		{ x = 6, y = PISO, z = 19 },
		{ x = 20, y = PISO, z = 22 },
	}
	return m, info
end
M.catalogo.galpao_estoque = { paletas = PAL_ESTOQUE, construir = estoque }

-- ---------------------------------------------------------------------------------------------------------------
-- galpao_oficina (50×40, pé-direito 14)
-- ---------------------------------------------------------------------------------------------------------------
local PAL_OFICINA = {
	pal("Metal", { 118, 112, 100 }, { 86, 84, 80 }, { 120, 70, 56 }),
	pal("CorrodedMetal", { 100, 112, 106 }, { 74, 84, 82 }, { 156, 136, 92 }),
	pal("Metal", { 112, 104, 128 }, { 80, 76, 96 }, { 150, 140, 110 }, { piso = { 84, 84, 86 } }),
	pal("CorrodedMetal", { 134, 100, 78 }, { 90, 74, 66 }, { 100, 112, 120 }),
}

local function oficina(ctx, spec)
	local rng = spec.rng
	local p = spec.paleta
	local cfg = { tipo = "oficina", variante = "galpao_oficina", w = 50, d = 40, H = 14, alt = 4, altPortao = 11 }
	local paredes = {
		f = {
			{ pos = -9, tipo = "portao" },
			{ pos = 12, tipo = "porta" },
			{ pos = 20, tipo = "janela", larg = 5, peitoril = 8 },
		},
		t = {
			{ pos = 0, tipo = "porta" },
			{ pos = -14, tipo = "janela", peitoril = 8 },
			{ pos = 14, tipo = "janela", peitoril = 8 },
		},
		e = { { pos = -8, tipo = "janela", peitoril = 8 }, { pos = 8, tipo = "janela", peitoril = 8 } },
		d = { { pos = -8, tipo = "janela", peitoril = 8 } },
	}
	local m, cf = casca(ctx, spec, cfg, paredes)
	-- escritório no canto de trás à direita
	local corOf = esc(p.faixa, 1.15)
	ctx.parede(m, cf, "Escritorio", { 12, 9 }, { 23.6, 9 }, 0, 8, ESP, corOf, "Concrete", {
		{ de = 6, larg = 5, tipo = "janela", alt = 3.5, peitoril = 3.4, cor = p.estrutura },
	})
	ctx.parede(m, cf, "Escritorio", { 12, 9 }, { 12, 18.6 }, 0, 8, ESP, corOf, "Concrete", {
		{ de = 4.8, larg = 5.5, tipo = "porta", cor = p.portao },
	})
	ctx.piso(m, cf, "ForroEscritorio", 11.6, 23.6, 8.6, 18.6, 8.5, 0.5, esc(corOf, 0.9), "Concrete")
	local sala = { x0 = 12.4, x1 = 23.6, z0 = 9.4, z1 = 18.6 }
	local mx, mz, mr = Mob.paraParede("mesa_escritorio", "+z", 18, sala, 0.1)
	mobiliar(ctx, m, cf, PISO, {
		{ "mesa_escritorio", mx, mz, mr },
		{ "cadeira_escritorio", 18, 15.6, 0.3 },
		{ "arquivo_alto", 22, 12, -pi / 2 },
		{ "caixa_papelao", 13.8, 17.4, 0.4 },
	}, rng)
	Mob.colocar(ctx, m, "computador", cf, mx, PISO + 2.7, mz, mr, { rng = rng })
	-- baias
	Mob.colocar(ctx, m, "elevador_oficina", cf, -14, PISO, -4, 0, { rng = rng })
	Mob.colocar(ctx, m, "elevador_oficina", cf, -14, PISO, 8, 0, { rng = rng })
	Props.carro(ctx, m, cf * CFrame.new(-14, PISO + 2.6, -4) * CFrame.Angles(0, pi / 2, 0), { variante = 3, rng = rng })
	Props.carro_destruido(
		ctx,
		m,
		cf * CFrame.new(12, PISO, -6) * CFrame.Angles(0, -0.25, 0),
		{ variante = 1, rng = rng }
	)
	local salaTodo = { x0 = -23.6, x1 = 23.6, z0 = -18.6, z1 = 18.6 }
	for _, it in
		{
			{ "bancada_trabalho", "+z", -18 },
			{ "bancada_trabalho", "+z", -8 },
			{ "compressor", "+z", 0 },
			{ "tambor_oleo", "+z", 3.5 },
			{ "tambor_oleo", "+z", 5.5 },
			{ "expositor_pneus", "-x", -10 },
			{ "expositor_pneus", "-x", 2 },
			{ "pilha_pneus", "-x", 14 },
		}
	do
		local x, z, r = Mob.paraParede(it[1], it[2], it[3], salaTodo, 0.1)
		Mob.colocar(ctx, m, it[1], cf, x, PISO, z, r, { rng = rng })
	end
	Mob.colocar(ctx, m, "caixa_ferramentas", cf, -18, PISO + 3.2, 17.4, 0.2, { rng = rng })
	Mob.colocar(ctx, m, "caixa_ferramentas", cf, -8, PISO + 3.2, 17.4, -0.3, { rng = rng })
	Mob.colocar(ctx, m, "quadro_eletrico", cf, 8, PISO + 3, 18.6, 0, { rng = rng })
	for _, q in { { 4, -12 }, { 5.5, -13 }, { 6.5, -11.5 } } do
		Mob.colocar(ctx, m, "galao", cf, q[1], PISO, q[2], rng.entre(-1, 1), { rng = rng })
	end
	local info = infoPadrao(50, 40, 19, 0)
	info.loot = {
		{ x = -2, y = PISO, z = -8 },
		{ x = 4, y = PISO, z = 4 },
		{ x = 18, y = PISO, z = 12.5 },
		{ x = -4, y = PISO, z = 12 },
	}
	return m, info
end
M.catalogo.galpao_oficina = { paletas = PAL_OFICINA, construir = oficina }

-- ---------------------------------------------------------------------------------------------------------------
-- celeiro (44×60): telhado alto de duas águas, portas grandes, baias, jirau de feno
-- ---------------------------------------------------------------------------------------------------------------
local PAL_CELEIRO = {
	pal(
		"WoodPlanks",
		{ 112, 52, 46 },
		{ 62, 58, 58 },
		{ 120, 60, 52 },
		{ estrutura = { 176, 170, 158 }, piso = { 84, 70, 54 } }
	),
	pal(
		"WoodPlanks",
		{ 118, 110, 96 },
		{ 70, 60, 54 },
		{ 130, 120, 104 },
		{ estrutura = { 84, 66, 52 }, piso = { 84, 70, 54 } }
	),
	pal(
		"WoodPlanks",
		{ 80, 90, 82 },
		{ 56, 60, 58 },
		{ 110, 100, 84 },
		{ estrutura = { 168, 164, 152 }, piso = { 80, 68, 54 } }
	),
	pal(
		"WoodPlanks",
		{ 96, 72, 56 },
		{ 70, 54, 48 },
		{ 150, 140, 120 },
		{ estrutura = { 150, 144, 130 }, piso = { 88, 72, 56 } }
	),
	pal(
		"WoodPlanks",
		{ 100, 104, 108 },
		{ 60, 62, 66 },
		{ 126, 72, 56 },
		{ estrutura = { 170, 168, 160 }, piso = { 84, 74, 60 } }
	),
}

local function celeiro(ctx, spec)
	local rng = spec.rng
	local p = spec.paleta
	local cfg = {
		tipo = "celeiro",
		variante = "celeiro",
		w = 44,
		d = 60,
		H = 17,
		alt = 11,
		altPortao = 14,
		xbrace = true,
		pisoMat = "Ground",
		passosOitao = 11,
	}
	local paredes = {
		f = { { pos = 0, tipo = "portao", larg = 16 } },
		t = {
			{ pos = 0, tipo = "porta" },
			{ pos = -12, tipo = "janela", peitoril = 5 },
			{ pos = 12, tipo = "janela", peitoril = 5 },
		},
		e = {
			{ pos = -14, tipo = "janela", larg = 4, peitoril = 6 },
			{ pos = 12, tipo = "janela", larg = 4, peitoril = 6 },
			{ pos = 24, tipo = "porta" },
		},
		d = {
			{ pos = -14, tipo = "janela", larg = 4, peitoril = 6 },
			{ pos = 12, tipo = "janela", larg = 4, peitoril = 6 },
		},
	}
	local m, cf, b, c, hx, hz = casca(ctx, spec, cfg, paredes)
	local topoJirau = 10
	-- jirau de feno sobre a metade de trás
	ctx.piso(m, cf, "Jirau", -hx + 0.4, hx - 0.4, 0, hz - 0.4, topoJirau, 0.8, { 100, 80, 58 }, "WoodPlanks")
	for _, pp in { { -12, 1 }, { 12, 1 }, { -12, 14 }, { 12, 14 }, { -12, 27 }, { 12, 27 } } do
		b("PostePrincipal", pp[1], topoJirau / 2 - 0.4, pp[2], 1.0, topoJirau - 0.8, 1.0, p.estrutura, "WoodPlanks")
	end
	ctx.escada(m, cf, "EscadaJirau", -18.3, -15, "+z", PISO, topoJirau - PISO, 4.5, { 110, 84, 60 }, "WoodPlanks")
	ctx.rampa(
		m,
		cf,
		"CorrimaoEscada",
		-15.9,
		PISO + 3.2,
		-15,
		-15.9,
		topoJirau + 3.4,
		0,
		0.3,
		0.3,
		p.estrutura,
		"WoodPlanks",
		MINI
	)
	corrimao(b, -15.9, 0, hx - 0.4, 0, topoJirau, p.estrutura)
	-- baias à direita, sob a luz da porta
	for _, z in { -22, -14, -6 } do
		b("DivisoriaBaia", 16.3, 2.2, z, 8.6, 4.4, ESP, { 104, 78, 56 }, "WoodPlanks")
	end
	for _, z in { -18, -10 } do
		b("Manjedoura", hx - 1.6, 1.6, z, 1.6, 0.8, 4, { 90, 66, 48 }, "WoodPlanks")
	end
	-- feno no jirau e no chão
	local f = {
		{ "fardo_feno", -16.5, -hz + 0, 0 },
	}
	f = {
		{ "fardo_feno", -17, 24, 0 },
		{ "fardo_feno", -17, 28, 0.1 },
		{ "fardo_feno", -12.5, 27.8, pi / 2 },
		{ "fardo_feno", 16.5, 27.8, 0 },
		{ "fardo_feno", 17, 23, pi / 2 },
		{ "fardo_feno", 17, 18, 0.2 },
		{ "fardo_feno", -17, 6, 0.1 },
		{ "fardo_feno", -17.2, 10, 0 },
	}
	mobiliar(ctx, m, cf, topoJirau, f, rng)
	mobiliar(ctx, m, cf, topoJirau + 3, { { "fardo_feno", -17, 26, 0.1 }, { "fardo_feno", 16.8, 25.5, 0 } }, rng)
	b("MontaFeno", 6, topoJirau + 0.75, 20, 15, 1.5, 10, { 156, 134, 76 }, "Sand")
	b("MontaFeno", 6, topoJirau + 2.0, 20, 11, 1.2, 7.5, { 164, 142, 80 }, "Sand")
	b("MontaFeno", 6, topoJirau + 3.1, 20, 6.5, 1.0, 4.5, { 168, 146, 84 }, "Sand")
	-- chão
	mobiliar(ctx, m, cf, PISO, {
		{ "fardo_feno", -17, 8, 0 },
		{ "fardo_feno", -17, 12, 0.15 },
		{ "fardo_feno", -17, 16, 0 },
		{ "fardo_feno", 17, 8, 0.1 },
		{ "fardo_feno", 17, 12, 0 },
		{ "bancada_ferramentas", 14, 22, 0 },
		{ "barril", 5, 24, 0 },
		{ "barril", 7.2, 24.5, 0 },
		{ "caixa_papelao", -6, 27, 0.3 },
		{ "bau", -2, 27.2, 0 },
		{ "caixa_ferramentas", -9, 26.5, 0.4 },
	}, rng)
	mobiliar(ctx, m, cf, PISO + 1.0, { { "fardo_feno", -17, 8.1, 0 } }, rng)
	local info = infoPadrao(44, 60, 29, 0)
	info.loot = {
		{ x = 0, y = topoJirau, z = 12 },
		{ x = -8, y = PISO, z = -10 },
		{ x = 16, y = PISO, z = -10 },
		{ x = 14, y = PISO, z = 2 },
	}
	local _ = c
	return m, info
end
M.catalogo.celeiro = { paletas = PAL_CELEIRO, construir = celeiro }

-- ---------------------------------------------------------------------------------------------------------------
-- serraria_galpao (56×36): serra de fita, esteira de toras, pilhas de tábuas
-- ---------------------------------------------------------------------------------------------------------------
local PAL_SERRARIA = {
	pal(
		"WoodPlanks",
		{ 112, 90, 68 },
		{ 84, 76, 70 },
		{ 90, 70, 54 },
		{ estrutura = { 78, 62, 48 }, piso = { 104, 90, 70 } }
	),
	pal(
		"WoodPlanks",
		{ 96, 104, 92 },
		{ 70, 78, 72 },
		{ 96, 80, 60 },
		{ estrutura = { 84, 70, 54 }, piso = { 100, 90, 72 } }
	),
	pal(
		"WoodPlanks",
		{ 128, 108, 84 },
		{ 96, 84, 74 },
		{ 100, 80, 64 },
		{ estrutura = { 90, 72, 56 }, piso = { 108, 92, 72 } }
	),
	pal(
		"WoodPlanks",
		{ 88, 78, 70 },
		{ 66, 62, 62 },
		{ 110, 88, 66 },
		{ estrutura = { 70, 58, 48 }, piso = { 96, 84, 68 } }
	),
}

local function pilhaTabuas(b, x, z, comp, larg, alt, cor, rng)
	local n = max(3, floor(alt / 0.7))
	local h = alt / n
	for i = 1, n do
		b(
			"Tabuas",
			x,
			(i - 0.5) * h,
			z,
			comp - rng.entre(0, 0.8),
			h * 0.9,
			larg,
			esc(cor, 0.92 + 0.12 * rng.rnd()),
			"WoodPlanks"
		)
	end
	for _, s in { -1, 1 } do
		b("Escora", x + s * comp * 0.35, alt / 2, z, 0.7, alt, larg + 0.2, esc(cor, 0.7), "Wood", MINI)
	end
end

local function serraFita(b, c, x, z, p)
	b("SerraBase", x, 0.8, z + 1, 5, 1.6, 12, ACO, "Metal")
	b("SerraTrilho", x - 1.6, 1.8, z + 1, 0.4, 0.5, 12, ESCURO, "Metal", MINI)
	b("SerraTrilho", x + 1.6, 1.8, z + 1, 0.4, 0.5, 12, ESCURO, "Metal", MINI)
	for _, s in { -1, 1 } do
		b("SerraColuna", x + s * 3.6, 6.5, z, 1.2, 13, 2.4, p.detalhe, "Metal")
	end
	b("SerraTravessa", x, 12.7, z, 8.4, 1.4, 2.4, p.detalhe, "Metal")
	c("RodaSuperior", x, 10, z, 4.8, 1.2, ESCURO, "Metal", { eixo = "x", consulta = false })
	c("RodaInferior", x, 3.8, z, 4.8, 1.2, ESCURO, "Metal", { eixo = "x", consulta = false })
	b("Lamina", x, 6.9, z - 2.3, 0.12, 6.2, 0.12, { 150, 150, 154 }, "Metal", { colide = false, consulta = false })
	b("Lamina", x, 6.9, z + 2.3, 0.12, 6.2, 0.12, { 150, 150, 154 }, "Metal", { colide = false, consulta = false })
	b("Painel", x + 3.6, 3.2, z - 1.3, 0.3, 2, 0.1, ESCURO, "Metal", DECOR)
end

local function serrariaGalpao(ctx, spec)
	local rng = spec.rng
	local p = spec.paleta
	local cfg = {
		tipo = "serraria",
		variante = "serraria_galpao",
		w = 56,
		d = 36,
		H = 14,
		alt = 4,
		altPortao = 11,
		semNervuras = false,
	}
	local paredes = {
		f = {
			{ pos = -14, tipo = "vao", larg = 14, alt = 11 },
			{ pos = 0, tipo = "porta" },
			{ pos = 14, tipo = "vao", larg = 14, alt = 11 },
		},
		t = { { pos = 12, tipo = "porta" }, { pos = -12, tipo = "janela", peitoril = 8 } },
		e = { { pos = -8, tipo = "janela", peitoril = 8 }, { pos = 8, tipo = "janela", peitoril = 8 } },
		d = {
			{ pos = 0, tipo = "porta" },
			{ pos = -9, tipo = "janela", peitoril = 8 },
			{ pos = 9, tipo = "janela", peitoril = 8 },
		},
	}
	local m, cf, b, c = casca(ctx, spec, cfg, paredes)
	serraFita(b, c, -14, 9, p)
	-- duto de exaustão sobre a esteira
	c("Duto", -14, 11.2, -2, 1.8, 28, { 120, 124, 126 }, "Metal", { eixo = "z", colide = false })
	for _, z in { -12, 2 } do
		b("DutoSuporte", -14, 12.7, z, 0.4, 3, 0.4, ACO, "Metal", DECOR)
	end
	for _, z in { -10, 0, 10 } do
		pilhaTabuas(b, 16, z, 12, 4.5, 5 + rng.entre(-0.6, 0.4), { 150, 118, 76 }, rng)
	end
	pilhaTabuas(b, 22, 14, 6, 3, 3, { 156, 124, 80 }, rng)
	b("Serragem", -22, 0.6, 12, 6, 1.2, 4, { 168, 140, 96 }, "Sand")
	b("Serragem", -20, 1.2, 12.4, 3.6, 0.8, 2.6, { 172, 144, 100 }, "Sand")
	-- toras sobre a esteira
	for _, z in { -13, -7, -1 } do
		c("Tora", -14, 4.1, z, 2.2, 5.2 + rng.entre(0, 0.8), { 98, 70, 48 }, "Wood", { eixo = "z" })
	end
	mobiliar(ctx, m, cf, PISO, {
		{ "esteira", -14, -6, pi / 2, { w = 22 } },
		{ "bancada_trabalho", 22, -2, pi / 2, { w = 8 } },
		{ "barril", 25, 6, 0 },
		{ "barril", 25, 8.3, 0 },
		{ "caixa_ferramentas", -24, 14, 0.4 },
		{ "caixa_papelao", -24.5, 10.5, 0.2 },
	}, rng)
	Mob.colocar(ctx, m, "quadro_eletrico", cf, -26.6 + 0.05, PISO + 3, -2, -pi / 2, { rng = rng })
	local info = infoPadrao(56, 36, 17, 0)
	info.loot = {
		{ x = -4, y = PISO, z = -8 },
		{ x = 4, y = PISO, z = 12 },
		{ x = -22, y = PISO, z = -2 },
	}
	return m, info
end
M.catalogo.serraria_galpao = { paletas = PAL_SERRARIA, construir = serrariaGalpao }

-- ---------------------------------------------------------------------------------------------------------------
-- Estruturas: function(ctx, pai, cf, op) → Model. cf = centro da base no chão. Footprints em M.tamanhos.
-- ---------------------------------------------------------------------------------------------------------------
local function novoModelo(ctx, pai, nome)
	local m = Instance.new("Model")
	m.Name = nome
	m:SetAttribute("Prop", nome)
	m:SetAttribute("Estrutura", nome)
	m.Parent = pai
	return m
end

local function escadaMarinheiro(b, x, z, eixo, y0, y1, cor)
	-- degraus de gato presos à estrutura (decorativo: sem colisão)
	local n = floor((y1 - y0) / 1.6)
	for _, s in { -0.5, 0.5 } do
		if eixo == "x" then
			b("LongaridaEscada", x, (y0 + y1) / 2, z + s, 0.2, y1 - y0, 0.2, cor, "Metal", DECOR)
		else
			b("LongaridaEscada", x + s, (y0 + y1) / 2, z, 0.2, y1 - y0, 0.2, cor, "Metal", DECOR)
		end
	end
	for i = 1, n do
		local y = y0 + i * 1.6 - 0.8
		if eixo == "x" then
			b("DegrauEscada", x, y, z, 0.2, 0.2, 1.1, cor, "Metal", DECOR)
		else
			b("DegrauEscada", x, y, z, 1.1, 0.2, 0.2, cor, "Metal", DECOR)
		end
	end
end

M.tamanhos.chamine = { 9, 9, 47.5 }
M.tamanhos.silo = { 15, 15, 35 }
M.tamanhos.tanque_elevado = { 14, 14, 34 }
M.tamanhos.tanque_combustivel = { 24, 9, 10 }
M.tamanhos.torre_agua = { 14, 14, 44 }
M.tamanhos.moinho = { 12, 12, 36 }
M.tamanhos.guindaste = { 14, 14, 34 }
M.tamanhos.poco = { 8, 8, 9 }

function M.estruturas.chamine(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "chamine")
	local b, c = ferr(ctx, m, cf)
	local tijolo = (op and op.cor) or { 124, 84, 70 }
	b("Base", 0, 1, 0, 9, 2, 9, CONCRETO, "Concrete")
	local dh = 6.5
	for i = 1, 7 do
		local diam = 7.2 - (i - 1) * 0.55
		c("Fuste", 0, 2 + (i - 0.5) * dh, 0, diam, dh, esc(tijolo, 1 - 0.025 * i), "Brick")
		if i == 3 or i == 5 then
			c("Anel", 0, 2 + i * dh, 0, diam + 0.5, 0.6, ACO, "Metal")
		end
	end
	local topo = 2 + 7 * dh
	c("Anel", 0, topo - 0.3, 0, 4.9, 0.8, ACO, "Metal")
	c("Fuligem", 0, topo + 0.05, 0, 3.2, 0.2, { 26, 24, 24 }, "Concrete", { colide = false })
	escadaMarinheiro(b, 0, -(7.2 / 2 + 0.2), "z", 2, topo - 4, ESCURO)
	return m
end

function M.estruturas.silo(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "silo")
	local b, c = ferr(ctx, m, cf)
	local cor = (op and op.cor) or { 128, 130, 126 }
	c("Fundacao", 0, 0.75, 0, 14.6, 1.5, CONCRETO, "Concrete")
	for i = 1, 3 do
		c("Anel", 0, 1.5 + (i - 0.5) * 9, 0, 13, 9, esc(cor, 1 - 0.04 * i), "CorrodedMetal")
		c("Cinta", 0, 1.5 + i * 9, 0, 13.5, 0.5, ACO, "Metal")
	end
	for i = 1, 4 do
		c("Cone", 0, 28.5 + (i - 0.5) * 1.6, 0, 12.4 - (i - 1) * 3.0, 1.6, esc(cor, 0.7), "CorrodedMetal")
	end
	c("Ventilacao", 0, 36, 0, 1.8, 2.2, ACO, "Metal")
	b("Porta", 0, 3.5, -6.6, 2.4, 3.4, 0.3, ESCURO, "Metal", DECOR)
	c("Duto", 4.2, 14, -6.9, 0.7, 26, ACO, "Metal", DECOR)
	escadaMarinheiro(b, -4, -6.9, "z", 1.5, 29, ESCURO)
	return m
end

function M.estruturas.tanque_elevado(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "tanque_elevado")
	local b, c = ferr(ctx, m, cf)
	local cor = (op and op.cor) or { 118, 124, 126 }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			b("Perna", sx * 5, 10.5, sz * 5, 0.9, 21, 0.9, ACO, "Metal")
		end
	end
	for _, y in { 8, 15 } do
		for _, s in { -1, 1 } do
			b("Cinta", s * 5, y, 0, 0.6, 0.6, 10, ACO, "Metal", MINI)
			b("Cinta", 0, y, s * 5, 10, 0.6, 0.6, ACO, "Metal", MINI)
		end
	end
	for _, s in { -1, 1 } do
		ctx.rampa(m, cf, "Diagonal", s * 5, 8, -5, -s * 5, 15, -5, 0.4, 0.4, ESCURO, "Metal", MINI)
		ctx.rampa(m, cf, "Diagonal", -5, 8, s * 5, -5, 15, -s * 5, 0.4, 0.4, ESCURO, "Metal", MINI)
	end
	b("Plataforma", 0, 21.2, 0, 12.4, 0.5, 12.4, ACO, "DiamondPlate")
	c("Tanque", 0, 25.5, 0, 12, 8, cor, "CorrodedMetal")
	c("Cinta", 0, 23.5, 0, 12.4, 0.5, ACO, "Metal")
	c("Cinta", 0, 27.5, 0, 12.4, 0.5, ACO, "Metal")
	c("Tampo", 0, 30.3, 0, 12.2, 1.6, esc(cor, 0.7), "CorrodedMetal")
	c("Tampo", 0, 31.7, 0, 6, 1.2, esc(cor, 0.7), "CorrodedMetal")
	c("Tubo", 0, 11, 0, 1.2, 21, ACO, "Metal", { colide = false })
	escadaMarinheiro(b, 5.7, 0, "x", 0.5, 22, ESCURO)
	return m
end

function M.estruturas.tanque_combustivel(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "tanque_combustivel")
	local b, c = ferr(ctx, m, cf)
	local cor = (op and op.cor) or { 128, 124, 112 }
	for _, x in { -8, 0, 8 } do
		b("Berco", x, 0.9, 0, 1.6, 1.8, 6, CONCRETO, "Concrete")
	end
	c("Casco", 0, 5, 0, 7.6, 22, cor, "CorrodedMetal", { eixo = "x" })
	for _, x in { -4.5, 4.5 } do
		c("Cinta", x, 5, 0, 7.9, 0.5, ACO, "Metal", { eixo = "x" })
	end
	c("Boca", 5.5, 8.9, 0, 2.2, 0.8, ACO, "Metal")
	c("Boca", -5.5, 8.9, 0, 2.2, 0.8, ACO, "Metal")
	b("Faixa", 0, 5, -3.85, 12, 1.4, 0.1, { 170, 60, 50 }, "Concrete", DECOR)
	c("Tubo", 11.6, 2.4, 0, 0.8, 3, ACO, "Metal", MINI)
	b("Valvula", 11.6, 4.1, 0, 1.2, 0.6, 0.6, { 150, 40, 36 }, "Metal", MINI)
	escadaMarinheiro(b, 11.2, 0, "x", 0.5, 8.6, ESCURO)
	if op and op.bund then
		for _, s in { -1, 1 } do
			b("Contencao", 0, 1.1, s * 7.2, 28, 2.2, 0.8, CONCRETO, "Concrete")
			b("Contencao", s * 14, 1.1, 0, 0.8, 2.2, 14.4, CONCRETO, "Concrete")
		end
	end
	return m
end

function M.estruturas.torre_agua(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "torre_agua")
	local b, c = ferr(ctx, m, cf)
	local cor = (op and op.cor) or { 132, 134, 130 }
	b("Fundacao", 0, 0.75, 0, 8, 1.5, 8, CONCRETO, "Concrete")
	c("Fuste", 0, 14, 0, 5, 26, cor, "Concrete")
	for _, y in { 8, 16, 24 } do
		c("Cinta", 0, y, 0, 5.4, 0.5, ACO, "Metal")
	end
	c("Suporte", 0, 28.2, 0, 8, 2.4, esc(cor, 0.85), "Concrete")
	c("Tanque", 0, 34, 0, 14, 8.4, esc(cor, 1.05), "Concrete")
	c("Cinta", 0, 31, 0, 14.4, 0.5, ACO, "Metal")
	c("Cinta", 0, 37, 0, 14.4, 0.5, ACO, "Metal")
	c("Teto", 0, 38.9, 0, 14, 1.4, esc(cor, 0.6), "Slate")
	c("Teto", 0, 40.2, 0, 8, 1.2, esc(cor, 0.6), "Slate")
	c("Teto", 0, 41.4, 0, 2.6, 1.2, esc(cor, 0.6), "Slate")
	b("Porta", 0, 3.5, -4.1, 2.6, 5, 0.3, ESCURO, "Metal", DECOR)
	escadaMarinheiro(b, 0, -2.7, "z", 1.5, 27, ESCURO)
	return m
end

function M.estruturas.moinho(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "moinho")
	local b, c = ferr(ctx, m, cf)
	local ferro = (op and op.cor) or { 118, 100, 84 }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ctx.rampa(m, cf, "Perna", sx * 5, 0, sz * 5, sx * 1.4, 28, sz * 1.4, 0.7, 0.7, ferro, "Metal")
		end
	end
	for _, y in { 6, 12, 18, 24 } do
		local k = 5 - (y / 28) * 3.6
		for _, s in { -1, 1 } do
			b("Cinta", 0, y, s * k, 2 * k, 0.4, 0.4, ferro, "Metal", MINI)
			b("Cinta", s * k, y, 0, 0.4, 0.4, 2 * k, ferro, "Metal", MINI)
		end
	end
	b("Plataforma", 0, 28.2, 0, 3.6, 0.4, 3.6, ACO, "DiamondPlate")
	b("Cabeca", 0, 29.4, 0, 1.4, 1.8, 3, ESCURO, "Metal")
	b("Leme", 0, 29.6, 4.6, 0.2, 2.6, 5.4, { 140, 100, 80 }, "Metal", { colide = false })
	c("Hub", 0, 29.6, -2, 1, 1.2, ESCURO, "Metal", { eixo = "z", colide = false })
	for i = 0, 7 do
		local a = i * pi / 4 + 0.2
		local lx, ly = math.cos(a), math.sin(a)
		ctx.rampa(
			m,
			cf,
			"Pa",
			lx * 1.2,
			29.6 + ly * 1.2,
			-2.6,
			lx * 7.4,
			29.6 + ly * 7.4,
			-2.6,
			1.4,
			0.2,
			{ 150, 140, 124 },
			"Metal",
			DECOR
		)
	end
	c("Bomba", 0, 3, 0, 1.2, 6, ACO, "Metal", { colide = false })
	b("Reservatorio", 0, 0.5, 0, 3, 1, 3, CONCRETO, "Concrete", { colide = false })
	return m
end

function M.estruturas.guindaste(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "guindaste")
	local b, c = ferr(ctx, m, cf)
	local cor = (op and op.cor) or { 164, 138, 62 }
	b("EsteiraE", -4.4, 1.0, 0, 3, 2, 12, ESCURO, "Metal")
	b("EsteiraD", 4.4, 1.0, 0, 3, 2, 12, ESCURO, "Metal")
	b("Chassi", 0, 2.6, 0, 10, 1.2, 10, cor, "Metal")
	b("Cabine", 2.6, 5.2, -2.4, 4, 4, 4.4, cor, "Metal")
	b("CabineVidro", 2.6, 5.4, -4.7, 3.2, 2.4, 0.2, { 80, 100, 110 }, "Glass", { transparencia = 0.5 })
	b("Contrapeso", 0, 4.4, 3.8, 8, 3.6, 3, esc(cor, 0.7), "Metal")
	b("Mastro", -2, 11, 0, 1.8, 20, 1.8, cor, "Metal")
	ctx.rampa(m, cf, "Lanca", -2, 20.5, 0, -2, 30, -17, 1.6, 1.2, cor, "Metal")
	ctx.rampa(m, cf, "Tirante", -2, 21, 0, -2, 30, -17, 0.3, 0.3, ESCURO, "Metal", DECOR)
	c("Cabo", -2, 24, -16.5, 0.25, 12, ESCURO, "Metal", DECOR)
	c("Iman", -2, 17.6, -16.5, 3.4, 0.9, ESCURO, "Metal", { colide = false })
	return m
end

function M.estruturas.poco(ctx, pai, cf, op)
	local m = novoModelo(ctx, pai, "poco")
	local b, c = ferr(ctx, m, cf)
	c("Anel", 0, 1.1, 0, 5.2, 2.2, (op and op.cor) or { 118, 112, 104 }, "Cobblestone")
	c("Agua", 0, 1.9, 0, 3.6, 0.2, { 20, 28, 30 }, "Glass", { colide = false, consulta = false })
	for _, s in { -1, 1 } do
		b("Poste", s * 2.4, 4.2, 0, 0.5, 6, 0.5, { 90, 66, 48 }, "Wood")
	end
	b("Eixo", 0, 6.6, 0, 5.6, 0.4, 0.4, { 80, 60, 44 }, "Wood", MINI)
	ctx.rampa(m, cf, "Telhadinho", -3.4, 6.6, 0, 0, 8.6, 0, 4.6, 0.3, { 70, 52, 44 }, "WoodPlanks")
	ctx.rampa(m, cf, "Telhadinho", 3.4, 6.6, 0, 0, 8.6, 0, 4.6, 0.3, { 70, 52, 44 }, "WoodPlanks")
	b("Balde", 0, 4.6, 0, 0.8, 0.9, 0.8, ACO, "Metal", { colide = false })
	return m
end

-- ---------------------------------------------------------------------------------------------------------------
-- Áreas
-- ---------------------------------------------------------------------------------------------------------------
local function colocarEstrutura(ctx, nome, x, z, rotY, op, pasta)
	local y = ctx.topoEm(x, z)
	local m =
		M.estruturas[nome](ctx, pasta or ctx.pastas.Props, CFrame.new(x, y, z) * CFrame.Angles(0, rotY or 0, 0), op)
	local t = M.tamanhos[nome]
	local w, d = t[1], t[2]
	if rotY and abs(abs(rotY) - pi / 2) < 0.01 then
		w, d = d, w
	end
	ctx.inserirObstaculo(x - w / 2, x + w / 2, z - d / 2, z + d / 2)
	return m
end

local function lajeChao(ctx, nome, x0, x1, z0, z1, topo, cor, mat)
	return ctx.laje("Chao", nome, x0, x1, z0, z1, topo, 0.1, cor, mat)
end

-- cerca de madeira em segmentos de até 40 ao longo de um eixo; lacunas = lista de {de, ate} (coordenada ao longo)
local function cerca(ctx, pasta, x0, z0, x1, z1, lacunas)
	local horiz = z0 == z1
	local a, bb = if horiz then x0 else z0, if horiz then x1 else z1
	local lo, hi = min(a, bb), max(a, bb)
	local n = max(1, ceil((hi - lo) / 40))
	local seg = (hi - lo) / n
	for i = 1, n do
		local centro = lo + (i - 0.5) * seg
		local pular = false
		for _, l in lacunas or {} do
			if centro >= l[1] and centro <= l[2] then
				pular = true
			end
		end
		if not pular then
			local x, z = if horiz then centro else x0, if horiz then z0 else centro
			Props.colocar(ctx, pasta, "cerca_madeira", x, z, if horiz then 0 else pi / 2, { w = seg })
		end
	end
end

local function contarPecas(pasta)
	local n = 0
	for _, d in pasta:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- ---------------------------------------------------------------------------------------------------------------
-- Fazenda (planície 600×600). Faixa de 40 livre ao sul (z1) e a leste (x1), onde as estradas tocam o pad.
-- ---------------------------------------------------------------------------------------------------------------
function M.areas.fazenda(ctx, ret)
	local Cat = require("./catalogo")
	local rng = ctx.rng("fazenda")
	local props = ctx.pastas.Props
	local topo = ctx.NIVEL_PAD
	local N = topo + 0.1
	local Z = "planicie"
	local x0, x1, z0, z1 = ret.x0, ret.x1, ret.z0, ret.z1
	-- offsets em relação ao canto noroeste do pad (-1500, -1500) garantem que o layout acompanhe o retângulo
	local ox, oz = x0 + 300, z0 + 300 -- centro da fazenda (pad 600×600 → (-1200,-1200))
	local function X(v)
		return ox + v
	end
	local function Zc(v)
		return oz + v
	end

	-- terreiro e caminhos de terra
	local terra = { 98, 82, 62 }
	lajeChao(ctx, "Terreiro", X(-100), X(160), Zc(-160), Zc(0), N, terra, "Ground")
	local caminho = { 110, 94, 72 }
	-- sul: da faixa livre (z1 − 40) até o terreiro; leste: da faixa livre (x1 − 40) até o terreiro
	ctx.laje("Chao", "CaminhoSul", X(100) - 6, X(100) + 6, Zc(0) - 1, z1 - 40, topo + 0.06, 0.1, caminho, "Ground")
	ctx.laje(
		"Chao",
		"CaminhoLeste",
		X(130) - 6,
		x1 - 40,
		Zc(-200) - 6,
		Zc(-200) + 6,
		topo + 0.06,
		0.1,
		caminho,
		"Ground"
	)
	ctx.laje(
		"Chao",
		"CaminhoLeste2",
		X(130) - 6,
		X(130) + 6,
		Zc(-200),
		Zc(-160) + 1,
		topo + 0.06,
		0.1,
		caminho,
		"Ground"
	)

	-- casa de fazenda
	do
		local spec = {
			cf = CFrame.new(X(100), topo, Zc(-90)) * CFrame.Angles(0, pi, 0),
			zona = Z,
			local_ = "Fazenda",
			andares = 2,
			rng = ctx.rng("fazenda_casa"),
		}
		local modelo, info = Cat.construir(ctx, "casa_media", spec)
		ctx.registrarConstrucao(spec, modelo, info)
	end
	-- celeiro, de frente para o terreiro (leste)
	do
		local spec = {
			cf = CFrame.new(X(-30), topo, Zc(-90)) * CFrame.Angles(0, -pi / 2, 0),
			zona = Z,
			local_ = "Fazenda",
			andares = 1,
			rng = ctx.rng("fazenda_celeiro"),
		}
		spec.w, spec.d = 44, 60
		spec.paleta = rng.escolher(M.catalogo.celeiro.paletas)
		local modelo, info = celeiro(ctx, spec)
		ctx.registrarConstrucao(spec, modelo, info)
	end
	-- silos em fila atrás do celeiro
	for i = 0, 2 do
		colocarEstrutura(ctx, "silo", X(-50 + i * 20), Zc(-138), 0, nil, props)
	end
	colocarEstrutura(ctx, "moinho", X(140), Zc(-130), 0, nil, props)
	colocarEstrutura(ctx, "poco", X(50), Zc(-120), 0, nil, props)
	Props.colocar(ctx, props, "trator", X(40), Zc(-50), 0.5)
	-- fardos junto ao celeiro e ao terreiro
	for _, f in
		{
			{ 10, -150, 0 },
			{ 16, -150, 0.3 },
			{ 13, -150, 0.1, 4.5 },
			{ 10, -144, 0.2 },
			{ 130, -60, 0.4 },
			{ 136, -64, 0 },
			{ 133, -62, 0.2, 4.5 },
		}
	do
		Props.colocar(
			ctx,
			props,
			"fardo_feno_ext",
			X(f[1]),
			Zc(f[2]),
			f[3],
			{ y = if f[4] then topo + 0.1 + f[4] else nil }
		)
	end

	-- campos de plantação
	local function campo(nome, cx0, cx1, cz0, cz1, cor, espaco)
		lajeChao(ctx, nome, X(cx0), X(cx1), Zc(cz0), Zc(cz1), N, { 70, 56, 42 }, "Mud")
		local z = cz0 + 3
		while z < cz1 - 1.5 do
			ctx.bloco(
				ctx.pastas.Chao,
				CFrame.new(),
				"Plantacao",
				X((cx0 + cx1) / 2),
				N + 0.2,
				Zc(z),
				cx1 - cx0 - 6,
				0.4,
				2.2,
				ctx.variar(cor, 0.08, rng),
				"LeafyGrass"
			)
			z += espaco
		end
	end
	campo("CampoA", -270, -140, -330, -250, { 112, 124, 66 }, 5)
	campo("CampoB", -120, 40, -330, -260, { 126, 120, 62 }, 5)
	campo("CampoD", -270, -140, -90, 0, { 98, 118, 60 }, 5)
	-- milharal: fileiras altas sem colisão (o jogador atravessa, mas perde a visão)
	do
		local cx0, cx1, cz0, cz1 = -270, -140, -230, -120
		lajeChao(ctx, "CampoMilho", X(cx0), X(cx1), Zc(cz0), Zc(cz1), N, { 66, 52, 38 }, "Ground")
		local z = cz0 + 6
		while z < cz1 - 4 do
			for _, seg in { { cx0 + 4, -213 }, { -197, cx1 - 4 } } do
				local len = seg[2] - seg[1]
				local cxm = X((seg[1] + seg[2]) / 2)
				ctx.bloco(
					ctx.pastas.Vegetacao,
					CFrame.new(),
					"Milho",
					cxm,
					N + 3.4,
					Zc(z),
					len,
					6.6,
					3,
					{ 102, 112, 58 },
					"Grass",
					DECOR
				)
				ctx.bloco(
					ctx.pastas.Vegetacao,
					CFrame.new(),
					"MilhoTopo",
					cxm,
					N + 6.9,
					Zc(z),
					len,
					0.5,
					2.2,
					{ 150, 138, 80 },
					"Grass",
					DECOR
				)
			end
			z += 14
		end
	end

	-- pasto cercado ao sul do terreiro
	local pasto = { x0 = X(-120), x1 = X(80), z0 = Zc(30), z1 = Zc(200) }
	lajeChao(ctx, "Pasto", pasto.x0, pasto.x1, pasto.z0, pasto.z1, N, { 72, 92, 54 }, "Grass")
	cerca(ctx, props, pasto.x0, pasto.z0, pasto.x1, pasto.z0, { { X(0) - 12, X(0) + 12 } })
	cerca(ctx, props, pasto.x0, pasto.z1, pasto.x1, pasto.z1)
	cerca(ctx, props, pasto.x0, pasto.z0, pasto.x0, pasto.z1)
	cerca(ctx, props, pasto.x1, pasto.z0, pasto.x1, pasto.z1)
	for _, f in { { -60, 100 }, { -52, 108 }, { 40, 150 } } do
		Props.colocar(ctx, props, "fardo_feno_ext", X(f[1]), Zc(f[2]), rng.entre(0, 3))
	end
	-- cercas dos campos e do terreiro
	cerca(ctx, props, X(-270), Zc(-245), X(40), Zc(-245), { { X(-100) - 3, X(-100) + 3 } })
	cerca(ctx, props, X(-270), Zc(-115), X(-140), Zc(-115))
	cerca(ctx, props, X(-270), Zc(-95), X(-270), Zc(5))
	cerca(ctx, props, X(-270), Zc(5), X(-140), Zc(5))
	cerca(ctx, props, X(-100), Zc(-165), X(110), Zc(-165), { { X(130) - 20, X(130) + 20 } })
	cerca(ctx, props, X(-100), Zc(-5), X(60), Zc(-5), { { X(0) - 12, X(0) + 12 } })

	-- loot externo
	for _, q in
		{
			{ 70, -45 },
			{ 0, -50 },
			{ -75, -170 },
			{ 25, -105 },
			{ 130, -90 },
			{ -205, -125 },
			{ -190, -40 },
			{ -10, 100 },
		}
	do
		ctx.loot(X(q[1]), ctx.topoEm(X(q[1]), Zc(q[2])), Zc(q[2]), "fabrica", Z)
	end
	print(
		string.format(
			"[fazenda] %d peças em Props, %d em Construcoes",
			contarPecas(props),
			contarPecas(ctx.pastas.Construcoes)
		)
	)
	local _ = { z0, x0 }
end

-- ---------------------------------------------------------------------------------------------------------------
-- Serraria (120×100): galpão à esquerda, pátio de toras à direita (a estrada de terra entra por +X, z = centro)
-- ---------------------------------------------------------------------------------------------------------------
function M.areas.serraria(ctx, ret)
	local rng = ctx.rng("serraria")
	local props = ctx.pastas.Props
	local topo = ctx.NIVEL_PAD
	local Z = "floresta"
	local cx, cz = (ret.x0 + ret.x1) / 2, (ret.z0 + ret.z1) / 2
	-- galpão: frente para +X (rotY = −π/2): o eixo local X vira o mundo Z
	local gx, gz = ret.x0 + 6 + 18, cz
	local spec = {
		cf = CFrame.new(gx, topo, gz) * CFrame.Angles(0, -pi / 2, 0),
		zona = Z,
		local_ = "Serraria",
		andares = 1,
		rng = ctx.rng("serraria_galpao"),
	}
	spec.w, spec.d = 56, 36
	spec.paleta = rng.escolher(M.catalogo.serraria_galpao.paletas)
	local modelo, info = serrariaGalpao(ctx, spec)
	ctx.registrarConstrucao(spec, modelo, info)

	local fx = gx + 18 -- frente do galpão
	-- esteira externa até o portão da esquerda (local x = −14 → mundo z = gz − 14)
	local ez = gz - 14
	Mob.colocar(ctx, props, "esteira", CFrame.new(), fx + 15, topo, ez, 0, { w = 30, rng = rng })
	ctx.inserirObstaculo(fx, fx + 30, ez - 1.8, ez + 1.8)
	for i = 0, 2 do
		ctx.cilindro(
			props,
			CFrame.new(),
			"Tora",
			fx + 6 + i * 9,
			topo + 2.6 + 1.1,
			ez,
			2.2,
			6,
			{ 98, 70, 48 },
			"Wood",
			{ eixo = "x" }
		)
	end
	-- pilhas de toras e tábuas
	for _, q in { { 52, -34 }, { 66, -34 }, { 52, -42 }, { 80, -40 } } do
		Props.colocar(ctx, props, "pilha_toras", fx + q[1] - 40, cz + q[2], rng.entre(-0.1, 0.1))
	end
	Props.colocar(ctx, props, "pilha_toras", fx + 22, cz + 40, 0.05)
	Props.colocar(ctx, props, "pilha_toras", fx + 36, cz + 40, -0.05)
	Props.colocar(ctx, props, "pilha_toras", fx + 50, cz + 40, 0.05, { y = topo + 6 })
	Props.colocar(ctx, props, "caminhao", fx + 40, cz - 24, pi / 2)
	local b = ferr(ctx, props, CFrame.new())
	pilhaTabuas(b, fx + 16, cz + 22, 12, 4.5, 5.2, { 150, 118, 76 }, rng)
	pilhaTabuas(b, fx + 16 + 18, cz + 22, 12, 4.5, 4.4, { 156, 124, 80 }, rng)
	ctx.inserirObstaculo(fx + 8, fx + 40, cz + 19.5, cz + 25)
	-- cerrote circular de bancada ao ar livre
	local sx, sz = fx + 56, cz + 12
	b("Bancada", sx, topo + 1.6, sz, 8, 0.8, 4, { 110, 84, 60 }, "WoodPlanks")
	for _, s in { -1, 1 } do
		b("Perna", sx + s * 3.4, topo + 0.8, sz, 0.8, 1.6, 3.4, { 90, 66, 48 }, "Wood", MINI)
	end
	ctx.cilindro(
		props,
		CFrame.new(),
		"Lamina",
		sx,
		topo + 3.1,
		sz,
		3.6,
		0.15,
		{ 160, 160, 164 },
		"Metal",
		{ eixo = "z", colide = false }
	)
	b("Resguardo", sx, topo + 3.1, sz - 0.9, 3.8, 2.8, 0.2, ACO, "Metal", DECOR)
	ctx.inserirObstaculo(sx - 4, sx + 4, sz - 2, sz + 2)
	-- barris, serragem e tocos
	for _, q in { { 70, -8 }, { 72.4, -8.5 } } do
		Mob.colocar(ctx, props, "barril", CFrame.new(), fx + q[1] - 40, topo, cz + q[2], 0, { rng = rng })
	end
	b("Serragem", fx + 24, topo + 0.6, cz + 6, 8, 1.2, 6, { 168, 140, 96 }, "Sand")
	-- loot externo (pátio livre, longe das pilhas)
	for _, q in { { 28, 6 }, { 60, -10 }, { 46, 20 }, { 70, 10 } } do
		local x, z = fx + q[1] - 20, cz + q[2]
		ctx.loot(x, ctx.topoEm(x, z), z, "fabrica", Z)
	end
	print(
		string.format(
			"[serraria] %d peças em Props, %d em Construcoes",
			contarPecas(props),
			contarPecas(ctx.pastas.Construcoes)
		)
	)
	local _ = cx
end

-- ---------------------------------------------------------------------------------------------------------------
-- Ferro-velho (120×100): cerca de chapa, pilhas de carros, containers, guindaste, casinha do dono
-- ---------------------------------------------------------------------------------------------------------------
local function chapa(ctx, pasta, x0, z0, x1, z1, lacunas, rng, topo)
	local horiz = z0 == z1
	local a, bb = if horiz then x0 else z0, if horiz then x1 else z1
	local lo, hi = min(a, bb), max(a, bb)
	local n = max(1, ceil((hi - lo) / 11))
	local seg = (hi - lo) / n
	for i = 1, n do
		local centro = lo + (i - 0.5) * seg
		local pular = false
		for _, l in lacunas or {} do
			if centro >= l[1] and centro <= l[2] then
				pular = true
			end
		end
		if not pular then
			local h = 5.4 + rng.entre(-0.5, 0.8)
			local cor = ctx.variar({ 124, 96, 74 }, 0.18, rng)
			local mat = if rng.chance(0.4) then "Metal" else "CorrodedMetal"
			local x, z = if horiz then centro else x0, if horiz then z0 else centro
			ctx.bloco(
				pasta,
				CFrame.new(),
				"Chapa",
				x,
				topo + h / 2,
				z,
				if horiz then seg else 0.5,
				h,
				if horiz then 0.5 else seg,
				cor,
				mat
			)
			local px, pz = if horiz then centro + seg / 2 else x0, if horiz then z0 else centro + seg / 2
			ctx.bloco(pasta, CFrame.new(), "PosteChapa", px, topo + 3.4, pz, 0.8, 6.8, 0.8, ACO, "Metal", MINI)
		end
	end
end

local function cz_(ret)
	return (ret.z0 + ret.z1) / 2
end

function M.areas.ferroVelho(ctx, ret)
	local rng = ctx.rng("ferro_velho")
	local props = ctx.pastas.Props
	local topo = ctx.NIVEL_PAD
	local Z = "floresta"
	local cx = (ret.x0 + ret.x1) / 2
	local fx0, fx1, fz0, fz1 = ret.x0 + 4, ret.x1 - 4, ret.z0 + 4, ret.z1 - 4
	-- cerca de chapa; portão (vão) no lado sul (z1), centrado
	chapa(ctx, props, fx0, fz0, fx1, fz0, nil, rng, topo)
	chapa(ctx, props, fx0, fz1, fx1, fz1, { { cx - 8, cx + 8 } }, rng, topo)
	chapa(ctx, props, fx0, fz0, fx0, fz1, nil, rng, topo)
	chapa(ctx, props, fx1, fz0, fx1, fz1, nil, rng, topo)
	for _, s in { -1, 1 } do
		ctx.bloco(
			props,
			CFrame.new(),
			"Folha",
			cx + s * 11,
			topo + 3,
			fz1 + 1.2,
			8,
			6,
			0.4,
			{ 130, 84, 60 },
			"CorrodedMetal",
			{ rotY = s * 0.25, colide = false }
		)
		ctx.bloco(props, CFrame.new(), "PosteChapa", cx + s * 8.2, topo + 3.9, fz1, 1, 7.8, 1, ACO, "Metal")
	end
	ctx.inserirObstaculo(fx0 - 1, fx1 + 1, fz0 - 1, fz0 + 1)
	ctx.inserirObstaculo(fx0 - 1, fx0 + 1, fz0, fz1)
	ctx.inserirObstaculo(fx1 - 1, fx1 + 1, fz0, fz1)

	-- pilhas de carros em duas fileiras ao norte (vão no meio)
	local nCarros = 0
	for fila, zf in { fz0 + 6, fz0 + 11.8 } do
		for i = 1, 8 do
			if i ~= 5 then
				local altura = if fila == 1 then rng.inteiro(2, 3) else rng.inteiro(1, 2)
				for k = 1, altura do
					Props.colocar(
						ctx,
						props,
						"carro_destruido",
						fx0 + 6 + 11.4 * (i - 0.5) + rng.entre(-0.4, 0.4),
						zf,
						pi / 2 + rng.entre(-0.08, 0.08),
						{ variante = rng.inteiro(1, 3), y = topo + (k - 1) * 4.4, rng = rng, obstaculo = (k == 1) }
					)
					nCarros += 1
				end
			end
		end
	end
	-- containers a oeste (um empilhado)
	local wx = ret.x0 + 16
	Props.colocar(ctx, props, "container_carga", wx, cz_(ret) - 6, pi / 2, { rng = rng })
	Props.colocar(
		ctx,
		props,
		"container_carga",
		wx,
		cz_(ret) - 6,
		pi / 2,
		{ y = topo + 8.6, rng = rng, obstaculo = false }
	)
	Props.colocar(ctx, props, "container_carga", wx, cz_(ret) + 18, pi / 2 + 0.06, { rng = rng })
	colocarEstrutura(ctx, "guindaste", ret.x1 - 18, ret.z0 + 42, 0, nil, props)
	-- espalhados
	for _, q in { { -26, -8 }, { 10, 0 }, { 14, 20 }, { -30, 26 } } do
		Props.colocar(
			ctx,
			props,
			"carro_destruido",
			cx + q[1],
			(ret.z0 + ret.z1) / 2 + q[2],
			rng.entre(0, 6),
			{ variante = rng.inteiro(1, 3), rng = rng }
		)
	end
	for _, q in { { -14, 22 }, { -8, 24 }, { 26, 22 } } do
		Props.colocar(ctx, props, "pilha_pneus_ext", cx + q[1], ret.z1 - 14 + q[2] * 0, 0)
	end
	Props.colocar(ctx, props, "entulho", cx - 16, cz_(ret) + 4, 0.3)
	Props.colocar(ctx, props, "entulho", cx + 16, cz_(ret) - 6, -0.2)
	for _, q in { { 9, 8 }, { 11.2, 8.6 }, { 10, 10.4 } } do
		Mob.colocar(ctx, props, "barril", CFrame.new(), cx + q[1], topo, cz_(ret) + q[2], 0, { rng = rng })
	end

	-- casinha do dono (sudeste), frente para oeste
	do
		local spec = {
			cf = CFrame.new(ret.x1 - 16, topo, ret.z1 - 20) * CFrame.Angles(0, pi / 2, 0),
			zona = Z,
			local_ = "Ferro-velho",
			andares = 1,
			rng = ctx.rng("ferro_velho_casa"),
			w = 22,
			d = 16,
		}
		local modelo, info = M.casinha(ctx, spec)
		ctx.registrarConstrucao(spec, modelo, info)
	end

	-- loot externo
	for _, q in { { 0, 4 }, { -14, -12 }, { 14, -14 }, { -34, 8 }, { 10, 28 }, { 26, 8 } } do
		local x, z = cx + q[1], cz_(ret) + q[2]
		ctx.loot(x, ctx.topoEm(x, z), z, "fabrica", Z)
	end
	print(
		string.format(
			"[ferroVelho] %d peças em Props (%d carros), %d em Construcoes",
			contarPecas(props),
			nCarros,
			contarPecas(ctx.pastas.Construcoes)
		)
	)
end

-- casinha de chapa e madeira do dono do ferro-velho (22×16, uma água)
function M.casinha(ctx, spec)
	local rng = spec.rng
	local w, d, H = 22, 16, 9
	local m = ctx.modeloConstrucao(spec, "casa", "casinha_ferro_velho", w, d, H + 3.5, 1)
	local cf = spec.cf
	local b = ferr(ctx, m, cf)
	local hx, hz = w / 2 - 1, d / 2 - 1
	local cor = ctx.variar({ 122, 104, 84 }, 0.1, rng)
	ctx.piso(m, cf, "Piso", -hx - 0.4, hx + 0.4, -hz - 0.4, hz + 0.4, PISO, 0.6, { 84, 66, 50 }, "WoodPlanks")
	ctx.parede(m, cf, "Parede", { -hx, -hz }, { hx, -hz }, 0, H, ESP, cor, "WoodPlanks", {
		{ de = 6, larg = 5, tipo = "porta", cor = { 90, 64, 50 } },
		{ de = 16, larg = 4.5, tipo = "janela", alt = 3.4, peitoril = 3.4, cor = { 80, 60, 46 } },
	})
	ctx.parede(m, cf, "Parede", { -hx, hz }, { hx, hz }, 0, H, ESP, cor, "CorrodedMetal", {
		{ de = 11, larg = 4.5, tipo = "janela", alt = 3.4, peitoril = 3.4, cor = { 80, 60, 46 } },
	})
	ctx.parede(m, cf, "Parede", { -hx, -hz }, { -hx, hz }, 0, H, ESP, cor, "CorrodedMetal", {
		{ de = 7, larg = 4, tipo = "janela", alt = 3.4, peitoril = 3.4, cor = { 80, 60, 46 } },
	})
	ctx.parede(m, cf, "Parede", { hx, -hz }, { hx, hz }, 0, H, ESP, cor, "WoodPlanks", {
		{ de = 7, larg = 4, tipo = "janela", alt = 3.4, peitoril = 3.4, cor = { 80, 60, 46 } },
	})
	ctx.parede(m, cf, "Divisoria", { 4.5, -hz }, { 4.5, hz }, 0, H, ESP, esc(cor, 0.9), "WoodPlanks", {
		{ de = 7, larg = 5.5, tipo = "porta", cor = { 90, 64, 50 } },
	})
	oitoes(b, { parede = cor, mat = "WoodPlanks" }, hx, hz, H, 3.5, false, 4)
	ctx.telhadoDuasAguas(
		m,
		cf,
		"Telhado",
		0,
		0,
		2 * hx + ESP,
		2 * hz + ESP,
		H,
		3.5,
		1.0,
		0.5,
		{ 96, 70, 56 },
		"CorrodedMetal",
		false
	)
	b("Chamine", -6, H + 3.2, 4, 1.8, 3.6, 1.8, { 120, 120, 118 }, "Brick")
	b("Degrau", -5, 0.3, -hz - 1.4, 5, 0.6, 2, CONCRETO, "Concrete")
	-- sala (x < 4.5) e quarto (x > 4.5)
	mobiliar(ctx, m, cf, PISO, {
		{ "fogao", -9, 6.5, pi },
		{ "geladeira", -6, 6.6, pi },
		{ "pia_cozinha", -2.5, 6.8, pi },
		{ "mesa_cozinha", -8, -1, 0 },
		{ "cadeira", -10.6, -1, pi / 2 },
		{ "sofa_pequeno", 1.5, -5.2, 0 },
		{ "poltrona", -10, -4.5, 0.3 },
		{ "cama_solteiro", 9.4, 4, 0 },
		{ "criado_mudo", 6.6, 6.8, 0 },
		{ "guarda_roupa", 9.6, -6.6, pi },
		{ "caixa_papelao", 7, -5, 0.4 },
	}, rng)
	local info = infoPadrao(w, d, hz, -hx + 6 - hx * 0 - 0)
	info.frente = { 0, -(hz + 4) }
	info.portaria = { -hx + 6 - 0, -hz }
	info.loot = { { x = -4, y = PISO, z = 0 }, { x = 8, y = PISO, z = -1 } }
	return m, info
end

-- ---------------------------------------------------------------------------------------------------------------
-- Pátio da fábrica: estruturas nos retângulos livres (livres = lista de {x0,x1,z0,z1})
-- ---------------------------------------------------------------------------------------------------------------
function M.areas.patioFabrica(ctx, ret, livres)
	local rng = ctx.rng("patio_fabrica")
	local props = ctx.pastas.Props
	local topo = ctx.NIVEL_PAD
	local colocados = {}
	local itens = {
		{ peso = 3, tipo = "container", w = 20, d = 8.6 },
		{ peso = 1.5, tipo = "chamine", w = 9, d = 9 },
		{ peso = 1.5, tipo = "silo", w = 15, d = 15 },
		{ peso = 1, tipo = "tanque_elevado", w = 14, d = 14 },
		{ peso = 1.5, tipo = "tanque_combustivel", w = 24, d = 9, gira = true },
		{ peso = 0.7, tipo = "torre_agua", w = 14, d = 14 },
		{ peso = 1.5, tipo = "tubovia", w = 36, d = 3, gira = true },
		{ peso = 1.2, tipo = "pneus", w = 5, d = 5 },
	}
	local function cabe(x0, x1, z0, z1)
		if not (x0 >= ret.x0 - 3 and x1 <= ret.x1 + 3 and z0 >= ret.z0 - 3 and z1 <= ret.z1 + 3) then
			return false
		end
		for _, r in colocados do
			if x0 - 5 < r[2] and x1 + 5 > r[1] and z0 - 5 < r[4] and z1 + 5 > r[3] then
				return false
			end
		end
		return not ctx.retanguloOcupado(x0, x1, z0, z1, 1)
	end
	local total = 0
	for _, L in livres do
		local area = (L.x1 - L.x0) * (L.z1 - L.z0)
		local alvo = max(1, min(10, floor(area / 300)))
		local feitos, tent = 0, 0
		while feitos < alvo and tent < 80 do
			tent += 1
			local it = rng.sortear(itens)
			local gira = it.gira and rng.chance(0.5)
			local w, d = if gira then it.d else it.w, if gira then it.w else it.d
			if it.tipo == "tubovia" then
				w, d = if gira then 3 else rng.entre(24, 40), if gira then rng.entre(24, 40) else 3
			end
			if L.x1 - L.x0 - 2 >= w and L.z1 - L.z0 - 2 >= d then
				local x = rng.entre(L.x0 + 1 + w / 2, L.x1 - 1 - w / 2)
				local z = rng.entre(L.z0 + 1 + d / 2, L.z1 - 1 - d / 2)
				if cabe(x - w / 2, x + w / 2, z - d / 2, z + d / 2) then
					local rot = if gira then pi / 2 else 0
					if it.tipo == "container" then
						local girar = (L.x1 - L.x0) < (L.z1 - L.z0) and gira == false and w > d
						Props.colocar(
							ctx,
							props,
							"container_carga",
							x,
							z,
							if girar then pi / 2 else 0,
							{ rng = rng, obstaculo = false }
						)
						if rng.chance(0.4) then
							Props.colocar(
								ctx,
								props,
								"container_carga",
								x,
								z,
								0,
								{ y = topo + 8.6, rng = rng, obstaculo = false }
							)
						end
					elseif it.tipo == "tubovia" then
						local len = if gira then d else w
						local pb = ferr(ctx, props, CFrame.new(x, topo, z) * CFrame.Angles(0, rot, 0))
						local nn = max(2, ceil(len / 12))
						for i = 0, nn do
							local t = -len / 2 + len * i / nn
							pb("SuportePerna", t, 4.5, 0, 0.8, 9, 0.8, ACO, "Metal", MINI)
						end
						for _, yy in { 9.3, 10.9 } do
							local cil = ctx.cilindro(
								props,
								CFrame.new(x, topo, z) * CFrame.Angles(0, rot, 0),
								"Tubo",
								0,
								yy,
								0,
								1.4,
								len,
								{ 118, 104, 92 },
								"Metal",
								{ eixo = "x", colide = false }
							)
							local _ = cil
						end
						pb("Travessa", 0, 8.4, 0, len, 0.5, 2.4, ACO, "Metal", MINI)
					elseif it.tipo == "pneus" then
						Props.colocar(ctx, props, "pilha_pneus_ext", x, z, rng.entre(0, 3))
					else
						colocarEstrutura(ctx, it.tipo, x, z, rot, nil, props)
					end
					if it.tipo ~= "pneus" then
						ctx.inserirObstaculo(x - w / 2, x + w / 2, z - d / 2, z + d / 2)
					end
					table.insert(colocados, { x - w / 2, x + w / 2, z - d / 2, z + d / 2 })
					feitos += 1
					total += 1
				end
			end
		end
		-- loot: 1 ponto por ~3 itens, em chão livre
		local nloot = max(1, floor(feitos / 3))
		for _ = 1, nloot do
			for _ = 1, 30 do
				local x = rng.entre(L.x0 + 2, L.x1 - 2)
				local z = rng.entre(L.z0 + 2, L.z1 - 2)
				local ok = true
				for _, r in colocados do
					if x > r[1] - 3 and x < r[2] + 3 and z > r[3] - 3 and z < r[4] + 3 then
						ok = false
						break
					end
				end
				if ok and not ctx.ocupado(x, z, 2) then
					ctx.loot(x, ctx.topoEm(x, z), z, "fabrica", "fabrica")
					break
				end
			end
		end
	end
	print(string.format("[patioFabrica] %d itens, %d peças em Props", total, contarPecas(props)))
end

return M
