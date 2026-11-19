-- Regras/Animacao: contas puras dos clipes de animação (dado JSON -> quadros resolvidos) e decisões do AnimacaoCorpo.
-- Dono: A1 (docs/personagens.md §2/A1). Sem Instance, sem Enum, sem CFrame: testado em tests/Animacao.spec.luau e usado
-- pelo shared/Animacao (que monta a KeyframeSequence) e por ferramentas/animacao/validar_corpo.luau (folha de quadros).
-- Formato do clipe (igual ao de assets/animacoes/armas/*.json, lido por ferramentas/animacao/montar_armas.luau):
--   arquivo = { poses = { nome = { Junta = {rx,ry,rz[,px,py,pz]} } }, clipes = { Nome = { duracao, loop, prioridade, quadros } } }
--   quadro  = { t, de? = nome de pose, juntas? = {...}, easing? = "Cubic-Out", marcadores? = { "Nome" } }
-- Ângulos em graus (ordem YXZ), posição em studs, junta = nome do Motor6D do R15, a Pose vai na peça filha.
-- O easing escrito num quadro vale na CHEGADA a ele (o Roblox guarda o easing do trecho na pose anterior: ver Animacao.sequencia).

local Regra = {}

export type Quadro = {
	t: number,
	easing: string?,
	marcadores: { string }?,
	juntas: { [string]: { number } },
}

-- junta do R15 -> peça filha (onde a Pose fica) e peça pai
Regra.JUNTA_PECA = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
} :: { [string]: string }

Regra.PAI_PECA = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
} :: { [string]: string }

Regra.PRIORIDADES = {
	Core = 1,
	Idle = 2,
	Movement = 3,
	Action = 4,
	Action2 = 5,
	Action3 = 6,
	Action4 = 7,
} :: { [string]: number }

Regra.ESTILOS =
	{ Linear = true, Constant = true, Elastic = true, Cubic = true, Bounce = true, CubicV2 = true } :: { [string]: boolean }
Regra.DIRECOES = { In = true, Out = true, InOut = true } :: { [string]: boolean }

Regra.PERNAS = {
	LeftHip = true,
	LeftKnee = true,
	LeftAnkle = true,
	RightHip = true,
	RightKnee = true,
	RightAnkle = true,
} :: { [string]: boolean }

-- Limites angulares plausíveis (graus) por junta: { {minX,maxX}, {minY,maxY}, {minZ,maxZ} }. Convenção do R15 do jogo
-- (conferida nos clipes de arma): ombro +X levanta o braço para a frente, cotovelo +X dobra, joelho -X dobra,
-- cintura/raiz +X inclina para trás, -X para a frente. A raiz (Root) é livre porque o clipe de morte deita o corpo.
local LIVRE = { -180, 180 }
Regra.LIMITES = {
	Root = { LIVRE, LIVRE, LIVRE },
	Waist = { { -60, 45 }, { -60, 60 }, { -40, 40 } },
	Neck = { { -60, 60 }, { -75, 75 }, { -40, 40 } },
	LeftShoulder = { { -90, 180 }, { -100, 100 }, { -100, 100 } },
	RightShoulder = { { -90, 180 }, { -100, 100 }, { -100, 100 } },
	LeftElbow = { { -5, 150 }, { -20, 20 }, { -20, 20 } },
	RightElbow = { { -5, 150 }, { -20, 20 }, { -20, 20 } },
	LeftWrist = { { -80, 80 }, { -45, 45 }, { -45, 45 } },
	RightWrist = { { -80, 80 }, { -45, 45 }, { -45, 45 } },
	LeftHip = { { -90, 120 }, { -45, 45 }, { -45, 60 } },
	RightHip = { { -90, 120 }, { -45, 45 }, { -60, 45 } },
	LeftKnee = { { -150, 5 }, { -10, 10 }, { -10, 10 } },
	RightKnee = { { -150, 5 }, { -10, 10 }, { -10, 10 } },
	LeftAnkle = { { -50, 50 }, { -20, 20 }, { -20, 20 } },
	RightAnkle = { { -50, 50 }, { -20, 20 }, { -20, 20 } },
} :: { [string]: { { number } } }

Regra.TOLERANCIA_ULTIMO_QUADRO = 1e-4
Regra.POSICAO_MAX = 4 -- studs: deslocamento máximo de uma junta num quadro

-- "Cubic-Out" -> "Cubic", "Out". nil/inválido -> Linear, In (o mesmo de montar_armas.luau).
function Regra.easing(texto: string?): (string, string)
	if not texto then
		return "Linear", "In"
	end
	local estilo, direcao = string.match(texto, "^(%a+)%-?(%a*)$")
	if not estilo or not Regra.ESTILOS[estilo] then
		return "Linear", "In"
	end
	if direcao == "" or not Regra.DIRECOES[direcao] then
		direcao = "In"
	end
	return estilo, direcao
end

local function numerico(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Resolve "de" + "juntas" de um quadro. Devolve a tabela ou nil, motivo.
local function juntasDoQuadro(poses: any, q: any): ({ [string]: { number } }?, string?)
	local r: { [string]: { number } } = {}
	if q.de ~= nil then
		local base = poses[q.de]
		if type(base) ~= "table" then
			return nil, "pose inexistente: " .. tostring(q.de)
		end
		for j, v in base do
			r[j] = v
		end
	end
	for j, v in q.juntas or {} do
		r[j] = v
	end
	for j, v in r do
		if not Regra.JUNTA_PECA[j] then
			return nil, "junta desconhecida: " .. tostring(j)
		end
		if type(v) ~= "table" or (#v ~= 3 and #v ~= 6) then
			return nil, "junta " .. j .. " precisa de 3 ou 6 números"
		end
		for i = 1, #v do
			if not numerico(v[i]) then
				return nil, "junta " .. j .. " com valor inválido"
			end
		end
	end
	return r
end

-- Quadros do clipe em ordem de tempo, com poses e juntas resolvidas. nil, motivo se o clipe não existe ou está quebrado.
function Regra.resolverQuadros(arquivo: any, nomeClipe: string): ({ Quadro }?, string?)
	local clipe = arquivo and arquivo.clipes and arquivo.clipes[nomeClipe]
	if type(clipe) ~= "table" or type(clipe.quadros) ~= "table" then
		return nil, "clipe inexistente: " .. tostring(nomeClipe)
	end
	local saida: { Quadro } = {}
	for i, q in clipe.quadros do
		if not numerico(q.t) then
			return nil, `quadro {i} sem tempo`
		end
		local juntas, erro = juntasDoQuadro(arquivo.poses or {}, q)
		if not juntas then
			return nil, `quadro {i}: {erro}`
		end
		table.insert(saida, { t = q.t, easing = q.easing, marcadores = q.marcadores, juntas = juntas })
	end
	table.sort(saida, function(a, b)
		return a.t < b.t
	end)
	return saida
end

local function igualJuntas(a: { [string]: { number } }, b: { [string]: { number } }): boolean
	for j, va in a do
		local vb = b[j]
		if not vb or #va ~= #vb then
			return false
		end
		for i = 1, #va do
			if math.abs(va[i] - vb[i]) > 1e-3 then
				return false
			end
		end
	end
	for j in b do
		if not a[j] then
			return false
		end
	end
	return true
end

-- Problemas do clipe (lista de textos; vazia = ok). `opcoes.proibidas`: conjunto de juntas que o clipe não pode usar
-- (ex.: pernas nos clipes de carro e de mão).
function Regra.validarClipe(arquivo: any, nomeClipe: string, opcoes: { proibidas: { [string]: boolean }? }?): { string }
	local erros: { string } = {}
	local function erro(texto: string)
		table.insert(erros, texto)
	end
	local clipe = arquivo and arquivo.clipes and arquivo.clipes[nomeClipe]
	if type(clipe) ~= "table" then
		return { "clipe inexistente" }
	end
	if not (numerico(clipe.duracao) and clipe.duracao > 0) then
		erro("duracao inválida")
	end
	if clipe.prioridade ~= nil and not Regra.PRIORIDADES[clipe.prioridade] then
		erro("prioridade desconhecida: " .. tostring(clipe.prioridade))
	end
	if clipe.loop ~= nil and type(clipe.loop) ~= "boolean" then
		erro("loop precisa ser booleano")
	end
	local quadros, motivo = Regra.resolverQuadros(arquivo, nomeClipe)
	if not quadros then
		erro(motivo or "quadros inválidos")
		return erros
	end
	if #quadros < 2 then
		erro("precisa de 2+ quadros")
		return erros
	end
	if quadros[1].t ~= 0 then
		erro("primeiro quadro deve estar em t=0")
	end
	if numerico(clipe.duracao) and math.abs(quadros[#quadros].t - clipe.duracao) > Regra.TOLERANCIA_ULTIMO_QUADRO then
		erro(`duração {clipe.duracao} diferente do último quadro {quadros[#quadros].t}`)
	end
	local proibidas = opcoes and opcoes.proibidas or {}
	for i, q in quadros do
		if i > 1 and q.t <= quadros[i - 1].t then
			erro(`tempos não crescentes no quadro {i}`)
		end
		if q.easing ~= nil then
			local estilo = string.match(q.easing, "^(%a+)")
			if not (estilo and Regra.ESTILOS[estilo]) then
				erro(`easing inválido no quadro {i}: {q.easing}`)
			end
		end
		if next(q.juntas) == nil then
			erro(`quadro {i} sem juntas`)
		end
		for _, m in q.marcadores or {} do
			if type(m) ~= "string" or m == "" then
				erro(`marcador inválido no quadro {i}`)
			end
		end
		for j, v in q.juntas do
			if proibidas[j] then
				erro(`quadro {i}: junta {j} proibida neste grupo`)
			end
			local lim = Regra.LIMITES[j]
			if lim then
				for eixo = 1, 3 do
					local x = v[eixo] or 0
					if x < lim[eixo][1] or x > lim[eixo][2] then
						erro(
							`quadro {i}: {j} eixo {string.sub("XYZ", eixo, eixo)}={x} fora de [{lim[eixo][1]},{lim[eixo][2]}]`
						)
					end
				end
			end
			if #v == 6 then
				local d = math.sqrt(v[4] ^ 2 + v[5] ^ 2 + v[6] ^ 2)
				if d > Regra.POSICAO_MAX then
					erro(`quadro {i}: {j} desloca {d} studs (máx {Regra.POSICAO_MAX})`)
				end
			end
		end
	end
	if clipe.loop == true and not igualJuntas(quadros[1].juntas, quadros[#quadros].juntas) then
		erro("clipe em laço: primeiro e último quadro precisam ser iguais (senão dá pulo)")
	end
	return erros
end

local function fmt(x: number): string
	local s = string.format("%.1f", x)
	s = string.gsub(s, "%.0$", "")
	return s
end

local ORDEM_JUNTAS = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightHip",
	"RightKnee",
	"RightAnkle",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
}

-- Folha de quadros em texto: um bloco por quadro com os ângulos de cada junta (e posição se houver).
function Regra.folha(arquivo: any, nomeClipe: string): string
	local clipe = arquivo and arquivo.clipes and arquivo.clipes[nomeClipe]
	local quadros = Regra.resolverQuadros(arquivo, nomeClipe)
	if not (clipe and quadros) then
		return nomeClipe .. ": clipe inexistente"
	end
	local L = {
		`{nomeClipe}  dur={clipe.duracao}s  loop={tostring(clipe.loop == true)}  prio={clipe.prioridade or "Action"}  quadros={#quadros}`,
	}
	for _, q in quadros do
		local partes = {}
		for _, j in ORDEM_JUNTAS do
			local v = q.juntas[j]
			if v then
				local txt = `{j}({fmt(v[1])},{fmt(v[2])},{fmt(v[3])}`
				if #v == 6 then
					txt ..= `|{fmt(v[4])},{fmt(v[5])},{fmt(v[6])}`
				end
				table.insert(partes, txt .. ")")
			end
		end
		local extra = ""
		if q.easing then
			extra ..= " [" .. q.easing .. "]"
		end
		if q.marcadores and #q.marcadores > 0 then
			extra ..= " {" .. table.concat(q.marcadores, ",") .. "}"
		end
		local tempo = string.gsub(string.format("%.3f", q.t), "%.?0+$", "")
		table.insert(L, string.format("  t=%-6s%s %s", tempo == "" and "0" or tempo, extra, table.concat(partes, " ")))
	end
	return table.concat(L, "\n")
end

-- Decisões do AnimacaoCorpo ---------------------------------------------------------------------------------------------------

-- Clipe de repouso de quem está sentado num banco de carro: o VehicleSeat é o motorista, o Seat comum é passageiro.
function Regra.clipeAssento(classeAssento: string?): string?
	if classeAssento == "VehicleSeat" then
		return "MotoristaIdle"
	elseif classeAssento == "Seat" then
		return "PassageiroIdle"
	end
	return nil
end

-- Clipe da mão para o item segurado. `litros` = capacidade/conteúdo do recipiente de combustível (nil se não é recipiente);
-- a partir de `minimoGalao` o recipiente é pesado (SegurarGalao). Mão esquerda tem variante própria.
function Regra.clipeMao(litros: number?, lado: string, minimoGalao: number): string
	if litros ~= nil and litros >= minimoGalao and lado ~= "esquerda" then
		return "SegurarGalao"
	end
	if lado == "esquerda" then
		return "SegurarUmaMaoEsq"
	end
	return "SegurarUmaMao"
end

-- Velocidade para o clipe "Usar" durar o tempo de uso do item (Config/Itens.uso); limitada para não parecer tosca.
function Regra.velocidadeUso(duracaoNativa: number, usoSegundos: number?): number
	if not usoSegundos or usoSegundos <= 0 or duracaoNativa <= 0 then
		return 1
	end
	return math.clamp(duracaoNativa / usoSegundos, 0.5, 2)
end

-- Volante: peso (0..1) e lado ("Esquerda"/"Direita"/nil) do clipe de curva para o valor de direção (-1..1, + = direita).
function Regra.volante(direcao: number, zonaMorta: number): (string?, number)
	local v = math.clamp(direcao, -1, 1)
	if math.abs(v) <= zonaMorta then
		return nil, 0
	end
	local peso = (math.abs(v) - zonaMorta) / (1 - zonaMorta)
	return if v < 0 then "Esquerda" else "Direita", math.clamp(peso, 0, 1)
end

-- Estava no ar tempo suficiente para valer o clipe de Queda/Aterrissagem?
function Regra.quedaValida(tempoNoAr: number, minimo: number): boolean
	return tempoNoAr >= minimo
end

-- Dois acontecimentos (instantes em s, nil = nunca) caem na mesma janela? Casa "inventário mudou" com "item do chão mudou".
function Regra.juntos(a: number?, b: number?, janela: number): boolean
	return a ~= nil and b ~= nil and math.abs(a - b) <= janela
end

return Regra
