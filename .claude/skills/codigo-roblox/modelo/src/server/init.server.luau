--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movimento = require(Shared:WaitForChild("Config"):WaitForChild("Movimento"))
local Rede = require(Shared:WaitForChild("Rede"))

-- Uma fonte só para o movimento: o mesmo Config que o checker de mapa lê.
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterWalkSpeed = Movimento.velocidade
StarterPlayer.CharacterJumpHeight = Movimento.alturaPulo

Rede.criarTodos()

print("[Server] pronto")
