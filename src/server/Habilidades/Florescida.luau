-- Habilidades da Florescida (docs/monstros/logica.md §7): fora da cidade, curva lenta, flores-sentinela, rugido, mordida/cauda/fachada e
-- pisoteio. Ela cuida dos próprios golpes (d.semGolpeNormal = true sempre). Números em PresetsMonstro.florescida.habilidades.*.
-- Direção: o Humanoid roda com AutoRotate = false e anda na direção em que o corpo aponta; um Heartbeat gira o corpo para o rumo
-- (d.rumoLento.alvo, que o Monstros preenche em irPara) a `giro.grausPorSegundo`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared.Regras.Habilidades)

local M = {}

local ctx: any = {}
local U: any = {}

local ativas: { any } = {}
local conexao: RBXScriptConnection? = nil
local concretoDe: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function vec(v: Vector3): any
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Direção (Heartbeat) ---------------------------------------------------------------------------------------------------

local function dirigir(dt: number)
	for i = #ativas, 1, -1 do
		local d = ativas[i]
		if not d.vivo or not d.hrp.Parent then
			table.remove(ativas, i)
		else
			local alvo: Vector3? = d.rumoLento.alvo
			local pos = d.hrp.Position
			local delta = if alvo then Vector3.new(alvo.X - pos.X, 0, alvo.Z - pos.Z) else nil
			if delta and delta.Magnitude > 1.5 then
				local _, yaw = d.hrp.CFrame:ToOrientation()
				local novo = Regras.girarPara(
					yaw,
					math.atan2(-delta.X, -delta.Z),
					math.rad(d.preset.habilidades.giro.grausPorSegundo) * dt
				)
				d.hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, novo, 0)
				d.humanoid:Move(Vector3.new(-math.sin(novo), 0, -math.cos(novo)))
			else
				d.humanoid:Move(Vector3.zero)
			end
		end
	end
end

function M.configurar(c: any, util: any)
	ctx, U = c, util
end

function M.iniciar(d: any)
	d.hab = {
		andou = 0,
		andouCheck = 0,
		paradoAte = 0,
		rugidoUltimo = -math.huge,
		rugidoPendente = false,
		caudaUltimo = -math.huge,
		mordidaUltimo = -math.huge,
		fachadaUltimo = -math.huge,
		fachadaDentroAte = 0,
		ronda = nil, -- { ate }: rondando a borda da cidade
		janelas = nil, -- { ate, proximo }: rondando janelas de prédio alto/concreto
		pisoteioProx = 0,
		carros = {}, -- [Model] = instante do último pisão
	}
	d.humanoid.AutoRotate = false
	d.rumoLento = { alvo = nil }
	d.filtroDestino = function(p: Vector3): boolean
		return not U.dentroDeZona(p, d.preset.habilidades.cidade.chave)
	end
	table.insert(ativas, d)
	if not conexao then
		conexao = RunService.Heartbeat:Connect(dirigir)
	end
end

function M.aoMorrer(d: any)
	local Flores = ctx.servico("Flores")
	if Flores then
		Flores.murchar(d.id, d.preset.habilidades.florescer.murchar)
	end
	d.humanoid:Move(Vector3.zero)
end

function M.aoOuvir(d: any, ev: any)
	if ev.antes ~= "Caca" and ev.depois == "Caca" then
		d.hab.rugidoPendente = true
	end
end

-- Chão sob um ponto (ignora monstros, flores, personagens e itens).
local function chaoSob(pos: Vector3): Vector3?
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local lista: { Instance } = {}
	for _, nome in { "Monstros", "Flores", "ItensChao", "SonsSoltos", "Efeitos" } do
		local f = workspace:FindFirstChild(nome)
		if f then
			table.insert(lista, f)
		end
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(lista, j.Character)
		end
	end
	p.FilterDescendantsInstances = lista
	local r = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), p)
	return if r then r.Position else nil
end

