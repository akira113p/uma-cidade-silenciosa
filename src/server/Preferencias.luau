-- Preferencias: guarda as preferências do jogador (atributos Pref_*) e as salva no DataStore. Dono: P2.
-- Contrato: docs/arquitetura.md §5 (Preferencias).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local ConfigCamera = require(Shared:WaitForChild("Config"):WaitForChild("Camera"))
local Limite = require(script.Parent.Limite)

local Preferencias = {}

local NOME_DATASTORE = "Preferencias_v1"
local INTERVALO_SALVAR = 1 -- s entre SalvarPreferencias do mesmo jogador
local ESPERA_GRAVACAO = 6 -- s; o DataStore tem 6 s de intervalo entre gravações da mesma chave
local TENTATIVAS_CARGA = 3

local padrao: { [string]: any } = ConfigCamera.preferenciasPadrao
local limites: { [string]: { number } } = ConfigCamera.limitesPreferencias

local datastore: DataStore? = nil
-- Studio sem acesso à API: uma falha desliga o DataStore pelo resto da sessão (não repete, não atrasa).
local datastoreIndisponivel = false

local sujo: { [Player]: boolean } = {} -- mudou algo que ainda não foi gravado
local gravacaoAgendada: { [Player]: boolean } = {}
local carregado: { [Player]: boolean } = {} -- terminou a leitura (com ou sem sucesso)

local function obterDatastore(): DataStore?
	if datastoreIndisponivel then
		return nil
	end
	if not datastore then
		local ok, resultado = pcall(function()
			return DataStoreService:GetDataStore(NOME_DATASTORE)
		end)
		if not ok then
			datastoreIndisponivel = true
			warn("[Preferencias] DataStore indisponível: " .. tostring(resultado))
			return nil
		end
		datastore = resultado
	end
	return datastore
end

-- Aceita só o tipo do padrão; número finito, arredondado e dentro do limite. nil = rejeitar.
local function validar(chave: string, valor: unknown): any
	local modelo = padrao[chave]
	if type(modelo) == "boolean" then
		if type(valor) == "boolean" then
			return valor
		end
		return nil
	end
	if type(modelo) == "number" then
		if type(valor) ~= "number" or valor ~= valor or valor == math.huge or valor == -math.huge then
			return nil
		end
		local faixa = limites[chave]
		local arredondado = math.floor(valor + 0.5)
		if faixa then
			return math.clamp(arredondado, faixa[1], faixa[2])
		end
		return arredondado
	end
	return nil
end

local function aplicarPadroes(jogador: Player)
	for chave, valor in padrao do
		jogador:SetAttribute(chave, valor)
	end
end

local function coletar(jogador: Player): { [string]: any }
	local dados = {}
	for chave in padrao do
		dados[chave] = Preferencias.obter(jogador, chave)
	end
	return dados
end

local function gravar(jogador: Player)
	sujo[jogador] = nil
	local ds = obterDatastore()
	if not ds or not carregado[jogador] then
		return
	end
	local dados = coletar(jogador)
	local ok, erro = pcall(function()
		ds:SetAsync(tostring(jogador.UserId), dados)
	end)
	if not ok then
		warn("[Preferencias] falha ao salvar " .. jogador.Name .. ": " .. tostring(erro))
		if RunService:IsStudio() then
			datastoreIndisponivel = true
		end
	end
end

-- Junta várias mudanças seguidas em uma gravação só.
local function agendarGravacao(jogador: Player)
	sujo[jogador] = true
	if gravacaoAgendada[jogador] then
		return
	end
	gravacaoAgendada[jogador] = true
	task.delay(ESPERA_GRAVACAO, function()
		gravacaoAgendada[jogador] = nil
		if sujo[jogador] and jogador.Parent == Players then
			gravar(jogador)
		end
	end)
end

local function carregar(jogador: Player)
	local ds = obterDatastore()
	local lido: any = nil
	if ds then
		for tentativa = 1, TENTATIVAS_CARGA do
			local ok, resultado = pcall(function()
				return ds:GetAsync(tostring(jogador.UserId))
			end)
			if ok then
				lido = resultado
				break
			end
			warn("[Preferencias] falha ao carregar " .. jogador.Name .. ": " .. tostring(resultado))
			if RunService:IsStudio() then
				datastoreIndisponivel = true
				break
			end
			if tentativa < TENTATIVAS_CARGA then
				task.wait(2 * tentativa)
			end
		end
	end
	if jogador.Parent ~= Players then
		return
	end
	if type(lido) == "table" then
		for chave in padrao do
			local valor = validar(chave, lido[chave])
			if valor ~= nil then
				jogador:SetAttribute(chave, valor)
			end
		end
	end
	carregado[jogador] = true
end

local function aoSalvarPedido(jogador: Player, prefs: unknown)
	if type(prefs) ~= "table" or not Limite.ok(jogador, "SalvarPreferencias", INTERVALO_SALVAR) then
		return
	end
	local mudou = false
	-- Só as chaves conhecidas são lidas; o resto da tabela do cliente é ignorado.
	for chave in padrao do
		local valor = validar(chave, (prefs :: { [string]: unknown })[chave])
		if valor ~= nil and jogador:GetAttribute(chave) ~= valor then
			jogador:SetAttribute(chave, valor)
			mudou = true
		end
	end
	if mudou then
		agendarGravacao(jogador)
	end
end

local function aoSair(jogador: Player)
	if sujo[jogador] then
		gravar(jogador)
	end
	sujo[jogador] = nil
	gravacaoAgendada[jogador] = nil
	carregado[jogador] = nil
end

local function aoEntrar(jogador: Player)
	aplicarPadroes(jogador)
	carregar(jogador)
end

function Preferencias.obter(jogador: Player, chave: string): any
	local valor = jogador:GetAttribute(chave)
	if valor == nil then
		return padrao[chave]
	end
	return valor
end

function Preferencias.iniciar()
	Rede.evento("SalvarPreferencias").OnServerEvent:Connect(aoSalvarPedido)
	Players.PlayerAdded:Connect(function(jogador)
		task.spawn(aoEntrar, jogador)
	end)
	Players.PlayerRemoving:Connect(aoSair)
	for _, jogador in Players:GetPlayers() do
		-- Os atributos de padrão saem já; a leitura do DataStore vem em seguida sem bloquear.
		task.spawn(aoEntrar, jogador)
	end
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, jogador in Players:GetPlayers() do
			if sujo[jogador] then
				task.spawn(gravar, jogador)
			end
		end
		task.wait(2)
	end)
end

return Preferencias
