-- Mobília comercial / serviço / culto / industrial / acampamento (dono "comercial" em mobilia_tamanhos.luau).
-- Contrato: docs/mapa-v2.md §6. Cada função (ctx, pai, cf, op) cria UM Model (Name = nome, atributo Movel) filho de `pai`.
-- Origem no centro da pegada, no piso; frente = −Z; fixo "parede": sai para −Z a partir da face; só cor + Material.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local M = {}

-- ---------------------------------------------------------------------------------------------------------------
-- Paleta compartilhada (metal industrial, madeira, plástico, lona…)
-- ---------------------------------------------------------------------------------------------------------------
local PAL = {
	madeira = { 110, 80, 60 },
	madeiraEsc = { 78, 58, 44 },
	madeiraCl = { 150, 118, 84 },
	metal = { 118, 122, 126 },
	metalEsc = { 72, 76, 80 },
	aco = { 150, 154, 158 },
	branco = { 200, 200, 205 },
	creme = { 184, 176, 155 },
	preto = { 30, 30, 34 },
	grafite = { 48, 50, 54 },
	ferrugem = { 120, 72, 46 },
	vermelho = { 140, 48, 44 },
	azul = { 52, 74, 110 },
	verde = { 62, 92, 64 },
	amarelo = { 190, 158, 58 },
	laranja = { 176, 98, 40 },
	lona = { 92, 98, 72 },
	papelao = { 150, 118, 80 },
	vidro = { 150, 175, 190 },
	concreto = { 130, 130, 126 },
	pedra = { 118, 116, 110 },
	couro = { 96, 40, 36 },
	industrial = { 74, 98, 78 },
	palha = { 168, 146, 84 },
	tijolo = { 120, 66, 52 },
	hospital = { 150, 190, 180 },
}
-- cores de produtos (latas, caixas, pacotes) desbotadas
local PROD = {
	{ 172, 50, 44 },
	{ 58, 98, 150 },
	{ 196, 164, 60 },
	{ 70, 128, 80 },
	{ 190, 110, 50 },
	{ 200, 200, 195 },
	{ 130, 70, 120 },
}

local function esc(c, k)
	return { math.min(255, c[1] * k), math.min(255, c[2] * k), math.min(255, c[3] * k) }
end

local function dim(op, w, h, d)
	return (op and op.w) or w, (op and op.h) or h, (op and op.d) or d
end

local function cor(op, padrao)
	return (op and op.cor) or padrao
end

local function copiar(o, extra)
	local r = {}
	if o then
		for k, v in o do
			r[k] = v
		end
	end
	for k, v in extra do
		r[k] = v
	end
	return r
end

-- Cria o Model e as funções de peça. Alturas: y0 = base da peça. Peça < 0,6 em todas as dimensões não colide.
local function nova(ctx, pai, cf, nome)
	local m = Instance.new("Model")
	m.Name = nome
	m:SetAttribute("Movel", nome)
	local K = { m = m }
	local function miudo(o, a, b, c)
		if math.max(a, b, c) < 0.6 then
			return copiar(o, { colide = false, consulta = false, sombra = false })
		end
		return o
	end
	-- bloco: centro x/z, base y0
	function K.b(cx, y0, cz, sx, sy, sz, c, mat, o)
		return ctx.bloco(m, cf, nome, cx, y0 + sy / 2, cz, sx, sy, sz, c, mat, miudo(o, sx, sy, sz))
	end
	-- cilindro em pé
	function K.c(cx, y0, cz, d, h, c, mat, o)
		return ctx.cilindro(m, cf, nome, cx, y0 + h / 2, cz, d, h, c, mat, miudo(o, d, h, d))
	end
	-- cilindro deitado no eixo X / Z (cy = centro)
	function K.cx(cx, cy, cz, d, len, c, mat, o)
		return ctx.cilindro(m, cf, nome, cx, cy, cz, d, len, c, mat, copiar(miudo(o, len, d, d), { eixo = "x" }))
	end
	function K.cz(cx, cy, cz, d, len, c, mat, o)
		return ctx.cilindro(m, cf, nome, cx, cy, cz, d, len, c, mat, copiar(miudo(o, d, d, len), { eixo = "z" }))
	end
	function K.e(cx, cy, cz, d, c, mat, o)
		return ctx.esfera(m, cf, nome, cx, cy, cz, d, c, mat, miudo(o, d, d, d))
	end
	-- laje inclinada entre dois pontos, face de cima passando pela reta (própria: ctx.rampa orienta errado no Lune)
	function K.r(x0, y0, z0, x1, y1, z1, larg, esp, c, mat, o)
		local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local dir = Vector3.new(dx, dy, dz) / len
		local dir_ = dir
		local dr = dir_:Cross(Vector3.new(0, 1, 0))
		if dr.Magnitude < 0.001 then
			dr = Vector3.new(1, 0, 0)
		end
		local dd = dr.Unit
		local up = dd:Cross(dir_)
		-- fromMatrix(pos, X, Y, Z): X = dd, Y = up, Z = −dir  (X × Y = Z)
		local rot = CFrame.fromMatrix(Vector3.new(0, 0, 0), dd, up, -dir_)
		local meio = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) - up * (esp / 2)
		return ctx.bloco(m, cf, nome, meio.X, meio.Y, meio.Z, larg, esp, len, c, mat, copiar(o, { rot = rot }))
	end
	function K.fim()
		m.Parent = pai
		return m
	end
	return K
end

-- ---------------------------------------------------------------------------------------------------------------
-- Auxiliares comuns
-- ---------------------------------------------------------------------------------------------------------------

-- Fileira de produtos coloridos numa prateleira: n blocos entre xa e xb sobre y
local function produtos(K, semente, xa, xb, y, hmax, zc, prof, n)
	local largTotal = (xb - xa)
	local lg = largTotal / n
	for j = 0, n - 1 do
		local c = PROD[(semente * 3 + j) % #PROD + 1]
		local hh = hmax * (if (semente + j) % 2 == 0 then 1 else 0.7)
		K.b(xa + lg * (j + 0.5), y, zc, lg - 0.12, hh, prof, c, "SmoothPlastic")
	end
end

-- Estante de n prateleiras entre dois montantes. itens(i, xa, xb, yTopo, espaco, zc, prof) põe objetos sobre cada nível.
local function estante(K, w, h, d, n, corEst, matEst, corPrat, matPrat, itens)
	local t = 0.25
	K.b(-w / 2 + 0.2, 0, 0, 0.4, h, d, corEst, matEst)
	K.b(w / 2 - 0.2, 0, 0, 0.4, h, d, corEst, matEst)
	K.b(0, 0.2, d / 2 - 0.1, w - 0.8, h - 0.5, 0.2, esc(corEst, 0.7), matEst)
	K.b(0, h - 0.3, 0, w, 0.3, d, corEst, matEst)
	local passo = (h - 0.6 - 1.4) / (n - 1)
	for i = 0, n - 1 do
		local y0 = 0.3 + i * passo
		K.b(0, y0, 0, w - 0.8, t, d - 0.1, corPrat, matPrat)
		if itens then
			local topo = y0 + t
			local limite = if i < n - 1 then 0.3 + (i + 1) * passo else h - 0.3
			itens(i, -w / 2 + 0.5, w / 2 - 0.5, topo, limite - topo, -0.05, d - 0.6)
		end
	end
end

-- Cadeira simples virada para o centro. (cx,cz) = centro do assento; eixo "z" ou "x"; s = +1/−1 lado onde fica o encosto
local function cadeiraSimples(K, cx, cz, eixo, s, c, tam, altTotal)
	local a = tam or 1.3
	local alt = altTotal or 2.7
	K.b(cx, 1.4, cz, a, 0.25, a, c, "Wood")
	if eixo == "z" then
		K.b(cx, 1.65, cz + s * (a / 2 - 0.1), a, alt - 1.65, 0.2, c, "Wood")
		K.b(cx, 0, cz + s * (a / 2 - 0.1), a - 0.2, 1.4, 0.2, esc(c, 0.75), "Wood")
		K.b(cx, 0, cz - s * (a / 2 - 0.1), a - 0.2, 1.4, 0.2, esc(c, 0.75), "Wood")
	else
		K.b(cx + s * (a / 2 - 0.1), 1.65, cz, 0.2, alt - 1.65, a, c, "Wood")
		K.b(cx + s * (a / 2 - 0.1), 0, cz, 0.2, 1.4, a - 0.2, esc(c, 0.75), "Wood")
		K.b(cx - s * (a / 2 - 0.1), 0, cz, 0.2, 1.4, a - 0.2, esc(c, 0.75), "Wood")
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- MERCADO
-- ---------------------------------------------------------------------------------------------------------------
M.prateleira_mercado = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "prateleira_mercado")
	local w, h, d = dim(op, 8, 6, 2.2)
	local c = cor(op, PAL.metal)
	estante(K, w, h, d, 4, c, "Metal", PAL.aco, "Metal", function(i, xa, xb, y, esp, zc, prof)
		produtos(K, i, xa, xb, y, math.min(esp - 0.2, 1.3), zc, prof, 2)
	end)
	return K.fim()
end

M.geladeira_expositora = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "geladeira_expositora")
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, 6, 0.5, 2.8, PAL.grafite, "Metal")
	K.b(-2.85, 0.5, 0, 0.3, 5.2, 2.8, c, "Metal")
	K.b(2.85, 0.5, 0, 0.3, 5.2, 2.8, c, "Metal")
	K.b(0, 0.5, 1.25, 5.4, 5.2, 0.3, esc(c, 0.8), "Metal")
	K.b(0, 5.7, 0, 6, 0.8, 2.8, PAL.azul, "SmoothPlastic")
	for i = 0, 2 do
		K.b(0, 1.8 + i * 1.3, 0.1, 5.4, 0.15, 2.4, PAL.aco, "Metal")
	end
	-- produtos por nível
	produtos(K, 0, -2.6, 2.6, 0.5, 1.0, 0.1, 2.0, 2)
	produtos(K, 1, -2.6, 2.6, 1.95, 1.0, 0.1, 2.0, 1)
	produtos(K, 2, -2.6, 2.6, 3.25, 1.0, 0.1, 2.0, 2)
	produtos(K, 3, -2.6, 2.6, 4.55, 1.0, 0.1, 2.0, 1)
	-- portas de vidro com puxadores
	for _, s in { -1, 1 } do
		K.b(s * 1.4, 0.6, -1.35, 2.7, 5.0, 0.1, PAL.vidro, "Glass", { transparencia = 0.65, sombra = false })
		K.b(s * 0.2, 2.2, -1.42, 0.18, 2.0, 0.1, PAL.aco, "Metal")
	end
	return K.fim()
end

