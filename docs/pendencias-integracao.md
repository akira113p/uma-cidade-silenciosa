
## P7 · Armas e PvP

- **P6 (Inventario) / ArmaSlot**: o servidor de Armas escreve também o atributo `Player.ArmaSlot` (slot do inventário da arma equipada, `nil` sem arma). O evento `Inventario` leva `equipado: number?`: P6 pode ler esse atributo em vez de guardar estado próprio. Armas usa `Inventario.aoMudar` para desequipar sozinha se o item sair do slot (largou, morreu, trocou).
- **P6 (InventarioUI)**: `Equipar(slot)` com o mesmo slot já equipado só refaz o equipamento (idempotente); o toggle ("de novo no mesmo slot → `Equipar(nil)`") é decidido no cliente.
- **P1 (Mapa)**: `Mapa.Zonas` e `Mapa.Pontos` são ignorados pelo raycast das armas (excluídos no `RaycastParams`), mas peças invisíveis novas com `CanQuery = true` bloqueariam tiros. Manter `CanQuery = false` em tudo que é invisível e não deve parar bala.
- **P5 (Vida)**: `Vida.dano(..., fonte)` recebe `fonte.direcao` = direção unitária do tiro/golpe. Cabeça na pistola dá 50 de dano (vida da cabeça é 30): um tiro na cabeça mata (balanceamento, não bug).
- **P3 (Ruido/Config.Som)**: o ruído da arma usa o tipo `"arma"` direto em `Ruido.emitir(posicao, arma.ruidoDb, "arma", jogador)`; `Config/Som.acoes` não tem entrada `arma`, e não precisa (o dB vem de `Config/Armas.ruidoDb`).
- **P4 (Monstros)**: `Monstros.dano(modelo, valor, atacante)` recebe o dano chapado da arma (sem multiplicador de cabeça, monstros não têm partes de corpo).

## P2 · Personagem e câmera

- **P3 (Ruido) / ritmo do balanço**: a câmera avança a fase com `Config/Som.passosPorSegundo[modo]` (1.5/2/3) e a fórmula literal de `calculos.md §5` (`fase += pps × 2π × dt`). Com isso `|sin(fase)|` tem o fundo duas vezes por passo do Ruido (zera a cada π, e o passo corresponde a 2π). Se o balanço deve bater 1 fundo por passo, trocar para `pps × π × dt` em `Regras/Camera.avancarFase` (e ajustar a spec).
- **P5 (Vida) / HipHeight**: `Config/Movimento.alturaAgachado` (HipHeight × 0.6) NÃO é aplicado: o contrato do Movimento (§5) só fala em `WalkSpeed`, e baixar o HipHeight sem animação afunda as pernas do R15 no chão para os outros jogadores. A altura dos olhos agachado é só da câmera (`Config/Camera.alturaOlhosAgachado` via `Humanoid.CameraOffset`). A hitbox não encolhe agachado. Decidir se quer isso.
- **P3 (SonsLocal)**: `Configuracoes` chama `require(script.Parent.SonsLocal).tocar("Clique")` em `pcall` (INTEGRACAO: se o módulo ou o som não existir, o clique fica mudo). `Config/Sons.Clique` existe.
- **P4 (Monstros)**: a câmera trata `Estado` `"Caca"` (contrato §3) e também `"Caça"` como caça.
- **Camera.tremer(amplitude, duracao)**: função extra (fora do contrato) exposta por `client/Camera.luau` para outras partes, p.ex. coice de arma no `ArmasCliente`. Respeita `Pref_Tremor`/`Pref_Intensidade` só no aplicar; quem chamar deve checar as preferências se quiser evitar a chamada.
- **Comandos de Teste do Studio (Movimento)**: `"agachar"(ligado?)`, `"correr"(ligado?)`, `"velocidade"()`. Chamam o mesmo código dos eventos `Agachar`/`Correr` (com Limite de 0.1 s ao ligar).

## P3 · Som

- **Config/Som.aterrissagem.alturaMinima** (3.5 studs): campo novo em `Config/Som.luau` (não existia no contrato). Queda menor que isso não faz ruído nem som de aterrissagem (degrau/rampa e o nascer a +3 studs). Pulo normal (6 studs) conta. Ajustar no playtest.
- **P5 (Vida)**: o som `Dor` e o dano de queda são da Vida. O Ruido só emite `aterrissar` (50 dB para qualquer queda >= alturaMinima, sem escala por altura) e toca o som `Aterrissar`.
- **Limite.limpar**: ninguém chama `Limite.limpar(jogador)` ao sair (a tabela `ultimos` cresce um pouco por jogador que passou). Não é do P3; quem dono do `Limite` pode ligar no `PlayerRemoving`.
- **Todos os que chamam `Sons.tocar(nome, onde, {db})`**: sem `db` o som usa o roll-off padrão do Roblox (sem corte em `RollOffMaxDistance`). Passar `db` sempre que o som deve valer o mesmo número da tabela 1.4 (ex.: Armas, Inventário, Monstros).
- **Ruido.emitirAcao**: ação que não esteja em `Config/Som.acoes` dá `warn` e não emite nada. Ações validas hoje: agachado, andar, correr, aterrissar, porta, golpe, vidro, carro, pistola, fuzil, gritoMonstro, abrirCaixa, comer, beber, bandagem, kit.
- **Comandos de Teste (Studio)**: `"ruido"(db?)` emite na posição do jogador (padrão 60 dB, fonte = o jogador, então move o HudSom); `"som"(nome?, db?)` toca um som do catálogo 8 studs à frente.
- **SonsLocal / Coração**: toca com monstro em `Estado` `"Caca"` (ou `"Caça"`) **ou `"Ataque"`** a <= `Config/Camera.monstroCacando.distancia`. Incluir `Ataque` evita o coração calar justamente na mordida.
- **Voz**: usa `jogador:FindFirstChildWhichIsA("AudioDeviceInput")` (o chat de voz coloca a entrada no Player). Não testado com microfone real (só a API foi conferida no Studio: `AudioAnalyzer.RmsLevel`, `AudioDeviceInput.Muted/Player`, `Wire`).

## P5 · Vida e sobrevivência

- **Config/Sobrevivencia.luau**: acrescentei `estamina.multVoltaFomeBaixa = 0.5` (o "pela metade" do §4 estava só em prosa; regra não pode ter número solto).
- **`Vida.danoTodas(jogador, valor, fonte)`**: função extra (fora do §5) usada pelo dano de frio (1 em cada parte) para gerar um só evento `Dano`/`Dor` em vez de seis. Quem quiser dano em todas as partes pode usar.
- **Causa "vazio"**: morte por `Humanoid.Died` vinda de fora (queda no vazio, reset) vai para `aoMorrer`/`Morreu` com `causa = "vazio"`, que não está em `FonteDano.tipo`. Inventario deve aceitar qualquer string.
- **Correndo + movimento**: Sobrevivencia só gasta estamina/comida se `Correndo == true` E a velocidade horizontal do HumanoidRootPart > 1 stud/s (segurar Shift parado não gasta). P2: se o Movimento já garantir isso, sem conflito.
- **Dano de queda no spawn**: Vida ignora aterrissagens nos primeiros 2 s após `CharacterAdded` (o Spawn teleporta o personagem e a altura medida seria falsa). Não mexer em `Spawn` sem conferir isso.
- **Substitutos INTEGRACAO**: `Sons` (P3, `Sons.tocar("Dor", raiz)`) e `Ambiente` (P3, `Ambiente.condicao()`) são carregados com `pcall(require)`; se ausentes, Vida não toca som e Sobrevivencia lê `workspace:GetAttribute("Condicao")` (ou "dia").
- **Mobile**: HudVida (canto inferior esquerdo, ~250 px de largura) pode encostar na barra de slots do InventarioUI em telas de 667 px. Conferir no playtest com emulação de celular.
- **Aviso**: o HUD mostra no máximo 3 avisos empilhados, 3 s cada, acima do centro inferior (y = -100 px) para não cobrir os slots do InventarioUI.

## P6 · Inventário e loot

- **Armas deve reagir ao inventário (P7).** Se o item da arma equipada some (largar, morte, bolsa), `ArmaEquipada` fica setado: o Inventario não escreve esse atributo. Armas deve usar `Inventario.aoMudar` e desequipar quando nenhum slot tiver o item. O Inventario reenvia o estado ao cliente em toda mudança de `ArmaEquipada`.
- **Pedir o inventário ao iniciar.** Não existe evento para o cliente pedir o estado (o `Inventario` pode chegar antes de o `InventarioUI` ligar o listener). Substituto: o cliente manda `UsarItem(0)` ao iniciar e o servidor reenvia o estado. Sugestão: evento `PedirInventario` em `Rede.luau`.
- **Formato do evento `Inventario`.** `itens` é `{ {slot, id, qtd} }` só dos slots ocupados (o contrato diz `{ {id, qtd} }`; sem o número do slot o cliente não sabe qual tecla é qual). O 2º argumento `equipado` é o slot da arma equipada (primeiro slot cujo item tem `arma == ArmaEquipada`).
- **Evento `ConteudoCaixa` com `itens = nil`** significa "feche a janela" (cliente também fecha se o container sumiu).
- **`Aviso` (P5/HudVida) vs barra de slots.** A barra do inventário ocupa o centro inferior (~76 px + 12 px de margem) e a barra de uso fica logo acima dela. O `Aviso` de "centro inferior" deve ficar acima disso (sugestão: pelo menos 140 px do fundo) para não cobrir os slots.
- **Folga de alcance.** O servidor aceita `Itens.alcanceInteracao * 1.25` (10 studs) por latência, igual aos 10 studs em que o cliente fecha a janela. Sugestão: virar `Config/Itens.folgaInteracao`. Constante local `FOLGA_ALCANCE` em `server/Loot.luau`.
- **`Usando` no cliente.** O atributo é só booleano; a barra de progresso usa `Config/Itens.itens[id].uso` do último slot apertado. Sugestão se precisar de exatidão: atributo `UsoDuracao` (dono Inventario).
- **Funções extras (além do contrato, sem mudar as pedidas):** `Inventario.espaco(jogador, id)`, `Inventario.retirarDaBolsa(bolsa, indice, qtd?)` (3º parâmetro opcional), `Loot.abrir(jogador, container)`.
- **Mapa (P1).** `server/Loot` espera até 15 s por `workspace.Mapa.Pontos`; sem pontos `Loot` ou sem atributo `Tabela` válido avisa com `warn` e não cria caixa.

