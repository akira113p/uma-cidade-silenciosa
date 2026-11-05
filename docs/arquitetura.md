# Arquitetura do corte vertical

Este documento é o contrato entre as 7 partes do jogo. Cada parte é escrita por um agente diferente, **em paralelo**,
então ninguém pode depender de ver o código do outro: depende só do que está escrito aqui. Se uma parte precisa de algo
que não está aqui, ela **não inventa**: escreve a necessidade em `docs/pendencias-integracao.md` e segue com um
substituto local marcado `-- INTEGRACAO:`.

Leitura obrigatória antes de codar: este arquivo, `docs/calculos.md` (fórmulas), `src/shared/Config/*` (números),
`src/shared/Rede.luau` (mensagens), `.claude/skills/codigo-roblox/SKILL.md` (5 regras e 4 checagens) e
`.claude/skills/roblox-dev-skill/SKILL.md` (Luau e segurança).

---

## 1. Visão geral

```
                         ┌──────────────── SERVIDOR (autoritativo) ────────────────┐
 cliente pede ──Rede──▶  │ Movimento  Preferencias  Inventario  Loot  Armas        │
                         │      │          │            │        │      │          │
                         │      ▼          ▼            ▼        ▼      ▼          │
                         │  atributos do Player  ◀── Vida ◀── Sobrevivencia        │
                         │                          ▲                              │
                         │  Ruido ──aoRuido──▶ Monstros ──Vida.dano────┘           │
                         │   │  ▲                                                 │
                         │   ▼  └── emitir() de Armas, Inventario, Loot, Monstros  │
                         │  Sons (3D)   Ambiente ◀── Visual (relógio, clima)       │
                         └─────────────────────────────────────────────────────────┘
 cliente mostra ◀──atributos replicados + Rede── Camera, Controles, HUDs, FiltroPS1, SonsLocal
```

Princípios:
1. **Servidor decide**: ruído, dano, acerto, estamina, inventário. O cliente só pede (Rede) e mostra (atributos e Rede).
2. **Estado do jogador = atributos no `Player`** (replicam sozinhos). Cada atributo tem **um único dono** que escreve;
   os outros só leem (§3).
3. **Números só em `Config/`**. Fórmulas só em `Regras/` (puras, testadas no Lune). Serviços só ligam as peças.
4. **Toda mensagem em `Rede.luau`** (já escrito; não adicionar eventos sem anotar em pendências).
5. **Streaming ligado**: no cliente, peças do mapa e monstros podem não existir. Nunca `WaitForChild` sem timeout em
   coisa do mapa; tratar `nil`.

### Árvore de arquivos e dono

| Arquivo | Parte |
|---|---|
| `src/shared/Config/*.luau`, `src/shared/Rede.luau` | **pronto** (contrato; só ajustar número com motivo) |
| `src/server/init.server.luau`, `src/client/init.client.luau`, `src/server/Limite.luau`, `src/server/Teste.luau` | **pronto** |
| `ferramentas/gerar_mapa.luau`, `ferramentas/checar_mapa.luau`, `mapa/Mapa.rbxm`, `src/server/Visual.luau`, `src/client/FiltroPS1.luau` | P1 Mapa e visual |
| `src/shared/Regras/Camera.luau`, `src/server/Movimento.luau`, `src/server/Preferencias.luau`, `src/client/Camera.luau`, `src/client/Controles.luau`, `src/client/Configuracoes.luau` | P2 Personagem e câmera |
| `src/shared/Regras/Som.luau`, `src/server/Sons.luau`, `src/server/Ambiente.luau`, `src/server/Ruido.luau`, `src/client/SonsLocal.luau`, `src/client/HudSom.luau`, `src/client/Voz.luau`, `src/client/DebugRuido.luau` | P3 Som |
| `src/shared/Regras/Percepcao.luau`, `src/server/Monstros.luau` | P4 Monstros |
| `src/shared/Regras/Corpo.luau`, `src/shared/Regras/Sobrevivencia.luau`, `src/server/Vida.luau`, `src/server/Sobrevivencia.luau`, `src/server/Spawn.luau`, `src/client/HudVida.luau` | P5 Vida e sobrevivência |
| `src/shared/Regras/Inventario.luau`, `src/shared/Regras/Loot.luau`, `src/server/Inventario.luau`, `src/server/Loot.luau`, `src/client/InventarioUI.luau` | P6 Inventário e loot |
| `src/shared/Regras/Armas.luau`, `src/server/Armas.luau`, `src/client/ArmasCliente.luau` | P7 Armas e PvP |
| `tests/<Regra>.spec.luau` | dono da regra |

**Nenhuma parte edita arquivo de outra.** Teste de cada regra: `tests/<Nome>.spec.luau`, usando `tests/util.luau`.

### Padrão de módulo de serviço (servidor e cliente)

```lua
-- <Nome>: <uma linha do que faz>. Dono: P<n>. Contrato: docs/arquitetura.md §<x>.
local X = {}
function X.iniciar() ... end   -- obrigatório; chamado uma vez pelo init, na ordem do §2
-- funções públicas listadas no contrato
return X
```
- `iniciar()` não pode bloquear: laços vão em `task.spawn`.
- `require` de outro serviço: `require(script.Parent.<Nome>)`. Só chamar funções do outro serviço **depois** do
  `iniciar` (dentro de eventos/laços), nunca no topo do módulo.
- Comandos de teste do Studio: `require(script.Parent.Teste).registrar("nome", function(jogador, ...) end)` dentro do
  `iniciar` (o Teste só existe no Studio).

---

## 2. Ordem de início

Servidor (`src/server/init.server.luau`, pronto):
`Rede.criarTodos` → Teste → Sons → Ambiente → Visual → Ruido → Preferencias → Movimento → Vida → Sobrevivencia →
Inventario → Spawn → Loot → Monstros → Armas.

Cliente (`src/client/init.client.luau`, pronto):
SonsLocal → FiltroPS1 → Controles → Camera → Configuracoes → HudSom → Voz → DebugRuido → HudVida → InventarioUI →
ArmasCliente.

