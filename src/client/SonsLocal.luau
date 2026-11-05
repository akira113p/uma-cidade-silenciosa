-- SonsLocal: sons 2D do cliente (UI, coração, ambiente em loop) e aplicação de Pref_Volume aos SoundGroups.
-- Dono: P3. Contrato: docs/arquitetura.md §P3.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared:WaitForChild("Config"):WaitForChild("Sons"))
local CfgCamera = require(Shared:WaitForChild("Config"):WaitForChild("Camera"))

local SonsLocal = {}

local GRUPOS = { "Efeitos", "Ambiente", "UI", "Voz" }
local PREFIXO_LOCAL = "Local_" -- os SoundGroups do servidor têm o nome puro; os do cliente levam este prefixo
local FADE_AMBIENTE = 2 -- s
local FADE_CURTO = 0.5 -- s
local VARREDURA = 0.25 -- s (4 Hz)
local ESTADOS_CORACAO = { Caca = true, ["Caça"] = true, Ataque = true }
local CONDICAO_PARA_LOOP: { [string]: string } = {
	noite = "AmbienteNoite",
	dia = "AmbienteDia",
	chuva = "AmbienteChuva",
	tempestade = "AmbienteChuva",
}

local rng = Random.new()
local jogador = Players.LocalPlayer
local grupos: { [string]: SoundGroup } = {}
local loops: { [string]: Sound } = {}

local function volumeGeral(): number
	local pref = jogador:GetAttribute("Pref_Volume")
	if type(pref) ~= "number" then
		pref = CfgCamera.preferenciasPadrao.Pref_Volume
	end
	return math.clamp(pref / 100, 0, 1)
end

-- Pref_Volume vale para os grupos locais e para os do servidor (a mudança é local, não replica)
local function aplicarVolume(instancia: Instance)
	if not instancia:IsA("SoundGroup") then
		return
	end
	local nome = string.gsub(instancia.Name, "^" .. PREFIXO_LOCAL, "")
	if table.find(GRUPOS, nome) then
		instancia.Volume = volumeGeral()
	end
end

local function garantirGrupos()
	for _, nome in GRUPOS do
		if not grupos[nome] then
			local g = Instance.new("SoundGroup")
			g.Name = PREFIXO_LOCAL .. nome
			g.Volume = volumeGeral()
			g.Parent = SoundService
			grupos[nome] = g
		end
	end
end

local function criarSom(nome: string): (Sound?, any)
	local cfg = Catalogo[nome]
	if cfg == nil or #cfg.ids == 0 then
		warn("[SonsLocal] som desconhecido: " .. tostring(nome))
		return nil, nil
	end
	garantirGrupos()
	local som = Instance.new("Sound")
	som.Name = nome
	som.SoundId = cfg.ids[rng:NextInteger(1, #cfg.ids)]
	som.Volume = cfg.volume
	som.PlaybackSpeed = 1 + rng:NextNumber(-cfg.variacao, cfg.variacao)
	som.SoundGroup = grupos[cfg.grupo]
	return som, cfg
end

function SonsLocal.tocar(nome: string)
	local som = criarSom(nome)
	if not som then
		return
	end
	som.Ended:Once(function()
		som:Destroy()
	end)
	som.Parent = SoundService
	som:Play()
	task.delay(15, function()
		som:Destroy() -- garantia se o Ended não vier (áudio que não carregou)
	end)
end

function SonsLocal.loop(nome: string, ligado: boolean)
	local som = loops[nome]
	if not som then
		if not ligado then
			return
		end
		local novo = criarSom(nome)
		if not novo then
			return
		end
		novo.Looped = true
		novo.Volume = 0
		novo.Parent = SoundService
		loops[nome] = novo
		som = novo
	end

	local cfg = Catalogo[nome]
	local fade = if cfg.grupo == "Ambiente" then FADE_AMBIENTE else FADE_CURTO
	local alvo = if ligado then cfg.volume else 0
	if ligado and not som.IsPlaying then
		som:Play()
	end
	local tween = TweenService:Create(som, TweenInfo.new(fade), { Volume = alvo })
	tween:Play()
	if not ligado then
		local ref = som
		tween.Completed:Once(function(estado)
			-- só para se ninguém religou o loop durante o fade
			if estado == Enum.PlaybackState.Completed and ref.Volume == 0 then
				ref:Stop()
			end
		end)
	end
end

local function coracaoPerto(): boolean
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local pasta = workspace:FindFirstChild("Monstros")
	if not (raiz and raiz:IsA("BasePart") and pasta) then
		return false
	end
	local limite = CfgCamera.monstroCacando.distancia
	for _, monstro in pasta:GetChildren() do
		if monstro:IsA("Model") and ESTADOS_CORACAO[monstro:GetAttribute("Estado")] then
			if (monstro:GetPivot().Position - raiz.Position).Magnitude <= limite then
				return true
			end
		end
	end
	return false
end

function SonsLocal.iniciar()
	garantirGrupos()
	for _, instancia in SoundService:GetChildren() do
		aplicarVolume(instancia)
	end
	SoundService.ChildAdded:Connect(aplicarVolume) -- grupos do servidor que chegam depois
	jogador:GetAttributeChangedSignal("Pref_Volume"):Connect(function()
		for _, instancia in SoundService:GetChildren() do
			aplicarVolume(instancia)
		end
	end)

	-- Ambiente: um loop por condição, trocando com fade
	local atual: string? = nil
	local function trocarAmbiente()
		local condicao = workspace:GetAttribute("Condicao")
		local loop = if type(condicao) == "string" then CONDICAO_PARA_LOOP[condicao] else nil
		if loop == atual then
			return
		end
		if atual then
			SonsLocal.loop(atual, false)
		end
		atual = loop
		if loop then
			SonsLocal.loop(loop, true)
		end
	end
	workspace:GetAttributeChangedSignal("Condicao"):Connect(trocarAmbiente)
	trocarAmbiente()

	-- Coração: batimento enquanto há monstro caçando por perto
	task.spawn(function()
		local ligado = false
		while true do
			task.wait(VARREDURA)
			local perto = coracaoPerto()
			if perto ~= ligado then
				ligado = perto
				SonsLocal.loop("Coracao", perto)
			end
		end
	end)
end

return SonsLocal
