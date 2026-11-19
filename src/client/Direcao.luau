-- Direcao: dirigir (cliente). Sentado no VehicleSeat de um modelo com atributo Veiculo, lê ThrottleFloat/SteerFloat e
-- aplica nos HingeConstraint Motor_* (tração) e Dir_* (direção). O motorista é dono da física do carro, então a
-- escrita é local. Contrato: docs/veiculos.md. Sem MotorLigado as rodas ficam soltas.
-- Passageiro (Seat do mesmo modelo, docs/combustivel.md §7): estado.ativo = true e estado.motorista = false; não liga
-- pedais nem motores, só acompanha a velocidade. Teclas: E sai, F troca de banco (G/H só valem para o motorista).
-- Expõe Direcao.estado (para Cabine e HudVeiculo) e Direcao.aoMudar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Teclas = require(script.Parent.Teclas)
local Mouse = require(script.Parent.Mouse)
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Veiculo"))

local Direcao = {}

local jogador = Players.LocalPlayer

-- Padrões de afinação. Qualquer um pode ser sobrescrito em Config/Veiculos.direcao.
local PADRAO = {
	-- Mais ágil (2026-11-14): arranca e freia mais rápido, volante mais vivo e ajudas de aderência/giro.
	segundosAteMax = 3.2, -- s de 0 à velocidade máxima com o pedal no fundo
	folgaAceleracao = 24, -- studs/s: o comando nunca passa muito da velocidade real (evita acumular com o carro preso)
	segundosFreio = 0.7, -- s para parar da velocidade máxima
	segundosRolar = 7, -- s para parar sem pedal (freio-motor fraco)
	fatorRe = 0.4, -- marcha à ré = 40% da velocidade máxima
	torqueRolar = 0.12, -- fração do torque ao soltar o pedal
	torqueFreio = 4, -- múltiplo do torque ao frear
	limiarParado = 1.5, -- studs/s: abaixo disto o pedal contrário vira ré em vez de freio
	anguloMax = 34, -- graus das rodas parado (o servo do servidor limita em 35: AnguloDirecao)
	reducaoAngulo = 0.6, -- fração do ângulo que se perde na velocidade máxima
	grausPorSegundo = 260, -- rapidez de virar a roda
	grausPorSegundoVolta = 380, -- rapidez de voltar ao centro
	puxarGraus = 3.5, -- graus de desvio por unidade de Puxa na velocidade
	sinalMotor = 1, -- 1 ou -1: inverte o sentido global do motor se o modelo girar ao contrário
	sinalDirecao = 1, -- idem para a direção
	-- Freio de mão (segurar Shift): trava as rodas traseiras, solta o atrito delas e exagera o giro: o carro derrapa.
	freioMaoDesaceleracao = 0.45, -- fração do freio normal aplicada ao comando sem pedal
	freioMaoAtritoTraseiro = 0.35, -- atrito (máx.) das rodas traseiras com o freio puxado
	freioMaoGuinada = 1.4, -- multiplicador do giro-alvo (rotação do carro) com o freio puxado
	-- Ajudas de condução (só com o carro no chão e acima de velMinAjuda)
	aderenciaLateral = 4.5, -- 1/s: parte do deslize lateral cortada por segundo (carro "colado" ao asfalto)
	aderenciaLateralFreioMao = 0.6, -- idem com o freio puxado (deixa deslizar, só amortece)
	ajudaGuinada = 5, -- 1/s: rapidez com que o giro do carro segue o das rodas (resposta imediata ao volante)
	guinadaMax = 2.6, -- rad/s: teto do giro-alvo
	contraVolante = 0.45, -- graus de volante automático por stud/s de deslize acima do limiar
	contraVolanteLimiar = 3, -- studs/s de deslize lateral abaixo dos quais não corrige
	contraVolanteMax = 14, -- graus
	velMinAjuda = 4, -- studs/s
}

local cfg: any = nil
local params: any = PADRAO

