# Monstros: lógica das habilidades e mecânicas (contrato de implementação)

Escrito em 2026-11-14 (Opus), a partir das fichas `docs/monstros/<monstro>.md` **com as mudanças que o usuário escreveu nelas** (§0).
Lógica = Opus · código = Sonnet 5.5 (3 agentes, §8) · animações = Opus (§7) · revisão = Opus.
Números marcados `PROVISÓRIO` não foram medidos: ficam em `Config/PresetsMonstro` e se ajustam no playtest. Nenhum número solto no código.

Unidades: studs. Escalas usadas aqui: personagem 5,234 studs = 1,8 m (monstros); carros `Config/Veiculos.velMax` (normal 45–58 studs/s, esportivo 78).

---

## 0. Decisões do usuário (2026-11-14, escritas nas fichas)

| Monstro | O que o usuário pediu | Onde entra |
|---|---|---|
| Rastejador | mais dano em parede, quebra mais rápido, buraco maior; **depois de entrar numa casa, procura o jogador lá dentro** | §3.2, §3.3 |
| Wrapper | **sem grito**: um **sonar** que solta uma **onda visível** (o jogador vê o raio e se foi atingido); **algo entre os dois bloqueia**; se detectar, **se joga** na sua direção. O som é um **grito abafado** (não tem boca) | §4 |
| Corcunda | **joga o jogador no chão com um impulso**; **abre e fecha porta**; **enxerga um pouco**; a imitação inclui **falas curtas em inglês baixadas da internet** | §5 |
| MonstroPS1 | **lança as lâminas**: pouco dano, baixa precisão | §6.3 |
| Florescida | **mais rápida que um carro normal** ("chega a 50 km/h"); **não entra em cidade grande** | §7.1 |

Interpretações que eu (Opus) fiz e que o usuário pode corrigir:
- **Velocidade da Florescida:** "50 km/h" e "mais rápida que carro normal" não batem nas unidades do jogo (50 km/h ≈ 40 studs/s, carro normal faz 45–58).
  Vale a **frase do comportamento**: caça a **60 studs/s** (passa carro normal, perde para esportivo 78). `PROVISÓRIO`.
- **Sonar do Wrapper:** detecta **quem a onda alcança com linha de visão livre**, parado ou não (o usuário trocou o "parado = invisível" pela regra
  da linha de visão). Agachado não muda nada: o que salva é ter parede, carro ou prop entre os dois.
- **"Cidade grande"** = a zona `cidade` do mapa (`Mapa.Zonas`, atributo `Zona = "cidade"`). Vilas, floresta e fábrica valem.
- **Portas:** o mapa não tem porta funcional (a "Folha" é decorativa, entreaberta e sem colisão). Para o Corcunda abrir/fechar porta, entra um
  **sistema de portas** (§2.1), que o **jogador também usa**. Ele monta as portas em tempo de execução, **sem mudar o arquivo do mapa** (regra 4).
- **Monstro machuca monstro** (Wrapper batendo noutro): **não** (dano 0). **Escada lenta do Wrapper:** fora desta rodada.

---

## 1. Peças comuns já existentes (não reinventar)

| Peça | Onde | Uso aqui |
|---|---|---|
| Percepção por som | `Regras/Percepcao` (`ouvir`, `tick`, `estimar`) | toda detecção nova vira `ouvirSom(d, excesso, pos, agora)` com `excesso >= estados.investigaAte` (= Caça) e **posição exata** |
| Ruído | `server/Ruido.emitir(pos, db, tipo, fonte)` | todo som novo de monstro/porta/lâmina emite ruído |
| Lunge | `Regras/Lunge` + `passoLunge` em `Monstros.luau` | investida do Wrapper (alvo vindo do sonar) |
| Destruição | `Destruicao.dano(inst, qtd, info)`, `golpesPara`, `vaoUtil`, `explosao` | paredes, portas, props, fachada |
| Arrombar | `server/MonstroArrombar` | Rastejador (números novos), Florescida (fachada, §7.4) |
| Arremesso | `Regras/Arremesso.simular` | lâmina lançada (§6.3) |
| Deitado | atributo `Deitado` em `server/Movimento` | base do "derrubado" (§2.2) |
| ProximityPrompt | já usado no Loot (1105 prompts) | portas |
| Clipe com tempo | `d.clipe` / `d.golpeAte` / `animar(d, agora, true)` | toda ação especial (§2.4) |

---

## 2. Sistemas novos comuns

### 2.1 Portas (novo; dono: agente B)
- **Montagem:** ao iniciar o servidor, para cada peça `Folha` sob `Mapa.Construcoes` (e `ZonaTeste.Construcoes`), cria uma porta: dobradiça na
  lateral onde a folha está presa (`lib.luau` do mapa: "presa à lateral esquerda", entreaberta a 75°). A porta guarda `aberta` (bool), o ângulo
  fechado (0°) e o aberto (90°). Começa **aberta** (como o mapa já é). Fechada = `CanCollide = true`, `CanQuery = true`; aberta = sem colisão.
  Em lotes com `task.wait()` (são centenas a milhares de portas).
- **Movimento:** Tween de 0,35 s (abrir/fechar normal). `bater` = fechar em 0,15 s (porta batida).
- **Jogador:** `ProximityPrompt` na folha, `E`, distância 6, `RequiresLineOfSight = true`, texto "Abrir"/"Fechar". Abrir agachado = **silencioso**.
- **Ruído:** abrir 45 dB, fechar 50 dB, bater 65 dB, abrir agachado 25 dB (tipos `portaAbrir`, `portaFechar`, `portaBater`). Sons `PortaAbrir`, `PortaFechar`, `PortaBater`.
- **Destrutível:** a folha é madeira na `Destruicao` (já classifica por material). Quebrou = some a porta.
- **Navegação:** porta fechada bloqueia o caminho; depois de mexer numa porta, chamar `Monstros.invalidarCaminhos(pos, 12)`.
- **API (B exporta, A usa):**
  - `Portas.naLinha(de: Vector3, ate: Vector3, raio: number): Porta?`: a porta **fechada** mais próxima cortando o segmento (para o monstro decidir abrir ou arrombar).
  - `Portas.perto(pos: Vector3, raio: number): { Porta }`.
  - `Portas.abrir(porta, quem: (Player | Model)?, silencioso: boolean?)`, `Portas.fechar(porta, quem, bater: boolean?)`, `Portas.estaAberta(porta): boolean`, `Portas.posicao(porta): Vector3`.
