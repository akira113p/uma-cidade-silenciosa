# Itens no mundo: modelo de blocos, mão, chão e coleta

Contrato escrito em 2026-11-05 (decisões em `docs/decisoes.md`). 4 partes escritas em paralelo (A, B, C, D). Nada aqui é "física do Roblox":
**o item no chão é sempre `Anchored`**; o arremesso é uma simulação balística nossa, com raycast, animada por `PivotTo`. Motivo: zero custo de
simulação com centenas de itens, sem network ownership, sem CollisionGroup, sem item empurrando jogador, resultado testável em Lune.

## 1. O que existe hoje (medido, 2026-11-05)
- Arma na mão: 1 Part `ArmaNaMao` soldada à `RightHand` pelo servidor (`src/server/Armas.luau` ~l.36-50 tabela VISUAL, ~l.131-146). Lanterna: só luz no cliente, sem corpo.
- Largar: botão no Tab → `LargarItem(slot)` → `Inventario.largar` cria uma Part "Bolsa" marrom 2×1×1,5 com ProximityPrompt. Morte: tudo numa bolsa.
- Loot: móveis (`Loot.luau`, 3.191 com atributo `Movel`). Os **880 pontos Loot** (`workspace.Mapa.Pontos`, Part 1×1×1 com atributos `Tabela` e `Zona`) existem e **ninguém os lê**.
- Chão: topo do `Chao` 0,5; interior da cidade `BaseY` 1,10; ponto Loot de andar = topo do piso + 0,5; de rua Y 1,6–1,8.
- Sem CollisionGroup em mapa/personagem/monstro. Backpack do Roblox desligada. Armas pesa `workspace.Mapa.Pontos` e `Zonas` fora do raycast.

## 2. Convenção do modelo (vale para A, C e D)
Cada item de `Config/Itens.itens` tem um modelo em `Config/ItensModelos.modelos[id]`, em **dados puros** (números e strings, sem `Vector3`/`Enum`, para o Lune testar):
```lua
modelos[id] = {
  partes = {   -- ordem importa: a primeira é a PrimaryPart (raiz)
    { nome = "Corpo", forma = "Block"|"Cylinder"|"Ball"|"Wedge",
      tam = {x,y,z},          -- studs (para Cylinder: x = comprimento ao longo do eixo X do Roblox; ver nota)
      pos = {x,y,z}, rot = {rx,ry,rz},   -- relativo à origem do modelo; rot em GRAUS, mesma ordem de `CFrame.Angles(rx, ry, rz)` (fromEulerAnglesXYZ)
      cor = {r,g,b},          -- 0-255, paleta fria e dessaturada; acento vermelho só em kit/lata/refrigerante
      material = "Plastic"|"SmoothPlastic"|"Metal"|"Fabric"|"Wood"|"Glass"|"Neon"|"Cardboard",
      transp = 0.x?, },
  },
  mao   = { pos = {x,y,z}, rot = {rx,ry,rz} },  -- CFrame da origem do modelo relativo à mão (RightHand; LeftHand se lado = "esquerda")
  lado  = "direita" | "esquerda",               -- padrão "direita"; lanterna = "esquerda"
  chao  = { rot = {rx,ry,rz} },                 -- rotação para o item DEITAR no chão (a altura de repouso sai da caixa depois de girar)
  escalaChao = 1.0,                             -- opcional: aumenta item pequeno só no chão para dar para ver
}
```
- **Origem do modelo** = onde a mão segura (cabo da faca/machado/pistola, meio da lata, corpo da lanterna). **+Y = cima do objeto, −Z = frente/ponta** (cano, ponta da lâmina, lente).
- Orientação inicial na mão: manter o que `ArmaNaMao` faz hoje (comprimento ao longo do eixo Y da mão, ponta para fora do braço). O Opus afina por screenshot depois.
- Nota Cylinder do Roblox: o eixo do cilindro é o X da peça; para um cilindro "de pé" use `rot = {0,0,90}`. O construtor não corrige isso; o dado já deve vir certo.
- Tamanhos de referência (studs, 3 studs ≈ 1 m, mão do R15 ≈ 0,4): enlatado Ø0,5×0,7 · barra 0,9×0,15×0,45 · garrafa Ø0,45×1,3 · refrigerante Ø0,45×0,8 · bandagem rolo Ø0,5×0,35 ·
  kit 1,1×0,4×0,8 · faca 1,2 de comprimento · pé de cabra 2,2 · machado 2,4 · pistola 0,9×0,5×0,2 · caixa de munição 0,6×0,4×0,3 · lanterna Ø0,5×1,3.
  Cada modelo tem entre 2 e 6 partes (o objetivo é "bem simples": silhueta reconhecível e uma cor de acento). Nenhuma peça menor que 0,08 de lado.
