-- Postes à noite (docs/filtro.md §5 S4). Tudo PROVISÓRIO: afinar por captura de tela no Studio.
-- Cores em {r, g, b} 0..255 (sem Color3, para a Config carregar no Lune).
return {
	-- quais lâmpadas
	nomes = { "poste_luz", "poste_luz_rodovia" }, -- Model.Name (e atributo Prop) dos postes
	maxLuzes = 8, -- SpotLights simultâneos (pool fixo)
	maxHalos = 30, -- halos simultâneos (pool fixo)
	alcance = 140, -- studs: distância máxima da câmera para ganhar luz e cone
	alcanceHalo = 260, -- studs: distância máxima para ganhar halo
	intervaloEscolha = 0.25, -- s (4 Hz): reescolha dos postes mais próximos

	-- noite
	limiarNoite = 0.35, -- 0..1: abaixo disso de e.noite nada aparece
	faixaNoite = 0.3, -- 0..1: largura da subida até o brilho cheio

	-- lâmpadas com defeito (hash da posição)
	fracaoQuebrada = 0.12, -- 0..1: proporção apagada para sempre
	fracaoPisca = 0.1, -- 0..1: proporção que pisca

	-- luz
	cor = { 255, 196, 120 }, -- sépia quente
	brilhoSpot = 7, -- Brightness do SpotLight (2026-11-03: 2.5 quase não iluminava o chão a 21 studs de altura)
	anguloSpot = 75, -- graus
	alcanceSpot = 60, -- studs (Range)
	recuoLuz = 0.3, -- studs abaixo do centro da lâmpada onde a luz nasce

	-- cone (Beam)
	coneLargura0 = 1.5, -- studs, na lâmpada
	coneLargura1 = 16, -- studs, no chão (2026-11-03: 20 passava da poça do SpotLight)
	coneTransparencia = 0.72, -- 0..1 com brilho cheio (1 = invisível; 2026-11-03: 0.55 ficava sólido demais)
	alturaPadrao = 20, -- studs: altura do cone se o raio para baixo não achar chão
	alcanceRaio = 80, -- studs: raio da lâmpada para o chão

	conePertoEixo = 9, -- studs: distância horizontal da câmera ao poste abaixo da qual o cone some
	coneLongeEixo = 22, -- studs: a partir daqui o cone aparece inteiro
	coneDotMin = 0.55, -- |LookVector.Y| até aqui o cone aparece inteiro
	coneDotMax = 0.85, -- |LookVector.Y| daqui em diante (olhando ao longo do eixo) o cone some

	-- halo
	haloTamanho = 16, -- studs (BillboardGui em escala de mundo)
	haloTransparencia = 0.6, -- 0..1 com brilho cheio
}
