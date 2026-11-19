# MonstroPS1

Nível 1 · humanoide magro, 2 m (5,8 studs), **lâminas longas no lugar dos dedos** · preset `monstroPS1` · malha/anim: `refazer_monstros.py`.

**Conceito:** o duelista. Corpo de gente, mãos de faca. Anda curvado com as lâminas penduradas quase no chão; perto, é o mais perigoso do nível 1.

## Já no jogo
- **Percepção:** som.
- **Locomoção:** 6 calmo / 14 caçando. Sobe degrau (2,4 studs, provisório). **Não arromba, não ataca carro.**
- **Ataque:** ergue as duas lâminas e cruza para baixo; impacto em 0,48 s, a cada 1,5 s, dano 20.
- **Animação (refeita em 2026-11-14):** tronco curvado, braços pendurados com as lâminas balançando; corrida com braços para trás.

## Habilidade especial (proposta): Arrastar lâminas
Em Caça, quando o alvo está a 15–40 studs, ele **arrasta as lâminas no chão** e dispara em linha reta (arrancada curta).
- Efeito: arrancada de 1,5 s a 26 studs/s e **rastro de faíscas** no chão (luz laranja que dura 6 s).
- As faíscas **iluminam** a área (à noite e na névoa o jogador vê ele chegando) e **fazem barulho** contínuo de metal (ruído): ele mesmo se denuncia.
- Se a arrancada termina perto do alvo, emenda um golpe duplo (duas lâminas, dano 15 + 15).
- Recarga: 12 s.

## Mecânicas extras (proposta)
- **Corta obstáculos leves:** cerca de madeira, porta de madeira e vidro **cortam** em 1–2 golpes (dano `garra` alto contra madeira/vidro na
  `Destruicao`); concreto e tijolo não. É o "arrombar" dele, só para material fraco.
- **Bloqueia tiro de frente:** em Caça, com as lâminas cruzadas na frente, tiro de **pistola** no tronco por trás das lâminas faz metade do dano;
  rifle/escopeta passam. Recompensa flanquear.
- **Parry por barulho:** quando leva um golpe corpo a corpo (machado, pé de cabra), as lâminas batem com som alto (ruído 80 dB): briga de
  perto com ele atrai outros monstros.

## Comportamento (proposta)
- **Calmo:** anda em círculos lentos raspando a ponta das lâminas no chão (som baixo e constante: dá para ouvir de longe e evitar).
- **Investiga:** anda até o ponto com as lâminas erguidas; para e "escuta" girando o tronco.
- **Caça:** aproxima, arrancada, golpe duplo.

## Mecânicas e números a decidir
| O quê | Proposta | Observação |
|---|---|---|
| Arrancada | 1,5 s, 26 studs/s, 15–40 studs do alvo | |
| Golpe duplo | 15 + 15 | |
| Redução de dano de pistola pela frente | 50% | só pistola |
| Cortar madeira/vidro | 1–2 golpes | ligar `Destruicao` com tipo `lamina` |
ele lanca as facas, da pouco dano,  e tem baixa precisao

## Fraquezas
A arrancada é em linha reta (passo de lado esquiva); as faíscas e o raspar o denunciam; fraco contra rifle e escopeta; recarga longa da arrancada.
