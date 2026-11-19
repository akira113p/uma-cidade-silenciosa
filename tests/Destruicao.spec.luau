local CfgMat = require("../src/shared/Config/Materiais")
local Cfg = require("../src/shared/Config/Destruicao")
local R = require("../src/shared/Regras/Destruicao")
local util = require("./util")

-- classe e vida por material (tabela do §4.1)
local esperado = {
	Glass = { "vidro", 10 },
	Fabric = { "leve", 20 },
	SmoothPlastic = { "leve", 30 },
	Plastic = { "leve", 30 },
	Wood = { "madeira", 150 },
	WoodPlanks = { "madeira", 150 },
	Sandstone = { "alvenaria", 240 },
	Limestone = { "alvenaria", 300 },
	Slate = { "alvenaria", 300 },
	Brick = { "alvenaria", 360 },
	Marble = { "alvenaria", 400 },
	Concrete = { "alvenaria", 480 },
	Granite = { "alvenaria", 520 },
	Basalt = { "alvenaria", 560 },
	CorrodedMetal = { "metal", 360 },
	Metal = { "metal", 600 },
	DiamondPlate = { "metal", 900 },
	Grass = { "alvenaria", 300 }, -- fora da tabela: padrão
}
for nome, e in esperado do
	local c = R.classeDe(nome, CfgMat)
	util.igual(c.classe, e[1], "classe " .. nome)
	util.perto(c.vidaPorStud, e[2], "vida por stud " .. nome)
end
assert(R.classeDe("Glass", CfgMat).fixa, "vidro é fixo")
assert(not R.classeDe("Wood", CfgMat).fixa, "madeira não é fixa")

-- vida: vidro fixo, clamp da espessura
for _, esp in { 0.1, 0.5, 1, 3, 8 } do
	util.perto(R.vidaMaxima("Glass", esp, CfgMat), 10, "vidro espessura " .. esp)
end
util.perto(R.vidaMaxima("Brick", 0.1, CfgMat), 180, "clamp mínimo (0,5)")
util.perto(R.vidaMaxima("Brick", 1, CfgMat), 360, "1 stud")
util.perto(R.vidaMaxima("Brick", 2, CfgMat), 720, "2 studs")
util.perto(R.vidaMaxima("Brick", 10, CfgMat), 1080, "clamp máximo (3)")
util.perto(R.vidaMaxima("Metal", 0.2, CfgMat), 300, "metal fino (0,5)")

-- matriz
util.perto(R.danoEfetivo(40, "corte", "madeira", CfgMat), 90, "machado em madeira")
util.perto(R.danoEfetivo(40, "corte", "alvenaria", CfgMat), 9, "machado em tijolo")
util.perto(R.danoEfetivo(25, "bala", "vidro", CfgMat), 225, "pistola em vidro")
util.igual(R.danoEfetivo(25, "bala", "classeFantasma", CfgMat), 0, "classe inexistente")
util.igual(R.danoEfetivo(25, "tipoFantasma", "vidro", CfgMat), 0, "tipo inexistente")

-- tabela de golpes do §4.3 (1 stud de espessura)
local dano = { pistola = 25, faca = 18, peDeCabra = 28, machado = 40, marreta = 55, garra = 20 }
local tipo = {
	pistola = "bala",
	faca = "corte",
	peDeCabra = "alavanca",
	machado = "corte",
	marreta = "marreta",
	garra = "garra",
}
-- a tabela do §4.3 vale com multiplicador 1; o multiplicador global (Config/Materiais) é testado acima
local CfgMatBase = setmetatable({ multiplicadorDano = 1 }, { __index = CfgMat })
local golpes = {
	{ "vidro", 10, { pistola = 1, faca = 1, peDeCabra = 1, machado = 1, marreta = 1, garra = 1 } },
	{ "madeira", 150, { pistola = 12, faca = 6, peDeCabra = 5, machado = 3, marreta = 3, garra = 8 } },
	{ "alvenaria", 360, { pistola = 58, faca = 134, peDeCabra = 26, machado = 60, marreta = 5, garra = 45 } },
	{ "alvenaria", 480, { pistola = 77, faca = 178, peDeCabra = 35, machado = 80, marreta = 6, garra = 60 } },
	{ "metal", 600, { pistola = 120, faca = 334, peDeCabra = 54, machado = 150, marreta = 14, garra = 200 } },
	{ "metal", 300, { pistola = 60, faca = 167, peDeCabra = 27, machado = 75, marreta = 7, garra = 100 } },
}
for _, linha in golpes do
	for arma, n in linha[3] do
		util.igual(
			R.golpesPara(linha[2], dano[arma], tipo[arma], linha[1], CfgMatBase),
			n,
			string.format("golpes %s vida %d com %s", linha[1], linha[2], arma)
		)
	end
