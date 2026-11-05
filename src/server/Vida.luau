-- Vida: vida por partes do corpo, dano, cura, morte e dano de queda. Dono: P5. Contrato: docs/arquitetura.md §5 Vida.
-- O Humanoid.Health NÃO é a vida do jogo: fica em 100 e só zera na morte (a vida real são os atributos Vida_*).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Corpo = require(Shared:WaitForChild("Regras"):WaitForChild("Corpo"))
local CfgCorpo = require(Shared:WaitForChild("Config"):WaitForChild("Corpo"))
local CfgMonstros = require(Shared:WaitForChild("Config"):WaitForChild("Monstros"))

export type FonteDano = {
	tipo: "monstro" | "jogador" | "queda" | "fome" | "sede" | "frio" | "batida",
	jogador: Player?,
	direcao: Vector3?,
}

local Vida = {}

local VIDA_HUMANOIDE = 100 -- contrato: Humanoid.MaxHealth = Health = 100 enquanto vivo
local GRACA_SPAWN = 2 -- s após nascer sem dano de queda (o Spawn teleporta o personagem)
local DANO_MAXIMO = 1000 -- teto para um valor absurdo vindo de outra parte

local AVISO_PARTE_ZERADA = {
	BracoE = "Braço esquerdo inutilizado: sem arma de duas mãos.",
	BracoD = "Braço direito inutilizado: sem arma de duas mãos.",
	PernaE = "Perna esquerda inutilizada: mais lento e sem correr.",
	PernaD = "Perna direita inutilizada: mais lento e sem correr.",
}

local corpos: { [Player]: { [string]: number } } = {}
local ligacoes: { [Player]: { RBXScriptConnection } } = {}
local nascimento: { [Player]: number } = {}
local callbacksMorte: { (jogador: Player, causa: string, posicao: Vector3) -> () } = {}

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
	warn("[Vida] erro ao carregar " .. nome .. ": " .. tostring(resultado))
	return nil
end

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

local function escrever(jogador: Player, corpo: { [string]: number })
	for _, parte in CfgCorpo.ordem do
		jogador:SetAttribute("Vida_" .. parte, corpo[parte])
	end
	jogador:SetAttribute("MultVelocidade", Corpo.multVelocidade(corpo, CfgCorpo))
	jogador:SetAttribute("PodeCorrer", Corpo.podeCorrer(corpo))
	jogador:SetAttribute("BracoZerado", Corpo.bracoZerado(corpo))
end

local function reiniciar(jogador: Player)
	local corpo = Corpo.novo(CfgCorpo)
	corpos[jogador] = corpo
	escrever(jogador, corpo)
	jogador:SetAttribute("Morto", false)
end

local function limpar(jogador: Player)
	local lista = ligacoes[jogador]
	if lista then
		for _, ligacao in lista do
			ligacao:Disconnect()
		end
	end
	ligacoes[jogador] = nil
end

local function matar(jogador: Player, causa: string)
	if jogador:GetAttribute("Morto") == true then
		return
	end
	jogador:SetAttribute("Morto", true)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local posicao = if raiz then raiz.Position else Vector3.zero
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.Health = 0
	end
	Rede.evento("Morreu"):FireClient(jogador, causa)
	for _, callback in callbacksMorte do
		task.spawn(callback, jogador, causa, posicao)
	end
end

local function tocarDor(jogador: Player)
	local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
	local Sons = modulo("Sons")
	if raiz and Sons then
		Sons.tocar("Dor", raiz)
	end
end

-- Aplica uma lista de { parte, valor } de uma vez: um só evento Dano, um só som, uma só checagem de morte.
local function aplicar(jogador: Player, lista: { { parte: string, valor: number } }, fonte: FonteDano)
	local antes = corpos[jogador]
	-- "Imortal" é do menu de admin (server/Admin.luau)
	if not antes or jogador:GetAttribute("Morto") == true or jogador:GetAttribute("Imortal") == true then
		return
	end
	local corpo = antes
	local total = 0
	local morreu = false
	for _, item in lista do
		local m
		corpo, m = Corpo.dano(corpo, item.parte, item.valor, CfgCorpo)
		morreu = morreu or m
		total += item.valor
	end
	corpos[jogador] = corpo
	escrever(jogador, corpo)

	Rede.evento("Dano"):FireClient(jogador, lista[1].parte, total, fonte.direcao)
	tocarDor(jogador)
	if not morreu then
		for parte, texto in AVISO_PARTE_ZERADA do
			if antes[parte] > 0 and corpo[parte] <= 0 then
				aviso(jogador, texto)
			end
		end
	end
	if morreu then
		matar(jogador, fonte.tipo)
	end
end

local function valorValido(valor: any): boolean
	return type(valor) == "number" and valor == valor and valor > 0
end

function Vida.dano(jogador: Player, parte: string?, valor: number, fonte: FonteDano)
	if not valorValido(valor) then
		return
	end
	if parte ~= nil and CfgCorpo.partes[parte] == nil then
		warn("[Vida] parte desconhecida '" .. tostring(parte) .. "': sorteando")
		parte = nil
	end
	local alvo = parte or Corpo.sortearParte(CfgMonstros.sorteioParte, math.random)
	aplicar(jogador, { { parte = alvo, valor = math.min(valor, DANO_MAXIMO) } }, fonte)
end

