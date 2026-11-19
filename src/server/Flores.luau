-- Flores: flores-sentinela da Florescida (docs/monstros/logica.md §7.2). A flor escuta por ela: som de jogador a <= raioEscuta da flor
-- chama a dona com a posição exata do som, qualquer que seja a distância dela. Indexadas por grade (nada de laço por todas as flores).
-- Estado só aqui. `configurar({ ouvir = function(donoId, pos), servico = fn })` vem do Monstros.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presets = require(Shared.Config.PresetsMonstro) :: any
local Regras = require(Shared.Regras.Habilidades)

local Flores = {}

local ctx: any = {}
local cfg = Presets.florescida.habilidades.florescer
local grade: { [string]: { [Model]: boolean } } = {}
local celulaDe: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local porDona: { [number]: { Model } } = {}
local pasta: Folder? = nil

function Flores.configurar(c: any)
	ctx = c
end

local function pastaFlores(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local p = workspace:FindFirstChild("Flores")
	if p and p:IsA("Folder") then
		pasta = p
		return p
	end
	local nova = Instance.new("Folder")
	nova.Name = "Flores"
	nova.Parent = workspace
	pasta = nova
	return nova
end

local function parte(nome: string, tam: Vector3, cor: Color3, pai: Model): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tam
	p.Color = cor
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Parent = pai
	return p
end

local function remover(flor: Model)
	local c = celulaDe[flor]
	if c and grade[c] then
		grade[c][flor] = nil
	end
	celulaDe[flor] = nil
	local id = flor:GetAttribute("Dona")
	local lista = type(id) == "number" and porDona[id]
	if lista then
		local i = table.find(lista, flor)
		if i then
			table.remove(lista, i)
		end
	end
	if flor.Parent then
		flor:Destroy()
	end
end

-- Planta uma flor em `pos` (o chão) para a Florescida `d` (d.id). A 13ª faz a mais antiga murchar.
function Flores.plantar(d: any, pos: Vector3): Model?
	local lista = porDona[d.id]
	if not lista then
		lista = {}
		porDona[d.id] = lista
	end
	if Regras.florAMurchar(#lista, cfg.max) then
		remover(lista[1])
	end
	local m = Instance.new("Model")
	m.Name = "Flor"
	local caule = parte("Caule", Vector3.new(0.2, 1.2, 0.2), Color3.fromRGB(95, 120, 85), m)
	caule.CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0))
	local petalas = parte("Petalas", Vector3.new(0.9, 0.3, 0.9), Color3.fromRGB(215, 220, 205), m)
	petalas.CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0))
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(150, 200, 140)
	luz.Brightness = 0.6
	luz.Range = 6
	luz.Parent = petalas
	m.PrimaryPart = caule
	m:SetAttribute("Flor", true)
	m:SetAttribute("Dona", d.id)
	m.Parent = pastaFlores()
	local c = Regras.celula(pos.X, pos.Z, cfg.raioEscuta)
	grade[c] = grade[c] or {}
	grade[c][m] = true
	celulaDe[m] = c
	table.insert(lista, m)
	return m
end

-- Um som de jogador (não imitação) no mundo: chama a dona de toda flor a <= raioEscuta da origem. Devolve quantas donas chamou.
function Flores.aoRuido(evento: any): number
	local fonte = evento.fonte
	if typeof(fonte) ~= "Instance" or not (fonte :: Instance):IsA("Player") or evento.tipo == "imitacao" then
		return 0
	end
	local origem: Vector3 = evento.posicao
	local donas: { [number]: boolean } = {}
	local n = 0
	for _, c in Regras.celulasVizinhas(origem.X, origem.Z, cfg.raioEscuta) do
		local g = grade[c]
		if g then
			for flor in g do
				local p = flor.PrimaryPart
				local id = flor:GetAttribute("Dona")
				if
					p
					and type(id) == "number"
					and not donas[id]
					and (p.Position - origem).Magnitude <= cfg.raioEscuta
				then
					donas[id] = true
					n += 1
				end
			end
		end
	end
	for id in donas do
		if ctx.ouvir then
			ctx.ouvir(id, origem)
		end
	end
	return n
end

-- Contrato com o agente B (Armas): tiro ou golpe corpo a corpo numa flor. `arma = { tipo, agachado }`.
-- Faca com o jogador agachado: some em silêncio. O resto: estalo (som + 70 dB com fonte = jogador) e a dona vai até a flor.
function Flores.atingir(flor: Instance, jogador: Player, arma: { tipo: string, agachado: boolean })
	if not (flor:IsA("Model") and flor:GetAttribute("Flor") == true and flor.Parent) then
		return
	end
	local p = flor.PrimaryPart
	local pos = if p then p.Position else flor:GetPivot().Position
	local dono = flor:GetAttribute("Dona")
	local silencioso = arma.tipo == "faca" and arma.agachado == true
	remover(flor)
	if silencioso then
		return
	end
	local sons = ctx.servico and ctx.servico("Sons")
	if sons then
		sons.tocar("FlorEstalo", pos)
	end
	if type(dono) == "number" and ctx.ouvir then
		ctx.ouvir(dono, pos) -- a dona ouve pela própria flor
	end
	local ruido = ctx.servico and ctx.servico("Ruido")
	if ruido then
		ruido.emitir(pos, cfg.db, "florEstalo", jogador) -- fonte = jogador: monstro de nível igual ao dele não ignora
	end
end

-- A dona morreu: as flores dela murcham em `segundos`.
function Flores.murchar(donoId: number, segundos: number)
	local lista = porDona[donoId]
	porDona[donoId] = nil
	if not lista then
		return
	end
	for _, flor in table.clone(lista) do
		task.delay(segundos, remover, flor)
	end
end

function Flores.contar(donoId: number): number
	local l = porDona[donoId]
	return if l then #l else 0
end

return Flores
