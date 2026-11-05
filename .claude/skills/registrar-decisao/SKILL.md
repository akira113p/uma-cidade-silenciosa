---
name: registrar-decisao
description: Registra em docs/decisoes.md uma decisão que o usuário acabou de tomar sobre o canal (nicho, voz, estilo, formato, cadência, orçamento, critérios de parada). Use quando o usuário responder uma pergunta de decisão, aprovar ou rejeitar uma opção, ou depois de cada rodada do grilling.
---

Registre em `docs/decisoes.md` (crie o arquivo se não existir), uma entrada por decisão, no topo da lista:

```
## AAAA-MM-DD · <título curto>
- Decisão: <o que foi decidido, em uma frase>
- Motivo: <por que, nas palavras do usuário quando possível>
- Substitui: <decisão anterior, se houver>
```

Regras:
- Só registre o que o **usuário** decidiu ou aprovou. Recomendação sua, sugestão de subagente e pergunta ainda sem resposta não são decisão: vão em "Pendentes", no fim do arquivo.
- Se a decisão contradiz uma anterior, não apague a antiga: marque "Substitui".
- Depois de registrar, atualize no `CLAUDE.md` do projeto a seção "Decisões tomadas" só se a decisão mudar uma das linhas que já estão lá. Não copie o histórico para o `CLAUDE.md`.
- Responda em uma linha dizendo o que foi registrado.