M.freezer_horizontal = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "freezer_horizontal")
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, 5.6, 0.3, 2.6, PAL.grafite, "Metal")
	K.b(0, 0.3, 0, 6, 1.9, 3, c, "Metal")
	K.b(0, 1.0, -1.52, 6, 0.5, 0.05, PAL.azul, "SmoothPlastic", { colide = false })
	for i, x in { -2, 0, 2 } do
		K.b(x, 2.2, 0, 1.6, 0.35, 2.3, PROD[(i * 2) % #PROD + 1], "SmoothPlastic")
	end
	for _, s in { -1, 1 } do
		K.b(s * 1.5, 2.4, 0.1 * s, 3, 0.2, 2.6, PAL.vidro, "Glass", { transparencia = 0.6 })
		K.b(s * 1.5, 2.6, 0.1 * s, 3, 0.2, 2.6, PAL.vidro, "Glass", { transparencia = 0.7 })
	end
	return K.fim()
end

M.balcao_caixa = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "balcao_caixa")
	local c = cor(op, PAL.grafite)
	K.b(0, 0, 0, 7, 2.4, 3, c, "Metal")
	K.b(0, 2.4, 0, 7, 0.2, 3, PAL.concreto, "Concrete")
	-- esteira (lado do cliente)
	K.b(-1.7, 2.6, -0.5, 3.8, 0.12, 1.7, PAL.preto, "SmoothPlastic")
	K.b(-1.7, 2.6, -1.4, 3.8, 0.25, 0.15, PAL.aco, "Metal")
	K.b(-1.7, 2.6, 0.4, 3.8, 0.25, 0.15, PAL.aco, "Metal")
	K.b(-2.5, 2.72, -0.5, 1.0, 0.45, 0.9, PROD[2], "SmoothPlastic")
	K.b(-0.9, 2.72, -0.5, 0.8, 0.45, 0.7, PROD[3], "SmoothPlastic")
	-- divisória e registradora
	K.b(0.5, 2.6, -0.2, 0.15, 0.55, 2.3, PAL.aco, "Metal")
	K.b(2.2, 2.6, 0.5, 2.0, 0.35, 1.6, PAL.creme, "SmoothPlastic")
	K.b(2.2, 2.8, 0.9, 1.4, 0.2, 0.8, PAL.preto, "SmoothPlastic", { rot = CFrame.Angles(-0.3, 0, 0) })
	K.b(2.2, 2.9, 0.4, 1.4, 0.2, 0.25, PAL.preto, "SmoothPlastic", { colide = false })
	K.b(2.2, 2.3, -0.4, 1.6, 0.22, 0.5, PAL.metalEsc, "Metal")
	K.b(3.0, 2.6, -0.8, 0.9, 0.2, 0.5, PAL.aco, "Metal", { colide = false })
	return K.fim()
end

M.carrinho_compras = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "carrinho_compras")
	local c = cor(op, PAL.aco)
	for _, x in { -0.8, 0.8 } do
		K.cx(x, 0.25, -1.4, 0.5, 0.2, PAL.preto, "SmoothPlastic")
		K.cx(x, 0.25, 1.4, 0.5, 0.2, PAL.preto, "SmoothPlastic")
		K.b(x, 0.5, 0, 0.12, 0.12, 3.4, c, "Metal")
	end
	K.b(0, 0.9, -0.7, 1.8, 0.1, 2.0, c, "Metal", { transparencia = 0.3 })
	K.b(-0.9, 0.9, -0.7, 0.06, 1.7, 2.0, c, "Metal", { transparencia = 0.55, colide = false })
	K.b(0.9, 0.9, -0.7, 0.06, 1.7, 2.0, c, "Metal", { transparencia = 0.55, colide = false })
	K.b(0, 0.9, -1.65, 1.8, 1.7, 0.06, c, "Metal", { transparencia = 0.55, colide = false })
	K.b(0, 0.9, 0.3, 1.8, 1.7, 0.06, c, "Metal", { transparencia = 0.55, colide = false })
	K.b(-0.9, 2.55, -0.7, 0.12, 0.12, 2.0, PAL.vermelho, "Metal")
	K.b(0.9, 2.55, -0.7, 0.12, 0.12, 2.0, PAL.vermelho, "Metal")
	K.b(0, 2.55, -1.65, 1.8, 0.12, 0.12, PAL.vermelho, "Metal")
	K.b(0, 2.55, 0.3, 1.8, 0.12, 0.12, PAL.vermelho, "Metal")
	K.r(-0.9, 2.5, 0.3, -0.9, 3.1, 1.65, 0.12, 0.12, c, "Metal")
	K.r(0.9, 2.5, 0.3, 0.9, 3.1, 1.65, 0.12, 0.12, c, "Metal")
	K.b(0, 3.08, 1.64, 1.9, 0.14, 0.14, PAL.preto, "SmoothPlastic")
	return K.fim()
end

M.cesta_compras = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cesta_compras")
	local c = cor(op, PAL.vermelho)
	K.b(0, 0, 0, 1.6, 0.1, 1.2, c, "SmoothPlastic")
	K.b(0, 0, -0.55, 1.6, 0.8, 0.1, c, "SmoothPlastic", { transparencia = 0.2 })
	K.b(0, 0, 0.55, 1.6, 0.8, 0.1, c, "SmoothPlastic", { transparencia = 0.2 })
	K.b(-0.75, 0, 0, 0.1, 0.8, 1.2, c, "SmoothPlastic", { transparencia = 0.2 })
	K.b(0.75, 0, 0, 0.1, 0.8, 1.2, c, "SmoothPlastic", { transparencia = 0.2 })
	K.b(-0.55, 0.8, 0, 0.1, 0.4, 0.1, PAL.aco, "Metal")
	K.b(0.55, 0.8, 0, 0.1, 0.4, 0.1, PAL.aco, "Metal")
	K.b(0, 1.1, 0, 1.2, 0.1, 0.1, PAL.aco, "Metal")
	K.b(0, 0.1, 0, 1.0, 0.4, 0.8, PROD[2], "SmoothPlastic")
	return K.fim()
end

M.pilha_produtos = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "pilha_produtos")
	local c = cor(op, PAL.papelao)
	K.b(0, 0, 0, 3, 0.2, 3, PAL.madeiraEsc, "Wood")
	K.b(-0.8, 0.2, -0.5, 1.4, 1.0, 1.8, c, "Wood")
	K.b(0.8, 0.2, -0.5, 1.2, 1.0, 1.8, esc(c, 0.9), "Wood")
	K.b(0, 0.2, 0.9, 2.6, 1.0, 1.2, esc(c, 1.05), "Wood")
	K.b(-0.4, 1.2, -0.2, 1.6, 0.9, 1.6, PROD[1], "SmoothPlastic")
	K.b(0.8, 1.2, 0.7, 1.2, 0.8, 0.9, PROD[3], "SmoothPlastic")
	for i, p in { { -0.6, -0.1 }, { 0.2, -0.2 }, { -0.1, 0.5 } } do
		K.c(p[1], 2.1, p[2], 0.8, 0.9, PROD[(i * 2) % #PROD + 1], "Metal")
	end
	K.c(0.9, 2.0, 0.7, 0.8, 0.9, PROD[4], "Metal")
	return K.fim()
end

M.balcao_acougue = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "balcao_acougue")
	local w, h, d = dim(op, 8, 3.4, 3)
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, w, 2.0, d, c, "Metal")
	K.b(0, 2.0, d / 2 - 0.1, w, h - 2.0, 0.2, PAL.aco, "Metal")
	K.b(0, 2.0, -d / 2 + 0.1, w, 0.25, 0.2, PAL.aco, "Metal")
	K.b(0, 0.5, -d / 2 - 0.0, w - 0.4, 0.25, 0.04, PAL.vermelho, "SmoothPlastic", { colide = false })
	local n = math.max(2, math.floor(w / 2))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		K.b(
			x,
			2.0,
			-0.3,
			w / n - 0.3,
			0.45,
			d - 1.2,
			if i % 2 == 0 then PAL.vermelho else { 190, 110, 100 },
			"SmoothPlastic"
		)
	end
	K.r(0, 2.3, -d / 2 + 0.2, 0, h, 0.4, w - 0.4, 0.12, PAL.vidro, "Glass", { transparencia = 0.6, sombra = false })
	K.b(w / 2 - 1.1, 2.0, d / 2 - 0.6, 1.0, 0.5, 0.8, PAL.aco, "Metal")
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- LOJAS
-- ---------------------------------------------------------------------------------------------------------------
M.balcao_loja = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "balcao_loja")
	local w, h, d = dim(op, 7, 3.4, 2.4)
	local c = cor(op, PAL.madeira)
	K.b(0, 0, 0, w - 0.2, 0.3, d - 0.2, PAL.madeiraEsc, "Wood")
	K.b(0, 0.3, 0, w - 0.2, h - 0.7, d - 0.2, c, "Wood")
	K.b(0, h - 0.4, 0, w, 0.4, d, PAL.madeiraEsc, "Wood")
	local n = math.max(2, math.floor(w / 2.4))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		K.b(x, 0.7, -d / 2 + 0.05, w / n - 0.5, h - 1.6, 0.1, esc(c, 1.2), "Wood", { colide = false })
		K.b(x, h - 1.4, -d / 2 - 0.02, 0.5, 0.15, 0.12, PAL.aco, "Metal")
	end
	return K.fim()
end

M.vitrine = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "vitrine")
	local w, h, d = dim(op, 5, 3.4, 2)
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0, w, 1.3, d, c, "Wood")
	K.b(0, 1.3, 0, w, 0.12, d, PAL.preto, "Fabric")
	K.b(-w / 2 + 0.07, 1.4, 0, 0.14, h - 1.4, d, c, "Wood")
	K.b(w / 2 - 0.07, 1.4, 0, 0.14, h - 1.4, d, c, "Wood")
	K.b(0, h - 0.12, 0, w, 0.12, d, c, "Wood")
	K.b(0, 1.4, -d / 2 + 0.07, w - 0.3, h - 1.5, 0.08, PAL.vidro, "Glass", { transparencia = 0.7, sombra = false })
	K.b(0, 1.4, d / 2 - 0.07, w - 0.3, h - 1.5, 0.08, PAL.vidro, "Glass", { transparencia = 0.7, sombra = false })
	K.b(-w / 4, 1.42, 0, 0.8, 0.5, 0.8, PAL.amarelo, "Metal")
	K.b(w / 4, 1.42, 0, 0.6, 0.7, 0.6, PAL.azul, "SmoothPlastic")
	return K.fim()
end

M.arara_roupas = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "arara_roupas")
	local c = cor(op, PAL.aco)
	for _, s in { -1, 1 } do
		K.b(s * 2.3, 0, 0, 0.2, 0.2, 1.6, c, "Metal")
		K.b(s * 2.3, 0.2, 0, 0.2, 5.0, 0.2, c, "Metal")
		K.b(s * 2.3, 5.2, 0, 0.3, 0.2, 0.3, PAL.preto, "SmoothPlastic")
	end
	K.cx(0, 4.8, 0, 0.2, 4.8, c, "Metal")
	-- roupas penduradas: painéis de tecido
	local tons = { { 120, 60, 60 }, { 60, 80, 120 }, { 150, 140, 110 }, { 70, 100, 70 }, { 90, 90, 100 } }
	for i, t in tons do
		K.b(-1.9 + (i - 1) * 0.95, 1.3, 0, 0.8, 3.4, 0.5, t, "Fabric", { colide = false })
	end
	return K.fim()
end

M.manequim = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "manequim")
	local c = cor(op, PAL.creme)
	K.c(0, 0, 0, 1.6, 0.2, PAL.preto, "Metal")
	K.c(0, 0.2, 0, 0.25, 2.4, PAL.preto, "Metal")
	K.b(0, 2.2, 0, 0.9, 0.8, 0.5, c, "SmoothPlastic")
	K.b(0, 3.0, 0, 1.1, 1.6, 0.6, PAL.azul, "Fabric")
	K.b(-0.7, 3.1, 0, 0.3, 1.4, 0.3, c, "SmoothPlastic")
	K.b(0.7, 3.1, 0, 0.3, 1.4, 0.3, c, "SmoothPlastic")
	K.c(0, 4.6, 0, 0.35, 0.5, c, "SmoothPlastic")
	K.e(0, 5.55, 0, 0.9, c, "SmoothPlastic")
	K.b(0, 2.2, 0, 1.3, 1.0, 0.8, PAL.verde, "Fabric")
	return K.fim()
end

M.prateleira_loja = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "prateleira_loja")
	local w, h, d = dim(op, 6, 7, 1.6)
	local c = cor(op, PAL.madeira)
	estante(K, w, h, d, 5, c, "Wood", PAL.madeiraCl, "WoodPlanks", function(i, xa, xb, y, esp, zc, prof)
		if i % 2 == 0 then
			produtos(K, i + 2, xa, xb, y, math.min(esp - 0.3, 1.0), zc, prof - 0.2, 2)
		else
			K.b(xa + 0.5, y, zc, 1.0, math.min(esp - 0.3, 0.9), prof - 0.2, PAL.papelao, "Wood")
		end
	end)
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- RESTAURANTE / BAR
-- ---------------------------------------------------------------------------------------------------------------
M.mesa_restaurante = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_restaurante")
	local c = cor(op, PAL.madeira)
	local n = (op and op.variante) or 4
	K.b(0, 2.2, 0, 2.4, 0.2, 2.4, c, "Wood")
	K.b(0, 0.2, 0, 0.5, 2.0, 0.5, PAL.madeiraEsc, "Wood")
	K.b(0, 0, 0, 1.6, 0.2, 1.6, PAL.madeiraEsc, "Wood")
	local lados = { { 0, -1.35, "z", 1 }, { 0, 1.35, "z", -1 }, { -1.35, 0, "x", 1 }, { 1.35, 0, "x", -1 } }
	-- encosto do lado de fora: o s do encosto é o lado oposto ao centro
	local ordem = if n == 2 then { 1, 2 } elseif n == 3 then { 1, 2, 3 } else { 1, 2, 3, 4 }
	for _, i in ordem do
		local l = lados[i]
		local s = if l[3] == "z" then (if l[2] < 0 then -1 else 1) else (if l[1] < 0 then -1 else 1)
		cadeiraSimples(K, l[1], l[2], l[3], s, PAL.madeiraCl, 1.3, 2.7)
	end
	-- prato/vela no centro
	K.c(0, 2.4, 0, 0.3, 0.3, PAL.creme, "SmoothPlastic")
	return K.fim()
end