## P4 · Monstros

- **Config/Monstros.ia (INTEGRACAO)**: números de execução da IA ficaram como `IA_PADRAO` no topo de `server/Monstros.luau` (5 Hz, lote de 25 monstros por frame, pausa a 700 studs, rosnado 8..20 s e só com jogador a <= 100 studs, vagar, tombar 3 s, renascer 180 s, até 6 pathfinding simultâneos, raycast em 30 monstros por frame). Se `Config/Monstros` ganhar um bloco `ia = { ... }` com as mesmas chaves, ele vale no lugar (via metatable), sem mexer no código.
- **Percepcao recebe o Config/Monstros inteiro** como `cfg` (usa `cfg.estados` e `cfg.niveis`). `niveis[n].velocidadeInvestiga` é opcional: sem ela, Investiga anda na velocidade de Calmo (a tabela de `calculos.md §2.1` diz "anda").
- **Relógio de Investiga**: conta do último som OU de quando entrou em Investiga vindo da Caça. Assim, Caça -> 8 s calado -> Investiga -> mais 12 s -> Calmo (20 s no total desde o último som). Só quem entra em Investiga direto tem exatamente 12 s do último som.
- **Reação em cadeia do grito**: o grito do nível 1 (60 dB) alcança ~350 studs de noite e faria todo nível 1 gritar também. Decisão: monstro ignora ruído de outro monstro de nível >= ao seu (nível 1 não escuta nível 1; níveis 2/3 escutam o grito do 1, como o §2.1 pede). Revisar se o usuário quiser matilha.
- **Raycast de paredes com filtro Include**: usa `RaycastParams` com `FilterType = Include` e só `Mapa.Construcoes`, em vez de excluir personagens e monstros. Mesmo resultado (cada acerto numa construção conta 1) e mais barato. Sem `Construcoes`, paredes = 0.
- **Toque que acerta o jogador** e **dano recebido** alimentam a Percepcao como se fosse som com excesso = `estados.investigaAte` (vira Caça na posição do jogador/atacante). Entrar em Caça assim também faz o nível 1 gritar.
- **Servidor depende (e trata ausência) de**: `Ruido.aoRuido/emitirAcao` (sem Ruido: monstros surdos, `warn`), `Sons.tocar` (sem Sons: sem grito/rosnado), `Vida.dano/estaVivo` (sem Vida: sem dano), `Regras/Som` (sem ela: fórmula local idêntica à de `calculos.md §1.3`).
- **Atributos**: além do §3, nada novo no modelo do monstro. `Estado` assume `"Calmo" | "Investiga" | "Caca" | "Ataque"` (sem cedilha, como o §3).
- **Corpo do monstro morto**: tomba (rotação 90° em Z, ancorado, sem colisão) e some em 3 s. `Monstros.ehMonstro` ainda devolve o modelo nesse intervalo; `Monstros.dano` ignora morto. P7 pode seguir sem checagem extra.
- **Boneco de blocos usa `RigType = R15` com `HipHeight = 0.1`** (o padrão R6 ignora HipHeight). Não conferido em playtest (proibido nesta rodada): se o boneco afundar ou flutuar, ajustar `IA.hipHeight`.
- **Modelos prontos**: o Rojo ainda não mapeia `ServerStorage.Modelos.Monstros` (não está em `default.project.json`). Quando os modelos de `modelos 3d/monstros` entrarem, precisam de `Humanoid` + `HumanoidRootPart`; senão cai no boneco.
- **Comandos de Teste**: `"monstro"(especieId?)` nasce um 20 studs à frente (ignora `nivelAtivoMaximo` se a espécie for dada; não renasce); `"monstros"()` devolve/imprime contagem por estado.

## P1 · Mapa e visual

- **Config/Mundo.semente** (20261101): campo novo (o gerador precisa de semente fixa; mesma semente = mesmo `Mapa.rbxm`, conferido por hash). Nenhum outro número de Mundo foi alterado.
- **Alturas do chão** (para quem põe coisa no mapa): floresta em Y = 0; áreas construídas (asfalto da cidade, avenidas, pads de vilas/fábrica/planície/posto da guarda) em 0.5; calçadas da cidade 0.9; lotes 1.1; manchas de LeafyGrass +0.15 sobre a superfície. Pontos já vêm em topo + 0.5 (Spawn/Loot/Monstro). Degraus entre níveis são de 0.2 a 0.5 studs (andáveis sem pular).
- **P6 (Loot) / tabela "predio"**: `Config/Itens.tabelas` não tem `predio`. Pontos de loot de prédio saem com `Tabela = "casa"` (galpão da fábrica = `"fabrica"`, posto de vila = `"posto"`, posto da guarda = `"guarda"`). Se quiser tabela própria, criar `tabelas.predio` e trocar `TABELA_POR_TIPO` em `ferramentas/gerar_mapa.luau`.
- **P6 (Loot)**: 385 pontos Loot (1 por construção). Na cidade ficam na calçada em frente à construção (Y = 1.4); nas vilas/fábrica/guarda ficam a 3.5 studs da fachada.
- **P4 (Monstros)**: há 1357 pontos Monstro (cidade 676, floresta 632, vila 27, fábrica 12, outros 10) para `maxPorServidor = 250`: o serviço precisa escolher quais usar (sorteio ou os mais próximos dos jogadores). Atributo `Zona` do ponto = chave de `Config/Monstros.densidade`.
- **P5 (Spawn)**: 18 pontos Spawn (6 por vila), atributo `Zona` = nome da vila (`"Vila Norte"`, ...). Estão a >= 8 studs de qualquer construção (o checker garante) e em chão alcançável entre si.
- **Mapa.Zonas**: as zonas específicas (cidade, 3 vilas, fábrica, planície, posto da guarda) se sobrepõem à zona `floresta`, que cobre o mapa todo em 4 quadrantes de 2000×2000 (limite de 2048 por peça). Quem consultar deve escolher a zona mais específica (menor). Todas têm `CanQuery = false`, atributos `Zona` e `Nome`. Para saber a zona de um ponto, usar a conta de caixa (CFrame/Size), não `GetPartBoundsInBox`.
- **Mapa.Bordas / Zonas / Pontos**: tudo invisível com `CanQuery = false`, para não parar tiro nem o raycast de paredes do Monstros (que só conta acertos em `Mapa.Construcoes`). Portas e janelas das construções (peças finas coladas na fachada) também têm `CanCollide = false` e `CanQuery = false`: não contam como parede extra.
- **Construções**: Model com `Corpo` (sólido, PrimaryPart), `Telhado`, `Porta`, `Janela` (e `Torre`/`Cabine`/`TetoCabine` no posto da guarda), `ModelStreamingMode = Atomic`. Atributos: `Tipo`, `Zona`, `Andares`, `Interior = false`, e `Local` (nome da vila, `"Fabrica"` ou `"PostoGuarda"`). Galpão e posto da guarda têm `Andares = 1` mas altura própria (16–20 studs; torre 30).
- **Árvores**: 2500 (Config) em aglomerados (80%) + dispersas, `distanciaMinima` 14, nenhuma em cidade/vila/fábrica/avenida/planície. Tronco colide; copa não colide e não é consultada por raycast.
- **FiltroPS1 / dither**: `rbxassetid://138954735210943` existe (nome `dither_pattern`) mas é um **Decal** (AssetTypeId 13), não uma Image. Não foi possível conferir visualmente no jogo (sem playtest). Se o `ImageLabel` ficar vazio, pegar o id da Image correspondente e trocar `IMAGEM_DITHER` em `src/client/FiltroPS1.luau`; as 360 scanlines funcionam independente da textura.
- **Visual / clima**: os multiplicadores visuais de chuva/tempestade (densidade da Atmosphere, Haze, Brightness) estão como tabela local `CLIMAS` em `src/server/Visual.luau` (`INTEGRACAO`: mover para `Config/Tempo` se quiser). Não há partículas/som de chuva no Visual (som é do Ambiente/SonsLocal).
- **Comandos de Teste**: `"hora"(h)` (0..24) e `"clima"("limpo"|"chuva"|"tempestade")`.
- **Verificação**: `lune run ferramentas/gerar_mapa.luau` e `lune run ferramentas/checar_mapa.luau` (exit != 0 se falhar). O checker lê o `.rbxm` direto (sem Studio): grade de 4 studs para alcance, degrau máximo = `Movimento.alturaPulo` × 0.9.

## Mapa v2 (2026-11-02): interiores, rios, floresta de pinheiros, estradas
Contrato e divisão em `docs/mapa-v2.md`. 14 módulos em `ferramentas/mapa/` (escritos por agentes Sonnet em paralelo, integrados e revisados pelo Opus).
`lune run ferramentas/gerar_mapa.luau --final` → `mapa/Mapa.rbxm` (154,7 mil peças, 3,7 MB); `lune run ferramentas/checar_mapa.luau` verde
(827 de 827 loots internos alcançáveis a partir da porta; rios só se atravessam por ponte/viaduto/passarela).
- **Verificado no Studio (place de revisão):** vista geral, exterior de casa, interior de casa com luz de teste, ponte com treliça, estrada com faixas,
  `[Rios] 499 trechos de água preenchidos`, 880 caixas de loot (2026-11-02: a caixa foi substituída por compartimentos nos móveis), sem erro de script. **Não verificado:** playtest de 20 min, FPS com 150 mil peças e
  streaming, nado no rio, monstros atravessando água/pontes, visual dos interiores em todas as variantes.
