-- Cidade 900x900: laje de asfalto, faixas, calcadas, lotes, edificios por regiao (centro/comercial/residencial) e parques.
-- Contrato: docs/mapa-v2.md (L1). Edificios vem do catalogo (Cat.construir); props de parque de Props.colocar.
-- Adaptado de _legado_gerar_mapa_v1.luau (laje, faixas, calcadas, lotes, manchas de LeafyGrass).

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Cat = require("./catalogo")
local Props = require("./props")

local abs, floor, max, min, pi = math.abs, math.floor, math.max, math.min, math.pi

local M = {}

local NIVEL_PAD = 0.5 -- asfalto
local NIVEL_CALCADA = 0.9
local NIVEL_LOTE = 1.1
local LIMITE_PECAS = 50000 -- orcamento de Construcoes da cidade
local FRENTE_LIVRE = 6 -- st livres a frente da fachada
local MARGEM_CTX = 6 -- margem de ctx.retanguloOcupado entre edificios
local LIM = 50 -- pegada dentro de +-50 do centro do lote (lote = +-54, recuo >= 4)

local COR = {
	asfalto = { 54, 55, 58 },
	faixa = { 136, 126, 84 },
	faixaPedestre = { 160, 158, 150 },
	calcada = { 118, 116, 110 },
	loteUrbano = { 92, 92, 88 },
	loteVerde = { 76, 90, 66 },
	grama = { 68, 92, 58 },
	alameda = { 124, 120, 110 },
	praca = { 138, 134, 124 },
	areia = { 150, 135, 100 },
	manchaAlta = { 92, 108, 60 },
}

-- Cotas: variantes que NUNCA saem do sorteio comum; so entram pelas exigencias (quantidade e regiao).
local COTAS = {
	hospital = true,
	delegacia = true,
	prefeitura = true,
	biblioteca = true,
	bombeiros = true,
	mercado = true,
	posto = true,
	banco = true,
	escola = true,
	igreja = true,
}
-- Comercio pequeno no residencial so em esquina de quarteirao
local SO_ESQUINA = {
	loja_conveniencia = true,
	loja_ferragens = true,
	farmacia = true,
	bar = true,
	oficina = true,
}
-- Prioridade de corte se estourar o orcamento (menor = corta primeiro). Ausente = nunca corta.
local PRIORIDADE = {
	casa_pequena = 1,
	casa_media = 1,
	casa_grande = 1,
	sobrado = 1,
	cabana = 1,
	apartamentos = 2,
	loja_conveniencia = 2,
	loja_ferragens = 2,
	farmacia = 2,
	bar = 2,
	oficina = 2,
	loja_roupas = 2,
	restaurante = 3,
	predio_misto = 3,
	hotel = 3,
	garagem = 3,
	escritorio = 4,
	torre = 5,
}

local PARAMS = {
	centro = { recuo = { 6, 6 }, gap = { 10, 10 }, aceita = 1.0, modos = { "NS", "WE" }, interior = 0 },
	comercial = { recuo = { 6, 8 }, gap = { 10, 14 }, aceita = 0.9, modos = { "NS", "WE", "4" }, interior = 4 },
	residencial = { recuo = { 8, 13 }, gap = { 10, 22 }, aceita = 0.55, modos = { "4" }, interior = 4 },
}

local FACES = {
	N = { th = 0, fx = 0, fz = -1 },
	S = { th = pi, fx = 0, fz = 1 },
	W = { th = pi / 2, fx = -1, fz = 0 },
	E = { th = -pi / 2, fx = 1, fz = 0 },
}

