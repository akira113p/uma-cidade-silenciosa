-- Modelos de blocos dos itens (docs/itens-no-mundo.md §2). Um por id de Config/Itens.itens. Dados puros: o `local function` abaixo só
-- monta tabelas; o que sai é número e string. Montagem: src/shared/ItemModelo.luau. Regras (validar/caixa/repouso): Regras/ItemModelo.luau.
--
-- Convenção: origem = onde a mão segura; +Y = cima do objeto; -Z = frente/ponta (cano, lâmina, lente). Studs (3 studs ≈ 1 m).
-- Cylinder do Roblox tem o eixo no X da peça: `cil` já gira para "y" (de pé) ou "z" (deitado para a frente). rot em graus,
-- mesma ordem de CFrame.Angles. A primeira peça de cada modelo é a PrimaryPart.
-- mao = CFrame da origem do modelo relativo à mão: o mesmo da empunhadura de Config/ArmasAnim (0, -0.16, 0) com giro -90° em X, que
-- põe o -Z do modelo (ponta) para fora do braço (-Y da mão). chao.rot deita o item; a altura de repouso sai da caixa girada.

local function bloco(nome, tam, pos, cor, material, rot, transp)
	return {
		nome = nome,
		forma = "Block",
		tam = tam,
		pos = pos,
		rot = rot or { 0, 0, 0 },
		cor = cor,
		material = material,
		transp = transp,
	}
end

-- comprimento ao longo de `eixo` ("y" = de pé, "z" = deitado para a frente, "x" = como vem); diam nos outros dois.
local ROT_EIXO = { x = { 0, 0, 0 }, y = { 0, 0, 90 }, z = { 0, 90, 0 } }
local function cil(nome, comprimento, diam, pos, cor, material, eixo, transp)
	return {
		nome = nome,
		forma = "Cylinder",
		tam = { comprimento, diam, diam },
		pos = pos,
		rot = ROT_EIXO[eixo],
		cor = cor,
		material = material,
		transp = transp,
	}
end

local function esfera(nome, diam, pos, cor, material)
	return {
		nome = nome,
		forma = "Ball",
		tam = { diam, diam, diam },
		pos = pos,
		rot = { 0, 0, 0 },
		cor = cor,
		material = material,
	}
end

local function mao()
	return { pos = { 0, -0.16, 0 }, rot = { -90, 0, 0 } }
end

