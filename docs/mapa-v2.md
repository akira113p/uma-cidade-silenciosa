# Mapa v2 — interiores, cidade de prédios, rios, floresta de pinheiros (contrato dos módulos)

Pedido do usuário (2026-11-02): interiores das casas feitos **por código**; biblioteca de **mobília** e de **edifícios base**
(cada um só muda de cor/paleta); montar tudo no mapa; **cidade central só de prédios**, cidade um pouco maior; lista de
construções que o usuário não pediu (mercado, posto, igreja, cemitério…) e colocá-las no mapa; **floresta de pinheiros do
norte da Europa**, mais árvores; **decoração ao longo das estradas** e as **próprias estradas**; **terreno** diferente
(colinas); **rios** atravessando o mapa com **pontes**; **viadutos** com estrada; vida urbana melhor em geral.

Tudo é gerado por `lune run ferramentas/gerar_mapa.luau` → `mapa/Mapa.rbxm` (o Rojo sincroniza em `Workspace.Mapa`). Nada é
feito à mão no Studio. Números do layout: `src/shared/Config/Mundo.luau`. Geometria derivada (estradas, pontes, viadutos,
rios suavizados): `ferramentas/mapa/plano.luau` (`ctx.plano`).

## 1. Arquivos e donos

| Arquivo (em `ferramentas/mapa/`) | Dono | O que é |
|---|---|---|
| `lib.luau`, `plano.luau`, `mobilia.luau`, `props.luau`, `catalogo.luau`, `*_tamanhos.luau`, `catalogo_contrato.luau`, `../gerar_mapa.luau`, `../testar_modulo.luau` | **Opus** | infraestrutura. **Ninguém mais edita.** Faltou função? Escreva no seu módulo e diga no relatório. |
| `mobilia_casa.luau` | agente M1 | móveis domésticos (nomes em `mobilia_tamanhos.luau`, dono `casa`) |
| `mobilia_comercial.luau` | agente M2 | móveis de comércio, serviço, igreja, indústria, acampamento (dono `comercial`) |
| `edificios_casas.luau` | agente E1 | casa_pequena, casa_media, casa_grande, sobrado, cabana |
| `edificios_altos.luau` | agente E2 | apartamentos, escritorio, torre, hotel, predio_misto, garagem |
| `edificios_comercio.luau` | agente E3 | mercado, lojas, farmácia, restaurante, bar, banco, posto, lanchonete, motel, oficina |
| `edificios_servicos.luau` | agente E4 | hospital, delegacia, bombeiros, escola, prefeitura, biblioteca |
| `edificios_especiais.luau` | agente E5 | igreja, capela, cripta, guarda (+ áreas `cemiterio`, `acampamento`) |
| `edificios_industria.luau` | agente E6 | galpões, celeiro, serraria (+ estruturas e áreas `fazenda`, `serraria`, `ferroVelho`, `patioFabrica`) |
| `relevo.luau`, `../../src/server/Rios.luau` | agente T1 | terreno (colinas), leito/margens dos rios, água |
| `estradas.luau`, `pontes.luau` | agente T2 | asfalto das estradas, faixas; pontes, passarelas, viadutos |
| `floresta.luau` | agente F1 | floresta boreal de pinheiros e toda a vegetação/pedras/tocos |
| `props_urbanos.luau`, `decoracao.luau` | agente D1 | props externos (postes, carros, placas…) e sua colocação nas ruas/estradas |
| `cidade.luau` | agente L1 | laje/ruas/calçadas/lotes da cidade, colocação dos edifícios por região, parques |
| `areas.luau` | agente L2 | pads, vilas, fábrica, fazenda, posto da guarda e os POIs de `Mundo.pois` |

Cada agente só cria/edita os **seus** arquivos (e arquivos de teste `ferramentas/mapa/_teste_<agente>_*.luau` que apaga ao
terminar). Código legado de referência (não editar): `_legado_gerar_mapa_v1.luau`, `_legado_checar_mapa_v1.luau`.

## 2. Pipeline e ordem

`gerar_mapa.luau` cria `ctx = lib.novoCtx(Mundo, plano)` e chama `require("./mapa/<modulo>").gerar(ctx)` nesta ordem
(módulo ausente é ignorado com aviso):

1. `relevo` — define `ctx.altura(x,z)`; cria o chão (pasta `Chao`) e o leito/margens dos rios; marcadores de água em `Rios`.
2. `estradas` — asfalto em `Ruas` (todas as `plano.estradas`, **só nos trechos livres** `plano.trechosLivres(seg)`).
3. `pontes` — pontes (`plano.pontes`), viadutos (`plano.viadutos`), passarelas (`Mundo.pontesPedestres`).
4. `cidade` — laje de asfalto, ruas, calçadas, lotes, construções, parques.
5. `areas` — pads planos de todas as áreas, vilas, fábrica, fazenda, guarda, POIs. Preenche `ctx.spawnsPlanejados`.
6. `floresta` — árvores e vegetação (precisa que tudo que ocupa chão já exista: usa `ctx.ocupado` e `plano`).
7. `decoracao` — props nas ruas e estradas.
8. (orquestrador) bordas, zonas, pontos de Spawn/Loot/Monstro, gravação.

Quem precisa de algo de um módulo posterior **não** usa: pede por `ctx` (função registrada) ou deixa para o módulo posterior.

