-- Pontes (plano.pontes), passarelas (Mundo.pontesPedestres) e viadutos (plano.viadutos). Piso em `Ruas`; pilares, vigas,
-- guarda-corpo, muros de arrimo e placas em `Props`. Contrato: docs/mapa-v2.md §8 (T2).
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Instance = roblox.Instance
local Enum = roblox.Enum

local floor, ceil, min, max, abs, pi = math.floor, math.ceil, math.min, math.max, math.abs, math.pi

local M = {}

local ASFALTO = { 62, 62, 66 }
local CONCRETO = { 112, 112, 108 }
local CONCRETO_ESC = { 86, 86, 84 }
local CALCADA = { 122, 120, 114 }
local ACO = { 74, 78, 80 }
local MADEIRA = { 98, 78, 58 }
local AMARELA = { 150, 132, 62 }
local BRANCA = { 150, 150, 146 }

local ESP_PONTE = 1.2 -- tabuleiro: topo 0,5, fundo -0,7 (a água fica em -0,8)
local BASE_PONTE = 0.5 - ESP_PONTE
local ESP_VIADUTO = 2.5
local LARG_CALCADA = 4

-- Quadro local de uma obra reta: origem no ponto `along` do eixo, +X local = sentido do eixo, Z local = transversal.
-- (eixo "z": +X local = +Z do mundo e +Z local = −X do mundo.)
local function quadro(eixo: string, along: number, fixo: number)
	if eixo == "x" then
		return CFrame.new(along, 0, fixo)
	end
	return CFrame.new(fixo, 0, along) * CFrame.Angles(0, -pi / 2, 0)
end

local function retMundo(eixo: string, a0: number, a1: number, s0: number, s1: number, fixo: number)
	if eixo == "x" then
		return a0, a1, fixo + s0, fixo + s1
	end
	return fixo + s0, fixo + s1, a0, a1
end

