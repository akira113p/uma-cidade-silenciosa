-- Teclas: atalhos de menu (inventário, câmera, configurações, admin) com duas vias ao mesmo tempo:
--   1) UserInputService.InputBegan, que ignora o "processado" (o Roblox marca como processadas as teclas que a
--      interface padrão usa, como o Tab da lista de jogadores), e só desiste com uma caixa de texto focada;
--   2) ContextActionService com prioridade alta, que também bloqueia o atalho padrão do Roblox.
-- As duas vias chamam a mesma função com um intervalo mínimo, então um aperto nunca vale por dois.
-- No Studio, cada aperto de uma tecla registrada é impresso no Output ("[Teclas] ...") para achar conflito de tecla.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Teclas = {}

local INTERVALO_MINIMO = 0.15 -- s
local ultimo: { [string]: number } = {}

-- nomes: nomes de Enum.KeyCode ("Tab", "V"...). Nome desconhecido avisa e é ignorado.
function Teclas.ligar(nome: string, nomes: { string }, aoApertar: () -> ())
	local codigos: { Enum.KeyCode } = {}
	local conjunto: { [Enum.KeyCode]: boolean } = {}
	for _, n in nomes do
		local codigo = (Enum.KeyCode :: any)[n]
		if codigo then
			table.insert(codigos, codigo)
			conjunto[codigo] = true
		else
			warn("[Teclas] tecla desconhecida em '" .. nome .. "': " .. tostring(n))
		end
	end
	if #codigos == 0 then
		return
	end

	local function disparar()
		local agora = os.clock()
		if agora - (ultimo[nome] or 0) < INTERVALO_MINIMO then
			return
		end
		ultimo[nome] = agora
		aoApertar()
	end

	UserInputService.InputBegan:Connect(function(entrada, processado)
		if entrada.UserInputType ~= Enum.UserInputType.Keyboard or not conjunto[entrada.KeyCode] then
			return
		end
		if RunService:IsStudio() then
			print(string.format("[Teclas] %s: %s (processado=%s)", nome, entrada.KeyCode.Name, tostring(processado)))
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		disparar()
	end)

	ContextActionService:BindActionAtPriority("Teclas_" .. nome, function(_, estado)
		if estado == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			disparar()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(codigos))
end

return Teclas