Executar/testar sem mexer no mapa oficial (**NUNCA** rodar com `--final`; só o Opus):
```
lune run ferramentas/gerar_mapa.luau --so relevo,estradas --saida build/<seuagente>.rbxm
lune run ferramentas/testar_modulo.luau edificios_casas          # só módulos edificios_* (confere o contrato, grava build/teste_<modulo>.rbxm)
```
`--so` roda só os módulos listados (os que dependem de outros funcionam sem eles: `ctx.altura` = 0, sem rios…).
Agentes que testam sozinhos devem usar sempre `--saida build/<nome-único>.rbxm`.

## 3. `ctx` (resumo; a fonte é `lib.luau` — leia-o)

- Peças: `ctx.bloco(pai, cf, nome, cx,cy,cz, sx,sy,sz, cor, material, op)`, `ctx.cilindro`, `ctx.esfera`, `ctx.cunha`, `ctx.rampa`
  (laje inclinada entre dois pontos), `ctx.laje(pasta, nome, x0,x1,z0,z1, topo, esp, cor, mat)` (mundo; registra superfície).
  `cf` = CFrame do quadro local (origem = centro da pegada, Y = topo do piso, frente = −Z); `cx,cy,cz` = centro LOCAL da peça.
  Cor = `{r,g,b}` 0–255. `op`: `colide=false`, `consulta=false` (CanQuery), `transparencia`, `refletancia`, `sombra=false`, `rotY`, `rot`.
- Construção: `ctx.parede(...)` (aberturas porta/janela/vão/arco), `ctx.piso(...)` (com furos), `ctx.escada(...)`,
  `ctx.telhadoDuasAguas(...)`, `ctx.modeloConstrucao(spec, tipo, variante, w, d, altura, andares)` (cria o Model com atributos
  + `Pegada`), `ctx.registrarConstrucao(spec, modelo, info)` (cria os pontos de Loot).
- Mundo: `ctx.altura(x,z)`, `ctx.topoEm(x,z)`, `ctx.ocupado(x,z,margem)`, `ctx.retanguloOcupado(...)`, `ctx.inserirObstaculo(x0,x1,z0,z1)`,
  `ctx.registrarSuperficie`, `ctx.ponto(nome,x,z,attrs,y?)`, `ctx.loot(x,topoPiso,z,tabela,zona)`, `ctx.rng("nome")` (sorteio
  independente por módulo; **nunca** `math.random`), `ctx.plano`, `ctx.pastas.<Pasta>`, `ctx.Mundo`.
- Pastas do mapa: `Chao`, `Ruas`, `Construcoes`, `Vegetacao`, `Bordas`, `Zonas`, `Pontos`, `Rios`, `Props`.
  `Chao` e `Ruas` só têm **piso** (peças cujo topo se anda em cima; o checker as trata como chão). Guarda-corpo, poste, pilar,
  carro, cerca → `Props`. Construções (Model com atributo `Tipo`) → `Construcoes`. Árvores, arbustos, pedras, tocos → `Vegetacao`.
- `plano` (leia `plano.luau`): `plano.estradas` (cada uma com `segs`, `rets`), `plano.pontes`, `plano.viadutos`, `plano.rios`,
  `plano.cidade`/`vilas`/`fabrica`/`planicie`/`guarda`/`pois` (retângulos `{x0,x1,z0,z1}`), `plano.planos` (tudo que é plano
  em Y = 0,5), `plano.distPlano(x,z)`, `plano.folgaRio(x,z)`, `plano.profundidadeRio(x,z)`, `plano.zonaEm(x,z)`,
  `plano.emAreaConstruida(x,z,margem)`, `plano.emRio(x,z,margem)`, `plano.meiaVia/passo/meiaCidade`.

## 4. Convenções (todos)

- **Escala:** ~3 studs por metro. Porta 4,5×7,5. Pé-direito 12 (um andar = 12). Personagem R15 ≈ 5 de altura, largura 2,
  pula 6, anda 16 st/s. **Corredores e portas ≥ 5 de largura livre; escadas ≥ 4,5**; nenhum móvel pode bloquear porta, escada
  ou caminho entre cômodos. Degrau de escada ≤ 1 de subida (a `ctx.escada` já faz).
- **Estilo (PS1 de terror, noite):** blocos simples e bem proporcionados, **sem textura/imagem**, só `Material` real e cor.
  Cores dessaturadas e escuras (parede de reboco verde-acinzentado `{96,110,98}`, cinza `{120,122,118}`, bege sujo `{150,138,115}`;
  piso de tábua escura `{70,48,36}` em `WoodPlanks`; móveis de madeira `{110,80,60}` em `Wood`; eletrodomésticos brancos
  `{200,200,205}` `SmoothPlastic`/`Metal`; bancada de `Marble`; igreja de tijolo claro `Brick` `{175,175,172}`; telhados escuros
  `{60,45,42}` `Slate`). Olhe as imagens de referência (§9). Detalhe é dado por **peças pequenas bem escolhidas** (batente,
  rodapé, maçaneta, puxador, moldura, cornija, calha, ímã na geladeira), não por mais ruído.
- **Materiais permitidos** (nomes do enum `Enum.Material`, importam para o som dos passos — `Config/Som.superficies`):
  Concrete, Brick, WoodPlanks, Wood, Metal, DiamondPlate, CorrodedMetal, Slate, Marble, Granite, Cobblestone, Pavement, Asphalt,
  Rock, Basalt, Limestone, Sandstone, Fabric (tapete: silencioso), Plastic, SmoothPlastic, Glass, Grass, LeafyGrass, Ground, Mud,
  Sand, Snow, Pebble, Ice, Neon, Foil. Piso de interior: WoodPlanks / Concrete / Marble / Fabric (tapete) / Slate.
