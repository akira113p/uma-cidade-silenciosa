--!strict
-- Números dos itens no chão (docs/itens-no-mundo.md §3-B). PROVISÓRIO. Regras: Regras/ItensChao e Regras/Arremesso.
-- Tempos e alcance de interação vêm de Config/Itens (uma fonte só).

-- No Roblox o require é por instância; no Lune (testes) é por caminho relativo ao arquivo.
local function carregar(nome: string): any
	if typeof(script) == "Instance" then
		return require((script :: any).Parent:WaitForChild(nome))
	end
	return (require :: any)("./" .. nome)
end

local Itens: { reposicao: number, alcanceInteracao: number, bolsaDuracao: number } = carregar("Itens")

return {
	chanceSpawn = 0.35, -- chance de um ponto Loot gerar item na partida
	alcance = Itens.alcanceInteracao, -- studs entre o jogador e o item (fonte: Config/Itens)
	raioMira = 1.4, -- studs: distância máxima do item ao raio da mira
	maxItens = 600, -- itens vivos em workspace.ItensChao; passando disso some o largado mais antigo
	largadoDuracao = Itens.bolsaDuracao, -- s até item largado/de morte sumir
	reposicao = Itens.reposicao, -- s para o ponto sortear de novo depois de pego
	alturaCastPonto = 3, -- studs: raio para baixo a partir do ponto Loot para achar o piso

	-- Arremesso ao largar (studs, s, rad/s). gravidade vem do workspace.Gravity no servidor.
	arremesso = { frente = 12, cima = 6, giroMax = 8, passo = 1 / 30, maxPassos = 90, restituicao = 0 },

	-- Morte: itens saem em leque; velocidade horizontal = raio × 2, vertical = cima.
	espalhar = { raioMin = 1.5, raioMax = 4, cima = 7 },
}
