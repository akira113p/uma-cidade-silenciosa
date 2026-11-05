-- Áreas fora da cidade: pads planos (Y 0,5), vilas (ruas em cruz, casas, posto, igreja, mercado, 6 spawns), fábrica,
-- planície (fazenda), posto da guarda e os POIs de Mundo.pois. Contrato: docs/mapa-v2.md §8 (L2). Dono: agente L2.
-- Funções de área de outros módulos (edificios_especiais/industria) são opcionais: se faltarem, só o pad + ctx.avisos.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Cat = require("./catalogo")
local Props = require("./props")

local abs, pi = math.abs, math.pi

local M = {}

local COR = {
	vila = { 96, 86, 70 },
	asfalto = { 52, 52, 56 },
	faixa = { 170, 150, 70 },
	fabrica = { 96, 98, 100 },
	planicie = { 72, 92, 56 },
	guarda = { 84, 78, 64 },
	cobble = { 110, 108, 102 },
}

-- pad por tipo de POI: { cor, material }
local PAD_POI = {
	cemiterio = { { 70, 72, 62 }, "Ground" },
	acampamento = { { 86, 80, 64 }, "Ground" },
	serraria = { { 96, 76, 54 }, "Ground" },
	ferroVelho = { { 80, 68, 58 }, "Ground" },
	parada = { { 84, 84, 86 }, "Pavement" },
	igrejaIsolada = { { 94, 90, 80 }, "Ground" },
}

local VIA_VILA = 24
local CLAR = 12 -- folga entre construção e a borda da rua da vila

-- rotação (múltiplo de 90°) para que a frente (−Z local) aponte para o vetor (fx, fz)
local function rotDe(fx: number, fz: number): number
	if fz < 0 then
		return 0
	elseif fz > 0 then
		return pi
	elseif fx > 0 then
		return -pi / 2
	end
	return pi / 2
end

