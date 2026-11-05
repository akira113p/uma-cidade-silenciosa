-- Ruido: o servidor calcula e publica todo barulho do jogo (passos, aterrissagem, voz e ações de outras partes).
-- Dono: P3. Contrato: docs/arquitetura.md §5. Quem ouve (monstros) se registra com aoRuido; paredes são do ouvinte.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Ambiente = require(script.Parent.Ambiente)
local Limite = require(script.Parent.Limite)
local Sons = require(script.Parent.Sons)
local Teste = require(script.Parent.Teste)

export type EventoRuido = {
	posicao: Vector3,
	db: number, -- emitido
	tipo: string, -- nome da ação (Config/Som.acoes) ou "passo"
	fonte: (Player | Model)?,
	ambiente: number, -- Ambiente.db() no momento
	tempo: number, -- os.clock()
}

local Ruido = {}

local PRIMEIRO_PASSO = 0.5 -- acumulador ao parar: o primeiro passo cai meio ciclo depois de começar a andar
local ACUMULADOR_MAXIMO = 2 -- evita rajada de passos depois de um engasgo do servidor

local ouvintes: { (EventoRuido) -> () } = {}
local estados: { [Player]: { acumulador: number, alturaMaxima: number, conexao: RBXScriptConnection? } } = {}
local noStudio = RunService:IsStudio()

-- Rede.criarTodos já rodou no init antes de qualquer require de serviço
local eventoMeuRuido = Rede.evento("MeuRuido")
local eventoRuidoDebug = Rede.evento("RuidoDebug")

local function ehJogador(fonte: any): boolean
	return typeof(fonte) == "Instance" and (fonte :: Instance):IsA("Player")
end

function Ruido.aoRuido(callback: (EventoRuido) -> ())
	table.insert(ouvintes, callback)
end

function Ruido.emitir(posicao: Vector3, db: number, tipo: string, fonte: (Player | Model)?)
	if type(db) ~= "number" or db ~= db or db == math.huge or db == -math.huge then
		warn("[Ruido] dB inválido em emitir (" .. tostring(tipo) .. "): " .. tostring(db))
		return
	end
	local ambiente = Ambiente.db()
	local evento: EventoRuido = {
		posicao = posicao,
		db = db,
		tipo = tipo,
		fonte = fonte,
		ambiente = ambiente,
		tempo = os.clock(),
	}
	for _, callback in ouvintes do
		task.spawn(callback, evento)
	end

	-- alcance para um ouvinte nível 1 (margem 0): é o que o medidor e o debug mostram
	local alcance = Som.alcance(db, ambiente, 0)
	if fonte and ehJogador(fonte) then
		local jogador = fonte :: Player
		jogador:SetAttribute("UltimoRuido", db)
		eventoMeuRuido:FireClient(jogador, db, ambiente, alcance)
	end
	if noStudio then
		eventoRuidoDebug:FireAllClients(posicao, alcance, db)
	end
end

function Ruido.emitirAcao(acao: string, posicao: Vector3, fonte: (Player | Model)?)
	local db = CfgSom.acoes[acao]
	if db == nil then
		warn("[Ruido] ação desconhecida: " .. tostring(acao))
		return
	end
	Ruido.emitir(posicao, db, acao, fonte)
end

local function vivo(jogador: Player, humanoide: Humanoid): boolean
	return humanoide.Health > 0 and jogador:GetAttribute("Morto") ~= true
end

local function raizDe(jogador: Player): (BasePart?, Humanoid?)
	local personagem = jogador.Character
	if not personagem then
		return nil, nil
	end
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if raiz and raiz:IsA("BasePart") and humanoide then
		return raiz, humanoide
	end
	return nil, nil
end

-- Aterrissagem: Freefall → Landed, altura = ponto mais alto da queda − chão. Queda pequena é degrau, não conta.
local function ligarPersonagem(jogador: Player, personagem: Model)
	local estado = estados[jogador]
	if not estado then
		return
	end
	local humanoide = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
	local raiz = personagem:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not (humanoide and raiz) then
		return
	end
	if estado.conexao then
		estado.conexao:Disconnect()
	end
	estado.alturaMaxima = raiz.Position.Y
	estado.conexao = humanoide.StateChanged:Connect(function(antes, depois)
		if depois == Enum.HumanoidStateType.Freefall then
			estado.alturaMaxima = raiz.Position.Y
		elseif antes == Enum.HumanoidStateType.Freefall and depois == Enum.HumanoidStateType.Landed then
			local altura = math.max(estado.alturaMaxima, raiz.Position.Y) - raiz.Position.Y
			if altura >= CfgSom.aterrissagem.alturaMinima and vivo(jogador, humanoide) then
				Sons.tocar("Aterrissar", raiz, { db = CfgSom.acoes.aterrissar })
				Ruido.emitirAcao("aterrissar", raiz.Position, jogador)
			end
		end
	end)
