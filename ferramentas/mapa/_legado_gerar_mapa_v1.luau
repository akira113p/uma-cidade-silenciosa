-- Gera o mapa inteiro (cidade, vilas, fábrica, planície, posto da guarda, avenidas, floresta) em build/mapa_v1_legado.rbxm (LEGADO v1: nunca grava em mapa/Mapa.rbxm, que é do gerar_mapa.luau v2).
-- Uso (da raiz do projeto): lune run ferramentas/mapa/_legado_gerar_mapa_v1.luau
-- Determinístico: mesma semente (Config/Mundo.semente) = mesmo mapa. Este arquivo NÃO vai para o Workspace.Mapa;
-- não editar o mapa no Studio (é sobrescrito na próxima geração). Dono: P1. Contrato: docs/arquitetura.md §6.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Mundo = require("../src/shared/Config/Mundo")
local Monstros = require("../src/shared/Config/Monstros")
local Itens = require("../src/shared/Config/Itens")

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs

-- ---------------------------------------------------------------------------------------------------------------
-- Números do gerador que não são do jogo (só aparência/alinhamento do mapa)
-- ---------------------------------------------------------------------------------------------------------------
local NIVEL_PAD = 0.5 -- topo das áreas construídas (asfalto, pads); a floresta fica em 0
local NIVEL_CALCADA = 0.9
local NIVEL_LOTE = 1.1
local VIA_VILA = 24 -- largura das ruas de terra/asfalto dentro das vilas
local RECUO_LOTE = 4 -- distância da construção até a borda do lote (a calçada fica fora do lote)
local FOLGA_ENTRE_CONSTRUCOES = 8
local JANELAS = true
local LIMITE_PECAS = 15000

-- Tabela de loot por tipo de construção (Config/Itens.tabelas não tem "predio": prédio usa a de casa)
local TABELA_POR_TIPO = {
	casa = "casa",
	loja = "loja",
	predio = "casa",
	posto = "posto",
	galpao = "fabrica",
	guarda = "guarda",
}

local COR = {
	floresta = { 74, 88, 62 },
	planicie = { 98, 110, 76 },
	asfalto = { 54, 55, 58 },
	faixa = { 136, 126, 84 },
	calcada = { 118, 116, 110 },
	lote = { 92, 92, 88 },
	vila = { 102, 92, 76 },
	fabrica = { 84, 90, 96 },
	guarda = { 96, 88, 72 },
	manchaAlta = { 92, 108, 60 },
	tronco = { 82, 64, 48 },
	copa = { 52, 70, 50 },
	porta = { 38, 34, 32 },
	janela = { 46, 52, 58 },
	borda = { 255, 255, 255 },
	casa = { 140, 110, 96 },
	loja = { 128, 128, 122 },
	predio = { 108, 112, 118 },
	posto = { 116, 126, 136 },
	galpao = { 98, 106, 114 },
	guardaPredio = { 112, 88, 64 },
}

-- ---------------------------------------------------------------------------------------------------------------
-- Aleatório determinístico (Park-Miller): não depende da versão do Lune
-- ---------------------------------------------------------------------------------------------------------------
local estado = (Mundo.semente or 1) % 2147483647
if estado == 0 then
	estado = 1
end
local function rnd(): number
	estado = (estado * 48271) % 2147483647
	return (estado - 1) / 2147483646
end
local function entre(a: number, b: number): number
	return a + (b - a) * rnd()
end
local function inteiro(a: number, b: number): number -- inclusivo
	return a + floor(rnd() * (b - a + 1))
end
local function sinal(): number
	return if rnd() < 0.5 then -1 else 1
end
local function sortearPeso(lista)
	local total = 0
	for _, e in lista do
		total += e.peso
	end
	local r = rnd() * total
	for _, e in lista do
		r -= e.peso
		if r <= 0 then
			return e
		end
	end
	return lista[#lista]
end

-- ---------------------------------------------------------------------------------------------------------------
-- Peças
-- ---------------------------------------------------------------------------------------------------------------
local function rgb(c)
	return Color3.fromRGB(floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5))
end

local function variar(c, v: number)
	local k = 1 + (rnd() * 2 - 1) * v
	return { min(255, c[1] * k), min(255, c[2] * k), min(255, c[3] * k) }
end

local function escurecer(c, k: number)
	return { c[1] * k, c[2] * k, c[3] * k }
end

local mapa = Instance.new("Model")
mapa.Name = "Mapa"
mapa:SetAttribute("Semente", Mundo.semente)

local pastas = {}
for _, nome in { "Chao", "Ruas", "Construcoes", "Vegetacao", "Bordas", "Zonas", "Pontos" } do
	local f = Instance.new("Folder")
	f.Name = nome
	f.Parent = mapa
	pastas[nome] = f
end

-- opcoes: colide (padrão true), consulta (CanQuery, padrão true), transparencia, rotY
local function criar(
	pai,
	nome: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	cor,
	material: string,
	opcoes
)
	assert(max(sx, sy, sz) <= Mundo.pecaMaxima, nome .. " passa de " .. Mundo.pecaMaxima .. " studs")
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = Vector3.new(sx, sy, sz)
	if opcoes and opcoes.rotY then
		p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, opcoes.rotY, 0)
	else
		p.CFrame = CFrame.new(x, y, z)
	end
	p.Color = rgb(cor)
	p.Material = (Enum.Material :: any)[material]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if opcoes then
		if opcoes.colide == false then
			p.CanCollide = false
		end
		if opcoes.consulta == false then
			p.CanQuery = false
		end
		if opcoes.transparencia then
			p.Transparency = opcoes.transparencia
		end
	end
	p.Parent = pai
	return p