Cada `iniciar` é chamado dentro de `pcall`; erro de uma parte é impresso e as outras continuam.

---

## 3. Estado compartilhado (atributos)

### No `Player`
| Atributo | Tipo | Dono (escreve) | Quem lê |
|---|---|---|---|
| `Agachado`, `Correndo` | bool | Movimento | Ruido, Sobrevivencia, Camera, HudVida |
| `Usando` | bool | Inventario (true enquanto consome item) | Movimento (bloqueia correr), Armas (bloqueia ataque) |
| `Estamina`, `Fome`, `Sede`, `Calor` | number 0..100 | Sobrevivencia | Movimento, HudVida |
| `Vida_Cabeca`, `Vida_Torso`, `Vida_BracoE`, `Vida_BracoD`, `Vida_PernaE`, `Vida_PernaD` | number | Vida | HudVida |
| `MultVelocidade` | number | Vida (produto das pernas: 1, 0.6, 0.36) | Movimento |
| `PodeCorrer` | bool | Vida (false com perna zerada) | Movimento |
| `BracoZerado` | bool | Vida | Armas (mira, duas mãos) |
| `Morto` | bool | Vida | todos |
| `UltimoRuido` | number (dB) | Ruido | HudSom |
| `ArmaEquipada` | string? (id de Config/Armas) | Armas | ArmasCliente, HudVida |
| `Pref_Tremor`, `Pref_Intensidade`, `Pref_FOV`, `Pref_FiltroPS1`, `Pref_Volume` | ver Config/Camera | Preferencias | Camera, FiltroPS1, SonsLocal |

### No `workspace`
| Atributo | Dono | Valores |
|---|---|---|
| `Clima` | Visual (inicia com `Config/Tempo.climaPadrao`; Teste muda) | `"limpo"`, `"chuva"`, `"tempestade"` |
| `Condicao` | Ambiente | `"dia"`, `"noite"`, `"chuva"`, `"tempestade"` |
| `AmbienteDb` | Ambiente | number |

### No modelo de monstro (`workspace.Monstros.<Model>`)
`Monstro` = true, `Especie` (string), `Nivel` (number), `Estado` (`"Calmo"|"Investiga"|"Caca"|"Ataque"`), `Vida` (number).

### Pastas criadas em tempo de jogo
`workspace.Monstros` (Monstros), `workspace.Caixas` (Loot), `workspace.Bolsas` (Inventario), `workspace.SonsSoltos`
(Sons). Quem cria é o dono; outros usam `FindFirstChild` e tratam `nil`.

---

## 4. Rede (resumo do dono de cada evento)

Ver `src/shared/Rede.luau` para os argumentos.

| Evento | Direção | Dono (OnServerEvent / FireClient) | Validação mínima no servidor |
|---|---|---|---|
| `Agachar`, `Correr` | c→s | Movimento | boolean; Limite 0.1 s; ignorar se `Morto` |
| `SalvarPreferencias` | c→s | Preferencias | tabela; só chaves `Pref_*` conhecidas; números com `math.clamp` nos limites; Limite 1 s |
| `Voz` | c→s | Ruido | number finito; clamp `Config/Som.voz`; Limite `voz.intervalo` |
| `Equipar`, `Atacar` | c→s | Armas | ver §P7 |
| `UsarItem`, `LargarItem` | c→s | Inventario | slot inteiro 1..slots; item existe |
| `AbrirCaixa`, `PegarItem` | c→s | Loot | instância é caixa/bolsa real; distância ≤ `Itens.alcanceInteracao` |
| `MeuRuido`, `RuidoDebug` | s→c | Ruido | — |
| `Dano`, `Morreu` | s→c | Vida | — |
| `Inventario` | s→c | Inventario | — |
| `ConteudoCaixa` | s→c | Loot | — |
| `Acerto` | s→c | Armas | — |
| `Aviso` | s→c | qualquer serviço | — (HudVida mostra) |

Toda checagem de frequência usa `server/Limite.luau`: `Limite.ok(jogador, "<evento>", intervalo)`.

---

## 5. Contratos entre serviços do servidor

Funções públicas que outras partes chamam. Assinatura exata; quem implementa não muda.

### Sons (P3)
```lua
Sons.tocar(nome: string, onde: BasePart | Vector3, opcoes: { db: number?, volume: number? }?): Sound?
```
Escolhe uma variação de `Config/Sons[nome].ids`, pitch aleatório ±`variacao`, `Volume = cfg.volume × (opcoes.volume or 1)`,
`SoundGroup` = grupo do catálogo (SoundGroups criados por Sons em `SoundService`). Se `onde` é `Vector3`, cria uma peça
invisível ancorada em `workspace.SonsSoltos` e a remove depois. Se `opcoes.db` vier, `RollOffMaxDistance =
math.max(20, Som.alcance(db, Ambiente.db(), 0))` e `RollOffMode = InverseTapered`. Toca e limpa com `Debris` após
`TimeLength + 1` (ou 5 s se `TimeLength` for 0). Nome desconhecido → `warn` e `nil`.

### Ambiente (P3)
```lua
Ambiente.condicao(): "dia" | "noite" | "chuva" | "tempestade"
Ambiente.db(): number
```
Lê `workspace:GetAttribute("Clima")` e `Lighting.ClockTime` com `Regras/Som.condicao`. Atualiza os atributos
`Condicao` e `AmbienteDb` do workspace a cada 1 s.

