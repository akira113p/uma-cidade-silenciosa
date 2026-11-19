# Gold Bright: importação de braços, armas e animações em 1ª pessoa (2026-11-15)

Pedido do usuário: importar para o Roblox os modelos de arma, as mãos (braços em 1ª pessoa) e as animações do Gold Bright.
Contexto do jogo e da engenharia reversa (código, mecânicas): `pesquisa/gold-bright.md`, `pesquisa/gold-bright-armas.md`.
**Estado (2026-11-15, 2ª parte): enviado e ligado ao jogo; `checar.ps1` verde; NUNCA rodou no Studio.**
Decisões do usuário (2026-11-15): **armas novas** (não substituem as nossas) e **aceita a GPLv3+**.
- Open Cloud: 158/158 enviados (18 FBX, 18 atlas como `Image`, 122 `Animation`), 0 falhas; 4 atlas ficaram em "Reviewing" (PP91, OTS48K, SR3M, Vodka).
  Ids em `modelos 3d/gold-bright/roblox/<grupo>/enviados.json` -> `src/shared/Config/ArmasGB.luau` (gerado por `gerar_config_gb.py`).
- 9 armas novas em `Config/Armas`/`Itens`/`ItensModelos`/`Admin.armasNovas`: `tt33`, `ots20` (pistola), `mp5`, `pp91`, `sr3m`, `ots48k` (fuzil),
  `rmb93`, `toz34` (escopeta), `canoChumbo` (contundente). Fora do loot (só pelo menu de admin) até o playtest. Números PROVISÓRIOS.
  SMG usam `municaoRifle` (o item de pistola tem pente de 17, `tests/ArmasPane`). OTs-20 e OTs-48K engatilham na mão (Q); TOZ-34 sem engatilhar nem pane.
- `server/ArmasGB.luau`: `LoadAsset` de cada modelo -> `ReplicatedStorage.ArmasGB.<id>` (MeshPart + Bones, textura aplicada).
- `client/ViewmodelGB.luau`: clona o molde, põe na câmera pela câmera original (`ArmasGB.camera`), AnimationController+Animator, toca os estados
  (Draw, Idle em loop com prioridade Idle, Fire, Cock, Reload Phase 1-3 [- Empty] encaixadas na duração do servidor, Check Ammo [Close], Melee Attack [Fast]),
  molas de coice/sway/corrida (`Config/ArmasVista.gb`), esconde braços e `ArmaNaMao` reais, `bocaMundo` para o clarão.
  `client/ArmasViewmodel` cede a vez quando `ViewmodelGB.assumiu(id)` (molde presente); sem molde, continua o caminho antigo.
- 3ª pessoa/chão/plano B: `ArmaModelo` usa o modelo de uma arma nossa da mesma classe (`APELIDO`: tt33->pistola, ots20->beretta, mp5/pp91->carabinaM5,
  sr3m->ak74, ots48k->ar15, rmb93->escopeta, toz34->escopetaM1912, canoChumbo->peDeCabra).
- Comer/remédio: animações enviadas e no Config (`ArmasGB.itens`), **ainda não ligadas** ao uso dos itens.
- De passagem: tirado o BOM (EF BB BF) do início de `Config/Armas.luau` e `Regras/Armas.luau`, que fazia o stylua falhar.

