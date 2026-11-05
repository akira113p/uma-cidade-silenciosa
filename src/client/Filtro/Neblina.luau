--!strict
-- Névoa em camadas: colunas de Beam verticais numa grade fixa no mundo (anel em volta da câmera) + partículas rasteiras.
-- Dono: S3. Contas puras em Regras/FiltroNeblina. Nada é criado por quadro: colunas vêm de um pool.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regras = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regras"):WaitForChild("FiltroNeblina"))

local Neblina = {}

type Coluna = {
	chave: string,
	part: Part,
	topo: Attachment,
	beams: { Beam }, -- camadas de largura decrescente sobre os mesmos Attachments
	x: number,
	z: number,
	nivel: number, -- degrau de densidade atual (0 = beam desligado)
	provisorio: boolean,
}
type Entrada = { y: number, x: number, z: number, pula: boolean, provisorio: boolean }

local cfg: any
local pc: any -- cfg.particulas
local ajuste: (string, any) -> any
local pai: Instance
local pasta: Folder
local pastaColunas: Folder
local texturas: any

local ativa = false -- ligar(true)
local nivelAuto = 3
local colunasOn = false
local particulasOn = false
local noPai = false

-- parâmetros vigentes (relidos de ajuste a cada 1 s)
local P = {
	esp = 28,
	rInt = 12,
	rExt = 150,
	rampaInt = 8,
	rampaExt = 50,
	jitter = 8,
	altura = 14,
	largura = 36,
	tChao = 0.55,
	clarear = 0.15,
	niveis = 10,
	espEfetivo = 28,
}
local assinatura = ""
local proxAssinatura = 0
local proxCor = 0
local corSeq: ColorSequence = ColorSequence.new(Color3.new(1, 1, 1))
local corAtualFog: Color3? = nil

local ativas: { [string]: Coluna } = {}
local pool: { Coluna } = {}
local desejadas: { [string]: Regras.Celula } = {}
local pendentes: { string } = {}
local cache: { [string]: Entrada } = {}
local nCache = 0
local seqs: { [number]: NumberSequence } = {}
local celulaI: number? = nil
local celulaJ: number? = nil
local proxRetentativa = 0

local paramsChao = RaycastParams.new()
paramsChao.FilterType = Enum.RaycastFilterType.Include
paramsChao.RespectCanCollide = false
local paramsTeto = RaycastParams.new()
paramsTeto.FilterType = Enum.RaycastFilterType.Include
paramsTeto.RespectCanCollide = false
paramsTeto.IgnoreWater = true
local proxFiltro = 0

local particulaPart: Part
local emissor: ParticleEmitter
local chaoParticulas = 0
local proxChaoParticulas = 0
local proxTaxa = 0
local taxaAtual = -1

local function temColunas(): boolean
	return texturas.neblinaMechaA ~= "" or texturas.neblinaMechaB ~= ""
end

local function atualizarFiltros(agora: number)
	if agora < proxFiltro then
		return
	end
	proxFiltro = agora + 2
	local mapa = workspace:FindFirstChild("Mapa")
	local lista: { Instance } = { workspace.Terrain }
	if mapa then
		for _, nome in { "Chao", "Ruas", "Rios" } do
			local f = mapa:FindFirstChild(nome)
			if f then
				table.insert(lista, f)
			end
		end
		paramsTeto.FilterDescendantsInstances = { mapa }
	else
		paramsTeto.FilterDescendantsInstances = {}
	end
	paramsChao.FilterDescendantsInstances = lista
end

local function lerParametros()
	P.esp = ajuste("Neblina_espacamento", cfg.espacamento)
	P.rInt = ajuste("Neblina_raioInterno", cfg.raioInterno)
	P.rExt = ajuste("Neblina_raioExterno", cfg.raioExterno)
	P.rampaInt = ajuste("Neblina_rampaInterna", cfg.rampaInterna)
	P.rampaExt = ajuste("Neblina_rampaExterna", cfg.rampaExterna)
	P.jitter = ajuste("Neblina_jitter", cfg.jitter)
	P.altura = ajuste("Neblina_altura", cfg.altura)
	P.largura = ajuste("Neblina_largura", cfg.largura)
	P.tChao = ajuste("Neblina_transparenciaChao", cfg.transparenciaChao)
	P.clarear = ajuste("Neblina_clarear", cfg.clarear)
	P.niveis = cfg.niveisFade
	P.espEfetivo = if nivelAuto <= 2 then P.esp * cfg.multiplicadorNivel2 else P.esp
