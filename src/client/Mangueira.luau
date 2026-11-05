-- Mangueira (cliente): corda Verlet das mangueiras do posto + prompts por contexto. Dono: S5. Contrato: docs/combustivel.md §5.3 e §6.4.
-- O servidor cria workspace.Mangueiras/<UserId> (Folder com atributos Dono/Estado/Comprimento/Fluxo e ObjectValues
-- Bocal/Destino) e decide tudo. Aqui só se DESENHA a corda (física local, sem rede) e se esconde/renomeia, SÓ neste
-- cliente, os prompts que não fazem sentido no momento. Sem mangueira no mundo o RenderStepped fica desconectado.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Combustivel"))

local Mangueira = {}

local jogador = Players.LocalPlayer
local CFG = Cfg.mangueira

local AMORTECIMENTO = 0.98 -- por quadro; evita a corda balançar para sempre
local ITERACOES = 4 -- passadas das restrições de distância por quadro
local DT_MAX = 1 / 30 -- passo máximo da simulação (queda de FPS não explode a corda)
local ATRITO_CHAO = 0.6 -- fração da velocidade horizontal que sobra quando o ponto toca o chão
local RAIO_ORIGEM = 1.5 -- studs acima do ponto de onde o raio do chão parte
local RAIO_ALCANCE = 4 -- comprimento do raio do chão
local FOLGA_JUNTA = 0.12 -- studs a mais em cada cilindro para as juntas não abrirem
local COR_BORRACHA = Color3.fromRGB(25, 25, 25)
local COR_BICO = Color3.fromRGB(200, 180, 40)
local NOME_BOMBA = "bomba_combustivel"
local PROMPTS = { PegarMangueira = true, EncherRecipiente = true, Abastecer = true }

type Mang = {
	pasta: Folder,
	dono: Player?,
	bocal: ObjectValue,
	destino: ObjectValue,
	pontos: { Vector3 },
	antes: { Vector3 },
	pecas: { Part },
	cfs: { CFrame }, -- reaproveitado a cada quadro para o BulkMoveTo
	pronta: boolean, -- pontos inicializados desde que a mangueira ficou visível
	visivel: boolean,
	ligacoes: { RBXScriptConnection },
}

local mangueiras: { [Instance]: Mang } = {}
local quantas = 0
local pastaLocal: Folder? = nil
local pastaMundo: Folder? = nil
local ligacaoQuadro: RBXScriptConnection? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local gravidade = Vector3.new(0, -196.2, 0)

-- Inventário e prompts (contexto) ---------------------------------------------------------------------------------

local porSlot: { [number]: { id: string, qtd: number } } = {}
local prompts: { [ProximityPrompt]: string } = setmetatable({}, { __mode = "k" }) :: any -- prompt -> ActionText original

local function minhaMangueira(): Folder?
	local pasta = pastaMundo
	if not pasta then
		return nil
	end
	local filho = pasta:FindFirstChild(tostring(jogador.UserId))
	return if filho and filho:IsA("Folder") then filho else nil
end

local function valorDe(pasta: Instance, nome: string): Instance?
	local ov = pasta:FindFirstChild(nome)
	return if ov and ov:IsA("ObjectValue") then ov.Value else nil
end

-- A bomba (Model do mapa) que contém o prompt/anexo; sobe até achar o modelo marcado.
local function bombaDe(inst: Instance?): Instance?
	local atual = inst
	while atual and atual ~= workspace do
		if atual:GetAttribute("Movel") == NOME_BOMBA or atual:GetAttribute("BombaId") ~= nil then
			return atual
		end
		atual = atual.Parent
	end
	return nil
end

local function temRecipienteVazio(): boolean
	for _, o in porSlot do
		local rec = Cfg.recipientes[o.id]
		if rec and rec.enche then
			return true
		end
	end
	return false
end

local function contextoBomba(prompt: ProximityPrompt, original: string): (boolean, string)
	local minha = minhaMangueira()
	if not minha and jogador:GetAttribute("Mangueira") ~= true then
		return true, original
	end
	-- Com mangueira: só a bomba dela mostra o prompt, como "Guardar".
	local bocal = minha and valorDe(minha, "Bocal")
	local bomba = bombaDe(prompt)
	if bocal and bomba and bocal:IsDescendantOf(bomba) then
		return true, "Guardar mangueira"
	end
	return false, original
end

