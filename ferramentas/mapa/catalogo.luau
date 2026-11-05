-- Fachada do catálogo de edifícios: junta os módulos edificios_*. Variante cujo módulo (ou entrada) ainda não existe vira
-- uma caixa cinza com a pegada do contrato (ctx.modeloConstrucao) — a cidade/áreas geram e se vê o layout antes dos
-- interiores ficarem prontos. Dono: Opus (integração).
--
-- Uso:   local Cat = require("./catalogo")
--        local def = Cat.def.casa_pequena                      -- { modulo, tipo, w, d, andares, regioes, peso }
--        local modelo, info = Cat.construir(ctx, "casa_pequena", spec)
--   spec = { cf (centro da pegada no piso, frente −Z, rotação múltipla de 90°), zona, local_?, andares?, paleta?, rng? }
--   Sem spec.andares, sorteia na faixa; sem spec.rng, usa ctx.rng("cat_" .. variante).

local fs = require("@lune/fs")

local DEF = require("./catalogo_contrato")

local Cat = { def = DEF, reais = {}, faltando = {}, modulos = {} }

local function carregar(nome: string)
	if Cat.modulos[nome] ~= nil then
		return Cat.modulos[nome]
	end
	local mod = false
	if fs.isFile("ferramentas/mapa/" .. nome .. ".luau") then
		local ok, r = pcall(require, "./" .. nome)
		if ok then
			mod = r
		else
			print("[catalogo] ERRO ao carregar " .. nome .. ": " .. tostring(r))
		end
	end
	Cat.modulos[nome] = mod
	return mod
end

local function construirCaixa(ctx, variante: string, d, spec)
	local andares = spec.andares
	local altura = andares * ctx.Mundo.cidade.alturaAndar
	local m = ctx.modeloConstrucao(spec, d.tipo, variante, d.w, d.d, altura, andares)
	m:SetAttribute("Placeholder", true)
	ctx.bloco(m, spec.cf, "Corpo", 0, altura / 2, 0, d.w - 2, altura, d.d - 2, { 150, 150, 150 }, "Concrete")
	return m, { frente = { 0, -(d.d / 2 + 4) } }
end

function Cat.construir(ctx, variante: string, spec)
	local d = assert(DEF[variante], "variante inexistente no catálogo: " .. variante)
	spec.w, spec.d = d.w, d.d
	-- um rng por variante e por ctx, guardado no ctx: chamadas seguidas não repetem o mesmo sorteio
	ctx.rngsCatalogo = ctx.rngsCatalogo or {}
	local rng = spec.rng
	if not rng then
		rng = ctx.rngsCatalogo[variante]
		if not rng then
			rng = ctx.rng("cat_" .. variante)
			ctx.rngsCatalogo[variante] = rng
		end
	end
	spec.rng = rng
	if not spec.andares then
		spec.andares = rng.inteiro(d.andares[1], d.andares[2])
	end
	local mod = carregar(d.modulo)
	local entrada = mod and mod.catalogo and mod.catalogo[variante]
	if entrada then
		Cat.reais[variante] = true
		if not spec.paleta and entrada.paletas then
			spec.paleta = rng.escolher(entrada.paletas)
		end
		return entrada.construir(ctx, spec)
	end
	Cat.faltando[variante] = true
	return construirCaixa(ctx, variante, d, spec)
end

return Cat
