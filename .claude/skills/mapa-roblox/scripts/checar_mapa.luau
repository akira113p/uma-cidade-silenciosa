-- checar_mapa.luau
-- Rodar pelo MCP do Studio: execute_luau (datamodel Edit) com o conteúdo deste arquivo.
-- Lê os números de movimento do próprio jogo, monta o grafo de plataformas e devolve um JSON:
--   numeros   = cada número usado, com a fonte
--   suposicoes = tudo que é chute (aparece em todo relatório)
--   falhas / avisos / manual
-- Ajustes por tag (CollectionService): "Decoracao" (ignorar), "ForaDeAlcance" (não pode ser alcançável),
-- "SemSaidaOk" (pode ser beco sem saída), "Objetivo" (precisa ser alcançável).

local HttpService = game:GetService("HttpService")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PASTA_MAPA = "Mapa" -- workspace.Mapa; se não existir, usa o workspace inteiro
local MARGEM = 0.9 -- usa 90% do pulo e do alcance teóricos
local PE_MIN, PE_MAX = 1, 2 -- pegada do personagem em studs (lado menor, lado maior)
local LIMITE_PECAS = 3000

local rel = { numeros = {}, suposicoes = {}, falhas = {}, avisos = {}, manual = {}, resumo = {} }

local function numero(nome, valor, fonte)
	rel.numeros[nome] = { valor = valor, fonte = fonte }
	return valor
end
local function falha(regra, msg)
	table.insert(rel.falhas, regra .. ": " .. msg)
end
local function aviso(regra, msg)
	table.insert(rel.avisos, regra .. ": " .. msg)
end

-- Números de movimento: Config do jogo > StarterPlayer > workspace
local config = nil
local shared = ReplicatedStorage:FindFirstChild("Shared")
local pastaConfig = shared and shared:FindFirstChild("Config")
local modMov = pastaConfig and pastaConfig:FindFirstChild("Movimento")
if modMov and modMov:IsA("ModuleScript") then
	local ok, r = pcall(require, modMov)
	if ok and type(r) == "table" then
		config = r
	end
end

local g = numero("gravidade", workspace.Gravity, "workspace.Gravity")
local velocidade, alturaPulo
if config and config.velocidade then
	velocidade = numero("velocidade", config.velocidade, "Shared.Config.Movimento.velocidade")
else
	velocidade = numero("velocidade", StarterPlayer.CharacterWalkSpeed, "StarterPlayer.CharacterWalkSpeed")
end
if config and config.alturaPulo then
	alturaPulo = numero("alturaPulo", config.alturaPulo, "Shared.Config.Movimento.alturaPulo")
elseif StarterPlayer.CharacterUseJumpPower then
	local jp = StarterPlayer.CharacterJumpPower
	alturaPulo = numero("alturaPulo", jp * jp / (2 * g), "StarterPlayer.CharacterJumpPower^2 / (2*gravidade)")
else
	alturaPulo = numero("alturaPulo", StarterPlayer.CharacterJumpHeight, "StarterPlayer.CharacterJumpHeight")
end
local inclinacaoMax = numero("inclinacaoMax", StarterPlayer.CharacterMaxSlopeAngle, "StarterPlayer.CharacterMaxSlopeAngle")
local quedaMax = config and config.quedaMax and numero("quedaMax", config.quedaMax, "Shared.Config.Movimento.quedaMax") or nil

table.insert(rel.suposicoes, string.format("margem de segurança %.0f%% sobre pulo e alcance", MARGEM * 100))
table.insert(rel.suposicoes, string.format("pegada do personagem %dx%d studs", PE_MIN, PE_MAX))
table.insert(rel.suposicoes, "cada peça vira a caixa alinhada aos eixos que a contém (MeshPart/cunha = caixa)")
table.insert(rel.suposicoes, "sem teto: não verifica se a cabeça bate em algo no meio do pulo")
table.insert(rel.suposicoes, "movimento só por pulo/queda; escada, TrussPart, plataforma móvel e teleporte não entram no grafo")
if not quedaMax then
	table.insert(rel.suposicoes, "sem Config.Movimento.quedaMax: quedas são só listadas, não reprovadas")
