# Personagens, seletor e animações do corpo (contrato)

Pedido do usuário (2026-11-05): ao entrar no jogo o jogador escolhe um personagem; **não muda atributos** (todos no tamanho do
personagem atual, que será substituído); as animações que faltam são criadas **a partir das que já existem**, para o jogo todo
(carros, segurando armas, itens, braços em 1ª pessoa). Personagens vêm de `modelos 3d/` e `C:\Users\cerfr\Downloads\psx sttuff`.

Escrito por agentes Sonnet a partir deste documento; revisão e integração pelo Opus/Sonnet principal. Nenhuma parte usa o MCP do Studio
(regra 6 do CLAUDE.md: esta sessão não é dona do Studio) e **nada é enviado ao Roblox** (Open Cloud está com 403 "User is moderated").

## 0. Decisões tomadas aqui (registrar em docs/decisoes.md)
1. **Todos os personagens têm o mesmo corpo físico**: o R15 atual, escalado por `Config/Aparencia.escala` (≈ 5,234 studs). Peças R15 originais
   continuam sendo física, hitbox (nomes e `CanQuery` intactos) e junta de animação, e ficam `Transparency = 1`. O visual de cada personagem é
   **uma peça visual soldada em cada uma das 15 peças R15**, chamada `"Bloco"` (como hoje). Muda só a aparência; nenhum atributo (vida, velocidade, dano).
2. Visual de um personagem = `"bloco"` (Parts coloridas por paleta, funciona sem upload) **ou** `"malhas"` (15 MeshParts, uma por peça R15, com
   `MeshId`/`TextureID` vindos de `Config/PersonagensMalhas`). Sem malha enviada, o personagem cai no visual `"bloco"` com a paleta dele. Assim o
   seletor funciona hoje, e quando as malhas puderem ser enviadas basta preencher o config gerado.
3. O personagem atual (suéter amarelo, tranças douradas) vira o personagem `padrao`, o primeiro da lista. Não é apagado.
4. **Animações não dependem de upload.** Um clipe é dado (JSON, igual ao de `assets/animacoes/armas/`), o jogo monta a `KeyframeSequence` em runtime e
   a registra com `KeyframeSequenceProvider:RegisterKeyframeSequence`. Cada cliente toca no Animator de **todos** os personagens que vê (o que o
   servidor/outros não podem carregar sem id publicado). Se `Config/ArmasAnim` ou o config novo trouxer um id publicado, vale o id. **A confirmar no
   Studio pela dona do Studio:** que `LoadAnimation` aceita o id registrado em runtime no cliente e que o clipe aparece nos dois lados.
5. **Braços em 1ª pessoa** passam a ser um rig R15 mínimo (só tronco superior e braços), preso à câmera, tocando **os mesmos clipes** da 3ª pessoa.
   As molas de coice e a mira continuam por cima, como ajuste procedural. O IK analítico/poses de `ArmasVista` ficam como reserva quando um clipe não existe.
6. Escolha persiste (`Pref_Personagem`, número) e vale em toda vida. O seletor abre ao entrar e também pela tela de morte ("Trocar personagem").

## 1. Elenco
`src/shared/Config/Personagens.luau` (dado puro). Cada entrada: `id` (string estável), `n` (número estável, usado na persistência e na rede), `nome`,
`descricao` (1 linha), `visual` ("bloco"|"malhas"), `paleta` (cores, mesmas chaves de `Config/Aparencia.cores`; só as que mudam), `fonte`
(caminho/licença/crédito), `ordem`. Elenco inicial (revisar após a medição dos candidatos no Blender):

| n | id | Origem | Licença |
|---|---|---|---|
| 1 | padrao | bloco atual (Config/Aparencia) | do projeto |
| 2 | office_worker | psx-people-free `office_worker.fbx` | CC BY 4.0 (heyheythere) |
| 3 | survivor_woman | psx-people-free `survivor_woman.fbx` | CC BY 4.0 (heyheythere) |
| 4+ | (villager_man, villager_woman, male_casual, ps1_character) | `psx sttuff\3-personagens` | **sem licença na pasta; só entram se o usuário confirmar origem** |

Crédito obrigatório dos CC BY 4.0: tela de créditos/rodapé do seletor com "PSX People Free by heyheythere – heyheythere.itch.io/psx-people-free – CC BY 4.0".

## 2. Peças (quem escreve o quê)

### Parte S — seletor (Sonnet "S")
Dono: `src/shared/Config/Personagens.luau`, `src/shared/Regras/Personagens.luau` (+ teste Lune em `tests/`), `src/shared/PersonagemVisual.luau`,
`src/server/Personagem.luau`, `src/server/Aparencia.luau` (refatorar), `src/client/SeletorPersonagem.luau`, `src/client/Aparencia.luau` (se preciso), `src/shared/Rede.luau`
(eventos novos), `src/server/Preferencias.luau` (+ `Config/Camera.luau` limites de `Pref_Personagem`), `src/server/init.server.luau`, `src/client/init.client.luau`,
`default.project.json` (**só** `CharacterAutoLoads = false`), `src/client/HudVida.luau` (**só** o botão "Trocar personagem" na tela de morte), `docs/personagens.md` (seção Estado).

Fluxo:
- `CharacterAutoLoads = false`. O servidor (`Personagem.luau`) só chama `jogador:LoadCharacter()` quando há escolha. Respawn: no `Humanoid.Died`,
  espera `Players.RespawnTime` e chama `LoadCharacter` (a não ser que o jogador esteja no seletor). Antes do primeiro `LoadCharacter`, `Spawn` já deixou
  `RespawnLocation` pronto (registra no `PlayerAdded`); conferir a ordem de inicialização (`init.server.luau`).
- Entrada: cliente mostra o seletor assim que as preferências carregam (esperar o atributo `PrefCarregadas` ou equivalente; criar se não existir) e
  pede `EscolherPersonagem(n)`. Servidor valida (`n` número inteiro existente, `Limite.ok`, jogador sem personagem vivo OU Morto), grava
  `jogador:SetAttribute("PersonagemId", id)` e `Pref_Personagem = n`, e chama `LoadCharacter`.
