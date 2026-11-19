-- Personagem: escolha do personagem e nascimento (Players.CharacterAutoLoads = false). O jogador entra SEM personagem,
-- escolhe no seletor (client/SeletorPersonagem.luau) e só então o servidor chama LoadCharacter. Depois de morrer, espera
-- Players.RespawnTime e reaparece sozinho, a não ser que o jogador esteja no seletor (aí reaparece ao fechar ou ao
-- confirmar outro personagem). Dono: parte S. Contrato: docs/personagens.md §2.
-- O servidor não confia no cliente: n inteiro do elenco, Limite.ok, estado do jogador (Regras/Personagens). Escolher
-- NÃO muda atributo nenhum do jogo (vida, velocidade, dano): só o atributo PersonagemId, que o visual lê.
-- Atributos: Player.PersonagemId (ausente = "padrao") e Character.PersonagemId (o cliente dos outros jogadores precisa).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Personagens"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Personagens"))
local Limite = require(script.Parent.Limite)
local Preferencias = require(script.Parent.Preferencias)

local Personagem = {}

local INTERVALO_ESCOLHA = 0.5 -- s entre EscolherPersonagem do mesmo jogador
local INTERVALO_ESTADO = 0.2 -- s entre SeletorEstado do mesmo jogador
local ESPERA_PREFERENCIAS = 20 -- s para o DataStore responder antes de seguir com o padrão

type Estado = {
	ficha: number, -- cresce a cada personagem que nasce; identifica "o personagem atual"
	agendado: number, -- ficha cujo respawn já está agendado (0 = nenhum)
	pendente: number, -- ficha cujo respawn ficou esperando o seletor fechar (0 = nenhum)
	escolheu: boolean,
	carregando: boolean, -- LoadCharacter da escolha/respawn em andamento
	escolhendo: boolean, -- seletor aberto no cliente
	escolhendoDesde: number,
}

local estados: { [Player]: Estado } = {}

local function responder(jogador: Player, ok: boolean, n: number?, texto: string?)
	Rede.evento("PersonagemEscolhido"):FireClient(jogador, ok, n, texto)
end

local function estaMorto(jogador: Player): boolean
	if jogador:GetAttribute("Morto") == true then
		return true
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	return humanoide ~= nil and humanoide.Health <= 0
end

local function esperarPreferencias(jogador: Player)
	local t0 = os.clock()
	while
		jogador.Parent == Players
		and jogador:GetAttribute("PrefCarregadas") ~= true
		and os.clock() - t0 < ESPERA_PREFERENCIAS
	do
		task.wait(0.25)
	end
end

-- LoadCharacter sem deixar o erro (jogador que saiu no meio) derrubar o serviço.
local function nascer(jogador: Player, est: Estado): boolean
	est.carregando = true
	local ok, erro = pcall(function()
		jogador:LoadCharacter()
	end)
	est.carregando = false
	if not ok and jogador.Parent == Players then
		warn("[Personagem] LoadCharacter falhou para " .. jogador.Name .. ": " .. tostring(erro))
	end
	return ok
end

-- Escolha já validada: grava o PersonagemId, salva a preferência e faz nascer. Roda em task própria (LoadCharacter espera).
local function aplicarEscolha(jogador: Player, est: Estado, entrada: Regras.Entrada)
	esperarPreferencias(jogador) -- senão a leitura do DataStore, ao chegar, desfaria o Pref_Personagem
	if jogador.Parent ~= Players then
		est.carregando = false
		return
	end
	jogador:SetAttribute("PersonagemId", entrada.id)
	Preferencias.definir(jogador, "Pref_Personagem", entrada.n)
	est.escolheu = true
	est.escolhendo = false
	est.pendente = 0
	local ok = nascer(jogador, est)
	if jogador.Parent == Players then
		responder(jogador, ok, entrada.n, if ok then nil else "Não deu para criar o personagem. Tente de novo.")
	end
end

-- Pedido de escolha (do cliente ou do comando de teste). `confiavel` pula só o Limite.
local function pedirEscolha(jogador: Player, n: unknown, confiavel: boolean): string?
	local est = estados[jogador]
	if not est then
		return "jogador sem estado"
	end
	if not confiavel and not Limite.ok(jogador, "EscolherPersonagem", INTERVALO_ESCOLHA) then
		return "rápido demais"
	end
	local entrada = Regras.validarEscolha(Cfg.lista, n)
	if not entrada then
		responder(jogador, false, nil, "Personagem inválido.")
		return "personagem inválido"
	end
	local pode, motivo = Regras.podeEscolher({
		escolheu = est.escolheu,
		temPersonagem = jogador.Character ~= nil,
		morto = estaMorto(jogador),
		carregando = est.carregando,
	})
	if not pode then
		responder(jogador, false, nil, motivo)
		return motivo
	end
	est.carregando = true -- fecha a porta já: clique duplo/spam não entra
	task.spawn(aplicarEscolha, jogador, est, entrada)
	return nil
