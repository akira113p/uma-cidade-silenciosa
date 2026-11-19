-- Obstaculos: esbarrar em móveis e props (docs/som.md §5.2) e entrar em vegetação (§5.3). Chamado por Ruido.amostrar a cada amostra (10 Hz)
-- de quem está se movendo: UMA consulta espacial por jogador por amostra (a mesma caixa serve ao esbarrão e ao mato).
-- Móveis têm o atributo `Movel` e props o atributo `Prop` (ferramentas/mapa/mobilia_tamanhos.luau e props_tamanhos.luau); nada muda no mapa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Raizes = require(Shared:WaitForChild("Raizes"))
local Sons = require(script.Parent.Sons)
local Teste = require(script.Parent.Teste)

local Obstaculos = {}

local SUBIDA_ANCESTRAIS = 4 -- ancestrais que se sobe procurando o Model com Movel/Prop (docs/som.md §5.2)
local MAX_PARTES = 40 -- partes devolvidas por consulta
local ATUALIZAR_RAIZES = 1 -- s entre refazer a lista de raízes (a ZonaTeste pode surgir ou sumir)

local cfg = CfgSom.esbarrar
local rng = Random.new()

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.MaxParts = MAX_PARTES

local raizesAtuais: { Instance } = {}
local proximaAtualizacao = 0

-- nome do Movel/Prop (minúsculo) → classe de esbarrão, montado uma vez a partir de Config/Som.esbarrar.classes
local classePorNome: { [string]: string } = {}
for nomeClasse, def in cfg.classes do
	for _, nome in def.nomes do
		classePorNome[nome] = nomeClasse
	end
end

type EstadoJogador = {
	anterior: { [Instance]: boolean }, -- objetos na caixa da amostra anterior (contato novo = não estava aqui)
	pares: { [Instance]: number }, -- objeto → os.clock() do último esbarrão deste jogador (recarga)
	vegetacao: boolean, -- resultado da última amostra
}
local estados: { [Player]: EstadoJogador } = {}

-- custo medido (docs/som.md §9 fase C): soma de tempo e contagem das chamadas de amostrar
local custoTotal, custoChamadas = 0, 0

local function atualizarRaizes()
	local agora = os.clock()
	if agora < proximaAtualizacao then
		return
	end
	proximaAtualizacao = agora + ATUALIZAR_RAIZES
	local lista: { Instance } = {}
	for _, nome in { "Construcoes", "Props", "Vegetacao" } do
		for _, raiz in Raizes.obter(nome) do
			table.insert(lista, raiz)
		end
	end
	if not Raizes.iguais(lista, raizesAtuais) then
		raizesAtuais = lista
		params.FilterDescendantsInstances = lista
	end
end

-- O nome (ou o de algum ancestral próximo) tem arbusto/moita/cerca_viva/fronde?
local function ehVegetacao(parte: Instance): boolean
	local atual: Instance? = parte
	for _ = 0, SUBIDA_ANCESTRAIS do
		if not atual or atual == workspace then
			break
		end
		local nome = string.lower(atual.Name)
		local prop = atual:GetAttribute("Prop")
		if type(prop) == "string" then
			nome ..= " " .. string.lower(prop)
		end
		for _, v in CfgSom.vegetacao.nomes do
			if string.find(nome, v, 1, true) then
				return true
			end
		end
		atual = atual.Parent
	end
	return false
end

-- Sobe até 4 ancestrais atrás de um Model com Movel ou Prop. Devolve (modelo, nome).
local function objetoDe(parte: Instance): (Model?, string?)
	local atual: Instance? = parte
	for _ = 0, SUBIDA_ANCESTRAIS do
		if not atual or atual == workspace then
			return nil, nil
		end
		if atual:IsA("Model") then
			local nome = atual:GetAttribute("Movel")
			if type(nome) ~= "string" then
				nome = atual:GetAttribute("Prop")
			end
			if type(nome) == "string" then
				return atual, nome
			end
		end
		atual = atual.Parent
	end
	return nil, nil
end

