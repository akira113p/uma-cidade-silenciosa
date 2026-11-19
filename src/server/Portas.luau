-- Portas (docs/monstros/logica.md §2.1). Monta, em tempo de execução, uma porta funcional por peça "Folha" das construções do
-- mapa (o arquivo do mapa NÃO muda: regra 4 do CLAUDE.md). A folha nasce entreaberta (75°) e sem colisão; fechada ela colide.
-- Jogador usa ProximityPrompt (E). API para os monstros: naLinha, perto, abrir, fechar, estaAberta, posicao.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Portas"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Portas"))

local Portas = {}

export type Porta = {
	folha: BasePart,
	aberta: boolean,
	dobradica: Vector3,
	cfAberto: CFrame,
	cfFechado: CFrame,
	tamanho: Vector3,
	ultimo: number,
	tween: Tween?,
	ficha: number,
	prompt: ProximityPrompt?,
}

local lista: { Porta } = {}
local porFolha: { [Instance]: Porta } = {}
local celulas: { [string]: { Porta } } = {}
local pronto = false
local montadas = 0
local duracaoMontagem = 0

local function chave(cx: number, cz: number): string
	return cx .. "," .. cz
end

-- Módulos irmãos podem faltar ou falhar: nada aqui pode quebrar por causa deles.
local function opcional(nome: string): any
	local arquivo = script.Parent:FindFirstChild(nome)
	if not (arquivo and arquivo:IsA("ModuleScript")) then
		return nil
	end
	local ok, m = pcall(require, arquivo)
	return if ok then m else nil
end

local function valida(p: Porta): boolean
	return p.folha.Parent ~= nil and p.folha:IsDescendantOf(workspace)
end

