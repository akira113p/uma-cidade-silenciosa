-- Mobília doméstica (dono "casa" em mobilia_tamanhos): quarto, sala, cozinha, banheiro, escritório, decoração, garagem.
-- Contrato em docs/mapa-v2.md §6: cada função cria um Model (Movel = nome) filho de `pai`; frente −Z; origem no centro da
-- pegada, no piso (parede: face da parede, sai para −Z; teto: origem no teto, pendura). Só cor + Material, sem textura.
-- Linguagem visual: pé quadrado de madeira escura, puxador de metal fino, frente de gaveta/porta 0,06 saliente do corpo.

local roblox = require("@lune/roblox")
local TAM = require("./mobilia_tamanhos")

local Instance = roblox.Instance
local CFrame = roblox.CFrame

local min, max, floor, abs, pi, sin, cos = math.min, math.max, math.floor, math.abs, math.pi, math.sin, math.cos

-- Paleta compartilhada (dessaturada, noite)
local P = {
	madeira = { 110, 80, 60 },
	madeiraEsc = { 78, 56, 44 },
	madeiraCl = { 150, 120, 90 },
	branco = { 200, 200, 205 },
	ceramica = { 206, 206, 208 },
	esmalte = { 186, 190, 194 },
	inox = { 150, 152, 156 },
	cromo = { 175, 178, 182 },
	puxador = { 168, 170, 174 },
	ferro = { 58, 58, 62 },
	preto = { 32, 32, 35 },
	borracha = { 30, 30, 32 },
	marmore = { 150, 150, 152 },
	colchao = { 96, 110, 128 },
	coberta = { 110, 96, 92 },
	travesseiro = { 176, 174, 168 },
	tecido = { 104, 88, 72 },
	tecidoCl = { 124, 108, 88 },
	folha = { 58, 84, 52 },
	terracota = { 128, 76, 56 },
	abajur = { 176, 164, 134 },
	latao = { 130, 106, 62 },
	vidroEsc = { 22, 28, 30 },
	papel = { 196, 190, 170 },
	papelao = { 148, 116, 80 },
	pedra = { 118, 114, 108 },
	vermelho = { 140, 50, 40 },
	livros = { { 110, 50, 44 }, { 60, 76, 96 }, { 70, 92, 66 }, { 128, 112, 70 }, { 90, 66, 92 }, { 70, 60, 54 } },
}

local DET = { consulta = false, sombra = false } -- detalhe pequeno
local DETC = { consulta = false, sombra = false, colide = false } -- detalhe pequeno que não deve prender o jogador
local FINO = { consulta = false, colide = false } -- cortina, tapete, quadro

local function mul(c, k: number)
	return { min(255, c[1] * k), min(255, c[2] * k), min(255, c[3] * k) }
end

-- Kit de construção: modelo + atalhos que já usam ctx, cf e o modelo como pai.
local function kit(ctx, pai, cf, nome: string)
	local m = Instance.new("Model")
	m.Name = nome
	m:SetAttribute("Movel", nome)
	m.Parent = pai
	local k = { m = m }
	function k.b(n, cx, cy, cz, sx, sy, sz, cor, mat, o)
		return ctx.bloco(m, cf, n, cx, cy, cz, sx, sy, sz, cor, mat, o)
	end
	function k.c(n, cx, cy, cz, dia, len, cor, mat, o)
		return ctx.cilindro(m, cf, n, cx, cy, cz, dia, len, cor, mat, o)
	end
	function k.e(n, cx, cy, cz, dia, cor, mat, o)
		return ctx.esfera(m, cf, n, cx, cy, cz, dia, cor, mat, o)
	end
	function k.r(n, x0, y0, z0, x1, y1, z1, larg, esp, cor, mat, o)
		return ctx.rampa(m, cf, n, x0, y0, z0, x1, y1, z1, larg, esp, cor, mat, o)
	end
	return k
end

local M = {}

-- def: registra a peça; resolve w/h/d (var) e op nulo
local function def(nome: string, f)
	local t = TAM[nome]
	assert(t, "mobilia_casa: peça fora de mobilia_tamanhos: " .. nome)
	M[nome] = function(ctx, pai, cf, op)
		op = op or {}
		local k = kit(ctx, pai, cf, nome)
		local w = if t.var and op.w then op.w else t.w
		local h = if t.var and op.h then op.h else t.h
		local d = if t.var and op.d then op.d else t.d
		f(k, w, h, d, op, ctx)
		return k.m
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Peças de linguagem comum
-- ---------------------------------------------------------------------------------------------------------------
local FR = 0.12 -- recuo da frente do corpo; frente de gaveta/porta ocupa [zf+0.06, zf+0.12], puxador [zf, zf+0.1]

-- quatro pés quadrados de madeira escura em (±px, ±pz)
local function pes(k, px: number, pz: number, h: number, sec: number, cor)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Pe", sx * px, h / 2, sz * pz, sec, h, sec, cor or P.madeiraEsc, "Wood")
		end
	end
end

-- puxador de metal fino na frente (zf = −d/2)
local function pux(k, x: number, y: number, zf: number, len: number, vertical: boolean?)
	if vertical then
		k.b("Puxador", x, y, zf + 0.05, 0.12, len, 0.1, P.puxador, "Metal", DETC)
	else
		k.b("Puxador", x, y, zf + 0.05, len, 0.12, 0.1, P.puxador, "Metal", DETC)
	end
end

local function gaveta(k, cx: number, cy: number, sx: number, sy: number, zf: number, cor, lenPux: number?)
	k.b("Gaveta", cx, cy, zf + 0.09, sx, sy, 0.06, cor, "Wood")
	pux(k, cx, cy, zf, lenPux or 0.5)
end

local function porta(k, cx: number, cy: number, sx: number, sy: number, zf: number, cor, xPux: number)
	k.b("Porta", cx, cy, zf + 0.09, sx, sy, 0.06, cor, "Wood")
	pux(k, xPux, cy, zf, min(0.9, sy * 0.4), true)
end

local function corpo(k, cx: number, y0: number, y1: number, w: number, d: number, cor, mat: string?)
	k.b("Corpo", cx, (y0 + y1) / 2, FR / 2, w, y1 - y0, d - FR, cor, mat or "Wood")
end

-- mesa genérica (jantar, cozinha): tampo, 4 pés quadrados, travessas
local function mesa(k, w: number, h: number, d: number, corTopo, corPe, caminho)
	local e = 0.25
	k.b("Tampo", 0, h - 0.04 - e / 2, 0, w, e, d, corTopo, "Wood")
	local lx, lz = w / 2 - 0.4, d / 2 - 0.4
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Pe", sx * lx, (h - 0.04 - e) / 2, sz * lz, 0.4, h - 0.04 - e, 0.4, corPe, "Wood")
		end
	end
	local yt = h - 0.04 - e - 0.2
	k.b("Travessa", 0, yt, -lz, 2 * lx - 0.4, 0.4, 0.2, corPe, "Wood")
	k.b("Travessa", 0, yt, lz, 2 * lx - 0.4, 0.4, 0.2, corPe, "Wood")
	k.b("Travessa", -lx, yt, 0, 0.2, 0.4, 2 * lz - 0.4, corPe, "Wood")
	k.b("Travessa", lx, yt, 0, 0.2, 0.4, 2 * lz - 0.4, corPe, "Wood")
	if caminho then
		k.b("Caminho", 0, h - 0.02, 0, w * 0.55, 0.04, min(1.1, d * 0.3), caminho, "Fabric", FINO)
	end
end

-- espelho de parede: moldura + vidro (fixo na parede, sai para −Z)
local function espelho(k, w: number, h: number, corMoldura, rachado: boolean?)
	k.b("Moldura", 0, h / 2, -0.12, w, h, 0.24, corMoldura, "Wood", DET)
	k.b(
		"Vidro",
		0,
		h / 2,
		-0.27,
		w - 0.5,
		h - 0.5,
		0.06,
		{ 150, 162, 168 },
		"Metal",
		{ refletancia = 0.35, sombra = false }
	)
	k.b("Ornamento", 0, h - 0.125, -0.27, w * 0.45, 0.25, 0.06, mul(corMoldura, 1.15), "Wood", DETC)
	if rachado then
		k.b("Rachadura", 0.25, h / 2, -0.295, 0.04, h * 0.5, 0.01, { 215, 220, 222 }, "SmoothPlastic", {
			consulta = false,
			sombra = false,
			colide = false,
			rot = CFrame.Angles(0, 0, 0.45),
		})
		k.b("Rachadura", -0.2, h / 2 + 0.25, -0.295, 0.04, h * 0.3, 0.01, { 215, 220, 222 }, "SmoothPlastic", {
			consulta = false,
			sombra = false,
			colide = false,
			rot = CFrame.Angles(0, 0, -0.9),
		})
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- QUARTO
-- ---------------------------------------------------------------------------------------------------------------
local function cama(nome: string, nTrav: number)
	def(nome, function(k, w, h, d, op)
		local mad = op.cor or P.madeira
		local col = op.cor2 or P.colchao
		local cob = op.cor3 or P.coberta
		local zh = d / 2
		local ew = w - 0.5
		k.b("Cabeceira", 0, h / 2, zh - 0.25, w, h, 0.5, mad, "Wood")
		k.b("Peseira", 0, 0.8, -zh + 0.2, w, 1.6, 0.4, mad, "Wood")
		k.b("Estrado", 0, 0.7, 0, ew, 0.9, d - 0.8, P.madeiraEsc, "Wood")
		k.b("Colchao", 0, 1.45, 0, ew - 0.1, 0.6, d - 1.0, col, "Fabric")
		local csz = (d - 1.0) * 0.6
		k.b("Coberta", 0, 1.85, -(d - 1.0) / 2 + csz / 2, ew, 0.3, csz, cob, "Fabric")
		for i = 1, nTrav do
			local pw = min(1.9, (ew - 0.6) / nTrav - 0.2)
			local px = (i - (nTrav + 1) / 2) * (pw + 0.3)
			k.b("Travesseiro", px, 2.0, zh - 1.15, pw, 0.5, 1.1, P.travesseiro, "Fabric")
		end
	end)
