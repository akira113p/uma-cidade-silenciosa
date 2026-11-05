-- Testa um módulo de edifícios (ferramentas/mapa/edificios_*.luau) isolado: constrói cada variante do `catalogo` em
-- terreno plano, uma fileira por variante (uma coluna por nº de andares e por paleta), e confere o contrato.
-- Uso (da raiz): lune run ferramentas/testar_modulo.luau -- edificios_casas [--saida build/teste_casas.rbxm]
-- Confere: peça solta, tamanho > 2048, atributos do Model, Pegada, peças fora da pegada (> 3 st de folga), tipo fora de
-- lib.TIPOS, andares fora da faixa declarada, nº de peças por construção, mobília que sobrou como Placeholder.
-- Sai com código ≠ 0 se algo falhar. Mesmo contrato da seção "Catálogo de edifícios" de docs/mapa-v2.md.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Mundo = require("../src/shared/Config/Mundo")
local planoMod = require("./mapa/plano")
local lib = require("./mapa/lib")
local Mob = require("./mapa/mobilia")
local CONTRATO = require("./mapa/catalogo_contrato")

local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance

local args = process.args
local nomeModulo = args[1]
assert(nomeModulo, "uso: lune run ferramentas/testar_modulo.luau -- <modulo> [--saida arquivo]")
local saida = "build/teste_" .. nomeModulo .. ".rbxm"
for i = 2, #args do
	if args[i] == "--saida" then
		saida = args[i + 1]
	end
end

local mod = require("./mapa/" .. nomeModulo)
assert(mod.catalogo, nomeModulo .. " não exporta `catalogo`")

local ctx = lib.novoCtx(Mundo, planoMod.criar(Mundo))
local rng = ctx.rng("teste_" .. nomeModulo)
local falhas = {}
local function falha(msg: string)
	table.insert(falhas, msg)
	print("FALHA " .. msg)
end

-- as variantes que o contrato atribui a este módulo têm de existir no catálogo, com as medidas do contrato
local nomes = {}
for nome, c in CONTRATO do
	if c.modulo == nomeModulo then
		if not mod.catalogo[nome] then
			print("FALHA variante do contrato sem implementação: " .. nome)
			process.exit(1)
		end
		table.insert(nomes, nome)
	end
end
for nome in mod.catalogo do
	if not CONTRATO[nome] or CONTRATO[nome].modulo ~= nomeModulo then
		print("FALHA variante fora do contrato (catalogo_contrato.luau): " .. nome)
		process.exit(1)
	end
end
table.sort(nomes)

-- chão de teste
local chao = ctx.bloco(ctx.pastas.Chao, CFrame.new(), "ChaoTeste", 0, -1, 0, 2000, 2, 2000, { 90, 100, 80 }, "Grass")
chao.Name = "ChaoTeste"