function M.gerar(ctx)
	local Mundo = ctx.Mundo
	local C = Mundo.cidade
	local plano = ctx.plano
	local rng = ctx.rng("cidade")
	local rngPark = ctx.rng("cidade_parques")
	ctx.avisos = ctx.avisos or {}

	local passo = plano.passo
	local meiaCidade = plano.meiaCidade
	local meiaVia = plano.meiaVia
	local N = floor(C.lado / passo + 0.5) -- quarteiroes por lado (6)
	local LOTE = C.quarteirao / 2 - C.calcada -- meio lado do lote (54)
	local meioQuart = C.quarteirao / 2
	local origin = CFrame.new()

	local function rgb(c)
		return ctx.rgb(c)
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Ruas: laje de asfalto, faixas tracejadas, faixas de pedestre
	-- -------------------------------------------------------------------------------------------------------------
	ctx.laje(
		"Ruas",
		"AsfaltoCidade",
		-meiaVia,
		meiaVia,
		-meiaVia,
		meiaVia,
		NIVEL_PAD,
		2,
		COR.asfalto,
		Mundo.avenida.material
	)

	local centrosRua = {}
	for k = 0, N do
		centrosRua[k] = -meiaCidade + passo * k
	end
	local meiaRua = C.rua / 2
	local opFaixa = { colide = false, consulta = false, sombra = false }

	local function tracejado(a: number, b: number, fixo: number, ao_longo_x: boolean)
		local len = b - a
		local dash, periodo = 6, 16
		local n = floor((len + (periodo - dash)) / periodo)
		local total = n * dash + (n - 1) * (periodo - dash)
		local s0 = a + (len - total) / 2
		for q = 0, n - 1 do
			local c = s0 + q * periodo + dash / 2
			if ao_longo_x then
				ctx.bloco(
					ctx.pastas.Ruas,
					origin,
					"FaixaH",
					c,
					NIVEL_PAD + 0.05,
					fixo,
					dash,
					0.2,
					0.8,
					COR.faixa,
					"Asphalt",
					opFaixa
				)
			else
				ctx.bloco(
					ctx.pastas.Ruas,
					origin,
					"FaixaV",
					fixo,
					NIVEL_PAD + 0.05,
					c,
					0.8,
					0.2,
					dash,
					COR.faixa,
					"Asphalt",
					opFaixa
				)
			end
		end
	end
	for k = 0, N do
		for i = 0, N - 1 do
			local a = centrosRua[i] + meiaRua
			local b = centrosRua[i + 1] - meiaRua
			tracejado(a, b, centrosRua[k], true)
			tracejado(a, b, centrosRua[k], false)
		end
	end
	-- faixas de pedestre nos braços que existem (nao saem da laje)
	for i = 0, N do
		for j = 0, N do
			local cx, cz = centrosRua[i], centrosRua[j]
			for _, off in { -8, -4, 0, 4, 8 } do
				if i < N then
					ctx.bloco(
						ctx.pastas.Ruas,
						origin,
						"Zebra",
						cx + meiaRua + 5,
						NIVEL_PAD + 0.05,
						cz + off,
						6,
						0.2,
						2.2,
						COR.faixaPedestre,
						"Asphalt",
						opFaixa
					)
				end
				if i > 0 then
					ctx.bloco(
						ctx.pastas.Ruas,
						origin,
						"Zebra",
						cx - meiaRua - 5,
						NIVEL_PAD + 0.05,
						cz + off,
						6,
						0.2,
						2.2,
						COR.faixaPedestre,
						"Asphalt",
						opFaixa
					)
				end
				if j < N then
					ctx.bloco(
						ctx.pastas.Ruas,
						origin,
						"Zebra",
						cx + off,
						NIVEL_PAD + 0.05,
						cz + meiaRua + 5,
						2.2,
						0.2,
						6,
						COR.faixaPedestre,
						"Asphalt",
						opFaixa
					)
				end
				if j > 0 then
					ctx.bloco(
						ctx.pastas.Ruas,
						origin,
						"Zebra",
						cx + off,
						NIVEL_PAD + 0.05,
						cz - meiaRua - 5,
						2.2,
						0.2,
						6,
						COR.faixaPedestre,
						"Asphalt",
						opFaixa
					)
				end
			end
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Quarteiroes: regiao pela distancia de Chebyshev ao centro; parques
	-- -------------------------------------------------------------------------------------------------------------
	local function regiaoDe(bx: number, bz: number): string
		local d = max(abs(bx - C.centro[1]), abs(bz - C.centro[2]))
		if d <= C.regioes.centro then
			return "centro"
		elseif d <= C.regioes.comercial then
			return "comercial"
		end
		return "residencial"
	end

	local blocos = {}
	local porRegiao = { centro = {}, comercial = {}, residencial = {} }
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			local bx = -meiaCidade + passo / 2 + passo * i
			local bz = -meiaCidade + passo / 2 + passo * j
			local reg = regiaoDe(bx, bz)
			local bl = { i = i, j = j, bx = bx, bz = bz, regiao = reg, parque = false, pendentes = {}, zonas = {} }
			table.insert(blocos, bl)
			table.insert(porRegiao[reg], bl)
		end
	end

	local function embaralhar(lista)
		local r = {}
		for _, v in lista do
			table.insert(r, v)
		end
		for k = #r, 2, -1 do
			local q = rng.inteiro(1, k)
			r[k], r[q] = r[q], r[k]
		end
		return r
	end

	-- parques: 1 no comercial e 2 no residencial (afastados entre si)
	local parques = {}
	do
		local function sortearParque(lista)
			for _ = 1, 200 do
				local bl = rng.escolher(lista)
				local ok = not bl.parque
				for _, p in parques do
					if max(abs(p.bx - bl.bx), abs(p.bz - bl.bz)) < 300 then
						ok = false
					end
				end
				if ok then
					bl.parque = true
					table.insert(parques, bl)
					return
				end
			end
		end
		sortearParque(porRegiao.comercial)
		sortearParque(porRegiao.residencial)
		sortearParque(porRegiao.residencial)
	end

	-- calcadas e lotes (lote vazio de predio: parque troca a laje)
	for _, bl in blocos do
		local bx, bz = bl.bx, bl.bz
		ctx.laje(
			"Ruas",
			"Calcada",
			bx - meioQuart,
			bx + meioQuart,
			bz - meioQuart,
			bz + meioQuart,
			NIVEL_CALCADA,
			0.9,
			ctx.variar(COR.calcada, 0.04, rng),
			"Concrete"
		)
		if bl.parque then
			ctx.laje(
				"Chao",
				"LoteParque",
				bx - LOTE,
				bx + LOTE,
				bz - LOTE,
				bz + LOTE,
				NIVEL_LOTE,
				0.5,
				ctx.variar(COR.grama, 0.06, rng),
				"Grass"
			)
		elseif bl.regiao == "residencial" then
			ctx.laje(
				"Chao",
				"Lote",
				bx - LOTE,
				bx + LOTE,
				bz - LOTE,
				bz + LOTE,
				NIVEL_LOTE,
				0.5,
				ctx.variar(COR.loteVerde, 0.06, rng),
				"Grass"
			)
		else
			ctx.laje(
				"Chao",
				"Lote",
				bx - LOTE,
				bx + LOTE,
				bz - LOTE,
				bz + LOTE,
				NIVEL_LOTE,
				0.5,
				ctx.variar(COR.loteUrbano, 0.05, rng),
				"Pavement"
			)
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Parques: fonte central, alamedas em cruz, 4 quadrantes (coreto, playground, bosque, jardim), bancos, arvores
	-- -------------------------------------------------------------------------------------------------------------
	local function parque(bl)
		local bx, bz = bl.bx, bl.bz
		local rp = rngPark
		local function colocar(nome, lx, lz, rot, op)
			return Props.colocar(ctx, ctx.pastas.Props, nome, bx + lx, bz + lz, rot, op)
		end
		local topoA = NIVEL_LOTE + 0.1
		ctx.laje(
			"Ruas",
			"Alameda",
			bx - LOTE,
			bx + LOTE,
			bz - 4,
			bz + 4,
			topoA,
			0.3,
			ctx.variar(COR.alameda, 0.04, rp),
			"Pavement"
		)
		ctx.laje(
			"Ruas",
			"Alameda",
			bx - 4,
			bx + 4,
			bz - LOTE,
			bz - 4,
			topoA,
			0.3,
			ctx.variar(COR.alameda, 0.04, rp),
			"Pavement"
		)
		ctx.laje(
			"Ruas",
			"Alameda",
			bx - 4,
			bx + 4,
			bz + 4,
			bz + LOTE,
			topoA,
			0.3,
			ctx.variar(COR.alameda, 0.04, rp),
			"Pavement"
		)
		ctx.laje(
			"Ruas",
			"Praca",
			bx - 15,
			bx + 15,
			bz - 15,
			bz + 15,
			NIVEL_LOTE + 0.2,
			0.4,
			ctx.variar(COR.praca, 0.03, rp),
			"Cobblestone"
		)
		colocar("fonte", 0, 0, 0, { rng = rp })

		-- bancos nas alamedas, de frente para o caminho
		for _, u in { -40, -26, 26, 40 } do
			colocar("banco_praca", u, 8, 0, { rng = rp })
			colocar("banco_praca", u, -8, pi, { rng = rp })
			colocar("banco_praca", 8, u, pi / 2, { rng = rp })
			colocar("banco_praca", -8, u, -pi / 2, { rng = rp })
		end

		-- arvores ao longo do perimetro interno (deixa as entradas das alamedas livres)
		for _, u in { -42, -28, -14, 14, 28, 42 } do
			colocar("arvore_rua", u, -46, 0, { rng = rp })
			colocar("arvore_rua", u, 46, 0, { rng = rp })
			colocar("arvore_rua", -46, u, 0, { rng = rp })
			colocar("arvore_rua", 46, u, 0, { rng = rp })
		end

		local tipos = { "coreto", "playground", "bosque", "jardim" }
		for k = #tipos, 2, -1 do
			local q = rp.inteiro(1, k)
			tipos[k], tipos[q] = tipos[q], tipos[k]
		end
		local qi = 0
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				qi += 1
				local tipo = tipos[qi]
				local qx, qz = sx * 28, sz * 28
				if tipo == "coreto" then
					colocar("coreto", qx, qz, 0, { rng = rp })
					colocar("canteiro", qx, qz - 14, 0, { rng = rp })
					colocar("canteiro", qx, qz + 14, 0, { rng = rp })
					colocar("canteiro", qx - 14, qz, pi / 2, { rng = rp })
					colocar("canteiro", qx + 14, qz, pi / 2, { rng = rp })
				elseif tipo == "playground" then
					ctx.laje(
						"Ruas",
						"AreiaPlayground",
						bx + qx - 14,
						bx + qx + 14,
						bz + qz - 14,
						bz + qz + 14,
						NIVEL_LOTE + 0.15,
						0.3,
						ctx.variar(COR.areia, 0.05, rp),
						"Sand"
					)
					colocar("balanco", qx - 7, qz - 7, 0, { rng = rp })
					colocar("escorregador", qx + 8, qz - 4, 0, { rng = rp })
					colocar("gangorra", qx - 2, qz + 9, 0, { rng = rp })
				elseif tipo == "bosque" then
					local pos = {}
					for _ = 1, 30 do
						if #pos >= 5 then
							break
						end
						local lx, lz = qx + rp.entre(-10, 10), qz + rp.entre(-10, 10)
						local ok = true
						for _, p in pos do
							if abs(p[1] - lx) < 9.5 and abs(p[2] - lz) < 9.5 then
								ok = false
							end
						end
						if ok then
							table.insert(pos, { lx, lz })
						end
					end
					for _, p in pos do
						colocar("arvore_rua", p[1], p[2], rp.entre(0, 6.28), { rng = rp })
					end
				else
					for _, ox in { -6, 6 } do
						for _, oz in { -9, 9 } do
							colocar("canteiro", qx + ox, qz + oz, 0, { rng = rp })
						end
					end
					colocar("banco_praca", qx, qz, if sx < 0 then -pi / 2 else pi / 2, { rng = rp })
				end
			end
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Colocacao de edificios
	-- -------------------------------------------------------------------------------------------------------------
	local nomesVariantes = {}
	for nome in Cat.def do
		table.insert(nomesVariantes, nome)
	end
	table.sort(nomesVariantes)

	local pools = { centro = {}, comercial = {}, residencial = {} }
	for _, nome in nomesVariantes do
		local d = Cat.def[nome]
		if not COTAS[nome] then
			for _, reg in d.regioes do
				table.insert(pools[reg], {
					variante = nome,
					peso = d.peso,
					w = d.w,
					d = d.d,
					soEsquina = reg == "residencial" and SO_ESQUINA[nome] == true,
				})
			end
		end
	end

	local function escolher(regiao: string, maxW: number, maxD: number, esquina: boolean)
		local lista = {}
		for _, e in pools[regiao] do
			if e.w <= maxW + 0.01 and e.d <= maxD and (esquina or not e.soEsquina) then
				table.insert(lista, e)
			end
		end
		if #lista == 0 then
			return nil
		end
		return rng.sortear(lista)
	end

	local colocados = {} -- { variante, regiao, modelo, spec, info, pecas, dist, bloco }

	local function contarPecas(modelo)
		local n = 0
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end

	-- retangulos em coordenadas LOCAIS do lote: corpo e zona de frente
	local function retangulos(cx, cz, wx, wz, fx, fz)
		local x0, x1, z0, z1 = cx - wx / 2, cx + wx / 2, cz - wz / 2, cz + wz / 2
		local zx0, zx1, zz0, zz1 = x0, x1, z0, z1
		if fz < 0 then
			zz0, zz1 = z0 - FRENTE_LIVRE, z0
		elseif fz > 0 then
			zz0, zz1 = z1, z1 + FRENTE_LIVRE
		elseif fx < 0 then
			zx0, zx1 = x0 - FRENTE_LIVRE, x0
		else
			zx0, zx1 = x1, x1 + FRENTE_LIVRE
		end
		return { x0, x1, z0, z1 }, { zx0, zx1, zz0, zz1 }
	end

	local function valido(bl, corpo, zona): boolean
		if corpo[1] < -LIM or corpo[2] > LIM or corpo[3] < -LIM or corpo[4] > LIM then
			return false
		end
		local bx, bz = bl.bx, bl.bz
		if ctx.retanguloOcupado(bx + corpo[1], bx + corpo[2], bz + corpo[3], bz + corpo[4], MARGEM_CTX) then
			return false
		end
		if ctx.retanguloOcupado(bx + zona[1], bx + zona[2], bz + zona[3], bz + zona[4], 0) then
			return false
		end
		for _, z in bl.zonas do
			if corpo[1] < z[2] and corpo[2] > z[1] and corpo[3] < z[4] and corpo[4] > z[3] then
				return false
			end
		end
		return true
	end

	local function construirEm(bl, variante: string, cx, cz, face, wx, wz, corpo, zona)
		local def = Cat.def[variante]
		local cf = CFrame.new(bl.bx + cx, NIVEL_LOTE, bl.bz + cz) * CFrame.Angles(0, face.th, 0)
		local spec = { cf = cf, zona = "cidade" }
		if variante == "apartamentos" and bl.regiao == "residencial" then
			spec.andares = def.andares[1] -- apartamentos baixos fora do centro
		end
		local modelo, info = Cat.construir(ctx, variante, spec)
		table.insert(bl.zonas, { bl.bx + zona[1], bl.bx + zona[2], bl.bz + zona[3], bl.bz + zona[4] })
		table.insert(colocados, {
			variante = variante,
			regiao = bl.regiao,
			modelo = modelo,
			spec = spec,
			info = info,
			pecas = contarPecas(modelo),
			dist = max(abs(bl.bx), abs(bl.bz)),
			bloco = bl,
		})
		return true
	end

	-- posicao ao longo da borda -> geometria local
	local function geometria(lado: string, u: number, w: number, d: number, rec: number)
		if lado == "N" then
			return u, -LOTE + rec + d / 2, w, d
		elseif lado == "S" then
			return u, LOTE - rec - d / 2, w, d
		elseif lado == "W" then
			return -LOTE + rec + d / 2, u, d, w
		end
		return LOTE - rec - d / 2, u, d, w
	end

	local function tentar(bl, variante: string, lado: string, u: number, rec: number): boolean
		local def = Cat.def[variante]
		local face = FACES[lado]
		local cx, cz, wx, wz = geometria(lado, u, def.w, def.d, rec)
		local corpo, zona = retangulos(cx, cz, wx, wz, face.fx, face.fz)
		if not valido(bl, corpo, zona) then
			return false
		end
		return construirEm(bl, variante, cx, cz, face, wx, wz, corpo, zona)
	end

	-- coloca uma variante especifica em qualquer ponto livre do perimetro (ou, por ultimo, do miolo)
	local function colocarEspecifico(bl, variante: string): boolean
		local def = Cat.def[variante]
		local P = PARAMS[bl.regiao]
		for _, lado in embaralhar({ "N", "S", "W", "E" }) do
			local u0 = -LIM + 1
			while u0 + def.w <= LIM - 1 + 0.01 do
				if tentar(bl, variante, lado, u0 + def.w / 2, P.recuo[1]) then
					return true
				end
				u0 += 3
			end
		end
		for _ = 1, 60 do
			local lado = rng.escolher({ "N", "S", "W", "E" })
			local face = FACES[lado]
			local wx, wz = def.w, def.d
			if lado == "W" or lado == "E" then
				wx, wz = def.d, def.w
			end
			local cx = rng.entre(-LIM + wx / 2, LIM - wx / 2)
			local cz = rng.entre(-LIM + wz / 2, LIM - wz / 2)
			local corpo, zona = retangulos(cx, cz, wx, wz, face.fx, face.fz)
			if valido(bl, corpo, zona) then
				return construirEm(bl, variante, cx, cz, face, wx, wz, corpo, zona)
			end
		end
		return false
	end

	local function percorrer(bl, lado: string)
		local P = PARAMS[bl.regiao]
		local cursor = -LIM + 1
		local fim = LIM - 1
		while cursor + 20 <= fim do
			local rec = rng.entre(P.recuo[1], P.recuo[2])
			local restante = fim - cursor
			local esquina = cursor <= -LIM + 2 or restante < 40
			local e = escolher(bl.regiao, restante, 2 * LOTE - 2 * rec - 8, esquina)
			if not e then
				break
			end
			if not rng.chance(P.aceita) then
				cursor += rng.entre(8, 16)
			elseif tentar(bl, e.variante, lado, cursor + e.w / 2, rec) then
				cursor += e.w + rng.entre(P.gap[1], P.gap[2])
			else
				cursor += 4
			end
		end
	end

	local function preencherMiolo(bl)
		local P = PARAMS[bl.regiao]
		for _ = 1, P.interior do
			local e = escolher(bl.regiao, 50, 50, false)
			if not e then
				break
			end
			local cx = rng.entre(-LIM + 14, LIM - 14)
			local cz = rng.entre(-LIM + 14, LIM - 14)
			-- orientacoes por distancia da fachada a borda mais proxima
			local ordem = {}
			for _, lado in { "N", "S", "W", "E" } do
				local face = FACES[lado]
				local dist = if face.fz < 0
					then cz + LOTE
					elseif face.fz > 0 then LOTE - cz
					elseif face.fx < 0 then cx + LOTE
					else LOTE - cx
				table.insert(ordem, { lado = lado, dist = dist })
			end
			table.sort(ordem, function(a, b)
				return a.dist < b.dist
			end)
			for _, o in ordem do
				local face = FACES[o.lado]
				local wx, wz = e.w, e.d
				if o.lado == "W" or o.lado == "E" then
					wx, wz = e.d, e.w
				end
				local corpo, zona = retangulos(cx, cz, wx, wz, face.fx, face.fz)
				if valido(bl, corpo, zona) then
					construirEm(bl, e.variante, cx, cz, face, wx, wz, corpo, zona)
					break
				end
			end
		end
	end

	-- exigencias (cotas): quantidade e regioes de cada variante rara
	local exigencias = {}
	do
		local function exigir(v: string, regs)
			table.insert(exigencias, { variante = v, regs = regs })
		end
		exigir("hospital", { "comercial" })
		exigir("delegacia", { "comercial" })
		exigir("prefeitura", { "centro" })
		exigir("biblioteca", { "comercial" })
		exigir("bombeiros", { "comercial" })
		if rng.chance(0.5) then
			exigir("bombeiros", { "residencial" })
		end
		exigir("mercado", { "comercial" })
		if rng.chance(0.5) then
			exigir("mercado", { "residencial" })
		end
		exigir("posto", { "comercial" })
		if rng.chance(0.5) then
			exigir("posto", { "residencial" })
		end
		exigir("banco", { "comercial" })
		exigir("banco", { "comercial" })
		exigir("escola", { "residencial" })
		exigir("igreja", { "residencial" })
		if rng.chance(0.5) then
			exigir("igreja", { "residencial" })
		end
	end
	local candidatosDe = function(ex)
		local lista = {}
		for _, bl in blocos do
			if not bl.parque then
				for _, r in ex.regs do
					if bl.regiao == r then
						table.insert(lista, bl)
					end
				end
			end
		end
		return lista
	end
	for _, ex in exigencias do
		local lista = embaralhar(candidatosDe(ex))
		local melhor, custo = nil, math.huge
		for _, bl in lista do
			local c = #bl.pendentes
			for _, p in bl.pendentes do
				if p == ex.variante then
					c += 10
				end
			end
			if c < custo then
				melhor, custo = bl, c
			end
		end
		assert(melhor, "sem quarteirao para " .. ex.variante)
		table.insert(melhor.pendentes, ex.variante)
	end

	local falhas = {}
	for _, bl in blocos do
		if bl.parque then
			parque(bl)
		else
			local P = PARAMS[bl.regiao]
			for _, v in bl.pendentes do
				if not colocarEspecifico(bl, v) then
					table.insert(falhas, v)
				end
			end
			local modo = rng.escolher(P.modos)
			if modo == "NS" then
				percorrer(bl, "N")
				percorrer(bl, "S")
			elseif modo == "WE" then
				percorrer(bl, "W")
				percorrer(bl, "E")
			else
				percorrer(bl, "N")
				percorrer(bl, "S")
				percorrer(bl, "W")
				percorrer(bl, "E")
			end
			preencherMiolo(bl)
		end
	end
	-- cotas que nao couberam no quarteirao sorteado: tenta nos outros da regiao
	for _, v in falhas do
		local ex = nil
		for _, e in exigencias do
			if e.variante == v then
				ex = e
			end
		end
		local ok = false
		for _, bl in embaralhar(candidatosDe(ex)) do
			if colocarEspecifico(bl, v) then
				ok = true
				break
			end
		end
		if not ok then
			table.insert(ctx.avisos, "cidade: nao coube a cota " .. v)
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Orcamento: corta o que for de menor prioridade (de fora para dentro) se Construcoes passar do limite
	-- -------------------------------------------------------------------------------------------------------------
	local total = 0
	for _, c in colocados do
		total += c.pecas
	end
	local cortados = 0
	if total > LIMITE_PECAS then
		local cand = {}
		for _, c in colocados do
			if PRIORIDADE[c.variante] then
				c.sorte = rng.rnd()
				table.insert(cand, c)
			end
		end
		table.sort(cand, function(a, b)
			local pa, pb = PRIORIDADE[a.variante], PRIORIDADE[b.variante]
			if pa ~= pb then
				return pa < pb
			end
			if a.dist ~= b.dist then
				return a.dist > b.dist
			end
			return a.sorte < b.sorte
		end)
		for _, c in cand do
			if total <= LIMITE_PECAS then
				break
			end
			total -= c.pecas
			c.removido = true
			c.modelo:Destroy()
			cortados += 1
		end
		if total > LIMITE_PECAS then
			table.insert(
				ctx.avisos,
				string.format("cidade: Construcoes %d pecas passou de %d mesmo apos cortes", total, LIMITE_PECAS)
			)
		end
	end

	local sobreviventes = {}
	for _, c in colocados do
		if not c.removido then
			ctx.registrarConstrucao(c.spec, c.modelo, c.info)
			table.insert(sobreviventes, c)
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Terrenos baldios: manchas de LeafyGrass nos lotes residenciais
	-- -------------------------------------------------------------------------------------------------------------
	local nManchas = 0
	do
		local lotes = {}
		for _, bl in blocos do
			if bl.regiao == "residencial" and not bl.parque then
				table.insert(lotes, bl)
			end
		end
		local alvo = C.gramaAltaManchas
		local tent = 0
		while nManchas < alvo and tent < alvo * 200 do
			tent += 1
			local bl = rng.escolher(lotes)
			local tam = rng.entre(8, 18)
			local x0 = bl.bx + rng.entre(-LOTE + 2, LOTE - 2 - tam)
			local z0 = bl.bz + rng.entre(-LOTE + 2, LOTE - 2 - tam)
			local x1, z1 = x0 + tam, z0 + tam
			local base = ctx.topoEm((x0 + x1) / 2, (z0 + z1) / 2)
			local plano_ = true
			for _, pt in { { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } } do
				if ctx.topoEm(pt[1], pt[2]) ~= base then
					plano_ = false
				end
			end
			if plano_ and not ctx.retanguloOcupado(x0, x1, z0, z1, 3) then
				local topo = base + 0.15
				ctx.bloco(
					ctx.pastas.Vegetacao,
					origin,
					"Mancha",
					(x0 + x1) / 2,
					topo - 0.15,
					(z0 + z1) / 2,
					tam,
					0.3,
					tam,
					ctx.variar(COR.manchaAlta, 0.12, rng),
					"LeafyGrass",
					nil
				)
				ctx.registrarSuperficie(x0, x1, z0, z1, topo)
				nManchas += 1
			end
		end
	end

	-- -------------------------------------------------------------------------------------------------------------
	-- Relatorio
	-- -------------------------------------------------------------------------------------------------------------
	local pecasReg = { centro = 0, comercial = 0, residencial = 0 }
	local nReg = { centro = 0, comercial = 0, residencial = 0 }
	local porVariante = {}
	for _, c in sobreviventes do
		pecasReg[c.regiao] += c.pecas
		nReg[c.regiao] += 1
		porVariante[c.variante] = (porVariante[c.variante] or 0) + 1
	end
	local totalFinal = pecasReg.centro + pecasReg.comercial + pecasReg.residencial
	print(
		string.format(
			"[cidade] %d edificios, %d pecas em Construcoes (limite %d), %d cortados, %d manchas, %d parques",
			#sobreviventes,
			totalFinal,
			LIMITE_PECAS,
			cortados,
			nManchas,
			#parques
		)
	)
	for _, reg in { "centro", "comercial", "residencial" } do
		print(string.format("[cidade]   %-11s %3d edificios %6d pecas", reg, nReg[reg], pecasReg[reg]))
	end
	local partes = {}
	for _, nome in nomesVariantes do
		if porVariante[nome] then
			table.insert(partes, nome .. "=" .. porVariante[nome])
		end
	end
	print("[cidade] variantes: " .. table.concat(partes, ", "))
	local faltando = {}
	for nome in Cat.faltando do
		table.insert(faltando, nome)
	end
	table.sort(faltando)
	local usadosFalt = 0
	for _, nome in faltando do
		usadosFalt += porVariante[nome] or 0
	end
	print(
		string.format(
			"[cidade] placeholders (Cat.faltando): %d variantes (%d edificios): %s",
			#faltando,
			usadosFalt,
			table.concat(faltando, ", ")
		)
	)
	ctx.cidadeResumo = { colocados = sobreviventes, parques = parques, blocos = blocos }
end

return M
