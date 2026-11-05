local Armas = require("../src/shared/Regras/Armas")
local ConfigArmas = require("../src/shared/Config/Armas")
local Corpo = require("../src/shared/Config/Corpo")
local util = require("./util")

-- cadência
assert(Armas.podeAtacar(-math.huge, 0, 0.35), "primeiro ataque sempre pode")
assert(Armas.podeAtacar(10, 10.35, 0.35), "exatamente na cadência pode")
assert(not Armas.podeAtacar(10, 10.2, 0.35), "antes da cadência não pode")
assert(not Armas.podeAtacar(10, 9, 0.35), "relógio voltando não pode")
assert(not Armas.podeAtacar(0 / 0, 5, 0.35), "NaN não pode")
assert(not Armas.podeAtacar(0, 0 / 0, 0.35), "agora NaN não pode")

-- origem contra a cabeça
local cabeca = { x = 10, y = 5, z = 10 }
assert(Armas.origemValida({ x = 10, y = 5, z = 10 }, cabeca, ConfigArmas.toleranciaOrigem), "origem na cabeça")
assert(Armas.origemValida({ x = 13, y = 5, z = 14 }, cabeca, ConfigArmas.toleranciaOrigem), "origem a 5 studs")
assert(
	not Armas.origemValida({ x = 30, y = 5, z = 10 }, cabeca, ConfigArmas.toleranciaOrigem),
	"origem forjada a 20 studs"
)
assert(not Armas.origemValida({ x = 0 / 0, y = 5, z = 10 }, cabeca, ConfigArmas.toleranciaOrigem), "origem NaN")
assert(not Armas.origemValida({ x = math.huge, y = 5, z = 10 }, cabeca, ConfigArmas.toleranciaOrigem), "origem inf")

-- direção: magnitude 0.5..1.5
local d = Armas.normalizarDirecao({ x = 0, y = 0, z = -1.2 }, 0.5, 1.5)
assert(d ~= nil, "magnitude 1.2 aceita")
util.perto(d.z, -1, "normalizada")
assert(Armas.normalizarDirecao({ x = 0, y = 0, z = 0.4 }, 0.5, 1.5) == nil, "magnitude 0.4 rejeitada")
assert(Armas.normalizarDirecao({ x = 0, y = 0, z = 2 }, 0.5, 1.5) == nil, "magnitude 2 rejeitada")
assert(Armas.normalizarDirecao({ x = 0 / 0, y = 0, z = 1 }, 0.5, 1.5) == nil, "NaN rejeitado")
assert(Armas.normalizarDirecao({ x = 0, y = 0, z = 0 }, 0.5, 1.5) == nil, "zero rejeitado")

-- espalhamento
local function ang(a, b)
	local c = a.x * b.x + a.y * b.y + a.z * b.z
	return math.deg(math.acos(math.clamp(c, -1, 1)))
end
local frente = { x = 0, y = 0, z = -1 }
local sem = Armas.espalhar(frente, 0, util.rng(1))
util.perto(sem.z, -1, "graus 0 mantém a direção")
local rng = util.rng(42)
for _ = 1, 500 do
	local dir = { x = rng() - 0.5, y = rng() - 0.5, z = rng() - 0.5 }
	local m = math.sqrt(dir.x ^ 2 + dir.y ^ 2 + dir.z ^ 2)
	dir = { x = dir.x / m, y = dir.y / m, z = dir.z / m }
	local r = Armas.espalhar(dir, 3, rng)
	util.perto(math.sqrt(r.x ^ 2 + r.y ^ 2 + r.z ^ 2), 1, "unitário")
	assert(ang(dir, r) <= 3 + 1e-6, "dentro do cone")
end
local vertical = Armas.espalhar({ x = 0, y = 1, z = 0 }, 2, util.rng(7))
assert(ang({ x = 0, y = 1, z = 0 }, vertical) <= 2 + 1e-6, "cone na vertical")
-- rng máximo = desvio máximo
local maximo = Armas.espalhar(frente, 3, util.seq({ 0.9999999, 0 }))
util.perto(ang(frente, maximo), 3, "desvio máximo ≈ cone", 0.01)

-- dano
local pistola = ConfigArmas.armas.pistola
util.perto(Armas.dano(pistola, "Torso", Corpo), 25, "pistola no torso")
util.perto(Armas.dano(pistola, "Cabeca", Corpo), 50, "pistola na cabeça ×2")
util.perto(Armas.dano(ConfigArmas.armas.faca, "BracoE", Corpo), 18, "faca no braço")
util.perto(Armas.dano(ConfigArmas.armas.machado, "Cabeca", Corpo), 80, "machado na cabeça")

