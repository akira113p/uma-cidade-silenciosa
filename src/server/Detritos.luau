-- Detritos: vidro, lata, garrafa, folhas, galho, entulho e tábua soltos pelo chão (docs/som.md §5.1). Quem pisa faz barulho no lugar do detrito.
-- Nascem em TEMPO DE EXECUÇÃO (como Portas e Loot), em workspace.Detritos: nada vai para Mapa.rbxm nem para Workspace.Mapa (regra 4 do CLAUDE.md).
-- Detecção sem Touched: grade espacial de 8 studs (a mesma ideia das Flores); Ruido.amostrar chama `aoPasso` a cada passo do jogador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Raizes = require(Shared:WaitForChild("Raizes"))
local Sons = require(script.Parent.Sons)
local Teste = require(script.Parent.Teste)

local Detritos = {}

local cfg = CfgSom.detritos
local ESPERA_MAPA = 30 -- s esperando workspace.Mapa aparecer
local ALTURA_PARTE = 0.02 -- studs: a peça fica um fio acima do chão (evita z-fighting)
local ALTURA_MAX_DIFERENCA = 3 -- studs: detrito de outro andar não é pisado
local ALTURA_CHUTE = { acima = 3, queda = 8 } -- raio que acha o chão no ponto para onde a lata/garrafa é chutada
local PRIORIDADE_ZONA = { "cidade", "vila", "fabrica" } -- depois: planície/guarda ("outros"), depois floresta
local ZONAS_OUTROS = { planicie = true, guarda = true }
local MAX_TESTE = 20

type Detrito = {
	id: number,
	tipo: string,
	pos: Vector3,
	modelo: Model,
	ultimo: { [Player]: number }, -- os.clock() do último acionamento por jogador (recarga)
	celula: string,
}
type Zona = { chave: string, cx: number, cz: number, sx: number, sz: number, topo: number, altura: number }
type Predio = { cf: CFrame, tam: Vector3, zona: string }

local rng = Random.new() -- efeitos em jogo (chance, chute); a colocação usa a semente fixa do Config
local detritos: { [number]: Detrito } = {}
local grade: { [string]: { [number]: Detrito } } = {}
local proximoId = 0
local pasta: Folder? = nil

-- tipos em ordem fixa (a iteração de tabela não é determinística: o sorteio com semente precisa ser)
local nomesTipos: { string } = {}
for nome in cfg.tipos do
	table.insert(nomesTipos, nome)
end
table.sort(nomesTipos)

local function chaveCelula(x: number, z: number): string
	return math.floor(x / cfg.celula) .. ":" .. math.floor(z / cfg.celula)
end

local function inserirNaGrade(d: Detrito)
	local c = chaveCelula(d.pos.X, d.pos.Z)
	local g = grade[c]
	if not g then
		g = {}
		grade[c] = g
	end
	g[d.id] = d
	d.celula = c
end

local function tirarDaGrade(d: Detrito)
	local g = grade[d.celula]
	if g then
		g[d.id] = nil
	end
end

-- Visual -----------------------------------------------------------------------------------------------------------------

