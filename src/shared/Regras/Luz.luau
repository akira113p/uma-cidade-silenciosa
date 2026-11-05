-- Luz: regra pura da luz do dia. Usada pelo servidor (Visual) e pelo cliente (filtro). Teste: tests/Luz.spec.luau.

local Luz = {}

-- 0 = noite fechada, 1 = meio-dia. O sol sobe às 6 e desce às 18; um pouco antes e depois ainda há penumbra.
function Luz.luzDaHora(hora: number): number
	local altura = math.sin((hora - 6) / 12 * math.pi) -- -1..1, positiva entre 6 e 18
	return math.clamp(altura * 1.6 + 0.2, 0, 1)
end

return Luz