**Testado no Studio (2026-11-15, Play no place oficial, ZonaTeste):** os 9 moldes carregam (`LoadAsset`, 1 MeshPart + 43-47 Bones, textura);
o repouso dos ossos no Roblox bate com o derivado (rotação exata; posição só desloca pelo centro da caixa da malha, que a câmera já desconta);
TT-33: Draw, Idle, tiro (coice, 112 dB), Z (tira o pente e mostra as balas), R (recarga em 3 fases, +1 tática) OK; RMB-93 aparece baixa e à direita
igual ao render do Blender pela câmera original (`normalPosition` do WeaponModelRecoil = (0, -0,42, 0,40), quase a posição estática usada);
cano de chumbo: Idle no centro, golpe sai do quadro como no original. Sem erro no console. Corrigido no teste: `PivotTo` do Model (pivô do FBX girado -90°
deixava a arma fora da tela) -> CFrame direto no MeshPart; trilha do Idle separada da de ação (o Draw da arma usa o mesmo clipe).
Não testados: MP5, PP-91, SR-3M, OTs-20, OTs-48K, TOZ-34 em Play (moldes conferidos), Q nas armas de ferrolho/bomba, 3ª pessoa.

**Correção 2026-11-15 (relato do usuário: "a mão tá parada assim, totalmente quebrado"):** os canais Euler dos clipes (os braços de todas as armas)
eram montados na ordem errada (`Rz·Rx·Ry`). Conferido numericamente contra o repouso do prefab: só `Rz·Ry·Rx` dá erro < 0,01 em todos os ossos
(as outras ordens erram até 1,9). 110 animações refeitas e reenviadas (`enviar_gb.py --so-animacoes`; malha e atlas não mudam).
Conferir pose pela câmera original no Blender: `ferramentas/goldbright/vista_camera_gb.py` (renderiza `_blend/<grupo>.blend` da `camera_na_raiz` com o FOV dado).
Mira básica: `docs/armas.md` §14.

**Próximos passos:** (1) teste na ZonaTeste pela dona do Studio: menu de admin > Armas novas; o molde aparece em `ReplicatedStorage.ArmasGB`? o rig fica
no lugar (senão `Config/ArmasVista.gb.ajuste`/`porArma`)? os ossos animam (Draw, Idle, tiro, R, Q, Z, golpe)? Riscos: Animator em MeshPart ancorado com
Bones, repouso dos ossos derivado e não medido, FOV 55 do original contra 70 nosso (braços podem parecer pequenos). (2) Ligar comer/remédio ao uso dos itens.
(3) Loot e números depois do playtest; malhas próprias de 3ª pessoa. Reenviar: `enviar_gb.py` (pula o mesmo sha256) e `gerar_config_gb.py`.

## Licença (importante para publicar)
`E:\jogos\gold bright\LICENSE.txt` diz: jogo inteiro (código **e** assets) em **GPLv3+**, extração permitida, uso privado sem obrigação.
**Distribuir** (um place publicado no Roblox, que serve os assets a outros jogadores) = a obra derivada inteira passa a ser GPLv3+ e é preciso
oferecer o código-fonte. Quem decide se aceita isso é o usuário. Enquanto não enviar ao Roblox, não há distribuição.
Os arquivos extraídos ficam em `modelos 3d/` (ignorado pelo git, como os outros terceiros).

## Pipeline (tudo em `ferramentas/goldbright/`)
| Passo | Script | Saída |
|---|---|---|
| 1. Extrair do jogo (UnityPy, ~15 s) | `extrair_gb.py` | `modelos 3d/gold-bright/<grupo>/` rig.json, meshes.json, clips.json, animadores.json, tex/ |
| 2. Montar .blend (malha única, armadura, ações, prévias) | `montar_blend_gb.py` (Blender) | `modelos 3d/gold-bright/_blend/<grupo>.blend` + atlas + PNGs de prévia |
| 3. FBX + manifesto + animações em dados | `exportar_gb.py` (Blender) | `modelos 3d/gold-bright/roblox/<grupo>/` .fbx, atlas.png, manifesto.json, anim_blender.json |
| 4. Bone.Transform do Roblox | `converter_anim_gb.py` | anim_roblox.json, rest_roblox_bruto.txt (DERIVADO) |
| 5. KeyframeSequence | `montar_anim_gb.luau` (Lune) | `anim/<Prefixo>_<Clipe>.rbxm` |
| Tudo de 2 a 5 | `rodar_gb.py [--so PREFIXO] [--sem-blend]` | ~1 min para os 18 grupos |

