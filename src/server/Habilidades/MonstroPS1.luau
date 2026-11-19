-- Habilidades do MonstroPS1 (docs/monstros/logica.md §6): arrancada com lâminas arrastando, golpe duplo, lâminas lançadas e corte de
-- madeira/vidro (tipo de dano `lamina`). Números em PresetsMonstro.monstroPS1.habilidades.{arrancada,lancar,golpeDuplo,corte}.
-- O bloqueio de pistola e o ruído de aparar (§6.5) são do Armas (agente B).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared.Regras.Habilidades)
local Arremesso = require(Shared.Regras.Arremesso)

local M = {}

local ctx: any = {}
local U: any = {}
local random = Random.new()

function M.configurar(c: any, util: any)
	ctx, U = c, util
end

function M.iniciar(d: any)
	d.hab = {
		arrancada = false,
		arrancadaUltimo = -math.huge,
		lancarUltimo = -math.huge,
		lancarParado = 0,
		duploAte = 0,
		golpes = 0,
		corteCheck = 0,
		corteProx = 0,
	}
end

local function vec(v: Vector3): any
	return { x = v.X, y = v.Y, z = v.Z }
end

local function rnd(): number
	return random:NextNumber()
end

local function pe(d: any): number
	return d.hrp.Position.Y - d.hrp.Size.Y / 2 - d.humanoid.HipHeight
end

local function pastaEfeitos(): Folder
	local f = workspace:FindFirstChild("Efeitos")
	if f and f:IsA("Folder") then
		return f
	end
	local nova = Instance.new("Folder")
	nova.Name = "Efeitos"
	nova.Parent = workspace
	return nova
end

-- Golpe duplo (§6.2) ------------------------------------------------------------------------------------------------------

local function golpeDuplo(d: any, jogador: Player, agora: number)
	local h, g = d.hab, d.preset.habilidades.golpeDuplo
	h.duploAte = agora + ctx.tocarAcao(d, "GolpeDuplo", agora, g.duracao)
	for _, nome in { "impacto1", "impacto2" } do
		task.delay(ctx.evento(d, "GolpeDuplo", nome, g[nome]), function()
			if not d.vivo or not ctx.estaVivo(jogador) then
				return
			end
			local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
			if hrp and ctx.horizontal(hrp.Position - d.hrp.Position) <= g.alcance then
				local delta = hrp.Position - d.hrp.Position
				U.danoJogador(jogador, nil, g.dano, if delta.Magnitude > 0 then delta.Unit else nil)
			end
		end)
	end
end

-- 1 golpe de perto em cada `cada` é o golpe duplo; os outros são o Attack normal (Monstros).
function M.aoGolpear(d: any, jogador: Player, agora: number): boolean
	local h, g = d.hab, d.preset.habilidades.golpeDuplo
	h.golpes += 1
	if Regras.golpeDuploAgora(h.golpes, g.cada) then
		golpeDuplo(d, jogador, agora)
		return true
	end
	return false
end

-- Arrancada (§6.1) --------------------------------------------------------------------------------------------------------

local function faisca(d: any, a: any, comLuz: boolean)
	local pos = d.hrp.Position
	local p = Instance.new("Part")
	p.Name = "Faisca"
	p.Size = Vector3.new(0.3, 0.3, 0.3)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 150, 40)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(pos.X, pe(d) + 0.15, pos.Z)
	if comLuz then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 150, 40)
		l.Brightness = 0.8
		l.Range = 8
		l.Parent = p
	end
	p.Parent = pastaEfeitos()
	Debris:AddItem(p, a.faiscaVida)
end

local function iniciarArrancada(d: any, jogador: Player, alvo: Vector3, agora: number)
	local h, a = d.hab, d.preset.habilidades.arrancada
	h.arrancada = true
	h.arrancadaUltimo = agora
	ctx.tocarAcao(d, "Arrancada", agora, a.duracao, a.duracao)
	d.humanoid.WalkSpeed = a.velocidade
	local sons = ctx.servico("Sons")
	local ruido = ctx.servico("Ruido")
	local loop = if sons then sons.loop("RasparLaminas", d.hrp, { db = a.db }) else nil
	task.spawn(function()
		local inicio = os.clock()
		local proxRuido, proxLuz = inicio, inicio
		-- linha reta até a posição do alvo NO INÍCIO (passo de lado esquiva)
		while d.vivo and os.clock() - inicio < a.duracao do
			local t = os.clock()
			-- a troca de estado visível (Monstros.aplicarEstadoVisivel) reescreve WalkSpeed: reafirma a cada passo (visto em Play 2026-11-14)
			d.humanoid.WalkSpeed = a.velocidade
			ctx.irPara(d, alvo)
			faisca(d, a, t >= proxLuz)
			if t >= proxLuz then
				proxLuz = t + a.luzCada
			end
			if ruido and t >= proxRuido then
				proxRuido = t + a.rasparCada
				ruido.emitir(d.hrp.Position, a.db, "raspar", d.modelo)
			end
			task.wait(a.faiscaCada)
		end
		if loop then
			loop:Destroy()
		end
		h.arrancada = false
		if not d.vivo then
			return
		end
		local fim = os.clock()
		d.golpeAte = fim
		d.clipe = nil
		ctx.restaurarVelocidade(d)
		-- terminou colado no alvo: golpe duplo na hora
		local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
		if hrp and ctx.estaVivo(jogador) and ctx.horizontal(hrp.Position - d.hrp.Position) <= a.golpeDuploDist then
			d.ultimoGolpe = fim
			golpeDuplo(d, jogador, fim)
		end
	end)