end

-- Superfícies pisáveis (retângulos com topo): usadas para pôr pontos "no chão" (Y = topo + 0.5)
local superficies = {}
local function topoEm(x: number, z: number): number?
	local melhor = nil
	for _, s in superficies do
		if x >= s.x0 and x <= s.x1 and z >= s.z0 and z <= s.z1 and (melhor == nil or s.topo > melhor) then
			melhor = s.topo
		end
	end
	return melhor
end

-- Laje com topo em `topo`, de x0..x1 e z0..z1
local function laje(
	pasta: string,
	nome: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	topo: number,
	espessura: number,
	cor,
	material: string
)
	local p = criar(
		pastas[pasta],
		nome,
		(x0 + x1) / 2,
		topo - espessura / 2,
		(z0 + z1) / 2,
		x1 - x0,
		espessura,
		z1 - z0,
		cor,
		material
	)
	table.insert(superficies, { x0 = x0, x1 = x1, z0 = z0, z1 = z1, topo = topo })
	return p
end

-- ---------------------------------------------------------------------------------------------------------------
-- Obstáculos (construções e troncos) em grade de baldes: consulta rápida de "tem coisa aqui?"
-- ---------------------------------------------------------------------------------------------------------------
local BALDE = 64
local balde = {}
local function chaveBalde(i: number, j: number): number
	return (i + 1000) * 10000 + (j + 1000)
end
local function inserirObstaculo(x0: number, x1: number, z0: number, z1: number)
	local r = { x0, x1, z0, z1 }
	for i = floor(x0 / BALDE), floor(x1 / BALDE) do
		for j = floor(z0 / BALDE), floor(z1 / BALDE) do
			local k = chaveBalde(i, j)
			local l = balde[k]
			if not l then
				l = {}
				balde[k] = l
			end
			table.insert(l, r)
		end
	end
end
-- retângulo (x0..x1, z0..z1) encosta em algum obstáculo, com `margem` de folga?
local function retanguloOcupado(x0: number, x1: number, z0: number, z1: number, margem: number): boolean
	for i = floor((x0 - margem) / BALDE), floor((x1 + margem) / BALDE) do
		for j = floor((z0 - margem) / BALDE), floor((z1 + margem) / BALDE) do
			local l = balde[chaveBalde(i, j)]
			if l then
				for _, r in l do
					if x0 - margem <= r[2] and x1 + margem >= r[1] and z0 - margem <= r[4] and z1 + margem >= r[3] then
						return true
					end
				end
			end
		end
	end
	return false
end
local function ocupado(x: number, z: number, margem: number): boolean
	return retanguloOcupado(x, x, z, z, margem)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Layout das áreas (tudo vem de Config/Mundo)
-- ---------------------------------------------------------------------------------------------------------------
local C = Mundo.cidade
local meiaCidade = C.lado / 2
local passo = C.quarteirao + C.rua
local nQuart = floor(C.lado / passo + 0.5)
local meiaVia = meiaCidade + C.rua / 2 -- a rua de contorno entra na laje de asfalto
local meiaLote = C.quarteirao / 2 - C.calcada
local cidadeX, cidadeZ = C.centro[1], C.centro[2]
assert(cidadeX == 0 and cidadeZ == 0, "o gerador assume a cidade centrada em 0,0")

local mt = Mundo.tamanho / 2

-- Retângulos das áreas (para zona/exclusão de árvores): { x0, x1, z0, z1 }
local areas = {
	cidade = { -meiaVia, meiaVia, -meiaVia, meiaVia },
}
local function retDe(centro, lx: number, lz: number)
	return { centro[1] - lx / 2, centro[1] + lx / 2, centro[2] - lz / 2, centro[2] + lz / 2 }
end
local vilasRet = {}
for i, v in Mundo.vilas do
	vilasRet[i] = retDe(v.centro, v.lado, v.lado)
end
local fabricaRet = retDe(Mundo.fabrica.centro, Mundo.fabrica.tamanho[1], Mundo.fabrica.tamanho[2])
local planiciRet = retDe(Mundo.planicie.centro, Mundo.planicie.lado, Mundo.planicie.lado)
local PAD_GUARDA = 100
local guardaRet = retDe(Mundo.guardaFlorestal.centro, PAD_GUARDA, PAD_GUARDA)