Comandos da raiz: `python -I ferramentas/goldbright/extrair_gb.py "modelos 3d/gold-bright"` e `python -I ferramentas/goldbright/rodar_gb.py`.
Blender: `C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe` (5.3). Sempre `python -I`, e os scripts rodam fora da pasta de dados do jogo.

## O que saiu (18 grupos, 122 animações)
Cada grupo = **uma malha só** (braços + arma + peças móveis, um MeshPart) com **um atlas 1024x1024** (2x2 de 512; braços 256 px sobem, `Weapons.png` 1024 desce),
armadura de 40 a 48 ossos, máx. 4 influências, 3.000 a 7.900 triângulos, 1,7 a 5,7 studs de comprimento (escala 2,908 studs/m, a do R15 do jogo).

| Prefixo | Arma/item | Animações | Estados do Animator (original) → clipe: ver `animadores.json` |
|---|---|---|---|
| TT33 | pistola TT-33 | 21 | `Pistol_Hands` (braços) + `Pistol_Self` (arma) tocam JUNTOS |
| MP5, PP91 | submetralhadoras | 11, 16 | |
| OTS20, OTS48K | OTs-20 Gnom, OTs-48K (ferrolho) | 13, 9 | OTs-20 Reload_2/3 movem uma peça ~11 studs (pente/projétil saindo da tela?): conferir |
| RMB93, TOZ34 | escopeta de bomba, de cano duplo | 10, 10 | |
| SR3M | fuzil SR-3M | 16 | |
| CanoChumbo | corpo a corpo (cano de chumbo; Club e Spade só trocam a malha) | 7 | |
| LataCarne/LataPeixe/LeiteCondensado/BatataCozida/BatataCrua/Vodka | comer/beber | 1 cada | é a animação de comer com a lata que o usuário pediu |
| Comprimidos/Morfina/Vacina | usar remédio | 1 cada | |
Não convertidos: `Puzzle_*` (chaves, pé de cabra, maçarico, etc.), mapa, bicicleta, NPCs. Dá para fazer igual se pedirem.

## Como cada coisa foi resolvida (para ninguém refazer)
- **Clipes do Unity são "streamed"**: o UnityPy não decodifica. `extrair_gb.py` decodifica os três blocos (streamed = polinômio cúbico por trecho, dense, constante).
  Atributo de binding: **1 posição, 2 quaternion, 3 ESCALA, 4 EULER** (eu tinha invertido 3 e 4: dava "escala" de -143).
- **Caminho do osso**: CRC32 (zlib) do caminho relativo ao nó do Animator. Cada grupo tem mais de um Animator (braços na raiz, arma no nó `TT33`...);
  o clipe vai para a base que mais casa. Cobertura mínima 60 %: o Unity removeu alguns ossos do prefab (ex.: OTs-48K recarga 73 %), esses canais somem.
- **Clipes certos por grupo**: lidos das controllers dos Animators (`AnimatorOverrideController` resolve o clipe real de cada estado). Sem isso eram 90+ clipes por grupo.
- **Escala**: os nós têm escala (Arms_Rig 22,5; rigs de arma 100). Foi cozida nos vértices (esqueleto de skinning no repouso) e os ossos ficam só com rotação+translação
  (osso do Roblox ignora escala). Vale porque a escala dos ossos skinados é uniforme e constante.
- **Eixos**: Unity (esquerdo, Y cima, +Z frente) → Blender frente -Y: (x,y,z) -> (-x,-z,y); o enrolamento dos triângulos é invertido. Mesma convenção dos monstros.
- **Poses esparsas**: o original toca o clipe das mãos e o da arma ao mesmo tempo. Cada ação só tem os ossos que ela anima (+ ancestrais com `Weight = 0`),
  senão um clipe zeraria o outro.
