local Personagens = require("../src/shared/Regras/Personagens")
local cfg = require("../src/shared/Config/Personagens")
local aparencia = require("../src/shared/Config/Aparencia")
local util = require("./util")

local lista = cfg.lista

-- elenco coerente: ids e números únicos, padrão existe, paleta só com 3 números
local ids, ns = {}, {}
for _, e in lista do
	assert(not ids[e.id], "id repetido: " .. e.id)
	assert(not ns[e.n], "n repetido: " .. e.n)
	ids[e.id], ns[e.n] = true, true
	assert(e.n == math.floor(e.n) and e.n >= 1, "n inteiro >= 1: " .. e.id)
	assert(e.visual == "bloco" or e.visual == "malhas", "visual inválido: " .. e.id)
	for chave, c in e.paleta do
		assert(#c == 3, "cor com 3 números: " .. e.id .. "." .. chave)
		for _, v in c do
			assert(v >= 0 and v <= 255, "cor fora de 0..255: " .. e.id .. "." .. chave)
		end
	end
	if e.estilo.cabelo ~= "trancas" then
		assert(cfg.cabelos[e.estilo.cabelo], "preset de cabelo inexistente: " .. e.estilo.cabelo)
	end
end
assert(ids[cfg.padrao], "o id padrão existe no elenco")
util.igual(Personagens.porId(lista, "male_casual").n, 1, "padrão é o n 1")

-- validarEscolha: só inteiro finito do elenco
util.igual(Personagens.validarEscolha(lista, 2).id, "office_worker", "n 2")
util.igual(Personagens.validarEscolha(lista, 3).id, "survivor_woman", "n 3")
util.igual(Personagens.validarEscolha(lista, 0), nil, "n 0")
util.igual(Personagens.validarEscolha(lista, 99), nil, "n fora do elenco")
util.igual(Personagens.validarEscolha(lista, -1), nil, "n negativo")
util.igual(Personagens.validarEscolha(lista, 1.5), nil, "n fracionário")
util.igual(Personagens.validarEscolha(lista, 0 / 0), nil, "n NaN")
util.igual(Personagens.validarEscolha(lista, math.huge), nil, "n infinito")
util.igual(Personagens.validarEscolha(lista, "2"), nil, "n texto")
util.igual(Personagens.validarEscolha(lista, nil), nil, "n nil")
util.igual(Personagens.validarEscolha(lista, {}), nil, "n tabela")

-- idEfetivo: ausente/inválido = padrão
util.igual(Personagens.idEfetivo(lista, nil, "male_casual"), "male_casual", "id ausente")
util.igual(Personagens.idEfetivo(lista, "naoexiste", "male_casual"), "male_casual", "id inexistente")
util.igual(Personagens.idEfetivo(lista, 5, "male_casual"), "male_casual", "id de outro tipo")
util.igual(Personagens.idEfetivo(lista, "office_worker", "male_casual"), "office_worker", "id válido")

-- nInicial: escolha salva válida ou padrão
util.igual(Personagens.nInicial(lista, 3, "male_casual"), 3, "salvo válido")
util.igual(Personagens.nInicial(lista, 77, "male_casual"), 1, "salvo inválido cai no padrão")
util.igual(Personagens.nInicial(lista, nil, "male_casual"), 1, "sem salvo")

-- ordenar: por ordem, sem mutar a entrada
local embaralhada = { lista[3], lista[1], lista[2] }
local ord = Personagens.ordenar(embaralhada)
util.igual(ord[1].id, "male_casual", "ordenada 1")
util.igual(ord[3].id, "survivor_woman", "ordenada 3")
util.igual(embaralhada[1].id, "survivor_woman", "entrada intacta")

-- vizinho dá a volta
util.igual(Personagens.vizinho(3, 1, 1), 2, "vizinho +1")
util.igual(Personagens.vizinho(3, 3, 1), 1, "vizinho dá a volta")
util.igual(Personagens.vizinho(3, 1, -1), 3, "vizinho -1 dá a volta")
util.igual(Personagens.vizinho(0, 1, 1), 1, "vizinho sem itens")

-- podeEscolher
local function estado(o: { [string]: boolean }?)
	local e = { escolheu = false, temPersonagem = false, morto = false, carregando = false }
	for k, v in o or {} do
		(e :: any)[k] = v
	end
	return e
end
util.igual((Personagens.podeEscolher(estado())), true, "primeira escolha")
util.igual((Personagens.podeEscolher(estado({ temPersonagem = true }))), true, "primeira escolha com personagem solto")
util.igual((Personagens.podeEscolher(estado({ escolheu = true }))), true, "já escolheu, sem personagem")
util.igual(
	(Personagens.podeEscolher(estado({ escolheu = true, temPersonagem = true, morto = true }))),
	true,
	"morto troca"
)
local ok, motivo = Personagens.podeEscolher(estado({ escolheu = true, temPersonagem = true }))
util.igual(ok, false, "vivo não troca")
assert(type(motivo) == "string" and motivo ~= "", "vivo recebe motivo")
util.igual((Personagens.podeEscolher(estado({ carregando = true }))), false, "clique duplo enquanto carrega")

-- decidirRespawn: sem respawn dobrado
local function resp(o: { [string]: any }?)
	local e: { [string]: any } =
		{ presente = true, fichaAgendada = 4, fichaAtual = 4, escolheu = true, carregando = false, escolhendo = false }
	for k, v in o or {} do
		e[k] = v
	end
	return Personagens.decidirRespawn(e :: any)
end
util.igual(resp(), "reaparecer", "morreu e o tempo acabou")
util.igual(resp({ escolhendo = true }), "esperar", "no seletor espera")
util.igual(resp({ fichaAtual = 5 }), "cancelar", "outro personagem já nasceu (troca antecipada)")
util.igual(resp({ presente = false }), "cancelar", "jogador saiu")
util.igual(resp({ carregando = true }), "cancelar", "já carregando")
util.igual(resp({ escolheu = false }), "cancelar", "nunca escolheu")

-- malhas: completas só com tudo preenchido
local nomes = {}
for nome in aparencia.partes do
	table.insert(nomes, nome)
end
util.igual(#nomes, 15, "15 peças R15")
local function malhaCompleta()
	local m: any = { modelo = "rbxassetid://1", textura = "rbxassetid://2", alturaTotalStuds = 5.1, partes = {} }
	for _, nome in nomes do
		m.partes[nome] = { meshId = "rbxassetid://3", tamanhoNativo = { 1, 1, 1 }, centroMontagem = { 0, 2, 0 } }
	end
	return m
end
util.igual(Personagens.malhasCompletas(malhaCompleta(), nomes), true, "malhas completas")
util.igual(Personagens.malhasCompletas(false, nomes), false, "false")
util.igual(Personagens.malhasCompletas(nil, nomes), false, "nil")
util.igual(Personagens.malhasCompletas({ modelo = false, textura = false, partes = {} }, nomes), false, "stub")
local semTextura = malhaCompleta()
semTextura.textura = false
util.igual(Personagens.malhasCompletas(semTextura, nomes), false, "sem textura")
local semPeca = malhaCompleta()
semPeca.partes.Head = nil
util.igual(Personagens.malhasCompletas(semPeca, nomes), false, "falta uma peça")
local tamRuim = malhaCompleta()
tamRuim.partes.LeftFoot.tamanhoNativo = { 1, 1 }
util.igual(Personagens.malhasCompletas(tamRuim, nomes), false, "tamanho nativo incompleto")
local semCentro = malhaCompleta()
semCentro.partes.Head.centroMontagem = nil
util.igual(Personagens.malhasCompletas(semCentro, nomes), false, "falta centroMontagem")
local semAltura = malhaCompleta()
semAltura.alturaTotalStuds = nil
util.igual(Personagens.malhasCompletas(semAltura, nomes), false, "falta alturaTotalStuds")

-- visualEfetivo: cai no bloco sem malha
local office = Personagens.porId(lista, "office_worker") :: any
util.igual(
	Personagens.visualEfetivo(office, { modelo = false, textura = false, partes = {} }, nomes),
	"bloco",
	"stub -> bloco"
)
util.igual(Personagens.visualEfetivo(office, malhaCompleta(), nomes), "malhas", "malhas completas")
util.igual(
	Personagens.visualEfetivo(Personagens.porId(lista, "male_casual") :: any, malhaCompleta(), nomes),
	"malhas",
	"padrão também é malha"
)

-- paleta: sobrescreve sem mutar a base
local base = { pele = { 1, 2, 3 }, suter = { 4, 5, 6 } }
local pal = Personagens.paleta(base, { paleta = { suter = { 9, 9, 9 }, gravata = { 7, 7, 7 } } } :: any)
util.igual(pal.suter[1], 9, "suter sobrescrito")
util.igual(pal.pele[1], 1, "pele mantida")
util.igual(pal.gravata[1], 7, "chave nova")
util.igual(base.suter[1], 4, "base intacta")

-- personagens se distinguem do padrão em camisa/calça
for _, id in { "office_worker", "survivor_woman" } do
	local e = Personagens.porId(lista, id) :: any
	local p = Personagens.paleta(aparencia.cores, e)
	assert(p.suter[1] ~= aparencia.cores.suter[1] or p.suter[2] ~= aparencia.cores.suter[2], id .. ": camisa diferente")
	assert(
		p.calcao[1] ~= aparencia.cores.calcao[1] or p.calcao[2] ~= aparencia.cores.calcao[2],
		id .. ": calça diferente"
	)
end

-- créditos: CC BY 4.0 uma vez só
local cred = Personagens.creditos(lista)
util.igual(#cred, 1, "um crédito (repetidos juntam)")
assert(string.find(cred[1], "CC BY 4.0", 1, true), "crédito cita a licença")
assert(string.find(cred[1], "heyheythere", 1, true), "crédito cita o autor")

print("Personagens.spec ok")
