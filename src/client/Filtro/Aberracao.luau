-- Aberração cromática por divisão de FOV (docs/filtro.md §5 S2). Dono: S2.
-- 2 ViewportFrames (vermelho, ciano) com câmeras no CFrame da câmera real e FOV menor/maior → franja radial.
-- Conteúdo: clones estáticos de workspace.Mapa perto da câmera (cache por célula) + monstros e personagens de outros
-- jogadores SÓ quando a câmera os vê (regra de justiça do PvP: nunca mostrar o que a câmera não vê).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regras = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("FiltroAberracao"))

local Aberracao = {}

-- Filhos que um clone pode manter (só o que desenha); o resto é destruído.
local FILHOS_VISUAIS = {
	SpecialMesh = true,
	SurfaceAppearance = true,
	Decal = true,
	Texture = true,
}
local NIVEL_MINIMO_DINAMICO = 2
local NIVEL_ESTATICO = 3

type Entrada = { -- célula estática
	pastaV: Folder,
	pastaC: Folder,
	partes: { BasePart }?, -- nil = ainda não consultou
	i: number,
	pronta: boolean,
	pares: { Par },
	cx: number, -- centro da célula (X, Z)
	cz: number,
	dRef: number, -- distância câmera-centro usada na última névoa aplicada
	fogRef: number, -- FogStart + FogEnd da última névoa aplicada
}
type Par = {
	orig: BasePart,
	v: BasePart,
	c: BasePart,
	cor: Color3, -- cor original
	decais: { { inst: Instance, t0: number } },
	textura: string, -- TextureID original (MeshPart)
	semTextura: boolean,
	trans0: number, -- Transparency original
	tamanho: Vector3,
	grande: boolean, -- maior dimensão > cfg.parteGrande: distância até a caixa
}
type Dinamico = { pastaV: Folder, pastaC: Folder, pares: { Par } }

local ctx: any = nil
local cfg: any = nil -- cópia viva da config (com ajustes do Studio)
local ligado = true
local nivelAtual = 3
local ativo = false -- viewports visíveis

local vfV: ViewportFrame, vfC: ViewportFrame
local camV: Camera, camC: Camera
local raizEstV: Folder, raizEstC: Folder
local raizDinV: Folder, raizDinC: Folder

local celulas: { [string]: Entrada } = {}
local fila: { string } = {}
local filaI = 1
local dinamicos: { [Instance]: Dinamico } = {}
local nDinamicos = 0

local tCelulas = 0
local tVisib = 0
local tNevoa = 0
local totalPartes = 0 -- partes estáticas clonadas (por viewport)
local tLuz = 0
local transAtual = -1 -- soma das duas transparências aplicadas (evita escrever propriedade sem mudança)
local paramsConsulta = OverlapParams.new()
paramsConsulta.FilterType = Enum.RaycastFilterType.Include
paramsConsulta.MaxParts = 3000
local paramsRaio = RaycastParams.new()
paramsRaio.FilterType = Enum.RaycastFilterType.Exclude
paramsRaio.IgnoreWater = true

local function cor(t: { number }): Color3
	return Color3.new(t[1], t[2], t[3])
end

local function criarViewport(nome: string, corImagem: Color3, zIndex: number): (ViewportFrame, Camera)
	local vf = Instance.new("ViewportFrame")
	vf.Name = nome
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.ImageColor3 = corImagem
	vf.ImageTransparency = 1
	vf.Active = false
	vf.ZIndex = zIndex
	vf.Visible = false
	local cam = Instance.new("Camera")
	cam.Name = "Camera"
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = ctx.guiMundo
	return vf, cam
end

-- Deixa o clone só com o que desenha: sem colisão, ancorado, sem filhos não visuais.
local function limparClone(p: BasePart)
	for _, d in p:GetDescendants() do
		if not FILHOS_VISUAIS[d.ClassName] then
			d:Destroy()
		end
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

