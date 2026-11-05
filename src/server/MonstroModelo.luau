--!strict
-- MonstroModelo: monta o modelo do Rastejador (docs/rastejador.md §3) e toca as animações (plano A: Animator no servidor).
-- Colisão = bloco invisível do corpo (HumanoidRootPart, com HipHeight); visual = MeshPart com ossos, soldado, sem colisão.
-- Sem assetId (envio/LoadAsset falhou): preparar() devolve false e o Monstros cai no boneco de blocos.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Malhas = require(Shared.Config.MonstrosMalhas) :: any
local CfgRast = require(Shared.Config.Rastejador) :: any
local Regras = require(Shared.Regras.Rastejador)

local MonstroModelo = {}

local moldes: { [string]: Model } = {}
local tentou: { [string]: boolean } = {}

type Pista = { tracks: { [string]: AnimationTrack }, atual: string?, desde: number }
local pistas: { [Model]: Pista } = setmetatable({}, { __mode = "k" }) :: any

local function pastaMoldes(): Folder
	local modelos = ServerStorage:FindFirstChild("Modelos")
	if not modelos then
		modelos = Instance.new("Folder")
		modelos.Name = "Modelos"
		modelos.Parent = ServerStorage
	end
	local pasta = modelos:FindFirstChild("MonstrosMalha")
	if not pasta then
		pasta = Instance.new("Folder")
		pasta.Name = "MonstrosMalha"
		pasta.Parent = modelos
	end
	return pasta :: Folder
end

local function montar(id: string, cfg: any): Model?
	local ok, carregado = pcall(function()
		return InsertService:LoadAsset(cfg.modelo)
	end)
	if not ok then
		warn(("[MonstroModelo] LoadAsset(%s) falhou: %s"):format(tostring(cfg.modelo), tostring(carregado)))
		return nil
	end
	local malha = (carregado :: Instance):FindFirstChildWhichIsA("MeshPart", true)
	if not malha then
		warn("[MonstroModelo] modelo carregado sem MeshPart: " .. id)
		carregado:Destroy()
		return nil
	end
	local esperada = CfgRast.altura.jogadorStuds / CfgRast.altura.jogadorMetros * CfgRast.altura.metros
	if math.abs(malha.Size.Y - esperada) > esperada * 0.03 then
		warn(
			("[MonstroModelo] altura da malha %.3f != %.3f do Config/Rastejador: reexportar (exportar_rastejador.py --altura)"):format(
				malha.Size.Y,
				esperada
			)
		)
	end

	local molde = Instance.new("Model")
	molde.Name = id
	local c, cc = cfg.corpo, cfg.corpoCentro
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(c.x, c.y, c.z)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CFrame = CFrame.new(0, 0, 0)
	hrp.Parent = molde

	-- malha: centro dela = centro do bloco - corpoCentro (o bloco fica sobre o corpo, a malha estende até o chão)
	malha.Parent = molde
	malha.Anchored = false
	malha.CanCollide = false
	malha.CanTouch = false
	malha.CanQuery = true -- acertável por arma
	malha.Massless = true
	malha.TextureID = cfg.textura or ""
	malha.CFrame = hrp.CFrame * CFrame.new(-cc.x, -cc.y, -cc.z)
	local solda = Instance.new("WeldConstraint")
	solda.Part0 = hrp
	solda.Part1 = malha
	solda.Parent = hrp

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- o padrão R6 ignora HipHeight
	humanoid.HipHeight = cfg.fundoDoCorpo
	humanoid.Parent = molde
	Instance.new("Animator").Parent = humanoid

	molde.PrimaryPart = hrp
	molde:SetAttribute("Altura", malha.Size.Y)
	carregado:Destroy()
	return molde
end

-- Carrega o molde da espécie (uma vez). true = há molde pronto. Chamar de uma thread que pode esperar (LoadAsset).
function MonstroModelo.preparar(id: string): boolean
	if moldes[id] then
		return true
	end
	if tentou[id] then
		return false
	end
	tentou[id] = true
	local cfg = Malhas[id]
	if not (cfg and cfg.modelo and cfg.corpo) then
		warn("[MonstroModelo] sem assetId do modelo para " .. id .. ": usando boneco de blocos")
		return false
	end
	local molde = montar(id, cfg)
	if not molde then
		return false
	end
	molde.Parent = pastaMoldes()
	moldes[id] = molde
	return true
end

function MonstroModelo.clonar(id: string): Model?
	local molde = moldes[id]
	return if molde then molde:Clone() else nil
end

-- Animação ------------------------------------------------------------------------------------------------------

local function carregarPistas(modelo: Model, id: string): Pista?
	local cfg = Malhas[id]
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not (cfg and cfg.animacoes and animator) then
		return nil
	end
	local p: Pista = { tracks = {}, atual = nil, desde = 0 }
	for nome, animId in cfg.animacoes do
		local a = Instance.new("Animation")
		a.AnimationId = animId
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and track then
			p.tracks[nome] = track
		end
		a:Destroy()
	end
	pistas[modelo] = p
	return p
end

-- Toca `acao` (Idle/Walk/Run/Attack/Death). Ciclos: velocidade de reprodução = velocidade real ÷ nativa (Regras.velocidadeAnim).
-- Attack reinicia quando `reiniciar` (novo golpe). Death congela no último quadro (o corpo fica na pose final).
function MonstroModelo.tocar(modelo: Model, id: string, acao: string, velocidade: number, reiniciar: boolean?)
	local p = pistas[modelo] or carregarPistas(modelo, id)
	if not p then
		return
	end
	local track = p.tracks[acao]
	if not track then
		return
	end
	if p.atual == acao and not reiniciar then
		if track.Looped or acao == "Walk" or acao == "Run" then
			track:AdjustSpeed(Regras.velocidadeAnim(acao, velocidade, CfgRast))
		end
		return
	end
	local anterior = if p.atual then p.tracks[p.atual] else nil
	if anterior and anterior ~= track then
		anterior:Stop(0.15)
	end
	p.atual = acao
	if acao == "Death" then
		track:Play(0.1, 1, 1)
		task.delay(math.max(track.Length - 0.04, 0.1), function()
			if track.IsPlaying then
				track:AdjustSpeed(0) -- congela no último quadro
			end
		end)
	elseif acao == "Attack" then
		track:Play(0.08, 1, 1)
		if reiniciar then
			track.TimePosition = 0
		end
	else
		track:Play(0.15, 1, Regras.velocidadeAnim(acao, velocidade, CfgRast))
	end
end

-- Morte: solta de física e tira a colisão; a animação Death segue (quem chama toca). Sem rotação do modelo.
function MonstroModelo.congelar(modelo: Model)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
end

return MonstroModelo
