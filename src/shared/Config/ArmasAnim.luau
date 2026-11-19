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
			Equip = "rbxassetid://137085179338467",
			Golpe = "rbxassetid://126532690633723",
			Idle = "rbxassetid://96132612869599",
		},
		escopeta = {
			Equip = "rbxassetid://117234970026723",
			Fire = "rbxassetid://120742801259082",
			Idle = "rbxassetid://99887362462082",
			RecargaCartucho = "rbxassetid://80902485742783",
			RecargaFim = "rbxassetid://102309318926643",
			RecargaInicio = "rbxassetid://135483812803237",
		},
		faca = {
			Equip = "rbxassetid://110454742289828",
			Golpe1 = "rbxassetid://114257853122331",
			Golpe2 = "rbxassetid://118060518579409",
			Idle = "rbxassetid://101871924144134",
		},
		fuzil = {
			Equip = "rbxassetid://97241711765436",
			Fire = "rbxassetid://82288537979970",
			Idle = "rbxassetid://139485065440064",
			Reload = "rbxassetid://124439465626808",
		},
		lancador = {
			Equip = "rbxassetid://125374873284508",
			Fire = "rbxassetid://106670382730504",
			Idle = "rbxassetid://109890057933498",
			Reload = "rbxassetid://84734512190551",
		},
		machado = {
			Equip = "rbxassetid://98592872201515",
			Golpe = "rbxassetid://127650366223085",
			Idle = "rbxassetid://129723604495884",
		},
		pistola = {
			Equip = "rbxassetid://106703958622086",
			Fire = "rbxassetid://73541804621761",
			Idle = "rbxassetid://111732734924259",
			Reload = "rbxassetid://135608394360996",
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