- **Rotação:** construções giram só em múltiplos de 90° (`spec.cf` já vem rotacionado — escreva tudo em coordenadas locais e
  use `cf`). Em locais: **frente = −Z**; porta de entrada na face −Z, centrada ou deslocada.
- **Determinismo:** só `ctx.rng("nome")`. Nada de `math.random`, `os.time`, `tick`.
- **Peças:** todas Anchored (a lib já faz), nenhuma > 2048. Sem União, sem MeshPart (não dá para criar no Lune). `TopSurface`/
  `BottomSurface` Smooth já vêm da lib. Evite faces coplanares sobrepostas (z-fighting): afaste 0,02–0,05.
  Detalhe pequeno (< 0,6 st) → `consulta = false` e `sombra = false` (não conta como parede no som nem pesa na sombra).
  Peça que o jogador atravessa de propósito (folha de porta, moldura, cortina) → `colide = false`.
- **Parede e som:** cada parede de verdade entre fonte e ouvinte tira 10 dB (raycast em peças com `CanQuery`). Paredes sólidas
  (≥ 0,8 de espessura, `consulta = true`). Divisórias finas de baia/cela também valem.
- **Interiores:** o piso do térreo é Y local 0 (topo do pad). Laje entre andares: topo em `andar × 12`, espessura ≥ 0,8.
  **Pé-direito livre = 12 − espessura da laje.** Andar de cima: forro/teto do último andar + telhado. Iluminação: sem luzes
  (apagão) — só `Neon` em letreiros/painéis. Janelas com vidro: `ctx.parede` já faz.
- **Loot de interior:** cada construção devolve `info.loot = { {x,y,z, tabela?} ... }` (local; y = topo do piso do andar) — 1 ponto
  por 2–3 cômodos relevantes, sempre sobre piso livre, longe de porta e escada (≥ 3 st), nunca dentro de móvel. Térreo e andares de
  cima. Faixa por tipo: casa 2–4; comércio 3–6; prédio alto 4–10; hospital/delegacia 6–10; galpão 3–6.
- **Orçamento de peças por construção:** casa ≤ 400; prédio alto ≤ 1100; comércio/serviço ≤ 700; galpão ≤ 500. Reuse peças: uma
  peça grande é melhor que cinco pequenas. Andares de cima de prédios altos: planta enxuta (corredor, salas com 2–4 móveis).
- **Nomes:** funções e variáveis em português como o resto do projeto (`iniciar`, `jogador`, `parede`). Tabs, aspas duplas, coluna
  120 (StyLua). Cabeçalho de 2–3 linhas no arquivo. Comentário só onde o porquê não é óbvio. Rode `stylua <seus arquivos>`.
- **Verificação:** o que você entrega precisa rodar sem erro, com contagem de peças impressa e dentro do orçamento. Não há
  Studio nesta etapa (outros agentes usam o mesmo): **não** use as ferramentas MCP do Roblox Studio. O Opus revisa visualmente.

## 5. Contrato dos edifícios (módulos `edificios_*`)

Um módulo exporta `M.catalogo = { [variante] = { paletas = { {...}, ... }, construir = function(ctx, spec) ... end } }` com
**exatamente** as variantes que `catalogo_contrato.luau` atribui a ele (mesmos nomes, medidas `w×d`, faixa de andares, `tipo`).
Quem coloca usa `Cat.construir(ctx, "casa_pequena", spec)` (`catalogo.luau`).

```lua
-- spec (entrada): cf = CFrame do centro da pegada no piso (Y = topo do pad), frente −Z local, rotação múltipla de 90°;
--   zona ("cidade"|"vila"|"fabrica"|"floresta"|"guarda"|"planicie"), local_? (nome da vila/área), andares (inteiro na faixa),
--   paleta (uma das `paletas` da variante, escolhida por quem coloca; pode vir nil → escolha com spec.rng), rng, w, d.
-- retorno: (modelo, info)
--   modelo: criado com ctx.modeloConstrucao(spec, tipo, variante, w, d, alturaTotal, andares) — já tem Tipo, Variante, Zona,
--           Andares, Interior = true, Local, PrimaryPart = "Pegada" e ModelStreamingMode Atomic. TODAS as peças dentro dele.
--   info: { loot = { {x=,y=,z=,tabela=?}, ... }, frente = {x, z} (ponto local fora da porta, p/ loot externo e para a rua),
--           portaria = {x, z} (centro da porta de entrada, local) }
```
- A pegada `w×d` é **o limite do edifício**: beiral, degraus, varanda, letreiro, cobertura de bombas, calçada de entrada — tudo
  cabe nela (folga de 3 st tolerada). Entrada principal na face −Z.
- `paletas`: lista de 4–6 tabelas de cores (`parede`, `telhado`, `piso`, `porta`, `detalhe`, … as chaves que **você** definir).
  A forma do edifício é a mesma; só a cor muda. Escolha paletas realmente diferentes (e coerentes entre si).
- Variantes de **planta**: se a variante tiver 2–3 plantas internas diferentes, sorteie por `spec.rng` (determinístico).
- `spec.andares` pode ser maior que 1: gere a planta do térreo + andares de cima (laje com furo da escada, escada entre andares,
  corredor/salas). Último andar → telhado.
- Teste: `lune run ferramentas/testar_modulo.luau <modulo>` — falha se solta, fora da pegada, atributo errado, tipo fora de
  `lib.TIPOS`, etc., e mostra peças por construção. Tem de passar **sem falha** para entregar.
- Tabelas de loot padrão por tipo: `lib.TIPOS` (hospital usa a tabela `hospital`; o resto cai em casa/loja/posto/fabrica/guarda).

## 6. Contrato da mobília

