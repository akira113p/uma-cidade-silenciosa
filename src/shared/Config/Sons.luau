-- Catálogo de sons: nome lógico → variações. O código toca NOMES, nunca ids soltos (skill som-roblox).
-- Todos conferidos em 2026-11-01 com ContentProvider:PreloadAsync no place do jogo (status Success).
-- confirmado = false: o usuário ainda não ouviu. Origem "HL2"/"CSGO"/"SCP" = áudio de jogo de terceiros enviado por
-- usuário; trocar antes de publicar.
-- grupo: "Efeitos" | "Ambiente" | "UI" | "Voz" (SoundGroup no SoundService, volume pela preferência Pref_Volume)

local function ids(lista: { number }): { string }
	local t = {}
	for _, id in lista do
		table.insert(t, "rbxassetid://" .. id)
	end
	return t
end

-- No Roblox o require é por instância; no Lune (testes) é por caminho relativo ao arquivo.
local function carregar(nome: string): any
	if typeof(script) == "Instance" then
		return require((script :: any).Parent:WaitForChild(nome))
	end
	return (require :: any)("./" .. nome)
end

-- Ids enviados do pacote PSX (gerado por ferramentas/audio/gerar_config_audio.py; lista vazia = ainda não enviado).
local PSX = carregar("SonsPSX")
-- Sons novos dos monstros (gerado por ferramentas/som/enviar_som.py; docs/monstros/logica.md §9). Faltando = lista vazia.
local NM = carregar("SonsMonstros")
local function monstro(nome: string): { string }
	local id = NM.sons[nome]
	return if id then ids({ id }) else {}
end
local falasCorcunda = ids(NM.VozCorcunda)

-- Usa só os ids novos se houver; senão os antigos (o jogo não fica mudo até o upload acontecer; docs/audio-psx.md §3).
local function novoOuAntigo(novos: { number }?, antigos: { number }): { string }
	if novos and #novos > 0 then
		return ids(novos)
	end
	return ids(antigos)
end

-- Junta só os ids que existem (faixa de ambiente ainda não enviada vem nil).
local function existentes(...: number?): { number }
	local pacote = table.pack(...)
	local t = {}
	for i = 1, pacote.n do
		if pacote[i] then
			table.insert(t, pacote[i])
		end
	end
	return t
end

local ANTIGOS_CONCRETO = { 87061775498714, 120195545352847, 108290664490396, 106961831442199, 112000835797556 }
local ANTIGOS_GRAMA_BAIXA = { 129956418693357, 78534941650081, 110522236020035, 135037154891351 }
local ANTIGOS_METAL = { 140728903346385, 139723537411614, 135890657963973, 9125818616 }
local passoMetal = novoOuAntigo(PSX.passos.Metal, ANTIGOS_METAL) -- MangueiraSolta reaproveita a mesma lista

