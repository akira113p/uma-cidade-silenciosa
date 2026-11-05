-- Ambiente: condição (dia/noite/chuva/tempestade) e ruído de fundo em dB. Dono: P3. Contrato: docs/arquitetura.md §5.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Som = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("Som"))

local Ambiente = {}

local INTERVALO = 1 -- s entre atualizações dos atributos do workspace

-- Calculado na hora (barato) para que o comando de teste "clima" valha já, sem esperar o laço de 1 s.
function Ambiente.condicao(): string
	local clima = workspace:GetAttribute("Clima")
	return Som.condicao(Lighting.ClockTime, if type(clima) == "string" then clima else nil)
end

function Ambiente.db(): number
	return Som.ambiente(Ambiente.condicao())
end

local function publicar()
	local condicao = Ambiente.condicao()
	workspace:SetAttribute("Condicao", condicao)
	workspace:SetAttribute("AmbienteDb", Som.ambiente(condicao))
end

function Ambiente.iniciar()
	publicar()
	task.spawn(function()
		while true do
			task.wait(INTERVALO)
			publicar()
		end
	end)
end

return Ambiente
