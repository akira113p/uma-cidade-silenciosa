-- Aparencia (cliente): na primeira pessoa esconde a cabeça cúbica (e o rosto) do PRÓPRIO personagem, para ela não
-- tapar a câmera. A cabeça dos outros jogadores continua visível. O servidor monta o visual (server/Aparencia.luau).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Aparencia"))

local Aparencia = {}

local jogador = Players.LocalPlayer

local function esconder(cabeca: Instance, escondido: boolean)
	if cabeca:IsA("BasePart") then
		cabeca.LocalTransparencyModifier = if escondido then 1 else 0
	end
	for _, gui in cabeca:GetChildren() do
		if gui:IsA("SurfaceGui") then
			gui.Enabled = not escondido
		end
	end
end

function Aparencia.iniciar()
	RunService:BindToRenderStep("AparenciaCabeca", Enum.RenderPriority.Last.Value, function()
		local personagem = jogador.Character
		local camera = workspace.CurrentCamera
		if not personagem or not camera then
			return
		end
		local raiz = personagem:FindFirstChild("Head")
		local perto = raiz ~= nil
			and (camera.CFrame.Position - (raiz :: BasePart).Position).Magnitude < Cfg.distanciaPrimeiraPessoa
		for _, cabeca in CollectionService:GetTagged(Cfg.etiquetaCabeca) do
			if cabeca:IsDescendantOf(personagem) then
				esconder(cabeca, perto)
			end
		end
	end)
end

return Aparencia
