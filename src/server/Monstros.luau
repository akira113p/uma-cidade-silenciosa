-- Monstros: monstros cegos que caçam pelo som. Nascem nos pontos "Monstro" do mapa, ouvem Ruido.aoRuido, deslizam sem
-- animação. Dono: P4. Contrato: docs/arquitetura.md §5 (Monstros) e §P4. Regra de percepção: Regras/Percepcao.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Monstros)
local ConfigSom = require(Shared.Config.Som)
local CfgAdmin = require(Shared.Config.Admin)
local Percepcao = require(Shared.Regras.Percepcao)
local Audicao = require(Shared.Regras.Audicao) -- audição por espécie (docs/som.md §6)
-- Rastejador/Wrapper (docs/rastejador.md, docs/wrapper.md): números por preset (Config/PresetsMonstro) e regras puras da espécie com `capacidades`.
local Presets = require(Shared.Config.PresetsMonstro) :: any
local MalhasCfg = require(Shared.Config.MonstrosMalhas)
local RegrasRast = require(Shared.Regras.Rastejador)
local Lunge = require(Shared.Regras.Lunge)
local Raizes = require(Shared.Raizes)
local RegrasHab = require(Shared.Regras.Habilidades)

local Monstros = {}

-- INTEGRACAO: números de execução da IA, ainda fora de Config/Monstros. Se o Config ganhar um bloco `ia`, ele vale
-- no lugar destes (ver docs/pendencias-integracao.md, seção P4).
local IA_PADRAO = {
	hz = 5, -- passes da IA por segundo
	lote = 25, -- monstros por frame dentro de um pass (espalha o custo)
	distanciaPausa = 700, -- studs; Calmo sem jogador mais perto que isto não processa
	distanciaRosnado = 100, -- studs; só rosna se houver jogador mais perto que isto
	rosnado = { 8, 20 }, -- s entre rosnados
	vagarTroca = { 4, 9 }, -- s até escolher outro ponto de vagar
	vagarDescanso = { 1, 4 }, -- s parado ao chegar no ponto de vagar
	chegou = 3, -- studs; distância que conta como "chegou"
	alvoMudou = 3, -- studs; o alvo precisa andar isto para recalcular o caminho
	caminhoDireto = 8, -- studs; mais perto que isto vai em linha reta, sem pathfinding
	calculosSimultaneos = 6, -- ComputeAsync em andamento ao mesmo tempo, no servidor todo
	travadoCada = 1.5, -- s entre checagens de "travado"
	travadoMinimo = 1, -- studs que precisa andar nesse intervalo
	raycastsPorFrame = 30, -- monstros com raycast de paredes por frame, por ruído
	tombar = 3, -- s do tombo até o modelo sumir
	renascer = 180, -- s da morte até renascer no mesmo ponto
	alturaAtaque = 4, -- studs além de metade da altura do monstro para o toque valer
	hipHeight = 0.1, -- altura do chão ao fundo do corpo do boneco de blocos
}
local IA = setmetatable((Config :: any).ia or {}, { __index = IA_PADRAO }) :: typeof(IA_PADRAO)

local random = Random.new()

type Dados = {
	modelo: Model,
	humanoid: Humanoid,
	hrp: BasePart,
	especie: any,
	nivel: number,
	vida: number,
	vivo: boolean,
	ponto: BasePart?,
	origem: Vector3,
	perc: any,
	estadoVisivel: string,
	atacando: boolean,
	ultimoGolpe: number,
	waypoints: { PathWaypoint }?,
	indice: number,
	alvoCaminho: Vector3?,
	ultimoCalculo: number,
	calculando: boolean,
	destinoVagar: Vector3?,
	proximaVagada: number,
	proximoRosnado: number,
	checkPos: Vector3,
	checkTempo: number,
	-- Só espécies com Config.especies[i].capacidades / malha (Rastejador). Nil nas outras.
	preset: any, -- Config/PresetsMonstro[especie.preset]; nil nas espécies sem capacidades
	cap: any, -- estado dos módulos MonstroObjetivo/Movimento/Arrombar
	acao: string?, -- última ação de animação mandada (Idle/Walk/Run/Attack/Death)
	golpeAte: number, -- os.clock até o fim da animação de golpe em curso
	clipe: string?, -- clipe a tocar no lugar de Attack enquanto golpeAte (WallSlam, Scream); nil = Attack
	lunge: any, -- Regras/Lunge.Maquina; só preset com golpe.tipo == "lunge" (Wrapper)
	-- Habilidades por espécie (docs/monstros/logica.md §2.3): estado em d.hab, controlado por server/Habilidades/<Especie>.
	id: number, -- único no servidor (a Florescida e as flores se acham por ele)
	hab: any,
	semGolpeNormal: boolean, -- a habilidade deste tick cuida do golpe: o toque normal não vale
	intervaloGolpe: number?, -- sobrepõe Config.niveis[nivel].intervaloGolpe (Corcunda com o jogador no chão)
	danoMult: number?, -- multiplica o dano do PRÓXIMO golpe normal (emboscada do Corcunda)
	alvoSonar: { jogador: Player, pos: Vector3, ate: number }?, -- Wrapper: onde a onda detectou alguém
	rumoLento: { alvo: Vector3? }?, -- Florescida: o Heartbeat gira o corpo até aqui (AutoRotate = false)
	filtroDestino: ((Vector3) -> boolean)?, -- vagar descarta destinos que devolvem false (Florescida: fora da cidade)
	-- soma ao limiar de audição (Regras/Audicao.Extra: grave/medio/agudo/chao em dB, ignorarAgachado); quem liga, desliga
	-- (Rastejador: Pulso; MonstroPS1: raspar)
	audicaoExtra: { grave: number?, medio: number?, agudo: number?, chao: number?, ignorarAgachado: boolean? }?,
}

local animar: (d: Dados, agora: number, reiniciar: boolean) -> () -- definida mais abaixo (ouvirSom já a usa)

local lista: { Dados } = {}
local porModelo: { [Instance]: Dados } = {}
local porId: { [number]: Dados } = {}
local proximoId = 0
local calculosEmAndamento = 0
local errosAvisados = 0
local iniciado = false

-- Serviços de outras partes: carregados sob demanda e em pcall (podem não existir durante o desenvolvimento).
local servicos: { [string]: any } = {}
local ausentes: { [string]: boolean } = {}
local function servico(nome: string): any
	local s = servicos[nome]
	if s then
		return s
	end
	if ausentes[nome] then
		return nil
	end
	local arquivo = script.Parent:FindFirstChild(nome)
	local ok, modulo = false, nil
	if arquivo then
		ok, modulo = pcall(require, arquivo)
	end
	if ok and modulo then
		servicos[nome] = modulo
		return modulo
	end
	ausentes[nome] = true
	warn("[Monstros] serviço indisponível: " .. nome .. (if arquivo then " (erro ao carregar)" else " (ausente)"))
	return nil
end

-- Preset da espécie (Config/PresetsMonstro[especie.preset]); só espécies com `capacidades` têm. Padrão: o do Rastejador.
-- Velocidades nativas dos clipes: as medidas pelo pipeline de animação (MonstrosMalhas[id].nativas, gerado) valem sobre as escritas no preset
-- (clipes refeitos em 2026-11-14 mudaram o passo: a Florescida corre a 59 studs/s no clipe, o preset dizia 38). Cópia por espécie, em cache.
local presetPorEspecie: { [string]: any } = {}

