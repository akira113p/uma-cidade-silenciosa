-- Floresta boreal do norte da Europa: pinheiro-silvestre, abeto, bétula, árvores mortas, tocos, troncos caídos, pedras de
-- granito com musgo, arbustos, samambaias, cogumelos, mantos de agulhas e manchas de LeafyGrass. Contrato: docs/mapa-v2.md §8 F1.
-- Tudo em Workspace.Mapa.Vegetacao. Só o que colide se chama `Tronco` (troncos, tocos, pedras, toras) ou `Mancha`.

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local floor, max, min, sqrt, sin, cos, atan, pi =
	math.floor, math.max, math.min, math.sqrt, math.sin, math.cos, math.atan, math.pi

local TAN30 = 0.577

local COR = {
	troncoPinho = { { 96, 62, 44 }, { 84, 58, 44 }, { 70, 56, 48 } },
	altoPinho = { 128, 80, 52 },
	copaPinho = { { 42, 66, 46 }, { 38, 60, 42 }, { 46, 70, 48 } },
	troncoAbeto = { { 70, 56, 48 }, { 78, 60, 46 } },
	copaAbeto = { { 30, 52, 38 }, { 26, 46, 34 }, { 34, 58, 42 } },
	betula = { 198, 196, 186 },
	marcaBetula = { 34, 32, 30 },
	copaBetula = { { 110, 122, 62 }, { 138, 134, 68 }, { 96, 112, 58 } },
	morta = { 82, 74, 66 },
	toco = { 92, 68, 48 },
	corte = { 150, 120, 86 },
	granito = { { 112, 114, 110 }, { 98, 100, 98 }, { 124, 120, 114 } },
	musgo = { 52, 82, 44 },
	mirtilo = { { 58, 84, 48 }, { 66, 80, 52 }, { 50, 74, 54 } },
	zimbro = { { 36, 56, 44 }, { 42, 62, 48 } },
	samambaia = { { 62, 98, 54 }, { 74, 104, 58 } },
	cogumeloHaste = { 196, 186, 160 },
	cogumeloChapeu = { { 130, 56, 42 }, { 170, 150, 118 }, { 120, 92, 60 } },
	agulhas = { 70, 52, 38 },
	mancha = { 92, 108, 60 },
	tora = { 84, 64, 48 },
}

local M = {}