- **Interiores sem luz** (apagão, de propósito): o compartimento (móvel) e o texto ficam escuros. (2026-11-02: a caixa foi substituída por compartimentos nos móveis.) Decidir se alguns cômodos ganham `PointLight`.
- **Paredes para o som e para o monstro:** `Mapa.Construcoes` agora tem paredes e móveis dentro de cada prédio; o raycast de paredes de `server/Monstros`
  (cada acerto em `Construcoes` conta 1, teto `maxParedes`=3) vai contar móveis. Se isso pesar demais, marcar móveis com `CanQuery = false` ou filtrar por
  nome (`Parede`, `Laje`).
- **Água é Terrain em tempo de execução** (`src/server/Rios.luau`, ligado em `init.server.luau`): no Studio em modo Edit os rios aparecem como leito de areia.
  Não houve teste de nado. O `PathfindingService` pode tratar água como custo alto: conferir se monstros encalham.
- **Chão é grade de lajes inclinadas** (relevo ±21 st, inclinação máx 21°): `ctx.altura` concorda com a superfície real em ≤ 0,23 st. Pontos de Monstro
  podem ficar até 1 st acima/abaixo do chão (o checker aceita 1,3).
- **Orçamento:** `Mundo.limitePecas` subiu para 165 000 (interiores reais pesam). Construcoes 68,5 mil, Vegetacao 49,9 mil, Props 18,3 mil. Corte mais barato:
  mantos de agulhas da floresta (~2 100 peças) e carros decorativos.
- **Checker:** grade 3D dos interiores usa vão livre mínimo **5,0** e degrau 1,3; o personagem escalado (1,05) tem ~5,4. Patamares de escada ficam ≥ 5,8 (E2 corrigiu).
  A galeria do 2º andar do motel e alguns corredores de casa podem ficar perto de 5 de passagem.
- **Pontos de Loot:** 880 (era 385): 53 externos + 827 dentro dos prédios. A tabela `hospital` é nova em `Config/Itens`.
- **Sobras conhecidas:** galpões têm 1 planta só (varia a paleta); casa_media de 1 andar sem escada; telhados em degraus de blocos nos oitões; placas e letreiros usam
  SurfaceGui (texto não conferido em todos); `ctx.rampa` foi corrigido (o `CFrame.lookAt` do Lune erra a inclinação: usar `CFrame.fromMatrix`).
- **Lista de construções novas (não pedidas antes):** mercado, farmácia, restaurante, bar, banco, loja de roupas/ferragens/conveniência, oficina, hospital, delegacia, bombeiros,
  escola, prefeitura, biblioteca, hotel, motel, lanchonete de estrada, garagem, apartamentos, escritório, torre, igreja, capela, cripta, celeiro, serraria; áreas: cemitério,
  acampamento Halvorsen, fazenda, serraria, ferro-velho, parada de rodovia, igreja isolada, pátio da fábrica, parques com coreto/fonte/playground.

## Filtro
- **2º playtest (2026-11-03, Opus, MCP)**: grão leve (~2% dia / 3% noite, 8 quadros/s), franja da aberração com fade por
  distância (forte até 18 studs, nula a 48), névoa de dia 25–300, lanterna (brilho 34/20; cone volumétrico desligado na
  1ª pessoa; atenuada de dia), neblina em camadas refeita (3 beams sobrepostos, sem painel de bordas retas) e cone dos
  postes com fade por proximidade/ângulo. 58–60 FPS, 231 beams ativos. **Falta**: (1) ouvir o usuário sobre o grão
  "bem de leve"; (2) lanterna vista de fora (cone volumétrico na 3ª pessoa/outros jogadores) e a cabeça do R15 que não
  inclina; (3) bateria da lanterna; (4) custo com 3+ clientes (Fase 9); (5) estalos de fita ainda visíveis no topo da
  tela às vezes (tracking espontâneo 6–15 s).
- **Auditoria 2026-11-03 (Opus, playtest MCP)**: 4 checagens verdes, sem erro no console, 60 FPS (teto) com céu, aberração
  (146 partes clonadas), postes e grão/moldura/vinheta. Conferido por captura: céu de névoa (sem azul), névoa cinza de dia,
  sépia à noite (ambient/névoa subidos, `brilhoSpot` 7), moldura 9-slice, aberração radial (corrigida: sem chão, com névoa
  nos clones). Depois (mesmo dia): texturas T1–T5 geradas no ChatGPT (Haiku no Chrome), auditadas por Sonnet, enviadas;
  neblina em camadas sem placas (laterais esmaecidas no processador), cone de luz à noite, crepúsculo 17h36 conferido,
  moldura com `sliceEscala` 0.5 (usuário pediu mais fina). 60 FPS com tudo. **Falta**: (1) lente Glass: cobre a tela,
  mas a refração não apareceu no Studio em qualidade automática — conferir com gráfico no máximo; (2) custo em área
  densa do centro e com 3+ clientes (Fase 9); (3) cone de luz depois de `coneTransparencia` 0.72 sem nova captura;
  (4) faixa de tracking e poeira não foram flagradas em captura (aparecem em intervalos).
- **S5**: `Config/Tempo.luz.*.climas` ainda tem `densidade` e `haze` (eram da Atmosphere, sem uso); podem sair. Valores de névoa, cor, bloom e profundidade são PROVISÓRIOS: afinar por captura no Studio (9h, 18h30, 23h). `docs/calculos.md` não cita névoa/Atmosphere (nada a mudar). `Pref_Lente` padrão false.
- **S2 (Aberração)**: o orquestrador (S1) precisa passar `e.pulsos`, `e.caca`, `e.noite`, `e.fov` e chamar `Aberracao.nivel/ligar`. Limites: ViewportFrame não tem profundidade contra o mundo real, então um monstro parcialmente atrás de poste mostra a franja sobre o poste (`pontosVisiveisMinimos = 2` em `Config/Filtro/Aberracao` é mais justo). Roupas (Shirt/Pants) não aparecem nos clones de personagens. Custo da geometria estática (milhares de clones em ~20 células) a medir no Studio; afinar `clonesPorQuadro`, `maxPartesPorCelula`, `raioEstatico`.

## Lanterna
- **S7 (2026-11-03)**: lanterna de mão escrita e integrada; 4 checagens verdes; NÃO testada no Studio (em uso). Arquivos:
  `Config/Lanterna`, `Regras/Lanterna` (+ `tests/Lanterna.spec`), `server/Lanterna`, `client/Lanterna`. Tocados no mínimo:
  `Config/Itens` (item, kit `slot = 5`, loot casa 4 / loja 4 / posto 6), `Rede` (evento `Lanterna`), `server/Armas.equipar`
  (item tipo "lanterna" vai para `Lanterna.alternar`), `server/Inventario` (kit aceita `slot` fixo), `client/InventarioUI`
  (destaque/"equipada"/botão Equipar/Guardar e texto do item), `init.server` e `init.client` (linha na ORDEM).
- Decisões fora do contrato: (1) a lanterna é **independente da arma**: equipar a lanterna não troca `ArmaEquipada`, e pistola e
  lanterna ficam acesas juntas; o slot da lanterna vai no atributo `Player.LanternaSlot`, e a luz em `Character.LanternaLigada`.
  (2) Apertar o slot da lanterna alterna equipar/guardar (o servidor decide; o `Equipar(nil)` só guarda a arma). (3) Equipar já
  acende (`ligarAoEquipar`); F alterna depois e só age com a lanterna equipada. (4) `Range` de luz no Roblox corta em 60: o
  `SpotLight` de ~85/110 pedido ficou 60 (cortado em código). (5) Sem botão de toque para F no celular (equipar acende,
  guardar apaga).
- Conflitos/lacunas: `Filtro.nivel` não é exposto ao cliente; `Lanterna.qualidade(n)` existe (corta núcleo, preenchimento e cone
  abaixo de 2) mas ninguém a chama. Ligar no `Filtro/init` (`chamar(c, "nivel", n)`) ou em atributo, quando S1 puder.
- Afinar no Studio: `deslocamento`/`convergencia` (mão vs olhar), `meiaVidaDirecao`, `balanco`, brilho do principal/núcleo,
  largura e transparência do cone (comparar com a foto noturna), luz dos outros na cabeça (a cabeça do R15 não inclina com o
  pitch da câmera: o facho dos outros só gira com o corpo, a menos que `Aparencia`/`Camera` incline o pescoço), atravessar
  parede quando a câmera está colada (sem raycast de limite), terceira pessoa (a luz sai da câmera, longe da cabeça).

## Veículos
- **V3 (cliente)**: `client/Direcao`, `Cabine`, `HudVeiculo` escritos; NÃO testados no Studio. Nomes de Config que o cliente lê
  (todos com padrão no código, então Config/Veiculos pode omitir): `teclas.ligar/buzina`; `camera` (Vector3 ou `{x,y,z}` ou
  `{olho=...}` no espaço do Chassi; sem isso usa Banco1 + (0,1.2,0)) com opcionais `camera.tremor` (studs na VelMax, 0.03),
  `camera.roll` (graus, 0.5), `camera.seguirGiro` (>0 faz a vista girar com o carro; padrão 0 porque a câmera padrão do Roblox
  pode já seguir em VehicleSeat); tabela `direcao` opcional com `segundosAteMax`, `segundosFreio`, `segundosRolar`, `fatorRe`,
  `anguloMax`, `reducaoAngulo`, `grausPorSegundo`, `puxarGraus`, `sinalMotor`, `sinalDirecao`. `Config/Som.metrosPorStud` já existe.
