--!strict
-- Regras puras das raízes de construção (docs/destruicao.md): quais pastas valem como "mapa" para destruição, atenuação de
-- ruído e arrombamento. Sem Instance: quem toca o Workspace é Shared/Raizes.luau.

local Raizes = {}

-- Pais em ordem: o mapa de verdade primeiro, depois a zona de teste no void (skill teste-no-void). Cada pai pode ter
-- Construcoes e Props.
Raizes.PAIS = { "Mapa", "ZonaTeste" }

-- Raízes válidas para `nome` ("Construcoes" | "Props"). `achar(pai, nome)` devolve a raiz ou nil (pai ou pasta ausente).
-- Pai que não existe é só ignorado: sem ZonaTeste, o resultado é o mesmo de antes (só Mapa.<nome>).
function Raizes.coletar(nome: string, achar: (string, string) -> any?): { any }
	local lista: { any } = {}
	for _, pai in Raizes.PAIS do
		local raiz = achar(pai, nome)
		if raiz ~= nil then
			table.insert(lista, raiz)
		end
	end
	return lista
end

-- Mesma lista, mesma ordem? (para só refazer o filtro do raycast quando uma pasta surge, some ou é trocada)
function Raizes.iguais(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for i, x in a do
		if b[i] ~= x then
			return false
		end
	end
	return true
end

return Raizes