### Ruido (P3)
```lua
export type EventoRuido = {
	posicao: Vector3,
	db: number,          -- emitido
	tipo: string,        -- nome da ação (Config/Som.acoes) ou "passo"
	fonte: Player | Model | nil,
	ambiente: number,    -- Ambiente.db() no momento
	tempo: number,       -- os.clock()
}
Ruido.emitir(posicao: Vector3, db: number, tipo: string, fonte: (Player | Model)?): ()
Ruido.emitirAcao(acao: string, posicao: Vector3, fonte: (Player | Model)?): ()  -- db = Config/Som.acoes[acao]
Ruido.aoRuido(callback: (EventoRuido) -> ()): ()                                -- Monstros registra aqui
```
`emitir` monta o evento, chama todos os callbacks (cada um em `task.spawn`), manda `MeuRuido` para a fonte se for
`Player`, atualiza `UltimoRuido`, e no Studio manda `RuidoDebug` para todos. **Não** calcula paredes nem quem ouve
(isso é de cada ouvinte).

Passos (interno do Ruido): laço a `Config/Som.hzAmostragem` por jogador vivo; velocidade horizontal do
`HumanoidRootPart`; `Regras/Som.modoPasso(vel, Agachado, Correndo)`; acumulador `+= dt × passosPorSegundo[modo]`; a cada
inteiro: superfície por `Humanoid.FloorMaterial` (`Air` = sem passo), `db = Som.emitido(modo, superficie)`,
`Sons.tocar("Passo"..Superficie, hrp, {db = db})`, `Ruido.emitir(hrp.Position, db, "passo", jogador)`.
Aterrissagem: `Humanoid.StateChanged` Freefall→Landed com a altura máxima da queda; emite `aterrissar` + som
`Aterrissar` (a parte do dano de queda é da Vida, que escuta o mesmo evento por conta própria).
Voz: evento `Voz` → `Ruido.emitir(cabeça, db, "voz", jogador)` sem som (a voz real já toca pelo chat de voz).

### Movimento (P2)
Sem funções públicas. Escuta `Agachar`/`Correr`, escreve `Agachado`/`Correndo`, aplica `Humanoid.WalkSpeed`:
`base = velocidadeCorrida | velocidadeAgachado | velocidade` × `MultVelocidade`. Correr só se `PodeCorrer ~= false`,
`Usando ~= true`, não agachado e `Estamina >= minimoParaVoltarACorrer` (ao ligar) / `> 0` (ao manter). Desliga
`Correndo` sozinho quando `Estamina` chega a 0. Reaplica no `CharacterAdded` e quando qualquer atributo lido muda.

### Preferencias (P2)
```lua
Preferencias.obter(jogador: Player, chave: string): any
```
Carrega do DataStore `"Preferencias_v1"` (chave = UserId) em `pcall`; falha (Studio sem API) → padrão sem repetir.
Escreve atributos `Pref_*`. Salva ao sair e no `SalvarPreferencias` (com Limite).

### Vida (P5)
```lua
export type FonteDano = { tipo: "monstro" | "jogador" | "queda" | "fome" | "sede" | "frio", jogador: Player?, direcao: Vector3? }
Vida.dano(jogador: Player, parte: string?, valor: number, fonte: FonteDano): ()   -- parte nil = sorteio de Config/Monstros.sorteioParte
Vida.curar(jogador: Player, valor: number): string?                               -- devolve a parte curada
Vida.estaVivo(jogador: Player): boolean
Vida.aoMorrer(callback: (jogador: Player, causa: string, posicao: Vector3) -> ()): ()
```
Usa `Regras/Corpo`. Escreve `Vida_*`, `MultVelocidade`, `PodeCorrer`, `BracoZerado`, `Morto`. Manda `Dano` ao jogador
atingido e toca `Dor`. Morte: `Morto = true`, `Humanoid.Health = 0`, `Morreu`, callbacks. Reset de tudo no
`CharacterAdded`. **O `Humanoid.Health` não é a vida do jogo**: mantém `MaxHealth = Health = 100` e desliga a
regeneração padrão (remover o script `Health` do personagem); só zera na morte.
Dano de queda: escuta o próprio personagem (Freefall→Landed, altura) e chama `Regras/Corpo.danoQueda`.

### Sobrevivencia (P5)
Sem funções públicas além de:
```lua
Sobrevivencia.alterar(jogador: Player, barra: "Fome" | "Sede" | "Calor" | "Estamina", delta: number): ()
```
(o Inventario usa para comida e bebida). Laço a cada `Config/Sobrevivencia.tick` com `Regras/Sobrevivencia.passo`;
condição do `Ambiente.condicao()`; dano por fome/sede/frio via `Vida.dano`.

### Spawn (P5)
```lua
Spawn.pontoAleatorio(): CFrame
```
No `CharacterAdded`, move o personagem para um `Mapa.Pontos` com `Name == "Spawn"` sorteado (+3 studs em Y). Sem
pontos (mapa ausente) → `CFrame.new(0, 10, 0)` e `warn`.

### Inventario (P6)
```lua
Inventario.dar(jogador: Player, id: string, qtd: number): number      -- devolve a sobra que não coube
Inventario.remover(jogador: Player, id: string, qtd: number): boolean
Inventario.contar(jogador: Player, id: string): number
Inventario.slot(jogador: Player, slot: number): { id: string, qtd: number }?
Inventario.aoMudar(callback: (jogador: Player) -> ()): ()
```
Usa `Regras/Inventario`. Manda `Inventario` ao cliente a cada mudança. `UsarItem`: comida/bebida →
`Sobrevivencia.alterar`; cura → `Vida.curar`; tempo de uso com `Usando = true` (cancela se morrer); ruído
`Ruido.emitirAcao(item.ruido, ...)` e som `Sons.tocar(item.som, hrp)`. Arma no `UsarItem` = nada (equipar é `Equipar`).
`LargarItem`: cria uma bolsa com 1 item. Morte (`Vida.aoMorrer`): tudo vai para uma bolsa em `workspace.Bolsas` na
posição da morte, que some após `Itens.bolsaDuracao`. Respawn com inventário vazio recebe `Itens.kitInicial`.