- **Quem usa porta:** só o **Corcunda** abre/fecha (§5.3). Rastejador, Wrapper e Florescida tratam porta fechada como parede (arrombam/batem; madeira cai em
  1–2 golpes). MonstroPS1 **corta** (§6.4).

### 2.2 Derrubado (novo; dono: agente B)
- `Movimento.derrubar(jogador, segundos: number, impulso: Vector3)`: liga `Deitado = true` e um atributo **`Derrubado`** (número: `workspace:GetServerTimeNow()` do fim; o cliente compara com o mesmo relógio).
  Enquanto `Derrubado` estiver valendo, o pedido de levantar/agachar do cliente é **ignorado**. Aplica `impulso` no `HumanoidRootPart`
  (`AssemblyLinearVelocity += impulso`). Ao acabar, desliga `Derrubado` e **volta para agachado** (não de pé direto: o jogador levanta com C).
- Se o jogador estiver num carro: não derruba (ignora).
- Cliente (agente C): texto "Derrubado" no HUD e câmera com tremor curto (`Config/Camera`, se já houver tremor de dano, reaproveitar).
- Usado por: Corcunda (empurrão, §5.2) e Florescida (rugido, §7.3; cauda empurra sem derrubar).

### 2.3 Habilidades por espécie (novo; dono: agente A)
- `server/MonstroHabilidades.luau` (despachante) + um arquivo por espécie em `server/Habilidades/<Especie>.luau`. Cada um exporta
  `iniciar(d)`, `passo(d, agora, ctx) -> boolean` (true = a habilidade tomou o controle do movimento neste tick), `aoOuvir(d, evento)` (opcional),
  `aoMorrer(d)` (opcional). `ctx = { jogadores, maisPerto, distPerto }`.
- `passoMonstro` chama `MonstroHabilidades.passo` **antes** do bloco de movimento. Se devolver true, o resto do movimento do tick é pulado
  (o ataque normal por toque continua valendo, salvo quando a habilidade marca `d.semGolpeNormal = true`).
- Regras puras (recargas, cones, escolha de pontos, zona, mira com erro) em `Regras/Habilidades.luau`, testadas em Lune (`tests/Habilidades.spec.luau`).
- Números de cada habilidade no preset da espécie: `PresetsMonstro.<preset>.habilidades.<nome> = { ... }`.
- Sem malha/clipe: a habilidade **funciona igual** (só não anima). Clipe ausente em `MonstrosMalhas` = usar o tempo padrão do preset.

### 2.4 Clipes de ação e eventos de tempo (contrato com as animações)
- `MonstrosMalhas[id].eventos[clipe] = { impacto = s, soltar = s, ... }` (gerado pelo `gerar_config_monstros.py` a partir do manifesto; agente D).
- Função única em `Monstros.luau`: `tocarAcao(d, clipe, agora) -> duracao` (põe `d.clipe`, `d.golpeAte = agora + duracao`, reinicia) e
  `evento(d, clipe, nome, padrao) -> s`. O dano de qualquer golpe acontece em `agora + evento(...)`, nunca no início do clipe.
- O clipe `Death` substitui o `tombarTween` quando existir (Wrapper passa a ter Death).

### 2.5 Zonas (novo; dono: agente A)
- `Regras/Habilidades.dentroDeZona(pos, zonas, nome) -> boolean`: caixas das peças de `Mapa.Zonas` com atributo `Zona` (lidas uma vez).
- Usado pela Florescida (§7.1).

### 2.6 Limite por espécie (dono: agente A)
- `Config/Monstros.especies[i].maxPorServidor` (opcional). `popular()` respeita; `Monstros.invocar` (admin) pode passar até `maxAdmin`.
- Florescida: `maxPorServidor = 1`, `maxAdmin = 2`, e só nasce em ponto **fora** da zona `cidade`.

### 2.7 Onda de sonar no cliente (novo; dono: agente C)
- Evento `Rede` **`MonstroSonar`** (servidor → todos os clientes a ≤ 120 studs): `(origem: Vector3, raio: number, velocidade: number, id: number)`.
- Evento **`SonarAtingido`** (servidor → só o jogador): `(id: number, detectado: boolean)`. Chega quando a frente da onda passa por ele.
- Cliente `src/client/MonstroSonar.luau`: esfera translúcida (Neon, cor fria pálida, Transparency 0,85 → 1) crescendo de 0 até `raio` a `velocidade`;
  anel no chão (Beam ou cilindro fino) para ler o raio. Ao receber `SonarAtingido`:
  - `detectado = true`: borda vermelha na tela 0,6 s + som `SonarDetectado` (alto, seco) + HUD "DETECTADO".
  - `detectado = false` (a onda passou, mas havia algo no meio): pulso azul fraco 0,3 s + som `SonarPassou` (baixo). O jogador aprende que a cobertura funcionou.
- Respeita o filtro (não desligar névoa); funciona em 1ª e 3ª pessoa.

---

## 3. Rastejador (nível 1, `quadrupedeArrombador`)

### 3.1 Pulso no chão (aprovado na ficha)
- **Gatilho:** em Investiga, ao chegar a ≤ 4 studs do alvo estimado sem achar ninguém; e em **Busca** (§3.3) em cada ponto visitado. Recarga 15 s.
- **Ação:** clipe `Pulso` (2,0 s; o corpo desce até o chão). Durante o clipe: parado, sem golpe (`semGolpeNormal`).
- **Efeito (janela de 4 s a partir do evento `encostou` do clipe, padrão 0,4 s):** a cada 0,25 s, todo jogador a ≤ 25 studs **andando**
  (`velocidade horizontal ≥ 1,5`) e **não** `Agachado`/`Deitado` vira detecção: `ouvirSom` com posição exata (Caça). Correndo também conta.
  Dentro de carro não conta.
- **Som:** `PulsoChao` (raspar grave) no início, 40 dB de ruído (não chama ninguém longe).
- Números: `habilidades.pulso = { raio = 25, janela = 4, recarga = 15, velMinima = 1.5, db = 40 }`.

### 3.2 Arrombar mais forte (pedido do usuário)
Muda só números em `PresetsMonstro.quadrupedeArrombador.arrombar` (o resto da lógica de `MonstroArrombar` fica):

