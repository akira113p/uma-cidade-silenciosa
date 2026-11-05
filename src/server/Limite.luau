-- Limite de frequência por jogador e por evento (Rede regra 3: o servidor limita tudo que chega).

local Limite = {}

local ultimos: { [Player]: { [string]: number } } = {}

function Limite.ok(jogador: Player, nome: string, intervalo: number): boolean
	local t = ultimos[jogador]
	if not t then
		t = {}
		ultimos[jogador] = t
	end
	local agora = os.clock()
	local antes = t[nome]
	if antes and agora - antes < intervalo then
		return false
	end
	t[nome] = agora
	return true
end

function Limite.limpar(jogador: Player)
	ultimos[jogador] = nil
end

return Limite
