# Destruição universal: materiais, dano, escurecer, quebrar

Pedido do usuário (2026-11-04): um sistema **único** em que qualquer coisa que machuca uma construção (tiro, golpe de arma
corpo a corpo, garra de monstro, carro, no futuro marreta e explosão) dá dano ao **material** da peça; a peça **escurece**
conforme leva dano e depois **quebra**, abrindo um buraco permanente (até reiniciar o servidor). O Rastejador deixa de ter
lógica própria de buraco e passa a usar este sistema. Vale para parede, janela/vidro, grade, laje/teto, algumas cercas e
alguns grupos (bomba e tanque de combustível).

Regra do fluxo (igual ao `rastejador.md`): decisão não prevista aqui → **não decidir**: anotar em `docs/pendencias-integracao.md`,
seção "Destruição", e continuar no resto. Nada de commit. Nunca rodar `gerar_mapa.luau --final`. O mapa **não muda**: tudo é
classificado em tempo de execução pelo nome, pelo `Material` e pelo `Size` da peça.

## 0. Fatos do mapa e do código (conferidos em 2026-11-04)

- `Mapa.Construcoes/<tipo>_<variante>_<N>` (Model) com peças soltas: `Parede`, `Fachada`, `Divisoria`, `Banho`, `Provador`,
  `Cofre`, `Piso`, `Laje`, `Forro`, `Teto`, `TetoCasa`, `Telhado`, `Ladrilho`, `Vidro`, `FolhaVidro`, `GradeJanela`, `GradeSacada`,
  `GradeEnrolar`, `PortaEnrolar`, `PortaoCorrer`, `Grade`, `GradePortao`; móveis são Model filho com atributo `Movel`.
  Não existe peça "Janela": janela = `Vidro` + `Moldura` + `Caixilho` (as duas últimas `CanCollide=false`) dentro de buraco da `Parede`.
- **`Vidro` é sólido e consultável** (`CanCollide` e `CanQuery` padrão = true). Logo o tiro já o acerta e ele já bloqueia
  o caminho. (A nota de `pendencias-integracao.md` que dizia "janela CanCollide=false" está errada para o vidro; só a `Folha`
  da porta e o `Tapume` têm os dois falsos.) Quebrar o vidro abre a janela de verdade.
- Peças com `CanQuery=false` (Folha, Tapume, Pegada, detalhes < 0,6) **não são acertáveis**; ficam fora do sistema.
- Materiais por peça vêm da paleta do prédio (`Concrete`, `Brick`, `Limestone`, `Sandstone`, `Wood`, `WoodPlanks`, `Glass`,
  `Metal`, `CorrodedMetal`, `DiamondPlate`, `Slate`, `Granite`, `Basalt`, `Marble`...). Comércio sai sempre `Concrete`.
- Sem União nem MeshPart: tudo é `Part` retangular. Recortar um buraco = dividir o bloco em até 4 blocos.
- ~155 mil peças no mapa (68 mil em Construcoes). Nada de `Script` por peça, nada de atributo novo por peça no build:
  estado **só em tabela fraca no servidor**, criado na primeira pancada.
- O ruído conta como parede toda peça de `Construcoes` com `CanQuery=true` (`Monstros.luau`, raycast até 3 paredes, 10 dB cada):
  peça que some deixa de atenuar sozinha. Não há cache de navmesh: o `PathfindingService` lê a geometria a cada `ComputeAsync`.
- `Armas.luau`: raycast de tiro e golpe já acerta `Construcoes`, mas `acertar` não tem ramo para construção.
- Carro (`Veiculos.luau`): laço de 10 Hz (`PASSO = 0.1`) só para carros com motorista; detecta batida por variação de velocidade
  (`deltaV ≥ 14`) e **não sabe no que bateu**; carroceria zerada hoje não muda nada além do número. Massas 1235–2200, velMax 45–78.
- `Loot` guarda referência aos móveis com compartimento; destruir o container apaga o conteúdo sem drop.
  Por isso **móveis não entram na v1** (ver §3).
- `client/Filtro/Aberracao.luau` clona peças do mapa por célula sem ouvir remoção: peça destruída continua no clone até a célula sair
  do raio (anotar em pendências; dono é o filtro, não este sistema).

## 1. Visão geral

```
 Fonte de dano ──► Destruicao.dano(peca, quantidade, info) ──► Regras (puras)
 (tiro, golpe,        │ 1. peça é destrutível? (papel, CanQuery, cache)         classe do material
  garra, carro,       │ 2. dano efetivo = quantidade × mult[tipo][classe]       vida máxima
  explosão)           │ 3. vida -= efetivo; estágio de escurecer mudou? pinta   estágio visual
                      │ 4. vida ≤ 0 → quebrar: recortar buraco, destruir, efeitos, avisar ouvintes
                      └► aoQuebrar(evento): Monstros invalida caminhos, quem quiser reage (futuro: explosão da bomba)
```

Princípios: **o servidor decide tudo** (cliente só vê a peça mudar de cor e sumir). Números só em `Config`. Regras puras testadas
em Lune. Custo: nenhuma varredura periódica; só cálculo no momento do dano. Ninguém acessa o estado de outra peça por fora: sempre
por `Destruicao`.

