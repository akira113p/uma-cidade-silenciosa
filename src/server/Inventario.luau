-- Inventario (servidor): inventário de cada jogador e uso de itens. Largar e morrer entregam os itens ao ItensChao
-- (itens soltos no mundo, docs/itens-no-mundo.md); não existe mais bolsa.
-- Dono: P6 (e único dono do atributo `Usando`). Contrato: docs/arquitetura.md §5.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Itens = require(Shared:WaitForChild("Config"):WaitForChild("Itens"))
local Regras = require(Shared:WaitForChild("Regras"):WaitForChild("Inventario"))
local Limite = require(script.Parent.Limite)

type Estado = {
	inv: Regras.Inv,
	precisaKit: boolean, -- true no primeiro spawn e depois de cada morte
	uso: number, -- ficha do uso em andamento; mudar a ficha cancela o laço
}

local Inventario = {}

local PASSO_USO = 0.1 -- s entre checagens enquanto o jogador consome um item

local estados: { [Player]: Estado } = {}
local ouvintes: { (Player) -> () } = {}

-- Outros serviços carregados sob demanda: se um deles falhou ao carregar, o inventário continua funcionando.
local servicos: { [string]: any } = {}
local function servico(nome: string): any
	local m = servicos[nome]
	if m == nil then
		local arquivo = script.Parent:FindFirstChild(nome)
		local ok, resultado = false, nil
		if arquivo then
			ok, resultado = pcall(require, arquivo)
		end
		if ok then
			m = resultado
		else
			warn("[Inventario] serviço indisponível: " .. nome .. " " .. tostring(resultado))
			m = false
		end
		servicos[nome] = m
	end
	return m or nil
end

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

-- Modelo do item na mão durante o uso (comer/beber/curar); id nil limpa. Falha em silêncio se o serviço não existe.
local function naMao(jogador: Player, id: string?)
	local ItemNaMao = servico("ItemNaMao")
	if ItemNaMao then
		pcall(ItemNaMao.definir, jogador, "uso", id)
	end
end

local function personagemVivo(jogador: Player): (Model?, BasePart?)
	local personagem = jogador.Character
	local hrp = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not personagem or not hrp or not hrp:IsA("BasePart") then
		return nil, nil
	end
	local Vida = servico("Vida")
	if Vida then
		if not Vida.estaVivo(jogador) then
			return nil, nil
		end
	else
		-- INTEGRACAO: sem Vida (P5), vale o Humanoid do Roblox.
		local humanoid = personagem:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return nil, nil
		end
	end
	return personagem, hrp
end

-- Posição do slot equipado: primeiro slot cujo item é a arma de `ArmaEquipada` (atributo do dono Armas).
local function equipadoDe(jogador: Player, inv: Regras.Inv): number?
	local arma = jogador:GetAttribute("ArmaEquipada")
	if type(arma) ~= "string" then
		return nil
	end
	-- duas armas iguais com pentes diferentes: vale o slot que o dono de ArmaEquipada informou
	local preferido = jogador:GetAttribute("ArmaSlot")
	if type(preferido) == "number" then
		local p = inv[preferido]
		local def = p and Itens.itens[p.id]
		if def and def.arma == arma then
			return preferido
		end
	end
	for i = 1, #inv do
		local p = inv[i]
		local def = p and Itens.itens[p.id]
		if def and def.arma == arma then
			return i
		end
	end
	return nil
end

local function enviar(jogador: Player)
	local e = estados[jogador]
	if e then
		Rede.evento("Inventario"):FireClient(jogador, Regras.ocupados(e.inv), equipadoDe(jogador, e.inv))
	end
end

local function mudou(jogador: Player)
	enviar(jogador)
	for _, f in ouvintes do
		task.spawn(f, jogador)
	end
end

local function cancelarUso(jogador: Player)
	local e = estados[jogador]
	if e then
		e.uso += 1
	end
	if jogador:GetAttribute("Usando") ~= false then
		jogador:SetAttribute("Usando", false)
	end
	naMao(jogador, nil)
end