- Se a escolha salva é inválida ou o jogador não tem preferência: seletor abre com `padrao` marcado.
- Rede (novos, em `Rede.EVENTOS`, com comentário de contrato): `EscolherPersonagem` (C→S, número), `AbrirSeletor` (S→C, aberto pela morte/trocar não precisa: o cliente já sabe), `PersonagemEscolhido` (S→C, confirmação ou recusa com texto).
- Visual: `Aparencia.aplicar` lê `jogador:GetAttribute("PersonagemId")` e delega a `PersonagemVisual`. O atributo também vai no `Character` (`personagem:SetAttribute("PersonagemId", id)`),
  pois o cliente de OUTROS jogadores e o viewmodel precisam saber.
- UI: **código puro** (`Instance.new`, `criar` próprio), um `ScreenGui` com `Mouse.pedir("Seletor")`/`liberar` (ver `src/client/Mouse.luau`). Lista/grade de cartões com nome, descrição e uma **prévia 3D** num
  `ViewportFrame` (clone do R15 do avatar do jogador revestido com o visual do personagem, girando devagar; fallback para só a silhueta/cores se falhar). Botão Confirmar; teclado/gamepad funcionam; texto ≥ 14 px; funciona em 4:3 e em celular. Estética: PS1/Silent Hill, escura, fria, sem emoji.
- `PersonagemVisual` (shared, **funciona no cliente também**): `criarParte(id, nomeParteR15, original): BasePart` devolve a peça visual (`Part` ou `MeshPart`) já com tamanho, cor/textura e sem física,
  e `detalhes(id, nomeParteR15, parte)` põe os acessórios do visual (rosto, cabelo, suéter, tênis do `padrao`; o cabelo/cabeça com a etiqueta `Config/Aparencia.etiquetaCabeca`).
  O viewmodel (parte A2) usa `criarParte` só para braços/mãos. O código de `padrao` hoje em `server/Aparencia.luau` migra para cá sem mudar o resultado.
- Persistência: `Pref_Personagem` numérico em `Config/Camera.limitesPreferencias`; `Preferencias.validar` continua só aceitando booleano/número.

### Parte M — malhas dos personagens (Sonnet "M")
Dono: `ferramentas/modelos/personagem_psx.py` (Blender headless), `ferramentas/modelos/gerar_config_personagens.py`, `src/shared/Config/PersonagensMalhas.luau` (gerado, começa com `false`),
`modelos 3d/personagens/<id>/...` (saídas), `docs/personagens.md` (seção "Malhas").
Entrada: FBX de psx-people-free (e os demais só se tiverem rig utilizável e o usuário liberar a licença). Saída por personagem: **um FBX com 15 malhas**, nomeadas exatamente como as peças R15
(`Head, UpperTorso, LowerTorso, LeftUpperArm, LeftLowerArm, LeftHand, RightUpperArm, RightLowerArm, RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, RightUpperLeg, RightLowerLeg, RightFoot`),
em pose T/A, cada uma com a origem no centro da própria caixa (o MeshPart do Roblox fica centrado na caixa), textura atlas ≤ 256 px, ≤ 1000 tris por peça, sem animação, até 4 influências irrelevantes (sem pele: o peso decide só a divisão
das malhas). A divisão é por osso dominante do vértice → peça R15 (`Hips→LowerTorso`, `Spine/Chest→UpperTorso`, `Head/Neck→Head`, braço/antebraço/mão e coxa/canela/pé por lado). Um manifesto JSON por personagem lista as peças, tris e o tamanho nativo de cada uma.
O Lua estica cada malha para `original.Size` (o corpo continua o R15 atual, a malha só preenche o espaço). **Não enviar nada**: com o 403 ativo o script de envio fica documentado, mas não é executado; `PersonagensMalhas.luau` guarda `modelo`/`textura` como `false` até lá.

### Parte A1 — animações em runtime e clipes que faltam (Sonnet "A1")
Dono: `src/shared/Animacao.luau`, `src/shared/Regras/Animacao.luau` (+ teste), `src/shared/Config/AnimacoesCorpo.luau`, `assets/animacoes/corpo/*.json`, `src/client/AnimacaoCorpo.luau`, `src/client/ArmasTerceira.luau` (trocar a origem do clipe), `ferramentas/animacao/` (validador/folha de quadros em Lune), mapeamento em `default.project.json` (**só** a entrada que expõe `assets/animacoes` como módulos; usar Edit, não reescrever o arquivo), `docs/personagens.md` (seção "Animações").

API (contrato com A2):
```
Animacao.carregarDados(grupo: string): Dados            -- ex.: "armas/pistola", "corpo/carro"; dado já decodificado do .json (ModuleScript via Rojo)
Animacao.sequencia(grupo, clipe): KeyframeSequence      -- monta como ferramentas/animacao/montar_armas.luau (mesma tabela junta→peça, easing, marcadores)
Animacao.id(grupo, clipe): string?                      -- id publicado (config) se existir; senão RegisterKeyframeSequence (cache); nil se o clipe não existe
Animacao.trilha(animator: Animator, grupo, clipe, opcoes?): AnimationTrack?   -- LoadAnimation com cache por (animator, grupo, clipe); prioridade/loop vêm do dado
Animacao.duracao(grupo, clipe): number
```
Tudo tolerante: dado ausente/clipe inexistente = `nil` com um `warn` único, nunca erro. Regras puras (resolver `de` + `juntas`, ordenar quadros, validar) em `Regras/Animacao` com teste Lune; o código que cria Instances fica fora do teste.
`ArmasTerceira` passa a usar `Animacao.trilha` (id publicado de `ArmasAnim` se houver, senão registrado), e passa a tocar também nos **outros** personagens (cada cliente toca os clipes no Animator dos outros; o estado vem de atributos do Character que o servidor já tem ou ganha: arma equipada/classe, ação, mira). Não quebrar o IKControl nem a camada de mira.

