--!strict
-- Toda mensagem cliente<->servidor é declarada AQUI. Nenhum outro arquivo cria RemoteEvent/RemoteFunction.
-- O servidor valida tudo que chega (tipo, faixa, estado do jogador) e limita a frequência (server/Limite.luau).
-- Dono de cada evento: docs/arquitetura.md, seção "Rede".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTOS: { string } = {
	-- cliente -> servidor
	"Agachar", -- (ligado: boolean)                                  Movimento
	"Correr", -- (ligado: boolean)                                   Movimento
	"SalvarPreferencias", -- (prefs: {[string]: any})                Preferencias
	"Voz", -- (dbVoz: number) nível da voz no microfone, 4 Hz máx.   Ruido
	"Equipar", -- (slot: number?) nil = mãos vazias                  Armas
	"Atacar", -- (origem: Vector3, direcao: Vector3)                 Armas
	"Recarregar", -- ()  R; o servidor valida arma de fogo, pente < capacidade, reserva > 0     Armas
	"Mira", -- (pitch: number) graus, 8 Hz máx.; servidor valida número finito e limita a ±80     Armas
	"UsarItem", -- (slot: number)                                    Inventario
	"LargarItem", -- (slot: number)                                  Inventario
	"AbrirCaixa", -- (caixa: BasePart)                               Loot
	"PegarItem", -- (container: Instance, indice: number)            Loot
	"PegarDoChao", -- (item: Instance) item solto em workspace.ItensChao; o servidor confere alcance, vida e espaço   ItensChao
	"Lanterna", -- (ligada: boolean) liga/apaga a lanterna equipada       Lanterna
	"LigarMotor", -- ()  só o motorista; liga/tenta ligar o motor                  Veiculos
	"Buzina", -- ()  só o motorista                                                 Veiculos
	"SairCarro", -- c→s: pede para sair. s→c: (cf: CFrame) onde pôr o personagem   Veiculos
	"TrocarBanco", -- ()  passageiro/motorista pede o próximo banco livre do carro (tecla F, Limite 0,4 s)   Veiculos
	"Admin", -- (acao: string, arg: any) menu de admin (tecla O); o servidor confere quem é dono   Admin
	-- servidor -> cliente
	"MeuRuido", -- (db: number, ambiente: number, alcance: number) último ruído do próprio jogador   Ruido
	"RuidoDebug", -- (posicao: Vector3, alcance: number, db: number) só no Studio, para todos   Ruido
	"Dano", -- (parte: string, valor: number, direcao: Vector3?) tremor/flash no cliente   Vida
	"Inventario", -- (itens: {{id: string, qtd: number}}, equipado: number?)   Inventario
	"ConteudoCaixa", -- (container: Instance, itens: {{id: string, qtd: number}})   Loot
	"Acerto", -- (alvoEhJogador: boolean, parte: string?) marcador de acerto   Armas
	"Disparo", -- (atirador: Player, armaId: string, origem: Vector3, fim: Vector3) clarão/rastro para quem está perto, menos o atirador   Armas
	"Explosao", -- (posicao: Vector3, raio: number) efeito + tremor por distância (foguete)   Armas (Foguete)
	"Aviso", -- (texto: string) mensagem curta no centro inferior   qualquer serviço
	"Morreu", -- (causa: string) tela de morte   Vida
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
