-- Movimento: dono de Agachado/Correndo e do WalkSpeed. Dono: P2. Contrato: docs/arquitetura.md §5 (Movimento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local ConfigMovimento = require(Shared:WaitForChild("Config"):WaitForChild("Movimento"))
local ConfigSobrevivencia = require(Shared:WaitForChild("Config"):WaitForChild("Sobrevivencia"))
local Limite = require(script.Parent.Limite)

local Movimento = {}

local INTERVALO_PEDIDO = 0.1
local ATRIBUTOS_LIDOS =
	{ "Estamina", "MultVelocidade", "PodeCorrer", "Usando", "Agachado", "Deitado", "Correndo", "Morto" }

local conexoes: { [Player]: { RBXScriptConnection } } = {}

-- Atributo ausente = valor neutro (as outras partes podem não existir ainda).
local function numero(jogador: Player, nome: string, neutro: number): number
	local v = jogador:GetAttribute(nome)
	if type(v) == "number" then
		return v
	end
	return neutro
end

local function booleano(jogador: Player, nome: string, neutro: boolean): boolean
	local v = jogador:GetAttribute(nome)
	if type(v) == "boolean" then
		return v
	end
	return neutro
end

local function podeManterCorrida(jogador: Player): boolean
	return booleano(jogador, "PodeCorrer", true)
		and not booleano(jogador, "Usando", false)
		and not booleano(jogador, "Agachado", false)
		and not booleano(jogador, "Deitado", false)
		and not booleano(jogador, "Morto", false)
		and numero(jogador, "Estamina", 100) > 0
end

local function podeComecarCorrida(jogador: Player): boolean
	return podeManterCorrida(jogador)
		and numero(jogador, "Estamina", 100) >= ConfigSobrevivencia.estamina.minimoParaVoltarACorrer
end

-- Recalcula Correndo (desliga se as condições caíram) e o WalkSpeed.
local function aplicar(jogador: Player)
	if booleano(jogador, "Correndo", false) and not podeManterCorrida(jogador) then
		jogador:SetAttribute("Correndo", false)
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		return
	end
	local base = ConfigMovimento.velocidade
	if booleano(jogador, "Deitado", false) then
		base = ConfigMovimento.velocidadeDeitado
	elseif booleano(jogador, "Correndo", false) then
		base = ConfigMovimento.velocidadeCorrida
	elseif booleano(jogador, "Agachado", false) then
		base = ConfigMovimento.velocidadeAgachado
	end
	humanoide.WalkSpeed = base * numero(jogador, "MultVelocidade", 1)
	-- deitado não pula
	humanoide:SetStateEnabled(Enum.HumanoidStateType.Jumping, not booleano(jogador, "Deitado", false))
end

-- Pose de agachar (R15): coxa para a frente, joelho para trás, pé plano, tronco inclinado e quadril mais baixo.
-- Mexe no C0 dos Motor6D (a animação só escreve Transform, então as duas coisas somam) e no HipHeight, que também
-- encolhe a hitbox. Tudo no servidor para os outros jogadores verem. Ângulos e alturas: Config/Movimento.agachado.
local POSE = ConfigMovimento.agachado
local DEITADO = ConfigMovimento.deitado
local originais: { [Model]: { quadril: number, juntas: { [Motor6D | AnimationConstraint]: CFrame } } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

-- O R15 do Studio novo usa AnimationConstraint nas juntas (sem Motor6D); as duas têm C0.
local function achar(personagem: Model, nome: string): (Motor6D | AnimationConstraint)?
	local junta = personagem:FindFirstChild(nome, true)
	if junta and (junta:IsA("Motor6D") or junta:IsA("AnimationConstraint")) then
		return junta
	end
	return nil
end

-- Deitado, as peças do corpo ficam rentes ao chão; colidindo, a física as empurra e o personagem escorrega. Elas vão para um
-- grupo que não colide com nada (o Humanoid se apoia pelo HipHeight, que deitado nunca vai a 0). Tiro/raycast não usam colisão.
local GRUPO_DEITADO = "CorpoDeitado"
local gruposOriginais: { [BasePart]: string } = setmetatable({}, { __mode = "k" }) :: any
local function prepararGrupo()
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, GRUPO_DEITADO)
	for _, g in PhysicsService:GetRegisteredCollisionGroups() do
		pcall(PhysicsService.CollisionGroupSetCollidable, PhysicsService, GRUPO_DEITADO, g.name, false)
	end
end

local function grupoDoCorpo(personagem: Model, deitado: boolean)
	for _, d in personagem:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if deitado then
				if d.CollisionGroup ~= GRUPO_DEITADO then
					gruposOriginais[d] = d.CollisionGroup
					d.CollisionGroup = GRUPO_DEITADO
				end
			elseif d.CollisionGroup == GRUPO_DEITADO then
				d.CollisionGroup = gruposOriginais[d] or "Default"
			end
		end
	end
end

local function aplicarPose(jogador: Player)
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not personagem or not humanoide or humanoide.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local morto = booleano(jogador, "Morto", false)
	local deitado = booleano(jogador, "Deitado", false) and not morto
	local agachado = booleano(jogador, "Agachado", false) and not morto and not deitado
	local dados = originais[personagem]
	if not dados then
		if not agachado and not deitado then
			return -- de pé e nunca agachou: nada a desfazer
		end
		dados = { quadril = humanoide.HipHeight, juntas = {} }
		originais[personagem] = dados
	end

	local coxa = math.rad(POSE.anguloCoxa)
	local tronco = math.rad(POSE.inclinacaoTronco)
	local angulos = {
		LeftHip = coxa + tronco,
		RightHip = coxa + tronco,
		LeftKnee = -2 * coxa,
		RightKnee = -2 * coxa,
		LeftAnkle = coxa,
		RightAnkle = coxa,
		Root = -tronco,
	}
	-- deitado: o corpo inteiro gira para a frente no Root (fica de bruços) e desce; pernas quase retas
	local coxaD = math.rad(DEITADO.anguloCoxa)
	local angulosDeitado = {
		LeftHip = coxaD,
		RightHip = coxaD,
		LeftKnee = -coxaD,
		RightKnee = -coxaD,
		LeftAnkle = 0,
		RightAnkle = 0,
		Root = -math.rad(DEITADO.angulo),
	}
	local info = TweenInfo.new(
		if deitado then DEITADO.duracao else POSE.duracao,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	for nome, angulo in angulos do
		local junta = achar(personagem, nome)
		-- AnimationConstraint: C0 é só leitura; o equivalente é o CFrame do Attachment0 (como em PersonagemVisual.ajustarEsqueleto)
		local alvoTween: Instance? = if junta and junta:IsA("AnimationConstraint") then junta.Attachment0 else junta
		if junta and alvoTween then
			local original = dados.juntas[junta]
			if not original then
				original = if alvoTween:IsA("Attachment") then alvoTween.CFrame else (junta :: Motor6D).C0
				dados.juntas[junta] = original
			end
			local alvo = original
			if deitado then
				alvo = original * CFrame.Angles(angulosDeitado[nome], 0, 0)
				if nome == "Root" then
					alvo = CFrame.new(0, -DEITADO.descer, 0) * alvo
				end
			elseif agachado then
				alvo = original * CFrame.Angles(angulo, 0, 0)
			end
			if alvoTween:IsA("Attachment") then
				TweenService:Create(alvoTween, info, { CFrame = alvo }):Play()
			else
				TweenService:Create(alvoTween, info, { C0 = alvo }):Play()
			end
		end
	end
	grupoDoCorpo(personagem, deitado)
	local alturaQuadril = if deitado
		then DEITADO.alturaQuadril
		else dados.quadril - (if agachado then POSE.alturaQuadril else 0)
	TweenService:Create(humanoide, info, { HipHeight = alturaQuadril }):Play()
end

-- Derrubado: atributo com o instante de fim em workspace:GetServerTimeNow() (o cliente compara com o mesmo relógio).
local function estaDerrubado(jogador: Player): boolean
	return numero(jogador, "Derrubado", 0) > workspace:GetServerTimeNow()
end

local function agachar(jogador: Player, ligado: unknown)
	if type(ligado) ~= "boolean" or estaDerrubado(jogador) or not Limite.ok(jogador, "Agachar", INTERVALO_PEDIDO) then
		return
	end
	if booleano(jogador, "Morto", false) then
		return
	end
	jogador:SetAttribute("Deitado", false) -- agachar (ligar ou desligar) sempre sai do deitado
	jogador:SetAttribute("Agachado", ligado)
	if ligado then
		jogador:SetAttribute("Correndo", false)
	end
	aplicar(jogador)
end

-- Deitar: liga Deitado e também Agachado (ruído, mira e o resto do jogo tratam deitado como agachado). Desligar = de pé.
local function deitar(jogador: Player, ligado: unknown)
	if type(ligado) ~= "boolean" or estaDerrubado(jogador) or not Limite.ok(jogador, "Deitar", INTERVALO_PEDIDO) then
		return
	end
	if booleano(jogador, "Morto", false) then
		return
	end
	jogador:SetAttribute("Deitado", ligado)
	jogador:SetAttribute("Agachado", ligado)
	if ligado then
		jogador:SetAttribute("Correndo", false)
	end
	aplicar(jogador)
end

local fichaDerrubado: { [Player]: number } = {}

-- Derruba o jogador por `segundos` (Deitado + Derrubado) e aplica `impulso` no HumanoidRootPart. Dentro de carro ou morto: ignora.
-- Ao acabar volta AGACHADO (não de pé): o jogador levanta com C. Derrubar de novo estende o fim, nunca encurta.
function Movimento.derrubar(jogador: Player, segundos: number, impulso: Vector3?)
	if type(segundos) ~= "number" or segundos ~= segundos or segundos <= 0 then
		return
	end
	if booleano(jogador, "Morto", false) then
		return
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (humanoide and raiz and raiz:IsA("BasePart")) or humanoide.SeatPart ~= nil then
		return
	end
	local cfg = ConfigMovimento.derrubado
	segundos = math.min(segundos, cfg.maxSegundos)
	local agora = workspace:GetServerTimeNow()
	local fim = math.max(agora + segundos, numero(jogador, "Derrubado", 0))
	jogador:SetAttribute("Derrubado", fim)
	jogador:SetAttribute("Correndo", false)
	jogador:SetAttribute("Deitado", true)
	jogador:SetAttribute("Agachado", true)
	aplicar(jogador)
	if typeof(impulso) == "Vector3" and impulso.Magnitude == impulso.Magnitude then
		if impulso.Magnitude > cfg.maxImpulso then
			impulso = impulso.Unit * cfg.maxImpulso
		end
		-- o cliente é dono da física do próprio personagem: velocidade posta só no servidor é sobrescrita. O cliente aplica
		-- (client/MonstroEfeitos, evento Impulso); o servidor também põe, para o caso de a posse estar com ele.
		raiz.AssemblyLinearVelocity += impulso
		pcall(function()
			Rede.evento("Impulso"):FireClient(jogador, impulso)
		end)
	end
	local ficha = (fichaDerrubado[jogador] or 0) + 1
	fichaDerrubado[jogador] = ficha
	task.delay(fim - agora, function()
		if fichaDerrubado[jogador] ~= ficha or jogador.Parent == nil then
			return
		end
		jogador:SetAttribute("Derrubado", 0)
		if booleano(jogador, "Morto", false) then
			return
		end
		-- volta agachado: Deitado desliga, Agachado fica
		jogador:SetAttribute("Deitado", false)
		jogador:SetAttribute("Agachado", true)
		aplicar(jogador)
		-- rede de segurança: se o impulso/corpo do monstro jogou o Humanoid em FallingDown/Ragdoll/PlatformStand, ele não
		-- levanta sozinho (bug "fico no chão sem conseguir andar", 2026-11-16)
		local atual = jogador.Character and jogador.Character:FindFirstChildOfClass("Humanoid")
		if atual and atual.Health > 0 then
			atual.PlatformStand = false
			local estado = atual:GetState()
			if
				estado == Enum.HumanoidStateType.FallingDown
				or estado == Enum.HumanoidStateType.Ragdoll
				or estado == Enum.HumanoidStateType.PlatformStanding
			then
				atual:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end)
end

local function correr(jogador: Player, ligado: unknown)
	if type(ligado) ~= "boolean" then
		return
	end
	-- Soltar a tecla nunca é limitado: um toque rápido não pode deixar o jogador correndo.
	if ligado and not Limite.ok(jogador, "Correr", INTERVALO_PEDIDO) then
		return
	end
	if booleano(jogador, "Morto", false) then
		return
	end
	jogador:SetAttribute("Correndo", ligado and podeComecarCorrida(jogador))
	aplicar(jogador)
end

local function limpar(jogador: Player)
	fichaDerrubado[jogador] = nil
	local lista = conexoes[jogador]
	if lista then
		for _, c in lista do
			c:Disconnect()
		end
		conexoes[jogador] = nil
	end
end

local function aoEntrar(jogador: Player)
	limpar(jogador)
	local lista: { RBXScriptConnection } = {}
	conexoes[jogador] = lista

	jogador:SetAttribute("Agachado", false)
	jogador:SetAttribute("Deitado", false)
	jogador:SetAttribute("Correndo", false)

	for _, nome in ATRIBUTOS_LIDOS do
		table.insert(
			lista,
			jogador:GetAttributeChangedSignal(nome):Connect(function()
				aplicar(jogador)
			end)
		)
	end

	table.insert(
		lista,
		jogador:GetAttributeChangedSignal("Agachado"):Connect(function()
			aplicarPose(jogador)
		end)
	)
	table.insert(
		lista,
		jogador:GetAttributeChangedSignal("Deitado"):Connect(function()
			aplicarPose(jogador)
		end)
	)
	table.insert(
		lista,
		jogador:GetAttributeChangedSignal("Morto"):Connect(function()
			aplicarPose(jogador)
		end)
	)

	local function aoPersonagem(personagem: Model)
		-- Recomeça de pé e andando; o Humanoid pode demorar a replicar.
		jogador:SetAttribute("Agachado", false)
		jogador:SetAttribute("Deitado", false)
		jogador:SetAttribute("Correndo", false)
		jogador:SetAttribute("Derrubado", 0)
		fichaDerrubado[jogador] = (fichaDerrubado[jogador] or 0) + 1
		local humanoide = personagem:WaitForChild("Humanoid", 10)
		if humanoide and humanoide:IsA("Humanoid") then
			-- o jogo derruba por código (Movimento.derrubar); o ragdoll automático do Roblox (pancada de monstro/impulso) só atrapalha
			humanoide:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoide:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			aplicar(jogador)
		end
	end
	table.insert(lista, jogador.CharacterAdded:Connect(aoPersonagem))
	if jogador.Character then
		task.spawn(aoPersonagem, jogador.Character)
	end
end

function Movimento.iniciar()
	prepararGrupo()
	Rede.evento("Agachar").OnServerEvent:Connect(agachar)
	Rede.evento("Correr").OnServerEvent:Connect(correr)
	Rede.evento("Deitar").OnServerEvent:Connect(deitar)

	Players.PlayerAdded:Connect(aoEntrar)
	Players.PlayerRemoving:Connect(limpar)
	for _, jogador in Players:GetPlayers() do
		task.spawn(aoEntrar, jogador)
	end

	-- Comandos do Studio: execute_luau não dispara RemoteEvent de cliente.
	local ok, Teste = pcall(require, script.Parent.Teste)
	if ok then
		Teste.registrar("agachar", function(jogador: Player, ligado: boolean?)
			agachar(jogador, ligado ~= false)
			return jogador:GetAttribute("Agachado")
		end)
		Teste.registrar("deitar", function(jogador: Player, ligado: boolean?)
			deitar(jogador, ligado ~= false)
			return jogador:GetAttribute("Deitado")
		end)
		Teste.registrar("correr", function(jogador: Player, ligado: boolean?)
			correr(jogador, ligado ~= false)
			return jogador:GetAttribute("Correndo")
		end)
		Teste.registrar("derrubar", function(jogador: Player, segundos: number?, impulso: Vector3?)
			Movimento.derrubar(jogador, segundos or 2, impulso or Vector3.zero)
			return string.format(
				"Derrubado=%s Deitado=%s",
				tostring(jogador:GetAttribute("Derrubado")),
				tostring(jogador:GetAttribute("Deitado"))
			)
		end)
		Teste.registrar("velocidade", function(jogador: Player)
			local humanoide = jogador.Character and jogador.Character:FindFirstChildOfClass("Humanoid")
			return string.format(
				"WalkSpeed=%s Agachado=%s Correndo=%s",
				humanoide and tostring(humanoide.WalkSpeed) or "sem humanoide",
				tostring(jogador:GetAttribute("Agachado")),
				tostring(jogador:GetAttribute("Correndo"))
			)
		end)
	end
end

return Movimento
