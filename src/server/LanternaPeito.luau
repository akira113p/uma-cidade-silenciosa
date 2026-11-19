-- Lanterna de peito (2026-11-16): o modelo do pacote PsxFlashLights (Config/LanternaMalha) preso no UpperTorso do personagem
-- enquanto a lanterna está equipada. Só o servidor monta/desmonta (replica para todos). A animação (chave deslizando, lente e
-- indicador acendendo) e a luz são VISUAIS e ficam em client/Lanterna, lendo Character.LanternaLigada.
-- Peças: Model "LanternaPeito" com Corpo (Weld no UpperTorso), Lente e Indicador (Weld no Corpo) e Botao (Motor6D "BotaoJunta",
-- o cliente mexe no Transform). Sem asset (falhou/ainda não enviado) monta em blocos com as medidas da Config.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Cfg = require(Config:WaitForChild("Lanterna"))
local Malha = require(Config:WaitForChild("LanternaMalha"))

local LanternaPeito = {}

local NOME = "LanternaPeito"
local moldes: { [string]: BasePart }? = nil
local carregando = false

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function inerte(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

-- Carrega o Model do asset uma vez (yield). Sem asset ou com erro: moldes = {} e vale a versão em blocos.
local function carregar()
	if moldes or carregando then
		while carregando do
			task.wait()
		end
		return
	end
	carregando = true
	local achados: { [string]: BasePart } = {}
	if Malha.modelo then
		local ok, res = pcall(function()
			return InsertService:LoadAsset(Malha.modelo)
		end)
		if ok and res then
			for _, d in res:GetDescendants() do
				if d:IsA("MeshPart") and Malha.partes[d.Name] then
					local m = d:Clone()
					if Malha.textura then
						m.TextureID = Malha.textura
					end
					achados[d.Name] = m
				end
			end
			res:Destroy()
			if not achados.Corpo then
				warn("[LanternaPeito] o modelo não tem MeshPart 'Corpo'; usando blocos")
				achados = {}
			end
		else
			warn("[LanternaPeito] LoadAsset falhou: " .. tostring(res) .. "; usando blocos")
		end
	end
	moldes = achados
	carregando = false
end

local function peca(nome: string): BasePart
	local m = moldes and moldes[nome]
	local p: BasePart
	if m then
		p = m:Clone()
	else
		local d = Malha.partes[nome]
		local b = Instance.new("Part")
		b.Size = v3(d.tamanho)
		if nome == "Lente" then
			b.Shape = Enum.PartType.Cylinder
			b.Size = Vector3.new(d.tamanho[3], d.tamanho[2], d.tamanho[1]) -- cilindro no eixo X: gira no Weld
			b.Color = Color3.fromRGB(150, 150, 140)
			b.Material = Enum.Material.Glass
		elseif nome == "Botao" then
			b.Color = Color3.fromRGB(120, 122, 125)
			b.Material = Enum.Material.Metal
		elseif nome == "Indicador" then
			b.Color = Color3.fromRGB(90, 20, 20)
		else
			b.Color = Color3.fromRGB(88, 70, 52)
			b.Material = Enum.Material.Metal
		end
		p = b
	end
	p.Name = nome
	inerte(p)
	return p
end

-- CFrame da peça no espaço da origem do modelo (centro da Config; a Lente em blocos é cilindro deitado em X -> virar para Z).
local function noModelo(nome: string, p: BasePart): CFrame
	local cf = CFrame.new(v3(Malha.partes[nome].centro))
	if nome == "Lente" and not p:IsA("MeshPart") then
		cf *= CFrame.Angles(0, math.rad(90), 0)
	end
	if p:IsA("MeshPart") then
		cf *= CFrame.Angles(0, math.rad(Malha.giroImportacao or 0), 0) -- o Roblox gira a malha do FBX ao importar
	end
	return cf
end

function LanternaPeito.tirar(personagem: Model?)
	local m = personagem and personagem:FindFirstChild(NOME)
	if m then
		m:Destroy()
	end
end

-- Veste a lanterna no peito (idempotente). Yield na 1ª vez (carrega o asset).
function LanternaPeito.vestir(personagem: Model)
	carregar()
	if personagem:FindFirstChild(NOME) or not personagem.Parent then
		return
	end
	local torso = personagem:FindFirstChild("UpperTorso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local c = Cfg.peito
	local esc = c.escala or 1
	local modelo = Instance.new("Model")
	modelo.Name = NOME

	local corpo = peca("Corpo")
	corpo.Parent = modelo
	-- origem do modelo na frente do UpperTorso
	local origem = CFrame.new(c.pos.x, c.pos.y, -torso.Size.Z / 2 + c.pos.z)
		* CFrame.fromEulerAnglesYXZ(math.rad(c.rot.x), math.rad(c.rot.y), math.rad(c.rot.z))
	local cCorpo = noModelo("Corpo", corpo)
	local w = Instance.new("Weld")
	w.Name = "PeitoJunta"
	w.Part0 = torso
	w.Part1 = corpo
	w.C0 = origem * CFrame.new(cCorpo.Position * esc) * cCorpo.Rotation -- a rotação leva o giro de importação da malha
	w.Parent = corpo

	for _, nome in { "Lente", "Botao", "Indicador" } do
		if not Malha.partes[nome] then
			continue
		end
		if nome == "Indicador" and not (moldes and moldes.Indicador) then
			continue
		end
		local p = peca(nome)
		p.Parent = modelo
		local rel = cCorpo:Inverse() * noModelo(nome, p)
		rel = CFrame.new(rel.Position * esc) * rel.Rotation
		local j: JointInstance
		if nome == "Botao" then
			local motor = Instance.new("Motor6D")
			motor.Name = "BotaoJunta"
			j = motor
		else
			j = Instance.new("Weld")
			j.Name = nome .. "Junta"
		end
		j.Part0 = corpo
		j.Part1 = p
		j.C0 = rel
		j.Parent = p
	end
	if esc ~= 1 then
		for _, p in modelo:GetChildren() do
			if p:IsA("BasePart") then
				p.Size *= esc
			end
		end
	end
	modelo.PrimaryPart = corpo
	modelo.Parent = personagem
end

function LanternaPeito.iniciar()
	task.spawn(carregar)
end

return LanternaPeito
