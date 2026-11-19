local Presets = require("../src/shared/Config/PresetsMonstro")
local Monstros = require("../src/shared/Config/Monstros")
local H = require("../src/shared/Regras/Habilidades")
local util = require("./util")

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

-- recarga ---------------------------------------------------------------------------------------------------------------
assert(H.pronto(-math.huge, 0, 10), "nunca usou: pronto")
assert(not H.pronto(0, 9.9, 10), "antes da recarga")
assert(H.pronto(0, 10, 10), "recarga cumprida")

-- cone ------------------------------------------------------------------------------------------------------------------
local origem, frente = v(0, 0, 0), v(0, 0, -1)
assert(H.noCone(origem, frente, v(0, 0, -10), 70, 14), "de frente, dentro do alcance")
assert(not H.noCone(origem, frente, v(0, 0, -15), 70, 14), "além do alcance")
assert(H.noCone(origem, frente, v(5, 0, -10), 70, 14), "~27 graus: dentro do cone de 70")
assert(not H.noCone(origem, frente, v(10, 0, -5), 70, 14), "~63 graus: fora do cone de 70")
assert(not H.noCone(origem, frente, v(0, 0, 10), 70, 14), "atrás")
assert(H.noCone(origem, v(0, 0, 1), v(0, 0, 10), 100, 14), "cone traseiro (frente invertida)")

-- visão do Corcunda (§5.1) -------------------------------------------------------------------------------------------
local vis = Presets.corcunda.habilidades.visao
util.igual(H.alcanceVisao(vis, {}), 14, "de pé de dia")
util.igual(H.alcanceVisao(vis, { agachado = true }), 7, "agachado")
util.igual(H.alcanceVisao(vis, { deitado = true }), 4, "deitado")
util.igual(H.alcanceVisao(vis, { noite = true }), 7, "noite pela metade")
util.igual(H.alcanceVisao(vis, { noite = true, agachado = true }), 3.5, "noite e agachado")
util.igual(H.alcanceVisao(vis, { noite = true, lanterna = true }), 20, "lanterna ligada: 20")
assert(H.ehNoite(3, 6, 18) and H.ehNoite(18, 6, 18) and not H.ehNoite(12, 6, 18), "noite fora de 6-18")
assert(H.veJogador(vis, origem, frente, v(0, 0, -10), {}, true), "vê")
assert(not H.veJogador(vis, origem, frente, v(0, 0, -10), {}, false), "sem linha de visão não vê")
assert(
	not H.veJogador(vis, origem, frente, v(0, 0, -10), { agachado = true }, true),
	"agachado a 10: fora do alcance 7"
)
assert(H.veJogador(vis, origem, frente, v(0, 0, -6), { agachado = true }, true), "agachado a 6: vê")

-- sonar (§4.1) --------------------------------------------------------------------------------------------------------
local son = Presets.corpoAriete.habilidades.sonar
util.perto(H.tempoOnda(45, son.velocidade), 1.5, "45 studs a 30/s = 1,5 s")
util.perto(H.tempoOnda(15, son.velocidade), 0.5, "15 studs = 0,5 s")
assert(H.ondaAlcanca(45, son.raio) and not H.ondaAlcanca(45.1, son.raio), "alcance da onda")
assert(not H.perdeuAlvo(10, 12.9, son) and H.perdeuAlvo(10, 13, son), "perdeu o alvo depois de 3 s")
assert(
	H.alvoSonarValido({ ate = 5 }, 4.9) and not H.alvoSonarValido({ ate = 5 }, 5) and not H.alvoSonarValido(nil, 0),
	"memória do sonar"
)
assert(Presets.corpoAriete.semGrito == true and Presets.corpoAriete.grito == nil, "Wrapper sem grito")

-- pulso (§3.1) ---------------------------------------------------------------------------------------------------------
local pul = Presets.quadrupedeArrombador.habilidades.pulso
assert(H.pulsoDetecta(pul, 10, 8, false, false, false), "correndo perto: detecta")
assert(not H.pulsoDetecta(pul, 10, 1.4, false, false, false), "quase parado: não")
assert(not H.pulsoDetecta(pul, 10, 8, true, false, false), "agachado: não")
assert(not H.pulsoDetecta(pul, 10, 8, false, true, false), "deitado: não")
assert(not H.pulsoDetecta(pul, 10, 8, false, false, true), "em carro: não")
assert(not H.pulsoDetecta(pul, 25.1, 8, false, false, false), "fora do raio")

