---
name: modelo-3d-roblox
description: Pipeline de modelos 3D para o jogo Roblox - escolhe o caminho (Blender por primitivas, referência→modelo, malha densa→reduzir+bake, gerado no Studio, Creator Store), valida contra os limites do Roblox (20k tris/mesh, textura 1024) e exporta FBX + manifesto com o tamanho em studs. Use para qualquer pedido de modelo, prop, arma, construção, estátua ou mesh para o jogo.
---

# Modelo 3D para Roblox

Mapa e objetos do jogo são **meshes**, não pilhas de Parts (no vídeo base, é isso que separa um jogo feito por IA que "parece IA" de um que não parece). Toda peça passa por: **brief → construir → olhar → portões → exportar → importar → conferir no Studio**.

Blender: `BLENDER_EXE` está em `.claude/settings.json` (Blender 5.2 da Steam). Rodar scripts headless com
`python .claude/skills/blender-lpm-skill/scripts/bl.py --script <arquivo.py> -- <args>`.
O MCP `blender` (oficial do Blender Lab) serve para inspecionar/ajustar ao vivo; a construção fica em scripts para ser reproduzível.

## 1. Brief (uma linha, antes de tudo)
`<objeto>, <tamanho real em metros>, <orçamento de tris>, <estilo>, <caminho>`.
Orçamentos: prop pequeno 300–800 · prop grande 800–2 000 · módulo de cenário 600–3 000 · peça herói 2 000–6 000. Teto do Roblox: **20 000 por mesh**.
Conversão: **1 stud = 0,28 m** (create.roblox.com/docs/physics/units). Personagem R15 ≈ 5 studs ≈ 1,4 m.

## 2. Escolher o caminho
| Caminho | Quando | Como |
|---|---|---|
| **A. Primitivas** (padrão) | arestas duras: caixote, baú, arma, poste, muro, módulo de prédio | skill `blender-lpm-skill` (receita `lpm`, paleta, render de 5 vistas, gate) |
| **B. Referência → modelo** | existe imagem/concept e a forma é orgânica ou específica | skill `blender-image-to-3d` (fases com IoU contra a referência) |
| **C. Malha densa → reduzir + bake** | veio de gerador de IA/scan/escultura (100k–600k tris) | `scripts/reduzir.py` → `blender-image-to-3d/scripts/bake_maps.py` |
| **D. Gerado no Studio** | rascunho rápido, peça de fundo | MCP do Studio: `generate_mesh` / `generate_procedural_model` + `wait_job_finished` |
| **E. Creator Store** | itens genéricos | MCP `search_asset` → `insert_asset`; **auditar** (ver Armadilhas) |

O pipeline do vídeo (Flux na Cloudflare → Hi3DGen no Kaggle) **não está montado**: precisa de conta Cloudflare (Workers AI) e Kaggle. Quando montado, a saída dele entra no caminho C.

## 3. Caminho C em detalhe (testado em 2026-10-11)
```bash
BL=.claude/skills/blender-lpm-skill/scripts/bl.py
python $BL --script .claude/skills/modelo-3d-roblox/scripts/reduzir.py -- --input bruto/x.glb --alvo 6000 --save assets/modelos/X/X_master.blend
python $BL --script .claude/skills/blender-image-to-3d/scripts/bake_maps.py -- --blend assets/modelos/X/X_master.blend \
  --low LOW --high HIGH --res 1024 --maps normal,ao,basecolor --out assets/modelos/X/tex --rebuild-material --save assets/modelos/X/X_baked.blend
python $BL --script .claude/skills/modelo-3d-roblox/scripts/exportar_roblox.py -- --input assets/modelos/X/X_baked.blend --out assets/roblox/X --colecao LOW
```
`reduzir.py` solda vértices, decima para o alvo, limpa geometria solta e refaz a UV. `--res 1024` é o máximo de textura do Roblox.

## 4. Olhar (obrigatório)
Renderizar 5 vistas + folha: `python $BL --script .claude/skills/blender-lpm-skill/scripts/render_views.py -- --input <blend> --out <pasta>/views --ortho` e **ler `sheet.png`**. Julgar silhueta de frente e de lado, proporção contra o brief e legibilidade a 3 m. No caminho C, ocultar a coleção HIGH antes (o render mostra a cena inteira). Não aprovar por uma vista só.

## 5. Exportar
`scripts/exportar_roblox.py` (testado): falha se uma mesh passa do orçamento (`--limite`, padrão 20 000) ou uma textura passa de 1024 px; avisa sobre buracos e n-gons; ignora objetos `_COL`; exporta FBX com as opções da doc oficial (Path Mode Copy, Embed Textures, FBX Unit Scale) e grava `<out>.roblox.json` com `size_studs_xyz` (eixo Y do Roblox = Z do Blender).

## 6. Importar e conferir no Studio
- Hoje: o usuário importa o FBX em **File → Import 3D** (o MCP do Studio não importa arquivo local de mesh). Upload automático via Open Cloud fica para quando houver API key em variável de ambiente.
- Depois de importar, pelo MCP: `inspect_instance` na MeshPart → ajustar `Size` para o `size_studs_xyz` do manifesto (a escala do importador varia; o manifesto é a verdade) → `CollisionFidelity` = `Box` ou `Hull` em props (não `PreciseConvexDecomposition` sem motivo) → `Anchored = true` em cenário → `screen_capture` para ver no mundo.
- Guardar o asset final em `ServerStorage/Modelos` ou `ReplicatedStorage/Modelos` com o nome do brief.

## Armadilhas (cada erro novo vira uma linha aqui, com o motivo)
- glTF/FBX de geradores chegam com vértices separados por face. Decimar sem soldar deixou 122 mil arestas soltas e FBX de 3,2 MB para 6 mil tris. `reduzir.py` já solda.
- `render_views.py` renderiza a cena inteira; com HIGH visível a vista engana.
- O `bl.py` do LPM procura o Blender em `Program Files`; aqui ele está na Steam. Sem `BLENDER_EXE` ele falha.
- Modelos da Creator Store podem trazer `Script`/`LocalScript` escondidos (backdoor). Depois de `insert_asset`, listar descendentes do tipo LuaSourceContainer e apagar o que não for esperado.
- Não decimar um modelo de arestas duras: reconstruir por primitivas (caminho A). Decimar é só para malha orgânica densa.
- `lpm.Palette.images()` grava cores **lineares** numa imagem de bytes sRGB (Blender 5.2): o PNG sai escuro e saturado (laranja `#f27c0a` virou `#e23301`). Receitas que usam paleta devem regravar os pixels em sRGB direto e conferir o PNG contra o hex (ver `assets/modelos/Dome/dome.py`). Conferir lendo o PNG com PIL, não pelo render do Blender (AgX também muda a cor).
