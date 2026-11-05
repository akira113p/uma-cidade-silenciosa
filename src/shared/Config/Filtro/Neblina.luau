-- Névoa em camadas: colunas de Beam e partículas rasteiras (docs/filtro.md §5 S3). PROVISÓRIO: afinar no Studio.
return {
	espacamento = 28, -- studs entre colunas da grade
	raioInterno = 12, -- studs: sem coluna mais perto que isto da câmera
	raioExterno = 150, -- studs: sem coluna mais longe que isto
	rampaInterna = 8, -- studs: entrada gradual depois do raio interno
	rampaExterna = 50, -- studs: saída gradual antes do raio externo
	jitter = 8, -- studs: deslocamento máximo de cada coluna na grade
	altura = 14, -- studs: altura da coluna
	largura = 36, -- studs: largura do beam mais largo
	camadas = { 1, 0.66, 0.36 }, -- beams sobrepostos por coluna (fração da largura): borda em degraus + núcleo denso
	-- 2026-11-03: 0.55 e perfil mais duro faziam cada coluna parecer uma placa; mais leve e com topo mais suave
	transparenciaChao = 0.65, -- 0..1: transparência da base da coluna na densidade cheia
	perfil = { { 0, 1 }, { 0.35, 0.5 }, { 0.75, 0.1 }, { 1, 0 } }, -- {posição 0..1 ao longo da altura, densidade 0..1}
	clarear = 0.15, -- 0..1: quanto o FogColor é misturado com branco
	niveisFade = 10, -- degraus de densidade (quantiza a transparência)
	velocidadeTextura = 0.03, -- studs/s
	tetoAlcance = 40, -- studs: coluna sob teto mais baixo que isto é pulada
	alcanceRaioChao = 400, -- studs: tamanho do raio para baixo
	colunasPorQuadro = 6, -- resoluções de coluna nova (2 raios cada) por quadro
	alturaOlhos = 3.5, -- studs: câmera acima do chão, se o raio não achar chão
	reTentarChao = 1.5, -- s: nova tentativa para coluna sem chão (mapa em streaming)
	maxCache = 4000, -- entradas do cache de chão/teto
	multiplicadorNivel2 = 1.5, -- espaçamento no nível 2
	densidadeInterior = 0.7, -- quanto a densidade cai dentro de prédio (× interior)
	clima = { limpo = 1, chuva = 1, tempestade = 1 }, -- multiplicador de densidade por clima (teto 1)
	-- Partículas rasteiras
	particulas = {
		lado = 180, -- studs: lado da caixa que segue a câmera
		taxaDia = 4, -- partículas/s
		taxaNoite = 7,
		multiplicadorClima = { limpo = 1, chuva = 1.3, tempestade = 1.6 },
		tamanhoMin = 12, -- studs
		tamanhoMax = 24,
		vidaMin = 8, -- s
		vidaMax = 14,
		velMin = 0.5, -- studs/s
		velMax = 1.2,
		transparencia = 0.7, -- no meio da vida
	},
}