function M.gerar(ctx)
	local plano = ctx.plano
	local Mundo = ctx.Mundo
	local rng = ctx.rng("pontes")
	local Ruas, Props = ctx.pastas.Ruas, ctx.pastas.Props
	local ID = CFrame.new()
	local resumo = { pontes = {}, passarelas = {}, viadutos = {} }
	ctx.pontesResumo = resumo

	local FINO = { colide = false, consulta = false, sombra = false }

	-- Laje inclinada ao longo de X local (s0 == s1): a face de cima passa pela linha (t0,y0)→(t1,y1).
	-- (ctx.rampa usa CFrame.lookAt, que no Lune sai com a inclinação errada para linhas ao longo de X.)
	local function rampa(pai, cf, nome, t0, y0, s0, t1, y1, _s1, larg, esp, cor, mat, op)
		local dt, dy = t1 - t0, y1 - y0
		local len = math.sqrt(dt * dt + dy * dy)
		local th = math.atan2(dy, dt)
		if dt < 0 then
			th = math.atan2(-dy, -dt)
		end
		local cx = (t0 + t1) / 2 + math.sin(th) * esp / 2
		local cy = (y0 + y1) / 2 - math.cos(th) * esp / 2
		local o = { rot = CFrame.Angles(0, 0, th) }
		for k, v in op or {} do
			o[k] = v
		end
		return ctx.bloco(pai, cf, nome, cx, cy, s0, len, esp, larg, cor, mat, o)
	end

	local function leito(x: number, z: number): number
		return min(ctx.altura(x, z), -plano.profundidadeRio(x, z))
	end
	local function mundoXZ(q, t: number, s: number)
		local p = q:PointToWorldSpace(Vector3.new(t, 0, s))
		return p.X, p.Z
	end

	-- Guarda-corpo: barreira de concreto + montantes + corrimões, seguindo uma linha (t0,y0)→(t1,y1) em Z local = s
	local function parapeito(q, t0, y0, t1, y1, s)
		rampa(Props, q, "Barreira", t0, y0 + 1.2, s, t1, y1 + 1.2, s, 1.0, 1.2, CONCRETO, "Concrete")
		local len = abs(t1 - t0)
		local nn = max(1, ceil(len / 6))
		for i = 0, nn do
			local f = i / nn
			local t, y = t0 + (t1 - t0) * f, y0 + (y1 - y0) * f
			ctx.bloco(Props, q, "Montante", t, y + 2.4, s, 0.5, 2.4, 0.5, ACO, "Metal", { consulta = false })
		end
		rampa(Props, q, "Corrimao", t0, y0 + 3.7, s, t1, y1 + 3.7, s, 0.45, 0.35, ACO, "Metal", { consulta = false })
		rampa(
			Props,
			q,
			"Corrimao",
			t0,
			y0 + 2.5,
			s,
			t1,
			y1 + 2.5,
			s,
			0.3,
			0.3,
			ACO,
			"Metal",
			{ colide = false, consulta = false }
		)
	end

	-- Marcas de pista sobre uma linha (t0,y0)→(t1,y1): bordas brancas, centro amarelo, faixas brancas tracejadas
	local function marcasPerfil(q, W, t0, y0, t1, y1)
		local function reta(ta, tb, s, larg, cor)
			local fa, fb = (ta - t0) / (t1 - t0), (tb - t0) / (t1 - t0)
			rampa(
				Ruas,
				q,
				"Faixa",
				ta,
				y0 + (y1 - y0) * fa + 0.06,
				s,
				tb,
				y0 + (y1 - y0) * fb + 0.06,
				s,
				larg,
				0.12,
				cor,
				"SmoothPlastic",
				FINO
			)
		end
		local function tracejada(s, larg, cor, dash, gap)
			local sentido = if t1 > t0 then 1 else -1
			local a, b = min(t0, t1), max(t0, t1)
			local d = ceil((a + 1) / (dash + gap)) * (dash + gap)
			while d + dash <= b - 1 do
				if sentido > 0 then
					reta(d, d + dash, s, larg, cor)
				else
					reta(d + dash, d, s, larg, cor)
				end
				d += dash + gap
			end
		end
		for _, sg in { -1, 1 } do
			reta(t0, t1, sg * (W / 2 - 1.4), 0.4, BRANCA)
			if W >= 30 then
				reta(t0, t1, sg * 0.45, 0.3, AMARELA)
				tracejada(sg * W / 4, 0.35, BRANCA, 9, 13)
			end
		end
		if W < 30 then
			tracejada(0, 0.4, AMARELA, 8, 12)
		end
	end

	-- Placa verde com texto (SurfaceGui). Se o ambiente não aceitar SurfaceGui, fica a placa lisa.
	local function placa(q, t, s, rotY, ty, linha1, linha2)
		local qp = q * CFrame.new(t, 0, s) * CFrame.Angles(0, rotY, 0)
		for _, dx in { -3.4, 3.4 } do
			ctx.bloco(Props, qp, "PostePlaca", dx, ty + 3, 0, 0.6, 7.5, 0.6, ACO, "Metal")
		end
		local painel = ctx.bloco(Props, qp, "PlacaPonte", 0, ty + 6, 0, 9, 3.2, 0.4, { 44, 86, 58 }, "Metal")
		local ok = pcall(function()
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.Parent = painel
			local txt = Instance.new("TextLabel")
			txt.Size = (roblox :: any).UDim2.new(1, 0, 1, 0)
			txt.BackgroundTransparency = 1
			txt.Text = linha1 .. "\n" .. linha2
			txt.TextColor3 = (roblox :: any).Color3.fromRGB(225, 225, 215)
			txt.TextScaled = true
			txt.Parent = gui
		end)
		return ok
	end

	-- ------------------------------------------------------------------------------------------------------
	-- (a) PONTES sobre rios
	-- ------------------------------------------------------------------------------------------------------
	local placasOk = true
	for _, p in plano.pontes do
		local est = plano.estradaPorNome[p.estrada]
		local seg = nil
		local ao = if p.eixo == "x" then p.centro[1] else p.centro[2]
		for _, sg in est.segs do
			if sg.eixo == p.eixo and sg.fixo == p.fixo and ao >= sg.a0 and ao <= sg.a1 then
				seg = sg
				break
			end
		end
		local a0 = if seg then max(p.a0, seg.a0) else p.a0
		local a1 = if seg then min(p.a1, seg.a1) else p.a1
		local L = a1 - a0
		if L >= 4 then
			local lar = p.largura
			local W = lar + 2 * LARG_CALCADA
			local q = quadro(p.eixo, (a0 + a1) / 2, p.fixo)
			local fixo = p.fixo

			local function laje(nome, s0, s1, cor, mat)
				local x0, x1, z0, z1 = retMundo(p.eixo, a0, a1, s0, s1, fixo)
				local peca = ctx.laje("Ruas", nome, x0, x1, z0, z1, 0.5, ESP_PONTE, cor, mat)
				peca:SetAttribute("Ponte", p.nome)
				return peca
			end
			laje("Tabuleiro", -lar / 2, lar / 2, ASFALTO, "Asphalt")
			laje("TabuleiroCalcada", lar / 2, lar / 2 + LARG_CALCADA, CALCADA, "Concrete")
			laje("TabuleiroCalcada", -lar / 2 - LARG_CALCADA, -lar / 2, CALCADA, "Concrete")
			marcasPerfil(q, lar, -L / 2 + 0.5, 0.5, L / 2 - 0.5, 0.5)

			-- guarda-corpo (com 6 de prolongamento em cada cabeceira, só a barreira baixa)
			for _, sg in { -1, 1 } do
				local s = sg * (W / 2 - 0.5)
				parapeito(q, -L / 2, 0.5, L / 2, 0.5, s)
				for _, e in { -1, 1 } do
					ctx.bloco(Props, q, "BarreiraCabeceira", e * (L / 2 + 3), 1.0, s, 6, 1.0, 1.0, CONCRETO, "Concrete")
				end
			end

			-- vigas longitudinais e travessas sob o tabuleiro
			for _, sg in { -1, 1 } do
				ctx.bloco(
					Props,
					q,
					"Viga",
					0,
					BASE_PONTE - 1.1,
					sg * (W / 2 - 0.7),
					L,
					2.2,
					1.2,
					CONCRETO_ESC,
					"Concrete"
				)
			end
			local tt = -L / 2 + 10
			while tt < L / 2 - 5 do
				ctx.bloco(
					Props,
					q,
					"Travessa",
					tt,
					BASE_PONTE - 0.5,
					0,
					0.8,
					1.0,
					W - 2.8,
					CONCRETO_ESC,
					"Concrete",
					FINO
				)
				tt += 10
			end

			-- cabeceiras (encontros) sob o início e o fim do tabuleiro
			if L >= 30 then
				for _, e in { -1, 1 } do
					ctx.bloco(
						Props,
						q,
						"Encontro",
						e * (L / 2 - 9),
						(-6 + BASE_PONTE) / 2,
						0,
						5,
						BASE_PONTE + 6,
						W - 1,
						CONCRETO,
						"Concrete"
					)
				end
			end

			-- pilares no leito: ~1 a cada 40 st (Rio Grande, vão ≈ 110, ganha 2)
			local m = max(0, floor(L / 40 + 0.5) - 1)
			local nPilares = 0
			for k = 1, m do
				local t = -L / 2 + L * k / (m + 1)
				local feito = false
				for _, sg in { -1, 1 } do
					local s = sg * (W / 2 - 3.5)
					local wx, wz = mundoXZ(q, t, s)
					local base = leito(wx, wz) - 1
					local h = BASE_PONTE - base
					if h >= 1.5 then
						ctx.bloco(Props, q, "Pilar", t, (base + BASE_PONTE) / 2, s, 3.2, h, 3.2, CONCRETO, "Concrete")
						feito = true
						nPilares += 1
					end
				end
				if feito then
					ctx.bloco(Props, q, "Cabecote", t, BASE_PONTE - 0.9, 0, 4.2, 1.8, W - 1, CONCRETO_ESC, "Concrete")
				end
			end

			-- treliça metálica dos dois lados nas pontes grandes
			if L > 90 then
				local nv = max(2, floor(L / 12 + 0.5))
				local alt = 9.5
				for _, sg in { -1, 1 } do
					local s = sg * (W / 2 - 0.5)
					local ts = {}
					for i = 0, nv do
						ts[i] = -L / 2 + L * i / nv
						ctx.bloco(
							Props,
							q,
							"TrelicaMontante",
							ts[i],
							(1.7 + alt) / 2,
							s,
							0.7,
							alt - 1.7,
							0.7,
							ACO,
							"Metal"
						)
					end
					rampa(Props, q, "TrelicaBanzo", -L / 2, alt, s, L / 2, alt, s, 0.9, 0.8, ACO, "Metal")
					for i = 1, nv do
						local ya, yb = if i % 2 == 0 then 1.7 else alt, if i % 2 == 0 then alt else 1.7
						rampa(Props, q, "TrelicaDiagonal", ts[i - 1], ya, s, ts[i], yb, s, 0.5, 0.5, ACO, "Metal", {
							colide = false,
							consulta = false,
						})
					end
				end
				for i = 0, nv, 2 do
					ctx.bloco(
						Props,
						q,
						"TrelicaTravessa",
						-L / 2 + L * i / nv,
						alt,
						0,
						0.7,
						0.7,
						W - 1,
						ACO,
						"Metal",
						FINO
					)
				end
			end

			-- placas nas duas cabeceiras: texto do rio
			do
				local ex, ez = mundoXZ(q, -L / 2 - 6, W / 2 + 3)
				local ok1 = placa(q, -L / 2 - 6, W / 2 + 3, pi / 2, max(0.5, ctx.altura(ex, ez)), p.rio, "Ponte")
				local fx, fz = mundoXZ(q, L / 2 + 6, -(W / 2 + 3))
				local ok2 = placa(q, L / 2 + 6, -(W / 2 + 3), -pi / 2, max(0.5, ctx.altura(fx, fz)), p.rio, "Ponte")
				placasOk = placasOk and ok1 and ok2
			end

			table.insert(resumo.pontes, { nome = p.nome, a0 = a0, a1 = a1, pilares = nPilares })
		end
	end

	-- ------------------------------------------------------------------------------------------------------
	-- (b) PASSARELAS de pedestres
	-- ------------------------------------------------------------------------------------------------------
	for _, pp in Mundo.pontesPedestres do
		local rio = nil
		for _, r in plano.rios do
			if r.nome == pp.rio then
				rio = r
			end
		end
		assert(rio, pp.nome .. ": rio inexistente " .. tostring(pp.rio))
		local along = if pp.eixo == "x" then pp.centro[1] else pp.centro[2]
		local fixo = if pp.eixo == "x" then pp.centro[2] else pp.centro[1]
		local q = quadro(pp.eixo, along, fixo)
		local w = pp.largura
		local meioRio = rio.largura / 2 + rio.margem
		local Ld = meioRio + 2
		local function hg(t: number): number
			local x, z = mundoXZ(q, t, 0)
			return max(ctx.altura(x, z), 0.5)
		end
		local yd = max(hg(-Ld), hg(Ld)) + 1.0
		local ESPP = 0.6

		-- comprimento horizontal da rampa de 1:6 que desce de yd até o terreno
		local rampas = {}
		for _, sg in { -1, 1 } do
			local len = 6
			for _ = 1, 10 do
				len = 6 * max(1, yd - hg(sg * (Ld + len)))
			end
			rampas[sg] = len
		end

		local x0, x1, z0, z1 = retMundo(pp.eixo, along - Ld, along + Ld, -w / 2, w / 2, fixo)
		local deck =
			ctx.bloco(Ruas, q, "PassarelaTabuleiro", 0, yd - ESPP / 2, 0, 2 * Ld, ESPP, w, MADEIRA, "WoodPlanks")
		deck:SetAttribute("Passarela", pp.nome)
		for _, sg in { -1, 1 } do
			local len = rampas[sg]
			local yf = yd - len / 6
			local r =
				rampa(Ruas, q, "PassarelaRampa", sg * Ld, yd, 0, sg * (Ld + len), yf, 0, w, ESPP, MADEIRA, "WoodPlanks")
			r:SetAttribute("Passarela", pp.nome)
			-- corrimão em cada lado do trecho plano e das rampas
			for _, ss in { -1, 1 } do
				local s = ss * (w / 2 - 0.3)
				for _, par in { { sg * Ld, yd, sg * (Ld + len), yf } } do
					local t0, y0, t1, y1 = par[1], par[2], par[3], par[4]
					local nn = max(1, ceil(abs(t1 - t0) / 5))
					for i = 0, nn do
						local f = i / nn
						ctx.bloco(
							Props,
							q,
							"CorrimaoPoste",
							t0 + (t1 - t0) * f,
							y0 + (y1 - y0) * f + 1.6,
							s,
							0.4,
							3.2,
							0.4,
							ACO,
							"Metal",
							{ consulta = false }
						)
					end
					rampa(
						Props,
						q,
						"Corrimao",
						t0,
						y0 + 3.2,
						s,
						t1,
						y1 + 3.2,
						s,
						0.4,
						0.35,
						ACO,
						"Metal",
						{ consulta = false }
					)
					rampa(
						Props,
						q,
						"Corrimao",
						t0,
						y0 + 1.6,
						s,
						t1,
						y1 + 1.6,
						s,
						0.3,
						0.3,
						ACO,
						"Metal",
						{ colide = false, consulta = false }
					)
				end
			end
			-- escoras sob a rampa onde ela fica alta
			local nn = max(1, floor(len / 12))
			for i = 1, nn do
				local t = sg * (Ld + len * i / (nn + 1))
				local y = yd - abs(t) / 6 + Ld / 6 -- altura da rampa em t
				local g = hg(t)
				if y - ESPP - g > 1.2 then
					for _, ss in { -1, 1 } do
						ctx.bloco(
							Props,
							q,
							"Escora",
							t,
							(g + y - ESPP) / 2 - 0.3,
							ss * (w / 2 - 0.5),
							0.8,
							y - ESPP - g + 0.6,
							0.8,
							ACO,
							"Metal"
						)
					end
				end
			end
		end
		do -- corrimão do trecho plano
			for _, ss in { -1, 1 } do
				local s = ss * (w / 2 - 0.3)
				local nn = max(1, ceil(2 * Ld / 5))
				for i = 0, nn do
					ctx.bloco(
						Props,
						q,
						"CorrimaoPoste",
						-Ld + 2 * Ld * i / nn,
						yd + 1.6,
						s,
						0.4,
						3.2,
						0.4,
						ACO,
						"Metal",
						{ consulta = false }
					)
				end
				rampa(
					Props,
					q,
					"Corrimao",
					-Ld,
					yd + 3.2,
					s,
					Ld,
					yd + 3.2,
					s,
					0.4,
					0.35,
					ACO,
					"Metal",
					{ consulta = false }
				)
				rampa(Props, q, "Corrimao", -Ld, yd + 1.6, s, Ld, yd + 1.6, s, 0.3, 0.3, ACO, "Metal", {
					colide = false,
					consulta = false,
				})
			end
		end
		-- pilaretes no leito a cada ~22 st
		local nb = max(1, floor(2 * Ld / 22))
		for i = 1, nb do
			local t = -Ld + 2 * Ld * i / (nb + 1)
			for _, ss in { -1, 1 } do
				local s = ss * (w / 2 - 0.5)
				local wx, wz = mundoXZ(q, t, s)
				local base = leito(wx, wz) - 1
				local h = yd - ESPP - base
				if h >= 1.2 then
					ctx.bloco(Props, q, "Pilarete", t, base + h / 2, s, 0.9, h, 0.9, ACO, "Metal")
				end
			end
		end
		table.insert(resumo.passarelas, {
			nome = pp.nome,
			yd = yd,
			Ld = Ld,
			rampaA = rampas[-1],
			rampaB = rampas[1],
			rect = { x0, x1, z0, z1 },
		})
	end

	-- ------------------------------------------------------------------------------------------------------
	-- (c) VIADUTOS: deck elevado + rampas pisáveis (asfalto) + muros de arrimo + pilares. As rampas e o deck NÃO
	-- registram superfície (ctx.topoEm devolveria a altura do deck para quem está EMBAIXO, na estrada de baixo).
	-- ------------------------------------------------------------------------------------------------------
	for _, v in plano.viadutos do
		local sob = plano.estradaPorNome[v.sobre]
		local along = if v.eixo == "x" then v.centro[1] else v.centro[2]
		local q = quadro(v.eixo, along, v.fixo)
		local W, alt, R = v.largura, v.altura, v.rampa
		local md = (v.deck1 - v.deck0) / 2

		local deck =
			ctx.bloco(Ruas, q, "ViadutoDeck", 0, alt - ESP_VIADUTO / 2, 0, 2 * md, ESP_VIADUTO, W, ASFALTO, "Asphalt")
		deck:SetAttribute("Viaduto", v.nome)
		marcasPerfil(q, W, -md, alt, md, alt)
		for _, sg in { -1, 1 } do
			local r = rampa(
				Ruas,
				q,
				"ViadutoRampa",
				sg * md,
				alt,
				0,
				sg * (md + R),
				0.5,
				0,
				W,
				ESP_VIADUTO,
				ASFALTO,
				"Asphalt"
			)
			r:SetAttribute("Viaduto", v.nome)
			r:SetAttribute("Parte", "rampa")
			marcasPerfil(q, W, sg * md, alt, sg * (md + R), 0.5)

			-- muros de arrimo escalonados dos dois lados (fecham o aterro sob a rampa)
			local passo = 7
			local nn = ceil(R / passo)
			for i = 0, nn - 1 do
				local ta, tb = i * passo, min(R, (i + 1) * passo)
				local yb = alt - (alt - 0.5) * tb / R -- altura do topo da rampa no lado baixo do degrau
				local topo = yb - 0.05
				local fundo = -1.0
				if topo - fundo > 0.5 then
					for _, ss in { -1, 1 } do
						ctx.bloco(
							Props,
							q,
							"MuroArrimo",
							sg * (md + (ta + tb) / 2),
							(topo + fundo) / 2,
							ss * (W / 2 - 0.7),
							tb - ta,
							topo - fundo,
							1.4,
							CONCRETO,
							"Concrete"
						)
					end
				end
			end
			-- muro de fecho sob a ponta do deck
			ctx.bloco(
				Props,
				q,
				"MuroFecho",
				sg * (md - 0.7),
				(alt - ESP_VIADUTO - 1) / 2,
				0,
				1.4,
				alt - ESP_VIADUTO + 1,
				W - 2.8,
				CONCRETO,
				"Concrete"
			)
			-- guarda-corpo das rampas
			for _, ss in { -1, 1 } do
				parapeito(q, sg * md, alt, sg * (md + R), 0.5, ss * (W / 2 - 0.5))
			end
			-- pilares + cabeçote nas laterais da estrada de baixo
			local tp = sg * (sob.largura / 2 + 5)
			for _, s in { -W / 2 + 3, 0, W / 2 - 3 } do
				ctx.bloco(
					Props,
					q,
					"Pilar",
					tp,
					(alt - ESP_VIADUTO - 1) / 2,
					s,
					3,
					alt - ESP_VIADUTO + 1,
					3,
					CONCRETO,
					"Concrete"
				)
			end
			ctx.bloco(Props, q, "Cabecote", tp, alt - ESP_VIADUTO - 0.75, 0, 4.5, 1.5, W - 1, CONCRETO_ESC, "Concrete")
		end
		for _, ss in { -1, 1 } do
			parapeito(q, -md, alt, md, alt, ss * (W / 2 - 0.5))
		end
		table.insert(resumo.viadutos, v.nome)
	end

	if not placasOk then
		ctx.avisos = ctx.avisos or {}
		table.insert(
			ctx.avisos,
			"pontes: SurfaceGui/TextLabel não aceitos neste ambiente, placas das pontes ficaram sem texto"
		)
	end
	local nProps = 0
	for _, d in Props:GetDescendants() do
		if d:IsA("BasePart") then
			nProps += 1
		end
	end
	print(
		string.format(
			"  pontes: %d pontes, %d passarelas, %d viadutos (Props agora com %d peças)",
			#resumo.pontes,
			#resumo.passarelas,
			#resumo.viadutos,
			nProps
		)
	)
	local _ = rng
end

return M
