-- ItemNaMao (servidor): dono do modelo de blocos que o personagem segura. Um modelo por (jogador, mão).
-- Contrato: docs/itens-no-mundo.md §3-D. Quem pede (Armas, Lanterna, Inventario) carrega este módulo sob demanda.
-- Fontes: "uso" (comer/beber/curar) > "arma", as duas na mão direita; "lanterna" na mão esquerda.
-- Quando "uso" termina (id nil), a arma volta. O modelo vem de Shared/ItemModelo (criar(id, "mao") + prenderNaMao).
-- Nome do modelo: "ArmaNaMao" para a arma (o viewmodel esconde esse nome do próprio dono), "ItemNaMao" para o resto.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemNaMao = {}

type Lado = "direita" | "esquerda"
type Mao = { id: string, modelo: Model }
type Estado = {
	fontes: { [string]: string? }, -- fonte -> id do item; ausente = fonte vazia
	direita: Mao?,
	esquerda: Mao?,
}

local FONTES: { [string]: boolean } = { arma = true, lanterna = true, uso = true }

local estados: { [Player]: Estado } = {}
local iniciado = false
local avisados: { [string]: boolean } = {}

local function avisarUmaVez(chave: string, texto: string)
	if not avisados[chave] then
		avisados[chave] = true
		warn("[ItemNaMao] " .. texto)
	end
end

-- Shared/ItemModelo (parte A) carregado na hora: se faltar ou falhar, nada aparece na mão e o resto do jogo segue.
local itemModelo: any = nil
local function modeloDeItens(): any
	if itemModelo == nil then
		local arquivo = Shared:FindFirstChild("ItemModelo")
		local ok, resultado = false, nil
		if arquivo then
			ok, resultado = pcall(require, arquivo)
		end
		if ok then
			itemModelo = resultado
		else
			avisarUmaVez("ItemModelo", "Shared/ItemModelo indisponível: " .. tostring(resultado))
			itemModelo = false
		end
	end
	return itemModelo or nil
end

local function estadoDe(jogador: Player): Estado
	local e = estados[jogador]
	if not e then
		e = { fontes = {}, direita = nil, esquerda = nil }
		estados[jogador] = e
	end
	return e
end

-- O que a mão deve segurar agora, e por qual fonte.
local function desejado(e: Estado, lado: Lado): (string?, string?)
	if lado == "esquerda" then
		return e.fontes.lanterna, "lanterna"
	end
	if e.fontes.uso then
		return e.fontes.uso, "uso"
	end
	return e.fontes.arma, "arma"
end

local function soltar(e: Estado, lado: Lado)
	local atual = e[lado]
	if atual then
		atual.modelo:Destroy()
		e[lado] = nil
	end
end

-- Faz a mão `lado` bater com o que as fontes pedem. Sem mão (R6, personagem incompleto) fica vazia, sem erro.
local function aplicar(jogador: Player, e: Estado, lado: Lado)
	local id, fonte = desejado(e, lado)
	local atual = e[lado]
	if atual and atual.id == id and atual.modelo.Parent ~= nil then
		return
	end
	soltar(e, lado)
	local personagem = jogador.Character
	if not (id and personagem and personagem.Parent) then
		return
	end
	local IM = modeloDeItens()
	if not IM then
		return
	end
	local ok, modelo = pcall(IM.criar, id, "mao")
	if not (ok and typeof(modelo) == "Instance" and modelo:IsA("Model")) then
		avisarUmaVez("criar_" .. id, "ItemModelo.criar(" .. id .. ") falhou: " .. tostring(modelo))
		return
	end
	modelo.Name = if fonte == "arma" then "ArmaNaMao" else "ItemNaMao"
	modelo.Parent = personagem
	local okPrender, preso = pcall(IM.prenderNaMao, modelo, personagem, id)
	if not (okPrender and preso) then
		if not okPrender then
			avisarUmaVez("prender_" .. id, "ItemModelo.prenderNaMao(" .. id .. ") falhou: " .. tostring(preso))
		end
		modelo:Destroy() -- sem mão (R6) ou erro: não deixa o modelo solto no personagem
		return
	end
	e[lado] = { id = id, modelo = modelo }
end

-- Tira tudo da mão e esquece as fontes (morte, respawn, saída).
function ItemNaMao.limpar(jogador: Player)
	local e = estados[jogador]
	if not e then
		return
	end
	table.clear(e.fontes)
	soltar(e, "direita")
	soltar(e, "esquerda")
end

-- id nil limpa a fonte. Prioridade na mão direita: "uso" > "arma".
function ItemNaMao.definir(jogador: Player, fonte: string, id: string?)
	if not iniciado then
		ItemNaMao.iniciar()
	end
	if not FONTES[fonte] then
		warn("[ItemNaMao] fonte desconhecida: " .. tostring(fonte))
		return
	end
	if id ~= nil and type(id) ~= "string" then
		return
	end
	if jogador.Parent == nil then
		return
	end
	local e = estadoDe(jogador)
	e.fontes[fonte] = id
	aplicar(jogador, e, "direita")
	aplicar(jogador, e, "esquerda")
end

local function aoEntrar(jogador: Player)
	jogador.CharacterRemoving:Connect(function()
		ItemNaMao.limpar(jogador)
	end)
end

-- Idempotente: definir() também chama, porque este módulo não está na lista do init.server.
function ItemNaMao.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	for _, jogador in Players:GetPlayers() do
		aoEntrar(jogador)
	end
	Players.PlayerAdded:Connect(aoEntrar)
	Players.PlayerRemoving:Connect(function(jogador)
		ItemNaMao.limpar(jogador)
		estados[jogador] = nil
	end)
	local okVida, Vida = pcall(require, script.Parent.Vida)
	if okVida and Vida then
		Vida.aoMorrer(function(jogador)
			ItemNaMao.limpar(jogador)
		end)
	else
		avisarUmaVez("Vida", "Vida indisponível: a mão só é limpa ao trocar de personagem")
	end
end

return ItemNaMao
