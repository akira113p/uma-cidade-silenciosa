-- Monta o Model visual de uma arma (docs/armas.md §8). Usado pelo servidor (arma na mão, presa à RightHand) e pelo cliente (viewmodel).
-- Origem do Model = empunhadura (Cabo), cano para -Z, cima +Y, em studs. Dados de Config/ArmasMalhas (gerado por
-- ferramentas/modelos/gerar_config_armas.py); sem malha enviada o Model sai como um bloco provisório do tamanho certo, com `warn`.
--
-- Estrutura: Model `id` > Cabo (Part invisível 0,2, PrimaryPart) + um MeshPart por parte soldado ao Cabo (WeldConstraint),
-- + Attachments no Cabo: Boca (saída do tiro/clarão), Ejecao (cápsula), ApoioEsquerdo (mão esquerda; só armas de duas mãos), Mira (olho; opcional).
-- Tudo sem colisão/consulta/toque, sem sombra, Massless. O lançador tem a parte `Foguete` (esconder depois do disparo é com quem anima).
--
-- A malha vem de AssetService:CreateMeshPartAsync (rola no servidor e no cliente; LoadAsset só roda no servidor). Isso rende (yield), então
-- `criar` é síncrona e usa um molde em cache; o módulo começa a baixar os moldes sozinho ao ser requerido (`precarregar`). Quem chamar `criar`
-- antes do molde chegar recebe o bloco provisório (e o molde chega para a próxima). `ArmaModelo.pronta(id)` diz se a malha já está no cache.
local AssetService = game:GetService("AssetService")

local Malhas: { [string]: any } = require(script.Parent:WaitForChild("Config"):WaitForChild("ArmasMalhas")) :: any

local ArmaModelo = {}

export type Opcoes = {
	bloco: boolean?, -- true: força o bloco provisório (teste)
}

-- Tamanho/centro/âncoras do bloco provisório, copiados de modelos 3d/armas_roblox/manifesto.json (2026-11-05). Só valem sem malha.
local PROVISORIO: { [string]: { tamanho: { number }, centro: { number }, cor: Color3, ancoras: { [string]: { number } } } } =
	{
		pistola = {
			tamanho = { 0.058, 0.362, 0.582 },
			centro = { 0, 0.036, -0.204 },
			cor = Color3.fromRGB(35, 35, 40),
			ancoras = { Boca = { 0, 0.172, -0.494 }, Ejecao = { 0.029, 0.181, -0.204 }, Mira = { 0, 0.217, 0.029 } },
		},
		beretta = {
			tamanho = { 0.101, 0.404, 0.631 },
			centro = { 0, 0.057, -0.208 },
			cor = Color3.fromRGB(35, 35, 40),
			ancoras = { Boca = { 0.016, 0.202, -0.52 }, Ejecao = { 0.051, 0.218, -0.24 }, Mira = { 0, 0.258, 0.057 } },
		},
		faca = {
			tamanho = { 0.045, 0.189, 0.872 },
			centro = { 0, -0.055, -0.305 },
			cor = Color3.fromRGB(150, 150, 155),
			ancoras = { Boca = { 0, -0.034, -0.742 } },
		},
		peDeCabra = {
			tamanho = { 0.065, 0.31, 1.745 },
			centro = { 0, 0, 0 },
			cor = Color3.fromRGB(110, 60, 50),
			ancoras = { Boca = { 0, 0.024, -0.848 } },
		},
		machado = {
			tamanho = { 0.217, 0.837, 2.326 },
			centro = { 0, -0.1, -0.279 },
			cor = Color3.fromRGB(110, 80, 50),
			ancoras = { Boca = { 0, -0.376, -1.401 } },
		},
		ar15 = {
			tamanho = { 0.144, 0.708, 2.617 },
			centro = { 0, 0.142, -0.445 },
			cor = Color3.fromRGB(35, 35, 40),
			ancoras = {
				Boca = { 0, 0.251, -1.754 },
				Ejecao = { 0.072, 0.212, -0.183 },
				ApoioEsquerdo = { 0, 0.141, -0.968 },
				Mira = { 0, 0.495, -0.183 },
			},
		},
		carabinaM5 = {
			tamanho = { 0.213, 0.848, 2.094 },
			centro = { 0, 0.17, -0.356 },
			cor = Color3.fromRGB(35, 35, 40),
			ancoras = {
				Boca = { -0.002, 0.379, -1.375 },
				Ejecao = { 0.107, 0.254, -0.147 },
				ApoioEsquerdo = { 0, 0.17, -0.775 },
				Mira = { 0, 0.594, -0.147 },
			},
		},
		ak74 = {
			tamanho = { 0.141, 0.773, 2.742 },
			centro = { 0, 0.015, -0.494 },
			cor = Color3.fromRGB(80, 60, 40),
			ancoras = {
				Boca = { 0, 0.295, -1.792 },
				Ejecao = { 0.07, 0.093, -0.494 },
				ApoioEsquerdo = { 0, 0.108, -1.042 },
				Mira = { 0, 0.402, -0.494 },
			},
		},
		escopeta = {
			tamanho = { 0.337, 0.77, 3.053 },
			centro = { 0, 0, -1.13 },
			cor = Color3.fromRGB(70, 50, 35),
			ancoras = {
				Boca = { 0, 0.282, -2.636 },
				Ejecao = { 0.168, 0.231, -0.824 },
				ApoioEsquerdo = { 0, 0.092, -1.588 },
				Mira = { 0, 0.385, -1.13 },
			},
		},
		escopetaM1912 = {
			tamanho = { 0.129, 0.536, 2.937 },
			centro = { 0, 0.027, -0.587 },
			cor = Color3.fromRGB(70, 50, 35),
			ancoras = {
				Boca = { 0, 0.23, -2.007 },
				Ejecao = { 0.065, 0.188, -0.294 },
				ApoioEsquerdo = { 0, 0.08, -1.175 },
				Mira = { 0, 0.295, -0.587 },
			},
		},
		lancaFoguetes = {
			tamanho = { 0.201, 0.379, 2.763 },
			centro = { 0, 0.106, -1.022 },
			cor = Color3.fromRGB(60, 75, 55),
			ancoras = { Boca = { 0, 0.208, -2.404 }, ApoioEsquerdo = { 0, 0.151, -0.746 }, Mira = { 0, 0.295, -0.47 } },
		},
	}