- Conferir no Studio: sentido do motor e da direção (deduzido do `WorldAxis` do `Attachment0` das constraints; se o carro andar de
  ré ou virar ao contrário, trocar `sinalMotor`/`sinalDirecao` para -1); Hinge `Motor_*` precisa de `ActuatorType = Motor` e `Dir_*` de
  `Servo`; `Roda_XX` como cilindro (raio = maior de Size.Y/Z / 2); `Volante` com posição certa (o real é escondido só no cliente e
  um volante de blocos é desenhado); `Rede` deve declarar `LigarMotor` e `Buzina` (o cliente usa `pcall`).
- Cabine sobrescreve a posição da câmera em RenderPriority.Camera+2 (tremor de golpe/aterrissagem da `Camera` perde efeito dentro do
  carro). `client/Camera.luau` não foi editado.

## Veiculos
- **V2 (servidor, 2026-11-03)**: `server/Veiculos.luau`, `server/VeiculoModelo.luau` + edições em `Rede` (`LigarMotor`, `Buzina`),
  `init.server` (`Veiculos` depois de `Loot`), `Sons` (`Sons.loop`, aviso de som sem ids uma vez por nome), `Loot`
  (`registrarCompartimento`), `Armas` (`ehPecaVeiculo` em `ehAlvo` e em `acertar`, require preguiçoso de `Veiculos`), `Vida` (`"batida"`).
  NÃO testado no Studio (nem `rojo build` com os arquivos de V1 ausentes quando escrito).
- Campos de Config que V2 nomeou (V1 precisa ter): `Veiculos.tipos[t].{nome,modelo,tamanho,massa,assentos,dbBase,peso,cor}`,
  `maxAtivos`, `distanciaAcordar`, `pesoSubstituir` (lido como CHANCE 0..1 de um prop `carro` virar carro dirigível, antes do teto
  `maxAtivos`), `suspensao.{comprimento,curso,rigidez,amortecimento}`, `queda.{furado,faltando}` (studs a menos em `FreeLength`),
  `batida.limiarDeltaV`, `ruido.intervaloMotor`. `Config/Som.acoes`: `carroLigar,carroFalhar,carroBatida,buzina,pneuEstouro,porta,vidro`.
  Sons: `MotorLoop,MotorPartida,MotorFalha,CarroBatida,Buzina,PneuEstouro,PortaCarro,Vidro`. Loot: tabela `portaMalas`.
  `tipo.cor` aceita lista de `Color3` ou `{r,g,b}` (0..255 ou 0..1). `Regra.limites().aderencia` é lido como multiplicador (1 = normal)
  do atrito das rodas (`friction = 2 * aderencia`, mínimo 0.15).
- Constantes locais a virar Config: `VeiculoModelo` (raio 1.0, largura 0.7, `ANGULO_DIRECAO` 35°, torque/velocidade do servo,
  `TORQUE_FREIO` 5e4, densidade/atrito da roda); `Veiculos` (tolerância 1.3x e 2 s do anti-trapaça, pausa 1.5 s, PlaybackSpeed do motor 0.7+0.9*fração).
- **Para V3 (convenções reais do modelo)**: frente = -Z. `Motor_XX` (as 4 rodas, eixo +X): `AngularVelocity` NEGATIVA anda para a frente
  (vel = -throttle*velMax/RaioRoda; atributo `RaioRoda` = 1). `Dir_FE/Dir_FD` (Servo, eixo +Y): `TargetAngle` em graus, positivo vira à
  ESQUERDA, então usar `-steer * AnguloDirecao`. Estacionado, o servidor deixa `MotorMaxTorque = 5e4` e `AngularVelocity = 0` (freio); ao
  sentar o motorista, `MotorMaxTorque = 0` (solto): o cliente define torque/velocidade em `Motor_*` só com `MotorLigado`. O dono da
  física é o motorista; o servidor tira a posse por ~1.5 s se passar de 1.3x `VelMax` por 2 s. Ao sair do carro o motor desliga.
- Decisões de V2: motor desliga ao sair; entrar pelos prompts de `PortaE`/`PortaD` (sempre existem, mesmo com a porta "faltando");
  banco 1 primeiro, depois os livres; batida usa só a variação HORIZONTAL de velocidade (aterrissagem não conta); vidro quebrado/faltando
  fica com `CanQuery=false` (tiro atravessa e pode acertar o ocupante); carro queimado não tem prompt nem porta-malas e fica ancorado.
  Props `carro` deitados (variante de `carro_destruido`) ficam como prop. `amassado` do Estado ainda não tem visual (só a cor escurece pela carroceria).
- Peças: `Carroceria`, `Frente`, `Tras` (blocos extras, sem alvo próprio além de "Carroceria"), `Capo` (alvo "Motor"), `Teto`. Moldes
  em `ServerStorage.Modelos.Veiculos[tipo.modelo]`: MeshParts com o nome de uma peça de carroceria substituem o bloco (pivô do molde = centro do `Chassi`); não testado.
- A conferir no Studio: estabilidade da suspensão (massa 1500 vs rodas densidade 8, `rigidez/amortecimento` de V1), altura de assento vs teto
  (a cabeça do R15 passa do teto em carros baixos), `Seat:Sit`, colisão corpo x roda (grupos `VeiculoCorpo`/`VeiculoRoda`), custo do sono/acordar.

## Veiculos modelos (M2, 2026-11-03)

Escrito: `Config/VeiculosMalhas.luau` (vazio: o jogo segue em blocos), `server/VeiculoModelo` (moldes, malhas, rodas), `client/Cabine` (painel, colunas, volante-malha),
`ferramentas/modelos/gerar_config.py` e `enviar_veiculos.py` (não executados). Nada testado no Studio nem contra o Roblox real.

Decisões que o contrato não previa (o código segue a primeira opção; trocar se não servir):
- **Formato do `manifesto.json`**: o contrato só lista o conteúdo. Suposto: `{ tipos: { <tipo>: { dimensoes: [x,y,z], rodas: { FE, FD, TE, TD: [x,y,z] } } },
  arquivos: [ { arquivo, tipo, estado: "inteiro"|"queimado", textura, triangulos, pecas: { Nome: { tamanho, centro } } }, { arquivo: "roda.fbx", tipo: "roda" } ] }`
  (vetor como lista ou `{x,y,z}`; `arquivos` também aceito como objeto). Se a M1 usou outro formato, ajustar `gerar_config.py`/`enviar_veiculos.py`.
- **Blocos sem malha de mesmo nome**: `Frente`, `Tras`, `Teto` (e qualquer peça que o molde não tenha) ficariam visíveis por cima da malha. Opção A (feita): com malha, todos
  os blocos de carroceria/vidro/volante ficam `Transparency = 1` (seguem como colisão e alvo). Opção B: deixar visíveis. Opção C: criar malha só do que o molde tem e esconder o resto só no inteiro.
- **`pecas` dentro de `inteiro`/`queimado`** no `VeiculosMalhas` (campo extra, além de `modelo`/`textura`): posição de cada malha pelo `centro` do manifesto; sem isso, pela caixa
  do molde assumindo origem no centro da base. Opção: ignorar `centro` e usar sempre a caixa.
- **Escala**: se o maior lado do molde carregado difere mais de 15% de `dimensoes` (roda: 2 studs), o molde é descartado com `warn` e o carro fica em blocos. Opção: reescalar o molde.
- **`dimensoes` do Config substitui `tipo.tamanho`** (blocos, colisão, Cabine) sempre que existir no `VeiculosMalhas`, mesmo sem assetId; `rodas` só dão x e z (a altura segue a suspensão atual).
- **Carga dos moldes** é preguiçosa: `VeiculoModelo.carregar()` roda na primeira `criar` (bloqueia até terminar; chamadas concorrentes esperam). Sugestão para a Veiculos: chamar
  `VeiculoModelo.carregar()` no início de `Veiculos.iniciar` (não editei `Veiculos.luau`). Moldes já postos à mão em `ServerStorage.Modelos.Veiculos` não são baixados de novo.
- **Estrutura do que `LoadAsset` devolve** (a doc não diz): o código pega todos os MeshPart descendentes e os achata num Model `<tipo.modelo>`, `<tipo.modelo>_Queimado` ou `Roda`, pelos nomes. A doc de `LoadAsset`
  também não diz se vale só para assets do dono do jogo/place: o upload tem de ser da mesma conta/grupo do place. Conferir no Studio.
- **Textura enviada como Decal**: o `assetId` de um Decal pode não ser o id da imagem que `TextureID` espera (Roblox às vezes resolve, às vezes não). Se a textura sair branca, achar o id da imagem e gravar à mão em `enviados.json`.
- **Dono dos assets**: só `userId` (`ROBLOX_CREATOR_ID`); grupo exigiria outro campo/variável (a doc aceita `groupId`).
- **Vidro com malha**: ok = tinta `COR_VIDRO` e transparência 0.5; quebrado = clara e 0.25. O Cabine esconde `Volante_Malha` (e o bloco) só para o motorista; painel e colunas são blocos locais com medidas fixas relativas ao olho e a `dimensoes`: afinar no Studio (podem cortar a malha da cabine).
- **Roda espelhada**: a mesma malha de roda nos dois lados (sem espelhar). Largura da roda de bloco segue 0.7.

### M1 (Blender, 2026-11-03): o que saiu e o que fica para o usuário/Opus

Saída em `modelos 3d/veiculos/`: 6 `<tipo>_inteiro.fbx`, 6 `<tipo>_queimado.fbx`, `roda.fbx`, `manifesto.json` (formato do `gerar_config.py`, mais campos extras `mascara`, `ausentes`, `frente_blender`), `texturas/`, `renders/`.
Scripts: `ferramentas/modelos/{fbx_ascii,veiculos_pz,cortes.json,montar_manifesto}.py`. Tipos com as chaves do `Config/Veiculos`: sedan, compacto, suv, pickup, van, esportivo.

