-- Sobrevivencia: fome, sede, calor e estamina de cada jogador (atributos no Player). Dono: P5.
-- Contrato: docs/arquitetura.md §5 Sobrevivencia. Fórmulas em Regras/Sobrevivencia; aqui só o laço e o dano por barra zerada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Sobrevivencia"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Sobrevivencia"))
local Vida = require(script.Parent:WaitForChild("Vida"))

local Sobrevivencia = {}

local VELOCIDADE_MOVENDO = 1 -- studs/s horizontais: abaixo disso o personagem conta como parado
local DT_MAXIMO = 2 -- s: teto do passo (servidor engasgado não pode zerar a barra de uma vez)

local BARRAS = { Fome = true, Sede = true, Calor = true, Estamina = true }
local ORDEM_ATRIBUTOS = { "Fome", "Sede", "Calor", "Estamina" }

local AVISOS = {
	{ barra = "Fome", texto = "Você está com fome.", limite = Cfg.estamina.fomeBaixa },
	{ barra = "Sede", texto = "Você está com sede.", limite = Cfg.estamina.fomeBaixa },
	{ barra = "Calor", texto = "Você está com frio.", limite = Cfg.calorBaixo },
}

type Barras = { Fome: number, Sede: number, Calor: number, Estamina: number }

type Estado = {
	barras: Barras,
	semCorrer: number, -- s desde que parou de correr
	ultimo: number?, -- os.clock() do último passo
	tFome: number, -- s com a barra zerada, para o dano no intervalo do Config
	tSede: number,
	tFrio: number,
	avisado: { [string]: boolean }, -- aviso de barra baixa já mostrado (limpa quando a barra sobe)
}

local estados: { [Player]: Estado } = {}

-- Módulos de outras partes: carregados sob demanda e tolerando ausência (as partes são escritas em paralelo).
local function modulo(nome: string): any?
	local arquivo = script.Parent:FindFirstChild(nome)
	if not arquivo then
		return nil
	end
	local ok, resultado = pcall(require, arquivo)
	if ok then
		return resultado
	end
	warn("[Sobrevivencia] erro ao carregar " .. nome .. ": " .. tostring(resultado))
	return nil
end

local function condicaoAtual(): string
	local Ambiente = modulo("Ambiente")
	if Ambiente then
		local ok, condicao = pcall(Ambiente.condicao)
		if ok and condicao then
			return condicao
		end
	end
	-- INTEGRACAO: Ambiente (P3) ausente; usa o atributo que ele publica no workspace, ou "dia".
	return workspace:GetAttribute("Condicao") or "dia"
end

local function escrever(jogador: Player, barras: Barras)
	for _, nome in ORDEM_ATRIBUTOS do
		-- uma casa decimal: o atributo só replica quando muda de verdade
		jogador:SetAttribute(nome, math.floor(barras[nome] * 10 + 0.5) / 10)
	end
end

local function novoEstado(): Estado
	return {
		barras = table.clone(Cfg.inicial),
		semCorrer = 0,
		ultimo = nil,
		tFome = 0,
		tSede = 0,
		tFrio = 0,
		avisado = {},
	}
end

local function reiniciar(jogador: Player)
	local estado = novoEstado()
	estados[jogador] = estado
	escrever(jogador, estado.barras)
end

function Sobrevivencia.alterar(jogador: Player, barra: string, delta: number)
	local estado = estados[jogador]
	if not estado or not BARRAS[barra] then
		warn("[Sobrevivencia] alterar: barra inválida: " .. tostring(barra))
		return
	end
	if type(delta) ~= "number" or delta ~= delta or math.abs(delta) == math.huge then
		return
	end
	estado.barras[barra] = math.clamp(estado.barras[barra] + delta, 0, Cfg.maximo)
	escrever(jogador, estado.barras)
end

-- Dano por barra zerada: acumula tempo e bate a cada `intervalo`.
local function cobrar(acumulado: number, zerada: boolean, dt: number, intervalo: number): (number, boolean)
	if not zerada then
		return 0, false
	end
	acumulado += dt
	if acumulado >= intervalo then
		return acumulado - intervalo, true
	end
	return acumulado, false
