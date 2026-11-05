--!strict
-- Regras puras da destruição universal (docs/destruicao.md §5): classe e vida do material, dano efetivo, estágios de escurecer,
-- recorte do vão em peça retangular e energia do carro. Sem Instance: vetores são tabelas {x, y, z}.

local Destruicao = {}

export type Vec = { number }
export type Retalho = { centro: Vec, tamanho: Vec }
export type Classe = { classe: string, vidaPorStud: number, fixa: boolean }
export type Buraco = { largura: number, altura: number }

local EPS = 1e-9

function Destruicao.classeDe(materialNome: string, cfgMat: any): Classe
	local m = cfgMat.materiais[materialNome] or cfgMat.padrao
	return { classe = m.classe, vidaPorStud = m.vidaPorStud, fixa = m.fixa == true }
end

function Destruicao.vidaMaxima(materialNome: string, espessura: number, cfgMat: any): number
	local c = Destruicao.classeDe(materialNome, cfgMat)
	if c.fixa then
		return c.vidaPorStud
	end
	return c.vidaPorStud * math.clamp(espessura, cfgMat.espessura.min, cfgMat.espessura.max)
end

function Destruicao.danoEfetivo(quantidade: number, tipo: string, classe: string, cfgMat: any): number
	local linha = cfgMat.matriz[tipo]
	local mult = linha and linha[classe]
	if type(mult) ~= "number" then
		return 0
	end
	return quantidade * mult
end

function Destruicao.golpesPara(
	vidaRestante: number,
	quantidade: number,
	tipo: string,
	classe: string,
	cfgMat: any
): number
	local ef = Destruicao.danoEfetivo(quantidade, tipo, classe, cfgMat)
	if ef <= 0 then
		return math.huge
	end
	return math.max(1, math.ceil(vidaRestante / ef - EPS))
end

