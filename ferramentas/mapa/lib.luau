-- Biblioteca compartilhada do gerador de mapa (Lune). Cria o `ctx` que todo módulo de ferramentas/mapa/ recebe.
-- Contrato completo: docs/mapa-v2.md. Dono: Opus (integração). Quem escreve módulo NÃO edita este arquivo: se faltar
-- uma função, escreva no próprio módulo e avise no relatório final.
--
-- Convenções
--   * Unidade: stud (≈ 0,33 m). Porta 4,5×7,5; andar 12; passo do personagem 16 st/s; pulo 6.
--   * "cf" é o CFrame do quadro local de um objeto (origem no centro da pegada, Y = topo do piso). Frente = −Z local.
--     Rotação só em múltiplos de 90° para construções (o checker usa caixas alinhadas aos eixos).
--   * Toda peça é Anchored. Toda posição "cx, cy, cz" local é do CENTRO da peça, relativa a cf.

local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local floor, ceil, min, max, abs, sqrt, pi = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt, math.pi

local lib = {}

lib.NIVEL_PAD = 0.5 -- topo das áreas planas construídas (asfalto, pads); a floresta/relevo sobe e desce em volta
lib.PASTAS = { "Chao", "Ruas", "Construcoes", "Vegetacao", "Bordas", "Zonas", "Pontos", "Rios", "Props" }

-- Tipos de construção válidos (atributo Tipo do Model) → tabela de loot padrão (chave de Config/Itens.tabelas).
-- Quem precisar de um tipo novo avisa o Opus; não inventar tipo fora desta lista.
lib.TIPOS = {
	casa = "casa",
	cabana = "casa",
	apartamentos = "casa",
	predio = "casa",
	escritorio = "casa",
	torre = "casa",
	hotel = "casa",
	motel = "casa",
	garagem = "casa",
	prefeitura = "casa",
	escola = "casa",
	biblioteca = "casa",
	igreja = "casa",
	capela = "casa",
	cripta = "casa",
	banco = "loja",
	loja = "loja",
	mercado = "loja",
	farmacia = "loja",
	restaurante = "loja",
	bar = "loja",
	lanchonete = "loja",
	posto = "posto",
	hospital = "hospital",
	delegacia = "guarda",
	bombeiros = "guarda",
	guarda = "guarda",
	galpao = "fabrica",
	armazem = "fabrica",
	celeiro = "fabrica",
	serraria = "fabrica",
	oficina = "fabrica",
}

