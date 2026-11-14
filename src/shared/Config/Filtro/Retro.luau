-- Filtros do DitherDown (docs/filtro-ditherdown.md). Pacote Unity URP "DitherDown" 1.1.0; o padrão do shader de origem está comentado
-- em cada número que tem equivalente. PROVISÓRIO: tudo é afinável ao vivo no Studio por ctx.ajuste("Retro...", valor).
return {
	ativo = true, -- interruptor mestre: false = o orquestrador não carrega as camadas novas e o seletor não aparece

	-- Intervalo (s) em que as camadas ligadas relêem o ajuste de Studio (atributo Filtro_Retro*). Nunca por quadro.
	reavaliarAjuste = 1,

	Dither = {
		amplitudeBase = 0.12, -- PROVISÓRIO; DitherAmount do shader é 0.1 (a força 100% multiplica isto)
		pixelPorTexel = 2, -- px de tela por texel do padrão (o shader pixela pelo Render Scale do URP; aqui o tile faz esse papel)
		zIndex = 5, -- acima da Aberração (que usa o padrão)
		nivelMinimo = 0, -- 2026-11-13: usuário quer tudo ligado; a qualidade automática não esconde
		prefForca = "Pref_FDitherForca", -- 0..100
		prefMatriz = "Pref_FDitherMatriz", -- 2..16 (potenciaValida arredonda)
	},

	ScanDura = {
		contagem = 360, -- shader ScanLines_Hard: fract(y*360), 360 ciclos por tela
		minimoPxCiclo = 2, -- piso do ciclo em px (tela pequena não vira ruído)
		minimo = 0.7, -- shader: brilho lerp(0.7, 1.0, step(0.5, fract))
		maximo = 1.0,
		zIndex = 6,
		nivelMinimo = 0, -- 2026-11-13: usuário quer tudo ligado; a qualidade automática não esconde
		alturaTexel = 8, -- texels da textura de 1 ciclo (4 escuros, 4 transparentes)
		larguraTilePx = 64, -- textura tem 1 px de largura e é toda igual na horizontal; um tile largo gasta menos quadrados
		prefForca = "Pref_FScanDuraForca",
	},

	ScanSuave = {
		contagem = 360, -- shader ScanLines_Soft: sin(y*360) SEM 2π (período 2π/360 da altura, ~57 ondas), não 360 linhas
		minimoPxPeriodo = 6, -- piso do período em px
		minimo = 0.7, -- shader: remap (-1,1) -> (0.7, 1.0)
		maximo = 1.0,
		zIndex = 7,
		nivelMinimo = 0, -- 2026-11-13: usuário quer tudo ligado; a qualidade automática não esconde
		alturaTexel = 64, -- texels da textura de 1 período
		larguraTilePx = 64,
		prefForca = "Pref_FScanSuaveForca",
	},

	Bandas = {
		velocidade = 0.1, -- telas por segundo; shader RollingBands: Speed 0.5 (grafo) / 1 (.mat). Reduzido por conforto: o usuário já teve dor de cabeça com o grão
		frequencia = 5, -- shader: Freq 5 (grafo); sin((t*Speed + y)*Freq)
		minimo = 0.8, -- shader: remap 0.15..0.85 no grafo, 0.5..1 no .mat; aqui bem mais suave
		maximo = 1.0,
		zIndex = 8,
		nivelMinimo = 0, -- 2026-11-13: usuário quer tudo ligado; a qualidade automática não esconde
		alturaTexel = 64, -- texels da textura de 1 período
		larguraTilePx = 64,
		prefForca = "Pref_FBandasForca",
	},

	Vhs = {
		offsetMax = 0.01, -- shader VHSEffect: ColorOffset limitado a ±0.01 (fração da largura)
		offsetPadrao = 0.002, -- valor do .mat do pacote (o do grafo é 0)
		nivelMinimo = 0, -- 2026-11-13: usuário quer tudo ligado; a qualidade automática não esconde
	},
}