local function presetDe(especie: any): any?
	if not especie.capacidades then
		return nil
	end
	local cache = presetPorEspecie[especie.id]
	if cache then
		return cache
	end
	local base = Presets[especie.preset or "quadrupedeArrombador"]
	local m = MalhasCfg[especie.id]
	if not (base and m and m.nativas) then
		return base
	end
	local copia = table.clone(base)
	copia.animacao = table.clone(base.animacao or {})
	copia.animacao.nativas = table.clone(copia.animacao.nativas or {})
	for clipe, v in m.nativas do
		copia.animacao.nativas[clipe] = v
	end
	presetPorEspecie[especie.id] = copia
	return copia
end

-- Velocidade do estado: o preset tem a dele (preset.velocidade); as outras espécies seguem Config/Monstros.niveis.
local function velocidadeDe(especie: any, nivel: number, estado: string): number
	local preset = presetDe(especie)
	if preset then
		local v = RegrasRast.velocidade(estado, preset)
		if v then
			return v
		end
	end
	return Percepcao.velocidade(nivel, estado, Config)
end

local function pastaMonstros(): Folder
	local pasta = workspace:FindFirstChild("Monstros")
	if pasta and pasta:IsA("Folder") then
		return pasta
	end
	local nova = Instance.new("Folder")
	nova.Name = "Monstros"
	nova.Parent = workspace
	return nova
end

local function vec(v: Vector3): Percepcao.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function horizontal(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function estaVivo(jogador: Player): boolean
	if jogador:GetAttribute("Morto") == true then
		return false
	end
	local vida = servico("Vida")
	if vida and vida.estaVivo then
		return vida.estaVivo(jogador)
	end
	return true
end

-- Modelo -------------------------------------------------------------------------------------------------------

local function parteSolta(nome: string, tamanho: Vector3, cor: Color3, pai: Model): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamanho
	p.Color = cor
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = pai
	return p
end

local function soldar(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Boneco de blocos: corpo (HumanoidRootPart), cabeça sem rosto (cegos) e dois braços compridos.
local function montarBoneco(especie: any): Model
	local tx, ty, tz = especie.tamanho[1], especie.tamanho[2], especie.tamanho[3]
	local cor = Color3.fromRGB(especie.cor[1], especie.cor[2], especie.cor[3])
	local modelo = Instance.new("Model")
	modelo.Name = especie.id

	local alturaCorpo, alturaCabeca, alturaBraco = ty * 0.7, ty * 0.3, ty * 0.6
	local corpo = parteSolta("HumanoidRootPart", Vector3.new(tx, alturaCorpo, tz), cor, modelo)
	corpo.CFrame = CFrame.new(0, 0, 0)

	local cabeca = parteSolta("Cabeca", Vector3.new(tx * 0.7, alturaCabeca, tz * 0.7), cor, modelo)
	cabeca.CFrame = corpo.CFrame * CFrame.new(0, alturaCorpo / 2 + alturaCabeca / 2, 0)
	local braco1 = parteSolta("BracoE", Vector3.new(tx * 0.25, alturaBraco, tz * 0.25), cor, modelo)
	braco1.CFrame = corpo.CFrame * CFrame.new(-(tx / 2 + tx * 0.125), alturaCorpo / 2 - alturaBraco / 2, 0)
	local braco2 = parteSolta("BracoD", Vector3.new(tx * 0.25, alturaBraco, tz * 0.25), cor, modelo)
	braco2.CFrame = corpo.CFrame * CFrame.new(tx / 2 + tx * 0.125, alturaCorpo / 2 - alturaBraco / 2, 0)

	for _, p in { cabeca, braco1, braco2 } do
		p.CanCollide = false
		p.Massless = true
		soldar(corpo, p)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- o padrão é R6, que ignora HipHeight
	humanoid.HipHeight = IA.hipHeight
	humanoid.Parent = modelo
	modelo.PrimaryPart = corpo
	return modelo
end

-- Clona o modelo pronto de ServerStorage.Modelos.Monstros se existir e tiver Humanoid + HumanoidRootPart.
local function clonarModelo(especie: any): Model?
	local modelos = ServerStorage:FindFirstChild("Modelos")
	local pasta = modelos and modelos:FindFirstChild("Monstros")
	local molde = pasta and pasta:FindFirstChild(especie.modelo)
	if not (molde and molde:IsA("Model")) then
		return nil
	end
	local copia = molde:Clone()
	if not (copia:FindFirstChildOfClass("Humanoid") and copia:FindFirstChild("HumanoidRootPart")) then
		warn("[Monstros] modelo sem Humanoid/HumanoidRootPart, usando boneco: " .. especie.modelo)
		copia:Destroy()
		return nil
	end
	copia.Name = especie.id
	copia.PrimaryPart = copia:FindFirstChild("HumanoidRootPart") :: BasePart
	return copia
end

local function especiesAtivas(): { any }
	local r = {}
	for _, e in Config.especies do
		if (e.nivel <= Config.nivelAtivoMaximo or e.nascerSempre) and not e.semNascer then
			table.insert(r, e)
		end
	end
	return r
end

-- Cria e registra um monstro com o fundo do corpo em `chao` (0.5 stud acima, cai e assenta).
local function criar(especie: any, chao: Vector3, ponto: BasePart?): Dados?
	local nivelCfg = Config.niveis[especie.nivel]
	if not nivelCfg then
		warn("[Monstros] espécie sem nível configurado: " .. tostring(especie.id))
		return nil
	end
	-- espécie com malha: o molde montado por MonstroModelo (colisão em bloco + malha animada); sem ele, o boneco de hoje
	local mm = if especie.malha then servico("MonstroModelo") else nil
	local modelo = (mm and mm.clonar(especie.id)) or clonarModelo(especie) or montarBoneco(especie)
	local humanoid = modelo:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = modelo.PrimaryPart :: BasePart

	modelo:PivotTo(CFrame.new(chao) * CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0))
	local caixa, tamanho = modelo:GetBoundingBox()
	modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, chao.Y + 0.5 - (caixa.Position.Y - tamanho.Y / 2), 0))

	humanoid.WalkSpeed = velocidadeDe(especie, especie.nivel, "Calmo")
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	modelo:SetAttribute("Monstro", true)
	modelo:SetAttribute("Especie", especie.id)
	modelo:SetAttribute("Nivel", especie.nivel)
	modelo:SetAttribute("Estado", "Calmo")
	modelo:SetAttribute("Vida", nivelCfg.vida)
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	modelo.Parent = pastaMonstros()
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)

	local agora = os.clock()
	proximoId += 1
	local d: Dados = {
		modelo = modelo,
		humanoid = humanoid,
		hrp = hrp,
		especie = especie,
		nivel = especie.nivel,
		vida = nivelCfg.vida,
		vivo = true,
		ponto = ponto,
		origem = chao,
		perc = Percepcao.novo(agora),
		estadoVisivel = "Calmo",
		atacando = false,
		ultimoGolpe = -math.huge,
		waypoints = nil,
		indice = 1,
		alvoCaminho = nil,
		ultimoCalculo = -math.huge,
		calculando = false,
		destinoVagar = nil,
		proximaVagada = agora + random:NextNumber(0, IA.vagarTroca[2]), -- dessincroniza os monstros
		proximoRosnado = agora + random:NextNumber(IA.rosnado[1], IA.rosnado[2]),
		checkPos = hrp.Position,
		checkTempo = agora,
		preset = presetDe(especie),
		cap = if especie.capacidades then {} else nil,
		acao = nil,
		golpeAte = -math.huge,
		clipe = nil,
		lunge = if especie.capacidades and presetDe(especie).golpe.tipo == "lunge" then Lunge.novo() else nil,
		id = proximoId,
		hab = {},
		semGolpeNormal = false,
		intervaloGolpe = nil,
		danoMult = nil,
	}
	table.insert(lista, d)
	porModelo[modelo] = d
	porId[proximoId] = d
	local hab = servico("MonstroHabilidades")
	if hab then
		hab.iniciar(d)
	end
	return d