-- Avenidas: faixas de 40 (retângulos). Cada uma liga a cidade a uma área.
local AV = Mundo.avenida.largura
local meiaAv = AV / 2
local avenidas = {}
do
	local v1, v2, v3 = Mundo.vilas[1], Mundo.vilas[2], Mundo.vilas[3]
	-- Vila Norte: reta em x = centro, da laje da cidade até a borda da vila
	table.insert(
		avenidas,
		{ nome = "Avenida_Norte", r = { v1.centro[1] - meiaAv, v1.centro[1] + meiaAv, vilasRet[1][4], -meiaVia } }
	)
	-- Vila Leste / Oeste: retas em z = centro
	table.insert(
		avenidas,
		{ nome = "Avenida_Leste", r = { meiaVia, vilasRet[2][1], v2.centro[2] - meiaAv, v2.centro[2] + meiaAv } }
	)
	table.insert(
		avenidas,
		{ nome = "Avenida_Oeste", r = { vilasRet[3][2], -meiaVia, v3.centro[2] - meiaAv, v3.centro[2] + meiaAv } }
	)
	-- Fábrica: sai da rua z = -600 da cidade, vai até x da fábrica e sobe até a borda dela
	local fx, fz = Mundo.fabrica.centro[1], Mundo.fabrica.centro[2]
	local zRua = -meiaCidade + passo * 1
	table.insert(avenidas, { nome = "Avenida_Fabrica_A", r = { meiaVia, fx + meiaAv, zRua - meiaAv, zRua + meiaAv } })
	table.insert(
		avenidas,
		{ nome = "Avenida_Fabrica_B", r = { fx - meiaAv, fx + meiaAv, fabricaRet[4], zRua - meiaAv } }
	)
	-- Posto da guarda: reta em x = centro, da laje da cidade até a borda do pad
	local gx = Mundo.guardaFlorestal.centro[1]
	table.insert(avenidas, { nome = "Avenida_Guarda", r = { gx - meiaAv, gx + meiaAv, meiaVia, guardaRet[3] } })
end

-- Zona (chave de Config/Monstros.densidade) de um ponto
local function dentro(r, x: number, z: number, margem: number?): boolean
	local m = margem or 0
	return x >= r[1] - m and x <= r[2] + m and z >= r[3] - m and z <= r[4] + m
end
local function zonaEm(x: number, z: number): string
	if dentro(areas.cidade, x, z) then
		return "cidade"
	end
	for _, r in vilasRet do
		if dentro(r, x, z) then
			return "vila"
		end
	end
	if dentro(fabricaRet, x, z) then
		return "fabrica"
	end
	if dentro(planiciRet, x, z) or dentro(guardaRet, x, z) then
		return "outros"
	end
	return "floresta"
end

-- Exclusão para vegetação: dentro de qualquer área construída ou avenida (com margem)
local function emAreaConstruida(x: number, z: number, margem: number): boolean
	if dentro(areas.cidade, x, z, margem) or dentro(fabricaRet, x, z, margem) or dentro(guardaRet, x, z, margem) then
		return true
	end
	for _, r in vilasRet do
		if dentro(r, x, z, margem) then
			return true
		end
	end
	for _, a in avenidas do
		if dentro(a.r, x, z, margem) then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Chão base (floresta) e áreas construídas
-- ---------------------------------------------------------------------------------------------------------------
do
	local k = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k += 1
			local x0, x1 = if sx < 0 then -mt else 0, if sx < 0 then 0 else mt
			local z0, z1 = if sz < 0 then -mt else 0, if sz < 0 then 0 else mt
			laje("Chao", "Floresta_" .. k, x0, x1, z0, z1, 0, 4, COR.floresta, Mundo.floresta.material)
		end
	end
end

-- Cidade: laje de asfalto, faixas, calçadas e lotes
laje("Ruas", "AsfaltoCidade", -meiaVia, meiaVia, -meiaVia, meiaVia, NIVEL_PAD, 2, COR.asfalto, Mundo.avenida.material)

local centrosRua = {}
for k = 0, nQuart do
	centrosRua[k] = -meiaCidade + passo * k
end
for k = 0, nQuart do
	for i = 0, nQuart - 1 do
		local a = centrosRua[i] + C.rua / 2
		local b = centrosRua[i + 1] - C.rua / 2
		local zk = centrosRua[k]
		criar(
			pastas.Ruas,
			"FaixaH",
			(a + b) / 2,
			NIVEL_PAD + 0.05,
			zk,
			b - a,
			0.2,
			0.8,
			COR.faixa,
			"Asphalt",
			{ colide = false, consulta = false }
		)
		criar(
			pastas.Ruas,
			"FaixaV",
			zk,
			NIVEL_PAD + 0.05,
			(a + b) / 2,
			0.8,
			0.2,
			b - a,
			COR.faixa,
			"Asphalt",
			{ colide = false, consulta = false }
		)
	end
end

local lotes = {} -- { cx, cz }
for i = 0, nQuart - 1 do
	for j = 0, nQuart - 1 do
		local bx = -meiaCidade + passo / 2 + passo * i
		local bz = -meiaCidade + passo / 2 + passo * j
		local m = C.quarteirao / 2
		laje("Ruas", "Calcada", bx - m, bx + m, bz - m, bz + m, NIVEL_CALCADA, 0.9, COR.calcada, "Concrete")
		laje(
			"Chao",
			"Lote",
			bx - meiaLote,
			bx + meiaLote,
			bz - meiaLote,
			bz + meiaLote,
			NIVEL_LOTE,
			0.5,
			variar(COR.lote, 0.05),
			"Pavement"
		)
		table.insert(lotes, { cx = bx, cz = bz })
	end
end

-- Vilas
for i, v in Mundo.vilas do
	local r = vilasRet[i]
	laje("Chao", "Pad_" .. v.nome, r[1], r[2], r[3], r[4], NIVEL_PAD, 2, COR.vila, "Ground")
	local cx, cz, L = v.centro[1], v.centro[2], v.lado / 2
	local t = NIVEL_PAD + 0.2
	laje("Ruas", "RuaVilaH", cx - L, cx + L, cz - VIA_VILA / 2, cz + VIA_VILA / 2, t, 0.4, COR.asfalto, "Asphalt")
	laje(
		"Ruas",
		"RuaVilaV1",
		cx - VIA_VILA / 2,
		cx + VIA_VILA / 2,
		cz - L,
		cz - VIA_VILA / 2,
		t,
		0.4,
		COR.asfalto,
		"Asphalt"
	)
	laje(
		"Ruas",
		"RuaVilaV2",
		cx - VIA_VILA / 2,
		cx + VIA_VILA / 2,
		cz + VIA_VILA / 2,
		cz + L,
		t,
		0.4,
		COR.asfalto,
		"Asphalt"
	)
