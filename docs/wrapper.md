# TheWrapper (monstro sem braços): lógica

Escrito em 2026-11-05. Lógica = Opus; código = agente Sonnet; pesquisas = Haiku. Base: `docs/preset-monstro.md` (receita do Rastejador).
Asset: `c:\Users\cerfr\Downloads\psx sttuff\2-monstros\TheWrapper V2\` (`MonsterPSX.fbx` com rig + 6 takes, `MonsterPSX.blend`, `MonsterPSX_Diffuse.png` 256).
Takes do FBX: `Idle_Watchful, Walk_Nervous, Run_Frantic, Attack_Lunge, WallSlam_Recover, Scream`.
**Licença desconhecida** (`RELATORIO.md` do psx stuff): uso interno/protótipo; não publicar o place sem o usuário confirmar.

## 1. Identidade
Sem braços: não agarra, não arranha. Todo dano é **investida de corpo/cabeça** (lunge). Pelos clipes, ele também **bate o corpo na parede e
se recupera** (WallSlam_Recover) e **grita** (Scream). Espécie nova `Wrapper`, `nivel = 1` (nasce no corte vertical), preset **`corpoAriete`**.
Segue a mesma percepção por som de todo monstro (Calmo/Investiga/Caça, `Regras/Percepcao`); nada disso muda.

## 2. Comportamento (o que difere do Rastejador)

| Situação | Rastejador | Wrapper |
|---|---|---|
| Golpe | garra, impacto 0,75 s depois do início | **Lunge**: ao chegar a `lunge.alcanceInicio` do alvo, para de andar, toca `Attack_Lunge`; no quadro de impacto aplica dano **se o alvo estiver a ≤ `lunge.alcanceImpacto`** (o corpo avança ~`lunge.avanco` studs durante o clipe, por `MoveTo` curto, não por física) |
| Após errar/acertar | nada | **Recuperação**: `lunge.recuperacao` s parado (sem novo golpe), vulnerável. Dá janela de fuga ao jogador (é o preço de não ter braço) |
| Parte atingida | sorteio normal (`sorteioParte`) | **sem BracoE/BracoD**: tabela própria `sorteioParte` do preset (Torso 0,5, Cabeca 0,2, PernaE 0,15, PernaD 0,15). Investida baixa acerta mais perna |
| Dano | nível 1 = 20 | `lunge.dano` = 25 (golpe único, mais lento, mais forte) |
| Arrombar | garra, 60 de dano por golpe, ~1,5 s | **Cabeçada** com `WallSlam_Recover`: dano 90 por cabeçada, depois recuperação `arrombar.recuperacao` s. Mesmas regras de alvo/raios/desistência/buraco, só os números mudam |
| Grito | `gritaAoCacar` do nível | **Scream** ao entrar em Caça (1 vez por entrada, com recarga `grito.recarga` s). O grito é **ruído de 95 dB** na posição do monstro via a API de ruído que já existe (atrai outros monstros). Reusa `gritaAoCacar`, só troca o clipe |
| Veículo | morde pneu/vidro | **Bate** no carro: usa a capacidade `veiculo` com dano por cabeçada (mesmos pesos pneu/vidro/carroceria); `Attack_Lunge` |
| Degrau/salto | sim | sim (`degrau`), números a medir |

Estados de animação: Idle (parado/Calmo) → `Idle_Watchful`; andando abaixo da velocidade de corte → `Walk_Nervous`; Caça → `Run_Frantic`;
golpe → `Attack_Lunge`; cabeçada em parede/carro → `WallSlam_Recover`; entrada em Caça → `Scream`. **Morte: o FBX não tem clipe**;
usar tombar o corpo por Tween (rotação 90° em 0,6 s) e depois o fluxo normal de morte. Não inventar clipe.

## 3. Números iniciais (defaults; **medir no Studio**, marcados `[medir]`)

| Grupo | Valor |
|---|---|
| Tamanho | altura `[medir]` do MeshPart importado; alvo ~ 6 studs (cabe numa porta de 4,5 de largura? checar `corpo`) |
| Velocidade | Calmo 7, Investiga 9, Caça 22, Ataque 22 (Run_Frantic é “frenético”: mais rápido que Rastejador 20, mas **raio de curva grande**: sem curva fechada) |
| Lunge | alcanceInicio 6, alcanceImpacto 7, impacto 0,45 s após o início, avanco 4, recuperacao 1,4 s, dano 25 |
| Cabeçada (arrombar) | dano 90, recuperacao 1,0 s, golpesMax 40, desistir 90 s, alvo real do jogador ≤ 40 studs |
| Grito | 95 dB, recarga 20 s |
| Animação `nativas` | Walk e Run `[medir]` studs/s; reprodução 0,5x–3x |
| Vida | do nível 1 (80). Janela de recuperação é a fraqueza |

## 4. Plano de implementação (para o Sonnet)

**Fase 0 (obrigatória antes do Wrapper): desamarrar do nome Rastejador** (`preset-monstro.md` §4).
- Criar `src/shared/Config/PresetsMonstro.luau` com `quadrupedeArrombador` (= o bloco atual de `Config/Rastejador`, valores idênticos) e `corpoAriete` (§3). `Config/Rastejador.luau` continua existindo como alias do primeiro preset, para não quebrar nada.
- `Config/Monstros.especies[i].preset = "quadrupedeArrombador"` no Rastejador; os módulos `server/Monstro{Objetivo,Movimento,Arrombar,Modelo}.luau` e `server/Monstros.luau` passam a ler `PresetsMonstro[especie.preset]` em vez de `Config/Rastejador`.
- `Regras/Rastejador` já é pura: aceita `cfg` do preset.
- **Critério:** com só a Fase 0, `pwsh scripts/checar.ps1` verde e o Rastejador se comporta igual (testes Lune existentes passam sem mudar valores).

**Fase 1: regras puras e testáveis** em `src/shared/Regras/` (ex.: `Lunge.luau`) + suíte Lune: máquina `Aproximar → Lunge → Recuperar → Aproximar`; função `deveIniciarLunge(dist, cfg)`, `impactoAcerta(distAlvo, cfg)`, `sortearParte(tabela, rnd)`; recuperação bloqueia golpe novo; grito só na transição para Caça e respeita recarga.

**Fase 2: servidor.** Espécie `Wrapper` em `Config/Monstros` (`malha = true`, `preset = "corpoAriete"`, `capacidades = { degrau, arrombar, veiculo }`); no módulo de golpe do monstro, ramificar por `preset.golpe.tipo == "lunge"`; `MonstroArrombar` usa `preset.arrombar` (cabeçada + recuperação); grito por ruído; morte por Tween. **Sem tocar em `Workspace.Mapa`.** Sem usar o MCP do Studio.

**Fase 3: corpo (pipeline do preset §3).** O que o Sonnet pode fazer só com arquivos: parametrizar `exportar_rastejador.py`, `gerar_anim_rastejador.py`, `enviar_monstros.py`, `gerar_config_monstros.py` por `--nome` e preparar `modelos 3d/wrapper/`. **Enviar à Open Cloud pode estar bloqueado** (403 "User is moderated", visto em 2026-11-05 nas armas): tentar uma vez e, se falhar, parar e relatar; sem malha enviada o servidor cai no boneco de blocos (comportamento existente), e a lógica ainda é testável.

**Fora do escopo do Sonnet:** testes no Studio (só a dona do Studio), salvar/publicar o place, `sessao.ps1 -Fim` (o Opus/usuário roda).

## 5. Checklist de teste (ZonaTeste, Play, dona do Studio)
1. Escala vs. personagem e os 6 clipes por `screen_capture`.
2. Caça em chão plano: velocidade real e patinação.
3. Lunge: dano só se o alvo ficar a ≤ alcanceImpacto; jogador que recua 3 studs no clipe escapa; durante a recuperação o monstro não golpeia.
4. Nunca causa dano em “braço” (a tabela não tem BracoE/BracoD).
5. Cabeçada em parede 20×12×1 de concreto: abre o vão (conferir nº de cabeçadas), recupera entre elas.
6. Grito ao entrar em Caça atrai outro monstro a 60 studs.
7. Carro ligado a 25 studs: bate em pneu/vidro.
8. Limpar `ZonaTeste`, parar Play, nada em `Workspace.Mapa`, não salvar.

## 6. Pendências de decisão do usuário
- Licença do asset (desconhecida): ok para protótipo?
- Wrapper arromba parede? (default sim, é o diferencial dele)
- Nível/espécie: default nível 1; o grito de 95 dB muda o equilíbrio do jogo em multiplayer.
- Morte sem clipe: Tween de tombar (default) ou pedir clipe no Blender.

## Estado

Fases 0-3 escritas em 2026-11-05/06 (Sonnet). Sem Studio, sem Rojo, sem commit. `pwsh scripts/checar.ps1`: verde ao fim das Fases 0, 1 e 2; ao fim da 3, **testes Lune e rojo build verdes (26 suítes + Lunge.spec)**, mas selene/stylua falham só por arquivos de outra sessão em andamento (`src/client/ArmasViewmodel.luau`, `BracosViewmodel.luau`), nenhum meu. (Também rodei `stylua src tests` uma vez e isso reformatou `src/shared/Config/SonsPSX.luau` de outra sessão: só espaçamento.)

**Fase 0 (feita).** `Config/PresetsMonstro.luau` com `quadrupedeArrombador` (valores idênticos) e `corpoAriete` (derivado por `derivar`, união recursiva; listas substituem). `Config/Rastejador.luau` virou alias (`require(script.Parent.PresetsMonstro).quadrupedeArrombador`; `tests/Rastejador.spec` lê o PresetsMonstro direto porque Lune não tem `script`). `Config/Monstros.especies.Rastejador.preset = "quadrupedeArrombador"`. `Monstros.criar` grava `d.preset`; `MonstroObjetivo/Movimento/Arrombar` leem `d.preset`; `MonstroModelo.preparar/tocar` recebem o preset. Novo no preset: `golpe.tipo = "garra"` e `arrombar.tipoDano = "garra"` (antes fixo no código; comportamento igual).
**Fase 1 (feita).** `Regras/Lunge.luau` (`novo`, `deveIniciarLunge`, `impactoAcerta`, `sortearParte`, `podeGolpear`, `passo`, `deveGritar`) + `tests/Lunge.spec.luau`. A recuperação começa no **impacto** (acertando ou errando).
**Fase 2 (feita, sem teste em jogo).**
- Espécie `Wrapper` em `Config/Monstros` (nível 1, `malha`, `preset = "corpoAriete"`, `capacidades` degrau/arrombar/veiculo) com **`semNascer = true`**: não entra no sorteio dos pontos do mapa (só pelo menu de admin/`Monstros.invocar`), para não misturar um monstro sem malha testada ao jogo. Tirar a chave faz ele nascer junto do Rastejador. (O doc diz "nasce no corte vertical": decisão sua.)
- `Monstros.luau`: `presetDe`, `d.lunge`/`d.clipe`/`d.ultimoGrito`; `passoLunge` + `impactoLunge` (Aproximar -> Lunge: para, Attack, `MoveTo` de `avanco` studs, dano em `task.delay(atrasoImpacto)` se o alvo estiver a <= `alcanceImpacto`, parte da tabela do preset, sem braços -> Recuperar parado). O toque do `passoMonstro` fica desligado para quem tem `d.lunge`. Grito: preset com `grito` usa `Lunge.deveGritar` (entrada em Caça + recarga), `Ruido.emitir` com 95 dB e clipe `Scream`; sem `grito`, o caminho antigo (Rastejador) não mudou. Morte: preset com `morte.tombar` (0,6 s) para os clipes e tomba por Tween (`tombarTween`), em vez do clipe Death.
- `MonstroArrombar`: `arrombar.recuperacao` no preset = próxima cabeçada só em `atrasoImpacto + recuperacao`; `arrombar.clipe = "WallSlam"` (cache de "parede arrombável" agora por preset). `MonstroObjetivo.bater` zera `d.clipe`. `MonstroModelo.tocar` aceita `WallSlam`/`Scream` e, se o modelo não tem o clipe, usa reserva (`WallSlam`->Attack, `Scream`->Idle); nova `MonstroModelo.parar`.
- Dano à parede da cabeçada usa o tipo `garra` (não existe `cabecada` em `Config/Materiais.matriz`); 90 de dano e `golpesMax 40` do doc. Criar um tipo novo é decisão de design (anotado, não resolvido).
**Fase 3 (feita até onde dá sem Studio).**
- `exportar_rastejador.py`, `gerar_anim_rastejador.py`, `enviar_monstros.py` e `montar_anim_rbxm.luau` aceitam `--nome` (perfil em `PERFIS`; padrão `rastejador`, saída igual). `gerar_config_monstros.py` gera todos os monstros que têm `manifesto.json` (Rastejador byte a byte igual ao anterior).
- `modelos 3d/wrapper/`: cópia do asset (`MonsterPSX.blend/.fbx/_Diffuse.png`), `wrapper.fbx` (altura 5,99 studs = metros 2,06), `manifesto.json`, `anim_blender.json` (6 clipes: Idle, Walk, Run, Attack, WallSlam, Scream; o take "Scream" vem gravado como `Scream.lol`), 1200 tris, 31 ossos de deformação, no máximo 4 influências.
- **Envio à Open Cloud tentado uma vez: aceito (`Approved`, sem 403)**: modelo `139692232616423`, textura (Decal) `77486864537239`. `Config/MonstrosMalhas.Wrapper` gerado com `modelo`, `corpo`, `fundoDoCorpo`, `duracao`; **sem `textura` nem `animacoes`**.

**Pendências para o usuário / dona do Studio**
1. Importar no Studio e converter o Decal em imagem (`InsertService:LoadAsset(decal)` -> `Decal.Texture`), gravar `imagemId` em `modelos 3d/wrapper/enviados.json`; medir `rest_roblox_bruto.txt` (repouso dos ossos); então `gerar_anim_rastejador.py --nome wrapper`, `lune run ferramentas/modelos/montar_anim_rbxm.luau aninhado wrapper`, `enviar_monstros.py --nome wrapper --animacoes`, `gerar_config_monstros.py`. Sem isso o Wrapper aparece sem textura e parado em T (testar só na ZonaTeste).
2. MEDIR no Studio: altura real do MeshPart, frente do modelo (o exportador supõe -Y como o Rastejador), `corpo` (a caixa sai 0,96 x 2,85 x 0,88: estreita), `degrau.andar`, `animacao.nativas` (placeholder do Rastejador), `alcanceInicio/Impacto/avanco`, `atrasoImpacto` 0,45 (clipe tem 1,21 s) e `velocidade`.
3. Doc vs código: o item 6 do checklist (grito atrai outro monstro) não vale para nível 1 vs nível 1 (`processarRuido`: monstro não ouve monstro de nível igual ou maior); só atrai níveis acima. Decidir se muda a regra.
4. `Monstros.popular` chama `MonstroModelo.preparar` para o Wrapper mesmo sem nascer (carrega o molde; sem malha cai no boneco com `warn`).
5. Decisões do §6 continuam abertas (licença, arrombar, nível, morte por Tween). Morte por Tween implementada sem teste.
6. Veículo: o Wrapper herda `veiculo.dano 12` do Rastejador (o doc pede dano por cabeçada); MEDIR.
7. Rodar `scripts/sessao.ps1` com `-Caminhos` só dos meus arquivos: `src/server/Monstro{Arrombar,Modelo,Movimento,Objetivo}.luau`, `Monstros.luau`, `src/shared/Config/{Monstros,Rastejador,PresetsMonstro,MonstrosMalhas}.luau`, `src/shared/Regras/Lunge.luau`, `tests/{Lunge,Rastejador}.spec.luau`, `ferramentas/modelos/{exportar_rastejador,gerar_anim_rastejador,enviar_monstros,gerar_config_monstros}.py`, `montar_anim_rbxm.luau`, `modelos 3d/wrapper/`, `docs/wrapper.md`.