-- Florescer (§7.2) --------------------------------------------------------------------------------------------------------

local function florescer(d: any, agora: number)
	local h, f = d.hab, d.preset.habilidades.florescer
	h.andou = 0
	h.paradoAte = agora + ctx.tocarAcao(d, "Florescer", agora, f.duracao)
	task.delay(ctx.evento(d, "Florescer", "plantar", f.plantar), function()
		if not d.vivo then
			return
		end
		local Flores = ctx.servico("Flores")
		local look = d.hrp.CFrame.LookVector
		local chao = chaoSob(d.hrp.Position + Vector3.new(look.X, 0, look.Z).Unit * (f.frente + d.hrp.Size.Z / 2))
		if Flores and chao then
			Flores.plantar(d, chao)
			local sons = ctx.servico("Sons")
			if sons then
				sons.tocar("FlorPlantar", chao)
			end
		end
	end)
end

-- Rugido (§7.3) -----------------------------------------------------------------------------------------------------------

local function rugir(d: any, agora: number, jogadores: { any })
	local h, r = d.hab, d.preset.habilidades.rugido
	h.rugidoUltimo = agora
	h.rugidoPendente = false
	h.paradoAte = agora + ctx.tocarAcao(d, "Rugido", agora, r.duracao)
	task.delay(ctx.evento(d, "Rugido", "impacto", r.impacto), function()
		if not d.vivo then
			return
		end
		local origem = d.hrp.Position
		local sons = ctx.servico("Sons")
		if sons then
			sons.tocar("RugidoChao", d.hrp, { db = r.db })
		end
		local ruido = ctx.servico("Ruido")
		if ruido then
			ruido.emitir(origem, r.db, "rugido", d.modelo) -- nível 3: chama os de nível 1 e 2 como escolta
		end
		local mov = ctx.servico("Movimento")
		for _, j in Players:GetPlayers() do
			local hrp = U.parteDoJogador(j, "HumanoidRootPart")
			if hrp and ctx.estaVivo(j) then
				local dist = (hrp.Position - origem).Magnitude
				if dist <= r.tremor then
					U.enviar("Tremor", j, r.tremorIntensidade, r.tremorDuracao)
				end
				if dist <= r.raio and not U.emCarro(j) and mov and mov.derrubar then
					local fora = Vector3.new(hrp.Position.X - origem.X, 0, hrp.Position.Z - origem.Z)
					fora = if fora.Magnitude > 0.1 then fora.Unit else d.hrp.CFrame.LookVector
					mov.derrubar(j, r.derrubado, fora * r.impulso + Vector3.new(0, r.subida, 0))
				end
			end
		end
	end)
	-- (jogadores do tick não são usados: o impacto relê quem está perto quando cai)
	local _ = jogadores
end

-- Ataques (§7.4) ------------------------------------------------------------------------------------------------------------

local function morder(d: any, jogador: Player, agora: number, alcance: number)
	local h, m = d.hab, d.preset.habilidades.mordida
	h.mordidaUltimo = agora
	ctx.tocarAcao(d, "Attack", agora, m.duracao)
	task.delay(ctx.evento(d, "Attack", "impacto", m.impacto), function()
		if not d.vivo or not ctx.estaVivo(jogador) then
			return
		end
		local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
		if hrp and ctx.horizontal(hrp.Position - d.hrp.Position) <= alcance + 2 then
			local delta = hrp.Position - d.hrp.Position
			U.danoJogador(
				jogador,
				nil,
				ctx.Config.niveis[d.nivel].dano,
				if delta.Magnitude > 0 then delta.Unit else nil
			)
		end
	end)
	local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
	if hrp then
		ctx.ouvirSom(d, ctx.Config.estados.investigaAte, hrp.Position, agora)
	end
end