end
cama("cama_casal", 2)
cama("cama_solteiro", 1)

def("beliche", function(k, w, h, d, op)
	local mad = op.cor or P.madeira
	local col = op.cor2 or P.colchao
	local px, pz = w / 2 - 0.2, d / 2 - 0.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Poste", sx * px, h / 2, sz * pz, 0.4, h, 0.4, mad, "Wood")
		end
	end
	for _, y in { 1.0, 3.9 } do
		k.b("Estrado", 0, y, 0, w - 0.8, 0.3, d - 0.8, P.madeiraEsc, "Wood")
		k.b("Colchao", 0, y + 0.45, 0, w - 0.8, 0.6, d - 0.8, col, "Fabric")
		k.b("Travesseiro", 0, y + 0.95, pz - 0.7, 1.5, 0.4, 0.9, P.travesseiro, "Fabric")
	end
	-- grades do beliche de cima: lateral inteira de um lado, metade do outro (entrada)
	k.b("Grade", -px, 5.2, 0, 0.2, 0.5, d - 0.9, mad, "Wood")
	k.b("Grade", px, 5.2, pz / 2 - 0.1, 0.2, 0.5, pz - 0.3, mad, "Wood")
	for _, y in { 2.0, 2.8, 3.6 } do
		k.b("Degrau", 0, y, -pz, w - 0.8, 0.15, 0.2, mad, "Wood")
	end
end)

def("berco", function(k, w, h, d, op)
	local mad = op.cor or P.madeiraCl
	local zl = d / 2 - 0.15
	local xl = w / 2 - 0.15
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Poste", sx * xl, h / 2, sz * zl, 0.3, h, 0.3, mad, "Wood")
		end
	end
	k.b("Base", 0, 0.95, 0, w - 0.6, 0.3, d - 0.6, P.madeiraEsc, "Wood")
	k.b("Colchao", 0, 1.275, 0, w - 0.7, 0.35, d - 0.7, op.cor2 or { 140, 150, 160 }, "Fabric")
	for _, sx in { -1, 1 } do
		k.b("Trilho", sx * xl, 3.075, 0, 0.2, 0.25, d - 0.6, mad, "Wood")
	end
	for _, sz in { -1, 1 } do
		k.b("Painel", 0, 2.3, sz * zl, w - 0.6, 1.7, 0.2, mad, "Wood")
	end
	for _, sx in { -1, 1 } do
		for _, z in { -1.1, 0, 1.1 } do
			k.b("Grade", sx * xl, 2.025, z, 0.14, 1.85, 0.14, mad, "Wood", DET)
		end
	end
end)

def("criado_mudo", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	pes(k, w / 2 - 0.2, d / 2 - 0.2, 0.4, 0.25)
	corpo(k, 0, 0.4, 1.75, w - 0.1, d, cor)
	k.b("Tampo", 0, 1.825, 0, w, 0.15, d, mul(cor, 0.9), "Wood")
	gaveta(k, 0, 1.4, w - 0.4, 0.55, zf, mul(cor, 1.1), 0.5)
	gaveta(k, 0, 0.8, w - 0.4, 0.55, zf, mul(cor, 1.1), 0.5)
end)

def("guarda_roupa", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	k.b("Rodape", 0, 0.2, 0.05, w - 0.3, 0.4, d - 0.3, P.madeiraEsc, "Wood")
	corpo(k, 0, 0.4, 7.2, w, d, cor)
	k.b("Cornija", 0, 7.35, 0, w, 0.3, d, mul(cor, 0.85), "Wood")
	for _, s in { -1, 1 } do
		local cx = s * (w / 4)
		k.b("Porta", cx, 3.75, zf + 0.09, w / 2 - 0.1, 6.4, 0.06, mul(cor, 1.05), "Wood")
		k.b("Almofada", cx, 3.75, zf + 0.04, w / 2 - 0.8, 5.0, 0.04, mul(cor, 0.9), "Wood", DET)
		pux(k, -s * 0.35, 3.8, zf, 0.9, true)
	end
end)

def("comoda", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	pes(k, w / 2 - 0.25, d / 2 - 0.25, 0.5, 0.3)
	corpo(k, 0, 0.5, 3.0, w - 0.2, d, cor)
	k.b("Tampo", 0, 3.1, 0, w, 0.2, d, mul(cor, 0.9), "Wood")
	for i = 0, 2 do
		gaveta(k, 0, 0.5 + 0.1 + 0.385 + i * 0.77, w - 0.6, 0.7, zf, mul(cor, 1.1), 0.8)
	end
end)

