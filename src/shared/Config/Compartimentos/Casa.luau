-- Compartimentos domésticos: móvel do mapa → categoria de loot e chance. Contrato: docs/compartimentos.md.
-- Chance calibrada pela contagem do mapa (ver relatório); quarto tem arma, banheiro e comida não têm.
return {
	tabelas = {
		comida_casa = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "enlatado", peso = 35, qtd = { 1, 2 } },
				{ id = "barra", peso = 30, qtd = { 1, 3 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "refrigerante", peso = 10, qtd = { 1, 2 } },
			},
		},
		cozinha_casa = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "enlatado", peso = 30, qtd = { 1, 2 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 2 } },
				{ id = "refrigerante", peso = 10, qtd = { 1, 1 } },
				{ id = "garrafaVazia", peso = 10, qtd = { 1, 1 } },
				{ id = "faca", peso = 4, qtd = { 1, 1 } },
			},
		},
		quarto_casa = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "bandagem", peso = 20, qtd = { 1, 1 } },
				{ id = "barra", peso = 20, qtd = { 1, 2 } },
				{ id = "agua", peso = 10, qtd = { 1, 1 } },
				{ id = "faca", peso = 8, qtd = { 1, 1 } },
				{ id = "pistola", peso = 2, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 6, qtd = { 4, 8 } },
			},
		},
		banheiro_casa = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "bandagem", peso = 40, qtd = { 1, 2 } },
				{ id = "agua", peso = 35, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 1 } },
				{ id = "kit", peso = 5, qtd = { 1, 1 } },
			},
		},
		garagem_casa = {
			rolagens = { 1, 2 },
			itens = {
				{ id = "peDeCabra", peso = 35, qtd = { 1, 1 } },
				{ id = "machado", peso = 20, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 20, qtd = { 1, 2 } },
				{ id = "barra", peso = 15, qtd = { 1, 1 } },
				{ id = "galaoVazio", peso = 20, qtd = { 1, 1 } },
				{ id = "galaoGasolina", peso = 8, qtd = { 1, 1 } },
			},
		},
		diversos_casa = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "barra", peso = 25, qtd = { 1, 1 } },
				{ id = "agua", peso = 15, qtd = { 1, 1 } },
				{ id = "enlatado", peso = 15, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 10, qtd = { 1, 1 } },
				{ id = "faca", peso = 3, qtd = { 1, 1 } },
			},
		},
	},
	moveis = {
		criado_mudo = { categoria = "quarto_casa", nome = "Criado-mudo", chance = 0.6 },
		guarda_roupa = { categoria = "quarto_casa", nome = "Guarda-roupa", chance = 0.6 },
		comoda = { categoria = "quarto_casa", nome = "Cômoda", chance = 0.8 },
		penteadeira = { categoria = "quarto_casa", nome = "Penteadeira", chance = 0.8 },
		geladeira = { categoria = "comida_casa", nome = "Geladeira", chance = 0.85 },
		armario_cozinha_alto = { categoria = "comida_casa", nome = "Armário de cozinha", chance = 1 },
		fogao = { categoria = "cozinha_casa", nome = "Fogão", chance = 0.5 },
		pia_cozinha = { categoria = "cozinha_casa", nome = "Pia de cozinha", chance = 0.4 },
		lavatorio = { categoria = "banheiro_casa", nome = "Lavatório", chance = 0.25 },
		cesto_roupa = { categoria = "banheiro_casa", nome = "Cesto de roupa", chance = 0.3 },
		bancada_ferramentas = { categoria = "garagem_casa", nome = "Bancada de ferramentas", chance = 1 },
		prateleira_garagem = { categoria = "garagem_casa", nome = "Prateleira de garagem", chance = 0.9 },
		caixa_ferramentas = { categoria = "garagem_casa", nome = "Caixa de ferramentas", chance = 1 },
		galao = { categoria = "garagem_casa", nome = "Galão", chance = 0.8 },
		pilha_pneus = { categoria = "garagem_casa", nome = "Pilha de pneus", chance = 1 },
		caixa_papelao = { categoria = "diversos_casa", nome = "Caixa de papelão", chance = 0.5 },
		bau = { categoria = "diversos_casa", nome = "Baú", chance = 1 },
		arquivo = { categoria = "diversos_casa", nome = "Arquivo", chance = 0.8 },
		aparador = { categoria = "diversos_casa", nome = "Aparador", chance = 0.6 },
		sapateira = { categoria = "diversos_casa", nome = "Sapateira", chance = 0.5 },
		escrivaninha = { categoria = "diversos_casa", nome = "Escrivaninha", chance = 0.7 },
		estante_livros = { categoria = "diversos_casa", nome = "Estante de livros", chance = 0.8 },
		movel_tv = { categoria = "diversos_casa", nome = "Móvel de TV", chance = 0.6 },
	},
}
