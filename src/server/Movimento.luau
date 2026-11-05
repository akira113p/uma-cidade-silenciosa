-- Movimento: dono de Agachado/Correndo e do WalkSpeed. Dono: P2. Contrato: docs/arquitetura.md §5 (Movimento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local ConfigMovimento = require(Shared:WaitForChild("Config"):WaitForChild("Movimento"))
local ConfigSobrevivencia = require(Shared:WaitForChild("Config"):WaitForChild("Sobrevivencia"))
local Limite = require(script.Parent.Limite)

local Movimento = {}

local INTERVALO_PEDIDO = 0.1
local ATRIBUTOS_LIDOS = { "Estamina", "MultVelocidade", "PodeCorrer", "Usando", "Agachado", "Correndo", "Morto" }

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
	if booleano(jogador, "Correndo", false) then
		base = ConfigMovimento.velocidadeCorrida
	elseif booleano(jogador, "Agachado", false) then
		base = ConfigMovimento.velocidadeAgachado
	end
	humanoide.WalkSpeed = base * numero(jogador, "MultVelocidade", 1)
end

-- Pose de agachar (R15): coxa para a frente, joelho para trás, pé plano, tronco inclinado e quadril mais baixo.
-- Mexe no C0 dos Motor6D (a animação só escreve Transform, então as duas coisas somam) e no HipHeight, que também
-- encolhe a hitbox. Tudo no servidor para os outros jogadores verem. Ângulos e alturas: Config/Movimento.agachado.
local POSE = ConfigMovimento.agachado
local originais: { [Model]: { quadril: number, juntas: { [Motor6D]: CFrame } } } = setmetatable({}, { __mode = "k" }) :: any

local function achar(personagem: Model, nome: string): Motor6D?
	local junta = personagem:FindFirstChild(nome, true)
	if junta and junta:IsA("Motor6D") then
		return junta
	end
	return nil
end

local function aplicarPose(jogador: Player)
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not personagem or not humanoide or humanoide.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local agachado = booleano(jogador, "Agachado", false) and not booleano(jogador, "Morto", false)
	local dados = originais[personagem]
	if not dados then
		if not agachado then
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
	local info = TweenInfo.new(POSE.duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for nome, angulo in angulos do
		local junta = achar(personagem, nome)
		if junta then
			local original = dados.juntas[junta]
			if not original then
				original = junta.C0
				dados.juntas[junta] = original
			end
			local alvo = if agachado then original * CFrame.Angles(angulo, 0, 0) else original
			TweenService:Create(junta, info, { C0 = alvo }):Play()
		end
	end
	local alturaQuadril = dados.quadril - (if agachado then POSE.alturaQuadril else 0)
	TweenService:Create(humanoide, info, { HipHeight = alturaQuadril }):Play()
end

local function agachar(jogador: Player, ligado: unknown)
	if type(ligado) ~= "boolean" or not Limite.ok(jogador, "Agachar", INTERVALO_PEDIDO) then
		return
	end
	if booleano(jogador, "Morto", false) then
		return
	end
	jogador:SetAttribute("Agachado", ligado)
	if ligado then
		jogador:SetAttribute("Correndo", false)
	end
	aplicar(jogador)
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
		jogador:GetAttributeChangedSignal("Morto"):Connect(function()
			aplicarPose(jogador)
		end)
	)

	local function aoPersonagem(personagem: Model)
		-- Recomeça de pé e andando; o Humanoid pode demorar a replicar.
		jogador:SetAttribute("Agachado", false)
		jogador:SetAttribute("Correndo", false)
		if personagem:WaitForChild("Humanoid", 10) then
			aplicar(jogador)
		end
	end
	table.insert(lista, jogador.CharacterAdded:Connect(aoPersonagem))
	if jogador.Character then
		task.spawn(aoPersonagem, jogador.Character)
	end
end

function Movimento.iniciar()
	Rede.evento("Agachar").OnServerEvent:Connect(agachar)
	Rede.evento("Correr").OnServerEvent:Connect(correr)

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
		Teste.registrar("correr", function(jogador: Player, ligado: boolean?)
			correr(jogador, ligado ~= false)
			return jogador:GetAttribute("Correndo")
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
