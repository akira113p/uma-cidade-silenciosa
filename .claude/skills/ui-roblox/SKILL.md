---
name: ui-roblox
description: UI do jogo Roblox (HUD, loja, menus, popups) a partir de UMA spec JSON que gera o preview PNG em 4 telas, o ModuleScript Luau que constrói a ScreenGui e um relatório de checagens (alvo de toque, sobreposição, centralização, texto mínimo, emoji, contorno único, caixa sobrando). Use para criar ou mudar qualquer tela/HUD/botão do jogo.
---

# UI do jogo

No vídeo base, a UI não é desenhada numa ferramenta de design: um desenho é só uma imagem e o jogo de verdade se afasta dele. Aqui **uma spec é a fonte**, e dela saem o preview, o código e o checker. Como os três vêm da mesma fonte, não discordam sobre tamanho ou cor.

## Fluxo
1. Escrever/editar `ui/specs/<Tela>.json` (formato: [references/formato-spec.md](references/formato-spec.md); exemplo: [exemplos/HudExemplo.json](exemplos/HudExemplo.json)).
2. Rodar:
   ```bash
   python .claude/skills/ui-roblox/scripts/ui_spec.py ui/specs/<Tela>.json --saida src/client/UI --preview ui/preview
   ```
   Sai com 1 se houver FALHA, e aí **não gera o Luau**. Corrigir a spec, nunca o `.luau` gerado.
3. **Ler `ui/preview/<Tela>_preview.png`** e julgar: hierarquia (o botão principal é o mais chamativo?), contraste com o mundo atrás, nada apertado no celular pequeno, nada minúsculo no PC. Elementos com falha aparecem com borda vermelha.
4. No jogo: o client faz `require(script.Parent.UI.<Tela>).criar(Players.LocalPlayer:WaitForChild("PlayerGui"))`. Com o Rojo, o `.luau` entra em `StarterPlayerScripts/Client/UI`.
5. Conferir no Studio pelo MCP: `execute_luau` (Edit) com o conteúdo do módulo criando a tela em `StarterGui`, depois `screen_capture`, depois apagar a tela de teste. Durante playtest, `execute_luau` no datamodel `Client` lê os `AbsoluteSize`/`AbsolutePosition` reais para comparar com o checker.

## Pilha de profundidade (automática com `"profundidade": true`)
Sombra deslocada para baixo e puxada para o azul, gradiente vertical na face (mais claro no topo), canto arredondado e **contorno com a mesma espessura em toda a UI**. Espessuras de contorno misturadas são o sinal mais claro de UI amadora ou feita por IA.

## Regras de checagem (`ui_spec.py`)
| Regra | Falha quando |
|---|---|
| TOQUE | botão < 44 px em alguma das 4 telas |
| SOBREPOSICAO | irmãos se tocam (use `"sobrepor": true` se for de propósito) |
| FORA | elemento sai do pai/tela (use `"vazar": true` se for de propósito) |
| CENTRO | elemento com `"centro"` desviado mais de 1,5 px |
| TEXTO_MIN | texto < `textoMin` (14 px), inclusive texto automático |
| EMOJI | emoji em texto: ícone é ImageLabel gerado (Flux/Cloudflare quando montado, ou desenhado no Blender e renderizado) |
| CONTORNO | elemento sobrescreve a espessura do tema |
| CAIXA_BOTAO | Frame com fundo só para embrulhar um botão (vício recorrente de IA) |
| TAMANHO_FIXO (aviso) | tamanho só em offset que fica pequeno na tela grande |
| TEXTO_CABE (aviso) | texto estimado maior que a caixa |

Telas: celular pequeno 667×375, celular grande 896×414, tablet 1024×768, PC 1920×1080, já descontada a barra superior do Roblox (`insetTopo`, 58 px: **suposição**, conferir no Studio e corrigir no tema se diferir).

## Estilo
Começa pelo estilo padrão do tema. Para copiar o visual de um jogo popular: o usuário fornece screenshots, Claude extrai paleta, raio de canto, espessura de contorno, deslocamento de sombra e fonte para um bloco `tema` e salva como `ui/temas/<nome>.json`. O tema vira padrão do projeto, e a UI de cada jogo pega as partes boas dele.

## Armadilhas
- Console do Windows em cp1252 quebrava a saída com `≠`/emoji; o script força UTF-8.
- HUD só com offset ficou minúsculo no PC full HD. Usar escala + `tamMin`/`tamMax` + `proporcao`.
- Luau gerado validado no Studio em 2026-10-12 (5 telas do corte vertical). O selene reclamava de `UDim2.new` só com escala ou só com offset: o gerador agora emite `fromScale`/`fromOffset`.
- O preview desenha `textoAuto` a 70% da altura **sem encolher para caber na largura** ("MONSTERS" sai cortado no PNG). No Roblox o `TextScaled` encolhe. Texto longo (log, resultado) precisa de `TextWrapped = true`, que o cliente liga.
- A sombra de `profundidade` é irmã do elemento: esconder o elemento deixa a sombra. Para abrir/fechar painel, cada painel é uma ScreenGui e se troca `Enabled`.
- Lista dinâmica: a spec traz um `ModeloLinha` dentro de `Lista`; o cliente tira o modelo, põe uma ScrollingFrame e clona uma linha por item.
