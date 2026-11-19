local Audicao = require("../src/shared/Regras/Audicao")
local Passo = require("../src/shared/Regras/Passo")
local Som = require("../src/shared/Regras/Som")
local CfgSom = require("../src/shared/Config/Som")
local CfgMonstros = require("../src/shared/Config/Monstros")
local Presets = require("../src/shared/Config/PresetsMonstro")
local util = require("./util")

-- Evento de passo da §8: noite, concreto, carga 5 kg, estamina cheia, sem parede
local noite = Som.ambienteBandas("noite")
local function passo(modo: string)
	local c = Som.compor(Passo.camadas({
		modo = modo,
		superficie = "concreto",
		carga = 5,
		estamina = 100,
		vegetacao = false,
	}, CfgSom))
	return { bandas = c.bandas, chao = c.chao, ambienteBandas = noite, modo = modo, tipo = "passo" }
end

local function alcance(ev: any, especie: string, nivel: number, paredes: number?, extra: any?, via: string?): number
	return Audicao.alcance(ev, Audicao.perfil(especie, nivel), paredes or 0, 0, 0, extra, via)
end

-- 1) a tabela de alcances da §8 (±1 stud; os valores com ~ dependem da absorção: ±2)
-- { agachado, andar, correr, tolerância do correr }
local ESPERADO = {
	Rastejador = { 9, 29, 153, 2 },
	Wrapper = { 6, 18, 98, 2 },
	Corcunda = { 18, 56, 292, 2 },
	MonstroPS1 = { 7, 23, 124, 2 },
	Florescida = { 5, 23, 85, 1 }, -- pelo chão: sem absorção, ±1
}
local nivelDe = { Rastejador = 1, Wrapper = 1, Corcunda = 1, MonstroPS1 = 1, Florescida = 3 }
for especie, e in ESPERADO do
	local n = nivelDe[especie]
	util.perto(alcance(passo("agachado"), especie, n), e[1], especie .. " agachado", 1)
	util.perto(alcance(passo("andar"), especie, n), e[2], especie .. " andar", 1)
	util.perto(alcance(passo("correr"), especie, n), e[3], especie .. " correr", e[4])
end

-- ouvinte de referência (limiar 0, sem chão) = o nível 1 de hoje: 12 / 36 / ~190 (hoje 11 / 36 / 200, sem carga)
do
	local ag, an, co = passo("agachado"), passo("andar"), passo("correr")
	util.perto((Som.alcanceEvento(ag.bandas, ag.chao, noite, nil)), 12, "referência agachado", 1)
	util.perto((Som.alcanceEvento(an.bandas, an.chao, noite, nil)), 36, "referência andar", 1)
	util.perto((Som.alcanceEvento(co.bandas, co.chao, noite, nil)), 190, "referência correr", 2)
end

-- Florescida: ouve a corrida e o passo pelo chão (o ar é pior)
for _, modo in { "agachado", "andar", "correr" } do
	local ev = passo(modo)
	local perfil = Audicao.perfil("Florescida", 3)
	local ar, _, chao = Audicao.vias(ev, perfil, Audicao.alcance(ev, perfil, 0, 0, 0, nil, nil) * 0.98, 0, 0, 0, nil)
	assert(chao ~= nil and chao >= 0 and chao >= ar, "Florescida " .. modo .. ": vence o chão")
end

