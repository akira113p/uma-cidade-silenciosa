-- InventarioUI (cliente): barra de 8 slots, lista (Tab) com "Largar", janela de caixa/bolsa e barra de uso.
-- Dono: P6. Contrato: docs/arquitetura.md §P6. O cliente só pede (Rede) e mostra; o servidor decide.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Itens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local CfgArmas = require(Shared:WaitForChild("Config"):WaitForChild("Armas"))
local CfgCorpo = require(Shared:WaitForChild("Config"):WaitForChild("Corpo"))
local CfgSom = require(Shared:WaitForChild("Config"):WaitForChild("Som"))
local CfgLanterna = require(Shared.Config:WaitForChild("Lanterna"))
local CfgCombustivel = require(Shared.Config:WaitForChild("Combustivel"))
local Mouse = require(script.Parent.Mouse)
local Teclas = require(script.Parent.Teclas)
local ConfigMovimento = require(Shared:WaitForChild("Config"):WaitForChild("Movimento"))

local InventarioUI = {}

local jogador = Players.LocalPlayer

-- Aparência (um contorno só em toda a UI, como pede a skill ui-roblox)
local COR_FUNDO = Color3.fromRGB(22, 22, 26)
local COR_LINHA = Color3.fromRGB(34, 34, 40)
local COR_CONTORNO = Color3.fromRGB(78, 78, 88)
local COR_DESTAQUE = Color3.fromRGB(255, 160, 40)
local COR_TEXTO = Color3.fromRGB(236, 236, 238)
local COR_SUAVE = Color3.fromRGB(165, 165, 172)
local COR_BOTAO = Color3.fromRGB(58, 58, 68)
local CONTORNO = 2
local RAIO = 6
local TEXTO = 14 -- tamanho mínimo de texto
local ALVO_TOQUE = 44 -- altura mínima de botão
local FONTE = Font.fromEnum(Enum.Font.GothamMedium)
local FONTE_NEGRITO = Font.fromEnum(Enum.Font.GothamBold)

local DISTANCIA_FECHAR = 10 -- studs até a janela de caixa/bolsa fechar sozinha
local MARGEM_BARRA = 12
local FOLGA_ESCOLHA_USO = 1 -- s: a tecla apertada conta como "o item que está sendo usado" por este tempo

local TECLAS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

type Ocupado = { slot: number, id: string, qtd: number, pente: number? }
type Painel = { raiz: Frame, titulo: TextLabel, lista: ScrollingFrame, vazio: TextLabel }
type Tela = {
	raiz: Frame,
	escala: UIScale,
	celulas: { TextButton },
	nome: TextLabel,
	tipo: TextLabel,
	descricao: TextLabel,
	botaoPrincipal: TextButton,
	botaoLargar: TextButton,
	corpo: TextLabel,
}

local gui: ScreenGui
local barra: Frame
local botaoSlots: { TextButton } = {}
local botaoMochila: TextButton? = nil
local tela: Tela
local selecionado: number? = nil
local apertarSlot: (number) -> ()
local painelCaixa: Painel
local barraUso: Frame
local enchimentoUso: Frame
local textoUso: TextLabel
local tamanhoSlot = 64

local porSlot: { [number]: Ocupado } = {}
local abertaCaixa: Instance? = nil
local ultimoUso: { id: string, t: number }? = nil
local tweenUso: Tween? = nil

-- Construção ----------------------------------------------------------------------------------------------------

local function nome(id: string): string
	local def = Itens.itens[id]
	return if def then def.nome else id
end

-- Nome curto para o slot: inteiro se couber, senão a primeira palavra.
local function nomeCurto(id: string): string
	local n = nome(id)
	if #n <= 9 then
		return n
	end
	return n:match("^(%S+)") or n
end

local function acabamento(objeto: GuiObject, cor: Color3?)
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, RAIO)
	canto.Parent = objeto
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = CONTORNO
	contorno.Color = cor or COR_CONTORNO
	contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contorno.Parent = objeto