-- espalhamento com braço zerado
util.perto(Armas.multEspalhamento(false, Corpo), 1, "braço ok")
util.perto(Armas.multEspalhamento(true, Corpo), 2, "braço zerado ×2")

-- queda de dano com a distância
local A = ConfigArmas.armas
local ak = A.ak74 -- queda inicio 150, minimo 0.55, alcance 500
util.perto(Armas.fatorQueda(ak, 0), 1, "queda: colado")
util.perto(Armas.fatorQueda(ak, 150), 1, "queda: no início")
util.perto(Armas.fatorQueda(ak, 325), 0.775, "queda: meio (1 -> 0,55)")
util.perto(Armas.fatorQueda(ak, 500), 0.55, "queda: no alcance")
util.perto(Armas.fatorQueda(ak, 900), 0.55, "queda: além do alcance fica no mínimo")
util.perto(Armas.fatorQueda({ dano = 10, alcance = 5 }, 4), 1, "sem queda vale 1")
util.perto(Armas.danoNaDistancia(ak, 325), 28 * 0.775, "danoNaDistancia")
util.perto(Armas.danoNaDistancia(A.escopeta, 5), 12, "escopeta colada = 12 por chumbinho")
util.perto(Armas.danoNaDistancia(A.escopeta, 120), 12 * 0.15, "escopeta no alcance")

-- bloom
local ar = A.ar15 -- porTiro 0.4, máximo 3, recuperação 5
util.perto(Armas.bloomAposTiro(ar, 0), 0.4, "bloom sobe porTiro")
util.perto(Armas.bloomAposTiro(ar, 2.9), 3, "bloom satura no máximo")
util.perto(Armas.bloomAposTiro(ar, 3), 3, "bloom no teto fica")
util.perto(Armas.bloomRecuperado(ar, 3, 0.2), 2, "bloom cai recuperação × dt")
util.perto(Armas.bloomRecuperado(ar, 3, 10), 0, "bloom zera, nunca negativo")
util.perto(Armas.bloomRecuperado(ar, 1, -1), 1, "dt negativo não aumenta")
util.perto(Armas.bloomAposTiro(A.escopeta, 0), 0, "escopeta sem bloom")

-- espalhamento total
util.perto(Armas.espalhamentoTotal(ar, 0, "parado", false, ConfigArmas, Corpo), 0.7, "total: parado, sem bloom")
util.perto(Armas.espalhamentoTotal(ar, 1, "parado", false, ConfigArmas, Corpo), 1.7, "total: soma o bloom")
util.perto(Armas.espalhamentoTotal(ar, 1, "correndo", false, ConfigArmas, Corpo), 1.7 * 1.9, "total: correndo")
util.perto(Armas.espalhamentoTotal(ar, 1, "agachado", false, ConfigArmas, Corpo), 1.7 * 0.7, "total: agachado")
util.perto(
	Armas.espalhamentoTotal(ar, 1, "andando", true, ConfigArmas, Corpo),
	1.7 * 1.25 * 2,
	"total: braço zerado x2"
)
util.perto(Armas.espalhamentoTotal(ar, 0, "voando", false, ConfigArmas, Corpo), 0.7, "estado desconhecido vale 1")

-- estado do atirador (limiar de andar = 1)
util.igual(Armas.estadoDoAtirador(false, false, 0, 1), "parado", "estado: parado")
util.igual(Armas.estadoDoAtirador(false, false, 16, 1), "andando", "estado: andando")
util.igual(Armas.estadoDoAtirador(false, true, 24, 1), "correndo", "estado: correndo")
util.igual(Armas.estadoDoAtirador(false, true, 0, 1), "parado", "estado: tecla de correr parado não é correndo")
util.igual(Armas.estadoDoAtirador(true, false, 0, 1), "agachado", "estado: agachado parado")
util.igual(Armas.estadoDoAtirador(true, false, 8, 1), "agachado", "estado: agachado andando devagar")
util.igual(Armas.estadoDoAtirador(true, true, 24, 1), "correndo", "estado: correndo vence agachado")

-- pode disparar
local ok, motivo = Armas.podeDisparar(ar, 5, false, false)
assert(ok and motivo == nil, "pode com pente")
ok, motivo = Armas.podeDisparar(ar, 0, false, false)
assert(not ok and motivo == "vazio", "pente zerado: vazio")
ok, motivo = Armas.podeDisparar(ar, 5, true, false)
assert(not ok and motivo == "recarregando", "recarregando")
ok, motivo = Armas.podeDisparar(ar, 0, true, false)
assert(not ok and motivo == "recarregando", "recarregando vence vazio")
ok, motivo = Armas.podeDisparar(ar, 5, false, true)
assert(not ok and motivo == "usando", "usando item")