local function pastaDetritos(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local existente = workspace:FindFirstChild("Detritos")
	if existente and existente:IsA("Folder") then
		pasta = existente
		return existente
	end
	local nova = Instance.new("Folder")
	nova.Name = "Detritos"
	nova.Parent = workspace
	pasta = nova
	return nova
end

local function variar(cor: { number }, r: Random): Color3
	local k = r:NextNumber(0.88, 1.08)
	return Color3.fromRGB(
		math.clamp(cor[1] * k, 0, 255),
		math.clamp(cor[2] * k, 0, 255),
		math.clamp(cor[3] * k, 0, 255)
	)
end

-- 1 a 3 peças soltas perto de `pos` (o chão), cores PS1 sem textura, sem colisão nem consulta.
local function montarVisual(tipo: string, pos: Vector3, r: Random): Model
	local def = cfg.tipos[tipo]
	local modelo = Instance.new("Model")
	modelo.Name = tipo
	local material = Enum.Material[def.material] or Enum.Material.SmoothPlastic
	local n = r:NextInteger(cfg.partes.min, cfg.partes.max)
	for i = 1, n do
		local escala = r:NextNumber(0.8, 1.2)
		local tam = Vector3.new(def.tamanho[1] * escala, def.tamanho[2], def.tamanho[3] * escala)
		local espalhar = if i == 1 then 0 else def.raio * 0.6
		local desvio = Vector3.new(r:NextNumber(-espalhar, espalhar), 0, r:NextNumber(-espalhar, espalhar))
		local parte = Instance.new("Part")
		parte.Name = "Peca"
		parte.Size = tam
		parte.Color = variar(def.cor, r)
		parte.Material = material
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanQuery = false
		parte.CanTouch = false
		parte.CastShadow = false
		parte.CFrame = CFrame.new(pos + desvio + Vector3.new(0, tam.Y / 2 + ALTURA_PARTE, 0))
			* CFrame.Angles(0, r:NextNumber(0, 2 * math.pi), 0)
		parte.Parent = modelo
	end
	return modelo
end

local function registrar(tipo: string, pos: Vector3, pai: Instance, r: Random): Detrito
	proximoId += 1
	local d: Detrito = {
		id = proximoId,
		tipo = tipo,
		pos = pos,
		modelo = montarVisual(tipo, pos, r),
		ultimo = setmetatable({}, { __mode = "k" }) :: any,
		celula = "",
	}
	d.modelo.Parent = pai
	detritos[d.id] = d
	inserirNaGrade(d)
	-- some junto com o modelo (galho quebrado, ZonaTeste apagada): sai da grade
	d.modelo.Destroying:Connect(function()
		tirarDaGrade(d)
		detritos[d.id] = nil
	end)
	return d
end

-- Evento de som -----------------------------------------------------------------------------------------------------------

local function emitir(tipo: string, nivel: number, posicao: Vector3, modo: string, fonte: Player?, somNome: string?)
	local def = cfg.tipos[tipo]
	local c = Som.compor({ { nome = tipo, nivel = nivel, perfil = def.perfil, chao = def.chao } })
	local ruido = require(script.Parent.Ruido)
	ruido.emitirSom({
		posicao = posicao,
		bandas = c.bandas,
		chao = c.chao,
		tipo = "detrito",
		dominante = tipo,
		modo = modo,
		fonte = fonte,
	})
	Sons.tocar(somNome or def.som, posicao, { db = c.db })
end

-- Raízes onde um detrito chutado pode pousar: chão, ruas, construções e a ZonaTeste (teste no void).
local function paramsChaoRuntime(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.IgnoreWater = true
	local lista: { Instance } = {}
	local mapa = workspace:FindFirstChild("Mapa")
	for _, nome in { "Chao", "Ruas" } do
		local f = mapa and mapa:FindFirstChild(nome)
		if f then
			table.insert(lista, f)
		end
	end
	for _, r in Raizes.obter("Construcoes") do
		table.insert(lista, r)
	end
	local zona = workspace:FindFirstChild("ZonaTeste")
	if zona then
		table.insert(lista, zona)
	end
	p.FilterDescendantsInstances = lista
	return p
end

local function mover(d: Detrito, nova: Vector3)
	tirarDaGrade(d)
	local delta = nova - d.pos
	d.pos = nova
	d.modelo:PivotTo(d.modelo:GetPivot() + delta)
	inserirNaGrade(d)
end

local function trocarTipo(d: Detrito, novoTipo: string)
	local pai = d.modelo.Parent
	local antigo = d.modelo
	d.tipo = novoTipo
	d.ultimo = setmetatable({}, { __mode = "k" }) :: any
	d.modelo = montarVisual(novoTipo, d.pos, rng)
	d.modelo.Parent = pai
	d.modelo.Destroying:Connect(function()
		tirarDaGrade(d)
		detritos[d.id] = nil
	end)
	-- o Destroying do modelo antigo tira o detrito da grade e da lista; ele continua, agora com outro tipo: volta para as duas
	antigo:Destroy()
	detritos[d.id] = d
	inserirNaGrade(d)
end

local function remover(d: Detrito)
	d.modelo:Destroy() -- o Destroying já tira da grade
end

-- Lata/garrafa pisada: anda de `chute.min` a `chute.max` studs na direção do passo, se houver chão ali.
local function chutar(d: Detrito, direcao: Vector3)
	local h = Vector3.new(direcao.X, 0, direcao.Z)
	h = if h.Magnitude > 0.01
		then h.Unit
		else Vector3.new(math.cos(rng:NextNumber(0, 6.283)), 0, math.sin(rng:NextNumber(0, 6.283)))
	local alvo = d.pos + h * rng:NextNumber(cfg.chute.min, cfg.chute.max)
	local r = workspace:Raycast(
		alvo + Vector3.new(0, ALTURA_CHUTE.acima, 0),
		Vector3.new(0, -ALTURA_CHUTE.queda, 0),
		paramsChaoRuntime()
	)
	if r and r.Normal.Y >= cfg.normalMinima then
		mover(d, r.Position)
	end
end

local function acionar(d: Detrito, jogador: Player, modo: string, direcao: Vector3)
	local def = cfg.tipos[d.tipo]
	local tipo = d.tipo
	emitir(tipo, def.nivel[modo], d.pos + Vector3.new(0, ALTURA_PARTE, 0), modo, jogador)
	if def.quebraAo and def.quebraAo[modo] then
		trocarTipo(d, def.quebraAo[modo]) -- garrafa correndo: quebra e vira vidro
	elseif def.chuta then
		chutar(d, direcao)
		local rolar = def.rolar
		if rolar and rolar.modos[modo] then
			-- lata correndo: depois de chutada, rola e faz um 2º barulho no ponto final
			task.delay(rolar.atraso, function()
				if d.modelo.Parent then
					emitir(tipo, rolar.db, d.pos, modo, jogador, rolar.som)
				end
			end)
		end
	elseif def.some then
		remover(d) -- galho quebra uma vez e some
	end
end

-- Chamado por Ruido.amostrar a cada passo: procura detritos a <= raioPe + raio do detrito do pé do jogador (grade de 8 studs).
function Detritos.aoPasso(jogador: Player, pe: Vector3, modo: string, direcao: Vector3)
	if not cfg.ligado then
		return
	end
	local chance = cfg.chance[modo]
	if not chance then
		return
	end
	local cx, cz = math.floor(pe.X / cfg.celula), math.floor(pe.Z / cfg.celula)
	local agora = os.clock()
	local achados: { Detrito } = {}
	for i = -1, 1 do
		for j = -1, 1 do
			local g = grade[(cx + i) .. ":" .. (cz + j)]
			if g then
				for _, d in g do
					local alcance = cfg.raioPe + cfg.tipos[d.tipo].raio
					local dx, dz = pe.X - d.pos.X, pe.Z - d.pos.Z
					if
						dx * dx + dz * dz <= alcance * alcance
						and math.abs(pe.Y - d.pos.Y) <= ALTURA_MAX_DIFERENCA
						and (d.ultimo[jogador] == nil or agora - d.ultimo[jogador] >= cfg.recarga)
					then
						table.insert(achados, d)
					end
				end
			end
		end
	end
	for _, d in achados do
		if d.modelo.Parent and rng:NextNumber() < chance then
			d.ultimo[jogador] = agora
			acionar(d, jogador, modo, direcao)
		end
	end
end

-- Colocação ------------------------------------------------------------------------------------------------------------------

-- Sorteia o tipo pelo peso na zona. Dentro de construção: só os que podem (dentro) e a tábua apenas com piso de madeira.
local function sortearTipo(zona: string, dentro: boolean, madeira: boolean, r: Random): string?
	local pesos: { number } = {}
	local total = 0
	for i, nome in nomesTipos do
		local def = cfg.tipos[nome]
		local peso = def.zonas[zona] or 0
		if def.interiorMadeira then
			peso = if dentro and madeira then def.interiorMadeira else 0
		elseif dentro and not def.dentro then
			peso = 0
		end
		pesos[i] = peso
		total += peso
	end
	if total <= 0 then
		return nil
	end
	local alvo = r:NextNumber(0, total)
	for i, nome in nomesTipos do
		alvo -= pesos[i]
		if alvo <= 0 and pesos[i] > 0 then
			return nome
		end
	end
	return nil
end

local function lerZonas(mapa: Instance): { [string]: { Zona } }
	local porChave: { [string]: { Zona } } = {}
	local zonas = mapa:FindFirstChild("Zonas")
	if zonas then
		for _, p in zonas:GetChildren() do
			local chave = p:GetAttribute("Zona")
			if p:IsA("BasePart") and type(chave) == "string" then
				local lista = porChave[chave]
				if not lista then
					lista = {}
					porChave[chave] = lista
				end
				table.insert(lista, {
					chave = chave,
					cx = p.Position.X,
					cz = p.Position.Z,
					sx = p.Size.X,
					sz = p.Size.Z,
					topo = p.Position.Y + p.Size.Y / 2,
					altura = p.Size.Y,
				})
			end
		end
	end
	return porChave
end

local function dentroDe(z: Zona, x: number, zz: number): boolean
	return math.abs(x - z.cx) <= z.sx / 2 and math.abs(zz - z.cz) <= z.sz / 2
end

-- Zona de um ponto pela prioridade do mapa: cidade > vila > fábrica > outros > floresta.
local function zonaEm(porChave: { [string]: { Zona } }, x: number, z: number): string
	for _, chave in PRIORIDADE_ZONA do
		for _, zona in porChave[chave] or {} do
			if dentroDe(zona, x, z) then
				return chave
			end
		end
	end
	for chave in ZONAS_OUTROS do
		for _, zona in porChave[chave] or {} do
			if dentroDe(zona, x, z) then
				return "outros"
			end
		end
	end
	return "floresta"
end

local function filhos(mapa: Instance, nome: string): Instance?
	return mapa:FindFirstChild(nome)
end

-- Número de detritos de cada zona (arredondado), na ordem alfabética das zonas: o sorteio com semente fixa é determinístico.
local function metas(): { { zona: string, n: number } }
	local m: { { zona: string, n: number } } = {}
	for zona, fracao in cfg.partilha do
		table.insert(m, { zona = zona, n = math.floor(cfg.total * fracao + 0.5) })
	end
	table.sort(m, function(a, b)
		return a.zona < b.zona
	end)
	return m
end

local function colocarTodos()
	local inicio = os.clock()
	local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
	if not mapa then
		warn("[Detritos] workspace.Mapa não existe: nenhum detrito colocado")
		return
	end
	local r = Random.new(cfg.semente)
	local zonasPorChave = lerZonas(mapa)
	local construcoes = filhos(mapa, "Construcoes")
	local props = filhos(mapa, "Props")

	-- raios: chão aberto (chão + ruas + construções, para reconhecer telhado) e interior (só construções)
	local paramsAberto = RaycastParams.new()
	paramsAberto.FilterType = Enum.RaycastFilterType.Include
	paramsAberto.IgnoreWater = true
	local listaAberto: { Instance } = {}
	for _, nome in { "Chao", "Ruas", "Construcoes" } do
		local f = filhos(mapa, nome)
		if f then
			table.insert(listaAberto, f)
		end
	end
	paramsAberto.FilterDescendantsInstances = listaAberto
	local paramsInterior = RaycastParams.new()
	paramsInterior.FilterType = Enum.RaycastFilterType.Include
	paramsInterior.IgnoreWater = true
	paramsInterior.FilterDescendantsInstances = if construcoes then { construcoes } else {}
	local paramsLivre = OverlapParams.new()
	paramsLivre.FilterType = Enum.RaycastFilterType.Include
	local listaLivre: { Instance } = {}
	for _, f in { construcoes, props } do
		if f then
			table.insert(listaLivre, f)
		end
	end
	paramsLivre.FilterDescendantsInstances = listaLivre
	paramsLivre.MaxParts = 1

	-- Rios: as Parts `Agua` de Mapa.Rios viram água do Terrain (server/Rios). O raio ignora água e bate no leito; por isso o ponto é
	-- conferido contra a caixa de cada Agua (no espaço da peça, com folga em cima para pegar a margem alagada).
	local aguas: { BasePart } = {}
	local pastaRios = filhos(mapa, "Rios")
	if pastaRios then
		for _, p in pastaRios:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(aguas, p)
			end
		end
	end
	local function naAgua(ponto: Vector3): boolean
		for _, p in aguas do
			local l = p.CFrame:PointToObjectSpace(ponto)
			local m = p.Size / 2
			if math.abs(l.X) <= m.X and math.abs(l.Z) <= m.Z and l.Y >= -m.Y - 1 and l.Y <= m.Y + 2 then
				return true
			end
		end
		return false
	end

	-- prédios por zona (atributo Zona do Model), com a caixa orientada
	local prediosPorZona: { [string]: { Predio } } = {}
	local lidos = 0
	if construcoes then
		for _, modelo in construcoes:GetChildren() do
			lidos += 1
			if lidos % cfg.lote == 0 then
				task.wait()
			end
			local zona = modelo:GetAttribute("Zona")
			if modelo:IsA("Model") and type(zona) == "string" then
				local cf, tam = modelo:GetBoundingBox()
				local lista = prediosPorZona[zona]
				if not lista then
					lista = {}
					prediosPorZona[zona] = lista
				end
				table.insert(lista, { cf = cf, tam = tam, zona = zona })
			end
		end
	end

	local pastaD = pastaDetritos()
	local colocados, tentativasTotal = 0, 0
	local contagem: { [string]: number } = {}

	local function livre(ponto: Vector3): boolean
		local l = cfg.livreCaixa
		local caixa = CFrame.new(ponto + Vector3.new(0, 0.2 + l / 2, 0))
		return #workspace:GetPartBoundsInBox(caixa, Vector3.new(l, l, l), paramsLivre) == 0
	end

	-- Um ponto candidato da zona: dentro de um prédio (interior) ou ao ar livre. Devolve (ponto, dentro, madeira) ou nil.
	local function candidato(zona: string, interior: boolean): (Vector3?, boolean, boolean)
		if interior then
			local lista = prediosPorZona[zona]
			if not lista or #lista == 0 then
				return nil, false, false
			end
			local p = lista[r:NextInteger(1, #lista)]
			local lx = r:NextNumber(-1, 1) * p.tam.X / 2 * cfg.margemPredio
			local lz = r:NextNumber(-1, 1) * p.tam.Z / 2 * cfg.margemPredio
			local ly = r:NextNumber(-p.tam.Y / 2 + cfg.alturaInterior.baixo, p.tam.Y / 2 - cfg.alturaInterior.alto)
			local origem = p.cf:PointToWorldSpace(Vector3.new(lx, ly, lz))
			local res = workspace:Raycast(origem, Vector3.new(0, -cfg.alturaInterior.alcance, 0), paramsInterior)
			if res and res.Normal.Y >= cfg.normalMinima then
				return res.Position, true, Som.superficieDeMaterial(res.Material.Name) == "madeira"
			end
			return nil, false, false
		end
		local lista = zonasPorChave[zona]
		if not lista or #lista == 0 then
			return nil, false, false
		end
		local z = lista[r:NextInteger(1, #lista)]
		local x = z.cx + r:NextNumber(-0.5, 0.5) * z.sx
		local zz = z.cz + r:NextNumber(-0.5, 0.5) * z.sz
		if zonaEm(zonasPorChave, x, zz) ~= zona then
			return nil, false, false
		end
		local res = workspace:Raycast(Vector3.new(x, z.topo, zz), Vector3.new(0, -(z.altura + 50), 0), paramsAberto)
		if not res or res.Normal.Y < cfg.normalMinima then
			return nil, false, false
		end
		if construcoes and res.Instance:IsDescendantOf(construcoes) then
			return nil, false, false -- bateu em telhado: o interior tem o seu próprio sorteio
		end
		if naAgua(res.Position) then
			return nil, false, false -- leito de rio
		end
		return res.Position, false, false
	end

	local iteracoes = 0
	for _, par in metas() do
		local zona, meta = par.zona, par.n
		local nDentro = math.floor(meta * (cfg.dentroFracao[zona] or 0) + 0.5)
		for i = 1, meta do
			local interior = i <= nDentro
			for _ = 1, cfg.tentativas do
				tentativasTotal += 1
				local ponto, dentro, madeira = candidato(zona, interior)
				if ponto and livre(ponto) then
					local tipo = sortearTipo(zona, dentro, madeira, r)
					if tipo then
						registrar(tipo, ponto, pastaD, r)
						colocados += 1
						contagem[tipo] = (contagem[tipo] or 0) + 1
						break
					end
				end
			end
			iteracoes += 1
			if iteracoes % cfg.lote == 0 then
				task.wait()
			end
		end
	end

	local partes = {}
	for _, nome in nomesTipos do
		table.insert(partes, nome .. "=" .. (contagem[nome] or 0))
	end
	print(
		string.format(
			"[Detritos] %d detritos colocados em %.2f s (%d tentativas): %s",
			colocados,
			os.clock() - inicio,
			tentativasTotal,
			table.concat(partes, " ")
		)
	)
end

function Detritos.contar(): number
	local n = 0
	for _ in detritos do
		n += 1
	end
	return n
end

function Detritos.iniciar()
	if not cfg.ligado then
		return
	end
	pastaDetritos()
	Players.PlayerRemoving:Connect(function(jogador)
		for _, d in detritos do
			d.ultimo[jogador] = nil
		end
	end)
	Teste.registrar("detritos", function(_jogador: Player, n: number?)
		local zona = workspace:FindFirstChild("ZonaTeste")
		local ancora = zona and zona:FindFirstChild("Ancora")
		if not (zona and ancora and ancora:IsA("BasePart")) then
			return "sem Workspace.ZonaTeste/Ancora (skill teste-no-void)"
		end
		local quantos = math.clamp(math.floor(n or 1), 1, MAX_TESTE)
		local pai = zona:FindFirstChild("Detritos")
		if not pai then
			pai = Instance.new("Folder")
			pai.Name = "Detritos"
			pai.Parent = zona
		end
		local base = ancora.Position + Vector3.new(-20, ancora.Size.Y / 2, -20)
		local r = Random.new()
		for i, nome in nomesTipos do
			for j = 1, quantos do
				registrar(nome, base + Vector3.new(j * 3, 0, i * 4), pai, r)
			end
		end
		return string.format(
			"%d detritos de cada tipo em fila (%s), x a partir de %s",
			quantos,
			table.concat(nomesTipos, ", "),
			tostring(base)
		)
	end)
	Teste.registrar("contardetritos", function()
		return string.format("%d detritos ativos", Detritos.contar())
	end)
	task.spawn(function()
		local ok, erro = pcall(colocarTodos)
		if not ok then
			warn("[Detritos] erro ao colocar os detritos: " .. tostring(erro))
		end
	end)
end

return Detritos