end

local function contarEspecie(id: string): number
	local n = 0
	for _, d in lista do
		if d.vivo and d.especie.id == id then
			n += 1
		end
	end
	return n
end

local function nascerNoPonto(ponto: BasePart)
	local ativas = especiesAtivas()
	if #ativas == 0 then
		warn("[Monstros] nenhuma espécie com nivel <= nivelAtivoMaximo")
		return
	end
	-- limite por espécie (maxPorServidor) e zona proibida (Florescida fora da cidade): só entra no sorteio quem pode nascer aqui
	local elegiveis = {}
	for _, e in ativas do
		local zonaOk = not (e.foraDaZona and ponto:GetAttribute("Zona") == e.foraDaZona)
		if zonaOk and RegrasHab.podeNascer(contarEspecie(e.id), e.maxPorServidor) then
			table.insert(elegiveis, e)
		end
	end
	if #elegiveis == 0 then
		return
	end
	local especie = elegiveis[random:NextInteger(1, #elegiveis)]
	criar(especie, ponto.Position - Vector3.new(0, ponto.Size.Y / 2, 0), ponto)
end

-- Ruído ---------------------------------------------------------------------------------------------------------

local paramsParedes = RaycastParams.new()
paramsParedes.FilterType = Enum.RaycastFilterType.Include
paramsParedes.IgnoreWater = true
local construcoesAtual: { Instance } = {}

-- Só as construções (Mapa e ZonaTeste) entram no filtro (Include): personagens e monstros ficam de fora sem precisar listá-los.
local function atualizarConstrucoes(): boolean
	local raizes = Raizes.obter("Construcoes")
	if not Raizes.iguais(raizes, construcoesAtual) then
		construcoesAtual = raizes
		paramsParedes.FilterDescendantsInstances = raizes
	end
	return #raizes > 0
end

-- Até maxParedes raycasts; cada acerto conta 1 e o raio segue do ponto atingido + 0.1 na mesma direção.
local function contarParedes(origem: Vector3, destino: Vector3): number
	local paredes = 0
	local pos = origem
	for _ = 1, ConfigSom.maxParedes do
		local dir = destino - pos
		if dir.Magnitude < 0.5 then
			break
		end
		local r = workspace:Raycast(pos, dir, paramsParedes)
		if not r then
			break
		end
		paredes += 1
		pos = r.Position + dir.Unit * 0.1
	end
	return paredes
end

local function gritar(d: Dados)
	-- preset.grito.db (Wrapper: 95 dB) ou o padrão de Config/Som
	local db = if d.preset and d.preset.grito then d.preset.grito.db else ConfigSom.acoes.gritoMonstro
	local sons = servico("Sons")
	if sons then
		sons.tocar("GritoMonstro", d.hrp, { db = db })
	end
	local ruido = servico("Ruido")
	if ruido then
		ruido.emitir(d.hrp.Position, db, "gritoMonstro", d.modelo)
	end
end

-- Aplica um som ao monstro e dispara o grito se ele entrou em Caça agora. `info` (opcional, vem do ruído real) = { tipo, db, jogador }:
-- as habilidades (aoOuvir) usam a transição de estado e, o Corcunda, o tipo do som para a memória de imitação. `banda`/`via` vêm da audição (docs/som.md §6.2).
local function ouvirSom(d: Dados, excesso: number, posicao: Vector3, agora: number, info: any?)
	local antes = d.perc.estado
	d.perc = Percepcao.ouvir(d.perc, excesso, vec(posicao), agora, Config)
	-- grito de rosnado do nível; o Wrapper não grita (usa o sonar: habilidades/Wrapper)
	if
		antes ~= "Caca"
		and d.perc.estado == "Caca"
		and Config.niveis[d.nivel].gritaAoCacar
		and not (d.preset and d.preset.semGrito)
	then
		task.spawn(gritar, d)
	end
	local hab = servico("MonstroHabilidades")
	if hab then
		hab.aoOuvir(d, {
			excesso = excesso,
			pos = posicao,
			agora = agora,
			antes = antes,
			depois = d.perc.estado,
			tipo = info and info.tipo,
			db = info and info.db,
			jogador = info and info.jogador,
			banda = info and info.banda, -- "grave" | "medio" | "agudo" | "chao" (Audicao.excesso)
			via = info and info.via, -- "ar" | "chao"
		})
	end
end

local function processarRuido(evento: any)
	-- imitação do Corcunda (logica.md §5.4): nenhum monstro reage, nem as flores
	if evento.tipo == "imitacao" then
		return
	end
	local Flores = servico("Flores")
	if Flores then
		pcall(Flores.aoRuido, evento) -- flor escuta por quem a plantou
	end
	-- evento de número único, sem bandas: plano
	if evento.bandas == nil then
		evento.bandas = { grave = evento.db, medio = evento.db, agudo = evento.db }
	end
	if evento.ambienteBandas == nil then
		local a = evento.ambiente
		evento.ambienteBandas = { grave = a, medio = a, agudo = a, chao = 0 }
	end
	local fonteJogador = typeof(evento.fonte) == "Instance" and (evento.fonte :: Instance):IsA("Player")
	local origem: Vector3 = evento.posicao
	local teto2 = ConfigSom.tetoAlcance * ConfigSom.tetoAlcance
	local fonteDados = if evento.fonte then porModelo[evento.fonte] else nil
	local temParedes = atualizarConstrucoes()

	local candidatos: { Dados } = {}
	for _, d in lista do
		if not d.vivo then
			continue
		end
		-- Monstro não ouve monstro de nível igual ou maior (senão o grito do nível 1 vira reação em cadeia).
		if fonteDados and fonteDados.nivel >= d.nivel then
			continue
		end
		local delta = d.hrp.Position - origem
		if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z > teto2 then
			continue
		end
		table.insert(candidatos, d)
	end

	local comRaycast = 0
	for _, d in candidatos do
		if not d.vivo then
			continue
		end
		local alvo = d.hrp.Position
		local distancia = (alvo - origem).Magnitude
		local dy = alvo.Y - origem.Y
		local perfil = Audicao.perfil(d.especie.id, d.nivel)
		local v = d.hrp.AssemblyLinearVelocity
		local atencao =
			Audicao.atencao(if d.atacando then "Ataque" else d.perc.estado, Vector3.new(v.X, 0, v.Z).Magnitude)
		-- Só paga raycast quem já ouviria sem paredes (paredes só diminuem o ar; o chão ignora parede).
		local excesso, banda = Audicao.excesso(evento, perfil, distancia, 0, dy, atencao, d.audicaoExtra)
		if excesso < 0 then
			continue
		end
		if temParedes and Audicao.precisaParedes(evento, perfil, distancia, dy, atencao, d.audicaoExtra) then
			local paredes = contarParedes(origem, alvo)
			if paredes > 0 then
				excesso, banda = Audicao.excesso(evento, perfil, distancia, paredes, dy, atencao, d.audicaoExtra)
			end
			comRaycast += 1
			if comRaycast % IA.raycastsPorFrame == 0 then
				task.wait()
			end
			if not d.vivo then
				continue
			end
		end
		if excesso >= 0 then
			-- Percepcao.estimar usa distância × erroPorDistancia: a distância "efetiva" carrega o erro da espécie e da banda (docs/som.md §3.7)
			local erroPadrao = Config.estados.erroPorDistancia
			local efetiva = Audicao.raioErro(distancia, perfil, banda, erroPadrao) / erroPadrao
			local estimada = Percepcao.estimar(vec(origem), efetiva, function()
				return random:NextNumber()
			end, Config)
			ouvirSom(d, excesso, Vector3.new(estimada.x, estimada.y, estimada.z), os.clock(), {
				tipo = evento.tipo,
				db = evento.db,
				jogador = fonteJogador,
				banda = banda,
				via = if banda == "chao" then "chao" else "ar",
			})
			if d.cap and d.especie.capacidades.veiculo then
				-- Rastejador: som de carro ouvido vira objetivo "veículo" (MonstroObjetivo); erro dele não derruba a IA
				local obj = servico("MonstroObjetivo")
				if obj then
					pcall(obj.somVeiculo, d, evento.tipo, origem, os.clock())
				end
			end
		end
	end
end

-- IA ------------------------------------------------------------------------------------------------------------

-- Move o monstro para `pos`. Florescida (rumoLento): só guarda o rumo; o Heartbeat de Habilidades/Florescida gira o corpo e anda.
local function irPara(d: Dados, pos: Vector3)
	if d.rumoLento then
		d.rumoLento.alvo = pos
	else
		d.humanoid:MoveTo(pos)
	end
end

local function parar(d: Dados)
	irPara(d, d.hrp.Position)
end

local function calcularCaminho(d: Dados, destino: Vector3, agora: number)
	d.calculando = true
	d.ultimoCalculo = agora
	d.alvoCaminho = destino
	calculosEmAndamento += 1
	task.spawn(function()
		local tamanho = d.hrp.Size
		local ok, path = pcall(function()
			local p = PathfindingService:CreatePath({
				AgentRadius = math.max(tamanho.X, tamanho.Z) / 2,
				-- Rastejador: altura real = fundo do corpo + bloco (HipHeight + Y), senão o caminho passa sob vãos onde ele não cabe
				AgentHeight = math.max(5, tamanho.Y, if d.cap then d.humanoid.HipHeight + tamanho.Y else 0),
				AgentCanJump = d.cap ~= nil, -- só o Rastejador salta (waypoint Jump: MonstroMovimento)
			})
			p:ComputeAsync(d.hrp.Position, destino)
			return p
		end)
		calculosEmAndamento -= 1
		d.calculando = false
		if not d.vivo or not d.hrp.Parent then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			d.waypoints = path:GetWaypoints()
			d.indice = 2 -- o primeiro waypoint é onde ele já está
		else
			d.waypoints = nil -- sem caminho: vai em linha reta
		end
		if d.cap then
			-- guarda o resultado para MonstroArrombar (Regras.precisaArrombar): estado, comprimento do caminho e alvo
			local comp = 0
			local wps = d.waypoints
			if wps then
				for i = 2, #wps do
					comp += (wps[i].Position - wps[i - 1].Position).Magnitude
				end
			end
			d.cap.caminho = {
				estado = if ok then path.Status.Name else "NoPath",
				comprimento = comp,
				alvo = destino,
			}
		end
	end)
end

local function seguirAlvo(d: Dados, alvo: Vector3, agora: number)
	local pos = d.hrp.Position
	local distAlvo = horizontal(alvo - pos)
	if distAlvo <= IA.chegou then
		parar(d)
		return
	end

	local alvoCaminho = d.alvoCaminho
	local mudou = alvoCaminho == nil or (alvo - alvoCaminho).Magnitude > IA.alvoMudou
	if mudou and not d.calculando and agora - d.ultimoCalculo >= Config.recalcularCaminhoMin then
		if distAlvo <= IA.caminhoDireto then
			d.waypoints = nil
			d.alvoCaminho = alvo
		elseif calculosEmAndamento < IA.calculosSimultaneos then
			calcularCaminho(d, alvo, agora)
		end
	end

	local wps = d.waypoints
	if not wps then
		irPara(d, alvo)
		return
	end
	local raio = math.max(IA.chegou, d.humanoid.WalkSpeed * 0.25)
	local i = d.indice
	while i <= #wps do
		if horizontal(wps[i].Position - pos) < raio then
			i += 1
		else
			break
		end
	end
	d.indice = i
	if d.cap and i <= #wps and wps[i].Action == Enum.PathWaypointAction.Jump then
		local mov = servico("MonstroMovimento")
		if mov then
			pcall(mov.saltarPara, d, wps[i].Position)
		end
	end
	irPara(d, if i > #wps then alvo else wps[i].Position)
end

local function vagar(d: Dados, agora: number)
	local pos = d.hrp.Position
	local destino = d.destinoVagar
	if destino and horizontal(destino - pos) < IA.chegou then
		d.destinoVagar = nil
		d.proximaVagada = agora + random:NextNumber(IA.vagarDescanso[1], IA.vagarDescanso[2])
		return
	end
	if agora >= d.proximaVagada then
		local angulo = random:NextNumber(0, 2 * math.pi)
		local raio = random:NextNumber(0.3, 1) * Config.estados.raioVagar
		destino = d.origem + Vector3.new(math.cos(angulo) * raio, 0, math.sin(angulo) * raio)
		if d.filtroDestino and not d.filtroDestino(destino) then
			destino = nil -- destino proibido (Florescida na cidade): fica parada e tenta outro depois
		end
		d.destinoVagar = destino
		d.proximaVagada = agora + random:NextNumber(IA.vagarTroca[1], IA.vagarTroca[2])
	end
	if destino then
		irPara(d, Vector3.new(destino.X, pos.Y, destino.Z))
	end
end

local function aplicarEstadoVisivel(d: Dados, estado: string)
	if estado == d.estadoVisivel then
		return
	end
	d.estadoVisivel = estado
	d.modelo:SetAttribute("Estado", estado)
	d.humanoid.WalkSpeed = velocidadeDe(d.especie, d.nivel, estado)
end

-- Animação (só espécies com malha): escolhe a ação pela regra pura e manda para MonstroModelo (Animator no servidor).
-- Atributos Acao/AcaoT ficam no modelo para o plano B (cliente) e para depuração.
function animar(d: Dados, agora: number, reiniciar: boolean)
	local mm = servico("MonstroModelo")
	if not mm then
		return
	end
	local v = horizontal(d.hrp.AssemblyLinearVelocity)
	local acao = RegrasRast.acao(d.estadoVisivel, agora < d.golpeAte, false, v, false, d.preset)
	if acao == "Attack" and d.clipe then
		acao = d.clipe -- WallSlam/Scream do Wrapper no lugar do Attack
	end
	if acao ~= d.acao or reiniciar or acao == "Walk" or acao == "Run" then
		if acao ~= d.acao or reiniciar then
			d.modelo:SetAttribute("Acao", acao)
			d.modelo:SetAttribute("AcaoT", workspace:GetServerTimeNow())
		end
		d.acao = acao
		mm.tocar(d.modelo, d.especie.id, acao, v, reiniciar, d.preset)
	end
end

-- Clipes de ação (docs/monstros/logica.md §2.4). Duração: o clipe em MonstrosMalhas (`duracao`), senão `padrao`, senão 1 s;
-- `forcar` impõe a duração (clipes em laço: Emboscada, Arrancada). Devolve a duração. O dano de qualquer golpe cai em agora + evento().
local function tocarAcao(d: Dados, clipe: string, agora: number, padrao: number?, forcar: number?): number
	local m = MalhasCfg[d.especie.id]
	local dur = forcar or (m and m.duracao and m.duracao[clipe]) or padrao or 1
	d.clipe = clipe
	d.golpeAte = agora + dur
	if d.especie.malha then
		animar(d, agora, true)
	end
	return dur
end

-- Tempo (s) de um evento do clipe (impacto, soltar, onda...) vindo do manifesto de animação; `padrao` quando falta.
local function evento(d: Dados, clipe: string, nome: string, padrao: number): number
	local m = MalhasCfg[d.especie.id]
	local e = m and m.eventos and m.eventos[clipe]
	return (e and e[nome]) or padrao
end

-- Volta ao Calmo (a habilidade desistiu: busca acabou, emboscada acabou, Florescida desistiu na borda da cidade).
local function acalmar(d: Dados, agora: number)
	d.perc = Percepcao.novo(agora)
	d.destinoVagar = nil
	d.proximaVagada = agora
	d.waypoints = nil
	d.alvoCaminho = nil
end

-- Golpe com malha: a animação de Attack começa agora e o dano cai em `atrasoImpacto` (quadro de impacto do clipe).
-- Se o jogador saiu do alcance até lá, o golpe erra.
local function golpeComAnimacao(d: Dados, alvo: Player, agora: number)
	d.clipe = nil
	-- a pose de golpe dura o clipe inteiro ou o intervalo entre golpes (o que for maior): sem piscar para Run entre dois golpes
	d.golpeAte = agora
		+ math.max(
			MalhasCfg[d.especie.id] and MalhasCfg[d.especie.id].duracao.Attack or 1,
			d.intervaloGolpe or Config.niveis[d.nivel].intervaloGolpe
		)
	animar(d, agora, true)
	local mult = d.danoMult or 1 -- emboscada do Corcunda: o golpe seguinte ao empurrão vale dobrado
	d.danoMult = nil
	task.delay(evento(d, "Attack", "impacto", d.preset.golpe.atrasoImpacto), function()
		if not d.vivo then
			return
		end
		local char = alvo.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) or not estaVivo(alvo) then
			return
		end
		local delta = hrp.Position - d.hrp.Position
		if horizontal(delta) > Config.estados.distanciaAtaque + 2 then
			return -- saiu do alcance antes do impacto: erra
		end
		local vida = servico("Vida")
		if vida then
			vida.dano(alvo, nil, Config.niveis[d.nivel].dano * mult, {
				tipo = "monstro",
				direcao = if delta.Magnitude > 0 then delta.Unit else nil,
			})
		end
	end)
end

-- Capacidades do Rastejador (docs/rastejador.md §5): módulos carregados uma vez; erro neles não derruba a IA (pcall + warn limitado).
local capMods: { objetivo: any?, movimento: any?, arrombar: any? }? = nil
local function capModulos()
	if capMods then
		return capMods
	end
	local mods = {
		objetivo = servico("MonstroObjetivo"),
		movimento = servico("MonstroMovimento"),
		arrombar = servico("MonstroArrombar"),
	}
	local ctx = { servico = servico, animar = animar, arrombar = mods.arrombar, tocarAcao = tocarAcao, evento = evento }
	for _, m in { mods.objetivo, mods.arrombar } do
		if m then
			m.configurar(ctx)
		end
	end
	capMods = mods
	return mods
end

local function capChamar(fn: any, ...: any): any
	if not fn then
		return nil
	end
	local ok, r = pcall(fn, ...)
	if not ok then
		if errosAvisados < 5 then
			errosAvisados += 1
			warn("[Monstros] erro em módulo do Rastejador: " .. tostring(r))
		end
		return nil
	end
	return r
end

-- Impacto da investida (Wrapper, docs/wrapper.md §2): chamado `golpe.atrasoImpacto` s depois do início do Attack. A máquina de
-- Regras/Lunge decide se acerta (alvo a <= alcanceImpacto); a parte vem da tabela do preset (sem braços). Servidor decide o dano.
local function impactoLunge(d: Dados, alvo: Player)
	if not d.vivo then
		return
	end
	local char = alvo.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local alvoOk = hrp ~= nil and hrp:IsA("BasePart") and estaVivo(alvo)
	local delta = if alvoOk then (hrp :: BasePart).Position - d.hrp.Position else nil
	local dist = if delta then horizontal(delta) else math.huge
	local ev, acertou = Lunge.passo(d.lunge, os.clock(), dist, d.preset)
	if ev ~= "impacto" or not acertou or not delta then
		return
	end
	local vida = servico("Vida")
	if vida then
		local parte = Lunge.sortearParte(d.preset.sorteioParte, function()
			return random:NextNumber()
		end)
		vida.dano(alvo, parte, d.preset.golpe.dano, {
			tipo = "monstro",
			direcao = if delta.Magnitude > 0 then delta.Unit else nil,
		})
	end
end

-- Um passo da máquina de investida. Devolve a fase depois do passo. Aproximar -> Lunge (para de andar, Attack, avança `avanco`)
-- -> Recuperar (parado, vulnerável) -> Aproximar. `alvo` = jogador mais perto atacável (ou nil).
local function passoLunge(d: Dados, agora: number, alvo: { jogador: Player, pos: Vector3 }?, distAlvo: number): string
	local m = d.lunge
	local delta = if alvo then alvo.pos - d.hrp.Position else nil
	local alcanca = delta ~= nil and math.abs(delta.Y) <= d.hrp.Size.Y / 2 + IA.alturaAtaque
	-- na fase Lunge quem fecha é o task.delay do impacto; o passo só entra como rede de segurança se o delay falhar
	if m.fase == "Lunge" and agora < m.ate + 0.3 then
		return m.fase
	end
	local ev = Lunge.passo(m, agora, if alcanca then distAlvo else math.huge, d.preset)
	if ev == "iniciar" and alvo and delta then
		d.ultimoGolpe = agora
		d.clipe = nil
		local clip = MalhasCfg[d.especie.id]
		d.golpeAte = agora
			+ math.max(clip and clip.duracao and clip.duracao.Attack or 0, d.preset.golpe.atrasoImpacto + 0.1)
		animar(d, agora, true)
		local dir = if horizontal(delta) > 0.1 then Vector3.new(delta.X, 0, delta.Z).Unit else d.hrp.CFrame.LookVector
		d.humanoid:MoveTo(d.hrp.Position + dir * d.preset.golpe.avanco)
		local jogador = alvo.jogador
		task.delay(d.preset.golpe.atrasoImpacto, function()
			local ok, erro = pcall(impactoLunge, d, jogador)
			if not ok and errosAvisados < 5 then
				errosAvisados += 1
				warn("[Monstros] erro no impacto do lunge: " .. tostring(erro))
			end
		end)
		ouvirSom(d, Config.estados.investigaAte, alvo.pos, agora) -- sentiu o jogador: caça a posição dele
	end
	return m.fase
end

local function passoMonstro(d: Dados, agora: number, jogadores: { { jogador: Player, pos: Vector3 } })
	local pos = d.hrp.Position

	local maisPerto, distPerto2 = nil, math.huge
	for _, j in jogadores do
		local delta = j.pos - pos
		local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
		if d2 < distPerto2 then
			maisPerto, distPerto2 = j, d2
		end
	end
	local distPerto = math.sqrt(distPerto2)

	-- Pausa de economia: Calmo e longe de todo mundo não gasta nada.
	if d.perc.estado == "Calmo" and not d.atacando and distPerto > IA.distanciaPausa then
		return
	end

	local antes = d.perc.estado
	d.perc = Percepcao.tick(d.perc, agora, Config)
	if antes ~= "Calmo" and d.perc.estado == "Calmo" then
		d.destinoVagar = nil
		d.proximaVagada = agora
		d.waypoints = nil
		d.alvoCaminho = nil
	end

	-- Habilidades da espécie (logica.md §2.3): antes do golpe normal e do movimento. true = tomaram o controle do movimento.
	local hab = servico("MonstroHabilidades")
	local controlou = false
	if hab then
		controlou = hab.passo(d, agora, { jogadores = jogadores, maisPerto = maisPerto, distPerto = distPerto })
	end

	-- Ataque: toque em jogador vivo a <= distanciaAtaque, em qualquer estado.
	local atacando = false
	if maisPerto then
		local delta = maisPerto.pos - pos
		atacando = horizontal(delta) <= Config.estados.distanciaAtaque
			and math.abs(delta.Y) <= d.hrp.Size.Y / 2 + IA.alturaAtaque
		if d.semGolpeNormal then
			atacando = false -- a habilidade cuida do golpe (Florescida, clipe de ação em curso)
		end
		if atacando and d.cap then
			-- jogador dentro de carro com vidros inteiros não é alvo: o Rastejador bate no carro (MonstroObjetivo)
			local mods = capModulos()
			atacando = capChamar(mods.objetivo and mods.objetivo.atacavel, maisPerto.jogador) ~= false
		end
		if d.lunge then
			atacando = false -- Wrapper: o golpe é a máquina de investida (abaixo), não o toque
		end
		if atacando and agora - d.ultimoGolpe >= (d.intervaloGolpe or Config.niveis[d.nivel].intervaloGolpe) then
			d.ultimoGolpe = agora
			local feito = hab ~= nil and hab.aoGolpear(d, maisPerto.jogador, agora) -- empurrão do Corcunda, golpe duplo do MonstroPS1
			if feito then
				d.ultimoGolpe = agora
			elseif d.especie.malha then
				golpeComAnimacao(d, maisPerto.jogador, agora) -- dano atrasado até o impacto do clipe
			else
				local vida = servico("Vida")
				if vida then
					vida.dano(maisPerto.jogador, nil, Config.niveis[d.nivel].dano, {
						tipo = "monstro",
						direcao = if delta.Magnitude > 0 then delta.Unit else nil,
					})
				end
			end
			-- sentiu o jogador: caça a posição dele
			ouvirSom(d, Config.estados.investigaAte, maisPerto.pos, agora)
		end
	end
	local lungeFase = "Aproximar"
	if d.lunge then
		local alvoL = nil
		if maisPerto then
			local mods = capModulos()
			if capChamar(mods.objetivo and mods.objetivo.atacavel, maisPerto.jogador) ~= false then
				alvoL = maisPerto
			end
		end
		-- Sonar (logica.md §4.2): ele lembra ONDE a onda bateu; chegando lá investe mesmo que o jogador tenha saído (o dano confere a
		-- posição real no impacto)
		local sonar = d.alvoSonar
		if RegrasHab.alvoSonarValido(sonar, agora) and sonar then
			if not alvoL or horizontal(sonar.pos - pos) < horizontal(alvoL.pos - pos) then
				alvoL = { jogador = sonar.jogador, pos = sonar.pos }
			end
		else
			d.alvoSonar = nil
		end
		if d.semGolpeNormal and d.lunge.fase == "Aproximar" then
			alvoL = nil -- sonar em curso: não inicia investida
		end
		local faseAntes = d.lunge.fase
		lungeFase = passoLunge(d, agora, alvoL, if alvoL then horizontal(alvoL.pos - pos) else math.huge)
		if faseAntes == "Aproximar" and d.lunge.fase == "Lunge" then
			d.alvoSonar = nil -- começou a investida
		end
		atacando = lungeFase ~= "Aproximar"
	end
	d.atacando = atacando
	aplicarEstadoVisivel(d, if atacando then "Ataque" else d.perc.estado)

	-- Rastejador: objetivo físico (veículo ruidoso, parede a arrombar). Só com monstro ativo e jogador a <= distanciaAtiva.
	local obj: any = nil
	local ativoCap = d.cap ~= nil and distPerto <= d.preset.objetivo.distanciaAtiva
	if ativoCap and not atacando and not controlou and (d.perc.estado ~= "Calmo" or d.cap.veiculo or d.cap.parede) then
		local mods = capModulos()
		obj = capChamar(
			mods.objetivo and mods.objetivo.passo,
			d,
			agora,
			d.perc,
			if maisPerto then maisPerto.pos else nil,
			distPerto
		)
	end

	if not controlou and d.lunge and lungeFase ~= "Aproximar" then
		if lungeFase == "Recuperar" then
			parar(d) -- parado e vulnerável: a janela de fuga do jogador
		end -- (na fase Lunge o MoveTo de `avanco` já foi dado em passoLunge)
	elseif controlou then
		-- a habilidade dirige o movimento neste tick
		d.atacando = atacando
	elseif atacando and maisPerto then
		irPara(d, maisPerto.pos)
	elseif obj then
		if obj.direto then
			irPara(d, obj.alvo) -- alinhando com um buraco: sem o "chegou" de 3 studs do seguirAlvo
		else
			seguirAlvo(d, obj.alvo, agora)
		end
	elseif d.perc.estado == "Calmo" then
		vagar(d, agora)
	else
		local a = d.perc.alvo
		if a then
			seguirAlvo(d, Vector3.new(a.x, a.y, a.z), agora)
		end
	end

	-- Rastejador: sonda de degrau/salto (acima do que o Humanoid sobe andando), só em movimento ativo.
	if ativoCap and (d.perc.estado ~= "Calmo" or atacando) then
		local mods = capModulos()
		capChamar(mods.movimento and mods.movimento.sondar, d, agora)
	end

	-- Travado (parede, quina): refaz o caminho ou escolhe outro ponto de vagar.
	-- Rastejador: escalonado (salto, recalcula, parede) em MonstroMovimento.travado.
	if agora - d.checkTempo >= IA.travadoCada then
		if (pos - d.checkPos).Magnitude < IA.travadoMinimo and d.humanoid.MoveDirection.Magnitude > 0.1 then
			if d.cap then
				local mods = capModulos()
				capChamar(mods.movimento and mods.movimento.travado, d, agora)
			else
				d.alvoCaminho = nil
				d.waypoints = nil
				d.destinoVagar = nil
				d.proximaVagada = agora
			end
		elseif d.cap then
			local mods = capModulos()
			capChamar(mods.movimento and mods.movimento.andou, d)
		end
		d.checkPos = pos
		d.checkTempo = agora
	end

	if d.especie.malha then
		animar(d, agora, false)
	end

	-- Rosnado ocasional, só se alguém está perto para ouvir (cada um é uma instância Sound).
	if agora >= d.proximoRosnado then
		d.proximoRosnado = agora + random:NextNumber(IA.rosnado[1], IA.rosnado[2])
		local sons = servico("Sons")
		if sons and distPerto <= IA.distanciaRosnado then
			sons.tocar("RosnadoMonstro", d.hrp)
		end
	end
end

local function jogadoresVivos(): { { jogador: Player, pos: Vector3 } }
	local r = {}
	for _, j in Players:GetPlayers() do
		local char = j.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") and estaVivo(j) then
			table.insert(r, { jogador = j, pos = hrp.Position })
		end
	end
	return r
end

local function compactar()
	local n = 0
	for i = 1, #lista do
		local d = lista[i]
		if d.vivo and d.hrp.Parent then
			n += 1
			lista[n] = d
		else
			if d.vivo then
				d.vivo = false -- destruído por fora: some do registro e renasce
				porModelo[d.modelo] = nil
				porId[d.id] = nil
				local hab = servico("MonstroHabilidades")
				if hab then
					hab.aoMorrer(d)
				end
				local ponto = d.ponto
				if ponto then
					task.delay(IA.renascer, function()
						if ponto.Parent then
							nascerNoPonto(ponto)
						end
					end)
				end
			end
		end
	end
	for i = #lista, n + 1, -1 do
		lista[i] = nil
	end
end

local function laco()
	local periodo = 1 / IA.hz
	while true do
		local inicio = os.clock()
		compactar()
		local jogadores = jogadoresVivos()
		local snapshot = table.clone(lista)
		for i, d in snapshot do
			if d.vivo then
				local ok, erro = pcall(passoMonstro, d, os.clock(), jogadores)
				if not ok and errosAvisados < 5 then
					errosAvisados += 1
					warn("[Monstros] erro na IA: " .. tostring(erro))
				end
			end
			if i % IA.lote == 0 then
				task.wait()
			end
		end
		local sobra = periodo - (os.clock() - inicio)
		task.wait(math.max(sobra, 0.03))
	end
end

-- Morte ---------------------------------------------------------------------------------------------------------

-- Sem animação: deita o modelo de lado mantendo o fundo no chão.
local function tombar(modelo: Model)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	local antes, tamAntes = modelo:GetBoundingBox()
	local fundo = antes.Position.Y - tamAntes.Y / 2
	modelo:PivotTo(modelo:GetPivot() * CFrame.Angles(0, 0, math.pi / 2))
	local depois, tamDepois = modelo:GetBoundingBox()
	modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, fundo - (depois.Position.Y - tamDepois.Y / 2), 0))
