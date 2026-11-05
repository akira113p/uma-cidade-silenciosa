local util = require("./util")
local Loot = require("../src/shared/Regras/Loot")
local Itens = require("../src/shared/Config/Itens")
local Casa = require("../src/shared/Config/Compartimentos/Casa")
local Comercial = require("../src/shared/Config/Compartimentos/Comercial")
local TAM = require("../ferramentas/mapa/mobilia_tamanhos")

-- Dados de Config/Compartimentos (contrato: docs/compartimentos.md). O init.luau usa `script:WaitForChild`,
-- que não existe no Lune; por isso Casa e Comercial são carregados direto e juntados do mesmo jeito.
local tabelas: { [string]: any } = {}
local moveis: { [string]: any } = {}
for _, parte in { Casa, Comercial } do
	for nome, tabela in parte.tabelas do
		assert(tabelas[nome] == nil, "categoria repetida: " .. nome)
		tabelas[nome] = tabela
	end
	for nome, movel in parte.moveis do
		assert(moveis[nome] == nil, "móvel repetido: " .. nome)
		moveis[nome] = movel
	end
end

-- (a) e (b): ids existem; peso > 0; qtd e rolagens em {min, max} com os limites certos
for categoria, t in tabelas do
	assert(type(t.rolagens) == "table" and #t.rolagens == 2, categoria .. ": rolagens precisa ser {min, max}")
	local rmin, rmax = t.rolagens[1], t.rolagens[2]
	assert(rmin >= 0 and rmin <= rmax, categoria .. ": rolagens fora de 0 <= min <= max")
	for _, e in t.itens do
		assert(Itens.itens[e.id] ~= nil, categoria .. ": id inexistente " .. tostring(e.id))
		assert(e.peso > 0, categoria .. ": peso não positivo em " .. e.id)
		assert(type(e.qtd) == "table" and #e.qtd == 2, categoria .. ": qtd precisa ser {min, max} em " .. e.id)
		assert(e.qtd[1] >= 1 and e.qtd[1] <= e.qtd[2], categoria .. ": qtd fora de 1 <= min <= max em " .. e.id)
	end
end

-- (c) e (d): categoria existe; chance em 0..1; nome não vazio; nome do móvel existe em mobilia_tamanhos
for nome, movel in moveis do
	assert(tabelas[movel.categoria] ~= nil, nome .. ": categoria inexistente " .. tostring(movel.categoria))
	assert(type(movel.chance) == "number" and movel.chance >= 0 and movel.chance <= 1, nome .. ": chance fora de 0..1")
	assert(type(movel.nome) == "string" and movel.nome ~= "", nome .. ": nome vazio")
	assert(TAM[nome] ~= nil, nome .. ": móvel inexistente em ferramentas/mapa/mobilia_tamanhos.luau")
end

local ARMAS = { faca = true, peDeCabra = true, machado = true, pistola = true, municaoPistola = true }

local function fracaoArma(tabela)
	local total, arma = 0, 0
	for _, e in tabela.itens do
		total += e.peso
		if ARMAS[e.id] then
			arma += e.peso
		end
	end
	return if total > 0 then arma / total else 0
end

-- (e): quarto > banheiro em arma; comida sem arma nenhuma. Se a categoria não existir, pula com aviso.
local faltam = {}
for _, categoria in { "quarto_casa", "banheiro_casa", "comida_casa" } do
	if tabelas[categoria] == nil then
		table.insert(faltam, categoria)
	end
end
if #faltam > 0 then
	print(
		"(e) PULADO: categoria(s) não existem em Compartimentos: " .. table.concat(faltam, ", ") .. " (o Opus ajusta)"
	)
else
	local quarto, banheiro = fracaoArma(tabelas.quarto_casa), fracaoArma(tabelas.banheiro_casa)
	assert(
		quarto > banheiro,
		string.format("quarto_casa (%.3f) deveria ter mais arma que banheiro_casa (%.3f)", quarto, banheiro)
	)
	assert(fracaoArma(tabelas.comida_casa) == 0, "comida_casa não deveria ter arma")
end

-- (f): simulação com rng fixo, mesma semente nas duas categorias
local function unidadesDeArma(categoria: string, sorteios: number): number
	local rng = util.rng(2024)
	local total = 0
	for _ = 1, sorteios do
		for _, item in Loot.sortear(tabelas[categoria], rng) do
			if ARMAS[item.id] then
				total += item.qtd
			end
		end
	end
	return total
end

if tabelas.quarto_casa == nil or tabelas.banheiro_casa == nil then
	print("(f) PULADO: falta quarto_casa ou banheiro_casa em Compartimentos (o Opus ajusta)")
else
	local armasQuarto = unidadesDeArma("quarto_casa", 2000)
	local armasBanheiro = unidadesDeArma("banheiro_casa", 2000)
	assert(
		armasQuarto > armasBanheiro,
		string.format("2000 sorteios: quarto deu %d armas, banheiro deu %d", armasQuarto, armasBanheiro)
	)
end

print("Compartimentos.spec ok")