-- Funções públicas ---------------------------------------------------------------------------------------------

-- `pente` (opcional): balas no pente de uma arma de fogo que entra (largada/chão/caixa); nil = arma nunca usada.
function Inventario.dar(jogador: Player, id: string, qtd: number, pente: number?): number
	local e = estados[jogador]
	if not e then
		return qtd
	end
	if Itens.itens[id] == nil then
		warn("[Inventario] dar: item desconhecido " .. tostring(id))
		return qtd
	end
	local novo, sobra = Regras.adicionar(e.inv, id, qtd, Itens.itens, Itens.empilhamentoPadrao, pente)
	if sobra ~= qtd then
		e.inv = novo
		mudou(jogador)
	end
	return sobra
end

function Inventario.remover(jogador: Player, id: string, qtd: number): boolean
	local e = estados[jogador]
	if not e then
		return false
	end
	local novo, ok = Regras.remover(e.inv, id, qtd)
	if ok then
		e.inv = novo
		mudou(jogador)
	end
	return ok
end

function Inventario.contar(jogador: Player, id: string): number
	local e = estados[jogador]
	return if e then Regras.contar(e.inv, id) else 0
end

-- Quanto de `id` ainda cabe no inventário (usado pelo Loot antes de tirar da caixa).
function Inventario.espaco(jogador: Player, id: string): number
	local e = estados[jogador]
	return if e then Regras.espaco(e.inv, id, Itens.itens, Itens.empilhamentoPadrao) else 0
end

function Inventario.slot(jogador: Player, slot: number): { id: string, qtd: number, pente: number? }?
	local e = estados[jogador]
	local p = e and e.inv[slot]
	if p then
		return { id = p.id, qtd = p.qtd, pente = p.pente }
	end
	return nil
end

-- Pente da arma no slot (nil: slot vazio ou arma ainda sem pente gravado).
function Inventario.pente(jogador: Player, slot: number): number?
	local e = estados[jogador]
	return if e then Regras.pente(e.inv, slot) else nil
end

-- Grava o pente da arma no slot (dono do estado: servidor de Armas). `silencioso` não reenvia o inventário ao cliente
-- nem avisa os ouvintes: usado a cada tiro (12 por segundo numa automática); o cliente lê o atributo Player.Pente.
function Inventario.definirPente(jogador: Player, slot: number, pente: number, silencioso: boolean?)
	local e = estados[jogador]
	if not e or not e.inv[slot] then
		return
	end
	e.inv = Regras.definirPente(e.inv, slot, pente)
	if not silencioso then
		mudou(jogador)
	end
end

-- Troca atômica de 1 `deId` por 1 `paraId` (ex.: galaoVazio -> galaoGasolina). Se o resultado não couber, nada muda e
-- devolve false. Um único `mudou` (sem remover + dar soltos). docs/combustivel.md §6.5.
function Inventario.trocar(jogador: Player, deId: string, paraId: string): boolean
	local e = estados[jogador]
	if not e then
		return false
	end
	if Itens.itens[deId] == nil or Itens.itens[paraId] == nil then
		warn("[Inventario] trocar: item desconhecido " .. tostring(deId) .. " -> " .. tostring(paraId))
		return false
	end
	local novo, ok = Regras.trocar(e.inv, deId, paraId, Itens.itens, Itens.empilhamentoPadrao)
	if not ok then
		return false
	end
	e.inv = novo
	mudou(jogador)
	return true
end

-- Carga em kg: Σ peso × qtd dos slots (Config/Itens: `peso` do item, `pesoPadrao` se faltar). Só lê o estado, sem custo de rede.
-- Entra na camada de equipamento do passo (docs/som.md §4.3).
function Inventario.carga(jogador: Player): number
	local e = estados[jogador]
	if not e then
		return 0
	end
	local total = 0
	for _, pilha in Regras.ocupados(e.inv) do
		local def = Itens.itens[pilha.id]
		local peso = if def and type(def.peso) == "number" then def.peso else Itens.pesoPadrao
		total += peso * pilha.qtd
	end
	return total