end

local function assinar(): string
	return string.format(
		"%g|%g|%g|%g|%g|%g|%g|%g|%g|%g|%d",
		P.esp,
		P.rInt,
		P.rExt,
		P.rampaInt,
		P.rampaExt,
		P.jitter,
		P.altura,
		P.largura,
		P.tChao,
		P.clarear,
		nivelAuto
	)
end

local function sequencia(idx: number): NumberSequence
	local s = seqs[idx]
	if s then
		return s
	end
	local f = idx / P.niveis / #cfg.camadas -- cada camada leva 1/N da opacidade; a soma dá o núcleo denso
	local pontos = {}
	for _, p in cfg.perfil do
		table.insert(pontos, NumberSequenceKeypoint.new(p[1], math.clamp(1 - (1 - P.tChao) * p[2] * f, 0, 1)))
	end
	s = NumberSequence.new(pontos)
	seqs[idx] = s
	return s
end

local function novaColuna(): Coluna
	local part = Instance.new("Part")
	part.Name = "Coluna"
	part.Size = Vector3.one
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local base = Instance.new("Attachment")
	base.Name = "Base"
	base.Parent = part
	local topo = Instance.new("Attachment")
	topo.Name = "Topo"
	topo.Parent = part
	local beams = {}
	for k = 1, #cfg.camadas do
		local beam = Instance.new("Beam")
		beam.Attachment0 = base
		beam.Attachment1 = topo
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightInfluence = 0 -- sem acender com lanterna/luz de ponto; a cor vem do FogColor
		beam.LightEmission = 0
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureSpeed = cfg.velocidadeTextura
		beam.Enabled = false
		beam.Parent = part
		beams[k] = beam
	end
	return { chave = "", part = part, topo = topo, beams = beams, x = 0, z = 0, nivel = 0, provisorio = false }
end

local function setEnabled(c: Coluna, v: boolean)
	for _, b in c.beams do
		b.Enabled = v
	end
end

local function liberar(c: Coluna)
	ativas[c.chave] = nil
	setEnabled(c, false)
	c.nivel = 0
	c.part.Parent = nil
	table.insert(pool, c)
end

local function liberarTodas()
	for _, c in ativas do
		setEnabled(c, false)
		c.nivel = 0
		c.part.Parent = nil
		table.insert(pool, c)
	end
	table.clear(ativas)
	table.clear(pendentes)
	table.clear(desejadas)
	celulaI, celulaJ = nil, nil
end

local function resolver(cel: Regras.Celula, camY: number): Entrada
	local dx, dz = Regras.jitter(cel.chave, P.jitter)
	local x, z = cel.x + dx, cel.z + dz
	local origem = Vector3.new(x, camY + 100, z)
	local r = workspace:Raycast(origem, Vector3.new(0, -cfg.alcanceRaioChao, 0), paramsChao)
	local ent: Entrada
	if not r then
		ent = { y = camY - cfg.alturaOlhos, x = x, z = z, pula = false, provisorio = true }
	elseif r.Material == Enum.Material.Water then
		ent = { y = r.Position.Y, x = x, z = z, pula = true, provisorio = false }
	else
		local teto =
			workspace:Raycast(r.Position + Vector3.new(0, 1, 0), Vector3.new(0, cfg.tetoAlcance, 0), paramsTeto)
		ent = { y = r.Position.Y, x = x, z = z, pula = teto ~= nil, provisorio = false }
	end
	if nCache > cfg.maxCache then
		table.clear(cache)
		nCache = 0
	end
	if not cache[cel.chave] then
		nCache += 1
	end
	cache[cel.chave] = ent
	return ent
end

