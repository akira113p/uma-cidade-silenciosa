-- Malhas dos personagens (docs/personagens.md, Parte M).
-- GERADO por ferramentas/modelos/gerar_config_personagens.py a partir de modelos 3d/personagens/<id>/<id>.json
-- (+ enviados.json, se existir). NAO editar a mao: rode o script de novo.
--
-- Estrutura (uma entrada por id de Config/Personagens):
--   [id] = {
--       modelo = false | "rbxassetid://...",   -- id do Model/FBX inteiro (informativo; false = nada enviado)
--       textura = false | "rbxassetid://...",  -- atlas recortado (<= 256 px), vai no TextureID de cada MeshPart
--       alturaTotalStuds = N,                  -- altura do boneco montado, pes em y = 0
--       partes = {                             -- as 15 pecas R15, todas obrigatorias
--           [nomeR15] = { meshId = false | "rbxassetid://...", tamanhoNativo = { x, y, z }, centroMontagem = { x, y, z } },
--       },
--   }
-- Eixos de tamanhoNativo e centroMontagem: os do Roblox, ponto = (-x, z, y) do Blender (medido). Frente = -Z; o lado esquerdo
-- do personagem fica em -X (LeftUpperArm tem centroMontagem.x < 0) e o direito em +X. x/z a partir do centro do corpo, y dos pes.
-- O visual "malhas" so vale com modelo, textura e as 15 partes preenchidos (Regras/Personagens.malhasCompletas);
-- qualquer falta cai em "bloco". Escala unica para o conjunto: k = altura do R15 / alturaTotalStuds; cada MeshPart recebe
-- Size = tamanhoNativo * k e fica em centroMontagem * k relativo aos pes (nao se estica peca a peca).
-- NADA foi enviado ao Roblox: todos os ids estao `false` ate a conta liberar (Open Cloud 403 User is moderated).