### Loot (P6)
O loot mora nos **móveis do mapa** (2026-11-02, substitui a caixa de madeira 3×2×2): cada móvel listado em
`Config/Compartimentos` vira compartimento com `ProximityPrompt` dentro da peça principal. Contrato: `docs/compartimentos.md`.
Conteúdo sorteado na primeira abertura por `Regras/Loot.sortear(Compartimentos.tabelas[categoria])`. `AbrirCaixa` → ruído
`abrirCaixa`, som `AbrirCaixa`, manda `ConteudoCaixa`. `PegarItem(container, indice)` vale para compartimento e bolsa:
`Inventario.dar`, atualiza o conteúdo, reenvia `ConteudoCaixa`. Vazio repõe após `Itens.reposicao`.
Bolsas são criadas pelo Inventario em `workspace.Bolsas`. **O conteúdo de caixas e bolsas fica em tabelas do servidor**,
indexadas pela instância (nunca em atributos). Para o Loot ler bolsas, o Inventario expõe:
```lua
Inventario.conteudoBolsa(bolsa: Instance): { { id: string, qtd: number } }?
Inventario.retirarDaBolsa(bolsa: Instance, indice: number): { id: string, qtd: number }?
```
Interação no cliente: `ProximityPrompt` (`ActionText = "Abrir"`, tecla E) criado pelo servidor em cada caixa e bolsa.
O `Triggered` no servidor já é a validação de distância do Roblox; o servidor ainda confere `Itens.alcanceInteracao`.
O evento `AbrirCaixa` do cliente existe para reabrir a janela sem prompt (validar igual).

### Monstros (P4)
```lua
Monstros.dano(modelo: Model, valor: number, atacante: Player?): ()
Monstros.ehMonstro(inst: Instance): Model?   -- sobe na hierarquia até achar Model com atributo Monstro
```
Ver §P4.

### Armas (P7)
Sem funções públicas. Ver §P7.

---

## 6. Mapa → contrato (P1 gera, P4/P5/P6 leem)

`workspace.Mapa` (vem de `mapa/Mapa.rbxm` pelo Rojo):
```
Mapa
├─ Chao/            ladrilhos (≤ 2048 por eixo), Material por zona
├─ Ruas/            asfalto, calçadas, avenidas
├─ Construcoes/     Model por construção: atributos Tipo ("casa"|"loja"|"predio"|"posto"|"galpao"|"guarda"),
│                   Zona, Andares, Interior = false. Blocos sólidos, CanCollide.
├─ Vegetacao/       árvores (tronco + copa), manchas de LeafyGrass
├─ Bordas/          muros invisíveis na borda do mapa
├─ Zonas/           Parts invisíveis cobrindo cada área, atributo Zona ("cidade"|"vila"|"floresta"|"fabrica"|"planicie"|"guarda")
└─ Pontos/          Parts invisíveis 1×1×1 (Transparency 1, CanCollide/CanQuery/CanTouch false, Anchored)
   ├─ "Spawn"   atributo Zona = nome da vila      (Config/Mundo.spawnsPorVila em cada vila)
   ├─ "Loot"    atributos Tabela (chave de Config/Itens.tabelas), Zona; na calçada em frente à construção
   └─ "Monstro" atributo Zona (chave de Config/Monstros.densidade); um por célula de densidade, no chão livre
```
Pontos ficam no chão (Y = topo da superfície + 0.5). O servidor sempre tem o mapa todo (streaming só afeta o cliente).

---

## P1 · Mapa e visual

**Entrega:** `ferramentas/gerar_mapa.luau` (Lune, gera `mapa/Mapa.rbxm` a partir de `Config/Mundo` e
`Config/Monstros.densidade`), `ferramentas/checar_mapa.luau` (adaptar de `.claude/skills/mapa-roblox/scripts/checar_mapa.luau`),
`src/server/Visual.luau`, `src/client/FiltroPS1.luau`.

- Gerador: determinístico (semente fixa em Config). Base no padrão de `../teste1/ferramentas/gerar_mapa.luau` (usar
  `@lune/roblox`, salvar com `roblox.serializeModel`). Cidade em grade de quarteirões; cada quarteirão com 2–6
  construções por sorteio de `cidade.tipos`; terrenos baldios com manchas de `LeafyGrass`. Vilas, fábrica (piso
  `DiamondPlate`, galpões de metal), planície, posto da guarda (madeira), avenidas ligando a cidade às áreas, floresta
  preenchendo o resto com distância mínima, sem árvore em rua/construção. Material de cada piso importa (som).
- Construção = um bloco (ou dois: corpo + telhado) por construção, cor por tipo com variação leve, PS1: sem textura,
  cores dessaturadas, `Material` real.
- Orçamento: ≤ 15.000 peças no total. Imprimir a contagem por pasta ao gerar.
- Checker: sem peça solta (todas Anchored), spawns em chão e longe de construção, pontos de loot alcançáveis do spawn
  (andar por ruas/chão: pode ser checagem por grade 2D de células livres), nenhuma peça maior que 2048. Sai com código
  ≠ 0 se falhar.
- `Visual.luau`: avança `Lighting.ClockTime` conforme `Config/Tempo`; define `workspace` atributo `Clima` inicial;
  registra no Teste `"hora"(h)` e `"clima"(nome)`.
- `FiltroPS1.luau` (cliente): sobreposição em tela cheia (`ScreenGui` "FiltroPS1", `IgnoreGuiInset = true`,
  `DisplayOrder = 100`, `ZIndex` alto, `Active = false`): `ImageLabel` com `rbxassetid://138954735210943` (dither; não
  conferido visualmente: conferir por `screen_capture` e trocar se não servir), `ResampleMode = Pixelated`,
  `ScaleType = Tile`, `TileSize` de 4–8 px, `ImageTransparency ≈ 0.9`; mais linhas de scanline finas (Frames de 1 px a cada
  3 px, transparência 0.92) se o dither não aparecer. Liga/desliga por `Pref_FiltroPS1`: também alterna
  `Lighting.Retro.Enabled` e `Lighting.Cor.Enabled` **no cliente** (mudança local). Iluminação base já está em
  `build.project.json` e `default.project.json` (Voxel, LightingStyle Soft, ColorGradingEffect Retro, ColorCorrection, Bloom, DepthOfField, Sky; sem Atmosphere).
