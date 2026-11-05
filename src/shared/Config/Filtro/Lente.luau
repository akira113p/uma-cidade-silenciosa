-- Distorção de lente por esfera Glass (docs/filtro.md §5 S3). PROVISÓRIO: tudo afinável (Filtro_Lente_<chave>).
return {
	-- 2026-11-03: 2.4/1.4 deixava a borda da esfera visível na tela. Para cobrir a tela larga o raio angular
	-- (asin(r/d)) tem que passar do meio-FOV horizontal (~62°): r/d ≈ 0.9 com a face da frente a ~0.6 stud.
	diametro = 10, -- studs
	distancia = 5.6, -- studs: do centro da esfera até a câmera
	transparencia = 0.85, -- 0..1 (o Glass só refrata com transparência > 0)
	cor = { 0.95, 0.97, 1 }, -- RGB 0..1
	qualidadeMinima = 8, -- SavedQualityLevel.Value mínimo (0 = automático, conta como baixo)
	ignorarQualidade = false, -- true ignora a qualidade (útil no Studio)
	nivelMinimo = 3, -- nível automático mínimo para ficar ligada
	reavaliarQualidade = 2, -- s
}
