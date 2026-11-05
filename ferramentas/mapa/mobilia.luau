-- Fachada da mobília: junta mobilia_casa e mobilia_comercial. Peça que o módulo ainda não implementa (ou módulo que
-- ainda não existe) vira um bloco cinza do tamanho do contrato (mobilia_tamanhos) — assim quem escreve plantas de
-- edifício consegue gerar e olhar o resultado antes de a mobília ficar pronta. Dono: Opus (integração).
--
-- Uso:   local Mob = require("./mobilia")
--        Mob.cama_casal(ctx, pai, cf, { cor = {..}, cor2 = {..}, rng = rng })     -- cf = quadro da peça (piso)
--        Mob.colocar(ctx, pai, "sofa", cfSala, x, yPiso, z, rotY, op)             -- local à sala, gira em torno do centro
--        Mob.tam.sofa → { w, h, d, dono, var?, fixo? }
-- `op` (todos opcionais): cor (principal), cor2 (secundária), cor3, w/h/d (só se var = true), variante (inteiro),
-- rng (ctx.rng(...)), zona. Cada função devolve o Model criado (filho de `pai`).

local fs = require("@lune/fs")

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Instance = roblox.Instance

local TAM = require("./mobilia_tamanhos")

local Mob = { tam = TAM, faltando = {}, implementado = {} }

local function carregar(arquivo: string)
	if not fs.isFile("ferramentas/mapa/" .. arquivo .. ".luau") then
		return {}
	end
	local ok, mod = pcall(require, "./" .. arquivo)
	if not ok then
		print("[mobilia] ERRO ao carregar " .. arquivo .. ": " .. tostring(mod))
		return {}
	end
	return mod
end

local casa = carregar("mobilia_casa")
local comercial = carregar("mobilia_comercial")

local function placeholder(nome: string)
	local t = TAM[nome]
	return function(ctx, pai, cf, op)
		local w = if t.var and op and op.w then op.w else t.w
		local h = if t.var and op and op.h then op.h else t.h
		local d = if t.var and op and op.d then op.d else t.d
		local m = Instance.new("Model")
		m.Name = nome
		m:SetAttribute("Movel", nome)
		m:SetAttribute("Placeholder", true)
		local y = h / 2
		local z = 0
		if t.fixo == "teto" then
			y = -h / 2
		elseif t.fixo == "parede" then
			z = -d / 2
		end
		ctx.bloco(m, cf, nome, 0, y, z, w, h, d, (op and op.cor) or { 150, 150, 150 }, "SmoothPlastic")
		m.Parent = pai
		return m
	end
end

for nome, t in TAM do
	local impl = (if t.dono == "casa" then casa else comercial)[nome]
	if impl then
		Mob[nome] = impl
		Mob.implementado[nome] = true
	else
		Mob[nome] = placeholder(nome)
		table.insert(Mob.faltando, nome)
	end
end
table.sort(Mob.faltando)

-- Põe `nome` numa sala: (x, z) locais ao quadro `cfSala` (Y = 0 do quadro é o piso; yPiso soma). rotY gira em
-- torno do centro da peça (0 = frente para −Z; π/2 = frente para −X; π = frente para +Z; −π/2 = frente para +X).
function Mob.colocar(ctx, pai, nome: string, cfSala, x: number, yPiso: number, z: number, rotY: number?, op)
	local fn = Mob[nome]
	assert(fn, "mobília inexistente: " .. nome)
	return fn(ctx, pai, cfSala * CFrame.new(x, yPiso, z) * CFrame.Angles(0, rotY or 0, 0), op)
end

-- Encosta numa parede: devolve (x, z, rotY) para pôr `nome` com as costas na face da parede de uma sala retangular
-- (xmin..xmax, zmin..zmax locais), no lado "-z"|"+z"|"-x"|"+x" da sala, deslocada `ao_longo` (coordenada ao longo da
-- parede, em X para "±z", em Z para "±x"). Folga = distância da parede (padrão 0,1). A frente da peça aponta para o
-- centro da sala.
function Mob.paraParede(nome: string, lado: string, ao_longo: number, sala, folga: number?)
	local t = TAM[nome]
	local f = folga or 0.1
	if lado == "-z" then
		return ao_longo, sala.z0 + t.d / 2 + f, math.pi -- costas em −Z, frente para +Z
	elseif lado == "+z" then
		return ao_longo, sala.z1 - t.d / 2 - f, 0
	elseif lado == "-x" then
		return sala.x0 + t.d / 2 + f, ao_longo, -math.pi / 2 -- frente para +X
	else
		return sala.x1 - t.d / 2 - f, ao_longo, math.pi / 2
	end
end

return Mob
