-- Controles: teclas e botões de tela para agachar (alterna) e correr (segura). Só pede; o servidor decide.
-- Dono: P2. V (terceira pessoa) é da Camera e P (configurações) é da Configuracoes.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local ConfigMovimento = require(Shared:WaitForChild("Config"):WaitForChild("Movimento"))

local Controles = {}

local ACAO_AGACHAR = "AgacharJogo"
local ACAO_CORRER = "CorrerJogo"

local function teclas(nomes: { string }): { Enum.KeyCode }
	local lista = {}
	for _, nome in nomes do
		local tecla = (Enum.KeyCode :: any)[nome]
		if tecla then
			table.insert(lista, tecla)
		else
			warn("[Controles] tecla desconhecida em Config/Movimento: " .. nome)
		end
	end
	return lista
end

function Controles.iniciar()
	local jogador = Players.LocalPlayer
	local agachar = Rede.evento("Agachar")
	local correr = Rede.evento("Correr")
	local criarBotao = UserInputService.TouchEnabled

	-- Alterna pelo atributo que o servidor devolveu, não por estado local: se o pedido for recusado, não desincroniza.
	-- Toque = agacha/levanta (deitado: passa a agachado). Segurar `segurarDeitar` s = deita/levanta.
	local deitar = Rede.evento("Deitar")
	local ficha = 0
	local deitouNestaTecla = false
	local function aoAgachar(_nome: string, estado: Enum.UserInputState)
		if estado == Enum.UserInputState.Begin then
			ficha += 1
			local minha = ficha
			deitouNestaTecla = false
			task.delay(ConfigMovimento.segurarDeitar, function()
				if ficha == minha then -- ainda segurando
					deitouNestaTecla = true
					deitar:FireServer(jogador:GetAttribute("Deitado") ~= true)
				end
			end)
		elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
			ficha += 1
			if not deitouNestaTecla and estado == Enum.UserInputState.End then
				if jogador:GetAttribute("Deitado") == true then
					agachar:FireServer(true)
				else
					agachar:FireServer(jogador:GetAttribute("Agachado") ~= true)
				end
			end
		end
		return Enum.ContextActionResult.Pass
	end

	local function aoCorrer(_nome: string, estado: Enum.UserInputState)
		if estado == Enum.UserInputState.Begin then
			-- dentro do carro o Shift é o freio de mão (Direcao), não corrida
			local personagem = jogador.Character
			local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
			if humanoide and humanoide.SeatPart ~= nil then
				return Enum.ContextActionResult.Pass
			end
			correr:FireServer(true)
		elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
			correr:FireServer(false)
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction(
		ACAO_AGACHAR,
		aoAgachar,
		criarBotao,
		table.unpack(teclas(ConfigMovimento.teclas.agachar))
	)
	ContextActionService:BindAction(
		ACAO_CORRER,
		aoCorrer,
		criarBotao,
		table.unpack(teclas(ConfigMovimento.teclas.correr))
	)
	if criarBotao then
		ContextActionService:SetTitle(ACAO_AGACHAR, "Agachar")
		ContextActionService:SetTitle(ACAO_CORRER, "Correr")
	end

	-- Janela sem foco não entrega o "soltar": solta a corrida por conta própria.
	UserInputService.WindowFocusReleased:Connect(function()
		correr:FireServer(false)
	end)
end

return Controles
