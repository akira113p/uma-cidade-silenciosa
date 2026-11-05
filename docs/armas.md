# Armas: arquitetura (11 armas, modelos, animações 1ª e 3ª pessoa, balanceamento)

Pedido do usuário (2026-11-05): implementar todos os itens que já temos (modelos em `modelos 3d/_ps2`), com animações e
balanceamento, para **primeira e terceira pessoa**. Papéis: Opus escreve esta arquitetura e o balanceamento
(`src/shared/Config/Armas.luau` já escrito); agentes Sonnet escrevem o código; Haiku levanta dados.
Regra do fluxo (igual a `rastejador.md`): decisão não prevista aqui → **não decidir**: anotar em
`docs/pendencias-integracao.md`, seção "Armas", e parar naquele ponto (o resto continua). Nada de commit.
Nunca rodar `gerar_mapa.luau --final`. Nunca ler/mostrar `.env`.

## 0. Decisões do usuário (tomadas em 2026-11-05)

1. **Pente + recarga** (tecla R, animação, som, munição reserva no inventário).
2. **Calibres**: 9mm (`municaoPistola`, id mantido), 5,56 (`municao556`), 5,45 (`municao545`, o AK-74 é 5,45x39, não 7,62),
   calibre 12 (`municaoCalibre12`), foguete (`municaoFoguete`) = **5 tipos**. O usuário disse "6 calibres" mas a lista
   mostrada tinha 5 nomes; a conta não fecha: anotado em pendências para confirmar se falta um (ex.: .45 para a `pistola`).
3. **Lança-foguetes**: explosão com dano em área **e** destrói construção (`Destruicao.explosao`).
4. **Props** (Barril, Máquina de vendas, Pombo): **fora desta rodada**.
Não decidido (não implementar, só anotar): mira com zoom (ADS), rajada de 3 tiros, penetração de parede por bala, recuo do
lançador, lentidão ao recarregar, armas nas mãos de monstros, skins, acessórios.

Escala do projeto: **2,908 studs/m** (jogador 5,234 studs = 1,8 m). A Creator Hub diz 1 stud = 0,28 m (3,571 studs/m);
`Config/Som.metrosPorStud` usa 0,28. Incompatível; **não mexer**, anotar em pendências (já levantado em `pesquisa/armas-dados-reais.md`).

## 1. Armas e arquivos de origem

| id (= id do item) | Nome | classe de animação | modelo em `_ps2/` | comprimento real (m) → studs | estado hoje |
|---|---|---|---|---|---|
| `faca` | Faca | faca | `Faca` | 0,30 → 0,87 | existe (bloco) |
| `peDeCabra` | Pé de cabra | contundente | `Pe_de_Cabra` | 0,60 → 1,75 | existe (bloco) |
| `machado` | Machado | machado | `Machado` | 0,80 → 2,33 | existe (bloco) |
| `pistola` | Pistola (Glock-like) | pistola | `Pistola` | 0,20 → 0,58 | existe (bloco) |
| `beretta` | Beretta 92FS | pistola | `Pistola_Beretta` | 0,217 → 0,63 | nova |
| `ar15` | AR-15 | fuzil | `AR15` | 0,90 → 2,62 | nova |
| `carabinaM5` | Carabina M5 | fuzil | `Carabina_M5` | 0,72 → 2,10 | nova |
| `ak74` | AK-74 | fuzil | `AK74` | 0,943 → 2,74 | nova |
| `escopeta` | Escopeta | escopeta | `Escopeta` | 1,05 → 3,05 | nova |
| `escopetaM1912` | Escopeta Trincheira M1912 | escopeta | `Escopeta_M1912` | 1,01 → 2,94 | nova |
| `lancaFoguetes` | Lança-foguetes | lancador | `Lanca_Foguetes` | 0,95 → 2,76 | nova |

Comprimentos de machado/pé de cabra/escopeta genérica não têm fonte (ver `pesquisa/armas-dados-reais.md` §7): são
estimativas minhas; o agente de modelos usa estes números e anota no manifesto. Achados do inventário
(`pesquisa/armas-modelos-inventario.md`): nenhuma tem ossos; Carabina_M5 tem 2292 tris e 21 malhas e texturas `cor_*.png`;
Pistola_Beretta tem 7 texturas (uma por malha); seis manifestos citam textura com sufixo `.001` que não existe na pasta;
o eixo do cano **não consta nos manifestos** (conferir no Blender).

## 2. Balanceamento (já em `Config/Armas.luau`; esta é a lógica)

