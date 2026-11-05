-- Checa mapa/Mapa.rbxm (saída de ferramentas/gerar_mapa.luau) contra o contrato de docs/mapa-v2.md.
-- Uso (da raiz do projeto): lune run ferramentas/checar_mapa.luau [arquivo.rbxm]   → código de saída ≠ 0 se alguma regra falhar.
--
-- Regras: pastas | peça solta, tamanho, orçamento | construções (atributos, Pegada, sem se atravessarem) | pontos (propriedades,
-- no chão, spawn longe de construção) | alcance a pé seco por grade 2D (spawns, loot externo e monstros; rios só se
-- atravessam por ponte) | interiores: do portão de cada construção até cada ponto de loot de dentro (grade 3D, degraus ≤ 1,3,
-- vão livre ≥ 5,5) | árvore em rua/construção | nada fora da borda | rios e props.
-- O chão pode ser inclinado (lajes do relevo): o topo vem do plano da face de cima de cada peça.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Mundo = require("../src/shared/Config/Mundo")
local Monstros = require("../src/shared/Config/Monstros")
local Itens = require("../src/shared/Config/Itens")
local Movimento = require("../src/shared/Config/Movimento")
local lib = require("./mapa/lib")
local planoMod = require("./mapa/plano")

local Vector3 = roblox.Vector3
local floor, ceil, min, max, abs, sqrt = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt

-- ---------------------------------------------------------------------------------------------------------------
-- Números (a fonte de cada um está no comentário)
-- ---------------------------------------------------------------------------------------------------------------
local CELULA = 4 -- studs por célula da grade de alcance externo
local RAIO = 1.5 -- meia largura do personagem (folga em volta de obstáculos)
local MARGEM = 0.9 -- usa 90% do pulo (skill mapa-roblox)
local DEGRAU = Movimento.alturaPulo * MARGEM -- maior diferença de altura entre células vizinhas, ao ar livre
local SPAWN_LONGE = 8 -- studs mínimos entre spawn e qualquer construção
local TOL_Y = 0.15 -- tolerância do Y dos pontos (topo + 0.5): o relevo é aproximado por lajes inclinadas
local ALTURA_JOGADOR = 5.0 -- vão livre mínimo acima de uma superfície
local DEGRAU_INTERIOR = 1.3 -- maior subida de um degrau (a lib faz degraus de 1)
local CELULA_INT = 1 -- studs por célula da grade 3D dos interiores (degrau de escada tem 1 de passada)
local PROF_AGUA = 1.5 -- rio mais fundo que isto (e sem ponte por cima) não se anda a pé
local PASTAS = lib.PASTAS
local ZONAS = { cidade = true, vila = true, floresta = true, fabrica = true, planicie = true, guarda = true }
local LIMITES_PASTA = {
	Chao = 12000,
	Ruas = 8000,
	Construcoes = 80000,
	Vegetacao = 55000,
	Props = 22000,
	Rios = 800,
}

local falhas: { string } = {}
local avisos: { string } = {}
local function falha(regra: string, msg: string)
	if #falhas < 200 then
		table.insert(falhas, regra .. ": " .. msg)
	end
end
local function aviso(regra: string, msg: string)
	table.insert(avisos, regra .. ": " .. msg)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Carregar
-- ---------------------------------------------------------------------------------------------------------------
local arquivo = process.args[1] or "mapa/Mapa.rbxm"
local okLer, conteudo = pcall(fs.readFile, arquivo)
if not okLer then
	print("FALHA: " .. arquivo .. " não existe (rode ferramentas/gerar_mapa.luau da raiz do projeto)")
	process.exit(1)
end
local raizes = roblox.deserializeModel(conteudo)
local mapa = raizes[1]
if not mapa or mapa.Name ~= "Mapa" then
	print("FALHA: a raiz do .rbxm precisa se chamar Mapa")
	process.exit(1)
end
local plano = planoMod.criar(Mundo)

local pasta = {}
for _, nome in PASTAS do
	local f = mapa:FindFirstChild(nome)
	if not f then
		falha("ESTRUTURA", "falta a pasta Mapa." .. nome)
	end
	pasta[nome] = f
end
if #falhas > 0 then
	print(table.concat(falhas, "\n"))
	process.exit(1)
end
for _, f in mapa:GetChildren() do
	if not pasta[f.Name] or pasta[f.Name] ~= f then
		falha("ESTRUTURA", "filho inesperado em Mapa: " .. f.Name)
	end
end

type Caixa = { x0: number, x1: number, z0: number, z1: number, topo: number, base: number }