Clipes novos (formato idêntico ao de armas, feitos a partir das poses e durações dos existentes; cada um com Idle/transições curtas, nada que mude hitbox):
| Grupo | Clipes | Notas |
|---|---|---|
| `corpo/carro` | `MotoristaIdle` (mãos no volante, loop), `MotoristaVira` esquerda/direita (opcional), `PassageiroIdle` (mãos no colo), `Entrar`, `Sair` | prioridade Action; só braços/tronco superior; pernas ficam na pose de sentar do motor |
| `corpo/mundo` | `Pegar` (agacha e alcança o chão, marcador `Pegou`), `Largar`/`Arremessar`, `Interagir` (alcança à frente: abrir porta/caixa/prompt), `Abastecer` (segura a mangueira) | |
| `corpo/mao` | `SegurarUmaMao` (Idle, lanterna/garrafa/galão/comida), `SegurarGalao`, `Usar` (beber/comer) | para `ItemNaMao`, não armas |
| `corpo/vida` | `Morte` (cai pra trás), `Queda`/`Aterrissagem` leve | Morte com prioridade Action4, toca no `Died`, congela no último quadro |
| `corpo/movimento` | `AgacharIdle` (se for útil sem quebrar o C0 procedural do servidor) | **só se** não conflitar com `Movimento.luau`; senão deixar procedural e registrar |
`AnimacaoCorpo` (cliente) liga cada clipe a seu gatilho (estado do Humanoid, `SeatPart`, atributos/eventos já existentes como `Rede` `Inventario`/`SairCarro`); proibido inventar evento de rede novo sem declarar em `Rede.EVENTOS` (e então avisar o dono da Parte S).
Validação: um script Lune confere toda junta/peça, `duracao == último quadro`, limites de ângulo plausíveis (ombro, cotovelo, joelho) e gera uma folha de quadros em texto (ângulos por tempo) para a revisão. Os clipes não podem ser vistos no Studio por esta sessão: revisão por números + cinemática direta com `ferramentas/animacao/bancada.luau` quando a dona do Studio puder rodar.

### Parte A2 — braços em 1ª pessoa com os clipes (Sonnet "A2")
Dono: `src/client/ArmasViewmodel.luau` (refatorar), `src/client/BracosViewmodel.luau` (novo, rig mínimo), `src/shared/Config/ArmasVista.luau` (reserva e ajustes), `docs/personagens.md` (seção "Primeira pessoa").
- Rig mínimo local: `Model` filho de `CurrentCamera` com `UpperTorso`(invisível, âncora do rig), `LeftUpperArm/LeftLowerArm/LeftHand`, `RightUpperArm/LowerArm/Hand` ligados por `Motor6D` com as mesmas `C0/C1` do R15 (copiar do personagem real), um `Animator` e a arma (`ArmaNaMao`/`ArmaModelo`) presa à `RightHand` como hoje (`JuntaArma`, `Config/ArmasAnim.mao`).
  A cada `RenderStepped` o rig é posicionado em `CFrame da câmera * offset` (offset configurável em `Config/ArmasVista`), e as molas de coice/balanço (Regras/Mola) somam por cima do offset, não dentro do clipe.
- Os braços usam a **aparência do personagem escolhido**: `PersonagemVisual.criarParte(PersonagemId, nome, original)` para os 6 segmentos (mesmo sem malhas funciona com blocos).
- Clipes: `Animacao.trilha(animatorDoViewmodel, "armas/<classe>", "Idle"|"Equip"|"Fire"|"Reload"|...)`, os mesmos que a 3ª pessoa. Tempos do tiro/recarga continuam mandados por `ArmasSinais` (a regra de cadência é do servidor/Config, o clipe é só visual; ajustar `AdjustSpeed` para casar com a duração real, como `ArmasTerceira.duracaoNativa`).
- Itens que não são arma: se `ItemNaMao` mostrar um item, o viewmodel mostra o item na `RightHand`/`LeftHand` e toca `corpo/mao` (fecha a lacuna "recipiente sem viewmodel" de `docs/combustivel.md`). Se o orçamento não couber, deixar o gancho e registrar em Pendências.
- Regras antigas mantidas: desliga com `Health <= 0`, `Morto`, `SeatPart ~= nil` (dentro do carro a `Cabine` cuida), esconde o corpo real (`LocalTransparencyModifier`) e o `Cabo/Boca/Ejecao/ApoioEsquerdo` continuam exigidos para a boca do tiro e a ejeção (funções `bocaMundo()`/`ejecaoMundo()` não mudam de assinatura: o `ArmasCliente` e o `EfeitosArma` as usam).
- Mantém o plano B: sem clipe, usa o caminho atual (`ArmasVista` + `Regras/Braco`), então nada para de funcionar enquanto A1 não entrega.

## 3. Restrições comuns (valem para todo agente que escreve)
- Português nos comentários e nomes, estilo do repo (tabs, `--` com linha de cabeçalho dizendo dono e propósito). `--!strict`-friendly, sem `wait`, sem `game.Workspace`, sem `:connect`.
- Números em `src/shared/Config`, rede em `src/shared/Rede.luau`, regras puras em `src/shared/Regras` com teste Lune em `tests/`. Servidor decide; cliente só pede.
- Depois de escrever: `pwsh scripts/checar.ps1` (rojo build + Lune + selene + stylua) tem que passar. Se `checar.ps1` quebrar por algo de **outra** parte, avisar em vez de consertar o arquivo dos outros.
- Não usar o MCP do Studio, não dar Play, não subir `rojo serve`, não enviar nada ao Roblox, não commitar, não mexer em `CLAUDE.md`, `docs/decisoes.md`, mapa, ou arquivos de outras partes (pedir ao principal).
- Cada parte termina com a seção **Estado** em `docs/personagens.md` (o que ficou pronto, o que não foi testado, o que depende de Studio) e uma linha em `docs/pendencias-integracao.md`.
- Nomes de peça R15 e `CanQuery` das peças originais: não mudar (dano por parte, tiro, câmera e agachar dependem deles).
- Aberração (`Filtro/Aberracao.luau:385`) clona peças visíveis de outros jogadores: peça visual nova deve ter `Transparency` 0 só nas peças `Bloco`; nada visível fora delas.

## 4. Estado
(preenchido pelas partes S, M, A1, A2 ao terminarem)

### Parte S (seletor, 2026-11-06)
**Pronto (escrito, `checar.ps1` verde nos meus arquivos; nada visto no Studio):**
- `Config/Personagens` (elenco: padrao n1, office_worker n2, survivor_woman n3; `estilo`, `paleta`, `fonte`, `cabelos`, `previa`, `alturaCorpo`, `esperaSeletorMax`),
  `Config/PersonagensMalhas` (stub criado por mim; a Parte M o regerou com `meshId = false`), `Regras/Personagens` + `tests/Personagens.spec.luau`
  (validação de n, estado de escolha, decisão de respawn sem dobrar, malhas completas, paleta, créditos).