end

-- Fábrica, planície, posto da guarda
laje(
	"Chao",
	"Pad_Fabrica",
	fabricaRet[1],
	fabricaRet[2],
	fabricaRet[3],
	fabricaRet[4],
	NIVEL_PAD,
	2,
	COR.fabrica,
	Mundo.fabrica.piso
)
laje(
	"Chao",
	"Pad_Planicie",
	planiciRet[1],
	planiciRet[2],
	planiciRet[3],
	planiciRet[4],
	NIVEL_PAD,
	2,
	COR.planicie,
	Mundo.planicie.material
)
laje("Chao", "Pad_Guarda", guardaRet[1], guardaRet[2], guardaRet[3], guardaRet[4], NIVEL_PAD, 2, COR.guarda, "Ground")

-- Avenidas
for _, a in avenidas do
	laje("Ruas", a.nome, a.r[1], a.r[2], a.r[3], a.r[4], NIVEL_PAD, 2, COR.asfalto, Mundo.avenida.material)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Construções (blocos): Model com Corpo + Telhado (+ porta, janelas na frente). Interior = false.
-- ---------------------------------------------------------------------------------------------------------------
local construcoes = {} -- registro p/ loot e checagem: { tipo, zona, cx, cz, w, d, frente = {fx, fz}, loot = {x, z} }
local contadorModelo = 0

-- spec: tipo, zona, local, cx, cz, w (em x), d (em z), andares, altura?, base, material, cor, frente {fx,fz}, loot {x,z}
local function construir(spec)
	contadorModelo += 1
	local altura = spec.altura or spec.andares * C.alturaAndar
	local m = Instance.new("Model")
	m.Name = spec.tipo .. "_" .. contadorModelo
	m:SetAttribute("Tipo", spec.tipo)
	m:SetAttribute("Zona", spec.zona)
	m:SetAttribute("Andares", spec.andares)
	m:SetAttribute("Interior", false)
	if spec.local_ then
		m:SetAttribute("Local", spec.local_)
	end
	local cx, cz, w, d, base = spec.cx, spec.cz, spec.w, spec.d, spec.base

	local corpo = criar(m, "Corpo", cx, base + altura / 2 - 0.15, cz, w, altura + 0.3, d, spec.cor, spec.material)
	criar(m, "Telhado", cx, base + altura + 0.4, cz, w + 1.2, 0.8, d + 1.2, escurecer(spec.cor, 0.55), "Concrete")

	-- porta e janelas na face da frente
	local fx, fz = spec.frente[1], spec.frente[2]
	local larguraFrente = if fz ~= 0 then w else d
	local profundidade = if fz ~= 0 then d else w
	local function naFrente(lateral: number, y: number, sLat: number, sY: number, nome: string, cor)
		-- lateral = deslocamento ao longo da fachada
		local px, pz, sx, sz
		if fz ~= 0 then
			px, pz = cx + lateral, cz + fz * (profundidade / 2 + 0.1)
			sx, sz = sLat, 0.3
		else
			px, pz = cx + fx * (profundidade / 2 + 0.1), cz + lateral
			sx, sz = 0.3, sLat
		end
		criar(m, nome, px, base + y, pz, sx, sY, sz, cor, "SmoothPlastic", { colide = false, consulta = false })
	end
	naFrente(0, 3.75, 4.5, 7.5, "Porta", COR.porta)
	if JANELAS then
		local nj = max(1, min(3, floor(larguraFrente / 10)))
		local espaco = larguraFrente / (nj + 1)
		for a = 1, spec.andares do
			for jn = 1, nj do
				local lat = (jn - (nj + 1) / 2) * espaco
				if not (a == 1 and abs(lat) < 5) then
					naFrente(lat, (a - 1) * C.alturaAndar + C.alturaAndar * 0.62, 3.2, 3.4, "Janela", COR.janela)
				end
			end
		end
	end

	if spec.torre then
		local tx, tz = cx + w / 2 - 4, cz + d / 2 - 4
		criar(m, "Torre", tx, base + 15, tz, 8, 30, 8, escurecer(spec.cor, 0.9), spec.material)
		criar(m, "Cabine", tx, base + 31.5, tz, 13, 3, 13, spec.cor, spec.material)
		criar(m, "TetoCabine", tx, base + 33.4, tz, 14.4, 0.8, 14.4, escurecer(spec.cor, 0.55), "Concrete")
	end

	m.PrimaryPart = corpo;
	(m :: any).ModelStreamingMode = (Enum :: any).ModelStreamingMode.Atomic
	m.Parent = pastas.Construcoes

	local ext = 0.6
	local extra = if spec.torre then 0 else 0
	inserirObstaculo(cx - w / 2 - ext - extra, cx + w / 2 + ext + extra, cz - d / 2 - ext, cz + d / 2 + ext)
	table.insert(construcoes, {
		tipo = spec.tipo,
		zona = spec.zona,
		cx = cx,
		cz = cz,
		w = w,
		d = d,
		loot = spec.loot,
	})
	return m