-- Caixa alinhada aos eixos (conservadora para peça girada)
local function caixa(p): Caixa
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = abs(r.X) * s.X / 2 + abs(u.X) * s.Y / 2 + abs(l.X) * s.Z / 2
	local ey = abs(r.Y) * s.X / 2 + abs(u.Y) * s.Y / 2 + abs(l.Y) * s.Z / 2
	local ez = abs(r.Z) * s.X / 2 + abs(u.Z) * s.Y / 2 + abs(l.Z) * s.Z / 2
	local pos = cf.Position
	return {
		x0 = pos.X - ex,
		x1 = pos.X + ex,
		z0 = pos.Z - ez,
		z1 = pos.Z + ez,
		topo = pos.Y + ey,
		base = pos.Y - ey,
	}
end

-- Altura da FACE DE CIMA (local +Y) da peça em (x,z), ou nil se (x,z) cai fora dela. Serve para lajes inclinadas.
-- Devolve também a altura da face de baixo (para vão livre nos interiores).
local function faceEm(p, x: number, z: number): (number?, number?)
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	if abs(u.Y) < 0.5 then
		return nil, nil -- peça deitada de lado: sem face de cima horizontal
	end
	local pos = cf.Position
	local dx, dz = x - pos.X, z - pos.Z
	-- resolve dx = r.X*a + l.X*b + u.X*h ; dz = r.Z*a + l.Z*b + u.Z*h  (h = ± s.Y/2) para a, b
	local function resolver(h: number): (number?, number?, number?)
		local rx, lx, rz, lz = r.X, l.X, r.Z, l.Z
		local det = rx * lz - lx * rz
		if abs(det) < 1e-6 then
			return nil, nil, nil
		end
		local bx, bz = dx - u.X * h, dz - u.Z * h
		local a = (bx * lz - lx * bz) / det
		local b = (rx * bz - bx * rz) / det
		if abs(a) > s.X / 2 + 1e-4 or abs(b) > s.Z / 2 + 1e-4 then
			return nil, nil, nil
		end
		return pos.Y + r.Y * a + l.Y * b + u.Y * h, a, b
	end
	local topo = resolver(s.Y / 2)
	if not topo then
		return nil, nil
	end
	local base = resolver(-s.Y / 2) or (topo - s.Y)
	return topo, base
end

-- ---------------------------------------------------------------------------------------------------------------
-- Peças: contagem, solta, tamanho
-- ---------------------------------------------------------------------------------------------------------------
local total = 0
local porPasta = {}
for _, nome in PASTAS do
	local n = 0
	for _, d in pasta[nome]:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if not d.Anchored then
				falha("SOLTA", d:GetFullName() .. " não está ancorada")
			end
			local s = d.Size
			if max(s.X, s.Y, s.Z) > Mundo.pecaMaxima then
				falha(
					"TAMANHO",
					string.format("%s tem %.0f×%.0f×%.0f (> %d)", d:GetFullName(), s.X, s.Y, s.Z, Mundo.pecaMaxima)
				)
			end
		end
	end
	porPasta[nome] = n
	total += n
	if LIMITES_PASTA[nome] and n > LIMITES_PASTA[nome] then
		aviso("ORCAMENTO", string.format("%s tem %d peças (alvo %d)", nome, n, LIMITES_PASTA[nome]))
	end
end
if total > Mundo.limitePecas then
	falha("ORCAMENTO", string.format("%d peças (limite %d)", total, Mundo.limitePecas))
end

-- ---------------------------------------------------------------------------------------------------------------
-- Construções
-- ---------------------------------------------------------------------------------------------------------------
local predios = {} -- { modelo, c = Caixa (pegada), x0.. }
local placeholders = 0
for _, m in pasta.Construcoes:GetChildren() do
	if not m:IsA("Model") then
		falha("CONSTRUCAO", m:GetFullName() .. " não é Model")
		continue
	end
	local tipo = m:GetAttribute("Tipo")
	if not (type(tipo) == "string" and lib.TIPOS[tipo]) then
		falha("CONSTRUCAO", m.Name .. ": atributo Tipo inválido (" .. tostring(tipo) .. ")")
	end
	if not ZONAS[m:GetAttribute("Zona") :: any] then
		falha("CONSTRUCAO", m.Name .. ": atributo Zona inválido (" .. tostring(m:GetAttribute("Zona")) .. ")")
	end
	local andares = m:GetAttribute("Andares")
	if type(andares) ~= "number" or andares < 1 then
		falha("CONSTRUCAO", m.Name .. ": atributo Andares inválido")
	end
	if m:GetAttribute("Interior") ~= true then
		falha("CONSTRUCAO", m.Name .. ": atributo Interior precisa ser true")
	end
	if m:GetAttribute("Placeholder") then
		placeholders += 1
	end
	local pegada = m:FindFirstChild("Pegada")
	if not pegada or not pegada:IsA("BasePart") then
		falha("CONSTRUCAO", m.Name .. ": sem a peça Pegada")
		continue
	end
	if pegada.CanCollide or pegada.CanQuery or pegada.Transparency ~= 1 then
		falha("CONSTRUCAO", m.Name .. ": Pegada precisa Transparency 1, CanCollide e CanQuery false")
	end
	table.insert(predios, { modelo = m, c = caixa(pegada), pegada = pegada })