function M.gerar(ctx)
	local Mundo, plano = ctx.Mundo, ctx.plano
	local F = Mundo.floresta
	local rng = ctx.rng("floresta")
	local rnd, entre, inteiro, escolher = rng.rnd, rng.entre, rng.inteiro, rng.escolher
	local variar = ctx.variar
	local pasta = ctx.pastas.Vegetacao
	local alt = ctx.altura
	local lim = Mundo.tamanho / 2 - 30
	local dmin = F.distanciaMinima

	local nPecas = 0
	local cont = {
		pinheiro = 0,
		abeto = 0,
		betula = 0,
		morta = 0,
		toco = 0,
		pedra = 0,
		toraCaida = 0,
		arbusto = 0,
		samambaia = 0,
		cogumelo = 0,
		manta = 0,
		mancha = 0,
	}
	local arvores = {} -- { x, z } de cada tronco de árvore (para testes e cogumelos)
	local obstaculos = {} -- inseridos em ctx só no fim, para os checks de `ocupado` verem só as construções

	-- ------------------------------------------------------------------------------------------------------------
	-- Ruído de valor determinístico (clareiras, bosques, espécies)
	-- ------------------------------------------------------------------------------------------------------------
	local semente = inteiro(1, 1000000)
	local function hashN(ix: number, iz: number, s: number): number
		local h = ((ix + 100000) * 1619 + (iz + 100000) * 31337 + (semente + s) * 6971) % 2147483647
		h = (h * 48271 + 12345) % 2147483647
		h = (h * 48271 + 12345) % 2147483647
		return h / 2147483647
	end
	local function suave(t: number): number
		return t * t * (3 - 2 * t)
	end
	local function clamp01(t: number): number
		return max(0, min(1, t))
	end
	local function ruido(x: number, z: number, escala: number, s: number): number
		local fx, fz = x / escala, z / escala
		local ix, iz = floor(fx), floor(fz)
		local tx, tz = suave(fx - ix), suave(fz - iz)
		local a, b = hashN(ix, iz, s), hashN(ix + 1, iz, s)
		local c, d = hashN(ix, iz + 1, s), hashN(ix + 1, iz + 1, s)
		local top = a + (b - a) * tx
		local bot = c + (d - c) * tx
		return top + (bot - top) * tz
	end
	local function bosque(x: number, z: number): number -- 0 (clareira) .. 1 (bosque fechado)
		local n = ruido(x, z, 520, 1) * 0.55 + ruido(x, z, 200, 2) * 0.33 + ruido(x, z, 75, 3) * 0.12
		return suave(clamp01((n - 0.36) / 0.26))
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Terreno
	-- ------------------------------------------------------------------------------------------------------------
	local function grad(x: number, z: number)
		local gx = (alt(x + 3, z) - alt(x - 3, z)) / 6
		local gz = (alt(x, z + 3) - alt(x, z - 3)) / 6
		return gx, gz, sqrt(gx * gx + gz * gz)
	end
	-- quadro sobre o chão, inclinado como o terreno (para peças planas)
	local function cfSolo(x: number, z: number, yaw: number, dy: number, gx: number, gz: number)
		return CFrame.new(x, alt(x, z) + dy, z) * CFrame.Angles(-atan(gz), 0, atan(gx)) * CFrame.Angles(0, yaw, 0)
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Peças. modo: 0 sólido (colide), 1 sem colisão/consulta/sombra, 2 sem colisão/consulta mas com sombra
	-- ------------------------------------------------------------------------------------------------------------
	local function peca(cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, modo, rotY, rot)
		local op = nil
		if modo == 1 then
			op = { colide = false, consulta = false, sombra = false }
		elseif modo == 2 then
			op = { colide = false, consulta = false }
		end
		if rotY or rot then
			op = op or {}
			op.rotY, op.rot = rotY, rot
		end
		nPecas += 1
		return ctx.bloco(pasta, cf, nome, cx, cy, cz, sx, sy, sz, cor, mat, op)
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Grade de ocupação própria (distância entre troncos/pedras/toras)
	-- ------------------------------------------------------------------------------------------------------------
	local CEL = 12
	local grade = {}
	local function kcel(i: number, j: number): number
		return (i + 1000) * 10000 + (j + 1000)
	end
	local function registrar(x: number, z: number, rt: number, arvore: boolean)
		local k = kcel(floor(x / CEL), floor(z / CEL))
		local l = grade[k]
		if not l then
			l = {}
			grade[k] = l
		end
		table.insert(l, { x, z, rt, arvore })
	end
	local function livre(x: number, z: number, rt: number, arvore: boolean): boolean
		local ci, cj = floor(x / CEL), floor(z / CEL)
		for i = ci - 1, ci + 1 do
			for j = cj - 1, cj + 1 do
				local l = grade[kcel(i, j)]
				if l then
					for _, a in l do
						local dx, dz = a[1] - x, a[2] - z
						local d = if arvore and a[4] then dmin else rt + a[3] + 1.5
						if dx * dx + dz * dz < d * d then
							return false
						end
					end
				end
			end
		end
		return true
	end
	local function obstaculo(x: number, z: number, meia: number)
		table.insert(obstaculos, { x - meia, x + meia, z - meia, z + meia })
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Árvores
	-- ------------------------------------------------------------------------------------------------------------
	local function quadroArvore(x: number, z: number, afund: number)
		local lx, lz = entre(-0.07, 0.07), entre(-0.07, 0.07)
		return CFrame.new(x, alt(x, z) - afund, z) * CFrame.Angles(0, entre(0, 2 * pi), 0) * CFrame.Angles(lx, 0, lz)
	end

	local function manta(x: number, z: number, raio: number)
		local gx, gz = grad(x, z)
		local cf = cfSolo(x, z, entre(0, pi), 0.06, gx, gz)
		local t = raio * entre(1.6, 2.2)
		peca(cf, "Agulhas", 0, 0, 0, t, 0.12, t * entre(0.8, 1.2), variar(COR.agulhas, 0.15, rng), "Ground", 1)
		cont.manta += 1
	end

	local function pinheiro(x, z, g)
		local H = entre(24, 44)
		local w = entre(1.4, 1.9) * (0.85 + H / 44 * 0.25)
		local cf = quadroArvore(x, z, 0.6 + g * 1.2)
		peca(cf, "Tronco", 0, H * 0.28, 0, w, H * 0.56, w, variar(escolher(COR.troncoPinho), 0.08, rng), "Wood", 0)
		peca(cf, "TroncoAlto", 0, H * 0.78, 0, w * 0.7, H * 0.46, w * 0.7, variar(COR.altoPinho, 0.1, rng), "Wood", 1)
		local cor = variar(escolher(COR.copaPinho), 0.1, rng)
		for i = 1, 3 do
			local cw = entre(6, 11) * (1.15 - i * 0.14)
			local ch = entre(3.2, 5.5)
			local cy = H * (0.72 + 0.08 * i) + entre(-1, 1)
			peca(
				cf,
				"Copa",
				entre(-2.2, 2.2),
				cy,
				entre(-2.2, 2.2),
				cw,
				ch,
				cw * entre(0.8, 1.2),
				variar(cor, 0.06, rng),
				"Grass",
				1,
				entre(0, pi)
			)
		end
		local gw = entre(3.5, 5.5)
		peca(
			cf,
			"Galho",
			entre(-2.5, 2.5),
			H * entre(0.55, 0.65),
			entre(-2.5, 2.5),
			gw,
			entre(2, 3),
			gw,
			variar(cor, 0.08, rng),
			"Grass",
			1,
			entre(0, pi)
		)
		if rnd() < 0.4 then
			manta(x, z, w * 2.2)
		end
		cont.pinheiro += 1
		return w
	end

	local function abeto(x, z, g)
		local H = entre(30, 50)
		local n = inteiro(4, 6)
		local w = entre(1.5, 2.1)
		local cf = quadroArvore(x, z, 0.6 + g * 1.2)
		peca(cf, "Tronco", 0, H * 0.45, 0, w, H * 0.9, w, variar(escolher(COR.troncoAbeto), 0.08, rng), "Wood", 0)
		local cor = variar(escolher(COR.copaAbeto), 0.08, rng)
		local base0 = H * 0.14
		local pas = (H * 0.8 - base0) / n
		local Wb = H * 0.27 + entre(-1.5, 1.5)
		local th = pas * 1.9
		for k = 0, n - 1 do
			local cw = Wb * (1 - k / n) ^ 0.85 + 2.4
			peca(
				cf,
				"Copa",
				0,
				base0 + k * pas + th / 2,
				0,
				cw,
				th,
				cw,
				variar(cor, 0.05, rng),
				"Grass",
				if k < 2 then 2 else 1,
				(k % 2) * pi / 4
			)
		end
		local topo = base0 + (n - 1) * pas + th
		local ph = H * 0.13
		peca(cf, "Copa", 0, topo + ph / 2 - 1, 0, 1.2, ph, 1.2, variar(cor, 0.05, rng), "Grass", 1)
		if rnd() < 0.35 then
			manta(x, z, Wb * 0.4)
		end
		cont.abeto += 1
		return w
	end

	local function betula(x, z, g)
		local H = entre(14, 22)
		local w = entre(1.0, 1.4)
		local cf = quadroArvore(x, z, 0.5 + g * 1.0)
		peca(cf, "Tronco", 0, H * 0.425, 0, w, H * 0.85, w, variar(COR.betula, 0.06, rng), "Wood", 0)
		peca(cf, "Marca", 0, H * entre(0.2, 0.5), 0, w + 0.06, entre(0.7, 1.2), w + 0.06, COR.marcaBetula, "Wood", 1)
		local cor = variar(escolher(COR.copaBetula), 0.08, rng)
		for i = 1, 2 do
			local cw = entre(5.5, 8.5) * (1.15 - i * 0.18)
			peca(
				cf,
				"Copa",
				entre(-1.5, 1.5),
				H * (0.74 + 0.12 * i),
				entre(-1.5, 1.5),
				cw,
				entre(4.5, 7),
				cw,
				variar(cor, 0.06, rng),
				"Grass",
				1,
				entre(0, pi)
			)
		end
		cont.betula += 1
		return w
	end

	local function morta(x, z, g)
		local H = entre(12, 26)
		local w = entre(1.1, 1.6)
		local cf = quadroArvore(x, z, 0.6 + g * 1.2)
		local cor = variar(COR.morta, 0.1, rng)
		peca(cf, "Tronco", 0, H / 2, 0, w, H, w, cor, "Wood", 0)
		for _ = 1, 2 do
			local len = entre(3.5, 6.5)
			local rot = CFrame.Angles(0, entre(0, 2 * pi), 0)
				* CFrame.Angles(0, 0, entre(0.5, 1.0))
				* CFrame.new(len / 2, 0, 0)
			peca(cf, "Galho", 0, H * entre(0.5, 0.85), 0, len, 0.5, 0.5, cor, "Wood", 1, nil, rot)
		end
		cont.morta += 1
		return w
	end

	local function toco(x, z, g)
		local h = entre(1.5, 3.5)
		local w = entre(2.2, 3.6)
		local cf = CFrame.new(x, alt(x, z) - 0.5 - g * 1.5, z) * CFrame.Angles(0, entre(0, 2 * pi), 0)
		peca(cf, "Tronco", 0, h / 2, 0, w, h, w, variar(COR.toco, 0.1, rng), "Wood", 0)
		peca(cf, "Corte", 0, h + 0.02, 0, w * 0.9, 0.12, w * 0.9, variar(COR.corte, 0.08, rng), "Wood", 1)
		cont.toco += 1
		return w
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 1: árvores (mistura por ruído: bosques de abeto, de pinheiro, bétulas em rios/clareiras)
	-- ------------------------------------------------------------------------------------------------------------
	do
		local alvo = F.arvores
		local n, tent = 0, 0
		while n < alvo and tent < alvo * 400 do
			tent += 1
			local x, z = entre(-lim, lim), entre(-lim, lim)
			local b = bosque(x, z)
			if rnd() >= b * 0.92 + 0.04 then
				continue
			end
			if plano.emAreaConstruida(x, z, 16) then
				continue
			end
			if not livre(x, z, 1, true) then
				continue
			end
			local folga = plano.folgaRio(x, z)
			if folga < 11.5 then
				continue
			end
			local gx, gz, g = grad(x, z)
			if g > TAN30 then
				continue
			end
			local h = alt(x, z)
			local fAlt = 1 - 0.55 * clamp01((h - 4) / 16)
			local bEstr = clamp01(1 - (plano.distPlano(x, z) - 14) / 90)
			local bRio = clamp01(1 - (folga - 10) / 70)
			if rnd() >= min(1, fAlt * (1 + 0.9 * bEstr + 0.8 * bRio) / 2) then
				continue
			end
			if ctx.ocupado(x, z, 7.5) then
				continue
			end

			local sp = ruido(x, z, 260, 4)
			local k = (sp - 0.5) * 3.2
			local claro = 1 - b
			local pesos = {
				{ peso = max(0.02, 0.47 * (1 + k)), f = pinheiro },
				{ peso = max(0.02, 0.37 * (1 - k)), f = abeto },
				{ peso = 0.055 * (1 + 3 * bRio + 2 * claro), f = betula },
				{ peso = 0.03 * (1 + 1.5 * claro), f = morta },
				{ peso = 0.04 * (1 + 2 * claro), f = toco },
			}
			local w = rng.sortear(pesos).f(x, z, g)
			registrar(x, z, 1, true)
			obstaculo(x, z, w / 2 + 0.1)
			table.insert(arvores, { x, z })
			n += 1
		end
		cont.tentativasArvores = tent
	end

	-- amostragem genérica de sítios secundários
	local function sitios(alvo: number, aceitar, fazer): number
		local feito, tent = 0, 0
		while feito < alvo and tent < alvo * 300 do
			tent += 1
			local x, z = entre(-lim, lim), entre(-lim, lim)
			if aceitar(x, z) and fazer(x, z) then
				feito += 1
			end
		end
		return feito
	end
	-- chão livre de qualquer coisa (para plantas, que não colidem)
	local function livrePequeno(x: number, z: number): boolean
		return not plano.emAreaConstruida(x, z, 10)
			and not ctx.ocupado(x, z, 3)
			and plano.folgaRio(x, z) >= 3
			and livre(x, z, 1, false)
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 2: pedras de granito com musgo (mais em clareiras e perto de rios)
	-- ------------------------------------------------------------------------------------------------------------
	sitios(F.pedras or 750, function(x, z)
		local claro = 1 - bosque(x, z)
		return rnd() < 0.2 + 0.8 * claro
	end, function(x, z)
		local grande = rnd() < 0.08
		local sx = if grande then entre(8, 13) else entre(2.5, 7)
		local sy = sx * entre(0.5, 0.9)
		local sz = sx * entre(0.7, 1.2)
		local rt = min(5, max(sx, sz) * 0.5)
		if plano.emAreaConstruida(x, z, 16) or ctx.ocupado(x, z, 7.5) or plano.emRio(x, z, 11.5) then
			return false
		end
		if not livre(x, z, rt, false) then
			return false
		end
		local _, _, g = grad(x, z)
		if g > TAN30 then
			return false
		end
		local afund = sy * 0.3 + g * max(sx, sz) * 0.5
		local cf = CFrame.new(x, alt(x, z), z)
			* CFrame.Angles(0, entre(0, 2 * pi), 0)
			* CFrame.Angles(entre(-0.1, 0.1), 0, entre(-0.1, 0.1))
		peca(cf, "Tronco", 0, sy / 2 - afund, 0, sx, sy, sz, variar(escolher(COR.granito), 0.08, rng), "Granite", 0)
		if rnd() < 0.7 then
			peca(
				cf,
				"Musgo",
				0,
				sy - afund + 0.12,
				0,
				sx * 0.72,
				0.28,
				sz * 0.72,
				variar(COR.musgo, 0.12, rng),
				"Grass",
				1
			)
		end
		registrar(x, z, rt, false)
		obstaculo(x, z, max(sx, sz) / 2 * 1.1)
		cont.pedra += 1
		return true
	end)

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 3: troncos caídos
	-- ------------------------------------------------------------------------------------------------------------
	sitios(F.toras or 280, function(x, z)
		return bosque(x, z) > 0.3 and rnd() < 0.8
	end, function(x, z)
		local len = entre(8, 14)
		local d = entre(1.6, 2.4)
		if plano.emAreaConstruida(x, z, 16) or ctx.ocupado(x, z, 7.5) or plano.emRio(x, z, 11.5) then
			return false
		end
		if not livre(x, z, len * 0.4, false) then
			return false
		end
		local _, _, g = grad(x, z)
		if g > 0.2 then
			return false
		end
		local cf = CFrame.new(x, alt(x, z), z) * CFrame.Angles(0, entre(0, pi), 0)
		local cor = variar(COR.tora, 0.12, rng)
		nPecas += 1
		ctx.cilindro(pasta, cf, "Tronco", 0, d / 2 - 0.3 - g * len * 0.3, 0, d, len, cor, "Wood", { eixo = "x" })
		if rnd() < 0.5 then
			peca(
				cf,
				"Musgo",
				0,
				d - 0.3 - g * len * 0.3 - 0.02,
				0,
				len * 0.55,
				0.2,
				d * 0.45,
				variar(COR.musgo, 0.12, rng),
				"Grass",
				1
			)
		end
		registrar(x, z, len * 0.4, false)
		obstaculo(x, z, len / 2 * 0.75)
		cont.toraCaida += 1
		return true
	end)

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 4: arbustos (mirtilo, zimbro)
	-- ------------------------------------------------------------------------------------------------------------
	local function arbusto(x: number, z: number): boolean
		if not livrePequeno(x, z) then
			return false
		end
		local gx, gz, g = grad(x, z)
		if g > TAN30 then
			return false
		end
		local cf = cfSolo(x, z, 0, -0.1 - g * 0.8, gx, gz)
		if rnd() < 0.65 then -- mirtilo
			local s = entre(2.2, 3.8)
			local h1 = s * entre(0.4, 0.6)
			local cor = variar(escolher(COR.mirtilo), 0.1, rng)
			peca(cf, "Arbusto", 0, h1 / 2, 0, s, h1, s * entre(0.8, 1.1), cor, "Grass", 1, entre(0, pi))
			peca(
				cf,
				"Arbusto",
				entre(-0.8, 0.8),
				h1 * 0.6,
				entre(-0.8, 0.8),
				s * 0.62,
				h1 * 0.9,
				s * 0.62,
				variar(cor, 0.1, rng),
				"Grass",
				1,
				entre(0, pi)
			)
		else -- zimbro
			local w = entre(1.8, 2.8)
			local h = entre(3, 5)
			local cor = variar(escolher(COR.zimbro), 0.1, rng)
			peca(cf, "Arbusto", 0, h * 0.3, 0, w, h * 0.6, w, cor, "Grass", 1, entre(0, pi))
			peca(
				cf,
				"Arbusto",
				0,
				h * 0.6 + h * 0.2,
				0,
				w * 0.62,
				h * 0.55,
				w * 0.62,
				variar(cor, 0.08, rng),
				"Grass",
				1,
				pi / 4
			)
		end
		cont.arbusto += 1
		return true
	end
	sitios(F.arbustos or 1000, function(x, z)
		return rnd() < 0.15 + 0.85 * bosque(x, z)
	end, function(x, z)
		if not arbusto(x, z) then
			return false
		end
		if rnd() < 0.4 then
			arbusto(x + entre(-4, 4), z + entre(-4, 4))
		end
		return true
	end)

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 5: samambaias (leques de 3 frondes)
	-- ------------------------------------------------------------------------------------------------------------
	sitios(F.samambaias or 420, function(x, z)
		local b = bosque(x, z)
		return b > 0.25 and rnd() < 0.8
	end, function(x, z)
		if not livrePequeno(x, z) then
			return false
		end
		local gx, gz, g = grad(x, z)
		if g > TAN30 then
			return false
		end
		local cf = cfSolo(x, z, 0, -0.05, gx, gz)
		local a0 = entre(0, 2 * pi)
		local cor = variar(escolher(COR.samambaia), 0.1, rng)
		local len = entre(3, 4)
		for k = 0, 2 do
			local rot = CFrame.Angles(0, a0 + k * 2 * pi / 3, 0)
				* CFrame.new(0, len / 2 * sin(0.5) + 0.1, -len / 2 * cos(0.5))
				* CFrame.Angles(0.5, 0, 0)
			peca(cf, "Fronde", 0, 0, 0, entre(1, 1.4), 0.12, len, variar(cor, 0.06, rng), "Grass", 1, nil, rot)
		end
		cont.samambaia += 1
		return true
	end)

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 6: cogumelos ao pé de árvores
	-- ------------------------------------------------------------------------------------------------------------
	do
		local alvo = F.cogumelos or 300
		local feito, tent = 0, 0
		while feito < alvo and tent < alvo * 20 and #arvores > 0 do
			tent += 1
			local a = arvores[inteiro(1, #arvores)]
			local ang, r = entre(0, 2 * pi), entre(1.8, 3.5)
			local x, z = a[1] + cos(ang) * r, a[2] + sin(ang) * r
			local _, _, g = grad(x, z)
			if g < 0.4 and not plano.emAreaConstruida(x, z, 6) and plano.folgaRio(x, z) >= 3 then
				local cf = CFrame.new(x, alt(x, z) - 0.15, z)
				local h = entre(0.6, 1.1)
				local c = entre(0.9, 1.6)
				peca(cf, "Cogumelo", 0, h / 2, 0, 0.3, h, 0.3, COR.cogumeloHaste, "Wood", 1)
				peca(
					cf,
					"Cogumelo",
					0,
					h + 0.12,
					0,
					c,
					0.3,
					c,
					variar(escolher(COR.cogumeloChapeu), 0.1, rng),
					"Wood",
					1,
					entre(0, pi)
				)
				cont.cogumelo += 1
				feito += 1
			end
		end
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Passo 7: manchas de LeafyGrass (+5 dB nos passos): uma possível por célula de 80, inclinadas como o terreno
	-- ------------------------------------------------------------------------------------------------------------
	do
		local celula, tMin, tMax = 80, 50, 72
		local p = min(1, F.gramaAlta / (((tMin + tMax) / 2 / celula) ^ 2))
		local x0 = -lim
		while x0 + celula <= lim do
			local z0 = -lim
			while z0 + celula <= lim do
				if rnd() < p then
					local tx, tz = entre(tMin, tMax), entre(tMin, tMax)
					local cx = x0 + entre(0, celula - tx) + tx / 2
					local cz = z0 + entre(0, celula - tz) + tz / 2
					local ok = true
					local pts = {
						{ cx - tx / 2, cz - tz / 2 },
						{ cx - tx / 2, cz + tz / 2 },
						{ cx + tx / 2, cz - tz / 2 },
						{ cx + tx / 2, cz + tz / 2 },
						{ cx, cz },
					}
					for _, q in pts do
						if plano.emAreaConstruida(q[1], q[2], 6) or plano.folgaRio(q[1], q[2]) < 6 then
							ok = false
							break
						end
					end
					if ok and ctx.retanguloOcupado(cx - tx / 2, cx + tx / 2, cz - tz / 2, cz + tz / 2, 3) then
						ok = false
					end
					if ok then
						local gx, gz, g = grad(cx, cz)
						local h0 = alt(cx, cz)
						if g > 0.25 then
							ok = false
						else
							local maior, menor = -math.huge, math.huge
							for _, q in pts do
								local dif = alt(q[1], q[2]) - (h0 + gx * (q[1] - cx) + gz * (q[2] - cz))
								maior, menor = max(maior, dif), min(menor, dif)
							end
							if maior > 0.9 or maior - menor > 1.5 then
								ok = false
							else
								local cf = CFrame.new(cx, h0 + max(0, maior), cz)
									* CFrame.Angles(-atan(gz), 0, atan(gx))
								nPecas += 1
								ctx.bloco(
									pasta,
									cf,
									"Mancha",
									0,
									0,
									0,
									tx,
									0.3,
									tz,
									variar(COR.mancha, 0.12, rng),
									"LeafyGrass"
								)
								cont.mancha += 1
							end
						end
					end
				end
				z0 += celula
			end
			x0 += celula
		end
	end

	for _, o in obstaculos do
		ctx.inserirObstaculo(o[1], o[2], o[3], o[4])
	end

	cont.arvoresTotal = #arvores
	cont.pecas = nPecas
	ctx.floresta = { contagem = cont, arvores = arvores }
	print(
		string.format(
			"  floresta: %d árvores (pinheiro %d, abeto %d, bétula %d, morta %d, toco %d), pedras %d, toras %d, arbustos %d, samambaias %d, cogumelos %d, mantas %d, manchas %d, %d peças",
			#arvores,
			cont.pinheiro,
			cont.abeto,
			cont.betula,
			cont.morta,
			cont.toco,
			cont.pedra,
			cont.toraCaida,
			cont.arbusto,
			cont.samambaia,
			cont.cogumelo,
			cont.manta,
			cont.mancha,
			nPecas
		)
	)
end

return M
