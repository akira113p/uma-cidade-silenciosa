-- Movimento do personagem. O checker do mapa (mapa-roblox) lê estes números. PROVISÓRIO.

return {
	velocidade = 16, -- andar
	velocidadeAgachado = 8,
	velocidadeCorrida = 24,
	alturaPulo = 6,
	gravidade = 196.2,
	-- Pose de agachar (R15, feita nos Motor6D pelo servidor): coxa para a frente, joelho para trás, pé plano.
	-- O quadril desce `alturaQuadril` studs (HipHeight), o que também encolhe a hitbox.
	agachado = { anguloCoxa = 55, alturaQuadril = 1.0, inclinacaoTronco = 10, duracao = 0.2 },

	teclas = {
		agachar = { "C", "LeftControl" },
		correr = { "LeftShift" },
		terceiraPessoa = { "V", "T" }, -- T é reserva, caso o V esteja em conflito
		configuracoes = { "P" },
		inventario = { "Tab", "I" }, -- I é reserva, caso o Tab esteja em conflito
		interagir = { "E" },
		recarregar = { "R" },
	},
}
