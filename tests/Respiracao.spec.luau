local R = require("../src/shared/Regras/Respiracao")
local Cfg = require("../src/shared/Config/Respiracao")
local Movimento = require("../src/shared/Config/Movimento")
local util = require("./util")

local DT = 1 / 60

-- 1) sem apertar nada o jogador arfa antes de 7 s (o marcador cai da zona em ~1 s e a tensão leva 5 s para encher)
for semente = 1, 10 do
	for _, proximidade in { 0, 1 } do
		local rng = util.rng(semente)
		local e = R.novo(proximidade, 100, Cfg)
		local t = 0
		while not e.falhou and t < 10 do
			e = R.passo(e, false, DT, rng, Cfg)
			t += DT
		end
		assert(e.falhou, string.format("sem apertar: nunca falhou (semente %d, proximidade %d)", semente, proximidade))
		assert(
			t < 7,
			string.format("sem apertar: levou %.2f s para arfar (semente %d, proximidade %d)", t, semente, proximidade)
		)
	end
end

-- 2) um "bot" sem atraso: segura quando p < centro da zona − v × 0,25. Passa 15 s em 10 de 10 sementes, com proximidade 0 e 1
for _, proximidade in { 0, 1 } do
	for semente = 1, 10 do
		local rng = util.rng(semente * 7919)
		local e = R.novo(proximidade, 100, Cfg)
		local t = 0
		while t < 15 do
			local segurando = e.p < e.zona - e.v * 0.25
			e = R.passo(e, segurando, DT, rng, Cfg)
			t += DT
			assert(
				not e.falhou,
				string.format(
					"bot falhou aos %.2f s (semente %d, proximidade %d, tensão %.2f)",
					t,
					semente,
					proximidade,
					e.tensao
				)
			)
		end
	end
end

-- 3) largura da zona nos extremos e no meio
util.perto(R.largura(0, Cfg), 0.26, "largura longe")
util.perto(R.largura(1, Cfg), 0.24, "largura colado")
util.perto(R.largura(0.5, Cfg), 0.25, "largura no meio")
util.perto(R.largura(-3, Cfg), 0.26, "proximidade abaixo de 0 vale 0")
util.perto(R.largura(9, Cfg), 0.24, "proximidade acima de 1 vale 1")

-- 4) proximidade pela distância: 1 colado (<= 4 studs), 0 em 12 ou mais, linear no meio
util.perto(R.proximidade(0, Cfg), 1, "proximidade colado")
util.perto(R.proximidade(4, Cfg), 1, "proximidade a 4 studs")
util.perto(R.proximidade(8, Cfg), 0.5, "proximidade a 8 studs")
util.perto(R.proximidade(12, Cfg), 0, "proximidade a 12 studs")
util.perto(R.proximidade(40, Cfg), 0, "proximidade longe")

-- 5) a tensão nunca fica abaixo de 0; o marcador fica em 0..1; a zona fica dentro da barra, para qualquer entrada
for semente = 1, 10 do
	local rng = util.rng(semente + 100)
	local e = R.novo(semente % 2, 50, Cfg)
	local aperto = util.rng(semente + 555)
	for i = 1, 60 * 20 do
		e = R.passo(e, aperto() < 0.5, DT, rng, Cfg)
		if i % 90 == 0 then
			e = R.comProximidade(e, aperto())
		end
		assert(e.tensao >= 0, "tensão negativa")
		assert(e.p >= 0 and e.p <= 1, "marcador fora da barra")
		local w = R.largura(e.proximidade, Cfg)
		assert(e.zona >= w / 2 - 1e-9 and e.zona <= 1 - w / 2 + 1e-9, "zona fora da barra")
		if e.falhou then
			break
		end
	end
end

-- 6) bater na borda zera a velocidade (embaixo e em cima)
do
	local rng = util.rng(1)
	local e = R.novo(0, 100, Cfg)
	for _ = 1, 120 do
		e = R.passo(e, false, DT, rng, Cfg)
		if e.falhou then
			break
		end
	end
	util.igual(e.p, 0, "caiu até embaixo")
	util.igual(e.v, 0, "embaixo: velocidade zerada")
	local alto = R.novo(0, 100, Cfg)
	alto.p = 0.99
	alto.v = 3
	local depois = R.passo(alto, true, DT, rng, Cfg)
	util.igual(depois.p, 1, "bateu em cima")
	util.igual(depois.v, 0, "em cima: velocidade zerada")
