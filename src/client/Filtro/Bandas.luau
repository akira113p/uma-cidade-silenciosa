-- Filtro/Bandas: bandas escuras que descem pela tela (RollingBands do DitherDown; docs/filtro-ditherdown.md §2, §5).
-- Um ImageLabel de altura H + período em mosaico: a textura é 1 período da onda (1 px de largura, `alturaTexel` de altura) com
-- TileSize.Y = período em px. A rolagem é só deslocar a Position.Y de 0 a um período, e a volta não tem costura. Único trabalho
-- por quadro: uma conta e, se o pixel inteiro mudou, uma atribuição de Position. A textura só é refeita quando força ou ajuste
-- mudam. Esta camada se move: o seletor avisa, e a velocidade padrão é baixa por conforto.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("FiltroRetro"))
local RetroTextura = require(script.Parent:WaitForChild("RetroTextura"))

local Bandas = {}

local cfg: any = nil
local geral: any = nil
local ctxLocal: any = nil
local rotulo: ImageLabel? = nil
local ligado = false
local nivelAtual = 3
local ultimaChave = "" -- chave da última textura construída (inclui falhas, para não tentar de novo em loop)
local texturaOk = false
local proximaLeitura = 0

-- valores vigentes, relidos em aplicar() (fora do caminho do quadro)
local ativa = false -- visível agora (atualizar só anima se true)
local velocidade = 0
local altura = 0
local periodo = 0
local ultimoDesloc = -1
local ultimoLayout = ""

-- Lê prefs e ajustes, reconstrói a textura se a chave mudou, recalcula tamanho/tile e acerta a visibilidade.
local function aplicar()
	local r = rotulo
	if not r then
		return
	end
	local ajuste = ctxLocal.ajuste
	local escala = Regras.escalaForca(ctxLocal.jogador:GetAttribute(cfg.prefForca))
	if not (ligado and escala > 0 and nivelAtual >= ajuste("RetroBandasNivelMinimo", cfg.nivelMinimo)) then
		r.Visible = false
		ativa = false
		return
	end

	velocidade = ajuste("RetroBandasVelocidade", cfg.velocidade)
	local frequencia = ajuste("RetroBandasFrequencia", cfg.frequencia)
	local minimo = ajuste("RetroBandasMinimo", cfg.minimo)
	local maximo = ajuste("RetroBandasMaximo", cfg.maximo)
	local chave = `{escala}|{minimo}|{maximo}|{cfg.alturaTexel}`
	if chave ~= ultimaChave then
		ultimaChave = chave
		local bytes = Regras.texturaPerfilVertical(cfg.alturaTexel, function(frac: number): number
			return Regras.alfaBandas(frac, minimo, maximo)
		end, escala)
		texturaOk =
			RetroTextura.aplicar(r, RetroTextura.criar("retroBandas", 1, cfg.alturaTexel, bytes, ctxLocal.config))
	end

	altura = ctxLocal.guiMundo.AbsoluteSize.Y
	periodo = Regras.periodoBandasPx(altura, frequencia)
	local layout = `{altura}|{periodo}`
	if layout ~= ultimoLayout then
		ultimoLayout = layout
		r.Size = UDim2.new(1, 0, 0, altura + periodo)
		r.TileSize = UDim2.fromOffset(cfg.larguraTilePx, periodo)
		ultimoDesloc = -1
	end
	r.Visible = texturaOk
	ativa = texturaOk
end

function Bandas.iniciar(ctx: any)
	ctxLocal = ctx
	cfg = ctx.config.Retro.Bandas
	geral = ctx.config.Retro

	local r = Instance.new("ImageLabel")
	r.Name = "RetroBandas"
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Size = UDim2.fromScale(1, 1) -- ajustado em aplicar() para H + período
	r.Position = UDim2.fromOffset(0, 0)
	r.ScaleType = Enum.ScaleType.Tile
	r.ImageColor3 = Color3.new(1, 1, 1)
	r.ZIndex = cfg.zIndex
	r.Active = false
	r.Selectable = false
	r.Interactable = false
	r.Visible = false
	r.Parent = ctx.guiMundo
	rotulo = r

	ctx.jogador:GetAttributeChangedSignal(cfg.prefForca):Connect(aplicar)
	ctx.guiMundo:GetPropertyChangedSignal("AbsoluteSize"):Connect(aplicar)
end

function Bandas.atualizar(e: any)
	if not ligado then
		return
	end
	if e.t >= proximaLeitura then
		-- relê o ajuste de Studio a cada geral.reavaliarAjuste s; só mexe na instância se algo mudou
		proximaLeitura = e.t + geral.reavaliarAjuste
		aplicar()
	end
	local r = rotulo
	if not r or not ativa then
		return
	end
	-- a textura desce `desloc` px; o rótulo começa um período acima para sempre cobrir a tela
	local desloc = math.floor(Regras.deslocBandasPx(e.t, velocidade, altura, periodo))
	if desloc ~= ultimoDesloc then
		ultimoDesloc = desloc
		r.Position = UDim2.fromOffset(0, desloc - periodo)
	end
end

function Bandas.ligar(valor: boolean)
	ligado = valor
	proximaLeitura = 0
	aplicar()
end

function Bandas.nivel(n: number)
	nivelAtual = n
	aplicar()
end

return Bandas
