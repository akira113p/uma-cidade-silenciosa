-- Filtro/Dither: overlay do dither de Bayer do DitherDown (docs/filtro-ditherdown.md §2, §5). Imitação: só o padrão, sem a
-- quantização do shader (o Roblox não deixa ler o frame). Um ImageLabel em mosaico com uma textura n×n gerada em execução.
-- A textura só é refeita quando a força, a matriz ou um ajuste mudam (nunca por quadro); o tile não depende da altura da tela.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("FiltroRetro"))
local RetroTextura = require(script.Parent:WaitForChild("RetroTextura"))

local Dither = {}

local cfg: any = nil
local geral: any = nil
local ctxLocal: any = nil
local rotulo: ImageLabel? = nil
local ligado = false
local nivelAtual = 3
local ultimaChave = "" -- chave da última construção (inclui falhas, para não tentar de novo em loop)
local texturaOk = false
local proximaLeitura = 0

local function visivelDesejado(escala: number): boolean
	return ligado and escala > 0 and nivelAtual >= ctxLocal.ajuste("RetroDitherNivelMinimo", cfg.nivelMinimo)
end

-- Lê prefs e ajustes, reconstrói a textura se a chave mudou e acerta a visibilidade.
local function aplicar()
	local r = rotulo
	if not r then
		return
	end
	local jogador = ctxLocal.jogador
	local escala = Regras.escalaForca(jogador:GetAttribute(cfg.prefForca))
	if not visivelDesejado(escala) then
		r.Visible = false
		return
	end

	local n = Regras.potenciaValida(jogador:GetAttribute(cfg.prefMatriz))
	local amplitude = ctxLocal.ajuste("RetroDitherAmplitude", cfg.amplitudeBase) * escala
	local ppt = ctxLocal.ajuste("RetroDitherPixelPorTexel", cfg.pixelPorTexel)
	local chave = `{n}|{amplitude}|{ppt}`
	if chave ~= ultimaChave then
		ultimaChave = chave
		local bytes = Regras.texturaDither(n, amplitude)
		local resultado = RetroTextura.criar("retroDither", n, n, bytes, ctxLocal.config)
		texturaOk = RetroTextura.aplicar(r, resultado)
		r.TileSize = UDim2.fromOffset(n * ppt, n * ppt)
	end
	r.Visible = texturaOk
end

function Dither.iniciar(ctx: any)
	ctxLocal = ctx
	cfg = ctx.config.Retro.Dither
	geral = ctx.config.Retro

	local r = Instance.new("ImageLabel")
	r.Name = "RetroDither"
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Size = UDim2.fromScale(1, 1)
	r.Position = UDim2.fromOffset(0, 0)
	r.ScaleType = Enum.ScaleType.Tile
	r.ResampleMode = Enum.ResamplerMode.Pixelated -- texels nítidos, sem suavizar o padrão
	r.ImageColor3 = Color3.new(1, 1, 1)
	r.ZIndex = cfg.zIndex
	r.Active = false
	r.Selectable = false
	r.Interactable = false
	r.Visible = false
	r.Parent = ctx.guiMundo
	rotulo = r

	local jogador: Player = ctx.jogador
	jogador:GetAttributeChangedSignal(cfg.prefForca):Connect(aplicar)
	jogador:GetAttributeChangedSignal(cfg.prefMatriz):Connect(aplicar)
end

function Dither.atualizar(e: any)
	if not ligado or e.t < proximaLeitura then
		return
	end
	-- relê o ajuste de Studio a cada geral.reavaliarAjuste s; só mexe na instância se a chave mudou
	proximaLeitura = e.t + geral.reavaliarAjuste
	aplicar()
end

function Dither.ligar(valor: boolean)
	ligado = valor
	proximaLeitura = 0
	aplicar()
end

function Dither.nivel(n: number)
	nivelAtual = n
	aplicar()
end

return Dither