-- Pistola: ferrolho, empunhadura inclinada (topo para a frente), guarda-mato e cano (acento claro).
local function pistola(o)
	return {
		partes = {
			bloco("Ferrolho", o.ferrolho, { 0, 0.2, -0.2 }, o.corFerrolho, "Metal"),
			bloco("Empunhadura", { 0.2, 0.4, 0.22 }, { 0, -0.08, 0.02 }, o.corCabo, "Plastic", { -15, 0, 0 }),
			bloco("Guarda", { 0.1, 0.08, 0.26 }, { 0, -0.1, -0.22 }, o.corFerrolho, "Metal"),
			-- boca do cano: 0,14 de comprimento, 0,05 enterrada na frente do ferrolho
			bloco("Cano", { 0.1, 0.1, 0.14 }, { 0, 0.2, -0.2 - o.ferrolho[3] / 2 - 0.02 }, o.corCano, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
		escalaChao = 1.2,
	}
end

-- Fuzil: receptor, cano, protetor de mão, coronha, empunhadura inclinada e carregador. o.mag = { tam, rotX }.
local function fuzil(o)
	return {
		partes = {
			bloco("Receptor", { 0.16, 0.22, 0.9 }, { 0, 0.28, -0.38 }, o.metal, "Metal"),
			cil("Cano", o.cano, 0.09, { 0, 0.3, -0.83 - o.cano / 2 }, o.metal2, "Metal", "z"),
			bloco(
				"Protetor",
				{ 0.18, 0.17, o.cano * 0.6 },
				{ 0, 0.3, -0.83 - o.cano * 0.3 },
				o.madeira or o.metal,
				o.madeira and "Wood" or "Plastic"
			),
			bloco(
				"Coronha",
				{ 0.14, 0.28, o.coronha },
				{ 0, 0.22, 0.07 + o.coronha / 2 },
				o.madeira or o.metal,
				o.madeira and "Wood" or "Plastic"
			),
			bloco("Empunhadura", { 0.14, 0.38, 0.16 }, { 0, 0, 0.04 }, o.metal, "Plastic", { -15, 0, 0 }),
			bloco("Carregador", o.mag[1], { 0, -0.03, -0.5 }, o.metal2, "Metal", { o.mag[2], 0, 0 }),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
	}
end

-- Escopeta de ferrolho/bomba: receptor, cano, tubo de munição, bomba (guarda-mão deslizante), coronha, empunhadura.
local function escopeta(o)
	return {
		partes = {
			bloco("Receptor", { 0.18, 0.26, 0.8 }, { 0, 0.26, -0.35 }, o.metal, "Metal"),
			cil("Cano", o.cano, o.dCano, { 0, 0.3, -0.75 - o.cano / 2 }, o.metal2, "Metal", "z"),
			cil("Tubo", o.cano * 0.85, 0.1, { 0, 0.14, -0.75 - o.cano * 0.425 }, o.metal, "Metal", "z"),
			bloco("Bomba", { 0.2, 0.18, o.bomba }, { 0, 0.15, -0.95 - o.bomba / 2 }, o.mad, o.matMad),
			bloco("Coronha", { 0.15, 0.3, 0.65 }, { 0, 0.2, 0.38 }, o.mad, o.matMad),
			bloco("Empunhadura", { 0.14, 0.34, 0.16 }, { 0, 0, 0.04 }, o.mad, o.matMad, { -15, 0, 0 }),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
	}
end

local modelos = {
	-- Lata de conserva: corpo cinza, rótulo vermelho. De pé no chão.
	enlatado = {
		partes = {
			cil("Corpo", 0.54, 0.5, { 0, 0, 0 }, { 150, 155, 160 }, "Metal", "y"),
			cil("Rotulo", 0.4, 0.52, { 0, 0, 0 }, { 135, 45, 42 }, "SmoothPlastic", "y"),
			cil("Tampa", 0.08, 0.44, { 0, 0.31, 0 }, { 185, 188, 192 }, "Metal", "y"),
			cil("Fundo", 0.08, 0.44, { 0, -0.31, 0 }, { 120, 124, 128 }, "Metal", "y"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Barra de cereal: embalagem chata com faixa ocre e as duas pontas seladas.
	barra = {
		partes = {
			bloco("Embalagem", { 0.78, 0.15, 0.45 }, { 0, 0, 0 }, { 118, 124, 118 }, "Plastic"),
			bloco("Faixa", { 0.26, 0.17, 0.47 }, { 0, 0, 0 }, { 150, 128, 70 }, "SmoothPlastic"),
			bloco("SeloA", { 0.08, 0.1, 0.47 }, { 0.43, 0, 0 }, { 95, 100, 95 }, "Plastic"),
			bloco("SeloB", { 0.08, 0.1, 0.47 }, { -0.43, 0, 0 }, { 95, 100, 95 }, "Plastic"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
		escalaChao = 1.4,
	},

	-- Garrafa d'água: corpo de vidro azulado, gargalo e tampa azul-escura. Deitada no chão.
	agua = {
		partes = {
			cil("Corpo", 0.95, 0.45, { 0, -0.1, 0 }, { 150, 180, 200 }, "Glass", "y", 0.35),
			cil("Rotulo", 0.3, 0.46, { 0, -0.1, 0 }, { 60, 85, 120 }, "SmoothPlastic", "y"),
			cil("Gargalo", 0.25, 0.3, { 0, 0.5, 0 }, { 150, 180, 200 }, "Glass", "y", 0.35),
			cil("Tampa", 0.1, 0.28, { 0, 0.675, 0 }, { 55, 80, 125 }, "Plastic", "y"),
		},
		mao = mao(),
		chao = { rot = { 90, 0, 0 } },
	},

	-- Lata de refrigerante: corpo vermelho, faixa clara, tampas prateadas.
	refrigerante = {
		partes = {
			cil("Corpo", 0.64, 0.45, { 0, 0, 0 }, { 150, 45, 45 }, "Metal", "y"),
			cil("Faixa", 0.18, 0.46, { 0, 0.05, 0 }, { 200, 200, 195 }, "SmoothPlastic", "y"),
			cil("Topo", 0.08, 0.4, { 0, 0.36, 0 }, { 175, 180, 185 }, "Metal", "y"),
			cil("Fundo", 0.08, 0.4, { 0, -0.36, 0 }, { 130, 134, 138 }, "Metal", "y"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Rolo de bandagem: disco de pano claro com furo escuro e faixa vermelha. Disco deitado no chão (eixo vertical).
	bandagem = {
		partes = {
			cil("Rolo", 0.35, 0.5, { 0, 0, 0 }, { 190, 188, 178 }, "Fabric", "y"),
			cil("Furo", 0.37, 0.22, { 0, 0, 0 }, { 40, 40, 45 }, "SmoothPlastic", "y"),
			cil("Faixa", 0.12, 0.52, { 0, 0, 0 }, { 140, 40, 40 }, "Fabric", "y"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
		escalaChao = 1.3,
	},

	-- Kit médico: maleta cinza clara com cruz vermelha na tampa e fecho escuro na frente.
	kit = {
		partes = {
			bloco("Maleta", { 1.1, 0.4, 0.8 }, { 0, 0, 0 }, { 170, 175, 172 }, "Plastic"),
			bloco("CruzH", { 0.5, 0.08, 0.16 }, { 0, 0.2, 0 }, { 160, 30, 30 }, "SmoothPlastic"),
			bloco("CruzV", { 0.16, 0.08, 0.5 }, { 0, 0.2, 0 }, { 160, 30, 30 }, "SmoothPlastic"),
			bloco("Fecho", { 0.16, 0.16, 0.08 }, { 0, 0.05, -0.44 }, { 60, 62, 66 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Faca: cabo escuro, guarda, lâmina com ponta mais estreita. Comprimento total ≈ 1,2. Deitada de lado.
	faca = {
		partes = {
			bloco("Cabo", { 0.14, 0.16, 0.36 }, { 0, 0, 0 }, { 50, 45, 42 }, "Wood"),
			bloco("Guarda", { 0.1, 0.26, 0.08 }, { 0, 0, -0.22 }, { 95, 98, 102 }, "Metal"),
			bloco("Lamina", { 0.08, 0.2, 0.54 }, { 0, 0, -0.53 }, { 150, 155, 160 }, "Metal"),
			bloco("Ponta", { 0.08, 0.1, 0.2 }, { 0, 0, -0.9 }, { 150, 155, 160 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
	},

	-- Pé de cabra: haste de aço, fita de pegada ferrugem, gancho em J na frente e espátula atrás. ≈ 2,2.
	peDeCabra = {
		partes = {
			cil("Haste", 2, 0.14, { 0, 0, -0.15 }, { 85, 88, 92 }, "Metal", "z"),
			cil("Fita", 0.5, 0.17, { 0, 0, 0.2 }, { 110, 60, 45 }, "Fabric", "z"),
			bloco("Gancho", { 0.14, 0.32, 0.14 }, { 0, 0.1, -1.08 }, { 85, 88, 92 }, "Metal"),
			bloco("Garra", { 0.14, 0.12, 0.26 }, { 0, 0.2, -0.95 }, { 85, 88, 92 }, "Metal"),
			bloco("Espatula", { 0.2, 0.09, 0.22 }, { 0, 0, 0.9 }, { 85, 88, 92 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Machado: cabo de madeira com fita oliva, cabeça de aço e lâmina para +Y. ≈ 2,4. Deitado com a lâmina de lado.
	machado = {
		partes = {
			cil("Cabo", 2.4, 0.12, { 0, 0, -0.7 }, { 95, 70, 50 }, "Wood", "z"),
			cil("Fita", 0.5, 0.15, { 0, 0, 0.1 }, { 70, 75, 55 }, "Fabric", "z"),
			bloco("Cabeca", { 0.2, 0.22, 0.32 }, { 0, 0, -1.7 }, { 80, 84, 90 }, "Metal"),
			bloco("Lamina", { 0.08, 0.5, 0.5 }, { 0, 0.3, -1.7 }, { 140, 145, 150 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
	},

	pistola = pistola({
		ferrolho = { 0.16, 0.16, 0.8 },
		corFerrolho = { 35, 38, 42 },
		corCabo = { 50, 50, 55 },
		corCano = { 95, 98, 105 },
	}),

	-- Beretta: ferrolho prateado mais longo sobre empunhadura escura.
	beretta = pistola({
		ferrolho = { 0.18, 0.18, 0.86 },
		corFerrolho = { 120, 124, 130 },
		corCabo = { 40, 40, 44 },
		corCano = { 70, 72, 78 },
	}),

	carabinaM5 = fuzil({
		cano = 0.55,
		coronha = 0.45,
		metal = { 38, 40, 45 },
		metal2 = { 60, 63, 68 },
		mag = { { 0.1, 0.5, 0.14 }, 0 },
	}),

	ar15 = fuzil({
		cano = 0.9,
		coronha = 0.6,
		metal = { 42, 45, 50 },
		metal2 = { 60, 63, 68 },
		mag = { { 0.1, 0.4, 0.2 }, 0 },
	}),

	-- AK-74: coronha e protetor de madeira, carregador curvo (parte de baixo para a frente).
	ak74 = fuzil({
		cano = 1,
		coronha = 0.65,
		metal = { 50, 50, 55 },
		metal2 = { 70, 72, 76 },
		madeira = { 100, 68, 42 },
		mag = { { 0.1, 0.5, 0.22 }, 20 },
	}),

	-- Escopeta moderna: peças pretas de plástico.
	escopeta = escopeta({
		cano = 1.3,
		dCano = 0.14,
		bomba = 0.55,
		metal = { 45, 47, 52 },
		metal2 = { 60, 62, 68 },
		mad = { 38, 40, 44 },
		matMad = "Plastic",
	}),

	-- Escopeta Trincheira M1912: cano fino de aço e madeira marrom.
	escopetaM1912 = escopeta({
		cano = 1.4,
		dCano = 0.1,
		bomba = 0.7,
		metal = { 60, 62, 66 },
		metal2 = { 80, 82, 88 },
		mad = { 105, 75, 45 },
		matMad = "Wood",
	}),

	-- Gold Bright (2026-11-15): modelos de chão em blocos (a malha do Gold Bright só existe no viewmodel).
	tt33 = pistola({
		ferrolho = { 0.16, 0.17, 0.72 },
		corFerrolho = { 30, 32, 34 },
		corCabo = { 60, 45, 35 },
		corCano = { 80, 82, 86 },
	}),
	ots20 = pistola({
		ferrolho = { 0.2, 0.22, 0.62 },
		corFerrolho = { 45, 47, 50 },
		corCabo = { 35, 35, 38 },
		corCano = { 70, 72, 76 },
	}),
	mp5 = fuzil({
		cano = 0.35,
		coronha = 0.4,
		metal = { 30, 32, 36 },
		metal2 = { 55, 58, 62 },
		mag = { { 0.1, 0.45, 0.14 }, 15 },
	}),
	pp91 = fuzil({
		cano = 0.2,
		coronha = 0.35,
		metal = { 35, 37, 40 },
		metal2 = { 58, 60, 64 },
		mag = { { 0.1, 0.35, 0.12 }, 0 },
	}),
	sr3m = fuzil({
		cano = 0.45,
		coronha = 0.5,
		metal = { 40, 42, 46 },
		metal2 = { 30, 32, 35 },
		mag = { { 0.1, 0.4, 0.18 }, 10 },
	}),
	ots48k = fuzil({
		cano = 1.1,
		coronha = 0.6,
		metal = { 45, 48, 52 },
		metal2 = { 65, 68, 72 },
		mag = { { 0.1, 0.3, 0.16 }, 0 },
	}),
	rmb93 = escopeta({
		cano = 1.0,
		dCano = 0.13,
		bomba = 0.45,
		metal = { 38, 40, 44 },
		metal2 = { 55, 57, 62 },
		mad = { 30, 32, 35 },
		matMad = "Plastic",
	}),
	toz34 = escopeta({
		cano = 1.5,
		dCano = 0.16,
		bomba = 0.5,
		metal = { 55, 57, 60 },
		metal2 = { 75, 78, 82 },
		mad = { 110, 72, 42 },
		matMad = "Wood",
	}),
	canoChumbo = {
		partes = {
			cil("Cano", 2, 0.16, { 0, 0, -0.6 }, { 90, 92, 95 }, "Metal", "z"),
			cil("Luva", 0.18, 0.22, { 0, 0, -1.55 }, { 70, 72, 75 }, "Metal", "z"),
			cil("Fita", 0.45, 0.19, { 0, 0, 0.15 }, { 40, 40, 42 }, "Fabric", "z"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Lança-foguetes: tubo verde-oliva no ombro, bocas escuras, apoio da mão da frente e mira.
	lancaFoguetes = {
		partes = {
			cil("Tubo", 1.8, 0.3, { 0, 0.3, -0.7 }, { 62, 76, 56 }, "Metal", "z"),
			cil("Boca", 0.2, 0.36, { 0, 0.3, -1.7 }, { 40, 44, 40 }, "Metal", "z"),
			cil("Traseira", 0.2, 0.36, { 0, 0.3, 0.3 }, { 40, 44, 40 }, "Metal", "z"),
			bloco("Cabo", { 0.14, 0.34, 0.16 }, { 0, 0.05, 0.04 }, { 45, 47, 50 }, "Plastic", { -15, 0, 0 }),
			bloco("Apoio", { 0.1, 0.3, 0.1 }, { 0, 0.1, -0.9 }, { 45, 47, 50 }, "Plastic"),
			bloco("Mira", { 0.08, 0.14, 0.2 }, { 0, 0.52, -0.4 }, { 90, 94, 90 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
	},

	-- Munição de Pistola: caixinha de papelão oliva com três cartuchos de latão à mostra.
	municaoPistola = {
		partes = {
			bloco("Caixa", { 0.5, 0.2, 0.34 }, { 0, -0.1, 0 }, { 62, 72, 58 }, "Cardboard"),
			bloco("Etiqueta", { 0.3, 0.08, 0.2 }, { 0, 0.04, 0 }, { 150, 125, 60 }, "SmoothPlastic"),
			cil("CartuchoA", 0.22, 0.1, { -0.15, 0.11, 0 }, { 190, 150, 70 }, "Metal", "y"),
			cil("CartuchoB", 0.22, 0.1, { 0, 0.11, 0 }, { 190, 150, 70 }, "Metal", "y"),
			cil("CartuchoC", 0.22, 0.1, { 0.15, 0.11, 0 }, { 190, 150, 70 }, "Metal", "y"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
		escalaChao = 1.3,
	},

	-- Munição de Rifle: caixa militar de lata verde com alça, fecho e faixa amarela.
	municaoRifle = {
		partes = {
			bloco("Caixa", { 0.8, 0.4, 0.38 }, { 0, -0.2, 0 }, { 58, 68, 52 }, "Metal"),
			bloco("Tampa", { 0.84, 0.08, 0.42 }, { 0, 0.04, 0 }, { 66, 77, 58 }, "Metal"),
			bloco("Alca", { 0.34, 0.08, 0.08 }, { 0, 0.12, 0 }, { 35, 38, 36 }, "Metal"),
			bloco("Faixa", { 0.4, 0.1, 0.08 }, { 0, -0.15, -0.19 }, { 200, 170, 60 }, "SmoothPlastic"),
			bloco("Fecho", { 0.1, 0.12, 0.08 }, { 0, -0.02, -0.2 }, { 150, 155, 150 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
		escalaChao = 1.2,
	},

	-- Munição de Escopeta: três cartuchos vermelhos de base de latão, de pé.
	municaoEscopeta = {
		partes = {
			cil("CartuchoA", 0.5, 0.2, { -0.22, 0, 0 }, { 165, 40, 35 }, "SmoothPlastic", "y"),
			cil("CartuchoB", 0.5, 0.2, { 0, 0, 0 }, { 165, 40, 35 }, "SmoothPlastic", "y"),
			cil("CartuchoC", 0.5, 0.2, { 0.22, 0, 0 }, { 165, 40, 35 }, "SmoothPlastic", "y"),
			cil("BaseA", 0.12, 0.21, { -0.22, -0.31, 0 }, { 190, 150, 70 }, "Metal", "y"),
			cil("BaseB", 0.12, 0.21, { 0, -0.31, 0 }, { 190, 150, 70 }, "Metal", "y"),
			cil("BaseC", 0.12, 0.21, { 0.22, -0.31, 0 }, { 190, 150, 70 }, "Metal", "y"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 90 } },
		escalaChao = 1.2,
	},

	-- Munição de Míssil: corpo verde, ogiva clara e aletas em cruz atrás. Deitado naturalmente (eixo em Z).
	municaoMissil = {
		partes = {
			cil("Corpo", 0.8, 0.2, { 0, 0, 0 }, { 70, 80, 58 }, "Metal", "z"),
			esfera("Ogiva", 0.22, { 0, 0, -0.45 }, { 130, 125, 100 }, "Metal"),
			bloco("AletaV", { 0.08, 0.34, 0.14 }, { 0, 0, 0.36 }, { 55, 62, 48 }, "Metal"),
			bloco("AletaH", { 0.34, 0.08, 0.14 }, { 0, 0, 0.36 }, { 55, 62, 48 }, "Metal"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
		escalaChao = 1.2,
	},

	-- Lanterna: corpo escuro (mão esquerda), cabeça mais larga e lente de Neon amarelo-pálido na frente (-Z).
	lanterna = {
		partes = {
			cil("Corpo", 0.8, 0.3, { 0, 0, 0.1 }, { 45, 48, 52 }, "Plastic", "z"),
			cil("Cabeca", 0.35, 0.5, { 0, 0, -0.475 }, { 60, 63, 68 }, "Metal", "z"),
			cil("Lente", 0.08, 0.42, { 0, 0, -0.69 }, { 235, 225, 150 }, "Neon", "z"),
			bloco("Botao", { 0.1, 0.08, 0.16 }, { 0, 0.17, 0.1 }, { 150, 125, 60 }, "Plastic"),
		},
		mao = mao(),
		lado = "esquerda",
		chao = { rot = { 0, 0, 0 } },
	},

	-- Garrafa vazia (recipiente de gasolina): só vidro, gargalo e tampa escura. Deitada no chão.
	garrafaVazia = {
		partes = {
			cil("Corpo", 0.8, 0.45, { 0, -0.15, 0 }, { 210, 225, 230 }, "Glass", "y", 0.5),
			cil("Gargalo", 0.2, 0.3, { 0, 0.35, 0 }, { 210, 225, 230 }, "Glass", "y", 0.5),
			cil("Tampa", 0.1, 0.28, { 0, 0.5, 0 }, { 70, 72, 76 }, "Plastic", "y"),
		},
		mao = mao(),
		chao = { rot = { 90, 0, 0 } },
	},

	-- Garrafa de gasolina: a mesma garrafa com líquido âmbar (~70% da altura do corpo) por dentro.
	garrafaGasolina = {
		partes = {
			cil("Corpo", 0.8, 0.45, { 0, -0.15, 0 }, { 210, 225, 230 }, "Glass", "y", 0.5),
			cil("Liquido", 0.56, 0.38, { 0, -0.27, 0 }, { 210, 170, 60 }, "SmoothPlastic", "y"),
			cil("Gargalo", 0.2, 0.3, { 0, 0.35, 0 }, { 210, 225, 230 }, "Glass", "y", 0.5),
			cil("Tampa", 0.1, 0.28, { 0, 0.5, 0 }, { 70, 72, 76 }, "Plastic", "y"),
		},
		mao = mao(),
		chao = { rot = { 90, 0, 0 } },
	},

	-- Galão vazio: corpo vermelho-escuro 0,9x0,75x0,4, bocal cinza no canto, alça no topo (origem = a alça, onde a mão segura) e listra clara.
	galaoVazio = {
		partes = {
			bloco("Corpo", { 0.9, 0.75, 0.4 }, { 0, -0.375, 0 }, { 110, 30, 25 }, "SmoothPlastic"),
			bloco("Bocal", { 0.2, 0.15, 0.2 }, { 0.28, 0.075, 0 }, { 90, 90, 95 }, "SmoothPlastic"),
			bloco("Alca", { 0.35, 0.08, 0.08 }, { -0.1, 0.04, 0 }, { 60, 15, 12 }, "SmoothPlastic"),
			bloco("Listra", { 0.6, 0.1, 0.08 }, { 0, -0.4, -0.2 }, { 225, 215, 200 }, "SmoothPlastic"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},

	-- Galão de gasolina (5 L): corpo vermelho, bocal amarelo.
	galaoGasolina = {
		partes = {
			bloco("Corpo", { 0.9, 0.75, 0.4 }, { 0, -0.375, 0 }, { 150, 25, 20 }, "SmoothPlastic"),
			bloco("Bocal", { 0.2, 0.15, 0.2 }, { 0.28, 0.075, 0 }, { 220, 190, 50 }, "SmoothPlastic"),
			bloco("Alca", { 0.35, 0.08, 0.08 }, { -0.1, 0.04, 0 }, { 60, 15, 12 }, "SmoothPlastic"),
			bloco("Listra", { 0.6, 0.1, 0.08 }, { 0, -0.4, -0.2 }, { 225, 215, 200 }, "SmoothPlastic"),
		},
		mao = mao(),
		chao = { rot = { 0, 0, 0 } },
	},
}

return { modelos = modelos }