| Número | Antes | Agora | Efeito |
|---|---|---|---|
| `dano` | 60 | **150** | concreto ~8 golpes (era 20), tijolo ~6, madeira 1 |
| `intervalo` | 1,2 s | **0,9 s** | |
| `folgaLargura` | 1,6 | **2,2** | vão mais largo que o corpo |
| `alturaBuraco` | 9 | **11** | |
| `golpesMax` | 60 | 60 | (com 150 de dano, paredes que antes eram ignoradas viram alvo) |
| clipe | Attack | **`Arrombar`** (0,9 s, `impacto` 0,45) | golpe próprio, mais violento |

### 3.3 Busca dentro da casa (pedido do usuário)
- **Quando:** o Rastejador **passa por um vão que ele abriu** (`Destruicao.aoQuebrar` com fonte = ele; guardar `d.vaoAberto = { pos, construcao, quando }`)
  **ou** entra numa construção (centro dentro da caixa de um Model de `Construcoes`) estando em Investiga/Caça, e nesse momento **não** tem
  percepção nova há ≥ 2 s.
- **Estado novo `Busca`** (dentro da habilidade; para a `Percepcao` ele segue em Investiga, mas o `tick` não o devolve a Calmo enquanto durar):
  1. Monta até 8 **pontos de busca** dentro da construção: grade de 6 studs na caixa do Model, no andar do monstro (±4 studs de altura), cada ponto
     validado por raycast para baixo achando piso a ≤ 6 studs e sem móvel em cima (raycast para cima livre por 4 studs). Prioridade: mais longe da
     entrada primeiro (quem se esconde vai para o fundo), depois aleatório.
  2. Visita os pontos em ordem (`seguirAlvo`); em cada um: gira a cabeça 1 s (Idle) e, se a recarga deixar, faz **Pulso** (§3.1).
  3. Andares de cima: se a construção tem escada (`Model` com peças `Degrau*`) e sobrou tempo, gera pontos do andar de cima depois de terminar o térreo.
  4. Termina quando: percebe alguém (vira Caça normal), visitou todos os pontos, ou passou `duracaoMax` (45 s). Ao terminar sem achar: Calmo, e
     **sai pelo vão** por onde entrou (não vaga dentro da casa).
- Porta fechada no caminho da busca: arromba (madeira, 1 golpe).
- Números: `habilidades.busca = { pontosMax = 8, grade = 6, duracaoMax = 45, olharCada = 1.0, entrarSemPercepcao = 2 }`.

### 3.4 Clipes (agente D)
`Idle, Walk, Run, Attack(impacto), Death, Pulso(encostou), Arrombar(impacto)`.

---

## 4. Wrapper (nível 1, `corpoAriete`) — sonar no lugar do grito

### 4.1 Sonar
- **Remove** o Scream (clipe e `grito` de 95 dB). Entra o **Sonar**.
- **Gatilhos** (recarga 10 s):
  1. ao **entrar em Caça** (onde antes gritava);
  2. em **Investiga**, ao chegar ao ponto sem achar ninguém;
  3. em **Caça**, se passou 3 s sem som novo (perdeu o alvo).
- **Ação:** clipe `Sonar` (1,2 s; o corpo infla e treme). No evento `onda` (padrão 0,5 s):
  - Som **`GritoAbafado`** (grito abafado sem boca; agente C) + **ruído de 70 dB**, tipo `sonar` (atrai menos que o grito de 95).
  - `MonstroSonar` aos clientes a ≤ 120 studs (§2.7) com `raio = 45`, `velocidade = 30` studs/s (a onda leva 1,5 s até a borda).
- **Detecção (servidor):** para cada jogador vivo a ≤ 45 studs, no instante `t = distancia / velocidade` depois da onda:
  - **Linha de visão** da cabeça do Wrapper (`hrp + 0,8·altura`) até **dois pontos** do jogador (cabeça e tronco). Raycast `Include` =
    `Construcoes` + `Props` + carros (`workspace.Veiculos`) + portas fechadas. **Detectado se pelo menos um dos dois raios chega livre.**
  - Folhas, vidro inteiro e porta **aberta** não bloqueiam (vidro: o raycast ignora peças `Glass`; ver `Destruicao`/material). Dentro de carro com vidros
    inteiros: **bloqueia** (a carroceria entra no raycast).
  - Detectado → `ouvirSom(d, investigaAte, posExata, agora)`, `d.alvoSonar = { jogador, pos, ate = agora + 4 }`, `SonarAtingido(true)`.
  - Não detectado (dentro do raio, mas bloqueado) → `SonarAtingido(false)`.
- Números: `habilidades.sonar = { raio = 45, velocidade = 30, recarga = 10, db = 70, perdeuAlvo = 3, alcanceAviso = 120, memoria = 4 }`.

### 4.2 Investida no detectado
- Com `d.alvoSonar` válido, o Wrapper corre (velocidade de Caça) até a **posição detectada** (não a atual: ele "lembra" onde a onda bateu) e usa a
  máquina de Lunge que já existe quando entra em `alcanceInicio`. Se o jogador saiu dali, o lunge passa direto.
- **Bater na parede (pedido antigo, mantido):** durante a fase Lunge, raycast curto à frente (2 studs) contra construções/props/carros; se bater:
  para, clipe **`Atordoado`** (2,0 s, sem golpe, sem andar), dano 0 em monstro (decisão §0). Bateu em carro: dano no carro como hoje.

### 4.3 Calmo: bater nas coisas
- Calmo, andando: se o raycast à frente bate em poste/parede a ≤ 1,5 studs, toca `WallSlam` curto (sem dano) e emite 45 dB `batidaCorpo`.

### 4.4 Clipes (agente D)
`Idle, Walk, Run, Attack(impacto), WallSlam(impacto), Sonar(onda), Atordoado, Death` (**Death é novo**; tirar `Scream`).

---

## 5. Corcunda (nível 1, `corcunda`)

### 5.1 Visão curta (pedido: "enxerga um pouco")
- Cone de **70°** à frente, alcance **14 studs**, com linha de visão (mesmo raycast do sonar). Alcance cai para **7** se o jogador está agachado e
  **4** deitado. À noite (Lighting `ClockTime` fora de 6–18) cai pela metade; jogador com lanterna ligada (`Lanterna` ligada) é visto a **20** studs.
