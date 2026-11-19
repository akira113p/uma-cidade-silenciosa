# Áudio PSX: medidas (pesquisa, somente leitura)

Data: 2026-11-05. Fonte: `C:\Users\cerfr\Downloads\psx sttuff\1-audio\` (nada foi alterado na pasta).

**Aviso:** tudo aqui é medição com ffmpeg/ffprobe. Ninguém ouviu os arquivos. "Escuro", "claro" e "chuva" são leituras de número (graves, agudos, nível, estabilidade), não avaliação de som. Confirmar de ouvido antes de travar a escolha.

Ferramentas: ffmpeg/ffprobe N-122528 (2026-01-23), em `D:\ffmpeg\bin`.

---

## 0. Encoders disponíveis

Comando: `ffmpeg -hide_banner -encoders | grep -iE "vorbis|mp3|opus"`

| Encoder | Status |
|---|---|
| `libvorbis` | disponível (encoder de verdade, usado no teste) |
| `vorbis` (nativo) | marcado como experimental (`X`); não usar |
| `libmp3lame` | disponível |
| `libopus` | disponível |
| `aac` | disponível |

---

## 1. "40 Free PSX Footsteps" (40 arquivos .ogg)

Formato de todos: Vorbis, 44,1 kHz, estéreo, decodificado em float (fltp). Bit depth não se aplica ao ogg. Os 40 arquivos estão em 8 pastas (a pasta Metal tem arquivos "Foodstep Metal N.ogg", como esperado).

Comandos por arquivo (ffmpeg, saída para `-f null`):
- Pico e RMS: `-af astats`, bloco "Overall" (linhas `Peak level dB` e `RMS level dB`).
- L só: `-af "pan=mono|c0=c0,astats"`. Mono (soma): `-af "pan=mono|c0=0.5*c0+0.5*c1,astats"`. Lado (L−R): `-af "pan=mono|c0=c0-c1,astats"`.
- Silêncio inicial: `-af "silencedetect=noise=-40dB:d=0.005"`; o início é o `silence_end` do primeiro silêncio que começa em 0 (se não há silêncio em 0, início = 0 ms).

**Silêncio inicial:** de 0 a 19 ms na maior parte. Metal (até 43 ms) e Stairs (até 38 ms) são os mais atrasados. Stone começa com som já no primeiro sample. Para sincronizar passo com a câmera, o atraso é pequeno (até ~40 ms); o que pesa mais é o "ataque" que vem junto.

**Loudness integrada (LUFS):** não serve aqui. O ebur128 usa blocos de 400 ms e todos os passos têm 0,13 a 0,34 s, então dá −70 LUFS (nada medido). Usar RMS e pico.

**Resumo por pasta** (n = arquivos; RMS e pico em dBFS; lado−mono = RMS de L−R menos RMS do mono, em dB):

| Pasta | n | Duração (s) | RMS (dB), faixa / média | Pico (dB), faixa | Silêncio inicial máx. (ms) | Lado−mono (dB) | Estéreo real? |
|---|---|---|---|---|---|---|---|
| Concrete | 5 | 0,128 | −31,7 … −25,3 / −27,7 | −14,1 … −6,3 | 18,8 | −29,8 | não (mono) |
| Dirt | 5 | 0,191 | −31,2 … −29,5 / −30,0 | −11,8 … −9,6 | 14,8 | −20,1 | não (mono) |
| Grass | 6 | 0,222 … 0,344 | −29,3 … −25,8 / −27,2 | −9,0 … −2,8 | 21,1 | idêntico (L=R) | não (mono exato) |
| Gravel | 5 | 0,163 … 0,219 | −34,5 … −27,2 / −30,6 | −16,3 … −9,5 | 15,9 | **+3,4** | **sim** (L e R diferentes) |
| Metal | 5 | 0,261 | −40,1 … −31,2 / −35,9 | −23,2 … −14,5 | 43,4 | −17,4 | quase (lado 17 dB abaixo) |
| Stairs | 5 | 0,231 | −34,8 … −27,7 / −31,5 | −13,2 … −5,0 | 37,9 | −18,0 | quase (lado 18 dB abaixo) |
| Stone | 4 | 0,218 … 0,278 | −32,2 … −27,4 / −29,8 | −14,3 … −8,6 | 0,0 | idêntico (L=R) | não (mono exato) |
| Wood | 5 | 0,185 | −29,6 … −26,9 / −27,9 | −10,2 … −7,3 | 10,6 | −25,9 | não (mono) |

**Mono ou estéreo?**
- Grass e Stone: L e R são idênticos. Exportar em mono não perde nada e corta o tamanho pela metade.
- Concrete, Dirt, Wood, Metal, Stairs: diferença L vs mono de até ~0,2 dB. Mono não perde nada perceptível pela medida.
- **Gravel é a exceção:** o lado (L−R) fica 3 dB acima do mono. A soma mono sai 1,6 a 2,9 dB mais baixa que o canal L (cancelamento de fase). Manter estéreo ou corrigir o nível antes de descartar um canal.

**Variação de nível dentro da pasta:** Metal ~9 dB (−40 a −31), Gravel ~7 dB, Grass ~3,5 dB. Para não soar repetitivo, normalizar por pasta e variar ±3 dB na hora de tocar.

Dados completos (uma linha por arquivo): `C:\Users\cerfr\AppData\Local\Temp\claude\096040755fbc9064\ab39e741-89cb-4ceb-9520-ed9d87471933\scratchpad\passos.tsv`

---

## 2. "PSX Ambient Pack\Tracks" (10 WAV)

Todos: 360,0 s (6 min), estéreo, 44,1 kHz, PCM 24 bits (s32 em ffmpeg). Licença: CAPTNPHANTOM, "PSX Ambient Pack" v1.0; uso comercial permitido, sem redistribuir o pack, sem colocar os originais em outro pack; atribuição opcional. Verificar a regra de "não redistribuir" antes de subir o áudio no Roblox (o upload é outro tipo de distribuição).

**Tabela principal** (RMS e pico em dBFS; LUFS integrado em LUFS; "LF<200" e "HF>4k" são RMS da banda, relativos ao RMS total; "gap" = LF − HF, em dB, maior = mais escuro/grave):

| Faixa | RMS | Pico | LUFS | LRA | LF<200 (rel.) | HF>4k (rel.) | gap LF−HF | Lado (L−R) vs mono |
|---|---|---|---|---|---|---|---|---|
| Blur | −19,8 | −2,4 | −18,3 | 4,6 | −2,6 | −35,5 | 32,9 | lado +4 dB (muito estéreo) |
| Distant | −26,4 | −8,5 | −25,8 | 6,5 | −1,2 | −43,1 | 41,8 | lado +6 dB |
| Drift | −23,3 | −6,3 | −21,6 | 4,7 | −3,0 | −38,2 | 35,3 | lado +5 dB |
| Echo | −20,2 | −0,4 | −18,1 | 4,5 | −5,6 | −30,7 | 25,1 | lado +5 dB |
| Faded | −17,4 | −0,2 | −15,7 | 5,2 | −2,7 | −37,5 | 34,8 | lado +6 dB |
| Glow | −24,7 | −6,2 | −22,7 | 6,9 | −5,8 | −38,0 | 32,2 | lado +2 dB |
| Hollow | −21,4 | −4,8 | −19,0 | 4,5 | −11,7 | −32,9 | 21,1 | lado +2 dB |
| Lost | −27,2 | −9,0 | −25,3 | 3,9 | −4,5 | −31,5 | 27,1 | lado +2 dB |
| Still | −24,7 | −6,9 | −23,1 | 6,3 | −2,0 | −44,4 | 42,4 | lado +2 dB |
| Veil | −21,7 | −5,0 | −19,5 | 3,8 | −5,6 | −42,3 | 36,7 | lado +2 dB |

Obs.: o "lado +N dB" é o RMS de (L−R) menos o RMS do mono, então valor positivo = estéreo muito largo (canais pouco correlacionados). Em todos os 10, o lado sai perto ou acima do mono: o mono perde nível e textura. Para Roblox, avaliar se a faixa vai como estéreo.

**Início vs fim (loop):** RMS nos primeiros e últimos segundos (ffmpeg `-ss 0 -t N` e `-sseof -N`).

| Faixa | 3 s início | 3 s fim | Dif. 3 s (dB) | 1 s início | 1 s fim | Dif. 1 s (dB) | Leitura |
|---|---|---|---|---|---|---|---|
| Blur | −16,0 | −17,4 | 1,4 | −14,5 | −16,0 | 1,5 | bom |
| Veil | −19,2 | −20,7 | 1,5 | −21,6 | −19,7 | 1,9 | bom |
| Faded | −18,8 | −17,5 | 1,2 | −18,6 | −15,2 | 3,4 | fim mais alto |
| Distant | −24,6 | −27,5 | 2,9 | −23,9 | −27,8 | 3,9 | razoável |
| Lost | −21,4 | −24,8 | 3,3 | −20,6 | −25,1 | 4,5 | razoável |
| Echo | −14,6 | −19,7 | 5,2 | −14,8 | −19,0 | 4,1 | degrau |
| Drift | −19,2 | −23,9 | 4,7 | −17,8 | −23,2 | 5,4 | degrau |
| Still | −18,0 | −22,7 | 4,7 | −18,0 | −23,5 | 5,5 | degrau |
| Hollow | −18,1 | −24,1 | 6,0 | −18,3 | −24,5 | 6,2 | degrau |
| Glow | −33,0 | −23,6 | 9,5 | −33,2 | −21,9 | 11,4 | pior (começa baixo e sobe) |

Leitura: a diferença de nível entre começo e fim mostra se há emenda audível num loop direto. Blur e Veil têm 1,5 a 2 dB, o que costuma passar. Glow (10 a 11 dB) e Hollow/Still/Drift (5 a 6 dB) fazem degrau claro no ponto de emenda. Para esses, precisa de crossfade (ex.: 3 a 5 s) na edição, ou não usar como loop. Isto é nível de RMS: não mede clique no sample nem fase. Confirmar ouvindo o loop.

**Conversão de teste (Hollow.wav → ogg):**

Comando: `ffmpeg -i Hollow.wav -c:a libvorbis -b:a 192k -ac 2 -ar 48000 Hollow-192k.ogg`

| Item | Valor |
|---|---|
| Origem (WAV 24 bits 44,1 kHz estéreo 6 min) | ~2.117 kbps, ~95 MB (cálculo pela taxa do ffprobe) |
| Saída (ogg libvorbis, 192 kbps alvo, 48 kHz) | **7.184.361 bytes = 6,85 MiB (7,18 MB)** |
| Taxa média real (ffprobe) | 159,7 kbps (ABR ficou abaixo do alvo) |
| Tempo de encode | 10,3 s (real) |
| Duração e canais | 360,0 s, 2 canais, 48 kHz |

Arquivo de teste: `C:\Users\cerfr\AppData\Local\Temp\claude\096040755fbc9064\ab39e741-89cb-4ceb-9520-ed9d87471933\scratchpad\conv\Hollow-192k.ogg` (rascunho, não foi para a pasta original).

---

## 3. Classificação proposta (só medidas, não ouvi)

Critérios: noite = mais escuro (gap grave-agudo alto), mais baixo e grave; dia = mais agudo/aberto (gap baixo), com folga de pico; chuva = nível estável (LRA baixo) e corpo de banda larga; sobras = o resto, usado para perigo/monstro.

| Uso | Escolha | Motivo (medida) | Alternativa |
|---|---|---|---|
| **Noite** | **Still** | gap 42,4 dB (um dos mais escuros), HF −44 dB, LUFS −23,1 | Distant (gap 41,8, o mais baixo: −25,8 LUFS) |
| **Dia** | **Hollow** | gap menor (21,1) = mais agudo relativo, pico −4,8 dB (folga), −19 LUFS | Echo (o agudo mais alto, HF −30,7 dB), mas pico −0,4 dB: precisa atenuar |
| **Chuva (base)** | **Veil** | LRA 3,8 (um dos mais estáveis), LUFS −19,5, início e fim 1,5 dB | Lost (LRA 3,9, mais baixo, −25,3 LUFS) |
| **Perigo/monstro** | Glow | LRA 6,9 (mais dinâmico), começa baixo e sobe: serve para tensão crescente | Faded (o mais alto, −15,7 LUFS, pico −0,2: precisa atenuar muito) |
| Sobra | Blur, Drift, Echo, Faded, Lost, Distant | Blur é o mais estável em loop e bem largo; Drift e Echo fazem degrau no loop; Faded e Echo muito altos | |

Atenção: **Glow** tem degrau de 11 dB entre início e fim. Se for usado em loop, precisa de crossfade. **Veil** serve de base sob chuva, mas é tonal de banda média; a chuva real pode precisar de algo mais ruidoso. Esta é uma proposta a ser testada, não decisão. Confirmar de ouvido antes de travar.

---

## Comandos usados (resumo)

- Probe: `ffprobe -v error -show_entries stream=codec_name,channels,sample_rate,bits_per_sample -show_entries format=duration,bit_rate -of default=nw=1`
- Medidas por arquivo: `scratchpad\medir.sh ARQUIVO` (faz astats full/L/mono/lado, lowpass 200 Hz e highpass 4 kHz, ebur128, silencedetect, 3 s início/fim). Saída TSV: `passos.tsv` (40 linhas), `ambiente.tsv` (10 linhas).
- Início/fim de 1 s e seam: `ffmpeg -ss 0 -t 1 -i F -af astats` e `-sseof -1 -i F -af astats`; seam com `concat` do arquivo com ele mesmo (`atrim=359.5:360.5`). Resultados em `seam.tsv`.
- Encode: `ffmpeg -i Hollow.wav -c:a libvorbis -b:a 192k -ac 2 -ar 48000 out.ogg`.

## Limites das medidas

- Lowpass/highpass e RMS por banda são aproximação simples, não centróide espectral.
- Início/fim em janelas de 1 e 3 s: o que deriva de fade de propósito aparece como "degrau". Isso é intencional, não defeito.
- Não ouvido. Nada de loop testado no Roblox. Se Roblox trata estéreo de forma diferente de mono em som posicional, isso não foi verificado aqui (checar em docs antes de decidir mono ou estéreo para passos e ambiente).