Corpo: cabeça 30 (x2 arma), torso 60, braço 35, perna 40; morrer = cabeça ou torso em 0. Dado alto de letalidade de propósito
(jogo de silêncio: o tiro é uma decisão, ele chama monstros a 600 studs). As armas se separam por **ruído, pente, munição
rara, coice e espalhamento**, não por TTK. Tiros no torso até matar: faca 4 (3 se cabeça), pé de cabra 3, machado 2,
pistola 3, Beretta 3, AR-15 2, M5 3, AK 3, escopeta 1 colado (96) / 2 a 30 studs, M1912 1 colado (90), foguete 1 no centro.

| Arma | Dano | Cadência (s) | Tiros/min | Pente | Recarga (s) | Cone° | Bloom° (por tiro/máx) | Alcance (studs) | Ruído dB |
|---|---|---|---|---|---|---|---|---|---|
| pistola | 25 | 0,35 | 171 | 17 | 1,9 | 1,5 | 0,5 / 3 | 300 | 110 |
| beretta | 28 | 0,40 | 150 | 15 | 2,1 | 1,0 | 0,45 / 2,5 | 330 | 110 |
| ar15 (semi) | 30 | 0,16 | 375 | 30 | 2,6 | 0,7 | 0,4 / 3 | 550 | 120 |
| carabinaM5 (auto) | 22 | 0,085 | 706 | 30 | 2,4 | 1,2 | 0,25 / 4,5 | 350 | 118 |
| ak74 (auto) | 28 | 0,092 | 652 | 30 | 2,9 | 1,4 | 0,35 / 5 | 500 | 122 |
| escopeta (pump) | 12 x 8 | 0,95 | 63 | 5 (tubo) | 0,5 + 0,55/cartucho + 0,4 | 4,5 | 0 | 120 | 125 |
| escopetaM1912 | 10 x 9 | 0,70 | 86 | 6 (tubo) | 0,55 + 0,6/cartucho + 0,4 | 6 | 0 | 110 | 125 |
| lancaFoguetes | explosão | 1,0 | 1 tiro | 1 | 3,8 | 0,5 | 0 | 600 | 120 / 135 explosão |

Cadências de M5/AK batem com as cíclicas reais (≈700 / 650 rpm). Dano cai com a distância: x1 até `queda.inicio`, linear até
`queda.minimo` em `alcance`. Espalhamento total = (cone + bloom) x `multEstado[estado]` x `multMiraBracoZerado` (Config/Corpo).
Bloom sobe `porTiro` a cada disparo (teto `maximo`) e cai `recuperacao` graus/s parado de atirar. Foguete: `projetil` no Config.
Loot: pistola e munição 9mm como hoje; Beretta/escopetas/rifles só em `guarda`, `fabrica` e (raras) `casa`/`posto`;
M5, AK e **lança-foguetes** as mais raras (peso 1-2). Munição: 9mm 8-16, 5,56 e 5,45 de 10 a 20, calibre 12 de 4 a 8, foguete 1.
Armas encontradas no chão nascem com o pente sorteado entre 40% e 100% (`Itens.penteLoot`).

## 3. Visão geral da arquitetura

```
Cliente (jogador local)                                   Servidor (decide tudo)                         Todos os clientes
 Teclas/mouse ─► ArmasCliente ─► Atacar(origem,dir) ───► Armas.atacar: cadência, pente, origem,           Disparo(s→c) ─► EfeitosArma (clarão, rastro,
   R ─────────►  (previsão local, coice, auto)  Recarregar ► raycast/pellets/projétil, dano, ruído         cápsula) ; Explosao(s→c) ─► efeito + tremor
   mouse ─► Mira(pitch) ─────────────────────────────────► atributos: Pente, Reserva, Recarregando,
 ArmasSinais (disparou/golpeou/recarregou/…)               ArmaEquipada, ArmaSlot ; Player/Character MiraPitch
   ├─► ArmasViewmodel  (1ª pessoa: braços+arma na câmera, molas, passos de recarga)          Animações do corpo R15 (3ª pessoa) tocadas
   ├─► ArmasTerceira   (corpo R15: anima Equip/Idle/Fire/Reload, IK da mão esquerda, mira)   pelo CLIENTE DONO e replicadas pelo Roblox
   └─► EfeitosArma     (clarão local, rastro, cápsula)                                       Arma na mão = Model montado por Shared/ArmaModelo
```

Princípios: servidor decide acerto, dano, pente e ruído (o cliente só pede); animação e efeito são só visuais.
O cliente dono toca as animações de corpo (aparecem na hora para ele e replicam sozinhas para os outros).
Primeira pessoa: viewmodel local (os braços reais e a arma real ficam **invisíveis só para o dono** com
`LocalTransparencyModifier = 1`; os outros jogadores veem o corpo animado normalmente). Terceira pessoa: corpo real animado,
viewmodel desligado. Alternar com V troca na hora.

