# Formato da spec de UI

```json
{
  "nome": "HudPrincipal",                 // nome da ScreenGui e do arquivo .luau
  "tema": { ... },                        // opcional; sobrescreve o tema padrão
  "telas": [["celular", 667, 375], ...],  // opcional; padrão = 4 telas
  "raiz": { <elemento> }
}
```

## Tema (padrão em `ui_spec.py`, `TEMA_PADRAO`)
| Chave | Padrão | O quê |
|---|---|---|
| `contorno` | 3 | espessura única de UIStroke |
| `canto` | 12 | raio do UICorner (px) |
| `sombra` | [0, 5] | deslocamento da sombra (px) |
| `corSombra` | #1b2140 | sombra puxada para o azul |
| `corContorno` | #14142a | |
| `gradiente` | 0.82 | multiplicador da cor na base da face (1 = sem gradiente) |
| `fonte` | FredokaOne | nome de `Enum.Font` |
| `corTexto` | #ffffff | |
| `textoMin` | 14 | menor texto aceito (px) |
| `toqueMin` | 44 | menor botão aceito (px) |
| `insetTopo` | 58 | barra superior do Roblox (suposição) |

## Elemento
| Chave | Tipo | O quê |
|---|---|---|
| `tipo` | Frame, TextLabel, TextButton, ImageLabel, ImageButton | |
| `nome` | texto | único entre irmãos |
| `tam` | [xEscala, xOffset, yEscala, yOffset] | UDim2; padrão [1,0,1,0] |
| `pos` | idem | padrão [0,0,0,0] |
| `ancora` | [x, y] | AnchorPoint; [0.5,0.5] = centro |
| `tamMin` / `tamMax` | [w, h] px | UISizeConstraint |
| `proporcao` | número (w/h) | UIAspectRatioConstraint |
| `cor` | #hex | fundo; sem `cor` = transparente |
| `transparencia` | 0–1 | do fundo |
| `profundidade` | bool | sombra + gradiente + canto + contorno |
| `texto`, `textoTam`, `corTexto`, `fonte`, `alinhar` (esquerda/centro/direita) | | texto |
| `textoAuto` | bool | TextScaled (tamanho ≈ 70% da altura) |
| `imagem` | rbxassetid://… | imagens |
| `centro` | true, "x" ou "y" | checar centralização (±1,5 px) |
| `sobrepor` / `vazar` | bool | libera SOBREPOSICAO / FORA para este elemento |
| `filhos` | lista | |

Ordem dos constraints no cálculo: tamanho → `tamMin`/`tamMax` → `proporcao` (aproximação do Roblox; conferir no Studio quando os dois existirem juntos).
