-- VeiculoModelo (servidor): monta e atualiza o Model físico de um veículo. Dono: V2. Contrato: docs/veiculos.md.
-- Convenções (o cliente, V3, depende delas):
--  * Eixo local: frente = -Z, direita = +X, cima = +Y. `cf` de criar() é a origem NO CHÃO, no centro do carro.
--  * Motor_XX (HingeConstraint, Motor): eixo +X do carro. AngularVelocity NEGATIVA = rodar para a frente (as quatro rodas).
--  * Dir_FE/Dir_FD (HingeConstraint, Servo): eixo +Y do carro, TargetAngle em graus; positivo = vira à ESQUERDA.
--    Limite em modelo:GetAttribute("AnguloDirecao") graus.
--  * Tudo nasce ancorado (carro dormindo); Veiculos acorda/dorme com ancorar().
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Veiculos"))
local CfgComb = require(Shared.Config:WaitForChild("Combustivel"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Veiculo"))
local Malhas: any = require(Shared:WaitForChild("Config"):WaitForChild("VeiculosMalhas"))

type Estado = Regra.Estado

local VeiculoModelo = {}

local RAIO_RODA = 1.0 -- raio do molde "Roda" (FBX) e padrão sem Config/VeiculosMalhas
local LARGURA_RODA = 0.7 -- na escala do molde (multiplica pelo raio)
local FOLGA_RODA = 0.4 -- centro da roda acima do fundo do chassi (em repouso); padrão sem Config/VeiculosMalhas
-- Com malha, raio e folga vêm de VeiculosMalhas.tipos[t].raioRoda/folgaRoda (raio proporcional ao carro; docs/veiculos-modelos.md).
-- A massa da roda fica igual (densidade / raio^3) e o torque do motor sobe com o raio (força no chão = torque / raio): a suspensão não muda.
local OLHO_ACIMA_BANCO = 2.70 -- studs acima do topo do banco (medido no jogo: cabeça do personagem sentado)
local ANGULO_DIRECAO = 35 -- graus, limite do servo de direção
-- INTEGRACAO: virar Config/Veiculos (pendencias, "Veiculos").
local TORQUE_DIRECAO = 4e5
local VELOCIDADE_DIRECAO = 6 -- rad/s do servo
local TORQUE_FREIO = 5e4
local DENSIDADE_RODA = 25
local DENSIDADE_SUSPENSAO = 80 -- suporte e cubo: pesados de propósito; massa pequena sob mola rígida faz a física divergir (NaN)
local FORCA_MOLA = 2e6
local ATRITO_RODA = 2

local GRUPO_CORPO = "VeiculoCorpo"
local GRUPO_RODA = "VeiculoRoda"

local RODAS = { "FE", "FD", "TE", "TD" }
local LADO_X = { FE = -1, FD = 1, TE = -1, TD = 1 }
local LADO_Z = { FE = -1, FD = -1, TE = 1, TD = 1 }
local VIDROS = { "ParaBrisa", "Traseiro", "JanelaE", "JanelaD" }
-- Peças da carroceria que quebram/somem e escurecem com o dano.
local CARROCERIA = { "Carroceria", "Frente", "Tras", "Capo", "PortaMalas", "PortaE", "PortaD", "ParaChoque", "Teto" }
local FALTANDO = { "Capo", "PortaMalas", "PortaE", "PortaD", "ParaChoque" }

local COR_TAMPA = Color3.fromRGB(170, 170, 175)
local COR_VIDRO = Color3.fromRGB(150, 190, 205)
local COR_VIDRO_QUEBRADO = Color3.fromRGB(210, 215, 220)
local COR_FAROL_APAGADO = Color3.fromRGB(150, 156, 156)
local COR_FAROL_ACESO = Color3.fromRGB(255, 240, 205)
local FAROIS = { "Farol_E", "Farol_D" }
local COR_QUEIMADO = Color3.fromRGB(30, 28, 26)
local COR_BATIDO = Color3.fromRGB(32, 28, 26)

local aleatorio = Random.new()
local gruposOk = false

local function registrarGrupos()
	if gruposOk then
		return
	end
	gruposOk = true
	for _, nome in { GRUPO_CORPO, GRUPO_RODA } do
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, nome)
	end
	pcall(PhysicsService.CollisionGroupSetCollidable, PhysicsService, GRUPO_CORPO, GRUPO_RODA, false)
end

local function dimensoes(t: any): (number, number, number)
	if typeof(t) == "Vector3" then
		return t.X, t.Y, t.Z
	end
	return t.x or t[1], t.y or t[2], t.z or t[3]
end

local function paraCor(v: any): Color3
	if typeof(v) == "Color3" then
		return v
	end
	if type(v) == "table" then
		local r, g, b = v.r or v.R or v[1], v.g or v.G or v[2], v.b or v.B or v[3]
		if r and g and b then
			if r <= 1 and g <= 1 and b <= 1 then
				return Color3.new(r, g, b)
			end
			return Color3.fromRGB(r, g, b)
		end
	end
	return Color3.fromRGB(110, 110, 115)
end

-- Cor do carro. Com texturas assadas (VeiculosMalhas.tipos[t].inteiro.texturas = cor1..cor4, `false` = não enviada), sorteia uma
-- e devolve a textura; a cor dos blocos é a de mesmo índice em Config/Veiculos.tipos[t].cor. Queimado/sem texturas: sorteio comum.
local function sortearCor(tipo: any, malhasTipo: any, queimado: boolean): (Color3, string?)
	local lista = tipo.cor
	local texs = if not queimado
			and malhasTipo
			and type(malhasTipo.inteiro) == "table"
		then malhasTipo.inteiro.texturas
		else nil
	if type(texs) == "table" then
		local validos = {}
		for i, t in texs do
			if type(t) == "string" then
				table.insert(validos, i)
			end
		end
		if #validos > 0 then
			local i = validos[aleatorio:NextInteger(1, #validos)]
			local cor = if type(lista) == "table" and #lista > 0
				then paraCor(lista[(i - 1) % #lista + 1])
				else paraCor(lista)
			return cor, texs[i]
		end
	end
	if type(lista) == "table" and #lista > 0 then
		return paraCor(lista[aleatorio:NextInteger(1, #lista)]), nil
	end
	return paraCor(lista), nil
end

type Opcoes = {
	forma: Enum.PartType?,
	transp: number?,
	colide: boolean?,
	consulta: boolean?,
	grupo: string?,
	peca: string?, -- atributo PecaVeiculo
	densidade: PhysicalProperties?,
	rot: CFrame?, -- giro extra aplicado em corpo()
}

local function nova(
	modelo: Model,
	nome: string,
	tamanho: Vector3,
	cframe: CFrame,
	cor: Color3,
	material: Enum.Material,
	o: Opcoes?
): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamanho
	p.CFrame = cframe
	p.Color = cor
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	local opcoes = o or {}
	if opcoes.forma then
		p.Shape = opcoes.forma
	end
	local transp = opcoes.transp or 0
	local colide = opcoes.colide ~= false
	local consulta = opcoes.consulta ~= false
	p.Transparency = transp
	p.CanCollide = colide
	p.CanQuery = consulta
	p.CollisionGroup = opcoes.grupo or GRUPO_CORPO
	if opcoes.densidade then
		p.CustomPhysicalProperties = opcoes.densidade
	end
	-- valores "normais" da peça, para aplicar() desfazer um estado de dano (idempotente)
	p:SetAttribute("TranspBase", transp)
	p:SetAttribute("ColideBase", colide)
	p:SetAttribute("ConsultaBase", consulta)
	if opcoes.peca then
		p:SetAttribute("PecaVeiculo", opcoes.peca)
	end
	p.Parent = modelo
	return p
end

local function soldar(chassi: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = chassi
	w.Part1 = p
	w.Parent = p
end

local function anexo(pai: BasePart, nome: string, cframe: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = nome
	a.CFrame = cframe
	a.Parent = pai
	return a
end

local function posicoesBancos(n: number, sx: number, sy: number, sz: number): { Vector3 }
	local lista = {}
	local y = -0.25 * sy + 0.25
	for i = 1, n do
		local linha = (i - 1) // 2
		local coluna = (i - 1) % 2
		local x = (if coluna == 0 then -0.22 else 0.22) * sx
		local z = math.min(0.05 * sz + linha * 0.18 * sz, 0.26 * sz)
		table.insert(lista, Vector3.new(x, y, z))
	end
	return lista
end

-- Bancos da malha (manifesto): x e z no espaço do carro, topo a `bancoTopo` studs do piso. nil se o tipo não os traz.
local function posicoesBancosMalha(m: any, sy: number, n: number): { Vector3 }?
	if not (m and type(m.bancos) == "table" and #m.bancos >= n) then
		return nil
	end
	local topo = if type(m.bancoTopo) == "number" then m.bancoTopo else 0.8
	local y = topo - 0.25 - sy / 2 -- o Seat tem 0.5 de espessura
	local lista = {}
	for i = 1, n do
		local b = m.bancos[i]
		table.insert(lista, Vector3.new(b.x, y, b.z))
	end
	return lista
end

-- Malhas (docs/veiculos-modelos.md, M2). Os blocos continuam sendo colisão e alvo; a malha é só visual.
-- Moldes: InsertService:LoadAsset de cada `modelo` de Config/VeiculosMalhas, uma vez, em ServerStorage.Modelos.Veiculos
-- (chaves: tipo.modelo, tipo.modelo .. "_Queimado", "Roda"). Sem assetId ou falhou: o carro segue em blocos.
local PECAS_MALHA = {
	"Carroceria",
	"Capo",
	"PortaMalas",
	"PortaE",
	"PortaD",
	"ParaChoque",
	"Vidro_ParaBrisa",
	"Vidro_Traseiro",
	"Vidro_JanelaE",
	"Vidro_JanelaD",
	"Volante",
}
-- Blocos que ficam invisíveis quando há malha de carroceria (mesmo os sem malha de mesmo nome).
local BLOCOS_ESCONDIDOS = {
	"Carroceria",
	"Frente",
	"Tras",
	"Capo",
	"PortaMalas",
	"PortaE",
	"PortaD",
	"ParaChoque",
	"Teto",
	"Vidro_ParaBrisa",
	"Vidro_Traseiro",
	"Vidro_JanelaE",
	"Vidro_JanelaD",
	"Volante",
}
local TOLERANCIA_ESCALA = 0.15
-- O FBX enviado pela Open Cloud volta com 0,28 do tamanho em studs (medido 2026-11-04: sedan 5,55 em vez de 19,83;
-- mesma razão em todos os modelos e na roda). 1 / 0,28 devolve o tamanho do Blender.
local FATOR_IMPORTACAO = 1 / 0.28
-- Idem: a importação gira a malha 180° em Y (X e Z das peças vêm negados; a frente do FBX aponta para +Z).
local VIRAR_IMPORTACAO = CFrame.Angles(0, math.pi, 0)
local estadoCarga = "nao" -- "nao" | "carregando" | "pronto"

local function pastaMoldes(): Folder
	local modelos = ServerStorage:FindFirstChild("Modelos")
	if not modelos then
		modelos = Instance.new("Folder")
		modelos.Name = "Modelos"
		modelos.Parent = ServerStorage
	end
	local veiculos = modelos:FindFirstChild("Veiculos")
	if not veiculos then
		veiculos = Instance.new("Folder")
		veiculos.Name = "Veiculos"
		veiculos.Parent = modelos
	end
	return veiculos :: Folder
end

local function numeroDe(v: any): number?
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v:match("%d+"))
	end
	return nil
end

local function maiorLado(t: any): number
	local x, y, z = dimensoes(t)
	return math.max(x, y, z)
end

-- Baixa um molde. `esperado` = maior lado em studs (conferência de escala). Falhou: warn e nada é guardado.
local function baixarMolde(pasta: Folder, chave: string, entrada: any, esperado: number?)
	local id = if type(entrada) == "table" then numeroDe(entrada.modelo) else nil
	if not id or pasta:FindFirstChild(chave) then
		return
	end
	local ok, resultado = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if not ok or typeof(resultado) ~= "Instance" then
		warn(("[VeiculoModelo] LoadAsset(%d) falhou para %s: %s"):format(id, chave, tostring(resultado)))
		return
	end
	local molde = Instance.new("Model")
	molde.Name = chave
	for _, d in resultado:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Size *= FATOR_IMPORTACAO
			d.Parent = molde -- achata: só os nomes importam; os CFrames não mudam
		end
	end
	resultado:Destroy()
	if #molde:GetChildren() == 0 then
		warn("[VeiculoModelo] molde sem MeshPart: " .. chave)
		molde:Destroy()
		return
	end
	if esperado then
		local _, tam = molde:GetBoundingBox()
		local real = math.max(tam.X, tam.Y, tam.Z)
		if math.abs(real - esperado) > esperado * TOLERANCIA_ESCALA then
			warn(
				("[VeiculoModelo] escala do molde %s: %.2f studs, esperado %.2f. Usando blocos."):format(
					chave,
					real,
					esperado
				)
			)
			molde:Destroy()
			return
		end
	end
	molde.Parent = pasta
end

-- Carrega todos os moldes (uma vez; chamadas concorrentes esperam). Chamado por criar(); pode ser chamado antes, no início.
function VeiculoModelo.carregar()
	if estadoCarga == "pronto" then
		return
	end
	if estadoCarga == "carregando" then
		while estadoCarga ~= "pronto" do
			task.wait(0.1)
		end
		return
	end
	estadoCarga = "carregando"
	local ok, erro = pcall(function()
		local pasta = pastaMoldes()
		for nome, tipo in Cfg.tipos do
			local m = Malhas.tipos and Malhas.tipos[nome]
			if m then
				local esperado = if m.dimensoes then maiorLado(m.dimensoes) else nil
				baixarMolde(pasta, tipo.modelo, m.inteiro, esperado)
				baixarMolde(pasta, tipo.modelo .. "_Queimado", m.queimado, esperado)
			end
		end
		baixarMolde(pasta, "Roda", Malhas.roda, 2 * RAIO_RODA)
	end)
	if not ok then
		warn("[VeiculoModelo] carregar: " .. tostring(erro))
	end
	estadoCarga = "pronto"
end

local function molde(chave: string): Model?
	local pasta = ServerStorage:FindFirstChild("Modelos")
	local veiculos = pasta and pasta:FindFirstChild("Veiculos")
	local m = veiculos and veiculos:FindFirstChild(chave)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function vetorDe(v: any): Vector3?
	if typeof(v) == "Vector3" then
		return v
	end
	if type(v) == "table" then
		local x, y, z = dimensoes(v)
		if type(x) == "number" and type(y) == "number" and type(z) == "number" then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

local function clonarMalha(origem: MeshPart, nome: string, cf: CFrame, textura: string?, escala: number?): MeshPart
	local m = origem:Clone()
	if escala and escala ~= 1 then
		m.Size = origem.Size * escala
	end
	m.Name = nome .. "_Malha"
	m.Anchored = true
	m.Massless = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Transparency = 0
	m.CollisionGroup = GRUPO_CORPO
	m.CFrame = cf
	if textura then
		m.TextureID = textura
	end
	m:SetAttribute("TranspBase", 0)
	return m
end

-- Troca o visual dos blocos pela malha. `origemCarro` = centro da base do carro (mundo). Devolve true se usou malha.
local function aplicarMalhas(
	modelo: Model,
	estado: Estado,
	tipo: any,
	chassi: Part,
	origemCarro: CFrame,
	texturaCor: string?
): boolean
	local dados = Malhas.tipos and Malhas.tipos[estado.tipo]
	local entrada = dados and (if estado.queimado then dados.queimado else dados.inteiro)
	local mol = molde(if estado.queimado then tipo.modelo .. "_Queimado" else tipo.modelo)
	if not (entrada and mol) then
		return false
	end
	local textura = texturaCor or (if type(entrada.textura) == "string" then entrada.textura else nil)
	-- sem `pecas` no Config: posição pela caixa do molde (assume origem no centro da base, como o contrato)
	local bbCF, bbTam = mol:GetBoundingBox()
	local baseMolde = bbCF * CFrame.new(0, -bbTam.Y / 2, 0)

	local function posicao(p: MeshPart): CFrame
		local pec = entrada.pecas and entrada.pecas[p.Name]
		local centro = if pec then vetorDe(pec.centro) else nil
		if centro then
			return origemCarro * CFrame.new(centro) * VIRAR_IMPORTACAO * p.CFrame.Rotation
		end
		return origemCarro * VIRAR_IMPORTACAO * baseMolde:ToObjectSpace(p.CFrame)
	end

	local nomes = if estado.queimado then { "Carroceria" } else PECAS_MALHA
	local criou = false
	for _, nome in nomes do
		local origem = mol:FindFirstChild(nome)
		if not (origem and origem:IsA("MeshPart")) and estado.queimado then
			origem = mol:FindFirstChildWhichIsA("MeshPart") -- queimado: um objeto só, qualquer nome
		end
		if origem and origem:IsA("MeshPart") then
			local m = clonarMalha(origem, nome, posicao(origem), textura)
			m.Parent = modelo
			soldar(chassi, m)
			criou = true
		end
	end
	if not criou then
		return false
	end
	for _, nome in BLOCOS_ESCONDIDOS do
		local bloco = modelo:FindFirstChild(nome)
		if bloco and bloco:IsA("BasePart") then
			bloco:SetAttribute("TranspBase", 1)
			bloco.Transparency = 1
		end
	end
	return true
end

-- `posRodas` (Config/VeiculosMalhas.tipos.<tipo>.rodas) dá x e z de cada roda; `malhaRoda` é o MeshPart do molde "Roda".
local function montarRoda(
	modelo: Model,
	chassi: Part,
	k: string,
	sx: number,
	sy: number,
	sz: number,
	posRodas: any,
	malhaRoda: MeshPart?,
	texturaRoda: string?,
	raio: number,
	folga: number
)
	local susp = Cfg.suspensao
	local L = susp.comprimento
	local ax, az = LADO_X[k] * (sx / 2 - 0.35), LADO_Z[k] * sz * 0.32
	local pr = if type(posRodas) == "table" then vetorDe(posRodas[k]) else nil
	if pr then
		ax, az = LADO_X[k] * math.abs(pr.X), LADO_Z[k] * math.abs(pr.Z)
	end
	local ya = -sy / 2 + folga + L
	local frente = LADO_Z[k] < 0
	local fisica = PhysicalProperties.new(math.max(0.01, DENSIDADE_RODA / raio ^ 3), ATRITO_RODA, 0, 100, 1)
	local leve = PhysicalProperties.new(DENSIDADE_SUSPENSAO, 0.3, 0, 1, 1)
	local posRoda = chassi.CFrame * CFrame.new(ax, ya - L, az)
	local semDirecao = { transp = 1, colide = false, consulta = false, grupo = GRUPO_RODA, densidade = leve }

	local suporte = nova(
		modelo,
		"Suporte_" .. k,
		Vector3.new(0.6, 0.6, 0.6),
		posRoda,
		Color3.new(0.1, 0.1, 0.1),
		Enum.Material.Metal,
		semDirecao
	)
	local cubo = suporte
	if frente then
		cubo = nova(
			modelo,
			"Cubo_" .. k,
			Vector3.new(0.5, 0.5, 0.5),
			posRoda,
			Color3.new(0.1, 0.1, 0.1),
			Enum.Material.Metal,
			semDirecao
		)
	end
	local roda = nova(
		modelo,
		"Roda_" .. k,
		Vector3.new(LARGURA_RODA * raio, raio * 2, raio * 2),
		posRoda,
		Color3.fromRGB(25, 25, 27),
		Enum.Material.Plastic,
		{
			forma = Enum.PartType.Cylinder,
			grupo = GRUPO_RODA,
			densidade = fisica,
			peca = "Pneu_" .. k,
			transp = if malhaRoda then 1 else 0,
		}
	)
	if malhaRoda then
		-- malha soldada à roda (gira com ela); o cilindro fica invisível, com colisão
		local m = clonarMalha(malhaRoda, "Roda_" .. k, roda.CFrame, texturaRoda, raio / RAIO_RODA)
		m.CollisionGroup = GRUPO_RODA
		m.Parent = modelo
		soldar(roda, m)
	end

	-- suspensão: Chassi --(Prismatic para baixo + Mola)--> Suporte
	local baixo = CFrame.Angles(0, 0, -math.pi / 2) -- eixo X do anexo vira -Y
	local aChassi = anexo(chassi, "Susp_" .. k, CFrame.new(ax, ya, az) * baixo)
	local aSuporte = anexo(suporte, "Susp", baixo)
	local guia = Instance.new("PrismaticConstraint")
	guia.Name = "Guia_" .. k
	guia.Attachment0 = aChassi
	guia.Attachment1 = aSuporte
	guia.LimitsEnabled = true
	guia.LowerLimit = math.max(0, L - susp.curso)
	guia.UpperLimit = L + susp.curso
	guia.Parent = modelo
	local mola = Instance.new("SpringConstraint")
	mola.Name = "Mola_" .. k
	mola.Attachment0 = aChassi
	mola.Attachment1 = aSuporte
	-- A mola comprime com o peso: comprimento livre maior pela compressão esperada (peso da roda / rigidez) + altura extra,
	-- senão o carro afunda ~0,5 stud e o assoalho raspa em qualquer degrau (medido: 0,15 de vão; degrau de 0,6 prendia a picape).
	local compressao = modelo:GetAttribute("CompressaoMola")
	mola.FreeLength = L + (if type(compressao) == "number" then compressao else 0)
	mola.Stiffness = susp.rigidez
	mola.Damping = susp.amortecimento
	mola.MaxForce = FORCA_MOLA
	mola.LimitsEnabled = false
	mola.Visible = false
	mola.Parent = modelo

	-- direção (só na frente): Suporte --(Servo, eixo Y)--> Cubo
	if frente then
		local cima = CFrame.Angles(0, 0, math.pi / 2) -- eixo X do anexo vira +Y
		local d = Instance.new("HingeConstraint")
		d.Name = "Dir_" .. k
		d.Attachment0 = anexo(suporte, "Dir", cima)
		d.Attachment1 = anexo(cubo, "Dir", cima)
		d.ActuatorType = Enum.ActuatorType.Servo
		d.ServoMaxTorque = TORQUE_DIRECAO
		d.AngularSpeed = VELOCIDADE_DIRECAO
		d.TargetAngle = 0
		d.LimitsEnabled = true
		d.LowerAngle = -ANGULO_DIRECAO
		d.UpperAngle = ANGULO_DIRECAO
		d.Parent = modelo
	end

	-- tração: Cubo --(Motor, eixo X)--> Roda. Estacionado = freado.
	local m = Instance.new("HingeConstraint")
	m.Name = "Motor_" .. k
	m.Attachment0 = anexo(cubo, "Motor", CFrame.new())
	m.Attachment1 = anexo(roda, "Motor", CFrame.new())
	m.ActuatorType = Enum.ActuatorType.Motor
	m.MotorMaxTorque = TORQUE_FREIO * raio
	m.AngularVelocity = 0
	m.Parent = modelo
end

-- Litros para o atributo Combustivel: 1 casa decimal (o passo mínimo de mudança é Config/Combustivel.passoAtributo).
function VeiculoModelo.arredondarLitros(litros: number): number
	return math.floor(litros * 10 + 0.5) / 10
end

-- Cria o carro ancorado em `cf` (origem no chão), já com o estado aplicado, dentro de workspace.Veiculos.
function VeiculoModelo.criar(estado: Estado, cf: CFrame): Model
	registrarGrupos()
	local tipo = Cfg.tipos[estado.tipo]
	assert(tipo, "VeiculoModelo: tipo desconhecido: " .. tostring(estado.tipo))
	VeiculoModelo.carregar()
	local malhasTipo = Malhas.tipos and Malhas.tipos[estado.tipo]
	local sx, sy, sz = dimensoes(if malhasTipo and malhasTipo.dimensoes then malhasTipo.dimensoes else tipo.tamanho)

	local modelo = Instance.new("Model")
	modelo.Name = "Veiculo_" .. estado.tipo
	local raio = if malhasTipo and type(malhasTipo.raioRoda) == "number" then malhasTipo.raioRoda else RAIO_RODA
	local folga = if malhasTipo and type(malhasTipo.folgaRoda) == "number" then malhasTipo.folgaRoda else FOLGA_RODA
	local chassiCF = cf * CFrame.new(0, sy / 2 + raio - folga + 0.05, 0)
	local cor, texturaCor = sortearCor(tipo, malhasTipo, estado.queimado)

	local chassi =
		nova(modelo, "Chassi", Vector3.new(sx, sy, sz), chassiCF, Color3.new(0.2, 0.2, 0.2), Enum.Material.Metal, {
			transp = 1,
			colide = false,
			consulta = false,
			densidade = PhysicalProperties.new(math.clamp(tipo.massa / (sx * sy * sz), 0.01, 100), 0.3, 0, 1, 1),
		})
	modelo.PrimaryPart = chassi

	local function corpo(nome: string, tam: Vector3, pos: Vector3, c: Color3, mat: Enum.Material, o: Opcoes?): Part
		local opcoes: Opcoes = o or {}
		if opcoes.peca == nil then
			opcoes.peca = "Carroceria"
		end
		local p = nova(modelo, nome, tam, chassiCF * CFrame.new(pos) * (opcoes.rot or CFrame.identity), c, mat, opcoes)
		p.Massless = true
		soldar(chassi, p)
		return p
	end

	-- carroceria (níveis em fração de sy: piso -0.5..-0.25, capô/porta-malas até 0, cabine 0..0.38, teto até 0.5)
	local cz, cabine = 0.08 * sz, 0.4 * sz
	corpo("Carroceria", Vector3.new(sx, 0.25 * sy, sz), Vector3.new(0, -0.375 * sy, 0), cor, Enum.Material.Metal)
	corpo(
		"Frente",
		Vector3.new(sx, 0.25 * sy, 0.38 * sz),
		Vector3.new(0, -0.125 * sy, -0.31 * sz),
		cor,
		Enum.Material.Metal
	)
	corpo(
		"Tras",
		Vector3.new(sx, 0.25 * sy, 0.22 * sz),
		Vector3.new(0, -0.125 * sy, 0.39 * sz),
		cor,
		Enum.Material.Metal
	)
	corpo("Capo", Vector3.new(sx - 0.1, 0.1, 0.38 * sz), Vector3.new(0, 0.05, -0.31 * sz), cor, Enum.Material.Metal, {
		peca = "Motor",
	})
	corpo(
		"PortaMalas",
		Vector3.new(sx - 0.1, 0.1, 0.22 * sz),
		Vector3.new(0, 0.05, 0.39 * sz),
		cor,
		Enum.Material.Metal
	)
	for lado, nome in { [-1] = "PortaE", [1] = "PortaD" } do
		corpo(
			nome,
			Vector3.new(0.2, 0.25 * sy, cabine),
			Vector3.new(lado * (sx / 2 - 0.1), -0.125 * sy, cz),
			cor,
			Enum.Material.Metal
		)
	end
	corpo("ParaChoque", Vector3.new(sx, 0.4, 0.3), Vector3.new(0, -0.35 * sy, -sz / 2 - 0.1), cor, Enum.Material.Metal)
	corpo(
		"Teto",
		Vector3.new(sx - 0.4, 0.12 * sy, cabine + 0.2),
		Vector3.new(0, 0.44 * sy, cz),
		cor,
		Enum.Material.Metal
	)

	local altVidro = 0.38 * sy
	local function vidroDe(nome: string, tam: Vector3, pos: Vector3)
		corpo("Vidro_" .. nome, tam, pos, COR_VIDRO, Enum.Material.Glass, { transp = 0.5, peca = "Vidro_" .. nome })
	end
	vidroDe("ParaBrisa", Vector3.new(sx - 0.5, altVidro, 0.15), Vector3.new(0, altVidro / 2, cz - cabine / 2))
	vidroDe("Traseiro", Vector3.new(sx - 0.5, altVidro, 0.15), Vector3.new(0, altVidro / 2, cz + cabine / 2))
	vidroDe("JanelaE", Vector3.new(0.12, altVidro, cabine - 0.3), Vector3.new(-sx / 2 + 0.1, altVidro / 2, cz))
	vidroDe("JanelaD", Vector3.new(0.12, altVidro, cabine - 0.3), Vector3.new(sx / 2 - 0.1, altVidro / 2, cz))

	-- bancos e volante
	local posBancos = posicoesBancosMalha(malhasTipo, sy, tipo.assentos) or posicoesBancos(tipo.assentos, sx, sy, sz)
	for i, pos in posBancos do
		local banco: Seat = if i == 1 then Instance.new("VehicleSeat") else Instance.new("Seat")
		banco.Name = "Banco" .. i
		banco.Size = Vector3.new(2, 0.5, 2)
		banco.CFrame = chassiCF * CFrame.new(pos)
		banco.Color = Color3.fromRGB(45, 42, 40)
		banco.Material = Enum.Material.Fabric
		banco.Anchored = true
		banco.CanTouch = false
		banco.CanQuery = false
		banco.CanCollide = false
		banco.Massless = true
		banco.CollisionGroup = GRUPO_CORPO
		banco.TopSurface = Enum.SurfaceType.Smooth
		banco.BottomSurface = Enum.SurfaceType.Smooth
		banco:SetAttribute("TranspBase", 0)
		banco:SetAttribute("ColideBase", false)
		banco:SetAttribute("ConsultaBase", false)
		if banco:IsA("VehicleSeat") then
			-- só fornece Throttle/Steer ao cliente: nada de direção automática do Roblox
			banco.MaxSpeed = 0
			banco.Torque = 0
			banco.TurnSpeed = 0
			banco.HeadsUpDisplay = false
		end
		banco.Parent = modelo
		soldar(chassi, banco)
	end
	local pm = posBancos[1]
	corpo(
		"Volante",
		Vector3.new(0.15, 1.1, 1.1),
		Vector3.new(pm.X, pm.Y + 0.9, pm.Z - 1.0),
		Color3.fromRGB(25, 25, 27),
		Enum.Material.Plastic,
		{
			forma = Enum.PartType.Cylinder,
			colide = false,
			consulta = false,
			peca = "Carroceria",
			rot = CFrame.Angles(math.rad(-25), math.pi / 2, 0),
		}
	)

	-- tampa do tanque (docs/combustivel.md §4.2): bloco cinza no lado esquerdo, atrás da porta; só decorativa (sem vida própria,
	-- o tiro nela conta como carroceria). Attachment PortaCombustivel na face externa (-X) é o destino da mangueira.
	local ct = CfgComb.carro.tampa
	local tamTampa = Vector3.new(ct.tamanho[1], ct.tamanho[2], ct.tamanho[3])
	local tampa = nova(
		modelo,
		"Tampa",
		tamTampa,
		chassiCF * CFrame.new(ct.fx * sx - ct.saliencia, ct.fy * sy, ct.fz * sz),
		COR_TAMPA,
		Enum.Material.Metal,
		{ colide = false, consulta = true, peca = "Carroceria" }
	)
	tampa.Massless = true
	soldar(chassi, tampa)
	local face = Vector3.new(-tamTampa.X / 2, 0, 0)
	anexo(tampa, "PortaCombustivel", CFrame.lookAt(face, face + Vector3.new(-1, 0, 0)))
	CollectionService:AddTag(tampa, "Tampa")
	if not estado.queimado then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Abastecer"
		prompt.ActionText = "Abastecer"
		prompt.ObjectText = tipo.nome
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = CfgComb.mangueira.alcanceTampa
		prompt.RequiresLineOfSight = false
		prompt.Parent = tampa
	end

	-- faróis (Config/Veiculos.farol): bloco colado na frente + SpotLight (facho) + PointLight (chão em volta). Apagados ao nascer;
	-- o atributo FarolLigado manda (VeiculoModelo.definirFarol). O bloco inclina `inclinacao` graus para o facho cair na estrada.
	local cfFarol = Cfg.farol
	for lado, nome in { [-1] = "Farol_E", [1] = "Farol_D" } do
		local lampada = corpo(
			nome,
			Vector3.new(0.14 * sx, 0.07 * sy, 0.12),
			Vector3.new(lado * cfFarol.lado * sx, cfFarol.altura * sy, -sz / 2 + 0.02),
			COR_FAROL_APAGADO,
			Enum.Material.Glass,
			{ colide = false, rot = CFrame.Angles(math.rad(-cfFarol.inclinacao), 0, 0) }
		)
		lampada.CastShadow = false
		local corLuz = cfFarol.cor
		local facho = Instance.new("SpotLight")
		facho.Name = "Facho"
		facho.Face = Enum.NormalId.Front
		facho.Angle = cfFarol.angulo
		facho.Range = cfFarol.alcance
		facho.Brightness = cfFarol.brilho
		facho.Color = Color3.fromRGB(corLuz[1], corLuz[2], corLuz[3])
		facho.Shadows = false
		facho.Enabled = false
		facho.Parent = lampada
		local chao = Instance.new("PointLight")
		chao.Name = "Preenchimento"
		chao.Range = cfFarol.preenchimento.alcance
		chao.Brightness = cfFarol.preenchimento.brilho
		chao.Color = facho.Color
		chao.Shadows = false
		chao.Enabled = false
		chao.Parent = lampada
	end

	local moldeRoda = molde("Roda")
	local malhaRoda = if moldeRoda then moldeRoda:FindFirstChildWhichIsA("MeshPart") else nil
	local texturaRoda = if type(Malhas.roda) == "table" and type(Malhas.roda.textura) == "string"
		then Malhas.roda.textura
		else nil
	modelo:SetAttribute(
		"CompressaoMola",
		tipo.massa * workspace.Gravity / 4 / Cfg.suspensao.rigidez + Cfg.suspensao.alturaExtra
	)
	for _, k in RODAS do
		montarRoda(modelo, chassi, k, sx, sy, sz, malhasTipo and malhasTipo.rodas, malhaRoda, texturaRoda, raio, folga)
	end
	-- origem do carro-molde = centro da base da carroceria = fundo do Chassi
	if aplicarMalhas(modelo, estado, tipo, chassi, chassiCF * CFrame.new(0, -sy / 2, 0), texturaCor) then
		modelo:SetAttribute("Malha", true)
	end

	modelo:SetAttribute("Veiculo", true)
	modelo:SetAttribute("Tipo", estado.tipo)
	modelo:SetAttribute("MotorLigado", false)
	modelo:SetAttribute("Tanque", tipo.tanque)
	modelo:SetAttribute("Combustivel", VeiculoModelo.arredondarLitros(estado.combustivel))
	modelo:SetAttribute("SemCombustivel", estado.combustivel <= 0)
	modelo:SetAttribute("Abastecendo", false)
	modelo:SetAttribute("FarolLigado", false)
	modelo:SetAttribute("CorBase", cor)
	modelo:SetAttribute("AnguloDirecao", ANGULO_DIRECAO)
	modelo:SetAttribute("RaioRoda", raio)
	modelo:SetAttribute("FolgaRoda", folga)
	-- olho do motorista no espaço do Chassi = topo do banco + 2.70 (cabeça do personagem sentado); o Cabine lê este atributo
	local olho: Vector3
	local o = if malhasTipo then vetorDe(malhasTipo.olho) else nil
	if o then
		olho = Vector3.new(o.X, o.Y - sy / 2, o.Z)
	else
		olho = posBancos[1] + Vector3.new(0, 0.25 + OLHO_ACIMA_BANCO, 0)
	end
	modelo:SetAttribute("OlhoLocal", olho);
	(modelo :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	VeiculoModelo.aplicar(modelo, estado)

	local pasta = workspace:FindFirstChild("Veiculos")
	if not pasta then
		pasta = Instance.new("Folder")
		pasta.Name = "Veiculos"
		pasta.Parent = workspace
	end
	modelo.Parent = pasta
	return modelo
end

local function exibir(p: Instance?, visivel: boolean)
	if not (p and p:IsA("BasePart")) then
		return
	end
	p.Transparency = if visivel then (p:GetAttribute("TranspBase") or 0) else 1
	p.CanCollide = visivel and p:GetAttribute("ColideBase") == true
	p.CanQuery = visivel and p:GetAttribute("ConsultaBase") == true
end

local function malhaDe(modelo: Model, nome: string): BasePart?
	local m = modelo:FindFirstChild(nome .. "_Malha")
	if m and m:IsA("BasePart") then
		return m
	end
	return nil
end

-- Reflete FarolLigado (e Queimado) nos dois faróis: bloco neon aceso + luzes ligadas. Queimado: faróis somem e nada acende.
local function atualizarFarol(modelo: Model)
	local queimado = modelo:GetAttribute("Queimado") == true
	local ligado = modelo:GetAttribute("FarolLigado") == true and not queimado
	for _, nome in FAROIS do
		local p = modelo:FindFirstChild(nome)
		if p and p:IsA("BasePart") then
			p:SetAttribute("TranspBase", if queimado then 1 else 0)
			p.Transparency = if queimado then 1 else 0
			p.Material = if ligado then Enum.Material.Neon else Enum.Material.Glass
			p.Color = if ligado then COR_FAROL_ACESO else COR_FAROL_APAGADO
			for _, filho in p:GetChildren() do
				if filho:IsA("Light") then
					filho.Enabled = ligado
				end
			end
		end
	end
end

-- Liga/apaga os faróis. Devolve o estado final (carro queimado não acende).
function VeiculoModelo.definirFarol(modelo: Model, ligado: boolean): boolean
	local final = ligado and modelo:GetAttribute("Queimado") ~= true
	modelo:SetAttribute("FarolLigado", final)
	atualizarFarol(modelo)
	return final
end

-- Reflete o estado no modelo (atributos, aparência, suspensão). Idempotente.
function VeiculoModelo.aplicar(modelo: Model, estado: Estado)
	local lim = Regra.limites(estado, Cfg)
	local queimado = estado.queimado
	modelo:SetAttribute("Queimado", queimado)
	modelo:SetAttribute("Motor", estado.motor)
	modelo:SetAttribute("Carroceria", estado.carroceria)
	modelo:SetAttribute("VelMax", lim.velMax)
	local raio = modelo:GetAttribute("RaioRoda")
	raio = if type(raio) == "number" then raio else RAIO_RODA
	modelo:SetAttribute("Torque", lim.torque * raio) -- força no chão = torque / raio
	modelo:SetAttribute("Aderencia", lim.aderencia)
	modelo:SetAttribute("Puxa", lim.puxa)

	-- carroceria: escurece com o dano; queimado = ferrugem preta
	local corBase = modelo:GetAttribute("CorBase")
	local base: Color3 = if typeof(corBase) == "Color3" then corBase else Color3.fromRGB(110, 110, 115)
	local avaria = math.clamp(1 - estado.carroceria / 100, 0, 1)
	local corAtual = if queimado then COR_QUEIMADO else base:Lerp(COR_BATIDO, avaria * 0.55)
	local material = if queimado then Enum.Material.CorrodedMetal else Enum.Material.Metal
	for _, nome in CARROCERIA do
		local p = modelo:FindFirstChild(nome)
		if p and p:IsA("BasePart") then
			p.Color = corAtual
			p.Material = material
			exibir(p, not estado.faltando[nome])
		end
		-- com malha a textura original fica: não escurece
		local mm = malhaDe(modelo, nome)
		if mm then
			mm.Transparency = if estado.faltando[nome] then 1 else 0
		end
	end
	for _, nome in FALTANDO do
		modelo:SetAttribute("Falta_" .. nome, estado.faltando[nome] == true)
	end

	for _, nome in VIDROS do
		local st = estado.vidros[nome]
		modelo:SetAttribute("Vidro_" .. nome, st)
		local p = modelo:FindFirstChild("Vidro_" .. nome)
		local mm = malhaDe(modelo, "Vidro_" .. nome)
		if mm then
			mm.Transparency = if queimado or st == "faltando" then 1 elseif st == "quebrado" then 0.25 else 0.5
			mm.Color = if st == "quebrado" then COR_VIDRO_QUEBRADO else COR_VIDRO
		end
		if p and p:IsA("BasePart") then
			if queimado or st == "faltando" then
				exibir(p, false)
			elseif st == "quebrado" then
				-- textura rachada por cor; sem colisão nem consulta: tiro e braço passam
				p.Color = COR_VIDRO_QUEBRADO
				p.Transparency = if mm then 1 else 0.25
				p.CanCollide = false
				p.CanQuery = false
			else
				p.Color = COR_VIDRO
				exibir(p, true)
			end
		end
	end

	-- pneus: mola mais curta = carro mais baixo
	local compressao = modelo:GetAttribute("CompressaoMola")
	local L = Cfg.suspensao.comprimento + (if type(compressao) == "number" then compressao else 0)
	local friccao = PhysicalProperties.new(
		math.max(0.01, DENSIDADE_RODA / raio ^ 3),
		math.max(0.15, ATRITO_RODA * lim.aderencia),
		0,
		100,
		1
	)
	for _, k in RODAS do
		local st = estado.pneus[k]
		modelo:SetAttribute("Pneu_" .. k, st)
		local roda = modelo:FindFirstChild("Roda_" .. k)
		local mola = modelo:FindFirstChild("Mola_" .. k)
		local sem = queimado or st == "faltando"
		exibir(roda, not sem)
		local mm = malhaDe(modelo, "Roda_" .. k)
		if mm then
			mm.Transparency = if sem then 1 else 0
		end
		if roda and roda:IsA("BasePart") then
			roda.CustomPhysicalProperties = friccao
		end
		if mola and mola:IsA("SpringConstraint") then
			if queimado or st == "faltando" then
				mola.FreeLength = L - Cfg.queda.faltando
			elseif st == "furado" then
				mola.FreeLength = L - Cfg.queda.furado
			else
				mola.FreeLength = L
			end
		end
	end

	for _, p in modelo:GetChildren() do
		if p:IsA("Seat") or p:IsA("VehicleSeat") then
			p.Transparency = if queimado then 1 else 0
			p.Disabled = queimado
		end
	end
	exibir(modelo:FindFirstChild("Volante"), not queimado)
	local tampa = modelo:FindFirstChild("Tampa")
	local promptTampa = tampa and tampa:FindFirstChild("Abastecer")
	if promptTampa and promptTampa:IsA("ProximityPrompt") then
		promptTampa.Enabled = not queimado
	end
	local mv = malhaDe(modelo, "Volante")
	if mv then
		mv.Transparency = if queimado then 1 else 0
	end
	atualizarFarol(modelo)
end

-- Pose de carro ESTACIONADO (ancorado): a mola só age com física, então o estado precisa aparecer na pose.
-- Queimado: sem rodas, a carroceria desce até o chão. Pneu furado/faltando: o canto desce (Cfg.queda) e o carro inclina.
-- Chame logo depois de criar (usa o CFrame de criação como base e não acumula).
function VeiculoModelo.assentar(modelo: Model, estado: Estado)
	local chassi = modelo.PrimaryPart
	if not chassi or not chassi.Anchored then
		return
	end
	local base = chassi:GetAttribute("CFBase")
	if typeof(base) ~= "CFrame" then
		base = chassi.CFrame
		chassi:SetAttribute("CFBase", base)
	end
	local raio, folga = modelo:GetAttribute("RaioRoda"), modelo:GetAttribute("FolgaRoda")
	local vao = if type(raio) == "number" and type(folga) == "number" then raio - folga else 0.8
	if estado.queimado then
		chassi.CFrame = (base :: CFrame) * CFrame.new(0, -vao, 0)
		return
	end
	local queda: { [string]: number } = {}
	for _, k in RODAS do
		local st = estado.pneus[k]
		queda[k] = if st == "faltando" then Cfg.queda.faltando elseif st == "furado" then Cfg.queda.furado else 0
	end
	local media = (queda.FE + queda.FD + queda.TE + queda.TD) / 4
	local frente, tras = (queda.FE + queda.FD) / 2, (queda.TE + queda.TD) / 2
	local esquerda, direita = (queda.FE + queda.TE) / 2, (queda.FD + queda.TD) / 2
	local aFE, aTD = chassi:FindFirstChild("Susp_FE"), chassi:FindFirstChild("Susp_TD")
	local entreEixos, bitola = 10, 5
	if aFE and aTD and aFE:IsA("Attachment") and aTD:IsA("Attachment") then
		entreEixos = math.max(1, math.abs(aTD.Position.Z - aFE.Position.Z))
		bitola = math.max(1, math.abs(aTD.Position.X - aFE.Position.X))
	end
	-- X positivo levanta o nariz (frente é -Z); Z positivo levanta a direita (+X)
	local arfagem = (tras - frente) / entreEixos
	local rolagem = (esquerda - direita) / bitola
	chassi.CFrame = (base :: CFrame) * CFrame.new(0, -media, 0) * CFrame.Angles(arfagem, 0, rolagem)
end

-- Põe o carro ancorado com o ponto visível mais baixo EXATAMENTE no chão (nunca flutua, nunca afunda).
function VeiculoModelo.encostar(modelo: Model)
	local menor, ponto = math.huge, nil
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.9 then
			local c, s = p.CFrame, p.Size
			local meia = 0.5
				* (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z)
			if p.Position.Y - meia < menor then
				menor, ponto = p.Position.Y - meia, p.Position
			end
		end
	end
	if not ponto then
		return
	end
	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	local ignorar: { Instance } = { modelo }
	local pasta = workspace:FindFirstChild("Veiculos")
	if pasta then
		table.insert(ignorar, pasta)
	end
	filtro.FilterDescendantsInstances = ignorar
	local h = workspace:Raycast(ponto + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), filtro)
	if not h then
		return
	end
	local delta = h.Position.Y - menor
	if math.abs(delta) > 0.02 then
		modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, delta, 0))
	end
end

function VeiculoModelo.ancorar(modelo: Model, ancorado: boolean)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = ancorado
		end
	end
end

-- Freio de estacionamento: motores travados em 0 (ligado) ou soltos (desligado, o cliente comanda).
function VeiculoModelo.freiar(modelo: Model, ligado: boolean)
	local raio = modelo:GetAttribute("RaioRoda")
	raio = if type(raio) == "number" then raio else RAIO_RODA
	for _, k in RODAS do
		local m = modelo:FindFirstChild("Motor_" .. k)
		if m and m:IsA("HingeConstraint") then
			m.AngularVelocity = 0
			m.MotorMaxTorque = if ligado then TORQUE_FREIO * raio else 0
		end
	end
end

-- Dono da física: o motorista (jogador) ou o servidor (nil). Só vale em peça não ancorada.
function VeiculoModelo.definirDono(modelo: Model, jogador: Player?)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			local raiz = p:GetRootPart()
			if raiz == p then
				pcall(p.SetNetworkOwner, p, jogador)
			end
		end
	end
end

return VeiculoModelo
