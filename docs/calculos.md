# Cálculos do jogo (valores iniciais)

Todos os números daqui vão para `src/shared/Config/` e cada fórmula vira uma função pura em `src/shared/Regras/`,
testada em Lune. Os valores marcados **PROVISÓRIO** são o ponto de partida e mudam no playtest. Mudar um número
é editar o Config, sem mexer na regra.

Unidade: 1 stud = 0,28 m (padrão do Roblox). Personagem com WalkSpeed 16 anda 16 studs/s (≈4,5 m/s).

---

## 1. Som (mecânica central)

### 1.1 Ruído emitido
```
ruido_emitido (dB) = base_da_acao + modificador_da_superficie
```
A ação é decidida **no servidor**, pela velocidade do personagem e pelo atributo `Agachado`. O cliente não diz
quanto barulho fez, senão um exploiter ficaria silencioso.

| Ação | base (dB) | | Superfície (`Humanoid.FloorMaterial`) | modificador |
|---|---|---|---|---|
| agachado | 30 | | carpete (`Fabric`, `Carpet`) | −8 |
| andar | 40 | | grama baixa (`Grass`) | −5 |
| correr | 55 | | concreto/asfalto (`Concrete`, `Asphalt`, `Pavement`, `Brick`) | 0 |
| aterrissar (queda < 8 studs) | 50 | | madeira (`Wood`, `WoodPlanks`) | +3 |
| abrir porta | 45 | | grama alta (`LeafyGrass`) | +5 |
| golpe corpo a corpo | 55 | | metal (`Metal`, `DiamondPlate`, `CorrodedMetal`) | +8 |
| quebrar vidro | 75 | | cascalho (`Pebble`, `Slate`) | +6 |
| carro ligado | 80 | | água (`Water`) | +6 |
| tiro de pistola | 110 | | | |
| tiro de fuzil | 120 | | | |

Passos são eventos discretos: um evento de ruído por passo. Ritmo: agachado 1,5 passo/s, andar 2/s, correr 3/s.
O mesmo ritmo move o balanço da câmera (seção 5), então o tremor que o jogador sente é o passo que o monstro ouve.

### 1.2 Ruído ambiente (mascaramento)
| Condição | ambiente (dB) |
|---|---|
| noite calma | 20 |
| dia | 25 |
| chuva | 40 |
| tempestade | 55 |

A cidade está morta (sem trânsito), por isso o ambiente é baixo. Na tempestade correr no concreto (55 dB) fica inaudível,
que é o "o ambiente pode ser barulhento e você pode fazer mais barulho" do Miro.

### 1.3 Propagação e audição
Lei do inverso do quadrado: o som cai 6 dB cada vez que a distância dobra.
```
ruido_recebido = ruido_emitido − 20·log10(distância_em_metros) − 10·paredes_entre   (paredes: máx. 3)
o monstro ouve se: ruido_recebido ≥ ambiente + margem_do_nivel
alcance (studs) = 10^((ruido_emitido − ambiente − margem_do_nivel) / 20) / 0,28   (teto: 600 studs)
```
`paredes_entre` = peças atravessadas por um raycast do som até o monstro (construção em bloco conta como 1).

**Margem por nível** ("quanto menor o nível, mais fácil perceber"; nível 2 "2× mais difícil"): cada nível pede +6 dB,
o que corta o alcance pela metade.

| Nível | margem (dB) | alcance relativo |
|---|---|---|
| 1 | 0 | 100% |
| 2 | 6 | 50% |
| 3 | 12 | 25% |
| Especial | por criatura | — |