## 2. Arquivos (dono único por arquivo)

| Arquivo | Conteúdo |
|---|---|
| `src/shared/Config/Materiais.luau` | tabela **material → classe + vida por stud**, classes (efeito visual, sons, ação de ruído), matriz **tipo de dano × classe** |
| `src/shared/Config/Destruicao.luau` | papéis por nome de peça, grupos (bomba/tanque), props destrutíveis, estágios de escurecer, tamanho de buraco por tipo, limites, números do carro |
| `src/shared/Regras/Destruicao.luau` | **regras puras** (§5). Testes em `tests/Destruicao.spec.luau` |
| `src/server/Destruicao.luau` | serviço: classificar, aplicar dano, pintar, recortar, efeitos, `aoQuebrar`, varredura do carro, explosão |
| `src/shared/Config/Armas.luau` | cada arma ganha `tipoDano` (`faca`/`machado` = `corte`, `peDeCabra` = `alavanca`, `pistola` = `bala`) |
| `src/server/Armas.luau` | **só** um ramo novo em `acertar` e em `ehAlvo` (§6.1) |
| `src/server/Veiculos.luau` | **só** os ganchos do §6.3 (varredura no laço, impacto na batida, `danoCarroceria`) |
| `src/server/MonstroArrombar.luau` | migra para `Destruicao.dano` (§6.2), **depois** que o agente do Rastejador terminar (ver §9) |
| `src/server/Monstros.luau` | **só** `Monstros.invalidarCaminhos(centro, raio)` (§6.4) |
| `src/server/init.server.luau` | `Destruicao` entra em `ORDEM`, antes de `Monstros` |
| `src/server/Teste.luau` (registros) | comandos de teste (§8) |
| `docs/calculos.md` §7, `docs/pendencias-integracao.md` "Destruição", `docs/rastejador.md` | números e pendências |

Rede: **nenhum RemoteEvent novo.** Cor e remoção replicam sozinhas; som por `Sons.tocar`; poeira por emissor temporário (como a de hoje).

## 3. O que é destrutível

Uma instância `inst` é destrutível se **todas** valerem:
1. `BasePart`, `CanQuery == true` (senão ninguém a acerta), não `Indestrutivel` (atributo) e descendente de `Mapa.Construcoes`
   ou de `Mapa.Props`;
2. **Construcoes**: o `Name` casa com um prefixo de `Config/Destruicao.nomes` cujo papel tem `destrutivel = true` (lista branca;
   nome desconhecido = indestrutível; o comando `destruicao_nomes` mostra o que ficou de fora);
3. **Props**: o Model-pai tem atributo `Prop` listado em `Config/Destruicao.props` (muro_baixo, cerca_madeira, cerca_arame,
   guard_rail);
4. **Grupo**: se algum ancestral Model tem `Movel` ou `Estrutura` listado em `Config/Destruicao.grupos`
   (`bomba_combustivel`, `tanque_combustivel`), a vida é **do grupo** (todas as peças dividem a mesma vida e o mesmo escurecer,
   e quebrar destrói o Model inteiro); o grupo tem `evento = "combustivel"` para o `aoQuebrar`.

Papéis iniciais (PROVISÓRIO; ordem = primeira correspondência):

| Papel | Prefixos de nome | Destrutível v1 |
|---|---|---|
| parede | `Parede`, `Fachada`, `Divisoria`, `Banho`, `Provador` | sim |
| vidro | `Vidro`, `FolhaVidro` | sim |
| grade | `Grade`, `PortaEnrolar`, `PortaoCorrer`, `PortaoFaixa` | sim |
| laje | `Laje`, `Forro`, `Teto`, `TetoCasa` | sim |
| telhado | `Telhado` | sim |
| piso | `Piso`, `Ladrilho` | **não** (chão do térreo; furo no piso é decisão pendente) |
| cofre | `Cofre` | **não** (pendente) |
| (móveis) | Model com `Movel` fora da lista de grupos | **não** (evita apagar loot; pendente) |

Sem colapso estrutural: peças acima de um buraco ficam no ar (`Anchored`). Sem animação de queda de pedaços.

## 4. Material, dano e vida (`Config/Materiais.luau`)

### 4.1 Material → classe e vida por stud de espessura
Vida da peça = `vidaPorStud × clamp(espessura, 0.5, 3)`, onde `espessura = min(Size.X, Size.Y, Size.Z)`. **Exceção:** classe `vidro` usa
vida **fixa** (não depende da espessura). Material fora da tabela usa `padrao`.