## 4. Arquivos e donos (um dono por arquivo)

| Arquivo | Conteúdo | Dono |
|---|---|---|
| `src/shared/Config/Armas.luau` | números (pronto, Opus) | Opus |
| `src/shared/Config/Itens.luau` | itens das 7 armas novas, 4 munições novas, tabelas de loot, `penteLoot` | A1 |
| `src/shared/Config/Sons.luau` | sons novos (lista no §10), `confirmado = false` | A1 |
| `src/shared/Regras/Armas.luau` + `tests/Armas.spec.luau` | regras puras novas (§5) | A1 |
| `src/shared/Regras/Braco.luau` + `tests/Braco.spec.luau` | IK de 2 ossos para o viewmodel | A1 |
| `src/shared/Regras/Mola.luau` + `tests/Mola.spec.luau` | mola amortecida (balanço, coice) | A1 |
| `src/shared/Rede.luau` | eventos novos `Recarregar`, `Mira`, `Disparo`, `Explosao` | A1 (só essa linha) |
| `src/server/Armas.luau` | equipar, atacar, pente, recarga, bloom, melee atrasado, Disparo | A2 |
| `src/server/Foguete.luau` | projétil + explosão | A2 |
| `src/server/Inventario.luau`, `src/shared/Regras/Inventario.luau`, `src/server/Loot.luau` | campo `pente` em slot/bolsa; pente de loot | A2 |
| `src/server/Admin.luau` | só se faltar item novo no menu | A2 |
| `ferramentas/modelos/exportar_armas.py`, `armas_modelos.json`, `enviar_armas.py`, `gerar_config_armas.py` | Blender → FBX → Open Cloud → Config | A3 |
| `src/shared/Config/ArmasMalhas.luau` | **gerado** (assetIds, partes, pontos de ancoragem) | A3 |
| `src/shared/ArmaModelo.luau` | monta o Model visual da arma (usa ArmasMalhas; bloco se faltar) | A3 |
| `assets/animacoes/armas/*.json`, `ferramentas/animacao/*`, `src/shared/Config/ArmasAnim.luau` | poses como dado, build, upload, ids | A4 |
| `src/client/ArmasTerceira.luau` | animação do corpo, IK da mão esquerda, mira (pitch) | A4 |
| `src/client/ArmasCliente.luau` (reescrever), `ArmasSinais.luau` (pronto) | entrada, auto, R, previsão, coice | A5 |
| `src/client/ArmasViewmodel.luau`, `src/shared/Config/ArmasVista.luau` | 1ª pessoa | A5 |
| `src/client/EfeitosArma.luau`, `src/client/HudMunicao.luau`, `src/client/Camera.luau` (só `Camera.coice`) | efeitos, HUD, coice | A5 |
| `src/client/InventarioUI.luau` | mostrar pente/calibre no detalhe da arma (mudança mínima) | A5 |
| `src/client/init.client.luau`, `src/server/init.server.luau` | ligar módulos novos (uma linha cada) | A5 (cliente), A2 (servidor) |
| `docs/calculos.md` §6, `docs/pendencias-integracao.md` "Armas", este doc (Estado) | atualizar ao fim | quem terminar por último de cada parte |

Regra de Studio (um só Studio aberto): **só o A4 (animação) pode iniciar playtest** (`start_stop_play`). O A3 (modelos) pode usar
`execute_luau` em modo edição, apenas dentro de `workspace.TesteArmas`, e apaga ao sair. A1, A2 e A5 **não** usam o Studio:
validam por `pwsh scripts/checar.ps1` e Lune. O Opus faz o playtest de integração depois.
Comandos: `lune run tests/X.spec.luau`; tudo: `pwsh scripts/checar.ps1` (rojo build, projetos iguais, testes, selene, stylua).
Estilo: tabs, `--!strict` nos módulos puros, português, comentário que diz o porquê.

## 5. Regras puras (A1) — `Regras/Armas.luau`, assinaturas fixas

As antigas (`podeAtacar`, `origemValida`, `normalizarDirecao`, `espalhar`, `dano`, `multEspalhamento`) **continuam**.
Novas (todas puras, sem Instance, sem `os.clock`):

