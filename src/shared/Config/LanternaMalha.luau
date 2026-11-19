-- Malha da lanterna de peito (pacote PsxFlashLights: FlashLight_003 (PsxFlashLights), Variation2 (FlashLight_3_.png, marrom)).
-- GERADO por ferramentas/lanterna/gerar_config_lanterna.py a partir de modelos 3d/PsxFlashLights/roblox/manifesto.json. Não editar à mão.
-- Eixos do Roblox, studs, origem = meio da face de TRÁS do corpo (encosta no peito), lente para -Z. Sem `modelo` = blocos.
return {
	modelo = 115311051324397, -- Model (FBX) com as MeshParts Corpo, Lente, Botao, Indicador
	textura = "rbxassetid://125172766930899",
	-- o Roblox gira a malha do FBX 180° em Y ao importar (medido no Studio 2026-11-17; igual aos carros,
	-- VeiculoModelo.VIRAR_IMPORTACAO): cada MeshPart é girada isto em volta do próprio centro para a lente voltar a -Z
	giroImportacao = 180,
	partes = {
		Corpo = { tamanho = { 0.241, 0.38, 0.1271 }, centro = { 0.0009, 0.0, -0.0636 } },
		Lente = { tamanho = { 0.204, 0.2044, 0.001 }, centro = { 0.0006, 0.0763, -0.1186 } },
		Botao = { tamanho = { 0.0082, 0.0448, 0.0496 }, centro = { -0.1165, -0.0026, -0.0284 } },
		Indicador = { tamanho = { 0.0122, 0.0543, 0.0222 }, centro = { -0.122, 0.1022, -0.0378 } },
	},
	lente = { centro = { 0.001, 0.0763, -0.1186 }, normal = { 0.0, 0.0, -1.0 }, raio = 0.1024 },
	botao = { eixo = { 0.0, 1.0, 0.0 }, curso = 0.0306 }, -- exportado DESLIGADO; ligado = +curso no eixo
}
