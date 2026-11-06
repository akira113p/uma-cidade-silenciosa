# Filtros do DitherDown no jogo (seletor): arquitetura

Origem: pacote Unity URP "DitherDown" 1.1.0 (RTWarner, Unlicense; `Downloads\psx sttuff\6-ui-e-filtro\ditherdown`). Pesquisa de 2026-11-05 (4 agentes
Haiku, lendo os `.shadergraph` e a documentação). Este documento é o contrato; o filtro atual (Silent Hill) continua em `docs/filtro.md`.
Regras do projeto valem: números em `src/shared/Config`, contas puras em `src/shared/Regras` com teste Lune, 4 checagens (`pwsh scripts/checar.ps1`).

## 0. Reversível (pedido do usuário)
1. Todo o trabalho está na branch local `filtros-ditherdown` (não é push). Desfazer = voltar para `main` e apagar a branch.
2. **Tudo novo nasce DESLIGADO.** Todas as preferências novas têm padrão `false` (ou força), então com o padrão o jogo se comporta como antes.
3. Interruptor mestre: `Config/Filtro/Retro.ativo` (padrão `true`). Com `false` o orquestrador não carrega as camadas novas e o seletor não aparece.
4. Nenhum arquivo existente é apagado; as edições em arquivos antigos são pequenas e listadas em §7.
5. Nada é salvo no Studio nem publicado (regras 6 e 8 do CLAUDE.md). Esta sessão não é a dona do Studio: **nada foi testado no Studio**; só Lune + selene + stylua + rojo build.

## 1. O que o Roblox não faz (decide o escopo)
Não existe shader nem passe de pós-processamento, nem leitura dos pixels da tela, nem escala de render. Conferido em 2026-11-05 (fontes no fim).
Logo: **quantização por pixel do frame e pixelação do frame 3D são impossíveis**; o resto vira **overlay de GUI** (ImageLabel em tile com textura
pequena) e **imitação**, não igual ao shader. O seletor diz isso na tela.

## 2. Os 7 shaders e o que viram

| Shader do pacote | O que faz (conferido no grafo) | Vira no jogo | Fidelidade |
|---|---|---|---|
| DitherDown | dither Bayer centrado (`C + a*(D-0.5)`, a=0.1) + quantiza cada canal em N=32 níveis; pixelação vem do Render Scale do URP, fora do shader | **Dither** (overlay Bayer) | imitação: só o padrão, sem quantização |
| DitherDownCombined | pixela em blocos (Pixelation 240), R/B deslocados ±ColorOffset, dither e quantização só no G | **Combinado**: preset = Dither (matriz 2, força 25) + VHS | imitação |
| Pixelate | `floor(uv*(W,H)/P)/((W,H)/P)` amostra a cena | **Pixelado: indisponível** (linha desabilitada com o motivo) | não existe no Roblox |
| ScanLines_Hard | `fract(y*360)`, `step(0.5)`, brilho lerp(0.7,1.0): 360 ciclos por tela, corte duro | **Scanlines duras** | fiel na frequência e faixa; mistura por alfa |
| ScanLines_Soft | `sin(y*360)` (sem 2π!), remap (-1,1)→(0.7,1.0): período 2π/360 da altura (~57 ondas) | **Scanlines suaves** | idem |
| RollingBands | `sin((t*Speed + y)*Freq)`, remap (0.15,0.85) no grafo / (0.5,1) no .mat; Speed 0.5, Freq 5 (grafo) | **Bandas rolando** | fiel na forma/período/velocidade |
| VHSEffect | R=cena(uv+off,0), B=cena(uv-off,0), G=cena; ColorOffset ±0.01 (padrão 0, .mat 0.002) | **VHS linear**: modo linear da camada Aberração (2 ViewportFrames deslocados em X, em vez de FOV) | geometria fiel; cor é "fantasma", não troca de canal |

Observações do grafo (guardar): o canal azul do DitherDown não é centrado (+0.03..0.05 de viés); R e B do Combined saem sem dither nem quantização; o
"Scanline Count" do Soft não é número de linhas (período 2π/360). Espaço de cor do projeto Unity desconhecido: afinar o escurecimento a olho.

Combinação com o que já existe: o tracking/grão/moldura do S1 não se repetem aqui; as Bandas são novas (bandas permanentes e periódicas, o tracking é uma faixa única).

## 3. Fórmulas de conversão (cada uma tem função pura em `Regras/FiltroRetro.luau`)
Multiplicar a cena por `k` = sobrepor **preto** com alfa `1-k`. Dither: sobrepor branco ou preto com alfa `2·a·|d|`, onde `d = limiar - 0.5`
e `limiar = (valorBayer+0.5)/(n·n)`; branco se `d >= 0`, preto se `d < 0` (aproxima `C + a·d` perto de cinza médio).
Tela em px: `H` = altura da ScreenGui (`AbsoluteSize.Y`), `W` = largura.
- Scan dura: ciclo de `cicloPx = max(H/360, 2)` px; no ciclo, 1ª metade `alfa = 1 - min`, 2ª metade `alfa = 0` (padrão min 0.7). Origem de y invertida
  (Roblox y cresce para baixo): escolher a metade escura em cima, é só estética.