end
if placeholders > 0 then
	aviso("PLACEHOLDER", placeholders .. " construções ainda são caixas cinza (módulo de edifício faltando)")
end
for i = 1, #predios do
	for j = i + 1, #predios do
		local a, b = predios[i].c, predios[j].c
		if a.x0 < b.x1 - 0.01 and a.x1 > b.x0 + 0.01 and a.z0 < b.z1 - 0.01 and a.z1 > b.z0 + 0.01 then
			falha("ENFIADA", predios[i].modelo.Name .. " e " .. predios[j].modelo.Name .. " se atravessam")
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Chão (Chao + Ruas colidindo), troncos (Vegetacao) e grade de alcance
-- ---------------------------------------------------------------------------------------------------------------
local troncos: { Caixa } = {}
for _, p in pasta.Vegetacao:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		if p.Name == "Tronco" then
			table.insert(troncos, caixa(p))
		elseif p.Name ~= "Mancha" then
			falha("VEGETACAO", p:GetFullName() .. " colide mas não é Tronco nem Mancha")
		end
	end
end

local chaoPecas = {} -- { p, c = Caixa, inclinada }
local ruas: { Caixa } = {}
for _, nome in { "Chao", "Ruas" } do
	for _, p in pasta[nome]:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			local c = caixa(p)
			table.insert(chaoPecas, { p = p, c = c })
			if nome == "Ruas" then
				table.insert(ruas, c)
			end
		end
	end
end
-- Vegetação que colide como "Mancha" também é chão
for _, p in pasta.Vegetacao:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and p.Name == "Mancha" then
		table.insert(chaoPecas, { p = p, c = caixa(p) })
	end
end

local meio = Mundo.tamanho / 2
local N = floor(Mundo.tamanho / CELULA)
local SEM_CHAO = -1e9
local topoCel = table.create(N * N, SEM_CHAO)
local bloq = table.create(N * N, false)

local function faixaCel(v0: number, v1: number): (number, number)
	local i0 = ceil((v0 + meio - CELULA / 2) / CELULA)
	local i1 = floor((v1 + meio - CELULA / 2) / CELULA)
	return max(0, i0), min(N - 1, i1)
end
local function centroCel(i: number): number
	return -meio + (i + 0.5) * CELULA
end

for _, e in chaoPecas do
	local c = e.c
	local i0, i1 = faixaCel(c.x0, c.x1)
	local j0, j1 = faixaCel(c.z0, c.z1)
	for j = j0, j1 do
		local fila = j * N + 1
		for i = i0, i1 do
			local t = faceEm(e.p, centroCel(i), centroCel(j))
			if t and t > topoCel[fila + i] then
				topoCel[fila + i] = t
			end
		end
	end
end

-- Obstáculos externos: pegada dos prédios, troncos, e props altos presos ao chão
local obstaculos: { Caixa } = {}
for _, b in predios do
	table.insert(obstaculos, b.c)
end
for _, t in troncos do
	table.insert(obstaculos, t)
end
local obstaculosProps = 0
for _, p in pasta.Props:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		local c = caixa(p)
		local pp = p.CFrame.Position
		local i, j = floor((pp.X + meio) / CELULA), floor((pp.Z + meio) / CELULA)
		if i >= 0 and i < N and j >= 0 and j < N then
			local t = topoCel[j * N + i + 1]
			if t ~= SEM_CHAO and c.topo - t > DEGRAU and c.base < t + 3 then
				table.insert(obstaculos, c)
				obstaculosProps += 1
			end
		end
	end
end
for _, c in obstaculos do
	local i0, i1 = faixaCel(c.x0 - RAIO, c.x1 + RAIO)
	local j0, j1 = faixaCel(c.z0 - RAIO, c.z1 + RAIO)
	for j = j0, j1 do
		local fila = j * N + 1
		for i = i0, i1 do
			bloq[fila + i] = true
		end
	end
end

local function celula(x: number, z: number): (number, number)
	return floor((x + meio) / CELULA), floor((z + meio) / CELULA)
end

local topoExato: (number, number) -> number?

-- Índice espacial simples para topoExato dos pontos (muitos): baldes de 128
local BAL = 128
local baldes = {}
local function chaveB(i: number, j: number): number
	return (i + 100) * 1000 + (j + 100)
