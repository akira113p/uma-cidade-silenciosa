-- Regras/Animacao + dados dos clipes de corpo (assets/animacoes/corpo/*.json). Roda da raiz do projeto.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Regra = require("../src/shared/Regras/Animacao")
local CfgCorpo = require("../src/shared/Config/AnimacoesCorpo")
local util = require("./util")

local PASTA = "assets/animacoes/corpo"

-- easing -------------------------------------------------------------------------------------------------------------------
do
	local e, d = Regra.easing("Cubic-Out")
	util.igual(e, "Cubic", "easing estilo")
	util.igual(d, "Out", "easing direção")
	e, d = Regra.easing("Bounce-Out")
	util.igual(e, "Bounce", "bounce")
	e, d = Regra.easing("Cubic-InOut")
	util.igual(d, "InOut", "InOut")
	e, d = Regra.easing(nil)
	util.igual(e .. d, "LinearIn", "sem easing = Linear/In")
	e, d = Regra.easing("Banana-Out")
	util.igual(e .. d, "LinearIn", "easing inválido cai em Linear/In")
	e, d = Regra.easing("Linear")
	util.igual(e .. d, "LinearIn", "Linear sem direção")
end

-- resolverQuadros ----------------------------------------------------------------------------------------------------------
do
	local arq = {
		poses = { a = { RightShoulder = { 10, 0, 0 }, RightElbow = { 20, 0, 0 } } },
		clipes = {
			C = {
				duracao = 1,
				quadros = {
					{ t = 1, de = "a", juntas = { RightElbow = { 90, 0, 0 } } },
					{ t = 0, de = "a" },
				},
			},
			Ruim = {
				duracao = 1,
				quadros = { { t = 0, de = "naoExiste" }, { t = 1, juntas = { Waist = { 0, 0, 0 } } } },
			},
			Junta = {
				duracao = 1,
				quadros = {
					{ t = 0, juntas = { Cotovelo = { 0, 0, 0 } } },
					{ t = 1, juntas = { Waist = { 0, 0, 0 } } },
				},
			},
		},
	}
	local q = Regra.resolverQuadros(arq, "C") :: any
	util.igual(#q, 2, "quadros")
	util.igual(q[1].t, 0, "ordenado por tempo")
	util.igual(q[2].juntas.RightElbow[1], 90, "juntas sobrepõem a pose")
	util.igual(q[2].juntas.RightShoulder[1], 10, "pose entra no quadro")
	local nada, motivo = Regra.resolverQuadros(arq, "Ruim")
	util.igual(nada, nil, "pose inexistente = nil")
	assert(string.find(motivo :: string, "naoExiste"), "motivo cita a pose")
	nada = Regra.resolverQuadros(arq, "Junta")
	util.igual(nada, nil, "junta desconhecida = nil")
	nada = Regra.resolverQuadros(arq, "Nada")
	util.igual(nada, nil, "clipe inexistente = nil")
end

-- validarClipe pega os erros que importam ------------------------------------------------------------------------------------
do
	local function clipe(c: any): { string }
		return Regra.validarClipe({ poses = {}, clipes = { X = c } }, "X")
	end
	local function tem(erros: { string }, trecho: string): boolean
		for _, e in erros do
			if string.find(e, trecho, 1, true) then
				return true
			end
		end
		return false
	end
	local bom = {
		duracao = 1,
		loop = false,
		prioridade = "Action",
		quadros = { { t = 0, juntas = { Waist = { 0, 0, 0 } } }, { t = 1, juntas = { Waist = { 10, 0, 0 } } } },
	}
	util.igual(#clipe(bom), 0, "clipe bom sem erros")
	local errado = table.clone(bom)
	errado.duracao = 1.5
	assert(tem(clipe(errado), "último quadro"), "duração diferente do último quadro")
	errado = table.clone(bom)
	errado.prioridade = "Foo"
	assert(tem(clipe(errado), "prioridade"), "prioridade inválida")
	errado = table.clone(bom)
	errado.quadros =
		{ { t = 0, juntas = { LeftElbow = { 0, 0, 0 } } }, { t = 1, juntas = { LeftElbow = { 400, 0, 0 } } } }
	assert(tem(clipe(errado), "fora de"), "cotovelo fora do limite")
	errado = table.clone(bom)
	errado.quadros = { { t = 0.1, juntas = { Waist = { 0, 0, 0 } } }, { t = 1, juntas = { Waist = { 0, 0, 0 } } } }
	assert(tem(clipe(errado), "t=0"), "primeiro quadro fora de zero")
	errado = table.clone(bom)
	errado.quadros = {
		{ t = 0, juntas = { Waist = { 0, 0, 0 } } },
		{ t = 0, juntas = { Waist = { 5, 0, 0 } } },
		{ t = 1, juntas = { Waist = { 0, 0, 0 } } },
	}
	assert(tem(clipe(errado), "não crescentes"), "tempo repetido")
	errado = table.clone(bom)
	errado.loop = true
	assert(tem(clipe(errado), "laço"), "laço com pulo")
	errado = table.clone(bom)
	errado.quadros =
		{ { t = 0, juntas = { Root = { 0, 0, 0, 9, 0, 0 } } }, { t = 1, juntas = { Root = { 0, 0, 0, 0, 0, 0 } } } }
	assert(tem(clipe(errado), "desloca"), "deslocamento grande")
	errado = table.clone(bom)
	errado.quadros =
		{ { t = 0, easing = "Foo-In", juntas = { Waist = { 0, 0, 0 } } }, { t = 1, juntas = { Waist = { 0, 0, 0 } } } }
	assert(tem(clipe(errado), "easing"), "easing inválido")
	local pernas = Regra.validarClipe({
		poses = {},
		clipes = {
			X = {
				duracao = 1,
				quadros = {
					{ t = 0, juntas = { LeftKnee = { 0, 0, 0 } } },
					{ t = 1, juntas = { LeftKnee = { -10, 0, 0 } } },
				},
			},
		},
	}, "X", { proibidas = Regra.PERNAS })
	assert(tem(pernas, "proibida"), "perna proibida")
end

-- decisões do AnimacaoCorpo ---------------------------------------------------------------------------------------------------
do
	util.igual(Regra.clipeAssento("VehicleSeat"), "MotoristaIdle", "motorista")
	util.igual(Regra.clipeAssento("Seat"), "PassageiroIdle", "passageiro")
	util.igual(Regra.clipeAssento(nil), nil, "sem assento")
	util.igual(Regra.clipeMao(5, "direita", 2), "SegurarGalao", "galão")
	util.igual(Regra.clipeMao(0.5, "direita", 2), "SegurarUmaMao", "garrafa")
	util.igual(Regra.clipeMao(nil, "direita", 2), "SegurarUmaMao", "item comum")
	util.igual(Regra.clipeMao(nil, "esquerda", 2), "SegurarUmaMaoEsq", "lanterna")
	util.perto(Regra.velocidadeUso(1.5, 3), 0.5, "uso longo desacelera até 0,5")
	util.perto(Regra.velocidadeUso(1.5, 1.5), 1, "uso igual ao clipe")
	util.perto(Regra.velocidadeUso(1.5, 0.2), 2, "uso curto acelera até 2")
	util.perto(Regra.velocidadeUso(1.5, nil), 1, "sem tempo = 1")
	local lado, peso = Regra.volante(0.05, 0.1)
	util.igual(lado, nil, "zona morta")
	util.igual(peso, 0, "zona morta sem peso")
	lado, peso = Regra.volante(-1, 0.1)
	util.igual(lado, "Esquerda", "esquerda")
	util.perto(peso, 1, "esquerda cheia")
	lado, peso = Regra.volante(0.55, 0.1)
	util.igual(lado, "Direita", "direita")
	util.perto(peso, 0.5, "meio caminho")
	assert(Regra.quedaValida(0.5, 0.35), "queda longa")
	assert(not Regra.quedaValida(0.2, 0.35), "pulo curto não é queda")
	assert(Regra.juntos(1, 1.5, 0.8), "dentro da janela")
	assert(not Regra.juntos(1, 3, 0.8), "fora da janela")
	assert(not Regra.juntos(nil, 1, 0.8), "nunca aconteceu")
end

-- dados dos clipes de corpo --------------------------------------------------------------------------------------------------
-- prioridade esperada por grupo/clipe (decisão em docs/personagens.md §4: Action2 para carro/mão, Action3 para ações de uma vez)
local PRIORIDADE: { [string]: { [string]: string } } = {
	carro = {
		MotoristaIdle = "Action2",
		MotoristaViraEsquerda = "Action3",
		MotoristaViraDireita = "Action3",
		PassageiroIdle = "Action2",
		Entrar = "Action2",
		Sair = "Action2",
	},
	mundo = { Pegar = "Action3", Largar = "Action3", Interagir = "Action3", Abastecer = "Action2" },
	mao = { SegurarUmaMao = "Action2", SegurarUmaMaoEsq = "Action2", SegurarGalao = "Action2", Usar = "Action3" },
	vida = { Morte = "Action4", Queda = "Movement", Aterrissagem = "Movement" },
}
-- só carro e mão são braços/tronco: sem pernas
local SEM_PERNAS: { [string]: boolean } = { carro = true, mao = true }
-- clipes que só repetem se forem Idle/Segurar/Queda/Abastecer/Vira
local LOOP: { [string]: boolean } = {
	MotoristaIdle = true,
	MotoristaViraEsquerda = true,
	MotoristaViraDireita = true,
	PassageiroIdle = true,
	SegurarUmaMao = true,
	SegurarUmaMaoEsq = true,
	SegurarGalao = true,
	Abastecer = true,
	Queda = true,
}

for grupo, clipes in PRIORIDADE do
	local arq = serde.decode("json", fs.readFile(`{PASTA}/{grupo}.json`))
	util.igual(arq.grupo, "corpo/" .. grupo, grupo .. ": campo grupo")
	util.igual(arq.rig, "R15", grupo .. ": rig")
	for nome, prio in clipes do
		assert(arq.clipes[nome], `{grupo}: falta o clipe {nome}`)
		local erros = Regra.validarClipe(arq, nome, { proibidas = if SEM_PERNAS[grupo] then Regra.PERNAS else nil })
		assert(#erros == 0, `{grupo}/{nome}: {table.concat(erros, "; ")}`)
		util.igual(arq.clipes[nome].prioridade, prio, `{grupo}/{nome}: prioridade`)
		util.igual(arq.clipes[nome].loop == true, LOOP[nome] == true, `{grupo}/{nome}: loop`)
		-- id previsto em Config/AnimacoesCorpo
		assert(
			CfgCorpo.animacoes[grupo] and CfgCorpo.animacoes[grupo][nome] ~= nil,
			`{grupo}/{nome}: sem entrada em Config/AnimacoesCorpo`
		)
	end
	for nome in arq.clipes do
		assert(clipes[nome], `{grupo}/{nome}: clipe não previsto no teste (adicione aqui e em Config/AnimacoesCorpo)`)
	end
end
for grupo, clipes in CfgCorpo.animacoes do
	assert(PRIORIDADE[grupo], grupo .. ": grupo do Config sem arquivo")
	for nome in clipes do
		assert(PRIORIDADE[grupo][nome], `{grupo}/{nome}: entrada do Config sem clipe`)
	end
end

-- marcadores que o AnimacaoCorpo espera
do
	local function temMarcador(grupo: string, clipe: string, marcador: string): boolean
		local arq = serde.decode("json", fs.readFile(`{PASTA}/{grupo}.json`))
		for _, q in arq.clipes[clipe].quadros do
			for _, m in q.marcadores or {} do
				if m == marcador then
					return true
				end
			end
		end
		return false
	end
	assert(temMarcador("vida", "Morte", "Congelar"), "Morte precisa do marcador Congelar")
	assert(temMarcador("mundo", "Pegar", "Pegou"), "Pegar precisa do marcador Pegou")
	assert(temMarcador("mundo", "Largar", "Soltou"), "Largar precisa do marcador Soltou")
end

-- clipes de arma continuam coerentes com o validador (estrutura; os limites angulares valem só para o corpo novo)
for _, arq in fs.readDir("assets/animacoes/armas") do
	if arq ~= "mao.json" and string.match(arq, "%.json$") then
		local d = serde.decode("json", fs.readFile("assets/animacoes/armas/" .. arq))
		for nome in d.clipes do
			local quadros = Regra.resolverQuadros(d, nome)
			assert(quadros and #quadros >= 2, `armas/{d.classe}/{nome}: resolverQuadros falhou`)
		end
	end
end

-- folha de quadros
do
	local arq = serde.decode("json", fs.readFile(PASTA .. "/vida.json"))
	local f = Regra.folha(arq, "Morte")
	assert(string.find(f, "Morte  dur=1.3s", 1, true), "cabeçalho da folha")
	assert(string.find(f, "{Congelar}", 1, true), "marcador na folha")
	assert(string.find(f, "Root(88,0,0|0,-2.3,0)", 1, true), "posição na folha")
end

print("Animacao.spec ok")
