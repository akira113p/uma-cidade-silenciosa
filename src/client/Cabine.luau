-- Cabine: primeira pessoa dentro do carro, tudo local e procedural. Põe o olho no banco (Config/Veiculos.camera),
-- esconde o corpo e o volante reais, desenha um volante de blocos que gira pelo steer e dois braços de blocos (cor do
-- suéter) indo dos ombros às mãos no volante, e treme com a velocidade respeitando Pref_Tremor/Pref_Intensidade.
-- Medidor de gasolina no painel (agulha −60°..+60°, "E"/"F" e luz de reserva). Passageiro (Seat, docs/combustivel.md §7/§8.3):
-- olho deslocado para o banco dele, sem volante nem mãos de bloco (o volante real continua visível).
-- Não envia animação ao Roblox. Contrato: docs/veiculos.md e docs/combustivel.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgAparencia = require(Config:WaitForChild("Aparencia"))
local CfgCamera = require(Config:WaitForChild("Camera"))
local Direcao = require(script.Parent.Direcao)

local Cabine = {}

local jogador = Players.LocalPlayer

local RAIO_VOLANTE = 0.52 -- studs
local SEGMENTOS = 12
local GRAUS_VOLANTE_POR_ANGULO = 5.5 -- o volante gira mais que as rodas
local NORMAL_VOLANTE = Vector3.new(0, 0.45, 0.89).Unit -- aponta para o motorista (frente do carro é -Z)
local OLHO_PADRAO = Vector3.new(0, 2.95, 0) -- somado à posição do Banco1 sem o atributo OlhoLocal: topo do banco (0.25) + 2.70
local ANGULO_MEDIDOR = 60 -- graus: agulha de +60 (E, vazio) a -60 (F, cheio) vista de frente
local MOLDURA_MEDIDOR = Vector3.new(1.4, 0.8, 0.05)
local AGULHA_COMPRIMENTO = 0.5
local TREMOR_PADRAO = 0.03 -- studs na velocidade máxima
local ROLL_PADRAO = 0.5 -- graus na velocidade máxima
local OCIOSO = 0.25 -- fração do tremor com o motor ligado e parado

local cfgVeiculos: any = nil
local cfgMalhas: any = nil -- Config/VeiculosMalhas (dimensoes do tipo; opcional)
local cfgComb: any = nil -- Config/Combustivel (nil: sem medidor)
local RegraComb: any = nil -- Regras/Combustivel
local pasta: Folder? = nil
local segmentos: { Part } = {} -- aro e raios do volante
local bracos: { Part } = {} -- ombro-cotovelo, cotovelo-mão, para cada lado
local maos: { Part } = {}
local painel: { { parte: Part, rel: CFrame } } = {} -- painel e colunas em blocos, no espaço do chassi
local escondidas: { [BasePart]: boolean } = {}
local raioVolante = RAIO_VOLANTE
local ultimaVarreduraCorpo = 0
local volanteReal: BasePart? = nil
local yawAcumulado = 0
local yawAnterior = 0

local function vetor(v: any): Vector3?
	if typeof(v) == "Vector3" then
		return v
	end
	if type(v) == "table" then
		if v.olho ~= nil then
			return vetor(v.olho)
		end
		local x = v.x or v.X or v[1]
		local y = v.y or v.Y or v[2]
		local z = v.z or v.Z or v[3]
		if type(x) == "number" and type(y) == "number" and type(z) == "number" then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

local function cor(lista: { number }): Color3
	return Color3.fromRGB(lista[1], lista[2], lista[3])
end

local function bloco(nome: string, tamanho: Vector3, c: Color3): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = c
	p.Size = tamanho
	p.Parent = pasta
	return p
end

local function ligarSegmento(p: Part, a: Vector3, b: Vector3)
	local comprimento = (b - a).Magnitude
	if comprimento < 0.01 then
		p.Transparency = 1
		return
	end
	p.Transparency = 0
	p.Size = Vector3.new(p.Size.X, p.Size.Y, comprimento)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
end

-- Olho no espaço do Chassi: atributo OlhoLocal do servidor (topo do banco + 2.70 studs, por tipo; cabeça do personagem sentado).
local function olhoLocal(modelo: Model, chassi: BasePart): Vector3
	local dado = modelo:GetAttribute("OlhoLocal")
	if typeof(dado) == "Vector3" then
		return dado
	end
	local banco = modelo:FindFirstChild("Banco1")
	if banco and banco:IsA("BasePart") then
		return chassi.CFrame:PointToObjectSpace(banco.Position) + OLHO_PADRAO
	end
	return OLHO_PADRAO
