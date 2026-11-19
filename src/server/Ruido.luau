-- Ruido: o servidor calcula e publica todo barulho do jogo (passos em camadas, aterrissagem, ofego, voz e ações de outras partes).
-- Dono: P3. Contrato: docs/som.md (Som v2) e docs/arquitetura.md §5. Quem ouve (monstros) se registra com aoRuido; paredes são do ouvinte.
-- Um evento = 3 bandas (grave, médio, agudo) + a vibração pelo chão (opcional). `emitir(pos, db, tipo, fonte)` continua valendo para quem
-- só tem um número: o perfil do tipo vem de Config/Som.perfisAcao.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local CfgMonstros = require(Shared.Config:WaitForChild("Monstros"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Passo = require(Shared.Regras:WaitForChild("Passo"))
local Audicao = require(Shared.Regras:WaitForChild("Audicao"))
local Ambiente = require(script.Parent.Ambiente)
local Limite = require(script.Parent.Limite)
local Sons = require(script.Parent.Sons)
local Teste = require(script.Parent.Teste)

export type Bandas = Som.Bandas
export type EventoRuido = {
	posicao: Vector3,
	db: number, -- = max(bandas): compatível com o número único de antes (HUD, Sons.tocar, Flores, Corcunda)
	bandas: Bandas, -- dB a 1 m, por banda
	chao: number?, -- dB da vibração pelo chão; nil = não toca o chão (voz, grito, tiro no ar)
	tipo: string, -- "passo", "detrito", "esbarrao", "itemCaiu", "respiracao", "arfar" ou o nome da ação de Config/Som.acoes
	dominante: string?, -- camada mais forte do passo ("pisada", "equipamento", ...) ou subtipo do detrito ("vidro", "lata"...) ou classe
	modo: string?, -- "deitado" | "agachado" | "andar" | "correr" nos passos e detritos (a regra do Pulso do Rastejador lê isto)
	fonte: (Player | Model)?,
	ambiente: number, -- ambiente médio (compat)
	ambienteBandas: Som.AmbienteBandas,
	tempo: number, -- os.clock()
}
-- O que quem emite informa; o resto o Ruido preenche.
export type Emissao = {
	posicao: Vector3,
	bandas: Bandas,
	chao: number?,
	tipo: string,
	dominante: string?,
	modo: string?,
	fonte: (Player | Model)?,
}

local Ruido = {}

local PRIMEIRO_PASSO = 0.5 -- acumulador ao parar: o primeiro passo cai meio ciclo depois de começar a andar
local ACUMULADOR_MAXIMO = 2 -- evita rajada de passos depois de um engasgo do servidor
local ESTAMINA_CHEIA = 100 -- jogador sem o atributo Estamina conta como descansado

type EstadoJogador = {
	acumulador: number,
	alturaMaxima: number,
	conexao: RBXScriptConnection?,
	respiracao: number, -- s acumulados parado para o próximo ofego
}

local ouvintes: { (EventoRuido) -> () } = {}
local estados: { [Player]: EstadoJogador } = {}
local noStudio = RunService:IsStudio()

-- Rede.criarTodos já rodou no init antes de qualquer require de serviço
local eventoMeuRuido = Rede.evento("MeuRuido")
local eventoRuidoDebug = Rede.evento("RuidoDebug")

-- Outros serviços (carregados sob demanda e em pcall: uma falha neles não derruba o ruído; evita require circular).
local servicos: { [string]: any } = {}
local function servico(nome: string): any
	local s = servicos[nome]
	if s == nil then
		local arquivo = script.Parent:FindFirstChild(nome)
		local ok, modulo = false, nil
		if arquivo then
			ok, modulo = pcall(require, arquivo)
		end
		if ok and modulo then
			s = modulo
		else
			warn("[Ruido] serviço indisponível: " .. nome .. " " .. tostring(modulo))
			s = false
		end
		servicos[nome] = s
	end
	return s or nil
end

local function ehJogador(fonte: any): boolean
	return typeof(fonte) == "Instance" and (fonte :: Instance):IsA("Player")
end

local function numeroValido(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Ruido.aoRuido(callback: (EventoRuido) -> ())
	table.insert(ouvintes, callback)
end

-- A função principal: preenche db, ambiente e tempo, chama os ouvintes e avisa o medidor de quem emitiu.
function Ruido.emitirSom(ev: Emissao)
	local b = ev.bandas
	if not (b and numeroValido(b.grave) and numeroValido(b.medio) and numeroValido(b.agudo)) then
		warn("[Ruido] bandas inválidas em emitirSom (" .. tostring(ev.tipo) .. ")")
		return
	end
	if ev.chao ~= nil and not numeroValido(ev.chao) then
		warn("[Ruido] chão inválido em emitirSom (" .. tostring(ev.tipo) .. ")")
		return
	end
	local ambienteBandas = Som.ambienteBandas(Ambiente.condicao())
	local db = math.max(b.grave, b.medio, b.agudo)
	local evento: EventoRuido = {
		posicao = ev.posicao,
		db = db,
		bandas = b,
		chao = ev.chao,
		tipo = ev.tipo,
		dominante = ev.dominante,
		modo = ev.modo,
		fonte = ev.fonte,
		ambiente = ambienteBandas.medio,
		ambienteBandas = ambienteBandas,
		tempo = os.clock(),
	}
	for _, callback in ouvintes do
		task.spawn(callback, evento)
	end

	-- alcance para o ouvinte de referência (limiar 0, sem chão = o nível 1 de antes): é o que o medidor e o debug mostram
	local alcance, banda = Som.alcanceEvento(b, nil, ambienteBandas, nil)
	local fonte = ev.fonte
	if fonte and ehJogador(fonte) then
		local jogador = fonte :: Player
		jogador:SetAttribute("UltimoRuido", db)
		local chave = Som.chaveRotulo(ev.tipo, ev.dominante, CfgSom.medidor.rotulos)
		eventoMeuRuido:FireClient(jogador, db, ambienteBandas.medio, alcance, chave)
	end
	if noStudio then
		eventoRuidoDebug:FireAllClients(
			ev.posicao,
			alcance,
			db,
			if ev.chao ~= nil and alcance <= 0 then "chao" else banda
		)
	end
end

-- Quem só tem um número (tiro, carro, porta...): as bandas vêm de Config/Som.perfisAcao[tipo] (sem entrada = plano, sem chão).
function Ruido.emitir(posicao: Vector3, db: number, tipo: string, fonte: (Player | Model)?)
	if not numeroValido(db) then
		warn("[Ruido] dB inválido em emitir (" .. tostring(tipo) .. "): " .. tostring(db))
		return
	end
	local bandas, chao = Som.bandasDeAcao(db, tipo)
	Ruido.emitirSom({ posicao = posicao, bandas = bandas, chao = chao, tipo = tipo, fonte = fonte })
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

local function estaminaDe(jogador: Player): number
	local e = jogador:GetAttribute("Estamina")
	return if type(e) == "number" then e else ESTAMINA_CHEIA
end

-- Carga em kg (Σ peso × qtd do inventário); 0 se o Inventario não carregou.
local function cargaDe(jogador: Player): number
	local inv = servico("Inventario")
	return if inv and inv.carga then inv.carga(jogador) else 0
end

local function prendendo(jogador: Player): boolean
	return jogador:GetAttribute("PrendendoRespiracao") == true
end

-- Superfície sob o pé, só para a camada da aterrissagem.
local function superficieSob(humanoide: Humanoid): string
	return Som.superficieDeMaterial(humanoide.FloorMaterial.Name)
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
				local c = Som.compor({ Passo.aterrissagem(altura, superficieSob(humanoide), CfgSom) })
				Sons.tocar("Aterrissar", raiz, { db = c.db })
				Ruido.emitirSom({
					posicao = raiz.Position,
					bandas = c.bandas,
					chao = c.chao,
					tipo = "aterrissar",
					fonte = jogador,
				})
			end
		end
	end)
end

local function novoJogador(jogador: Player)
	estados[jogador] = { acumulador = PRIMEIRO_PASSO, alturaMaxima = 0, respiracao = 0 }
	jogador.CharacterAdded:Connect(function(personagem)
		ligarPersonagem(jogador, personagem)
	end)
	if jogador.Character then
		task.spawn(ligarPersonagem, jogador, jogador.Character)
	end
end

-- Ofego parado (docs/som.md §4.4): a cada `intervalo` s parado, com estamina baixa, a respiração faz barulho.
local function ofegar(jogador: Player, estado: EstadoJogador, raiz: BasePart, dt: number)
	if not CfgSom.respiracao.ligado then
		return
	end
	estado.respiracao += dt
	if estado.respiracao < CfgSom.respiracao.intervalo then
		return
	end
	estado.respiracao = 0
	local camada = Passo.respiracaoParado(estaminaDe(jogador), prendendo(jogador), CfgSom)
	if camada then
		local c = Som.compor({ camada })
		Ruido.emitirSom({
			posicao = raiz.Position,
			bandas = c.bandas,
			chao = c.chao,
			tipo = "respiracao",
			fonte = jogador,
		})
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
	local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z)
	local modo = Som.modoPasso(
		horizontal.Magnitude,
		jogador:GetAttribute("Agachado") == true,
		jogador:GetAttribute("Correndo") == true,
		jogador:GetAttribute("Deitado") == true
	)
	local material = humanoide.FloorMaterial
	if modo == "parado" or material == Enum.Material.Air then
		estado.acumulador = PRIMEIRO_PASSO
		if modo == "parado" and humanoide.SeatPart == nil then
			ofegar(jogador, estado, raiz, dt)
		else
			estado.respiracao = 0
		end
		return
	end
	estado.respiracao = 0

	-- esbarrão e vegetação: uma consulta espacial por amostra (Obstaculos); o esbarrão só em andar/correr
	local direcao = if horizontal.Magnitude > 0.01 then horizontal.Unit else raiz.CFrame.LookVector
	local pe = raiz.Position - Vector3.new(0, raiz.Size.Y / 2 + humanoide.HipHeight, 0)
	local superficie = Som.superficieDeMaterial(material.Name)
	local obstaculos = servico("Obstaculos")
	local mato = false
	if obstaculos then
		local ok, achou = pcall(obstaculos.amostrar, jogador, raiz, modo, direcao, pe)
		mato = ok and achou == true
	end

	estado.acumulador = math.min(estado.acumulador + dt * CfgSom.passosPorSegundo[modo], ACUMULADOR_MAXIMO)
	if estado.acumulador < 1 then
		return
	end
	estado.acumulador -= 1

	local c = Som.compor(Passo.camadas({
		modo = modo,
		superficie = superficie,
		carga = cargaDe(jogador),
		estamina = estaminaDe(jogador),
		vegetacao = mato or superficie == "gramaAlta",
		prendendo = prendendo(jogador),
	}, CfgSom))
	Sons.tocar(Som.nomePasso(superficie), raiz, { db = c.db })
	Ruido.emitirSom({
		posicao = raiz.Position,
		bandas = c.bandas,
		chao = c.chao,
		tipo = "passo",
		dominante = c.dominante,
		modo = modo,
		fonte = jogador,
	})

	local detritos = servico("Detritos")
	if detritos then
		local ok, erro = pcall(detritos.aoPasso, jogador, pe, modo, direcao)
		if not ok then
			warn("[Ruido] erro em Detritos.aoPasso: " .. tostring(erro))
		end
	end
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
	if not numeroValido(db) then
		return
	end
	if not Limite.ok(jogador, "Voz", CfgSom.voz.intervalo) then
		return
	end
	local raiz, humanoide = raizDe(jogador)
	if not (raiz and humanoide) or not vivo(jogador, humanoide) then
		return
	end
	local valor = math.clamp(db :: number, 0, CfgSom.voz.maximo)
	if valor < CfgSom.voz.minimo then
		return
	end
	local cabeca = jogador.Character and jogador.Character:FindFirstChild("Head")
	local posicao = if cabeca and cabeca:IsA("BasePart") then cabeca.Position else raiz.Position
	Ruido.emitir(posicao, valor, "voz", jogador) -- sem som: a voz real já toca pelo chat de voz
end

-- Teste "audicao": a tabela da §8 de docs/som.md ao vivo (concreto, carga 5 kg, estamina cheia, sem parede, monstro Calmo andando).
local function tabelaAudicao(): string
	local ambiente = Som.ambienteBandas(Ambiente.condicao())
	local linhas =
		{ string.format("ambiente %s: %d dB (chão %d)", Ambiente.condicao(), ambiente.medio, ambiente.chao) }
	local eventos: { [string]: any } = {}
	for _, modo in { "agachado", "andar", "correr" } do
		local c = Som.compor(Passo.camadas({
			modo = modo,
			superficie = "concreto",
			carga = 5,
			estamina = ESTAMINA_CHEIA,
			vegetacao = false,
		}, CfgSom))
		eventos[modo] = { bandas = c.bandas, chao = c.chao, ambienteBandas = ambiente, modo = modo, tipo = "passo" }
	end
	local function linha(nome: string, perfil: Audicao.Perfil?, nivel: number): string
		local partes = {}
		for _, modo in { "agachado", "andar", "correr" } do
			local a = if perfil
				then Audicao.alcance(eventos[modo], perfil, 0, 0, 0, nil, nil)
				else Som.alcanceEvento(eventos[modo].bandas, eventos[modo].chao, ambiente, nil)
			table.insert(partes, string.format("%s %d", modo, math.floor(a + 0.5)))
		end
		return string.format("%s (nível %d): %s", nome, nivel, table.concat(partes, " | "))
	end
	table.insert(linhas, linha("referência", nil, 1))
	for _, especie in CfgMonstros.especies do
		if especie.malha then
			table.insert(linhas, linha(especie.id, Audicao.perfil(especie.id, especie.nivel), especie.nivel))
		end
	end
	return table.concat(linhas, "\n")
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

	-- Serviços do som v2 que não estão na ORDEM do init (docs/pendencias-integracao.md "Som v2"): o Ruido os inicia.
	for _, nome in { "Detritos", "Obstaculos", "Respiracao" } do
		local s = servico(nome)
		if s and s.iniciar then
			local ok, erro = pcall(s.iniciar)
			if not ok then
				warn("[Ruido] erro ao iniciar " .. nome .. ": " .. tostring(erro))
			end
		end
	end

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
	Teste.registrar("audicao", function()
		local texto = tabelaAudicao()
		print("[Ruido] audicao:\n" .. texto)
		return texto
	end)
end

return Ruido
