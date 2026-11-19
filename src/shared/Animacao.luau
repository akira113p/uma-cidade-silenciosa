-- Animacao: monta a KeyframeSequence de um clipe (dado JSON de assets/animacoes) em runtime e toca no Animator, sem upload.
-- Dono: A1 (docs/personagens.md §2/A1). Funciona no cliente e no servidor. Usado por ArmasTerceira, AnimacaoCorpo e (A2) pelos
-- braços da 1ª pessoa. Semântica de pose/easing/marcador idêntica a ferramentas/animacao/montar_armas.luau.
--   Animacao.carregarDados(grupo)                       dado do arquivo ("armas/pistola", "corpo/carro"); nil + um warn se não existe
--   Animacao.sequencia(grupo, clipe)                    KeyframeSequence (cache); nil se o clipe não existe
--   Animacao.id(grupo, clipe)                           id publicado (Config) se houver, senão o registrado em runtime (cache); nil se não existe
--   Animacao.trilha(animator, grupo, clipe, opcoes?)    AnimationTrack (cache por animator+clipe); prioridade/laço vêm do dado
--   Animacao.duracao(grupo, clipe)                      duração nativa em s (0 se não existe)
-- opcoes: { id: string?, prioridade: string?, loop: boolean? } (id força o id; os outros sobrepõem o dado).
-- Tudo tolerante: dado ausente/clipe inexistente = nil com um warn único, nunca erro. RegisterKeyframeSequence só vale no
-- cliente que registrou: cada cliente toca no Animator de todos os personagens que vê (não depende de upload).
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Regra = require(script.Parent:WaitForChild("Regras"):WaitForChild("Animacao"))

local Animacao = {}

local avisados: { [string]: boolean } = {}
local function avisar(chave: string, texto: string)
	if not avisados[chave] then
		avisados[chave] = true
		warn("[Animacao] " .. texto)
	end
end

-- Dados -------------------------------------------------------------------------------------------------------------

local dados: { [string]: any } = {}
local semDados: { [string]: boolean } = {}

function Animacao.carregarDados(grupo: string): any?
	local d = dados[grupo]
	if d then
		return d
	end
	if semDados[grupo] then
		return nil
	end
	local raiz = script.Parent:FindFirstChild("AnimacoesDados") or script.Parent:WaitForChild("AnimacoesDados", 5)
	local alvo: Instance? = raiz
	for parte in string.gmatch(grupo, "[^/]+") do
		alvo = alvo and alvo:FindFirstChild(parte)
	end
	if not (alvo and alvo:IsA("ModuleScript")) then
		semDados[grupo] = true
		avisar("dado_" .. grupo, "sem dado de animação para " .. grupo)
		return nil
	end
	local ok, resultado = pcall(require, alvo)
	if not ok or type(resultado) ~= "table" then
		semDados[grupo] = true
		avisar("dado_" .. grupo, "dado de " .. grupo .. " ilegível: " .. tostring(resultado))
		return nil
	end
	dados[grupo] = resultado
	return resultado
end

local function clipeDe(grupo: string, clipe: string): any?
	local d = Animacao.carregarDados(grupo)
	local c = d and d.clipes and d.clipes[clipe]
	if not c then
		if d then
			avisar(`clipe_{grupo}_{clipe}`, `clipe inexistente: {grupo}/{clipe}`)
		end
		return nil
	end
	return c
end

function Animacao.duracao(grupo: string, clipe: string): number
	local c = clipeDe(grupo, clipe)
	return c and c.duracao or 0
end

-- KeyframeSequence ------------------------------------------------------------------------------------------------------

