-- Ciclo dia/noite. Quem move o relógio e a luz: src/server/Visual.luau. Quem lê: Ruido (ambiente), Sobrevivencia (calor).

return {
	minutosReaisPorDia = 24, -- 1 h de jogo = 1 min real (12 min de noite, 12 de dia)
	horaInicial = 9, -- o jogador começa de manhã
	noiteComeca = 19, -- ClockTime >= isto ou < noiteTermina = noite
	noiteTermina = 6,
	-- Clima: atributo "Clima" no workspace ("limpo" | "chuva" | "tempestade"). No corte vertical fica "limpo";
	-- muda pelo menu de admin (tecla O) ou pelo comando de teste do Studio.
	climaPadrao = "limpo",

	-- Luz por hora: a Visual mistura "noite" e "dia" pela altura do sol (0 = noite fechada, 1 = meio-dia).
	luz = {
		noite = {
			-- 2026-11-03: subidos por captura (a 1ª versão deixava a noite preta; a foto-alvo é escura mas legível)
			ambient = { 0.34, 0.3, 0.26 },
			outdoor = { 0.4, 0.36, 0.3 },
			brilho = 1.2,
			-- Névoa do Lighting (FogStart/FogEnd/FogColor). Sem Atmosphere no Lighting (com ela a névoa seria ignorada).
			neblinaInicio = 0, -- studs
			neblinaFim = 90, -- studs: daqui para a frente tudo some na cor da névoa
			neblinaCor = { 0.26, 0.22, 0.17 }, -- sépia
			-- Lighting.Cor (ColorCorrection). PROVISÓRIO: afinar por captura no Studio.
			cor = {
				saturacao = -0.35, -- -1..1
				contraste = 0.18, -- -1..1
				brilho = -0.04, -- -1..1
				tint = { 1.0, 0.86, 0.68 }, -- RGB 0..1, sépia
			},
			-- Lighting.Brilho (Bloom). PROVISÓRIO.
			bloom = { intensidade = 0.6, tamanho = 30, limiar = 0.9 }, -- tamanho em px; limiar de luminância 0..
			-- Lighting.Profundidade (DepthOfField). PROVISÓRIO.
			profundidade = { distanciaFoco = 25, raioFoco = 35, intensidadeLonge = 0.25 }, -- studs; intensidade 0..1
		},
		dia = {
			ambient = { 0.42, 0.42, 0.46 },
			outdoor = { 0.62, 0.64, 0.7 },
			brilho = 2.6,
			neblinaInicio = 25, -- studs: perto fica limpo, a névoa só começa daqui e engrossa até o FogEnd
			-- 2026-11-03: dia enxerga mais longe e a névoa engrossa com a distância (FogStart → FogEnd é linear).
			-- Era 0–140; a noite continua curta (0–90).
			neblinaFim = 300,
			neblinaCor = { 0.7, 0.72, 0.74 }, -- cinza frio
			cor = {
				saturacao = -0.45,
				contraste = 0.12,
				brilho = 0,
				tint = { 0.93, 0.96, 1.0 },
			},
			bloom = { intensidade = 0.2, tamanho = 24, limiar = 1.4 },
			profundidade = { distanciaFoco = 25, raioFoco = 35, intensidadeLonge = 0.15 },
		},
		-- Multiplicadores do clima sobre a luz do momento
		climas = {
			-- neblina: multiplica as distâncias da névoa (menor = névoa mais perto); densidade e haze eram da Atmosphere (sem uso)
			limpo = { densidade = 1, haze = 1, brilho = 1, neblina = 1 },
			chuva = { densidade = 1.35, haze = 1.5, brilho = 0.8, neblina = 0.65 },
			tempestade = { densidade = 1.7, haze = 2, brilho = 0.6, neblina = 0.45 },
		},
		transicaoClima = 4, -- s
	},
}
