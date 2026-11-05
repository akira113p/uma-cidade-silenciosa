local Som = require("../src/shared/Regras/Som")
local CfgSom = require("../src/shared/Config/Som")
local Sons = require("../src/shared/Config/Sons")
local util = require("./util")

-- Colunas da tabela 1.4 de docs/calculos.md: Noite N1, Noite N2, Noite N3, Dia N1, Chuva N1, Tempestade N1
local COLUNAS = {
	{ condicao = "noite", margem = 0 },
	{ condicao = "noite", margem = 6 },
	{ condicao = "noite", margem = 12 },
	{ condicao = "dia", margem = 0 },
	{ condicao = "chuva", margem = 0 },
	{ condicao = "tempestade", margem = 0 },
}

-- { ação, superfície, dB da tabela, alcance esperado por coluna }
local TABELA = {
	{ "agachado", "carpete", 22, { 4, 0, 0, 0, 0, 0 } },
	{ "agachado", "gramaBaixa", 25, { 6, 0, 0, 0, 0, 0 } },
	{ "agachado", "concreto", 30, { 11, 6, 0, 6, 0, 0 } },
	{ "agachado", "gramaAlta", 35, { 20, 10, 5, 11, 0, 0 } },
	{ "agachado", "metal", 38, { 28, 14, 7, 16, 0, 0 } },
	{ "andar", "carpete", 32, { 14, 7, 0, 8, 0, 0 } },
	{ "andar", "gramaBaixa", 35, { 20, 10, 5, 11, 0, 0 } },
	{ "andar", "concreto", 40, { 36, 18, 9, 20, 0, 0 } },
	{ "andar", "gramaAlta", 45, { 64, 32, 16, 36, 6, 0 } },
	{ "andar", "metal", 48, { 90, 45, 23, 50, 9, 0 } },
	{ "correr", "gramaBaixa", 50, { 113, 57, 28, 64, 11, 0 } },
	{ "correr", "concreto", 55, { 201, 101, 50, 113, 20, 0 } },
	{ "correr", "gramaAlta", 60, { 357, 179, 90, 201, 36, 6 } },
	{ "correr", "metal", 63, { 504, 253, 127, 284, 50, 9 } },
	{ "porta", nil, 45, { 64, 32, 16, 36, 6, 0 } },
	{ "golpe", nil, 55, { 201, 101, 50, 113, 20, 0 } },
	{ "vidro", nil, 75, { 600, 600, 504, 600, 201, 36 } },
	{ "carro", nil, 80, { 600, 600, 600, 600, 357, 64 } },
	{ "pistola", nil, 110, { 600, 600, 600, 600, 600, 600 } },
	{ "fuzil", nil, 120, { 600, 600, 600, 600, 600, 600 } },
}

-- 1) cada linha da tabela 1.4: dB emitido e alcance em cada coluna (±1 stud; 0 tem de ser exatamente 0)
local celulas = 0
for _, linha in TABELA do
	local acao, superficie, dbEsperado, alcances = linha[1], linha[2], linha[3], linha[4]
	local nome = acao .. "/" .. tostring(superficie)
	local db = Som.emitido(acao, superficie)
	util.igual(db, dbEsperado, nome .. " dB")
	for i, coluna in COLUNAS do
		local ambiente = Som.ambiente(coluna.condicao)
		local alcance = Som.alcance(db, ambiente, coluna.margem)
		local esperado = alcances[i]
		local rotulo = string.format("%s %s margem %d", nome, coluna.condicao, coluna.margem)
		if esperado == 0 then
			util.igual(alcance, 0, rotulo .. " (inaudível)")
		else
			util.perto(alcance, esperado, rotulo, 1)
		end
		celulas += 1
	end
end
print(string.format("tabela 1.4: %d linhas, %d células conferidas", #TABELA, celulas))

-- 2) ambiente por condição
util.igual(Som.ambiente("noite"), 20, "ambiente noite")
util.igual(Som.ambiente("dia"), 25, "ambiente dia")
util.igual(Som.ambiente("chuva"), 40, "ambiente chuva")
util.igual(Som.ambiente("tempestade"), 55, "ambiente tempestade")
util.igual(Som.ambiente("inexistente"), 25, "condição desconhecida cai no dia")

-- 3) recebido: inverso do quadrado, 1 m mínimo, paredes
util.perto(Som.recebido(60, 0, 0), 60, "distância 0 vale 1 m")
util.perto(Som.recebido(60, 3, 0), 60, "0,84 m vale 1 m")
util.perto(Som.recebido(60, 1 / CfgSom.metrosPorStud, 0), 60, "1 m exato")
util.perto(Som.recebido(60, 2 / CfgSom.metrosPorStud, 0), 60 - 20 * math.log(2, 10), "2 m")
util.perto(Som.recebido(60, 20 / CfgSom.metrosPorStud, 0), 60 - 20 * math.log(20, 10), "20 m")
-- dobrar a distância cai ~6 dB
local d1 = Som.recebido(70, 50, 0)
local d2 = Som.recebido(70, 100, 0)
util.perto(d1 - d2, 6.0206, "dobro da distância = -6 dB", 0.001)
-- paredes: -10 dB cada, máximo 3
local sem = Som.recebido(70, 100, 0)
util.perto(Som.recebido(70, 100, 1), sem - 10, "1 parede")
util.perto(Som.recebido(70, 100, 2), sem - 20, "2 paredes")
util.perto(Som.recebido(70, 100, 3), sem - 30, "3 paredes")
util.perto(Som.recebido(70, 100, 4), sem - 30, "4 paredes valem 3")
util.perto(Som.recebido(70, 100, 99), sem - 30, "99 paredes valem 3")
util.perto(Som.recebido(70, 100, -2), sem, "paredes negativas valem 0")

