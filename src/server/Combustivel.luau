-- Combustivel (servidor): posto (bombas do mapa), mangueira, recipientes (galão/garrafa) e a mão que segura tudo isso.
-- Contrato: docs/combustivel.md §5 (mangueira) e §6 (posto, mão, itens). Números em Config/Combustivel.
-- A física da mangueira é do cliente (Verlet); aqui só o estado autoritativo em workspace.Mangueiras/<UserId>.
-- O carro (tanque, tampa, prompt "Abastecer") é de Veiculos/VeiculoModelo; este módulo só liga o Triggered da Tampa.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Config:WaitForChild("Combustivel"))
local CfgSom = require(Config:WaitForChild("Som"))
local CfgItens = require(Config:WaitForChild("Itens"))
local Limite = require(script.Parent.Limite)
local Inventario = require(script.Parent.Inventario)

local Combustivel = {}

-- Folga sobre os alcances de prompt para a latência (mesma ideia de Loot.FOLGA_ALCANCE).
local FOLGA = 1.25
local ESPERA_MAPA = 15 -- s esperando workspace.Mapa aparecer
local LOTE_VARREDURA = 500 -- descendentes visitados antes de ceder (task.wait) ao servidor
local TOLERANCIA_MEDIDA = 0.05 -- studs: comparar Size/posição das peças da bomba
local ESPACO_MINIMO = 0.25 -- L: abaixo disso o tanque conta como cheio (recusa plugar/despejar)
local PASSO_DESPEJO = 0.1 -- s entre checagens durante o despejo
-- INTEGRACAO: mover para Config/Combustivel (S1) se o Opus quiser; por ora valores do contrato (§5.2, §6.5).
local INTERVALO_RUIDO = 2 -- s entre ruídos 'abastecer'
local DESPEJAR_GARRAFA = 1.0 -- s travado despejando uma garrafa (galão usa Cfg.despejarSegundos)
local DB_PADRAO = { abastecer = 50, encher = 45, despejar = 40 } -- só se Config/Som ainda não tiver a ação

-- Medidas da bomba (docs/combustivel.md §6.2), locais à origem do gerador (centro da pegada no piso).
local BASE_TAMANHO = Vector3.new(2.4, 0.35, 1.8)
local BASE_ALTURA_CENTRO = 0.175
local CORPO_TAMANHO = Vector3.new(2.0, 4.85, 1.5)
local BOCAL_LOCAL = Vector3.new(1.15, 3.0, -0.5)
local ESTATICAS_LOCAL = { Vector3.new(1.15, 1.95, -0.5), Vector3.new(1.15, 0.9, -0.1) } -- mangueira e bico do mapa

type Estatica = { peca: BasePart, transparencia: number }
type Bomba = {
	modelo: Model,
	id: string,
	origem: CFrame,
	corpo: BasePart,
	bocal: Attachment,
	emUso: Player?,
	estaticas: { Estatica },
}
type Mangueira = {
	jogador: Player,
	bomba: Bomba,
	pasta: Folder,
	estado: string, -- "mao" | "plugada"
	carro: Model?,
	tampa: BasePart?,
	porta: Attachment?,
	fluxo: boolean,
	ultimoRuido: number,
}
type Mao = { slot: number, id: string }

local bombas: { Bomba } = {}
local mangueiras: { [Player]: Mangueira } = {}
local plugadas: { [Model]: Player } = setmetatable({}, { __mode = "k" }) :: any -- carro -> dono da mangueira plugada
local maos: { [Player]: Mao } = {}
local travas: { [Player]: number } = {} -- ficha do despejo em andamento; mudar a ficha cancela o laço
local trocando: { [Player]: boolean } = {} -- troca atômica em curso: o aoMudar não deve limpar a mão
local tampasLigadas: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local pastaMangueiras: Folder? = nil
local fichaDespejo = 0

-- Outros serviços sob demanda: se um falhar ao carregar, o posto continua (e avisa uma vez).
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
			warn("[Combustivel] serviço indisponível: " .. nome .. " " .. tostring(resultado))
			m = false
		end
		servicos[nome] = m
	end
	return m or nil
end

-- Canal de aviso que o resto do código já usa (Inventario, Loot, Veiculos): evento "Aviso" da Rede.
local function aviso(jogador: Player, texto: string)
	if jogador.Parent then
		Rede.evento("Aviso"):FireClient(jogador, texto)
	end
end

local function dbDe(acao: string): number
	return CfgSom.acoes[acao] or DB_PADRAO[acao] or 50
end

local function ruido(acao: string, posicao: Vector3, fonte: Player)
	local Ruido = servico("Ruido")
	if Ruido then
		Ruido.emitirAcao(acao, posicao, fonte)
	end
end