M.cabine_restaurante = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cabine_restaurante")
	local c = cor(op, PAL.couro)
	for _, s in { -1, 1 } do
		K.b(s * 2.4, 0, 0, 1.6, 1.4, 3.2, PAL.madeiraEsc, "Wood")
		K.b(s * 2.4, 1.4, 0, 1.6, 0.3, 3.2, c, "Fabric")
		K.b(s * 3.2 - s * 0.2, 1.7, 0, 0.4, 1.9, 3.2, c, "Fabric")
		K.b(s * 3.3, 0, 0, 0.2, 1.7, 3.2, PAL.madeiraEsc, "Wood", { colide = true })
	end
	K.b(0, 2.5, 0, 2.6, 0.2, 2.6, PAL.madeiraCl, "Wood")
	K.b(0, 0.2, 0, 0.5, 2.3, 0.5, PAL.aco, "Metal")
	K.b(0, 0, 0, 1.4, 0.2, 1.4, PAL.aco, "Metal")
	K.b(-0.5, 2.7, 0.2, 0.4, 0.5, 0.4, PAL.vidro, "Glass", { transparencia = 0.3 })
	K.b(0.5, 2.7, -0.2, 0.5, 0.35, 0.3, PAL.aco, "Metal")
	return K.fim()
end

M.balcao_bar = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "balcao_bar")
	local w, h, d = dim(op, 10, 3.6, 2.2)
	local c = cor(op, PAL.madeira)
	K.b(0, 0, 0.1, w - 0.2, 3.2, d - 0.3, c, "Wood")
	local n = math.max(3, math.floor(w / 2.2))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		K.b(x, 0.5, -d / 2 + 0.05, w / n - 0.4, 2.2, 0.08, esc(c, 1.25), "Wood", { colide = false })
	end
	K.b(0, 3.2, 0, w, 0.3, d, PAL.madeiraEsc, "Wood")
	K.b(0, 3.5, -d / 2 + 0.15, w, h - 3.5, 0.3, PAL.madeiraEsc, "Wood", { colide = false })
	K.cx(0, 0.5, -d / 2 + 0.1, 0.3, w - 0.4, PAL.aco, "Metal", { colide = false })
	for i = 1, 4 do
		local x = -w / 2 + i * w / 5
		K.c(x, 3.5, 0.3, 0.3, h - 3.5, PROD[i + 1], "Glass", { colide = false })
	end
	return K.fim()
end

M.banqueta = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "banqueta")
	local c = cor(op, PAL.couro)
	K.c(0, 0, 0, 1.5, 0.15, PAL.aco, "Metal")
	K.c(0, 0.15, 0, 0.25, 2.1, PAL.aco, "Metal")
	K.c(0, 1.0, 0, 1.3, 0.12, PAL.aco, "Metal")
	K.c(0, 2.25, 0, 1.5, 0.55, c, "Fabric")
	return K.fim()
end

M.maquina_venda = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "maquina_venda")
	local c = cor(op, PAL.vermelho)
	K.b(0, 0, 0.1, 3, 6.5, 2.4, c, "Metal")
	K.b(-0.35, 1.4, -1.25, 1.9, 4.3, 0.1, PAL.preto, "SmoothPlastic")
	K.b(-0.35, 1.5, -1.32, 1.7, 4.1, 0.06, PAL.vidro, "Glass", { transparencia = 0.7, sombra = false })
	for i = 0, 3 do
		K.b(-0.35, 1.8 + i * 1.0, -1.28, 1.6, 0.7, 0.05, PROD[i + 1], "SmoothPlastic", { colide = false })
	end
	K.b(1.0, 3.5, -1.3, 0.6, 1.4, 0.1, PAL.grafite, "SmoothPlastic")
	K.b(1.0, 4.4, -1.36, 0.4, 0.3, 0.05, { 80, 200, 120 }, "Neon", { colide = false })
	K.b(-0.2, 0.3, -1.3, 2.0, 0.7, 0.12, PAL.grafite, "SmoothPlastic")
	K.b(0, 5.8, -1.25, 2.8, 0.5, 0.1, PAL.branco, "Neon", { colide = false })
	return K.fim()
end

M.jukebox = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "jukebox")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0, 3, 0.6, 2, PAL.grafite, "Metal")
	K.b(0, 0.6, 0, 2.8, 3.2, 1.9, c, "Wood")
	K.cz(0, 4.2, 0, 2.8, 1.9, c, "Wood")
	K.b(0, 3.7, 0, 2.8, 1.0, 1.9, c, "Wood")
	K.b(0, 4.9, -0.95, 2.4, 0.5, 0.06, { 255, 190, 90 }, "Neon", { colide = false })
	K.b(0, 1.9, -0.98, 2.0, 1.6, 0.08, PAL.vidro, "Glass", { transparencia = 0.5 })
	K.b(0, 2.2, -1.0, 1.5, 0.6, 0.06, { 220, 80, 60 }, "Neon", { colide = false })
	K.b(0, 0.9, -0.98, 2.2, 0.7, 0.06, PAL.preto, "Fabric")
	K.b(0, 3.5, -1.0, 1.4, 0.3, 0.05, PAL.aco, "Metal")
	return K.fim()
end

M.mesa_sinuca = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_sinuca")
	local c = cor(op, PAL.madeiraEsc)
	for _, sx in { -1, 1 } do
		K.b(sx * 3.9, 0, 0, 0.9, 1.7, 4.2, c, "Wood")
	end
	K.b(0, 1.7, 0, 9, 0.7, 5, c, "Wood")
	K.b(0, 2.4, 0, 7.6, 0.12, 3.8, PAL.verde, "Fabric")
	K.b(0, 2.5, -2.4, 8.6, 0.3, 0.3, esc(c, 1.2), "Wood")
	K.b(0, 2.5, 2.4, 8.6, 0.3, 0.3, esc(c, 1.2), "Wood")
	K.b(-4.2, 2.5, 0, 0.3, 0.3, 4.6, esc(c, 1.2), "Wood")
	K.b(4.2, 2.5, 0, 0.3, 0.3, 4.6, esc(c, 1.2), "Wood")
	for _, x in { -3.7, 0, 3.7 } do
		K.c(x, 2.42, -2.05, 0.5, 0.1, PAL.preto, "SmoothPlastic", { colide = false })
		K.c(x, 2.42, 2.05, 0.5, 0.1, PAL.preto, "SmoothPlastic", { colide = false })
	end
	for i = 0, 2 do
		K.e(1.5 + (i % 2) * 0.4, 2.52, -0.4 + i * 0.4, 0.34, PROD[i + 1], "SmoothPlastic")
	end
	K.e(-2.0, 2.52, 0, 0.34, PAL.branco, "SmoothPlastic")
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- POSTO / OFICINA
-- ---------------------------------------------------------------------------------------------------------------
M.bomba_combustivel = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "bomba_combustivel")
	local c = cor(op, PAL.vermelho)
	K.b(0, 0, 0, 2.4, 0.35, 1.8, PAL.concreto, "Concrete")
	K.b(0, 0.35, 0, 2.0, 4.85, 1.5, c, "Metal")
	K.b(0, 5.2, 0, 2.2, 1.0, 1.7, PAL.branco, "Metal")
	K.b(0, 6.2, 0, 2.4, 0.3, 1.8, esc(c, 0.7), "Metal")
	K.b(0, 3.5, -0.78, 1.6, 1.1, 0.08, PAL.preto, "Glass")
	K.b(-0.35, 3.85, -0.83, 0.7, 0.3, 0.04, { 90, 220, 120 }, "Neon", { colide = false })
	K.b(0.45, 3.85, -0.83, 0.5, 0.3, 0.04, { 220, 190, 80 }, "Neon", { colide = false })
	K.b(0, 5.5, -0.88, 1.4, 0.5, 0.04, c, "SmoothPlastic", { colide = false })
	K.b(0, 2.3, -0.78, 1.4, 0.6, 0.06, PAL.metalEsc, "Metal", { colide = false })
	-- coldre, mangueira e bico no lado +X
	K.b(1.15, 2.9, -0.2, 0.2, 1.2, 0.8, PAL.grafite, "Metal")
	K.b(1.15, 3.05, -0.2, 0.2, 0.7, 0.35, PAL.preto, "SmoothPlastic")
	K.c(1.15, 0.9, -0.5, 0.22, 2.1, PAL.preto, "SmoothPlastic", { colide = false })
	K.cz(1.15, 0.9, -0.1, 0.22, 0.9, PAL.preto, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.tambor_oleo = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "tambor_oleo")
	local c = cor(op, PAL.azul)
	K.c(0, 0, 0, 1.8, 2.8, c, "Metal")
	K.c(0, 0.6, 0, 1.9, 0.15, esc(c, 0.7), "Metal", { colide = false })
	K.c(0, 1.5, 0, 1.9, 0.15, esc(c, 0.7), "Metal", { colide = false })
	K.c(0, 2.2, 0, 1.9, 0.15, esc(c, 0.7), "Metal", { colide = false })
	K.c(0.4, 2.8, 0.3, 0.3, 0.02, PAL.preto, "Metal", { colide = false })
	return K.fim()
end

M.expositor_pneus = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "expositor_pneus")
	local c = cor(op, PAL.metalEsc)
	for _, s in { -1, 1 } do
		K.b(s * 1.9, 0, 0, 0.2, 6, 2, c, "Metal")
	end
	K.b(0, 5.8, 0, 4, 0.2, 2, c, "Metal")
	for i = 0, 2 do
		K.b(0, 0.1 + i * 2.0, 0, 3.6, 0.15, 2, PAL.metal, "Metal")
		for _, x in { -0.9, 0.9 } do
			K.cz(x, 0.25 + i * 2.0 + 0.9, 0, 1.75, 1.4, PAL.preto, "Slate")
		end
	end
	return K.fim()
end

M.elevador_oficina = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "elevador_oficina")
	local c = cor(op, PAL.amarelo)
	for _, s in { -1, 1 } do
		K.b(s * 4.6, 0, 0, 0.8, 0.3, 5, PAL.metalEsc, "DiamondPlate")
		K.b(s * 4.6, 0.3, 1.6, 0.8, 6.7, 0.9, c, "Metal")
		K.b(s * 4.0, 2.4, -0.2, 0.5, 0.3, 3.0, PAL.metal, "Metal")
		K.b(s * 3.3, 2.6, -1.4, 1.3, 0.3, 0.6, PAL.metal, "Metal")
		K.c(s * 4.6, 0.3, 0.7, 0.5, 2.0, PAL.metalEsc, "Metal")
	end
	K.b(0, 6.5, 1.6, 10, 0.5, 0.9, c, "Metal")
	K.b(0, 0.3, 2.0, 8.4, 0.3, 0.7, PAL.metalEsc, "Metal", { colide = false })
	K.b(3.5, 0.3, -1.8, 1.6, 1.4, 0.8, PAL.grafite, "Metal")
	return K.fim()
end

M.compressor = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "compressor")
	local c = cor(op, PAL.vermelho)
	K.b(0, 0, 0, 2.6, 0.3, 1.8, PAL.grafite, "Metal")
	K.cx(0, 1.3, 0, 1.4, 1.2, c, "Metal")
	K.e(-0.6, 1.3, 0, 1.4, c, "Metal")
	K.e(0.6, 1.3, 0, 1.4, c, "Metal")
	K.b(0.3, 2.0, -0.2, 1.4, 1.2, 1.1, PAL.metalEsc, "Metal")
	K.c(-0.6, 2.0, 0.0, 0.5, 0.3, PAL.aco, "Metal")
	K.c(-0.6, 2.5, 0.0, 0.3, 0.7, PAL.aco, "Metal")
	K.b(1.0, 2.7, -0.1, 0.5, 0.3, 0.2, PAL.preto, "Metal")
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- ESCRITÓRIO / RECEPÇÃO
-- ---------------------------------------------------------------------------------------------------------------
M.computador = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "computador")
	local c = cor(op, PAL.creme)
	K.b(0, 0, 0.1, 1.4, 0.2, 1.2, c, "SmoothPlastic")
	K.b(0, 0.2, 0.25, 1.8, 1.4, 1.4, c, "SmoothPlastic")
	K.b(0, 0.35, -0.46, 1.4, 1.1, 0.06, PAL.grafite, "Glass", { colide = false })
	K.b(0, 0.55, -0.52, 1.0, 0.5, 0.03, { 70, 170, 110 }, "Neon", { colide = false })
	K.b(0, 0.0, -0.75, 2.0, 0.22, 0.6, c, "SmoothPlastic")
	K.b(0, 0.1, -0.9, 1.6, 0.1, 0.16, PAL.grafite, "SmoothPlastic", { colide = false })
	K.b(0.95, 1.4, 0.5, 0.3, 0.8, 0.4, PAL.creme, "SmoothPlastic")
	return K.fim()
