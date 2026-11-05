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
			Idle = "rbxassetid://75498104488794",
			Walk = "rbxassetid://72375333938634",
			Run = "rbxassetid://134318397938323",
			Attack = "rbxassetid://95860538607052",
			Death = "rbxassetid://118340794455812",
		},
		duracao = { Idle = 2.5, Walk = 1.3333, Run = 0.6667, Attack = 1.4583, Death = 1.9583 }, -- s
	},
}
