# Preset de monstro (receita do Rastejador para os próximos)

Salvo em 2026-11-05 a pedido do usuário: o que o Rastejador tem de IA, animação e pipeline, escrito como receita para
adicionar monstros novos. Fonte da verdade dos números: `src/shared/Config/Rastejador.luau`; do comportamento: `docs/rastejador.md`.

## 1. O que é um "preset"
Um monstro completo = três pacotes independentes:

| Pacote | O que contém | Onde vive hoje (Rastejador) |
|---|---|---|
| **A. Corpo** | malha + esqueleto + textura + 5 clipes (Idle, Walk, Run, Attack, Death) enviados à Open Cloud | `modelos 3d/rastejador/`, `Config/MonstrosMalhas.luau` (gerado) |
| **B. Comportamento** | percepção por som (comum a todos) + capacidades opcionais: `degrau`, `arrombar`, `veiculo` | `Config/Monstros.especies[i].capacidades`, `server/Monstro{Objetivo,Movimento,Arrombar,Modelo}.luau` |
| **C. Números** | tamanho, velocidades, degrau, golpe, arrombar, veículo, animação | `Config/Rastejador.luau` |

A **percepção** (Calmo/Investiga/Caça por som, `Regras/Percepcao`) não faz parte do preset: vale para todo monstro.

## 2. Preset "quadrúpede arrombador" (valores do Rastejador, medidos ou marcados)

| Grupo | Valor | Observação |
|---|---|---|
| Tamanho | `altura.metros = 2.0` com jogador 1,8 m / 5,234 studs → 5,816 studs | studs = jogadorStuds ÷ 1,8 × metros |
| Velocidade | Calmo 8, Investiga 8, Caça 20, Ataque 20 | por espécie (`Config/Rastejador.velocidade`); o nível 1 genérico segue 6/14 |
| Degrau | `andar` 2,7 (medido: o Humanoid sobe 2,8 com HipHeight 2,545), `saltoMax` 4,0, `folgaMin` 6,0, `sondaFrente` 5,0, 10 Hz | `andar` = medir de novo para cada corpo |
| Golpe | impacto 0,75 s depois do início do Attack; intervalo do nível (1,5 s) | `golpe.atrasoImpacto` sai do clipe |
| Arrombar | dano 60 por golpe (concreto 20 golpes, tijolo 15, madeira 3), `golpesMax` 60, desistir 90 s, 5 raios (0, ±15°, ±30°), alvo real do jogador a ≤ 40 studs, buraco = largura do corpo × 1,6 e 9 de altura | só espécies de corpo grande |
| Veículo | busca 25 studs, memória 6 s, alcance 7, dano 12 a cada 1,4 s, pesos pneu 0,3 / vidro 0,3 / carroceria 0,4 | ocupante só é atacável com vidro lateral quebrado (regra a confirmar) |
| Animação | `nativas` Walk 1,59 e Run 8,69 studs/s; reprodução entre 0,5x e 3x; Idle abaixo de 0,5 studs/s | medir de novo por clipe |

## 3. Passo a passo para um monstro novo

1. **Modelo base**: `modelos 3d/_ps2/<Nome>/<Nome>_rig.blend` (filtro PS2 + rig já feitos por `filtro_ps2.py` e `rig_ps2.py`; monstros em
   `SEM_FILTRO` usam o base). Animar: `animar_ps2.py` (procedural, serve a qualquer rig) ou um script à mão como `animar_rastejador_opus.py`
   (IK nas patas; foi o melhor dos três testados). 5 ações com os nomes `Idle, Walk, Run, Attack, Death`.
2. **Exportar**: `blender -b --factory-startup -P ferramentas/modelos/exportar_rastejador.py -- --altura <studs> --saida "modelos 3d/<nome>"`.
   O Roblox importa o FBX **1:1** (ignora `global_scale`): o exportador escala vértices e ossos.
3. **Enviar o corpo**: `python ferramentas/modelos/enviar_monstros.py` (chave e id do criador no `.env`; Model + Decal). A textura enviada é um **Decal**:
   converter para o id da imagem (`InsertService:LoadAsset(decal)` → `Decal.Texture`) e gravar `imagemId` em `enviados.json`.
4. **Medir o repouso dos ossos no Studio** depois de importar (`rest_roblox_bruto.txt`: uma linha por osso, `Bone.TransformedWorldCFrame` sem Transform,
   relativo ao MeshPart). Sem isso as animações saem erradas.
5. **Converter as animações**: `python ferramentas/modelos/gerar_anim_rastejador.py` → `anim_roblox.json`; depois
   `lune run ferramentas/modelos/montar_anim_rbxm.luau` (modo `aninhado`: poses aninhadas pela hierarquia dos ossos) → `.rbxm` por ação.
6. **Enviar os clipes**: `python ferramentas/modelos/enviar_monstros.py --animacoes` (Animation pela Open Cloud, aceita sem Robux, medido em 2026-11-04).
7. **Gerar o Config**: `python ferramentas/modelos/gerar_config_monstros.py` → `Config/MonstrosMalhas.luau`. Tocar com `Animator` dentro do Humanoid, no servidor.
8. **Espécie**: em `Config/Monstros.especies` pôr `malha = true` e `capacidades = { degrau = true, arrombar = true, veiculo = true }` (as que quiser).
9. **Números**: copiar o bloco do §2 e medir de novo o que depende do corpo (degrau `andar`, velocidades nativas dos clipes, `raioFolga`, `corpo`).
10. **Testar** no place oficial, em Play, na `ZonaTeste` (skill `teste-no-void`): ver §5. Depois `pwsh scripts/checar.ps1` e `sessao.ps1 -Fim` com `-Caminhos`.