-- O ViewportFrame não tem névoa: a cor do clone vai para FogColor conforme a distância (a peça fica opaca).
-- Texturas: Decal/Texture ganham transparência pelo mesmo fator; MeshPart perde o TextureID acima de fatorSemTextura.
local function aplicarNevoa(par: Par, origem: Vector3)
	-- Franja por distância: só longe a peça some (transparência); perto fica opaca. Partes grandes usam a caixa, não o centro.
	local pos = par.orig.Position
	local dFranja = (pos - origem).Magnitude
	local tam = par.tamanho
	if par.grande then
		dFranja = Regras.distanciaCaixa(origem.X, origem.Y, origem.Z, pos.X, pos.Y, pos.Z, tam.X, tam.Y, tam.Z)
	end
	local sumir = 1 - Regras.fatorFranja(dFranja, cfg.franjaPerto, cfg.franjaLonge)
	local tp = math.max(par.trans0, sumir)
	par.v.Transparency = tp
	par.c.Transparency = tp
	local f = Regras.fatorNevoa((par.orig.Position - origem).Magnitude, Lighting.FogStart, Lighting.FogEnd)
	local fc = Lighting.FogColor
	local r, g, b = Regras.corNevoa(par.cor.R, par.cor.G, par.cor.B, fc.R, fc.G, fc.B, f)
	local nova = Color3.new(r, g, b)
	par.v.Color = nova
	par.c.Color = nova
	for _, d in par.decais do
		d.inst.Transparency = d.t0 + (1 - d.t0) * math.max(f, sumir)
	end
	if par.textura ~= "" then
		local sem = f > cfg.fatorSemTextura
		if sem ~= par.semTextura then
			par.semTextura = sem
			local id = if sem then "" else par.textura
			local mv: any, mc: any = par.v, par.c
			mv.TextureID = id
			mc.TextureID = id
		end
	end
end

local function clonarParte(orig: BasePart, paiV: Instance, paiC: Instance, origem: Vector3): Par?
	local v = orig:Clone()
	if not v then -- Archivable false
		return nil
	end
	limparClone(v)
	local c = v:Clone()
	v.Parent = paiV
	c.Parent = paiC
	local decais = {}
	for _, raiz in { v, c } do
		for _, d in raiz:GetChildren() do
			if d:IsA("Decal") or d:IsA("Texture") then
				table.insert(decais, { inst = d, t0 = d.Transparency })
			end
		end
	end
	local par: Par = {
		orig = orig,
		v = v,
		c = c,
		cor = orig.Color,
		decais = decais,
		textura = if orig:IsA("MeshPart") then orig.TextureID else "",
		semTextura = false,
		trans0 = orig.Transparency,
		tamanho = orig.Size,
		grande = math.max(orig.Size.X, orig.Size.Y, orig.Size.Z) > cfg.parteGrande,
	}
	aplicarNevoa(par, origem)
	return par
end

local noite = 0

local function aplicarLuz()
	local luz = cor(cfg.luzDia):Lerp(cor(cfg.luzNoite), noite)
	local dir = -Lighting:GetSunDirection()
	for _, vf in { vfV, vfC } do
		vf.Ambient = Lighting.Ambient
		vf.LightColor = luz
		vf.LightDirection = dir
	end
end

local function ler(chave: string, padrao: number): number
	local v = ctx.ajuste(chave, padrao)
	return if type(v) == "number" then v else padrao
end

local function atualizarCfg()
	for k, v in ctx.config.Aberracao do
		cfg[k] = v
	end
	cfg.base = ler("AberracaoBase", cfg.base)
	cfg.fovDelta = ler("AberracaoFov", cfg.fovDelta)
	cfg.raioEstatico = ler("AberracaoRaio", cfg.raioEstatico)
end

-- Estático ------------------------------------------------------------------------------------------------

local function destruirCelula(chave: string)
	local e = celulas[chave]
	if e then
		totalPartes -= #e.pares
		e.pastaV:Destroy()
		e.pastaC:Destroy()
		celulas[chave] = nil
	end
end

local function destruirEstaticos()
	for chave in celulas do
		destruirCelula(chave)
	end
	fila = {}
	filaI = 1
end

