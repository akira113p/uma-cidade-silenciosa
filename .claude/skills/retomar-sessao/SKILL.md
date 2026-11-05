---
name: retomar-sessao
description: Retoma o trabalho do canal no começo de uma sessão. Lê CLAUDE.md, docs/decisoes.md, o handoff mais recente e a lista de pesquisas, e devolve o estado atual e o próximo passo. Use no início de qualquer sessão ou quando o usuário perguntar "onde paramos".
---

O usuário trabalha cerca de 2 horas por semana, então toda sessão começa fria. Faça nesta ordem, sem perguntar nada antes:

1. Leia `CLAUDE.md`.
2. Leia `docs/decisoes.md` (decisões e pendentes).
3. Leia o arquivo mais recente de `docs/handoff/`, se existir.
4. Liste `pesquisa/` (só os nomes).
5. Confira se algo no estado mudou desde o handoff: `git status` se for repositório, e a existência de `../openmontage`.

Responda em no máximo 10 linhas, em português:
- Decisões já tomadas (uma linha cada).
- Perguntas pendentes.
- O que ficou pela metade.
- **Próximo passo único recomendado** para as próximas 2 horas.

Não refaça pesquisa já salva em `pesquisa/`: cite o arquivo. No fim da sessão, lembre o usuário de rodar `/handoff`.
