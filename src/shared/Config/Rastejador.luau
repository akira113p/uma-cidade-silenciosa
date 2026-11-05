-- Rastejador (docs/rastejador.md §7): todos os números da espécie. Valores marcados PROVISÓRIO ainda não foram medidos.
-- Capacidades ligadas só no Rastejador (Config/Monstros.especies.Rastejador.capacidades).

return {
	-- Escala: studs do monstro = altura do personagem em studs ÷ jogadorMetros × metros.
	-- Medido no Studio (2026-11-04): bounding box do personagem (R15 escalado por Config/Aparencia, com cabelo) = 5.234 studs.
	altura = { metros = 2.0, jogadorMetros = 1.8, jogadorStuds = 5.234 },

	-- andar = maior degrau (studs) que o Humanoid sobe andando. MEDIDO (2026-11-04, tamanho 2x: HipHeight 2,545, WalkSpeed 14): sobe 2,8, não
	-- sobe 2,9 (degraus de 10 studs de fundo); 2,7 deixa margem. (No tamanho 1x eram 1,45 -> 1,4.) Os degraus do mapa (0,2-1,35) passam sem pular.
	-- saltoMax, folgaMin, margemSalto e sondaFrente foram dobrados do tamanho 1x (PROVISÓRIO, não medidos).
	degrau = { andar = 2.7, saltoMax = 4.0, folgaMin = 6.0, margemSalto = 1.2, sondaFrente = 5.0, hz = 10 },
	-- Impacto do clipe Attack: as garras chegam à frente em p = 0,47..0,57 de 35 quadros a 24 fps (animar_rastejador_opus.py) = ~0,75 s.
	golpe = { atrasoImpacto = 0.75 },
	-- Velocidade por estado (studs/s), só do Rastejador (Corcunda/Esfolado seguem Config/Monstros.niveis). Jogador corre 16 / sprint 24.
	velocidade = { Calmo = 8, Investiga = 8, Caca = 20, Ataque = 20 },
	travado = { saltoAltura = 4.0 }, -- studs; salto de desencalhe (1ª vez que trava)
	objetivo = { histerese = 1.5, distanciaAtiva = 250 }, -- distanciaAtiva: studs; sondas/raycasts só com jogador mais perto que isto
	arrombar = {
		fatorDesvio = 2.5,
		folgaDesvio = 30,
		espessuraMax = 1.6,
		alturaMin = 6,
		dano = 60, -- garra 2x: concreto (480/stud x 0,4 de garra) = 20 golpes (antes 20 = 60 golpes, acima de golpesMax: nunca tentava)
		intervalo = 1.2,
		distanciaGolpe = 6,
		folgaLargura = 1.6,
		alturaBuraco = 9, -- studs a partir do chão da parede
		esperaNavmesh = 0.5,
		golpesMax = 60, -- golpes de garra que o monstro aceita para abrir uma parede (Destruicao.golpesPara); acima disso ignora (sempre escolhe a mais fraca)
		alcanceRaio = 40, -- studs; raycast do monstro até a parede
		desistir = 90, -- s batendo/indo à mesma parede sem abrir: desiste
		erroDentro = 0.15, -- fração da distância: o alvo é o som ESTIMADO (Config/Monstros.estados.erroPorDistancia); "dentro" testa pontos nesse raio
		alvoRealDist = 40, -- studs; com jogador mais perto que isto o alvo da parede é a posição dele (o monstro já o ouviu/atacou)
		angulos = { 0, 15, -15, 30, -30 }, -- graus: raios monstro->alvo varridos para achar a parede mais fraca
		reprocurar = 3, -- s entre buscas de parede quando a anterior não achou
		raioFolga = 2.7, -- studs; metade do comprimento do corpo, para medir o alcance do golpe a partir do centro
	}, -- PROVISÓRIO
	veiculo = {
		raioBusca = 25,
		memoria = 6,
		alcance = 7,
		intervalo = 1.4,
		dano = 12,
		perseguirMax = 4,
		tiposDeSom = { "carro", "carroLigar", "carroFalhar", "carroBatida", "buzina", "pneuEstouro" },
		pesos = { pneu = 0.3, vidro = 0.3, carroceria = 0.4 },
	}, -- PROVISÓRIO
	animacao = {
		distancia = 150,
		maxAnimados = 40,
		nativas = { Walk = 1.59, Run = 8.69 }, -- studs/s do ciclo, MEDIDO dos clipes na altura 5,816 (0,6 e 3,29 un/s x 2,644)
		parado = 0.5, -- studs/s abaixo disto = Idle
		velMin = 0.5, -- limites da velocidade de reprodução
		velMax = 3,
	},
}
