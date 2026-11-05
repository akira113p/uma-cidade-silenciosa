---
name: codigo-roblox
description: Código Luau do jogo Roblox no fluxo do projeto - código em arquivos sincronizados pelo Rojo, config numa pasta só, rede num arquivo só, regras puras testáveis fora do Roblox, e 4 checagens (rojo build, testes Lune, selene, stylua) antes de o Studio ver qualquer coisa. Use para criar o projeto, escrever qualquer sistema/feature/script do jogo, ou quando algo quebrar no código.
---

# Código do jogo

Problema central: Claude não assiste o jogo rodando como um jogador. O que sai de um jogo rodando é o console e o que o `execute_luau` lê nos datamodels `Server`/`Client` durante o playtest. Então **o máximo possível do jogo tem que ser verificável parado**.

Conhecimento de Luau/APIs/segurança: skill `roblox-dev-skill`. Rojo/Rokit/selene/StyLua: skill `roblox-toolchain`.

## Projeto novo
1. Copiar `.claude/skills/codigo-roblox/modelo/` para a raiz do projeto.
2. `rokit install` (versões fixadas em `rokit.toml`) e `rojo plugin install` (plugin do Studio).
3. Rodar `pwsh scripts/checar.ps1` até **tudo verde antes da primeira linha de código de jogo**. Se o ponto de partida já falha, não dá para separar erro real de lixo gerado.
4. No Studio: plugin Rojo → Connect (com `rojo serve` rodando).

## As 5 regras
1. **Código vive em arquivos** (`src/`), sincronizado pelo Rojo. Nunca digitar código direto no Studio nem usar `multi_edit` em script que tem arquivo: Studio e arquivos divergem (foi isso que matou a primeira versão do jogo do vídeo).
2. **Todo número ajustável** (velocidade, dano, preço, tempo, recompensa) fica em `src/shared/Config/`. Balancear = mudar dado.
3. **Toda mensagem cliente↔servidor** é declarada em `src/shared/Rede.luau`. Servidor valida tipo, faixa e estado de tudo que chega, com limite de frequência.
4. **Regras puras** em `src/shared/Regras/`: fórmulas de custo, dano, progressão, sorteio. Sem `game`, sem `Instance`, sem `require` de módulos do Roblox. Cada regra tem `tests/<Nome>.spec.luau` rodando no Lune.
5. **Cada armadilha que custar tempo vira linha** na seção Armadilhas abaixo, com o motivo.

## Layout
```
src/shared/Config/      números (Movimento.luau já vem; o checker de mapa lê ele)
src/shared/Regras/      lógica pura testável
src/shared/Rede.luau    lista de eventos
src/server/             serviços (servidor autoritativo: moeda, inventário, compras, progresso)
src/client/             controladores, input, UI (src/client/UI/ = saída da skill ui-roblox)
tests/                  *.spec.luau (Lune)
```

## Escrever uma feature
1. Regra pura + teste primeiro (`Regras/X.luau` + `tests/X.spec.luau`).
2. Números em `Config/`.
3. Eventos em `Rede.luau`; handler no servidor validando tudo.
4. Cliente só pede e mostra; nunca decide valor.
5. `pwsh scripts/checar.ps1` verde.
6. No Studio: `start_stop_play` → `execute_luau` no datamodel `Server` para ler o estado (ex.: moedas do jogador) → `get_console_output` → parar. Erro no console = bug, mesmo que "funcione".
7. `systematic-debugging` para qualquer bug, antes de propor correção.

