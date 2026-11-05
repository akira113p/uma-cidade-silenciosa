-- Filtro visual: moldura de VHS, vinheta, poeira, tracking e linhas de glitch (src/client/Filtro/Moldura.luau). PROVISÓRIO.
return {
	-- Moldura 9-slice (moldura_vhs.png 256x256, cantos de raio 48 px; o LEIAME de assets/filtro/final confirma)
	sliceCenter = { 64, 64, 192, 192 }, -- px da imagem: esquerda, topo, direita, base
	sliceEscala = 0.5, -- ImageLabel.SliceScale (2026-11-03: 1 cobria os cantos do HUD; usuário pediu mais fina)
	transparenciaMoldura = 0.15, -- 0..1

	-- Vinheta: transparência por noite; dano e caça escurecem (tiram transparência)
	vinhetaDia = 0.55, -- 0..1
	vinhetaNoite = 0.35, -- 0..1
	vinhetaExtraDano = 0.35, -- tirado da transparência com pulso de dano 1
	vinhetaExtraCaca = 0.2, -- tirado da transparência com Estado.caca 1
	corVinheta = { 0, 0, 0 }, -- RGB 0..1
	corVinhetaDano = { 0.3, 0, 0 }, -- RGB 0..1 com pulso de dano 1

	-- Poeira de lente (tela cheia, deriva lenta, pisca de leve)
	poeiraTransparencia = 0.82, -- 0..1 base (2026-11-03: era 0.55)
	poeiraPisca = 0.06, -- amplitude do piscar na transparência
	poeiraPiscaHz = 0.7, -- Hz
	poeiraDeriva = 0.02, -- fração da tela: a poeira salta de posição (sorteio em +-isto) a cada quadro de grão, como filme
	poeiraEscala = 1.06, -- tamanho em relação à tela (folga para a deriva)

	-- Glitch / tracking
	glitchDuracao = { 0.5, 1.4 }, -- s: sorteio da duração de cada glitch
	trackingAltura = 56, -- px da faixa de tracking
	trackingTransparencia = 0.35, -- 0..1
	trackingChanceAtravessa = 0.6, -- probabilidade de atravessar a tela (senão fica parada na base)
	trackingBase = 0.94, -- fração da altura da tela onde a faixa fica parada
	tranco = 0.15, -- studs: amplitude do tranco de câmera no início do glitch (Camera.tremer, 0.12 s)
	trackingEspontaneo = { 6, 15 }, -- s: intervalo sorteado entre faixas de tracking fora de glitch (mesma duração do glitch)
	trancoDuracao = 0.12, -- s

	-- Craquelado (rachaduras pretas, textura craquelado tileável 1024): mosaico que salta de posição
	craqueladoTile = 512, -- px: TileSize
	craqueladoDia = 0.9, -- 0..1: ImageTransparency com noite = 0 (2026-11-03: era 0.75; usuário: mais leve)
	craqueladoNoite = 0.85, -- idem com noite = 1
	craqueladoSalto = { 1.5, 2.5 }, -- s: intervalo sorteado entre saltos de posição
	craqueladoTremor = 1, -- px: tremor a cada quadro de grão

	-- Estalos de fita: rajadas curtas de riscos horizontais finos (pool de Frames)
	estalos = {
		quantidade = 10, -- Frames no pool (>= rajadaMax)
		intervalo = { 3, 9 }, -- s entre rajadas (de dia, sem caça) (2026-11-03: era 0.8–4, cansava a vista)
		divisorNoite = 1.6, -- à noite o intervalo fica 1.6x menor
		divisorCaca = 2, -- com caca = 1 fica 2x menor
		duracao = { 0.05, 0.2 }, -- s de cada rajada
		rajada = { 2, 5 }, -- riscos por rajada
		altura = { 1, 3 }, -- px
		largura = { 0.05, 0.4 }, -- fração da tela
		transparencia = { 0.3, 0.7 }, -- 0..1 (alfa 0.3-0.7 = transparência 0.3-0.7)
		chanceBranco = 0.5, -- senão preto
	},

	-- Riscos verticais de filme (textura riscos 64x1024)
	riscos = {
		quantidade = 2, -- ImageLabels (0 a 2 visíveis ao mesmo tempo)
		largura = { 2, 4 }, -- px
		salto = { 0.1, 0.4 }, -- s entre saltos de posição X
		chance = 0.15, -- probabilidade de aparecer a cada salto
		transparencia = { 0.2, 0.5 }, -- 0..1 (alfa 0.5-0.8)
	},

	linhas = {
		quantidade = 12, -- Frames finos (8 a 14)
		alturaMin = 1, -- px
		alturaMax = 2, -- px
		hz = 10, -- sorteio de posições/larguras por segundo
		zonaTopo = 0.12, -- fração da tela perto do topo
		zonaBase = 0.12, -- fração da tela perto da base
		transparenciaMin = 0.7, -- 0..1
		transparenciaMax = 0.9, -- 0..1
		larguraMin = 0.05, -- fração da tela
		larguraMax = 0.6, -- fração da tela
		cores = { { 1, 1, 1 }, { 1, 0.2, 0.2 }, { 0.2, 1, 1 } }, -- RGB 0..1: branco, vermelho, ciano
	},

	zIndex = {
		poeira = 10,
		vinheta = 20,
		tracking = 30,
		craquelado = 25,
		glitch = 40,
		estalo = 45,
		riscos = 47,
		moldura = 60,
	},
}
