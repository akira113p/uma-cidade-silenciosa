-- Compartimentos dos móveis comerciais, industriais e institucionais (contrato: docs/compartimentos.md).
-- tabelas: categoria → { rolagens, itens = { {id, peso, qtd} } }. moveis: nome do móvel → { categoria, nome, chance }.

return {
	tabelas = {
		-- porta-malas de carro (docs/veiculos.md): pouco e comum; arma é rara
		portaMalas = {
			rolagens = { 0, 3 },
			itens = {
				{ id = "refrigerante", peso = 22, qtd = { 1, 2 } },
				{ id = "agua", peso = 22, qtd = { 1, 2 } },
				{ id = "barra", peso = 18, qtd = { 1, 2 } },
				{ id = "enlatado", peso = 14, qtd = { 1, 2 } },
				{ id = "bandagem", peso = 10, qtd = { 1, 1 } },
				{ id = "peDeCabra", peso = 8, qtd = { 1, 1 } },
				{ id = "lanterna", peso = 3, qtd = { 1, 1 } },
				{ id = "machado", peso = 2, qtd = { 1, 1 } },
				{ id = "faca", peso = 1, qtd = { 1, 1 } },
			},
		},
		mercado_comida = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "enlatado", peso = 35, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 2 } },
				{ id = "agua", peso = 25, qtd = { 1, 3 } },
				{ id = "refrigerante", peso = 20, qtd = { 1, 2 } },
			},
		},
		loja_geral = {
			rolagens = { 0, 3 },
			itens = {
				{ id = "refrigerante", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 20, qtd = { 1, 2 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "bandagem", peso = 15, qtd = { 1, 1 } },
				{ id = "enlatado", peso = 15, qtd = { 1, 2 } },
			},
		},
		bar_restaurante = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "agua", peso = 30, qtd = { 1, 2 } },
				{ id = "refrigerante", peso = 30, qtd = { 1, 2 } },
				{ id = "barra", peso = 15, qtd = { 1, 2 } },
				{ id = "enlatado", peso = 10, qtd = { 1, 1 } },
				{ id = "faca", peso = 5, qtd = { 1, 1 } },
			},
		},
		posto_oficina = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "refrigerante", peso = 35, qtd = { 1, 2 } },
				{ id = "barra", peso = 25, qtd = { 1, 2 } },
				{ id = "peDeCabra", peso = 15, qtd = { 1, 1 } },
				{ id = "machado", peso = 8, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 7, qtd = { 1, 1 } },
				{ id = "galaoVazio", peso = 25, qtd = { 1, 1 } },
				{ id = "galaoGasolina", peso = 10, qtd = { 1, 1 } },
				{ id = "garrafaVazia", peso = 20, qtd = { 1, 2 } },
			},
		},
		industria = {
			rolagens = { 1, 2 },
			itens = {
				{ id = "peDeCabra", peso = 20, qtd = { 1, 1 } },
				{ id = "machado", peso = 12, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 18, qtd = { 1, 2 } },
				{ id = "pistola", peso = 3, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 10, qtd = { 6, 12 } },
				{ id = "barra", peso = 15, qtd = { 1, 2 } },
				{ id = "agua", peso = 10, qtd = { 1, 2 } },
			},
		},
		escritorio = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "barra", peso = 25, qtd = { 1, 2 } },
				{ id = "agua", peso = 30, qtd = { 1, 2 } },
				{ id = "refrigerante", peso = 10, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 8, qtd = { 1, 1 } },
				{ id = "faca", peso = 3, qtd = { 1, 1 } },
			},
		},
		saude = {
			rolagens = { 1, 3 },
			itens = {
				{ id = "bandagem", peso = 40, qtd = { 1, 3 } },
				{ id = "kit", peso = 20, qtd = { 1, 1 } },
				{ id = "agua", peso = 25, qtd = { 1, 2 } },
				{ id = "barra", peso = 15, qtd = { 1, 2 } },
			},
		},
		seguranca = {
			rolagens = { 2, 3 },
			itens = {
				{ id = "pistola", peso = 25, qtd = { 1, 1 } },
				{ id = "municaoPistola", peso = 20, qtd = { 8, 16 } },
				{ id = "machado", peso = 12, qtd = { 1, 1 } },
				{ id = "peDeCabra", peso = 8, qtd = { 1, 1 } },
				{ id = "faca", peso = 5, qtd = { 1, 1 } },
				{ id = "kit", peso = 15, qtd = { 1, 1 } },
				{ id = "bandagem", peso = 10, qtd = { 1, 2 } },
			},
		},
		culto_escola = {
			rolagens = { 0, 2 },
			itens = {
				{ id = "barra", peso = 30, qtd = { 1, 2 } },
				{ id = "agua", peso = 35, qtd = { 1, 2 } },
				{ id = "bandagem", peso = 15, qtd = { 1, 1 } },
			},
		},
	},

	moveis = {
		-- mercado
		prateleira_mercado = { categoria = "mercado_comida", nome = "Prateleira", chance = 0.8 },
		geladeira_expositora = { categoria = "mercado_comida", nome = "Geladeira", chance = 0.85 },
		freezer_horizontal = { categoria = "mercado_comida", nome = "Freezer", chance = 0.8 },
		pilha_produtos = { categoria = "mercado_comida", nome = "Pilha de produtos", chance = 0.8 },
		balcao_acougue = { categoria = "mercado_comida", nome = "Balcão do açougue", chance = 0.8 },
		-- lojas
		prateleira_loja = { categoria = "loja_geral", nome = "Prateleira", chance = 0.7 },
		balcao_loja = { categoria = "loja_geral", nome = "Balcão", chance = 0.7 },
		vitrine = { categoria = "loja_geral", nome = "Vitrine", chance = 0.6 },
		balcao_caixa = { categoria = "loja_geral", nome = "Caixa", chance = 0.7 },
		arara_roupas = { categoria = "loja_geral", nome = "Arara de roupas", chance = 0.6 },
		maquina_venda = { categoria = "loja_geral", nome = "Máquina de venda", chance = 0.9 },
		-- restaurante / bar
		balcao_bar = { categoria = "bar_restaurante", nome = "Balcão do bar", chance = 0.8 },
		mesa_restaurante = { categoria = "bar_restaurante", nome = "Mesa", chance = 0.5 },
		-- posto / oficina
		tambor_oleo = { categoria = "posto_oficina", nome = "Tambor", chance = 0.6 },
		expositor_pneus = { categoria = "posto_oficina", nome = "Pneus", chance = 0.5 },
		compressor = { categoria = "posto_oficina", nome = "Compressor", chance = 0.4 },
		bancada_trabalho = { categoria = "posto_oficina", nome = "Bancada de trabalho", chance = 0.6 },
		-- indústria
		estante_industrial = { categoria = "industria", nome = "Estante", chance = 0.7 },
		palete = { categoria = "industria", nome = "Palete", chance = 0.5 },
		pilha_caixotes = { categoria = "industria", nome = "Caixotes", chance = 0.6 },
		barril = { categoria = "industria", nome = "Barril", chance = 0.6 },
		quadro_eletrico = { categoria = "industria", nome = "Quadro elétrico", chance = 0.3 },
		fardo_feno = { categoria = "industria", nome = "Fardo de feno", chance = 0.5 },
		-- escritório / recepção
		arquivo_alto = { categoria = "escritorio", nome = "Arquivo", chance = 0.7 },
		mesa_escritorio = { categoria = "escritorio", nome = "Mesa", chance = 0.6 },
		baia_escritorio = { categoria = "escritorio", nome = "Baia", chance = 0.5 },
		balcao_recepcao = { categoria = "escritorio", nome = "Balcão da recepção", chance = 0.6 },
		bebedouro = { categoria = "escritorio", nome = "Bebedouro", chance = 0.5 },
		-- saúde
		armario_medico = { categoria = "saude", nome = "Armário médico", chance = 0.95 },
		cama_hospital = { categoria = "saude", nome = "Cama de hospital", chance = 0.9 },
		-- segurança / delegacia / militar
		armario_armas = { categoria = "seguranca", nome = "Armário de armas", chance = 0.95 },
		estante_armas = { categoria = "seguranca", nome = "Estante de armas", chance = 0.95 },
		caixa_municao = { categoria = "seguranca", nome = "Caixa de munição", chance = 0.95 },
		mesa_delegacia = { categoria = "seguranca", nome = "Mesa da delegacia", chance = 0.7 },
		cela_grade = { categoria = "seguranca", nome = "Cela", chance = 0.6 },
		mesa_mapas = { categoria = "seguranca", nome = "Mesa de mapas", chance = 0.6 },
		-- culto / escola
		altar = { categoria = "culto_escola", nome = "Altar", chance = 0.5 },
		confessionario = { categoria = "culto_escola", nome = "Confessionário", chance = 0.5 },
		estante_biblioteca = { categoria = "culto_escola", nome = "Estante", chance = 0.6 },
		armario_escola = { categoria = "culto_escola", nome = "Armário", chance = 0.5 },
	},
}
