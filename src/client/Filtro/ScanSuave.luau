-- Filtro/ScanSuave: scanlines suaves do DitherDown (ScanLines_Soft; docs/filtro-ditherdown.md §2, §5). Multiplicar a cena por k
-- vira sobrepor preto com alfa 1-k. Um ImageLabel em mosaico: a textura tem 1 px de largura (toda igual na horizontal, por isso o
-- tile pode ser largo) e `alturaTexel` de altura; o TileSize.Y é o período em px. A textura só é refeita quando força ou ajuste
-- mudam; o tamanho do tile só é recalculado quando a altura da tela muda (AbsoluteSize) ou na releitura de ajuste.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("FiltroRetro"))
local RetroTextura = require(script.Parent:WaitForChild("RetroTextura"))

local ScanSuave = {}

local cfg: any = nil
local geral: any = nil
local ctxLocal: any = nil
local rotulo: ImageLabel? = nil
local ligado = false
local nivelAtual = 3
local ultimaChave = "" -- chave da última textura construída (inclui falhas, para não tentar de novo em loop)
local texturaOk = false
local ultimoPeriodo = -1
local proximaLeitura = 0

-- Lê prefs e ajustes, reconstrói a textura se a chave mudou, recalcula o tile e acerta a visibilidade.
local function aplicar()
	local r = rotulo
	if not r then
		return
	end
	local ajuste = ctxLocal.ajuste
	local escala = Regras.escalaForca(ctxLocal.jogador:GetAttribute(cfg.prefForca))
	if not (ligado and escala > 0 and nivelAtual >= ajuste("RetroScanSuaveNivelMinimo", cfg.nivelMinimo)) then
		r.Visible = false
		return
	end

	local minimo = ajuste("RetroScanSuaveMinimo", cfg.minimo)
	local maximo = ajuste("RetroScanSuaveMaximo", cfg.maximo)
	local chave = `{escala}|{minimo}|{maximo}|{cfg.alturaTexel}`
	if chave ~= ultimaChave then
		ultimaChave = chave
		local bytes = Regras.texturaPerfilVertical(cfg.alturaTexel, function(frac: number): number
			return Regras.alfaScanSuave(frac, minimo, maximo)
		end, escala)
		texturaOk =
			RetroTextura.aplicar(r, RetroTextura.criar("retroScanSuave", 1, cfg.alturaTexel, bytes, ctxLocal.config))
	end

	local altura = ctxLocal.guiMundo.AbsoluteSize.Y
	local periodo =
		Regras.periodoScanSuavePx(altura, ajuste("RetroScanSuaveContagem", cfg.contagem), cfg.minimoPxPeriodo)
	if periodo ~= ultimoPeriodo then
		ultimoPeriodo = periodo
		r.TileSize = UDim2.fromOffset(cfg.larguraTilePx, periodo)
	end
	r.Visible = texturaOk
end

function ScanSuave.iniciar(ctx: any)
	ctxLocal = ctx
	cfg = ctx.config.Retro.ScanSuave
	geral = ctx.config.Retro

	local r = Instance.new("ImageLabel")
	r.Name = "RetroScanSuave"
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Size = UDim2.fromScale(1, 1)
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

function ScanSuave.atualizar(e: any)
	if not ligado or e.t < proximaLeitura then
		return
	end
	-- relê o ajuste de Studio a cada geral.reavaliarAjuste s; só mexe na instância se algo mudou
	proximaLeitura = e.t + geral.reavaliarAjuste
	aplicar()
end

function ScanSuave.ligar(valor: boolean)
	ligado = valor
	proximaLeitura = 0
	aplicar()
end

function ScanSuave.nivel(n: number)
	nivelAtual = n
	aplicar()
end

return ScanSuave
