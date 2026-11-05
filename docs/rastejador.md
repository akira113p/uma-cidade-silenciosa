# Rastejador: modelo, animação, IA e arquitetura

Pedido do usuário (2026-11-04): trocar o inimigo nível 1 "Rastejador" (hoje boneco de blocos que desliza) pelo modelo
real, **com as animações**. Ele precisa **subir degraus** (calçada, rua, lote), **atacar o jogador**, **quebrar a parede de
casa** quando não consegue entrar e **atacar carros que fazem barulho**.

Regra do fluxo: decisão não prevista aqui → **não decidir**: anotar em `docs/pendencias-integracao.md`, seção
"Rastejador", e parar nesse ponto (o resto continua). Nada de commit. Nunca rodar `gerar_mapa.luau --final`.

## 0. Decisões do usuário (já tomadas)

- Animação: a do **Opus** (`modelos 3d/_ps2/Rastejador/Rastejador_anim_opus.blend`, script
  `ferramentas/modelos/animar_rastejador_opus.py`). Ações: Idle, Walk, Run, Attack, Death (conferir nomes no .blend).
- **Escala: o monstro tem 1 m de altura quando o jogador tem 1,8 m.** Altura do monstro em studs = altura real do
  personagem em studs ÷ 1,8 (medir o personagem no Studio, com `Config/Aparencia`, e gravar o número em Config). Compri-
  mento e largura vêm proporcionais do modelo (na altura normalizada de 2,2 m ele tem 4,0 × 3,7 m → fator 1/2,2).
- Quebrar parede: **buraco permanente até reiniciar o servidor**; vale de rota para todos.
- Animação entra no Roblox pela **Open Cloud** (chave no `.env`, `ROBLOX_OPEN_CLOUD_KEY`/`ROBLOX_CREATOR_ID`), se não custar
  Robux. A documentação não cita custo. Fase 0 testa com 1 clipe; se a resposta pedir pagamento/erro de preço, **para** e
  segue o plano B (§3.2). Não gastar Robux.
- Sem filtro PS2 extra: o Rastejador usa o `_ps2/Rastejador` já convertido (não está em `SEM_FILTRO`).

## 1. Visão geral (o que muda e o que não muda)

O Rastejador continua sendo uma espécie de `Config/Monstros.especies`, com a **mesma percepção** (`Regras/Percepcao`:
Calmo/Investiga/Caça por som) e o mesmo laço de `server/Monstros.luau`. O que entra é uma camada de **capacidades**,
ligadas por espécie (o Rastejador liga todas; Corcunda/Esfolado ficam como estão):

```
Ruído ──► Percepcao (estado + alvo estimado) ──► Objetivo físico ──► Movimento ──► Ações ──► Animação
                                                  │ jogador         │ caminho     │ golpe
                                                  │ veículo         │ degrau/salto│ arrombar
                                                  │ parede          │ travado     │ morder carro
                                                  └ ponto de som
```

Princípio herdado: **o servidor decide tudo** (alvo, dano, parede, carro); o cliente só mostra (animação, som local).
Custo: 250 monstros no máximo; sondas e raycasts só para monstros em Caça/Investiga/Ataque e a ≤ `distanciaAtiva`
de algum jogador. Monstro Calmo longe continua pausado (como hoje).

## 2. Arquivos (dono único por arquivo)

| Arquivo | Conteúdo |
|---|---|
| `src/shared/Config/Rastejador.luau` | **todos** os números novos (§7). Nada de número solto no código. |
| `src/shared/Config/Monstros.luau` | espécie `Rastejador` ganha `altura` (studs), `capacidades = { degrau = true, arrombar = true, veiculo = true }`, `malha = true`. `IA_PADRAO` pode ganhar chaves, sem quebrar as antigas. |
| `src/shared/Regras/Rastejador.luau` | **regras puras** (sem Instance): §4. Testes em `tests/Rastejador.spec.luau`. |
| `src/server/MonstroModelo.luau` | monta o modelo do Rastejador (colisão em blocos + malha visual, §3). `Monstros.criar` usa quando a espécie tem `malha`. |
| `src/server/MonstroObjetivo.luau` | escolhe o objetivo físico a cada passo da IA (§5.1) e guarda o estado de arrombar/morder. |
| `src/server/MonstroMovimento.luau` | degraus, salto, travado, caminho com salto (§5.2). |
| `src/server/MonstroArrombar.luau` | achar parede, bater, abrir o buraco (§5.3). |
| `src/server/Monstros.luau` | continua dono do laço; chama os módulos acima por `pcall`/`servico` quando a capacidade está ligada. Mudanças mínimas e comentadas. |
| `src/server/Veiculos.luau` | **só** acrescenta `Veiculos.maisPertoDe(posicao, raio)` (§5.4). Nada mais. |
| `src/shared/Config/Som.luau`, `Sons.luau` | acrescentar ação `paredeQuebrando` (65 dB) e sons `GolpeParede`, `ParedeCai` (reaproveitar ids já confirmados do catálogo; `confirmado = false`). |
| `src/shared/Config/MonstrosMalhas.luau` | gerado por `ferramentas/modelos/gerar_config_monstros.py`: assetId da malha, texturas, ids das animações, dimensões. |
| `src/client/MonstroAnimador.luau` | só no plano B de animação (§3.2). |
| `ferramentas/modelos/exportar_rastejador.py`, `enviar_monstros.py`, `gerar_config_monstros.py` | Blender → FBX/dados → Open Cloud → Config (modelo: `enviar_veiculos.py`, `gerar_config.py`). |
| `tests/Rastejador.spec.luau` | testes Lune das regras puras. |
| `docs/pendencias-integracao.md`, `docs/rastejador.md` (§ Estado) | o agente atualiza ao fim. |