end

-- Tamanho do carro: dimensoes do modelo 3d (VeiculosMalhas) ou o tamanho em blocos de Config/Veiculos.
local function tamanhoDoTipo(modelo: Model): Vector3
	local tipo = modelo:GetAttribute("Tipo")
	local dado = nil
	if type(tipo) == "string" then
		local m = if type(cfgMalhas) == "table" and type(cfgMalhas.tipos) == "table" then cfgMalhas.tipos[tipo] else nil
		dado = if type(m) == "table" then vetor(m.dimensoes) else nil
		if not dado and type(cfgVeiculos) == "table" and type(cfgVeiculos.tipos) == "table" then
			local t = cfgVeiculos.tipos[tipo]
			dado = if type(t) == "table" then vetor(t.tamanho) else nil
		end
	end
	return dado or Vector3.new(5.6, 3.4, 11)
end

-- Estado da cabine atual
local atual: { modelo: Model, banco: BasePart?, motorista: boolean, chassi: BasePart, olho: Vector3, centro: Vector3 }? =
	nil

-- Medidor de gasolina (só locais): agulha animada por quadro, luz de reserva. nil se não há o que mostrar.
local medidor: { agulha: Part, luz: Part, rel: CFrame, mostrado: number, reserva: boolean }? = nil
local ultimoQuadro = 0

local function restaurarCorpo()
	for parte in escondidas do
		if parte.Parent then
			parte.LocalTransparencyModifier = 0
		end
	end
	table.clear(escondidas)
	if volanteReal and volanteReal.Parent then
		volanteReal.LocalTransparencyModifier = 0
	end
	volanteReal = nil
end

local function esconderCorpo()
	local personagem = jogador.Character
	if personagem then
		for _, d in personagem:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				escondidas[d] = true
			end
		end
	end
	if volanteReal and volanteReal.Parent then
		volanteReal.LocalTransparencyModifier = 1
	end
end

local function desmontar()
	restaurarCorpo()
	if pasta then
		pasta:Destroy()
		pasta = nil
	end
	table.clear(segmentos)
	table.clear(bracos)
	table.clear(maos)
	table.clear(painel)
	medidor = nil
	atual = nil
end

-- Deslocamento x/z do olho do banco do passageiro em relação ao Banco1 (espaço do chassi). Mede os Seats do modelo
-- (vale para carro em blocos e com malha); sem eles usa os bancos de Config/VeiculosMalhas pelo índice do nome "BancoN".
local function deslocPassageiro(modelo: Model, chassi: BasePart, banco: BasePart?): Vector3
	if not banco then
		return Vector3.zero
	end
	local banco1 = modelo:FindFirstChild("Banco1")
	if banco1 and banco1:IsA("BasePart") then
		local a = chassi.CFrame:PointToObjectSpace(banco.Position)
		local b = chassi.CFrame:PointToObjectSpace(banco1.Position)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z)
	end
	local indice = tonumber(string.match(banco.Name, "^Banco(%d+)$"))
	local tipo = modelo:GetAttribute("Tipo")
	local m = if type(cfgMalhas) == "table"
			and type(cfgMalhas.tipos) == "table"
			and type(tipo) == "string"
		then cfgMalhas.tipos[tipo]
		else nil
	local lista = if type(m) == "table" then m.bancos else nil
	if indice and type(lista) == "table" and type(lista[indice]) == "table" and type(lista[1]) == "table" then
		return Vector3.new(lista[indice].x - lista[1].x, 0, lista[indice].z - lista[1].z)
	end
	return Vector3.zero
end

-- Gasolina do carro: (litros, tanque); tanque 0 = atributos ainda não chegaram.
local function lerGasolina(modelo: Model): (number, number)
	local tanque = modelo:GetAttribute("Tanque")
	local litros = modelo:GetAttribute("Combustivel")
	if type(tanque) ~= "number" or tanque <= 0 then
		return 0, 0
	end
	if type(litros) ~= "number" or modelo:GetAttribute("SemCombustivel") == true then
		litros = 0
	end
	return litros, tanque
end

