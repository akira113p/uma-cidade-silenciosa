-- ViewmodelGB: 1ª pessoa das armas do Gold Bright (docs/gold-bright-import.md). Só VISUAL e só local.
-- Clona o molde ReplicatedStorage.ArmasGB.<id> (posto lá pelo server/ArmasGB) e reproduz o que o jogo original faz por cima das
-- animações (WeaponModelRecoil.Update/Fire e GunHandler, decompilados; valores por arma em Config/ArmasGB.<id>.vista):
--   câmera -> nó da arma (quadril <-> mira, lerp velMira) -> "Recoil Position" (offset de corrida/parede ou de "não atira",
--   menos pitch/1080 para a frente, + coice de posição; rotação = sway + coice + pose + rotação de mira) -> raiz do rig -> malha.
-- A câmera das armas do original tem FOV 55 (a nossa ~70): o rig chega mais perto da câmera para dar a mesma projeção na
-- profundidade das mãos. Animações: Draw ao equipar, Idle em loop, Fire, Cock, Reload Phase 1-2-3 ("- Empty" com o pente vazio)
-- encaixadas na duração do servidor, Check Ammo (+ Close), Melee Attack (+ Fast); "Open Bolt" com o pente vazio (camada de ferrolho).
-- Relógio: cruz de vida no mostrador (verde/amarela/laranja/vermelha). Luneta: mira completa = retículo em tela cheia com zoom.
-- Sem molde (asset não carregou) `assumiu` devolve false e o client/ArmasViewmodel segue com o caminho dele.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgGB = require(Config:WaitForChild("ArmasGB"))
local CfgAparencia = require(Config:WaitForChild("Aparencia"))
local CfgCorpo = require(Config:WaitForChild("Corpo"))
local CfgVista = require(Config:WaitForChild("ArmasVista"))
local ArmasSinais = require(script.Parent.ArmasSinais)

local ViewmodelGB = {}

local jogador = Players.LocalPlayer
local PRIORIDADE = Enum.RenderPriority.Camera.Value + 5 -- depois do ArmasViewmodel (+4), que cede a vez quando este assume
local PARTES_CORPO = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
local LIMITE_GIRO = 0.5 -- rad por quadro: giro maior (teleporte, respawn) não vira sway
local TAN_FOV_ARMAS = math.tan(math.rad(55 / 2)) -- OverlayCam do Gold Bright
local G = CfgVista.gb

type Entrada = { id: string, dur: number, loop: boolean }
type Agendado = { t: number, estado: string, vel: number }

-- Estado ------------------------------------------------------------------------------------------------------------------
local armaId: string? = nil
local cfg: any = nil
local modelo: Model? = nil
local malha: BasePart? = nil
local animador: Animator? = nil
local trilhas: { [string]: AnimationTrack } = {}
local acao: { AnimationTrack } = {}
local acaoAte = 0 -- os.clock() em que a ação atual termina (recarga, engatilhar, checar): sem pose de corrida/parede
local idle: { AnimationTrack } = {}
local ferrolho: { AnimationTrack } = {} -- "Open Bolt" (pente vazio)
local fila: { Agendado } = {}
local recarga: { inicio: number, duracao: number }? = nil
local querDraw = false
local ligado = false
local camAnterior: CFrame? = nil
local ultimaMalha: CFrame? = nil
local guardadas: { [BasePart]: number } = {}
local promptsVisiveis = 0
local cruz: { Part }? = nil
local gui: ScreenGui? = nil
local rng = Random.new()

-- pose (porta do WeaponModelRecoil): tudo no espaço da câmera, studs e graus (Euler YXZ do Roblox)
local posArma = Vector3.zero -- nó da arma (lerp quadril <-> mira)
local offsetLerp = Vector3.zero -- lerpedPositionOffset (corrida/parede/não atira + pitch)
local rotPose = Vector3.zero -- aditionalMovementRotation
local coicePos = Vector3.zero -- positionalRecoil (volta a zero)
local coiceRot = Vector3.zero -- rotationalRecoil (volta a zero)
local recoilLocal = Vector3.zero -- Recoil Position.localPosition (segue coice + offset)
local rotAtual = CFrame.identity -- Recoil Position.localRotation (segue o alvo)
local sway = Vector3.zero
local mira = 0
local inclinar = 0 -- graus: o rig gira para cima em volta da câmera (ajuste nosso, ver Config/ArmasVista.gb.inclinar)

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function euler(v: Vector3): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