## 3. Modelo e animação

### 3.1 Malha
- Fonte: `_ps2/Rastejador/Rastejador_anim_opus.blend` (rig de 17 ossos, malha 3728 tris, textura 256 px).
- Exportar FBX na altura de 1,0 m (escala 1/2,2 sobre o normalizado), frente = -Z do Roblox, cima = +Y, pés em y=0,
  com o armature e os pesos (≤ 4 influências). Manifesto JSON: dimensões em m, nomes dos ossos, ações e duração.
- Enviar pela Open Cloud como Model (mesmo fluxo e mesmas armadilhas dos carros: `docs/veiculos-modelos.md`, seção
  "Envio e importação": fator de importação 0,28 e giro de 180° em Y **medidos, não assumidos**; reconferir porque aqui
  há esqueleto).
- Em jogo (`MonstroModelo`): modelo = **HumanoidRootPart** de colisão (bloco invisível, tamanho = caixa do corpo na escala
  final, não o da malha com patas esticadas), `Humanoid` R15 com HipHeight calculado para o bloco assentar no chão, e a
  **malha visual** soldada, `Massless`, sem colisão/consulta/toque. Parte para o raycast de arma = a malha precisa ser
  acertável (`CanQuery = true` na malha; `Monstros.ehMonstro` já sobe pela hierarquia).
- Sem assetId (falha do envio ou do `LoadAsset`): cai no boneco de blocos de hoje, com `warn`. Nunca quebra o servidor.

### 3.2 Animação (Fase 0 decide; critérios abaixo)
**Plano A (preferido): clipes na Open Cloud.** Construir um `KeyframeSequence` por ação (Idle, Walk, Run, Attack, Death)
com poses nos ossos (nomes do rig), a partir dos quadros do Opus (amostrar o .blend a 24 fps, 1 pose por quadro-chave
útil, ≤ 30 keyframes por ação). Gerar o `.rbxm` (Lune `@lune/roblox` ou Studio via MCP), subir como `Animation`, anotar o id
em `Config/MonstrosMalhas.animacoes`. Tocar no servidor com `Animator` (dentro do Humanoid) para replicar sozinho.
**Passa se:** (1) a API aceita sem pedir Robux, (2) o clipe toca no modelo importado no Studio com os ossos certos (conferir
por `screen_capture` em 3 instantes de Walk e 2 de Attack), (3) `AnimationTrack:GetMarkerReachedSignal("Impacto")` ou
tempo conhecido para o golpe.
**Plano B (se o A falhar em qualquer ponto):** dados + `Bone.Transform`. Exportar por ação a tabela
`{ duracao, ciclica, ossos = { [nome] = { {t, cframe}, ... } } }` em `Config/RastejadorAnim.luau` (ou JSON lido por Lune →
Luau), e `client/MonstroAnimador.luau` anima os monstros a ≤ `animacao.distancia` (150 studs) lendo os atributos
`Acao` e `AcaoT` do modelo (o servidor escreve; o cliente interpola e reinicia o Attack quando `AcaoT` muda). Orçamento:
≤ 40 monstros animados por vez, passo a 30 Hz, ossos só de quem está na tela (checar `WorldToViewportPoint`).
**Em qualquer plano**: o servidor mantém os atributos `Acao` (Idle/Walk/Run/Attack/Death) e `AcaoT`; a escolha da ação vem
de `Regras/Rastejador.acao` (§4). Velocidade de reprodução do Walk/Run = velocidade real ÷ velocidade nativa do ciclo
(sem patinar). Attack toca uma vez por golpe. Death toca uma vez e o corpo **fica na pose final** durante `IA.tombar`
(troca o `tombar` por rotação feio). Morte: some depois com o mesmo prazo de hoje.

## 4. Regras puras (`Regras/Rastejador.luau`, testadas)

Todas recebem `cfg = Config/Rastejador`. Sem Instance, sem `os.clock`.

- `classificarDegrau(altura, folga, cfg) -> "andar" | "saltar" | "parede"`
  `altura ≤ cfg.degrau.andar` → andar (o Humanoid sobe sozinho; valor medido na Fase 1); `≤ cfg.degrau.saltoMax` e
  `folga ≥ cfg.degrau.folgaMin` (espaço livre acima, para a cabeça) → saltar; senão parede.
