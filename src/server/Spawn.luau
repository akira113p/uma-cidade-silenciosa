-- Spawn: cada nascimento acontece num ponto "Spawn" sorteado das vilas, com os pés no chão. Dono: P5.
-- Usa SpawnLocation + Player.RespawnLocation (o motor posiciona o personagem sobre o pad; um PivotTo logo no
-- CharacterAdded é desfeito pelo motor). Contrato: docs/arquitetura.md §5 Spawn e §6 (workspace.Mapa.Pontos).

local Players = game:GetService("Players")

local Spawn = {}

local FALLBACK = CFrame.new(0, 10, 0)
local TAMANHO_PAD = Vector3.new(8, 0.2, 8)
local TOLERANCIA = 15 -- studs: mais longe que isto do pad, depois de nascer, o personagem é recolocado
local ESPERA_ESTABILIZAR = 0.25 -- s

local pads: { SpawnLocation } = {}

local function pontos(): { BasePart }
	local lista = {}
	local mapa = workspace:FindFirstChild("Mapa")
	local pasta = mapa and mapa:FindFirstChild("Pontos")
	if not pasta then
		return lista
	end
	for _, ponto in pasta:GetChildren() do
		if ponto.Name == "Spawn" and ponto:IsA("BasePart") then
			table.insert(lista, ponto)
		end
	end
	return lista
end

function Spawn.pontoAleatorio(): CFrame
	local lista = pontos()
	if #lista == 0 then
		warn("[Spawn] sem pontos Spawn em workspace.Mapa.Pontos; usando (0, 10, 0)")
		return FALLBACK
	end
	local ponto = lista[math.random(#lista)]
	return CFrame.new(ponto.Position + Vector3.new(0, 3, 0))
end

-- Um SpawnLocation fino, invisível e sem colisão em cada ponto: o topo do pad é o chão (o ponto fica 0.5 acima).
local function criarPads()
	local pasta = Instance.new("Folder")
	pasta.Name = "SpawnsJogo"
	for _, ponto in pontos() do
		local pad = Instance.new("SpawnLocation")
		pad.Name = "Pad"
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.Transparency = 1
		pad.Neutral = true
		pad.AllowTeamChangeOnTouch = false
		pad.Duration = 0
		pad.Size = TAMANHO_PAD
		pad.Position = ponto.Position - Vector3.new(0, 0.5 + TAMANHO_PAD.Y / 2, 0)
		pad:SetAttribute("Zona", ponto:GetAttribute("Zona"))
		pad.Parent = pasta
		table.insert(pads, pad)
	end
	pasta.Parent = workspace
end

local function sortearPad(): SpawnLocation?
	if #pads == 0 then
		return nil
	end
	return pads[math.random(#pads)]
end

local function registrar(jogador: Player)
	local atual = sortearPad()
	jogador.RespawnLocation = atual

	-- Rede de segurança: se o motor nascer o personagem longe do pad (ex.: personagem já existia ao iniciar),
	-- leva o personagem para o pad uma vez.
	local function aoPersonagem(personagem: Model)
		local alvo = atual
		jogador.RespawnLocation = sortearPad() -- o próximo nascimento será em outro ponto
		atual = jogador.RespawnLocation
		local raiz = personagem:WaitForChild("HumanoidRootPart", 10)
		if not raiz or not alvo then
			return
		end
		task.wait(ESPERA_ESTABILIZAR)
		if
			personagem:IsDescendantOf(workspace)
			and ((raiz :: BasePart).Position - alvo.Position).Magnitude > TOLERANCIA
		then
			personagem:PivotTo(alvo.CFrame + Vector3.new(0, 4, 0))
		end
	end
	jogador.CharacterAdded:Connect(aoPersonagem)
	if jogador.Character then
		task.spawn(aoPersonagem, jogador.Character)
	end
end

function Spawn.iniciar()
	-- O mapa chega pelo Rojo antes de qualquer serviço; se ainda faltar, tenta por até 10 s.
	local t0 = os.clock()
	while #pontos() == 0 and os.clock() - t0 < 10 do
		task.wait(0.5)
	end
	criarPads()
	if #pads == 0 then
		warn("[Spawn] nenhum ponto Spawn no mapa; jogadores nascem no padrão do Roblox")
	end

	Players.PlayerAdded:Connect(registrar)
	for _, jogador in Players:GetPlayers() do
		registrar(jogador)
	end
end

return Spawn
