local util = require("./util")
local Camera = require("../src/shared/Regras/Camera")
local cfg = require("../src/shared/Config/Camera")
local som = require("../src/shared/Config/Som")

-- fase 0 -> offset 0 em todos os modos
for modo in cfg.modos do
	local dy, dx, roll = Camera.offset(0, modo, 100, cfg)
	util.perto(dy, 0, "dy fase 0 " .. modo)
	util.perto(dx, 0, "dx fase 0 " .. modo)
	util.perto(roll, 0, "roll fase 0 " .. modo)
end

-- Picos: |sin(fase)| = 1 em π/2; sin(fase/2) = 1 em π
local dyAndar, _, _ = Camera.offset(math.pi / 2, "andar", 100, cfg)
util.perto(dyAndar, 0.12, "pico vertical andar")
local _, dxAndar, rollAndar = Camera.offset(math.pi, "andar", 100, cfg)
util.perto(dxAndar, 0.06, "pico lateral andar")
util.perto(rollAndar, 1.0, "pico roll andar")

-- correr > andar > agachado (vertical, lateral e roll), na mesma fase
local fase = 1.3
local dyC, dxC, rC = Camera.offset(fase, "correr", 100, cfg)
local dyA, dxA, rA = Camera.offset(fase, "andar", 100, cfg)
local dyG, dxG, rG = Camera.offset(fase, "agachado", 100, cfg)
assert(dyC > dyA and dyA > dyG and dyG > 0, "vertical: correr > andar > agachado")
assert(dxC > dxA and dxA > dxG and dxG > 0, "lateral: correr > andar > agachado")
assert(rC > rA and rA > rG and rG > 0, "roll: correr > andar > agachado")

-- intensidade 0 -> tudo 0; metade -> metade
for _, modo in { "agachado", "andar", "correr" } do
	local a, b, c = Camera.offset(fase, modo, 0, cfg)
	util.perto(a, 0, "dy intensidade 0 " .. modo)
	util.perto(b, 0, "dx intensidade 0 " .. modo)
	util.perto(c, 0, "roll intensidade 0 " .. modo)
end
local m1, m2, m3 = Camera.offset(fase, "correr", 50, cfg)
util.perto(m1, dyC / 2, "dy metade")
util.perto(m2, dxC / 2, "dx metade")
util.perto(m3, rC / 2, "roll metade")
-- fora da faixa vira clamp
local c1 = Camera.offset(fase, "correr", 500, cfg)
util.perto(c1, dyC, "intensidade acima de 100 vale 100")
local n1 = Camera.offset(fase, "correr", -20, cfg)
util.perto(n1, 0, "intensidade negativa vale 0")

-- modo desconhecido / parado
local p1, p2, p3 = Camera.offset(fase, "parado", 100, cfg)
util.perto(p1 + p2 + p3, 0, "parado")
local q1, q2, q3 = Camera.offset(fase, "voando", 100, cfg)
util.perto(q1 + q2 + q3, 0, "modo desconhecido")

-- avancarFase: um passo = π (um fundo de |sin| por passo); só avança com dt > 0
util.perto(Camera.avancarFase(0, 2, 0.5), math.pi, "avancarFase um passo")
util.perto(Camera.avancarFase(1, 3, 0), 1, "avancarFase dt 0")
local f = 0
for _ = 1, 10000 do
	f = Camera.avancarFase(f, som.passosPorSegundo.correr, 1 / 60)
end
assert(f >= 0 and f < 4 * math.pi + 1e-9, "fase fica limitada")
-- em 1/passosPorSegundo s a fase avança π (calculos.md §5)
util.perto(
	Camera.avancarFase(0, som.passosPorSegundo.andar, 1 / som.passosPorSegundo.andar),
	math.pi,
	"um passo = π",
	1e-6
)

-- tremor linear
util.perto(Camera.tremor(0.4, 0, 0.3), 0.4, "tremor no início")
util.perto(Camera.tremor(0.4, 0.15, 0.3), 0.2, "tremor na metade")
util.perto(Camera.tremor(0.4, 0.3, 0.3), 0, "tremor no fim")
util.perto(Camera.tremor(0.4, 5, 0.3), 0, "tremor depois do fim")
util.perto(Camera.tremor(0.4, 0.1, 0), 0, "duração 0")

-- tremor de aterrissagem: min(v/50, 1) × 0.6, qualquer sinal
util.perto(Camera.tremorAterrissagem(25, cfg), 0.3, "aterrissagem v 25")
util.perto(Camera.tremorAterrissagem(-25, cfg), 0.3, "aterrissagem v -25")
util.perto(Camera.tremorAterrissagem(50, cfg), 0.6, "aterrissagem v 50")
util.perto(Camera.tremorAterrissagem(200, cfg), 0.6, "aterrissagem satura")
util.perto(Camera.tremorAterrissagem(0, cfg), 0, "aterrissagem v 0")

-- FOV: base + 8 correndo
util.perto(Camera.fovAlvo("parado", 70, cfg), 70, "fov parado")
util.perto(Camera.fovAlvo("andar", 80, cfg), 80, "fov andar")
util.perto(Camera.fovAlvo("correr", 70, cfg), 78, "fov correr")
util.perto(Camera.fovAlvo("correr", 90, cfg), 98, "fov correr base 90")

-- modo
util.igual(Camera.modo(false, false, false), "parado", "modo parado")
util.igual(Camera.modo(true, true, true), "agachado", "agachado vence correr")
util.igual(Camera.modo(false, true, true), "correr", "modo correr")
util.igual(Camera.modo(false, true, false), "parado", "correr sem mover = parado")
util.igual(Camera.modo(false, false, true), "andar", "modo andar")

print("Camera.spec ok")