- `alturaDoSalto(altura, cfg) -> number` = `altura + cfg.degrau.margemSalto`, limitada a `saltoMax`.
- `precisaArrombar(estadoCaminho, comprimento, retaHoriz, alvoDentro, cfg) -> boolean`
  Verdadeiro se há alvo físico **dentro de construção** e (`estadoCaminho == "NoPath"` ou
  `comprimento > retaHoriz * cfg.arrombar.fatorDesvio + cfg.arrombar.folgaDesvio`). Falso se o caminho tem entrada
  curta. Nunca arromba alvo fora de construção.
- `paredeArrombavel(tam, ehPiso, atributos, cfg) -> boolean`: fina (`min(x,z) ≤ cfg.arrombar.espessuraMax`), alta
  (`y ≥ cfg.arrombar.alturaMin`), não indestrutível. Piso, telhado e fundação não.
- `vidaParede(espessura, cfg) -> number` = `clamp(espessura * cfg.arrombar.vidaPorStud, vidaMin, vidaMax)`.
- `buraco(larguraParede, alturaParede, ponto, larguraMonstro, cfg) -> { cx, largura, altura }` (em coordenadas locais
  da parede; limitado à parede; largura ≥ `larguraMonstro * cfg.arrombar.folgaLargura`).
- `partesDaParede(tamanho, buraco) -> { {centro, tamanho}, ... }` até 3 retalhos (esquerda, direita, topo) sem sobreposição,
  descartando os menores que `cfg.arrombar.retalhoMin`. Soma das áreas + buraco = área original (teste).
- `escolherObjetivo(candidatos, cfg) -> candidato?`: prioridade **jogador ao alcance > veículo ruidoso > parede de arrombar >
  ponto de som**; desempate por distância; veículo só vale se o último som dele foi há ≤ `cfg.veiculo.memoria`.
- `parteDoVeiculo(sorteio, ocupado, cfg) -> "pneu" | "vidro" | "carroceria"` com pesos de `cfg.veiculo.pesos`; vidro só
  conta se há ocupante.
- `acao(estado, atacando, subindo, velocidade, morto, cfg) -> "Idle"|"Walk"|"Run"|"Attack"|"Death"`.
- `velocidadeAnim(acao, velocidade, cfg) -> number`.

Casos de teste obrigatórios: degrau 0,4 andar / 0,9 saltar / 3,0 parede; sem folga vira parede; caminho curto não arromba,
NoPath arromba, alvo fora de prédio nunca arromba; buraco nas bordas da parede; soma de áreas dos retalhos; prioridade do
objetivo; veículo antigo (> memória) perde para ponto de som; `acao` em cada estado.

## 5. Servidor

### 5.1 Objetivo físico (`MonstroObjetivo`)
A cada passo (5 Hz) do monstro com `capacidades`, montar candidatos e chamar `Regras.escolherObjetivo`:
1. **Jogador**: vivo a ≤ `distanciaAtaque` (regra atual do `passoMonstro`; o golpe do jogador continua como hoje, mas com
   atraso `cfg.golpe.atrasoImpacto` para casar com o quadro de impacto do Attack; se o jogador sair do alcance antes do
   impacto, o golpe erra).
2. **Veículo**: de `ouvirSom` com `evento.tipo` em `cfg.veiculo.tiposDeSom` (carro, carroLigar, carroFalhar, carroBatida,
   buzina, pneuEstouro): `Veiculos.maisPertoDe(posicao, cfg.veiculo.raioBusca)`; guarda `{modelo, ultimoSom}` no `Dados`.
   Vale enquanto houver som novo dentro de `memoria` s **ou** o veículo estiver ocupado.
3. **Parede**: se `precisaArrombar` (checado ao recalcular caminho, não a cada passo).
4. **Ponto de som**: o `perc.alvo` de hoje.
A decisão troca de objetivo no máximo a cada `cfg.objetivo.histerese` s (evita tremer entre dois).

### 5.2 Movimento (`MonstroMovimento`)
- **Caminho**: `AgentCanJump = true`, `AgentRadius`/`AgentHeight` do bloco de colisão. Waypoint com `Action == Jump` →
  `saltar(alturaDoSalto)`.
- **Sonda de degrau** (10 Hz enquanto `MoveDirection > 0`): raycast para baixo a `cfg.degrau.sondaFrente` studs à frente do
  corpo, a partir de `saltoMax + 1` acima do pé; `altura = topoAdiante - topoAtual`. Mais um raycast horizontal na altura
  do peito para ver se há parede/obstáculo alto. `classificarDegrau`: andar → nada; saltar → `Humanoid.JumpHeight` e
  `Jump`; parede → `obstruido = true` (o §5.3 pode assumir se for parede de construção; senão desvia, ver "travado").