local function contextoTampa(prompt: ProximityPrompt, original: string): (boolean, string)
	local minha = minhaMangueira()
	if minha then
		if minha:GetAttribute("Estado") == "plugada" then
			local alvo = valorDe(minha, "Destino")
			local tampa = prompt.Parent
			if alvo and tampa and alvo:IsDescendantOf(tampa) then
				return true, "Desplugar mangueira"
			end
			return false, original
		end
		return true, "Plugar mangueira"
	end
	local slot = jogador:GetAttribute("RecipienteSlot")
	local item = if type(slot) == "number" then porSlot[slot] else nil
	local rec = item and Cfg.recipientes[item.id]
	if item and rec and rec.despeja then
		return true, if string.find(item.id, "^garrafa") then "Despejar garrafa" else "Despejar galão"
	end
	return false, original
end

local function aplicarPrompt(prompt: ProximityPrompt)
	local original = prompts[prompt]
	if not original then
		return
	end
	local ligado, texto = true, original
	if prompt.Name == "PegarMangueira" then
		ligado, texto = contextoBomba(prompt, original)
	elseif prompt.Name == "EncherRecipiente" then
		ligado = temRecipienteVazio()
	elseif prompt.Name == "Abastecer" then
		ligado, texto = contextoTampa(prompt, original)
	end
	if prompt.Enabled ~= ligado then
		prompt.Enabled = ligado
	end
	if ligado and prompt.ActionText ~= texto then
		prompt.ActionText = texto
	end
end

local function atualizarPrompts()
	for prompt in prompts do
		if prompt.Parent == nil then
			prompts[prompt] = nil
		else
			aplicarPrompt(prompt)
		end
	end
end

local function registrarPrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") and PROMPTS[inst.Name] and not prompts[inst] then
		prompts[inst] = inst.ActionText
		aplicarPrompt(inst)
	end
end

-- Física e desenho -----------------------------------------------------------------------------------------------

local function atualizarFiltro()
	local lista: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(lista, p.Character)
		end
	end
	if pastaMundo then
		table.insert(lista, pastaMundo)
	end
	if workspace.CurrentCamera then
		table.insert(lista, workspace.CurrentCamera)
	end
	params.FilterDescendantsInstances = lista
end

local function mostrar(m: Mang, ligado: boolean)
	if m.visivel == ligado then
		return
	end
	m.visivel = ligado
	m.pronta = false
	local pai = if ligado then pastaLocal else nil
	for _, peca in m.pecas do
		peca.Parent = pai
	end
end

local function criarPecas(m: Mang)
	local n = CFG.segmentos - 1
	for i = 1, n do
		local peca = Instance.new("Part")
		peca.Name = "Segmento" .. i
		peca.Shape = Enum.PartType.Cylinder
		peca.Material = Enum.Material.Plastic
		peca.Color = if i == n then COR_BICO else COR_BORRACHA
		peca.Size = Vector3.new(1, CFG.raio * 2, CFG.raio * 2)
		peca.Anchored = true
		peca.CanCollide = false
		peca.CanQuery = false
		peca.CanTouch = false
		peca.CastShadow = false
		m.pecas[i] = peca
		m.cfs[i] = CFrame.identity
	end
end

-- Pontas da corda em coordenadas do mundo; nil se algo ainda não existe neste cliente (streaming, mão não carregada).
local function pontas(m: Mang): (Vector3?, Vector3?)
	local bocal = m.bocal.Value
	if not (bocal and bocal:IsA("Attachment") and bocal.Parent) then
		return nil, nil
	end
	local a = bocal.WorldPosition
	if m.pasta:GetAttribute("Estado") == "plugada" then
		local alvo = m.destino.Value
		if alvo and alvo:IsA("Attachment") and alvo.Parent then
			return a, alvo.WorldPosition
		end
		return a, nil
	end
	local dono = m.dono
	local personagem = dono and dono.Character
	local mao = personagem and personagem:FindFirstChild("RightHand")
	if mao and mao:IsA("BasePart") then
		return a, mao.Position
	end
	return a, nil
end

local function iniciarPontos(m: Mang, a: Vector3, b: Vector3)
	local n = CFG.segmentos
	for i = 1, n do
		local p = a:Lerp(b, (i - 1) / (n - 1))
		m.pontos[i] = p
		m.antes[i] = p
	end
	m.pronta = true
end