| Material (`Enum.Material.Name`) | Classe | Vida por stud | Observação |
|---|---|---|---|
| `Glass` | vidro | 10 (fixa) | 1 golpe qualquer |
| `Fabric`, `SmoothPlastic`, `Plastic` | leve | 20 / 30 / 30 | |
| `Wood`, `WoodPlanks` | madeira | 150 | |
| `Sandstone` | alvenaria | 240 | |
| `Limestone` | alvenaria | 300 | |
| `Slate` | alvenaria | 300 | |
| `Brick` | alvenaria | 360 | |
| `Marble` | alvenaria | 400 | |
| `Concrete` | alvenaria | 480 | |
| `Granite` | alvenaria | 520 | |
| `Basalt` | alvenaria | 560 | |
| `CorrodedMetal` | metal | 360 | |
| `Metal` | metal | 600 | grade e chapa são finas (clamp de 0,5) |
| `DiamondPlate` | metal | 900 | |
| (outros) | alvenaria | 300 | `padrao` |

Grupos usam `vida` própria do `Config/Destruicao.grupos` (bomba 150, tanque 400).

### 4.2 Matriz de multiplicadores: dano efetivo = dano × mult[tipo][classe]
| tipo \ classe | vidro | madeira | alvenaria | metal | leve |
|---|---|---|---|---|---|
| `bala` | 6 | 0,5 | 0,25 | 0,2 | 2 |
| `corte` (faca, machado) | 3 | 1,5 | 0,15 | 0,1 | 3 |
| `alavanca` (pé de cabra) | 3 | 1,2 | 0,5 | 0,4 | 2 |
| `marreta` (futuro) | 4 | 1,3 | 1,6 | 0,8 | 3 |
| `garra` (monstro) | 3 | 1 | 0,4 | 0,15 | 2 |
| `soco` (futuro, mãos vazias) | 1,5 | 0,2 | 0,05 | 0,02 | 1 |
| `impacto` (carro) | 3 | 1 | 1 | 1 | 1 |
| `explosao` | 4 | 1,5 | 1,2 | 0,8 | 3 |

Ideia: machado é de madeira, pé de cabra serve em alvenaria fraca, **marreta é a ferramenta de alvenaria**, bala só vence vidro e
madeira. Tipo de dano novo = nova linha na matriz (sem mudar código).

### 4.3 Golpes para abrir 1 stud de espessura (conferência dos números)
Dano base: pistola 25, faca 18, pé de cabra 28, machado 40, marreta 55 (futura), garra 20.

| Material (1 stud) | pistola | faca | pé de cabra | machado | marreta | garra |
|---|---|---|---|---|---|---|
| vidro (10) | 1 | 1 | 1 | 1 | 1 | 1 |
| madeira (150) | 12 | 6 | 5 | 3 | 3 | 8 |
| tijolo (360) | 58 | 134 | 26 | 60 | 5 | 45 |
| concreto (480) | 77 | 178 | 35 | 80 | 6 | 60 |
| metal (600, ou 300 com 0,5) | 120 (60) | 334 (167) | 54 (27) | 150 (75) | 14 (7) | 200 (100) |

Consequência esperada: o Rastejador acaba arrombando só madeira e vidro; machado em parede de tijolo é perda de tempo e o pé de
cabra é 2x melhor; marreta resolve alvenaria. Afinar no playtest.

### 4.4 Escurecer (e rachar)
`fracDano = 1 - vida/vidaMax`. Estágio = quantos limiares de `Config/Destruicao.estagios` (`{0.2, 0.4, 0.6, 0.8}`) já passaram
(0 a 4). **Só repinta quando o estágio muda** (no máximo 4 replicações por peça).
- Classes com `efeito = "escurecer"`: `Color = original:Lerp(escurecerAlvo, classe.escurece × estagio / #estagios)`;
  `classe.escurece`: madeira 0,6, alvenaria 0,55, metal 0,5, leve 0,5; `escurecerAlvo = Color3.fromRGB(18, 16, 15)`.
- Classe `vidro` (`efeito = "rachar"`): a cada estágio `Transparency` cai 0,1 e a cor clareia 8% (vidro fica leitoso/riscado). Como o vidro
  tem 10 de vida e quase todo dano o quebra, só aparece com `soco`, bala fraca ou dano acumulado.
- A cor original fica em atributo `CorOriginal` (Color3) **só** na primeira repintura; retalhos clonados herdam e continuam
  coerentes.
- Retalhos herdam o estágio da peça quebrada (`retalhos.danoHerdado = 0.5`: começam com 50% de dano).

## 5. Regras puras (`Regras/Destruicao.luau`, `--!strict`, sem Instance)

Todas recebem `cfgMat = Config/Materiais` e/ou `cfg = Config/Destruicao`. Vetores como tabelas `{x, y, z}`.

