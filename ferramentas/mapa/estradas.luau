-- Estradas do mapa v2: asfalto de todas as plano.estradas (só nos trechos livres), faixas, bordas, acostamento,
-- remendos, rachaduras, poças, ruas de terra e entroncamentos. Pontes e viadutos ficam em pontes.luau. Contrato: docs/mapa-v2.md.
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local floor, ceil, min, max, abs, sqrt = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt

local M = {}

M.COR = {
	Asphalt = { 62, 62, 66 }, -- igual para todas as estradas de asfalto: onde os retângulos se sobrepõem não há z-fighting
	Pavement = { 112, 108, 100 },
	Ground = { 92, 76, 56 },
	amarela = { 150, 132, 62 },
	branca = { 150, 150, 146 },
	acostamento = { 104, 98, 86 },
	terraAcostamento = { 84, 70, 52 },
}

local ESP = 2 -- espessura das lajes de asfalto
local ACOST_TOPO = 0.44 -- logo abaixo do asfalto: o degrau de 0,06 não existe para o jogador
local PASSO = 2 -- amostragem das faixas contínuas
local CHUNK = 300

function M.gerar(ctx)
	local plano = ctx.plano
	local COR = M.COR
	local rng = ctx.rng("estradas")
	local Ruas = ctx.pastas.Ruas
	local ID = CFrame.new()
	local NIVEL = ctx.NIVEL_PAD
	local n = { asfalto = 0, acostamento = 0, faixas = 0, defeitos = 0, juncoes = 0 }

	local todos = {}
	for _, est in plano.estradas do
		for _, seg in est.segs do
			table.insert(todos, { seg = seg, est = est })
		end
	end
	local pads = { plano.cidade, plano.fabrica, plano.planicie, plano.guarda }
	for _, r in plano.vilas do
		table.insert(pads, r)
	end
	for _, r in plano.pois do
		table.insert(pads, r)
	end

	-- (x,z) está sobre o retângulo de OUTRO segmento (cruzamento, entroncamento, quina)
	local function emOutra(x: number, z: number, seg, m: number): boolean
		for _, e in todos do
			if e.seg ~= seg then
				local r = e.seg.ret
				if x >= r.x0 - m and x <= r.x1 + m and z >= r.z0 - m and z <= r.z1 + m then
					return true
				end
			end
		end
		return false
	end

	local function ponto(seg, u: number, s: number)
		if seg.eixo == "x" then
			return u, seg.fixo + s
		end
		return seg.fixo + s, u
	end

	-- Peça fina sobre o asfalto (marca, rachadura, remendo): sem colisão, sem consulta, sem sombra
	local function fino(seg, u0, u1, s, larg, yc, esp, cor, mat, nome, rotY)
		if u1 - u0 < 0.3 then
			return
		end
		local cx, cz, sx, sz
		if seg.eixo == "x" then
			cx, cz, sx, sz = (u0 + u1) / 2, seg.fixo + s, u1 - u0, larg
		else
			cx, cz, sx, sz = seg.fixo + s, (u0 + u1) / 2, larg, u1 - u0
		end
		ctx.bloco(Ruas, ID, nome, cx, yc, cz, sx, esp, sz, cor, mat, {
			colide = false,
			consulta = false,
			sombra = false,
			rotY = rotY,
		})
		n.faixas += 1
	end

	-- intervalos [a,b] de u0..u1 em que a linha lateral `s` não toca outra estrada
	local function corridas(seg, u0, u1, s, margem)
		local runs = {}
		local ini = nil
		local ultimo = u0
		local u = u0
		while u <= u1 + 0.001 do
			local x, z = ponto(seg, u, s)
			local livre = not emOutra(x, z, seg, margem)
			if livre then
				if not ini then
					ini = u
				end
				ultimo = u
			elseif ini then
				table.insert(runs, { ini, ultimo })
				ini = nil
			end
			u += PASSO
		end
		if ini then
			table.insert(runs, { ini, min(u1, ultimo + PASSO) })
		end
		return runs
	end

	local function solida(seg, u0, u1, s, larg, cor, yc, esp, mat)
		for _, r in corridas(seg, u0, u1, s, 0.5) do
			local a = r[1]
			while a < r[2] - 0.01 do
				local b = min(r[2], a + 1000)
				fino(seg, a, b, s, larg, yc or 0.56, esp or 0.1, cor, mat or "SmoothPlastic", "Faixa")
				a = b
			end
		end
	end

	local function tracejada(seg, u0, u1, s, larg, cor, dash, gap)
		local P = dash + gap
		local d = ceil((u0 + 1) / P) * P
		while d + dash <= u1 - 1 do
			local x1, z1 = ponto(seg, d, s)
			local x2, z2 = ponto(seg, d + dash / 2, s)
			local x3, z3 = ponto(seg, d + dash, s)
			if not (emOutra(x1, z1, seg, 1) or emOutra(x2, z2, seg, 1) or emOutra(x3, z3, seg, 1)) then
				fino(seg, d, d + dash, s, larg, 0.56, 0.1, cor, "SmoothPlastic", "Faixa")
			end
			d += P
		end
	end

	local function marcas(est, seg, u0, u1)
		local meia = seg.largura / 2
		if est.material == "Asphalt" then
			for _, sg in { -1, 1 } do
				solida(seg, u0 + 1, u1 - 1, sg * (meia - 1.4), 0.4, COR.branca)
			end
			if seg.largura >= 30 then
				for _, sg in { -1, 1 } do
					solida(seg, u0 + 1, u1 - 1, sg * 0.45, 0.3, COR.amarela)
					tracejada(seg, u0, u1, sg * meia / 2, 0.35, COR.branca, 9, 13)
				end
			else
				tracejada(seg, u0, u1, 0, 0.4, COR.amarela, 8, 12)
			end
		elseif est.material == "Ground" then
			for _, sg in { -1, 1 } do
				solida(seg, u0 + 1, u1 - 1, sg * meia * 0.32, 1.5, { 62, 50, 38 }, 0.53, 0.05, "Mud")
			end
		end
	end

	local function defeitos(est, seg, u0, u1)
		local len = u1 - u0
		local meia = seg.largura / 2
		local mat = est.material
		local matPeca = if mat == "Ground" then "Mud" else mat
		local escuro = if mat == "Asphalt"
			then { 44, 44, 47 }
			elseif mat == "Ground" then { 64, 52, 40 }
			else { 86, 82, 76 }
		local claro = if mat == "Asphalt"
			then { 80, 80, 84 }
			elseif mat == "Ground" then { 108, 90, 66 }
			else { 128, 124, 116 }
		local crack = if mat == "Ground" then { 70, 58, 44 } else { 30, 30, 33 }
		local function achar(margem)
			for _ = 1, 6 do
				local u = rng.entre(u0 + 5, u1 - 5)
				local s = rng.entre(-meia + 3, meia - 3)
				local x, z = ponto(seg, u, s)
				if not emOutra(x, z, seg, margem) then
					return u, s, x, z
				end
			end
			return nil
		end
		for _ = 1, floor(len / 70 + rng.rnd()) do -- remendos
			local u, s = achar(5)
			if u then
				local a, b = rng.entre(2.5, 7), rng.entre(2, 5)
				fino(
					seg,
					u - a / 2,
					u + a / 2,
					s,
					b,
					0.53,
					0.06,
					if rng.chance(0.6) then escuro else claro,
					matPeca,
					"Remendo"
				)
				n.defeitos += 1
			end
		end
		for _ = 1, floor(len / 40 + rng.rnd()) do -- rachaduras: 1–2 trechos tortos
			local u, s = achar(5)
			if u then
				local ang = rng.entre(-0.7, 0.7)
				local l1 = rng.entre(4, 10)
				fino(seg, u - l1 / 2, u + l1 / 2, s, 0.18, 0.54, 0.05, crack, matPeca, "Rachadura", ang)
				n.defeitos += 1
				if rng.chance(0.5) then
					local l2 = rng.entre(3, 7)
					local ang2 = ang + rng.entre(-1.0, 1.0)
					local dx, dz = math.cos(ang) * l1 / 2, math.sin(ang) * l1 / 2
					fino(
						seg,
						u + dx - l2 / 2,
						u + dx + l2 / 2,
						s - dz,
						0.15,
						0.54,
						0.05,
						crack,
						matPeca,
						"Rachadura",
						ang2
					)
					n.defeitos += 1
				end
			end
		end
		for _ = 1, floor(len / 150 + rng.rnd() * 0.7) do -- poças
			local u, s, x, z = achar(6)
			if u then
				local d = rng.entre(3, if mat == "Ground" then 10 else 7)
				ctx.cilindro(Ruas, ID, "Poca", x, 0.525, z, d, 0.05, { 38, 48, 56 }, "Glass", {
					colide = false,
					consulta = false,
					sombra = false,
					refletancia = 0.2,
					transparencia = 0.15,
				})
				n.defeitos += 1
			end
		end
	end

	-- subtrai da lista de intervalos os pads (laje de cidade/vila/pois...) que cobrem a largura inteira da estrada
	local function recortar(seg, a: number, b: number)
		local meia = seg.largura / 2
		local lista = { { a, b } }
		for _, r in pads do
			local cobre, p0, p1
			if seg.eixo == "x" then
				cobre = r.z0 <= seg.fixo - meia + 0.01 and r.z1 >= seg.fixo + meia - 0.01
				p0, p1 = r.x0, r.x1
			else
				cobre = r.x0 <= seg.fixo - meia + 0.01 and r.x1 >= seg.fixo + meia - 0.01
				p0, p1 = r.z0, r.z1
			end
			if cobre then
				local novo = {}
				for _, iv in lista do
					if p1 <= iv[1] or p0 >= iv[2] then
						table.insert(novo, iv)
					else
						if p0 > iv[1] + 0.01 then
							table.insert(novo, { iv[1], p0 })
						end
						if p1 < iv[2] - 0.01 then
							table.insert(novo, { p1, iv[2] })
						end
					end
				end
				lista = novo
			end
		end
		return lista
	end

	-- ---------------------------------------------------------------------------------------------------------
	-- asfalto, acostamento, faixas e defeitos por trecho livre
	-- ---------------------------------------------------------------------------------------------------------
	for _, est in plano.estradas do
		local material = est.material
		local cor = COR[material] or COR.Asphalt
		local acost = if est.avenida then 5 elseif est.largura >= 30 then 4 elseif material == "Ground" then 2.5 else 3
		local corAc = if material == "Ground" then COR.terraAcostamento else COR.acostamento
		local matAc = if material == "Ground" then "Ground" else "Pebble"
		for _, seg in est.segs do
			local meia = seg.largura / 2
			for _, tl in plano.trechosLivres(seg) do
				for _, iv in recortar(seg, tl[1], tl[2]) do
					local u0, u1 = iv[1], iv[2]
					if u1 - u0 > 0.5 then
						local a = u0
						while a < u1 - 0.01 do
							local b = min(u1, a + CHUNK)
							local x0, x1, z0, z1
							if seg.eixo == "x" then
								x0, x1, z0, z1 = a, b, seg.fixo - meia, seg.fixo + meia
							else
								x0, x1, z0, z1 = seg.fixo - meia, seg.fixo + meia, a, b
							end
							ctx.laje("Ruas", "Asfalto_" .. est.nome, x0, x1, z0, z1, NIVEL, ESP, cor, material)
							n.asfalto += 1
							for _, sg in { -1, 1 } do
								local ax0, ax1, az0, az1
								if seg.eixo == "x" then
									local lado0 = if sg < 0 then seg.fixo - meia - acost else seg.fixo + meia
									ax0, ax1, az0, az1 = a, b, lado0, lado0 + acost
								else
									local lado0 = if sg < 0 then seg.fixo - meia - acost else seg.fixo + meia
									ax0, ax1, az0, az1 = lado0, lado0 + acost, a, b
								end
								ctx.laje("Ruas", "Acostamento", ax0, ax1, az0, az1, ACOST_TOPO, 1, corAc, matAc)
								n.acostamento += 1
							end
							a = b
						end
						marcas(est, seg, u0, u1)
						defeitos(est, seg, u0, u1)
					end
				end
			end
		end
	end

	-- ---------------------------------------------------------------------------------------------------------
	-- Entroncamentos: (1) pontas de duas estradas que se encontram em L ganham o quadradinho que falta;
	-- (2) estrada que desemboca no meio de outra ganha linha de parada na meia pista da direita.
	-- ---------------------------------------------------------------------------------------------------------
	local pontas = {}
	for _, est in plano.estradas do
		local np = #est.pts
		table.insert(pontas, { est = est, p = est.pts[1], viz = est.pts[2], seg = est.segs[1], ini = true })
		table.insert(
			pontas,
			{ est = est, p = est.pts[np], viz = est.pts[np - 1], seg = est.segs[#est.segs], ini = false }
		)
	end
	local emL = {}
	for i = 1, #pontas do
		for j = i + 1, #pontas do
			local A, B = pontas[i], pontas[j]
			if A.est ~= B.est and abs(A.p[1] - B.p[1]) <= 1 and abs(A.p[2] - B.p[2]) <= 1 then
				emL[A] = true
				emL[B] = true
				-- A ao longo de X e B ao longo de Z (ou ao contrário)
				local ax = A.seg.eixo == "x"
				local bx = B.seg.eixo == "x"
				if ax ~= bx then
					local H, V = if ax then A else B, if ax then B else A -- H anda em X, V anda em Z
					local xp, zp = H.p[1], V.p[2]
					local dh = if H.viz[1] > xp then 1 else -1
					local dv = if V.viz[2] > zp then 1 else -1
					local hV, hH = V.est.largura / 2, H.est.largura / 2
					local x0, x1 = min(xp, xp - dh * hV), max(xp, xp - dh * hV)
					local z0, z1 = min(zp, zp - dv * hH), max(zp, zp - dv * hH)
					local mat = H.est.material
					ctx.laje("Ruas", "Entroncamento", x0, x1, z0, z1, NIVEL, ESP, COR[mat] or COR.Asphalt, mat)
					n.juncoes += 1
				end
			end
		end
	end
	for _, pt in pontas do
		if not emL[pt] and pt.est.material == "Asphalt" then
			local seg = pt.seg
			local meia = seg.largura / 2
			local uE = if seg.eixo == "x" then pt.p[1] else pt.p[2]
			local uF = if abs(seg.a0 - uE) < abs(seg.a1 - uE) then seg.a1 else seg.a0
			local dir = if uE > uF then 1 else -1
			local ent = nil
			local u = uF
			while (uE - u) * dir > 0 do
				local x, z = ponto(seg, u, 0)
				if emOutra(x, z, seg, 0) then
					ent = u
					break
				end
				u += dir
			end
			if ent and abs(uE - ent) <= 25 then
				local uStop = ent - dir * 2.4
				local sDir = if seg.eixo == "x" then dir else -dir
				local ancho = meia - 2.4
				fino(
					seg,
					uStop - 0.6,
					uStop + 0.6,
					sDir * (0.8 + ancho / 2),
					ancho,
					0.56,
					0.1,
					COR.branca,
					"SmoothPlastic",
					"LinhaParada"
				)
				n.juncoes += 1
			end
		end
	end

	ctx.estradasContagem = n
	print(
		string.format(
			"  estradas: %d lajes de asfalto, %d acostamentos, %d faixas/marcas, %d defeitos, %d entroncamentos",
			n.asfalto,
			n.acostamento,
			n.faixas,
			n.defeitos,
			n.juncoes
		)
	)
end

return M
