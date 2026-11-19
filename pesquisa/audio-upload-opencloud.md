# Upload de áudio pela Open Cloud (pesquisa)

Feito em 2026-11-05. Somente leitura no repo, mais uma chamada GET de leitura à API. Nada foi enviado, nenhum POST, nada apagado.
Fontes em páginas do Creator Hub lidas por WebFetch (resumo de um modelo pequeno, não o texto literal) e por WebSearch. Onde a
página não abriu ou não traz o dado, está dito. Antes de decidir com base nos números de cota, conferir no próprio Creator Hub.

## 1. Como o projeto envia hoje (leitura do código)

Os dois scripts compartilham a mesma base, `ferramentas/modelos/enviar_veiculos.py`.

- **Nomes das variáveis de ambiente:** `ROBLOX_OPEN_CLOUD_KEY` (chave, header `x-api-key`) e `ROBLOX_CREATOR_ID` (id do dono do asset,
  vai em `creationContext.creator.userId`). Origem: ambiente ou `.env` na raiz, via `carregar_env()` (`enviar_veiculos.py:117-127`).
  Variável de ambiente tem prioridade (`setdefault`). O `.env` existe e tem esses dois nomes. O conteúdo não foi lido nem impresso.
- **Endpoint:** `POST https://apis.roblox.com/assets/v1/assets` (`enviar_veiculos.py:83`, `API` em `:34`).
- **Formato:** `multipart/form-data` montado à mão (`multipart()`, `:53-63`). Dois campos:
  - `request` = JSON `{"assetType", "displayName", "description", "creationContext": {"creator": {"userId"}}}` (`:76-81`);
  - `fileContent` = bytes do arquivo, com `Content-Type` próprio (`:58-61`).
- **Tipos por extensão** (`TIPOS_ARQUIVO`, `:35-42`): `.fbx`->`Model` (`model/fbx`); `.png/.jpg/.jpeg/.tga/.bmp`->`Decal`.
  `enviar_monstros.py:18-20` acrescenta `.rbxm`->`Animation` (`model/x-rbxm`) reatribuindo `ev.TIPOS_ARQUIVO`.
- **Operação assíncrona:** a resposta do POST é `{"path": "operations/<id>"}`. O script consulta `GET https://apis.roblox.com/assets/v1/<path>`
  a cada 2 s (`INTERVALO`), até 180 s (`ESPERA_MAX`), com `x-api-key` em cada consulta (`:90-99`). Quando `done` é true, usa
  `response.assetId` (`:95-99`). Cada chamada tem timeout de 120 s (`:68`).
- **Erros:** HTTP não 2xx vira `RuntimeError("HTTP <code>: ...")` (`chamar()`, `:66-71`).
- **Registro:** `enviados.json` por nome de arquivo com `sha256`, `assetId`, `tipo`, `revisionId`, `moderacao` (`enviar_monstros.py:63-70`).
  Pula se o sha256 não mudou e já há `assetId`.
- **Pontos a cuidar para áudio:** `enviar()` grava `description` fixo ("Veiculo do jogo...", `:79`). Para áudio é preciso parametrizar.
  `displayName` tem corte de 50 caracteres (`:78`).

## 2. Fatos da documentação oficial

Fontes: a página de uso e a de áudio foram lidas por WebFetch (resumo). A busca confirmou os mesmos pontos.