local estado = {
	ativo = false,
	motorista = false, -- true: banco é o VehicleSeat (Banco1); false: passageiro (Seat)
	modelo = nil :: Model?,
	banco = nil :: BasePart?, -- VehicleSeat ou Seat; o nome é "BancoN" (N = índice do banco)
	steer = 0, -- -1..1: ângulo atual / máximo (direita positivo)
	angulo = 0, -- graus, direita positivo
	velocidade = 0, -- studs/s ao longo da frente (sinal: + frente)
	fracao = 0, -- |velocidade| / VelMax, 0..1
	pedal = 0, -- ThrottleFloat atual
	freando = false,
	freioMao = false, -- Shift segurado (ou botão de toque): rodas traseiras travadas, o carro derrapa
	deslize = 0, -- studs/s de velocidade lateral (direita positivo): a Cabine inclina o horizonte com isto
}
Direcao.estado = estado

local ouvintes: { (boolean, Model?, BasePart?) -> () } = {}
function Direcao.aoMudar(fn: (boolean, Model?, BasePart?) -> ())
	table.insert(ouvintes, fn)
end

local function num(valor: any, padrao: number): number
	if type(valor) == "number" and valor == valor then
		return valor
	end
	return padrao
end

local function carregarConfig()
	local pasta = Shared:WaitForChild("Config")
	local modulo = pasta:WaitForChild("Veiculos", 10)
	if modulo then
		local ok, valor = pcall(require, modulo)
		if ok then
			cfg = valor
		else
			warn("[Direcao] erro ao ler Config/Veiculos: " .. tostring(valor))
		end
	else
		warn("[Direcao] Config/Veiculos ausente")
	end
	params = table.clone(PADRAO)
	if type(cfg) == "table" and type(cfg.direcao) == "table" then
		for chave, valor in cfg.direcao do
			if type(valor) == "number" then
				params[chave] = valor
			end
		end
	end
end

-- Rodas e constraints do carro atual ---------------------------------------------------------------------------

type Motor = { constraint: HingeConstraint, raio: number, sinal: number, traseira: boolean }
type Servo = { constraint: HingeConstraint, sinal: number }

local motores: { Motor } = {}
local servos: { Servo } = {}
local rodasTraseiras: { BasePart } = {}
local atritoOriginal: { [BasePart]: PhysicalProperties? | boolean } = {} -- false = a roda não tinha propriedades próprias
local atritoSolto = false -- true enquanto o atrito das rodas traseiras está reduzido pelo freio de mão
local entreEixos = 10 -- studs, medido nos Susp_FE/Susp_TD do chassi
local alturaSolo = 4.5 -- studs: alcance do raio que confere se o carro está no chão
local filtroSolo = RaycastParams.new()
filtroSolo.FilterType = Enum.RaycastFilterType.Exclude
local freioMaoToque = false -- botão de toque segurado
local teclasFreioMao: { Enum.KeyCode } = {}
local ultimaVarredura = 0
local velocidadeComando = 0 -- studs/s com sinal: alvo de rotação das rodas

local function chassiDe(modelo: Model): BasePart?
	local c = modelo.PrimaryPart or modelo:FindFirstChild("Chassi")
	if c and c:IsA("BasePart") then
		return c
	end
	return nil
end

-- Sentido do eixo: Motor positivo gira Attachment1 em relação a Attachment0. Se Attachment0 estiver na roda, inverte.
local function eixoMundo(c: HingeConstraint): Vector3?
	local a0 = c.Attachment0
	if not a0 then
		return nil
	end
	return a0.WorldAxis
end

