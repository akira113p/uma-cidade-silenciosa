-- EfeitosArma: o que se VÊ de um tiro e de uma explosão (docs/armas.md §10.3). Dono: A5. Só visual e só local.
--   * Tiro próprio: sinal `disparou` (previsão local). Clarão do viewmodel é do ArmasViewmodel; aqui ficam rastro, cápsula e,
--     em 3ª pessoa, o clarão na boca da arma da mão.
--   * Tiro dos outros: evento `Disparo(atirador, armaId, origem, fim)` do servidor (só para quem está perto).
--   * Explosão: evento `Explosao(posicao, raio)`: bola Neon que cresce, fumaça e tremor de câmera por distância.
-- Estética PS1: poucos objetos, vida curta, tudo limpo por Debris. Nenhum efeito decide acerto ou dano.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Config = Shared:WaitForChild("Config")
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgVista = require(Config:WaitForChild("ArmasVista"))
local ArmasSinais = require(script.Parent.ArmasSinais)
local ArmasViewmodel = require(script.Parent.ArmasViewmodel)
local Camera = require(script.Parent.Camera)

local EfeitosArma = {}

local jogador = Players.LocalPlayer
local rng = Random.new()

local DISTANCIA_RASTRO = 400 -- studs: alcance do raio que acha o fim do rastro do tiro próprio
local INTERVALO_CLARAO_OUTROS = 0.03 -- s: escopeta manda vários Disparo juntos; só o primeiro faz clarão
local FUMACA = "rbxasset://textures/particles/smoke_main.dds" -- textura nativa do Roblox (sem asset nosso)

local pasta: Folder
local cartuchas: { Part } = {}
local ultimoClarao: { [Player]: number } = {}

