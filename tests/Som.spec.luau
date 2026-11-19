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

-- 9) som v2 (docs/som.md): soma de energia, compor, propagação por banda, chão, ambiente por banda, alcance
util.perto(Som.somar({ 50, 50 }), 53.0103, "duas camadas iguais somam +3 dB", 0.001)
util.perto(Som.somar({ 50, 40 }), 50.4139, "uma camada 10 dB abaixo soma +0,4 dB", 0.001)
util.perto(Som.somar({ 42 }), 42, "uma camada só")
assert(Som.somar({}) == -math.huge, "sem camadas = -inf")

local composto = Som.compor({
	{ nome = "a", nivel = 50, perfil = { grave = -10, medio = 0, agudo = -5 }, chao = 30 },
	{ nome = "b", nivel = 50, perfil = { grave = 0, medio = -10, agudo = -5 } },
	{ nome = "c", nivel = 40, perfil = { grave = 0, medio = 0, agudo = 0 }, chao = 30 },
})
util.perto(composto.bandas.grave, Som.somar({ 40, 50, 40 }), "compor: grave")
util.perto(composto.bandas.medio, Som.somar({ 50, 40, 40 }), "compor: médio")
util.perto(composto.bandas.agudo, Som.somar({ 45, 45, 40 }), "compor: agudo")
util.perto(composto.chao :: number, 33.0103, "compor: chão soma só as camadas com chão", 0.001)
util.perto(
	composto.db,
	math.max(composto.bandas.grave, composto.bandas.medio, composto.bandas.agudo),
	"compor: db = max das bandas"
)
util.igual(composto.dominante, "a", "compor: dominante = camada de maior pico (empate fica com a primeira)")
util.igual(
	Som.compor({ { nivel = 40, perfil = { grave = 0, medio = 0, agudo = 0 } } }).chao,
	nil,
	"compor: nenhuma camada com chão = nil"
)

-- propagação pelo ar, por banda: 1 m sem perda; o grave não tem absorção; paredes por banda (6/10/14), no máximo 3
util.perto(Som.propagarAr(60, "grave", 1 / CfgSom.metrosPorStud, 0), 60, "grave a 1 m")
util.perto(Som.propagarAr(60, "grave", 100, 0), 60 - 20 * math.log(28, 10), "grave sem absorção a 28 m")
util.perto(Som.propagarAr(60, "medio", 100, 0), 60 - 20 * math.log(28, 10) - 0.01 * 28, "médio absorve 0,01 dB/m")
util.perto(Som.propagarAr(60, "agudo", 100, 0), 60 - 20 * math.log(28, 10) - 0.03 * 28, "agudo absorve 0,03 dB/m")
for banda, perda in { grave = 6, medio = 10, agudo = 14 } do
	local livre = Som.propagarAr(70, banda, 50, 0)
	util.perto(Som.propagarAr(70, banda, 50, 1), livre - perda, banda .. ": 1 parede")
	util.perto(Som.propagarAr(70, banda, 50, 2), livre - 2 * perda, banda .. ": 2 paredes")
	util.perto(Som.propagarAr(70, banda, 50, 3), livre - 3 * perda, banda .. ": 3 paredes")
	util.perto(Som.propagarAr(70, banda, 50, 9), livre - 3 * perda, banda .. ": 9 paredes valem 3")
end

-- pelo chão: 12 dB por dobro de distância, outro andar tira 20 dB, parede não entra
util.perto(Som.propagarChao(50, 1 / CfgSom.metrosPorStud, 0), 50, "chão a 1 m")
util.perto(Som.propagarChao(50, 100, 0), 50 - 40 * math.log(28, 10), "chão a 28 m")
util.perto(
	Som.propagarChao(50, 50, 0) - Som.propagarChao(50, 100, 0),
	12.0412,
	"chão: dobro da distância = -12 dB",
	0.001
)
util.perto(
	Som.propagarChao(50, 50, 10),
	Som.propagarChao(50, 50, 0),
	"chão: 10 studs de desnível ainda é o mesmo piso"
)
util.perto(Som.propagarChao(50, 50, -10.5), Som.propagarChao(50, 50, 0) - 20, "chão: outro andar tira 20 dB")

-- ambiente por banda
local ESPERADO_AMBIENTE = {
	noite = { 20, 20, 18, 0 },
	dia = { 25, 25, 22, 2 },
	chuva = { 32, 40, 44, 2 },
	tempestade = { 50, 55, 55, 8 },
}
for condicao, esperado in ESPERADO_AMBIENTE do
	local a = Som.ambienteBandas(condicao)
	util.igual(a.grave, esperado[1], condicao .. " grave")
	util.igual(a.medio, esperado[2], condicao .. " médio")
	util.igual(a.agudo, esperado[3], condicao .. " agudo")
	util.igual(a.chao, esperado[4], condicao .. " chão")
	util.igual(Som.ambiente(condicao), a.medio, condicao .. ": ambiente (número único) = banda do meio")