end

M.baia_escritorio = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "baia_escritorio")
	local c = cor(op, { 112, 118, 112 })
	-- divisórias (esq., dir., fundo) — finas mas sólidas para o som
	K.b(-3.1, 0, 0, 0.4, 5, 6, c, "Fabric")
	K.b(3.1, 0, 0, 0.4, 5, 6, c, "Fabric")
	K.b(0, 0, 2.8, 6.5, 5, 0.4, c, "Fabric")
	K.b(-3.1, 4.8, 0, 0.5, 0.2, 6, PAL.metalEsc, "Metal", { colide = false })
	K.b(3.1, 4.8, 0, 0.5, 0.2, 6, PAL.metalEsc, "Metal", { colide = false })
	K.b(0, 4.8, 2.8, 6.5, 0.2, 0.5, PAL.metalEsc, "Metal", { colide = false })
	-- mesa em L e gaveteiro
	K.b(0.3, 2.3, 1.9, 5.4, 0.2, 1.8, PAL.madeiraCl, "WoodPlanks")
	K.b(-1.9, 2.3, -0.6, 1.6, 0.2, 3.2, PAL.madeiraCl, "WoodPlanks")
	K.b(2.3, 0, 1.9, 1.4, 2.3, 1.6, PAL.metal, "Metal")
	K.b(-2.2, 0, 1.9, 0.2, 2.3, 1.6, PAL.metal, "Metal")
	K.b(-2.5, 0, -1.8, 0.2, 2.3, 0.2, PAL.metal, "Metal")
	K.b(-1.4, 0, -1.8, 0.2, 2.3, 0.2, PAL.metal, "Metal")
	-- computador, papéis, telefone
	local pc = ctx.lib and nil
	K.b(-0.4, 2.5, 1.9, 1.6, 1.4, 1.2, PAL.creme, "SmoothPlastic")
	K.b(-0.4, 2.8, 1.28, 1.2, 0.8, 0.05, { 70, 170, 110 }, "Neon", { colide = false })
	K.b(-0.4, 2.5, 1.0, 1.6, 0.12, 0.5, PAL.grafite, "SmoothPlastic", { colide = false })
	K.b(1.6, 2.5, 1.9, 0.9, 0.1, 0.7, PAL.branco, "Fabric", { colide = false })
	-- cadeira
	K.b(-0.2, 0, -0.2, 1.7, 1.6, 1.7, PAL.grafite, "Fabric")
	K.b(-0.2, 1.6, 0.5, 1.7, 1.9, 0.3, PAL.grafite, "Fabric")
	return K.fim()
end

M.mesa_escritorio = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_escritorio")
	local c = cor(op, PAL.madeira)
	K.b(0, 2.1, 0, 6, 0.2, 3, c, "WoodPlanks")
	K.b(-2.5, 0, 0, 0.3, 2.1, 2.8, PAL.metalEsc, "Metal")
	K.b(2.2, 0, 0, 1.4, 2.1, 2.6, c, "Wood")
	K.b(2.2, 1.4, -1.32, 1.1, 0.35, 0.05, PAL.aco, "Metal", { colide = false })
	K.b(2.2, 0.8, -1.32, 1.1, 0.35, 0.05, PAL.aco, "Metal", { colide = false })
	K.b(2.2, 0.1, -1.32, 1.1, 0.35, 0.05, PAL.aco, "Metal", { colide = false })
	K.b(0, 0, 1.2, 4, 1.6, 0.1, esc(c, 0.8), "Wood")
	K.b(-0.5, 2.3, 0.3, 1.0, 0.15, 0.8, PAL.branco, "Fabric", { colide = false })
	K.b(1.2, 2.3, 0.5, 0.6, 0.4, 0.5, PAL.grafite, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.mesa_reuniao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_reuniao")
	local w, h, d = dim(op, 12, 2.7, 5)
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, h - 0.25, 0, w, 0.25, d, c, "WoodPlanks")
	K.b(0, h - 0.4, 0, w - 0.6, 0.15, d - 0.6, PAL.grafite, "Wood")
	for _, s in { -1, 1 } do
		K.b(s * (w / 2 - 1.4), 0, 0, 0.6, h - 0.4, d - 1.4, c, "Wood")
		K.b(s * (w / 2 - 1.4), 0, 0, 1.6, 0.3, d - 0.8, PAL.grafite, "Wood")
	end
	K.b(0, h, 0, 1.6, 0.05, 1.2, PAL.grafite, "SmoothPlastic", { colide = false })
	K.b(w / 4, h, -0.5, 0.9, 0.05, 0.7, PAL.branco, "Fabric", { colide = false })
	K.b(-w / 4, h, 0.5, 0.9, 0.05, 0.7, PAL.branco, "Fabric", { colide = false })
	return K.fim()
end

M.balcao_recepcao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "balcao_recepcao")
	local w, h, d = dim(op, 10, 3.6, 2.6)
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0.3, w, 3.1, d - 0.6, c, "Wood")
	K.b(0, 0, -d / 2 + 0.3, w - 0.4, 0.3, 0.6, PAL.grafite, "Wood")
	K.b(0, 3.1, -0.1, w, 0.25, d - 0.2, PAL.pedra, "Marble")
	K.b(0, 3.35, 0.5, w, h - 3.35, d / 2 - 0.5, c, "Wood")
	local n = math.max(2, math.floor(w / 3.3))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		K.b(x, 0.6, -d / 2 + 0.38, w / n - 0.7, 2.2, 0.1, esc(c, 1.3), "Wood", { colide = false })
	end
	K.b(w / 4, 3.35, -0.5, 0.5, 0.2, 0.5, PAL.aco, "Metal", { colide = false })
	K.b(-w / 4, 3.35, -0.3, 0.9, 0.15, 0.6, PAL.branco, "Fabric", { colide = false })
	return K.fim()
end

M.sofa_recepcao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "sofa_recepcao")
	local c = cor(op, PAL.azul)
	K.b(0, 0.35, 0, 6.5, 1.1, 2.8, c, "Fabric")
	K.b(0, 1.45, 1.1, 5.5, 1.45, 0.6, c, "Fabric")
	for _, s in { -1, 1 } do
		K.b(s * 3.0, 1.45, 0, 0.5, 0.9, 2.8, esc(c, 0.85), "Fabric")
		K.b(s * 2.9, 0, -1.2, 0.3, 0.35, 0.3, PAL.preto, "Metal")
		K.b(s * 2.9, 0, 1.2, 0.3, 0.35, 0.3, PAL.preto, "Metal")
	end
	K.b(-1.4, 1.45, -0.4, 2.6, 0.4, 1.4, esc(c, 1.15), "Fabric")
	K.b(1.4, 1.45, -0.4, 2.6, 0.4, 1.4, esc(c, 1.15), "Fabric")
	return K.fim()
end

M.arquivo_alto = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "arquivo_alto")
	local c = cor(op, PAL.metal)
	K.b(0, 0, 0, 2.6, 0.3, 2.4, PAL.grafite, "Metal")
	K.b(0, 0.3, 0, 2.6, 5.9, 2.4, c, "Metal")
	for i = 0, 4 do
		K.b(0, 0.45 + i * 1.15, -1.22, 2.3, 1.0, 0.04, esc(c, 1.12), "Metal", { colide = false })
		K.b(0, 0.95 + i * 1.15, -1.24, 0.9, 0.12, 0.1, PAL.preto, "Metal")
		K.b(0, 0.7 + i * 1.15, -1.22, 0.6, 0.2, 0.03, PAL.branco, "Foil", { colide = false })
	end
	return K.fim()
end

M.copiadora = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "copiadora")
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, 3, 1.8, 2.4, PAL.grafite, "Metal")
	K.b(0, 1.8, 0, 3, 0.9, 2.4, c, "SmoothPlastic")
	K.b(0, 2.7, 0.1, 3, 0.2, 2.2, PAL.aco, "Metal")
	K.b(0, 2.9, 0.1, 2.8, 0.1, 2.0, PAL.vidro, "Glass", { transparencia = 0.5 })
	K.b(0.9, 2.7, -1.0, 1.0, 0.7, 0.3, PAL.grafite, "SmoothPlastic", { rot = CFrame.Angles(0.5, 0, 0) })
	K.b(-0.6, 1.9, -0.95, 1.6, 0.15, 0.5, PAL.branco, "Fabric", { colide = false })
	K.b(-1.0, 1.0, -1.22, 1.0, 0.4, 0.04, PAL.metal, "Metal", { colide = false })
	return K.fim()
end

M.bebedouro = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "bebedouro")
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, 1.6, 2.8, 1.6, c, "SmoothPlastic")
	K.b(0, 2.8, 0, 1.6, 0.12, 1.6, PAL.aco, "Metal")
	K.c(0, 2.92, 0, 1.2, 1.3, PAL.azul, "Glass", { transparencia = 0.45 })
	K.b(0.2, 1.8, -0.72, 0.3, 0.3, 0.2, PAL.vermelho, "SmoothPlastic")
	K.b(-0.2, 1.8, -0.72, 0.3, 0.3, 0.2, PAL.azul, "SmoothPlastic")
	K.b(0, 1.0, -0.72, 1.0, 0.2, 0.2, PAL.aco, "Metal")
	return K.fim()
end

M.quadro_branco = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "quadro_branco")
	local w, h, d = dim(op, 6, 4, 0.3)
	K.b(0, 0, -(d - 0.06) / 2, w, h, d - 0.06, PAL.aco, "Metal")
	K.b(0, 0.15, -d + 0.03, w - 0.3, h - 0.3, 0.06, PAL.branco, "SmoothPlastic")
	K.b(0, 0, -d + 0.1, w - 0.4, 0.15, 0.2, PAL.aco, "Metal", { colide = false })
	K.b(-w / 4, h * 0.55, -d + 0.01, w * 0.3, 0.08, 0.02, { 60, 90, 160 }, "SmoothPlastic", { colide = false })
	K.b(w / 6, h * 0.65, -d + 0.01, w * 0.25, 0.08, 0.02, { 170, 60, 60 }, "SmoothPlastic", { colide = false })
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- HOSPITAL / DELEGACIA / ESCOLA
-- ---------------------------------------------------------------------------------------------------------------
M.maca_hospital = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "maca_hospital")
	local c = cor(op, PAL.branco)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.cx(sx * 1.2, 0.2, sz * 3.0, 0.4, 0.2, PAL.preto, "SmoothPlastic")
		end
		K.b(sx * 1.2, 0.3, 0, 0.2, 0.3, 6.2, PAL.aco, "Metal")
	end
	K.b(0, 0.6, 0, 2.8, 0.25, 6.6, PAL.metal, "Metal")
	K.b(0, 0.85, 0.1, 2.8, 0.55, 6.4, PAL.hospital, "Fabric")
	K.b(0, 1.4, 2.8, 2.0, 0.35, 1.2, PAL.branco, "Fabric")
	K.b(0, 1.4, -0.5, 2.8, 0.35, 4.6, c, "Fabric")
	for _, s in { -1, 1 } do
		K.b(s * 1.5, 1.4, 0.3, 0.1, 0.6, 3.0, PAL.aco, "Metal")
	end
	K.c(0, 0.2, -3.3, 0.25, 3.0, PAL.aco, "Metal", { colide = false })
	return K.fim()
end

