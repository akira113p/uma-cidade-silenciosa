-- Pane, engatilhar, recarga rápida e munição de pente inteiro (docs/armas.md §13). Regras puras: Regras/Armas.luau.
local A = require("../src/shared/Config/Armas")
local Itens = require("../src/shared/Config/Itens")
local Regras = require("../src/shared/Regras/Armas")
local util = require("./util")

local armas = A.armas
local pane = A.pane
local rapida = A.recargaRapida

-- classes: pente = "auto"; bomba = "manual"; lançador sem engatilhar
for _, id in { "pistola", "beretta", "ar15", "carabinaM5", "ak74" } do
	assert(armas[id].engatilhar == "auto", id .. ": arma de pente engatilha sozinha")
	assert(Regras.podePanear(armas[id]), id .. ": arma de pente pode travar")
	assert((armas[id].tempoEngatilhar or 0) > 0, id .. ": precisa de tempoEngatilhar")
end
for _, id in { "escopeta", "escopetaM1912" } do
	assert(armas[id].engatilhar == "manual", id .. ": bomba engatilha na mão")
	assert(not Regras.podePanear(armas[id]), id .. ": bomba nunca trava")
	assert((armas[id].tempoEngatilhar or 0) > 0, id .. ": precisa de tempoEngatilhar")
end
assert(not Regras.usaEngatilhar(armas.lancaFoguetes), "lançador não engatilha")
assert(not Regras.podePanear(armas.lancaFoguetes), "lançador não trava")

-- chance de travar: 5% semi, 1,25% auto, 0 fora das armas de pente
util.perto(Regras.chancePane(armas.pistola, pane), 0.05, "pistola semi 5%", 1e-9)
util.perto(Regras.chancePane(armas.ar15, pane), 0.05, "AR-15 é semi: 5%", 1e-9)
util.perto(Regras.chancePane(armas.ak74, pane), 0.0125, "AK auto 1,25%", 1e-9)
util.perto(Regras.chancePane(armas.carabinaM5, pane), 0.0125, "M5 auto 1,25%", 1e-9)
util.perto(Regras.chancePane(armas.escopeta, pane), 0, "bomba não trava", 1e-9)

-- sorteio da pane: trava quando o valor passa de 1 - chance; nunca duas vezes no pente nem na última bala
assert(Regras.travou(armas.pistola, pane, false, 10, 0.951), "0,951 > 0,95 trava")
assert(not Regras.travou(armas.pistola, pane, false, 10, 0.95), "exatamente 0,95 não trava")
assert(not Regras.travou(armas.pistola, pane, false, 10, 0.5), "valor baixo não trava")
assert(not Regras.travou(armas.pistola, pane, true, 10, 0.999), "já travou neste pente: não trava de novo")
assert(not Regras.travou(armas.pistola, pane, false, 0, 0.999), "sem bala sobrando não trava")
assert(Regras.travou(armas.ak74, pane, false, 5, 0.99), "auto trava acima de 0,9875")
assert(not Regras.travou(armas.ak74, pane, false, 5, 0.98), "auto não trava abaixo de 0,9875")
assert(not Regras.travou(armas.escopeta, pane, false, 3, 0.9999), "bomba nunca trava")
assert(not Regras.travou(armas.lancaFoguetes, pane, false, 1, 0.9999), "lançador nunca trava")
assert(not Regras.travou(armas.pistola, pane, false, 5, 0 / 0), "sorteio NaN não trava")
-- taxa observada (10 mil tiros com pente novo a cada tiro): perto de 5%
do
	local rng = util.rng(7)
	local trava = 0
	for _ = 1, 10000 do
		if Regras.travou(armas.pistola, pane, false, 10, rng()) then
			trava += 1
		end
	end
	assert(trava > 380 and trava < 620, "taxa de pane perto de 5%: " .. trava .. " em 10000")
end

-- engatilhada depois do tiro / ao equipar
assert(Regras.engatilhadaAposTiro(armas.pistola, false), "pente: segue engatilhada")
assert(not Regras.engatilhadaAposTiro(armas.pistola, true), "pente que travou: desengatilhada")
assert(not Regras.engatilhadaAposTiro(armas.escopeta, false), "bomba: desengatilhada depois do tiro")
assert(Regras.engatilhadaAposTiro(armas.lancaFoguetes, false), "lançador: sempre pronto")
assert(Regras.engatilhadaAoEquipar(armas.pistola, 5), "equipar com bala: engatilhada")
assert(not Regras.engatilhadaAoEquipar(armas.pistola, 0), "equipar sem bala: não")
assert(Regras.engatilhadaAoEquipar(armas.lancaFoguetes, 0), "lançador não usa")