-- Chão, ruas e rios (Mapa.Chao etc.) e o Terrain ficam fora: sem névoa própria viram cunha limpa sobre o chão enevoado.
local function emPastaExcluida(p: BasePart, mapa: Instance): boolean
	if p:IsA("Terrain") then
		return true
	end
	for _, nome in cfg.pastasExcluidas do
		local pasta = mapa:FindFirstChild(nome)
		if pasta and p:IsDescendantOf(pasta) then
			return true
		end
	end
	return false
end

local function consultarCelula(chave: string, e: Entrada)
	local ix, iz = string.match(chave, "^(-?%d+),(-?%d+)$")
	local mapa = workspace:FindFirstChild("Mapa")
	if not ix or not iz or not mapa then
		return -- sem Mapa ainda: partes continua nil e a próxima reavaliação tenta de novo
	end
	local tam = cfg.tamanhoCelula
	local x0, z0 = tonumber(ix) * tam, tonumber(iz) * tam
	paramsConsulta.FilterDescendantsInstances = { mapa }
	paramsConsulta.MaxParts = cfg.consultaMaxPartes
	local caixa = CFrame.new(x0 + tam / 2, cfg.centroYConsulta, z0 + tam / 2)
	local achadas = workspace:GetPartBoundsInBox(caixa, Vector3.new(tam, cfg.alturaConsulta, tam), paramsConsulta)
	local boas: { BasePart } = {}
	for _, p in achadas do
		local pos = p.Position
		if
			pos.X >= x0
			and pos.X < x0 + tam
			and pos.Z >= z0
			and pos.Z < z0 + tam
			and p.Transparency < cfg.transparenciaMaxima
			and p.Size.Magnitude >= cfg.tamanhoMinimoParte
			and math.max(p.Size.X, p.Size.Y, p.Size.Z) <= cfg.ladoMaximo
			and not emPastaExcluida(p, mapa)
		then
			table.insert(boas, p)
		end
	end
	if #boas > cfg.maxPartesPorCelula then
		table.sort(boas, function(a, b)
			return a.Size.Magnitude > b.Size.Magnitude
		end)
		for i = #boas, cfg.maxPartesPorCelula + 1, -1 do
			boas[i] = nil
		end
	end
	e.partes = boas
end

-- Reavalia quais células faltam (dentro do raio) e descarta as que passaram do raio + margem.
local function reavaliarCelulas(pos: Vector3)
	local manter: { [string]: boolean } = {}
	for _, k in Regras.celulas(pos, cfg.tamanhoCelula, cfg.raioEstatico + cfg.margemDescarte) do
		manter[k] = true
	end
	for chave in celulas do
		if not manter[chave] then
			destruirCelula(chave)
		end
	end
	fila = {}
	filaI = 1
	for _, k in Regras.celulas(pos, cfg.tamanhoCelula, cfg.raioEstatico) do
		local e = celulas[k]
		if not e and totalPartes <= cfg.maxPartesTotal then -- guarda: acima do teto não abre células novas
			local pv, pc = Instance.new("Folder"), Instance.new("Folder")
			pv.Name, pc.Name = k, k
			pv.Parent, pc.Parent = raizEstV, raizEstC
			local ix, iz = string.match(k, "^(-?%d+),(-?%d+)$")
			local tam = cfg.tamanhoCelula
			e = {
				pastaV = pv,
				pastaC = pc,
				partes = nil,
				i = 1,
				pronta = false,
				pares = {},
				cx = (tonumber(ix) + 0.5) * tam,
				cz = (tonumber(iz) + 0.5) * tam,
				dRef = -1000,
				fogRef = -1,
			}
			celulas[k] = e
		end
		if e and not e.pronta then
			table.insert(fila, k)
		end
	end
end

-- Gasta o orçamento do quadro consultando células e clonando partes.
local function processarFila(origemNevoa: Vector3)
	local orcamento = cfg.clonesPorQuadro
	while orcamento > 0 and filaI <= #fila do
		local chave = fila[filaI]
		local e = celulas[chave]
		if not e or e.pronta then
			filaI += 1
		else
			if not e.partes then
				consultarCelula(chave, e)
				orcamento -= 1
				if not e.partes then
					filaI += 1 -- sem Mapa ainda; a próxima reavaliação tenta de novo
				end
			else
				local partes = e.partes
				while orcamento > 0 and e.i <= #partes do
					local p = partes[e.i]
					e.i += 1
					if p.Parent then
						local par = clonarParte(p, e.pastaV, e.pastaC, origemNevoa)
						if par then
							table.insert(e.pares, par)
							totalPartes += 1
						end
						orcamento -= 1
					end
				end
				if e.i > #partes then
					e.pronta = true
					e.partes = {}
					filaI += 1
				end
			end
		end
	end