end
util.igual(Som.ambienteBandas("inexistente").medio, 25, "ambiente por banda desconhecido cai no dia")

-- alcance de evento: a banda sem absorção (grave) bate com o alcance v1; limiar e chão entram; teto de 600
do
	local plano = { grave = 60, medio = 60, agudo = 60 }
	local amb = { grave = 20, medio = 20, agudo = 20, chao = 0 }
	local alcance, banda = Som.alcanceEvento(plano, nil, amb, nil)
	util.perto(alcance, Som.alcance(60, 20, 0), "alcanceEvento plano = alcance v1 (grave não absorve)", 0.05)
	util.igual(banda, "grave", "empate entre bandas: a que não absorve vence")
	local com6 = Som.alcanceEvento(plano, nil, amb, { grave = 6, medio = 6, agudo = 6 })
	util.perto(com6, Som.alcance(60, 20, 6), "alcanceEvento com limiar 6", 0.05)
	util.igual((Som.alcanceEvento({ grave = 10, medio = 10, agudo = 10 }, nil, amb, nil)), 0, "abaixo do ambiente = 0")
	local forte = Som.alcanceEvento({ grave = 130, medio = 130, agudo = 130 }, nil, amb, nil)
	util.igual(forte, CfgSom.tetoAlcance, "teto")
	-- só o chão: o ouvinte de referência (sem chão) não ouve; quem sente o chão ouve
	local soChao = { grave = 0, medio = 0, agudo = 0 }
	util.igual((Som.alcanceEvento(soChao, 50, amb, nil)), 0, "referência não sente o chão")
	local a2, b2 = Som.alcanceEvento(soChao, 50, amb, { grave = 0, medio = 0, agudo = 0, chao = 4 })
	util.perto(a2, 10 ^ ((50 - 0 - 4) / 40) / CfgSom.metrosPorStud, "alcance pelo chão: 40·log10(m)", 0.05)
	util.igual(b2, "chao", "banda que vence = chão")
end

-- modo de passo com deitado (4º argumento opcional; deitado vence agachado)
util.igual(Som.modoPasso(3, true, false, true), "deitado", "deitado")
util.igual(Som.modoPasso(3, true, true, true), "deitado", "deitado vence agachado e correr")
util.igual(Som.modoPasso(0, true, false, true), "parado", "deitado parado")
util.igual(Som.modoPasso(3, true, false, false), "agachado", "deitado=false não muda nada")

-- bandas de uma ação de número único (Ruido.emitir): tipo sem entrada = plano, sem chão
do
	local b, c = Som.bandasDeAcao(110, "pistola")
	util.igual(b.grave, 108, "pistola: grave -2")
	util.igual(b.medio, 110, "pistola: médio")
	util.igual(c, nil, "pistola não toca o chão")
	local b2, c2 = Som.bandasDeAcao(80, "carro")
	util.igual(b2.agudo, 70, "carro: agudo -10")
	util.igual(c2, 70, "carro: chão -10")
	local b3, c3 = Som.bandasDeAcao(50, "tipoQueNaoExiste")
	util.igual(b3.grave, 50, "plano: grave")
	util.igual(b3.agudo, 50, "plano: agudo")
	util.igual(c3, nil, "plano: sem chão")
end

-- item caindo: 12 studs = +6 dB; abaixo de 3 studs não soma; classe desconhecida cai em padrão
do
	local n12 = Som.nivelQueda("metal", 12)
	util.perto(n12, CfgSom.queda.classes.metal.nivel + 6.0206, "queda de 12 studs", 0.001)
	util.igual(Som.nivelQueda("metal", 1), CfgSom.queda.classes.metal.nivel, "queda baixa não soma")
	util.igual(Som.nivelQueda("xyz", 3), CfgSom.queda.classes.padrao.nivel, "classe desconhecida = padrão")
end

-- rótulo do HUD
util.igual(Som.chaveRotulo("passo", "equipamento", CfgSom.medidor.rotulos), "equipamento", "rótulo pelo dominante")
util.igual(
	Som.chaveRotulo("esbarrao", "madeiraLeve", CfgSom.medidor.rotulos),
	"esbarrao",
	"rótulo pelo tipo quando o dominante não tem"
)
util.igual(Som.chaveRotulo("tiro", nil, CfgSom.medidor.rotulos), nil, "sem rótulo")

