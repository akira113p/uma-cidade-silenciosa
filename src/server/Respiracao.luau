-- Respiracao (servidor): decide quando o minigame de segurar a respiração abre e quando acaba (docs/som.md §13). O cliente joga
-- (client/RespiracaoMinigame); o servidor só aceita a falha ("arfou") e NUNCA um "venci": o sucesso vem dos fins daqui.
-- Regra pura: Regras/Respiracao. Números: Config/Respiracao. Enquanto o minigame está ativo o jogador tem o atributo PrendendoRespiracao
-- e a camada de respiração do passo some (Ruido lê o atributo): silêncio total parado, a recompensa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rede = require(Shared:WaitForChild("Rede"))
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Respiracao"))
local CfgSom = require(Shared.Config:WaitForChild("Som"))
local Som = require(Shared:WaitForChild("Regras"):WaitForChild("Som"))
local R = require(Shared.Regras:WaitForChild("Respiracao"))
local Sons = require(script.Parent.Sons)
local Teste = require(script.Parent.Teste)

local Respiracao = {}

local ESTAMINA_CHEIA = 100
local DISTANCIA_TESTE = 8 -- studs: monstro fictício do comando de teste

type Ativo = {
	inicio: number,
	folego: number,
	falso: number?, -- distância fixa do monstro fictício (comando de teste); nil = monstros de verdade
	falhou: boolean, -- o cliente já avisou o arfar (no máximo um por minigame)
	ultimaProximidade: number, -- os.clock() do último aviso de proximidade ao cliente
}
type Estado = { ativo: Ativo?, ultimoFim: number }

local estados: { [Player]: Estado } = {}

-- Outros serviços carregados sob demanda e em pcall (podem faltar; evita require circular).
local servicos: { [string]: any } = {}
local function servico(nome: string): any
	local s = servicos[nome]
	if s == nil then
		local arquivo = script.Parent:FindFirstChild(nome)
		local ok, modulo = false, nil
		if arquivo then
			ok, modulo = pcall(require, arquivo)
		end
		if ok and modulo then
			s = modulo
		else
			warn("[Respiracao] serviço indisponível: " .. nome .. " " .. tostring(modulo))
			s = false
		end
		servicos[nome] = s
	end
	return s or nil
end

local function estadoDe(jogador: Player): Estado
	local e = estados[jogador]
	if not e then
		e = { ativo = nil, ultimoFim = -math.huge }
		estados[jogador] = e
	end
	return e
end

local function estaminaDe(jogador: Player): number
	local e = jogador:GetAttribute("Estamina")
	return if type(e) == "number" then e else ESTAMINA_CHEIA
end

-- Monstro "em busca": Investiga, ou com a Busca do Rastejador ativa dentro de uma casa.
local function emBusca(d: any): boolean
	return d.perc.estado == "Investiga" or (d.hab ~= nil and d.hab.busca ~= nil)
end

-- Varre os monstros a <= raio: devolve a distância horizontal do mais perto em busca (nil se nenhum) e se algum já está em Caça/Ataque.
local function varrer(posicao: Vector3, raio: number): (number?, boolean)
	local Monstros = servico("Monstros")
	if not (Monstros and Monstros.proximos) then
		return nil, false
	end
	local melhor: number? = nil
	local cacando = false
	for _, d in Monstros.proximos(posicao, raio, Cfg.alturaMax) do
		if d.perc.estado == "Caca" or d.atacando then
			cacando = true
		elseif melhor == nil and emBusca(d) then
			local delta = d.hrp.Position - posicao
			melhor = Vector3.new(delta.X, 0, delta.Z).Magnitude
		end
	end
	return melhor, cacando
end

local function cabecaDe(jogador: Player, raiz: BasePart): Vector3
	local cabeca = jogador.Character and jogador.Character:FindFirstChild("Head")
	return if cabeca and cabeca:IsA("BasePart") then cabeca.Position else raiz.Position
end

local function raizDe(jogador: Player): (BasePart?, Humanoid?)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if raiz and raiz:IsA("BasePart") and humanoide then
		return raiz, humanoide
	end
	return nil, nil
end

local function modoDe(jogador: Player, raiz: BasePart): string
	local v = raiz.AssemblyLinearVelocity
	return Som.modoPasso(
		Vector3.new(v.X, 0, v.Z).Magnitude,
		jogador:GetAttribute("Agachado") == true,
		jogador:GetAttribute("Correndo") == true,
		jogador:GetAttribute("Deitado") == true
	)
end

-- Emite um som do próprio jogador na cabeça: bandas de uma camada única (nível + perfil).
local function emitir(
	jogador: Player,
	tipo: string,
	nivel: number,
	perfil: Som.Bandas,
	posicao: Vector3,
	somNome: string?
)
	local ruido = servico("Ruido")
	if not ruido then
		return
	end
	local c = Som.compor({ { nome = tipo, nivel = nivel, perfil = perfil } })
	ruido.emitirSom({ posicao = posicao, bandas = c.bandas, chao = c.chao, tipo = tipo, fonte = jogador })
	if somNome then
		Sons.tocar(somNome, posicao, { db = c.db })
	end
end

local function terminar(jogador: Player, motivo: string)
	local est = estados[jogador]
	local ativo = est and est.ativo
	if not (est and ativo) then
		return
	end
	est.ativo = nil
	est.ultimoFim = os.clock()
	jogador:SetAttribute("PrendendoRespiracao", false)
	Rede.evento("Respiracao"):FireClient(jogador, "fim", motivo)
	if motivo == "folego" then
		-- o fôlego acabou: solta o ar, baixo mas arriscado colado (perfil da camada de respiração do passo)
		local raiz = raizDe(jogador)
		if raiz then
			emitir(
				jogador,
				"respiracao",
				Cfg.soltarAr.db,
				CfgSom.passo.respiracaoPerfil,
				cabecaDe(jogador, raiz),
				"SoltarAr"
			)
		end
	end
