--!strict
-- Regras puras dos braços em 1ª pessoa com clipes (docs/personagens.md, Parte A2). Sem Instance, testável em Lune.
-- Escolha de clipe por evento, velocidade (AdjustSpeed) para casar o clipe com a duração real que o servidor/Config mandam,
-- etapas da recarga por cartucho, compensação de FOV e a regra do IK da mão esquerda. Dono: A2.

local BracosVista = {}

export type Etapa = { clipe: string, inicio: number, duracao: number }
export type RegrasIK = { desligar: { [string]: boolean }, janelas: { [string]: { number } } }

local function numero(v: any, reserva: number): number
	if type(v) == "number" and v == v and v > 0 and v < math.huge then
		return v
	end
	return reserva
end

-- Velocidade para um clipe de duração `nativa` durar `alvo` segundos, limitada a [minimo, maximo]. Dado ruim = 1.
function BracosVista.velocidade(nativa: number, alvo: number, minimo: number, maximo: number): number
	if type(nativa) ~= "number" or type(alvo) ~= "number" or not (nativa > 0) or not (alvo > 0) then
		return 1
	end
	return math.clamp(nativa / alvo, minimo, maximo)
end

-- Tiro: nunca mais lento que o nativo (o clipe de tiro é curto), mais rápido se a cadência é menor que o clipe.
function BracosVista.velocidadeTiro(nativa: number, cadencia: number, maximo: number): number
	return math.clamp(numero(nativa, 0.15) / math.max(numero(cadencia, nativa), 0.05), 1, maximo)
end

-- Golpe: o marcador "Impacto" do clipe (impactoNativo, s) tem de cair em `atrasoImpacto` (Config/Armas); além disso o golpe
-- inteiro não pode passar de 95% da cadência (o próximo golpe não começa em cima do anterior).
function BracosVista.velocidadeGolpe(
	impactoNativo: number?,
	atrasoImpacto: number,
	nativa: number,
	cadencia: number,
	minimo: number,
	maximo: number
): number
	local v = 1
	if impactoNativo and impactoNativo > 0 and atrasoImpacto > 0 then
		v = impactoNativo / atrasoImpacto
	end
	local teto = numero(nativa, 1) / math.max(numero(cadencia, 1) * 0.95, 0.05)
	return math.clamp(math.max(v, teto), minimo, maximo)
end

-- Nome do clipe de golpe: a faca alterna Golpe1/Golpe2 (índice do ArmasCliente), as outras têm um só.
function BracosVista.clipeGolpe(classe: string, indice: number?): string
	if classe == "faca" then
		return if indice == 2 then "Golpe2" else "Golpe1"
	end
	return "Golpe"
end

-- Recarga por cartucho (escopeta): Inicio, N x Cartucho, Fim, com N pelo tempo total que o servidor mandou
-- (mesma conta de ArmasTerceira). `duracaoAlvo` de cada etapa é a do Config/Armas.recarga; `inicio` é o instante dela na recarga.
function BracosVista.etapasTubo(inicio: number, porCartucho: number, fim: number, total: number): { Etapa }
	local etapas: { Etapa } = {}
	local n = math.max(0, math.floor((total - inicio - fim) / math.max(porCartucho, 0.05) + 0.5))
	local t = 0
	table.insert(etapas, { clipe = "RecargaInicio", inicio = t, duracao = inicio })
	t += inicio
	for _ = 1, n do
		table.insert(etapas, { clipe = "RecargaCartucho", inicio = t, duracao = porCartucho })
		t += porCartucho
	end
	table.insert(etapas, { clipe = "RecargaFim", inicio = t, duracao = fim })
	return etapas
end

-- Escala lateral/vertical para a arma manter o lugar na tela quando o FOV da câmera muda (corrida = 78): razão das
-- tangentes do meio-FOV. FOV inválido = 1.
function BracosVista.compensarFov(fov: number, referencia: number): number
	if
		type(fov) ~= "number"
		or type(referencia) ~= "number"
		or fov < 1
		or fov > 170
		or referencia < 1
		or referencia > 170
	then
		return 1
	end
	return math.tan(math.rad(fov) / 2) / math.tan(math.rad(referencia) / 2)
end

-- Mão esquerda por IKControl: desejado só com arma de duas mãos, e quando o clipe em andamento não anima essa mão
-- (lista `desligar`) nem está dentro de uma janela de `janelas` (segundos, na velocidade nativa do clipe).
-- `nomeClipe` nil = nenhum clipe de ação tocando.
function BracosVista.ikDesejado(regras: RegrasIK?, duasMaos: boolean, nomeClipe: string?, tempo: number): boolean
	if not duasMaos then
		return false
	end
	if regras and nomeClipe then
		if regras.desligar[nomeClipe] then
			return false
		end
		local janela = regras.janelas[nomeClipe]
		if janela and tempo >= janela[1] and tempo <= janela[2] then
			return false
		end
	end
	return true
end

return BracosVista