### 1.4 Tabela de alcance resultante (studs; 0 = inaudível)
| Ação | Superfície | dB | Noite N1 | Noite N2 | Noite N3 | Dia N1 | Chuva N1 | Tempestade N1 |
|---|---|---|---|---|---|---|---|---|
| agachado | carpete | 22 | 4 | 0 | 0 | 0 | 0 | 0 |
| agachado | grama baixa | 25 | 6 | 0 | 0 | 0 | 0 | 0 |
| agachado | concreto | 30 | 11 | 6 | 0 | 6 | 0 | 0 |
| agachado | grama alta | 35 | 20 | 10 | 5 | 11 | 0 | 0 |
| agachado | metal | 38 | 28 | 14 | 7 | 16 | 0 | 0 |
| andar | carpete | 32 | 14 | 7 | 0 | 8 | 0 | 0 |
| andar | grama baixa | 35 | 20 | 10 | 5 | 11 | 0 | 0 |
| andar | concreto | 40 | 36 | 18 | 9 | 20 | 0 | 0 |
| andar | grama alta | 45 | 64 | 32 | 16 | 36 | 6 | 0 |
| andar | metal | 48 | 90 | 45 | 23 | 50 | 9 | 0 |
| correr | grama baixa | 50 | 113 | 57 | 28 | 64 | 11 | 0 |
| correr | concreto | 55 | 201 | 101 | 50 | 113 | 20 | 0 |
| correr | grama alta | 60 | 357 | 179 | 90 | 201 | 36 | 6 |
| correr | metal | 63 | 504 | 253 | 127 | 284 | 50 | 9 |
| abrir porta | — | 45 | 64 | 32 | 16 | 36 | 6 | 0 |
| golpe corpo a corpo | — | 55 | 201 | 101 | 50 | 113 | 20 | 0 |
| quebrar vidro | — | 75 | 600 | 600 | 504 | 600 | 201 | 36 |
| carro ligado | — | 80 | 600 | 600 | 600 | 600 | 357 | 64 |
| tiro (pistola/fuzil) | — | 110/120 | 600 | 600 | 600 | 600 | 600 | 600 |

Leitura: agachado no carpete de noite só um nível 1 colado em você ouve. Correr no metal à noite chama tudo num raio
de meio quarteirão grande. Um tiro chama o mapa a 600 studs, o que pesa no PvP: matar outro jogador com arma de fogo
tem custo.

### 1.5 Mesmo número para jogadores (PvP)
O som 3D de cada passo toca para os outros jogadores com `RollOffMaxDistance = alcance(ruido, ambiente, margem 0)`.
O jogador ouve o outro mais ou menos onde um monstro nível 1 ouviria. Uma tabela só, sem dois sistemas.

### 1.6 Medidor de decibéis (HUD)
Mostra o ruído do último passo/ação e uma marca no nível do ambiente. Verde: abaixo do ambiente. Amarelo: até +10 dB.
Vermelho: acima de +10 dB.

---

## 2. Monstros

### 2.1 Reação ao som (cegos)
`excesso = ruido_recebido − (ambiente + margem_do_nivel)`, calculado para cada monstro dentro do teto de 600 studs.

| Estado | Entra quando | Faz | Sai quando |
|---|---|---|---|
| Calmo | início | vaga devagar na zona dele | — |
| Investiga | 0 ≤ excesso < 10 | anda até a posição estimada do som | 12 s sem ouvir nada → Calmo |
| Caça | excesso ≥ 10, ou 2 sons em 5 s | corre até a última posição ouvida, atualiza a cada som | 8 s sem ouvir → Investiga |
| Ataque | jogador a ≤ 4 studs (toque) | golpeia | jogador sai do alcance |

Posição estimada = posição real + erro aleatório de raio `distância × 0,15`. Longe, ele erra; perto, acerta.
Monstro nível 1 grita ao entrar em Caça (60 dB, ver Miro: "barulhos que atraem monstros maiores"). Esse grito é
um evento de ruído como qualquer outro e acorda os níveis 2/3 próximos.

### 2.2 Números por nível (PROVISÓRIO)
Referência: jogador anda 16, agachado 8, correndo 24 studs/s.

| | Nível 1 | Nível 2 | Nível 3 |
|---|---|---|---|
| Velocidade calmo / caça (studs/s) | 6 / 14 | 8 / 22 | 10 / 27 |
| Dano por golpe | 20 | 35 | 70 |
| Intervalo entre golpes (s) | 1,5 | 1,2 | 2,0 |
| Vida | 80 | 200 | 600 |
| Por zona (densidade) | 1 a cada 60×60 studs na cidade | 1 a cada 200×200 | 2 no mapa todo |