local function ativarColuna(cel: Regras.Celula, ent: Entrada)
	local c = table.remove(pool) or novaColuna()
	c.chave = cel.chave
	c.x, c.z = ent.x, ent.z
	c.provisorio = ent.provisorio
	c.nivel = 0
	c.part.Position = Vector3.new(ent.x, ent.y, ent.z)
	c.topo.Position = Vector3.new(0, P.altura, 0)
	local usaA = (#cel.chave + string.byte(cel.chave, #cel.chave)) % 2 == 0
	for k, b in c.beams do
		b.Width0 = P.largura * cfg.camadas[k]
		b.Width1 = P.largura * cfg.camadas[k]
		-- a textura corre ao longo do feixe: uma repetição por altura da coluna (antes: 36 > 14 cortava a textura)
		b.TextureLength = P.altura
		b.Color = corSeq
		local a = (k % 2 == 1) == usaA
		local tex = if a then texturas.neblinaMechaA else texturas.neblinaMechaB
		if tex == "" then
			tex = if a then texturas.neblinaMechaB else texturas.neblinaMechaA
		end
		b.Texture = tex
	end
	c.part.Parent = pastaColunas
	ativas[c.chave] = c
end

local function reconstruirAnel(cam: Vector3)
	local i = math.floor(cam.X / P.espEfetivo + 0.5)
	local j = math.floor(cam.Z / P.espEfetivo + 0.5)
	if i == celulaI and j == celulaJ then
		return
	end
	celulaI, celulaJ = i, j
	local lista =
		Regras.anel(i * P.espEfetivo, j * P.espEfetivo, P.espEfetivo, P.rInt - P.espEfetivo, P.rExt + P.espEfetivo)
	table.clear(desejadas)
	table.clear(pendentes)
	for _, cel in lista do
		desejadas[cel.chave] = cel
	end
	for chave, c in ativas do
		if not desejadas[chave] then
			liberar(c)
		end
	end
	for _, cel in lista do
		if not ativas[cel.chave] then
			local ent = cache[cel.chave]
			if ent then
				if not ent.pula then
					ativarColuna(cel, ent)
				end
			else
				table.insert(pendentes, cel.chave)
			end
		end
	end
end

local function processarPendentes(camY: number)
	local n = 0
	while n < cfg.colunasPorQuadro do
		local chave = table.remove(pendentes)
		if not chave then
			break
		end
		local cel = desejadas[chave]
		if cel and not ativas[chave] then
			n += 1
			local ent = resolver(cel, camY)
			if not ent.pula then
				ativarColuna(cel, ent)
			end
		end
	end
end

-- Mapa em streaming: colunas sem chão achado tentam de novo de vez em quando.
local function retentar(agora: number)
	if agora < proxRetentativa then
		return
	end
	proxRetentativa = agora + cfg.reTentarChao
	local refazer = {}
	for chave, c in ativas do
		if c.provisorio then
			table.insert(refazer, c)
			cache[chave] = nil
			nCache -= 1
		end
	end
	for _, c in refazer do
		local chave = c.chave
		liberar(c)
		table.insert(pendentes, chave)
	end
end

local function corDaNevoa(): ColorSequence
	local c = Lighting.FogColor:Lerp(Color3.new(1, 1, 1), P.clarear)
	return ColorSequence.new(c)
end

local function aplicarEstado()
	colunasOn = ativa and temColunas() and nivelAuto >= 2
	particulasOn = ativa and texturas.neblinaPuff ~= "" and nivelAuto >= 1
	local qualquer = colunasOn or particulasOn
	if qualquer and not noPai then
		pasta.Parent = pai
		noPai = true
	elseif not qualquer and noPai then
		pasta.Parent = nil
		noPai = false
	end
	pastaColunas.Parent = if colunasOn then pasta else nil
	emissor.Enabled = particulasOn
	particulaPart.Parent = if particulasOn then pasta else nil
	if not colunasOn then
		liberarTodas()
	end
	taxaAtual = -1
	proxAssinatura = 0
end

function Neblina.iniciar(ctx: any)
	cfg = ctx.config.Neblina
	pc = cfg.particulas
	texturas = ctx.config.Texturas
	ajuste = ctx.ajuste
	pai = ctx.pastaMundo

	pasta = Instance.new("Folder")
	pasta.Name = "Neblina"
	pastaColunas = Instance.new("Folder")
	pastaColunas.Name = "Colunas"

	particulaPart = Instance.new("Part")
	particulaPart.Name = "NeblinaRasteira"
	particulaPart.Transparency = 1
	particulaPart.Anchored = true
	particulaPart.CanCollide = false
	particulaPart.CanQuery = false
	particulaPart.CanTouch = false
	particulaPart.CastShadow = false
	particulaPart.Size = Vector3.new(pc.lado, 2, pc.lado)

	local tamMedio = (pc.tamanhoMin + pc.tamanhoMax) / 2
	local tamVar = (pc.tamanhoMax - pc.tamanhoMin) / 2
	emissor = Instance.new("ParticleEmitter")
	emissor.Texture = texturas.neblinaPuff
	emissor.Shape = Enum.ParticleEmitterShape.Box
	emissor.EmissionDirection = Enum.NormalId.Top
	emissor.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tamMedio, tamVar),
		NumberSequenceKeypoint.new(1, tamMedio, tamVar),
	})
	emissor.Lifetime = NumberRange.new(pc.vidaMin, pc.vidaMax)
	emissor.Speed = NumberRange.new(pc.velMin, pc.velMax)
	emissor.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, pc.transparencia),
		NumberSequenceKeypoint.new(0.75, pc.transparencia),
		NumberSequenceKeypoint.new(1, 1),
	})
	emissor.Rotation = NumberRange.new(0, 360)
	emissor.RotSpeed = NumberRange.new(-4, 4)
	emissor.LightInfluence = 1
	emissor.LightEmission = 0
	emissor.Orientation = Enum.ParticleOrientation.FacingCamera
	emissor.LockedToPart = false
	emissor.Rate = pc.taxaDia
	emissor.Enabled = false
	emissor.Parent = particulaPart

	lerParametros()
	assinatura = assinar()
	corSeq = corDaNevoa()
	emissor.Color = corSeq
	atualizarFiltros(0)
	aplicarEstado()
