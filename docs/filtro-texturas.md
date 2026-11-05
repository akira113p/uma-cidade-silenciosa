# Texturas do filtro visual (referência Silent Hill)

Contrato das imagens que o filtro usa. Duas origens:
- **ChatGPT** (orgânicas, precisam parecer reais): geradas por agente no navegador, brutas em `assets/filtro/bruto/`.
- **Python** (precisam de propriedade exata: média neutra, 9-slice, gradiente medido): `ferramentas/filtro/gerar_texturas.py`.

Depois de geradas, todas passam por `ferramentas/filtro/processar_texturas.py` (recorte, tamanho final, canal alfa,
emenda sem costura) e vão para `assets/filtro/final/`, de onde sobem para a conta pelo MCP do Studio.

Contexto visual: cidade em névoa densa estilo Silent Hill 1, cinza frio de dia, sépia/marrom à noite. As imagens são
usadas em Roblox como textura de Beam, ParticleEmitter ou ImageLabel por cima da tela; o Roblox aplica a cor por
`Color`/`ImageColor3`, então a imagem deve ser **neutra (branco/cinza)**, nunca colorida, salvo onde dito.

## Geradas no ChatGPT

| Id | Arquivo bruto | Uso no jogo | Requisitos |
|---|---|---|---|
| T1 | `neblina_mecha_a.png`, `neblina_mecha_b.png` | Textura de `Beam` vertical (coluna de neblina rasteira, densa embaixo e sumindo para cima) | Quadrada 1024×1024. Mechas de neblina/fumaça branca suaves, sem formas reconhecíveis, sem bordas duras. **Emenda sem costura na horizontal** (esquerda casa com direita). Fundo preto puro (vira alfa no processamento) ou transparente. Densidade mais alta na metade de baixo. Duas variações diferentes. |
| T2 | `neblina_puff.png` | Partícula (`ParticleEmitter`) de neblina que flutua perto do chão | Quadrada 512×512. Uma nuvem/fumaça branca macia e irregular, centrada, que some até a borda (nada encosta na borda). Fundo preto puro ou transparente. |
| T3 | `cone_luz.png` | `Beam` do cone de luz do poste à noite (feixe volumétrico visto na névoa) | 512×1024 (retrato). Feixe de luz branco visto de lado: estreito e forte em cima, abrindo e enfraquecendo para baixo, bordas laterais suaves, poeira/partículas muito sutis dentro. Fundo preto puro. Sem a lâmpada, sem poste. |
| T4 | `faixa_tracking.png` | Faixa horizontal de erro de tracking de VHS que passa pela tela (como na base da foto-alvo da noite) | 2048×128 (faixa larga e baixa). Ruído horizontal de fita VHS: riscos brancos finos, chuvisco, pequenos traços deslocados. Fundo preto puro. Emenda sem costura na horizontal. Branco/cinza, com no máximo um leve resíduo vermelho/ciano nos riscos. |
| T5 | `poeira_lente.png` | Sobreposição sutil de poeira e riscos de lente/filme, tela cheia | 1920×1080. Pontos de poeira, fiapos e riscos finos brancos espalhados, esparsos (cobrem < 5% da área), concentrados mais nas bordas que no centro. Fundo preto puro. |

Regras para todas: sem texto, sem marca d'água, sem moldura, sem objeto reconhecível, sem cor (salvo T4), contraste
alto entre o elemento e o fundo preto (o preto vira transparente).

## Geradas em Python (não vão para o ChatGPT)
| Id | Arquivo | Por que Python |
|---|---|---|
| P1 | `grao_1.png` … `grao_4.png` (256×256 cada) | Grão de 2 px, alfa médio 0.30, metade blocos pretos e metade brancos: o brilho médio da tela não muda. |
| P2 | `vinheta.png` (512×512) | Gradiente radial medido (escurece cantos sem mexer no centro). |
| P3 | `moldura_vhs.png` (256×256, 9-slice) | Cantos arredondados com medida exata para `SliceCenter`; franja vermelha/ciano na borda interna. |
| P4 | `halo_luz.png` (256×256) | Brilho radial da lâmpada. |
| P5 | `craquelado.png` (1024×1024, tileável nas duas direções) | Rede de rachaduras (Voronoi com traçado deformado), preto, alfa 0.4–0.9 nas linhas, ~4% da área; chave `craquelado`. |
| P6 | `riscos_filme.png` (64×1024) | Um risco vertical fino e irregular, branco, some nas pontas; esticado e sorteado na tela; chave `riscos`. |

O céu não usa textura: é a caixa de céu da névoa (`docs/filtro.md` §1).
