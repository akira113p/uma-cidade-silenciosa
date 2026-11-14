-- Câmera em primeira pessoa (docs/calculos.md §5). Regra: src/shared/Regras/Camera.luau. PROVISÓRIO.

return {
	modos = {
		parado = { amplitude = 0, inclinacao = 0, fov = 70 },
		agachado = { amplitude = 0.05, inclinacao = 0.5, fov = 70 },
		andar = { amplitude = 0.12, inclinacao = 1.0, fov = 70 },
		correr = { amplitude = 0.25, inclinacao = 2.0, fov = 78 },
	},
	transicaoFov = 0.3, -- s
	alturaOlhosAgachado = -0.2, -- offset Y extra da câmera agachado (o quadril já desce em Config/Movimento.agachado)

	aterrissagem = { divisorVelocidade = 50, maximo = 0.6, duracao = 0.25 },
	golpe = { amplitude = 0.4, duracao = 0.3 },
	monstroCacando = { distancia = 40, amplitude = 0.03 },

	terceiraPessoa = { distancia = 10, tecla = "V" },

	-- Preferências (atributos Pref_* no jogador; salvas pelo servidor)
	preferenciasPadrao = {
		Pref_Tremor = true,
		Pref_Intensidade = 100, -- 0..100
		Pref_FOV = 70, -- 60..90
		Pref_FiltroPS1 = true, -- rótulo "Filtro de imagem": liga/desliga o filtro todo
		Pref_Aberracao = true,
		Pref_Lente = false,
		Pref_NeblinaVolume = true,
		Pref_Volume = 100, -- 0..100
		-- Filtros do DitherDown (docs/filtro-ditherdown.md §6): tudo nasce desligado
		Pref_FDither = false,
		Pref_FDitherForca = 100, -- 0..100
		Pref_FDitherMatriz = 4, -- 2..16 (potência de 2)
		Pref_FScanDura = false,
		Pref_FScanDuraForca = 100,
		Pref_FScanSuave = false,
		Pref_FScanSuaveForca = 100,
		Pref_FBandas = false,
		Pref_FBandasForca = 50,
		Pref_FVhs = false,
		Pref_FVhsForca = 20,
	},
	limitesPreferencias = {
		Pref_Intensidade = { 0, 100 },
		Pref_FOV = { 60, 90 },
		Pref_Volume = { 0, 100 },
		Pref_FDitherForca = { 0, 100 },
		Pref_FDitherMatriz = { 2, 16 },
		Pref_FScanDuraForca = { 0, 100 },
		Pref_FScanSuaveForca = { 0, 100 },
		Pref_FBandasForca = { 0, 100 },
		Pref_FVhsForca = { 0, 100 },
	},
}
