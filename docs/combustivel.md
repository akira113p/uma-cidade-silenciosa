# Combustível (gasolina, posto, mangueira, recipientes, passageiros)

Contrato entre as partes S1–S5. Escrito em 2026-11-05 a partir de 4 levantamentos (carros, itens/inventário, convenções, API de corda).
Decisões do usuário (2026-11-05): **ids fixos** para garrafa/galão (sem litros por item); **bomba infinita**.
Pedido original: abastecer o carro; ver a gasolina na 1ª e na 3ª pessoa; carro com mais de um ocupante; mangueira que pluga na
tampa do carro, **com física**; gasolina em garrafa vazia e em galão (criar o galão).

## 1. Escopo

Entra:
1. Tanque por carro (litros), consumo, motor que não liga/desliga sem gasolina.
2. Ver a gasolina: HUD do veículo (1ª e 3ª pessoa), agulha no painel da Cabine (1ª pessoa), etiqueta flutuante perto da tampa de qualquer carro.
3. Vários ocupantes: confirmar, completar e consertar o que já existe (bancos 2..n); trocar de banco; HUD para todos.
4. Posto: 4 bombas já existentes no mapa (`bomba_combustivel`) ganham bocal, mangueira e prompts. Infinitas.
5. Mangueira: sai da bomba, vai na mão do jogador, pluga na tampa do carro. Física Verlet no cliente (§5).
6. Recipientes: `garrafaVazia`, `garrafaGasolina`, `galaoVazio`, `galaoGasolina` (o galão é item novo + modelo 3D por código).
7. Ruído ao abastecer (atrai monstro).

Não entra (anotado em `docs/pendencias-integracao.md`, seção "Combustível"): sifão (tirar gasolina de carro), explosão da bomba/carro com gasolina,
preço/economia, persistência, litros parciais, sons novos (usa ids provisórios).

## 2. Mudança no contrato de `docs/veiculos.md`

Tirar "combustível" da linha "Não entra" (veiculos.md:13) e apontar para este documento.

## 3. Números (todos em `src/shared/Config/Combustivel.luau` e `Config/Veiculos.luau`; nenhum em outro lugar)

Unidades: litros (L), segundos (s), studs.

`Config/Combustivel.luau` (arquivo novo, `return { ... }`, comentários em português):
```
autonomiaMaxSeg     = 900    -- tanque cheio, motor ligado, na velMax com pedal a fundo: dura 15 min
autonomiaParadoSeg  = 3600   -- tanque cheio, motor ligado, parado: dura 60 min
fracaoReserva       = 0.15   -- abaixo disso: aviso de reserva (HUD pisca)
passoAtributo       = 0.1    -- L; o atributo Combustivel só muda quando varia >= isto

mangueira = {
  comprimento   = 14,    -- studs, máximo entre bocal da bomba e a ponta
  tolerancia    = 2.5,   -- studs acima de comprimento: o servidor solta a mangueira
  segmentos     = 14,    -- pontos da corda Verlet (cliente)
  distanciaDesenho = 150, -- studs da câmera; além disso a mangueira não é simulada
  raio          = 0.18,  -- studs
  vazaoLps      = 0.8,   -- L/s ao abastecer carro pela mangueira
  alcanceTampa  = 6,     -- studs até a tampa para plugar/soltar (ProximityPrompt)
  alcanceBomba  = 8,     -- studs até a bomba para pegar/guardar/encher
  conferirSeg   = 0.2,   -- período da checagem de distância no servidor
}
recipientes = {          -- por id de item; litros fixos (decisão do usuário)
  garrafaVazia     = { capacidade = 0.5, enche = "garrafaGasolina" },
  garrafaGasolina  = { litros = 0.5,     despeja = "garrafaVazia" },
  galaoVazio       = { capacidade = 5,   enche = "galaoGasolina" },
  galaoGasolina    = { litros = 5,       despeja = "galaoVazio" },
}
carro = {
  -- Tampa de combustível, proporção do tamanho (sx, sy, sz) do Chassi, relativa ao CENTRO do chassi.
  -- Frente = -Z, esquerda = -X (VeiculoModelo.luau:3). Lado esquerdo, traseiro, logo atrás da porta.
  tampa = { fx = -0.5, fy = 0.05, fz = 0.33, tamanho = { 0.15, 0.5, 0.7 }, saliencia = 0.05 },
  etiquetaDistancia = 10,   -- studs até a tampa para a etiqueta de gasolina aparecer
}
encherSegundos      = 1.0    -- HoldDuration do prompt "Encher" na bomba
despejarSegundos    = 2.5    -- tempo travado despejando um recipiente (galão), garrafa = 1.0
```
Derivados (puros, em `Regras/Combustivel.luau`, nada hard-coded):
- `consumoParadoLps(tanque) = tanque / autonomiaParadoSeg`
- `consumoMaxLps(tanque)   = tanque / autonomiaMaxSeg`
- `consumoLps(tanque, fracVel, pedal) = parado + (max - parado) * clamp(fracVel,0,1) * (0.4 + 0.6 * clamp(|pedal|,0,1))`
  (acelerar parado, `fracVel = 0`, consome só o parado; engrenar a fundo na velMax = max)
