-- Aberração cromática por divisão de FOV (docs/filtro.md §5 S2). Regras: src/shared/Regras/FiltroAberracao.luau. PROVISÓRIO.
-- Afinação ao vivo no Studio (atributos do jogador): Filtro_AberracaoBase, Filtro_AberracaoFov, Filtro_AberracaoRaio.

return {
	-- Intensidade 0..1 = base + pulsos; abaixo de minimoVisivel a camada fica oculta (custo zero)
	base = 0.6, -- intensidade parada
	extraDano = 0.5, -- somado × pulsos.dano (0..1)
	extraSusto = 0.4, -- somado × pulsos.susto (0..1)
	extraCaca = 0.3, -- somado × caca (0..1)
	minimoVisivel = 0.05,

	-- FOV: com intensidade 1 o vermelho usa fov - fovDelta e o ciano fov + fovDelta
	fovDelta = 4.5, -- graus por lado (franja radial: zero no centro, cresce para a borda)
	pesoCor = 0.18, -- 0..<0.5: peso de cada cor (vermelho e ciano) sobre a cena com intensidade 1; a cena fica com 1 - 2 x isto
	corVermelho = { 1, 0, 0 }, -- RGB 0..1 (ImageColor3 do viewport vermelho)
	corCiano = { 0, 1, 1 }, -- RGB 0..1

	-- Iluminação dos viewports (1 Hz): Ambient = Lighting.Ambient; luz direcional mistura dia e noite
	intervaloLuz = 1, -- s
	luzDia = { 1, 1, 1 }, -- LightColor ao meio-dia
	luzNoite = { 0.25, 0.22, 0.2 }, -- LightColor à noite fechada

	-- Estático: clones da geometria de workspace.Mapa perto da câmera, por célula
	tamanhoCelula = 32, -- studs
	raioEstatico = 50, -- studs da câmera
	margemDescarte = 16, -- studs além do raio antes de destruir a célula
	intervaloCelulas = 0.25, -- s (4 Hz): reavalia quais células faltam e quais descartar
	clonesPorQuadro = 30, -- partes clonadas por quadro (cada uma gera 2 clones, um por viewport); consulta de célula conta 1
	tamanhoMinimoParte = 0.8, -- studs: partes cuja maior dimensão é menor que isso não entram (poupa peças de detalhe)
	maxPartesPorCelula = 500, -- teto por célula; sobrando, ficam as maiores
	consultaMaxPartes = 3000, -- OverlapParams.MaxParts da consulta da célula
	transparenciaMaxima = 0.5, -- só entra parte com Transparency abaixo disso (opaca)
	alturaConsulta = 800, -- studs: altura da caixa de consulta da célula
	centroYConsulta = 200, -- studs: Y do centro da caixa de consulta

	ladoMaximo = 120, -- studs: partes com maior dimensão acima disso não entram (enormes)
	maxPartesTotal = 6000, -- guarda de desempenho: acima disso (por viewport) não abre células novas
	-- Sem névoa nos ViewportFrames: a névoa vira cor (clone vai para Lighting.FogColor); clones sempre opacos
	fatorSemTextura = 0.6, -- acima desta fração de névoa o MeshPart perde o TextureID (fica só a cor)
	pastasExcluidas = { "Chao", "Ruas", "Rios" }, -- filhos de workspace.Mapa que nunca entram no estático
	intervaloNevoa = 0.5, -- s (2 Hz): refaz a cor de névoa dos estáticos
	passoNevoaCelula = 2, -- studs: só refaz a célula se a distância até ela mudou mais que isso

	-- Franja por distância (independe da névoa): clone opaco até franjaPerto, some (transparência) até franjaLonge
	franjaPerto = 18, -- studs
	franjaLonge = 48, -- studs
	parteGrande = 24, -- studs: partes com maior dimensão acima disso medem a distância até a caixa (AABB), não ao centro

	-- Dinâmico: monstros e personagens de outros jogadores, só quando a câmera os vê
	raioDinamico = 60, -- studs
	fracaoNevoaDinamico = 0.85, -- alcance também limitado a FogStart + (FogEnd - FogStart) x isto (além, a névoa já esconde)
	intervaloVisibilidade = 0.1, -- s (10 Hz): raios de visibilidade
	pontosVisiveisMinimos = 1, -- quantos dos pontos (cabeça, tronco) precisam estar livres; 2 = mais justo, esconde mais cedo
}