## Armadilhas
- Modelo validado em 2026-10-12. Duas falhas corrigidas: `rojo build` não cria a pasta `build/` (o `checar` cria antes) e um teste do modelo não estava no formato do StyLua.
- `rojo build` monta o .rbxl inteiro em ~1 s e pega arquivo quebrado e projeto mal mapeado antes do Studio.
- (Cidade Silenciosa, 2026-11-03) Servir o mapa de ~155 mil peças congela o plugin do Rojo ("não está respondendo"): a comparação inicial roda no Studio. `default.project.json` fica sem mapa (seguro para `rojo serve`); `build.project.json` tem o mapa e é o que o `checar` constrói. Mudou Lighting/propriedades: mudar nos dois (o `checar` compara).
- Rokit sem binário pronto: baixar o zip do release (`gh release download --repo rojo-rbx/rokit`) e `rokit self-install`; depois `rokit trust <dono/ferramenta>` para cada ferramenta e `rokit install`.
- **`execute_luau` roda em outra VM**: `require` de um módulo do jogo devolve uma cópia nova (perfil vazio). Para ler/alterar o estado real: atributos (o servidor espelha o perfil em `DebugPerfil` no Studio) ou um `BindableFunction` (`ServerStorage.Teste`, criado por `src/server/Teste.luau` só no Studio).
- ProximityPrompt só aparece (e `InputHoldBegin` só dispara) quando está **na tela**. No playtest, depois de teleportar o personagem, apontar `workspace.CurrentCamera` para o alvo e esperar `ProximityPromptService.PromptShown`.
- `user_mouse_input` por coordenada não acertou botão (o caminho do mouse cruza o CoreGui); clicar por `instance_path`. Por isso as linhas de lista recebem o id como `Name`.
- DataStore no Studio com API desligada dá erro "Studio access to APIs is not allowed": não tentar de novo (só atrasa a entrada) e não salvar por cima.
- Lune (`@lune/roblox`): `TextLabel.Font = Enum.Font.X` quebra a serialização; usar `FontFace = roblox.Font.fromEnum(...)`.
- `src/client/UI/` é gerado pela skill `ui-roblox`: fica no `.styluaignore`; corrigir a spec, nunca o `.luau`.
- Modelo anexado ao jogador (seguidor): mover no servidor pelo `Heartbeat` com `Lerp` (anchored + `PivotTo`) funciona e replica; teletransportar quando a distância passar de ~60 studs (respawn). Cubos do seguidor com `CanCollide = false`, senão empurram o jogador.
- Teste de movimento pelo `execute_luau`: conferir que o ponto está em cima de chão (x do corredor é -30..30; x=-125 é a coluna da base 1 e o personagem cai no vazio).
- Pista de intenção do inimigo: o servidor sorteia a ação do próximo turno logo depois de resolver o atual e a guarda em `luta.intencao`; o cliente só recebe o nome ("ataque"/"escudo"/"quebra"). Assim a pista nunca mente.
- Depois de editar arquivos, o Rojo pode levar alguns segundos para o Studio ter o código novo: se o playtest mostrar comportamento antigo (campo novo vem `nil`), checar `Source` do módulo no Edit (`execute_luau`) e reiniciar o play.
- Efeito de defesa (escudo) precisa de prioridade na ordem do turno; senão o oponente mais rápido bate antes de ele subir. Simular no Lune (`Combate.turno`) antes de culpar o cliente.
- Outra sessão pode estar usando o mesmo Studio: o play é encerrado por fora e o `execute_luau` responde "Target is closed". Conferir `get_studio_state` e, se for recorrente, validar pelas regras puras (Lune) em vez do playtest.

