-- Itens, inventário e loot. Regra de sorteio: src/shared/Regras/Loot.luau. PROVISÓRIO.
-- tipo: "comida" | "bebida" | "cura" | "arma" | "municao" | "lanterna" | "recipiente"
-- uso: tempo (s) parado usando; ruido = nome da ação em Config/Som.acoes; som = nome lógico em Config/Sons.
-- Recipiente (gasolina): litros e troca vazio/cheio ficam em Config/Combustivel.recipientes (cada id daqui tem entrada lá).
-- Arma: item.arma = id em Config/Armas (mesmo id do item). Munição: Config/Armas.armas[x].municao aponta para o id daqui.

return {
	slots = 8, -- tamanho do inventário
	empilhamentoPadrao = 1,

	-- Arma de fogo achada no chão (caixa/bolsa sem estado) nasce com o pente sorteado entre estas frações da capacidade.
	penteLoot = { 0.4, 1 },

	itens = {
		enlatado = { nome = "Enlatado", tipo = "comida", fome = 35, uso = 3, ruido = "comer", som = "Comer", pilha = 3 },
		barra = {
			nome = "Barra de cereal",
			tipo = "comida",
			fome = 15,
			uso = 1.5,
			ruido = "comer",
			som = "Comer",
			pilha = 5,
		},
		agua = {
			nome = "Garrafa d'água",
			tipo = "bebida",
			sede = 40,
			uso = 2,
			ruido = "beber",
			som = "Beber",
			pilha = 3,
		},
		refrigerante = {
			nome = "Refrigerante",
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
			tipo = "cura",
			cura = 15,
			uso = 5,
			ruido = "bandagem",
			som = "Bandagem",
			pilha = 5,
		},
		kit = { nome = "Kit médico", tipo = "cura", cura = 40, uso = 8, ruido = "kit", som = "Bandagem", pilha = 1 },
		faca = { nome = "Faca", tipo = "arma", arma = "faca", pilha = 1 },
		peDeCabra = { nome = "Pé de cabra", tipo = "arma", arma = "peDeCabra", pilha = 1 },
		machado = { nome = "Machado", tipo = "arma", arma = "machado", pilha = 1 },
		pistola = { nome = "Pistola", tipo = "arma", arma = "pistola", pilha = 1 },
		beretta = { nome = "Beretta 92FS", tipo = "arma", arma = "beretta", pilha = 1 },
		carabinaM5 = { nome = "Carabina M5", tipo = "arma", arma = "carabinaM5", pilha = 1 },
		ar15 = { nome = "AR-15", tipo = "arma", arma = "ar15", pilha = 1 },
		ak74 = { nome = "AK-74", tipo = "arma", arma = "ak74", pilha = 1 },
		escopeta = { nome = "Escopeta", tipo = "arma", arma = "escopeta", pilha = 1 },
		escopetaM1912 = { nome = "Escopeta Trincheira M1912", tipo = "arma", arma = "escopetaM1912", pilha = 1 },
		lancaFoguetes = { nome = "Lança-foguetes", tipo = "arma", arma = "lancaFoguetes", pilha = 1 },
		municaoPistola = { nome = "Munição 9mm", tipo = "municao", pilha = 30 },
		municao556 = { nome = "Munição 5,56", tipo = "municao", pilha = 30 },
		municao545 = { nome = "Munição 5,45", tipo = "municao", pilha = 30 },
		municaoCalibre12 = { nome = "Munição calibre 12", tipo = "municao", pilha = 12 },
		municaoFoguete = { nome = "Munição de foguete", tipo = "municao", pilha = 2 },
		lanterna = { nome = "Lanterna", tipo = "lanterna", pilha = 1 }, -- equipa pela barra; números em Config/Lanterna
		-- Recipientes de gasolina (docs/combustivel.md §6.5). Segurar na mão: clicar o slot; despejar no carro pela tampa.
		garrafaVazia = { nome = "Garrafa vazia", tipo = "recipiente", pilha = 3 },
		garrafaGasolina = { nome = "Garrafa de gasolina", tipo = "recipiente", pilha = 3 },
		galaoVazio = { nome = "Galão vazio", tipo = "recipiente", pilha = 1 },
		galaoGasolina = { nome = "Galão de gasolina (5 L)", tipo = "recipiente", pilha = 1 },
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
				{ id = "beretta", peso = 1, qtd = { 1, 1 } }, -- rara
				{ id = "escopetaM1912", peso = 1, qtd = { 1, 1 } }, -- rara
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
				{ id = "beretta", peso = 1, qtd = { 1, 1 } }, -- rara
				{ id = "escopeta", peso = 1, qtd = { 1, 1 } }, -- rara
			},
		},
		fabrica = {
			rolagens = { 1, 2 },
			itens = {
				{ id = "peDeCabra", peso = 25, qtd = { 1, 1 } },
				{ id = "machado", peso = 15, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 20, qtd = { 1, 2 } },
				{ id = "pistola", peso = 4, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 12, qtd = { 6, 12 } },
				-- comida para a soma das armas de fogo não passar a da comida (tests/Armas.spec confere)
				{ id = "enlatado", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 3 } },
				{ id = "agua", peso = 20, qtd = { 1, 2 } },
				-- armas novas (docs/armas.md §2): M5, AK e lançador são as mais raras (peso 1)
				{ id = "beretta", peso = 3, qtd = { 1, 1 } },
				{ id = "escopeta", peso = 3, qtd = { 1, 1 } },
				{ id = "escopetaM1912", peso = 2, qtd = { 1, 1 } },
				{ id = "ar15", peso = 2, qtd = { 1, 1 } },
				{ id = "carabinaM5", peso = 1, qtd = { 1, 1 } },
				{ id = "ak74", peso = 1, qtd = { 1, 1 } },
				{ id = "lancaFoguetes", peso = 1, qtd = { 1, 1 } },
				{ id = "municao556", peso = 6, qtd = { 10, 20 } },
				{ id = "municao545", peso = 3, qtd = { 10, 20 } },
				{ id = "municaoCalibre12", peso = 6, qtd = { 4, 8 } },
				{ id = "municaoFoguete", peso = 1, qtd = { 1, 1 } },
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
				{ id = "pistola", peso = 15, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 30, qtd = { 8, 16 } },
				{ id = "kit", peso = 15, qtd = { 1, 1 } },
				{ id = "machado", peso = 15, qtd = { 1, 1 } },
				{ id = "enlatado", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 3 } },
				{ id = "agua", peso = 20, qtd = { 1, 2 } },
				{ id = "beretta", peso = 3, qtd = { 1, 1 } },
				{ id = "escopeta", peso = 3, qtd = { 1, 1 } },
				{ id = "escopetaM1912", peso = 2, qtd = { 1, 1 } },
				{ id = "ar15", peso = 2, qtd = { 1, 1 } },
				{ id = "carabinaM5", peso = 1, qtd = { 1, 1 } },
				{ id = "ak74", peso = 1, qtd = { 1, 1 } },
				{ id = "lancaFoguetes", peso = 1, qtd = { 1, 1 } },
				{ id = "municao556", peso = 6, qtd = { 10, 20 } },
				{ id = "municao545", peso = 3, qtd = { 10, 20 } },
				{ id = "municaoCalibre12", peso = 6, qtd = { 4, 8 } },
				{ id = "municaoFoguete", peso = 1, qtd = { 1, 1 } },
			},
		},
	},

	reposicao = 15 * 60, -- s para a caixa aberta voltar a ter loot
	alcanceInteracao = 8, -- studs entre o jogador e a caixa/bolsa
	bolsaDuracao = 10 * 60, -- s até a bolsa de morte sumir
}