-- Moldura preta com "E" e "F", agulha e luz de reserva, sobre o painel ao lado do volante, virada para o olho.
local function montarMedidor(centro: Vector3, olho: Vector3, addBloco: (string, Vector3, CFrame) -> Part)
	local dx = if centro.x <= 0 then 1.15 else -1.15 -- do lado do centro do carro
	local pos = centro + Vector3.new(dx, -0.3 + 0.45, -1.0 + 0.1)
	local molduraRel = CFrame.lookAt(pos, olho)
	local moldura = addBloco("Medidor", MOLDURA_MEDIDOR, molduraRel)
	moldura.Color = Color3.fromRGB(10, 10, 12)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Parent = moldura
	for _, dado in { { "E", 0.04 }, { "F", 0.86 } } do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Code
		t.TextSize = 22
		t.TextColor3 = Color3.fromRGB(225, 225, 220)
		t.Text = dado[1]
		t.AnchorPoint = Vector2.new(0, 1)
		t.Position = UDim2.fromScale(dado[2], 0.98)
		t.Size = UDim2.fromScale(0.1, 0.35)
		t.Parent = gui
	end

	local agulha = bloco("Agulha", Vector3.new(0.06, AGULHA_COMPRIMENTO, 0.03), Color3.fromRGB(190, 40, 35))
	local luz = addBloco("LuzReserva", Vector3.new(0.12, 0.12, 0.04), molduraRel * CFrame.new(-0.58, 0.27, -0.04))
	luz.Color = Color3.fromRGB(70, 15, 12)
	medidor = { agulha = agulha, luz = luz, rel = molduraRel, mostrado = 0, reserva = false }
end

local function montar(modelo: Model, banco: BasePart?, motorista: boolean)
	desmontar()
	local chassi = modelo.PrimaryPart or modelo:FindFirstChild("Chassi")
	local camera = workspace.CurrentCamera
	if not chassi or not chassi:IsA("BasePart") or not camera then
		return
	end
	local olhoMotorista = olhoLocal(modelo, chassi)
	local olho = if motorista then olhoMotorista else olhoMotorista + deslocPassageiro(modelo, chassi, banco)
	local volante = modelo:FindFirstChild("Volante_Malha", true) or modelo:FindFirstChild("Volante", true)
	local centro = olhoMotorista + Vector3.new(0, -0.8, -1.8) -- volante e painel são sempre os do motorista
	raioVolante = RAIO_VOLANTE
	if volante and volante:IsA("BasePart") then
		volanteReal = if motorista then volante else nil -- o passageiro vê o volante real
		centro = chassi.CFrame:PointToObjectSpace(volante.Position)
		-- o volante do modelo cresce com o carro: o de blocos acompanha
		raioVolante = math.clamp(math.max(volante.Size.X, volante.Size.Y) / 2 * 0.85, RAIO_VOLANTE, 0.9)
	end

	pasta = Instance.new("Folder")
	pasta.Name = "CabineLocal"
	pasta.Parent = camera

	local cores = CfgAparencia.cores
	local corSuter = cor(cores.suter)
	local corPele = cor(cores.pele)
	local corVolante = Color3.fromRGB(28, 28, 30)

	if motorista then -- passageiro: sem volante nem mãos de bloco
		for i = 1, SEGMENTOS do
			table.insert(segmentos, bloco("Aro" .. i, Vector3.new(0.09, 0.09, 0.2), corVolante))
		end
		for i = 1, 3 do
			table.insert(segmentos, bloco("Raio" .. i, Vector3.new(0.07, 0.07, 0.2), corVolante))
		end
		for i = 1, 4 do
			table.insert(bracos, bloco("Braco" .. i, Vector3.new(0.3, 0.3, 0.5), corSuter))
		end
		for i = 1, 2 do
			table.insert(maos, bloco("Mao" .. i, Vector3.new(0.26, 0.26, 0.3), corPele))
		end
	end

	-- painel e colunas A em blocos escuros (só locais). Abaixo da linha do para-brisa: nada tapa a vista para frente.
	local tam = tamanhoDoTipo(modelo)
	local corPainel = Color3.fromRGB(20, 20, 22)
	local function addBloco(nome: string, tamanho: Vector3, rel: CFrame): Part
		local parte = bloco(nome, tamanho, corPainel)
		table.insert(painel, { parte = parte, rel = rel })
		return parte
	end
	addBloco(
		"Painel",
		Vector3.new(tam.X * 0.88, 0.5, 1.1),
		CFrame.new(centro + Vector3.new(0, -0.3, -1.0)) * CFrame.Angles(math.rad(-12), 0, 0)
	)
	for sinal = -1, 1, 2 do
		addBloco(
			if sinal < 0 then "ColunaE" else "ColunaD",
			Vector3.new(0.28, 2.3, 0.4),
			CFrame.new(Vector3.new(sinal * (tam.X / 2 - 0.5), olhoMotorista.Y + 0.4, olhoMotorista.Z - 2.0))
				* CFrame.Angles(math.rad(-28), math.rad(sinal * -8), 0)
		)
	end
	if cfgComb and RegraComb then
		montarMedidor(centro, olho, addBloco)
	end

	atual = { modelo = modelo, banco = banco, motorista = motorista, chassi = chassi, olho = olho, centro = centro }
	yawAcumulado = 0
	local _, yaw0 = chassi.CFrame:ToOrientation()
	yawAnterior = yaw0
	esconderCorpo()