-- busca: grade e prioridade pelo fundo (§3.3) --------------------------------------------------------------------------------
local bus = Presets.quadrupedeArrombador.habilidades.busca
local pontos = H.candidatosBusca({ cx = 0, cz = 0, sx = 30, sz = 18 }, bus.grade, { x = -15, z = 0 }, util.rng(7))
assert(#pontos >= 8, "grade 30x18 de 6 studs tem pelo menos 8 pontos")
assert(pontos[1].x > 0, "o primeiro ponto é do lado oposto à entrada")
local n = #pontos
assert(pontos[n].x < pontos[1].x, "o último está mais perto da entrada")
for _, p in pontos do
	assert(math.abs(p.x) <= 15 and math.abs(p.z) <= 9, "dentro da caixa")
end

-- esconderijo (§5.4) ------------------------------------------------------------------------------------------------------
util.igual(H.escolherEsconderijo({ { oculto = false, dentro = true, dist = 1 } }), nil, "nenhum oculto")
util.igual(
	H.escolherEsconderijo({
		{ oculto = true, dentro = false, dist = 2 },
		{ oculto = true, dentro = true, dist = 9 },
		{ oculto = false, dentro = true, dist = 1 },
	}),
	2,
	"oculto e dentro vence o mais perto de fora"
)
util.igual(
	H.escolherEsconderijo({ { oculto = true, dentro = true, dist = 9 }, { oculto = true, dentro = true, dist = 3 } }),
	2,
	"entre dois dentro: o mais perto"
)

-- memória e imitação ---------------------------------------------------------------------------------------------------------
local emb = Presets.corcunda.habilidades.emboscada
local mem = {}
for i = 1, 5 do
	mem = H.memoriaRegistrar(mem, { tipo = "passo", db = 40 + i, quando = i }, i, emb)
end
util.igual(#mem, 3, "guarda só os 3 últimos")
util.igual(mem[1].db, 43, "o mais velho que sobrou")
mem = H.memoriaRegistrar(mem, { tipo = "vidro", db = 75, quando = 100 }, 100, emb)
util.igual(#mem, 1, "sons com mais de 60 s caem")
util.igual(H.memoriaEscolher({}, 0, emb, util.rng(1)), nil, "memória vazia")
util.igual(H.memoriaEscolher(mem, 101, emb, util.rng(1)).tipo, "vidro", "escolhe da memória")
util.igual(H.memoriaEscolher(mem, 200, emb, util.rng(1)), nil, "tudo velho")
util.igual(H.somDoTipo("passo", emb.sons), "PassoConcreto", "passo imitável")
util.igual(H.somDoTipo("carro", emb.sons), nil, "carro não é imitável")
assert(emb.sons.imitacao == nil, "imitação não imita imitação")

-- mira com erro (§6.3) ------------------------------------------------------------------------------------------------------
local lan = Presets.monstroPS1.habilidades.lancar
local rng = util.rng(42)
local alvo = v(0, 0.3, -1)
local maior = 0
for _ = 1, 500 do
	local d = H.desviarDirecao(alvo, lan.erroGraus, rng)
	local mag = math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
	util.perto(mag, 1, "direção unitária", 1e-6)
	local ang = H.anguloEntre(d, alvo)
	assert(ang <= lan.erroGraus + 1e-6, "erro dentro de 9 graus: " .. ang)
	maior = math.max(maior, ang)
end
assert(maior > lan.erroGraus * 0.7, "o sorteio usa o cone todo")
assert(H.anguloEntre(H.desviarDirecao(v(0, 1, 0), 9, rng), v(0, 1, 0)) <= 9 + 1e-6, "vertical também funciona")
local prev = H.alvoPrevisto(v(10, 0, 0), v(5, 0, -5), 0.2)
util.perto(prev.x, 11, "previsão x")
util.perto(prev.z, -1, "previsão z")

-- escolha de ataque do MonstroPS1 -----------------------------------------------------------------------------------------
local arr = Presets.monstroPS1.habilidades.arrancada
local escolha = function(dist, linha, a, l)
	return H.escolherAtaquePS1(dist, linha, a, l, arr, lan)
end
util.igual(escolha(30, true, true, true), "arrancada", "a 30: prefere arrancada")
util.igual(escolha(45, true, true, true), "lancar", "a 45: só lança")
util.igual(escolha(30, false, true, true), nil, "sem linha de visão: nada")
util.igual(escolha(30, true, false, true), "lancar", "arrancada em recarga: lança")
util.igual(escolha(10, true, true, true), nil, "perto demais para os dois")
util.igual(escolha(60, true, true, true), nil, "longe demais")
assert(H.golpeDuploAgora(3, 3) and H.golpeDuploAgora(6, 3) and not H.golpeDuploAgora(4, 3), "1 a cada 3 é golpe duplo")

-- zona (§2.5) e Florescida (§7.1) ------------------------------------------------------------------------------------------
local zonas = {
	{ chave = "cidade", cx = 0, cz = 0, sx = 900, sz = 900 },
	{ chave = "vila", cx = 1200, cz = 0, sx = 200, sz = 200 },
}
assert(H.dentroDeZona({ x = 0, z = 0 }, zonas, "cidade"), "centro da cidade")
assert(H.dentroDeZona({ x = 450, z = 450 }, zonas, "cidade"), "no limite: dentro")
assert(not H.dentroDeZona({ x = 451, z = 0 }, zonas, "cidade"), "um stud fora")
assert(not H.dentroDeZona({ x = 1200, z = 0 }, zonas, "cidade"), "a vila não é a cidade")
assert(H.dentroDeZona({ x = 1200, z = 0 }, zonas, "vila"), "a vila é vila")
local fora = H.pontoForaMaisProximo({ x = 400, z = 10 }, zonas[1], 2)
util.igual(fora.x, 452, "sai pelo lado leste, 2 studs além da borda")
util.igual(fora.z, 10, "mantém z")
local fora2 = H.pontoForaMaisProximo({ x = 10, z = -440 }, zonas[1], 2)
util.igual(fora2.z, -452, "sai pelo sul")
local ja = H.pontoForaMaisProximo({ x = 600, z = 0 }, zonas[1], 2)
util.igual(ja.x, 600, "já fora: fica")
assert(H.zonaQueContem({ x = 0, z = 0 }, zonas, "cidade") == zonas[1], "zonaQueContem")
assert(H.zonaQueContem({ x = 600, z = 0 }, zonas, "cidade") == nil, "zonaQueContem fora")

-- giro limitado ---------------------------------------------------------------------------------------------------------------
util.perto(H.girarPara(0, 1, 0.2), 0.2, "gira no máximo")
util.perto(H.girarPara(0, 0.1, 0.2), 0.1, "chega sem passar")
util.perto(H.girarPara(3, -3, 0.2), 3.2, "pelo lado mais curto (passa de pi)")
util.perto(H.girarPara(0, -1, 0.2), -0.2, "gira para o outro lado")

-- limite por espécie (§2.6) ------------------------------------------------------------------------------------------------
assert(H.podeNascer(0, nil) and H.podeNascer(999, nil), "sem limite")
assert(H.podeNascer(0, 1) and not H.podeNascer(1, 1), "um por servidor")
local flo
for _, e in Monstros.especies do
	if e.id == "Florescida" then
		flo = e
	end
end
util.igual(flo.maxPorServidor, 1, "Florescida: um por servidor")
util.igual(flo.maxAdmin, 2, "admin até 2")
util.igual(flo.capacidades.arrombar, false, "fachada no lugar do arrombar")
util.igual(flo.foraDaZona, "cidade", "só nasce fora da cidade")

-- fachada, flores, grade ------------------------------------------------------------------------------------------------------
local fac = Presets.florescida.habilidades.fachada
util.igual(H.decidirFachada(20, false, fac), "arrancar", "baixa e não concreto")
util.igual(H.decidirFachada(20, true, fac), "rondar", "concreto: ronda")
util.igual(H.decidirFachada(30, false, fac), "rondar", "alta: ronda")
util.igual(H.decidirFachada(26, false, fac), "arrancar", "no limite de 26")
assert(not H.florAMurchar(11, 12) and H.florAMurchar(12, 12), "a 13ª faz a mais antiga murchar")
util.igual(H.celula(25, -5, 20), "1:-1", "célula da grade")
util.igual(#H.celulasVizinhas(25, -5, 20), 9, "3x3 células")

-- presets (números do contrato) -------------------------------------------------------------------------------------------------
local arromb = Presets.quadrupedeArrombador.arrombar
util.igual(arromb.dano, 150, "arrombar: dano 150")
util.igual(arromb.intervalo, 0.9, "intervalo 0,9")
util.igual(arromb.folgaLargura, 2.2, "vão mais largo")
util.igual(arromb.alturaBuraco, 11, "vão mais alto")
util.igual(arromb.clipe, "Arrombar", "clipe próprio")
util.igual(Presets.corpoAriete.arrombar.dano, 90, "o Wrapper segue com 90")
util.igual(Presets.corpoAriete.arrombar.alturaBuraco, 9, "o Wrapper não herda o vão novo")
util.igual(Presets.florescida.velocidade.Caca, 60, "Florescida caça a 60 studs/s")
print("Habilidades.spec ok")