- `classeDe(materialNome, cfgMat) -> { classe: string, vidaPorStud: number, fixa: boolean }`
- `vidaMaxima(materialNome, espessura, cfgMat) -> number` (§4.1)
- `danoEfetivo(quantidade, tipo, classe, cfgMat) -> number` (0 se o tipo ou a classe não existe)
- `golpesPara(vidaRestante, quantidade, tipo, classe, cfgMat) -> number` (`math.huge` se o efetivo é 0)
- `estagio(fracDano, limiares) -> integer`
- `fatorEscurecer(classe, estagio, cfgMat, cfg) -> number` (0..1 para o `Lerp`) e `transparenciaRachada(base, estagio, cfg) -> number`
- `papelDe(nome, cfg) -> { papel: string, destrutivel: boolean }?` (primeiro prefixo que casa; nil se nenhum)
- `tamanhoBuraco(tipo, dimsPeca, larguraFonte?, cfg) -> { largura, altura }` (§7)
- `recortar(tamanho, eixoFino, pontoLocal, buraco, ancoraChao, minimo) -> { Retalho }`
  - `tamanho = {x,y,z}` da peça; `eixoFino` = índice (1,2,3) da menor dimensão; `pontoLocal` = ponto do golpe no referencial da peça;
  - **vão atravessa a espessura inteira**; parede vertical (`eixoFino` ≠ Y): vão **do chão da peça** para cima, centrado no golpe,
    limitado às bordas; laje (`eixoFino` = Y): vão centrado no golpe nos dois eixos horizontais;
  - devolve até 4 retalhos `{ centro = {x,y,z}, tamanho = {x,y,z} }` (esquerda, direita, topo, e — só em laje/janela alta — fundo), sem
    sobreposição; retalho com qualquer dimensão < `minimo` é absorvido pelo vão (sem fresta) ou descartado se for lasca;
  - **teste obrigatório:** volume dos retalhos + volume do vão = volume da peça; vão sempre dentro da peça; golpe na borda.
- `inteiraSeMenor(dims, cfg) -> boolean`: peça cuja **maior** dimensão ≤ `cfg.pecaInteira` (padrão 2,5) é destruída inteira, sem vão
  (vidro de janela, grades, tábuas de cerca).
- `danoImpactoCarro(massa, velocidade, cfg) -> number` = `0.5 · massa · velocidade² · cfg.carro.escalaEnergia`
- `atravessa(energia, vidaRestanteEfetiva) -> boolean`
- `custoCarroceria(vidaGasta, cfg) -> number` = `vidaGasta · cfg.carro.recuoCarroceria`
- `danoAtropelo(velocidade, cfg) -> number` = `max(0, velocidade − cfg.carro.atropelo.velMin) · cfg.carro.atropelo.danoPorVel`
- `quedaExplosao(distancia, raio) -> number` (1 no centro → 0 na borda, linear)

Casos de teste obrigatórios: classe de cada material da tabela; vidro com espessura qualquer = 10; clamp de espessura; matriz
(machado em madeira = 60, em tijolo = 6, pistola em vidro = 150); `golpesPara` batendo com a tabela §4.3; estágios nos limiares
(0,19→0; 0,2→1; 0,99→4); `papelDe` para `Parede`, `ParedeLonga`, `GradeJanela`, `Piso`, `Cofre`, nome desconhecido; `recortar` com
volume conservado em parede (golpe no meio, na borda esquerda, na direita, parede mais baixa que o vão) e em laje; `inteiraSeMenor`;
impacto do carro (sedan 1520 a 58 st/s ≈ 380 com a escala padrão); atropelo abaixo da velocidade mínima = 0.

## 6. Servidor (`src/server/Destruicao.luau`)

Padrão de serviço do projeto (`iniciar()` sem bloquear, `require` de outro serviço só depois do `iniciar`, `pcall` para o que
pode faltar, `warn` com limite de taxa).

### 6.0 API pública
```lua
type TipoDano = "bala"|"corte"|"alavanca"|"marreta"|"garra"|"soco"|"impacto"|"explosao"
type Info = {
  tipo: TipoDano,
  ponto: Vector3?,       -- ponto do acerto (padrão: o centro da peça)
  normal: Vector3?,
  fonte: any?,           -- Player, Model do monstro, Model do carro...
  largura: number?,      -- largura mínima do vão pedido pela fonte (garra: corpo do monstro × folga; carro: largura + 1)
  altura: number?,
  ruido: string?,        -- ação de Config/Som.acoes a emitir a CADA golpe (o Rastejador usa "paredeQuebrando"); nil = nenhum
}
type Resultado = { quebrou: boolean, fracao: number, efetivo: number, classe: string, vidaRestante: number }
function Destruicao.ehDestrutivel(inst: Instance): boolean
function Destruicao.dano(inst: Instance, quantidade: number, info: Info): Resultado?   -- nil se não destrutível
function Destruicao.golpesPara(inst: Instance, quantidade: number, tipo: TipoDano): number   -- math.huge se não destrutível
function Destruicao.vidaRestante(inst: Instance): number?
function Destruicao.aoQuebrar(fn: (Evento) -> ()): () -> ()   -- devolve o desconectar
  -- Evento = { centro: Vector3, classe: string, material: string, papel: string, tipo: TipoDano, fonte: any?, grupo: string? }
function Destruicao.explosao(centro: Vector3, raio: number, dano: number, fonte: any?)   -- tipo "explosao", queda linear, só peças destrutíveis
function Destruicao.varrerCarro(chassi: BasePart, velocidade: Vector3, massa: number, fonte: any?): { custoCarroceria: number, atropelados: number }
function Destruicao.impactoCarro(chassi: BasePart, velocidadeAntes: Vector3, velocidadeDepois: Vector3, massa: number, fonte: any?): number -- custoCarroceria
function Destruicao.furos(): number
function Destruicao.estatisticas(): { furos: number, pecasExtras: number, danificadas: number }
```

