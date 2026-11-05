-- Admin: executa os pedidos do menu de admin (tecla O) (hora, clima, itens, voo, imortal, cura). Dono: integração.
-- Só o Studio e os donos de Config/Admin.luau passam; o cliente nunca decide quem é admin (atributo "Admin" é do servidor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgAdmin = require(Shared:WaitForChild("Config"):WaitForChild("Admin"))
local CfgItens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local CfgTempo = require(Shared:WaitForChild("Config"):WaitForChild("Tempo"))
local Limite = require(script.Parent.Limite)

local Admin = {}

local PROTECAO_POUSO = 4 -- s de imortalidade depois de parar de voar (a queda não machuca)
local protegidoAte: { [Player]: number } = {}

-- Os outros serviços são carregados na hora: o Admin não derruba nada se algum faltar.
local function servico(nome: string): any
	local arquivo = script.Parent:FindFirstChild(nome)
	if not arquivo then
		return nil
	end
	local ok, modulo = pcall(require, arquivo)
	return if ok then modulo else nil
end

function Admin.autorizado(jogador: Player): boolean
	if CfgAdmin.liberarParaTodos then
		return true
	end
	if RunService:IsStudio() and CfgAdmin.liberarNoStudio then
		return true
	end
	return table.find(CfgAdmin.donos, jogador.UserId) ~= nil
end

-- "Imortal" (lido por server/Vida) = imortal do menu, ou voando, ou pousando.
local function recalcularImortal(jogador: Player)
	local agora = os.clock()
	local protegido = (protegidoAte[jogador] or 0) > agora
	local imortal = jogador:GetAttribute("AdminImortal") == true
		or jogador:GetAttribute("AdminVoar") == true
		or protegido
	jogador:SetAttribute("Imortal", imortal)
end

local function numero(valor: unknown, minimo: number, maximo: number): number?
	if type(valor) ~= "number" or valor ~= valor or valor == math.huge or valor == -math.huge then
		return nil
	end
	return math.clamp(valor, minimo, maximo)
end

local acoes: { [string]: (jogador: Player, arg: any) -> () } = {}

acoes.dar = function(jogador, arg)
	if type(arg) ~= "table" or type(arg.id) ~= "string" or not CfgItens.itens[arg.id] then
		return
	end
	local qtd = numero(arg.qtd, 1, CfgAdmin.maxQuantidade)
	local Inventario = servico("Inventario")
	if qtd and Inventario then
		local sobra = Inventario.dar(jogador, arg.id, math.floor(qtd))
		if sobra > 0 then
			Rede.evento("Aviso"):FireClient(jogador, "Mochila cheia: " .. sobra .. " não couberam")
		end
	end
end

acoes.hora = function(_, arg)
	local hora = numero(arg, 0, 24)
	local Visual = servico("Visual")
	if hora and Visual then
		Visual.definirHora(hora)
	end
end

acoes.congelar = function(_, arg)
	local Visual = servico("Visual")
	if type(arg) == "boolean" and Visual then
		Visual.congelar(arg)
		workspace:SetAttribute("RelogioCongelado", arg)
	end
end

acoes.clima = function(_, arg)
	if type(arg) == "string" and CfgTempo.luz.climas[arg] then
		workspace:SetAttribute("Clima", arg)
	end
end

acoes.voar = function(jogador, arg)
	if type(arg) ~= "boolean" then
		return
	end
	if not arg and jogador:GetAttribute("AdminVoar") == true then
		protegidoAte[jogador] = os.clock() + PROTECAO_POUSO
		task.delay(PROTECAO_POUSO + 0.1, function()
			if jogador.Parent then
				recalcularImortal(jogador)
			end
		end)
	end
	jogador:SetAttribute("AdminVoar", arg)
	recalcularImortal(jogador)
end

acoes.imortal = function(jogador, arg)
	if type(arg) == "boolean" then
		jogador:SetAttribute("AdminImortal", arg)
		recalcularImortal(jogador)
	end
end

acoes.visual = function(jogador, _)
	local Aparencia = servico("Aparencia")
	if Aparencia and jogador.Character then
		-- limpa os blocos antigos para montar de novo (útil depois de mudar Config/Aparencia)
		for _, x in jogador.Character:GetDescendants() do
			if x.Name == "Bloco" and x:IsA("Part") then
				x.Parent.Transparency = 0
				x:Destroy()
			end
		end
		task.spawn(Aparencia.aplicar, jogador, jogador.Character)
	end
end

acoes.curar = function(jogador, _)
	local Vida = servico("Vida")
	local Sobrevivencia = servico("Sobrevivencia")
	if Vida then
		for _ = 1, 12 do
			if Vida.curar(jogador, 100) == nil then
				break
			end
		end
	end
	if Sobrevivencia then
		for _, barra in { "Fome", "Sede", "Calor", "Estamina" } do
			Sobrevivencia.alterar(jogador, barra, 100)
		end
	end
end

-- Carros e monstros: o servidor valida (tipo, espécie, quantidade); quem monta o estado é Regras/Veiculo.montar.
acoes.carro = function(jogador, arg)
	local Veiculos = servico("Veiculos")
	if type(arg) ~= "table" or not Veiculos then
		return
	end
	local pedido = arg.pedido
	if type(pedido) == "table" then
		pedido = table.clone(pedido)
		pedido.combustivel = numero(pedido.combustivel, 0, 1) -- fração do tanque; nil = cheio (Regras/Veiculo.montar)
	end
	local n, texto = Veiculos.invocar(jogador, arg.tipo, arg.todos == true, pedido)
	Rede.evento("Aviso"):FireClient(jogador, if n > 0 then "Carro: " .. texto else "Carro não nasceu: " .. texto)
end

acoes.limparCarros = function(jogador, _)
	local Veiculos = servico("Veiculos")
	if Veiculos then
		Veiculos.limparInvocados(jogador)
	end
end

acoes.monstro = function(jogador, arg)
	local Monstros = servico("Monstros")
	if type(arg) ~= "table" or not Monstros then
		return
	end
	local n, texto = Monstros.invocar(jogador, arg.id, arg.qtd)
	Rede.evento("Aviso")
		:FireClient(jogador, if n > 0 then n .. " monstro(s): " .. texto else "Monstro não nasceu: " .. texto)
end

acoes.limparMonstros = function(jogador, _)
	local Monstros = servico("Monstros")
	if Monstros then
		Monstros.limparInvocados(jogador)
	end
end

function Admin.iniciar()
	local function aoEntrar(jogador: Player)
		jogador:SetAttribute("Admin", Admin.autorizado(jogador))
		jogador:SetAttribute("AdminVoar", false)
		jogador:SetAttribute("AdminImortal", false)
		jogador:SetAttribute("Imortal", false)
	end
	Players.PlayerAdded:Connect(aoEntrar)
	for _, jogador in Players:GetPlayers() do
		aoEntrar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		protegidoAte[jogador] = nil
	end)

	Rede.evento("Admin").OnServerEvent:Connect(function(jogador, acao, arg)
		if not Admin.autorizado(jogador) or type(acao) ~= "string" or not Limite.ok(jogador, "Admin", 0.1) then
			return
		end
		local f = acoes[acao]
		if f then
			f(jogador, arg)
		end
	end)

	workspace:SetAttribute("RelogioCongelado", false)
end

return Admin