- Checa a cada 0,3 s, só para jogadores a ≤ 20 studs. Viu → `ouvirSom` com posição exata (Caça).
- Números: `habilidades.visao = { angulo = 70, alcance = 14, agachado = 7, deitado = 4, noite = 0.5, lanterna = 20, cada = 0.3 }`.

### 5.2 Empurrão (pedido: "te joga no chão com um impulso")
- Substitui o **primeiro** golpe de cada encontro (um encontro termina quando ele perde o alvo por 8 s).
- A ≤ 4 studs do alvo: clipe **`Empurrao`** (0,7 s). No `impacto` (padrão 0,35 s), se o jogador ainda está a ≤ 5 studs e na frente (cone 90°):
  `Movimento.derrubar(jogador, 2.0, direcao * 45 + Vector3.new(0, 15, 0))`, dano **10**, som `Empurrao`, ruído 55 dB.
- Depois, enquanto o jogador está `Derrubado`, golpes normais (`Attack`, dano 20) com intervalo 1,0 s (mais rápido que o normal de 1,5).
- **Emboscada** (§5.4): se o empurrão vem de uma emboscada, o primeiro golpe depois dele faz **dano dobrado** (40).
- Números: `habilidades.empurrao = { alcance = 4, acerto = 5, derrubado = 2.0, forca = 45, subida = 15, dano = 10, intervaloNoChao = 1.0, encontroAte = 8 }`.

### 5.3 Portas (pedido: "abre e fecha porta")
- Ao seguir caminho, a cada 0,5 s: `Portas.naLinha(pos, proximoWaypoint, 3)`. Porta fechada a ≤ 4 studs → para, clipe **`AbrirPorta`** (0,8 s);
  no evento `porta` (0,4 s) `Portas.abrir(porta, d.modelo)` (barulho normal, 45 dB: ele **não** abre em silêncio).
- Depois de passar (porta ficou ≥ 4 studs atrás dele): **fecha** se estiver em Calmo, Investiga ou indo para emboscada (para se esconder).
  Em Caça, deixa aberta.
- Nunca bate porta. Não arromba.

### 5.4 Emboscada + Imitação (aprovada na ficha + falas em inglês)
- **Memória de sons:** guarda os 3 últimos sons **de jogador** que ouviu nos últimos 60 s: `{ tipo, db, quando }` (só tipos imitáveis: `passo*`,
  `portaAbrir`, `portaFechar`, `tiro*`, `itemCaindo`, `vidro`).
- **Entrar em emboscada:** em Investiga, ao chegar ao ponto sem achar ninguém → procura **esconderijo** a ≤ 15 studs: ponto com piso, de onde o
  ponto do som **não** é visível (raycast bloqueado), preferindo dentro de construção; fecha a porta do cômodo se houver (§5.3). Chegou:
  clipe **`Emboscada`** (agachado, em loop) por até **30 s**.
- **Imitar** a cada 10–25 s (aleatório) durante a emboscada: clipe **`Imitar`** (1,5 s) e toca **uma** destas:
  - 50%: uma **fala** (`VozCorcunda_1..N`, §5.5) na posição dele, com ruído de **55 dB** tipo `imitacao`;
  - 50%: um som da memória, mesmo nome de som e mesmo dB, com `PlaybackSpeed × 0,9` (o "defeito audível") e tipo `imitacao`.
- **Monstros ignoram `imitacao`** (em `processarRuido`: `if evento.tipo == "imitacao" then continue`). Para jogadores é um som como outro (HUD inclusive).
- **Gatilho da emboscada:** jogador a ≤ 6 studs (por visão §5.1 ou por som) → **Empurrão** imediato (§5.2) com o golpe seguinte dobrado.
- Sai da emboscada: 30 s sem ninguém → Calmo (abre a porta do cômodo e sai).
- Ruído do próprio passo: metade do normal (`passoDbMult = 0.5`; ele não emite passo hoje, então isso só vale se um dia emitir: anotar).
- Números: `habilidades.emboscada = { raioEsconderijo = 15, duracao = 30, imitarMin = 10, imitarMax = 25, gatilho = 6, chanceFala = 0.5, falaDb = 55, pitchDefeito = 0.9, memoria = 60 }`.

### 5.5 Falas em inglês (agente C)
- **8 a 12 falas curtas** (≤ 2 s), voz adulta comum, em inglês: "Hello?", "Help me", "Over here", "Is someone there?", "I'm hurt", "Please", "Come here",
  "Wait for me", "Hey", "I can hear you"…
- **Origem obrigatória: licença CC0 / domínio público** (ex.: Freesound filtrado por CC0, OpenGameArt CC0). Anotar arquivo, URL, autor e licença em
  `docs/creditos.md`. **Nada de** voz de pessoa famosa, filme, jogo, nem TTS de serviço pago. Se não achar CC0 suficiente, parar e avisar.
- Tratamento (ferramenta em `ferramentas/som/`, ffmpeg): mono, 22 kHz, normalizar, pitch −8%, passa-baixa 3,5 kHz, leve bitcrush (estética PS1).
- Envio como Audio pela Open Cloud (ler a memória/limites de áudio antes; `env -u ROBLOX_OPEN_CLOUD_KEY` + `.env`). Ouvir/olhar antes de enviar.
  **Conteúdo sem violência explícita** (moderação já puniu a conta duas vezes: textura do Esfolado, fotos de pessoas).
- Config: `Config/Sons.VozCorcunda = { ids... }` (ou uma entrada por fala).

### 5.6 Clipes (agente D)
`Idle, Walk, Run, Attack(impacto), Death, Empurrao(impacto), AbrirPorta(porta), Emboscada (loop), Imitar`.

---

## 6. MonstroPS1 (nível 1, `monstroPS1`)

### 6.1 Arrancada com lâminas arrastando (aprovada)
- **Gatilho:** em Caça, alvo a 15–40 studs, com linha de visão livre (raycast §4.1), recarga 12 s.
- Clipe **`Arrancada`** (loop) por 1,5 s a **26 studs/s** em linha reta para a posição do alvo **no início** (não persegue durante: passo de lado esquiva).
- **Faíscas:** a cada 0,1 s, uma peça Neon laranja pequena no chão (sem colisão, sem consulta) + `PointLight` fraca a cada 0,3 s; somem em 6 s
  (`Debris`). Ruído contínuo de **60 dB** (`raspar`) a cada 0,5 s; som `RasparLaminas` em loop durante a arrancada.