return {
	-- Passos (um por superfície de Config/Som.superficies). pitch varia ±variacao.
	PassoConcreto = {
		ids = novoOuAntigo(PSX.passos.Concrete, ANTIGOS_CONCRETO),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Concrete); antigos: Creator Store (IDogeffI, Diman_x86)",
		confirmado = false,
	},
	PassoTerra = {
		ids = novoOuAntigo(PSX.passos.Dirt, ANTIGOS_GRAMA_BAIXA),
		volume = 0.55,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Dirt); antigos: os de grama baixa",
		confirmado = false,
	},
	PassoPedra = {
		ids = novoOuAntigo(PSX.passos.Stone, ANTIGOS_CONCRETO),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Stone); antigos: os de concreto",
		confirmado = false,
	},
	PassoGramaBaixa = {
		ids = novoOuAntigo(PSX.passos.Grass, ANTIGOS_GRAMA_BAIXA),
		volume = 0.5,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Grass); antigos: Creator Store (Robloxmastermanyay)",
		confirmado = false,
	},
	PassoGramaAlta = {
		-- Mesmo arquivo da grama baixa, mais alto e com mais variação de pitch: dá a diferença.
		ids = novoOuAntigo(PSX.passos.Grass, { 9114518386, 114626769792529 }),
		volume = 0.7,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Grass); antigos: ProSoundEffects / levka_321",
		confirmado = false,
	},
	PassoMadeira = {
		ids = novoOuAntigo(PSX.passos.Wood, { 92705710431057, 140525304232464 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Wood); antigos: Creator Store (Robloxmastermanyay, Diman_x86 'CSGO')",
		confirmado = false,
	},
	PassoCarpete = {
		-- O pacote não tem carpete: Dirt abafado é o mais próximo (decisão provisória, docs/audio-psx.md §3.1).
		ids = novoOuAntigo(PSX.passos.Dirt, { 91882016473062, 111131620367547, 73343053773763, 123224557798023 }),
		volume = 0.3,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Dirt, abafado); antigos: Creator Store (iLoveSwiss_0)",
		confirmado = false,
	},
	PassoCascalho = {
		ids = novoOuAntigo(PSX.passos.Gravel, { 71307609262509, 104596932601069, 132387836053582 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Gravel); antigos: Creator Store (Diman_x86)",
		confirmado = false,
	},
	PassoMetal = {
		ids = passoMetal,
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "PSX 40 Free Footsteps (Metal); antigos: Creator Store (Diman_x86 'CSGO', zhernoseki12 'SCP' CC BY-SA), ProSoundEffects",
		confirmado = false,
	},
	PassoAgua = {
		ids = ids({ 9117940837 }),
		volume = 0.5,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "ProSoundEffects",
		confirmado = false,
	},
	Aterrissar = {
		ids = ids({ 122835002033356, 9113525391 }),
		volume = 0.7,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (katorea_1), ProSoundEffects",
		confirmado = false,
	},

	-- Ações
	Porta = {
		ids = ids({ 9120829478, 85624114152325 }),
		volume = 0.7,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "ProSoundEffects / No0ne80412",
		confirmado = false,
	},
	Vidro = {
		ids = ids({ 9114592102, 9114592245 }),
		volume = 0.9,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "ProSoundEffects",
		confirmado = false,
	},
	AbrirCaixa = {
		ids = ids({ 9113722325 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "ProSoundEffects",
		confirmado = false,
	},
	Comer = {
		ids = ids({ 7029475752, 78138340192174 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store",
		confirmado = false,
	},
	Beber = {
		ids = ids({ 9114171957, 1481574895 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "ProSoundEffects / WaddelsG",
		confirmado = false,
	},
	Bandagem = {
		ids = ids({ 9113836270 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "ProSoundEffects",
		confirmado = false,
	},

	-- Armas
	Balanco = {
		ids = ids({ 108598690388763, 120847059990228 }),
		volume = 0.6,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "Creator Store",
		confirmado = false,
	},
	Faca = {
		ids = ids({ 108673879396403 }),
		volume = 0.6,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "Creator Store (coolguyVicaso)",
		confirmado = false,
	},
	AcertoCarne = {
		ids = ids({ 127713737439439, 97094698098374 }),
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "Creator Store",
		confirmado = false,
	},
	AcertoMetal = {
		ids = ids({ 9125740081, 9116653976 }),
		volume = 0.8,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "ProSoundEffects",
		confirmado = false,
	},
	TiroPistola = {
		ids = ids({ 127604219525464, 90432171903658, 92011177452282 }),
		volume = 1,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (Murklit: mod ArcCW)",
		confirmado = false,
	},

	-- Armas novas (docs/armas.md §11), candidatos de pesquisa/armas-sons-candidatos.md (busca de 2026-11-05).
	-- ATENÇÃO: este bloco ainda NÃO passou por ContentProvider:PreloadAsync (A1 não usa o Studio) e ninguém ouviu.
	-- Conferir no playtest; vários são extraídos de jogos/mods comerciais, trocar antes de publicar.
	TiroFuzil = {
		ids = ids({ 113879008765178, 131480162950556 }),
		volume = 1,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (circles_squared 'Assault Rifle Shot', xXN00BL3MUR3005Xx 'Gunsaw')",
		confirmado = false,
	},
	TiroEscopeta = {
		-- Não usei 9112912106 (ProSoundEffects): tem vários tiros em 3,1 s e tocaria rajada.
		ids = ids({ 136216209294970, 113543931016554 }),
		volume = 1,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (dolongisor 'shotgun 12 gauge single shot dry', Vyhtx21 'Shotgun shot', sem descrição)",
		confirmado = false,
	},
	TiroFoguete = {
		ids = ids({ 12222065, 140307246312623 }),
		volume = 1,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (Roblox 'Launching rocket.wav', PIauny 'Rocket launch 2')",
		confirmado = false,
	},
	ExplosaoFoguete = {
		ids = ids({ 94063576800916, 6969688228 }),
		volume = 1,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (rerberto2019 'Roblox Rocket Explosion Sound', Siydge 'Distant Explosion - Hellfire Rocket', cauda longa)",
		confirmado = false,
	},
	RecargaPenteSai = {
		ids = ids({ 1550642637, 86957102948956 }),
		volume = 0.7,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (nascarsimracing1 'Pistol Mag Out', leomomoeda10 'pistol mag out')",
		confirmado = false,
	},
	-- Só há inserção de pente de RIFLE (sem candidato de pistola): reaproveitado também na pistola/Beretta.
	RecargaPenteEntra = {
		ids = ids({ 126098303988653, 103627838055194 }),
		volume = 0.7,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (Urb3nAmbush 'M16/M4 Mag In', xxxnewmakcxxx 'M9K M4A1 Mag Insert': extraído de addon do Garry's Mod)",
		confirmado = false,
	},
	RecargaFuzil = {
		ids = ids({ 140069224599018, 134316977450799 }),
		volume = 0.7,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (THESE_BISCUITS987 'Assault Rifle Reloading Audio', shrstt 'Rifle_reload')",
		confirmado = false,
	},
	RecargaFoguete = {
		ids = ids({ 100747600452749 }),
		volume = 0.8,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (Zelgraz 'Rocket launcher Reload Sound')",
		confirmado = false,
	},
	Bombear = {
		ids = ids({ 9112913564, 113837896417526 }),
		volume = 0.8,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "ProSoundEffects ('12 Gauge Shotgun 9', 1,1 s), Creator Store (RabbitFan6butreal 'shotgun-pump')",
		confirmado = false,
	},
	InserirCartucho = {
		ids = ids({ 104910000431982, 134908573221885 }),
		volume = 0.6,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "Creator Store (CBE_Simon 'Shotgun Shell Insert', xxxnewmakcxxx 'LiTDoom Shell Insert': extraído do mod LiTDoom)",
		confirmado = false,
	},
	CliqueVazio = {
		ids = ids({ 90499731723010 }),
		volume = 0.7,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (lxstrzg '9mm Pistol Dry Fire'; único candidato bom, serve para todas as armas)",
		confirmado = false,
	},
	EquiparArma = {
		ids = ids({ 1788528046, 126112151825919 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (SleepyHeroo 'Weapon Draw', xXLord_3400Xx 'Weapon draw')",
		confirmado = false,
	},
	BalancoPesado = {
		-- Sem candidato de machado: whoosh pesado de espada/golpe. 9119746108 tem vários golpes em 2,1 s (pode soar como rajada).
		ids = ids({ 112611832797358, 9119746108 }),
		volume = 0.7,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "Creator Store (fluff5050 'Downslam Air'), ProSoundEffects ('Sword Duel 402')",
		confirmado = false,
	},
	CartuchoCai = {
		ids = ids({ 9113631067, 9113105140 }),
		volume = 0.5,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "ProSoundEffects ('Bullet Drops 4', 'Ammo Rounds Drop 1')",
		confirmado = false,
	},

	-- Veículos (busca search_asset em 2026-11-03, PreloadAsync Success)
	MotorLoop = {
		ids = ids({ 80317022777602 }),
		volume = 0.7,
		variacao = 0.0,
		grupo = "Efeitos",
		loop = true,
		origem = "Creator Store (Roblox Resources, Car-Engine-Loop)",
		confirmado = false,
	},
	MotorPartida = {
		ids = ids({ 5830481291 }),
		volume = 0.8,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (zKevin)",
		confirmado = false,
	},
	MotorFalha = {
		ids = ids({ 111925060225158 }),
		volume = 0.8,
		variacao = 0.03,
		grupo = "Efeitos",
		origem = "Creator Store (robloxain_alt2222)",
		confirmado = false,
	},
	-- Rastejador arrombando parede (docs/rastejador.md §2): ids reaproveitados do catálogo (AcertoMetal / CarroBatida).
	GolpeParede = {
		ids = ids({ 9125740081, 9116653976 }),
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "ProSoundEffects (reuso de AcertoMetal)",
		confirmado = false,
	},
	ParedeCai = {
		ids = ids({ 8125594257, 70951531892215 }),
		volume = 1,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "Creator Store (reuso de CarroBatida)",
		confirmado = false,
	},
	-- Poste/placa tombado batendo no chão (docs/destruicao.md §11): reuso de CarroBatida até achar um som de metal caindo.
	PosteCai = {
		ids = ids({ 8125594257, 70951531892215 }),
		volume = 1,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "Creator Store (reuso de CarroBatida)",
		confirmado = false,
	},
	CarroBatida = {
		ids = ids({ 8125594257, 70951531892215 }),
		volume = 1,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (InGriefToDwell, Trime_X24)",
		confirmado = false,
	},
	Buzina = {
		ids = ids({ 127513531122725 }),
		volume = 0.9,
		variacao = 0.02,
		grupo = "Efeitos",
		origem = "Creator Store (poldamerr)",
		confirmado = false,
	},
	PneuEstouro = {
		ids = ids({ 106788715223076, 2694245144 }),
		volume = 0.9,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (diman's group, Ize_Cubz)",
		confirmado = false,
	},
	PortaCarro = {
		ids = ids({ 139882610901041, 121381393291287 }),
		volume = 0.8,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (jian5eva, axtrull)",
		confirmado = false,
	},

	-- Monstros
	GritoMonstro = {
		ids = ids({ 120080200131565, 126129882321098 }),
		volume = 1,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "Creator Store",
		confirmado = false,
	},
	RosnadoMonstro = {
		ids = ids({ 73132281873037, 9114628818, 92131465156643 }),
		volume = 0.7,
		variacao = 0.12,
		grupo = "Efeitos",
		origem = "Creator Store / ProSoundEffects",
		confirmado = false,
	},

	-- Monstros novos (docs/monstros/logica.md §9). Enviados pela Open Cloud (ferramentas/som); origem e licença em docs/creditos.md.
	-- Sem ids = Sons.tocar ignora com aviso (uma vez). Sons de jogo reaproveitam ids do catálogo quando serviam.
	PulsoChao = {
		ids = monstro("PulsoChao"),
		volume = 0.8,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "sintético (ffmpeg, ferramentas/som/gerar_sons.py)",
		confirmado = false,
	},
	GritoAbafado = {
		ids = monstro("GritoAbafado"),
		volume = 1,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "sintético (ffmpeg): serra com vibrato + passa-baixa forte, sem boca; provisório, ninguém ouviu",
		confirmado = false,
	},
	SonarOnda = {
		ids = monstro("SonarOnda"),
		volume = 0.7,
		variacao = 0,
		grupo = "Efeitos",
		origem = "sintético (ffmpeg)",
		confirmado = false,
	},
	SonarDetectado = {
		ids = monstro("SonarDetectado"),
		volume = 0.8,
		variacao = 0,
		grupo = "UI",
		origem = "sintético (ffmpeg)",
		confirmado = false,
	},
	SonarPassou = {
		ids = monstro("SonarPassou"),
		volume = 0.6,
		variacao = 0,
		grupo = "UI",
		origem = "sintético (ffmpeg)",
		confirmado = false,
	},
	Empurrao = {
		ids = ids({ 127713737439439, 97094698098374 }),
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "Creator Store (reuso de AcertoCarne)",
		confirmado = false,
	},
	PortaAbrir = {
		ids = ids({ 9120829478, 85624114152325 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "ProSoundEffects / No0ne80412 (reuso de Porta)",
		confirmado = false,
	},
	PortaFechar = {
		ids = ids({ 9120829478, 85624114152325 }),
		volume = 0.7,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "ProSoundEffects / No0ne80412 (reuso de Porta)",
		confirmado = false,
	},
	PortaBater = {
		ids = ids({ 9120829478, 85624114152325 }),
		volume = 1,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "ProSoundEffects / No0ne80412 (reuso de Porta, mais alto; trocar por batida seca se soar fraco)",
		confirmado = false,
	},
	RasparLaminas = {
		ids = monstro("RasparLaminas"),
		volume = 0.7,
		variacao = 0.03,
		grupo = "Efeitos",
		loop = true,
		origem = "sintético (ffmpeg), laço de 2 s",
		confirmado = false,
	},
	LaminaLancada = {
		ids = ids({ 108598690388763, 120847059990228 }),
		volume = 0.7,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "Creator Store (reuso de Balanco)",
		confirmado = false,
	},
	LaminaImpacto = {
		ids = ids({ 9125740081, 9116653976 }),
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "ProSoundEffects (reuso de AcertoMetal)",
		confirmado = false,
	},
	LaminaAparar = {
		ids = ids({ 9125740081, 9116653976 }),
		volume = 0.9,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "ProSoundEffects (reuso de AcertoMetal)",
		confirmado = false,
	},
	RugidoChao = {
		ids = ids({ 120080200131565, 126129882321098 }),
		volume = 1,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "Creator Store (reuso de GritoMonstro; trocar por rugido grave próprio se soar agudo)",
		confirmado = false,
	},
	CaudaGolpe = {
		ids = ids({ 112611832797358, 9119746108 }),
		volume = 0.8,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "Creator Store / ProSoundEffects (reuso de BalancoPesado)",
		confirmado = false,
	},
	FlorEstalo = {
		ids = monstro("FlorEstalo"),
		volume = 0.8,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "sintético (ffmpeg)",
		confirmado = false,
	},
	FlorPlantar = {
		ids = monstro("FlorPlantar"),
		volume = 0.7,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "sintético (ffmpeg)",
		confirmado = false,
	},
	-- Falas do Corcunda (§5.5): "VozCorcunda" sorteia uma; "VozCorcunda_n" toca a n. nomes lista os nomes lógicos.
	-- Origem: Kenney "Voiceover Pack #1" (CC0, voz de Jeffrey M. Smith), tratada (pitch -8%, passa-baixa 3,5 kHz, bitcrush).
	VozCorcunda = {
		ids = falasCorcunda,
		nomes = {
			"VozCorcunda_1",
			"VozCorcunda_2",
			"VozCorcunda_3",
			"VozCorcunda_4",
			"VozCorcunda_5",
			"VozCorcunda_6",
			"VozCorcunda_7",
			"VozCorcunda_8",
			"VozCorcunda_9",
			"VozCorcunda_10",
		},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_1 = {
		ids = if falasCorcunda[1] then { falasCorcunda[1] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_2 = {
		ids = if falasCorcunda[2] then { falasCorcunda[2] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_3 = {
		ids = if falasCorcunda[3] then { falasCorcunda[3] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_4 = {
		ids = if falasCorcunda[4] then { falasCorcunda[4] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_5 = {
		ids = if falasCorcunda[5] then { falasCorcunda[5] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_6 = {
		ids = if falasCorcunda[6] then { falasCorcunda[6] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_7 = {
		ids = if falasCorcunda[7] then { falasCorcunda[7] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_8 = {
		ids = if falasCorcunda[8] then { falasCorcunda[8] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_9 = {
		ids = if falasCorcunda[9] then { falasCorcunda[9] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},
	VozCorcunda_10 = {
		ids = if falasCorcunda[10] then { falasCorcunda[10] } else {},
		volume = 0.9,
		variacao = 0.03,
		grupo = "Voz",
		origem = "Kenney Voiceover Pack #1 (CC0)",
		confirmado = false,
	},

	-- Jogador
	Dor = {
		ids = ids({ 9120417632, 132677043446218 }),
		volume = 0.8,
		variacao = 0.05,
		grupo = "Voz",
		origem = "ProSoundEffects / jevilfor",
		confirmado = false,
	},
	Coracao = {
		ids = ids({ 6202853067 }),
		volume = 0.6,
		variacao = 0,
		grupo = "Efeitos",
		loop = true,
		origem = "Screaming_Monkeys",
		confirmado = false,
	},

	-- Ambiente (loops locais no cliente)
	AmbienteNoite = {
		ids = novoOuAntigo(existentes(PSX.ambiente.Still, PSX.ambiente.Distant, PSX.ambiente.Veil), { 9114244841 }),
		volume = 0.3,
		variacao = 0,
		grupo = "Ambiente",
		loop = true,
		origem = "PSX Ambient Pack (Still, Distant, Veil; Ambience by CAPTNPHANTOM); antigo: ProSoundEffects",
		confirmado = false,
	},
	AmbienteDia = {
		ids = novoOuAntigo(existentes(PSX.ambiente.Hollow, PSX.ambiente.Blur, PSX.ambiente.Faded), { 9114244841 }),
		volume = 0.22,
		variacao = 0,
		grupo = "Ambiente",
		loop = true,
		origem = "PSX Ambient Pack (Hollow, Blur, Faded; Ambience by CAPTNPHANTOM); antigo: ProSoundEffects",
		confirmado = false,
	},
	AmbienteChuva = {
		ids = ids({ 5911952995, 7127218501 }),
		volume = 0.6,
		variacao = 0,
		grupo = "Ambiente",
		loop = true,
		origem = "Creator Store (F_ergy, j_rahf)",
		confirmado = false,
	},

	-- Combustível (docs/combustivel.md): sons provisórios reaproveitando ids de outras entradas, sem áudio novo.
	Abastecendo = {
		ids = ids({ 9117940837 }), -- ids de PassoAgua
		volume = 0.5,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "ProSoundEffects (provisório: reaproveita PassoAgua)",
		confirmado = false,
	},
	MangueiraEncaixa = {
		ids = ids({ 139882610901041, 121381393291287 }), -- ids de PortaCarro
		volume = 0.8,
		variacao = 0.04,
		grupo = "Efeitos",
		origem = "Creator Store (jian5eva, axtrull) (provisório: reaproveita PortaCarro)",
		confirmado = false,
	},
	MangueiraSolta = {
		ids = passoMetal, -- mesma lista de PassoMetal
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (Diman_x86 'CSGO', zhernoseki12 'SCP' CC BY-SA), ProSoundEffects (provisório: reaproveita PassoMetal)",
		confirmado = false,
	},
	Despejar = {
		ids = ids({ 9117940837 }), -- ids de PassoAgua
		volume = 0.5,
		variacao = 0.1,
		grupo = "Efeitos",
		origem = "ProSoundEffects (provisório: reaproveita PassoAgua)",
		confirmado = false,
	},

	-- Som v2 (docs/som.md §5, §13): AINDA SEM ID (lista vazia). Sons.tocar avisa uma vez e segue. Ver docs/pendencias-integracao.md "Som v2".
	PassoVidro = {
		ids = {}, -- sem áudio ainda: passo em piso de vidro
		volume = 0.6,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoVidro = {
		ids = {}, -- sem áudio ainda: pisar em vidro quebrado
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoLata = {
		ids = {}, -- sem áudio ainda: chutar uma lata
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoLataRolar = {
		ids = {}, -- sem áudio ainda: lata rolando
		volume = 0.6,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoGarrafa = {
		ids = {}, -- sem áudio ainda: garrafa quebrando
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoFolhas = {
		ids = {}, -- sem áudio ainda: folhas secas
		volume = 0.7,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoGalho = {
		ids = {}, -- sem áudio ainda: galho quebrando
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoEntulho = {
		ids = {}, -- sem áudio ainda: entulho rangendo
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	DetritoTabua = {
		ids = {}, -- sem áudio ainda: tábua solta do assoalho rangendo
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarMadeira = {
		ids = {}, -- sem áudio ainda: esbarrar em móvel de madeira
		volume = 0.8,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarMetal = {
		ids = {}, -- sem áudio ainda: esbarrar em móvel de metal
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarVidro = {
		ids = {}, -- sem áudio ainda: esbarrar em vitrine ou vidro
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarEstofado = {
		ids = {}, -- sem áudio ainda: esbarrar em estofado
		volume = 0.5,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarPiano = {
		ids = {}, -- sem áudio ainda: esbarrar em piano
		volume = 1,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	EsbarrarVeiculo = {
		ids = {}, -- sem áudio ainda: esbarrar em carro abandonado
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	Arfar = {
		ids = {}, -- sem áudio ainda: arfar alto (errou o minigame de segurar a respiração)
		volume = 0.9,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},
	SoltarAr = {
		ids = {}, -- sem áudio ainda: soltar o ar (fôlego acabou)
		volume = 0.5,
		variacao = 0.06,
		grupo = "Efeitos",
		origem = "pendente (Som v2)",
		confirmado = false,
	},

	-- UI
	Clique = {
		ids = ids({ 88442833509532 }),
		volume = 0.5,
		variacao = 0,
		grupo = "UI",
		origem = "AmbientSorcery",
		confirmado = false,
	},
}
