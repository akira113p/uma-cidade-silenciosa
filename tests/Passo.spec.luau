local Passo = require("../src/shared/Regras/Passo")
local Som = require("../src/shared/Regras/Som")
local CfgSom = require("../src/shared/Config/Som")
local util = require("./util")

-- Estado da §8 de docs/som.md: noite, concreto, carga 5 kg, estamina cheia, sem vegetação
local function estado(modo: string, extra: any?)
	local e = { modo = modo, superficie = "concreto", carga = 5, estamina = 100, vegetacao = false }
	for k, v in extra or {} do
		(e :: any)[k] = v
	end
	return e
end

local function compor(e: any)
	return Som.compor(Passo.camadas(e, CfgSom))
end

-- 1) as bandas compostas da §8 (±0,1 dB)
local TABELA = {
	{ "andar", 34.1, 40.1, 37.3, 36 },
	{ "correr", 49.0, 55.1, 52.2, 59 },
	{ "agachado", 24.3, 30.2, 27.5, 10 },
}
for _, linha in TABELA do
	local modo = linha[1] :: string
	local c = compor(estado(modo))
	util.perto(c.bandas.grave, linha[2] :: number, modo .. " grave", 0.1)
	util.perto(c.bandas.medio, linha[3] :: number, modo .. " médio", 0.1)
	util.perto(c.bandas.agudo, linha[4] :: number, modo .. " agudo", 0.1)
	util.perto(c.chao :: number, linha[5] :: number, modo .. " chão", 0.1)
	util.igual(c.dominante, "pisada", modo .. ": a pisada domina")
end

-- 2) sem carga e descansado, o alcance de referência fica perto do de hoje (agachado 11, andar 36, correr 200 no concreto, noite):
-- a respiração soma um pouco (a §8 de docs/som.md dá 12 / 36 / ~190 com 5 kg)
local noite = Som.ambienteBandas("noite")
for _, caso in { { "agachado", 11, 2 }, { "andar", 36, 3 }, { "correr", 200, 12 } } do
	local c = compor(estado(caso[1] :: string, { carga = 0 }))
	local alcance = Som.alcanceEvento(c.bandas, c.chao, noite, nil)
	util.perto(alcance, caso[2] :: number, caso[1] .. " sem carga: alcance de referência", caso[3] :: number)
end

-- 3) camadas: nomes, perfis, carga e estamina
do
	local camadas = Passo.camadas(estado("andar", { vegetacao = true }), CfgSom)
	local nomes = {}
	for _, c in camadas do
		table.insert(nomes, c.nome)
	end
	util.igual(table.concat(nomes, ","), "pisada,equipamento,respiracao,vegetacao", "4 camadas com vegetação")
	util.igual(#Passo.camadas(estado("andar"), CfgSom), 3, "3 camadas sem vegetação")
	util.igual(
		#Passo.camadas(estado("andar", { prendendo = true }), CfgSom),
		2,
		"prendendo a respiração: a camada some"
	)
end

-- carga: 10·log10(1 + carga/cargaRef) sobre a base do modo
do
	local sem = Passo.camadas(estado("andar", { carga = 0 }), CfgSom)[2]
	local com = Passo.camadas(estado("andar", { carga = 10 }), CfgSom)[2]
	util.perto(sem.nivel, CfgSom.passo.equip.andar, "equipamento sem carga = base do modo")
	util.perto(com.nivel - sem.nivel, 3.0103, "carga = cargaRef soma +3 dB", 0.001)
	util.perto(Passo.camadas(estado("andar", { carga = -5 }), CfgSom)[2].nivel, sem.nivel, "carga negativa vale 0")
end

-- estamina: respiração sobe até respCansaco quando zerada; fora da faixa é travada
do
	local cheia = Passo.camadas(estado("correr", { estamina = 100 }), CfgSom)[3]
	local vazia = Passo.camadas(estado("correr", { estamina = 0 }), CfgSom)[3]
	util.perto(vazia.nivel - cheia.nivel, CfgSom.passo.respCansaco, "estamina 0 soma respCansaco")
	util.perto(
		Passo.camadas(estado("correr", { estamina = 250 }), CfgSom)[3].nivel,
		cheia.nivel,
		"estamina > 100 vale 100"
	)
	util.perto(Passo.camadas(estado("correr", { estamina = -9 }), CfgSom)[3].nivel, vazia.nivel, "estamina < 0 vale 0")
	-- cansado, a respiração passa a mandar no passo agachado
	local c = compor(estado("agachado", { estamina = 0, carga = 0 }))
	util.igual(c.dominante, "respiracao", "agachado exausto: a respiração domina")
end

-- 4) agachado e deitado: pisada cai e o chão quase não vibra
do
	local andar = compor(estado("andar"))
	local agachado = compor(estado("agachado"))
	local deitado = compor(estado("deitado"))
	assert(andar.db - agachado.db >= 9, "agachado: pisada -10 dB")
	assert((andar.chao :: number) - (agachado.chao :: number) >= 20, "agachado: o chão quase não vibra")
	assert((agachado.chao :: number) > (deitado.chao :: number), "deitado vibra menos que agachado")