- Scan suave: período `max(H·2π/360, 6)` px; `alfa = 1 - (min + (sin θ + 1)/2·(max - min))`, θ = 2π·fração.
- Bandas: `k = min + (sin((t·v + y)·f) + 1)/2·(max - min)`, y = fração da altura. Período em px = `H·2π/f`. Rolagem: a textura de 1 período
  desce `(t·v·H) mod período` px (no Unity `y` sobe, então o padrão desce na tela).
- VHS linear: deslocamento em px = `clamp(off, -0.01, 0.01) · W`; vermelho vai +x, ciano -x.
- Força (0..100) multiplica a **amplitude** (alfa máximo, deslocamento), não a frequência: `escalaForca(f) = clamp(f,0,100)/100`.

## 4. Textura sem upload (a conta está com Open Cloud 403 "User is moderated")
As texturas dos overlays são **geradas em tempo de execução** com `AssetService:CreateEditableImage` + `WritePixelsBuffer`, a partir de arrays de bytes
calculados pelas regras puras (testáveis). Ordem de tentativa em `Filtro/RetroTextura.luau`:
1. id fixo em `Config/Filtro/Texturas.luau` (chave própria; vazio hoje) → usa `Image`.
2. `EditableImage` gerada → `ImageLabel.ImageContent = Content.fromObject(img)`.
3. falha (API indisponível, memória) → a camada fica oculta e dá um `warn` uma vez. **Nunca derruba o filtro.**
**NÃO VERIFICADO no Studio**: nomes exatos da API (`AssetService:CreateEditableImage`, `EditableImage:WritePixelsBuffer`, `Content.fromObject`,
`ImageLabel.ImageContent`) e se o jogo publicado tem permissão de EditableImage. Tudo em `pcall`; confirmar quando a dona do Studio puder testar.
Fontes: create.roblox.com/docs/en-us/reference/engine/classes/EditableImage (WritePixelsBuffer, DrawImage, ReadPixelsBuffer confirmados; `Size` e teto de 1024² divergem entre páginas).

## 5. Camadas novas (contrato `docs/filtro.md` §3: `iniciar(ctx)`, `atualizar(estado)`, `ligar(bool)`, `nivel(n)`)
Todas em `src/client/Filtro/`, no `ctx.guiMundo` (DisplayOrder -10, abaixo do HUD), ZIndex acima da Aberração (que usa o padrão): Dither 5, ScanDura 6,
ScanSuave 7, Bandas 8. Desligada = instâncias com `Visible = false`, custo ~0. Cada uma reage a `GetAttributeChangedSignal` das suas prefs (força, matriz).

| Arquivo | Pref liga | Pref força | Resumo | Nível mínimo (0..3) |
|---|---|---|---|---|
| `Dither.luau` | `Pref_FDither` | `Pref_FDitherForca` (+ `Pref_FDitherMatriz` 2/4/8/16) | ImageLabel `ScaleType.Tile`, `ResampleMode.Pixelated`, `TileSize` = n·`pixelPorTexel` px, textura `texturaDither(n, amplitude)` | 1 |
| `ScanDura.luau` | `Pref_FScanDura` | `Pref_FScanDuraForca` | tile preto, `TileSize.Y` = `cicloPx`, textura de 1 ciclo | 1 |
| `ScanSuave.luau` | `Pref_FScanSuave` | `Pref_FScanSuaveForca` | tile preto, `TileSize.Y` = período, textura de 1 período | 1 |
| `Bandas.luau` | `Pref_FBandas` | `Pref_FBandasForca` | ImageLabel de altura `H + período`, anima `Position.Y` por quadro | 2 |
| `Aberracao.luau` (já existe) | `Pref_Aberracao` **ou** `Pref_FVhs` | `Pref_FVhsForca` | com `Pref_FVhs` = true usa modo linear: FOV igual ao real, `Position = UDim2.fromOffset(±desloc, 0)`, `Size` continua tela cheia (NÃO alargar: vazaria cena além da borda e quebraria a regra de justiça do PvP) | 3 |

Recalcular `TileSize`/alturas só quando `AbsoluteSize` da gui mudar (não por quadro). Bandas é a única que mexe por quadro.
Conforto: o usuário já teve dor de cabeça com o grão (`Config/Filtro/Grao.luau`). Padrões conservadores, tudo desligado, e o seletor avisa que Bandas se move.