local function lerp(a: any, b: any, k: number): any
	return a + (b - a) * math.clamp(k, 0, 1)
end

local function pasta(): Instance?
	return ReplicatedStorage:FindFirstChild("ArmasGB")
end

local function limitar(v: number): number
	return math.clamp(v, G.velocidade.minimo, G.velocidade.maximo)
end

-- Corpo real ----------------------------------------------------------------------------------------------------------------
local function esconderCorpo(personagem: Model)
	local raizes: { Instance } = {}
	for _, nome in PARTES_CORPO do
		local p = personagem:FindFirstChild(nome)
		if p then
			table.insert(raizes, p)
		end
	end
	for _, filho in personagem:GetChildren() do
		if filho.Name == "ArmaNaMao" or filho.Name == "ItemNaMao" then
			table.insert(raizes, filho)
		end
	end
	for _, raiz in raizes do
		local lista = raiz:GetDescendants()
		table.insert(lista, raiz)
		for _, d in lista do
			if d:IsA("BasePart") then
				if guardadas[d] == nil then
					guardadas[d] = d.LocalTransparencyModifier
				end
				d.LocalTransparencyModifier = 1
			end
		end
	end
end

local function restaurarCorpo()
	for parte, antes in guardadas do
		if parte.Parent then
			local naMao = parte:FindFirstAncestor("ArmaNaMao") or parte:FindFirstAncestor("ItemNaMao")
			parte.LocalTransparencyModifier = if naMao then 0 else antes
		end
	end
	table.clear(guardadas)
end

-- Luneta (retículo em tela cheia) ---------------------------------------------------------------------------------------------
local function telaLuneta(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "LunetaGB"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 5
	g.Enabled = false
	local circulo = Instance.new("Frame")
	circulo.Name = "Lente"
	circulo.AnchorPoint = Vector2.new(0.5, 0.5)
	circulo.Position = UDim2.fromScale(0.5, 0.5)
	circulo.Size = UDim2.fromScale(0.78, 0.78)
	circulo.BackgroundTransparency = 1
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.DominantAxis = Enum.DominantAxis.Height
	ar.Parent = circulo
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0.5, 0)
	canto.Parent = circulo
	local borda = Instance.new("UIStroke") -- borda grossa preta = tudo fora da lente
	borda.Thickness = 2000
	borda.Color = Color3.new(0, 0, 0)
	borda.Parent = circulo
	for _, d in { { 1, 0.004, 0, 0.5 }, { 0.004, 1, 0.5, 0 } } do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		l.Size = UDim2.fromScale(d[1], d[2])
		l.Position = UDim2.fromScale(d[3], d[4])
		l.AnchorPoint = Vector2.new(d[3], d[4])
		l.Parent = circulo
	end
	circulo.Parent = g
	g.Parent = jogador:WaitForChild("PlayerGui")
	gui = g
	return g
end

-- Modelo e trilhas ----------------------------------------------------------------------------------------------------------
local function destruir()
	for _, t in trilhas do
		t:Stop(0)
	end
	table.clear(trilhas)
	table.clear(acao)
	table.clear(idle)
	table.clear(ferrolho)
	table.clear(fila)
	recarga = nil
	if modelo then
		modelo:Destroy()
	end
	modelo, malha, animador, ultimaMalha, cruz = nil, nil, nil, nil, nil
	if gui then
		gui.Enabled = false
	end
	jogador:SetAttribute("LunetaZoom", nil)
end

