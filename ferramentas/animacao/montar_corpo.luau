-- Monta os clipes de corpo (assets/animacoes/corpo/*.json) como KeyframeSequence e grava build/anim_corpo/<grupo>_<Clipe>.rbxm
-- (um por arquivo, prontos para enviar como Animation quando a conta puder; no jogo o shared/Animacao monta o mesmo em runtime).
-- Mesma semântica de ferramentas/animacao/montar_armas.luau (pose por junta, easing do trecho na pose anterior, marcadores).
-- Valida antes (Regras/Animacao.validarClipe) e para se algo estiver errado. Uso (da raiz):  lune run ferramentas/animacao/montar_corpo.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Regra = require("../../src/shared/Regras/Animacao")

local PASTA_JSON = "assets/animacoes/corpo"
local PASTA_SAIDA = "build/anim_corpo"
local SEM_PERNAS: { [string]: boolean } = { carro = true, mao = true }

local function cframeDe(v: { number }): any
	return roblox.CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0)
		* roblox.CFrame.fromEulerAnglesYXZ(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
end

local function montar(nomeSeq: string, clipe: any, quadros: { any }): any
	local ks = roblox.Instance.new("KeyframeSequence")
	ks.Name = nomeSeq
	ks.Loop = clipe.loop == true
	ks.Priority = (roblox.Enum.AnimationPriority :: any)[clipe.prioridade or "Action"]
	for i, q in quadros do
		local proximo = quadros[i + 1]
		local estilo, direcao = Regra.easing(if proximo then proximo.easing else nil)
		local kf = roblox.Instance.new("Keyframe")
		kf.Time = q.t
		local poses: { [string]: any } = {}
		local function garantir(peca: string): any
			if poses[peca] then
				return poses[peca]
			end
			local p = roblox.Instance.new("Pose")
			p.Name = peca
			p.Weight = 0
			poses[peca] = p
			local pai = Regra.PAI_PECA[peca]
			if pai then
				p.Parent = garantir(pai)
			else
				p.Parent = kf
			end
			return p
		end
		for junta, v in q.juntas do
			local p = garantir(Regra.JUNTA_PECA[junta])
			p.CFrame = cframeDe(v)
			p.Weight = 1
			p.EasingStyle = (roblox.Enum.PoseEasingStyle :: any)[estilo]
			p.EasingDirection = (roblox.Enum.PoseEasingDirection :: any)[direcao]
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

pcall(fs.writeDir, "build")
pcall(fs.writeDir, PASTA_SAIDA)
local total = 0
for _, arquivo in fs.readDir(PASTA_JSON) do
	local grupo = string.match(arquivo, "^(.+)%.json$")
	if not grupo then
		continue
	end
	local arq = serde.decode("json", fs.readFile(`{PASTA_JSON}/{arquivo}`))
	local nomes: { string } = {}
	for n in arq.clipes do
		table.insert(nomes, n)
	end
	table.sort(nomes)
	for _, nome in nomes do
		local erros = Regra.validarClipe(arq, nome, { proibidas = if SEM_PERNAS[grupo] then Regra.PERNAS else nil })
		if #erros > 0 then
			print(`FALHOU corpo/{grupo}/{nome}: {table.concat(erros, "; ")}`)
			process.exit(1)
		end
		local quadros = Regra.resolverQuadros(arq, nome) :: { any }
		local clipe = arq.clipes[nome]
		local ks = montar(`corpo_{grupo}_{nome}`, clipe, quadros)
		local bytes = roblox.serializeModel({ ks }, false)
		fs.writeFile(`{PASTA_SAIDA}/{grupo}_{nome}.rbxm`, bytes)
		total += 1
		print(`ok corpo_{grupo}_{nome}: {#quadros} quadros, {clipe.duracao}s, {#bytes} bytes`)
	end
end
print(`{total} clipes em {PASTA_SAIDA}`)
