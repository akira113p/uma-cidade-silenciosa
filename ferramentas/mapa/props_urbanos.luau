-- Props externos (postes, placas, mobiliario urbano, veiculos, cemiterio, cenas). Contrato: docs/mapa-v2.md secao 7 e
-- props_tamanhos.luau. Cada funcao: (ctx, pai, cf, op) -> Model com atributo Prop; origem no centro da pegada, no chao, frente -Z.
-- Dono: agente D1. Aleatoriedade so por op.rng / ctx.rng.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local UDim2 = roblox.UDim2
local Enum = roblox.Enum

local TAM = require("./props_tamanhos")

local pi, rad, sin, cos, floor, ceil, max, min =
	math.pi, math.rad, math.sin, math.cos, math.floor, math.ceil, math.max, math.min

local P = {}

-- cores (desbotadas, estilo noite de terror)
local CONC = { 124, 122, 116 }
local CONC_ESC = { 84, 84, 82 }
local ACO = { 78, 82, 84 }
local PRETO = { 26, 26, 28 }
local FERRO = { 58, 60, 62 }
local MAD = { 98, 72, 52 }
local MAD_ESC = { 70, 50, 38 }
local FERRUGEM = { 110, 68, 46 }
local VIDRO = { 24, 30, 34 }
local PNEU = { 20, 20, 22 }
local VERDE = { 46, 72, 46 }
local PEDRA = { 118, 122, 114 }
local TERRA = { 70, 56, 42 }

local rngPorCtx = setmetatable({}, { __mode = "k" })
local function rngDe(ctx, op)
	if op and op.rng then
		return op.rng
	end
	local r = rngPorCtx[ctx]
	if not r then
		r = ctx.rng("props_urbanos")
		rngPorCtx[ctx] = r
	end
	return r
end

local function escuro(c, k)
	return { c[1] * k, c[2] * k, c[3] * k }
end

-- Cria o Model e as funcoes de peca. b = bloco, c = cilindro (eixo), e = esfera, r = rampa entre dois pontos locais.
local function novo(ctx, pai, cf, nome, op)
	local m = Instance.new("Model")
	m.Name = nome
	m:SetAttribute("Prop", nome)
	local k = { m = m, rng = rngDe(ctx, op), ctx = ctx, cf = cf }
	function k.b(cx, cy, cz, sx, sy, sz, cor, mat, o)
		return ctx.bloco(m, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat or "Metal", o)
	end
	function k.c(eixo, cx, cy, cz, d, len, cor, mat, o)
		local oo = { eixo = eixo }
		if o then
			for key, v in o do
				oo[key] = v
			end
		end
		return ctx.cilindro(m, cf, nome, cx, cy, cz, d, len, cor, mat or "Metal", oo)
	end
	function k.e(cx, cy, cz, d, cor, mat, o)
		return ctx.esfera(m, cf, nome, cx, cy, cz, d, cor, mat or "Plastic", o)
	end
	function k.r(x0, y0, z0, x1, y1, z1, larg, esp, cor, mat, o)
		return ctx.rampa(m, cf, nome, x0, y0, z0, x1, y1, z1, larg, esp, cor, mat or "Metal", o)
	end
	function k.fim()
		m.Parent = pai
		return m
	end
	return k
end

local function texto(k, parte, str, cor)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = str
	tl.TextScaled = true
	tl.FontFace = roblox.Font.fromEnum(Enum.Font.GothamBold)
	tl.TextColor3 = k.ctx.rgb(cor)
	tl.Parent = sg
	sg.Parent = parte
end

-- posicoes igualmente espacadas de -w/2+margem ate w/2-margem com no minimo n pontos (passo aproximado)
local function espacar(w, passo, margem)
	local n = max(2, ceil((w - 2 * margem) / passo) + 1)
	local t = {}
	for i = 0, n - 1 do
		t[i + 1] = -w / 2 + margem + (w - 2 * margem) * i / (n - 1)
	end
	return t
end

-- placa sobre poste(s): profundidade total D, placa larg x alt centrada em yc. Devolve a peca interna (para texto).
local function placa(k, D, larg, alt, yc, corBorda, corFundo, txt, corTxt, polos)
	for _, px in polos or { 0 } do
		k.b(px, yc / 2, D / 2 - 0.15, 0.3, yc, 0.3, FERRO, "Metal")
	end
	k.b(0, yc, -D / 2 + 0.14, larg, alt, 0.2, corBorda, "Metal")
	local f = k.b(0, yc, -D / 2 + 0.02, larg - 0.4, alt - 0.4, 0.04, corFundo, "Metal", { colide = false })
	if txt then
		texto(k, f, txt, corTxt or { 230, 230, 225 })
	end
	return f
end

-- ---------------------------------------------------------------------------------------------------------------
-- iluminacao e sinalizacao
-- ---------------------------------------------------------------------------------------------------------------
function P.poste_luz(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "poste_luz", op)
	local zc = 1.4
	k.c("y", 0, 0.4, zc, 1.2, 0.8, CONC, "Concrete")
	k.c("y", 0, 11.4, zc, 0.7, 21.2, ACO, "Metal")
	k.b(0, 21.8, -0.3, 0.4, 0.4, 3.4, ACO, "Metal")
	local lum = k.b(0, 21.35, -1.0, 1.0, 0.4, 2.0, FERRO, "Metal")
	k.b(0, 21.12, -1.0, 0.8, 0.06, 1.6, { 150, 150, 120 }, "Glass", { sombra = false })
	if op and op.acesa then
		local l = Instance.new("PointLight")
		l.Range = 40
		l.Brightness = 1.2
		l.Color = roblox.Color3.fromRGB(255, 214, 150)
		l.Parent = lum
	end
	return k.fim()
end

function P.poste_luz_rodovia(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "poste_luz_rodovia", op)
	local zc = 3.2
	k.c("y", 0, 0.6, zc, 1.4, 1.2, CONC, "Concrete")
	k.c("y", 0, 15.6, zc, 0.9, 28.8, ACO, "Metal")
	k.b(0, 29.75, -0.4, 0.5, 0.5, 7.2, ACO, "Metal")
	k.r(0, 26.2, zc, 0, 29.5, -0.5, 0.3, 0.3, ACO, "Metal")
	k.b(0, 29.15, -2.5, 1.2, 0.6, 3.0, FERRO, "Metal")
	k.b(0, 28.82, -2.5, 1.0, 0.06, 2.6, { 150, 150, 120 }, "Glass", { sombra = false })
	return k.fim()
end

function P.poste_madeira(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "poste_madeira", op)
	k.c("y", 0, 17, 0, 1.0, 34, MAD, "Wood")
	k.b(0, 32, 0, 0.4, 0.5, 6.0, MAD_ESC, "Wood")
	k.b(0, 28.5, 0, 0.4, 0.4, 4.0, MAD_ESC, "Wood")
	local fios = {}
	for _, z in { -2.5, 0, 2.5 } do
		k.c("y", 0, 32.6, z, 0.4, 0.7, { 90, 110, 100 }, "Glass", { sombra = false })
		table.insert(fios, { 32.9, z })
	end
	for _, z in { -1.5, 1.5 } do
		k.c("y", 0, 28.9, z, 0.3, 0.5, { 90, 110, 100 }, "Glass", { sombra = false })
	end
	-- fios ate o proximo poste (op.alvo = {x, z} de mundo)
	if op and op.alvo then
		local ay = ctx.topoEm(op.alvo[1], op.alvo[2])
		local t = cf:PointToObjectSpace(Vector3.new(op.alvo[1], ay, op.alvo[2]))
		for _, f in fios do
			k.r(0, f[1], f[2], t.X, t.Y + f[1], t.Z + f[2], 0.12, 0.12, PRETO, "Metal", {
				colide = false,
				consulta = false,
				sombra = false,
			})
		end
	end
	return k.fim()
end

