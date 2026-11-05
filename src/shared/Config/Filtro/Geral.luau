-- Filtro visual: números do orquestrador (src/client/Filtro/init.luau). PROVISÓRIO: afinar por captura (docs/filtro.md §6).
return {
	prioridadeRender = 5, -- somado a Enum.RenderPriority.Camera (a câmera dinâmica está em Camera+1)

	-- Pulsos 0..1 (Filtro.pulso). Meia-vida em segundos: tempo para o valor cair à metade.
	pulsos = {
		meiaVidaDano = 0.7, -- s
		meiaVidaSusto = 0.9, -- s
		meiaVidaGlitch = 0.12, -- s (só a borda de subida importa para a Moldura; as outras camadas usam como flash)
	},
	danoParaPulsoCheio = 40, -- pontos de vida perdidos de uma vez que dão pulso de dano 1

	-- Monstro em Caça perto: Estado.caca = 1 a `perto` studs ou menos, 0 a `longe` ou mais.
	caca = {
		perto = 15, -- studs
		longe = 60, -- studs
		distSusto = 40, -- studs: monstro que ENTRA em Caça a esta distância ou menos dá pulso de susto
		varredura = 0.25, -- s (4 Hz)
		suavizar = 0.3, -- s: meia-vida da suavização de Estado.caca
	},

	-- Câmera debaixo de teto (raio para cima a 4 Hz)
	interior = {
		alcance = 60, -- studs
		varredura = 0.25, -- s
		suavizar = 0.4, -- s: meia-vida
	},
	distanciaPrimeiraPessoa = 2, -- studs câmera-cabeça abaixo dos quais conta como primeira pessoa

	-- Próximo glitch (Regras/Filtro.proximoGlitch): intervalo sorteado em [min, max] segundos
	glitch = {
		intervaloDia = { 45, 90 }, -- s
		intervaloNoite = { 14, 35 }, -- s
		divisorCaca = 3, -- com caca = 1 o intervalo fica 3x menor
		primeiro = 12, -- s: nenhum glitch antes disto depois de iniciar
		forca = 1, -- 0..1: valor do pulso "glitch"
	},

	-- Qualidade automática (Regras/Filtro.nivelPorFps)
	qualidade = {
		janelaFps = 2, -- s: janela da média de FPS
		carencia = 6, -- s depois de iniciar sem avaliar (carregamento do mapa derruba o FPS)
		nivelInicial = 3,
		minimo = { [1] = 20, [2] = 32, [3] = 45 }, -- FPS médio mínimo para ficar em cada nível
		folga = 8, -- FPS acima do mínimo do nível seguinte para subir
		segDescer = 4, -- s seguidos abaixo do mínimo para descer
		segSubir = 12, -- s seguidos acima do mínimo+folga para subir
	},

	-- Preferências (atributos do jogador) que desligam camadas; o filtro geral é Pref_FiltroPS1
	prefPadrao = {
		Pref_FiltroPS1 = true,
		Pref_Aberracao = true,
		Pref_Lente = false,
		Pref_NeblinaVolume = true,
	},
}