O nível 1 é mais lento que o jogador correndo (14 < 24): fugir funciona, mas correr faz barulho. O nível 3 corre
mais que você: a única defesa é não ser ouvido.

---

## 3. Corpo (dano por partes, estilo First Aid)

| Parte | Vida | Zerou → |
|---|---|---|
| Cabeça | 30 | morte |
| Torso | 60 | morte |
| Braço esquerdo / direito | 35 cada | não usa arma de duas mãos; mira treme ×2 |
| Perna esquerda / direita | 40 cada | velocidade ×0,6 por perna; sem correr |

Onde o golpe cai:
- **Monstro**: sorteio. Torso 40%, braços 25%, pernas 25%, cabeça 10%.
- **Arma de jogador**: a parte atingida pelo raycast (head, torso, braço, perna do R15). Cabeça ×2 de dano.
- **Queda**: pernas. `dano = (altura − 12) × 3`, dividido entre as duas pernas; abaixo de 12 studs, zero.

Vida que transborda (golpe maior que a parte) passa 50% para o torso. Cura: bandagem +15 numa parte (5 s, faz 25 dB),
kit +40 (8 s). Sem regeneração natural.

---

## 4. Sobrevivência

| Barra | Começa | Cai | Efeito em 0 |
|---|---|---|---|
| Fome | 100 | −1,7/min (≈60 min reais) | −2 vida no torso a cada 10 s |
| Sede | 100 | −2,5/min (≈40 min) | −2 vida no torso a cada 10 s |
| Calor | 100 | depende do lugar (abaixo) | abaixo de 30: estamina máx. ×0,7; em 0: −1 vida em cada parte a cada 10 s |
| Estamina | 100 | correr −12/s (≈8 s de corrida) | sem correr até voltar a 25 |

- Correr multiplica o gasto de fome e sede por 1,5.
- Estamina volta +10/s depois de 1,5 s sem correr; agachado parado +15/s; com fome < 20 a volta é pela metade.
- Calor por minuto: dia ao ar livre 0, noite −1, chuva −3, tempestade −5, dentro de construção +2, perto de fogo +10.
  Roupas (craft, depois) multiplicam a perda por (1 − isolamento).

---

## 5. Câmera (primeira pessoa dinâmica)

```
fase += passos_por_segundo × π × dt           (só com o personagem andando; π por passo)
offset_vertical   = amplitude × |sin(fase)|   (fundo do seno = pé no chão = evento de passo)
offset_lateral    = amplitude × 0,5 × sin(fase / 2)
inclinação (roll) = inclinação_máx × sin(fase / 2)
```
| Modo | amplitude (studs) | inclinação máx. | FOV |
|---|---|---|---|
| agachado | 0,05 | 0,5° | 70 |
| andar | 0,12 | 1,0° | 70 |
| correr | 0,25 | 2,0° | 78 (transição em 0,3 s) |

- Aterrissagem: tremor de `min(velocidade_vertical / 50, 1) × 0,6` studs, decai em 0,25 s.
- Golpe recebido: tremor de 0,4 studs + flash vermelho na borda.
- Monstro em Caça a menos de 40 studs: tremor fino contínuo de 0,03 (o "coração acelerado").
- **Configurações**: tremor ligado/desligado, intensidade 0–100% (multiplica todas as amplitudes), FOV 60–90,
  filtro PS1 ligado/desligado. Tecla V alterna primeira/terceira pessoa.

---

## 6. PvP

Números em `src/shared/Config/Armas.luau` (PROVISÓRIO até o playtest); regras puras em `Regras/Armas`. Vida do corpo: cabeça 30 (arma x2), torso 60, braço 35, perna 40.
"T" = tiros no torso para matar. Dano de arma de fogo é por projétil (escopeta: por chumbinho).