end

function Neblina.atualizar(e: any)
	if not noPai then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cam = camera.CFrame.Position
	local agora = e.t

	-- afinação ao vivo: se algum número mudou, recomeça o anel
	if agora >= proxAssinatura then
		proxAssinatura = agora + 1
		lerParametros()
		local nova = assinar()
		if nova ~= assinatura then
			assinatura = nova
			table.clear(seqs)
			table.clear(cache)
			nCache = 0
			liberarTodas()
		end
	end
	if agora >= proxCor then
		proxCor = agora + 0.25
		local fog = Lighting.FogColor
		if fog ~= corAtualFog then
			corAtualFog = fog
			corSeq = corDaNevoa()
			emissor.Color = corSeq
			for _, c in ativas do
				for _, b in c.beams do
					b.Color = corSeq
				end
			end
		end
	end
	atualizarFiltros(agora)

	if colunasOn then
		reconstruirAnel(cam)
		retentar(agora)
		processarPendentes(cam.Y)

		local clima = cfg.clima[e.clima] or 1
		local dens = math.clamp(clima * (1 - e.interior * cfg.densidadeInterior) * ajuste("Neblina_densidade", 1), 0, 1)
		local niveis = P.niveis
		for _, c in ativas do
			local d = math.sqrt((c.x - cam.X) ^ 2 + (c.z - cam.Z) ^ 2)
			local f = Regras.fade(d, P.rInt, P.rampaInt, P.rExt, P.rampaExt) * dens
			local idx = math.floor(Regras.quantizar(f, niveis) * niveis + 0.5)
			if idx ~= c.nivel then
				c.nivel = idx
				if idx == 0 then
					setEnabled(c, false)
				else
					local seq = sequencia(idx)
					for _, b in c.beams do
						b.Transparency = seq
						b.Enabled = true
					end
				end
			end
		end
	end

	if particulasOn then
		if agora >= proxChaoParticulas then
			proxChaoParticulas = agora + 0.25
			local r = workspace:Raycast(cam, Vector3.new(0, -cfg.alcanceRaioChao, 0), paramsChao)
			chaoParticulas = if r then r.Position.Y else cam.Y - cfg.alturaOlhos
		end
		particulaPart.Position = Vector3.new(cam.X, chaoParticulas + 1, cam.Z)
		if agora >= proxTaxa then
			proxTaxa = agora + 0.5
			local taxa = (pc.taxaDia + (pc.taxaNoite - pc.taxaDia) * e.noite)
				* (pc.multiplicadorClima[e.clima] or 1)
				* ajuste("Neblina_taxaParticulas", 1)
			if math.abs(taxa - taxaAtual) > 0.05 then
				taxaAtual = taxa
				emissor.Rate = taxa
			end
		end
	end
end

function Neblina.ligar(ligado: boolean)
	ativa = ligado
	aplicarEstado()
end

function Neblina.nivel(n: number)
	nivelAuto = n
	lerParametros()
	assinatura = assinar()
	table.clear(seqs)
	liberarTodas()
	aplicarEstado()
end

return Neblina
