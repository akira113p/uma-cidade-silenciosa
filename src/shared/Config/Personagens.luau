-- Elenco de personagens (dado puro). Dono: parte S (docs/personagens.md §1). Todos têm o MESMO corpo físico (o R15 de
-- Config/Aparencia); muda só o visual: nenhum atributo (vida, velocidade, dano) depende do personagem.
-- Campos: id (string estável), n (número estável: persistência e rede), nome, descricao (1 linha), visual ("bloco" |
-- "malhas"; "malhas" cai em "bloco" enquanto Config/PersonagensMalhas não tiver tudo enviado), estilo (detalhes do
-- visual em blocos), paleta (só as cores que mudam em relação a Config/Aparencia.cores; chaves novas são aceitas),
-- fonte (origem/licença/crédito), ordem (posição no seletor). Cores em RGB 0..255.

return {
	padrao = "male_casual", -- id do personagem usado quando o atributo PersonagemId falta ou é inválido

	-- Altura (studs) do corpo R15 atual (Config/Rastejador: 5,234). Visual "malhas": escala única do conjunto,
	-- k = alturaCorpo / PersonagensMalhas[id].alturaTotalStuds (ver shared/PersonagemVisual).
	alturaCorpo = 5.234,

	-- Variações de cabelo. "trancas" é o preset do personagem atual (Config/Aparencia.cabelo, lido pelo código).
	-- trancas = 0 não põe bolinhas; faixaTras/faixaLado = fração da altura da cabeça que a faixa cobre.
	cabelos = {
		curto = { lajeEspessura = 0.14, trancas = 0, trancaDiametro = 0.3, faixaTras = 0.3, faixaLado = 0.2 },
		comprido = { lajeEspessura = 0.2, trancas = 0, trancaDiametro = 0.3, faixaTras = 0.98, faixaLado = 0.62 },
	},

	-- Prévia 3D do seletor: R15 aproximado (escala 1, studs) empilhado do pé à cabeça; o código aplica Config/Aparencia.escala.
	previa = {
		tamanhos = {
			Head = { 1.2, 1.2, 1.2 },
			UpperTorso = { 2, 1.6, 1 },
			LowerTorso = { 2, 0.4, 1 },
			LeftUpperArm = { 1, 1.2, 1 },
			LeftLowerArm = { 1, 1.1, 1 },
			LeftHand = { 1, 0.3, 1 },
			RightUpperArm = { 1, 1.2, 1 },
			RightLowerArm = { 1, 1.1, 1 },
			RightHand = { 1, 0.3, 1 },
			LeftUpperLeg = { 1, 1.2, 1 },
			LeftLowerLeg = { 1, 1.2, 1 },
			LeftFoot = { 1, 0.3, 1 },
			RightUpperLeg = { 1, 1.2, 1 },
			RightLowerLeg = { 1, 1.2, 1 },
			RightFoot = { 1, 0.3, 1 },
		},
		fov = 28, -- graus da câmera da prévia
		margem = 1.18, -- folga em volta do personagem no quadro
		giro = 0.6, -- rad/s
	},

	-- Quanto o servidor espera (s) com o jogador no seletor antes de reaparecê-lo mesmo assim.
	esperaSeletorMax = 60,

	lista = {
		{
			id = "male_casual",
			n = 1,
			nome = "Casual",
			descricao = "Camiseta verde, calça jeans e barba.",
			visual = "malhas",
			estilo = { cabelo = "curto", torso = "suter", rosto = "serio", costura = false, mochila = false },
			paleta = {
				pele = { 214, 170, 140 },
				suter = { 52, 82, 84 },
				calcao = { 40, 66, 110 },
				perna = { 40, 66, 110 },
				cabelo = { 50, 36, 28 },
			},
			fonte = {
				origem = "psx sttuff/3-personagens (male_casual); textura em mosaico, sem foto",
				licenca = "uso liberado pelo usuario (2026-11-13)",
				credito = false,
			},
			ordem = 1,
		},
		{
			id = "office_worker",
			n = 2,
			nome = "Escriturário",
			descricao = "Camisa social clara, gravata e calça escura.",
			visual = "malhas",
			estilo = { cabelo = "curto", torso = "gravata", rosto = "serio", costura = false, mochila = false },
			paleta = {
				pele = { 224, 172, 138 },
				suter = { 222, 226, 232 }, -- camisa social clara
				bolso = { 196, 202, 212 }, -- colarinho
				cinto = { 30, 30, 36 },
				fivela = { 170, 170, 176 },
				calcao = { 44, 46, 58 }, -- calça escura (coxa)
				perna = { 44, 46, 58 }, -- calça escura (canela)
				sapato = { 26, 24, 24 },
				sola = { 58, 56, 54 },
				cabelo = { 58, 40, 30 },
				sobrancelha = { 50, 34, 26 },
				boca = { 176, 104, 98 },
				gravata = { 128, 34, 40 },
			},
			fonte = {
				origem = "psx-people-free office_worker.fbx",
				licenca = "CC BY 4.0",
				credito = "PSX People Free by heyheythere - heyheythere.itch.io/psx-people-free - CC BY 4.0",
			},
			ordem = 2,
		},
		{
			id = "survivor_woman",
			n = 3,
			nome = "Sobrevivente",
			descricao = "Jaqueta verde-militar, mochila e cabelo longo.",
			visual = "malhas",
			estilo = { cabelo = "comprido", torso = "jaqueta", rosto = "serio", costura = false, mochila = true },
			paleta = {
				pele = { 206, 150, 118 },
				suter = { 74, 88, 56 }, -- jaqueta verde-militar
				bolso = { 58, 70, 44 },
				cordao = { 196, 186, 146 }, -- zíper
				cinto = { 36, 30, 24 },
				fivela = { 150, 140, 90 },
				calcao = { 78, 68, 50 }, -- calça cargo
				perna = { 56, 50, 40 },
				sapato = { 38, 32, 26 }, -- botas
				sola = { 22, 20, 18 },
				cabelo = { 92, 52, 34 },
				sobrancelha = { 70, 40, 28 },
				boca = { 168, 92, 86 },
				mochila = { 96, 86, 56 },
				mochilaFecho = { 40, 36, 30 },
			},
			fonte = {
				origem = "psx-people-free survivor_woman.fbx",
				licenca = "CC BY 4.0",
				credito = "PSX People Free by heyheythere - heyheythere.itch.io/psx-people-free - CC BY 4.0",
			},
			ordem = 3,
		},
		{
			id = "villager_man",
			n = 4,
			nome = "Aldeão",
			descricao = "Chapéu de palha, camisa marrom e sandálias.",
			visual = "malhas",
			estilo = { cabelo = "curto", torso = "suter", rosto = "serio", costura = false, mochila = false },
			paleta = {
				pele = { 200, 150, 120 },
				suter = { 96, 64, 40 },
				calcao = { 150, 140, 110 },
				perna = { 150, 140, 110 },
				cabelo = { 30, 24, 20 },
			},
			fonte = {
				origem = "psx sttuff/3-personagens (villager_man); textura em mosaico, sem foto",
				licenca = "uso liberado pelo usuario (2026-11-13)",
				credito = false,
			},
			ordem = 4,
		},
		{
			id = "villager_woman",
			n = 5,
			nome = "Aldeã",
			descricao = "Blusa clara, macacão verde e cabelo curto.",
			visual = "malhas",
			estilo = { cabelo = "curto", torso = "suter", rosto = "serio", costura = false, mochila = false },
			paleta = {
				pele = { 210, 160, 130 },
				suter = { 210, 204, 190 },
				calcao = { 90, 100, 76 },
				perna = { 200, 150, 120 },
				cabelo = { 24, 20, 18 },
			},
			fonte = {
				origem = "psx sttuff/3-personagens (villager_woman); textura em mosaico, sem foto",
				licenca = "uso liberado pelo usuario (2026-11-13)",
				credito = false,
			},
			ordem = 5,
		},
	},
}