end
for _, e in chaoPecas do
	local c = e.c
	for i = floor(c.x0 / BAL), floor(c.x1 / BAL) do
		for j = floor(c.z0 / BAL), floor(c.z1 / BAL) do
			local k = chaveB(i, j)
			local l = baldes[k]
			if not l then
				l = {}
				baldes[k] = l
			end
			table.insert(l, e)
		end
	end
end
topoExato = function(x: number, z: number): number?
	local melhor = nil
	local l = baldes[chaveB(floor(x / BAL), floor(z / BAL))]
	if l then
		for _, e in l do
			local c = e.c
			if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then
				local t = faceEm(e.p, x, z)
				if t and (melhor == nil or t > melhor) then
					melhor = t
				end
			end
		end
	end
	return melhor
end

-- Pegada (construção) que contém o ponto, se houver
local function predioEm(x: number, z: number)
	for _, b in predios do
		local c = b.c
		if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then
			return b
		end
	end
	return nil
end

local function dentroDeObstaculo(x: number, z: number): boolean
	for _, c in obstaculos do
		if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then
			return true
		end
	end
	return false
end

-- Água: rio fundo (pelo plano) sem peça de piso acima (ponte)
local function ehAgua(x: number, z: number): boolean
	if plano.profundidadeRio(x, z) <= PROF_AGUA then
		return false
	end
	local t = topoExato(x, z)
	return not (t and t > -0.5)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Pontos
-- ---------------------------------------------------------------------------------------------------------------
local spawns, loots, monstros = {}, {}, {}
local lootsInternos = {} -- { pos, predio }
local nomesVilas = {}
for _, v in Mundo.vilas do
	nomesVilas[v.nome] = 0
end
local contagemMonstroZona = {}
for chave in Monstros.densidade do
	contagemMonstroZona[chave] = 0
end

for _, p in pasta.Pontos:GetChildren() do
	local nome = p.Name
	if not p:IsA("BasePart") then
		falha("PONTO", p:GetFullName() .. " não é peça")
		continue
	end
	local pos = p.CFrame.Position
	if nome ~= "Spawn" and nome ~= "Loot" and nome ~= "Monstro" then
		falha("PONTO", "nome inesperado em Pontos: " .. nome)
		continue
	end
	local s = p.Size
	if s.X ~= 1 or s.Y ~= 1 or s.Z ~= 1 or p.Transparency ~= 1 or p.CanCollide or p.CanQuery or p.CanTouch then
		falha(
			"PONTO",
			string.format(
				"%s em (%.0f, %.0f): precisa 1×1×1, Transparency 1, CanCollide/CanQuery/CanTouch false",
				nome,
				pos.X,
				pos.Z
			)
		)
	end
	local zona = p:GetAttribute("Zona")
	local dentroPredio = if nome == "Loot" then predioEm(pos.X, pos.Z) else nil
	local interno = false
	if dentroPredio then
		-- loot dentro da pegada: o piso é peça do próprio prédio (checado depois, na grade 3D)
		interno = true
	else
		local topo = topoExato(pos.X, pos.Z)
		if not topo then
			falha("PONTO", string.format("%s em (%.0f, %.0f) está fora do chão", nome, pos.X, pos.Z))
			continue
		end
		-- Monstro: o relevo é aproximado por lajes, o monstro cai até o chão ao nascer → 1 st de folga.
		local tol = if nome == "Monstro" then 1.3 else 0.35
		if abs(pos.Y - (topo + 0.5)) > tol then
			-- loot elevado (torre, plataforma): vale se há peça colidindo de Props/Construcoes com o topo logo abaixo
			local apoiado = false
			if nome == "Loot" and pos.Y > topo + 0.5 then
				for _, pastaNome in { "Props", "Construcoes" } do
					for _, d in pasta[pastaNome]:GetDescendants() do
						if d:IsA("BasePart") and d.CanCollide then
							local t = faceEm(d, pos.X, pos.Z)
							if t and abs(t - (pos.Y - 0.5)) <= 0.35 then
								apoiado = true
								break
							end
						end
					end
					if apoiado then
						break
					end
				end
			end
			if not apoiado then
				falha(
					"PONTO",
					string.format(
						"%s em (%.0f, %.0f): Y %.2f, esperado %.2f (topo + 0.5)",
						nome,
						pos.X,
						pos.Z,
						pos.Y,
						topo + 0.5
					)
				)
			end
		end
	end
	if nome == "Spawn" then
		if nomesVilas[zona :: any] == nil then
			falha("SPAWN", string.format("Spawn em (%.0f, %.0f) com Zona inválida: %s", pos.X, pos.Z, tostring(zona)))
		else
			nomesVilas[zona :: any] += 1
		end
		table.insert(spawns, pos)
	elseif nome == "Loot" then
		local tabela = p:GetAttribute("Tabela")
		if type(tabela) ~= "string" or Itens.tabelas[tabela] == nil then
			falha(
				"LOOT",
				string.format("Loot em (%.0f, %.0f) com Tabela inválida: %s", pos.X, pos.Z, tostring(tabela))
			)
		end
		if not ZONAS[zona :: any] then
			falha("LOOT", string.format("Loot em (%.0f, %.0f) com Zona inválida: %s", pos.X, pos.Z, tostring(zona)))
		end
		if interno then
			table.insert(lootsInternos, { pos = pos, predio = dentroPredio })
		else
			table.insert(loots, pos)
		end
	else
		if type(zona) ~= "string" or Monstros.densidade[zona] == nil then
			falha(
				"MONSTRO",
				string.format(
					"Monstro em (%.0f, %.0f) com Zona fora de Config/Monstros.densidade: %s",
					pos.X,
					pos.Z,
					tostring(zona)
				)
			)
		else
			contagemMonstroZona[zona] += 1
		end
		if dentroDeObstaculo(pos.X, pos.Z) then
			falha(
				"MONSTRO",
				string.format("Monstro em (%.0f, %.0f) está dentro de construção/tronco/prop", pos.X, pos.Z)
			)
		end
		if ehAgua(pos.X, pos.Z) then
			falha("MONSTRO", string.format("Monstro em (%.0f, %.0f) está na água", pos.X, pos.Z))
		end
		table.insert(monstros, pos)
	end