- `fracVel = |velocidade ao longo do chassi| / velMax do carro` (o servidor já usa isso na ruidosidade do motor: reaproveitar).

`Config/Veiculos.luau` (adicionar, sem tocar no resto):
- por tipo: `tanque` (L): compacto 40, sedan 55, esportivo 50, suv 70, pickup 80, van 90.
- A posição da tampa NÃO é por tipo: é proporcional ao tamanho do carro, em `Config/Combustivel.carro.tampa` (§4.2).
- `condicoes.combustivel = { min = 0.05, max = 0.6, chanceVazio = 0.15 }` (fração do tanque ao nascer carro do mapa).
- `teclas.trocarBanco = { "F" }`.
- `ruido`/`Config/Som.luau` ações novas: `abastecer = 50` (dB, enquanto a mangueira enche o carro, a cada 2 s), `encher = 45` (recipiente na bomba),
  `despejar = 40` (recipiente no tanque). Valores chutados, ajustar no playtest.

## 4. Veículo

### 4.1 Estado (`Regras/Veiculo.luau`)
- `Estado.combustivel: number` (litros). Entra em `copiar`, `sortear` e `montar` (os 3 lugares que montam `Estado` campo a campo; esquecer um perde o campo em silêncio).
- `sortear`: `combustivel = tanque * (rng() < chanceVazio ? 0 : lerp(min, max, rng()))`; carro `queimado` nasce com 0.
- `montar(tipo, pedido, cfg)`: `pedido.combustivel` é fração 0..1 (opcional, padrão 1 = cheio; usado pelo admin/invocação).
- `podeLigar(e): boolean` = `podeDirigir(e) and e.combustivel > 0` (nova; `tentarLigar` chama e devolve falso sem consumir sorteio quando não há gasolina).
- Funções puras novas em `Regras/Combustivel.luau`: `consumoLps`, `consumir(litros, dt, tanque, fracVel, pedal): number` (novo nível, mín 0),
  `encher(atual, tanque, quantidade): (novo, aceito, sobra)`, `fracao(atual, tanque)`, `reserva(atual, tanque, cfg): boolean`,
  `trocarRecipiente(id, cfgRecipientes, acao): string?` (`"encher"`→`enche`, `"despejar"`→`despeja`; nil se não aplicável).

### 4.2 Modelo (`VeiculoModelo.luau`)
- Atributos no Model: `Tanque` (L, capacidade, fixo), `Combustivel` (L, arredondado, só muda ≥ `passoAtributo`), `Abastecendo` (bool, mangueira plugada).
- Peça `Tampa`: bloco `Config/Combustivel.carro.tampa.tamanho` (X espessura 0,15; Y 0,5; Z 0,7), cinza-claro `(170,170,175)`, soldado ao Chassi (WeldConstraint, como os outros blocos).
  Centro (relativo ao centro do Chassi, mesmo sistema dos blocos de `VeiculoModelo.luau:618-627`): `x = fx * sx - saliencia`, `y = fy * sy`, `z = fz * sz`, com (sx, sy, sz) = tamanho do Chassi/Config (com malha, o da malha, :600).
  Para o sedan (8,1 × 5 × 19,8): centro ≈ (−4,1; 0,25; 6,5): fora da PortaE (x = −3,95, espessura 0,2, z −2,4…5,5), atrás dela e antes do fim do carro. Conferir com `screen_capture` em carro de cada tipo (malha muda o contorno).
  Attachment `PortaCombustivel` dentro da Tampa, na face externa (offset −X local da Tampa), `Orientation` olhando para fora (−X do carro). `CanCollide=false`, `CanQuery=true`, `Massless=true`.
  `CollectionService:AddTag(tampa, "Tampa")` (replica a tag; o cliente da etiqueta e o servidor de abastecimento descobrem as tampas por ela; o carro é `FindFirstAncestorOfClass("Model")`).
  `ProximityPrompt` "Abastecer" na Tampa (E, `MaxActivationDistance = mangueira.alcanceTampa`, `RequiresLineOfSight=false`, `Name = "Abastecer"`), criado junto dos prompts de porta. Quem decide o efeito é o servidor (§6), não o prompt.
- A Tampa existe também sem malha (carro em blocos). Entra na lista de peças "alvo" da destruição só como decorativa (sem vida própria).
- `OlhoLocal` continua sendo o olho do motorista; ver §7 para passageiros.

### 4.3 Servidor (`Veiculos.luau`)
- O laço de 0,1 s hoje só visita carro com motorista. Consumo vale para **todo carro com `MotorLigado = true`**, com ou sem motorista:
  incluir esses carros no laço (lista própria de carros ligados) ou fazer a parte de combustível num laço próprio de 0,2 s sobre `carrosLigados`. Não criar laço por carro.