local function varrer(modelo: Model)
	table.clear(motores)
	table.clear(servos)
	table.clear(rodasTraseiras)
	local chassi = chassiDe(modelo)
	if not chassi then
		return
	end
	-- entre-eixos e altura do chassi ao chão (para as ajudas de condução)
	local aFE, aTD = chassi:FindFirstChild("Susp_FE"), chassi:FindFirstChild("Susp_TD")
	if aFE and aTD and aFE:IsA("Attachment") and aTD:IsA("Attachment") then
		entreEixos = math.max(1, math.abs(aTD.Position.Z - aFE.Position.Z))
	end
	alturaSolo = chassi.Size.Y / 2 + num(modelo:GetAttribute("RaioRoda"), 1.2) + 0.8
	for _, nome in { "Roda_TE", "Roda_TD" } do
		local roda = modelo:FindFirstChild(nome, true)
		if roda and roda:IsA("BasePart") then
			table.insert(rodasTraseiras, roda)
		end
	end
	local frente = chassi.CFrame.LookVector
	local cima = Vector3.yAxis
	local cima_x_frente = cima:Cross(frente)
	for _, filho in modelo:GetDescendants() do
		if not filho:IsA("HingeConstraint") then
			continue
		end
		local sufixo = filho.Name:match("^Motor_(%u+)$")
		local dir = filho.Name:match("^Dir_(%u+)$")
		if sufixo then
			local roda = modelo:FindFirstChild("Roda_" .. sufixo, true)
			local raio = 1.2
			if roda and roda:IsA("BasePart") then
				raio = math.max(roda.Size.Y, roda.Size.Z) / 2
			end
			local eixo = eixoMundo(filho)
			local sinal = 1
			if eixo then
				sinal = if eixo:Dot(cima_x_frente) >= 0 then 1 else -1
				local a0 = filho.Attachment0
				if a0 and a0.Parent and a0.Parent.Name:match("^Roda_") then
					sinal = -sinal
				end
			end
			table.insert(motores, {
				constraint = filho,
				raio = math.max(raio, 0.3),
				sinal = sinal * params.sinalMotor,
				traseira = sufixo == "TE" or sufixo == "TD",
			})
		elseif dir then
			local eixo = eixoMundo(filho)
			-- virar à direita = girar negativo em torno do eixo vertical (Attachment0 fica no lado fixo: Suporte)
			local sinal = if eixo and eixo.Y < 0 then 1 else -1
			table.insert(servos, { constraint = filho, sinal = sinal * params.sinalDirecao })
		end
	end
end

-- `travarTraseiras`: torque com que as rodas traseiras seguram em 0 (freio de mão); nil = andam como as da frente.
local function aplicarMotores(velocidadeAlvo: number, torque: number, travarTraseiras: number?)
	for _, m in motores do
		local c = m.constraint
		if c.Parent then
			if travarTraseiras and m.traseira then
				c.MotorMaxTorque = travarTraseiras
				c.AngularVelocity = 0
			else
				c.MotorMaxTorque = torque
				c.AngularVelocity = velocidadeAlvo / m.raio * m.sinal
			end
		end
	end
end

-- Freio de mão puxado: rodas traseiras com atrito baixo (o carro rabeia). Solto: volta ao atrito de antes. A escrita é local,
-- como a dos motores: o motorista é dono da física, e é ele quem simula o atrito.
local function atritoTraseiro(solto: boolean)
	if solto == atritoSolto then
		return
	end
	atritoSolto = solto
	for _, roda in rodasTraseiras do
		if roda.Parent then
			if solto then
				if atritoOriginal[roda] == nil then
					atritoOriginal[roda] = roda.CustomPhysicalProperties or false
				end
				local o = roda.CustomPhysicalProperties
				if o then
					roda.CustomPhysicalProperties = PhysicalProperties.new(
						o.Density,
						math.min(o.Friction, params.freioMaoAtritoTraseiro),
						o.Elasticity,
						o.FrictionWeight,
						o.ElasticityWeight
					)
				end
			else
				local antes = atritoOriginal[roda]
				if typeof(antes) == "PhysicalProperties" then
					roda.CustomPhysicalProperties = antes
				end
				atritoOriginal[roda] = nil
			end
		end
	end
end

local function freioMaoApertado(): boolean
	if freioMaoToque then
		return true
	end
	if Mouse.menuAberto() or UserInputService:GetFocusedTextBox() then
		return false
	end
	for _, tecla in teclasFreioMao do
		if UserInputService:IsKeyDown(tecla) then
			return true
		end
	end
	return false
end

-- Carro no chão? (um raio para baixo, sem o próprio carro nem o personagem)
local function noChao(chassi: BasePart): boolean
	return workspace:Raycast(chassi.Position, Vector3.new(0, -alturaSolo, 0), filtroSolo) ~= nil
end