end

-- Dinâmico ------------------------------------------------------------------------------------------------

local function removerDinamico(alvo: Instance)
	local d = dinamicos[alvo]
	if d then
		d.pastaV:Destroy()
		d.pastaC:Destroy()
		dinamicos[alvo] = nil
		nDinamicos -= 1
	end
end

local function destruirDinamicos()
	for alvo in dinamicos do
		removerDinamico(alvo)
	end
end

local function criarDinamico(alvo: Model, origem: Vector3)
	local pv, pc = Instance.new("Folder"), Instance.new("Folder")
	pv.Name, pc.Name = alvo.Name, alvo.Name
	local pares: { Par } = {}
	for _, d in alvo:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			local par = clonarParte(d, pv, pc, origem)
			if par then
				table.insert(pares, par)
			end
		end
	end
	pv.Parent, pc.Parent = raizDinV, raizDinC
	dinamicos[alvo] = { pastaV = pv, pastaC = pc, pares = pares }
	nDinamicos += 1
end

-- Pontos que a câmera precisa ver: cabeça e tronco (ou o pivô).
local function pontosDe(alvo: Model): { Vector3 }
	local pontos = {}
	local cabeca = alvo:FindFirstChild("Head")
	local raiz = alvo:FindFirstChild("HumanoidRootPart") or alvo.PrimaryPart
	if cabeca and cabeca:IsA("BasePart") then
		table.insert(pontos, cabeca.Position)
	end
	if raiz and raiz:IsA("BasePart") then
		table.insert(pontos, raiz.Position)
	end
	if #pontos == 0 then
		table.insert(pontos, alvo:GetPivot().Position)
	end
	return pontos
end

