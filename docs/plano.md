# Plano: corte vertical de "Uma Cidade Silenciosa" (título provisório)

Sobrevivência PvP com monstros cegos que caçam pelo som, câmera em primeira pessoa e filtro PS1. Decisões em
`docs/decisoes.md`, números e fórmulas em `docs/calculos.md`, APIs conferidas em `pesquisa/00-descoberta.md`.

**O corte vertical tem:** mapa no tamanho final com construções em blocos, movimento e câmera dinâmica, sistema de som,
monstros nível 1 (modelos parados, sem animação), fome/sede/calor/estamina, dano por partes do corpo, loot em caixas,
PvP com 3 armas corpo a corpo e pistola, filtro PS1, 12 jogadores por servidor.

**Fica de fora:** interiores, craft, veículos, construções quebráveis, minijogos, níveis 2/3/Especial, clima dinâmico
(o ambiente existe como número, mas sem chuva visual), criador de personagem, minimapa.

Cada fase tem uma verificação. A fase só termina quando a verificação passa.

---

## Fase 0: Descoberta de APIs (antes de codar)
Conferir na documentação oficial (create.roblox.com) e registrar em `pesquisa/00-descoberta.md` as APIs que o plano usa:
`ColorGradingEffect` (preset Retro), `Lighting.LightingStyle`, `Atmosphere`, `ImageLabel.ResampleMode`,
`Workspace.StreamingEnabled` + `ModelStreamingMode`, `Humanoid.FloorMaterial`, `PathfindingService:CreatePath`,
`Sound.RollOffMaxDistance` (e a API nova `AudioEmitter`/`AudioListener`, se servir melhor para o som 3D),
`Workspace:Raycast`, `RunService:BindToRenderStep`, `UserInputService`.
- **Verificação:** cada API na lista com link da doc e assinatura. Nada usado no código fora dessa lista.

## Fase 1: Base do projeto
Copiar do teste1 o que `exportar-miro/03-arquivos-para-copiar.md` lista: `rokit.toml`, `selene.toml`, `stylua.toml`,
`scripts/checar.*`, `.claude/skills/` (as que faltam: codigo-roblox, mapa-roblox, ui-roblox, modelo-3d-roblox, som-roblox,
roblox-lighting, roblox-dev-skill, roblox-toolchain, blender-*, criar-jogo-roblox, handoff), `.claude/settings.json`.
Adaptar `default.project.json` e `Rede.luau`. `git init`. Criar place novo no Studio.
- **Verificação:** `pwsh scripts/checar.ps1` com 4 checagens verdes; `rojo serve` conecta no place novo.

## Fase 2: Regras puras e Config
Transformar `docs/calculos.md` em código:
- `Config/Som.luau` (ações, superfícies, ambiente, margens, teto), `Config/Monstros.luau`, `Config/Corpo.luau`,
  `Config/Sobrevivencia.luau`, `Config/Camera.luau`, `Config/Armas.luau`, `Config/Mundo.luau`.
- `Regras/Som.luau` (emitido, recebido, alcance), `Regras/Percepcao.luau` (estado do monstro), `Regras/Corpo.luau`
  (dano, transbordo, morte), `Regras/Sobrevivencia.luau` (barras por dt), `Regras/Camera.luau` (offset por fase).
- **Verificação:** testes Lune reproduzem a tabela 1.4 de `calculos.md` linha por linha; casos de borda (0 parede vs
  3 paredes, teto de 600, perna zerada, transbordo para o torso).

## Fase 3: Mapa em blocos (tamanho final) + filtro PS1
Gerador por dados (`ferramentas/gerar_mapa.luau`, mesmo padrão do teste1) a partir de `Config/Mundo`:
- Mapa total 4000×4000 studs (~1,1 km de lado). Cidade central 1500×1500: quarteirões de 120 com ruas de 30
  (asfalto) e calçada de 6 (concreto). Construções em bloco com atributo `Tipo` (casa, loja, prédio 2/3 andares,
  posto) para os interiores depois. Andar = 12 studs, então o prédio mais alto tem 36.
- 3 vilas (300×300, ~12 casas + posto), fábrica, planície, posto da guarda florestal, floresta (árvore = tronco + copa,
  2 peças) e avenidas de 40 ligando tudo.
- Pisos com o `Material` certo, porque o som depende dele: grama alta em manchas, metal na fábrica.
- `StreamingEnabled` ligado com `ModelStreamingMode` conforme a Fase 0.
- Filtro PS1: `ColorGradingEffect` Retro + iluminação conforme a Fase 0, `Atmosphere` com névoa curta (~250 studs),
  saturação baixa, sobreposição de tela com padrão de dither 4×4 (`ImageLabel` com `ResampleMode = Pixelated`),
  liga/desliga pela configuração.
- **Verificação:** `checar_mapa` (peça solta, tudo alcançável, sem buraco no chão); contagem de peças por quadrante;
  captura de tela no Studio com e sem filtro; FPS no Studio.

