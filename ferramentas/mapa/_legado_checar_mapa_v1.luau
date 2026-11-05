-- Checa mapa/Mapa.rbxm (saída da ferramentas/gerar_mapa.luau) contra o contrato de docs/arquitetura.md §6.
-- Uso (da raiz do projeto): lune run ferramentas/checar_mapa.luau   → código de saída ≠ 0 se qualquer regra falhar.
-- Adaptado de .claude/skills/mapa-roblox/scripts/checar_mapa.luau para rodar fora do Studio: o grafo de plataformas
-- vira uma grade 2D de células livres, porque o mapa é plano e feito de lajes/blocos. Dono: P1.
--
-- Regras: estrutura de pastas | peça solta (todas Anchored) | peça > pecaMaxima | orçamento de peças | construções
-- (atributos, sem se atravessarem) | pontos (propriedades, atributos, no chão, spawn longe de construção) | alcance por
-- grade (spawns, loot e monstros alcançáveis a partir de um spawn) | árvore em rua/construção | nada fora da borda.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Mundo = require("../src/shared/Config/Mundo")
local Monstros = require("../src/shared/Config/Monstros")
local Itens = require("../src/shared/Config/Itens")
local Movimento = require("../src/shared/Config/Movimento")

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs

-- ---------------------------------------------------------------------------------------------------------------
-- Números (a fonte de cada um está no comentário)
-- ---------------------------------------------------------------------------------------------------------------
local LIMITE_PECAS = 15000 -- docs/arquitetura.md §P1
local CELULA = 4 -- studs por célula da grade de alcance
local RAIO = 1.5 -- meia largura do personagem (folga em volta de obstáculos)
local MARGEM = 0.9 -- usa 90% do pulo (skill mapa-roblox)
local DEGRAU = Movimento.alturaPulo * MARGEM -- maior diferença de altura entre células vizinhas
local SPAWN_LONGE = 8 -- studs mínimos entre spawn e qualquer construção
local TOL_Y = 0.05 -- tolerância do Y dos pontos (topo + 0.5)
local PASTAS = { "Chao", "Ruas", "Construcoes", "Vegetacao", "Bordas", "Zonas", "Pontos" }
local TIPOS = { casa = true, loja = true, predio = true, posto = true, galpao = true, guarda = true }
local ZONAS = { cidade = true, vila = true, floresta = true, fabrica = true, planicie = true, guarda = true }

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
local okLer, conteudo = pcall(fs.readFile, "mapa/Mapa.rbxm")
if not okLer then
	print("FALHA: mapa/Mapa.rbxm não existe (rode ferramentas/gerar_mapa.luau da raiz do projeto)")
	process.exit(1)
end
local raizes = roblox.deserializeModel(conteudo)
local mapa = raizes[1]
if not mapa or mapa.Name ~= "Mapa" then
	print("FALHA: a raiz do .rbxm precisa se chamar Mapa")
	process.exit(1)
end

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

type Caixa = { x0: number, x1: number, z0: number, z1: number, topo: number, base: number }
local function caixa(p): Caixa
	local pos, s = p.CFrame.Position, p.Size
	return {
		x0 = pos.X - s.X / 2,
		x1 = pos.X + s.X / 2,
		z0 = pos.Z - s.Z / 2,
		z1 = pos.Z + s.Z / 2,
		topo = pos.Y + s.Y / 2,
		base = pos.Y - s.Y / 2,
	}
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
end
if total > LIMITE_PECAS then
	falha("ORCAMENTO", string.format("%d peças (limite %d)", total, LIMITE_PECAS))
