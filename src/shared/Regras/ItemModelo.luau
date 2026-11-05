--!strict
-- Regras puras dos modelos de itens (docs/itens-no-mundo.md §2-3A): validar os dados de Config/ItensModelos, medir a caixa dos
-- blocos depois de girados e achar a altura de repouso no chão. Sem Instance/Vector3/CFrame: roda em Lune.
-- Vetores são { x, y, z } posicionais (como nos dados). Ângulos em graus, ordem de CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz.

local ItemModelo = {}

export type Vet = { number }
export type Parte = {
	nome: string,
	forma: string,
	tam: Vet,
	pos: Vet,
	rot: Vet,
	cor: Vet,
	material: string,
	transp: number?,
}
export type Pose = { pos: Vet, rot: Vet }
export type Modelo = {
	partes: { Parte },
	mao: Pose,
	lado: string?,
	chao: { rot: Vet },
	escalaChao: number?,
}
export type Caixa = { min: Vet, max: Vet }
export type Repouso = { rot: Vet, altura: number }

ItemModelo.FORMAS = { Block = true, Cylinder = true, Ball = true, Wedge = true } :: { [string]: boolean }
ItemModelo.MATERIAIS = {
	Plastic = true,
	SmoothPlastic = true,
	Metal = true,
	Fabric = true,
	Wood = true,
	Glass = true,
	Neon = true,
	Cardboard = true,
} :: { [string]: boolean }
ItemModelo.MAX_PARTES = 6
ItemModelo.LADO_MIN = 0.08 -- studs: nenhuma peça menor que isto em qualquer eixo

local function finito(n: any): boolean
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function vetor3(v: any): boolean
	return type(v) == "table" and #v == 3 and finito(v[1]) and finito(v[2]) and finito(v[3])
end

-- (ok, motivo). `modelo` vem de fora (dados), por isso `any`.
function ItemModelo.validar(modelo: any): (boolean, string?)
	if type(modelo) ~= "table" then
		return false, "modelo não é tabela"
	end
	local partes = modelo.partes
	if type(partes) ~= "table" or #partes < 1 then
		return false, "sem partes"
	end
	if #partes > ItemModelo.MAX_PARTES then
		return false, string.format("%d partes (máximo %d)", #partes, ItemModelo.MAX_PARTES)
	end
	local nomes: { [string]: boolean } = {}
	for i, p in partes do
		local rotulo = string.format("parte %d", i)
		if type(p) ~= "table" then
			return false, rotulo .. ": não é tabela"
		end
		if type(p.nome) ~= "string" or p.nome == "" then
			return false, rotulo .. ": sem nome"
		end
		rotulo = string.format("parte %d (%s)", i, p.nome)
		if nomes[p.nome] then
			return false, rotulo .. ": nome repetido"
		end
		nomes[p.nome] = true
		if not ItemModelo.FORMAS[p.forma] then
			return false, rotulo .. ": forma inválida " .. tostring(p.forma)
		end
		if not ItemModelo.MATERIAIS[p.material] then
			return false, rotulo .. ": material inválido " .. tostring(p.material)
		end
		if not vetor3(p.tam) then
			return false, rotulo .. ": tam inválido"
		end
		for _, t in p.tam do
			if t < ItemModelo.LADO_MIN then
				return false, rotulo .. ": lado menor que " .. ItemModelo.LADO_MIN
			end
		end
		if not vetor3(p.pos) then
			return false, rotulo .. ": pos inválido"
		end
		if not vetor3(p.rot) then
			return false, rotulo .. ": rot inválido"
		end
		if not vetor3(p.cor) then
			return false, rotulo .. ": cor inválida"
		end
		for _, c in p.cor do
			if c < 0 or c > 255 then
				return false, rotulo .. ": cor fora de 0..255"
			end
		end
		if p.transp ~= nil and not (finito(p.transp) and p.transp >= 0 and p.transp <= 1) then
			return false, rotulo .. ": transp fora de 0..1"
		end
	end
	if type(modelo.mao) ~= "table" or not vetor3(modelo.mao.pos) or not vetor3(modelo.mao.rot) then
		return false, "mao inválida"
	end
	if modelo.lado ~= nil and modelo.lado ~= "direita" and modelo.lado ~= "esquerda" then
		return false, "lado inválido " .. tostring(modelo.lado)
	end
	if type(modelo.chao) ~= "table" or not vetor3(modelo.chao.rot) then
		return false, "chao.rot inválido"
	end
	if modelo.escalaChao ~= nil and not (finito(modelo.escalaChao) and modelo.escalaChao > 0) then
		return false, "escalaChao inválida"
	end
	return true, nil
end

-- Matriz 3x3 (linhas) de CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz, ângulos em graus.
local function matriz(rot: Vet): { Vet }
	local a, b, c = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	return {
		{ cb * cc, -cb * sc, sb },
		{ ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
		{ sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
	}
end

local function multiplicar(a: { Vet }, b: { Vet }): { Vet }
	local r: { Vet } = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end

local function aplicar(m: { Vet }, v: Vet): Vet
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

-- Meia-extensão no eixo `i` do mundo de uma peça com meio-tamanho `h` girada por `m`. Exata para bloco, bola e cilindro
-- (eixo do cilindro = X da peça, como no Roblox); a cunha usa a caixa dela (conservador).
local function meiaExtensao(m: { Vet }, h: Vet, forma: string, i: number): number
	local l = m[i]
	if forma == "Ball" then
		return math.sqrt((l[1] * h[1]) ^ 2 + (l[2] * h[2]) ^ 2 + (l[3] * h[3]) ^ 2)
	elseif forma == "Cylinder" then
		return math.abs(l[1]) * h[1] + math.sqrt((l[2] * h[2]) ^ 2 + (l[3] * h[3]) ^ 2)
	end
	return math.abs(l[1]) * h[1] + math.abs(l[2]) * h[2] + math.abs(l[3]) * h[3]
end

-- Caixa alinhada aos eixos de todas as peças depois de girar cada peça pela rot dela e o conjunto por `rot` (padrão 0).
function ItemModelo.caixa(modelo: Modelo, rot: Vet?): Caixa
	local global = matriz(rot or { 0, 0, 0 })
	local min = { math.huge, math.huge, math.huge }
	local max = { -math.huge, -math.huge, -math.huge }
	for _, p in modelo.partes do
		local m = multiplicar(global, matriz(p.rot))
		local c = aplicar(global, p.pos)
		local h = { p.tam[1] / 2, p.tam[2] / 2, p.tam[3] / 2 }
		for i = 1, 3 do
			local e = meiaExtensao(m, h, p.forma, i)
			min[i] = math.min(min[i], c[i] - e)
			max[i] = math.max(max[i], c[i] + e)
		end
	end
	return { min = min, max = max }
end

-- Rotação de repouso (chao.rot) e distância da origem até o ponto mais baixo (já com escalaChao).
function ItemModelo.repouso(modelo: Modelo): Repouso
	local rot = modelo.chao.rot
	local caixa = ItemModelo.caixa(modelo, rot)
	return { rot = rot, altura = -caixa.min[2] * (modelo.escalaChao or 1) }
end

return ItemModelo
