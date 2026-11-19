# Monstros: fichas de design

Escrito em 2026-11-14. Uma ficha por monstro **que já tem modelo e está no jogo**. Cada ficha separa:
- **Já no jogo**: o que o código faz hoje (fonte: `Config/Monstros`, `Config/PresetsMonstro`, `docs/rastejador.md`, `docs/wrapper.md`).
- **Proposta**: habilidade especial e mecânicas novas. **Nada de "Proposta" está decidido**: o usuário aprova, corta ou muda antes de virar código
  (registrar em `docs/decisoes.md` com a skill `registrar-decisao`).

Regra comum a todos (não muda): são **cegos**, caçam **pelo som** (`Regras/Percepcao`: Calmo → Investiga → Caça). Toda habilidade nova
precisa conversar com o som: ou usa o som, ou cria som, ou dá ao jogador um jeito silencioso de escapar.

| Monstro | Nível | Corpo | Papel no jogo | Habilidade especial (proposta) | Ficha |
|---|---|---|---|---|---|
| Rastejador | 1 | quadrúpede 2 m | caçador de casa: arromba paredes | **Pulso no chão**: sente vibração de passos pelo piso | [rastejador.md](rastejador.md) |
| Wrapper | 1 | bípede sem braços ~2 m | aríete: investida e grito | **Grito-sonar**: o grito revela quem se mexe | [wrapper.md](wrapper.md) |
| Corcunda | 1 | bípede curvado 2 m | espreitador paciente | **Imitação**: repete sons para atrair o jogador | [corcunda.md](corcunda.md) |
| MonstroPS1 | 1 | humanoide de lâminas 2 m | duelista rápido de perto | **Arrastar lâminas**: faísca que cega e marca rota | [monstrops1.md](monstrops1.md) |
| Florescida | 3 | quadrúpede gigante 5,5 m | chefe errante do mapa | **Florescer**: planta flores-sentinela que ouvem por ela | [florescida.md](florescida.md) |

Fora desta lista: **Esfolado** (modelo pronto, fora do jogo por moderação da textura) e os que ainda são blocos (Espreitador, Carniceiro, Pernalta).

## Como os papéis se completam
- Nível 1 tem quatro jeitos diferentes de pressionar o jogador: **entrar** (Rastejador), **correr atrás** (Wrapper), **enganar** (Corcunda) e
  **cortar de perto** (MonstroPS1). Nenhum é "o mesmo monstro com outra malha".
- A Florescida é rara e muda a região inteira: o jogador **evita** em vez de enfrentar.
- Todo monstro tem uma **fraqueza legível** (janela de recuperação, cegueira momentânea, barulho próprio), para o PvP de sobrevivência não virar só fuga.
