local R = require("../src/shared/Regras/Raizes")

-- árvore falsa: tabela[pai][nome] = raiz
local function arvore(t: any)
	return function(pai: string, nome: string)
		local p = t[pai]
		return p and p[nome]
	end
end

local mapaC, mapaP, zonaC, zonaP = { "mapaC" }, { "mapaP" }, { "zonaC" }, { "zonaP" }

-- sem ZonaTeste: igual ao comportamento antigo (só Mapa)
local sem = arvore({ Mapa = { Construcoes = mapaC, Props = mapaP } })
local lc = R.coletar("Construcoes", sem)
assert(#lc == 1 and lc[1] == mapaC, "sem zona: só Mapa.Construcoes")
local lp = R.coletar("Props", sem)
assert(#lp == 1 and lp[1] == mapaP, "sem zona: só Mapa.Props")

-- com zona: Mapa primeiro, depois ZonaTeste
local com =
	arvore({ Mapa = { Construcoes = mapaC, Props = mapaP }, ZonaTeste = { Construcoes = zonaC, Props = zonaP } })
lc = R.coletar("Construcoes", com)
assert(#lc == 2 and lc[1] == mapaC and lc[2] == zonaC, "com zona: Mapa e ZonaTeste")
lp = R.coletar("Props", com)
assert(#lp == 2 and lp[1] == mapaP and lp[2] == zonaP, "com zona: props")

-- zona só com Construcoes (sem Props); pais ausentes
local parcial = arvore({ ZonaTeste = { Construcoes = zonaC } })
assert(#R.coletar("Props", parcial) == 0, "sem Props em lugar nenhum: lista vazia")
lc = R.coletar("Construcoes", parcial)
assert(#lc == 1 and lc[1] == zonaC, "sem Mapa: só a zona")
assert(#R.coletar("Construcoes", arvore({})) == 0, "nada existe: vazio, sem erro")

-- a pasta pode surgir ou sumir entre chamadas (sem cache velho)
local vivo: any = { Mapa = { Construcoes = mapaC } }
local achar = arvore(vivo)
assert(#R.coletar("Construcoes", achar) == 1, "antes da zona")
vivo.ZonaTeste = { Construcoes = zonaC }
assert(#R.coletar("Construcoes", achar) == 2, "zona surgiu")
vivo.ZonaTeste = nil
assert(#R.coletar("Construcoes", achar) == 1, "zona sumiu")

-- iguais
assert(R.iguais({}, {}), "vazias iguais")
assert(R.iguais({ mapaC, zonaC }, { mapaC, zonaC }), "mesmas")
assert(not R.iguais({ mapaC }, { mapaC, zonaC }), "tamanho diferente")
assert(not R.iguais({ mapaC, zonaC }, { zonaC, mapaC }), "ordem diferente")
assert(not R.iguais({ mapaC }, { mapaP }), "raiz trocada")

print("Raizes.spec ok")