| Fato | Resultado | Fonte |
|---|---|---|
| assetType | `Audio` (campo de request). Enum completo não conferido: a referência abriu só como índice | https://create.roblox.com/docs/cloud/guides/usage-assets ; https://create.roblox.com/docs/reference/cloud/assets/v1 (índice) |
| Formatos e content types | `.mp3` audio/mpeg; `.ogg` audio/ogg; `.wav` audio/wav; `.flac` audio/flac. Uma faixa só | https://create.roblox.com/docs/cloud/guides/usage-assets ; https://create.roblox.com/docs/audio/assets |
| Tamanho | Menos de 20 MB por arquivo (regra geral da API: "file size up to 20 MB"). 9 MB cabe | https://create.roblox.com/docs/audio/assets ; https://create.roblox.com/docs/cloud/guides/usage-assets |
| Duração | Até 7 minutos | https://create.roblox.com/docs/audio/assets |
| Taxa e canais | Até 48 kHz. Mono, estéreo 2.0, 3.0 ou 5.1 | https://create.roblox.com/docs/audio/assets |
| Atualização | Áudio não pode ser atualizado pelo Update (sobe um novo asset) | https://create.roblox.com/docs/cloud/guides/usage-assets |
| Cota de upload | **Conflito entre as páginas (não resolvido).** Página de áudio: 2.000 para conta verificada por ID e 100 sem verificação, com "limite mensal simplificado". Guia de uso: 100 por mês verificada e 10 no total por mês sem verificação. Nenhuma das duas cita janela de 30 dias. A nota antiga do projeto (`pesquisa/limites-assets-roblox.md`) diz "2.000 por 30 dias" | https://create.roblox.com/docs/audio/assets ; https://create.roblox.com/docs/cloud/guides/usage-assets |
| Custo | Nenhuma das páginas cita Robux para upload de áudio (a nota do projeto já diz o mesmo) | https://create.roblox.com/docs/audio/assets |
| Escopo da chave | Pela API key: adicionar os assets em "Access Permissions" e dar leitura e escrita ao jogo escolhido. `asset:read` e `asset:write` são os escopos de OAuth 2.0. O cabeçalho é `x-api-key` em todos os endpoints | https://create.roblox.com/docs/cloud/guides/usage-assets |
| Privacidade | Áudio é privado por padrão: "Although you are initially the only one who can view and use private audio assets" (trecho via resumo). Para outros experiences, é preciso conceder permissão (sistema de privacidade de assets). A página não diz se outro jogo do mesmo criador usa sem permissão | https://create.roblox.com/docs/audio/assets |
| Moderação | Áudio precisa passar pela moderação antes de ser reutilizado. A página não descreve o que acontece se for reprovado. Na consulta do asset o campo é `moderationResult.moderationState` | https://create.roblox.com/docs/audio/assets ; https://create.roblox.com/docs/cloud/guides/usage-assets |
| Valores de moderationState | Exemplos: `MODERATION_STATE_APPROVED` (guia de uso). O GET de hoje devolveu `Approved` (sem prefixo). Não há lista de valores de reprovação nas páginas lidas | (ver teste da seção 4) |
| Assets por operação | POST devolve `path` `operations/<id>`. A operação é consultada por `GET /assets/v1/operations/{operationId}` até `done`, com `response.assetId` | https://create.roblox.com/docs/reference/cloud/assets/v1 (índice) ; https://create.roblox.com/docs/cloud/guides/usage-assets |
| Id em Sound | Sim: `rbxassetid://` seguido do `assetId` da resposta. Por código: `Sound.SoundId = "rbxassetid://ID"`. Pelo guia: `Content.fromAssetId()` em propriedades do tipo Content | https://create.roblox.com/docs/cloud/guides/usage-assets ; https://create.roblox.com/docs/reference/engine/classes/AudioPlayer#AssetId |
| Cota consultável | Há endpoints de leitura de cota: `GET /v1/asset-quotas` e `GET /cloud/v2/users/{user_id}/asset-quotas` (beta). Não foram chamados (o limite do teste era uma chamada) | https://create.roblox.com/docs/cloud/reference/features/assets |

**Não confirmado nas páginas lidas:** enum completo de `assetType`; lista de valores de `moderationState` (incluindo reprovação);
se o asset de áudio precisa de permissão para ser tocado pelo próprio criador no mesmo jogo; o que acontece com áudio reprovado.
Esses pontos precisam de teste no Studio, depois do bloqueio de conta ser resolvido.

## 3. Exemplo de código para áudio (estilo de `enviar_monstros.py`)

