-- Movimento do personagem. O checker do mapa (mapa-roblox) lê estes números. PROVISÓRIO.

return {
	velocidade = 16, -- andar
	velocidadeAgachado = 8,
	velocidadeDeitado = 3, -- rastejando
	velocidadeCorrida = 24,
	alturaPulo = 6,
	gravidade = 196.2,
	-- Pose de agachar (R15, feita nos Motor6D pelo servidor): coxa para a frente, joelho para trás, pé plano.
	-- O quadril desce `alturaQuadril` studs (HipHeight), o que também encolhe a hitbox.
	agachado = { anguloCoxa = 55, alturaQuadril = 1.0, inclinacaoTronco = 10, duracao = 0.2 },
	-- Deitado (segurar a tecla de agachar `segurarDeitar` s): o corpo gira `angulo` graus para a frente no Root e desce `descer`
	-- studs; o quadril (HipHeight) vai a `alturaQuadril`. Conta como agachado para ruído/mira (o servidor liga os dois atributos).
	deitado = { angulo = 90, descer = 0.1, alturaQuadril = 0.25, anguloCoxa = 8, duracao = 0.35 },
	segurarDeitar = 0.5,
	-- Derrubado (docs/monstros/logica.md §2.2): `Movimento.derrubar` deita o jogador por N s; ao acabar ele volta agachado.
	derrubado = { maxSegundos = 6, maxImpulso = 120 },

	teclas = {
		agachar = { "C", "LeftControl" },
		correr = { "LeftShift" },
		terceiraPessoa = { "V", "T" }, -- T é reserva, caso o V esteja em conflito
		configuracoes = { "P" },
		inventario = { "Tab", "I" }, -- I é reserva, caso o Tab esteja em conflito
		interagir = { "E" },
		recarregar = { "R" },
		-- Armas (docs/armas.md §13): engatilhar/destravar na mão (bomba precisa a cada tiro) e checar a munição (frase no HUD).
		engatilhar = { "Q" },
		checarMunicao = { "Z" },
		-- segurar: minigame de prender a respiração (docs/som.md §13). Espaço (decisão do usuário 2026-11-14; o F é a lanterna):
		-- durante o minigame a ação engole a tecla (Sink) e o personagem não pula; fora dele o Espaço volta a ser o pulo.
		prenderRespiracao = { "Space" },
	},
}
