-- Monta um KeyframeSequence por ação a partir de modelos 3d/rastejador/anim_roblox.json (gerar_anim_rastejador.py) e grava
-- modelos 3d/rastejador/anim/Rastejador_<Acao>.rbxm. Uso (da raiz):  lune run ferramentas/modelos/montar_anim_rbxm.luau [modo]
-- modo "aninhado" (padrão): poses aninhadas pela hierarquia dos ossos. modo "plano": todas as poses direto no Keyframe.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local modo, nome_monstro = process.args[1], process.args[2] -- no Lune 0.10 o `...` vem vazio
modo = modo or "aninhado"
nome_monstro = nome_monstro or "rastejador" -- Uso: lune run ... [modo] [rastejador|wrapper]
local PASTA = "modelos 3d/" .. nome_monstro
local dados = serde.decode("json", fs.readFile(PASTA .. "/anim_roblox.json"))
local manifesto = serde.decode("json", fs.readFile(PASTA .. "/manifesto.json"))
-- prefixo do Animation: o manifesto manda (monstros v2: "MonstroPS1_"); sem ele, nome com inicial maiúscula (rastejador, wrapper)
local PREFIXO = manifesto.prefixo_anim or (string.upper(string.sub(nome_monstro, 1, 1)) .. string.sub(nome_monstro, 2) .. "_")

local function pai(osso: string): string?
	return manifesto.ossos[osso].pai
end

pcall(fs.writeDir, PASTA .. "/anim")
for nome, a in dados do
	local ks = roblox.Instance.new("KeyframeSequence")
	ks.Name = PREFIXO .. nome
	ks.Loop = a.ciclica
	-- locomoção = Core; todo o resto (golpes, habilidades, Death, loops de estado como Emboscada e Atordoado) = Action
	local LOCOMOCAO = { Idle = true, Walk = true, Run = true, Arrancada = true }
	ks.Priority = if LOCOMOCAO[nome] then roblox.Enum.AnimationPriority.Core else roblox.Enum.AnimationPriority.Action
	for i, t in a.tempos do
		local kf = roblox.Instance.new("Keyframe")
		kf.Name = "Keyframe"
		kf.Time = t
		local poses = {}
		for _, osso in a.ossos do
			local v = a.frames[i][osso]
			local p = roblox.Instance.new("Pose")
			p.Name = osso
			p.CFrame = roblox.CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7]) -- x,y,z,qx,qy,qz,qw
			p.Weight = 1
			p.EasingStyle = roblox.Enum.PoseEasingStyle.Linear
			poses[osso] = p
		end
		for _, osso in a.ossos do -- pais vêm antes dos filhos
			local pp = pai(osso)
			poses[osso].Parent = if modo == "aninhado" and pp then poses[pp] else kf
		end
		kf.Parent = ks
	end
	local bytes = roblox.serializeModel({ ks }, false)
	fs.writeFile(PASTA .. "/anim/" .. PREFIXO .. nome .. ".rbxm", bytes)
	print("gravado", nome, #a.tempos .. " keyframes", #bytes .. " bytes")
end