-- Ajudas de condução, só para o motorista (o dono da física): corta parte do deslize lateral (ou deixa deslizar, com o
-- freio de mão) e faz o giro do carro seguir o ângulo das rodas, para o volante responder na hora. Devolve o deslize lateral.
local function ajudasFisicas(chassi: BasePart, dt: number, freioMao: boolean): number
	local cf = chassi.CFrame
	local direita = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	local frente = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if direita.Magnitude < 0.1 or frente.Magnitude < 0.1 then
		return 0
	end
	direita, frente = direita.Unit, frente.Unit
	local v = chassi.AssemblyLinearVelocity
	local lateral = v:Dot(direita)
	local aoLongo = v:Dot(frente)
	local plano = math.sqrt(lateral * lateral + aoLongo * aoLongo)
	if plano < params.velMinAjuda or not noChao(chassi) then
		return lateral
	end
	local grip = if freioMao then params.aderenciaLateralFreioMao else params.aderenciaLateral
	chassi.AssemblyLinearVelocity = v - direita * (lateral * (1 - math.exp(-grip * dt)))
	local giro = chassi.AssemblyAngularVelocity
	local alvo = Regra.guinadaAlvo(
		estado.angulo,
		aoLongo,
		entreEixos,
		if freioMao then params.freioMaoGuinada else 1,
		params.guinadaMax
	)
	local novo = giro.Y + (alvo - giro.Y) * (1 - math.exp(-params.ajudaGuinada * dt))
	chassi.AssemblyAngularVelocity = Vector3.new(giro.X, novo, giro.Z)
	return lateral
end

-- Passo físico --------------------------------------------------------------------------------------------------

local function moverPara(atual: number, alvo: number, passo: number): number
	if atual < alvo then
		return math.min(atual + passo, alvo)
	end
	return math.max(atual - passo, alvo)
end