end

function Inventario.aoMudar(callback: (jogador: Player) -> ())
	table.insert(ouvintes, callback)
end

-- Uso de itens -------------------------------------------------------------------------------------------------

local TIPOS_USAVEIS = { comida = true, bebida = true, cura = true }

local function aplicarUso(jogador: Player, id: string, def: any): boolean
	if def.tipo == "cura" then
		local Vida = servico("Vida")
		if not Vida then
			return false
		end
		if Vida.curar(jogador, def.cura) == nil then
			aviso(jogador, "Nada para curar")
			return false
		end
		return Inventario.remover(jogador, id, 1)
	end
	if not Inventario.remover(jogador, id, 1) then
		return false
	end
	local Sobrevivencia = servico("Sobrevivencia")
	if Sobrevivencia then
		if def.fome then
			Sobrevivencia.alterar(jogador, "Fome", def.fome)
		end
		if def.sede then
			Sobrevivencia.alterar(jogador, "Sede", def.sede)
		end
	end
	return true
end

local function usar(jogador: Player, slot: number)
	local e = estados[jogador]
	if not e or jogador:GetAttribute("Usando") == true then
		return
	end
	local pilha = e.inv[slot]
	if not pilha then
		return
	end
	local id = pilha.id
	local def = Itens.itens[id]
	if def and (def.tipo == "recipiente" or def.tipo == "municao") then
		-- munição também (só segurar na mão); galão/garrafa: o mesmo gesto de usar item segura/guarda na mão (docs/combustivel.md §6.5). Fica fora de
		-- TIPOS_USAVEIS de propósito: não é consumo, não passa por aplicarUso.
		local Combustivel = servico("Combustivel")
		if Combustivel then
			Combustivel.segurarRecipiente(jogador, slot)
		end
		return
	end
	if not def or not TIPOS_USAVEIS[def.tipo] then
		return -- arma: equipar é o evento Equipar; munição não se usa
	end
	local _, hrp = personagemVivo(jogador)
	if not hrp then
		return
	end

	e.uso += 1
	local ficha = e.uso
	jogador:SetAttribute("Usando", true)
	naMao(jogador, id)

	local Ruido = servico("Ruido")
	if Ruido and def.ruido then
		Ruido.emitirAcao(def.ruido, hrp.Position, jogador)
	end
	local Sons = servico("Sons")
	if Sons and def.som then
		Sons.tocar(def.som, hrp)
	end

	task.spawn(function()
		local inicio = os.clock()
		local duracao = def.uso or 0
		repeat
			task.wait(PASSO_USO)
			local atual = estados[jogador]
			local p = atual and atual.inv[slot]
			if e.uso ~= ficha or not atual or not p or p.id ~= id or not personagemVivo(jogador) then
				if e.uso == ficha and jogador.Parent then
					jogador:SetAttribute("Usando", false)
					naMao(jogador, nil)
				end
				return
			end
		until os.clock() - inicio >= duracao
		aplicarUso(jogador, id, def)
		if e.uso == ficha and jogador.Parent then
			e.uso += 1
			jogador:SetAttribute("Usando", false)
			naMao(jogador, nil) -- terminou de comer/beber/curar: o item some da mão
		end
	end)
end

