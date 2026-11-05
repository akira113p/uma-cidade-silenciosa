-- Aparencia: troca o visual de todo personagem R15 pelo modelo do jogo, só por código. Primeiro iguala o corpo com as
-- escalas de Config/Aparencia (esbelto e alto); depois deixa as peças do avatar invisíveis (elas continuam sendo a
-- física, a animação e a hitbox) e solda um bloco colorido em cada uma. O cliente esconde a cabeça do próprio jogador
-- na primeira pessoa (client/Aparencia.luau). Config: src/shared/Config/Aparencia.luau.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Aparencia"))

local Aparencia = {}

local function cor(nome: string): Color3
	local c = Cfg.cores[nome]
	return Color3.fromRGB(c[1], c[2], c[3])
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

local function quadro(
	pai: Instance,
	nome: string,
	c: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	raio: number
): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BorderSizePixel = 0
	f.BackgroundColor3 = c
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	if raio > 0 then
		local canto = Instance.new("UICorner")
		canto.CornerRadius = UDim.new(0, raio)
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

-- Linhas verticais de tricô nas faces pedidas.
local function costurar(bloco: BasePart, def: { faces: { string }, cor: string, linhas: number })
	for _, face in def.faces do
		local gui = superficie(bloco, "Costura", face, 140, 140, 1)
		for i = 1, def.linhas do
			local linha = Instance.new("Frame")
			linha.BorderSizePixel = 0
			linha.BackgroundColor3 = cor(def.cor)
			linha.BackgroundTransparency = Cfg.transparenciaCostura
			linha.AnchorPoint = Vector2.new(0.5, 0)
			linha.Position = UDim2.fromScale((i - 0.5) / def.linhas, 0)
			linha.Size = UDim2.new(0, 5, 1, 0)
			linha.Parent = gui
		end
	end
end

-- Rosto: sobrancelhas, olhos brancos com pupila olhando de lado, boca e língua.
local function desenharRosto(cabeca: BasePart)
	local gui = superficie(cabeca, "Rosto", "Front", 220, 200, 0)
	for _, x in { 34, 140 } do
		quadro(gui, "Sobrancelha", cor("sobrancelha"), x, 40, 52, 9, 3)
		local olho = quadro(gui, "Olho", cor("olhoBranco"), x + 4, 58, 44, 38, 6)
		quadro(olho, "Pupila", cor("pupila"), 22, 11, 16, 18, 4)
	end
	quadro(gui, "Boca", cor("boca"), 76, 128, 70, 12, 3)
	quadro(gui, "Lingua", cor("lingua"), 124, 138, 22, 20, 8)
end

-- Cabelo trançado dourado: laje no topo, tranças na frente e atrás, faixa atrás e nas laterais.
local function desenharCabelo(cabeca: BasePart, largura: number, altura: number, profundidade: number)
	local h = Cfg.cabelo
	local c = cor("cabelo")
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
	for _, parte in lista do
		CollectionService:AddTag(parte, Cfg.etiquetaCabeca)
	end
end

-- Detalhes do suéter na frente do tronco: bolso de canguru e cordões do capuz.
local function detalhesSuter(tronco: BasePart)
	local gui = superficie(tronco, "Detalhes", "Front", 136, 168, 1)
	quadro(gui, "Bolso", cor("bolso"), 22, 100, 92, 44, 4)
	for _, x in { 52, 80 } do
		quadro(gui, "Cordao", cor("cordao"), x, 14, 4, 34, 2)
	end
end

-- Fivela prateada do cinto (o LowerTorso inteiro é o cinto preto).
local function detalhesCinto(cintura: BasePart)
	local gui = superficie(cintura, "Fivela", "Front", 136, 40, 1)
	quadro(gui, "Fivela", cor("fivela"), 52, 8, 32, 24, 3)
end

-- Tênis: cabedal rosa em cima, sola branca embaixo (ligeiramente maior).
local function montarPe(original: BasePart, bloco: Part)
	local sola = original.Size.Y * Cfg.solaFracao
	local resto = original.Size.Y - sola
	bloco.Size = Vector3.new(original.Size.X, resto, original.Size.Z)
	bloco.CFrame = original.CFrame * CFrame.new(0, sola / 2, 0)
	acessorio(
		bloco,
		"Sola",
		Vector3.new(original.Size.X * Cfg.solaFolga, sola, original.Size.Z * Cfg.solaFolga),
		Vector3.new(0, -(resto + sola) / 2, 0),
		cor("sola")
	)
end

local function novoBloco(grupo: string): Part
	local bloco = Instance.new("Part")
	bloco.Name = "Bloco"
	bloco.Anchored = false
	bloco.CanCollide = false
	bloco.CanQuery = false
	bloco.CanTouch = false
	bloco.Massless = true
	bloco.TopSurface = Enum.SurfaceType.Smooth
	bloco.BottomSurface = Enum.SurfaceType.Smooth
	bloco.Color = cor(if grupo == "cabeca" then "pele" else grupo)
	bloco.Material = if Cfg.tecido[grupo] then Enum.Material.Fabric else Enum.Material.SmoothPlastic
	return bloco
end

local function revestir(personagem: Model)
	for _, x in personagem:GetChildren() do
		if
			x:IsA("Accessory")
			or x:IsA("Shirt")
			or x:IsA("Pants")
			or x:IsA("ShirtGraphic")
			or x:IsA("CharacterMesh")
		then
			x:Destroy()
		end
	end
	local tronco = personagem:FindFirstChild("UpperTorso")
	local larguraTronco = if tronco and tronco:IsA("BasePart") then tronco.Size.X else 1.3

	for nome, grupo in Cfg.partes do
		local original = personagem:FindFirstChild(nome)
		if original and original:IsA("BasePart") and not original:FindFirstChild("Bloco") then
			local bloco = novoBloco(grupo)
			if grupo == "cabeca" then
				local c = Cfg.cabeca
				local largura = larguraTronco * c.larguraSobreTronco
				local altura = largura * c.alturaSobreLargura
				local profundidade = largura * c.profundidadeSobreLargura
				bloco.Size = Vector3.new(largura, altura, profundidade)
				-- a base da cabeça fica onde a base da cabeça do avatar estava (sobre os ombros)
				bloco.CFrame = original.CFrame * CFrame.new(0, (altura - original.Size.Y) / 2, 0)
				CollectionService:AddTag(bloco, Cfg.etiquetaCabeca)
				desenharRosto(bloco)
				desenharCabelo(bloco, largura, altura, profundidade)
			elseif grupo == "sapato" then
				montarPe(original, bloco)
			else
				bloco.Size = original.Size
				bloco.CFrame = original.CFrame
			end
			local solda = Instance.new("WeldConstraint")
			solda.Part0 = original
			solda.Part1 = bloco
			solda.Parent = bloco
			bloco.Parent = original

			local costura = Cfg.costurasEm[nome]
			if costura then
				costurar(bloco, costura)
			end
			if nome == "UpperTorso" then
				detalhesSuter(bloco)
			elseif nome == "LowerTorso" then
				detalhesCinto(bloco)
			end
			original.Transparency = 1
		end
	end
	personagem:SetAttribute("Aparencia", true)
	-- roupa/acessório que o motor ainda adicionar depois (avatar carregando tarde) é removido na hora
	personagem.ChildAdded:Connect(function(x)
		if
			x:IsA("Accessory")
			or x:IsA("Shirt")
			or x:IsA("Pants")
			or x:IsA("ShirtGraphic")
			or x:IsA("CharacterMesh")
		then
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
			revestir(personagem)
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
