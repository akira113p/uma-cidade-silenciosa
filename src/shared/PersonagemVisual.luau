-- PersonagemVisual: monta o visual de um personagem (Config/Personagens) sobre as 15 peças R15. Funciona no servidor
-- (src/server/Aparencia.luau) e no cliente (prévia do seletor e braços do viewmodel). Dono: parte S (docs/personagens.md §2).
-- As peças R15 originais não mudam (nome, CanQuery, física): o visual é UMA peça "Bloco" soldada em cada uma, visível;
-- a original fica Transparency = 1. Visual "bloco" = Part colorida pela paleta do personagem + acessórios (rosto, cabelo,
-- roupa); visual "malhas" = MeshPart com MeshId/TextureID de Config/PersonagensMalhas, caindo em bloco se faltar algo.
-- O código de "padrao" veio de server/Aparencia.luau sem mudar o resultado.
-- ATENÇÃO: com malhas, criarParte pode ESPERAR (AssetService:CreateMeshPartAsync); chame de dentro de task/pcall.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local Cfg = require(Config:WaitForChild("Aparencia"))
local CfgPers = require(Config:WaitForChild("Personagens"))
local Malhas = require(Config:WaitForChild("PersonagensMalhas"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Personagens"))

local PersonagemVisual = {}

export type Opcoes = {
	raiz: BasePart?, -- malhas: HumanoidRootPart do corpo real (se a peça original não está no modelo dele, ex.: viewmodel)
	distPeAteRaiz: number?, -- malhas: distância dos pés ao centro da raiz, se o modelo não tem os dois pés
	previa: boolean?, -- true = sem etiquetas, sem costura em SurfaceGui, rosto/roupa em peças finas (SurfaceGui não aparece em ViewportFrame)
}

local NOMES_PARTES: { string } = {}
for nome in Cfg.partes do
	table.insert(NOMES_PARTES, nome)
end
table.sort(NOMES_PARTES)

local ESPESSURA_DETALHE = 0.04 -- studs, retângulos da prévia

-- Paleta de cores (Color3) por personagem, calculada uma vez.
local paletas: { [string]: { [string]: Color3 } } = {}

function PersonagemVisual.entrada(id: string?): Regras.Entrada
	local e = Regras.porId(CfgPers.lista, id)
	if e then
		return e
	end
	return Regras.porId(CfgPers.lista, CfgPers.padrao) :: Regras.Entrada
end

local function paleta(entrada: Regras.Entrada): { [string]: Color3 }
	local p = paletas[entrada.id]
	if not p then
		p = {}
		for chave, c in Regras.paleta(Cfg.cores, entrada) do
			p[chave] = Color3.fromRGB(c[1], c[2], c[3])
		end
		paletas[entrada.id] = p
	end
	return p
end

-- "bloco" ou "malhas" (já considerando se as malhas estão completas).
function PersonagemVisual.visual(id: string?): "bloco" | "malhas"
	local entrada = PersonagemVisual.entrada(id)
	return Regras.visualEfetivo(entrada, (Malhas :: any)[entrada.id], NOMES_PARTES)
end

-- Parte sem física presa a um bloco, na posição local `pos` (studs) do bloco.
local function acessorio(
	bloco: BasePart,
	nome: string,
	tamanho: Vector3,
	pos: Vector3,
	c: Color3,
	forma: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Shape = forma or Enum.PartType.Block
	p.Size = tamanho
	p.Color = c
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = bloco.CFrame * CFrame.new(pos)
	local solda = Instance.new("WeldConstraint")
	solda.Part0 = bloco
	solda.Part1 = p
	solda.Parent = p
	p.Parent = bloco
	return p
end

----------------------------------------------------------------------------------------------------------------------
-- Retângulos desenhados na face da frente (rosto, roupa): SurfaceGui + Frames no jogo; peças finas na prévia.
----------------------------------------------------------------------------------------------------------------------

-- x, y, w, h em pixels do canvas; raio = canto arredondado; filhos têm coordenadas relativas ao pai.
type Retangulo = {
	nome: string,
	cor: string,
	x: number,
	y: number,
	w: number,
	h: number,
	raio: number,
	filhos: { Retangulo }?,
}

local function retangulo(nome: string, cor: string, x: number, y: number, w: number, h: number, raio: number): Retangulo
	return { nome = nome, cor = cor, x = x, y = y, w = w, h = h, raio = raio }
end

local ROSTO_CANVAS = Vector2.new(220, 200)
local TRONCO_CANVAS = Vector2.new(136, 168)
local CINTO_CANVAS = Vector2.new(136, 40)

local function rostoPadrao(): { Retangulo }
	local lista: { Retangulo } = {}
	for _, x in { 34, 140 } do
		table.insert(lista, retangulo("Sobrancelha", "sobrancelha", x, 40, 52, 9, 3))
		local olho = retangulo("Olho", "olhoBranco", x + 4, 58, 44, 38, 6)
		olho.filhos = { retangulo("Pupila", "pupila", 22, 11, 16, 18, 4) }
		table.insert(lista, olho)
	end
	table.insert(lista, retangulo("Boca", "boca", 76, 128, 70, 12, 3))
	table.insert(lista, retangulo("Lingua", "lingua", 124, 138, 22, 20, 8))
	return lista
end

-- Rosto sério: olhos menores e pupilas no meio, boca fina, sem língua.
local function rostoSerio(): { Retangulo }
	local lista: { Retangulo } = {}
	for _, x in { 38, 134 } do
		table.insert(lista, retangulo("Sobrancelha", "sobrancelha", x, 44, 48, 8, 3))
		local olho = retangulo("Olho", "olhoBranco", x + 8, 62, 32, 26, 5)
		olho.filhos = { retangulo("Pupila", "pupila", 10, 6, 12, 14, 3) }
		table.insert(lista, olho)
	end
	table.insert(lista, retangulo("Boca", "boca", 82, 140, 56, 8, 3))
	return lista
end

local ROSTOS: { [string]: () -> { Retangulo } } = { padrao = rostoPadrao, serio = rostoSerio }

-- Detalhes da frente do tronco por estilo de roupa.
local function troncoSuter(): { Retangulo }
	local lista = { retangulo("Bolso", "bolso", 22, 100, 92, 44, 4) }
	for _, x in { 52, 80 } do
		table.insert(lista, retangulo("Cordao", "cordao", x, 14, 4, 34, 2))
	end
	return lista
end

local function troncoGravata(): { Retangulo }
	return {
		retangulo("Colarinho", "bolso", 38, 2, 60, 16, 2),
		retangulo("NoGravata", "gravata", 60, 10, 16, 16, 2),
		retangulo("Gravata", "gravata", 62, 26, 12, 108, 2),
	}
end

local function troncoJaqueta(): { Retangulo }
	return {
		retangulo("Ziper", "cordao", 66, 0, 4, 168, 1),
		retangulo("BolsoPeito", "bolso", 14, 40, 44, 34, 3),
		retangulo("BolsoPeito", "bolso", 78, 40, 44, 34, 3),
		retangulo("BolsoBaixo", "bolso", 14, 118, 44, 36, 3),
		retangulo("BolsoBaixo", "bolso", 78, 118, 44, 36, 3),
	}
end

local TRONCOS: { [string]: () -> { Retangulo } } = {
	suter = troncoSuter,
	gravata = troncoGravata,
	jaqueta = troncoJaqueta,
}

local function fivela(): { Retangulo }
	return { retangulo("Fivela", "fivela", 52, 8, 32, 24, 3) }
end

local function quadro(pai: Instance, r: Retangulo, c: Color3, x: number, y: number): Frame
	local f = Instance.new("Frame")
	f.Name = r.nome
	f.BorderSizePixel = 0
	f.BackgroundColor3 = c
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(r.w, r.h)
	if r.raio > 0 then
		local canto = Instance.new("UICorner")
		canto.CornerRadius = UDim.new(0, r.raio)
		canto.Parent = f
	end
	f.Parent = pai
	return f
end

local function superficie(
	bloco: BasePart,
	nome: string,
	face: string,
	largura: number,
	altura: number,
	luz: number
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = nome
	gui.Face = (Enum.NormalId :: any)[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(largura, altura)
	gui.LightInfluence = luz
	gui.Parent = bloco
	return gui
end

local function desenharFrames(pai: Instance, lista: { Retangulo }, cores: { [string]: Color3 })
	for _, r in lista do
		local f = quadro(pai, r, cores[r.cor], r.x, r.y)
		if r.filhos then
			desenharFrames(f, r.filhos, cores)
		end
	end
end

-- Mesmo desenho em peças finas coladas na frente (a face "Front" olha para -Z; o canvas cresce para a direita de quem
-- olha de frente, que é -X local).
local function desenharPecas(
	bloco: BasePart,
	lista: { Retangulo },
	canvas: Vector2,
	cores: { [string]: Color3 },
	ox: number,
	oy: number,
	nivel: number
)
	local s = bloco.Size
	for _, r in lista do
		local ax, ay = ox + r.x, oy + r.y
		local cx = s.X / 2 - (ax + r.w / 2) / canvas.X * s.X
		local cy = s.Y / 2 - (ay + r.h / 2) / canvas.Y * s.Y
		local z = -(s.Z / 2 + ESPESSURA_DETALHE / 2 + (nivel - 1) * ESPESSURA_DETALHE)
		acessorio(
			bloco,
			r.nome,
			Vector3.new(r.w / canvas.X * s.X, r.h / canvas.Y * s.Y, ESPESSURA_DETALHE),
			Vector3.new(cx, cy, z),
			cores[r.cor]
		)
		if r.filhos then
			desenharPecas(bloco, r.filhos, canvas, cores, ax, ay, nivel + 1)
		end
	end
end

local function desenhar(
	bloco: BasePart,
	nomeGui: string,
	lista: { Retangulo },
	canvas: Vector2,
	luz: number,
	cores: { [string]: Color3 },
	previa: boolean
)
	if previa then
		desenharPecas(bloco, lista, canvas, cores, 0, 0, 1)
	else
		desenharFrames(superficie(bloco, nomeGui, "Front", canvas.X, canvas.Y, luz), lista, cores)
	end
end

-- Linhas verticais de tricô nas faces pedidas (só no jogo; a prévia dispensa).
local function costurar(
	bloco: BasePart,
	def: { faces: { string }, cor: string, linhas: number },
	cores: { [string]: Color3 }
)
	for _, face in def.faces do
		local gui = superficie(bloco, "Costura", face, 140, 140, 1)
		for i = 1, def.linhas do
			local linha = Instance.new("Frame")
			linha.BorderSizePixel = 0
			linha.BackgroundColor3 = cores[def.cor]
			linha.BackgroundTransparency = Cfg.transparenciaCostura
			linha.AnchorPoint = Vector2.new(0.5, 0)
			linha.Position = UDim2.fromScale((i - 0.5) / def.linhas, 0)
			linha.Size = UDim2.new(0, 5, 1, 0)
			linha.Parent = gui
		end
	end
end

-- Cabelo: laje no topo, tranças (se o preset tiver), faixa atrás e nas laterais. `h` = preset (Cfg.cabelo ou CfgPers.cabelos.x).
local function desenharCabelo(
	cabeca: BasePart,
	largura: number,
	altura: number,
	profundidade: number,
	h: any,
	c: Color3,
	etiquetar: boolean
)
	local topo = altura / 2
	local lista: { Part } = {}
	table.insert(
		lista,
		acessorio(
			cabeca,
			"CabeloTopo",
			Vector3.new(largura * 1.02, h.lajeEspessura, profundidade * 1.02),
			Vector3.new(0, topo + h.lajeEspessura / 2, 0),
			c
		)
	)
	local d = h.trancaDiametro
	if h.trancas > 0 then
		for fileira = 1, 2 do
			local z = if fileira == 1 then -profundidade / 2 + d / 2 else profundidade / 2 - d / 2
			for i = 1, h.trancas do
				local x = -largura / 2 + d / 2 + (largura - d) * (i - 1) / (h.trancas - 1)
				table.insert(
					lista,
					acessorio(
						cabeca,
						"Tranca",
						Vector3.new(d, d, d),
						Vector3.new(x, topo + h.lajeEspessura + d / 3, z),
						c,
						Enum.PartType.Ball
					)
				)
			end
		end
	end
	local alturaTras = altura * h.faixaTras
	table.insert(
		lista,
		acessorio(
			cabeca,
			"CabeloTras",
			Vector3.new(largura * 1.02, alturaTras, 0.07),
			Vector3.new(0, topo - alturaTras / 2, profundidade / 2 + 0.035),
			c
		)
	)
	local alturaLado = altura * h.faixaLado
	for _, lado in { -1, 1 } do
		table.insert(
			lista,
			acessorio(
				cabeca,
				"CabeloLado",
				Vector3.new(0.07, alturaLado, profundidade * 1.02),
				Vector3.new(lado * (largura / 2 + 0.035), topo - alturaLado / 2, 0),
				c
			)
		)
	end
	if etiquetar then
		for _, parte in lista do
			CollectionService:AddTag(parte, Cfg.etiquetaCabeca)
		end
	end
end

-- Tênis/bota: cabedal em cima, sola embaixo (ligeiramente maior). O bloco já tem a altura do cabedal.
local function desenharSola(bloco: BasePart, c: Color3)
	local sola = bloco.Size.Y / (1 - Cfg.solaFracao) * Cfg.solaFracao
	acessorio(
		bloco,
		"Sola",
		Vector3.new(bloco.Size.X * Cfg.solaFolga, sola, bloco.Size.Z * Cfg.solaFolga),
		Vector3.new(0, -(bloco.Size.Y + sola) / 2, 0),
		c
	)
end

----------------------------------------------------------------------------------------------------------------------
-- Peça visual
----------------------------------------------------------------------------------------------------------------------

local function novoBloco(grupo: string, cores: { [string]: Color3 }): Part
	local bloco = Instance.new("Part")
	bloco.Name = "Bloco"
	bloco.Anchored = false
	bloco.CanCollide = false
	bloco.CanQuery = false
	bloco.CanTouch = false
	bloco.Massless = true
	bloco.TopSurface = Enum.SurfaceType.Smooth
	bloco.BottomSurface = Enum.SurfaceType.Smooth
	bloco.Color = cores[if grupo == "cabeca" then "pele" else grupo]
	bloco.Material = if Cfg.tecido[grupo] then Enum.Material.Fabric else Enum.Material.SmoothPlastic
	return bloco
end

local molde: { [string]: MeshPart } = {}
local malhaFalhou: { [string]: boolean } = {}

-- Raiz (HumanoidRootPart) que ancora o conjunto de malhas: a de opcoes.raiz ou a do modelo da peça original.
local function raizDe(original: BasePart, opcoes: Opcoes?): BasePart?
	if opcoes and opcoes.raiz then
		return opcoes.raiz
	end
	local modelo = original:FindFirstAncestorOfClass("Model")
	local raiz = modelo and modelo:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		return raiz
	end
	return nil
end

-- CFrame da peça em relação à HumanoidRootPart na pose de REPOUSO (juntas sem Transform), pela cadeia de juntas C0 * C1⁻¹.
-- A soldagem tem que usar o repouso: o revestir roda com a animação já tocando, e a pose do instante deslocaria a malha.
local function repousoRelativo(parte: BasePart): CFrame?
	local cf = CFrame.identity
	local atual: BasePart = parte
	for _ = 1, 8 do
		if atual.Name == "HumanoidRootPart" then
			return cf
		end
		local junta: any = nil
		for _, j in atual:GetChildren() do
			if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and (j :: any).Part1 == atual then
				junta = j
				break
			end
		end
		if not junta or not junta.Part0 then
			return nil
		end
		cf = junta.C0 * junta.C1:Inverse() * cf
		atual = junta.Part0
	end
	return nil
end

-- Distância (studs) da base dos pés até o centro da raiz, na pose de repouso (os pés originais já estão no tamanho final).
local function distanciaPeAteRaiz(raiz: BasePart, opcoes: Opcoes?): number?
	if opcoes and opcoes.distPeAteRaiz then
		return opcoes.distPeAteRaiz
	end
	local modelo = raiz.Parent
	if not modelo then
		return nil
	end
	local menor = math.huge
	for _, nome in { "LeftFoot", "RightFoot" } do
		local pe = modelo:FindFirstChild(nome)
		if pe and pe:IsA("BasePart") then
			-- no espaço da raiz: não depende de o personagem estar de pé no mundo
			local rep = repousoRelativo(pe)
			local y = if rep then rep.Position.Y else raiz.CFrame:PointToObjectSpace(pe.Position).Y
			menor = math.min(menor, y - pe.Size.Y / 2)
		end
	end
	if menor == math.huge then
		return nil
	end
	return -menor
end

-- MeshPart da peça (cópia de um molde por MeshId); nil se faltar dado ou o carregamento falhar (aí cai em bloco).
-- Escala UNIFORME do conjunto: k = Config/Personagens.alturaCorpo / alturaTotalStuds; Size = tamanhoNativo * k (sem
-- esticar por eixo) e posição = raiz * (centroMontagem * k - (0, distPeAteRaiz, 0)), com a rotação da raiz.
local function criarMalha(id: string, nome: string, raiz: BasePart, distPe: number, original: BasePart): MeshPart?
	local dados = (Malhas :: any)[id]
	local def = dados and dados.partes and dados.partes[nome]
	if not def or not dados.alturaTotalStuds or dados.alturaTotalStuds <= 0 then
		return nil
	end
	local base = molde[def.meshId]
	if not base then
		local ok, resultado = pcall(function()
			-- fidelidade só pode ser dada na criação (escrever CollisionFidelity/RenderFidelity depois exige capability de plugin)
			return (AssetService :: any):CreateMeshPartAsync(Content.fromUri(def.meshId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Performance,
			})
		end)
		if not ok or not resultado then
			if not malhaFalhou[def.meshId] then
				malhaFalhou[def.meshId] = true
				warn("[PersonagemVisual] malha não carregou (" .. tostring(def.meshId) .. "): " .. tostring(resultado))
			end
			return nil
		end
		base = resultado :: MeshPart
		molde[def.meshId] = base
	end
	local k = CfgPers.alturaCorpo / dados.alturaTotalStuds
	local nativo, centro = def.tamanhoNativo, def.centroMontagem
	local m = base:Clone()
	m.Name = "Bloco"
	m.TextureID = dados.textura
	m.Transparency = 0
	m.Size = Vector3.new(nativo[1], nativo[2], nativo[3]) * k
	-- CENTRADA na peça R15 (escala uniforme, sem esticar): a mão visível fica na mão R15, onde a arma/item é preso, e cada
	-- segmento acompanha o osso que a animação move. Posicionar pelo centroMontagem (proporções do modelo original) separava
	-- a mão visível da mão física (arma flutuando). centro/raiz/distPe ficam só de referência.
	local _ = centro and raiz and distPe
	-- o esqueleto R15 já foi movido para as proporções do modelo (ajustarEsqueleto): centrar na peça = lugar certo
	m.CFrame = original.CFrame
	m.Anchored = false
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	return m
end

-- Peça visual do personagem `id` para a peça R15 `nome` (original). Devolve Part ou MeshPart já com tamanho, cor/textura,
-- CFrame (o que o chamador solda na original) e sem física; NÃO põe pai nem solda. Acessórios: PersonagemVisual.detalhes.
function PersonagemVisual.criarParte(id: string?, nome: string, original: BasePart, opcoes: Opcoes?): BasePart
	local grupo = Cfg.partes[nome]
	assert(grupo, "PersonagemVisual.criarParte: peça R15 desconhecida: " .. tostring(nome))
	local entrada = PersonagemVisual.entrada(id)
	if PersonagemVisual.visual(entrada.id) == "malhas" then
		-- malhas ancoram na raiz do corpo: sem raiz/pés (ex.: rig só de braços), passe opcoes.raiz e opcoes.distPeAteRaiz
		local raiz = raizDe(original, opcoes)
		local distPe = raiz and distanciaPeAteRaiz(raiz, opcoes)
		local m = if raiz and distPe then criarMalha(entrada.id, nome, raiz, distPe, original) else nil
		if m then
			return m
		end
	end
	local cores = paleta(entrada)
	local bloco = novoBloco(grupo, cores)
	if grupo == "cabeca" then
		local tronco = original.Parent and original.Parent:FindFirstChild("UpperTorso")
		local larguraTronco = if tronco and tronco:IsA("BasePart") then tronco.Size.X else 1.3
		local c = Cfg.cabeca
		local largura = larguraTronco * c.larguraSobreTronco
		local altura = largura * c.alturaSobreLargura
		local profundidade = largura * c.profundidadeSobreLargura
		bloco.Size = Vector3.new(largura, altura, profundidade)
		-- a base da cabeça fica onde a base da cabeça do avatar estava (sobre os ombros)
		bloco.CFrame = original.CFrame * CFrame.new(0, (altura - original.Size.Y) / 2, 0)
	elseif grupo == "sapato" then
		local sola = original.Size.Y * Cfg.solaFracao
		local resto = original.Size.Y - sola
		bloco.Size = Vector3.new(original.Size.X, resto, original.Size.Z)
		bloco.CFrame = original.CFrame * CFrame.new(0, sola / 2, 0)
	else
		bloco.Size = original.Size
		bloco.CFrame = original.CFrame
	end
	return bloco
end

-- Acessórios do visual na peça `parte` (devolvida por criarParte), ANTES ou depois de parentear. Malhas só recebem a
-- etiqueta da cabeça (o cliente esconde na 1ª pessoa).
function PersonagemVisual.detalhes(id: string?, nome: string, parte: BasePart, opcoes: Opcoes?)
	local previa = opcoes ~= nil and opcoes.previa == true
	local grupo = Cfg.partes[nome]
	if not grupo then
		return
	end
	if grupo == "cabeca" and not previa then
		CollectionService:AddTag(parte, Cfg.etiquetaCabeca)
	end
	if parte:IsA("MeshPart") then
		return
	end
	local entrada = PersonagemVisual.entrada(id)
	local estilo = entrada.estilo
	local cores = paleta(entrada)

	if grupo == "cabeca" then
		desenhar(parte, "Rosto", (ROSTOS[estilo.rosto] or rostoPadrao)(), ROSTO_CANVAS, 0, cores, previa)
		local preset = if estilo.cabelo == "trancas" then Cfg.cabelo else CfgPers.cabelos[estilo.cabelo]
		desenharCabelo(parte, parte.Size.X, parte.Size.Y, parte.Size.Z, preset or Cfg.cabelo, cores.cabelo, not previa)
	elseif grupo == "sapato" then
		desenharSola(parte, cores.sola)
	end

	local costura = Cfg.costurasEm[nome]
	if costura and estilo.costura and not previa then
		costurar(parte, costura, cores)
	end
	if nome == "UpperTorso" then
		desenhar(parte, "Detalhes", (TRONCOS[estilo.torso] or troncoSuter)(), TRONCO_CANVAS, 1, cores, previa)
		if estilo.mochila then
			local s = parte.Size
			acessorio(
				parte,
				"Mochila",
				Vector3.new(s.X * 0.8, s.Y * 0.8, 0.5),
				Vector3.new(0, -s.Y * 0.05, s.Z / 2 + 0.25),
				cores.mochila
			)
			acessorio(
				parte,
				"MochilaFecho",
				Vector3.new(s.X * 0.7, 0.12, 0.52),
				Vector3.new(0, s.Y * 0.18, s.Z / 2 + 0.25),
				cores.mochilaFecho
			)
		end
	elseif nome == "LowerTorso" then
		-- fivela do cinto (o LowerTorso inteiro é o cinto)
		desenhar(parte, "Fivela", fivela(), CINTO_CANVAS, 1, cores, previa)
	end
end

-- Veste UMA peça R15: cria a peça visual, solda na original, aplica os detalhes e esconde a original.
function PersonagemVisual.revestirParte(id: string?, nome: string, original: BasePart, opcoes: Opcoes?)
	local bloco = PersonagemVisual.criarParte(id, nome, original, opcoes)
	PersonagemVisual.detalhes(id, nome, bloco, opcoes)
	local solda = Instance.new("WeldConstraint")
	solda.Part0 = original
	solda.Part1 = bloco
	solda.Parent = bloco
	bloco.Parent = original
	original.Transparency = 1
end

-- Veste as 15 peças R15 do modelo (as que já têm "Bloco" ficam como estão). Pode esperar (malhas).
-- Pais antes dos filhos (cada junta é refeita a partir da pose de repouso já ajustada do pai).
local ORDEM_ESQUELETO = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local function juntaDe(parte: BasePart): any
	for _, j in parte:GetChildren() do
		if (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and (j :: any).Part1 == parte then
			return j
		end
	end
	return nil
end

-- Move as juntas do R15 para as proporções do modelo de malha: o centro de cada peça R15 (em repouso) passa a ser o
-- centroMontagem * k da malha. Assim a malha vai CENTRADA na peça e fica no lugar certo, e a arma/item presos à mão R15
-- ficam na mão que se vê. Mesma rotação de repouso; só a posição muda. Uma vez por personagem (atributo EsqueletoAjustado).
local function ajustarEsqueleto(modelo: Model, id: string)
	if modelo:GetAttribute("EsqueletoAjustado") then
		return
	end
	local dados = (Malhas :: any)[id]
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if not (dados and dados.partes and dados.alturaTotalStuds and raiz and raiz:IsA("BasePart")) then
		return
	end
	local k = CfgPers.alturaCorpo / dados.alturaTotalStuds
	local distPe = distanciaPeAteRaiz(raiz)
	if not distPe then
		return
	end
	local antes: { [string]: CFrame } = {}
	for _, nome in ORDEM_ESQUELETO do
		local p = modelo:FindFirstChild(nome)
		local r = p and p:IsA("BasePart") and repousoRelativo(p)
		if not r then
			return -- esqueleto incompleto: não mexe em nada
		end
		antes[nome] = r
	end
	local novo: { [string]: CFrame } = { HumanoidRootPart = CFrame.identity }
	for _, nome in ORDEM_ESQUELETO do
		local p = modelo:FindFirstChild(nome) :: BasePart
		local j = juntaDe(p)
		local def = dados.partes[nome]
		local c = def and def.centroMontagem
		local pai = j and j.Part0 and novo[j.Part0.Name]
		if not (j and c and pai) then
			novo[nome] = antes[nome]
		else
			local desejado = CFrame.new(Vector3.new(c[1], c[2], c[3]) * k - Vector3.new(0, distPe, 0))
				* antes[nome].Rotation
			local c0 = pai:Inverse() * desejado * j.C1
			if j:IsA("AnimationConstraint") and j.Attachment0 then
				j.Attachment0.CFrame = c0
			else
				j.C0 = c0
			end
			novo[nome] = desejado
		end
	end
	modelo:SetAttribute("EsqueletoAjustado", true)
end

function PersonagemVisual.revestir(modelo: Model, id: string?, opcoes: Opcoes?)
	local idEf = PersonagemVisual.entrada(id).id
	if PersonagemVisual.visual(idEf) == "malhas" then
		ajustarEsqueleto(modelo, idEf)
		local dados = (Malhas :: any)[idEf]
		if
			not modelo:GetAttribute("EsqueletoAjustado")
			and opcoes
			and opcoes.previa
			and dados
			and dados.alturaTotalStuds
		then
			-- prévia do seletor: rig parado, sem juntas, com os pés em y = 0 no espaço do modelo. As peças vão direto para as
			-- proporções do modelo de malha (senão os braços ficam afastados do tronco, no lugar do R15).
			local k = CfgPers.alturaCorpo / dados.alturaTotalStuds
			local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
			local pe = modelo:FindFirstChild("LeftFoot") :: BasePart?
			local origem = if raiz and pe
				then CFrame.new(raiz.Position.X, pe.Position.Y - pe.Size.Y / 2, raiz.Position.Z) * raiz.CFrame.Rotation
				else modelo:GetPivot()
			for nome, def in dados.partes do
				local p = modelo:FindFirstChild(nome)
				local c = def.centroMontagem
				if p and p:IsA("BasePart") and c then
					p.CFrame = origem * CFrame.new(Vector3.new(c[1], c[2], c[3]) * k)
				end
			end
		end
	end
	for _, nome in NOMES_PARTES do
		local original = modelo:FindFirstChild(nome)
		if original and original:IsA("BasePart") and not original:FindFirstChild("Bloco") then
			PersonagemVisual.revestirParte(id, nome, original, opcoes)
		end
	end
end

-- Rig R15 aproximado e estático (15 peças invisíveis, nomes do R15, de frente para -Z) para a prévia do seletor, com
-- as escalas de Config/Aparencia.escala. Não depende de avatar nem de Humanoid. Centrado nos pés (y = 0).
function PersonagemVisual.criarRigPrevia(): Model
	local escala = Cfg.escala
	local sx, sy, sz = escala.BodyWidthScale, escala.BodyHeightScale, escala.BodyDepthScale
	local tamanhos = CfgPers.previa.tamanhos
	local modelo = Instance.new("Model")
	modelo.Name = "RigPrevia"

	local function tam(nome: string): Vector3
		local t = tamanhos[nome]
		return Vector3.new(t[1] * sx, t[2] * sy, t[3] * sz)
	end
	local function peca(nome: string, centro: Vector3): BasePart
		local p = Instance.new("Part")
		p.Name = nome
		p.Size = tam(nome)
		p.CFrame = CFrame.new(centro)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Parent = modelo
		return p
	end

	local larguraTronco = tam("UpperTorso").X
	local y = 0
	-- empilha do pé para cima; devolve o y do topo
	local function pilha(nomeA: string, nomeB: string, nomeC: string, lado: number)
		local x = lado * larguraTronco / 4
		local a, b, c = tam(nomeA), tam(nomeB), tam(nomeC)
		peca(nomeA, Vector3.new(x, a.Y / 2, 0)) -- pé
		peca(nomeB, Vector3.new(x, a.Y + b.Y / 2, 0)) -- canela
		peca(nomeC, Vector3.new(x, a.Y + b.Y + c.Y / 2, 0)) -- coxa
		return a.Y + b.Y + c.Y
	end
	y = pilha("LeftFoot", "LeftLowerLeg", "LeftUpperLeg", -1)
	pilha("RightFoot", "RightLowerLeg", "RightUpperLeg", 1)

	local baixo, alto = tam("LowerTorso"), tam("UpperTorso")
	peca("LowerTorso", Vector3.new(0, y + baixo.Y / 2, 0))
	local topoBaixo = y + baixo.Y
	peca("UpperTorso", Vector3.new(0, topoBaixo + alto.Y / 2, 0))
	local topoTronco = topoBaixo + alto.Y
	local cabeca = tam("Head")
	peca("Head", Vector3.new(0, topoTronco + cabeca.Y / 2, 0))
	-- raiz do corpo (como a HumanoidRootPart do R15): âncora do visual "malhas" na prévia
	local raiz = peca("LowerTorso", Vector3.new(0, y + baixo.Y / 2, 0))
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(larguraTronco, alto.Y + baixo.Y, alto.Z)

	for _, lado in { "Left", "Right" } do
		local sinal = if lado == "Left" then -1 else 1
		local braco, antebraco, mao = tam(lado .. "UpperArm"), tam(lado .. "LowerArm"), tam(lado .. "Hand")
		local x = sinal * (larguraTronco / 2 + braco.X / 2)
		peca(lado .. "UpperArm", Vector3.new(x, topoTronco - braco.Y / 2, 0))
		peca(lado .. "LowerArm", Vector3.new(x, topoTronco - braco.Y - antebraco.Y / 2, 0))
		peca(lado .. "Hand", Vector3.new(x, topoTronco - braco.Y - antebraco.Y - mao.Y / 2, 0))
	end
	return modelo
end

PersonagemVisual.nomesPartes = NOMES_PARTES

return PersonagemVisual