### 6.1 `dano` passo a passo
1. `estadoDe(inst)`: tabela fraca `estado[BasePart|Model] = { vida, vidaMax, classe, estagio, papel, grupo? }`, criada na 1ª pancada.
   Classificação cacheada em outra tabela fraca (`ehDestrutivel`), inclusive o `false`.
2. `efetivo = Regras.danoEfetivo(quantidade, info.tipo, classe)`; `efetivo <= 0` → só toca o som de impacto (limitado) e sai.
3. `vida -= efetivo`; `Sons.tocar(classe.somImpacto, ponto)` no máximo a cada `cfg.somImpactoIntervalo` s por peça;
   se `info.ruido`, `Ruido.emitirAcao(info.ruido, ponto, fonte)` (a quebra tem ruído próprio, §6.1.5).
4. Se o estágio mudou: **pintar** (todas as peças do grupo, se for grupo). Só `Color`/`Transparency` e o atributo `CorOriginal`.
5. `vida <= 0` → `quebrar`: som da classe (`somQuebra`), ruído `classe.acaoQuebra` na posição (ação já existente em `Config/Som.acoes`:
   `vidro` 75 dB para vidro, `paredeQuebrando` 65 dB para o resto), poeira (um emissor, 0,5 s, cor da classe),
   dispara `aoQuebrar` (cada ouvinte em `pcall`).
   - **Grupo:** destrói o Model inteiro, sem recorte; evento com `grupo = "<nome>"`.
   - **Peça pequena** (`inteiraSeMenor`): `Destroy()` sem retalhos.
   - **Senão:** recorte via `Regras.recortar`; cada retalho é `Clone()` da peça (mesmas propriedades), `Anchored = true`, mesmo pai,
     estado inicial com `danoHerdado`; a original é destruída.
6. Limites (`cfg.limites`): `buracos` (padrão 300) e `pecasExtras` (padrão 6000 clones criados). Estourou: não corta mais; a peça só
   escurece até o estágio máximo e `warn` (uma vez). Não deixa o servidor crescer sem teto.
7. Nunca lança erro para o chamador: tudo dentro de `pcall`; falha vira `warn` limitado.

### 6.2 Pontos de integração (cada um é uma mudança pequena e comentada)

**Armas** (`src/server/Armas.luau`):
- `ehAlvo(resultado)`: também verdadeiro se `Destruicao.ehDestrutivel(resultado.Instance)` (para o golpe corpo a corpo preferir a
  parede ao Spherecast vazio). Veículo, jogador e monstro continuam antes.
- `acertar(...)`: depois dos ramos de veículo/jogador/monstro, se destrutível:
  `Destruicao.dano(resultado.Instance, cfg.dano, { tipo = cfg.tipoDano, ponto = resultado.Position, normal = resultado.Normal, fonte = atacante })`.
  **Não** tocar `cfg.somAcerto` nem disparar `Acerto` para construção (o som é da classe do material).
- `Config/Armas.luau`: `tipoDano` por arma. Arma nova (marreta) = entrada em `Config/Armas`, item em `Config/Itens` e `tipoDano = "marreta"`.
  Armas sem `tipoDano` não machucam construção (log único).

**MonstroArrombar** (`src/server/MonstroArrombar.luau`) migra **quando o agente do Rastejador terminar** (§9):
- `bater`: troca o corpo do `task.delay` por `Destruicao.dano(peca, Cfg.arrombar.dano, { tipo = "garra", ponto = p.ponto, normal = p.normal, fonte = d.modelo, largura = d.hrp.Size.X * Cfg.arrombar.folgaLargura, altura = Cfg.arrombar.alturaBuraco, ruido = "paredeQuebrando" })`;
  se `resultado.quebrou`: zera `alvoCaminho`, `waypoints`, `cap.parede` e agenda o recálculo como hoje.
- Some: `abrirBuraco`, `poeira`, `furos`, atributo `VidaParede` (e `Furado`, `Regras.buraco`/`partesDaParede` ficam só se algum teste ainda
  os usar; senão removidos com seus testes).
- `candidato`: antes de aceitar uma parede, `Destruicao.golpesPara(peca, Cfg.arrombar.dano, "garra") <= Cfg.arrombar.golpesMax` (novo, 25):
  monstro não perde minuto em concreto. Parede que não passa entra em `paredesRuins` por 30 s como hoje.
- `arrombavel(p)` continua pedindo `Parede*` fina e alta (`Regras.paredeArrombavel`) **e** `Destruicao.ehDestrutivel(p)`. O Rastejador
  quebrar vidro de janela é decisão pendente (`Cfg.arrombar.quebraVidro = false` por enquanto).

**Veículos** (`src/server/Veiculos.luau`), só ganchos:
- `Veiculos.danoCarroceria(modelo, dano, fonte)`: aplica `Regra.acertar(d.estado, "Carroceria", dano, ...)` + `aplicarEstado` + `efeitos`;
  se a carroceria chegou a 0 e o motor > 0, zera o motor e chama `desligar` (**"quebrou o carro" = motor morto e desligado**; incêndio/explosão do
  carro é decisão pendente).
