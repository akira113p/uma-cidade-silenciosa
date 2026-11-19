--!strict
-- Regras dos veículos: estado de dano, ligar, limites de condução, batida e tiro. Puro (sem Roblox). Dono: V1.
-- Contrato: docs/veiculos.md. Nenhuma função muda a entrada; Estado novo é cópia.
-- puxa: -1..1, positivo = o carro desvia para a DIREITA (pneu ruim à direita puxa para a direita).

local Veiculo = {}

export type Pneu = "ok" | "furado" | "faltando"
export type Vidro = "ok" | "quebrado" | "faltando"
export type Estado = {
	tipo: string,
	condicao: string,
	queimado: boolean,
	motor: number,
	carroceria: number,
	pneus: { [string]: Pneu },
	vidros: { [string]: Vidro },
	faltando: { [string]: boolean },
	amassado: { [string]: boolean },
	combustivel: number, -- litros no tanque (0..Config/Veiculos.tipos[tipo].tanque)
}
export type Resultado = { vidros: { string }, pneus: { string }, motorQuebrou: boolean, amassou: string? }

local RODAS = { "FE", "FD", "TE", "TD" }
local VIDROS = { "ParaBrisa", "Traseiro", "JanelaE", "JanelaD" }
local PECAS = { "Capo", "PortaMalas", "PortaE", "PortaD", "ParaChoque" }
local CONDICOES = { "inteiro", "avariado", "destruido", "queimado" } -- ordem fixa: sorteio determinístico
local VIDRO_DO_LADO: { [string]: string } = {
	Frente = "ParaBrisa",
	Tras = "Traseiro",
	Esquerda = "JanelaE",
	Direita = "JanelaD",
}
local RODAS_DO_LADO: { [string]: { string } } = {
	Frente = { "FE", "FD" },
	Tras = { "TE", "TD" },
	Esquerda = { "FE", "TE" },
	Direita = { "FD", "TD" },
}

local function sorteio01(rng: () -> number): number
	return math.clamp(rng(), 0, 0.999999999)
end

local function faixa(f: { number }, rng: () -> number): number
	return f[1] + (f[2] - f[1]) * sorteio01(rng)
end

local function copiar(e: Estado): Estado
	return {
		tipo = e.tipo,
		condicao = e.condicao,
		queimado = e.queimado,
		motor = e.motor,
		carroceria = e.carroceria,
		pneus = table.clone(e.pneus),
		vidros = table.clone(e.vidros),
		faltando = table.clone(e.faltando),
		amassado = table.clone(e.amassado),
		combustivel = e.combustivel,
	}
end

local function vazio(): Resultado
	return { vidros = {}, pneus = {}, motorQuebrou = false, amassou = nil }
end

local function tanqueDe(tipo: string, cfg: any): number
	local t = cfg.tipos[tipo]
	return if t and type(t.tanque) == "number" then t.tanque else 0
end