local function som(nome: string, onde: BasePart | Vector3, db: number?)
	local Sons = servico("Sons")
	if Sons then
		pcall(Sons.tocar, nome, onde, if db then { db = db } else nil)
	end
end

local function tamanhoPerto(a: Vector3, b: Vector3): boolean
	return math.abs(a.X - b.X) <= TOLERANCIA_MEDIDA
		and math.abs(a.Y - b.Y) <= TOLERANCIA_MEDIDA
		and math.abs(a.Z - b.Z) <= TOLERANCIA_MEDIDA
end

-- Jogador ----------------------------------------------------------------------------------------------------

-- Personagem, raiz e humanoide se o jogador está vivo; senão nil.
local function vivo(jogador: Player): (Model?, BasePart?, Humanoid?)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not (personagem and raiz and raiz:IsA("BasePart") and humanoide) or humanoide.Health <= 0 then
		return nil, nil, nil
	end
	if jogador:GetAttribute("Morto") == true then
		return nil, nil, nil
	end
	return personagem, raiz, humanoide
end

local function sentado(humanoide: Humanoid): boolean
	return humanoide.SeatPart ~= nil
end

local function armado(jogador: Player): boolean
	local arma = jogador:GetAttribute("ArmaEquipada")
	return type(arma) == "string" and arma ~= ""
end

-- Carro -------------------------------------------------------------------------------------------------------

local function motorLigado(carro: Model): boolean
	local V = servico("Veiculos")
	if V and V.motorLigado then
		local ok, r = pcall(V.motorLigado, carro)
		if ok then
			return r == true
		end
	end
	return carro:GetAttribute("MotorLigado") == true
end

local function queimado(carro: Model): boolean
	local V = servico("Veiculos")
	local e = V and V.estadoDe and V.estadoDe(carro)
	return e ~= nil and e.queimado == true
end

-- false: o carro não está (mais) registrado em Veiculos (removido/destruído).
local function carroVivo(carro: Model): boolean
	if not carro.Parent then
		return false
	end
	local V = servico("Veiculos")
	if V and V.estadoDe then
		return V.estadoDe(carro) ~= nil
	end
	return true
end

local function litrosDe(carro: Model): (number, number)
	local V = servico("Veiculos")
	if V and V.combustivelDe then
		local ok, litros, tanque = pcall(V.combustivelDe, carro)
		if ok and type(litros) == "number" and type(tanque) == "number" then
			return litros, tanque
		end
	end
	return carro:GetAttribute("Combustivel") or 0, carro:GetAttribute("Tanque") or 0
end

local function encherCarro(carro: Model, litros: number): number
	local V = servico("Veiculos")
	if V and V.encher then
		return V.encher(carro, litros) or 0
	end
	warn("[Combustivel] Veiculos.encher indisponível")
	return 0
end

-- O model que Veiculos conhece (chave de dados) a partir de uma peça: sobe até achar um com estado.
local function carroDe(peca: Instance): Model?
	local primeiro = peca:FindFirstAncestorOfClass("Model")
	local atual = primeiro
	local V = servico("Veiculos")
	while atual do
		if V and V.estadoDe and V.estadoDe(atual) ~= nil then
			return atual
		end
		local acima = atual.Parent
		atual = if acima then acima:FindFirstAncestorOfClass("Model") else nil
	end
	return primeiro
end

local function tampaDe(carro: Model): BasePart?
	for _, p in CollectionService:GetTagged("Tampa") do
		if p:IsA("BasePart") and p:IsDescendantOf(carro) then
			return p
		end
	end
	return nil
end

-- Motivo de recusa comum a plugar e despejar (nil = pode).
local function recusaCarro(carro: Model): string?
	if queimado(carro) then
		return "Carro queimado"
	end
	if motorLigado(carro) then
		return "Desligue o motor"
	end
	local litros, tanque = litrosDe(carro)
	if tanque - litros < ESPACO_MINIMO then
		return "Tanque cheio"
	end
	return nil
end

-- Mão ----------------------------------------------------------------------------------------------------------
-- O modelo na mão é do ItemNaMao (fonte "uso", docs/itens-no-mundo.md §3-D); aqui só se decide qual id mostrar.

-- Modelo do recipiente na mão direita; id nil limpa a fonte. Falha em silêncio se o serviço não existe.
local function modeloNaMao(jogador: Player, id: string?)
	local ItemNaMao = servico("ItemNaMao")
	if ItemNaMao then
		pcall(ItemNaMao.definir, jogador, "uso", id)
	end
end

local function limparMao(jogador: Player)
	local mao = maos[jogador]
	if mao then
		maos[jogador] = nil
		modeloNaMao(jogador, nil)
	end
	if jogador.Parent and jogador:GetAttribute("RecipienteSlot") ~= nil then
		jogador:SetAttribute("RecipienteSlot", nil)
	end
