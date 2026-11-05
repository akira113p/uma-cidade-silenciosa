---
name: mapa-roblox
description: Construir e validar mapas do jogo Roblox - mapa como espaço jogável (dá para chegar? dá para voltar? peça solta? peça enfiada? queda grande demais?) medido com os números reais de movimento do jogo, e com visual de meshes em vez de pilha de Parts. Use ao criar, mudar ou revisar qualquer mapa, fase, obby, área ou cenário.
---

# Mapa

Um mapa é um espaço por onde o jogador anda, e não uma pilha de peças. As perguntas que importam têm resposta certa e são mensuráveis: dá para chegar lá, dá para voltar, quanto se cai. **Todo número vem do jogo, com a fonte anotada; todo chute aparece no relatório.**

## Estrutura no Studio
- Todo o mapa dentro de `workspace.Mapa` (o checker olha só ali).
- Ao menos uma `SpawnLocation` dentro do mapa.
- Números de movimento em `ReplicatedStorage.Shared.Config.Movimento` (`velocidade`, `alturaPulo`, `quedaMax`). Sem isso, o checker usa `StarterPlayer.CharacterWalkSpeed`/`CharacterJumpHeight`. O código do jogo **aplica os mesmos valores** ao Humanoid: uma fonte só.
- Tags (CollectionService) para intenção: `Decoracao` (ignorar), `Objetivo` (precisa ser alcançável), `ForaDeAlcance` (não pode ser), `SemSaidaOk` (beco sem saída proposital).

## Checar
Pelo MCP: `execute_luau` (datamodel `Edit`) com o conteúdo de [scripts/checar_mapa.luau](scripts/checar_mapa.luau). Ele devolve um JSON com:
| Regra | O quê |
|---|---|
| SOLTA | peça não ancorada e sem junta: cai ao dar play |
| SPAWN | sem SpawnLocation pisável |
| SEM_SAIDA | dá para chegar e não dá para voltar ao spawn |
| ALCANCE_INDEVIDO | peça `ForaDeAlcance` alcançável |
| INALCANCAVEL | `Objetivo` inalcançável (falha) ou chão alto que ninguém alcança (aviso) |
| ENFIADA | peças se atravessando (aviso) |
| QUEDA | queda maior que `quedaMax` (aviso) |

Física do pulo: v0 = √(2·g·h); tempo até a altura do alvo = (v0 + √(v0² − 2·g·Δy))/g; alcance = velocidade × tempo. Tudo com margem de 90%.

Depois do checker, **olhar**: `screen_capture` de cima e da altura dos olhos em cada área (linhas de visão, espaçamento, leitura do caminho). Em playtest, `start_stop_play` + `character_navigation` até os pontos críticos + `get_console_output` confirma o que o grafo previu.

## Visual
- Peças de cenário são **meshes** (skill `modelo-3d-roblox`: módulos em grade de 0,5/1 m com a mesma paleta), não Parts cruas. Parts só para colisão invisível (`Transparency = 1`) e blocagem.
- Para seguir o estilo de um jogo de referência: o usuário passa screenshots, Claude anota paleta, formas, densidade de detalhe e iluminação em `docs/estilo-mapa.md`, e os módulos seguem esse documento.
- Iluminação/atmosfera: skill `roblox-lighting`.
- Orçamento: cada mesh ≤ 20 000 tris (o exportador já barra); reaproveitar a mesma mesh em vez de variações quase iguais.

## Armadilhas
- Checker validado no Studio em 2026-10-12 (75 peças, retorno JSON ok, `GetPartsInPart` funciona em Edit). Peça com `ForaDeAlcance` não gera mais aviso INALCANCAVEL (é o esperado dela).
- Blockout gerado por código (`ferramentas/gerar_mapa.luau`, Lune → `.rbxm` sincronizado pelo Rojo): paredes no eixo Z perdem meia espessura em cada ponta para não se atravessarem nos cantos; parede mais alta que o pulo ganha `ForaDeAlcance`.
- Borda de 6 studs com pulo de 7.2: dava para subir e cair para fora do mapa. Toda borda externa fica acima de `Movimento.alturaPulo`.
- Placa/letreiro no meio do caminho fica na frente da câmera (da luta e da terceira pessoa): placas vão encostadas em parede ou acima da cerca do fundo.
- Luau não compara Instances com `<`: usar `GetFullName()` para chaves de pares.
- Padrão visual do projeto (2026-10-12): `Texture` nas faces (Top no chão, 4 laterais na parede) com a textura do Baseplate (`rbxassetid://6372755229`) a 78% de transparência para o quadriculado ficar sutil; a 60% ficou forte demais. No Lune, `Texture.Texture` só aceita string (`Content.fromUri` dá erro de conversão).
- Cerca de peças soltas (pilares, trilhos, X) se tocam de propósito: marcar tudo `Decoracao` para o checker de mapa não encher o relatório de ENFIADA. A colisão continua valendo.
- Paredes por bioma em segmentos colineares: o recuo de meia espessura nas pontas (para não atravessar o canto) só vale onde há parede perpendicular; entre segmentos use recuo 0, senão sobra um vão de 2 studs.

