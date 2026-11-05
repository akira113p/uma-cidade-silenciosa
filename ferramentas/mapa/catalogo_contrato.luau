-- Contrato do catálogo de edifícios: variante → módulo dono, tipo, pegada (w em X, d em Z, FRENTE = −Z local), faixa de
-- andares, onde aparece e com que peso. Quem constrói (edificios_*.luau) cumpre ESTES números; quem coloca
-- (cidade.luau, areas.luau) planeja com ELES. Mudar um número aqui = avisar o Opus.
--   regioes: onde o sorteio da cidade pode usar ("centro", "comercial", "residencial") — a cidade usa Mundo.cidade.regioes;
--            fora da cidade o módulo `areas` escolhe a variante pelo nome, então regioes pode ficar vazio.
--   peso: probabilidade relativa dentro da região.
--   pegada inclui beiral, letreiro, cobertura de bombas, degraus, varanda: nada do edifício passa dela (± 3 st).
-- Altura: andares × 12 (pé-direito 12) + telhado/cobertura. O primeiro andar fica em Y local = 0 (piso = topo do pad).

local function v(modulo, tipo, w, d, a0, a1, regioes, peso)
	return { modulo = modulo, tipo = tipo, w = w, d = d, andares = { a0, a1 }, regioes = regioes, peso = peso or 10 }
end

local R = { "residencial" }
local C = { "comercial" }
local CE = { "centro" }
local CEC = { "centro", "comercial" }
local CR = { "comercial", "residencial" }
local NADA = {}

return {
	-- edificios_casas ---------------------------------------------------------------------------------------------
	casa_pequena = v("edificios_casas", "casa", 24, 20, 1, 1, R, 30),
	casa_media = v("edificios_casas", "casa", 30, 24, 1, 2, R, 30),
	casa_grande = v("edificios_casas", "casa", 36, 28, 2, 2, R, 15),
	sobrado = v("edificios_casas", "casa", 20, 26, 2, 3, CR, 25),
	cabana = v("edificios_casas", "cabana", 22, 18, 1, 1, NADA),

	-- edificios_altos ---------------------------------------------------------------------------------------------
	apartamentos = v("edificios_altos", "apartamentos", 36, 36, 4, 6, { "centro", "comercial", "residencial" }, 25),
	escritorio = v("edificios_altos", "escritorio", 40, 40, 6, 10, CEC, 30),
	torre = v("edificios_altos", "torre", 44, 44, 10, 14, CE, 25),
	hotel = v("edificios_altos", "hotel", 40, 32, 5, 7, CEC, 12),
	predio_misto = v("edificios_altos", "predio", 36, 30, 3, 5, CEC, 25),
	garagem = v("edificios_altos", "garagem", 44, 36, 3, 4, CEC, 8),

	-- edificios_comercio ------------------------------------------------------------------------------------------
	mercado = v("edificios_comercio", "mercado", 56, 44, 1, 1, CR, 10),
	loja_conveniencia = v("edificios_comercio", "loja", 34, 26, 1, 1, CR, 14),
	loja_roupas = v("edificios_comercio", "loja", 36, 28, 1, 1, C, 12),
	loja_ferragens = v("edificios_comercio", "loja", 40, 30, 1, 1, CR, 8),
	farmacia = v("edificios_comercio", "farmacia", 30, 26, 1, 1, CR, 8),
	restaurante = v("edificios_comercio", "restaurante", 42, 32, 1, 1, C, 12),
	bar = v("edificios_comercio", "bar", 34, 26, 1, 2, CR, 10),
	banco = v("edificios_comercio", "banco", 40, 32, 1, 2, CEC, 8),
	posto = v("edificios_comercio", "posto", 54, 44, 1, 1, CR, 6),
	lanchonete_estrada = v("edificios_comercio", "lanchonete", 36, 28, 1, 1, NADA),
	motel = v("edificios_comercio", "motel", 56, 30, 1, 2, NADA),
	oficina = v("edificios_comercio", "oficina", 40, 32, 1, 1, CR, 5),

	-- edificios_servicos ------------------------------------------------------------------------------------------
	hospital = v("edificios_servicos", "hospital", 64, 44, 2, 3, C, 1),
	delegacia = v("edificios_servicos", "delegacia", 44, 34, 1, 2, C, 1),
	bombeiros = v("edificios_servicos", "bombeiros", 52, 40, 1, 2, CR, 1),
	escola = v("edificios_servicos", "escola", 60, 40, 1, 2, R, 1),
	prefeitura = v("edificios_servicos", "prefeitura", 56, 40, 2, 3, CE, 1),
	biblioteca = v("edificios_servicos", "biblioteca", 44, 34, 1, 2, CR, 1),

	-- edificios_especiais -----------------------------------------------------------------------------------------
	igreja = v("edificios_especiais", "igreja", 30, 54, 1, 1, R, 1),
	capela = v("edificios_especiais", "capela", 20, 28, 1, 1, NADA),
	cripta = v("edificios_especiais", "cripta", 16, 18, 1, 1, NADA),
	guarda = v("edificios_especiais", "guarda", 40, 30, 1, 1, NADA), -- posto da guarda florestal, com torre de 30

	-- edificios_industria -----------------------------------------------------------------------------------------
	galpao_maquinas = v("edificios_industria", "galpao", 70, 50, 1, 1, NADA),
	galpao_estoque = v("edificios_industria", "armazem", 70, 50, 1, 1, NADA),
	galpao_oficina = v("edificios_industria", "oficina", 50, 40, 1, 1, NADA),
	celeiro = v("edificios_industria", "celeiro", 44, 60, 1, 1, NADA),
	serraria_galpao = v("edificios_industria", "serraria", 56, 36, 1, 1, NADA),
}
