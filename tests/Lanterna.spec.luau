local util = require("./util")
local Lanterna = require("../src/shared/Regras/Lanterna")
local cfg = require("../src/shared/Config/Lanterna")
local Itens = require("../src/shared/Config/Itens")

local function comprimento(v)
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- suavizarDirecao: retorno unitário
local r = Lanterna.suavizarDirecao({ x = 0, y = 0, z = -1 }, { x = 1, y = 0, z = 0 }, 0.016, 0.09)
util.perto(comprimento(r), 1, "unitário")

-- meia-vida: depois de uma meia-vida, o ângulo restante cai à metade (alvo a 90° -> ~45° ou o ponto médio vetorial)
local alvo = { x = 1, y = 0, z = 0 }
local atual = { x = 0, y = 0, z = -1 }
local meio = Lanterna.suavizarDirecao(atual, alvo, 0.09, 0.09)
-- mistura linear com k = 0.5: (0.5, 0, -0.5) normalizado => 45° do alvo
util.perto(meio.x, math.sqrt(0.5), "meia-vida x")
util.perto(meio.z, -math.sqrt(0.5), "meia-vida z")

-- independe do passo de tempo (1 passo de 0.2 s vs 10 de 0.02 s: mesma direção, interpolação esférica)
local a = Lanterna.suavizarDirecao(atual, alvo, 0.2, 0.09)
local b = atual
for _ = 1, 10 do
	b = Lanterna.suavizarDirecao(b, alvo, 0.02, 0.09)
end
local angA = math.atan2(a.x, -a.z)
local angB = math.atan2(b.x, -b.z)
assert(math.abs(angA - angB) < 1e-6, "passo de tempo não muda o resultado")

-- converge: muito tempo = alvo
local fim = Lanterna.suavizarDirecao(atual, alvo, 5, 0.09)
util.perto(fim.x, 1, "converge x")
util.perto(fim.z, 0, "converge z")

-- dt 0 = não mexe; meia-vida 0 = pula para o alvo
local parado = Lanterna.suavizarDirecao(atual, alvo, 0, 0.09)
util.perto(parado.z, -1, "dt 0")
util.perto(Lanterna.suavizarDirecao(atual, alvo, 0.01, 0).x, 1, "meia-vida 0")

-- direção oposta: não vira vetor nulo
local oposta = Lanterna.suavizarDirecao({ x = 0, y = 0, z = -1 }, { x = 0, y = 0, z = 1 }, 0.09, 0.09)
util.perto(comprimento(oposta), 1, "oposta unitária")