end

-- O tempo de reaparecer acabou (ou o seletor fechou com um respawn esperando).
local function tentarReaparecer(jogador: Player, ficha: number)
	local est = estados[jogador]
	if not est then
		return
	end
	local escolhendo = est.escolhendo and os.clock() - est.escolhendoDesde < Cfg.esperaSeletorMax
	local decisao = Regras.decidirRespawn({
		presente = jogador.Parent == Players,
		fichaAgendada = ficha,
		fichaAtual = est.ficha,
		escolheu = est.escolheu,
		carregando = est.carregando,
		escolhendo = escolhendo,
	})
	if decisao == "esperar" then
		est.pendente = ficha
		task.delay(Cfg.esperaSeletorMax + 1, function()
			if estados[jogador] == est and est.pendente == ficha then
				tentarReaparecer(jogador, ficha)
			end
		end)
	elseif decisao == "reaparecer" then
		est.pendente = 0
		nascer(jogador, est)
	end
end

-- Agenda UM respawn por personagem (Died e CharacterRemoving podem vir os dois).
local function agendarRespawn(jogador: Player, est: Estado, ficha: number)
	if est.agendado == ficha then
		return
	end
	est.agendado = ficha
	task.delay(Players.RespawnTime, tentarReaparecer, jogador, ficha)
end

local function aoPersonagem(jogador: Player, est: Estado, personagem: Model)
	est.ficha += 1
	local ficha = est.ficha
	est.pendente = 0
	personagem:SetAttribute(
		"PersonagemId",
		Regras.idEfetivo(Cfg.lista, jogador:GetAttribute("PersonagemId"), Cfg.padrao)
	)
	local humanoide = personagem:WaitForChild("Humanoid", 10)
	if humanoide and humanoide:IsA("Humanoid") then
		-- Died dispara uma vez por Character; o Once garante que não agenda duas vezes.
		humanoide.Died:Once(function()
			agendarRespawn(jogador, est, ficha)
		end)
	end
end

local function registrar(jogador: Player)
	if estados[jogador] then
		return
	end
	local est: Estado = {
		ficha = 0,
		agendado = 0,
		pendente = 0,
		escolheu = false,
		carregando = false,
		escolhendo = false,
		escolhendoDesde = 0,
	}
	estados[jogador] = est
	jogador.CharacterAdded:Connect(function(personagem)
		aoPersonagem(jogador, est, personagem)
	end)
	-- personagem removido sem morrer (Destroy por fora): também reaparece
	jogador.CharacterRemoving:Connect(function()
		agendarRespawn(jogador, est, est.ficha)
	end)
	if jogador.Character then
		-- só acontece se CharacterAutoLoads ainda estava ligado quando o jogador entrou
		task.spawn(aoPersonagem, jogador, est, jogador.Character)
	end
	-- Convida o cliente a abrir o seletor assim que as preferências chegam (o cliente também abre sozinho).
	task.spawn(function()
		esperarPreferencias(jogador)
		if jogador.Parent == Players and not est.escolheu then
			local salvo = Regras.nInicial(Cfg.lista, jogador:GetAttribute("Pref_Personagem"), Cfg.padrao)
			Rede.evento("AbrirSeletor"):FireClient(jogador, salvo)
		end
	end)
end

local function aoSeletorEstado(jogador: Player, aberto: unknown)
	local est = estados[jogador]
	if type(aberto) ~= "boolean" or not est or not Limite.ok(jogador, "SeletorEstado", INTERVALO_ESTADO) then
		return
	end
	est.escolhendo = aberto
	est.escolhendoDesde = os.clock()
	if not aberto and est.pendente ~= 0 then
		tentarReaparecer(jogador, est.pendente)
	end
end

function Personagem.iniciar()
	-- Também está em default.project.json; aqui garante que nada nasce antes da escolha.
	Players.CharacterAutoLoads = false

	Rede.evento("EscolherPersonagem").OnServerEvent:Connect(function(jogador, n)
		pedirEscolha(jogador, n, false)
	end)
	Rede.evento("SeletorEstado").OnServerEvent:Connect(aoSeletorEstado)

	Players.PlayerAdded:Connect(registrar)
	for _, jogador in Players:GetPlayers() do
		registrar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		estados[jogador] = nil
	end)

	local arquivo = script.Parent:FindFirstChild("Teste")
	local okTeste, Teste = pcall(function()
		return require(arquivo :: ModuleScript)
	end)
	if okTeste and Teste then
		-- "personagem"(n): escolhe e nasce sem passar pelo seletor (n do Config/Personagens; padrão 1)
		Teste.registrar("personagem", function(jogador: Player, n: number?)
			return pedirEscolha(jogador, n or 1, true) or "ok"
		end)
	end
end

return Personagem