function Veiculo.sortear(tipo: string, rng: () -> number, cfg: any): Estado
	local total = 0
	for _, n in CONDICOES do
		total += cfg.condicoes[n].peso
	end
	local alvo = sorteio01(rng) * total
	local nome = "avariado"
	for _, n in CONDICOES do
		nome = n
		alvo -= cfg.condicoes[n].peso
		if alvo < 0 then
			break
		end
	end
	local c = cfg.condicoes[nome]
	local motor = faixa(c.motor, rng)
	if sorteio01(rng) < c.chanceMotorZero then
		motor = 0
	end
	local e: Estado = {
		tipo = tipo,
		condicao = nome,
		queimado = c.queimado == true,
		motor = math.floor(motor + 0.5),
		carroceria = math.floor(faixa(c.carroceria, rng) + 0.5),
		pneus = {},
		vidros = {},
		faltando = {},
		amassado = { Frente = false, Tras = false, Esquerda = false, Direita = false },
		combustivel = 0, -- sorteado no fim (depois das peças, para não mudar o sorteio do resto)
	}
	for _, r in RODAS do
		local x = sorteio01(rng)
		if x < c.pneuFaltando then
			e.pneus[r] = "faltando"
		elseif x < c.pneuFaltando + c.pneuFurado then
			e.pneus[r] = "furado"
		else
			e.pneus[r] = "ok"
		end
	end
	for _, v in VIDROS do
		local x = sorteio01(rng)
		if x < c.vidroFaltando then
			e.vidros[v] = "faltando"
		elseif x < c.vidroFaltando + c.vidroQuebrado then
			e.vidros[v] = "quebrado"
		else
			e.vidros[v] = "ok"
		end
	end
	for _, p in PECAS do
		e.faltando[p] = sorteio01(rng) < c.pecaFaltando
	end
	-- Combustível: sorteado por último. Queimado nasce vazio; os outros ou vazios (chanceVazio) ou entre min e max do tanque.
	local gas = cfg.condicoes.combustivel
	local vazioSorteado = sorteio01(rng) < gas.chanceVazio
	local fracaoGas = gas.min + (gas.max - gas.min) * sorteio01(rng)
	if e.queimado or vazioSorteado then
		e.combustivel = 0
	else
		e.combustivel = tanqueDe(tipo, cfg) * fracaoGas
	end
	if e.queimado then
		e.motor = 0
	end
	return e
end

-- Estado montado à mão (menu de admin). `pedido` vem do cliente: tudo é validado aqui, campo inválido vira o padrão.
-- Padrão = carro perfeito (motor 100, carroceria 100, nada quebrado nem faltando). Devolve nil se o tipo não existe.
function Veiculo.montar(tipo: any, pedido: any, cfg: any): Estado?
	if type(tipo) ~= "string" or cfg.tipos[tipo] == nil then
		return nil
	end
	local p: { [string]: any } = if type(pedido) == "table" then pedido else {}
	local function porcentagem(v: any): number
		if type(v) ~= "number" or v ~= v then
			return 100
		end
		return math.floor(math.clamp(v, 0, 100) + 0.5)
	end
	local function sub(chave: string): { [string]: any }
		local t = p[chave]
		return if type(t) == "table" then t else {}
	end
	local queimado = p.queimado == true
	local e: Estado = {
		tipo = tipo,
		condicao = if queimado then "queimado" else "personalizado",
		queimado = queimado,
		motor = porcentagem(p.motor),
		carroceria = porcentagem(p.carroceria),
		pneus = {},
		vidros = {},
		faltando = {},
		amassado = { Frente = false, Tras = false, Esquerda = false, Direita = false },
		combustivel = 0,
	}
	-- combustivel: fração 0..1 do tanque (padrão 1 = cheio); inválido vira cheio. Queimado nasce vazio.
	local fracaoGas = 1
	if type(p.combustivel) == "number" and p.combustivel == p.combustivel then
		fracaoGas = math.clamp(p.combustivel, 0, 1)
	end
	e.combustivel = if queimado then 0 else tanqueDe(tipo, cfg) * fracaoGas
	local pneus, vidros, faltando = sub("pneus"), sub("vidros"), sub("faltando")
	for _, r in RODAS do
		local v = pneus[r]
		e.pneus[r] = if v == "furado" or v == "faltando" then v else "ok"
	end
	for _, v in VIDROS do
		local x = vidros[v]
		e.vidros[v] = if x == "quebrado" or x == "faltando" then x else "ok"
	end
	for _, peca in PECAS do
		e.faltando[peca] = faltando[peca] == true
	end
	if queimado then
		e.motor = 0
	end
	return e
end

function Veiculo.podeDirigir(e: Estado): boolean
	return not e.queimado
end

-- Pode girar o motor: dirigível e com gasolina no tanque.
function Veiculo.podeLigar(e: Estado): boolean
	return Veiculo.podeDirigir(e) and e.combustivel > 0
end