end
util.igual(R.golpesPara(100, 10, "soco", "inexistente", CfgMat), math.huge, "golpes sem efeito = infinito")

-- estágios
util.igual(R.estagio(0, Cfg.estagios), 0, "estágio 0")
util.igual(R.estagio(0.19, Cfg.estagios), 0, "estágio 0,19")
util.igual(R.estagio(0.2, Cfg.estagios), 1, "estágio 0,2")
util.igual(R.estagio(0.4, Cfg.estagios), 2, "estágio 0,4")
util.igual(R.estagio(0.79, Cfg.estagios), 3, "estágio 0,79")
util.igual(R.estagio(0.99, Cfg.estagios), 4, "estágio 0,99")
util.perto(R.fatorEscurecer("madeira", 4, CfgMat, Cfg), 0.6, "escurecer madeira no máximo")
util.perto(R.fatorEscurecer("alvenaria", 2, CfgMat, Cfg), 0.275, "escurecer alvenaria no meio")
util.igual(R.fatorEscurecer("vidro", 4, CfgMat, Cfg), 0, "vidro não escurece")
util.igual(R.fatorEscurecer("madeira", 0, CfgMat, Cfg), 0, "estágio 0 não muda a cor")
util.perto(R.transparenciaRachada(0.5, 2, Cfg), 0.3, "vidro racha")
util.perto(R.transparenciaRachada(0.1, 4, Cfg), 0, "transparência não passa de 0")

-- papéis por nome
local function papel(nome: string): string
	local p = R.papelDe(nome, Cfg)
	return if p then p.papel .. (if p.destrutivel then ":sim" else ":nao") else "nil"
end
util.igual(papel("Parede"), "parede:sim", "Parede")
util.igual(papel("ParedeLonga"), "parede:sim", "ParedeLonga")
util.igual(papel("GradeJanela"), "grade:sim", "GradeJanela")
util.igual(papel("Vidro"), "vidro:sim", "Vidro")
util.igual(papel("FolhaVidro"), "vidro:sim", "FolhaVidro")
util.igual(papel("TetoCasa"), "laje:sim", "TetoCasa")
util.igual(papel("Piso"), "piso:nao", "Piso")
util.igual(papel("Cofre"), "cofre:nao", "Cofre")
util.igual(papel("Folha"), "nil", "Folha (porta) sem papel")
util.igual(papel("Qualquer"), "nil", "nome desconhecido")

-- tamanho do vão
local b = R.tamanhoBuraco("corte", { 20, 10, 1 }, nil, Cfg)
util.perto(b.largura, 3, "vão do corte")
util.perto(b.altura, 6.5, "vão do corte (altura)")
b = R.tamanhoBuraco("garra", { 20, 10, 1 }, 2.8, Cfg)
util.perto(b.largura, 2.8, "vão da garra usa a largura da fonte")
b = R.tamanhoBuraco("explosao", { 2, 3, 0.5 }, nil, Cfg)
util.perto(b.largura, 2, "vão limitado à peça (largura)")
util.perto(b.altura, 3, "vão limitado à peça (altura)")

-- recortar: volume conservado e sem sobreposição
local function vol(t: { number }): number
	return t[1] * t[2] * t[3]
end
local function caixa(r: R.Retalho): { number }
	return {
		r.centro[1] - r.tamanho[1] / 2,
		r.centro[1] + r.tamanho[1] / 2,
		r.centro[2] - r.tamanho[2] / 2,
		r.centro[2] + r.tamanho[2] / 2,
		r.centro[3] - r.tamanho[3] / 2,
		r.centro[3] + r.tamanho[3] / 2,
	}
end
local function sobrepoe(a: { number }, b2: { number }): boolean
	return a[1] < b2[2] - 1e-6
		and b2[1] < a[2] - 1e-6
		and a[3] < b2[4] - 1e-6
		and b2[3] < a[4] - 1e-6
		and a[5] < b2[6] - 1e-6
		and b2[5] < a[6] - 1e-6