## 4. O que ainda está amarrado ao nome "Rastejador" (fazer ANTES do segundo monstro)
O preset funciona hoje só para uma espécie. Para reaproveitar de verdade:
- Os módulos `MonstroObjetivo/Movimento/Arrombar/Modelo` e `Monstros.luau` leem `Config/Rastejador` direto (um único bloco de números). Passar a
  ler `Config/PresetsMonstro[especie.preset]` (cada espécie com `preset = "quadrupedeArrombador"`), mantendo `Rastejador` como o primeiro preset.
- `MonstrosMalhas.luau` tem a chave `Rastejador`; `gerar_config_monstros.py` e os scripts de exportação/animação/envio têm a pasta `rastejador`
  e os prefixos `Rastejador_` fixos. Parametrizar por `--nome`.
- `Regras/Rastejador` (degrau, parede, objetivo, velocidade, ação) já é pura e serve a qualquer espécie se receber o `cfg` do preset.
- Decisão de design pendente: monstros pequenos (Corcunda, Esfolado) arrombam parede? A regra de `golpesMax`/dano muda com o corpo.

## 5. Checklist de teste (ZonaTeste, Play, tudo medido)
1. Escala contra o personagem (bounding box) e os 5 clipes por `screen_capture` (Walk em 2 instantes, Attack no impacto).
2. Velocidade de Caça em chão plano (studs/s) e patinação (velocidade ÷ nativa dentro de `velMin`..`velMax`).
3. Degraus de 0,5 / 2,0 / 3,5 studs em Caça sem pausa.
4. Casa fechada (concreto 20×12×1) com jogador dentro: abre o vão, entra, causa dano. Com porta estreita demais para o corpo.
5. Carro ligado a 25 studs: morde pneu/vidro; desligar o motor para o ataque.
6. Ao fim: apagar `Workspace.ZonaTeste`, parar o Play, checagem pós-teste; nada em `Workspace.Mapa`; não salvar o place.

## 6. Armadilhas já pagas
- Open Cloud: `Animation` só aceita `.rbxm` de KeyframeSequence **com as poses aninhadas pela hierarquia**; `Decal` ≠ id de imagem.
- O navmesh do Roblox **não enxerga** parede que saiu: depois do vão o caminho continua NoPath. O monstro usa a lista de vãos (`Destruicao.vaoUtil`) e `MoveTo` direto.
- `AgentRadius` do corpo 2x faz portas de 4,1–4,8 studs darem NoPath, mas o corpo passa em linha reta: não confiar só no `Status` do caminho.
- Parede dura descartada por `golpesMax` baixo deixava o monstro parado em prédio de concreto (causa medida em 2026-11-05).
- Reprodução do clipe a 1x com velocidade de IA muito maior que a do ciclo faz o pé patinar; medir `nativas` e subir o passo no Blender se passar de 3x.
- Mais de uma sessão no Studio: um Play alheio foi parado por engano em 2026-11-05; sempre `list_roblox_studios` e confirmar de quem é.

## 7. Corcunda, MonstroPS1 e Florescida (2026-11-14)
Refeitos no Blender (`refazer_monstros.py`: `<Nome>_v2.blend/.json`, 5 clipes, 30 fps). Perfis em `exportar_rastejador.py` (`perfil_v2`; `TEXTURA_SEGURA` = Corcunda, Florescida; **Esfolado sem perfil**, moderação).
Comandos por monstro (`--nome corcunda|monstrops1|florescida`): `exportar_rastejador.py --altura <studs>` (5,816 / 5,816 / 6,3971) -> `derivar_repouso_roblox.py` (repouso DERIVADO do manifesto, ver abaixo)
-> `gerar_anim_rastejador.py` -> `lune run ferramentas/modelos/montar_anim_rbxm.luau aninhado <nome>` -> `enviar_monstros.py --nome <nome> --imagem [--animacoes]` -> `gerar_config_monstros.py`.
- **`--imagem`** (novo): o PNG sobe como `Image`, então o `assetId` já é o id da imagem (grava `imagemId`); dispensa converter Decal no Studio.
- **Repouso derivado:** `rest_roblox_bruto.txt` saiu de `derivar_repouso_roblox.py` (regra verificada contra o medido do Rastejador e do Wrapper, erro < 0,005 studs). **Não foi medido no Studio** nestes três: conferir ao importar.
- Presets `corcunda`, `monstroPS1`, `florescida` (derivados do `quadrupedeArrombador`): `nativas` = `velocidade_nativa_m_s` x `escala_blender_para_fbx` (MEDIDO dos clipes), `golpe.atrasoImpacto` = 0,483 s (clipe).
  Velocidades = `Config/Monstros.niveis` do nível. Degrau, `raioFolga`, veículo: PROVISÓRIOS.
- Espécie: `nascerSempre = true` (Florescida) faz nascer com `nivel > nivelAtivoMaximo`.
