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

return {
	-- Passos (um por superfície de Config/Som.superficies). pitch varia ±variacao.
	PassoConcreto = {
		ids = ids({ 87061775498714, 120195545352847, 108290664490396, 106961831442199, 112000835797556 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (IDogeffI, Diman_x86)",
		confirmado = false,
	},
	PassoGramaBaixa = {
		ids = ids({ 129956418693357, 78534941650081, 110522236020035, 135037154891351 }),
		volume = 0.5,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (Robloxmastermanyay)",
		confirmado = false,
	},
	PassoGramaAlta = {
		ids = ids({ 9114518386, 114626769792529 }),
		volume = 0.6,
		variacao = 0.08,
		grupo = "Efeitos",
		origem = "ProSoundEffects / levka_321",
		confirmado = false,
	},
	PassoMadeira = {
		ids = ids({ 92705710431057, 140525304232464 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (Robloxmastermanyay, Diman_x86 'CSGO')",
		confirmado = false,
	},
	PassoCarpete = {
		ids = ids({ 91882016473062, 111131620367547, 73343053773763, 123224557798023 }),
		volume = 0.4,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (iLoveSwiss_0)",
		confirmado = false,
	},
	PassoCascalho = {
		ids = ids({ 71307609262509, 104596932601069, 132387836053582 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (Diman_x86)",
		confirmado = false,
	},
	PassoMetal = {
		ids = ids({ 140728903346385, 139723537411614, 135890657963973, 9125818616 }),
		volume = 0.6,
		variacao = 0.05,
		grupo = "Efeitos",
		origem = "Creator Store (Diman_x86 'CSGO', zhernoseki12 'SCP' CC BY-SA), ProSoundEffects",
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
		ids = ids({ 9114244841 }),
		volume = 0.35,
		variacao = 0,
		grupo = "Ambiente",
		loop = true,
		origem = "ProSoundEffects",
		confirmado = false,
	},
	AmbienteDia = {
		ids = ids({ 9114244841 }),
		volume = 0.15,
		variacao = 0,
		grupo = "Ambiente",
		loop = true,
		origem = "ProSoundEffects",
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
		ids = ids({ 140728903346385, 139723537411614, 135890657963973, 9125818616 }), -- ids de PassoMetal
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
