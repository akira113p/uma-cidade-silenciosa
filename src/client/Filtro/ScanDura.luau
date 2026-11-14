-- Filtro/ScanDura: scanlines duras do DitherDown (ScanLines_Hard; docs/filtro-ditherdown.md §2, §5). Multiplicar a cena por k
-- vira sobrepor preto com alfa 1-k. Um ImageLabel em mosaico: a textura tem 1 px de largura (toda igual na horizontal, por isso o
-- tile pode ser largo) e `alturaTexel` de altura; o TileSize.Y é o ciclo em px. A textura só é refeita quando força ou ajuste
-- mudam; o tamanho do tile só é recalculado quando a altura da tela muda (AbsoluteSize) ou na releitura de ajuste.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("FiltroRetro"))
local RetroTextura = require(script.Parent:WaitForChild("RetroTextura"))

local ScanDura = {}

local cfg: any = nil
local geral: any = nil
local ctxLocal: any = nil
local rotulo: ImageLabel? = nil
local ligado = false
local nivelAtual = 3
local ultimaChave = "" -- chave da última textura construída (inclui falhas, para não tentar de novo em loop)
local texturaOk = false
local ultimoCiclo = -1
local proximaLeitura = 0

-- Lê prefs e ajustes, reconstrói a textura se a chave mudou, recalcula o tile e acerta a visibilidade.
local function aplicar()
	local r = rotulo
	if not r then
		return
	end
	local ajuste = ctxLocal.ajuste
	local escala = Regras.escalaForca(ctxLocal.jogador:GetAttribute(cfg.prefForca))
	if not (ligado and escala > 0 and nivelAtual >= ajuste("RetroScanDuraNivelMinimo", cfg.nivelMinimo)) then
		r.Visible = false
		return
	end

	local minimo = ajuste("RetroScanDuraMinimo", cfg.minimo)
	local maximo = ajuste("RetroScanDuraMaximo", cfg.maximo)
	local chave = `{escala}|{minimo}|{maximo}|{cfg.alturaTexel}`
	if chave ~= ultimaChave then
		ultimaChave = chave
		local bytes = Regras.texturaPerfilVertical(cfg.alturaTexel, function(frac: number): number
			return Regras.alfaScanDura(frac, minimo, maximo)
		end, escala)
		texturaOk =
			RetroTextura.aplicar(r, RetroTextura.criar("retroScanDura", 1, cfg.alturaTexel, bytes, ctxLocal.config))
	end

	local altura = ctxLocal.guiMundo.AbsoluteSize.Y
	local ciclo = Regras.cicloScanDuraPx(altura, ajuste("RetroScanDuraContagem", cfg.contagem), cfg.minimoPxCiclo)
	if ciclo ~= ultimoCiclo then
		ultimoCiclo = ciclo
		r.TileSize = UDim2.fromOffset(cfg.larguraTilePx, ciclo)
	end
	r.Visible = texturaOk
end

function ScanDura.iniciar(ctx: any)
	ctxLocal = ctx
	cfg = ctx.config.Retro.ScanDura
	geral = ctx.config.Retro

	local r = Instance.new("ImageLabel")
	r.Name = "RetroScanDura"
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Size = UDim2.fromScale(1, 1)
	r.Position = UDim2.fromOffset(0, 0)
	r.ScaleType = Enum.ScaleType.Tile
	r.ResampleMode = Enum.ResamplerMode.Pixelated -- corte duro entre a faixa escura e a clara
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

function ScanDura.atualizar(e: any)
	if not ligado or e.t < proximaLeitura then
		return
	end
	-- relê o ajuste de Studio a cada geral.reavaliarAjuste s; só mexe na instância se algo mudou
	proximaLeitura = e.t + geral.reavaliarAjuste
	aplicar()
end

function ScanDura.ligar(valor: boolean)
	ligado = valor
	proximaLeitura = 0
	aplicar()
end

function ScanDura.nivel(n: number)
	nivelAtual = n
	aplicar()
end

return ScanDura