- `shared/PersonagemVisual`: `entrada(id)`, `visual(id)`, `criarParte(id, nomeR15, original)`, `detalhes(id, nomeR15, parte, opcoes?)`, `revestirParte`, `revestir(modelo, id, opcoes?)`,
  `criarRigPrevia()`, `nomesPartes`. O visual do `padrao` migrou de `server/Aparencia.luau` sem mudar nada (mesmos nomes de Frame/SurfaceGui, mesma ordem). `opcoes.previa = true` troca SurfaceGui por peças finas
  (SurfaceGui não aparece em ViewportFrame) e não põe etiqueta de cabeça. Malhas: `AssetService:CreateMeshPartAsync(meshId)` (cache por MeshId), `TextureID`, e cai em bloco se faltar dado ou falhar.
  **Pode esperar (yield)**: chamar dentro de task/pcall.
- `server/Aparencia`: `revestir(personagem, id?)` e `aplicar` agora delegam ao `PersonagemVisual` e leem `PersonagemId` (ausente/inválido = padrao); gravam o atributo no Character.
- `server/Personagem`: `CharacterAutoLoads = false` (também em `default.project.json` **e `build.project.json`**, senão o check "projetos iguais" falha). `LoadCharacter` só depois de `EscolherPersonagem`. Respawn: `Died:Once` ou
  `CharacterRemoving` agenda UM respawn por personagem (ficha), `Players.RespawnTime` depois; cancela se outro personagem já nasceu / jogador saiu / já carregando; espera se o seletor está aberto (`SeletorEstado`), no máx. `esperaSeletorMax` s.
  Atributos `PersonagemId` no jogador e no Character; `Pref_Personagem` via `Preferencias.definir`. Comando de teste (só Studio): `ServerStorage.Teste:Invoke("personagem", nil, n)` escolhe e nasce sem o seletor.
- `server/Preferencias`: `Pref_Personagem` (padrão 1, faixa 1..99), atributo novo `PrefCarregadas` (true quando a leitura termina, com ou sem sucesso), `Preferencias.definir(jogador, chave, valor)`, e `SalvarPreferencias` do cliente **não** grava `Pref_Personagem`.
- Rede: `EscolherPersonagem` (c→s), `SeletorEstado` (c→s, extra: segura o respawn automático), `AbrirSeletor` (s→c), `PersonagemEscolhido` (s→c, `ok, n, texto`).
- `client/SeletorPersonagem`: `abrir({modo = "entrada"|"morte", selecionado = n})`, `aberto()`. Cartões com prévia 3D (rig R15 estático + `PersonagemVisual` em modo prévia, girando), setas/D-pad, Enter/A confirma, Esc/B volta (só no modo morte), créditos no rodapé, `Mouse.pedir("Seletor")`. Botão "Trocar personagem" na tela de morte (`HudVida`, que também pede o cursor `Mouse.pedir("Morte")` enquanto a tela aparece).

**Decisões que tomei (revisar):**
1. A prévia usa um rig R15 aproximado e estático (`criarRigPrevia`), não o avatar do jogador: na entrada ainda não há Character e `CreateHumanoidModelFromDescription` é assíncrono e pode falhar.
2. Os dois personagens novos têm `visual = "malhas"` (destino) e caem em bloco com paleta própria (office_worker: camisa clara, gravata vinho, calça escura, cabelo curto; survivor_woman: jaqueta verde-militar, mochila, calça cargo, cabelo castanho comprido) enquanto as malhas não existem.
3. Escolha só vale no primeiro nascimento ou depois de morrer; vivo recebe "Só dá para trocar de personagem depois de morrer.". Trocar na tela de morte nasce na hora (cancela o respawn automático).
4. O seletor sempre abre ao entrar (com o personagem salvo marcado); Esc não fecha o seletor de entrada.
5. **Malhas (contrato atualizado pelo coordenador, 2026-11-06):** escala UNIFORME do conjunto, `k = Config/Personagens.alturaCorpo (5,234) / PersonagensMalhas[id].alturaTotalStuds`; `MeshPart.Size = tamanhoNativo * k` (sem esticar por eixo);
   posição = `HumanoidRootPart.CFrame * CFrame.new(centroMontagem * k - Vector3.new(0, distPeAteRaiz, 0))` (rotação da raiz), com `distPeAteRaiz = -min(Y no espaço da raiz de (pé.Position - pé.Size.Y/2))` entre `LeftFoot`/`RightFoot` originais, medido a cada `criarParte`
   (por isso a espera de `Cfg.esperaEscala` antes de revestir importa). Cada MeshPart é "Bloco", soldada à original de mesmo nome, `Transparency 0`; a original vai a 1. Vãos nas juntas são aceitos (placeholder). O caminho "bloco" continua esticando ao `Size` da peça.
   `Regras.malhasCompletas` agora exige também `alturaTotalStuds > 0` e `centroMontagem` (3 números) em cada parte; faltou algo = o personagem inteiro cai em "bloco" (tolerante). Se a raiz ou um pé não existe, aquela peça cai em bloco.
   **API para o viewmodel (A2):** `PersonagemVisual.criarParte(id, nome, original, opcoes?)` e `revestirParte` aceitam `opcoes.raiz` (HumanoidRootPart do corpo real) e `opcoes.distPeAteRaiz`; sem `opcoes`, a raiz é a `HumanoidRootPart` do modelo da peça original e os pés são `LeftFoot`/`RightFoot` desse modelo. Um rig só de braços precisa passar `raiz` (e `distPeAteRaiz` se não tiver pés).
   Lado: `centroMontagem.x < 0` é o lado esquerdo (-X do Roblox, frente -Z), como diz o cabeçalho do `PersonagensMalhas.luau`; usado sem espelhar. Na prévia, `criarRigPrevia` ganhou uma `HumanoidRootPart` invisível.

**Não testado (tudo depende do Studio, dona do Studio):** a ordem de inicialização com `CharacterAutoLoads = false` (sobretudo o 1º `LoadCharacter` nascer em um pad do Spawn); tela do seletor em 4:3 e celular; ViewportFrame (iluminação, enquadramento, rosto/roupa em peças finas, lado do rosto espelhado); `Died`/respawn manual e o botão da tela de morte; `CreateMeshPartAsync` com string (a API pede `Content` nas versões novas; só dá para ver com malhas enviadas); persistência no DataStore; spam no Confirmar; saída do jogador durante o seletor; o `Filtro/Aberracao` com as peças novas; cursor livre na tela de morte.
**Efeitos colaterais a avisar:** (a) `server/Admin.luau` ação `visual` só destrói `Bloco` que seja `Part` (um `MeshPart` ficaria); (b) qualquer teste que contava com o personagem nascendo sozinho precisa chamar `Teste:Invoke("personagem", nil, 1)` ou passar pelo seletor; (c) `Config/Aparencia.cores` continua a paleta do `padrao` (o viewmodel A2 deve usar `PersonagemVisual.criarParte` para a cor certa).

