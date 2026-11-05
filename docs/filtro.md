# Filtro visual (referência Silent Hill): arquitetura

Contrato entre as partes que escrevem o filtro. Alvo: fotos de 2026-11-02 (dia cinza frio com névoa densa; noite sépia
com cones de luz dos postes; moldura de VHS com granulação). Decisões em `docs/decisoes.md` (2026-11-02). Texturas em
`docs/filtro-texturas.md`. Regras do projeto valem: números em `src/shared/Config`, contas puras em
`src/shared/Regras` com teste Lune, 4 checagens (`pwsh scripts/checar.ps1`).

## 1. O que o Roblox não tem e como cada etapa contorna

Pesquisa de 2026-11-02 (DevForum, docs): não há shader nem passe de pós-processamento customizado. Efeitos nativos:
Bloom, Blur, ColorCorrection, ColorGrading, DepthOfField, SunRays. Tudo abaixo é técnica nossa ou adaptada.

| Etapa | Técnica | Origem |
|---|---|---|
| Névoa curta | `Lighting.FogStart/FogEnd/FogColor` **sem Atmosphere** (com Atmosphere no Lighting a névoa é ignorada — docs do Atmosphere; o projeto tinha as duas) | doc oficial |
| Céu de névoa | **Caixa de céu**: 6 placas opacas presas à câmera logo depois do `FogEnd`. Tudo além do FogEnd é pintado com `FogColor`, então o céu vira névoa da cor exata de cada hora, sem textura | própria |
| Névoa em camadas e por altura | Colunas de `Beam` verticais com `FaceCamera`, numa grade fixa no mundo ao redor da câmera; transparência ao longo do beam = densa no chão, some no alto (névoa por altura); os beams têm profundidade, então objetos à frente os escondem (sensação volumétrica) | adaptada de "Volumetric Fog V1" (beams) e Voxel (BillboardGui) |
| Neblina rasteira | `ParticleEmitter` numa caixa larga que segue a câmera no chão | comum |
| Aberração cromática | **Divisão por FOV**: 2 `ViewportFrame` (vermelho e ciano) por cima do mundo, câmeras com o mesmo CFrame e FOV um pouco menor/maior que o real → franja **radial** (zero no centro, cresce para a borda), como a lente real. Conteúdo: geometria estática perto da câmera (cache por célula) + monstros/jogadores visíveis | adaptada (a da comunidade desloca viewports em pixels, o que não é radial) |
| Distorção de lente (barril/CRT) | Esfera de material **Glass** na frente da câmera: o Glass refrata o que está atrás → distorção real do 3D. Só funciona com gráfico alto | "I made a realistic VHS effect" (DevForum) |
| Granulação | 4 quadros de ruído só no alfa, metade pontos pretos e metade brancos (média neutra: não escurece a tela), trocados a 12–15 quadros/s com deslocamento aleatório | própria |
| Moldura VHS, vinheta, poeira, tracking, glitch | `ImageLabel` 9-slice + sobreposições; faixa de tracking atravessa a tela em intervalos; glitch dá um tranco na câmera (`Camera.tremer`) | comum |
| Postes à noite | Pool de `SpotLight` nos N postes mais próximos + `Beam` de cone (luz volumétrica falsa) + halo; alguns piscam ou estão quebrados | comum |
| Cor por hora | `ColorCorrection` (saturação, contraste, tint frio de dia / sépia à noite), Bloom e DepthOfField leves | nativo |

Limites honestos: a franja só existe onde há clone no ViewportFrame (perto da câmera e criaturas visíveis); a lente só
distorce com gráfico alto (no automático fica desligada); não existe pixelização da imagem 3D.

## 2. Arquivos e donos

