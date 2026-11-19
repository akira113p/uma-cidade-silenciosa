# Corcunda

Nível 1 · bípede curvado, 2 m (5,8 studs), cabeça pendurada à frente, uma lâmina na mão direita · preset `corcunda` · malha/anim:
`ferramentas/modelos/refazer_monstros.py`.

**Conceito:** o que espera. Anda devagar, quase não faz barulho, e **imita** o que ouviu para trazer o jogador até ele.

## Já no jogo
- **Percepção:** som.
- **Locomoção:** 6 calmo / 14 caçando (números do nível 1). Sobe degrau (2,7 studs, provisório). **Não arromba parede, não ataca carro.**
- **Ataque:** golpe de garra/lâmina com impacto em 0,48 s, a cada 1,5 s, dano 20.
- **Animação:** Idle, Walk (arrastado), Run, Attack (ergue os braços e desce), Death (cai de lado).

## Habilidade especial (proposta): Imitação
Ele **guarda o último som de jogador** que ouviu (passo, porta, tiro, rádio, item caindo) e, depois, **toca esse som** de onde está.
- Para outros jogadores, o som imitado aparece igual a um som real (no HUD e no áudio): parece outra pessoa, um tiro, uma porta.
- Para os **outros monstros**, o som imitado **não conta** (ele não chama concorrência).
- Ele toca o som parado, num canto escuro, e fica de **emboscada**: quem vier conferir chega a ≤ 6 studs e leva o golpe com **dano dobrado**
  (ataque surpresa, só no primeiro golpe).
- Recarga: 25 s. Só imita sons ouvidos nos últimos 60 s.
- Pista para o jogador atento: o som imitado sai **um pouco mais grave** e **sem eco de origem** (ex.: tiro sem cápsula caindo, passos sempre no mesmo ritmo).

## Comportamento (proposta)
- **Calmo:** quase parado; anda pouco e para muito. Prefere becos, interiores e embaixo de escada.
- **Investiga:** em vez de ir até o som, **se esconde perto dele** e espera 10 s; depois imita.
- **Caça:** persegue, mas desiste mais cedo (8 s sem ouvir) e volta a armar emboscada.
- **Em grupo:** nunca anda junto de outros monstros (evita chamar atenção).

## Mecânicas e números a decidir
| O quê | Proposta | Observação |
|---|---|---|
| Sons imitáveis | passo, porta, tiro, item caindo, vidro | voz/rádio só se o jogo tiver voz |
| Dano da emboscada | 2x no 1º golpe | |
| Distância da emboscada | ≤ 6 studs | |
| Ruído do próprio passo | metade do normal | é o mais silencioso |
ele te joga no chao com um impulso, ele abre e fecha porta, ele encherga um pouco
a copia de voz vem com algumas falas em ingles que ele pode falar(baixe as falas dfa internet, falas curtas)

## Fraquezas
Lento, sem arrombar (porta fechada e sem barulho = seguro), desiste rápido, a . Morre com a vida do nível 1 (80).