## 6. Seletor (UI) e preferências
`Config/Filtro/Seletor.luau` (dados puros): lista de filtros `{ id, rotulo, fonte, fidelidade, pref, forca = { pref, opcoes, padrao }, extras = {...}, indisponivel, motivo }`,
`presets` (`Combinado`, `Desligar todos`), `aviso` de cada um. `Regras/FiltroSeletor.luau`: `validar(lista, padrao, limites)` (devolve lista de erros; usada no teste para
garantir que toda pref citada existe em `Config/Camera.preferenciasPadrao`), `aplicarPreset(preset)` (tabela de prefs a enviar).
UI: `src/client/FiltrosSeletor.luau` constrói as linhas **dentro da lista de `Configuracoes.luau`** (tecla P), seção "Filtros de tela (DitherDown)": por filtro uma linha
Ligado/Desligado, uma linha de Força (`linhaOpcoes`), e para o Dither uma linha de Matriz; depois "Combinado" e "Desligar todos"; "Pixelado" aparece desabilitado com o motivo.
Reusa `pedir` (lote de 1 envio/s do `SalvarPreferencias`). Pelo toque: alvo ≥ 44 px, como o resto.
O painel de Configurações tem `UISizeConstraint` 460×440 com rolagem; manter a rolagem, não aumentar o painel.
Preferências novas em `Config/Camera.luau` (`preferenciasPadrao` e `limitesPreferencias`; o servidor valida sozinho pelo tipo do padrão e arredonda):
`Pref_FDither=false, Pref_FDitherForca=100, Pref_FDitherMatriz=4 (2..16), Pref_FScanDura=false, Pref_FScanDuraForca=100, Pref_FScanSuave=false,
Pref_FScanSuaveForca=100, Pref_FBandas=false, Pref_FBandasForca=50, Pref_FVhs=false, Pref_FVhsForca=20`; forças limitadas a 0..100.
A matriz que chega do servidor pode ser 3 ou 5: `Regras/FiltroRetro.potenciaValida(n)` arredonda para 2/4/8/16.

## 7. Arquivos e donos
| Arquivo | Dono | Obs |
|---|---|---|
| `src/shared/Regras/FiltroRetro.luau` + `tests/FiltroRetro.spec.luau` | Agente A | funções puras de §3 |
| `src/shared/Config/Filtro/Retro.luau` | A | `ativo`, números de cada filtro (padrões do shader comentados), zIndex |
| `src/client/Filtro/Dither.luau`, `ScanDura.luau`, `ScanSuave.luau`, `Bandas.luau`, `RetroTextura.luau` | A | camadas e gerador de textura |
| `src/shared/Config/Filtro/Texturas.luau` | A | só acrescenta chaves vazias para os ids opcionais |
| `src/shared/Config/Filtro/init.luau` | Opus (já escrito) | exporta `Retro` e `Seletor` |
| `src/shared/Config/Filtro/Seletor.luau`, `src/shared/Regras/FiltroSeletor.luau` + `tests/FiltroSeletor.spec.luau` | Agente B | §6 |
| `src/client/FiltrosSeletor.luau`, `src/client/Configuracoes.luau` | B | seção na tela de Configurações |
| `src/shared/Config/Camera.luau` (prefs), `src/client/Filtro/init.luau` (ORDEM + prefs), `src/client/Filtro/Aberracao.luau` (modo linear) | B | pequenas |
| `docs/pendencias-integracao.md` (seção "Filtro DitherDown") | B | o que não foi verificado |
Ninguém edita arquivo de outro dono.

## 8. Verificação
1. `pwsh scripts/checar.ps1` verde (rojo build, testes Lune, selene, stylua).
2. Revisão do Opus: lê todo o código, confere contra este contrato, roda os testes, procura loop por quadro, instância criada por quadro, falta de `pcall`, número fora de Config.
3. Pendente (dona do Studio): Play no place oficial dentro da `ZonaTeste`, capturas com cada filtro, conferir o §4 (EditableImage), medir FPS, afinar números.

## Fontes (acesso 2026-11-05)
Unity Shader Graph: Posterize, Screen Position, URP Sample Buffer, Remap, Step (docs.unity3d.com). Roblox: ViewportFrame, ImageLabel (ResampleMode, TileSize),
EditableImage, CaptureService (create.roblox.com/docs). DevForum: "Pixelated Visuals Help!" (3535185, 2025-03), "Controlling the resolution of ViewportFrames... CanvasGroups"
(2968151, 2024-05), "Captures APIs" (2838188), "3D world is still rendered in low resolution on high DPI" (4731822, 2026-07..10). Não confirmado: teto 1024 do
ViewportFrame/EditableImage, captura → EditableImage, mecanismo dos truques de pixelação da comunidade.
