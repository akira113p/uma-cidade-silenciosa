--!strict
-- Sinais locais entre os módulos de arma do cliente (docs/armas.md §6.3). Quem ATUA dispara; quem MOSTRA escuta.
-- Dono: ArmasCliente dispara; ArmasViewmodel, ArmasTerceira e EfeitosArma escutam. Não guarda estado de jogo.

export type Ouvinte = (...any) -> ()

local ArmasSinais = {}

local ouvintes: { [string]: { Ouvinte } } = {}

-- Nomes usados:
--   "disparou"    (armaId: string, origem: Vector3, direcao: Vector3)   tiro local aceito pelo cliente (previsão)
--   "golpeou"     (armaId: string)                                      início do golpe corpo a corpo local
--   "vazio"       (armaId: string)                                      gatilho sem munição
--   "recarregou"  (armaId: string, duracao: number)                     início da recarga (duração total em s)
--   "recargaFim"  (armaId: string, cancelada: boolean)
--   "equipou"     (armaId: string?)                                     nil = desarmou
function ArmasSinais.ouvir(nome: string, fn: Ouvinte): () -> ()
	local lista = ouvintes[nome]
	if not lista then
		lista = {}
		ouvintes[nome] = lista
	end
	table.insert(lista, fn)
	return function()
		local i = table.find(lista, fn)
		if i then
			table.remove(lista, i)
		end
	end
end

function ArmasSinais.disparar(nome: string, ...: any)
	local lista = ouvintes[nome]
	if not lista then
		return
	end
	for _, fn in table.clone(lista) do
		task.spawn(fn, ...)
	end
end

return ArmasSinais