local DIMENSAO_CABO = 0.2
local moldes: { [string]: { [string]: MeshPart } } = {} -- id -> nome da parte -> molde
local falhou: { [string]: boolean } = {}
local carregando: { [string]: boolean } = {}
local avisou: { [string]: boolean } = {}

-- Armas sem malha enviada que ganham um modelo de peças em vez do bloco único. Origem = empunhadura, ponta para -Z.
local PARTES_BLOCOS: { [string]: { { nome: string, tam: { number }, pos: { number }, cor: Color3, material: Enum.Material } } } =
	{
		faca = {
			{
				nome = "Cabo",
				tam = { 0.07, 0.1, 0.26 },
				pos = { 0, -0.03, 0 },
				cor = Color3.fromRGB(50, 45, 42),
				material = Enum.Material.Wood,
			},
			{
				nome = "Guarda",
				tam = { 0.06, 0.17, 0.04 },
				pos = { 0, -0.03, -0.15 },
				cor = Color3.fromRGB(95, 98, 102),
				material = Enum.Material.Metal,
			},
			{
				nome = "Lamina",
				tam = { 0.03, 0.14, 0.42 },
				pos = { 0, -0.02, -0.38 },
				cor = Color3.fromRGB(160, 165, 170),
				material = Enum.Material.Metal,
			},
			{
				nome = "Ponta",
				tam = { 0.03, 0.08, 0.15 },
				pos = { 0, -0.035, -0.66 },
				cor = Color3.fromRGB(160, 165, 170),
				material = Enum.Material.Metal,
			},
		},
	}

-- Ajuste visual por arma (só malha): escala = fator de tamanho; recuo = fração do comprimento que a malha avança (-Z) para a mão
-- segurar perto da ponta de trás em vez do meio.
local AJUSTE: { [string]: { escala: number, recuo: number, apoio: Vector3? } } = {
	peDeCabra = { escala = 1.6, recuo = 0.3 },
	-- apoio = deslocamento do ApoioEsquerdo (studs): a mão da frente segura por baixo do tubo, não por cima
	lancaFoguetes = { escala = 1, recuo = 0, apoio = Vector3.new(0, -0.15, 0) },
}

local function escalaDe(id: string): number
	local a = AJUSTE[id]
	return if a then a.escala else 1
end

local function deslocamentoDe(id: string, comprimento: number): Vector3
	local a = AJUSTE[id]
	return if a then Vector3.new(0, 0, -a.recuo * comprimento * a.escala) else Vector3.zero
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function vx(t: any): Vector3 -- {x,y,z} do Config
	return Vector3.new(t.x, t.y, t.z)
end