-- `deIdle`: trilha própria do loop (o mesmo clipe pode ser Idle e parte de uma ação, ex. o Draw da arma = TT33_Self_Idle).
local function trilha(e: Entrada, chaveExtra: string?): AnimationTrack?
	local a = animador
	if not a then
		return nil
	end
	local chave = e.id .. (chaveExtra or "")
	local t = trilhas[chave]
	if t then
		return t
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = e.id
	local ok, nova = pcall(function()
		return a:LoadAnimation(anim)
	end)
	if not ok then
		warn("[ViewmodelGB] não carregou " .. e.id .. ": " .. tostring(nova))
		return nil
	end
	trilhas[chave] = nova
	return nova
end

local function duracaoNatural(estado: string): number
	local lista = cfg and cfg.estados[estado]
	if not lista then
		return 0
	end
	local d = 0
	for _, e in lista do
		d = math.max(d, e.dur)
	end
	return d
end

-- Toca um estado (todas as trilhas dele juntas), parando a ação anterior. Devolve false se o estado não existe.
local function tocar(estado: string, vel: number, fade: number): boolean
	local lista = cfg and cfg.estados[estado]
	if not lista then
		return false
	end
	for _, t in acao do
		t:Stop(fade)
	end
	table.clear(acao)
	for _, e in lista do
		local t = trilha(e)
		if t then
			t.Priority = Enum.AnimationPriority.Action
			t.Looped = false
			t:Play(fade, 1, vel)
			table.insert(acao, t)
		end
	end
	if estado ~= "Fire" and estado ~= "Draw" then
		acaoAte = math.max(acaoAte, os.clock() + duracaoNatural(estado) / math.max(vel, 0.01))
	end
	return true
end

local function pararAcao(fade: number)
	for _, t in acao do
		t:Stop(fade)
	end
	table.clear(acao)
	table.clear(fila)
	recarga = nil
	acaoAte = 0
end

local function tocarLoop(estado: string, destino: { AnimationTrack }, prioridade: Enum.AnimationPriority, chave: string)
	local lista = cfg and cfg.estados[estado]
	table.clear(destino)
	if not lista then
		return
	end
	for _, e in lista do
		local t = trilha(e, chave)
		if t then
			t.Priority = prioridade
			t.Looped = true
			t:Play(G.fade.idle, 1, 1)
			table.insert(destino, t)
		end
	end
end

local function criarCruz(m: Model): { Part }?
	local r = cfg.vista and cfg.vista.relogio
	if not r then
		return nil
	end
	local d = r.diametro
	local pecas = {}
	local k = G.relogio.tamanho
	for _, tam in { Vector3.new(k * d, 0.28 * k * d, 0.01 * d), Vector3.new(0.28 * k * d, k * d, 0.01 * d) } do
		local p = Instance.new("Part")
		p.Name = "CruzVida"
		p.Size = tam
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
		table.insert(pecas, p)
	end
	return pecas
end

local function construir(camera: Camera): boolean
	local p = pasta()
	local molde = p and armaId and p:FindFirstChild(armaId)
	if not (molde and molde:IsA("Model")) then
		return false
	end
	local m = molde:Clone()
	local parte = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not parte then
		m:Destroy()
		return false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	local controlador = Instance.new("AnimationController")
	controlador.Parent = m
	local a = Instance.new("Animator")
	a.Parent = controlador
	m.Name = "ViewmodelGB"
	m.Parent = camera
	modelo, malha, animador = m, parte, a
	cruz = criarCruz(m)
	tocarLoop("Idle", idle, Enum.AnimationPriority.Idle, "#idle")
	if querDraw then
		querDraw = false
		tocar("Draw", 1, G.fade.acao)
	end
	return true
end

-- Sinais --------------------------------------------------------------------------------------------------------------------
local function zerarPose()
	local v = cfg and cfg.vista
	posArma = if v then vec(v.quadril) else Vector3.zero
	offsetLerp, rotPose, coicePos, coiceRot, sway = Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero
	recoilLocal = if v then vec(v.recoilPosition) else Vector3.zero
	rotAtual = CFrame.identity
	mira = 0
end

