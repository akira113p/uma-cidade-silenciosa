-- Lanterna (servidor): equipar pela barra e ligar/apagar, tudo validado aqui. Dono: S7. Números: Config/Lanterna.
-- Atributos que este módulo escreve (o resto do jogo só lê):
--   Player.LanternaSlot (number?)       slot do inventário com a lanterna equipada; nil = guardada
--   Character.LanternaLigada (boolean)  luz acesa; o cliente do dono e dos outros jogadores desenham a luz a partir dele
--   Character.LanternaFalhaTipo/T/Semente  falha em curso ("piscar" | "apagar" | "ligar"; T = GetServerTimeNow do início; Semente por
--     ÚLTIMO: o cliente reage a ela). Todos derivam o mesmo padrão da semente (Regras/Lanterna.padraoFalha). "apagar" termina com
--     LanternaLigada = false (o jogador liga de novo com F).
-- A lanterna é silenciosa: não chama Ruido nem atrai monstros. É independente da arma (Armas.ArmaEquipada).
-- O corpo da lanterna fica no peito (server/LanternaPeito); a luz e a animação de ligar são desenhadas no cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Lanterna"))
local CfgItens = require(Shared.Config:WaitForChild("Itens"))

local Limite = require(script.Parent.Limite)
local Inventario = require(script.Parent.Inventario)
local Vida = require(script.Parent.Vida)
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Lanterna"))

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

local rng = Random.new()
local proximaFalha: { [Player]: number } = {} -- os.clock() da próxima falha, só enquanto acesa

local function agendar(jogador: Player, depois: number)
	proximaFalha[jogador] = os.clock() + depois + Regras.proximaFalha(Cfg.falha, rng:NextNumber())
end

-- Dispara uma falha no personagem (todos os clientes leem os atributos). "apagar" apaga ao fim do padrão.
local function falhar(jogador: Player, tipo: string)
	local personagem = jogador.Character
	if not personagem then
		return
	end
	local semente = rng:NextInteger(1, 2147483646)
	local padrao = Regras.padraoFalha(semente, tipo)
	personagem:SetAttribute("LanternaFalhaTipo", tipo)
	personagem:SetAttribute("LanternaFalhaT", workspace:GetServerTimeNow())
	personagem:SetAttribute("LanternaFalhaSemente", semente) -- por último
	if tipo == "apagar" then
		task.delay(padrao.duracao, function()
			if jogador.Character == personagem and personagem:GetAttribute("LanternaFalhaSemente") == semente then
				personagem:SetAttribute("LanternaLigada", false)
				Rede.evento("Aviso"):FireClient(jogador, Cfg.falha.aviso)
			end
		end)
	end
	agendar(jogador, padrao.duracao)
end

local function apagar(jogador: Player)
	proximaFalha[jogador] = nil
	local personagem = jogador.Character
	if personagem and personagem:GetAttribute("LanternaLigada") ~= false then
		personagem:SetAttribute("LanternaLigada", false)
	end
end

-- 2026-11-16: a lanterna equipada fica PRESA NO PEITO (server/LanternaPeito), não mais na mão esquerda: as duas mãos ficam livres
-- para qualquer arma. Carregado na hora: se o módulo falhar, a lanterna funciona sem o modelo.
local function peito(jogador: Player, vestir: boolean)
	local ok, P = pcall(require, script.Parent.LanternaPeito)
	if not ok then
		warn("[Lanterna] LanternaPeito indisponível: " .. tostring(P))
		return
	end
	local personagem = jogador.Character
	if not personagem then
		return
	end
	if vestir then
		task.spawn(P.vestir, personagem) -- a 1ª vez carrega o asset (yield)
	else
		P.tirar(personagem)
	end
end

local function atualizarModelo(jogador: Player)
	peito(jogador, type(jogador:GetAttribute("LanternaSlot")) == "number")
end

local function desequipar(jogador: Player)
	jogador:SetAttribute("LanternaSlot", nil)
	apagar(jogador)
	peito(jogador, false)
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
	if rng:NextNumber() < Cfg.falha.chanceFalharAoLigar then
		falhar(jogador, "ligar")
	else
		agendar(jogador, 0)
	end
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
	atualizarModelo(jogador)
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

	-- falhas ocasionais enquanto acesa (4 Hz basta: os intervalos são de dezenas de segundos)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local agora = os.clock()
			for jogador, quando in proximaFalha do
				if jogador.Parent == nil then
					proximaFalha[jogador] = nil
				elseif agora >= quando then
					local personagem = jogador.Character
					if personagem and personagem:GetAttribute("LanternaLigada") == true then
						falhar(jogador, Regras.tipoFalha(Cfg.falha, rng:NextNumber()))
					else
						proximaFalha[jogador] = nil
					end
				end
			end
		end
	end)

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
