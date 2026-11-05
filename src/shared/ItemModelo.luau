--!strict
-- Monta o Model de blocos de um item (docs/itens-no-mundo.md §2) a partir de Config/ItensModelos. Roda no servidor e no cliente.
-- Origem do Model = onde a mão segura (Model:GetPivot e PivotTo valem a origem, não o centro da PrimaryPart).
-- "chao": tudo Anchored, ModelStreamingMode Atomic, tamanhos e posições × escalaChao (item pequeno fica visível).
-- "mao": Anchored=false, Massless, peças soldadas à raiz por WeldConstraint; a raiz é presa à mão por prenderNaMao.
-- Armas (Config/Itens tipo "arma") NO CHÃO usam o modelo real de Shared/ArmaModelo, deitado (decisão 2026-11-05); os blocos de
-- Config/ItensModelos valem para elas só como reserva (ArmaModelo falhou). Na mão, quem monta a arma é o Armas.luau.

local Regra = require(script.Parent:WaitForChild("Regras"):WaitForChild("ItemModelo"))
local Dados: { modelos: { [string]: any } } =
	require(script.Parent:WaitForChild("Config"):WaitForChild("ItensModelos")) :: any

local Itens = require(script.Parent:WaitForChild("Config"):WaitForChild("Itens"))

local ItemModelo = {}

local validados: { [string]: boolean } = {}

local function modeloDe(id: string): any
	local modelo = Dados.modelos[id]
	if modelo == nil then
		error(string.format("ItemModelo: o item '%s' não tem modelo em Config/ItensModelos", tostring(id)), 3)
	end
	if not validados[id] then
		local ok, motivo = Regra.validar(modelo)
		if not ok then
			error(string.format("ItemModelo: modelo de '%s' inválido: %s", id, tostring(motivo)), 3)
		end
		validados[id] = true
	end
	return modelo
end

local function cframeDe(pos: { number }, rot: { number }): CFrame
	return CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
end

local FORMAS: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Cylinder = Enum.PartType.Cylinder,
	Ball = Enum.PartType.Ball,
}

