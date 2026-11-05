-- Primeira pessoa das armas (docs/armas.md §10.2): onde a arma fica na tela, de onde saem os braços e as poses de
-- sacar, recarregar, bombear e golpear, tudo como DADO por classe de animação (as 7 do §9). TUDO PROVISÓRIO: os números
-- de pose nunca foram vistos no jogo (escritos sem Studio); afinar no playtest com a arma na mão.
--
-- Convenções
--   * Espaço da câmera: +x direita, +y cima, +z para TRÁS (a frente é -z). Medidas em studs, ângulos em graus.
--   * `base` = onde o Cabo (a empunhadura) fica em relação à câmera, parado.
--   * Um passo de pose = { t = 0..1 (fração da duração), pos = deslocamento somado à base, rot = ângulos (x tom, y guinada,
--     z rolagem) somados à base, esq = mão esquerda }. Entre passos a interpolação usa suavização (smoothstep).
--   * `esq.pos` está no espaço da ARMA (origem = Cabo, cano para -z). `esq.peso` 0 = a mão fica no ApoioEsquerdo da arma
--     (ou escondida, em arma de uma mão); 1 = a mão vai para `esq.pos`. `esq.delta` soma um deslocamento ao ponto final
--     (bombear). Passo sem `esq` = peso 0.
--   * Duração de `recarga`/golpe NÃO é daqui: a recarga vem de Config/Armas (sinal `recarregou`) e o golpe é calculado para
--     o impacto cair em `atrasoImpacto` (`impactoT` = fração do golpe em que a lâmina acerta). `sacarDuracao` vem do §9.

local function v(x: number, y: number, z: number)
	return { x = x, y = y, z = z }
end

local ZERO = v(0, 0, 0)