| Arma | Dano | T | Cadência (s) | Pente | Recarga (s) | Cone° | Bloom° (por tiro / máx / recup. por s) | Alcance (studs) | Queda (início → mín.) | Ruído dB |
|---|---|---|---|---|---|---|---|---|---|---|
| Faca | 18 | 4 | 0,5 | | | | | 5 | | 40 |
| Pé de cabra | 28 | 3 | 0,9 | | | | | 6 | | 55 |
| Machado | 40 | 2 | 1,3 | | | | | 6 | | 55 |
| Pistola (9mm) | 25 | 3 | 0,35 | 17 | 1,9 | 1,5 | 0,5 / 3 / 4 | 300 | 80 → x0,55 | 110 |
| Beretta 92FS (9mm) | 28 | 3 | 0,40 | 15 | 2,1 | 1,0 | 0,45 / 2,5 / 4,5 | 330 | 100 → x0,6 | 110 |
| AR-15 (semi, 5,56) | 30 | 2 | 0,16 | 30 | 2,6 | 0,7 | 0,4 / 3 / 5 | 550 | 200 → x0,6 | 120 |
| Carabina M5 (auto, 5,56) | 22 | 3 | 0,085 | 30 | 2,4 | 1,2 | 0,25 / 4,5 / 6 | 350 | 90 → x0,5 | 118 |
| AK-74 (auto, 5,45) | 28 | 3 | 0,092 | 30 | 2,9 | 1,4 | 0,35 / 5 / 5 | 500 | 150 → x0,55 | 122 |
| Escopeta (pump, cal. 12) | 12 x 8 | 1 colado | 0,95 | 5 (tubo) | 0,5 + 0,55/cartucho + 0,4 | 4,5 | 0 | 120 | 15 → x0,15 | 125 |
| Escopeta M1912 (cal. 12) | 10 x 9 | 1 colado | 0,70 | 6 (tubo) | 0,55 + 0,6/cartucho + 0,4 | 6 | 0 | 110 | 12 → x0,15 | 125 |
| Lança-foguetes | explosão 140 | 1 no centro | 1,0 | 1 | 3,8 | 0,5 | 0 | 600 (voo 150 st/s, 4 s) | | 120 (tiro) / 135 (explosão) |

Fórmulas:
- Queda: `fatorQueda = 1` até `queda.inicio`; linear até `queda.minimo` em `alcance`; além disso fica no mínimo. Dano na distância = `dano x fatorQueda` (cabeça x2 depois).
- Espalhamento total (graus) = `(cone + bloom) x multEstado[estado] x multMiraBracoZerado`. `multEstado`: parado 1, andando 1,25, correndo 1,9, agachado 0,7. Braço zerado x2 (Config/Corpo).
- Estado do atirador: correndo (tecla de correr **e** movendo-se acima do limiar) > agachado > andando (velocidade horizontal acima do limiar) > parado.
- Bloom: sobe `porTiro` a cada disparo (teto `maximo`) e cai `recuperacao` graus/s desde o último tiro (nunca abaixo de 0). Escopetas e lançador têm bloom 0.
- Pente: tipo "pente" completa o que a reserva permitir (`recarregarPente`), tempo fixo. Tipo "cartucho" (escopetas): `inicio + n x porCartucho + fim`, com n = cartuchos que cabem e há; atirar interrompe e mantém o que entrou. Pente cheio ou reserva 0 = não recarrega.
- Escopeta: 8 (M1912: 9) raios por tiro, cada um com o cone próprio; soma o dano por parte atingida. Colado: 96 (90) = morte no torso (60); a 30 studs a escopeta faz ~2 tiros.
- Explosão do foguete: `danoCentro x (1 + (fatorBorda - 1) x d/raio)` com raio 20, centro 140, borda x0,25, parede entre explosão e alvo x0,35; torso x1, braços/pernas/cabeça x0,5; atinge o próprio atirador. Construção: raio 18, dano 450; monstro 140; carro 220 (no centro, caindo com a distância).
- Munição por calibre: 9mm, 5,56, 5,45, calibre 12, foguete. Pilhas: 30 / 30 / 30 / 12 / 2. Loot de pente: arma achada nasce com pente entre 40% e 100% (`Itens.penteLoot`).

Morte: o inventário cai numa bolsa no chão (some em 10 min), respawn em 10 s numa vila aleatória com o kit mínimo.
Validação no servidor: distância real ≤ alcance + 2 studs, cadência respeitada e linha de visão por raycast.

## 7. Destruição de construções (PROVISÓRIO; contrato em `docs/destruicao.md`)

