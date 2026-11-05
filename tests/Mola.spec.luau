local Mola = require("../src/shared/Regras/Mola")
local util = require("./util")

local alvo = { x = 1, y = -2, z = 3 }

-- converge para o alvo (amortecimento crítico: 2·√k)
local k = 200
local c = 2 * math.sqrt(k)
local e = Mola.novo()
for _ = 1, 120 do
	Mola.passo(e, alvo, k, c, 1 / 60)
end
util.perto(e.x, 1, "converge x", 0.001)
util.perto(e.y, -2, "converge y", 0.001)
util.perto(e.z, 3, "converge z", 0.001)
util.perto(e.vx, 0, "para x", 0.001)

-- amortecimento crítico não ultrapassa o alvo
local e2 = Mola.novo()
local maximo = -math.huge
for _ = 1, 300 do
	Mola.passo(e2, { x = 1, y = 0, z = 0 }, k, c, 1 / 60)
	maximo = math.max(maximo, e2.x)
end
assert(maximo <= 1.001, "sem sobrepasso no amortecimento crítico: " .. maximo)

-- sub-amortecida oscila (ultrapassa)
local e3 = Mola.novo()
local pico = -math.huge
for _ = 1, 300 do
	Mola.passo(e3, { x = 1, y = 0, z = 0 }, k, 2, 1 / 60)
	pico = math.max(pico, e3.x)
end
assert(pico > 1.2, "mola solta ultrapassa o alvo: " .. pico)

-- dt grande (0,05) estável: com subpassos dá o mesmo que muitos passos pequenos
local grande = Mola.novo()
local pequeno = Mola.novo()
for _ = 1, 20 do
	Mola.passo(grande, alvo, 300, 25, 0.05)
	for _ = 1, 3 do
		Mola.passo(pequeno, alvo, 300, 25, 0.05 / 3)
	end
end
util.perto(grande.x, pequeno.x, "dt grande ~ dt pequeno x", 0.01)
util.perto(grande.z, pequeno.z, "dt grande ~ dt pequeno z", 0.01)
util.perto(grande.x, 1, "dt grande converge", 0.01)

-- dt 0,05 com mola dura não explode
local duro = Mola.novo()
for _ = 1, 200 do
	Mola.passo(duro, alvo, 2000, 90, 0.05)
	assert(math.abs(duro.x) < 10 and math.abs(duro.y) < 10 and math.abs(duro.z) < 10, "mola dura explodiu")
end
util.perto(duro.y, -2, "mola dura converge", 0.01)

-- dt absurdo (engasgo de 5 s) é cortado e continua estável
local engasgo = Mola.novo()
Mola.passo(engasgo, alvo, 400, 40, 5)
assert(engasgo.x == engasgo.x and math.abs(engasgo.x) < 10, "dt enorme não explode")

-- dt 0, negativo e NaN não mexem
local parado = Mola.novo(1, 2, 3)
Mola.passo(parado, { x = 9, y = 9, z = 9 }, 100, 10, 0)
Mola.passo(parado, { x = 9, y = 9, z = 9 }, 100, 10, -1)
Mola.passo(parado, { x = 9, y = 9, z = 9 }, 100, 10, 0 / 0)
assert(parado.x == 1 and parado.y == 2 and parado.z == 3 and parado.vx == 0, "dt inválido não mexe")

-- impulso (coice) empurra e a mola devolve
local coice = Mola.novo()
Mola.impulso(coice, 0, 0, 5)
Mola.passo(coice, { x = 0, y = 0, z = 0 }, k, c, 1 / 60)
assert(coice.z > 0, "impulso empurra")
for _ = 1, 180 do
	Mola.passo(coice, { x = 0, y = 0, z = 0 }, k, c, 1 / 60)
end
util.perto(coice.z, 0, "coice volta ao repouso", 0.001)

-- devolve o próprio estado (encadeável)
assert(Mola.passo(coice, alvo, k, c, 0.01) == coice, "devolve o estado")

print("Mola.spec ok")