local function baterCauda(d: any, jogador: Player, agora: number)
	local h, c = d.hab, d.preset.habilidades.cauda
	h.caudaUltimo = agora
	h.paradoAte = agora + ctx.tocarAcao(d, "Cauda", agora, c.duracao)
	task.delay(ctx.evento(d, "Cauda", "impacto", c.impacto), function()
		if not d.vivo or not ctx.estaVivo(jogador) then
			return
		end
		local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
		local look = d.hrp.CFrame.LookVector
		if hrp and Regras.noCone(vec(d.hrp.Position), vec(-look), vec(hrp.Position), c.cone, c.alcance + 2) then
			local delta = Vector3.new(hrp.Position.X - d.hrp.Position.X, 0, hrp.Position.Z - d.hrp.Position.Z)
			local dir = if delta.Magnitude > 0.1 then delta.Unit else -look
			U.danoJogador(jogador, nil, c.dano, dir)
			U.enviar("Impulso", jogador, dir * c.empurrao) -- o cliente é dono da física do próprio personagem
			local sons = ctx.servico("Sons")
			if sons then
				sons.tocar("CaudaGolpe", d.hrp)
			end
		end
	end)
end

-- Construção de concreto (maioria das paredes de concreto): a fachada não arranca.
local function ehConcreto(modelo: Model): boolean
	local c = concretoDe[modelo]
	if c ~= nil then
		return c
	end
	local total, concreto = 0, 0
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Parede" then
			total += 1
			if p.Material == Enum.Material.Concrete then
				concreto += 1
			end
			if total >= 60 then
				break
			end
		end
	end
	c = total > 0 and concreto * 2 > total
	concretoDe[modelo] = c
	return c
end

local function arrancarFachada(d: any, agora: number, ponto: Vector3, normal: Vector3)
	local h, f = d.hab, d.preset.habilidades.fachada
	h.fachadaUltimo = agora
	h.paradoAte = agora + ctx.tocarAcao(d, "ArrancarFachada", agora, f.duracao)
	task.delay(ctx.evento(d, "ArrancarFachada", "impacto", f.impacto), function()
		local D = ctx.servico("Destruicao")
		if not d.vivo or not D then
			return
		end
		local tam = Vector3.new(f.caixa[1], f.caixa[2], f.caixa[3])
		local centro = ponto + Vector3.new(0, tam.Y / 2 - 3, 0) -- o ponto é a altura do corpo do alvo; a caixa parte do chão
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Include
		op.FilterDescendantsInstances = require(Shared.Raizes).obter("Construcoes")
		for _, p in workspace:GetPartBoundsInBox(CFrame.lookAt(centro, centro + normal), tam, op) do
			if string.sub(p.Name, 1, 6) == "Parede" or p.Material == Enum.Material.Glass then
				if D.ehDestrutivel(p) then
					D.dano(p, f.dano, {
						tipo = "impacto",
						ponto = p:GetClosestPointOnSurface(centro),
						normal = normal,
						fonte = d.modelo,
						largura = f.caixa[1],
						altura = f.caixa[2],
					})
				end
			end
		end
		d.hab.fachadaDentroAte = os.clock() + f.dentroPor
	end)
end

-- O alvo está dentro de construção: arranca a fachada (baixa e não concreto) ou começa a rondar janelas. true = atacou.
local function tentarFachada(d: any, j: any, agora: number): boolean
	local h, f = d.hab, d.preset.habilidades.fachada
	if not Regras.pronto(h.fachadaUltimo, agora, f.recarga) then
		return false
	end
	local modelo = U.construcaoEm(j.pos, 2)
	if not modelo or not U.dentroDe(modelo, j.pos) then
		return false
	end
	local pos = d.hrp.Position
	local dir = j.pos - pos
	local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), dir.Unit * (dir.Magnitude + 2), U.paramsSolido())
	local alcance = d.preset.habilidades.mordida.alcance
	if not r or ctx.horizontal(r.Position - pos) > alcance + 2 then
		return false -- longe da parede: vai até lá primeiro
	end
	local _, tam = modelo:GetBoundingBox()
	if Regras.decidirFachada(tam.Y, ehConcreto(modelo), f) == "arrancar" then
		arrancarFachada(d, agora, r.Position, r.Normal)
		return true
	end
	if not h.janelas then
		h.janelas = { ate = agora + f.rondar, proximo = agora }
	end
	return false