**DECISÃO DO USUÁRIO (textura de pintura)**: as 6 texturas `*shell.png` NÃO têm cor de pintura. Nas regiões de pintura o PNG tem alfa = 0 (35% a 82% da textura; RGB é só um cinza esverdeado de sombreado),
e a cor vem do shader do PZ (`TexturePainColor` + máscara). No Roblox, `TextureID` com alfa 0 fica transparente: a carroceria sumiria. Segui com a textura como está (nada alterado). Opções:
(A) gerar uma cópia opaca por tipo (alfa → 1, RGB em cinza claro), e pintar com `MeshPart.Color` (multiplica a textura); vidro, faróis e grade também seriam tingidos, exceto se a cópia for separada por peça.
(B) assar N variantes prontas por tipo (pintura na cor do `cor` do Config) com a máscara; mais PNGs, cor fixa por variante, vidros e faróis intactos (recomendo se quiser as cores do Config).
(C) uma cor só opaca (cinza) para todos. Os queimados (`vehicles_*_burnt.png`) são RGB opacos, sem esse problema.

Decisões que o contrato não previa (segui a primeira opção):
- **Escala dos tipos**: o sedan tem 11 studs e os outros seguem a proporção real do PZ (compacto 7,7; suv 8,8; pickup 9,5; van 9,9; esportivo 8,8), todos na mesma escala e com as `dimensoes` do manifesto.
  O contrato diz "11 studs"; 11 para todos deixaria o compacto do tamanho do sedan. Os `tamanho` do `Config/Veiculos` (9 / 11,5 / 12,5 / 12,5 / 10,5) são maiores que isso. Opção: reescalar cada tipo ao `tamanho.z` do Config (mudar `comprimento_jogo` em `cortes.json` e rodar de novo).
- **`ParaChoque` = só o dianteiro** (o bloco do jogo é um só, na frente). O traseiro fica em `Carroceria`.
- **y das rodas no manifesto = 1,0 (estimativa)**; x e z vêm dos números do PZ na mesma escala (sedan = 11 studs). O M2 só usa x e z.
- **Origem de cada FBX**: as peças ficam na posição do carro (origem = centro da base), então cada objeto tem pivô na origem do arquivo, não no seu centro. `centro`/`tamanho` do manifesto dão a posição certa.
- **Rodas nos queimados**: as malhas queimadas já trazem cotos de roda (e porta/capô soltos); mantidos como estão (queimado sem corte).
- **Roda**: veio do dump ASCII `Vehicles_Wheel.txt` (cilindro de 12 lados, 48 triângulos, convertido sem problema); eixo em X, raio 1 stud, largura 0,9. Textura `vehicle_wheel.png` 128x128 cinza.
- **Sem textura enviada nem FBX enviado**: nada foi ao Roblox.

Peças que o modelo não permite separar (todas em `Carroceria`, registradas aqui; `ausentes` do manifesto está vazio porque as 11 peças existem em todos os tipos):
- Porta traseira: os modelos só têm a porta dianteira de cada lado (a traseira, quando existe, é parte da lateral). Teto, colunas, para-choque traseiro, para-lamas e faróis: dentro de `Carroceria`.
- `PortaMalas` da van = as portas traseiras (máscara 0,255,0) e pode incluir uma faixa do para-choque traseiro. Na pickup é só a tampa da caçamba (8 triângulos); `PortaE`/`PortaD` da pickup têm 4 e 6 triângulos (uma face grande).
- `Volante` do compacto tem só 12 triângulos (o modelo é mais simples); nos outros são ~38.
- A malha do PZ é uma casca: o interior (bancos, painel) é só textura em poucas faces, e as peças são faces soltas (sem espessura). Olhar no Studio de perto.
- Frente: confirmada nos 12 modelos (capô, para-brisa, grade): é +Y no FBX original. O FBX exportado já sai com frente em -Z e cima em +Y.
- `gerar_config.py` rodado sem querer com `--help` (ele ignora argumentos) regravou `src/shared/Config/VeiculosMalhas.luau` com o mesmo conteúdo vazio de antes (sem manifesto.json no momento). Rodar de novo com o manifesto atual quando for hora.

### M3 (2026-11-03): escala por tipo, 4 cores, sair do carro. Nada testado no Studio.
- **Testar no Studio**: suspensão/estabilidade com raio de roda por tipo (0.93 a 1.43; massa da roda constante, torque x raio); carro de ~20 studs em ruas e vilas; `SairCarro`
  (E, pulo, os dois lados bloqueados vão para cima do teto); textura de Decal como `TextureID` (id pode não servir); cabeça x teto com o personagem real; painel e colunas da Cabine (afinar).
- Banco do motorista a 1.8 studs atrás do volante do modelo e fileiras a cada 2.6: suposição minha (não vinha da decisão). Folga de cabeça medida nos bancos traseiros: 0.28 a 0.38 (ok).
- Props `carro` vizinhos são ignorados no teste de colisão: carro grande pode ficar sobreposto a um prop que continuou prop.
- Os prompts "Entrar" continuam visíveis dentro do carro (E também é a tecla de sair; entrar é recusado com o personagem sentado).
- `Config/Veiculos.tamanho` (fallback em blocos) foi atualizado para a escala nova. Escala pesada: sedan 19.8 x 8.1 x 5, esportivo 19.9 (altura 4.9), van 14.6.

## Destruição (2026-11-04, contrato em `docs/destruicao.md`)
- **Correção:** a nota "janelas e portas têm CanCollide=false e CanQuery=false" (seção do Rastejador) vale só para `Folha` e `Tapume`. O `Vidro` do gerador é sólido e
  consultável (`lib.luau` 506-512), então bloqueia caminho e tiro, e quebrar abre a janela de verdade.
- **Não decidido (não implementar sem o usuário):**
  1. Bomba e tanque de combustível explodem/pegam fogo ao quebrar? Hoje só o evento `combustivel` em `Destruicao.aoQuebrar` (sem efeito).
  2. Piso do térreo e cofre do banco destrutíveis? (v1: não.)
  3. Móveis destrutíveis? Destruir o container de loot apaga o conteúdo sem drop (v1: não entram).
  4. Rastejador quebra vidro de janela para entrar? (`Cfg.arrombar.quebraVidro = false`.)
  5. Carro que atravessa parede perde velocidade? O servidor não é dono da física do carro; v1 só desconta carroceria. Carroceria 0 = motor morto e desligado; incêndio/explosão do carro?
  6. Colapso estrutural (peça em cima de um vão cai)? v1: não, tudo `Anchored`.
- **Filtro (dono do filtro):** `client/Filtro/Aberracao.luau` clona peças do mapa por célula e não ouve remoção; peça destruída continua visível no clone até a célula sair do raio.
- **Mapa:** comércio sai sempre `Concrete` (a chave `parMat` é lida e nunca definida nas paletas): parede de loja é a mais dura do mapa. Decidir se vira madeira/tijolo por paleta.
- **Implementação (Fases A/B):** vão de bala/corte em parede parte do chão da peça (contrato); parte pequena demais ou não-Block é destruída inteira; `velImpulso` do
  atropelo (30) foi inventado para o "acima de um limite" do §6.3; sem playtest ainda. **Fase C** (migrar `MonstroArrombar`, remover `abrirBuraco`/`VidaParede`) pendente.
- **Marreta:** não existe item. Entra como arma nova (`Config/Armas` + `Config/Itens` com `tipoDano = "marreta"`) sem mudar o sistema.

## Rastejador (2026-11-04)

Decisões **não previstas no contrato** (nada foi decidido além do mínimo; o usuário confirma):

- **Patinação do Walk/Run.** O ciclo do Opus anda ~0,79 studs/s (Walk) e ~4,35 studs/s (Run) no tamanho do jogo, contra 6 e 14 studs/s da IA.
  "Velocidade real ÷ nativa" daria 7,6x e 3,2x (limite `velMax` 2,5). Hoje `animacao.nativas = { Walk = 6, Run = 14 }` (provisório): o clipe toca a 1x e os pés patinam.
  Opções: aumentar o passo dos clipes no Blender, baixar as velocidades do nível 1, ou subir `velMax` aceitando ciclo rápido. Decidir.
- **Ocupante de carro (regra nova).** Jogador sentado em veículo com os dois vidros laterais (`JanelaE`/`JanelaD`) inteiros **não é atacável** pelo Rastejador (ele bate no carro);
  com um deles `quebrado`/`faltando`, vira atacável. Hoje qualquer monstro a 4 studs ataca mesmo dentro do carro. Confirmar a regra e quais vidros contam.
- **Pose de golpe** dura `max(clipe 1,46 s, intervaloGolpe 1,5 s)` para não piscar para Run entre dois golpes.
- **Distância ativa.** Sondas, objetivo e arrombar só rodam com jogador a <= `objetivo.distanciaAtiva` = 250 studs (número meu, provisório).
- **Navmesh não vê a parede quebrada** (medido). Contornado com a lista de buracos em `MonstroArrombar`; revisar quando a `Destruicao` universal entrar (`invalidarCaminhos`).
- **Parede arrombável = nome `Parede*` + tamanho** (`Parede`, `ParedeLonga`, `ParedeCurta`; espessura <= 1,6 e altura >= 6). `Fachada`, `Divisoria`, `Vidro` etc. não entram (decidir na `Destruicao`).
- **Som**: `GolpeParede` e `ParedeCai` reusam ids de `AcertoMetal` e `CarroBatida` (`confirmado = false`); `paredeQuebrando` = 65 dB. O usuário precisa ouvir.
- **Animação no servidor**: custo do Animator para dezenas de monstros e a replicação não foram medidos. O plano B (cliente, `Bone.Transform`) ficou sem código.
- **Escada interna** não testada.
- **Assets enviados** (conta do `.env`): FBX 91445481804236, imagem 120887041573147 (decal 130923450655011), Idle 113326809590535, Walk 140643199639650,
  Run 121950653077067, Attack 112763423373964, Death 95363491062836. Um envio de teste com conteúdo inválido falhou e não gerou asset.