-- bloqueio do tiro
assert(Regras.bloqueioDeTiro(armas.pistola, true, false, false) == nil, "pronta: atira")
assert(Regras.bloqueioDeTiro(armas.pistola, true, true, false) == "travada", "travada")
assert(Regras.bloqueioDeTiro(armas.escopeta, false, false, false) == "desengatilhada", "bomba desengatilhada")
assert(Regras.bloqueioDeTiro(armas.escopeta, true, false, true) == "engatilhando", "mão ocupada")
assert(Regras.bloqueioDeTiro(armas.lancaFoguetes, false, false, false) == nil, "lançador ignora engatilhada")
assert(Regras.bloqueioDeTiro(armas.pistola, nil, nil, nil) == nil, "sem informação do servidor não bloqueia")

-- tecla de engatilhar
do
	local acao, t = Regras.engatilhar(armas.pistola, 0, true, false, pane)
	assert(acao == "vazio" and t == 0, "sem balas: só o clique")
	acao, t = Regras.engatilhar(armas.pistola, 5, true, false, pane)
	assert(acao == "nada", "já engatilhada e sem pane: nada")
	acao, t = Regras.engatilhar(armas.pistola, 5, false, true, pane)
	assert(acao == "destravar", "pane: destrava")
	util.perto(t, pane.tempoDestravar, "tempo de destravar")
	acao, t = Regras.engatilhar(armas.escopeta, 3, false, false, pane)
	assert(acao == "engatilhar", "bomba desengatilhada: engatilha")
	util.perto(t, armas.escopeta.tempoEngatilhar, "tempo de bombear")
	acao = Regras.engatilhar(armas.lancaFoguetes, 1, false, false, pane)
	assert(acao == "nada", "lançador não engatilha")
end

-- capacidade da recarga: +1 só com bala na câmara (pente, engatilhada, sem pane, pente >= 1)
assert(Regras.capacidadeRecarga(armas.pistola, 10, true, false) == armas.pistola.pente + 1, "tática: +1")
assert(Regras.capacidadeRecarga(armas.pistola, 0, true, false) == armas.pistola.pente, "vazia: sem +1")
assert(Regras.capacidadeRecarga(armas.pistola, 10, true, true) == armas.pistola.pente, "travada: sem +1")
assert(Regras.capacidadeRecarga(armas.pistola, 10, false, false) == armas.pistola.pente, "desengatilhada: sem +1")
assert(Regras.capacidadeRecarga(armas.escopeta, 3, true, false) == armas.escopeta.pente, "bomba: sem +1")
assert(not Regras.podeRecarregar(armas.pistola, armas.pistola.pente + 1, 30, true, false), "pente+1: cheio")
assert(Regras.podeRecarregar(armas.pistola, armas.pistola.pente, 30, true, false), "pente cheio sem a câmara: +1 cabe")
assert(not Regras.podeRecarregar(armas.pistola, 3, 0, true, false), "sem reserva não recarrega")

-- tempo de recarga: vazia numa arma de pente inclui engatilhar; cheia/tática não; tubo não muda
do
	local p = armas.pistola
	util.perto(Regras.tempoRecarga(p, 5, 50), p.recarga.tempo, "tática: tempo base")
	util.perto(Regras.tempoRecarga(p, 0, 50), p.recarga.tempo + p.tempoEngatilhar, "vazia: tempo + engatilhar")
	local e = armas.escopeta
	util.perto(
		Regras.tempoRecarga(e, 0, 50),
		e.recarga.inicio + e.pente * e.recarga.porCartucho + e.recarga.fim,
		"tubo vazio igual a antes"
	)
end

-- recarga rápida: janela, falha, nova duração
do
	local p = armas.pistola
	local d = Regras.tempoRecarga(p, 5, 50)
	assert(Regras.cliqueNaRecarga(p, rapida, d * 0.5, d, false, false) == "rapida", "meio da recarga: rápida")
	assert(Regras.cliqueNaRecarga(p, rapida, d * 0.1, d, false, false) == "falha", "cedo demais: falha")
	assert(Regras.cliqueNaRecarga(p, rapida, d * 0.9, d, false, false) == "falha", "tarde demais: falha")
	assert(Regras.cliqueNaRecarga(p, rapida, d * 0.5, d, true, false) == "ignorar", "depois de atrapalhar: ignora")
	assert(Regras.cliqueNaRecarga(p, rapida, d * 0.5, d, false, true) == "ignorar", "depois da rápida: ignora")
	assert(Regras.cliqueNaRecarga(armas.escopeta, rapida, 1, 3, false, false) == "ignorar", "tubo não tem rápida")
	local nova = Regras.duracaoAposClique("rapida", rapida, d * 0.5, d)
	assert(nova < d, "rápida termina antes")
	assert(nova >= d * 0.5 + rapida.minimoApos - 1e-9, "rápida nunca termina antes de decorrido + mínimo")
	util.perto(Regras.duracaoAposClique("falha", rapida, d * 0.1, d), d + rapida.penalidade, "falha demora mais")
	util.perto(Regras.duracaoAposClique("ignorar", rapida, 0, d), d, "ignorar não muda")
