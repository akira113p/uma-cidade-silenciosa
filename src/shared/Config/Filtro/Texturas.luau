-- Ids das imagens do filtro (docs/filtro-texturas.md). Vazio = a parte que usa a imagem fica oculta.
-- Preenchidos depois do upload pelo MCP do Studio (assets/filtro/final/LEIAME.md).
return {
	grao = { -- P1 grao_1..4.png (v2 2026-11-03: grão de 2 px, alfa médio 0.30; o v1 de 0.04 não aparecia)
		"rbxassetid://106104171017838",
		"rbxassetid://83941627687257",
		"rbxassetid://97019631618118",
		"rbxassetid://130814017475444",
	},
	vinheta = "rbxassetid://128788362219175", -- P2
	moldura = "rbxassetid://124648894894029", -- P3 (9-slice; SliceCenter em Config/Filtro/Moldura)
	halo = "rbxassetid://132420080737022", -- P4
	craquelado = "rbxassetid://137802722233279", -- P5 craquelado.png (rede de rachaduras, tileável)
	riscos = "rbxassetid://111445159871928", -- P6 riscos_filme.png (risco vertical de filme)
	-- T1–T5: geradas no ChatGPT, auditadas e processadas (assets/filtro/final), upload 2026-11-03
	neblinaMechaA = "rbxassetid://122555313724930", -- T1a (v2: laterais esmaecidas)
	neblinaMechaB = "rbxassetid://95297107100107", -- T1b (v2)
	neblinaPuff = "rbxassetid://117216911048719", -- T2
	coneLuz = "rbxassetid://107050879762706", -- T3
	tracking = "rbxassetid://73406609300688", -- T4
	poeira = "rbxassetid://132047947622474", -- T5
	-- Filtros do DitherDown (docs/filtro-ditherdown.md §4). Vazio = textura gerada em execução (EditableImage) por
	-- src/client/Filtro/RetroTextura.luau; um id aqui tem prioridade (use se o upload voltar a funcionar).
	retroDither = "",
	retroScanDura = "",
	retroScanSuave = "",
	retroBandas = "",
}
