-- MonstroSonar: onda visível do sonar do Wrapper e a reação na tela de quem ela alcança. Dono: agente C.
-- Contrato: docs/monstros/logica.md §2.7. Eventos de Rede: MonstroSonar(origem, raio, velocidade, id) e SonarAtingido(id, detectado).
-- Só mostra: quem decide a detecção é o servidor. Leve: no máximo MAX_ONDAS vivas, cada uma com 2 peças.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))

local SonsLocal = require(script.Parent.SonsLocal)

local MonstroSonar = {}

local MAX_ONDAS = 4
local COR_ONDA = Color3.fromRGB(190, 210, 225) -- fria, pálida
local COR_DETECTADO = Color3.fromRGB(200, 30, 25)
local COR_PASSOU = Color3.fromRGB(70, 110, 200)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)
local TRANSP_ESFERA_INICIO = 0.85
local ESPESSURA_DISCO = 0.2 -- studs
local ALTURA_DISCO = 0.15 -- studs acima do piso
local PISO_ALCANCE = 60 -- studs do raycast para baixo
local PISO_PADRAO = 3 -- studs abaixo da origem se não achar piso
local TELA_DETECTADO = 0.6 -- s
local TELA_PASSOU = 0.3 -- s
local TEXTO_DETECTADO = 0.9 -- s
local FONTE = Enum.Font.Code
local TAMANHO_TEXTO = 36
local CANVAS = 256 -- px do SurfaceGui do anel
local ESPESSURA_ANEL = 5 -- px no canvas

type Onda = {
	id: number,
	origem: Vector3,
	raio: number,
	velocidade: number,
	inicio: number,
	esfera: Part,
	disco: Part,
}

local jogador = Players.LocalPlayer
local ondas: { Onda } = {}
local pasta: Folder? = nil
local conexao: RBXScriptConnection? = nil

local tela: ScreenGui? = nil
local bordaStroke: UIStroke? = nil
local texto: TextLabel? = nil
local tweenBorda: Tween? = nil
local tweenTexto: Tween? = nil