return {
	male_casual = {
		modelo = "rbxassetid://91769867573741",
		textura = "rbxassetid://82774880465639",
		alturaTotalStuds = 5.234,
		partes = {
			Head = {
				meshId = "rbxassetid://135574255573495",
				tamanhoNativo = { 0.5254, 0.8584, 0.6735 },
				centroMontagem = { -0.0003, 4.8048, -0.0317 },
			},
			UpperTorso = {
				meshId = "rbxassetid://77429504567478",
				tamanhoNativo = { 1.1402, 1.5646, 0.8772 },
				centroMontagem = { 0, 3.7514, 0.0706 },
			},
			LowerTorso = {
				meshId = "rbxassetid://140116822947927",
				tamanhoNativo = { 1.136, 0.9949, 0.8318 },
				centroMontagem = { 0, 2.8786, 0.0863 },
			},
			LeftUpperArm = {
				meshId = "rbxassetid://83381681578482",
				tamanhoNativo = { 0.3449, 1.0859, 0.4862 },
				centroMontagem = { -0.7426, 3.8662, 0.1361 },
			},
			LeftLowerArm = {
				meshId = "rbxassetid://81207843908320",
				tamanhoNativo = { 0.298, 0.9331, 0.3081 },
				centroMontagem = { -0.7775, 3.0906, 0.168 },
			},
			LeftHand = {
				meshId = "rbxassetid://85580843028809",
				tamanhoNativo = { 0.2156, 0.5637, 0.3995 },
				centroMontagem = { -0.7164, 2.3685, 0.1031 },
			},
			RightUpperArm = {
				meshId = "rbxassetid://111548973282613",
				tamanhoNativo = { 0.3449, 1.0859, 0.4862 },
				centroMontagem = { 0.7426, 3.8662, 0.1361 },
			},
			RightLowerArm = {
				meshId = "rbxassetid://137546465278207",
				tamanhoNativo = { 0.298, 0.9331, 0.3081 },
				centroMontagem = { 0.7775, 3.0906, 0.168 },
			},
			RightHand = {
				meshId = "rbxassetid://109706893907558",
				tamanhoNativo = { 0.2156, 0.5637, 0.3995 },
				centroMontagem = { 0.7164, 2.3685, 0.1031 },
			},
			LeftUpperLeg = {
				meshId = "rbxassetid://85196162461509",
				tamanhoNativo = { 0.5489, 1.2302, 0.6611 },
				centroMontagem = { -0.3385, 1.9247, 0.1241 },
			},
			LeftLowerLeg = {
				meshId = "rbxassetid://118415744122272",
				tamanhoNativo = { 0.4617, 1.3857, 0.4595 },
				centroMontagem = { -0.4507, 0.9292, 0.2463 },
			},
			LeftFoot = {
				meshId = "rbxassetid://94182821560591",
				tamanhoNativo = { 0.3703, 0.2789, 0.7556 },
				centroMontagem = { -0.4798, 0.1395, 0.0459 },
			},
			RightUpperLeg = {
				meshId = "rbxassetid://99330608211166",
				tamanhoNativo = { 0.5489, 1.2302, 0.6611 },
				centroMontagem = { 0.3385, 1.9247, 0.1241 },
			},
			RightLowerLeg = {
				meshId = "rbxassetid://131408033432849",
				tamanhoNativo = { 0.4617, 1.3857, 0.4595 },
				centroMontagem = { 0.4507, 0.9292, 0.2463 },
			},
			RightFoot = {
				meshId = "rbxassetid://110817267564873",
				tamanhoNativo = { 0.3703, 0.2789, 0.7556 },
				centroMontagem = { 0.4798, 0.1395, 0.0459 },
			},
		},
	},
	office_worker = {
		modelo = "rbxassetid://104429856580826",
		textura = "rbxassetid://109726008992531",
		alturaTotalStuds = 5.1228,
		partes = {
			Head = {
				meshId = "rbxassetid://80571325311066",
				tamanhoNativo = { 0.5118, 1.0038, 0.6368 },
				centroMontagem = { 0, 4.6209, -0.0334 },
			},
			UpperTorso = {
				meshId = "rbxassetid://99161971366341",
				tamanhoNativo = { 1.0468, 0.8869, 0.6164 },
				centroMontagem = { 0, 3.8646, -0.0174 },
			},
			LowerTorso = {
				meshId = "rbxassetid://131851230809959",
				tamanhoNativo = { 0.9538, 0.8723, 0.6455 },
				centroMontagem = { 0, 2.985, -0.0029 },
			},
			LeftUpperArm = {
				meshId = "rbxassetid://139963969185076",
				tamanhoNativo = { 0.2836, 0.9666, 0.3373 },
				centroMontagem = { -0.6652, 3.7155, 0 },
			},
			LeftLowerArm = {
				meshId = "rbxassetid://122681329138595",
				tamanhoNativo = { 0.2015, 0.7996, 0.2326 },
				centroMontagem = { -0.6761, 2.8905, 0 },
			},
			LeftHand = {
				meshId = "rbxassetid://75635887261123",
				tamanhoNativo = { 0.258, 0.5563, 0.2536 },
				centroMontagem = { -0.6956, 2.2464, 0.004 },
			},
			RightUpperArm = {
				meshId = "rbxassetid://94223753977043",
				tamanhoNativo = { 0.2836, 0.9666, 0.3373 },
				centroMontagem = { 0.6652, 3.7155, 0 },
			},
			RightLowerArm = {
				meshId = "rbxassetid://89076586715671",
				tamanhoNativo = { 0.2015, 0.7996, 0.2326 },
				centroMontagem = { 0.6761, 2.8905, 0 },
			},
			RightHand = {
				meshId = "rbxassetid://135200937120234",
				tamanhoNativo = { 0.2636, 0.5563, 0.2536 },
				centroMontagem = { 0.6928, 2.2464, 0.004 },
			},
			LeftUpperLeg = {
				meshId = "rbxassetid://76411690248102",
				tamanhoNativo = { 0.4769, 1.2503, 0.599 },
				centroMontagem = { -0.2384, 1.9237, 0.0204 },
			},
			LeftLowerLeg = {
				meshId = "rbxassetid://78157440306647",
				tamanhoNativo = { 0.2619, 1.2067, 0.3606 },
				centroMontagem = { -0.2733, 0.7824, 0.0174 },
			},
			LeftFoot = {
				meshId = "rbxassetid://80162311396927",
				tamanhoNativo = { 0.2544, 0.2343, 0.7124 },
				centroMontagem = { -0.2733, 0.1171, -0.1963 },
			},
			RightUpperLeg = {
				meshId = "rbxassetid://78207679269528",
				tamanhoNativo = { 0.4769, 1.2503, 0.599 },
				centroMontagem = { 0.2384, 1.9237, 0.0204 },
			},
			RightLowerLeg = {
				meshId = "rbxassetid://111219647571089",
				tamanhoNativo = { 0.2619, 1.2067, 0.3606 },
				centroMontagem = { 0.2733, 0.7824, 0.0174 },
			},
			RightFoot = {
				meshId = "rbxassetid://119829826535221",
				tamanhoNativo = { 0.2544, 0.2343, 0.7124 },
				centroMontagem = { 0.2733, 0.1171, -0.1963 },
			},
		},
	},
	survivor_woman = {
		modelo = "rbxassetid://132063201632558",
		textura = "rbxassetid://80957814857280",
		alturaTotalStuds = 4.9458,
		partes = {
			Head = {
				meshId = "rbxassetid://102801571870488",
				tamanhoNativo = { 0.5563, 1.0473, 0.6791 },
				centroMontagem = { 0, 4.4221, 0.0173 },
			},
			UpperTorso = {
				meshId = "rbxassetid://81465943110642",
				tamanhoNativo = { 0.8542, 1.2422, 1.1082 },
				centroMontagem = { 0, 3.5146, 0.2024 },
			},
			LowerTorso = {
				meshId = "rbxassetid://91683024303842",
				tamanhoNativo = { 0.9891, 0.7816, 0.5918 },
				centroMontagem = { 0, 2.8377, 0.0112 },
			},
			LeftUpperArm = {
				meshId = "rbxassetid://116366231962111",
				tamanhoNativo = { 0.2409, 0.9278, 0.285 },
				centroMontagem = { -0.5476, 3.5668, 0 },
			},
			LeftLowerArm = {
				meshId = "rbxassetid://129469276633172",
				tamanhoNativo = { 0.1702, 0.7677, 0.1965 },
				centroMontagem = { -0.5574, 2.7749, 0 },
			},
			LeftHand = {
				meshId = "rbxassetid://94453479508030",
				tamanhoNativo = { 0.2273, 0.4928, 0.2168 },
				centroMontagem = { -0.5719, 2.1754, 0.0034 },
			},
			RightUpperArm = {
				meshId = "rbxassetid://125577714366171",
				tamanhoNativo = { 0.2409, 0.9278, 0.285 },
				centroMontagem = { 0.5476, 3.5668, 0 },
			},
			RightLowerArm = {
				meshId = "rbxassetid://110719441986712",
				tamanhoNativo = { 0.1702, 0.7677, 0.1965 },
				centroMontagem = { 0.5574, 2.7749, 0 },
			},
			RightHand = {
				meshId = "rbxassetid://70688373419870",
				tamanhoNativo = { 0.2273, 0.4928, 0.2168 },
				centroMontagem = { 0.5719, 2.1754, 0.0034 },
			},
			LeftUpperLeg = {
				meshId = "rbxassetid://114246743996751",
				tamanhoNativo = { 0.4945, 1.2003, 0.575 },
				centroMontagem = { -0.2473, 1.8467, 0.0195 },
			},
			LeftLowerLeg = {
				meshId = "rbxassetid://106194973490513",
				tamanhoNativo = { 0.2514, 1.1585, 0.3461 },
				centroMontagem = { -0.2991, 0.7511, 0.0167 },
			},
			LeftFoot = {
				meshId = "rbxassetid://72962668206067",
				tamanhoNativo = { 0.2442, 0.2249, 0.6839 },
				centroMontagem = { -0.2991, 0.1124, -0.1884 },
			},
			RightUpperLeg = {
				meshId = "rbxassetid://76148210560358",
				tamanhoNativo = { 0.4945, 1.2003, 0.575 },
				centroMontagem = { 0.2473, 1.8467, 0.0195 },
			},
			RightLowerLeg = {
				meshId = "rbxassetid://113593855410430",
				tamanhoNativo = { 0.2514, 1.1585, 0.3461 },
				centroMontagem = { 0.2991, 0.7511, 0.0167 },
			},
			RightFoot = {
				meshId = "rbxassetid://96233959226150",
				tamanhoNativo = { 0.2442, 0.2249, 0.6839 },
				centroMontagem = { 0.2991, 0.1124, -0.1884 },
			},
		},
	},
	villager_man = {
		modelo = "rbxassetid://119406111809963",
		textura = "rbxassetid://74259305525475",
		alturaTotalStuds = 5.234,
		partes = {
			Head = {
				meshId = "rbxassetid://107687805398509",
				tamanhoNativo = { 1.3314, 1.0565, 1.3277 },
				centroMontagem = { -0.0071, 4.7058, 0 },
			},
			UpperTorso = {
				meshId = "rbxassetid://140521486843097",
				tamanhoNativo = { 0.8799, 1.456, 0.6599 },
				centroMontagem = { -0.0046, 3.6818, -0.0158 },
			},
			LowerTorso = {
				meshId = "rbxassetid://81566349031749",
				tamanhoNativo = { 0.882, 0.496, 0.5902 },
				centroMontagem = { -0.0046, 2.8758, -0.0135 },
			},
			LeftUpperArm = {
				meshId = "rbxassetid://93952801005714",
				tamanhoNativo = { 0.2456, 0.9741, 0.3432 },
				centroMontagem = { -0.5673, 3.8025, 0.0839 },
			},
			LeftLowerArm = {
				meshId = "rbxassetid://103023929531481",
				tamanhoNativo = { 0.2274, 0.7418, 0.2258 },
				centroMontagem = { -0.5651, 3.0028, 0.0318 },
			},
			LeftHand = {
				meshId = "rbxassetid://74734188011726",
				tamanhoNativo = { 0.1676, 0.4737, 0.1856 },
				centroMontagem = { -0.5558, 2.4353, 0.0143 },
			},
			RightUpperArm = {
				meshId = "rbxassetid://85026673816819",
				tamanhoNativo = { 0.2461, 0.9663, 0.3636 },
				centroMontagem = { 0.5584, 3.7974, 0.0735 },
			},
			RightLowerArm = {
				meshId = "rbxassetid://137398776022448",
				tamanhoNativo = { 0.2277, 0.7511, 0.2322 },
				centroMontagem = { 0.5763, 2.9983, -0.0024 },
			},
			RightHand = {
				meshId = "rbxassetid://70581162716021",
				tamanhoNativo = { 0.1668, 0.4753, 0.1642 },
				centroMontagem = { 0.5657, 2.4397, 0.0262 },
			},
			LeftUpperLeg = {
				meshId = "rbxassetid://118045771715592",
				tamanhoNativo = { 0.4966, 1.2715, 0.5274 },
				centroMontagem = { -0.2919, 2.2662, -0.0071 },
			},
			LeftLowerLeg = {
				meshId = "rbxassetid://130842103571921",
				tamanhoNativo = { 0.4749, 1.64, 0.4762 },
				centroMontagem = { -0.3024, 1.1452, -0.0326 },
			},
			LeftFoot = {
				meshId = "rbxassetid://74488294121271",
				tamanhoNativo = { 0.2642, 0.3951, 0.6092 },
				centroMontagem = { -0.2896, 0.1975, -0.1493 },
			},
			RightUpperLeg = {
				meshId = "rbxassetid://84948395500487",
				tamanhoNativo = { 0.4966, 1.2715, 0.5274 },
				centroMontagem = { 0.2828, 2.2662, -0.0071 },
			},
			RightLowerLeg = {
				meshId = "rbxassetid://131389986416719",
				tamanhoNativo = { 0.4749, 1.6399, 0.4762 },
				centroMontagem = { 0.2932, 1.1451, -0.0326 },
			},
			RightFoot = {
				meshId = "rbxassetid://125929789430199",
				tamanhoNativo = { 0.2642, 0.3951, 0.6092 },
				centroMontagem = { 0.2804, 0.1975, -0.1493 },
			},
		},
	},
	villager_woman = {
		modelo = "rbxassetid://76205332070175",
		textura = "rbxassetid://80054761072704",
		alturaTotalStuds = 5.234,
		partes = {
			Head = {
				meshId = "rbxassetid://106489889107573",
				tamanhoNativo = { 0.487, 0.9245, 0.5483 },
				centroMontagem = { 0, 4.7717, -0.0385 },
			},
			UpperTorso = {
				meshId = "rbxassetid://114453769528275",
				tamanhoNativo = { 0.9539, 1.2695, 0.6234 },
				centroMontagem = { -0.0105, 3.8508, -0.0953 },
			},
			LowerTorso = {
				meshId = "rbxassetid://134765708514098",
				tamanhoNativo = { 0.9329, 0.6285, 0.6618 },
				centroMontagem = { 0, 3.0336, 0.0672 },
			},
			LeftUpperArm = {
				meshId = "rbxassetid://77144024653883",
				tamanhoNativo = { 0.2312, 1.0057, 0.2365 },
				centroMontagem = { -0.6031, 3.9219, 0.0476 },
			},
			LeftLowerArm = {
				meshId = "rbxassetid://84666783481541",
				tamanhoNativo = { 0.2327, 0.7382, 0.2845 },
				centroMontagem = { -0.6238, 3.0933, 0.0146 },
			},
			LeftHand = {
				meshId = "rbxassetid://113374704345573",
				tamanhoNativo = { 0.1711, 0.488, 0.1694 },
				centroMontagem = { -0.6269, 2.5292, -0.0628 },
			},
			RightUpperArm = {
				meshId = "rbxassetid://94935948552411",
				tamanhoNativo = { 0.2312, 0.9972, 0.272 },
				centroMontagem = { 0.6031, 3.9177, 0.0653 },
			},
			RightLowerArm = {
				meshId = "rbxassetid://102380146271270",
				tamanhoNativo = { 0.2327, 0.7382, 0.2845 },
				centroMontagem = { 0.6238, 3.0933, 0.0146 },
			},
			RightHand = {
				meshId = "rbxassetid://94796620333795",
				tamanhoNativo = { 0.1711, 0.488, 0.1694 },
				centroMontagem = { 0.6269, 2.5292, -0.0628 },
			},
			LeftUpperLeg = {
				meshId = "rbxassetid://108643425059826",
				tamanhoNativo = { 0.4961, 1.3416, 0.5328 },
				centroMontagem = { -0.2516, 2.3299, 0.0172 },
			},
			LeftLowerLeg = {
				meshId = "rbxassetid://136755927530882",
				tamanhoNativo = { 0.3603, 1.6916, 0.4505 },
				centroMontagem = { -0.2265, 1.1812, -0.0048 },
			},
			LeftFoot = {
				meshId = "rbxassetid://83428662082712",
				tamanhoNativo = { 0.2726, 0.4075, 0.6284 },
				centroMontagem = { -0.294, 0.2038, -0.1541 },
			},
			RightUpperLeg = {
				meshId = "rbxassetid://79154921861885",
				tamanhoNativo = { 0.4709, 1.3416, 0.5328 },
				centroMontagem = { 0.2768, 2.3299, 0.0172 },
			},
			RightLowerLeg = {
				meshId = "rbxassetid://109741609189130",
				tamanhoNativo = { 0.3763, 1.6915, 0.4505 },
				centroMontagem = { 0.2297, 1.1812, -0.0048 },
			},
			RightFoot = {
				meshId = "rbxassetid://121924678890461",
				tamanhoNativo = { 0.2726, 0.4075, 0.6284 },
				centroMontagem = { 0.294, 0.2038, -0.1541 },
			},
		},
	},
}