-- Extra (não está no §5): o mesmo valor em TODAS as partes de uma vez (frio). Um evento Dano, um som.
function Vida.danoTodas(jogador: Player, valor: number, fonte: FonteDano)
	if not valorValido(valor) then
		return
	end
	local lista = {}
	for _, parte in CfgCorpo.ordem do
		table.insert(lista, { parte = parte, valor = math.min(valor, DANO_MAXIMO) })
	end
	aplicar(jogador, lista, fonte)
end

function Vida.curar(jogador: Player, valor: number): string?
	local corpo = corpos[jogador]
	if not corpo or jogador:GetAttribute("Morto") == true or not valorValido(valor) then
		return nil
	end
	local novo, parte = Corpo.curar(corpo, valor, CfgCorpo)
	if parte then
		corpos[jogador] = novo
		escrever(jogador, novo)
	end
	return parte
end

function Vida.estaVivo(jogador: Player): boolean
	return corpos[jogador] ~= nil and jogador:GetAttribute("Morto") ~= true and jogador.Character ~= nil
end

function Vida.aoMorrer(callback: (jogador: Player, causa: string, posicao: Vector3) -> ())
	table.insert(callbacksMorte, callback)
end

local function aoAterrissar(jogador: Player, altura: number)
	if os.clock() - (nascimento[jogador] or 0) < GRACA_SPAWN then
		return
	end
	local total = Corpo.danoQueda(altura, CfgCorpo)
	if total > 0 then
		aplicar(jogador, { { parte = "PernaE", valor = total / 2 }, { parte = "PernaD", valor = total / 2 } }, {
			tipo = "queda",
		})
	end
end

local function aoPersonagem(jogador: Player, personagem: Model)
	limpar(jogador)
	reiniciar(jogador)
	nascimento[jogador] = os.clock()
	local lista: { RBXScriptConnection } = {}
	ligacoes[jogador] = lista

	local humanoide = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
	local raiz = personagem:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoide or not raiz or ligacoes[jogador] ~= lista then
		return
	end

	humanoide.MaxHealth = VIDA_HUMANOIDE
	humanoide.Health = VIDA_HUMANOIDE

	-- sem regeneração padrão
	local regen = personagem:FindFirstChild("Health")
	if regen and regen:IsA("BaseScript") then
		regen:Destroy()
	end
	table.insert(
		lista,
		personagem.ChildAdded:Connect(function(filho)
			if filho.Name == "Health" and filho:IsA("BaseScript") then
				filho:Destroy()
			end
		end)
	)
	-- qualquer outra fonte de dano/cura do Roblox é desfeita enquanto vivo
	table.insert(
		lista,
		humanoide.HealthChanged:Connect(function(saude)
			if saude > 0 and saude < humanoide.MaxHealth and jogador:GetAttribute("Morto") ~= true then
				humanoide.Health = humanoide.MaxHealth
			end
		end)
	)
	-- morte vinda de fora (vazio, reset): conta como morte do jogo
	table.insert(
		lista,
		humanoide.Died:Connect(function()
			matar(jogador, "vazio")
		end)
	)

	-- dano de queda: altura = ponto mais alto da queda livre − posição ao pousar
	local topo: number? = nil
	table.insert(
		lista,
		RunService.Heartbeat:Connect(function()
			if topo and raiz.Position.Y > topo then
				topo = raiz.Position.Y
			end
		end)
	)
	table.insert(
		lista,
		humanoide.StateChanged:Connect(function(antigo, novo)
			if novo == Enum.HumanoidStateType.Freefall then
				topo = raiz.Position.Y
			elseif antigo == Enum.HumanoidStateType.Freefall then
				local alto = topo
				topo = nil
				if novo == Enum.HumanoidStateType.Landed and alto then
					aoAterrissar(jogador, alto - raiz.Position.Y)
				end
			end
		end)
	)
end

local function registrar(jogador: Player)
	reiniciar(jogador)
	jogador.CharacterAdded:Connect(function(personagem)
		aoPersonagem(jogador, personagem)
	end)
	jogador.CharacterRemoving:Connect(function()
		limpar(jogador)
	end)
	if jogador.Character then
		task.spawn(aoPersonagem, jogador, jogador.Character)
	end
end

local function resumo(jogador: Player): string
	local partes = {}
	for _, parte in CfgCorpo.ordem do
		table.insert(partes, string.format("%s=%.1f", parte, jogador:GetAttribute("Vida_" .. parte) or -1))
	end
	table.insert(partes, string.format("Mult=%.2f", jogador:GetAttribute("MultVelocidade") or -1))
	table.insert(partes, "PodeCorrer=" .. tostring(jogador:GetAttribute("PodeCorrer")))
	table.insert(partes, "BracoZerado=" .. tostring(jogador:GetAttribute("BracoZerado")))
	table.insert(partes, "Morto=" .. tostring(jogador:GetAttribute("Morto")))
	return table.concat(partes, " ")
end

function Vida.iniciar()
	Players.PlayerAdded:Connect(registrar)
	for _, jogador in Players:GetPlayers() do
		registrar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		limpar(jogador)
		corpos[jogador] = nil
		nascimento[jogador] = nil
	end)

	local Teste = modulo("Teste")
	if Teste then
		-- "dano"(parte?, valor?): parte nil = sorteio de monstro; valor padrão 10
		Teste.registrar("dano", function(jogador: Player, parte: string?, valor: number?)
			Vida.dano(jogador, parte, valor or 10, { tipo = "monstro" })
			return resumo(jogador)
		end)
		Teste.registrar("curar", function(jogador: Player, valor: number?)
			local parte = Vida.curar(jogador, valor or 15)
			return tostring(parte) .. " | " .. resumo(jogador)
		end)
	end
end

return Vida
