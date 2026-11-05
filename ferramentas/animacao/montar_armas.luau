-- Monta os clipes de arma (3ª pessoa, docs/armas.md §9) a partir de assets/animacoes/armas/<classe>.json.
-- Gera build/anim_armas/<classe>_<Clipe>.rbxm (um KeyframeSequence por arquivo, para enviar como Animation).
-- Uso (da raiz):  lune run ferramentas/animacao/montar_armas.luau
-- Formato do JSON (poses como dado, skill animacao-roblox):
--   { "classe", "poses": { nome: { Junta: [rx,ry,rz] | [rx,ry,rz,px,py,pz] } },
--     "clipes": { Nome: { "duracao", "loop", "prioridade", "quadros": [ { "t", "de"?: nome de pose, "juntas"?: {...},
--                                                                          "easing"?: "Cubic-Out", "marcadores"?: ["Impacto"] } ] } } }
-- Ângulos em graus, ordem YXZ (Ry*Rx*Rz, guinada por fora); posição em studs. Junta = nome do Motor6D do R15; a Pose vai na peça filha.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local PASTA_JSON = "assets/animacoes/armas"
local PASTA_SAIDA = "build/anim_armas"

-- junta do R15 -> peça filha (onde a Pose fica) e peça pai
local JUNTA_PECA: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
}
local PAI_PECA: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
}

local PRIORIDADE = {
	Core = roblox.Enum.AnimationPriority.Core,
	Idle = roblox.Enum.AnimationPriority.Idle,
	Movement = roblox.Enum.AnimationPriority.Movement,
	Action = roblox.Enum.AnimationPriority.Action,
	Action2 = roblox.Enum.AnimationPriority.Action2,
	Action3 = roblox.Enum.AnimationPriority.Action3,
	Action4 = roblox.Enum.AnimationPriority.Action4,
}

local function easing(texto: string?): (any, any)
	if not texto then
		return roblox.Enum.PoseEasingStyle.Linear, roblox.Enum.PoseEasingDirection.In
	end
	local estilo, direcao = string.match(texto, "^(%a+)%-?(%a*)$")
	local e = (roblox.Enum.PoseEasingStyle :: any)[estilo] or roblox.Enum.PoseEasingStyle.Linear
	local d = (roblox.Enum.PoseEasingDirection :: any)[if direcao ~= "" then direcao else "In"]
		or roblox.Enum.PoseEasingDirection.In
	return e, d
end

-- junta -> CFrame
local function cframeDe(v: { number }): any
	local rx, ry, rz = math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0)
	return roblox.CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0) * roblox.CFrame.fromEulerAnglesYXZ(rx, ry, rz)
end

-- Resolve "de" + "juntas" de um quadro em { Junta = {rx,ry,rz,px,py,pz} }.
local function juntasDoQuadro(poses: any, q: any): { [string]: { number } }
	local r: { [string]: { number } } = {}
	if q.de then
		local base = poses[q.de]
		assert(base, "pose inexistente: " .. tostring(q.de))
		for j, v in base do
			r[j] = v
		end
	end
	for j, v in q.juntas or {} do
		r[j] = v
	end
	for j in r do
		assert(JUNTA_PECA[j], "junta desconhecida: " .. j)
	end
	return r
end

local function montarSequencia(classe: string, nome: string, clipe: any, resolvidos: any): any
	local ks = roblox.Instance.new("KeyframeSequence")
	ks.Name = classe .. "_" .. nome
	ks.Loop = clipe.loop == true
	ks.Priority = PRIORIDADE[clipe.prioridade or "Action"]
	for i, q in resolvidos do
		-- o easing do JSON vale na chegada ao quadro; no Roblox a Pose guarda o easing do trecho até a PRÓXIMA pose
		local proximo = resolvidos[i + 1]
		local kf = roblox.Instance.new("Keyframe")
		kf.Time = q.t
		-- peças com pose (as animadas e seus ancestrais, estes com Weight 0 só para sustentar a árvore)
		local poses: { [string]: any } = {}
		local function garantir(peca: string)
			if poses[peca] then
				return poses[peca]
			end
			local p = roblox.Instance.new("Pose")
			p.Name = peca
			p.Weight = 0
			poses[peca] = p
			local pai = PAI_PECA[peca]
			if pai then
				garantir(pai)
				p.Parent = poses[pai]
			else
				p.Parent = kf
			end
			return p
		end
		for junta, v in q.juntas do
			local peca = JUNTA_PECA[junta]
			local p = garantir(peca)
			p.CFrame = cframeDe(v)
			p.Weight = 1
			local e, d = easing(if proximo then proximo.easing else nil)
			p.EasingStyle = e
			p.EasingDirection = d
		end
		for _, m in q.marcadores or {} do
			local marcador = roblox.Instance.new("KeyframeMarker")
			marcador.Name = m
			marcador.Parent = kf
		end
		kf.Parent = ks
	end
	return ks
end

local function resolverClipe(arquivo: any, clipe: any): { any }
	local saida = {}
	for _, q in clipe.quadros do
		table.insert(saida, {
			t = q.t,
			easing = q.easing,
			marcadores = q.marcadores,
			juntas = juntasDoQuadro(arquivo.poses or {}, q),
		})
	end
	table.sort(saida, function(a, b)
		return a.t < b.t
	end)
	return saida
end

local function main()
	pcall(fs.writeDir, "build")
	pcall(fs.writeDir, PASTA_SAIDA)
	local dados: any = {}
	for _, arq in fs.readDir(PASTA_JSON) do
		if arq ~= "mao.json" and string.match(arq, "%.json$") then
			local a = serde.decode("json", fs.readFile(PASTA_JSON .. "/" .. arq))
			local classe = a.classe
			dados[classe] = {}
			local nomes = {}
			for n in a.clipes do
				table.insert(nomes, n)
			end
			table.sort(nomes)
			for _, nome in nomes do
				local clipe = a.clipes[nome]
				local quadros = resolverClipe(a, clipe)
				assert(#quadros >= 2, classe .. "_" .. nome .. ": precisa de 2+ quadros")
				assert(
					math.abs(quadros[#quadros].t - clipe.duracao) < 1e-4,
					`{classe}_{nome}: último quadro ({quadros[#quadros].t}) deve ser igual a duracao ({clipe.duracao})`
				)
				dados[classe][nome] = {
					duracao = clipe.duracao,
					loop = clipe.loop == true,
					prioridade = clipe.prioridade or "Action",
					quadros = quadros,
				}
				local ks = montarSequencia(classe, nome, clipe, quadros)
				local bytes = roblox.serializeModel({ ks }, false)
				fs.writeFile(`{PASTA_SAIDA}/{classe}_{nome}.rbxm`, bytes)
				print(`ok {classe}_{nome}: {#quadros} quadros, {clipe.duracao}s, {#bytes} bytes`)
			end
		end
	end
end

main()
