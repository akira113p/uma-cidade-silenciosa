-- Regras puras do seletor de filtros (docs/filtro-ditherdown.md §6). Sem Instance; testável no Lune.
local FiltroSeletor = {}

type Prefs = { [string]: any }
type Limites = { [string]: { number } }

-- Confere uma pref de número com lista de opções: existe, é número e as opções cabem na faixa.
local function validarOpcoes(onde: string, ctrl: any, padrao: Prefs, limites: Limites, erros: { string })
	local pref = ctrl.pref
	if type(pref) ~= "string" or padrao[pref] == nil then
		table.insert(erros, onde .. ": pref inexistente " .. tostring(pref))
		return
	end
	if type(padrao[pref]) ~= "number" then
		table.insert(erros, onde .. ": " .. pref .. " não é número no padrão")
		return
	end
	if type(ctrl.opcoes) ~= "table" or #ctrl.opcoes == 0 then
		table.insert(erros, onde .. ": sem opções")
		return
	end
	local faixa = limites[pref]
	for _, v in ctrl.opcoes do
		if type(v) ~= "number" then
			table.insert(erros, onde .. ": opção não numérica " .. tostring(v))
		elseif faixa and (v < faixa[1] or v > faixa[2]) then
			table.insert(erros, onde .. ": opção " .. v .. " fora da faixa de " .. pref)
		end
	end
end

-- Lista de erros do seletor contra as preferências reais (vazia = ok).
function FiltroSeletor.validar(seletor: any, padrao: Prefs, limites: Limites): { string }
	local erros: { string } = {}

	local ids: { [string]: boolean } = {}
	for i, f in seletor.filtros do
		local onde = "filtro " .. tostring(f.id or i)
		if type(f.id) ~= "string" or ids[f.id] then
			table.insert(erros, onde .. ": id ausente ou repetido")
		else
			ids[f.id] = true
		end
		if f.indisponivel then
			if f.pref ~= nil then
				table.insert(erros, onde .. ": indisponível não pode ter pref")
			end
			if type(f.motivo) ~= "string" or f.motivo == "" then
				table.insert(erros, onde .. ": indisponível sem motivo")
			end
		else
			if type(f.pref) ~= "string" or padrao[f.pref] == nil then
				table.insert(erros, onde .. ": pref inexistente " .. tostring(f.pref))
			elseif type(padrao[f.pref]) ~= "boolean" then
				table.insert(erros, onde .. ": " .. f.pref .. " não é liga/desliga no padrão")
			end
			if f.forca then
				validarOpcoes(onde .. " força", f.forca, padrao, limites, erros)
			end
			for _, extra in f.extras or {} do
				validarOpcoes(onde .. " extra", extra, padrao, limites, erros)
			end
		end
	end

	local idsPreset: { [string]: boolean } = {}
	for i, p in seletor.presets do
		local onde = "preset " .. tostring(p.id or i)
		if type(p.id) ~= "string" or idsPreset[p.id] then
			table.insert(erros, onde .. ": id ausente ou repetido")
		else
			idsPreset[p.id] = true
		end
		for pref, valor in p.ajusta do
			local modelo = padrao[pref]
			if modelo == nil then
				table.insert(erros, onde .. ": pref inexistente " .. tostring(pref))
			elseif type(valor) ~= type(modelo) then
				table.insert(erros, onde .. ": " .. pref .. " com tipo " .. type(valor) .. ", padrão " .. type(modelo))
			end
		end
	end

	return erros
end

-- Cópia da tabela de prefs que o preset manda ao servidor.
function FiltroSeletor.aplicarPreset(preset: any): Prefs
	return table.clone(preset.ajusta)
end

return FiltroSeletor