Dano efetivo = dano da fonte × multiplicador[tipo de dano][classe do material]. Vida da peça = vida por stud do material × espessura (0,5 a 3 studs); vidro tem vida fixa 10.
Estágios de escurecer em 20/40/60/80% de dano; a peça quebra em 0 e abre um vão (3×6,5 studs para golpe de arma, largura do corpo para monstro e carro).

| Material | Classe | Vida por stud |
|---|---|---|
| Glass | vidro | 10 (fixa) |
| Wood, WoodPlanks | madeira | 150 |
| Sandstone / Limestone / Slate / Brick | alvenaria | 240 / 300 / 300 / 360 |
| Marble / Concrete / Granite / Basalt | alvenaria | 400 / 480 / 520 / 560 |
| CorrodedMetal / Metal / DiamondPlate | metal | 360 / 600 / 900 |
| bomba de combustível (grupo) / tanque (grupo) | — | 150 / 400 |

| Tipo de dano | vidro | madeira | alvenaria | metal | leve |
|---|---|---|---|---|---|
| bala | 6 | 0,5 | 0,25 | 0,2 | 2 |
| corte (faca, machado) | 3 | 1,5 | 0,15 | 0,1 | 3 |
| alavanca (pé de cabra) | 3 | 1,2 | 0,5 | 0,4 | 2 |
| marreta (futuro) | 4 | 1,3 | 1,6 | 0,8 | 3 |
| garra (monstro) | 3 | 1 | 0,4 | 0,15 | 2 |
| impacto (carro) / explosão | 3 / 4 | 1 / 1,5 | 1 / 1,2 | 1 / 0,8 | 1 / 3 |

Golpes para abrir 1 stud: madeira = machado 3, pé de cabra 5, pistola 12, garra 8; tijolo = pé de cabra 26, machado 60, marreta 5; concreto = pé de cabra 35, marreta 6.
Carro: dano de impacto = 0,5 × massa × velocidade² × 1,5e-4 (sedan a 58 studs/s ≈ 380: quebra madeira e quase tijolo); a carroceria perde 15% da vida do material destruído.
Atropelo: (velocidade − 8) × 1,6 de dano, a cada 0,4 s por monstro (58 studs/s ≈ 80).

## 8. Rastejador (2026-11-04; `src/shared/Config/Rastejador.luau`, regras em `Regras/Rastejador`)

- Escala (2x, 2026-11-04): altura = 5,234 (jogador medido) / 1,8 x 2,0 m = 5,816 studs; corpo de colisão 2,662 x 2,904 x 5,322; HipHeight 2,545. (1x eram 2,908; 1,331 x 1,452 x 2,661; 1,272.)
- Degrau (2x): o Humanoid sobe 2,8 (medido) -> `andar = 2,7`; `saltoMax` 4,0, `margemSalto` 1,2, folga mínima 6,0 (dobrados, não medidos). (1x: 1,45 -> 1,4.)
- Golpe: dano no jogador 0,75 s depois do início de Attack (impacto do clipe); jogador a mais de distância de ataque + 2 studs nesse instante = erra.
- Arrombar: vida da parede = clamp(espessura x 80, 60, 220); dano 20 a cada 1,2 s (espessura 1 = 80 = 4 golpes; medido 5-7 s); buraco = 1,6 x largura do corpo (2,13) x 4,5 de altura; sobra < 0,8 vira parte do buraco; até 150 buracos.
- Carro: raio de busca 25, memória do som 6 s, alcance 3,5 da caixa, golpe a cada 1,4 s, dano 12 (pneu 0,3 / vidro 0,3 só com ocupante / carroceria 0,4), perseguição máxima 4 s se o carro for mais rápido.
- Ciclos nativos (2x): Walk 1,59 e Run 8,69 studs/s; Run toca a 1,61x com a IA a 14; Walk pediria 3,8x e fica em 2,5x.
- Animação: Idle 2,5 s, Walk 1,333 s, Run 0,667 s, Attack 1,458 s, Death 1,958 s (24 fps); reprodução limitada a 0,5-2,5x (ver pendências: patinação).
