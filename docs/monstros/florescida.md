# Florescida

**Nível 3** · quadrúpede **gigante**, 5,5 m (16 studs), corpo de cervo podre, chifres, cauda longa, mandíbula que abre · preset `florescida` ·
malha/anim: `refazer_monstros.py`. Decisão do usuário (2026-11-14): forte e gigante, nível alto.

**Conceito:** o chefe errante. Não é para lutar: é para **mudar o mapa** por onde passa. Onde ela anda, a cidade fica mais perigosa.

## Já no jogo
- **Percepção:** som. Nasce no mapa por `nascerSempre` (mesmo com só o nível 1 ativo).
- **Números do nível 3:** vida 600, dano 70, golpe a cada 2 s, 10 studs/s calma, 27 caçando.
- **Capacidades:** sobe degrau (provisório), **arromba** (vão de 16 studs, dano 120 por golpe, provisório), **ataca carro**.
- **Ataque:** empina, recolhe o pescoço e morde para baixo; impacto em 0,48 s.
- **Animação:** anda de quatro com as mãos no chão; cauda e mandíbula animadas; morte tomba de lado.

## Habilidade especial (proposta): Florescer
Por onde ela passa, **planta flores-sentinela** (malha pequena, pétalas pálidas, brilho fraco).
- A cada 30 s andando, deixa 1 flor no chão (máximo 12 por Florescida no mapa; a mais antiga murcha).
- A flor **ouve**: qualquer som a ≤ 20 studs de uma flor chega à Florescida **como se ela estivesse ali** (sem erro de distância).
  Ela então caminha até lá, mesmo do outro lado do mapa.
- A flor **pode ser destruída** (1 golpe de arma branca ou 1 tiro), mas destruí-la **faz barulho** (estalo, 70 dB): ela ouve e vem.
  Destruir em silêncio só **agachado com faca**.
- Efeito visual: perto de flores a névoa fica levemente esverdeada (o jogador aprende a ler a área "marcada").

## Mecânicas extras (proposta)
- **Pisotear:** ao andar em Caça, derruba postes, cercas e carros abandonados no caminho (dano de atropelo da `Destruicao`); o barulho atrai
  monstros menores, que a seguem como **escolta**.
- **Rugido de chão:** ao entrar em Caça, bate as patas dianteiras: todo jogador a ≤ 30 studs **cai** (fica no chão 1,5 s, como o deitar) e a câmera treme.
- **Grande demais para entrar:** não cabe em prédio; em vez de arrombar casa, **arranca o telhado/parede da frente** e enfia a cabeça (alcance
  da mordida aumenta para dentro de cômodos térreos). Prédio alto de concreto = refúgio.
- **Cauda:** golpe de cauda em quem estiver **atrás** dela (dano 35, empurra 10 studs). Atrás não é ponto cego.

## Comportamento (proposta)
- **Calmo:** atravessa o mapa devagar entre regiões (cidade → floresta → vila), parando para florescer. Fica sempre em movimento.
- **Investiga:** vai ao som; se for som vindo de flor, vai direto e rápido.
- **Caça:** rugido de chão, persegue; se o alvo entra em prédio de concreto, ronda o prédio por 60 s mordendo janelas e depois desiste.
- **Raridade:** 1 por servidor (no máximo 2). Quando ela chega numa região, os sons ficam abafados (sinal de aviso a quem conhece).

## Mecânicas e números a decidir
| O quê | Proposta | Observação |
|---|---|---|
| Quantidade por servidor | 1 (máx. 2) | hoje nasce pela densidade normal: **precisa de limite** |
| Flores | 1 a cada 30 s, máx. 12, raio de escuta 20 | |
| Rugido de chão | 30 studs, queda 1,5 s, recarga 30 s | |
| Golpe de cauda | 35 + empurrão 10 studs | |
| Arrombar | arranca telhado/fachada térrea | substitui o vão de 16 studs, que destruiria andares |
ele e mais rapido q um carro normal(chega a 50kmh e n entra em cidsades grandes)

## Fraquezas
Lenta para virar, não entra em prédio de concreto, as flores podem ser destruídas em silêncio, só existe 1. Vida alta (600): matar exige grupo.