local function passo(dt: number)
	local banco, modelo = estado.banco, estado.modelo
	if not estado.ativo or not banco or not modelo or not banco.Parent or not modelo.Parent then
		return
	end
	local chassi = chassiDe(modelo)
	if not chassi then
		return
	end
	if not estado.motorista then
		-- passageiro: sem pedais, volante nem motores; só a velocidade para o HUD
		local velMaxP = math.max(num(modelo:GetAttribute("VelMax"), 40), 1)
		local velP = chassi.AssemblyLinearVelocity:Dot(chassi.CFrame.LookVector)
		estado.velocidade = velP
		estado.fracao = math.clamp(math.abs(velP) / velMaxP, 0, 1)
		return
	end
	local agora = os.clock()
	if agora - ultimaVarredura > 1 or (#motores == 0 and agora - ultimaVarredura > 0.25) then
		ultimaVarredura = agora
		varrer(modelo)
	end

	local velMax = math.max(num(modelo:GetAttribute("VelMax"), 40), 1)
	local torque = math.max(num(modelo:GetAttribute("Torque"), 0), 0)
	local puxa = num(modelo:GetAttribute("Puxa"), 0)
	local ligado = modelo:GetAttribute("MotorLigado") == true

	local velocidade = chassi.AssemblyLinearVelocity:Dot(chassi.CFrame.LookVector)
	local assentoMotorista = banco :: VehicleSeat
	local pedal = if ligado then math.clamp(assentoMotorista.ThrottleFloat, -1, 1) else 0
	local volante = math.clamp(assentoMotorista.SteerFloat, -1, 1)
	local fracao = math.clamp(math.abs(velocidade) / velMax, 0, 1)
	local freioMao = freioMaoApertado()

	estado.velocidade = velocidade
	estado.fracao = fracao
	estado.pedal = pedal
	estado.freioMao = freioMao

	-- Direção: ângulo máximo cai com a velocidade; voltar ao centro é mais rápido que virar.
	local reducao = 1 - params.reducaoAngulo * fracao ^ 0.8
	local alvoAngulo = volante * params.anguloMax * reducao
	if ligado or fracao > 0.02 then
		alvoAngulo += puxa * params.puxarGraus * (0.3 + fracao)
	end
	-- contra-esterço automático: o carro desliza de lado, o volante acompanha a deriva (mais forte com o freio de mão)
	if velocidade > 2 then
		alvoAngulo += Regra.contraVolante(
			estado.deslize,
			params.contraVolanteLimiar,
			params.contraVolante * (if freioMao then 1.5 else 1),
			params.contraVolanteMax
		)
	end
	alvoAngulo = math.clamp(alvoAngulo, -params.anguloMax, params.anguloMax)
	local taxa = if volante == 0 or math.sign(alvoAngulo) ~= math.sign(estado.angulo)
		then params.grausPorSegundoVolta
		else params.grausPorSegundo
	estado.angulo = moverPara(estado.angulo, alvoAngulo, taxa * dt)
	estado.steer = math.clamp(estado.angulo / params.anguloMax, -1, 1)
	for _, s in servos do
		if s.constraint.Parent then
			s.constraint.TargetAngle = estado.angulo * s.sinal
		end
	end

	atritoTraseiro(freioMao)
	estado.deslize = ajudasFisicas(chassi, dt, freioMao)
	local travar = if freioMao then torque * params.torqueFreio else nil -- freio de mão: rodas traseiras seguram em 0

	if not ligado then
		velocidadeComando = 0
		estado.freando = false
		aplicarMotores(0, 0, travar)
		return
	end

	-- Tração: rampa de aceleração, freio forte, ré a 40%.
	local aceleracao = velMax / params.segundosAteMax
	local freio = velMax / params.segundosFreio
	local rolar = velMax / params.segundosRolar
	local freando = (pedal < -0.05 and velocidade > params.limiarParado)
		or (pedal > 0.05 and velocidade < -params.limiarParado)
	estado.freando = freando
	local torqueAplicado = torque

	if freando then
		-- o comando acompanha a velocidade real e cai rápido: as rodas seguram o carro
		local alvo = math.min(math.abs(velocidadeComando), math.abs(velocidade))
		alvo = math.max(alvo - freio * dt, 0)
		velocidadeComando = alvo * math.sign(velocidade)
		torqueAplicado = torque * params.torqueFreio
	elseif math.abs(pedal) > 0.05 then
		local alvo = if pedal > 0 then velMax * pedal else velMax * params.fatorRe * pedal
		local sobe = math.sign(alvo) == math.sign(velocidadeComando) or velocidadeComando == 0
		if sobe then
			local meta = math.abs(alvo)
			local atual = math.abs(velocidadeComando)
			-- arranque rápido, topo suave
			local mult = 0.35 + 0.65 * (1 - math.clamp(atual / math.max(meta, 1), 0, 1))
			local novo = moverPara(atual, meta, aceleracao * mult * dt)
			novo = math.min(novo, math.abs(velocidade) + params.folgaAceleracao)
			velocidadeComando = novo * math.sign(alvo)
		else
			-- virar o pedal com o comando ainda no sentido contrário: zera o comando depressa
			velocidadeComando = moverPara(velocidadeComando, 0, freio * dt)
		end
	elseif freioMao then
		-- sem acelerar, com o freio de mão: o comando cai depressa (as rodas da frente também seguram um pouco)
		velocidadeComando = moverPara(velocidadeComando, 0, freio * params.freioMaoDesaceleracao * dt)
		torqueAplicado = torque * params.torqueRolar * 2
	else
		velocidadeComando = moverPara(velocidadeComando, 0, rolar * dt)
		torqueAplicado = torque * params.torqueRolar
	end

	aplicarMotores(velocidadeComando, torqueAplicado, travar)
end

-- Entrar e sair -------------------------------------------------------------------------------------------------

local function notificar()
	for _, fn in ouvintes do
		local ok, erro = pcall(fn, estado.ativo, estado.modelo, estado.banco)
		if not ok then
			warn("[Direcao] ouvinte: " .. tostring(erro))
		end
	end
end

local botoes: ScreenGui? = nil
local PAINEL_LARGURA = 232 -- px do Painel do HudVeiculo (os botões touch ficam à esquerda dele)

local function sair()
	if not estado.ativo then
		return
	end
	atritoTraseiro(false) -- devolve o atrito das rodas traseiras antes de largar o carro
	table.clear(atritoOriginal)
	table.clear(rodasTraseiras)
	freioMaoToque = false
	-- um último quadro com as rodas travadas até o servidor assumir a posse
	for _, m in motores do
		if m.constraint.Parent then
			m.constraint.AngularVelocity = 0
			m.constraint.MotorMaxTorque = num(estado.modelo and estado.modelo:GetAttribute("Torque"), 0)
				* params.torqueFreio
		end
	end
	for _, s in servos do
		if s.constraint.Parent then
			s.constraint.TargetAngle = 0
		end
	end
	table.clear(motores)
	table.clear(servos)
	estado.ativo = false
	estado.motorista = false
	estado.modelo = nil
	estado.banco = nil
	estado.steer = 0
	estado.angulo = 0
	estado.velocidade = 0
	estado.fracao = 0
	estado.pedal = 0
	estado.freando = false
	estado.freioMao = false
	estado.deslize = 0
	velocidadeComando = 0
	if botoes then
		botoes.Enabled = false
	end
	notificar()
end

-- Botões só do motorista somem para o passageiro.
local function mostrarBotoes(motorista: boolean)
	if not botoes then
		return
	end
	for _, nome in { "Ligar", "Buzina", "Farol", "Freio" } do
		local b = botoes:FindFirstChild(nome)
		if b and b:IsA("GuiObject") then
			b.Visible = motorista
		end
	end
end

local function entrar(banco: BasePart)
	local modelo = banco:FindFirstAncestorOfClass("Model")
	while modelo and modelo:GetAttribute("Veiculo") ~= true do
		modelo = modelo:FindFirstAncestorOfClass("Model")
	end
	if not modelo then
		return
	end
	if estado.ativo then
		sair()
	end
	estado.ativo = true
	estado.motorista = banco:IsA("VehicleSeat")
	estado.modelo = modelo
	estado.banco = banco
	estado.angulo = 0
	estado.deslize = 0
	velocidadeComando = 0
	ultimaVarredura = 0
	atritoSolto = false
	filtroSolo.FilterDescendantsInstances = { modelo, jogador.Character }
	if botoes then
		mostrarBotoes(estado.motorista)
		botoes.Enabled = true
	end
	notificar()
end

local ligadoAoHumanoide: Humanoid? = nil
local conexoesHumanoide: { RBXScriptConnection } = {}

local function aoMudarAssento(humanoide: Humanoid)
	local assento = humanoide.SeatPart
	if assento and (assento:IsA("VehicleSeat") or assento:IsA("Seat")) then
		entrar(assento) -- banco de fora de carro (sem atributo Veiculo no modelo) é ignorado por entrar
	else
		sair()
	end
end

local function seguirHumanoide(humanoide: Humanoid?)
	if humanoide == ligadoAoHumanoide then
		return
	end
	for _, c in conexoesHumanoide do
		c:Disconnect()
	end
	table.clear(conexoesHumanoide)
	ligadoAoHumanoide = humanoide
	sair()
	if humanoide then
		table.insert(
			conexoesHumanoide,
			humanoide:GetPropertyChangedSignal("SeatPart"):Connect(function()
				aoMudarAssento(humanoide)
			end)
		)
		aoMudarAssento(humanoide)
	end
end

-- Teclas e botões de toque --------------------------------------------------------------------------------------

local function pedir(nome: string)
	if not estado.ativo or Mouse.menuAberto() then
		return
	end
	local ok, evento = pcall(Rede.evento, nome)
	if ok and evento then
		evento:FireServer()
	end
end

local function criarBotoes()
	local tela = Instance.new("ScreenGui")
	tela.Name = "BotoesVeiculo"
	tela.ResetOnSpawn = false
	tela.DisplayOrder = 11
	tela.Enabled = false
	tela.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local lista = {
		-- grade 2x2 à esquerda do painel do HudVeiculo (232 px + 12 de margem): coluna 0 = mais perto do painel
		{ nome = "Sair", evento = "SairCarro", coluna = 0, linha = 0 },
		{ nome = "Banco", evento = "TrocarBanco", coluna = 1, linha = 0 },
		{ nome = "Ligar", evento = "LigarMotor", coluna = 0, linha = 1 },
		{ nome = "Buzina", evento = "Buzina", coluna = 1, linha = 1 },
		{ nome = "Farol", evento = "Farol", coluna = 2, linha = 0 },
		{ nome = "Freio", evento = nil, coluna = 2, linha = 1 }, -- freio de mão: segurar (não é um evento de rede)
	}
	for _, dados in lista do
		local botao = Instance.new("TextButton")
		botao.Name = dados.nome
		botao.AnchorPoint = Vector2.new(1, 1)
		botao.Position = UDim2.new(1, -(PAINEL_LARGURA + 24 + dados.coluna * 96), 1, -(16 + dados.linha * 72))
		botao.Size = UDim2.fromOffset(88, 64)
		botao.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
		botao.BackgroundTransparency = 0.25
		botao.BorderSizePixel = 0
		botao.Font = Enum.Font.Code
		botao.TextSize = 18
		botao.TextColor3 = Color3.fromRGB(235, 235, 230)
		botao.Text = dados.nome
		local contorno = Instance.new("UIStroke")
		contorno.Thickness = 1.5
		contorno.Color = Color3.fromRGB(8, 8, 10)
		contorno.Parent = botao
		if dados.evento then
			botao.Activated:Connect(function()
				pedir(dados.evento)
			end)
		else
			local function segurar(entrada: InputObject, valor: boolean)
				if
					entrada.UserInputType == Enum.UserInputType.Touch
					or entrada.UserInputType == Enum.UserInputType.MouseButton1
				then
					freioMaoToque = valor
				end
			end
			botao.InputBegan:Connect(function(entrada)
				segurar(entrada, true)
			end)
			botao.InputEnded:Connect(function(entrada)
				segurar(entrada, false)
			end)
		end
		botao.Parent = tela
	end
	tela.Parent = jogador:WaitForChild("PlayerGui")
	botoes = tela
end

function Direcao.iniciar()
	carregarConfig()

	local teclas = if type(cfg) == "table" and type(cfg.teclas) == "table" then cfg.teclas else {}
	Teclas.ligar("veiculoLigar", teclas.ligar or { "G" }, function()
		if estado.motorista then
			pedir("LigarMotor")
		end
	end)
	Teclas.ligar("veiculoBuzina", teclas.buzina or { "H" }, function()
		if estado.motorista then
			pedir("Buzina")
		end
	end)
	Teclas.ligar("veiculoFarol", teclas.farol or { "L" }, function()
		if estado.motorista then
			pedir("Farol")
		end
	end)
	-- Freio de mão: segurar. Lido por IsKeyDown a cada quadro em passo() (sem Teclas.ligar, que só vê o apertar).
	-- O Shift também é a tecla de correr a pé (Controles); sentado, o Controles não pede corrida.
	for _, nome in teclas.freioMao or { "LeftShift", "RightShift" } do
		local codigo = (Enum.KeyCode :: any)[nome]
		if codigo then
			table.insert(teclasFreioMao, codigo)
		end
	end
	-- Sair: E dentro do carro (o servidor põe o personagem ao lado da porta). Pular também sai (padrão do Roblox).
	Teclas.ligar("veiculoSair", teclas.sair or { "E" }, function()
		pedir("SairCarro")
	end)
	-- Trocar de banco (F): InputBegan direto, sem Teclas.ligar, porque Teclas "engole" a tecla em todo lugar e o F
	-- também é a tecla do prompt "Encher recipiente" da bomba (a pé). Só vale dentro do carro.
	local teclasBanco: { Enum.KeyCode } = {}
	for _, nome in teclas.trocarBanco or { "F" } do
		local codigo = (Enum.KeyCode :: any)[nome]
		if codigo then
			table.insert(teclasBanco, codigo)
		end
	end
	local ultimaTrocaBanco = 0
	UserInputService.InputBegan:Connect(function(entrada, _)
		if
			entrada.UserInputType ~= Enum.UserInputType.Keyboard
			or not estado.ativo
			or not table.find(teclasBanco, entrada.KeyCode)
			or UserInputService:GetFocusedTextBox()
		then
			return
		end
		local agora = os.clock()
		if agora - ultimaTrocaBanco < 0.3 then
			return
		end
		ultimaTrocaBanco = agora
		pedir("TrocarBanco")
	end)

	if UserInputService.TouchEnabled then
		criarBotoes()
	end

	-- Ponto de saída decidido pelo servidor (ver Veiculos.colocarAoLado): o cliente é dono do personagem.
	Rede.evento("SairCarro").OnClientEvent:Connect(function(cf: CFrame)
		local personagem = jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if personagem and raiz and raiz:IsA("BasePart") and typeof(cf) == "CFrame" then
			raiz.AssemblyLinearVelocity = Vector3.zero
			raiz.AssemblyAngularVelocity = Vector3.zero
			personagem:PivotTo(cf)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ok, erro = pcall(passo, dt)
		if not ok then
			warn("[Direcao] " .. tostring(erro))
		end
	end)

	local function aoPersonagem(personagem: Model)
		task.spawn(function()
			local humanoide = personagem:WaitForChild("Humanoid", 10)
			if humanoide and humanoide:IsA("Humanoid") then
				seguirHumanoide(humanoide)
			end
		end)
	end
	jogador.CharacterAdded:Connect(aoPersonagem)
	if jogador.Character then
		aoPersonagem(jogador.Character)
	end
end

return Direcao