-- entrada inválida: sem alvo mantém a atual; sem atual vale o alvo
local mantem = Lanterna.suavizarDirecao({ x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = 0 }, 0.1, 0.09)
util.perto(mantem.y, 1, "alvo nulo mantém atual")
local usa = Lanterna.suavizarDirecao({ x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, 0.1, 0.09)
util.perto(usa.y, 1, "atual nula usa alvo")

-- cintilação: sempre em 0.85..1, determinística, nunca pisca forte
local c = cfg.cintilacao
local menor = 1
for i = 0, 60000 do
	local t = i * 0.01
	local v = Lanterna.cintilacao(t, 42, c)
	assert(v >= 0.85 - 1e-9 and v <= 1 + 1e-9, "cintilação fora de 0.85..1: " .. v)
	menor = math.min(menor, v)
	util.igual(v, Lanterna.cintilacao(t, 42, c), "determinística")
end
assert(menor < 0.97, "tem que haver queda de brilho")
assert(menor >= 0.85 - 1e-9, "queda máxima 15%")
-- sem cfg usa o padrão (igual ao Config)
util.perto(Lanterna.cintilacao(13.37, 7), Lanterna.cintilacao(13.37, 7, c), "padrão = Config", 1e-9)
-- semente diferente, quedas em outros instantes
local diferente = false
for i = 0, 3000 do
	if Lanterna.cintilacao(i * 0.01, 1, c) ~= Lanterna.cintilacao(i * 0.01, 2, c) then
		diferente = true
	end
end
assert(diferente, "sementes diferentes dão cintilações diferentes")

-- intervalo entre quedas: 4 a 12 s (início da queda = brilho sai de 1)
for _, semente in { 1, 99, 123456789 } do
	local inicios = {}
	local anterior = 1
	local passo = 0.005
	for i = 0, 600 / passo do
		local t = i * passo
		local v = Lanterna.cintilacao(t, semente, c)
		if v < 1 and anterior >= 1 then
			table.insert(inicios, t)
		end
		anterior = v
	end
	assert(#inicios > 40, "queda a cada ~8 s em 600 s")
	for i = 2, #inicios do
		local d = inicios[i] - inicios[i - 1]
		assert(
			d >= 4 - 0.02 and d <= 12 + 0.02,
			string.format("intervalo %.2f s fora de 4..12 (semente %d)", d, semente)
		)
	end
end

-- descida rápida: o ponto mais baixo vem logo no começo da queda
do
	local t0
	for i = 0, 2000 do
		local t = i * 0.005
		if Lanterna.cintilacao(t, 5, c) < 1 then
			t0 = t
			break
		end
	end
	assert(t0, "achou uma queda")
	local fundo, tFundo = 1, t0
	for i = 0, 100 do
		local t = t0 + i * 0.005
		local v = Lanterna.cintilacao(t, 5, c)
		if v < fundo then
			fundo, tFundo = v, t
		end
	end
	assert(tFundo - t0 <= c.duracao * c.fracaoDescida + 0.02, "queda rápida")
end

-- t inválido
util.igual(Lanterna.cintilacao(-1, 1), 1, "t negativo")
util.igual(Lanterna.cintilacao(0 / 0, 1), 1, "t NaN")

-- balanço: parado = 0; cresce com a velocidade; respeita o teto
local bal = cfg.balanco
local dx0, dy0 = Lanterna.balanco(0.3, 0, bal)
util.igual(dx0, 0, "parado dx")
util.igual(dy0, 0, "parado dy")
-- no pico vertical: sin(fase) = 1 => t = 1 / (4 f)
local tPico = 1 / (4 * bal.frequencia)
local _, dyAndar = Lanterna.balanco(tPico, bal.velocidadeRef, bal)
util.perto(dyAndar, bal.amplitudeY, "pico vertical andar", 1e-9)
local _, dyCorrer = Lanterna.balanco(tPico, 24, bal)
assert(dyCorrer > dyAndar, "correr balança mais que andar")
local _, dyAgachado = Lanterna.balanco(tPico, 8, bal)
assert(dyAgachado > 0 and dyAgachado < dyAndar, "agachado balança menos")
local _, dyVoo = Lanterna.balanco(tPico, 1000, bal)
util.perto(dyVoo, bal.amplitudeY * bal.fatorMaximo, "teto de amplitude", 1e-9)
-- lateral no pico: sin(fase / 2) = 1 => t = 1 / (2 f)
local dxPico = Lanterna.balanco(1 / (2 * bal.frequencia), bal.velocidadeRef, bal)
util.perto(dxPico, bal.amplitudeX, "pico lateral andar", 1e-9)
local nanX = Lanterna.balanco(1, 0 / 0, bal)
util.igual(nanX, 0, "velocidade NaN")

-- Config e item
assert(cfg.cintilacao.profundidadeMax <= 0.15 + 1e-9, "cintilação: profundidade máxima 15%")
assert(cfg.cintilacao.intervalo - cfg.cintilacao.janela >= 4 and cfg.cintilacao.intervalo + cfg.cintilacao.janela <= 12)
util.igual(cfg.bateria, nil, "sem bateria nesta versão")
local item = Itens.itens.lanterna
assert(item and item.tipo == "lanterna" and item.pilha == 1, "item lanterna")
local noKit = false
for _, k in Itens.kitInicial do
	if k.id == "lanterna" then
		noKit = true
		util.igual(k.slot, 5, "lanterna no slot 5 do kit")
	end
end
assert(noKit, "lanterna no kit inicial")
for _, tabela in { "casa", "loja", "posto" } do
	local achou = false
	for _, e in Itens.tabelas[tabela].itens do
		if e.id == "lanterna" then
			achou = true
			assert(e.peso <= 6, "peso baixo em " .. tabela)
		end
	end
	assert(achou, "lanterna na tabela " .. tabela)
end

print("Lanterna.spec ok")