end

-- Ronda de janelas: a cada `janelaCada` s morde o vidro mais perto.
local function rondarJanelas(d: any, agora: number)
	local h, f = d.hab, d.preset.habilidades.fachada
	local jn = h.janelas
	if agora >= jn.ate then
		h.janelas = nil
		ctx.acalmar(d, agora)
		return
	end
	if agora < jn.proximo then
		return
	end
	jn.proximo = agora + f.janelaCada
	local D = ctx.servico("Destruicao")
	if not D then
		return
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = require(Shared.Raizes).obter("Construcoes")
	local melhor, menor = nil, math.huge
	for _, p in workspace:GetPartBoundsInRadius(d.hrp.Position, d.preset.habilidades.mordida.alcance + 6, op) do
		if p.Material == Enum.Material.Glass and D.ehDestrutivel(p) then
			local dist = (p.Position - d.hrp.Position).Magnitude
			if dist < menor then
				melhor, menor = p, dist
			end
		end
	end
	if melhor then
		local p = melhor
		ctx.tocarAcao(d, "Attack", agora, d.preset.habilidades.mordida.duracao)
		task.delay(ctx.evento(d, "Attack", "impacto", d.preset.habilidades.mordida.impacto), function()
			if d.vivo and p.Parent then
				D.dano(p, f.danoJanela, { tipo = "impacto", fonte = d.modelo })
			end
		end)
	end
end

-- Pisotear (§7.5) --------------------------------------------------------------------------------------------------------------

local function pisotear(d: any, agora: number)
	local h, p = d.hab, d.preset.habilidades.pisotear
	h.pisoteioProx = agora + p.cada
	local D = ctx.servico("Destruicao")
	local cf = d.hrp.CFrame * CFrame.new(0, 0, -(d.hrp.Size.Z / 2 + p.frente / 2))
	local tam = Vector3.new(d.hrp.Size.X, d.hrp.Size.Y, p.frente)
	local Raizes = require(Shared.Raizes)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = Raizes.obter("Props")
	if D then
		for _, peca in workspace:GetPartBoundsInBox(cf, tam, op) do
			if D.ehDestrutivel(peca) then
				D.dano(peca, p.dano, { tipo = "impacto", fonte = d.modelo })
			end
		end
	end
	local veiculos = workspace:FindFirstChild("Veiculos")
	local V = ctx.servico("Veiculos")
	if veiculos and V then
		op.FilterDescendantsInstances = { veiculos }
		for _, peca in workspace:GetPartBoundsInBox(cf, tam, op) do
			local modelo = peca:FindFirstAncestorOfClass("Model")
			while modelo and modelo.Parent ~= veiculos do
				modelo = modelo.Parent and modelo.Parent:FindFirstAncestorOfClass("Model")
			end
			if modelo and agora - (h.carros[modelo] or -math.huge) >= p.cadaCarro then
				h.carros[modelo] = agora
				if peca:GetAttribute("PecaVeiculo") ~= nil then
					V.acerto(peca, p.danoCarro, nil)
				end
				local base = modelo.PrimaryPart
				if base then
					local lado = d.hrp.CFrame.RightVector
					local sinal = if (base.Position - d.hrp.Position):Dot(lado) >= 0 then 1 else -1
					base.AssemblyLinearVelocity += lado * sinal * p.impulsoCarro
				end
			end
		end
	end
end

-- Passo -------------------------------------------------------------------------------------------------------------------------------