- Verificação: `lune run ferramentas/gerar_mapa.luau`, `lune run ferramentas/checar_mapa.luau` verdes; `rojo build`
  verde; `pwsh scripts/checar.ps1` verde.

## P2 · Personagem e câmera

**Entrega:** `Regras/Camera.luau` + `tests/Camera.spec.luau`, `server/Movimento.luau`, `server/Preferencias.luau`,
`client/Controles.luau`, `client/Camera.luau`, `client/Configuracoes.luau`.

- `Regras/Camera`: 
  ```lua
  Camera.avancarFase(fase: number, passosPorSegundo: number, dt: number): number
  Camera.offset(fase: number, modo: string, intensidade: number, cfg): (number, number, number) -- dy, dx, rollGraus
  Camera.tremor(amplitude: number, t: number, duracao: number): number                          -- decaimento linear
  Camera.tremorAterrissagem(velVertical: number, cfg): number
  ```
  Fórmulas de `calculos.md §5`. Testes: fase 0 → offset 0; correr > andar > agachado; intensidade 0 → 0.
- `Controles` (cliente): teclas de `Config/Movimento.teclas`; manda `Agachar` (alterna) e `Correr` (segura); celular:
  botões na tela (Agachar, Correr) com `ContextActionService`. A tecla V é tratada pela Camera, não pelos Controles.
- `Camera` (cliente): primeira pessoa (`LockFirstPerson` vem do projeto). `RenderStepped` com
  `RunService:BindToRenderStep("CameraDinamica", Enum.RenderPriority.Camera.Value + 1, ...)`: modo pelo `Agachado`/
  `Correndo` do jogador e velocidade real; fase avança só andando; aplica `Humanoid.CameraOffset` (dy + agachado,
  dx) e roll multiplicando `Camera.CFrame` por `CFrame.Angles(0, 0, rad(roll))`; FOV interpolado (`Pref_FOV` como base,
  +8 correndo). Tremor de aterrissagem (estado Landed do próprio Humanoid), de golpe (evento `Dano`), e fino quando
  existe monstro com `Estado == "Caca"` a ≤ 40 studs (varrer `workspace.Monstros` a 4 Hz). `Pref_Tremor = false` ou
  intensidade 0 → nenhum balanço/tremor (FOV continua). Tecla V: alterna `CameraMode` Classic com
  `CameraMinZoomDistance = CameraMaxZoomDistance = 10` ↔ LockFirstPerson.
- `Configuracoes` (cliente): tecla P abre painel simples (ScreenGui "Configuracoes"): tremor on/off, intensidade
  (0/25/50/75/100), FOV (60..90 de 5 em 5), filtro PS1 on/off, volume. Botões grandes (≥ 44 px). Ao mudar, manda
  `SalvarPreferencias` e só reflete quando o atributo `Pref_*` voltar do servidor. Som de clique via
  `SonsLocal.tocar("Clique")`.
- Verificação: testes Lune; no playtest (`execute_luau` Server), `Humanoid.WalkSpeed` = 8/16/24 nos três modos, e
  correr bloqueado com `Estamina = 0`.

## P3 · Som

**Entrega:** `Regras/Som.luau` + `tests/Som.spec.luau`, `server/Sons.luau`, `server/Ambiente.luau`, `server/Ruido.luau`,
`client/SonsLocal.luau`, `client/HudSom.luau`, `client/Voz.luau`, `client/DebugRuido.luau`.

- `Regras/Som`:
  ```lua
  Som.superficieDeMaterial(nomeMaterial: string): string          -- Config/Som.superficies; desconhecido = superficiePadrao
  Som.emitido(acao: string, superficie: string?): number          -- acoes[acao] + superficies[sup].db (sup só para passos)
  Som.recebido(emitido: number, distanciaStuds: number, paredes: number): number
  Som.alcance(emitido: number, ambiente: number, margem: number): number   -- studs, teto, 0 se inaudível
  Som.excesso(recebido: number, ambiente: number, margem: number): number  -- >= 0 ouve
  Som.condicao(clockTime: number, clima: string?): string
  Som.ambiente(condicao: string): number
  Som.modoPasso(velocidade: number, agachado: boolean, correndo: boolean): "parado" | "agachado" | "andar" | "correr"
  Som.vozParaDb(rms: number): number                               -- 20·log10(rms) + 90, clamp 0..120
  ```
  Distância < 1 m vale 1 m. Teste obrigatório: reproduzir **cada linha da tabela 1.4** de `calculos.md` (tolerância
  ±1 stud) e os casos de parede (cada parede −10 dB, máximo 3).
- `Sons`, `Ambiente`, `Ruido`: contratos do §5. Ruido também registra no Teste `"ruido"(db)` (emite na posição do
  jogador).
- `SonsLocal` (cliente):
  ```lua
  SonsLocal.tocar(nome: string): ()        -- som 2D (UI, coração)
  SonsLocal.loop(nome: string, ligado: boolean): ()
  ```
  SoundGroups locais respeitando `Pref_Volume`. Ambiente: loop pela `workspace.Condicao` (noite/dia/chuva), troca com
  fade de 2 s. Coração: loop quando existe monstro em Caça a ≤ 40 studs (mesma varredura de 4 Hz descrita na Camera;
  pode duplicar a varredura, é barata).
- `HudSom` (cliente): medidor de decibéis (ScreenGui "HudSom", canto inferior direito): barra 0..120 dB com a marca do
  `AmbienteDb`, valor do último `MeuRuido`, cor verde/amarela/vermelha (`Config/Som.medidor`), decai em 1 s.
- `Voz` (cliente): se `VoiceChatService` permitir e existir `AudioDeviceInput` do jogador local (API nova está ativa:
  `VoiceChatService.UseAudioApi = Enabled`), liga `AudioDeviceInput → Wire → AudioAnalyzer`, lê `RmsLevel` a 4 Hz e manda
  `Voz(Som.vozParaDb(rms))` só quando ≥ `Config/Som.voz.minimo`. Sem voz → não faz nada. Tudo em `pcall`.