end
assert(rapida.janelaDe < rapida.janelaAte and rapida.fator > 0 and rapida.fator < 1, "Config recargaRapida coerente")

-- pente velho que cai: tudo menos a bala da câmara
do
	local chao, camara = Regras.penteVelho(10, true, false)
	assert(chao == 9 and camara == 1, "engatilhada: 9 caem, 1 fica na câmara")
	chao, camara = Regras.penteVelho(10, true, true)
	assert(chao == 10 and camara == 0, "travada: cai tudo")
	chao, camara = Regras.penteVelho(0, true, false)
	assert(chao == 0 and camara == 0, "vazio: nada cai")
	chao, camara = Regras.penteVelho(10, false, false)
	assert(chao == 10 and camara == 0, "desengatilhada: cai tudo")
end

-- frases da checagem de munição
assert(Regras.frasePente(0, 17) == "Vazio.", "vazio")
assert(Regras.frasePente(2, 17) == "Só restam algumas balas.", "poucas")
assert(Regras.frasePente(6, 17) == "Menos da metade.", "menos da metade")
assert(Regras.frasePente(9, 17) == "Mais ou menos metade.", "metade")
assert(Regras.frasePente(16, 17) == "Quase cheio.", "quase cheio")
assert(Regras.frasePente(17, 17) == "Cheio.", "cheio")
assert(Regras.frasePente(18, 17) == "Cheio.", "+1 na câmara conta como cheio")
assert(Regras.fraseReserva(0, 17) == "Sem reserva.", "sem reserva")
assert(Regras.fraseReserva(5, 17) == "Reserva: menos de um pente.", "menos de um pente")
assert(Regras.fraseReserva(17, 17) == "Reserva: 1 pente.", "um pente")
assert(Regras.fraseReserva(26, 17) == "Reserva: 1 e meio pentes.", "um e meio")
assert(Regras.fraseReserva(34, 17) == "Reserva: 2 pentes.", "dois pentes")

-- munição achada = um pente inteiro (decisão do usuário 2026-11-14): `pente` do item, qtd de loot e pilha de 2 pentes
do
	local pentesDoItem = {}
	for id, item in Itens.itens do
		if item.tipo == "municao" then
			assert(type(item.pente) == "number" and item.pente >= 1, id .. ": munição sem `pente`")
			assert(item.pilha == item.pente * 2 or item.id == "municaoMissil", id .. ": pilha tem que guardar 2 pentes")
			pentesDoItem[id] = item.pente
		end
	end
	-- cada arma de fogo carrega no máximo um pente do item de munição dela
	for id, cfg in armas do
		if cfg.tipo == "fogo" then
			local p = pentesDoItem[cfg.municao]
			assert(p ~= nil, id .. ": municao sem item")
			assert(
				p >= cfg.pente or cfg.recarga.tipo == "cartucho" or cfg.pente == 1,
				id .. ": pente do item menor que o da arma"
			)
		end
	end
	local function conferir(tabelas: { [string]: any }, origem: string)
		for nome, tabela in tabelas do
			for _, e in tabela.itens do
				local p = pentesDoItem[e.id]
				if p then
					assert(
						e.qtd[1] == p and e.qtd[2] == p,
						string.format(
							"%s/%s: %s tem que valer 1 pente (%d), veio {%d, %d}",
							origem,
							nome,
							e.id,
							p,
							e.qtd[1],
							e.qtd[2]
						)
					)
				end
			end
		end
	end
	conferir(Itens.tabelas, "Itens")
	-- o init de Config/Compartimentos usa script:WaitForChild (não existe no Lune): carrega Casa e Comercial direto
	conferir(require("../src/shared/Config/Compartimentos/Casa").tabelas, "Casa")
	conferir(require("../src/shared/Config/Compartimentos/Comercial").tabelas, "Comercial")
end

print("ArmasPane.spec ok")