end

-- 7) segurar empurra para cima, soltar deixa cair; tensão sobe fora da zona e desce dentro
do
	local rng = util.rng(3)
	local e = R.novo(0, 100, Cfg)
	local subiu = R.passo(R.passo(e, true, DT, rng, Cfg), true, DT, rng, Cfg)
	assert(subiu.p > e.p and subiu.v > 0, "segurar sobe")
	local caiu = R.passo(R.passo(e, false, DT, rng, Cfg), false, DT, rng, Cfg)
	assert(caiu.p < e.p and caiu.v < 0, "soltar cai")
	-- dentro: a tensão não passa de 0 e não sobe
	util.igual(subiu.tensao, 0, "dentro da zona a tensão fica em 0")
	-- fora: sobe `subida` por segundo
	local fora = R.novo(0, 100, Cfg)
	fora.p = 0
	fora.zona = 0.9
	fora.alvo = 0.9
	fora.espera = 10
	local depois = R.passo(fora, false, 0.1, rng, Cfg)
	util.perto(depois.tensao, Cfg.jogo.subida * 0.1, "tensão sobe fora da zona")
	util.igual(depois.dentro, false, "fora da zona")
	-- alívio: dentro com tensão 0,5 cai `alivio` por segundo
	local aliviar = R.novo(0, 100, Cfg)
	aliviar.tensao = 0.5
	local d2 = R.passo(aliviar, false, 0.1, rng, Cfg)
	util.perto(d2.tensao, 0.5 - Cfg.jogo.alivio * 0.1, "tensão cai dentro da zona", 0.001)
	-- depois de falhar, o estado congela
	local f = R.novo(0, 100, Cfg)
	f.tensao = 0.99
	f.p = 0
	f.zona = 0.9
	f.alvo = 0.9
	f.espera = 10
	local acabou = R.passo(f, false, 0.1, rng, Cfg)
	util.igual(acabou.falhou, true, "tensão cheia = falhou")
	util.igual(R.passo(acabou, true, 5, rng, Cfg), acabou, "estado falhado congela")
end

-- 8) estamina baixa: a zona anda mais depressa (x1,4)
do
	local descansado = R.novo(0, 100, Cfg)
	local cansado = R.novo(0, 20, Cfg)
	util.igual(descansado.cansado, false, "estamina 100: descansado")
	util.igual(cansado.cansado, true, "estamina 20: cansado")
	local function andou(e: any): number
		e.alvo = 0.9
		e.espera = 10
		local depois = R.passo(e, false, 0.5, util.rng(1), Cfg)
		return depois.zona - e.zona
	end
	util.perto(andou(descansado), Cfg.jogo.velZona * 0.5, "zona anda velZona por segundo")
	util.perto(andou(cansado), Cfg.jogo.velZona * Cfg.jogo.velZonaCansado * 0.5, "cansado: velZona x 1,4")
end

-- 9) fôlego: 10 s + 8 s × estamina/100
util.perto(R.folego(100, Cfg), 18, "fôlego com estamina cheia")
util.perto(R.folego(0, Cfg), 10, "fôlego com estamina zero")
util.perto(R.folego(50, Cfg), 14, "fôlego com estamina 50")
util.perto(R.folego(500, Cfg), 18, "estamina travada em 100")