local function slotValido(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= Itens.slots
end

local function largar(jogador: Player, slot: number)
	local e = estados[jogador]
	if not e or not e.inv[slot] then
		return
	end
	local _, hrp = personagemVivo(jogador)
	local ItensChao = servico("ItensChao")
	if not hrp or not ItensChao then
		return -- sem o serviço do chão o item ficaria perdido: não tira do inventário
	end
	local novo, tirado = Regras.retirarSlot(e.inv, slot)
	if not tirado then
		return
	end
	e.inv = novo
	-- o item inteiro do slot sai arremessado à frente (a posição final é decidida pelo ItensChao)
	ItensChao.largar(jogador, tirado.id, tirado.qtd, tirado.pente)
	mudou(jogador)
end

-- Ciclo de vida ------------------------------------------------------------------------------------------------

local function aoSpawnar(jogador: Player)
	local e = estados[jogador]
	if not e then
		return
	end
	e.uso += 1
	jogador:SetAttribute("Usando", false)
	naMao(jogador, nil)
	if e.precisaKit then
		e.precisaKit = false
		for _, item in Itens.kitInicial do
			-- `slot` fixa a posição na barra (a lanterna fica no 5); ocupado ou fora da faixa = primeiro livre
			if item.slot and item.slot >= 1 and item.slot <= Itens.slots and not e.inv[item.slot] then
				e.inv[item.slot] = { id = item.id, qtd = item.qtd }
			else
				Inventario.dar(jogador, item.id, item.qtd)
			end
		end
	end
	enviar(jogador)
end

local function jogadorEntrou(jogador: Player)
	if estados[jogador] then
		return
	end
	estados[jogador] = { inv = Regras.novo(Itens.slots), precisaKit = true, uso = 0 }
	jogador:SetAttribute("Usando", false)
	jogador:GetAttributeChangedSignal("ArmaEquipada"):Connect(function()
		enviar(jogador)
	end)
	jogador.CharacterAdded:Connect(function()
		aoSpawnar(jogador)
	end)
	if jogador.Character then
		task.spawn(aoSpawnar, jogador)
	end
end

local function aoMorrer(jogador: Player, _causa: string, posicao: Vector3)
	local e = estados[jogador]
	if not e then
		return
	end
	cancelarUso(jogador)
	local conteudo = Regras.lista(e.inv)
	e.inv = Regras.novo(Itens.slots)
	e.precisaKit = true
	local ItensChao = servico("ItensChao")
	if ItensChao and #conteudo > 0 then
		ItensChao.espalhar(posicao, conteudo, jogador) -- `jogador` = fonte do som dos itens que caem (docs/som.md §5.4)
	end
	mudou(jogador)
end

function Inventario.iniciar()
	Rede.evento("UsarItem").OnServerEvent:Connect(function(jogador: Player, slot: any)
		if not Limite.ok(jogador, "UsarItem", 0.2) then
			return
		end
		if slot == 0 then
			-- INTEGRACAO: não existe evento "pedir inventário"; o cliente manda UsarItem(0) ao iniciar para receber o estado.
			enviar(jogador)
			return
		end
		if slotValido(slot) then
			usar(jogador, slot)
		end
	end)

	Rede.evento("LargarItem").OnServerEvent:Connect(function(jogador: Player, slot: any)
		if not Limite.ok(jogador, "LargarItem", 0.25) then
			return
		end
		if slotValido(slot) then
			largar(jogador, slot)
		end
	end)

	Players.PlayerAdded:Connect(jogadorEntrou)
	for _, jogador in Players:GetPlayers() do
		jogadorEntrou(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador: Player)
		cancelarUso(jogador)
		estados[jogador] = nil
		Limite.limpar(jogador)
	end)

	local Vida = servico("Vida")
	if Vida then
		Vida.aoMorrer(aoMorrer)
	end

	local ok, Teste = pcall(require, script.Parent.Teste)
	if ok then
		Teste.registrar("dar", function(jogador: Player, id: string, qtd: number?)
			local sobra = Inventario.dar(jogador, id, qtd or 1)
			return string.format("%s x%d dado, sobra %d", tostring(id), qtd or 1, sobra)
		end)
		Teste.registrar("inv", function(jogador: Player)
			local e = estados[jogador]
			if not e then
				return "sem inventário"
			end
			local linhas = {}
			for _, o in Regras.ocupados(e.inv) do
				table.insert(
					linhas,
					string.format("%d: %s x%d%s", o.slot, o.id, o.qtd, if o.pente then " pente " .. o.pente else "")
				)
			end
			local texto = if #linhas > 0 then table.concat(linhas, " | ") else "(vazio)"
			print("[inv] " .. jogador.Name .. " Usando=" .. tostring(jogador:GetAttribute("Usando")) .. " " .. texto)
			return texto
		end)
	end
end

return Inventario