| Arquivo | Dono |
|---|---|
| `src/client/Filtro/init.luau` (orquestrador), `Filtro/Grao.luau`, `Filtro/Moldura.luau` | S1 Núcleo |
| `src/shared/Config/Filtro/Geral.luau`, `Grao.luau`, `Moldura.luau` | S1 |
| `src/shared/Regras/Filtro.luau` + `tests/Filtro.spec.luau` | S1 |
| apagar `src/client/FiltroPS1.luau`; `init.client.luau` troca `"FiltroPS1"` por `"Filtro"` | S1 |
| `src/client/Filtro/Aberracao.luau`, `Config/Filtro/Aberracao.luau`, `Regras/FiltroAberracao.luau` + `tests/FiltroAberracao.spec.luau` | S2 Aberração |
| `src/client/Filtro/Lente.luau`, `Filtro/Neblina.luau`, `Filtro/Ceu.luau`, `Config/Filtro/Lente.luau`, `Neblina.luau`, `Ceu.luau`, `Regras/FiltroNeblina.luau` + spec | S3 Névoa e lente |
| `src/client/Filtro/Postes.luau`, `Config/Filtro/Postes.luau`, `Regras/FiltroPostes.luau` + spec | S4 Postes |
| `src/server/Visual.luau`, `Config/Tempo.luau`, `Regras/Luz.luau` + `tests/Luz.spec.luau`, `build.project.json` e `default.project.json` (Lighting), `Config/Camera.luau` (preferências), `client/Configuracoes.luau` (linhas novas) | S5 Base |
| `ferramentas/filtro/gerar_texturas.py`, `ferramentas/filtro/processar_texturas.py`, `assets/filtro/final/` | S6 Texturas |
| `src/shared/Config/Filtro/init.luau`, `Config/Filtro/Texturas.luau` | Opus (já escritos) |

Ninguém edita arquivo de outro dono. Se precisar, anota em `docs/pendencias-integracao.md` seção "Filtro".

## 3. Contrato das camadas (cliente)

Cada camada em `src/client/Filtro/<Nome>.luau` exporta exatamente:

```lua
Camada.iniciar(ctx: Ctx): ()          -- cria instâncias; nunca falha por textura vazia (a parte sem textura fica oculta)
Camada.atualizar(e: Estado): ()       -- todo quadro, chamado pelo orquestrador
Camada.ligar(ligado: boolean): ()     -- filtro geral/preferência/qualidade; desligada = instâncias ocultas, custo ~0
Camada.nivel(n: number): ()           -- qualidade automática 0..3 (3 = tudo); cada camada decide o que corta
```

```lua
type Ctx = {
	config: any,                 -- require(Config.Filtro): Ctx.config.Grao, .Aberracao, ..., .Texturas, .Geral
	jogador: Player,
	camera: Camera,              -- workspace.CurrentCamera (o orquestrador troca se mudar)
	guiTela: ScreenGui,          -- "FiltroTela", DisplayOrder 100, IgnoreGuiInset (grão, moldura: por cima do HUD)
	guiMundo: ScreenGui,         -- "FiltroMundo", DisplayOrder -10, IgnoreGuiInset (aberração: abaixo do HUD)
	pastaMundo: Folder,          -- "Filtro" dentro de workspace.CurrentCamera (partes/beams locais, não replicam)
	ajuste: (chave: string, padrao: any) -> any, -- no Studio lê o atributo "Filtro_<chave>" do LocalPlayer (afinar
	                                             -- ao vivo pelo MCP); fora do Studio devolve `padrao`
	camera_tremer: (amplitude: number, duracao: number) -> (),  -- Camera.tremer (respeita Pref_Tremor)
}

type Estado = {
	t: number, dt: number,       -- os.clock(), segundos do quadro
	noite: number,               -- 0 = meio-dia, 1 = noite fechada (1 - Regras/Luz.luzDaHora(Lighting.ClockTime))
	clima: string,               -- workspace:GetAttribute("Clima") ou "limpo"
	fov: number,                 -- camera.FieldOfView do quadro
	interior: number,            -- 0..1 suavizado: 1 = câmera debaixo de teto (raio para cima a 4 Hz)
	primeiraPessoa: boolean,     -- distância câmera–cabeça < 2 studs
	caca: number,                -- 0..1: monstro com Estado "Caca" perto (1 a ≤ 15 studs, 0 a ≥ 60), varre workspace.Monstros a 4 Hz
	pulsos: { dano: number, susto: number, glitch: number }, -- 0..1, decaem sozinhos (Regras/Filtro.decair)
	nivel: number,               -- qualidade automática atual 0..3
}
```