- **Medir, não chutar**: na Fase 1 medir no Studio a maior altura que o Humanoid sobe andando com o HipHeight escolhido
  (degraus de 0,2/0,4/0,6/0,9/1,2); gravar em `cfg.degrau.andar`. Os degraus do mapa são 0,2–0,5 (calçada 0,9, asfalto 0,5,
  lote 1,1): o Rastejador tem de passar de rua para calçada e lote **sem ficar parado**.
- **Travado**: o teste atual (1,5 s, 1 stud) ganha escalonamento: 1ª vez → salto; 2ª → recalcula caminho; 3ª → se há parede
  arrombável entre ele e o objetivo, vira objetivo "parede"; senão escolhe ponto de vagar novo.
- Escadas internas: o caminho cuida (ctx.escada). Medir uma subida de escada de prédio e anotar se funciona; se não,
  anotar em pendências (não tentar resolver agora).
- Água: não entra (cada rio tem faixa; o caminho já evita). Sem mudança.

### 5.3 Arrombar parede (`MonstroArrombar`)
1. Alvo da parede: `workspace:Raycast(pos, direção ao objetivo, paramsConstrucoes)` em `Mapa.Construcoes`; vale se o
   acerto for `paredeArrombavel` (classificar por tamanho; **não** depender de atributo novo no mapa). Cache de
   classificação por peça (weak table).
