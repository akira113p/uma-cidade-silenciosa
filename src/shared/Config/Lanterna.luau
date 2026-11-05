-- Lanterna de mão (S7). Tudo PROVISÓRIO: afinar por captura de tela no Studio. Regras: src/shared/Regras/Lanterna.luau.
-- Cores em {r, g, b} 0..255 (sem Color3, para a Config carregar no Lune).
-- Luz do próprio jogador: client/Lanterna.luau (presa à câmera). Dos outros: SpotLight na cabeça. Liga/desliga: servidor.
return {
	-- Bateria: não existe nesta versão. Quando existir, será a duração (s) com a lanterna acesa; nil = infinita.
	bateria = nil,

	teclas = { "F" }, -- nomes de Enum.KeyCode que ligam/apagam (via client/Teclas)
	ligarAoEquipar = true, -- equipar pela barra já acende; F alterna depois
	intervaloPedido = 0.15, -- s: teto de pedidos/s por jogador no servidor (evento Lanterna)

	-- SpotLight principal (cone largo que desenha o círculo de luz no chão e na parede)
	cor = { 255, 226, 170 }, -- quente
	principal = {
		angulo = 48, -- graus (Angle do SpotLight)
		alcance = 60, -- studs. O Roblox limita Range de luz a 60; valores maiores são cortados em client/Lanterna
		brilho = 34, -- 2026-11-03: era 6 e depois 14, a poça mal aparecia (asfalto escuro reflete pouco); 40 estoura a borda
	},
	-- SpotLight do núcleo (estreito e forte; cortado em qualidade baixa)
	nucleo = { angulo = 18, alcance = 60, brilho = 20 },
	-- PointLight de preenchimento ao redor da mão (cortado em qualidade baixa)
	preenchimento = { alcance = 10, brilho = 0.6 },

	-- Onde a lanterna fica em relação à câmera (espaço da câmera: +X direita, +Y cima, -Z frente)
	-- 2026-11-03: a poça caía no canto inferior direito; mão mais perto do centro e convergência curta
	deslocamento = { x = 0.5, y = -0.5, z = -0.6 }, -- studs
	convergencia = 16, -- studs: o facho mira o ponto da câmera a essa distância (a mão fica abaixo/à direita do olhar)
	meiaVidaDirecao = 0.09, -- s: o facho persegue a direção da câmera (atraso suave de lanterna na mão)
	fadeLigar = 0.12, -- s para a luz subir/descer ao ligar/apagar
	fatorDia = 0.12, -- 0..1: fração do brilho ao meio-dia (1 = igual à noite). Dentro de casa ainda ajuda um pouco.

	-- Balanço ao andar (Regras/Lanterna.balanco). Amplitudes em studs na posição da lanterna.
	balanco = {
		amplitudeY = 0.07, -- vertical, studs
		amplitudeX = 0.05, -- lateral, studs
		frequencia = 1.8, -- Hz do passo (vertical; o lateral é a metade)
		velocidadeRef = 16, -- studs/s em que a amplitude vale 100% (andar)
		fatorMaximo = 1.6, -- teto do multiplicador (correr = 24 / 16 = 1.5)
		suavizacaoVelocidade = 0.15, -- s: meia-vida do filtro da velocidade (evita salto ao parar/arrancar)
	},

	-- Cintilação (Regras/Lanterna.cintilacao): queda curta de brilho, NUNCA pisca forte (dor de cabeça)
	cintilacao = {
		intervalo = 8, -- s: largura da janela; o intervalo entre quedas fica entre 4 e 12 s
		janela = 4, -- s: dentro de cada janela a queda cai num instante sorteado (intervalo - janela = mínimo entre quedas)
		duracao = 0.3, -- s: duração de uma queda
		profundidadeMin = 0.05, -- fração do brilho perdida no mínimo
		profundidadeMax = 0.15, -- e no máximo (nunca abaixo de 0.85)
		fracaoDescida = 0.15, -- 0..1: parte da duração gasta caindo (rápida); o resto é a volta
	},

	-- Feixe volumétrico (Beam com Texturas.coneLuz: poeira/névoa iluminada). Id vazio = sem beam, a luz continua.
	cone = {
		-- 2026-11-03: DESLIGADO na primeira pessoa. O feixe nasce colado na câmera e aponta para onde ela olha, então é
		-- visto de frente e vira uma estrela de riscos no meio da tela. A referência (foto noturna) mostra só o círculo
		-- de luz no chão. O cone fica para a lanterna vista de fora (terceira pessoa / outros jogadores) numa versão futura.
		ligado = false,
		alcance = 32, -- studs à frente
		largura0 = 0.4, -- studs, na lanterna
		largura1 = 26, -- studs, na ponta (~ 2 * alcance * tan(angulo / 2))
		transparencia = 0.8, -- 0..1 com brilho cheio de noite (1 = invisível)
		fatorDia = 0.35, -- 0..1: visibilidade do cone ao meio-dia em relação à noite (mais escuro = mais visível)
	},

	-- Luz dos outros jogadores (SpotLight simples na cabeça, sem beam)
	outros = {
		angulo = 48,
		alcance = 60,
		brilho = 4,
		deslocamento = { x = 0.5, y = -0.5, z = -0.6 }, -- studs no espaço da cabeça
		intervaloVarredura = 0.25, -- s: com que frequência o cliente confere quem está com a lanterna acesa
	},
}
