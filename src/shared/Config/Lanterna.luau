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

	-- 2026-11-16 (pedido do usuário): lanterna de PEITO (modelo do pacote PsxFlashLights, Config/LanternaMalha) e luz no estilo
	-- do Gold Bright (pesquisa/gold-bright.md §8): facho branco de 55° com miolo de 40° (círculo nítido), sombra, sobe linear ao
	-- ligar (~0,8 s), luz curta só para as mãos/arma. 1ª pessoa: a luz sai da cabeça (como no Gold Bright, círculo no centro).
	-- 3ª pessoa e outros jogadores: a luz sai da LENTE do modelo no peito. Equipar pela barra = vestir no peito (mãos livres).
	peito = {
		-- onde a origem do modelo (meio da face de trás) fica no UpperTorso: +X direita do personagem, +Y cima, -Z frente.
		-- z é somado à frente do UpperTorso (-Size.Z/2): folga até a roupa.
		pos = { x = -0.42, y = 0.32, z = -0.06 },
		rot = { x = 0, y = 0, z = 0 }, -- graus
		escala = 1, -- multiplica o tamanho do modelo
		-- chave deslizante (Motor6D Corpo->Botao, animada em cada cliente): eixo no espaço do Corpo, curso em studs (ligado = +)
		botao = { eixo = { x = 0, y = 1, z = 0 }, curso = 0.035, tempo = 0.12 },
		-- lente: cor apagada (vidro) e acesa (Neon), mesmo ritmo da luz
		lente = { corApagada = { 150, 150, 140 }, corAcesa = { 255, 252, 240 } },
		-- indicador vermelho (se o modelo tiver a peça): acende junto
		indicador = { corApagada = { 90, 20, 20 }, corAcesa = { 255, 40, 30 } },
	},
	-- Port do Gold Bright: ligar sobe a luz LINEAR (facho +30/s até 25 = 0,83 s); apagar corta na hora.
	subida = 0.83, -- s até o brilho cheio
	primeira = {
		cor = { 255, 250, 238 }, -- branca, só um fio mais quente (vidro velho)
		-- 2026-11-17: reduzidas (era 9 / 22 / 1.4): em Realistic o miolo queimava o branco. 6,5 já era fraco demais; 8 / 3,2 medido no Studio.
		-- 2026-11-17 (2ª): a BOLA BRANCA do print do usuário vinha dos 4 cones de `suja` (sem sombra) somando no centro, enquanto o miolo
		-- (luz "gasta", ver client/Lanterna) não iluminava de perto. Sem os cones e com luz nova a cada acender: 14/3 deu círculo quente com
		-- os tijolos visíveis a 18-24 studs e parede laranja (não branca) a 8 studs. 12/2,5 = um pouco abaixo disso.
		externo = { angulo = 55, alcance = 60, brilho = 1.4 }, -- borda do círculo (brilho a distRef; ver compensacao)
		interno = { angulo = 40, alcance = 60, brilho = 6 }, -- miolo (a 22 studs: 4,5 fraco, 8 já estoura o centro)
		-- sombra no miolo: precisa de Lighting.LightingStyle = Realistic (o antigo Future; a propriedade Technology foi substituída pelo
		-- Unified Lighting). Em Soft+Voxel a sombra é por bloco de 4 studs e o próprio corpo apagava o facho (medido 2026-11-17).
		sombra = true,
		maos = { alcance = 4, brilho = 0.6 }, -- PointLight curta na frente da câmera: ilumina braços e arma
		-- brilho × (distância da superfície no centro do facho / distRef) ^ expoente (Regras/Lanterna.fatorDistancia). Medido
		-- 2026-11-17 com luzes novas: 5/1,2 bom a ~23 studs (14 estourava), ~3 bom a ~9 studs (12 virava a bola branca).
		compensacao = { distRef = 22, expoente = 0.5, minimo = 0.3, meiaVida = 0.08 },
		-- studs no espaço da câmera: um pouco à FRENTE do rosto, senão o próprio corpo (escondido só para o dono) faz sombra no facho
		deslocamento = { x = 0.08, y = -0.12, z = -1.1 },
	},
	terceira = { -- da lente do peito (3ª pessoa do próprio jogador e todos os outros)
		externo = { angulo = 55, alcance = 60, brilho = 1 },
		interno = { angulo = 40, alcance = 60, brilho = 4 },
		sombra = false,
	},

	-- COOKIE (textura de sujeira do facho, 2026-11-17): o Roblox não aceita textura em luz, então a máscara é uma ImageLabel PRETA com
	-- alfa (manchas, digitais, poeira e borda irregular; centro limpo) desenhada por cima do mundo e centrada no ponto da tela para onde
	-- o facho aponta. Visto do vértice do SpotLight, o cone é um círculo na tela em qualquer geometria, então a máscara casa com o mundo.
	-- Só 1ª pessoa do dono (nível de qualidade >= `minNivel`). Fonte: assets/lanterna/bruto/lanterna_facho.png (ChatGPT) ->
	-- ferramentas/lanterna/processar_facho.py -> enviar_cookie.py.
	cookie = {
		-- v1 (111900406477515) reprovada: tinha borda preta que virava um ANEL escuro na tela. v2: só sujeira de dentro do disco
		-- (alfa 0 a partir de r = 0,42 da imagem), nada escurece fora da luz. Vazio = a máscara não é criada.
		imagem = "rbxassetid://88627567096322", -- assets/lanterna/final/lanterna_cookie.png v3 (manchas mais fortes; v2 93721452655056)
		raioImagem = 0.46, -- fração da largura da imagem em que a borda do disco some (RAIO_DISCO do processar_facho.py)
		anguloTela = 40, -- graus: o círculo que se VÊ é o do miolo (primeira.interno.angulo), não o do facho de 55°
		forca = 0.9, -- 0..1: opacidade máxima da máscara com a luz cheia (a de dia some junto com o fator da luz)
		minNivel = 2,
	},

	-- LENTE SUJA: o Roblox não tem textura de luz (o `cookie` do Gold Bright, light_03, é um disco irregular com anel e mancha).
	-- Imitação: cones finos sobrepostos ao facho, desviados do eixo e de cores um pouco diferentes (verde-amarelado, quente): a borda
	-- do círculo fica irregular e manchada. Luz de brilho NEGATIVO (para escurecer manchas) NÃO funciona: o Roblox zera (medido).
	-- `desvio` = {guinada, inclinação} em graus; `brilho` é multiplicado pelo fator da lanterna. Só em qualidade 3.
	-- 2026-11-17 (2ª): ESVAZIADA. As camadas coloridas faziam um anel arco-íris em volta do círculo (print do usuário); a sujeira
	-- agora vem de `cookie`. Formato de cada camada, se voltar: { desvio = { 7, -4 }, angulo = 14, brilho = 0.9, cor = { 225, 240, 200 } }
	suja = {},

	-- FALHAS (pedido do usuário 2026-11-17; ritmo do Gold Bright, pesquisa/gold-bright.md §8): quem decide é o SERVIDOR (atributos
	-- LanternaFalhaTipo/T/Semente no personagem; todos os clientes derivam o mesmo padrão da semente, Regras/Lanterna.padraoFalha).
	falha = {
		intervalo = { 20, 50 }, -- s acesa até a próxima falha (o original: 25 a 40)
		chanceApagar = 0.25, -- a falha termina com a lanterna APAGADA: aperta F para religar. Senão só pisca.
		chanceFalharAoLigar = 0.15, -- ao ligar, falha um pouco antes de acender de vez
		aviso = "A lanterna falhou. Aperte F.",
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