function M.passo(d: any, agora: number, c: any): boolean
	local h, cf = d.hab, d.preset.habilidades
	if not h then
		return false
	end
	d.semGolpeNormal = true
	local pos = d.hrp.Position

	if agora < h.paradoAte then
		ctx.parar(d)
		return true
	end

	-- flores: a cada `cada` s andando fora da cidade e fora de construção
	if agora >= h.andouCheck then
		h.andouCheck = agora + 1
		local v = d.hrp.AssemblyLinearVelocity
		if
			math.sqrt(v.X * v.X + v.Z * v.Z) > 1
			and not U.dentroDeZona(pos, cf.cidade.chave)
			and U.construcaoEm(pos, 4) == nil
		then
			h.andou += 1
			if h.andou >= cf.florescer.cada then
				florescer(d, agora)
				ctx.parar(d)
				return true
			end
		end
	end

	-- rugido ao entrar em Caça
	if h.rugidoPendente then
		if Regras.pronto(h.rugidoUltimo, agora, cf.rugido.recarga) then
			rugir(d, agora, c.jogadores)
			ctx.parar(d)
			return true
		end
		h.rugidoPendente = false
	end

	-- cidade: nunca entra
	local controlou = false
	local zonas = U.zonas()
	local p2 = { x = pos.X, z = pos.Z }
	local a = d.perc.alvo
	if Regras.dentroDeZona(p2, zonas, cf.cidade.chave) then
		local caixa = Regras.zonaQueContem(p2, zonas, cf.cidade.chave)
		if caixa then
			local f = Regras.pontoForaMaisProximo(p2, caixa, cf.cidade.borda)
			ctx.seguirAlvo(d, Vector3.new(f.x, pos.Y, f.z), agora)
			controlou = true
		end
	elseif d.perc.estado ~= "Calmo" and a and Regras.dentroDeZona({ x = a.x, z = a.z }, zonas, cf.cidade.chave) then
		local caixa = Regras.zonaQueContem({ x = a.x, z = a.z }, zonas, cf.cidade.chave)
		if caixa then
			local f = Regras.pontoForaMaisProximo({ x = a.x, z = a.z }, caixa, cf.cidade.borda)
			local borda = Vector3.new(f.x, pos.Y, f.z)
			if ctx.horizontal(borda - pos) > 6 then
				ctx.seguirAlvo(d, borda, agora)
			else
				ctx.parar(d)
				h.ronda = h.ronda or { ate = agora + cf.cidade.rondar }
				if agora >= h.ronda.ate then
					h.ronda = nil
					ctx.acalmar(d, agora)
				end
			end
			controlou = true
		end
	else
		h.ronda = nil
	end

	-- ataques ao jogador mais perto
	local j = c.maisPerto
	if j then
		local delta = j.pos - pos
		local dh = ctx.horizontal(delta)
		local nivel = ctx.Config.niveis[d.nivel]
		if
			Regras.pronto(h.caudaUltimo, agora, cf.cauda.recarga)
			and Regras.noCone(vec(pos), vec(-d.hrp.CFrame.LookVector), vec(j.pos), cf.cauda.cone, cf.cauda.alcance)
			and math.abs(delta.Y) <= cf.mordida.altura
		then
			baterCauda(d, j.jogador, agora)
			ctx.parar(d)
			return true
		end
		if dh <= cf.mordida.alcance + 26 and tentarFachada(d, j, agora) then
			ctx.parar(d)
			return true
		end
		local alcance = cf.mordida.alcance + (if agora < h.fachadaDentroAte then cf.fachada.alcanceDentro else 0)
		if
			dh <= alcance
			and math.abs(delta.Y) <= cf.mordida.altura
			and Regras.pronto(h.mordidaUltimo, agora, d.intervaloGolpe or nivel.intervaloGolpe)
			and ctx.atacavel(j.jogador)
		then
			morder(d, j.jogador, agora, alcance)
		end
	end

	if h.janelas then
		rondarJanelas(d, agora)
	end
	if d.perc.estado == "Caca" and agora >= h.pisoteioProx then
		pisotear(d, agora)
	end
	return controlou
end

return M
