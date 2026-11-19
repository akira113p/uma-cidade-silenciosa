--!strict
-- MonstroObjetivo: escolhe o objetivo físico do Rastejador a cada passo da IA (docs/rastejador.md §5.1, §5.4).
-- Prioridade (Regras.escolherObjetivo): jogador ao alcance > veículo ruidoso > parede a arrombar > ponto de som.
-- Jogador ao alcance e ponto de som continuam no laço do Monstros; aqui entram veículo e parede. Estado em d.cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Malhas = require(Shared.Config.MonstrosMalhas) :: any
local Regras = require(Shared.Regras.Rastejador)

local MonstroObjetivo = {}

local ctx: any = {} -- { servico, animar, arrombar }
function MonstroObjetivo.configurar(c: any)
	ctx = c
end

local random = Random.new()

local function horizontal(v: Vector3): number
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

local function ehTipoDeSom(Cfg: any, tipo: string): boolean
	return table.find(Cfg.veiculo.tiposDeSom, tipo) ~= nil
end

-- Jogador sentado em veículo com os vidros laterais inteiros não é atacável (o monstro bate no carro).
-- REGRA NOVA a confirmar com o usuário: docs/pendencias-integracao.md, "Rastejador".
function MonstroObjetivo.atacavel(jogador: Player): boolean
	local char = jogador.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat then
		return true
	end
	local modelo = seat:FindFirstAncestorOfClass("Model")
	local veic = ctx.servico and ctx.servico("Veiculos")
	local estado = modelo and veic and veic.estadoDe(modelo)
	if not estado then
		return true
	end
	for _, lado in { "JanelaE", "JanelaD" } do
		if estado.vidros[lado] ~= "ok" then
			return true
		end
	end
	return false
end

-- Som de veículo ouvido por este monstro: guarda o veículo mais perto da fonte (raioBusca) e o instante.
function MonstroObjetivo.somVeiculo(d: any, tipo: string, posicao: Vector3, agora: number)
	if d.especie.capacidades.veiculo ~= true then
		return
	end
	local Cfg = d.preset
	if not ehTipoDeSom(Cfg, tipo) then
		return
	end
	local veic = ctx.servico and ctx.servico("Veiculos")
	local modelo: Model? = if veic then veic.maisPertoDe(posicao, Cfg.veiculo.raioBusca) else nil
	if not modelo then
		return
	end
	local v = d.cap.veiculo
	if v and v.modelo == modelo then
		v.ultimoSom = agora
	else
		d.cap.veiculo = { modelo = modelo, ultimoSom = agora, desde = agora, proximoGolpe = 0 }
	end
end

local function ocupado(modelo: Model): boolean
	for _, p in modelo:GetDescendants() do
		if p:IsA("Seat") and p.Occupant then
			return true
		end
	end
	return false
end

-- Ponto da caixa do veículo mais perto de `pos` e a distância horizontal até ele.
local function pontoDaCaixa(modelo: Model, pos: Vector3): (Vector3, number)
	local cf, tam = modelo:GetBoundingBox()
	local l = cf:PointToObjectSpace(pos)
	local c = Vector3.new(
		math.clamp(l.X, -tam.X / 2, tam.X / 2),
		math.clamp(l.Y, -tam.Y / 2, tam.Y / 2),
		math.clamp(l.Z, -tam.Z / 2, tam.Z / 2)
	)
	local p = cf * c
	return p, horizontal(p - pos)
end