-- 4) recebido, excesso e alcance concordam: na borda do alcance o excesso é ~0
for _, caso in { { 55, 20, 0 }, { 63, 20, 6 }, { 60, 40, 0 }, { 45, 20, 12 } } do
	local emitido, ambiente, margem = caso[1], caso[2], caso[3]
	local alcance = Som.alcance(emitido, ambiente, margem)
	local excesso = Som.excesso(Som.recebido(emitido, alcance, 0), ambiente, margem)
	util.perto(
		excesso,
		0,
		string.format("excesso na borda (%d dB, amb %d, margem %d)", emitido, ambiente, margem),
		0.01
	)
	assert(Som.excesso(Som.recebido(emitido, alcance * 0.9, 0), ambiente, margem) > 0, "dentro do alcance ouve")
	assert(Som.excesso(Som.recebido(emitido, alcance * 1.1, 0), ambiente, margem) < 0, "fora do alcance não ouve")
end
-- uma parede encurta o alcance: 55 dB a 100 studs (28 m) chega com 26 dB; ambiente da noite é 20
assert(Som.excesso(Som.recebido(55, 100, 0), 20, 0) > 0, "100 studs, sem parede: ouve")
assert(Som.excesso(Som.recebido(55, 100, 1), 20, 0) < 0, "100 studs, 1 parede: não ouve")
assert(Som.excesso(Som.recebido(55, 100, 2), 20, 0) < 0, "100 studs, 2 paredes: não ouve")
-- 110 dB (tiro): com 3 paredes a 400 studs ainda passa (110 - 41 - 30 = 39 > 20)
assert(Som.excesso(Som.recebido(110, 400, 3), 20, 0) > 0, "tiro atravessa 3 paredes")
util.igual(Som.alcance(10, 20, 0), 0, "emitido abaixo do ambiente = 0")
util.igual(Som.alcance(120, 20, 0), CfgSom.tetoAlcance, "teto de 600")

-- 5) condição pelo relógio e pelo clima
util.igual(Som.condicao(12, nil), "dia", "meio-dia")
util.igual(Som.condicao(6, nil), "dia", "6h já é dia")
util.igual(Som.condicao(5.99, nil), "noite", "5h59 é noite")
util.igual(Som.condicao(18.99, nil), "dia", "18h59 é dia")
util.igual(Som.condicao(19, nil), "noite", "19h é noite")
util.igual(Som.condicao(23, "limpo"), "noite", "clima limpo não muda")
util.igual(Som.condicao(23, "chuva"), "chuva", "chuva à noite")
util.igual(Som.condicao(12, "tempestade"), "tempestade", "tempestade de dia")

-- 6) modo de passo
util.igual(Som.modoPasso(0, false, false), "parado", "parado")
util.igual(Som.modoPasso(1.4, false, true), "parado", "abaixo da velocidade mínima não é passo")
util.igual(Som.modoPasso(8, true, false), "agachado", "agachado")
util.igual(Som.modoPasso(16, false, false), "andar", "andar")
util.igual(Som.modoPasso(24, false, true), "correr", "correr")
util.igual(Som.modoPasso(24, true, true), "agachado", "agachado vence correr")

-- 7) voz: 20·log10(rms) + 90, clamp 0..120
util.perto(Som.vozParaDb(1), 90, "rms 1")
util.perto(Som.vozParaDb(0.1), 70, "rms 0,1")
util.perto(Som.vozParaDb(0.01), 50, "rms 0,01")
util.igual(Som.vozParaDb(0), 0, "rms 0")
util.igual(Som.vozParaDb(-1), 0, "rms negativo")
util.igual(Som.vozParaDb(0 / 0), 0, "rms NaN")
util.igual(Som.vozParaDb(1e-9), 0, "rms minúsculo trava em 0")
util.igual(Som.vozParaDb(1000), 120, "rms enorme trava em 120")

-- 8) superfícies: todo material do Config cai na superfície certa; desconhecido = padrão; todo passo existe no catálogo
for nomeSuperficie, def in CfgSom.superficies do
	for _, material in def.materiais do
		util.igual(Som.superficieDeMaterial(material), nomeSuperficie, "material " .. material)
	end
	local som = Som.nomePasso(nomeSuperficie)
	assert(Sons[som] ~= nil, "catálogo sem o som " .. som)
end
util.igual(Som.superficieDeMaterial("Air"), "concreto", "Air cai no padrão")
util.igual(Som.superficieDeMaterial("Xyz"), "concreto", "desconhecido cai no padrão")
util.igual(Som.nomePasso("carpete"), "PassoCarpete", "nome do passo carpete")
util.igual(Som.nomePasso("gramaBaixa"), "PassoGramaBaixa", "nome do passo gramaBaixa")
util.igual(Som.emitido("andar", "superficieInexistente"), 40, "superfície desconhecida usa a padrão (0 dB)")
-- toda ação do Config tem base numérica e as ações de passo têm ritmo
for acao, db in CfgSom.acoes do
	assert(type(db) == "number", "ação sem dB: " .. acao)
end
for _, modo in { "agachado", "andar", "correr" } do
	assert(CfgSom.passosPorSegundo[modo] > 0, "sem ritmo de passo: " .. modo)
end

print("Som.spec ok")
