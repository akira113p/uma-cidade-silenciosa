--!strict
-- Raízes de construção válidas AGORA: Workspace.Mapa.<nome> e, se existir, Workspace.ZonaTeste.<nome>.
-- Sem cache: cada chamada relê o Workspace (FindFirstChild), então a ZonaTeste pode surgir ou sumir durante o jogo.
-- Quem guarda a lista (filtro de raycast) compara com Raizes.iguais e só refaz quando mudou.
local Regras = require(script.Parent.Regras.Raizes)

local Raizes = {}

Raizes.iguais = Regras.iguais

local function achar(pai: string, nome: string): Instance?
	local p = workspace:FindFirstChild(pai)
	return p and p:FindFirstChild(nome)
end

-- nome: "Construcoes" (paredes, móveis) ou "Props" (postes, carcaças...).
function Raizes.obter(nome: string): { Instance }
	return Regras.coletar(nome, achar) :: { Instance }
end

return Raizes