local function esbarrar(
	jogador: Player,
	estado: EstadoJogador,
	modelo: Model,
	nome: string,
	modo: string,
	ponto: Vector3
)
	local classe = classePorNome[nome] or cfg.padrao
	local def = cfg.classes[classe]
	local nivel = def.nivel[modo]
	if nivel == nil then
		return
	end
	local c = Som.compor({ { nome = classe, nivel = nivel, perfil = def.perfil, chao = def.chao } })
	local ruido = require(script.Parent.Ruido)
	ruido.emitirSom({
		posicao = ponto,
		bandas = c.bandas,
		chao = c.chao,
		tipo = "esbarrao",
		dominante = classe,
		modo = modo,
		fonte = jogador,
	})
	Sons.tocar(def.som, ponto, { db = c.db })
	estado.pares[modelo] = os.clock()
end

-- Uma amostra de `jogador` em movimento (`modo`: "deitado" | "agachado" | "andar" | "correr"; direcao horizontal unitária; pe = posição do pé).
-- Devolve true se há vegetação (arbusto/mato) em volta: entra na camada de vegetação do passo.
function Obstaculos.amostrar(jogador: Player, raiz: BasePart, modo: string, direcao: Vector3, pe: Vector3): boolean
	local inicio = os.clock()
	local estado = estados[jogador]
	if not estado then
		estado = { anterior = {}, pares = setmetatable({}, { __mode = "k" }) :: any, vegetacao = false }
		estados[jogador] = estado
	end
	atualizarRaizes()

	local alto = modo == "andar" or modo == "correr"
	local cf: CFrame
	local tamanho: Vector3
	if alto then
		local c = cfg.caixa
		local centro =
			Vector3.new(raiz.Position.X + direcao.X * c.frente, pe.Y + c.altura, raiz.Position.Z + direcao.Z * c.frente)
		cf = CFrame.lookAt(centro, centro + direcao)
		tamanho = Vector3.new(c.tamanho[1], c.tamanho[2], c.tamanho[3])
	else
		-- agachado/deitado: caixa menor, só para vegetação (sem esbarrão)
		local b = CfgSom.vegetacao.caixaBaixa
		cf = CFrame.new(Vector3.new(raiz.Position.X, pe.Y + b[2] / 2, raiz.Position.Z))
		tamanho = Vector3.new(b[1], b[2], b[3])
	end

	local partes = workspace:GetPartBoundsInBox(cf, tamanho, params)
	local vegetacao = false
	local agora: { [Instance]: boolean } = {}
	local novos: { { modelo: Model, nome: string } } = {}
	for _, parte in partes do
		if ehVegetacao(parte) then
			vegetacao = true
			continue
		end
		if alto and cfg.ligado then
			local modelo, nome = objetoDe(parte)
			if modelo and nome and not agora[modelo] then
				agora[modelo] = true
				if not estado.anterior[modelo] then
					table.insert(novos, { modelo = modelo, nome = nome })
				end
			end
		end
	end
	estado.anterior = agora
	estado.vegetacao = vegetacao

	-- contato novo: correndo, sempre; andando, com chance. Recarga por par (jogador, objeto).
	local t = os.clock()
	for _, n in novos do
		local ultimo = estado.pares[n.modelo]
		if
			(ultimo == nil or t - ultimo >= cfg.recarga) and (modo == "correr" or rng:NextNumber() < cfg.chanceAndar)
		then
			esbarrar(jogador, estado, n.modelo, n.nome, modo, cf.Position)
		end
	end

	custoTotal += os.clock() - inicio
	custoChamadas += 1
	return vegetacao
end

-- Última vegetação medida de um jogador (para quem precisar sem uma nova consulta).
function Obstaculos.vegetacao(jogador: Player): boolean
	local e = estados[jogador]
	return e ~= nil and e.vegetacao
end

-- Custo médio por amostra em milissegundos e número de amostras (comando de teste "custoobstaculos").
function Obstaculos.custo(): (number, number)
	return if custoChamadas > 0 then custoTotal / custoChamadas * 1000 else 0, custoChamadas
end

function Obstaculos.iniciar()
	Players.PlayerRemoving:Connect(function(jogador)
		estados[jogador] = nil
	end)
	Teste.registrar("custoobstaculos", function()
		local ms, n = Obstaculos.custo()
		local texto = string.format("Obstaculos.amostrar: %.4f ms por chamada em média (%d chamadas)", ms, n)
		print("[Obstaculos] " .. texto)
		return texto
	end)
end

return Obstaculos