local function inerte(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
end

local function aviso(id: string, texto: string)
	if not avisou[id] then
		avisou[id] = true
		warn("[ArmaModelo] " .. id .. ": " .. texto)
	end
end

-- Armas do Gold Bright (Config/ArmasGB): a malha delas só existe no viewmodel de 1ª pessoa (client/ViewmodelGB). Na 3ª pessoa,
-- no chão do plano B e no viewmodel de blocos usam o modelo de uma arma nossa da mesma classe. Trocar quando houver malha própria.
local APELIDO: { [string]: string } = {
	tt33 = "pistola",
	ots20 = "beretta",
	mp5 = "carabinaM5",
	pp91 = "carabinaM5",
	sr3m = "ak74",
	ots48k = "ar15",
	rmb93 = "escopeta",
	toz34 = "escopetaM1912",
	canoChumbo = "peDeCabra",
}

local function base(id: string): string
	return APELIDO[id] or id
end

-- Baixa (yield) os moldes de uma arma. Seguro de chamar várias vezes e em paralelo.
function ArmaModelo.carregar(id: string)
	id = base(id)
	if moldes[id] or falhou[id] then
		return
	end
	if carregando[id] then
		while carregando[id] do
			task.wait()
		end
		return
	end
	local cfg = Malhas[id]
	if not cfg then
		falhou[id] = true
		return
	end
	carregando[id] = true
	local partes: { [string]: MeshPart } = {}
	local ok = true
	for _, p in cfg.partes do
		local sucesso, mp = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(p.malha), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if not sucesso then
			warn("[ArmaModelo] malha de " .. id .. "/" .. p.nome .. " não carregou: " .. tostring(mp))
			ok = false
			break
		end
		local molde = mp :: MeshPart
		molde.Name = p.nome
		molde.Size = vx(p.tamanho) * escalaDe(id) -- reescala a malha para o tamanho do manifesto (independe do fator de importação)
		if p.textura then
			molde.TextureID = p.textura
		end
		inerte(molde)
		partes[p.nome] = molde
	end
	carregando[id] = nil
	if ok then
		moldes[id] = partes
	else
		falhou[id] = true
	end
end

-- Baixa os moldes de todas as armas com malha (ou das ids dadas). Yield.
function ArmaModelo.precarregar(ids: { string }?)
	local lista = ids
	if not lista then
		lista = {}
		for id, cfg in Malhas do
			if cfg then
				table.insert(lista :: { string }, id)
			end
		end
	end
	local pendentes = #(lista :: { string })
	for _, id in lista :: { string } do
		task.spawn(function()
			ArmaModelo.carregar(id)
			pendentes -= 1
		end)
	end
	while pendentes > 0 do
		task.wait()
	end
end

function ArmaModelo.pronta(id: string): boolean
	return moldes[base(id)] ~= nil
end

-- Comprimento da arma em studs (0 se desconhecida).
function ArmaModelo.comprimento(id: string): number
	id = base(id)
	local cfg = Malhas[id]
	if cfg then
		return cfg.comprimento * escalaDe(id)
	end
	local p = PROVISORIO[id]
	return p and p.tamanho[3] or 0
end

local function anexo(cabo: Part, nome: string, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = nome
	a.Position = pos
	a.Parent = cabo
end

local function soldar(cabo: Part, parte: BasePart, pos: Vector3)
	parte.CFrame = cabo.CFrame * CFrame.new(pos)
	local s = Instance.new("WeldConstraint")
	s.Part0 = cabo
	s.Part1 = parte
	s.Parent = parte
	parte.Parent = cabo.Parent
end

function ArmaModelo.criar(id: string, opcoes: Opcoes?): Model
	local modelo = Instance.new("Model")
	modelo.Name = id
	id = base(id)
	local cabo = Instance.new("Part")
	cabo.Name = "Cabo"
	cabo.Size = Vector3.one * DIMENSAO_CABO
	cabo.Transparency = 1
	inerte(cabo)
	cabo.Parent = modelo
	modelo.PrimaryPart = cabo

	local cfg = Malhas[id]
	local molde = moldes[id]
	if molde and cfg and not (opcoes and opcoes.bloco) then
		for _, p in cfg.partes do
			local m = molde[p.nome]
			if m then
				soldar(cabo, m:Clone(), vx(p.posicao) * escalaDe(id) + deslocamentoDe(id, cfg.comprimento))
			end
		end
		for nome, pos in cfg.ancoras do
			local extra = if nome == "ApoioEsquerdo"
					and AJUSTE[id]
					and AJUSTE[id].apoio
				then AJUSTE[id].apoio :: Vector3
				else Vector3.zero
			anexo(cabo, nome, vx(pos) * escalaDe(id) + deslocamentoDe(id, cfg.comprimento) + extra)
		end
		return modelo
	end

	-- bloco provisório
	local prov = PROVISORIO[id]
	if cfg and not falhou[id] and not (opcoes and opcoes.bloco) then
		task.spawn(ArmaModelo.carregar, id) -- a próxima já vem com a malha
		aviso(id, "malha ainda não baixou; bloco provisório nesta vez")
	elseif not cfg then
		aviso(id, "sem malha enviada (Config/ArmasMalhas = false); bloco provisório")
	end
	if not prov then
		aviso(id, "arma desconhecida; bloco mínimo")
		return modelo
	end
	local feitas = PARTES_BLOCOS[id]
	if feitas then
		for _, d in feitas do
			local peca = Instance.new("Part")
			peca.Name = d.nome
			peca.Size = v3(d.tam)
			peca.Color = d.cor
			peca.Material = d.material
			inerte(peca)
			soldar(cabo, peca, v3(d.pos))
		end
		for nome, pos in prov.ancoras do
			anexo(cabo, nome, v3(pos))
		end
		return modelo
	end
	local bloco = Instance.new("Part")
	bloco.Name = "Bloco"
	bloco.Size = v3(prov.tamanho)
	bloco.Color = prov.cor
	bloco.Material = Enum.Material.Metal
	inerte(bloco)
	soldar(cabo, bloco, v3(prov.centro))
	for nome, pos in prov.ancoras do
		anexo(cabo, nome, v3(pos))
	end
	return modelo
end

task.defer(function()
	ArmaModelo.precarregar()
end)

return ArmaModelo