- **Altura do jogador** medida pelo bounding box (5,234 studs, com cabelo); se a referência dos 1,8 m for outra, trocar `altura.jogadorStuds` e reexportar (`exportar_rastejador.py --altura`).

### Rastejador 2x (2026-11-04)
- **Portas:** com o corpo 2x só portas >= ~5,1 de largura deixam o caminho passar (medido, ver Estado); ~840 de ~1080 portas não. O Rastejador passa a depender de arrombar (ou de `AgentRadius` menor que a metade do comprimento do corpo; hoje 2,66). Decidir: manter assim, usar a largura do corpo (1,33) no `AgentRadius`, ou alargar portas.
- **Alcance do golpe:** `Config/Monstros.estados.distanciaAtaque` = 4 studs do centro vale para todos; a frente do corpo 2x está a 2,66 do centro. Não alterei (é de todos os monstros). Decidir se o Rastejador ganha alcance próprio.
- **Patinação do Walk:** Run ok (1,61x); Walk precisa 3,8x e está limitado a 2,5x (patina 34%). Opções: velMax 3,8, Walk mais veloz nos clipes, ou Calmo mais lento. A pendência anterior de patinação (1x) fica substituída por esta.
- **Números dobrados sem medir:** saltoMax, folgaMin, margemSalto, sondaFrente, distanciaGolpe, raioFolga, alturaBuraco, veiculo.alcance.
- **Ferramenta de teste:** neste Studio o MCP `execute_luau` não invoca `ServerStorage.Teste` nem cria Scripts (erro de Capabilities/Network). Testes de IA exigirão a sessão anterior ou liberar a capacidade.

## Armas (2026-11-05, contrato em `docs/armas.md`)

A1 (regras, configs, rede):
- **Sons novos sem teste:** o bloco de armas de `Config/Sons` (TiroFuzil ... CartuchoCai) não passou por `PreloadAsync` (A1 não usa o Studio) e ninguém ouviu. Rodar o preload no playtest e trocar o que falhar. Vários candidatos são extraídos de jogos/mods comerciais (checar direitos antes de publicar).
- **Sons reaproveitados/sem candidato:** `RecargaPenteEntra` usa inserção de pente de **rifle** (não há de pistola), serve também a pistola/Beretta. `BalancoPesado` (machado) não tem candidato de machado: whoosh genérico + "Sword Duel 402", que tem vários golpes em 2,1 s e pode soar repetido. `TiroEscopeta` não usa o "12 Gauge Shotgun 1" (vários tiros em 3,1 s). Os candidatos de nome `RecargaPistolaSai/Entra` do levantamento viraram `RecargaPenteSai/Entra` (nomes do `Config/Armas`).
- **`estadoDoAtirador` (decisão de regra, fora do doc):** correndo só vale com velocidade acima do limiar (tecla de correr parado = parado); agachado vence andando (agachado andando devagar fica 0,7, não 1,25); o servidor passa o `limiarAndar`. Se o desejado é "agachado andando = andando", trocar a ordem em `Regras/Armas.estadoDoAtirador`.
- **`Braco.resolver2Ossos(ombro, alvo, polo, l1, l2)`:** `polo` é uma **direção** (para onde o cotovelo dobra), não um ponto. Alvo mais perto que |l1 - l2| mantém a mão em |l1 - l2| (não alcança o alvo); mais longe que l1 + l2 estica. `Mola.passo` corta dt em 0,1 s e usa subpassos de 1/240 s; `Mola.novo(x,y,z)` e `Mola.impulso(estado,x,y,z)` existem além do contrato.
- **Loot:** para a arma de fogo não passar a comida, `fabrica` e `guarda` ganharam enlatado/barra/agua (a fabrica não tinha comida). Beretta e escopetas: casa (peso 1), posto (peso 1), fabrica/guarda (2-3); AR-15 2; M5, AK e lançador peso 1 em fabrica/guarda. O teste `Armas.spec` confere. Rever no playtest.
- **Calibres:** o doc diz 5 calibres e o usuário falou "6"; seguem os 5 (9mm, 5,56, 5,45, cal. 12, foguete). Nada a fazer até o usuário confirmar.
- **stylua do projeto:** `stylua --check` falha por arquivos que não são do A1: `Config/Armas.luau` (Opus), `server/Inventario.luau`, `server/Loot.luau`, `Regras/Inventario.luau`, `Regras/Loot.luau`, `tests/Inventario.spec.luau`, `tests/Loot.spec.luau` (A2 em andamento). Rodar `stylua` neles ao fim.

A2 (servidor de armas, pente, foguete) — nada testado no Studio, só Lune/selene/stylua:
- **`Regras/Loot.luau` editado (fora da lista do A2):** `Item` ganhou `pente`, `retirar` preserva o pente (senão as armas que ficam na caixa/bolsa o perdiam) e há `Loot.penteSorteado(capacidade, faixa, rng)` (testes em `Loot.spec`). Arma de fogo sorteada vira uma entrada por arma, cada uma com o seu pente (`server/Loot.comPentes`, faixa `Itens.penteLoot`).
- **Pente por tiro é silencioso:** `Inventario.definirPente(jogador, slot, n, true)` não reenvia o evento `Inventario` (uma automática faria 12 envios/s). O cliente lê o atributo `Player.Pente`; o pente no evento `Inventario` (`itens[i].pente`) só atualiza em recarga, troca de arma, largar, etc. O detalhe da arma equipada no `InventarioUI` deve preferir o atributo `Pente`.
- **`equipado` do evento `Inventario`** agora usa o atributo `ArmaSlot` (duas armas iguais com pentes diferentes), e `Armas` escreve `ArmaSlot` antes de `ArmaEquipada`.
- **Recarregar não faz ruído para os monstros:** só `Sons.tocar(somRecarga)` sem `db` e sem `Ruido.emitir`. Decidir se recarregar atrai monstro (hoje não; o tiro sim).
- **`somEquipar` (Config/Armas) não é tocado pelo servidor:** ninguém foi designado. Se o cliente (viewmodel) não tocar, sacar a arma é mudo.
- **Foguete e `Disparo`:** o lançador também manda `Disparo`, com `fim = origem + 4 studs` (o foguete é uma peça real; um rastro Neon de 600 studs seria feio). `EfeitosArma` pode ignorar o rastro quando `armaId == "lancaFoguetes"`.
- **Explosão no jogador = 6 chamadas de `Vida.dano`** (torso x1, cabeça/braços/pernas x0,5): 6 eventos `Dano` e 6 sons de dor no mesmo quadro. Se incomodar, `Vida` precisa de `danoPartes(jogador, lista, fonte)` (hoje só `dano` e `danoTodas`).
- **Foguetes ficam em `workspace.Projeteis`** (pasta criada pelo `Foguete`); `Armas` e a linha de visada da explosão a ignoram. Limite de 8 no ar: acima disso o tiro é recusado sem gastar pente.
- **`ArmasAnim.mao`:** `Armas.montarModelo` usa `mao.porClasse[classe]` se for CFrame, senão `mao.C0`, senão `CFrame.new()`. O A4 pode escolher qualquer um dos dois.
- **Dano de explosão em monstro** conta da superfície da peça mais perto (não do centro do modelo), sem atenuação por parede (o doc só pede `fatorParede` para jogadores).
- **Arma com `Reserva` em duas pilhas:** `Reserva` = soma de todas as pilhas do calibre; a recarga tira das primeiras pilhas.

