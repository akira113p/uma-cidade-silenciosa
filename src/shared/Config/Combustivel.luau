-- Números do combustível (contrato: docs/combustivel.md §3). Regras puras: src/shared/Regras/Combustivel. PROVISÓRIO até o playtest.
-- Unidades: litros (L), segundos (s), studs. O tanque de cada carro fica em Config/Veiculos.tipos[x].tanque.

return {
	autonomiaMaxSeg = 900, -- tanque cheio, motor ligado, na velMax com pedal a fundo: dura 15 min
	autonomiaParadoSeg = 3600, -- tanque cheio, motor ligado, parado: dura 60 min
	fracaoReserva = 0.15, -- abaixo disto: aviso de reserva (HUD pisca)
	fracaoCritica = 0.05, -- abaixo disto (ou 0): HUD vermelho piscando a 2 Hz
	passoAtributo = 0.1, -- L; o atributo Combustivel só muda quando varia >= isto

	mangueira = {
		comprimento = 14, -- studs, máximo entre o bocal da bomba e a ponta
		tolerancia = 2.5, -- studs acima de comprimento: o servidor solta a mangueira
		segmentos = 14, -- pontos da corda Verlet (cliente)
		distanciaDesenho = 150, -- studs da câmera; além disso a mangueira não é simulada
		raio = 0.18, -- studs
		vazaoLps = 0.8, -- L/s ao abastecer carro pela mangueira
		alcanceTampa = 6, -- studs até a tampa para plugar/soltar (ProximityPrompt)
		alcanceBomba = 8, -- studs até a bomba para pegar/guardar/encher
		conferirSeg = 0.2, -- período da checagem de distância no servidor
	},

	-- Por id de item; litros fixos (decisão do usuário, 2026-11-05). Cada id aqui tem de existir em Config/Itens (tipo "recipiente") e vice-versa.
	-- vazio: capacidade + enche (id do item cheio). cheio: litros + despeja (id do item vazio).
	recipientes = {
		garrafaVazia = { capacidade = 0.5, enche = "garrafaGasolina" },
		garrafaGasolina = { litros = 0.5, despeja = "garrafaVazia" },
		galaoVazio = { capacidade = 5, enche = "galaoGasolina" },
		galaoGasolina = { litros = 5, despeja = "galaoVazio" },
	},

	carro = {
		-- Tampa de combustível, proporção do tamanho (sx, sy, sz) do Chassi, relativa ao CENTRO do chassi.
		-- Frente = -Z, esquerda = -X (VeiculoModelo.luau). Lado esquerdo, traseiro, logo atrás da porta.
		-- tamanho = bloco da tampa em studs (X espessura, Y, Z); saliencia = quanto a tampa sai para fora do casco.
		tampa = { fx = -0.5, fy = 0.05, fz = 0.33, tamanho = { 0.15, 0.5, 0.7 }, saliencia = 0.05 },
		etiquetaDistancia = 10, -- studs até a tampa para a etiqueta de gasolina aparecer
	},

	encherSegundos = 1.0, -- HoldDuration do prompt "Encher" na bomba
	despejarSegundos = 2.5, -- tempo travado despejando um galão
	despejarGarrafaSegundos = 1.0, -- idem, garrafa (docs/combustivel.md §6.5)
	espacoMinimoDespejar = 0.25, -- L; com menos espaço no tanque o despejo é recusado ("Tanque cheio") e não gasta o item
}
