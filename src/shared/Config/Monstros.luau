-- Monstros (docs/calculos.md §2). Regra de percepção: src/shared/Regras/Percepcao.luau. PROVISÓRIO.
-- Nomes e níveis dos modelos são provisórios (pasta "modelos 3d/monstros"). No corte vertical só o nível 1 nasce.

return {
	margemPorNivel = { [1] = 0, [2] = 6, [3] = 12 }, -- dB a mais que o ambiente para ouvir

	estados = {
		investigaAte = 10, -- excesso (dB) < isto → Investiga; >= → Caça
		somsParaCaca = 2, -- este número de sons dentro de janelaCaca também → Caça
		janelaCaca = 5, -- s
		investigaTimeout = 12, -- s sem ouvir → Calmo
		cacaTimeout = 8, -- s sem ouvir → Investiga
		erroPorDistancia = 0.15, -- raio do erro da posição estimada = distância × isto
		distanciaAtaque = 4, -- studs
		raioVagar = 40, -- studs em volta do ponto de nascimento no estado Calmo
	},

	niveis = {
		[1] = {
			velocidadeCalmo = 6,
			velocidadeCaca = 14,
			dano = 20,
			intervaloGolpe = 1.5,
			vida = 80,
			gritaAoCacar = true,
		},
		[2] = {
			velocidadeCalmo = 8,
			velocidadeCaca = 22,
			dano = 35,
			intervaloGolpe = 1.2,
			vida = 200,
			gritaAoCacar = false,
		},
		[3] = {
			velocidadeCalmo = 10,
			velocidadeCaca = 27,
			dano = 70,
			intervaloGolpe = 2.0,
			vida = 600,
			gritaAoCacar = false,
		},
	},

	-- Onde o golpe do monstro cai (soma 1)
	sorteioParte = {
		{ parte = "Torso", peso = 0.40 },
		{ parte = "BracoE", peso = 0.125 },
		{ parte = "BracoD", peso = 0.125 },
		{ parte = "PernaE", peso = 0.125 },
		{ parte = "PernaD", peso = 0.125 },
		{ parte = "Cabeca", peso = 0.10 },
	},

	-- Espécies. modelo = nome em ServerStorage.Modelos.Monstros; se não existir, o servidor monta um boneco de blocos.
	especies = {
		{
			id = "Rastejador",
			nivel = 1,
			modelo = "Rastejador",
			cor = { 90, 80, 70 },
			tamanho = { 3, 3, 5 },
			-- docs/rastejador.md: malha real + animação (server/MonstroModelo) e capacidades extras (degrau, parede, carro).
			-- Altura no preset (Config/PresetsMonstro; jogador ÷ 1,8). Só o Rastejador liga isto; Corcunda/Esfolado seguem como estão.
			malha = true,
			preset = "quadrupedeArrombador", -- Config/PresetsMonstro
			capacidades = { degrau = true, arrombar = true, veiculo = true },
		},
		-- docs/wrapper.md: monstro sem braços, golpe por investida (preset corpoAriete). Nasce nos pontos do mapa junto com o Rastejador
		-- (liberado pelo usuário em 2026-11-13; malha, textura e 6 animações enviadas). `semNascer = true` voltaria a só invocar pelo admin.
		{
			id = "Wrapper",
			nivel = 1,
			modelo = "Wrapper",
			cor = { 120, 110, 100 },
			tamanho = { 3, 6, 3 },
			malha = true,
			preset = "corpoAriete",
			capacidades = { degrau = true, arrombar = true, veiculo = true },
		},
		-- 2026-11-14 (decisão do usuário): Corcunda, MonstroPS1 e Florescida com malha refeita no Blender (5 clipes), nascem no mapa.
		-- Corcunda e MonstroPS1: só degrau (não arrombam, não mordem carro). Florescida: degrau + arrombar + veículo.
		{
			id = "Corcunda",
			nivel = 1,
			modelo = "Corcunda",
			cor = { 110, 95, 85 },
			tamanho = { 3, 5, 2 },
			malha = true,
			preset = "corcunda",
			capacidades = { degrau = true },
		},
		{
			id = "MonstroPS1",
			nivel = 1,
			modelo = "MonstroPS1",
			cor = { 100, 100, 110 },
			tamanho = { 4, 6, 2 },
			malha = true,
			preset = "monstroPS1",
			capacidades = { degrau = true },
		},
		{ id = "Esfolado", nivel = 1, modelo = "Esfolado", cor = { 130, 70, 65 }, tamanho = { 2, 6, 2 } },
		{ id = "Espreitador", nivel = 2, modelo = "Espreitador", cor = { 60, 60, 70 }, tamanho = { 3, 7, 3 } },
		{ id = "Carniceiro", nivel = 2, modelo = "Carniceiro", cor = { 100, 40, 40 }, tamanho = { 4, 7, 3 } },
		-- nascerSempre: nasce mesmo com nivel > nivelAtivoMaximo (o inverso de semNascer).
		-- 2026-11-14 (usuário): gigante (5,5 m = 16 studs), nível alto e forte -> números do nível 3 (vida 600, dano 70).
		{
			id = "Florescida",
			nivel = 3,
			modelo = "Florescida",
			cor = { 80, 100, 70 },
			tamanho = { 5, 16, 20 },
			malha = true,
			nascerSempre = true,
			preset = "florescida",
			-- logica.md §2.6/§7.4: um por servidor (admin até 2), só nasce fora da zona `cidade`; a fachada substitui o arrombar
			maxPorServidor = 1,
			maxAdmin = 2,
			foraDaZona = "cidade",
			capacidades = { degrau = true, arrombar = false, veiculo = true },
		},
		{ id = "Pernalta", nivel = 3, modelo = "Pernalta", cor = { 50, 45, 50 }, tamanho = { 4, 14, 4 } },
	},

	nivelAtivoMaximo = 1, -- corte vertical: só nascem espécies com nivel <= isto (ou com `nascerSempre = true`; `semNascer = true` nunca nasce)

	-- Densidade: 1 monstro por (lado x lado) studs dentro de cada zona do mapa
	densidade = {
		cidade = 60,
		vila = 120,
		floresta = 150,
		fabrica = 80,
		outros = 200,
	},
	maxPorServidor = 250,
	recalcularCaminhoMin = 0.5, -- s entre recálculos de caminho do mesmo monstro
}
