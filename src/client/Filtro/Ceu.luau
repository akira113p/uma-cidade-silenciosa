--!strict
-- Caixa de céu da névoa: 6 placas presas à câmera logo depois do FogEnd, pintadas com FogColor. Dono: S3.
-- Tudo além do FogEnd já é pintado com FogColor pelo motor, então a caixa vira céu de névoa da cor exata da hora.
local Lighting = game:GetService("Lighting")

local Ceu = {}

local cfg: any
local ajuste: (string, any) -> any
local pasta: Folder
local partes: { Part } = {}
local lado = 0 -- lado atual da caixa
local fogEndAtual = -1
local corAtual: Color3? = nil
local ligado = true
local pai: Instance

-- direção de cada placa (normal para fora)
local FACES = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local function metade(): number
	local fogEnd = Lighting.FogEnd
	local margem = ajuste("Ceu_margem", cfg.margem)
	local esp = ajuste("Ceu_espessura", cfg.espessura)
	return math.min(fogEnd + margem, (cfg.ladoMaximo - 2 * esp) / 2)
end

local function redimensionar()
	local esp = ajuste("Ceu_espessura", cfg.espessura)
	local m = metade()
	lado = m
	local larg = 2 * m + 2 * esp
	for i, p in partes do
		local f = FACES[i]
		if f.X ~= 0 then
			p.Size = Vector3.new(esp, larg, larg)
		elseif f.Y ~= 0 then
			p.Size = Vector3.new(larg, esp, larg)
		else
			p.Size = Vector3.new(larg, larg, esp)
		end
	end
end

function Ceu.iniciar(ctx: any)
	cfg = ctx.config.Ceu
	ajuste = ctx.ajuste
	pai = ctx.pastaMundo
	pasta = Instance.new("Folder")
	pasta.Name = "Ceu"
	for i = 1, 6 do
		local p = Instance.new("Part")
		p.Name = "Placa" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Lighting.FogColor
		p.Parent = pasta
		partes[i] = p
	end
	fogEndAtual = Lighting.FogEnd
	redimensionar()
	pasta.Parent = pai
end

function Ceu.atualizar(_e: any)
	if not ligado then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if math.abs(Lighting.FogEnd - fogEndAtual) > ajuste("Ceu_toleranciaFogEnd", cfg.toleranciaFogEnd) then
		fogEndAtual = Lighting.FogEnd
		redimensionar()
	end
	local cor = Lighting.FogColor
	if cor ~= corAtual then
		corAtual = cor
		for _, p in partes do
			p.Color = cor
		end
	end
	local esp = ajuste("Ceu_espessura", cfg.espessura)
	local pos = camera.CFrame.Position
	local d = lado + esp / 2
	local chao = math.min(ajuste("Ceu_profundidadeChao", cfg.profundidadeChao), lado)
	for i, p in partes do
		local f = FACES[i]
		if i == 4 then
			p.Position = pos + Vector3.new(0, -(chao + esp / 2), 0)
		else
			p.Position = pos + f * d
		end
	end
end

function Ceu.ligar(l: boolean)
	ligado = l
	if pasta then
		pasta.Parent = if l then pai else nil
	end
end

function Ceu.nivel(_n: number) end

return Ceu
