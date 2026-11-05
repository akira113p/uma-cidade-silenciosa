-- Números da destruição universal (docs/destruicao.md §3, §6.4, §7). Todos PROVISÓRIO: afinar no playtest.
-- Materiais, classes e matriz de dano: Config/Materiais.

return {
	estagios = { 0.2, 0.4, 0.6, 0.8 }, -- frações de dano em que a peça repinta (0 a 4 estágios)
	escurecerAlvo = { 18, 16, 15 }, -- RGB 0-255
	rachar = { transparencia = 0.1, clarear = 0.08 }, -- vidro, por estágio: Transparency cai e a cor clareia
	pecaInteira = 2.5, -- studs: peça cuja maior dimensão é <= isto é destruída inteira, sem vão
	somImpactoIntervalo = 0.12, -- s por peça
	retalhos = { minimo = 0.8, danoHerdado = 0.5 },
	limites = { buracos = 300, pecasExtras = 6000 },
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
		escalaEnergia = 1.5e-4, -- dano = 0.5 x massa x v^2 x escala (sedan 1520 a 58 st/s = ~380)
		recuoCarroceria = 0.15, -- carroceria perdida por ponto de vida do material destruído
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

	-- Tamanho do vão por tipo de dano (studs). info.largura/altura vencem. garra e impacto: a largura é só o
	-- padrão quando a fonte não informa (o Rastejador manda corpo x folga; o carro manda largura + larguraVao).
	buraco = {
		bala = { largura = 1.2, altura = 1.2 },
		corte = { largura = 3, altura = 6.5 },
		alavanca = { largura = 3, altura = 6.5 },
		soco = { largura = 3, altura = 6.5 },
		marreta = { largura = 3.5, altura = 6.5 },
		garra = { largura = 3, altura = 4.5 },
		impacto = { largura = 6, altura = 5.5 },
		explosao = { largura = 4, altura = 7 },
	},
}
