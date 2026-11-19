-- Audição por espécie (docs/som.md §6). Regra: src/shared/Regras/Audicao.luau. PROVISÓRIO: nada foi medido no playtest.
-- limiar = dB acima do ambiente (por banda) que o monstro precisa para ouvir; menor = ouve melhor. chao = limiar da vibração pelo chão
-- (ausente = não sente o chão). erroPorDistancia = raio do erro da posição estimada ÷ distância (substitui
-- Config/Monstros.estados.erroPorDistancia para a espécie).

local function limiar(grave: number, medio: number, agudo: number)
	return { grave = grave, medio = medio, agudo = agudo }
end

return {
	porEspecie = {
		-- rente ao chão: ouvido bom de grave; o Pulso baixa o chão (Config/PresetsMonstro habilidades.pulso.bonusChao)
		Rastejador = { limiar = limiar(0, 2, 6), chao = 14, erroPorDistancia = 0.15 },
		-- corpo envolto abafa o ouvido (pior no agudo); compensa com o sonar
		Wrapper = { limiar = limiar(2, 6, 10), erroPorDistancia = 0.10 },
		-- ouvido fino de médio (passo, voz, porta: o que ele imita) e sabe de onde veio
		Corcunda = { limiar = limiar(6, -4, 0), erroPorDistancia = 0.08 },
		-- barulhento; o próprio raspar o atrapalha (Config/PresetsMonstro habilidades.raspar.surdez)
		MonstroPS1 = { limiar = limiar(2, 4, 8), erroPorDistancia = 0.20 },
		-- gigante (nível 3): ouve mal de perto, sente a corrida pelo chão de longe; as flores ouvem por ela
		Florescida = { limiar = limiar(6, 12, 16), chao = 4, erroPorDistancia = 0.15 },
	},

	-- Espécie sem perfil (Esfolado, Espreitador, Carniceiro, Pernalta): limiar plano = margem do nível (= hoje), sem chão, erro padrão.
	porNivel = { [1] = 0, [2] = 6, [3] = 12 },

	-- Atenção do ouvinte (docs/som.md §6.3): soma ao limiar de todas as bandas. Quem corre ouve pior (o próprio barulho), quem para escuta melhor.
	atencao = {
		Calmo = 0,
		Investiga = -2,
		Caca = 4,
		Ataque = 10,
		parado = -3, -- somado quando a velocidade horizontal do monstro é menor que `velocidadeParado`
		velocidadeParado = 1, -- studs/s
	},

	-- Pausa de escuta (docs/som.md §6.3, decisão #5: DESLIGADA até o usuário aprovar): em Investiga, ao chegar ao ponto estimado sem ouvir
	-- nada, o monstro fica parado `duracao` s (ganha o `parado` de cima).
	pausaEscuta = { ligado = false, duracao = 2 },
}