def("penteadeira", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	pes(k, w / 2 - 0.25, d / 2 - 0.25, 2.4, 0.3)
	k.b("Tampo", 0, 2.5, 0, w, 0.2, d, mul(cor, 0.9), "Wood")
	k.b("Corpo", 0, 2.0, 0.06, w - 0.8, 0.8, d - FR, cor, "Wood")
	gaveta(k, 0, 2.0, w - 1.3, 0.55, zf, mul(cor, 1.1), 0.6)
	k.b("Moldura", 0, 4.05, 0.8, 3.0, 2.9, 0.2, cor, "Wood")
	k.b("Vidro", 0, 4.1, 0.675, 2.6, 2.4, 0.05, { 150, 162, 168 }, "Metal", { refletancia = 0.35, sombra = false })
	k.b("Frasco", -1.2, 2.9, 0.2, 0.35, 0.6, 0.35, { 120, 150, 140 }, "Glass", DETC)
	k.b("Caixinha", 1.1, 2.7, 0.0, 0.8, 0.3, 0.5, P.latao, "Metal", DETC)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- SALA
-- ---------------------------------------------------------------------------------------------------------------
local function sofa(nome: string, nAss: number)
	def(nome, function(k, w, h, d, op)
		local cor = op.cor or P.tecido
		local cor2 = op.cor2 or P.tecidoCl
		local cor3 = op.cor3 or P.coberta
		local var = op.variante or 1
		local zf = -d / 2
		local braco = if w > 4 then 0.8 else 0.6
		local iw = w - 2 * braco
		pes(k, w / 2 - 0.25, d / 2 - 0.25, 0.3, 0.3)
		k.b("Base", 0, 0.85, 0, iw, 1.1, d, cor, "Fabric")
		for _, s in { -1, 1 } do
			k.b("Braco", s * (w / 2 - braco / 2), 1.25, 0, braco, 1.9, d, cor, "Fabric")
		end
		k.b("Encosto", 0, 2.15, d / 2 - 0.4, iw, 1.5, 0.8, cor, "Fabric")
		if var == 1 then
			local cw = iw / nAss
			local sz = d - 0.85
			for i = 1, nAss do
				local x = (i - (nAss + 1) / 2) * cw
				k.b("Almofada", x, 1.65, -d / 2 + sz / 2, cw - 0.06, 0.5, sz, cor2, "Fabric")
				k.b("AlmofadaCostas", x, 2.35, d / 2 - 1.0, cw - 0.06, 0.9, 0.5, cor2, "Fabric")
			end
			if nAss >= 2 then
				k.b("Almofadinha", -iw / 2 + 0.6, 2.3, d / 2 - 1.0 - 0.45, 0.9, 0.9, 0.3, cor3, "Fabric", DET)
			end
		else
			k.b("Assento", 0, 1.65, -d / 2 + (d - 0.85) / 2, iw - 0.1, 0.5, d - 0.85, cor2, "Fabric")
			k.b("Manta", iw * 0.15, 1.93, -0.2, min(2.6, iw * 0.5), 0.1, 1.4, cor3, "Fabric", FINO)
		end
	end)
end
sofa("sofa", 3)
sofa("sofa_pequeno", 2)
sofa("poltrona", 1)

def("mesa_centro", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	pes(k, w / 2 - 0.3, d / 2 - 0.3, 0.95, 0.3)
	k.b("Tampo", 0, 1.05, 0, w, 0.2, d, cor, "Wood")
	k.b("Prateleira", 0, 0.4, 0, w - 0.9, 0.1, d - 0.9, P.madeiraEsc, "Wood")
	k.b("Livro", 0.7, 1.21, 0.1, 1.0, 0.12, 0.7, P.livros[1], "Fabric", DETC)
	k.b(
		"Livro",
		0.75,
		1.33,
		0.1,
		0.8,
		0.12,
		0.6,
		P.livros[2],
		"Fabric",
		{ consulta = false, sombra = false, colide = false, rotY = 0.3 }
	)
	k.b("Caneca", -0.9, 1.25, -0.2, 0.4, 0.3, 0.4, P.branco, "SmoothPlastic", DETC)
end)

def("estante_livros", function(k, w, h, d, op, ctx)
	local cor = op.cor or P.madeira
	local rng = op.rng or ctx.rng("mobilia_casa_estante")
	k.b("Fundo", 0, h / 2, d / 2 - 0.05, w, h, 0.1, mul(cor, 0.7), "Wood")
	for _, s in { -1, 1 } do
		k.b("Lateral", s * (w / 2 - 0.125), h / 2, 0, 0.25, h, d, cor, "Wood")
	end
	k.b("Topo", 0, h - 0.15, 0, w, 0.3, d, cor, "Wood")
	k.b("Base", 0, 0.2, 0, w - 0.5, 0.4, d - 0.1, mul(cor, 0.8), "Wood")
	local n = max(3, floor(h / 1.75 + 0.5))
	local yb, yt = 0.4, h - 0.3
	local passo = (yt - yb) / n
	local iw = w - 0.5
	for i = 1, n - 1 do
		k.b("Prateleira", 0, yb + i * passo, 0, iw, 0.15, d - 0.1, cor, "Wood")
	end
	local grupos = if n <= 4 then 2 else 1
	for i = 0, n - 1 do
		local ytopo = yb + i * passo + (if i > 0 then 0.075 else 0)
		local livre = passo - 0.25
		for g = 1, grupos do
			local gw = iw * rng.entre(0.22, 0.32)
			local gh = livre * rng.entre(0.65, 0.92)
			local x = if g == 1 then -iw / 2 + 0.1 + gw / 2 else iw / 2 - 0.1 - gw / 2 - rng.entre(0, 0.4)
			k.b("Livros", x, ytopo + gh / 2, 0, gw, gh, d - 0.45, rng.escolher(P.livros), "Fabric", DET)
		end
	end
end)

def("movel_tv", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	pes(k, w / 2 - 0.3, d / 2 - 0.3, 0.4, 0.3)
	corpo(k, 0, 0.4, 2.1, w, d, cor)
	k.b("Tampo", 0, 2.175, 0, w, 0.15, d, mul(cor, 0.9), "Wood")
	for _, s in { -1, 1 } do
		porta(k, s * (w / 4), 1.25, w / 2 - 0.15, 1.5, zf, mul(cor, 1.08), -s * 0.3)
	end
	-- TV de tubo
	k.b("TV", 0, 2.925, -0.15, 2.8, 1.35, 1.1, P.preto, "SmoothPlastic")
	k.b("TVTubo", 0, 2.85, 0.65, 1.8, 1.0, 0.5, mul(P.preto, 1.15), "SmoothPlastic")
	k.b("Tela", -0.25, 2.95, -0.7, 2.0, 1.0, 0.05, P.vidroEsc, "Glass", { refletancia = 0.15, sombra = false })
	k.b("Botao", 1.15, 3.1, -0.7, 0.2, 0.2, 0.06, { 120, 120, 124 }, "Metal", DETC)
	k.b("Botao", 1.15, 2.75, -0.7, 0.2, 0.2, 0.06, { 120, 120, 124 }, "Metal", DETC)
end)

def("lareira", function(k, w, h, d, op)
	local cor = op.cor or P.pedra
	k.b("Soleira", 0, 0.2, -0.2, w, 0.4, 1.8, mul(cor, 0.8), "Granite")
	for _, s in { -1, 1 } do
		k.b("Pilar", s * 2.25, 1.9, 0.45, 1.5, 3.0, 1.3, cor, "Cobblestone")
	end
	k.b("Verga", 0, 3.9, 0.45, w, 1.0, 1.3, cor, "Cobblestone")
	k.b("Manto", 0, 4.575, 0.1, w, 0.35, 1.9, P.madeiraEsc, "Wood")
	k.b("Coluna", 0, 5.275, 0.55, 4.6, 1.05, 1.1, cor, "Cobblestone")
	k.b("Chamine", 0, 6.4, 0.55, 3.4, 1.2, 1.1, mul(cor, 0.92), "Cobblestone")
	k.b("Fuligem", 0, 1.9, 1.0, 3.0, 3.0, 0.2, { 20, 18, 18 }, "Slate")
	k.b("Cinza", 0, 0.43, 0.55, 2.4, 0.06, 1.2, { 52, 50, 48 }, "Ground", DETC)
	k.c("Tora", 0, 0.7, 0.4, 0.5, 2.2, { 58, 42, 34 }, "Wood", { eixo = "x", colide = false })
	k.c("Tora", 0, 0.7, 0.85, 0.5, 2.2, { 52, 38, 32 }, "Wood", { eixo = "x", colide = false })
	k.c("Tora", 0.1, 1.15, 0.62, 0.5, 2.0, { 64, 46, 36 }, "Wood", { eixo = "x", colide = false })
end)

def("aparador", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	pes(k, w / 2 - 0.3, d / 2 - 0.25, 0.4, 0.3)
	corpo(k, 0, 0.4, 2.9, w - 0.2, d, cor)
	k.b("Tampo", 0, 2.95, 0, w, 0.1, d, mul(cor, 0.9), "Wood")
	for i = -1, 1 do
		porta(k, i * 1.55, 1.65, 1.45, 2.2, zf, mul(cor, 1.08), i * 1.55 + 0.55)
	end
end)

def("relogio_pe", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraEsc
	k.b("Base", 0, 0.8, 0, w, 1.6, d, cor, "Wood")
	k.b("Corpo", 0, 3.6, 0, 1.3, 4.0, 1.1, mul(cor, 1.08), "Wood")
	k.b("Cabeca", 0, 6.15, 0.05, 1.6, 1.1, 1.2, cor, "Wood")
	k.b("Coroa", 0, 6.85, 0, w, 0.3, d, mul(cor, 0.9), "Wood")
	k.c(
		"Mostrador",
		0,
		6.15,
		-0.63,
		1.0,
		0.06,
		P.abajur,
		"SmoothPlastic",
		{ eixo = "z", colide = false, sombra = false }
	)
	k.b("PonteiroH", 0.0, 6.28, -0.67, 0.07, 0.3, 0.03, P.preto, "SmoothPlastic", DETC)
	k.b("PonteiroM", 0.18, 6.15, -0.67, 0.4, 0.06, 0.03, P.preto, "SmoothPlastic", DETC)
	k.b("Janela", 0, 3.7, -0.57, 0.7, 2.6, 0.04, { 36, 40, 40 }, "Glass", DETC)
	k.b("Haste", 0, 3.7, -0.53, 0.06, 2.0, 0.04, P.latao, "Metal", DETC)
	k.c(
		"Pendulo",
		0,
		2.9,
		-0.53,
		0.5,
		0.04,
		P.latao,
		"Metal",
		{ eixo = "z", colide = false, sombra = false, consulta = false }
	)
end)

def("piano", function(k, w, h, d, op)
	local cor = op.cor or { 42, 34, 32 }
	k.b("Corpo", 0, 1.9, 0.5, w, 3.8, 1.2, cor, "Wood")
	k.b("Tampa", 0, 3.9, 0.45, w, 0.2, 1.3, mul(cor, 0.85), "Wood")
	for _, s in { -1, 1 } do
		k.b("Lateral", s * 2.25, 1.1, -0.6, 0.5, 2.2, 1.0, cor, "Wood")
	end
	k.b("Tabua", 0, 1.85, -0.6, 4.0, 0.3, 1.0, mul(cor, 0.9), "Wood")
	k.b("Teclas", 0, 2.07, -0.6, 3.9, 0.14, 0.8, { 205, 200, 185 }, "SmoothPlastic", DET)
	for _, x in { -1.5, -1.0, 0.8, 1.3 } do
		k.b("TeclaPreta", x, 2.19, -0.4, 0.35, 0.12, 0.4, P.preto, "SmoothPlastic", DETC)
	end
	k.b("Partitura", 0, 3.05, -0.18, 3.4, 0.9, 0.15, mul(cor, 1.25), "Wood", DET)
	k.b("Lira", 0, 0.5, -0.25, 1.6, 0.9, 0.3, mul(cor, 1.1), "Wood", DET)
	for _, x in { -0.5, 0.5 } do
		k.b("Pedal", x, 0.25, -0.5, 0.4, 0.15, 0.5, P.latao, "Metal", DETC)
	end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- COZINHA / JANTAR
-- ---------------------------------------------------------------------------------------------------------------
def("mesa_jantar", function(k, w, h, d, op)
	mesa(k, w, h, d, op.cor or P.madeira, op.cor2 or P.madeiraEsc, op.cor3 or { 130, 120, 100 })
end)

def("mesa_cozinha", function(k, w, h, d, op)
	mesa(k, w, h, d, op.cor or P.madeiraCl, op.cor2 or P.madeiraEsc, op.cor3 or { 150, 70, 62 })
end)

def("cadeira", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	k.b("Assento", 0, 1.6, 0, w, 0.2, d, cor, "Wood")
	k.b("Estofado", 0, 1.775, -0.05, w - 0.3, 0.15, d - 0.4, op.cor2 or P.tecido, "Fabric")
	for _, s in { -1, 1 } do
		k.b("Pe", s * (w / 2 - 0.15), 0.75, -d / 2 + 0.15, 0.25, 1.5, 0.25, P.madeiraEsc, "Wood")
		k.b("Montante", s * (w / 2 - 0.15), h / 2, d / 2 - 0.15, 0.25, h, 0.25, P.madeiraEsc, "Wood")
	end
	for _, y in { 2.4, 3.1 } do
		k.b("Ripa", 0, y, d / 2 - 0.15, w - 0.5, 0.4, 0.12, cor, "Wood")
	end
end)

def("geladeira", function(k, w, h, d, op)
	local cor = op.cor or P.branco
	local zf = -d / 2
	k.b("Rodape", 0, 0.1, 0.05, w - 0.2, 0.2, d - 0.4, P.ferro, "Metal")
	corpo(k, 0, 0.2, h, w, d, cor, "SmoothPlastic")
	k.b("PortaFreezer", 0, 5.05, zf + 0.09, w - 0.1, 2.1, 0.06, mul(cor, 1.02), "SmoothPlastic")
	k.b("PortaGeladeira", 0, 2.1, zf + 0.09, w - 0.1, 3.6, 0.06, mul(cor, 1.02), "SmoothPlastic")
	k.b("Fresta", 0, 3.98, zf + 0.09, w - 0.1, 0.1, 0.07, { 60, 60, 64 }, "SmoothPlastic", DET)
	pux(k, 1.0, 4.9, zf, 1.1, true)
	pux(k, 1.0, 2.9, zf, 1.4, true)
	k.b("Bilhete", -0.6, 4.7, zf + 0.04, 0.5, 0.65, 0.04, { 205, 200, 150 }, "SmoothPlastic", DETC)
	k.b("Foto", -0.5, 3.2, zf + 0.04, 0.6, 0.8, 0.04, { 150, 150, 148 }, "SmoothPlastic", DETC)
	k.b("Ima", -0.2, 2.1, zf + 0.04, 0.3, 0.3, 0.04, { 150, 56, 48 }, "SmoothPlastic", DETC)
end)

def("fogao", function(k, w, h, d, op)
	local cor = op.cor or P.branco
	local zf = -d / 2
	k.b("Rodape", 0, 0.1, 0.05, w - 0.2, 0.2, d - 0.4, P.ferro, "Metal")
	corpo(k, 0, 0.2, 2.5, w, d, cor, "SmoothPlastic")
	k.b("Mesa", 0, 2.55, 0, w, 0.1, d, { 40, 40, 44 }, "Metal")
	k.b("Painel", 0, 2.8, d / 2 - 0.1, w, 0.4, 0.2, mul(cor, 0.9), "SmoothPlastic")
	for _, x in { -0.6, 0.6 } do
		for _, z in { -0.5, 0.5 } do
			k.c("Boca", x, 2.64, z, 0.7, 0.08, P.ferro, "Metal", DET)
		end
	end
	k.c("Panela", -0.6, 2.83, -0.5, 0.9, 0.3, P.inox, "Metal", DET)
	k.b("CaboPanela", -0.6 - 0.65, 2.9, -0.5, 0.4, 0.08, 0.12, P.preto, "SmoothPlastic", DETC)
	for _, x in { -0.9, -0.3, 0.3, 0.9 } do
		k.c(
			"Botao",
			x,
			2.2,
			zf + 0.07,
			0.28,
			0.14,
			P.preto,
			"SmoothPlastic",
			{ eixo = "z", colide = false, sombra = false, consulta = false }
		)
	end
	k.b("PortaForno", 0, 1.2, zf + 0.09, w - 0.4, 1.6, 0.06, mul(cor, 1.02), "SmoothPlastic")
	k.b("VisorForno", 0, 1.05, zf + 0.04, 1.5, 0.8, 0.04, P.vidroEsc, "Glass", DETC)
	pux(k, 0, 1.9, zf, 1.7)
end)

def("pia_cozinha", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	k.b("Rodape", 0, 0.125, 0.05, w - 0.2, 0.25, d - 0.4, P.madeiraEsc, "Wood")
	corpo(k, 0, 0.25, 2.35, w, d, cor)
	k.b("Tampo", 0, 2.475, 0, w, 0.25, d, op.cor2 or P.marmore, "Marble")
	for i = -1, 1 do
		porta(k, i * 1.6, 1.3, 1.5, 1.9, zf, mul(cor, 1.08), i * 1.6 + 0.5)
	end
	k.b("Cuba", 0, 2.625, 0.1, 2.0, 0.05, 1.3, P.inox, "Metal", DET)
	k.b("Ralo", 0, 2.665, 0.1, 1.7, 0.03, 1.0, { 70, 74, 76 }, "Metal", DETC)
	k.c("Torneira", 0, 2.775, 0.8, 0.3, 0.35, P.cromo, "Metal", DETC)
	k.b("Bica", 0, 2.88, 0.5, 0.14, 0.14, 0.7, P.cromo, "Metal", DETC)
	k.b("Alavanca", 0.2, 2.78, 0.8, 0.1, 0.25, 0.1, P.cromo, "Metal", DETC)
	k.c("Prato", 1.8, 2.7, 0.0, 0.9, 0.12, P.branco, "SmoothPlastic", DETC)
	k.c("Caneca", -1.8, 2.8, 0.0, 0.35, 0.4, { 120, 60, 54 }, "SmoothPlastic", DETC)
end)

def("bancada_cozinha", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	local topo = h - 0.4
	k.b("Rodape", 0, 0.125, 0.05, w - 0.2, 0.25, d - 0.4, P.madeiraEsc, "Wood")
	corpo(k, 0, 0.25, topo - 0.25, w, d, cor)
	k.b("Tampo", 0, topo - 0.125, 0, w, 0.25, d, op.cor2 or P.marmore, "Marble")
	local n = min(4, max(2, floor(w / 1.7 + 0.5)))
	local pw = (w - 0.3) / n
	for i = 1, n do
		local x = (i - (n + 1) / 2) * pw
		local alt = topo - 0.25 - 0.25 - 0.2
		porta(k, x, 0.25 + 0.1 + alt / 2, pw - 0.1, alt, zf, mul(cor, 1.08), x + pw * 0.3)
	end
	k.c("Pratos", -w / 2 + 0.9, topo + 0.12, 0.1, 0.9, 0.25, P.branco, "SmoothPlastic", DETC)
	k.c("Panela", w / 2 - 1.0, topo + 0.2, 0.0, 1.0, 0.4, P.inox, "Metal", DETC)
	k.b("Pote", 0.2, topo + 0.2, 0.3, 0.6, 0.4, 0.6, { 56, 80, 128 }, "SmoothPlastic", DETC)
end)

def("armario_cozinha_alto", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d
	k.b("Corpo", 0, h / 2, -(d - FR) / 2, w, h, d - FR, cor, "Wood")
	k.b("Cornija", 0, h - 0.1, -d / 2, w, 0.2, d, mul(cor, 0.85), "Wood")
	k.b("Rodape", 0, 0.075, -d / 2, w - 0.1, 0.15, d - 0.1, mul(cor, 0.85), "Wood")
	local n = min(4, max(2, floor(w / 1.7 + 0.5)))
	local pw = (w - 0.2) / n
	for i = 1, n do
		local x = (i - (n + 1) / 2) * pw
		k.b("Porta", x, h / 2, zf + 0.09, pw - 0.08, h - 0.5, 0.06, mul(cor, 1.08), "Wood")
		pux(k, x + (if x < 0 then 0.3 else -0.3), 0.6, zf, 0.6, true)
	end
end)

def("microondas", function(k, w, h, d, op)
	local cor = op.cor or P.branco
	local zf = -d / 2
	k.b("Pe", 0, 0.05, 0, w - 0.2, 0.1, d - 0.2, P.ferro, "Metal", DET)
	corpo(k, 0, 0.1, h, w, d, cor, "SmoothPlastic")
	k.b("Porta", -0.2, 0.65, zf + 0.09, 1.15, 0.9, 0.06, mul(cor, 0.92), "SmoothPlastic")
	k.b("Visor", -0.25, 0.65, zf + 0.04, 0.85, 0.55, 0.04, P.vidroEsc, "Glass", DETC)
	k.b("Painel", 0.65, 0.65, zf + 0.09, 0.4, 0.9, 0.06, mul(cor, 0.8), "SmoothPlastic")
	for _, y in { 0.4, 0.85 } do
		k.b("Botao", 0.65, y, zf + 0.03, 0.2, 0.12, 0.06, P.preto, "SmoothPlastic", DETC)
	end
	pux(k, 0.3, 0.65, zf, 0.6, true)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- BANHEIRO / SERVIÇO
-- ---------------------------------------------------------------------------------------------------------------
def("banheira", function(k, w, h, d, op)
	local cor = op.cor or P.branco
	local ax, az = w / 2 - 0.4, d / 2 - 0.3
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Pe", sx * ax, 0.125, sz * az, 0.5, 0.25, 0.5, P.ferro, "Metal", DET)
		end
	end
	k.b("Fundo", 0, 0.475, 0, w, 0.45, d, cor, "SmoothPlastic")
	for _, s in { -1, 1 } do
		k.b("ParedeLonga", 0, 1.275, s * (d / 2 - 0.225), w, 1.15, 0.45, cor, "SmoothPlastic")
		k.b("ParedeCurta", s * (w / 2 - 0.275), 1.275, 0, 0.55, 1.15, d - 0.9, cor, "SmoothPlastic")
		k.b("Borda", 0, 1.91, s * (d / 2 - 0.3), w, 0.12, 0.6, mul(cor, 1.03), "SmoothPlastic")
	end
	k.b("Mancha", 0, 0.71, 0, w * 0.6, 0.02, d * 0.4, { 112, 104, 84 }, "SmoothPlastic", DETC)
	k.b("Base", -1.5, 2.01, d / 2 - 0.3, 1.8, 0.08, 0.4, P.cromo, "Metal", DET)
	for _, x in { -2.2, -0.8 } do
		k.c("Torneira", x, 2.125, d / 2 - 0.3, 0.28, 0.15, P.cromo, "Metal", DETC)
	end
	k.b("Bica", -1.5, 2.14, d / 2 - 0.7, 0.14, 0.12, 0.8, P.cromo, "Metal", DETC)
end)

def("vaso_sanitario", function(k, w, h, d, op)
	local cor = op.cor or P.ceramica
	k.b("Pedestal", 0, 0.4, 0.35, 0.9, 0.8, 1.3, cor, "SmoothPlastic")
	k.b("Bacia", 0, 1.1, -0.15, w - 0.1, 0.6, 1.9, cor, "SmoothPlastic")
	k.b("Assento", 0, 1.46, -0.25, w - 0.2, 0.12, 1.7, mul(cor, 0.94), "SmoothPlastic")
	k.b("Tampa", 0, 1.57, -0.25, w - 0.3, 0.1, 1.5, mul(cor, 0.97), "SmoothPlastic")
	k.b("Caixa", 0, 1.54, 0.85, w, 1.08, 0.7, cor, "SmoothPlastic")
	k.b("TampaCaixa", 0, 2.14, 0.85, w, 0.12, 0.8, mul(cor, 0.95), "SmoothPlastic")
	k.c("Descarga", 0.35, 2.17, 0.85, 0.3, 0.07, P.cromo, "Metal", DETC)
	for _, s in { -1, 1 } do
		k.b("Dobradica", s * 0.5, 1.6, 0.6, 0.2, 0.15, 0.15, P.cromo, "Metal", DETC)
	end
end)

def("lavatorio", function(k, w, h, d, op)
	local cor = op.cor or P.ceramica
	k.b("Pedestal", 0, 0.1, 0.3, 1.2, 0.2, 1.2, cor, "SmoothPlastic")
	k.b("Coluna", 0, 1.1, 0.3, 0.8, 1.8, 0.8, cor, "SmoothPlastic")
	k.b("Bacia", 0, 2.275, 0, w, 0.55, d, cor, "SmoothPlastic")
	k.b("Fundo", 0, 2.57, -0.1, w - 0.8, 0.04, d - 0.8, mul(cor, 0.82), "SmoothPlastic", DETC)
	k.b("Encosto", 0, 2.8, d / 2 - 0.1, w, 0.5, 0.2, cor, "SmoothPlastic")
	k.c("Torneira", 0, 2.85, 0.6, 0.25, 0.5, P.cromo, "Metal", DETC)
	k.b("Bica", 0, 3.14, 0.35, 0.12, 0.12, 0.5, P.cromo, "Metal", DETC)
	for _, s in { -1, 1 } do
		k.c("Registro", s * 0.6, 2.9, 0.6, 0.25, 0.3, P.cromo, "Metal", DETC)
	end
end)

def("espelho_banheiro", function(k, w, h, d, op)
	espelho(k, w, h, op.cor or P.branco, if op.variante then op.variante == 2 else true)
end)

def("box_chuveiro", function(k, w, h, d, op)
	local cor = op.cor or P.ceramica
	local vid = { 150, 175, 190 }
	k.b("Bandeja", 0, 0.175, 0, w, 0.35, d, cor, "SmoothPlastic")
	k.c("Ralo", 0, 0.37, 0, 0.5, 0.04, P.ferro, "Metal", DETC)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Perfil", sx * (w / 2 - 0.1), 3.925, sz * (d / 2 - 0.1), 0.2, 7.15, 0.2, P.cromo, "Metal", DET)
		end
	end
	k.b(
		"Vidro",
		w / 2 - 0.1,
		3.85,
		0,
		0.1,
		6.9,
		d - 0.4,
		vid,
		"Glass",
		{ transparencia = 0.6, consulta = false, sombra = false }
	)
	k.b(
		"VidroPorta",
		0.75,
		3.85,
		-(d / 2 - 0.1),
		1.3,
		6.9,
		0.1,
		vid,
		"Glass",
		{ transparencia = 0.6, consulta = false, sombra = false }
	)
	k.b("TrilhoFrente", 0, 7.4, -(d / 2 - 0.1), w - 0.2, 0.15, 0.2, P.cromo, "Metal", DET)
	k.b("TrilhoLado", w / 2 - 0.1, 7.4, 0, 0.2, 0.15, d - 0.4, P.cromo, "Metal", DET)
	k.b("Coluna", 0, 3.85, d / 2 - 0.1, 0.14, 7.0, 0.14, P.cromo, "Metal", DETC)
	k.b("Cano", 0, 6.95, d / 2 - 0.5, 0.12, 0.12, 0.9, P.cromo, "Metal", DETC)
	k.c("Chuveiro", 0, 6.85, d / 2 - 0.95, 0.7, 0.12, P.cromo, "Metal", DETC)
	k.c(
		"Registro",
		0,
		4.0,
		d / 2 - 0.1,
		0.3,
		0.2,
		P.cromo,
		"Metal",
		{ eixo = "z", colide = false, sombra = false, consulta = false }
	)
end)

def("maquina_lavar", function(k, w, h, d, op)
	local cor = op.cor or P.branco
	local zf = -d / 2
	corpo(k, 0, 0.1, h, w, d, cor, "SmoothPlastic")
	k.b("Pe", 0, 0.05, 0, w - 0.3, 0.1, d - 0.3, P.ferro, "Metal", DET)
	k.b("Painel", 0, 2.45, zf + 0.09, w - 0.1, 0.7, 0.06, mul(cor, 0.88), "SmoothPlastic")
	k.c("Aro", 0, 1.3, zf + 0.09, 1.7, 0.06, P.esmalte, "SmoothPlastic", { eixo = "z", sombra = false })
	k.c("Vidro", 0, 1.3, zf + 0.05, 1.3, 0.06, P.vidroEsc, "Glass", { eixo = "z", sombra = false, colide = false })
	for _, x in { 0.5, 0.9 } do
		k.c(
			"Botao",
			x,
			2.45,
			zf + 0.04,
			0.28,
			0.08,
			P.preto,
			"SmoothPlastic",
			{ eixo = "z", colide = false, sombra = false, consulta = false }
		)
	end
	k.b("Visor", -0.7, 2.45, zf + 0.05, 0.5, 0.25, 0.04, P.vidroEsc, "Glass", DETC)
end)

def("cesto_roupa", function(k, w, h, d, op)
	local cor = op.cor or { 140, 110, 70 }
	k.c("Corpo", 0, 1.0, 0, 1.5, 2.0, cor, "Wood")
	for _, y in { 0.6, 1.5 } do
		k.c("Aro", 0, y, 0, 1.56, 0.12, mul(cor, 0.75), "Wood", DET)
	end
	k.c("Tampa", 0, 2.1, 0, 1.6, 0.2, mul(cor, 1.1), "Wood")
	k.c("Pega", 0, 2.3, 0, 0.3, 0.2, mul(cor, 0.75), "Wood", DET)
	k.b("Pano", 0.5, 1.9, -0.65, 0.5, 0.6, 0.12, { 100, 112, 124 }, "Fabric", DETC)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- ESCRITÓRIO DOMÉSTICO
-- ---------------------------------------------------------------------------------------------------------------
def("escrivaninha", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	local zf = -d / 2
	k.b("Tampo", 0, 2.6, 0, w, 0.2, d, mul(cor, 0.9), "Wood")
	k.b("PainelLado", -w / 2 + 0.2, 1.25, 0, 0.2, 2.5, d - 0.3, cor, "Wood")
	k.b("Fundo", -0.5, 1.7, d / 2 - 0.2, w - 1.7, 1.2, 0.1, mul(cor, 0.8), "Wood")
	k.b("Gaveteiro", w / 2 - 0.8, 1.25, 0.05, 1.5, 2.5, d - 0.3 - FR, cor, "Wood")
	for i = 0, 2 do
		gaveta(k, w / 2 - 0.8, 2.15 - i * 0.75, 1.3, 0.65, zf + 0.15, mul(cor, 1.1), 0.5)
	end
	k.b("Papeis", -1.2, 2.72, 0.1, 1.0, 0.04, 0.8, P.papel, "Fabric", DETC)
	k.b(
		"Livro",
		0.4,
		2.76,
		-0.2,
		0.8,
		0.12,
		0.6,
		P.livros[3],
		"Fabric",
		{ consulta = false, sombra = false, colide = false, rotY = 0.2 }
	)
end)

def("cadeira_escritorio", function(k, w, h, d, op)
	local cor = op.cor or { 50, 52, 56 }
	for i = 0, 2 do
		k.b("Estrela", 0, 0.06, 0, 1.9, 0.12, 0.25, P.ferro, "Metal", { rotY = i * pi / 3, sombra = false })
	end
	k.c("Coluna", 0, 0.86, 0, 0.3, 1.48, P.cromo, "Metal", DET)
	k.b("Assento", 0, 1.8, 0, 1.8, 0.4, 1.8, cor, "Fabric")
	k.b("Encosto", 0, 3.0, d / 2 - 0.2, 1.7, 1.6, 0.35, cor, "Fabric")
	k.b("Lombar", 0, 2.2, d / 2 - 0.2, 0.4, 0.5, 0.2, P.ferro, "Metal", DET)
	for _, s in { -1, 1 } do
		k.b("ApoioBraco", s * 0.95, 2.2, 0.2, 0.12, 0.4, 0.12, P.ferro, "Metal", DETC)
		k.b("Braco", s * 0.95, 2.45, 0, 0.2, 0.12, 1.0, P.ferro, "SmoothPlastic", DETC)
	end
end)

def("arquivo", function(k, w, h, d, op)
	local cor = op.cor or { 84, 90, 86 }
	local zf = -d / 2
	k.b("Rodape", 0, 0.125, 0.05, w - 0.2, 0.25, d - 0.3, P.ferro, "Metal")
	corpo(k, 0, 0.25, h, w, d, cor, "Metal")
	for i = 0, 3 do
		local y = 0.25 + 0.1 + 0.46 + i * 0.99
		k.b("Gaveta", 0, y, zf + 0.09, w - 0.3, 0.9, 0.06, mul(cor, 1.08), "Metal")
		pux(k, 0, y - 0.15, zf, 0.7)
		k.b("Etiqueta", 0, y + 0.2, zf + 0.04, 0.5, 0.22, 0.04, P.papel, "SmoothPlastic", DETC)
	end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- DECORAÇÃO
-- ---------------------------------------------------------------------------------------------------------------
def("tapete", function(k, w, h, d, op)
	local cor = op.cor or { 112, 66, 58 }
	k.b("Borda", 0, 0.03, 0, w, 0.06, d, cor, "Fabric", FINO)
	k.b("Campo", 0, 0.05, 0, w - 0.8, 0.08, d - 0.8, op.cor2 or mul(cor, 0.7), "Fabric", FINO)
	k.b("Motivo", 0, 0.07, 0, w * 0.45, 0.09, d * 0.4, op.cor3 or { 150, 128, 90 }, "Fabric", FINO)
	for _, s in { -1, 1 } do
		k.b("Franja", 0, 0.03, s * (d / 2 - 0.1), w - 0.6, 0.05, 0.2, { 168, 156, 128 }, "Fabric", FINO)
	end
end)

def("quadro", function(k, w, h, d, op)
	local v = op.variante or (if op.rng then op.rng.inteiro(1, 3) else 1)
	local mold = op.cor or P.madeiraEsc
	k.b("Fundo", 0, h / 2, -0.075, w, h, 0.15, mold, "Wood", FINO)
	k.b("MolduraH", 0, h - 0.125, -0.225, w, 0.25, 0.15, mul(mold, 1.15), "Wood", FINO)
	k.b("MolduraH", 0, 0.125, -0.225, w, 0.25, 0.15, mul(mold, 1.15), "Wood", FINO)
	k.b("MolduraV", -w / 2 + 0.125, h / 2, -0.225, 0.25, h - 0.5, 0.15, mul(mold, 1.15), "Wood", FINO)
	k.b("MolduraV", w / 2 - 0.125, h / 2, -0.225, 0.25, h - 0.5, 0.15, mul(mold, 1.15), "Wood", FINO)
	local cw, ch = w - 0.5, h - 0.5
	if v == 1 then
		k.b("Tela", 0, h / 2, -0.2, cw, ch, 0.1, { 88, 98, 104 }, "SmoothPlastic", FINO)
		k.b("Colina", 0, 0.25 + ch * 0.18, -0.27, cw, ch * 0.36, 0.04, { 52, 66, 50 }, "SmoothPlastic", FINO)
		k.c(
			"Sol",
			cw * 0.25,
			h * 0.72,
			-0.27,
			min(cw, ch) * 0.22,
			0.04,
			{ 170, 160, 120 },
			"SmoothPlastic",
			{ eixo = "z", consulta = false, colide = false, sombra = false }
		)
	elseif v == 2 then
		k.b("Tela", 0, h / 2, -0.2, cw, ch, 0.1, { 54, 46, 42 }, "SmoothPlastic", FINO)
		k.c(
			"Rosto",
			0,
			h * 0.58,
			-0.27,
			min(cw, ch) * 0.4,
			0.04,
			{ 150, 124, 104 },
			"SmoothPlastic",
			{ eixo = "z", consulta = false, colide = false, sombra = false }
		)
		k.b("Ombros", 0, 0.25 + ch * 0.15, -0.27, cw * 0.6, ch * 0.28, 0.04, { 70, 76, 90 }, "SmoothPlastic", FINO)
	else
		k.b("Tela", 0, h / 2, -0.2, cw, ch, 0.1, { 150, 140, 120 }, "SmoothPlastic", FINO)
		k.b(
			"Forma",
			-cw * 0.2,
			h / 2 + ch * 0.1,
			-0.27,
			cw * 0.4,
			ch * 0.5,
			0.04,
			{ 120, 62, 56 },
			"SmoothPlastic",
			FINO
		)
		k.b(
			"Forma",
			cw * 0.18,
			h / 2 - ch * 0.12,
			-0.27,
			cw * 0.4,
			ch * 0.4,
			0.04,
			{ 60, 82, 104 },
			"SmoothPlastic",
			FINO
		)
	end
end)

def("espelho_parede", function(k, w, h, d, op)
	espelho(k, w, h, op.cor or P.madeiraEsc, op.variante == 2)
end)

def("luminaria_chao", function(k, w, h, d, op)
	local cor = op.cor or P.abajur
	k.c("Base", 0, 0.075, 0, 1.2, 0.15, P.ferro, "Metal")
	k.c("Haste", 0, 2.4, 0, 0.15, 4.5, P.latao, "Metal", DET)
	k.c("Colar", 0, 4.45, 0, 0.4, 0.2, P.latao, "Metal", DET)
	k.c("Cupula", 0, 4.7, 0, 1.15, 1.0, cor, "Fabric", { colide = false, sombra = false })
end)

def("luminaria_mesa", function(k, w, h, d, op)
	local cor = op.cor or P.abajur
	k.c("Base", 0, 0.1, 0, 0.7, 0.2, P.preto, "Metal", DETC)
	k.c("Haste", 0, 0.55, 0, 0.14, 0.7, P.preto, "Metal", DETC)
	k.c("Cupula", 0, 1.2, 0, 0.95, 0.8, cor, "Fabric", DETC)
end)

def("planta_vaso", function(k, w, h, d, op)
	local verde = op.cor or P.folha
	k.c("Vaso", 0, 0.5, 0, 1.2, 1.0, P.terracota, "Brick")
	k.c("Borda", 0, 1.05, 0, 1.5, 0.2, mul(P.terracota, 1.1), "Brick", DET)
	k.c("Terra", 0, 1.16, 0, 1.3, 0.04, { 54, 42, 34 }, "Ground", DETC)
	local folhas = {
		{ 0.0, 2.3, 0.25 },
		{ 1.3, 2.3, 0.25 },
		{ 2.6, 1.6, 0.4 },
		{ 3.9, 1.6, 0.4 },
		{ 5.2, 1.6, 0.4 },
	}
	for i, f in folhas do
		local az, len, incl = f[1], f[2], f[3]
		local cor = if i == 4 then { 110, 100, 56 } else verde
		-- base da folha em (0,1.15,0); eixo inclinado para fora no azimute `az`
		local dx, dz = cos(az), -sin(az)
		local cy = 1.15 + len / 2 * cos(incl)
		local off = len / 2 * sin(incl)
		k.b("Folha", dx * off, cy, dz * off, 0.5, len, 0.1, cor, "Grass", {
			colide = false,
			consulta = false,
			sombra = false,
			rot = CFrame.Angles(0, az, 0) * CFrame.Angles(0, 0, -incl),
		})
	end
end)

def("cesto_lixo", function(k, w, h, d, op)
	local cor = op.cor or { 80, 84, 86 }
	k.c("Corpo", 0, 0.725, 0, 1.1, 1.35, cor, "Metal")
	k.c("Borda", 0, 1.45, 0, 1.2, 0.1, mul(cor, 1.2), "Metal", DET)
	k.e("Bola", -0.2, 1.55, 0.1, 0.35, P.papel, "Fabric", DETC)
	k.e("Bola", 0.2, 1.52, -0.15, 0.4, mul(P.papel, 0.9), "Fabric", DETC)
end)

def("caixa_papelao", function(k, w, h, d, op)
	local cor = op.cor or P.papelao
	k.b("Corpo", 0, 0.95, 0, w, 1.9, d, cor, "Wood")
	k.b("AbaA", 0, 1.94, -d / 4, w, 0.08, d / 2 - 0.05, mul(cor, 1.06), "Wood", DET)
	k.b("AbaB", 0, 1.94, d / 4, w, 0.08, d / 2 - 0.05, mul(cor, 1.06), "Wood", DET)
	k.b("Fita", 0, 1.98, 0, 0.5, 0.04, d, { 170, 150, 110 }, "SmoothPlastic", DETC)
	k.b("Etiqueta", 0.4, 1.0, -d / 2 + 0.02, 0.7, 0.5, 0.04, P.papel, "SmoothPlastic", DETC)
end)

def("bau", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraEsc
	k.b("Corpo", 0, 0.6, 0, w, 1.2, d - 0.1, cor, "Wood")
	k.c("Tampa", 0, 1.2, 0, d - 0.1, w, mul(cor, 1.08), "Wood", { eixo = "x" })
	for _, s in { -1, 1 } do
		k.b("Cinta", s * (w / 2 - 0.5), 0.6, 0, 0.3, 1.2, d, P.ferro, "Metal", DET)
		k.c(
			"CintaTampa",
			s * (w / 2 - 0.5),
			1.2,
			0,
			d,
			0.3,
			P.ferro,
			"Metal",
			{ eixo = "x", consulta = false, sombra = false }
		)
	end
	k.b("Fecho", 0, 1.15, -d / 2 + 0.03, 0.4, 0.5, 0.1, P.latao, "Metal", DETC)
end)

def("cabideiro", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraEsc
	k.b("PeA", 0, 0.1, 0, w, 0.2, 0.3, cor, "Wood")
	k.b("PeB", 0, 0.1, 0, 0.3, 0.2, d, cor, "Wood")
	k.b("Haste", 0, 2.75, 0, 0.22, 5.1, 0.22, cor, "Wood")
	k.e("Topo", 0, 5.3, 0, 0.4, cor, "Wood", DETC)
	for _, y in { 4.9, 4.3 } do
		k.b("GanchoA", 0, y, 0, 1.4, 0.14, 0.14, P.latao, "Metal", DETC)
		k.b("GanchoB", 0, y, 0, 0.14, 0.14, 1.4, P.latao, "Metal", DETC)
	end
	k.b("Casaco", 0.3, 3.95, 0, 0.8, 1.75, 0.4, { 66, 60, 54 }, "Fabric", DETC)
	k.b("Chapeu", 0, 4.45, 0.4, 0.6, 0.15, 0.6, { 90, 80, 66 }, "Fabric", DETC)
end)

def("sapateira", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraCl
	for _, s in { -1, 1 } do
		k.b("Lateral", s * (w / 2 - 0.1), h / 2, 0, 0.2, h, d, cor, "Wood")
	end
	for _, y in { 0.15, 0.95, 1.75, h - 0.075 } do
		k.b("Prateleira", 0, y, 0, w - 0.4, 0.15, d, cor, "Wood")
	end
	k.b("Fundo", 0, h / 2, d / 2 - 0.04, w - 0.4, h - 0.1, 0.08, mul(cor, 0.7), "Wood", DET)
	local sapatos = { { 0.15, -0.9 }, { 0.15, 0.4 }, { 0.95, -0.5 }, { 1.75, -1.0 }, { 1.75, 0.6 } }
	for i, s in sapatos do
		k.b(
			"Sapato",
			s[2],
			s[1] + 0.075 + 0.2,
			0,
			0.85,
			0.4,
			0.4,
			if i % 2 == 0 then { 50, 44, 40 } else { 90, 66, 52 },
			"Fabric",
			DETC
		)
	end
end)

def("relogio_parede", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraEsc
	k.c("Caixa", 0, 0.8, -0.1, 1.6, 0.2, cor, "Wood", { eixo = "z", sombra = false, consulta = false })
	k.c(
		"Face",
		0,
		0.8,
		-0.23,
		1.35,
		0.06,
		P.abajur,
		"SmoothPlastic",
		{ eixo = "z", sombra = false, consulta = false, colide = false }
	)
	for _, p in { { 0, 1.3 }, { 0.5, 0.8 }, { 0, 0.3 }, { -0.5, 0.8 } } do
		k.b("Marca", p[1], p[2], -0.27, 0.08, 0.08, 0.04, P.preto, "SmoothPlastic", DETC)
	end
	k.b("PonteiroH", 0, 0.95, -0.28, 0.07, 0.35, 0.04, P.preto, "SmoothPlastic", DETC)
	k.b("PonteiroM", 0.18, 0.8, -0.28, 0.4, 0.06, 0.04, P.preto, "SmoothPlastic", DETC)
end)

def("prateleira_parede", function(k, w, h, d, op)
	local cor = op.cor or P.madeira
	k.b("Tabua", 0, 0.23, -d / 2, w, 0.14, d, cor, "Wood", DET)
	k.b("Frente", 0, 0.16, -d + 0.05, w, 0.16, 0.1, mul(cor, 0.85), "Wood", DET)
	for _, s in { -1, 1 } do
		k.b("Mao", s * (w / 2 - 0.5), 0.08, -d * 0.4, 0.14, 0.16, d * 0.8, P.ferro, "Metal", DET)
	end
end)

def("cortina", function(k, w, h, d, op, ctx)
	local cor = op.cor or { 120, 84, 78 }
	local var = op.variante or 1
	k.c(
		"Varao",
		0,
		6.88,
		-0.1,
		0.15,
		w,
		P.latao,
		"Metal",
		{ eixo = "x", colide = false, consulta = false, sombra = false }
	)
	local dobras = if var == 1 then 6 else 3
	local pw = if var == 1 then w / dobras else w * 0.22 / dobras
	for lado = 1, (if var == 1 then 1 else 2) do
		for i = 1, dobras do
			local x
			if var == 1 then
				x = (i - (dobras + 1) / 2) * pw
			else
				local s = if lado == 1 then -1 else 1
				x = s * (w / 2 - pw * (i - 0.5))
			end
			local zc = if i % 2 == 0 then -0.14 else -0.26
			k.b("Dobra", x, 3.45, zc, pw, 6.7, 0.28, if i % 2 == 0 then mul(cor, 0.9) else cor, "Fabric", FINO)
		end
	end
	if var ~= 1 then
		for _, s in { -1, 1 } do
			k.b("Laco", s * (w / 2 - w * 0.11), 3.2, -0.4 + 0.2, w * 0.24, 0.2, 0.4, P.latao, "Fabric", FINO)
		end
	end
end)

def("ventilador_teto", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraCl
	local sf = { colide = false, consulta = false, sombra = false }
	k.c("Haste", 0, -0.15, 0, 0.2, 0.3, P.ferro, "Metal", sf)
	k.c("Motor", 0, -0.55, 0, 0.9, 0.5, P.ferro, "Metal", { colide = false, consulta = false })
	k.c("Luz", 0, -1.0, 0, 0.6, 0.4, { 150, 146, 130 }, "Glass", sf)
	for i = 0, 3 do
		local a = i * pi / 2
		local bx, bz = cos(a) * 1.45, sin(a) * 1.45
		local ao_x = (i % 2 == 0)
		k.b("Pa", bx, -0.62, bz, if ao_x then 2.1 else 0.6, 0.06, if ao_x then 0.6 else 2.1, cor, "Wood", sf)
	end
end)

def("lustre", function(k, w, h, d, op)
	local cor = op.cor or P.latao
	local sf = { colide = false, consulta = false, sombra = false }
	k.c("Corrente", 0, -0.3, 0, 0.1, 0.6, cor, "Metal", sf)
	k.e("Cubo", 0, -0.7, 0, 0.5, cor, "Metal", sf)
	k.b("BracoX", 0, -0.9, 0, 2.6, 0.1, 0.1, cor, "Metal", sf)
	k.b("BracoZ", 0, -0.9, 0, 0.1, 0.1, 2.6, cor, "Metal", sf)
	for _, s in { -1, 1 } do
		k.b("AroX", 0, -0.9, s * 1.3, 2.7, 0.1, 0.1, cor, "Metal", sf)
		k.b("AroZ", s * 1.3, -0.9, 0, 0.1, 0.1, 2.7, cor, "Metal", sf)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.c("Vela", sx * 1.3, -0.55, sz * 1.3, 0.22, 0.6, P.papel, "SmoothPlastic", sf)
		end
	end
	k.c("Pendente", 0, -1.2, 0, 0.12, 0.6, cor, "Metal", sf)
	k.e("Cristal", 0, -1.7, 0, 0.5, { 170, 180, 184 }, "Glass", sf)
end)

-- ---------------------------------------------------------------------------------------------------------------
-- GARAGEM / OFICINA DOMÉSTICA
-- ---------------------------------------------------------------------------------------------------------------
def("bancada_ferramentas", function(k, w, h, d, op)
	local cor = op.cor or P.madeiraCl
	local zf = -d / 2
	pes(k, w / 2 - 0.3, d / 2 - 0.3, 2.45, 0.4, P.madeiraEsc)
	k.b("Tampo", 0, 2.6, 0, w, 0.3, d, cor, "Wood")
	k.b("Prateleira", 0, 0.7, 0, w - 0.8, 0.15, d - 0.8, P.madeiraEsc, "Wood")
	k.b("Gaveteiro", -w / 2 + 1.2, 1.6, 0.05, 1.6, 1.8, d - 0.8, mul(cor, 0.85), "Wood")
	for _, y in { 2.0, 1.2 } do
		gaveta(k, -w / 2 + 1.2, y, 1.4, 0.65, zf + 0.35, mul(cor, 1.08), 0.5)
	end
	k.b("Torno", w / 2 - 0.8, 2.95, -d / 2 + 0.5, 0.6, 0.4, 0.5, { 70, 74, 80 }, "Metal")
	k.b("TornoMordente", w / 2 - 0.8, 3.1, -d / 2 + 0.1, 0.5, 0.15, 0.2, { 60, 64, 70 }, "Metal", DETC)
	k.b("MarteloCabo", 0.4, 2.8, 0.2, 0.8, 0.1, 0.14, P.madeiraEsc, "Wood", DETC)
	k.b("MartelloCabeca", 0.9, 2.86, 0.2, 0.3, 0.2, 0.2, P.ferro, "Metal", DETC)
	k.c("Lata", 0.8, 0.85, 0, 0.7, 0.55, { 140, 120, 60 }, "Metal", DETC)
end)

def("prateleira_garagem", function(k, w, h, d, op)
	local cor = op.cor or { 80, 92, 104 }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.b("Montante", sx * (w / 2 - 0.125), h / 2, sz * (d / 2 - 0.125), 0.25, h, 0.25, cor, "Metal")
		end
	end
	local niveis = { 0.3, 2.2, 4.1, h - 0.075 }
	for _, y in niveis do
		k.b("Prateleira", 0, y, 0, w - 0.1, 0.15, d, mul(cor, 1.2), "Metal")
	end
	local caixas = {
		{ 1, -1.6, 1.2, 0.9, 1.0, P.papelao },
		{ 1, 0.3, 1.5, 1.1, 1.1, mul(P.papelao, 0.85) },
		{ 2, -0.8, 1.3, 1.0, 1.0, { 70, 76, 86 } },
		{ 2, 1.4, 1.0, 0.8, 1.1, P.papelao },
		{ 3, -1.2, 1.4, 1.0, 1.0, mul(P.papelao, 0.9) },
		{ 3, 1.0, 1.0, 0.8, 1.2, P.vermelho },
	}
	for _, c in caixas do
		local y = niveis[c[1]] + 0.075 + c[4] / 2
		k.b("Caixa", c[2], y, 0, c[3], c[4], c[5], c[6], "Wood", DET)
	end
	k.c("Tinta", 1.7, niveis[3] + 0.075 + 0.35, 0, 0.7, 0.7, { 130, 120, 70 }, "Metal", DETC)
end)

def("bicicleta", function(k, w, h, d, op)
	local cor = op.cor or { 120, 50, 44 }
	local zr, zfr = 1.6, -1.6
	for _, z in { zr, zfr } do
		k.c("Pneu", 0, 1.1, z, 2.2, 0.2, P.borracha, "Plastic", { eixo = "x", colide = false })
		k.c("Aro", 0, 1.1, z, 1.6, 0.24, P.cromo, "Metal", { eixo = "x", colide = false, sombra = false })
	end
	local t = 0.14
	k.r("TuboSuperior", 0, 2.45, 0.7, 0, 2.55, -1.0, t, t, cor, "Metal", DET)
	k.r("TuboDiagonal", 0, 2.35, -1.0, 0, 0.9, 0.2, t, t, cor, "Metal", DET)
	k.r("TuboBanco", 0, 0.9, 0.2, 0, 2.95, 0.75, t, t, cor, "Metal", DET)
	k.r("BaseTraseira", 0, 0.9, 0.2, 0, 1.1, zr, t, t, cor, "Metal", DET)
	k.r("EscoraTraseira", 0, 2.45, 0.72, 0, 1.1, zr, t, t, cor, "Metal", DET)
	k.r("Garfo", 0, 2.85, -1.1, 0, 1.1, zfr, t, t, P.ferro, "Metal", DET)
	k.b("Guidao", 0, 2.95, -1.1, 1.0, 0.12, 0.12, P.ferro, "Metal", DETC)
	k.b("Selim", 0, 3.1, 0.8, 0.4, 0.15, 0.9, P.preto, "Fabric", DETC)
	k.c(
		"Coroa",
		0.1,
		0.9,
		0.2,
		0.9,
		0.06,
		P.ferro,
		"Metal",
		{ eixo = "x", colide = false, sombra = false, consulta = false }
	)
	k.c(
		"Eixo",
		0,
		0.9,
		0.2,
		0.12,
		0.9,
		P.ferro,
		"Metal",
		{ eixo = "x", colide = false, sombra = false, consulta = false }
	)
	for _, s in { -1, 1 } do
		k.b("Manivela", s * 0.4, 0.9 - s * 0.175, 0.2, 0.08, 0.4, 0.1, P.ferro, "Metal", DETC)
		k.b("Pedal", s * 0.4, 0.9 - s * 0.35, 0.2, 0.25, 0.08, 0.5, P.ferro, "Metal", DETC)
	end
end)

def("pilha_pneus", function(k, w, h, d, op)
	local jit = { { 0.05, -0.05 }, { -0.08, 0.04 }, { 0.1, 0.06 }, { -0.04, -0.08 } }
	for i = 1, 4 do
		local y = (i - 0.5) * 0.85
		local j = jit[i]
		k.c("Pneu", j[1], y, j[2], 2.4, 0.8, P.borracha, "Plastic")
		k.c("Faixa", j[1], y, j[2], 2.46, 0.2, { 46, 46, 50 }, "Plastic", { sombra = false })
	end
	k.c("Furo", jit[4][1], 3.4, jit[4][2], 1.3, 0.04, { 14, 14, 16 }, "SmoothPlastic", DETC)
	k.c("Aro", jit[4][1], 3.38, jit[4][2], 0.8, 0.06, P.cromo, "Metal", DETC)
end)

def("caixa_ferramentas", function(k, w, h, d, op)
	local cor = op.cor or P.vermelho
	k.b("Corpo", 0, 0.4, 0, w, 0.8, d, cor, "Metal")
	k.b("Tampa", 0, 0.88, 0, w, 0.16, d, mul(cor, 0.9), "Metal")
	for _, s in { -1, 1 } do
		k.b("Suporte", s * 0.5, 1.05, 0, 0.12, 0.2, 0.2, P.ferro, "Metal", DETC)
		k.b("Fecho", s * 0.55, 0.72, -d / 2 + 0.03, 0.2, 0.3, 0.06, P.cromo, "Metal", DETC)
	end
	k.b("Alca", 0, 1.1, 0, 1.12, 0.1, 0.2, P.ferro, "Metal", DETC)
end)

def("galao", function(k, w, h, d, op)
	local cor = op.cor or { 150, 44, 36 }
	k.b("Corpo", 0, 0.6, 0, w, 1.2, d, cor, "Metal")
	for _, x in { -0.36, 0.04 } do
		k.b("PegaPoste", x, 1.35, 0, 0.12, 0.3, 0.2, mul(cor, 0.8), "Metal", DETC)
	end
	k.b("PegaBarra", -0.16, 1.5, 0, 0.52, 0.1, 0.2, mul(cor, 0.8), "Metal", DETC)
	k.c("Bocal", 0.3, 1.37, 0.0, 0.3, 0.25, mul(cor, 0.8), "Metal", DETC)
	k.c("Tampa", 0.3, 1.55, 0.0, 0.34, 0.1, P.preto, "SmoothPlastic", DETC)
	k.b("Faixa", 0, 0.6, -d / 2 + 0.02, 0.7, 0.4, 0.04, { 205, 190, 90 }, "SmoothPlastic", DETC)
end)

return M
