-- Seletor de filtros (docs/filtro-ditherdown.md §6): dados puros da seção da tela de Configurações.
-- Regra de validação: src/shared/Regras/FiltroSeletor.luau. Interface: src/client/FiltrosSeletor.luau.
-- Cada pref citada aqui precisa existir em Config/Camera.preferenciasPadrao (o teste confere).

local FORCA_PADRAO = { 0, 25, 50, 75, 100 }

return {
	titulo = "Filtros de tela (DitherDown)",
	nota = "Imitações por sobreposição: o Roblox não permite shader de tela.",

	-- Ordem = ordem na tela. forca/extras: { pref, rotulo, opcoes } (opções numéricas exatas).
	filtros = {
		{
			id = "Dither",
			rotulo = "Dither Bayer",
			fonte = "DitherDown",
			fidelidade = "imitação",
			pref = "Pref_FDither",
			forca = { pref = "Pref_FDitherForca", rotulo = "Força (%)", opcoes = FORCA_PADRAO },
			extras = {
				{ pref = "Pref_FDitherMatriz", rotulo = "Matriz", opcoes = { 2, 4, 8, 16 } },
			},
		},
		{
			id = "ScanDura",
			rotulo = "Scanlines duras",
			fonte = "ScanLines_Hard",
			fidelidade = "fiel na frequência",
			pref = "Pref_FScanDura",
			forca = { pref = "Pref_FScanDuraForca", rotulo = "Força (%)", opcoes = FORCA_PADRAO },
		},
		{
			id = "ScanSuave",
			rotulo = "Scanlines suaves",
			fonte = "ScanLines_Soft",
			fidelidade = "fiel na frequência",
			pref = "Pref_FScanSuave",
			forca = { pref = "Pref_FScanSuaveForca", rotulo = "Força (%)", opcoes = FORCA_PADRAO },
		},
		{
			id = "Bandas",
			rotulo = "Bandas rolando",
			fonte = "RollingBands",
			fidelidade = "fiel na forma e na velocidade",
			aviso = "Tem movimento: pode cansar a vista",
			pref = "Pref_FBandas",
			forca = { pref = "Pref_FBandasForca", rotulo = "Força (%)", opcoes = FORCA_PADRAO },
		},
		{
			id = "Vhs",
			rotulo = "VHS linear (separação RGB)",
			fonte = "VHSEffect",
			fidelidade = "geometria fiel, cor em fantasma",
			aviso = "Pesado: renderiza a cena de novo",
			pref = "Pref_FVhs",
			forca = { pref = "Pref_FVhsForca", rotulo = "Força (%)", opcoes = { 10, 20, 40, 60, 100 } },
		},
		{
			id = "Pixelado",
			rotulo = "Pixelado",
			fonte = "Pixelate",
			fidelidade = "não existe no Roblox",
			indisponivel = true,
			motivo = "O Roblox não deixa reduzir a resolução do 3D",
		},
	},

	-- ajusta: { [pref] = valor } enviado pelo mesmo caminho dos botões (lote de 1 envio por segundo).
	presets = {
		{
			id = "Combinado",
			rotulo = "Combinado",
			fonte = "DitherDownCombined",
			ajusta = {
				Pref_FDither = true,
				Pref_FDitherMatriz = 2,
				Pref_FDitherForca = 25,
				Pref_FVhs = true,
				Pref_FVhsForca = 20,
			},
		},
		{
			id = "Desligar",
			rotulo = "Desligar todos",
			ajusta = {
				Pref_FDither = false,
				Pref_FScanDura = false,
				Pref_FScanSuave = false,
				Pref_FBandas = false,
				Pref_FVhs = false,
			},
		},
	},
}