end

local function texto(pai: Instance, propriedades: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = FONTE
	t.TextSize = TEXTO
	t.TextColor3 = COR_TEXTO
	t.TextTruncate = Enum.TextTruncate.AtEnd
	for chave, valor in propriedades do
		(t :: any)[chave] = valor
	end
	t.Parent = pai
	return t
end

local function botao(pai: Instance, rotulo: string, largura: number): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = COR_BOTAO
	b.FontFace = FONTE_NEGRITO
	b.Text = rotulo
	b.TextSize = TEXTO
	b.TextColor3 = COR_TEXTO
	b.Size = UDim2.fromOffset(largura, ALVO_TOQUE)
	acabamento(b)
	b.Parent = pai
	return b
end

local function criarPainel(tituloInicial: string): Painel
	local raiz = Instance.new("Frame")
	raiz.AnchorPoint = Vector2.new(0.5, 0.5)
	raiz.Position = UDim2.fromScale(0.5, 0.45)
	raiz.Size = UDim2.fromScale(0.9, 0.7)
	raiz.BackgroundColor3 = COR_FUNDO
	raiz.BackgroundTransparency = 0.1
	raiz.Visible = false
	acabamento(raiz)
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(420, 380)
	limite.Parent = raiz
	raiz.Parent = gui

	local titulo = texto(raiz, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30),
		Text = tituloInicial,
		FontFace = FONTE_NEGRITO,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local lista = Instance.new("ScrollingFrame")
	lista.Position = UDim2.fromOffset(8, 40)
	lista.Size = UDim2.new(1, -16, 1, -48)
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = 4
	lista.CanvasSize = UDim2.new()
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.Parent = raiz
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lista

	local vazio = texto(raiz, {
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Vazio",
		TextColor3 = COR_SUAVE,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	return { raiz = raiz, titulo = titulo, lista = lista, vazio = vazio }
end

-- Uma linha por item: "Nome  x3" à esquerda e o botão de ação à direita.
local function preencher(
	painel: Painel,
	linhas: { { rotulo: string, qtd: number } },
	acao: string,
	aoClicar: (number) -> ()
)
	for _, filho in painel.lista:GetChildren() do
		if filho:IsA("Frame") then
			filho:Destroy()
		end
	end
	painel.vazio.Visible = #linhas == 0
	for i, linha in linhas do
		local f = Instance.new("Frame")
		f.Name = tostring(i)
		f.LayoutOrder = i
		f.Size = UDim2.new(1, -4, 0, 52)
		f.BackgroundColor3 = COR_LINHA
		acabamento(f)
		texto(f, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -124, 1, 0),
			Text = if linha.qtd > 1 then string.format("%s  x%d", linha.rotulo, linha.qtd) else linha.rotulo,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local b = botao(f, acao, 96)
		b.Name = acao
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -4, 0.5, 0)
		b.Activated:Connect(function()
			aoClicar(i)
		end)
		f.Parent = painel.lista
	end
end

-- Estado -------------------------------------------------------------------------------------------------------

local function slotEquipado(): number?
	local arma = jogador:GetAttribute("ArmaEquipada")
	if type(arma) ~= "string" then
		return nil
	end
	for slot = 1, Itens.slots do
		local o = porSlot[slot]
		local def = o and Itens.itens[o.id]
		if def and def.arma == arma then
			return slot
		end
	end
	return nil
end

-- Lanterna equipada (atributo LanternaSlot do servidor). Vale ao mesmo tempo que a arma da mão.
local function slotLanterna(): number?
	local slot = jogador:GetAttribute("LanternaSlot")
	return if type(slot) == "number" then slot else nil
end

-- Recipiente de combustível na mão (atributo RecipienteSlot do servidor). Vale no lugar da arma/mangueira.
local function slotRecipiente(): number?
	local slot = jogador:GetAttribute("RecipienteSlot")
	return if type(slot) == "number" then slot else nil
end

local function atualizarBarra()
	local equipado = slotEquipado()
	local lanterna = slotLanterna()
	local recipiente = slotRecipiente()
	for slot = 1, Itens.slots do
		local b = botaoSlots[slot]
		local o = porSlot[slot]
		local nomeLabel = b:FindFirstChild("Nome") :: TextLabel
		local qtdLabel = b:FindFirstChild("Qtd") :: TextLabel
		nomeLabel.Text = if o then nomeCurto(o.id) else ""
		qtdLabel.Text = if o and o.qtd > 1 then "x" .. o.qtd else ""
		local contorno = b:FindFirstChildOfClass("UIStroke") :: UIStroke
		contorno.Color = if slot == equipado
				or slot == lanterna
				or slot == recipiente
			then COR_DESTAQUE
			else COR_CONTORNO
		b.BackgroundTransparency = if o then 0.15 else 0.45
	end
end

-- Tela do inventário (Tab) ---------------------------------------------------------------------------------------

local function corVida(fracao: number): string
	if fracao <= 0 then
		return "#7a7a80"
	elseif fracao < 0.35 then
		return "#e0564a"
	elseif fracao < 0.7 then
		return "#e8c14a"
	end
	return "#6fcf7a"
end

local function atualizarCorpo()
	local partes = {
		{ "Cabeça", "Cabeca" },
		{ "Torso", "Torso" },
		{ "Braço E", "BracoE" },
		{ "Braço D", "BracoD" },
		{ "Perna E", "PernaE" },
		{ "Perna D", "PernaD" },
	}
	local textos = {}
	for _, par in partes do
		local max = CfgCorpo.partes[par[2]].vida
		local atual = jogador:GetAttribute("Vida_" .. par[2])
		atual = if type(atual) == "number" then atual else max
		table.insert(
			textos,
			string.format(
				'%s <font color="%s">%d/%d</font>',
				par[1],
				corVida(atual / max),
				math.floor(atual + 0.5),
				max
			)
		)
	end
	local function textoBarra(rotulo: string, atributo: string): string
		local v = jogador:GetAttribute(atributo)
		v = if type(v) == "number" then v else 100
		return string.format('%s <font color="%s">%d</font>', rotulo, corVida(v / 100), math.floor(v + 0.5))
	end
	tela.corpo.Text = string.format(
		"%s     %s\n%s     %s\n%s     %s\n\n%s     %s     %s     %s",
		textos[1],
		textos[2],
		textos[3],
		textos[4],
		textos[5],
		textos[6],
		textoBarra("Fome", "Fome"),
		textoBarra("Sede", "Sede"),
		textoBarra("Calor", "Calor"),
		textoBarra("Estamina", "Estamina")
	)
end

-- Texto de ajuda de cada tipo de item, tirado do Config (nenhum número escrito aqui).
local function detalhesDe(id: string, pente: number?, reserva: number?): (string, string, string?)
	local def = Itens.itens[id]
	if not def then
		return id, "", nil
	end
	local db = def.ruido and CfgSom.acoes[def.ruido]
	local ruido = if db then string.format("\nFaz %d dB.", db) else ""
	if def.tipo == "comida" then
		local resumo =
			string.format("Restaura %d de fome.\nLeva %.1f s para comer.%s", def.fome or 0, def.uso or 0, ruido)
		return "Comida", resumo, "Usar"
	elseif def.tipo == "bebida" then
		local extra = if def.fome then string.format(" e %d de fome", def.fome) else ""
		local resumo = string.format(
			"Restaura %d de sede%s.\nLeva %.1f s para beber.%s",
			def.sede or 0,
			extra,
			def.uso or 0,
			ruido
		)
		return "Bebida", resumo, "Usar"
	elseif def.tipo == "cura" then
		local resumo =
			string.format("Cura %d na parte do corpo mais ferida.\nLeva %.1f s.%s", def.cura or 0, def.uso or 0, ruido)
		return "Cura", resumo, "Usar"
	elseif def.tipo == "arma" then
		local arma = CfgArmas.armas[def.arma]
		if not arma then
			return "Arma", "", "Equipar"
		end
		local resumo = string.format(
			"Dano %d.\nAlcance %d studs.\n%.2f s entre ataques.\nFaz %d dB.",
			arma.dano,
			arma.alcance,
			arma.cadencia,
			arma.ruidoDb
		)
		if arma.duasMaos then
			resumo ..= "\nUsa as duas mãos."
		end
		if arma.municao then
			resumo ..= string.format("\nCalibre: %s.", nome(arma.municao))
			-- pente atual (se o servidor já informou) e quanto cabe; reserva = munição do calibre na mochila
			local cheio = arma.pente or 1
			if pente then
				resumo ..= string.format("\nPente: %d/%d.", pente, cheio)
			else
				resumo ..= string.format("\nPente: %d.", cheio)
			end
			if reserva then
				resumo ..= string.format("\nReserva: %d.", reserva)
			end
		end
		return if arma.tipo == "fogo" then "Arma de fogo" else "Arma corpo a corpo", resumo, "Equipar"
	elseif def.tipo == "municao" then
		return "Munição", "Gasta automaticamente ao atirar.", nil
	elseif def.tipo == "lanterna" then
		local tecla = CfgLanterna.teclas[1] or "F"
		local resumo = tecla .. " liga e apaga.\nSilenciosa, mas os outros jogadores veem o facho."
		return "Lanterna", resumo, "Equipar"
	elseif def.tipo == "recipiente" then
		local rec = CfgCombustivel.recipientes[id]
		local resumo = "Segure e use na bomba de combustível ou na tampa de um carro."
		if rec and rec.litros then
			resumo = string.format("Contém %s L de gasolina.\nDespeje na tampa de um carro.", tostring(rec.litros))
		elseif rec and rec.capacidade then
			resumo = string.format("Vazio. Cabe %s L.\nEncha numa bomba de combustível.", tostring(rec.capacidade))
		end
		return "Recipiente", resumo, "Segurar"
	end
	return def.tipo, "", nil
end

local function primeiroOcupado(): number?
	for slot = 1, Itens.slots do
		if porSlot[slot] then
			return slot
		end
	end
	return nil
end

local function atualizarTela()
	if not tela.raiz.Visible then
		return
	end
	if selecionado == nil or porSlot[selecionado] == nil then
		selecionado = primeiroOcupado()
	end
	local equipado = slotEquipado()
	local lanterna = slotLanterna()
	local recipiente = slotRecipiente()
	for slot = 1, Itens.slots do
		local c = tela.celulas[slot]
		local o = porSlot[slot];
		(c:FindFirstChild("Nome") :: TextLabel).Text = if o then nome(o.id) else ""
		local rodape = c:FindFirstChild("Qtd") :: TextLabel
		rodape.Text = if slot == equipado or slot == lanterna
			then "equipada"
			elseif slot == recipiente then "na mão"
			elseif o and o.qtd > 1 then "x" .. o.qtd
			else ""
		local contorno = c:FindFirstChildOfClass("UIStroke") :: UIStroke
		contorno.Color = if slot == selecionado
			then COR_TEXTO
			elseif slot == equipado or slot == lanterna or slot == recipiente then COR_DESTAQUE
			else COR_CONTORNO
		contorno.Thickness = if slot == selecionado then 3 else CONTORNO
		c.BackgroundTransparency = if o then 0.1 else 0.45
	end

	local o = selecionado and porSlot[selecionado]
	if not o then
		tela.nome.Text = "Mochila vazia"
		tela.tipo.Text = ""
		tela.descricao.Text = "Pegue itens nas caixas e no chão. As teclas 1 a 8 usam os itens fora desta tela."
		tela.botaoPrincipal.Visible = false
		tela.botaoLargar.Visible = false
	else
		-- pente: da arma equipada vem do atributo (sempre fresco); das outras, do campo `pente` do slot
		local pente, reserva = o.pente, nil
		local defSel = Itens.itens[o.id]
		local cfgSel = defSel and defSel.arma and CfgArmas.armas[defSel.arma]
		if cfgSel and cfgSel.municao then
			if selecionado == equipado and type(jogador:GetAttribute("Pente")) == "number" then
				pente = jogador:GetAttribute("Pente")
			end
			reserva = 0
			for _, outro in porSlot do
				if outro.id == cfgSel.municao then
					reserva += outro.qtd
				end
			end
		end
		local tipo, descricao, acao = detalhesDe(o.id, pente, reserva)
		tela.nome.Text = if o.qtd > 1 then string.format("%s  x%d", nome(o.id), o.qtd) else nome(o.id)
		tela.tipo.Text = tipo
		tela.descricao.Text = descricao
		local naMao = (acao == "Equipar" and (selecionado == equipado or selecionado == lanterna))
			or (acao == "Segurar" and selecionado == recipiente)
		if naMao then
			acao = "Guardar"
		end
		tela.botaoPrincipal.Visible = acao ~= nil
		tela.botaoPrincipal.Text = acao or ""
		tela.botaoLargar.Visible = true
	end
	atualizarCorpo()
end

local function selecionar(slot: number)
	selecionado = slot
	atualizarTela()
end

local function criarTela()
	local raiz = Instance.new("Frame")
	raiz.Name = "Inventario"
	raiz.AnchorPoint = Vector2.new(0.5, 0.5)
	raiz.Position = UDim2.fromScale(0.5, 0.46)
	raiz.Size = UDim2.fromOffset(660, 410)
	raiz.BackgroundColor3 = COR_FUNDO
	raiz.BackgroundTransparency = 0.05
	raiz.Visible = false
	acabamento(raiz)
	local escala = Instance.new("UIScale")
	escala.Parent = raiz
	raiz.Parent = gui

	texto(raiz, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(300, 30),
		Text = "Inventário",
		FontFace = FONTE_NEGRITO,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	texto(raiz, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(200, 24),
		Text = "Tab fecha",
		TextColor3 = COR_SUAVE,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local grade = Instance.new("Frame")
	grade.Position = UDim2.fromOffset(14, 48)
	grade.Size = UDim2.fromOffset(424, 208)
	grade.BackgroundTransparency = 1
	grade.Parent = raiz
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(100, 100)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grade

	local celulas: { TextButton } = {}
	for slot = 1, Itens.slots do
		local b = Instance.new("TextButton")
		b.Name = "Celula" .. slot
		b.LayoutOrder = slot
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = COR_LINHA
		acabamento(b)
		texto(b, {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(24, 16),
			Text = tostring(slot),
			TextColor3 = COR_SUAVE,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		texto(b, {
			Name = "Nome",
			Position = UDim2.fromOffset(4, 26),
			Size = UDim2.new(1, -8, 0, 44),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
		})
		texto(b, {
			Name = "Qtd",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -4),
			Size = UDim2.new(1, -12, 0, 16),
			TextColor3 = COR_DESTAQUE,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		b.Activated:Connect(function()
			selecionar(slot)
		end)
		b.Parent = grade
		celulas[slot] = b
	end

	texto(raiz, {
		Position = UDim2.fromOffset(14, 268),
		Size = UDim2.fromOffset(300, 22),
		Text = "Corpo e estado",
		FontFace = FONTE_NEGRITO,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local corpo = texto(raiz, {
		Position = UDim2.fromOffset(14, 294),
		Size = UDim2.fromOffset(424, 108),
		RichText = true,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})

	local det = Instance.new("Frame")
	det.Position = UDim2.fromOffset(452, 48)
	det.Size = UDim2.fromOffset(194, 350)
	det.BackgroundColor3 = COR_LINHA
	acabamento(det)
	det.Parent = raiz
	local nomeLabel = texto(det, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(174, 26),
		FontFace = FONTE_NEGRITO,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local tipoLabel = texto(det, {
		Position = UDim2.fromOffset(10, 36),
		Size = UDim2.fromOffset(174, 18),
		TextColor3 = COR_SUAVE,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local descricao = texto(det, {
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.fromOffset(174, 170),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local principal = botao(det, "Usar", 174)
	principal.Position = UDim2.fromOffset(10, 244)
	local largar = botao(det, "Largar", 174)
	largar.Position = UDim2.fromOffset(10, 296)

	principal.Activated:Connect(function()
		local slot = selecionado
		if slot and porSlot[slot] then
			apertarSlot(slot)
		end
	end)
	largar.Activated:Connect(function()
		if selecionado and porSlot[selecionado] then
			Rede.evento("LargarItem"):FireServer(selecionado)
		end
	end)

	tela = {
		raiz = raiz,
		escala = escala,
		celulas = celulas,
		nome = nomeLabel,
		tipo = tipoLabel,
		descricao = descricao,
		botaoPrincipal = principal,
		botaoLargar = largar,
		corpo = corpo,
	}
end

local function definirLista(visivel: boolean)
	if tela.raiz.Visible == visivel then
		return
	end
	tela.raiz.Visible = visivel
	if visivel then
		Mouse.pedir("Inventario")
		atualizarTela()
	else
		Mouse.liberar("Inventario")
	end
end

local function alternarLista(ligado: boolean?)
	definirLista(if ligado == nil then not tela.raiz.Visible else ligado)
end

local function reativarPrompt(container: Instance?)
	local prompt = container and container:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
end

local function fecharCaixa()
	reativarPrompt(abertaCaixa)
	abertaCaixa = nil
	painelCaixa.raiz.Visible = false
	Mouse.liberar("Caixa")
end

local function mostrarCaixa(container: Instance, itens: { { id: string, qtd: number } })
	if abertaCaixa ~= container then
		reativarPrompt(abertaCaixa)
		abertaCaixa = container
		-- Prompt desligado só neste cliente: assim o E fecha a janela em vez de reabri-la.
		local prompt = container:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end
	definirLista(false)
	local nomeContainer = container:GetAttribute("Nome")
	if type(nomeContainer) == "string" then
		painelCaixa.titulo.Text = nomeContainer
	else
		painelCaixa.titulo.Text = if container:GetAttribute("Bolsa") then "Bolsa" else "Caixa"
	end
	local linhas = {}
	for _, item in itens do
		table.insert(linhas, { rotulo = nome(item.id), qtd = item.qtd })
	end
	preencher(painelCaixa, linhas, "Pegar", function(i: number)
		if abertaCaixa then
			Rede.evento("PegarItem"):FireServer(abertaCaixa, i)
		end
	end)
	painelCaixa.raiz.Visible = true
	Mouse.pedir("Caixa")
end

-- Ações ----------------------------------------------------------------------------------------------------------

function apertarSlot(slot: number)
	local o = porSlot[slot]
	if not o then
		return
	end
	local def = Itens.itens[o.id]
	if def and def.tipo == "arma" then
		Rede.evento("Equipar"):FireServer(if slotEquipado() == slot then nil else slot)
	elseif def and def.tipo == "lanterna" then
		Rede.evento("Equipar"):FireServer(slot) -- o servidor equipa ou guarda (alterna) sem mexer na arma
	else
		ultimoUso = { id = o.id, t = os.clock() }
		Rede.evento("UsarItem"):FireServer(slot)
	end
end

local function aoApertarE(_nome: string, estado: Enum.UserInputState): Enum.ContextActionResult
	if estado == Enum.UserInputState.Begin and abertaCaixa then
		fecharCaixa()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function aoApertarNumero(
	_nome: string,
	estado: Enum.UserInputState,
	entrada: InputObject
): Enum.ContextActionResult
	local slot = TECLAS[entrada.KeyCode]
	if slot and estado == Enum.UserInputState.Begin then
		apertarSlot(slot)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

-- Barra de uso (progresso enquanto o atributo Usando é true) -------------------------------------------------

local function atualizarUso()
	if tweenUso then
		tweenUso:Cancel()
		tweenUso = nil
	end
	if jogador:GetAttribute("Usando") ~= true then
		barraUso.Visible = false
		return
	end
	local recente = ultimoUso and os.clock() - ultimoUso.t <= FOLGA_ESCOLHA_USO
	local id = if recente and ultimoUso then ultimoUso.id else nil
	local def = id and Itens.itens[id]
	local duracao = if def and def.uso then def.uso else 2
	textoUso.Text = if id then nome(id) else "Usando"
	enchimentoUso.Size = UDim2.fromScale(0, 1)
	barraUso.Visible = true
	local t = TweenService:Create(
		enchimentoUso,
		TweenInfo.new(duracao, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	tweenUso = t
	t:Play()
end

-- Layout responsivo -----------------------------------------------------------------------------------------------

local function redimensionar()
	local camera = workspace.CurrentCamera
	local largura = if camera then camera.ViewportSize.X else 800
	local itens = Itens.slots + (if botaoMochila then 1 else 0)
	tamanhoSlot = math.clamp(math.floor((largura - 24 - (itens - 1) * 4) / itens), 56, 76)
	for _, b in botaoSlots do
		b.Size = UDim2.fromOffset(tamanhoSlot, tamanhoSlot)
	end
	if botaoMochila then
		botaoMochila.Size = UDim2.fromOffset(tamanhoSlot, tamanhoSlot)
	end
	barra.Size = UDim2.fromOffset(itens * tamanhoSlot + (itens - 1) * 4, tamanhoSlot)
	barraUso.Position = UDim2.new(0.5, 0, 1, -(MARGEM_BARRA + tamanhoSlot + 10))
	if tela then
		local altura = if camera then camera.ViewportSize.Y else 600
		tela.escala.Scale = math.clamp(math.min(largura / 690, altura / 440), 0.45, 1)
	end
end

local function criarBarra()
	barra = Instance.new("Frame")
	barra.Name = "Barra"
	barra.AnchorPoint = Vector2.new(0.5, 1)
	barra.Position = UDim2.new(0.5, 0, 1, -MARGEM_BARRA)
	barra.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = barra
	barra.Parent = gui

	for slot = 1, Itens.slots do
		local b = Instance.new("TextButton")
		b.Name = "Slot" .. slot
		b.LayoutOrder = slot
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = COR_FUNDO
		acabamento(b)
		texto(b, {
			Name = "Tecla",
			Position = UDim2.fromOffset(5, 2),
			Size = UDim2.fromOffset(20, 16),
			Text = tostring(slot),
			TextColor3 = COR_SUAVE,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		texto(b, {
			Name = "Nome",
			Position = UDim2.fromOffset(3, 19),
			Size = UDim2.new(1, -6, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		texto(b, {
			Name = "Qtd",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -2),
			Size = UDim2.fromOffset(40, 16),
			TextColor3 = COR_DESTAQUE,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		b.Activated:Connect(function()
			apertarSlot(slot)
		end)
		b.Parent = barra
		botaoSlots[slot] = b
	end

	if UserInputService.TouchEnabled then
		local m = botao(barra, "Mochila", 64)
		m.LayoutOrder = Itens.slots + 1
		m.Activated:Connect(function()
			if abertaCaixa then
				fecharCaixa()
			else
				alternarLista()
			end
		end)
		botaoMochila = m
	end
end

local function criarBarraUso()
	barraUso = Instance.new("Frame")
	barraUso.Name = "Uso"
	barraUso.AnchorPoint = Vector2.new(0.5, 1)
	barraUso.Size = UDim2.fromOffset(240, 26)
	barraUso.BackgroundColor3 = COR_FUNDO
	barraUso.BackgroundTransparency = 0.15
	barraUso.Visible = false
	acabamento(barraUso)
	barraUso.Parent = gui

	enchimentoUso = Instance.new("Frame")
	enchimentoUso.Name = "Enchimento"
	enchimentoUso.Size = UDim2.fromScale(0, 1)
	enchimentoUso.BackgroundColor3 = COR_DESTAQUE
	enchimentoUso.BackgroundTransparency = 0.35
	enchimentoUso.BorderSizePixel = 0
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, RAIO)
	canto.Parent = enchimentoUso
	enchimentoUso.Parent = barraUso

	textoUso = texto(barraUso, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
end

-- Abre/fecha a tela do Tab (usado pelo gancho de teste do Studio e pelo botão de celular).
function InventarioUI.alternar()
	alternarLista()
end

function InventarioUI.iniciar()
	-- A mochila padrão do Roblox esconde os números 1..8 e desenha outra barra; aqui o inventário é nosso.
	task.spawn(function()
		for _ = 1, 10 do
			local ok1 = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			local ok2 = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
			if ok1 and ok2 then
				break
			end
			task.wait(1)
		end
	end)

	gui = Instance.new("ScreenGui")
	gui.Name = "InventarioUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = jogador:WaitForChild("PlayerGui")

	criarTela()
	painelCaixa = criarPainel("Caixa")
	criarBarra()
	criarBarraUso()
	redimensionar()
	atualizarBarra()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redimensionar)
	end

	Teclas.ligar("inventario", ConfigMovimento.teclas.inventario, function()
		if abertaCaixa then
			fecharCaixa()
		else
			alternarLista()
		end
	end)
	ContextActionService:BindActionAtPriority(
		"InventarioE",
		aoApertarE,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E
	)
	ContextActionService:BindAction(
		"InventarioNumeros",
		aoApertarNumero,
		false,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight
	)

	Rede.evento("Inventario").OnClientEvent:Connect(function(lista: { Ocupado }, _equipado: number?)
		porSlot = {}
		for _, o in lista do
			porSlot[o.slot] = o
		end
		atualizarBarra()
		atualizarTela()
	end)

	Rede.evento("ConteudoCaixa").OnClientEvent
		:Connect(function(container: Instance?, itens: { { id: string, qtd: number } }?)
			if container == nil or container.Parent == nil or itens == nil then
				fecharCaixa()
				return
			end
			mostrarCaixa(container, itens)
		end)

	jogador:GetAttributeChangedSignal("Usando"):Connect(atualizarUso)
	for _, atributo in { "ArmaEquipada", "LanternaSlot", "RecipienteSlot", "Pente" } do
		jogador:GetAttributeChangedSignal(atributo):Connect(function()
			atualizarBarra()
			atualizarTela()
		end)
	end
	-- Corpo e barras da tela do inventário mudam o tempo todo: atualiza a 2 Hz enquanto ela está aberta.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if tela.raiz.Visible then
				atualizarCorpo()
			end
		end
	end)

	-- Fecha a janela ao se afastar ou quando a caixa/bolsa some.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local aberta = abertaCaixa
			if aberta then
				local hrp = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
				local longe = true
				if aberta.Parent and hrp and aberta:IsA("BasePart") then
					longe = ((hrp :: BasePart).Position - aberta.Position).Magnitude > DISTANCIA_FECHAR
				end
				if longe then
					fecharCaixa()
				end
			end
		end
	end)

	-- INTEGRACAO: não existe evento "pedir inventário"; UsarItem(0) faz o servidor reenviar o estado.
	Rede.evento("UsarItem"):FireServer(0)
end

return InventarioUI