end

-- Põe o recipiente do slot na mão (troca o que já estava). O chamador já validou.
local function definirMao(jogador: Player, slot: number, id: string)
	maos[jogador] = { slot = slot, id = id }
	jogador:SetAttribute("RecipienteSlot", slot)
	modeloNaMao(jogador, id)
end

-- Comer/beber usa a mesma fonte "uso" e, ao terminar, apaga o modelo do recipiente: se a mão ainda deve ter o recipiente
-- e nenhum uso/despejo está em curso, reaplica (chamado a cada passo do laço de conferência).
local function reaplicarMaos()
	for jogador, mao in maos do
		if jogador:GetAttribute("Usando") ~= true then
			local personagem = jogador.Character
			if
				personagem
				and personagem:FindFirstChild("RightHand")
				and not personagem:FindFirstChild("ItemNaMao")
				and not armado(jogador)
			then
				modeloNaMao(jogador, mao.id)
			end
		end
	end
end

-- Depois de uma troca atômica do recipiente que estava na mão: se o slot não tem mais o mesmo item, a mão segue o item
-- novo (no mesmo slot ou no primeiro que o tiver); se ele sumiu, a mão esvazia.
local function seguirTroca(jogador: Player, mao: Mao?, idNovo: string)
	if not mao or maos[jogador] ~= mao then
		return
	end
	local p = Inventario.slot(jogador, mao.slot)
	if p and p.id == mao.id then
		return -- pilha: ainda sobrou um do tipo antigo no slot
	end
	if p and p.id == idNovo then
		definirMao(jogador, mao.slot, idNovo)
		return
	end
	for s = 1, CfgItens.slots do
		local q = Inventario.slot(jogador, s)
		if q and q.id == idNovo then
			definirMao(jogador, s, idNovo)
			return
		end
	end
	limparMao(jogador)
end

-- Troca atômica protegida do aoMudar (que limparia a mão ao ver o slot mudar). true se trocou.
local function trocar(jogador: Player, deId: string, paraId: string): boolean
	trocando[jogador] = true
	local ok, resultado = pcall(Inventario.trocar, jogador, deId, paraId)
	trocando[jogador] = nil
	if not ok then
		warn("[Combustivel] Inventario.trocar falhou: " .. tostring(resultado))
		return false
	end
	return resultado == true
end

-- Mangueira ----------------------------------------------------------------------------------------------------

local function mostrarEstaticas(bomba: Bomba, visivel: boolean)
	for _, e in bomba.estaticas do
		if e.peca.Parent then
			e.peca.Transparency = if visivel then e.transparencia else 1
		end
	end
end

local function posicaoBocal(bomba: Bomba): Vector3
	return if bomba.corpo.Parent then bomba.bocal.WorldPosition else bomba.origem.Position
end

-- Guarda/solta a mangueira do jogador: apaga a pasta replicada, libera a bomba e o carro. `texto` vira aviso; `tocar` solta som.
local function guardarMangueira(m: Mangueira, texto: string?, tocar: boolean?)
	if mangueiras[m.jogador] ~= m then
		return
	end
	mangueiras[m.jogador] = nil
	local carro = m.carro
	if carro then
		if plugadas[carro] == m.jogador then
			plugadas[carro] = nil
		end
		if carro.Parent then
			carro:SetAttribute("Abastecendo", false)
		end
	end
	if m.bomba.emUso == m.jogador then
		m.bomba.emUso = nil
		mostrarEstaticas(m.bomba, true)
	end
	m.pasta:Destroy()
	if m.jogador.Parent then
		m.jogador:SetAttribute("Mangueira", false)
	end
	if texto then
		aviso(m.jogador, texto)
	end
	if tocar and m.bomba.corpo.Parent then
		som("MangueiraSolta", posicaoBocal(m.bomba), dbDe("abastecer"))
	end
end

local function criarMangueira(jogador: Player, bomba: Bomba): Mangueira
	local pasta = Instance.new("Folder")
	pasta.Name = tostring(jogador.UserId)
	pasta:SetAttribute("Dono", jogador.UserId)
	pasta:SetAttribute("Estado", "mao")
	pasta:SetAttribute("Comprimento", Cfg.mangueira.comprimento)
	pasta:SetAttribute("Fluxo", false)
	local bocal = Instance.new("ObjectValue")
	bocal.Name = "Bocal"
	bocal.Value = bomba.bocal
	bocal.Parent = pasta
	local destino = Instance.new("ObjectValue")
	destino.Name = "Destino"
	destino.Parent = pasta
	local m: Mangueira = {
		jogador = jogador,
		bomba = bomba,
		pasta = pasta,
		estado = "mao",
		carro = nil,
		tampa = nil,
		porta = nil,
		fluxo = false,
		ultimoRuido = 0,
	}
	mangueiras[jogador] = m
	bomba.emUso = jogador
	mostrarEstaticas(bomba, false)
	jogador:SetAttribute("Mangueira", true)
	pasta.Parent = pastaMangueiras
	return m
