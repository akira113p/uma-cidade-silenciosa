-- Gera o mapa inteiro em mapa/Mapa.rbxm chamando os módulos de ferramentas/mapa/ em ordem. Contrato: docs/mapa-v2.md.
-- Uso (da raiz do projeto):
--   lune run ferramentas/gerar_mapa.luau -- --final                  gera tudo e grava mapa/Mapa.rbxm (só o Opus faz isso)
--   lune run ferramentas/gerar_mapa.luau -- --so relevo,estradas --saida build/meu.rbxm   só esses módulos (teste)
--   lune run ferramentas/gerar_mapa.luau                              tudo, mas grava em build/mapa_teste.rbxm
-- Determinístico: mesma semente (Config/Mundo.semente) = mesmo mapa. O Rojo sincroniza mapa/Mapa.rbxm em Workspace.Mapa;
-- não editar o mapa no Studio (é sobrescrito na próxima geração).

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local datetime = require("@lune/datetime")

local Mundo = require("../src/shared/Config/Mundo")
local Monstros = require("../src/shared/Config/Monstros")

local planoMod = require("./mapa/plano")
local lib = require("./mapa/lib")

local floor, min, max = math.floor, math.min, math.max

-- ---------------------------------------------------------------------------------------------------------------
-- Argumentos
-- ---------------------------------------------------------------------------------------------------------------
local final = false
local so: { [string]: boolean }? = nil
local saida = "build/mapa_teste.rbxm"
do
	local a = process.args
	local i = 1
	while i <= #a do
		if a[i] == "--final" then
			final = true
			saida = "mapa/Mapa.rbxm"
		elseif a[i] == "--so" then
			i += 1
			so = {}
			for nome in string.gmatch(a[i] or "", "[^,]+") do
				so[nome] = true
			end
		elseif a[i] == "--saida" then
			i += 1
			saida = a[i]
		end
		i += 1
	end
	assert(not (final and so), "--final e --so não combinam: o mapa final sempre sai completo")
end

-- Ordem importa: cada módulo só depende dos anteriores (docs/mapa-v2.md §Ordem).
local MODULOS = {
	"relevo", -- ctx.altura, chão (lajes inclinadas), leito e margens dos rios, marcadores de água
	"estradas", -- asfalto das avenidas e estradas (cortado onde há ponte/viaduto), faixas, acostamento
	"pontes", -- pontes sobre rios, passarelas, viadutos
	"cidade", -- laje da cidade, ruas, calçadas, lotes, construções, parques
	"areas", -- pads planos + vilas, fábrica, fazenda, posto da guarda e POIs
	"floresta", -- pinheiros e vegetação (depois de tudo que ocupa chão)
	"decoracao", -- postes, placas, carros, etc. ao longo das ruas e estradas
}

local ctx = lib.novoCtx(Mundo, planoMod.criar(Mundo))
ctx.spawnsPlanejados = {} -- { x, z, vila }: o módulo `areas` preenche

local function quero(nome: string): boolean
	return so == nil or so[nome] == true
end

local avisos = {}
local tempos = {}
for _, nome in MODULOS do
	if not quero(nome) then
		continue
	end
	if not fs.isFile("ferramentas/mapa/" .. nome .. ".luau") then
		table.insert(avisos, "módulo ausente: " .. nome)
		continue
	end
	local t0 = datetime.now().unixTimestampMillis
	local mod = require("./mapa/" .. nome)
	mod.gerar(ctx)
	tempos[nome] = (datetime.now().unixTimestampMillis - t0) / 1000
end

local P = ctx.plano
local rngPontos = ctx.rng("pontos")
local entre = rngPontos.entre
local mt = Mundo.tamanho / 2

-- ---------------------------------------------------------------------------------------------------------------
-- Bordas (muros invisíveis) e Zonas (invisíveis, sem consulta para não parar raycast)
-- ---------------------------------------------------------------------------------------------------------------
do
	local esp = 4
	local alt = Mundo.muroBorda
	local cy = alt / 2 - 5
	local opc = { transparencia = 1, consulta = false }
	local meio = mt + esp / 2
	local comp = Mundo.tamanho / 2 + esp
	local cf0 = roblox.CFrame.new()
	for _, s in { -1, 1 } do
		for _, metade in { -1, 1 } do
			local sufixo = (if s < 0 then "n" else "p") .. (if metade < 0 then "1" else "2")
			ctx.bloco(
				ctx.pastas.Bordas,
				cf0,
				"Borda_Z" .. sufixo,
				metade * comp / 2,
				cy,
				s * meio,
				comp,
				alt,
				esp,
				{ 255, 255, 255 },
				"SmoothPlastic",
				opc
			)
			ctx.bloco(
				ctx.pastas.Bordas,
				cf0,
				"Borda_X" .. sufixo,
				s * meio,
				cy,
				metade * (Mundo.tamanho / 2) / 2,
				esp,
				alt,
				Mundo.tamanho / 2,
				{ 255, 255, 255 },
				"SmoothPlastic",
				opc
			)
		end
	end
end