end
-- peças fora das pastas do contrato
for _, f in mapa:GetChildren() do
	if not pasta[f.Name] or pasta[f.Name] ~= f then
		falha("ESTRUTURA", "filho inesperado em Mapa: " .. f.Name)
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Construções
-- ---------------------------------------------------------------------------------------------------------------
local predios = {} -- { modelo, corpo = Caixa, total = Caixa (corpo + telhado) }
local obstaculos: { Caixa } = {} -- tudo que bloqueia o andar (colide e passa da altura do pulo)
for _, m in pasta.Construcoes:GetChildren() do
	if not m:IsA("Model") then
		falha("CONSTRUCAO", m:GetFullName() .. " não é Model")
		continue
	end
	local tipo = m:GetAttribute("Tipo")
	if not (type(tipo) == "string" and TIPOS[tipo]) then
		falha("CONSTRUCAO", m.Name .. ": atributo Tipo inválido (" .. tostring(tipo) .. ")")
	end
	if not ZONAS[m:GetAttribute("Zona") :: any] then
		falha("CONSTRUCAO", m.Name .. ": atributo Zona inválido (" .. tostring(m:GetAttribute("Zona")) .. ")")
	end
	local andares = m:GetAttribute("Andares")
	if type(andares) ~= "number" or andares < 1 then
		falha("CONSTRUCAO", m.Name .. ": atributo Andares inválido")
	end
	if m:GetAttribute("Interior") ~= false then
		falha("CONSTRUCAO", m.Name .. ": atributo Interior precisa ser false")
	end
	local corpo = m:FindFirstChild("Corpo")
	if not corpo or not corpo:IsA("BasePart") or not corpo.CanCollide then
		falha("CONSTRUCAO", m.Name .. ": sem Corpo sólido")
		continue
	end
	local telhado = m:FindFirstChild("Telhado")
	local cc = caixa(corpo)
	local tot = { x0 = cc.x0, x1 = cc.x1, z0 = cc.z0, z1 = cc.z1, topo = cc.topo, base = cc.base }
	if telhado and telhado:IsA("BasePart") then
		local ct = caixa(telhado)
		tot.x0, tot.x1 = min(tot.x0, ct.x0), max(tot.x1, ct.x1)
		tot.z0, tot.z1 = min(tot.z0, ct.z0), max(tot.z1, ct.z1)
		tot.topo = max(tot.topo, ct.topo)
	end
	table.insert(predios, { modelo = m, corpo = cc, total = tot })
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			table.insert(obstaculos, caixa(p))
		end
	end
end
for i = 1, #predios do
	for j = i + 1, #predios do
		local a, b = predios[i].total, predios[j].total
		if a.x0 < b.x1 and a.x1 > b.x0 and a.z0 < b.z1 and a.z1 > b.z0 then
			falha("ENFIADA", predios[i].modelo.Name .. " e " .. predios[j].modelo.Name .. " se atravessam")
		end
	end
end

-- Troncos (colidem) e manchas (chão)
local troncos: { Caixa } = {}
local chaoPecas: { Caixa } = {}
for _, p in pasta.Vegetacao:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		if p.Name == "Tronco" then
			local c = caixa(p)
			table.insert(troncos, c)
			table.insert(obstaculos, c)
		elseif p.Name == "Mancha" then
			table.insert(chaoPecas, caixa(p))
		else
			falha("VEGETACAO", p:GetFullName() .. " colide mas não é Tronco nem Mancha")
		end
	end
end
local ruas: { Caixa } = {}
for _, nome in { "Chao", "Ruas" } do
	for _, p in pasta[nome]:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide then
			local c = caixa(p)
			table.insert(chaoPecas, c)
			if nome == "Ruas" then
				table.insert(ruas, c)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Grade de alcance
-- ---------------------------------------------------------------------------------------------------------------
local meio = Mundo.tamanho / 2
local N = floor(Mundo.tamanho / CELULA)
local SEM_CHAO = -1e9
local topoCel = table.create(N * N, SEM_CHAO)
local bloq = table.create(N * N, false)

local function faixaCel(v0: number, v1: number): (number, number)
	-- índices de células cujo centro cai em [v0, v1]
	local i0 = ceil((v0 + meio - CELULA / 2) / CELULA)
	local i1 = floor((v1 + meio - CELULA / 2) / CELULA)
	return max(0, i0), min(N - 1, i1)
end

for _, c in chaoPecas do
	local i0, i1 = faixaCel(c.x0, c.x1)
	local j0, j1 = faixaCel(c.z0, c.z1)
	for j = j0, j1 do
		local fila = j * N + 1
		for i = i0, i1 do
			local k = fila + i
			if c.topo > topoCel[k] then
				topoCel[k] = c.topo
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

-- Topo exato do chão no ponto (maior topo entre as peças pisáveis que o cobrem)
local function topoExato(x: number, z: number): number?
	local melhor = nil
	for _, c in chaoPecas do
		if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 and (melhor == nil or c.topo > melhor) then
			melhor = c.topo
		end
	end
	return melhor
end

local function dentroDeObstaculo(x: number, z: number): boolean
	for _, c in obstaculos do
		if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Pontos