M.cama_hospital = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cama_hospital")
	local c = cor(op, PAL.branco)
	K.b(0, 0.5, 0, 3.0, 0.3, 7.0, PAL.aco, "Metal")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.cx(sx * 1.4, 0.25, sz * 3.2, 0.5, 0.25, PAL.preto, "SmoothPlastic")
		end
	end
	K.b(0, 0.8, 0, 3.0, 0.6, 7.0, PAL.hospital, "Fabric")
	K.b(0, 1.4, 1.2, 3.0, 0.3, 5.0, c, "Fabric")
	K.b(0, 1.4, -2.3, 3.0, 0.3, 2.6, PAL.hospital, "Fabric")
	K.b(0, 1.4, 2.8, 2.2, 0.5, 1.1, PAL.branco, "Fabric")
	K.b(0, 0.7, 3.5, 3.4, 2.7, 0.2, PAL.aco, "Metal")
	K.b(0, 0.9, -3.6, 3.4, 1.6, 0.2, PAL.aco, "Metal")
	for _, s in { -1, 1 } do
		K.b(s * 1.6, 1.7, 0.3, 0.1, 1.0, 3.6, PAL.aco, "Metal")
	end
	K.b(1.7, 2.0, -3.7, 0.3, 0.8, 0.3, PAL.grafite, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.armario_medico = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "armario_medico")
	local c = cor(op, PAL.branco)
	K.b(0, 0, 0, 3.4, 0.4, 1.6, PAL.grafite, "Metal")
	K.b(0, 0.4, 0, 3.4, 5.6, 1.6, c, "Metal")
	for _, s in { -1, 1 } do
		K.b(s * 0.85, 2.3, -0.77, 1.6, 3.4, 0.06, PAL.vidro, "Glass", { transparencia = 0.5 })
		K.b(s * 0.1, 3.4, -0.82, 0.12, 1.2, 0.12, PAL.aco, "Metal")
	end
	for i = 0, 2 do
		K.b(0, 2.5 + i * 1.1, -0.1, 3.0, 0.1, 1.2, PAL.aco, "Metal", { colide = false })
		K.b(-0.9 + i * 0.8, 2.6 + i * 1.1, -0.1, 0.6, 0.5, 0.5, PROD[i + 3], "SmoothPlastic", { colide = false })
	end
	K.b(0, 0.9, -0.77, 3.0, 1.4, 0.06, esc(c, 0.9), "Metal", { colide = false })
	K.b(0, 1.2, -0.80, 0.9, 0.6, 0.04, PAL.vermelho, "SmoothPlastic", { colide = false })
	K.b(0, 1.3, -0.82, 0.2, 0.4, 0.04, PAL.branco, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.cortina_hospital = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cortina_hospital")
	local w, h, d = dim(op, 7, 6.5, 0.4)
	local c = cor(op, PAL.hospital)
	for _, s in { -1, 1 } do
		K.b(s * (w / 2 - 0.15), 0, 0, 0.3, h, 0.3, PAL.aco, "Metal")
		K.b(s * (w / 2 - 0.15), 0, 0, 0.6, 0.15, 0.4, PAL.aco, "Metal")
	end
	K.b(0, h - 0.2, 0, w, 0.2, 0.3, PAL.aco, "Metal", { colide = false })
	local n = math.max(2, math.floor((w - 0.8) / 1.0))
	local larg = (w - 0.8) / n
	for i = 0, n - 1 do
		K.b(
			-w / 2 + 0.4 + (i + 0.5) * larg,
			1.0,
			if i % 2 == 0 then -0.1 else 0.1,
			larg,
			h - 1.2,
			0.12,
			if i % 2 == 0 then c else esc(c, 0.9),
			"Fabric",
			{ colide = false }
		)
	end
	return K.fim()
end

M.mesa_cirurgia = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_cirurgia")
	local c = cor(op, PAL.aco)
	K.b(0, 0, 0, 2.6, 0.3, 5.6, PAL.grafite, "Metal")
	K.b(0, 0.3, 0, 0.8, 2.0, 0.8, c, "Metal")
	K.b(0, 2.3, 0, 1.2, 0.3, 2.0, c, "Metal")
	K.b(0, 2.6, 0, 3.2, 0.3, 6.4 + 0.6, c, "Metal")
	K.b(0, 2.9, 0.4, 2.8, 0.25, 4.6, PAL.hospital, "Fabric")
	K.b(0, 2.9, 3.1, 1.4, 0.25, 0.8, PAL.hospital, "Fabric")
	K.b(-1.55, 2.9, -0.5, 0.15, 0.3, 2.0, PAL.metalEsc, "Metal")
	K.b(1.55, 2.9, -0.5, 0.15, 0.3, 2.0, PAL.metalEsc, "Metal")
	return K.fim()
end

M.cadeira_rodas = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cadeira_rodas")
	local c = cor(op, PAL.grafite)
	for _, s in { -1, 1 } do
		K.cx(s * 1.1, 1.2, 0.3, 2.4, 0.25, PAL.preto, "Slate")
		K.cx(s * 1.1, 1.2, 0.3, 1.6, 0.3, PAL.aco, "Metal", { colide = false })
		K.cx(s * 1.0, 0.35, -1.15, 0.7, 0.25, PAL.preto, "Slate")
		K.b(s * 0.9, 1.9, 0.2, 0.15, 0.15, 1.5, PAL.aco, "Metal")
		K.b(s * 1.0, 1.5, 1.25, 0.2, 1.9, 0.2, PAL.aco, "Metal")
	end
	K.b(0, 1.5, 0.0, 1.8, 0.25, 1.7, c, "Fabric")
	K.b(0, 1.8, 0.85, 1.8, 1.4, 0.2, c, "Fabric")
	K.b(0, 3.0, 1.35, 2.2, 0.15, 0.3, PAL.preto, "SmoothPlastic")
	K.b(0, 0.6, -0.5, 1.4, 0.15, 0.9, PAL.aco, "Metal")
	return K.fim()
end

M.cela_grade = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cela_grade")
	local c = cor(op, PAL.metalEsc)
	local fechada = op and op.variante == 2
	-- paredes de concreto (fundo e laterais)
	K.b(0, 0, 3.6, 8, 8, 0.8, PAL.concreto, "Concrete")
	K.b(-3.8, 0, -0.4, 0.4, 8, 7.2, PAL.concreto, "Concrete")
	K.b(3.8, 0, -0.4, 0.4, 8, 7.2, PAL.concreto, "Concrete")
	-- frente gradeada: batentes, barras a cada ~0,85 (vão < 0,6: ninguém passa), travessas
	K.b(-2.1, 0, -3.8, 0.4, 8, 0.4, c, "Metal")
	K.b(2.1, 0, -3.8, 0.4, 8, 0.4, c, "Metal")
	K.b(0, 7.6, -3.8, 8, 0.4, 0.4, c, "Metal")
	local xs = { -3.55, -2.75, 2.75, 3.55 }
	for _, x in xs do
		K.c(x, 0, -3.8, 0.3, 7.6, c, "Metal")
	end
	for _, s in { -1, 1 } do
		K.b(s * 3.0, 0.2, -3.8, 1.9, 0.3, 0.35, c, "Metal")
		K.b(s * 3.0, 3.8, -3.8, 1.9, 0.3, 0.35, c, "Metal")
	end
	if fechada then
		for _, x in { -1.3, -0.45, 0.45, 1.3 } do
			K.c(x, 0, -3.8, 0.3, 7.6, c, "Metal")
		end
		K.b(0, 3.8, -3.8, 4.2, 0.3, 0.35, c, "Metal")
		K.b(0, 0.0, -3.8, 4.2, 0.3, 0.35, c, "Metal")
	else
		-- porta aberta, encostada na lateral esquerda (não colide)
		K.b(-3.4, 0.2, -2.0, 0.2, 7.2, 3.6, c, "Metal", { transparencia = 0.5, colide = false })
	end
	-- beliche à direita
	for _, sz in { -1, 1 } do
		for _, sx in { 2.0, 3.5 } do
			K.b(sx, 0, 0 + sz * 2.8, 0.3, 5.0, 0.3, PAL.metal, "Metal")
		end
	end
	K.b(2.75, 1.5, 0, 1.6, 0.3, 6.2, PAL.lona, "Fabric")
	K.b(2.75, 3.4, 0, 1.6, 0.3, 6.2, PAL.lona, "Fabric")
	-- vaso e pia no canto esquerdo
	K.c(-2.9, 0, 2.5, 1.2, 1.3, PAL.branco, "SmoothPlastic")
	K.b(-3.45, 1.3, 2.5, 0.4, 1.4, 1.0, PAL.aco, "Metal")
	K.b(-3.45, 2.6, 0.5, 0.5, 0.8, 1.2, PAL.aco, "Metal")
	return K.fim()
end

M.mesa_delegacia = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_delegacia")
	local c = cor(op, PAL.metal)
	K.b(0, 2.1, 0, 6, 0.2, 3, PAL.madeiraEsc, "WoodPlanks")
	K.b(-2.3, 0, 0, 1.2, 2.1, 2.8, c, "Metal")
	K.b(2.3, 0, 0, 1.2, 2.1, 2.8, c, "Metal")
	K.b(0, 0.8, 1.2, 3.4, 1.3, 0.15, esc(c, 0.8), "Metal")
	K.b(-0.2, 2.3, -0.2, 1.2, 0.1, 0.9, PAL.branco, "Fabric", { colide = false })
	K.b(1.4, 2.3, 0.5, 0.7, 0.35, 0.7, PAL.grafite, "SmoothPlastic", { colide = false })
	K.b(-1.5, 2.3, 0.6, 0.5, 0.4, 0.3, { 80, 140, 90 }, "SmoothPlastic", { colide = false })
	K.b(0.8, 2.3, -1.0, 1.0, 0.25, 0.3, PAL.amarelo, "Metal", { colide = false })
	K.b(-2.3, 2.3, -0.4, 0.5, 0.4, 0.5, PAL.aco, "Metal", { colide = false })
	return K.fim()
end

M.armario_armas = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "armario_armas")
	local c = cor(op, PAL.industrial)
	K.b(0, 0, 0, 4, 6.5, 1.6, c, "Metal")
	for _, s in { -1, 1 } do
		K.b(s * 0.95, 0.6, -0.77, 1.8, 5.3, 0.06, esc(c, 1.15), "Metal", { colide = false })
		K.b(s * 0.2, 3.0, -0.82, 0.12, 0.6, 0.12, PAL.aco, "Metal")
	end
	K.b(0, 3.4, -0.82, 0.4, 0.3, 0.12, PAL.amarelo, "Metal")
	K.b(0, 0.15, -0.77, 3.6, 0.35, 0.04, PAL.grafite, "Metal", { colide = false })
	K.b(0, 6.0, -0.77, 3.4, 0.35, 0.04, PAL.vermelho, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.carteira_escolar = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "carteira_escolar")
	local c = cor(op, PAL.madeiraCl)
	K.b(0, 2.5, -0.5, 2.6, 0.2, 1.0, c, "WoodPlanks")
	K.b(-1.1, 0, -0.5, 0.15, 2.5, 0.8, PAL.metalEsc, "Metal")
	K.b(1.1, 0, -0.5, 0.15, 2.5, 0.8, PAL.metalEsc, "Metal")
	K.b(0, 1.3, -0.5, 2.2, 0.1, 0.8, PAL.metalEsc, "Metal", { colide = false })
	K.b(0, 1.4, 0.3, 1.6, 0.2, 1.4, c, "Wood")
	K.b(0, 1.6, 0.9, 1.6, 1.2, 0.2, c, "Wood")
	K.b(-0.7, 0, 0.3, 0.12, 1.4, 1.2, PAL.metalEsc, "Metal")
	K.b(0.7, 0, 0.3, 0.12, 1.4, 1.2, PAL.metalEsc, "Metal")
	K.b(0.2, 2.7, -0.6, 0.8, 0.08, 0.6, PAL.branco, "Fabric", { colide = false })
	return K.fim()
end

M.mesa_professor = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_professor")
	local c = cor(op, PAL.madeira)
	K.b(0, 2.3, 0, 5, 0.2, 2.6, c, "WoodPlanks")
	K.b(-2.2, 0, 0, 0.5, 2.3, 2.4, c, "Wood")
	K.b(2.0, 0, 0, 1.1, 2.3, 2.4, c, "Wood")
	K.b(0, 0.4, 1.1, 3.9, 1.9, 0.15, esc(c, 0.8), "Wood")
	K.b(2.0, 1.6, -1.22, 0.8, 0.4, 0.05, PAL.aco, "Metal", { colide = false })
	K.b(-0.8, 2.5, 0.2, 1.0, 0.25, 0.7, PROD[2], "SmoothPlastic", { colide = false })
	K.b(1.2, 2.5, 0.4, 0.4, 0.3, 0.4, PAL.vermelho, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.lousa = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "lousa")
	local w, h, d = dim(op, 10, 4.5, 0.4)
	K.b(0, 0, -(d - 0.06) / 2, w, h, d - 0.06, PAL.madeiraEsc, "Wood")
	K.b(0, 0.35, -d + 0.03, w - 0.6, h - 0.7, 0.06, { 40, 62, 50 }, "Slate")
	K.b(0, 0, -d + 0.1, w - 0.6, 0.25, 0.2, PAL.madeiraCl, "Wood", { colide = false })
	K.b(-w / 3, 0.25, -d + 0.1, 0.8, 0.2, 0.2, PAL.branco, "Fabric", { colide = false })
	K.b(-w / 6, h * 0.55, -d + 0.01, w * 0.3, 0.08, 0.02, PAL.branco, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.armario_escola = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "armario_escola")
	local c = cor(op, PAL.madeira)
	K.b(0, 0, 0, 4, 6.5, 1.6, c, "Wood")
	for _, s in { -1, 1 } do
		K.b(s * 0.98, 0.3, -0.77, 1.9, 5.9, 0.06, esc(c, 1.2), "Wood", { colide = false })
		K.b(s * 0.2, 3.0, -0.82, 0.12, 0.6, 0.12, PAL.aco, "Metal")
	end
	K.b(0, 0.0, -0.8, 4, 0.3, 0.04, PAL.madeiraEsc, "Wood", { colide = false })
	K.b(0, 6.4, -0.8, 4.1, 0.1, 0.04, PAL.madeiraEsc, "Wood", { colide = false })
	return K.fim()
