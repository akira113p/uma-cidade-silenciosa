-- Sons: toca sons 3D do catálogo (Config/Sons) a partir do servidor. Dono: P3. Contrato: docs/arquitetura.md §5.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared:WaitForChild("Config"):WaitForChild("Sons"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local Ambiente = require(script.Parent.Ambiente)
local Teste = require(script.Parent.Teste)

local Sons = {}

local GRUPOS = { "Efeitos", "Ambiente", "UI", "Voz" }
local ALCANCE_MINIMO = 20 -- studs; RollOffMaxDistance nunca fica menor que isto
local DURACAO_PADRAO = 5 -- s, quando o servidor não sabe o TimeLength (som não carregado no servidor)
local PECA_SOLTA = 0.2 -- lado da peça invisível de som em Vector3

local rng = Random.new()
local grupos: { [string]: SoundGroup } = {}

local function pastaSoltos(): Folder
	local pasta = workspace:FindFirstChild("SonsSoltos")
	if pasta and pasta:IsA("Folder") then
		return pasta
	end
	local nova = Instance.new("Folder")
	nova.Name = "SonsSoltos"
	nova.Parent = workspace
	return nova
end

local function grupo(nome: string): SoundGroup?
	return grupos[nome]
end

local avisados: { [string]: boolean } = {}
local function avisarUmaVez(nome: string)
	if not avisados[nome] then
		avisados[nome] = true
		warn("[Sons] som desconhecido ou sem ids: " .. tostring(nome))
	end
end

-- opcoes.db: o som só é ouvido até onde um ouvinte nível 1 o ouviria (docs/calculos.md §1.5)
function Sons.tocar(nome: string, onde: BasePart | Vector3, opcoes: { db: number?, volume: number? }?): Sound?
	local cfg = Catalogo[nome]
	if cfg == nil or #cfg.ids == 0 then
		avisarUmaVez(nome)
		return nil
	end

	local som = Instance.new("Sound")
	som.Name = nome
	som.SoundId = cfg.ids[rng:NextInteger(1, #cfg.ids)]
	som.Volume = cfg.volume * ((opcoes and opcoes.volume) or 1)
	som.PlaybackSpeed = 1 + rng:NextNumber(-cfg.variacao, cfg.variacao)
	som.SoundGroup = grupo(cfg.grupo)
	if opcoes and opcoes.db then
		som.RollOffMode = Enum.RollOffMode.InverseTapered
		som.RollOffMaxDistance = math.max(ALCANCE_MINIMO, Som.alcance(opcoes.db, Ambiente.db(), 0))
	end

	local duracao = DURACAO_PADRAO
	if typeof(onde) == "Vector3" then
		local peca = Instance.new("Part")
		peca.Name = "SomSolto"
		peca.Size = Vector3.new(PECA_SOLTA, PECA_SOLTA, PECA_SOLTA)
		peca.Anchored = true
		peca.CanCollide = false
		peca.CanQuery = false
		peca.CanTouch = false
		peca.Transparency = 1
		peca.CFrame = CFrame.new(onde)
		som.Parent = peca
		peca.Parent = pastaSoltos()
		som:Play()
		Debris:AddItem(peca, duracao + 1)
	else
		som.Parent = onde
		som:Play()
		-- TimeLength só é conhecido se o servidor já carregou o áudio; senão fica a duração padrão
		if som.TimeLength > 0 then
			duracao = som.TimeLength
		end
		Debris:AddItem(som, duracao + 1)
	end
	return som
end

-- Som em laço preso a uma peça (motor). Quem chama controla Volume/PlaybackSpeed e destrói. Sem ids, devolve nil.
function Sons.loop(nome: string, peca: BasePart, opcoes: { db: number? }?): Sound?
	local cfg = Catalogo[nome]
	if cfg == nil or #cfg.ids == 0 then
		avisarUmaVez(nome)
		return nil
	end
	local som = Instance.new("Sound")
	som.Name = nome
	som.SoundId = cfg.ids[rng:NextInteger(1, #cfg.ids)]
	som.Volume = cfg.volume
	som.Looped = true
	som.SoundGroup = grupo(cfg.grupo)
	if opcoes and opcoes.db then
		som.RollOffMode = Enum.RollOffMode.InverseTapered
		som.RollOffMaxDistance = math.max(ALCANCE_MINIMO, Som.alcance(opcoes.db, Ambiente.db(), 0))
	end
	som.Parent = peca
	som:Play()
	return som
end

function Sons.iniciar()
	for _, nome in GRUPOS do
		local g = SoundService:FindFirstChild(nome)
		if not (g and g:IsA("SoundGroup")) then
			g = Instance.new("SoundGroup")
			g.Name = nome
			g.Volume = 1 -- o volume do jogador é aplicado no cliente (SonsLocal, Pref_Volume)
			g.Parent = SoundService
		end
		grupos[nome] = g :: SoundGroup
	end
	pastaSoltos()

	Teste.registrar("som", function(jogador: Player, nome: string?, db: number?)
		local personagem = jogador and jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if not (raiz and raiz:IsA("BasePart")) then
			return "sem personagem"
		end
		local tocado = Sons.tocar(nome or "PassoConcreto", raiz.Position + Vector3.new(0, 0, -8), { db = db })
		return tocado and "tocando " .. tocado.Name or "som desconhecido"
	end)
end

return Sons