end

local function tipoPorNome(nome: string)
	for _, t in C.tipos do
		if t.tipo == nome then
			return t
		end
	end
	error("tipo desconhecido em Mundo.cidade.tipos: " .. nome)
end

local function especDoTipo(def, zona: string, base: number)
	return {
		tipo = def.tipo,
		zona = zona,
		andares = inteiro(def.andares[1], def.andares[2]),
		base = base,
		material = def.material,
		cor = variar(COR[def.tipo], 0.1),
	}
end

-- Cidade: 2–6 construções por lote, coladas numa das bordas do lote (a frente dá para a rua/calçada)
local FRENTES = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } -- lado 1 = -Z, 2 = +Z, 3 = -X, 4 = +X
for _, lote in lotes do
	local alvo = inteiro(2, 6)
	local colocados = {}
	local feitos = 0
	local tentativas = 0
	while feitos < alvo and tentativas < alvo * 40 do
		tentativas += 1
		local def = sortearPeso(C.tipos)
		local lado = inteiro(1, 4)
		local w, d = def.tamanho[1], def.tamanho[2]
		if lado >= 3 then
			w, d = d, w
		end
		local lx, lz -- relativos ao centro do lote
		local limX, limZ = meiaLote - RECUO_LOTE - w / 2, meiaLote - RECUO_LOTE - d / 2
		if lado == 1 then
			lx, lz = entre(-limX, limX), -meiaLote + RECUO_LOTE + d / 2
		elseif lado == 2 then
			lx, lz = entre(-limX, limX), meiaLote - RECUO_LOTE - d / 2
		elseif lado == 3 then
			lx, lz = -meiaLote + RECUO_LOTE + w / 2, entre(-limZ, limZ)
		else
			lx, lz = meiaLote - RECUO_LOTE - w / 2, entre(-limZ, limZ)
		end
		local livre = true
		for _, o in colocados do
			if
				abs(lx - o.lx) < (w + o.w) / 2 + FOLGA_ENTRE_CONSTRUCOES
				and abs(lz - o.lz) < (d + o.d) / 2 + FOLGA_ENTRE_CONSTRUCOES
			then
				livre = false
				break
			end
		end
		if livre then
			feitos += 1
			table.insert(colocados, { lx = lx, lz = lz, w = w, d = d })
			local frente = FRENTES[lado]
			local spec = especDoTipo(def, "cidade", NIVEL_LOTE)
			spec.cx, spec.cz, spec.w, spec.d = lote.cx + lx, lote.cz + lz, w, d
			spec.frente = frente
			-- loot na calçada, em frente à porta
			local anel = meiaLote + C.calcada / 2
			if lado <= 2 then
				spec.loot = { spec.cx, lote.cz + frente[2] * anel }
			else
				spec.loot = { lote.cx + frente[1] * anel, spec.cz }
			end
			construir(spec)
		end
	end
end