end

-- 5) superfície: madeira vibra mais que concreto; carpete menos; desconhecida cai no padrão
do
	local concreto = compor(estado("andar"))
	local madeira = compor(estado("andar", { superficie = "madeira" }))
	local carpete = compor(estado("andar", { superficie = "carpete" }))
	util.perto((madeira.chao :: number) - (concreto.chao :: number), 3 + 6, "madeira: +3 na pisada e +6 no chão")
	assert((carpete.chao :: number) < (concreto.chao :: number), "carpete vibra menos")
	util.perto(compor(estado("andar", { superficie = "xyz" })).db, concreto.db, "superfície desconhecida = concreto")
end

-- 6) vegetação: farfalhar agudo, só soma onde há mato
do
	local sem = compor(estado("correr"))
	local com = compor(estado("correr", { vegetacao = true }))
	assert(com.bandas.agudo > sem.bandas.agudo, "mato soma no agudo")
	util.perto(com.bandas.grave, sem.bandas.grave, "mato quase não soma no grave", 0.1)
end

-- 7) ofego parado: só com estamina baixa (~32%), liga/desliga, e some enquanto prende a respiração
do
	assert(Passo.respiracaoParado(100, false, CfgSom) == nil, "descansado não ofega")
	assert(Passo.respiracaoParado(40, false, CfgSom) == nil, "estamina 40% não ofega")
	assert(Passo.respiracaoParado(30, false, CfgSom) ~= nil, "estamina 30% ofega")
	local limite = 100 * (1 - (CfgSom.respiracao.minimo - CfgSom.passo.resp.parado) / CfgSom.passo.respCansaco)
	util.perto(limite, 31.8, "limiar de estamina do ofego ~32%", 0.1)
	assert(Passo.respiracaoParado(0, true, CfgSom) == nil, "prendendo: não ofega")
	local camada = Passo.respiracaoParado(0, false, CfgSom) :: any
	util.perto(camada.nivel, CfgSom.passo.resp.parado + CfgSom.passo.respCansaco, "ofego com estamina 0")
	util.igual(camada.chao, nil, "ofego não toca o chão")
	local desligado = table.clone(CfgSom)
	desligado.respiracao = { ligado = false, intervalo = 2, minimo = 25 }
	assert(Passo.respiracaoParado(0, false, desligado) == nil, "interruptor desligado")
end

-- 8) aterrissagem: cair de 12 studs soma +6 dB no nível e no chão; perfil {0, 0, -6}
do
	local a3 = Passo.aterrissagem(3, "concreto", CfgSom)
	local a12 = Passo.aterrissagem(12, "concreto", CfgSom)
	util.perto(a3.nivel, CfgSom.acoes.aterrissar, "altura de referência: nível base")
	util.perto(a12.nivel - a3.nivel, 6.0206, "12 studs = +6 dB", 0.001)
	util.perto((a12.chao :: number) - (a3.chao :: number), 6.0206, "12 studs: +6 dB no chão", 0.001)
	util.perto(a3.chao :: number, CfgSom.aterrissagem.chaoBase, "chão = chaoBase + superfície.chao (concreto 0)")
	util.perto(
		Passo.aterrissagem(3, "madeira", CfgSom).chao :: number,
		CfgSom.aterrissagem.chaoBase + 6,
		"madeira +6 no chão"
	)
	util.igual(a12.perfil.agudo, -6, "perfil: agudo -6")
	util.igual(a12.perfil.grave, 0, "perfil: grave 0")
	util.perto(Passo.aterrissagem(1, "concreto", CfgSom).nivel, a3.nivel, "altura abaixo da referência não reduz")
end

print("Passo.spec ok")