2. Ir até `cfg.arrombar.distanciaGolpe` da parede (usa o `seguirAlvo`; alvo = ponto fora da parede, normal × 3).
3. Bater a cada `cfg.arrombar.intervalo` s: `Acao = "Attack"`, atributo `Vida` da parede (`VidaParede`, lazy,
   `vidaParede(espessura)`), dano `cfg.arrombar.dano`. Cada golpe: `Sons.tocar("GolpeParede", parte, {db = ...})` e
   `Ruido.emitirAcao("paredeQuebrando", posicao, modelo)` (chama os outros monstros: eles seguem a regra "não ouve
   nível igual ou maior", então só níveis acima reagem).
4. Vida 0 → `abrirBuraco(parede, ponto)`: calcula `buraco` e `partesDaParede` no referencial da peça (`CFrame` +
   `Size`), cria os retalhos **clonando** a peça (mesmas propriedades/atributos, `Anchored`, mesmo pai), destrói a original,
   marca os retalhos `Furado = true` (não arrombar de novo o mesmo vão; podem ser quebrados de novo), `Sons.tocar("ParedeCai")`
   e um burst curto de partículas (poeira; um emissor, 0,5 s). Sem animação de queda de peças. Limite `cfg.arrombar.maxBuracos`
   por servidor (acima disso: o monstro desiste da parede e volta a vagar).
5. Não depende de `Ruido` existir (usa `servico`). O raycast de paredes do `processarRuido` passa a contar menos
   paredes sozinho (a peça saiu).
6. Depois do buraco: recalcular caminho já (limpa `alvoCaminho`). O navmesh do Roblox lê a geometria na hora do
   `ComputeAsync`; esperar `cfg.arrombar.esperaNavmesh` s antes de recalcular e testar (a Fase 4 mede se o caminho passa
   pelo buraco; se não passar, seguir em linha reta com `MoveTo` pelo buraco).
7. Janela e porta do gerador têm `CanCollide = false` e `CanQuery = false` e **já são entradas**: o caminho as usa; nunca
   as arrombar.

### 5.4 Veículos (`MonstroObjetivo` + `Veiculos.maisPertoDe`)
- `Veiculos.maisPertoDe(posicao: Vector3, raio: number): Model?` devolve o veículo vivo (não destruído) mais perto do
  ponto, usando o registro `dados` que já existe. Nada mais muda em `Veiculos`.
- Ao chegar a `cfg.veiculo.alcance` da **caixa** do veículo (não do centro), bate a cada `cfg.veiculo.intervalo` s:
  `Regras.parteDoVeiculo` → acha uma peça com atributo `PecaVeiculo` correspondente (pneu/vidro/carroceria) e chama
  `Veiculos.acerto(peca, cfg.veiculo.dano, nil)`. Veículo vira alvo porque faz barulho: parar de bater quando o motor
  desligar e ninguém estiver dentro por `memoria` s.
- **Ocupante**: se o veículo está ocupado e o vidro do lado do banco está `faltando`/`quebrado`, o monstro pode atacar
  o ocupante pelo golpe normal (dano ao jogador, parte sorteada). Com vidro inteiro, só bate no carro. Anotar em
  pendências que isso é uma regra nova para o usuário confirmar.
- Veículo em movimento rápido: não persegue além de `cfg.veiculo.perseguirMax` s; segue o último som como ponto de som.

### 5.5 Dano recebido
`Monstros.dano` continua. Rastejador tem `vida = 80` (nível 1). Armas na malha: o `CanQuery` da malha basta; nenhum
multiplicador de cabeça.

## 6. Percepção (inalterada) e interação com o resto
- `Percepcao` não muda; os novos objetivos só **consomem** `perc.estado/alvo`.
- Cadeia de gritos: continua nível 1 não escutando nível 1; o som de bater na parede (65 dB) também.
- Câmera/HUD: `Estado == "Ataque"` já é tratado (coração).
- Rede: nenhum RemoteEvent novo. Atributos novos do modelo: `Acao`, `AcaoT`, `Altura`.
- Streaming: o modelo é `Atomic`; o cliente nunca faz `WaitForChild` sem timeout.

## 7. `Config/Rastejador.luau` (valores PROVISÓRIOS; marcar com `-- PROVISÓRIO`)

```lua
return {
  altura = { metros = 1.0, jogadorMetros = 1.8 },      -- escala: studs = alturaJogadorStuds / 1.8
  degrau = { andar = 0.5, saltoMax = 2.0, folgaMin = 3.0, margemSalto = 0.6, sondaFrente = 2.5, hz = 10 },
  golpe = { atrasoImpacto = 0.35 },                     -- s do início do Attack até o dano (conferir no clipe)
  objetivo = { histerese = 1.5 },
  arrombar = { fatorDesvio = 2.5, folgaDesvio = 30, espessuraMax = 1.6, alturaMin = 6, vidaPorStud = 80,
               vidaMin = 60, vidaMax = 220, dano = 20, intervalo = 1.2, distanciaGolpe = 3, folgaLargura = 1.6,
               retalhoMin = 0.8, maxBuracos = 150, esperaNavmesh = 0.5 },
  veiculo = { raioBusca = 25, memoria = 6, alcance = 3.5, intervalo = 1.4, dano = 12, perseguirMax = 4,
              tiposDeSom = { "carro", "carroLigar", "carroFalhar", "carroBatida", "buzina", "pneuEstouro" },
              pesos = { pneu = 0.3, vidro = 0.3, carroceria = 0.4 } },
  animacao = { distancia = 150, maxAnimados = 40, nativas = { Walk = 6, Run = 14 } }, -- studs/s do ciclo
}
```

## 8. Fases do agente (cada uma termina verde antes da próxima)

0. **Spike de animação** (§3.2): subir 1 clipe pela Open Cloud, tocar no Studio. Decidir A ou B e escrever o resultado
   em `docs/pendencias-integracao.md`. Parar se pedir Robux.
1. **Regras + Config + testes** (`Regras/Rastejador`, `Config/Rastejador`, `tests/Rastejador.spec.luau`). Medir
   a altura do personagem e o degrau natural no Studio (MCP, place confirmado antes de escrever).
2. **Pipeline do modelo**: `exportar_rastejador.py` (Blender headless, `C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe`),
   `enviar_monstros.py`, `gerar_config_monstros.py`. Render de conferência (frente/lado) e medida em m.
3. **`MonstroModelo` + animação** em jogo, monstro parado e andando, 5 ações conferidas por `screen_capture`.
4. **Movimento** (degraus/salto/travado) e **objetivo** (jogador, veículo). Playtest: rua→calçada→lote sem parar; ataque
   ao jogador com impacto no quadro; carro ligado a 25 studs é mordido (pneu/vidro), parar o motor → para.
5. **Arrombar**: casa fechada (sem caminho curto) com jogador dentro faz buraco permanente; buraco serve a outro monstro.
6. `pwsh scripts/checar.ps1` verde; atualizar `CLAUDE.md` (Estado), `docs/pendencias-integracao.md` (seção Rastejador),
   `docs/calculos.md` (números novos), este arquivo (§ Estado).

Verificação via Studio MCP: confirmar o place antes de escrever; usar `ServerStorage.Teste:Invoke("monstro", "Rastejador")`
e comandos novos que o agente registrar em `Teste` (`"rastejador_arrombar"`, `"rastejador_veiculo"`). Rodar com
`default.project.json` (memória: porta 34872, nunca servir `build.project.json`).

## 9. O que o Opus vai auditar (critérios de aceite)
1. Números só em Config; regras puras testadas; `checar.ps1` verde.
2. Capacidades **só** ligadas no Rastejador; Corcunda/Esfolado e `Monstros.invocar` seguem iguais.
3. Custo: sondas/raycasts só para monstro ativo perto de jogador; sem laço novo por monstro (usa o `laco` existente);
   `calculosSimultaneos` respeitado.
4. Sem falhas silenciosas: erro em módulo novo não derruba a IA (`pcall` com `warn` limitado).
5. Buraco: soma de áreas, sem peça solta, `Anchored`, sem acumular instâncias; `maxBuracos`.
6. Escala: monstro = 1/1,8 do personagem, medido.
7. Decisões fora do contrato registradas em pendências, não resolvidas no código.

## Estado

Escrito e testado em 2026-11-04 pelo agente do Rastejador (Fases 0-6). `pwsh scripts/checar.ps1` verde. Tudo medido no Studio
(`cidade-carros7.rbxl`, Play, Rojo `default.project.json`), sem commit.

**Fase 0 (animação): plano A passou.** A Open Cloud (Assets API v1) aceita `assetType "Animation"` com `.rbxm` de `KeyframeSequence`;
sem pedido de Robux/preço (resposta `Approved`). Os 5 clipes foram enviados. Estrutura que funciona: poses aninhadas pela hierarquia dos ossos
(Hips > Spine > Chest ...), sem pose para o MeshPart; `Animator` dentro do Humanoid do modelo. Toca no servidor e replica para o cliente.
**Medido:** `LoadAnimation` de Walk dá `Length` 1,333 s (32 quadros / 24 fps); com o clipe tocando, 16 ossos tinham `Transform` diferente de zero.
Marcador "Impacto": não existe; o impacto é tempo conhecido (`golpe.atrasoImpacto = 0,75 s`, do p = 0,47-0,57 do clipe de 35 quadros).

**Pipeline (Fase 2).** `ferramentas/modelos/exportar_rastejador.py` (Blender headless) -> `modelos 3d/rastejador/{rastejador.fbx, Monster_1.png,
manifesto.json, anim_blender.json}`; `gerar_anim_rastejador.py` converte para `Bone.Transform` (`anim_roblox.json`); `montar_anim_rbxm.luau`
(Lune) grava os `.rbxm`; `enviar_monstros.py` (`--animacoes`) envia; `gerar_config_monstros.py` gera `Config/MonstrosMalhas.luau`.
Medido: o Roblox importa o FBX **1:1** (1 unidade = 1 stud) e **ignora o `global_scale`** (2,2 ficou 2,2 com global_scale 4,73). Por isso o exportador
escala vértices e ossos nos dados (altura final 2,908 studs; importado = 4,891 x 2,908 x 5,292). O .blend tem até 5 influências por vértice; limitado a 4.
Textura: o `assetId` devolvido é de um Decal; imagem = `120887041573147` (campo `imagemId` em `enviados.json`; "being generated" por alguns minutos).
Conversão Blender -> Roblox (verificada: erro de posição do repouso 0,0000): x' = -x, y' = z - 1,1, z' = y (vezes a escala);
`Transform = Rr^-1 * Gr(pai)^-1 * Gr(osso) * Rr`, com `Rr` o repouso medido no Studio (`rest_roblox_bruto.txt`); não depende de os eixos dos ossos baterem.

**Escala (critério 6).** Personagem medido: bounding box 5,234 studs (R15 escalado, com cabelo). Monstro = 5,234 / 1,8 = **2,908 studs** (malha no Studio: 2,908).

**Degrau (Fase 1).** Humanoid com HipHeight 1,272 (fundo do corpo) e WalkSpeed 14: sobe 1,45, não sobe 1,5 -> `degrau.andar = 1,4`. Com salto de 2,0 + a subida
automática passou até 3,0 (1,9 s, pausa 0,2 s); a classificação continua conservadora (`saltoMax = 2,0`).

**Fase 3 (modelo + animação).** `MonstroModelo`: bloco de colisão 1,331 x 1,452 x 2,661 (cabeça+tronco), `HipHeight` 1,272, malha soldada sem colisão (`CanQuery` true).
Ações vistas por `screen_capture`: Walk, Attack em 0,75 s (garras à frente), Death final (pose achatada); Run e Idle por medição de ossos (juntas de pé/mão 0,14-0,15
acima do chão, sem afundar). **Não visto com a IA real:** Death (só no clone de teste, que flutuava 0,65 por erro meu de posição).

**Fase 4.** Rua(0,5)->calçada(0,9)->lote(1,1) reais (loja_conveniencia_29): 19 studs em 1,3 s, v=14, pausa 0 s. Golpe: `Attack` começa em 0,14 s e a vida do jogador cai 0,76 s
depois; intervalo real 1,5-1,65 s (IA a 5 Hz). Carro (sedan inteiro, som "carro" 80 dB a cada 1 s por 12 s): o monstro deixou carroceria 71->0 e 2 pneus furados;
objetivo "veículo" até 6 s depois do último som, depois volta ao ponto de som.
**Fase 5.** Prédio fechado de teste (4 `Parede` 20x12x1 + laje) em `Mapa.Construcoes`: o monstro A abriu o buraco em 7,2 s e entrou; B/C/D (outros x) entraram em
2,6-3,6 s pelo buraco existente, sem bater. Buraco 2,13 x 4,5; retalhos 230,416 + buraco 9,584 = 240 (soma exata); 8 peças no modelo (sem peça solta, `Anchored`).
**O navmesh do Roblox não enxerga a parede que saiu** (medido: `NoPath` de fora para dentro depois do buraco): `MonstroArrombar` guarda os buracos e outro monstro vai
ao vão e atravessa em linha reta (`MoveTo` direto).

**Mudança de rumo (coordenação, 2026-11-04): `docs/destruicao.md`.** O usuário pediu destruição universal por material; o buraco do Rastejador migra para
`Destruicao.dano` (§6.2 de `destruicao.md`, "bater"). Não se investiu mais em lógica própria de buraco: `abrirBuraco`, `VidaParede`, `Regras.buraco/partesDaParede`
foram **removidos na migração** (2026-11-04, Opus): `MonstroArrombar` agora usa `Destruicao.dano` (tipo "garra"), `Destruicao.vaoUtil` e `Cfg.arrombar.golpesMax`; ver `docs/destruicao.md` "Estado". Outro agente edita pontualmente `server/Veiculos.luau` (ganchos) e
`server/Monstros.luau` (`invalidarCaminhos`): reler antes de editar.

**Não testado / de fora:** escada interna de prédio; FPS e custo do Animator no servidor com ~83 Rastejadores animados (250 monstros no total); Death com a IA real;
vidro lateral quebrado liberando o ataque ao ocupante (código escrito, não exercitado); `perseguirMax` (carro em fuga); teste com 3+ clientes; Walk/Run patinam (ver pendências).

### Tamanho 2x (pedido do usuário, 2026-11-04): 2 m com jogador de 1,8 m

`Config/Rastejador.altura.metros = 2.0` -> 5,816 studs (= 5,234 / 1,8 x 2). Reexportado (`exportar_rastejador.py --altura 5.816`), FBX novo 134924177372078 e os 5 clipes
reenviados (Idle 75498104488794, Walk 72375333938634, Run 134318397938323, Attack 95860538607052, Death 118340794455812; texturas iguais); `MonstrosMalhas` regerado.
As translações dos clipes acompanham a escala sozinhas (`gerar_anim_rastejador.py` usa `escala_blender_para_fbx`); o repouso dos ossos no Studio é exatamente o dobro (posições x2, rotações iguais, conferido em Hips/Foot.R/Hand.L).
**Medido (Studio, Play, `build/rastejador2x.rbxl`):** malha 9,783 x 5,816 x 10,584; bloco de colisão 2,662 x 2,904 x 5,322; HipHeight 2,545; 95 Rastejadores com malha e textura.
Altura do jogador oscila com a pose (bbox 5,12-5,23), a razão fica 1,11-1,14.
- **Degrau:** o Humanoid sobe 2,8 e não sobe 2,9 -> `degrau.andar = 2,7` (era 1,4). `saltoMax` 4,0, `folgaMin` 6,0, `margemSalto` 1,2, `sondaFrente` 5,0 e `travado.saltoAltura` 4,0 foram dobrados (provisórios, sem medida).
- **Dobrados (provisórios):** `arrombar.distanciaGolpe` 6, `raioFolga` 2,7 (metade do comprimento do corpo), `alturaBuraco` 9 (o bloco vai de 2,5 a 5,4 acima do chão), `veiculo.alcance` 7. A largura do buraco = largura do corpo x 1,6 = 4,26 sai sozinha.
- **Caminho:** `AgentHeight` agora = HipHeight + altura do bloco (5,45) para o Rastejador (antes `max(5, Y)`); `AgentRadius` = 2,66 (metade do comprimento do bloco, regra antiga). Mudança mínima em `Monstros.calcularCaminho`.
- **Portas (medidas no mapa):** folhas de porta: 4,1 (84), 4,2 (118), 4,6 (54), 4,8 (582), 5,1 (156), 5,2 (39), 5,6 (14), 6,6 (19), 7,6 (4). Pathfinding de fora para dentro com 5 portas de cada largura, agente 2x (r=2,66, h=5,45): 4,1/4,2 NoPath em 5/5; 4,6 e 4,8 Success em 1/5; 5,1 e 5,2 Success em 5/5; 5,6 1/5; 6,6 1/5; 7,6 0/4. O agente 1x (r=1,33) dava Success em 5/5 nas de 4,1, 5,1, 5,2 e 6,6 e falhava em parte das demais (a sonda é grosseira: NoPath também vem do interior). Conclusão: **a maioria das portas (4,1-4,8: ~840 de ~1080) não deixa o 2x passar; o caminho passa a pedir arrombar** (ver pendências, não decidi nada).
- **Patinação remedida:** ciclo nativo Walk 0,6 un/s x 2,644 = **1,59 studs/s** e Run 3,29 x 2,644 = **8,69 studs/s** (`animacao.nativas`). Com a IA a 6 e 14: Run = 1,61x (sem limite, não patina); Walk = 3,8x, limitado a `velMax` 2,5 -> o clipe anda 3,98 contra 6 studs/s (patina 34%).
- **Visto por screen_capture (clone de teste, tamanho 2x, ao lado do jogador):** Walk (2 instantes) e Attack em 0,75 s (braços à frente). Escala conferida a olho contra o personagem.
- **Não testado no 2x:** a IA completa (Teste, sondas, salto, objetivo veículo, arrombar): neste Studio o `execute_luau` perdeu o acesso ao `ServerStorage.Teste` (erro "additional value for the Capabilities property: Network", também ao criar Script ou `require` dos módulos do servidor), então não consegui injetar ruído nem invocar. Os testes de Fase 4/5 acima valem para o tamanho 1x. Sem teste: se o buraco de 4,26 x 9 resulta bem, ataque com alcance (`distanciaAtaque` 4 do centro, frente do corpo a 2,66), se o corpo 2x cabe nos vãos de caminho do mapa.

**Comandos de teste novos (`ServerStorage.Teste:Invoke`)**: `rastejador_ruido` (x, y, z, db, tipo) e `rastejador_estado`.

### Arrombar casas e velocidade (2026-11-05)

**Place conferido:** `game.PlaceId` 135860309517450; os scripts do place (Monstros, MonstroArrombar/Objetivo/Movimento/Modelo, Destruicao, Config/Monstros, Config/Rastejador,
Regras/Percepcao, Regras/Rastejador) tinham o mesmo tamanho e checksum dos arquivos do repo: **nenhuma edição do usuário só no Studio**. Havia um Play parado (jogador imóvel no
spawn, sem zona de teste nem monstro invocado) que eu parei para sincronizar o Rojo; testes na `Workspace.ZonaTeste` (6000, 300, 6000), apagada no fim, checagem pós-teste "ok: place limpo".

**Por que não quebrava (medido):**
- (a) **confirmado:** `Cfg.arrombar.golpesMax = 25` com dano 20: concreto = 60 golpes, tijolo = 45, madeira = 8 (`Destruicao.golpesPara`, medido). O mapa comercial é todo `Concrete`:
  o monstro descartava toda parede dura e marcava "ruim" por 30 s, nunca batia.
- (b) **provável, não medido isolado:** `dentro(alvo)` testava só o ponto estimado (erro até 15% da distância: 6,75 a 45 studs); com o jogador perto da parede o alvo cai fora da pegada.
- (c) **provável, não medido:** um raio reto e 3 acertos; qualquer rodapé/moldura consultável antes da parede gastava os acertos.
- (d) `desistir = 25 s` era menor que o tempo de quebrar concreto (24 s só de golpes), mesmo com dano maior.
- (e) o jogador dentro só vira alvo a <= `distanciaAtaque`: normal; depois do vão ele corre ao jogador e ataca (visto).

**O que mudou:** `arrombar.dano` 20 -> 60 (garra do 2x: concreto 20 golpes, tijolo 15, madeira 3); `golpesMax` 60; `desistir` 90 s; `MonstroArrombar.dentro` testa também 6 pontos no disco de erro
(`erroDentro = 0.15`); `acharParede` varre 5 raios (`angulos` 0, +-15, +-30 graus, até 5 acertos cada) e `Regras.escolherParede` fica com a de menos golpes (empate: a mais perto);
com o jogador a <= `alvoRealDist = 40` studs o alvo da parede é a posição dele (já o ouviu/atacou), senão o som estimado. A destruição universal (dano, escurecer, vão permanente, ruído
`paredeQuebrando`) não mudou.
**Velocidade por espécie:** `Config/Rastejador.velocidade = { Calmo 8, Investiga 8, Caca 20, Ataque 20 }`, lida por `Regras.velocidade` em `Monstros.velocidadeDe` (só espécies com `capacidades`;
Corcunda/Esfolado seguem `Config/Monstros.niveis`, `Percepcao` intacta). `animacao.velMax` 2,5 -> 3: Run a 20 toca a 2,30x (sem patinar); Walk a 8 pediria 5,0x e fica em 3,0x
(clipe anda 4,8 studs/s, patina 40%).

**Testado (ZonaTeste, concreto, paredes 20 x 12 x 1, laje):**
- Casa fechada, jogador dentro, monstro 45 studs fora: `obj=parede`, bateu 26,7 s (20 golpes), entrou 0,3 s depois, vida 240 -> 200 (golpes de 20 em parte do corpo).
- Casa com porta de 4,2, monstro alinhado com a porta: entrou em 1,9 s sem bater (corpo 2,66 de largura passa; o navmesh com raio 2,66 diria NoPath, o fallback em linha reta passa), vida 147 -> 107.
- Mesma casa, monstro do lado oposto à porta: bateu a parede norte, vão aos 26,3 s, entrou aos 27,0 s, **matou o jogador** (vida 27 -> 15 -> morte).
- Velocidade medida em chão plano: 20 studs/s de Caça (picos 21,1-24,1 na amostragem de 0,3 s/0,1 s). Degraus de 2,0 e 3,5 studs na Caça: passou sem pausa (maior pausa 0,0 s) em ~2,9 s.
**Não testado:** as suspeitas (b) e (c) isoladas; concreto com jogador longe da parede (alvo só estimado); material metal (golpes > 60 continua ignorado); vários monstros na mesma casa; Death com a IA real.