end

M.estante_biblioteca = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "estante_biblioteca")
	local w, h, d = dim(op, 6, 8, 1.8)
	local c = cor(op, PAL.madeiraEsc)
	estante(K, w, h, d, 4, c, "Wood", c, "Wood", function(i, xa, xb, y, esp, zc, prof)
		local m = (xa + xb) / 2
		local lg = (xb - xa) / 2
		local alt = math.min(esp - 0.35, 1.6)
		K.b(xa + lg * 0.5, y, zc, lg - 0.1, alt, prof - 0.2, PROD[(i * 2) % #PROD + 1], "Fabric")
		K.b(xb - lg * 0.5, y, zc, lg - 0.1, alt * 0.8, prof - 0.2, PROD[(i * 2 + 3) % #PROD + 1], "Fabric")
		_ = m
	end)
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- IGREJA / CULTO
-- ---------------------------------------------------------------------------------------------------------------
M.banco_igreja = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "banco_igreja")
	local w, h, d = dim(op, 10, 3.4, 2.4)
	local c = cor(op, PAL.madeiraEsc)
	for _, s in { -1, 1 } do
		K.b(s * (w / 2 - 0.2), 0, 0, 0.4, h, d, c, "Wood")
	end
	K.b(0, 1.4, -0.1, w - 0.8, 0.25, 1.7, esc(c, 1.2), "WoodPlanks")
	K.b(0, 1.65, d / 2 - 0.2, w - 0.8, h - 1.65, 0.3, esc(c, 1.1), "WoodPlanks")
	K.b(0, 0.3, -d / 2 + 0.15, w - 0.8, 1.1, 0.12, c, "Wood")
	K.b(0, 0.3, d / 2 - 0.2, w - 0.8, 1.1, 0.12, c, "Wood")
	K.b(0, 0.0, 0.0, w - 0.8, 0.3, d - 0.2, esc(c, 0.7), "Wood", { colide = false })
	return K.fim()
end

M.altar = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "altar")
	local c = cor(op, PAL.pedra)
	K.b(0, 0, 0, 7, 0.4, 3, esc(c, 0.85), "Slate")
	K.b(0, 0.4, 0, 6.2, 2.5, 2.4, c, "Marble")
	K.b(0, 2.9, 0, 7, 0.3, 3, esc(c, 1.15), "Marble")
	K.b(0, 0.6, -1.23, 3.2, 2.1, 0.06, PAL.branco, "Fabric", { colide = false })
	K.b(0, 2.9, -0.2, 3.6, 0.04, 1.8, PAL.branco, "Fabric", { colide = false })
	K.b(0, 1.7, -1.28, 0.3, 1.0, 0.05, PAL.amarelo, "Metal", { colide = false })
	K.b(0, 1.95, -1.28, 0.8, 0.3, 0.05, PAL.amarelo, "Metal", { colide = false })
	for _, s in { -1, 1 } do
		K.c(s * 2.6, 3.2, 0, 0.4, 0.4, PAL.creme, "SmoothPlastic")
	end
	K.b(0, 3.2, 0.5, 0.5, 0.4, 0.3, PAL.amarelo, "Metal", { colide = false })
	return K.fim()
end

M.pulpito = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "pulpito")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0, 3, 0.4, 2.6, esc(c, 0.8), "Wood")
	K.b(0, 0.4, 0.2, 2.2, 3.5, 1.8, c, "Wood")
	K.b(0, 0.7, -0.72, 1.6, 2.5, 0.06, esc(c, 1.25), "Wood", { colide = false })
	K.r(0, 3.9, -1.1, 0, 4.6, 0.9, 2.8, 0.3, esc(c, 1.15), "Wood")
	K.b(0, 4.25, -0.1, 2.0, 0.15, 0.9, PAL.creme, "Fabric", { colide = false, rot = CFrame.Angles(0.33, 0, 0) })
	return K.fim()
end

M.pia_batismal = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "pia_batismal")
	local c = cor(op, PAL.pedra)
	K.c(0, 0, 0, 2.6, 0.3, esc(c, 0.85), "Slate")
	K.c(0, 0.3, 0, 1.1, 1.8, c, "Marble")
	K.c(0, 2.1, 0, 2.4, 0.7, c, "Marble")
	K.c(0, 2.7, 0, 2.0, 0.1, PAL.azul, "Glass", { transparencia = 0.3, colide = false })
	K.c(0, 2.8, 0, 2.2, 0.15, esc(c, 1.15), "Marble", { colide = false })
	K.e(0, 3.15, 0, 0.6, PAL.amarelo, "Metal", { colide = false })
	return K.fim()
end

M.candelabro = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "candelabro")
	local c = cor(op, PAL.amarelo)
	K.c(0, 0, 0, 1.6, 0.25, c, "Metal")
	K.c(0, 0.25, 0, 0.35, 3.6, c, "Metal")
	K.c(0, 1.2, 0, 0.7, 0.2, c, "Metal", { colide = false })
	K.b(0, 3.8, 0, 1.6, 0.15, 0.2, c, "Metal", { colide = false })
	for _, x in { -0.7, 0, 0.7 } do
		K.c(x, 3.95, 0, 0.3, 0.8, PAL.creme, "SmoothPlastic", { colide = false })
		K.b(x, 4.75, 0, 0.12, 0.25, 0.12, { 255, 200, 90 }, "Neon", { colide = false })
	end
	return K.fim()
end

M.cruz_parede = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cruz_parede")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, -0.2, 0.7, 4.6, 0.4, c, "Wood")
	K.b(0, 2.8, -0.2, 3, 0.7, 0.4, c, "Wood")
	K.b(0, 0.2, -0.42, 0.25, 4.2, 0.04, esc(c, 1.3), "Wood", { colide = false })
	return K.fim()
end

M.orgao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "orgao")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0.7, 7, 8.5, 1.6, c, "Wood")
	local alturas = { 4.5, 6, 7.4, 8.2, 7.4, 6, 4.5 }
	for i, hh in alturas do
		K.c(-2.7 + (i - 1) * 0.9, 1.0, 0.3, 0.7, hh - 1.0, PAL.aco, "Metal")
	end
	K.b(0, 0, -0.8, 7, 2.6, 1.4, c, "Wood")
	K.b(0, 2.6, -0.8, 7.2, 0.2, 1.6, esc(c, 1.2), "Wood")
	K.b(0, 2.8, -1.2, 5, 0.12, 0.8, PAL.creme, "SmoothPlastic")
	K.b(0, 2.9, -1.3, 5, 0.1, 0.35, PAL.preto, "SmoothPlastic", { colide = false })
	K.b(0, 0, -1.45, 3, 1.3, 0.08, esc(c, 0.7), "Wood", { colide = false })
	return K.fim()
end

M.confessionario = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "confessionario")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0, 0, 4.6, 0.4, 3, esc(c, 0.7), "Wood")
	K.b(0, 0.4, 1.4, 4.6, 6.0, 0.2, c, "Wood")
	for _, s in { -1, 1 } do
		K.b(s * 1.1, 0.4, 0, 0.2, 6.6, 2.9, c, "Wood")
		K.b(s * 2.25, 0.4, 0, 0.2, 5.6, 2.9, c, "Wood")
		K.b(s * 1.7, 0.4, -1.4, 1.0, 5.6, 0.2, esc(c, 1.1), "Wood")
		K.b(s * 1.7, 0.4, -1.45, 1.1, 4.6, 0.08, PAL.couro, "Fabric", { colide = false })
		K.b(s * 1.7, 0.4, -0.5, 1.0, 1.0, 0.8, esc(c, 0.85), "Wood")
		K.b(s * 1.1, 3.0, 0.0, 0.25, 1.6, 0.9, PAL.preto, "Wood", { colide = false })
	end
	K.b(0, 6.8, 0, 2.6, 0.7, 3, esc(c, 1.15), "Wood")
	K.b(0, 0.4, -1.4, 2.0, 6.0, 0.15, esc(c, 1.2), "Wood", { colide = false })
	K.b(-1.7, 6.0, 0, 1.2, 0.2, 3, c, "Wood")
	K.b(1.7, 6.0, 0, 1.2, 0.2, 3, c, "Wood")
	return K.fim()
end

M.caixao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "caixao")
	local c = cor(op, PAL.madeiraEsc)
	K.b(0, 0.3, 1.9, 1.7, 1.7, 3.2, c, "Wood")
	K.b(0, 0.3, -0.2, 2.6, 1.7, 2.2, c, "Wood")
	K.b(0, 0.3, -2.2, 2.0, 1.7, 2.0, c, "Wood")
	K.b(0, 0, 0.0, 2.2, 0.3, 6.6, PAL.grafite, "Wood")
	K.b(0, 2.0, 1.9, 1.5, 0.2, 3.0, esc(c, 1.2), "Wood")
	K.b(0, 2.0, -0.2, 2.4, 0.2, 2.0, esc(c, 1.2), "Wood")
	K.b(0, 2.0, -2.2, 1.8, 0.2, 1.8, esc(c, 1.2), "Wood")
	K.b(0, 2.2, -0.1, 0.3, 0.04, 2.0, PAL.amarelo, "Metal", { colide = false })
	K.b(0, 2.2, -0.5, 1.2, 0.04, 0.3, PAL.amarelo, "Metal", { colide = false })
	for _, s in { -1, 1 } do
		K.b(s * 1.32, 1.0, -0.2, 0.1, 0.2, 0.8, PAL.amarelo, "Metal", { colide = false })
		K.b(s * 1.05, 1.0, 2.4, 0.1, 0.2, 0.8, PAL.amarelo, "Metal", { colide = false })
	end
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- INDUSTRIAL / RURAL
-- ---------------------------------------------------------------------------------------------------------------
M.estante_industrial = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "estante_industrial")
	local w, h, d = dim(op, 8, 7, 2.4)
	local c = cor(op, PAL.azul)
	estante(K, w, h, d, 4, c, "Metal", PAL.laranja, "Metal", function(i, xa, xb, y, esp, zc, prof)
		local lg = (xb - xa) / 2
		for j = 0, 1 do
			local hh = math.min(esp - 0.4, 1.0 + ((i + j) % 3) * 0.4)
			K.b(
				xa + lg * (j + 0.5),
				y,
				zc,
				lg - 0.25,
				hh,
				prof - 0.3,
				if (i + j) % 2 == 0 then PAL.papelao else PAL.madeiraCl,
				"Wood"
			)
		end
	end)
	return K.fim()
end

M.palete = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "palete")
	local c = cor(op, PAL.madeiraCl)
	for _, z in { -2.1, 0, 2.1 } do
		K.b(0, 0, z, 5, 0.5, 0.8, esc(c, 0.85), "Wood")
	end
	for i = 0, 4 do
		K.b(0, 0.5, -2.1 + i * 1.05, 5, 0.4, 0.8, c, "WoodPlanks")
	end
	return K.fim()
end

M.pilha_caixotes = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "pilha_caixotes")
	local w, h, d = dim(op, 5, 5, 5)
	local c = cor(op, PAL.madeiraCl)
	local function caixote(x, y, z, a, b, e)
		K.b(x, y, z, a, b, e, c, "WoodPlanks")
		K.b(x, y + 0.05, z - e / 2 - 0.02, a + 0.04, 0.3, 0.06, esc(c, 0.6), "Wood", { colide = false })
		K.b(x, y + b - 0.35, z - e / 2 - 0.02, a + 0.04, 0.3, 0.06, esc(c, 0.6), "Wood", { colide = false })
	end
	local u = w / 5
	caixote(-1.3 * u, 0, -1.2 * u, 2.4 * u, 2.2 * h / 5, 2.4 * u)
	caixote(1.2 * u, 0, -1.3 * u, 2.4 * u, 2.4 * h / 5, 2.2 * u)
	caixote(-0.2 * u, 0, 1.3 * u, 2.6 * u, 2.2 * h / 5, 2.2 * u)
	caixote(-1.3 * u, 2.2 * h / 5, -1.2 * u, 2.2 * u, 2.3 * h / 5, 2.2 * u)
	caixote(0.6 * u, 2.4 * h / 5, -1.2 * u, 1.9 * u, 2.6 * h / 5, 1.9 * u)
	return K.fim()