```
fatorQueda(cfg, distancia): number                 -- 1 até cfg.queda.inicio, linear até cfg.queda.minimo em cfg.alcance; sem queda → 1
danoNaDistancia(cfg, distancia): number            -- cfg.dano * fatorQueda
espalhamentoTotal(cfg, bloom, estado, bracoZerado, cfgArmas, cfgCorpo): number   -- graus; estado ∈ parado|andando|correndo|agachado
bloomAposTiro(cfg, bloom): number                  -- min(bloom + porTiro, maximo)
bloomRecuperado(cfg, bloom, dt): number            -- max(0, bloom - recuperacao*dt)
estadoDoAtirador(agachado, correndo, velocidadeHoriz, limiarAndar): string
podeDisparar(cfg, pente, recarregando, usando): (boolean, string?)   -- motivo "vazio"|"recarregando"|"usando"
recarregarPente(pente, capacidade, reserva): (novoPente, novaReserva, movidas)   -- tipo "pente": completa o que a reserva permitir
cartuchoParaTubo(pente, capacidade, reserva): (novoPente, novaReserva, movidas)  -- 1 cartucho (0 se cheio/sem reserva)
tempoRecarga(cfg, pente, reserva): number          -- pente: cfg.recarga.tempo; tubo: inicio + n*porCartucho + fim (n = cartuchos que cabem e há)
pelotas(cfg): number                                -- cfg.projeteis or 1
danoExplosao(distancia, raio, danoCentro, fatorBorda): number  -- linear de danoCentro (d=0) a danoCentro*fatorBorda (d=raio); 0 fora
```
Testes obrigatórios: queda nas bordas (início, meio, alcance, além), bloom satura/zera, estado (agachado vence correr? definir:
correndo > andando > agachado > parado se correndo; agachado só se parado/andando lento), recarga com reserva menor que o buraco,
com pente cheio (0 movidas), tubo cartucho a cartucho, tempo do tubo com 0/3/5 faltando, `danoExplosao` em 0/raio/fora,
`configuracao coerente`: todas as armas de `Config/Armas` têm `classe`, `municao` com item existente em `Config/Itens` (quando
`tipo = "fogo"`), `pente >= 1`, `recarga` válida, `queda.inicio < alcance`, `modo` ∈ {semi, auto}, item com `arma = id`.
`Regras/Braco.resolver2Ossos(ombro, alvo, polo, l1, l2): (cotovelo, mao)` (vetores {x,y,z}; alvo longe demais estica; polo indica
o lado do cotovelo). `Regras/Mola.passo(estado, alvo, rigidez, amortecimento, dt)` com `estado = {x,y,z,vx,vy,vz}`,
estável para dt até 0,05 (subpassos).

## 6. Rede e atributos

### 6.1 Atributos (servidor escreve)
`Player.ArmaEquipada`, `ArmaSlot` (já existem), mais **`Pente`** (number; cheio ao equipar arma nova de loot sem estado = ver §7.4),
**`Reserva`** (number: soma da munição do calibre no inventário), **`Recarregando`** (bool). `Player.MiraPitch` (number, graus, o servidor
copia do evento `Mira`, limitado a ±80). Todos nil sem arma.

### 6.2 Eventos novos (declarar em `Rede.luau`; validar tudo)
| Evento | Direção | Argumentos | Observação |
|---|---|---|---|
| `Recarregar` | c→s | `()` | R; servidor valida arma de fogo, pente < capacidade, reserva > 0 |
| `Mira` | c→s | `(pitch: number)` | até 8 Hz (`Limite.ok`); `typeof number`, finito, clamp |
| `Disparo` | s→c | `(atirador: Player, armaId: string, origem: Vector3, fim: Vector3)` | para quem está a ≤ `alcanceVisual`, menos o atirador (ele prevê); `fim` = ponto de acerto ou ponta do alcance; escopeta manda 1 por chumbinho agrupado (máx. 3 rastros) |
| `Explosao` | s→c | `(posicao: Vector3, raio: number)` | efeito + tremor por distância |
`Atacar(origem, direcao)` e `Equipar(slot)` não mudam de assinatura.

### 6.3 Sinais locais (`client/ArmasSinais.luau`, pronto)
`disparou(armaId, origem, direcao)`, `golpeou(armaId)`, `vazio(armaId)`, `recarregou(armaId, duracao)`, `recargaFim(armaId, cancelada)`,
`equipou(armaId?)`. Disparados só por `ArmasCliente` (no instante do pedido ao servidor / início da recarga). Escutam:
`ArmasViewmodel`, `ArmasTerceira`, `EfeitosArma`.

## 7. Servidor (A2) — `server/Armas.luau`

### 7.1 Equipar
Mantém as regras atuais (duas mãos com braço zerado, `Usando`, lanterna separada). A arma na mão deixa de ser bloco soldado:
`ArmaModelo.criar(id)` (§8) é montado e preso à `RightHand` por `Motor6D` (`Part0 = RightHand`, `Part1 = Cabo`, `C0 = ArmasAnim.mao.C0`);
nome `ArmaNaMao`, replica para todos. Equipar cancela recarga em andamento. Estado do jogador: `{ ultimo, slot, arma, bloom, ultimoTiro,
recargaId, atrasos }`.

