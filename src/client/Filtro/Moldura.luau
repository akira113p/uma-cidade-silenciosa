-- Filtro/Moldura: vinheta, poeira, craquelado, estalos de fita, riscos de filme, faixa de tracking, linhas de glitch e
-- moldura 9-slice (docs/filtro.md §5 S1). Partes com textura vazia ficam ocultas; linhas de glitch e estalos
-- (Frames) não precisam de textura. Tudo em pool: nada é criado por quadro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regras = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("Filtro"))

local Moldura = {}

local cfg: any = nil
local ctxLocal: any = nil
local ligado = false
local rng = Random.new()

local vinheta: ImageLabel? = nil
local moldura: ImageLabel? = nil
local poeira: ImageLabel? = nil
local tracking: ImageLabel? = nil
local craquelado: ImageLabel? = nil
local linhas: { Frame } = {}
local estalos: { Frame } = {}
local riscos: { ImageLabel } = {}
local riscosProximo: { number } = {}

local glitchFim = 0
local proximoSorteio = 0
local glitchAnterior = 0
local trackingInicio = 0
local trackingFim = 0
local trackingAtravessa = false
local trackingProximo = 0
local craqueladoProximo = 0
local craqueladoX = 0
local craqueladoY = 0
local estaloProximo = 0
local estaloFim = 0
local ultimoQuadroGrao = -1

local function criarImagem(nome: string, id: string, z: number): ImageLabel?
	if id == "" then
		return nil
	end
	local r = Instance.new("ImageLabel")
	r.Name = nome
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Image = id
	r.Size = UDim2.fromScale(1, 1)
	r.ZIndex = z
	r.Active = false
	r.Interactable = false
	r.Visible = false
	r.Parent = ctxLocal.guiTela
	return r
end