local function zona(nome: string, chave: string, cx: number, cz: number, lx: number, lz: number)
	local p = ctx.bloco(
		ctx.pastas.Zonas,
		roblox.CFrame.new(),
		"Zona_" .. nome,
		cx,
		100,
		cz,
		lx,
		300,
		lz,
		{ 255, 255, 255 },
		"SmoothPlastic",
		{
			transparencia = 1,
			colide = false,
			consulta = false,
		}
	)
	p:SetAttribute("Zona", chave)
	p:SetAttribute("Nome", nome)
end
zona("Cidade", "cidade", 0, 0, P.cidade.x1 * 2, P.cidade.z1 * 2)
for i, v in Mundo.vilas do
	zona(v.nome, "vila", v.centro[1], v.centro[2], v.lado, v.lado)
	assert(P.vilas[i])
end
zona(
	"Fabrica",
	"fabrica",
	Mundo.fabrica.centro[1],
	Mundo.fabrica.centro[2],
	Mundo.fabrica.tamanho[1],
	Mundo.fabrica.tamanho[2]
)
zona(
	"Planicie",
	"planicie",
	Mundo.planicie.centro[1],
	Mundo.planicie.centro[2],
	Mundo.planicie.lado,
	Mundo.planicie.lado
)
zona("PostoGuarda", "guarda", Mundo.guardaFlorestal.centro[1], Mundo.guardaFlorestal.centro[2], 100, 100)
for k, q in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
	zona("Floresta_" .. k, "floresta", q[1] * mt / 2, q[2] * mt / 2, mt, mt)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Monstros: um por célula de densidade (lado = Config/Monstros.densidade[zona]), em chão livre e seco
-- ---------------------------------------------------------------------------------------------------------------
do
	for _, s in ctx.spawnsPlanejados do
		ctx.ponto("Spawn", s.x, s.z, { Zona = s.vila })
	end

	local function monstrosEm(chave: string, r, aceitar)
		local lado = Monstros.densidade[chave]
		assert(lado, "Config/Monstros.densidade sem a chave " .. chave)
		local cx = r.x0
		while cx < r.x1 do
			local cz = r.z0
			while cz < r.z1 do
				for _ = 1, 40 do
					local x = entre(cx, min(cx + lado, r.x1))
					local z = entre(cz, min(cz + lado, r.z1))
					if aceitar(x, z) and not ctx.ocupado(x, z, 3) and not P.emRio(x, z, 4) then
						ctx.ponto("Monstro", x, z, { Zona = chave })
						ctx.contagemMonstro[chave] = (ctx.contagemMonstro[chave] or 0) + 1
						break
					end
				end
				cz += lado
			end
			cx += lado
		end
	end
	local sempre = function()
		return true
	end
	monstrosEm("cidade", P.cidade, sempre)
	for _, r in P.vilas do
		monstrosEm("vila", r, sempre)
	end
	monstrosEm("fabrica", P.fabrica, sempre)
	monstrosEm("outros", P.planicie, sempre)
	monstrosEm("outros", P.guarda, sempre)
	monstrosEm("floresta", { x0 = -mt + 20, x1 = mt - 20, z0 = -mt + 20, z1 = mt - 20 }, function(x, z)
		return P.zonaEm(x, z) == "floresta" and not P.emAreaConstruida(x, z, 4)
	end)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Materializa os pontos (Parts 1×1×1 invisíveis) na pasta Pontos
-- ---------------------------------------------------------------------------------------------------------------
for _, pt in ctx.pontosPendentes do
	local y = pt.y or (ctx.topoEm(pt.x, pt.z) + 0.5)
	local p = ctx.bloco(
		ctx.pastas.Pontos,
		roblox.CFrame.new(),
		pt.nome,
		pt.x,
		y,
		pt.z,
		1,
		1,
		1,
		{ 255, 255, 255 },
		"SmoothPlastic",
		{
			transparencia = 1,
			colide = false,
			consulta = false,
		}
	)
	for k, v in pt.atributos do
		p:SetAttribute(k, v)
	end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Contagem, orçamento e gravação
-- ---------------------------------------------------------------------------------------------------------------
local total, linhas = lib.contar(ctx.mapa)
fs.writeFile(saida, roblox.serializeModel({ ctx.mapa }))
print(saida .. " gerado (semente " .. tostring(Mundo.semente) .. ")")
print(table.concat(linhas, "\n"))
print(string.format("  %-12s %7d peças (limite %d)", "TOTAL", total, Mundo.limitePecas))
print(
	string.format(
		"  construções %d | pontos: Spawn %d, Loot %d, Monstro %d",
		#ctx.construcoes,
		ctx.contagemPontos.Spawn,
		ctx.contagemPontos.Loot,
		ctx.contagemPontos.Monstro
	)
)
do
	local partes = {}
	for chave, n in ctx.contagemMonstro do
		table.insert(partes, chave .. "=" .. n)
	end
	table.sort(partes)
	print("  Monstro por zona: " .. table.concat(partes, ", "))
	local t = {}
	for nome, s in tempos do
		table.insert(t, string.format("%s %.1fs", nome, s))
	end
	table.sort(t)
	print("  tempos: " .. table.concat(t, ", "))
end
for _, a in avisos do
	print("AVISO " .. a)
end
if ctx.avisos then
	for _, a in ctx.avisos do
		print("AVISO " .. a)
	end
end
if total > Mundo.limitePecas then
	error(string.format("passou do orçamento: %d > %d peças", total, Mundo.limitePecas))
end