local function cor(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function novaPeca(nome: string, tamanho: Vector3, corPeca: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material
	p.Color = corPeca
	p.Size = tamanho
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Boca da arma que o personagem segura (Attachment "Boca" dentro de ArmaNaMao).
local function bocaDe(personagem: Model?): CFrame?
	local naMao = personagem and personagem:FindFirstChild("ArmaNaMao")
	local att = naMao and naMao:FindFirstChild("Boca", true)
	if att and att:IsA("Attachment") then
		return att.WorldCFrame
	end
	return nil
end

-- Clarão temporário (3ª pessoa e armas dos outros). O clarão do viewmodel é do ArmasViewmodel.
local function clarao(onde: CFrame)
	local c = CfgVista.clarao
	local s = c.tamanho * rng:NextNumber(0.8, 1.3)
	local p = novaPeca("Clarao", Vector3.new(s, s, s), cor(c.cor), Enum.Material.Neon)
	p.CFrame = onde * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
	local luz = Instance.new("PointLight")
	luz.Range = c.luz.alcance
	luz.Brightness = c.luz.brilho
	luz.Color = p.Color
	luz.Shadows = false
	luz.Parent = p
	p.Parent = pasta
	Debris:AddItem(p, c.duracao)
end

local function rastro(a: Vector3, b: Vector3)
	local comp = (b - a).Magnitude
	if comp < 0.5 then
		return
	end
	local r = CfgVista.rastro
	local p = novaPeca("Rastro", Vector3.new(r.espessura, r.espessura, comp), cor(r.cor), Enum.Material.Neon)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Transparency = 0.15
	p.Parent = pasta
	Debris:AddItem(p, r.duracao)
end

-- Cápsula: um bloco pequeno que cai e some. Anel de `maximo` vivas.
local function ejetarCartucha(onde: CFrame, direita: Vector3)
	local c = CfgVista.cartucha
	if #cartuchas >= c.maximo then
		local velha = table.remove(cartuchas, 1)
		if velha then
			velha:Destroy()
		end
	end
	local t = c.tamanho
	local p = novaPeca("Cartucha", Vector3.new(t.x, t.y, t.z), cor(c.cor), Enum.Material.Metal)
	p.Anchored = false
	p.CanCollide = true
	p.Massless = false
	p.CFrame = onde
	p.AssemblyLinearVelocity = direita * c.velocidade * rng:NextNumber(0.7, 1.2)
		+ Vector3.new(0, c.velocidade * rng:NextNumber(0.4, 0.8), 0)
	p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
	p.Parent = pasta
	table.insert(cartuchas, p)
	p.Destroying:Once(function()
		local i = table.find(cartuchas, p)
		if i then
			table.remove(cartuchas, i)
		end
	end)
	Debris:AddItem(p, c.vida)
end

-- Fim de um rastro do tiro próprio: raio da origem na direção (com o cone da arma para cada chumbinho).
local function fimDoTiro(origem: Vector3, direcao: Vector3, cfg: any, espalhar: boolean): Vector3
	local dir = direcao
	if espalhar then
		local cone = math.rad(cfg.espalhamento)
		local desvio = CFrame.new(Vector3.zero, direcao)
			* CFrame.Angles(rng:NextNumber(-cone, cone), rng:NextNumber(-cone, cone), 0)
		dir = desvio.LookVector
	end
	local alcance = math.min(cfg.alcance, DISTANCIA_RASTRO)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar: { Instance } = { pasta }
	if jogador.Character then
		table.insert(ignorar, jogador.Character)
	end
	local projeteis = workspace:FindFirstChild("Projeteis")
	if projeteis then
		table.insert(ignorar, projeteis)
	end
	params.FilterDescendantsInstances = ignorar
	params.IgnoreWater = true
	local r = workspace:Raycast(origem, dir * alcance, params)
	return if r then r.Position else origem + dir * alcance
end

-- Tiro do próprio jogador (previsão local) ----------------------------------------------------------------------------------

local function aoDisparar(id: string, origem: Vector3, direcao: Vector3)
	local cfg = CfgArmas.armas[id]
	if not cfg then
		return
	end
	local vista = CfgVista.classes[cfg.classe]
	local personagem = jogador.Character
	local naVista = ArmasViewmodel.ativo()
	local boca = if naVista then ArmasViewmodel.bocaMundo() else bocaDe(personagem)
	if not naVista and boca then
		clarao(boca)
	end
	local inicio = if boca then boca.Position else origem + direcao

	if cfg.classe ~= "lancador" then
		local n = math.min(cfg.projeteis or 1, CfgVista.rastro.maximoEscopeta)
		for _ = 1, n do
			rastro(inicio, fimDoTiro(origem, direcao, cfg, (cfg.projeteis or 1) > 1))
		end
	end

	if vista and vista.cartucha then
		local ej = if naVista then ArmasViewmodel.ejecaoMundo() else nil
		if ej then
			local camera = workspace.CurrentCamera
			local direita = if camera then camera.CFrame.RightVector else ej.RightVector
			ejetarCartucha(ej, direita)
		end
	end
end

-- Tiro dos outros -------------------------------------------------------------------------------------------------------------

local function aoDisparoDeOutro(atirador: Player, id: string, origem: Vector3, fim: Vector3)
	if atirador == jogador then
		return
	end
	local cfg = CfgArmas.armas[id]
	local boca = bocaDe(atirador.Character)
	local agora = os.clock()
	if boca and agora - (ultimoClarao[atirador] or 0) > INTERVALO_CLARAO_OUTROS then
		ultimoClarao[atirador] = agora
		clarao(boca)
	end
	if cfg and cfg.classe == "lancador" then
		return
	end
	rastro(if boca then boca.Position else origem, fim)
end

-- Explosão ------------------------------------------------------------------------------------------------------------------

local function aoExplodir(posicao: Vector3, raio: number)
	if typeof(posicao) ~= "Vector3" or type(raio) ~= "number" or raio ~= raio then
		return
	end
	raio = math.clamp(raio, 1, 80)
	local e = CfgVista.explosao

	local bola = novaPeca("Explosao", Vector3.one * raio * 0.4, cor(e.cor), Enum.Material.Neon)
	bola.Shape = Enum.PartType.Ball
	bola.CFrame = CFrame.new(posicao)
	bola.Transparency = 0.1
	local luz = Instance.new("PointLight")
	luz.Range = 60
	luz.Brightness = 5
	luz.Color = bola.Color
	luz.Shadows = false
	luz.Parent = bola
	bola.Parent = pasta
	local info = TweenInfo.new(e.duracaoBola, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bola, info, { Size = Vector3.one * raio * 2, Transparency = 1 }):Play()
	TweenService:Create(luz, info, { Brightness = 0 }):Play()
	Debris:AddItem(bola, e.duracaoBola + 0.1)

	-- Fumaça: um jato curto de partículas grandes (poucas, é barato)
	local ponto = novaPeca("Fumaca", Vector3.one, cor(e.corFumaca), Enum.Material.SmoothPlastic)
	ponto.Transparency = 1
	ponto.CFrame = CFrame.new(posicao)
	local fumaca = Instance.new("ParticleEmitter")
	fumaca.Texture = FUMACA
	fumaca.Color = ColorSequence.new(cor(e.corFumaca))
	fumaca.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, raio * 0.4), NumberSequenceKeypoint.new(1, raio * 1.1) })
	fumaca.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	fumaca.Lifetime = NumberRange.new(1, 1.8)
	fumaca.Speed = NumberRange.new(3, 9)
	fumaca.SpreadAngle = Vector2.new(180, 180)
	fumaca.Rate = 0
	fumaca.LightEmission = 0
	fumaca.Parent = ponto
	ponto.Parent = pasta
	fumaca:Emit(12)
	Debris:AddItem(ponto, 2.5)

	-- Tremor proporcional ao inverso da distância (a Camera aplica Pref_Tremor/Pref_Intensidade)
	local camera = workspace.CurrentCamera
	if camera then
		local d = (camera.CFrame.Position - posicao).Magnitude
		if d < e.distanciaMax then
			Camera.tremer(e.tremorMaximo * e.distanciaRef / (d + e.distanciaRef), e.duracaoTremor)
		end
	end
end

function EfeitosArma.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "EfeitosArma"
	pasta.Parent = workspace

	ArmasSinais.ouvir("disparou", aoDisparar)
	Rede.evento("Disparo").OnClientEvent:Connect(aoDisparoDeOutro)
	Rede.evento("Explosao").OnClientEvent:Connect(aoExplodir)
	Players.PlayerRemoving:Connect(function(p)
		ultimoClarao[p] = nil
	end)
end

return EfeitosArma
