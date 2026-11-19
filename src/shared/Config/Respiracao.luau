-- Segurar a respiração (docs/som.md §13). Regra: src/shared/Regras/Respiracao.luau. PROVISÓRIO: nada foi medido no playtest.
-- Quando um monstro em busca chega bem perto de um jogador escondido, o jogador segura a respiração num minigame simples e meio difícil:
-- errar = arfar alto. Tecla: Config/Movimento.teclas.prenderRespiracao.

return {
	ligado = true,

	-- Quando começa (servidor, laço de `hz` Hz; docs/som.md §13.1)
	hz = 5,
	recarga = 6, -- s desde o fim do último minigame do jogador
	raio = 12, -- studs na horizontal: monstro em busca a <= isto abre o minigame
	alturaMax = 8, -- studs de diferença de altura
	longe = 4, -- studs: a proximidade é 1 colado e 0 em `raio`; abaixo de `longe` já vale 1
	saidaExtra = 4, -- studs além do raio em que o monstro "se afastou" e o minigame fecha sem som

	-- Fôlego (§13.2): dura no máximo folegoBase + folegoEstamina × estamina/100 segundos
	folegoBase = 10,
	folegoEstamina = 8,

	-- Rede (§13.4)
	proximidadeCada = 0.5, -- s entre as atualizações de proximidade ao cliente
	falhaAposMin = 0.3, -- s depois do início: antes disso o servidor ignora "falhou"

	-- Sons (§13.3). O fôlego que acaba solta o ar (baixo, mas arriscado colado); o arfar é alto. O perfil de "respiracao" é o da camada de
	-- respiração do passo (Config/Som.passo.respiracaoPerfil).
	soltarAr = { db = 28 },
	arfar = { db = 58, perfil = { grave = -3, medio = 0, agudo = -6 }, estamina = 10 }, -- estamina = quanto o arfar custa

	-- A regra do jogo (docs/som.md §13.2). Posição p e zona em 0..1 (0 embaixo).
	jogo = {
		empurrao = 2.6, -- /s²: aceleração para cima com a tecla segurada
		gravidade = 1.8, -- /s²: aceleração para baixo com a tecla solta
		amortecimento = 2.5, -- /s
		inicio = 0.5, -- p e zona no início
		larguraLonge = 0.26, -- largura da zona com o monstro em `raio`
		larguraPerto = 0.24, -- largura da zona com o monstro colado (0,18 deixava só 10% passando)
		trocaMin = 0.8, -- s entre trocar o alvo da zona
		trocaMax = 1.6,
		velZona = 0.35, -- /s
		velZonaCansado = 1.4, -- multiplicador da velocidade da zona com estamina < cansadoAbaixo
		cansadoAbaixo = 30, -- % de estamina
		subida = 0.2, -- /s: tensão sobe fora da zona (1 / 0,2 = 5 s fora da zona o tempo todo até arfar; era 0,55 = 1,8 s)
		alivio = 0.25, -- /s: tensão cai dentro da zona
	},

	-- Cliente (§13.5)
	cliente = {
		barra = { largura = 22, altura = 240, deslocamentoX = 110 }, -- px; deslocamento à direita do centro da tela
		vinhetaMax = 0.65, -- opacidade máxima da vinheta (com a tensão cheia)
		vinhetaLargura = 0.28, -- fração da tela que cada borda da vinheta cobre
		batimento = { base = 1, extra = 0.7 }, -- PlaybackSpeed do Coracao: base + extra × proximidade
		abafar = { HighGain = -12 }, -- EqualizerSoundEffect no SoundGroup "Efeitos"
		avisoSegundos = 4, -- s que a dica aparece na primeira vez
		dica = "Segure ESPAÇO para prender a respiração",
		botaoTitulo = "Segurar", -- botão de toque (ContextActionService)
	},
}
