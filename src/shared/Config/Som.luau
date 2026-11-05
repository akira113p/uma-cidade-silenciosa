-- Números do som (docs/calculos.md §1). Regra: src/shared/Regras/Som.luau. PROVISÓRIO até o playtest.

return {
	metrosPorStud = 0.28,
	tetoAlcance = 600, -- studs; nenhum som é ouvido além disso
	dbPorParede = 10,
	maxParedes = 3,

	-- Base de cada ação (dB)
	acoes = {
		agachado = 30,
		andar = 40,
		correr = 55,
		aterrissar = 50,
		porta = 45,
		golpe = 55,
		vidro = 75,
		carro = 80,
		carroLigar = 70,
		carroFalhar = 62,
		carroBatida = 88,
		buzina = 95,
		pneuEstouro = 90,
		pistola = 110,
		fuzil = 120,
		gritoMonstro = 60,
		paredeQuebrando = 65, -- Rastejador batendo/quebrando parede (docs/rastejador.md)
		abrirCaixa = 35,
		comer = 30,
		beber = 30,
		bandagem = 25,
		kit = 30,
		abastecer = 50, -- mangueira enchendo o carro (a cada 2 s); chute, ajustar no playtest (docs/combustivel.md §3)
		encher = 45, -- encher recipiente na bomba
		despejar = 40, -- despejar recipiente no tanque
	},

	-- Passos por segundo de cada modo (também é o ritmo do balanço da câmera)
	passosPorSegundo = {
		agachado = 1.5,
		andar = 2,
		correr = 3,
	},

	-- Superfícies: modificador em dB e lista de Enum.Material (por nome) que caem nela
	superficies = {
		carpete = { db = -8, materiais = { "Fabric", "Carpet" } },
		gramaBaixa = { db = -5, materiais = { "Grass", "Ground", "Mud", "Sand", "Snow" } },
		concreto = {
			db = 0,
			materiais = {
				"Concrete",
				"Asphalt",
				"Pavement",
				"Brick",
				"Cobblestone",
				"SmoothPlastic",
				"Plastic",
				"Slate",
				"Rock",
				"Basalt",
				"Limestone",
				"Marble",
				"Granite",
			},
		},
		madeira = { db = 3, materiais = { "Wood", "WoodPlanks" } },
		gramaAlta = { db = 5, materiais = { "LeafyGrass" } },
		metal = { db = 8, materiais = { "Metal", "DiamondPlate", "CorrodedMetal", "Foil" } },
		cascalho = { db = 6, materiais = { "Pebble", "Salt", "CrackedLava" } },
		agua = { db = 6, materiais = { "Water", "Glass" } },
	},
	superficiePadrao = "concreto",

	-- Ruído ambiente (dB). workspace:GetAttribute("Clima") escolhe chuva/tempestade; senão dia/noite pelo relógio.
	ambiente = {
		noite = 20,
		dia = 25,
		chuva = 40,
		tempestade = 55,
	},

	-- Voz no microfone (Rede "Voz"): dB que o servidor aceita
	voz = {
		minimo = 25, -- abaixo disso é ignorado (respiração, ruído de fundo)
		maximo = 90,
		intervalo = 0.25, -- s entre amostras aceitas
	},

	-- HUD do medidor
	medidor = {
		amareloAte = 10, -- dB acima do ambiente
	},

	-- Aterrissagem: queda menor que isto (studs) é degrau/rampa e não faz barulho. Pulo normal (6) faz; nascer (+3) não.
	aterrissagem = {
		alturaMinima = 3.5,
	},

	-- Amostragem do servidor
	hzAmostragem = 10,
	velocidadeMinimaPasso = 1.5, -- studs/s; abaixo disso não conta passo
}
