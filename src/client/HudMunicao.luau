-- HudMunicao (nova, 2026-11-14): SEM contador numérico. Canto inferior direito, só quando há arma de fogo na mão:
--   * aviso fixo enquanto a arma está TRAVADA ou DESENGATILHADA (com a tecla de engatilhar);
--   * ao CHECAR a munição (tecla Z) duas frases: como está o pente e quantos pentes sobram na reserva (docs/armas.md §13.5);
--   * "Sem balas." por um instante quando o gatilho bate no vazio.
-- Só mostra: lê os atributos Pente, Reserva, Engatilhada, Travada, ArmaEquipada e os sinais de ArmasSinais.
-- Dono: A5 (docs/armas.md §10.3, reescrita no §13). O quanto de munição sobra também está no inventário (Tab).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CfgArmas = require(Config:WaitForChild("Armas"))
local CfgMovimento = require(Config:WaitForChild("Movimento"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Armas"))
local ArmasSinais = require(script.Parent.ArmasSinais)

local HudMunicao = {}

local jogador = Players.LocalPlayer

-- Mesmo visual dos outros HUDs (HudVida): fonte Code, contorno único de 1,5 px, texto mínimo 14.
local FONTE = Enum.Font.Code
local TEXTO_MIN = 14
local TEXTO_AVISO = 22
local COR_TEXTO = Color3.fromRGB(235, 235, 230)
local COR_SUAVE = Color3.fromRGB(170, 170, 165)
local COR_ATENCAO = Color3.fromRGB(220, 200, 60)
local COR_PERIGO = Color3.fromRGB(220, 70, 55)
local COR_CONTORNO = Color3.fromRGB(8, 8, 10)

local ATRASO_FRASE = 0.4 -- fração da animação de checar em que as frases aparecem (o pente já está à vista)
local DURACAO_FRASE = 3.5 -- s com as frases na tela
local DURACAO_VAZIO = 1.6 -- s de "Sem balas."
local FADE = 0.6 -- s para apagar

local function criar(classe: string, propriedades: { [string]: any }, pai: Instance?): any
	local inst = Instance.new(classe)
	for nome, valor in propriedades do
		(inst :: any)[nome] = valor
	end
	inst.Parent = pai
	return inst
end

local function texto(pai: Instance, propriedades: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = FONTE,
		TextColor3 = COR_TEXTO,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = COR_CONTORNO,
		TextSize = TEXTO_MIN,
		TextXAlignment = Enum.TextXAlignment.Right,
	}
	for nome, valor in propriedades do
		base[nome] = valor
	end
	return criar("TextLabel", base, pai)
end

local function armaAtual(): (string?, any)
	local id = jogador:GetAttribute("ArmaEquipada")
	if type(id) ~= "string" then
		return nil, nil
	end
	local cfg = CfgArmas.armas[id]
	if cfg and cfg.tipo == "fogo" then
		return id, cfg
	end
	return nil, nil
end

-- Nome da primeira tecla de engatilhar para o aviso ("Q").
local function teclaEngatilhar(): string
	local t = (CfgMovimento.teclas :: any).engatilhar
	return if type(t) == "table" and type(t[1]) == "string" then t[1] else "Q"
end

function HudMunicao.iniciar()
	local tela = criar("ScreenGui", {
		Name = "HudMunicao",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, jogador:WaitForChild("PlayerGui"))

	local painel = criar("Frame", {
		Name = "Painel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 78),
	}, tela)

	local aviso = texto(painel, {
		Name = "Aviso",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = TEXTO_AVISO,
		Visible = false,
	})
	local linhaPente = texto(painel, {
		Name = "Pente",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 20),
		Visible = false,
	})
	local linhaReserva = texto(painel, {
		Name = "Reserva",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = COR_SUAVE,
		Visible = false,
	})

	-- as frases são escritas no instante em que aparecem (a munição pode ter mudado durante a animação)
	local fraseAte = -math.huge
	local vazioAte = -math.huge
	local ficha = 0 -- cancelar a checagem pendente (disparou, recarregou, trocou de arma)

	local function esconderFrases()
		ficha += 1
		fraseAte = -math.huge
	end

	local ArmasCliente: any = nil
	local okRequire, modulo = pcall(function()
		return require(script.Parent.ArmasCliente)
	end)
	if okRequire then
		ArmasCliente = modulo
	end

	local function penteAgora(): number
		local p: number? = nil
		if ArmasCliente and ArmasCliente.pente then
			p = ArmasCliente.pente()
		end
		if p == nil then
			local servidor = jogador:GetAttribute("Pente")
			p = if type(servidor) == "number" then servidor else 0
		end
		return math.max(0, math.floor(p :: number))
	end

	local function mostrarFrases(id: string)
		local _, cfg = armaAtual()
		if not cfg or jogador:GetAttribute("ArmaEquipada") ~= id then
			return
		end
		local pente = penteAgora()
		local reservaAttr = jogador:GetAttribute("Reserva")
		local reserva = if type(reservaAttr) == "number" then math.max(0, math.floor(reservaAttr)) else 0
		if cfg.pente <= 1 then
			-- lançador: um tiro por vez
			linhaPente.Text = if pente >= 1 then "Carregado." else "Vazio."
			linhaReserva.Text = if reserva > 0 then string.format("Reserva: %d.", reserva) else "Sem reserva."
		else
			linhaPente.Text = Regras.frasePente(pente, cfg.pente)
			linhaReserva.Text = Regras.fraseReserva(reserva, cfg.pente)
		end
		linhaPente.TextColor3 = if pente <= 0
			then COR_PERIGO
			elseif pente / cfg.pente <= 0.25 then COR_ATENCAO
			else COR_TEXTO
		fraseAte = os.clock() + DURACAO_FRASE
	end

	ArmasSinais.ouvir("checou", function(id: string, duracao: number)
		ficha += 1
		local minha = ficha
		fraseAte = -math.huge
		task.delay(duracao * ATRASO_FRASE, function()
			if ficha == minha then
				mostrarFrases(id)
			end
		end)
	end)
	for _, nome in { "disparou", "recarregou", "engatilhou", "equipou" } do
		ArmasSinais.ouvir(nome, esconderFrases)
	end
	-- gatilho no vazio (sem ser pane/desengatilhada, que já têm o aviso fixo)
	ArmasSinais.ouvir("vazio", function(id: string)
		if jogador:GetAttribute("Travada") == true or jogador:GetAttribute("Engatilhada") == false then
			return
		end
		if penteAgora() <= 0 and jogador:GetAttribute("ArmaEquipada") == id then
			vazioAte = os.clock() + DURACAO_VAZIO
		end
	end)

	local function transparencia(ate: number, agora: number): number
		local resta = ate - agora
		if resta <= 0 then
			return 1
		end
		return 1 - math.clamp(resta / FADE, 0, 1)
	end

	local function atualizar()
		local id, cfg = armaAtual()
		local visivel = id ~= nil and jogador:GetAttribute("Morto") ~= true
		tela.Enabled = visivel
		if not visivel or not cfg then
			return
		end
		local agora = os.clock()

		-- aviso fixo: pane vence desengatilhada vence "sem balas"
		local mensagem: string? = nil
		local cor = COR_TEXTO
		if jogador:GetAttribute("Travada") == true then
			mensagem = string.format("ARMA TRAVADA  [%s]", teclaEngatilhar())
			cor = COR_PERIGO
		elseif
			jogador:GetAttribute("Engatilhada") == false
			and jogador:GetAttribute("Engatilhando") ~= true
			and Regras.usaEngatilhar(cfg)
			and penteAgora() > 0
		then
			mensagem = string.format("ENGATILHE  [%s]", teclaEngatilhar())
			cor = COR_ATENCAO
		elseif agora < vazioAte then
			mensagem = "Sem balas."
			cor = COR_PERIGO
		end
		aviso.Visible = mensagem ~= nil
		if mensagem ~= nil then
			aviso.Text = mensagem
			aviso.TextColor3 = cor
			aviso.TextTransparency = if agora < vazioAte and mensagem == "Sem balas."
				then transparencia(vazioAte, agora)
				else 0
		end

		local t = transparencia(fraseAte, agora)
		local mostrando = t < 1
		linhaPente.Visible = mostrando
		linhaReserva.Visible = mostrando
		if mostrando then
			linhaPente.TextTransparency = t
			linhaReserva.TextTransparency = t
			linhaPente.TextStrokeTransparency = 0.3 + 0.7 * t
			linhaReserva.TextStrokeTransparency = 0.3 + 0.7 * t
		end
	end

	jogador:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
		esconderFrases()
		vazioAte = -math.huge
	end)
	RunService.Heartbeat:Connect(atualizar)
	atualizar()
end

return HudMunicao