-- Sem gasolina devolve false sem gastar sorteio (o rng só anda quando o motor realmente tenta pegar).
function Veiculo.tentarLigar(e: Estado, rng: () -> number, cfg: any): boolean
	if not Veiculo.podeLigar(e) or e.motor <= 0 then
		return false
	end
	local f = math.clamp(e.motor / 100, 0, 1)
	local chance = cfg.ligar.chanceMin + (cfg.ligar.chanceMax - cfg.ligar.chanceMin) * f
	return sorteio01(rng) < chance
end

function Veiculo.limites(e: Estado, cfg: any): { velMax: number, torque: number, aderencia: number, puxa: number }
	local tipo = cfg.tipos[e.tipo]
	local d = cfg.defeitos
	local fMotor = math.clamp(e.motor / 100, 0, 1)
	local velFator = 1
	local aderSoma = 0
	local ruimE, ruimD = 0, 0
	for _, r in RODAS do
		local p = e.pneus[r]
		local peso = if string.sub(r, 1, 1) == "F" then 1 else d.puxaTraseiro
		local esquerda = string.sub(r, 2, 2) == "E"
		local ruim = 0
		if p == "furado" then
			velFator *= d.velPneuFurado
			aderSoma += d.aderenciaFurado
			ruim = d.puxaFurado * peso
		elseif p == "faltando" then
			velFator *= d.velPneuFaltando
			aderSoma += d.aderenciaFaltando
			ruim = peso
		else
			aderSoma += 1
		end
		if esquerda then
			ruimE += ruim
		else
			ruimD += ruim
		end
	end
	velFator = math.max(velFator, d.velMinima)
	local vel = tipo.velMax * velFator * (d.velMotorMin + (1 - d.velMotorMin) * fMotor)
	local torque = tipo.torque * (d.torqueMotorMin + (1 - d.torqueMotorMin) * fMotor)
	local maxLado = 1 + d.puxaTraseiro -- soma máxima de um lado
	local puxa = math.clamp((ruimD - ruimE) / maxLado, -1, 1)
	return { velMax = vel, torque = torque, aderencia = aderSoma / 4, puxa = puxa }
end

function Veiculo.dbMotor(e: Estado, fracaoVelocidade: number, cfg: any): number
	local tipo = cfg.tipos[e.tipo]
	local r = cfg.ruido
	local f = math.clamp(fracaoVelocidade, 0, 1)
	local db = tipo.dbBase + r.aceleracaoDb * f
	db += r.bonusMotorRuim * (1 - math.clamp(e.motor / 100, 0, 1))
	if e.faltando.Capo then
		db += r.bonusCapoFaltando
	end
	return db
end

-- -Z local é a frente, -X a esquerda.
function Veiculo.direcaoBatida(localX: number, localZ: number): string
	if math.abs(localZ) >= math.abs(localX) then
		return if localZ < 0 then "Frente" else "Tras"
	end
	return if localX < 0 then "Esquerda" else "Direita"
end

function Veiculo.bater(e: Estado, deltaV: number, lado: string, rng: () -> number, cfg: any): (Estado, Resultado)
	local b = cfg.batida
	local res = vazio()
	if deltaV < b.limiarDeltaV then
		return e, res
	end
	local n = copiar(e)
	local sev = math.clamp((deltaV - b.limiarDeltaV) / (b.deltaVTotal - b.limiarDeltaV), 0, 1)
	n.carroceria = math.max(0, n.carroceria - deltaV * b.escalaCarroceria)
	local escalaMotor = if lado == "Frente" then b.escalaMotorFrente else b.escalaMotorOutros
	if n.motor > 0 then
		n.motor = math.max(0, n.motor - deltaV * escalaMotor)
		if n.motor <= 0 then
			res.motorQuebrou = true
		end
	end
	if n.amassado[lado] == false then
		n.amassado[lado] = true
		res.amassou = lado
	end
	local vidroDoLado = VIDRO_DO_LADO[lado]
	for _, v in VIDROS do
		if n.vidros[v] == "ok" then
			local chance = sev * (if v == vidroDoLado then b.chanceVidroLado else b.chanceVidroOutros)
			if sorteio01(rng) < chance then
				n.vidros[v] = "quebrado"
				table.insert(res.vidros, v)
			end
		end
	end
	local doLado = RODAS_DO_LADO[lado]
	if doLado then
		for _, r in doLado do
			if n.pneus[r] == "ok" and sorteio01(rng) < sev * b.chancePneu then
				n.pneus[r] = "furado"
				table.insert(res.pneus, r)
			end
		end
	end
	return n, res
