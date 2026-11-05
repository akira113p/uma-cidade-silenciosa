-- Visual padrão dos jogadores (todos iguais): personagem em blocos, montado por código em src/server/Aparencia.luau.
-- Referência (imagem do usuário, 2026-11-02): corpo esbelto e alto, cabeça cúbica marrom escura com cabelo trançado
-- dourado, suéter amarelo de tricô com bolso e cordões, cinto preto, bermuda bege de tricô, pernas escuras e tênis rosa
-- de sola branca. Cores em RGB 0..255; medidas de bloco em fração do tamanho da peça do R15 (ou studs onde dito).

return {
	-- Escalas do R15 aplicadas a todo jogador (iguala o corpo; o avatar de cada um tinha proporções próprias).
	-- Largura/profundidade baixas = corpo esbelto como na referência (tronco ~0,62 mais estreito que alto).
	escala = {
		BodyHeightScale = 1.05,
		BodyWidthScale = 0.68,
		BodyDepthScale = 0.78,
		HeadScale = 1,
		BodyTypeScale = 0,
		BodyProportionScale = 0,
	},
	esperaEscala = 0.6, -- s para o motor refazer o tamanho das peças antes de medir

	cores = {
		pele = { 70, 36, 26 },
		perna = { 52, 28, 22 },
		suter = { 218, 176, 38 },
		costura = { 182, 142, 24 },
		bolso = { 176, 136, 26 },
		cordao = { 238, 226, 196 },
		cinto = { 22, 22, 24 },
		fivela = { 196, 196, 202 },
		calcao = { 194, 154, 112 },
		costuraCalcao = { 168, 128, 90 },
		sapato = { 206, 118, 172 },
		sola = { 205, 205, 200 },
		cabelo = { 222, 192, 134 },
		olhoBranco = { 245, 245, 240 },
		pupila = { 14, 14, 16 },
		sobrancelha = { 214, 170, 110 },
		boca = { 214, 162, 112 },
		lingua = { 226, 104, 134 },
	},

	-- Cabeça cúbica: largura = tronco × larguraSobreTronco; altura e profundidade em fração da largura.
	cabeca = { larguraSobreTronco = 1.14, alturaSobreLargura = 0.9, profundidadeSobreLargura = 0.9 },

	-- Cabelo trançado: laje no topo, tranças (bolinhas) na borda da frente e de trás, faixas atrás e nas laterais.
	cabelo = {
		lajeEspessura = 0.22, -- studs
		trancas = 8, -- por fileira (frente e trás)
		trancaDiametro = 0.34, -- studs
		faixaTras = 0.45, -- fração da altura da cabeça
		faixaLado = 0.38,
	},

	-- Parte do R15 -> grupo de cor. "cabeca" ganha rosto/cabelo e some na primeira pessoa.
	partes = {
		Head = "cabeca",
		UpperTorso = "suter",
		LowerTorso = "cinto",
		LeftUpperArm = "suter",
		LeftLowerArm = "suter",
		RightUpperArm = "suter",
		RightLowerArm = "suter",
		LeftHand = "pele",
		RightHand = "pele",
		LeftUpperLeg = "calcao",
		RightUpperLeg = "calcao",
		LeftLowerLeg = "perna",
		RightLowerLeg = "perna",
		LeftFoot = "sapato",
		RightFoot = "sapato",
	},
	-- Grupos feitos de tecido (resto é plástico liso)
	tecido = { suter = true, calcao = true },

	-- Costura vertical (tricô): faces, cor e quantidade de linhas por face
	costurasEm = {
		UpperTorso = { faces = { "Front", "Back", "Left", "Right" }, cor = "costura", linhas = 9 },
		LeftUpperArm = { faces = { "Front", "Back", "Left", "Right" }, cor = "costura", linhas = 5 },
		RightUpperArm = { faces = { "Front", "Back", "Left", "Right" }, cor = "costura", linhas = 5 },
		LeftLowerArm = { faces = { "Front", "Back", "Left", "Right" }, cor = "costura", linhas = 5 },
		RightLowerArm = { faces = { "Front", "Back", "Left", "Right" }, cor = "costura", linhas = 5 },
		LeftUpperLeg = { faces = { "Front", "Back", "Left", "Right" }, cor = "costuraCalcao", linhas = 5 },
		RightUpperLeg = { faces = { "Front", "Back", "Left", "Right" }, cor = "costuraCalcao", linhas = 5 },
	},
	transparenciaCostura = 0.45,

	-- Tênis: a sola branca é uma fração da altura do pé; o resto é o cabedal rosa.
	solaFracao = 0.45,
	solaFolga = 1.05, -- a sola é um pouco maior que o cabedal

	etiquetaCabeca = "AparenciaCabeca", -- CollectionService: o cliente esconde na primeira pessoa
	distanciaPrimeiraPessoa = 1.6, -- studs da câmera à cabeça para contar como primeira pessoa
}
