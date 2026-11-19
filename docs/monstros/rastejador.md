# Rastejador

Nível 1 · quadrúpede, 2 m de altura (5,8 studs), corpo comprido · preset `quadrupedeArrombador` · fichas técnicas: `docs/rastejador.md`, `docs/preset-monstro.md`.

**Conceito:** a coisa que entra. Anda de quatro, baixo e rápido; se você se trancou numa casa fazendo barulho, ele abre a parede.

## Já no jogo
- **Percepção:** som (Calmo/Investiga/Caça). Investiga o ponto estimado do som (erro cresce com a distância).
- **Locomoção:** 8 studs/s calmo e investigando, 20 caçando (o jogador corre 16, sprint 24). Sobe degraus até 2,7 studs andando e **salta** até 4.
- **Ataque:** garra, impacto 0,75 s após começar o golpe, a cada 1,5 s; dano por parte do corpo (sorteio).
- **Arrombar:** escolhe a parede mais fraca entre ele e o alvo (5 raios), bate até abrir (concreto ~20 golpes, tijolo 15, madeira 3), cria vão
  permanente do tamanho do corpo; desiste depois de 90 s.
- **Carro:** carro ligado e barulhento atrai; morde pneu, vidro e lataria. Ocupante só é atacado com o vidro lateral quebrado.

## Habilidade especial (proposta): Pulso no chão
Ele encosta o corpo no chão e **sente vibração**: por alguns segundos ouve **passos andando** (não só correndo) num raio curto.
- Gatilho: no estado Investiga, quando chega ao ponto estimado e não acha nada; para, encosta a barriga no chão (pose de Idle mais baixa), 2 s.
- Efeito: durante 4 s, passos andando a ≤ 25 studs contam como som (hoje andar quase não faz barulho). **Agachado e deitado não contam.**
- Fraqueza: parado no chão, ele não ataca nem anda; é a janela para sair andando agachado ou acertar um tiro.
- Recarga: 15 s por monstro.
- Sinal ao jogador: som grave de raspar e o corpo achatado. Quem conhece o sinal, agacha.

## Comportamento (proposta)
- **Calmo:** vaga rente às paredes e sob carros abandonados; prefere sombra. Para de vez em quando com a cabeça inclinada (já no Idle).
- **Investiga:** anda em zigue-zague curto até o ponto; usa o Pulso ao chegar.
- **Caça:** linha reta até o som; se a linha cruza parede fina, arromba em vez de contornar (já é assim).
- **Grupo:** quando um Rastejador arromba, o barulho da parede (já é ruído) atrai os outros: uma casa aberta vira ponto de encontro.

## Mecânicas e números a decidir
| O quê | Proposta | Observação |
|---|---|---|
| Raio do Pulso | 25 studs | medir com passos reais |
| Duração / recarga | 4 s / 15 s | |
| Andar agachado | imune ao Pulso | dá valor ao agachar |
| Subir em telhado | não | é rasteiro; telhado vira refúgio contra ele (mas não contra o barulho) |
ele tem q dar mais danbo nas paredes( e quebrar mais rapido, e fazer uym buraco maior, e uma vez q entrar numna casa, procura pelo jogador dentero dela)

## Fraquezas
Barulhento ao arrombar (denuncia onde está), parado durante o Pulso, não sobe em telhado, só pega ocupante de carro com vidro quebrado.