### Malhas (Parte M, 2026-11-06)
Pipeline `ferramentas/modelos/personagem_psx.py` (Blender headless, 5.2) + `ferramentas/modelos/gerar_config_personagens.py`. **Nada foi enviado ao Roblox**
(403 "User is moderated"); `Config/PersonagensMalhas.luau` está gerado com todos os ids `false`, então o visual cai em "bloco" até o envio.

**Rodar** (da raiz; o Blender do projeto é o do Steam):
```
"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --factory-startup -P ferramentas/modelos/personagem_psx.py -- ^
  --input "<arquivo.fbx>" --id office_worker [--saida "modelos 3d/personagens"] [--fonte ".."] [--licenca "CC BY 4.0"] [--credito ".."]
  [--textura <png>] [--altura-metros 1.8] [--studs-por-metro 2.9078] [--pose baixa|aberta] [--sem-previa]
python ferramentas/modelos/gerar_config_personagens.py
```
`--textura` serve para FBX que não trazem a imagem (os villagers e o male_casual); `--altura-metros` normaliza a altura total (os villagers têm 2,4 m). Sem `--licenca` o manifesto
sai com `desconhecida: confirmar origem com o usuario` e o gerador **deixa o personagem fora** do config (só comentário no topo).

**O que o script faz:** importa o FBX, imprime ossos e vértices por osso dominante, congela a malha na pose de repouso, junta as malhas soltas (cabelo, mochila, chapéu entram pelo osso delas:
`Hair`→Head, `Backpack`→UpperTorso), divide por osso dominante em 15 objetos com os nomes exatos das peças R15, **gira os braços (rígidos, em T) até pender na vertical** (cadeia ombro→cotovelo→punho, e afasta
até 0,05 m se invadir o tronco) porque o Lua estica cada malha para o Size da peça R15 e um braço horizontal numa caixa vertical ficaria torto, escala nos dados (2,9078 studs/m, pés em y=0), põe a origem de cada peça
no centro da caixa (o objeto guarda `centroMontagem`, então o FBX monta o boneco inteiro), recorta o atlas para a página do personagem (≤ 256 px, UV refeita, PNG idêntico ao recorte do atlas, conferido), tira armature/pele/animação,
valida (15 peças, nenhuma vazia, ≤ 1000 tris), exporta `<id>.fbx` + `<id>.png` + `<id>.json`, **reimporta o FBX** para conferir nomes e tamanhos e renderiza `previa.png` (frente, 3/4, perfil).
Mapeamento de osso→peça cobre `Hips/Spine/Head/LeftArm/...` (psx-people), `Hip/Chest/UpperArm.L/Upperleg.R/...` (villagers) e `pelvis/thigh_left/shin.L/f_middle.01.L` (male_casual); osso sem peça manda os vértices para a peça mais próxima (aviso).
Eixos medidos no projeto (Beretta): ponto Roblox = (-x, z, y) do Blender; frente -Y vira -Z; o lado esquerdo do personagem (+X no Blender) vira -X, **então +X do Roblox é o lado DIREITO do personagem** (`LeftUpperArm.centroMontagem.x < 0`). `tamanhoNativo` = (dx, dz, dy) do Blender, em studs; `centroMontagem` = centro da caixa da peça no boneco montado, **mesmo mapeamento de eixos** (x = -x do Blender, y = z, z = y), em studs, x centrado no corpo, z com a origem do modelo original, y a partir dos pés (= 0).

**Config (atualizado 2026-11-06):** `PersonagensMalhas.luau` traz por personagem `alturaTotalStuds` e por parte `meshId`, `tamanhoNativo` e `centroMontagem`. O `PersonagemVisual` deve usar **uma escala só para o conjunto**, `k = altura do R15 / alturaTotalStuds`, com `Size = tamanhoNativo * k` e a peça em `centroMontagem * k` relativo aos pés (não esticar peça a peça).

**Resultados** (saída em `modelos 3d/personagens/<id>/`, ignorada pelo git como o resto de `modelos 3d`):
| id | licença | tris (soma) | maior peça | altura (studs) | textura | no config |
|---|---|---|---|---|---|---|
| office_worker | CC BY 4.0 (heyheythere) | 962 | Hand 180 | 5,12 | 128x128 | sim |
| survivor_woman | CC BY 4.0 (heyheythere) | 1078 | Head 248 | 4,95 | 224x128 | sim |
| villager_man | desconhecida | 646 | Head 242 (com o chapéu) | 5,23 (normalizado) | 256x183 | **não** |
| villager_woman | desconhecida | 556 | Head 116 | 5,23 (normalizado) | 256x183 | **não** |
| male_casual | desconhecida | 952 | Torso 138 | 5,23 (normalizado) | 256x256 | **não** |
| ps1 character.fbx | desconhecida | 1926 | (sem armature) | sem rig | | **não serve**: 2 malhas soltas sem esqueleto nem pesos, escala 0,298 no objeto; precisaria de rig novo (`rig_ps2.py`) |
Tris por peça de office_worker: Head 172, UpperTorso 54, LowerTorso 48, UpperArm 36, LowerArm 32, Hand 180, UpperLeg 38, LowerLeg 32, Foot 26 (cada lado igual). Folga entre peças vizinhas: **0** em todas
(medida pela caixa, nos 5 personagens; única exceção villager_woman, UpperTorso|RightUpperArm, 0,021 stud; conferido a olho no `previa.png`: nenhum buraco, só emendas de tom). Reimportação: nomes exatos e tamanhos iguais ao manifesto (diferença 0,0000).