local function criarFrame(nome: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BorderSizePixel = 0
	f.Size = UDim2.new(0.2, 0, 0, 1)
	f.ZIndex = z
	f.Active = false
	f.Interactable = false
	f.Visible = false
	f.Parent = ctxLocal.guiTela
	return f
end

local function cor(c: { number }): Color3
	return Color3.new(c[1], c[2], c[3])
end

local function entre(faixa: { number }): number
	return faixa[1] + rng:NextNumber() * (faixa[2] - faixa[1])
end

local function esconderEstalos()
	for _, f in estalos do
		f.Visible = false
	end
	estaloFim = 0
end

local function esconderGlitch()
	if tracking then
		tracking.Visible = false
	end
	for _, l in linhas do
		l.Visible = false
	end
	trackingFim = 0
	glitchFim = 0
end

local function aplicarVisivel()
	if vinheta then
		vinheta.Visible = ligado
	end
	if moldura then
		moldura.Visible = ligado
	end
	if poeira then
		poeira.Visible = ligado
	end
	if craquelado then
		craquelado.Visible = ligado
	end
	if not ligado then
		esconderGlitch()
		esconderEstalos()
		for _, r in riscos do
			r.Visible = false
		end
	end
end

function Moldura.iniciar(ctx: any)
	ctxLocal = ctx
	cfg = ctx.config.Moldura
	local tex = ctx.config.Texturas
	local z = cfg.zIndex
	local agora = os.clock()
	trackingProximo = agora + entre(cfg.trackingEspontaneo)
	estaloProximo = agora + entre(cfg.estalos.intervalo)

	poeira = criarImagem("Poeira", tex.poeira or "", z.poeira)
	if poeira then
		poeira.Size = UDim2.fromScale(cfg.poeiraEscala, cfg.poeiraEscala)
		poeira.AnchorPoint = Vector2.new(0.5, 0.5)
		poeira.Position = UDim2.fromScale(0.5, 0.5)
		poeira.ScaleType = Enum.ScaleType.Stretch
		poeira.ImageTransparency = cfg.poeiraTransparencia
	end

	vinheta = criarImagem("Vinheta", tex.vinheta or "", z.vinheta)
	if vinheta then
		vinheta.ScaleType = Enum.ScaleType.Stretch
		vinheta.ImageColor3 = cor(cfg.corVinheta)
		vinheta.ImageTransparency = cfg.vinhetaDia
	end

	craquelado = criarImagem("Craquelado", tex.craquelado or "", z.craquelado)
	if craquelado then
		craquelado.Size = UDim2.new(1, cfg.craqueladoTile, 1, cfg.craqueladoTile)
		craquelado.ScaleType = Enum.ScaleType.Tile
		craquelado.TileSize = UDim2.fromOffset(cfg.craqueladoTile, cfg.craqueladoTile)
		craquelado.ResampleMode = Enum.ResamplerMode.Pixelated
		craquelado.ImageTransparency = cfg.craqueladoDia
	end

	tracking = criarImagem("Tracking", tex.tracking or "", z.tracking)
	if tracking then
		tracking.Size = UDim2.new(1, 0, 0, cfg.trackingAltura)
		tracking.ScaleType = Enum.ScaleType.Stretch
		tracking.ImageTransparency = cfg.trackingTransparencia
	end

	for i = 1, cfg.linhas.quantidade do
		linhas[i] = criarFrame("Glitch" .. i, z.glitch)
	end
	for i = 1, cfg.estalos.quantidade do
		estalos[i] = criarFrame("Estalo" .. i, z.estalo)
	end

	for i = 1, cfg.riscos.quantidade do
		local r = criarImagem("Risco" .. i, tex.riscos or "", z.riscos)
		if r then
			r.ScaleType = Enum.ScaleType.Stretch
			table.insert(riscos, r)
			table.insert(riscosProximo, 0)
		end
	end

	moldura = criarImagem("Moldura", tex.moldura or "", z.moldura)
	if moldura then
		local s = cfg.sliceCenter
		moldura.ScaleType = Enum.ScaleType.Slice
		moldura.SliceCenter = Rect.new(s[1], s[2], s[3], s[4])
		moldura.SliceScale = cfg.sliceEscala
		moldura.ImageTransparency = cfg.transparenciaMoldura
	end
	aplicarVisivel()
end

local function sortearLinhas()
	local c = cfg.linhas
	for _, l in linhas do
		local y: number
		if rng:NextNumber() < 0.5 then
			y = rng:NextNumber() * c.zonaTopo
		else
			y = 1 - rng:NextNumber() * c.zonaBase
		end
		local largura = c.larguraMin + rng:NextNumber() * (c.larguraMax - c.larguraMin)
		l.Size = UDim2.new(largura, 0, 0, rng:NextInteger(c.alturaMin, c.alturaMax))
		l.Position = UDim2.fromScale(rng:NextNumber() * (1 - largura), y)
		l.BackgroundColor3 = cor(c.cores[rng:NextInteger(1, #c.cores)])
		l.BackgroundTransparency = c.transparenciaMin + rng:NextNumber() * (c.transparenciaMax - c.transparenciaMin)
		l.Visible = true
	end
end

local function iniciarTracking(t: number, duracao: number)
	trackingInicio = t
	trackingFim = t + duracao
	trackingAtravessa = rng:NextNumber() < cfg.trackingChanceAtravessa
end

local function iniciarEstalos(t: number)
	local c = cfg.estalos
	estaloFim = t + entre(c.duracao)
	local n = math.min(rng:NextInteger(c.rajada[1], c.rajada[2]), #estalos)
	for i, f in estalos do
		if i > n then
			f.Visible = false
			continue
		end
		local largura = entre(c.largura)
		f.Size = UDim2.new(largura, 0, 0, rng:NextInteger(c.altura[1], c.altura[2]))
		f.Position = UDim2.fromScale(rng:NextNumber() * (1 - largura), rng:NextNumber())
		f.BackgroundColor3 = if rng:NextNumber() < c.chanceBranco then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		f.BackgroundTransparency = entre(c.transparencia)
		f.Visible = true
	end
end

local function iniciarGlitch(t: number)
	local duracao = entre(cfg.glitchDuracao)
	glitchFim = t + duracao
	iniciarTracking(t, duracao)
	proximoSorteio = 0
	if ctxLocal.camera_tremer then
		ctxLocal.camera_tremer(cfg.tranco, cfg.trancoDuracao)
	end
end

function Moldura.atualizar(e: any)
	if not ligado then
		return
	end
	local t = e.t
	local p = e.pulsos

	-- borda de subida do pulso de glitch inicia um glitch
	if p.glitch > glitchAnterior + 0.5 and t >= glitchFim then
		iniciarGlitch(t)
	end
	glitchAnterior = p.glitch

	-- quadro de grão: a poeira salta e o craquelado treme (como filme)
	local quadro = math.floor(t * ctxLocal.config.Grao.fps)
	local novoQuadro = quadro ~= ultimoQuadroGrao
	ultimoQuadroGrao = quadro

	if vinheta then
		local transp = Regras.mistura(cfg.vinhetaDia, cfg.vinhetaNoite, e.noite)
			- p.dano * cfg.vinhetaExtraDano
			- e.caca * cfg.vinhetaExtraCaca
		vinheta.ImageTransparency = math.clamp(transp, 0, 1)
		vinheta.ImageColor3 = cor(cfg.corVinheta):Lerp(cor(cfg.corVinhetaDano), math.clamp(p.dano, 0, 1))
	end

	if poeira then
		local pisca = math.sin(t * cfg.poeiraPiscaHz * math.pi * 2) * cfg.poeiraPisca
		poeira.ImageTransparency = math.clamp(cfg.poeiraTransparencia + pisca, 0, 1)
		if novoQuadro then
			poeira.Position = UDim2.fromScale(
				0.5 + (rng:NextNumber() * 2 - 1) * cfg.poeiraDeriva,
				0.5 + (rng:NextNumber() * 2 - 1) * cfg.poeiraDeriva
			)
		end
	end

	if craquelado then
		craquelado.ImageTransparency = Regras.mistura(cfg.craqueladoDia, cfg.craqueladoNoite, e.noite)
		if t >= craqueladoProximo then
			craqueladoProximo = t + entre(cfg.craqueladoSalto)
			craqueladoX = rng:NextInteger(0, cfg.craqueladoTile - 1)
			craqueladoY = rng:NextInteger(0, cfg.craqueladoTile - 1)
		end
		if novoQuadro then
			local tr = cfg.craqueladoTremor
			craquelado.Position =
				UDim2.fromOffset(-craqueladoX + rng:NextInteger(-tr, tr), -craqueladoY + rng:NextInteger(-tr, tr))
		end
	end

	-- faixa de tracking espontânea
	if t >= trackingProximo then
		trackingProximo = t + entre(cfg.trackingEspontaneo)
		if t >= trackingFim then
			iniciarTracking(t, entre(cfg.glitchDuracao))
		end
	end
	if tracking then
		if t < trackingFim then
			local y = cfg.trackingBase
			if trackingAtravessa then
				y = (t - trackingInicio) / math.max(trackingFim - trackingInicio, 0.001)
			end
			tracking.Visible = true
			tracking.Position = UDim2.fromScale(0, y)
			tracking.AnchorPoint = Vector2.new(0, if trackingAtravessa then 0 else 1)
		else
			tracking.Visible = false
		end
	end

	-- estalos de fita
	if estaloFim > 0 then
		if t >= estaloFim then
			esconderEstalos()
		end
	elseif t >= estaloProximo then
		estaloProximo = Regras.proximoEstalo(t, e.noite, e.caca, cfg.estalos, rng)
		iniciarEstalos(t)
	end

	-- riscos verticais de filme
	for i, r in riscos do
		if t >= riscosProximo[i] then
			riscosProximo[i] = t + entre(cfg.riscos.salto)
			if rng:NextNumber() < cfg.riscos.chance then
				r.Size = UDim2.new(0, rng:NextInteger(cfg.riscos.largura[1], cfg.riscos.largura[2]), 1, 0)
				r.Position = UDim2.fromScale(rng:NextNumber(), 0)
				r.ImageTransparency = entre(cfg.riscos.transparencia)
				r.Visible = true
			else
				r.Visible = false
			end
		end
	end

	-- linhas de glitch
	if t < glitchFim then
		if t >= proximoSorteio then
			proximoSorteio = t + 1 / cfg.linhas.hz
			sortearLinhas()
		end
	elseif glitchFim > 0 then
		glitchFim = 0
		for _, l in linhas do
			l.Visible = false
		end
	end
end

function Moldura.ligar(valor: boolean)
	ligado = valor
	aplicarVisivel()
end

function Moldura.nivel(_n: number)
	-- barata: mantida em todos os níveis
end

return Moldura