end

-- Morte sem clipe Death (Wrapper): tomba 90 graus em `duracao` s por Tween, fundo no chão, e congela. Mesmo destino de `tombar`.
local function tombarTween(modelo: Model, duracao: number)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	local inicial = modelo:GetPivot()
	local antes, tamAntes = modelo:GetBoundingBox()
	local fundo = antes.Position.Y - tamAntes.Y / 2
	modelo:PivotTo(inicial * CFrame.Angles(0, 0, math.pi / 2))
	local depois, tamDepois = modelo:GetBoundingBox()
	local final = modelo:GetPivot() + Vector3.new(0, fundo - (depois.Position.Y - tamDepois.Y / 2), 0)
	modelo:PivotTo(inicial)
	local valor = Instance.new("CFrameValue")
	valor.Value = inicial
	valor.Changed:Connect(function(cf)
		if modelo.Parent then
			modelo:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(valor, TweenInfo.new(duracao, Enum.EasingStyle.Quad), { Value = final })
	tween.Completed:Connect(function()
		valor:Destroy()
	end)
	tween:Play()
end

local function morrer(d: Dados)
	d.vivo = false
	porId[d.id] = nil
	local hab = servico("MonstroHabilidades")
	if hab then
		hab.aoMorrer(d) -- Florescida: as flores murcham
	end
	d.humanoid.WalkSpeed = 0
	d.humanoid:MoveTo(d.hrp.Position)
	d.modelo:SetAttribute("Vida", 0)
	local mm = if d.especie.malha then servico("MonstroModelo") else nil
	local malha = MalhasCfg[d.especie.id]
	local clipeDeath = malha and malha.animacoes and malha.animacoes.Death
	if mm and d.preset and d.preset.morte and not clipeDeath then
		-- sem clipe Death no modelo: para os clipes e tomba por Tween (com o Death novo do Wrapper cai no ramo do clipe)
		d.modelo:SetAttribute("Acao", "Death")
		d.modelo:SetAttribute("AcaoT", workspace:GetServerTimeNow())
		pcall(mm.parar, d.modelo)
		pcall(tombarTween, d.modelo, d.preset.morte.tombar)
	elseif mm then
		-- com malha: toca o clipe Death (fica na pose final) em vez de tombar o modelo
		d.modelo:SetAttribute("Acao", "Death")
		d.modelo:SetAttribute("AcaoT", workspace:GetServerTimeNow())
		pcall(mm.tocar, d.modelo, d.especie.id, "Death", 0, true, d.preset)
		pcall(mm.congelar, d.modelo)
	else
		pcall(tombar, d.modelo)
	end
	local modelo, ponto = d.modelo, d.ponto
	task.delay(IA.tombar, function()
		porModelo[modelo] = nil
		modelo:Destroy()
	end)
	if ponto then
		task.delay(IA.renascer, function()
			if ponto.Parent then
				nascerNoPonto(ponto)
			end
		end)
	end
end

-- API pública -----------------------------------------------------------------------------------------------------

-- Tira vida do monstro. Quem atacou (jogador) vira o alvo: o monstro entra em Caça na posição dele.
function Monstros.dano(modelo: Model, valor: number, atacante: Player?)
	local d = porModelo[modelo]
	if not d or not d.vivo or type(valor) ~= "number" or valor ~= valor or valor <= 0 then
		return
	end
	d.vida = math.max(0, d.vida - valor)
	modelo:SetAttribute("Vida", d.vida)
	if d.vida <= 0 then
		morrer(d)
		return
	end
	local hrpAtacante = atacante and atacante.Character and atacante.Character:FindFirstChild("HumanoidRootPart")
	if hrpAtacante and hrpAtacante:IsA("BasePart") then
		ouvirSom(d, Config.estados.investigaAte, hrpAtacante.Position, os.clock())
	end
end

-- Invocação pelo menu de admin: `qtd` monstros da espécie `especieId` (qualquer espécie do Config, mesmo de nível acima do ativo)
-- em fila na frente do jogador, no chão. Sem ponto de origem: ao morrer não renascem. Devolve quantos nasceram.
local invocados: { [Player]: { Model } } = {}

function Monstros.invocar(jogador: Player, especieId: any, qtd: any): (number, string)
	local personagem = jogador.Character
	local hrp = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not (personagem and hrp and hrp:IsA("BasePart")) then
		return 0, "sem personagem"
	end
	local especie
	if type(especieId) == "string" then
		for _, e in Config.especies do
			if e.id == especieId then
				especie = e
			end
		end
	end
	if not especie then
		return 0, "espécie desconhecida"
	end
	local n = if type(qtd) == "number" and qtd == qtd
		then math.floor(math.clamp(qtd, 1, CfgAdmin.invocar.maxMonstros))
		else 1
	local meus = invocados[jogador]
	if not meus then
		meus = {}
		invocados[jogador] = meus
	end
	local frente = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	frente = if frente.Magnitude > 0.1 then frente.Unit else Vector3.new(0, 0, -1)
	local direita = frente:Cross(Vector3.yAxis)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personagem :: Instance, pastaMonstros() }
	local criados = 0
	local limite = false
	for i = 1, n do
		if not RegrasHab.podeNascer(contarEspecie(especie.id), especie.maxAdmin or especie.maxPorServidor) then
			limite = true
			break
		end
		local alvo = hrp.Position
			+ frente * CfgAdmin.invocar.distancia
			+ direita * ((i - (n + 1) / 2) * CfgAdmin.invocar.espacamentoMonstros)
		local r = workspace:Raycast(alvo + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
		local chao = if r then r.Position else alvo - Vector3.new(0, 3, 0)
		local d = criar(especie, chao, nil)
		if d then
			d.modelo:SetAttribute("Invocado", true)
			table.insert(meus, d.modelo)
			criados += 1
		end
	end
	while #meus > CfgAdmin.invocar.maxMonstros do
		local velho = table.remove(meus, 1)
		if velho and velho.Parent then
			Monstros.dano(velho, 1e9, nil)
		end
	end
	return criados, if criados == 0 and limite then "limite da espécie por servidor" else especie.id
end

-- Mata (e some com) os monstros invocados por este admin.
function Monstros.limparInvocados(jogador: Player)
	for _, m in invocados[jogador] or {} do
		if m.Parent then
			Monstros.dano(m, 1e9, nil)
		end
	end
	invocados[jogador] = nil
end

-- Destruicao (docs/destruicao.md §6.4): uma parede/vidro/cerca quebrou em `centro`; monstros a até `raio` studs descartam o
-- caminho e esperam o navmesh (que lê a geometria no ComputeAsync) antes de recalcular.
function Monstros.invalidarCaminhos(centro: Vector3, raio: number)
	local agora = os.clock()
	for _, d in lista do
		if d.vivo and d.hrp.Parent and (d.hrp.Position - centro).Magnitude <= raio then
			local espera = d.preset and d.preset.arrombar and d.preset.arrombar.esperaNavmesh or 0
			d.waypoints = nil
			d.alvoCaminho = nil
			d.ultimoCalculo = agora + espera
		end
	end
end

-- Sobe pela hierarquia até o Model com atributo Monstro; nil se não for parte de monstro.
function Monstros.ehMonstro(inst: Instance): Model?
	local atual: Instance? = inst
	while atual and atual ~= workspace do
		if atual:IsA("Model") and atual:GetAttribute("Monstro") then
			return atual
		end
		atual = atual.Parent
	end
	return nil
end

local function popular()
	local mapa = workspace:WaitForChild("Mapa", 10)
	local pontos = mapa and mapa:FindFirstChild("Pontos")
	if not pontos then
		warn("[Monstros] workspace.Mapa.Pontos ausente: nenhum monstro nasce")
		return
	end
	-- carrega o molde da malha (LoadAsset yield) antes de nascer qualquer monstro; falha = boneco de blocos
	for _, e in Config.especies do
		if e.malha and (e.nivel <= Config.nivelAtivoMaximo or e.nascerSempre) then
			local mm = servico("MonstroModelo")
			if mm then
				mm.preparar(e.id, presetDe(e))
			end
		end
	end
	local candidatos: { BasePart } = {}
	for _, p in pontos:GetChildren() do
		if p.Name == "Monstro" and p:IsA("BasePart") then
			table.insert(candidatos, p)
		end
	end
	if #candidatos == 0 then
		warn('[Monstros] nenhum ponto "Monstro" no mapa: nenhum monstro nasce')
		return
	end
	-- Embaralha antes de cortar em maxPorServidor, para o corte não favorecer uma região.
	for i = #candidatos, 2, -1 do
		local j = random:NextInteger(1, i)
		candidatos[i], candidatos[j] = candidatos[j], candidatos[i]
	end
	local total = math.min(#candidatos, Config.maxPorServidor)
	for i = 1, total do
		nascerNoPonto(candidatos[i])
		if i % 10 == 0 then
			task.wait()
		end
	end
	print(string.format("[Monstros] %d monstros nasceram (%d pontos no mapa)", total, #candidatos))
end

local function registrarTestes()
	local ok, Teste = pcall(function()
		return require(script.Parent.Teste)
	end)
	if not ok then
		return
	end
	Teste.registrar("monstro", function(jogador: Player, especieId: string?)
		local id = especieId
		if not id then
			local ativas = especiesAtivas()
			local sorteada = ativas[random:NextInteger(1, math.max(#ativas, 1))]
			id = sorteada and sorteada.id
		end
		local n, texto = Monstros.invocar(jogador, id, 1)
		return if n > 0 then "nasceu " .. texto else "falhou: " .. texto
	end)
	-- Rastejador (docs/rastejador.md §8): ruído em ponto qualquer e estado dos monstros com capacidades.
	Teste.registrar(
		"rastejador_ruido",
		function(_jogador: Player, x: number, y: number, z: number, db: number?, tipo: string?)
			local ruido = servico("Ruido")
			if not ruido then
				return "sem Ruido"
			end
			ruido.emitir(Vector3.new(x, y, z), db or 100, tipo or "teste", nil)
			return "ruido em " .. tostring(Vector3.new(x, y, z))
		end
	)
	Teste.registrar("rastejador_estado", function()
		local linhas = {}
		for _, d in lista do
			if d.vivo and d.cap and d.modelo:GetAttribute("Invocado") then
				local c = d.cap
				table.insert(
					linhas,
					string.format(
						"%s estado=%s acao=%s obj=%s caminho=%s parede=%s veiculo=%s pos=%s",
						d.modelo.Name,
						d.estadoVisivel,
						tostring(d.acao),
						tostring(c.objTipo),
						if c.caminho then c.caminho.estado .. "/" .. math.floor(c.caminho.comprimento) else "-",
						if c.parede then (if c.parede.buraco then "buraco" else "peca") else "nao",
						tostring(c.veiculo ~= nil),
						tostring(d.hrp.Position)
					)
				)
			end
		end
		return table.concat(linhas, "\n")
	end)
	Teste.registrar("monstros", function()
		local contagem: { [string]: number } = {}
		local total = 0
		for _, d in lista do
			if d.vivo then
				total += 1
				contagem[d.estadoVisivel] = (contagem[d.estadoVisivel] or 0) + 1
			end
		end
		local partes = { "total=" .. total }
		for _, estado in { "Calmo", "Investiga", "Caca", "Ataque" } do
			table.insert(partes, estado .. "=" .. (contagem[estado] or 0))
		end
		local texto = table.concat(partes, " ")
		print("[Monstros] " .. texto)
		return texto
	end)
end

-- Monstros vivos a <= `raio` studs de `pos` na horizontal e, se `dyMax`, a no máximo `dyMax` de diferença de altura; do mais perto para o mais
-- longe. Quem decide se estão "em busca" é quem chama (Respiracao: d.perc.estado == "Investiga" ou a Busca do Rastejador ativa).
function Monstros.proximos(pos: Vector3, raio: number, dyMax: number?): { Dados }
	local achados: { { d: Dados, dist: number } } = {}
	for _, d in lista do
		if d.vivo then
			local delta = d.hrp.Position - pos
			local dist = horizontal(delta)
			if dist <= raio and (dyMax == nil or math.abs(delta.Y) <= dyMax) then
				table.insert(achados, { d = d, dist = dist })
			end
		end
	end
	table.sort(achados, function(a, b)
		return a.dist < b.dist
	end)
	local saida: { Dados } = {}
	for _, a in achados do
		table.insert(saida, a.d)
	end
	return saida
end

function Monstros.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	pastaMonstros()

	-- Habilidades por espécie e flores (logica.md §2.3, §7.2): módulos opcionais, carregados em pcall
	local habCtx = {
		servico = servico,
		Config = Config,
		animar = animar,
		tocarAcao = tocarAcao,
		evento = evento,
		ouvirSom = ouvirSom,
		seguirAlvo = seguirAlvo,
		irPara = irPara,
		parar = parar,
		restaurarVelocidade = function(d: Dados)
			d.humanoid.WalkSpeed = velocidadeDe(d.especie, d.nivel, d.estadoVisivel)
		end,
		acalmar = acalmar,
		estaVivo = estaVivo,
		horizontal = horizontal,
		porId = function(id: number): Dados?
			return porId[id]
		end,
		porModelo = function(m: Instance): Dados?
			return porModelo[m]
		end,
		atacavel = function(j: Player): boolean
			local mods = capModulos()
			return capChamar(mods.objetivo and mods.objetivo.atacavel, j) ~= false
		end,
	}
	local hab = servico("MonstroHabilidades")
	if hab then
		hab.configurar(habCtx)
	end
	local flores = servico("Flores")
	if flores then
		flores.configurar({
			servico = servico,
			ouvir = function(donoId: number, pos: Vector3)
				local d = porId[donoId]
				if d and d.vivo then
					ouvirSom(d, Config.estados.investigaAte, pos, os.clock()) -- posição exata, excesso de Caça
				end
			end,
		})
	end

	local ruido = servico("Ruido")
	if ruido then
		ruido.aoRuido(function(ev)
			-- cada callback já roda em task.spawn pelo Ruido; o spawn extra protege se alguém chamar direto
			task.spawn(processarRuido, ev)
		end)
	end

	registrarTestes()
	task.spawn(laco)
	task.spawn(popular)
end

return Monstros
