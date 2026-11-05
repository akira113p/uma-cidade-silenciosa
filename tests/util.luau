-- Apoio dos testes (Lune). Não é teste: o checar só roda *.spec.luau.

local util = {}

-- Gerador determinístico [0, 1) para os sorteios das regras.
function util.rng(semente: number): () -> number
	local estado = semente % 2147483647
	if estado <= 0 then
		estado += 2147483646
	end
	return function()
		estado = (estado * 16807) % 2147483647
		return (estado - 1) / 2147483646
	end
end

-- Sequência fixa de valores, em loop.
function util.seq(valores: { number }): () -> number
	local i = 0
	return function()
		i = i % #valores + 1
		return valores[i]
	end
end

function util.perto(a: number, b: number, nome: string, tol: number?)
	assert(math.abs(a - b) <= (tol or 0.01), string.format("%s: esperado %.3f, veio %.3f", nome, b, a))
end

function util.igual(a: any, b: any, nome: string)
	assert(a == b, string.format("%s: esperado %s, veio %s", nome, tostring(b), tostring(a)))
end

return util
