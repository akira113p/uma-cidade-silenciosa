-- Admin (cliente): menu na tecla O (CfgAdmin.tecla) com hora, clima, voo, imortal, cura e qualquer item. Só abre se o servidor marcou o
-- atributo "Admin" no jogador. O cliente só pede; server/Admin.luau confere quem é dono e executa.
-- Voo: com o atributo AdminVoar ligado pelo servidor, o cliente (dono da física do personagem) move o personagem.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgAdmin = require(Shared:WaitForChild("Config"):WaitForChild("Admin"))
local CfgItens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local CfgVeiculos = require(Shared:WaitForChild("Config"):WaitForChild("Veiculos"))
local CfgMonstros = require(Shared:WaitForChild("Config"):WaitForChild("Monstros"))
local Mouse = require(script.Parent.Mouse)
local Teclas = require(script.Parent.Teclas)

local Admin = {}

local jogador = Players.LocalPlayer

local COR_FUNDO = Color3.fromRGB(22, 22, 26)
local COR_CONTORNO = Color3.fromRGB(78, 78, 88)
local COR_DESTAQUE = Color3.fromRGB(255, 160, 40)
local COR_TEXTO = Color3.fromRGB(236, 236, 238)
local COR_BOTAO = Color3.fromRGB(58, 58, 68)
local COR_LIGADO = Color3.fromRGB(70, 130, 80)
local FONTE_NEGRITO = Font.fromEnum(Enum.Font.GothamBold)

local painel: Frame
local escala: UIScale
local quantidade = CfgAdmin.quantidades[1]
local botoesQuantidade: { [number]: TextButton } = {}
local aoAtualizar: { () -> () } = {}

-- Carros: o que o menu vai pedir ao servidor (Regras/Veiculo.montar valida de novo). Valores fora do padrão = defeito.
local RODAS =
	{ { "FE", "Pneu diant. E" }, { "FD", "Pneu diant. D" }, { "TE", "Pneu tras. E" }, { "TD", "Pneu tras. D" } }
local VIDROS = {
	{ "ParaBrisa", "Para-brisa" },
	{ "Traseiro", "Vidro traseiro" },
	{ "JanelaE", "Janela E" },
	{ "JanelaD", "Janela D" },
}
local PECAS = {
	{ "Capo", "Capô" },
	{ "PortaMalas", "Porta-malas" },
	{ "PortaE", "Porta E" },
	{ "PortaD", "Porta D" },
	{ "ParaChoque", "Para-choque" },
}
local NIVEIS_MOTOR = { 100, 50, 0 }
local NIVEIS_CARROCERIA = { 100, 50, 10 }
local ESTADOS_PNEU = { "ok", "furado", "faltando" }
local ESTADOS_VIDRO = { "ok", "quebrado", "faltando" }

local function carroPadrao()
	return { motor = 100, carroceria = 100, queimado = false, combustivel = 1, pneus = {}, vidros = {}, faltando = {} }
end

local carro: any = carroPadrao()
local tipoCarro = "sedan"
local atualizadoresCarro: { () -> () } = {}
local quantidadeMonstro = CfgAdmin.invocar.quantidadesMonstro[1]
local botoesQuantidadeMonstro: { [number]: TextButton } = {}

local function atualizarCarro()
	for _, f in atualizadoresCarro do
		f()
	end
end

