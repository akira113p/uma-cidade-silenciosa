local util = require("./util")
local Luz = require("../src/shared/Regras/Luz")

util.igual(Luz.luzDaHora(0), 0, "meia-noite")
util.igual(Luz.luzDaHora(12), 1, "meio-dia")
util.igual(Luz.luzDaHora(24), 0, "24 h = meia-noite")

-- limites 0..1 e continuidade (passo de 0.05 h não pula mais que 0.15)
local anterior = Luz.luzDaHora(0)
for i = 1, 480 do
	local f = Luz.luzDaHora(i * 0.05)
	assert(f >= 0 and f <= 1, "fora de 0..1 em " .. i * 0.05)
	assert(math.abs(f - anterior) < 0.15, "salto em " .. i * 0.05)
	anterior = f
end

-- amanhecer sobe, entardecer desce
assert(Luz.luzDaHora(8) > Luz.luzDaHora(6), "sobe de manhã")
assert(Luz.luzDaHora(16) > Luz.luzDaHora(19), "desce à tarde")