end

-- Peças
local raiz = workspace:FindFirstChild(PASTA_MAPA) or workspace
if raiz == workspace then
	aviso("PASTA", "workspace." .. PASTA_MAPA .. " não existe; checando o workspace inteiro")
end

local function dentroDePersonagem(p)
	local m = p:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then
			return true
		end
		m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function caixa(p)
	local cf, s = p.CFrame, p.Size / 2
	local mnx, mny, mnz = math.huge, math.huge, math.huge
	local mxx, mxy, mxz = -math.huge, -math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = cf:PointToWorldSpace(Vector3.new(sx * s.X, sy * s.Y, sz * s.Z))
				mnx, mny, mnz = math.min(mnx, w.X), math.min(mny, w.Y), math.min(mnz, w.Z)
				mxx, mxy, mxz = math.max(mxx, w.X), math.max(mxy, w.Y), math.max(mxz, w.Z)
			end
		end
	end
	return Vector3.new(mnx, mny, mnz), Vector3.new(mxx, mxy, mxz)
end

local pecas = {}
for _, d in raiz:GetDescendants() do
	if d:IsA("BasePart") and not dentroDePersonagem(d) and not CollectionService:HasTag(d, "Decoracao") then
		table.insert(pecas, d)
	end
end
rel.resumo.pecas = #pecas
if #pecas > LIMITE_PECAS then
	aviso("LIMITE", string.format("%d peças; checando só as %d primeiras", #pecas, LIMITE_PECAS))
end

-- 1. Peças soltas que vão cair no play
for i, p in pecas do
	if i > LIMITE_PECAS then
		break
	end
	if not p.Anchored and #p:GetJoints() == 0 then
		falha("SOLTA", p:GetFullName() .. " não está ancorada nem presa a nada: cai ao dar play")
	end
end

-- 2. Nós do grafo: topos pisáveis
local nos = {}
for i, p in pecas do
	if i > LIMITE_PECAS then
		break
	end
	if p.CanCollide and p.Transparency < 1 or (p.CanCollide and p:IsA("SpawnLocation")) then
		local mn, mx = caixa(p)
		local up = math.max(math.abs(p.CFrame.RightVector.Y), math.abs(p.CFrame.UpVector.Y), math.abs(p.CFrame.LookVector.Y))
		local inclinacao = math.deg(math.acos(math.clamp(up, -1, 1)))
		local lx, lz = mx.X - mn.X, mx.Z - mn.Z
		local pisavel = inclinacao <= inclinacaoMax and math.min(lx, lz) >= PE_MIN and math.max(lx, lz) >= PE_MAX
		if pisavel then
			table.insert(nos, { peca = p, mn = mn, mx = mx, topo = mx.Y, spawn = p:IsA("SpawnLocation") })
		elseif p:IsA("SpawnLocation") then
			falha("SPAWN", p:GetFullName() .. " não é pisável (pequena ou inclinada demais)")
		end
	end
end
rel.resumo.plataformas = #nos

-- 3. Arestas: dá para ir de A até B?
local v0 = math.sqrt(2 * g * alturaPulo * MARGEM)
local alturaUtil = alturaPulo * MARGEM
local function distanciaXZ(a, b)
	local dx = math.max(0, b.mn.X - a.mx.X, a.mn.X - b.mx.X)
	local dz = math.max(0, b.mn.Z - a.mx.Z, a.mn.Z - b.mx.Z)
	return math.sqrt(dx * dx + dz * dz)
end
local function alcanca(a, b)
	local subida = b.topo - a.topo
	if subida > alturaUtil then
		return false
	end
	local vao = distanciaXZ(a, b)
	if vao <= 0.05 then
		return true
	end
	local disc = v0 * v0 - 2 * g * subida
	if disc < 0 then
		return false
	end
	local t = (v0 + math.sqrt(disc)) / g
	return vao <= velocidade * t * MARGEM
end

local saida, entrada = {}, {}
for i = 1, #nos do
	saida[i], entrada[i] = {}, {}
end
local maiorQueda = 0
for i, a in nos do
	for j, b in nos do
		if i ~= j and alcanca(a, b) then
			table.insert(saida[i], j)
			table.insert(entrada[j], i)
			local queda = a.topo - b.topo
			if queda > maiorQueda then
				maiorQueda = queda
			end
			if quedaMax and queda > quedaMax then
				aviso("QUEDA", string.format("%s -> %s cai %.1f studs (> quedaMax %.1f)", a.peca:GetFullName(), b.peca:GetFullName(), queda, quedaMax))
			end
		end
	end
end
rel.resumo.maiorQueda = maiorQueda

local function bfs(inicio, vizinhos)
	local visto, fila = {}, {}
	for _, i in inicio do
		visto[i] = true
		table.insert(fila, i)
	end
	local k = 1
	while k <= #fila do
		for _, j in vizinhos[fila[k]] do
			if not visto[j] then
				visto[j] = true
				table.insert(fila, j)
			end
		end
		k += 1
	end
	return visto
end

local spawns = {}
for i, n in nos do
	if n.spawn then
		table.insert(spawns, i)
	end
end
if #spawns == 0 then
	falha("SPAWN", "nenhuma SpawnLocation pisável no mapa")
else
	local alcancavel = bfs(spawns, saida)
	local voltaAoSpawn = bfs(spawns, entrada)
	local nAlc = 0
	for i, n in nos do
		local nome = n.peca:GetFullName()
		if alcancavel[i] then
			nAlc += 1
			if CollectionService:HasTag(n.peca, "ForaDeAlcance") then
				falha("ALCANCE_INDEVIDO", nome .. " tem a tag ForaDeAlcance mas dá para chegar")
			end
			if not voltaAoSpawn[i] and not CollectionService:HasTag(n.peca, "SemSaidaOk") then
				falha("SEM_SAIDA", nome .. ": dá para cair/chegar ali e não dá para voltar")
			end
		else
			if CollectionService:HasTag(n.peca, "Objetivo") then
				falha("INALCANCAVEL", nome .. " é Objetivo e ninguém chega lá")
			elseif n.topo > 0 and not CollectionService:HasTag(n.peca, "ForaDeAlcance") then
				aviso("INALCANCAVEL", string.format("%s (topo %.1f) não é alcançável a partir do spawn", nome, n.topo))
			end
		end
	end
	rel.resumo.alcancaveis = nAlc
end

-- 4. Peças enfiadas umas nas outras
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { raiz }
local vistos = {}
local nSobre = 0
for i, p in pecas do
	if i > LIMITE_PECAS or nSobre >= 50 then
		break
	end
	local amn, amx = caixa(p)
	for _, q in workspace:GetPartsInPart(p, params) do
		local np, nq = p:GetFullName(), q:GetFullName()
		local chave = np < nq and (np .. "|" .. nq) or (nq .. "|" .. np)
		if q ~= p and not vistos[chave] then
			vistos[chave] = true
			local bmn, bmx = caixa(q)
			local ox = math.min(amx.X, bmx.X) - math.max(amn.X, bmn.X)
			local oy = math.min(amx.Y, bmx.Y) - math.max(amn.Y, bmn.Y)
			local oz = math.min(amx.Z, bmx.Z) - math.max(amn.Z, bmn.Z)
			if ox > 0.1 and oy > 0.1 and oz > 0.1 then
				nSobre += 1
				aviso("ENFIADA", string.format("%s e %s se atravessam (%.1fx%.1fx%.1f)", p:GetFullName(), q:GetFullName(), ox, oy, oz))
			end
		end
	end
end

table.insert(rel.manual, "linhas de visão: screen_capture de cada área a partir do ponto de vista do jogador")
table.insert(rel.manual, "espaçamento de anéis/sequências de plataformas: conferir no screen_capture de cima")

print(string.format("[checar_mapa] %d falha(s), %d aviso(s)", #rel.falhas, #rel.avisos))
return HttpService:JSONEncode(rel)
