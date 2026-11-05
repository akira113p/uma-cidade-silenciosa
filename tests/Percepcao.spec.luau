local Config = require("../src/shared/Config/Monstros")
local Percepcao = require("../src/shared/Regras/Percepcao")
local util = require("./util")

local pos = { x = 10, y = 3, z = -20 }

-- novo
local e0 = Percepcao.novo(100)
util.igual(e0.estado, "Calmo", "novo é Calmo")
assert(e0.alvo == nil, "novo sem alvo")
util.igual(#e0.sons, 0, "novo sem sons")

-- excesso 5 → Investiga (e não muta a entrada)
local e1 = Percepcao.ouvir(e0, 5, pos, 100, Config)
util.igual(e1.estado, "Investiga", "excesso 5")
util.igual(e0.estado, "Calmo", "entrada intacta")
util.igual(#e0.sons, 0, "sons da entrada intactos")
local alvo1 = e1.alvo :: { x: number, y: number, z: number }
util.igual(alvo1.x, 10, "alvo.x")
util.igual(alvo1.z, -20, "alvo.z")
util.igual(e1.ultimoSom, 100, "ultimoSom")
assert(alvo1 ~= pos, "alvo é cópia")

-- fronteira: excesso 0 ouve (Investiga); excesso 10 = Caça; excesso 9.99 = Investiga
util.igual(Percepcao.ouvir(e0, 0, pos, 1, Config).estado, "Investiga", "excesso 0")
util.igual(Percepcao.ouvir(e0, 9.99, pos, 1, Config).estado, "Investiga", "excesso 9.99")
util.igual(Percepcao.ouvir(e0, 10, pos, 1, Config).estado, "Caca", "excesso 10")
-- excesso 12 → Caça
util.igual(Percepcao.ouvir(e0, 12, pos, 1, Config).estado, "Caca", "excesso 12")
-- excesso negativo: nada muda
util.igual(Percepcao.ouvir(e0, -0.1, pos, 1, Config), e0, "excesso < 0 devolve o mesmo estado")

-- 2 sons em 4 s → Caça; em 6 s continua Investiga
local a = Percepcao.ouvir(e0, 5, pos, 0, Config)
util.igual(a.estado, "Investiga", "1º som")
local b = Percepcao.ouvir(a, 5, pos, 4, Config)
util.igual(b.estado, "Caca", "2 sons em 4 s")
util.igual(b.desde, 4, "desde da Caça")
local c = Percepcao.ouvir(a, 5, pos, 6, Config)
util.igual(c.estado, "Investiga", "2 sons em 6 s")
util.igual(#c.sons, 1, "som velho sai da janela")
util.igual(c.desde, 0, "desde não muda sem troca de estado")

-- Caça não rebaixa por som fraco e atualiza o alvo
local f = Percepcao.ouvir(Percepcao.ouvir(e0, 15, pos, 0, Config), 1, { x = 1, y = 2, z = 3 }, 2, Config)
util.igual(f.estado, "Caca", "Caça mantém")
util.igual((f.alvo :: { x: number, y: number, z: number }).x, 1, "alvo atualizado")
util.igual(f.desde, 0, "desde da Caça mantido")

-- tick: Calmo não muda
util.igual(Percepcao.tick(e0, 1e6, Config), e0, "Calmo não muda")

-- tick: 12 s calado → Calmo
local inv = Percepcao.ouvir(e0, 5, pos, 0, Config)
util.igual(Percepcao.tick(inv, 11.9, Config).estado, "Investiga", "11.9 s ainda investiga")
local calmo = Percepcao.tick(inv, 12, Config)
util.igual(calmo.estado, "Calmo", "12 s calado")
assert(calmo.alvo == nil, "Calmo sem alvo")

-- tick: Caça 8 s calado → Investiga (alvo mantido), mais 12 s → Calmo
local caca = Percepcao.ouvir(e0, 15, pos, 0, Config)
util.igual(Percepcao.tick(caca, 7.9, Config).estado, "Caca", "7.9 s ainda caça")
local volta = Percepcao.tick(caca, 8, Config)
util.igual(volta.estado, "Investiga", "8 s calado")
assert(volta.alvo ~= nil, "Investiga mantém alvo")
util.igual(#volta.sons, 0, "sons limpos")
util.igual(Percepcao.tick(volta, 19.9, Config).estado, "Investiga", "ainda investiga 11.9 s depois")
util.igual(Percepcao.tick(volta, 20, Config).estado, "Calmo", "12 s depois da queda → Calmo")

-- um som novo durante o Investiga reinicia o relógio
local reinicio = Percepcao.ouvir(volta, 3, pos, 15, Config)
util.igual(Percepcao.tick(reinicio, 26.9, Config).estado, "Investiga", "relógio reiniciado")

-- estimar: erro ≤ distância × 0.15, y igual, e não é sempre zero
local rng = util.rng(42)
local maior = 0
for i = 1, 2000 do
	local dist = (i % 50) * 12
	local est = Percepcao.estimar(pos, dist, rng, Config)
	local erro = math.sqrt((est.x - pos.x) ^ 2 + (est.z - pos.z) ^ 2)
	assert(erro <= dist * 0.15 + 1e-9, string.format("erro %.3f > %.3f", erro, dist * 0.15))
	util.igual(est.y, pos.y, "y preservado")
	maior = math.max(maior, erro / math.max(dist, 1e-9) * (if dist > 0 then 1 else 0))
end
assert(maior > 0.1, "estimativa deveria usar boa parte do raio permitido")
local perto0 = Percepcao.estimar(pos, 0, rng, Config)
util.igual(perto0.x, pos.x, "distância 0 acerta x")
util.igual(perto0.z, pos.z, "distância 0 acerta z")
-- rng fixo: ângulo 0, raio máximo
local max = Percepcao.estimar(pos, 100, util.seq({ 0, 0.999999 }), Config)
util.perto(max.x - pos.x, 15, "raio máximo no eixo x", 0.01)
util.perto(max.z - pos.z, 0, "raio máximo no eixo z", 0.01)

-- velocidade
util.igual(Percepcao.velocidade(1, "Calmo", Config), 6, "n1 calmo")
util.igual(Percepcao.velocidade(1, "Investiga", Config), 6, "n1 investiga anda")
util.igual(Percepcao.velocidade(1, "Caca", Config), 14, "n1 caça")
util.igual(Percepcao.velocidade(1, "Ataque", Config), 14, "n1 ataque")
util.igual(Percepcao.velocidade(2, "Caca", Config), 22, "n2 caça")
util.igual(Percepcao.velocidade(3, "Calmo", Config), 10, "n3 calmo")
util.igual(Percepcao.velocidade(3, "Caca", Config), 27, "n3 caça")
util.igual(Percepcao.velocidade(99, "Caca", Config), 14, "nível desconhecido cai no 1")
local cfgInv = {
	estados = Config.estados,
	niveis = { [1] = { velocidadeCalmo = 5, velocidadeCaca = 9, velocidadeInvestiga = 7 } },
}
util.igual(Percepcao.velocidade(1, "Investiga", cfgInv), 7, "velocidadeInvestiga opcional")

print("Percepcao.spec ok")