end

local function definirFluxo(m: Mangueira, fluxo: boolean)
	if m.fluxo ~= fluxo then
		m.fluxo = fluxo
		m.pasta:SetAttribute("Fluxo", fluxo)
	end
end

local function aoPegarMangueira(jogador: Player, bomba: Bomba)
	if not Limite.ok(jogador, "PegarMangueira", 0.25) then
		return
	end
	local _, raiz, humanoide = vivo(jogador)
	if not (raiz and humanoide) or sentado(humanoide) then
		return
	end
	if (raiz.Position - bomba.corpo.Position).Magnitude > Cfg.mangueira.alcanceBomba * FOLGA then
		return
	end
	local atual = mangueiras[jogador]
	if atual then
		if atual.bomba == bomba then
			guardarMangueira(atual, nil, true) -- mesmo prompt: "Guardar mangueira"
		else
			aviso(jogador, "Você já tem uma mangueira")
		end
		return
	end
	if bomba.emUso and bomba.emUso ~= jogador then
		aviso(jogador, "Bomba ocupada")
		return
	end
	if armado(jogador) then
		aviso(jogador, "Guarde a arma primeiro")
		return
	end
	limparMao(jogador) -- mão livre: o recipiente volta ao inventário (continua nele, só sai da mão)
	criarMangueira(jogador, bomba)
	som("MangueiraEncaixa", posicaoBocal(bomba), dbDe("abastecer"))
end

local function plugar(m: Mangueira, carro: Model, tampa: BasePart)
	local jogador = m.jogador
	local porta = tampa:FindFirstChild("PortaCombustivel")
	if not (porta and porta:IsA("Attachment")) then
		aviso(jogador, "Tampa sem encaixe")
		return
	end
	local recusa = recusaCarro(carro)
	if recusa then
		aviso(jogador, recusa)
		return
	end
	if plugadas[carro] ~= nil then
		aviso(jogador, "Já há uma mangueira neste carro")
		return
	end
	if
		(posicaoBocal(m.bomba) - porta.WorldPosition).Magnitude
		> Cfg.mangueira.comprimento + Cfg.mangueira.tolerancia
	then
		aviso(jogador, "Mangueira curta demais")
		return
	end
	m.estado = "plugada"
	m.carro = carro
	m.tampa = tampa
	m.porta = porta
	m.ultimoRuido = 0
	plugadas[carro] = jogador
	m.pasta:SetAttribute("Estado", "plugada")
	local destino = m.pasta:FindFirstChild("Destino")
	if destino and destino:IsA("ObjectValue") then
		destino.Value = porta
	end
	carro:SetAttribute("Abastecendo", true)
	definirFluxo(m, true)
	som("MangueiraEncaixa", tampa, dbDe("abastecer"))
end

local function desplugar(m: Mangueira)
	local carro = m.carro
	if carro then
		if plugadas[carro] == m.jogador then
			plugadas[carro] = nil
		end
		if carro.Parent then
			carro:SetAttribute("Abastecendo", false)
		end
		if m.tampa then
			som("MangueiraSolta", m.tampa, dbDe("abastecer"))
		end
	end
	m.estado = "mao"
	m.carro, m.tampa, m.porta = nil, nil, nil
	m.pasta:SetAttribute("Estado", "mao")
	local destino = m.pasta:FindFirstChild("Destino")
	if destino and destino:IsA("ObjectValue") then
		destino.Value = nil
	end
	definirFluxo(m, false)
end

-- Despejar um recipiente cheio no tanque --------------------------------------------------------------------

local function cancelarDespejo(jogador: Player)
	if travas[jogador] then
		fichaDespejo += 1 -- invalida o laço em andamento
		travas[jogador] = nil
		if jogador.Parent then
			jogador:SetAttribute("Usando", false)
		end
	end
end