A5 (cliente e primeira pessoa) — NADA testado no Studio (cliente escrito às cegas; só selene/stylua/Lune dos módulos puros). Arquivos: `client/ArmasCliente`, `ArmasViewmodel`, `EfeitosArma`, `HudMunicao`, `Camera.coice`, `Config/ArmasVista`, `InventarioUI` (pente/calibre/reserva), `init.client` (ORDEM: Viewmodel, Efeitos e Hud antes de `ArmasCliente`).
- **Poses do viewmodel são chute:** todos os números de `Config/ArmasVista` (base de cada classe, ombros, polo, poses de sacar/recarga/golpe/bombear, convenção de ângulos em Euler YXZ somados) nunca foram vistos. Afinar no playtest com a arma na mão; a ordem a olhar é: arma aparece e está na posição certa, braços alcançam a empunhadura, cano aponta para o centro, depois as animações.
- **Convenções que assumi de `ArmaModelo` (A3):** `Shared/ArmaModelo.luau` com `criar(id)` devolvendo Model com `Cabo` (BasePart, pode ser descendente), Attachments `Boca`/`Ejecao`/`ApoioEsquerdo`; cano/ponta da arma para **-Z** e cima +Y no espaço do Cabo (inclusive faca/machado/pé de cabra: eixo longo em -Z, o viewmodel os inclina com `rot.x` positivo). O viewmodel clona, ancora tudo, zera `PivotOffset` do Cabo e usa `PrimaryPart = Cabo`. Sem `ApoioEsquerdo` o viewmodel usa `ArmasVista.classes[c].apoioPadrao`. Se `ArmaModelo` não existir/falhar: warn uma vez, sem viewmodel (a arma real fica visível, o `ArmaNaMao` do servidor continua) e tenta de novo a cada 2 s.
- **`golpeou(armaId, indice)`:** o `ArmasCliente` passa um 2º argumento (1/2; a faca alterna estocada e corte). `ArmasSinais.disparar` repassa, quem não usa ignora. O A4 (`ArmasTerceira`) pode usar o mesmo índice para os clipes `Golpe1/Golpe2` ficarem iguais ao viewmodel.
- **Coice da câmera (`Camera.coice(vertical, horizontal)`):** é um deslocamento visual por cima da câmera do Roblox (sobe na hora, decai em ~0,4 s, acumula em rajada até 14 graus); não mexe no estado interno da câmera padrão, então a mira volta ao ponto de partida sozinha. O tiro seguinte sai da câmera já deslocada (sobe em rajada). Respeita `Pref_Tremor`/`Pref_Intensidade`; some na 3ª pessoa. O coice da arma no viewmodel respeita as mesmas preferências, mas com piso de 35% (`ArmasVista.coice.minimo`) porque é animação da arma, não tremor.
- **Esconder o corpo real:** `LocalTransparencyModifier = 1` em braços, mãos (e `Bloco`/costuras filhas) e `ArmaNaMao` do próprio personagem, a cada quadro enquanto o viewmodel está ativo (1ª pessoa, arma na mão, vivo, fora de carro); guarda o valor anterior e devolve ao desativar. `SurfaceGui` dessas peças é desligada e religada igual. Não testado contra o `TransparencyController` do PlayerModule (o viewmodel roda em `Camera+4`, depois dele).
- **Filtro (aberração por ViewportFrame):** o viewmodel mora em `workspace.CurrentCamera`; a `Aberracao` clona só `Mapa`, monstros e outros jogadores, então o viewmodel aparece uma vez só, **sem a franja de cor**. Se o usuário quiser a franja, é trabalho do filtro (clonar o viewmodel). Plano B do doc (arma real animada sem viewmodel) não foi necessário.
- **Efeitos que o doc listou e eu NÃO fiz:** fumaça do cano e marca de bala no ponto de acerto (opcionais). Cápsula só nas classes `pistola`/`fuzil`, só no viewmodel (1ª pessoa do dono); escopeta/lançador sem cápsula; outros jogadores sem cápsula. Rastro do tiro próprio: raio local da boca na direção da câmera (sem o espalhamento do servidor, exceto o cone sorteado dos chumbinhos); o lançador não tem rastro.
- **Textura de fumaça da explosão:** `rbxasset://textures/particles/smoke_main.dds` (nativa do Roblox). Não conferida; se não aparecer, a explosão ainda mostra a esfera Neon e a luz.
- **`somEquipar` e `somVazio` são locais:** `ArmasCliente` toca `somEquipar` ao sacar e `somVazio` (CliqueVazio) no gatilho vazio via `SonsLocal.tocar` (o servidor nem vê o gatilho vazio). Só o dono ouve; os outros jogadores não ouvem o equipar.
- **HUD no celular:** `HudMunicao` fica no canto inferior direito (220x84, 12 px de margem), abaixo do botão ATACAR (84 px a 120 px do fundo); o botão de recarga "R" (60 px) fica à esquerda do ATACAR. Em tela de 667 px a barra de slots do `InventarioUI` pode encostar no HUD. Conferir com emulação de celular.
- **Previsão de pente:** `ArmasCliente` bloqueia o gatilho com pente local 0 (e clica). Se o atributo `Pente` vier 0 por engano (ex.: servidor sem pente gravado), a arma "trava"; o servidor escreve `Inventario.pente(...) or 0`, então vale conferir no playtest que a arma de fábrica/kit nasce cheia. Sem o atributo (nil) o gatilho não é bloqueado.
- **Mira central:** 4 ticks que abrem com `espalhamentoTotal` local (bloom previsto + estado local), só estético; a mira original (ponto e marcador de acerto) ficou igual. Arma corpo a corpo: só o ponto.
- **`vazio` e recarga recusada:** se o servidor não responder `Recarregando = true` em 0,8 s, o cliente cancela a animação de recarga sozinho (`recargaFim(id, true)`).

A3 (modelos: Blender, Open Cloud, `Config/ArmasMalhas`, `Shared/ArmaModelo`):
- **ENVIO PARADO: "User is moderated" (HTTP 403) na Open Cloud, 2026-11-05.** Foram aceitos Beretta (fbx 101995038694061, imagem 101851030317324), Pistola (113361719014435, 71595023366000)
  e Faca (135669372098483, 88186680750227); logo depois da Faca, **todo** pedido (até leitura) devolve 403 "User is moderated", e o Studio do place `kay_113p` caiu da lista (reabrir o
  Studio pode exigir resolver a moderação da conta). Causa **não confirmada**; suspeita: a textura da Faca (`Map__2.png`, sangue) ficou em `Reviewing` e pode ter sido recusada. Conferir a conta
  em https://www.roblox.com/info/moderation e os 3 PNG em "Reviewing". Nada foi gasto (sem pedido de Robux). Quando liberar: `python ferramentas/modelos/enviar_armas.py --imagem Image` (idempotente por sha256;
  enviar o resto) e **ler o MeshId** no Studio (ver abaixo), depois `python ferramentas/modelos/gerar_config_armas.py`. Se a Faca for o motivo: trocar a textura dela (PNG sem sangue) e reexportar.
- **`ArmasMalhas` hoje: só `beretta` tem malha** (MeshId 129689935791597 lido no teste); as outras 10 estão `false` e `ArmaModelo` usa o bloco provisório (já com o tamanho/âncoras reais do manifesto). `pistola` e `faca`
  foram enviadas, falta só ler o MeshId: `InsertService:LoadAsset(modelo)` no Studio (edição) -> `MeshPart.MeshId`; gravar em `enviados.json` na entrada do `.fbx` como `"meshId": 123` e rodar `gerar_config_armas.py`.
  O assetId do Model **não** é o MeshId; o jogo usa o MeshId com `AssetService:CreateMeshPartAsync` (testado em edição, tamanho idêntico), não `LoadAsset`, porque o cliente (viewmodel) também precisa montar a arma.
- **Textura enviada como `Image` (não Decal):** a Open Cloud aceitou `assetType = "Image"` e o assetId já serve em `MeshPart.TextureID` (testado na Beretta). Dispensa a conversão Decal -> imagem das pistas de veículo/monstro.
- **Medido (Beretta, Studio):** a importação do FBX é **1 unidade = 1 stud** (fator 1,0; o Size bateu com o manifesto na 4ª casa), sem giro: o centro da caixa e a ponta da frente saíram onde o manifesto previa
  (conferido pelos vértices via `EditableMesh`: X, Y e Z sem espelho). A escrita é B = (-a, c, b) para o ponto Roblox (a, b, c) (ver `exportar_armas.py`). `ArmaModelo` ainda reescala o MeshPart para `tamanho`.
- **Escolhas de modelagem (minhas, sem decisão do usuário):** `escopetaM1912` usa só o conjunto "v_" do .blend (as duas versões, view e world, estão empilhadas no mesmo arquivo; o conjunto de baixo tem uma textura só e mais detalhe;
  os nomes das peças "v_/w_" estão trocados no bolt). Carabina M5 sem o pente solto, o cartucho e a caixa (itens de vitrine) e Beretta sem `ammo`/`bullet`. O **foguete do lançador é uma segunda MeshPart (`Foguete`)
  encaixada no cano** (3% de sobreposição) e conta no comprimento de 2,76 studs, então o tubo sozinho fica com ~1,7: se o usuário quiser o tubo com 0,95 m, dá ~4,2 studs ao todo. Quem anima pode esconder `Foguete` depois do disparo.
  Pé de cabra: a garra grande aponta para a frente (-Z), curvando para baixo. Machado: cabo diagonal na origem corrigido por PCA; gume para baixo, cabeça para a frente. Faca: gume para baixo, ponta à frente.
  Pontos `Mira`/`Ejecao`/`ApoioEsquerdo` são estimados à mão por render (marcadores nos PNG em `modelos 3d/armas_roblox/renders/`); A4/A5 ajustam.
- **Texturas:** atlas único por arma (Beretta: 5 imagens em 396x264, metade da resolução; M5: materiais de cor chapada viram células 4x4; AR-15: 256 + célula de vidro). A M5 sai quase preta (as cores dela são `cor_*.png` muito escuras, não é erro).
  Atlas e FBX em `modelos 3d/armas_roblox/<id>/`; manifesto, `enviados.json` e renders (lado e 3/4, com marcadores) na pasta-mãe.
- **Verificação que ficou faltando por causa do Studio fora do ar:** fileira das 11 com `screen_capture`, conferir tamanhos das 10 não enviadas e testar `ArmaModelo.criar` em edição (o módulo passou em selene/stylua/rojo build, mas não rodou no Studio).
  Na 1ª chamada sem molde `criar` devolve o bloco e dispara o download (o módulo já começa a baixar tudo ao ser requerido: `task.defer(precarregar)`); `ArmaModelo.pronta(id)` diz se a malha chegou.
- **Escala 0,28 x 2,908:** nada mexido (ver `docs/armas.md` §0); os tamanhos das armas usam 2,908 studs/m como a tabela do §1.

A4 (animação do corpo, 3ª pessoa) — NADA visto no Studio (o place `kay_113p` caiu no meio do trabalho e não voltou; só foi visto 1 quadro do fuzil e 1 da pistola na bancada de FK):
- **Feito local:** `assets/animacoes/armas/{faca,contundente,machado,pistola,fuzil,escopeta,lancador}.json` (28 clipes; poses como dado, `de`+`juntas`, easing na chegada, marcador `Impacto`, bloco `ik`) + `mao.json`; `lune run ferramentas/animacao/montar_armas.luau`
  gera `build/anim_armas/<classe>_<Clipe>.rbxm` (conferido por `deserializeModel`: Pose aninhada pela hierarquia do R15, Weight 0 nos pais não animados); `python ferramentas/animacao/gerar_config.py` gera `Config/ArmasAnim.luau`;
  `tests/ArmasAnimDados.spec.luau` confere os JSON contra `Config/Armas` (clipes exigidos, marcador `Impacto` = `atrasoImpacto`, velocidade de recarga 0,6-1,6x, Fire x cadência).