end

local function iniciarMinigame(jogador: Player, distancia: number, falso: boolean)
	local est = estadoDe(jogador)
	local agora = os.clock()
	local estamina = estaminaDe(jogador)
	local ativo: Ativo = {
		inicio = agora,
		folego = R.folego(estamina, Cfg),
		falso = if falso then distancia else nil,
		falhou = false,
		ultimaProximidade = agora,
	}
	est.ativo = ativo
	jogador:SetAttribute("PrendendoRespiracao", true)
	Rede.evento("Respiracao"):FireClient(jogador, "iniciar", {
		duracao = ativo.folego,
		proximidade = R.proximidade(distancia, Cfg),
		estamina = estamina, -- o cliente acelera a zona com estamina baixa (regra pura)
	})
end

-- Um passo (Cfg.hz Hz) de um jogador: fecha o minigame ativo ou procura motivo para abrir um.
local function passo(jogador: Player)
	local est = estadoDe(jogador)
	local raiz, humanoide = raizDe(jogador)
	local vivo = raiz ~= nil and humanoide ~= nil and humanoide.Health > 0 and jogador:GetAttribute("Morto") ~= true
	if not (raiz and humanoide) or not vivo then
		if est.ativo then
			terminar(jogador, "morreu")
		end
		return
	end
	local agora = os.clock()
	local modo = modoDe(jogador, raiz)
	local emCarro = humanoide.SeatPart ~= nil
	local ativo = est.ativo

	if ativo then
		local distanciaBusca, cacando
		if ativo.falso then
			distanciaBusca, cacando = ativo.falso, false
		else
			distanciaBusca, cacando = varrer(raiz.Position, Cfg.raio + Cfg.saidaExtra)
		end
		local motivo = R.motivoFim({
			modo = modo,
			emCarro = emCarro,
			tempo = agora - ativo.inicio,
			folego = ativo.folego,
			distanciaBusca = distanciaBusca,
			cacando = cacando,
		}, Cfg)
		if motivo then
			terminar(jogador, motivo)
		elseif distanciaBusca and agora - ativo.ultimaProximidade >= Cfg.proximidadeCada then
			ativo.ultimaProximidade = agora
			Rede.evento("Respiracao"):FireClient(jogador, "proximidade", R.proximidade(distanciaBusca, Cfg))
		end
		return
	end

	-- quem anda ou corre já está fazendo barulho: nem procura monstro (poupa a varredura)
	if emCarro or not (modo == "parado" or modo == "agachado" or modo == "deitado") then
		return
	end
	if agora - est.ultimoFim < Cfg.recarga then
		return
	end
	local distancia, cacando = varrer(raiz.Position, Cfg.raio)
	if cacando then
		return -- ele já sabe onde você está
	end
	local abre = R.podeAbrir({
		vivo = true,
		emCarro = emCarro,
		ativo = false,
		desdeUltimo = agora - est.ultimoFim,
		modo = modo,
		distancia = distancia,
		dy = 0, -- Monstros.proximos já filtrou |Δy| <= alturaMax
	}, Cfg)
	if abre and distancia then
		iniciarMinigame(jogador, distancia, false)
	end
end

local function aoFalhar(jogador: Player)
	local est = estados[jogador]
	local ativo = est and est.ativo
	if not (est and ativo) or ativo.falhou then
		return
	end
	if os.clock() - ativo.inicio < Cfg.falhaAposMin then
		return
	end
	ativo.falhou = true
	local raiz = raizDe(jogador)
	if raiz then
		emitir(jogador, "arfar", Cfg.arfar.db, Cfg.arfar.perfil, cabecaDe(jogador, raiz), "Arfar")
	end
	local sobrevivencia = servico("Sobrevivencia")
	if sobrevivencia then
		sobrevivencia.alterar(jogador, "Estamina", -Cfg.arfar.estamina)
	end
	terminar(jogador, "arfou")
end

function Respiracao.ativo(jogador: Player): boolean
	local e = estados[jogador]
	return e ~= nil and e.ativo ~= nil
end

function Respiracao.iniciar()
	Rede.evento("RespiracaoFalhou").OnServerEvent:Connect(aoFalhar)
	Players.PlayerRemoving:Connect(function(jogador)
		estados[jogador] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1 / Cfg.hz)
			if Cfg.ligado then
				for _, jogador in Players:GetPlayers() do
					local ok, erro = pcall(passo, jogador)
					if not ok then
						warn("[Respiracao] erro no passo: " .. tostring(erro))
					end
				end
			end
		end
	end)

	-- Teste: abre o minigame para quem chamou, com um monstro fictício a 8 studs (na ZonaTeste, skill teste-no-void).
	-- Fica ativo até o fôlego acabar, o jogador andar ou errar. O fim "afastou"/"cacou" não acontece (o monstro é fictício).
	Teste.registrar("respiracao", function(jogador: Player)
		local raiz = raizDe(jogador)
		if not raiz then
			return "sem personagem"
		end
		if estadoDe(jogador).ativo then
			terminar(jogador, "moveu")
		end
		iniciarMinigame(jogador, DISTANCIA_TESTE, true)
		local ativo = estadoDe(jogador).ativo :: Ativo
		return string.format(
			"minigame aberto: monstro fictício a %d studs, proximidade %.2f, fôlego %.1f s",
			DISTANCIA_TESTE,
			R.proximidade(DISTANCIA_TESTE, Cfg),
			ativo.folego
		)
	end)
end

return Respiracao
