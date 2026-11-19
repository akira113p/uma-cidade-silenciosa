-- AnimacaoCorpo (cliente): liga os gatilhos do jogo aos clipes de corpo (assets/animacoes/corpo: carro, mundo, mao, vida) em TODOS
-- os personagens que este cliente vê (cada cliente toca no Animator de cada um; o registro em runtime não vale entre clientes).
-- Dono: A1 (docs/personagens.md §2/A1 e §4). Quem decide é o servidor; aqui só se MOSTRA o que já está replicado:
--   * assento: Humanoid.SeatPart (banco de um modelo com atributo Veiculo): VehicleSeat = motorista, Seat = passageiro; Entrar/Sair,
--     MotoristaIdle/PassageiroIdle e a curva (SteerFloat do VehicleSeat -> MotoristaViraEsquerda/Direita com peso);
--   * item na mão: modelo "ItemNaMao" no personagem (atributo Item, solda SoldaMao na mão) -> SegurarUmaMao/Esq/Galao; atributo
--     Usando do Player -> Usar; atributo Mangueira do Player -> Abastecer;
--   * vida: Humanoid.Died -> Morte (congela no marcador Congelar); FreeFalling -> Queda/Aterrissagem (só queda longa);
--   * só no jogador local: Pegar/Largar (evento Inventario casado com workspace.ItensChao perto) e Interagir (ProximityPrompt).
-- Agachar fica PROCEDURAL (server/Movimento.luau mexe no C0 das juntas): sem clipe aqui de propósito.
-- Tolerante: sem Animator, sem dado ou sem clipe = não faz aquela parte, sem erro. Nenhum evento de rede novo.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Rede = require(Shared:WaitForChild("Rede"))
local Animacao = require(Shared:WaitForChild("Animacao"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Animacao"))
local Cfg = require(Config:WaitForChild("AnimacoesCorpo"))
local CfgItens = require(Config:WaitForChild("Itens"))
local CfgCombustivel = require(Config:WaitForChild("Combustivel"))

local AnimacaoCorpo = {}

local jogador = Players.LocalPlayer

local G = {
	carro = "corpo/carro",
	mundo = "corpo/mundo",
	mao = "corpo/mao",
	vida = "corpo/vida",
}

type Ator = {
	jogador: Player,
	ehMeu: boolean,
	personagem: Model,
	humanoide: Humanoid,
	animator: Animator?,
	desejado: { [string]: { grupo: string, clipe: string }? }, -- canal -> clipe que deveria estar tocando
	tocando: { [string]: string? }, -- canal -> clipe que está tocando
	faixas: { [string]: AnimationTrack? },
	vira: { Esquerda: AnimationTrack?, Direita: AnimationTrack? },
	assento: BasePart?,
	emCarro: boolean,
	assentoId: number,
	noAr: number?,
	quedaTocou: boolean,
	morto: boolean,
	maoDireita: string?, -- clipe da mão direita (nil = nada na mão)
	itemDireita: string?,
	ligacoes: { RBXScriptConnection },
}

local atores: { [Player]: Ator } = {}
local comVolante: { [Ator]: boolean } = {}

-- Util ------------------------------------------------------------------------------------------------------------------------

local function trilha(a: Ator, grupo: string, clipe: string): AnimationTrack?
	if not a.animator then
		return nil
	end
	return Animacao.trilha(a.animator, grupo, clipe)
end

-- Clipe de uma vez só (reinicia se já estiver tocando). Devolve a trilha.
local function tocarUma(a: Ator, grupo: string, clipe: string, velocidade: number?): AnimationTrack?
	if a.morto then
		return nil
	end
	local t = trilha(a, grupo, clipe)
	if not t then
		return nil
	end
	if t.IsPlaying then
		t.TimePosition = 0
		t:AdjustSpeed(velocidade or 1)
	else
		t:Play(Cfg.fade.entrar, 1, velocidade or 1)
	end
	return t
end

-- Canal de repouso: um clipe em laço por vez (assento, mao, maoEsq, mangueira, queda).
local function sincronizar(a: Ator, canal: string)
	if not a.animator then
		return
	end
	local quer = a.desejado[canal]
	local atual = a.tocando[canal]
	if (quer and quer.clipe) == atual then
		return
	end
	local velha = a.faixas[canal]
	if velha then
		velha:Stop(Cfg.fade.repouso)
		a.faixas[canal] = nil
	end
	a.tocando[canal] = nil
	if quer then
		local t = trilha(a, quer.grupo, quer.clipe)
		if t then
			t:Play(Cfg.fade.repouso)
			a.faixas[canal] = t
			a.tocando[canal] = quer.clipe
		end
	end
end

local function definirCanal(a: Ator, canal: string, grupo: string?, clipe: string?)
	if a.morto then
		clipe = nil
	end
	a.desejado[canal] = if grupo and clipe then { grupo = grupo, clipe = clipe } else nil
	sincronizar(a, canal)
end

local function pararVira(a: Ator)
	for _, nome in { "Esquerda", "Direita" } do
		local t = (a.vira :: any)[nome] :: AnimationTrack?
		if t and t.IsPlaying then
			t:Stop(Cfg.fade.volante)
		end
	end
end

-- Assento -------------------------------------------------------------------------------------------------------------------

local function carroDe(assento: Instance?): Model?
	local atual = assento
	while atual and atual ~= workspace do
		if atual:IsA("Model") and atual:GetAttribute("Veiculo") == true then
			return atual
		end
		atual = atual.Parent
	end
	return nil
end

local avaliarMao: (Ator) -> ()

local function aoAssento(a: Ator)
	local assento = a.humanoide.SeatPart
	local carro = carroDe(assento)
	local repouso = if carro and assento then Regra.clipeAssento(assento.ClassName) else nil
	if repouso and assento then
		local entrou = not a.emCarro
		a.emCarro = true
		a.assento = assento
		a.assentoId += 1
		local meu = a.assentoId
		local espera = 0
		if entrou then
			if tocarUma(a, G.carro, "Entrar") then
				espera = Animacao.duracao(G.carro, "Entrar") * 0.7 -- o Idle entra por cima do fim do Entrar
			end
		end
		pararVira(a)
		comVolante[a] = if assento:IsA("VehicleSeat") then true else nil
		local function repousar()
			if meu == a.assentoId and a.assento == assento then
				definirCanal(a, "assento", G.carro, repouso)
			end
		end
		if espera > 0 then
			task.delay(espera, repousar)
		else
			repousar()
		end
		avaliarMao(a)
	else
		a.assento = nil
		a.assentoId += 1
		comVolante[a] = nil
		pararVira(a)
		definirCanal(a, "assento", nil, nil)
		if a.emCarro then
			a.emCarro = false
			tocarUma(a, G.carro, "Sair")
			avaliarMao(a)
		end
	end
end

-- Curva: o peso do clipe acompanha SteerFloat do VehicleSeat (replicado pelo cliente do motorista).
local function atualizarVolante(a: Ator)
	local assento = a.assento
	local lado: string? = nil
	local peso = 0
	if assento and assento:IsA("VehicleSeat") and a.tocando.assento == "MotoristaIdle" and not a.morto then
		lado, peso = Regra.volante(assento.SteerFloat, Cfg.volante.zonaMorta)
	end
	for _, nome in { "Esquerda", "Direita" } do
		local t = (a.vira :: any)[nome] :: AnimationTrack?
		if nome == lado and peso > 0 then
			if not t then
				t = trilha(a, G.carro, "MotoristaVira" .. nome)
				local vira: any = a.vira
				vira[nome] = t
			end
			if t then
				if not t.IsPlaying then
					t:Play(Cfg.fade.volante, peso)
				end
				t:AdjustWeight(peso, Cfg.fade.volante)
			end
		elseif t and t.IsPlaying then
			t:Stop(Cfg.fade.volante)
		end
	end
end

-- Item na mão ---------------------------------------------------------------------------------------------------------------

local function ladoDe(modelo: Instance, id: string?): string
	local solda = modelo:FindFirstChild("SoldaMao", true)
	local parte = solda and (solda :: any).Part0
	if parte then
		return if parte.Name == "LeftHand" then "esquerda" else "direita"
	end
	return if id == "lanterna" then "esquerda" else "direita"
end

local function litrosDe(id: string?): number?
	local def = id and (CfgCombustivel.recipientes :: any)[id]
	if def then
		return def.capacidade or def.litros
	end
	return nil
end

avaliarMao = function(a: Ator)
	local direita: string? = nil
	local esquerda: string? = nil
	local itemDireita: string? = nil
	if not a.emCarro then
		for _, filho in a.personagem:GetChildren() do
			if filho.Name == "ItemNaMao" and filho:IsA("Model") then
				local id = filho:GetAttribute("Item")
				id = if type(id) == "string" then id else nil
				local lado = ladoDe(filho, id)
				local clipe = Regra.clipeMao(litrosDe(id), lado, Cfg.mao.minimoGalao)
				if lado == "esquerda" then
					esquerda = clipe
				else
					direita = clipe
					itemDireita = id
				end
			end
		end
	end
	-- com arma na mão o clipe da arma (e o IK) cuidam da mão esquerda
	if esquerda and a.jogador:GetAttribute("ArmaEquipada") ~= nil then
		esquerda = nil
	end
	a.maoDireita = direita
	a.itemDireita = itemDireita
	definirCanal(a, "mao", G.mao, direita)
	definirCanal(a, "maoEsq", G.mao, esquerda)
	local abastecendo = a.jogador:GetAttribute("Mangueira") == true and not a.emCarro
	definirCanal(a, "mangueira", G.mundo, if abastecendo then "Abastecer" else nil)
end

local function aoUsar(a: Ator)
	if a.jogador:GetAttribute("Usando") ~= true then
		return
	end
	-- o modelo do item chega junto do atributo; espera um instante para ele existir nos dois lados
	task.delay(0.15, function()
		if atores[a.jogador] ~= a or a.jogador:GetAttribute("Usando") ~= true or not a.maoDireita then
			return
		end
		local def = a.itemDireita and (CfgItens.itens :: any)[a.itemDireita]
		local velocidade = Regra.velocidadeUso(Animacao.duracao(G.mao, "Usar"), def and def.uso)
		tocarUma(a, G.mao, "Usar", velocidade)
	end)
end

-- Vida ------------------------------------------------------------------------------------------------------------------------

local function aoMorrer(a: Ator, jaMorto: boolean)
	if a.morto then
		return
	end
	a.morto = true
	comVolante[a] = nil
	for canal in a.desejado do
		a.desejado[canal] = nil
		sincronizar(a, canal)
	end
	pararVira(a)
	if not Cfg.morteAnimada then
		return -- juntas quebram na morte (padrão do motor): o clipe não teria o que animar
	end
	local t = trilha(a, G.vida, "Morte")
	if not t then
		return
	end
	-- congela na pose caída: o marcador Congelar é o penúltimo quadro
	t:GetMarkerReachedSignal("Congelar"):Connect(function()
		t:AdjustSpeed(0)
	end)
	t:Play(Cfg.fade.morte)
	if jaMorto then
		t.TimePosition = math.max(0, Animacao.duracao(G.vida, "Morte") - 0.06) -- corpo que já estava caído quando entrou no alcance
	end
end

local function aoCair(a: Ator, ativo: boolean)
	if ativo then
		local inicio = os.clock()
		a.noAr = inicio
		a.quedaTocou = false
		task.delay(Cfg.queda.minimo, function()
			if a.noAr == inicio and not a.morto and not a.emCarro and a.humanoide.Health > 0 then
				a.quedaTocou = true
				definirCanal(a, "queda", G.vida, "Queda")
			end
		end)
	else
		local tocou = a.quedaTocou
		a.noAr = nil
		a.quedaTocou = false
		definirCanal(a, "queda", nil, nil)
		if tocou and not a.morto and not a.emCarro then
			tocarUma(a, G.vida, "Aterrissagem")
		end
	end
end

-- Ator por personagem -----------------------------------------------------------------------------------------------------------

local function desligar(p: Player)
	local a = atores[p]
	if not a then
		return
	end
	atores[p] = nil
	comVolante[a] = nil
	for _, l in a.ligacoes do
		l:Disconnect()
	end
	for _, t in a.faixas do
		if t.IsPlaying then
			t:Stop(0)
		end
	end
	pararVira(a)
end

local function criarAtor(p: Player, personagem: Model)
	desligar(p)
	local humanoide = personagem:WaitForChild("Humanoid", 10)
	if not (humanoide and humanoide:IsA("Humanoid")) or p.Character ~= personagem then
		return
	end
	local a: Ator = {
		jogador = p,
		ehMeu = p == jogador,
		personagem = personagem,
		humanoide = humanoide,
		animator = nil,
		desejado = {},
		tocando = {},
		faixas = {},
		vira = {},
		assento = nil,
		emCarro = false,
		assentoId = 0,
		noAr = nil,
		quedaTocou = false,
		morto = false,
		maoDireita = nil,
		itemDireita = nil,
		ligacoes = {},
	}
	atores[p] = a
	local function ligar(conexao: RBXScriptConnection)
		table.insert(a.ligacoes, conexao)
	end

	ligar(humanoide:GetPropertyChangedSignal("SeatPart"):Connect(function()
		aoAssento(a)
	end))
	ligar(humanoide.Died:Connect(function()
		aoMorrer(a, false)
	end))
	ligar(humanoide.FreeFalling:Connect(function(ativo)
		aoCair(a, ativo)
	end))
	local function reavaliarMao()
		avaliarMao(a)
		task.delay(0.3, function() -- a solda da mão chega depois do modelo
			if atores[p] == a then
				avaliarMao(a)
			end
		end)
	end
	ligar(personagem.ChildAdded:Connect(function(filho)
		if filho.Name == "ItemNaMao" then
			reavaliarMao()
		end
	end))
	ligar(personagem.ChildRemoved:Connect(function(filho)
		if filho.Name == "ItemNaMao" then
			avaliarMao(a)
		end
	end))
	ligar(p:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
		avaliarMao(a)
	end))
	ligar(p:GetAttributeChangedSignal("Mangueira"):Connect(function()
		avaliarMao(a)
	end))
	ligar(p:GetAttributeChangedSignal("Usando"):Connect(function()
		aoUsar(a)
	end))

	local animator = humanoide:WaitForChild("Animator", 10)
	if atores[p] ~= a or not (animator and animator:IsA("Animator")) then
		return
	end
	a.animator = animator
	if humanoide.Health <= 0 or a.morto then
		a.morto = false -- morreu antes do Animator existir: toca a Morte agora (já caído, se o corpo era antigo)
		aoMorrer(a, humanoide.Health <= 0)
		return
	end
	aoAssento(a)
	avaliarMao(a)
end

local function ligarJogador(p: Player)
	p.CharacterAdded:Connect(function(personagem)
		task.spawn(criarAtor, p, personagem)
	end)
	p.CharacterRemoving:Connect(function()
		desligar(p)
	end)
	if p.Character then
		task.spawn(criarAtor, p, p.Character)
	end
end

-- Gatilhos só do jogador local ------------------------------------------------------------------------------------------------

local function distanciaAte(inst: Instance, a: Ator): number
	local raiz = a.personagem:FindFirstChild("HumanoidRootPart")
	if not (raiz and raiz:IsA("BasePart")) then
		return math.huge
	end
	local alvo: Vector3
	if inst:IsA("Model") then
		alvo = inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		alvo = inst.Position
	else
		return math.huge
	end
	return (alvo - raiz.Position).Magnitude
end

local function ligarLocal()
	local totalAnterior: number? = nil
	local tInvMais: number? = nil
	local tInvMenos: number? = nil
	local tChaoSomeu: number? = nil
	local tChaoNovo: number? = nil
	local ultimoInteragir = 0

	local function eu(): Ator?
		return atores[jogador]
	end

	local function avaliar()
		local a = eu()
		if not a or a.morto or a.emCarro then
			return
		end
		if Regra.juntos(tInvMais, tChaoSomeu, Cfg.mundo.janela) then
			tInvMais, tChaoSomeu = nil, nil
			tocarUma(a, G.mundo, "Pegar")
		end
		if Regra.juntos(tInvMenos, tChaoNovo, Cfg.mundo.janela) then
			tInvMenos, tChaoNovo = nil, nil
			tocarUma(a, G.mundo, "Largar")
		end
	end

	local okInv, inventario = pcall(Rede.evento, "Inventario")
	if okInv then
		inventario.OnClientEvent:Connect(function(lista: any)
			local total = 0
			if type(lista) == "table" then
				for _, item in lista do
					total += (type(item) == "table" and tonumber(item.qtd)) or 0
				end
			end
			if totalAnterior ~= nil then
				if total > totalAnterior then
					tInvMais = os.clock()
				elseif total < totalAnterior then
					tInvMenos = os.clock()
				end
				avaliar()
			end
			totalAnterior = total
		end)
	end

	task.spawn(function()
		local pasta = workspace:WaitForChild("ItensChao", 60)
		if not pasta then
			return
		end
		pasta.ChildAdded:Connect(function(filho)
			local a = eu()
			if a and filho:GetAttribute("Largado") == true and distanciaAte(filho, a) <= Cfg.mundo.distancia then
				tChaoNovo = os.clock()
				avaliar()
			end
		end)
		pasta.ChildRemoved:Connect(function(filho)
			local a = eu()
			if a and distanciaAte(filho, a) <= Cfg.mundo.distancia then
				tChaoSomeu = os.clock()
				avaliar()
			end
		end)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(_, quem)
		local a = eu()
		if quem ~= jogador or not a or a.emCarro or a.morto then
			return
		end
		local agora = os.clock()
		if agora - ultimoInteragir < Cfg.mundo.interagirRecarga then
			return
		end
		ultimoInteragir = agora
		tocarUma(a, G.mundo, "Interagir")
	end)
end

function AnimacaoCorpo.iniciar()
	for _, p in Players:GetPlayers() do
		ligarJogador(p)
	end
	Players.PlayerAdded:Connect(ligarJogador)
	Players.PlayerRemoving:Connect(desligar)
	RunService.Heartbeat:Connect(function()
		for a in comVolante do
			atualizarVolante(a)
		end
	end)
	ligarLocal()
end

-- Para testes no Studio / outros módulos: clipe tocando num canal do jogador (nil se nenhum).
function AnimacaoCorpo.tocando(p: Player, canal: string): string?
	local a = atores[p]
	return a and a.tocando[canal]
end

return AnimacaoCorpo
