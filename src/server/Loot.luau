-- Loot (servidor): compartimentos de loot nos móveis do mapa (e porta-malas) e a janela de abrir/pegar.
-- Dono: P6. Contrato: docs/compartimentos.md (móveis) e docs/arquitetura.md §5 (janela). Categorias em
-- Config/Compartimentos. Itens soltos no chão (largados, de morte, de ponto Loot) são do ItensChao, não daqui.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Itens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local CfgArmas = require(Shared.Config:WaitForChild("Armas"))
local Compartimentos = require(Shared:WaitForChild("Config"):WaitForChild("Compartimentos"))
local RegrasLoot = require(Shared:WaitForChild("Regras"):WaitForChild("Loot"))
local Limite = require(script.Parent.Limite)

type Item = RegrasLoot.Item
type Caixa = {
	conteudo: { Item },
	tabela: string, -- categoria (chave de Compartimentos.tabelas)
	reposicaoAgendada: boolean,
	sorteado: boolean, -- false até a primeira abertura (sorteio preguiçoso)
	nome: string, -- texto do prompt ("Geladeira")
}

local Loot = {}

-- Folga sobre Itens.alcanceInteracao para a latência (o jogador anda entre o clique e a chegada do evento).
-- INTEGRACAO: virar Config/Itens.folgaInteracao (ver docs/pendencias-integracao.md, P6).
local FOLGA_ALCANCE = 1.25
local ESPERA_MAPA = 15 -- s esperando workspace.Mapa aparecer
local LOTE_VARREDURA = 500 -- descendentes de Construcoes visitados antes de ceder (task.wait) ao servidor

