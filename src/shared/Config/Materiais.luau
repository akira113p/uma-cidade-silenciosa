-- Materiais da destruição (docs/destruicao.md §4). Material (Enum.Material.Name) -> classe + vida por stud de espessura;
-- classes (efeito visual, sons, ação de ruído); matriz tipo de dano x classe. Tudo PROVISÓRIO: afinar no playtest.
-- Sons: nomes de Config/Sons. acaoQuebra: ação de Config/Som.acoes.

return {
	-- Vida da peça = vidaPorStud x clamp(espessura, min, max); classe "fixa" (vidro) ignora a espessura.
	espessura = { min = 0.5, max = 3 },

	padrao = { classe = "alvenaria", vidaPorStud = 300 },

	materiais = {
		Glass = { classe = "vidro", vidaPorStud = 10, fixa = true },
		Fabric = { classe = "leve", vidaPorStud = 20 },
		SmoothPlastic = { classe = "leve", vidaPorStud = 30 },
		Plastic = { classe = "leve", vidaPorStud = 30 },
		Wood = { classe = "madeira", vidaPorStud = 150 },
		WoodPlanks = { classe = "madeira", vidaPorStud = 150 },
		Sandstone = { classe = "alvenaria", vidaPorStud = 240 },
		Limestone = { classe = "alvenaria", vidaPorStud = 300 },
		Slate = { classe = "alvenaria", vidaPorStud = 300 },
		Brick = { classe = "alvenaria", vidaPorStud = 360 },
		Marble = { classe = "alvenaria", vidaPorStud = 400 },
		Concrete = { classe = "alvenaria", vidaPorStud = 480 },
		Granite = { classe = "alvenaria", vidaPorStud = 520 },
		Basalt = { classe = "alvenaria", vidaPorStud = 560 },
		CorrodedMetal = { classe = "metal", vidaPorStud = 360 },
		Metal = { classe = "metal", vidaPorStud = 600 },
		DiamondPlate = { classe = "metal", vidaPorStud = 900 },
	},

	-- efeito "escurecer": Color = original:Lerp(escurecerAlvo, escurece x estagio / #estagios); "rachar": vidro clareia e fica leitoso.
	classes = {
		vidro = {
			efeito = "rachar",
			inteira = true, -- vidro estilhaça por inteiro: nunca fica pedaço com vão (janela inteira abre)
			escurece = 0,
			somImpacto = "Vidro",
			somQuebra = "Vidro",
			acaoQuebra = "vidro",
			poeira = { 200, 215, 220 },
		},
		madeira = {
			efeito = "escurecer",
			escurece = 0.6,
			somImpacto = "GolpeParede",
			somQuebra = "ParedeCai",
			acaoQuebra = "paredeQuebrando",
			poeira = { 120, 100, 80 },
		},
		alvenaria = {
			efeito = "escurecer",
			escurece = 0.55,
			somImpacto = "GolpeParede",
			somQuebra = "ParedeCai",
			acaoQuebra = "paredeQuebrando",
			poeira = { 150, 145, 135 },
		},
		metal = {
			efeito = "escurecer",
			escurece = 0.5,
			somImpacto = "AcertoMetal",
			somQuebra = "ParedeCai",
			acaoQuebra = "paredeQuebrando",
			poeira = { 110, 110, 115 },
		},
		leve = {
			efeito = "escurecer",
			escurece = 0.5,
			somImpacto = "GolpeParede",
			somQuebra = "ParedeCai",
			acaoQuebra = "paredeQuebrando",
			poeira = { 170, 165, 155 },
		},
	},

	-- dano efetivo = dano x matriz[tipo][classe]. Tipo novo = linha nova (sem mudar código).
	matriz = {
		bala = { vidro = 6, madeira = 0.5, alvenaria = 0.25, metal = 0.2, leve = 2 },
		corte = { vidro = 3, madeira = 1.5, alvenaria = 0.15, metal = 0.1, leve = 3 },
		alavanca = { vidro = 3, madeira = 1.2, alvenaria = 0.5, metal = 0.4, leve = 2 },
		marreta = { vidro = 4, madeira = 1.3, alvenaria = 1.6, metal = 0.8, leve = 3 },
		garra = { vidro = 3, madeira = 1, alvenaria = 0.4, metal = 0.15, leve = 2 },
		soco = { vidro = 1.5, madeira = 0.2, alvenaria = 0.05, metal = 0.02, leve = 1 },
		impacto = { vidro = 3, madeira = 1, alvenaria = 1, metal = 1, leve = 1 },
		explosao = { vidro = 4, madeira = 1.5, alvenaria = 1.2, metal = 0.8, leve = 3 },
	},
}
