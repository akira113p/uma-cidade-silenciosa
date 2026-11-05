-- Filtro visual: granulação (src/client/Filtro/Grao.luau). PROVISÓRIO.
return {
	-- 2026-11-03 (2º ajuste): usuário relatou dor de cabeça; alvo "bem de leve" (referência: Silent Hill 1, grão discreto).
	-- Cobertura efetiva = 0.30 (alfa médio da textura) × (1 - transparência): dia ~2%, noite ~3%. Menos quadros/s
	-- também reduz a cintilação, que é o que cansa a vista.
	fps = 8, -- quadros de grão por segundo
	tamanhoTile = 256, -- px: lado da textura grao_N.png e do deslocamento aleatório
	transparenciaDia = 0.93, -- 0..1: ImageTransparency do grão com noite = 0
	transparenciaNoite = 0.9, -- idem com noite = 1 (um pouco mais de grão à noite)
	extraDano = 0.12, -- quanto o pulso de dano 1 tira da transparência (mais grão)
	zIndex = 50,
}
