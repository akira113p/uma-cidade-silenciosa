---
name: som-roblox
description: Sons do jogo Roblox a partir de uma biblioteca já classificada (explosão, golpe, UI, moeda, passo, magia, ambiente), combinando camadas em vez de gerar ou subir áudio novo. Use para adicionar, trocar ou ajustar qualquer som/feedback sonoro do jogo.
---

# Som

O upload de áudio no Roblox tem **cota mensal**, e cada arquivo passa por moderação. Gerar áudio com IA e subir um por um não escala. Por isso o fluxo do vídeo usa uma biblioteca de sons já disponíveis, classificados por nome, e combina camadas (ex.: explosão = estouro grave + estilhaço + cauda de fumaça).

## Biblioteca
1. Colher com o mesmo script da VFX: `execute_luau` com `.claude/skills/vfx-roblox/scripts/colher.luau` sobre `workspace.Colheita` (a parte `sons` do JSON), ou buscar direto com `search_asset` (áudio da Creator Store).
2. Ouvir não é possível para Claude. A classificação vem do nome, da duração e da origem. **O usuário confirma cada som por categoria** antes de entrar na biblioteca.
3. Gravar em `assets/som/biblioteca.json`: `{ nome, categoria, SoundId, Duracao, Volume, PlaybackSpeed, origem, confirmado }`.
4. Só usar áudio que a conta pode usar no jogo (público na Creator Store ou do próprio usuário). Áudio privado de terceiros fica mudo no jogo.

## Usar no jogo
- Catálogo em `src/shared/Config/Sons.luau`: nome lógico → uma ou mais camadas `{ id, volume, pitch, atraso }`. O código toca **nomes lógicos** ("Coleta", "CompraOk"), nunca IDs soltos.
- `SoundGroup` por categoria (Efeitos, UI, Música, Ambiente) para o jogador ajustar volume.
- Variação: pitch aleatório ±5% em sons repetidos (passos, moedas), para não soar robótico.
- Feedback de UI (clique, compra, erro) sempre com som. É barato e muda a sensação do jogo.

## Armadilhas
- Classificar só pelo nome engana ("fire" pode ser tiro ou fogo). Por isso o campo `confirmado` existe e só som confirmado vai para o catálogo.
