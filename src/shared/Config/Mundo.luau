-- Layout do mapa (gerado por ferramentas/gerar_mapa.luau → mapa/Mapa.rbxm). Contrato dos módulos: docs/mapa-v2.md.
-- Coordenadas em studs; (0, 0) é o centro do mapa; o chão plano das áreas construídas fica em Y = 0.5. PROVISÓRIO.
-- Só o gerador e o checker leem este arquivo (o jogo não).

return {
	tamanho = 4000, -- lado do mapa (quadrado), centro em 0,0
	pecaMaxima = 2048, -- limite do Roblox por eixo
	semente = 20261102, -- mesma semente = mesmo mapa; mudar só para sortear outro layout
	limitePecas = 165000, -- orçamento total (subiu de 150 mil na integração: interiores reais pesam); por pasta em docs/mapa-v2.md

	cidade = {
		centro = { 0, 0 },
		lado = 900, -- 6 × 6 quarteirões (era 750)
		quarteirao = 120,
		rua = 30, -- asfalto
		calcada = 6, -- concreto, em volta de cada quarteirão
		alturaAndar = 12,
		-- Regiões urbanas por distância (Chebyshev, em studs) ao centro da cidade
		regioes = {
			centro = 190, -- até aqui: só prédios altos (escritórios, torres, hotéis, apartamentos)
			comercial = 330, -- até aqui: comércio, serviços, prédios médios
			-- além: residencial (casas, pequenos comércios, igreja, escola)
		},
		gramaAltaManchas = 30, -- manchas de LeafyGrass em terrenos baldios (só na região residencial)
	},

	vilas = {
		{ nome = "Vila Norte", centro = { 0, -1500 }, lado = 300, casas = 12, posto = true },
		{ nome = "Vila Leste", centro = { 1500, 600 }, lado = 300, casas = 12, posto = true },
		{ nome = "Vila Oeste", centro = { -1500, 700 }, lado = 300, casas = 12, posto = true },
	},

	fabrica = {
		centro = { 1300, -1300 },
		tamanho = { 250, 200 },
		galpoes = 4,
		material = "Metal",
		piso = "DiamondPlate",
	},
	planicie = { centro = { -1200, -1200 }, lado = 600, material = "Grass", gramaAlta = 0.3 }, -- fazenda
	guardaFlorestal = { centro = { -400, 1600 }, tamanho = { 40, 30 }, material = "WoodPlanks", torre = true },

	-- Avenidas de 40 ligando cidade → cada vila, fábrica e posto da guarda (retas; o plano as transforma em estradas)
	avenida = { largura = 40, material = "Asphalt" },

	floresta = {
		-- Floresta boreal de pinheiros (norte da Europa): pinheiro-silvestre, abeto, bétula, tocos, pedras, mirtilo.
		arvores = 7000, -- orçamento de árvores; o módulo da floresta decide a mistura
		distanciaMinima = 12,
		material = "Grass", -- chão fora das áreas construídas
		gramaAlta = 0.15, -- fração do chão da floresta em LeafyGrass (manchas)
	},

	muroBorda = 60, -- altura do muro invisível na borda

	-- Pontos que o gerador cria em Mapa.Pontos (ver docs/mapa-v2.md)
	pontosLootPorConstrucao = 1, -- mínimo por construção (os interiores podem pedir mais)
	spawnsPorVila = 6,

	-- ---------------------------------------------------------------------------------------------------------------
	-- Relevo: grade de lajes inclinadas (módulo relevo). Áreas planas (cidade, pads, estradas, POIs) ficam em Y = 0.5.
	-- ---------------------------------------------------------------------------------------------------------------
	relevo = {
		celula = 48, -- lado de cada laje do terreno
		amplitude = 20, -- altura máxima das colinas (studs)
		comprimentoOnda = 380, -- tamanho típico de uma colina
		margemPlano = 60, -- distância em que o relevo "sobe" a partir de uma área plana
		espessuraLaje = 8,
	},

	-- ---------------------------------------------------------------------------------------------------------------
	-- Rios: pts = linha central (o plano suaviza). largura = canal d'água; margem = talude de cada lado;
	-- profundidade = de Y = 0 ao leito. A água é Terrain (src/server/Rios.luau); o leito e as margens são Parts.
	-- ---------------------------------------------------------------------------------------------------------------
	rios = {
		{
			nome = "Rio Grande",
			largura = 44,
			margem = 26,
			profundidade = 7,
			pts = {
				{ -760, -2000 },
				{ -790, -1700 },
				{ -740, -1400 },
				{ -770, -1000 },
				{ -700, -600 },
				{ -760, -200 },
				{ -700, 200 },
				{ -740, 500 },
				{ -690, 800 },
				{ -720, 1100 },
				{ -640, 1450 },
				{ -700, 1750 },
				{ -660, 2000 },
			},
		},
		{
			nome = "Rio Leste",
			largura = 32,
			margem = 22,
			profundidade = 6,
			pts = {
				{ 900, -2000 },
				{ 860, -1700 },
				{ 930, -1400 },
				{ 880, -1000 },
				{ 940, -600 },
				{ 880, -300 },
				{ 930, 0 },
				{ 880, 300 },
				{ 950, 600 },
				{ 900, 900 },
				{ 960, 1200 },
				{ 900, 1500 },
				{ 940, 1800 },
				{ 900, 2000 },
			},
		},
		{
			nome = "Riacho Oeste", -- desemboca no Rio Grande
			largura = 14,
			margem = 12,
			profundidade = 4,
			pts = {
				{ -2000, 300 },
				{ -1700, 180 },
				{ -1400, 260 },
				{ -1100, 150 },
				{ -900, 330 },
				{ -740, 500 },
			},
		},
	},

	-- ---------------------------------------------------------------------------------------------------------------
	-- Estradas: polilinhas só com segmentos retos nos eixos X ou Z (a quebra é em ângulo reto). material: Asphalt (faixa
	-- central), Pavement/Slate (cascalho) ou Ground (terra). Onde cruzam um rio o plano cria uma ponte automaticamente.
	-- As avenidas de `avenida` entram no plano com estes mesmos campos (ver ferramentas/mapa/plano.luau).
	-- ---------------------------------------------------------------------------------------------------------------
	estradas = {
		{
			nome = "Estrada_PlanicieNorte", -- fazenda → Vila Norte
			largura = 24,
			material = "Asphalt",
			pts = { { -900, -1400 }, { -300, -1400 }, { -300, -1500 }, { -150, -1500 } },
		},
		{
			nome = "Estrada_NorteFabrica", -- Vila Norte → fábrica
			largura = 24,
			material = "Asphalt",
			pts = { { 150, -1500 }, { 600, -1500 }, { 600, -1300 }, { 1175, -1300 } },
		},
		{
			nome = "Estrada_LesteFabrica", -- Vila Leste → fábrica
			largura = 24,
			material = "Asphalt",
			pts = { { 1500, 450 }, { 1500, -1300 }, { 1425, -1300 } },
		},
		{
			nome = "Rodovia_Leste", -- N–S, embaixo do Viaduto_Leste; sai da Avenida_Fabrica_A e vai até o posto da guarda
			largura = 30,
			material = "Asphalt",
			pts = { { 650, -300 }, { 650, 1600 } },
		},
		{
			nome = "Estrada_Sul", -- posto da guarda → Rodovia_Leste
			largura = 24,
			material = "Asphalt",
			pts = { { -350, 1600 }, { 650, 1600 } },
		},
		{
			nome = "Estrada_Guarda_Oeste", -- posto da guarda → Rodovia_Oeste (cruza o Rio Grande)
			largura = 24,
			material = "Asphalt",
			pts = { { -450, 1600 }, { -1100, 1600 } },
		},
		{
			nome = "Rodovia_Oeste", -- N–S, embaixo do Viaduto_Oeste; da fazenda ao sul (cruza o Riacho Oeste)
			largura = 30,
			material = "Asphalt",
			pts = { { -1100, -900 }, { -1100, 1600 } },
		},
		{
			nome = "Estrada_Cemiterio",
			largura = 18,
			material = "Pavement",
			pts = { { -20, -850 }, { -220, -850 } },
		},
		{
			nome = "Estrada_Acampamento",
			largura = 20,
			material = "Pavement",
			pts = { { 635, 1250 }, { 450, 1250 } },
		},
		{
			nome = "Estrada_Serraria",
			largura = 16,
			material = "Ground",
			pts = { { -1115, -400 }, { -1190, -400 } },
		},
		{
			nome = "Estrada_Parada",
			largura = 20,
			material = "Asphalt",
			pts = { { 665, 1000 }, { 740, 1000 } },
		},
	},

	-- Viadutos: a `estrada` (que precisa ser reta no trecho) passa elevada sobre a `sobre` (outra estrada), em `centro`.
	-- O deck fica em Y = altura; as rampas descem até o chão nas duas pontas (comprimento = altura × 7).
	viadutos = {
		{
			nome = "Viaduto_Leste",
			estrada = "Avenida_Leste",
			sobre = "Rodovia_Leste",
			centro = { 650, 600 },
			altura = 14,
		},
		{
			nome = "Viaduto_Oeste",
			estrada = "Avenida_Oeste",
			sobre = "Rodovia_Oeste",
			centro = { -1100, 700 },
			altura = 14,
		},
	},

	-- Passarelas de pedestres sobre rios (sem estrada): eixo "x" = anda ao longo de X
	pontesPedestres = {
		{ nome = "Passarela_Riacho", rio = "Riacho Oeste", centro = { -1400, 260 }, eixo = "z", largura = 6 },
		{ nome = "Passarela_Leste", rio = "Rio Leste", centro = { 930, 0 }, eixo = "x", largura = 6 },
	},

	-- Pontos de interesse fora da cidade/vilas. tipo = chave do construtor em ferramentas/mapa/areas.luau.
	-- tam = {largura em X, profundidade em Z}. Cada um ganha um pad plano e (quando há) a estrada que o liga.
	pois = {
		{ nome = "Cemitério Maple Rise", tipo = "cemiterio", centro = { -300, -850 }, tam = { 160, 160 } },
		{ nome = "Acampamento Halvorsen", tipo = "acampamento", centro = { 350, 1250 }, tam = { 200, 200 } },
		{ nome = "Serraria", tipo = "serraria", centro = { -1250, -400 }, tam = { 120, 100 } },
		{ nome = "Parada da Rodovia", tipo = "parada", centro = { 760, 1000 }, tam = { 120, 160 } },
		{ nome = "Igreja da Estrada", tipo = "igrejaIsolada", centro = { -1010, 1200 }, tam = { 90, 90 } },
		{ nome = "Ferro-velho", tipo = "ferroVelho", centro = { 1100, -800 }, tam = { 120, 100 } },
	},
}