local z = 0
local FOLGA_PEGADA = 3.5 -- beiral, calha, degrau de entrada, letreiro
for _, nome in nomes do
	local impl = mod.catalogo[nome]
	local v = {
		tipo = CONTRATO[nome].tipo,
		w = CONTRATO[nome].w,
		d = CONTRATO[nome].d,
		andares = CONTRATO[nome].andares,
		paletas = impl.paletas,
		construir = impl.construir,
	}
	if not lib.TIPOS[v.tipo] then
		falha(nome .. ": tipo '" .. tostring(v.tipo) .. "' fora de lib.TIPOS")
	end
	if type(v.w) ~= "number" or type(v.d) ~= "number" or type(v.construir) ~= "function" then
		falha(nome .. ": faltam w, d ou construir")
		continue
	end
	local aMin, aMax = v.andares[1], v.andares[2]
	local colunas = {}
	for a = aMin, aMax do
		table.insert(colunas, a)
	end
	local nPaletas = math.max(1, if v.paletas then math.min(#v.paletas, 3) else 1)
	local x = -900
	local linhaProfundidade = v.d
	for _, andares in colunas do
		for p = 1, nPaletas do
			for _, rot in { 0, math.pi / 2 } do
				if rot ~= 0 and (andares ~= aMin or p ~= 1) then
					continue
				end
				local cf = CFrame.new(x + v.w / 2, lib.NIVEL_PAD, z + v.d / 2) * CFrame.Angles(0, rot, 0)
				local spec = {
					cf = cf,
					zona = "cidade",
					andares = andares,
					paleta = if v.paletas then v.paletas[p] else nil,
					rng = ctx.rng(nome .. andares .. p),
					w = v.w,
					d = v.d,
				}
				local antes = lib.contar(ctx.mapa)
				local ok, modelo, info = pcall(v.construir, ctx, spec)
				if not ok then
					falha(string.format("%s (andares %d, paleta %d): erro %s", nome, andares, p, tostring(modelo)))
				else
					local etiqueta =
						string.format("%s andares=%d paleta=%d%s", nome, andares, p, if rot ~= 0 then " rot90" else "")
					local depois = lib.contar(ctx.mapa)
					local n = depois - antes
					local ptsFalta = 0
					if modelo:GetAttribute("Tipo") ~= v.tipo then
						falha(
							etiqueta
								.. ": atributo Tipo = "
								.. tostring(modelo:GetAttribute("Tipo"))
								.. ", esperado "
								.. v.tipo
						)
					end
					if modelo:GetAttribute("Interior") ~= true then
						falha(etiqueta .. ": atributo Interior precisa ser true")
					end
					if modelo:GetAttribute("Andares") ~= andares then
						falha(
							etiqueta
								.. ": atributo Andares = "
								.. tostring(modelo:GetAttribute("Andares"))
								.. ", esperado "
								.. andares
						)
					end
					local pegada = modelo:FindFirstChild("Pegada")
					if not pegada then
						falha(etiqueta .. ": sem a peça Pegada (use ctx.modeloConstrucao)")
					else
						local ps = pegada.Size
						if math.abs(ps.X - v.w) > 0.01 or math.abs(ps.Z - v.d) > 0.01 then
							falha(
								etiqueta
									.. ": Pegada "
									.. ps.X
									.. "×"
									.. ps.Z
									.. " ≠ catálogo "
									.. v.w
									.. "×"
									.. v.d
							)
						end
					end
					local mw, md = if rot == 0 then v.w else v.d, if rot == 0 then v.d else v.w
					local x0, x1, z0, z1 =
						cf.Position.X - mw / 2, cf.Position.X + mw / 2, cf.Position.Z - md / 2, cf.Position.Z + md / 2
					local fora = 0
					local altoMax = 0
					for _, d in modelo:GetDescendants() do
						if d:IsA("BasePart") then
							if not d.Anchored then
								falha(etiqueta .. ": peça solta " .. d:GetFullName())
							end
							local pos, s = d.CFrame.Position, d.Size
							local rv, uv, lv = d.CFrame.RightVector, d.CFrame.UpVector, d.CFrame.LookVector
							local ex = math.abs(rv.X) * s.X / 2 + math.abs(uv.X) * s.Y / 2 + math.abs(lv.X) * s.Z / 2
							local ez = math.abs(rv.Z) * s.X / 2 + math.abs(uv.Z) * s.Y / 2 + math.abs(lv.Z) * s.Z / 2
							if
								pos.X - ex < x0 - FOLGA_PEGADA
								or pos.X + ex > x1 + FOLGA_PEGADA
								or pos.Z - ez < z0 - FOLGA_PEGADA
								or pos.Z + ez > z1 + FOLGA_PEGADA
							then
								fora += 1
								if fora <= 3 then
									falha(
										string.format(
											"%s: %s fora da pegada (%.1f, %.1f, tam %.1f×%.1f)",
											etiqueta,
											d.Name,
											pos.X - cf.Position.X,
											pos.Z - cf.Position.Z,
											s.X,
											s.Z
										)
									)
								end
							end
							altoMax = math.max(altoMax, pos.Y + s.Y / 2 - lib.NIVEL_PAD)
						end
					end
					for _, d in modelo:GetDescendants() do
						if d:GetAttribute("Placeholder") then
							ptsFalta += 1
						end
					end
					local nLoot = ctx.registrarConstrucao(spec, modelo, info)
					print(
						string.format(
							"%-34s %5d peças | altura %.0f | loot %d%s",
							etiqueta,
							n,
							altoMax,
							nLoot,
							if ptsFalta > 0 then " | " .. ptsFalta .. " móveis Placeholder" else ""
						)
					)
				end
				x += v.w + 24
			end
		end
	end
	z += linhaProfundidade + 30
end

if #Mob.faltando > 0 then
	print("[mobilia] ainda sem implementação (viram bloco cinza): " .. #Mob.faltando .. " peças")
end

fs.writeFile(saida, roblox.serializeModel({ ctx.mapa }))
print(saida .. " gravado")
if #falhas > 0 then
	print(string.format("%d falha(s)", #falhas))
	process.exit(1)
end
print("tudo verde")