end

-- Lâminas lançadas (§6.3) ---------------------------------------------------------------------------------------------------

local function lancarLamina(d: any, jogador: Player)
	local l = d.preset.habilidades.lancar
	local hrpJ = U.parteDoJogador(jogador, "HumanoidRootPart")
	if not hrpJ then
		return
	end
	local mao = (d.hrp.CFrame * CFrame.new(d.hrp.Size.X / 2 + 0.5, d.hrp.Size.Y * 0.2, -1)).Position
	local prev = Regras.alvoPrevisto(vec(hrpJ.Position), vec(hrpJ.AssemblyLinearVelocity), l.previsao)
	local dir = Regras.desviarDirecao({ x = prev.x - mao.X, y = prev.y - mao.Y, z = prev.z - mao.Z }, l.erroGraus, rnd)
	local vel = { x = dir.x * l.velocidade, y = dir.y * l.velocidade, z = dir.z * l.velocidade }
	local sons = ctx.servico("Sons")
	if sons then
		sons.tocar("LaminaLancada", d.hrp)
	end

	-- trajetória até o primeiro acerto em geometria estática (construções, props, carros)
	local rp = U.paramsVisao()
	local passos, acertoPasso = 0, nil
	local acertoInst: Instance? = nil
	local acertoPos, acertoNormal = nil, nil
	local res = Arremesso.simular(vec(mao), vel, l.gravidade, l.passo, math.ceil(l.tempoMax / l.passo), function(a, b)
		passos += 1
		if acertoPasso then
			return nil, nil
		end
		local r = workspace:Raycast(Vector3.new(a.x, a.y, a.z), Vector3.new(b.x - a.x, b.y - a.y, b.z - a.z), rp)
		if r then
			acertoPasso, acertoInst, acertoPos, acertoNormal = passos, r.Instance, r.Position, r.Normal
			return vec(r.Position), vec(r.Normal)
		end
		return nil, nil
	end)
	local caminho: { Vector3 } = {}
	local total = 0
	local ultimo = mao
	for i, p in res.pontos do
		if acertoPasso and i > acertoPasso + 1 then
			break
		end
		local v = Vector3.new(p.x, p.y, p.z)
		total += (v - ultimo).Magnitude
		if total > l.alcanceMax then
			break
		end
		table.insert(caminho, v)
		ultimo = v
	end
	if acertoPos and acertoPasso and #caminho >= acertoPasso + 1 then
		caminho[#caminho] = acertoPos
	end

	local lamina = Instance.new("Part")
	lamina.Name = "Lamina"
	lamina.Size = Vector3.new(l.tamanho[1], l.tamanho[2], l.tamanho[3])
	lamina.Material = Enum.Material.Metal
	lamina.Color = Color3.fromRGB(60, 60, 68)
	lamina.Anchored = true
	lamina.CanCollide = false
	lamina.CanQuery = false
	lamina.CanTouch = false
	lamina.CFrame = CFrame.new(mao)
	lamina.Parent = pastaEfeitos()

	-- voo: a cada passo confere os personagens (jogadores se mexem) antes de seguir
	local chars: { Instance } = {}
	for _, j in Players:GetPlayers() do
		if j.Character and ctx.estaVivo(j) then
			table.insert(chars, j.Character)
		end
	end
	local pc = RaycastParams.new()
	pc.FilterType = Enum.RaycastFilterType.Include
	pc.FilterDescendantsInstances = chars
	for i = 2, #caminho do
		local a, b = caminho[i - 1], caminho[i]
		local r = workspace:Raycast(a, b - a, pc)
		if r then
			local dono = U.personagemDe(r.Instance)
			if dono then
				local dd = b - a
				U.danoJogador(dono, U.parteDoCorpo(r.Instance.Name), l.dano, if dd.Magnitude > 0 then dd.Unit else nil)
			end
			lamina:Destroy()
			return
		end
		lamina.CFrame = CFrame.lookAt(b, b + (b - a))
		task.wait(l.passo)
	end

	if acertoInst and acertoPos and acertoNormal then
		-- crava na construção e some
		lamina.CFrame = CFrame.lookAt(acertoPos, acertoPos - acertoNormal)
		Debris:AddItem(lamina, l.vidaCravada)
		if sons then
			sons.tocar("LaminaImpacto", acertoPos)
		end
		local ruido = ctx.servico("Ruido")
		if ruido then
			ruido.emitir(acertoPos, l.db, "laminaImpacto", d.modelo)
		end
		local D = ctx.servico("Destruicao")
		local inst = acertoInst
		if D and inst:IsA("BasePart") and inst.Material == Enum.Material.Glass then
			D.dano(inst, l.danoVidro, { tipo = "corte", ponto = acertoPos, normal = acertoNormal, fonte = d.modelo })
		end
	else
		lamina:Destroy()
	end
end

local function iniciarLancar(d: any, jogador: Player, agora: number)
	local h, l = d.hab, d.preset.habilidades.lancar
	h.lancarUltimo = agora
	h.lancarParado = agora + ctx.tocarAcao(d, "Lancar", agora, l.duracao)
	ctx.parar(d)
	local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
	if hrp then
		local p = d.hrp.Position
		d.hrp.CFrame = CFrame.lookAt(p, Vector3.new(hrp.Position.X, p.Y, hrp.Position.Z))
	end
	task.delay(ctx.evento(d, "Lancar", "soltar", l.soltar), function()
		if d.vivo then
			lancarLamina(d, jogador)
		end
	end)
end

-- Corte (§6.4) -----------------------------------------------------------------------------------------------------------------

-- Em Caça, porta fechada / cerca de madeira / vidro à frente (cai em <= golpesMax golpes de lâmina): corta com o Attack.
local function cortar(d: any, agora: number): boolean
	local h, k = d.hab, d.preset.habilidades.corte
	if agora < h.corteCheck or agora < h.corteProx or d.perc.estado ~= "Caca" then
		return false
	end
	h.corteCheck = agora + k.cada
	local D = ctx.servico("Destruicao")
	if not D or d.humanoid.MoveDirection.Magnitude < 0.1 then
		return false
	end
	local pos = d.hrp.Position
	local dir = d.humanoid.WalkToPoint - pos
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.5 then
		return false
	end
	local r = workspace:Raycast(pos, dir.Unit * (k.alcance + d.hrp.Size.Z / 2), U.paramsSolido())
	if not (r and D.ehDestrutivel(r.Instance)) then
		return false
	end
	local ok, golpes = pcall(D.golpesPara, r.Instance, k.dano, k.tipo)
	if not ok or golpes > k.golpesMax then
		return false -- alvenaria: contorna como hoje
	end
	h.corteProx = agora + k.intervalo
	ctx.tocarAcao(d, "Attack", agora, k.intervalo)
	ctx.parar(d)
	local peca, ponto, normal = r.Instance, r.Position, r.Normal
	task.delay(ctx.evento(d, "Attack", "impacto", k.impacto), function()
		if d.vivo and peca.Parent then
			D.dano(peca, k.dano, { tipo = k.tipo, ponto = ponto, normal = normal, fonte = d.modelo })
		end
	end)
	return true
end

-- Passo -----------------------------------------------------------------------------------------------------------------------------

function M.passo(d: any, agora: number, c: any): boolean
	local h, cf = d.hab, d.preset.habilidades
	if not h then
		return false
	end
	-- raspar as lâminas (Calmo andando ou na arrancada) o ensurdece (docs/som.md §6.4): só enquanto raspa
	local raspando = h.arrancada or (d.perc.estado == "Calmo" and d.humanoid.MoveDirection.Magnitude > 0.1)
	d.audicaoExtra = if raspando then cf.raspar.surdez else nil
	if h.arrancada then
		d.semGolpeNormal = true
		return true -- a thread da arrancada dirige o corpo
	end
	if agora < h.lancarParado or agora < h.duploAte then
		d.semGolpeNormal = agora < h.lancarParado
		ctx.parar(d)
		return true
	end

	local j = c.maisPerto
	if d.perc.estado == "Caca" and j and c.distPerto >= cf.arrancada.min and c.distPerto <= cf.lancar.max then
		local hrp = U.parteDoJogador(j.jogador, "HumanoidRootPart")
		local linha = hrp ~= nil and U.linhaLivre(d.hrp.Position + Vector3.new(0, d.hrp.Size.Y * 0.3, 0), hrp.Position)
		local escolha = Regras.escolherAtaquePS1(
			c.distPerto,
			linha == true,
			Regras.pronto(h.arrancadaUltimo, agora, cf.arrancada.recarga),
			Regras.pronto(h.lancarUltimo, agora, cf.lancar.recarga),
			cf.arrancada,
			cf.lancar
		)
		if escolha == "arrancada" then
			iniciarArrancada(d, j.jogador, j.pos, agora)
			d.semGolpeNormal = true
			return true
		elseif escolha == "lancar" then
			iniciarLancar(d, j.jogador, agora)
			d.semGolpeNormal = true
			return true
		end
	end

	return cortar(d, agora)
end

return M
