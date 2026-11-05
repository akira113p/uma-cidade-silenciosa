-- Foguete: o projétil do lança-foguetes e a explosão (docs/armas.md §7.6). Dono: A2.
-- O servidor voa o foguete (Part física, sem gravidade, sem colisão própria) e testa o caminho por raycast a cada
-- Heartbeat. Ao acertar (ou ao fim da vida) explode: destrói construção (Destruicao.explosao), machuca jogadores
-- (inclusive o atirador), monstros e carros, faz ruído e avisa os clientes (evento Explosao).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgCorpo = require(Shared:WaitForChild("Config"):WaitForChild("Corpo"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Armas"))

local Vida = require(script.Parent.Vida)
local Monstros = require(script.Parent.Monstros)
local Sons = require(script.Parent.Sons)
local Ruido = require(script.Parent.Ruido)

local Foguete = {}

-- Constantes de implementação (o balanceamento está em Config/Armas.projetil).
local MAX_ATIVOS = 8 -- foguetes no ar ao mesmo tempo, no servidor inteiro
local IGNORA_ATIRADOR = 0.3 -- s: o foguete atravessa o próprio atirador logo depois de sair do cano
local DISTANCIA_EXPLOSAO_CLIENTE = 700 -- studs: quem está mais longe não recebe o evento Explosao
local RECUO_NORMAL = 0.5 -- studs: o centro da explosão sai um pouco da superfície acertada
local COMPRIMENTO, ESPESSURA = 1.6, 0.35
local MULT_PARTE_ATINGIDA: { [string]: number } = {
	Torso = 1,
	Cabeca = 0.5,
	BracoE = 0.5,
	BracoD = 0.5,
	PernaE = 0.5,
	PernaD = 0.5,
}

local ativos: { [Part]: boolean } = {}
local contagem = 0

local function pastaProjeteis(): Folder
	local pasta = workspace:FindFirstChild("Projeteis")
	if pasta and pasta:IsA("Folder") then
		return pasta
	end
	local nova = Instance.new("Folder")
	nova.Name = "Projeteis"
	nova.Parent = workspace
	return nova
end

-- O que o raycast do foguete (e a linha de visada da explosão) nunca enxerga: zonas, pontos, sons soltos, bolsas.
local function ignoradosDoMundo(): { Instance }
	local lista: { Instance } = { pastaProjeteis() }
	local mapa = workspace:FindFirstChild("Mapa")
	for _, pasta in { mapa and mapa:FindFirstChild("Zonas"), mapa and mapa:FindFirstChild("Pontos") } do
		table.insert(lista, pasta)
	end
	for _, nome in { "SonsSoltos", "ItensChao" } do
		local pasta = workspace:FindFirstChild(nome)
		if pasta then
			table.insert(lista, pasta)
		end
	end
	return lista
end

local function paramsExcluindo(lista: { Instance }): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = lista
	return p
end

-- Distância de `p` até a caixa da peça (0 se dentro): o dano da explosão conta da superfície, não do centro da peça.
local function distanciaAteCaixa(peca: BasePart, p: Vector3): number
	local l = peca.CFrame:PointToObjectSpace(p)
	local h = peca.Size / 2
	local mais = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	return (l - mais).Magnitude
end

local function destruicao(): any
	local ok, m = pcall(require, script.Parent.Destruicao)
	return if ok then m else nil
end

local function veiculos(): any
	local ok, m = pcall(require, script.Parent.Veiculos)
	return if ok then m else nil
end

local function ehPecaVeiculo(inst: Instance): Model?
	local modelo = inst:FindFirstAncestorOfClass("Model")
	if modelo and modelo:GetAttribute("Veiculo") == true then
		return modelo
	end
	return nil
end

-- Etapa 2: jogadores no raio (o atirador também). Parede entre o centro e o torso reduz o dano por fatorParede.
local function machucarJogadores(centro: Vector3, atirador: Player, proj: any)
	local ignorar = ignoradosDoMundo()
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(ignorar, j.Character)
		end
	end
	local monstros = workspace:FindFirstChild("Monstros")
	if monstros then
		table.insert(ignorar, monstros)
	end
	local params = paramsExcluindo(ignorar)

	for _, alvo in Players:GetPlayers() do
		local personagem = alvo.Character
		local torso = personagem
			and (personagem:FindFirstChild("UpperTorso") or personagem:FindFirstChild("HumanoidRootPart"))
		if not (torso and torso:IsA("BasePart") and Vida.estaVivo(alvo)) then
			continue
		end
		local d = torso.Position - centro
		local base = Regra.danoExplosao(d.Magnitude, proj.raioExplosao, proj.danoCentro, proj.fatorBorda)
		if base <= 0 then
			continue
		end
		if d.Magnitude > 0.1 and workspace:Raycast(centro, d, params) then
			base *= proj.fatorParede
		end
		local direcao = if d.Magnitude > 0.01 then d.Unit else Vector3.yAxis
		for _, parte in { "Torso", "Cabeca", "BracoE", "BracoD", "PernaE", "PernaD" } do
			if CfgCorpo.partes[parte] then
				Vida.dano(alvo, parte, base * MULT_PARTE_ATINGIDA[parte], {
					tipo = "jogador",
					jogador = atirador,
					direcao = direcao,
				})
			end
		end
	end
end

-- Etapas 3 e 4: monstros e carros dentro do raio (uma busca só).
local function machucarMonstrosECarros(centro: Vector3, atirador: Player, proj: any)
	local monstros: { [Model]: number } = {}
	local carros: { [Model]: { dist: number, peca: BasePart, ehCarroceria: boolean } } = {}
	for _, parte in workspace:GetPartBoundsInRadius(centro, proj.raioExplosao, OverlapParams.new()) do
		local dist = distanciaAteCaixa(parte, centro)
		local monstro = Monstros.ehMonstro(parte)
		if monstro then
			if monstros[monstro] == nil or dist < monstros[monstro] then
				monstros[monstro] = dist
			end
			continue
		end
		local carro = ehPecaVeiculo(parte)
		local nomePeca = parte:GetAttribute("PecaVeiculo")
		if carro and type(nomePeca) == "string" then
			local ehCarroceria = nomePeca == "Carroceria"
			local atual = carros[carro]
			if atual == nil then
				carros[carro] = { dist = dist, peca = parte, ehCarroceria = ehCarroceria }
			else
				atual.dist = math.min(atual.dist, dist)
				if ehCarroceria and not atual.ehCarroceria then
					atual.peca, atual.ehCarroceria = parte, true
				end
			end
		end
	end

	for modelo, dist in monstros do
		Monstros.dano(modelo, Regra.danoExplosao(dist, proj.raioExplosao, proj.dano.monstro, proj.fatorBorda), atirador)
	end
	local V = veiculos()
	if V then
		for _, c in carros do
			local dano = Regra.danoExplosao(c.dist, proj.raioExplosao, proj.dano.carro, proj.fatorBorda)
			if dano > 0 then
				V.acerto(c.peca, dano, atirador)
			end
		end
	end
end

local function explodir(centro: Vector3, atirador: Player, cfg: any)
	local proj = cfg.projetil
	local function etapa(nome: string, fn: () -> ())
		local ok, erro = pcall(fn)
		if not ok then
			warn("[Foguete] falha em " .. nome .. ": " .. tostring(erro))
		end
	end

	etapa("construção", function()
		local D = destruicao()
		if D and D.explosao then
			D.explosao(centro, proj.raioConstrucao, proj.danoConstrucao, atirador)
		end
	end)
	etapa("jogadores", function()
		machucarJogadores(centro, atirador, proj)
	end)
	etapa("monstros e carros", function()
		machucarMonstrosECarros(centro, atirador, proj)
	end)
	etapa("som", function()
		Ruido.emitir(centro, proj.ruidoExplosaoDb, "arma", atirador)
		Sons.tocar(cfg.somExplosao, centro, { db = proj.ruidoExplosaoDb })
		local evento = Rede.evento("Explosao")
		for _, j in Players:GetPlayers() do
			local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") and (raiz.Position - centro).Magnitude <= DISTANCIA_EXPLOSAO_CLIENTE then
				evento:FireClient(j, centro, proj.raioExplosao)
			end
		end
	end)
end

local function construir(origem: Vector3, direcao: Vector3): Part
	local apoio = if math.abs(direcao.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local cima = (apoio - direcao * direcao:Dot(apoio)).Unit

	local corpo = Instance.new("Part")
	corpo.Name = "Foguete"
	corpo.Shape = Enum.PartType.Cylinder -- o eixo do cilindro é o X da peça
	corpo.Size = Vector3.new(COMPRIMENTO, ESPESSURA, ESPESSURA)
	corpo.Color = Color3.fromRGB(58, 58, 64)
	corpo.Material = Enum.Material.Metal
	corpo.CFrame = CFrame.fromMatrix(origem + direcao * 1.2, direcao, cima)
	corpo.CanCollide = false
	corpo.CanQuery = false
	corpo.CanTouch = false
	corpo.CastShadow = false

	local ponta = Instance.new("Part")
	ponta.Name = "Ponta"
	ponta.Shape = Enum.PartType.Ball
	ponta.Size = Vector3.new(0.34, 0.34, 0.34)
	ponta.Color = Color3.fromRGB(255, 120, 40)
	ponta.Material = Enum.Material.Neon
	ponta.CFrame = corpo.CFrame * CFrame.new(COMPRIMENTO / 2, 0, 0)
	ponta.Massless = true
	ponta.CanCollide = false
	ponta.CanQuery = false
	ponta.CanTouch = false
	ponta.CastShadow = false
	local solda = Instance.new("WeldConstraint")
	solda.Part0 = corpo
	solda.Part1 = ponta
	solda.Parent = corpo
	ponta.Parent = corpo

	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 150, 70)
	luz.Brightness = 2
	luz.Range = 12
	luz.Parent = corpo

	local traseira0 = Instance.new("Attachment")
	traseira0.Position = Vector3.new(-COMPRIMENTO / 2, ESPESSURA / 2, 0)
	traseira0.Parent = corpo
	local traseira1 = Instance.new("Attachment")
	traseira1.Position = Vector3.new(-COMPRIMENTO / 2, -ESPESSURA / 2, 0)
	traseira1.Parent = corpo
	local rastro = Instance.new("Trail")
	rastro.Attachment0 = traseira0
	rastro.Attachment1 = traseira1
	rastro.Lifetime = 0.5
	rastro.LightEmission = 0.6
	rastro.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(90, 90, 95))
	rastro.Transparency = NumberSequence.new(0.2, 1)
	rastro.Parent = corpo
	return corpo
end

-- true se cabe mais um foguete no ar. Quem chama checa ANTES de gastar o pente.
function Foguete.cheio(): boolean
	return contagem >= MAX_ATIVOS
end

-- Lança o foguete de `atirador`. `cfg` = Config/Armas.armas.lancaFoguetes; `direcao` unitária. false = não lançou.
function Foguete.lancar(atirador: Player, cfg: any, origem: Vector3, direcao: Vector3): boolean
	local proj = cfg.projetil
	if contagem >= MAX_ATIVOS or type(proj) ~= "table" then
		return false
	end
	local corpo = construir(origem, direcao)
	local ignorarMundo = ignoradosDoMundo()
	table.insert(ignorarMundo, corpo)
	local paramsMundo = paramsExcluindo(ignorarMundo)
	local comAtirador = table.clone(ignorarMundo)
	if atirador.Character then
		table.insert(comAtirador, atirador.Character)
	end
	local paramsInicio = paramsExcluindo(comAtirador)

	corpo.Parent = pastaProjeteis()
	ativos[corpo] = true
	contagem += 1

	-- sem gravidade: força para cima igual ao peso (a massa só se conhece com a peça no mundo)
	local centro = Instance.new("Attachment")
	centro.Parent = corpo
	local forca = Instance.new("VectorForce")
	forca.Attachment0 = centro
	forca.RelativeTo = Enum.ActuatorRelativeTo.World
	forca.ApplyAtCenterOfMass = true
	forca.Force = Vector3.new(0, corpo.AssemblyMass * workspace.Gravity, 0)
	forca.Parent = corpo
	corpo.AssemblyLinearVelocity = direcao * proj.velocidade
	pcall(function()
		corpo:SetNetworkOwner(nil)
	end)

	local inicio = os.clock()
	local ultima = origem
	local conexao: RBXScriptConnection? = nil
	local terminou = false

	local function terminar(posicao: Vector3)
		if terminou then
			return
		end
		terminou = true
		if conexao then
			conexao:Disconnect()
		end
		if ativos[corpo] then
			ativos[corpo] = nil
			contagem -= 1
		end
		corpo:Destroy()
		explodir(posicao, atirador, cfg)
	end

	conexao = RunService.Heartbeat:Connect(function()
		if terminou then
			return
		end
		if not corpo.Parent then
			-- destruído por fora (Foguete.limpar ou limpeza do workspace)
			terminou = true
			if conexao then
				conexao:Disconnect()
			end
			if ativos[corpo] then
				ativos[corpo] = nil
				contagem -= 1
			end
			return
		end
		local decorrido = os.clock() - inicio
		local posicao = corpo.Position
		local passo = posicao - ultima
		if passo.Magnitude > 1e-4 then
			local acerto =
				workspace:Raycast(ultima, passo, if decorrido < IGNORA_ATIRADOR then paramsInicio else paramsMundo)
			if acerto then
				return terminar(acerto.Position + acerto.Normal * RECUO_NORMAL)
			end
		end
		ultima = posicao
		if decorrido >= proj.vida then
			terminar(posicao)
		end
	end)
	return true
end

-- Destrói todos os foguetes no ar (encerramento do servidor, testes).
function Foguete.limpar()
	for corpo in ativos do
		corpo:Destroy()
	end
end

function Foguete.iniciar()
	pastaProjeteis()
	game:BindToClose(Foguete.limpar)
end

return Foguete