end

for nome, n in nomesVilas do
	if n ~= Mundo.spawnsPorVila then
		falha("SPAWN", string.format("%s tem %d spawns (esperado %d)", nome, n, Mundo.spawnsPorVila))
	end
end
for chave, n in contagemMonstroZona do
	if n == 0 then
		falha("MONSTRO", "nenhum ponto Monstro com Zona = " .. chave)
	end
end
local nLoot = #loots + #lootsInternos
if #predios > 0 and nLoot < #predios * Mundo.pontosLootPorConstrucao then
	falha(
		"LOOT",
		string.format(
			"%d pontos de loot para %d construções (esperado %d por construção)",
			nLoot,
			#predios,
			Mundo.pontosLootPorConstrucao
		)
	)
end

-- Spawn: longe de construção
for _, sp in spawns do
	for _, b in predios do
		local c = b.c
		local dx = max(0, c.x0 - sp.X, sp.X - c.x1)
		local dz = max(0, c.z0 - sp.Z, sp.Z - c.z1)
		local d = sqrt(dx * dx + dz * dz)
		if d < SPAWN_LONGE then
			falha(
				"SPAWN",
				string.format(
					"Spawn em (%.0f, %.0f) a %.1f studs de %s (mínimo %d)",
					sp.X,
					sp.Z,
					d,
					b.modelo.Name,
					SPAWN_LONGE
				)
			)
			break
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Alcance a pé seco: BFS por células livres a partir do primeiro spawn
-- ---------------------------------------------------------------------------------------------------------------
local alcancada = table.create(N * N, false)
local nAlcancadas = 0
if #spawns == 0 then
	falha("SPAWN", "nenhum ponto Spawn no mapa")
