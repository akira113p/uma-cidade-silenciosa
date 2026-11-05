--!strict
-- MonstroMovimento: degraus, salto e "travado" do Rastejador (docs/rastejador.md §5.2). O Humanoid sobe sozinho até
-- Config/Rastejador.degrau.andar (medido 1,45 studs); acima disso a sonda decide entre saltar e obstáculo (parede).
-- Estado por monstro em d.cap (criado pelo Monstros). Sonda só roda para quem Monstros mandou (ativo e perto de jogador).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared.Config.Rastejador) :: any
local Regras = require(Shared.Regras.Rastejador)

local MonstroMovimento = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local proximoFiltro = 0

-- Fora do raycast: monstros, personagens, itens no chão e sons soltos. Reconstruído a cada 2 s.
local function atualizarFiltro(agora: number)
	if agora < proximoFiltro then
		return
	end
	proximoFiltro = agora + 2
	local lista: { Instance } = {}
	for _, nome in { "Monstros", "ItensChao", "SonsSoltos" } do
		local f = workspace:FindFirstChild(nome)
		if f then
			table.insert(lista, f)
		end
	end
	for _, j in game:GetService("Players"):GetPlayers() do
		if j.Character then
			table.insert(lista, j.Character)
		end
	end
	params.FilterDescendantsInstances = lista
end

local function horizontal(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function pe(d: any): number -- altura do pé (chão sob o corpo)
	return d.hrp.Position.Y - d.hrp.Size.Y / 2 - d.humanoid.HipHeight
end

function MonstroMovimento.saltar(d: any, altura: number)
	local h: Humanoid = d.humanoid
	local estado = h:GetState()
	if estado == Enum.HumanoidStateType.Jumping or estado == Enum.HumanoidStateType.Freefall then
		return
	end
	h.UseJumpPower = false
	h.JumpHeight = Regras.alturaDoSalto(altura, Cfg)
	h.Jump = true
end

-- Waypoint do caminho com Action == Jump: salta a altura medida entre o pé e o waypoint.
function MonstroMovimento.saltarPara(d: any, destino: Vector3)
	MonstroMovimento.saltar(d, math.max(destino.Y - pe(d), Cfg.degrau.andar))
end

-- Sonda de degrau (10 Hz, chamada pelo laço de 5 Hz: a distância da sonda cobre o que ele anda no intervalo).
-- Devolve "andar" | "saltar" | "parede" | nil (sem obstáculo acima do que se sobe andando).
function MonstroMovimento.sondar(d: any, agora: number): string?
	local cap = d.cap
	if agora < (cap.proxSonda or 0) then
		return nil
	end
	cap.proxSonda = agora + 1 / Cfg.degrau.hz
	local dir3: Vector3 = d.humanoid.MoveDirection
	if dir3.Magnitude < 0.1 then
		cap.obstruido = nil
		return nil
	end
	atualizarFiltro(agora)
	local dir = Vector3.new(dir3.X, 0, dir3.Z).Unit
	local pos: Vector3 = d.hrp.Position
	local chao = pe(d)
	local meio = Cfg.arrombar.raioFolga
	local vel = horizontal(d.hrp.AssemblyLinearVelocity)
	local alcance = Cfg.degrau.sondaFrente + vel / Cfg.degrau.hz
	-- raio horizontal logo acima do que o Humanoid sobe sozinho: só acerta o que é mais alto que `andar`
	local origem = Vector3.new(pos.X, chao + Cfg.degrau.andar + 0.15, pos.Z)
	local r = workspace:Raycast(origem, dir * (meio + alcance), params)
	if not r then
		cap.obstruido = nil
		return nil
	end
	local dist = horizontal(r.Position - origem) - meio
	-- topo do obstáculo: raio para baixo um pouco dentro dele, desde saltoMax + 1 acima do pé
	local alto = chao + Cfg.degrau.saltoMax + 1
	local ponto = r.Position + dir * 0.4
	local topo =
		workspace:Raycast(Vector3.new(ponto.X, alto, ponto.Z), Vector3.new(0, -(Cfg.degrau.saltoMax + 1.5), 0), params)
	if not topo then
		cap.obstruido = { peca = r.Instance, ponto = r.Position }
		return "parede"
	end
	local altura = topo.Position.Y - chao
	local acima =
		workspace:Raycast(topo.Position + Vector3.new(0, 0.05, 0), Vector3.new(0, Cfg.degrau.folgaMin + 0.5, 0), params)
	local folga = if acima then acima.Distance else Cfg.degrau.folgaMin + 0.5
	local classe = Regras.classificarDegrau(altura, folga, Cfg)
	if classe == "saltar" then
		cap.obstruido = nil
		if dist <= math.max(1.2, vel * 0.3) then
			MonstroMovimento.saltar(d, altura)
		end
	elseif classe == "parede" then
		cap.obstruido = { peca = r.Instance, ponto = r.Position }
	else
		cap.obstruido = nil
	end
	return classe
end

-- Travado (não andou `travadoMinimo` em `travadoCada` com MoveDirection > 0): 1ª salta, 2ª recalcula o caminho,
-- 3ª sinaliza parede (Arrombar vê `cap.forcarParede`) e escolhe outro ponto de vagar. Devolve o passo tomado.
function MonstroMovimento.travado(d: any, agora: number): string
	local cap = d.cap
	cap.travados = (cap.travados or 0) + 1
	local n = cap.travados
	if n == 1 then
		MonstroMovimento.saltar(d, Cfg.travado.saltoAltura)
		return "salto"
	elseif n == 2 then
		d.alvoCaminho = nil
		d.waypoints = nil
		return "recalcular"
	end
	cap.travados = 0
	cap.forcarParede = true
	d.alvoCaminho = nil
	d.waypoints = nil
	d.destinoVagar = nil
	d.proximaVagada = agora
	return "parede"
end

function MonstroMovimento.andou(d: any)
	d.cap.travados = 0
end

return MonstroMovimento
