-- Monta um KeyframeSequence por ação a partir de <pasta>/anim_roblox.json (converter_anim_gb.py) e grava <pasta>/anim/<Prefixo><Acao>.rbxm.
-- Uso (da raiz):  lune run ferramentas/goldbright/montar_anim_gb.luau "modelos 3d/gold-bright/roblox/<grupo>" <Prefixo>
-- Igual ao montar_anim_rbxm.luau (poses aninhadas pela hierarquia), mas respeita `pesos`: ancestral não animado = Weight 0.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local PASTA, PREFIXO = process.args[1], process.args[2] or ""
local dados = serde.decode("json", fs.readFile(PASTA .. "/anim_roblox.json"))
local manifesto = serde.decode("json", fs.readFile(PASTA .. "/manifesto.json"))

pcall(fs.writeDir, PASTA .. "/anim")
for nome, a in dados do
	local ks = roblox.Instance.new("KeyframeSequence")
	ks.Name = PREFIXO .. nome
	ks.Loop = a.ciclica
	-- Viewmodel: tudo Action (sobrepõe o Idle do corpo); o Idle em loop também, é a pose base da arma.
	ks.Priority = roblox.Enum.AnimationPriority.Action
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
			p.Weight = a.pesos[osso]
			p.EasingStyle = roblox.Enum.PoseEasingStyle.Linear
			poses[osso] = p
		end
		for _, osso in a.ossos do -- pais vêm antes dos filhos
			local pp = manifesto.ossos[osso].pai
			poses[osso].Parent = if pp then poses[pp] else kf
		end
		kf.Parent = ks
	end
	local bytes = roblox.serializeModel({ ks }, false)
	fs.writeFile(PASTA .. "/anim/" .. PREFIXO .. nome .. ".rbxm", bytes)
end
print("gravado", PASTA, "acoes:", #dados)
