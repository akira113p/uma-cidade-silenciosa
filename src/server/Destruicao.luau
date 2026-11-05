-- Destruicao (servidor): dano universal a construções. Qualquer fonte (tiro, golpe, garra, carro, explosão) dá dano ao material
-- da peça; ela escurece por estágios e quebra, abrindo um vão permanente. Contrato: docs/destruicao.md.
-- Estado só em tabela fraca (nada de atributo ou Script por peça); Sons, Ruido e Monstros são opcionais (pcall).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Destruicao"))
local CfgMat = require(Shared.Config:WaitForChild("Materiais"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Destruicao"))
local Raizes = require(Shared:WaitForChild("Raizes"))

local Destruicao = {}

export type TipoDano = "bala" | "corte" | "alavanca" | "marreta" | "garra" | "soco" | "impacto" | "explosao"
export type Info = {
	tipo: TipoDano,
	ponto: Vector3?,
	normal: Vector3?,
	fonte: any?,
	largura: number?,
	altura: number?,
	ruido: string?,
}
export type Resultado = { quebrou: boolean, fracao: number, efetivo: number, classe: string, vidaRestante: number }
type Extras = { normal: Vector3?, chao: Vector3? }
export type Evento = {
	normal: Vector3?, -- eixo da espessura da parede (unitário, sem sinal); só quando a peça foi recortada
	chao: Vector3?, -- pé do vão (parede vertical recortada)
	centro: Vector3,
	classe: string,
	material: string,
	papel: string,
	tipo: string,
	fonte: any?,
	grupo: string?,
}

type Cls = { papel: string, grupo: string?, modelo: Model? }
type Estado = {
	vida: number,
	vidaMax: number,
	classe: string,
	material: string,
	papel: string,
	estagio: number,
	transp0: number?,
	grupo: string?,
	modelo: Model?,
	travada: boolean?, -- limites estourados: só escurece
}

local fraca = { __mode = "k" }
local estados: { [Instance]: Estado } = setmetatable({}, fraca) :: any
local cache: { [Instance]: Cls | boolean } = setmetatable({}, fraca) :: any
local ultimoSom: { [Instance]: number } = setmetatable({}, fraca) :: any
local ultimoAtropelo: { [Instance]: number } = setmetatable({}, fraca) :: any

local ouvintes: { (Evento) -> () } = {}
-- Vãos abertos em parede vertical { pos (pé do vão), normal (eixo da espessura, sem sinal) }: o navmesh do Roblox NÃO enxerga a
-- peça que saiu (medido no Rastejador: NoPath de fora para dentro depois do buraco), então quem quer atravessar usa vaoUtil.
local vaos: { { pos: Vector3, normal: Vector3 } } = {}
local furosAbertos = 0
local pecasExtras = 0
local iniciado = false
local servicos: { [string]: any } = {}
local avisos: { [string]: number } = {}

local ESCURECER_ALVO = Color3.fromRGB(Cfg.escurecerAlvo[1], Cfg.escurecerAlvo[2], Cfg.escurecerAlvo[3])
local BRANCO = Color3.new(1, 1, 1)

-- warn com limite de taxa por chave (1 a cada 5 s), para uma falha repetida não virar spam.
local function avisar(chave: string, texto: string)
	local agora = os.clock()
	if agora - (avisos[chave] or -math.huge) < 5 then
		return
	end
	avisos[chave] = agora
	warn("[Destruicao] " .. texto)
end

-- Sons, Ruido e Monstros: opcionais, só depois do iniciar. nil se o serviço falhar ao carregar.
local function servico(nome: string): any
	if not iniciado then
		return nil
	end
	local s = servicos[nome]
	if s == nil then
		local arquivo = script.Parent:FindFirstChild(nome)
		local ok, modulo = false, nil
		if arquivo then
			ok, modulo = pcall(require, arquivo)
		end
		s = if ok then modulo else false
		servicos[nome] = s
	end
	return s or nil
end

-- Classificação ---------------------------------------------------------------------------------------------------

-- Raiz (Mapa ou ZonaTeste) que contém a peça, sem cache: a ZonaTeste pode surgir ou sumir durante o jogo.
local function raizDe(inst: Instance, nome: string): Instance?
	for _, r in Raizes.obter(nome) do
		if inst:IsDescendantOf(r) then
			return r
		end
	end
	return nil
end

local function classificar(inst: Instance): Cls?
	if not inst:IsA("BasePart") or not inst.CanQuery or inst:GetAttribute("Indestrutivel") == true then
		return nil
	end
	local emConstrucoes = false
	local raiz = raizDe(inst, "Construcoes")
	if raiz then
		emConstrucoes = true
	else
		raiz = raizDe(inst, "Props")
		if not raiz then
			return nil
		end
	end
	local movel = false
	local prop: string? = nil
	local atual = inst.Parent
	while atual and atual ~= raiz and atual ~= workspace do
		if atual:IsA("Model") then
			for _, atributo in { "Movel", "Estrutura" } do
				local nome = atual:GetAttribute(atributo)
				if type(nome) == "string" then
					if Cfg.grupos[nome] then
						return { papel = "grupo", grupo = nome, modelo = atual }
					elseif atributo == "Movel" then
						movel = true
					end
				end
			end
			local p = atual:GetAttribute("Prop")
			if prop == nil and type(p) == "string" then
				prop = p
			end
		end
		atual = atual.Parent
	end
	if movel then
		return nil -- móvel fora da lista de grupos: apagaria o loot (decisão pendente)
	end
	if emConstrucoes then
		local papel = Regras.papelDe(inst.Name, Cfg)
		if papel and papel.destrutivel then
			return { papel = papel.papel }
		end
		return nil
	end
	if prop and Cfg.props[prop] then
		return { papel = "prop" }
	end
	return nil
end

local function clsDe(inst: Instance): Cls?
	local c = cache[inst]
	if c == nil then
		c = classificar(inst) or false
		cache[inst] = c
	end
	if c == false then
		return nil
	end
	return c :: Cls
end

-- Classe, vida máxima e material da peça (ou do grupo), sem criar estado.
local function dadosDe(inst: Instance, cls: Cls): (string, number, string)
	if cls.grupo then
		local g = Cfg.grupos[cls.grupo]
		return Regras.classeDe(g.material, CfgMat).classe, g.vida, g.material
	end
	local peca = inst :: BasePart
	local material = peca.Material.Name
	local s = peca.Size
	return Regras.classeDe(material, CfgMat).classe,
		math.floor(Regras.vidaMaxima(material, math.min(s.X, s.Y, s.Z), CfgMat) + 0.5), -- inteiro: espessura 0.80000305 deixava 0.0005 de vida
		material
end

local function estadoDe(inst: Instance, cls: Cls): Estado
	local chave: Instance = cls.modelo or inst
	local e = estados[chave]
	if e then
		return e
	end
	local classe, vidaMax, material = dadosDe(inst, cls)
	e = {
		vida = vidaMax,
		vidaMax = vidaMax,
		classe = classe,
		material = material,
		papel = cls.papel,
		estagio = 0,
		transp0 = if cls.grupo then nil else (inst :: BasePart).Transparency,
		grupo = cls.grupo,
		modelo = cls.modelo,
	}
	estados[chave] = e
	return e :: Estado
end

-- Vida atual (ou máxima se nunca levou dano), classe e chave de estado, sem criar estado.
local function vidaDe(inst: Instance, cls: Cls): (number, string)
	local e = estados[cls.modelo or inst]
	if e then
		return e.vida, e.classe
	end
	local classe, vidaMax = dadosDe(inst, cls)
	return vidaMax, classe
end

local function chaveDe(inst: Instance, cls: Cls): Instance
	return cls.modelo or inst
end

-- Visual ---------------------------------------------------------------------------------------------------------

local function pintarPeca(peca: BasePart, e: Estado)
	local original = peca:GetAttribute("CorOriginal")
	if typeof(original) ~= "Color3" then
		original = peca.Color
		peca:SetAttribute("CorOriginal", original)
	end
	local cor = original :: Color3
	local classe = CfgMat.classes[e.classe]
	if classe.efeito == "rachar" then
		peca.Color = cor:Lerp(BRANCO, Regras.fatorClarear(e.estagio, Cfg))
		peca.Transparency = Regras.transparenciaRachada(e.transp0 or peca.Transparency, e.estagio, Cfg)
	else
		peca.Color = cor:Lerp(ESCURECER_ALVO, Regras.fatorEscurecer(e.classe, e.estagio, CfgMat, Cfg))
	end
end

local function pintar(inst: Instance, e: Estado)
	if e.modelo then
		for _, d in e.modelo:GetDescendants() do
			if d:IsA("BasePart") then
				pintarPeca(d, e)
			end
		end
	else
		pintarPeca(inst :: BasePart, e)
	end
end

local function poeira(ponto: Vector3, cor: { number })
	local c = Cfg.poeira
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.CanQuery = false
	ancora.CanTouch = false
	ancora.Transparency = 1
	ancora.Size = Vector3.new(1, 1, 1)
	ancora.Position = ponto
	local emissor = Instance.new("ParticleEmitter")
	emissor.Rate = 0
	emissor.Lifetime = NumberRange.new(c.vida[1], c.vida[2])
	emissor.Speed = NumberRange.new(c.velocidade[1], c.velocidade[2])
	emissor.SpreadAngle = Vector2.new(180, 180)
	emissor.Size = NumberSequence.new(c.tamanho[1], c.tamanho[2])
	emissor.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	emissor.Color = ColorSequence.new(Color3.fromRGB(cor[1], cor[2], cor[3]))
	emissor.Parent = ancora
	ancora.Parent = workspace
	emissor:Emit(c.quantidade)
	Debris:AddItem(ancora, c.duracao)
end

local function tocarSom(nome: string, ponto: Vector3)
	local Sons = servico("Sons")
	if Sons then
		local ok, erro = pcall(Sons.tocar, nome, ponto)
		if not ok then
			avisar("som", "Sons.tocar falhou: " .. tostring(erro))
		end
	end
end

local function emitirRuido(acao: string, ponto: Vector3, fonte: any)
	local Ruido = servico("Ruido")
	if Ruido then
		local ok, erro = pcall(Ruido.emitirAcao, acao, ponto, fonte)
		if not ok then
			avisar("ruido", "Ruido.emitirAcao falhou: " .. tostring(erro))
		end
	end
end

-- Fonte de ruído: só Player ou Model são aceitos pelo Ruido.
local function fonteDeRuido(fonte: any): Instance?
	if typeof(fonte) == "Instance" and (fonte:IsA("Player") or fonte:IsA("Model")) then
		return fonte
	end
	return nil
end

-- Quebra ---------------------------------------------------------------------------------------------------------

local function posicaoDe(inst: Instance, cls: Cls): Vector3
	if cls.modelo then
		return cls.modelo:GetPivot().Position
	end
	return (inst :: BasePart).Position
end

-- Divide a peça em retalhos (clones Anchored) em volta do vão e a destrói. Devolve (centro do vão, quebrou).
local function cortar(peca: BasePart, e: Estado, info: Info, ponto: Vector3): (Vector3?, boolean, Extras?)
	local s = peca.Size
	local dims = { s.X, s.Y, s.Z }
	local eixoFino = 1
	for i = 2, 3 do
		if dims[i] < dims[eixoFino] then
			eixoFino = i
		end
	end
	local c = peca.CFrame
	local lp = c:PointToObjectSpace(ponto)
	local pontoLocal = { lp.X, lp.Y, lp.Z }
	local buraco = Regras.tamanhoBuraco(info.tipo, dims, info.largura, Cfg)
	if info.altura then
		buraco.altura = math.min(info.altura, dims[2])
	end
	local ancoraChao = eixoFino ~= 2 and info.tipo ~= "bala" -- furo de bala é no ponto do tiro, não do chão para cima
	local minimo = Cfg.retalhos.minimo
	local retalhos = Regras.recortar(dims, eixoFino, pontoLocal, buraco, ancoraChao, minimo)
	if furosAbertos >= Cfg.limites.buracos or pecasExtras + #retalhos > Cfg.limites.pecasExtras then
		return nil, false
	end
	local vao = Regras.vao(dims, eixoFino, pontoLocal, buraco, ancoraChao, minimo)
	local pai = peca.Parent
	local herdado = Cfg.retalhos.danoHerdado
	for _, r in retalhos do
		local clone = peca:Clone()
		clone.Size = Vector3.new(r.tamanho[1], r.tamanho[2], r.tamanho[3])
		clone.CFrame = c * CFrame.new(r.centro[1], r.centro[2], r.centro[3])
		clone.Anchored = true
		local novo: Estado = {
			vida = e.vidaMax * (1 - herdado),
			vidaMax = e.vidaMax,
			classe = e.classe,
			material = e.material,
			papel = e.papel,
			estagio = Regras.estagio(herdado, Cfg.estagios),
			transp0 = e.transp0,
		}
		estados[clone] = novo
		cache[clone] = { papel = e.papel }
		clone.Parent = pai
		if novo.estagio > 0 then
			pintarPeca(clone, novo)
		end
	end
	furosAbertos += 1
	pecasExtras += #retalhos
	local centro = c:PointToWorldSpace(Vector3.new(vao.centro[1], vao.centro[2], vao.centro[3]))
	-- normal = eixo da espessura (sem sinal); chão = pé do vão, 1 stud acima da base (só parede vertical): o navmesh não enxerga
	-- a peça que saiu, então quem atravessa o vão precisa saber onde ele está (MonstroArrombar.buracos)
	local eixos = { c.RightVector, c.UpVector, c.LookVector }
	local extras: Extras = { normal = eixos[eixoFino] }
	if eixoFino ~= 2 then
		extras.chao = c:PointToWorldSpace(Vector3.new(vao.centro[1], -s.Y / 2 + 1, vao.centro[3]))
	end
	peca:Destroy()
	return centro, true, extras
end

local function quebrar(inst: Instance, cls: Cls, e: Estado, info: Info, ponto: Vector3): boolean
	local centro: Vector3? = ponto
	local extras: Extras? = nil
	if cls.modelo then
		centro = cls.modelo:GetPivot().Position
		cls.modelo:Destroy()
	else
		local peca = inst :: BasePart
		local s = peca.Size
		local bloco = peca.ClassName == "Part" and (peca :: Part).Shape == Enum.PartType.Block
		if Regras.inteiraSeMenor({ s.X, s.Y, s.Z }, Cfg) or not bloco or CfgMat.classes[e.classe].inteira then
			centro = peca.Position
			peca:Destroy()
		else
			local ok, vao, cortou, ex = pcall(cortar, peca, e, info, ponto)
			if not ok then
				avisar("cortar", "falha ao recortar: " .. tostring(vao))
				return false
			end
			if not cortou then
				e.travada = true
				avisar("limite", "limite de buracos ou peças extras atingido: as peças só escurecem")
				return false
			end
			centro = vao
			extras = ex
		end
	end
	local posicao = centro or ponto
	if extras and extras.chao and extras.normal then
		local n = Vector3.new(extras.normal.X, 0, extras.normal.Z)
		if n.Magnitude > 1e-3 then
			table.insert(vaos, { pos = extras.chao, normal = n.Unit })
		end
	end
	local classe = CfgMat.classes[e.classe]
	tocarSom(classe.somQuebra, posicao)
	emitirRuido(classe.acaoQuebra, posicao, fonteDeRuido(info.fonte))
	poeira(posicao, classe.poeira)
	local Monstros = servico("Monstros")
	if Monstros and Monstros.invalidarCaminhos then
		local ok, erro = pcall(Monstros.invalidarCaminhos, posicao, Cfg.invalidarCaminhos.raio)
		if not ok then
			avisar("caminhos", "Monstros.invalidarCaminhos falhou: " .. tostring(erro))
		end
	end
	local grupo = if cls.grupo then Cfg.grupos[cls.grupo] else nil
	local evento: Evento = {
		normal = extras and extras.normal,
		chao = extras and extras.chao,
		centro = posicao,
		classe = e.classe,
		material = e.material,
		papel = e.papel,
		tipo = info.tipo,
		fonte = info.fonte,
		grupo = if grupo then cls.grupo else nil,
	}
	for _, fn in table.clone(ouvintes) do
		local ok, erro = pcall(fn, evento)
		if not ok then
			avisar("ouvinte", "ouvinte de aoQuebrar falhou: " .. tostring(erro))
		end
	end
	return true
end

local function aplicarDano(inst: Instance, quantidade: number, info: Info): Resultado?
	local cls = clsDe(inst)
	if not cls then
		return nil
	end
	local e = estadoDe(inst, cls)
	local classe = CfgMat.classes[e.classe]
	local chave = chaveDe(inst, cls)
	local ponto = info.ponto or posicaoDe(inst, cls)
	local agora = os.clock()
	local efetivo = Regras.danoEfetivo(quantidade, info.tipo, e.classe, CfgMat)

	local function resultado(quebrou: boolean): Resultado
		return {
			quebrou = quebrou,
			fracao = math.clamp(1 - e.vida / e.vidaMax, 0, 1),
			efetivo = efetivo,
			classe = e.classe,
			vidaRestante = math.max(0, e.vida),
		}
	end
	local function somImpacto()
		if agora - (ultimoSom[chave] or -math.huge) >= Cfg.somImpactoIntervalo then
			ultimoSom[chave] = agora
			tocarSom(classe.somImpacto, ponto)
		end
	end

	if efetivo <= 0 or e.travada then
		somImpacto()
		return resultado(false)
	end
	e.vida -= efetivo
	somImpacto()
	if info.ruido then
		emitirRuido(info.ruido, ponto, fonteDeRuido(info.fonte))
	end
	local estagio = Regras.estagio(math.clamp(1 - e.vida / e.vidaMax, 0, 1), Cfg.estagios)
	if estagio ~= e.estagio then
		e.estagio = estagio
		pintar(inst, e)
	end
	if e.vida <= 0 then
		local quebrou = quebrar(inst, cls, e, info, ponto)
		if not quebrou then
			e.vida = 0
			e.estagio = #Cfg.estagios
			pintar(inst, e)
		end
		return resultado(quebrou)
	end
	return resultado(false)
end

-- API pública ----------------------------------------------------------------------------------------------------

function Destruicao.ehDestrutivel(inst: Instance): boolean
	local ok, cls = pcall(clsDe, inst)
	return ok and cls ~= nil
end

function Destruicao.dano(inst: Instance, quantidade: number, info: Info): Resultado?
	if type(quantidade) ~= "number" or quantidade ~= quantidade or quantidade <= 0 or quantidade == math.huge then
		return nil
	end
	if type(info) ~= "table" or type(info.tipo) ~= "string" then
		return nil
	end
	local ok, res = pcall(aplicarDano, inst, quantidade, info)
	if not ok then
		avisar("dano", "falha em dano: " .. tostring(res))
		return nil
	end
	return res
end

function Destruicao.vidaRestante(inst: Instance): number?
	local cls = clsDe(inst)
	if not cls then
		return nil
	end
	return (vidaDe(inst, cls))
end

function Destruicao.golpesPara(inst: Instance, quantidade: number, tipo: TipoDano): number
	local cls = clsDe(inst)
	if not cls then
		return math.huge
	end
	local vida, classe = vidaDe(inst, cls)
	return Regras.golpesPara(vida, quantidade, tipo, classe, CfgMat)
end

-- Devolve a função que remove o ouvinte.
function Destruicao.aoQuebrar(fn: (Evento) -> ()): () -> ()
	table.insert(ouvintes, fn)
	return function()
		local i = table.find(ouvintes, fn)
		if i then
			table.remove(ouvintes, i)
		end
	end
end

function Destruicao.furos(): number
	return furosAbertos
end

-- Vão aberto que leva de `de` até `alvo` (um de cada lado da parede), até `raio` studs de `de`; o de menor desvio. A normal
-- devolvida aponta para o lado de `de`. nil se não há.
function Destruicao.vaoUtil(de: Vector3, alvo: Vector3, raio: number): { pos: Vector3, normal: Vector3 }?
	local melhor = nil
	local menor = math.huge
	for _, v in vaos do
		local a, b = (de - v.pos):Dot(v.normal), (alvo - v.pos):Dot(v.normal)
		local d1 = Vector3.new(de.X - v.pos.X, 0, de.Z - v.pos.Z).Magnitude
		if d1 <= raio and a * b < 0 and math.abs(a) > 0.1 then
			local total = d1 + Vector3.new(alvo.X - v.pos.X, 0, alvo.Z - v.pos.Z).Magnitude
			if total < menor then
				melhor, menor = { pos = v.pos, normal = if a > 0 then v.normal else -v.normal }, total
			end
		end
	end
	return melhor
end

function Destruicao.estatisticas(): { furos: number, pecasExtras: number, danificadas: number }
	local n = 0
	for _ in estados do
		n += 1
	end
	return { furos = furosAbertos, pecasExtras = pecasExtras, danificadas = n }
end

-- Ponto da peça mais perto de `p` (clamp no espaço local).
local function pontoMaisProximo(peca: BasePart, p: Vector3): Vector3
	local l = peca.CFrame:PointToObjectSpace(p)
	local h = peca.Size / 2
	return peca.CFrame:PointToWorldSpace(
		Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	)
end

local paramsPecas = OverlapParams.new()
paramsPecas.FilterType = Enum.RaycastFilterType.Include
local raizesAtuais: { Instance } = {}

-- Include {Construcoes e Props do Mapa e da ZonaTeste}; refeito quando as pastas mudam.
local function atualizarParams(): boolean
	local lista = Raizes.obter("Construcoes")
	for _, p in Raizes.obter("Props") do
		table.insert(lista, p)
	end
	if not Raizes.iguais(lista, raizesAtuais) then
		raizesAtuais = lista
		paramsPecas.FilterDescendantsInstances = lista
	end
	return #lista > 0
end

-- Peças destrutíveis (uma por grupo) dentro da caixa.
local function pecasNaCaixa(cf: CFrame, tamanho: Vector3): { { peca: BasePart, cls: Cls } }
	local lista = {}
	if not atualizarParams() then
		return lista
	end
	local vistos: { [Instance]: boolean } = {}
	for _, parte in workspace:GetPartBoundsInBox(cf, tamanho, paramsPecas) do
		local cls = parte.Parent and clsDe(parte)
		if cls then
			local chave = chaveDe(parte, cls)
			if not vistos[chave] then
				vistos[chave] = true
				table.insert(lista, { peca = parte, cls = cls })
			end
		end
	end
	return lista
end

function Destruicao.explosao(centro: Vector3, raio: number, dano: number, fonte: any?)
	local ok, erro = pcall(function()
		if not atualizarParams() or raio <= 0 or dano <= 0 then
			return
		end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = raizesAtuais
		params.MaxParts = Cfg.explosaoMaxPecas
		local alvos: { { peca: BasePart, ponto: Vector3, queda: number } } = {}
		local vistos: { [Instance]: number } = {}
		for _, parte in workspace:GetPartBoundsInRadius(centro, raio, params) do
			local cls = clsDe(parte)
			if cls then
				local ponto = pontoMaisProximo(parte, centro)
				local queda = Regras.quedaExplosao((ponto - centro).Magnitude, raio)
				local chave = chaveDe(parte, cls)
				if queda > 0 and (vistos[chave] or 0) < queda then
					vistos[chave] = queda
					table.insert(alvos, { peca = parte, ponto = ponto, queda = queda })
				end
			end
		end
		for _, a in alvos do
			-- o grupo aparece uma vez por peça: só a peça de maior queda dele aplica o dano
			local cls = clsDe(a.peca)
			if a.peca.Parent and cls and vistos[chaveDe(a.peca, cls)] == a.queda then
				vistos[chaveDe(a.peca, cls)] = -1
				Destruicao.dano(a.peca, dano * a.queda, { tipo = "explosao", ponto = a.ponto, fonte = fonte })
			end
		end
	end)
	if not ok then
		avisar("explosao", "falha na explosão: " .. tostring(erro))
	end
end

-- Dimensões do chassi no plano: largura (menor) e comprimento (maior).
local function medidasDoChassi(chassi: BasePart): (number, number)
	return math.min(chassi.Size.X, chassi.Size.Z), math.max(chassi.Size.X, chassi.Size.Z)
end

local function paraPlano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local paramsMonstros = OverlapParams.new()
paramsMonstros.FilterType = Enum.RaycastFilterType.Include

local function varrerMonstros(
	cf: CFrame,
	tamanho: Vector3,
	dir: Vector3,
	velocidade: number,
	fonte: any
): (number, number)
	local pasta = workspace:FindFirstChild("Monstros")
	local Monstros = servico("Monstros")
	if not (pasta and Monstros) then
		return 0, 0
	end
	paramsMonstros.FilterDescendantsInstances = { pasta }
	local c = Cfg.carro.atropelo
	local dano = Regras.danoAtropelo(velocidade, Cfg)
	if dano <= 0 then
		return 0, 0
	end
	local agora = os.clock()
	local custo, atropelados = 0, 0
	local atacante = if typeof(fonte) == "Instance" and fonte:IsA("Player") then fonte else nil
	local vistos: { [Model]: boolean } = {}
	for _, parte in workspace:GetPartBoundsInBox(cf, tamanho, paramsMonstros) do
		local modelo = Monstros.ehMonstro(parte)
		if modelo and not vistos[modelo] and agora - (ultimoAtropelo[modelo] or -math.huge) >= c.intervalo then
			vistos[modelo] = true
			ultimoAtropelo[modelo] = agora
			Monstros.dano(modelo, dano, atacante)
			atropelados += 1
			custo += dano * c.recuo
			local hrp = modelo:FindFirstChild("HumanoidRootPart")
			if velocidade >= c.velImpulso and hrp and hrp:IsA("BasePart") then
				hrp:ApplyImpulse(dir * c.impulso * hrp.AssemblyMass)
			end
		end
	end
	return custo, atropelados
end

-- 10 Hz, só carro com motorista e acima de velMin (quem chama confere). O carro atravessa o que a energia vence.
function Destruicao.varrerCarro(
	chassi: BasePart,
	velocidade: Vector3,
	massa: number,
	fonte: any?
): { custoCarroceria: number, atropelados: number }
	local saida = { custoCarroceria = 0, atropelados = 0 }
	local ok, erro = pcall(function()
		local c = Cfg.carro
		local plano = paraPlano(velocidade)
		local vel = plano.Magnitude
		if vel < c.velMin then
			return
		end
		local dir = plano.Unit
		local largura, comprimento = medidasDoChassi(chassi)
		local alcance = c.alcanceBase + vel * c.passoLaco * c.passoFator
		local altura = chassi.Size.Y
		local pos = chassi.Position
		local nariz = Vector3.new(pos.X, pos.Y + c.alturaChao, pos.Z) + dir * (comprimento / 2) -- base do chassi + alturaChao + metade da caixa
		local centro = nariz + dir * (alcance / 2)
		local cf = CFrame.lookAt(centro, centro + dir)
		local tamanho = Vector3.new(largura + c.larguraExtra, altura, alcance)

		local energia = Regras.danoImpactoCarro(massa, vel, Cfg)
		for _, a in pecasNaCaixa(cf, tamanho) do
			local peca, cls = a.peca, a.cls
			local vida, classe = vidaDe(peca, cls)
			local mult = CfgMat.matriz.impacto[classe] or 0
			if mult > 0 and peca.Parent and Regras.atravessa(energia * mult, vida) then
				local res = Destruicao.dano(peca, energia, {
					tipo = "impacto",
					ponto = pontoMaisProximo(peca, nariz),
					fonte = fonte or chassi.Parent,
					largura = largura + c.larguraVao,
				})
				if res and res.quebrou then
					saida.custoCarroceria += Regras.custoCarroceria(vida, Cfg)
				end
			end
		end

		local custo, atropelados = varrerMonstros(cf, tamanho, dir, vel, fonte)
		saida.custoCarroceria += custo
		saida.atropelados = atropelados
	end)
	if not ok then
		avisar("varrer", "falha em varrerCarro: " .. tostring(erro))
	end
	return saida
end

-- Na batida (deltaV alto): a energia perdida vai para a peça destrutível mais perto do nariz. Devolve o custo de carroceria
-- só do que quebrou; a parede escurece mesmo sem quebrar.
function Destruicao.impactoCarro(
	chassi: BasePart,
	velocidadeAntes: Vector3,
	velocidadeDepois: Vector3,
	massa: number,
	fonte: any?
): number
	local custo = 0
	local ok, erro = pcall(function()
		local c = Cfg.carro
		local antes, depois = paraPlano(velocidadeAntes), paraPlano(velocidadeDepois)
		local energia = 0.5 * massa * (antes.Magnitude ^ 2 - depois.Magnitude ^ 2) * c.escalaEnergia
		if energia <= 0 or antes.Magnitude < 1e-3 then
			return
		end
		local dir = antes.Unit
		local largura, comprimento = medidasDoChassi(chassi)
		local altura = chassi.Size.Y
		local pos = chassi.Position
		local nariz = Vector3.new(pos.X, pos.Y, pos.Z) + dir * (comprimento / 2)
		local centro = nariz + dir * (c.alcanceBatida / 2 - c.recuoBatida)
		local cf = CFrame.lookAt(centro, centro + dir)
		local tamanho = Vector3.new(largura + c.larguraExtra, math.max(altura, 3), c.alcanceBatida)
		local melhor: BasePart? = nil
		local melhorCls: Cls? = nil
		local menor = math.huge
		for _, a in pecasNaCaixa(cf, tamanho) do
			local d = (pontoMaisProximo(a.peca, nariz) - nariz).Magnitude
			if d < menor then
				melhor, melhorCls, menor = a.peca, a.cls, d
			end
		end
		if not (melhor and melhorCls) then
			return
		end
		local vida = vidaDe(melhor, melhorCls)
		local res = Destruicao.dano(melhor, energia, {
			tipo = "impacto",
			ponto = pontoMaisProximo(melhor, nariz),
			fonte = fonte or chassi.Parent,
			largura = largura + c.larguraVao,
		})
		if res and res.quebrou then
			custo = Regras.custoCarroceria(vida, Cfg)
		end
	end)
	if not ok then
		avisar("impacto", "falha em impactoCarro: " .. tostring(erro))
	end
	return custo
end

-- Comandos de teste (Studio) ---------------------------------------------------------------------------------------

local function mira(jogador: Player): (RaycastResult?, string?)
	local personagem = jogador and jogador.Character
	local cabeca = personagem and personagem:FindFirstChild("Head")
	if not (personagem and cabeca and cabeca:IsA("BasePart")) then
		return nil, "jogador sem personagem"
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personagem }
	return workspace:Raycast(cabeca.Position, cabeca.CFrame.LookVector * 20, params), nil
end

local function descrever(inst: Instance): string
	local cls = clsDe(inst)
	if not cls then
		local papel = Regras.papelDe(inst.Name, Cfg)
		return string.format(
			"%s: indestrutível (papel %s, CanQuery %s)",
			inst:GetFullName(),
			papel and papel.papel or "nenhum",
			tostring(inst:IsA("BasePart") and inst.CanQuery)
		)
	end
	local e = estados[chaveDe(inst, cls)]
	local vida, classe = vidaDe(inst, cls)
	local _, vidaMax, material = dadosDe(inst, cls)
	return string.format(
		"%s: papel %s, material %s, classe %s, vida %.1f/%.1f, estágio %d%s",
		inst:GetFullName(),
		cls.papel,
		material,
		classe,
		vida,
		vidaMax,
		e and e.estagio or 0,
		if cls.grupo then ", grupo " .. cls.grupo else ""
	)
end

local function registrarTestes()
	local Teste = require(script.Parent.Teste)
	Teste.registrar("destruicao_info", function(jogador: Player)
		local r, motivo = mira(jogador)
		if not r then
			return motivo or "nada na mira (20 studs)"
		end
		return descrever(r.Instance)
	end)
	Teste.registrar("destruicao_dano", function(jogador: Player, tipo: string?, quantidade: number?)
		local r, motivo = mira(jogador)
		if not r then
			return motivo or "nada na mira (20 studs)"
		end
		local res = Destruicao.dano(r.Instance, tonumber(quantidade) or 25, {
			tipo = (tipo or "bala") :: TipoDano,
			ponto = r.Position,
			normal = r.Normal,
			fonte = jogador,
		})
		if not res then
			return "não destrutível: " .. descrever(r.Instance)
		end
		return string.format(
			"quebrou=%s fração=%.2f efetivo=%.1f classe=%s vidaRestante=%.1f",
			tostring(res.quebrou),
			res.fracao,
			res.efetivo,
			res.classe,
			res.vidaRestante
		)
	end)
	Teste.registrar("destruicao_nomes", function()
		local raizes = Raizes.obter("Construcoes")
		if #raizes == 0 then
			return "sem Mapa.Construcoes"
		end
		local contagem: { [string]: number } = {}
		for _, construcoes in raizes do
			for _, d in construcoes:GetDescendants() do
				if d:IsA("BasePart") and d.CanQuery then
					contagem[d.Name] = (contagem[d.Name] or 0) + 1
				end
			end
		end
		local linhas: { { nome: string, n: number } } = {}
		for nome, n in contagem do
			table.insert(linhas, { nome = nome, n = n })
		end
		table.sort(linhas, function(a, b)
			return a.n > b.n
		end)
		local saida = {}
		for i, l in linhas do
			if i > 80 then
				break
			end
			local papel = Regras.papelDe(l.nome, Cfg)
			table.insert(
				saida,
				string.format(
					"%s x%d: %s",
					l.nome,
					l.n,
					if papel
						then papel.papel .. (if papel.destrutivel then " (destrutível)" else " (não)")
						else "sem papel"
				)
			)
		end
		return string.format("%d nomes distintos (80 mais frequentes)\n%s", #linhas, table.concat(saida, "\n"))
	end)
	Teste.registrar("destruicao_explosao", function(jogador: Player, raio: number?, dano: number?)
		local personagem = jogador and jogador.Character
		local hrp = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) then
			return "jogador sem personagem"
		end
		local centro = hrp.Position + hrp.CFrame.LookVector * 10
		Destruicao.explosao(centro, tonumber(raio) or 20, tonumber(dano) or 400, jogador)
		return string.format("explosão em %s, raio %s", tostring(centro), tostring(tonumber(raio) or 20))
	end)
	Teste.registrar("destruicao_estado", function()
		local s = Destruicao.estatisticas()
		return string.format("furos=%d pecasExtras=%d danificadas=%d", s.furos, s.pecasExtras, s.danificadas)
	end)
end

function Destruicao.iniciar()
	iniciado = true
	registrarTestes()
end

return Destruicao