local function aoEquipar(id: string?)
	destruir()
	armaId = id
	cfg = if id then CfgGB.armas[id] else nil
	if not cfg then
		armaId = nil
		return
	end
	querDraw = true
	acaoAte = 0
	zerarPose()
end

local function aoDisparar(id: string)
	if id ~= armaId or not modelo then
		return
	end
	tocar("Fire", 1, G.fade.tiro)
	local v = cfg.vista
	if not v then
		return
	end
	-- WeaponModelRecoil.Fire: rotação (-x, ±y, ±z) e posição (±x, -y, -z) do Unity -> Roblox: rotação (x, ±y, ±z), posição (±x, -y, +z)
	local r = vec(if mira > 0.5 then v.coiceRotMira else v.coiceRotQuadril)
	local k = vec(if mira > 0.5 then v.coicePosMira else v.coicePosQuadril)
	coiceRot = Vector3.new(r.X, rng:NextNumber(-r.Y, r.Y), rng:NextNumber(-r.Z, r.Z)) * G.coiceEscala
	coicePos = Vector3.new(rng:NextNumber(-k.X, k.X), -k.Y, k.Z) * G.coiceEscala
end

local function aoGolpear(id: string, indice: number?)
	if id ~= armaId or not modelo then
		return
	end
	local estado = if indice == 2 and cfg.estados["Melee Attack Fast"] then "Melee Attack Fast" else "Melee Attack"
	tocar(estado, 1, G.fade.acao)
end

local function aoRecarregar(id: string, duracao: number)
	if id ~= armaId or not modelo or duracao <= 0 then
		return
	end
	local vazia = jogador:GetAttribute("Pente") == 0
	local fases = {}
	local natural = 0
	for i = 1, 3 do
		local nome = "Reload Phase " .. i
		if vazia and cfg.estados[nome .. " - Empty"] then
			nome ..= " - Empty"
		end
		if cfg.estados[nome] then
			table.insert(fases, nome)
			natural += duracaoNatural(nome)
		end
	end
	if #fases == 0 then
		return
	end
	local vel = limitar(natural / duracao)
	local agora = os.clock()
	table.clear(fila)
	local t = agora
	for _, nome in fases do
		table.insert(fila, { t = t, estado = nome, vel = vel })
		t += duracaoNatural(nome) / vel
	end
	recarga = { inicio = agora, duracao = duracao }
	acaoAte = agora + duracao
end

local function aoFimRecarga(id: string, cancelada: boolean)
	if id ~= armaId then
		return
	end
	if cancelada then
		pararAcao(G.fade.acao)
	else
		recarga = nil
	end
end

local function aoReajustarRecarga(id: string, duracaoNova: number)
	local r = recarga
	if id ~= armaId or not r or duracaoNova <= 0 then
		return
	end
	local k = duracaoNova / r.duracao
	for _, f in fila do
		f.t = r.inicio + (f.t - r.inicio) * k
		f.vel = limitar(f.vel / k)
	end
	for _, t in acao do
		t:AdjustSpeed(limitar(t.Speed / k))
	end
	r.duracao = duracaoNova
	acaoAte = r.inicio + duracaoNova
end

local function aoEngatilhar(id: string, tempo: number, _destravar: boolean)
	if id ~= armaId or not modelo then
		return
	end
	local nat = duracaoNatural("Cock")
	tocar("Cock", if nat > 0 and tempo > 0 then limitar(nat / tempo) else 1, G.fade.acao)
end

local function aoChecar(id: string, duracao: number)
	if id ~= armaId or not modelo then
		return
	end
	local vazia = jogador:GetAttribute("Pente") == 0
	local abrir = if vazia and cfg.estados["Check Ammo Empty"] then "Check Ammo Empty" else "Check Ammo"
	local fechar = abrir .. " Close"
	local mesmo = cfg.estados[fechar] and cfg.estados[fechar][1].id == cfg.estados[abrir][1].id
	local nat = duracaoNatural(abrir) + (if mesmo or not cfg.estados[fechar] then 0 else duracaoNatural(fechar))
	local vel = if nat > 0 and duracao > 0 then limitar(nat / duracao) else 1
	table.clear(fila)
	tocar(abrir, vel, G.fade.acao)
	if cfg.estados[fechar] and not mesmo then
		table.insert(fila, { t = os.clock() + duracaoNatural(abrir) / vel, estado = fechar, vel = vel })
	end