**Limites que ficaram (honestos):**
- O visual **não foi visto no Roblox**. Só Blender (Workbench, textura simples). O sombreado baked dos psx-people está em **cor de vértice** (`Col`) e o FBX a leva; **não sei se o Roblox aplica** cor de vértice em MeshPart; se ignorar, o personagem fica sem o sombreado (textura sozinha, mais chapada).
- **Proporção (resolvida no config pela escala única, ver acima):** as caixas nativas não são as do R15 (cabeça 0,51 x 1,0 x 0,64 studs contra 1,2³ do R15; o cabelo e a mochila da survivor_woman inflam Head e UpperTorso: Head 0,56 x 1,05 x 0,68, UpperTorso 0,85 x 1,24 x 1,11). Se o Lua esticasse cada malha ao Size da peça
  (`PersonagemVisual`), a cabeça e o tronco saem esmagados/alargados e o cabelo comprido some dentro do bloco. Adotado: escala única do conjunto + `centroMontagem` (coordenador, 2026-11-06). Consequência: o boneco não encaixa nas caixas físicas do R15 (cabeça mais estreita, braços mais finos); é só visual.
- Os bracos rígidos ficam com uma emenda reta no ombro/cotovelo (como no original PS1); no male_casual (pele suave no original) a divisão por osso dominante deixou um pequeno degrau no cotovelo e no ombro.
- villager_woman tem uma aba do vestido atrás do quadril que sai do corpo; survivor_woman: os fios de cabelo da frente (da malha original) ficam sobre o peito. Ambos como no original.
- Lado: `LeftUpperArm` etc. saem do osso `Left*` do original, que está em +X no Blender = -X no Roblox (conferir no Studio com o primeiro envio).

**O que falta (precisa da conta liberada e da dona do Studio):**
1. Enviar o FBX de cada personagem como **Model** (o fluxo de `enviar_armas.py`/`enviar_monstros.py`, 1 envio por personagem, mais o PNG como `Image`). Não executado.
2. Medir no Studio o **pivô de importação** dos 15 MeshParts (esperado: centro da caixa, 1 unidade = 1 stud, sem giro, como a Beretta) e ler cada `MeshId` (`InsertService:LoadAsset` -> `MeshPart.MeshId`).
3. Gravar `modelos 3d/personagens/<id>/enviados.json` = `{ "modelo": N, "textura": N, "meshIds": { "Head": N, ... } }` e rodar `python ferramentas/modelos/gerar_config_personagens.py` (preenche o `PersonagensMalhas.luau`).
4. Conferir se a cor de vértice aparece; conferir créditos `PSX People Free by heyheythere - https://heyheythere.itch.io/psx-people-free - CC BY 4.0` na tela de créditos.
5. Usuário: confirmar origem/licença de villager_man, villager_woman e male_casual (as saídas já estão geradas, é só tirar o "desconhecida" do manifesto e rodar o gerador) e decidir o ps1 character (sem rig).

### Primeira pessoa (Parte A2, 2026-11-06)
Escrito e com `checar.ps1` verde nos meus arquivos (`stylua --check` e `selene` limpos neles; o `checar` falha hoje por `ArmasTerceira.luau`/`Animacao.spec`/`Armas` de outras partes). **Nada visto no Studio.**

**Arquivos:** `src/client/BracosViewmodel.luau` (novo, rig), `src/client/ArmasViewmodel.luau` (refatorado, mesmas funções públicas: `iniciar`, `ativo`, `bocaMundo`, `ejecaoMundo`), `src/shared/Regras/BracosVista.luau` + `tests/BracosVista.spec.luau` (regras puras), `src/shared/Config/ArmasVista.luau` (`rig` e `item` novos; o resto é a reserva intacta).

**Como funciona**
- `BracosViewmodel.criar(personagem, camera)` copia as 8 juntas R15 do personagem real (`Root, Waist, Right/Left Shoulder, Elbow, Wrist`, mesmos C0/C1 e mesmos nomes de peça) e monta `HumanoidRootPart` (única peça ancorada) > `LowerTorso` > `UpperTorso` (invisíveis) + 6 segmentos de braço, mais `AnimationController > Animator`. Os 6 segmentos vêm de `PersonagemVisual.criarParte(PersonagemId, nome, original)` (X/Z × `rig.espessura` 0,9); sem o módulo, ou com malhas ainda não aquecidas, blocos nas cores `pele`/`suter`. O Model nasce filho de `CurrentCamera`.
- A arma (`ArmaModelo.criar`, como antes) fica presa à `RightHand` do rig por `Motor6D "JuntaArma"` com `Config/ArmasAnim.mao.porClasse[classe]`. Os clipes são `Animacao.trilha(animator, "armas/<classe>", clipe)`, os mesmos da 3ª pessoa.
- **Posicionamento por calibração:** a cinemática direta (C0/C1 do rig + poses do 1º `Keyframe` da `KeyframeSequence` do `Idle`, via `Animacao.sequencia`) dá onde o Cabo fica em relação ao `UpperTorso`. A cada quadro o tronco vai para `armaCF * caboRelativo:Inverse()`, onde `armaCF = câmera * base + molas + corrida + parede` (as mesmas contas de antes). Resultado: no `Idle` o Cabo cai exatamente em `ArmasVista.classes[c].base`, então os números de `base` continuam valendo e o clipe só move o braço a partir dali. Se a calibração falhar usa `rig.torsoReserva`.
- Coice, balanço, sway, corrida e recuo de parede movem o rig inteiro por cima do clipe (o que o clipe de poses fazia sozinho no plano B agora é o `Equip`/`Fire`/`Golpe`/`Reload` do rig).
- Velocidades (`AdjustSpeed`): tiro = `max(1, Fire nativo / cadência)`; recarga de pente = `Reload nativo / duração do sinal`; recarga por cartucho = `RecargaInicio`, N × `RecargaCartucho`, `RecargaFim` agendados pelo relógio do quadro (N pela duração total, mesma conta de `ArmasTerceira`), cada um com a velocidade para durar o tempo de `Config/Armas.recarga`; golpe = `Impacto` nativo (`ArmasAnim.impacto`) / `atrasoImpacto`, com teto de 95% da cadência; `Equip` = nativo / `sacarDuracao`. Tudo em `Regras/BracosVista` (testado).
- Mão esquerda: `IKControl` no `ApoioEsquerdo` da arma (rig, mesmas regras `ArmasAnim.ik` da 3ª pessoa, via `BracosVista.ikDesejado`); em arma de uma mão o braço esquerdo só aparece enquanto toca `Reload`/`Recarga*` (`rig.esquerdaSoNaRecarga`), para o repouso dele não ficar pendurado no quadro.
- **Plano B:** se `Animacao` não existe, o clipe `Idle` da classe é nil, ou faltar peça/junta R15, o viewmodel usa o caminho antigo inteiro (blocos + `Regras/Braco` + poses de `ArmasVista`), com um `warn` único.
- **Item na mão (fecha a lacuna de recipiente do `docs/combustivel.md`):** sem arma, se o personagem tem filho `ItemNaMao` (lanterna, garrafa, galão, comida), o viewmodel clona esse modelo para a mão certa do rig (lado lido da `SoldaMao`) e toca `corpo/mao` > `SegurarUmaMao` (`ArmasVista.item`). O `ItemNaMao` real também é escondido (`LocalTransparencyModifier`). Sem esse clipe (A1) nada muda: o item continua sem viewmodel (`itemIndisponivel`).
- Mantido: desliga com `Health <= 0`, `Morto`, `SeatPart ~= nil` ou câmera longe da cabeça (V/T); esconde braços/`ArmaNaMao`/`ItemNaMao` reais; refaz ao respawn e quando o atributo `PersonagemId` do Character muda; sem `Instance.new` por quadro (o `RaycastParams` da parede agora é reaproveitado).
- **FOV:** o viewmodel usa o FOV da câmera (sem ViewportFrame, que quebraria a névoa/aberração do filtro); a posição lateral/vertical da arma é escalada por `tan(FOV/2)/tan(70°/2)` (`rig.compensarFov`) para a arma não "fugir" da tela na corrida (FOV 78). **Near-clip:** não dá para mudar o plano próximo da câmera; os ombros ficam atrás/abaixo do olho como antes e o recuo de parede continua. **Ordem de desenho:** é 3D comum, então a arma ainda pode atravessar parede muito encostada; só o recuo de parede evita.

