-- Valida os clipes de corpo (assets/animacoes/corpo/*.json) e imprime a folha de quadros (ângulos por tempo) para a revisão.
-- Confere: junta/peça do R15, pose existente, duração = último quadro (1e-4), tempos crescentes, limites angulares plausíveis
-- (ombro, cotovelo, joelho...), pernas proibidas em carro/mão, laço sem pulo. Sai com código 1 se algo falhar.
-- Uso (da raiz):  lune run ferramentas/animacao/validar_corpo.luau [-- grupo[/Clipe]] [--resumo]
--   sem argumento: todos os grupos, folha completa;  --resumo: só uma linha por clipe;  vida/Morte: só esse clipe.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Regra = require("../../src/shared/Regras/Animacao")

local PASTA = "assets/animacoes/corpo"
local SEM_PERNAS: { [string]: boolean } = { carro = true, mao = true }

local filtroGrupo: string? = nil
local filtroClipe: string? = nil
local resumo = false
for _, a in process.args do
	if a == "--resumo" then
		resumo = true
	else
		local g, c = string.match(a, "^([%w_]+)/?([%w_]*)$")
		filtroGrupo = g
		filtroClipe = if c ~= "" then c else nil
	end
end

local falhas = 0
local grupos: { string } = {}
for _, arq in fs.readDir(PASTA) do
	local g = string.match(arq, "^(.+)%.json$")
	if g then
		table.insert(grupos, g)
	end
end
table.sort(grupos)

for _, grupo in grupos do
	if filtroGrupo and filtroGrupo ~= grupo then
		continue
	end
	local arq = serde.decode("json", fs.readFile(`{PASTA}/{grupo}.json`))
	local nomes: { string } = {}
	for n in arq.clipes do
		table.insert(nomes, n)
	end
	table.sort(nomes)
	print(`== corpo/{grupo}  ({#nomes} clipes)`)
	for _, nome in nomes do
		if filtroClipe and filtroClipe ~= nome then
			continue
		end
		local erros = Regra.validarClipe(arq, nome, { proibidas = if SEM_PERNAS[grupo] then Regra.PERNAS else nil })
		local clipe = arq.clipes[nome]
		if #erros > 0 then
			falhas += #erros
			print(`FALHOU corpo/{grupo}/{nome}`)
			for _, e in erros do
				print("   - " .. e)
			end
		elseif resumo then
			print(`ok  {nome}: {#clipe.quadros} quadros, {clipe.duracao}s, loop={tostring(clipe.loop == true)}, {clipe.prioridade}`)
		else
			print(Regra.folha(arq, nome))
			print("")
		end
	end
end

if falhas > 0 then
	print(`\n{falhas} problema(s).`)
	process.exit(1)
end
print("\nvalidar_corpo ok")