- Terminou a ≤ 5 studs do alvo → **Golpe duplo** imediato (§6.2). Senão volta à perseguição normal.
- Números: `habilidades.arrancada = { min = 15, max = 40, duracao = 1.5, velocidade = 26, recarga = 12, faiscaCada = 0.1, faiscaVida = 6, db = 60 }`.

### 6.2 Golpe duplo
- Clipe **`GolpeDuplo`** (1,0 s), eventos `impacto1` (0,35) e `impacto2` (0,65): dano **15 + 15**, cada um só acerta se o jogador estiver a ≤ 5 studs.
- Usado depois da arrancada e como golpe normal de perto 1 a cada 3 vezes (as outras usam `Attack`, dano 20).

### 6.3 Lâminas lançadas (pedido: "lança as facas, pouco dano, baixa precisão")
- **Gatilho:** em Caça, alvo a 15–50 studs com linha de visão, recarga **6 s**, e **não** durante arrancada. Se arrancada e lançamento estão
  disponíveis: a ≤ 40 prefere arrancada; 40–50 só lança.
- Clipe **`Lancar`** (0,8 s), evento `soltar` (0,45 s): sai da mão direita uma lâmina (peça fina 0,2×0,2×2,5, metal escuro).
- **Mira com erro:** direção = alvo previsto (posição + velocidade × 0,2 s) com desvio aleatório de **até 9°** (cone), velocidade inicial
  **80 studs/s**, gravidade do `Arremesso` (`Regras/Arremesso.simular`, passos de 1/30 s, servidor).
- **Acerto:** raycast entre posições de cada passo contra personagens e construções. Acertou jogador: dano **8** na parte atingida
  (`Vida.dano(jogador, parte, 8, { tipo = "monstro", direcao })`). Acertou construção: lâmina **crava** (Anchored) e some em 10 s; ruído 50 dB
  (`laminaImpacto`). Vidro: quebra (Destruicao tipo `corte`, dano 30).
- Alcance máximo 80 studs ou 2 s de voo. A lâmina não é coletável.
- Números: `habilidades.lancar = { min = 15, max = 50, recarga = 6, erroGraus = 9, velocidade = 80, dano = 8, previsao = 0.2, vidaCravada = 10, db = 50 }`.

### 6.4 Corta madeira e vidro
- Novo tipo de dano **`lamina`** em `Config/Materiais.tipos`: `{ vidro = 4, madeira = 2.5, alvenaria = 0.05, metal = 0.05, leve = 3 }`.
- Porta fechada/cerca de madeira/vidro no caminho em Caça: golpe `Attack` com `Destruicao.dano(peca, 60, { tipo = "lamina", fonte = d.modelo })`
  (porta e cerca caem em 1–2 golpes). **Não** arromba alvenaria: aí contorna (como hoje).

### 6.5 Bloqueio de pistola e barulho de aparar
- Em Caça, tiro de **pistola** (`Config/Armas` calibre de pistola) que acerta o **tronco** vindo do cone frontal de 60° do monstro: dano × 0,5,
  som `LaminaAparar`. Rifle/escopeta/foguete: dano cheio. (Agente B, em `Armas.luau`: precisa saber a frente do monstro: `hrp.CFrame.LookVector`.)
- Golpe corpo a corpo de jogador nele: ruído de **80 dB** (`aparar`) na posição dele.

### 6.6 Clipes (agente D)
`Idle, Walk, Run, Attack(impacto), Death, GolpeDuplo(impacto1, impacto2), Arrancada (loop), Lancar(soltar)`.

---

## 7. Florescida (nível 3, `florescida`, 5,5 m = 16 studs)

### 7.1 Velocidade e zona (pedido)
- Velocidades: Calmo **12**, Investiga **24**, Caça **60** studs/s (`PROVISÓRIO`; §0). Curva lenta: `Humanoid` com `AutoRotate = false` e giro
  limitado a **120°/s** (habilidade gira o `hrp` em direção ao próximo waypoint); em Caça reta, alcança carro normal; em curva fechada, perde.
- **Não entra na zona `cidade`:**
  - Nasce só em pontos fora da `cidade`.
  - `vagar`: destinos dentro da `cidade` são descartados.
  - Alvo (som/visão) dentro da `cidade`: vai até o **ponto da borda mais próximo** (2 studs para fora), ronda a borda 20 s e desiste (Calmo).
  - Se por empurrão/física estiver dentro: volta para fora pelo caminho mais curto.
- Pathfinding com `AgentRadius`/`AgentHeight` do corpo dela; se NoPath, `MoveTo` direto (como o Rastejador faz) e destrói o que estiver no caminho (§7.5).

### 7.2 Florescer (flores-sentinela)
- A cada **30 s andando** fora da `cidade` (e fora de construção), clipe **`Florescer`** (1,5 s); no evento `plantar` (0,9 s) cria uma flor no chão
  à frente (raycast para baixo). Máximo **12** por Florescida; a 13ª faz a mais antiga murchar (some).
- **Flor:** `Model` pequeno em `workspace.Flores` (Anchored, `CanCollide = false`, `CanQuery = true`, ~1,2 stud, pétalas pálidas, `PointLight` verde
  fraca alcance 6), atributos `Flor = true`, `Dona = <id da Florescida>`. Névoa local esverdeada: o cliente (agente C) põe um tom verde leve na
  névoa quando a câmera está a ≤ 25 studs de uma flor.
- **Escuta:** em `processarRuido`, para cada som de jogador (não `imitacao`), se existe flor a ≤ **20** studs da origem, a **dona** recebe
  `ouvirSom` com **posição exata** e excesso de Caça, **qualquer que seja a distância** dela até lá.
- **Destruir flor** (agente B chama `Flores.atingir(flor, jogador, arma)`, agente A implementa):
  - tiro ou golpe corpo a corpo: a flor some com som `FlorEstalo` e **ruído de 70 dB** (a dona ouve pela própria flor: vai para lá);
  - **faca com o jogador agachado**: some em silêncio (0 dB).
- Morreu a Florescida: as flores dela murcham em 10 s.
- Números: `habilidades.florescer = { cada = 30, max = 12, raioEscuta = 20, db = 70, murchar = 10 }`.

