-- Contrato dos props externos (decoração urbana/rodoviária/rural): nome → pegada {w (X), h (Y), d (Z)} em studs, frente
-- = −Z local, origem = centro da pegada no chão. Implementados por props_urbanos.luau (agente de decoração).
-- `var = true`: aceita op.w (comprimento) — cercas, muros, guard-rails, cercas vivas. `variantes = n`: op.variante 1..n.
-- Peça dentro de pegada de "colisão" (carro, caçamba…) colide; fios, letreiros e folhas não (CanCollide = false).

local function t(w, h, d, extra)
	local r = { w = w, h = h, d = d }
	if extra then
		for k, val in extra do
			r[k] = val
		end
	end
	return r
end

return {
	-- iluminação e sinalização
	poste_luz = t(1.2, 22, 4), -- poste de rua com braço e luminária; op.acesa = true acende (PointLight de baixo alcance)
	poste_luz_rodovia = t(1.4, 30, 8),
	poste_madeira = t(1, 34, 6), -- poste de telefone/energia com cruzeta e isoladores
	semaforo = t(1.6, 20, 6),
	placa_pare = t(2.4, 11, 0.5),
	placa_velocidade = t(2, 11, 0.5, { variantes = 3 }),
	placa_rua = t(5, 12, 0.5), -- nome de rua em letreiro; op.texto
	placa_direcao = t(10, 12, 0.6, { var = true }), -- placa verde de rodovia; op.texto
	placa_aviso = t(2.6, 11, 0.5, { variantes = 4 }),
	outdoor = t(24, 28, 3),
	-- mobiliário urbano
	hidrante = t(1.4, 2.8, 1.4),
	lixeira_rua = t(1.8, 3, 1.8),
	cacamba = t(7, 4.5, 4),
	banco_praca = t(6, 3, 2),
	ponto_onibus = t(10, 8, 4),
	caixa_correio = t(1.4, 3.8, 1.4),
	telefone_publico = t(2, 7.5, 2),
	banca_jornal = t(6, 9, 5),
	caixa_energia = t(3, 4, 3), -- transformador de calçada
	fonte = t(14, 6, 14),
	estatua = t(5, 14, 5),
	coreto = t(18, 14, 18),
	canteiro = t(8, 2.8, 4),
	arvore_rua = t(8, 18, 8), -- árvore de calçada/parque (bordo/plátano), copa em blocos PS1
	arbusto = t(4, 3, 4),
	cerca_viva = t(8, 3.5, 2.5, { var = true }),
	barraca_feira = t(8, 8, 6),
	-- playground
	balanco = t(8, 7, 6),
	escorregador = t(6, 7, 12),
	gangorra = t(10, 3, 2),
	-- barreiras e cercas
	barreira_concreto = t(3, 3, 8),
	cone = t(1.2, 2, 1.2),
	cerca_arame = t(8, 4.5, 0.4, { var = true }), -- tela de arame com postes; op.w = comprimento
	cerca_madeira = t(8, 4, 0.6, { var = true }),
	muro_baixo = t(10, 4, 1, { var = true }),
	guard_rail = t(12, 2.4, 1.2, { var = true }),
	-- veículos (parados, abandonados). op.variante: carro 1 sedan, 2 hatch, 3 picape, 4 van, 5 táxi; op.cor
	carro = t(5.6, 4.6, 11, { variantes = 5 }),
	carro_destruido = t(5.6, 4.6, 11, { variantes = 3 }), -- queimado / sem portas / de lado
	caminhao = t(8, 11, 22),
	onibus = t(8, 11, 26),
	trator = t(8, 9, 12),
	trailer = t(8, 8, 22),
	container_carga = t(20, 8.6, 8),
	-- cemitério
	lapide = t(2, 3.2, 0.8, { variantes = 5 }),
	cruz_cemiterio = t(3, 6, 1),
	-- lixo e cenas
	entulho = t(8, 3, 6),
	pilha_pneus_ext = t(5, 5, 5),
	mancha_sangue = t(4, 0.1, 4, { variantes = 3 }), -- decal chapado no chão (Part fina, CanCollide = false)
	fardo_feno_ext = t(5, 4.5, 5),
	torre_celular = t(10, 60, 10),
	pilha_toras = t(12, 6, 6),
	tenda_feira = t(10, 9, 8),
}
