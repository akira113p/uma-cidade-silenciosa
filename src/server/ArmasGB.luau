-- Moldes do viewmodel do Gold Bright (docs/gold-bright-import.md). LoadAsset só roda no servidor: carrega uma vez cada `modelo`
-- de Config/ArmasGB e põe em ReplicatedStorage.ArmasGB.<id> (Model com o MeshPart esquelético e os Bones), para o cliente clonar.
-- Falhou (asset em moderação, sem rede, Studio sem permissão) = não há molde e o client/ArmasViewmodel segue com os blocos.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CfgGB = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ArmasGB"))

local ArmasGB = {}

local function primeiroMeshPart(raiz: Instance): MeshPart?
	if raiz:IsA("MeshPart") then
		return raiz
	end
	for _, d in raiz:GetDescendants() do
		if d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

local function carregar(pasta: Folder, id: string, cfg: any)
	if not cfg.modelo or pasta:FindFirstChild(id) then
		return
	end
	local ok, resultado = pcall(function()
		return InsertService:LoadAsset(cfg.modelo)
	end)
	if not ok or not resultado then
		warn(("[ArmasGB] LoadAsset(%s) falhou para %s: %s"):format(tostring(cfg.modelo), id, tostring(resultado)))
		return
	end
	local malha = primeiroMeshPart(resultado)
	if not malha then
		warn("[ArmasGB] o modelo de " .. id .. " não tem MeshPart")
		resultado:Destroy()
		return
	end
	local molde = Instance.new("Model")
	molde.Name = id
	malha.Parent = molde
	malha.Name = "Malha"
	malha.Anchored = true
	malha.CanCollide = false
	malha.CanQuery = false
	malha.CanTouch = false
	malha.CastShadow = false
	malha.Massless = true
	if cfg.textura then
		malha.TextureID = cfg.textura
	end
	molde.PrimaryPart = malha
	resultado:Destroy()
	molde.Parent = pasta
end

function ArmasGB.iniciar()
	local pasta = Instance.new("Folder")
	pasta.Name = "ArmasGB"
	pasta.Parent = ReplicatedStorage
	for id, cfg in CfgGB.armas do
		task.spawn(carregar, pasta, id, cfg)
	end
end

return ArmasGB
