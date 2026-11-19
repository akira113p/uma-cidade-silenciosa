-- Veiculos (servidor): nascimento no mapa, entrar/sair, motor, batida, tiro, ruído e anti-trapaça. Dono: V2.
-- Contrato: docs/veiculos.md. O modelo físico está em VeiculoModelo; as regras puras, em Regras/Veiculo.
-- O motorista é dono da física (SetNetworkOwner): o servidor só confere velocidade e colisão.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Veiculos"))
local CfgSom = require(Shared.Config:WaitForChild("Som"))
local CfgItens = require(Shared.Config:WaitForChild("Itens"))
local CfgAdmin = require(Shared.Config:WaitForChild("Admin"))
local CfgDestruicao = require(Shared.Config:WaitForChild("Destruicao"))
local CfgComb = require(Shared.Config:WaitForChild("Combustivel"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Veiculo"))
local RegraComb = require(Shared.Regras:WaitForChild("Combustivel"))

local Limite = require(script.Parent.Limite)
local Teste = require(script.Parent.Teste)
local Sons = require(script.Parent.Sons)
local Ruido = require(script.Parent.Ruido)
local Vida = require(script.Parent.Vida)
local Loot = require(script.Parent.Loot)
local VeiculoModelo = require(script.Parent.VeiculoModelo)

type Estado = Regra.Estado
type Dado = {
	modelo: Model,
	estado: Estado,
	lim: any, -- resultado de Regra.limites
	tipo: any, -- Cfg.tipos[estado.tipo]
	chassi: BasePart,
	bancos: { Seat },
	motorista: Player?,
	ligado: boolean,
	dormindo: boolean,
	vAnterior: Vector3?,
	excesso: number, -- s acima de 1.3 x VelMax
	proxRuido: number,
	proxDerrapagem: number, -- os.clock a partir do qual a próxima derrapagem pode fazer ruído
	ultimaBatida: number,
	somMotor: Sound?,
	ocupado: boolean, -- tem alguém sentado em qualquer banco
	dono: Player?, -- dono atual da física (motorista, ou o passageiro mais antigo se não há motorista)
	estacionarAte: number?, -- os.clock até ancorar à força; nil = não está esperando parar
	desde: { [Player]: number }, -- os.clock da entrada de cada ocupante (o mais antigo herda a física)
	trocando: { [Player]: boolean }, -- está trocando de banco (não é saída: não teleporta para fora)
	nivelPublicado: number, -- litros do último valor gravado no atributo Combustivel
}

local Veiculos = {}

local ESPERA_MAPA = 15
local LOTE_VARREDURA = 300 -- filhos visitados antes de ceder o servidor
local FOLGA_ALCANCE = 1.25 -- latência na checagem de distância de entrar (mesmo valor do Loot)
local PASSO = 0.1 -- s, laço dos carros ocupados (10 Hz)
local TOLERANCIA_VEL = 1.3 -- x VelMax
local TEMPO_EXCESSO = 2 -- s
local PAUSA_RETOMADA = 1.5 -- s com a física no servidor depois de pegar trapaça
local INTERVALO_BATIDA = 0.3 -- s entre batidas contadas
-- Som do motor: PlaybackSpeed = BASE + ALCANCE * fração da velocidade.
-- INTEGRACAO: virar Config/Veiculos (ver docs/pendencias-integracao.md, "Veiculos").
local VELOCIDADE_SOM_BASE, VELOCIDADE_SOM_ALCANCE = 0.7, 0.9
local DANO_TIRO_MINIMO = 0
-- INTEGRACAO: virar Config/Veiculos (docs/combustivel.md, pendências).
local PASSO_COMBUSTIVEL = 0.2 -- s, laço único de consumo
local VEL_ESTACIONAR = 2 -- studs/s: abaixo disto o carro sem ocupante é ancorado (acima, só freia)
local TEMPO_ESTACIONAR = 10 -- s freando antes de ancorar à força
local ESPERA_TROCA = 0.6 -- s: janela em que a troca de banco não conta como saída
local LIMIAR_LADO = 0.1 -- studs: banco com |x| menor que isto não tem lado (serve para qualquer porta)
local TENTATIVAS_CONDICAO = 80

local rng = Random.new()
local function aleatorio(): number
	return rng:NextNumber()
end

local dados: { [Model]: Dado } = {}
local porMotorista: { [Player]: Dado } = {}
local dadoDoBanco: { [Instance]: Dado } = {}
local ligados: { [Dado]: boolean } = {} -- carros com o motor ligado (laço único de combustível)
local Malhas: any = require(Shared:WaitForChild("Config"):WaitForChild("VeiculosMalhas"))

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

local function resumo(d: Dado): string
	local e = d.estado
	return string.format(
		"%s %s motor=%d carroceria=%d queimado=%s ligado=%s pneus=[%s %s %s %s] vidros=[%s %s %s %s]",
		e.tipo,
		e.condicao,
		e.motor,
		e.carroceria,
		tostring(e.queimado),
		tostring(d.ligado),
		e.pneus.FE,
		e.pneus.FD,
		e.pneus.TE,
		e.pneus.TD,
		e.vidros.ParaBrisa,
		e.vidros.Traseiro,
		e.vidros.JanelaE,
		e.vidros.JanelaD
	)
end

-- Estado novo; `condicoes` (lista) força a condição (carro_destruido, comando de teste).
local function sortearEstado(tipo: string, condicoes: { string }?): Estado
	local e = Regra.sortear(tipo, aleatorio, Cfg)
	if not condicoes then
		return e
	end
	for _ = 1, TENTATIVAS_CONDICAO do
		if table.find(condicoes, e.condicao) then
			return e
		end
		e = Regra.sortear(tipo, aleatorio, Cfg)
	end
	-- a Regra não deu a condição pedida: força na cópia (motor zerado, queimado se for o caso)
	local c = table.clone(e)
	c.condicao = condicoes[#condicoes]
	c.queimado = c.condicao == "queimado"
	c.motor = 0
	return c
end

local function sortearTipo(): string
	local total = 0
	for _, t in Cfg.tipos do
		total += t.peso
	end
	local sorte = aleatorio() * total
	local ultimo = "sedan"
	for nome, t in Cfg.tipos do
		ultimo = nome
		sorte -= t.peso
		if sorte <= 0 then
			return nome
		end
	end
	return ultimo
end

local function desligar(d: Dado)
	d.ligado = false
	ligados[d] = nil
	d.modelo:SetAttribute("MotorLigado", false)
	if d.somMotor then
		d.somMotor:Destroy()
		d.somMotor = nil
	end
end

local function aplicarEstado(d: Dado, novo: Estado)
	d.estado = novo
	d.modelo:SetAttribute("Mexido", true) -- dano/tiro/batida: some o direito de ser removido ou recriado
	d.lim = Regra.limites(novo, Cfg)
	VeiculoModelo.aplicar(d.modelo, novo)
	if d.ligado and novo.motor <= 0 then
		desligar(d)
	end
end

local function jogadorDoBanco(banco: Seat): Player?
	local humanoide = banco.Occupant
	return humanoide and humanoide.Parent and Players:GetPlayerFromCharacter(humanoide.Parent) or nil
end

-- Quem está sentado, do mais antigo ao mais novo. Quem está trocando de banco continua contando.
local function ocupantes(d: Dado): { Player }
	local lista: { Player } = {}
	for _, banco in d.bancos do
		local jogador = jogadorDoBanco(banco)
		if jogador then
			table.insert(lista, jogador)
		end
	end
	for jogador in d.trocando do
		if not table.find(lista, jogador) then
			table.insert(lista, jogador)
		end
	end
	for _, jogador in lista do
		if d.desde[jogador] == nil then
			d.desde[jogador] = os.clock()
		end
	end
	for jogador in d.desde do
		if not table.find(lista, jogador) then
			d.desde[jogador] = nil
		end
	end
	table.sort(lista, function(a, b)
		return d.desde[a] < d.desde[b]
	end)
	return lista
end

-- Ninguém no carro: freio de estacionamento. Parado, ancora; em movimento, só freia e ancora quando parar (ou no prazo).
-- Devolver a física ao servidor com o carro solto faz as rodas explodirem: o dono anterior segue com ela até ancorar.
local function estacionar(d: Dado)
	d.dono = nil
	d.vAnterior = nil
	VeiculoModelo.freiar(d.modelo, true)
	if d.chassi.AssemblyLinearVelocity.Magnitude <= VEL_ESTACIONAR then
		d.estacionarAte = nil
		d.dormindo = true
		VeiculoModelo.ancorar(d.modelo, true)
	else
		d.estacionarAte = os.clock() + TEMPO_ESTACIONAR
	end
end

-- Alguém sentou ou saiu de qualquer banco: reavalia o motorista e o dono da física.
-- Carro com ocupante nunca fica ancorado: sem motorista, o passageiro mais antigo herda a física (freio de estacionamento ligado).
local function reavaliar(d: Dado)
	local lista = ocupantes(d)
	d.ocupado = #lista > 0
	local jogador = jogadorDoBanco(d.bancos[1])
	if jogador ~= d.motorista then
		if d.motorista then
			porMotorista[d.motorista] = nil
		end
		d.motorista = jogador
		d.vAnterior = nil
		d.excesso = 0
		if jogador then
			porMotorista[jogador] = d
		else
			desligar(d)
		end
	end
	local alvo = jogador or lista[1]
	if alvo then
		d.estacionarAte = nil
		if alvo ~= d.dono or d.dormindo then
			d.dono = alvo
			d.dormindo = false
			d.vAnterior = nil
			d.excesso = 0
			VeiculoModelo.ancorar(d.modelo, false)
			VeiculoModelo.freiar(d.modelo, jogador == nil)
			VeiculoModelo.definirDono(d.modelo, alvo)
		end
	elseif d.dono ~= nil or not d.dormindo then
		estacionar(d)
	end
end

local function entrar(d: Dado, jogador: Player, porta: BasePart)
	if not Limite.ok(jogador, "EntrarCarro", 0.5) then
		return
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (humanoide and raiz and raiz:IsA("BasePart")) or humanoide.Health <= 0 or not Vida.estaVivo(jogador) then
		return
	end
	if humanoide.SeatPart ~= nil then
		return
	end
	if (raiz.Position - porta.Position).Magnitude > CfgItens.alcanceInteracao * FOLGA_ALCANCE then
		return
	end
	if not Regra.podeDirigir(d.estado) then
		aviso(jogador, "Carro queimado")
		return
	end
	-- banco livre do lado da porta usada (PortaE = esquerda, x < 0; PortaD = direita, x > 0), o mais à frente primeiro; senão qualquer
	local sinal = if porta.Name == "PortaE" then -1 elseif porta.Name == "PortaD" then 1 else 0
	local escolhido: Seat? = nil
	local qualquer: Seat? = nil
	for _, banco in d.bancos do
		if banco.Occupant == nil and not banco.Disabled then
			qualquer = qualquer or banco
			local x = d.chassi.CFrame:PointToObjectSpace(banco.Position).X
			if sinal ~= 0 and x * sinal > LIMIAR_LADO then
				escolhido = escolhido or banco
			end
		end
	end
	local banco = escolhido or qualquer
	if banco then
		Sons.tocar("PortaCarro", d.chassi)
		Ruido.emitirAcao("porta", d.chassi.Position, jogador)
		banco:Sit(humanoide)
		return
	end
	aviso(jogador, "Carro lotado")
end

-- Sair: põe o personagem AO LADO da porta, em lugar livre, nunca dentro do carro. Lado do banco primeiro (motorista = esquerda);
-- bloqueado, tenta o outro lado. Chamado quando o ocupante de qualquer banco sai (tecla E, pulo, botão do celular).
local ALTURA_PERSONAGEM = 5.4 -- caixa de teste do espaço livre (R15 em pé, com folga)
local LARGURA_PERSONAGEM = 2.6
local DISTANCIA_PORTA = 1.8 -- studs além da lateral do carro

local function posicaoLivre(d: Dado, banco: Seat, lado: number, ignorar: Instance?): Vector3?
	local chassi = d.chassi
	local meia = d.chassi.Size.X / 2
	local alvo = chassi.CFrame:PointToWorldSpace(
		Vector3.new(lado * (meia + DISTANCIA_PORTA), 0, chassi.CFrame:PointToObjectSpace(banco.Position).Z)
	)
	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	filtro.FilterDescendantsInstances = if ignorar then { d.modelo, ignorar } else { d.modelo }
	local chao = workspace:Raycast(alvo + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), filtro)
	if not chao then
		return nil
	end
	local centro = chao.Position + Vector3.new(0, ALTURA_PERSONAGEM / 2 + 0.1, 0)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = if ignorar then { d.modelo, ignorar } else { d.modelo }
	for _, p in
		workspace:GetPartBoundsInBox(
			CFrame.new(centro),
			Vector3.new(LARGURA_PERSONAGEM, ALTURA_PERSONAGEM - 0.4, LARGURA_PERSONAGEM),
			op
		)
	do
		if p.CanCollide then
			return nil
		end
	end
	return chao.Position + Vector3.new(0, 3.2, 0)
end

-- Sentado, o personagem fica dentro dos blocos de colisão do carro. Ao soltar a solda, a física do cliente o expulsaria num
-- tranco (arremessa dezenas de studs): por isso não colide com o carro até já estar do lado de fora.
local GRUPO_OCUPANTE = "VeiculoOcupante"
local ESPERA_COLISAO = 0.6 -- s depois de sair até voltar a colidir com o carro

local function grupoDoPersonagem(personagem: Instance, grupo: string)
	for _, p in personagem:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = grupo
		end
	end
end

local function colocarAoLado(d: Dado, banco: Seat, humanoide: Humanoid)
	local personagem = humanoide.Parent
	task.delay(ESPERA_COLISAO, function()
		if personagem and personagem.Parent and humanoide.SeatPart == nil then
			grupoDoPersonagem(personagem, "Default")
		end
	end)
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (personagem and personagem:IsA("Model") and raiz and raiz:IsA("BasePart")) or humanoide.Health <= 0 then
		return
	end
	-- O cliente é dono do personagem: PivotTo só no servidor é desfeito. Quem move é o próprio cliente (Direcao).
	local jogador = Players:GetPlayerFromCharacter(personagem)
	local function mover(cf: CFrame)
		personagem:PivotTo(cf)
		if jogador then
			Rede.evento("SairCarro"):FireClient(jogador, cf)
		end
	end
	local esquerdo = d.chassi.CFrame:PointToObjectSpace(banco.Position).X <= 0
	local preferido = if esquerdo then -1 else 1
	for _, lado in { preferido, -preferido } do
		local pos = posicaoLivre(d, banco, lado, personagem)
		if pos then
			local olhar = d.chassi.CFrame.RightVector * lado
			raiz.AssemblyLinearVelocity = Vector3.zero
			raiz.AssemblyAngularVelocity = Vector3.zero
			mover(CFrame.lookAt(pos, pos + Vector3.new(olhar.X, 0, olhar.Z)))
			return
		end
	end
	-- os dois lados bloqueados: acima do teto, nunca dentro do carro
	local topo = d.chassi.CFrame:PointToWorldSpace(Vector3.new(0, d.chassi.Size.Y / 2 + 3.5, 0))
	mover(CFrame.new(topo))
end

local function pedirSair(jogador: Player)
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local assento = humanoide and humanoide.SeatPart
	local d = assento and dadoDoBanco[assento]
	if not (humanoide and assento and d) or not Limite.ok(jogador, "SairCarro", 0.3) then
		return
	end
	local solda = assento:FindFirstChild("SeatWeld")
	if solda then
		solda:Destroy() -- o Occupant vira nil: o ouvinte em ativar() faz colocarAoLado
	else
		humanoide.Sit = false
	end
end

local function tentarLigar(d: Dado, jogador: Player)
	local pos = d.chassi.Position
	if d.estado.combustivel <= 0 then
		aviso(jogador, "Sem gasolina")
		return
	end
	if Regra.tentarLigar(d.estado, aleatorio, Cfg) then
		d.ligado = true
		ligados[d] = true
		d.proxRuido = 0
		d.modelo:SetAttribute("MotorLigado", true)
		Sons.tocar("MotorPartida", d.chassi, { db = CfgSom.acoes.carroLigar })
		if not d.somMotor then
			d.somMotor = Sons.loop("MotorLoop", d.chassi, { db = d.tipo.dbBase })
		end
		Ruido.emitirAcao("carroLigar", pos, jogador)
	else
		Sons.tocar("MotorFalha", d.chassi, { db = CfgSom.acoes.carroFalhar })
		Ruido.emitirAcao("carroFalhar", pos, jogador)
		aviso(jogador, "O motor não pegou")
	end
end

-- Efeitos do que um Resultado quebrou (som e ruído); `fonte` é quem causou.
local function efeitos(d: Dado, res: any, fonte: Player?)
	local pos = d.chassi.Position
	if #res.vidros > 0 then
		Sons.tocar("Vidro", pos)
		Ruido.emitirAcao("vidro", pos, fonte)
	end
	if #res.pneus > 0 then
		Sons.tocar("PneuEstouro", pos, { db = CfgSom.acoes.pneuEstouro })
		Ruido.emitirAcao("pneuEstouro", pos, fonte)
	end
	if res.motorQuebrou then
		desligar(d)
	end
end

-- Destruicao (docs/destruicao.md §6.3): require preguiçoso e protegido; se ela faltar, o carro segue sem destruir nada.
local function destruicao(): any
	local ok, m = pcall(require, script.Parent.Destruicao)
	return if ok then m else nil
end

-- Dano direto à carroceria (o que o carro destruiu). Carroceria 0 com motor > 0: motor morto e desligado.
local function danoCarroceria(d: Dado, dano: number, fonte: Player?)
	if dano <= 0 then
		return
	end
	local novo, res = Regra.acertar(d.estado, "Carroceria", dano, aleatorio, Cfg)
	if novo.carroceria <= 0 and novo.motor > 0 then
		novo.motor = 0
		desligar(d)
	end
	aplicarEstado(d, novo)
	efeitos(d, res, fonte)
end

local function processarBatida(d: Dado, delta: Vector3, deltaV: number, antes: Vector3, depois: Vector3)
	local local3 = d.chassi.CFrame:VectorToObjectSpace(-delta)
	local lado = Regra.direcaoBatida(local3.X, local3.Z)
	local novo, res = Regra.bater(d.estado, deltaV, lado, aleatorio, Cfg)
	aplicarEstado(d, novo)
	local pos = d.chassi.Position
	Sons.tocar("CarroBatida", d.chassi, { db = CfgSom.acoes.carroBatida })
	Ruido.emitirAcao("carroBatida", pos, d.motorista)
	efeitos(d, res, d.motorista)
	local dano = Regra.danoOcupante(deltaV, Cfg)
	if dano > 0 then
		for _, banco in d.bancos do
			local jogador = jogadorDoBanco(banco)
			if jogador then
				Vida.dano(jogador, nil, dano, { tipo = "batida" })
			end
		end
	end
	-- o que a batida destruiu (parede, cerca...) custa carroceria; o dano da batida em si é o de Regra.bater, acima
	local D = destruicao()
	if D then
		local ok, custo = pcall(D.impactoCarro, d.chassi, antes, depois, d.chassi.AssemblyMass, d.motorista)
		if ok and type(custo) == "number" and custo > 0 then
			danoCarroceria(d, custo, d.motorista)
		end
	end
end

-- Anti-trapaça: velocidade muito acima do limite por TEMPO_EXCESSO → o servidor pega a física e freia.
local function retomarPosse(d: Dado, jogador: Player)
	d.excesso = 0
	d.vAnterior = nil
	VeiculoModelo.freiar(d.modelo, true)
	VeiculoModelo.ancorar(d.modelo, true)
	aviso(jogador, "Velocidade impossível: o carro foi freado")
	warn(
		string.format(
			"[Veiculos] %s acima de %.1fx a velocidade máxima: física retomada",
			jogador.Name,
			TOLERANCIA_VEL
		)
	)
	task.delay(PAUSA_RETOMADA, function()
		if d.motorista == jogador and d.chassi.Parent then
			VeiculoModelo.ancorar(d.modelo, false)
			VeiculoModelo.freiar(d.modelo, false)
			VeiculoModelo.definirDono(d.modelo, jogador)
		end
	end)
end

local function atualizarOcupado(d: Dado, agora: number, tickSom: boolean)
	local chassi = d.chassi
	local v = chassi.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z)
	local velocidade = plano.Magnitude
	local velMax = d.lim.velMax

	-- batida: variação brusca da velocidade horizontal entre duas amostras
	local anterior = d.vAnterior
	if anterior then
		local delta = plano - Vector3.new(anterior.X, 0, anterior.Z)
		local dv = delta.Magnitude
		if dv >= Cfg.batida.limiarDeltaV and agora - d.ultimaBatida >= INTERVALO_BATIDA then
			d.ultimaBatida = agora
			processarBatida(d, delta, dv, anterior, v)
		end
	end
	d.vAnterior = v

	-- destruição: o carro rápido atravessa construção fraca e atropela monstro (docs/destruicao.md §6.3)
	local D = if d.motorista then destruicao() else nil
	if D and velocidade >= CfgDestruicao.carro.velMin then
		local ok, r = pcall(D.varrerCarro, chassi, v, chassi.AssemblyMass, d.motorista)
		if ok and r and r.custoCarroceria > 0 then
			danoCarroceria(d, r.custoCarroceria, d.motorista)
		end
	end

	-- derrapagem (freio de mão): pneu cantando é barulho, e barulho atrai monstro
	if d.motorista and agora >= d.proxDerrapagem then
		local lateral = plano:Dot(chassi.CFrame.RightVector)
		if Regra.derrapando(velocidade, lateral, Cfg) then
			d.proxDerrapagem = agora + Cfg.derrapagem.intervalo
			Ruido.emitirAcao("carroDerrapar", chassi.Position, d.motorista)
		end
	end

	if d.motorista then
		if velMax > 0 and velocidade > velMax * TOLERANCIA_VEL then
			d.excesso += PASSO
			if d.excesso >= TEMPO_EXCESSO then
				retomarPosse(d, d.motorista)
			end
		else
			d.excesso = math.max(0, d.excesso - PASSO)
		end
	end

	if d.ligado then
		if d.estado.motor <= 0 then
			desligar(d)
			return
		end
		local fracao = if velMax > 0 then math.clamp(velocidade / velMax, 0, 1) else 0
		if agora >= d.proxRuido then
			d.proxRuido = agora + Cfg.ruido.intervaloMotor
			Ruido.emitir(chassi.Position, Regra.dbMotor(d.estado, fracao, Cfg), "carro", d.motorista)
		end
		if tickSom and d.somMotor then
			d.somMotor.PlaybackSpeed = VELOCIDADE_SOM_BASE + VELOCIDADE_SOM_ALCANCE * fracao
		end
	end
end

-- Grava o nível no atributo Combustivel (1 casa) só quando varia >= passoAtributo (ou `forcar`); SemCombustivel sempre em dia.
local function publicarCombustivel(d: Dado, forcar: boolean)
	local nivel = d.estado.combustivel
	if forcar or math.abs(nivel - d.nivelPublicado) >= CfgComb.passoAtributo then
		d.nivelPublicado = nivel
		d.modelo:SetAttribute("Combustivel", VeiculoModelo.arredondarLitros(nivel))
	end
	d.modelo:SetAttribute("SemCombustivel", nivel <= 0)
end

-- Consumo de um carro ligado por `dt` s. Pedal = |ThrottleFloat| do VehicleSeat do motorista (replicado pelo cliente dele).
local function consumirCombustivel(d: Dado, dt: number)
	local e = d.estado
	local velMax = d.lim.velMax
	local chassi = d.chassi
	local aoLongo = math.abs(chassi.AssemblyLinearVelocity:Dot(chassi.CFrame.LookVector))
	local fracVel = if velMax > 0 then math.clamp(aoLongo / velMax, 0, 1) else 0
	local pedal = if d.motorista then math.clamp(math.abs((d.bancos[1] :: any).ThrottleFloat), 0, 1) else 0
	e.combustivel = RegraComb.consumir(e.combustivel, dt, d.tipo.tanque, fracVel, pedal, CfgComb)
	if e.combustivel <= 0 then
		-- acabou: o motor morre e faz barulho (ação "carro" de Config/Som)
		publicarCombustivel(d, true)
		desligar(d)
		Ruido.emitirAcao("carro", chassi.Position, d.motorista)
		if d.motorista then
			aviso(d.motorista, "Sem gasolina")
		end
		return
	end
	publicarCombustivel(d, false)
end

local function iniciarLacos()
	-- carros com gente: batida, anti-trapaça, destruição, ruído e som do motor (10 Hz)
	task.spawn(function()
		local contador = 0
		while true do
			task.wait(PASSO)
			contador += 1
			local agora = os.clock()
			for _, d in dados do
				if not d.chassi.Parent then
					continue
				end
				if d.motorista or d.ocupado then
					local ok, erro = pcall(atualizarOcupado, d, agora, contador % 2 == 0)
					if not ok then
						warn("[Veiculos] erro no laço: " .. tostring(erro))
					end
				elseif d.estacionarAte then
					-- sem ocupante e ainda andando: freado; ancora ao parar ou no prazo
					if d.chassi.AssemblyLinearVelocity.Magnitude <= VEL_ESTACIONAR or agora >= d.estacionarAte then
						d.estacionarAte = nil
						d.dormindo = true
						VeiculoModelo.ancorar(d.modelo, true)
					end
				end
			end
		end
	end)
	-- combustível: UM laço para todo carro com o motor ligado (com ou sem motorista), 5 Hz
	task.spawn(function()
		local anterior = os.clock()
		while true do
			task.wait(PASSO_COMBUSTIVEL)
			local agora = os.clock()
			local dt = agora - anterior
			anterior = agora
			for d in ligados do
				if d.chassi.Parent then
					local ok, erro = pcall(consumirCombustivel, d, dt)
					if not ok then
						warn("[Veiculos] erro no combustível: " .. tostring(erro))
					end
				else
					ligados[d] = nil
				end
			end
		end
	end)
end

-- Liga um modelo recém-criado ao servidor: bancos, prompts de entrada, porta-malas.
local function ativar(modelo: Model, estado: Estado): Dado
	local tipo = Cfg.tipos[estado.tipo]
	local chassi = modelo.PrimaryPart :: BasePart
	local bancos: { Seat } = {}
	for i = 1, tipo.assentos do
		local b = modelo:FindFirstChild("Banco" .. i)
		-- VehicleSeat não herda de Seat
		if b and (b:IsA("Seat") or b:IsA("VehicleSeat")) then
			table.insert(bancos, b :: any)
		end
	end
	local d: Dado = {
		modelo = modelo,
		estado = estado,
		lim = Regra.limites(estado, Cfg),
		tipo = tipo,
		chassi = chassi,
		bancos = bancos,
		motorista = nil,
		ligado = false,
		dormindo = true,
		vAnterior = nil,
		excesso = 0,
		proxRuido = 0,
		proxDerrapagem = 0,
		ultimaBatida = -math.huge,
		somMotor = nil,
		ocupado = false,
		dono = nil,
		estacionarAte = nil,
		desde = {},
		trocando = {},
		nivelPublicado = estado.combustivel,
	}
	dados[modelo] = d
	VeiculoModelo.freiar(modelo, true)

	for _, banco in bancos do
		dadoDoBanco[banco] = d
		local anterior: Humanoid? = nil
		banco:GetPropertyChangedSignal("Occupant"):Connect(function()
			local ocupante = banco.Occupant
			reavaliar(d)
			if ocupante == nil and anterior then
				local saiu = anterior
				anterior = nil
				local quem = saiu.Parent and Players:GetPlayerFromCharacter(saiu.Parent)
				if not (quem and d.trocando[quem]) then -- trocar de banco não é sair
					colocarAoLado(d, banco, saiu)
				end
			elseif ocupante then
				modelo:SetAttribute("Mexido", true)
				anterior = ocupante
				if ocupante.Parent then
					grupoDoPersonagem(ocupante.Parent, GRUPO_OCUPANTE)
				end
			end
		end)
	end

	if not estado.queimado then
		for _, nome in { "PortaE", "PortaD" } do
			local porta = modelo:FindFirstChild(nome)
			if porta and porta:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Entrar"
				prompt.ObjectText = tipo.nome
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = CfgItens.alcanceInteracao
				prompt.RequiresLineOfSight = false
				prompt.Parent = porta
				prompt.Triggered:Connect(function(jogador: Player)
					entrar(d, jogador, porta)
				end)
			end
		end
		local malas = modelo:FindFirstChild("PortaMalas")
		if malas and malas:IsA("BasePart") and not estado.faltando.PortaMalas then
			Loot.registrarCompartimento(malas, "portaMalas", "Porta-malas")
		end
	end

	modelo.Destroying:Connect(function()
		ligados[d] = nil
		if d.motorista then
			porMotorista[d.motorista] = nil
		end
		for _, banco in bancos do
			dadoDoBanco[banco] = nil
		end
		dados[modelo] = nil
	end)
	return d
end

local function nascer(estado: Estado, cf: CFrame): Model
	local modelo = VeiculoModelo.criar(estado, cf)
	ativar(modelo, estado)
	VeiculoModelo.assentar(modelo, estado) -- pose pelo estado (queimado no chão, pneu ruim inclina)
	VeiculoModelo.encostar(modelo) -- nunca flutua
	return modelo
end

-- CFrame no chão do prop `carro`: o prop não tem pivô definido, então lê a orientação da maior peça (a carroceria) e o
-- centro/chão do conjunto. Devolve nil para carro tombado (variante "deitado" de carro_destruido).
local function pivoDoProp(prop: Model): CFrame?
	local maior: BasePart? = nil
	local volumeMaior = -1
	for _, p in prop:GetChildren() do
		if p:IsA("BasePart") then
			local volume = p.Size.X * p.Size.Y * p.Size.Z
			if volume > volumeMaior then
				maior, volumeMaior = p, volume
			end
		end
	end
	if not maior or maior.CFrame.UpVector.Y < 0.9 then
		return nil
	end
	local frente = Vector3.new(maior.CFrame.LookVector.X, 0, maior.CFrame.LookVector.Z)
	if frente.Magnitude < 0.1 then
		return nil
	end
	frente = frente.Unit
	local direita = frente:Cross(Vector3.yAxis)
	local minD, maxD, minF, maxF, minY = math.huge, -math.huge, math.huge, -math.huge, math.huge
	for _, p in prop:GetChildren() do
		if p:IsA("BasePart") then
			local pos = p.Position
			local d, f = pos:Dot(direita), pos:Dot(frente)
			minD, maxD = math.min(minD, d), math.max(maxD, d)
			minF, maxF = math.min(minF, f), math.max(maxF, f)
			local c, s = p.CFrame, p.Size
			local meia = 0.5
				* (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z)
			minY = math.min(minY, pos.Y - meia)
		end
	end
	local centro = direita * ((minD + maxD) / 2) + frente * ((minF + maxF) / 2)
	local origem = Vector3.new(centro.X, minY, centro.Z)
	return CFrame.lookAt(origem, origem + frente)
end

-- Prop tombado/de lado/de cabeça para baixo: usa a rotação da maior peça (mesma convenção do prop em pé) e o centro do
-- conjunto. A altura é ajustada depois por VeiculoModelo.encostar.
local function pivoDeitado(prop: Model): CFrame?
	local maior: BasePart? = nil
	local volumeMaior = -1
	local soma, n = Vector3.zero, 0
	for _, p in prop:GetChildren() do
		if p:IsA("BasePart") then
			soma += p.Position
			n += 1
			local volume = p.Size.X * p.Size.Y * p.Size.Z
			if volume > volumeMaior then
				maior, volumeMaior = p, volume
			end
		end
	end
	if not maior or n == 0 then
		return nil
	end
	return CFrame.new(soma / n) * maior.CFrame.Rotation
end

local PASTAS_GIGANTES =
	{ Chao = true, Ruas = true, Vegetacao = true, Zonas = true, Pontos = true, Rios = true, Bordas = true }

local function coletarProps(): { Model }
	local achados: { Model } = {}
	local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
	if not mapa then
		warn("[Veiculos] workspace.Mapa não existe: nenhum carro criado")
		return achados
	end
	local pilha: { Instance } = {}
	for _, nome in { "Props", "Construcoes" } do
		local pasta = mapa:WaitForChild(nome, ESPERA_MAPA)
		if pasta then
			table.insert(pilha, pasta)
		else
			warn("[Veiculos] workspace.Mapa." .. nome .. " não existe")
		end
	end
	local visitados = 0
	while #pilha > 0 do
		local atual = table.remove(pilha) :: Instance
		for _, filho in atual:GetChildren() do
			visitados += 1
			if visitados % LOTE_VARREDURA == 0 then
				task.wait()
			end
			if filho:IsA("Model") then
				local nome = filho:GetAttribute("Prop")
				if nome == "carro" or nome == "carro_destruido" then
					table.insert(achados, filho)
				elseif nome == nil then
					table.insert(pilha, filho)
				end
			elseif filho:IsA("Folder") and not PASTAS_GIGANTES[filho.Name] then
				table.insert(pilha, filho)
			end
		end
	end
	return achados
end

-- Carro novo (maior que o prop de 11 studs) colide com construção/árvore/outro carro? Ignora chão, ruas, zonas, o próprio prop
-- e outros props de carro (que podem ou não virar carro). A caixa começa 1.2 studs acima do chão: ladeira e meio-fio não contam.
local PASTAS_IGNORADAS = { "Chao", "Ruas", "Zonas", "Pontos", "Rios" }
local ELEVACAO_TESTE = 1.2

local function colideComMapa(prop: Model, estado: Estado, cf: CFrame, escala: number?): boolean
	local k = escala or 1
	local tipo = Cfg.tipos[estado.tipo]
	local m = Malhas.tipos and Malhas.tipos[estado.tipo]
	local t = if m and m.dimensoes then m.dimensoes else tipo.tamanho
	local sx, sy, sz = (t.x or t[1]) * k, (t.y or t[2]) * k, (t.z or t[3]) * k
	local ignorar: { Instance } = { prop }
	local mapa = workspace:FindFirstChild("Mapa")
	if mapa then
		for _, nome in PASTAS_IGNORADAS do
			local pasta = mapa:FindFirstChild(nome)
			if pasta then
				table.insert(ignorar, pasta)
			end
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignorar
	local altura = sy - ELEVACAO_TESTE
	local caixa = cf * CFrame.new(0, ELEVACAO_TESTE + altura / 2, 0)
	for _, p in workspace:GetPartBoundsInBox(caixa, Vector3.new(sx * 0.95, altura, sz * 0.95), op) do
		if p.CanCollide and not p:IsDescendantOf(prop) then
			local modeloProp = p:FindFirstAncestorOfClass("Model")
			local ehOutroProp = false
			while modeloProp do
				local n = modeloProp:GetAttribute("Prop")
				if n == "carro" or n == "carro_destruido" then
					ehOutroProp = true
					break
				end
				modeloProp = modeloProp:FindFirstAncestorOfClass("Model")
			end
			if not ehOutroProp then
				return true
			end
		end
	end
	return false
end

-- Vagas do mapa: o servidor só DECIDE na abertura (estado fixo por vaga); o modelo é criado e removido sob demanda
-- (laço de materialização) conforme a distância dos jogadores. Ver docs/veiculos.md, "Carros do mapa sob demanda".
type Vaga = { cf: CFrame, estado: Estado, deitado: boolean, destruido: boolean, modelo: Model?, morta: boolean }
local vagas: { Vaga } = {}

local function filtroPreso(todos: { Model }): RaycastParams
	local ignorar: { Instance } = { workspace.Terrain }
	local mapa = workspace:FindFirstChild("Mapa")
	if mapa then
		for _, nome in PASTAS_IGNORADAS do
			local pasta = mapa:FindFirstChild(nome)
			if pasta then
				table.insert(ignorar, pasta)
			end
		end
	end
	for _, p in todos do
		table.insert(ignorar, p)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignorar
	params.RespectCanCollide = true
	return params
end

-- Preso: os DOIS sentidos (frente e ré) bloqueados por geometria colidível a menos de Cfg.mapa.presoDistancia.
local function podeSair(estado: Estado, cf: CFrame, params: RaycastParams): boolean
	local tipo = Cfg.tipos[estado.tipo]
	local m = Malhas.tipos and Malhas.tipos[estado.tipo]
	local t = if m and m.dimensoes then m.dimensoes else tipo.tamanho
	local sx, sy, sz = t.x or t[1], t.y or t[2], t.z or t[3]
	local c = Cfg.mapa
	local altura = math.max(sy - c.presoElevacao, 0.5)
	local caixa = cf * CFrame.new(0, c.presoElevacao + altura / 2, 0)
	local tamanho = Vector3.new(sx * 0.9, altura, sz * 0.9)
	for _, sentido in { 1, -1 } do
		local r = workspace:Blockcast(caixa, tamanho, cf.LookVector * sentido * c.presoAlcance, params)
		if not r or r.Distance >= c.presoDistancia then
			return true
		end
	end
	return false
end

local function nascerNoMapa()
	local t0 = os.clock()
	local props = coletarProps()
	for i = #props, 2, -1 do -- embaralha
		local j = rng:NextInteger(1, i)
		props[i], props[j] = props[j], props[i]
	end
	local n = { operacionais = 0, destruidos = 0, presos = 0, naoCoube = 0, sobrepostos = 0, tombados = 0, semPose = 0 }
	local analisados = 0
	local presoParams = filtroPreso(props)
	for _, prop in props do
		if not prop.Parent then
			continue
		end
		local cf = pivoDoProp(prop)
		local deitado = false
		if not cf then
			cf = pivoDeitado(prop)
			deitado = true
		end
		if not cf then
			n.semPose += 1
			continue
		end
		local destruido = deitado or prop:GetAttribute("Prop") == "carro_destruido"
		-- tipos em ordem aleatória
		local escolhido = sortearTipo()
		local ordem = { escolhido }
		for nome in Cfg.tipos do
			if nome ~= escolhido then
				table.insert(ordem, nome)
			end
		end
		for i = 2, #ordem do
			local j = rng:NextInteger(2, #ordem)
			ordem[i], ordem[j] = ordem[j], ordem[i]
		end

		local estado: Estado? = nil
		local cabe: string? = nil -- primeiro tipo que cabe (mesmo que preso)
		if deitado then
			cabe = ordem[1]
		else
			for _, tipo in ordem do
				local candidato = Regra.montar(tipo, nil, Cfg) :: Estado
				if not colideComMapa(prop, candidato, cf) then
					cabe = cabe or tipo
					if not destruido and podeSair(candidato, cf, presoParams) then
						local motor, carroceria = Cfg.mapa.motor, Cfg.mapa.carroceria
						-- gasolina como em Regra.sortear: às vezes vazio, senão entre min e max do tanque
						local gas = Cfg.condicoes.combustivel
						local fracaoGas = if aleatorio() < gas.chanceVazio
							then 0
							else gas.min + aleatorio() * (gas.max - gas.min)
						estado = Regra.montar(tipo, {
							motor = motor[1] + aleatorio() * (motor[2] - motor[1]),
							carroceria = carroceria[1] + aleatorio() * (carroceria[2] - carroceria[1]),
							combustivel = fracaoGas,
						}, Cfg)
						break
					end
					if destruido then
						break
					end
				end
			end
		end
		if estado then
			n.operacionais += 1
		elseif cabe then
			estado = sortearEstado(cabe, { "destruido", "queimado" })
			if deitado then
				n.tombados += 1
				n.destruidos += 1
			elseif destruido then
				n.destruidos += 1
			else
				n.presos += 1
			end
		else
			-- nenhum tipo cabe: o menor (compacto) destruído, caixa relaxada; aceita sobreposição leve
			local menor = if Cfg.tipos.compacto then "compacto" else ordem[1]
			estado = sortearEstado(menor, { "destruido", "queimado" })
			n.naoCoube += 1
			if colideComMapa(prop, estado, cf, Cfg.mapa.escalaRelaxada) then
				n.sobrepostos += 1
			end
		end
		prop:Destroy()
		table.insert(
			vagas,
			{ cf = cf, estado = estado, deitado = deitado, destruido = destruido, modelo = nil, morta = false }
		)
		analisados += 1
		if analisados % 3 == 0 then
			task.wait()
		end
	end
	Veiculos.resumoVagas = {
		total = #vagas,
		operacionais = n.operacionais,
		destruidos = n.destruidos,
		presos = n.presos,
		naoCoube = n.naoCoube,
		sobrepostos = n.sobrepostos,
		tempo = os.clock() - t0,
	}
	print(
		string.format(
			"[Veiculos] %d vagas decididas em %.1f s (de %d props): %d operacionais, %d destruidos/queimados (%d tombados), %d presos, %d nao couberam (%d ainda sobrepostos), %d sem pose",
			#vagas,
			os.clock() - t0,
			#props,
			n.operacionais,
			n.destruidos + n.presos + n.naoCoube,
			n.tombados,
			n.presos,
			n.naoCoube,
			n.sobrepostos,
			n.semPose
		)
	)
end

-- Carro de vaga "mexido": alguém sentou, ele levou dano/tiro/batida ou foi solto da âncora. Nunca é removido nem recriado.
local function mexido(v: Vaga): boolean
	local m = v.modelo
	if not m then
		return false
	end
	if m:GetAttribute("Mexido") then
		return true
	end
	local d = dados[m]
	if d and (d.motorista ~= nil or not d.chassi.Anchored) then
		m:SetAttribute("Mexido", true)
		return true
	end
	return false
end

local function distanciaMinima(posicoes: { Vector3 }, ponto: Vector3): number
	local menor = math.huge
	for _, p in posicoes do
		menor = math.min(menor, (p - ponto).Magnitude)
	end
	return menor
end

local function lacoMaterializar()
	local c = Cfg.mapa
	while true do
		task.wait(c.intervalo)
		local posicoes: { Vector3 } = {}
		for _, j in Players:GetPlayers() do
			local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") then
				table.insert(posicoes, raiz.Position)
			end
		end
		local criados = 0
		for _, v in vagas do
			if v.morta then
				continue
			end
			local dist = distanciaMinima(posicoes, v.cf.Position)
			local modelo = v.modelo
			if modelo then
				if not modelo.Parent then
					v.morta = true -- destruído por outro sistema: não volta
				elseif dist > c.raioRemover and not mexido(v) then
					v.modelo = nil
					modelo:Destroy()
				end
			elseif dist < c.raioCriar and criados < c.criarPorCiclo then
				criados += 1
				local ok, novo = pcall(nascer, v.estado, v.cf)
				if ok then
					v.modelo = novo
				else
					v.morta = true
					warn("[Veiculos] falha ao criar carro: " .. tostring(novo))
				end
			end
		end
	end
end

-- Peça do veículo atingida por tiro/golpe. true se a peça é de veículo (o chamador não resolve mais nada).
function Veiculos.acerto(peca: BasePart, dano: number, atacante: Player?): boolean
	local modelo = peca:FindFirstAncestorOfClass("Model")
	local d = modelo and dados[modelo]
	if not d then
		return false
	end
	local nome = peca:GetAttribute("PecaVeiculo")
	if dano > 0 then
		d.modelo:SetAttribute("Mexido", true)
	end
	if type(nome) == "string" and dano > DANO_TIRO_MINIMO then
		local novo, res = Regra.acertar(d.estado, nome, dano, aleatorio, Cfg)
		aplicarEstado(d, novo)
		efeitos(d, res, atacante)
	end
	return true
end

-- Dano direto à carroceria (explosão, marreta futura...). Carroceria 0 = motor morto e desligado.
function Veiculos.danoCarroceria(modelo: Model, dano: number, fonte: Player?)
	local d = dados[modelo]
	if d then
		d.modelo:SetAttribute("Mexido", true)
		danoCarroceria(d, dano, fonte)
	end
end

-- Rastejador (docs/rastejador.md §5.4): veículo vivo (não queimado) mais perto de `posicao`, até `raio` studs do chassi.
function Veiculos.maisPertoDe(posicao: Vector3, raio: number): Model?
	local melhor: Model? = nil
	local menor = raio
	for modelo, d in dados do
		if modelo.Parent and not d.estado.queimado then
			local dist = (d.chassi.Position - posicao).Magnitude
			if dist <= menor then
				melhor, menor = modelo, dist
			end
		end
	end
	return melhor
end

function Veiculos.estadoDe(modelo: Model): Estado?
	local d = dados[modelo]
	return d and d.estado
end

-- Combustível (docs/combustivel.md §10): usado por server/Combustivel (posto, mangueira, recipientes).
function Veiculos.combustivelDe(modelo: Model): (number, number)
	local d = dados[modelo]
	if not d then
		return 0, 0
	end
	return d.estado.combustivel, d.tipo.tanque
end

-- Põe `litros` no tanque; devolve quantos couberam. Queimado não aceita.
function Veiculos.encher(modelo: Model, litros: number): number
	local d = dados[modelo]
	if not d or d.estado.queimado then
		return 0
	end
	local novo, aceito = RegraComb.encher(d.estado.combustivel, d.tipo.tanque, litros)
	if aceito > 0 then
		d.estado.combustivel = novo
		publicarCombustivel(d, true)
	end
	return aceito
end

function Veiculos.motorLigado(modelo: Model): boolean
	local d = dados[modelo]
	return d ~= nil and d.ligado
end

-- Passa o jogador sentado para o próximo banco livre do mesmo carro (circular). Quem chama já aplicou o Limite.
function Veiculos.trocarBanco(jogador: Player)
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local atual = humanoide and humanoide.SeatPart
	local d = atual and dadoDoBanco[atual]
	if not (humanoide and atual and d) or humanoide.Health <= 0 or d.trocando[jogador] then
		return
	end
	local n = #d.bancos
	local indice = table.find(d.bancos, atual :: any) or 1
	local destino: Seat? = nil
	for passo = 1, n - 1 do
		local candidato = d.bancos[(indice - 1 + passo) % n + 1]
		if candidato.Occupant == nil and not candidato.Disabled then
			destino = candidato
			break
		end
	end
	if not destino then
		aviso(jogador, "Sem banco livre")
		return
	end
	local novo = destino
	d.trocando[jogador] = true
	novo:Sit(humanoide)
	task.delay(ESPERA_TROCA / 2, function()
		-- o Sit não largou o banco antigo? solta a solda velha e senta de novo
		if d.trocando[jogador] and novo.Occupant ~= humanoide then
			local solda = atual:FindFirstChild("SeatWeld")
			if solda then
				solda:Destroy()
			end
			novo:Sit(humanoide)
		end
	end)
	task.delay(ESPERA_TROCA, function()
		d.trocando[jogador] = nil
		if d.chassi.Parent then
			reavaliar(d)
		end
	end)
end

local function maisPerto(jogador: Player): Dado?
	local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
	if not (raiz and raiz:IsA("BasePart")) then
		return nil
	end
	local melhor: Dado? = nil
	local menor = math.huge
	for _, d in dados do
		local dist = (d.chassi.Position - raiz.Position).Magnitude
		if dist < menor then
			melhor, menor = d, dist
		end
	end
	return melhor
end

-- Invocação pelo menu de admin ------------------------------------------------------------------------------------------
-- Um carro (ou um de cada tipo) em fila na frente do jogador, no chão, olhando para ele. Nascem ancorados e dirigíveis:
-- o primeiro que sentar acorda o carro. `pedido` é o estado pedido (Regras/Veiculo.montar valida tudo).
local invocados: { [Player]: { Model } } = {}

local function limparInvocados(jogador: Player)
	for _, m in invocados[jogador] or {} do
		if m.Parent then
			m:Destroy()
		end
	end
	invocados[jogador] = nil
end

local function solo(posicao: Vector3, ignorar: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignorar
	local r = workspace:Raycast(posicao + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
	return if r then r.Position else nil
end

-- Devolve quantos carros nasceram e o texto de resumo (para o Aviso do admin).
local function invocar(jogador: Player, tipo: any, todos: boolean, pedido: any): (number, string)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (personagem and raiz and raiz:IsA("BasePart")) then
		return 0, "sem personagem"
	end
	local tipos: { string } = {}
	if todos then
		for nome in Cfg.tipos do
			table.insert(tipos, nome)
		end
		table.sort(tipos)
	elseif type(tipo) == "string" and Cfg.tipos[tipo] then
		tipos = { tipo }
	else
		return 0, "tipo inválido"
	end

	local ajuste = CfgAdmin.invocar
	local frente = Vector3.new(raiz.CFrame.LookVector.X, 0, raiz.CFrame.LookVector.Z)
	frente = if frente.Magnitude > 0.1 then frente.Unit else Vector3.new(0, 0, -1)
	local direita = frente:Cross(Vector3.yAxis)
	local lista = invocados[jogador]
	if not lista then
		lista = {}
		invocados[jogador] = lista
	end
	local ignorar: { Instance } = { personagem }
	local pasta = workspace:FindFirstChild("Veiculos")
	if pasta then
		table.insert(ignorar, pasta)
	end
	local base = raiz.Position - Vector3.new(0, 3, 0)

	local criados = 0
	local ultimo = ""
	for i, nome in tipos do
		local estado = Regra.montar(nome, pedido, Cfg)
		if not estado then
			continue
		end
		local deslocamento = (i - (#tipos + 1) / 2) * ajuste.espacamento
		local alvo = base + frente * ajuste.distancia + direita * deslocamento
		local chao = solo(alvo, ignorar)
		local origem = Vector3.new(alvo.X, if chao then chao.Y else base.Y, alvo.Z)
		-- a frente do carro é -Z local: olha para o jogador
		local olhar = origem - frente
		local ok, modelo = pcall(nascer, estado, CFrame.lookAt(origem, Vector3.new(olhar.X, origem.Y, olhar.Z)))
		if not ok then
			warn("[Veiculos] invocar falhou: " .. tostring(modelo))
			continue
		end
		modelo:SetAttribute("Invocado", true)
		table.insert(lista, modelo)
		criados += 1
		ultimo = resumo(dados[modelo])
	end
	while #lista > ajuste.maxCarros do
		local velho = table.remove(lista, 1)
		if velho and velho.Parent then
			velho:Destroy()
		end
	end
	return criados, if criados == 1 then ultimo else criados .. " carros"
end

function Veiculos.invocar(jogador: Player, tipo: any, todos: boolean, pedido: any): (number, string)
	return invocar(jogador, tipo, todos, pedido)
end

function Veiculos.limparInvocados(jogador: Player)
	limparInvocados(jogador)
end

local function registrarTestes()
	Teste.registrar("carro", function(jogador: Player, tipo: string?, condicao: string?)
		local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		if not (raiz and raiz:IsA("BasePart")) then
			return "sem personagem"
		end
		local nomeTipo = tipo or sortearTipo()
		if not Cfg.tipos[nomeTipo] then
			return "tipo desconhecido: " .. tostring(nomeTipo)
		end
		local estado = sortearEstado(nomeTipo, if condicao then { condicao } else nil)
		local frente = Vector3.new(raiz.CFrame.LookVector.X, 0, raiz.CFrame.LookVector.Z)
		frente = if frente.Magnitude > 0.1 then frente.Unit else Vector3.new(0, 0, -1)
		local origem = raiz.Position + frente * 16 - Vector3.new(0, 3, 0)
		local modelo = nascer(estado, CFrame.lookAt(origem, origem + frente:Cross(Vector3.yAxis)))
		return "criado: " .. resumo(dados[modelo])
	end)
	-- Um carro de cada tipo em fila na frente do jogador (perfeitos, como no menu de admin; "preset" opcional: nome em
	-- Config/Admin.presetsCarro).
	Teste.registrar("carros", function(jogador: Player, preset: string?)
		local pedido = nil
		for _, p in CfgAdmin.presetsCarro do
			if preset and p.rotulo == preset then
				pedido = p.pedido
			end
		end
		local n, texto = invocar(jogador, nil, true, pedido)
		return n .. " carros: " .. texto
	end)
	Teste.registrar("carroEstado", function(jogador: Player)
		local d = maisPerto(jogador)
		if not d then
			return "nenhum carro"
		end
		local texto = resumo(d)
		print("[Veiculos] " .. texto)
		return texto
	end)
	Teste.registrar("carroDano", function(jogador: Player, peca: string?)
		local d = maisPerto(jogador)
		if not d then
			return "nenhum carro"
		end
		for _, p in d.modelo:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("PecaVeiculo") == peca then
				Veiculos.acerto(p, 50, jogador)
				return resumo(d)
			end
		end
		return "peça desconhecida: " .. tostring(peca)
	end)
end

function Veiculos.iniciar()
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, GRUPO_OCUPANTE)
	for _, grupo in { "VeiculoCorpo", "VeiculoRoda" } do
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, grupo)
		pcall(PhysicsService.CollisionGroupSetCollidable, PhysicsService, GRUPO_OCUPANTE, grupo, false)
	end
	task.spawn(VeiculoModelo.carregar) -- baixa os moldes já; criar() espera o fim se chegar antes
	Rede.evento("SairCarro").OnServerEvent:Connect(pedirSair)
	Rede.evento("TrocarBanco").OnServerEvent:Connect(function(jogador: Player)
		if Limite.ok(jogador, "TrocarBanco", 0.4) then
			Veiculos.trocarBanco(jogador)
		end
	end)
	Rede.evento("LigarMotor").OnServerEvent:Connect(function(jogador: Player)
		local d = porMotorista[jogador]
		if not d or not Limite.ok(jogador, "LigarMotor", 0.8) then
			return
		end
		if d.ligado then
			desligar(d)
		else
			tentarLigar(d, jogador)
		end
	end)
	Rede.evento("Farol").OnServerEvent:Connect(function(jogador: Player)
		local d = porMotorista[jogador]
		if not d or not Limite.ok(jogador, "Farol", 0.25) then
			return
		end
		VeiculoModelo.definirFarol(d.modelo, d.modelo:GetAttribute("FarolLigado") ~= true)
	end)
	Rede.evento("Buzina").OnServerEvent:Connect(function(jogador: Player)
		local d = porMotorista[jogador]
		if not d or not Limite.ok(jogador, "Buzina", 0.4) then
			return
		end
		Sons.tocar("Buzina", d.chassi, { db = CfgSom.acoes.buzina })
		Ruido.emitirAcao("buzina", d.chassi.Position, jogador)
	end)
	Players.PlayerRemoving:Connect(function(jogador)
		porMotorista[jogador] = nil
		limparInvocados(jogador)
	end)

	registrarTestes()
	iniciarLacos()
	task.spawn(nascerNoMapa)
	task.spawn(lacoMaterializar)
end

return Veiculos
