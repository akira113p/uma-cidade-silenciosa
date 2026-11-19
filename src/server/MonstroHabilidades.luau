-- MonstroHabilidades: despachante das habilidades por espécie (docs/monstros/logica.md §2.3). Um módulo por espécie em
-- server/Habilidades/<Especie>.luau, com `passo(d, agora, c) -> boolean` (true = tomou o controle do movimento neste tick),
-- e opcionais `iniciar(d)`, `aoOuvir(d, ev)`, `aoGolpear(d, jogador, agora) -> boolean`, `aoMorrer(d)`, `configurar(ctx)`.
-- Erro numa habilidade nunca derruba a IA (pcall + warn limitado). Sem módulo para a espécie = nada acontece.
-- Também guarda as ferramentas comuns (`H.util`): linha de visão, partes do jogador, construção sob um ponto, zonas, rede.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared.Rede)
local Raizes = require(Shared.Raizes)
local Regras = require(Shared.Regras.Habilidades)

local H: any = {}

local ctx: any = {}
local modulos: { [string]: any } = {}
local ausentes: { [string]: boolean } = {}
local avisos = 0

local function avisar(texto: string)
	if avisos < 8 then
		avisos += 1
		warn("[MonstroHabilidades] " .. texto)
	end
end

local function modulo(id: string): any
	local m = modulos[id]
	if m then
		return m
	end
	if ausentes[id] then
		return nil
	end
	local pasta = script.Parent:FindFirstChild("Habilidades")
	local arquivo = pasta and pasta:FindFirstChild(id)
	local ok, r = false, nil
	if arquivo then
		ok, r = pcall(require, arquivo)
	end
	if ok and r then
		modulos[id] = r
		if r.configurar then
			pcall(r.configurar, ctx, H.util)
		end
		return r
	end
	ausentes[id] = true
	return nil
end

local function chamar(m: any, nome: string, ...: any): any
	local fn = m and m[nome]
	if not fn then
		return nil
	end
	local ok, r = pcall(fn, ...)
	if not ok then
		avisar(nome .. ": " .. tostring(r))
		return nil
	end
	return r
end

-- Ferramentas comuns --------------------------------------------------------------------------------------------------

local util: any = {}
H.util = util

-- Raycast de visão: construções, props e carros (portas fechadas são peças de Construcoes). Vidro não bloqueia.
local paramsVisao = RaycastParams.new()
paramsVisao.FilterType = Enum.RaycastFilterType.Include
paramsVisao.IgnoreWater = true
local proximaAtualizacao = 0

-- Paredes + props, sem carros (batida do Wrapper, corte do MonstroPS1).
local paramsSolido = RaycastParams.new()
paramsSolido.FilterType = Enum.RaycastFilterType.Include
paramsSolido.IgnoreWater = true

local function atualizarParams()
	local agora = os.clock()
	if agora < proximaAtualizacao then
		return
	end
	proximaAtualizacao = agora + 2
	local solidos: { Instance } = {}
	for _, nome in { "Construcoes", "Props" } do
		for _, r in Raizes.obter(nome) do
			table.insert(solidos, r)
		end
	end
	paramsSolido.FilterDescendantsInstances = solidos
	local todos = table.clone(solidos)
	local veic = workspace:FindFirstChild("Veiculos")
	if veic then
		table.insert(todos, veic)
	end
	paramsVisao.FilterDescendantsInstances = todos
end

function util.paramsSolido(): RaycastParams
	atualizarParams()
	return paramsSolido
end

function util.paramsVisao(): RaycastParams
	atualizarParams()
	return paramsVisao
end

-- true se o segmento de -> para não bate em nada sólido (vidro é atravessado).
function util.linhaLivre(de: Vector3, para: Vector3): boolean
	atualizarParams()
	local pos = de
	for _ = 1, 4 do
		local dir = para - pos
		if dir.Magnitude < 0.5 then
			return true
		end
		local r = workspace:Raycast(pos, dir, paramsVisao)
		if not r then
			return true
		end
		if r.Instance:IsA("BasePart") and r.Instance.Material == Enum.Material.Glass then
			pos = r.Position + dir.Unit * 0.1
		else
			return false
		end
	end
	return false
end

function util.parteDoJogador(jogador: Player, nome: string): BasePart?
	local char = jogador.Character
	local p = char and char:FindFirstChild(nome)
	return if p and p:IsA("BasePart") then p else nil
end

function util.agachado(jogador: Player): boolean
	return jogador:GetAttribute("Agachado") == true
end

function util.deitado(jogador: Player): boolean
	return jogador:GetAttribute("Deitado") == true
end

function util.emCarro(jogador: Player): boolean
	local char = jogador.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.SeatPart ~= nil
end

function util.velHoriz(jogador: Player): number
	local hrp = util.parteDoJogador(jogador, "HumanoidRootPart")
	if not hrp then
		return 0
	end
	local v = hrp.AssemblyLinearVelocity
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

function util.derrubado(jogador: Player): boolean
	local t = jogador:GetAttribute("Derrubado")
	return type(t) == "number" and t > os.clock()
end

-- Dispara um evento de Rede para um cliente; evento ainda não declarado ou erro de rede viram silêncio.
function util.enviar(nome: string, jogador: Player, ...: any)
	local args = table.pack(...)
	pcall(function()
		Rede.evento(nome):FireClient(jogador, table.unpack(args, 1, args.n))
	end)
end