function P.semaforo(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "semaforo", op)
	local zc = 2.2
	k.b(0, 0.3, zc, 1.6, 0.6, 1.6, CONC, "Concrete")
	k.c("y", 0, 10, zc, 0.8, 20, ACO, "Metal")
	k.b(0, 18, -0.4, 0.4, 0.4, 5.2, ACO, "Metal")
	k.b(0, 17.7, -2.5, 0.3, 0.6, 0.3, ACO, "Metal")
	k.b(0, 15.4, -2.5, 1.6, 4.0, 1.0, PRETO, "Metal")
	k.b(0, 16.4, -3.03, 0.9, 0.9, 0.06, { 92, 30, 28 }, "Glass")
	k.b(0, 15.4, -3.03, 0.9, 0.9, 0.06, { 96, 80, 30 }, "Glass")
	k.b(0, 14.4, -3.03, 0.9, 0.9, 0.06, { 30, 70, 40 }, "Glass")
	return k.fim()
end

function P.placa_pare(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "placa_pare", op)
	local yc = 9.8
	local verm = { 128, 36, 34 }
	k.b(0, yc / 2, 0.1, 0.3, yc, 0.3, FERRO, "Metal")
	k.b(0, yc, -0.15, 2.4, 1.0, 0.2, verm, "Metal")
	k.b(0, yc, -0.15, 1.0, 2.4, 0.2, verm, "Metal")
	k.b(0, yc, -0.15, 1.7, 1.7, 0.2, verm, "Metal", { rot = CFrame.Angles(0, 0, pi / 4) })
	local f = k.b(0, yc, -0.24, 2.0, 0.7, 0.03, verm, "Metal", { colide = false })
	texto(k, f, "PARE", { 226, 226, 222 })
	return k.fim()
end

function P.placa_velocidade(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "placa_velocidade", op)
	local v = (op and op.variante) or k.rng.inteiro(1, 3)
	local txt = ({ "30", "50", "70" })[v]
	placa(k, 0.5, 2, 2.6, 9.7, { 138, 36, 34 }, { 200, 200, 194 }, txt, { 30, 30, 30 })
	return k.fim()
end

function P.placa_rua(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "placa_rua", op)
	placa(k, 0.5, 5, 1.2, 11.4, { 190, 190, 184 }, { 34, 66, 50 }, (op and op.texto) or "Rua Maple", nil)
	return k.fim()
end

function P.placa_direcao(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "placa_direcao", op)
	local w = (op and op.w) or TAM.placa_direcao.w
	placa(
		k,
		0.6,
		w,
		3.6,
		10.2,
		{ 190, 190, 184 },
		{ 34, 66, 50 },
		(op and op.texto) or "Centro  3 km",
		nil,
		{ -(w / 2 - 1), w / 2 - 1 }
	)
	return k.fim()
end

function P.placa_aviso(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "placa_aviso", op)
	local v = (op and op.variante) or k.rng.inteiro(1, 4)
	local txt = ({ "!", "CURVA", "OBRAS", "PERIGO" })[v]
	local yc = 9.7
	k.b(0, yc / 2, 0.1, 0.3, yc, 0.3, FERRO, "Metal")
	local giro = { rot = CFrame.Angles(0, 0, pi / 4) }
	k.b(0, yc, -0.11, 1.838, 1.838, 0.2, PRETO, "Metal", giro)
	k.b(0, yc, -0.23, 1.55, 1.55, 0.04, { 196, 164, 40 }, "Metal", giro)
	local f = k.b(0, yc, -0.24, 1.3, 0.5, 0.03, { 196, 164, 40 }, "Metal", { colide = false })
	texto(k, f, txt, { 30, 30, 30 })
	return k.fim()
end

function P.outdoor(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "outdoor", op)
	for _, x in { -8, 8 } do
		k.c("y", x, 11.5, 0, 1.6, 23, ACO, "Metal")
	end
	k.b(0, 17.85, 0, 24, 0.3, 3, FERRO, "DiamondPlate")
	k.b(0, 18.6, 1.4, 24, 1.0, 0.1, FERRO, "Metal")
	-- moldura + painel
	k.b(0, 28 - 0.4, -1.0, 24, 0.8, 1.0, FERRO, "Metal")
	k.b(0, 18.4, -1.0, 24, 0.8, 1.0, FERRO, "Metal")
	k.b(-11.6, 23.2, -1.0, 0.8, 10, 1.0, FERRO, "Metal")
	k.b(11.6, 23.2, -1.0, 0.8, 10, 1.0, FERRO, "Metal")
	local f = k.b(0, 23.2, -1.1, 22.4, 8.4, 0.6, { 150, 140, 120 }, "Metal")
	local fa = k.b(0, 23.2, -1.41, 22, 8.0, 0.02, { 150, 140, 120 }, "Metal", { colide = false })
	texto(k, fa, (op and op.texto) or "VISITE MAPLE RISE", { 90, 30, 28 })
	f.Name = "outdoor"
	return k.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- mobiliario urbano
-- ---------------------------------------------------------------------------------------------------------------
function P.hidrante(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "hidrante", op)
	local cor = (op and op.cor) or { 148, 46, 40 }
	k.c("y", 0, 0.125, 0, 1.4, 0.25, escuro(cor, 0.8), "Metal")
	k.c("y", 0, 1.2, 0, 0.9, 1.9, cor, "Metal")
	k.c("y", 0, 2.3, 0, 1.0, 0.3, cor, "Metal")
	k.c("y", 0, 2.6, 0, 0.6, 0.4, cor, "Metal")
	k.c("x", 0, 1.4, 0, 0.5, 1.4, cor, "Metal")
	k.c("z", 0, 1.4, -0.45, 0.5, 0.6, cor, "Metal")
	return k.fim()
end

function P.lixeira_rua(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "lixeira_rua", op)
	k.c("y", 0, 1.3, 0, 1.7, 2.6, { 50, 68, 54 }, "Metal")
	k.c("y", 0, 2.8, 0, 1.8, 0.4, { 40, 54, 44 }, "Metal")
	k.c("y", 0, 3.0, 0, 1.2, 0.04, PRETO, "Metal", { colide = false })
	k.c("y", 0, 0.7, 0, 1.8, 0.12, FERRO, "Metal")
	k.c("y", 0, 1.8, 0, 1.8, 0.12, FERRO, "Metal")
	return k.fim()
end