end

-- Quadro --------------------------------------------------------------------------------------------------------------------
local function desligar()
	if not ligado then
		return
	end
	ligado = false
	if modelo then
		modelo.Parent = nil
	end
	if gui then
		gui.Enabled = false
	end
	jogador:SetAttribute("LunetaZoom", nil)
	restaurarCorpo()
	camAnterior = nil
	ultimaMalha = nil
end

local function emPrimeiraPessoa(personagem: Model, camera: Camera): boolean
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	local cabeca = personagem:FindFirstChild("Head")
	if not (humanoide and cabeca and cabeca:IsA("BasePart")) then
		return false
	end
	if humanoide.Health <= 0 or jogador:GetAttribute("Morto") == true or humanoide.SeatPart ~= nil then
		return false
	end
	return (camera.CFrame.Position - cabeca.Position).Magnitude < CfgAparencia.distanciaPrimeiraPessoa
end

-- distância até a parede à frente (GunHandler.distToWall), em metros do jogo original
local paramsParede = RaycastParams.new()
paramsParede.FilterType = Enum.RaycastFilterType.Exclude
local function distanciaParede(camera: Camera, personagem: Model, escala: number): number
	paramsParede.FilterDescendantsInstances = { personagem, camera }
	local alcance = G.parede.metros * escala
	local r = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * alcance, paramsParede)
	return if r then r.Distance / escala else math.huge
end

local function fracaoVida(): number
	local f = 1
	for nome, parte in CfgCorpo.partes do
		if parte.fatal then
			local v = jogador:GetAttribute("Vida_" .. nome)
			if type(v) == "number" then
				f = math.min(f, v / parte.vida)
			end
		end
	end
	return f
end

local function atualizarCruz()
	local c = cruz
	local m = malha
	local r = cfg.vista and cfg.vista.relogio
	if not (c and m and r) then
		return
	end
	local osso = m:FindFirstChild(r.osso, true)
	if not (osso and osso:IsA("Bone")) then
		return
	end
	local o = r.cf
	local face = osso.TransformedWorldCFrame
		* CFrame.new(o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9], o[10], o[11], o[12])
	-- a frente do mostrador (normal para fora) é o LookVector deste CFrame; a cruz fica um fio acima do vidro
	local cf = face * CFrame.new(0, 0, -0.02 * r.diametro)
	local f = fracaoVida()
	local cores = G.relogio.cores
	local cor = if f > G.relogio.verde
		then cores.verde
		elseif f > G.relogio.amarelo then cores.amarelo
		elseif f > G.relogio.laranja then cores.laranja
		else cores.vermelho
	for _, p in c do
		p.CFrame = cf
		p.Color = Color3.fromRGB(cor[1], cor[2], cor[3])
	end
end

