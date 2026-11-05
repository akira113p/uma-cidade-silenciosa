-- Plano geométrico do mapa: só dados e contas (nenhuma Instance). Lê Config/Mundo e devolve rios suavizados, estradas
-- em segmentos/retângulos, pontes (estrada × rio), viadutos, áreas planas e a zona de qualquer ponto.
-- Todos os módulos do gerador leem ctx.plano; ninguém recalcula isso por conta própria. Dono: Opus (integração).

local floor, ceil, min, max, abs, sqrt = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt

local plano = {}

local PASSO_RIO = 20 -- studs entre pontos da linha central suavizada
local FOLGA_PONTE = 6 -- studs de encontro (cabeceira) além do talude, de cada lado

local function catmull(p0, p1, p2, p3, t: number)
	local t2, t3 = t * t, t * t * t
	local function eixo(a: number, b: number, c: number, d: number): number
		return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
	end
	return { eixo(p0[1], p1[1], p2[1], p3[1]), eixo(p0[2], p1[2], p2[2], p3[2]) }
end

local function suavizar(pts)
	local denso = {}
	local n = #pts
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = pts[max(1, i - 1)], pts[i], pts[i + 1], pts[min(n, i + 2)]
		local dx, dz = p2[1] - p1[1], p2[2] - p1[2]
		local passos = max(1, ceil(sqrt(dx * dx + dz * dz) / PASSO_RIO))
		for k = 0, passos - 1 do
			table.insert(denso, catmull(p0, p1, p2, p3, k / passos))
		end
	end
	table.insert(denso, { pts[n][1], pts[n][2] })
	return denso
end

-- distância de (x,z) ao segmento a-b; devolve distância e ponto mais próximo
local function distSegmento(x: number, z: number, ax: number, az: number, bx: number, bz: number)
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = if l2 == 0 then 0 else max(0, min(1, ((x - ax) * dx + (z - az) * dz) / l2))
	local px, pz = ax + dx * t, az + dz * t
	local ex, ez = x - px, z - pz
	return sqrt(ex * ex + ez * ez), px, pz
end

