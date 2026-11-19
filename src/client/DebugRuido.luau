-- DebugRuido: só no Studio. Desenha no chão um disco com o raio do alcance de cada ruído (F8 liga/desliga). Dono: P3.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Rede = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rede"))

local DebugRuido = {}

local DURACAO = 1 -- s até o disco sumir
local ESPESSURA = 0.2
local TRANSPARENCIA_INICIAL = 0.6

-- Cor do disco = banda que domina o alcance (docs/som.md §7.3): grave azul, médio branco, agudo amarelo, chão marrom.
local COR_BANDA: { [string]: Color3 } = {
	grave = Color3.fromRGB(70, 120, 255),
	medio = Color3.fromRGB(245, 245, 245),
	agudo = Color3.fromRGB(255, 220, 60),
	chao = Color3.fromRGB(139, 90, 43),
}

local function cor(banda: string?): Color3
	return COR_BANDA[banda or "medio"] or COR_BANDA.medio
end

function DebugRuido.iniciar()
	if not RunService:IsStudio() then
		return
	end

	local ligado = false -- desligado por padrão: só o medidor (HudSom) mostra o ruído; F8 liga o disco de teste
	local pasta = Instance.new("Folder")
	pasta.Name = "DebugRuido"
	pasta.Parent = workspace

	UserInputService.InputBegan:Connect(function(entrada, processado)
		if processado or entrada.KeyCode ~= Enum.KeyCode.F8 then
			return
		end
		ligado = not ligado
		print("[DebugRuido] " .. (if ligado then "ligado" else "desligado"))
	end)

	Rede.evento("RuidoDebug").OnClientEvent
		:Connect(function(posicao: Vector3, alcance: number, _db: number, banda: string?)
			if not ligado or typeof(posicao) ~= "Vector3" or type(alcance) ~= "number" or alcance <= 0 then
				return
			end
			local disco = Instance.new("Part")
			disco.Name = "Ruido"
			disco.Shape = Enum.PartType.Cylinder
			-- o Cylinder do Roblox é deitado no eixo X: o eixo do disco vira o Y do mundo girando 90° em Z
			disco.Size = Vector3.new(ESPESSURA, alcance * 2, alcance * 2)
			disco.CFrame = CFrame.new(posicao) * CFrame.Angles(0, 0, math.rad(90))
			disco.Anchored = true
			disco.CanCollide = false
			disco.CanQuery = false
			disco.CanTouch = false
			disco.CastShadow = false
			disco.Material = Enum.Material.Neon
			disco.Color = cor(banda)
			disco.Transparency = TRANSPARENCIA_INICIAL
			disco.Parent = pasta
			TweenService:Create(disco, TweenInfo.new(DURACAO), { Transparency = 1 }):Play()
			Debris:AddItem(disco, DURACAO + 0.1)
		end)
end

return DebugRuido
