# Wrapper

Nível 1 · bípede **sem braços**, ~2 m (6 studs) · preset `corpoAriete` · ficha técnica: `docs/wrapper.md`.

**Conceito:** um corpo enrolado que só sabe se jogar contra as coisas. Não agarra, não arranha: investe. Grita quando começa a caçar.

## Já no jogo
- **Percepção:** som, como todos.
- **Locomoção:** calmo 7, investigando 9, caçando 22 studs/s (mais rápido que o Rastejador), mas **curva aberta**: não vira fechado.
- **Ataque (lunge):** a 6 studs do alvo para, investe ~4 studs, impacto em 0,45 s, dano 25; depois fica **1,4 s parado** (recuperação).
  Sem braços: acerta mais tronco, cabeça e pernas (tabela própria de partes).
- **Arrombar:** cabeçada (dano 90 por golpe) com recuperação de 1 s.
- **Grito:** ao entrar em Caça, grita (95 dB, recarga 20 s): o grito é ruído e atrai os outros monstros.
- **Carro:** bate o corpo no carro (mesmos alvos pneu/vidro/lataria).
- **Morte:** sem clipe; o servidor tomba o corpo.

## Habilidade especial (proposta): Grito-sonar
O grito, além de chamar os outros, **revela quem se mexe**: por 1,5 s depois do grito, todo jogador que **se move** num raio de 40 studs vira
alvo de Caça direto (posição exata, sem o erro por distância).
- Contra-jogo: ficar **parado** durante o grito (andar, correr ou atirar entrega). Agachado parado = invisível.
- Sinal: o grito é longo e alto; o HUD de ruído já mostra o dB. Jogador aprende "grito = congela".
- Recarga: a mesma do grito (20 s).

## Comportamento (proposta)
- **Calmo:** anda em linha reta e bate o ombro em postes e paredes (WallSlam leve, sem dano); esse barulho próprio denuncia onde ele está.
- **Investiga:** corre até o ponto, para, balança o corpo ("escutando"); se não acha, grita (sonar) com 50% de chance.
- **Caça:** investida em linha reta. Se o jogador desviar de lado na hora do lunge, ele passa direto e **bate no que estiver atrás** (parede, carro,
  outro monstro): se bater em parede, fica 2 s atordoado.
- **Portas:** não abre porta (não tem mão): arromba.

## Mecânicas e números a decidir
| O quê | Proposta | Observação |
|---|---|---|
| Janela do sonar | 1,5 s, 40 studs | |
| Atordoado após errar contra parede | 2 s | recompensa o desvio lateral |
| Dano em outro monstro ao colidir | 0 ou pequeno | decidir: monstro machuca monstro? |
| Escada | sobe devagar (metade da velocidade) | sem braços para se apoiar |
em vez de um grito, ele tem um sonar q jkoga uma onda(o jogador consegue ver o raio do sonar e se foi atingido( se tiver algo entre os 2 ele n vee com o sonar) se ele te detectar ele se joga na sua direcao igual vc falou)
ele n grita, faz um grito abafado pq n tem boca

## Fraquezas
Curva aberta (fuga em zigue-zague), recuperação depois de cada investida, atordoado ao bater em parede, denuncia a si mesmo batendo nas coisas.
