-- Números da destruição universal (docs/destruicao.md §3, §6.4, §7). Todos PROVISÓRIO: afinar no playtest.
-- Materiais, classes e matriz de dano: Config/Materiais.

return {
	estagios = { 0.2, 0.4, 0.6, 0.8 }, -- frações de dano em que a peça repinta (0 a 4 estágios)
	escurecerAlvo = { 18, 16, 15 }, -- RGB 0-255
	rachar = { transparencia = 0.1, clarear = 0.08 }, -- vidro, por estágio: Transparency cai e a cor clareia
	pecaInteira = 2.5, -- studs: peça cuja maior dimensão é <= isto é destruída inteira, sem vão
	somImpactoIntervalo = 0.12, -- s por peça
	retalhos = { minimo = 0.8, danoHerdado = 0.5 },
	limites = { buracos = 1500, pecasExtras = 15000 }, -- 2026-11-16: furos de tiro contam aqui (eram 300 / 6000)
	invalidarCaminhos = { raio = 60 }, -- studs: monstros a até isto da quebra recalculam o caminho
	poeira = { quantidade = 30, duracao = 2, vida = { 0.6, 1.1 }, velocidade = { 3, 8 }, tamanho = { 1.5, 4 } },
	explosaoMaxPecas = 400, -- peças consideradas por explosão

	carro = {
		velMin = 12, -- studs/s: abaixo disto o carro não quebra nada
		alcanceBase = 2,
		passoFator = 1.5, -- alcance = alcanceBase + |v| x passo do laço x passoFator
		passoLaco = 0.1, -- s: período do laço de Veiculos (PASSO)
		alturaChao = 0.8, -- a caixa começa isto acima da base do chassi
		larguraExtra = 0.5, -- a caixa é mais larga que o chassi
		larguraVao = 1, -- o vão da parede é a largura do carro mais isto
		alcanceBatida = 3, -- studs de comprimento da caixa da batida (peça mais perto do nariz)
		recuoBatida = 1, -- a caixa da batida começa isto atrás do nariz (o carro já recuou ao ser medido)
		escalaEnergia = 3e-4, -- dano = 0.5 x massa x v^2 x escala (sedan 1520 a 58 st/s = ~767; era 1.5e-4 até 2026-11-16)
		recuoCarroceria = 0.06, -- carroceria perdida por ponto de vida do material destruído (era 0.15)
		folgaAltura = 0.6, -- o vão do carro vai até o teto do chassi mais isto
		soleira = 1.5, -- se o pé do carro está a menos disto da base da parede, o vão desce até o chão (sem degrau)
		atropelo = { velMin = 8, danoPorVel = 1.6, intervalo = 0.4, recuo = 0.1, impulso = 40, velImpulso = 30 },
	},

	-- Lista ordenada: o primeiro prefixo que casa com o Name da peça vence. Nome sem prefixo = indestrutível.
	nomes = {
		{ "Parede", "parede" },
		{ "Fachada", "parede" },
		{ "Divisoria", "parede" },
		{ "Banho", "parede" },
		{ "Provador", "parede" },
		{ "FolhaVidro", "vidro" },
		{ "Vidro", "vidro" },
		{ "Grade", "grade" },
		{ "PortaEnrolar", "grade" },
		{ "PortaoCorrer", "grade" },
		{ "PortaoFaixa", "grade" },
		{ "Laje", "laje" },
		{ "Forro", "laje" },
		{ "TetoCasa", "laje" },
		{ "Teto", "laje" },
		{ "Telhado", "telhado" },
		{ "Piso", "piso" },
		{ "Ladrilho", "piso" },
		{ "Cofre", "cofre" },
	},

	papeis = {
		parede = { destrutivel = true },
		vidro = { destrutivel = true },
		grade = { destrutivel = true },
		laje = { destrutivel = true },
		telhado = { destrutivel = true },
		piso = { destrutivel = false }, -- chão do térreo; furo no piso é decisão pendente
		cofre = { destrutivel = false }, -- pendente
	},

	-- Models de Mapa.Props com atributo Prop nesta lista: todas as peças consultáveis são destrutíveis.
	props = { muro_baixo = true, cerca_madeira = true, cerca_arame = true, guard_rail = true },

	-- Models com atributo Movel/Estrutura nesta lista: vida do grupo inteiro; quebrar destrói o Model.
	grupos = {
		bomba_combustivel = { vida = 150, evento = "combustivel", material = "Metal" },
		tanque_combustivel = { vida = 400, evento = "combustivel", material = "Metal" },
	},

	-- Forma do vão por tipo de dano (o que não está aqui é retângulo; a garra do monstro continua retângulo).
	formaPorTipo = { bala = "elipse", explosao = "elipse", impacto = "carro" },
	formas = {
		elipse = { linha = 0.8, linhasMax = 5 }, -- degraus de ~0,8 stud de altura, no máximo 5
		-- silhueta de frente do carro, de baixo para cima: {de, até (fração da altura), largura (fração)}
		carro = { perfil = { { 0, 0.12, 0.88 }, { 0.12, 0.55, 1 }, { 0.55, 0.8, 0.82 }, { 0.8, 1, 0.6 } } },
	},
	-- Vão que conta como passagem para os monstros (Destruicao.vaoUtil): encosta no chão da peça e tem pelo menos isto.
	vaoPassavel = { largura = 2, altura = 4 },

	-- Furo de tiro (2026-11-16): cada tiro soma dano num ponto da peça (marcas a até `raio` uma da outra somam juntas); passou de
	-- vidaMax x fracao[classe], abre ali um furo em elipse. Espingarda: os chumbos que acertaram a mesma peça somam num tiro só e o
	-- furo tem o tamanho do espalhamento deles (+ margemChumbo). A vida da peça inteira leva só danoGlobal do dano do tiro.
	furo = {
		fracao = { madeira = 0.1, alvenaria = 0.07, metal = 0.1, leve = 0.2 },
		tamanho = 0.6, -- furo de uma bala (studs)
		max = 3.2, -- maior furo de um tiro
		raio = 0.9, -- tiros a até isto de uma marca somam nela
		margemChumbo = 0.6,
		danoGlobal = 0.3,
		maxMarcas = 12, -- marcas guardadas por peça (a mais velha sai)
		poeira = 8, -- partículas do furo
	},

	-- Props que tombam (2026-11-16): vida do Model inteiro; ao quebrar, as peças acima da sapata giram em volta da base e caem;
	-- ao bater no chão tocam `som` e emitem a ação de ruído `acao` (Config/Som.acoes) e, parados, voltam a ficar ancorados.
	derrubar = {
		alturaBase = 1.2, -- peças com centro até isto acima da base ficam (sapata)
		empurrao = 9, -- studs/s dados ao topo na direção da pancada
		velBatida = 10, -- studs/s no topo: abaixo disto não conta como batida
		quedaBatida = 0.45, -- batida = a velocidade do topo caiu para menos que isto da amostra anterior
		amostra = 0.05, -- s entre amostras
		tempoMax = 5, -- s: sem batida até aqui, toca o som assim mesmo
		parado = { vel = 0.8, tempo = 0.8 }, -- parado por isto -> ancora
		tempoAncorar = 10, -- s: ancora de qualquer jeito
		som = "PosteCai",
		acao = "posteCai",
	},
	derrubaveis = {
		poste_luz = { vida = 250, material = "Metal" },
		poste_luz_rodovia = { vida = 320, material = "Metal" },
		poste_madeira = { vida = 260, material = "Wood" },
		semaforo = { vida = 280, material = "Metal" },
		placa_pare = { vida = 90, material = "Metal" },
		placa_velocidade = { vida = 90, material = "Metal" },
		placa_aviso = { vida = 90, material = "Metal" },
		placa_rua = { vida = 110, material = "Metal" },
		caixa_correio = { vida = 120, material = "Metal" },
		telefone_publico = { vida = 160, material = "Metal" },
	},

	-- Tamanho do vão por tipo de dano (studs). info.largura/altura vencem. garra e impacto: a largura é só o
	-- padrão quando a fonte não informa (o Rastejador manda corpo x folga; o carro manda largura + larguraVao).
	buraco = {
		bala = { largura = 2.4, altura = 2.4 }, -- peça inteira vencida a tiro (o furo de cada tiro é o `furo` acima)
		corte = { largura = 3, altura = 6.5 },
		alavanca = { largura = 3, altura = 6.5 },
		soco = { largura = 3, altura = 6.5 },
		marreta = { largura = 3.5, altura = 6.5 },
		garra = { largura = 3, altura = 4.5 },
		impacto = { largura = 6, altura = 5.5 },
		explosao = { largura = 5, altura = 5 },
	},
}