return {
	-- Braços: de onde saem (espaço da câmera, atrás e abaixo do olho, fora do quadro) e para onde o cotovelo aponta.
	ombro = { D = v(0.95, -0.95, 0.5), E = v(-0.95, -0.95, 0.5) },
	polo = { D = v(0.8, -1, 0.35), E = v(-0.8, -1, 0.35) }, -- direção (espaço da câmera) do lado do cotovelo
	-- Medidas de reserva se o personagem ainda não tiver as peças R15 (largura, altura/comprimento, profundidade).
	bracoReserva = { superior = v(0.7, 1.25, 0.8), inferior = v(0.65, 1.1, 0.75), mao = v(0.65, 0.4, 0.7) },
	escalaBraco = 0.9, -- os braços do viewmodel são um pouco mais finos que os do corpo (fica menos "tapado")

	-- Molas (Regras/Mola). rigidez, amortecimento. Amortecimento abaixo de 2*sqrt(rigidez) = vai e volta (coice).
	molaPos = { rigidez = 150, amortecimento = 15 },
	molaRot = { rigidez = 110, amortecimento = 12 },

	-- Coice visual da arma por tiro: cada grau de Config/Armas.coice.vertical vira isto.
	coice = {
		recuoPorGrau = 0.085, -- studs para trás
		subidaPorGrau = 0.012, -- studs para cima
		pitchPorGrau = 1.5, -- graus de inclinação da arma
		guinadaPorGrau = 1.2, -- graus por grau horizontal
		minimo = 0.35, -- fração mantida mesmo com Pref_Tremor desligado (é animação da arma, não tremor)
	},

	-- Balanço da arma ao andar (somado ao alvo das molas). x/y em studs, rolagem em graus.
	balanco = {
		andar = { x = 0.035, y = 0.03, roll = 0.8 },
		correr = { x = 0.07, y = 0.06, roll = 1.6 },
		agachado = { x = 0.02, y = 0.015, roll = 0.4 },
	},
	respiracao = { amplitude = 0.006, hz = 0.35 }, -- sobe/desce parado
	sway = { ganho = 0.45, maximo = 7 }, -- a arma atrasa em relação ao giro da câmera: fração do giro (por quadro), graus máx.
	suavizarCorrida = 8, -- 1/s: rapidez de entrar/sair da pose de corrida
	suavizarSaida = 0.15, -- s: recolhe a pose quando um clipe é cancelado

	-- Parede perto: raio curto para frente; se bate, a arma recua e sobe (nunca atravessa).
	parede = { distancia = 3.2, recuo = 1.0, subida = 30, suavizar = 12 },

	clarao = { tamanho = 0.4, duracao = 0.05, cor = { 255, 214, 120 }, luz = { alcance = 12, brilho = 2 } },
	rastro = { duracao = 0.06, espessura = 0.07, cor = { 255, 232, 160 }, maximoEscopeta = 3 },
	cartucha = { tamanho = v(0.07, 0.07, 0.2), cor = { 200, 160, 70 }, vida = 2, maximo = 12, velocidade = 9 },
	explosao = {
		tremorMaximo = 1, -- studs (Camera.tremer corta em 1 e aplica as preferências)
		distanciaRef = 40, -- studs: a esta distância o tremor cai pela metade
		distanciaMax = 320,
		duracaoTremor = 0.9,
		duracaoBola = 0.45,
		cor = { 255, 150, 50 },
		corFumaca = { 70, 66, 62 },
	},

	-- Mira central: ticks que abrem com o espalhamento (só estético; o servidor decide o espalhamento real).
	mira = { tick = 7, espessura = 2, folgaMinima = 3, suavizar = 14 },

	-- Detalhes por classe de animação (docs/armas.md §9).
	classes = {
		----------------------------------------------------------------------------------------------- faca
		faca = {
			duasMaos = false,
			base = { pos = v(0.5, -0.62, -1.2), rot = v(58, 8, 0) },
			maoD = ZERO,
			correr = { pos = v(-0.05, -0.2, 0.1), rot = v(-15, 10, 0) },
			sacarDuracao = 0.35,
			sacar = {
				{ t = 0, pos = v(0.2, -1.0, 0.3), rot = v(-60, 15, 20) },
				{ t = 0.65, pos = v(0, 0.06, -0.04), rot = v(6, -2, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			impactoT = 0.5,
			golpes = {
				{ -- 1: estocada
					{ t = 0, pos = ZERO, rot = ZERO },
					{ t = 0.3, pos = v(0.05, -0.05, 0.25), rot = v(-8, 0, 0) },
					{ t = 0.5, pos = v(-0.05, 0.12, -0.85), rot = v(12, -4, 0) },
					{ t = 0.75, pos = v(-0.02, 0.05, -0.4), rot = v(4, 0, 0) },
					{ t = 1, pos = ZERO, rot = ZERO },
				},
				{ -- 2: corte lateral
					{ t = 0, pos = ZERO, rot = ZERO },
					{ t = 0.3, pos = v(0.35, 0.15, 0.1), rot = v(-8, -30, 25) },
					{ t = 0.5, pos = v(-0.55, -0.1, -0.55), rot = v(8, 50, -35) },
					{ t = 0.8, pos = v(-0.25, -0.05, -0.2), rot = v(3, 20, -12) },
					{ t = 1, pos = ZERO, rot = ZERO },
				},
			},
		},

		----------------------------------------------------------------------------------------------- contundente
		contundente = {
			duasMaos = false,
			base = { pos = v(0.55, -0.65, -1.3), rot = v(42, 10, 0) },
			maoD = ZERO,
			correr = { pos = v(-0.05, -0.2, 0.1), rot = v(-12, 12, 0) },
			sacarDuracao = 0.4,
			sacar = {
				{ t = 0, pos = v(0.2, -1.1, 0.3), rot = v(-60, 15, 20) },
				{ t = 0.65, pos = v(0, 0.07, -0.05), rot = v(7, -2, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			impactoT = 0.5,
			golpes = {
				{
					{ t = 0, pos = ZERO, rot = ZERO },
					{ t = 0.35, pos = v(0.45, 0.35, 0.2), rot = v(-25, -20, 35) },
					{ t = 0.5, pos = v(-0.5, -0.2, -0.6), rot = v(20, 40, -30) },
					{ t = 0.8, pos = v(-0.2, -0.1, -0.25), rot = v(8, 16, -12) },
					{ t = 1, pos = ZERO, rot = ZERO },
				},
			},
		},

		----------------------------------------------------------------------------------------------- machado
		machado = {
			duasMaos = true,
			base = { pos = v(0.45, -0.7, -1.4), rot = v(35, 5, 0) },
			maoD = ZERO,
			apoioPadrao = v(0, -0.2, 0.7), -- onde a mão esquerda segura o cabo se o modelo não tiver ApoioEsquerdo
			correr = { pos = v(-0.1, -0.25, 0.15), rot = v(-10, 14, 0) },
			sacarDuracao = 0.5,
			sacar = {
				{ t = 0, pos = v(0.2, -1.1, 0.4), rot = v(-60, 15, 20) },
				{ t = 0.65, pos = v(0, 0.07, -0.05), rot = v(7, -2, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			impactoT = 0.5, -- o ímpeto vem da subida até 0,5 e da descida; o servidor acerta em atrasoImpacto
			golpes = {
				{
					{ t = 0, pos = ZERO, rot = ZERO },
					{ t = 0.28, pos = v(0.05, 0.6, 0.35), rot = v(55, 0, 0) },
					{ t = 0.5, pos = v(0, -0.45, -0.7), rot = v(-45, 0, 0) },
					{ t = 0.75, pos = v(0, -0.3, -0.4), rot = v(-25, 0, 0) },
					{ t = 1, pos = ZERO, rot = ZERO },
				},
			},
		},

		----------------------------------------------------------------------------------------------- pistola
		pistola = {
			duasMaos = false,
			base = { pos = v(0.55, -0.55, -1.8), rot = v(0, 2, 0) },
			maoD = ZERO,
			correr = { pos = v(-0.1, -0.3, 0.2), rot = v(-22, 25, -8) },
			cartucha = true,
			sacarDuracao = 0.35,
			sacar = {
				{ t = 0, pos = v(0.15, -0.9, 0.3), rot = v(-55, 10, 15) },
				{ t = 0.6, pos = v(0, 0.05, -0.05), rot = v(5, 0, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			recarga = {
				{ t = 0, pos = ZERO, rot = ZERO, esq = { pos = v(-0.6, -1.8, 0.4), peso = 0 } },
				{ t = 0.1, pos = v(-0.05, 0, 0.1), rot = v(12, 0, -18), esq = { pos = v(-0.4, -1.1, 0.2), peso = 1 } },
				{ t = 0.18, pos = v(-0.05, 0, 0.1), rot = v(12, 0, -18), esq = { pos = v(-0.1, -0.45, 0), peso = 1 } },
				{
					t = 0.35,
					pos = v(-0.05, 0, 0.1),
					rot = v(12, 0, -18),
					esq = { pos = v(-0.3, -1.4, 0.35), peso = 1 },
				},
				{ t = 0.5, pos = v(-0.05, 0, 0.1), rot = v(12, 0, -18), esq = { pos = v(-0.4, -1.7, 0.4), peso = 1 } },
				{ t = 0.63, pos = v(-0.05, 0, 0.1), rot = v(12, 0, -18), esq = { pos = v(-0.1, -0.5, 0), peso = 1 } },
				{
					t = 0.68,
					pos = v(-0.03, 0.03, 0.18),
					rot = v(14, 0, -14),
					esq = { pos = v(-0.1, -0.45, 0), peso = 1 },
				},
				{ t = 0.82, pos = v(0, 0, 0.04), rot = v(4, 0, -6), esq = { pos = v(-0.25, -0.9, 0.1), peso = 0.6 } },
				{ t = 1, pos = ZERO, rot = ZERO, esq = { pos = v(-0.6, -1.8, 0.4), peso = 0 } },
			},
		},

		----------------------------------------------------------------------------------------------- fuzil
		fuzil = {
			duasMaos = true,
			base = { pos = v(0.5, -0.72, -1.55), rot = v(0, 2.5, 0) },
			maoD = ZERO,
			apoioPadrao = v(0, -0.18, -1.15),
			correr = { pos = v(-0.2, -0.28, 0.18), rot = v(-18, 28, -6) },
			cartucha = true,
			sacarDuracao = 0.5,
			sacar = {
				{ t = 0, pos = v(0.2, -1.0, 0.35), rot = v(-55, 12, 18) },
				{ t = 0.6, pos = v(0, 0.06, -0.06), rot = v(5, 0, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			recarga = {
				{ t = 0, pos = ZERO, rot = ZERO },
				{ t = 0.1, pos = v(0, 0, 0.05), rot = v(6, 0, -14), esq = { pos = v(-0.1, -0.5, -0.55), peso = 1 } },
				{ t = 0.22, pos = v(0, 0, 0.05), rot = v(6, 0, -14), esq = { pos = v(-0.15, -1.2, -0.5), peso = 1 } },
				{ t = 0.38, pos = v(0, 0, 0.05), rot = v(6, 0, -14), esq = { pos = v(-0.5, -1.6, 0.1), peso = 1 } },
				{ t = 0.5, pos = v(0, 0, 0.05), rot = v(6, 0, -14), esq = { pos = v(-0.2, -1.15, -0.5), peso = 1 } },
				{
					t = 0.58,
					pos = v(0, 0.03, 0.12),
					rot = v(8, 0, -12),
					esq = { pos = v(-0.1, -0.55, -0.55), peso = 1 },
				},
				{ t = 0.72, pos = v(0, 0, 0.04), rot = v(-3, 0, -4), esq = { pos = v(-0.05, 0.25, 0.1), peso = 1 } },
				{ t = 0.85, pos = v(0, 0, 0.1), rot = v(-3, 0, -4), esq = { pos = v(-0.05, 0.25, 0.45), peso = 1 } },
				{ t = 0.93, pos = v(0, 0, 0.02), rot = v(-1, 0, -2), esq = { pos = v(-0.05, 0.25, 0.15), peso = 0.6 } },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
		},

		----------------------------------------------------------------------------------------------- escopeta
		escopeta = {
			duasMaos = true,
			base = { pos = v(0.5, -0.74, -1.55), rot = v(0, 2.5, 0) },
			maoD = ZERO,
			apoioPadrao = v(0, -0.2, -1.2),
			correr = { pos = v(-0.2, -0.28, 0.18), rot = v(-18, 28, -6) },
			sacarDuracao = 0.5,
			sacar = {
				{ t = 0, pos = v(0.2, -1.0, 0.35), rot = v(-55, 12, 18) },
				{ t = 0.6, pos = v(0, 0.06, -0.06), rot = v(5, 0, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			-- Bombear depois do tiro (a escopeta é pump): a mão esquerda corre para trás e volta pelo `delta`.
			bombear = {
				atraso = 0.2, -- s depois do tiro
				duracao = 0.5,
				passos = {
					{ t = 0, pos = ZERO, rot = ZERO },
					{
						t = 0.4,
						pos = v(0, 0.01, 0.05),
						rot = v(-1, 0, 0),
						esq = { pos = ZERO, peso = 0, delta = v(0, 0, 0.5) },
					},
					{ t = 0.55, pos = v(0, 0, 0.03), rot = ZERO, esq = { pos = ZERO, peso = 0, delta = v(0, 0, 0.5) } },
					{ t = 1, pos = ZERO, rot = ZERO, esq = { pos = ZERO, peso = 0, delta = ZERO } },
				},
			},
			-- Recarga por cartucho: início (inclina e leva a mão à janela), cartucho (repete) e fim (bombeia).
			recargaTubo = {
				inicio = {
					{ t = 0, pos = ZERO, rot = ZERO },
					{
						t = 0.6,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.05, -0.45, -0.4), peso = 1 },
					},
					{
						t = 1,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.05, -0.45, -0.4), peso = 1 },
					},
				},
				cartucho = {
					{
						t = 0,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.05, -0.45, -0.4), peso = 1 },
					},
					{
						t = 0.4,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.5, -1.4, 0.2), peso = 1 },
					},
					{
						t = 0.75,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.25, -0.8, -0.2), peso = 1 },
					},
					{
						t = 1,
						pos = v(0, 0.1, 0.14),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.05, -0.45, -0.4), peso = 1 },
					},
				},
				fim = {
					{
						t = 0,
						pos = v(0, 0.08, 0.12),
						rot = v(8, 0, -24),
						esq = { pos = v(-0.05, -0.45, -0.4), peso = 1 },
					},
					{ t = 0.4, pos = ZERO, rot = ZERO, esq = { pos = v(-0.05, -0.45, -0.4), peso = 0 } },
					{
						t = 0.65,
						pos = v(0, 0.01, 0.05),
						rot = v(-1, 0, 0),
						esq = { pos = ZERO, peso = 0, delta = v(0, 0, 0.5) },
					},
					{ t = 1, pos = ZERO, rot = ZERO, esq = { pos = ZERO, peso = 0, delta = ZERO } },
				},
			},
		},

		----------------------------------------------------------------------------------------------- lançador
		lancador = {
			duasMaos = true,
			base = { pos = v(0.55, -0.5, -1.1), rot = v(0, 3, 0) },
			maoD = ZERO,
			apoioPadrao = v(0, -0.2, -0.9),
			correr = { pos = v(-0.15, -0.3, 0.2), rot = v(-15, 20, -6) },
			sacarDuracao = 0.6,
			sacar = {
				{ t = 0, pos = v(0.2, -1.1, 0.4), rot = v(-60, 12, 18) },
				{ t = 0.6, pos = v(0, 0.06, -0.06), rot = v(5, 0, 0) },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
			recarga = {
				{ t = 0, pos = ZERO, rot = ZERO },
				{ t = 0.12, pos = v(0, -0.32, 0.15), rot = v(-24, 0, 10), esq = { pos = v(0, -0.1, -0.5), peso = 1 } },
				{ t = 0.28, pos = v(0, -0.32, 0.15), rot = v(-24, 0, 10), esq = { pos = v(0, 0.05, 0.85), peso = 1 } },
				{
					t = 0.45,
					pos = v(0, -0.32, 0.15),
					rot = v(-24, 0, 10),
					esq = { pos = v(-0.4, -1.2, 0.9), peso = 1 },
				},
				{ t = 0.65, pos = v(0, -0.32, 0.15), rot = v(-24, 0, 10), esq = { pos = v(0, 0.05, 0.85), peso = 1 } },
				{ t = 0.72, pos = v(0, -0.3, 0.22), rot = v(-22, 0, 8), esq = { pos = v(0, 0.05, 0.85), peso = 1 } },
				{ t = 0.88, pos = v(0, 0, 0.05), rot = v(-4, 0, 2), esq = { pos = v(0, -0.1, -0.5), peso = 0.5 } },
				{ t = 1, pos = ZERO, rot = ZERO },
			},
		},
	},
}