-- 10) quando abre (§13.1): todas as condições
do
	local base = {
		vivo = true,
		emCarro = false,
		ativo = false,
		desdeUltimo = math.huge,
		modo = "agachado",
		distancia = 8,
		dy = 2,
	}
	local function com(mudanca: any): any
		local c = table.clone(base)
		for k, v in mudanca do
			c[k] = v
		end
		return c
	end
	assert(R.podeAbrir(base, Cfg), "caso base abre")
	assert(R.podeAbrir(com({ modo = "parado" }), Cfg), "parado abre")
	assert(R.podeAbrir(com({ modo = "deitado" }), Cfg), "deitado abre")
	assert(not R.podeAbrir(com({ modo = "andar" }), Cfg), "andando não abre")
	assert(not R.podeAbrir(com({ modo = "correr" }), Cfg), "correndo não abre")
	assert(not R.podeAbrir(com({ vivo = false }), Cfg), "morto não abre")
	assert(not R.podeAbrir(com({ emCarro = true }), Cfg), "em carro não abre")
	assert(not R.podeAbrir(com({ ativo = true }), Cfg), "já ativo não abre")
	assert(not R.podeAbrir(com({ desdeUltimo = 5.9 }), Cfg), "recarga de 6 s")
	assert(R.podeAbrir(com({ desdeUltimo = 6 }), Cfg), "recarga cumprida")
	local semMonstro = com({})
	semMonstro.distancia = nil
	assert(not R.podeAbrir(semMonstro, Cfg), "sem monstro em busca")
	assert(R.podeAbrir(com({ distancia = 12 }), Cfg), "no limite do raio")
	assert(not R.podeAbrir(com({ distancia = 12.1 }), Cfg), "fora do raio")
	assert(R.podeAbrir(com({ dy = -8 }), Cfg), "8 studs de altura ainda vale")
	assert(not R.podeAbrir(com({ dy = 8.5 }), Cfg), "outro andar não abre")
	local desligado = table.clone(Cfg)
	desligado.ligado = false
	assert(not R.podeAbrir(base, desligado), "interruptor desligado")
end

-- 11) por que acaba (§13.3)
do
	local base = { modo = "agachado", emCarro = false, tempo = 3, folego = 14, distanciaBusca = 6, cacando = false }
	local function com(mudanca: any): any
		local c = table.clone(base)
		for k, v in mudanca do
			c[k] = v
		end
		return c
	end
	util.igual(R.motivoFim(base, Cfg), nil, "continua")
	util.igual(R.motivoFim(com({ modo = "andar" }), Cfg), "moveu", "começou a andar")
	util.igual(R.motivoFim(com({ modo = "correr" }), Cfg), "moveu", "começou a correr")
	util.igual(R.motivoFim(com({ emCarro = true }), Cfg), "moveu", "entrou em carro")
	util.igual(R.motivoFim(com({ cacando = true }), Cfg), "cacou", "monstro em Caça")
	util.igual(R.motivoFim(com({ distanciaBusca = 16 }), Cfg), nil, "a 16 studs ainda continua (raio + 4)")
	util.igual(R.motivoFim(com({ distanciaBusca = 16.5 }), Cfg), "afastou", "passou de raio + 4")
	local semBusca = com({})
	semBusca.distanciaBusca = nil
	util.igual(R.motivoFim(semBusca, Cfg), "afastou", "monstro voltou a Calmo")
	util.igual(R.motivoFim(com({ tempo = 14 }), Cfg), "folego", "fôlego acabou")
	util.igual(R.motivoFim(com({ tempo = 13.9 }), Cfg), nil, "fôlego ainda não")
	util.igual(R.motivoFim(com({ modo = "andar", cacando = true, tempo = 99 }), Cfg), "moveu", "prioridade: moveu")
	util.igual(R.motivoFim(com({ cacando = true, tempo = 99 }), Cfg), "cacou", "prioridade: caça antes do fôlego")
end

-- 12) a tecla está no Config de movimento: Espaço (decisão 2026-11-14) e nunca uma tecla já usada por outra ação (o F é a lanterna)
do
	local mov = Movimento :: any
	local teclas = mov.teclas.prenderRespiracao
	assert(type(teclas) == "table" and teclas[1] == "Space", "tecla de prender a respiração = Space")
	for acao, lista in mov.teclas do
		if acao ~= "prenderRespiracao" then
			for _, t in lista do
				assert(t ~= teclas[1], "tecla de prender a respiração repetida em teclas." .. acao)
			end
		end
	end
end

print("Respiracao.spec ok")
