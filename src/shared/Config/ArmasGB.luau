-- Viewmodel do Gold Bright (braços + arma animados em 1ª pessoa). Contrato: docs/gold-bright-import.md.
-- GERADO por ferramentas/goldbright/gerar_config_gb.py (enviados.json + dados extraídos). Não editar à mão.
-- Assets do Gold Bright: GPLv3+ (aceito pelo usuário em 2026-11-15). Sem `modelo` a arma usa o viewmodel de blocos.
return {
	armas = {
		tt33 = {
			grupo = "TT33",
			modelo = 78655628830409, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://75493382053743",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.09685, 1.00409, 1.35868, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.18233, 0.47639, -1.48586 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.97724, 3.02449, 1.15456 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -0.5816, -1.5994 },
				mira = { -0.37513, -0.31116, -1.42492 },
				rotMira = { 1.3, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 0.49727, 1.10213 },
				malhaNaRaiz = { 0.19395, -0.77436, -0.86141 },
				coiceRotQuadril = { 35.0, 10.0, 2.0 },
				coicePosQuadril = { 0.0, 0.5816, 1.3086 },
				coiceRotMira = { 35.0, 10.0, 2.0 },
				coicePosMira = { 0.0, 0.5816, 1.3086 },
				corrida = { pos = { 0.0, -0.1454, 0.2908 }, rot = { 60.0, 10.0, 20.0 } },
				naoAtira = { pos = { 0.0, 0.0, 0.17448 }, rot = { 30.0, -5.0, 25.0 } },
				velMira = 8.0,
				velRecuoPos = 18.0,
				velRecuoRot = 32.0,
				voltaPos = 7.2,
				voltaRot = 12.8,
				swayPos = 1.0,
				swayRot = 1.0,
				profundidade = 1.772,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = {
					{ id = "rbxassetid://92965606465833", dur = 0.8667, loop = false },
					{ id = "rbxassetid://90379509999159", dur = 0.8667, loop = false },
				}, -- TT33_Hands_Mag, TT33_Self_Mag
				["Check Ammo Close"] = {
					{ id = "rbxassetid://92965606465833", dur = 0.8667, loop = false },
					{ id = "rbxassetid://90379509999159", dur = 0.8667, loop = false },
				}, -- TT33_Hands_Mag, TT33_Self_Mag
				["Check Ammo Empty"] = {
					{ id = "rbxassetid://92965606465833", dur = 0.8667, loop = false },
					{ id = "rbxassetid://106768890332545", dur = 0.8667, loop = false },
				}, -- TT33_Hands_Mag, TT33_Self_Mag_Empty
				["Check Ammo Empty Close"] = {
					{ id = "rbxassetid://92965606465833", dur = 0.8667, loop = false },
					{ id = "rbxassetid://106768890332545", dur = 0.8667, loop = false },
				}, -- TT33_Hands_Mag, TT33_Self_Mag_Empty
				["Closed Bolt"] = {
					{ id = "rbxassetid://88921427168191", dur = 0.1, loop = true },
					{ id = "rbxassetid://95856774213740", dur = 0.1, loop = false },
				}, -- TT33_Hands_Ref, TT33_Self_Idle
				["Cock"] = {
					{ id = "rbxassetid://137868423842401", dur = 0.9, loop = false },
					{ id = "rbxassetid://127825215264817", dur = 0.8, loop = false },
				}, -- TT33_Reload_Hands_4, TT33_Reload_Self_Cock
				["Draw"] = {
					{ id = "rbxassetid://118444576558268", dur = 0.9667, loop = false },
					{ id = "rbxassetid://95856774213740", dur = 0.1, loop = false },
				}, -- TT33_Draw, TT33_Self_Idle
				["Empty - Uncocked"] = {
					{ id = "rbxassetid://112762575028582", dur = 1.9667, loop = true },
					{ id = "rbxassetid://122914310204106", dur = 0.1, loop = false },
				}, -- TT33_Hands_Idle, TT33_Empty
				["Fire"] = {
					{ id = "rbxassetid://88921427168191", dur = 0.1, loop = true },
					{ id = "rbxassetid://76802339139812", dur = 0.1667, loop = false },
				}, -- TT33_Hands_Ref, TT33_Self_Fire
				["Holster"] = {
					{ id = "rbxassetid://134942914422361", dur = 0.9667, loop = false },
					{ id = "rbxassetid://95856774213740", dur = 0.1, loop = false },
				}, -- TT33_Holster, TT33_Self_Idle
				["Idle"] = {
					{ id = "rbxassetid://112762575028582", dur = 1.9667, loop = true },
					{ id = "rbxassetid://95856774213740", dur = 0.1, loop = false },
				}, -- TT33_Hands_Idle, TT33_Self_Idle
				["Open Bolt"] = {
					{ id = "rbxassetid://88921427168191", dur = 0.1, loop = true },
					{ id = "rbxassetid://122914310204106", dur = 0.1, loop = false },
				}, -- TT33_Hands_Ref, TT33_Empty
				["Reload Phase 1"] = {
					{ id = "rbxassetid://104259021428059", dur = 0.9667, loop = false },
					{ id = "rbxassetid://92388985143453", dur = 0.9667, loop = false },
				}, -- TT33_Reload_Hands_1, TT33_Reload_Self_1
				["Reload Phase 1 - Empty"] = {
					{ id = "rbxassetid://104259021428059", dur = 0.9667, loop = false },
					{ id = "rbxassetid://97606139361428", dur = 0.9667, loop = false },
				}, -- TT33_Reload_Hands_1, TT33_Reload_Self_1_Empty
				["Reload Phase 2"] = {
					{ id = "rbxassetid://70834996493770", dur = 1.1333, loop = false },
					{ id = "rbxassetid://117390205095336", dur = 1.1667, loop = false },
				}, -- TT33_Reload_Hands_2, TT33_Reload_Self_2
				["Reload Phase 2 - Empty"] = {
					{ id = "rbxassetid://70834996493770", dur = 1.1333, loop = false },
					{ id = "rbxassetid://122086794672609", dur = 1.1667, loop = false },
				}, -- TT33_Reload_Hands_2, TT33_Reload_Self_2_Empty
				["Reload Phase 3"] = {
					{ id = "rbxassetid://118914228456515", dur = 1.5333, loop = false },
					{ id = "rbxassetid://137324082834267", dur = 1.5333, loop = false },
				}, -- TT33_Reload_Hands_3, TT33_Reload_Self_3
				["Reload Phase 3 - Empty"] = {
					{ id = "rbxassetid://118914228456515", dur = 1.5333, loop = false },
					{ id = "rbxassetid://86819296025735", dur = 1.5333, loop = false },
				}, -- TT33_Reload_Hands_3, TT33_Reload_Self_3_Empty
				["Scoped"] = {
					{ id = "rbxassetid://88921427168191", dur = 0.1, loop = true },
					{ id = "rbxassetid://95856774213740", dur = 0.1, loop = false },
				}, -- TT33_Hands_Ref, TT33_Self_Idle
			},
		},
		mp5 = {
			grupo = "MP5",
			modelo = 137369645260557, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://73962767091944",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.17035, 1.50717, 0.97899, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.13916, 0.71309, -1.01102 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.78685, 2.91332, 1.66986 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { -0.05816, -0.69792, -1.1632 },
				mira = { -0.39113, -0.4711, -0.5816 },
				rotMira = { -0.0, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { -0.0, 0.71828, 0.79679 },
				malhaNaRaiz = { 0.17035, -1.06225, -1.19418 },
				coiceRotQuadril = { 10.0, 2.0, 0.3 },
				coicePosQuadril = { 0.0, 0.23264, 0.5089 },
				coiceRotMira = { 4.0, 2.0, 2.0 },
				coicePosMira = { 0.0, 0.05816, 0.23264 },
				corrida = { pos = { 0.0, -0.2908, 0.4362 }, rot = { -15.0, 35.0, 7.0 } },
				naoAtira = { pos = { 0.0, 0.0, 0.17448 }, rot = { 30.0, -5.0, 25.0 } },
				velMira = 8.0,
				velRecuoPos = 18.0,
				velRecuoRot = 32.0,
				voltaPos = 7.2,
				voltaRot = 12.8,
				swayPos = 1.0,
				swayRot = 0.8,
				profundidade = 1.29918,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://73127622602223", dur = 1.1333, loop = false } }, -- MP5_Mag
				["Check Ammo Close"] = { { id = "rbxassetid://73127622602223", dur = 1.1333, loop = false } }, -- MP5_Mag
				["Check Ammo Empty"] = { { id = "rbxassetid://73127622602223", dur = 1.1333, loop = false } }, -- MP5_Mag
				["Check Ammo Empty Close"] = { { id = "rbxassetid://73127622602223", dur = 1.1333, loop = false } }, -- MP5_Mag
				["Closed Bolt"] = { { id = "rbxassetid://97283574878742", dur = 0.1, loop = true } }, -- MP5_Ref
				["Cock"] = { { id = "rbxassetid://73912790161238", dur = 0.9667, loop = false } }, -- MP5_Cock
				["Draw"] = { { id = "rbxassetid://90685320898821", dur = 0.9667, loop = false } }, -- MP5_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://97283574878742", dur = 0.1, loop = true } }, -- MP5_Ref
				["Fire"] = { { id = "rbxassetid://97283574878742", dur = 0.1, loop = true } }, -- MP5_Ref
				["Holster"] = { { id = "rbxassetid://81400315376183", dur = 0.9667, loop = false } }, -- MP5_Holster
				["Idle"] = { { id = "rbxassetid://116609406623299", dur = 2.4667, loop = true } }, -- MP5_Idle
				["Open Bolt"] = { { id = "rbxassetid://97283574878742", dur = 0.1, loop = true } }, -- MP5_Ref
				["Reload Phase 1"] = { { id = "rbxassetid://134165732101825", dur = 1.4667, loop = false } }, -- MP5_Reload_Tactical_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://78604760277899", dur = 2.2333, loop = false } }, -- MP5_Reload_1
				["Reload Phase 2"] = { { id = "rbxassetid://125576392176207", dur = 1.6667, loop = false } }, -- MP5_Reload_Tactical_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://114163054154849", dur = 1.0667, loop = false } }, -- MP5_Reload_2
				["Reload Phase 3"] = { { id = "rbxassetid://82822363352099", dur = 1.3333, loop = false } }, -- MP5_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://82822363352099", dur = 1.3333, loop = false } }, -- MP5_Reload_3
				["Scoped"] = { { id = "rbxassetid://97283574878742", dur = 0.1, loop = true } }, -- MP5_Ref
			},
		},
		pp91 = {
			grupo = "PP91",
			modelo = 88653861801964, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://105030497737218",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.16911, 1.10529, 1.56631, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.26221, 0.57812, -1.37991 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.71842, 2.76292, 1.46799 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.2908, -1.13412, -1.68664 },
				mira = { -0.0916, -0.93347, -0.98872 },
				rotMira = { -0.0, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { -0.30243, 1.2737, 1.38712 },
				malhaNaRaiz = { 0.13332, -1.07039, -1.15046 },
				coiceRotQuadril = { 10.0, 2.0, 0.3 },
				coicePosQuadril = { 0.0, 0.02908, 0.05816 },
				coiceRotMira = { 5.0, 2.0, 2.0 },
				coicePosMira = { 0.0, 0.00582, 0.00582 },
				corrida = { pos = { 0.2908, 0.0, 0.1454 }, rot = { 35.0, -0.0, 15.0 } },
				naoAtira = { pos = { 0.2908, 0.0, 0.1454 }, rot = { 25.0, -0.0, 10.0 } },
				velMira = 8.0,
				velRecuoPos = 18.0,
				velRecuoRot = 32.0,
				voltaPos = 7.2,
				voltaRot = 12.8,
				swayPos = 0.6,
				swayRot = 0.8,
				profundidade = 1.48827,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://76809702868201", dur = 0.9667, loop = false } }, -- PP_91_Mag_Check
				["Check Ammo Close"] = { { id = "rbxassetid://76809702868201", dur = 0.9667, loop = false } }, -- PP_91_Mag_Check
				["Check Ammo Empty"] = { { id = "rbxassetid://76809702868201", dur = 0.9667, loop = false } }, -- PP_91_Mag_Check
				["Check Ammo Empty Close"] = { { id = "rbxassetid://76809702868201", dur = 0.9667, loop = false } }, -- PP_91_Mag_Check
				["Closed Bolt"] = { { id = "rbxassetid://92643175635941", dur = 0.1, loop = true } }, -- PP_91_Closed_Bolt
				["Cock"] = { { id = "rbxassetid://102518732871814", dur = 1.4667, loop = false } }, -- PP_91_Cock
				["Draw"] = { { id = "rbxassetid://73168392648172", dur = 1.4667, loop = false } }, -- PP_91_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://140438212254279", dur = 0.1, loop = false } }, -- PP_91_Empty
				["Fire"] = { { id = "rbxassetid://96511318453959", dur = 0.1, loop = true } }, -- PP_91_Fire
				["Holster"] = { { id = "rbxassetid://117018304163697", dur = 1.4667, loop = false } }, -- PP_91_Holster
				["Idle"] = { { id = "rbxassetid://79416538307080", dur = 2.4667, loop = true } }, -- PP_91_Idle
				["Open Bolt"] = { { id = "rbxassetid://128339914590493", dur = 0.1, loop = false } }, -- PP_91_Open_Bolt
				["Reload Phase 1"] = { { id = "rbxassetid://117477096546795", dur = 1.0333, loop = false } }, -- PP_91_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://76963412120035", dur = 3.4667, loop = false } }, -- PP_91_Reload_1_1
				["Reload Phase 2"] = { { id = "rbxassetid://98288780772829", dur = 1.1, loop = false } }, -- PP_91_Reload_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://80081155945883", dur = 1.1, loop = false } }, -- PP_91_Reload_2_1
				["Reload Phase 3"] = { { id = "rbxassetid://100604580321966", dur = 1.3333, loop = false } }, -- PP_91_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://95104950624385", dur = 1.3333, loop = false } }, -- PP_91_Reload_3_1
				["Scoped"] = { { id = "rbxassetid://109255455948821", dur = 0.1, loop = true } }, -- PP_91_Scoped
			},
		},
		ots20 = {
			grupo = "OTS20",
			modelo = 90847684283573, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://87028954258860",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.20879, 0.87752, 1.30597, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.18175, 0.50539, -1.31713 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.85321, 3.74062, 1.28787 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -0.78516, -1.8902 },
				mira = { -0.39113, -0.55252, -2.0356 },
				rotMira = { 0.5, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 0.87822, 1.42783 },
				malhaNaRaiz = { 0.20879, -0.97057, -0.8436 },
				coiceRotQuadril = { 45.0, 10.0, 2.0 },
				coicePosQuadril = { 0.0, 0.8724, 1.3086 },
				coiceRotMira = { 45.0, 10.0, 2.0 },
				coicePosMira = { 0.0, 0.8724, 1.3086 },
				corrida = { pos = { 0.1454, 0.2908, -0.2908 }, rot = { 60.0, 10.0, 10.0 } },
				naoAtira = { pos = { 0.0, 0.0, 0.17448 }, rot = { 30.0, -5.0, 25.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 8.0,
				swayPos = 1.0,
				swayRot = 1.0,
				profundidade = 1.65132,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://127822673607125", dur = 0.9667, loop = false } }, -- OTs_20_Mag_Open
				["Check Ammo Close"] = { { id = "rbxassetid://124633690385876", dur = 0.9667, loop = false } }, -- OTs_20_Mag_Close
				["Check Ammo Empty"] = { { id = "rbxassetid://127822673607125", dur = 0.9667, loop = false } }, -- OTs_20_Mag_Open
				["Check Ammo Empty Close"] = { { id = "rbxassetid://124633690385876", dur = 0.9667, loop = false } }, -- OTs_20_Mag_Close
				["Closed Bolt"] = { { id = "rbxassetid://114310970915270", dur = 0.0333, loop = true } }, -- OTs_20_Cocked
				["Cock"] = { { id = "rbxassetid://120028707725734", dur = 0.6333, loop = false } }, -- OTs_20_Cock
				["Draw"] = { { id = "rbxassetid://87534801686289", dur = 0.9667, loop = false } }, -- OTs_20_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://78663722205518", dur = 0.0333, loop = true } }, -- OTs_20_Uncocked
				["Fire"] = { { id = "rbxassetid://91257249182841", dur = 0.0667, loop = false } }, -- OTs_20_Fire
				["Holster"] = { { id = "rbxassetid://98476877396813", dur = 0.9667, loop = false } }, -- OTs_20_Holster
				["Idle"] = { { id = "rbxassetid://102277892419945", dur = 1.9667, loop = true } }, -- OTs_20_Idle
				["Open Bolt"] = { { id = "rbxassetid://78663722205518", dur = 0.0333, loop = true } }, -- OTs_20_Uncocked
				["Reload Phase 1"] = { { id = "rbxassetid://119640596997253", dur = 1.3, loop = false } }, -- OTs_20_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://119640596997253", dur = 1.3, loop = false } }, -- OTs_20_Reload_1
				["Reload Phase 2"] = { { id = "rbxassetid://113273152886815", dur = 1.3333, loop = false } }, -- OTs_20_Reload_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://113273152886815", dur = 1.3333, loop = false } }, -- OTs_20_Reload_2
				["Reload Phase 3"] = { { id = "rbxassetid://140583531494519", dur = 1.0, loop = false } }, -- OTs_20_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://140583531494519", dur = 1.0, loop = false } }, -- OTs_20_Reload_3
				["Scoped"] = { { id = "rbxassetid://136942702337193", dur = 1.9667, loop = true } }, -- OTs_20_Scoped
			},
		},
		ots48k = {
			grupo = "OTS48K",
			modelo = 95759759703918, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://89603276973192",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.53296, 0.60041, 1.22037, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { -0.16771, 0.25506, -2.63199 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.00225, 5.264, 1.18597 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -1.22136, -1.5994 },
				mira = { -0.3635, -1.05997, -0.90148 },
				rotMira = { -0.0, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 1.1632, 1.3086 },
				malhaNaRaiz = { 0.53296, -0.60041, -1.48209 },
				coiceRotQuadril = { 20.0, 8.0, 2.0 },
				coicePosQuadril = { 0.0, 0.2908, 0.4362 },
				coiceRotMira = { 15.0, 4.0, 2.0 },
				coicePosMira = { 0.0, 0.0727, 0.0 },
				corrida = { pos = { 0.0, 0.0, 0.2908 }, rot = { 10.0, 25.0, 30.0 } },
				naoAtira = { pos = { 0.2908, 0.0, 0.17448 }, rot = { 40.0, -5.0, 5.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 8.0,
				swayPos = 0.6,
				swayRot = 0.8,
				profundidade = 1.09244,
				escala = 2.908,
				luneta = true,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://94959048672654", dur = 1.8333, loop = false } }, -- OTs_48K_Mag_Check
				["Check Ammo Close"] = { { id = "rbxassetid://132841853465169", dur = 1.9667, loop = false } }, -- OTs_48K_Reload_1
				["Check Ammo Empty"] = { { id = "rbxassetid://94959048672654", dur = 1.8333, loop = false } }, -- OTs_48K_Mag_Check
				["Check Ammo Empty Close"] = { { id = "rbxassetid://132841853465169", dur = 1.9667, loop = false } }, -- OTs_48K_Reload_1
				["Cock"] = { { id = "rbxassetid://103182033741367", dur = 1.1333, loop = false } }, -- OTs_48K_Cock
				["Draw"] = { { id = "rbxassetid://72342373686409", dur = 0.9667, loop = false } }, -- OTs_48K_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://84529801684294", dur = 1.9667, loop = true } }, -- OTs_48K_Idle
				["Holster"] = { { id = "rbxassetid://95837442687782", dur = 0.9667, loop = false } }, -- OTs_48K_Holster
				["Idle"] = { { id = "rbxassetid://84529801684294", dur = 1.9667, loop = true } }, -- OTs_48K_Idle
				["Reload Phase 1"] = { { id = "rbxassetid://132841853465169", dur = 1.9667, loop = false } }, -- OTs_48K_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://132841853465169", dur = 1.9667, loop = false } }, -- OTs_48K_Reload_1
				["Reload Phase 2"] = { { id = "rbxassetid://74386461766155", dur = 0.8, loop = false } }, -- OTs_48K_Reload_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://74386461766155", dur = 0.8, loop = false } }, -- OTs_48K_Reload_2
				["Reload Phase 3"] = { { id = "rbxassetid://121318922355533", dur = 2.0, loop = false } }, -- OTs_48K_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://121318922355533", dur = 2.0, loop = false } }, -- OTs_48K_Reload_3
				["Scoped"] = { { id = "rbxassetid://78556568486874", dur = 0.0333, loop = false } }, -- OTs_48K_Ref
			},
		},
		rmb93 = {
			grupo = "RMB93",
			modelo = 113568348098853, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://122451398469177",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.40997, 1.01431, 1.93087, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { -0.01717, 0.39919, -2.42201 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.03976, 4.8479, 1.20275 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -1.22136, -1.65756 },
				mira = { -0.39258, -0.90439, -1.5994 },
				rotMira = { -0.0, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 1.1632, 1.0178 },
				malhaNaRaiz = { 0.40997, -0.86891, -1.14571 },
				coiceRotQuadril = { 20.0, 5.0, 10.0 },
				coicePosQuadril = { 0.0, 0.2908, 0.4362 },
				coiceRotMira = { 15.0, 1.0, 5.0 },
				coicePosMira = { 0.0, 0.0727, 0.0 },
				corrida = { pos = { 0.5816, 0.0, -0.2908 }, rot = { 50.0, -5.0, 15.0 } },
				naoAtira = { pos = { -0.2908, -0.1454, 0.2908 }, rot = { 10.0, 40.0, 30.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 12.0,
				swayPos = 0.6,
				swayRot = 0.8,
				profundidade = 0.68664,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://87689981808195", dur = 1.5, loop = false } }, -- RMB_93_Mag_Open
				["Check Ammo Close"] = { { id = "rbxassetid://84131488887100", dur = 1.5, loop = false } }, -- RMB_93_Mag_Close
				["Check Ammo Empty"] = { { id = "rbxassetid://87689981808195", dur = 1.5, loop = false } }, -- RMB_93_Mag_Open
				["Check Ammo Empty Close"] = { { id = "rbxassetid://84131488887100", dur = 1.5, loop = false } }, -- RMB_93_Mag_Close
				["Cock"] = { { id = "rbxassetid://103309594477918", dur = 1.2, loop = false } }, -- RMB_93_Cock
				["Draw"] = { { id = "rbxassetid://138633176848112", dur = 1.6333, loop = false } }, -- RMB_93_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://96031467224624", dur = 0.0333, loop = false } }, -- RMB_93_Ref
				["Fire"] = { { id = "rbxassetid://96031467224624", dur = 0.0333, loop = false } }, -- RMB_93_Ref
				["Holster"] = { { id = "rbxassetid://95700039624202", dur = 1.6333, loop = false } }, -- RMB_93_Holster
				["Idle"] = { { id = "rbxassetid://115644455664396", dur = 1.9667, loop = true } }, -- RMB_93_Idle
				["Reload Phase 1"] = { { id = "rbxassetid://107060953901203", dur = 1.7, loop = false } }, -- RMB_93_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://107060953901203", dur = 1.7, loop = false } }, -- RMB_93_Reload_1
				["Reload Phase 2"] = { { id = "rbxassetid://128500408026946", dur = 1.0, loop = false } }, -- RMB_93_Reload_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://128500408026946", dur = 1.0, loop = false } }, -- RMB_93_Reload_2
				["Reload Phase 3"] = { { id = "rbxassetid://121840115480046", dur = 2.0, loop = false } }, -- RMB_93_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://121840115480046", dur = 2.0, loop = false } }, -- RMB_93_Reload_3
				["Scoped"] = { { id = "rbxassetid://96031467224624", dur = 0.0333, loop = false } }, -- RMB_93_Ref
			},
		},
		sr3m = {
			grupo = "SR3M",
			modelo = 124260588276620, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://97118415161736",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.41549, 0.75534, 1.35837, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -0.0, 0.0, 1.0 },
			boca = { 0.0539, 0.39151, -1.69409 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.76472, 3.38866, 1.56666 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { -0.20356, -0.78516, -1.454 },
				mira = { -0.46964, -0.64703, -1.5994 },
				rotMira = { 0.5, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 0.86077, 1.12249 },
				malhaNaRaiz = { 0.4155, -0.83095, -0.59066 },
				coiceRotQuadril = { 5.0, 0.75, 0.3 },
				coicePosQuadril = { 0.0, 0.05816, 0.08724 },
				coiceRotMira = { 2.5, 0.75, 2.0 },
				coicePosMira = { 0.0, 0.01163, 0.01454 },
				corrida = { pos = { -0.1454, -0.1454, 0.2908 }, rot = { 15.0, 30.0, 30.0 } },
				naoAtira = { pos = { 0.0, -0.1454, -0.0 }, rot = { 15.0, -0.0, 30.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 8.0,
				swayPos = 1.0,
				swayRot = 1.0,
				profundidade = 0.60928,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://106638141826936", dur = 0.9667, loop = false } }, -- SR_3M_Mag_Check_Out
				["Check Ammo Close"] = { { id = "rbxassetid://112900511239739", dur = 0.9667, loop = false } }, -- SR_3M_Mag_Check_In
				["Check Ammo Empty"] = { { id = "rbxassetid://106638141826936", dur = 0.9667, loop = false } }, -- SR_3M_Mag_Check_Out
				["Check Ammo Empty Close"] = { { id = "rbxassetid://112900511239739", dur = 0.9667, loop = false } }, -- SR_3M_Mag_Check_In
				["Closed Bolt"] = { { id = "rbxassetid://114381263723939", dur = 0.1, loop = false } }, -- SR_3M_Bolt_Closed
				["Cock"] = { { id = "rbxassetid://92475452617553", dur = 1.4667, loop = false } }, -- SR_3M_Cock
				["Draw"] = { { id = "rbxassetid://93213137082678", dur = 0.9667, loop = false } }, -- SR_3M_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://98432347231384", dur = 2.4667, loop = true } }, -- SR_3M_Idle
				["Fire"] = { { id = "rbxassetid://71404311784728", dur = 0.1, loop = true } }, -- SR_3M_Fire
				["Holster"] = { { id = "rbxassetid://77678739929472", dur = 0.9667, loop = false } }, -- SR_3M_Holster
				["Idle"] = { { id = "rbxassetid://98432347231384", dur = 2.4667, loop = true } }, -- SR_3M_Idle
				["Open Bolt"] = { { id = "rbxassetid://78078587419128", dur = 0.1, loop = false } }, -- SR_3M_Bolt_Open
				["Reload Phase 1"] = { { id = "rbxassetid://93157671028318", dur = 1.0667, loop = false } }, -- SR_3M_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://86378510836445", dur = 1.0667, loop = false } }, -- SR_3M_Reload_1_Empty
				["Reload Phase 2"] = { { id = "rbxassetid://128880243839991", dur = 0.8667, loop = false } }, -- SR_3M_Reload_2
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://76208728628004", dur = 0.9333, loop = false } }, -- SR_3M_Reload_2_Empty
				["Reload Phase 3"] = { { id = "rbxassetid://81224838168561", dur = 1.5, loop = false } }, -- SR_3M_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://104455514857595", dur = 1.8667, loop = false } }, -- SR_3M_Reload_3_Empty
				["Scoped"] = { { id = "rbxassetid://81765405471670", dur = 0.0333, loop = true } }, -- SR_3M_Ref
			},
		},
		toz34 = {
			grupo = "TOZ34",
			modelo = 81013887421024, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://97713131990463",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.27873, 0.79016, 1.57076, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.05367, 0.47354, -2.84994 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.10786, 5.70747, 1.14732 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -1.22136, -1.1632 },
				mira = { -0.31988, -0.95382, -1.22136 },
				rotMira = { 0.7, 0.1, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.0, 1.1632, 1.1632 },
				malhaNaRaiz = { 0.27873, -0.79016, -1.68708 },
				coiceRotQuadril = { 20.0, 5.0, 10.0 },
				coicePosQuadril = { 0.0, 0.34896, 1.04688 },
				coiceRotMira = { 15.0, 1.0, 5.0 },
				coicePosMira = { 0.0, 0.34896, 1.04688 },
				corrida = { pos = { 0.2908, -0.49436, -0.2908 }, rot = { 45.0, -9.0, 7.0 } },
				naoAtira = { pos = { 0.0, 0.0, 0.17448 }, rot = { 30.0, -5.0, 25.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 12.0,
				swayPos = 1.0,
				swayRot = 1.0,
				profundidade = 0.38457,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Check Ammo"] = { { id = "rbxassetid://137264602971850", dur = 1.1333, loop = false } }, -- TOZ34_Mag
				["Check Ammo Close"] = { { id = "rbxassetid://99869573066087", dur = 1.1333, loop = false } }, -- TOZ34_Mag_Close
				["Check Ammo Empty"] = { { id = "rbxassetid://137264602971850", dur = 1.1333, loop = false } }, -- TOZ34_Mag
				["Check Ammo Empty Close"] = { { id = "rbxassetid://99869573066087", dur = 1.1333, loop = false } }, -- TOZ34_Mag_Close
				["Cock"] = { { id = "rbxassetid://138468464938617", dur = 1.6, loop = false } }, -- TOZ34_Reload_3
				["Draw"] = { { id = "rbxassetid://139718598505261", dur = 0.9667, loop = false } }, -- TOZ34_Draw
				["Empty - Uncocked"] = { { id = "rbxassetid://76150867539342", dur = 1.9667, loop = true } }, -- TOZ34_Idle
				["Holster"] = { { id = "rbxassetid://115031928107344", dur = 0.9667, loop = false } }, -- TOZ34_Holster
				["Idle"] = { { id = "rbxassetid://76150867539342", dur = 1.9667, loop = true } }, -- TOZ34_Idle
				["Reload Phase 1"] = { { id = "rbxassetid://94598543608906", dur = 1.1333, loop = false } }, -- TOZ34_Reload_1
				["Reload Phase 1 - Empty"] = { { id = "rbxassetid://94598543608906", dur = 1.1333, loop = false } }, -- TOZ34_Reload_1
				["Reload Phase 2"] = { { id = "rbxassetid://121673955541502", dur = 1.1, loop = false } }, -- TOZ34_Reload_2_1
				["Reload Phase 2 - Empty"] = { { id = "rbxassetid://85851166643529", dur = 1.1, loop = false } }, -- TOZ34_Reload_2
				["Reload Phase 3"] = { { id = "rbxassetid://138468464938617", dur = 1.6, loop = false } }, -- TOZ34_Reload_3
				["Reload Phase 3 - Empty"] = { { id = "rbxassetid://138468464938617", dur = 1.6, loop = false } }, -- TOZ34_Reload_3
				["Scoped"] = { { id = "rbxassetid://138732382647719", dur = 0.0333, loop = true } }, -- TOZ34_Ref
			},
		},
		canoChumbo = {
			grupo = "CanoChumbo",
			modelo = 89156377326854, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://91157400566791",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.321, 0.29225, 1.14359, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.31128, 0.14953, -1.06992 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 1.90965, 2.14049, 2.31029 }, -- studs (x, z do Blender) só para conferência
			-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera).
			vista = {
				quadril = { 0.0, -1.3086, -1.7448 },
				mira = { -0.35332, -0.92184, -0.8724 },
				rotMira = { 1.3, -0.0, 0.0 },
				recoilPosition = { -0.0, 0.0, -0.0 },
				raiz = { 0.08724, 1.24829, 0.61359 },
				malhaNaRaiz = { 0.23376, -0.23194, -0.01237 },
				coiceRotQuadril = { 20.0, 5.0, 10.0 },
				coicePosQuadril = { 0.0, 0.2908, 0.4362 },
				coiceRotMira = { 15.0, 1.0, 5.0 },
				coicePosMira = { 0.0, 0.0727, 0.0 },
				corrida = { pos = { 0.0, 0.0, 0.1454 }, rot = { 18.0, -0.0, 0.0 } },
				naoAtira = { pos = { 0.2908, 0.0, 0.17448 }, rot = { 40.0, -5.0, 5.0 } },
				velMira = 8.0,
				velRecuoPos = 12.0,
				velRecuoRot = 24.0,
				voltaPos = 4.0,
				voltaRot = 12.0,
				swayPos = 0.6,
				swayRot = 0.8,
				profundidade = 1.77384,
				escala = 2.908,
				luneta = false,
			},
			fovOriginal = 55.0,
			estados = {
				["Draw"] = { { id = "rbxassetid://91600729327210", dur = 0.9667, loop = false } }, -- Lead_Pipe_Draw
				["Holster"] = { { id = "rbxassetid://117854433303302", dur = 0.9667, loop = false } }, -- Lead_Pipe_Holster
				["Idle"] = { { id = "rbxassetid://107139224398771", dur = 1.9667, loop = false } }, -- Lead_Pipe_Idle
				["Melee Attack"] = { { id = "rbxassetid://120680734068151", dur = 1.6333, loop = false } }, -- Lead_Pipe_Attack
				["Melee Attack Fast"] = { { id = "rbxassetid://78745396409311", dur = 1.1667, loop = false } }, -- Lead_Pipe_Attack_Fast
				["Melee Broken"] = { { id = "rbxassetid://104496912601927", dur = 1.6333, loop = false } }, -- Lead_Pipe_Broken
				["Melee Charge"] = { { id = "rbxassetid://113049323185147", dur = 1.1333, loop = false } }, -- Lead_Pipe_Ready
			},
		},
	},
	-- Comer/beber/remédio: enviados, ainda não ligados ao uso dos itens (estado "Pills" = o clipe do item).
	itens = {
		LataCarne = {
			grupo = "LataCarne",
			modelo = 136084799310310, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://132708906089660",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.20168, 1.69349, 0.53885, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.38741, -0.19843, -0.75057 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.76769, 1.67358, 1.4791 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://136343996779228", dur = 1.9667, loop = false } }, -- Food_Small_Can
			},
		},
		LataPeixe = {
			grupo = "LataPeixe",
			modelo = 125351098722945, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://123050782577311",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.20168, 1.69349, 0.53885, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.31972, -0.10326, -0.74139 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.76769, 1.67358, 1.4791 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://114826997884886", dur = 1.9667, loop = false } }, -- Food_Small_Can
			},
		},
		LeiteCondensado = {
			grupo = "LeiteCondensado",
			modelo = 75620293751662, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://113661339509579",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.20168, 1.69349, 0.53885, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.38741, -0.19843, -0.75057 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.76769, 1.67358, 1.4791 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://115386649325341", dur = 1.9667, loop = false } }, -- Food_Small_Can
			},
		},
		Comprimidos = {
			grupo = "Comprimidos",
			modelo = 133964370865471, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://115232445696376",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.11458, 1.39386, 0.64984, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { -0.60038, -0.50015, -0.96087 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 3.03758, 1.95002, 1.58344 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://90941880676928", dur = 2.4667, loop = false } }, -- Pills
			},
		},
		Morfina = {
			grupo = "Morfina",
			modelo = 95150052380006, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://131835535085946",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.11458, 1.4811, 0.2718, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { -0.60038, -0.50015, -0.96087 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 3.03758, 1.95002, 1.58344 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://72470376535171", dur = 1.9667, loop = false } }, -- Morphine_Main
			},
		},
		Vacina = {
			grupo = "Vacina",
			modelo = 99335292569943, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://70739280038878",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { -0.11458, 1.4811, 0.2718, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { -0.60038, -0.50015, -0.96087 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 3.03758, 1.95002, 1.58344 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://114771501541044", dur = 1.9667, loop = false } }, -- Morphine_Main
			},
		},
		Vodka = {
			grupo = "Vodka",
			modelo = 123519521321539, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://114951306000495",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.00395, 1.48465, 1.0903, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.36457, -0.01802, -0.44461 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.99989, 1.67995, 1.83986 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://70402049565811", dur = 1.9667, loop = false } }, -- Drink
			},
		},
		BatataCozida = {
			grupo = "BatataCozida",
			modelo = 77437662383930, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://122201809372131",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.20168, 1.69349, 0.53885, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.38742, -0.19842, -0.75057 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.76769, 1.67358, 1.4791 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://108889187429102", dur = 1.9667, loop = false } }, -- Food_Small_Can
			},
		},
		BatataCrua = {
			grupo = "BatataCrua",
			modelo = 122793466743767, -- Model (FBX); nil = ainda não enviado
			textura = "rbxassetid://77986669740403",
			-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()
			camera = { 0.20168, 1.69349, 0.53885, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 },
			boca = { 0.33179, -0.16226, -0.75366 }, -- ponta da arma no espaço do MeshPart
			tamanho = { 2.76769, 1.67358, 1.4791 }, -- studs (x, z do Blender) só para conferência
			fovOriginal = 55.0,
			estados = {
				["Pills"] = { { id = "rbxassetid://137120437695428", dur = 1.9667, loop = false } }, -- Food_Small_Can
			},
		},
	},
}