Orquestrador (`Filtro/init.luau`):
- `Filtro.iniciar()` (chamado pelo `init.client.luau`): cria ctx, requer as camadas na ordem
  `Ceu, Neblina, Lente, Aberracao, Postes, Grao, Moldura` (pcall por camada: uma quebrada não derruba as outras),
  liga `RunService:BindToRenderStep("Filtro", Enum.RenderPriority.Camera.Value + 5, passo)` (depois da câmera dinâmica,
  que está em Camera+1), monta `Estado` e chama `atualizar` de cada camada ligada.
- `Filtro.pulso(tipo: "dano" | "susto" | "glitch", forca: number)`: API pública (ex.: ArmasCliente no futuro).
- Eventos internos: perda de vida do humanoide local → `pulso("dano", perda / Geral.danoParaPulsoCheio)`; monstro
  entrando em Caça perto → `pulso("susto", 1)`; glitch agendado por `Regras/Filtro.proximoGlitch`.
- Preferências (atributos do jogador): `Pref_FiltroPS1` liga/desliga tudo (mantém o nome; rótulo vira "Filtro de
  imagem") e também `Lighting.Retro`/`Lighting.Cor` como hoje; `Pref_Aberracao` → camada Aberracao;
  `Pref_Lente` → Lente; `Pref_NeblinaVolume` → Neblina. Céu, Grão, Moldura e Postes seguem só o filtro geral.
- Qualidade automática: média de FPS (janela `Geral.janelaFps`) → `Regras/Filtro.nivelPorFps` → `camada.nivel(n)`.

Ordem visual dentro de `guiTela` (ZIndex): poeira 10, vinheta 20, tracking 30, glitch 40, grão 50, moldura 60.

## 4. Regras puras (testáveis no Lune, sem Instance)

`Regras/Filtro.luau` (S1):
```lua
decair(valor: number, dt: number, meiaVida: number): number
quadroGrao(t: number, fps: number, nQuadros: number): number            -- 1..n, troca a cada 1/fps, nunca repete o anterior
deslocGrao(t: number, fps: number, tamanho: number): (number, number)   -- px 0..tamanho-1, determinístico por quadro
proximoGlitch(agora: number, noite: number, caca: number, cfg, rng: Random): number  -- instante do próximo
nivelPorFps(nivel: number, mediaFps: number, segAbaixo: number, segAcima: number, cfg): number  -- histerese
mistura(a: number, b: number, f: number): number
```
`Regras/FiltroAberracao.luau` (S2):
```lua
fovs(fovBase: number, intensidade: number, cfg): (number, number)  -- (fovVermelho < fovBase < fovCiano); 0 → iguais
transparencia(intensidade: number, cfg): number
celulas(pos: Vector3-like {X,Y,Z}, tamanho: number, raio: number): { string }  -- chaves "x,z" das células no raio
```
`Regras/FiltroNeblina.luau` (S3):
```lua
anel(cx: number, cz: number, espacamento: number, raioInt: number, raioExt: number): { {chave: string, x: number, z: number} }
jitter(chave: string, amplitude: number): (number, number)   -- hash determinístico
fade(dist: number, raioInt: number, rampaInt: number, raioExt: number, rampaExt: number): number -- 0..1
quantizar(v: number, niveis: number): number
```
`Regras/FiltroPostes.luau` (S4):
```lua
estadoLampada(x: number, z: number, cfg): "normal" | "pisca" | "quebrada"   -- hash da posição
brilhoPisca(t: number, x: number, z: number): number   -- 0..1
maisPerto(distancias: { number }, n: number): { number } -- índices
```
`Regras/Luz.luau` (S5): `luzDaHora(hora: number): number` — move a função hoje local em `server/Visual.luau`
(0 = noite fechada, 1 = meio-dia; mesma fórmula). Cliente e servidor usam a mesma.

Testes: um `tests/<Modulo>.spec.luau` por módulo, no estilo de `tests/Camera.spec.luau` (`require("./util")`).

## 5. Etapas em detalhe

### S5 · Base de luz (servidor + projeto)
- `build.project.json` e `default.project.json`: **remover** `Lighting.Atmosfera`. Adicionar `Lighting.Ceu` (`Sky`, `CelestialBodiesShown`
  false, `StarCount` 0), `Lighting.Brilho` (`BloomEffect`) e `Lighting.Profundidade` (`DepthOfFieldEffect`,
  `NearIntensity` 0). `Clouds` não existe no projeto; manter assim.
- `Config/Tempo.luz.noite/dia`: tirar os campos `atmosfera*`; acrescentar `cor = { saturacao, contraste, brilho,
  tint = {r,g,b} }`, `bloom = { intensidade, tamanho, limiar }`, `profundidade = { distanciaFoco, raioFoco,
  intensidadeLonge }`. Valores iniciais (PROVISÓRIO, afinar por captura): névoa dia 0–140 cor {0.70,0.72,0.74}; noite
  0–75 cor {0.15,0.12,0.09}; cor dia saturação -0.45, contraste 0.12, tint {0.93,0.96,1.0}; noite saturação -0.35,
  contraste 0.18, brilho -0.04, tint {1.0,0.86,0.68}; bloom dia 0.2/24/1.4, noite 0.6/30/0.9; profundidade foco 25,
  raio 35, longe 0.15 (dia) / 0.25 (noite). Climas continuam multiplicando a névoa.
- `server/Visual.luau`: usa `Regras/Luz.luzDaHora`; aplica névoa, cor (`Lighting.Cor`), bloom, profundidade misturando
  noite↔dia; remove a parte de Atmosphere; se achar alguma `Atmosphere` no Lighting ao iniciar, destrói (avisa no
  Output uma vez).
- Preferências novas em `Config/Camera.preferenciasPadrao`: `Pref_Aberracao = true`, `Pref_Lente = false`,
  `Pref_NeblinaVolume = true`. `Configuracoes.luau`: 3 linhas liga/desliga ("Aberração cromática", "Distorção de lente
  (gráfico alto)", "Neblina em camadas") e rótulo "Filtro de imagem" no lugar de "Filtro PS1". Conferir que
  `server/Preferencias.luau` aceita booleanos novos sem mudança (ele lê de `preferenciasPadrao`).
- Nada da caixa de céu aqui (é cliente, S3).

### S1 · Núcleo, grão e moldura
- Orquestrador conforme §3. `interior`: raio para cima de 60 studs a partir da câmera, ignorando personagens e
  `pastaMundo`; suavizado (meia-vida 0.4 s).
- **Grão**: `ImageLabel` maior que a tela (tela + `tamanhoTile` px nas duas direções), `ScaleType.Tile`,
  `TileSize = tamanhoTile` px, `ResampleMode.Pixelated`; a cada quadro de grão troca `Image` entre os 4 ids de
  `Texturas.grao` e muda `Position` por `deslocGrao` (negativo). `ImageTransparency` mistura `Grao.transparenciaDia` →
  `transparenciaNoite` por `e.noite`, menos `pulsos.dano * Grao.extraDano`. Pré-carregar os 4 ids
  (`ContentProvider:PreloadAsync`). Nível 0 mantém o grão (é barato).
- **Moldura**: vinheta (`Stretch`, transparência por noite), moldura 9-slice (`ScaleType.Slice`, `SliceCenter` de
  `Moldura.sliceCenter`), poeira (tela cheia, transparência alta, deriva lenta e pisca de leve), faixa de tracking
  (aparece em `proximoGlitch`, atravessa a tela de cima para baixo ou fica parada na base em `duracao`), linhas de
  glitch (8–14 `Frame` finos de 1–2 px perto do topo e da base, larguras e posições sorteadas a 10 Hz, cores
  branco/vermelho/ciano baixas, como nas fotos-alvo), e no início de cada glitch `ctx.camera_tremer(Moldura.tranco,
  0.12)`. Escurecer a vinheta com `pulsos.dano` e `caca`.

### S2 · Aberração cromática (divisão por FOV)
- Em `guiMundo`: 2 `ViewportFrame` tela cheia, `BackgroundTransparency` 1, `ImageColor3` vermelho
  (`Aberracao.corVermelho`) e ciano, `ImageTransparency = transparencia(intensidade)`; cada um com sua `Camera`
  (filha do ViewportFrame); a cada quadro `CFrame = ctx.camera.CFrame` e `FieldOfView` pelos `fovs`. `Ambient`,
  `LightColor`, `LightDirection` do ViewportFrame aproximam o Lighting (atualizar a 1 Hz).
- Intensidade = `Aberracao.base` + `pulsos.dano * Aberracao.extraDano` + `pulsos.susto * extraSusto` + `caca *
  extraCaca`, limitada a 1. Abaixo de `Aberracao.minimoVisivel` → camada oculta (sem custo de render).
- **Estático**: células de `tamanhoCelula` (32) num raio `raioEstatico` (36) da câmera; cada célula clona (uma vez, com
  cache por célula) as `BasePart` de `workspace.Mapa` cujo centro cai na célula, opacas (`Transparency < 0.5`), sem
  scripts/sons/luzes/decals de efeito; usar `workspace:GetPartBoundsInBox` da célula com `OverlapParams` que inclui
  só `workspace.Mapa`. Clonar no máximo `Aberracao.clonesPorQuadro` por quadro (fila). Células fora do raio + margem
  são destruídas. O mesmo clone serve aos dois viewports? Não: cada ViewportFrame precisa do seu; manter 2 cópias.
- **Dinâmico**: monstros (`workspace.Monstros`) e personagens de outros jogadores a ≤ `raioDinamico` (60) e
  ≤ `Lighting.FogEnd`, **só se visíveis**: a 10 Hz, raios da câmera até `Head` e `HumanoidRootPart` (ou pivô)
  ignorando o próprio personagem e o alvo; os dois bloqueados → remove o clone. Clones dinâmicos atualizam CFrame de
  cada parte todo quadro (mapa original → clone). **Regra de justiça (PvP): a camada nunca mostra o que a câmera
  não vê.**
- Nível: 3 = estático + dinâmico; 2 = só dinâmico; 1 e 0 = desligada.

### S3 · Céu, névoa em camadas e lente
- **Céu** (`Ceu.luau`): 6 `Part` em `pastaMundo`, `Anchored`, `CanCollide/CanQuery/CanTouch` false, `CastShadow`
  false, `Material` SmoothPlastic, cor = `Lighting.FogColor`, formando uma caixa centrada na câmera a
  `Lighting.FogEnd + Ceu.margem` (lado limitado a 2048 studs; se o FogEnd passar disso, a caixa usa 2048/2 e a névoa
  ainda cobre). Atualiza posição todo quadro (só posição, sem girar), tamanho quando o FogEnd muda. O chão da caixa
  fica abaixo do terreno (`Ceu.profundidadeChao`), só para tampar buracos.
- **Neblina** (`Neblina.luau`): grade fixa no mundo pelo `anel` (espaçamento 28, raio interno 12, externo 150).
  Cada coluna = `Attachment` na base (chão por raycast para baixo, cache por chave) e no topo (`base + altura`), um
  `Beam` com `FaceCamera` true, `Width0/Width1 = largura`, `Segments` 1, `Texture` alternando mecha A/B pelo hash,
  `TextureSpeed` lento, `TextureLength` = largura, `LightInfluence` 1, `Color` = `Lighting.FogColor` clareado
  (`Neblina.clarear`), `Transparency` = `NumberSequence` densa embaixo e 1 no topo, multiplicada pelo `fade` de
  distância, quantizada (`quantizar`, 10 níveis, sequências em cache). Pula coluna se a base estiver sob teto (raio
  para cima bate em algo em ≤ 40 studs) ou na água. Densidade multiplicada por clima e por `1 - interior * 0.7`.
  Sem textura (id vazio) → camada oculta. Nível 3 = espaçamento normal; 2 = espaçamento × 1.5; 1 = só partículas; 0 = nada.
- Partículas: uma `Part` invisível ancorada que segue a câmera no chão, com `ParticleEmitter` (`Shape` Box,
  `EmissionDirection` Top, textura `neblinaPuff`, tamanho 12–24, vida 8–14 s, velocidade 0.5–1.2, transparência com
  entrada e saída, `LightInfluence` 1); taxa por noite e clima.
- **Lente** (`Lente.luau`): `Part` `Shape` Ball, `Material` Glass, `Reflectance` 0, `CastShadow` false, sem
  colisão/consulta, cor `Lente.cor`, `Transparency` `Lente.transparencia`, tamanho `Lente.diametro`, presa em
  `camera.CFrame * CFrame.new(0, 0, -Lente.distancia)` todo quadro. Só em primeira pessoa. Ligada só com
  `Pref_Lente` = true **e** (`UserSettings().GameSettings.SavedQualityLevel` ≥ `Lente.qualidadeMinima` ou
  `Lente.ignorarQualidade`). Se um raio da câmera para a frente bater em algo a menos de `distancia + diametro/2`,
  oculta (não atravessar parede). Todos os números por `ctx.ajuste` (afinação ao vivo no Studio).

### S4 · Postes
- Acha postes por nome de Model `poste_luz` e `poste_luz_rodovia` (atributo `Prop` igual) dentro de `workspace.Mapa`
  (streaming: `DescendantAdded/Removing`, lista mantida). Lâmpada = a `BasePart` de `Material` Glass mais baixa do
  modelo.
- A 4 Hz: escolhe os `Postes.maxLuzes` (8) mais próximos a ≤ `Postes.alcance` que não estão quebrados; só eles
  recebem `SpotLight` (Face Bottom, `Angle`, `Range`, cor quente) e o `Beam` de cone (textura `coneLuz`, da lâmpada até
  o chão, `Width0` pequeno, `Width1` largo, `FaceCamera` true, `LightEmission` 1, `LightInfluence` 0). Halo
  (`BillboardGui` + `ImageLabel` `halo`) nos `Postes.maxHalos` (30) mais próximos. Objetos reaproveitados (pool),
  nunca criados por quadro.
- Tudo multiplicado por `clamp((e.noite - Postes.limiarNoite) / faixa, 0, 1)`: de dia nada aparece. `pisca` usa
  `brilhoPisca`. Nível 0–1: só halos; 2: luzes sem cone; 3: tudo.

### S6 · Texturas
- `gerar_texturas.py` (numpy + PIL): P1 `grao_1..4.png` (256×256, RGB = preto ou branco por pixel, alfa = ruído
  gaussiano |n| com média ajustada para que a soma de luminância branca e preta se cancele; grão de 1 px), P2
  `vinheta.png` (512, alfa radial suave, centro 0), P3 `moldura_vhs.png` (256×256, borda preta com cantos de raio 48
  px, franja vermelha à esquerda/ciano à direita de 3 px na borda interna, fade de 12 px; escrever o `SliceCenter`
  usado no relatório), P4 `halo_luz.png` (256, branco radial). Saída em `assets/filtro/final/`.
- `processar_texturas.py`: para cada bruto de `assets/filtro/bruto/` que existir: preto → alfa (luminância vira alfa,
  RGB branco), recorte/redimensionamento ao tamanho de `docs/filtro-texturas.md`, emenda horizontal sem costura
  (mistura cruzada das bordas) onde pedido, salva em `assets/filtro/final/`. Ausente → pula e avisa.
- Relatório `assets/filtro/final/LEIAME.md`: tabela arquivo → tamanho → chave em `Config/Filtro/Texturas.luau`.

## 6. Afinação e verificação (Opus, depois das partes)
1. `pwsh scripts/checar.ps1` verde.
2. Upload das imagens finais pelo MCP do Studio; ids em `Config/Filtro/Texturas.luau`.
3. Playtest pelo MCP, `screen_capture` de dia (9h), crepúsculo (18h30) e noite (23h) na mesma cena das fotos-alvo;
   afinar números por `Filtro_<chave>` e depois gravar no Config.
4. Medir custo: FPS com tudo ligado vs. filtro desligado; o nível automático tem que cair sozinho.
5. Conferir a regra de justiça da aberração (monstro atrás de parede não aparece).
