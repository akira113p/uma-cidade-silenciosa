-- Dano por partes do corpo (docs/calculos.md §3). Regra: src/shared/Regras/Corpo.luau. PROVISÓRIO.

return {
	partes = {
		Cabeca = { vida = 30, fatal = true },
		Torso = { vida = 60, fatal = true },
		BracoE = { vida = 35, fatal = false },
		BracoD = { vida = 35, fatal = false },
		PernaE = { vida = 40, fatal = false },
		PernaD = { vida = 40, fatal = false },
	},
	ordem = { "Cabeca", "Torso", "BracoE", "BracoD", "PernaE", "PernaD" },

	transbordoParaTorso = 0.5, -- fração do dano que sobra de uma parte zerada e vai para o torso
	multPernaZerada = 0.6, -- velocidade × isto por perna zerada
	multMiraBracoZerado = 2, -- espalhamento da mira × isto com um braço zerado
	multCabecaArma = 2, -- dano de arma na cabeça × isto

	queda = {
		alturaSegura = 12, -- studs
		danoPorStud = 3, -- dividido entre as duas pernas
	},

	-- Partes do R15 → parte do jogo (para o raycast das armas)
	r15 = {
		Head = "Cabeca",
		UpperTorso = "Torso",
		LowerTorso = "Torso",
		HumanoidRootPart = "Torso",
		LeftUpperArm = "BracoE",
		LeftLowerArm = "BracoE",
		LeftHand = "BracoE",
		RightUpperArm = "BracoD",
		RightLowerArm = "BracoD",
		RightHand = "BracoD",
		LeftUpperLeg = "PernaE",
		LeftLowerLeg = "PernaE",
		LeftFoot = "PernaE",
		RightUpperLeg = "PernaD",
		RightLowerLeg = "PernaD",
		RightFoot = "PernaD",
	},
}