end

local function novoJogador(jogador: Player)
	estados[jogador] = { acumulador = PRIMEIRO_PASSO, alturaMaxima = 0 }
	jogador.CharacterAdded:Connect(function(personagem)
		ligarPersonagem(jogador, personagem)
	end)
	if jogador.Character then
		task.spawn(ligarPersonagem, jogador, jogador.Character)
	end
end

-- Um passo de amostragem (dt segundos desde a anterior) de um jogador
local function amostrar(jogador: Player, dt: number)
	local estado = estados[jogador]
	local raiz, humanoide = raizDe(jogador)
	if not (estado and raiz and humanoide) or not vivo(jogador, humanoide) then
		return
	end

	-- a altura máxima da queda acompanha o ponto mais alto enquanto está no ar
	if humanoide:GetState() == Enum.HumanoidStateType.Freefall then
		estado.alturaMaxima = math.max(estado.alturaMaxima, raiz.Position.Y)
	end

	local velocidade = raiz.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z).Magnitude
	local modo =
		Som.modoPasso(horizontal, jogador:GetAttribute("Agachado") == true, jogador:GetAttribute("Correndo") == true)
	local material = humanoide.FloorMaterial
	if modo == "parado" or material == Enum.Material.Air then
		estado.acumulador = PRIMEIRO_PASSO
		return
	end

	estado.acumulador = math.min(estado.acumulador + dt * CfgSom.passosPorSegundo[modo], ACUMULADOR_MAXIMO)
	if estado.acumulador < 1 then
		return
	end
	estado.acumulador -= 1

	local superficie = Som.superficieDeMaterial(material.Name)
	local db = Som.emitido(modo, superficie)
	Sons.tocar(Som.nomePasso(superficie), raiz, { db = db })
	Ruido.emitir(raiz.Position, db, "passo", jogador)
end

local function laco()
	local ultimo = os.clock()
	while true do
		task.wait(1 / CfgSom.hzAmostragem)
		local agora = os.clock()
		local dt = agora - ultimo
		ultimo = agora
		for _, jogador in Players:GetPlayers() do
			local ok, erro = pcall(amostrar, jogador, dt)
			if not ok then
				warn("[Ruido] erro na amostragem de passos: " .. tostring(erro))
			end
		end
	end
end

-- Voz: o cliente manda o nível do microfone; o servidor só confere tipo, taxa, estado e faixa do Config.
local function aoVoz(jogador: Player, db: unknown)
	if type(db) ~= "number" or db ~= db or db == math.huge or db == -math.huge then
		return
	end
	if not Limite.ok(jogador, "Voz", CfgSom.voz.intervalo) then
		return
	end
	local raiz, humanoide = raizDe(jogador)
	if not (raiz and humanoide) or not vivo(jogador, humanoide) then
		return
	end
	local valor = math.clamp(db, 0, CfgSom.voz.maximo)
	if valor < CfgSom.voz.minimo then
		return
	end
	local cabeca = jogador.Character and jogador.Character:FindFirstChild("Head")
	local posicao = if cabeca and cabeca:IsA("BasePart") then cabeca.Position else raiz.Position
	Ruido.emitir(posicao, valor, "voz", jogador) -- sem som: a voz real já toca pelo chat de voz
end

function Ruido.iniciar()
	Players.PlayerAdded:Connect(novoJogador)
	for _, jogador in Players:GetPlayers() do
		novoJogador(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		local estado = estados[jogador]
		if estado and estado.conexao then
			estado.conexao:Disconnect()
		end
		estados[jogador] = nil
	end)

	Rede.evento("Voz").OnServerEvent:Connect(aoVoz)
	task.spawn(laco)

	Teste.registrar("ruido", function(jogador: Player, db: number?)
		local raiz = raizDe(jogador)
		if not raiz then
			return "sem personagem"
		end
		local valor = db or 60
		Ruido.emitir(raiz.Position, valor, "teste", jogador)
		return string.format(
			"ruido %d dB, alcance %.0f studs (ambiente %d dB)",
			valor,
			Som.alcance(valor, Ambiente.db(), 0),
			Ambiente.db()
		)
	end)
end

return Ruido