-- Quantos limiares já passaram (0 a #limiares).
function Destruicao.estagio(fracDano: number, limiares: { number }): number
	local n = 0
	for _, l in limiares do
		if fracDano >= l - EPS then
			n += 1
		end
	end
	return n
end

-- Fração do Lerp original -> escurecerAlvo (0 para classe que não escurece).
function Destruicao.fatorEscurecer(classe: string, estagio: number, cfgMat: any, cfg: any): number
	local c = cfgMat.classes[classe]
	if not c or c.efeito ~= "escurecer" then
		return 0
	end
	return math.clamp(c.escurece * estagio / #cfg.estagios, 0, 1)
end

function Destruicao.transparenciaRachada(base: number, estagio: number, cfg: any): number
	return math.max(0, base - cfg.rachar.transparencia * estagio)
end

-- Fração em que a cor do vidro clareia em direção ao branco.
function Destruicao.fatorClarear(estagio: number, cfg: any): number
	return math.clamp(cfg.rachar.clarear * estagio, 0, 1)
end

function Destruicao.papelDe(nome: string, cfg: any): { papel: string, destrutivel: boolean }?
	for _, par in cfg.nomes do
		local prefixo: string = par[1]
		if string.sub(nome, 1, #prefixo) == prefixo then
			local papel: string = par[2]
			local p = cfg.papeis[papel]
			return { papel = papel, destrutivel = p ~= nil and p.destrutivel == true }
		end
	end
	return nil
end

-- Vão pedido: largura/altura da tabela do tipo, ou largura da fonte; nunca maior que a peça.
function Destruicao.tamanhoBuraco(tipo: string, dimsPeca: Vec, larguraFonte: number?, cfg: any): Buraco
	local b = cfg.buraco[tipo] or cfg.buraco.corte
	local largura = larguraFonte or b.largura
	local maior = math.max(dimsPeca[1], dimsPeca[3])
	return { largura = math.min(largura, maior), altura = math.min(b.altura, dimsPeca[2]) }
end

-- Eixos do plano da peça: parede vertical (eixo fino X ou Z) usa (comprimento, Y); laje (eixo fino Y) usa (X, Z).
local function eixosDoPlano(eixoFino: number): (number, number)
	if eixoFino == 2 then
		return 1, 3
	end
	return (if eixoFino == 1 then 3 else 1), 2
end

-- Vão no plano da peça, em coordenadas locais: {centro, tamanho} (espessura inteira). Folgas menores que `minimo`
-- entre o vão e a borda são absorvidas pelo vão (sem fresta).
function Destruicao.vao(
	tamanho: Vec,
	eixoFino: number,
	pontoLocal: Vec,
	buraco: Buraco,
	ancoraChao: boolean,
	minimo: number
): Retalho
	local u, v = eixosDoPlano(eixoFino)
	local U, V = tamanho[u], tamanho[v]
	local largura = math.min(buraco.largura, U)
	local altura = if eixoFino == 2 then math.min(buraco.largura, V) else math.min(buraco.altura, V)

	local cu = math.clamp(pontoLocal[u], -U / 2 + largura / 2, U / 2 - largura / 2)
	local u0, u1 = cu - largura / 2, cu + largura / 2
	local v0, v1
	if ancoraChao and eixoFino ~= 2 then
		v0, v1 = -V / 2, -V / 2 + altura
	else
		local cv = math.clamp(pontoLocal[v], -V / 2 + altura / 2, V / 2 - altura / 2)
		v0, v1 = cv - altura / 2, cv + altura / 2
	end

	if u0 + U / 2 < minimo then
		u0 = -U / 2
	end
	if U / 2 - u1 < minimo then
		u1 = U / 2
	end
	if v0 + V / 2 < minimo then
		v0 = -V / 2
	end
	if V / 2 - v1 < minimo then
		v1 = V / 2
	end

	local centro = { 0, 0, 0 }
	local tam = { tamanho[1], tamanho[2], tamanho[3] }
	centro[u], centro[v] = (u0 + u1) / 2, (v0 + v1) / 2
	tam[u], tam[v] = u1 - u0, v1 - v0
	return { centro = centro, tamanho = tam }
end

-- Retalhos em volta do vão (esquerda, direita, topo e fundo do vão), sem sobreposição; vão + retalhos = a peça.
function Destruicao.recortar(
	tamanho: Vec,
	eixoFino: number,
	pontoLocal: Vec,
	buraco: Buraco,
	ancoraChao: boolean,
	minimo: number
): { Retalho }
	local u, v = eixosDoPlano(eixoFino)
	local U, V = tamanho[u], tamanho[v]
	local vao = Destruicao.vao(tamanho, eixoFino, pontoLocal, buraco, ancoraChao, minimo)
	local u0, u1 = vao.centro[u] - vao.tamanho[u] / 2, vao.centro[u] + vao.tamanho[u] / 2
	local v0, v1 = vao.centro[v] - vao.tamanho[v] / 2, vao.centro[v] + vao.tamanho[v] / 2

	local lista: { Retalho } = {}
	local function adicionar(ua: number, ub: number, va: number, vb: number)
		if ub - ua <= EPS or vb - va <= EPS then
			return
		end
		local centro = { 0, 0, 0 }
		local tam = { tamanho[1], tamanho[2], tamanho[3] }
		centro[u], centro[v] = (ua + ub) / 2, (va + vb) / 2
		tam[u], tam[v] = ub - ua, vb - va
		table.insert(lista, { centro = centro, tamanho = tam })
	end
	adicionar(-U / 2, u0, -V / 2, V / 2) -- esquerda, altura toda
	adicionar(u1, U / 2, -V / 2, V / 2) -- direita, altura toda
	adicionar(u0, u1, v1, V / 2) -- topo do vão
	adicionar(u0, u1, -V / 2, v0) -- fundo do vão (laje ou vão que não parte do chão)
	return lista
end

function Destruicao.inteiraSeMenor(dims: Vec, cfg: any): boolean
	return math.max(dims[1], dims[2], dims[3]) <= cfg.pecaInteira
end

function Destruicao.danoImpactoCarro(massa: number, velocidade: number, cfg: any): number
	return 0.5 * massa * velocidade * velocidade * cfg.carro.escalaEnergia
end

function Destruicao.atravessa(energia: number, vidaRestanteEfetiva: number): boolean
	return energia >= vidaRestanteEfetiva
end

function Destruicao.custoCarroceria(vidaGasta: number, cfg: any): number
	return vidaGasta * cfg.carro.recuoCarroceria
end

function Destruicao.danoAtropelo(velocidade: number, cfg: any): number
	local a = cfg.carro.atropelo
	return math.max(0, velocidade - a.velMin) * a.danoPorVel
end

-- 1 no centro, 0 na borda (e além), linear.
function Destruicao.quedaExplosao(distancia: number, raio: number): number
	if raio <= 0 or distancia >= raio then
		return 0
	end
	return 1 - math.max(0, distancia) / raio
end

return Destruicao
