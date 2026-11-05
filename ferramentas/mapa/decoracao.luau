-- Decoracao: coloca props (props_urbanos) na cidade, nas estradas e nas vilas. Roda por ultimo. Contrato: docs/mapa-v2.md
-- secao 8 (D1). Grade de ocupacao propria (celula 2) + ctx.retanguloOcupado; nunca bloqueia uma rua inteira (corredor livre >= 8).
-- Dono: agente D1. Aleatoriedade so por ctx.rng("decoracao").

local Vector3 = require("@lune/roblox").Vector3
local Props = require("./props")

local floor, ceil, abs, max, min, sin, cos, pi, atan2, sqrt =
	math.floor, math.ceil, math.abs, math.max, math.min, math.sin, math.cos, math.pi, math.atan2, math.sqrt

local M = {}

local ORCAMENTO = { cidade = 6600, estrada = 3600, vila = 1300 } -- pecas de Props por categoria (total ~11 500)
local CEL = 2
local NOMES_X = { "Rua Cedar", "Rua Birch", "Rua Larch", "Rua Elm", "Rua Aspen", "Rua Rowan", "Rua Willow" }
local NOMES_Z = { "Av. Maple", "Rua 2", "Rua 3", "Av. Rise", "Rua 5", "Rua 6", "Rua 7" }

local function mira(fx, fz) -- rotY para a frente (-Z local) apontar na direcao (fx, fz)
	return atan2(-fx, -fz)
end

