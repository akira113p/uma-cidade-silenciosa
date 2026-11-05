-- Visual: relógio do dia/noite e a luz que o acompanha (Config/Tempo), e o clima (atributo workspace.Clima). Dono: P1.
-- Contrato: docs/arquitetura.md §P1. Admin e Teste mudam a hora por Visual.definirHora / Visual.congelar.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tempo = require(Shared:WaitForChild("Config"):WaitForChild("Tempo"))
local Luz = require(Shared:WaitForChild("Regras"):WaitForChild("Luz"))

local Visual = {}

local INTERVALO = 0.25 -- s entre atualizações do relógio e da luz

local congelado = false
-- Multiplicadores do clima, suavizados em direção ao clima atual
local mult = { brilho = 1, neblina = 1 }
local clima = Tempo.luz.climas[Tempo.climaPadrao] or Tempo.luz.climas.limpo
-- Efeitos do Lighting (criados pelo default.project.json); nil se faltar, e a luz segue sem eles
local efeitos: { cor: ColorCorrectionEffect?, brilho: BloomEffect?, profundidade: DepthOfFieldEffect? } = {}

local function cor(t: { number }): Color3
	return Color3.new(t[1], t[2], t[3])
end

local function misturar(a: { number }, b: { number }, f: number): Color3
	return cor(a):Lerp(cor(b), f)
end

local function numeros(n: number, d: number, f: number): number
	return n + (d - n) * f
end

local function aplicarLuz(dt: number)
	local f = Luz.luzDaHora(Lighting.ClockTime)
	local n, d = Tempo.luz.noite, Tempo.luz.dia

	-- Aproxima o multiplicador do clima do alvo (transicaoClima s para chegar)
	local passo = math.min(1, dt / Tempo.luz.transicaoClima)
	mult.brilho += (clima.brilho - mult.brilho) * passo
	mult.neblina += (clima.neblina - mult.neblina) * passo

	Lighting.Ambient = misturar(n.ambient, d.ambient, f)
	Lighting.OutdoorAmbient = misturar(n.outdoor, d.outdoor, f)
	Lighting.Brightness = numeros(n.brilho, d.brilho, f) * mult.brilho

	-- Névoa (sem Atmosphere). Mais perto no mau tempo.
	Lighting.FogColor = misturar(n.neblinaCor, d.neblinaCor, f)
	Lighting.FogStart = numeros(n.neblinaInicio, d.neblinaInicio, f) * mult.neblina
	Lighting.FogEnd = numeros(n.neblinaFim, d.neblinaFim, f) * mult.neblina

	-- Cor, bloom e profundidade (sempre ligados aqui; o cliente liga/desliga Retro e Cor pela preferência)
	if efeitos.cor then
		efeitos.cor.Saturation = numeros(n.cor.saturacao, d.cor.saturacao, f)
		efeitos.cor.Contrast = numeros(n.cor.contraste, d.cor.contraste, f)
		efeitos.cor.Brightness = numeros(n.cor.brilho, d.cor.brilho, f)
		efeitos.cor.TintColor = misturar(n.cor.tint, d.cor.tint, f)
	end
	if efeitos.brilho then
		efeitos.brilho.Intensity = numeros(n.bloom.intensidade, d.bloom.intensidade, f)
		efeitos.brilho.Size = numeros(n.bloom.tamanho, d.bloom.tamanho, f)
		efeitos.brilho.Threshold = numeros(n.bloom.limiar, d.bloom.limiar, f)
	end
	if efeitos.profundidade then
		efeitos.profundidade.FocusDistance = numeros(n.profundidade.distanciaFoco, d.profundidade.distanciaFoco, f)
		efeitos.profundidade.InFocusRadius = numeros(n.profundidade.raioFoco, d.profundidade.raioFoco, f)
		efeitos.profundidade.FarIntensity = numeros(n.profundidade.intensidadeLonge, d.profundidade.intensidadeLonge, f)
		efeitos.profundidade.NearIntensity = 0
	end
end

-- Hora do dia (0..24). Usada pelo Admin e pelo comando de teste "hora".
function Visual.definirHora(hora: number)
	Lighting.ClockTime = hora % 24
	aplicarLuz(0)
end

function Visual.congelar(ligado: boolean)
	congelado = ligado
end

function Visual.estaCongelado(): boolean
	return congelado
end

function Visual.iniciar()
	Lighting.ClockTime = Tempo.horaInicial
	workspace:SetAttribute("Clima", Tempo.climaPadrao)

	-- Com Atmosphere no Lighting a névoa (FogStart/FogEnd/FogColor) é ignorada: não pode existir nenhuma.
	local achou = false
	for _, atm in Lighting:GetChildren() do
		if atm:IsA("Atmosphere") then
			atm:Destroy()
			achou = true
		end
	end
	if achou then
		warn("[Visual] Atmosphere removida do Lighting: ela anula a névoa (Fog*). Use só a névoa do Lighting.")
	end
	efeitos.cor = Lighting:FindFirstChild("Cor") :: ColorCorrectionEffect?
	efeitos.brilho = Lighting:FindFirstChild("Brilho") :: BloomEffect?
	efeitos.profundidade = Lighting:FindFirstChild("Profundidade") :: DepthOfFieldEffect?

	workspace:GetAttributeChangedSignal("Clima"):Connect(function()
		local nome = workspace:GetAttribute("Clima")
		local novo = type(nome) == "string" and Tempo.luz.climas[nome]
		if novo then
			clima = novo
		end
	end)
	aplicarLuz(0)

	local horasPorSegundo = 24 / (Tempo.minutosReaisPorDia * 60)
	task.spawn(function()
		while true do
			local dt = task.wait(INTERVALO)
			if not congelado then
				Lighting.ClockTime = (Lighting.ClockTime + dt * horasPorSegundo) % 24
			end
			aplicarLuz(dt)
		end
	end)

	local Teste = require(script.Parent.Teste)
	Teste.registrar("hora", function(_, h: number?)
		if type(h) ~= "number" or h ~= h or h < 0 or h > 24 then
			return "uso: hora(0..24)"
		end
		Visual.definirHora(h)
		return "ClockTime = " .. tostring(Lighting.ClockTime)
	end)
	Teste.registrar("clima", function(_, nome: string?)
		if type(nome) ~= "string" or not Tempo.luz.climas[nome] then
			return 'uso: clima("limpo" | "chuva" | "tempestade")'
		end
		workspace:SetAttribute("Clima", nome)
		return "Clima = " .. nome
	end)
end

return Visual