-- 2) Rastejador no Pulso: só a via chão, limiar 2 (14 - 12). andar 25; agachado ~6 mas o Pulso o ignora
do
	local pulso = { chao = Presets.quadrupedeArrombador.habilidades.pulso.bonusChao }
	util.igual(pulso.chao, -12, "bônus do pulso no chão")
	util.perto(alcance(passo("andar"), "Rastejador", 1, 0, pulso, "chao"), 25, "Pulso: andar pelo chão", 1)
	util.perto(
		alcance(passo("agachado"), "Rastejador", 1, 0, pulso, "chao"),
		6,
		"Pulso sem ignorarAgachado: agachado ~6",
		1
	)
	local ignora = { chao = pulso.chao, ignorarAgachado = true }
	util.igual(
		alcance(passo("agachado"), "Rastejador", 1, 0, ignora, "chao"),
		0,
		"Pulso com ignorarAgachado: agachado não conta"
	)
	util.igual(
		alcance(passo("deitado"), "Rastejador", 1, 0, ignora, "chao"),
		0,
		"Pulso com ignorarAgachado: deitado não conta"
	)
	util.perto(alcance(passo("andar"), "Rastejador", 1, 0, ignora, "chao"), 25, "ignorarAgachado não mexe em andar", 1)
	assert(alcance(passo("correr"), "Rastejador", 1, 0, ignora, "chao") > 25, "correr é sentido de mais longe")
	-- a regra só vale para passos: um detrito (tipo "detrito") agachado ainda passa pelo chão
	local detrito = passo("agachado")
	detrito.tipo = "detrito"
	detrito.chao = 40
	assert(alcance(detrito, "Rastejador", 1, 0, ignora, "chao") > 0, "ignorarAgachado só vale para passos")
	-- o padrão do preset é ignorar (decisão #2)
	util.igual(Presets.quadrupedeArrombador.habilidades.pulso.ignorarAgachado, true, "pulso.ignorarAgachado padrão")
end

-- 3) atrás de 2 paredes, correndo, Rastejador: o grave atravessa e vence (médio 16 studs, grave 25)
do
	local ev = passo("correr")
	local soMedio = { bandas = { grave = -1000, medio = ev.bandas.medio, agudo = -1000 }, ambienteBandas = noite }
	local soGrave = { bandas = { grave = ev.bandas.grave, medio = -1000, agudo = -1000 }, ambienteBandas = noite }
	util.perto(alcance(soMedio, "Rastejador", 1, 2), 16, "2 paredes: médio", 1)
	util.perto(alcance(soGrave, "Rastejador", 1, 2), 25, "2 paredes: grave", 1)
	local perfil = Audicao.perfil("Rastejador", 1)
	-- a 24 studs ainda se ouve pelo ar (o grave); o médio já morreu. (O Rastejador também sente o chão ali: aqui só o ar.)
	local ar, bandaAr = Audicao.vias(ev, perfil, 24, 2, 0, 0, nil)
	util.igual(bandaAr, "grave", "2 paredes a 24 studs: o grave vence no ar")
	assert(ar >= 0, "2 paredes a 24 studs: ainda ouve pelo ar")
	assert((Audicao.vias(ev, perfil, 30, 2, 0, 0, nil)) < 0, "2 paredes a 30 studs: não ouve pelo ar")
	-- 3 paredes valem 3; mais que isso não piora
	util.perto(
		Audicao.excesso(ev, perfil, 20, 3, 0, 0, nil),
		Audicao.excesso(ev, perfil, 20, 9, 0, 0, nil),
		"9 paredes valem 3"
	)
end

-- 4) perfil: espécie com perfil, espécie sem perfil (limiar plano da margem do nível = hoje, sem chão)
do
	local r = Audicao.perfil("Rastejador", 1)
	util.igual(r.limiar.grave, 0, "Rastejador grave")
	util.igual(r.limiar.medio, 2, "Rastejador médio")
	util.igual(r.limiar.agudo, 6, "Rastejador agudo")
	util.igual(r.chao, 14, "Rastejador sente o chão")
	util.igual(r.erro, 0.15, "Rastejador erro")
	util.igual(Audicao.perfil("Corcunda", 1).limiar.medio, -4, "Corcunda médio")
	util.igual(Audicao.perfil("Corcunda", 1).chao, nil, "Corcunda não sente o chão")
	util.igual(Audicao.perfil("Wrapper", 1).limiar.agudo, 10, "Wrapper agudo")
	util.igual(Audicao.perfil("MonstroPS1", 1).erro, 0.2, "MonstroPS1 erro")
	util.igual(Audicao.perfil("Florescida", 3).chao, 4, "Florescida chão")
	for nivel, margem in { [1] = 0, [2] = 6, [3] = 12 } do
		local p = Audicao.perfil("Esfolado", nivel)
		util.igual(p.limiar.grave, margem, "Esfolado nível " .. nivel .. " grave")
		util.igual(p.limiar.medio, margem, "Esfolado nível " .. nivel .. " médio")
		util.igual(p.limiar.agudo, margem, "Esfolado nível " .. nivel .. " agudo")
		util.igual(p.chao, nil, "espécie sem perfil não sente o chão")
		util.igual(p.erro, nil, "espécie sem perfil usa o erro padrão")
		util.igual(margem, CfgMonstros.margemPorNivel[nivel], "porNivel = margemPorNivel de Config/Monstros")
	end
	util.igual(Audicao.perfil("Pernalta", 99).limiar.medio, 0, "nível desconhecido cai no 1")
	-- todas as espécies do Config/Monstros que nascem têm perfil
	for _, especie in CfgMonstros.especies do
		if especie.malha then
			assert(
				Audicao.perfil(especie.id, especie.nivel).erro ~= nil,
				"espécie sem perfil de audição: " .. especie.id
			)
		end
	end
end

-- 5) regressão: perfil plano {0, 0, 0}, sem chão e ambiente igual nas bandas = o resultado de hoje
do
	for nivel = 1, 3 do
		local perfil = Audicao.perfil("EspecieSemPerfil", nivel)
		for _, caso in { { 55, 20 }, { 40, 25 }, { 80, 40 }, { 110, 55 }, { 30, 20 } } do
			local db, amb = caso[1], caso[2]
			local ev = {
				bandas = { grave = db, medio = db, agudo = db },
				ambienteBandas = { grave = amb, medio = amb, agudo = amb, chao = 0 },
			}
			for _, distancia in { 0, 5, 36, 100, 300 } do
				local hoje = Som.excesso(Som.recebido(db, distancia, 0), amb, CfgMonstros.margemPorNivel[nivel])
				local novo = Audicao.excesso(ev, perfil, distancia, 0, 0, 0, nil)
				util.perto(
					novo,
					hoje,
					string.format("regressão %d dB amb %d nível %d a %d studs", db, amb, nivel, distancia),
					1e-9
				)
			end
		end
	end
