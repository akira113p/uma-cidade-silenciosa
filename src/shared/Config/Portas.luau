-- Portas funcionais (docs/monstros/logica.md §2.1). Tudo PROVISÓRIO: afinar no playtest.
-- A folha do mapa nasce entreaberta a `anguloMapa` graus; o servidor a monta como porta em tempo de execução.

return {
	anguloMapa = 75, -- graus: abertura da Folha no arquivo do mapa (ferramentas/mapa/lib.luau, th = 1.3 rad)
	comecaAberta = true,
	duracaoAbrir = 0.35, -- s
	duracaoFechar = 0.35,
	duracaoBater = 0.15,
	cooldown = 0.25, -- s entre dois acionamentos da mesma porta

	-- ruído (dB, tipo do Ruido.emitir) por modo
	ruido = {
		abrir = { db = 45, tipo = "portaAbrir" },
		abrirAgachado = { db = 25, tipo = "portaAbrir" },
		fechar = { db = 50, tipo = "portaFechar" },
		bater = { db = 65, tipo = "portaBater" },
	},
	sons = { abrir = "PortaAbrir", fechar = "PortaFechar", bater = "PortaBater" },

	prompt = {
		tecla = "E",
		distancia = 6,
		linhaDeVisao = true,
		textoAbrir = "Abrir",
		textoFechar = "Fechar",
		folgaServidor = 4, -- studs além da distância do prompt aceitos no servidor (lag)
	},

	-- montagem em lotes (servidor): construções por lote antes de task.wait()
	lote = 25,
	-- busca espacial
	celula = 32, -- studs
	alturaFolga = 3, -- studs de folga vertical em naLinha
	invalidarRaio = 12, -- Monstros.invalidarCaminhos(pos, raio)
}