**Falta / depende do Studio (dona do Studio)**
1. `Animator` num Model filho de `CurrentCamera`: tocar de verdade? (é a base do risco todo; se não tocar, a calibração e o plano B continuam funcionando, mas sem animar o braço o `Idle` não aparece e o viewmodel fica na pose de repouso R15, com os braços estendidos para baixo; nesse caso trocar para Model em `workspace` oculto, ou `Camera` > Model com `Humanoid`).
2. `Animacao.id` usa `RegisterKeyframeSequence` em runtime e `Animator:LoadAnimation` com o id registrado: confirmar no cliente (contrato 0.4 da A1).
3. Primeira pose: os C0/C1 reais escalados batem com a cinemática direta? Conferir onde o braço aparece e ajustar `ArmasVista.rig.torsoReserva` e `classes[*].base` (nunca visto).
4. `IKControl` sem `Humanoid` (só `AnimationController`): se não funcionar a mão esquerda segue o clipe, sem erro.
5. `Motor6D` com `Part1 = Cabo` solda da arma: confirmar que as peças da arma (WeldConstraint ao Cabo, `Massless`) seguem a mão sem tremer.
6. Posição do item na mão e qual braço `SegurarUmaMao` anima (lanterna só na esquerda hoje usa o mesmo clipe e espelha só a posição: se o clipe anima o braço direito, a mão esquerda fica parada).
- Primeira pessoa, malhas (2026-11-06): se `criarParte` devolver MeshPart, o segmento do rig fica uma peça invisível com a medida da R15 real e a malha vai como filha, soldada com `original.CFrame:ToObjectSpace(malha.CFrame)`, sem mexer no Size; `opcoes.raiz` = HumanoidRootPart do personagem real (`original.Parent`). Blocos não mudam. Não testado (só há blocos hoje).

### Animações (Parte A1, 2026-11-06)
Escrito e com `checar.ps1` verde nos meus arquivos. **Nada visto no Studio** (esta sessão não é dona dele); o que falta confirmar está no fim.

**Arquivos:** `src/shared/Animacao.luau` (runtime), `src/shared/Regras/Animacao.luau` + `tests/Animacao.spec.luau` (regras puras e dados), `src/shared/Config/AnimacoesCorpo.luau` (ids `false` + números dos gatilhos), `assets/animacoes/corpo/{carro,mundo,mao,vida}.json` (17 clipes), `src/client/AnimacaoCorpo.luau`, `src/client/ArmasTerceira.luau` (usa `Animacao`, toca também nos outros), `ferramentas/animacao/validar_corpo.luau` (valida + folha de quadros) e `montar_corpo.luau` (grava `build/anim_corpo/*.rbxm`). `default.project.json` e `build.project.json` ganharam `Shared.AnimacoesDados -> assets/animacoes` (o `checar` exige os dois iguais; `.json` vira `ModuleScript` que devolve a tabela, conferido com `rojo build`). Linha nova em `init.client.luau` (`AnimacaoCorpo`, depois de `ArmasTerceira`).