local function simular(m: Mang, a: Vector3, b: Vector3, dt: number)
	local n = CFG.segmentos
	local pontos, antes = m.pontos, m.antes
	local comprimento = m.pasta:GetAttribute("Comprimento")
	if type(comprimento) ~= "number" then
		comprimento = CFG.comprimento
	end
	local seg = comprimento / (n - 1)

	-- Ponta além do comprimento não acompanha: a corda fica esticada e a ponta fica no limite.
	local ate = b - a
	if ate.Magnitude > comprimento then
		b = a + ate.Unit * comprimento
	end

	-- Passo de Verlet (pontas presas).
	local g = gravidade * (dt * dt)
	for i = 2, n - 1 do
		local p = pontos[i]
		pontos[i] = p + (p - antes[i]) * AMORTECIMENTO + g
		antes[i] = p
	end
	pontos[1], antes[1] = a, a
	pontos[n], antes[n] = b, b

	-- Restrições de distância; os pontos 1 e n têm peso 0 (presos).
	for _ = 1, ITERACOES do
		for i = 1, n - 1 do
			local p1, p2 = pontos[i], pontos[i + 1]
			local delta = p2 - p1
			local d = delta.Magnitude
			if d > 1e-4 then
				local w1 = if i == 1 then 0 else 1
				local w2 = if i + 1 == n then 0 else 1
				local soma = w1 + w2
				if soma > 0 then
					local corr = delta * ((d - seg) / d / soma)
					pontos[i] = p1 + corr * w1
					pontos[i + 1] = p2 - corr * w2
				end
			end
		end
	end

	-- Chão: 1 raio para baixo por ponto livre; o ponto apoia no raio da mangueira e perde velocidade.
	local raio = CFG.raio
	for i = 2, n - 1 do
		local p = pontos[i]
		local hit = workspace:Raycast(p + Vector3.new(0, RAIO_ORIGEM, 0), Vector3.new(0, -RAIO_ALCANCE, 0), params)
		if hit and p.Y < hit.Position.Y + raio then
			local y = hit.Position.Y + raio
			local ant = antes[i]
			pontos[i] = Vector3.new(p.X, y, p.Z)
			antes[i] = Vector3.new(p.X - (p.X - ant.X) * (1 - ATRITO_CHAO), y, p.Z - (p.Z - ant.Z) * (1 - ATRITO_CHAO))
		end
	end
end

