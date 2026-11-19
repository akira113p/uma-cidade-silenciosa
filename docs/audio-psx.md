# Áudio PSX: passos e ambiência (contrato)

Troca os passos e o ambiente dia/noite do catálogo `Config/Sons` pelos áudios de `C:\Users\cerfr\Downloads\psx sttuff\1-audio\`
(**40 Free PSX Footsteps** e **PSX Ambient Pack**, CAPTNPHANTOM). Lógica escrita pelo Opus; código pelo Sonnet; medições e
pesquisa pelo Haiku (`pesquisa/audio-psx-medidas.md`, `pesquisa/audio-upload-opencloud.md`).

## 1. Fluxo (3 estágios, cada um um script)

```
psx sttuff (OGG/WAV)  →  converter  →  build/audio/*.ogg  →  enviar (Open Cloud)  →  audio-psx-ids.json
                                                                       ↓
                                  gerar_config_audio.py  →  src/shared/Config/SonsPSX.luau  →  Config/Sons.luau
```

| Script (em `ferramentas/audio/`) | Faz |
|---|---|
| `converter_psx.py` | ffmpeg (`D:\ffmpeg\bin`). Passos: **mono**, OGG Vorbis (`-ac 1 -c:a libvorbis -q:a 5`, ou o encoder que a medição achar). Ambiente: **estéreo**, OGG ~192 kbps, 48 kHz, **só as 6 faixas usadas** (Still, Distant, Veil, Hollow, Blur, Faded; as outras 4 ficam de fora para poupar cota). Medido: Hollow→ogg 192k = 7,2 MB, ~10 s. Gravel é estéreo real: no mono usar `-ac 1` mesmo, mas conferir queda de nível (≤3 dB, compensar com `volume=+2dB` só no Gravel). Saída em `build/audio/passos/<Superficie>_<n>.ogg` e `build/audio/ambiente/<Nome>.ogg`. Falha se algum arquivo passar de 19 MB ou 7 min. Idempotente (pula o que já existe e é mais novo que a origem). |
| `enviar_audio.py` | Open Cloud, mesmo molde de `ferramentas/modelos/enviar_monstros.py` (chave e criador do `.env`, nunca imprimir segredos). `assetType = "Audio"`. Grava `ferramentas/audio/enviados.json` (`arquivo → assetId`, sem reenviar o que já tem id). `--dry-run` lista o que enviaria e o tamanho. Para no 1º erro 403/429 e diz qual. |
| `gerar_config_audio.py` | Lê `enviados.json` e escreve `src/shared/Config/SonsPSX.luau` (gerado, cabeçalho "NÃO EDITAR"). Superfície sem id fica `{}`. |

## 2. `Config/SonsPSX.luau` (gerado)

```lua
return {
  passos = { Concrete = { 123, 456 }, Dirt = {...}, Grass = {...}, Gravel = {...}, Stairs = {...}, Stone = {...}, Wood = {...}, Metal = {...} },
  ambiente = { Still = 789, Distant = ..., Veil = ..., Hollow = ..., Blur = ..., Faded = ... },
}
```

IDs são números (sem prefixo). Lista vazia = ainda não enviado.

## 3. `Config/Sons.luau`: troca com fallback

Helper no topo: `local function novoOuAntigo(novos: {number}?, antigos: {number}): {string}` — se `novos` tem itens, usa só eles;
senão usa `antigos` (os ids que já estavam). **Assim o jogo não fica mudo enquanto o upload não acontece** (a Open Cloud está
com "User is moderated", ver `docs/pendencias-integracao.md`). Os ids antigos ficam como `antigos` até o usuário ouvir e aprovar;
depois são apagados do arquivo. Campo `origem` de cada entrada passa a citar o pacote PSX.

### 3.1 Passos (positional, servidor): mapa superfície → pasta

| Superfície (Config/Som) | Entrada do catálogo | Pasta PSX | Ajuste |
|---|---|---|---|
| concreto | `PassoConcreto` | Concrete | volume 0.6 |
| terra **(nova)** | `PassoTerra` | Dirt | volume 0.55 |
| pedra **(nova)** | `PassoPedra` | Stone | volume 0.6 |
| gramaBaixa | `PassoGramaBaixa` | Grass | volume 0.5 |
| gramaAlta | `PassoGramaAlta` | Grass | volume 0.7, variação 0.1 (mesmo arquivo, mais grave/alto: dá a diferença) |
| madeira | `PassoMadeira` | Wood | volume 0.6 |
| cascalho | `PassoCascalho` | Gravel | volume 0.6 |
| metal | `PassoMetal` | Metal (pasta tem o typo "Foodstep") | volume 0.6 |
| carpete | `PassoCarpete` | **Dirt**, volume 0.3 | o pacote não tem carpete; Dirt abafado é o mais próximo. Decisão provisória, avisar o usuário |
| agua | `PassoAgua` | **mantém o antigo** | o pacote não tem água |
| (sem material no Roblox) | `PassoEscada` não entra no `Som.superficies`; os OGG de Stairs são enviados e ficam em `SonsPSX.passos.Stairs` para uso futuro | Stairs | detectar escada precisa de marca no mapa, que não se regenera agora (regra 4) |

Reaproveitados por outras entradas: `MangueiraSolta` continua apontando para os ids de `PassoMetal` (copiar a referência à nova tabela,
não os ids antigos). `Aterrissar` e demais ações **não mudam**.

### 3.2 `Config/Som.luau`: duas superfícies novas e materiais redistribuídos

- `terra = { db = -3, materiais = { "Ground", "Mud", "Sand" } }`
- `gramaBaixa` perde `Ground/Mud/Sand`; fica `{ "Grass", "Snow" }` (db -5 como estava).
- `pedra = { db = 2, materiais = { "Cobblestone", "Brick", "Slate", "Rock", "Basalt", "Limestone", "Marble", "Granite", "CrackedLava" } }`.
- `concreto` perde esses materiais; fica `{ "Concrete", "Asphalt", "Pavement", "SmoothPlastic", "Plastic" }`.
- `cascalho` perde `CrackedLava` (vai para pedra). Um material só pode estar em uma superfície (o teste `Som.spec` confere).
- O catálogo precisa ter `PassoTerra` e `PassoPedra` (`Som.nomePasso` gera o nome; o `Som.spec` falha sem eles).
- Os dB mexem no alcance do ruído: `terra` (-3) e `pedra` (+2) são palpites; entram na lista de números a ajustar no playtest (`docs/calculos.md`).

### 3.3 Ambiente (2D, cliente, `SonsLocal`)

O cliente já escolhe um id aleatório da lista ao criar o loop (`criarSom`) e faz fade de 2 s ao trocar a condição. Basta mudar o catálogo:

| Entrada | Faixas (preencher com a classificação de `pesquisa/audio-psx-medidas.md`) | Volume |
|---|---|---|
| `AmbienteNoite` | Still, Distant, Veil (medidas: Still o mais escuro, Distant o mais baixo, Veil o loop mais limpo) | 0.30 |
| `AmbienteDia` | Hollow, Blur, Faded (mais abertas; Hollow tem pico -0,4 dB: converter com `-af volume=-3dB`) | 0.22 |
| `AmbienteChuva` | **mantém o antigo** (o pacote não tem chuva) | 0.6 |

Sem mudar a lógica de `SonsLocal.luau` (troca por `Condicao` já existe). O pacote são camas/drones sem stinger; o jogo continua
silencioso nos momentos de tensão, o que é desejado (som = mecânica).

## 4. Regras que o Sonnet não pode quebrar

1. **Nada de Studio.** Esta sessão não é dona do Studio: só arquivos do repo. Nada de `rojo serve`, MCP do Studio, Play.
2. `build/audio/` fica no `.gitignore` (OGGs convertidos e a pasta `psx sttuff` não entram no git). `enviados.json` entra.
3. **Upload só depois do `--dry-run` e só se o teste de conta (Haiku) deu 200**; se a Open Cloud ainda responde "User is moderated", o Sonnet
   NÃO insiste: entrega os scripts prontos, os OGG convertidos e `Config/SonsPSX.luau` com listas vazias, e diz o que faltou.
4. Os áudios sobem **privados** (padrão da API): a licença do Ambient Pack proíbe publicar os originais em outro asset store; convertido/cortado
   para uso no jogo é permitido. Nunca tornar público nem listar na Creator Store.
5. Footsteps não têm licença/autor declarados: ok para teste no jogo do usuário, **confirmar antes de publicar o jogo** (já em `psx-stuff-assets`).
6. Crédito: acrescentar "Ambience by CAPTNPHANTOM" onde o projeto guardar créditos (se não houver arquivo, criar `docs/creditos.md` com a linha).
7. Código Luau: tabs, `--!strict` onde o arquivo já tem, nada de `wait()`. Python: stdlib + `subprocess`, sem dependências novas.
8. Antes de entregar: `pwsh scripts/checar.ps1` verde (rojo build, Lune, selene, stylua). `Som.spec` cobre os materiais e o catálogo.
9. Não commitar nem rodar `scripts/sessao.ps1 -Fim`.

## 5. Verificação

- `lune run tests/Som.spec.luau` (via checar) verde com as superfícies novas.
- `python ferramentas/audio/converter_psx.py` converte 40 passos (mono) + 6 ambientes (estéreo), todos < 19 MB.
- `python ferramentas/audio/enviar_audio.py --dry-run` lista 46 arquivos e o tamanho total.
- `python ferramentas/audio/gerar_config_audio.py` gera `SonsPSX.luau` que `selene` e `stylua` aceitam, com listas vazias ou preenchidas.
- Teste de ouvido (só a dona do Studio, na ZonaTeste, depois do upload): `ServerStorage.Teste:Invoke("som", "PassoTerra")` e cada passo; ambiente dia/noite pelo ciclo.

## Notas das medições (Haiku, nada foi ouvido)
- Loop: Veil e Blur emendam bem (1,5 dB); Still, Hollow 5–6 dB de degrau no fim→começo. Aceito por ora; se incomodar de ouvido, `converter_psx.py` ganha crossfade de 3 s.
- Glow (degrau de 10 dB) e Echo ficaram de fora. Sobras para uso futuro (perigo/monstro): Glow, Echo, Lost, Drift.

## Estado
Escrito em 2026-11-05 (Sonnet). Scripts em `ferramentas/audio/` (`converter_psx.py`, `enviar_audio.py`, `gerar_config_audio.py`); `Config/SonsPSX.luau` gerado com listas vazias;
`Config/Sons.luau` com `novoOuAntigo` (fallback nos ids antigos) e `PassoTerra`/`PassoPedra`; `Config/Som.luau` com `terra` e `pedra`; créditos em `docs/creditos.md`.
- Converter rodado: 40 passos mono (5 a 8,5 KB cada, 0,13 a 0,34 s) + 6 ambientes estéreo 48 kHz 360 s (5,2 a 7,2 MB), **37,98 MB no total**, nada perto de 19 MB. Hollow com `volume=-3dB`, Gravel com `volume=2dB`.
- `enviar_audio.py --dry-run`: 46 arquivos, 37,98 MB. **Upload NÃO feito** (sem aprovação do usuário). Para enviar: `python ferramentas/audio/enviar_audio.py` e depois `python ferramentas/audio/gerar_config_audio.py`.
- `enviar_veiculos.enviar` ganhou os parâmetros opcionais `descricao` e `nome` (default igual ao antigo).
- `checar.ps1`: tudo verde exceto stylua em `src/shared/Regras/BracosVista.luau` (arquivo de outra sessão, fora deste trabalho).
- Ambiente: os 3 de noite/dia entram no mesmo loop aleatório; com um id parcial (só parte enviada) usa só os que existem.
