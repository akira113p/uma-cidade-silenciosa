--!strict
-- Percepcao: máquina de estados de um monstro cego (Calmo/Investiga/Caca). Pura, sem Instance. Dono: P4.
-- Contrato: docs/arquitetura.md §P4; tabela de docs/calculos.md §2.1. "Ataque" não é daqui: é sobreposição do servidor.
-- `cfg` é o Config/Monstros inteiro (usa cfg.estados e cfg.niveis). Estados nunca são mutados: cada função devolve cópia.

export type Vec = { x: number, y: number, z: number }
export type Estado = { estado: string, alvo: Vec?, ultimoSom: number, sons: { number }, desde: number }
export type Cfg = {
	estados: {
		investigaAte: number,
		somsParaCaca: number,
		janelaCaca: number,
		investigaTimeout: number,
		cacaTimeout: number,
		erroPorDistancia: number,
	},
	niveis: {
		[number]: {
			velocidadeCalmo: number,
			velocidadeCaca: number,
			velocidadeInvestiga: number?, -- opcional; sem ela Investiga anda na velocidade de Calmo
		},
	},
}

local Percepcao = {}

function Percepcao.novo(agora: number): Estado
	return { estado = "Calmo", alvo = nil, ultimoSom = -math.huge, sons = {}, desde = agora }
end

-- Registra um som já audível (excesso >= 0; negativo é ignorado). Investiga se 0 <= excesso < investigaAte;
-- Caça se excesso >= investigaAte ou se há `somsParaCaca` sons dentro de `janelaCaca`. Caça nunca rebaixa por som fraco.
function Percepcao.ouvir(e: Estado, excesso: number, posicao: Vec, agora: number, cfg: Cfg): Estado
	if excesso < 0 then
		return e
	end
	local est = cfg.estados
	local sons: { number } = {}
	for _, t in e.sons do
		if agora - t <= est.janelaCaca then
			table.insert(sons, t)
		end
	end
	table.insert(sons, agora)

	local pedido = "Investiga"
	if excesso >= est.investigaAte or #sons >= est.somsParaCaca then
		pedido = "Caca"
	end
	local novo = e.estado
	if e.estado == "Calmo" or (e.estado == "Investiga" and pedido == "Caca") then
		novo = pedido
	end
	return {
		estado = novo,
		alvo = { x = posicao.x, y = posicao.y, z = posicao.z },
		ultimoSom = agora,
		sons = sons,
		desde = if novo ~= e.estado then agora else e.desde,
	}
end

-- Timeouts. Caça sem ouvir cacaTimeout s → Investiga (mantém o alvo); Investiga sem ouvir investigaTimeout s → Calmo.
-- O relógio de Investiga conta do último som OU de quando entrou em Investiga (vindo da Caça ele ganha tempo de chegar).
function Percepcao.tick(e: Estado, agora: number, cfg: Cfg): Estado
	local est = cfg.estados
	if e.estado == "Caca" and agora - e.ultimoSom >= est.cacaTimeout then
		return { estado = "Investiga", alvo = e.alvo, ultimoSom = e.ultimoSom, sons = {}, desde = agora }
	end
	if e.estado == "Investiga" and agora - math.max(e.ultimoSom, e.desde) >= est.investigaTimeout then
		return { estado = "Calmo", alvo = nil, ultimoSom = e.ultimoSom, sons = {}, desde = agora }
	end
	return e
end

-- Posição estimada do som: real + erro horizontal uniforme no disco de raio distancia × erroPorDistancia.
function Percepcao.estimar(real: Vec, distancia: number, rng: () -> number, cfg: Cfg): Vec
	local raio = math.max(0, distancia) * cfg.estados.erroPorDistancia
	local angulo = rng() * 2 * math.pi
	local r = math.sqrt(rng()) * raio
	return { x = real.x + math.cos(angulo) * r, y = real.y, z = real.z + math.sin(angulo) * r }
end

-- Studs/s. Calmo e Investiga andam; Caca e Ataque correm. Nível desconhecido usa o 1.
function Percepcao.velocidade(nivel: number, estado: string, cfg: Cfg): number
	local n = cfg.niveis[nivel] or cfg.niveis[1]
	if estado == "Caca" or estado == "Ataque" then
		return n.velocidadeCaca
	end
	if estado == "Investiga" then
		return n.velocidadeInvestiga or n.velocidadeCalmo
	end
	return n.velocidadeCalmo
end

return Percepcao