- `consumir`: `fracVel` pela velocidade do Chassi; `pedal` = atributo `Pedal` do motorista (se o cliente não replica o pedal, usar `fracVel` como proxy: `pedal = fracVel > 0.05 and 1 or 0`). O agente decide e documenta.
- Chegou a 0: `desligar` (já existe) + atributo `SemCombustivel = true` + ruído de motor morrendo (usa a ação existente `carro`, sem som novo).
- `tentarLigar`/`LigarMotor`: sem gasolina → não liga, avisa o jogador pelo canal de aviso que o código já usa (`Aviso`/`Dica`; descobrir no código) com "Sem gasolina".
- Anti-trapaça: nenhuma mudança (o cliente não decide combustível).
- Admin: invocar carro aceita `combustivel` (fração) no pedido; padrão cheio. Linha/botão simples no menu de carros do admin: "Combustível: cheio / meio / vazio" (src/server/Admin.luau já aceita `pedido`; client/Admin.luau ganha 3 botões).
- Spawn de carros do mapa (sob demanda): `Regra.sortear` já traz o combustível; só garantir que o atributo `Combustivel` e `Tanque` são gravados ao criar.
- Funções públicas novas (para `Combustivel.luau` server): `Veiculos.combustivelDe(modelo): (litros, tanque)`, `Veiculos.encher(modelo, litros): (aceito)` (atualiza Estado e atributo),
  `Veiculos.motorLigado(modelo): boolean`.

## 5. Mangueira (física)

Decisão: **Verlet no cliente, estado autoritativo no servidor**. Motivo (levantamento 2026-11-05): `RopeConstraint` não colide, não tem curva real
(só reta/folgada), tem histórico de bug de replicação com personagem e de instabilidade; cadeia de `BallSocketConstraint` tem bug aberto de "spazm" (2026-04-03)
e custo de física por segmento sem número oficial. Verlet no cliente dá curva real, peso, arrasto no chão e zero custo de rede/ownership.

### 5.1 Estado replicado (servidor cria, todos veem)
`workspace.Mangueiras` (Folder, criada pelo servidor). Para cada mangueira ativa, um `Folder` filho nomeado `tostring(UserId do dono)`:
- Atributos: `Dono` (UserId), `Estado` (`"mao"` | `"plugada"`), `Comprimento` (studs), `Fluxo` (bool: está enchendo o carro).
- `ObjectValue` `Bocal` (Value = Attachment `Bocal` na bomba).
- `ObjectValue` `Destino` (Value = Attachment `PortaCombustivel` do carro; vazio quando `Estado = "mao"`).
Cliente que ainda não tem as instâncias (streaming) usa `WaitForChild(…, 5)` e ignora a mangueira se falhar.

### 5.2 Servidor
- Uma mangueira por jogador, uma por bomba (se a bomba já está em uso por outro jogador, "Bomba ocupada").
- Pegar: prompt "Pegar mangueira" na bomba (E). Exige mão livre: ao pegar, o servidor guarda a arma equipada (§6.3) e o recipiente na mão.
- Soltar/guardar: prompt "Guardar mangueira" na bomba (E, mesmo prompt, o texto é trocado no cliente), ou morte, saída do jogo, entrar em carro, pegar arma/recipiente.
- Plugar: prompt "Abastecer" na Tampa do carro. Condições: motor **desligado**, jogador com mangueira em `"mao"`, distância ≤ `alcanceTampa × 1.25`, carro não `Queimado`, tanque com espaço.
  Efeito: `Estado = "plugada"`, `Destino = PortaCombustivel`, atributo `Abastecendo = true` no carro, `Fluxo = true`.
- Enquanto `Fluxo`: a cada 0,2 s, `litros = vazaoLps × dt` no tanque; `Ruido.emitirAcao("abastecer")` a cada 2 s na posição da Tampa; para sozinho quando o tanque enche (`Fluxo = false`; mangueira continua plugada).
- Soltar do carro: prompt "Abastecer" na Tampa de novo (E, com mangueira plugada = desplugar) → volta para `"mao"`.
- Distância: a cada `conferirSeg`, `distância(Bocal, ponta) > Comprimento + tolerancia` → solta: mangueira some (volta pra bomba), som de metal, aviso "A mangueira soltou".
  `ponta` = `RightHand` do dono (mão) ou `PortaCombustivel` (plugada). Carro que andar (motor ligado) com mangueira plugada: ao ligar o motor com mangueira plugada, o servidor solta a mangueira primeiro (não explode, só retrai).
- Limpeza: dono morre/sai/entra no carro, carro destruído/queimado/removido (carro sob demanda), bomba destruída → destrói o Folder.
- Sem custo, bomba infinita. Sem `RopeConstraint`, sem `Part` de física no servidor.