`mobilia_tamanhos.luau` lista cada peça (nome → `w,h,d`, `dono`, `var`, `fixo`). Quem implementa (M1: dono `casa`; M2: dono
`comercial`) exporta uma tabela `{ [nome] = function(ctx, pai, cf, op) ... end }` e **respeita a pegada** `w×h×d` (±5 %).
Frente = −Z; origem no centro da pegada, no piso (`fixo = "parede"`: origem na face da parede, a peça sai para −Z;
`fixo = "teto"`: origem no teto, pendura para baixo). `op`: `cor` (principal), `cor2`, `cor3`, `w/h/d` (se `var`),
`variante` (inteiro; sorteie com `op.rng` se faltar), `rng`. Cada função cria **um Model** (`Name = nome`,
atributo `Movel = nome`) filho de `pai` e o devolve. Orçamento ≤ 18 peças por móvel (a maioria ≤ 10); geladeira,
fogão, banheira etc. precisam **parecer** o objeto (puxador, boca do fogão, torneira, tampa do vaso, espelho…).
Cores padrão sensatas quando `op.cor` vier nil (o edifício pode sobrescrever). Peça minúscula: `consulta=false, sombra=false`.
Quem usa: `Mob.colocar(ctx, pai, nome, cfSala, x, yPiso, z, rotY, op)`, `Mob.paraParede(nome, lado, aoLongo, sala, folga)`
(ver `mobilia.luau`). Peça sem implementação vira bloco cinza (aparece em `Mob.faltando`).

## 7. Contrato dos props externos

`props_tamanhos.luau` (nome → `w,h,d`, `var`, `variantes`). `props_urbanos.luau` exporta `{ [nome] = function(ctx, pai, cf, op) end }`
(Model com `Name = nome`, atributo `Prop = nome`, filho de `pai`). Origem no centro da pegada, no chão, frente −Z.
`op`: `variante`, `cor`, `texto` (placas), `w` (se `var`), `rng`. Uso: `Props.colocar(ctx, pai, nome, x, z, rotY, op)` (mundo).
Todos os props externos são para a pasta `Props`. Orçamento: poste ≤ 8 peças; carro ≤ 18; fonte/coreto/playground ≤ 40.

## 8. Tarefas por agente

### M1 `mobilia_casa.luau` e M2 `mobilia_comercial.luau`
Implementar **todas** as peças de `mobilia_tamanhos.luau` com seu `dono`. Testar com um script em
`ferramentas/mapa/_teste_<agente>_mob.luau` (apagar no fim) que põe cada peça em fileira, confere tamanho do bounding box ±5 % e
nenhuma peça solta; imprima a contagem de peças por móvel. Mesma "linguagem visual" dentro de cada módulo (puxadores iguais,
pés de móvel iguais). Variantes: `op.variante` onde fizer sentido (maquina_industrial 1–3: prensa, torno, serra; sofá com/sem
almofada), mas sempre com uma padrão. M2 também: `cela_grade` com grades de verdade (vãos para passar a mão, sem vão que dê para
atravessar), `caixao`, `barraca` (tenda militar de lona: Fabric), `fogueira` (tora + pedras), `saco_areia` (barricada).

### E1–E6 edifícios (ver §5, contrato em `catalogo_contrato.luau`)
Cada variante: **exterior** reconhecível e com personalidade (telhado, varanda, janelas com moldura, porta com batente, rodapé de
cor, calha, chaminé, número da casa, caixa de correio…) + **interior mobiliado** com `Mob` + cômodos coerentes (veja a lista por
variante abaixo) + `info.loot`. Interior escuro, abandonado: algumas cadeiras caídas, caixas, papéis — pouco, bem posto. Cada
variante tem pelo menos 2 plantas internas ou espelhamento por `rng` para não ficarem todas iguais. Janelas só nas paredes
externas (às vezes cegas por tapume: peça de madeira diagonal).
- **E1 casas:** `casa_pequena` (sala+cozinha, quarto, banheiro; varanda), `casa_media` (térreo sala/cozinha/lavabo, andar de cima 2
  quartos + banheiro; escada), `casa_grande` (2 andares, garagem integrada com porta de enrolar aberta e carro dentro, 3 quartos),
  `sobrado` (estreito, 2–3 andares, comércio pequeno ou sala embaixo), `cabana` (madeira, 1 cômodo grande + quartinho, lareira).
- **E2 altos:** `apartamentos` (hall + escada + elevador decorativo; corredor central, 4 apês por andar com sala/cozinha/quarto/
  banheiro enxutos), `escritorio` (lobby com recepção; andares de baias e salas de reunião; cobertura com casa de máquinas),
  `torre` (lobby alto de mármore, andares de escritório aberto com pilares, cobertura com antenas), `hotel` (recepção, corredores
  com quartos numerados, restaurante embaixo), `predio_misto` (loja no térreo, apartamentos em cima, letreiro), `garagem`
  (andares abertos com pilares, rampa/escada, carros parados via `Props.carro`, cabine de pagamento).
- **E3 comércio:** `mercado` (corredores de prateleiras, caixas, açougue, câmara fria, depósito), `loja_conveniencia`, `loja_roupas`
  (araras, provadores), `loja_ferragens`, `farmacia`, `restaurante` (salão com mesas/cabines, cozinha, banheiros), `bar` (balcão,
  sinuca, jukebox; 2º andar opcional), `banco` (guichês, cofre com porta grossa), `posto` (cobertura sobre 4 bombas na frente +
  loja de conveniência + banheiros; placa de preços alta), `lanchonete_estrada` (diner), `motel` (fileira de quartos com porta
  para fora, recepção), `oficina` (baias, elevador, bancada, pneus).