### 7.3 Rugido de chão
- Ao **entrar em Caça** (recarga 30 s): clipe **`Rugido`** (1,6 s; empina e bate as patas). No `impacto` (0,9 s): todo jogador a ≤ **30** studs,
  no chão (não em carro), é **derrubado** 1,5 s (`Movimento.derrubar`, impulso para fora 20 + para cima 10); tremor de câmera em quem estiver a ≤ 60
  (evento `Rede` `Tremor(intensidade, duracao)`, agente C). Ruído 100 dB `rugido`.
- Números: `habilidades.rugido = { raio = 30, derrubado = 1.5, impulso = 20, subida = 10, tremor = 60, recarga = 30, db = 100 }`.

### 7.4 Ataques: mordida, cauda, fachada
- **Mordida** = `Attack` (impacto do clipe), alcance 14 studs a partir do centro (o corpo tem 20 de comprimento), dano do nível 3 (70).
- **Cauda:** jogador **atrás** (cone traseiro de 100°) a ≤ 14 studs → clipe **`Cauda`** (0,9 s), impacto 0,45: dano **35** e empurrão 50 para trás
  (sem derrubar). Recarga 4 s.
- **Fachada (substitui o vão de 16 studs):** alvo dentro de construção **térrea ou de 2 andares** (altura do Model ≤ 26 studs) e **não** de
  concreto: clipe **`ArrancarFachada`** (1,8 s), no `impacto` (0,8): `Destruicao.dano` em todas as peças de parede da face voltada para ela, numa
  caixa de 14 × 12 × 3 studs (largura × altura × profundidade) no térreo, com dano 2000 tipo `impacto`. Depois a mordida alcança **+8 studs**
  para dentro (`alcanceDentro`). Recarga 6 s. Prédio alto ou de concreto: **não** ataca a construção; ronda 60 s mordendo janelas
  (`Destruicao` no vidro) e desiste.
- Números: `habilidades.cauda = { alcance = 14, cone = 100, dano = 35, empurrao = 50, recarga = 4 }`,
  `habilidades.fachada = { alturaMax = 26, caixa = {14, 12, 3}, dano = 2000, alcanceDentro = 8, recarga = 6, rondar = 60 }`.
- O `arrombar` antigo (vão de 16 studs) **sai** do preset dela (`capacidades.arrombar = false`); a fachada é a forma dela de entrar.

### 7.5 Pisotear
- Em Caça, a cada 0,2 s: caixa à frente (6 studs, largura do corpo) → `Destruicao.dano(peca, 400, { tipo = "impacto", fonte = d.modelo })` em props,
  cercas e postes; carro na caixa recebe impulso lateral 60 e dano na lataria (`veiculo.dano`). Construção: não (só pela fachada).

### 7.6 Clipes (agente D)
`Idle, Walk, Run (galope, nativo ≈ 60 studs/s), Attack(impacto), Death, Rugido(impacto), Cauda(impacto), Florescer(plantar), ArrancarFachada(impacto)`.

---

## 8. Divisão do trabalho (donos de arquivo; ninguém mexe no do outro)

| Agente | Faz | Arquivos (só estes) |
|---|---|---|
| **D: animações** (Opus, esforço baixo) | refaz os 5 clipes base dos 5 monstros + os clipes novos (§3.4, §4.4, §5.6, §6.6, §7.6) com os **eventos de tempo**; exporta, envia, gera `MonstrosMalhas` com `eventos` | `modelos 3d/**`, `ferramentas/modelos/**`, `src/shared/Config/MonstrosMalhas.luau` (gerado), `docs/monstros/animacoes.md` |
| **A: IA** (Sonnet 5.5) | §2.3–2.6, §3, §4.1–4.3 (servidor), §5.1–5.4, §6.1–6.4 (servidor; ordem do dano do tipo `lamina` em Materiais é do B), §7 (servidor, inclusive `Flores`) | `src/server/Monstros.luau`, `src/server/Monstro*.luau`, `src/server/MonstroHabilidades.luau`, `src/server/Habilidades/**`, `src/server/Flores.luau`, `src/shared/Regras/Habilidades.luau`, `src/shared/Regras/Lunge.luau`, `src/shared/Regras/Percepcao.luau`, `src/shared/Config/{Monstros,PresetsMonstro,Rastejador}.luau`, `tests/Habilidades.spec.luau` (+ specs de monstro existentes), `docs/decisoes.md` |
| **B: mundo e jogador** (Sonnet 5.5) | §2.1 portas, §2.2 derrubado (servidor), §6.4 tipo `lamina`, §6.5 bloqueio/aparar, chamadas a `Flores.atingir` em `Armas` | `src/server/Portas.luau` (novo), `src/shared/Config/Portas.luau` (novo), `src/shared/Regras/Portas.luau` (novo, se precisar), `src/server/Movimento.luau`, `src/shared/Config/Movimento.luau`, `src/server/Armas.luau`, `src/shared/Config/Materiais.luau`, `src/server/Destruicao.luau` (só se o tipo novo exigir), `src/server/init.server.luau` (iniciar Portas), `tests/Portas.spec.luau` |
| **C: cliente, rede e som** (Sonnet 5.5) | §2.7 onda do sonar, HUD "Derrubado"/"DETECTADO", névoa verde das flores (§7.2), tremor (§7.3), todos os **sons novos** (lista §9), falas em inglês (§5.5) | `src/shared/Rede.luau`, `src/client/MonstroSonar.luau` (novo), `src/client/MonstroEfeitos.luau` (novo: derrubado, tremor, névoa verde), `src/client/init.client.luau` (iniciar), `src/shared/Config/{Sons,SonsPSX,Som}.luau`, `ferramentas/som/**`, `assets/som/**`, `docs/creditos.md` |

Contratos entre agentes (cada um programa contra o contrato, mesmo antes do outro terminar; carregar módulo do outro com o `servico()`/`pcall` que
`Monstros.luau` já usa, para nunca quebrar se ainda não existir):
- B → A: `Portas.naLinha/perto/abrir/fechar/estaAberta/posicao` (§2.1), `Movimento.derrubar(jogador, s, impulso)` (§2.2).
- A → B: `Flores.atingir(flor: Instance, jogador: Player, arma: { tipo: string, agachado: boolean })` (§7.2).
- A → C (Rede, servidor dispara): `MonstroSonar(origem, raio, velocidade, id)`, `SonarAtingido(id, detectado)`, `Tremor(intensidade, duracao)`.
  **C declara os eventos em `Rede.luau`**; A só dispara pelo nome.