-- ---------------------------------------------------------------------------------------------------------------
local spawns, loots, monstros = {}, {}, {}
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
	local topo = topoExato(pos.X, pos.Z)
	if not topo then
		falha("PONTO", string.format("%s em (%.0f, %.0f) está fora do chão", nome, pos.X, pos.Z))
		continue
	end
	if abs(pos.Y - (topo + 0.5)) > TOL_Y then
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
	local zona = p:GetAttribute("Zona")
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
		table.insert(loots, pos)
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
			falha("MONSTRO", string.format("Monstro em (%.0f, %.0f) está dentro de construção/tronco", pos.X, pos.Z))
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
if #predios > 0 and #loots < #predios * Mundo.pontosLootPorConstrucao then
	falha(
		"LOOT",
		string.format(
			"%d pontos de loot para %d construções (esperado %d por construção)",
			#loots,
			#predios,
			Mundo.pontosLootPorConstrucao
		)
	)
end

-- Spawn: longe de construção
for _, sp in spawns do
	for _, b in predios do
		local c = b.total
		local dx = max(0, c.x0 - sp.X, sp.X - c.x1)
		local dz = max(0, c.z0 - sp.Z, sp.Z - c.z1)
		local d = math.sqrt(dx * dx + dz * dz)
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
-- Alcance: BFS por células livres a partir do primeiro spawn
-- ---------------------------------------------------------------------------------------------------------------
local alcancada = table.create(N * N, false)
local nAlcancadas = 0
if #spawns == 0 then
	falha("SPAWN", "nenhum ponto Spawn no mapa")
else
	local fila = {}
	local cabeca, cauda = 1, 0
	for _, sp in spawns do
		local i, j = celula(sp.X, sp.Z)
		local k = j * N + i + 1
		if bloq[k] or topoCel[k] == SEM_CHAO then
			falha("SPAWN", string.format("Spawn em (%.0f, %.0f) cai numa célula bloqueada", sp.X, sp.Z))
		elseif not alcancada[k] then
			alcancada[k] = true
			cauda += 1
			fila[cauda] = k
		end
		-- só o primeiro spawn semeia; os outros precisam ser alcançados por ele
		break
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
					if nt ~= SEM_CHAO and abs(nt - th) <= DEGRAU then
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
						"%s em (%.0f, %.0f) não é alcançável a partir do primeiro spawn",
						nome,
						pos.X,
						pos.Z
					)
				)
			end
		end
	end
end

-- Árvores: nem na rua nem em construção
for _, t in troncos do
	local cx, cz = (t.x0 + t.x1) / 2, (t.z0 + t.z1) / 2
	for _, r in ruas do
		if cx >= r.x0 and cx <= r.x1 and cz >= r.z0 and cz <= r.z1 then
			falha("ARVORE", string.format("tronco em (%.0f, %.0f) em cima de rua/calçada", cx, cz))
			break
		end
	end
	for _, b in predios do
		local c = b.total
		if cx >= c.x0 - 1 and cx <= c.x1 + 1 and cz >= c.z0 - 1 and cz <= c.z1 + 1 then
			falha("ARVORE", string.format("tronco em (%.0f, %.0f) dentro de %s", cx, cz, b.modelo.Name))
			break
		end
	end
end

-- Nada fora da borda do mapa (exceto as Bordas)
for _, nome in { "Chao", "Ruas", "Construcoes", "Vegetacao", "Zonas", "Pontos" } do
	for _, p in pasta[nome]:GetDescendants() do
		if p:IsA("BasePart") then
			local c = caixa(p)
			if c.x0 < -meio - 0.01 or c.x1 > meio + 0.01 or c.z0 < -meio - 0.01 or c.z1 > meio + 0.01 then
				falha("BORDA", p:GetFullName() .. " passa da borda do mapa")
			end
		end
	end
end

-- Bordas: invisíveis e sem CanQuery (não param tiro nem raycast de som)
for _, b in pasta.Bordas:GetChildren() do
	if not b:IsA("BasePart") or b.Transparency ~= 1 or not b.CanCollide or b.CanQuery then
		falha("BORDA", b.Name .. ": precisa Transparency 1, CanCollide true, CanQuery false")
	end
end

-- Zonas: invisíveis e sem CanQuery (não podem parar raycast)
for _, z in pasta.Zonas:GetChildren() do
	if not z:IsA("BasePart") or z.Transparency ~= 1 or z.CanCollide or z.CanQuery then
		falha("ZONA", z.Name .. ": precisa Transparency 1, CanCollide false, CanQuery false")
	end
	if not ZONAS[z:GetAttribute("Zona") :: any] then
		falha("ZONA", z.Name .. ": atributo Zona inválido")
	end
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
		"[checar_mapa] construções %d | Spawn %d, Loot %d, Monstro %d | células alcançadas %d de %d | degrau máx %.1f studs (pulo × %.1f)",
		#predios,
		#spawns,
		#loots,
		#monstros,
		nAlcancadas,
		N * N,
		DEGRAU,
		MARGEM
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
