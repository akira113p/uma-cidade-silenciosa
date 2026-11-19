-- ItensChao (servidor): itens soltos no mundo (pontos Loot, largados pelo jogador, espalhados na morte) e a coleta com E.
-- Contrato: docs/itens-no-mundo.md §3-C. O item no chão é SEMPRE Anchored (sem física do Roblox): o arremesso é a
-- simulação balística de Regras/Arremesso animada por PivotTo no Heartbeat. Modelos: shared/ItemModelo. Números: Config/ItensChao.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local ItemModelo = require(Shared:WaitForChild("ItemModelo"))
local Itens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local CfgArmas = require(Shared.Config:WaitForChild("Armas"))
local Cfg = require(Shared.Config:WaitForChild("ItensChao"))
local CfgSom = require(Shared.Config:WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Arremesso = require(Shared:WaitForChild("Regras"):WaitForChild("Arremesso"))
local RegrasChao = require(Shared.Regras:WaitForChild("ItensChao"))
local RegrasLoot = require(Shared.Regras:WaitForChild("Loot"))
local Limite = require(script.Parent.Limite)

local ItensChao = {}

local ESPERA_MAPA = 15 -- s esperando workspace.Mapa aparecer
local LOTE_PONTOS = 100 -- pontos visitados antes de ceder (task.wait) ao servidor
local QUEDA_MAXIMA = 30 -- studs que o raio procura chão sob um item sem ponto
local FOLGA_ALCANCE = 1.25 -- sobre Cfg.alcance, para a latência
local ALTURA_LARGAR = 1.2 -- studs acima do HumanoidRootPart de onde o item sai
local FRENTE_LARGAR = 1.5 -- studs à frente do HumanoidRootPart
local FAIXA_PENTE_PADRAO = { 0.4, 1 }
local TAG = "ItemChao"

type Registro = {
	t: number, -- os.clock() da criação (para o limite de itens)
	id: string,
	largado: boolean,
	ponto: Instance?, -- ponto Loot de origem (item de ponto repõe depois de pego)
}
type Voo = {
	modelo: Model,
	pontos: { Vector3 },
	passo: number,
	duracao: number,
	t: number,
	altura: number, -- distância da origem do modelo ao ponto mais baixo (sobe aos poucos até o pouso)
	rotFinal: CFrame, -- só rotação
	final: CFrame,
	eixo: Vector3,
	giro: number, -- rad/s no início; zera até o pouso
	aoPousar: (() -> ())?, -- som da queda (docs/som.md §5.4)
}
export type Opcoes = { largado: boolean?, ponto: Instance?, pente: number? }

local aleatorio = Random.new()
local registro: { [Instance]: Registro } = {}
local total = 0
local voando: { Voo } = {}
local conexao: RBXScriptConnection? = nil

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local proximoFiltro = 0

-- Outros serviços carregados sob demanda: se um deles falhou ao carregar, os itens do chão continuam funcionando.
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
			warn("[ItensChao] serviço indisponível: " .. nome .. " " .. tostring(resultado))
			m = false
		end
		servicos[nome] = m
	end
	return m or nil
end

local function rng(): number
	return aleatorio:NextNumber()
end

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

local function pasta(): Folder
	local existente = workspace:FindFirstChild("ItensChao")
	if existente and existente:IsA("Folder") then
		return existente
	end
	local nova = Instance.new("Folder")
	nova.Name = "ItensChao"
	nova.Parent = workspace
	return nova
end

local function v3(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function tabela(v: Vector3): { x: number, y: number, z: number }
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Fora do raycast: personagens, monstros, os próprios itens e o que não é "mundo". Reconstruído a cada 1 s.
local function parametros(): RaycastParams
	local agora = os.clock()
	if agora >= proximoFiltro then
		proximoFiltro = agora + 1
		local lista: { Instance } = { pasta() }
		for _, j in Players:GetPlayers() do
			if j.Character then
				table.insert(lista, j.Character)
			end
		end
		for _, nome in { "Monstros", "SonsSoltos", "Projeteis" } do
			local f = workspace:FindFirstChild(nome)
			if f then
				table.insert(lista, f)
			end
		end
		local mapa = workspace:FindFirstChild("Mapa")
		if mapa then
			for _, nome in { "Pontos", "Zonas", "Vegetacao" } do
				local f = mapa:FindFirstChild(nome)
				if f then
					table.insert(lista, f)
				end
			end
		end
		params.FilterDescendantsInstances = lista
	end
	return params
end

local function chaoSob(origem: Vector3, distancia: number): Vector3?
	local acerto = workspace:Raycast(origem, Vector3.new(0, -distancia, 0), parametros())
	return if acerto then acerto.Position else nil
end

local function raio(a: { x: number, y: number, z: number }, b: { x: number, y: number, z: number })
	local pa = v3(a)
	local acerto = workspace:Raycast(pa, v3(b) - pa, parametros())
	if acerto then
		return tabela(acerto.Position), tabela(acerto.Normal)
	end
	return nil, nil
end

-- Registro e criação ---------------------------------------------------------------------------------------------

local agendarReposicao: (ponto: Instance) -> ()

local function sortearPonto(ponto: Instance): boolean
	local nomeTabela = ponto:GetAttribute("Tabela")
	local def = if type(nomeTabela) == "string" then Itens.tabelas[nomeTabela] else nil
	if not def then
		return false
	end
	local sorteio = RegrasChao.sortearPonto(def, rng, Cfg.chanceSpawn)
	if not sorteio then
		return false
	end
	-- arma de fogo achada no chão nasce com o pente sorteado (como nas caixas do Loot)
	local pente: number? = nil
	local itemDef = Itens.itens[sorteio.id]
	local cfgArma = if itemDef and itemDef.tipo == "arma" then CfgArmas.armas[itemDef.arma] else nil
	if cfgArma and cfgArma.tipo == "fogo" then
		pente = RegrasLoot.penteSorteado(cfgArma.pente, Itens.penteLoot or FAIXA_PENTE_PADRAO, rng)
	end
	return ItensChao.criarEm((ponto :: BasePart).Position, sorteio.id, sorteio.qtd, { ponto = ponto, pente = pente })
		~= nil
end

agendarReposicao = function(ponto: Instance)
	task.delay(Cfg.reposicao, function()
		if ponto.Parent == nil then
			return
		end
		if not sortearPonto(ponto) then
			agendarReposicao(ponto) -- não saiu nada: tenta de novo daqui a outra reposição
		end
	end)
end

-- Monta o modelo do item (ainda sem pai), registra e agenda o sumiço. nil se o id não tem modelo.
local function montar(id: string, qtd: number, opcoes: Opcoes?): Model?
	local ok, modelo = pcall(ItemModelo.criar, id, "chao")
	if not ok or not modelo then
		warn("[ItensChao] sem modelo para " .. tostring(id) .. ": " .. tostring(modelo))
		return nil
	end
	local largado = opcoes ~= nil and opcoes.largado == true
	modelo:SetAttribute("Item", id)
	modelo:SetAttribute("Qtd", qtd)
	modelo:SetAttribute("Largado", largado)
	if opcoes and opcoes.pente then
		modelo:SetAttribute("Pente", opcoes.pente)
	end
	CollectionService:AddTag(modelo, TAG)

	registro[modelo] = { t = os.clock(), id = id, largado = largado, ponto = if opcoes then opcoes.ponto else nil }
	total += 1
	modelo.Destroying:Connect(function()
		if registro[modelo] then
			registro[modelo] = nil
			total -= 1
		end
	end)
	if largado then
		task.delay(Cfg.largadoDuracao, function()
			if modelo.Parent then
				modelo:Destroy()
			end
		end)
	end
	return modelo
end

-- Passou de `maxItens` vivos: some o largado mais antigo (item de ponto nunca sai por limite).
local function aplicarLimite()
	if total <= Cfg.maxItens then
		return
	end
	local lista = {}
	for modelo, r in registro do
		table.insert(lista, { t = r.t, id = modelo, largado = r.largado })
	end
	for _, modelo in RegrasChao.removerExcedente(lista, Cfg.maxItens) do
		(modelo :: Instance):Destroy()
	end
end

local function poseFinal(id: string, chao: Vector3): (CFrame, number)
	local repouso = ItemModelo.repouso(id)
	local yaw = aleatorio:NextNumber(0, 2 * math.pi)
	-- o yaw gira em torno do eixo vertical do mundo, depois de o item deitar (giro)
	local cf = CFrame.new(chao + Vector3.new(0, repouso.altura, 0)) * CFrame.Angles(0, yaw, 0) * repouso.giro
	return cf, repouso.altura
end

-- Sem arremesso: assenta no chão achado por raycast para baixo. Item de ponto: raio curto, e sem acerto fica onde está.
function ItensChao.criarEm(posicao: Vector3, id: string, qtd: number, opcoes: Opcoes?): Model?
	if Itens.itens[id] == nil or qtd < 1 then
		warn("[ItensChao] criarEm: item inválido " .. tostring(id) .. " x" .. tostring(qtd))
		return nil
	end
	local chao: Vector3?
	if opcoes and opcoes.ponto then
		chao = chaoSob(posicao, Cfg.alturaCastPonto) or posicao
	else
		chao = chaoSob(posicao + Vector3.new(0, 1, 0), QUEDA_MAXIMA)
		if not chao then
			warn(string.format("[ItensChao] sem chão sob %s: %s descartado", tostring(posicao), id))
			return nil
		end
	end
	local modelo = montar(id, qtd, opcoes)
	if not modelo then
		return nil
	end
	modelo:PivotTo((poseFinal(id, chao)))
	modelo.Parent = pasta()
	if opcoes and opcoes.largado then
		aplicarLimite()
	end
	return modelo
end

-- Som da queda (docs/som.md §5.4) -------------------------------------------------------------------------------------

-- Item que pousa faz barulho onde cai (distração): nível da classe + 10·log10(altura/alturaRef). `fonte` = quem largou/jogou.
local function somDeQueda(id: string, posicao: Vector3, altura: number, fonte: Player?)
	if not CfgSom.queda.ligado then
		return
	end
	local Ruido = servico("Ruido")
	if not Ruido then
		return
	end
	local def = Itens.itens[id]
	local classe = (def and def.classeQueda) or (def and CfgSom.queda.porTipo[def.tipo]) or CfgSom.queda.padrao
	local nivel, perfil = Som.nivelQueda(classe, altura)
	local c = Som.compor({ { nome = "itemCaiu", nivel = nivel, perfil = perfil } })
	Ruido.emitirSom({
		posicao = posicao,
		bandas = c.bandas,
		chao = c.chao,
		tipo = "itemCaiu",
		dominante = classe,
		fonte = fonte,
	})
end

-- Arremesso -----------------------------------------------------------------------------------------------------

local function animar(dt: number)
	local i = 1
	while i <= #voando do
		local v = voando[i]
		if v.modelo.Parent == nil then
			table.remove(voando, i)
			continue
		end
		v.t += dt
		if v.t >= v.duracao then
			v.modelo:PivotTo(v.final)
			table.remove(voando, i)
			if v.aoPousar then
				task.spawn(v.aoPousar)
			end
			continue
		end
		local f = v.t / v.passo
		local a = math.floor(f)
		local p1 = v.pontos[a + 1]
		local p2 = v.pontos[a + 2] or p1
		local progresso = v.t / v.duracao
		local pos = p1:Lerp(p2, f - a) + Vector3.new(0, v.altura * progresso, 0)
		-- o giro zera até o pouso, para o item chegar na pose de repouso sem salto
		local giro = CFrame.fromAxisAngle(v.eixo, v.giro * (v.duracao - v.t)) * v.rotFinal
		v.modelo:PivotTo(CFrame.new(pos) * giro)
		i += 1
	end
	if #voando == 0 and conexao then
		conexao:Disconnect()
		conexao = nil
	end
end

-- Lança o modelo (já com pai, registrado) de `origem` com `velocidade`.
-- `fonte` (opcional): quem lançou; `somAoPousar` liga o som da queda (a morte limita quantos itens fazem som).
local function arremessar(
	modelo: Model,
	id: string,
	origem: Vector3,
	velocidade: Vector3,
	fonte: Player?,
	somAoPousar: boolean?
)
	local a = Cfg.arremesso
	local res = Arremesso.simular(tabela(origem), tabela(velocidade), workspace.Gravity, a.passo, a.maxPassos, raio)
	local pontos: { Vector3 } = {}
	for _, p in res.pontos do
		table.insert(pontos, v3(p))
	end
	local fim: Vector3
	if res.tocouChao then
		fim = v3(res.repouso)
	else
		local chao = chaoSob(v3(res.repouso) + Vector3.new(0, 0.5, 0), QUEDA_MAXIMA)
		if not chao then
			warn("[ItensChao] arremesso sem chão: " .. id .. " descartado")
			modelo:Destroy()
			return
		end
		fim = chao
		table.insert(pontos, chao)
	end
	local final, altura = poseFinal(id, fim)
	local duracao = (#pontos - 1) * a.passo
	local aoPousar: (() -> ())? = nil
	if somAoPousar then
		local topo = fim.Y
		for _, p in pontos do
			topo = math.max(topo, p.Y)
		end
		local alturaQueda = topo - fim.Y
		aoPousar = function()
			somDeQueda(id, fim, alturaQueda, fonte)
		end
	end
	if duracao <= 0 then
		modelo:PivotTo(final)
		if aoPousar then
			task.spawn(aoPousar)
		end
		return
	end
	local eixo = Vector3.new(aleatorio:NextNumber(-1, 1), aleatorio:NextNumber(-1, 1), aleatorio:NextNumber(-1, 1))
	if eixo.Magnitude < 0.1 then
		eixo = Vector3.xAxis
	end
	table.insert(voando, {
		modelo = modelo,
		pontos = pontos,
		passo = a.passo,
		duracao = duracao,
		t = 0,
		altura = altura,
		rotFinal = final.Rotation,
		final = final,
		eixo = eixo.Unit,
		giro = aleatorio:NextNumber(-a.giroMax, a.giroMax),
		aoPousar = aoPousar,
	})
	modelo:PivotTo(CFrame.new(pontos[1]) * final.Rotation)
	if not conexao then
		conexao = RunService.Heartbeat:Connect(animar)
	end
end

-- Ponto de saída de um arremesso: se há parede entre `base` e `ideal`, sai colado nela.
local function saida(base: Vector3, ideal: Vector3): Vector3
	local acerto = workspace:Raycast(base, ideal - base, parametros())
	return if acerto then acerto.Position + acerto.Normal * 0.3 else ideal
end

local function lancar(
	id: string,
	qtd: number,
	base: Vector3,
	origem: Vector3,
	velocidade: Vector3,
	pente: number?,
	fonte: Player?,
	somAoPousar: boolean?
)
	if Itens.itens[id] == nil or qtd < 1 then
		warn("[ItensChao] lançar: item inválido " .. tostring(id) .. " x" .. tostring(qtd))
		return
	end
	local modelo = montar(id, qtd, { largado = true, pente = pente })
	if not modelo then
		return
	end
	local inicio = saida(base, origem)
	modelo:PivotTo(CFrame.new(inicio))
	modelo.Parent = pasta()
	aplicarLimite()
	arremessar(modelo, id, inicio, velocidade, fonte, somAoPousar)
end

-- Chamado por Inventario.largar. `pente` (opcional): balas no pente da arma de fogo que sai, guardadas no item.
function ItensChao.largar(jogador: Player, id: string, qtd: number, pente: number?)
	local hrp = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local frente = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	frente = if frente.Magnitude > 0.01 then frente.Unit else Vector3.zAxis
	local base = hrp.Position + Vector3.new(0, ALTURA_LARGAR, 0)
	local a = Cfg.arremesso
	lancar(
		id,
		qtd,
		base,
		base + frente * FRENTE_LARGAR,
		frente * a.frente + Vector3.new(0, a.cima, 0),
		pente,
		jogador,
		true
	)
end

-- Morte: um item por entrada, em leque. `itens` = { {id, qtd, pente?} }. `fonte` (opcional) = quem morreu: os primeiros
-- Config/Som.queda.maxPorMorte itens fazem o som da queda (docs/som.md §5.4).
function ItensChao.espalhar(posicao: Vector3, itens: { { id: string, qtd: number, pente: number? } }, fonte: Player?)
	local velocidades = RegrasChao.velocidadesEspalhar(#itens, rng, Cfg.espalhar)
	local base = posicao + Vector3.new(0, 1, 0)
	for i, item in itens do
		local v = velocidades[i]
		if v then
			lancar(item.id, item.qtd, posicao, base, v3(v), item.pente, fonte, i <= CfgSom.queda.maxPorMorte)
		end
	end
end

function ItensChao.contar(): number
	return total
end

-- Coleta ---------------------------------------------------------------------------------------------------------

local function posicaoDe(item: Model): Vector3
	return if item.PrimaryPart then item.PrimaryPart.Position else item:GetPivot().Position
end

local function pegar(jogador: Player, item: any)
	if typeof(item) ~= "Instance" or not item:IsA("Model") then
		return
	end
	local r = registro[item]
	if not r or item.Parent ~= pasta() then
		return
	end
	local personagem = jogador.Character
	local hrp = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local Vida = servico("Vida")
	if Vida then
		if not Vida.estaVivo(jogador) then
			return
		end
	else
		local humanoid = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
	end
	if (hrp.Position - posicaoDe(item)).Magnitude > Cfg.alcance * FOLGA_ALCANCE then
		return
	end
	local Inventario = servico("Inventario")
	local qtd = item:GetAttribute("Qtd")
	if not Inventario or type(qtd) ~= "number" or qtd < 1 then
		return
	end

	local n = math.min(qtd, Inventario.espaco(jogador, r.id))
	if n < 1 then
		aviso(jogador, "Inventário cheio")
		return
	end
	local pente = item:GetAttribute("Pente")
	local sobra = Inventario.dar(jogador, r.id, n, if type(pente) == "number" then pente else nil)
	local levou = n - sobra
	if levou < 1 then
		aviso(jogador, "Inventário cheio")
		return
	end

	local Sons = servico("Sons")
	if Sons then
		Sons.tocar("AbrirCaixa", posicaoDe(item)) -- som provisório (pendência: som próprio de pegar)
	end
	if levou >= qtd then
		local ponto = r.ponto
		item:Destroy()
		if ponto then
			agendarReposicao(ponto)
		end
	else
		item:SetAttribute("Qtd", qtd - levou)
	end
end

-- Início e testes -------------------------------------------------------------------------------------------------

local function montarPontos()
	local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
	local pontos = mapa and mapa:WaitForChild("Pontos", ESPERA_MAPA)
	if not pontos then
		warn("[ItensChao] workspace.Mapa.Pontos não existe: nenhum item de ponto criado")
		return
	end
	local itens, validos = 0, 0
	local visitados = 0
	for _, ponto in pontos:GetChildren() do
		visitados += 1
		if visitados % LOTE_PONTOS == 0 then
			task.wait()
		end
		local nomeTabela = ponto:GetAttribute("Tabela")
		if ponto:IsA("BasePart") and type(nomeTabela) == "string" and Itens.tabelas[nomeTabela] then
			validos += 1
			if sortearPonto(ponto) then
				itens += 1
			end
		end
	end
	print(string.format("[ItensChao] %d itens em %d pontos", itens, validos))
end

local function registrarTestes()
	local ok, Teste = pcall(require, script.Parent.Teste)
	if not ok then
		return
	end
	Teste.registrar("chao", function()
		local dePonto, largados, voandoAgora = 0, 0, #voando
		for _, r in registro do
			if r.largado then
				largados += 1
			elseif r.ponto then
				dePonto += 1
			end
		end
		local texto = string.format(
			"%d itens no chão: %d de ponto, %d largados, %d em voo",
			total,
			dePonto,
			largados,
			voandoAgora
		)
		print("[ItensChao] " .. texto)
		return texto
	end)
	Teste.registrar("soltar", function(jogador: Player, id: string, qtd: number?)
		local hrp = jogador and jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return "sem personagem"
		end
		if Itens.itens[id] == nil then
			return "item desconhecido: " .. tostring(id)
		end
		local modelo = ItensChao.criarEm(hrp.Position + hrp.CFrame.LookVector * 4, id, qtd or 1, { largado = true })
		return if modelo then string.format("%s x%d no chão", id, qtd or 1) else "falhou (sem chão ou sem modelo)"
	end)
	Teste.registrar("limparchao", function()
		local n = total
		for _, filho in pasta():GetChildren() do
			filho:Destroy()
		end
		table.clear(voando)
		return string.format("%d itens removidos", n)
	end)
end

function ItensChao.iniciar()
	pasta()
	Rede.evento("PegarDoChao").OnServerEvent:Connect(function(jogador: Player, item: any)
		if Limite.ok(jogador, "PegarDoChao", 0.15) then
			pegar(jogador, item)
		end
	end)
	registrarTestes()
	task.spawn(montarPontos)
end

return ItensChao
