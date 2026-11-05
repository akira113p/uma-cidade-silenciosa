-- Mouse: dono único do cursor. Com algum menu aberto o cursor fica livre; fora disso fica preso no centro e escondido
-- (primeira pessoa). Cada menu chama Mouse.pedir("Nome") ao abrir e Mouse.liberar("Nome") ao fechar.
--
-- Por que não um botão Modal: no teste de 2026-11-01 um GuiButton Modal visível NÃO soltou o mouse (ModalEnabled
-- ficou false e MouseBehavior continuou LockCenter). O que funciona é forçar MouseBehavior = Default a cada quadro,
-- DEPOIS da câmera (RenderPriority.Last). Ao fechar o menu a câmera volta a prender o mouse sozinha.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Mouse = {}

local jogador = Players.LocalPlayer
local abertos: { [string]: boolean } = {}
local quantidade = 0

function Mouse.pedir(nome: string)
	if not abertos[nome] then
		abertos[nome] = true
		quantidade += 1
	end
end

function Mouse.liberar(nome: string)
	if abertos[nome] then
		abertos[nome] = nil
		quantidade -= 1
	end
end

-- true enquanto algum menu está aberto (ArmasCliente não atira)
function Mouse.menuAberto(): boolean
	return quantidade > 0
end

function Mouse.iniciar()
	RunService:BindToRenderStep("MouseJogo", Enum.RenderPriority.Last.Value, function()
		if quantidade > 0 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		else
			-- na terceira pessoa o cursor livre é natural; na primeira pessoa ele some
			UserInputService.MouseIconEnabled = jogador.CameraMode ~= Enum.CameraMode.LockFirstPerson
		end
	end)
end

return Mouse