-- Vilas: 12 casas e um posto em volta do cruzamento; frente das casas para a rua mais próxima
local spawnsPlanejados = {}
for i, v in Mundo.vilas do
	local cx, cz = v.centro[1], v.centro[2]
	local limite = v.lado / 2 - 8
	local colocados = {}
	local function livreVila(rx: number, rz: number, w: number, d: number): boolean
		for _, o in colocados do
			if
				abs(rx - o.rx) < (w + o.w) / 2 + FOLGA_ENTRE_CONSTRUCOES
				and abs(rz - o.rz) < (d + o.d) / 2 + FOLGA_ENTRE_CONSTRUCOES
			then
				return false
			end
		end
		return true
	end
	local function colocar(def, rx: number, rz: number, w: number, d: number, frente)
		table.insert(colocados, { rx = rx, rz = rz, w = w, d = d })
		local spec = especDoTipo(def, "vila", NIVEL_PAD)
		spec.cx, spec.cz, spec.w, spec.d = cx + rx, cz + rz, w, d
		spec.frente = frente
		spec.local_ = v.nome
		local prof = if frente[2] ~= 0 then d else w
		spec.loot = { spec.cx + frente[1] * (prof / 2 + 3.5), spec.cz + frente[2] * (prof / 2 + 3.5) }
		construir(spec)
	end

	if v.posto then
		local def = tipoPorNome("posto")
		local quadrantes = { { 1, 1 }, { -1, -1 }, { 1, -1 } }
		local q = quadrantes[(i - 1) % #quadrantes + 1]
		local w, d = def.tamanho[1], def.tamanho[2]
		local rx = q[1] * (VIA_VILA / 2 + 10 + w / 2)
		local rz = q[2] * (VIA_VILA / 2 + 8 + d / 2)
		colocar(def, rx, rz, w, d, { 0, -q[2] })
	end

	local casa = tipoPorNome("casa")
	local feitas, tentativas = 0, 0
	while feitas < v.casas and tentativas < 30000 do
		tentativas += 1
		local frenteEmZ = rnd() < 0.5
		local w, d = casa.tamanho[1], casa.tamanho[2]
		if not frenteEmZ then
			w, d = d, w
		end
		local sx, sz = sinal(), sinal()
		local folga = 8 + rnd() * 10
		local rx, rz, frente
		if frenteEmZ then
			rz = sz * (VIA_VILA / 2 + folga + d / 2)
			rx = sx * entre(VIA_VILA / 2 + 8 + w / 2, limite - w / 2)
			frente = { 0, -sz }
		else
			rx = sx * (VIA_VILA / 2 + folga + w / 2)
			rz = sz * entre(VIA_VILA / 2 + 8 + d / 2, limite - d / 2)
			frente = { -sx, 0 }
		end
		if abs(rx) + w / 2 <= limite and abs(rz) + d / 2 <= limite and livreVila(rx, rz, w, d) then
			colocar(casa, rx, rz, w, d, frente)
			feitas += 1
		end
	end
	assert(feitas == v.casas, "não coube todas as casas em " .. v.nome)

	-- spawns: chão livre, longe de construções
	local sp = {}
	local tent = 0
	while #sp < Mundo.spawnsPorVila and tent < 2000 do
		tent += 1
		local x, z = cx + entre(-limite, limite), cz + entre(-limite, limite)
		local ok = not ocupado(x, z, 14)
		if ok then
			for _, o in sp do
				if abs(o[1] - x) < 20 and abs(o[2] - z) < 20 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(sp, { x, z })
		end
	end
	assert(#sp == Mundo.spawnsPorVila, "spawns insuficientes em " .. v.nome)
	for _, p in sp do
		table.insert(spawnsPlanejados, { x = p[1], z = p[2], vila = v.nome })
	end
end

-- Fábrica: galpões de metal em 2×2 em volta do corredor central
do
	local F = Mundo.fabrica
	local def = { tipo = "galpao", andares = { 1, 1 }, material = F.material }
	local gw, gd = 70, 50
	local k = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k += 1
			if k <= F.galpoes then
				local rx, rz = sx * (gw / 2 + 25), sz * (gd / 2 + 25)
				local spec = especDoTipo(def, "fabrica", NIVEL_PAD)
				spec.cx, spec.cz, spec.w, spec.d = F.centro[1] + rx, F.centro[2] + rz, gw, gd
				spec.altura = inteiro(16, 20)
				spec.frente = { 0, -sz }
				spec.local_ = "Fabrica"
				spec.loot = { spec.cx, spec.cz + -sz * (gd / 2 + 3.5) }
				construir(spec)
			end
		end
	end
end

-- Posto da guarda florestal: casa de madeira com torre, frente para o norte (a avenida chega por lá)
do
	local G = Mundo.guardaFlorestal
	local spec = {
		tipo = "guarda",
		zona = "guarda",
		andares = 1,
		base = NIVEL_PAD,
		material = G.material,
		cor = variar(COR.guardaPredio, 0.05),
		cx = G.centro[1],
		cz = G.centro[2],
		w = G.tamanho[1],
		d = G.tamanho[2],
		frente = { 0, -1 },
		torre = G.torre,
		local_ = "PostoGuarda",
	}
	spec.loot = { spec.cx, spec.cz - (spec.d / 2 + 3.5) }
	construir(spec)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Manchas de LeafyGrass (+5 dB nos passos)
-- ---------------------------------------------------------------------------------------------------------------
local nManchas = 0
local function mancha(x0: number, x1: number, z0: number, z1: number, tolerarObstaculo: boolean?): boolean
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local base = topoEm(cx, cz)
	if not base then
		return false
	end
	for _, pt in { { x0, z0 }, { x0, z1 }, { x1, z0 }, { x1, z1 } } do
		if topoEm(pt[1], pt[2]) ~= base then
			return false
		end
	end
	if not tolerarObstaculo and retanguloOcupado(x0, x1, z0, z1, 3) then
		return false
	end
	local topo = base + 0.15
	criar(
		pastas.Vegetacao,
		"Mancha",
		cx,
		topo - 0.15,
		cz,
		x1 - x0,
		0.3,
		z1 - z0,
		variar(COR.manchaAlta, 0.12),
		"LeafyGrass",
		{ consulta = true }
	)
	table.insert(superficies, { x0 = x0, x1 = x1, z0 = z0, z1 = z1, topo = topo })
	nManchas += 1
	return true
end

-- Cidade: terrenos baldios dentro dos lotes
do
	local feitas, tent = 0, 0
	while feitas < C.gramaAltaManchas and tent < C.gramaAltaManchas * 200 do
		tent += 1
		local lote = lotes[inteiro(1, #lotes)]
		local tam = entre(8, 18)
		local x = lote.cx + entre(-meiaLote + 2, meiaLote - 2 - tam)
		local z = lote.cz + entre(-meiaLote + 2, meiaLote - 2 - tam)
		if mancha(x, x + tam, z, z + tam) then
			feitas += 1
		end
	end
end

-- Planície e floresta: uma mancha possível por célula da grade, com probabilidade tal que a fração coberta bata
local function manchasEmGrade(
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	fracao: number,
	celula: number,
	tamMin: number,
	tamMax: number,
	aceitar
)
	local tamMedio = (tamMin + tamMax) / 2
	local p = min(1, fracao / ((tamMedio / celula) ^ 2))
	local x = x0
	while x + celula <= x1 do
		local z = z0
		while z + celula <= z1 do
			if rnd() < p then
				local tx, tz = entre(tamMin, tamMax), entre(tamMin, tamMax)
				local px, pz = x + entre(0, celula - tx), z + entre(0, celula - tz)
				if aceitar(px, px + tx, pz, pz + tz) then
					mancha(px, px + tx, pz, pz + tz)
				end
			end
			z += celula
		end
		x += celula
	end
end

manchasEmGrade(
	planiciRet[1],
	planiciRet[2],
	planiciRet[3],
	planiciRet[4],
	Mundo.planicie.gramaAlta,
	60,
	30,
	50,
	function()
		return true
	end
)
manchasEmGrade(-mt + 40, mt - 40, -mt + 40, mt - 40, Mundo.floresta.gramaAlta, 80, 50, 72, function(ax0, ax1, az0, az1)
	for _, pt in { { ax0, az0 }, { ax0, az1 }, { ax1, az0 }, { ax1, az1 } } do
		if emAreaConstruida(pt[1], pt[2], 6) or dentro(planiciRet, pt[1], pt[2], 6) then
			return false
		end
	end
	return true
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Árvores: aglomerados + dispersas, distância mínima, nunca em área construída/avenida/planície
-- ---------------------------------------------------------------------------------------------------------------
local nArvores = 0
do
	local F = Mundo.floresta
	local celula = F.distanciaMinima
	local hash = {}
	local function chave(i: number, j: number): number
		return (i + 1000) * 10000 + (j + 1000)
	end
	local function longeDeArvores(x: number, z: number): boolean
		local ci, cj = floor(x / celula), floor(z / celula)
		for i = ci - 1, ci + 1 do
			for j = cj - 1, cj + 1 do
				local l = hash[chave(i, j)]
				if l then
					for _, a in l do
						local dx, dz = a[1] - x, a[2] - z
						if dx * dx + dz * dz < F.distanciaMinima * F.distanciaMinima then
							return false
						end
					end
				end
			end
		end
		return true
	end
	local function valido(x: number, z: number): boolean
		if abs(x) > mt - 30 or abs(z) > mt - 30 then
			return false
		end
		if emAreaConstruida(x, z, 14) or dentro(planiciRet, x, z, 10) then
			return false
		end
		return longeDeArvores(x, z)
	end

	-- centros de aglomerado (bosques)
	local centros = {}
	local tent = 0
	while #centros < 60 and tent < 5000 do
		tent += 1
		local x, z = entre(-mt + 100, mt - 100), entre(-mt + 100, mt - 100)
		if not emAreaConstruida(x, z, 30) and not dentro(planiciRet, x, z, 30) then
			table.insert(centros, { x, z })
		end
	end

	local tentativas = 0
	while nArvores < F.arvores and tentativas < F.arvores * 60 do
		tentativas += 1
		local x, z
		if rnd() < 0.8 and #centros > 0 then
			local c = centros[inteiro(1, #centros)]
			local raio = 60 + 140 * rnd()
			local ang = rnd() * math.pi * 2
			local r = raio * (rnd() + rnd()) / 2
			x, z = c[1] + math.cos(ang) * r, c[2] + math.sin(ang) * r
		else
			x, z = entre(-mt, mt), entre(-mt, mt)
		end
		if valido(x, z) then
			nArvores += 1
			local h = entre(F.alturaTronco[1], F.alturaTronco[2])
			local esp = entre(1.4, 2.0)
			criar(pastas.Vegetacao, "Tronco", x, h / 2 - 0.2, z, esp, h + 0.4, esp, variar(COR.tronco, 0.12), "Wood")
			local cw, ch = entre(8, 13), entre(7, 11)
			criar(
				pastas.Vegetacao,
				"Copa",
				x,
				h + ch * 0.3,
				z,
				cw,
				ch,
				cw,
				variar(COR.copa, 0.15),
				"Grass",
				{ colide = false, consulta = false, rotY = rnd() * math.pi }
			)
			local ci, cj = floor(x / celula), floor(z / celula)
			local k = chave(ci, cj)
			hash[k] = hash[k] or {}
			table.insert(hash[k], { x, z })
			inserirObstaculo(x - esp / 2, x + esp / 2, z - esp / 2, z + esp / 2)
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Bordas (muros invisíveis) e Zonas (invisíveis, sem consulta para não parar raycast)
-- ---------------------------------------------------------------------------------------------------------------
do
	local esp = 4
	local alt = Mundo.muroBorda
	local cy = alt / 2 - 5
	local opc = { transparencia = 1, consulta = false }
	local meio = mt + esp / 2
	local comp = Mundo.tamanho / 2 + esp
	for _, s in { -1, 1 } do
		-- paredes Norte/Sul (ao longo de X) em duas metades; Leste/Oeste (ao longo de Z) em duas metades
		for _, metade in { -1, 1 } do
			criar(
				pastas.Bordas,
				"Borda_Z" .. (if s < 0 then "n" else "p") .. (if metade < 0 then "1" else "2"),
				metade * comp / 2,
				cy,
				s * meio,
				comp,
				alt,
				esp,
				COR.borda,
				"SmoothPlastic",
				opc
			)
			criar(
				pastas.Bordas,
				"Borda_X" .. (if s < 0 then "n" else "p") .. (if metade < 0 then "1" else "2"),
				s * meio,
				cy,
				metade * (Mundo.tamanho / 2) / 2,
				esp,
				alt,
				Mundo.tamanho / 2,
				COR.borda,
				"SmoothPlastic",
				opc
			)
		end
	end
end

local function zona(nome: string, chave: string, cx: number, cz: number, lx: number, lz: number)
	local p = criar(pastas.Zonas, "Zona_" .. nome, cx, 100, cz, lx, 300, lz, COR.borda, "SmoothPlastic", {
		transparencia = 1,
		colide = false,
		consulta = false,
	})
	p:SetAttribute("Zona", chave)
	p:SetAttribute("Nome", nome)
end
zona("Cidade", "cidade", 0, 0, areas.cidade[2] * 2, areas.cidade[4] * 2)
for i, v in Mundo.vilas do
	zona(v.nome, "vila", v.centro[1], v.centro[2], v.lado, v.lado)
	assert(vilasRet[i])
end
zona(
	"Fabrica",
	"fabrica",
	Mundo.fabrica.centro[1],
	Mundo.fabrica.centro[2],
	Mundo.fabrica.tamanho[1],
	Mundo.fabrica.tamanho[2]
)
zona(
	"Planicie",
	"planicie",
	Mundo.planicie.centro[1],
	Mundo.planicie.centro[2],
	Mundo.planicie.lado,
	Mundo.planicie.lado
)
zona("PostoGuarda", "guarda", Mundo.guardaFlorestal.centro[1], Mundo.guardaFlorestal.centro[2], PAD_GUARDA, PAD_GUARDA)
-- floresta: fundo do mapa inteiro (4 quadrantes de 2000); as zonas acima se sobrepõem a ela
for k, q in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
	zona("Floresta_" .. k, "floresta", q[1] * mt / 2, q[2] * mt / 2, mt, mt)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Pontos: Spawn, Loot, Monstro (Parts 1×1×1 invisíveis, Y = topo + 0.5)
-- ---------------------------------------------------------------------------------------------------------------
local contagemPontos = { Spawn = 0, Loot = 0, Monstro = 0 }
local contagemMonstro = {}
local function ponto(nome: string, x: number, z: number, atributos)
	local topo = topoEm(x, z)
	assert(topo, string.format("ponto %s fora do chão (%.1f, %.1f)", nome, x, z))
	local p = criar(pastas.Pontos, nome, x, topo + 0.5, z, 1, 1, 1, COR.borda, "SmoothPlastic", {
		transparencia = 1,
		colide = false,
		consulta = false,
	})
	for k, v in atributos do
		p:SetAttribute(k, v)
	end
	contagemPontos[nome] += 1
	return p
end

for _, s in spawnsPlanejados do
	ponto("Spawn", s.x, s.z, { Zona = s.vila })
end

for _, c in construcoes do
	local tabela = TABELA_POR_TIPO[c.tipo]
	assert(Itens.tabelas[tabela], "tabela de loot inexistente: " .. tostring(tabela))
	for _ = 1, Mundo.pontosLootPorConstrucao do
		ponto("Loot", c.loot[1], c.loot[2], { Tabela = tabela, Zona = c.zona })
	end
end

-- Monstros: um por célula de densidade (lado = Config/Monstros.densidade[zona]), em chão livre
local function monstrosEm(chave: string, r, aceitar)
	local lado = Monstros.densidade[chave]
	assert(lado, "Config/Monstros.densidade sem a chave " .. chave)
	local cx = r[1]
	while cx < r[2] do
		local cz = r[3]
		while cz < r[4] do
			for _ = 1, 40 do
				local x = entre(cx, min(cx + lado, r[2]))
				local z = entre(cz, min(cz + lado, r[4]))
				if aceitar(x, z) and not ocupado(x, z, 3) then
					ponto("Monstro", x, z, { Zona = chave })
					contagemMonstro[chave] = (contagemMonstro[chave] or 0) + 1
					break
				end
			end
			cz += lado
		end
		cx += lado
	end
end

local sempre = function()
	return true
end
monstrosEm("cidade", areas.cidade, sempre)
for _, r in vilasRet do
	monstrosEm("vila", r, sempre)
end
monstrosEm("fabrica", fabricaRet, sempre)
monstrosEm("outros", planiciRet, sempre)
monstrosEm("outros", guardaRet, sempre)
monstrosEm("floresta", { -mt + 20, mt - 20, -mt + 20, mt - 20 }, function(x, z)
	return zonaEm(x, z) == "floresta" and not emAreaConstruida(x, z, 4)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- Contagem, orçamento e gravação
-- ---------------------------------------------------------------------------------------------------------------
local total = 0
local linhas = {}
for _, nome in { "Chao", "Ruas", "Construcoes", "Vegetacao", "Bordas", "Zonas", "Pontos" } do
	local n = 0
	for _, d in pastas[nome]:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	total += n
	table.insert(linhas, string.format("  %-12s %6d peças", nome, n))
end

fs.writeFile("build/mapa_v1_legado.rbxm", roblox.serializeModel({ mapa }))
print("build/mapa_v1_legado.rbxm gerado, LEGADO v1, não é o mapa oficial (semente " .. tostring(Mundo.semente) .. ")")
print(table.concat(linhas, "\n"))
print(string.format("  %-12s %6d peças (limite %d)", "TOTAL", total, LIMITE_PECAS))
print(
	string.format(
		"  construções %d | árvores %d | manchas LeafyGrass %d | pontos: Spawn %d, Loot %d, Monstro %d",
		#construcoes,
		nArvores,
		nManchas,
		contagemPontos.Spawn,
		contagemPontos.Loot,
		contagemPontos.Monstro
	)
)
local partes = {}
for chave, n in contagemMonstro do
	table.insert(partes, chave .. "=" .. n)
end
table.sort(partes)
print("  Monstro por zona: " .. table.concat(partes, ", "))
if total > LIMITE_PECAS then
	error(string.format("passou do orçamento: %d > %d peças", total, LIMITE_PECAS))
end
