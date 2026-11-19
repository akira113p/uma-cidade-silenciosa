--!strict
-- Regras puras das habilidades dos monstros (docs/monstros/logica.md §2.3, §2.5, §2.6, §3 a §7). Sem Instance, sem os.clock:
-- o tempo e o sorteio entram por parâmetro. Posições são { x, y, z }. `cfg` = PresetsMonstro.<preset>.habilidades.<nome>.
-- O servidor (server/MonstroHabilidades e server/Habilidades/*) só orquestra: raycast, Humanoid, rede, som.

export type Vec = { x: number, y: number, z: number }
export type Caixa = { chave: string, cx: number, cz: number, sx: number, sz: number } -- zona: centro e tamanho (xz), eixos do mundo
export type Cfg = any

local Habilidades = {}

local function horizontal(dx: number, dz: number): number
	return math.sqrt(dx * dx + dz * dz)
end

-- Recarga ----------------------------------------------------------------------------------------------------------

-- `ultimo` = instante do último uso (-math.huge se nunca usou).
function Habilidades.pronto(ultimo: number, agora: number, recarga: number): boolean
	return agora - ultimo >= recarga
end

-- Cones e visão ------------------------------------------------------------------------------------------------------

-- Cone horizontal: `alvo` está a <= alcance de `origem` e dentro de anguloTotal graus (metade para cada lado) de `frente`.
function Habilidades.noCone(origem: Vec, frente: Vec, alvo: Vec, anguloTotal: number, alcance: number): boolean
	local dx, dz = alvo.x - origem.x, alvo.z - origem.z
	local dist = horizontal(dx, dz)
	if dist > alcance then
		return false
	end
	if dist < 1e-6 then
		return true
	end
	local fm = horizontal(frente.x, frente.z)
	if fm < 1e-6 then
		return false
	end
	local cos = (dx * frente.x + dz * frente.z) / (dist * fm)
	return cos >= math.cos(math.rad(anguloTotal / 2))
end

-- Alcance da visão do Corcunda (§5.1): agachado e deitado enxergam menos, a noite corta (fator), lanterna ligada vale `lanterna`.
function Habilidades.alcanceVisao(
	cfg: Cfg,
	estado: { agachado: boolean?, deitado: boolean?, noite: boolean?, lanterna: boolean? }
): number
	local a = cfg.alcance
	if estado.deitado then
		a = cfg.deitado
	elseif estado.agachado then
		a = cfg.agachado
	end
	if estado.noite then
		a *= cfg.noite
	end
	if estado.lanterna then
		a = math.max(a, cfg.lanterna)
	end
	return a
end

-- Viu o jogador: dentro do cone/alcance E com linha de visão livre (o raycast é do servidor).
function Habilidades.veJogador(
	cfg: Cfg,
	origem: Vec,
	frente: Vec,
	alvo: Vec,
	estado: { agachado: boolean?, deitado: boolean?, noite: boolean?, lanterna: boolean? },
	linhaLivre: boolean
): boolean
	return linhaLivre and Habilidades.noCone(origem, frente, alvo, cfg.angulo, Habilidades.alcanceVisao(cfg, estado))
end

-- Noite: ClockTime fora de [inicioDia, fimDia).
function Habilidades.ehNoite(clockTime: number, inicioDia: number, fimDia: number): boolean
	return clockTime < inicioDia or clockTime >= fimDia
end

-- Sonar do Wrapper (§4.1) ---------------------------------------------------------------------------------------------

-- Segundos até a frente da onda chegar a `dist` studs.
function Habilidades.tempoOnda(dist: number, velocidade: number): number
	return dist / velocidade
end

function Habilidades.ondaAlcanca(dist: number, raio: number): boolean
	return dist <= raio
end

-- Gatilho 3 do sonar (Caça, perdeu o alvo): `perdeuAlvo` s sem som novo.
function Habilidades.perdeuAlvo(ultimoSom: number, agora: number, cfg: Cfg): boolean
	return agora - ultimoSom >= cfg.perdeuAlvo
end

function Habilidades.alvoSonarValido(alvo: { ate: number }?, agora: number): boolean
	return alvo ~= nil and agora < alvo.ate
end

-- Pulso no chão do Rastejador (§3.1) -----------------------------------------------------------------------------------

-- Detecta quem anda (velocidade horizontal >= velMinima), fora de carro, nem agachado nem deitado, a <= raio.
function Habilidades.pulsoDetecta(
	cfg: Cfg,
	dist: number,
	velHoriz: number,
	agachado: boolean,
	deitado: boolean,
	emCarro: boolean
): boolean
	return dist <= cfg.raio and velHoriz >= cfg.velMinima and not agachado and not deitado and not emCarro
end

-- Busca dentro da casa (§3.3) ------------------------------------------------------------------------------------------

-- Pontos candidatos numa grade de `grade` studs sobre a caixa { cx, cz, sx, sz } (recuada meia grade das paredes), do mais
-- longe da entrada para o mais perto (quem se esconde vai para o fundo), com sorteio de até `grade` studs para desempatar.
-- O servidor valida cada um (piso, sem móvel) e fica com os primeiros `pontosMax` bons.
function Habilidades.candidatosBusca(
	caixa: { cx: number, cz: number, sx: number, sz: number },
	grade: number,
	entrada: { x: number, z: number },
	rnd: () -> number
): { { x: number, z: number } }
	local r = {}
	local x0, z0 = caixa.cx - caixa.sx / 2 + grade / 2, caixa.cz - caixa.sz / 2 + grade / 2
	local nx, nz =
		math.max(1, math.floor((caixa.sx - grade) / grade) + 1), math.max(1, math.floor((caixa.sz - grade) / grade) + 1)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local x, z = x0 + i * grade, z0 + j * grade
			table.insert(r, { x = x, z = z, nota = horizontal(x - entrada.x, z - entrada.z) + rnd() * grade })
		end
	end
	table.sort(r, function(a, b)
		return a.nota > b.nota
	end)
	return r
end

-- Emboscada do Corcunda (§5.4) ------------------------------------------------------------------------------------------

-- Entre candidatos { oculto, dentro, dist }, o índice do melhor esconderijo: só os ocultos (o ponto do som não é visível dali),
-- dentro de construção primeiro, depois o mais perto. nil se nenhum serve.
function Habilidades.escolherEsconderijo(cands: { { oculto: boolean, dentro: boolean, dist: number } }): number?
	local melhor: number? = nil
	for i, c in cands do
		if c.oculto then
			local m = if melhor then cands[melhor] else nil
			if not m or (c.dentro and not m.dentro) or (c.dentro == m.dentro and c.dist < m.dist) then
				melhor = i
			end
		end
	end
	return melhor
end

-- Memória dos últimos sons de jogador: lista de { tipo, db, quando }. Devolve lista nova (descarta o velho, mantém os últimos `maximo`).
function Habilidades.memoriaRegistrar(
	mem: { { tipo: string, db: number, quando: number } },
	som: { tipo: string, db: number, quando: number },
	agora: number,
	cfg: Cfg
): { { tipo: string, db: number, quando: number } }
	local nova = {}
	for _, s in mem do
		if agora - s.quando <= cfg.memoria then
			table.insert(nova, s)
		end
	end
	table.insert(nova, som)
	while #nova > cfg.memoriaMax do
		table.remove(nova, 1)
	end
	return nova
end

-- Um som da memória ainda válido (<= cfg.memoria s), sorteado; nil se vazia.
function Habilidades.memoriaEscolher(
	mem: { { tipo: string, db: number, quando: number } },
	agora: number,
	cfg: Cfg,
	rnd: () -> number
): { tipo: string, db: number, quando: number }?
	local validos = {}
	for _, s in mem do
		if agora - s.quando <= cfg.memoria then
			table.insert(validos, s)
		end
	end
	if #validos == 0 then
		return nil
	end
	return validos[math.min(#validos, math.floor(rnd() * #validos) + 1)]
end

-- Nome do som de catálogo que imita o tipo de ruído; nil se o tipo não é imitável. `tabela` = cfg.sons.
function Habilidades.somDoTipo(tipo: string, tabela: { [string]: string }): string?
	return tabela[tipo]
end

-- Mira com erro da lâmina (§6.3) --------------------------------------------------------------------------------------

-- Direção unitária sorteada uniformemente dentro de um cone de `maxGraus` em volta de `dir` (não precisa ser unitária).
function Habilidades.desviarDirecao(dir: Vec, maxGraus: number, rnd: () -> number): Vec
	local m = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
	local ux, uy, uz = dir.x / m, dir.y / m, dir.z / m
	-- base ortonormal (u, v, w)
	local hx, hy, hz = 0, 1, 0
	if math.abs(uy) > 0.9 then
		hx, hy, hz = 1, 0, 0
	end
	local vx, vy, vz = uy * hz - uz * hy, uz * hx - ux * hz, ux * hy - uy * hx
	local vm = math.sqrt(vx * vx + vy * vy + vz * vz)
	vx, vy, vz = vx / vm, vy / vm, vz / vm
	local wx, wy, wz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
	local cosMax = math.cos(math.rad(maxGraus))
	local cosT = 1 - rnd() * (1 - cosMax) -- uniforme na calota esférica
	local sinT = math.sqrt(math.max(0, 1 - cosT * cosT))
	local phi = rnd() * 2 * math.pi
	local cp, sp = math.cos(phi), math.sin(phi)
	return {
		x = ux * cosT + (vx * cp + wx * sp) * sinT,
		y = uy * cosT + (vy * cp + wy * sp) * sinT,
		z = uz * cosT + (vz * cp + wz * sp) * sinT,
	}
end

-- Ângulo em graus entre dois vetores.
function Habilidades.anguloEntre(a: Vec, b: Vec): number
	local ma = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
	local mb = math.sqrt(b.x * b.x + b.y * b.y + b.z * b.z)
	local c = (a.x * b.x + a.y * b.y + a.z * b.z) / (ma * mb)
	return math.deg(math.acos(math.clamp(c, -1, 1)))
end

-- Alvo previsto: posição + velocidade x previsao s.
function Habilidades.alvoPrevisto(pos: Vec, vel: Vec, previsao: number): Vec
	return { x = pos.x + vel.x * previsao, y = pos.y + vel.y * previsao, z = pos.z + vel.z * previsao }
end

-- Escolha de ataque do MonstroPS1 (§6.1/§6.3) ---------------------------------------------------------------------------

-- Sem linha de visão: nenhum. Arrancada tem prioridade quando as duas servem (<= arrancada.max); acima só lança.
function Habilidades.escolherAtaquePS1(
	dist: number,
	linha: boolean,
	prontoArrancada: boolean,
	prontoLancar: boolean,
	arrancada: Cfg,
	lancar: Cfg
): string?
	if not linha then
		return nil
	end
	if prontoArrancada and dist >= arrancada.min and dist <= arrancada.max then
		return "arrancada"
	end
	if prontoLancar and dist >= lancar.min and dist <= lancar.max then
		return "lancar"
	end
	return nil
end

-- Golpe duplo como golpe normal de perto 1 a cada `cada` (contagem já incrementada: 3, 6, 9...).
function Habilidades.golpeDuploAgora(contagem: number, cada: number): boolean
	return contagem % cada == 0
end

-- Zonas (§2.5) e Florescida (§7) ---------------------------------------------------------------------------------------

-- A posição está numa caixa de zona com a chave `nome` (só X e Z; as zonas do mapa são faixas altas).
function Habilidades.dentroDeZona(pos: { x: number, z: number }, zonas: { Caixa }, nome: string): boolean
	for _, z in zonas do
		if z.chave == nome and math.abs(pos.x - z.cx) <= z.sx / 2 and math.abs(pos.z - z.cz) <= z.sz / 2 then
			return true
		end
	end
	return false
end

-- Ponto fora da caixa (folga studs além da borda) mais perto de `p`, na borda cuja distância é menor. Para `p` dentro da caixa:
-- sai pelo lado mais curto. Para `p` fora: devolve o próprio `p` recuado para fora se estiver colado, senão `p`.
function Habilidades.pontoForaMaisProximo(
	p: { x: number, z: number },
	c: Caixa,
	folga: number
): { x: number, z: number }
	local dxE, dxD = p.x - (c.cx - c.sx / 2), (c.cx + c.sx / 2) - p.x
	local dzS, dzN = p.z - (c.cz - c.sz / 2), (c.cz + c.sz / 2) - p.z
	if dxE < 0 or dxD < 0 or dzS < 0 or dzN < 0 then
		return { x = p.x, z = p.z } -- já fora
	end
	local m = math.min(dxE, dxD, dzS, dzN)
	if m == dxE then
		return { x = c.cx - c.sx / 2 - folga, z = p.z }
	elseif m == dxD then
		return { x = c.cx + c.sx / 2 + folga, z = p.z }
	elseif m == dzS then
		return { x = p.x, z = c.cz - c.sz / 2 - folga }
	end
	return { x = p.x, z = c.cz + c.sz / 2 + folga }
end

-- Caixa da primeira zona com a chave `nome` que contém `p`; nil se nenhuma.
function Habilidades.zonaQueContem(p: { x: number, z: number }, zonas: { Caixa }, nome: string): Caixa?
	for _, z in zonas do
		if z.chave == nome and math.abs(p.x - z.cx) <= z.sx / 2 and math.abs(p.z - z.cz) <= z.sz / 2 then
			return z
		end
	end
	return nil
end

-- Gira `atual` (rad, em torno de Y) em direção a `alvo` no máximo `maxRad`, pelo lado mais curto.
function Habilidades.girarPara(atual: number, alvo: number, maxRad: number): number
	local diff = (alvo - atual + math.pi) % (2 * math.pi) - math.pi
	return atual + math.clamp(diff, -maxRad, maxRad)
end

-- Limite por espécie (§2.6): `max` nil = sem limite.
function Habilidades.podeNascer(contagem: number, max: number?): boolean
	return max == nil or contagem < max
end

-- Fachada (§7.4): "arrancar" se a construção é baixa e não é de concreto; senão "rondar" (morde janelas).
function Habilidades.decidirFachada(alturaConstrucao: number, concreto: boolean, cfg: Cfg): string
	if alturaConstrucao <= cfg.alturaMax and not concreto then
		return "arrancar"
	end
	return "rondar"
end

-- Flores: a flor mais antiga murcha quando a Florescida já tem `max` (a 13ª faz a mais antiga sumir).
function Habilidades.florAMurchar(quantas: number, max: number): boolean
	return quantas >= max
end

-- Grade espacial das flores: chave da célula de lado `lado` para a posição.
function Habilidades.celula(x: number, z: number, lado: number): string
	return math.floor(x / lado) .. ":" .. math.floor(z / lado)
end

-- Células (3x3 em volta) que cobrem um raio <= lado em torno de (x, z).
function Habilidades.celulasVizinhas(x: number, z: number, lado: number): { string }
	local cx, cz = math.floor(x / lado), math.floor(z / lado)
	local r = {}
	for i = -1, 1 do
		for j = -1, 1 do
			table.insert(r, (cx + i) .. ":" .. (cz + j))
		end
	end
	return r
end

return Habilidades