function M.gerar(ctx)
	ctx.avisos = ctx.avisos or {}
	ctx.spawnsPlanejados = ctx.spawnsPlanejados or {}
	local Mundo, plano = ctx.Mundo, ctx.plano
	local NIVEL = ctx.NIVEL_PAD
	local rng = ctx.rng("areas")
	local cons = ctx.pastas.Construcoes

	local function aviso(txt: string)
		table.insert(ctx.avisos, "areas: " .. txt)
	end

	-- módulos opcionais de outros agentes
	local cacheMod = {}
	local function modulo(nome: string)
		if cacheMod[nome] ~= nil then
			return cacheMod[nome]
		end
		local m = false
		if fs.isFile("ferramentas/mapa/" .. nome .. ".luau") then
			local ok, r = pcall(require, "./" .. nome)
			if ok then
				m = r
			else
				aviso("erro ao carregar " .. nome .. ": " .. tostring(r))
			end
		end
		cacheMod[nome] = m
		return m
	end

	-- chama modulo.areas.funcao(ctx, ...); devolve true se existia e rodou
	local function chamarArea(nomeMod: string, funcao: string, ...)
		local m = modulo(nomeMod)
		local f = m and m.areas and m.areas[funcao]
		if not f then
			aviso(`{nomeMod}.areas.{funcao} ainda não existe: só o pad foi gerado`)
			return false
		end
		local ok, err = pcall(f, ctx, ...)
		if not ok then
			aviso(`{nomeMod}.areas.{funcao} falhou: {tostring(err)}`)
			return false
		end
		return true
	end

	local function pad(r, nome: string, cor, material: string)
		return ctx.laje("Chao", "Pad_" .. nome, r.x0, r.x1, r.z0, r.z1, NIVEL, 2, cor, material)
	end

	-- retângulo (mundo) toca alguma estrada (rets) com margem
	local function sobreEstrada(x0, x1, z0, z1, m: number): boolean
		for _, e in plano.estradas do
			for _, r in e.rets do
				if x0 - m <= r.x1 and x1 + m >= r.x0 and z0 - m <= r.z1 and z1 + m >= r.z0 then
					return true
				end
			end
		end
		return false
	end

	-- constrói e registra. f = vetor da frente no mundo; devolve modelo, info, spec
	local function construir(variante: string, x: number, z: number, f, zona: string, local_: string)
		local cf = CFrame.new(x, NIVEL, z) * CFrame.Angles(0, rotDe(f[1], f[2]), 0)
		local spec = { cf = cf, zona = zona, local_ = local_, rng = rng }
		local modelo, info = Cat.construir(ctx, variante, spec)
		ctx.registrarConstrucao(spec, modelo, info)
		return modelo, info, spec
	end

	-- extensão (mundo) da pegada conforme a frente
	local function extensao(def, f)
		if f[2] ~= 0 then
			return def.w, def.d
		end
		return def.d, def.w
	end

	local function colocarProp(nome: string, x: number, z: number, rotY: number?, op)
		return Props.colocar(ctx, ctx.pastas.Props, nome, x, z, rotY, op)
	end

	local nada = CFrame.new()

	-- -----------------------------------------------------------------------------------------------------------------
	-- Vilas
	-- -----------------------------------------------------------------------------------------------------------------
	local pesosCasa = {
		{ peso = 3, v = "casa_pequena" },
		{ peso = 3, v = "casa_media" },
		{ peso = 2, v = "casa_grande" },
		{ peso = 2, v = "sobrado" },
		{ peso = 2, v = "cabana" },
	}

	local function gerarVila(i: number, v)
		local r = plano.vilas[i]
		local cx, cz = v.centro[1], v.centro[2]
		local L = v.lado / 2
		local limite = L - 8
		local zonaVila = plano.zonaEm(cx, cz)

		pad(r, v.nome, COR.vila, "Ground")

		-- ruas em cruz (24) + faixas tracejadas
		local t = NIVEL + 0.2
		local m = VIA_VILA / 2
		ctx.laje("Ruas", "RuaVilaH", cx - L, cx + L, cz - m, cz + m, t, 0.4, COR.asfalto, "Asphalt")
		ctx.laje("Ruas", "RuaVilaV1", cx - m, cx + m, cz - L, cz - m, t, 0.4, COR.asfalto, "Asphalt")
		ctx.laje("Ruas", "RuaVilaV2", cx - m, cx + m, cz + m, cz + L, t, 0.4, COR.asfalto, "Asphalt")
		local op = { colide = false, consulta = false, sombra = false }
		local yf = t + 0.025
		local passo = 14
		local a = 16
		while a + 6 <= L - 4 do
			for _, s in { -1, 1 } do
				ctx.bloco(
					ctx.pastas.Ruas,
					nada,
					"Faixa",
					cx + s * (a + 3),
					yf,
					cz,
					6,
					0.05,
					0.5,
					COR.faixa,
					"Asphalt",
					op
				)
				ctx.bloco(
					ctx.pastas.Ruas,
					nada,
					"Faixa",
					cx,
					yf,
					cz + s * (a + 3),
					0.5,
					0.05,
					6,
					COR.faixa,
					"Asphalt",
					op
				)
			end
			a += passo
		end

		-- praça: quatro cantos do cruzamento, com postes e bancos
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x0, x1 = math.min(sx * 12, sx * 30), math.max(sx * 12, sx * 30)
				local z0, z1 = math.min(sz * 12, sz * 30), math.max(sz * 12, sz * 30)
				ctx.laje(
					"Ruas",
					"Praca",
					cx + x0,
					cx + x1,
					cz + z0,
					cz + z1,
					NIVEL + 0.12,
					0.3,
					COR.cobble,
					"Cobblestone"
				)
				if sx == sz then
					colocarProp("poste_luz", cx + sx * 16, cz + sz * 16, 0)
				end
				colocarProp("banco_praca", cx + sx * 23, cz + sz * 16, rotDe(0, -sz))
			end
		end

		-- construções: igreja, mercado, posto, 12 casas (maiores primeiro)
		local lista = { { var = "igreja", obrig = true }, { var = "mercado", obrig = false } }
		if v.posto then
			table.insert(lista, { var = "posto", obrig = true })
		end
		local casas = {}
		for _ = 1, v.casas do
			table.insert(casas, { var = rng.sortear(pesosCasa).v, obrig = true, casa = true })
		end
		table.sort(casas, function(p, q)
			local dp, dq = Cat.def[p.var], Cat.def[q.var]
			return dp.w * dp.d > dq.w * dq.d
		end)
		for _, c in casas do
			table.insert(lista, c)
		end

		local feitas = 0
		for _, it in lista do
			local def = Cat.def[it.var]
			local achou = nil
			for _, margem in { 10, 8, 6 } do
				for _ = 1, 5000 do
					local sx, sz = rng.sinal(), rng.sinal()
					local rx = sx * rng.entre(12 + CLAR + 8, limite - 8)
					local rz = sz * rng.entre(12 + CLAR + 8, limite - 8)
					local f = if abs(rz) <= abs(rx) then { 0, -sz } else { -sx, 0 }
					local ex, ez = extensao(def, f)
					if
						abs(rx) - ex / 2 >= m + CLAR
						and abs(rz) - ez / 2 >= m + CLAR
						and abs(rx) + ex / 2 <= limite
						and abs(rz) + ez / 2 <= limite
					then
						local x0, x1, z0, z1 = cx + rx - ex / 2, cx + rx + ex / 2, cz + rz - ez / 2, cz + rz + ez / 2
						if not ctx.retanguloOcupado(x0, x1, z0, z1, margem) and not sobreEstrada(x0, x1, z0, z1, 4) then
							achou = { x = cx + rx, z = cz + rz, f = f, ex = ex, ez = ez }
							break
						end
					end
				end
				if achou then
					break
				end
			end
			if not achou then
				if it.obrig then
					error(`{v.nome}: não coube {it.var}`)
				end
				aviso(`{v.nome}: {it.var} não coube`)
				continue
			end
			construir(it.var, achou.x, achou.z, achou.f, zonaVila, v.nome)
			if it.casa then
				feitas += 1
				-- caixa de correio no gramado da frente, deslocada para um lado
				local f = achou.f
				local prof = if f[2] ~= 0 then achou.ez else achou.ex
				local lado = if f[2] ~= 0 then achou.ex else achou.ez
				local px = achou.x + f[1] * (prof / 2 + 2) + -f[2] * (lado / 2 - 3)
				local pz = achou.z + f[2] * (prof / 2 + 2) + f[1] * (lado / 2 - 3)
				colocarProp("caixa_correio", px, pz, rotDe(-f[1], -f[2]))
			end
		end
		assert(feitas == v.casas, v.nome .. ": casas insuficientes")

		-- spawns: chão livre (≥ 14 de construção), ≥ 20 entre si
		local sp = {}
		for _ = 1, 6000 do
			if #sp >= Mundo.spawnsPorVila then
				break
			end
			local x, z = cx + rng.entre(-limite + 4, limite - 4), cz + rng.entre(-limite + 4, limite - 4)
			local ok = not ctx.ocupado(x, z, 14)
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
			table.insert(ctx.spawnsPlanejados, { x = p[1], z = p[2], vila = v.nome })
		end
	end

	for i, v in Mundo.vilas do
		gerarVila(i, v)
	end

	-- -----------------------------------------------------------------------------------------------------------------
	-- Fábrica: 4 galpões em 2×2 em volta de um corredor central; pátio pela área do módulo de indústria
	-- -----------------------------------------------------------------------------------------------------------------
	do
		local F = Mundo.fabrica
		local r = plano.fabrica
		local cx, cz = F.centro[1], F.centro[2]
		pad(r, "Fabrica", COR.fabrica, F.piso or "DiamondPlate")
		local qs = {
			{ -1, -1, "galpao_maquinas" },
			{ 1, -1, "galpao_maquinas" },
			{ -1, 1, "galpao_estoque" },
			{ 1, 1, "galpao_oficina" },
		}
		for k, q in qs do
			if k <= F.galpoes then
				construir(q[3], cx + q[1] * 60, cz + q[2] * 50, { 0, -q[2] }, "fabrica", "Fabrica")
			end
		end
		-- livres do pátio: faixa externa, deixando as entradas das estradas (corredor de ±16 no eixo) abertas
		local function R(x0, x1, z0, z1)
			return { x0 = cx + x0, x1 = cx + x1, z0 = cz + z0, z1 = cz + z1 }
		end
		local livres = {
			R(-121, 121, -96, -81),
			R(-121, -16, 81, 96),
			R(16, 121, 81, 96),
			R(-121, -99, -76, -16),
			R(-121, -99, 16, 76),
			R(99, 121, -76, -16),
			R(99, 121, 16, 76),
		}
		chamarArea("edificios_industria", "patioFabrica", r, livres)
	end

	-- -----------------------------------------------------------------------------------------------------------------
	-- Planície (fazenda)
	-- -----------------------------------------------------------------------------------------------------------------
	do
		local P = Mundo.planicie
		pad(plano.planicie, "Planicie", COR.planicie, P.material or "Grass")
		chamarArea("edificios_industria", "fazenda", plano.planicie)
	end

	-- -----------------------------------------------------------------------------------------------------------------
	-- Posto da guarda florestal: no centro do pad, frente para o norte (a avenida chega por −Z)
	-- -----------------------------------------------------------------------------------------------------------------
	do
		local G = Mundo.guardaFlorestal
		pad(plano.guarda, "PostoGuarda", COR.guarda, "Ground")
		construir("guarda", G.centro[1], G.centro[2], { 0, -1 }, "guarda", "PostoGuarda")
	end

	-- -----------------------------------------------------------------------------------------------------------------
	-- POIs
	-- -----------------------------------------------------------------------------------------------------------------
	local function faixa(nome: string, x0, x1, z0, z1, cor, material: string)
		return ctx.laje("Ruas", nome, x0, x1, z0, z1, NIVEL + 0.12, 0.3, cor, material)
	end

	local construtores = {}

	construtores.cemiterio = function(_p, r)
		chamarArea("edificios_especiais", "cemiterio", r)
	end
	construtores.acampamento = function(_p, r)
		chamarArea("edificios_especiais", "acampamento", r)
	end
	construtores.serraria = function(_p, r)
		chamarArea("edificios_industria", "serraria", r)
	end
	construtores.ferroVelho = function(_p, r)
		chamarArea("edificios_industria", "ferroVelho", r)
	end

	-- posto + lanchonete + motel de frente para o oeste (a estrada de acesso entra pelo lado −X do pad)
	construtores.parada = function(p, r)
		local cx, cz = p.centro[1], p.centro[2]
		local oeste = { -1, 0 }
		local x1 = r.x1 - 6
		local dp, dl, dm = Cat.def.posto, Cat.def.lanchonete_estrada, Cat.def.motel
		-- estacionamento asfaltado no meio, entre as fileiras
		local xl0, xl1 = r.x0 + 38, r.x0 + 68
		faixa("Estacionamento", xl0, xl1, r.z0 + 4, r.z1 - 4, { 58, 58, 60 }, "Asphalt")
		local z = r.z0 + 8
		while z < r.z1 - 8 do
			if abs(z - cz) > 16 then
				ctx.bloco(
					ctx.pastas.Ruas,
					nada,
					"Vaga",
					(xl0 + xl1) / 2 + 6,
					NIVEL + 0.27,
					z,
					12,
					0.05,
					0.4,
					{ 180, 180, 175 },
					"Asphalt",
					{ colide = false, consulta = false, sombra = false }
				)
			end
			z += 10
		end
		-- fundo: posto (d=44 em X). Frente: lanchonete ao norte da entrada e motel ao sul, junto à borda oeste
		construir("posto", x1 - dp.d / 2, cz + 22, oeste, "floresta", p.nome)
		construir("lanchonete_estrada", r.x0 + 6 + dl.d / 2, cz - 50, oeste, "floresta", p.nome)
		construir("motel", r.x0 + 6 + dm.d / 2, cz + 48, oeste, "floresta", p.nome)
	end

	construtores.igrejaIsolada = function(p, r)
		local cx, cz = p.centro[1], p.centro[2]
		-- estacionamento de cascalho na frente (oeste)
		faixa("EstacionamentoCascalho", r.x0 + 3, r.x0 + 26, cz - 40, cz + 40, { 120, 112, 98 }, "Pebble")
		construir("igreja", cx + 10, cz - 20, { -1, 0 }, "floresta", p.nome)
		-- mini-cemitério ao sul da igreja: grade de 5×4 = 20 lápides, cerca em três lados
		local gx0, gz0 = cx - 12, cz + 12
		for c = 0, 4 do
			for l = 0, 3 do
				colocarProp("lapide", gx0 + c * 10, gz0 + 5 + l * 7, 0, { variante = rng.inteiro(1, 5), rng = rng })
			end
		end
		local ax0, ax1, az1 = gx0 - 6, gx0 + 46, math.min(r.z1 - 3, gz0 + 36)
		colocarProp("cerca_madeira", (ax0 + ax1) / 2, az1, 0, { w = ax1 - ax0 })
		colocarProp("cerca_madeira", ax0, (gz0 + az1) / 2, pi / 2, { w = az1 - gz0 })
		colocarProp("cerca_madeira", ax1, (gz0 + az1) / 2, pi / 2, { w = az1 - gz0 })
		ctx.inserirObstaculo(ax0, ax1, gz0, az1)
	end

	for _, p in plano.pois do
		local cfg = PAD_POI[p.tipo]
		if not cfg then
			aviso(`POI {p.nome}: tipo '{p.tipo}' sem construtor (só o pad)`)
			cfg = { { 90, 84, 70 }, "Ground" }
		end
		pad(p, p.nome, cfg[1], cfg[2])
		local fn = construtores[p.tipo]
		if fn then
			fn(p, p)
		end
	end

	if next(Cat.faltando) then
		local nomes = {}
		for n in Cat.faltando do
			table.insert(nomes, n)
		end
		table.sort(nomes)
		aviso("edifícios ainda em caixa cinza: " .. table.concat(nomes, ", "))
	end
end

return M