function P.cacamba(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cacamba", op)
	local cor = (op and op.cor) or ({ { 52, 84, 66 }, { 96, 60, 44 }, { 58, 70, 96 } })[k.rng.inteiro(1, 3)]
	for _, z in { -1.4, 1.4 } do
		k.b(0, 0.25, z, 7, 0.5, 0.5, FERRO, "Metal")
	end
	k.b(0, 0.6, 0, 6.6, 0.2, 3.8, cor, "CorrodedMetal")
	for _, z in { -1.85, 1.85 } do
		k.b(0, 2.45, z, 7, 3.5, 0.3, cor, "CorrodedMetal")
		k.b(0, 4.35, z, 7, 0.3, 0.3, escuro(cor, 0.7), "Metal")
	end
	for _, x in { -3.35, 3.35 } do
		k.b(x, 2.45, 0, 0.3, 3.5, 3.4, cor, "CorrodedMetal")
		k.b(x, 4.35, 0, 0.3, 0.3, 3.4, escuro(cor, 0.7), "Metal")
	end
	k.b(0.5, 3.9, 0, 5, 0.8, 3.2, { 48, 40, 34 }, "Slate", { colide = false })
	return k.fim()
end

function P.banco_praca(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "banco_praca", op)
	for _, z in { -0.65, -0.05, 0.55 } do
		k.b(0, 1.5, z, 5.4, 0.2, 0.5, MAD, "WoodPlanks")
	end
	k.b(0, 2.2, 0.9, 5.4, 0.35, 0.15, MAD, "WoodPlanks")
	k.b(0, 2.7, 0.9, 5.4, 0.35, 0.15, MAD, "WoodPlanks")
	for _, x in { -2.85, 2.85 } do
		k.b(x, 0.9, 0, 0.3, 1.8, 2.0, FERRO, "Metal")
		k.b(x, 2.0, -0.3, 0.3, 0.2, 1.4, FERRO, "Metal")
		k.b(x, 1.5, 0.9, 0.3, 3.0, 0.2, FERRO, "Metal")
	end
	return k.fim()
end

function P.ponto_onibus(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "ponto_onibus", op)
	k.b(0, 7.85, 0, 10, 0.3, 4, ACO, "Metal")
	for _, x in { -4.85, 4.85 } do
		for _, z in { -1.8, 1.8 } do
			k.b(x, 3.85, z, 0.3, 7.7, 0.3, ACO, "Metal")
		end
	end
	k.b(0, 3.2, 1.85, 9.4, 4.4, 0.1, { 120, 150, 150 }, "Glass", { transparencia = 0.6 })
	k.b(-4.85, 3.2, 0, 0.1, 4.4, 3.4, { 120, 150, 150 }, "Glass", { transparencia = 0.6 })
	k.b(0.5, 1.8, 1.1, 5, 0.25, 1.2, MAD, "WoodPlanks")
	for _, x in { -1.6, 2.6 } do
		k.b(x, 0.9, 1.1, 0.2, 1.8, 1.0, FERRO, "Metal")
	end
	local f = k.b(-2.5, 3.5, 1.78, 2.2, 3, 0.08, { 40, 60, 90 }, "Metal", { colide = false })
	texto(k, f, "LINHA 12", { 220, 220, 214 })
	return k.fim()
end

function P.caixa_correio(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "caixa_correio", op)
	k.b(0, 1.4, 0, 0.4, 2.8, 0.4, MAD, "Wood")
	k.b(0, 3.3, 0, 1.4, 1.0, 1.4, (op and op.cor) or { 50, 70, 100 }, "Metal")
	k.b(0, 3.3, -0.69, 1.0, 0.7, 0.04, PRETO, "Metal", { colide = false })
	return k.fim()
end

function P.telefone_publico(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "telefone_publico", op)
	local cor = { 70, 90, 80 }
	k.b(0, 0.15, 0, 2, 0.3, 2, CONC, "Concrete")
	for _, x in { -0.85, 0.85 } do
		for _, z in { -0.85, 0.85 } do
			k.b(x, 3.65, z, 0.3, 6.7, 0.3, cor, "Metal")
		end
	end
	k.b(0, 7.25, 0, 2, 0.5, 2, cor, "Metal")
	for _, x in { -0.9, 0.9 } do
		k.b(x, 3.65, 0, 0.1, 6.2, 1.4, { 120, 150, 150 }, "Glass", { transparencia = 0.6 })
	end
	k.b(0, 3.65, 0.9, 1.4, 6.2, 0.1, { 120, 150, 150 }, "Glass", { transparencia = 0.6 })
	k.b(0, 4.4, 0.7, 0.8, 1.2, 0.35, PRETO, "Metal")
	k.b(-0.3, 4.9, 0.45, 0.2, 0.6, 0.15, PRETO, "Metal", { colide = false })
	return k.fim()
end

function P.banca_jornal(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "banca_jornal", op)
	local cor = (op and op.cor) or { 70, 86, 70 }
	k.b(0, 0.1, 0, 5.6, 0.2, 4.6, CONC_ESC, "Concrete")
	k.b(0, 1.75, -2.3, 5.4, 3.5, 0.4, cor, "Metal")
	k.b(0, 3.25, 2.35, 6, 6.5, 0.3, cor, "Metal")
	for _, x in { -2.85, 2.85 } do
		k.b(x, 3.25, 0, 0.3, 6.5, 4.4, cor, "Metal")
	end
	k.b(0, 6.8, 0, 6, 0.4, 5, escuro(cor, 0.7), "Metal")
	local f = k.b(0, 8.0, -2.3, 5.6, 2.0, 0.4, { 150, 130, 80 }, "Metal")
	local fa = k.b(0, 8.0, -2.51, 5.4, 1.8, 0.02, { 150, 130, 80 }, "Metal", { colide = false })
	f.Name = "banca_jornal"
	texto(k, fa, "JORNAIS", { 40, 30, 24 })
	k.b(0, 4.5, 2.0, 5.4, 0.1, 0.8, MAD, "Wood")
	local rng = k.rng
	for i = 1, 5 do
		local c = { rng.inteiro(100, 190), rng.inteiro(70, 150), rng.inteiro(60, 140) }
		k.b(-2.2 + (i - 1) * 1.1, 2.2, -2.53, 0.9, 1.2, 0.06, c, "Plastic", { colide = false })
	end
	return k.fim()
end

function P.caixa_energia(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "caixa_energia", op)
	local cor = { 80, 95, 85 }
	k.b(0, 0.2, 0, 3, 0.4, 3, CONC, "Concrete")
	k.b(0, 2.0, 0, 2.8, 3.2, 2.8, cor, "Metal")
	k.b(0, 3.8, 0, 3, 0.4, 3, escuro(cor, 0.8), "Metal")
	k.b(0, 2.0, -1.41, 0.06, 3.0, 0.04, PRETO, "Metal", { colide = false })
	k.b(0.7, 2.8, -1.42, 0.7, 0.7, 0.03, { 190, 160, 40 }, "Metal", { colide = false })
	k.b(-0.7, 1.0, -1.41, 0.9, 0.5, 0.04, PRETO, "Metal", { colide = false })
	return k.fim()
end

-- octogono de paredes: apotema ap (centro da parede), altura h a partir de y0
local function octogono(k, ap, y0, h, esp, comp, cor, mat, pular)
	for i = 0, 7 do
		if not (pular and pular[i]) then
			local a = i * pi / 4
			k.b(-ap * sin(a), y0 + h / 2, -ap * cos(a), comp, h, esp, cor, mat, { rotY = a })
		end
	end
end

function P.fonte(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "fonte", op)
	k.c("y", 0, 0.2, 0, 13.2, 0.4, CONC_ESC, "Concrete")
	octogono(k, 6.4, 0.4, 1.8, 1.2, 6.0, PEDRA, "Granite")
	k.c("y", 0, 1.2, 0, 3.4, 1.6, PEDRA, "Granite")
	k.c("y", 0, 2.3, 0, 5.2, 0.6, PEDRA, "Granite")
	k.c("y", 0, 3.6, 0, 1.0, 2.0, PEDRA, "Granite")
	k.b(0, 5.05, 0, 1.1, 0.9, 0.6, PEDRA, "Granite")
	k.e(0, 5.7, 0, 0.6, PEDRA, "Granite")
	for _, x in { -0.8, 0.8 } do
		k.b(x, 5.1, 0, 0.3, 0.9, 0.3, PEDRA, "Granite")
	end
	for _ = 1, 3 do
		local a = k.rng.entre(0, 2 * pi)
		local r = k.rng.entre(2.8, 5)
		k.b(cos(a) * r, 0.5, sin(a) * r, 1.2, 0.2, 0.9, { 58, 46, 32 }, "Slate", { colide = false, rotY = a })
	end
	return k.fim()
end

function P.estatua(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "estatua", op)
	local cor = (op and op.cor) or { 112, 124, 116 }
	k.b(0, 0.5, 0, 5, 1, 5, PEDRA, "Granite")
	k.b(0, 2.0, 0, 4, 2, 4, PEDRA, "Granite")
	k.b(0, 3.25, 0, 4.4, 0.5, 4.4, PEDRA, "Granite")
	for _, x in { -0.7, 0.7 } do
		k.b(x, 5.5, 0, 1.1, 4.0, 1.1, cor, "Granite")
	end
	k.b(0, 9.5, 0, 2.8, 4.0, 1.5, cor, "Granite")
	k.e(0, 12.4, 0, 1.8, cor, "Granite")
	k.b(-1.75, 9.6, 0, 0.7, 3.4, 0.7, cor, "Granite")
	k.b(1.75, 12.2, 0, 0.7, 2.8, 0.7, cor, "Granite")
	k.e(1.75, 13.6, 0, 0.8, { 120, 100, 70 }, "Granite")
	k.b(0, 9.0, 0.9, 2.6, 5.0, 0.3, escuro(cor, 0.85), "Granite")
	return k.fim()
end

function P.coreto(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "coreto", op)
	local branco = { 168, 166, 158 }
	local telha = { 90, 52, 46 }
	k.c("y", 0, 0.6, 0, 18, 1.2, CONC, "Concrete")
	for i = 0, 7 do
		local a = pi / 8 + i * pi / 4
		k.c("y", -8.12 * sin(a), 4.7, -8.12 * cos(a), 0.8, 7, branco, "Concrete")
	end
	octogono(k, 7.5, 1.2, 1.2, 0.3, 6.4, branco, "WoodPlanks", { [0] = true, [4] = true })
	k.c("y", 0, 8.5, 0, 16.4, 0.6, escuro(branco, 0.8), "Concrete")
	k.c("y", 0, 9.2, 0, 17.4, 0.8, telha, "Slate")
	k.c("y", 0, 10.1, 0, 13, 1.0, telha, "Slate")
	k.c("y", 0, 11.1, 0, 8.5, 1.0, telha, "Slate")
	k.c("y", 0, 12.1, 0, 4, 1.0, telha, "Slate")
	k.c("y", 0, 13.3, 0, 0.8, 1.4, FERRO, "Metal")
	return k.fim()
end

function P.canteiro(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "canteiro", op)
	for _, z in { -1.75, 1.75 } do
		k.b(0, 0.5, z, 8, 1.0, 0.5, CONC, "Concrete")
	end
	for _, x in { -3.75, 3.75 } do
		k.b(x, 0.5, 0, 0.5, 1.0, 3.0, CONC, "Concrete")
	end
	k.b(0, 0.8, 0, 7, 0.8, 3, TERRA, "Ground")
	k.b(-2.2, 1.9, 0, 2.6, 1.8, 2.8, VERDE, "LeafyGrass", { colide = false })
	k.b(0.4, 1.7, 0.2, 2.6, 1.4, 2.4, escuro(VERDE, 1.15), "LeafyGrass", { colide = false })
	k.b(2.5, 1.8, -0.3, 2.4, 1.6, 2.6, escuro(VERDE, 0.9), "LeafyGrass", { colide = false })
	return k.fim()
end

function P.arvore_rua(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "arvore_rua", op)
	local rng = k.rng
	local paleta = { { 146, 84, 42 }, { 150, 106, 48 }, { 120, 70, 44 }, { 66, 90, 54 }, { 138, 120, 52 } }
	local base = (op and op.cor) or paleta[rng.inteiro(1, #paleta)]
	k.c("y", 0, 6.0, 0, 1.2, 12, { 80, 62, 48 }, "Wood")
	local sem = { colide = false, consulta = false }
	local function copa(cx, cy, cz, sx, sy, sz, o)
		local oo = { colide = false, consulta = false }
		if o then
			oo.rotY = o
		end
		k.b(
			cx,
			cy,
			cz,
			sx,
			sy,
			sz,
			{ base[1] * (0.9 + rng.rnd() * 0.2), base[2] * (0.9 + rng.rnd() * 0.2), base[3] * 0.95 },
			"LeafyGrass",
			oo
		)
	end
	copa(0, 11.2, 0, 6.8, 3.0, 6.8)
	copa(0, 13.6, 0, 8, 3.0, 6.2)
	copa(0, 15.2, 0, 6.0, 2.4, 8)
	copa(0, 17.0, 0, 4.0, 2.0, 4.0)
	if rng.chance(0.5) then
		copa(0, 12.5, 0, 5, 2.5, 5, pi / 4)
	end
	_ = sem
	return k.fim()
end

function P.arbusto(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "arbusto", op)
	local cor = (op and op.cor) or VERDE
	k.b(0, 1.0, 0, 4, 2.0, 4, cor, "LeafyGrass", { colide = false })
	k.b(0, 2.2, 0, 2.6, 1.6, 2.6, escuro(cor, 1.15), "LeafyGrass", { colide = false, rotY = pi / 4 })
	return k.fim()
end

function P.cerca_viva(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cerca_viva", op)
	local w = (op and op.w) or TAM.cerca_viva.w
	local cor = (op and op.cor) or { 44, 70, 44 }
	k.b(0, 1.1, 0, w, 2.2, 2.5, cor, "LeafyGrass")
	k.b(0, 2.85, 0, w * 0.92, 1.3, 2.1, escuro(cor, 1.12), "LeafyGrass", { colide = false })
	return k.fim()
end

function P.barraca_feira(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "barraca_feira", op)
	local rng = k.rng
	local c1, c2 = { 150, 60, 52 }, { 190, 184, 170 }
	for _, x in { -3.85, 3.85 } do
		for _, z in { -2.85, 2.85 } do
			k.b(x, 3.7, z, 0.3, 7.4, 0.3, MAD, "Wood")
		end
	end
	for i = 0, 3 do
		k.b(-3 + 2 * i, 7.85, 0, 2, 0.3, 6, if i % 2 == 0 then c1 else c2, "Fabric", { colide = false })
	end
	k.b(0, 7.2, -2.95, 8, 0.7, 0.1, c1, "Fabric", { colide = false })
	k.b(0, 2.9, -0.8, 7, 0.3, 2.2, MAD, "WoodPlanks")
	for _, x in { -3.2, 3.2 } do
		k.b(x, 1.4, -0.8, 0.3, 2.8, 1.8, MAD_ESC, "Wood")
	end
	for i = 1, 3 do
		local c = { rng.inteiro(90, 170), rng.inteiro(70, 140), rng.inteiro(40, 90) }
		k.b(-2.4 + (i - 1) * 2.4, 3.45, -0.8, 1.6, 0.8, 1.4, c, "Wood")
	end
	k.b(0, 3.9, 2.8, 7.6, 6.0, 0.1, { 120, 110, 96 }, "Fabric", { colide = false })
	return k.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- playground
-- ---------------------------------------------------------------------------------------------------------------
function P.balanco(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "balanco", op)
	local aco = { 90, 96, 100 }
	k.c("x", 0, 6.8, 0, 0.4, 8, aco, "Metal")
	for _, sx in { -3.8, 3.8 } do
		for _, sz in { -1, 1 } do
			k.r(sx, 0.2, sz * 2.85, sx, 6.7, sz * 0.1, 0.35, 0.35, aco, "Metal")
		end
	end
	for _, sw in { -1.5, 1.5 } do
		for _, dx in { -0.8, 0.8 } do
			k.b(sw + dx, 4.5, 0, 0.08, 4.6, 0.08, FERRO, "Metal", { colide = false })
		end
		k.b(sw, 2.15, 0, 1.8, 0.2, 0.7, MAD, "Wood")
	end
	return k.fim()
end

function P.escorregador(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "escorregador", op)
	local azul, amar = { 60, 88, 124 }, { 168, 148, 60 }
	k.b(0, 4.65, 4.5, 4.4, 0.3, 3.0, MAD, "WoodPlanks")
	for _, sx in { -1, 1 } do
		for _, sz in { 3.15, 5.85 } do
			k.b(sx * 2.05, 3.35, sz, 0.3, 6.7, 0.3, azul, "Metal")
		end
	end
	k.b(0, 6.85, 4.5, 6.0, 0.3, 3.4, amar, "Metal", { colide = false })
	for _, sx in { -2.05, 2.05 } do
		k.b(sx, 5.5, 4.5, 0.15, 0.8, 3.0, azul, "Metal")
	end
	k.b(0, 5.5, 5.85, 4.0, 0.8, 0.15, azul, "Metal")
	for _, z in { 3.6, 5.4 } do
		k.b(2.5, 2.4, z, 0.2, 4.8, 0.2, FERRO, "Metal")
	end
	for _, y in { 0.8, 1.8, 2.8, 3.8 } do
		k.b(2.5, y, 4.5, 0.15, 0.15, 1.8, FERRO, "Metal")
	end
	k.r(0, 4.75, 3.0, 0, 0.9, -5.0, 1.6, 0.3, { 150, 150, 146 }, "Metal")
	for _, sx in { -0.85, 0.85 } do
		k.r(sx, 5.2, 3.0, sx, 1.35, -5.0, 0.15, 0.45, azul, "Metal")
	end
	k.b(0, 0.75, -5.55, 1.6, 0.3, 0.9, { 150, 150, 146 }, "Metal")
	return k.fim()
end

function P.gangorra(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "gangorra", op)
	local a = rad(12)
	local rot = CFrame.Angles(0, 0, a)
	k.b(0, 0.15, 0, 1.4, 0.3, 2.0, FERRO, "Metal")
	k.b(0, 1.0, 0, 0.5, 1.4, 0.6, FERRO, "Metal")
	k.b(0, 1.5, 0, 10.2, 0.3, 0.8, { 168, 148, 60 }, "Wood", { rot = rot })
	for _, s in { -4, 4 } do
		local x = s * cos(a) - 0.35 * sin(a)
		local y = 1.5 + s * sin(a) + 0.35 * cos(a)
		k.b(x, y, 0, 0.12, 0.7, 0.5, FERRO, "Metal", { rot = rot, colide = false })
	end
	return k.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- barreiras e cercas
-- ---------------------------------------------------------------------------------------------------------------
function P.barreira_concreto(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "barreira_concreto", op)
	local c = (op and op.cor) or CONC
	k.b(0, 0.5, 0, 3, 1, 8, c, "Concrete")
	k.b(0, 1.5, 0, 2.2, 1, 8, c, "Concrete")
	k.b(0, 2.5, 0, 1.2, 1, 8, c, "Concrete")
	for _, z in { -3.5, 3.5 } do
		k.b(0, 2.5, z, 1.22, 1.02, 0.8, { 170, 90, 40 }, "Concrete", { colide = false })
	end
	return k.fim()
end

function P.cone(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cone", op)
	local c = { 190, 100, 40 }
	k.b(0, 0.075, 0, 1.2, 0.15, 1.2, PRETO, "Plastic")
	k.c("y", 0, 0.45, 0, 1.0, 0.6, c, "Plastic")
	k.c("y", 0, 0.9, 0, 0.78, 0.12, { 200, 200, 194 }, "Plastic")
	k.c("y", 0, 1.0, 0, 0.75, 0.5, c, "Plastic")
	k.c("y", 0, 1.5, 0, 0.5, 0.5, c, "Plastic")
	k.c("y", 0, 1.88, 0, 0.3, 0.25, c, "Plastic")
	return k.fim()
end

function P.cerca_arame(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cerca_arame", op)
	local w = (op and op.w) or TAM.cerca_arame.w
	for _, x in espacar(w, 4, 0.2) do
		k.b(x, 2.25, 0, 0.3, 4.5, 0.4, ACO, "Metal")
	end
	k.b(0, 2.4, 0, w - 0.3, 3.4, 0.06, { 120, 124, 124 }, "Metal", { transparencia = 0.45, consulta = false })
	k.b(0, 4.4, 0, w, 0.15, 0.15, ACO, "Metal")
	return k.fim()
end

function P.cerca_madeira(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cerca_madeira", op)
	local w = (op and op.w) or TAM.cerca_madeira.w
	for _, x in espacar(w, 4, 0.25) do
		k.b(x, 2.0, 0, 0.5, 4.0, 0.6, MAD_ESC, "Wood")
	end
	for _, y in { 1.0, 2.0, 3.3 } do
		k.b(0, y, -0.2, w, 0.4, 0.2, MAD, "WoodPlanks")
	end
	return k.fim()
end

function P.muro_baixo(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "muro_baixo", op)
	local w = (op and op.w) or TAM.muro_baixo.w
	local cor = (op and op.cor) or { 130, 120, 108 }
	k.b(0, 1.8, 0, w, 3.6, 0.8, cor, "Brick")
	k.b(0, 3.8, 0, w, 0.4, 1.0, escuro(cor, 0.85), "Concrete")
	for _, x in espacar(w, 5, 0.45) do
		k.b(x, 1.9, 0, 0.9, 3.8, 1.0, escuro(cor, 0.92), "Brick")
	end
	return k.fim()
end

function P.guard_rail(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "guard_rail", op)
	local w = (op and op.w) or TAM.guard_rail.w
	local zn = { 150, 152, 150 }
	k.b(0, 1.9, -0.4, w, 1.0, 0.12, zn, "Metal")
	k.b(0, 2.1, -0.5, w, 0.2, 0.25, zn, "Metal")
	k.b(0, 1.7, -0.5, w, 0.2, 0.25, zn, "Metal")
	for _, x in espacar(w, 4, 0.15) do
		k.b(x, 1.1, 0.45, 0.3, 2.2, 0.3, FERRUGEM, "Metal")
		k.b(x, 1.9, 0.0, 0.2, 0.5, 0.9, FERRUGEM, "Metal", { colide = false })
	end
	return k.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- veiculos
-- ---------------------------------------------------------------------------------------------------------------
local PALETA_CARRO = {
	{ 118, 44, 40 },
	{ 58, 78, 102 },
	{ 128, 128, 122 },
	{ 92, 106, 82 },
	{ 152, 140, 102 },
	{ 44, 46, 52 },
	{ 150, 96, 48 },
}
local BUMP = { 50, 50, 54 }
local LUZ_T = { 110, 30, 30 }

-- v: 1 sedan, 2 hatch, 3 picape, 4 van, 5 taxi. o: W (largura do corpo), queimado, semVidro, semPortas, semRodas
local function construirCarro(k, v, cor, o)
	local W = o.W or 5.2
	local vidro = not o.semVidro
	local wx = W / 2 - 0.15
	local sx = W - 0.6
	local luzF = { 150, 140, 100 }
	local cabTopo = 4.6
	k.b(0, 1.9, 0, W, 2.0, 10.2, cor, "Metal") -- corpo inferior
	local function vidroLado(x, y, z, comp, alt)
		if o.semPortas then
			k.b(x, 3.6, z, 0.14, 1.4, comp + 0.4, { 12, 10, 10 }, "Metal", { colide = false })
		elseif vidro then
			k.b(x, y, z, 0.12, alt, comp, VIDRO, "Glass", { transparencia = 0.1, refletancia = 0.1 })
		end
	end
	if v == 1 or v == 5 then
		if v == 5 then
			cabTopo = 4.2
		end
		local h = cabTopo - 2.9
		k.b(0, 2.9 + h / 2, 0.6, sx, h, 4.0, cor, "Metal")
		if vidro then
			k.r(0, 2.9, -2.8, 0, cabTopo - 0.1, -1.4, sx - 0.2, 0.15, VIDRO, "Glass")
			k.r(0, cabTopo - 0.1, 2.6, 0, 2.9, 3.9, sx - 0.2, 0.15, VIDRO, "Glass")
		end
		for _, s in { -1, 1 } do
			vidroLado(s * sx / 2, 2.9 + h * 0.55, 0.6, 3.4, h - 0.6)
		end
		if v == 5 then
			k.b(0, 4.4, 0.6, 1.6, 0.4, 0.7, { 210, 190, 110 }, "Plastic")
			for _, s in { -1, 1 } do
				k.b(s * W / 2, 2.3, 0, 0.06, 0.3, 6, PRETO, "Metal", { colide = false })
			end
		end
	elseif v == 2 then
		k.b(0, 3.7, 1.4, sx, 1.6, 5.6, cor, "Metal")
		if vidro then
			k.r(0, 2.9, -2.8, 0, 4.4, -1.4, sx - 0.2, 0.15, VIDRO, "Glass")
			k.r(0, 4.4, 4.2, 0, 3.0, 4.95, sx - 0.2, 0.15, VIDRO, "Glass")
		end
		for _, s in { -1, 1 } do
			vidroLado(s * sx / 2, 3.8, 1.4, 5.0, 0.9)
		end
		cabTopo = 4.5
	elseif v == 3 then
		k.b(0, 3.75, -1.4, sx, 1.7, 3.2, cor, "Metal")
		if vidro then
			k.r(0, 2.9, -3.9, 0, 4.5, -3.0, sx - 0.2, 0.15, VIDRO, "Glass")
			k.b(0, 3.8, 0.22, sx - 0.8, 0.9, 0.06, VIDRO, "Glass")
		end
		for _, s in { -1, 1 } do
			vidroLado(s * sx / 2, 3.8, -1.4, 2.6, 0.95)
			k.b(s * wx, 3.3, 2.7, 0.3, 0.8, 4.8, cor, "Metal")
		end
		k.b(0, 3.3, 4.95, W - 0.6, 0.8, 0.3, cor, "Metal")
		k.b(0, 2.95, 2.7, W - 0.7, 0.1, 4.4, { 36, 34, 32 }, "Metal")
	else
		k.b(0, 3.75, 0.65, W - 0.2, 1.7, 8.9, cor, "Metal")
		if vidro then
			k.r(0, 2.9, -5.0, 0, 4.4, -3.8, W - 0.5, 0.15, VIDRO, "Glass")
			k.b(0, 3.9, 5.12, W - 1.2, 1.0, 0.06, VIDRO, "Glass")
		end
		for _, s in { -1, 1 } do
			vidroLado(s * (W - 0.2) / 2, 3.9, -2.6, 1.8, 1.0)
			vidroLado(s * (W - 0.2) / 2, 3.9, 2.6, 1.2, 1.0)
		end
	end
	k.b(0, 1.3, -5.25, W - 0.2, 0.8, 0.5, BUMP, "Metal")
	k.b(0, 1.3, 5.25, W - 0.2, 0.8, 0.5, BUMP, "Metal")
	if not o.queimado then
		k.b(0, 2.2, -5.12, W - 1.0, 0.5, 0.06, luzF, "Plastic")
		k.b(0, 2.2, 5.12, W - 1.0, 0.5, 0.06, LUZ_T, "Plastic")
	end
	if not o.semRodas then
		for _, s in { -1, 1 } do
			for _, z in { -3.5, 3.5 } do
				k.c("x", s * wx, 1.0, z, 2.0, 0.7, PNEU, "Plastic")
			end
		end
	end
	return cabTopo
end

function P.carro(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "carro", op)
	local v = (op and op.variante) or k.rng.inteiro(1, 5)
	local cor = (op and op.cor) or (if v == 5 then { 176, 150, 52 } else k.rng.escolher(PALETA_CARRO))
	construirCarro(k, v, cor, {})
	return k.fim()
end

function P.carro_destruido(ctx, pai, cf, op)
	local rng = rngDe(ctx, op)
	local v = (op and op.variante) or rng.inteiro(1, 3)
	local tipo = rng.inteiro(1, 3)
	if v == 1 then
		local k = novo(ctx, pai, cf, "carro_destruido", op)
		construirCarro(k, tipo, { 32, 28, 26 }, { queimado = true, semVidro = true })
		k.b(0, 0.03, 0, 5.4, 0.06, 10.4, { 28, 26, 24 }, "Slate", { colide = false, consulta = false, sombra = false })
		k.b(0.5, 4.45, 0.6, 2.2, 0.08, 1.8, FERRUGEM, "CorrodedMetal", { colide = false })
		k.b(-0.4, 3.0, -3.6, 2.0, 0.08, 1.6, FERRUGEM, "CorrodedMetal", { colide = false })
		return k.fim()
	elseif v == 2 then
		local k = novo(ctx, pai, cf, "carro_destruido", op)
		local cor = (op and op.cor) or { 118, 64, 46 }
		construirCarro(k, tipo, cor, { semVidro = true, semPortas = true, queimado = true })
		return k.fim()
	end
	-- deitado de lado: o quadro do carro gira 90 graus; o fundo fica para +X
	local cf2 = cf * CFrame.new(1.8, 2.4, 0) * CFrame.Angles(0, 0, pi / 2)
	local k = novo(ctx, pai, cf2, "carro_destruido", op)
	construirCarro(k, tipo, { 44, 36, 32 }, { W = 4.8, queimado = true, semVidro = true, semRodas = true })
	ctx.bloco(
		k.m,
		cf,
		"carro_destruido",
		2.35,
		0.1,
		-2.0,
		1.0,
		0.2,
		3.0,
		{ 70, 52, 42 },
		"CorrodedMetal",
		{ rotY = 0.2 }
	)
	ctx.cilindro(k.m, cf, "carro_destruido", 1.9, 0.35, 3.4, 1.9, 0.7, PNEU, "Plastic", { eixo = "y" })
	return k.fim()
end

function P.caminhao(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "caminhao", op)
	local rng = k.rng
	local cab = (op and op.cor)
		or rng.escolher({ { 118, 44, 40 }, { 58, 78, 102 }, { 92, 106, 82 }, { 140, 130, 100 } })
	local carga = rng.escolher({ { 170, 168, 160 }, { 110, 112, 108 }, { 120, 90, 60 } })
	k.b(0, 2.6, 0, 5.6, 0.8, 21, PRETO, "Metal")
	k.b(0, 5.5, -8.75, 7.2, 5.0, 4.3, cab, "Metal")
	k.b(0, 6.5, -10.93, 6.2, 2.2, 0.08, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 4.2, -10.92, 3.0, 1.4, 0.06, PRETO, "Metal")
	k.b(0, 3.3, -10.75, 7.6, 0.9, 0.5, BUMP, "Metal")
	k.b(0, 7.2, 2.5, 8, 7.6, 17, carga, "Metal")
	k.b(0, 7.2, 11.02, 0.1, 7.2, 0.05, PRETO, "Metal", { colide = false })
	k.b(0, 2.9, 10.8, 7, 0.6, 0.4, BUMP, "Metal")
	for _, s in { -1, 1 } do
		k.b(s * 3.62, 6.5, -8.6, 0.08, 2.2, 2.6, VIDRO, "Glass", { transparencia = 0.1 })
		k.b(s * 2.7, 4.2, -10.92, 0.9, 0.5, 0.06, { 150, 140, 100 }, "Plastic")
		k.b(s * 4.02, 7.2, 2.5, 0.06, 0.5, 17, escuro(cab, 0.9), "Metal", { colide = false })
		for _, z in { -8, 5.5, 8.5 } do
			k.c("x", s * 3.3, 1.7, z, 3.4, 1.2, PNEU, "Plastic")
		end
		k.b(s * 3, 3.4, 10.99, 0.7, 0.4, 0.06, LUZ_T, "Plastic")
	end
	return k.fim()
end

function P.onibus(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "onibus", op)
	local cor = (op and op.cor) or k.rng.escolher({ { 160, 140, 70 }, { 70, 90, 110 }, { 150, 150, 142 } })
	k.b(0, 5.8, 0, 8, 8.4, 26, cor, "Metal")
	k.b(0, 1.0, 0, 7.6, 1.4, 25.6, PRETO, "Metal")
	k.b(0, 10.5, 0, 4.6, 1.0, 10, escuro(cor, 0.8), "Metal")
	k.b(-4.03, 7.3, 0.5, 0.08, 2.8, 23, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(4.03, 7.3, 3.3, 0.08, 2.8, 17, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(4.03, 5.3, -9.5, 0.1, 6.0, 3.4, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 6.9, -13.04, 6.8, 3.4, 0.08, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 7.6, 13.04, 5.5, 2.4, 0.08, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 9.0, -13.03, 4.0, 0.8, 0.06, { 190, 120, 40 }, "Plastic")
	for _, z in { -8, -3, 2, 7, 11.5 } do
		k.b(-4.06, 7.3, z, 0.1, 2.9, 0.5, escuro(cor, 0.7), "Metal", { colide = false })
	end
	for _, z in { -2, 3, 8 } do
		k.b(4.06, 7.3, z, 0.1, 2.9, 0.5, escuro(cor, 0.7), "Metal", { colide = false })
	end
	for _, s in { -1, 1 } do
		k.b(s * 3.0, 2.8, -13.03, 0.9, 0.6, 0.06, { 150, 140, 100 }, "Plastic")
		for _, z in { -9, 8 } do
			k.c("x", s * 3.45, 1.6, z, 3.2, 1.0, PNEU, "Plastic")
		end
	end
	k.b(0, 1.8, -12.8, 8, 0.6, 0.5, BUMP, "Metal")
	k.b(0, 1.8, 12.8, 8, 0.6, 0.5, BUMP, "Metal")
	return k.fim()
end

function P.trator(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "trator", op)
	local cor = (op and op.cor) or k.rng.escolher({ { 70, 100, 60 }, { 120, 52, 42 }, { 60, 80, 110 } })
	k.b(0, 3.6, -3.1, 3.4, 2.8, 5.8, cor, "Metal")
	k.b(0, 3.4, -6.0, 2.8, 2.0, 0.06, PRETO, "Metal")
	k.b(0, 3.2, 1.8, 4.6, 0.6, 4.8, escuro(cor, 0.8), "Metal")
	for _, x in { -2.1, 2.1 } do
		for _, z in { -0.3, 3.9 } do
			k.b(x, 6.1, z, 0.3, 5.2, 0.3, escuro(cor, 0.8), "Metal")
		end
	end
	k.b(0, 8.85, 1.8, 5.4, 0.3, 4.8, escuro(cor, 0.8), "Metal")
	k.b(0, 6.2, 4.1, 4.0, 2.8, 0.08, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 6.2, -0.3, 4.0, 2.8, 0.08, VIDRO, "Glass", { transparencia = 0.1 })
	k.b(0, 4.3, 2.2, 1.6, 1.6, 1.4, PRETO, "Fabric")
	k.b(0, 5.2, 0.4, 0.8, 0.1, 0.8, PRETO, "Metal", { colide = false })
	k.b(0, 1.5, -4.2, 6.0, 0.4, 0.5, FERRO, "Metal")
	k.c("y", 1.0, 6.2, -4.6, 0.5, 2.4, FERRO, "Metal")
	k.b(0, 2.2, 5.8, 1.0, 0.5, 0.4, FERRO, "Metal")
	for _, s in { -1, 1 } do
		k.c("x", s * 3.1, 2.7, 3.3, 5.4, 1.8, PNEU, "Plastic")
		k.c("x", s * 3.95, 2.7, 3.3, 2.4, 0.2, { 168, 148, 60 }, "Metal")
		k.b(s * 3.1, 5.6, 3.3, 2.0, 0.3, 5.0, cor, "Metal")
		k.c("x", s * 3.3, 1.5, -4.2, 3.0, 1.0, PNEU, "Plastic")
	end
	return k.fim()
end

function P.trailer(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "trailer", op)
	local cor = (op and op.cor) or k.rng.escolher({ { 170, 168, 160 }, { 110, 112, 108 }, { 90, 100, 120 } })
	k.b(0, 5.0, 0, 8, 6.0, 22, cor, "Metal")
	k.b(0, 1.8, 0, 5.4, 0.5, 18, PRETO, "Metal")
	for _, s in { -1, 1 } do
		k.b(s * 3, 1.0, -7.5, 0.4, 1.7, 0.4, FERRO, "Metal")
		k.b(s * 3, 0.1, -7.5, 1, 0.2, 1, FERRO, "Metal")
		for _, z in { 6.2, 8.6 } do
			k.c("x", s * 3.1, 1.7, z, 3.4, 1.1, PNEU, "Plastic")
		end
		for _, z in { -8, -4, 0, 4, 8 } do
			k.b(s * 4.03, 5.0, z, 0.08, 5.8, 0.3, escuro(cor, 0.8), "Metal", { colide = false })
		end
	end
	k.b(0, 5.0, 11.02, 0.1, 5.8, 0.05, PRETO, "Metal", { colide = false })
	return k.fim()
end

function P.container_carga(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "container_carga", op)
	local cor = (op and op.cor)
		or k.rng.escolher({ { 110, 48, 40 }, { 40, 70, 100 }, { 70, 90, 60 }, { 160, 140, 60 }, { 130, 130, 125 } })
	local esc = escuro(cor, 0.8)
	k.b(0, 4.3, 0, 20, 8.6, 7.8, cor, "CorrodedMetal")
	for _, sx in { -9.75, 9.75 } do
		for _, sz in { -3.75, 3.75 } do
			k.b(sx, 4.3, sz, 0.5, 8.6, 0.5, esc, "Metal")
		end
	end
	for _, sz in { -3.95, 3.95 } do
		for i = 0, 8 do
			k.b(-8.8 + i * 2.2, 4.3, sz, 0.5, 8.0, 0.1, esc, "CorrodedMetal")
		end
	end
	k.b(10.0, 4.3, 0, 0.1, 8.0, 0.15, PRETO, "Metal", { colide = false })
	return k.fim()
end

-- ---------------------------------------------------------------------------------------------------------------
-- cemiterio, lixo e cenas
-- ---------------------------------------------------------------------------------------------------------------
function P.lapide(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "lapide", op)
	local v = (op and op.variante) or k.rng.inteiro(1, 5)
	local cor = (op and op.cor) or k.rng.escolher({ { 112, 114, 108 }, { 96, 100, 98 }, { 124, 120, 110 } })
	k.b(0, 0.2, 0, 2, 0.4, 0.8, escuro(cor, 0.85), "Concrete")
	if v == 1 then
		k.b(0, 1.3, 0, 1.8, 1.8, 0.5, cor, "Granite")
		k.c("z", 0, 2.2, 0, 1.8, 0.5, cor, "Granite")
	elseif v == 2 then
		k.b(0, 1.8, 0, 1.0, 2.8, 0.5, cor, "Granite")
		k.b(0, 2.5, 0, 2.0, 0.45, 0.5, cor, "Granite")
	elseif v == 3 then
		k.b(0, 1.8, 0, 2.0, 2.8, 0.5, cor, "Granite")
	elseif v == 4 then
		k.b(0, 1.7, 0, 1.6, 2.6, 0.5, cor, "Granite", { rot = CFrame.Angles(0, 0, rad(8)) })
	else
		k.b(0, 1.6, 0, 1.2, 2.2, 0.5, cor, "Granite")
		k.b(0, 2.95, 0, 1.0, 0.5, 0.5, escuro(cor, 1.1), "Granite")
	end
	return k.fim()
end

function P.cruz_cemiterio(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "cruz_cemiterio", op)
	local cor = (op and op.cor) or { 110, 110, 104 }
	k.b(0, 0.4, 0, 2, 0.8, 1, escuro(cor, 0.85), "Concrete")
	k.b(0, 3.4, 0, 0.7, 5.2, 0.7, cor, "Granite")
	k.b(0, 4.4, 0, 3, 0.7, 0.7, cor, "Granite")
	return k.fim()
end

function P.entulho(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "entulho", op)
	local rng = k.rng
	k.b(0, 0.4, 0, 8, 0.8, 6, CONC_ESC, "Concrete")
	k.b(0.3, 1.25, -0.2, 6.4, 0.9, 4.6, { 112, 76, 60 }, "Brick", { rotY = 0.05 })
	k.b(-0.6, 2.1, 0.2, 4.4, 0.8, 3.2, CONC, "Concrete", { rotY = -0.2 })
	k.b(0.4, 2.6, 0, 2.4, 0.8, 2, { 96, 92, 86 }, "Concrete", { rotY = 0.4 })
	for _ = 1, 6 do
		local x = rng.entre(-3.4, 3.4)
		local z = rng.sinal() * rng.entre(2.0, 2.7)
		k.b(x, 0.95, z, 0.9, 0.3, 0.5, { 120, 78, 60 }, "Brick", { rotY = rng.entre(0, pi), colide = false })
	end
	for _, s in { -1, 1 } do
		k.r(s * 3, 1.0, 1.5 * s, -s * 1.0, 2.9, -0.5 * s, 0.12, 0.12, FERRUGEM, "Metal", { colide = false })
	end
	return k.fim()
end

function P.pilha_pneus_ext(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "pilha_pneus_ext", op)
	local camadas = {
		{ { -1.25, -1.25 }, { 1.25, -1.25 }, { -1.25, 1.25 }, { 1.25, 1.25 } },
		{ { -1.25, -1.25 }, { 1.25, -1.25 }, { -1.25, 1.25 }, { 1.25, 1.25 } },
		{ { -1.2, 0 }, { 1.2, 0 }, { 0, 1.4 } },
		{ { -0.9, -0.5 }, { 0.9, 0.5 } },
		{ { 0, 0 } },
	}
	for i, cam in camadas do
		for _, p in cam do
			k.c("y", p[1], i - 0.5, p[2], 2.5, 1.0, PNEU, "Plastic")
		end
	end
	k.c("y", 0, 4.99, 0, 1.2, 0.04, { 8, 8, 8 }, "Plastic", { colide = false })
	return k.fim()
end

function P.mancha_sangue(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "mancha_sangue", op)
	local v = (op and op.variante) or k.rng.inteiro(1, 3)
	local cor = { 70, 12, 12 }
	local f = { colide = false, consulta = false, sombra = false }
	local function disco(x, z, d)
		k.c("y", x, 0.05, z, d, 0.1, cor, "SmoothPlastic", f)
	end
	if v == 1 then
		disco(-0.7, -0.6, 2.6)
		disco(0.7, 0.6, 2.6)
		disco(1.3, -1.2, 1.4)
		disco(-1.7, 1.5, 0.5)
	elseif v == 2 then
		disco(0, 0, 2.2)
		local g = { colide = false, consulta = false, sombra = false, rotY = 0.3 }
		k.b(0, 0.05, 0, 1.2, 0.1, 4.0, cor, "SmoothPlastic", g)
		k.b(0, 0.05, 0, 4.0, 0.1, 1.0, cor, "SmoothPlastic", g)
	else
		disco(0, 0, 2.4)
		for i = 0, 7 do
			local a = i * pi / 4
			local r = 1.62 + (i % 2) * 0.2
			disco(sin(a) * r, cos(a) * r, 0.6 + (i % 3) * 0.15)
		end
	end
	return k.fim()
end

function P.fardo_feno_ext(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "fardo_feno_ext", op)
	local palha = { 150, 128, 70 }
	k.b(0, 0.07, 0, 5, 0.14, 5, palha, "LeafyGrass", { colide = false })
	k.c("z", 0, 2.25, 0, 4.5, 5.0, palha, "LeafyGrass")
	for _, z in { -1.2, 1.2 } do
		k.c("z", 0, 2.25, z, 4.6, 0.15, PRETO, "Plastic", { colide = false })
	end
	return k.fim()
end

function P.torre_celular(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "torre_celular", op)
	local aco = { 120, 124, 124 }
	local function meia(y)
		return 4.6 - 3.6 * (y / 52)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			k.r(sx * 4.6, 0.2, sz * 4.6, sx * 1.0, 52, sz * 1.0, 0.6, 0.6, aco, "Metal")
			k.b(sx * 4.6, 0.25, sz * 4.6, 0.8, 0.5, 0.8, CONC, "Concrete")
		end
	end
	local ys = { 0, 13, 26, 39, 52 }
	for i = 1, 4 do
		local y0, y1 = ys[i], ys[i + 1]
		local h0, h1 = meia(y0), meia(y1)
		local s = if i % 2 == 0 then -1 else 1
		for _, f in { -1, 1 } do
			k.r(-s * h0, y0, f * h0, s * h1, y1, f * h1, 0.3, 0.3, aco, "Metal")
			k.r(f * h0, y0, -s * h0, f * h1, y1, s * h1, 0.3, 0.3, aco, "Metal")
		end
	end
	for _, y in { 13, 39 } do
		local h = meia(y)
		for _, f in { -1, 1 } do
			k.b(0, y, f * h, 2 * h, 0.4, 0.4, aco, "Metal")
			k.b(f * h, y, 0, 0.4, 0.4, 2 * h, aco, "Metal")
		end
	end
	k.b(0, 52.15, 0, 3.6, 0.3, 3.6, aco, "DiamondPlate")
	k.c("y", 0, 56, 0, 0.6, 8, aco, "Metal")
	for i = 0, 2 do
		local a = i * 2 * pi / 3
		k.b(sin(a) * 1.7, 54.2, cos(a) * 1.7, 1.0, 3.6, 0.3, { 200, 200, 196 }, "Metal", { rotY = a })
	end
	k.e(0, 59.7, 0, 0.5, { 160, 30, 30 }, "Plastic")
	return k.fim()
end

function P.pilha_toras(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "pilha_toras", op)
	local rng = k.rng
	local d = 1.667
	local cores = { { 104, 76, 52 }, { 112, 86, 60 }, { 96, 70, 48 } }
	for r = 0, 3 do
		local n = 4 - r
		for i = 1, n do
			local len = if i == 1 then 12 else rng.entre(11.2, 12)
			local y = d / 2 + r * 1.35
			local z = (i - (n + 1) / 2) * 1.5
			k.c("x", 0, y, z, d, len, rng.escolher(cores), "Wood")
			k.c("x", len / 2, y, z, d * 0.8, 0.04, { 150, 120, 84 }, "Wood", { colide = false })
		end
	end
	for _, x in { -5.5, 5.5 } do
		for _, z in { -2.95, 2.95 } do
			k.b(x, 2.6, z, 0.3, 5.2, 0.3, MAD_ESC, "Wood")
		end
	end
	return k.fim()
end

function P.tenda_feira(ctx, pai, cf, op)
	local k = novo(ctx, pai, cf, "tenda_feira", op)
	local rng = k.rng
	local c1, c2 = rng.escolher({ { 150, 60, 52 }, { 60, 88, 120 }, { 150, 130, 60 } }), { 190, 184, 170 }
	for _, x in { -4.6, 4.6 } do
		for _, z in { -3.6, 3.6 } do
			k.b(x, 3.5, z, 0.3, 7.0, 0.3, MAD, "Wood")
		end
	end
	for i = 0, 4 do
		local xc = -4 + 2 * i
		local c = if i % 2 == 0 then c1 else c2
		k.r(xc, 7, -4, xc, 9, 0, 2, 0.2, c, "Fabric", { colide = false })
		k.r(xc, 7, 4, xc, 9, 0, 2, 0.2, c, "Fabric", { colide = false })
	end
	for _, z in { -3.95, 3.95 } do
		k.b(0, 6.6, z, 10, 0.8, 0.1, c1, "Fabric", { colide = false })
	end
	for _, x in { -4.95, 4.95 } do
		k.b(x, 6.6, 0, 0.1, 0.8, 8, c2, "Fabric", { colide = false })
	end
	k.b(0, 2.9, 0, 7, 0.3, 2.2, MAD, "WoodPlanks")
	for _, x in { -3.2, 3.2 } do
		k.b(x, 1.4, 0, 0.3, 2.8, 1.8, MAD_ESC, "Wood")
	end
	for i = 1, 3 do
		local c = { rng.inteiro(90, 170), rng.inteiro(70, 140), rng.inteiro(40, 90) }
		k.b(-2.4 + (i - 1) * 2.4, 3.45, 0, 1.6, 0.8, 1.4, c, "Wood")
	end
	return k.fim()
end

return P