local function proximo(lista: { any }, atual: any): any
	return lista[((table.find(lista, atual) or 0) % #lista) + 1]
end

local function pedir(acao: string, arg: any?)
	Rede.evento("Admin"):FireServer(acao, arg)
end

local function acabamento(objeto: GuiObject)
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 6)
	canto.Parent = objeto
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = 2
	contorno.Color = COR_CONTORNO
	contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contorno.Parent = objeto
end

local function rotulo(pai: Instance, texto: string, ordem: number)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONTE_NEGRITO
	t.Text = texto
	t.TextSize = 16
	t.TextColor3 = COR_DESTAQUE
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = UDim2.new(1, 0, 0, 24)
	t.LayoutOrder = ordem
	t.Parent = pai
end

local function secao(pai: Instance, ordem: number, larguraCelula: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.fromScale(1, 0)
	f.LayoutOrder = ordem
	local grade = Instance.new("UIGridLayout")
	grade.CellSize = UDim2.fromOffset(larguraCelula, 38)
	grade.CellPadding = UDim2.fromOffset(6, 6)
	grade.SortOrder = Enum.SortOrder.LayoutOrder
	grade.Parent = f
	f.Parent = pai
	return f
end

local function botao(pai: Instance, texto: string, ordem: number, aoClicar: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = COR_BOTAO
	b.FontFace = FONTE_NEGRITO
	b.Text = texto
	b.TextSize = 14
	b.TextColor3 = COR_TEXTO
	b.LayoutOrder = ordem
	acabamento(b)
	b.Activated:Connect(aoClicar)
	b.Parent = pai
	return b
end

-- Botão que liga/desliga um atributo do jogador (ou do workspace) mostrando o estado.
local function interruptor(pai: Instance, texto: string, ordem: number, atributo: string, alvo: Instance, acao: string)
	local b: TextButton
	local function atualizar()
		local ligado = alvo:GetAttribute(atributo) == true
		b.Text = texto .. (if ligado then ": SIM" else ": NÃO")
		b.BackgroundColor3 = if ligado then COR_LIGADO else COR_BOTAO
	end
	b = botao(pai, texto, ordem, function()
		pedir(acao, alvo:GetAttribute(atributo) ~= true)
	end)
	alvo:GetAttributeChangedSignal(atributo):Connect(atualizar)
	table.insert(aoAtualizar, atualizar)
	atualizar()
end

local function destacarQuantidade()
	for q, b in botoesQuantidade do
		local ativo = q == quantidade
		b.BackgroundColor3 = if ativo then COR_LIGADO else COR_BOTAO
	end
end

local function construir(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "Admin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 300
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	painel = Instance.new("Frame")
	painel.Name = "Painel"
	painel.AnchorPoint = Vector2.new(0.5, 0.5)
	painel.Position = UDim2.fromScale(0.5, 0.5)
	painel.Size = UDim2.fromOffset(560, 470)
	painel.BackgroundColor3 = COR_FUNDO
	painel.BackgroundTransparency = 0.05
	painel.Visible = false
	acabamento(painel)
	escala = Instance.new("UIScale")
	escala.Parent = painel
	painel.Parent = gui

	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.FontFace = FONTE_NEGRITO
	titulo.Text = "Admin  (" .. CfgAdmin.tecla .. " ou " .. CfgAdmin.teclaReserva .. " fecha)"
	titulo.TextSize = 20
	titulo.TextColor3 = COR_TEXTO
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Position = UDim2.fromOffset(14, 8)
	titulo.Size = UDim2.new(1, -28, 0, 30)
	titulo.Parent = painel

	local lista = Instance.new("ScrollingFrame")
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(14, 46)
	lista.Size = UDim2.new(1, -28, 1, -58)
	lista.ScrollBarThickness = 6
	lista.CanvasSize = UDim2.new()
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.Parent = painel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lista

	-- Tempo
	rotulo(lista, "Tempo", 1)
	local tempo = secao(lista, 2, 122)
	for i, h in CfgAdmin.horas do
		botao(tempo, h.rotulo, i, function()
			pedir("hora", h.hora)
		end)
	end
	interruptor(tempo, "Congelar", #CfgAdmin.horas + 1, "RelogioCongelado", workspace, "congelar")

	-- Clima
	rotulo(lista, "Clima", 3)
	local clima = secao(lista, 4, 122)
	for i, c in { { "Limpo", "limpo" }, { "Chuva", "chuva" }, { "Tempestade", "tempestade" } } do
		botao(clima, c[1], i, function()
			pedir("clima", c[2])
		end)
	end

	-- Jogador
	rotulo(lista, "Jogador", 5)
	local eu = secao(lista, 6, 122)
	interruptor(eu, "Voar", 1, "AdminVoar", jogador, "voar")
	interruptor(eu, "Imortal", 2, "AdminImortal", jogador, "imortal")
	botao(eu, "Curar tudo", 3, function()
		pedir("curar")
	end)
	botao(eu, "Refazer visual", 4, function()
		pedir("visual")
	end)

	-- Carros
	rotulo(lista, "Carros: tipo", 7)
	local tipos = secao(lista, 8, 122)
	local nomesTipos: { string } = {}
	for nome in CfgVeiculos.tipos do
		table.insert(nomesTipos, nome)
	end
	table.sort(nomesTipos)
	local botoesTipo: { [string]: TextButton } = {}
	local function destacarTipo()
		for nome, b in botoesTipo do
			b.BackgroundColor3 = if nome == tipoCarro then COR_LIGADO else COR_BOTAO
		end
	end
	for i, nome in nomesTipos do
		botoesTipo[nome] = botao(tipos, CfgVeiculos.tipos[nome].nome or nome, i, function()
			tipoCarro = nome
			destacarTipo()
		end)
	end
	table.insert(atualizadoresCarro, destacarTipo)
	if not table.find(nomesTipos, tipoCarro) then
		tipoCarro = nomesTipos[1]
	end
	destacarTipo()

	rotulo(lista, "Carros: preset (preenche as peças abaixo)", 9)
	local presets = secao(lista, 10, 122)
	for i, p in CfgAdmin.presetsCarro do
		botao(presets, p.rotulo, i, function()
			carro = carroPadrao()
			for chave, valor in p.pedido do
				if type(valor) == "table" then
					for k, v in valor do
						carro[chave][k] = v
					end
				else
					carro[chave] = valor
				end
			end
			atualizarCarro()
		end)
	end

	rotulo(lista, "Carros: peça por peça (toque para mudar)", 11)
	local pecas = secao(lista, 12, 122)
	local ordem = 0
	local function proximaOrdem(): number
		ordem += 1
		return ordem
	end
	-- Botão que gira entre valores; fora do primeiro valor fica destacado.
	local function ciclo(rotuloBase: string, niveis: { any }, ler: () -> any, gravar: (any) -> ())
		local b: TextButton
		b = botao(pecas, rotuloBase, proximaOrdem(), function()
			gravar(proximo(niveis, ler()))
			atualizarCarro()
		end)
		table.insert(atualizadoresCarro, function()
			local v = ler()
			b.Text = rotuloBase .. ": " .. tostring(v)
			b.BackgroundColor3 = if v == niveis[1] then COR_BOTAO else COR_DESTAQUE
			b.TextColor3 = if v == niveis[1] then COR_TEXTO else Color3.fromRGB(20, 20, 20)
		end)
	end
	ciclo("Motor", NIVEIS_MOTOR, function()
		return carro.motor
	end, function(v)
		carro.motor = v
	end)
	ciclo("Carroceria", NIVEIS_CARROCERIA, function()
		return carro.carroceria
	end, function(v)
		carro.carroceria = v
	end)
	ciclo("Queimado", { false, true }, function()
		return carro.queimado
	end, function(v)
		carro.queimado = v
	end)
	for _, r in RODAS do
		ciclo(r[2], ESTADOS_PNEU, function()
			return carro.pneus[r[1]] or "ok"
		end, function(v)
			carro.pneus[r[1]] = v
		end)
	end
	for _, v in VIDROS do
		ciclo(v[2], ESTADOS_VIDRO, function()
			return carro.vidros[v[1]] or "ok"
		end, function(x)
			carro.vidros[v[1]] = x
		end)
	end
	for _, peca in PECAS do
		ciclo(peca[2], { false, true }, function()
			return carro.faltando[peca[1]] == true
		end, function(x)
			carro.faltando[peca[1]] = x
		end)
	end
	-- gasolina ao nascer (fração do tanque; Regras/Veiculo.montar valida)
	for _, nivel in { { "Gasolina: cheio", 1 }, { "Gasolina: metade", 0.5 }, { "Gasolina: vazio", 0 } } do
		local b = botao(pecas, nivel[1], proximaOrdem(), function()
			carro.combustivel = nivel[2]
			atualizarCarro()
		end)
		table.insert(atualizadoresCarro, function()
			b.BackgroundColor3 = if carro.combustivel == nivel[2] then COR_LIGADO else COR_BOTAO
		end)
	end

	local acoesCarro = secao(lista, 13, 176)
	local invocarCarro = botao(acoesCarro, "Invocar este carro", 1, function()
		pedir("carro", { tipo = tipoCarro, todos = false, pedido = carro })
	end)
	invocarCarro.BackgroundColor3 = COR_LIGADO
	botao(acoesCarro, "Um de cada tipo", 2, function()
		pedir("carro", { todos = true, pedido = carro })
	end)
	botao(acoesCarro, "Limpar meus carros", 3, function()
		pedir("limparCarros")
	end)
	table.insert(atualizadoresCarro, function() end)
	atualizarCarro()

	-- Monstros
	rotulo(lista, "Monstros (quantidade por espécie)", 20)
	local qtdsMonstro = secao(lista, 21, 60)
	local function destacarQuantidadeMonstro()
		for q, b in botoesQuantidadeMonstro do
			b.BackgroundColor3 = if q == quantidadeMonstro then COR_LIGADO else COR_BOTAO
		end
	end
	for i, q in CfgAdmin.invocar.quantidadesMonstro do
		botoesQuantidadeMonstro[q] = botao(qtdsMonstro, tostring(q), i, function()
			quantidadeMonstro = q
			destacarQuantidadeMonstro()
		end)
	end
	destacarQuantidadeMonstro()

	local monstros = secao(lista, 22, 176)
	local especies = table.clone(CfgMonstros.especies)
	table.sort(especies, function(a, b)
		if a.nivel ~= b.nivel then
			return a.nivel < b.nivel
		end
		return a.id < b.id
	end)
	for i, e in especies do
		botao(monstros, string.format("%s (nível %d)", e.id, e.nivel), i, function()
			pedir("monstro", { id = e.id, qtd = quantidadeMonstro })
		end)
	end
	local todas = botao(monstros, "Uma de cada espécie", #especies + 1, function()
		-- o servidor limita a frequência dos pedidos: um por vez
		task.spawn(function()
			for _, e in especies do
				pedir("monstro", { id = e.id, qtd = quantidadeMonstro })
				task.wait(0.15)
			end
		end)
	end)
	todas.BackgroundColor3 = COR_LIGADO
	botao(monstros, "Limpar meus monstros", #especies + 2, function()
		pedir("limparMonstros")
	end)

	-- Itens
	rotulo(lista, "Itens (quantidade ao clicar)", 100)
	local qtds = secao(lista, 101, 60)
	for i, q in CfgAdmin.quantidades do
		botoesQuantidade[q] = botao(qtds, tostring(q), i, function()
			quantidade = q
			destacarQuantidade()
		end)
	end
	destacarQuantidade()

	local novas: { [string]: boolean } = {}
	for _, id in CfgAdmin.armasNovas do
		novas[id] = true
	end
	for _, id in CfgAdmin.armasGoldBright do
		novas[id] = true
	end
	local itens = secao(lista, 102, 122)
	local ids = {}
	for id in CfgItens.itens do
		if not novas[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for i, id in ids do
		botao(itens, CfgItens.itens[id].nome, i, function()
			pedir("dar", { id = id, qtd = quantidade })
		end)
	end

	-- Armas novas: separadas da lista geral, abaixo dela. Arma = 1; munição = 1 pente inteiro (ignora a quantidade escolhida acima).
	rotulo(lista, "Armas novas (pane, engatilhar Q, checar munição Z)", 110)
	local secaoNovas = secao(lista, 111, 150)
	for i, id in CfgAdmin.armasNovas do
		local item = CfgItens.itens[id]
		if item then
			local qtd = if item.tipo == "municao" then (item.pente or 1) else 1
			local texto = if item.tipo == "municao" then string.format("%s (1 pente)", item.nome) else item.nome
			botao(secaoNovas, texto, i, function()
				pedir("dar", { id = id, qtd = qtd })
			end)
		end
	end

	-- Gold Bright: seção própria, abaixo das armas novas (viewmodel e animações do jogo original; mira no botão direito).
	rotulo(lista, "Gold Bright (botão direito mira, Q engatilha, Z checa, R recarrega)", 120)
	local secaoGB = secao(lista, 121, 150)
	for i, id in CfgAdmin.armasGoldBright do
		local item = CfgItens.itens[id]
		if item then
			botao(secaoGB, item.nome, i, function()
				pedir("dar", { id = id, qtd = 1 })
			end)
		end
	end

	return gui
end

-- Voo ----------------------------------------------------------------------------------------------------------------

local atachamento: Attachment? = nil
local velocidade: LinearVelocity? = nil

local function pararVoo()
	RunService:UnbindFromRenderStep("AdminVoo")
	if velocidade then
		velocidade:Destroy()
		velocidade = nil
	end
	if atachamento then
		atachamento:Destroy()
		atachamento = nil
	end
end

local function iniciarVoo()
	pararVoo()
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "AdminVooAttachment"
	a.Parent = raiz
	local v = Instance.new("LinearVelocity")
	v.Name = "AdminVoo"
	v.Attachment0 = a
	v.MaxForce = 1e8
	v.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.VectorVelocity = Vector3.zero
	v.Parent = raiz
	atachamento, velocidade = a, v

	RunService:BindToRenderStep("AdminVoo", Enum.RenderPriority.Character.Value, function()
		local camera = workspace.CurrentCamera
		if not camera or not velocidade or UserInputService:GetFocusedTextBox() then
			return
		end
		local function tecla(k: Enum.KeyCode): number
			return if UserInputService:IsKeyDown(k) then 1 else 0
		end
		local dir = camera.CFrame.LookVector * (tecla(Enum.KeyCode.W) - tecla(Enum.KeyCode.S))
			+ camera.CFrame.RightVector * (tecla(Enum.KeyCode.D) - tecla(Enum.KeyCode.A))
			+ Vector3.yAxis * (tecla(Enum.KeyCode.Space) - tecla(Enum.KeyCode.Q))
		local rapido = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then CfgAdmin.multVooRapido else 1
		velocidade.VectorVelocity = if dir.Magnitude > 0
			then dir.Unit * CfgAdmin.velocidadeVoo * rapido
			else Vector3.zero
	end)
end

local function atualizarVoo()
	if jogador:GetAttribute("AdminVoar") == true then
		iniciarVoo()
	else
		pararVoo()
	end
end

-- ----------------------------------------------------------------------------------------------------------------------

local function definirVisivel(visivel: boolean)
	if painel.Visible == visivel then
		return
	end
	painel.Visible = visivel
	if visivel then
		Mouse.pedir("Admin")
		for _, f in aoAtualizar do
			f()
		end
	else
		Mouse.liberar("Admin")
	end
end

function Admin.alternar()
	if jogador:GetAttribute("Admin") == true then
		definirVisivel(not painel.Visible)
	end
end

function Admin.iniciar()
	local gui = construir()
	gui.Parent = jogador:WaitForChild("PlayerGui")

	local function redimensionar()
		local camera = workspace.CurrentCamera
		if camera then
			local v = camera.ViewportSize
			escala.Scale = math.clamp(math.min(v.X / 600, v.Y / 500), 0.45, 1)
		end
	end
	redimensionar()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redimensionar)
	end

	Teclas.ligar("admin", { CfgAdmin.tecla, CfgAdmin.teclaReserva }, function()
		if jogador:GetAttribute("Admin") == true then
			definirVisivel(not painel.Visible)
		else
			-- Falha silenciosa era o pior caso: o servidor não marcou o jogador como admin (server/Admin.luau não rodou
			-- ou o place está com código antigo).
			warn("[Admin] menu bloqueado: o servidor não marcou o atributo Admin neste jogador")
		end
	end)

	-- Só no Studio: diz no Output se o menu está pronto, para separar "tecla não chegou" de "servidor não liberou".
	if RunService:IsStudio() then
		task.delay(5, function()
			print(
				string.format(
					"[Admin] menu pronto: teclas %s/%s, atributo Admin = %s",
					CfgAdmin.tecla,
					CfgAdmin.teclaReserva,
					tostring(jogador:GetAttribute("Admin"))
				)
			)
		end)
	end

	jogador:GetAttributeChangedSignal("AdminVoar"):Connect(atualizarVoo)
	jogador.CharacterAdded:Connect(function()
		task.wait(0.5)
		atualizarVoo()
	end)
	atualizarVoo()
end

return Admin