end
local function conferir(tam: { number }, fino: number, ponto: { number }, buraco: R.Buraco, chao: boolean, nome: string)
	local pecas = R.recortar(tam, fino, ponto, buraco, chao, Cfg.retalhos.minimo)
	local vao = R.vao(tam, fino, ponto, buraco, chao, Cfg.retalhos.minimo)
	assert(#pecas <= 4, nome .. ": até 4 retalhos")
	local c = caixa(vao)
	local limite = { -tam[1] / 2, tam[1] / 2, -tam[2] / 2, tam[2] / 2, -tam[3] / 2, tam[3] / 2 }
	for i = 1, 5, 2 do
		assert(c[i] >= limite[i] - 1e-6 and c[i + 1] <= limite[i + 1] + 1e-6, nome .. ": vão dentro da peça")
	end
	local soma = vol(vao.tamanho)
	local todas = { c }
	for _, r in pecas do
		local cr = caixa(r)
		for i = 1, 5, 2 do
			assert(cr[i] >= limite[i] - 1e-6 and cr[i + 1] <= limite[i + 1] + 1e-6, nome .. ": retalho dentro da peça")
		end
		for _, outra in todas do
			assert(not sobrepoe(cr, outra), nome .. ": sem sobreposição")
		end
		table.insert(todas, cr)
		soma += vol(r.tamanho)
		for k = 1, 3 do
			assert(r.tamanho[k] > 0, nome .. ": retalho sem tamanho")
		end
	end
	util.perto(soma, vol(tam), nome .. ": volume conservado", 1e-6)
	return pecas, vao
end

-- parede 20 x 10 x 1 (eixo comprido em X, fino em Z = 3)
local parede = { 20, 10, 1 }
local larg = { largura = 3, altura = 6.5 }
local _, vao = conferir(parede, 3, { 0, 0, 0 }, larg, true, "parede, golpe no meio")
util.perto(vao.centro[2], -5 + 6.5 / 2, "vão parte do chão da peça")
util.perto(vao.tamanho[3], 1, "vão atravessa a espessura")
conferir(parede, 3, { -10, 2, 0 }, larg, true, "parede, borda esquerda")
conferir(parede, 3, { 10, 2, 0 }, larg, true, "parede, borda direita")
conferir(parede, 3, { -9.5, 2, 0 }, larg, true, "parede, perto da borda (folga < mínimo)")
conferir(parede, 3, { 3.7, 4, 0 }, { largura = 1.2, altura = 1.2 }, true, "parede, bala")
conferir({ 20, 5, 1 }, 3, { 4, 0, 0 }, larg, true, "parede mais baixa que o vão")
conferir({ 2, 10, 20 }, 1, { 0, 0, 6 }, larg, true, "parede com eixo comprido em Z")
conferir(
	{ 20, 10, 1 },
	3,
	{ 5, 0, 0 },
	{ largura = 3, altura = 2 },
	false,
	"parede, vão no ponto do golpe (com fundo)"
)
local retalhosBorda, vaoBorda = conferir(parede, 3, { -10, 2, 0 }, larg, true, "parede, golpe na borda")
util.perto(vaoBorda.centro[1] - vaoBorda.tamanho[1] / 2, -10, "golpe na borda: vão encosta na borda")
util.igual(#retalhosBorda, 2, "golpe na borda: direita e topo")
-- laje 20 x 1 x 14 (fino em Y = 2)
conferir({ 20, 1, 14 }, 2, { 0, 0, 0 }, larg, true, "laje, golpe no meio")
conferir({ 20, 1, 14 }, 2, { 9, 0, -6 }, larg, true, "laje, canto")
conferir({ 20, 1, 14 }, 2, { -3, 0, 4 }, { largura = 1.2, altura = 1.2 }, true, "laje, bala")
local lajeMeio = R.recortar({ 20, 1, 14 }, 2, { 0, 0, 0 }, larg, true, Cfg.retalhos.minimo)
util.igual(#lajeMeio, 4, "laje no meio: 4 retalhos")
-- vão maior que a peça inteira: sem retalho
util.igual(#R.recortar({ 2, 3, 0.5 }, 3, { 0, 0, 0 }, { largura = 9, altura = 9 }, true, 0.8), 0, "vão cobre a peça")

-- formas do vão em faixas (2026-11-16): volume conservado, sem sobreposição, tudo dentro da peça
local function conferirFaixas(
	tam: { number },
	fino: number,
	ponto: { number },
	buraco: R.Buraco,
	forma: string,
	chao: boolean,
	nome: string,
	base: number?
): ({ R.Faixa }, { R.Retalho })
	local faixas = R.faixas(tam, fino, ponto, buraco, forma, chao, Cfg.retalhos.minimo, Cfg, base)
	assert(#faixas > 0, nome .. ": tem faixa")
	local pecas = R.recortarFaixas(tam, fino, faixas)
	local u, v = R.eixosDoPlano(fino)
	local caixas = {}
	local soma = 0
	for _, f in faixas do
		assert(f.u0 >= -tam[u] / 2 - 1e-6 and f.u1 <= tam[u] / 2 + 1e-6, nome .. ": faixa dentro (u)")
		assert(f.v0 >= -tam[v] / 2 - 1e-6 and f.v1 <= tam[v] / 2 + 1e-6, nome .. ": faixa dentro (v)")
		local r = { centro = { 0, 0, 0 }, tamanho = { tam[1], tam[2], tam[3] } }
		r.centro[u], r.centro[v] = (f.u0 + f.u1) / 2, (f.v0 + f.v1) / 2
		r.tamanho[u], r.tamanho[v] = f.u1 - f.u0, f.v1 - f.v0
		table.insert(caixas, caixa(r))
		soma += vol(r.tamanho)
	end
	local limite = { -tam[1] / 2, tam[1] / 2, -tam[2] / 2, tam[2] / 2, -tam[3] / 2, tam[3] / 2 }
	for _, r in pecas do
		local cr = caixa(r)
		for i = 1, 5, 2 do
			assert(cr[i] >= limite[i] - 1e-6 and cr[i + 1] <= limite[i + 1] + 1e-6, nome .. ": retalho dentro da peça")
		end
		for _, outra in caixas do
			assert(not sobrepoe(cr, outra), nome .. ": sem sobreposição")
		end
		table.insert(caixas, cr)
		soma += vol(r.tamanho)
	end
	util.perto(soma, vol(tam), nome .. ": volume conservado", 1e-6)
	return faixas, pecas
end

-- elipse: degraus, a faixa do meio é a mais larga
local perfil = R.perfilForma("elipse", 2.4, Cfg)
util.igual(#perfil, 3, "elipse de 2,4: 3 degraus")
util.perto(perfil[2][3], 1, "degrau do meio na largura toda")
assert(perfil[1][3] < 1 and perfil[3][3] < 1, "degraus das pontas mais estreitos")
util.igual(#R.perfilForma("elipse", 0.6, Cfg), 1, "furo pequeno: 1 degrau")
util.igual(#R.perfilForma("elipse", 50, Cfg), Cfg.formas.elipse.linhasMax, "elipse grande: no máximo linhasMax")
util.igual(#R.perfilForma("retangulo", 3, Cfg), 1, "retângulo: 1 faixa")

local furoB = { largura = 2.4, altura = 2.4 }
local fx = conferirFaixas(parede, 3, { 2, 1, 0 }, furoB, "elipse", false, "furo de espingarda no meio da parede")
util.igual(#fx, 3, "furo de espingarda: 3 faixas")
conferirFaixas(parede, 3, { -9.9, 4.9, 0 }, furoB, "elipse", false, "furo no canto de cima")
conferirFaixas(parede, 3, { 0, -4.6, 0 }, { largura = 0.6, altura = 0.6 }, "elipse", false, "bala perto do chão")
conferirFaixas({ 20, 1, 14 }, 2, { 3, 0, -2 }, furoB, "elipse", false, "furo na laje")
-- vão do carro: base no chão da parede, silhueta de 4 faixas, a de cima mais estreita
local carroB = { largura = 7, altura = 6.3 }
local fc = conferirFaixas(parede, 3, { 1, 0, 0 }, carroB, "carro", false, "carro na parede", -5)
util.igual(#fc, 4, "carro: 4 faixas")
util.perto(fc[1].v0, -5, "carro: vão desce até o chão")
assert(fc[4].u1 - fc[4].u0 < fc[2].u1 - fc[2].u0, "carro: teto mais estreito que a lataria")
conferirFaixas({ 6, 10, 1 }, 3, { 0, 0, 0 }, carroB, "carro", false, "carro numa parede estreita", -5)
conferirFaixas({ 20, 5, 1 }, 3, { 0, 0, 0 }, carroB, "carro", false, "carro numa parede baixa", -2.5)
-- retângulo por faixas = mesma área do vão antigo
local fr = conferirFaixas(parede, 3, { 0, 0, 0 }, larg, "retangulo", true, "retângulo por faixas")
util.igual(#fr, 1, "retângulo: 1 faixa")
util.perto(fr[1].v1 - fr[1].v0, 6.5, "retângulo: altura")
util.igual(#R.recortarFaixas(parede, 3, {}), 1, "sem faixa: a peça inteira volta")

-- furo de tiro
util.perto(R.limiarFuro(360, "alvenaria", Cfg), 360 * Cfg.furo.fracao.alvenaria, "limiar do furo no tijolo")
util.igual(R.limiarFuro(10, "vidro", Cfg), math.huge, "vidro não fura (estilhaça)")
util.perto(R.tamanhoFuro(nil, Cfg), Cfg.furo.tamanho, "furo de uma bala")
util.perto(R.tamanhoFuro(99, Cfg), Cfg.furo.max, "furo limitado")
-- espingarda (8 x 12, todos na mesma peça) fura tijolo e concreto de 1 stud num tiro; pistola fura madeira num tiro
local espingarda = R.danoEfetivo(96, "bala", "alvenaria", CfgMat)
assert(espingarda >= R.limiarFuro(360, "alvenaria", Cfg), "espingarda fura tijolo num tiro")
assert(espingarda >= R.limiarFuro(480, "alvenaria", Cfg), "espingarda fura concreto num tiro")
assert(
	R.danoEfetivo(25, "bala", "madeira", CfgMat) >= R.limiarFuro(120, "madeira", Cfg),
	"pistola fura madeira num tiro"
)
assert(
	R.danoEfetivo(25, "bala", "alvenaria", CfgMat) < R.limiarFuro(360, "alvenaria", Cfg),
	"pistola não fura tijolo num tiro"
)

-- prop derrubável
assert(not R.cai(0.4, 0, Cfg), "sapata fica")
assert(R.cai(11, 0, Cfg), "poste cai")
assert(R.bateuNoChao(20, 3, Cfg), "bateu no chão")
assert(not R.bateuNoChao(20, 18, Cfg), "ainda caindo")
assert(not R.bateuNoChao(2, 0, Cfg), "devagar demais para contar")

-- carro mais forte: sedan a 40 st/s atravessa tijolo de 1 stud, a 20 não
assert(
	R.atravessa(R.danoEfetivo(R.danoImpactoCarro(1520, 40, Cfg), "impacto", "alvenaria", CfgMat), 360),
	"sedan a 40 atravessa tijolo"
)
assert(
	not R.atravessa(R.danoEfetivo(R.danoImpactoCarro(1520, 20, Cfg), "impacto", "alvenaria", CfgMat), 360),
	"sedan a 20 não atravessa tijolo"
)

-- peça inteira
assert(R.inteiraSeMenor({ 2, 2.5, 0.3 }, Cfg), "vidro pequeno")
assert(R.inteiraSeMenor({ 2.5, 1, 1 }, Cfg), "no limite")
assert(not R.inteiraSeMenor({ 2.6, 1, 1 }, Cfg), "acima do limite")

-- carro
util.perto(R.danoImpactoCarro(1520, 58, Cfg), 767, "sedan a 58 st/s", 3)
util.perto(R.danoImpactoCarro(2200, 78, Cfg), 2008, "esportivo a fundo", 5)
assert(R.atravessa(380, 300), "atravessa madeira")
assert(not R.atravessa(380, 480), "não atravessa concreto")
util.perto(R.custoCarroceria(100, Cfg), 6, "custo da carroceria")
util.igual(R.danoAtropelo(5, Cfg), 0, "atropelo abaixo da velocidade mínima")
util.igual(R.danoAtropelo(Cfg.carro.atropelo.velMin, Cfg), 0, "atropelo na velocidade mínima")
util.perto(R.danoAtropelo(58, Cfg), 80, "atropelo a 58 st/s")

-- explosão
util.perto(R.quedaExplosao(0, 20), 1, "explosão no centro")
util.perto(R.quedaExplosao(10, 20), 0.5, "explosão na metade")
util.igual(R.quedaExplosao(20, 20), 0, "explosão na borda")
util.igual(R.quedaExplosao(30, 20), 0, "explosão além do raio")

print("Destruicao.spec ok")
