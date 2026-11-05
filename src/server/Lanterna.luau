-- Lanterna (servidor): equipar pela barra e ligar/apagar, tudo validado aqui. Dono: S7. Números: Config/Lanterna.
-- Atributos que este módulo escreve (o resto do jogo só lê):
--   Player.LanternaSlot (number?)       slot do inventário com a lanterna equipada; nil = guardada
--   Character.LanternaLigada (boolean)  luz acesa; o cliente do dono e dos outros jogadores desenham a luz a partir dele
-- A lanterna é silenciosa: não chama Ruido nem atrai monstros. É independente da arma (Armas.ArmaEquipada).
-- O corpo da lanterna na mão esquerda é do ItemNaMao (fonte "lanterna"); a luz continua sendo desenhada no cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Lanterna"))
local CfgItens = require(Shared.Config:WaitForChild("Itens"))

local Limite = require(script.Parent.Limite)
local Inventario = require(script.Parent.Inventario)
local Vida = require(script.Parent.Vida)

local Lanterna = {}

local function vivo(jogador: Player): Model?
	if jogador:GetAttribute("Morto") == true or not Vida.estaVivo(jogador) then
		return nil
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not (personagem and humanoide and humanoide.Health > 0) then
		return nil
	end
	return personagem
end

local function ehLanterna(jogador: Player, slot: number): boolean
	local entrada = Inventario.slot(jogador, slot)
	local item = entrada and CfgItens.itens[entrada.id]
	return item ~= nil and item.tipo == "lanterna"
end

local function apagar(jogador: Player)
	local personagem = jogador.Character
	if personagem and personagem:GetAttribute("LanternaLigada") ~= false then
		personagem:SetAttribute("LanternaLigada", false)
	end
end

-- ItemNaMao carregado na hora: se o módulo falhar, a lanterna funciona sem o modelo na mão.
local function naMao(jogador: Player, id: string?)
	local ok, N = pcall(require, script.Parent.ItemNaMao)
	if ok then
		N.definir(jogador, "lanterna", id)
	else
		warn("[Lanterna] ItemNaMao indisponível: " .. tostring(N))
	end
end

local function desequipar(jogador: Player)
	jogador:SetAttribute("LanternaSlot", nil)
	apagar(jogador)
	naMao(jogador, nil)
end

-- Liga ou apaga. Só acende com a lanterna equipada e o jogador vivo.
function Lanterna.definir(jogador: Player, ligada: boolean): boolean
	if not ligada then
		apagar(jogador)
		return true
	end
	local personagem = vivo(jogador)
	local slot = jogador:GetAttribute("LanternaSlot")
	if not personagem or type(slot) ~= "number" or not ehLanterna(jogador, slot) then
		return false
	end
	personagem:SetAttribute("LanternaLigada", true)
	return true
end

-- Chamado por Armas.equipar quando o slot escolhido tem uma lanterna: equipa; se já estava equipada, guarda.
function Lanterna.alternar(jogador: Player, slot: number): (boolean, string?)
	if not vivo(jogador) then
		return false, "morto"
	end
	if not ehLanterna(jogador, slot) then
		return false, "slot sem lanterna"
	end
	if jogador:GetAttribute("LanternaSlot") == slot then
		desequipar(jogador)
		return true, nil
	end
	jogador:SetAttribute("LanternaSlot", slot)
	local entrada = Inventario.slot(jogador, slot)
	naMao(jogador, if entrada then entrada.id else nil)
	if Cfg.ligarAoEquipar then
		Lanterna.definir(jogador, true)
	else
		apagar(jogador)
	end
	return true, nil
end

local function conferirSlot(jogador: Player)
	local slot = jogador:GetAttribute("LanternaSlot")
	if type(slot) == "number" and not ehLanterna(jogador, slot) then
		desequipar(jogador) -- largou, perdeu ou trocou o item do slot
	end
end

local function aoEntrar(jogador: Player)
	jogador.CharacterAdded:Connect(function()
		desequipar(jogador) -- personagem novo começa de mãos vazias e luz apagada
	end)
end

function Lanterna.iniciar()
	for _, jogador in Players:GetPlayers() do
		aoEntrar(jogador)
	end
	Players.PlayerAdded:Connect(aoEntrar)

	Inventario.aoMudar(conferirSlot)
	Vida.aoMorrer(desequipar)

	Rede.evento("Lanterna").OnServerEvent:Connect(function(jogador: Player, ligada: any)
		if not Limite.ok(jogador, "Lanterna", Cfg.intervaloPedido) then
			return
		end
		if type(ligada) ~= "boolean" then
			return
		end
		Lanterna.definir(jogador, ligada)
	end)

	-- Comando de teste do Studio: dá a lanterna (se faltar), equipa e acende.
	require(script.Parent.Teste).registrar("lanterna", function(jogador: Player)
		local slotLanterna: number?
		for i = 1, CfgItens.slots do
			local entrada = Inventario.slot(jogador, i)
			if entrada and entrada.id == "lanterna" then
				slotLanterna = i
				break
			end
		end
		if not slotLanterna then
			if Inventario.dar(jogador, "lanterna", 1) > 0 then
				return "inventário cheio"
			end
			for i = 1, CfgItens.slots do
				local entrada = Inventario.slot(jogador, i)
				if entrada and entrada.id == "lanterna" then
					slotLanterna = i
					break
				end
			end
		end
		if not slotLanterna then
			return "falhou: sem slot"
		end
		if jogador:GetAttribute("LanternaSlot") ~= slotLanterna then
			local ok, motivo = Lanterna.alternar(jogador, slotLanterna)
			if not ok then
				return "falhou: " .. tostring(motivo)
			end
		end
		Lanterna.definir(jogador, true)
		return "lanterna equipada e acesa (slot " .. tostring(slotLanterna) .. ")"
	end)
end

return Lanterna