end

local function preferencias(): (boolean, number)
	local ligado = jogador:GetAttribute("Pref_Tremor") ~= false
	local intensidade = jogador:GetAttribute("Pref_Intensidade")
	if type(intensidade) ~= "number" then
		intensidade = CfgCamera.preferenciasPadrao.Pref_Intensidade
	end
	return ligado, intensidade
end

local function cfgCabine(chave: string, padrao: number): number
	local c = if type(cfgVeiculos) == "table" then cfgVeiculos.camera else nil
	if type(c) == "table" and type(c[chave]) == "number" then
		return c[chave]
	end
	return padrao
end

-- Desenha volante e braços, tudo no espaço do chassi.
local function desenhar(
	chassi: BasePart,
	o: { modelo: Model, motorista: boolean, olho: Vector3, centro: Vector3 },
	steer: number,
	dt: number
)
	local base = chassi.CFrame
	for _, item in painel do
		item.parte.CFrame = base * item.rel
	end
	local med = medidor
	if med and cfgComb and RegraComb then
		-- agulha: vista de frente o E fica à esquerda (+X local da moldura), o F à direita; gira em torno do Z local
		local litros, tanque = lerGasolina(o.modelo)
		local frac = if tanque > 0 then RegraComb.fracao(litros, tanque) else 0
		med.mostrado += (frac - med.mostrado) * math.min(1, dt * 6)
		local desvio = math.rad(ANGULO_MEDIDOR - 2 * ANGULO_MEDIDOR * med.mostrado)
		local pivo = CFrame.new(0, -AGULHA_COMPRIMENTO / 2, -0.045)
		med.agulha.CFrame = base
			* med.rel
			* pivo
			* CFrame.Angles(0, 0, -desvio)
			* CFrame.new(0, AGULHA_COMPRIMENTO / 2, 0)
		local reserva = tanque > 0 and RegraComb.reserva(litros, tanque, cfgComb)
		if reserva ~= med.reserva then
			med.reserva = reserva
			med.luz.Material = if reserva then Enum.Material.Neon else Enum.Material.SmoothPlastic
			med.luz.Color = if reserva then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(70, 15, 12)
		end
	end
	if not o.motorista then
		return
	end
	local ex = Vector3.xAxis
	local ey = NORMAL_VOLANTE:Cross(ex)
	local giro = -math.rad(steer * GRAUS_VOLANTE_POR_ANGULO * 32) -- 32 graus de roda máxima
	local centro = o.centro

	local function ponto(theta: number, raio: number): Vector3
		return centro + (ex * math.cos(theta) + ey * math.sin(theta)) * raio
	end
	local function mundo(p: Vector3): Vector3
		return base:PointToWorldSpace(p)
	end

	for i = 1, SEGMENTOS do
		local t0 = giro + (i - 1) / SEGMENTOS * math.pi * 2
		local t1 = giro + i / SEGMENTOS * math.pi * 2
		ligarSegmento(segmentos[i], mundo(ponto(t0, raioVolante)), mundo(ponto(t1, raioVolante)))
	end
	for i = 1, 3 do
		local t = giro + (i - 1) * math.pi * 2 / 3 + math.pi / 2
		ligarSegmento(segmentos[SEGMENTOS + i], mundo(centro), mundo(ponto(t, raioVolante)))
	end

	-- mãos às 9 e 3 horas, giram junto
	local lado = { -1, 1 }
	for i, sinal in lado do
		local theta = giro + (if sinal < 0 then math.pi else 0)
		local mao = ponto(theta, raioVolante)
		local ombro = o.olho + Vector3.new(0.8 * sinal, -0.85, 0.15)
		local cotovelo = (ombro + mao) / 2 + Vector3.new(0.18 * sinal, -0.3, 0.1)
		local b1, b2 = bracos[(i - 1) * 2 + 1], bracos[(i - 1) * 2 + 2]
		ligarSegmento(b1, mundo(ombro), mundo(cotovelo))
		ligarSegmento(b2, mundo(cotovelo), mundo(mao))
		local m = maos[i]
		m.CFrame = CFrame.lookAt(mundo(mao), mundo(mao + (mao - cotovelo)))
	end