- **E4 serviços:** `hospital` (recepção, corredor de leitos/salas, centro cirúrgico, farmácia; 2–3 andares), `delegacia`
  (recepção, salas, celas, arsenal), `bombeiros` (garagem com caminhão — use `Props.caminhao` vermelho —, dormitório, escritório),
  `escola` (salas de aula, corredor, refeitório, quadra coberta), `prefeitura` (hall com colunas, gabinetes, salão), `biblioteca`.
- **E5 especiais:** `igreja` (como na referência: nave de tijolo claro, torre sineira quadrada, telhado escuro, bancos, altar,
  vitrais; sem placa), `capela` (pequena), `cripta` (mausoléu com caixões), `guarda` (posto florestal 40×30: madeira `WoodPlanks`,
  escritório, alojamento, arsenal; **torre de vigia de 30 st com escada interna e cabine** — como no gerador legado). Mais as
  **áreas**: `M.areas.cemiterio(ctx, ret)` (lápides `Props.lapide`/`cruz_cemiterio`, mausoléus `Cat cripta`, capela, cerca de
  ferro, alamedas de pedra, árvores secas; entrada por onde chega a estrada — ver `Mundo.estradas`) e `M.areas.acampamento(ctx,
  ret)` (Acampamento Halvorsen: cerca de arame, portão, barracas, fogueira, container-escritório, barricadas de saco de areia,
  torre de vigia, refeitório de lona, gerador; mobília de `mobilia_comercial`). `ret` = `ctx.plano.pois[i]`.
- **E6 indústria/rural:** `galpao_maquinas` (70×50, pé-direito 18: máquinas, esteiras, ponte rolante em trilhos, escritório
  suspenso), `galpao_estoque` (estantes industriais, paletes, empilhadeira), `galpao_oficina`, `celeiro` (fardos, baias, jirau),
  `serraria_galpao`. Estruturas exportadas em `M.estruturas.<nome>(ctx, pai, cf, op)`: `chamine`, `silo`, `tanque_elevado`,
  `tanque_combustivel`, `torre_agua`. **Áreas:** `M.areas.fazenda(ctx, ret)` (planície ~600×600: casa de fazenda via
  `Cat.construir("casa_media")`, celeiro, silos, plantações em fileiras de `LeafyGrass`/`Grass` alto como peças planas, cercas,
  trator, fardos), `M.areas.serraria(ctx, ret)`, `M.areas.ferroVelho(ctx, ret)`, `M.areas.patioFabrica(ctx, ret, livres)`
  (chaminés, tanques, silos, containers nos espaços livres do pátio da fábrica; `livres` = lista de retângulos).
  Áreas só colocam peças dentro de `ret` (± 3) e registram obstáculos (`ctx.inserirObstaculo`).

### T1 `relevo.luau` + `src/server/Rios.luau`
- `gerar(ctx)`: substitui `ctx.altura(x,z)`. **Chão = grade de lajes inclinadas** (`Mundo.relevo.celula`, `.espessuraLaje`) cobrindo
  o mapa todo, cada uma um bloco grosso orientado pelo plano ajustado a seus 4 cantos (vizinhas se sobrepõem, sem frestas: borde de
  cada laje cobre ~2 st além). `altura(x,z)` precisa **concordar com a superfície real** das lajes (erro ≤ 0,3 no interior da
  célula): defina a altura por célula/plano e calcule `altura` a partir do mesmo plano. Altura base: ruído determinístico
  (2–3 oitavas, comprimento `comprimentoOnda`, amplitude `amplitude`, tudo derivado de `ctx.rng`/hash, nunca `math.random`),
  multiplicada por uma subida suave a partir de `plano.distPlano` (0 → 0 em áreas planas; 1 além de `margemPlano`) e **menos**
  `plano.profundidadeRio(x,z)` (canal reto com talude de cosseno: já pronto no plano). Áreas planas ficam em Y 0,5 (quem constrói
  nelas põe a laje); onde o rio atravessa uma estrada, o rio vence (a ponte cobre).
  Células inteiramente dentro de um retângulo plano e longe de rios **não** geram laje (economia). Pasta `Chao`. Material:
  `Grass` com manchas de `Ground`/`Mud`/`Rock` nas encostas íngremes e margens (`Sand`/`Mud` no leito e talude do rio), cores
  verdes escuros de floresta boreal (`{58,74,52}`…); variar cor por célula. Orçamento: ≤ 12 000 peças em `Chao`.
  Inclinação máxima ~35° (o jogador sobe tudo, mas não pode virar parede): limite a amplitude ao necessário.
- **Rios:** leito + margens já saem do `altura` (profundidade do plano). Água = **Terrain**: `gerar` cria em `Rios` uma Part
  invisível `Agua` por trecho da linha central suavizada (`plano.rios[i].denso`, CanCollide/CanQuery false, Transparency 1, tamanho =
  largura do canal − 4 × (profundidade − 0,8) × comprimento do trecho + 2, CFrame orientado ao trecho, topo da água em Y = −0,8) e
  atributos `Rio` (nome). `src/server/Rios.luau` (`Rios.iniciar()`): ao iniciar, espera `workspace.Mapa.Rios`, para cada `Agua` faz
  `workspace.Terrain:FillBlock(cframe, size, Enum.Material.Water)` (em lotes com `task.wait()` a cada ~40 para não travar) e
  ajusta `Terrain.WaterColor` (verde-escuro turvo), `WaterTransparency`, `WaterWaveSize/Speed`, `WaterReflectance` para o clima do jogo.
  Sem Terrain em modo Edit: normal. **Não edite `init.server.luau`**: o Opus liga. Não rode o Studio.
