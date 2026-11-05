--!strict
-- Distorção de lente: esfera Glass na frente da câmera (barril real por refração). Só gráfico alto. Dono: S3.
local Lente = {}

local cfg: any
local ajuste: (string, any) -> any
local jogador: Player
local pastaMundo: Folder
local esfera: Part
local ligadoPref = false
local nivelAtual = 3
local qualidadeOk = false
local proxQualidade = 0
local visivel = false
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = false

local function qualidadeAtual(): number
	local ok, v = pcall(function()
		return (UserSettings().GameSettings.SavedQualityLevel :: any).Value
	end)
	return if ok and type(v) == "number" then v else 0
end

local function mostrar(v: boolean)
	if v == visivel then
		return
	end
	visivel = v
	esfera.Parent = if v then pastaMundo else nil
end

local function cor3(t: any): Color3
	return Color3.new(t[1], t[2], t[3])
end

local function aplicarForma()
	local d = ajuste("Lente_diametro", cfg.diametro)
	esfera.Size = Vector3.new(d, d, d)
	esfera.Transparency = ajuste("Lente_transparencia", cfg.transparencia)
	esfera.Color = cor3(cfg.cor)
end

function Lente.iniciar(ctx: any)
	cfg = ctx.config.Lente
	ajuste = ctx.ajuste
	jogador = ctx.jogador
	pastaMundo = ctx.pastaMundo
	esfera = Instance.new("Part")
	esfera.Name = "Lente"
	esfera.Shape = Enum.PartType.Ball
	esfera.Material = Enum.Material.Glass
	esfera.Reflectance = 0
	esfera.CastShadow = false
	esfera.Anchored = true
	esfera.CanCollide = false
	esfera.CanQuery = false
	esfera.CanTouch = false
	aplicarForma()
end

function Lente.atualizar(e: any)
	if not ligadoPref then
		mostrar(false)
		return
	end
	if e.t >= proxQualidade then
		proxQualidade = e.t + ajuste("Lente_reavaliarQualidade", cfg.reavaliarQualidade)
		qualidadeOk = ajuste("Lente_ignorarQualidade", cfg.ignorarQualidade)
			or qualidadeAtual() >= ajuste("Lente_qualidadeMinima", cfg.qualidadeMinima)
		aplicarForma()
	end
	local camera = workspace.CurrentCamera
	if
		not camera
		or not qualidadeOk
		or not e.primeiraPessoa
		or nivelAtual < ajuste("Lente_nivelMinimo", cfg.nivelMinimo)
	then
		mostrar(false)
		return
	end
	local d = ajuste("Lente_distancia", cfg.distancia)
	local diam = ajuste("Lente_diametro", cfg.diametro)
	local cf = camera.CFrame
	-- não atravessar parede: só a face da frente importa (a esfera é grande e quase encosta na câmera; parede
	-- dentro dela só aparece refratada). Algo a menos de 1 stud depois da face da frente esconde a lente.
	local personagem = jogador.Character
	params.FilterDescendantsInstances = if personagem then { personagem, pastaMundo } else { pastaMundo }
	if workspace:Raycast(cf.Position, cf.LookVector * math.max(0.5, d - diam / 2 + 1), params) then
		mostrar(false)
		return
	end
	esfera.CFrame = cf * CFrame.new(0, 0, -d)
	mostrar(true)
end

function Lente.ligar(ligado: boolean)
	ligadoPref = ligado
	proxQualidade = 0
	if not ligado and esfera then
		mostrar(false)
	end
end

function Lente.nivel(n: number)
	nivelAtual = n
end

return Lente
