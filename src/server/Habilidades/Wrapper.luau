-- Habilidades do Wrapper (docs/monstros/logica.md §4): Sonar no lugar do grito, atordoado ao bater na parede no lunge, e batidas em Calmo.
-- A investida em si (Regras/Lunge) segue no Monstros; aqui entram o sonar, o alvo lembrado (d.alvoSonar) e a batida na parede.
-- Números em PresetsMonstro.corpoAriete.habilidades.{sonar,atordoado,batida}.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regras = require(Shared.Regras.Habilidades)

local M = {}

local ctx: any = {}
local U: any = {}
local proximoId = 0

function M.configurar(c: any, util: any)
	ctx, U = c, util
end

function M.iniciar(d: any)
	d.hab = {
		sonarUltimo = -math.huge,
		sonarParadoAte = 0,
		pendente = false, -- gatilho 1 (entrou em Caça): o passo dispara
		atordoadoAte = 0,
		batidaUltimo = -math.huge,
		batidaCheck = 0,
	}
end

local function pe(d: any): number
	return d.hrp.Position.Y - d.hrp.Size.Y / 2 - d.humanoid.HipHeight
end

-- Detecção de um jogador quando a frente da onda chega nele: linha de visão da cabeça do Wrapper até a cabeça ou o tronco.
local function detectar(d: any, jogador: Player, id: number, cabeca: Vector3, raio: number, origem: Vector3)
	if not d.vivo or not ctx.estaVivo(jogador) then
		return
	end
	local hrp = U.parteDoJogador(jogador, "HumanoidRootPart")
	if not hrp or (hrp.Position - origem).Magnitude > raio then
		return -- saiu da área antes da onda chegar: a onda não o alcança
	end
	local head = U.parteDoJogador(jogador, "Head")
	local livre = U.linhaLivre(cabeca, hrp.Position) or (head ~= nil and U.linhaLivre(cabeca, head.Position))
	if livre then
		local agora = os.clock()
		local c = d.preset.habilidades.sonar
		ctx.ouvirSom(d, ctx.Config.estados.investigaAte, hrp.Position, agora)
		d.alvoSonar = { jogador = jogador, pos = hrp.Position, ate = agora + c.memoria }
	end
	U.enviar("SonarAtingido", jogador, id, livre)
end

local function emitirOnda(d: any)
	if not d.vivo then
		return
	end
	local c = d.preset.habilidades.sonar
	proximoId += 1
	local id = proximoId
	local origem: Vector3 = d.hrp.Position
	local altura = d.modelo:GetAttribute("Altura") or d.hrp.Size.Y
	local cabeca = Vector3.new(origem.X, pe(d) + c.alturaCabeca * altura, origem.Z)
	local sons = ctx.servico("Sons")
	if sons then
		sons.tocar("GritoAbafado", d.hrp, { db = c.db })
	end
	local ruido = ctx.servico("Ruido")
	if ruido then
		ruido.emitir(origem, c.db, "sonar", d.modelo) -- fonte = monstro de nível 1: não chama os outros de nível 1
	end
	for _, j in Players:GetPlayers() do
		local hrp = U.parteDoJogador(j, "HumanoidRootPart")
		if hrp and ctx.estaVivo(j) then
			local dist = (hrp.Position - origem).Magnitude
			if dist <= c.alcanceAviso then
				U.enviar("MonstroSonar", j, origem, c.raio, c.velocidade, id)
			end
			if Regras.ondaAlcanca(dist, c.raio) then
				task.delay(Regras.tempoOnda(dist, c.velocidade), detectar, d, j, id, cabeca, c.raio, origem)
			end
		end
	end
end

local function iniciarSonar(d: any, agora: number)
	local h, c = d.hab, d.preset.habilidades.sonar
	h.sonarUltimo = agora
	h.pendente = false
	local dur = ctx.tocarAcao(d, "Sonar", agora, c.duracao)
	h.sonarParadoAte = agora + dur
	task.delay(ctx.evento(d, "Sonar", "onda", c.onda), emitirOnda, d)
end

-- Gatilho 1: entrou em Caça agora.
function M.aoOuvir(d: any, ev: any)
	if ev.antes ~= "Caca" and ev.depois == "Caca" then
		d.hab.pendente = true
	end
end

-- Raycast curto à frente do corpo contra construções e props; true se bate.
local function bateuNaFrente(d: any, extra: number): boolean
	local look = d.hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return false
	end
	local r = workspace:Raycast(d.hrp.Position, flat.Unit * (d.hrp.Size.Z / 2 + extra), U.paramsSolido())
	return r ~= nil
end

function M.passo(d: any, agora: number, c: any): boolean
	local h, cf = d.hab, d.preset.habilidades
	if not h then
		return false
	end

	-- bateu na parede durante a investida: atordoado
	local m = d.lunge
	if m and m.fase == "Lunge" and bateuNaFrente(d, cf.atordoado.sonda) then
		m.fase = "Recuperar"
		m.impactoFeito = true
		m.ate = agora + cf.atordoado.duracao
		h.atordoadoAte = m.ate
		d.alvoSonar = nil
		ctx.tocarAcao(d, "Atordoado", agora, cf.atordoado.duracao)
		ctx.parar(d)
		local ruido = ctx.servico("Ruido")
		if ruido then
			ruido.emitir(d.hrp.Position, cf.batida.db, "batidaCorpo", d.modelo)
		end
		return true
	end
	if agora < h.atordoadoAte then
		d.semGolpeNormal = true
		ctx.parar(d)
		return true
	end

	-- sonar em curso: parado e sem investida
	if agora < h.sonarParadoAte then
		d.semGolpeNormal = true
		ctx.parar(d)
		return true
	end

	-- gatilhos do sonar (recarga, e nunca no meio de uma investida ou colado no alvo)
	local livre = (not m or m.fase == "Aproximar") and Regras.pronto(h.sonarUltimo, agora, cf.sonar.recarga)
	if livre and c.distPerto > d.preset.golpe.alcanceInicio + 2 then
		local alvo = d.perc.alvo
		local estado = d.perc.estado
		local disparar = h.pendente
		if not disparar and estado == "Investiga" and alvo then
			disparar = ctx.horizontal(Vector3.new(alvo.x, alvo.y, alvo.z) - d.hrp.Position) <= cf.sonar.chegou
		end
		if not disparar and estado == "Caca" then
			disparar = Regras.perdeuAlvo(d.perc.ultimoSom, agora, cf.sonar)
		end
		if disparar then
			iniciarSonar(d, agora)
			d.semGolpeNormal = true
			ctx.parar(d)
			return true
		end
	end
	h.pendente = false

	-- Calmo andando: bate em poste/parede à frente
	local b = cf.batida
	if d.perc.estado == "Calmo" and agora >= h.batidaCheck then
		h.batidaCheck = agora + b.cada
		local v = d.hrp.AssemblyLinearVelocity
		if
			math.sqrt(v.X * v.X + v.Z * v.Z) >= b.velMinima
			and Regras.pronto(h.batidaUltimo, agora, b.recarga)
			and bateuNaFrente(d, b.alcance)
		then
			h.batidaUltimo = agora
			ctx.tocarAcao(d, "WallSlam", agora, 1.0)
			local ruido = ctx.servico("Ruido")
			if ruido then
				ruido.emitir(d.hrp.Position, b.db, "batidaCorpo", d.modelo)
			end
		end
	end
	return false
end

return M