-- Chamado pelo prompt da Tampa (ligado aqui mesmo) com recipiente cheio na mão.
function Combustivel.aoDespejar(jogador: Player, modelo: Model)
	local mao = maos[jogador]
	local def = mao and Cfg.recipientes[mao.id]
	if not (mao and def and def.despeja and def.litros) then
		aviso(jogador, "Segure um recipiente cheio")
		return
	end
	if travas[jogador] or jogador:GetAttribute("Usando") == true then
		return
	end
	local tampa = tampaDe(modelo)
	local _, raiz = vivo(jogador)
	if not (tampa and raiz) then
		return
	end
	if (raiz.Position - tampa.Position).Magnitude > Cfg.mangueira.alcanceTampa * FOLGA then
		return
	end
	local recusa = recusaCarro(modelo)
	if recusa then
		aviso(jogador, recusa)
		return
	end

	fichaDespejo += 1
	local ficha = fichaDespejo
	travas[jogador] = ficha
	jogador:SetAttribute("Usando", true)
	ruido("despejar", tampa.Position, jogador)
	som("Abastecendo", tampa, dbDe("despejar"))
	local duracao = if string.find(mao.id, "garrafa", 1, true) then DESPEJAR_GARRAFA else Cfg.despejarSegundos
	local idCheio, idVazio, litros = mao.id, def.despeja, def.litros

	task.spawn(function()
		local inicio = os.clock()
		local motivo: string? = nil
		repeat
			task.wait(PASSO_DESPEJO)
			if travas[jogador] ~= ficha then
				return -- cancelado por fora (morte, saída): quem cancelou já limpou
			end
			local _, r = vivo(jogador)
			local p = Inventario.slot(jogador, mao.slot)
			if
				not r
				or maos[jogador] ~= mao
				or not p
				or p.id ~= idCheio
				or not modelo.Parent
				or motorLigado(modelo)
			then
				motivo = "Despejo cancelado"
			elseif (r.Position - tampa.Position).Magnitude > Cfg.mangueira.alcanceTampa * FOLGA then
				motivo = "Longe demais do tanque"
			end
		until motivo ~= nil or os.clock() - inicio >= duracao
		travas[jogador] = nil
		if jogador.Parent then
			jogador:SetAttribute("Usando", false)
		end
		if motivo then
			aviso(jogador, motivo)
			return
		end
		local recusaFinal = recusaCarro(modelo)
		if recusaFinal then
			aviso(jogador, recusaFinal)
			return
		end
		if not trocar(jogador, idCheio, idVazio) then
			aviso(jogador, "Não foi possível despejar")
			return
		end
		encherCarro(modelo, litros) -- a sobra além da capacidade se perde (default do contrato)
		seguirTroca(jogador, mao, idVazio)
	end)
end

-- Tampa do carro ----------------------------------------------------------------------------------------------

local function aoTampa(jogador: Player, tampa: BasePart)
	if not Limite.ok(jogador, "TampaCombustivel", 0.25) then
		return
	end
	local carro = carroDe(tampa)
	local _, raiz = vivo(jogador)
	if not (carro and raiz) then
		return
	end
	if (raiz.Position - tampa.Position).Magnitude > Cfg.mangueira.alcanceTampa * FOLGA then
		return
	end
	local m = mangueiras[jogador]
	if m then
		if m.estado == "mao" then
			plugar(m, carro, tampa)
		elseif m.carro == carro then
			desplugar(m)
		else
			aviso(jogador, "Mangueira plugada em outro carro")
		end
		return
	end
	local mao = maos[jogador]
	local def = mao and Cfg.recipientes[mao.id]
	if def and def.despeja then
		Combustivel.aoDespejar(jogador, carro)
		return
	end
	aviso(jogador, "Sem mangueira nem recipiente cheio")
end

local function ligarTampa(tampa: Instance)
	if not tampa:IsA("BasePart") or tampasLigadas[tampa] then
		return
	end
	tampasLigadas[tampa] = true
	task.spawn(function()
		local prompt = tampa:WaitForChild("Abastecer", 5)
		if not (prompt and prompt:IsA("ProximityPrompt")) then
			warn("[Combustivel] Tampa sem prompt 'Abastecer': " .. tampa:GetFullName())
			return
		end
		prompt.Triggered:Connect(function(jogador: Player)
			aoTampa(jogador, tampa :: BasePart)
		end)
	end)
end

-- Bomba -------------------------------------------------------------------------------------------------------

local function aoEncherRecipiente(jogador: Player, bomba: Bomba)
	if not Limite.ok(jogador, "EncherRecipiente", 0.5) then
		return
	end
	local _, raiz = vivo(jogador)
	if not raiz then
		return
	end
	if (raiz.Position - bomba.corpo.Position).Magnitude > Cfg.mangueira.alcanceBomba * FOLGA then
		return
	end
	if jogador:GetAttribute("Usando") == true then
		return
	end
	-- prefere o vazio da mão, depois galão vazio, depois garrafa vazia
	local mao = maos[jogador]
	local deId: string? = nil
	if mao then
		local def = Cfg.recipientes[mao.id]
		local p = Inventario.slot(jogador, mao.slot)
		if def and def.enche and p and p.id == mao.id then
			deId = mao.id
		end
	end
	if not deId then
		for _, id in { "galaoVazio", "garrafaVazia" } do
			if Inventario.contar(jogador, id) > 0 then
				deId = id
				break
			end
		end
	end
	if not deId then
		aviso(jogador, "Sem recipiente vazio")
		return
	end
	local paraId = Cfg.recipientes[deId].enche
	local naMao = if mao and mao.id == deId then mao else nil
	if not trocar(jogador, deId, paraId) then
		aviso(jogador, "Inventário cheio")
		return
	end
	seguirTroca(jogador, naMao, paraId)
	local pos = posicaoBocal(bomba)
	ruido("encher", pos, jogador)
	som("Abastecendo", pos, dbDe("encher"))