### 7.2 Atacar (fogo)
Ordem de checagem: a atual (limite, tipos, arma, vivo, `Usando`, duas mãos, direção, origem na cabeça, parede cabeça→origem, cadência)
+ `podeDisparar(cfg, pente, recarregando, usando)`: sem pente → `Aviso`/estado `vazio` (sem gastar cadência), com `Recarregando`
→ ignora. Tubo: tiro durante a recarga **interrompe** a recarga (cancela, mantém o que já entrou). Aceito: `pente -= 1` (gravado no
slot, §7.4), `bloom` atualizado (decai por `bloomRecuperado` com o tempo desde o último tiro), `Sons.tocar(cfg.som, cabeca, {db})`,
`Ruido.emitir(cabeca.Position, cfg.ruidoDb, "arma", jogador)`, `Disparo` para os outros. Hitscan: `pelotas(cfg)` raios, cada um com
`espalhar(dir, espalhamentoTotal)`; dano de cada = `danoNaDistancia(cfg, dist)` (x multCabecaArma na cabeça via `Regra.dano`);
soma por (alvo, parte) antes de chamar `Vida.dano` (uma chamada por parte atingida) e `Monstros.dano`; construção/veículo como hoje
(`acertar`). Pelotas contam como um só ruído. Lança-foguetes: não faz raycast, chama `Foguete.lancar(jogador, cfg, origem, dir)`.
Auto: o cliente reenvia `Atacar` no ritmo da cadência; o servidor continua dono da cadência.

### 7.3 Atacar (corpo a corpo)
Valida e **reinicia a cadência na hora**, mas só resolve o golpe `cfg.atrasoImpacto` s depois (`task.delay`), com a origem lida da
cabeça **nesse instante** e a direção enviada (re-validar vivo, mesma arma, não morto; sem custo se saiu do alcance). Som de
golpe toca no pedido, `somAcerto` no impacto. Serve para a animação bater no quadro certo.

### 7.4 Pente por arma (estado no item)
O slot do inventário ganha `pente: number?`. `nil` = **arma de fábrica/ de loot**: tratada como cheia ao primeiro `Equipar`
(grava `pente = cfg.pente`) — **exceto** loot, que o `Loot` já cria com `pente` sorteado em `Itens.penteLoot = {0.4, 1}`.
`Inventario.pente(jogador, slot): number?`, `Inventario.definirPente(jogador, slot, n)`; `Regras/Inventario` e as bolsas/
`LargarItem`/`PegarItem`/kit inicial **preservam** o campo (largar com pente 7 e pegar de volta = pente 7). Sem fugir por
duplicar item. `Pente` e `Reserva` (atributos do Player) atualizam a cada tiro, recarga e mudança de inventário.

### 7.5 Recarregar
`Recarregar` → valida (arma de fogo equipada, `pente < cfg.pente`, `Reserva > 0`, não `Usando`, não `Recarregando`), marca
`Recarregando = true`, `recargaId += 1`, toca os `somRecarga` nos instantes `t x duração`. Tipo **pente**: depois de `tempo` s,
`recarregarPente` e remove a munição do inventário; sem munição suficiente, move o que houver. Tipo **cartucho**: `inicio` s,
depois um cartucho a cada `porCartucho` s (som `somCartucho`), até encher/ficar sem reserva, e `fim` s de bombeio (`somBombear`).
Cancela (sem perder o que já entrou) ao trocar de arma, morrer, largar, usar item, ou atirar (só tubo). `Recarregando` falso ao fim.
Cliente espera `recargaFim`. Não recarrega lançador com a reserva zerada.

### 7.6 Foguete (`server/Foguete.luau`)
`Foguete.lancar`: cria `Part` (cilindro 0,35x1,6, cinza escuro, ponta neon, `PointLight`, `Trail`), velocidade `projetil.velocidade`,
sem gravidade, `CanCollide = false`, `CanQuery = false`, dono da rede = servidor. A cada `Heartbeat`: raycast do ponto anterior ao novo
(ignorando atirador por 0,3 s, zonas/pontos/sons/bolsas); acerto ou fim da vida → `explodir(centro)`:
1. `Destruicao.explosao(centro, raioConstrucao, danoConstrucao, jogador)` (protegido por `pcall`).
2. Jogadores no raio: `danoExplosao(dist, raio, danoCentro, fatorBorda)`; multiplicar por `fatorParede` se um raycast do centro ao torso
   bate em parede; aplicar torso x1, braços e pernas x0,5, cabeça x0,5 via `Vida.dano(jogador, parte, valor, {tipo="jogador", ...})`.
   **Atinge o próprio atirador** (sem atenuação extra).
