-- Comandos de teste, só no Studio: ServerStorage.Teste:Invoke("nome", jogadorOuNil, ...) pelo execute_luau (Server).
-- Cada serviço registra os seus no próprio iniciar(). Fora do Studio, registrar() não faz nada.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Teste = {}

local comandos: { [string]: (Player, ...any) -> any } = {}

function Teste.registrar(nome: string, fn: (Player, ...any) -> any)
	if not RunService:IsStudio() then
		return
	end
	if comandos[nome] then
		warn("[Teste] comando repetido: " .. nome)
	end
	comandos[nome] = fn
end

function Teste.iniciar()
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "Teste"
	-- jogador nil = primeiro jogador do servidor
	f.OnInvoke = function(nome: string, jogador: Player?, ...)
		if nome == "lista" then
			local nomes = {}
			for n in comandos do
				table.insert(nomes, n)
			end
			table.sort(nomes)
			return table.concat(nomes, ", ")
		end
		local fn = comandos[nome]
		if not fn then
			return "comando desconhecido: " .. tostring(nome)
		end
		local alvo = jogador or Players:GetPlayers()[1]
		return fn(alvo, ...)
	end
	f.Parent = ServerStorage
end

return Teste
