--!strict
-- Toda mensagem cliente<->servidor é declarada AQUI. Nenhum outro arquivo cria RemoteEvent/RemoteFunction.
-- O servidor valida tudo que chega (tipo, faixa, estado do jogador) e limita a frequência (server/Limite.luau).
-- Dono de cada evento: docs/arquitetura.md, seção "Rede".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTOS: { string } = {
	-- cliente -> servidor
	"Agachar", -- (ligado: boolean)                                  Movimento
	"Deitar", -- (ligado: boolean)                                   Movimento (segurar a tecla de agachar)
	"Correr", -- (ligado: boolean)                                   Movimento
	"Mirar", -- (ligado: boolean) botão direito com arma de fogo; o servidor grava Player.Mirando   Armas
	"SalvarPreferencias", -- (prefs: {[string]: any})                Preferencias
	"RespiracaoFalhou", -- ()  o minigame de segurar a respiração encheu a tensão (arfou); o servidor só aceita com minigame ativo, 1 por minigame, depois de 0,3 s   Respiracao
	"Voz", -- (dbVoz: number) nível da voz no microfone, 4 Hz máx.   Ruido
	"Equipar", -- (slot: number?) nil = mãos vazias                  Armas
	"Atacar", -- (origem: Vector3, direcao: Vector3)                 Armas
	"Recarregar", -- ()  R; o servidor valida arma de fogo, pente < capacidade, reserva > 0; R de novo DURANTE a recarga = recarga rápida/falha   Armas
	"Engatilhar", -- ()  Q; engatilha (bomba, recarga vazia) ou destrava a pane; o servidor valida e conta o tempo     Armas
	"Mira", -- (pitch: number) graus, 8 Hz máx.; servidor valida número finito e limita a ±80     Armas
	"UsarItem", -- (slot: number)                                    Inventario
	"LargarItem", -- (slot: number)                                  Inventario
	"AbrirCaixa", -- (caixa: BasePart)                               Loot
	"PegarItem", -- (container: Instance, indice: number)            Loot
	"PegarDoChao", -- (item: Instance) item solto em workspace.ItensChao; o servidor confere alcance, vida e espaço   ItensChao
	"Lanterna", -- (ligada: boolean) liga/apaga a lanterna equipada       Lanterna
	"LigarMotor", -- ()  só o motorista; liga/tenta ligar o motor                  Veiculos
	"Buzina", -- ()  só o motorista                                                 Veiculos
	"CarregarCarro", -- ()  com a mangueira na mão: pluga na tampa mais próxima (ou despluga se já plugada); botão/tecla G a pé   Combustivel
	"Farol", -- ()  só o motorista; liga/apaga os faróis do carro (tecla L, Limite 0,25 s)   Veiculos
	"SairCarro", -- c→s: pede para sair. s→c: (cf: CFrame) onde pôr o personagem   Veiculos
	"TrocarBanco", -- ()  passageiro/motorista pede o próximo banco livre do carro (tecla F, Limite 0,4 s)   Veiculos
	"Admin", -- (acao: string, arg: any) menu de admin (tecla O); o servidor confere quem é dono   Admin
	"EscolherPersonagem", -- (n: number) número do personagem em Config/Personagens; o servidor valida inteiro do elenco, Limite, estado   Personagem
	"SeletorEstado", -- (aberto: boolean) o jogador abriu/fechou o seletor (segura o respawn automático enquanto escolhe)   Personagem
	-- servidor -> cliente
	"MeuRuido", -- (db: number, ambiente: number, alcance: number, rotulo: string?) último ruído do próprio jogador; rotulo = chave de Config/Som.medidor.rotulos (dominante ou tipo)   Ruido
	"RuidoDebug", -- (posicao: Vector3, alcance: number, db: number, banda: string) só no Studio, para todos; banda = "grave" | "medio" | "agudo" | "chao"   Ruido
	"Respiracao", -- ("iniciar", {duracao, proximidade}) | ("proximidade", n) | ("fim", motivo)  minigame de segurar a respiração (docs/som.md §13.4)   Respiracao
	"Dano", -- (parte: string, valor: number, direcao: Vector3?) tremor/flash no cliente   Vida
	"Inventario", -- (itens: {{id: string, qtd: number}}, equipado: number?)   Inventario
	"ConteudoCaixa", -- (container: Instance, itens: {{id: string, qtd: number}})   Loot
	"Acerto", -- (alvoEhJogador: boolean, parte: string?) marcador de acerto   Armas
	"Disparo", -- (atirador: Player, armaId: string, origem: Vector3, fim: Vector3) clarão/rastro para quem está perto, menos o atirador   Armas
	"Explosao", -- (posicao: Vector3, raio: number) efeito + tremor por distância (foguete)   Armas (Foguete)
	"Aviso", -- (texto: string) mensagem curta no centro inferior   qualquer serviço
	"Morreu", -- (causa: string) tela de morte   Vida
	"AbrirSeletor", -- (nSalvo: number) abre o seletor de personagem (preferências já carregadas; nSalvo = último escolhido)   Personagem
	"PersonagemEscolhido", -- (ok: boolean, n: number?, texto: string?) resposta a EscolherPersonagem: ok fecha o seletor, senão texto = motivo   Personagem
	-- monstros (docs/monstros/logica.md §2.7; o servidor dispara pelo nome)
	"MonstroSonar", -- (origem: Vector3, raio: number, velocidade: number, id: number) onda visível do sonar (clientes a ≤ 120 studs)   Monstros
	"SonarAtingido", -- (id: number, detectado: boolean) só o jogador: a onda o alcançou; false = havia cobertura   Monstros
	"Impulso", -- (vetor: Vector3) só o jogador: soma o vetor à velocidade do HumanoidRootPart (empurrão de monstro; o personagem é simulado pelo cliente)   Movimento/Monstros
	"Tremor", -- (intensidade: number, duracao: number) tremor de câmera (rugido etc.); respeita Pref_Tremor   Monstros
}

local Rede = {}

local function pasta(): Instance
	if RunService:IsServer() then
		local existente = ReplicatedStorage:FindFirstChild("Rede")
		if existente then
			return existente
		end
		local nova = Instance.new("Folder")
		nova.Name = "Rede"
		nova.Parent = ReplicatedStorage
		return nova
	end
	return ReplicatedStorage:WaitForChild("Rede")
end

function Rede.evento(nome: string): RemoteEvent
	assert(table.find(EVENTOS, nome), "Rede: evento não declarado em Rede.luau: " .. nome)
	local raiz = pasta()
	local existente = raiz:FindFirstChild(nome)
	if existente and existente:IsA("RemoteEvent") then
		return existente
	end
	if RunService:IsServer() then
		local novo = Instance.new("RemoteEvent")
		novo.Name = nome
		novo.Parent = raiz
		return novo
	end
	return raiz:WaitForChild(nome) :: RemoteEvent
end

-- Servidor chama no início para criar todos os eventos antes de os clientes pedirem.
function Rede.criarTodos()
	assert(RunService:IsServer(), "Rede.criarTodos só no servidor")
	for _, nome in EVENTOS do
		Rede.evento(nome)
	end
end

return Rede