local function desenhar(m: Mang)
	local pontos, pecas, cfs = m.pontos, m.pecas, m.cfs
	for i = 1, CFG.segmentos - 1 do
		local p1, p2 = pontos[i], pontos[i + 1]
		local comprimento = (p2 - p1).Magnitude
		local peca = pecas[i]
		local tamanho = comprimento + FOLGA_JUNTA
		if math.abs(peca.Size.X - tamanho) > 0.02 then
			peca.Size = Vector3.new(tamanho, peca.Size.Y, peca.Size.Z)
		end
		-- O eixo do cilindro é o X da peça: gira 90° para que o X aponte para o próximo ponto.
		cfs[i] = if comprimento > 1e-4
			then CFrame.lookAt((p1 + p2) / 2, p2) * CFrame.Angles(0, math.rad(90), 0)
			else CFrame.new(p1)
	end
	workspace:BulkMoveTo(pecas, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function quadro(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local posCamera = camera.CFrame.Position
	local passo = math.min(dt, DT_MAX)
	gravidade = Vector3.new(0, -workspace.Gravity, 0)
	for _, m in mangueiras do
		local a, b = pontas(m)
		if a and b and (a - posCamera).Magnitude <= CFG.distanciaDesenho then
			if not m.visivel then
				mostrar(m, true)
			end
			if not m.pronta then
				iniciarPontos(m, a, b)
			end
			simular(m, a, b, passo)
			desenhar(m)
		elseif m.visivel then
			mostrar(m, false)
		end
	end
end

local function ligarQuadro()
	if not ligacaoQuadro then
		ligacaoQuadro = RunService.RenderStepped:Connect(quadro)
	end
end

local function desligarQuadro()
	if ligacaoQuadro then
		ligacaoQuadro:Disconnect()
		ligacaoQuadro = nil
	end
end

-- Ciclo de vida das mangueiras -------------------------------------------------------------------------------------

local function removerMangueira(pasta: Instance)
	local m = mangueiras[pasta]
	if not m then
		return
	end
	mangueiras[pasta] = nil
	quantas -= 1
	for _, c in m.ligacoes do
		c:Disconnect()
	end
	for _, peca in m.pecas do
		peca:Destroy()
	end
	if quantas <= 0 then
		quantas = 0
		desligarQuadro()
	end
	atualizarPrompts()
end

local function novaMangueira(pasta: Instance)
	if not pasta:IsA("Folder") then
		return
	end
	-- O streaming pode não ter entregue os filhos ainda: espera, e ignora se não vierem.
	local bocal = pasta:WaitForChild("Bocal", 5)
	local destino = pasta:WaitForChild("Destino", 5)
	if not (bocal and destino and bocal:IsA("ObjectValue") and destino:IsA("ObjectValue")) then
		return
	end
	if pasta.Parent ~= pastaMundo or mangueiras[pasta] then
		return
	end
	local dono = pasta:GetAttribute("Dono")
	local m: Mang = {
		pasta = pasta,
		dono = if type(dono) == "number" then Players:GetPlayerByUserId(dono) else nil,
		bocal = bocal,
		destino = destino,
		pontos = {},
		antes = {},
		pecas = {},
		cfs = {},
		pronta = false,
		visivel = false,
		ligacoes = {},
	}
	criarPecas(m)
	-- O dono pode ainda não ter chegado como Player neste cliente: resolve de novo quando o atributo ou o jogador mudar.
	local function resolverDono()
		local id = pasta:GetAttribute("Dono")
		m.dono = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
	end
	table.insert(m.ligacoes, pasta:GetAttributeChangedSignal("Dono"):Connect(resolverDono))
	table.insert(m.ligacoes, Players.PlayerAdded:Connect(resolverDono))
	table.insert(m.ligacoes, pasta:GetAttributeChangedSignal("Estado"):Connect(atualizarPrompts))
	table.insert(m.ligacoes, destino.Changed:Connect(atualizarPrompts))
	table.insert(m.ligacoes, bocal.Changed:Connect(atualizarPrompts))
	mangueiras[pasta] = m
	quantas += 1
	ligarQuadro()
	atualizarPrompts()
end

-- Início -------------------------------------------------------------------------------------------------------------

function Mangueira.iniciar()
	local pasta = Instance.new("Folder")
	pasta.Name = "MangueiraLocal"
	pasta.Parent = workspace.CurrentCamera or workspace:WaitForChild("Camera")
	pastaLocal = pasta

	-- Inventário: guardado só para saber se há recipiente vazio / cheio na mão (o servidor valida tudo de novo).
	Rede.evento("Inventario").OnClientEvent:Connect(function(lista: { { slot: number, id: string, qtd: number } })
		porSlot = {}
		for _, o in lista do
			porSlot[o.slot] = o
		end
		atualizarPrompts()
	end)
	jogador:GetAttributeChangedSignal("Mangueira"):Connect(atualizarPrompts)
	jogador:GetAttributeChangedSignal("RecipienteSlot"):Connect(atualizarPrompts)

	-- Prompts: acha os que o servidor cria (agora e no streaming) sem varrer o mapa a cada quadro.
	workspace.DescendantAdded:Connect(registrarPrompt)
	CollectionService:GetInstanceAddedSignal("Tampa"):Connect(function(tampa: Instance)
		local p = tampa:FindFirstChild("Abastecer")
		if p then
			registrarPrompt(p)
		end
	end)
	task.spawn(function()
		local feitos = 0
		for _, d in workspace:GetDescendants() do
			registrarPrompt(d)
			feitos += 1
			if feitos % 4000 == 0 then
				task.wait()
			end
		end
	end)

	-- Filtro do raio do chão: personagens, as mangueiras e a câmera não contam.
	local function ligarJogador(p: Player)
		p.CharacterAdded:Connect(atualizarFiltro)
		p.CharacterRemoving:Connect(function()
			task.defer(atualizarFiltro)
		end)
	end
	for _, p in Players:GetPlayers() do
		ligarJogador(p)
	end
	Players.PlayerAdded:Connect(function(p)
		ligarJogador(p)
		atualizarFiltro()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(atualizarFiltro)
	end)

	-- workspace.Mangueiras é criada pelo servidor; espera sem desistir.
	task.spawn(function()
		local mundo: Instance? = nil
		while not mundo do
			mundo = workspace:WaitForChild("Mangueiras", 10)
		end
		pastaMundo = mundo :: Folder
		atualizarFiltro()
		mundo.ChildAdded:Connect(function(filho)
			task.spawn(novaMangueira, filho)
			atualizarPrompts()
		end)
		mundo.ChildRemoved:Connect(function(filho)
			removerMangueira(filho)
		end)
		for _, filho in mundo:GetChildren() do
			task.spawn(novaMangueira, filho)
		end
		atualizarPrompts()
	end)
end

return Mangueira
