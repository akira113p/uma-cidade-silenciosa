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
--   "engatilhou"  (armaId: string, tempo: number, destravar: boolean)   Q aceito localmente: bombear/engatilhar ou destravar a pane
--   "bloqueado"   (armaId: string, motivo: string)                      gatilho recusado: "travada" | "desengatilhada" (junto de "vazio")
--   "checou"      (armaId: string, duracao: number)                     Z: animação de checar a munição; HudMunicao mostra as frases
--   "recargaRapida" (armaId: string, duracaoNova: number)               R de novo na janela certa: a recarga termina antes
--   "recargaFalhou" (armaId: string, duracaoNova: number)               R de novo fora da janela: a recarga demora mais
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