- `DebugRuido` (cliente, só `RunService:IsStudio()`): no `RuidoDebug`, desenha um círculo achatado (Cylinder fino,
  transparente, sem colisão) com raio = alcance, some em 1 s. Liga/desliga com F8.
- Verificação: testes Lune; playtest com o comando `ruido`.

## P4 · Monstros

**Entrega:** `Regras/Percepcao.luau` + `tests/Percepcao.spec.luau`, `server/Monstros.luau`.

- `Regras/Percepcao` (sem Vector3: posições como `{x: number, y: number, z: number}`):
  ```lua
  export type Estado = { estado: string, alvo: {x,y,z}?, ultimoSom: number, sons: {number}, desde: number }
  Percepcao.novo(agora: number): Estado
  Percepcao.ouvir(e: Estado, excesso: number, posicao: {x,y,z}, agora: number, cfg): Estado
  Percepcao.tick(e: Estado, agora: number, cfg): Estado          -- timeouts Investiga/Caça
  Percepcao.estimar(real: {x,y,z}, distancia: number, rng: () -> number, cfg): {x,y,z}
  Percepcao.velocidade(nivel: number, estado: string, cfg): number
  ```
  Regras da tabela de `calculos.md §2.1`. Testes: excesso 5 → Investiga; excesso 12 → Caça; 2 sons em 4 s → Caça;
  12 s calado → Calmo; erro da estimativa ≤ distância × 0.15.
- `server/Monstros`:
  - Nasce um monstro em cada `Mapa.Pontos` "Monstro" (até `maxPorServidor`), espécie sorteada entre as de
    `nivel <= nivelAtivoMaximo`. Modelo: clona `ServerStorage.Modelos.Monstros[especie.modelo]` se existir; senão monta
    boneco de blocos (corpo `tamanho`, cabeça, cor da espécie, `Material = SmoothPlastic`). Sempre: `Humanoid`
    (`WalkSpeed` pela Percepcao, sem animação: desliza), `HumanoidRootPart`, `PrimaryPart`, atributos do §3,
    `ModelStreamingMode = Atomic`, `Parent = workspace.Monstros`, `SetNetworkOwner(nil)`.
  - Ouvir: `Ruido.aoRuido(evento)`. Para cada monstro vivo a ≤ `Config/Som.tetoAlcance`: `recebido` sem paredes; se
    pode ouvir, conta paredes com até 3 raycasts (`RaycastParams` excluindo personagens e monstros; cada acerto em
    `Mapa.Construcoes` conta 1 e o raio continua do ponto atingido + 0.1 na mesma direção) e recalcula; ignora ruídos
    do próprio monstro. `excesso >= 0` → `Percepcao.ouvir` com posição estimada.
  - Laço de IA a 5 Hz: `Percepcao.tick`; Calmo → vagar até ponto aleatório em `raioVagar` do nascimento; Investiga/
    Caça → `PathfindingService:CreatePath({AgentRadius, AgentHeight, AgentCanJump = false})` até o alvo, recalcula só
    quando o alvo muda (ou após `recalcularCaminhoMin`), segue waypoints com `Humanoid:MoveTo`. Entrar em Caça com
    `gritaAoCacar` → `Sons.tocar("GritoMonstro", hrp, {db = acoes.gritoMonstro})` + `Ruido.emitirAcao("gritoMonstro",
    hrp.Position, modelo)`. Rosnado ocasional (`RosnadoMonstro`, a cada 8–20 s, sem ruído de jogo).
  - Ataque: jogador vivo a ≤ `distanciaAtaque` (qualquer estado: toque) → `Vida.dano(jogador, nil, nivel.dano,
    {tipo = "monstro", direcao})` respeitando `intervaloGolpe`; estado `Ataque` enquanto perto.
  - Distância de processamento: monstro sem jogador a ≤ 700 studs e em Calmo pausa a IA (economia).
  - `Monstros.dano`: reduz `Vida`; em 0 → some após 3 s (sem animação: tomba o modelo); renasce no mesmo ponto após
    3 min. Monstro atingido entra em Caça com alvo na posição do atacante.
  - Teste: `"monstro"(especieId?)` nasce um na frente do jogador; `"monstros"()` imprime contagem por estado.
- Verificação: testes Lune; playtest: monstro nasce, investiga um `ruido 60` a 50 studs, ignora `ruido 25`.

## P5 · Vida e sobrevivência

**Entrega:** `Regras/Corpo.luau` + `tests/Corpo.spec.luau`, `Regras/Sobrevivencia.luau` + `tests/Sobrevivencia.spec.luau`,
`server/Vida.luau`, `server/Sobrevivencia.luau`, `server/Spawn.luau`, `client/HudVida.luau`.

- `Regras/Corpo`:
  ```lua
  export type Corpo = { [string]: number }   -- vida atual por parte (chaves de Config/Corpo.ordem)
  Corpo.novo(cfg): Corpo
  Corpo.dano(c: Corpo, parte: string, valor: number, cfg): (Corpo, boolean)   -- (novo, morreu); transbordo p/ torso
  Corpo.curar(c: Corpo, valor: number, cfg): (Corpo, string?)
  Corpo.sortearParte(sorteio: {{parte: string, peso: number}}, rng: () -> number): string
  Corpo.multVelocidade(c: Corpo, cfg): number
  Corpo.podeCorrer(c: Corpo): boolean
  Corpo.bracoZerado(c: Corpo): boolean
  Corpo.danoQueda(altura: number, cfg): number    -- total (Vida divide entre PernaE/PernaD)
  ```
  Não muta a entrada (devolve cópia). Testes: transbordo (braço 35 recebe 45 → braço 0, torso −5); cabeça 0 → morreu;
  duas pernas zeradas → 0.36; queda de 12 → 0, de 20 → 24.
