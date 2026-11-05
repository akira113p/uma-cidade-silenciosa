-- Armas: equipar, atacar, pente, recarga e dano do PvP, tudo decidido no servidor. Dono: P7 (reescrito pelo A2).
-- Contrato: docs/armas.md §6-§7 (e docs/arquitetura.md §P7). O cliente só pede (Atacar, Recarregar, Mira, Equipar).
-- Dono dos atributos Player.ArmaEquipada, ArmaSlot, Pente, Reserva, Recarregando e MiraPitch.
-- A arma na mão é o Model de Shared/ArmaModelo preso à RightHand por Motor6D; se o módulo faltar ou falhar, o modelo de
-- blocos do item (Config/ItensModelos) entra pelo ItemNaMao (docs/itens-no-mundo.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local CfgArmas = require(Shared:WaitForChild("Config"):WaitForChild("Armas"))
local CfgCorpo = require(Shared.Config:WaitForChild("Corpo"))
local CfgItens = require(Shared.Config:WaitForChild("Itens"))
local CfgSom = require(Shared.Config:WaitForChild("Som"))
local Regra = require(Shared:WaitForChild("Regras"):WaitForChild("Armas"))

local Limite = require(script.Parent.Limite)
local Inventario = require(script.Parent.Inventario)
local Vida = require(script.Parent.Vida)
local Monstros = require(script.Parent.Monstros)
local Sons = require(script.Parent.Sons)
local Ruido = require(script.Parent.Ruido)
local Lanterna = require(script.Parent.Lanterna)

local Armas = {}

-- Constantes de validação (não são balanceamento; o balanceamento está em Config/Armas).
local DIRECAO_MIN, DIRECAO_MAX = 0.5, 1.5 -- magnitude aceita do vetor de direção enviado pelo cliente
local RAIO_CORPO_A_CORPO = 1.5 -- raio do Spherecast do corpo a corpo
local FOLGA_CADENCIA = 0.04 -- s: jitter de rede; o cliente espera cadência + 0.02
local FOLGA_DISTANCIA = 3 -- studs: lag entre a cabeça no servidor e a origem enviada
local INTERVALO_MIN_ATACAR = 0.05 -- s: teto de pedidos/s, antes de qualquer outra checagem
local INTERVALO_MIN_RECARREGAR = 0.2 -- s entre pedidos de recarga
local INTERVALO_MIN_MIRA = 0.1 -- s entre eventos Mira (o cliente manda 8 Hz = 0,125 s)
local MIRA_MAX = 80 -- graus: limite do MiraPitch
local MAX_RASTROS_DISPARO = 3 -- escopeta: no máximo 3 eventos Disparo por tiro (um por chumbinho agrupado)
local ALCANCE_FOGUETE_VISUAL = 4 -- studs: o "fim" do Disparo do lançador (o foguete é uma peça real, sem rastro de tiro)

type Estado = {
	ultimo: number, -- os.clock() do último ataque aceito (cadência)
	slot: number?,
	arma: string?,
	bloom: number, -- graus acumulados; decai por Regra.bloomRecuperado desde `ultimoTiro`
	ultimoTiro: number,
	recargaId: number, -- ficha da recarga em andamento; mudar a ficha cancela os passos agendados
	recarregando: boolean,
	equipId: number, -- ficha da arma na mão; mudar cancela golpes corpo a corpo agendados
}
local estados: { [Player]: Estado } = {}
local rng = Random.new()

local function estadoDe(jogador: Player): Estado
	local e = estados[jogador]
	if not e then
		e = {
			ultimo = -math.huge,
			slot = nil,
			arma = nil,
			bloom = 0,
			ultimoTiro = 0,
			recargaId = 0,
			recarregando = false,
			equipId = 0,
		}
		estados[jogador] = e
	end
	return e
end

local function aviso(jogador: Player, texto: string)
	Rede.evento("Aviso"):FireClient(jogador, texto)
end

local function vec(v: Vector3): Regra.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function vetorFinito(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < math.huge
end

-- Log de rejeição com teto de 1 por 2 s por jogador, para não virar spam sob ataque.
local function rejeitar(jogador: Player, motivo: string)
	if Limite.ok(jogador, "ArmasLog", 2) then
		warn(string.format("[Armas] ataque de %s rejeitado: %s", jogador.Name, motivo))
	end
end

local function vivo(jogador: Player): (Model?, Humanoid?, BasePart?)
	if jogador:GetAttribute("Morto") == true or not Vida.estaVivo(jogador) then
		return nil, nil, nil
	end
	local personagem = jogador.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local cabeca = personagem and personagem:FindFirstChild("Head")
	if not (personagem and humanoide and humanoide.Health > 0 and cabeca and cabeca:IsA("BasePart")) then
		return nil, nil, nil
	end
	return personagem, humanoide, cabeca
end

-- Raycast/Spherecast ignora o atacante e o que não é "mundo" (zonas, pontos, sons soltos, itens no chão, projéteis).
local function parametros(personagem: Model): RaycastParams
	local lista: { Instance } = { personagem }
	local mapa = workspace:FindFirstChild("Mapa")
	for _, pasta in { mapa and mapa:FindFirstChild("Zonas"), mapa and mapa:FindFirstChild("Pontos") } do
		table.insert(lista, pasta)
	end
	for _, nome in { "SonsSoltos", "ItensChao", "Projeteis" } do
		local pasta = workspace:FindFirstChild(nome)
		if pasta then
			table.insert(lista, pasta)
		end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = lista
	return p
end

-- Módulos de outras partes, carregados na hora e sem derrubar as armas se faltarem ---------------------------------

-- Veiculos inicia depois de Armas ser carregado: require preguiçoso (nil se o módulo falhar).
local function veiculos(): any
	local ok, m = pcall(require, script.Parent.Veiculos)
	return if ok then m else nil
end

-- Destruicao inicia antes de Armas, mas o require é preguiçoso e protegido: se ela falhar, a arma continua valendo.
local function destruicao(): any
	local ok, m = pcall(require, script.Parent.Destruicao)
	return if ok then m else nil
end

-- ItemNaMao: modelo de blocos na mão (fallback da arma). Carregado na hora; nil se o módulo falhar.
local function itemNaMao(): any
	local ok, m = pcall(require, script.Parent.ItemNaMao)
	if not ok then
		warn("[Armas] ItemNaMao indisponível: " .. tostring(m))
		return nil
	end
	return m
end

local function foguete(): any
	local ok, m = pcall(require, script.Parent.Foguete)
	if not ok then
		warn("[Armas] Foguete indisponível: " .. tostring(m))
		return nil
	end
	return m
end

-- ArmaModelo (A3) e ArmasAnim (A4) podem não existir ainda: cada um só vale se o ModuleScript estiver lá.
local function moduloOpcional(pai: Instance, nome: string): any
	local arquivo = pai:FindFirstChild(nome)
	if not (arquivo and arquivo:IsA("ModuleScript")) then
		return nil
	end
	local ok, m = pcall(require, arquivo)
	if not ok then
		warn("[Armas] " .. nome .. " falhou ao carregar: " .. tostring(m))
		return nil
	end
	return m
end

-- Onde a palma segura o Cabo: Config/ArmasAnim.mao.porClasse[classe] ou .C0; sem o config, a origem.
local function c0Da(classe: string): CFrame
	local anim = moduloOpcional(Shared.Config, "ArmasAnim")
	local mao = anim and anim.mao
	if type(mao) == "table" then
		local porClasse = mao.porClasse
		if type(porClasse) == "table" and typeof(porClasse[classe]) == "CFrame" then
			return porClasse[classe]
		end
		if typeof(mao.C0) == "CFrame" then
			return mao.C0
		end
	end
	return CFrame.new()
end

-- Atributos de munição ------------------------------------------------------------------------------------------------

-- Pente/Reserva/Recarregando refletem a arma equipada (nil sem arma de fogo). Chamado a cada tiro, recarga e mudança de inventário.
local function sincronizarMunicao(jogador: Player)
	local e = estados[jogador]
	local cfg = if e and e.arma then CfgArmas.armas[e.arma] else nil
	if not (e and e.slot and cfg and cfg.tipo == "fogo") then
		jogador:SetAttribute("Pente", nil)
		jogador:SetAttribute("Reserva", nil)
		jogador:SetAttribute("Recarregando", nil)
		return
	end
	jogador:SetAttribute("Pente", Inventario.pente(jogador, e.slot) or 0)
	jogador:SetAttribute("Reserva", Inventario.contar(jogador, cfg.municao))
	jogador:SetAttribute("Recarregando", e.recarregando)
end

-- Cancela a recarga em andamento sem perder o que já entrou no pente (os passos agendados morrem pela ficha).
local function cancelarRecarga(jogador: Player)
	local e = estados[jogador]
	if not e then
		return
	end
	e.recargaId += 1
	if e.recarregando then
		e.recarregando = false
		sincronizarMunicao(jogador)
	end
end

-- Equipar -------------------------------------------------------------------------------------------------------------

local function desequipar(jogador: Player)
	local e = estadoDe(jogador)
	cancelarRecarga(jogador)
	e.equipId += 1
	e.slot = nil
	e.arma = nil
	jogador:SetAttribute("ArmaEquipada", nil)
	jogador:SetAttribute("ArmaSlot", nil)
	jogador:SetAttribute("MiraPitch", nil)
	sincronizarMunicao(jogador)
	local personagem = jogador.Character
	local velha = personagem and personagem:FindFirstChild("ArmaNaMao")
	if velha then
		velha:Destroy()
	end
	local N = itemNaMao()
	if N then
		N.definir(jogador, "arma", nil) -- tira o modelo de blocos (fallback), se houver
	end
end

-- Model de Shared/ArmaModelo preso à RightHand por Motor6D. false se o módulo falta ou falha (aí vale o bloco provisório).
local function montarModelo(personagem: Model, id: string, classe: string): boolean
	local mao = personagem:FindFirstChild("RightHand")
	if not (mao and mao:IsA("BasePart")) then
		return true -- sem mão não há o que montar (nem bloco)
	end
	local ArmaModelo = moduloOpcional(Shared, "ArmaModelo")
	if not (ArmaModelo and ArmaModelo.criar) then
		return false
	end
	local ok, modelo = pcall(ArmaModelo.criar, id)
	if not (ok and typeof(modelo) == "Instance" and modelo:IsA("Model")) then
		warn("[Armas] ArmaModelo.criar(" .. id .. ") falhou: " .. tostring(modelo))
		return false
	end
	local cabo = modelo.PrimaryPart or modelo:FindFirstChild("Cabo")
	if not (cabo and cabo:IsA("BasePart")) then
		warn("[Armas] ArmaModelo de " .. id .. " sem Cabo")
		modelo:Destroy()
		return false
	end
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false -- a arma na mão não bloqueia o raycast de ninguém
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = false
		end
	end
	local c0 = c0Da(classe)
	modelo.Name = "ArmaNaMao"
	-- põe o Cabo exatamente onde a junta o quer, para a arma não "voar" do chão no primeiro quadro
	modelo:PivotTo((mao.CFrame * c0) * cabo.CFrame:ToObjectSpace(modelo:GetPivot()))
	local junta = Instance.new("Motor6D")
	junta.Name = "JuntaArma"
	junta.Part0 = mao
	junta.Part1 = cabo
	junta.C0 = c0
	junta.Parent = cabo
	modelo.Parent = personagem
	return true
end

-- `idItem` é o id de Config/Itens (ex.: "faca"), que é o do modelo de blocos; `id` é o da arma em Config/Armas.
local function montarArma(jogador: Player, personagem: Model, id: string, classe: string, idItem: string)
	if not montarModelo(personagem, id, classe) then
		local N = itemNaMao()
		if N then
			N.definir(jogador, "arma", idItem)
		end
	end
end

-- Devolve (ok, motivo). slot nil = mãos vazias.
local function equipar(jogador: Player, slot: number?): (boolean, string?)
	if slot == nil then
		desequipar(jogador)
		return true, nil
	end
	local personagem = vivo(jogador)
	if not personagem then
		return false, "morto"
	end
	local entrada = Inventario.slot(jogador, slot)
	local item = entrada and CfgItens.itens[entrada.id]
	if item and item.tipo == "lanterna" then
		return Lanterna.alternar(jogador, slot) -- a lanterna não troca a arma da mão e vale mesmo usando item
	end
	if jogador:GetAttribute("Usando") == true then
		return false, "usando item"
	end
	if not (item and item.tipo == "arma" and CfgArmas.armas[item.arma]) then
		return false, "slot sem arma"
	end
	local cfg = CfgArmas.armas[item.arma]
	if cfg.duasMaos and jogador:GetAttribute("BracoZerado") == true then
		aviso(jogador, "Braço ferido: não dá para usar " .. cfg.nome)
		return false, "braço zerado"
	end
	desequipar(jogador) -- cancela recarga e golpe agendado da arma anterior
	local e = estadoDe(jogador)
	e.slot = slot
	e.arma = item.arma
	if cfg.tipo == "fogo" and Inventario.pente(jogador, slot) == nil then
		-- arma de fábrica (kit/admin): cheia no primeiro uso. A de loot já vem com o pente sorteado (server/Loot).
		Inventario.definirPente(jogador, slot, cfg.pente, true)
	end
	jogador:SetAttribute("ArmaSlot", slot) -- antes de ArmaEquipada: é a mudança dela que reenvia o inventário (equipado = ArmaSlot)
	jogador:SetAttribute("ArmaEquipada", item.arma)
	sincronizarMunicao(jogador)
	montarArma(jogador, personagem, item.arma, cfg.classe, entrada.id)
	return true, nil
end

-- A arma equipada tem que continuar no slot (largou, usou, trocou): senão cai da mão. Também atualiza Pente/Reserva.
local function conferirSlot(jogador: Player)
	local e = estados[jogador]
	if not (e and e.slot and e.arma) then
		return
	end
	local entrada = Inventario.slot(jogador, e.slot)
	local item = entrada and CfgItens.itens[entrada.id]
	if not (item and item.tipo == "arma" and item.arma == e.arma) then
		desequipar(jogador)
		return
	end
	sincronizarMunicao(jogador)
end

-- Acerto e dano ---------------------------------------------------------------------------------------------------------

-- Quem foi atingido: jogador (Player) ou monstro (Model).
local function resolverAlvo(inst: Instance): (Player?, Model?)
	local modelo = inst:FindFirstAncestorOfClass("Model")
	local jogador = modelo and Players:GetPlayerFromCharacter(modelo)
	if jogador then
		return jogador, nil
	end
	return nil, Monstros.ehMonstro(inst)
end

local function ehPecaVeiculo(inst: Instance): boolean
	local modelo = inst:FindFirstAncestorOfClass("Model")
	return modelo ~= nil and modelo:GetAttribute("Veiculo") == true
end

local function ehAlvo(resultado: RaycastResult?): boolean
	if not resultado then
		return false
	end
	if ehPecaVeiculo(resultado.Instance) then
		return true
	end
	local jogador, monstro = resolverAlvo(resultado.Instance)
	if jogador ~= nil or monstro ~= nil then
		return true
	end
	-- construção destrutível: o golpe corpo a corpo prefere a parede ao Spherecast vazio
	local D = destruicao()
	return D ~= nil and D.ehDestrutivel(resultado.Instance)
end

-- Dano somado por alvo antes de aplicar: um tiro de escopeta (8-9 chumbinhos) vira UMA chamada por (jogador, parte),
-- por monstro, por peça de veículo e por peça de construção.
type Acumulador = {
	jogadores: { [Player]: { partes: { [string]: number }, pos: Vector3 } },
	monstros: { [Model]: { dano: number, pos: Vector3 } },
	veiculos: { [Instance]: { dano: number, pos: Vector3 } },
	construcoes: { [Instance]: { dano: number, pos: Vector3, normal: Vector3 } },
	direcao: Vector3?,
}

local function novoAcumulador(): Acumulador
	return { jogadores = {}, monstros = {}, veiculos = {}, construcoes = {}, direcao = nil }
end

local function registrarConstrucao(acc: Acumulador, inst: Instance, dano: number, pos: Vector3, normal: Vector3)
	local g = acc.construcoes[inst]
	if g then
		g.dano += dano
	else
		acc.construcoes[inst] = { dano = dano, pos = pos, normal = normal }
	end
end

local function registrar(acc: Acumulador, atacante: Player, resultado: RaycastResult, dano: number, direcao: Vector3)
	local inst = resultado.Instance
	acc.direcao = acc.direcao or direcao
	if ehPecaVeiculo(inst) then
		local g = acc.veiculos[inst]
		if g then
			g.dano += dano
		else
			acc.veiculos[inst] = { dano = dano, pos = resultado.Position }
		end
		return
	end
	local alvoJogador, alvoMonstro = resolverAlvo(inst)
	if alvoJogador then
		if alvoJogador == atacante or not Vida.estaVivo(alvoJogador) then
			return
		end
		local parte = CfgCorpo.r15[inst.Name] or "Torso"
		local g = acc.jogadores[alvoJogador]
		if not g then
			g = { partes = {}, pos = resultado.Position }
			acc.jogadores[alvoJogador] = g
		end
		g.partes[parte] = (g.partes[parte] or 0) + Regra.dano({ dano = dano }, parte, CfgCorpo)
	elseif alvoMonstro then
		local g = acc.monstros[alvoMonstro]
		if g then
			g.dano += dano
		else
			acc.monstros[alvoMonstro] = { dano = dano, pos = resultado.Position }
		end
	else
		registrarConstrucao(acc, inst, dano, resultado.Position, resultado.Normal)
	end
end

local avisouSemTipoDano: { [string]: boolean } = {}

local function aplicar(acc: Acumulador, atacante: Player, cfg: any)
	-- veículo: se a peça não é de veículo registrado (acerto devolve false) cai como construção
	for peca, g in acc.veiculos do
		local V = veiculos()
		if V and V.acerto(peca, g.dano, atacante) then
			Sons.tocar("AcertoMetal", g.pos)
		else
			registrarConstrucao(acc, peca, g.dano, g.pos, Vector3.yAxis)
		end
	end
	for alvo, g in acc.jogadores do
		local maiorParte, maior = "Torso", -1
		for parte, valor in g.partes do
			Vida.dano(alvo, parte, valor, { tipo = "jogador", jogador = atacante, direcao = acc.direcao })
			if valor > maior then
				maiorParte, maior = parte, valor
			end
		end
		Sons.tocar(cfg.somAcerto, g.pos)
		Rede.evento("Acerto"):FireClient(atacante, true, maiorParte)
	end
	for modelo, g in acc.monstros do
		Monstros.dano(modelo, g.dano, atacante)
		Sons.tocar(cfg.somAcerto, g.pos)
		Rede.evento("Acerto"):FireClient(atacante, false, nil)
	end
	-- construção: sem somAcerto nem evento Acerto (o som é da classe do material, tocado pela Destruicao)
	local D = destruicao()
	for peca, g in acc.construcoes do
		if D and D.ehDestrutivel(peca) then
			if cfg.tipoDano then
				D.dano(peca, g.dano, {
					tipo = cfg.tipoDano,
					ponto = g.pos,
					normal = g.normal,
					fonte = atacante,
				})
			elseif not avisouSemTipoDano[cfg.nome] then
				avisouSemTipoDano[cfg.nome] = true
				warn("[Armas] " .. cfg.nome .. " sem tipoDano em Config/Armas: não machuca construção")
			end
		end
	end
end

-- Disparo visual para quem está perto (menos o atirador, que prevê no cliente). `fins` = pontos de acerto/ponta do alcance.
local function avisarDisparo(atirador: Player, armaId: string, origem: Vector3, fins: { Vector3 })
	local evento = Rede.evento("Disparo")
	for _, outro in Players:GetPlayers() do
		if outro == atirador then
			continue
		end
		local raiz = outro.Character and outro.Character:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") and (raiz.Position - origem).Magnitude <= CfgArmas.alcanceVisual then
			for _, fim in fins do
				evento:FireClient(outro, atirador, armaId, origem, fim)
			end
		end
	end
end

-- Ataque -----------------------------------------------------------------------------------------------------------------

-- Estado de movimento do atirador, lido do servidor (nunca do cliente): parado | andando | correndo | agachado.
local function estadoDoAtirador(jogador: Player, personagem: Model): string
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local v = if raiz and raiz:IsA("BasePart") then raiz.AssemblyLinearVelocity else Vector3.zero
	return Regra.estadoDoAtirador(
		jogador:GetAttribute("Agachado") == true,
		jogador:GetAttribute("Correndo") == true,
		Vector3.new(v.X, 0, v.Z).Magnitude,
		CfgSom.velocidadeMinimaPasso
	)
end

local function atacarFogo(
	jogador: Player,
	e: Estado,
	id: string,
	cfg: any,
	personagem: Model,
	cabeca: BasePart,
	origem: Vector3,
	dirTabela: Regra.Vec,
	params: RaycastParams
)
	local slot = e.slot
	if not slot then
		return
	end
	local agora = os.clock()
	-- 5. cadência, guardada no servidor (só um tiro aceito reinicia o relógio; vazio/recarregando não gastam)
	if not Regra.podeAtacar(e.ultimo, agora, cfg.cadencia - FOLGA_CADENCIA) then
		return
	end
	-- tiro durante a recarga do tubo a interrompe (mantém os cartuchos que já entraram)
	if e.recarregando and cfg.recarga.tipo == "cartucho" and (Inventario.pente(jogador, slot) or 0) > 0 then
		cancelarRecarga(jogador)
	end
	local pente = Inventario.pente(jogador, slot) or 0
	local pode, motivo = Regra.podeDisparar(cfg, pente, e.recarregando, jogador:GetAttribute("Usando") == true)
	if not pode then
		if motivo == "vazio" and Limite.ok(jogador, "AvisoVazio", 1) then
			aviso(jogador, "Pente vazio")
		end
		return
	end

	-- espalhamento: cone + bloom (que decai com o tempo parado) x estado do atirador x braço zerado
	local bloom = math.min(Regra.bloomRecuperado(cfg, e.bloom, agora - e.ultimoTiro), cfg.bloom.maximo)
	local graus = Regra.espalhamentoTotal(
		cfg,
		bloom,
		estadoDoAtirador(jogador, personagem),
		jogador:GetAttribute("BracoZerado") == true,
		CfgArmas,
		CfgCorpo
	)

	local lancador = cfg.projetil ~= nil
	local Foguete = if lancador then foguete() else nil
	if lancador and (Foguete == nil or Foguete.cheio()) then
		return -- sem foguete no ar disponível: não gasta pente nem cadência
	end

	-- 6. pente consumido no servidor
	e.ultimo = agora
	e.bloom = Regra.bloomAposTiro(cfg, bloom)
	e.ultimoTiro = agora
	pente -= 1
	Inventario.definirPente(jogador, slot, pente, true)
	jogador:SetAttribute("Pente", pente)

	-- Efeitos que acontecem sempre: som e ruído (o tiro chama monstros a 600 studs: custo do PvP). Chumbinhos contam como um ruído só.
	Sons.tocar(cfg.som, cabeca, { db = cfg.ruidoDb })
	Ruido.emitir(cabeca.Position, cfg.ruidoDb, "arma", jogador)

	if lancador then
		local d = Regra.espalhar(dirTabela, graus, function()
			return rng:NextNumber()
		end)
		local dir = Vector3.new(d.x, d.y, d.z)
		Foguete.lancar(jogador, cfg, origem, dir)
		avisarDisparo(jogador, id, origem, { origem + dir * ALCANCE_FOGUETE_VISUAL })
		return
	end

	local acc = novoAcumulador()
	local fins: { Vector3 } = {}
	for i = 1, Regra.pelotas(cfg) do
		local d = Regra.espalhar(dirTabela, graus, function()
			return rng:NextNumber()
		end)
		local dir = Vector3.new(d.x, d.y, d.z)
		local resultado = workspace:Raycast(origem, dir * cfg.alcance, params)
		local fim = origem + dir * cfg.alcance
		if resultado then
			fim = resultado.Position
			registrar(acc, jogador, resultado, Regra.danoNaDistancia(cfg, (resultado.Position - origem).Magnitude), dir)
		end
		if i <= MAX_RASTROS_DISPARO then
			table.insert(fins, fim)
		end
	end
	aplicar(acc, jogador, cfg)
	avisarDisparo(jogador, id, origem, fins)
end

-- Resolve o golpe corpo a corpo `atrasoImpacto` s depois do pedido, com a origem lida da cabeça nesse instante.
local function resolverGolpe(jogador: Player, equipId: number, id: string, dir: Vector3)
	local e = estados[jogador]
	if not e or e.equipId ~= equipId or e.arma ~= id then
		return -- trocou/largou a arma ou saiu do jogo no meio do golpe
	end
	local personagem, _, cabeca = vivo(jogador)
	local cfg = CfgArmas.armas[id]
	if not (personagem and cabeca and cfg) then
		return
	end
	local params = parametros(personagem)
	local origem = cabeca.Position
	-- Raio fino primeiro (pega alvo colado, onde o Spherecast ignora o que já está dentro da esfera); depois a esfera, que perdoa a mira.
	local alcance = cfg.alcance + CfgArmas.toleranciaAlcance
	local resultado = workspace:Raycast(origem, dir * alcance, params)
	if not ehAlvo(resultado) then
		resultado = workspace:Spherecast(origem, RAIO_CORPO_A_CORPO, dir * alcance, params)
	end
	if not (resultado and ehAlvo(resultado)) then
		return
	end
	if (resultado.Position - cabeca.Position).Magnitude > alcance + FOLGA_DISTANCIA then
		return -- o alvo saiu do alcance durante o atraso: golpe no ar, sem custo
	end
	local acc = novoAcumulador()
	registrar(acc, jogador, resultado, cfg.dano, dir)
	aplicar(acc, jogador, cfg)
end

local function atacarCorpo(jogador: Player, e: Estado, id: string, cfg: any, cabeca: BasePart, dirTabela: Regra.Vec)
	local agora = os.clock()
	if not Regra.podeAtacar(e.ultimo, agora, cfg.cadencia - FOLGA_CADENCIA) then
		return
	end
	e.ultimo = agora -- a cadência reinicia no pedido; o golpe só resolve em atrasoImpacto
	Sons.tocar(cfg.som, cabeca, { db = cfg.ruidoDb })
	Ruido.emitir(cabeca.Position, cfg.ruidoDb, "arma", jogador)
	local equipId = e.equipId
	local dir = Vector3.new(dirTabela.x, dirTabela.y, dirTabela.z)
	task.delay(cfg.atrasoImpacto, resolverGolpe, jogador, equipId, id, dir)
end

local function atacar(jogador: Player, origem: any, direcao: any)
	if not Limite.ok(jogador, "Atacar", INTERVALO_MIN_ATACAR) then
		return
	end
	-- 1. tipos
	if typeof(origem) ~= "Vector3" or typeof(direcao) ~= "Vector3" then
		return rejeitar(jogador, "tipos inválidos")
	end
	if not (vetorFinito(origem) and vetorFinito(direcao)) then
		return rejeitar(jogador, "vetor não finito")
	end
	-- 2. estado do jogador e da arma
	local id = jogador:GetAttribute("ArmaEquipada")
	local cfg = if type(id) == "string" then CfgArmas.armas[id] else nil
	if not cfg then
		return
	end
	local personagem, _, cabeca = vivo(jogador)
	if not (personagem and cabeca) then
		return
	end
	if jogador:GetAttribute("Usando") == true then
		return
	end
	if cfg.duasMaos and jogador:GetAttribute("BracoZerado") == true then
		desequipar(jogador)
		return rejeitar(jogador, "duas mãos com braço zerado")
	end
	-- 3. direção plausível e origem perto da cabeça
	local dirTabela = Regra.normalizarDirecao(vec(direcao), DIRECAO_MIN, DIRECAO_MAX)
	if not dirTabela then
		return rejeitar(jogador, "direção com magnitude implausível")
	end
	if not Regra.origemValida(vec(origem), vec(cabeca.Position), CfgArmas.toleranciaOrigem) then
		return rejeitar(jogador, string.format("origem a %.1f studs da cabeça", (origem - cabeca.Position).Magnitude))
	end
	-- 4. da cabeça até a origem não pode haver parede (senão a origem forjada atravessa o mapa)
	local params = parametros(personagem)
	if workspace:Raycast(cabeca.Position, origem - cabeca.Position, params) then
		return rejeitar(jogador, "parede entre a cabeça e a origem")
	end

	local e = estadoDe(jogador)
	if e.arma ~= id then
		return -- atributo e estado fora de sincronia (equipar em andamento): ignora
	end
	if cfg.tipo == "fogo" then
		atacarFogo(jogador, e, id :: string, cfg, personagem, cabeca, origem, dirTabela, params)
	else
		atacarCorpo(jogador, e, id :: string, cfg, cabeca, dirTabela)
	end
end

-- Recarga -----------------------------------------------------------------------------------------------------------------

-- A recarga com ficha `ficha` segue valendo: mesma arma, jogador vivo, sem usar item.
local function recargaAtiva(jogador: Player, ficha: number, armaId: string): boolean
	local e = estados[jogador]
	return e ~= nil
		and e.recargaId == ficha
		and e.recarregando
		and e.arma == armaId
		and jogador.Parent ~= nil
		and jogador:GetAttribute("Usando") ~= true
		and vivo(jogador) ~= nil
end

local function encerrarRecarga(jogador: Player, ficha: number)
	local e = estados[jogador]
	if e and e.recargaId == ficha then
		e.recarregando = false
		sincronizarMunicao(jogador)
	end
end

local function somDaRecarga(jogador: Player, nome: string)
	local _, _, cabeca = vivo(jogador)
	if cabeca then
		Sons.tocar(nome, cabeca)
	end
end

-- Move até `n` balas da reserva para o pente do slot (pente: completa; tubo: 1 cartucho). false se não moveu nada.
local function moverMunicao(jogador: Player, e: Estado, cfg: any, tubo: boolean): boolean
	local slot = e.slot
	if not slot then
		return false
	end
	local pente = Inventario.pente(jogador, slot) or 0
	local reserva = Inventario.contar(jogador, cfg.municao)
	local novoPente, _, movidas
	if tubo then
		novoPente, _, movidas = Regra.cartuchoParaTubo(pente, cfg.pente, reserva)
	else
		novoPente, _, movidas = Regra.recarregarPente(pente, cfg.pente, reserva)
	end
	if movidas < 1 then
		return false
	end
	-- pente primeiro (silencioso): o evento Inventario que o remover dispara já leva o pente novo
	Inventario.definirPente(jogador, slot, novoPente, true)
	if not Inventario.remover(jogador, cfg.municao, movidas) then
		Inventario.definirPente(jogador, slot, pente, true)
		return false
	end
	return true
end

local function recarregar(jogador: Player)
	if not Limite.ok(jogador, "Recarregar", INTERVALO_MIN_RECARREGAR) then
		return
	end
	local e = estados[jogador]
	local id = e and e.arma
	local cfg = if id then CfgArmas.armas[id] else nil
	if not (e and id and cfg and e.slot and cfg.tipo == "fogo") then
		return
	end
	local personagem, _, cabeca = vivo(jogador)
	if not (personagem and cabeca) or e.recarregando or jogador:GetAttribute("Usando") == true then
		return
	end
	local pente = Inventario.pente(jogador, e.slot) or 0
	if pente >= cfg.pente then
		return
	end
	local reserva = Inventario.contar(jogador, cfg.municao)
	if reserva < 1 then
		aviso(jogador, "Sem munição")
		return
	end

	e.recarregando = true
	e.recargaId += 1
	local ficha = e.recargaId
	sincronizarMunicao(jogador)

	local recarga = cfg.recarga
	if recarga.tipo == "pente" then
		local duracao = Regra.tempoRecarga(cfg, pente, reserva)
		for _, s in cfg.somRecarga or {} do
			task.delay(s.t * duracao, function()
				if recargaAtiva(jogador, ficha, id) then
					somDaRecarga(jogador, s.nome)
				end
			end)
		end
		task.delay(duracao, function()
			if not recargaAtiva(jogador, ficha, id) then
				return
			end
			moverMunicao(jogador, e, cfg, false)
			encerrarRecarga(jogador, ficha)
		end)
		return
	end

	-- Tubo: `inicio` s, depois um cartucho a cada `porCartucho` s até encher ou acabar a reserva, e `fim` s de bombeio.
	local function fechar()
		if cfg.somBombear then
			somDaRecarga(jogador, cfg.somBombear)
		end
		task.delay(recarga.fim, function()
			if recargaAtiva(jogador, ficha, id) then
				encerrarRecarga(jogador, ficha)
			end
		end)
	end
	local function esperarCartucho()
		task.delay(recarga.porCartucho, function()
			if not recargaAtiva(jogador, ficha, id) then
				return
			end
			if not moverMunicao(jogador, e, cfg, true) then
				return fechar()
			end
			if cfg.somCartucho then
				somDaRecarga(jogador, cfg.somCartucho)
			end
			local cheio = (Inventario.pente(jogador, e.slot or 0) or 0) >= cfg.pente
			if cheio or Inventario.contar(jogador, cfg.municao) < 1 then
				fechar()
			else
				esperarCartucho()
			end
		end)
	end
	task.delay(recarga.inicio, function()
		if recargaAtiva(jogador, ficha, id) then
			esperarCartucho()
		end
	end)
end

-- Ciclo de vida ------------------------------------------------------------------------------------------------------------

local function aoEntrar(jogador: Player)
	estadoDe(jogador)
	jogador.CharacterAdded:Connect(function()
		desequipar(jogador) -- o bloco antigo morreu com o personagem; só zera estado e atributos
	end)
	jogador:GetAttributeChangedSignal("BracoZerado"):Connect(function()
		local id = jogador:GetAttribute("ArmaEquipada")
		local cfg = if type(id) == "string" then CfgArmas.armas[id] else nil
		if cfg and cfg.duasMaos and jogador:GetAttribute("BracoZerado") == true then
			desequipar(jogador)
			aviso(jogador, "Braço ferido: " .. cfg.nome .. " largada")
		end
	end)
	-- usar item (comer, curar) cancela a recarga
	jogador:GetAttributeChangedSignal("Usando"):Connect(function()
		if jogador:GetAttribute("Usando") == true then
			cancelarRecarga(jogador)
		end
	end)
end

function Armas.iniciar()
	for _, jogador in Players:GetPlayers() do
		aoEntrar(jogador)
	end
	Players.PlayerAdded:Connect(aoEntrar)
	Players.PlayerRemoving:Connect(function(jogador)
		estados[jogador] = nil
	end)

	Inventario.aoMudar(conferirSlot)
	Vida.aoMorrer(function(jogador)
		desequipar(jogador)
	end)

	Rede.evento("Equipar").OnServerEvent:Connect(function(jogador: Player, slot: any)
		if not Limite.ok(jogador, "Equipar", 0.1) then
			return
		end
		if slot ~= nil then
			if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > CfgItens.slots then
				return
			end
		end
		equipar(jogador, slot)
	end)

	Rede.evento("Atacar").OnServerEvent:Connect(atacar)

	Rede.evento("Recarregar").OnServerEvent:Connect(recarregar)

	-- Pitch da mira (para o corpo dos outros jogadores olhar para cima/baixo): só com arma, finito, limitado.
	Rede.evento("Mira").OnServerEvent:Connect(function(jogador: Player, pitch: any)
		if not Limite.ok(jogador, "Mira", INTERVALO_MIN_MIRA) then
			return
		end
		if type(pitch) ~= "number" or pitch ~= pitch or pitch == math.huge or pitch == -math.huge then
			return
		end
		local e = estados[jogador]
		if not (e and e.arma) then
			return
		end
		jogador:SetAttribute("MiraPitch", math.clamp(pitch, -MIRA_MAX, MIRA_MAX))
	end)

	-- Comando de teste do Studio: dá a arma, 2 pentes de reserva do calibre, o pente cheio, e equipa.
	require(script.Parent.Teste).registrar("arma", function(jogador: Player, id: string)
		local cfg = CfgArmas.armas[id]
		if not cfg then
			return "arma desconhecida: " .. tostring(id)
		end
		local idItem: string?
		for chave, item in CfgItens.itens do
			if item.tipo == "arma" and item.arma == id then
				idItem = chave
			end
		end
		if not idItem then
			return "nenhum item de Config/Itens aponta para a arma " .. id
		end
		local slotArma: number?
		for i = 1, CfgItens.slots do
			local entrada = Inventario.slot(jogador, i)
			if entrada and entrada.id == idItem then
				slotArma = i
				break
			end
		end
		if not slotArma then
			if Inventario.dar(jogador, idItem, 1) > 0 then
				return "inventário cheio"
			end
			for i = 1, CfgItens.slots do
				local entrada = Inventario.slot(jogador, i)
				if entrada and entrada.id == idItem then
					slotArma = i
					break
				end
			end
		end
		local reservaDada = ""
		if cfg.tipo == "fogo" and slotArma then
			local alvo = cfg.pente * 2
			local falta = alvo - Inventario.contar(jogador, cfg.municao)
			if falta > 0 then
				local sobra = Inventario.dar(jogador, cfg.municao, falta)
				if sobra > 0 then
					reservaDada = " (munição não coube: sobraram " .. sobra .. ")"
				end
			end
			Inventario.definirPente(jogador, slotArma, cfg.pente)
			reservaDada = string.format(
				" pente %d, reserva %d%s",
				cfg.pente,
				Inventario.contar(jogador, cfg.municao),
				reservaDada
			)
		end
		local ok, motivo = equipar(jogador, slotArma)
		return if ok
			then "equipada: " .. id .. " (slot " .. tostring(slotArma) .. ")" .. reservaDada
			else "falhou: " .. tostring(motivo)
	end)
end

return Armas
