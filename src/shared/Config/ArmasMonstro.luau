-- Armas contra monstros e flores (docs/monstros/logica.md §6.5 e §7.2). PROVISÓRIO.

return {
	-- MonstroPS1 aparar: as lâminas bloqueiam pistola vinda da frente enquanto ele caça.
	aparar = {
		especie = "MonstroPS1",
		estados = { "Caca", "Ataque" }, -- atributo Estado do modelo ("Ataque" é Caça com golpe em curso)
		classesBloqueadas = { "pistola" }, -- rifle, escopeta e foguete: dano cheio
		cone = 60, -- graus (total) à frente do monstro
		multiplicador = 0.5,
		som = "LaminaAparar",
		-- tronco = qualquer parte que não case com estes trechos (minúsculas)
		naoTronco = {
			"head",
			"cabeca",
			"arm",
			"braco",
			"leg",
			"perna",
			"hand",
			"mao",
			"foot",
			"blade",
			"lamina",
			"faca",
		},
		-- golpe corpo a corpo de jogador no monstro: barulho de metal contra metal
		ruido = { db = 80, tipo = "aparar" },
	},
	-- Flores da Florescida: tipo repassado a Flores.atingir
	flor = {
		tipoTiro = "tiro",
		tipoFaca = "faca", -- classes de arma que contam como faca
		classesFaca = { "faca" },
		tipoCorpo = "corpo",
	},
}