3. Monstros no raio (`Monstros.ehMonstro` por `GetPartBoundsInRadius`): `Monstros.dano(modelo, danoExplosao(.., projetil.dano.monstro,..), jogador)`.
4. Veículos no raio: `Veiculos.acerto(peca, ...)` na carroceria/pneus com `projetil.dano.carro` caindo com a distância (uma vez por veículo).
5. `Ruido.emitir(centro, projetil.ruidoExplosaoDb, "arma", jogador)`, `Sons.tocar(cfg.somExplosao, ...)`, `Explosao` para quem está a <=700 studs.
Limite global de foguetes ativos (8); `Foguete.limpar` ao encerrar. Teste de Studio: `Teste.registrar("arma", id)` já dá a arma e a munição do
calibre (ajustar para dar 2 pentes de reserva).

## 8. Modelos (A3) — Blender → Roblox

Entrada: `modelos 3d/_ps2/<Pasta>/<Pasta>.blend` (sem filtro novo; se faltar textura em disco, usar o PNG da pasta). Saída por arma:
- `modelos 3d/armas_roblox/<id>/<id>.fbx` (+ textura(s) PNG ≤ 512 px, **uma só** por MeshPart; Roblox MeshPart aceita uma textura):
  juntar objetos por material **ou** assar um atlas único (preferido; senão 1 MeshPart por textura, ver `partes` abaixo).
- Origem do objeto = **ponto da empunhadura** (onde a palma segura), cano para **-Z do Roblox** (frente), cima = +Y.
  Escala em studs: maior lado = comprimento da tabela do §1 x 2,908; **medir o fator de importação (0,28? 1?) com 1 envio de teste**
  e compensar na exportação (documentar). Eixos por geometria (cano = lado longo com a boca mais fina), conferido por render.
- Pontos de ancoragem (studs, espaço da arma, origem = empunhadura): `Boca` (saída do tiro/clarão), `Ejecao` (cápsula),
  `ApoioEsquerdo` (onde a mão esquerda segura, para o IK; armas de uma mão: omitir), `Mira` (olho; opcional).
- Manifesto `modelos 3d/armas_roblox/manifesto.json` com triângulos (≤ 3000 por arma; Carabina M5 pode passar de 1500 do filtro, o teto
  do Roblox é 20 000) e dimensões. Renders de conferência (2 ângulos por arma) em `modelos 3d/armas_roblox/renders/` — **olhar as imagens**.
- Envio pela Open Cloud como `Model` no mesmo fluxo de `enviar_veiculos.py`/`enviar_monstros.py`
  (`pesquisa/pipeline-upload-animacao.md`): texturas enviadas como imagem; atenção ao id de **Decal x imagem**. Chave no `.env` (não ler).
- `Config/ArmasMalhas.luau` (gerado): `[id] = { partes = { { malha = "rbxassetid://…", textura = "rbxassetid://…" | false, posicao = {x,y,z}, tamanho = {x,y,z} } },
  ancoras = { Boca = {x,y,z}, Ejecao = {…}, ApoioEsquerdo = {…}?, Mira = {…}? }, comprimento = studs }` ou `false` se o envio falhou.
- `Shared/ArmaModelo.criar(id, opcoes?) -> Model`: `Cabo` (Part invisível 0,2, PrimaryPart, `CanCollide/CanQuery/CanTouch = false`, `Massless`),
  um `MeshPart` por parte soldado ao Cabo, `Attachment` com os nomes de `ancoras` dentro do Cabo; sem `ArmasMalhas[id]` cai no bloco
  provisório antigo (`warn`, não quebra). Sem sombra (`CastShadow = false`). Segura as 11 armas, uma função só.
- Verificação: carregar cada malha com `InsertService:LoadAsset` no Studio (edição, `workspace.TesteArmas`), conferir `Size` de cada MeshPart
  contra o manifesto (tolerância 5%) e tirar `screen_capture` de uma fileira com as 11. Se a escala/giro vier errada, corrigir na exportação.

## 9. Animação do corpo (3ª pessoa) — A4

Rig R15 do jogador (blocos por cima, `Config/Aparencia`). Animações são **KeyframeSequence por classe**, escritas como dados
(`assets/animacoes/armas/<classe>.json`, formato da skill `animacao-roblox`), montadas por Lune (`@lune/roblox`, base em
`ferramentas/modelos/montar_anim_rbxm.luau`) e enviadas como `Animation` pela Open Cloud (reaproveitar `enviar_monstros.py --animacoes`;
**se a API pedir Robux ou der erro de preço, parar e anotar**: não gastar Robux). Ids em `Config/ArmasAnim.luau`.

