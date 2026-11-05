-- Móveis do mapa que guardam loot, por categoria. Contrato: docs/compartimentos.md. Junta Casa e Comercial.
local Casa = require(script:WaitForChild("Casa"))
local Comercial = require(script:WaitForChild("Comercial"))

local tabelas: { [string]: any } = {}
local moveis: { [string]: any } = {}

for _, parte in { Casa, Comercial } do
	for nome, tabela in parte.tabelas do
		assert(tabelas[nome] == nil, "[Compartimentos] categoria repetida: " .. nome)
		tabelas[nome] = tabela
	end
	for nome, movel in parte.moveis do
		assert(moveis[nome] == nil, "[Compartimentos] móvel repetido: " .. nome)
		moveis[nome] = movel
	end
end

return { tabelas = tabelas, moveis = moveis }