function M.gerar(ctx)
	local Mundo, plano = ctx.Mundo, ctx.plano
	local rng = ctx.rng("decoracao")
	local pasta = ctx.pastas.Props
	local limite = Mundo.tamanho / 2 - 40

	-- ------------------------------------------------------------------------------------------------------------
	-- grade de ocupacao
	-- ------------------------------------------------------------------------------------------------------------
	local grade = {}
	local function chave(i, j)
		return (i + 4096) * 8192 + (j + 4096)
	end
	local function marcar(x0, x1, z0, z1)
		for i = floor(x0 / CEL), floor((x1 - 0.001) / CEL) do
			for j = floor(z0 / CEL), floor((z1 - 0.001) / CEL) do
				grade[chave(i, j)] = true
			end
		end
	end
	local function livre(x0, x1, z0, z1)
		for i = floor(x0 / CEL), floor((x1 - 0.001) / CEL) do
			for j = floor(z0 / CEL), floor((z1 - 0.001) / CEL) do
				if grade[chave(i, j)] then
					return false
				end
			end
		end
		return true
	end
	local function marcarParte(p, folga)
		local c, s = p.CFrame, p.Size
		local r, u, l = c.RightVector, c.UpVector, c.LookVector
		local ex = (abs(r.X) * s.X + abs(u.X) * s.Y + abs(l.X) * s.Z) / 2 + folga
		local ez = (abs(r.Z) * s.X + abs(u.Z) * s.Y + abs(l.Z) * s.Z) / 2 + folga
		marcar(c.Position.X - ex, c.Position.X + ex, c.Position.Z - ez, c.Position.Z + ez)
	end

	-- bandas de rua (corredor livre): eixo "z" = rua que corre ao longo de Z em x = centro
	local bandas = {}
	local function banda(eixo, centro, meia, a0, a1)
		table.insert(bandas, { eixo = eixo, centro = centro, meia = meia, a0 = a0, a1 = a1 })
	end

	local C = Mundo.cidade
	local passo = C.quarteirao + C.rua
	local nq = floor(C.lado / passo + 0.5)
	local meiaC = C.lado / 2
	local meiaVia = plano.meiaVia
	local cr = {}
	for k = 0, nq do
		cr[k] = -meiaC + passo * k
		banda("z", cr[k], C.rua / 2, -meiaVia, meiaVia)
		banda("x", cr[k], C.rua / 2, -meiaVia, meiaVia)
	end
	for _, est in plano.estradas do
		for _, seg in est.segs do
			banda(seg.eixo, seg.fixo, seg.largura / 2, seg.a0, seg.a1)
		end
	end
	for _, v in plano.vilas do
		local cx, cz = (v.x0 + v.x1) / 2, (v.z0 + v.z1) / 2
		banda("z", cx, 12, v.z0, v.z1)
		banda("x", cz, 12, v.x0, v.x1)
	end

	-- exige uma faixa livre >= 8 (4 celulas) em cada linha de cada rua que o retangulo cruza
	local function corredorOk(x0, x1, z0, z1)
		for _, b in bandas do
			local la0, la1, al0, al1 = x0, x1, z0, z1
			if b.eixo == "x" then
				la0, la1, al0, al1 = z0, z1, x0, x1
			end
			if la1 > b.centro - b.meia and la0 < b.centro + b.meia and al1 > b.a0 and al0 < b.a1 then
				local r0, r1 = floor(max(al0, b.a0) / CEL), floor((min(al1, b.a1) - 0.001) / CEL)
				local l0, l1 = floor((b.centro - b.meia) / CEL), ceil((b.centro + b.meia) / CEL) - 1
				local c0, c1 = floor(la0 / CEL), floor((la1 - 0.001) / CEL)
				for r = r0, r1 do
					local run, melhor = 0, 0
					for l = l0, l1 do
						local bloq = (l >= c0 and l <= c1)
							or (if b.eixo == "z" then grade[chave(l, r)] else grade[chave(r, l)])
						if bloq then
							run = 0
						else
							run += 1
							if run > melhor then
								melhor = run
							end
						end
					end
					if melhor < 4 then
						return false
					end
				end
			end
		end
		return true
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- pre-marcas: construcoes, props ja existentes, spawns, pontes, viadutos
	-- ------------------------------------------------------------------------------------------------------------
	for _, m in ctx.pastas.Construcoes:GetChildren() do
		local pg = m:FindFirstChild("Pegada")
		if pg and pg:IsA("BasePart") then
			marcarParte(pg, 0.6)
		end
	end
	for _, d in pasta:GetDescendants() do
		if d:IsA("BasePart") then
			marcarParte(d, 0.3)
		end
	end
	for _, s in ctx.spawnsPlanejados or {} do
		marcar(s.x - 10, s.x + 10, s.z - 10, s.z + 10)
	end
	for _, p in plano.pontes do
		local lat = p.largura / 2 + 8
		if p.eixo == "x" then
			marcar(p.a0 - 2, p.a1 + 2, p.fixo - lat, p.fixo + lat)
		else
			marcar(p.fixo - lat, p.fixo + lat, p.a0 - 2, p.a1 + 2)
		end
	end
	for _, v in plano.viadutos do
		local lat = v.largura / 2 + 8
		if v.eixo == "x" then
			marcar(v.a0 - 2, v.a1 + 2, v.fixo - lat, v.fixo + lat)
		else
			marcar(v.fixo - lat, v.fixo + lat, v.a0 - 2, v.a1 + 2)
		end
	end

	-- as estradas/ruas ou calcadas estao registradas como obstaculo? entao so a grade vale
	local usaObs = true
	for _, p in { { 0, 0 }, { 132, 75 }, { 75, 132 }, { -132, -75 }, { 600, 1100 } } do
		if ctx.ocupado(p[1], p[2], 0) then
			usaObs = false
		end
	end
	if not usaObs then
		for _, d in ctx.pastas.Vegetacao:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				marcarParte(d, 1)
			end
		end
	end

	-- areas "planas" (onde nao ha decoracao de estrada)
	local areas = { plano.cidade, plano.fabrica, plano.planicie, plano.guarda }
	for _, v in plano.vilas do
		table.insert(areas, v)
	end
	for _, p in plano.pois do
		table.insert(areas, p)
	end
	local function emArea(x, z, margem)
		for _, a in areas do
			if plano.dentro(a, x, z, margem) then
				return true
			end
		end
		return false
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- colocar
	-- ------------------------------------------------------------------------------------------------------------
	local cat = "cidade"
	local limiteAtual = ORCAMENTO.cidade
	local gasto = { cidade = 0, estrada = 0, vila = 0 }
	local contagem = {}
	local totalPecas = 0

	-- devolve a caixa (x0,x1,z0,z1) se der para colocar
	local function avaliar(nome, x, z, rot, op, o)
		local t = Props.tam[nome]
		local w = (t.var and op and op.w) or t.w
		local gw, gd = o.gw or w, o.gd or t.d
		local c, s = abs(cos(rot)), abs(sin(rot))
		local ex, ez = (gw * c + gd * s) / 2, (gw * s + gd * c) / 2
		local x0, x1, z0, z1 = x - ex, x + ex, z - ez, z + ez
		if abs(x) > limite or abs(z) > limite then
			return nil
		end
		if gasto[cat] >= limiteAtual then
			return nil
		end
		if not o.ignorarGrade and not livre(x0, x1, z0, z1) then
			return nil
		end
		if usaObs and not o.via and not o.ignorarGrade and ctx.retanguloOcupado(x0, x1, z0, z1, o.margem or 0) then
			return nil
		end
		if plano.folgaRio(x, z) < 6 then
			return nil
		end
		if o.via and not corredorOk(x0, x1, z0, z1) then
			return nil
		end
		return x0, x1, z0, z1
	end

	local function colocar(nome, x, z, rot, op, o)
		o = o or {}
		op = op or {}
		op.rng = rng
		local x0, x1, z0, z1 = avaliar(nome, x, z, rot, op, o)
		if not x0 then
			return nil
		end
		local m = Props.colocar(ctx, pasta, nome, x, z, rot, op)
		marcar(x0, x1, z0, z1)
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		gasto[cat] += n
		totalPecas += n
		contagem[nome] = (contagem[nome] or 0) + 1
		return m
	end

	local function regiaoDe(x, z)
		local d = max(abs(x), abs(z))
		if d <= C.regioes.centro then
			return "centro"
		elseif d <= C.regioes.comercial then
			return "comercial"
		end
		return "residencial"
	end

	-- veiculo sorteado por regiao: devolve nome, op
	local function veiculo(reg)
		local r = rng.rnd()
		local nome, v = "carro", rng.inteiro(1, 4)
		if reg == "centro" then
			if r < 0.35 then
				v = 5
			elseif r < 0.55 then
				v = 4
			elseif r < 0.7 then
				nome = "onibus"
			elseif r < 0.8 then
				nome = "caminhao"
			end
		elseif reg == "comercial" then
			if r < 0.2 then
				v = 5
			elseif r < 0.32 then
				v = 4
			elseif r < 0.38 then
				nome = "onibus"
			elseif r < 0.46 then
				nome = "caminhao"
			elseif r < 0.58 then
				v = 3
			end
		else
			if r < 0.06 then
				v = 5
			elseif r < 0.2 then
				v = 3
			elseif r < 0.26 then
				v = 4
			elseif r < 0.29 then
				nome = "caminhao"
			end
		end
		if nome == "carro" then
			return nome, { variante = v }
		end
		return nome, {}
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- 1. cidade
	-- ------------------------------------------------------------------------------------------------------------
	cat = "cidade"
	limiteAtual = 3000
	local metaQ = C.quarteirao / 2
	local normais = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
	local postesMeio = {} -- { x, z, nx, nz } para carros batidos em poste

	-- cruzamentos: semaforo nos quatro cantos dos principais; placa de rua; barricadas
	for i = 0, nq - 1 do
		for j = 0, nq - 1 do
			local bx, bz = -meiaC + passo / 2 + passo * i, -meiaC + passo / 2 + passo * j
			local reg = regiaoDe(bx, bz)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local kx, kz = i + (sx + 1) / 2, j + (sz + 1) / 2
					local px, pz = bx + sx * 57.5, bz + sz * 57.5
					local rot = mira(sx, sz)
					if kx >= 2 and kx <= 4 and kz >= 2 and kz <= 4 then
						colocar("semaforo", px, pz, rot, nil, { gw = 3, gd = 3 })
					else
						colocar("poste_luz", px, pz, rot, nil, { gw = 3, gd = 3 })
					end
				end
			end
			-- placa de rua no canto (+,+) do quarteirao (uma por cruzamento interior)
			if i + 1 <= nq - 1 and j + 1 <= nq - 1 then
				local txt = NOMES_X[i + 2] .. " / " .. NOMES_Z[j + 2]
				colocar("placa_rua", bx + 50, bz + 58.5, mira(0, 1), { texto = txt }, { gw = 5, gd = 1 })
			end

			-- bordas do quarteirao
			for e = 1, 4 do
				local nx, nz = normais[e][1], normais[e][2]
				local tx, tz = -nz, nx
				local rot = mira(nx, nz)
				local function pos(t, d)
					return bx + nx * d + tx * t, bz + nz * d + tz * t
				end
				for _, t in { -25, 25 } do
					local x, z = pos(t, 58.3)
					if colocar("poste_luz", x, z, rot, nil, { gw = 1.6, gd = 4 }) then
						table.insert(postesMeio, { x = x, z = z, nx = nx, nz = nz, reg = reg })
					end
				end
			end
		end
	end

	-- carros nas ruas
	limiteAtual = 5300
	local function carroNaRua(eixo, fixo, a, reg)
		local nome, op = veiculo(reg)
		local modo = rng.rnd()
		local lat, rotAlong
		local alongRot = if eixo == "z" then 0 else pi / 2
		if rng.chance(0.5) then
			alongRot += pi
		end
		if modo < 0.55 then -- estacionado junto ao meio-fio
			lat = rng.sinal() * (if nome == "carro" then 10.6 else 9.5)
			rotAlong = alongRot + rng.entre(-0.06, 0.06)
		elseif modo < 0.85 then -- abandonado na pista, meio torto
			lat = rng.sinal() * rng.entre(2.5, 6.5)
			rotAlong = alongRot + rng.entre(-0.35, 0.35)
		else -- atravessado
			lat = rng.entre(-4, 4)
			rotAlong = alongRot + pi / 2 + rng.entre(-0.25, 0.25)
		end
		local x, z = a, fixo + lat
		if eixo == "z" then
			x, z = fixo + lat, a
		end
		if rng.chance(0.1) and nome == "carro" then
			return colocar("carro_destruido", x, z, rotAlong, { variante = rng.inteiro(1, 3) }, { via = true })
		end
		return colocar(nome, x, z, rotAlong, op, { via = true })
	end

	for k = 0, nq do
		for m = 0, nq - 1 do
			local a0, a1 = cr[m] + 24, cr[m + 1] - 24
			for _, eixo in { "z", "x" } do
				local mid = (a0 + a1) / 2
				local mx, mz = if eixo == "z" then cr[k] else mid, if eixo == "z" then mid else cr[k]
				local reg = regiaoDe(mx, mz)
				local n = if reg == "centro"
					then rng.inteiro(0, 2)
					elseif reg == "comercial" then rng.inteiro(1, 3)
					else rng.inteiro(1, 4)
				for _ = 1, n do
					for _ = 1, 4 do
						if carroNaRua(eixo, cr[k], rng.entre(a0, a1), reg) then
							break
						end
					end
				end
			end
		end
	end
	-- carros batidos em postes
	for _, p in postesMeio do
		if rng.chance(0.1) then
			local cx, cz = p.x + p.nx * 6.6, p.z + p.nz * 6.6
			colocar(
				"carro",
				cx,
				cz,
				mira(-p.nx, -p.nz) + rng.entre(-0.15, 0.15),
				{ variante = rng.inteiro(1, 4) },
				{ via = true }
			)
		end
	end
	-- cruzamentos: carro no centro, barricadas
	local interiores = {}
	for kx = 1, nq - 1 do
		for kz = 1, nq - 1 do
			table.insert(interiores, { kx, kz })
		end
	end
	for _, c in interiores do
		local x, z = cr[c[1]], cr[c[2]]
		if rng.chance(0.18) then
			colocar(
				if rng.chance(0.3) then "carro_destruido" else "carro",
				x + rng.entre(-4, 4),
				z + rng.entre(-4, 4),
				rng.entre(0, 2 * pi),
				{ variante = rng.inteiro(1, 3) },
				{ via = true }
			)
		end
	end
	for _ = 1, 9 do
		local c = interiores[rng.inteiro(1, #interiores)]
		local x, z = cr[c[1]], cr[c[2]]
		local dir = normais[rng.inteiro(1, 4)]
		local tx, tz = -dir[2], dir[1]
		local rotB = mira(dir[1], dir[2]) + pi / 2
		for _, lat in { -12, -4 } do
			colocar(
				"barreira_concreto",
				x + dir[1] * 28 + tx * lat,
				z + dir[2] * 28 + tz * lat,
				rotB,
				nil,
				{ via = true }
			)
		end
		for q = 0, 4 do
			colocar(
				"cone",
				x + dir[1] * (24 - q * 1.5) + tx * (2 + q * 1.8),
				z + dir[2] * (24 - q * 1.5) + tz * (2 + q * 1.8),
				0,
				nil,
				{ via = true }
			)
		end
		colocar(
			"placa_aviso",
			x + dir[1] * 34 + tx * 17,
			z + dir[2] * 34 + tz * 17,
			mira(dir[1], dir[2]),
			{ variante = 3 }
		)
	end

	-- extras de calcada e terrenos (apos os carros, com o resto do orcamento)
	limiteAtual = ORCAMENTO.cidade
	for i = 0, nq - 1 do
		for j = 0, nq - 1 do
			local bx, bz = -meiaC + passo / 2 + passo * i, -meiaC + passo / 2 + passo * j
			local reg = regiaoDe(bx, bz)
			for e = 1, 4 do
				local nx, nz = normais[e][1], normais[e][2]
				local tx, tz = -nz, nx
				local rot = mira(nx, nz)
				local function pos(t, d)
					return bx + nx * d + tx * t, bz + nz * d + tz * t
				end
				local pH = if reg == "centro" then 0.3 elseif reg == "comercial" then 0.5 else 0.55
				if rng.chance(pH) then
					local x, z = pos(rng.sinal() * rng.entre(34, 42), 59)
					colocar("hidrante", x, z, rot)
				end
				if rng.chance(0.55) then
					local x, z = pos(rng.sinal() * rng.entre(8, 20), 59)
					colocar("lixeira_rua", x, z, rot)
				end
				local pB = if reg == "centro" then 0.15 elseif reg == "comercial" then 0.35 else 0.3
				if rng.chance(pB) then
					local x, z = pos(rng.sinal() * rng.entre(8, 18), 56.3)
					colocar("banco_praca", x, z, rot, nil, { gd = 2 })
				end
				if reg ~= "centro" and rng.chance(0.08) then
					local x, z = pos(rng.sinal() * 35, 57.2)
					colocar("ponto_onibus", x, z, rot)
				end
				if reg ~= "residencial" and rng.chance(0.07) then
					local x, z = pos(rng.sinal() * 35, 57.2)
					colocar("banca_jornal", x, z, rot)
				end
				if reg ~= "centro" then
					local pT = if reg == "residencial" then 0.8 else 0.45
					for _, t in { -45, -12, 12, 45 } do
						if rng.chance(pT) then
							local x, z = pos(t, 57.5)
							local canteiro = rng.chance(0.3) and colocar("canteiro", x, z, rot, nil, { gd = 4 })
							colocar(
								"arvore_rua",
								x,
								z,
								rng.entre(0, pi),
								nil,
								{ gw = 2, gd = 2, ignorarGrade = canteiro ~= nil and canteiro ~= false }
							)
						end
					end
				end
			end
			-- terrenos: cacamba e entulho em vazios do quarteirao
			local pC = if reg == "centro" then 0.1 elseif reg == "comercial" then 0.3 else 0.35
			if rng.chance(pC) then
				for _ = 1, 8 do
					local x, z = bx + rng.entre(-48, 48), bz + rng.entre(-48, 48)
					if colocar("cacamba", x, z, if rng.chance(0.5) then 0 else pi / 2, nil, { margem = 3 }) then
						break
					end
				end
			end
			if reg ~= "centro" and rng.chance(0.3) then
				for _ = 1, 8 do
					local x, z = bx + rng.entre(-48, 48), bz + rng.entre(-48, 48)
					if colocar("entulho", x, z, rng.entre(0, pi), nil, { margem = 3 }) then
						break
					end
				end
			end
			if reg == "residencial" and rng.chance(0.25) then
				for _ = 1, 8 do
					local x, z = bx + rng.entre(-48, 48), bz + rng.entre(-48, 48)
					if colocar("arbusto", x, z, 0, nil, { margem = 2 }) then
						break
					end
				end
			end
		end
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- 2. vilas
	-- ------------------------------------------------------------------------------------------------------------
	cat = "vila"
	limiteAtual = ORCAMENTO.vila
	for _, v in plano.vilas do
		local cx, cz = (v.x0 + v.x1) / 2, (v.z0 + v.z1) / 2
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				colocar("poste_luz", cx + sx * 17, cz + sz * 17, mira(-sx, -sz), nil, { gw = 3, gd = 3 })
			end
		end
		for _, dir in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
			local tx, tz = -dir[2], dir[1]
			for q = 1, 3 do
				local d = 30 + q * 38
				local lado = if q % 2 == 0 then 1 else -1
				colocar(
					"poste_luz",
					cx + dir[1] * d + tx * lado * 16,
					cz + dir[2] * d + tz * lado * 16,
					mira(-tx * lado, -tz * lado),
					nil,
					{ gw = 1.6, gd = 4 }
				)
			end
			-- carros nas entradas
			for _ = 1, rng.inteiro(1, 2) do
				local d = rng.entre(100, 138)
				local along = rng.entre(-5, 5)
				local rot = (if dir[1] ~= 0 then pi / 2 else 0)
					+ (if rng.chance(0.5) then pi else 0)
					+ rng.entre(-0.3, 0.3)
				local nome, op = veiculo("residencial")
				colocar(nome, cx + dir[1] * d + tx * along, cz + dir[2] * d + tz * along, rot, op, { via = true })
			end
		end
		colocar("banco_praca", cx + 22, cz + 17, mira(-1, 0), nil, { gd = 2 })
		colocar("banco_praca", cx - 22, cz - 17, mira(1, 0), nil, { gd = 2 })
		colocar("hidrante", cx + 17, cz - 22, 0)
		colocar("lixeira_rua", cx - 17, cz + 22, 0)
		colocar("lixeira_rua", cx + 19, cz + 18, 0)
		colocar("caixa_energia", cx - 24, cz + 18, 0)
		colocar("placa_pare", cx + 15, cz - 15, mira(-1, 1))
		colocar("placa_pare", cx - 15, cz + 15, mira(1, -1))

		-- casas: caixa de correio e cerca na frente
		for _, m in ctx.pastas.Construcoes:GetChildren() do
			local tipo = m:GetAttribute("Tipo")
			local pg = m:FindFirstChild("Pegada")
			if
				pg
				and (tipo == "casa" or tipo == "cabana")
				and plano.dentro(v, pg.CFrame.Position.X, pg.CFrame.Position.Z, 0)
			then
				local pcf, ps = pg.CFrame, pg.Size
				local look = pcf.LookVector
				local rot = mira(look.X, look.Z)
				local function mundo(lx, lz)
					local p = pcf:PointToWorldSpace(Vector3.new(lx, 0, lz))
					return p.X, p.Z
				end
				local fz = -(ps.Z / 2 + 3)
				if rng.chance(0.7) then
					local x, z = mundo(ps.X / 2 - 2, fz - 1)
					colocar("caixa_correio", x, z, rot)
				end
				if rng.chance(0.5) then
					local wseg = min(16, ps.X / 2 - 3)
					if wseg >= 4 then
						for _, lado in { -1, 1 } do
							local x, z = mundo(lado * (3 + wseg / 2), fz - 1)
							colocar("cerca_madeira", x, z, rot, { w = wseg })
						end
					end
				end
			end
		end
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- 3. estradas
	-- ------------------------------------------------------------------------------------------------------------
	cat = "estrada"
	local function xz(eixo, fixo, a, lat)
		if eixo == "x" then
			return a, fixo + lat
		end
		return fixo + lat, a
	end
	local function rotAo(eixo)
		return if eixo == "z" then 0 else pi / 2
	end
	-- direcao "na frente" (para onde aponta -Z) para um sinal que encara o transito que anda no sentido d (+1/-1)
	local function rotSinal(eixo, d)
		if eixo == "z" then
			return if d > 0 then 0 else pi
		end
		return if d > 0 then pi / 2 else -pi / 2
	end

	local destinos = {}
	for _, v in plano.vilas do
		table.insert(destinos, { nome = v.nome, x = (v.x0 + v.x1) / 2, z = (v.z0 + v.z1) / 2 })
	end
	table.insert(destinos, {
		nome = "Fabrica",
		x = (plano.fabrica.x0 + plano.fabrica.x1) / 2,
		z = (plano.fabrica.z0 + plano.fabrica.z1) / 2,
	})
	table.insert(destinos, {
		nome = "Posto da Guarda",
		x = (plano.guarda.x0 + plano.guarda.x1) / 2,
		z = (plano.guarda.z0 + plano.guarda.z1) / 2,
	})
	table.insert(destinos, { nome = "Cidade", x = 0, z = 0 })
	for _, p in plano.pois do
		table.insert(destinos, { nome = p.nome, x = p.centro[1], z = p.centro[2] })
	end
	local function destinoMaisProximo(x, z)
		local melhor, md = nil, math.huge
		for _, d in destinos do
			local dd = sqrt((d.x - x) ^ 2 + (d.z - z) ^ 2)
			if dd < md then
				melhor, md = d, dd
			end
		end
		return melhor, md
	end

	local compTotal = 0
	for _, e in plano.estradas do
		for _, s in e.segs do
			compTotal += s.a1 - s.a0
		end
	end
	for _, est in plano.estradas do
		local compEst = 0
		for _, s in est.segs do
			compEst += s.a1 - s.a0
		end
		limiteAtual = gasto.estrada + (ORCAMENTO.estrada - 500) * compEst / compTotal
		local rodovia = est.nome:find("Rodovia") ~= nil
		local avenida = est.avenida == true
		local taxaCarro = if rodovia then 220 elseif avenida then 260 else 340
		local ladoPoste = rng.sinal()
		for _, seg in est.segs do
			local meia = seg.largura / 2
			local eixo, fixo = seg.eixo, seg.fixo
			for _, run in plano.trechosLivres(seg) do
				local r0, r1 = run[1], run[2]
				local comp = r1 - r0
				if comp < 40 then
					continue
				end
				local function livreArea(a, lat)
					local x, z = xz(eixo, fixo, a, lat)
					return not emArea(x, z, 3)
				end
				-- postes
				if avenida then
					local n = floor((comp - 40) / 90)
					for q = 0, n do
						local a = r0 + 20 + q * 90
						local lado = if q % 2 == 0 then 1 else -1
						local lat = lado * (meia + 5)
						if livreArea(a, lat) then
							local x, z = xz(eixo, fixo, a, lat)
							local fx, fz = 0, 0
							if eixo == "z" then
								fx = -lado
							else
								fz = -lado
							end
							colocar("poste_luz_rodovia", x, z, mira(fx, fz), nil, { gw = 2, gd = 8 })
						end
					end
				else
					local lat = ladoPoste * (meia + 6)
					local lista = {}
					local n = floor((comp - 40) / 70)
					for q = 0, n do
						local a = r0 + 20 + q * 70
						if livreArea(a, lat) then
							local x, z = xz(eixo, fixo, a, lat)
							if avaliar("poste_madeira", x, z, rotAo(eixo) + pi / 2, {}, { gw = 1, gd = 1 }) then
								table.insert(lista, { a = a, x = x, z = z })
							end
						end
					end
					for q, p in lista do
						local prox = lista[q + 1]
						local op = {}
						if prox and prox.a - p.a < 110 then
							op.alvo = { prox.x, prox.z }
						end
						colocar("poste_madeira", p.x, p.z, rotAo(eixo) + pi / 2, op, { gw = 1, gd = 1 })
					end
				end
				-- placas de velocidade (ambos os lados), marcos, avisos
				local a = r0 + 60
				local q = 0
				while a < r1 - 40 do
					if livreArea(a, meia + 4) and livreArea(a, -(meia + 4)) then
						local v = rng.inteiro(1, 3)
						local x, z = xz(eixo, fixo, a, meia + 4)
						colocar("placa_velocidade", x, z, rotSinal(eixo, 1), { variante = v })
						x, z = xz(eixo, fixo, a + 6, -(meia + 4))
						colocar("placa_velocidade", x, z, rotSinal(eixo, -1), { variante = v })
					end
					a += rng.entre(300, 420)
					q += 1
				end
				a = r0 + 100
				while a < r1 - 30 do
					if (rodovia or avenida) and livreArea(a, meia + 3) then
						local x, z = xz(eixo, fixo, a, meia + 3)
						colocar(
							"lapide",
							x,
							z,
							rotAo(eixo) + pi / 2,
							{ variante = 3, cor = { 150, 150, 142 } },
							{ gw = 2, gd = 1 }
						)
					end
					a += 200
				end
				for _ = 1, floor(comp / 500 + rng.rnd()) do
					local aa = rng.entre(r0 + 30, r1 - 30)
					local lado = rng.sinal()
					if livreArea(aa, lado * (meia + 4)) then
						local x, z = xz(eixo, fixo, aa, lado * (meia + 4))
						colocar("placa_aviso", x, z, rotSinal(eixo, lado), { variante = rng.inteiro(1, 4) })
					end
				end
				-- placas de direcao nas pontas livres desta corrida
				for _, ponta in { { r0 + 70, 1 }, { r1 - 70, -1 } } do
					if comp > 220 and not avenida and livreArea(ponta[1], meia + 8) then
						local x, z = xz(eixo, fixo, ponta[1], meia + 8)
						-- destino do lado oposto da corrida
						local ox, oz = xz(eixo, fixo, if ponta[2] == 1 then r1 else r0, 0)
						local d, dist = destinoMaisProximo(ox, oz)
						local txt = string.format("%s  %d m", d.nome, floor(dist / 3 / 50 + 0.5) * 50)
						colocar(
							"placa_direcao",
							x,
							z,
							rotSinal(eixo, ponta[2]),
							{ texto = txt, w = 12 },
							{ via = false }
						)
					end
				end
				-- carros e caminhoes abandonados no acostamento
				for _ = 1, floor(comp / taxaCarro + rng.rnd()) do
					local aa = rng.entre(r0 + 20, r1 - 20)
					local lado = rng.sinal()
					local modo = rng.rnd()
					local lat, nome, op = lado * (meia + 5), "carro", { variante = rng.inteiro(1, 5) }
					local rot = rotAo(eixo) + (if rng.chance(0.5) then pi else 0) + rng.entre(-0.3, 0.3)
					if modo < 0.2 then
						nome, op = "caminhao", {}
					elseif modo < 0.3 then
						nome, op = "onibus", {}
					elseif modo < 0.38 and not avenida then
						nome, op = "trailer", {}
						rot += rng.sinal() * 0.4
					elseif modo < 0.6 then
						nome, op = "carro", { variante = 3 }
						lat = lado * (meia + 10)
						rot = rotAo(eixo) + lado * 0.6 + (if rng.chance(0.5) then pi else 0)
					elseif modo < 0.72 then
						nome, op = "carro_destruido", { variante = rng.inteiro(1, 3) }
					end
					if livreArea(aa, lat) then
						local x, z = xz(eixo, fixo, aa, lat)
						colocar(nome, x, z, rot, op, { via = true })
					end
				end
				-- obras na pista
				if not avenida and comp > 200 and rng.chance(0.12) then
					local aa = rng.entre(r0 + 60, r1 - 60)
					local lado = rng.sinal()
					for q2 = 0, 4 do
						local x, z = xz(eixo, fixo, aa - 4 - q2 * 5, lado * (meia - 1.5 - q2 * 0.9))
						if livreArea(aa, 0) then
							colocar("cone", x, z, 0, nil, { via = true })
						end
					end
					for q2 = 0, 1 do
						local x, z = xz(eixo, fixo, aa + q2 * 9, lado * (meia - 6))
						if livreArea(aa, 0) then
							colocar("barreira_concreto", x, z, rotAo(eixo), nil, { via = true })
						end
					end
					local x, z = xz(eixo, fixo, aa - 30, lado * (meia + 4))
					colocar("placa_aviso", x, z, rotSinal(eixo, 1), { variante = 3 })
				end
				-- containers e caixas de correio fora da pista
				if comp > 150 and rng.chance(0.08) then
					local aa = rng.entre(r0 + 40, r1 - 40)
					local lado = rng.sinal()
					if livreArea(aa, lado * (meia + 16)) then
						local x, z = xz(eixo, fixo, aa, lado * (meia + 16))
						colocar("container_carga", x, z, rotAo(eixo) + pi / 2, nil, { via = true })
					end
				end
				-- cerca de arame ao longo de pasto (perto da planicie)
				local pl = plano.planicie
				local ex = {
					x0 = pl.x0 - 160,
					x1 = pl.x1 + 160,
					z0 = pl.z0 - 160,
					z1 = pl.z1 + 160,
				}
				local aa = r0 + 12
				while aa < r1 - 12 do
					local x, z = xz(eixo, fixo, aa + 12, 0)
					if plano.dentro(ex, x, z, 0) then
						for _, lado in { -1, 1 } do
							local fx, fz = xz(eixo, fixo, aa + 12, lado * (meia + 10))
							if not emArea(fx, fz, 3) then
								colocar("cerca_arame", fx, fz, rotAo(eixo) + pi / 2, { w = 24 }, { gd = 0.6 })
							end
						end
					end
					aa += 28
				end
			end
		end
		-- guard-rails nas curvas (quinas da polilinha)
		for q = 2, #est.pts - 1 do
			local p = est.pts[q]
			local meia = est.largura / 2
			for _, s in { { 1, 1 }, { -1, -1 } } do
				local x, z = p[1] + s[1] * (meia + 3), p[2] + s[2] * (meia + 3)
				if not emArea(x, z, 3) then
					colocar("guard_rail", x, z, 0, { w = 16 }, { via = true })
					colocar("guard_rail", x, z, pi / 2, { w = 16 }, { via = true })
				end
			end
		end
	end
	-- cabeceiras de pontes
	limiteAtual = ORCAMENTO.estrada
	for _, pt in plano.pontes do
		local lat = pt.largura / 2 + 2.5
		for _, lado in { -1, 1 } do
			for _, ponta in { { pt.a0 - 14, 1 }, { pt.a1 + 14, -1 } } do
				local x, z = xz(pt.eixo, pt.fixo, ponta[1], lado * lat)
				if not emArea(x, z, 3) then
					colocar("guard_rail", x, z, rotAo(pt.eixo) + pi / 2, { w = 20 }, { via = false, gd = 1.2 })
				end
			end
		end
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- relatorio
	-- ------------------------------------------------------------------------------------------------------------
	ctx.avisos = ctx.avisos or {}
	local linhas = {}
	for nome, n in contagem do
		table.insert(linhas, string.format("%s=%d", nome, n))
	end
	table.sort(linhas)
	print(
		string.format(
			"[decoracao] %d pecas de Props (cidade %d, vilas %d, estradas %d); %s",
			totalPecas,
			gasto.cidade,
			gasto.vila,
			gasto.estrada,
			table.concat(linhas, " ")
		)
	)
	if not usaObs then
		table.insert(ctx.avisos, "decoracao: ruas/calcadas registradas como obstaculo; usada so a grade propria")
	end
end

return M