-- ---------------------------------------------------------------------------------------------------------------
-- Aleatório determinístico (Park-Miller). Cada módulo pede o seu: ctx.rng("nome") → semente = semente do mapa + hash
-- do nome, então mexer num módulo não muda o sorteio dos outros.
-- ---------------------------------------------------------------------------------------------------------------
local function novoRng(semente: number)
	local estado = semente % 2147483647
	if estado <= 0 then
		estado = 1
	end
	local r = {}
	function r.rnd(): number
		estado = (estado * 48271) % 2147483647
		return (estado - 1) / 2147483646
	end
	function r.entre(a: number, b: number): number
		return a + (b - a) * r.rnd()
	end
	function r.inteiro(a: number, b: number): number -- inclusivo
		return a + floor(r.rnd() * (b - a + 1))
	end
	function r.sinal(): number
		return if r.rnd() < 0.5 then -1 else 1
	end
	function r.chance(p: number): boolean
		return r.rnd() < p
	end
	function r.escolher(lista)
		return lista[r.inteiro(1, #lista)]
	end
	-- lista de { peso = n, ... }
	function r.sortear(lista)
		local total = 0
		for _, e in lista do
			total += e.peso
		end
		local x = r.rnd() * total
		for _, e in lista do
			x -= e.peso
			if x <= 0 then
				return e
			end
		end
		return lista[#lista]
	end
	return r
end
lib.novoRng = novoRng

local function hashNome(nome: string): number
	local h = 5381
	for i = 1, #nome do
		h = (h * 33 + string.byte(nome, i)) % 2147483647
	end
	return h
end

-- ---------------------------------------------------------------------------------------------------------------
-- Cores: tabelas { r, g, b } 0–255 (como no resto do projeto); rgb() converte para Color3
-- ---------------------------------------------------------------------------------------------------------------
function lib.rgb(c)
	if type(c) ~= "table" then
		return c -- já é Color3
	end
	return Color3.fromRGB(floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5))
end
function lib.variar(c, v: number, rng)
	local k = 1 + (rng.rnd() * 2 - 1) * v
	return { min(255, c[1] * k), min(255, c[2] * k), min(255, c[3] * k) }
end
function lib.escurecer(c, k: number)
	return { min(255, c[1] * k), min(255, c[2] * k), min(255, c[3] * k) }
end
function lib.misturar(a, b, t: number)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- ---------------------------------------------------------------------------------------------------------------
-- ctx
-- ---------------------------------------------------------------------------------------------------------------
function lib.novoCtx(Mundo, plano)
	local ctx = {}
	ctx.Mundo = Mundo
	ctx.plano = plano
	ctx.NIVEL_PAD = lib.NIVEL_PAD
	ctx.lib = lib

	local mapa = Instance.new("Model")
	mapa.Name = "Mapa"
	mapa:SetAttribute("Semente", Mundo.semente)
	ctx.mapa = mapa
	ctx.pastas = {}
	for _, nome in lib.PASTAS do
		local f = Instance.new("Folder")
		f.Name = nome
		f.Parent = mapa
		ctx.pastas[nome] = f
	end

	ctx.rng = function(nome: string)
		return novoRng((Mundo.semente or 1) + hashNome(nome))
	end
	ctx.rgb, ctx.variar, ctx.escurecer, ctx.misturar = lib.rgb, lib.variar, lib.escurecer, lib.misturar

	-- Altura do terreno (topo do chão natural) em (x,z). O módulo `relevo` substitui esta função. Fora das áreas
	-- planas é o chão sobre o qual árvores, pedras e monstros ficam.
	ctx.altura = function(_x: number, _z: number): number
		return 0
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Peças
	-- ------------------------------------------------------------------------------------------------------------
	local function aplicar(p, cor, material: string, op)
		p.Anchored = true
		p.Color = lib.rgb(cor)
		p.Material = (Enum.Material :: any)[material]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanTouch = false
		if op then
			if op.colide == false then
				p.CanCollide = false
			end
			if op.consulta == false then
				p.CanQuery = false
			end
			if op.transparencia then
				p.Transparency = op.transparencia
			end
			if op.refletancia then
				p.Reflectance = op.refletancia
			end
			if op.sombra == false then
				p.CastShadow = false
			end
		end
	end

	local function checar(nome: string, sx: number, sy: number, sz: number)
		assert(max(sx, sy, sz) <= Mundo.pecaMaxima, nome .. " passa de " .. Mundo.pecaMaxima .. " studs")
		assert(sx > 0 and sy > 0 and sz > 0, nome .. " com tamanho <= 0: " .. sx .. "," .. sy .. "," .. sz)
	end

	-- Bloco com centro em (cx,cy,cz) LOCAL a cf. op: colide=false, consulta=false, transparencia, refletancia,
	-- sombra=false, rotY (radianos, em torno do centro da peça, local), rot = CFrame extra (substitui rotY).
	function ctx.bloco(pai, cf, nome: string, cx, cy, cz, sx, sy, sz, cor, material: string, op)
		checar(nome, sx, sy, sz)
		local p = Instance.new("Part")
		p.Name = nome
		p.Size = Vector3.new(sx, sy, sz)
		local local_ = CFrame.new(cx, cy, cz)
		if op and op.rot then
			local_ = local_ * op.rot
		elseif op and op.rotY then
			local_ = local_ * CFrame.Angles(0, op.rotY, 0)
		end
		p.CFrame = cf * local_
		aplicar(p, cor, material, op)
		p.Parent = pai
		return p
	end

	-- Cilindro: eixo "y" (padrão, em pé), "x" ou "z" (deitado). diametro e comprimento em studs.
	function ctx.cilindro(pai, cf, nome: string, cx, cy, cz, diametro, comprimento, cor, material: string, op)
		checar(nome, diametro, comprimento, diametro)
		local p = Instance.new("Part")
		p.Name = nome
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(comprimento, diametro, diametro) -- o eixo do cilindro é X
		local eixo = (op and op.eixo) or "y"
		local rot = CFrame.new()
		if eixo == "y" then
			rot = CFrame.Angles(0, 0, pi / 2)
		elseif eixo == "z" then
			rot = CFrame.Angles(0, pi / 2, 0)
		end
		p.CFrame = cf * CFrame.new(cx, cy, cz) * rot
		aplicar(p, cor, material, op)
		p.Parent = pai
		return p
	end

	function ctx.esfera(pai, cf, nome: string, cx, cy, cz, diametro, cor, material: string, op)
		checar(nome, diametro, diametro, diametro)
		local p = Instance.new("Part")
		p.Name = nome
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(diametro, diametro, diametro)
		p.CFrame = cf * CFrame.new(cx, cy, cz)
		aplicar(p, cor, material, op)
		p.Parent = pai
		return p
	end

	-- Cunha (WedgePart): a face inclinada sobe de −Z (baixo) para +Z (alto)? Não: a cunha do Roblox tem a rampa
	-- descendo para +Z e a face vertical em −Z... confira com `ctx.rampa`, que cuida da orientação.
	function ctx.cunha(pai, cf, nome: string, cx, cy, cz, sx, sy, sz, cor, material: string, op)
		checar(nome, sx, sy, sz)
		local p = Instance.new("WedgePart")
		p.Name = nome
		p.Size = Vector3.new(sx, sy, sz)
		local local_ = CFrame.new(cx, cy, cz)
		if op and op.rot then
			local_ = local_ * op.rot
		elseif op and op.rotY then
			local_ = local_ * CFrame.Angles(0, op.rotY, 0)
		end
		p.CFrame = cf * local_
		aplicar(p, cor, material, op)
		p.Parent = pai
		return p
	end

	-- Rampa: laje inclinada (Block rotacionado) de (x0,y0,z0) a (x1,y1,z1) LOCAIS, a face de CIMA passando pela linha
	-- que liga os dois pontos. `larg` é a largura perpendicular; `esp` a espessura. Serve para rampas, telhados de duas
	-- águas, escadas lisas e topos de colina. A peça se estende exatamente entre os pontos (comprimento = distância).
	function ctx.rampa(pai, cf, nome: string, x0, y0, z0, x1, y1, z1, larg, esp, cor, material: string, op)
		local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
		local len = sqrt(dx * dx + dy * dy + dz * dz)
		checar(nome, larg, esp, len)
		local a = Vector3.new(x0, y0, z0)
		local b = Vector3.new(x1, y1, z1)
		local meio = (a + b) / 2
		-- quadro cujo −Z aponta de b para a e que não gira em torno do eixo
		-- (CFrame.lookAt do Lune erra a inclinação: monta-se a base à mão; −Z aponta de a para b)
		local frente = (b - a).Unit
		local direita = frente:Cross(Vector3.new(0, 1, 0))
		if direita.Magnitude < 1e-4 then
			direita = Vector3.new(1, 0, 0)
		end
		direita = direita.Unit
		local base = CFrame.fromMatrix(meio, direita, direita:Cross(frente), -frente)
		-- desloca meia espessura para baixo (a face de cima passa pela linha)
		local p = Instance.new("Part")
		p.Name = nome
		p.Size = Vector3.new(larg, esp, len)
		p.CFrame = cf * (base * CFrame.new(0, -esp / 2, 0))
		aplicar(p, cor, material, op)
		p.Parent = pai
		return p
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Superfícies pisáveis planas (retângulos com topo) → `topoEm`. Lajes registram sozinhas.
	-- ------------------------------------------------------------------------------------------------------------
	ctx.superficies = {}
	function ctx.registrarSuperficie(x0: number, x1: number, z0: number, z1: number, topo: number)
		table.insert(ctx.superficies, { x0 = x0, x1 = x1, z0 = z0, z1 = z1, topo = topo })
	end

	-- Topo do chão em (x,z): a maior superfície plana registrada que cobre o ponto; senão o relevo (ctx.altura).
	function ctx.topoEm(x: number, z: number): number
		local melhor = nil
		for _, s in ctx.superficies do
			if x >= s.x0 and x <= s.x1 and z >= s.z0 and z <= s.z1 and (melhor == nil or s.topo > melhor) then
				melhor = s.topo
			end
		end
		return melhor or ctx.altura(x, z)
	end

	-- Laje alinhada aos eixos MUNDO, topo em `topo`; x0..x1, z0..z1 em coordenadas de mundo. Registra superfície.
	function ctx.laje(pasta: string, nome: string, x0, x1, z0, z1, topo, espessura, cor, material: string, op)
		local p = ctx.bloco(
			ctx.pastas[pasta],
			CFrame.new(),
			nome,
			(x0 + x1) / 2,
			topo - espessura / 2,
			(z0 + z1) / 2,
			x1 - x0,
			espessura,
			z1 - z0,
			cor,
			material,
			op
		)
		ctx.registrarSuperficie(x0, x1, z0, z1, topo)
		return p
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Obstáculos (construções, troncos, estruturas): grade de baldes para "tem coisa aqui?"
	-- ------------------------------------------------------------------------------------------------------------
	local BALDE = 64
	local balde = {}
	local function chaveBalde(i: number, j: number): number
		return (i + 1000) * 10000 + (j + 1000)
	end
	function ctx.inserirObstaculo(x0: number, x1: number, z0: number, z1: number)
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
	function ctx.retanguloOcupado(x0: number, x1: number, z0: number, z1: number, margem: number): boolean
		for i = floor((x0 - margem) / BALDE), floor((x1 + margem) / BALDE) do
			for j = floor((z0 - margem) / BALDE), floor((z1 + margem) / BALDE) do
				local l = balde[chaveBalde(i, j)]
				if l then
					for _, r in l do
						if
							x0 - margem <= r[2]
							and x1 + margem >= r[1]
							and z0 - margem <= r[4]
							and z1 + margem >= r[3]
						then
							return true
						end
					end
				end
			end
		end
		return false
	end
	function ctx.ocupado(x: number, z: number, margem: number): boolean
		return ctx.retanguloOcupado(x, x, z, z, margem)
	end

	-- Caixa (no mundo) de uma pegada com cf e tamanho local (w em X, d em Z): para inserirObstaculo
	function lib.caixaMundo(cf, w: number, d: number)
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf:PointToWorldSpace(Vector3.new(sx * w / 2, 0, sz * d / 2))
				x0, x1 = min(x0, p.X), max(x1, p.X)
				z0, z1 = min(z0, p.Z), max(z1, p.Z)
			end
		end
		return x0, x1, z0, z1
	end
	ctx.caixaMundo = lib.caixaMundo

	-- ------------------------------------------------------------------------------------------------------------
	-- Pontos (Spawn/Loot/Monstro) e loot de interior
	-- ------------------------------------------------------------------------------------------------------------
	ctx.contagemPontos = { Spawn = 0, Loot = 0, Monstro = 0 }
	ctx.contagemMonstro = {}
	ctx.pontosPendentes = {} -- { nome, x, y, z, atributos }: criados por gerar_mapa no fim (ordem estável)

	-- Registra um ponto. y = nil → topo do chão + 0,5. y dado = Y absoluto do CENTRO do ponto (loot em interiores).
	function ctx.ponto(nome: string, x: number, z: number, atributos, y: number?)
		ctx.contagemPontos[nome] += 1
		table.insert(ctx.pontosPendentes, { nome = nome, x = x, z = z, y = y, atributos = atributos })
	end

	-- Loot em posição de mundo (interiores): topoPiso = Y do piso onde a caixa fica; o ponto fica 0,5 acima.
	function ctx.loot(x: number, topoPiso: number, z: number, tabela: string, zona: string)
		ctx.ponto("Loot", x, z, { Tabela = tabela, Zona = zona }, topoPiso + 0.5)
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Interiores: paredes com aberturas, pisos com furos, escadas, telhados. Tudo em coordenadas LOCAIS a cf.
	-- ------------------------------------------------------------------------------------------------------------

	-- Parede reta (alinhada ao eixo X ou Z LOCAL) do ponto a=(x,z) ao ponto b=(x,z), do chão `base` (Y local) a
	-- base+altura. Espessura esp, centrada na linha a–b. Estende meia espessura em cada ponta (fecha cantos) — passe
	-- op.ext = 0 para não estender. aberturas = lista de:
	--   { de = distância de `a` ao CENTRO da abertura, larg, tipo = "porta"|"janela"|"vao"|"arco",
	--     alt = altura da abertura (porta/vao/arco: 7,5 padrão; janela: 3,6), peitoril = altura do parapeito (janela:
	--     3,4 padrão; porta: 0), vidro = true|false (janela; padrão true), cor = moldura/porta }
	-- Porta: vão livre com folha entreaberta e batente. Janela: vidro Glass (sem CanQuery? não: consulta true) +
	-- moldura. Devolve a lista de partes de parede (sem o vidro).
	function ctx.parede(
		pai,
		cf,
		nome: string,
		a,
		b,
		base: number,
		altura: number,
		esp: number,
		cor,
		material: string,
		aberturas,
		op
	)
		local ax, az, bx, bz = a[1], a[2], b[1], b[2]
		local horizontal = abs(az - bz) < 0.001 -- ao longo de X
		assert(horizontal or abs(ax - bx) < 0.001, nome .. ": parede fora dos eixos locais")
		local ext = if op and op.ext ~= nil then op.ext else esp / 2
		local sentido = if horizontal then (if bx >= ax then 1 else -1) else (if bz >= az then 1 else -1)
		local comp = (if horizontal then abs(bx - ax) else abs(bz - az)) + 2 * ext
		-- t = distância ao longo da parede a partir do início ESTENDIDO
		local function pos(t: number) -- t medido a partir do ponto a (sem extensão); devolve x, z locais
			if horizontal then
				return ax + sentido * t, az
			end
			return ax, az + sentido * t
		end
		local function trecho(t0: number, t1: number, y0: number, y1: number, nomePeca: string, c, m: string, o)
			-- peça de parede entre t0 e t1 (ao longo) e y0..y1 (altura local, absoluta)
			if t1 - t0 < 0.01 or y1 - y0 < 0.01 then
				return nil
			end
			local x0, z0 = pos(t0)
			local x1, z1 = pos(t1)
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			local sx, sz
			if horizontal then
				sx, sz = abs(x1 - x0), esp
			else
				sx, sz = esp, abs(z1 - z0)
			end
			return ctx.bloco(pai, cf, nomePeca, cx, (y0 + y1) / 2, cz, sx, y1 - y0, sz, c, m, o)
		end

		local lista = {}
		for _, ab in aberturas or {} do
			table.insert(lista, ab)
		end
		table.sort(lista, function(p, q)
			return p.de < q.de
		end)

		local partes = {}
		local cursor = -ext
		local topo = base + altura
		for _, ab in lista do
			local meia = ab.larg / 2
			local t0, t1 = ab.de - meia, ab.de + meia
			local tipo = ab.tipo or "porta"
			local peit = ab.peitoril or (if tipo == "janela" then 3.4 else 0)
			local alt = ab.alt or (if tipo == "janela" then 3.6 else 7.5)
			if tipo == "arco" then
				alt = ab.alt or 8
			end
			table.insert(partes, trecho(cursor, t0, base, topo, nome, cor, material, op))
			if peit > 0 then
				table.insert(partes, trecho(t0, t1, base, base + peit, nome, cor, material, op))
			end
			table.insert(partes, trecho(t0, t1, base + peit + alt, topo, nome, cor, material, op))
			local cx, cz = pos((t0 + t1) / 2)
			local corAb = ab.cor or lib.escurecer(cor, 0.5)
			if tipo == "janela" then
				local yc = base + peit + alt / 2
				if ab.vidro ~= false then
					local sx, sz = if horizontal then ab.larg else 0.25, if horizontal then 0.25 else ab.larg
					ctx.bloco(pai, cf, "Vidro", cx, yc, cz, sx, alt, sz, { 150, 175, 190 }, "Glass", {
						transparencia = 0.6,
						sombra = false,
					})
				end
				-- moldura em cruz
				local fx, fz = if horizontal then ab.larg + 0.4 else 0.5, if horizontal then 0.5 else ab.larg + 0.4
				ctx.bloco(
					pai,
					cf,
					"Moldura",
					cx,
					base + peit - 0.2,
					cz,
					fx,
					0.4,
					fz,
					corAb,
					"WoodPlanks",
					{ colide = false }
				)
				ctx.bloco(
					pai,
					cf,
					"Moldura",
					cx,
					base + peit + alt + 0.2,
					cz,
					fx,
					0.4,
					fz,
					corAb,
					"WoodPlanks",
					{ colide = false }
				)
				local mx, mz = if horizontal then 0.3 else 0.5, if horizontal then 0.5 else 0.3
				ctx.bloco(pai, cf, "Caixilho", cx, yc, cz, mx, alt, mz, corAb, "WoodPlanks", { colide = false })
			elseif tipo == "porta" then
				-- batente (verga) e folha entreaberta junto à lateral, sem bloquear a passagem
				local sx, sz = if horizontal then ab.larg + 0.6 else 0.5, if horizontal then 0.5 else ab.larg + 0.6
				ctx.bloco(
					pai,
					cf,
					"Batente",
					cx,
					base + alt + 0.25,
					cz,
					sx,
					0.5,
					sz,
					corAb,
					"WoodPlanks",
					{ colide = false }
				)
				-- folha entreaberta (75°) presa à lateral esquerda; não colide, não bloqueia o vão
				local ux, uz = if horizontal then sentido else 0, if horizontal then 0 else sentido
				local nx, nz = -uz, ux
				local th = 1.3
				local dx, dz = math.cos(th) * ux + math.sin(th) * nx, math.cos(th) * uz + math.sin(th) * nz
				local len = ab.larg - 0.4
				local hx, hz = pos(t0 + 0.2)
				ctx.bloco(
					pai,
					cf,
					"Folha",
					hx + dx * len / 2,
					base + (alt - 0.2) / 2,
					hz + dz * len / 2,
					len,
					alt - 0.2,
					0.3,
					corAb,
					"WoodPlanks",
					{
						colide = false,
						consulta = false,
						rotY = math.atan2(-dz, dx),
					}
				)
			end
			cursor = t1
		end
		table.insert(partes, trecho(cursor, comp - ext, base, topo, nome, cor, material, op))
		return partes
	end

	-- Piso/forro: retângulo (x0..x1, z0..z1) locais, topo em `topo` (Y local), com furos (lista de { x0,x1,z0,z1 }
	-- locais) para escada/poço. Devolve a lista de peças.
	function ctx.piso(
		pai,
		cf,
		nome: string,
		x0,
		x1,
		z0,
		z1,
		topo: number,
		esp: number,
		cor,
		material: string,
		furos,
		op
	)
		local rects = { { x0, x1, z0, z1 } }
		for _, f in furos or {} do
			local novos = {}
			for _, r in rects do
				if f.x1 <= r[1] or f.x0 >= r[2] or f.z1 <= r[3] or f.z0 >= r[4] then
					table.insert(novos, r)
				else
					if f.x0 > r[1] then
						table.insert(novos, { r[1], f.x0, r[3], r[4] })
					end
					if f.x1 < r[2] then
						table.insert(novos, { f.x1, r[2], r[3], r[4] })
					end
					local ix0, ix1 = max(r[1], f.x0), min(r[2], f.x1)
					if f.z0 > r[3] then
						table.insert(novos, { ix0, ix1, r[3], f.z0 })
					end
					if f.z1 < r[4] then
						table.insert(novos, { ix0, ix1, f.z1, r[4] })
					end
				end
			end
			rects = novos
		end
		local pecas = {}
		for _, r in rects do
			if r[2] - r[1] > 0.01 and r[4] - r[3] > 0.01 then
				table.insert(
					pecas,
					ctx.bloco(
						pai,
						cf,
						nome,
						(r[1] + r[2]) / 2,
						topo - esp / 2,
						(r[3] + r[4]) / 2,
						r[2] - r[1],
						esp,
						r[4] - r[3],
						cor,
						material,
						op
					)
				)
			end
		end
		return pecas
	end

	-- Escada reta. Começa em (x,z) locais (pé da escada, no piso de baixo, topo = yBase) e sobe `altura` na direção
	-- dir = "+x" | "-x" | "+z" | "-z". Degraus de `subida` (≤ 1) por `passada` de comprimento. Devolve o retângulo
	-- (x0,x1,z0,z1) que ela ocupa — use como furo no piso de cima (o topo do último degrau fica a `subida` do piso).
	function ctx.escada(
		pai,
		cf,
		nome: string,
		x: number,
		z: number,
		dir: string,
		yBase: number,
		altura: number,
		larg: number,
		cor,
		material: string,
		op
	)
		local subida = (op and op.subida) or 1
		local passada = (op and op.passada) or 1.5
		local n = ceil(altura / subida)
		local sub = altura / n
		local comp = n * passada
		local sx, sz =
			if dir == "+x" or dir == "-x" then comp else larg, if dir == "+x" or dir == "-x" then larg else comp
		-- centro do retângulo ocupado
		local cx = x + (if dir == "+x" then comp / 2 elseif dir == "-x" then -comp / 2 else 0)
		local cz = z + (if dir == "+z" then comp / 2 elseif dir == "-z" then -comp / 2 else 0)
		for i = 1, n do
			local ofs = (i - 0.5) * passada
			local px = x + (if dir == "+x" then ofs elseif dir == "-x" then -ofs else 0)
			local pz = z + (if dir == "+z" then ofs elseif dir == "-z" then -ofs else 0)
			local h = i * sub
			local psx, psz = if sx == comp then passada else larg, if sx == comp then larg else passada
			ctx.bloco(pai, cf, nome, px, yBase + h / 2, pz, psx, h, psz, cor, material, op)
		end
		return { x0 = cx - sx / 2, x1 = cx + sx / 2, z0 = cz - sz / 2, z1 = cz + sz / 2, comprimento = comp }
	end

	-- Comprimento (studs) de uma escada de `altura` com os parâmetros padrão: para reservar espaço na planta
	function ctx.comprimentoEscada(altura: number, op)
		local subida = (op and op.subida) or 1
		local passada = (op and op.passada) or 1.5
		return ceil(altura / subida) * passada
	end

	-- Telhado de duas águas sobre w×d (X×Z local), beiral `beiral`, cumeeira ao longo de Z se `cumeeiraZ` (padrão ao
	-- longo do lado maior). yBase = topo da parede; sobe `altura` até a cumeeira. Devolve as peças.
	function ctx.telhadoDuasAguas(
		pai,
		cf,
		nome: string,
		cx: number,
		cz: number,
		w: number,
		d: number,
		yBase: number,
		altura: number,
		beiral: number,
		esp: number,
		cor,
		material: string,
		cumeeiraZ: boolean?
	)
		local ao_longo_z = if cumeeiraZ ~= nil then cumeeiraZ else d >= w
		local pecas = {}
		local ww, dd = w + 2 * beiral, d + 2 * beiral
		if ao_longo_z then
			for _, s in { -1, 1 } do
				table.insert(
					pecas,
					ctx.rampa(pai, cf, nome, cx + s * ww / 2, yBase, cz, cx, yBase + altura, cz, dd, esp, cor, material)
				)
			end
		else
			for _, s in { -1, 1 } do
				table.insert(
					pecas,
					ctx.rampa(pai, cf, nome, cx, yBase, cz + s * dd / 2, cx, yBase + altura, cz, ww, esp, cor, material)
				)
			end
		end
		return pecas
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Modelo de construção: cria o Model com atributos e a "Pegada" (retângulo invisível usado pelo checker e pelo
	-- plano). Chame uma vez por construção; as peças vão em `modelo`. Devolve o Model.
	-- ------------------------------------------------------------------------------------------------------------
	ctx.contadorModelos = 0
	function ctx.modeloConstrucao(
		spec,
		tipo: string,
		variante: string,
		w: number,
		d: number,
		altura: number,
		andares: number
	)
		ctx.contadorModelos += 1
		local m = Instance.new("Model")
		m.Name = tipo .. "_" .. variante .. "_" .. ctx.contadorModelos
		m:SetAttribute("Tipo", tipo)
		m:SetAttribute("Variante", variante)
		m:SetAttribute("Zona", spec.zona)
		m:SetAttribute("Andares", andares)
		m:SetAttribute("Interior", true)
		if spec.local_ then
			m:SetAttribute("Local", spec.local_)
		end
		local pegada = ctx.bloco(
			m,
			spec.cf,
			"Pegada",
			0,
			altura / 2,
			0,
			w,
			altura,
			d,
			{ 255, 255, 255 },
			"SmoothPlastic",
			{ transparencia = 1, colide = false, consulta = false }
		)
		m.PrimaryPart = pegada;
		(m :: any).ModelStreamingMode = (Enum :: any).ModelStreamingMode.Atomic
		m.Parent = ctx.pastas.Construcoes
		local x0, x1, z0, z1 = lib.caixaMundo(spec.cf, w, d)
		ctx.inserirObstaculo(x0 - 0.6, x1 + 0.6, z0 - 0.6, z1 + 0.6)
		return m
	end

	-- ------------------------------------------------------------------------------------------------------------
	-- Registro de construções (loot + checker). Quem coloca uma construção chama isto depois de construir.
	--   spec = o mesmo spec passado ao construtor (cf, zona, w, d); info = o 2º retorno do construtor:
	--   info.loot = { { x, y, z, tabela? } } em coordenadas LOCAIS a spec.cf (y = topo do piso local), podendo ficar
	--   dentro do prédio; sem loot em info, vai um ponto na calçada em frente à porta (info.frente = {x,z} local).
	-- ------------------------------------------------------------------------------------------------------------
	ctx.construcoes = {}
	function ctx.registrarConstrucao(spec, modelo, info)
		local tipo = modelo:GetAttribute("Tipo")
		local tabelaPadrao = lib.TIPOS[tipo]
		assert(tabelaPadrao, "Tipo de construção fora de lib.TIPOS: " .. tostring(tipo))
		local zona = spec.zona
		local n = 0
		for _, l in (info and info.loot) or {} do
			local p = spec.cf:PointToWorldSpace(Vector3.new(l.x, l.y, l.z))
			ctx.loot(p.X, p.Y, p.Z, l.tabela or (info and info.tabela) or tabelaPadrao, zona)
			n += 1
		end
		if n == 0 then
			local f = (info and info.frente) or { 0, -(spec.d / 2 + 4) }
			local p = spec.cf:PointToWorldSpace(Vector3.new(f[1], 0, f[2]))
			ctx.ponto("Loot", p.X, p.Z, { Tabela = tabelaPadrao, Zona = zona })
			n = 1
		end
		if info and info.portaria then
			local p = spec.cf:PointToWorldSpace(Vector3.new(info.portaria[1], 0, info.portaria[2]))
			modelo:SetAttribute("PortaX", p.X)
			modelo:SetAttribute("PortaZ", p.Z)
			modelo:SetAttribute("BaseY", spec.cf.Position.Y)
		end
		table.insert(ctx.construcoes, { modelo = modelo, tipo = tipo, zona = zona, loot = n })
		return n
	end

	return ctx
end

-- Conta peças por pasta de um mapa
function lib.contar(mapa)
	local total = 0
	local linhas = {}
	local porPasta = {}
	for _, nome in lib.PASTAS do
		local f = mapa:FindFirstChild(nome)
		local n = 0
		if f then
			for _, d in f:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
				end
			end
		end
		porPasta[nome] = n
		total += n
		table.insert(linhas, string.format("  %-12s %7d peças", nome, n))
	end
	return total, linhas, porPasta
end

return lib
