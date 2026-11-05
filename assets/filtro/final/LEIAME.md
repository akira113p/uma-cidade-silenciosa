# Texturas finais do filtro

Geradas por `ferramentas/filtro/gerar_texturas.py` (P1-P4, semente fixa) e `ferramentas/filtro/processar_texturas.py`
(T1-T5, a partir de `assets/filtro/bruto/`; `--verificar` mede os finais). Todas brancas/neutras com a forma no alfa
(o Roblox tinge por `ImageColor3`/`Color`), salvo `grao_*` (preto/branco) e `moldura_vhs` (preto + franja).

| Arquivo | Tamanho | Chave em `Config/Filtro/Texturas.luau` | Uso |
|---|---|---|---|
| `grao_1..4.png` | 256x256 | `grao[1..4]` | `ImageLabel` em Tile, quadros trocados/deslocados; grao de 2 px (blocos 2x2), cada bloco preto ou branco, alfa medio 0.30, massas iguais (brilho medio nao muda) |
| `vinheta.png` | 512x512 | `vinheta` | `ImageLabel` Stretch tela cheia; centro alfa 0, cantos ~0.85 |
| `moldura_vhs.png` | 256x256 | `moldura` | `ImageLabel` Slice tela cheia; ver SliceCenter abaixo |
| `halo_luz.png` | 256x256 | `halo` | `BillboardGui` + `ImageLabel` no poste; branco, alfa gaussiano |
| `craquelado.png` | 1024x1024 | `craquelado` | `ImageLabel` tela cheia (ou Tile); rede de rachaduras tipo verniz/filme velho, preto, alfa 0.4-0.9 nas linhas (~4% da area), tileavel nas duas direcoes |
| `riscos_filme.png` | 64x1024 | `riscos` | `ImageLabel` esticado e sorteado em posicao/largura: 1 risco vertical branco irregular que some nas pontas |
| `neblina_mecha_a.png` | 1024x1024 | `neblinaMechaA` | textura de `Beam` de neblina; girada: base densa a esquerda (comeco do feixe), topo fino a direita; emenda agora no eixo vertical (cruza a largura do feixe) |
| `neblina_mecha_b.png` | 1024x1024 | `neblinaMechaB` | idem, variacao mais densa |
| `neblina_puff.png` | 512x512 | `neblinaPuff` | `ParticleEmitter`; alfa de borda 0 |
| `cone_luz.png` | 1024x512 (girado) | `coneLuz` | `Beam` do cone do poste; girada: ponta estreita e forte a esquerda (lampada), alfa de borda 0 |
| `faixa_tracking.png` | 2048x128 | `tracking` | `ImageLabel` faixa de tracking VHS (banda recortada do bruto); emenda horizontal; unico com residuo de cor |
| `poeira_lente.png` | 1920x1080 | `poeira` | `ImageLabel` tela cheia; cobertura ~0.15%, centro vazio |

Os arquivos T1-T5 saem de `python ferramentas/filtro/processar_texturas.py` (brutos em `assets/filtro/bruto/`).

## SliceCenter da moldura

`ImageLabel.ScaleType = Enum.ScaleType.Slice`, `SliceCenter = Rect.new(64, 64, 192, 192)` (px da imagem de 256).
O retangulo transparente fica a 16 px da borda, com cantos de raio 48 (curva termina em 64 px), fade de 12 px para
dentro e franja vermelha (esquerda) / ciano (direita) de 3 px, sutil. Os cantos de 64 px ficam fixos; o resto estica.
Com `SliceScale` 1 os cantos ficam com 64 px na tela.