- Sons (A e B tocam por `Sons.tocar(nome, parte, { db })`; C cadastra): ver §9. Som ainda não cadastrado = `Sons.tocar` ignora com aviso (conferir que
  é assim; se não for, C faz ser).
- Ruído: tipos novos `sonar, imitacao, portaAbrir, portaFechar, portaBater, raspar, laminaImpacto, aparar, rugido, batidaCorpo, florEstalo, pulsoChao`
  (C acrescenta em `Config/Som.acoes` só os que forem por ação; o resto passa `db` direto em `Ruido.emitir`).

## 9. Sons novos (agente C cadastra; origem = biblioteca do `som-roblox` ou CC0, créditos em `docs/creditos.md`)
`PulsoChao, GritoAbafado, SonarOnda (cliente), SonarDetectado (cliente), SonarPassou (cliente), Empurrao, PortaAbrir, PortaFechar, PortaBater,
VozCorcunda_1..N, RasparLaminas (loop), LaminaLancada, LaminaImpacto, LaminaAparar, RugidoChao, CaudaGolpe, FlorEstalo, FlorPlantar`.

## 10. Testes e entrega
- Lune (`tests/`): cone/alcance da visão, linha de visão simulada (função pura que recebe "bloqueado: bool"), tempo da onda por distância, escolha de
  esconderijo e de pontos de busca (grade, prioridade pelo fundo), erro de mira dentro de 9°, zona `cidade` (dentro/fora/borda), recargas, limite
  por espécie, portas (estado, ruído por modo).
- `pwsh scripts/checar.ps1` verde ao fim de **cada** agente. Ninguém commita nem roda `sessao.ps1 -Fim`. Ninguém usa o Studio (a revisão e o teste
  em Play são do Opus, com o usuário sabendo).
- Cada agente escreve no fim desta seção, em "Estado", o que fez, o que ficou `PROVISÓRIO` e o que não deu.

## Estado
- 2026-11-14: lógica escrita (Opus). Código e animações: em andamento.
- 2026-11-14 (agente A, IA, Sonnet): implementado §2.3 a §2.6, §3 (Pulso, Busca, números do arrombar), §4.1 a §4.3 (sonar, investida no alvo lembrado, atordoado, batida em Calmo), §5.1 a §5.4 (visão, empurrão, portas,
  emboscada, imitação), §6.1 a §6.4 (arrancada, golpe duplo, lâminas, corte) e §7 (zona, curva lenta, flores, rugido, mordida, cauda, fachada, pisoteio). `checar.ps1` verde (Habilidades.spec novo). **Nunca rodou no Studio.**
  - Arquivos: `server/MonstroHabilidades` (despachante + util: linha de visão, construção sob ponto, zonas, rede), `server/Habilidades/{Rastejador,Wrapper,Corcunda,MonstroPS1,Florescida}`, `server/Flores`,
    `shared/Regras/Habilidades`, e ganchos em `Monstros` (`tocarAcao`, `evento`, `irPara`, `acalmar`, `d.semGolpeNormal/intervaloGolpe/danoMult/alvoSonar`), `MonstroArrombar`, `MonstroObjetivo`, `MonstroModelo`.
  - PROVISÓRIO: todos os números novos; Florescida gira por Heartbeat + `Humanoid:Move` (AutoRotate=false), pode brigar com a física; `gravidade` da lâmina = 30 (a do mundo faria a lâmina cair demais); candidatos da Busca
    assumem caixa de construção alinhada aos eixos; fachada assume o Model da construção sob o jogador; concreto = maioria das `Parede*` com Material Concrete; sem Portas/Movimento.derrubar/Rede os eventos viram no-op.
  - Fora: §6.5 (bloqueio de pistola, ruído de aparar: agente B), escada lenta do Wrapper, ruído do passo do Corcunda (`passoDbMult` só anotado).
  - Depende dos outros: B (`Portas.*`, `Movimento.derrubar`, tipo `lamina`, chamada de `Flores.atingir` em Armas), C (eventos `MonstroSonar`, `SonarAtingido`, `Tremor`, `Impulso`; sons PulsoChao, GritoAbafado, Empurrao, RasparLaminas,
    LaminaLancada, LaminaImpacto, RugidoChao, CaudaGolpe, FlorEstalo, FlorPlantar, VozCorcunda_1..10, PortaAbrir/Fechar), D (clipes e `eventos` em MonstrosMalhas; sem eles usa os tempos padrão do preset e clipes de reserva em `MonstroModelo`).
- 2026-11-14 (agente B, Sonnet): §2.1 portas, §2.2 derrubado, §6.4 `lamina`, §6.5 aparar e chamadas a `Flores.atingir` escritos; `checar.ps1`: testes Lune (incl. `Portas`, `Aparar`) verdes, sem Studio.
  - `server/Portas.luau` (+ `Config/Portas`, `Regras/Portas`): monta em segundo plano (lotes de 25 construções com `task.wait()`) uma porta por `Folha` de `Mapa.Construcoes`/`ZonaTeste.Construcoes`; dobradiça achada pela geometria (ponta da folha mais afastada do centro do `Batente` ao longo da parede), fechada = folha girada 75° de volta para a parede. Começa aberta (pose do mapa, 75°, não 90°). `ProximityPrompt` "PromptPorta" (E, 6 studs). Escuta `Destruicao.aoQuebrar` (folha removida/recortada deixa de ser porta). Contagem e tempo de montagem saem no Output (`[Portas] N portas montadas em X s`) e em `Teste:Invoke("portas")`; **não medidos** (sem Studio). Comando `porta` (abrir/fechar/bater a mais próxima).
  - `Movimento.derrubar(jogador, s, impulso)`; `Derrubado` = `workspace:GetServerTimeNow()` do fim (0 = livre); `Agachar`/`Deitar` ignorados enquanto vale; carro/morto ignoram; volta agachado. Comando `derrubar`. Limites em `Config/Movimento.derrubado` (6 s, impulso 120).
  - `Armas`: acerto em instância com atributo `Flor` -> `Flores.atingir` por pcall (módulo opcional); pistola no tronco do MonstroPS1 vindo do cone de 60° em Caça/Ataque: x0,5 + som `LaminaAparar`; golpe corpo a corpo nele: ruído 80 dB `aparar`. Números em `Config/ArmasMonstro` (novo), regra em `Regras/Aparar` (novo).
  - PROVISÓRIO: "tronco" do monstro = peça cujo nome não contém head/cabeca/arm/braco/leg/perna/hand/mao/foot/blade/lamina/faca; estado "Ataque" também conta como Caça; fechar agachado = 50 dB (só abrir tem versão silenciosa); sinal/dobradiça nunca vistos em Play.
  - Depende de A: `Flores.atingir`, uso de `Portas.*` e do `Monstros.invalidarCaminhos`. Depende de C: sons `PortaAbrir/PortaFechar/PortaBater/LaminaAparar` e HUD "Derrubado".
