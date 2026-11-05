-- Versao: etiqueta pequena com o build do código no canto superior direito (só no Studio). Serve para o usuário
-- conferir se o jogo aberto está com o código mais novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Versao"))

local Versao = {}

function Versao.iniciar()
	print("[Versao] cliente build " .. Cfg.build .. " (" .. Cfg.nota .. ")")
	if not RunService:IsStudio() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Versao"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900
	gui.IgnoreGuiInset = true
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(1, 0)
	t.Position = UDim2.new(1, -8, 0, 4)
	t.Size = UDim2.fromOffset(260, 16)
	t.TextXAlignment = Enum.TextXAlignment.Right
	t.TextSize = 12
	t.Font = Enum.Font.Code
	t.TextColor3 = Color3.fromRGB(200, 200, 205)
	t.TextTransparency = 0.25
	t.Text = "build " .. Cfg.build
	t.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Versao
