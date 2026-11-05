-- GERADO por ferramentas/animacao/gerar_config.py (assets/animacoes/armas/*.json + ferramentas/animacao/enviados.json).
-- Nao editar a mao: mude o JSON e rode o gerador. Contrato: docs/armas.md §9 (animacao do corpo, 3a pessoa).
-- animacoes[classe][clipe] = id da Animation (false = ainda nao enviada: o clipe nao toca). duracao = duracao NATIVA do clipe (s);
-- ArmasTerceira ajusta a velocidade (AdjustSpeed) para casar com Config/Armas (recarga.tempo, cadencia).
-- mao.C0 = CFrame do Motor6D RightHand -> Cabo da arma (palma segura o Cabo); porClasse sobrepoe por classe.
return {
	mao = {
		C0 = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
		porClasse = {
			contundente = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
			escopeta = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
			faca = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
			fuzil = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
			lancador = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
			machado = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(0), math.rad(0), math.rad(0)),
			pistola = CFrame.new(0, -0.16, 0) * CFrame.fromEulerAnglesYXZ(math.rad(-90), math.rad(0), math.rad(0)),
		},
	},
	animacoes = {
		contundente = {
			Equip = false,
			Golpe = false,
			Idle = false,
		},
		escopeta = {
			Equip = false,
			Fire = false,
			Idle = false,
			RecargaCartucho = false,
			RecargaFim = false,
			RecargaInicio = false,
		},
		faca = {
			Equip = false,
			Golpe1 = false,
			Golpe2 = false,
			Idle = false,
		},
		fuzil = {
			Equip = false,
			Fire = false,
			Idle = false,
			Reload = false,
		},
		lancador = {
			Equip = false,
			Fire = false,
			Idle = false,
			Reload = false,
		},
		machado = {
			Equip = false,
			Golpe = false,
			Idle = false,
		},
		pistola = {
			Equip = false,
			Fire = false,
			Idle = false,
			Reload = false,
		},
	},
	duracao = {
		contundente = {
			Equip = 0.4,
			Golpe = 0.7,
			Idle = 2.2,
		},
		escopeta = {
			Equip = 0.5,
			Fire = 0.7,
			Idle = 2.4,
			RecargaCartucho = 0.55,
			RecargaFim = 0.4,
			RecargaInicio = 0.5,
		},
		faca = {
			Equip = 0.35,
			Golpe1 = 0.45,
			Golpe2 = 0.45,
			Idle = 2,
		},
		fuzil = {
			Equip = 0.5,
			Fire = 0.12,
			Idle = 2.4,
			Reload = 2.6,
		},
		lancador = {
			Equip = 0.6,
			Fire = 0.3,
			Idle = 2.6,
			Reload = 3.8,
		},
		machado = {
			Equip = 0.5,
			Golpe = 1,
			Idle = 2.4,
		},
		pistola = {
			Equip = 0.35,
			Fire = 0.15,
			Idle = 2,
			Reload = 2,
		},
	},
	-- instante (s, na velocidade nativa) do marcador "Impacto" dos golpes; tem de bater com Config/Armas.atrasoImpacto
	impacto = {
		contundente = { Golpe = 0.25 },
		faca = { Golpe1 = 0.12, Golpe2 = 0.12 },
		machado = { Golpe = 0.35 },
	},
	-- mao esquerda por IKControl: clipes em que o IK fica desligado (a mao anima) e janelas (s) dentro do clipe
	ik = {
		escopeta = {
			desligar = { Equip = true, RecargaInicio = true, RecargaCartucho = true, RecargaFim = true },
			janelas = { Fire = { 0.2, 0.58 } },
		},
		fuzil = { desligar = { Equip = true, Reload = true }, janelas = {} },
		lancador = { desligar = { Equip = true, Reload = true }, janelas = {} },
		machado = { desligar = { Equip = true, Golpe = true }, janelas = {} },
	},
	-- camada de mira (pitch da camera): fracao do angulo que cada junta leva e limites, em graus
	mira = {
		alcance = 150, -- studs: so personagens ate esta distancia da camera recebem a mira
		hz = 8, -- envio do evento Mira
		cintura = 0.35,
		pescoco = 0.65,
		ombros = 0.65, -- so em arma de fogo (duas maos: os dois ombros; uma mao: so o direito)
		maxCintura = 30,
		maxPescoco = 50,
		maxOmbro = 55,
		suavizar = 12, -- 1/s, para o pitch replicado dos outros jogadores
	},
}