- No laço `atualizarOcupado` (10 Hz, já só para carros com motorista), com `velocidade >= cfg.carro.velMin`:
  `local r = Destruicao.varrerCarro(d.chassi, v, d.chassi.AssemblyMass, d.motorista)` dentro de `pcall`, e `danoCarroceria(d.modelo, r.custoCarroceria, nil)` se > 0.
- Em `processarBatida` (já acontece quando `deltaV ≥ 14`): `Destruicao.impactoCarro(d.chassi, anterior, v, massa, d.motorista)` e
  `danoCarroceria` com o custo devolvido. **Não** dobrar o dano da carroceria da batida que já existe (`Regra.bater`): o custo daqui é só pelo que o
  carro destruiu.

**Monstros** (`src/server/Monstros.luau`): `Monstros.invalidarCaminhos(centro: Vector3, raio: number)`: para cada monstro vivo a ≤ raio, zera
`waypoints`/`alvoCaminho` e marca `ultimoCalculo = os.clock() + esperaNavmesh`. `Destruicao` chama pelo `aoQuebrar` (raio 60) em `pcall`
(serviço opcional). Vale para qualquer quebra, não só do Rastejador.

### 6.3 Carro: varredura e impacto
**`varrerCarro` (10 Hz, só motorista, só acima de `velMin`)**
1. Caixa à frente: `CFrame` do chassi deslocado `alcance/2` na direção da **velocidade horizontal**; tamanho = (largura do chassi + 0,5, altura do chassi,
   `alcance`); `alcance = cfg.carro.alcanceBase + |v| × PASSO × cfg.carro.passoFator` (para pegar o que o carro alcança antes da próxima amostra).
   Altura da caixa começa 0,8 acima do chão para não pegar piso.
2. `OverlapParams` Include `{ Mapa.Construcoes, Mapa.Props }`; para cada peça destrutível: `energia = Regras.danoImpactoCarro(massa, |v|, cfg)`,
   `efetivo = energia × mult["impacto"][classe]`. Se `Regras.atravessa(efetivo, vidaRestante)` → `Destruicao.dano(peca, energia, {tipo = "impacto", ... largura = largura do carro + 1})`
   (o carro **atravessa**: a parede some antes do contato, o carro quase não perde velocidade); acumula `custoCarroceria`. Se não atravessa: **nada**
   (a colisão real vai acontecer e o `impactoCarro` cuida).
3. Monstros: `OverlapParams` Include `workspace.Monstros`; `Monstros.ehMonstro(parte)` → `Monstros.dano(modelo, Regras.danoAtropelo(|v|), motorista)`, com `intervalo` por
   monstro (`cfg.carro.atropelo.intervalo`, tabela fraca); custo de carroceria = dano causado × `atropelo.recuo`. Acima de um limite o monstro também toma impulso
   (`ApplyImpulse` no `HumanoidRootPart` do monstro, que é do servidor).
4. Devolve `{ custoCarroceria, atropelados }`.

**`impactoCarro` (na batida)**: usa a **velocidade antes** (a direção da batida) e a energia perdida `0.5·m·(|vAntes|² − |vDepois|²)·escala`; acha a peça destrutível
mais perto do nariz do carro (mesma caixa, 3 studs) e chama `Destruicao.dano(tipo = "impacto")`. Escurece a parede mesmo sem quebrar. Devolve custo de carroceria só
do que quebrou.

Não há perda de velocidade ao atravessar (o dono da física é o cliente do motorista; o servidor não consegue frear). O preço é a carroceria. Aceito na v1; pendente avaliar
se precisa de freio (`d.chassi.AssemblyLinearVelocity` pelo dono) depois do playtest.

### 6.4 Tamanho do vão (`Config/Destruicao.buraco`, studs)
| tipo | largura | altura | observação |
|---|---|---|---|
| `bala` | 1,2 | 1,2 | furo pequeno **centrado no ponto do tiro** (não do chão), só se a vida chegar a 0 |
| `corte`, `alavanca`, `soco` | 3 | 6,5 | passa um jogador |
| `marreta` | 3,5 | 6,5 | |
| `garra` | `info.largura` (corpo × 1,6) | 4,5 | igual ao Rastejador de hoje |
| `impacto` | `info.largura` (carro + 1) | 5,5 | |
| `explosao` | 4 | 7 | |
`info.largura/altura` vencem a tabela. Sempre limitado ao tamanho da peça. Em parede vertical o vão começa no chão da peça.

