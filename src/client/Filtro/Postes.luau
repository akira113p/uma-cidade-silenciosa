-- Filtro · Postes: à noite, cones de luz (SpotLight + Beam) e halos nos postes mais próximos. Dono: S4.
-- Contrato: docs/filtro.md §3 e §5. Pool fixo de instâncias (nada é criado por quadro); fórmulas em Regras/FiltroPostes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("FiltroPostes"))
local ConfigPostes = require(Shared:WaitForChild("Config"):WaitForChild("Filtro"):WaitForChild("Postes"))

local Postes = {}

local ctx
local pastaPool
local ligado = true
local nivelAtual = 3
local visivel = false -- algo está aceso/visível no momento
local acumulado = 0
local textoCone = ""
local textoHalo = ""

local NOMES = {}
for _, nome in ConfigPostes.nomes do
	NOMES[nome] = true
end

local registro = {} -- [Model] = rec
local lista = {} -- recs em ordem (para varrer)
local slotsLuz = {}
local slotsHalo = {}

local function cor3(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- lâmpada = BasePart Glass mais baixa do modelo
local function acharLampada(modelo: Model): BasePart?
	local melhor: BasePart? = nil
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass then
			if not melhor or d.Position.Y < melhor.Position.Y then
				melhor = d
			end
		end
	end
	return melhor
end

-- filtro barato: nome primeiro (tabela), depois IsA
local function adicionar(d: Instance)
	if NOMES[d.Name] and d:IsA("Model") and not registro[d] then
		local rec = { modelo = d, tentativas = 0 }
		registro[d] = rec
		table.insert(lista, rec)
	end
end

local function liberarLuz(rec)
	local s = rec.slotLuz
	if s then
		s.rec = nil
		s.spot.Enabled = false
		s.beam.Enabled = false
		rec.slotLuz = nil
	end
	if rec.luzesMapa then
		for _, l in rec.luzesMapa do
			if l.Parent then
				l.Enabled = true
			end
		end
		rec.luzesMapa = nil
	end
end

local function liberarHalo(rec)
	local s = rec.slotHalo
	if s then
		s.rec = nil
		s.gui.Enabled = false
		s.gui.Adornee = nil
		rec.slotHalo = nil
	end
end

local function remover(d: Instance)
	local rec = registro[d]
	if rec then
		liberarLuz(rec)
		liberarHalo(rec)
		registro[d] = nil
		local i = table.find(lista, rec)
		if i then
			lista[i] = lista[#lista]
			lista[#lista] = nil
		end
	end
end

-- acha a lâmpada (com algumas tentativas: o streaming pode trazer as peças depois do Model)
local function resolver(rec): boolean
	if rec.lampada and rec.lampada.Parent then
		return true
	end
	if rec.tentativas >= 5 then
		return false
	end
	rec.tentativas += 1
	local l = acharLampada(rec.modelo)
	if not l then
		return false
	end
	rec.lampada = l
	rec.pos = l.Position
	rec.estado = Regras.estadoLampada(rec.pos.X, rec.pos.Z, ConfigPostes)
	rec.chao = nil
	return true
end

local function achaChao(rec)
	if rec.chao then
		return rec.chao
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = { rec.modelo }
	local origem = rec.pos - Vector3.new(0, ConfigPostes.recuoLuz, 0)
	local r = workspace:Raycast(origem, Vector3.new(0, -ConfigPostes.alcanceRaio, 0), p)
	rec.chao = if r then r.Position else origem - Vector3.new(0, ConfigPostes.alturaPadrao, 0)
	return rec.chao
end

local function criarPool()
	pastaPool = Instance.new("Part")
	pastaPool.Name = "PostesPool"
	pastaPool.Anchored = true
	pastaPool.CanCollide = false
	pastaPool.CanQuery = false
	pastaPool.CanTouch = false
	pastaPool.CastShadow = false
	pastaPool.Transparency = 1
	pastaPool.Size = Vector3.one
	pastaPool.CFrame = CFrame.new(0, -1000, 0)
	pastaPool.Parent = ctx.pastaMundo

	local cor = cor3(ConfigPostes.cor)
	for i = 1, ConfigPostes.maxLuzes do
		local a0 = Instance.new("Attachment")
		a0.Name = "Luz" .. i
		a0.Parent = pastaPool
		local a1 = Instance.new("Attachment")
		a1.Name = "Chao" .. i
		a1.Parent = pastaPool
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = ConfigPostes.anguloSpot
		spot.Range = ConfigPostes.alcanceSpot
		spot.Color = cor
		spot.Shadows = false
		spot.Enabled = false
		spot.Brightness = 0
		spot.Parent = a0
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Texture = textoCone
		beam.Color = ColorSequence.new(cor)
		beam.Width0 = ConfigPostes.coneLargura0
		beam.Width1 = ConfigPostes.coneLargura1
		beam.Transparency = NumberSequence.new(1)
		beam.Enabled = false
		beam.Parent = a0
		slotsLuz[i] = { att0 = a0, att1 = a1, spot = spot, beam = beam, transp = 1 }
	end

	for i = 1, ConfigPostes.maxHalos do
		local gui = Instance.new("BillboardGui")
		gui.Name = "Halo" .. i
		gui.Size = UDim2.fromScale(ConfigPostes.haloTamanho, ConfigPostes.haloTamanho)
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = ConfigPostes.alcanceHalo
		gui.ResetOnSpawn = false
		gui.Enabled = false
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = textoHalo
		img.ImageColor3 = cor
		img.ImageTransparency = 1
		img.Parent = gui
		gui.Parent = ctx.pastaMundo
		slotsHalo[i] = { gui = gui, img = img }
	end
end

local function apagarTudo()
	for _, rec in lista do
		liberarLuz(rec)
		liberarHalo(rec)
	end
	for _, s in slotsLuz do
		s.spot.Enabled = false
		s.beam.Enabled = false
	end
	for _, s in slotsHalo do
		s.gui.Enabled = false
	end
	visivel = false
end

local function slotLivre(slots)
	for _, s in slots do
		if not s.rec then
			return s
		end
	end
	return nil
end

-- 4 Hz: reescolhe quem tem luz e quem tem halo
local function escolher()
	local camPos = ctx.camera.CFrame.Position
	local alcance = ctx.ajuste("PostesAlcance", ConfigPostes.alcance)
	local comLuz, dLuz, comHalo, dHalo = {}, {}, {}, {}
	for _, rec in lista do
		if rec.estado ~= "quebrada" and resolver(rec) and rec.estado ~= "quebrada" then
			local d = (rec.pos - camPos).Magnitude
			if d <= ConfigPostes.alcanceHalo then
				table.insert(comHalo, rec)
				table.insert(dHalo, d)
				if d <= alcance and nivelAtual >= 2 then
					table.insert(comLuz, rec)
					table.insert(dLuz, d)
				end
			end
		end
	end

	local querLuz, querHalo = {}, {}
	for _, i in Regras.maisPerto(dLuz, ConfigPostes.maxLuzes) do
		querLuz[comLuz[i]] = true
	end
	for _, i in Regras.maisPerto(dHalo, ConfigPostes.maxHalos) do
		querHalo[comHalo[i]] = true
	end

	for _, rec in lista do
		if rec.slotLuz and not querLuz[rec] then
			liberarLuz(rec)
		end
		if rec.slotHalo and not querHalo[rec] then
			liberarHalo(rec)
		end
	end

	for rec in querLuz do
		if not rec.slotLuz then
			local s = slotLivre(slotsLuz)
			if s then
				s.rec = rec
				rec.slotLuz = s
				s.att0.WorldPosition = rec.pos - Vector3.new(0, ConfigPostes.recuoLuz, 0)
				s.att1.WorldPosition = achaChao(rec)
				-- não duplicar luz forte: desliga a PointLight do mapa enquanto o pool usa o poste
				local luzes = {}
				for _, d in rec.modelo:GetDescendants() do
					if d:IsA("PointLight") and d.Enabled then
						d.Enabled = false
						table.insert(luzes, d)
					end
				end
				rec.luzesMapa = luzes
			end
		end
	end
	for rec in querHalo do
		if not rec.slotHalo then
			local s = slotLivre(slotsHalo)
			if s then
				s.rec = rec
				rec.slotHalo = s
				s.gui.Adornee = rec.lampada
			end
		end
	end
end

function Postes.iniciar(c)
	ctx = c
	textoCone = ctx.config.Texturas.coneLuz
	textoHalo = ctx.config.Texturas.halo
	criarPool()

	task.spawn(function()
		local mapa = workspace:WaitForChild("Mapa", 60)
		if not mapa then
			return
		end
		mapa.DescendantAdded:Connect(adicionar)
		mapa.DescendantRemoving:Connect(remover)
		local n = 0
		for _, d in mapa:GetDescendants() do
			adicionar(d)
			n += 1
			if n % 4000 == 0 then
				task.wait()
			end
		end
	end)
end

function Postes.atualizar(e)
	if not ligado then
		return
	end
	local fator = math.clamp((e.noite - ConfigPostes.limiarNoite) / ConfigPostes.faixaNoite, 0, 1)
	if fator <= 0 then
		if visivel then
			apagarTudo()
		end
		return
	end
	visivel = true

	acumulado += e.dt
	if acumulado >= ConfigPostes.intervaloEscolha then
		acumulado = 0
		escolher()
	end

	local brilho = ctx.ajuste("PostesBrilho", ConfigPostes.brilhoSpot)
	local mostrarCone = textoCone ~= "" and nivelAtual >= 3
	local camCF = ctx.camera.CFrame
	local camPos = camCF.Position
	-- cone vertical: o ângulo de visão depende só de |LookVector.Y|
	local fAngulo = Regras.fatorAnguloCone(camCF.LookVector.Y, ConfigPostes.coneDotMin, ConfigPostes.coneDotMax)
	for _, s in slotsLuz do
		local rec = s.rec
		if rec then
			local b = fator
			if rec.estado == "pisca" then
				b *= Regras.brilhoPisca(e.t, rec.pos.X, rec.pos.Z)
			end
			s.spot.Brightness = brilho * b
			s.spot.Enabled = b > 0.01
			local dx, dz = rec.pos.X - camPos.X, rec.pos.Z - camPos.Z
			local fProx = Regras.fatorProximidadeCone(
				math.sqrt(dx * dx + dz * dz),
				ConfigPostes.conePertoEixo,
				ConfigPostes.coneLongeEixo
			)
			local tr = 1 - (1 - ConfigPostes.coneTransparencia) * b * fProx * fAngulo
			s.beam.Enabled = mostrarCone and b > 0.01 and tr < 0.995
			if math.abs(tr - s.transp) > 0.02 then
				s.transp = tr
				s.beam.Transparency = NumberSequence.new(tr)
			end
		end
	end
	if textoHalo ~= "" then
		for _, s in slotsHalo do
			local rec = s.rec
			if rec then
				local b = fator
				if rec.estado == "pisca" then
					b *= Regras.brilhoPisca(e.t, rec.pos.X, rec.pos.Z)
				end
				s.img.ImageTransparency = 1 - (1 - ConfigPostes.haloTransparencia) * b
				s.gui.Enabled = b > 0.01
			end
		end
	end
end

function Postes.ligar(l: boolean)
	ligado = l
	if not l and visivel then
		apagarTudo()
	end
end

function Postes.nivel(n: number)
	nivelAtual = n
end

return Postes
