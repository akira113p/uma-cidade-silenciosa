-- Filtro/Grao: granulação animada (docs/filtro.md §5 S1). ImageLabel maior que a tela com a textura em mosaico; a cada
-- quadro de grão troca a imagem entre os ids de Texturas.grao e desloca o mosaico. Sem textura: fica oculto.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regras = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("Filtro"))

local Grao = {}

local cfg: any = nil
local rotulo: ImageLabel? = nil
local ids: { string } = {}
local ligado = false
local ultimoQuadro = -1

local function aplicarVisivel()
	if rotulo then
		rotulo.Visible = ligado and #ids > 0
	end
end

function Grao.iniciar(ctx: any)
	cfg = ctx.config.Grao
	ids = {}
	for _, id in ctx.config.Texturas.grao do
		if type(id) == "string" and id ~= "" then
			table.insert(ids, id)
		end
	end

	local r = Instance.new("ImageLabel")
	r.Name = "Grao"
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.Size = UDim2.new(1, cfg.tamanhoTile, 1, cfg.tamanhoTile)
	r.Position = UDim2.fromOffset(0, 0)
	r.ScaleType = Enum.ScaleType.Tile
	r.TileSize = UDim2.fromOffset(cfg.tamanhoTile, cfg.tamanhoTile)
	r.ResampleMode = Enum.ResamplerMode.Pixelated
	r.ImageTransparency = cfg.transparenciaDia
	r.ZIndex = cfg.zIndex
	r.Active = false
	r.Interactable = false
	r.Visible = false
	r.Parent = ctx.guiTela
	rotulo = r

	if #ids > 0 then
		r.Image = ids[1]
		-- pré-carrega com rótulos descartáveis (uma vez, fora do quadro)
		task.spawn(function()
			local temporarios = {}
			for _, id in ids do
				local t = Instance.new("ImageLabel")
				t.Image = id
				table.insert(temporarios, t)
			end
			pcall(ContentProvider.PreloadAsync, ContentProvider, temporarios)
			for _, t in temporarios do
				t:Destroy()
			end
		end)
	end
	aplicarVisivel()
end

function Grao.atualizar(e: any)
	local r = rotulo
	if not r or not ligado or #ids == 0 then
		return
	end
	local quadro = math.floor(e.t * cfg.fps)
	if quadro ~= ultimoQuadro then
		ultimoQuadro = quadro
		r.Image = ids[Regras.quadroGrao(e.t, cfg.fps, #ids)]
		local dx, dy = Regras.deslocGrao(e.t, cfg.fps, cfg.tamanhoTile)
		r.Position = UDim2.fromOffset(-dx, -dy)
	end
	local t = Regras.mistura(cfg.transparenciaDia, cfg.transparenciaNoite, e.noite) - e.pulsos.dano * cfg.extraDano
	r.ImageTransparency = math.clamp(t, 0, 1)
end

function Grao.ligar(valor: boolean)
	ligado = valor
	aplicarVisivel()
end

function Grao.nivel(_n: number)
	-- o grão é barato: mantido em todos os níveis
end

return Grao