- Teste: `lune run ferramentas/gerar_mapa.luau --so relevo --saida build/t1.rbxm`; confira contagem, alturas min/max, nenhuma laje
  fora de ±2000, `altura` ≈ superfície (amostre 2 000 pontos e compare com o topo real calculado das lajes), declividade máxima.

### T2 `estradas.luau` + `pontes.luau`
- `estradas.gerar`: para cada `ctx.plano.estradas[i]`, cada `seg`, cada `plano.trechosLivres(seg)`: laje de asfalto em `Ruas` (topo
  Y 0,5, espessura 2, retângulo do trecho com a largura da estrada) com o `material` da estrada (Asphalt/Pavement/Ground) e
  cor por tipo; **faixa central tracejada** amarela (peças finas `colide=false, consulta=false`), linhas de borda brancas
  desbotadas, acostamento de cascalho/terra (`Ground`/`Pebble`, 3–5 st) onde a estrada sai da cidade, entroncamentos e curvas em
  L preenchidos (os `rets` já se sobrepõem nas quinas), **rachaduras/remendos** (peças planas escuras) e poças esporádicas. A
  rodovia e as avenidas têm 2 faixas por sentido. Registrar `ctx.registrarSuperficie` (já feito por `ctx.laje`). A estrada
  que **entra** na cidade/vila/área termina colada na laje delas (já é assim no plano).
- `pontes.gerar`: (a) **pontes** de `plano.pontes` (`a0..a1` ao longo do `eixo`, `fixo` = coordenada transversal, largura da
  estrada + calçada de 4 st de cada lado): tabuleiro de concreto em `Ruas` (topo 0,5, espessura 2 — o vão livre sobre o leito é
  ≥ 6), pilares robustos no leito a cada ~30 st (em `Props`), guarda-corpo de concreto/aço (`Props`), viga treliçada ou arcos
  simples (peças), cabeceiras, placa com nome do rio. A ponte maior (Rio Grande, vão ≈ 120) tem 2 pilares; (b) **passarelas** de
  `Mundo.pontesPedestres` (madeira/aço, corrimão, 6 de largura, rampas de 1:6 se o leito for fundo; o talude já desce); (c) **viadutos**
  de `plano.viadutos`: deck elevado em Y = `altura` (espessura 2,5) sobre a `sobre`, rampas de asfalto (topo sobe de 0,5 até
  `altura` ao longo de `rampa`; use `ctx.rampa` ou degraus de laje fina ≤ 1 → prefira rampa contínua) nas duas pontas, pilares
  em `Props`, guarda-corpo, faixa central, cabeceiras de concreto; **o chão sob o viaduto continua pisável** (a estrada de baixo
  passa livre, ≥ 10 de vão). A estrada de cima já NÃO gera asfalto no trecho do viaduto (`trechosLivres`). Rampas **pisáveis**:
  inclinação ≤ 12°. Material: concreto/asfalto; cores de rodovia desbotada.
- Contagem: `Ruas` ≤ 8 000 peças. Teste com `--so relevo,estradas,pontes`; confira que não há buraco entre o fim de um trecho livre e o
  início da ponte (sobreposição de 0–1 st é ok), nem laje atravessando leito.

### F1 `floresta.luau`
Floresta boreal do norte da Europa, **mais densa e mais variada** (a legada tinha 2 500 árvores "bola em cima de tronco").
`Mundo.floresta.arvores` é o **orçamento de árvores**; adapte as peças por árvore ao orçamento de `Vegetacao` (≤ 55 000 peças).
- **Pinheiro-silvestre** (`Pinus sylvestris`: tronco alto e fino avermelhado, copa irregular só no alto, em blocos/cilindros
  deslocados), **abeto** (`Picea abies`: cone escalonado de 4–6 degraus de blocos girados 45° entre andares, mais alto e escuro),
  **bétula** (tronco branco com manchas pretas, copa pequena clara/amarelada — poucas), **árvores mortas** e **tocos**,
  **troncos caídos**, **pedras/blocos de granito** (musgo = peça verde fina em cima), **arbustos** de mirtilo/zimbro, **samambaias**
  (peças em leque), **cogumelos** esparsos, **manchas de LeafyGrass/Ground/Snow-free** no chão, **mantos de agulhas** (peças planas
  marrom-escuras ao pé dos pinheiros). Troncos **colidem** (`CanCollide = true`, nome `Tronco`); copas, galhos e folhas **não**
  (`CanCollide = false`, `CanQuery = false`). O checker exige: peça que colide em `Vegetacao` chama-se `Tronco` ou `Mancha`
  (manchas = `LeafyGrass` baixas); pedras e tocos que colidem chamam-se `Tronco` também (atributo `Tipo = "pedra"` etc. opcional).
- Aglomerados (bosques densos, clareiras com pedra e toco, manchas de abeto fechado, bétulas junto a rios e clareiras). Mais denso
  perto de estradas e rios, mais ralo no alto das colinas. Distância mínima `Mundo.floresta.distanciaMinima` entre troncos (pode
  haver alguns pares mais perto em aglomerados).
- **Posição:** Y = `ctx.altura(x,z)` (afunde a base do tronco 0,6). Nunca em `plano.emAreaConstruida(x,z,14)`, nunca em rio
  (`plano.emRio(x,z,10)`), nem sobre a laje de nenhuma construção (`ctx.ocupado(x,z,6)`), nem fora de ±(metade − 30). Registre cada
  tronco com `ctx.inserirObstaculo`. Inclinação do terreno > 30° → sem árvore.