end

local function criarPrompt(
	pai: BasePart,
	nome: string,
	texto: string,
	tecla: Enum.KeyCode,
	espera: number
): ProximityPrompt
	local antigo = pai:FindFirstChild(nome)
	if antigo then
		antigo:Destroy()
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = nome
	p.ActionText = texto
	p.ObjectText = "Bomba de combustível"
	p.KeyboardKeyCode = tecla
	p.HoldDuration = espera
	p.MaxActivationDistance = Cfg.mangueira.alcanceBomba
	p.RequiresLineOfSight = false
	p.Parent = pai
	return p
end

-- Monta a bomba a partir do Model do mapa. nil (com aviso) se não achar a base de concreto ou o corpo.
local function montarBomba(modelo: Model, numero: number): Bomba?
	local base: BasePart? = nil
	local corpo: BasePart? = nil
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			if not base and tamanhoPerto(d.Size, BASE_TAMANHO) then
				base = d
			elseif not corpo and tamanhoPerto(d.Size, CORPO_TAMANHO) then
				corpo = d
			end
		end
	end
	if not (base and corpo) then
		warn("[Combustivel] bomba sem base/corpo reconhecíveis: " .. modelo:GetFullName())
		return nil
	end
	local origem = base.CFrame * CFrame.new(0, -BASE_ALTURA_CENTRO, 0)

	local bocal = Instance.new("Attachment")
	bocal.Name = "Bocal"
	bocal.CFrame = corpo.CFrame:ToObjectSpace(CFrame.new(origem * BOCAL_LOCAL)) -- orientação do mundo: +Y para cima
	bocal.Parent = corpo

	local estaticas: { Estatica } = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d ~= base and d ~= corpo then
			local local3 = origem:PointToObjectSpace(d.Position)
			for _, alvo in ESTATICAS_LOCAL do
				if tamanhoPerto(local3, alvo) then
					table.insert(estaticas, { peca = d, transparencia = d.Transparency })
					break
				end
			end
		end
	end

	local id = string.format("bomba_%d", numero)
	modelo:SetAttribute("BombaId", id)
	local bomba: Bomba = {
		modelo = modelo,
		id = id,
		origem = origem,
		corpo = corpo,
		bocal = bocal,
		emUso = nil,
		estaticas = estaticas,
	}
	criarPrompt(corpo, "PegarMangueira", "Pegar mangueira", Enum.KeyCode.E, 0).Triggered:Connect(
		function(jogador: Player)
			aoPegarMangueira(jogador, bomba)
		end
	)
	local encher = criarPrompt(corpo, "EncherRecipiente", "Encher recipiente", Enum.KeyCode.F, Cfg.encherSegundos)
	encher.UIOffset = Vector2.new(0, -70) -- não sobrepor o prompt de pegar mangueira
	encher.Triggered:Connect(function(jogador: Player)
		aoEncherRecipiente(jogador, bomba)
	end)
	return bomba
end