-- Config: todo perfil é ≤ 0 com a banda mais forte em 0; todo som de detrito/esbarrão/queda existe no catálogo
local function conferirPerfil(p: any, nome: string)
	util.igual(math.max(p.grave, p.medio, p.agudo), 0, nome .. ": a banda mais forte vale 0")
	assert(math.min(p.grave, p.medio, p.agudo) <= 0, nome .. ": offsets <= 0")
end
for nome, def in CfgSom.superficies do
	conferirPerfil((def :: any).perfil, "superfície " .. nome)
end
for nome, def in CfgSom.perfisAcao do
	conferirPerfil(def.perfil, "ação " .. nome)
end
for nome, def in CfgSom.detritos.tipos do
	conferirPerfil(def.perfil, "detrito " .. nome)
	assert(Sons[def.som] ~= nil, "catálogo sem o som " .. def.som)
	if def.rolar then
		assert(Sons[def.rolar.som] ~= nil, "catálogo sem o som " .. def.rolar.som)
	end
	for _, modo in { "deitado", "agachado", "andar", "correr" } do
		assert(type(def.nivel[modo]) == "number", "detrito " .. nome .. " sem nível em " .. modo)
	end
end
for nome, def in CfgSom.esbarrar.classes do
	conferirPerfil(def.perfil, "esbarrão " .. nome)
	assert(Sons[def.som] ~= nil, "catálogo sem o som " .. def.som)
end
for nome, def in CfgSom.queda.classes do
	conferirPerfil(def.perfil, "queda " .. nome)
end
conferirPerfil(CfgSom.passo.equipamento.perfil, "equipamento")
conferirPerfil(CfgSom.passo.respiracaoPerfil, "respiração")
conferirPerfil(CfgSom.passo.vegetacaoPerfil, "vegetação")
for _, nome in { "Arfar", "Coracao", "SoltarAr" } do
	assert(Sons[nome] ~= nil, "catálogo sem o som " .. nome)
end
-- as bases de pisada são as de hoje (acoes), para o alcance de referência não mudar
for _, modo in { "agachado", "andar", "correr" } do
	util.igual(CfgSom.passo.pisada[modo], CfgSom.acoes[modo], "pisada = acoes." .. modo)
end
for nome, def in CfgSom.perfisAcao do
	assert(def.chao == nil or type(def.chao) == "number", "perfil de ação com chão inválido: " .. nome)
end

-- Itens: todo item tem peso (kg) positivo e, se tiver, classeQueda existente; os pesos de referência da §4.3
local Itens = require("../src/shared/Config/Itens")
for id, def in Itens.itens do
	assert(type((def :: any).peso) == "number" and (def :: any).peso > 0, "item sem peso: " .. id)
	local classe = (def :: any).classeQueda
	assert(classe == nil or CfgSom.queda.classes[classe] ~= nil, "classeQueda inexistente em " .. id)
	if (def :: any).tipo and CfgSom.queda.porTipo[(def :: any).tipo] then
		assert(
			CfgSom.queda.classes[CfgSom.queda.porTipo[(def :: any).tipo]] ~= nil,
			"porTipo aponta classe inexistente"
		)
	end
end
util.igual(Itens.itens.enlatado.peso, 0.4, "peso: comida 0,4")
util.igual(Itens.itens.bandagem.peso, 0.1, "peso: bandagem 0,1")
util.igual(Itens.itens.kit.peso, 1, "peso: kit 1")
util.igual(Itens.itens.peDeCabra.peso, 2, "peso: pé de cabra 2")
util.igual(Itens.itens.galaoGasolina.peso, 4, "peso: galão cheio 4")
util.igual(Itens.itens.garrafaGasolina.peso, 1, "peso: garrafa cheia 1")
util.igual(Itens.itens.municaoRifle.peso, 0.02, "peso: munição 0,02 por unidade")

-- detritos: repartição por zona soma 1; todo tipo pode nascer em alguma zona ou dentro de madeira
do
	local soma = 0
	for _, fracao in CfgSom.detritos.partilha do
		soma += fracao
	end
	util.perto(soma, 1, "partilha dos detritos soma 1")
	for nome, def in CfgSom.detritos.tipos do
		local peso = def.interiorMadeira or 0
		for _, p in def.zonas do
			peso += p
		end
		assert(peso > 0, "detrito que não nasce em lugar nenhum: " .. nome)
	end
	util.igual(CfgSom.detritos.total, 5000, "detritos.total")
end

print("Som.spec ok")
