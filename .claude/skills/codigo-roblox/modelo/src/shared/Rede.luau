--!strict
-- Toda mensagem cliente<->servidor é declarada AQUI. Nenhum outro arquivo cria RemoteEvent/RemoteFunction.
-- O servidor valida tudo que chega (tipo, faixa, estado do jogador): o cliente não é confiável.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTOS: { string } = {
	-- "ComprarUpgrade",
}

local Rede = {}

local function pasta(): Instance
	if RunService:IsServer() then
		local existente = ReplicatedStorage:FindFirstChild("Rede")
		if existente then
			return existente
		end
		local nova = Instance.new("Folder")
		nova.Name = "Rede"
		nova.Parent = ReplicatedStorage
		return nova
	end
	return ReplicatedStorage:WaitForChild("Rede")
end

function Rede.evento(nome: string): RemoteEvent
	assert(table.find(EVENTOS, nome), "Rede: evento não declarado em Rede.luau: " .. nome)
	local raiz = pasta()
	local existente = raiz:FindFirstChild(nome)
	if existente and existente:IsA("RemoteEvent") then
		return existente
	end
	if RunService:IsServer() then
		local novo = Instance.new("RemoteEvent")
		novo.Name = nome
		novo.Parent = raiz
		return novo
	end
	return raiz:WaitForChild(nome) :: RemoteEvent
end

-- Servidor chama no início para criar todos os eventos antes de os clientes pedirem.
function Rede.criarTodos()
	assert(RunService:IsServer(), "Rede.criarTodos só no servidor")
	for _, nome in EVENTOS do
		Rede.evento(nome)
	end
end

return Rede