end

-- peca: "Pneu_FE" | "Vidro_ParaBrisa" | "Motor" | "Carroceria". Nomes no Resultado sem prefixo ("FE", "ParaBrisa").
function Veiculo.acertar(e: Estado, peca: string, dano: number, rng: () -> number, cfg: any): (Estado, Resultado)
	local t = cfg.tiro
	local res = vazio()
	local n = copiar(e)
	local fator = math.max(0, dano) / t.danoReferencia
	local pneu = string.match(peca, "^Pneu_(%a+)$")
	local vidro = string.match(peca, "^Vidro_(%a+)$")
	if pneu then
		if n.pneus[pneu] == "ok" and sorteio01(rng) < math.min(1, t.chancePneu * fator) then
			n.pneus[pneu] = "furado"
			table.insert(res.pneus, pneu)
			return n, res
		end
	elseif vidro then
		if n.vidros[vidro] == "ok" and sorteio01(rng) < math.min(1, t.chanceVidro * fator) then
			n.vidros[vidro] = "quebrado"
			table.insert(res.vidros, vidro)
			return n, res
		end
	elseif peca == "Motor" then
		if n.motor > 0 then
			n.motor = math.max(0, n.motor - dano * t.danoMotor)
			if n.motor <= 0 then
				res.motorQuebrou = true
			end
			return n, res
		end
	elseif peca == "Carroceria" then
		n.carroceria = math.max(0, n.carroceria - dano * t.danoCarroceria)
		return n, res
	end
	return e, res
end

-- Condução dinâmica (usada pelo client/Direcao; puro para testar) ------------------------------------------------------

-- Taxa de giro (rad/s em torno de Y, esquerda positivo) que um carro de entre-eixos `entreEixos` teria com as rodas em
-- `anguloGraus` (direita positivo) andando a `velFrente` (studs/s, ré negativa). `fator` > 1 exagera o giro (freio de mão).
function Veiculo.guinadaAlvo(
	anguloGraus: number,
	velFrente: number,
	entreEixos: number,
	fator: number,
	maximo: number
): number
	local giro = -math.tan(math.rad(anguloGraus)) * velFrente / math.max(entreEixos, 1) * fator
	return math.clamp(giro, -maximo, maximo)
end

-- Correção automática do volante quando o carro desliza de lado: `deslize` = velocidade lateral (studs/s, direita positivo).
-- Vira para o lado da deriva (contra-esterço); abaixo de `limiar` não faz nada e a correção cresce a partir dele.
function Veiculo.contraVolante(deslize: number, limiar: number, ganho: number, maximoGraus: number): number
	local excesso = math.abs(deslize) - limiar
	if excesso <= 0 then
		return 0
	end
	return math.sign(deslize) * math.min(excesso * ganho, maximoGraus)
end

-- Está derrapando de forma audível? (o servidor emite ruído de pneu): rápido o bastante e com deslize lateral grande.
function Veiculo.derrapando(velocidade: number, deslizeLateral: number, cfg: any): boolean
	local d = cfg.derrapagem
	return velocidade >= d.velMin and math.abs(deslizeLateral) >= d.deslizeMin
end

function Veiculo.danoOcupante(deltaV: number, cfg: any): number
	local d = cfg.batida.danoOcupante
	if deltaV < cfg.batida.limiarDeltaV then
		return 0
	end
	return math.clamp((deltaV - d.limiar) * d.porDeltaV, 0, d.maximo)
end

return Veiculo