local function visivel(alvo: Model, origem: Vector3): boolean
	local personagem = ctx.jogador.Character
	paramsRaio.FilterDescendantsInstances = if personagem
		then { personagem, alvo, ctx.pastaMundo }
		else { alvo, ctx.pastaMundo }
	local pontos = pontosDe(alvo)
	local livres = 0
	for _, ponto in pontos do
		if workspace:Raycast(origem, ponto - origem, paramsRaio) == nil then
			livres += 1
		end
	end
	return livres >= math.min(cfg.pontosVisiveisMinimos, #pontos)
end

local function varrerVisibilidade()
	local origem = ctx.camera.CFrame.Position
	local alcance =
		Regras.alcanceDinamico(cfg.raioDinamico, Lighting.FogStart, Lighting.FogEnd, cfg.fracaoNevoaDinamico)
	local candidatos: { Model } = {}
	local pasta = workspace:FindFirstChild("Monstros")
	if pasta then
		for _, m in pasta:GetChildren() do
			if m:IsA("Model") then
				table.insert(candidatos, m)
			end
		end
	end
	for _, jogador in Players:GetPlayers() do
		if jogador ~= ctx.jogador and jogador.Character then
			table.insert(candidatos, jogador.Character)
		end
	end
	local vistos: { [Instance]: boolean } = {}
	for _, alvo in candidatos do
		if alvo.Parent and (alvo:GetPivot().Position - origem).Magnitude <= alcance and visivel(alvo, origem) then
			vistos[alvo] = true
			if not dinamicos[alvo] then
				criarDinamico(alvo, origem)
			end
		end
	end
	for alvo, d in dinamicos do
		if not vistos[alvo] then
			removerDinamico(alvo)
		else
			for _, par in d.pares do
				aplicarNevoa(par, origem)
			end
		end
	end
end

-- 2 Hz: refaz a névoa dos clones estáticos de cada célula cuja distância mudou mais de 2 studs (ou a névoa mudou).
local function atualizarNevoaEstatica(origem: Vector3)
	local fog = Lighting.FogStart + Lighting.FogEnd
	for _, e in celulas do
		local d = math.sqrt((e.cx - origem.X) ^ 2 + (e.cz - origem.Z) ^ 2)
		if math.abs(d - e.dRef) > cfg.passoNevoaCelula or fog ~= e.fogRef then
			e.dRef, e.fogRef = d, fog
			for _, par in e.pares do
				aplicarNevoa(par, origem)
			end
		end
	end
end

-- Contrato ------------------------------------------------------------------------------------------------

local function ocultar()
	if ativo then
		ativo = false
		vfV.Visible = false
		vfC.Visible = false
		destruirDinamicos() -- ao voltar, a primeira varredura decide de novo (nunca mostra posição velha)
	end
end

function Aberracao.iniciar(c: any)
	ctx = c
	cfg = table.clone(c.config.Aberracao)
	vfV, camV = criarViewport("AberracaoVermelho", cor(cfg.corVermelho), 1) -- ZIndex 1: embaixo (Regras.transparencias assume isso)
	vfC, camC = criarViewport("AberracaoCiano", cor(cfg.corCiano), 2) -- ZIndex 2: o ciano fica POR CIMA do vermelho
	local function raiz(vf: ViewportFrame, nome: string): Folder
		local f = Instance.new("Folder")
		f.Name = nome
		f.Parent = vf
		return f
	end
	raizEstV, raizEstC = raiz(vfV, "Estatico"), raiz(vfC, "Estatico")
	raizDinV, raizDinC = raiz(vfV, "Dinamico"), raiz(vfC, "Dinamico")
end

function Aberracao.ligar(l: boolean)
	ligado = l
	if not l then
		ocultar()
		destruirEstaticos()
		destruirDinamicos()
	end
end

function Aberracao.nivel(n: number)
	nivelAtual = n
	if n < NIVEL_ESTATICO then
		destruirEstaticos()
	end
	if n < NIVEL_MINIMO_DINAMICO then
		ocultar()
	end
end

function Aberracao.atualizar(e: any)
	if not ligado or nivelAtual < NIVEL_MINIMO_DINAMICO then
		return -- desligada: nada por quadro
	end
	local p = e.pulsos
	local intensidade = Regras.intensidade(cfg, p.dano, p.susto, e.caca)
	if intensidade < cfg.minimoVisivel then
		ocultar()
		return
	end

	local t = e.t
	local camera = ctx.camera
	if t - tCelulas >= cfg.intervaloCelulas then
		tCelulas = t
		atualizarCfg()
		if nivelAtual >= NIVEL_ESTATICO then
			reavaliarCelulas(camera.CFrame.Position)
		end
	end
	if t - tLuz >= cfg.intervaloLuz then
		tLuz = t
		noite = e.noite
		aplicarLuz()
	end
	if not ativo then
		varrerVisibilidade() -- antes de mostrar: nenhum clone aparece sem passar pelo teste
		tVisib = t
		ativo = true
		vfV.Visible = true
		vfC.Visible = true
	elseif t - tVisib >= cfg.intervaloVisibilidade then
		tVisib = t
		varrerVisibilidade()
	end

	if nivelAtual >= NIVEL_ESTATICO then
		processarFila(camera.CFrame.Position)
		if t - tNevoa >= cfg.intervaloNevoa then
			tNevoa = t
			atualizarNevoaEstatica(camera.CFrame.Position)
		end
	end

	local cf = camera.CFrame
	local fv, fc = Regras.fovs(e.fov, intensidade, cfg)
	camV.CFrame, camC.CFrame = cf, cf
	camV.FieldOfView, camC.FieldOfView = fv, fc
	local tV, tC = Regras.transparencias(intensidade, cfg)
	if tV + tC ~= transAtual then
		transAtual = tV + tC
		vfV.ImageTransparency, vfC.ImageTransparency = tV, tC
	end

	if nDinamicos > 0 then
		for _, d in dinamicos do
			for _, par in d.pares do
				if par.orig.Parent then
					local pcf = par.orig.CFrame
					par.v.CFrame, par.c.CFrame = pcf, pcf
				end
			end
		end
	end
end

return Aberracao
