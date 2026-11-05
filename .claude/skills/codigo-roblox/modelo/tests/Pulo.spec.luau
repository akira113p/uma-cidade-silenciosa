local Pulo = require("../src/shared/Regras/Pulo")

local function perto(a: number?, b: number, nome: string)
	assert(a ~= nil, nome .. ": esperado número, veio nil")
	assert(math.abs(a - b) < 0.01, string.format("%s: esperado %.2f, veio %.2f", nome, b, a))
end

-- Padrão Roblox: velocidade 16, pulo 7.2, gravidade 196.2
local v0 = math.sqrt(2 * 196.2 * 7.2)
perto(Pulo.alcance(16, 7.2, 196.2, 0), 16 * 2 * v0 / 196.2, "mesmo nível")
perto(Pulo.alcance(16, 7.2, 196.2, 7.2), 16 * v0 / 196.2, "no topo do pulo")
assert(Pulo.alcance(16, 7.2, 196.2, 8) == nil, "acima do pulo deve ser nil")
assert(
	(Pulo.alcance(16, 7.2, 196.2, -10) :: number) > (Pulo.alcance(16, 7.2, 196.2, 0) :: number),
	"descer alcança mais longe"
)

print("Pulo.spec ok")
