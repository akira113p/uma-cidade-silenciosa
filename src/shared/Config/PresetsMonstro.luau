-- PresetsMonstro (docs/preset-monstro.md, docs/wrapper.md): um bloco de números por "corpo" de monstro. Cada espécie de
-- Config/Monstros com `capacidades` aponta um preset por `preset = "<nome>"`; os módulos do servidor leem `d.preset`.
-- Valores marcados PROVISÓRIO ainda não foram medidos; `-- MEDIR` = medir no Studio (dona do Studio).

-- "quadrupedeArrombador": o Rastejador. Valores idênticos ao antigo Config/Rastejador (que agora é alias deste bloco).
local quadrupedeArrombador = {
	-- Escala: studs do monstro = altura do personagem em studs ÷ jogadorMetros × metros.
	-- Medido no Studio (2026-11-04): bounding box do personagem (R15 escalado por Config/Aparencia, com cabelo) = 5.234 studs.
	altura = { metros = 2.0, jogadorMetros = 1.8, jogadorStuds = 5.234 },

	-- andar = maior degrau (studs) que o Humanoid sobe andando. MEDIDO (2026-11-04, tamanho 2x: HipHeight 2,545, WalkSpeed 14): sobe 2,8, não
	-- sobe 2,9 (degraus de 10 studs de fundo); 2,7 deixa margem. (No tamanho 1x eram 1,45 -> 1,4.) Os degraus do mapa (0,2-1,35) passam sem pular.
	-- saltoMax, folgaMin, margemSalto e sondaFrente foram dobrados do tamanho 1x (PROVISÓRIO, não medidos).
	degrau = { andar = 2.7, saltoMax = 4.0, folgaMin = 6.0, margemSalto = 1.2, sondaFrente = 5.0, hz = 10 },
	-- Impacto do clipe Attack: as garras chegam à frente em p = 0,47..0,57 de 35 quadros a 24 fps (animar_rastejador_opus.py) = ~0,75 s.
	golpe = { tipo = "garra", atrasoImpacto = 0.75 },
	-- Velocidade por estado (studs/s), só do Rastejador (Corcunda/Esfolado seguem Config/Monstros.niveis). Jogador corre 16 / sprint 24.
	velocidade = { Calmo = 8, Investiga = 8, Caca = 20, Ataque = 20 },
	travado = { saltoAltura = 4.0 }, -- studs; salto de desencalhe (1ª vez que trava)
	objetivo = { histerese = 1.5, distanciaAtiva = 250 }, -- distanciaAtiva: studs; sondas/raycasts só com jogador mais perto que isto
	arrombar = {
		fatorDesvio = 2.5,
		folgaDesvio = 30,
		espessuraMax = 1.6,
		alturaMin = 6,
		tipoDano = "garra", -- tipo de dano da Destruicao (Config/Materiais)
		-- 2026-11-14 (usuário, docs/monstros/logica.md §3.2): mais dano, quebra mais rápido, buraco maior. Era dano 60 / intervalo 1,2 / folga 1,6 / altura 9.
		dano = 150, -- concreto ~8 golpes (era 20), tijolo ~6, madeira 1
		intervalo = 0.9,
		distanciaGolpe = 6,
		folgaLargura = 2.2,
		alturaBuraco = 11, -- studs a partir do chão da parede
		clipe = "Arrombar", -- golpe próprio (0,9 s); o impacto vem do evento `impacto` do clipe (padrão atrasoImpacto)
		atrasoImpacto = 0.45,
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
		tiposDeSom = { "carro", "carroLigar", "carroFalhar", "carroBatida", "carroDerrapar", "buzina", "pneuEstouro" },
		pesos = { pneu = 0.3, vidro = 0.3, carroceria = 0.4 },
	}, -- PROVISÓRIO
	-- Habilidades por espécie (docs/monstros/logica.md; lidas por server/Habilidades/<Especie>.luau). As presets derivados herdam
	-- este bloco, mas cada módulo só lê o que é seu. PROVISÓRIO: tudo não medido.
	habilidades = {
		-- §3.1 Pulso no chão: em Investiga ao chegar sem achar ninguém e em cada ponto da Busca.
		pulso = {
			raio = 25, -- legado: a varredura por raio saiu (docs/som.md §6.4); a detecção agora é audição pelo chão (bonusChao)
			bonusChao = -12, -- dB somados ao limiar do chão do monstro durante a janela (negativo = ouve melhor)
			ignorarAgachado = true, -- passo agachado/deitado não usa a via chão durante o pulso (docs/som.md §11 #2)
			janela = 4, -- s de detecção depois do evento `encostou`
			recarga = 15,
			velMinima = 1.5, -- studs/s horizontais para contar como "andando"
			db = 40,
			chegou = 4, -- studs do ponto estimado: conta como "chegou sem achar ninguém"
			encostou = 0.4, -- s do início do clipe até o evento (padrão)
			cada = 0.25, -- s entre varreduras dentro da janela
			duracao = 2.0, -- s do clipe (padrão)
		},
		-- §3.3 Busca dentro da casa.
		busca = {
			pontosMax = 8,
			grade = 6,
			duracaoMax = 45,
			olharCada = 1.0,
			entrarSemPercepcao = 2, -- s sem percepção nova para começar a busca
			alturaAndar = 4, -- studs: piso do ponto a +-isto do pé do monstro
			pisoMax = 6, -- studs: o raycast para baixo procura piso até aqui
			livreAcima = 4, -- studs livres acima do piso (sem móvel/teto)
			chegou = 3,
			checarCada = 1.0, -- s entre testes de "entrou numa construção"
			saida = 20, -- s para voltar à entrada ao terminar sem achar
			vaoValeAte = 60, -- s que um vão aberto por ele ainda conta como entrada
			raioConstrucao = 4, -- studs para achar a construção sob um ponto
		},
	},
	animacao = {
		distancia = 150,
		maxAnimados = 40,
		nativas = { Walk = 1.59, Run = 8.69 }, -- studs/s do ciclo, MEDIDO dos clipes na altura 5,816 (0,6 e 3,29 un/s x 2,644)
		parado = 0.5, -- studs/s abaixo disto = Idle
		velMin = 0.5, -- limites da velocidade de reprodução
		velMax = 3,
	},
}

-- União recursiva: tabelas se fundem, qualquer outro valor (inclusive lista) substitui.
local function derivar(base: any, mudancas: any): any
	local r = table.clone(base)
	for k, v in mudancas do
		if type(v) == "table" and type(r[k]) == "table" and #v == 0 and next(v) ~= nil then
			r[k] = derivar(r[k], v)
		else
			r[k] = v
		end
	end
	return r
end

-- "corpoAriete": o Wrapper, monstro sem braços (docs/wrapper.md §2-3). Todo dano é investida de corpo (lunge).
local corpoAriete = derivar(quadrupedeArrombador, {
	-- ~6 studs: studs = jogadorStuds / jogadorMetros x metros = 5,234 / 1,8 x 2,06. MEDIR a altura do MeshPart importado.
	altura = { metros = 2.06 },
	velocidade = { Calmo = 7, Investiga = 9, Caca = 22, Ataque = 22 }, -- MEDIR: Run_Frantic tem raio de curva grande
	-- Golpe único, mais lento e mais forte. Sem BracoE/BracoD: o Wrapper não tem braço (tabela própria, soma 1).
	golpe = {
		tipo = "lunge",
		atrasoImpacto = 0.45, -- s do início do Attack_Lunge até o dano. MEDIR no clipe
		alcanceInicio = 6, -- studs: a esta distância para de andar e investe. MEDIR
		alcanceImpacto = 7, -- studs: o dano só cai se o alvo estiver a <= isto no quadro de impacto
		avanco = 4, -- studs que o corpo avança durante o clipe (MoveTo curto, não física)
		recuperacao = 1.4, -- s parado e vulnerável depois do golpe (acertando ou não)
		dano = 25,
	},
	sorteioParte = {
		{ parte = "Torso", peso = 0.5 },
		{ parte = "Cabeca", peso = 0.2 },
		{ parte = "PernaE", peso = 0.15 },
		{ parte = "PernaD", peso = 0.15 },
	},
	-- Cabeçada na parede (WallSlam_Recover): dano 90 por cabeçada e recuperação entre elas.
	-- (os números de vão do Rastejador, §3.2, não valem para o Wrapper: voltam aos de antes)
	arrombar = {
		tipoDano = "garra", -- PROVISÓRIO: sem tipo "cabeçada" em Config/Materiais; decidir com o usuário (docs/wrapper.md Estado)
		intervalo = 1.2,
		folgaLargura = 1.6,
		alturaBuraco = 9,
		atrasoImpacto = 0.45,
		dano = 90,
		recuperacao = 1.0, -- s parado depois de cada cabeçada
		golpesMax = 40,
		desistir = 90,
		alvoRealDist = 40,
		clipe = "WallSlam", -- clipe tocado em vez de Attack ao bater na parede
	},
	morte = { tombar = 0.6 }, -- sem clipe Death no FBX: tomba o corpo 90 graus por Tween (s)
	-- 2026-11-14 (usuário, logica.md §4): sem grito; o sonar (habilidades.sonar) ocupa o lugar. `semGrito` desliga o gritaAoCacar do nível.
	semGrito = true,
	habilidades = {
		-- §4.1 Sonar: onda visível, linha de visão decide quem é detectado.
		sonar = {
			raio = 45,
			velocidade = 30, -- studs/s da frente da onda (45 studs em 1,5 s)
			recarga = 10,
			db = 70,
			perdeuAlvo = 3, -- s sem som novo em Caça: gatilho 3
			alcanceAviso = 120, -- studs: clientes que veem a onda
			memoria = 4, -- s que ele lembra onde a onda bateu
			duracao = 1.2, -- s do clipe (padrão)
			onda = 0.5, -- s do início do clipe até o evento `onda` (padrão)
			chegou = 4, -- studs: gatilho 2 (Investiga, chegou sem achar)
			alturaCabeca = 0.8, -- fração da altura, a partir do chão, de onde a onda sai
		},
		-- §4.2 Bateu na parede durante o lunge.
		atordoado = { duracao = 2.0, sonda = 2 }, -- sonda: studs à frente do corpo
		-- §4.3 Calmo: bate nas coisas andando.
		batida = { alcance = 1.5, recarga = 6, db = 45, cada = 0.5, velMinima = 2 },
	},
	animacao = { nativas = { Walk = 1.59, Run = 8.69 } }, -- MEDIR: placeholder do Rastejador; medir Walk_Nervous e Run_Frantic
})

-- Monstros refeitos no Blender (refazer_monstros.py), docs/preset-monstro.md. Escala dos clipes: nativas (studs/s) = velocidade_nativa_m_s
-- do <Nome>_v2.json x escala_blender_para_fbx do manifesto (MEDIDO dos clipes). Golpe: impacto_s = 0,483 s (clipe Attack, 30 quadros a 30 fps).
-- Alturas PROVISÓRIAS (2026-11-14, usuário não decidiu): Corcunda 2,0 m, MonstroPS1 2,0 m, Florescida 2,2 m (jogador 1,8 m = 5,234 studs).
-- degrau.andar e raioFolga: PROVISÓRIOS (estimados de HipHeight e comprimento do corpo; medir no Studio, ZonaTeste).
-- Velocidades = Config/Monstros.niveis do nível da espécie (Investiga = Calmo), para não mudar o equilíbrio.

-- Corcunda: humanoide curvado, só degrau. escala 2,6436 (5,816 / 2,2).
local corcunda = derivar(quadrupedeArrombador, {
	altura = { metros = 2.0 },
	degrau = { andar = 2.7 }, -- PROVISÓRIO: HipHeight 2,976 (Rastejador 2,545 -> 2,7)
	golpe = { atrasoImpacto = 0.483 },
	velocidade = { Calmo = 6, Investiga = 6, Caca = 14, Ataque = 14 }, -- nível 1
	animacao = { nativas = { Walk = 3.199, Run = 14.322 } }, -- 1,21 e 5,417 m/s x 2,6436
	-- docs/monstros/logica.md §5. PROVISÓRIO.
	habilidades = {
		visao = {
			angulo = 70,
			alcance = 14,
			agachado = 7,
			deitado = 4,
			noite = 0.5,
			lanterna = 20,
			cada = 0.3,
			raioMax = 20,
			diaInicio = 6,
			diaFim = 18,
		},
		empurrao = {
			alcance = 4,
			acerto = 5,
			derrubado = 2.0,
			forca = 45,
			subida = 15,
			dano = 10,
			intervaloNoChao = 1.0,
			encontroAte = 8,
			impacto = 0.35, -- s do evento `impacto` (padrão)
			duracao = 0.7,
			cone = 90,
			db = 55,
			danoDobrado = 2, -- multiplicador do golpe seguinte vindo de emboscada
		},
		portas = { cada = 0.5, raioLinha = 3, abrirDist = 4, passouDist = 4, porta = 0.4, duracao = 0.8, validade = 30 },
		emboscada = {
			raioEsconderijo = 15,
			duracao = 30,
			imitarMin = 10,
			imitarMax = 25,
			gatilho = 6,
			chanceFala = 0.5,
			falaDb = 55,
			pitchDefeito = 0.9,
			memoria = 60,
			memoriaMax = 3,
			imitarDuracao = 1.5,
			chegou = 3,
			angulos = 16,
			aneis = { 0.5, 1.0 }, -- frações de raioEsconderijo
			alturaOlho = 3,
			chegouAlvo = 4, -- studs do ponto do som para dar a investigação por vazia
			numeroFalas = 10, -- VozCorcunda_1..N (agente C cadastra 8 a 12)
			passoDbMult = 0.5, -- anotado: ele não emite passo hoje
			-- tipo de ruído imitável -> nome do som de catálogo
			sons = {
				passo = "PassoConcreto",
				aterrissar = "Aterrissar",
				porta = "Porta",
				portaAbrir = "PortaAbrir",
				portaFechar = "PortaFechar",
				pistola = "TiroPistola",
				arma = "TiroPistola", -- Armas.luau emite os tiros com tipo "arma" (sem distinguir calibre): imita como pistola
				fuzil = "TiroFuzil",
				vidro = "Vidro",
				itemCaindo = "CartuchoCai",
				-- tipos novos do Som v2 (docs/som.md §6.4): um som de catálogo por tipo (o subtipo do evento é ignorado)
				detrito = "DetritoLata",
				esbarrao = "EsbarrarMadeira",
				itemCaiu = "CartuchoCai",
				respiracao = "SoltarAr",
			},
		},
	},
})

-- MonstroPS1: humanoide de braços longos, só degrau. escala 2,6436.
local monstroPS1 = derivar(quadrupedeArrombador, {
	altura = { metros = 2.0 },
	degrau = { andar = 2.4 }, -- PROVISÓRIO: HipHeight 2,485
	golpe = { atrasoImpacto = 0.483 },
	velocidade = { Calmo = 6, Investiga = 6, Caca = 14, Ataque = 14 }, -- nível 1
	animacao = { nativas = { Walk = 2.332, Run = 11.896 } }, -- 0,882 e 4,5 m/s x 2,6436 (clipes refeitos 2026-11-14)
	-- docs/monstros/logica.md §6. PROVISÓRIO.
	habilidades = {
		arrancada = {
			min = 15,
			max = 40,
			duracao = 1.5,
			velocidade = 26,
			recarga = 12,
			faiscaCada = 0.1,
			faiscaVida = 6,
			db = 60,
			rasparCada = 0.5,
			luzCada = 0.3,
			golpeDuploDist = 5,
		},
		-- docs/som.md §6.4: enquanto raspa as lâminas (Calmo e na arrancada) o próprio barulho o ensurdece: soma ao limiar de cada banda
		raspar = { surdez = { grave = 6, medio = 6, agudo = 6 } },
		lancar = {
			min = 15,
			max = 50,
			recarga = 6,
			erroGraus = 9,
			velocidade = 80,
			dano = 8,
			previsao = 0.2,
			vidaCravada = 10,
			db = 50,
			soltar = 0.45, -- s do evento `soltar` (padrão)
			duracao = 0.8,
			gravidade = 30, -- studs/s2: a lâmina voa quase reta (workspace.Gravity = 196 faria ela cair 24 studs em 40 de distância)
			tempoMax = 2,
			alcanceMax = 80,
			passo = 1 / 30,
			danoVidro = 30,
			tamanho = { 0.2, 0.2, 2.5 },
		},
		golpeDuplo = { dano = 15, alcance = 5, cada = 3, impacto1 = 0.35, impacto2 = 0.65, duracao = 1.0 },
		corte = { dano = 60, tipo = "lamina", golpesMax = 2, alcance = 6, intervalo = 1.0, cada = 0.5, impacto = 0.483 },
	},
})

-- Florescida: quadrúpede (cervo) com cauda e mandíbula; nível 2 (vida/dano/percepção do nível 2), arromba e morde carro. escala 2,9078 (6,3971 / 2,2).
local florescida = derivar(quadrupedeArrombador, {
	-- 2026-11-14 (usuário): gigante, mais de 5 m, nível alto e forte. 5,5 m = 16 studs (escala 7,2727 sobre a malha de 2,2 m).
	altura = { metros = 5.5 },
	-- PROVISÓRIO (não medido): HipHeight 8,49 -> andar 9,0 (Rastejador: 2,545 -> 2,7); o resto = Rastejador x 2,75 (16 / 5,816)
	degrau = { andar = 9.0, saltoMax = 11.0, folgaMin = 16.5, margemSalto = 3.3, sondaFrente = 13.75 },
	golpe = { atrasoImpacto = 0.483 },
	-- 2026-11-14 (usuário, logica.md §7.1): "mais rápida que carro normal". PROVISÓRIO: Caça 60 passa carro normal (45-58), perde para esportivo (78).
	velocidade = { Calmo = 12, Investiga = 24, Caca = 60, Ataque = 60 },
	-- o arrombar antigo (vão de 16 studs) saiu (capacidades.arrombar = false); fica só raioFolga, usado no alcance contra carro
	arrombar = { raioFolga = 9.9 },
	veiculo = { alcance = 18, raioBusca = 40, dano = 30 }, -- PROVISÓRIO
	animacao = { nativas = { Walk = 6.058, Run = 38.182 } }, -- 0,833 e 5,25 m/s x 7,2727; Caça 60 = 1,57x (velMax 3)
	-- docs/monstros/logica.md §7. PROVISÓRIO.
	habilidades = {
		giro = { grausPorSegundo = 120 },
		cidade = { chave = "cidade", borda = 2, rondar = 20 },
		mordida = { alcance = 14, altura = 10, impacto = 0.483, duracao = 1.2 },
		florescer = {
			cada = 30,
			max = 12,
			raioEscuta = 20,
			db = 70,
			murchar = 10,
			duracao = 1.5,
			plantar = 0.9,
			frente = 8, -- studs à frente onde nasce a flor
		},
		rugido = {
			raio = 30,
			derrubado = 1.5,
			impulso = 20,
			subida = 10,
			tremor = 60,
			tremorIntensidade = 1.0,
			tremorDuracao = 1.2,
			recarga = 30,
			db = 100,
			duracao = 1.6,
			impacto = 0.9,
		},
		cauda = { alcance = 14, cone = 100, dano = 35, empurrao = 50, recarga = 4, duracao = 0.9, impacto = 0.45 },
		fachada = {
			alturaMax = 26,
			caixa = { 14, 12, 3 },
			dano = 2000,
			alcanceDentro = 8,
			dentroPor = 8, -- s que o alcance extra vale
			recarga = 6,
			rondar = 60,
			duracao = 1.8,
			impacto = 0.8,
			danoJanela = 400,
			janelaCada = 2,
		},
		pisotear = { cada = 0.2, frente = 6, dano = 400, impulsoCarro = 60, danoCarro = 30, cadaCarro = 1.0 },
	},
})

return {
	quadrupedeArrombador = quadrupedeArrombador,
	corpoAriete = corpoAriete,
	corcunda = corcunda,
	monstroPS1 = monstroPS1,
	florescida = florescida,
}
