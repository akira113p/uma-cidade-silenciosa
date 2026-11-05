-- Fachada dos props externos (mesmo padrão de mobilia.luau): implementados em props_urbanos.luau; o que falta vira
-- caixa cinza do tamanho do contrato (props_tamanhos). Dono: Opus (integração).
--   local Props = require("./props")
--   Props.carro(ctx, pai, cf, { variante = 2, cor = {..}, rng = rng })     -- cf = quadro da peça no chão
--   Props.colocar(ctx, pai, "poste_luz", x, z, rotY, op)                   -- coordenadas de MUNDO; Y = ctx.topoEm(x, z)
--   Props.tam.carro → { w, h, d, var?, variantes? }
-- Cada função devolve o Model criado (filho de `pai`). `op.obstaculo = false` evita registrar a pegada como obstáculo
-- em ctx.inserirObstaculo (padrão: registra props com pegada ≥ 2 st e que colidem).

local fs = require("@lune/fs")

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local TAM = require("./props_tamanhos")

local Props = { tam = TAM, faltando = {}, implementado = {} }

local impl = {}
if fs.isFile("ferramentas/mapa/props_urbanos.luau") then
	local ok, mod = pcall(require, "./props_urbanos")
	if ok then
		impl = mod
	else
		print("[props] ERRO ao carregar props_urbanos: " .. tostring(mod))
	end
end

local function placeholder(nome: string)
	local t = TAM[nome]
	return function(ctx, pai, cf, op)
		local w = if t.var and op and op.w then op.w else t.w
		local m = Instance.new("Model")
		m.Name = nome
		m:SetAttribute("Prop", nome)
		m:SetAttribute("Placeholder", true)
		ctx.bloco(m, cf, nome, 0, t.h / 2, 0, w, t.h, t.d, (op and op.cor) or { 140, 140, 140 }, "SmoothPlastic")
		m.Parent = pai
		return m
	end
end

for nome in TAM do
	if impl[nome] then
		Props[nome] = impl[nome]
		Props.implementado[nome] = true
	else
		Props[nome] = placeholder(nome)
		table.insert(Props.faltando, nome)
	end
end
table.sort(Props.faltando)

-- Põe `nome` no mundo em (x, z) (Y = topo do chão ali), girado rotY em torno do centro. Registra obstáculo.
function Props.colocar(ctx, pai, nome: string, x: number, z: number, rotY: number?, op)
	local fn = Props[nome]
	assert(fn, "prop inexistente: " .. nome)
	local y = if op and op.y then op.y else ctx.topoEm(x, z)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rotY or 0, 0)
	local m = fn(ctx, pai, cf, op)
	local t = TAM[nome]
	if not (op and op.obstaculo == false) and t.w * t.d >= 4 then
		local w = if t.var and op and op.w then op.w else t.w
		local x0, x1, z0, z1 = ctx.caixaMundo(cf, w, t.d)
		ctx.inserirObstaculo(x0, x1, z0, z1)
	end
	return m
end

return Props