- Variação: altura, inclinação leve do tronco (≤ 4°), rotação, cor (`ctx.variar`), pares de tamanho. Silhueta é o que importa à
  distância (neblina densa): copas escuras `{34,58,40}` / `{42,66,46}`, troncos `{96,62,44}` / `{70,56,48}`.
- Manchas de `LeafyGrass` (som +5 dB) continuam como no legado: `Mundo.floresta.gramaAlta`, tamanho 50–72, só em chão plano o
  bastante (use a mesma função do legado adaptada ao relevo: coloque sobre a superfície, inclinada como a laje do relevo — ou
  simplesmente mais fina e do tamanho da célula).
- Teste: `--so relevo,floresta` (e sem relevo): contagem por espécie, tempo, nenhuma árvore em rio/estrada, nenhuma pedra enfiada em construção.

### D1 `props_urbanos.luau` + `decoracao.luau`
- `props_urbanos.luau`: todos os props de `props_tamanhos.luau` (ver §7), com **carros de 5 modelos** bem reconhecíveis em silhueta
  (sedan, hatch, picape, van, táxi) e cores desbotadas, rodas de cilindro, vidros escuros, para-choques; `carro_destruido` (queimado:
  preto/ferrugem, sem vidros; sem portas; de lado); caminhão, ônibus (janelas, porta), trator; postes de luz (apagados), postes de
  madeira com fios (peças finas esticadas até outro poste — só se `op.alvo` vier), semáforos, placas (SurfaceGui com `op.texto`;
  nomes de ruas), hidrante, caçamba, banco de praça, ponto de ônibus, fonte seca com estátua, coreto, playground, árvore de rua
  (bordo — "Maple Rise" — copa de 3–5 blocos PS1), cercas, guard-rail, barreiras, containers de carga (cores variadas).
- `decoracao.gerar(ctx)` (roda por último): coloca props **sem** passar por cima de construção/árvore/rio/rua de carro:
  1. **Cidade:** postes de luz nos cantos de cada quarteirão e a cada ~50 st nas calçadas, hidrantes, lixeiras, bancos, bancas,
     pontos de ônibus, semáforos nos cruzamentos principais, **carros abandonados** nas ruas (poucos por cruzamento; alguns batidos
     em poste, alguns de lado, alguns bloqueando a pista), caçambas em becos, entulho, barricadas de concreto e cones em alguns
     cruzamentos, árvores de rua em canteiros, placas de rua em cada esquina. Menos coisas no centro de prédios altos (calçada limpa
     e larga) e mais no residencial.
  2. **Estradas** (`plano.estradas`, exceto o interior da cidade): postes de madeira a cada ~70 st, guard-rails em curvas/nas
     cabeceiras de pontes (não nas pontes: a T2 faz), placas de velocidade/direção/aviso, marcos quilométricos, carros e caminhões
     abandonados (batidos no acostamento), barreiras e cones em obra, containers, cercas de arame onde corta pasto, caixas de correio
     em estradinhas de vila, caminhonetes na vala. Densidade variável por estrada (rodovia mais).
  3. **Vilas** (`plano.vilas`): cercas, caixas de correio, carros nas entradas, bancos, poste a cada esquina.
  Use `ctx.rng("decoracao")`, `ctx.ocupado` e registre obstáculos grandes. Props em `Props`. Orçamento: `Props` ≤ 20 000 peças no total
  (inclui pontes/viadutos da T2 e prédios/áreas): D1 ≤ 14 000.
- Verifique: nenhum prop sobreposto a outro (use uma grade de ocupação própria além de `ctx.ocupado`), nenhum sobre rua onde bloqueie
  um cruzamento inteiro (deixe sempre uma pista livre de 8 st).

### L1 `cidade.luau`
- **Estrutura** (adapte o código de `_legado_gerar_mapa_v1.luau`): laje de asfalto da cidade (`plano.cidade`), faixas de rua
  (tracejadas), calçadas por quarteirão, lotes. Cidade agora **900** (6×6 quarteirões de 120 + ruas de 30). Lembre: na borda da cidade
  as ruas continuam em avenidas (T2); deixe a laje e as faixas nas bordas coerentes com os eixos das avenidas (`Mundo.avenida`).
- **Regiões** (`Mundo.cidade.regioes`, distância de Chebyshev ao centro): `centro` (≤ 190) só prédios altos (torres, escritórios,
  hotéis, apartamentos, garagens, predio_misto) **bem juntos** (recuo 6 da calçada, vãos de 10 entre prédios, vielas); `comercial`
  (≤ 330) prédios médios + comércio + serviços (mercado, hospital, delegacia, banco, restaurantes…) — **um** hospital, **uma**
  delegacia, **uma** prefeitura (no centro/comercial), **uma** biblioteca, 1–2 bombeiros, 1–2 mercados, 1–2 postos, 1 escola;
  `residencial` (além): casas, sobrados, apartamentos baixos, comércio de esquina, 1–2 igrejas, escola. Região vem do centro do
  quarteirão. Pesos em `catalogo_contrato.luau`. Parques/praças (em ~3 quarteirões inteiros, 1 no comercial/centro e 2 no
  residencial) com fonte, coreto, playground, bancos, canteiros, árvores de rua, alamedas de calçada; terrenos baldios residuais
  com manchas de LeafyGrass (`Mundo.cidade.gramaAltaManchas`).