Não gravado no repo. Uso de referência. Reaproveita `enviar_veiculos.py` (mesmo multipart e polling), e parametriza a descrição.

```python
"""Envia .ogg/.mp3 de modelos 3d/audio/ como Audio (Open Cloud). Grava enviados_audio.json."""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enviar_veiculos as ev  # noqa: E402

PASTA = ev.RAIZ / "modelos 3d" / "audio"
ev.TIPOS_ARQUIVO = dict(ev.TIPOS_ARQUIVO, **{
    ".ogg": ("Audio", "audio/ogg"),
    ".mp3": ("Audio", "audio/mpeg"),
    ".wav": ("Audio", "audio/wav"),
    ".flac": ("Audio", "audio/flac"),
})
LIMITE_MB = 20  # guia: menos de 20 MB e menos de 7 min


def main():
    ev.carregar_env()
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    caminho_env = PASTA / "enviados_audio.json"
    enviados = json.loads(caminho_env.read_text(encoding="utf-8")) if caminho_env.exists() else {}
    for arq in sorted(PASTA.glob("*")):
        if arq.suffix.lower() not in ev.TIPOS_ARQUIVO or arq.stat().st_size > LIMITE_MB * 1024 * 1024:
            continue
        h = ev.sha256(arq)
        if enviados.get(arq.name, {}).get("sha256") == h:
            print("ja enviado", arq.name)
            continue
        tipo, resp = ev.enviar(arq, chave, criador)  # ver nota: enviar() fixa a descricao
        enviados[arq.name] = {"sha256": h, "assetId": int(resp["assetId"]), "tipo": tipo,
                              "moderacao": resp.get("moderationResult")}
        caminho_env.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", arq.name, enviados[arq.name]["assetId"])


if __name__ == "__main__":
    main()
```

Nota: `enviar()` fixa `description` ("Veiculo do jogo Uma Cidade Silenciosa", `enviar_veiculos.py:79`). Para áudio, o certo é
acrescentar um parâmetro `descricao=` a `enviar()` (default atual) e passar "Audio do jogo...". Não mexido agora.

No Lua, o uso seria `Sound.SoundId = "rbxassetid://" .. id` (id do campo `assetId` de `enviados_audio.json`). O id devolvido é do
asset de áudio, então não há conversão Decal->imagem como nas texturas.

## 4. Teste de estado da conta (2026-11-05)

Uma chamada GET, sem POST, sem apagar nada. Chave lida do `.env` por código Python, nunca impressa.

- Chamada: `GET https://apis.roblox.com/assets/v1/assets/81412098464236` com `x-api-key`. O id é o `modelo` do compacto em
  `src/shared/Config/VeiculosMalhas.luau` (`tipos.compacto.inteiro`).
- **Resultado: HTTP 200.** Corpo (resumo, sem chave): `assetId` 81412098464236, `assetType` `Model`, `state` `Active`,
  `moderationResult.moderationState` `Approved`, `revisionCreateTime` 2026-11-04T16:54:11Z, `isPublished` true.
- **Conclusão:** o bloqueio "User is moderated" (403, pendencias A3) **não apareceu nesta leitura**. A nota diz que o 403 atingia
  até a leitura desde 2026-11-05. Ainda não se sabe se a moderação foi resolvida ou se o bloqueio só afeta POST (upload).
  Uma leitura não prova que um upload funciona. Para isso seria preciso um POST, que não foi feito e depende de aprovação.
- O asset lido tem revisão de 2026-11-04, então é anterior ao bloqueio reportado.

## 5. Próximos passos sugeridos

1. Conferir no Creator Hub a cota real de áudio (2.000/100 ou 100/10, e a janela). Pelo `asset-quotas`, sem POST.
2. Só com aprovação do usuário: um POST de teste com um `.ogg` pequeno, para confirmar o upload e o estado da conta.
3. Depois do upload, testar no Studio no void (`Workspace.ZonaTeste`, skill `teste-no-void`) se `Sound.SoundId` toca para o próprio criador.