end

local function passo(jogador: Player, estado: Estado, dt: number, condicao: string)
	local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local velocidade = 0
	if raiz then
		local v = raiz.AssemblyLinearVelocity
		velocidade = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	local movendo = velocidade > VELOCIDADE_MOVENDO
	-- Correndo é "tecla segurada" (Movimento); só gasta estamina e comida se o personagem está andando de fato.
	local correndo = jogador:GetAttribute("Correndo") == true and movendo

	local barras, zeradas = Regra.passo(estado.barras, dt, {
		correndo = correndo,
		agachadoParado = jogador:GetAttribute("Agachado") == true and not movendo,
		condicao = condicao,
		dentro = false, -- corte vertical: construções são blocos
		pertoFogo = false,
		tempoSemCorrer = estado.semCorrer,
	}, Cfg)
	estado.barras = barras
	estado.semCorrer = if correndo then 0 else estado.semCorrer + dt
	escrever(jogador, barras)

	for _, a in AVISOS do
		if barras[a.barra] < a.limite then
			if not estado.avisado[a.barra] then
				estado.avisado[a.barra] = true
				Rede.evento("Aviso"):FireClient(jogador, a.texto)
			end
		else
			estado.avisado[a.barra] = false
		end
	end

	local vazio, frio = Cfg.danoVazio, Cfg.danoCongelando
	local bateFome, bateSede, bateFrio
	estado.tFome, bateFome = cobrar(estado.tFome, zeradas.fome, dt, vazio.intervalo)
	estado.tSede, bateSede = cobrar(estado.tSede, zeradas.sede, dt, vazio.intervalo)
	estado.tFrio, bateFrio = cobrar(estado.tFrio, zeradas.frio, dt, frio.intervalo)
	if bateFome then
		Vida.dano(jogador, vazio.parte, vazio.valor, { tipo = "fome" })
	end
	if bateSede and Vida.estaVivo(jogador) then
		Vida.dano(jogador, vazio.parte, vazio.valor, { tipo = "sede" })
	end
	if bateFrio and Vida.estaVivo(jogador) then
		Vida.danoTodas(jogador, frio.valor, { tipo = "frio" })
	end
end

local function resumo(jogador: Player): string
	local partes = {}
	for _, nome in ORDEM_ATRIBUTOS do
		table.insert(partes, string.format("%s=%.1f", nome, jogador:GetAttribute(nome) or -1))
	end
	return table.concat(partes, " ")
end

local function registrar(jogador: Player)
	reiniciar(jogador)
	jogador.CharacterAdded:Connect(function()
		reiniciar(jogador)
	end)
end

function Sobrevivencia.iniciar()
	Players.PlayerAdded:Connect(registrar)
	for _, jogador in Players:GetPlayers() do
		registrar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		estados[jogador] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Cfg.tick)
			local condicao = condicaoAtual()
			local agora = os.clock()
			for _, jogador in Players:GetPlayers() do
				local estado = estados[jogador]
				if not estado then
					continue
				end
				if not Vida.estaVivo(jogador) then
					estado.ultimo = nil
					continue
				end
				local dt = if estado.ultimo then math.min(agora - estado.ultimo, DT_MAXIMO) else 0
				estado.ultimo = agora
				if dt > 0 then
					passo(jogador, estado, dt, condicao)
				end
			end
		end
	end)

	local Teste = modulo("Teste")
	if Teste then
		-- "barras"(fome?, sede?, calor?, estamina?): define as barras; nil mantém a atual
		Teste.registrar(
			"barras",
			function(jogador: Player, fome: number?, sede: number?, calor: number?, estamina: number?)
				local estado = estados[jogador]
				if not estado then
					return "sem estado para " .. jogador.Name
				end
				local novos = { Fome = fome, Sede = sede, Calor = calor, Estamina = estamina }
				for nome, valor in novos do
					estado.barras[nome] = math.clamp(valor, 0, Cfg.maximo)
				end
				escrever(jogador, estado.barras)
				return resumo(jogador)
			end
		)
	end
end

return Sobrevivencia
