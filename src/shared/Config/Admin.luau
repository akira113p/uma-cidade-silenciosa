-- Menu de admin (tecla O). Quem pode: o Studio e os UserIds abaixo. A decisão é do servidor (server/Admin.luau).

return {
	donos = { 4057187673 }, -- kay_113p
	liberarNoStudio = true,
	liberarParaTodos = true, -- TEMPORÁRIO (2026-11-01): qualquer jogador abre o admin. Voltar a false antes de publicar.
	tecla = "O", -- tecla que abre o menu (nome de Enum.KeyCode)
	teclaReserva = "K", -- também abre, caso o O esteja em conflito (o Roblox usa I/O para o zoom da câmera)
	maxQuantidade = 99,
	velocidadeVoo = 60, -- studs/s (Shift multiplica por multVooRapido)
	multVooRapido = 3,
	horas = {
		{ rotulo = "Amanhecer", hora = 6 },
		{ rotulo = "Dia", hora = 12 },
		{ rotulo = "Entardecer", hora = 18 },
		{ rotulo = "Noite", hora = 0 },
	},
	quantidades = { 1, 5, 10, 30 },

	-- Invocação de carros e monstros (menu de admin). Nascem na frente do jogador, no chão.
	invocar = {
		distancia = 32, -- studs à frente do jogador
		espacamento = 13, -- studs entre os carros de uma fila (carro tem até ~8 de largura)
		maxCarros = 12, -- por admin: passando disto o mais antigo some
		maxMonstros = 24, -- por admin
		quantidadesMonstro = { 1, 3, 5, 10 },
		espacamentoMonstros = 4,
	},

	-- Presets de carro: pedido parcial (Regras/Veiculo.montar); o resto fica perfeito. O menu também monta peça por peça.
	-- Rodas: FE FD TE TD. Vidros: ParaBrisa Traseiro JanelaE JanelaD. Peças: Capo PortaMalas PortaE PortaD ParaChoque.
	presetsCarro = {
		{ rotulo = "Inteiro", pedido = {} },
		{
			rotulo = "Avariado",
			pedido = {
				motor = 55,
				carroceria = 55,
				pneus = { FE = "furado" },
				vidros = { ParaBrisa = "quebrado" },
				faltando = { Capo = true },
			},
		},
		{
			rotulo = "Destruído",
			pedido = {
				motor = 10,
				carroceria = 15,
				pneus = { FE = "furado", TD = "faltando" },
				vidros = { ParaBrisa = "quebrado", JanelaE = "faltando", JanelaD = "quebrado" },
				faltando = { Capo = true, PortaD = true, ParaChoque = true },
			},
		},
		{ rotulo = "Queimado", pedido = { queimado = true, carroceria = 5 } },
		{ rotulo = "Motor quebrado", pedido = { motor = 0 } },
		{
			rotulo = "Pneus furados",
			pedido = { pneus = { FE = "furado", FD = "furado", TE = "furado", TD = "furado" } },
		},
		{
			rotulo = "Sem pneus",
			pedido = { pneus = { FE = "faltando", FD = "faltando", TE = "faltando", TD = "faltando" } },
		},
		{
			rotulo = "Vidros quebrados",
			pedido = {
				vidros = { ParaBrisa = "quebrado", Traseiro = "quebrado", JanelaE = "quebrado", JanelaD = "quebrado" },
			},
		},
		{
			rotulo = "Sem vidros",
			pedido = {
				vidros = { ParaBrisa = "faltando", Traseiro = "faltando", JanelaE = "faltando", JanelaD = "faltando" },
			},
		},
		{
			rotulo = "Sem peças",
			pedido = { faltando = { Capo = true, PortaMalas = true, PortaE = true, PortaD = true, ParaChoque = true } },
		},
	},
}
