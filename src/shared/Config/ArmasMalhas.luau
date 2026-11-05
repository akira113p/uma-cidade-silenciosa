-- Malhas das armas (docs/armas.md §8). Origem = empunhadura, cano para -Z, cima +Y, studs.
-- GERADO por ferramentas/modelos/gerar_config_armas.py (manifesto.json + enviados.json). Nao editar a mao.
-- `false` = ainda sem malha enviada: Shared/ArmaModelo cai no bloco provisorio.
return {
	faca = false, -- EXCLUIDA do envio (armas_modelos.json > excluidas)
	peDeCabra = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	machado = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	pistola = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
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
	ar15 = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	carabinaM5 = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	ak74 = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	escopeta = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	escopetaM1912 = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
	lancaFoguetes = false, -- falta enviar/ler meshId/imagem (ver enviados.json)
}