- 2026-11-14 (agente C: cliente, rede e som). **Feito:**
  - `Rede.luau`: `MonstroSonar(origem, raio, velocidade, id)`, `SonarAtingido(id, detectado)`, `Tremor(intensidade, duracao)` (servidor -> cliente; A dispara pelo nome, ja criados em `Rede.criarTodos`).
  - `src/client/MonstroSonar.luau`: esfera Neon + anel no chao (SurfaceGui com UIStroke) crescendo a `velocidade`, max 4 ondas, som local `SonarOnda`;
    `SonarAtingido(_, true)` = borda vermelha 0,6 s + "DETECTADO" + `SonarDetectado`; `false` = pulso azul 0,3 s + `SonarPassou`.
  - `src/client/MonstroEfeitos.luau`: HUD "Derrubado", `Tremor`, nevoa verde das flores. Ambos iniciados em `init.client.luau`.
  - **Contrato `Derrubado` (para o B):** atributo do **Player** = `workspace:GetServerTimeNow()` do fim (nao `os.clock`); o cliente mostra o HUD enquanto
    `workspace:GetServerTimeNow() < atributo`. Limpar com `nil`/0 ao acabar. (Ja estava assim na §2.2.)
  - **Contrato `Tremor(intensidade, duracao)`:** `intensidade` 0..1 (amplitude = intensidade x 0,6 studs, via `Camera.tremer`, que respeita `Pref_Tremor`/`Pref_Intensidade` e some em 3a pessoa); `duracao` em s (teto 5).
    Ao ficar derrubado o cliente ja treme sozinho (0,3 / 0,35 s): o servidor nao precisa mandar `Tremor` para isso.
  - **Nevoa das flores:** `ColorCorrectionEffect` propria `Lighting.NevoaFlor` (tinta verde + saturacao -0,1), forca 0 a 25 studs -> 1 a 10 studs da flor mais proxima de `workspace.Flores` (atributo `Flor = true`); `src/client/Filtro` intacto.
  - **Sons (§9):** todos cadastrados em `Config/Sons.luau` (+ `Config/SonsMonstros.luau`, gerado). 8 sinteticos e 10 falas enviados pela Open Cloud (18 Audio, estado `Reviewing`); os demais reaproveitam ids ja existentes. Detalhes e licencas em `docs/creditos.md`.
  - **Falas:** `Sons.tocar("VozCorcunda", ...)` sorteia uma; `Sons.tocar("VozCorcunda_n", ...)` toca a n (1..10); `Config/Sons.VozCorcunda.nomes` lista os nomes. Ruido 55 dB `imitacao` e do A.
  - `Sons.tocar` ja ignora som sem ids com `warn` uma vez (nao precisou mexer em `server/Sons.luau`).
- **PROVISORIO / pendente (C):** (1) as falas sao do pacote Kenney: chamados de "war" (Medic!, Look out!, Get down!, Cover me!, Hold...), **nao** "Hello?/Help me" (nao ha CC0 conversacional baixavel: Freesound exige login; OGA so tem CC-BY/caricatura). Servem para imitar sobrevivente, mas o usuario deve ouvir; (2) nenhum som foi ouvido por humano (so espectrograma/niveis): `GritoAbafado` e `PulsoChao` sao sinteses e podem soar artificiais; (3) enviados estao `Reviewing` na moderacao; (4) `PortaBater`, `RugidoChao`, `Empurrao` reaproveitam sons existentes (trocar se soarem fracos/agudos); (5) sem teste em Play.
  - **`Impulso(vetor: Vector3)`** (servidor -> so o jogador; Rede.luau): o cliente faz `hrp.AssemblyLinearVelocity += vetor` (magnitude limitada a 120; ignora se morto ou sentado em assento/carro). Para `Movimento.derrubar` e a cauda da Florescida, no lugar de aplicar a velocidade no servidor.
- 2026-11-14 (Opus, revisão + teste em Play na ZonaTeste): correções da revisão:
  - `Armas`: o ruído de 80 dB do aparar sai com `fonte = atacante` (com fonte = monstro, os de mesmo nível o ignoravam).
  - `Movimento.derrubar`: o impulso também vai ao cliente pelo evento `Impulso` (o cliente é dono da física do personagem).
  - `PresetsMonstro.corcunda`: tipo de ruído `arma` (tiros) mapeado para `TiroPistola` na imitação (antes o Corcunda nunca imitava tiro).
  - `Monstros.presetDe`: as `nativas` medidas pelo pipeline (`MonstrosMalhas`) valem sobre as do preset (Florescida: galope 59 studs/s; o preset dizia 38).
  - `Habilidades/MonstroPS1`: a arrancada reafirma `WalkSpeed` a cada passo (a troca de estado visível a derrubava para 14; visto em Play).
  Visto em Play (sem erro no console): 1762 portas montadas em 2,3 s; Florescida limitada a 1 no mapa; Wrapper: sonar → "DETECTADO" no cliente → investida e morte;
  Corcunda: empurrão derruba 2 s (o jogador voa ~15 studs: forte, `forca = 45` PROVISÓRIO) e depois o perde (agachado, sem som: coerente);
  Florescida: rugido parada 1,5 s, investida ~56 studs/s, passa direto pela curva lenta, volta e morde; Rastejador: caça e ataca.
  Não visto: arrancada/lâminas do MonstroPS1 depois da correção, Pulso e Busca do Rastejador (precisa de casa na ZonaTeste), portas usadas pelo Corcunda,
  emboscada/imitação, flores e fachada, sons tocando (texturas e áudios novos ainda em processamento na Roblox).