### 5.3 Cliente (`src/client/Mangueira.luau`)
- Observa `workspace.Mangueiras`. Para cada mangueira, simula uma corda Verlet de `segmentos` pontos entre as duas pontas (bocal da bomba; mão `RightHand` do dono ou `PortaCombustivel`).
- Física por quadro (`RunService.RenderStepped`, só mangueiras a ≤ 150 studs da câmera): gravidade `-workspace.Gravity`; restrições de distância entre pontos (4 iterações), comprimento por segmento = `Comprimento / (segmentos − 1)`;
  pontas presas; colisão com o chão por 1 raio para baixo por ponto (`workspace:Raycast`, filtro exclui personagens, `Mangueiras`, `CurrentCamera`); arrasto leve (`amortecimento = 0.98`) para não balançar eternamente.
- Desenho: `segmentos − 1` cilindros finos (`Part`, `Shape=Cylinder`/bloco fino, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`, `Anchored=true`, `Material=Plastic`), cor borracha preta `(25,25,25)` com bico `(200,180,40)`
  (último segmento amarelo). Pasta local em `workspace.CurrentCamera/MangueiraLocal`. Reaproveitar peças (pool); nada de `Instance.new` por quadro.
- Prompts: o servidor cria os prompts; o cliente só ajusta `Enabled`/`ActionText` **localmente** (padrão que `InventarioUI` já usa para a caixa de loot): ver §6.4.
- Se a mangueira esticar além de `Comprimento` (antes do servidor soltar), o ponto da ponta não acompanha (visual esticado, sem puxar o personagem).

## 6. Posto, recipientes, mão

### 6.1 Bomba (`src/server/Combustivel.luau`, módulo novo)
- No `iniciar`: espera o mapa (mesmo padrão de espera de `server/Loot.luau`), varre `workspace.Mapa.Construcoes` por `Model` com atributo `Movel == "bomba_combustivel"`. Para cada um:
  cria `Attachment` `Bocal` numa peça do modelo (no coldre/lado do bico; posição do levantamento de geometria §6.2), marca `BombaId` (string única) e cria os prompts.
- Prompts na bomba (parte do corpo): 
  - "Pegar mangueira" (E, `Name = "PegarMangueira"`, hold 0).
  - "Encher recipiente" (F, `Name = "EncherRecipiente"`, hold `encherSegundos`).
- "Encher recipiente": o servidor escolhe do inventário do jogador o primeiro `galaoVazio`, senão o primeiro `garrafaVazia` (considerando a mão: se o recipiente na mão é um vazio, é ele). Troca atômica (§6.5). Ruído `encher`. Aviso "Sem recipiente vazio" se não houver.
- Tecla F no prompt fica fora do conflito de `trocarBanco` porque prompts só aparecem a pé.

### 6.2 Geometria da bomba (levantamento em `ferramentas/mapa/mobilia_comercial.luau:546-564`)
O `Model` da bomba NÃO tem `PrimaryPart` e o pivô padrão do Roblox não é a origem do gerador. Origem do gerador = centro da pegada no piso. Para achar a origem:
`base = a Part com Size ≈ (2.4, 0.35, 1.8)` (base de concreto, centro local (0, 0.175, 0)) → `origemCF = base.CFrame * CFrame.new(0, -0.175, 0)`. Tudo abaixo é local a `origemCF`.
Corpo: Part com Size ≈ (2.0, 4.85, 1.5), centro (0, 2.775, 0). Altura total 6,5; largura X −1,2…1,26; profundidade Z −0,9…0,9. **Frente (visor) = −Z. Bico e coldre ficam no lado +X** (peças a x = 1,15):
coldre (0.2×1.2×0.8 em (1.15, 3.5, −0.2)), mangueira vertical (cilindro Ø0.22, y 0.9…3.0, em (1.15, 1.95, −0.5)), bico horizontal (cilindro Ø0.22, Z −0.55…0.35, em (1.15, 0.9, −0.1)), cor `(30,30,34)`.
- `Attachment` `Bocal`: parent = a Part do corpo, posição local à `origemCF` = `(1.15, 3.0, −0.5)` (topo da mangueira vertical), orientação: +Y mundo.
- Enquanto a mangueira desta bomba está ativa, o servidor deixa `Transparency = 1` as duas peças cilíndricas `(30,30,34)` a x ≈ 1,15 (a mangueira vertical e o bico estáticos) e restaura ao guardar. Identificar por `Shape`/Size/posição relativa à origem (tolerância 0,05). Se não achar, ignora (mantém visíveis).
- Prompts na Part do corpo, `MaxActivationDistance = alcanceBomba`. Posto: 4 bombas, ilhas 4×0,6×8 (z local do posto −15…−7); um carro de prop fica no vão entre as bombas 1 e 2 (pode estar sobreposto à ilha; não é problema deste sistema).
- Posto de teste: `ServerStorage.Teste:Invoke("irPosto")` (S3 registra) teleporta o jogador ao lado da bomba mais próxima.

### 6.3 Mão
Mão = `RightHand`. Só uma coisa por vez: arma, lanterna(?), recipiente **ou** mangueira. Lanterna não ocupa a mão (modelo próprio no cliente).
- Atributo do jogador `RecipienteSlot` (slot do inventário que está na mão, ou nil). `Mangueira` (bool no Player: tem mangueira na mão).
- Segurar recipiente: clicar o slot / tecla 1–8 num item de `tipo = "recipiente"` alterna (mesmo gesto que usar item); servidor `Combustivel.segurarRecipiente(jogador, slot)`.
  Visual: bloco `RecipienteNaMao` soldado na `RightHand` (como `ArmaNaMao`): galão vazio vermelho-escuro, galão cheio vermelho com tampa amarela (`§8`), garrafa vazia/cheia (cilindro fino).
- Equipar arma desfaz recipiente e solta mangueira (`jogador:GetAttributeChangedSignal("ArmaEquipada")`; em `Armas.equipar` o `ArmaSlot` é setado antes de `ArmaEquipada`).
- Pegar mangueira / segurar recipiente com arma equipada: `Armas.luau` **não exporta** função de desequipar (só `desequipar` local e `Armas.iniciar`). Contrato: NÃO mexer em `Armas.luau`. O servidor **recusa**
  pegar mangueira/segurar recipiente com arma equipada, com aviso "Guarde a arma primeiro" (o jogador desequipa clicando de novo no slot da arma). Anotado em pendências (preferir exportar `Armas.guardar(jogador)`).
- O jogador pode atacar sentado (`Armas.atacar` não checa assento): fora do escopo, anotar em pendências.
- Morrer, entrar no carro: limpa recipiente da mão e mangueira.

### 6.4 Prompts por contexto (cliente)
Cliente (em `src/client/Mangueira.luau`) liga/desliga e renomeia **localmente** os prompts do servidor, para o jogador não ver opção sem sentido:
- Prompt `PegarMangueira` na bomba: visível se o jogador não tem mangueira; se tem a mangueira **desta** bomba, texto "Guardar mangueira".
- Prompt `EncherRecipiente`: visível só se o inventário tem `galaoVazio` ou `garrafaVazia`.
- Prompt "Abastecer" da Tampa: texto "Plugar mangueira" (com mangueira em mão), "Desplugar mangueira" (mangueira plugada neste carro), "Despejar galão"/"Despejar garrafa" (recipiente cheio na mão); fora desses casos, oculto.
- Dados do contexto: atributos do Player (`Mangueira`, `RecipienteSlot`) e o inventário que o cliente já recebe pelo remote `Inventario`. O servidor valida tudo de novo (cliente só esconde).

### 6.5 Itens (`Config/Itens.luau`) e inventário
Itens novos (ids fixos): 
```
garrafaVazia    = { nome = "Garrafa vazia",          tipo = "recipiente", pilha = 3 },
garrafaGasolina = { nome = "Garrafa de gasolina",    tipo = "recipiente", pilha = 3 },
galaoVazio      = { nome = "Galão vazio",            tipo = "recipiente", pilha = 1 },
galaoGasolina   = { nome = "Galão de gasolina (5 L)", tipo = "recipiente", pilha = 1 },
```
- `tipo = "recipiente"` entra na lista de tipos do comentário (Itens.luau:2). Os dados de litros ficam em `Config/Combustivel.recipientes` (única fonte).
- Atenção: `galao` já é o nome de um MÓVEL de loot (Casa.luau:78), por isso o item se chama `galaoVazio`. Não renomear o móvel.
- Despejar no carro: `galaoGasolina → galaoVazio` / `garrafaGasolina → garrafaVazia`, adiciona `litros` no tanque. Sobra além da capacidade **se perde** (default; anotado em pendências).
  Antes de despejar, se `espaço no tanque < 0,25 L`: recusa ("Tanque cheio") e não gasta o item. Duração travada: `despejarSegundos` (galão) / 1,0 (garrafa), mesma trava de ação usada em uso de item (`uso`); o servidor cancela se o jogador se afasta.
- **Troca atômica**: `Regras/Inventario.trocar(inv, deId, paraId, itens, padrao?): (Inv, ok)` — remove 1 de `deId`, adiciona 1 de `paraId`; se o resultado não couber, devolve o inventário ORIGINAL e `false` (sem meia troca).
  `server/Inventario.trocar(jogador, deId, paraId): boolean` chama a regra e `mudou` uma vez. É a única forma de transformar item (nada de `remover` + `dar` soltos).
- Cópias de `{id, qtd}`: não há campos novos por instância, então **nada** nas 6 cópias do levantamento muda.
- Hook de uso: `server/Inventario.luau`. A função `usar` tem a guarda `TIPOS_USAVEIS` (comida/bebida/cura, linhas ~364-367) que **descarta em silêncio** qualquer outro tipo, e um tipo novo sem ramo cairia no ramo "comida" de `aplicarUso` (~327-352).
  O hook entra **antes** dessa guarda: `if def.tipo == "recipiente" then require(script.Parent.Combustivel).segurarRecipiente(jogador, slot) return end`. NÃO adicionar `recipiente` a `TIPOS_USAVEIS`. `Limite` 0,2 s do handler `UsarItem` (~487-499) já cobre. (Linhas aproximadas: o levantamento deu :327-352 e :487-499; conferir.)
- Cliente (`InventarioUI.luau`): `apertarSlot` (~685-697) já cai no `else` e manda `UsarItem` para tipo desconhecido, então o clique/tecla 1–8 funciona sem mudar a decisão. Falta: destaque do slot na mão (hoje só arma e lanterna; ler `RecipienteSlot` do jogador, ao lado de `slotEquipado()`/`slotLanterna()` ~229-248),
  e botão principal na tela Tab ("Segurar"/"Guardar") — `detalhesDe` (~386) devolve sem botão para tipo desconhecido.
- Admin: ids novos aparecem sozinhos no menu "Itens" (itera `CfgItens.itens`).
- Loot (`Config/Compartimentos`, não `Itens.tabelas`, que o jogo não lê):
  - `posto_oficina`: `galaoVazio` peso 25 (qtd 1), `galaoGasolina` peso 10 (qtd 1), `garrafaVazia` peso 20 (qtd 1–2).
  - `garagem_casa`: `galaoVazio` peso 20, `galaoGasolina` peso 8.
  - tabelas de cozinha/casa (a que tem `agua`/`refrigerante`): `garrafaVazia` peso 10.
  Conferir os nomes exatos das tabelas em `Config/Compartimentos/Casa.luau` e `Comercial.luau`.
- **O galão (criar):** item `galaoVazio`/`galaoGasolina` (acima) + modelo 3D em blocos, montado por código em `src/shared/Config/ItensModelos.luau` (sistema de `docs/itens-no-mundo.md`: modelo de blocos por item, mão via `ItemNaMao.definir(jogador, "uso", id)`, chão via `ItensChao`), sem malha externa. (Versão final: o S3 chegou a escrever um bloco próprio na mão e foi trocado por este sistema em 2026-11-05.)
  Medidas (1 stud ≈ 0,28 m; galão de ~5 L ≈ 25×20×10 cm → **~0,9 × 0,75 × 0,4 studs**), estética PS1, todos `SmoothPlastic`:
  - corpo `0.9 × 0.75 × 0.4`, vermelho `(150,25,20)` (vazio: `(110,30,25)` mais escuro);
  - bocal/tampa `0.2 × 0.15 × 0.2` no canto superior: amarelo `(220,190,50)` cheio, cinza `(90,90,95)` vazio;
  - alça `0.35 × 0.08 × 0.08` no topo, `(60,15,12)`;
  - listra clara fina na frente, só decoração.
  Garrafa: cilindro `0.25 × 0.7` (Ø × altura), transparente `Glass` `(210,225,230)`; cheia tem um cilindro interno amarelo-âmbar `(210,170,60)` com 70% da altura (`Neon` não); vazia só o vidro.
  Posição na mão: `Weld`, `C0 = CFrame.new(0, -0.2, -0.3) * CFrame.Angles(0, math.rad(90), 0)`; o agente ajusta olhando `screen_capture` em 1ª e 3ª pessoa (o viewmodel de arma é `ArmasViewmodel`; o recipiente não tem viewmodel próprio: ver na 1ª pessoa se o bloco aparece, senão anotar em pendências).

## 7. Passageiros (carro com mais de uma pessoa)

Estado atual (levantamento): 2–4 bancos por tipo, `Banco1` é `VehicleSeat`, os demais `Seat`; prompts `Entrar` só em `PortaE`/`PortaD`; entrar pega o primeiro banco livre.
Verificar e corrigir:
1. **Entrar**: prefere o banco livre do lado da porta usada (`PortaE` → x < 0 / `PortaD` → x > 0; sinal conforme o levantamento de geometria) e mais à frente; se não houver, qualquer livre. Mensagem "Carro lotado" quando cheio.
2. **Trocar de banco**: remote novo `TrocarBanco` (cliente → servidor). Servidor: `Veiculos.trocarBanco(jogador)` troca para o próximo banco livre (circular). Se o `Banco1` ficou livre e há passageiro, ele pode virar motorista (`atualizarMotorista` roda no listener de Occupant que já existe). Tecla `F` (`Config/Veiculos.teclas.trocarBanco`), botão no touch.
3. **Motorista sai com passageiro**: o carro não pode ficar ancorado com gente dentro. Regra: carro com qualquer ocupante não é ancorado (hoje, sem motorista, `freiar` ancora): usar freio de estacionamento por `AssemblyLinearVelocity` (já tem `freiar`; checar se ancora) e liberar o dono de rede para o passageiro mais antigo, ou servidor, se ninguém dirige.
4. **Dano a todos**: `danoOcupante` na batida aplica a cada ocupante (motorista e passageiros), não só ao motorista.
5. **Saída do passageiro**: `pedirSair` já destrói o `SeatWeld`; conferir que o ponto de saída (`colocarAoLado`) usa o lado do banco do passageiro (banco com x<0 sai pela esquerda) e não colide com o carro.
6. **Cliente do passageiro**: hoje o cliente do passageiro cai em `sair()` do `Direcao` (só limpa controles, correto). Falta: HUD e Cabine para passageiro (§8.3, §8.4); sem teclas de direção; `E` sai; `F` troca de banco.
7. Entrar em carro com mangueira na mão: solta a mangueira primeiro (§5.2).

## 8. Interface

### 8.1 HUD do veículo (`HudVeiculo.luau`)
- Aparece para **qualquer ocupante** (não só motorista), em 1ª e 3ª pessoa (hoje já não olha o `CameraMode`; manter).
- Nova linha "Gasolina": barra com a fração (`Combustivel / Tanque`), texto `23/55 L` (1 casa decimal só se < 10 L), cor: verde > reserva, amarelo ≤ `fracaoReserva`, vermelho piscando (2 Hz) quando 0 ou ≤ 5%.
- Painel cresce (232×156 → ~232×180). Conferir sobreposição com os botões touch (Buzina cobre a faixa superior do painel, H-168 a H-110): mover os botões touch para cima ou subir o painel.
- Lê atributos do Model do carro (`Combustivel`, `Tanque`, `SemCombustivel`), interpola a barra entre atualizações a 10 Hz (já existe).
- Passageiro: mostra só velocidade, Ligado/Desligado, gasolina (não mostra pneus/vidros do motorista? mostra tudo, é informação do carro: **mostra tudo**).

### 8.2 Etiqueta externa (gasolina de qualquer carro, 3ª pessoa e a pé)
- Em `HudVeiculo.luau`: a pé ou dentro, enquanto a distância até uma `Tampa` for ≤ `carro.etiquetaDistancia` (10 studs), uma `BillboardGui` local (`Adornee = Tampa`, `AlwaysOnTop=true`, `Size` ~ 120×34 px, `MaxDistance` = a mesma) mostra "Gasolina 23/55 L" com mini barra, no mesmo estilo do HUD.
  Descoberta das tampas: `CollectionService:GetInstanceAddedSignal("Tampa")` / `GetInstanceRemovedSignal("Tampa")` + `GetTagged("Tampa")` no início (o servidor não expõe lista de carros e o cliente não tem a tabela `dados` do servidor). Distância checada a 5 Hz só entre as tampas conhecidas; só 1 etiqueta (a mais próxima).
  Streaming: carro fora do alcance do cliente não existe nele, então a etiqueta some sozinha. Lê `Combustivel`/`Tanque` do Model da tampa.
- Aparece sempre (informação útil), com ou sem mangueira.

### 8.3 Agulha na Cabine (1ª pessoa) (`Cabine.luau`)
- O painel de blocos cinza ganha um medidor: moldura preta 1,4×0,8 studs, ponteiro (bloco fino vermelho) que gira de −60° a +60° conforme `Combustivel / Tanque`, "E" e "F" em dois blocos pequenos, luz vermelha pequena (bloco `Neon`) acesa na reserva.
- Passageiros: sem volante nem mãos; olho = `OlhoLocal` deslocado para o banco do passageiro (`bancos[i]` em `VeiculosMalhas` menos `bancos[1]`, x e z); mesma regra de visibilidade do corpo (`LocalTransparencyModifier = 1`).

### 8.4 Inventário (`InventarioUI.luau`)
- Slot de recipiente: clique alterna "segurar" (destaque como o equipado); texto do slot já mostra o nome (a UI é texto).
- Nada de ícones novos.

## 9. Rede

Remotes novos (declarar em `src/shared/Rede.luau`, lista `EVENTOS`, com comentário de direção):
- `TrocarBanco` — cliente → servidor — sem argumento.
- `Aviso` já existe? O agente confere o canal de mensagem ao jogador existente e reusa; criar `AvisoCombustivel` só se não existir nenhum.
Todo o resto é por atributo/instância (§5.1, §4.2). Prompts do servidor dispensam remote.
`Limite.ok(jogador, "TrocarBanco", 0.4)`.

## 10. Divisão em partes e ordem

| Parte | Dono | Arquivos |
|---|---|---|
| **S1** Regras, Config, Itens, loot, Rede, testes | agente Sonnet 1 | `src/shared/Config/Combustivel.luau`, `src/shared/Regras/Combustivel.luau`, `src/shared/Regras/Veiculo.luau`, `src/shared/Config/Veiculos.luau`, `src/shared/Config/Itens.luau`, `src/shared/Config/Compartimentos/*.luau`, `src/shared/Config/Som.luau`, `src/shared/Config/Sons.luau`, `src/shared/Regras/Inventario.luau`, `src/shared/Rede.luau`, `tests/Combustivel.spec.luau`, `tests/Veiculo.spec.luau`, `tests/Inventario.spec.luau`, `tests/Loot.spec.luau` (se precisar) |
| **S2** Servidor do carro | agente Sonnet 2 | `src/server/Veiculos.luau`, `src/server/VeiculoModelo.luau`, `src/server/Admin.luau`, `src/client/Admin.luau` (só botões de combustível do carro) |
| **S3** Servidor do posto, mangueira, mão | agente Sonnet 3 | `src/server/Combustivel.luau` (novo), `src/server/Inventario.luau` (`trocar`, hook de recipiente), `src/server/init.server.luau` (ORDEM) |
| **S4** Cliente do carro | agente Sonnet 4 | `src/client/HudVeiculo.luau`, `src/client/Cabine.luau`, `src/client/Direcao.luau` (passageiro, tecla trocar banco, botão touch) |
| **S5** Cliente da mangueira e inventário | agente Sonnet 5 | `src/client/Mangueira.luau` (novo), `src/client/InventarioUI.luau`, `src/client/init.client.luau` (ORDEM) |

Ordem de leitura: todos leem este documento. As APIs entre partes (assinaturas abaixo) são fixas: cada agente escreve contra elas sem esperar o outro.
`pwsh scripts/checar.ps1` é rodado pelo Opus depois de todas as partes; cada agente roda `lune run tests/<seu>.spec.luau`, `selene src`, `stylua --check src tests` no que tocou.

### Assinaturas fixas

`Regras/Combustivel.luau` (puro, sem `require` de Roblox; `cfg` = `Config/Combustivel`):
```
consumoLps(tanque: number, fracVel: number, pedal: number, cfg: any): number
consumir(litros: number, dt: number, tanque: number, fracVel: number, pedal: number, cfg: any): number   -- novo nível, >= 0
encher(atual: number, tanque: number, quantidade: number): (number, number, number)                       -- (novo, aceito, sobra)
fracao(atual: number, tanque: number): number                                                           -- 0..1
reserva(atual: number, tanque: number, cfg: any): boolean
recipiente(id: string, cfg: any): { litros: number?, capacidade: number?, enche: string?, despeja: string? }?
```
`Regras/Veiculo.luau`: `podeLigar(e: Estado): boolean`; `Estado.combustivel: number`; `montar(...)` aceita `pedido.combustivel` (fração).
`Regras/Inventario.luau`: `trocar(inv: Inv, deId: string, paraId: string, itens: any, padrao: number?): (Inv, boolean)`.

`server/Veiculos.luau` (S2 expõe, S3 consome): 
```
Veiculos.combustivelDe(modelo: Model): (number, number)    -- (litros, tanque)
Veiculos.encher(modelo: Model, litros: number): number     -- litros aceitos
Veiculos.motorLigado(modelo: Model): boolean
Veiculos.trocarBanco(jogador: Player): ()
```
`server/Inventario.luau` (S3):
```
Inventario.trocar(jogador: Player, deId: string, paraId: string): boolean
```
`server/Combustivel.luau` (S3):
```
Combustivel.segurarRecipiente(jogador: Player, slot: number): ()
Combustivel.aoDespejar(jogador: Player, modelo: Model): ()   -- chamado pelo prompt da Tampa (S3 conecta o Triggered de todas as Tampas; S2 só cria a peça e o prompt)
Combustivel.iniciar(): ()
```
O prompt da Tampa é criado por S2 em `VeiculoModelo` (`Name = "Abastecer"`); **S3 conecta o `Triggered`** observando `Tampa` nova via `CollectionService` tag `"Tampa"` (S2 marca com `CollectionService:AddTag(tampa, "Tampa")`, a Tampa tem o atributo `CarroModelo`? não: S3 acha o carro por `tampa:FindFirstAncestorOfClass("Model")`).

Atributos de Player (S3 escreve; S4/S5 leem): `Mangueira` (bool), `RecipienteSlot` (number?).
Atributos do carro (S2 escreve; S4/S5 leem): `Tanque`, `Combustivel`, `SemCombustivel`, `Abastecendo`.
Instâncias (S3 escreve; S5 lê): `workspace.Mangueiras/<UserId>` (§5.1).

## 11. Verificação (o que o Opus confere depois)

1. 4 checagens verdes (`pwsh scripts/checar.ps1`).
2. Testes: consumo (parado < máx, máx na velMax), `consumir` não vai abaixo de 0, `encher` (sobra), `trocar` (cabe/não cabe, sem meia troca), `podeLigar`, sorteio de combustível (vazio ocasional, nunca acima do tanque), todos os itens novos têm `Config/Combustivel.recipientes` e vice-versa.
3. Studio (MCP): invocar carro cheio/meio/vazio; vazio não liga; ligado consome e desliga em 0; HUD (1ª e 3ª pessoa) e agulha mostram; etiqueta aparece perto da tampa; pegar mangueira na bomba, plugar na tampa (motor desligado), nível sobe, enche e para, desplugar; afastar > 16,5 studs solta;
   encher galão e garrafa na bomba (inventário), despejar no carro; dois jogadores em um carro (multiplayer simulado com 2 clientes no Studio), trocar de banco, motorista sai com passageiro.
4. Console sem erro de script. Nenhuma `Instance.new` por quadro no cliente da mangueira.