- `Regras/Sobrevivencia`:
  ```lua
  export type Barras = { Fome: number, Sede: number, Calor: number, Estamina: number }
  export type Contexto = { correndo: boolean, agachadoParado: boolean, condicao: string, dentro: boolean,
                           pertoFogo: boolean, tempoSemCorrer: number }
  Sobrevivencia.passo(b: Barras, dt: number, ctx: Contexto, cfg): (Barras, { fome: boolean, sede: boolean, frio: boolean })
  Sobrevivencia.estaminaMaxima(b: Barras, cfg): number
  ```
  O segundo retorno diz quais barras estão em 0 (o serviço aplica dano no intervalo do Config). Testes: 60 min parado
  → fome ≈ 0; 8 s correndo → estamina ≈ 4; volta depois de 1.5 s.
- Serviços: contratos do §5. `dentro` e `pertoFogo` = false no corte vertical (construções são blocos).
- `HudVida` (cliente, ScreenGui "HudVida", canto inferior esquerdo): 4 barras (fome, sede, calor, estamina) e um boneco
  de 6 partes (Frames) com cor por % de vida (verde → amarelo → vermelho → preto zerada). Flash vermelho na borda no
  evento `Dano`. Tela de morte no `Morreu` ("Você morreu" + causa + contagem de 10 s). Avisos do evento `Aviso`
  (centro inferior, 3 s).
- Verificação: testes Lune; playtest com Teste `"dano"(parte, valor)`, `"barras"(fome, sede, calor, estamina)`.

## P6 · Inventário e loot

**Entrega:** `Regras/Inventario.luau` + `tests/Inventario.spec.luau`, `Regras/Loot.luau` + `tests/Loot.spec.luau`,
`server/Inventario.luau`, `server/Loot.luau`, `client/InventarioUI.luau`.

- `Regras/Inventario` (inventário = lista de `slots` posições, cada uma `{id, qtd}?`):
  ```lua
  Inventario.novo(slots: number): { [number]: {id: string, qtd: number}? }
  Inventario.adicionar(inv, id: string, qtd: number, itens): (inv, number)   -- empilha até item.pilha; devolve sobra
  Inventario.remover(inv, id: string, qtd: number): (inv, boolean)
  Inventario.retirarSlot(inv, slot: number, qtd: number?): (inv, {id: string, qtd: number}?)
  Inventario.contar(inv, id: string): number
  Inventario.lista(inv): { {id: string, qtd: number} }
  ```
  Não muta a entrada. Testes: empilhamento, sobra, remover mais do que tem → false sem mudar.
- `Regras/Loot`:
  ```lua
  Loot.sortear(tabela, rng: () -> number): { {id: string, qtd: number} }   -- rolagens {min,max}; peso; qtd {min,max}
  ```
  Testes com `util.seq`: resultado determinístico; nunca qtd 0; ids existem em `Config/Itens.itens`.
- Serviços: contratos do §5. Teste: `"dar"(id, qtd)`, `"inv"()`.
- `InventarioUI` (cliente, ScreenGui "InventarioUI"): barra de 8 slots no centro inferior (sempre visível, número da
  tecla 1–8, nome curto e qtd). Teclas 1–8: se arma → `Equipar(slot)` (de novo no mesmo slot → `Equipar(nil)`);
  senão → `UsarItem(slot)`. Tab abre lista com botão "Largar". Janela de caixa/bolsa ao receber `ConteudoCaixa`
  (lista com botão "Pegar" por item → `PegarItem`; fecha com E, Tab, ou ao se afastar 10 studs). Barra de progresso
  enquanto `Usando`.
- Verificação: testes Lune; playtest abrindo caixa, pegando, comendo, morrendo e pegando a bolsa.

## P7 · Armas e PvP

**Entrega:** `Regras/Armas.luau` + `tests/Armas.spec.luau`, `server/Armas.luau`, `client/ArmasCliente.luau`.

- `Regras/Armas`:
  ```lua
  Armas.podeAtacar(ultimoAtaque: number, agora: number, cadencia: number): boolean
  Armas.origemValida(origem: {x,y,z}, cabeca: {x,y,z}, tolerancia: number): boolean
  Armas.espalhar(direcao: {x,y,z}, graus: number, rng: () -> number): {x,y,z}     -- unitário
  Armas.dano(arma, parteJogo: string, cfgCorpo): number                         -- cabeça × multCabecaArma
  Armas.multEspalhamento(bracoZerado: boolean, cfgCorpo): number
  ```
- `server/Armas`:
  - `Equipar(slot?)`: valida que o slot tem item `tipo = "arma"`; arma de duas mãos negada com `BracoZerado`; escreve
    `ArmaEquipada`. Sem `Tool` do Roblox: a arma na mão é um bloco simples soldado à `RightHand` (`Weld`), nome
    `ArmaNaMao`. Desequipar remove.
  - `Atacar(origem, direcao)`: valida tipos (Vector3, direção com magnitude 0.5..1.5 → normaliza), jogador vivo, não
    `Usando`, arma equipada, `podeAtacar` (cadência guardada no servidor), `origemValida` contra a cabeça. Corpo a corpo:
    `workspace:Spherecast` (raio 1.5) ou `Raycast` até `alcance + toleranciaAlcance`, excluindo o próprio personagem.
    Fogo: precisa de 1 `municaoPistola` (`Inventario.remover`), espalhamento × `multEspalhamento`, `Raycast` até
    `alcance`. Acerto em personagem de jogador → parte pelo `Config/Corpo.r15` → `Vida.dano(alvo, parte,
    Armas.dano(...), {tipo = "jogador", jogador = atacante, direcao})`; em monstro (`Monstros.ehMonstro`) →
    `Monstros.dano`. Sempre: `Sons.tocar(arma.som, ...)`, `Ruido.emitir(posicao, arma.ruidoDb, "arma", jogador)`;
    acerto: `Sons.tocar(arma.somAcerto, ponto)` e `Acerto` para o atacante.
  - Teste: `"arma"(id)` dá a arma e equipa.
