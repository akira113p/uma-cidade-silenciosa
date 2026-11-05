-- Fome, sede, calor, estamina (docs/calculos.md §4). Regra: src/shared/Regras/Sobrevivencia.luau. PROVISÓRIO.
-- Taxas por minuto real, exceto estamina (por segundo).

return {
	inicial = { Fome = 100, Sede = 100, Calor = 100, Estamina = 100 },
	maximo = 100,

	fomePorMin = 1.7,
	sedePorMin = 2.5,
	multGastoCorrendo = 1.5,
	danoVazio = { parte = "Torso", valor = 2, intervalo = 10 }, -- fome ou sede em 0

	calorPorMin = {
		dia = 0,
		noite = -1,
		chuva = -3,
		tempestade = -5,
		dentro = 2,
		fogo = 10,
	},
	calorBaixo = 30, -- abaixo disso a estamina máxima cai
	multEstaminaFrio = 0.7,
	danoCongelando = { valor = 1, intervalo = 10 }, -- em cada parte, com calor 0

	estamina = {
		gastoCorrendo = 12, -- por s
		volta = 10, -- por s, depois de esperaVolta
		voltaAgachadoParado = 15,
		esperaVolta = 1.5, -- s sem correr
		minimoParaVoltarACorrer = 25,
		fomeBaixa = 20, -- com fome abaixo disso a volta é multiplicada por multVoltaFomeBaixa
		multVoltaFomeBaixa = 0.5,
	},

	tick = 0.5, -- s entre atualizações no servidor
}
