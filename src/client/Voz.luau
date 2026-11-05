-- Voz: lê o nível do microfone (AudioDeviceInput → Wire → AudioAnalyzer) e avisa o servidor. Dono: P3.
-- Sem chat de voz o módulo não faz nada. Tudo em pcall: voz é opcional e nunca pode derrubar o resto.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))

local Voz = {}

local HZ = 4 -- leituras por segundo (o servidor aceita no máximo 1 a cada Config/Som.voz.intervalo)
local BUSCA = 3 -- s entre tentativas de achar o AudioDeviceInput (o chat de voz pode ligar depois)
local BUSCA_SEM_VOZ = 30 -- s entre consultas quando a voz está desligada

-- O AudioDeviceInput do jogador local nasce como filho do Player quando o chat de voz está ligado
local function acharEntrada(jogador: Player): AudioDeviceInput?
	return jogador:FindFirstChildWhichIsA("AudioDeviceInput")
end

-- Voz desligada na conta/jogo → nem procura. Se a consulta falhar, assume que pode haver voz.
local function vozPermitida(jogador: Player): boolean
	local ok, habilitada = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(jogador.UserId)
	end)
	return not ok or habilitada == true
end

local function ligar(entrada: AudioDeviceInput): (AudioAnalyzer, { Instance })
	local analisador = Instance.new("AudioAnalyzer")
	analisador.Name = "VozAnalisador"
	analisador.Parent = SoundService

	local fio = Instance.new("Wire")
	fio.Name = "VozFio"
	fio.SourceInstance = entrada
	fio.TargetInstance = analisador
	fio.Parent = SoundService
	return analisador, { analisador, fio }
end

-- Fica de olho no microfone enquanto o AudioDeviceInput existir; devolve quando ele some
local function monitorar(entrada: AudioDeviceInput, eventoVoz: RemoteEvent)
	local analisador, criados = ligar(entrada)
	while entrada.Parent ~= nil do
		task.wait(1 / HZ)
		local lido, rms = pcall(function()
			return analisador.RmsLevel
		end)
		if lido and type(rms) == "number" and not entrada.Muted then
			local db = Som.vozParaDb(rms)
			if db >= CfgSom.voz.minimo then
				eventoVoz:FireServer(db)
			end
		end
	end
	for _, instancia in criados do
		instancia:Destroy()
	end
end

function Voz.iniciar()
	task.spawn(function()
		local jogador = Players.LocalPlayer
		local eventoVoz = Rede.evento("Voz")
		while true do
			local ok, erro = pcall(function()
				if not vozPermitida(jogador) then
					task.wait(BUSCA_SEM_VOZ)
					return
				end
				local entrada = acharEntrada(jogador)
				if entrada then
					monitorar(entrada, eventoVoz)
				else
					task.wait(BUSCA)
				end
			end)
			if not ok then
				-- sem voz é caso normal; o log mostra o motivo uma vez e o laço segue devagar
				print("[Voz] erro: " .. tostring(erro))
				task.wait(BUSCA_SEM_VOZ)
			end
		end
	end)
end

return Voz
