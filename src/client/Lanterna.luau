-- Lanterna (cliente). Dono: S7. Números: Config/Lanterna; fórmulas: Regras/Lanterna. Só VISUAL; quem liga é o servidor
-- (Character.LanternaLigada) e o modelo no peito é montado pelo server/LanternaPeito.
-- 2026-11-16 (pedido do usuário; luz portada do Gold Bright, pesquisa/gold-bright.md §8):
--   * 1ª pessoa: a luz sai da CABEÇA (câmera): facho branco de 55° + miolo de 40° (o anel nítido), sombra no miolo, PointLight
--     curta que ilumina braços e arma. Ao ligar sobe LINEAR em `subida` s; apagar corta na hora (como no original).
--   * 3ª pessoa (o próprio jogador) e todos os outros: a luz sai da LENTE do modelo no peito.
--   * Animação de ligar/desligar em TODOS os personagens: a chave desliza (Motor6D BotaoJunta), a lente vira Neon branca e o
--     indicador vermelho acende, no mesmo ritmo da luz.
-- O cliente só PEDE (evento Lanterna, tecla F). A lanterna é silenciosa: nada aqui chama Ruido.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Lanterna"))
local CfgAparencia = require(Shared.Config:WaitForChild("Aparencia"))
local Malha = require(Shared.Config:WaitForChild("LanternaMalha"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Lanterna"))
local Luz = require(Shared.Regras:WaitForChild("Luz"))
local Teclas = require(script.Parent.Teclas)

local Lanterna = {}

local jogador = Players.LocalPlayer
local ALCANCE_MAX_LUZ = 60 -- o Roblox corta Range de luz em 60 studs

local nivel = 3 -- qualidade (0..3, a mesma do filtro). Abaixo de 2: sem sombra e sem a luz das mãos
local direcao: Regras.Vec? = nil

-- Luz da cabeça (1ª pessoa do próprio jogador)
local pasta: Folder
local parte: Part
-- As 3 luzes da cabeça NÃO são reaproveitadas: nascem ao acender e são destruídas ao apagar (`criarLuzesCabeca` /
-- `luzCabecaApagada`). Medido 2026-11-17 em Realistic: as luzes antigas, depois de muitas trocas de Enabled (piscar, apagar,
-- religar), passavam a NÃO iluminar parede a menos de ~15 studs (só o ambiente aparecia), enquanto uma SpotLight recém-criada
-- no mesmo lugar e com os mesmos números iluminava normal. Durante a falha (piscar) elas ficam Enabled e só o brilho vai a 0.
local paramsRaio = RaycastParams.new()
paramsRaio.FilterType = Enum.RaycastFilterType.Exclude
paramsRaio.IgnoreWater = true
local fatorDist = 1 -- Config/Lanterna.primeira.compensacao, suavizado
local externo: SpotLight? = nil
local interno: SpotLight? = nil
local maos: PointLight? = nil

-- Camadas da lente suja (Config/Lanterna.suja): cones finos desviados do eixo que acrescentam ou tiram luz do facho
type Suja = { luz: SpotLight, anexo: Attachment, brilho: number }
local sujasCabeca: { Suja } = {}

-- Estado por personagem (todos, inclusive o próprio): luz que sobe, chave, luzes da lente, falha em curso
type Estado = {
	k: number, -- 0..1 brilho (sobe linear, cai na hora)
	chave: number, -- 0..1 posição da chave
	anexo: Attachment?,
	ext: SpotLight?,
	int: SpotLight?,
	sujas: { Suja },
	semente: number,
	falhaSemente: number?, -- semente da última falha vista (LanternaFalhaSemente)
	padrao: Regras.PadraoFalha?, -- falha em curso (nil = nenhuma)
	falhaT: number, -- GetServerTimeNow do início da falha
}
local estados: { [Model]: Estado } = {}

local function cor3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function spot(c: { angulo: number, alcance: number, brilho: number }, nome: string, pai: Instance): SpotLight
	local s = Instance.new("SpotLight")
	s.Name = nome
	s.Face = Enum.NormalId.Front
	s.Angle = c.angulo
	s.Range = math.min(c.alcance, ALCANCE_MAX_LUZ)
	s.Color = cor3(Cfg.primeira.cor)
	s.Brightness = 0
	s.Shadows = false
	s.Enabled = false
	s.Parent = pai
	return s
end

-- No modo realista (LightingStyle = Realistic) uma luz perde o PRIMEIRO acender: fica só um halo e o núcleo forte do miolo não
-- aparece até a luz ser desligada e ligada de novo (medido no Studio 2026-11-17; religar com F "consertava"). Contorno: a 1ª vez
-- que cada luz acende, fica 1 quadro ligada, 3 desligadas e liga de vez, no início da subida (brilho ~0): ninguém vê.
local aquecimento: { [Light]: number } = setmetatable({}, { __mode = "k" }) :: any
local function ativar(luz: Light, ligada: boolean)
	if not ligada then
		luz.Enabled = false
		return
	end
	local n = (aquecimento[luz] or 0) + 1
	if n <= 6 then
		aquecimento[luz] = n
	end
	luz.Enabled = n == 1 or n >= 5
end

-- Cria as camadas de sujeira como filhas de `base` (cada uma num Attachment desviado de `cfLocal` por guinada/inclinação).
local function criarSujas(base: BasePart, cfLocal: CFrame): { Suja }
	local lista: { Suja } = {}
	for i, c in Cfg.suja do
		local a = Instance.new("Attachment")
		a.Name = "Suja" .. i
		a.CFrame = cfLocal * CFrame.Angles(math.rad(c.desvio[2]), math.rad(c.desvio[1]), 0)
		a.Parent = base
		local l = Instance.new("SpotLight")
		l.Name = "Suja"
		l.Face = Enum.NormalId.Front
		l.Angle = c.angulo
		l.Range = ALCANCE_MAX_LUZ
		l.Color = cor3(c.cor)
		l.Brightness = 0
		l.Shadows = false
		l.Enabled = false
		l.Parent = a
		table.insert(lista, { luz = l, anexo = a, brilho = c.brilho })
	end
	return lista
end

local function aplicarSujas(lista: { Suja }, f: number)
	local ligado = f > 0 and nivel >= 3
	for _, sj in lista do
		sj.luz.Brightness = sj.brilho * f
		ativar(sj.luz, ligado)
	end
end

local function criarLuzCabeca()
	pasta = Instance.new("Folder")
	pasta.Name = "Lanterna"
	parte = Instance.new("Part")
	parte.Name = "LanternaLuz"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false
	parte.Transparency = 1
	parte.Size = Vector3.new(0.2, 0.2, 0.2)
	parte.Parent = pasta
	sujasCabeca = criarSujas(parte, CFrame.identity)
end

-- Luzes novas, já Enabled, brilho 0 (a subida e as falhas mexem só no brilho).
local function criarLuzesCabeca()
	local e = spot(Cfg.primeira.externo, "Externo", parte)
	local i = spot(Cfg.primeira.interno, "Interno", parte)
	local m = Instance.new("PointLight")
	m.Name = "Maos"
	m.Range = Cfg.primeira.maos.alcance
	m.Color = cor3(Cfg.primeira.cor)
	m.Brightness = 0
	m.Shadows = false
	m.Parent = parte
	e.Enabled = true
	i.Enabled = true
	externo, interno, maos = e, i, m
end

-- Máscara de sujeira do facho (Config/Lanterna.cookie): ImageLabel preta com alfa, centrada onde o eixo do facho cai na tela.
local telaCookie: ScreenGui? = nil
local imagemCookie: ImageLabel? = nil

local function criarCookie()
	local c = Cfg.cookie
	if not c or c.imagem == "" then
		return
	end
	local pg = jogador:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "LanternaCookie"
	gui.DisplayOrder = 1 -- sob o HUD (10) e o viewmodel (5), sobre o filtro do mundo (-10); o filtro da tela (100) cobre tudo
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = pg
	local im = Instance.new("ImageLabel")
	im.Name = "Cookie"
	im.BackgroundTransparency = 1
	im.BorderSizePixel = 0
	im.Image = c.imagem
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.ImageColor3 = Color3.new(0, 0, 0)
	im.ImageTransparency = 1
	im.Active = false
	im.Parent = gui
	telaCookie = gui
	imagemCookie = im
end

-- f = fator da luz (0 = apagada). `posicao`/`dir` = origem e direção do facho (mundo). Esconde com f <= 0 ou qualidade baixa.
local function atualizarCookie(camera: Camera, f: number, posicao: Vector3?, dir: Vector3?)
	local gui, im = telaCookie, imagemCookie
	if not (gui and im) then
		return
	end
	local c = Cfg.cookie
	if f <= 0.001 or not posicao or not dir or nivel < c.minNivel then
		gui.Enabled = false
		return
	end
	local vp = camera.ViewportSize
	local ponto, frente = camera:WorldToViewportPoint(posicao + dir * 100)
	if not frente then
		gui.Enabled = false
		return
	end
	-- raio em pixels do círculo do cone: tan(meio ângulo) / tan(FOV vertical / 2) * metade da altura
	local raioPx = math.tan(math.rad(c.anguloTela / 2)) / math.tan(math.rad(camera.FieldOfView / 2)) * (vp.Y / 2)
	local lado = raioPx / c.raioImagem -- a borda do disco fica a raioImagem * largura do centro da imagem
	im.Size = UDim2.fromOffset(lado, lado)
	im.Position = UDim2.fromOffset(ponto.X, ponto.Y)
	im.ImageTransparency = 1 - math.clamp(c.forca * f, 0, 1)
	gui.Enabled = true
end

local function primeiraPessoa(personagem: Model?, camera: Camera): boolean
	local cabeca = personagem and personagem:FindFirstChild("Head")
	if not (cabeca and cabeca:IsA("BasePart")) then
		return false
	end
	return (camera.CFrame.Position - cabeca.Position).Magnitude < CfgAparencia.distanciaPrimeiraPessoa
end

local function fatorDia(): number
	local luzDia = math.clamp(Luz.luzDaHora(Lighting.ClockTime), 0, 1)
	return 1 - (1 - Cfg.fatorDia) * luzDia
end

-- Luzes da lente (criadas localmente no modelo de peito de cada personagem)
local function luzesLente(e: Estado, modelo: Model)
	local corpo = modelo:FindFirstChild("Corpo")
	if not (corpo and corpo:IsA("BasePart")) then
		return
	end
	if e.anexo and e.anexo.Parent == corpo then
		return
	end
	if e.anexo then
		e.anexo:Destroy()
	end
	for _, sj in e.sujas do
		sj.anexo:Destroy()
	end
	local esc = Cfg.peito.escala or 1
	local centroCorpo = v3(Malha.partes.Corpo.centro)
	local pos = (v3(Malha.lente.centro) - centroCorpo) * esc
	local normal = v3(Malha.lente.normal).Unit
	local a = Instance.new("Attachment")
	a.Name = "LanternaLuzLocal"
	-- a MeshPart do Corpo está girada `giroImportacao` (server/LanternaPeito): o anexo é posto no espaço dela
	local giro = if corpo:IsA("MeshPart")
		then CFrame.Angles(0, math.rad(Malha.giroImportacao or 0), 0)
		else CFrame.identity
	a.CFrame = giro:Inverse() * CFrame.lookAt(pos, pos + normal)
	a.Parent = corpo
	e.anexo = a
	e.ext = spot(Cfg.terceira.externo, "Externo", a)
	e.int = spot(Cfg.terceira.interno, "Interno", a)
	e.sujas = criarSujas(corpo, a.CFrame)
end

local function limparEstado(modelo: Model)
	local e = estados[modelo]
	if e and e.anexo then
		e.anexo:Destroy()
	end
	if e then
		for _, sj in e.sujas do
			sj.anexo:Destroy()
		end
	end
	estados[modelo] = nil
end

-- Chave, lente e indicador (todos os personagens)
local function animarModelo(modelo: Model, e: Estado, ligada: boolean, dt: number, pf: number)
	local cb = Cfg.peito.botao
	local alvo = if ligada then 1 else 0
	e.chave += math.clamp(alvo - e.chave, -dt / cb.tempo, dt / cb.tempo)
	local botao = modelo:FindFirstChild("Botao")
	local junta = botao and botao:FindFirstChild("BotaoJunta")
	if junta and junta:IsA("Motor6D") then
		local mb = Malha.botao
		local eixo = if mb then v3(mb.eixo) else Vector3.new(cb.eixo.x, cb.eixo.y, cb.eixo.z)
		local curso = (if mb then mb.curso else cb.curso) * (Cfg.peito.escala or 1)
		junta.Transform = CFrame.new(eixo.Unit * curso * e.chave) -- a malha vem DESLIGADA (fundo do trilho)
	end
	-- lente e indicador: acesos = cor Neon sem textura (a textura pinta por cima da cor); apagados = a textura original
	local function acender(nome: string, c: { corApagada: { number }, corAcesa: { number } }, f: number)
		local peca = modelo:FindFirstChild(nome)
		if not (peca and peca:IsA("BasePart")) then
			return
		end
		local acesa = f > 0.05
		if peca:IsA("MeshPart") then
			if peca:GetAttribute("TexturaOriginal") == nil then
				peca:SetAttribute("TexturaOriginal", peca.TextureID)
			end
			peca.TextureID = if acesa then "" else peca:GetAttribute("TexturaOriginal")
		end
		peca.Material = if acesa then Enum.Material.Neon else Enum.Material.SmoothPlastic
		peca.Color = cor3(c.corApagada):Lerp(cor3(c.corAcesa), f)
	end
	acender("Lente", Cfg.peito.lente, e.k * pf) -- pisca junto com a luz
	acender("Indicador", Cfg.peito.indicador, e.chave * pf)
end

local function vec3ToVec(v: Vector3): Regras.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Em 1ª pessoa o corpo de verdade continua na frente da câmera (só escondido para o dono) e corta o facho da cabeça com a
-- sombra dele (medido no Studio: o raio batia na própria mão). Enquanto a luz da cabeça está acesa, as peças do próprio
-- personagem não projetam sombra NESTE cliente; ao sair, volta como estava.
local semSombra: { [BasePart]: boolean } = {}
local function sombraCorpo(personagem: Model?, desligar: boolean)
	if desligar and personagem then
		for _, d in personagem:GetDescendants() do
			if d:IsA("BasePart") and semSombra[d] == nil then
				semSombra[d] = d.CastShadow
				d.CastShadow = false
			end
		end
	elseif not desligar and next(semSombra) then
		for peca, antes in semSombra do
			if peca.Parent then
				peca.CastShadow = antes
			end
		end
		table.clear(semSombra)
	end
end

local function luzCabecaApagada()
	for _, l in { externo, interno, maos } :: { Light? } do
		if l then
			l:Destroy()
		end
	end
	externo, interno, maos = nil, nil, nil
	aplicarSujas(sujasCabeca, 0)
end

local function passo(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- a peça da luz fica no WORKSPACE (só neste cliente): luz em peça filha da Camera não ilumina o mundo (medido 2026-11-16)
	if pasta.Parent ~= workspace then
		pasta.Parent = workspace
	end
	local dia = fatorDia()
	local t = os.clock()
	local completo = nivel >= 2
	local cabecaUsada = false

	-- todos os personagens com a lanterna no peito
	local vistos: { [Model]: boolean } = {}
	for _, p in Players:GetPlayers() do
		local personagem = p.Character
		local modelo = personagem and personagem:FindFirstChild("LanternaPeito")
		if not (personagem and modelo and modelo:IsA("Model")) then
			continue
		end
		vistos[modelo] = true
		local e = estados[modelo]
		if not e then
			e = { k = 0, chave = 0, semente = p.UserId % 100000, sujas = {}, falhaT = 0 }
			estados[modelo] = e
		end
		local ligada = personagem:GetAttribute("LanternaLigada") == true and p:GetAttribute("Morto") ~= true
		-- Gold Bright: sobe linear até o máximo em `subida` s; apagar corta na hora
		e.k = if ligada then math.min(1, e.k + dt / math.max(Cfg.subida, 0.01)) else 0

		-- falha em curso (decidida pelo servidor; todos derivam o mesmo padrão da semente)
		local semente = personagem:GetAttribute("LanternaFalhaSemente")
		if type(semente) == "number" and semente ~= e.falhaSemente then
			e.falhaSemente = semente
			local tipo = personagem:GetAttribute("LanternaFalhaTipo")
			local t0 = personagem:GetAttribute("LanternaFalhaT")
			e.padrao = Regras.padraoFalha(semente, if type(tipo) == "string" then tipo else "piscar")
			e.falhaT = if type(t0) == "number" then t0 else workspace:GetServerTimeNow()
		end
		local pf = 1
		if e.padrao then
			local decorrido = workspace:GetServerTimeNow() - e.falhaT
			-- "apagar" fica a 0 mais 0,6 s: o servidor apaga o atributo ao fim do padrão e a réplica leva um instante (sem clarão)
			if decorrido > e.padrao.duracao + 0.6 then
				e.padrao = nil
			else
				pf = Regras.fatorFalha(e.padrao, decorrido)
			end
		end
		animarModelo(modelo, e, ligada, dt, pf)

		local f = e.k * pf * Regras.cintilacao(t, e.semente, Cfg.cintilacao) * dia
		local daCabeca = p == jogador and primeiraPessoa(personagem, camera)
		if daCabeca then
			cabecaUsada = true
			-- sempre que o dono está em 1ª pessoa com a lanterna no peito, NÃO só com a luz acesa: o mapa de sombra do modo realista
			-- guarda a sombra do corpo de antes (medido: a 1ª vez após nascer saía fraca até apagar e acender de novo)
			sombraCorpo(personagem, true)
			-- 1ª pessoa: luz da cabeça; a da lente fica apagada
			if e.ext and e.int then
				ativar(e.ext, false)
				ativar(e.int, false)
			end
			aplicarSujas(e.sujas, 0)
			if e.k <= 0 then
				-- apagada de verdade: as luzes morrem (ver o comentário de `externo`)
				luzCabecaApagada()
				direcao = nil
				atualizarCookie(camera, 0, nil, nil)
			else
				-- acesa (mesmo no meio de uma piscada: aí só o brilho vai a 0, sem trocar Enabled)
				if not (externo and interno and maos) then
					criarLuzesCabeca()
				end
				local cf = camera.CFrame
				local d = Cfg.primeira.deslocamento
				local posicao = (cf * CFrame.new(d.x, d.y, d.z)).Position
				local alvo = vec3ToVec(cf.LookVector)
				direcao = if direcao then Regras.suavizarDirecao(direcao, alvo, dt, Cfg.meiaVidaDirecao) else alvo
				local dir = Vector3.new(direcao.x, direcao.y, direcao.z)
				parte.CFrame = CFrame.lookAt(posicao, posicao + dir)
				-- compensação pela distância da superfície no centro do facho (suavizada: sem salto ao passar por uma quina)
				local comp = Cfg.primeira.compensacao
				paramsRaio.FilterDescendantsInstances = { personagem, pasta }
				local hit = workspace:Raycast(posicao, dir * ALCANCE_MAX_LUZ, paramsRaio)
				local alvoDist = Regras.fatorDistancia(if hit then hit.Distance else nil, comp)
				fatorDist += (alvoDist - fatorDist) * (1 - 0.5 ^ (dt / math.max(comp.meiaVida, 0.001)))
				local ext, int, mao = externo :: SpotLight, interno :: SpotLight, maos :: PointLight
				ext.Brightness = Cfg.primeira.externo.brilho * f * fatorDist
				int.Brightness = Cfg.primeira.interno.brilho * f * fatorDist
				int.Shadows = Cfg.primeira.sombra and completo
				mao.Brightness = if completo then Cfg.primeira.maos.brilho * f else 0
				mao.Enabled = completo
				aplicarSujas(sujasCabeca, f)
				atualizarCookie(camera, f, posicao, dir)
			end
		else
			luzesLente(e, modelo)
			if e.ext and e.int then
				e.ext.Brightness = Cfg.terceira.externo.brilho * f
				ativar(e.ext, f > 0)
				e.int.Brightness = Cfg.terceira.interno.brilho * f
				e.int.Shadows = Cfg.terceira.sombra and completo
				ativar(e.int, f > 0 and completo)
			end
			aplicarSujas(e.sujas, f)
		end
	end
	if not cabecaUsada then
		sombraCorpo(nil, false)
		luzCabecaApagada()
		direcao = nil
		atualizarCookie(camera, 0, nil, nil)
	end
	for modelo in estados do
		if not vistos[modelo] then
			limparEstado(modelo)
		end
	end
end

-- Qualidade automática do filtro (0..3). Ninguém chama ainda: o orquestrador do Filtro não a expõe (docs/pendencias).
function Lanterna.qualidade(n: number)
	nivel = n
end

function Lanterna.iniciar()
	criarLuzCabeca()
	criarCookie()
	luzCabecaApagada()

	Teclas.ligar("lanterna", Cfg.teclas, function()
		local slot = jogador:GetAttribute("LanternaSlot")
		if type(slot) ~= "number" or jogador:GetAttribute("Morto") == true then
			return
		end
		local personagem = jogador.Character
		local ligada = personagem ~= nil and personagem:GetAttribute("LanternaLigada") == true
		Rede.evento("Lanterna"):FireServer(not ligada)
	end)

	-- depois da câmera do Roblox (Camera), da câmera dinâmica (Camera + 1) e antes do filtro (Camera + 5)
	RunService:BindToRenderStep("Lanterna", Enum.RenderPriority.Camera.Value + 3, passo)
end

return Lanterna