- Modelo montado = `Model` com `PrimaryPart`, atributo `Item = id`, nome `Item_<id>`. Todas as Parts: `CanCollide=false, CanQuery=false, CanTouch=false, CastShadow=false`.
  Modo `"chao"`: todas `Anchored=true`, `Model.ModelStreamingMode = Atomic`. Modo `"mao"`: `Anchored=false, Massless=true`, peças presas à raiz por `WeldConstraint`; a raiz presa à mão por `ItemModelo.prenderNaMao`.

## 3. Partes e donos (um arquivo = um dono; ninguém edita arquivo de outro)

### A. Modelos (shared)
Arquivos: `src/shared/Config/ItensModelos.luau`, `src/shared/Regras/ItemModelo.luau`, `src/shared/ItemModelo.luau`, `tests/ItemModelo.spec.luau`.
```lua
-- Regras/ItemModelo.luau  (puro, sem Instance)
validar(modelo): (boolean, string?)                 -- partes ≥1, formas/materiais válidos, tam > 0, rot em graus, cor 0..255
caixa(modelo, rot: {number}?): { min: {x,y,z}, max: {x,y,z} }   -- caixa alinhada aos eixos de TODAS as partes depois de girar por `rot` (rotação de cada parte e depois do conjunto, graus, ordem de `CFrame.Angles`)
repouso(modelo): { rot: {x,y,z}, altura: number }   -- rot = modelo.chao.rot; altura = -min.y da caixa girada × escalaChao (distância da origem até o ponto mais baixo)
-- ItemModelo.luau  (usa Instance; roda em servidor e cliente)
criar(id: string, modo: "chao" | "mao"): Model      -- erro claro se id sem modelo; modelo montado conforme §2
repouso(id): { giro: CFrame, altura: number }       -- versão com CFrame de Regras.repouso
prenderNaMao(modelo: Model, personagem: Model, id: string): boolean   -- acha RightHand/LeftHand (R15) conforme `lado`, posiciona raiz = mão.CFrame * mao, cria o WeldConstraint; false se não há mão (R6)
```
`tests/ItemModelo.spec.luau`: todo `id` de `Config/Itens.itens` tem modelo válido; `repouso.altura > 0`; caixa de um bloco conhecido gira certo (cubo 1×2×1 girado 90° em X → altura 0,5 → …); tamanho máximo de qualquer modelo ≤ 3,0 em qualquer eixo.