**API (`Animacao`, a mesma do contrato; usada pela A2 em `BracosViewmodel`)**
- `carregarDados(grupo)`: tabela do JSON ("armas/pistola", "corpo/carro"); `nil` + um `warn` se não existe.
- `sequencia(grupo, clipe)`: `KeyframeSequence` (cache) igual à de `montar_armas.luau`: uma `Pose` por peça animada com `Weight` 1 e os ancestrais com `Weight` 0 (inclui `HumanoidRootPart`), easing do trecho na pose ANTERIOR, `KeyframeMarker`s.
- `id(grupo, clipe)`: id publicado de `Config/ArmasAnim` (armas/*) ou `Config/AnimacoesCorpo` (corpo/*) se houver; senão `KeyframeSequenceProvider:RegisterKeyframeSequence` (cache; aceita retorno `string` ou `Content`). `nil` se o clipe não existe.
- `trilha(animator, grupo, clipe, opcoes?)`: `LoadAnimation` com cache por animator; prioridade e laço do JSON (`opcoes` = `{id, prioridade, loop}` sobrepõe). `duracao(grupo, clipe)`: do JSON (0 se não existe). Tudo tolerante (nil + warn único).

**Clipes novos** (prioridade; duração; todos validados: junta/peça, último quadro = duração, limites angulares, pernas só onde permitido, laço sem pulo)
- `corpo/carro`: `MotoristaIdle` Action2 2,4 s laço; `MotoristaViraEsquerda`/`Direita` Action3 0,6 s laço (peso = direção); `PassageiroIdle` Action2 2,6 s laço; `Entrar` Action2 0,5 s; `Sair` Action2 0,5 s. Só ombros/cotovelos/punhos/cintura.
- `corpo/mundo`: `Pegar` Action3 0,9 s (marcador `Pegou` em 0,42; usa pernas e raiz para agachar); `Largar` Action3 0,5 s (`Soltou`); `Interagir` Action3 0,7 s (`Alcancou`); `Abastecer` Action2 2,0 s laço.
- `corpo/mao`: `SegurarUmaMao` (braço direito) / `SegurarUmaMaoEsq` (braço esquerdo, lanterna) Action2 2,2 s laço; `SegurarGalao` Action2 2,4 s laço; `Usar` Action3 1,5 s (`Consumiu`; velocidade = 1,5 / `Config/Itens.uso`, limitada a 0,5-2x).
- `corpo/vida`: `Morte` Action4 1,3 s (marcador `Congelar` em 1,25: o cliente faz `AdjustSpeed(0)`); `Queda` Movement 0,8 s laço; `Aterrissagem` Movement 0,35 s.
- `corpo/movimento` (`AgacharIdle`): **não feito de propósito**. O agachar é procedural (`server/Movimento.luau` mexe no `C0` das juntas e no `HipHeight`) e um clipe de pernas brigaria com isso.

**Desvios do contrato (decididos por mim, revisar):** (1) carro e mão em **Action2** (não Action) e as ações de uma vez em **Action3**: arma equipada toca `Idle` em Action, e dois clipes do mesmo nível nos mesmos braços se misturam pela metade; só ombros/cotovelos/punhos entram nesses clipes, então andar/pernas continuam do Movement/Core. (2) `corpo/mao` ganhou `SegurarUmaMaoEsq` (a lanterna fica na esquerda). (3) **`server/Vida.luau`: `Humanoid.BreakJointsOnDeath = false`** (uma linha): sem isso as juntas quebram na morte e o clipe `Morte` não tem o que animar. (4) **`server/Armas.luau`: atributo novo `Player.GolpeSeq`** (contador de golpes corpo a corpo aceitos, uma linha em `atacarCorpo`); os outros clientes tocam `Golpe`/`Golpe1|2` quando ele muda. Sem evento de rede novo.

**Como cada gatilho liga (`AnimacaoCorpo`, todos os jogadores, cada cliente toca no Animator que vê)**
- Assento: `Humanoid.SeatPart` num modelo com atributo `Veiculo`: `VehicleSeat` = motorista, `Seat` = passageiro. `Entrar`, depois o Idle entra por cima de 70% do `Entrar`; ao sair, `Sair`. Curva: `VehicleSeat.SteerFloat` (zona morta 0,1) controla o peso do `MotoristaVira*`.
- Item na mão: filhos `ItemNaMao` do personagem (atributo `Item`, mão lida da `SoldaMao`): recipiente com 2+ litros = `SegurarGalao`, resto `SegurarUmaMao`/`Esq`; lanterna na esquerda é ignorada se há arma equipada (o IK da arma cuida). `Player.Usando` -> `Usar`. `Player.Mangueira` -> `Abastecer`.
- Vida: `Humanoid.Died` -> `Morte` (corpo já caído ao entrar no alcance = vai direto para a pose final); `FreeFalling` por 0,6 s -> `Queda`, e `Aterrissagem` ao pousar (o pulo normal, ~0,5 s no ar, não conta).
- Só o jogador local: `Pegar` = evento `Inventario` (total subiu) casado em 0,8 s com um item de `workspace.ItensChao` que sumiu a menos de 10 studs; `Largar` = total desceu + item com `Largado` apareceu perto; `Interagir` = `ProximityPromptService.PromptTriggered` (qualquer prompt, no máx. 2/s). Não mexi em `ItensChaoCliente`/`InventarioUI` (não são meus): se um dia emitirem um sinal, trocar a heurística por ele.
- `ArmasTerceira`: id publicado se houver senão registrado; passa a tocar nos outros: equipar por `Player.ArmaEquipada`, tiro pelo evento `Disparo` (já existente, só chega a quem está perto), recarga por `Player.Recarregando` (pente = `Reload`; cartucho = `RecargaInicio`, `RecargaCartucho` em laço, `RecargaFim`), golpe por `GolpeSeq`. IK e camada de mira intactos (a mira já valia nos outros); **sem IK da mão esquerda nos outros** (só o clipe).

**Falta / depende do Studio (dona do Studio)**
1. `RegisterKeyframeSequence(ks)` em runtime no cliente + `Animator:LoadAnimation(Animation{AnimationId = id})`: toca? A API nova devolve `Content` (uso `.Uri`); se exigir a `KeyframeSequence` parentada em algum lugar, parentar em `Animacao.id`. Base de todo o resto (inclusive a 1ª pessoa da A2).
2. Prioridades de fato (Action2/3/4 sobre o `Animate` padrão do Roblox e sobre `Idle` de arma) e se os clipes só de braço deixam as pernas do `Animate` andarem.
3. Replicação: o que cada cliente registra só vale nele; confirmar que o clipe do jogador local não aparece quebrado nos outros (eles tocam o próprio).
4. `Morte`: o corpo cai de costas deslocando a raiz em -2,3 studs (palpite pela altura do quadril); ajustar `Root` (py) em `vida.json` até as costas encostarem no chão sem afundar. `BreakJointsOnDeath = false` não pode ter efeito colateral (câmera, bolsa, `Vida.aoMorrer`).
5. `Pegar`: agachamento calculado à mão (quadril 55°, joelho -100°, tornozelo +45°, raiz -0,8): conferir se a mão chega ao chão e os pés não flutuam/afundam; `Entrar`/`Sair` com o carro de verdade.
6. Sinal dos eixos conferido só nos números dos clipes de arma (ombro +X levanta à frente, cotovelo +X dobra, joelho -X dobra, cintura +X para trás): olhar uma vez cada clipe.
7. `GetMarkerReachedSignal("Congelar")` congelando a Morte; `Humanoid.FreeFalling`/`Died` disparam nos clientes que veem outro jogador; `SteerFloat` do `VehicleSeat` replicado para os outros.
8. Para a A2: `SegurarUmaMao` anima o braço DIREITO; a lanterna na esquerda deve usar `SegurarUmaMaoEsq` (já existe).
