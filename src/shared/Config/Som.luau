-- Números do som (docs/som.md = Som v2; resumo em docs/calculos.md §1). Regras: src/shared/Regras/{Som,Passo,Audicao}.luau.
-- PROVISÓRIO: tudo o que não foi medido no playtest. Interruptores `ligado` valem para o que o usuário ainda não aprovou (docs/som.md §11).

-- Perfil de bandas: dB abaixo do nível da camada (≤ 0; a banda mais forte vale 0). docs/som.md §2.
local function perfil(grave: number, medio: number, agudo: number)
	return { grave = grave, medio = medio, agudo = agudo }
end

-- Ruído ambiente por banda (docs/som.md §3.4): o grave e o médio de chuva/tempestade mascaram menos que o agudo.
local ambienteBandas = {
	noite = { grave = 20, medio = 20, agudo = 18, chao = 0 },
	dia = { grave = 25, medio = 25, agudo = 22, chao = 2 },
	chuva = { grave = 32, medio = 40, agudo = 44, chao = 2 },
	tempestade = { grave = 50, medio = 55, agudo = 55, chao = 8 },
}

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
		carroLigar = 34, -- partida do motor (era 70; 2026-11-14: baixada duas vezes a pedido do usuário)
		carroFalhar = 32, -- motor que não pegou (era 62)
		carroBatida = 88,
		carroDerrapar = 78, -- pneu cantando no freio de mão (Config/Veiculos.derrapagem); chute, ajustar no playtest
		buzina = 95,
		pneuEstouro = 90,
		pistola = 110,
		fuzil = 120,
		gritoMonstro = 60,
		paredeQuebrando = 65, -- Rastejador batendo/quebrando parede (docs/rastejador.md)
		posteCai = 82, -- poste/placa tombado batendo no chão (docs/destruicao.md §11); chute, ajustar no playtest
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
		deitado = 1,
		agachado = 1.5,
		andar = 2,
		correr = 3,
	},

	-- Superfícies (docs/som.md §4.2): `db` = modificador da pisada, `perfil` = bandas da pisada, `chao` = modificador da vibração pelo chão,
	-- `materiais` = Enum.Material (por nome) que caem nela. PROVISÓRIO.
	superficies = {
		carpete = { db = -8, perfil = perfil(-6, 0, -12), chao = -10, materiais = { "Fabric", "Carpet" } },
		terra = { db = -3, perfil = perfil(0, -3, -12), chao = -6, materiais = { "Ground", "Mud", "Sand" } },
		gramaBaixa = { db = -5, perfil = perfil(-6, 0, -6), chao = -8, materiais = { "Grass", "Snow" } },
		concreto = {
			db = 0,
			perfil = perfil(-6, 0, -3),
			chao = 0,
			materiais = { "Concrete", "Asphalt", "Pavement", "SmoothPlastic", "Plastic" },
		},
		pedra = {
			db = 2,
			perfil = perfil(-6, 0, -2),
			chao = 0,
			materiais = {
				"Cobblestone",
				"Brick",
				"Slate",
				"Rock",
				"Basalt",
				"Limestone",
				"Marble",
				"Granite",
				"CrackedLava",
			},
		},
		madeira = { db = 3, perfil = perfil(0, 0, -8), chao = 6, materiais = { "Wood", "WoodPlanks" } }, -- piso oco: passa pelo chão
		gramaAlta = { db = 5, perfil = perfil(-12, -3, 0), chao = -8, materiais = { "LeafyGrass" } },
		metal = {
			db = 8,
			perfil = perfil(-3, -3, 0),
			chao = 8,
			materiais = { "Metal", "DiamondPlate", "CorrodedMetal", "Foil" },
		},
		cascalho = { db = 6, perfil = perfil(-12, -3, 0), chao = -4, materiais = { "Pebble", "Salt" } },
		agua = { db = 6, perfil = perfil(-6, 0, -3), chao = -10, materiais = { "Water" } },
		vidro = { db = 6, perfil = perfil(-15, -4, 0), chao = -4, materiais = { "Glass" } }, -- novo: saiu de `agua`
	},
	superficiePadrao = "concreto",

	-- Ruído ambiente (dB). workspace:GetAttribute("Clima") escolhe chuva/tempestade; senão dia/noite pelo relógio.
	-- `ambiente` (um número) = a banda do meio, para quem ainda lê o ruído como número único (HUD, Sons.tocar, Flores).
	ambiente = {
		noite = ambienteBandas.noite.medio,
		dia = ambienteBandas.dia.medio,
		chuva = ambienteBandas.chuva.medio,
		tempestade = ambienteBandas.tempestade.medio,
	},
	ambienteBandas = ambienteBandas, -- docs/som.md §3.4

	-- Voz no microfone (Rede "Voz"): dB que o servidor aceita
	voz = {
		minimo = 25, -- abaixo disso é ignorado (respiração, ruído de fundo)
		maximo = 90,
		intervalo = 0.25, -- s entre amostras aceitas
	},

	-- HUD do medidor
	-- rotulos: chave (dominante do evento ou, na falta, o tipo) -> texto curto ao lado do último ruído (docs/som.md §7.3)
	medidor = {
		amareloAte = 10, -- dB acima do ambiente
		rotulos = {
			pisada = "passo",
			passo = "passo",
			equipamento = "equipamento",
			respiracao = "respiração",
			arfar = "arfar!",
			vegetacao = "mato",
			vidro = "vidro!",
			lata = "lata!",
			garrafa = "garrafa!",
			folhas = "folhas!",
			galho = "galho!",
			entulho = "entulho!",
			tabua = "tábua!",
			esbarrao = "esbarrão!",
			itemCaiu = "item caiu",
		},
	},

	-- Aterrissagem: queda menor que isto (studs) é degrau/rampa e não faz barulho. Pulo normal (6) faz; nascer (+3) não.
	-- docs/som.md §4.5: perfil {0, 0, -6}; o nível soma 10·log10(altura / alturaRef) (cair 12 studs = +6 dB) e a vibração sai de `chaoBase`
	-- + superfície.chao + o mesmo termo da altura.
	aterrissagem = {
		alturaMinima = 3.5,
		perfil = perfil(0, 0, -6),
		chaoBase = 50,
		alturaRef = 3,
	},

	-- Amostragem do servidor
	hzAmostragem = 10,
	velocidadeMinimaPasso = 1.5, -- studs/s; abaixo disso não conta passo

	-- Propagação (docs/som.md §3.2, §3.3). absorcao em dB por metro (o agudo se perde no ar), parede em dB por parede por banda
	-- (o grave atravessa, o agudo morre). Pelo chão: cai `atenuacao` · log10(m), ignora parede, outro andar tira `outroPiso`.
	absorcao = { grave = 0, medio = 0.01, agudo = 0.03 },
	parede = { grave = 6, medio = 10, agudo = 14 },
	chao = { atenuacao = 40, alturaMesmoPiso = 10, outroPiso = 20 },
	alcanceIteracoes = 20, -- passos da busca binária de Som.alcanceEvento
	-- Erro da posição estimada por banda (docs/som.md §3.7): grave e vibração dizem "tem alguém ali", não "exatamente ali".
	erroBanda = { grave = 1.5, medio = 1.0, agudo = 0.8, chao = 2.0 },

	-- Passo do jogador em camadas (docs/som.md §4.1). `pisada` = as bases de hoje (= acoes.agachado/andar/correr).
	passo = {
		pisada = { deitado = 20, agachado = 30, andar = 40, correr = 55 },
		chaoModo = { deitado = -25, agachado = -20, andar = -4, correr = 4 },
		equip = { deitado = 10, agachado = 16, andar = 24, correr = 36 },
		resp = { parado = 10, deitado = 12, agachado = 14, andar = 18, correr = 30 },
		vegetacao = { deitado = 18, agachado = 24, andar = 36, correr = 46 },
		cargaRef = 10, -- kg: equipamento soma 10·log10(1 + carga / cargaRef)
		respCansaco = 22, -- dB a mais na respiração com estamina 0
		equipamento = { ligado = true, perfil = perfil(-12, -3, 0) }, -- docs/som.md §11 #7
		respiracaoPerfil = perfil(-3, 0, -9),
		vegetacaoPerfil = perfil(-15, -3, 0),
	},

	-- Ofegar parado com estamina baixa (docs/som.md §4.4): a cada `intervalo` s, se o nível da respiração >= `minimo`.
	respiracao = { ligado = true, intervalo = 2, minimo = 25 },

	-- Vegetação (docs/som.md §5.3): nomes de peça/modelo/ancestral (sem maiúsculas) que contam como arbusto/mato. Conferido em
	-- ferramentas/mapa/floresta.luau (peças "Arbusto" e "Fronde" em Mapa.Vegetacao) e props_urbanos.luau (props "arbusto" e "cerca_viva").
	vegetacao = {
		nomes = { "arbusto", "fronde", "moita", "cerca_viva" },
		caixaBaixa = { 1.6, 1.5, 1.6 }, -- studs: caixa só de vegetação ao agachar/deitar (sem esbarrão)
	},

	-- Detritos no chão (docs/som.md §5.1). Nascem em tempo de execução (workspace.Detritos), não no mapa.
	-- nivel = dB por modo; chao = dB absolutos da vibração (nil = não toca o chão); zonas = peso do sorteio por zona do mapa (Mapa.Zonas);
	-- dentro = pode nascer dentro de construção. PROVISÓRIO: números e `raio` (distância do pé em que aciona).
	detritos = {
		ligado = true,
		total = 5000,
		semente = 20261114,
		lote = 100, -- detritos colocados antes de ceder (task.wait)
		tentativas = 12, -- pontos sorteados por detrito antes de desistir
		celula = 8, -- studs: grade espacial (mesma ideia das Flores)
		raioPe = 1.2, -- studs: soma ao raio do detrito para acionar
		recarga = 1.5, -- s: o mesmo jogador não aciona o mesmo detrito antes disso
		normalMinima = 0.9, -- normal.Y mínima do chão para nascer
		livreCaixa = 1.2, -- studs: lado da caixa que tem de estar sem móvel/prop em cima
		chance = { deitado = 1.0, agachado = 0.6, andar = 0.9, correr = 1.0 },
		chute = { min = 2, max = 5 }, -- studs que a lata/garrafa anda ao ser pisada
		partes = { min = 1, max = 3 }, -- peças por detrito (visual PS1, sem textura)
		-- Repartição do total por zona e, nas zonas com construções, a fração dos detritos da zona que nasce DENTRO delas. PROVISÓRIO.
		-- Zonas sem peso aqui (planície, posto da guarda) não recebem detritos. A zona de um ponto segue a prioridade do mapa:
		-- cidade > vila > fábrica > outros > floresta (as quatro faixas de floresta cobrem o mapa inteiro).
		partilha = { cidade = 0.4, vila = 0.2, fabrica = 0.15, floresta = 0.25 },
		dentroFracao = { cidade = 0.6, vila = 0.6, fabrica = 0.6 },
		alturaInterior = { baixo = 3, alto = 2, alcance = 15 }, -- studs: início do raio dentro do prédio (do piso para cima / do teto para baixo) e comprimento
		margemPredio = 0.9, -- fração da meia-largura do prédio onde se sorteia o ponto (fica longe das paredes)
		tipos = {
			vidro = {
				raio = 1.0,
				nivel = { deitado = 22, agachado = 30, andar = 50, correr = 62 },
				perfil = perfil(-15, -4, 0),
				dentro = true,
				zonas = { cidade = 3, fabrica = 2, vila = 1 },
				som = "DetritoVidro",
				cor = { 150, 170, 175 },
				tamanho = { 0.5, 0.08, 0.4 },
				material = "Glass",
			},
			lata = {
				raio = 0.5,
				nivel = { deitado = 18, agachado = 28, andar = 48, correr = 60 },
				perfil = perfil(-12, -3, 0),
				dentro = true,
				zonas = { cidade = 3, vila = 2, fabrica = 1 },
				som = "DetritoLata",
				cor = { 140, 120, 90 },
				tamanho = { 0.4, 0.55, 0.4 },
				material = "Metal",
				chuta = true,
				-- correndo, depois de chutada ela rola: 2º evento `db` dB (mesmo perfil) `atraso` s depois, no ponto final
				rolar = { db = 45, atraso = 0.6, modos = { correr = true }, som = "DetritoLataRolar" },
			},
			garrafa = {
				raio = 0.5,
				nivel = { deitado = 20, agachado = 30, andar = 52, correr = 66 },
				perfil = perfil(-15, -4, 0),
				dentro = true,
				zonas = { cidade = 2, vila = 2 },
				som = "DetritoGarrafa",
				cor = { 70, 110, 80 },
				tamanho = { 0.3, 0.8, 0.3 },
				material = "Glass",
				chuta = true,
				quebraAo = { correr = "vidro" }, -- nesses modos quebra e vira o detrito indicado; nos outros rola como a lata
			},
			folhas = {
				raio = 1.5,
				nivel = { deitado = 15, agachado = 22, andar = 38, correr = 48 },
				perfil = perfil(-12, -2, 0),
				dentro = false,
				zonas = { floresta = 5, vila = 2 },
				som = "DetritoFolhas",
				cor = { 110, 80, 45 },
				tamanho = { 1.8, 0.1, 1.6 },
				material = "Grass",
			},
			galho = {
				raio = 0.6,
				nivel = { deitado = 20, agachado = 32, andar = 50, correr = 58 },
				perfil = perfil(-6, 0, -2),
				chao = 30,
				dentro = false,
				zonas = { floresta = 4, vila = 1 },
				som = "DetritoGalho",
				cor = { 78, 58, 40 },
				tamanho = { 0.15, 0.15, 1.4 },
				material = "Wood",
				some = true, -- quebra e some (uma vez só)
			},
			entulho = {
				raio = 1.0,
				nivel = { deitado = 18, agachado = 26, andar = 44, correr = 56 },
				perfil = perfil(-3, 0, -6),
				chao = 36,
				dentro = true,
				zonas = { cidade = 2, fabrica = 3 },
				som = "DetritoEntulho",
				cor = { 110, 108, 102 },
				tamanho = { 0.9, 0.5, 0.8 },
				material = "Concrete",
			},
			tabua = {
				raio = 1.2,
				nivel = { deitado = 20, agachado = 34, andar = 46, correr = 52 },
				perfil = perfil(0, 0, -10),
				chao = 40,
				dentro = true,
				interiorMadeira = 3, -- só nasce dentro de construção cujo piso é madeira; este é o peso do sorteio
				zonas = {},
				som = "DetritoTabua",
				cor = { 98, 72, 52 },
				tamanho = { 0.35, 0.08, 1.6 },
				material = "WoodPlanks",
			},
		},
	},

	-- Esbarrar em móveis e props (docs/som.md §5.2). Só em andar/correr. Nomes = atributo Movel (mobilia_tamanhos) ou Prop (props_tamanhos).
	-- nivel = dB por modo (correr/andar); chao = dB absolutos (nil = não toca o chão); `padrao` = classe dos demais.
	esbarrar = {
		ligado = true,
		chanceAndar = 0.25,
		recarga = 2, -- s por par (jogador, objeto)
		caixa = { frente = 2, altura = 1.5, tamanho = { 2.2, 2, 1.2 } }, -- centro = HRP + direção × frente, à altura do pé + `altura`
		padrao = "padrao",
		classes = {
			madeiraLeve = {
				nivel = { correr = 58, andar = 44 },
				perfil = perfil(-6, 0, -4),
				som = "EsbarrarMadeira",
				nomes = {
					"cadeira",
					"banqueta",
					"mesa_centro",
					"criado_mudo",
					"cadeira_escritorio",
					"carteira_escolar",
					"mesa_dobravel",
					"cabideiro",
					"luminaria_chao",
					"planta_vaso",
					"cesto_lixo",
					"caixa_papelao",
					"cesto_roupa",
					"cone",
					"palete",
				},
			},
			madeiraPesada = {
				nivel = { correr = 50, andar = 38 },
				perfil = perfil(0, -2, -10),
				chao = 40,
				som = "EsbarrarMadeira",
				nomes = {
					"mesa_jantar",
					"mesa_cozinha",
					"mesa_escritorio",
					"mesa_reuniao",
					"guarda_roupa",
					"comoda",
					"estante_livros",
					"aparador",
					"bau",
					"balcao_loja",
					"balcao_bar",
					"balcao_caixa",
					"banco_igreja",
					"banco_praca",
				},
			},
			metalOco = {
				nivel = { correr = 66, andar = 52 },
				perfil = perfil(-8, -2, 0),
				som = "EsbarrarMetal",
				nomes = {
					"arquivo",
					"arquivo_alto",
					"armario_escola",
					"armario_medico",
					"armario_armas",
					"prateleira_mercado",
					"prateleira_loja",
					"prateleira_garagem",
					"estante_industrial",
					"carrinho_compras",
					"lixeira_rua",
					"cacamba",
					"tambor_oleo",
					"barril",
					"maquina_venda",
					"bicicleta",
					"caixa_ferramentas",
					"galao",
					"cadeira_rodas",
					"cela_grade",
				},
			},
			vidro = {
				nivel = { correr = 70, andar = 56 },
				perfil = perfil(-15, -4, 0),
				som = "EsbarrarVidro",
				nomes = { "vitrine", "geladeira_expositora", "espelho_parede", "espelho_banheiro", "box_chuveiro" },
			},
			estofado = {
				nivel = { correr = 30, andar = 22 },
				perfil = perfil(-6, 0, -15),
				som = "EsbarrarEstofado",
				nomes = {
					"sofa",
					"sofa_pequeno",
					"sofa_recepcao",
					"poltrona",
					"cama_casal",
					"cama_solteiro",
					"beliche",
					"cama_campanha",
					"fardo_feno",
					"fardo_feno_ext",
					"saco_areia",
				},
			},
			eletro = {
				nivel = { correr = 54, andar = 42 },
				perfil = perfil(-3, 0, -6),
				som = "EsbarrarMetal",
				nomes = {
					"geladeira",
					"fogao",
					"maquina_lavar",
					"microondas",
					"freezer_horizontal",
					"computador",
					"copiadora",
					"jukebox",
					"bebedouro",
					"gerador",
					"compressor",
				},
			},
			piano = {
				nivel = { correr = 72, andar = 60 },
				perfil = perfil(0, 0, -2),
				som = "EsbarrarPiano",
				nomes = { "piano", "orgao" },
			},
			veiculo = {
				nivel = { correr = 62, andar = 48 },
				perfil = perfil(0, -2, -4),
				chao = 50,
				som = "EsbarrarVeiculo",
				nomes = { "carro", "carro_destruido", "caminhao", "onibus", "trator", "trailer" },
			},
			padrao = {
				nivel = { correr = 46, andar = 36 },
				perfil = perfil(0, 0, -6),
				som = "EsbarrarMadeira",
				nomes = {},
			},
		},
	},

	-- Item caindo (docs/som.md §5.4): nivel + 10·log10(max(1, altura / alturaRef)) onde o item pousa. A classe vem de `classeQueda` no item
	-- (Config/Itens) ou, sem ele, de `porTipo`. No máximo `maxPorMorte` itens fazem som ao espalhar o inventário de quem morreu.
	queda = {
		ligado = true,
		alturaRef = 3,
		maxPorMorte = 4,
		padrao = "padrao",
		porTipo = { arma = "metal" },
		classes = {
			metal = { nivel = 55, perfil = perfil(-8, -2, 0) },
			vidro = { nivel = 62, perfil = perfil(-15, -4, 0) },
			macio = { nivel = 30, perfil = perfil(-6, 0, -12) },
			padrao = { nivel = 40, perfil = perfil(0, 0, -6) },
		},
	},

	-- Perfil (bandas e vibração pelo chão) das ações que já existem (docs/som.md §7.2). `Ruido.emitir(pos, db, tipo)` monta as bandas
	-- a partir daqui; `chao` é relativo ao nível (nil = não toca o chão). Tipo sem entrada = `perfilPadrao`, sem chão. PROVISÓRIO.
	perfilPadrao = perfil(0, 0, 0),
	perfisAcao = {
		pistola = { perfil = perfil(-2, 0, 0) },
		fuzil = { perfil = perfil(-2, 0, 0) },
		arma = { perfil = perfil(-2, 0, 0) },
		carro = { perfil = perfil(0, -4, -10), chao = -10 },
		carroLigar = { perfil = perfil(0, -4, -10), chao = -10 },
		carroFalhar = { perfil = perfil(0, -4, -10), chao = -10 },
		carroBatida = { perfil = perfil(0, 0, -4), chao = -6 },
		pneuEstouro = { perfil = perfil(0, 0, -4), chao = -6 },
		carroDerrapar = { perfil = perfil(-10, -3, 0) },
		buzina = { perfil = perfil(-8, 0, -2) },
		porta = { perfil = perfil(-4, 0, -6) },
		portaAbrir = { perfil = perfil(-4, 0, -6) },
		portaFechar = { perfil = perfil(-4, 0, -6) },
		portaBater = { perfil = perfil(0, 0, -6), chao = -10 },
		vidro = { perfil = perfil(-15, -4, 0) },
		golpe = { perfil = perfil(0, -2, -8), chao = -8 },
		paredeQuebrando = { perfil = perfil(0, -2, -8), chao = -8 },
		posteCai = { perfil = perfil(0, 0, -4), chao = -4 },
		batidaCorpo = { perfil = perfil(0, -2, -8), chao = -8 },
		gritoMonstro = { perfil = perfil(-6, 0, -3) },
		sonar = { perfil = perfil(-6, 0, -3) },
		rugido = { perfil = perfil(0, -2, -10), chao = -6 },
		pulsoChao = { perfil = perfil(0, -6, -12), chao = -4 },
		raspar = { perfil = perfil(-10, -3, 0) },
		voz = { perfil = perfil(-8, 0, -4) },
		abrirCaixa = { perfil = perfil(-6, 0, -4) },
		comer = { perfil = perfil(-6, 0, -4) },
		beber = { perfil = perfil(-6, 0, -4) },
		bandagem = { perfil = perfil(-6, 0, -4) },
		kit = { perfil = perfil(-6, 0, -4) },
		abastecer = { perfil = perfil(-4, 0, -8) },
		encher = { perfil = perfil(-4, 0, -8) },
		despejar = { perfil = perfil(-4, 0, -8) },
	},
}
