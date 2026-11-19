-- GERADO por ferramentas/modelos/gerar_config_monstros.py. Nao editar a mao.

return {
	Rastejador = {
		modelo = 134924177372078,
		textura = "rbxassetid://120887041573147",
		dimensoes = { x = 9.7829, y = 5.816, z = 10.5841 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 2.6622, y = 2.9036, z = 5.3217 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = -0.3275, y = 1.0885, z = 0.6884 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 2.5447, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://104438747042041",
			Walk = "rbxassetid://118854865410226",
			Run = "rbxassetid://101228530234571",
			Attack = "rbxassetid://95282390106880",
			Death = "rbxassetid://99159905944593",
			Arrombar = "rbxassetid://138880664417694",
			Pulso = "rbxassetid://115212802814725",
		},
		duracao = {
			Idle = 2.5,
			Walk = 1.3333,
			Run = 0.6667,
			Attack = 1.4583,
			Death = 1.9583,
			Arrombar = 0.9167,
			Pulso = 2,
		}, -- s
		eventos = { -- s desde o inicio do clipe (medido no clipe)
			Attack = { impacto = 0.75 },
			Arrombar = { impacto = 0.4583 },
			Pulso = { encostou = 0.5833 },
		},
		nativas = { Walk = 1.5862, Run = 8.6862 }, -- studs/s sem patinar
	},
	Wrapper = {
		modelo = 139692232616423,
		textura = "rbxassetid://130716678861042",
		dimensoes = { x = 1.6908, y = 5.99, z = 0.9966 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 0.9563, y = 2.8524, z = 0.8795 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = 0.0719, y = 1.5688, z = 0.0401 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 3.1375, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://95122845712418",
			Walk = "rbxassetid://134675669413644",
			Run = "rbxassetid://125185595075666",
			Attack = "rbxassetid://95839174890160",
			Death = "rbxassetid://77536866292055",
			Atordoado = "rbxassetid://135079606792996",
			Sonar = "rbxassetid://140102825284485",
			WallSlam = "rbxassetid://75482192805357",
		},
		duracao = {
			Idle = 2,
			Walk = 1,
			Run = 0.5333,
			Attack = 1,
			Death = 1.5,
			Atordoado = 2,
			Sonar = 1.2,
			WallSlam = 1.2,
		}, -- s
		eventos = { -- s desde o inicio do clipe (medido no clipe)
			Attack = { impacto = 0.4667 },
			Sonar = { onda = 0.5 },
			WallSlam = { impacto = 0.5 },
		},
		nativas = { Walk = 2.6497, Run = 15.5388 }, -- studs/s sem patinar
	},
	Corcunda = {
		modelo = 83181162241062,
		textura = "rbxassetid://125972263271742",
		dimensoes = { x = 3.2094, y = 5.816, z = 3.6108 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 1.4091, y = 2.8397, z = 2.7097 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = 0.4099, y = 1.4882, z = -0.4505 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 2.9763, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://133201526418737",
			Walk = "rbxassetid://100534892548685",
			Run = "rbxassetid://121394558844883",
			Attack = "rbxassetid://104200579813262",
			Death = "rbxassetid://102747171727482",
			AbrirPorta = "rbxassetid://123278156859336",
			Emboscada = "rbxassetid://71846367883726",
			Empurrao = "rbxassetid://127014390383821",
			Imitar = "rbxassetid://71217902943780",
		},
		duracao = {
			Idle = 2,
			Walk = 1,
			Run = 0.6,
			Attack = 0.9,
			Death = 1.5,
			AbrirPorta = 0.8,
			Emboscada = 3,
			Empurrao = 0.7,
			Imitar = 1.5,
		}, -- s
		eventos = { -- s desde o inicio do clipe (medido no clipe)
			Attack = { impacto = 0.4667 },
			AbrirPorta = { porta = 0.4 },
			Empurrao = { impacto = 0.3333 },
		},
		nativas = { Walk = 2.6436, Run = 13.2182 }, -- studs/s sem patinar
	},
	MonstroPS1 = {
		modelo = 82098452856067,
		textura = "rbxassetid://130533141359461",
		dimensoes = { x = 4.8058, y = 5.816, z = 1.0818 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 2.7572, y = 3.3313, z = 1.0444 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = 0.2337, y = 1.2423, z = 0.0187 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 2.4847, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://82206332851050",
			Walk = "rbxassetid://72930579440713",
			Run = "rbxassetid://83775484510519",
			Attack = "rbxassetid://98282272832236",
			Death = "rbxassetid://109433537588825",
			Arrancada = "rbxassetid://77180601899698",
			GolpeDuplo = "rbxassetid://99132481199199",
			Lancar = "rbxassetid://133607389220492",
		},
		duracao = {
			Idle = 2,
			Walk = 1.1333,
			Run = 0.6667,
			Attack = 0.9,
			Death = 1.5,
			Arrancada = 0.6,
			GolpeDuplo = 1,
			Lancar = 0.8,
		}, -- s
		eventos = { -- s desde o inicio do clipe (medido no clipe)
			Attack = { impacto = 0.4667 },
			GolpeDuplo = { impacto1 = 0.3333, impacto2 = 0.6667 },
			Lancar = { soltar = 0.4667 },
		},
		nativas = { Walk = 2.2577, Run = 11.8964, Arrancada = 13.6385 }, -- studs/s sem patinar
	},
	Florescida = {
		modelo = 123431633584876,
		textura = "rbxassetid://128840723426490",
		dimensoes = { x = 4.6231, y = 16, z = 19.7735 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 4.1247, y = 7.5079, z = 11.8041 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = -0.2492, y = 4.2461, z = -3.9847 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 8.4921, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://74721051908770",
			Walk = "rbxassetid://73527479399990",
			Run = "rbxassetid://86479738624616",
			Attack = "rbxassetid://121875563300223",
			Death = "rbxassetid://97065954411889",
			ArrancarFachada = "rbxassetid://91230632196194",
			Cauda = "rbxassetid://126030945096058",
			Florescer = "rbxassetid://135170153372261",
			Rugido = "rbxassetid://114588831768435",
		},
		duracao = {
			Idle = 2,
			Walk = 1.3333,
			Run = 0.5,
			Attack = 0.9,
			Death = 1.5,
			ArrancarFachada = 1.8,
			Cauda = 0.9,
			Florescer = 1.5,
			Rugido = 1.6,
		}, -- s
		eventos = { -- s desde o inicio do clipe (medido no clipe)
			Attack = { impacto = 0.4667 },
			ArrancarFachada = { impacto = 0.8 },
			Cauda = { impacto = 0.4667 },
			Florescer = { plantar = 0.9 },
			Rugido = { impacto = 0.9 },
		},
		nativas = { Walk = 5.3018, Run = 59.2582 }, -- studs/s sem patinar
	},
}