## Fase 4: Personagem e câmera
- Agachar (C ou Ctrl), correr (Shift), estamina ligada à corrida. Estado em atributos (`Agachado`, `Correndo`) validados
  no servidor.
- Câmera em primeira pessoa com balanço por passo, tremor de aterrissagem e FOV de corrida (`calculos.md` §5).
  V alterna para terceira pessoa.
- Tela de configurações: tremor, intensidade, FOV, filtro PS1 (salvo por jogador).
- **Verificação:** playtest pelo MCP medindo velocidades por modo; tremor zerado com a opção desligada.

## Fase 5: Som
- Servidor amostra cada personagem a 10 Hz, decide a ação (velocidade + atributo) e a superfície (`FloorMaterial`), emite
  um evento de ruído por passo no ritmo de `calculos.md` §1.1.
- Eventos de ação (porta, golpe, tiro) passam pela mesma função.
- Sons 3D de passo por superfície com alcance pela fórmula (§1.5). Precisa de 1 conjunto de sons por superfície
  (skill `som-roblox`).
- HUD: medidor de decibéis com a marca do ambiente.
- Ferramenta de debug (só no Studio): círculo no chão mostrando o alcance de cada ruído.
- **Verificação:** no playtest, o círculo bate com a tabela 1.4 para 3 combinações (agachado carpete, andar concreto,
  correr metal).

## Fase 6: Monstros nível 1
- Modelos de `modelos 3d/monstros` passam pelo pipeline Blender: reduzir polígonos, textura PS1 (reduzir para 64–128 px,
  paleta de 15 bits com dither, ampliar sem filtro para 512 px), exportar. Sem animação: o modelo desliza.
- Spawn por zona com a densidade de §2.2. Estados Calmo/Investiga/Caça/Ataque (`Regras/Percepcao`), caminho por
  `PathfindingService` recalculado só quando o alvo muda.
- Ataque sorteia a parte do corpo (§3). Grito ao entrar em Caça vira ruído.
- **Verificação:** com 3 jogadores de teste, monstro ignora quem está agachado no carpete, investiga quem anda no concreto
  a 30 studs e caça quem corre no metal a 400.

## Fase 7: Sobrevivência, corpo e loot
- Barras de fome, sede, calor e estamina (§4), partes do corpo (§3), HUD com o boneco das partes.
- Caixas de loot nas calçadas e na porta das construções (os interiores vêm depois): comida, água, bandagem, kit,
  armas. Tabela de loot em `Config/Loot`, reposição a cada 15 min.
- **Verificação:** testes Lune das barras; no playtest, perna zerada reduz a velocidade e bandagem cura.

## Fase 8: PvP
- Faca, pé de cabra, machado e pistola (§6), dano por parte atingida, validação no servidor, tiro emite 110 dB.
- Morte: bolsa com o inventário, respawn em vila aleatória.
- **Verificação:** playtest com 2 clientes no Studio; cliente que forja um golpe fora do alcance é rejeitado.

## Fase 9: Playtest e ajuste
Studio Test com 3+ clientes, 20 minutos. Ajustar só o Config. Registrar os números aprovados em `docs/decisoes.md` e o que
falhou nas "Armadilhas" da skill da área.
- **Verificação:** 20 minutos sem erro no console; os números que o usuário aprovar deixam de ser PROVISÓRIO.

---

## Visual: a fazer (referência Silent Hill, decidido em 2026-11-02)
Alvo: névoa densa, granulação animada, paleta fria dessaturada com acentos vermelhos. Ordem e detalhes em
`docs/decisoes.md` ("Pendentes"). **Arquitetura do filtro completo (céu de névoa, névoa por altura, aberração por FOV,
lente Glass, grão neutro, moldura VHS, postes): `docs/filtro.md`; texturas: `docs/filtro-texturas.md`.**
- [ ] Névoa mais curta, subindo e descendo com o ciclo (`Config/Tempo.luz`); testar por captura de tela.
- [ ] Granulação animada em tela cheia no lugar do dither estático (`FiltroPS1`).
- [ ] Script Blender em lote que converte `modelos 3d` (monstros, armas, outros) para o estilo PS1.
- [ ] Regra de paleta: cinza/frio em tudo, vermelho só em acentos.
- [ ] (Depois) textura de sujeira nas construções; lanterna.
Fora por enquanto: textura de sujeira nas construções. O foco é converter os modelos que já existem.

## Riscos
- **Filtro PS1:** o Roblox não tem shader. Textura de malha não tem filtro sem suavização, então o visual pixelado vem
  da textura preparada no Blender + color grading + sobreposição. Fica parecido, não idêntico.
- **Mapa grande com 12 jogadores:** depende do streaming. Se o FPS cair, o mapa encolhe pelo Config sem reescrever código.
- **Monstros × 12 jogadores:** cada ruído consulta só os monstros dentro de 600 studs; o caminho é recalculado só quando
  o alvo muda.
- **Exploit:** cliente nunca informa ruído, dano nem posição de acerto sem validação no servidor.
- **Assets de terceiros:** os modelos de `modelos 3d` são temporários até serem modificados.