-- Espera o mapa e varre Construcoes por modelos `Movel == "bomba_combustivel"` (mesmo padrão de Loot.montarCompartimentos).
local function montarBombas()
	local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
	local construcoes = mapa and mapa:WaitForChild("Construcoes", ESPERA_MAPA)
	if not construcoes then
		warn("[Combustivel] workspace.Mapa.Construcoes não existe: nenhuma bomba criada")
		return
	end
	local achados: { Model } = {}
	local visitados = 0
	for _, instancia in construcoes:GetDescendants() do
		visitados += 1
		if visitados % LOTE_VARREDURA == 0 then
			task.wait()
		end
		if instancia:IsA("Model") and instancia:GetAttribute("Movel") == "bomba_combustivel" then
			table.insert(achados, instancia)
		end
	end
	for i, modelo in achados do
		local bomba = montarBomba(modelo, i)
		if bomba then
			table.insert(bombas, bomba)
		end
	end
	print(string.format("[Combustivel] %d bombas de %d modelos (visitados %d)", #bombas, #achados, visitados))
end

-- Verificação periódica ------------------------------------------------------------------------------------------

-- Uma passada sobre todas as mangueiras: limpeza, distância, fluxo e ruído.
local function conferir(dt: number)
	reaplicarMaos()
	local agora = os.clock()
	for _, m in table.clone(mangueiras) do
		local jogador = m.jogador
		local _, raiz, humanoide = vivo(jogador)
		local carro = m.carro
		local ponta: Vector3? = nil
		local motivo: string? = nil
		if not (raiz and humanoide) or jogador.Parent == nil or sentado(humanoide) then
			motivo = "" -- sem aviso: morreu, saiu ou sentou
		elseif not m.bomba.corpo:IsDescendantOf(workspace) then
			motivo = "A mangueira soltou"
		elseif m.estado == "plugada" then
			-- carro sumiu/queimou, ou o motor ligou com a mangueira plugada: retrai
			if not (carro and m.tampa and m.porta) or not carroVivo(carro) or queimado(carro) or motorLigado(carro) then
				motivo = "A mangueira soltou"
			else
				ponta = m.porta.WorldPosition
			end
		else
			local mao = jogador.Character and jogador.Character:FindFirstChild("RightHand")
			ponta = if mao and mao:IsA("BasePart") then mao.Position else raiz.Position
		end
		if motivo == nil and ponta then
			local limite = Cfg.mangueira.comprimento + Cfg.mangueira.tolerancia
			if (posicaoBocal(m.bomba) - ponta).Magnitude > limite then
				motivo = "A mangueira soltou"
			end
		end
		if motivo ~= nil then
			guardarMangueira(m, if motivo ~= "" then motivo else nil, jogador.Parent ~= nil and motivo ~= "")
		elseif m.estado == "plugada" and m.fluxo and carro and m.tampa then
			local pedido = Cfg.mangueira.vazaoLps * dt
			local aceito = encherCarro(carro, pedido)
			local litros, tanque = litrosDe(carro)
			if aceito < pedido - 1e-4 or tanque - litros < 0.01 then
				definirFluxo(m, false) -- tanque cheio: a mangueira continua plugada
			elseif agora - m.ultimoRuido >= INTERVALO_RUIDO then
				m.ultimoRuido = agora
				ruido("abastecer", m.tampa.Position, jogador)
				som("Abastecendo", m.tampa, dbDe("abastecer"))
			end
		end
	end
end

-- Ciclo de vida do jogador ------------------------------------------------------------------------------------

local function limparTudo(jogador: Player)
	local m = mangueiras[jogador]
	if m then
		guardarMangueira(m, nil, false)
	end
	limparMao(jogador)
	cancelarDespejo(jogador)
	trocando[jogador] = nil
end

local function conectarPersonagem(jogador: Player, personagem: Model)
	limparTudo(jogador)
	task.spawn(function()
		local humanoide = personagem:WaitForChild("Humanoid", 10)
		if not (humanoide and humanoide:IsA("Humanoid")) then
			return
		end
		humanoide:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if humanoide.SeatPart ~= nil then
				limparTudo(jogador) -- entrar em carro limpa mangueira e recipiente da mão
			end
		end)
		humanoide.Died:Connect(function()
			limparTudo(jogador)
		end)
	end)
end

local function jogadorEntrou(jogador: Player)
	jogador:SetAttribute("Mangueira", false)
	jogador:SetAttribute("RecipienteSlot", nil)
	jogador:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
		if armado(jogador) then
			limparTudo(jogador) -- equipar arma solta a mangueira e guarda o recipiente
		end
	end)
	jogador.CharacterAdded:Connect(function(personagem)
		conectarPersonagem(jogador, personagem)
	end)
	jogador.CharacterRemoving:Connect(function()
		limparTudo(jogador)
	end)
	if jogador.Character then
		conectarPersonagem(jogador, jogador.Character)
	end
end

-- Pública: segurar/guardar o recipiente do slot na mão (chamada pelo hook `usar` de Inventario). Alterna.
function Combustivel.segurarRecipiente(jogador: Player, slot: number)
	local _, _, humanoide = vivo(jogador)
	if not humanoide or sentado(humanoide) then
		return
	end
	local mao = maos[jogador]
	if mao and mao.slot == slot then
		limparMao(jogador) -- clicar de novo guarda
		return
	end
	local p = Inventario.slot(jogador, slot)
	local def = p and CfgItens.itens[p.id]
	if not (p and def and def.tipo == "recipiente") then
		return
	end
	if armado(jogador) then
		aviso(jogador, "Guarde a arma primeiro")
		return
	end
	if travas[jogador] then
		return -- despejando: a mão não troca no meio
	end
	local m = mangueiras[jogador]
	if m then
		guardarMangueira(m, nil, true) -- só uma coisa por vez na mão
	end
	definirMao(jogador, slot, p.id)
end