local function novaParte(def: any, escala: number): BasePart
	local parte: BasePart
	if def.forma == "Wedge" then
		parte = Instance.new("WedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = FORMAS[def.forma]
		parte = p
	end
	parte.Name = def.nome
	parte.Size = Vector3.new(def.tam[1] * escala, def.tam[2] * escala, def.tam[3] * escala)
	parte.CFrame = cframeDe({ def.pos[1] * escala, def.pos[2] * escala, def.pos[3] * escala }, def.rot)
	parte.Color = Color3.fromRGB(def.cor[1], def.cor[2], def.cor[3])
	parte.Material = (Enum.Material :: any)[def.material]
	parte.Transparency = def.transp or 0
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false
	return parte
end

-- Arma no chão: modelo real de ArmaModelo (cabo na origem, cano para -Z), deitada de lado (Z 90°). nil se não é arma ou ArmaModelo falhou.
local GIRO_ARMA = CFrame.Angles(0, 0, math.rad(90))
local alturaArma: { [string]: number } = {} -- cache só depois de a malha estar pronta (provisório muda de tamanho)

local function modeloArma(id: string): (Model?, boolean)
	local def = Itens.itens[id]
	if not def or def.tipo ~= "arma" or def.arma == nil then
		return nil, false
	end
	local ok, ArmaModelo = pcall(function()
		return require(script.Parent:WaitForChild("ArmaModelo"))
	end)
	if not ok then
		return nil, false
	end
	local ok2, modelo = pcall(ArmaModelo.criar, def.arma)
	if not ok2 or typeof(modelo) ~= "Instance" then
		return nil, false
	end
	return modelo :: Model, ArmaModelo.pronta(def.arma)
end

-- Distância do pivô (cabo) ao ponto mais baixo do modelo depois de girar por GIRO_ARMA.
local function alturaDeitada(modelo: Model): number
	local pivo = modelo:GetPivot()
	local minimo = math.huge
	for _, parte in modelo:GetDescendants() do
		if parte:IsA("BasePart") and parte.Transparency < 1 then
			local local_ = GIRO_ARMA * pivo:ToObjectSpace(parte.CFrame)
			local m = local_.Rotation
			local tam = parte.Size / 2
			local meio = math.abs(m.RightVector.Y) * tam.X
				+ math.abs(m.UpVector.Y) * tam.Y
				+ math.abs(m.LookVector.Y) * tam.Z
			minimo = math.min(minimo, local_.Position.Y - meio)
		end
	end
	return if minimo == math.huge then 0.2 else -minimo
end

function ItemModelo.criar(id: string, modo: "chao" | "mao"): Model
	if modo == "chao" then
		local arma = modeloArma(id)
		if arma then
			arma.Name = "Item_" .. id
			arma:SetAttribute("Item", id)
			arma.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			for _, parte in arma:GetDescendants() do
				if parte:IsA("BasePart") then
					parte.Anchored = true
					parte.CanCollide = false
					parte.CanQuery = false
					parte.CanTouch = false
				end
			end
			return arma
		end
	end
	local def = modeloDe(id)
	local noChao = modo == "chao"
	local escala: number = if noChao then def.escalaChao or 1 else 1

	local modelo = Instance.new("Model")
	modelo.Name = "Item_" .. id
	modelo:SetAttribute("Item", id)
	if noChao then
		modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end

	local raiz: BasePart? = nil
	for _, parteDef in def.partes do
		local parte = novaParte(parteDef, escala)
		parte.Anchored = noChao
		parte.Massless = not noChao
		parte.Parent = modelo
		if raiz == nil then
			raiz = parte
		elseif not noChao then
			local solda = Instance.new("WeldConstraint")
			solda.Name = "Solda"
			solda.Part0 = raiz
			solda.Part1 = parte
			solda.Parent = parte
		end
	end
	local r = raiz :: BasePart
	-- o pivô do Model é a origem do modelo (CFrame identidade na montagem), não a posição da raiz
	r.PivotOffset = r.CFrame:Inverse()
	modelo.PrimaryPart = r
	return modelo
end

-- Giro (CFrame de rotação pura) para o item deitar no chão e distância da origem até o ponto mais baixo (com escalaChao).
function ItemModelo.repouso(id: string): { giro: CFrame, altura: number }
	local arma, pronta = modeloArma(id)
	if arma then
		local altura = alturaArma[id]
		if altura == nil then
			altura = alturaDeitada(arma)
			if pronta then
				alturaArma[id] = altura
			end
		end
		arma:Destroy()
		return { giro = GIRO_ARMA, altura = altura }
	end
	local r = Regra.repouso(modeloDe(id))
	return { giro = cframeDe({ 0, 0, 0 }, r.rot), altura = r.altura }
end

-- Posiciona a raiz em mão.CFrame * mao e solda à RightHand (ou LeftHand se lado = "esquerda"). false se não há mão (R6) ou raiz.
-- Se o modelo ainda não tem Parent, vira filho do personagem (a solda só vale com as duas peças no mundo).
function ItemModelo.prenderNaMao(modelo: Model, personagem: Model, id: string): boolean
	local def = modeloDe(id)
	local mao = personagem:FindFirstChild(if def.lado == "esquerda" then "LeftHand" else "RightHand")
	local raiz = modelo.PrimaryPart
	if not (mao and mao:IsA("BasePart") and raiz) then
		return false
	end
	modelo:PivotTo(mao.CFrame * cframeDe(def.mao.pos, def.mao.rot))
	if modelo.Parent == nil then
		modelo.Parent = personagem
	end
	local solda = Instance.new("WeldConstraint")
	solda.Name = "SoldaMao"
	solda.Part0 = mao
	solda.Part1 = raiz
	solda.Parent = raiz
	return true
end

return ItemModelo