local function passo(dt: number)
	local personagem = jogador.Character
	local camera = workspace.CurrentCamera
	if not (armaId and cfg and personagem and camera and emPrimeiraPessoa(personagem, camera)) then
		desligar()
		return
	end
	if not modelo and not construir(camera) then
		desligar()
		return
	end
	local m = modelo :: Model
	if m.Parent ~= camera then
		m.Parent = camera
	end
	ligado = true
	local agora = os.clock()
	while fila[1] and agora >= fila[1].t do
		local f = table.remove(fila, 1) :: Agendado
		tocar(f.estado, f.vel, G.fade.acao)
	end
	for _, t in idle do
		if not t.IsPlaying then
			t:Play(G.fade.idle, 1, 1)
		end
	end
	-- camada de ferrolho do original: pente vazio = "Open Bolt" (ferrolho/corrediça travados atrás)
	local vazio = jogador:GetAttribute("Pente") == 0 and not recarga
	if vazio and #ferrolho == 0 and cfg.estados["Open Bolt"] then
		tocarLoop("Open Bolt", ferrolho, Enum.AnimationPriority.Movement, "#ferrolho")
	elseif not vazio and #ferrolho > 0 then
		for _, t in ferrolho do
			t:Stop(G.fade.acao)
		end
		table.clear(ferrolho)
	end
	esconderCorpo(personagem)

	local v = cfg.vista
	if not v then
		return
	end
	local s = v.escala
	-- mira (botão direito; Player.Mirando, sem correr)
	local querMira = jogador:GetAttribute("Mirando") == true and jogador:GetAttribute("Correndo") ~= true
	local alvoArma = if querMira then vec(v.mira) else vec(v.quadril)
	posArma = lerp(posArma, alvoArma, v.velMira * dt)
	mira = lerp(mira, if querMira then 1 else 0, v.velMira * dt)

	-- pose de corrida/parede ou de "não atira" (prompt de interação na tela), fora de recarga/engatilhar/checar
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	local movendo = humanoide ~= nil and humanoide.MoveDirection.Magnitude > 0.1
	local correndo = jogador:GetAttribute("Correndo") == true and movendo
	local ocupado = agora < acaoAte
	local alvoOff, alvoRot = Vector3.zero, Vector3.zero
	if not ocupado and not querMira then
		if correndo or distanciaParede(camera, personagem, s) < G.parede.metros then
			alvoOff, alvoRot = vec(v.corrida.pos), vec(v.corrida.rot)
		elseif promptsVisiveis > 0 then
			alvoOff, alvoRot = vec(v.naoAtira.pos), vec(v.naoAtira.rot)
		end
	end
	-- olhar para baixo traz a arma para perto: -pitch/1080 * forward (metros) no original
	local pitch = -math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	alvoOff += Vector3.new(0, 0, pitch / 1080 * s)
	offsetLerp = lerp(offsetLerp, alvoOff, G.velPose * dt)
	rotPose = lerp(rotPose, alvoRot, G.velPose * dt)

	-- coice: alvo volta a zero (voltaPos/voltaRot), a Recoil Position segue o alvo (velRecuoPos/velRecuoRot)
	coicePos = lerp(coicePos, Vector3.zero, v.voltaPos * dt)
	coiceRot = lerp(coiceRot, Vector3.zero, v.voltaRot * dt)
	recoilLocal = lerp(recoilLocal, vec(v.recoilPosition) + offsetLerp + coicePos, v.velRecuoPos * dt)

	-- sway: a arma atrasa contra o giro da câmera (graus)
	local giro = Vector3.zero
	if camAnterior then
		local rel = camAnterior:ToObjectSpace(camera.CFrame)
		local rx, ry = rel:ToEulerAnglesYXZ()
		if math.abs(rx) < LIMITE_GIRO and math.abs(ry) < LIMITE_GIRO then
			giro = Vector3.new(math.deg(rx), math.deg(ry), 0)
		end
	end
	camAnterior = camera.CFrame
	local sw = G.sway
	local kSway = (1 - (1 - G.mira.sway) * mira) * v.swayRot
	local alvoSway = Vector3.new(
		math.clamp(-giro.X * sw.ganho * 10, -sw.maximo, sw.maximo),
		math.clamp(-giro.Y * sw.ganho * 10, -sw.maximo, sw.maximo),
		math.clamp(giro.Y * sw.ganho * 5, -sw.maximo, sw.maximo)
	) * kSway
	sway = lerp(sway, alvoSway, sw.suavizar * dt)
	local alvoRotTotal = sway + coiceRot + rotPose + vec(v.rotMira) * mira
	rotAtual = rotAtual:Lerp(euler(alvoRotTotal), math.clamp(v.velRecuoRot * dt, 0, 1))

	-- ajuste nosso (não está nos dados do original): o rig sobe um pouco no quadril (relógio visível como nas imagens de
	-- referência) e mais durante checar/recarregar/engatilhar (a ação aparece no meio da tela); mirando volta a zero
	local alvoInclinar = (if ocupado then G.inclinar.acao else G.inclinar.base) * (1 - mira)
	inclinar = lerp(inclinar, alvoInclinar, G.inclinar.suavizar * dt)

	-- câmera das armas de FOV 55: aproxima o rig para a mesma projeção na profundidade das mãos
	local k = TAN_FOV_ARMAS / math.tan(math.rad(camera.FieldOfView / 2))
	local aproximar = (1 - k) * v.profundidade * G.emularFov

	-- luneta: mira completa = retículo em tela cheia, arma escondida, zoom (client/Camera lê LunetaZoom)
	local naLuneta = v.luneta and mira > G.luneta.limiar
	if v.luneta then
		local tela = telaLuneta()
		tela.Enabled = naLuneta
		jogador:SetAttribute("LunetaZoom", if naLuneta then G.luneta.zoom else nil)
	end

	local aj = G.porArma[armaId :: string] or G.ajuste
	local cf = camera.CFrame
		* CFrame.Angles(math.rad(inclinar), 0, 0)
		* CFrame.new(Vector3.new(0, 0, aproximar) + Vector3.new(aj.pos.x, aj.pos.y, aj.pos.z))
		* CFrame.fromEulerAnglesYXZ(math.rad(aj.rot.x), math.rad(aj.rot.y), math.rad(aj.rot.z))
		* CFrame.new(posArma + recoilLocal)
		* rotAtual
		* CFrame.new(vec(v.raiz))
		* CFrame.new(vec(v.malhaNaRaiz))
	local mp = malha :: BasePart
	mp.CFrame = cf
	mp.LocalTransparencyModifier = if naLuneta then 1 else 0
	ultimaMalha = cf
	if cruz then
		for _, p in cruz do
			p.LocalTransparencyModifier = mp.LocalTransparencyModifier
		end
		atualizarCruz()
	end