- **Moderação**: texturas `bloody_new.png` (comer/remédio) foram trocadas pelo braço limpo `arms.png`. Esfolado já foi recusado antes por sangue.
- **Acessórios fora da malha padrão**: laser, luneta, silenciador, red dot, estojos, clarão (`EXCLUIR_NOMES` em `montar_blend_gb.py`); malhas inativas também.
  Os 30 projéteis do pente do PP-91 viraram 1.

## Não verificado / riscos
- **Nada foi aberto no Studio.** O repouso dos ossos no Roblox é **derivado** (regra verificada com o Rastejador e o Wrapper, erro < 0,005 stud), não medido neste rig.
  Depois de importar o FBX medir um osso e conferir (`converter_anim_gb.py --conferir` não existe; usar `derivar_repouso_roblox.py --conferir` como modelo).
- Textura do `Scope` (RenderTexture) não existe fora do jogo: a luneta ficou sem lente (cinza). Atalhos de visibilidade por escala 0 no original foram perdidos
  (peças que o Unity escondia por animação podem aparecer).
- Custo/limite da Open Cloud para 122 `Animation` e 18 modelos: ver `pesquisa/pipeline-upload-animacao.md`. A conta já levou "User is moderated" (403) uma vez.

## Decisões (resolvidas em 2026-11-15: armas novas + GPL aceita; lista mantida como histórico)
1. **Mapeamento**: as armas do Gold Bright não são as nossas 11 (`docs/armas.md` §1). Substituir o viewmodel e o modelo das nossas (pistola/Beretta ← TT-33; AR-15/M5/AK ← MP5/PP-91/SR-3M;
   escopetas ← RMB-93/TOZ-34; melee ← cano de chumbo) ou **adicionar** armas novas ao lado?
2. **GPL**: aceitar publicar o jogo sob GPLv3+ com o código-fonte aberto, ou usar só como referência/privado?
3. **Em 3ª pessoa** os braços do R15 continuam com as animações do corpo (`ArmasTerceira`): o rig do Gold Bright só serve de viewmodel (1ª pessoa).
4. Viewmodel: trocar `ArmasViewmodel` (blocos + IK, `docs/armas.md` §10.2) por este rig animado, tocando `Draw/Idle/Fire/Reload*/Cock/Holster` por estado.
   Detalhe: os estados `Fire` do original são clipes da ARMA (`*_Self_Fire`) e das MÃOS (`*_Hands_Ref`) simultâneos.

## Próximos passos (quando 1 e 2 forem decididos)
1. `enviar_gb.py` (reusar `enviar_veiculos.enviar`): FBX como Model, atlas como Decal (+ conversão Decal→imagem, ver pipeline), `.rbxm` como Animation; `--dry-run` primeiro.
2. `Config/ArmasGB.luau` gerado (ids, estados→clipe, comprimentos), como `MonstrosMalhas`.
3. Viewmodel novo (`src/client/`), testado na ZonaTeste por quem for a dona do Studio.

## Enquadramento igual ao jogo (2026-11-15, 3ª parte; pedido do usuário com 4 imagens de referência)
Testado em Play no place oficial (ZonaTeste): TT-33 parada/checar (Z)/recarregar (R)/mirar/parede, RMB-93 (mão esquerda na bomba), OTs-48K
com luneta (quadril e retículo), cruz de vida no relógio. Sem erro de script.
- **Ordem Euler**: os canais Euler dos clipes são `Rz·Ry·Rx` (provado de dois jeitos: bate com o repouso do prefab e mantém a mão esquerda
  no carregador durante `TT33_Hands_Mag`; as outras ordens erram).