end

M.barril = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "barril")
	local c = cor(op, PAL.ferrugem)
	K.c(0, 0, 0, 1.9, 3, c, "CorrodedMetal")
	K.c(0, 0.9, 0, 2.0, 0.12, esc(c, 0.7), "Metal", { colide = false })
	K.c(0, 1.9, 0, 2.0, 0.12, esc(c, 0.7), "Metal", { colide = false })
	K.c(0, 2.9, 0, 2.0, 0.1, esc(c, 0.7), "Metal", { colide = false })
	K.c(0.4, 3.0, 0.3, 0.3, 0.1, PAL.preto, "Metal", { colide = false })
	return K.fim()
end

M.bancada_trabalho = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "bancada_trabalho")
	local w, h, d = dim(op, 8, 3.2, 3)
	local c = cor(op, PAL.madeira)
	K.b(0, h - 0.8, 0, w, 0.4, d, c, "WoodPlanks")
	for _, s in { -1, 1 } do
		K.b(s * (w / 2 - 0.3), 0, 0, 0.5, h - 0.8, d - 0.2, PAL.metalEsc, "Metal")
	end
	K.b(0, 0.9, 0, w - 1.0, 0.2, d - 0.4, esc(c, 0.8), "Wood")
	K.b(0, 0.0, d / 2 - 0.2, w - 1.0, h - 0.8, 0.15, esc(c, 0.7), "Wood", { colide = false })
	K.b(-w / 4, h - 0.4, 0.2, 1.0, 0.4, 0.5, PAL.vermelho, "Metal", { colide = false })
	K.b(w / 6, h - 0.4, -0.5, 1.4, 0.3, 0.5, PAL.grafite, "Metal", { colide = false })
	K.b(w / 2 - 1.0, h - 0.4, 0.5, 0.7, 0.55, 0.8, PAL.metal, "Metal", { colide = false })
	return K.fim()
end

M.maquina_industrial = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "maquina_industrial")
	local c = cor(op, PAL.industrial)
	local v = (op and op.variante) or 1
	if v == 2 then
		-- torno: bancada longa, cabeçote, mandril, contraponto, carro, luminária articulada
		K.b(-2.25, 0, -0.4, 1.5, 2.2, 3.0, PAL.metalEsc, "Metal")
		K.b(2.25, 0, -0.4, 1.5, 2.2, 3.0, PAL.metalEsc, "Metal")
		K.b(0, 2.2, -0.4, 6, 0.7, 3, c, "Metal")
		K.b(-2.0, 2.9, -0.4, 2.0, 1.9, 2.6, c, "Metal")
		K.cx(-0.7, 4.2, -0.4, 1.3, 0.8, PAL.aco, "Metal")
		K.cx(0.5, 3.9, -0.4, 0.25, 2.0, PAL.aco, "Metal")
		K.b(2.1, 2.9, -0.4, 1.0, 1.3, 1.2, c, "Metal")
		K.b(0.2, 2.9, -0.9, 1.5, 0.9, 1.4, PAL.metalEsc, "Metal")
		K.b(-0.6, 2.9, -1.35, 0.9, 0.3, 0.2, PAL.vermelho, "Metal", { colide = false })
		K.c(2.7, 0, 1.6, 0.4, 4.4, PAL.grafite, "Metal")
		K.r(2.7, 4.4, 1.6, 1.6, 5.6, 0.8, 0.3, 0.3, PAL.grafite, "Metal")
		K.b(1.3, 5.3, 0.6, 0.9, 0.7, 0.9, PAL.amarelo, "Metal")
	elseif v == 3 then
		-- serra de fita
		K.b(0, 0, 0, 6, 0.7, 4, PAL.metalEsc, "Metal")
		K.b(-1.2, 0.7, 1.2, 1.4, 5.3, 1.2, c, "Metal")
		K.b(0.1, 4.6, 1.2, 4.0, 1.4, 1.2, c, "Metal")
		K.cz(-1.2, 4.9, 0.4, 2.2, 0.3, PAL.aco, "Metal")
		K.cz(-1.2, 1.7, 0.4, 2.2, 0.3, PAL.aco, "Metal")
		K.b(0.8, 1.7, 0.5, 4.0, 0.8, 2.6, PAL.aco, "DiamondPlate")
		K.b(-1.2, 1.7, 0.3, 0.1, 3.9, 0.1, PAL.grafite, "Metal", { colide = false })
		K.b(2.4, 0.7, 1.4, 1.5, 1.4, 1.5, PAL.grafite, "Metal")
		K.b(1.4, 2.5, -0.5, 2.4, 0.9, 1.0, PAL.laranja, "Metal", { transparencia = 0.5 })
		K.b(-2.3, 0.7, -1.4, 0.9, 1.2, 0.9, PAL.vermelho, "Metal")
	else
		-- prensa hidráulica
		K.b(0, 0, 0, 6, 0.8, 4, PAL.metalEsc, "Metal")
		for _, s in { -1, 1 } do
			K.b(s * 2.4, 0.8, 0, 0.9, 4.7, 1.6, c, "Metal")
		end
		K.b(0, 5.2, 0, 6, 0.8, 3.0, c, "Metal")
		K.c(0, 3.3, 0, 1.2, 1.9, PAL.aco, "Metal")
		K.b(0, 2.7, 0, 3.0, 0.6, 2.0, PAL.metal, "Metal")
		K.b(0, 0.8, 0, 3.4, 0.6, 2.4, PAL.ferrugem, "CorrodedMetal")
		K.b(0, 1.4, 0, 2.4, 1.3, 1.6, PAL.grafite, "Metal", { colide = false })
		K.b(2.6, 0.8, -1.6, 0.9, 1.4, 0.7, PAL.vermelho, "Metal")
		K.b(2.6, 1.5, -1.98, 0.5, 0.3, 0.05, { 255, 80, 60 }, "Neon", { colide = false })
	end
	return K.fim()
end

M.esteira = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "esteira")
	local w, h, d = dim(op, 20, 2.6, 3.2)
	local c = cor(op, PAL.industrial)
	local n = math.max(3, math.floor(w / 4) + 1)
	for i = 0, n - 1 do
		K.b(-w / 2 + 0.5 + i * (w - 1) / (n - 1), 0, 0, 0.5, 1.4, d - 0.4, PAL.metalEsc, "Metal")
	end
	for _, s in { -1, 1 } do
		K.b(0, 1.2, s * (d / 2 - 0.15), w, 0.6, 0.3, c, "Metal")
		K.cz(s * (w / 2 - 0.45), 1.5, 0, 0.9, d - 0.4, PAL.grafite, "Metal")
	end
	K.b(0, 1.4, 0, w - 0.9, 0.2, d - 0.7, PAL.preto, "Slate")
	for i = 1, 3 do
		K.b(-w / 2 + i * w / 4, 1.6, 0, 1.2, math.min(h - 1.6, 0.4 + (i % 2) * 0.5), 1.4, PAL.papelao, "Wood")
	end
	K.b(w / 2 - 0.8, 0, d / 2 - 0.6, 1.0, 1.2, 0.9, PAL.vermelho, "Metal", { colide = false })
	return K.fim()
end

M.tanque = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "tanque")
	local w, h, d = dim(op, 6, 9, 6)
	local c = cor(op, PAL.metal)
	local r = math.min(w, d) - 0.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.b(sx * (r / 2 - 0.5), 0, sz * (r / 2 - 0.5), 0.5, 1.8, 0.5, PAL.metalEsc, "Metal")
		end
	end
	K.c(0, 1.8, 0, r, h - 3.0, c, "CorrodedMetal")
	K.c(0, h - 1.2, 0, r * 0.7, 0.6, esc(c, 0.9), "Metal")
	K.c(0, h - 0.6, 0, r * 0.3, 0.6, PAL.metalEsc, "Metal")
	K.c(0, 3.0, 0, r + 0.2, 0.2, PAL.metalEsc, "Metal", { colide = false })
	K.c(0, 6.0, 0, r + 0.2, 0.2, PAL.metalEsc, "Metal", { colide = false })
	-- escada marinheiro e tubo
	K.b(r / 2 + 0.05, 1.8, -0.5, 0.1, h - 3.0, 0.1, PAL.aco, "Metal", { colide = false })
	K.b(r / 2 + 0.05, 1.8, 0.5, 0.1, h - 3.0, 0.1, PAL.aco, "Metal", { colide = false })
	for i = 0, 3 do
		K.b(r / 2 + 0.05, 2.5 + i * 1.5, 0, 0.1, 0.1, 1.0, PAL.aco, "Metal", { colide = false })
	end
	K.b(-0.6, 1.0, -r / 2 + 0.05, 0.6, 0.6, 0.6, PAL.vermelho, "Metal")
	return K.fim()
end

M.quadro_eletrico = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "quadro_eletrico")
	local c = cor(op, PAL.metal)
	K.b(0, 0, -0.4, 2.6, 5, 0.8, c, "Metal")
	for _, s in { -1, 1 } do
		K.b(s * 0.65, 0.3, -0.83, 1.1, 4.4, 0.06, esc(c, 1.1), "Metal", { colide = false })
	end
	K.b(0, 2.3, -0.86, 0.15, 0.7, 0.1, PAL.preto, "Metal")
	K.b(0, 3.6, -0.88, 0.9, 0.7, 0.04, PAL.amarelo, "SmoothPlastic", { colide = false })
	K.b(0, 3.6, -0.9, 0.5, 0.4, 0.03, PAL.preto, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.empilhadeira = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "empilhadeira")
	local c = cor(op, PAL.amarelo)
	for _, s in { -1, 1 } do
		K.cx(s * 1.6, 0.7, -0.3, 1.4, 0.7, PAL.preto, "Slate")
		K.cx(s * 1.6, 0.6, 3.0, 1.2, 0.7, PAL.preto, "Slate")
		K.b(s * 0.9, 0.0, -2.2, 0.5, 0.25, 3.8, PAL.metalEsc, "Metal")
		K.b(s * 0.9, 0.0, -0.2, 0.4, 6.6, 0.5, PAL.metalEsc, "Metal")
		K.b(s * 1.6, 1.6, 1.0, 0.3, 4.0, 0.3, PAL.grafite, "Metal")
		K.b(s * 1.6, 1.6, 3.4, 0.3, 4.0, 0.3, PAL.grafite, "Metal")
	end
	K.b(0, 0.9, 1.4, 3.2, 1.3, 3.6, c, "Metal")
	K.b(0, 0.9, 3.5, 3.4, 2.0, 1.0, PAL.grafite, "Metal")
	K.b(0, 2.2, 1.6, 1.8, 0.35, 1.5, PAL.grafite, "Fabric")
	K.b(0, 2.5, 2.3, 1.8, 1.2, 0.3, PAL.grafite, "Fabric")
	K.b(0, 5.6, 2.2, 3.4, 0.2, 2.7, PAL.grafite, "Metal")
	K.cz(0, 3.2, 0.3, 0.9, 0.1, PAL.preto, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.caldeira = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "caldeira")
	local c = cor(op, PAL.ferrugem)
	K.b(0, 0, 0, 6, 0.8, 6, PAL.tijolo, "Brick")
	K.c(0, 0.8, 0, 4.8, 6.4, c, "CorrodedMetal")
	K.c(0, 3.0, 0, 5.0, 0.25, PAL.metalEsc, "Metal", { colide = false })
	K.c(0, 5.5, 0, 5.0, 0.25, PAL.metalEsc, "Metal", { colide = false })
	K.c(0, 7.2, 0, 4.4, 0.5, PAL.metalEsc, "Metal")
	K.c(0, 7.7, 0, 1.4, 2.3, PAL.grafite, "Metal")
	K.b(0, 1.2, -2.35, 2.4, 2.4, 0.4, PAL.grafite, "Metal")
	K.b(0, 1.8, -2.6, 1.6, 1.2, 0.15, { 255, 120, 50 }, "Neon", { colide = false })
	K.b(0, 0.9, -2.6, 1.6, 0.3, 0.2, PAL.preto, "Metal", { colide = false })
	K.cx(1.0, 5.8, -2.4, 0.3, 0.6, PAL.aco, "Metal")
	K.e(1.0, 5.8, -2.55, 0.9, PAL.branco, "Metal", { colide = false })
	K.cx(2.2, 4.0, 0.0, 0.5, 1.6, PAL.aco, "Metal")
	K.cx(2.2, 4.0, 0.0, 0.3, 1.0, PAL.aco, "Metal", { colide = false })
	return K.fim()
end