-- Cada jogador vivo a <= raio de `pos` (3D): { { jogador, pos } }. Usa a lista do tick quando passada.
function util.jogadoresPerto(
	lista: { { jogador: Player, pos: Vector3 } },
	pos: Vector3,
	raio: number
): { { jogador: Player, pos: Vector3 } }
	local r = {}
	for _, j in lista do
		if (j.pos - pos).Magnitude <= raio then
			table.insert(r, j)
		end
	end
	return r
end

-- Sobe de uma peça até o Model filho direto de uma raiz de Construcoes (o "edifício").
function util.construcaoDe(inst: Instance): Model?
	local raizes = Raizes.obter("Construcoes")
	local atual: Instance? = inst
	while atual and atual.Parent do
		if table.find(raizes, atual.Parent) then
			return if atual:IsA("Model") then atual else nil
		end
		atual = atual.Parent
	end
	return nil
end

local paramsConstrucao = OverlapParams.new()
paramsConstrucao.FilterType = Enum.RaycastFilterType.Include

-- Edifício com alguma peça a <= raio de `pos` (o mais perto vence). nil se nenhum.
function util.construcaoEm(pos: Vector3, raio: number): Model?
	paramsConstrucao.FilterDescendantsInstances = Raizes.obter("Construcoes")
	local partes = workspace:GetPartBoundsInRadius(pos, raio, paramsConstrucao)
	local melhor, menor = nil, math.huge
	for _, p in partes do
		local m = util.construcaoDe(p)
		if m then
			local d = (p.Position - pos).Magnitude
			if d < menor then
				melhor, menor = m, d
			end
		end
	end
	return melhor
end

-- `pos` está dentro da caixa (xz) e abaixo do topo do edifício.
function util.dentroDe(modelo: Model, pos: Vector3): boolean
	local cf, tam = modelo:GetBoundingBox()
	local l = cf:PointToObjectSpace(pos)
	return math.abs(l.X) <= tam.X / 2 and math.abs(l.Z) <= tam.Z / 2 and math.abs(l.Y) <= tam.Y / 2
end

-- Zonas do mapa (Mapa.Zonas, atributo Zona): caixas { chave, cx, cz, sx, sz }. Lidas uma vez por pasta.
local zonasCache: { any } = {}
local zonasDe: Instance? = nil
function util.zonas(): { any }
	local mapa = workspace:FindFirstChild("Mapa")
	local pasta = mapa and mapa:FindFirstChild("Zonas")
	if pasta ~= zonasDe then
		zonasDe = pasta
		zonasCache = {}
		if pasta then
			for _, p in pasta:GetChildren() do
				local chave = p:GetAttribute("Zona")
				if p:IsA("BasePart") and type(chave) == "string" then
					table.insert(
						zonasCache,
						{ chave = chave, cx = p.Position.X, cz = p.Position.Z, sx = p.Size.X, sz = p.Size.Z }
					)
				end
			end
		end
	end
	return zonasCache
end

function util.dentroDeZona(pos: Vector3, nome: string): boolean
	return Regras.dentroDeZona({ x = pos.X, z = pos.Z }, util.zonas(), nome)
end

-- Dano em jogador pelo serviço Vida (parte nil = sorteio).
function util.danoJogador(jogador: Player, parte: string?, valor: number, direcao: Vector3?)
	local vida = ctx.servico and ctx.servico("Vida")
	if vida then
		vida.dano(jogador, parte, valor, { tipo = "monstro", direcao = direcao })
	end
end

-- Nome de parte do corpo do jogo (Config/Monstros.sorteioParte) para uma peça do personagem Roblox.
function util.parteDoCorpo(nome: string): string?
	if string.find(nome, "Head") then
		return "Cabeca"
	elseif string.find(nome, "Left") and string.find(nome, "Arm") or string.find(nome, "LeftHand") then
		return "BracoE"
	elseif string.find(nome, "Right") and string.find(nome, "Arm") or string.find(nome, "RightHand") then
		return "BracoD"
	elseif string.find(nome, "Left") and (string.find(nome, "Leg") or string.find(nome, "Foot")) then
		return "PernaE"
	elseif string.find(nome, "Right") and (string.find(nome, "Leg") or string.find(nome, "Foot")) then
		return "PernaD"
	end
	return "Torso"
end

function util.personagemDe(inst: Instance): Player?
	local m = inst:FindFirstAncestorOfClass("Model")
	return if m then Players:GetPlayerFromCharacter(m) else nil
end

-- API para o Monstros ---------------------------------------------------------------------------------------------------

function H.configurar(c: any)
	ctx = c
end

function H.iniciar(d: any)
	d.hab = {}
	chamar(modulo(d.especie.id), "iniciar", d)
end

-- true = a habilidade tomou o controle do movimento. `c` = { jogadores, maisPerto, distPerto }.
function H.passo(d: any, agora: number, c: any): boolean
	d.semGolpeNormal = false
	local m = modulo(d.especie.id)
	if not m then
		return false
	end
	return chamar(m, "passo", d, agora, c) == true
end

-- ev = { excesso, pos, agora, antes, depois, tipo?, db?, jogador? } (tipo/db/jogador só quando vem de ruído real).
function H.aoOuvir(d: any, ev: any)
	chamar(modulo(d.especie.id), "aoOuvir", d, ev)
end

-- true = a habilidade fez o golpe (o Monstros não faz o golpe normal).
function H.aoGolpear(d: any, jogador: Player, agora: number): boolean
	return chamar(modulo(d.especie.id), "aoGolpear", d, jogador, agora) == true
end

function H.aoMorrer(d: any)
	chamar(modulo(d.especie.id), "aoMorrer", d)
end

return H
