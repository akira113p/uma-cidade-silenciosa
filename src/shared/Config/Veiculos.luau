-- Números dos veículos (contrato: docs/veiculos.md). Regras puras: src/shared/Regras/Veiculo. PROVISÓRIO até o playtest.
-- tamanho = caixa em studs com a escala nova dos modelos (personagem sentado cabe: docs/veiculos-modelos.md); sem malha vale este.
-- Origem dos números-base: arquivos vehicle_*_template.txt de pesquisa/veiculos-pz/dados (Project Zomboid), só como proporção.
-- Conversões: velMax = maxSpeed(PZ) x 0.65 (studs/s); massa = mass(PZ) x 1.9;
-- torque (força por roda no chão) = massa x 19.6 (4 rodas = 40% do peso: sobe rampa de ~22°; o viaduto tem 8°). Com o torque do PZ x 3
-- a picape tinha 12% do peso e travava no pé do viaduto (medido 2026-11-04). A aceleração continua pela rampa de velocidade da Direcao.
-- dbBase = 45 + 0.35 x engineLoudness(PZ). Unidades: studs, studs/s, dB. 1 stud = 0.28 m (Config/Som.metrosPorStud).

return {
	tipos = {
		-- PZ CarNormal: mass 800, engineForce 4000, maxSpeed 90, loudness 80
		sedan = {
			nome = "Sedã",
			modelo = "Sedan",
			tamanho = { x = 8.1, y = 5, z = 19.8 },
			massa = 1520,
			velMax = 58,
			torque = 29800,
			dbBase = 73,
			assentos = 4,
			tanque = 55, -- litros (docs/combustivel.md §3)
			peso = 30,
			cor = { { 120, 124, 128 }, { 90, 40, 38 }, { 60, 74, 90 }, { 150, 146, 130 }, { 38, 40, 42 } },
		},
		-- PZ SmallCar: mass 650, engineForce 3600, maxSpeed 70, loudness 55
		compacto = {
			nome = "Compacto",
			modelo = "Compacto",
			tamanho = { x = 7.5, y = 4.9, z = 15.1 },
			massa = 1235,
			velMax = 45,
			torque = 24200,
			dbBase = 64,
			assentos = 4,
			tanque = 40, -- litros (docs/combustivel.md §3)
			peso = 25,
			cor = { { 140, 130, 100 }, { 100, 60, 50 }, { 80, 96, 84 }, { 160, 160, 156 } },
		},
		-- PZ SUV: mass 1000, engineForce 4700, maxSpeed 90, loudness 100
		suv = {
			nome = "SUV",
			modelo = "SUV",
			tamanho = { x = 8.4, y = 5, z = 16.3 },
			massa = 1900,
			velMax = 58,
			torque = 37300,
			dbBase = 80,
			assentos = 4,
			tanque = 70, -- litros (docs/combustivel.md §3)
			peso = 14,
			cor = { { 30, 34, 36 }, { 90, 96, 100 }, { 70, 60, 48 }, { 110, 30, 28 } },
		},
		-- PZ PickUpTruck: mass 1030, engineForce 4000, maxSpeed 70, loudness 110
		pickup = {
			nome = "Picape",
			modelo = "Pickup",
			tamanho = { x = 6.7, y = 4.8, z = 15.4 },
			massa = 1960,
			velMax = 45,
			torque = 38500,
			dbBase = 84,
			assentos = 2,
			tanque = 80, -- litros (docs/combustivel.md §3)
			peso = 14,
			cor = { { 130, 120, 90 }, { 70, 76, 60 }, { 100, 50, 40 }, { 140, 140, 136 } },
		},
		-- PZ StepVan: mass 1160, engineForce 3700, maxSpeed 70, loudness 100 (3 lugares em vez de 2: transporte)
		van = {
			nome = "Van",
			modelo = "Van",
			tamanho = { x = 6.6, y = 4.9, z = 14.6 },
			massa = 2200,
			velMax = 45,
			torque = 43200,
			dbBase = 80,
			assentos = 3,
			tanque = 90, -- litros (docs/combustivel.md §3)
			peso = 9,
			cor = { { 170, 170, 164 }, { 80, 86, 100 }, { 110, 100, 70 } },
		},
		-- PZ CarSports: mass 800, engineForce 5700, maxSpeed 120, loudness 90
		esportivo = {
			nome = "Esportivo",
			modelo = "Esportivo",
			tamanho = { x = 8, y = 4.9, z = 19.9 },
			massa = 1520,
			velMax = 78,
			torque = 38000,
			dbBase = 76,
			assentos = 2,
			tanque = 50, -- litros (docs/combustivel.md §3)
			peso = 4,
			cor = { { 150, 30, 28 }, { 30, 32, 36 }, { 170, 150, 40 } },
		},
	},

	-- Condição sorteada no mapa. peso: 'inteiro' é raro, a maioria não anda bem (nada de conserto no jogo).
	-- motor/carroceria: faixas {min, max}. As chances são por peça, 0..1.
	condicoes = {
		inteiro = {
			peso = 6,
			motor = { 70, 100 },
			carroceria = { 70, 100 },
			chanceMotorZero = 0,
			pneuFurado = 0.05,
			pneuFaltando = 0,
			vidroQuebrado = 0.08,
			vidroFaltando = 0,
			pecaFaltando = 0.02,
			queimado = false,
		},
		avariado = {
			peso = 34,
			motor = { 25, 80 },
			carroceria = { 35, 80 },
			chanceMotorZero = 0.15,
			pneuFurado = 0.25,
			pneuFaltando = 0.05,
			vidroQuebrado = 0.35,
			vidroFaltando = 0.08,
			pecaFaltando = 0.12,
			queimado = false,
		},
		destruido = {
			peso = 38,
			motor = { 0, 40 },
			carroceria = { 5, 40 },
			chanceMotorZero = 0.45,
			pneuFurado = 0.4,
			pneuFaltando = 0.2,
			vidroQuebrado = 0.5,
			vidroFaltando = 0.3,
			pecaFaltando = 0.35,
			queimado = false,
		},
		queimado = {
			peso = 22,
			motor = { 0, 0 },
			carroceria = { 0, 15 },
			chanceMotorZero = 1,
			pneuFurado = 0,
			pneuFaltando = 1,
			vidroQuebrado = 0,
			vidroFaltando = 1,
			pecaFaltando = 0.6,
			queimado = true,
		},
		-- Gasolina ao nascer carro do mapa (Regras/Veiculo.sortear): fração do tanque entre min e max; chanceVazio nasce seco.
		-- Não é condição sorteável (fica fora da lista de pesos); queimado sempre nasce vazio.
		combustivel = { min = 0.05, max = 0.6, chanceVazio = 0.15 },
	},

	-- Todo prop 'carro'/'carro_destruido' do mapa vira carro nosso (2026-11-04); os tombados nascem deitados e destruídos.
	distanciaAcordar = 250, -- studs; mais longe disto o carro fica ancorado

	-- Carros do mapa sob demanda: o servidor decide as vagas na abertura e só cria o modelo perto dos jogadores.
	mapa = {
		raioCriar = 350, -- studs: jogador mais perto que isto cria o carro da vaga
		raioRemover = 450, -- studs: nenhum jogador mais perto que isto remove o carro (se nunca foi mexido)
		criarPorCiclo = 4, -- criações por ciclo do laço
		intervalo = 1.5, -- s entre ciclos
		motor = { 60, 100 }, -- carro operacional
		carroceria = { 70, 100 },
		escalaRelaxada = 0.7, -- caixa de colisão quando nenhum tipo cabe (compacto destruído)
		presoDistancia = 14, -- studs: bloqueio nos dois sentidos abaixo disto = preso (6 deixou passar uma van de garagem que não saía)
		presoAlcance = 25, -- studs medidos para frente e para trás
		presoElevacao = 1.2, -- studs acima do chão onde a caixa começa
	},

	-- Efeito dos defeitos (Regras/Veiculo.limites). Fatores multiplicam por pneu.
	defeitos = {
		velPneuFurado = 0.78,
		velPneuFaltando = 0.55,
		velMinima = 0.15, -- piso do fator de velocidade por pneus
		velMotorMin = 0.45, -- fator de velMax com motor em 0 (motor 100 = 1)
		torqueMotorMin = 0.5,
		aderenciaFurado = 0.7,
		aderenciaFaltando = 0.4,
		puxaFurado = 0.5, -- peso do pneu furado no puxão lateral (faltando = 1)
		puxaTraseiro = 0.5, -- pneu traseiro puxa menos que o dianteiro
	},

	ligar = { chanceMin = 0.25, chanceMax = 0.97 }, -- tentarLigar: sobe com o motor (0..100)

	-- Servidor: mola das rodas. Massa média ~1700; rigidez para ~0.5 stud de compressão por roda. Afinar no Studio.
	-- alturaExtra: studs a mais de vão sobre a altura de projeto (a mola nasce com a compressão do peso já compensada).
	suspensao = { comprimento = 1.4, curso = 0.7, rigidez = 180000, amortecimento = 6000, alturaExtra = 0.25 },
	-- Quanto a mola encurta (studs de FreeLength) com pneu ruim.
	queda = { furado = 0.45, faltando = 0.9 },

	-- Batida: deltaV = variação horizontal de velocidade entre amostras (studs/s).
	batida = {
		limiarDeltaV = 14, -- abaixo disto nada muda
		deltaVTotal = 50, -- severidade 1 (batida total)
		escalaCarroceria = 1.2, -- dano na carroceria por deltaV
		escalaMotorFrente = 0.9,
		escalaMotorOutros = 0.15,
		chanceVidroLado = 1.2, -- x severidade, vidro do lado atingido
		chanceVidroOutros = 0.25,
		chancePneu = 0.5, -- x severidade, pneus do lado atingido
		danoOcupante = { limiar = 20, porDeltaV = 1.1, maximo = 90 }, -- vida: (deltaV - limiar) x porDeltaV
	},

	-- Tiro/golpe em peça: chance = chanceX x dano / danoReferencia (teto 1).
	tiro = {
		danoReferencia = 20,
		chancePneu = 0.7,
		chanceVidro = 0.85,
		danoMotor = 0.6, -- vida do motor tirada por dano
		danoCarroceria = 0.8,
	},

	ruido = {
		intervaloMotor = 1.5, -- s entre emissões com motor ligado
		aceleracaoDb = 10, -- dbMotor: sobe de ocioso (dbBase) até dbBase + isto na velocidade máxima
		bonusMotorRuim = 8, -- dB a mais com motor em 0 (proporcional)
		bonusCapoFaltando = 4,
	},

	-- sair: E dentro do carro (evento SairCarro); pular também sai. trocarBanco: F, vai para o próximo banco livre (evento TrocarBanco).
	teclas = { ligar = { "G" }, buzina = { "H" }, sair = { "E" }, trocarBanco = { "F" } },

	-- Cabine (cliente): tremor/roll opcionais. A posição do olho NÃO é daqui: vem por tipo de Config/VeiculosMalhas
	-- (olho = topo do banco + 2.70 studs, ver docs/veiculos-modelos.md) e chega ao cliente no atributo OlhoLocal do modelo.
	camera = {},
}