else
	local fila = {}
	local cabeca, cauda = 1, 0
	local sp = spawns[1]
	local i0, j0 = celula(sp.X, sp.Z)
	local k0 = j0 * N + i0 + 1
	if bloq[k0] or topoCel[k0] == SEM_CHAO then
		falha("SPAWN", string.format("Spawn em (%.0f, %.0f) cai numa célula bloqueada", sp.X, sp.Z))
	else
		alcancada[k0] = true
		cauda += 1
		fila[cauda] = k0
	end
	while cabeca <= cauda do
		local k = fila[cabeca]
		cabeca += 1
		nAlcancadas += 1
		local i = (k - 1) % N
		local j = (k - 1 - i) // N
		local th = topoCel[k]
		for d = 1, 4 do
			local ni, nj = i, j
			if d == 1 then
				ni -= 1
			elseif d == 2 then
				ni += 1
			elseif d == 3 then
				nj -= 1
			else
				nj += 1
			end
			if ni >= 0 and ni < N and nj >= 0 and nj < N then
				local nk = nj * N + ni + 1
				if not alcancada[nk] and not bloq[nk] then
					local nt = topoCel[nk]
					if nt ~= SEM_CHAO and abs(nt - th) <= DEGRAU and not ehAgua(centroCel(ni), centroCel(nj)) then
						alcancada[nk] = true
						cauda += 1
						fila[cauda] = nk
					end
				end
			end
		end
	end

	local function alcancavel(pos): boolean
		local ci, cj = celula(pos.X, pos.Z)
		for dj = -1, 1 do
			for di = -1, 1 do
				local i, j = ci + di, cj + dj
				if i >= 0 and i < N and j >= 0 and j < N and alcancada[j * N + i + 1] then
					return true
				end
			end
		end
		return false
	end

	local naoAlcancados = { Spawn = 0, Loot = 0, Monstro = 0 }
	for nome, lista in { Spawn = spawns, Loot = loots, Monstro = monstros } do
		for _, pos in lista do
			if not alcancavel(pos) then
				naoAlcancados[nome] += 1
				falha(
					"ALCANCE",
					string.format(
						"%s em (%.0f, %.0f) não é alcançável a pé a partir do primeiro spawn",
						nome,
						pos.X,
						pos.Z
					)
				)
			end
		end
	end

	-- Entrada de cada construção alcançável (o ponto da porta)
	for _, b in predios do
		local px, pz = b.modelo:GetAttribute("PortaX"), b.modelo:GetAttribute("PortaZ")
		if type(px) == "number" and type(pz) == "number" then
			-- porta funda dentro da pegada (cobertura de bombas, escadaria): a pegada inteira é obstáculo na grade; o
			-- interior é checado a partir da porta de qualquer jeito
			local c = b.c
			local fundo = min(px - c.x0, c.x1 - px, pz - c.z0, c.z1 - pz)
			local ok = fundo > 8
			for dx = -6, 6, 3 do
				for dz = -6, 6, 3 do
					if alcancavel({ X = px + dx, Z = pz + dz }) then
						ok = true
					end
				end
			end
			if not ok then
				falha(
					"PORTA",
					string.format("a porta de %s (%.0f, %.0f) não é alcançável por fora", b.modelo.Name, px, pz)
				)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Interiores: grade 3D por construção. Estado = (célula, superfície). Superfície = topo de peça com vão livre ≥ 5,5