- `ArmasCliente`: clique esquerdo (ou botão na tela no celular) com arma equipada → `Atacar(camera.CFrame.Position,
  camera.CFrame.LookVector)`; cadência local só para não spammar (o servidor decide); marcador de acerto no `Acerto`;
  mira simples (ponto no centro, ScreenGui "Mira").
- Verificação: testes Lune; playtest com 2 clientes: acerto no corpo tira vida da parte certa; ataque com origem
  forjada a 20 studs é rejeitado (log).

---

## 7. Regras para quem escreve código (todas as partes)

1. Luau com `--!strict` nas Regras; serviços podem ser não-strict, mas sem `any` desnecessário.
2. Estilo: tabs, aspas duplas, coluna 120 (StyLua do projeto). Nomes em português como o resto (`iniciar`, `jogador`).
3. Comentário só onde o porquê não é óbvio; cabeçalho de 1–2 linhas por arquivo dizendo o que faz e o dono.
4. Nada de API inventada. Na dúvida, conferir na doc oficial (create.roblox.com) ou no Studio pelo MCP
   (`execute_luau` em modo Edit, sem salvar nada no place). Studio aberto: `Local de kay_113p: 11012026_1`
   (studio_id `3186311d-271b-4019-b58c-9acf54b60351`). **Não** rodar playtest nem `multi_edit` nele durante o trabalho
   em paralelo (outras partes usam o mesmo Studio); só leitura e conferência de API.
5. Checagem antes de entregar: `pwsh scripts/checar.ps1` (as 4 checagens). Erros de selene/stylua **nos seus
   arquivos** são seus; nos dos outros, ignorar. Rodar `stylua <seus arquivos>` para formatar.
6. Entregar no fim um resumo: arquivos criados, funções públicas, o que foi verificado, o que ficou em
   `docs/pendencias-integracao.md`.

---

## 8. Adendos depois do primeiro playtest (2026-11-01)

- **Teclas** (`client/Teclas.luau`): `Teclas.ligar(nome, {nomes de KeyCode}, funcao)` liga um atalho por InputBegan (ignora `processado`)
  e por ContextActionService (High, Sink), com intervalo mínimo de 0,15 s. No Studio imprime `[Teclas] nome: Tecla (processado=…)`.
  Teclas em `Config/Movimento.teclas` e `Config/Admin.tecla`.
- **Mouse** (`client/Mouse.luau`, iniciado antes de todos): dono único do cursor (força `MouseBehavior = Default` a cada quadro com menu aberto). Menus chamam
  `Mouse.pedir("Nome")` ao abrir e `Mouse.liberar("Nome")` ao fechar; `Mouse.menuAberto()` bloqueia o tiro.
  Menus atuais: Configuracoes, Inventario, Caixa, Admin. Fora deles: `MouseIconEnabled = false` na primeira pessoa.
- **Inventário (Tab)**: tela em `client/InventarioUI.luau` (grade 4×2, detalhes do item, Usar/Equipar/Guardar/Largar,
  corpo e estado atualizados a 2 Hz). O texto de ajuda de cada item sai de `Config/Itens`, `Config/Armas` e `Config/Som`.
- **Spawn** (`server/Spawn.luau`): cria um `SpawnLocation` fino em cada ponto `Spawn` (pasta `workspace.SpawnsJogo`) e
  sorteia `Player.RespawnLocation` a cada nascimento. Um `PivotTo` logo no `CharacterAdded` é desfeito pelo motor.
- **Agachar** (`server/Movimento.luau`): `aplicarPose` mexe no C0 de Hip/Knee/Ankle/Root e no `HipHeight`
  (`Config/Movimento.agachado`). Só R15. `Config/Camera.alturaOlhosAgachado` é só o ajuste fino da câmera.
- **Dia/noite** (`server/Visual.luau`): a luz (Ambient, OutdoorAmbient, Brightness, névoa Fog*, Cor, Brilho, Profundidade; sem Atmosphere, que anula a névoa; `Regras/Luz.luzDaHora`) é misturada pela altura
  do sol; números em `Config/Tempo.luz`. `Visual.definirHora(h)`, `Visual.congelar(b)`. Clima multiplica a luz.
- **Admin**: `server/Admin.luau` (evento `Admin`, ações: dar, hora, congelar, clima, voar, imortal, curar; confere
  `Admin.autorizado`) e `client/Admin.luau` (O, voo por `LinearVelocity` quando `AdminVoar` é true). Atributos do
  jogador: `Admin`, `AdminVoar`, `AdminImortal`, `Imortal` (lido por `server/Vida`).
- **Gancho de teste do Studio**: atributo `TesteUI` no jogador abre menus ("inventario#1", "admin#1", "config#1"); a
  simulação de teclado do MCP não chega ao jogo.
- **Aparência dos jogadores** (`server/Aparencia.luau`, `client/Aparencia.luau`, `Config/Aparencia.luau`): todo personagem R15 vira
  o modelo do jogo, só por código, baseado no personagem de suéter dentro do carro. As peças do avatar ficam invisíveis
  (seguem como física/animação/hitbox) e um bloco colorido é soldado em cada uma: cabeça cúbica escura com rosto
  (SurfaceGui: olhos, pupilas, boca), suéter mostarda de Fabric com costura vertical, mãos escuras, calça e sapato escuros.
  Acessórios e roupa do avatar são removidos. O cliente esconde a cabeça do próprio jogador na primeira pessoa
  (etiqueta `AparenciaCabeca`). Só R15. Aplicado depois de `CharacterAppearanceLoaded`.
  **v2 (2026-11-02):** antes de revestir, `server/Aparencia` aplica as escalas R15 de `Config/Aparencia.escala` (NumberValue no
  Humanoid) e espera `esperaEscala` s; a cabeça é medida a partir do tronco; ganha cabelo trançado (laje, bolinhas, faixas),
  sobrancelhas e língua; o tronco ganha bolso e cordões; o LowerTorso é o cinto com fivela; as coxas são a bermuda; o pé tem
  cabedal rosa e sola branca. Não testado no Studio.