| Classe | Armas | Clipes (duração) |
|---|---|---|
| faca | faca | Idle (laço), Equip 0,35, Golpe1 estocada, Golpe2 corte lateral (alternam) |
| contundente | pé de cabra | Idle, Equip 0,4, Golpe (swing lateral; impacto em 0,25 s) |
| machado | machado | Idle (duas mãos), Equip 0,5, Golpe (de cima; impacto em 0,35 s) |
| pistola | pistola, Beretta | Idle, Equip 0,35, Fire 0,15 (coice), Reload 1,9→2,1 (esticar com `AdjustSpeed`) |
| fuzil | AR-15, M5, AK | Idle (duas mãos), Equip 0,5, Fire 0,12, Reload 2,4→2,9 |
| escopeta | 2 escopetas | Idle, Equip 0,5, Fire+Bombear 0,7, RecargaInicio 0,5, RecargaCartucho (0,55, repete), RecargaFim 0,4 |
| lancador | lança-foguetes | Idle (ombro), Equip 0,6, Fire 0,3, Reload 3,8 |
Prioridades: Idle/hold = `Action` (mexe só em braços/tronco; pernas ficam com o andar do jogo), Equip/Fire/Golpe = `Action2`,
Reload = `Action3`. Impacto do golpe no tempo de `atrasoImpacto` (marcador `Impacto`). Duração do Reload/Equip ajustada por
`AdjustSpeed(duracaoClip / tempoConfig)` para casar com `Config/Armas.recarga`.
Pose da arma: `Config/ArmasAnim.mao = { C0 = CFrame…, porClasse = {…} }` calibrada no Studio para a palma segurar o `Cabo`.
**Mão esquerda por `IKControl`** (`ChainRoot = LeftUpperArm`, `EndEffector = LeftHand`, `Target = Attachment ApoioEsquerdo` da arma),
ligado em armas de duas mãos exceto no Reload/Equip (a mão esquerda anima), peso suave 0,25 s. Se `IKControl` não funcionar neste rig
(medir por 3 quadros), fallback: o clipe leva a mão esquerda num ponto médio por classe e o `ApoioEsquerdo` ajusta só `C0` do ombro
(anotar em pendências qual foi usado).
**`client/ArmasTerceira.luau`**: escuta `equipou/disparou/golpeou/recarregou/recargaFim`, escolhe o clipe, toca no `Animator` do próprio
personagem, mantém o Idle enquanto há arma, e aplica a **mira**: `MiraPitch` (próprio: direto da câmera; outros jogadores: atributo
replicado) vira rotação em `Waist`/`Neck`/ombros via `Transform` a cada `RenderStepped`, só para personagens a ≤ 150 studs. Envia `Mira` (8 Hz).
Verificação: `screen_capture` em 4-6 instantes por clipe (folha de quadros), olhado pelo agente; pé não desliza; arma não atravessa o corpo;
silhueta legível de lado e de frente; o corpo de **outro** jogador (cliente de teste) mostra a arma na mão e a pose.

## 10. Primeira pessoa e cliente (A5)

### 10.1 Entrada e previsão (`ArmasCliente`, reescrever mantendo mira e marcador de acerto)
Clique esquerdo segurado dispara no ritmo de `cadencia` (semi: um por clique, solta e clica de novo; auto: continua). R recarrega
(`Config/Movimento.teclas.recarregar = {"R"}`; botão no celular). Previsão local: contador `penteLocal` (sincroniza com o atributo
`Pente` quando não houve tiro nos últimos 0,3 s), recusa se vazio (dispara `vazio` + clique), nega durante `Recarregando`. Em cada tiro:
`ArmasSinais.disparar("disparou", …)`, `Rede.Atacar(origem, direcao)`, coice (`Camera.coice(vertical, horizontal)`, só se
`Pref_Tremor` ligado; respeita `Pref_Intensidade`). Origem/direção como hoje (1ª pessoa = câmera; 3ª pessoa = cabeça mirando o ponto da câmera).
Melee: `golpeou`, alterna golpe 1/2 da faca. Esc/menu aberto não atira.