-- recarga de pente
local p, r, m = Armas.recarregarPente(10, 30, 100)
assert(p == 30 and r == 80 and m == 20, "pente completa: " .. p .. "/" .. r .. "/" .. m)
p, r, m = Armas.recarregarPente(10, 30, 7)
assert(p == 17 and r == 0 and m == 7, "reserva menor que o buraco move só o que há")
p, r, m = Armas.recarregarPente(30, 30, 50)
assert(p == 30 and r == 50 and m == 0, "pente cheio: 0 movidas")
p, r, m = Armas.recarregarPente(0, 17, 0)
assert(p == 0 and r == 0 and m == 0, "sem reserva: nada")

-- recarga de tubo, cartucho a cartucho
p, r, m = Armas.cartuchoParaTubo(2, 5, 10)
assert(p == 3 and r == 9 and m == 1, "tubo: 1 cartucho")
p, r, m = Armas.cartuchoParaTubo(5, 5, 10)
assert(p == 5 and r == 10 and m == 0, "tubo cheio: 0")
p, r, m = Armas.cartuchoParaTubo(2, 5, 0)
assert(p == 2 and r == 0 and m == 0, "tubo sem reserva: 0")
do
	local pt, rs = 0, 3
	local passos = 0
	repeat
		local mv
		pt, rs, mv = Armas.cartuchoParaTubo(pt, 5, rs)
		passos += mv
	until mv == 0
	assert(pt == 3 and rs == 0 and passos == 3, "tubo com 3 de reserva termina com 3")
end

-- tempo de recarga
util.perto(Armas.tempoRecarga(A.pistola, 0, 50), 1.9, "pente: tempo fixo")
util.perto(Armas.tempoRecarga(A.lancaFoguetes, 0, 2), 3.8, "lançador: tempo fixo")
util.perto(Armas.tempoRecarga(A.escopeta, 5, 20), 0, "tubo cheio: 0")
util.perto(Armas.tempoRecarga(A.escopeta, 4, 20), 0.5 + 0.55 + 0.4, "tubo faltando 1")
util.perto(Armas.tempoRecarga(A.escopeta, 2, 20), 0.5 + 3 * 0.55 + 0.4, "tubo faltando 3")
util.perto(Armas.tempoRecarga(A.escopeta, 0, 20), 0.5 + 5 * 0.55 + 0.4, "tubo faltando 5")
util.perto(Armas.tempoRecarga(A.escopeta, 0, 2), 0.5 + 2 * 0.55 + 0.4, "tubo limitado pela reserva")
util.perto(Armas.tempoRecarga(A.escopeta, 0, 0), 0, "tubo sem reserva: 0")
util.perto(Armas.tempoRecarga(A.escopetaM1912, 0, 20), 0.55 + 6 * 0.6 + 0.4, "M1912 vazia")

-- pelotas
util.igual(Armas.pelotas(A.pistola), 1, "pelotas: pistola 1")
util.igual(Armas.pelotas(A.escopeta), 8, "pelotas: escopeta 8")
util.igual(Armas.pelotas(A.escopetaM1912), 9, "pelotas: M1912 9")

-- explosão: 140 no centro, x0,25 na borda, raio 20
local proj = A.lancaFoguetes.projetil
util.perto(Armas.danoExplosao(0, proj.raioExplosao, proj.danoCentro, proj.fatorBorda), 140, "explosão no centro")
util.perto(
	Armas.danoExplosao(10, proj.raioExplosao, proj.danoCentro, proj.fatorBorda),
	87.5,
	"explosão no meio do raio"
)
util.perto(Armas.danoExplosao(20, proj.raioExplosao, proj.danoCentro, proj.fatorBorda), 35, "explosão na borda")
util.perto(Armas.danoExplosao(20.1, proj.raioExplosao, proj.danoCentro, proj.fatorBorda), 0, "explosão fora do raio")
util.perto(Armas.danoExplosao(-1, 20, 140, 0.25), 0, "distância negativa não vale")
util.perto(Armas.danoExplosao(0 / 0, 20, 140, 0.25), 0, "NaN não vale")

