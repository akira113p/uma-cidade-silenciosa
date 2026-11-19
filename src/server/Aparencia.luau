-- Aparencia: troca o visual de todo personagem R15 pelo modelo do jogo, só por código. Primeiro iguala o corpo com as
-- escalas de Config/Aparencia (esbelto e alto); depois deixa as peças do avatar invisíveis (elas continuam sendo a
-- física, a animação e a hitbox) e solda uma peça "Bloco" em cada uma. O QUE desenhar em cada peça é de cada personagem
-- do seletor (Config/Personagens, atributo PersonagemId do jogador; ausente = "padrao"): ver shared/PersonagemVisual.luau,
-- que também serve ao cliente. O cliente esconde a cabeça do próprio jogador na primeira pessoa (client/Aparencia.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Aparencia"))
local PersonagemVisual = require(Shared:WaitForChild("PersonagemVisual"))

local Aparencia = {}

local function ehRoupa(x: Instance): boolean
	return x:IsA("Accessory") or x:IsA("Shirt") or x:IsA("Pants") or x:IsA("ShirtGraphic") or x:IsA("CharacterMesh")
end

-- Veste o personagem com o visual de `id` (padrão: atributo PersonagemId do personagem; ausente = "padrao").
-- Pode esperar (malhas carregam por AssetService).
local function revestir(personagem: Model, id: string?)
	local escolhido = PersonagemVisual.entrada(id or personagem:GetAttribute("PersonagemId")).id
	personagem:SetAttribute("PersonagemId", escolhido)
	for _, x in personagem:GetChildren() do
		if ehRoupa(x) then
			x:Destroy()
		end
	end
	PersonagemVisual.revestir(personagem, escolhido)
	personagem:SetAttribute("Aparencia", true)
	-- roupa/acessório que o motor ainda adicionar depois (avatar carregando tarde) é removido na hora
	personagem.ChildAdded:Connect(function(x)
		if ehRoupa(x) then
			task.defer(x.Destroy, x)
		end
	end)
end
Aparencia.revestir = revestir

-- Escalas do R15 (NumberValue dentro do Humanoid): o motor refaz o tamanho das peças sozinho.
local function escalar(humanoide: Humanoid)
	for nome, valor in Cfg.escala do
		local escala = humanoide:FindFirstChild(nome)
		if escala and escala:IsA("NumberValue") then
			escala.Value = valor
		end
	end
end

-- Roda tudo dentro de pcall e avisa no Output: se o visual não aparecer, a linha "[Aparencia] erro" diz por quê.
local function aplicar(jogador: Player, personagem: Model)
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		warn("[Aparencia] " .. jogador.Name .. ": personagem sem Humanoid")
		return
	end
	if humanoide.RigType ~= Enum.HumanoidRigType.R15 then
		warn(
			"[Aparencia] "
				.. jogador.Name
				.. ": o personagem é R6; o visual só funciona em R15 (Game Settings > Avatar > R15)"
		)
		return
	end
	print("[Aparencia] aplicando em " .. jogador.Name)
	local ok, erro = pcall(function()
		escalar(humanoide)
		task.wait(Cfg.esperaEscala)
		if personagem.Parent then
			revestir(personagem, jogador:GetAttribute("PersonagemId"))
		end
	end)
	if ok then
		print("[Aparencia] pronto em " .. jogador.Name)
	else
		warn("[Aparencia] erro: " .. tostring(erro))
	end
end
Aparencia.aplicar = aplicar

local function aoPersonagem(jogador: Player, personagem: Model)
	print("[Aparencia] personagem chegou: " .. jogador.Name)
	if not personagem:WaitForChild("Humanoid", 10) then
		warn("[Aparencia] " .. jogador.Name .. ": sem Humanoid em 10 s")
		return
	end
	-- O avatar (acessórios, roupa, cabeça) chega depois do CharacterAdded; mexer antes é sobrescrito. Espera até 10 s
	-- olhando o estado (não depende de pegar o evento CharacterAppearanceLoaded no instante certo). tick() é relógio de
	-- parede; os.clock() não serve para esperar. Na hora do CharacterAdded o personagem ainda não tem Parent, então o
	-- que vale como "ainda está vivo" é ser o personagem atual do jogador.
	local t0 = tick()
	while not jogador:HasAppearanceLoaded() and jogador.Character == personagem and tick() - t0 < 10 do
		task.wait(0.2)
	end
	print(
		"[Aparencia] avatar carregado="
			.. tostring(jogador:HasAppearanceLoaded())
			.. " após "
			.. string.format("%.1f", tick() - t0)
			.. " s: "
			.. jogador.Name
	)
	if jogador.Character == personagem then
		aplicar(jogador, personagem)
	else
		print("[Aparencia] personagem trocado antes de aplicar: " .. jogador.Name)
	end
end

function Aparencia.iniciar()
	local function registrar(jogador: Player)
		jogador.CharacterAdded:Connect(function(personagem)
			aoPersonagem(jogador, personagem)
		end)
		if jogador.Character then
			task.spawn(aoPersonagem, jogador, jogador.Character)
		end
	end
	Players.PlayerAdded:Connect(registrar)
	for _, jogador in Players:GetPlayers() do
		registrar(jogador)
	end
end

return Aparencia
