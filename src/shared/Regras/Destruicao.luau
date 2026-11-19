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
	return quantidade * mult * (cfgMat.multiplicadorDano or 1)
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
Destruicao.eixosDoPlano = eixosDoPlano

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

-- Formas de vão (2026-11-16) -----------------------------------------------------------------------------------------
-- Um vão com forma é uma pilha de faixas retangulares (de baixo para cima) no plano (u, v) da peça: a elipse vira degraus
-- (furo de tiro, explosão), o carro vira a silhueta de frente (base larga, cabine mais estreita). Tudo continua Part bloco.

export type Faixa = { u0: number, u1: number, v0: number, v1: number }

-- Perfil {a, b, w}: faixa de a a b (fração da altura, de baixo para cima) com largura w (fração da largura do vão).
function Destruicao.perfilForma(forma: string, altura: number, cfg: any): { { number } }
	local f = cfg.formas and cfg.formas[forma]
	if forma == "elipse" and f then
		local n = math.clamp(math.floor(altura / f.linha + 0.5), 1, f.linhasMax)
		local lista = {}
		for i = 1, n do
			local a, b = (i - 1) / n, i / n
			local t = a + b - 1 -- centro da faixa, de -1 a 1
			table.insert(lista, { a, b, math.sqrt(math.max(0, 1 - t * t)) })
		end
		return lista
	end
	if f and f.perfil then
		return f.perfil
	end
	return { { 0, 1, 1 } }
end

-- Faixas do vão, em coordenadas locais da peça. `baseLocal` (opcional) fixa o pé do vão no eixo v; senão o vão parte do chão
-- da peça (`ancoraChao`, parede vertical) ou fica centrado no ponto. Folgas menores que `minimo` até a borda viram vão.
function Destruicao.faixas(
	tamanho: Vec,
	eixoFino: number,
	pontoLocal: Vec,
	buraco: Buraco,
	forma: string,
	ancoraChao: boolean,
	minimo: number,
	cfg: any,
	baseLocal: number?
): { Faixa }
	local u, v = eixosDoPlano(eixoFino)
	local U, V = tamanho[u], tamanho[v]
	local largura = math.min(buraco.largura, U)
	local altura = if eixoFino == 2 then math.min(buraco.largura, V) else math.min(buraco.altura, V)
	local cu = math.clamp(pontoLocal[u], -U / 2 + largura / 2, U / 2 - largura / 2)
	local vb
	if baseLocal and eixoFino ~= 2 then
		vb = baseLocal
	elseif ancoraChao and eixoFino ~= 2 then
		vb = -V / 2
	else
		vb = pontoLocal[v] - altura / 2
	end
	vb = math.clamp(vb, -V / 2, V / 2 - altura)

	local perfil = Destruicao.perfilForma(forma, altura, cfg)
	local lista: { Faixa } = {}
	for i, p in perfil do
		local v0, v1 = vb + p[1] * altura, vb + p[2] * altura
		if i == 1 and v0 + V / 2 < minimo then
			v0 = -V / 2
		end
		if i == #perfil and V / 2 - v1 < minimo then
			v1 = V / 2
		end
		local w = largura * p[3]
		local u0, u1 = cu - w / 2, cu + w / 2
		if w > EPS then
			if u0 + U / 2 < minimo then
				u0 = -U / 2
			end
			if U / 2 - u1 < minimo then
				u1 = U / 2
			end
		end
		if v1 - v0 > EPS then
			table.insert(lista, { u0 = u0, u1 = u1, v0 = v0, v1 = v1 })
		end
	end
	return lista
end

-- Retalhos em volta das faixas: tira de baixo, esquerda/direita de cada faixa (colunas iguais fundidas) e tira de cima.
-- Retalhos + faixas = a peça, sem sobreposição.
function Destruicao.recortarFaixas(tamanho: Vec, eixoFino: number, faixas: { Faixa }): { Retalho }
	local u, v = eixosDoPlano(eixoFino)
	local U, V = tamanho[u], tamanho[v]
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
	if #faixas == 0 then
		adicionar(-U / 2, U / 2, -V / 2, V / 2)
		return lista
	end
	adicionar(-U / 2, U / 2, -V / 2, faixas[1].v0)
	-- colunas à esquerda e à direita: faixas seguidas com a mesma borda viram um retalho só
	for lado = 1, 2 do
		local ini = 1
		while ini <= #faixas do
			local borda = if lado == 1 then faixas[ini].u0 else faixas[ini].u1
			local fim = ini
			while fim < #faixas do
				local prox = if lado == 1 then faixas[fim + 1].u0 else faixas[fim + 1].u1
				if math.abs(prox - borda) > EPS then
					break
				end
				fim += 1
			end
			if lado == 1 then
				adicionar(-U / 2, borda, faixas[ini].v0, faixas[fim].v1)
			else
				adicionar(borda, U / 2, faixas[ini].v0, faixas[fim].v1)
			end
			ini = fim + 1
		end
	end
	adicionar(-U / 2, U / 2, faixas[#faixas].v1, V / 2)
	return lista
end

-- Caixa que contém as faixas (u0, u1, v0, v1).
function Destruicao.caixaFaixas(faixas: { Faixa }): (number, number, number, number)
	local u0, u1 = math.huge, -math.huge
	for _, f in faixas do
		u0, u1 = math.min(u0, f.u0), math.max(u1, f.u1)
	end
	return u0, u1, faixas[1].v0, faixas[#faixas].v1
end

-- Furo de tiro: dano local acumulado num ponto da peça que abre o furo (fração da vida da peça, por classe).
function Destruicao.limiarFuro(vidaMax: number, classe: string, cfg: any): number
	local f = cfg.furo and cfg.furo.fracao[classe]
	if type(f) ~= "number" or f <= 0 then
		return math.huge
	end
	return vidaMax * f
end

-- Tamanho do furo: espalhamento dos chumbos (ou o furo base de uma bala), entre o mínimo e o máximo.
function Destruicao.tamanhoFuro(espalhamento: number?, cfg: any): number
	local f = cfg.furo
	return math.clamp(espalhamento or f.tamanho, f.tamanho, f.max)
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

-- Quem cai (prop derrubável): peças cujo centro está acima de `base + alturaBase` tombam; as de baixo (sapata) ficam.
function Destruicao.cai(centroY: number, baseY: number, cfg: any): boolean
	return centroY > baseY + cfg.derrubar.alturaBase
end

-- Batida no chão de quem está tombando: vinha rápido e perdeu a maior parte da velocidade de uma amostra para a outra.
function Destruicao.bateuNoChao(velAntes: number, velAgora: number, cfg: any): boolean
	local d = cfg.derrubar
	return velAntes >= d.velBatida and velAgora <= velAntes * d.quedaBatida
end

-- 1 no centro, 0 na borda (e além), linear.
function Destruicao.quedaExplosao(distancia: number, raio: number): number
	if raio <= 0 or distancia >= raio then
		return 0
	end
	return 1 - math.max(0, distancia) / raio
end

return Destruicao