## 7. Números de `Config/Destruicao.luau` (todos PROVISÓRIO)
```lua
return {
  estagios = { 0.2, 0.4, 0.6, 0.8 },
  escurecerAlvo = { 18, 16, 15 },          -- RGB 0-255
  pecaInteira = 2.5,                       -- studs: maior dimensão abaixo disto = destrói inteira
  somImpactoIntervalo = 0.12,              -- s por peça
  retalhos = { minimo = 0.8, danoHerdado = 0.5 },
  limites = { buracos = 300, pecasExtras = 6000 },
  invalidarCaminhos = { raio = 60 },
  carro = {
    velMin = 12,                           -- studs/s: abaixo disto o carro não quebra nada
    alcanceBase = 2, passoFator = 1.5,
    escalaEnergia = 1.5e-4,                -- dano = 0.5·massa·v²·escala (sedan 1520 a 58 st/s ≈ 380)
    recuoCarroceria = 0.15,                -- carroceria perdida por ponto de vida do material destruído
    atropelo = { velMin = 8, danoPorVel = 1.6, intervalo = 0.4, recuo = 0.1, impulso = 40 },
  },
  nomes = { ... }, papeis = { ... }, props = { ... }, grupos = { bomba_combustivel = { vida = 150, evento = "combustivel", material = "Metal" }, ... },
  buraco = { ... },                        -- tabela do §6.4
}
```
Valores do carro: massas de 1235 a 2200 e velMax de 45 a 78 dão energia de ≈ 190 (compacto a 45) até ≈ 700 (esportivo a 78): quebra madeira sempre, tijolo com carro
pesado/rápido, concreto só com esportivo a fundo. Atropelo a 58 st/s: ≈ 80 de dano (mata nível 1; nível 3 precisa de várias passadas).

## 8. Verificação

- `pwsh scripts/checar.ps1` verde (rojo build, **projetos iguais**: `default.project.json` e `build.project.json` ganham os mesmos arquivos novos, testes, selene, stylua).
- Testes Lune de `Regras/Destruicao` (§5).
- Comandos em `ServerStorage.Teste:Invoke(...)` no datamodel Server (Studio via MCP, **confirmar o place antes de escrever**):
  - `"destruicao_info"` → classe, vida, estágio e papel da peça na mira do jogador (raycast de 20 studs);
  - `"destruicao_dano"(tipo, quantidade)` → dá dano à peça na mira;
  - `"destruicao_nomes"` → nomes distintos sob `Construcoes` com contagem e classificação (para estender a lista branca);
  - `"destruicao_explosao"(raio, dano)` → explosão 10 studs à frente;
  - `"destruicao_estado"` → `estatisticas()`.
- Playtest pelo MCP: parede de madeira + machado (3 golpes), tijolo + pé de cabra, vidro + tiro (1), concreto + tiro (escurece em 4 estágios,
  não quebra), carro a 50 st/s numa parede de madeira (atravessa e perde carroceria), carro num monstro, Rastejador batendo numa parede, bomba de combustível.
  Console sem erro; `Destruicao.estatisticas()` coerente; FPS não cai com 50 peças danificadas.

## 9. Ordem de trabalho e coordenação

O agente do Rastejador está mexendo em `Monstros.luau`, `MonstroArrombar.luau`, `Veiculos.luau` e `Config/Rastejador.luau`. Para não colidir:
1. **Fase A (sem tocar neles):** `Config/Materiais`, `Config/Destruicao`, `Regras/Destruicao` + testes, `server/Destruicao` (inclui `varrerCarro`, `impactoCarro`, `explosao`),
   `Config/Armas.tipoDano`, ramo em `Armas.luau`, registro no `init.server.luau`, comandos de `Teste`, `project.json`.
2. **Fase B (edições mínimas e pontuais, relendo o arquivo logo antes de cada `Edit`):** ganchos de `Veiculos.luau` (`danoCarroceria`, laço, batida)
   e `Monstros.invalidarCaminhos`.
3. **Fase C (só depois do agente do Rastejador terminar a Fase 5 dele):** migrar `MonstroArrombar.luau` (§6.2).
4. Docs: `calculos.md` §7, `pendencias-integracao.md` "Destruição", `CLAUDE.md` (Estado e tabela de documentos), este arquivo (§ Estado).

## 10. O que o Opus vai auditar (critérios de aceite)
1. Números só em `Config`; regras puras testadas; `checar.ps1` verde nas 4 checagens.
2. **Nenhum** `Script` ou atributo novo por peça; estado em tabela fraca; `Color` repinta só na troca de estágio.
3. Recorte: volume conservado, sem peça solta, tudo `Anchored`, limites de buracos e de peças extras respeitados, nenhum clone de `Folha`/`Tapume`/peça de móvel.
4. Falha de qualquer parte (Sons, Ruido, Monstros ausentes) nunca derruba `dano` nem o laço do carro (`pcall` com `warn` limitado).
5. Armas: tiro e golpe em parede escurecem e quebram; jogador/monstro/veículo continuam como antes; arma sem `tipoDano` não explode.
6. Carro: só cai no laço com motorista e velocidade ≥ `velMin`; sem varredura quando parado; atropelo com intervalo.
7. Piso, cofre, móveis e peças não listadas continuam indestrutíveis. Decisões fora do contrato foram para as pendências.

