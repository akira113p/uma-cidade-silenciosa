--!strict
-- Regras puras do seletor de personagem (sem Roblox): quem chama passa o elenco (Config/Personagens.lista).
-- Dono: parte S (docs/personagens.md). Nenhuma função muta a entrada.

local Personagens = {}

export type Entrada = {
	id: string,
	n: number,
	nome: string,
	descricao: string,
	visual: string,
	estilo: { [string]: any },
	paleta: { [string]: { number } },
	fonte: { origem: string, licenca: string, credito: string | boolean },
	ordem: number,
}

export type EstadoEscolha = {
	escolheu: boolean, -- já escolheu um personagem alguma vez nesta sessão
	temPersonagem: boolean,
	morto: boolean,
	carregando: boolean, -- uma escolha/respawn já está em andamento
}

export type EstadoRespawn = {
	presente: boolean, -- o jogador ainda está no servidor
	fichaAgendada: number, -- número do personagem que morreu e agendou o respawn
	fichaAtual: number, -- número do personagem atual
	escolheu: boolean,
	carregando: boolean,
	escolhendo: boolean, -- com o seletor aberto (e dentro do prazo)
}

function Personagens.porN(lista: { Entrada }, n: unknown): Entrada?
	if type(n) ~= "number" then
		return nil
	end
	for _, e in lista do
		if e.n == n then
			return e
		end
	end
	return nil
end

function Personagens.porId(lista: { Entrada }, id: unknown): Entrada?
	if type(id) ~= "string" then
		return nil
	end
	for _, e in lista do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- O servidor nunca confia no cliente: só um número inteiro finito que exista no elenco vale.
function Personagens.validarEscolha(lista: { Entrada }, n: unknown): Entrada?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge or n ~= math.floor(n) then
		return nil
	end
	return Personagens.porN(lista, n)
end

-- id desconhecido, ausente ou de outro tipo = o padrão.
function Personagens.idEfetivo(lista: { Entrada }, id: unknown, padrao: string): string
	local e = Personagens.porId(lista, id)
	if e then
		return e.id
	end
	return padrao
end

-- Cópia ordenada por `ordem` (desempate por n).
function Personagens.ordenar(lista: { Entrada }): { Entrada }
	local copia = table.clone(lista)
	table.sort(copia, function(a, b)
		if a.ordem ~= b.ordem then
			return a.ordem < b.ordem
		end
		return a.n < b.n
	end)
	return copia
end

-- Número que o seletor abre marcado: a escolha salva se ainda existir, senão o padrão.
function Personagens.nInicial(lista: { Entrada }, salvo: unknown, padrao: string): number
	local e = Personagens.validarEscolha(lista, salvo)
	if e then
		return e.n
	end
	local p = Personagens.porId(lista, padrao)
	if p then
		return p.n
	end
	return lista[1] and lista[1].n or 1
end

-- Posição vizinha em `total` itens, dando a volta (teclado/gamepad no seletor). indice e resultado vão de 1 a total.
function Personagens.vizinho(total: number, indice: number, passo: number): number
	if total <= 0 then
		return 1
	end
	return (indice - 1 + passo) % total + 1
end

-- Pode escolher agora? Segunda resposta = motivo (texto para o jogador).
function Personagens.podeEscolher(e: EstadoEscolha): (boolean, string?)
	if e.carregando then
		return false, "Aguarde um instante."
	end
	if not e.escolheu or not e.temPersonagem or e.morto then
		return true, nil
	end
	return false, "Só dá para trocar de personagem depois de morrer."
end

-- O que fazer quando o tempo de reaparecer acaba:
--  "cancelar"  = outro personagem já nasceu / o jogador saiu / nunca escolheu / já está carregando (evita respawn dobrado);
--  "esperar"   = o jogador está no seletor (reaparece quando fechar);
--  "reaparecer".
function Personagens.decidirRespawn(e: EstadoRespawn): "reaparecer" | "esperar" | "cancelar"
	if not e.presente or e.fichaAgendada ~= e.fichaAtual or not e.escolheu or e.carregando then
		return "cancelar"
	end
	if e.escolhendo then
		return "esperar"
	end
	return "reaparecer"
end

local function tresNumeros(t: any): boolean
	return type(t) == "table" and type(t[1]) == "number" and type(t[2]) == "number" and type(t[3]) == "number"
end

-- Malhas completas = modelo, textura, alturaTotalStuds > 0 e todas as `partes` (nomes R15) com meshId texto,
-- tamanhoNativo e centroMontagem de 3 números (o visual escala o conjunto por alturaTotalStuds e posiciona pelo centro).
function Personagens.malhasCompletas(malha: any, partes: { string }): boolean
	if type(malha) ~= "table" or type(malha.modelo) ~= "string" or type(malha.textura) ~= "string" then
		return false
	end
	local dadas = malha.partes
	if type(dadas) ~= "table" or type(malha.alturaTotalStuds) ~= "number" or malha.alturaTotalStuds <= 0 then
		return false
	end
	for _, nome in partes do
		local p = dadas[nome]
		if type(p) ~= "table" or type(p.meshId) ~= "string" or p.meshId == "" then
			return false
		end
		if not tresNumeros(p.tamanhoNativo) or not tresNumeros(p.centroMontagem) then
			return false
		end
	end
	return true
end

-- "malhas" só se o personagem pede e as malhas estão completas; senão "bloco".
function Personagens.visualEfetivo(entrada: Entrada, malha: any, partes: { string }): "bloco" | "malhas"
	if entrada.visual == "malhas" and Personagens.malhasCompletas(malha, partes) then
		return "malhas"
	end
	return "bloco"
end

-- Cores base + as do personagem (cada cor { r, g, b }); devolve uma tabela nova.
function Personagens.paleta(base: { [string]: { number } }, entrada: Entrada): { [string]: { number } }
	local resultado = table.clone(base)
	for chave, cor in entrada.paleta do
		resultado[chave] = cor
	end
	return resultado
end

-- Créditos sem repetição, na ordem do elenco (rodapé do seletor).
function Personagens.creditos(lista: { Entrada }): { string }
	local vistos: { [string]: boolean } = {}
	local saida: { string } = {}
	for _, e in Personagens.ordenar(lista) do
		local c = e.fonte.credito
		if type(c) == "string" and c ~= "" and not vistos[c] then
			vistos[c] = true
			table.insert(saida, c)
		end
	end
	return saida
end

return Personagens