function plano.criar(Mundo)
	local P = {}
	local C = Mundo.cidade
	local meiaCidade = C.lado / 2
	local passo = C.quarteirao + C.rua
	local meiaVia = meiaCidade + C.rua / 2 -- a rua de contorno entra na laje de asfalto da cidade

	local function ret(centro, lx: number, lz: number)
		return { x0 = centro[1] - lx / 2, x1 = centro[1] + lx / 2, z0 = centro[2] - lz / 2, z1 = centro[2] + lz / 2 }
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Áreas (retângulos). `cidade` é a laje de asfalto inteira.
	-- ---------------------------------------------------------------------------------------------------------------
	P.meiaVia = meiaVia
	P.passo = passo
	P.meiaCidade = meiaCidade
	P.cidade = { x0 = -meiaVia, x1 = meiaVia, z0 = -meiaVia, z1 = meiaVia }
	P.vilas = {}
	for i, v in Mundo.vilas do
		P.vilas[i] = ret(v.centro, v.lado, v.lado)
		P.vilas[i].nome = v.nome
	end
	P.fabrica = ret(Mundo.fabrica.centro, Mundo.fabrica.tamanho[1], Mundo.fabrica.tamanho[2])
	P.planicie = ret(Mundo.planicie.centro, Mundo.planicie.lado, Mundo.planicie.lado)
	P.guarda = ret(Mundo.guardaFlorestal.centro, 100, 100) -- pad do posto da guarda
	P.pois = {}
	for i, p in Mundo.pois do
		P.pois[i] = ret(p.centro, p.tam[1], p.tam[2])
		P.pois[i].nome = p.nome
		P.pois[i].tipo = p.tipo
		P.pois[i].centro = p.centro
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Rios: linha central suavizada + distância
	-- ---------------------------------------------------------------------------------------------------------------
	P.rios = {}
	for i, r in Mundo.rios do
		P.rios[i] = {
			nome = r.nome,
			largura = r.largura,
			margem = r.margem,
			profundidade = r.profundidade,
			pts = r.pts,
			denso = suavizar(r.pts),
		}
	end

	-- Distância de (x,z) à linha central do rio mais "influente" e seus dados: devolve (folga, rio, px, pz) onde
	-- folga = distância − (largura/2 + margem): ≤ 0 significa dentro do canal ou do talude. Menor folga entre os rios.
	function P.folgaRio(x: number, z: number)
		local melhorFolga, melhorRio, mx, mz = math.huge, nil, 0, 0
		for _, r in P.rios do
			local d = math.huge
			local qx, qz = 0, 0
			local dn = r.denso
			for k = 1, #dn - 1 do
				local dd, px, pz = distSegmento(x, z, dn[k][1], dn[k][2], dn[k + 1][1], dn[k + 1][2])
				if dd < d then
					d, qx, qz = dd, px, pz
				end
			end
			local folga = d - (r.largura / 2 + r.margem)
			if folga < melhorFolga then
				melhorFolga, melhorRio, mx, mz = folga, r, qx, qz
			end
		end
		return melhorFolga, melhorRio, mx, mz
	end

	-- Perfil do rio: profundidade (≥ 0) abaixo de Y = 0 na posição (x,z). 0 fora do rio. Canal reto no meio, talude
	-- suave (cosseno) nas margens.
	function P.profundidadeRio(x: number, z: number): number
		local folga, r, mx, mz = P.folgaRio(x, z)
		if not r or folga >= 0 then
			return 0
		end
		local ex, ez = x - mx, z - mz
		local d = sqrt(ex * ex + ez * ez)
		local meia = r.largura / 2
		if d <= meia then
			return r.profundidade
		end
		local t = (d - meia) / r.margem -- 0 na borda do canal, 1 no topo do talude
		return r.profundidade * 0.5 * (1 + math.cos(math.pi * min(1, t)))
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Estradas (avenidas + Mundo.estradas)
	-- ---------------------------------------------------------------------------------------------------------------
	local estradas = {}
	local AV = Mundo.avenida.largura
	local function avenida(nome: string, pts)
		table.insert(
			estradas,
			{ nome = nome, largura = AV, material = Mundo.avenida.material, pts = pts, avenida = true }
		)
	end
	do
		local v1, v2, v3 = Mundo.vilas[1], Mundo.vilas[2], Mundo.vilas[3]
		avenida("Avenida_Norte", { { v1.centro[1], P.vilas[1].z1 }, { v1.centro[1], -meiaVia } })
		-- parte da rua de contorno (z = meiaCidade) e desvia até o eixo da vila, para encostar na laje da cidade
		local zContorno = meiaCidade
		avenida("Avenida_Leste", {
			{ meiaVia, zContorno },
			{ meiaVia + 35, zContorno },
			{ meiaVia + 35, v2.centro[2] },
			{ P.vilas[2].x0, v2.centro[2] },
		})
		avenida("Avenida_Oeste", {
			{ -meiaVia, zContorno },
			{ -meiaVia - 35, zContorno },
			{ -meiaVia - 35, v3.centro[2] },
			{ P.vilas[3].x1, v3.centro[2] },
		})
		local fx = Mundo.fabrica.centro[1]
		local zRua = -meiaCidade + passo
		avenida("Avenida_Fabrica_A", { { meiaVia, zRua }, { fx, zRua } })
		avenida("Avenida_Fabrica_B", { { fx, zRua }, { fx, P.fabrica.z1 } })
		local gx = Mundo.guardaFlorestal.centro[1]
		avenida("Avenida_Guarda", { { gx, meiaVia }, { gx, P.guarda.z0 } })
	end
	for _, e in Mundo.estradas do
		table.insert(estradas, {
			nome = e.nome,
			largura = e.largura,
			material = e.material,
			pts = e.pts,
		})
	end

	P.estradas = {}
	P.estradaPorNome = {}
	for _, e in estradas do
		local meia = e.largura / 2
		local segs, rets = {}, {}
		local n = #e.pts
		for i = 1, n - 1 do
			local a, b = e.pts[i], e.pts[i + 1]
			assert(a[1] == b[1] or a[2] == b[2], e.nome .. ": segmento fora dos eixos")
			local eixo = if a[2] == b[2] then "x" else "z" -- "x" = anda ao longo de X
			local a0, a1 = if eixo == "x" then a[1] else a[2], if eixo == "x" then b[1] else b[2]
			local fixo = if eixo == "x" then a[2] else a[1]
			local lo, hi = min(a0, a1), max(a0, a1)
			-- cantos: nos vértices internos, cada segmento avança meia largura para fechar a quina
			if i > 1 then
				lo, hi = if a0 < a1 then lo - meia else lo, if a0 > a1 then hi + meia else hi
			end
			if i < n - 1 then
				lo, hi = if a1 < a0 then lo - meia else lo, if a1 > a0 then hi + meia else hi
			end
			local seg = { eixo = eixo, fixo = fixo, a0 = lo, a1 = hi, largura = e.largura }
			table.insert(segs, seg)
			if eixo == "x" then
				seg.ret = { x0 = lo, x1 = hi, z0 = fixo - meia, z1 = fixo + meia }
			else
				seg.ret = { x0 = fixo - meia, x1 = fixo + meia, z0 = lo, z1 = hi }
			end
			table.insert(rets, seg.ret)
		end
		local est = {
			nome = e.nome,
			largura = e.largura,
			material = e.material,
			avenida = e.avenida,
			pts = e.pts,
			segs = segs, -- { eixo, fixo, a0, a1, largura, ret, pontes = {}, viadutos = {} }
			rets = rets,
		}
		table.insert(P.estradas, est)
		P.estradaPorNome[e.nome] = est
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Pontes: onde o eixo de um segmento entra no talude de um rio
	-- ---------------------------------------------------------------------------------------------------------------
	P.pontes = {}
	for _, est in P.estradas do
		for _, seg in est.segs do
			seg.pontes = {}
			seg.viadutos = {}
			local atual = nil
			local a = seg.a0
			while a <= seg.a1 + 0.001 do
				local x, z = if seg.eixo == "x" then a else seg.fixo, if seg.eixo == "x" then seg.fixo else a
				local folga, rio = P.folgaRio(x, z)
				if folga < FOLGA_PONTE and rio then
					if not atual then
						atual = { a0 = a, a1 = a, rio = rio.nome }
					else
						atual.a1 = a
					end
				elseif atual then
					table.insert(seg.pontes, atual)
					atual = nil
				end
				a += 2
			end
			if atual then
				table.insert(seg.pontes, atual)
			end
			for _, p in seg.pontes do
				p.a0 -= FOLGA_PONTE
				p.a1 += FOLGA_PONTE
				p.nome = string.format("Ponte_%s_%s", est.nome, p.rio:gsub("%s", ""))
				p.estrada = est.nome
				p.eixo = seg.eixo
				p.fixo = seg.fixo
				p.largura = seg.largura
				p.centro = if seg.eixo == "x" then { (p.a0 + p.a1) / 2, seg.fixo } else { seg.fixo, (p.a0 + p.a1) / 2 }
				table.insert(P.pontes, p)
			end
		end
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Viadutos: o trecho [a0, a1] do segmento da `estrada` é do viaduto (a estrada não gera asfalto ali)
	-- ---------------------------------------------------------------------------------------------------------------
	P.viadutos = {}
	for _, v in Mundo.viadutos do
		local est = assert(P.estradaPorNome[v.estrada], v.nome .. ": estrada inexistente " .. v.estrada)
		local sob = assert(P.estradaPorNome[v.sobre], v.nome .. ": estrada inexistente " .. v.sobre)
		local achado = nil
		for _, seg in est.segs do
			local ao = if seg.eixo == "x" then v.centro[1] else v.centro[2]
			local fx = if seg.eixo == "x" then v.centro[2] else v.centro[1]
			if abs(fx - seg.fixo) < 0.5 and ao >= seg.a0 and ao <= seg.a1 then
				achado = { seg = seg, ao = ao }
			end
		end
		assert(achado, v.nome .. ": o centro não está sobre a estrada " .. v.estrada)
		local meiaDeck = sob.largura / 2 + 10
		local rampa = v.altura * 7
		local seg = achado.seg
		local vd = {
			nome = v.nome,
			estrada = v.estrada,
			sobre = v.sobre,
			eixo = seg.eixo,
			fixo = seg.fixo,
			largura = seg.largura,
			altura = v.altura,
			centro = v.centro,
			deck0 = achado.ao - meiaDeck,
			deck1 = achado.ao + meiaDeck,
			rampa = rampa,
			a0 = achado.ao - meiaDeck - rampa,
			a1 = achado.ao + meiaDeck + rampa,
			material = est.material,
		}
		assert(vd.a0 >= seg.a0 and vd.a1 <= seg.a1, v.nome .. ": as rampas passam do segmento da estrada")
		table.insert(seg.viadutos, vd)
		table.insert(P.viadutos, vd)
	end

	-- Trechos livres de uma estrada: o que sobra do segmento sem pontes e sem viadutos → o módulo de estradas faz
	-- asfalto só nesses intervalos. Devolve lista de { a0, a1 } ao longo do eixo.
	function P.trechosLivres(seg)
		local cortes = {}
		for _, p in seg.pontes do
			table.insert(cortes, { p.a0, p.a1 })
		end
		for _, v in seg.viadutos do
			table.insert(cortes, { v.a0, v.a1 })
		end
		table.sort(cortes, function(a, b)
			return a[1] < b[1]
		end)
		local livres = {}
		local cursor = seg.a0
		for _, c in cortes do
			if c[1] > cursor + 0.01 then
				table.insert(livres, { cursor, c[1] })
			end
			cursor = max(cursor, c[2])
		end
		if seg.a1 > cursor + 0.01 then
			table.insert(livres, { cursor, seg.a1 })
		end
		return livres
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Áreas planas (o relevo sobe a partir delas) — tudo que fica em Y = 0.5
	-- ---------------------------------------------------------------------------------------------------------------
	P.planos = { P.cidade, P.fabrica, P.planicie, P.guarda }
	for _, v in P.vilas do
		table.insert(P.planos, v)
	end
	for _, p in P.pois do
		table.insert(P.planos, p)
	end
	for _, est in P.estradas do
		for _, r in est.rets do
			table.insert(P.planos, r)
		end
	end

	-- Distância de (x,z) ao plano plano mais próximo (0 dentro de um); usada pelo relevo para subir suavemente.
	function P.distPlano(x: number, z: number): number
		local melhor = math.huge
		for _, r in P.planos do
			local dx = max(0, r.x0 - x, x - r.x1)
			local dz = max(0, r.z0 - z, z - r.z1)
			local d = sqrt(dx * dx + dz * dz)
			if d < melhor then
				melhor = d
				if d == 0 then
					return 0
				end
			end
		end
		return melhor
	end

	-- ---------------------------------------------------------------------------------------------------------------
	-- Zona (chave de Config/Monstros.densidade) de um ponto
	-- ---------------------------------------------------------------------------------------------------------------
	local function dentro(r, x: number, z: number, margem: number?): boolean
		local m = margem or 0
		return x >= r.x0 - m and x <= r.x1 + m and z >= r.z0 - m and z <= r.z1 + m
	end
	P.dentro = dentro

	function P.zonaEm(x: number, z: number): string
		if dentro(P.cidade, x, z) then
			return "cidade"
		end
		for _, r in P.vilas do
			if dentro(r, x, z) then
				return "vila"
			end
		end
		if dentro(P.fabrica, x, z) then
			return "fabrica"
		end
		if dentro(P.planicie, x, z) or dentro(P.guarda, x, z) then
			return "outros"
		end
		return "floresta"
	end

	-- Dentro de qualquer área construída, estrada ou POI, com margem (para a floresta não nascer ali)
	function P.emAreaConstruida(x: number, z: number, margem: number): boolean
		for _, r in P.planos do
			if dentro(r, x, z, margem) then
				return true
			end
		end
		return false
	end

	-- Dentro ou perto de um rio (folga < margemExtra)
	function P.emRio(x: number, z: number, margemExtra: number): boolean
		local folga = P.folgaRio(x, z)
		return folga < margemExtra
	end

	return P
end

return plano