M.tubulacao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "tubulacao")
	local w, h, d = dim(op, 10, 1, 1)
	local c = cor(op, PAL.metalEsc)
	K.cx(0, 0.5, 0, 0.8, w, c, "Metal")
	for i = 0, 3 do
		K.cx(-w / 2 + 0.2 + i * (w - 0.4) / 3, 0.5, 0, 1.0, 0.3, PAL.aco, "Metal", { colide = false })
	end
	K.b(0, 0, 0, 0.4, 0.3, 0.6, PAL.ferrugem, "CorrodedMetal")
	K.b(w / 4, 0.3, 0, 0.8, 0.7, 0.8, PAL.vermelho, "Metal")
	return K.fim()
end

M.fardo_feno = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "fardo_feno")
	local c = cor(op, PAL.palha)
	K.b(0, 0, 0, 4, 3, 2.6, c, "Grass")
	K.b(0, 0.0, -0.4, 3.8, 3.04, 0.1, esc(c, 0.7), "Fabric", { colide = false })
	K.b(0, 0.0, 0.4, 3.8, 3.04, 0.1, esc(c, 0.7), "Fabric", { colide = false })
	K.b(-1.0, 3.0, -0.5, 1.2, 0.01, 1.4, esc(c, 1.15), "Grass", { colide = false })
	K.b(0, 0.0, 0.0, 4.04, 0.4, 2.64, esc(c, 0.9), "Grass", { colide = false })
	return K.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- ACAMPAMENTO
-- ---------------------------------------------------------------------------------------------------------------
M.barraca = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "barraca")
	local c = cor(op, PAL.lona)
	local cl = esc(c, 1.12)
	-- piso (lona de chão) e paredes baixas
	K.b(0, 0, 0, 9, 0.1, 10, esc(c, 0.7), "Fabric", { colide = false })
	K.b(-4.45, 0.1, 0, 0.1, 2.4, 10, c, "Fabric")
	K.b(4.45, 0.1, 0, 0.1, 2.4, 10, c, "Fabric")
	-- teto de duas águas
	K.r(-4.5, 2.5, 0, 0, 5.6, 0, 10.4, 0.2, cl, "Fabric")
	K.r(4.5, 2.5, 0, 0, 5.6, 0, 10.4, 0.2, cl, "Fabric")
	-- fundo e frente em degraus (triângulo) — frente com entrada aberta
	K.b(0, 0.1, 4.9, 9, 2.4, 0.1, c, "Fabric")
	K.b(0, 2.5, 4.9, 6.2, 1.0, 0.1, c, "Fabric")
	K.b(0, 3.5, 4.9, 3.4, 1.0, 0.1, c, "Fabric")
	K.b(0, 4.5, 4.9, 1.2, 1.0, 0.1, c, "Fabric")
	for _, s in { -1, 1 } do
		K.b(s * 3.2, 0.1, -4.9, 2.6, 2.4, 0.1, c, "Fabric")
	end
	K.b(0, 4.1, -4.9, 4.0, 0.5, 0.1, c, "Fabric")
	K.b(0, 4.6, -4.9, 2.0, 0.6, 0.1, c, "Fabric")
	K.b(0, 3.0, -4.9, 3.8, 1.1, 0.1, c, "Fabric")
	-- mastro, estacas e cordas
	K.b(0, 0.1, -4.9, 0.25, 5.4, 0.25, PAL.madeiraEsc, "Wood")
	return K.fim()
end

M.cama_campanha = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "cama_campanha")
	local c = cor(op, PAL.lona)
	for _, s in { -1, 1 } do
		K.b(s * 1.35, 1.1, 0, 0.25, 0.25, 6.6, PAL.madeiraEsc, "Wood")
		K.r(s * 1.35, 0.0, -3.0, s * 1.35, 1.2, -2.4, 0.2, 0.2, PAL.metalEsc, "Metal")
		K.r(s * 1.35, 0.0, 3.0, s * 1.35, 1.2, 2.4, 0.2, 0.2, PAL.metalEsc, "Metal")
		K.r(s * 1.35, 1.2, -2.4, s * 1.35, 0.0, -1.9, 0.2, 0.2, PAL.metalEsc, "Metal")
		K.r(s * 1.35, 1.2, 2.4, s * 1.35, 0.0, 1.9, 0.2, 0.2, PAL.metalEsc, "Metal")
	end
	K.b(0, 1.3, 0, 2.5, 0.2, 6.4, c, "Fabric")
	K.b(0, 1.5, 2.4, 1.8, 0.35, 1.2, PAL.creme, "Fabric")
	K.b(0, 1.5, -0.6, 2.4, 0.2 + 0.5, 3.8, esc(c, 0.7), "Fabric")
	return K.fim()
end

M.mesa_dobravel = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_dobravel")
	local c = cor(op, PAL.madeiraCl)
	K.b(0, 2.5, 0, 5, 0.2, 2.6, c, "WoodPlanks")
	for _, s in { -1, 1 } do
		K.r(s * 2.0, 0.0, -1.1, s * 2.0, 2.5, 0.0, 0.2, 0.15, PAL.metalEsc, "Metal")
		K.r(s * 2.0, 0.0, 1.1, s * 2.0, 2.5, 0.0, 0.2, 0.15, PAL.metalEsc, "Metal")
		K.b(s * 2.0, 0.0, 0, 0.2, 0.15, 2.4, PAL.metalEsc, "Metal", { colide = false })
	end
	K.b(0, 2.7, 0, 1.2, 0.1, 0.8, PAL.branco, "Fabric", { colide = false })
	return K.fim()
end

M.fogueira = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "fogueira")
	local c = cor(op, PAL.madeiraEsc)
	K.c(0, 0, 0, 3.4, 0.2, PAL.grafite, "Slate", { colide = false })
	for i = 0, 7 do
		local a = i * math.pi / 4
		K.b(math.cos(a) * 1.65, 0, math.sin(a) * 1.65, 1.0, 0.9 + (i % 3) * 0.3, 1.0, PAL.pedra, "Rock", { rotY = a })
	end
	K.cx(0, 0.5, 0, 0.5, 2.6, c, "Wood", { colide = false, rot = CFrame.Angles(0, 0.3, 0.2) })
	K.cx(0, 0.55, 0, 0.5, 2.6, c, "Wood", { colide = false, rot = CFrame.Angles(0, 1.9, -0.2) })
	K.cx(0, 0.9, 0, 0.45, 2.2, esc(c, 0.8), "Wood", { colide = false, rot = CFrame.Angles(0, 1.1, 0.1) })
	K.b(0, 0.7, 0, 1.0, 0.8, 1.0, { 255, 120, 40 }, "Neon", { colide = false, rot = CFrame.Angles(0, 0.6, 0) })
	K.b(0, 1.3, 0, 0.5, 0.5, 0.5, { 255, 190, 70 }, "Neon", { colide = false })
	return K.fim()
end

M.caixa_municao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "caixa_municao")
	local c = cor(op, PAL.industrial)
	K.b(0, 0, 0, 2.4, 1.2, 1.4, c, "Metal")
	K.b(0, 1.2, 0, 2.5, 0.4, 1.5, esc(c, 0.9), "Metal")
	K.b(0, 1.3, -0.77, 0.4, 0.3, 0.08, PAL.aco, "Metal", { colide = false })
	K.b(0, 1.6, 0, 1.0, 0.1, 0.2, PAL.aco, "Metal", { colide = false })
	K.b(0, 0.5, -0.72, 1.4, 0.3, 0.04, PAL.amarelo, "SmoothPlastic", { colide = false })
	return K.fim()
end

M.estante_armas = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "estante_armas")
	local c = cor(op, PAL.madeiraEsc)
	for _, s in { -1, 1 } do
		K.b(s * 2.4, 0, 0, 0.2, 6, 1.4, c, "Wood")
	end
	K.b(0, 0, 0.5, 4.6, 0.8, 0.4, c, "Wood")
	K.b(0, 4.5, 0.5, 4.6, 0.5, 0.4, c, "Wood")
	K.b(0, 0.8, 0.6, 4.6, 3.7, 0.15, esc(c, 0.75), "Wood", { colide = false })
	K.b(0, 5.6, 0.0, 4.9, 0.4, 1.4, c, "Wood")
	K.b(0, 4.1, -0.1, 4.6, 0.2, 0.2, esc(c, 1.2), "Wood", { colide = false })
	for i = 0, 4 do
		local x = -1.8 + i * 0.9
		K.c(x, 1.0, 0.1, 0.22, 3.6, PAL.grafite, "Metal", { colide = false })
		K.b(x, 0.8, 0.05, 0.45, 1.8, 0.5, PAL.madeiraCl, "Wood", { colide = false })
	end
	return K.fim()
end

M.mesa_mapas = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "mesa_mapas")
	local c = cor(op, PAL.madeira)
	K.b(0, 2.3, 0, 6, 0.3, 4, c, "WoodPlanks")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.b(sx * 2.6, 0, sz * 1.6, 0.5, 2.6, 0.5, PAL.madeiraEsc, "Wood")
		end
	end
	K.b(0, 0.7, 0, 5.2, 0.2, 0.3, PAL.madeiraEsc, "Wood", { colide = false })
	K.b(0, 2.6, 0, 5.2, 0.03, 3.2, { 190, 176, 140 }, "Fabric", { colide = false })
	K.b(-1.0, 2.63, 0.3, 1.4, 0.02, 0.1, PAL.vermelho, "SmoothPlastic", { colide = false })
	K.c(1.2, 2.63, -0.5, 0.25, 0.25, PAL.azul, "SmoothPlastic", { colide = false })
	K.c(1.6, 2.63, 0.5, 0.25, 0.25, PAL.vermelho, "SmoothPlastic", { colide = false })
	K.c(2.2, 2.6, 1.3, 0.5, 0.1, PAL.aco, "Metal", { colide = false })
	return K.fim()
end

M.gerador = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "gerador")
	local c = cor(op, PAL.laranja)
	K.b(0, 0, 0, 3, 0.4, 2.2, PAL.grafite, "Metal")
	K.b(0, 0.4, 0, 2.8, 1.5, 2.0, c, "Metal")
	K.b(0, 1.9, 0, 2.2, 0.5, 1.8, PAL.grafite, "Metal")
	K.b(0.8, 1.9, 0.6, 0.9, 0.7, 0.9, PAL.vermelho, "Metal")
	K.c(-1.0, 2.4, 0.5, 0.3, 0.2, PAL.aco, "Metal")
	K.b(0, 0.8, -1.03, 1.2, 0.8, 0.06, PAL.preto, "Metal", { colide = false })
	K.b(-0.6, 1.0, -1.08, 0.2, 0.2, 0.06, { 90, 220, 120 }, "Neon", { colide = false })
	K.b(0.5, 1.0, -1.08, 0.3, 0.3, 0.06, PAL.amarelo, "Metal", { colide = false })
	K.b(0, 2.4, 0, 2.4, 0.2, 2.2, PAL.metalEsc, "Metal", { colide = false })
	return K.fim()
end

M.lampiao = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "lampiao")
	local c = cor(op, PAL.metalEsc)
	K.c(0, 0, 0, 1.0, 0.25, c, "Metal")
	K.c(0, 0.25, 0, 0.7, 1.3, PAL.amarelo, "Glass", { transparencia = 0.5 })
	K.b(0, 0.5, 0, 0.3, 0.6, 0.3, { 255, 190, 80 }, "Neon", { colide = false })
	K.c(0, 1.55, 0, 0.9, 0.3, c, "Metal")
	K.c(0, 1.85, 0, 0.3, 0.35, c, "Metal")
	K.b(0, 2.0, 0, 0.8, 0.2, 0.08, c, "Metal", { colide = false })
	return K.fim()
end

M.saco_areia = function(ctx, pai, cf, op)
	local K = nova(ctx, pai, cf, "saco_areia")
	local w, h, d = dim(op, 5, 2.2, 1.6)
	local c = cor(op, { 150, 134, 100 })
	local nBase = math.max(2, math.floor(w / 1.0))
	local lg = w / nBase
	local fileiras = math.max(1, math.floor(h / 0.7))
	for f = 0, fileiras - 1 do
		local n = if f % 2 == 0 then nBase else nBase - 1
		for i = 0, n - 1 do
			local x = if f % 2 == 0 then -w / 2 + lg * (i + 0.5) else -w / 2 + lg * (i + 1)
			local tom = 0.9 + ((i * 7 + f * 3) % 5) * 0.04
			K.b(x, f * h / fileiras, 0, lg - 0.06, h / fileiras - 0.04, d, esc(c, tom), "Fabric")
		end
	end
	return K.fim()
end

return M
