--!strict
-- Regra pura: sem game, sem Instance, sem require. Roda no Roblox e no Lune (testes).

local Pulo = {}

-- Distância horizontal máxima de um pulo que termina `subida` studs acima (negativo = abaixo) do ponto de saída.
-- Retorna nil se a subida é maior que a altura do pulo.
function Pulo.alcance(velocidade: number, alturaPulo: number, gravidade: number, subida: number): number?
	if subida > alturaPulo then
		return nil
	end
	local v0 = math.sqrt(2 * gravidade * alturaPulo)
	local tempo = (v0 + math.sqrt(v0 * v0 - 2 * gravidade * subida)) / gravidade
	return velocidade * tempo
end

return Pulo
