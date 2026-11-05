local Sobrevivencia = require("../src/shared/Regras/Sobrevivencia")
local cfg = require("../src/shared/Config/Sobrevivencia")
local util = require("./util")

local function ctx(extra: { [string]: any }?): any
	local c = {
		correndo = false,
		agachadoParado = false,
		condicao = "dia",
		dentro = false,
		pertoFogo = false,
		tempoSemCorrer = 100,
	}
	for k, v in extra or {} do
		c[k] = v
	end
	return c
end

local DT = cfg.tick

-- avança `segundos` repetindo o mesmo contexto; devolve as barras e as flags do último passo
local function simular(b: any, segundos: number, c: any): (any, any)
	local zeradas
	for _ = 1, math.round(segundos / DT) do
		b, zeradas = Sobrevivencia.passo(b, DT, c, cfg)
	end
	return b, zeradas
end

local cheio = table.clone(cfg.inicial)

-- 60 min parado: fome ≈ 0 (1,7/min); sede zera aos 40 min
local b60, z60 = simular(cheio, 60 * 60, ctx())
util.perto(b60.Fome, 0, "fome após 60 min", 0.5)
util.perto(b60.Sede, 0, "sede após 60 min", 0.5)
util.igual(z60.fome, true, "flag fome")
util.igual(z60.sede, true, "flag sede")
util.igual(z60.frio, false, "dia não congela")
local b30, z30 = simular(cheio, 30 * 60, ctx())
util.perto(b30.Fome, 100 - 1.7 * 30, "fome após 30 min", 0.05)
util.perto(b30.Sede, 100 - 2.5 * 30, "sede após 30 min", 0.05)
util.igual(z30.fome, false, "fome ainda não zerou aos 30 min")

-- não muta a entrada
util.igual(cheio.Fome, 100, "entrada intacta")

-- correr: gasto de fome e sede ×1,5
local bCorrer = simular(cheio, 60, ctx({ correndo = true, tempoSemCorrer = 0 }))
util.perto(100 - bCorrer.Fome, 1.7 * 1.5, "fome correndo 1 min", 0.01)
util.perto(100 - bCorrer.Sede, 2.5 * 1.5, "sede correndo 1 min", 0.01)

-- estamina: 8 s correndo -> ≈ 4
local bEst = simular(cheio, 8, ctx({ correndo = true, tempoSemCorrer = 0 }))
util.perto(bEst.Estamina, 4, "estamina após 8 s correndo", 0.01)
local bEsgotada = simular(cheio, 20, ctx({ correndo = true, tempoSemCorrer = 0 }))
util.igual(bEsgotada.Estamina, 0, "estamina não fica negativa")

-- estamina volta só depois de 1,5 s sem correr (+10/s)
local b = bEst
local tempo = 0
for _ = 1, 3 do -- 1,5 s de espera
	b = Sobrevivencia.passo(b, DT, ctx({ tempoSemCorrer = tempo }), cfg)
	tempo += DT
end
util.perto(b.Estamina, 4, "sem volta durante a espera", 0.001)
b = Sobrevivencia.passo(b, DT, ctx({ tempoSemCorrer = tempo }), cfg)
util.perto(b.Estamina, 4 + 10 * DT, "volta +10/s depois da espera", 0.001)
util.perto(simular(bEst, 5, ctx({ tempoSemCorrer = 2 })).Estamina, 54, "5 s de volta", 0.01)
util.igual(simular(bEst, 30, ctx({ tempoSemCorrer = 2 })).Estamina, 100, "volta ao máximo")

-- agachado parado: +15/s; fome baixa: metade
local bAgachado = simular(bEst, 1, ctx({ tempoSemCorrer = 2, agachadoParado = true }))
util.perto(bAgachado.Estamina, 4 + 15, "agachado parado +15/s", 0.01)
local famintoBase = { Fome = 10, Sede = 100, Calor = 100, Estamina = 4 }
local bFaminto = simular(famintoBase, 1, ctx({ tempoSemCorrer = 2 }))
util.perto(bFaminto.Estamina, 4 + 5, "fome < 20: volta pela metade", 0.01)

-- calor por minuto: dia 0, noite -1, chuva -3, tempestade -5, dentro +2, fogo +10
util.perto(simular(cheio, 600, ctx({ condicao = "dia" })).Calor, 100, "calor dia", 0.01)
util.perto(simular(cheio, 600, ctx({ condicao = "noite" })).Calor, 90, "calor noite 10 min", 0.01)
util.perto(simular(cheio, 600, ctx({ condicao = "chuva" })).Calor, 70, "calor chuva 10 min", 0.01)
util.perto(simular(cheio, 600, ctx({ condicao = "tempestade" })).Calor, 50, "calor tempestade 10 min", 0.01)
util.perto(simular(cheio, 600, ctx({ condicao = "desconhecida" })).Calor, 100, "condição desconhecida = 0", 0.01)
local frio = { Fome = 100, Sede = 100, Calor = 50, Estamina = 100 }
util.perto(simular(frio, 300, ctx({ dentro = true, condicao = "tempestade" })).Calor, 60, "dentro: +2/min", 0.01)
util.perto(simular(frio, 300, ctx({ pertoFogo = true, dentro = true })).Calor, 100, "fogo: +10/min, teto 100", 0.01)
util.perto(simular(frio, 60, ctx({ pertoFogo = true, condicao = "noite" })).Calor, 60, "fogo vence a noite", 0.01)

-- calor em 0: flag frio
local _, zFrio = simular({ Fome = 100, Sede = 100, Calor = 3, Estamina = 100 }, 120, ctx({ condicao = "tempestade" }))
util.igual(zFrio.frio, true, "calor 0 -> frio")

-- estamina máxima cai a ×0,7 com calor < 30
util.perto(Sobrevivencia.estaminaMaxima(cheio, cfg), 100, "máxima normal")
util.perto(
	Sobrevivencia.estaminaMaxima({ Fome = 100, Sede = 100, Calor = 29, Estamina = 100 }, cfg),
	70,
	"máxima no frio"
)
util.perto(
	Sobrevivencia.estaminaMaxima({ Fome = 100, Sede = 100, Calor = 30, Estamina = 100 }, cfg),
	100,
	"máxima em 30"
)
local congelando = simular({ Fome = 100, Sede = 100, Calor = 20, Estamina = 100 }, 1, ctx())
util.perto(congelando.Estamina, 70, "estamina cortada no teto frio", 0.001)
util.perto(
	simular({ Fome = 100, Sede = 100, Calor = 20, Estamina = 0 }, 20, ctx()).Estamina,
	70,
	"volta só até 70",
	0.001
)

print("Sobrevivencia.spec ok")