### B. Regras puras e números do chão (shared)
Arquivos: `src/shared/Config/ItensChao.luau`, `src/shared/Regras/Arremesso.luau`, `src/shared/Regras/ItensChao.luau`, `tests/Arremesso.spec.luau`, `tests/ItensChao.spec.luau`.
```lua
-- Config/ItensChao.luau (PROVISÓRIO; números todos aqui)
chanceSpawn = 0.35            -- por ponto Loot
alcance = 8                   -- usa Itens.alcanceInteracao como fonte; aqui só a mira:
raioMira = 1.4                -- studs: distância máxima do item ao raio da mira
maxItens = 600                -- itens vivos em workspace.ItensChao; passando disso, some o largado mais antigo
largadoDuracao = 600          -- s até item largado/de morte sumir (= Itens.bolsaDuracao; ler de lá em vez de repetir)
reposicao = 900               -- s para o ponto sortear de novo depois de pego (= Itens.reposicao)
alturaCastPonto = 3           -- studs: raio para baixo a partir do ponto Loot para achar o piso
arremesso = { frente = 12, cima = 6, giroMax = 8, passo = 1/30, maxPassos = 90, restituicao = 0 }  -- studs/s, rad/s
espalhar  = { raioMin = 1.5, raioMax = 4, cima = 7 }              -- morte: velocidade horizontal ≈ raio × 2

-- Regras/Arremesso.luau
simular(origem: Vector3, velocidade: Vector3, gravidade: number, passo: number, maxPassos: number,
        raio: (a: Vector3, b: Vector3) -> (Vector3?, Vector3?)) -> { pontos: {Vector3}, repouso: Vector3, normal: Vector3, tocouChao: boolean }
-- Integra v += g·dt; cada passo lança `raio(p, p')`. Acerto com normal.Y ≥ 0.7 (chão) para ali. Parede/teto: zera a componente da velocidade na normal, ×0,3 no resto, continua de
-- acerto + normal×0.05. Sem acerto em maxPassos: `tocouChao=false` e `repouso` = último ponto.
-- Regras/ItensChao.luau
sortearPonto(tabela, rng, chance): { id: string, qtd: number }?   -- chance → senão nil; depois Regras/Loot.sortear(tabela, rng) e fica com a 1ª entrada
velocidadesEspalhar(n: number, rng, cfg): { Vector3 }              -- n velocidades em leque (ângulos uniformes + jitter), sem sobrepor
removerExcedente(itens: { { t: number, id: any } }, max: number): { any }    -- ids a remover: mais antigos primeiro (só `largado`), devolve lista
```
Testes determinísticos (`util.seq`/`util.rng`): queda reta num piso falso (`raio` que devolve acerto em y=0), parede, teto, sem chão, `chance` 0 e 1, n=1/4/8 velocidades distintas, excedente.

### C. Servidor: itens soltos, largar, morte, coleta
Arquivos: `src/server/ItensChao.luau` (novo), `src/server/Inventario.luau`, `src/server/Loot.luau`, `src/server/MonstroMovimento.luau`, `src/server/init.server.luau` (ORDEM: `"ItensChao"` logo depois de `"Inventario"`, antes de `"Spawn"`; precisa de `Mapa`, então o sorteio dos pontos espera `workspace.Mapa` até 15 s, como o Loot), `src/shared/Rede.luau` (só adicionar o evento abaixo).
```lua
-- Rede.luau: "PegarDoChao" -- (item: Instance)  c→s   ItensChao
-- ItensChao (servidor)
ItensChao.largar(jogador: Player, id: string, qtd: number): ()               -- chamado por Inventario.largar; arremessa a partir de hrp + (0,1.2,0) + look*1.5
ItensChao.espalhar(posicao: Vector3, itens: { {id: string, qtd: number} }): ()  -- morte; um item por entrada, em leque (velocidadesEspalhar)
ItensChao.criarEm(posicao: Vector3, id: string, qtd: number, opcoes: { largado: boolean?, ponto: Instance? }?): Model?  -- sem arremesso: assenta no chão achado por raycast para baixo
ItensChao.contar(): number
ItensChao.iniciar(): ()
```
- Contêiner: `workspace.ItensChao` (Folder). Cada item: Model de `ItemModelo.criar(id, "chao")`, atributos `Item` (id), `Qtd`, `Largado` (bool); `CollectionService` tag `"ItemChao"`. Posição final: raycast para baixo (Exclude: personagens, `Monstros`, `ItensChao`, `Mapa.Pontos`, `Mapa.Zonas`, `Mapa.Vegetacao`) → `CFrame.new(chao + Y·altura) * giro(chao) * Angles(0, yawAleatório, 0)`. Sem chão em 30 studs: some (descarta e avisa no output).
- **Arremesso**: `Arremesso.simular` com `raio` = `workspace:Raycast(a, b-a, params)`; animar por `RunService.Heartbeat` com `PivotTo` do modelo anchored seguindo `pontos` (dt acumulado, pulando por `passo`) + giro em torno de um eixo aleatório; ao fim, cai para a pose de repouso. O modelo existe e é visível desde o primeiro passo.
- **Pontos Loot**: na partida, varre `workspace.Mapa.Pontos` filhos com atributo `Tabela` válida em `Itens.tabelas` (os `Spawn` e `Monstro` não têm `Tabela`: ignorar). Para cada um: `sortearPonto(tabela, rng, chanceSpawn)`; se sair, cria o item no piso achado por raycast de `ponto.Position` para baixo (`alturaCastPonto`; sem acerto usa a própria posição). Cede o servidor a cada ~100 pontos (`task.wait()`). Imprime `[ItensChao] N itens em M pontos`. Item de ponto, depois de pego, agenda `reposicao` s e sorteia de novo (se não sair, tenta de novo em outro `reposicao`).
- **Largar/morte**: o `Inventario.largar` deixa de criar bolsa e chama `ItensChao.largar` (não é mais função local; o item inteiro do slot vai junto com `qtd`). `aoMorrer` chama `ItensChao.espalhar(posicao, Regras.lista(inv))`. Item `Largado=true` some em `largadoDuracao`; passou de `maxItens` vivos, remove os largados mais antigos (`removerExcedente`); item de ponto nunca é removido por limite.
- **Coleta (`PegarDoChao`)**: valida instância dentro de `workspace.ItensChao` com atributo `Item`, jogador vivo, distância do `HumanoidRootPart` à raiz do item ≤ `Itens.alcanceInteracao * 1.25`, `Limite.ok(jogador, "PegarDoChao", 0.15)`. `n = min(Qtd, Inventario.espaco(jogador, id))`; `n < 1` → `Aviso` "Inventário cheio". `Inventario.dar`; se sobrar, `Qtd` do modelo cai; senão destrói e (se de ponto) agenda reposição. Som: `Sons.tocar("AbrirCaixa", raiz)` (som provisório; decisão de som novo em pendências). **Sem ruído de pegar/largar** por enquanto (decisão de design pendente, anotar).
- **Remover a bolsa**: apagar `criarBolsa`, `pastaBolsas`, `bolsas`, `conteudoBolsa`, `retirarDaBolsa`, `destruirBolsa` do `Inventario`; em `Loot.luau` o ramo de bolsa de `conteudoDe`/`pegar`/`acessivel` passa a só existir para compartimentos (nenhum outro módulo chama as funções removidas: conferir com Grep); `chaoSob` do Inventario some ou vira helper de `ItensChao`. Trocar a referência a `"Bolsas"` por `"ItensChao"` em `MonstroMovimento.luau`. (`Armas.luau` é do D.)
- Comandos de teste (`Teste.registrar`): `chao` (conta itens e quantos de ponto/largado), `soltar <id> [qtd]` (cria um à frente do jogador), `limparchao`.

### D. Servidor: item na mão; cliente: mira e coleta
Arquivos: `src/server/ItemNaMao.luau` (novo), `src/server/Armas.luau`, `src/server/Lanterna.luau`, `src/client/ItensChaoCliente.luau` (novo), `src/client/init.client.luau` (só iniciar o módulo), `src/server/init.server.luau` **não**: o `ItemNaMao` é carregado sob demanda por quem o usa, como os outros serviços.
```lua
-- ItemNaMao (servidor)  -- dono do modelo na mão; um modelo por (jogador, mão)
ItemNaMao.definir(jogador: Player, fonte: "arma" | "lanterna" | "uso", id: string?): ()   -- id nil limpa a fonte
-- Prioridade por mão: "uso" (comer/beber/curar, mão direita) > "arma" (direita) ; "lanterna" na esquerda. Quando "uso" termina, a arma volta.
ItemNaMao.limpar(jogador: Player): ()    -- morte/respawn/saída
```
- `Armas.luau`: no lugar do bloco `ArmaNaMao`, chama `ItemNaMao.definir(jogador, "arma", idDoItem)` e `definir(jogador, "arma", nil)` ao desequipar; some a tabela VISUAL. **O `id` é o do `Config/Itens` (não o da arma)**: achar pelo slot equipado. Trocar `"Bolsas"` por `"ItensChao"` em `Armas.parametros`. Nada na lógica de dano muda.
- `Lanterna.luau`: ao equipar/desequipar o slot (`LanternaSlot`), chama `ItemNaMao.definir(jogador, "lanterna", "lanterna")`/`nil` (modelo na mão esquerda; a luz continua do cliente).
- **Uso**: `Inventario.luau` é do C. Contrato: C chama `ItemNaMao.definir(jogador, "uso", id)` ao começar o uso e `definir(jogador, "uso", nil)` ao terminar/cancelar/morrer (via `servico("ItemNaMao")`, falhar em silêncio se indisponível). D só entrega o módulo.
- Respawn/morte: limpar tudo (`CharacterRemoving`/`Vida.aoMorrer`). Personagem R6/sem mão: nada a mostrar, sem erro.
- `ItensChaoCliente` (cliente): a 10 Hz acha, entre os modelos com a tag `"ItemChao"` (`CollectionService`: `GetInstanceAddedSignal` para streaming), o melhor candidato: distância do `Head` ≤ `Itens.alcanceInteracao`, distância do item ao raio da câmera ≤ `raioMira`, mais perto da mira vence. Sobre o candidato: **um** `Highlight` (preenchimento transparente, contorno claro, `DepthMode AlwaysOnTop`; reusar a mesma instância trocando `Adornee`) e **um** `BillboardGui` (`TextLabel`: nome de `Config/Itens` + `x<Qtd>` se >1, e `[E]`; fonte do HUD do jogo). Tecla `E` (ver `client/Teclas.luau` e `Config/Movimento`: usar o padrão de teclas do projeto, nunca ler `E` solto se já houver mapa) → `Rede.evento("PegarDoChao"):FireServer(modelo)`. No celular: o rótulo é botão que pega. Não pega com Tab aberto nem dentro de carro. Sem varredura por frame: 10 Hz sobre a lista da tag (só os itens streamados, ≤ ~150 por vez), comparando por `magnitude`.

## 4. Fora do escopo (pendências para o usuário decidir, ver `pendencias-integracao.md`)
Ruído de pegar/largar; som próprio de pegar/largar/cair; item que quebra ao cair; empilhar visual (vários modelos para `Qtd` alto); tecla de largar na mão; armas com durabilidade; pente de munição visível.

## 5. Verificação (Opus, depois das 4 partes)
1. `pwsh scripts/checar.ps1` verde (rojo build, Lune, selene, stylua).
2. Studio pelo MCP: fila com os 12 modelos no chão + 12 na mão (screenshots), conferir silhueta, escala e pose na mão em primeira e terceira pessoa.
3. `soltar`, Largar pelo Tab, pegar com E; morrer com 8 itens e ver o leque; cheio → aviso; sem erro no console.
4. `chao` mostra ~300 itens de ponto; FPS no Studio sem queda perceptível; item largado some em 10 min (acelerar com Config no teste).

## 6. Estado (2026-11-05, depois da integração)
`pwsh scripts/checar.ps1` verde (20 suítes). 4 partes escritas por Sonnet (A modelos, B regras, C servidor do chão, D mão + cliente), integradas pelo Opus. Divergências do contrato, já no código:
- **Vetores de `Regras/Arremesso` e `Regras/ItensChao` são tabelas `{x,y,z}`**, não `Vector3` (nenhuma Regra do projeto usa Vector3); `server/ItensChao` converte na chamada. `Regras/ItemModelo` usa arrays `{x,y,z}`.
- **27 itens, não 12**: `Config/ItensModelos` tem modelo para todo id de `Config/Itens` (o teste exige). Fuzis, escopetas, lança-foguetes, munições e recipientes de gasolina entraram depois do contrato.
- **Armas** (decisão 2026-11-05): na mão e no chão usam o `ArmaModelo` (malha real, ou o bloco provisório dele). `ItemModelo.criar(id, "chao")` e `repouso(id)` devolvem o `ArmaModelo` deitado (giro Z 90°) quando o item é `tipo = "arma"`; os blocos de `ItensModelos` valem para armas só como reserva. Na mão, `Armas.luau` mantém o `ArmaModelo`; o `ItemNaMao` só entra como reserva.
- **`pente`**: arma de fogo largada/espalhada/de ponto guarda o pente (atributo `Pente`) e o devolve ao pegar (`Inventario.dar(jogador, id, qtd, pente)`).
- Yaw aleatório do pouso gira em torno do eixo vertical do mundo (`CFrame.Angles(0, yaw, 0) * giro`).
- `ItemNaMao` (nome do modelo): `"ArmaNaMao"` quando vem da arma (o viewmodel esconde do dono), `"ItemNaMao"` nos outros. O recipiente de combustível já usa `ItemNaMao.definir(jogador, "uso", id)`.
- Tecla E do cliente: `ContextActionService` com `Pass` (não `Teclas.ligar`, que daria `Sink` e engoliria o E de fechar caixa e dos ProximityPrompt).
Testado no Studio (place montado, script de autoteste temporário, sem erro no console): 328 itens em 880 pontos (37%); 27 modelos criados sem erro; item de uso e lanterna aparecem na mão; largar → pousa ancorado no chão com `Qtd`; `PegarDoChao` do cliente → o servidor entrega; morte com 8 itens → 8 no chão; cliente destaca (Highlight) o item certo ao mirar. Medidas: nenhum modelo passa de 3,1 studs.

## 7. Pendências (não decididas ou não vistas)
- **Não visto por imagem:** o texto do rótulo `[E]` (o `screen_capture` não mostrou o BillboardGui; os dados dizem Enabled e na tela); a pose do item na mão em 1ª e 3ª pessoa; escala/cor dos modelos no chão do mapa com a névoa do filtro. Conferir jogando.
- **Uso (comer/curar) com arma equipada:** o `ItemNaMao` desenha o item por cima do `ArmaNaMao` (a arma não some durante o uso). Esconder o `ArmaNaMao` enquanto `Usando` for true.
- **Lanterna na mão esquerda em 1ª pessoa:** o viewmodel só esconde nomes `ArmaNaMao`; o modelo `ItemNaMao` pode aparecer para o dono.
- Sem linha de visada na coleta: dá para destacar e pegar item atrás de parede fina a até 8 studs.
- **Decisões de design em aberto (perguntar):** ruído e som de pegar/largar (hoje sem ruído; som provisório `AbrirCaixa`); `Qtd` alto com um modelo só; tecla de largar na mão; item que quebra ao cair.
- `client/InventarioUI.luau:693` ainda testa o atributo `Bolsa` (código morto; a bolsa não existe mais).
- Item de ponto removido por `limparchao` não agenda reposição (só o pego pelo jogador agenda).
- O raycast do chão guarda a lista de exclusões por 1 s: personagem recém-nascido pode ficar fora dela nesse intervalo.
- `docs/arquitetura.md` §5 ainda descreve a bolsa (`workspace.Bolsas`) e `workspace.Caixas`: desatualizado; vale este documento.
- **Ferramenta de teste:** neste Studio o `execute_luau` não dá `require` nos módulos do jogo nem cria Script (erro de Capabilities/Network). Para testar runtime: `rojo build` de um projeto temporário (cópia de `build.project.json` com `../` nos caminhos e um Script/LocalScript de autoteste que imprime `[TESTE] ...`), abrir o .rbxl, Play e ler o console; apagar tudo depois.
