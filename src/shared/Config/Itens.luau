-- Itens, inventário e loot. Regra de sorteio: src/shared/Regras/Loot.luau. PROVISÓRIO.
-- tipo: "comida" | "bebida" | "cura" | "arma" | "municao" | "lanterna" | "recipiente"
-- uso: tempo (s) parado usando; ruido = nome da ação em Config/Som.acoes; som = nome lógico em Config/Sons.
-- Recipiente (gasolina): litros e troca vazio/cheio ficam em Config/Combustivel.recipientes (cada id daqui tem entrada lá).
-- Arma: item.arma = id em Config/Armas (mesmo id do item). Munição: Config/Armas.armas[x].municao aponta para o id daqui.
-- Munição achada no mapa vale UM PENTE INTEIRO por sorteio (decisão do usuário 2026-11-14): `pente` = balas de um pente
-- (pistola 17, rifle 30, escopeta 6 = tubo cheio, míssil 1); toda `qtd` de loot da munição é {pente, pente} e a pilha do slot
-- guarda 2 pentes. O inventário continua contando BALAS (tests/ArmasPane.spec confere que loot e `pente` não se separam).

return {
	slots = 8, -- tamanho do inventário
	empilhamentoPadrao = 1,
	-- Peso (docs/som.md §4.3): `peso` (kg, por unidade) em cada item soma na carga do jogador e aumenta o barulho do passo (camada de equipamento).
	-- Não confundir com o `peso` das tabelas de loot (chance de sorteio). Sem o campo vale `pesoPadrao`. PROVISÓRIO.
	-- `classeQueda` (opcional) = som do item ao cair (Config/Som.queda.classes); sem ele vale Config/Som.queda.porTipo[tipo] ou "padrao".
	pesoPadrao = 0.5,

	-- Arma de fogo achada no chão (caixa/bolsa sem estado) nasce com o pente sorteado entre estas frações da capacidade.
	penteLoot = { 0.4, 1 },

	itens = {
		enlatado = {
			nome = "Enlatado",
			peso = 0.4,
			classeQueda = "metal",
			tipo = "comida",
			fome = 35,
			uso = 3,
			ruido = "comer",
			som = "Comer",
			pilha = 3,
		},
		barra = {
			nome = "Barra de cereal",
			peso = 0.4,
			classeQueda = "macio",
			tipo = "comida",
			fome = 15,
			uso = 1.5,
			ruido = "comer",
			som = "Comer",
			pilha = 5,
		},
		agua = {
			nome = "Garrafa d'água",
			peso = 0.4,
			classeQueda = "vidro",
			tipo = "bebida",
			sede = 40,
			uso = 2,
			ruido = "beber",
			som = "Beber",
			pilha = 3,
		},
		refrigerante = {
			nome = "Refrigerante",
			peso = 0.4,
			classeQueda = "vidro",
			tipo = "bebida",
			sede = 20,
			fome = 5,
			uso = 1.5,
			ruido = "beber",
			som = "Beber",
			pilha = 3,
		},
		bandagem = {
			nome = "Bandagem",
			peso = 0.1,
			classeQueda = "macio",
			tipo = "cura",
			cura = 15,
			uso = 5,
			ruido = "bandagem",
			som = "Bandagem",
			pilha = 5,
		},
		kit = {
			nome = "Kit médico",
			peso = 1,
			classeQueda = "macio",
			tipo = "cura",
			cura = 40,
			uso = 8,
			ruido = "kit",
			som = "Bandagem",
			pilha = 1,
		},
		faca = { nome = "Faca", peso = 0.3, tipo = "arma", arma = "faca", pilha = 1 },
		peDeCabra = { nome = "Pé de cabra", peso = 2, tipo = "arma", arma = "peDeCabra", pilha = 1 },
		machado = { nome = "Machado", peso = 2.5, tipo = "arma", arma = "machado", pilha = 1 },
		pistola = { nome = "Pistola", peso = 1, tipo = "arma", arma = "pistola", pilha = 1 },
		beretta = { nome = "Beretta 92FS", peso = 1, tipo = "arma", arma = "beretta", pilha = 1 },
		carabinaM5 = { nome = "Carabina M5", peso = 3.5, tipo = "arma", arma = "carabinaM5", pilha = 1 },
		ar15 = { nome = "AR-15", peso = 3.5, tipo = "arma", arma = "ar15", pilha = 1 },
		ak74 = { nome = "AK-74", peso = 4, tipo = "arma", arma = "ak74", pilha = 1 },
		escopeta = { nome = "Escopeta", peso = 4, tipo = "arma", arma = "escopeta", pilha = 1 },
		escopetaM1912 = {
			nome = "Escopeta Trincheira M1912",
			peso = 4.5,
			tipo = "arma",
			arma = "escopetaM1912",
			pilha = 1,
		},
		lancaFoguetes = { nome = "Lança-foguetes", peso = 6, tipo = "arma", arma = "lancaFoguetes", pilha = 1 },
		-- Gold Bright (2026-11-15): viewmodel em Config/ArmasGB. Fora do loot (só pelo menu de admin) até o playtest.
		tt33 = { nome = "TT-33", peso = 0.9, tipo = "arma", arma = "tt33", pilha = 1 },
		ots20 = { nome = "OTs-20 Gnom", peso = 1.1, tipo = "arma", arma = "ots20", pilha = 1 },
		mp5 = { nome = "MP5", peso = 3, tipo = "arma", arma = "mp5", pilha = 1 },
		pp91 = { nome = "PP-91 Kedr", peso = 1.6, tipo = "arma", arma = "pp91", pilha = 1 },
		sr3m = { nome = "SR-3M", peso = 2.5, tipo = "arma", arma = "sr3m", pilha = 1 },
		ots48k = { nome = "OTs-48K", peso = 4.5, tipo = "arma", arma = "ots48k", pilha = 1 },
		rmb93 = { nome = "RMB-93", peso = 3.8, tipo = "arma", arma = "rmb93", pilha = 1 },
		toz34 = { nome = "TOZ-34", peso = 3.2, tipo = "arma", arma = "toz34", pilha = 1 },
		canoChumbo = { nome = "Cano de chumbo", peso = 1.5, tipo = "arma", arma = "canoChumbo", pilha = 1 },
		municaoPistola = { nome = "Munição de Pistola", peso = 0.02, tipo = "municao", pente = 17, pilha = 34 },
		municaoRifle = { nome = "Munição de Rifle", peso = 0.02, tipo = "municao", pente = 30, pilha = 60 },
		municaoEscopeta = { nome = "Munição de Escopeta", peso = 0.02, tipo = "municao", pente = 6, pilha = 12 },
		municaoMissil = { nome = "Munição de Míssil", peso = 2, tipo = "municao", pente = 1, pilha = 2 },
		lanterna = { nome = "Lanterna", peso = 0.5, tipo = "lanterna", pilha = 1 }, -- equipa pela barra; números em Config/Lanterna
		-- Recipientes de gasolina (docs/combustivel.md §6.5). Segurar na mão: clicar o slot; despejar no carro pela tampa.
		garrafaVazia = { nome = "Garrafa vazia", peso = 0.2, classeQueda = "vidro", tipo = "recipiente", pilha = 3 },
		garrafaGasolina = {
			nome = "Garrafa de gasolina",
			peso = 1,
			classeQueda = "vidro",
			tipo = "recipiente",
			pilha = 3,
		},
		galaoVazio = { nome = "Galão vazio", peso = 0.5, classeQueda = "metal", tipo = "recipiente", pilha = 1 },
		galaoGasolina = {
			nome = "Galão de gasolina (5 L)",
			peso = 4,
			classeQueda = "metal",
			tipo = "recipiente",
			pilha = 1,
		},
	},

	-- Cura vai para a parte mais ferida que não está zerada; se todas zeradas (não fatais), a mais ferida.
	-- slot (opcional): posição fixa da barra, se estiver livre (senão vai para o primeiro livre).
	kitInicial = { { id = "barra", qtd = 1 }, { id = "agua", qtd = 1 }, { id = "lanterna", qtd = 1, slot = 5 } },

	-- Tabelas de loot por tipo de ponto (atributo "Tabela" do ponto no mapa). { rolagens = {min, max}, itens = { {id, peso, qtd = {min, max}} } }.
	tabelas = {
		casa = {
			rolagens = { 1, 3 },
			itens = {
				{ id = "enlatado", peso = 30, qtd = { 1, 2 } },
				{ id = "barra", peso = 25, qtd = { 1, 3 } },
				{ id = "agua", peso = 30, qtd = { 1, 2 } },
				{ id = "bandagem", peso = 15, qtd = { 1, 2 } },
				{ id = "faca", peso = 6, qtd = { 1, 1 } },
				{ id = "lanterna", peso = 4, qtd = { 1, 1 } },
				{ id = "ots20", peso = 1, qtd = { 1, 1 } }, -- rara
				{ id = "toz34", peso = 1, qtd = { 1, 1 } }, -- rara
			},
		},
		loja = {
			rolagens = { 2, 4 },
			itens = {
				{ id = "enlatado", peso = 25, qtd = { 1, 3 } },
				{ id = "refrigerante", peso = 25, qtd = { 1, 3 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 3 } },
				{ id = "lanterna", peso = 4, qtd = { 1, 1 } },
			},
		},
		posto = {
			rolagens = { 1, 3 },
			itens = {
				{ id = "refrigerante", peso = 30, qtd = { 1, 2 } },
				{ id = "barra", peso = 30, qtd = { 1, 2 } },
				{ id = "peDeCabra", peso = 12, qtd = { 1, 1 } },
				{ id = "kit", peso = 5, qtd = { 1, 1 } },
				{ id = "lanterna", peso = 6, qtd = { 1, 1 } },
				{ id = "ots20", peso = 1, qtd = { 1, 1 } }, -- rara
				{ id = "rmb93", peso = 1, qtd = { 1, 1 } }, -- rara
			},
		},
		fabrica = {
			rolagens = { 1, 2 },
			itens = {
				{ id = "peDeCabra", peso = 25, qtd = { 1, 1 } },
				{ id = "machado", peso = 15, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 20, qtd = { 1, 2 } },
				{ id = "tt33", peso = 4, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 12, qtd = { 17, 17 } },
				-- comida para a soma das armas de fogo não passar a da comida (tests/Armas.spec confere)
				{ id = "enlatado", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 3 } },
				{ id = "agua", peso = 20, qtd = { 1, 2 } },
				-- armas de fogo do Gold Bright (docs/gold-bright-import.md; as antigas saíram do loot em 2026-11-16): PP-91, SR-3M e lançador são as mais raras (peso 1)
				{ id = "ots20", peso = 3, qtd = { 1, 1 } },
				{ id = "rmb93", peso = 3, qtd = { 1, 1 } },
				{ id = "toz34", peso = 2, qtd = { 1, 1 } },
				{ id = "mp5", peso = 2, qtd = { 1, 1 } },
				{ id = "pp91", peso = 1, qtd = { 1, 1 } },
				{ id = "sr3m", peso = 1, qtd = { 1, 1 } },
				{ id = "ots48k", peso = 1, qtd = { 1, 1 } },
				{ id = "lancaFoguetes", peso = 1, qtd = { 1, 1 } },
				{ id = "municaoRifle", peso = 9, qtd = { 30, 30 } },
				{ id = "municaoEscopeta", peso = 6, qtd = { 6, 6 } },
				{ id = "municaoMissil", peso = 1, qtd = { 1, 1 } },
			},
		},
		hospital = {
			rolagens = { 1, 3 },
			itens = {
				{ id = "bandagem", peso = 40, qtd = { 1, 3 } },
				{ id = "kit", peso = 20, qtd = { 1, 1 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 10, qtd = { 1, 2 } },
			},
		},
		guarda = {
			rolagens = { 2, 3 },
			itens = {
				{ id = "tt33", peso = 15, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 30, qtd = { 17, 17 } },
				{ id = "kit", peso = 15, qtd = { 1, 1 } },
				{ id = "machado", peso = 15, qtd = { 1, 1 } },
				{ id = "enlatado", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 3 } },
				{ id = "agua", peso = 20, qtd = { 1, 2 } },
				{ id = "ots20", peso = 3, qtd = { 1, 1 } },
				{ id = "rmb93", peso = 3, qtd = { 1, 1 } },
				{ id = "toz34", peso = 2, qtd = { 1, 1 } },
				{ id = "mp5", peso = 2, qtd = { 1, 1 } },
				{ id = "pp91", peso = 1, qtd = { 1, 1 } },
				{ id = "sr3m", peso = 1, qtd = { 1, 1 } },
				{ id = "ots48k", peso = 1, qtd = { 1, 1 } },
				{ id = "lancaFoguetes", peso = 1, qtd = { 1, 1 } },
				{ id = "municaoRifle", peso = 9, qtd = { 30, 30 } },
				{ id = "municaoEscopeta", peso = 6, qtd = { 6, 6 } },
				{ id = "municaoMissil", peso = 1, qtd = { 1, 1 } },
			},
		},
	},

	reposicao = 15 * 60, -- s para a caixa aberta voltar a ter loot
	alcanceInteracao = 8, -- studs entre o jogador e a caixa/bolsa
	bolsaDuracao = 10 * 60, -- s até a bolsa de morte sumir
}