local function acharPeca(modelo: Model, parte: string, de: Vector3): BasePart?
	local prefixo = if parte == "pneu" then "Pneu_" elseif parte == "vidro" then "Vidro_" else "Carroceria"
	local melhor: BasePart? = nil
	local menor = math.huge
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			local nome = p:GetAttribute("PecaVeiculo")
			if type(nome) == "string" and string.sub(nome, 1, #prefixo) == prefixo then
				local dist = (p.Position - de).Magnitude
				if dist < menor then
					melhor, menor = p, dist
				end
			end
		end
	end
	return melhor
end

local function bater(d: any, v: any, agora: number)
	local Cfg = d.preset
	v.proximoGolpe = agora + Cfg.veiculo.intervalo
	d.clipe = nil -- Attack (no Wrapper, Attack_Lunge)
	d.golpeAte = agora + (Malhas[d.especie.id] and Malhas[d.especie.id].duracao.Attack or 1)
	if ctx.animar then
		ctx.animar(d, agora, true)
	end
	task.delay(Cfg.golpe.atrasoImpacto, function()
		local modelo: Model = v.modelo
		if not (d.vivo and modelo.Parent) then
			return
		end
		local parte = Regras.parteDoVeiculo(random:NextNumber(), ocupado(modelo), Cfg)
		local peca = acharPeca(modelo, parte, d.hrp.Position) or acharPeca(modelo, "carroceria", d.hrp.Position)
		local veic = ctx.servico and ctx.servico("Veiculos")
		if peca and veic then
			veic.acerto(peca, Cfg.veiculo.dano, nil)
		end
	end)
end

-- Um passo. `perc` = d.perc. Devolve { tipo, alvo: Vector3 } para o Monstros seguir, ou nil (fluxo normal: vagar/ponto de som).
function MonstroObjetivo.passo(d: any, agora: number, perc: any, jogadorPos: Vector3?, distJogador: number?): any?
	local Cfg = d.preset
	local cap = d.cap
	local pos: Vector3 = d.hrp.Position
	local cands: { [string]: any } = {}

	local v = cap.veiculo
	if v then
		local modelo: Model = v.modelo
		local veic = ctx.servico and ctx.servico("Veiculos")
		local estado = if veic and modelo.Parent then veic.estadoDe(modelo) else nil
		if not modelo.Parent or (estado and estado.queimado) then
			cap.veiculo = nil
		else
			local base = modelo.PrimaryPart
			local vel = if base then horizontal(base.AssemblyLinearVelocity) else 0
			if vel > d.humanoid.WalkSpeed * 0.9 then
				v.rapidoDesde = v.rapidoDesde or agora
			else
				v.rapidoDesde = nil
			end
			-- carro em fuga: persegue só por perseguirMax s e depois segue o último som como ponto de som
			if not (v.rapidoDesde and agora - v.rapidoDesde > Cfg.veiculo.perseguirMax) then
				local ponto, dist = pontoDaCaixa(modelo, pos)
				cands.veiculo = {
					tipo = "veiculo",
					distancia = dist,
					idade = agora - v.ultimoSom,
					ocupado = ocupado(modelo),
					ponto = ponto,
				}
			end
		end
	end

	local alvoSom: Vector3? = if perc.alvo and perc.estado ~= "Calmo"
		then Vector3.new(perc.alvo.x, perc.alvo.y, perc.alvo.z)
		else nil
	if alvoSom then
		-- alvo da parede: com o jogador a <= alvoRealDist (já o ouviu/atacou) é a posição dele; senão o som ESTIMADO, com o erro
		-- de posição (erroDentro x distância) tolerado no teste "dentro de construção"
		local real = jogadorPos ~= nil and distJogador ~= nil and distJogador <= Cfg.arrombar.alvoRealDist
		local alvoParede: Vector3 = if real and jogadorPos then jogadorPos else alvoSom
		local erro = if real then 0 else horizontal(alvoSom - pos) * Cfg.arrombar.erroDentro
		local pr = if ctx.arrombar then ctx.arrombar.candidato(d, alvoParede, agora, erro) else nil
		if pr then
			cands.parede = pr
		end
		cands.som = { tipo = "som", distancia = horizontal(alvoSom - pos), ponto = alvoSom }
	elseif cap.parede and ctx.arrombar then
		-- parede em andamento mesmo se a percepção esfriou: termina o que começou
		cands.parede = ctx.arrombar.candidato(d, pos, agora)
	end

	local lista = {}
	for _, c in cands do
		table.insert(lista, c)
	end
	local melhor = Regras.escolherObjetivo(lista, Cfg)
	-- histerese: não troca de objetivo antes de `histerese` s, a menos que o anterior tenha deixado de valer
	if
		melhor
		and cap.objTipo
		and melhor.tipo ~= cap.objTipo
		and agora - (cap.objDesde or 0) < Cfg.objetivo.histerese
	then
		local anterior = cands[cap.objTipo]
		if anterior then
			melhor = anterior
		end
	end
	if not melhor then
		cap.objTipo = nil
		return nil
	end
	if melhor.tipo ~= cap.objTipo then
		cap.objTipo = melhor.tipo
		cap.objDesde = agora
	end

	if melhor.tipo == "veiculo" then
		local vv = cap.veiculo
		if melhor.distancia <= Cfg.veiculo.alcance + Cfg.arrombar.raioFolga and agora >= vv.proximoGolpe then
			bater(d, vv, agora)
		end
		return { tipo = "veiculo", alvo = melhor.ponto }
	elseif melhor.tipo == "parede" and ctx.arrombar then
		local alvo, direto = ctx.arrombar.passo(d, agora)
		return if alvo then { tipo = "parede", alvo = alvo, direto = direto } else nil
	end
	return nil -- som: o Monstros segue perc.alvo como sempre
end

return MonstroObjetivo