local function pastaOndas(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local nova = Instance.new("Folder")
	nova.Name = "OndasSonar"
	nova.Parent = workspace
	pasta = nova
	return nova
end

local function pecaBase(nome: string): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = COR_ONDA
	return p
end

local function alturaDoPiso(origem: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filtro: { Instance } = {}
	if jogador.Character then
		table.insert(filtro, jogador.Character)
	end
	for _, nome in { "Monstros", "OndasSonar", "ItensChao", "SonsSoltos" } do
		local pai = workspace:FindFirstChild(nome)
		if pai then
			table.insert(filtro, pai)
		end
	end
	params.FilterDescendantsInstances = filtro
	local r = workspace:Raycast(origem + Vector3.new(0, 1, 0), Vector3.new(0, -PISO_ALCANCE, 0), params)
	if r then
		return r.Position.Y + ALTURA_DISCO
	end
	return origem.Y - PISO_PADRAO
end

local function remover(indice: number)
	local o = ondas[indice]
	o.esfera:Destroy()
	o.disco:Destroy()
	table.remove(ondas, indice)
end

local function atualizar()
	local agora = os.clock()
	for i = #ondas, 1, -1 do
		local o = ondas[i]
		local t = agora - o.inicio
		local r = t * o.velocidade
		if r >= o.raio then
			remover(i)
		else
			local fracao = r / o.raio
			local d = math.max(r * 2, 0.1)
			o.esfera.Size = Vector3.one * d
			o.esfera.Transparency = TRANSP_ESFERA_INICIO + (1 - TRANSP_ESFERA_INICIO) * fracao
			o.disco.Size = Vector3.new(ESPESSURA_DISCO, d, d)
			o.disco.Transparency = 1 -- só o anel da SurfaceGui aparece
		end
	end
	if #ondas == 0 and conexao then
		conexao:Disconnect()
		conexao = nil
	end
end

local function criarAnel(disco: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Anel"
	gui.Face = Enum.NormalId.Right -- com o disco deitado (Orientation Z 90), +X do cilindro aponta para cima
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(CANVAS, CANVAS)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	local quadro = Instance.new("Frame")
	quadro.BackgroundTransparency = 1
	quadro.Size = UDim2.fromScale(1, 1)
	quadro.Parent = gui
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0.5, 0)
	canto.Parent = quadro
	local traco = Instance.new("UIStroke")
	traco.Thickness = ESPESSURA_ANEL
	traco.Color = COR_ONDA
	traco.Parent = quadro
	gui.Parent = disco
end

local function aoOnda(origem: Vector3, raio: number, velocidade: number, id: number)
	if
		typeof(origem) ~= "Vector3"
		or type(raio) ~= "number"
		or type(velocidade) ~= "number"
		or type(id) ~= "number"
	then
		return
	end
	if raio <= 0 or velocidade <= 0 or raio ~= raio or velocidade ~= velocidade then
		return
	end
	while #ondas >= MAX_ONDAS do
		remover(1) -- a mais antiga sai
	end

	local esfera = pecaBase("SonarEsfera")
	esfera.Shape = Enum.PartType.Ball
	esfera.Size = Vector3.one * 0.2
	esfera.Transparency = TRANSP_ESFERA_INICIO
	esfera.CFrame = CFrame.new(origem)
	esfera.Parent = pastaOndas()

	local disco = pecaBase("SonarAnel")
	disco.Shape = Enum.PartType.Cylinder
	disco.Size = Vector3.new(ESPESSURA_DISCO, 0.2, 0.2)
	disco.Transparency = 1
	disco.CFrame = CFrame.new(origem.X, alturaDoPiso(origem), origem.Z) * CFrame.Angles(0, 0, math.rad(90))
	criarAnel(disco)
	disco.Parent = pastaOndas()

	table.insert(ondas, {
		id = id,
		origem = origem,
		raio = raio,
		velocidade = velocidade,
		inicio = os.clock(),
		esfera = esfera,
		disco = disco,
	})
	SonsLocal.tocar("SonarOnda")
	if not conexao then
		conexao = RunService.RenderStepped:Connect(atualizar)
	end
end

local function criarTela()
	local g = Instance.new("ScreenGui")
	g.Name = "MonstroSonar"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 20
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local b = Instance.new("Frame")
	b.Name = "Borda"
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromScale(1, 1)
	b.Active = false
	b.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 40
	s.Color = COR_DETECTADO
	s.Transparency = 1
	s.Parent = b

	local t = Instance.new("TextLabel")
	t.Name = "Detectado"
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.3)
	t.Size = UDim2.fromOffset(320, 48)
	t.Font = FONTE
	t.Text = "DETECTADO"
	t.TextSize = TAMANHO_TEXTO
	t.TextColor3 = COR_DETECTADO
	t.TextTransparency = 1
	t.TextStrokeColor3 = COR_CONTORNO
	t.TextStrokeTransparency = 1
	t.Parent = g

	g.Parent = jogador:WaitForChild("PlayerGui")
	tela, bordaStroke, texto = g, s, t
end

local function pulsoBorda(cor: Color3, duracao: number, forca: number)
	if not bordaStroke then
		return
	end
	if tweenBorda then
		tweenBorda:Cancel()
	end
	bordaStroke.Color = cor
	bordaStroke.Transparency = 1 - forca
	tweenBorda =
		TweenService:Create(bordaStroke, TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		})
	tweenBorda:Play()
end

local function mostrarTexto()
	if not texto then
		return
	end
	if tweenTexto then
		tweenTexto:Cancel()
	end
	texto.TextTransparency = 0
	texto.TextStrokeTransparency = 0.2
	tweenTexto =
		TweenService:Create(texto, TweenInfo.new(TEXTO_DETECTADO, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	tweenTexto:Play()
end

local function aoAtingir(_id: number, detectado: boolean)
	if not tela then
		return
	end
	if detectado == true then
		pulsoBorda(COR_DETECTADO, TELA_DETECTADO, 0.15)
		mostrarTexto()
		SonsLocal.tocar("SonarDetectado")
	else
		pulsoBorda(COR_PASSOU, TELA_PASSOU, 0.55)
		SonsLocal.tocar("SonarPassou")
	end
end

function MonstroSonar.iniciar()
	criarTela()
	Rede.evento("MonstroSonar").OnClientEvent:Connect(aoOnda)
	Rede.evento("SonarAtingido").OnClientEvent:Connect(aoAtingir)
end

return MonstroSonar