end

local function passo()
	local est = Direcao.estado
	local camera = workspace.CurrentCamera
	if not est.ativo or not est.modelo or not camera then
		if atual then
			desmontar()
		end
		return
	end
	if jogador.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		-- terceira pessoa (tecla V): sem cabine local
		if atual then
			desmontar()
		end
		return
	end
	if not atual or atual.modelo ~= est.modelo or atual.banco ~= est.banco then
		montar(est.modelo, est.banco, est.motorista)
		if not atual then
			return
		end
	end
	local a = atual :: any
	local chassi: BasePart = a.chassi
	if not chassi.Parent then
		desmontar()
		return
	end

	local agora = os.clock()
	if agora - ultimaVarreduraCorpo > 1 then
		ultimaVarreduraCorpo = agora
		esconderCorpo()
	else
		for parte in escondidas do
			if parte.Parent then
				parte.LocalTransparencyModifier = 1
			end
		end
		if volanteReal and volanteReal.Parent then
			volanteReal.LocalTransparencyModifier = 1
		end
	end

	-- tremor por velocidade (e do motor parado ligado)
	local pref, intensidade = preferencias()
	local fator = if pref then intensidade / 100 else 0
	local ligado = a.modelo:GetAttribute("MotorLigado") == true
	local tremor = (est.fracao + (if ligado then OCIOSO else 0)) * cfgCabine("tremor", TREMOR_PADRAO) * fator
	local roll = est.fracao * cfgCabine("roll", ROLL_PADRAO) * fator
	local tx = math.noise(agora * 31, 2.1, 0) * 2 * tremor
	local ty = math.noise(agora * 31, 8.7, 0) * 2 * tremor
	local tr = math.noise(agora * 19, 5.3, 0) * roll

	local rotacao = camera.CFrame.Rotation
	local seguir = cfgCabine("seguirGiro", 0) > 0
	if seguir then
		local _, yaw = chassi.CFrame:ToOrientation()
		local delta = math.atan2(math.sin(yaw - yawAnterior), math.cos(yaw - yawAnterior))
		yawAnterior = yaw
		yawAcumulado += delta
		rotacao = CFrame.Angles(0, yawAcumulado, 0) * rotacao
	end
	local posicao = chassi.CFrame:PointToWorldSpace(a.olho)
	local cf = CFrame.new(posicao) * rotacao
	cf = cf * CFrame.new(tx, ty, 0) * CFrame.Angles(0, 0, math.rad(tr))
	camera.CFrame = cf

	local agoraQuadro = os.clock()
	local dtQuadro = math.clamp(agoraQuadro - ultimoQuadro, 0, 0.1)
	ultimoQuadro = agoraQuadro
	desenhar(chassi, a, est.steer, dtQuadro)
end

function Cabine.iniciar()
	local modulo = Config:WaitForChild("Veiculos", 10)
	if modulo then
		local ok, valor = pcall(require, modulo)
		if ok then
			cfgVeiculos = valor
		end
	end
	local mComb = Config:WaitForChild("Combustivel", 10)
	local rComb = Shared:WaitForChild("Regras"):WaitForChild("Combustivel", 10)
	if mComb and rComb then
		local ok1, v1 = pcall(require, mComb)
		local ok2, v2 = pcall(require, rComb)
		if ok1 and ok2 then
			cfgComb = v1
			RegraComb = v2
		else
			warn("[Cabine] combustível indisponível: " .. tostring(if ok1 then v2 else v1))
		end
	end
	local malhas = Config:WaitForChild("VeiculosMalhas", 10)
	if malhas then
		local ok, valor = pcall(require, malhas)
		if ok then
			cfgMalhas = valor
		end
	end
	-- depois da Camera (Camera + 1), para sobrescrever a posição do olho
	RunService:BindToRenderStep("CabineVeiculo", Enum.RenderPriority.Camera.Value + 2, function()
		local ok, erro = pcall(passo)
		if not ok then
			warn("[Cabine] " .. tostring(erro))
			desmontar()
		end
	end)
	Direcao.aoMudar(function(ativo)
		if not ativo then
			desmontar()
		end
	end)
end

return Cabine