- **AGUARDA UPLOAD (Open Cloud 403 "User is moderated", ver A3):** os 28 clipes estão com id `false` em `Config/ArmasAnim.animacoes`; `ArmasTerceira` não toca clipe sem id (sem erro). Quando a conta liberar:
  `lune run ferramentas/animacao/montar_armas.luau` -> `python ferramentas/animacao/enviar_animacoes.py` (para no 1º erro; idempotente por sha256; grava `ferramentas/animacao/enviados.json`) -> `python ferramentas/animacao/gerar_config.py`.
  Se pedir Robux, parar. A tela de teste sem upload: no Studio, registrar a `KeyframeSequence` no cliente e pôr o id no atributo do jogador `AnimTeste_<classe>_<Clipe>` (gancho só em `RunService:IsStudio()`).
- **Poses são CHUTE geométrico, sem folha de quadros revisada.** Ordem para olhar no Studio: mão na empunhadura, cano horizontal, braço não atravessa o corpo, depois golpes/recargas. `mao.json` (C0 por classe) está em -90° em X (empunhadura padrão do R15) para todas, exceto `machado` (0°, cabo na vertical, gume para a frente);
  as inclinações do cano ficam no pulso (`RightWrist` -26 no fuzil/escopeta). Calibrar `mao.porClasse` com as malhas reais (A3 ainda sem MeshId; o bloco provisório tem as âncoras certas). Âncoras reais de `ApoioEsquerdo` (A3): AR-15 z -0,97; M5 -0,78; AK -1,04; escopeta -1,59; M1912 -1,18; lança -0,75. O fuzil sentado perto do corpo
  alcança bem; escopeta (-1,59) e AK (-1,04) podem passar do alcance da mão esquerda (braço 1,85 studs) e o IK só estica: se acontecer, aproximar a arma do corpo na pose `mira` da classe.
- **IKControl da mão esquerda: escrito, NÃO testado** (precisava dos 3 quadros no playtest). Configuração: `Type = Position`, `ChainRoot = LeftUpperArm`, `EndEffector = LeftHand.LeftGripAttachment`, `Pole` = Attachment em UpperTorso (-1,6; -1,4; 0,5), `Target = ArmaNaMao.Cabo.ApoioEsquerdo` (procurado a cada 0,2 s),
  peso suave 0,25 s, desligado nos clipes de `ik.desligar` e nas janelas (`escopeta.Fire` 0,2-0,58 s, bombeio). **Fallback do §9 NÃO implementado:** sem IK (ou sem `ApoioEsquerdo`) vale só a pose da mão esquerda do clipe (aproximada). Decidir depois do teste.
- **Rig do Studio usa `AnimationConstraint`, não `Motor6D`** (`CreateHumanoidModelFromDescription` em edição: 15 `AnimationConstraint` com `Transform`; `Players:CreateHumanoidModelFromDescription`). Conferir no playtest qual o personagem real do jogo tem. `ArmasTerceira` aceita os dois (`Transform`), mas se a
  escrita de `Transform` em `AnimationConstraint` não aparecer na tela, a camada de mira precisa de outro caminho (ex.: `IKControl` tipo `LookAt` na cabeça). Aceita o risco de a camada de mira não ter sido vista nenhuma vez.
- **Camada de mira (decisões minhas, números em `Config/ArmasAnim.mira`):** cintura 35%, pescoço 65%, ombros 65% do pitch (clamps 30/50/55 graus); ombros só em arma de fogo (os dois em duas mãos, só o direito em uma mão); pré-multiplica rotação X no `Transform` sem acumular
  (compara com o que escreveu no quadro anterior). Pitch próprio = câmera; dos outros = atributo `Player.MiraPitch` suavizado. Sem animação enviada, os braços ficam pendurados e os ombros girando com a câmera ficam estranhos: só vale com os clipes. Em 3ª pessoa "Classic" o corpo não gira com a câmera (guinada não é minha).
- **Pendência de integração:** `ArmasTerceira` precisa de uma linha em `client/init.client.luau` (ORDEM, depois de `ArmasCliente`; é do A5/Opus). O sinal `golpeou(armaId, indice)` do A5 é usado (índice 1/2 da faca). O tubo da escopeta usa `recarregou(armaId, duracaoTotal)` e deduz o nº de cartuchos de `(duracao - inicio - fim)/porCartucho`.
- **Sobras de teste:** a bancada de FK está em `ferramentas/animacao/bancada.luau` (colar como ModuleScript em ServerStorage no Studio; usa `ServerScriptService.Server.Aparencia.revestir`); `screen_capture` aceita `camera_position`/`look_at_position`. O Studio caiu com `workspace.Bancada` e `ServerStorage.Bancada` criados em edição (se o place for restaurado sem salvar, sumiram; se salvou, apagar os dois).

## Combustível (2026-11-05, contrato em `docs/combustivel.md`)
Escrito por 5 agentes Sonnet (S1 regras/config, S2 servidor do carro, S3 posto/mangueira/mão, S4 cliente do carro, S5 cliente da mangueira); `pwsh scripts/checar.ps1` verde. **NADA testado no Studio ainda.**
- **Para ver no Studio (nada disto foi visto):** posição/cor da `Tampa` nos 6 tipos e com malha (sedan calculado em ≈(-4,1; 0,25; 6,5)); `Bocal` da bomba e a mangueira Verlet (cilindro ao longo da corda, pontas, chão, 1ª pessoa: a mão pode estar invisível);
  prompts E/F da bomba sem sobrepor (S3 pôs `UIOffset (0,-70)` no F); etiqueta de gasolina sobre a Tampa em 1ª/3ª pessoa; medidor na `Cabine` (pode ficar tapado pelo volante) e o "E/F" no `SurfaceGui`; botões touch (grade 2×2); `Seat:Sit` ao trocar de banco com 2 clientes; `irPosto`/`darGasolina`/`estadoCombustivel` (Teste).
- **Defaults meus (mudar se quiser):** sobra além da capacidade ao despejar se perde; plugar/despejar só com motor desligado; mangueira solta ao ligar o motor, ao equipar arma, ao sentar; arma equipada IMPEDE pegar mangueira/segurar recipiente ("Guarde a arma primeiro"; o certo seria `Armas.guardar(jogador)` exportado, pois `desequipar` é local em `Armas.luau`);
  autonomia 15 min (a fundo) / 60 min (parado); tanques 40–90 L; ruído `abastecer` 50 dB, `encher` 45, `despejar` 40; carros do mapa nascem com 5–60% (15% vazios).
- **Sons provisórios:** `Abastecendo`/`Despejar` (ids de PassoAgua), `MangueiraEncaixa` (PortaCarro), `MangueiraSolta` (PassoMetal), `confirmado = false`. Não há som de jorro/esguicho; decidir se sobe áudio novo (custo/limites em `pesquisa/limites-assets-roblox.md`).
- **Constantes locais que deviam ir para Config:** `Veiculos.luau` ~57-62 (`PASSO_COMBUSTIVEL`, `VEL_ESTACIONAR`, `TEMPO_ESTACIONAR`, `ESPERA_TROCA`, `LIMIAR_LADO`) e `Combustivel.luau` (`INTERVALO_RUIDO`, `FOLGA`).
- **Pedal:** o consumo usa `ThrottleFloat` do `VehicleSeat` do motorista; se o servidor não o recebe, cai no fator 0,4 do pedal (consome só pela velocidade). Medir no Studio.
- **Tecla F:** em `Direcao` o F de trocar de banco usa `InputBegan` próprio (não `Teclas.ligar`) para não engolir o F de "Encher recipiente" a pé. Trocar de banco motorista↔passageiro passa por `sair()`/`entrar()` e pisca HUD/Cabine um quadro.
- **Passageiro:** sai o motorista e fica passageiro → o motor desliga, o carro fica livre (dono de rede = passageiro mais antigo, freio travado). Para dirigir, F até o `Banco1` e ligar (G). A barra do HUD não interpola entre as atualizações de 10 Hz.
- **Mão:** o recipiente usa `ItemNaMao.definir(jogador, "uso", id)` (sistema de `docs/itens-no-mundo.md`), então o galão aparece na mão e, ao largar, no chão. Se comer/beber segurando o recipiente, o modelo some e `reaplicarMaos` o repõe no passo seguinte.
- **Fora do escopo:** sifão (tirar gasolina de carro), explosão da bomba/carro com gasolina (`docs/pendencias-integracao.md` "Destruição"), preço/economia, persistência, litros parciais, atacar sentado no carro (`Armas.atacar` não checa assento), `garrafaVazia` fora da cozinha (só em `cozinha_casa` e posto/oficina), devolver `garrafaVazia` ao beber `agua`.
- **Doc de pendências antigas:** `docs/pendencias-integracao.md:52` e `:73` descrevem `Mapa.Pontos` no Loot; já está desatualizado (o código só lê `Construcoes`; os pontos agora são de `ItensChao`).

### Armas: Faca fora do envio (2026-11-05, pedido do usuário)
- O usuário confirmou que a **Faca** causou a moderação da conta (403 "User is moderated"; textura `Map__2.png` com sangue). A Faca foi **removida do pipeline**:
  `armas_modelos.json > excluidas` (exportar, enviar e gerar_config a ignoram), saída local `modelos 3d/armas_roblox/faca/` e renders apagados (regeneráveis de `_ps2/Faca`),
  entrada tirada do `manifesto.json`, `Config/ArmasMalhas.faca = false`. A arma `faca` **continua no jogo** (bloco provisório na mão, números de Config/Armas intactos): decisão do usuário se vira outra malha sem sangue ou sai do jogo.
- Os assets já enviados da Faca (modelo 135669372098483, imagem 88186680750227) continuam na conta; a Open Cloud não deixa apagar enquanto a conta estiver moderada: remover no Creator Hub.
- Antes de reenviar as 8 restantes: conferir as texturas. `peDeCabra.png` tem faixa marrom-avermelhada (parece ferrugem, mas pode ser lida como sangue); `machado.png` é madeira e metal escuro. Decidir com o usuário se escurece/dessatura a faixa do pé de cabra.
- Nada será enviado até a conta ser liberada e o usuário mandar retomar.
