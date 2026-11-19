-- AnimacoesCorpo: números e ids dos clipes de corpo (assets/animacoes/corpo/*.json). Dono: A1 (docs/personagens.md §2/A1).
-- animacoes[grupo][clipe] = id publicado (rbxassetid://...) ou false = sem upload: o jogo monta a KeyframeSequence em runtime
-- (shared/Animacao) e registra com KeyframeSequenceProvider. Um id aqui vale mais que o registro em runtime.
-- Os grupos são o nome do arquivo em assets/animacoes/corpo ("carro" = "corpo/carro"). Duração, laço e prioridade vêm do JSON.
return {
	animacoes = {
		carro = {
			MotoristaIdle = "rbxassetid://82157575239971",
			MotoristaViraEsquerda = "rbxassetid://107684992408177",
			MotoristaViraDireita = "rbxassetid://88725112894183",
			PassageiroIdle = "rbxassetid://125293882304440",
			Entrar = "rbxassetid://105957414634476",
			Sair = "rbxassetid://102102958392532",
		},
		mundo = {
			Pegar = "rbxassetid://125455917650158",
			Largar = "rbxassetid://77716262859812",
			Interagir = "rbxassetid://120339092005356",
			Abastecer = "rbxassetid://85169409949535",
		},
		mao = {
			SegurarUmaMao = "rbxassetid://89482842607320",
			SegurarUmaMaoEsq = "rbxassetid://138292347218518",
			SegurarGalao = "rbxassetid://71396281737303",
			Usar = "rbxassetid://79175639857338",
		},
		vida = {
			Morte = "rbxassetid://95926709065507",
			Queda = "rbxassetid://75298434963647",
			Aterrissagem = "rbxassetid://122696861302495",
		},
	},

	-- Morte animada (clipe corpo/vida Morte). Liga: o servidor deixa as juntas inteiras na morte (BreakJointsOnDeath = false) e
	-- o cliente toca o clipe. Desligada por padrão: se o clipe registrado em runtime não carregar, o corpo ficaria em pé e
	-- rígido até renascer, pior que o desmonte padrão do motor. A dona do Studio liga (true) depois de ver o clipe tocar.
	morteAnimada = false,

	fade = {
		entrar = 0.1, -- s: entrada/saída dos clipes de uma vez só
		repouso = 0.2, -- s: Idle do carro e SegurarX entram/saem neste tempo
		morte = 0.05,
		volante = 0.12, -- s: o peso do clipe de curva acompanha a direção
	},

	volante = {
		zonaMorta = 0.1, -- fração da direção (SteerFloat) ignorada
	},

	-- Queda: o clipe de Queda só toca depois de estar no ar por este tempo (pulo curto não vira queda); a Aterrissagem só se
	-- ele tocou.
	queda = {
		minimo = 0.6, -- s (um pulo normal dura ~0,5 s no ar com JumpHeight 6)
	},

	-- Itens: recipientes a partir desta capacidade em litros usam SegurarGalao (Config/Combustivel.recipientes).
	mao = {
		minimoGalao = 2,
	},

	-- Coleta/largar no chão do cliente local: janela (s) para casar "inventário mudou" com "item do chão apareceu/sumiu",
	-- e distância máxima (studs) do item ao personagem.
	mundo = {
		janela = 0.8,
		distancia = 10,
		interagirRecarga = 0.5, -- s mínimos entre dois "Interagir"
	},
}
