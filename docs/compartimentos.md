# Compartimentos — móveis do mapa como loot (substitui a caixa de madeira)

Pedido do usuário (2026-11-02): a `Caixa` solta no chão sai. O loot passa a morar nos **móveis do mapa** (`Model` com atributo
`Movel` dentro de `workspace.Mapa.Construcoes`), em **categorias**: geladeira dá comida, criado-mudo tem mais chance de arma que
o lavatório do banheiro, etc. O código (ProximityPrompt + estado) fica **dentro do móvel**, criado pelo servidor.

## Contrato de dados — `src/shared/Config/Compartimentos/`
`init.luau` junta `Casa.luau` e `Comercial.luau` (erro se categoria ou móvel repetir) e devolve `{ tabelas, moveis }`.
Cada um dos dois arquivos devolve:

```lua
return {
	-- categoria → tabela de loot, MESMO formato de Itens.tabelas: { rolagens = {min, max}, itens = { {id, peso, qtd = {min, max}} } }
	-- rolagens pode começar em 0 (móvel pode estar vazio). `id` tem de existir em Config/Itens.itens.
	tabelas = { comida_casa = { rolagens = { 1, 3 }, itens = { ... } }, ... },
	-- nome do móvel (chave de ferramentas/mapa/mobilia_tamanhos.luau) → compartimento
	moveis = { geladeira = { categoria = "comida_casa", nome = "Geladeira", chance = 0.9 }, ... },
}
```
- `chance` (0–1): probabilidade de **aquela instância** ser compartimento (decidida uma vez no início; as demais ficam sem prompt).
  É o botão de densidade: o mapa tem ~3200 móveis; alvo total de ~1000–1500 compartimentos (a caixa antiga eram 880).
- `nome`: texto do prompt ("Geladeira"). Móvel que não aparece em `moveis` é cenário puro.
- Itens existentes: enlatado, barra, agua, refrigerante, bandagem, kit, faca, peDeCabra, machado, pistola, municaoPistola.
  Armas = faca, peDeCabra, machado, pistola (e municaoPistola). **Não inventar itens.**
- Regra de design: a chance de arma depende do cômodo. Quarto (criado_mudo, guarda_roupa, comoda) > banheiro (≈ 0). Armário de
  armas/estante de armas/caixa de munição: alto. Geladeira/despensa: só comida e bebida. Hospital: cura. Oficina/garagem/
  indústria: ferramentas (peDeCabra, machado), pouca bandagem.

## Servidor — `src/server/Loot.luau`
Ao iniciar, varre `workspace.Mapa.Construcoes` (espera o mapa), e para cada `Model` com `Movel` presente em `Compartimentos.moveis`
sorteia (`chance`) e cria o compartimento: **container = a peça principal do móvel** (`PrimaryPart`, senão a de maior volume),
com um `ProximityPrompt` (E, "Abrir", `ObjectText = nome`) dentro dela e atributos `Compartimento = categoria`, `Nome = nome`.
O conteúdo é sorteado **na primeira abertura** (preguiçoso), com `RegrasLoot.sortear(Compartimentos.tabelas[categoria])`.
Abrir/Pegar/reposição seguem iguais à caixa antiga (`AbrirCaixa`, `PegarItem`, `ConteudoCaixa`, `Itens.reposicao`).
`workspace.Mapa.Pontos` com nome `Loot` e a Part "Caixa" **deixam de ser usados** (os pontos continuam no gerador; ignorados).

## Cliente — `src/client/InventarioUI.luau`
Título do painel = atributo `Nome` do container (senão "Bolsa" se `Bolsa`, senão "Caixa").
