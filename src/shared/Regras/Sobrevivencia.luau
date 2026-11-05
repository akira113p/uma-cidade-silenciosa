--!strict
-- Sobrevivencia: um passo de fome, sede, calor e estamina (docs/calculos.md §4). Pura. Dono: P5.

export type Barras = { Fome: number, Sede: number, Calor: number, Estamina: number }
export type Contexto = {
	correndo: boolean,
	agachadoParado: boolean,
	condicao: string, -- "dia" | "noite" | "chuva" | "tempestade"
	dentro: boolean,
	pertoFogo: boolean,
	tempoSemCorrer: number, -- segundos sem correr até o início deste passo
}
export type Zeradas = { fome: boolean, sede: boolean, frio: boolean }
export type CfgSobrevivencia = {
	maximo: number,
	fomePorMin: number,
	sedePorMin: number,
	multGastoCorrendo: number,
	calorPorMin: { [string]: number },
	calorBaixo: number,
	multEstaminaFrio: number,
	estamina: {
		gastoCorrendo: number,
		volta: number,
		voltaAgachadoParado: number,
		esperaVolta: number,
		fomeBaixa: number,
		multVoltaFomeBaixa: number,
	},
}

local Sobrevivencia = {}

-- Frio forte reduz o teto da estamina.
function Sobrevivencia.estaminaMaxima(b: Barras, cfg: CfgSobrevivencia): number
	if b.Calor < cfg.calorBaixo then
		return cfg.maximo * cfg.multEstaminaFrio
	end
	return cfg.maximo
end

-- Calor por minuto: fogo > dentro > condição do tempo (condição desconhecida = 0).
local function calorPorMin(ctx: Contexto, cfg: CfgSobrevivencia): number
	if ctx.pertoFogo then
		return cfg.calorPorMin.fogo
	elseif ctx.dentro then
		return cfg.calorPorMin.dentro
	end
	return cfg.calorPorMin[ctx.condicao] or 0
end

function Sobrevivencia.passo(b: Barras, dt: number, ctx: Contexto, cfg: CfgSobrevivencia): (Barras, Zeradas)
	local maximo = cfg.maximo
	local gasto = if ctx.correndo then cfg.multGastoCorrendo else 1

	local fome = b.Fome - cfg.fomePorMin / 60 * dt * gasto
	local sede = b.Sede - cfg.sedePorMin / 60 * dt * gasto
	local calor = b.Calor + calorPorMin(ctx, cfg) / 60 * dt
	fome = math.clamp(fome, 0, maximo)
	sede = math.clamp(sede, 0, maximo)
	calor = math.clamp(calor, 0, maximo)

	local est = cfg.estamina
	local estamina = b.Estamina
	if ctx.correndo then
		estamina -= est.gastoCorrendo * dt
	elseif ctx.tempoSemCorrer >= est.esperaVolta then
		local taxa = if ctx.agachadoParado then est.voltaAgachadoParado else est.volta
		if fome < est.fomeBaixa then
			taxa *= est.multVoltaFomeBaixa
		end
		estamina += taxa * dt
	end
	local novo: Barras = { Fome = fome, Sede = sede, Calor = calor, Estamina = 0 }
	estamina = math.clamp(estamina, 0, Sobrevivencia.estaminaMaxima(novo, cfg))
	novo.Estamina = estamina

	return novo, { fome = fome <= 0, sede = sede <= 0, frio = calor <= 0 }
end

return Sobrevivencia