local aleatorio = Random.new()
local caixas: { [Instance]: Caixa } = {}
-- Quem está com a janela de cada container aberta, para reenviar o conteúdo quando outro jogador pega algo
-- (os índices mudam quando uma entrada some). Chave fraca: container destruído libera a entrada.
local vendo: { [Instance]: { [Player]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local servicos: { [string]: any } = {}
local function servico(nome: string): any
	local m = servicos[nome]
	if m == nil then
		local arquivo = script.Parent:FindFirstChild(nome)
		local ok, resultado = false, nil
		if arquivo then
			ok, resultado = pcall(require, arquivo)
		end
		if ok then
			m = resultado
		else
			warn("[Loot] serviço indisponível: " .. nome .. " " .. tostring(resultado))
			m = false
		end
		servicos[nome] = m
	end
	return m or nil
end

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

-- Faixa do pente de arma achada no chão (fração da capacidade); sem Itens.penteLoot cai no padrão 40%-100%.
local FAIXA_PENTE_PADRAO = { 0.4, 1 }

-- Arma de fogo sorteada nasce com pente sorteado, e cada arma é uma entrada própria (cada uma com o seu pente).
local function comPentes(sorteado: { Item }): { Item }
	local saida: { Item } = {}
	local faixa = Itens.penteLoot or FAIXA_PENTE_PADRAO
	for _, item in sorteado do
		local def = Itens.itens[item.id]
		local cfg = if def and def.tipo == "arma" then CfgArmas.armas[def.arma] else nil
		if cfg and cfg.tipo == "fogo" then
			for _ = 1, item.qtd do
				local pente = RegrasLoot.penteSorteado(cfg.pente, faixa, function()
					return aleatorio:NextNumber()
				end)
				table.insert(saida, { id = item.id, qtd = 1, pente = pente })
			end
		else
			table.insert(saida, item)
		end
	end
	return saida
end

local function sortearCategoria(categoria: string): { Item }
	return comPentes(RegrasLoot.sortear(Compartimentos.tabelas[categoria], function()
		return aleatorio:NextNumber()
	end))
end

local function copiar(conteudo: { Item }): { Item }
	local c: { Item } = {}
	for _, item in conteudo do
		table.insert(c, { id = item.id, qtd = item.qtd, pente = item.pente })
	end
	return c
end

local function textoObjeto(caixa: Caixa): string
	if not caixa.sorteado or #caixa.conteudo > 0 then
		return caixa.nome
	end
	return caixa.nome .. " (vazio)"
end

local function atualizarTexto(parte: Instance, caixa: Caixa)
	local prompt = parte:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ObjectText = textoObjeto(caixa)
	end
end

-- Sorteia o conteúdo na primeira vez que alguém mexe no compartimento.
local function garantirConteudo(caixa: Caixa)
	if caixa.sorteado then
		return
	end
	caixa.conteudo = sortearCategoria(caixa.tabela)
	caixa.sorteado = true
end

-- Conteúdo atual (cópia) de um compartimento; nil se `container` não é um.
local function conteudoDe(container: Instance): { Item }?
	local caixa = caixas[container]
	if not caixa then
		return nil
	end
	if not caixa.sorteado then
		garantirConteudo(caixa)
		atualizarTexto(container, caixa)
	end
	return copiar(caixa.conteudo)
end

local function alcance(jogador: Player, container: Instance): boolean
	local personagem = jogador.Character
	local hrp = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") or not container:IsA("BasePart") then
		return false
	end
	return (hrp.Position - container.Position).Magnitude <= Itens.alcanceInteracao * FOLGA_ALCANCE
end

local function estaVivo(jogador: Player): boolean
	local Vida = servico("Vida")
	if Vida then
		return Vida.estaVivo(jogador)
	end
	-- INTEGRACAO: sem Vida (P5), vale o Humanoid do Roblox.
	local humanoid = jogador.Character and jogador.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Container que o jogador pode mexer agora: compartimento real, jogador vivo e perto.
local function acessivel(jogador: Player, container: any): Instance?
	if typeof(container) ~= "Instance" or container.Parent == nil then
		return nil
	end
	if not caixas[container] then
		return nil
	end
	if not estaVivo(jogador) or not alcance(jogador, container) then
		return nil
	end
	return container
end

local function enviar(jogador: Player, container: Instance)
	local conteudo = conteudoDe(container)
	if conteudo then
		Rede.evento("ConteudoCaixa"):FireClient(jogador, container, conteudo)
	end
end

-- Manda o conteúdo novo a todo mundo que está com a janela aberta (e esquece quem saiu ou se afastou).
local function avisarQuemVe(container: Instance)
	local lista = vendo[container]
	if not lista then
		return
	end
	for jogador in lista do
		if jogador.Parent and alcance(jogador, container) then
			enviar(jogador, container)
		else
			lista[jogador] = nil
		end
	end
end

local function agendarReposicao(parte: Instance, caixa: Caixa)
	if caixa.reposicaoAgendada then
		return
	end
	caixa.reposicaoAgendada = true
	task.delay(Itens.reposicao, function()
		if caixas[parte] ~= caixa then
			return
		end
		caixa.reposicaoAgendada = false
		caixa.conteudo = sortearCategoria(caixa.tabela)
		atualizarTexto(parte, caixa)
		avisarQuemVe(parte)
	end)
end

-- Abre a janela: o compartimento faz barulho e som.
function Loot.abrir(jogador: Player, container: any)
	local alvo = acessivel(jogador, container)
	if not alvo or not Limite.ok(jogador, "AbrirCaixa", 0.3) then
		return
	end
	local Ruido = servico("Ruido")
	if Ruido then
		Ruido.emitirAcao("abrirCaixa", (alvo :: BasePart).Position, jogador)
	end
	local Sons = servico("Sons")
	if Sons then
		Sons.tocar("AbrirCaixa", alvo :: BasePart)
	end
	local lista = vendo[alvo]
	if not lista then
		lista = {}
		vendo[alvo] = lista
	end
	lista[jogador] = true
	enviar(jogador, alvo)
end

local function pegar(jogador: Player, container: any, indice: any)
	if type(indice) ~= "number" or indice % 1 ~= 0 or indice < 1 then
		return
	end
	local alvo = acessivel(jogador, container)
	if not alvo then
		return
	end
	local Inventario = servico("Inventario")
	local conteudo = conteudoDe(alvo)
	local entrada = conteudo and conteudo[indice]
	if not Inventario or not entrada then
		-- índice velho (outro jogador levou o item): mostra a lista atual
		enviar(jogador, alvo)
		return
	end
	local n = math.min(entrada.qtd, Inventario.espaco(jogador, entrada.id))
	if n < 1 then
		aviso(jogador, "Inventário cheio")
		return
	end

	local caixa = caixas[alvo]
	caixa.conteudo = RegrasLoot.retirar(caixa.conteudo, indice, n)
	local sobra = Inventario.dar(jogador, entrada.id, n, entrada.pente)
	if sobra > 0 then
		-- Não deveria acontecer (espaco acabou de ser conferido, sem yield no meio).
		warn(string.format("[Loot] %s: sobraram %d de %s ao pegar", jogador.Name, sobra, entrada.id))
	end

	atualizarTexto(alvo, caixa)
	if #caixa.conteudo == 0 then
		agendarReposicao(alvo, caixa)
	end
	local lista = vendo[alvo]
	if lista then
		lista[jogador] = true
	end
	avisarQuemVe(alvo)
end

-- Peça que segura o compartimento: PrimaryPart do móvel; senão, a BasePart de maior volume entre os filhos diretos.
local function containerDe(modelo: Model): BasePart?
	if modelo.PrimaryPart then
		return modelo.PrimaryPart
	end
	local maior: BasePart? = nil
	local volumeMaior = -1
	for _, filho in modelo:GetChildren() do
		if filho:IsA("BasePart") then
			local tamanho = filho.Size
			local volume = tamanho.X * tamanho.Y * tamanho.Z
			if volume > volumeMaior then
				maior = filho
				volumeMaior = volume
			end
		end
	end
	return maior
end

-- Torna `container` (peça de um móvel) um compartimento: estado, atributos e ProximityPrompt.
local function criarCompartimento(container: BasePart, categoria: string, nome: string)
	local caixa: Caixa = {
		conteudo = {},
		tabela = categoria,
		reposicaoAgendada = false,
		sorteado = false,
		nome = nome,
	}
	caixas[container] = caixa
	container:SetAttribute("Compartimento", categoria)
	container:SetAttribute("Nome", nome)
	container.Destroying:Connect(function()
		caixas[container] = nil
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir"
	prompt.ObjectText = nome
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Itens.alcanceInteracao
	prompt.RequiresLineOfSight = false
	prompt.Parent = container
	prompt.Triggered:Connect(function(jogador: Player)
		Loot.abrir(jogador, container)
	end)
end

-- Varre Mapa.Construcoes e cria compartimentos nos móveis sorteados pela chance (cede o servidor a cada lote).
local function montarCompartimentos()
	local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
	local construcoes = mapa and mapa:WaitForChild("Construcoes", ESPERA_MAPA)
	if not construcoes then
		warn("[Loot] workspace.Mapa.Construcoes não existe: nenhum compartimento criado")
		return
	end

	local moveisComLoot = 0
	local criados = 0
	local porCategoria: { [string]: number } = {}
	local categoriasAusentes: { [string]: boolean } = {}
	local visitados = 0
	for _, instancia in construcoes:GetDescendants() do
		visitados += 1
		if visitados % LOTE_VARREDURA == 0 then
			task.wait()
		end
		if not instancia:IsA("Model") then
			continue
		end
		local nomeMovel = instancia:GetAttribute("Movel")
		local movel = if type(nomeMovel) == "string" then Compartimentos.moveis[nomeMovel] else nil
		if not movel then
			continue
		end
		moveisComLoot += 1
		if Compartimentos.tabelas[movel.categoria] == nil then
			if not categoriasAusentes[movel.categoria] then
				categoriasAusentes[movel.categoria] = true
				warn("[Loot] categoria sem tabela em Compartimentos: " .. tostring(movel.categoria))
			end
			continue
		end
		if aleatorio:NextNumber() >= movel.chance then
			continue
		end
		local container = containerDe(instancia)
		if not container then
			warn("[Loot] móvel sem peça: " .. instancia:GetFullName())
			continue
		end
		criarCompartimento(container, movel.categoria, movel.nome)
		criados += 1
		porCategoria[movel.categoria] = (porCategoria[movel.categoria] or 0) + 1
	end

	local categorias = {}
	for categoria in porCategoria do
		table.insert(categorias, categoria)
	end
	table.sort(categorias)
	local partes = {}
	for _, categoria in categorias do
		table.insert(partes, string.format("%s %d", categoria, porCategoria[categoria]))
	end
	print(
		string.format(
			"[Loot] %d compartimentos criados em %d móveis (%s)",
			criados,
			moveisComLoot,
			table.concat(partes, ", ")
		)
	)
end

-- Veiculos (porta-malas) cria compartimentos em peças próprias.
Loot.registrarCompartimento = criarCompartimento

function Loot.iniciar()
	Rede.evento("AbrirCaixa").OnServerEvent:Connect(function(jogador: Player, container: any)
		Loot.abrir(jogador, container)
	end)
	Rede.evento("PegarItem").OnServerEvent:Connect(function(jogador: Player, container: any, indice: any)
		if Limite.ok(jogador, "PegarItem", 0.15) then
			pegar(jogador, container, indice)
		end
	end)
	Players.PlayerRemoving:Connect(function(jogador: Player)
		for _, lista in vendo do
			lista[jogador] = nil
		end
	end)

	task.spawn(montarCompartimentos)
end

return Loot