### 10.2 Viewmodel (`ArmasViewmodel` + `Config/ArmasVista`)
Só em 1ª pessoa com arma. Model local em `workspace.CurrentCamera`: dois braços (blocos: manga na cor do suéter, mão na cor da pele,
medidas de `Config/Aparencia`/R15, `CastShadow = false`, `CanQuery = false`) e `ArmaModelo.criar(id)`. Posição = `câmera.CFrame x offset da classe`
+ molas (`Regras/Mola`): balanço pelo andar (`Camera` já tem fase de passo), sway pela rotação da câmera, coice (empurra para trás/cima e
volta), queda ao correr (arma abaixada), recuo se há parede perto (raycast curto da câmera; arma sobe). Mão direita no `Cabo`, mão esquerda no
`ApoioEsquerdo` (armas de duas mãos) — cotovelos por `Regras/Braco.resolver2Ossos` com o polo para fora/baixo. Estados por dado em
`ArmasVista` (por classe: `base` pos/rot, `apoio`, e listas de passos `{t (0..1), pos, rot}` para `sacar`, `recarga`, `bombear`, `golpe1`, `golpe2`),
interpolados com easing; duração de `recarga`/`sacar` = a de `Config/Armas` (sinal `recarregou(armaId, duracao)`). Esconde o corpo real
(braços, mãos e `ArmaNaMao` do próprio personagem) com `LocalTransparencyModifier = 1` **só enquanto o viewmodel está ativo**; ao ir para 3ª pessoa,
desarmar ou morrer, desfaz (e `client/Aparencia` continua mandando na cabeça). Não duplica sombra/filtro: conferir com o filtro ligado
(aberração por ViewportFrame) se o viewmodel aparece uma vez só; se duplicar, anotar em pendências e usar o plano B (arma real animada, sem viewmodel).

### 10.3 Efeitos e HUD
`EfeitosArma`: clarão na `Boca` (Neon 1-2 quadros, `PointLight` 0,05 s; no viewmodel e no `ArmaNaMao` dos outros via `Disparo`), rastro curto
(retângulo Neon esticado da boca ao `fim`, 0,06 s, até 3 por tiro de escopeta), cápsula (`Ejecao`, 1 pequeno bloco que cai 2 s, até 12 vivos),
fumaça rápida do cano, marca de bala no ponto de acerto (decal pequeno 8 s, máx. 40, só em Parts do mapa; opcional se custar), explosão (esfera
Neon que cresce e some + fumaça + tremor `Camera.tremer` proporcional ao inverso da distância). Estética PS1: poucos quadros, sem partículas caras.
`HudMunicao`: canto inferior direito, "PENTE / RESERVA" (ex.: `12 / 45`), nome da arma e calibre; vermelho com pente 0; barra fina de recarga;
some sem arma de fogo. `InventarioUI`: detalhe da arma mostra pente atual e calibre. Mira: ponto central que abre com o espalhamento visual
(simples: raio = bloom local, só estética, sem decidir nada).

## 11. Sons (A1 + Haiku D)
Candidatos achados pelo Haiku em `pesquisa/armas-sons-candidatos.md`. Novos nomes lógicos em `Config/Sons`: `TiroFuzil`, `TiroEscopeta`,
`TiroFoguete`, `ExplosaoFoguete`, `RecargaPenteSai`, `RecargaPenteEntra`, `RecargaFuzil`, `RecargaFoguete`, `Bombear`, `InserirCartucho`,
`CliqueVazio`, `EquiparArma`, `BalancoPesado` (machado), `CartuchoCai` (opcional). `confirmado = false` em todos (o usuário ainda precisa ouvir).
Sem candidato → reaproveitar o mais parecido (anotar em pendências).

## 12. Verificação final (Opus)
`pwsh scripts/checar.ps1` verde; rojo serve (`default.project.json`, porta 34872) + playtest no Studio: dar cada arma (`ServerStorage.Teste:Invoke("arma", id)`),
atirar nos monstros, recarregar (pente/tubo), esvaziar, trocar de arma no meio da recarga, morrer com a arma (bolsa preserva o pente), foguete contra
parede (vão) e contra carro, 1ª e 3ª pessoa (V), outro cliente vendo a pose; sem erro no console. Números aprovados pelo usuário deixam de ser PROVISÓRIO.

## Estado (2026-11-05)
- **Pronto e verde em `checar.ps1` (nada testado no Studio ainda):** A1 regras/itens/sons/rede, A2 servidor (`Armas`, `Foguete`, pente no inventário), A5 cliente
  (`ArmasCliente`, `ArmasViewmodel`, `ArmasVista`, `EfeitosArma`, `HudMunicao`, `Camera.coice`, `InventarioUI`), A3 exportação Blender das 11 armas + `ArmaModelo`.
- **Bloqueado:** a Open Cloud responde 403 "User is moderated" a toda chamada depois do envio da Faca. Enviados: Faca, Pistola, Beretta (só a Beretta ligada em `Config/ArmasMalhas`);
  faltam 8 malhas e todas as animações. Retomada: `docs/pendencias-integracao.md` "Armas" (bloco A3). Studio do place do jogo caiu; `workspace.TesteArmas` ficou sujo.
- **Falta (playtest do Opus, §12):** afinar poses de `ArmasVista` (chutes), conferir `LocalTransparencyModifier` dos braços, foguete (voo, vão na parede, carro),
  recarga de tubo, 3ª pessoa com animações, loot, pesos e números.
