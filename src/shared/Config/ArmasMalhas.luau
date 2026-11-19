-- Malhas das armas (docs/armas.md §8). Origem = empunhadura, cano para -Z, cima +Y, studs.
-- GERADO por ferramentas/modelos/gerar_config_armas.py (manifesto.json + enviados.json). Nao editar a mao.
-- `false` = ainda sem malha enviada: Shared/ArmaModelo cai no bloco provisorio.
return {
	faca = false, -- EXCLUIDA do envio (armas_modelos.json > excluidas)
	peDeCabra = {
		comprimento = 1.7448, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://102988021276894",
				textura = "rbxassetid://87006118229922",
				posicao = { x = 0, y = 0, z = 0 },
				tamanho = { x = 0.0648, y = 0.3105, z = 1.7448 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.0236, z = -0.848 },
		},
	},
	machado = {
		comprimento = 2.3264, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://132761883380161",
				textura = "rbxassetid://74090344582974",
				posicao = { x = 0, y = -0.1004, z = -0.2792 },
				tamanho = { x = 0.2173, y = 0.8371, z = 2.3264 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = -0.3762, z = -1.4008 },
		},
	},
	pistola = {
		comprimento = 0.5816, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://99578214729683",
				textura = "rbxassetid://71595023366000",
				posicao = { x = 0, y = 0.0362, z = -0.2036 },
				tamanho = { x = 0.0576, y = 0.3617, z = 0.5816 },
			},
		},
		ancoras = {
			Boca = { x = 0.0002, y = 0.1717, z = -0.4944 },
			Ejecao = { x = 0.0288, y = 0.1808, z = -0.2036 },
			Mira = { x = 0, y = 0.217, z = 0.0291 },
		},
	},
	beretta = {
		comprimento = 0.631, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://129689935791597",
				textura = "rbxassetid://101851030317324",
				posicao = { x = 0, y = 0.0565, z = -0.2082 },
				tamanho = { x = 0.1014, y = 0.4037, z = 0.631 },
			},
		},
		ancoras = {
			Boca = { x = 0.016, y = 0.2021, z = -0.5203 },
			Ejecao = { x = 0.0507, y = 0.218, z = -0.2398 },
			Mira = { x = 0, y = 0.2584, z = 0.0568 },
		},
	},
	ar15 = {
		comprimento = 2.6172, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://113926211711996",
				textura = "rbxassetid://81075517109608",
				posicao = { x = 0, y = 0.1415, z = -0.4449 },
				tamanho = { x = 0.1442, y = 0.7076, z = 2.6172 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.2509, z = -1.7535 },
			Ejecao = { x = 0.0721, y = 0.2123, z = -0.1832 },
			ApoioEsquerdo = { x = 0, y = 0.1415, z = -0.9684 },
			Mira = { x = 0, y = 0.4953, z = -0.1832 },
		},
	},
	carabinaM5 = {
		comprimento = 2.0938, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://129838237287525",
				textura = "rbxassetid://74388766383335",
				posicao = { x = 0, y = 0.1696, z = -0.3559 },
				tamanho = { x = 0.2134, y = 0.8478, z = 2.0938 },
			},
		},
		ancoras = {
			Boca = { x = -0.0022, y = 0.3785, z = -1.3751 },
			Ejecao = { x = 0.1067, y = 0.2543, z = -0.1466 },
			ApoioEsquerdo = { x = 0, y = 0.1696, z = -0.7747 },
			Mira = { x = 0, y = 0.5935, z = -0.1466 },
		},
	},
	ak74 = {
		comprimento = 2.7422, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://114906199612127",
				textura = "rbxassetid://74825393687877",
				posicao = { x = 0, y = 0.0155, z = -0.4936 },
				tamanho = { x = 0.1411, y = 0.7731, z = 2.7422 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.2955, z = -1.7922 },
			Ejecao = { x = 0.0705, y = 0.0928, z = -0.4936 },
			ApoioEsquerdo = { x = 0, y = 0.1082, z = -1.0421 },
			Mira = { x = 0, y = 0.402, z = -0.4936 },
		},
	},
	escopeta = {
		comprimento = 3.0534, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://87632972010044",
				textura = "rbxassetid://127090095828298",
				posicao = { x = 0, y = 0, z = -1.1298 },
				tamanho = { x = 0.3365, y = 0.7698, z = 3.0534 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.2821, z = -2.6358 },
			Ejecao = { x = 0.1683, y = 0.2309, z = -0.8244 },
			ApoioEsquerdo = { x = 0, y = 0.0924, z = -1.5878 },
			Mira = { x = 0, y = 0.3849, z = -1.1298 },
		},
	},
	escopetaM1912 = {
		comprimento = 2.9371, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://138914695130475",
				textura = "rbxassetid://136077526188139",
				posicao = { x = 0, y = 0.0268, z = -0.5874 },
				tamanho = { x = 0.1294, y = 0.5358, z = 2.9371 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.2301, z = -2.0075 },
			Ejecao = { x = 0.0647, y = 0.1875, z = -0.2937 },
			ApoioEsquerdo = { x = 0, y = 0.0804, z = -1.1748 },
			Mira = { x = 0, y = 0.2947, z = -0.5874 },
		},
	},
	lancaFoguetes = {
		comprimento = 2.7626, -- studs
		partes = {
			{
				nome = "Corpo",
				malha = "rbxassetid://79826679774039",
				textura = "rbxassetid://91344746619230",
				posicao = { x = 0, y = 0.0864, z = -0.4826 },
				tamanho = { x = 0.1036, y = 0.3395, z = 1.6834 },
			},
			{
				nome = "Foguete",
				malha = "rbxassetid://139374387133539",
				textura = "rbxassetid://91344746619230",
				posicao = { x = 0, y = 0.2085, z = -1.8313 },
				tamanho = { x = 0.2008, y = 0.1739, z = 1.1444 },
			},
		},
		ancoras = {
			Boca = { x = 0, y = 0.2085, z = -2.4035 },
			ApoioEsquerdo = { x = 0, y = 0.1515, z = -0.7459 },
			Mira = { x = 0, y = 0.2955, z = -0.4696 },
		},
	},
}