- **Colocação:** `Cat.construir(ctx, variante, spec)` (use `ctx.registrarConstrucao(spec, modelo, info)` depois). Cada quarteirão: grade
  de lotes por região; frente do edifício **para a rua mais próxima**; recuo da calçada ≥ 4; sem sobreposição (`ctx.retanguloOcupado`
  com margem). Loot exterior só se `info.loot` vier vazio (o registro já faz). Atributos `Zona = "cidade"`. A variante sai da
  função de região com pesos; **nunca** repita um mesmo edifício raro (hospital…) além do número acima.
- O mapa não pode ter prédio na rua, nem prédio sobre o outro, nem porta de entrada encostada em outra parede (≥ 6 st livres à frente).
  Beirais não podem passar de 1,5 sobre a calçada.
- Spawns/vilas **não** são deste módulo. Orçamento de `Construcoes` da cidade: ≤ 50 000 peças (prédios altos dominam: ajuste a
  proporção `centro` se estourar). Teste: `--so cidade` (placeholders onde faltar edifício) e depois com os reais.

### L2 `areas.luau`
- **Pads planos** (`Chao`, topo 0,5, espessura 2, `ctx.laje`) para vilas, fábrica, planície, posto da guarda e cada POI de
  `Mundo.pois` (material/cor por tipo: Ground, Pavement, DiamondPlate…); **vilas:** ruas de terra/asfalto em cruz (24 de largura)
  como no legado, **12 casas** por vila (variantes `casa_pequena/media/grande/sobrado/cabana`, frente para a rua mais próxima), 1 **posto**
  (variante `posto`), 1 **igreja** (`igreja`) e 1 `mercado` pequeno quando couber, canteiros/cercas/caixas de correio leves (o
  grosso é do D1 depois), **6 spawns** em chão livre longe de construção (≥ 14) e entre si (≥ 20): `ctx.spawnsPlanejados`
  (`{x, z, vila}`). **Fábrica:** 4 galpões (`galpao_maquinas` ×2, `galpao_estoque`, `galpao_oficina`) em 2×2 em volta de um
  corredor central, pátio com `E6.areas.patioFabrica(ctx, ret, livres)` se existir. **Planície:** `E6.areas.fazenda(ctx, ret)`.
  **Posto da guarda:** `Cat.construir("guarda", ...)` no centro do pad (`Mundo.guardaFlorestal`; zona `guarda`). **POIs** por `tipo`:
  `cemiterio` → `E5.areas.cemiterio`; `acampamento` → `E5.areas.acampamento`; `serraria` → `E6.areas.serraria`; `ferroVelho` →
  `E6.areas.ferroVelho`; `parada` (parada de rodovia) → `Cat posto` + `lanchonete_estrada` + `motel` + estacionamento, orientados
  para a estrada; `igrejaIsolada` → `igreja` + estacionamento de cascalho + cemitério pequeno (≤ 20 lápides `Props.lapide`). Se
  a função da área não existir ainda (módulo de outro agente), faça só o pad e uma nota em `ctx.avisos`.
- Construções recebem `Zona` coerente com `plano.zonaEm` (`vila`, `fabrica`, `guarda`; POIs → `floresta`). `Local` = nome da vila /
  "Fabrica" / "PostoGuarda" / nome do POI (o jogo usa para texto).
- Registre tudo com `ctx.registrarConstrucao`. Spawn longe de construção ≥ 14 e **sem** props grandes.
- Orçamento: vilas 3×12×350 + o resto ≤ 30 000 peças. Teste: `--so areas` (+ `relevo` para ver o chão).

## 9. Referências visuais (imagens) — o estilo desejado

Imagens (leia com a ferramenta Read; são do usuário, de um protótipo anterior com texturas): `C:\Users\cerfr\AppData\Local\Temp\claude\
d--programacao-projetos-jogos-roblox-uma-cidade-silenciosa\d0ad3f29-2923-4d14-8897-ee52f67a5d66\images\1.png … 5.png`
1. Casa de 2 andares verde-acinzentada, varanda com colunas brancas, porta, janelas com moldura branca, telhado escuro, gramado alto, noite.
2. Igreja de tijolo claro, torre quadrada com janela alta, telhado preto (sem placa: o texto da referência foi removido a pedido).
3. Quarto: piso de tábua escura, cama de madeira com colchão azul-acinzentado, criado-mudo com abajur, parede verde-acinzentada.
4. Banheiro: banheira, pia de pedestal com espelho, vaso — tudo branco e simples, piso de tábua, parede verde rugosa.
5. Cozinha: geladeira branca com ímãs/bilhetes e puxador, bancada de madeira com tampo de mármore, panelas/pratos em cima, janelas escuras.
Reproduza essa **atmosfera e proporção** só com cor + Material (sem texturas).

## 10. Orçamento de peças (total ≤ `Mundo.limitePecas` = 150 000)

| Pasta | Limite |
|---|---|
| Chao | 12 000 |
| Ruas | 8 000 |
| Construcoes | 80 000 (cidade ≤ 50 000, áreas ≤ 30 000) |
| Vegetacao | 55 000 |
| Props | 20 000 |
| Rios | 800 |
| Pontos / Zonas / Bordas | ~3 000 |

(A soma passa de 150 000 de propósito: nem tudo chega ao teto. Quem estourar o seu teto reduz.)

## 11. Entrega de cada agente

Responda no fim com um relatório curto (≤ 25 linhas): arquivos criados; funções/variantes entregues; contagem de peças medida;
o que testou e o resultado; **o que ficou faltando ou duvidoso** (para `docs/pendencias-integracao.md`); qualquer função de
`lib`/`plano` que você precisou e não achou. Não deixe arquivos temporários (`_teste_*`, `build/<seu>.rbxm` pode ficar).