-- acima. Vizinhas se ligam se a diferença de altura ≤ 1,3 (degrau). Parte da porta (para dentro) e confere cada loot.
-- ---------------------------------------------------------------------------------------------------------------
local interioresChecados, lootsInternosOk = 0, 0
local function checarInterior(b)
	local m = b.modelo
	local c = b.c
	local px, pz, base = m:GetAttribute("PortaX"), m:GetAttribute("PortaZ"), m:GetAttribute("BaseY")
	if type(px) ~= "number" or type(pz) ~= "number" or type(base) ~= "number" then
		aviso(
			"INTERIOR",
			m.Name .. ": sem PortaX/PortaZ (info.portaria no retorno do construtor); interior não checado"
		)
		return
	end
	local x0, z0 = c.x0 - 4, c.z0 - 4
	local W = ceil((c.x1 + 4 - x0) / CELULA_INT)
	local H = ceil((c.z1 + 4 - z0) / CELULA_INT)
	local celulas = table.create(W * H) -- índice (j*W+i+1) → lista de intervalos { base, topo }

	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Name ~= "Pegada" then
			local cc = caixa(d)
			local ia, ib = max(0, floor((cc.x0 - x0) / CELULA_INT)), min(W - 1, floor((cc.x1 - x0) / CELULA_INT))
			local ja, jb = max(0, floor((cc.z0 - z0) / CELULA_INT)), min(H - 1, floor((cc.z1 - z0) / CELULA_INT))
			for j = ja, jb do
				for i = ia, ib do
					local cx, cz = x0 + (i + 0.5) * CELULA_INT, z0 + (j + 0.5) * CELULA_INT
					-- o centro precisa estar dentro (±1) da peça: reduz bloqueio falso por AABB de peça girada
					local topo, baixo = faceEm(d, cx, cz)
					if topo == nil then
						-- peça de lado ou fora do retângulo girado: se a caixa alinhada cobre o centro, use a caixa
						if
							cx >= cc.x0
							and cx <= cc.x1
							and cz >= cc.z0
							and cz <= cc.z1
							and abs(d.CFrame.UpVector.Y) < 0.5
						then
							topo, baixo = cc.topo, cc.base
						end
					end
					if topo then
						local k = j * W + i + 1
						local l = celulas[k]
						if not l then
							l = {}
							celulas[k] = l
						end
						table.insert(l, { baixo, topo })
					end
				end
			end
		end
	end

	-- Superfícies por célula: intervalos fundidos; topo é superfície se o vão até o próximo ≥ ALTURA_JOGADOR
	local sup = {} -- k → lista de topos
	for k, l in celulas do
		table.sort(l, function(a, bb)
			return a[1] < bb[1]
		end)
		local fundidos = {}
		for _, iv in l do
			local ult = fundidos[#fundidos]
			if ult and iv[1] <= ult[2] + 0.05 then
				ult[2] = max(ult[2], iv[2])
			else
				table.insert(fundidos, { iv[1], iv[2] })
			end
		end
		local s = {}
		for idx, iv in fundidos do
			local prox = fundidos[idx + 1]
			if not prox or prox[1] - iv[2] >= ALTURA_JOGADOR then
				table.insert(s, iv[2])
			end
		end
		sup[k] = s
	end

	-- Início: um passo para dentro da porta, na superfície mais próxima do nível da base
	local cx, cz = (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2
	local dx, dz = cx - px, cz - pz
	local len = sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local inicio = nil
	for passo = 2, 6, 1 do
		local sx, sz = px + dx * passo, pz + dz * passo
		local i, j = floor((sx - x0) / CELULA_INT), floor((sz - z0) / CELULA_INT)
		if i >= 0 and i < W and j >= 0 and j < H then
			local s = sup[j * W + i + 1]
			if s then
				for idx, t in s do
					if t >= base - 1.2 and t <= base + 3.2 then -- porta pode ficar num soco/degrau de entrada
						inicio = { i, j, idx }
						break
					end
				end
			end
		end
		if inicio then
			break
		end
	end
	if not inicio then
		falha(
			"INTERIOR",
			m.Name .. ": nada pisável logo depois da porta (portaria em " .. string.format("%.0f, %.0f", px, pz) .. ")"
		)
		return
	end

	local visitado = {} -- chave = (k*64 + idx)
	local fila = { inicio }
	visitado[(inicio[2] * W + inicio[1] + 1) * 64 + inicio[3]] = true
	local cab = 1
	local nVisitados = 0
	while cab <= #fila do
		local e = fila[cab]
		cab += 1
		nVisitados += 1
		local i, j, idx = e[1], e[2], e[3]
		local t = sup[j * W + i + 1][idx]
		for d = 1, 4 do
			local ni, nj = i, j
			if d == 1 then
				ni -= 1
			elseif d == 2 then
				ni += 1
			elseif d == 3 then
				nj -= 1
			else
				nj += 1
			end
			if ni >= 0 and ni < W and nj >= 0 and nj < H then
				local nk = nj * W + ni + 1
				local s = sup[nk]
				if s then
					for nidx, nt in s do
						if abs(nt - t) <= DEGRAU_INTERIOR then
							local chave = nk * 64 + nidx
							if not visitado[chave] then
								visitado[chave] = true
								table.insert(fila, { ni, nj, nidx })
							end
						end
					end
				end
			end
		end
	end

	if process.args[2] == m.Name then
		for k = 0, 3 do
			local yAlvo = base + 12 * k + 0.4
			print(
				string.format(
					"-- %s andar %d (y≈%.1f): o = alcançado, . = piso não alcançado, ' ' = sem piso; L = loot",
					m.Name,
					k,
					yAlvo
				)
			)
			for j = 0, H - 1 do
				local linha = {}
				for i = 0, W - 1 do
					local ch = " "
					local s = sup[j * W + i + 1]
					if s then
						for idx, t in s do
							if abs(t - yAlvo) <= 1.4 then
								ch = if visitado[(j * W + i + 1) * 64 + idx] then "o" else "."
							end
						end
					end
					for _, l in lootsInternos do
						if l.predio == b and abs(l.pos.Y - 0.5 - yAlvo) <= 1.4 then
							if floor((l.pos.X - x0) / CELULA_INT) == i and floor((l.pos.Z - z0) / CELULA_INT) == j then
								ch = "L"
							end
						end
					end
					table.insert(linha, ch)
				end
				print(table.concat(linha))
			end
		end
	end

	-- Cada loot interno: existe superfície visitada em ±1 célula cujo topo ≈ y − 0,5
	for _, l in lootsInternos do
		if l.predio == b then
			local ok = false
			local nenhumPiso = true
			local ci, cj = floor((l.pos.X - x0) / CELULA_INT), floor((l.pos.Z - z0) / CELULA_INT)
			for dj = -1, 1 do
				for di = -1, 1 do
					local i, j = ci + di, cj + dj
					if i >= 0 and i < W and j >= 0 and j < H then
						local s = sup[j * W + i + 1]
						if s then
							for idx, t in s do
								if abs(t - (l.pos.Y - 0.5)) <= 0.8 then
									nenhumPiso = false
									if visitado[(j * W + i + 1) * 64 + idx] then
										ok = true
									end
								end
							end
						end
					end
				end
			end
			if ok then
				lootsInternosOk += 1
			elseif nenhumPiso then
				falha(
					"LOOT",
					string.format(
						"Loot em %s (%.0f, %.1f, %.0f): sem piso livre sob o ponto",
						m.Name,
						l.pos.X,
						l.pos.Y,
						l.pos.Z
					)
				)
			else
				falha(
					"LOOT",
					string.format(
						"Loot em %s (%.0f, %.1f, %.0f) não é alcançável da porta (móvel/parede/escada?)",
						m.Name,
						l.pos.X,
						l.pos.Y,
						l.pos.Z
					)
				)
			end
		end
	end
	interioresChecados += 1
end
for _, b in predios do
	if not b.modelo:GetAttribute("Placeholder") then
		checarInterior(b)
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Árvores: nem na rua nem em construção
-- ---------------------------------------------------------------------------------------------------------------
for _, t in troncos do
	local cx, cz = (t.x0 + t.x1) / 2, (t.z0 + t.z1) / 2
	for _, r in ruas do
		if cx >= r.x0 and cx <= r.x1 and cz >= r.z0 and cz <= r.z1 then
			falha("ARVORE", string.format("tronco em (%.0f, %.0f) em cima de rua/calçada/ponte", cx, cz))
			break
		end
	end
	for _, b in predios do
		local c = b.c
		if cx >= c.x0 - 1 and cx <= c.x1 + 1 and cz >= c.z0 - 1 and cz <= c.z1 + 1 then
			falha("ARVORE", string.format("tronco em (%.0f, %.0f) dentro de %s", cx, cz, b.modelo.Name))
			break
		end
	end
	if plano.profundidadeRio(cx, cz) > 1 then
		falha("ARVORE", string.format("tronco em (%.0f, %.0f) dentro do rio", cx, cz))
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Borda, bordas, zonas, rios
-- ---------------------------------------------------------------------------------------------------------------
for _, nome in { "Chao", "Ruas", "Construcoes", "Vegetacao", "Zonas", "Pontos", "Rios", "Props" } do
	for _, p in pasta[nome]:GetDescendants() do
		if p:IsA("BasePart") then
			local c = caixa(p)
			-- lajes do relevo na borda sobrepõem alguns studs: ficam sob o muro de Bordas (4 de espessura)
			local folga = if nome == "Chao" then 4 elseif nome == "Rios" then 30 else 0.01
			if c.x0 < -meio - folga or c.x1 > meio + folga or c.z0 < -meio - folga or c.z1 > meio + folga then
				falha("BORDA", p:GetFullName() .. " passa da borda do mapa")
			end
		end
	end
end
for _, b in pasta.Bordas:GetChildren() do
	if not b:IsA("BasePart") or b.Transparency ~= 1 or not b.CanCollide or b.CanQuery then
		falha("BORDA", b.Name .. ": precisa Transparency 1, CanCollide true, CanQuery false")
	end
end
for _, z in pasta.Zonas:GetChildren() do
	if not z:IsA("BasePart") or z.Transparency ~= 1 or z.CanCollide or z.CanQuery then
		falha("ZONA", z.Name .. ": precisa Transparency 1, CanCollide false, CanQuery false")
	end
	if not ZONAS[z:GetAttribute("Zona") :: any] then
		falha("ZONA", z.Name .. ": atributo Zona inválido")
	end
end
local nAgua = 0
for _, a in pasta.Rios:GetChildren() do
	if a:IsA("BasePart") then
		nAgua += 1
		if a.CanCollide or a.CanQuery or a.Transparency ~= 1 then
			falha("RIO", a:GetFullName() .. ": marcador de água precisa Transparency 1, CanCollide e CanQuery false")
		end
	end
end
if #Mundo.rios > 0 and nAgua == 0 then
	aviso(
		"RIO",
		"não há marcadores de água em Mapa.Rios (módulo relevo ainda não gera? Rios.luau não terá o que encher)"
	)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Relatório
-- ---------------------------------------------------------------------------------------------------------------
local contagem = {}
for _, nome in PASTAS do
	table.insert(contagem, string.format("%s=%d", nome, porPasta[nome]))
end
print(string.format("[checar_mapa] %d peças (%s)", total, table.concat(contagem, ", ")))
print(
	string.format(
		"[checar_mapa] construções %d | Spawn %d, Loot %d (+%d internos), Monstro %d | células alcançadas %d de %d | degrau máx %.1f",
		#predios,
		#spawns,
		#loots,
		#lootsInternos,
		#monstros,
		nAlcancadas,
		N * N,
		DEGRAU
	)
)
print(
	string.format(
		"[checar_mapa] interiores checados %d | loot interno alcançável %d de %d | props que bloqueiam %d | águas %d",
		interioresChecados,
		lootsInternosOk,
		#lootsInternos,
		obstaculosProps,
		nAgua
	)
)
for _, a in avisos do
	print("AVISO " .. a)
end
if #falhas > 0 then
	for _, f in falhas do
		print("FALHA " .. f)
	end
	print(string.format("[checar_mapa] %d falha(s)", #falhas))
	process.exit(1)
end
print("[checar_mapa] tudo verde")
