-- Início do servidor: cria a rede e inicia cada serviço na ordem de docs/arquitetura.md §2.
-- Erro de um serviço é impresso e os outros continuam (as partes são escritas em paralelo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rede = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rede"))
Rede.criarTodos()
local Versao = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Versao"))
print("[Versao] servidor build " .. Versao.build .. " (" .. Versao.nota .. ")")

local ORDEM = {
	"Teste",
	"Sons",
	"Ambiente",
	"Visual",
	"Rios",
	"Ruido",
	"Preferencias",
	"Movimento",
	"Vida",
	"Sobrevivencia",
	"Inventario",
	"ItensChao",
	"Spawn",
	"Loot",
	"Veiculos",
	"Combustivel", -- depois de Veiculos e Inventario (usa Veiculos.encher e Inventario.trocar)
	"Destruicao",
	"Portas", -- depois de Destruicao (ouve aoQuebrar); monta as portas em segundo plano
	"Monstros",
	"Armas",
	"ArmasGB", -- moldes do viewmodel do Gold Bright (LoadAsset -> ReplicatedStorage.ArmasGB)
	"Foguete",
	"Lanterna",
	"LanternaPeito", -- carrega o modelo da lanterna de peito (Config/LanternaMalha)
	"Admin",
	"Aparencia",
	"Personagem", -- por último: depois de Spawn (RespawnLocation pronto) e Aparencia (ouve o CharacterAdded); o 1º LoadCharacter só vem do pedido do jogador
}

local modulos = {}
for _, nome in ORDEM do
	local arquivo = script:FindFirstChild(nome)
	if not arquivo then
		warn("[init] serviço ausente: " .. nome)
		continue
	end
	local ok, modulo = pcall(require, arquivo)
	if ok then
		modulos[nome] = modulo
	else
		warn("[init] erro ao carregar " .. nome .. ": " .. tostring(modulo))
	end
end

for _, nome in ORDEM do
	local modulo = modulos[nome]
	if modulo and modulo.iniciar then
		local ok, erro = pcall(modulo.iniciar)
		if not ok then
			warn("[init] erro ao iniciar " .. nome .. ": " .. tostring(erro))
		end
	end
end

local Limite = require(script.Limite)
game:GetService("Players").PlayerRemoving:Connect(Limite.limpar)