- (Cidade Silenciosa, 2026-11-01) `PivotTo` logo no `CharacterAdded` é desfeito: o motor posiciona o personagem depois. Esperar `IsDescendantOf(workspace)` + `task.wait()` antes de mover (src/server/Spawn.luau).
- (Cidade Silenciosa, 2026-11-01) Id de **Decal** em `ImageLabel.Image` falha com "Asset type does not match requested type". UI precisa do id da **Image**.
- (Cidade Silenciosa, 2026-11-01) Playtest sem Rojo conectado: `rojo build -o build/x.rbxl` e abrir o arquivo (`start build\x.rbxl`); o MCP lista a janela nova pelo nome do arquivo em ~30 s.
- (Cidade Silenciosa, 2026-11-01) **GuiButton `Modal` NÃO solta o mouse** na primeira pessoa (ModalEnabled ficou false, MouseBehavior ficou LockCenter, mesmo visível e dentro da tela). Funciona: `UserInputService.MouseBehavior = Default` num `BindToRenderStep` com `RenderPriority.Last`, enquanto houver menu aberto (client/Mouse.luau). Ao parar de forçar, a câmera prende de novo sozinha.
- (Cidade Silenciosa, 2026-11-01) `user_keyboard_input` do MCP **não chega ao jogo** (nem ao UserInputService). Para testar menus: gancho só do Studio, atributo `TesteUI` no jogador (client/init.client.luau). `ContextActionService:CallFunction` não dá no execute_luau (falta capability).
- (Cidade Silenciosa, 2026-11-01) Atalho de menu: usar `client/Teclas.luau` (InputBegan ignorando `processado` + CAS de prioridade alta, com intervalo mínimo). O Tab padrão do Roblox abre a lista de jogadores: desligar `CoreGuiType.PlayerList`.
- (Cidade Silenciosa, 2026-11-01, **corrigida em 2026-11-03**) **Atmosphere no Lighting anula `FogStart/FogEnd/FogColor`** (docs do Atmosphere). A nota antiga dizia "usar Fog, Atmosphere como complemento": errado, as duas não convivem; o projeto tinha as duas e a névoa do Config não fazia nada (céu azul no playtest). Agora só Fog, e `server/Visual.luau` destrói qualquer Atmosphere ao iniciar.
- (Cidade Silenciosa, 2026-11-03) **Fog não cobre o céu**: tudo além do FogEnd vira FogColor, mas o skybox não. Céu de névoa = caixa de 6 Parts presa à câmera logo depois do FogEnd (`client/Filtro/Ceu.luau`).
- (Cidade Silenciosa, 2026-11-03) **ViewportFrame não tem névoa**: clone de chão longe aparece "limpo" por cima do chão enevoado (cunha colorida na tela) e monstro longe aparece através da névoa (injusto no PvP). Clone = transparência `max(original, fatorNevoa(dist))`, sem chão/planos grandes, alcance limitado pela névoa (`Filtro/Aberracao`).
- (Cidade Silenciosa, 2026-11-03) **Aberração por ViewportFrame**: (1) excluir paredes dos clones = fantasma (o que está atrás aparece por cima); clonar paredes e fazer a névoa pela COR do clone (`Lerp` para FogColor), nunca por transparência. (2) GUI não tem mistura aditiva: duas camadas fortes iguais → a de cima domina (tudo ciano). Pesos iguais: tCiano = 1 - w, tVermelho = 1 - w/tCiano; força vem de separar mais (fovDelta), não de opacidade (w ≤ ~0.2).
- (Cidade Silenciosa, 2026-11-03) Grão: cobertura efetiva = alfa médio da textura × (1 - ImageTransparency). Alfa 0.04 com transparência 0.8 = invisível; alfa 0.30 com 0.35 = chiado de TV; alvo ~5–8%.
- (Cidade Silenciosa, 2026-11-03) `upload_image` do MCP só aceita URL HTTP: servir a pasta com `python -m http.server 8765 --bind 127.0.0.1` e passar `http://localhost:8765/x.png`. Os ids voltam como **Image** (conferir com `ContentProvider:PreloadAsync` no Client antes de gravar no Config).
- (Cidade Silenciosa, 2026-11-03) Textura de **Beam** corre no eixo horizontal ao longo do feixe (Attachment0 → Attachment1): imagem "em pé" (cone estreito em cima) tem que ser girada 90° antes do upload.
- (Cidade Silenciosa, 2026-11-03) Esfera Glass de lente na frente da câmera: para cobrir a tela larga o raio angular `asin(r/d)` precisa passar do meio-FOV horizontal (~62°) → r/d ≈ 0.9 (diâmetro 10, distância 5.6). Menor que isso a borda da esfera aparece como disco azulado. A refração não apareceu no Studio em qualidade automática.
- (Cidade Silenciosa, 2026-11-01) `user_keyboard_input` aceita `actions=[{"type":"key_press","key":"O"}]` e responde "Success", mas o jogo não recebe (nenhuma linha `[Teclas]` no Output). Não serve como prova de atalho; usar o gancho `TesteUI`.
- (Cidade Silenciosa, 2026-11-01) Atalho que só age com uma condição (ex.: atributo `Admin` do servidor) não pode falhar calado: se a condição falha, `warn` com o motivo. Senão "a tecla não funciona" e "o servidor não liberou" parecem o mesmo bug. Menu de admin: O e reserva K (`Config/Admin`), e no Studio o Output mostra `[Admin] menu pronto: ... atributo Admin = ...`.
- (Cidade Silenciosa, 2026-11-01) O Roblox liga I e O ao zoom da câmera (`RbxCameraKeypress`); o `Teclas` (CAS prioridade alta, Sink) deve ganhar, mas por isso o menu tem tecla reserva.