- **Pose por cima das animações** = porta do `WeaponModelRecoil.Update`/`Fire` (decompilado em `E:\ferramentas\analise\decomp2`):
  nó da arma -> lerp(aimSpeed) para `normalPosition` (quadril) ou `aimingPosition` + offset de mira de ferro/luneta; "Recoil Position" recebe
  offset de corrida/parede (`GunHandler.runningPositionOffset`/`runningRotation`, parede < 1,6 m) ou "não atira" (`cantFire*`), menos
  pitch/1080 para a frente, + coice (`recoilRotationHipfire`/`recoilKickbackHipfire`). Valores por arma lidos dos bytes crus dos
  MonoBehaviours (sem typetree): `ferramentas/goldbright/poses_gb.py` -> `modelos 3d/gold-bright/poses.json` -> `Config/ArmasGB.<id>.vista`.
- **FOV**: as armas do original são desenhadas por uma `OverlayCam` de FOV 55 (a do mundo é 75). `ViewmodelGB` aproxima o rig para dar a
  mesma projeção (`Config/ArmasVista.gb.emularFov`).
- **Ajuste nosso** (não está nos dados): `gb.inclinar` gira o rig para cima (6° parado, 22° em checar/recarregar/engatilhar, 0 mirando),
  para o relógio e a ação aparecerem como nas imagens de referência.
- **Relógio**: cruz Neon presa ao osso do antebraço esquerdo na face do mostrador, cor pela pior vida das partes fatais (`gb.relogio`).
- **OTs-48K = fuzil de luneta**: `montar_blend_gb.ACESSORIOS` liga a luneta (sem as lentes) e tira mira de ferro e silenciador; mira completa =
  retículo em tela cheia (`LunetaGB`) + zoom (`Player.LunetaZoom`, lido pelo `client/Camera`).
- "Open Bolt" toca em loop com o pente vazio (corrediça/ferrolho travado atrás), como a camada de ferrolho do Animator original.
- Ferramentas novas: `poses_gb.py`, `vista_camera_gb.py` (render pela câmera do jogo, com quadro e posição da raiz).

## Painel admin, loot e relógio (2026-11-16)
Pedido do usuário: separar as armas do Gold Bright no painel admin, tirar as armas antigas do spawn do mapa (o lança-foguetes continua; armas brancas e
utilitários continuam) e tirar o relógio dos modelos de braço.
- **Admin**: seção própria "Gold Bright" (`Config/Admin.armasGoldBright`, 9 armas, 1 por clique) abaixo de "Armas novas", que ficou com as armas antigas
  (Beretta, AR-15, M5, AK-74, escopetas, lança-foguetes) e as munições. Saem da lista geral de itens.
- **Loot** (`Config/Itens` tabelas, `Compartimentos/Casa`, `Compartimentos/Comercial`): cada arma de fogo antiga foi trocada pela do Gold Bright com o MESMO peso:
  pistola->TT-33, Beretta->OTs-20, escopeta->RMB-93, M1912->TOZ-34, AR-15->MP5, M5->PP-91, AK-74->SR-3M; OTs-48K entra raro (peso 1) ao lado do SR-3M.
  Lança-foguetes, faca, pé de cabra, machado, comida, munição e utilitários não mudaram. As armas antigas continuam definidas (Config/Armas, admin, 3ª pessoa).
  A lista antiga ficou só no admin. Interpretação minha de "tirando o lança-míssil do spawn": o lançador FICA no mapa. Para tirar dele: apagar as 2 linhas
  `lancaFoguetes` em `Config/Itens` (tabelas `fabrica` e `guarda`).
- **Relógio**: malha `Watch` excluída em `montar_blend_gb.EXCLUIR_NOMES` (18 FBX refeitos e reenviados, só o FBX mudou) e `gerar_config_gb.RELOGIO = False`
  (sem `vista.relogio`, o `ViewmodelGB` não cria a cruz de vida). Para voltar: tirar "Watch" da lista e pôr `RELOGIO = True`.
- Studio: o plugin do Rojo estava sem "Connect"; os 6 arquivos foram escritos pelo MCP e conferidos por hash (djb2) contra o repo.