local function cframeDe(v: { number }): CFrame
	return CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0)
		* CFrame.fromEulerAnglesYXZ(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
end

local sequencias: { [string]: KeyframeSequence } = {}

function Animacao.sequencia(grupo: string, clipe: string): KeyframeSequence?
	local chave = grupo .. "/" .. clipe
	local pronta = sequencias[chave]
	if pronta then
		return pronta
	end
	local c = clipeDe(grupo, clipe)
	if not c then
		return nil
	end
	local quadros, motivo = Regra.resolverQuadros(Animacao.carregarDados(grupo), clipe)
	if not quadros or #quadros < 2 then
		avisar("quadros_" .. chave, `clipe {chave} inválido: {motivo or "menos de 2 quadros"}`)
		return nil
	end

	local ks = Instance.new("KeyframeSequence")
	ks.Name = string.gsub(chave, "/", "_")
	ks.Loop = c.loop == true
	ks.Priority = (Enum.AnimationPriority :: any)[c.prioridade or "Action"] or Enum.AnimationPriority.Action
	for i, q in quadros do
		-- o easing do JSON vale na chegada ao quadro; no Roblox a Pose guarda o easing do trecho até a PRÓXIMA pose
		local proximo = quadros[i + 1]
		local estilo, direcao = Regra.easing(if proximo then proximo.easing else nil)
		local kf = Instance.new("Keyframe")
		kf.Time = q.t
		local poses: { [string]: Pose } = {}
		local function garantir(peca: string): Pose
			local existente = poses[peca]
			if existente then
				return existente
			end
			local p = Instance.new("Pose")
			p.Name = peca
			p.Weight = 0 -- ancestral só sustenta a árvore; as peças animadas ganham Weight 1 abaixo
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
			p.EasingStyle = (Enum.PoseEasingStyle :: any)[estilo]
			p.EasingDirection = (Enum.PoseEasingDirection :: any)[direcao]
		end
		for _, m in q.marcadores or {} do
			local marcador = Instance.new("KeyframeMarker")
			marcador.Name = m
			marcador.Parent = kf
		end
		kf.Parent = ks
	end
	sequencias[chave] = ks
	return ks
end

-- Ids ---------------------------------------------------------------------------------------------------------------------

local function idPublicado(grupo: string, clipe: string): string?
	local pasta, nome = string.match(grupo, "^(%w+)/(.+)$")
	if not pasta then
		return nil
	end
	local config: any = nil
	local pastaConfig = script.Parent:FindFirstChild("Config")
	if pasta == "armas" then
		config = pastaConfig and pastaConfig:FindFirstChild("ArmasAnim")
	elseif pasta == "corpo" then
		config = pastaConfig and pastaConfig:FindFirstChild("AnimacoesCorpo")
	end
	if not (config and config:IsA("ModuleScript")) then
		return nil
	end
	local ok, cfg = pcall(require, config)
	local porGrupo = ok and cfg.animacoes and cfg.animacoes[nome]
	local id = porGrupo and porGrupo[clipe]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

local registrados: { [string]: string } = {}

function Animacao.id(grupo: string, clipe: string): string?
	local publicado = idPublicado(grupo, clipe)
	if publicado then
		return publicado
	end
	local chave = grupo .. "/" .. clipe
	local id = registrados[chave]
	if id then
		return id
	end
	local ks = Animacao.sequencia(grupo, clipe)
	if not ks then
		return nil
	end
	local ok, resultado = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(ks) :: any
	end)
	if not ok or resultado == nil then
		avisar("registro_" .. chave, `RegisterKeyframeSequence falhou em {chave}: {tostring(resultado)}`)
		return nil
	end
	-- a API nova devolve Content (userdata com .Uri); a antiga devolve o texto do id
	local texto: any = resultado
	if type(texto) ~= "string" then
		local okUri, uri = pcall(function()
			return (resultado :: any).Uri
		end)
		texto = if okUri and type(uri) == "string" and uri ~= "" then uri else tostring(resultado)
	end
	registrados[chave] = texto
	return texto
end

-- Trilhas -----------------------------------------------------------------------------------------------------------------

local trilhas: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

function Animacao.trilha(animator: Animator?, grupo: string, clipe: string, opcoes: any?): AnimationTrack?
	if not animator or not animator.Parent then
		return nil
	end
	local porAnimator = trilhas[animator]
	if not porAnimator then
		porAnimator = {}
		trilhas[animator] = porAnimator
	end
	local chave = grupo .. "/" .. clipe
	local existente = porAnimator[chave]
	if existente then
		return existente
	end
	local c = clipeDe(grupo, clipe)
	if not c then
		return nil
	end
	local id = if opcoes
			and type(opcoes.id) == "string"
			and opcoes.id ~= ""
		then opcoes.id
		else Animacao.id(grupo, clipe)
	if not id then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.Name = string.gsub(chave, "/", "_")
	anim.AnimationId = id
	local ok, nova = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not nova then
		avisar("load_" .. chave, `LoadAnimation falhou em {chave}: {tostring(nova)}`)
		return nil
	end
	local prioridade = (opcoes and opcoes.prioridade) or c.prioridade or "Action"
	nova.Priority = (Enum.AnimationPriority :: any)[prioridade] or Enum.AnimationPriority.Action
	local loop = if opcoes and type(opcoes.loop) == "boolean" then opcoes.loop else c.loop == true
	nova.Looped = loop
	porAnimator[chave] = nova
	return nova
end

return Animacao