end

-- API -----------------------------------------------------------------------------------------------------------------------
-- true se esta arma tem viewmodel do Gold Bright pronto (config + molde no ReplicatedStorage): o ArmasViewmodel cede a vez.
function ViewmodelGB.assumiu(id: string?): boolean
	if not id or not CfgGB.armas[id] then
		return false
	end
	local p = pasta()
	return p ~= nil and p:FindFirstChild(id) ~= nil
end

function ViewmodelGB.ativo(): boolean
	return ligado and modelo ~= nil
end

-- Ponta da arma no mundo (clarão e rastro do EfeitosArma).
function ViewmodelGB.bocaMundo(): CFrame?
	local base = ultimaMalha
	if not (base and cfg) then
		return nil
	end
	local b = cfg.boca
	return base * CFrame.new(b[1], b[2], b[3])
end

function ViewmodelGB.iniciar()
	ArmasSinais.ouvir("equipou", aoEquipar)
	ArmasSinais.ouvir("disparou", aoDisparar)
	ArmasSinais.ouvir("golpeou", aoGolpear)
	ArmasSinais.ouvir("recarregou", aoRecarregar)
	ArmasSinais.ouvir("recargaFim", aoFimRecarga)
	ArmasSinais.ouvir("engatilhou", aoEngatilhar)
	ArmasSinais.ouvir("checou", aoChecar)
	ArmasSinais.ouvir("recargaRapida", aoReajustarRecarga)
	ArmasSinais.ouvir("recargaFalhou", aoReajustarRecarga)
	-- "não atira" do original: a arma levanta quando há algo para interagir (E) na tela
	ProximityPromptService.PromptShown:Connect(function(prompt)
		promptsVisiveis += 1
		prompt.PromptHidden:Once(function()
			promptsVisiveis = math.max(0, promptsVisiveis - 1)
		end)
	end)
	jogador.CharacterAdded:Connect(function()
		destruir()
		restaurarCorpo()
		zerarPose()
	end)
	RunService:BindToRenderStep("ViewmodelGB", PRIORIDADE, passo)
end

return ViewmodelGB