local function remover(p: Porta)
	porFolha[p.folha] = nil
	local i = table.find(lista, p)
	if i then
		lista[i] = lista[#lista]
		lista[#lista] = nil
	end
	local cx, cz = Regras.celula(p.cfFechado.X, p.cfFechado.Z, Cfg.celula)
	local c = celulas[chave(cx, cz)]
	if c then
		local j = table.find(c, p)
		if j then
			table.remove(c, j)
		end
	end
	if p.tween then
		p.tween:Cancel()
	end
	if p.prompt then
		p.prompt:Destroy()
	end
end

local function invalidar(pos: Vector3)
	local Monstros = opcional("Monstros")
	if Monstros and Monstros.invalidarCaminhos then
		pcall(Monstros.invalidarCaminhos, pos, Cfg.invalidarRaio)
	end
end

local function ruido(pos: Vector3, modo: string, silencioso: boolean, quem: (Player | Model)?)
	local db, tipo = Regras.ruido(modo, silencioso, Cfg)
	local Ruido = opcional("Ruido")
	if Ruido then
		pcall(Ruido.emitir, pos, db, tipo, quem)
	end
	local Sons = opcional("Sons")
	if Sons then
		pcall(Sons.tocar, Cfg.sons[modo], pos, { db = db }) -- nome ainda não cadastrado: Sons.tocar ignora
	end
end

local function atualizarPrompt(p: Porta)
	if p.prompt then
		p.prompt.ActionText = if p.aberta then Cfg.prompt.textoFechar else Cfg.prompt.textoAbrir
	end
end

local function mover(p: Porta, aberta: boolean, duracao: number)
	p.aberta = aberta
	p.ficha += 1
	local ficha = p.ficha
	if p.tween then
		p.tween:Cancel()
	end
	local pos = p.cfFechado.Position
	if aberta then
		p.folha.CanCollide = false
		p.folha.CanQuery = false
	else
		p.folha.CanQuery = true -- fechando: já entra no raycast (tiro, visão); a colisão só vale ao fim
	end
	atualizarPrompt(p)
	local t = TweenService:Create(
		p.folha,
		TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = if aberta then p.cfAberto else p.cfFechado }
	)
	p.tween = t
	t.Completed:Connect(function()
		if p.ficha ~= ficha or not valida(p) then
			return
		end
		if not aberta then
			p.folha.CanCollide = true
		end
		p.tween = nil
		invalidar(pos)
	end)
	t:Play()
end

local function ehSilencioso(quem: (Player | Model)?, silencioso: boolean?): boolean
	if silencioso ~= nil then
		return silencioso
	end
	return typeof(quem) == "Instance" and quem:IsA("Player") and quem:GetAttribute("Agachado") == true
end

function Portas.estaAberta(porta: Porta): boolean
	return porta.aberta
end

function Portas.posicao(porta: Porta): Vector3
	return porta.cfFechado.Position
end

function Portas.abrir(porta: Porta, quem: (Player | Model)?, silencioso: boolean?)
	if not valida(porta) then
		return
	end
	local agora = os.clock()
	if not Regras.podeMudar(porta.aberta, true, porta.ultimo, agora, Cfg) then
		return
	end
	porta.ultimo = agora
	mover(porta, true, Regras.duracao("abrir", Cfg))
	ruido(porta.cfFechado.Position, "abrir", ehSilencioso(quem, silencioso), quem)
end

function Portas.fechar(porta: Porta, quem: (Player | Model)?, bater: boolean?)
	if not valida(porta) then
		return
	end
	local agora = os.clock()
	if not Regras.podeMudar(porta.aberta, false, porta.ultimo, agora, Cfg) then
		return
	end
	porta.ultimo = agora
	local modo = if bater then "bater" else "fechar"
	mover(porta, false, Regras.duracao(modo, Cfg))
	ruido(porta.cfFechado.Position, modo, false, quem)
end

function Portas.perto(pos: Vector3, raio: number): { Porta }
	local saida: { Porta } = {}
	local x0, z0 = Regras.celula(pos.X - raio, pos.Z - raio, Cfg.celula)
	local x1, z1 = Regras.celula(pos.X + raio, pos.Z + raio, Cfg.celula)
	for cx = x0, x1 do
		for cz = z0, z1 do
			local c = celulas[chave(cx, cz)]
			if c then
				for _, p in c do
					if valida(p) and (p.cfFechado.Position - pos).Magnitude <= raio then
						table.insert(saida, p)
					end
				end
			end
		end
	end
	return saida
end

-- A porta FECHADA mais próxima de `de` que corta o segmento de -> ate (com folga `raio`).
function Portas.naLinha(de: Vector3, ate: Vector3, raio: number): Porta?
	local meio = (de + ate) / 2
	local alcance = (ate - de).Magnitude / 2 + raio + 12
	local ymin = math.min(de.Y, ate.Y) - Cfg.alturaFolga
	local ymax = math.max(de.Y, ate.Y) + Cfg.alturaFolga
	local melhor: Porta? = nil
	local melhorD = math.huge
	local a: Regras.P2 = { x = de.X, z = de.Z }
	local b: Regras.P2 = { x = ate.X, z = ate.Z }
	for _, p in Portas.perto(meio, alcance) do
		local c = p.cfFechado.Position
		if not p.aberta and c.Y >= ymin and c.Y <= ymax then
			local h = { x = p.dobradica.X, z = p.dobradica.Z }
			local fim = { x = c.X * 2 - p.dobradica.X, z = c.Z * 2 - p.dobradica.Z }
			if Regras.cortaCaminho(a, b, h, fim, raio) then
				local d = (c - de).Magnitude
				if d < melhorD then
					melhor, melhorD = p, d
				end
			end
		end
	end
	return melhor
end

local function criarPrompt(p: Porta)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptPorta"
	prompt.ActionText = if p.aberta then Cfg.prompt.textoFechar else Cfg.prompt.textoAbrir
	prompt.ObjectText = "Porta"
	prompt.KeyboardKeyCode = Enum.KeyCode[Cfg.prompt.tecla]
	prompt.MaxActivationDistance = Cfg.prompt.distancia
	prompt.RequiresLineOfSight = Cfg.prompt.linhaDeVisao
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(function(jogador: Player)
		if not valida(p) or jogador:GetAttribute("Morto") == true then
			return
		end
		local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		local limite = Cfg.prompt.distancia + Cfg.prompt.folgaServidor + p.tamanho.X
		if not (raiz and raiz:IsA("BasePart")) or (raiz.Position - p.cfFechado.Position).Magnitude > limite then
			return
		end
		if p.aberta then
			Portas.fechar(p, jogador, false)
		else
			Portas.abrir(p, jogador)
		end
	end)
	prompt.Parent = p.folha
	p.prompt = prompt
end

local function montar(folha: BasePart)
	if porFolha[folha] then
		return
	end
	local cf = folha.CFrame
	local c: Regras.P2 = { x = cf.X, z = cf.Z }
	local r = cf.RightVector
	local bat = folha.Parent and folha.Parent:FindFirstChild("Batente")
	local centroBat: Regras.P2? = nil
	local eixoBat: Regras.P2? = nil
	if bat and bat:IsA("BasePart") then
		centroBat = { x = bat.Position.X, z = bat.Position.Z }
		local e = if bat.Size.X >= bat.Size.Z then bat.CFrame.RightVector else bat.CFrame.LookVector -- eixo longo = a parede
		eixoBat = { x = e.X, z = e.Z }
	end
	local h = Regras.dobradica(c, { x = r.X, z = r.Z }, folha.Size.X, centroBat, eixoBat)
	local rad = Regras.anguloParaFechar(c, h, centroBat, Cfg.anguloMapa)
	local hv = Vector3.new(h.x, cf.Y, h.z)
	local fechado = CFrame.new(hv) * CFrame.Angles(0, rad, 0) * CFrame.new(-hv) * cf
	local p: Porta = {
		folha = folha,
		aberta = true,
		dobradica = hv,
		cfAberto = cf,
		cfFechado = fechado,
		tamanho = folha.Size,
		ultimo = -math.huge,
		ficha = 0,
	}
	folha.Anchored = true
	porFolha[folha] = p
	table.insert(lista, p)
	local cx, cz = Regras.celula(fechado.X, fechado.Z, Cfg.celula)
	local k = chave(cx, cz)
	local cel = celulas[k]
	if not cel then
		cel = {}
		celulas[k] = cel
	end
	table.insert(cel, p)
	criarPrompt(p)
	if not Cfg.comecaAberta then
		folha.CFrame = fechado
		folha.CanCollide = true
		folha.CanQuery = true
		p.aberta = false
		atualizarPrompt(p)
	end
	montadas += 1
end

local function montarTudo()
	local inicio = os.clock()
	local n = 0
	for _, pai in { workspace:FindFirstChild("Mapa"), workspace:FindFirstChild("ZonaTeste") } do
		local raiz = pai and pai:FindFirstChild("Construcoes")
		if raiz then
			for _, predio in raiz:GetChildren() do
				for _, d in predio:GetDescendants() do
					if d.Name == "Folha" and d:IsA("BasePart") then
						montar(d)
					end
				end
				n += 1
				if n % Cfg.lote == 0 then
					task.wait()
				end
			end
		end
	end
	duracaoMontagem = os.clock() - inicio
	pronto = true
	print(string.format("[Portas] %d portas montadas em %.2f s", montadas, duracaoMontagem))
end

function Portas.contagem(): (number, number)
	return montadas, duracaoMontagem
end

function Portas.iniciar()
	local Destruicao = opcional("Destruicao")
	if Destruicao and Destruicao.aoQuebrar then
		Destruicao.aoQuebrar(function(evento)
			-- folha quebrada (removida ou recortada) deixa de ser porta
			for _, p in Portas.perto(evento.centro, 8) do
				if p.folha.Size ~= p.tamanho then
					remover(p)
				end
			end
			for _, p in table.clone(lista) do
				if not valida(p) then
					remover(p)
				end
			end
		end)
	end
	task.spawn(montarTudo)

	local Teste = opcional("Teste")
	if Teste then
		Teste.registrar("portas", function()
			return string.format("%d portas (montagem %.2f s, pronto=%s)", montadas, duracaoMontagem, tostring(pronto))
		end)
		Teste.registrar("porta", function(jogador: Player, acao: string?)
			local raiz = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
			if not (raiz and raiz:IsA("BasePart")) then
				return "sem personagem"
			end
			local p = Portas.perto(raiz.Position, 15)[1]
			if not p then
				return "nenhuma porta a 15 studs"
			end
			if acao == "fechar" then
				Portas.fechar(p, jogador, false)
			elseif acao == "bater" then
				Portas.fechar(p, jogador, true)
			else
				Portas.abrir(p, jogador)
			end
			return "aberta=" .. tostring(p.aberta)
		end)
	end
end

return Portas