## Estado
2026-11-04: Fases A, B e C feitas e testadas no Studio (place `11042026_1`, mapa com 182 construções, Play, servidor e cliente). `pwsh scripts/checar.ps1` verde nos
arquivos desta feature (a suíte `Rastejador.spec` ficou vermelha em 21:54 por edição concorrente do agente do Rastejador no `Config/Rastejador` — degrau 2x — e não por aqui).
- **Feito (Sonnet, A+B):** `Config/Materiais`, `Config/Destruicao`, `Regras/Destruicao` (+ `vao`, `fatorClarear`), `tests/Destruicao.spec.luau`, `server/Destruicao` (API do §6.0 e 5 comandos
  de Teste), registro em `init.server` (antes de `Monstros`), `Config/Armas.tipoDano` + ramo em `Armas.luau`, `Veiculos.danoCarroceria` + ganchos (laço e batida), `Monstros.invalidarCaminhos`.
- **Feito (Opus, revisão e C):** furo de bala centrado no ponto do tiro; vida máxima arredondada para inteiro (espessura 0,80000305 deixava 0,0005 de vida e exigia um golpe a mais);
  vidro estilhaça **inteiro** (`classes.vidro.inteira`); `aoQuebrar` agora leva `normal` e `chao` do vão e `Destruicao.vaoUtil(de, alvo, raio)` guarda os vãos (o navmesh não enxerga a peça
  que saiu); `MonstroArrombar` migrado: `impacto` chama `Destruicao.dano(tipo "garra", ruido "paredeQuebrando")`, `candidato` usa `vaoUtil` e recusa parede com mais de
  `Cfg.arrombar.golpesMax = 25` golpes (concreto, metal), `arrombavel` exige `ehDestrutivel`. Removidos: `abrirBuraco`, `poeira`, `VidaParede`, `Furado`, `Regras.vidaParede/buraco/partesDaParede`
  (e seus testes) e as chaves `vidaPorStud/vidaMin/vidaMax/retalhoMin/maxBuracos` do `Config/Rastejador`.
- **Medido em jogo:**
  - mapa real: madeira 0,8 = 120 de vida (3 machadadas, 4 pé de cabra, 10 balas); tijolo 360 (26 pé de cabra, 60 machado); concreto 480 (35 / 80); espelho de banheiro (Movel) indestrutível;
  - madeira: 2 machadadas (60 cada) quebram, cor 0,51 -> 0,37 -> 0,24 por estágio, 3 retalhos `Anchored`, evento com `normal` e `chao`;
  - tijolo com 40 tiros de pistola: 69% de dano, cor escurecida, não quebra;
  - vidro: 1 tiro estilhaça a peça inteira (sem cacos);
  - `vaoUtil`: normal orientada para quem consulta; nil do mesmo lado e a mais de 60 studs;
  - **arma real** (cliente -> evento `Atacar` -> servidor): 5 machadadas abriram vão 3x6,5 numa parede de madeira (retalhos 2,5 + 3 + 2,5);
  - **Rastejador** fora de um prédio fechado de madeira (4 paredes 20x12x1): ouviu 90 dB dentro, abriu o vão pela `Destruicao` (peças restantes com `CorOriginal`) e o jogador seguiu com 100 de vida;
  - carro (chassi falso, 50 st/s, massa 1520): atravessa parede de madeira e custa 37,5 de carroceria; atropelo: (50-8) x 1,6 = 67,2 de dano e 6,72 de custo, 1 monstro atingido;
  - console sem erro de script em dois playtests.
- **NÃO testado em jogo:** carro real dirigido por um jogador (ganchos de `Veiculos`: `varrerCarro` no laço e `impactoCarro` na batida); explosão; FPS com dezenas de peças danificadas; o dano do atropelo no
  monstro real (o teste usou outra instância do módulo `Monstros`; a conta do dano e do custo bateu); grupo bomba/tanque de combustível; telhado/laje; marreta (não existe item).
- **Armadilhas do teste:** `require` de um módulo de servidor dentro de `execute_luau` cria **outra instância** (estado e `iniciar` próprios): as estatísticas dele não contam os cortes do jogo, e sem `iniciar()` os
  serviços opcionais ficam desligados. O Rojo ficou sem aplicar as edições no Studio (`default.project.json` servindo, plugin conectado): o código testado foi colado no Studio a partir dos arquivos; reconectar o Rojo antes de salvar o place.
- Escolhas de implementação (não previstas): laje abre vão quadrado de lado `largura`; folga < `retalhos.minimo` entre vão e borda é absorvida pelo vão
  (só no plano, nunca na espessura); peça que não é `Part` bloco (Wedge, cilindro, MeshPart) é destruída inteira; `furos` conta só recortes (peça inteira e grupo
  não contam nem são limitados); em `destruicao_info/dano` a mira usa a direção da cabeça (sem a inclinação da câmera); impacto do carro usa a caixa da batida com início 1 stud atrás do nariz
  (`carro.recuoBatida`). Números novos em Config: `rachar`, `poeira`, `explosaoMaxPecas`, `carro.passoLaco/alturaChao/larguraExtra/larguraVao/alcanceBatida/recuoBatida`, `atropelo.velImpulso`
  (PROVISÓRIO). A caixa de varredura do carro começa em `alturaChao` acima do **centro** do chassi (não da base): com o chassi real (altura 5) cobre de 1,6 a 6,6 acima do chão.