-- Inventário mudou: a mão só vale se o slot ainda tem o mesmo recipiente.
local function aoMudarInventario(jogador: Player)
	if trocando[jogador] then
		return
	end
	local mao = maos[jogador]
	if not mao then
		return
	end
	local p = Inventario.slot(jogador, mao.slot)
	if not p or p.id ~= mao.id then
		limparMao(jogador)
	end
end

-- Teste (só no Studio) ----------------------------------------------------------------------------------------

local function bombaMaisPerto(posicao: Vector3): Bomba?
	local melhor: Bomba? = nil
	local menor = math.huge
	for _, b in bombas do
		if b.corpo.Parent then
			local d = (b.corpo.Position - posicao).Magnitude
			if d < menor then
				melhor, menor = b, d
			end
		end
	end
	return melhor
end

local function registrarTestes()
	local ok, Teste = pcall(require, script.Parent.Teste)
	if not ok then
		return
	end
	Teste.registrar("irPosto", function(jogador: Player)
		local personagem, raiz, humanoide = vivo(jogador)
		if not (personagem and raiz and humanoide) then
			return "jogador morto"
		end
		local bomba = bombaMaisPerto(raiz.Position)
		if not bomba then
			return "nenhuma bomba achada (" .. #bombas .. ")"
		end
		-- 4 studs do lado +X (lado do bocal) e um pouco à frente (-Z), olhando para a bomba
		local alvo = bomba.origem * Vector3.new(1.15 + 4, 0, -1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { personagem }
		local topo = Vector3.new(alvo.X, bomba.origem.Position.Y + 6, alvo.Z)
		local chao = workspace:Raycast(topo, Vector3.new(0, -30, 0), params)
		local y = if chao then chao.Position.Y else bomba.origem.Position.Y
		local altura = humanoide.HipHeight + raiz.Size.Y / 2 + 0.1
		local ponto = Vector3.new(alvo.X, y + altura, alvo.Z)
		personagem:PivotTo(CFrame.lookAt(ponto, Vector3.new(bomba.corpo.Position.X, ponto.Y, bomba.corpo.Position.Z)))
		return string.format("%s a %.1f studs da bomba", bomba.id, (ponto - bomba.corpo.Position).Magnitude)
	end)
	Teste.registrar("darGasolina", function(jogador: Player)
		local linhas = {}
		for _, id in { "galaoVazio", "galaoGasolina", "garrafaVazia", "garrafaGasolina" } do
			table.insert(linhas, string.format("%s sobra %d", id, Inventario.dar(jogador, id, 1)))
		end
		return table.concat(linhas, " | ")
	end)
	Teste.registrar("estadoCombustivel", function(jogador: Player)
		local lista = {}
		for dono, m in mangueiras do
			table.insert(lista, {
				dono = dono.Name,
				bomba = m.bomba.id,
				estado = m.estado,
				fluxo = m.fluxo,
				carro = if m.carro then m.carro.Name else nil,
			})
		end
		local mao = maos[jogador]
		local ids = {}
		for _, b in bombas do
			table.insert(ids, b.id .. (if b.emUso then ("@" .. b.emUso.Name) else ""))
		end
		return {
			bombas = #bombas,
			idsBombas = ids,
			mangueiras = lista,
			mao = if mao then { slot = mao.slot, id = mao.id } else nil,
			atributoMangueira = jogador:GetAttribute("Mangueira"),
			atributoRecipienteSlot = jogador:GetAttribute("RecipienteSlot"),
			despejando = travas[jogador] ~= nil,
		}
	end)
end

function Combustivel.iniciar()
	local pasta = workspace:FindFirstChild("Mangueiras")
	if not (pasta and pasta:IsA("Folder")) then
		pasta = Instance.new("Folder")
		pasta.Name = "Mangueiras"
		pasta.Parent = workspace
	end
	pastaMangueiras = pasta :: Folder

	Players.PlayerAdded:Connect(jogadorEntrou)
	for _, jogador in Players:GetPlayers() do
		jogadorEntrou(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		limparTudo(jogador)
		travas[jogador] = nil
	end)

	Inventario.aoMudar(aoMudarInventario)
	local Vida = servico("Vida")
	if Vida then
		Vida.aoMorrer(function(jogador)
			limparTudo(jogador)
		end)
	end

	for _, tampa in CollectionService:GetTagged("Tampa") do
		ligarTampa(tampa)
	end
	CollectionService:GetInstanceAddedSignal("Tampa"):Connect(ligarTampa)

	task.spawn(function()
		local ultimo = os.clock()
		while true do
			task.wait(Cfg.mangueira.conferirSeg)
			local agora = os.clock()
			local ok, erro = pcall(conferir, agora - ultimo)
			ultimo = agora
			if not ok then
				warn("[Combustivel] erro na conferência: " .. tostring(erro))
			end
		end
	end)

	registrarTestes()
	task.spawn(montarBombas)
end

return Combustivel
