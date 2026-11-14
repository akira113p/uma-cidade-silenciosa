local util = require("./util")
local R = require("../src/shared/Regras/FiltroSeletor")
local seletor = require("../src/shared/Config/Filtro/Seletor")
local camera = require("../src/shared/Config/Camera")

-- dados reais: tudo que o seletor cita existe e é coerente com as preferências
local erros = R.validar(seletor, camera.preferenciasPadrao, camera.limitesPreferencias)
util.igual(#erros, 0, "dados reais sem erro: " .. table.concat(erros, "; "))

-- tudo nasce ligado no máximo, menos as Scanlines suaves (pedido do usuário 2026-11-13)
for _, f in seletor.filtros do
	if f.pref then
		util.igual(camera.preferenciasPadrao[f.pref], f.pref ~= "Pref_FScanSuave", "padrão " .. f.pref)
		if f.forca then
			util.igual(camera.preferenciasPadrao[f.forca.pref], 100, "força máxima " .. f.forca.pref)
		end
	end
end

-- Pixelado fica indisponível, com motivo
local achouPixelado = false
for _, f in seletor.filtros do
	if f.id == "Pixelado" then
		achouPixelado = true
		util.igual(f.indisponivel, true, "Pixelado indisponível")
	end
end
assert(achouPixelado, "Pixelado listado")

-- aplicarPreset devolve cópia
local combinado
for _, p in seletor.presets do
	if p.id == "Combinado" then
		combinado = p
	end
end
assert(combinado, "preset Combinado existe")
local copia = R.aplicarPreset(combinado)
util.igual(copia.Pref_FDither, true, "Combinado liga o dither")
util.igual(copia.Pref_FDitherMatriz, 2, "Combinado usa matriz 2")
copia.Pref_FDither = false
util.igual(combinado.ajusta.Pref_FDither, true, "cópia não altera o original")

-- casos ruins fabricados
local padrao = { A = false, AF = 50, M = 4, B = true }
local limites = { AF = { 0, 100 }, M = { 2, 16 } }
local function ruim(seletorRuim: any, trecho: string, nome: string)
	local e = R.validar(seletorRuim, padrao, limites)
	local achou = false
	for _, msg in e do
		if string.find(msg, trecho, 1, true) then
			achou = true
		end
	end
	assert(achou, nome .. ": esperava erro com '" .. trecho .. "', veio: " .. table.concat(e, "; "))
end

local bom = {
	filtros = { { id = "a", pref = "A", forca = { pref = "AF", opcoes = { 0, 50, 100 } } } },
	presets = { { id = "p", ajusta = { A = true, AF = 10 } } },
}
util.igual(#R.validar(bom, padrao, limites), 0, "caso bom sem erro")

ruim({ filtros = { { id = "a", pref = "X" } }, presets = {} }, "pref inexistente", "pref do filtro")
ruim(
	{ filtros = { { id = "a", pref = "A", forca = { pref = "X", opcoes = { 1 } } } }, presets = {} },
	"pref inexistente",
	"pref da força"
)
ruim(
	{ filtros = { { id = "a", pref = "A", extras = { { pref = "Y", opcoes = { 2 } } } } }, presets = {} },
	"pref inexistente",
	"pref do extra"
)
ruim({ filtros = {}, presets = { { id = "p", ajusta = { Z = true } } } }, "pref inexistente", "pref do preset")
ruim(
	{ filtros = { { id = "a", pref = "A" }, { id = "a", pref = "A" } }, presets = {} },
	"repetido",
	"id de filtro repetido"
)
ruim(
	{ filtros = {}, presets = { { id = "p", ajusta = {} }, { id = "p", ajusta = {} } } },
	"repetido",
	"id de preset repetido"
)
ruim({ filtros = {}, presets = { { id = "p", ajusta = { A = 1 } } } }, "tipo", "tipo errado no preset")
ruim({ filtros = {}, presets = { { id = "p", ajusta = { AF = true } } } }, "tipo", "boolean onde é número")
ruim(
	{ filtros = { { id = "a", pref = "A", forca = { pref = "AF", opcoes = { 0, 200 } } } }, presets = {} },
	"fora da faixa",
	"opção fora da faixa"
)
ruim(
	{ filtros = { { id = "a", pref = "A", extras = { { pref = "M", opcoes = { 1, 4 } } } } }, presets = {} },
	"fora da faixa",
	"extra fora da faixa"
)
ruim({ filtros = { { id = "a", pref = "AF" } }, presets = {} }, "liga/desliga", "pref de número como liga")
ruim(
	{ filtros = { { id = "a", indisponivel = true, pref = "A", motivo = "x" } }, presets = {} },
	"não pode ter pref",
	"indisponível com pref"
)
ruim({ filtros = { { id = "a", indisponivel = true } }, presets = {} }, "sem motivo", "indisponível sem motivo")

print("FiltroSeletor.spec ok")