-- configuração coerente: Config/Armas x Config/Itens x Config/Sons
local Itens = require("../src/shared/Config/Itens")
local Sons = require("../src/shared/Config/Sons")
local CLASSES = { faca = 1, contundente = 1, machado = 1, pistola = 1, fuzil = 1, escopeta = 1, lancador = 1 }
local contagem = 0
for id, arma in A do
	contagem += 1
	assert(CLASSES[arma.classe], id .. ": classe inválida " .. tostring(arma.classe))
	assert(arma.tipo == "corpo" or arma.tipo == "fogo", id .. ": tipo")
	assert(arma.cadencia > 0 and arma.alcance > 0 and arma.ruidoDb > 0, id .. ": números positivos")
	assert(Sons[arma.som] ~= nil, id .. ": som sem entrada em Config/Sons: " .. tostring(arma.som))
	assert(Sons[arma.somAcerto] ~= nil, id .. ": somAcerto sem entrada em Config/Sons")
	local item = Itens.itens[id]
	assert(item ~= nil and item.tipo == "arma" and item.arma == id, id .. ": item correspondente com arma = id")
	if arma.tipo == "corpo" then
		assert(arma.dano > 0 and arma.atrasoImpacto ~= nil and arma.atrasoImpacto >= 0, id .. ": corpo a corpo")
	else
		assert(arma.modo == "semi" or arma.modo == "auto", id .. ": modo semi|auto")
		assert(arma.pente >= 1, id .. ": pente >= 1")
		assert(arma.espalhamento ~= nil and arma.espalhamento >= 0, id .. ": espalhamento")
		assert(arma.bloom.porTiro >= 0 and arma.bloom.maximo >= arma.bloom.porTiro, id .. ": bloom")
		assert(arma.bloom.recuperacao > 0, id .. ": bloom recupera")
		assert(arma.coice ~= nil, id .. ": coice")
		local mun = Itens.itens[arma.municao]
		assert(mun ~= nil and mun.tipo == "municao", id .. ": munição existe em Itens: " .. tostring(arma.municao))
		local rec = arma.recarga
		if rec.tipo == "pente" then
			assert(rec.tempo > 0, id .. ": recarga de pente com tempo")
		else
			assert(rec.tipo == "cartucho", id .. ": tipo de recarga")
			assert(rec.inicio >= 0 and rec.porCartucho > 0 and rec.fim >= 0, id .. ": recarga de tubo")
			assert(arma.somCartucho ~= nil and arma.somBombear ~= nil, id .. ": tubo com sons")
		end
		if arma.queda then
			assert(arma.queda.inicio < arma.alcance, id .. ": queda.inicio < alcance")
			assert(arma.queda.minimo > 0 and arma.queda.minimo <= 1, id .. ": queda.minimo")
		end
		if arma.projetil then
			assert(arma.dano == 0 and arma.projetil.raioExplosao > 0, id .. ": lançador sem dano direto")
			assert(Sons[arma.somExplosao] ~= nil, id .. ": somExplosao")
		else
			assert(arma.dano > 0, id .. ": dano")
		end
		if arma.somRecarga then
			for _, passo in arma.somRecarga do
				assert(passo.t >= 0 and passo.t <= 1 and Sons[passo.nome] ~= nil, id .. ": somRecarga " .. passo.nome)
			end
		end
		assert(Sons[arma.somVazio] ~= nil and Sons[arma.somEquipar] ~= nil, id .. ": sons vazio/equipar")
		if arma.somBombear then
			assert(Sons[arma.somBombear] ~= nil and Sons[arma.somCartucho] ~= nil, id .. ": sons do tubo")
		end
	end
end
assert(contagem == 11, "11 armas em Config/Armas, vieram " .. contagem)
-- toda munição de Itens é usada por alguma arma
for id, item in Itens.itens do
	if item.tipo == "municao" then
		local usada = false
		for _, arma in A do
			if arma.municao == id then
				usada = true
			end
		end
		assert(usada, id .. ": munição que nenhuma arma usa")
	end
end
-- loot: em nenhuma tabela a soma dos pesos de armas passa a da comida/bebida (onde há comida); M5, AK e lançador pesam <= 2
for nome, tabela in Itens.tabelas do
	local armas, comida = 0, 0
	for _, entrada in tabela.itens do
		local item = Itens.itens[entrada.id]
		assert(item ~= nil, nome .. ": item inexistente " .. entrada.id)
		if item.tipo == "arma" then
			armas += entrada.peso
		elseif item.tipo == "comida" or item.tipo == "bebida" then
			comida += entrada.peso
		end
		if entrada.id == "carabinaM5" or entrada.id == "ak74" or entrada.id == "lancaFoguetes" then
			assert(entrada.peso <= 2, nome .. ": " .. entrada.id .. " tem que ser rara")
		end
		if item.tipo == "arma" and Itens.itens[item.arma] then
			local cfg = A[item.arma]
			assert(cfg ~= nil, nome .. ": arma sem Config/Armas " .. entrada.id)
		end
	end
	assert(
		armas <= comida or comida == 0 and armas == 0,
		nome .. ": armas (" .. armas .. ") passam a comida (" .. comida .. ")"
	)
end
assert(Itens.penteLoot[1] > 0 and Itens.penteLoot[2] <= 1 and Itens.penteLoot[1] <= Itens.penteLoot[2], "penteLoot")

print("Armas.spec ok")