end

-- 6) atenção: estado do ouvinte e parado
do
	util.igual(Audicao.atencao("Calmo", 8), 0, "Calmo andando")
	util.igual(Audicao.atencao("Investiga", 8), -2, "Investiga")
	util.igual(Audicao.atencao("Caca", 20), 4, "Caça correndo")
	util.igual(Audicao.atencao("Ataque", 20), 10, "Ataque")
	util.igual(Audicao.atencao("Calmo", 0), -3, "Calmo parado escuta melhor")
	util.igual(Audicao.atencao("Caca", 0.5), 1, "Caça parada: 4 - 3")
	util.igual(Audicao.atencao("EstadoDesconhecido", 8), 0, "estado desconhecido = 0")
	-- quem corre ouve pior: o mesmo som a 40 studs
	local ev = passo("andar")
	local perfil = Audicao.perfil("Rastejador", 1)
	local calmo = Audicao.excesso(ev, perfil, 28, 0, 0, Audicao.atencao("Calmo", 8), nil)
	local caca = Audicao.excesso(ev, perfil, 28, 0, 0, Audicao.atencao("Caca", 20), nil)
	util.perto(calmo - caca, 4, "atenção de Caça tira 4 dB")
end

-- 7) erro da posição por banda: grave e chão se localizam mal, agudo bem
do
	local perfil = Audicao.perfil("Rastejador", 1)
	local base = 100 * 0.15
	util.perto(Audicao.raioErro(100, perfil, "grave", 0.15), base * 1.5, "erro grave")
	util.perto(Audicao.raioErro(100, perfil, "medio", 0.15), base * 1.0, "erro médio")
	util.perto(Audicao.raioErro(100, perfil, "agudo", 0.15), base * 0.8, "erro agudo")
	util.perto(Audicao.raioErro(100, perfil, "chao", 0.15), base * 2.0, "erro chão")
	util.perto(Audicao.raioErro(100, Audicao.perfil("Corcunda", 1), "medio", 0.15), 100 * 0.08, "erro da espécie")
	util.perto(
		Audicao.raioErro(100, Audicao.perfil("Esfolado", 1), "medio", 0.15),
		100 * 0.15,
		"sem erro na espécie: usa o padrão"
	)
	util.igual(Audicao.raioErro(-5, perfil, "medio", 0.15), 0, "distância negativa")
end

-- 8) quando pagar raycast de paredes (§6.2): só se o ar passa e vence o chão
do
	local perfil = Audicao.perfil("Rastejador", 1)
	local ev = passo("correr")
	assert(Audicao.precisaParedes(ev, perfil, 100, 0, 0, nil), "100 studs: só o ar chega, parede muda o resultado")
	assert(not Audicao.precisaParedes(ev, perfil, 5, 0, 0, nil), "5 studs: o chão vence, parede não muda")
	assert(not Audicao.precisaParedes(ev, perfil, 400, 0, 0, nil), "400 studs: não ouve nem sem paredes")
	-- sem chão no ouvinte, sempre depende do ar
	assert(
		Audicao.precisaParedes(ev, Audicao.perfil("Wrapper", 1), 50, 0, 0, nil),
		"Wrapper (sem chão) precisa de paredes"
	)
	-- o chão passa mesmo sem o ar: não precisa de parede
	local soChao = { bandas = { grave = 0, medio = 0, agudo = 0 }, chao = 60, ambienteBandas = noite }
	assert(not Audicao.precisaParedes(soChao, perfil, 10, 0, 0, nil), "só o chão ouve: sem raycast")
	local x, banda = Audicao.excesso(soChao, perfil, 10, 3, 0, 0, nil)
	assert(x >= 0 and banda == "chao", "parede não tira o chão")
end

-- 9) chão: outro andar tira 20 dB (|dy| > 10 studs)
do
	local perfil = Audicao.perfil("Rastejador", 1)
	local ev = { bandas = { grave = 0, medio = 0, agudo = 0 }, chao = 60, ambienteBandas = noite }
	local mesmo = Audicao.excesso(ev, perfil, 20, 0, 3, 0, nil)
	local outro = Audicao.excesso(ev, perfil, 20, 0, 12, 0, nil)
	util.perto(mesmo - outro, 20, "outro andar: -20 dB no chão")
end

-- 10) extras de habilidade: MonstroPS1 raspando ensurdece (+6 em todas as bandas)
do
	local surdez = Presets.monstroPS1.habilidades.raspar.surdez
	local ev = passo("andar")
	local normal = alcance(ev, "MonstroPS1", 1)
	local raspando = alcance(ev, "MonstroPS1", 1, 0, surdez)
	assert(raspando < normal, "raspando ouve menos")
	util.perto(raspando, normal * 10 ^ (-6 / 20), "+6 dB de limiar = metade da distância", 1.5)
end

print("Audicao.spec ok")
