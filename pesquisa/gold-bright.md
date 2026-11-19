# Gold Bright: tudo o que foi levantado (2026-11-14) — ler ANTES de mexer no jogo de novo

Jogo de referência do usuário para armas, lanterna, comer, vida e tela vermelha. **Projeto pessoal de aprendizado**; usamos como referência de
**comportamento** e reescrevemos em Luau. Nada de código nem de asset do jogo foi copiado para o repositório.
Este arquivo reúne o que foi descoberto (compilado, assets, modelos, animações, mecânicas) para ninguém refazer o trabalho.
Detalhe só das armas: `pesquisa/gold-bright-armas.md`. O que foi implementado: `docs/armas.md` §13.

Legenda de certeza: **[lido]** = visto no código decompilado ou numa estrutura do binário; **[nomes]** = só nomes de classes/campos/strings
(o comportamento é deduzido); **[não visto]** = nunca foi examinado.

---

## 0. Retomar rápido (ferramentas e caminhos)

| O quê | Onde |
|---|---|
| Jogo | `E:\jogos\Gold Bright` (Unity 6000.3.15f1, IL2CPP, Windows x64). Estúdio: Aurora Forge Studios |
| Node portátil 24.22.3 | `E:\ferramentas\node-v24.22.3-win-x64` (o Node global é o 24.11.0, velho demais para a REA; **não mexi no global**) |
| REA 6.9.0 (Reverse Engineer Anything) | `E:\ferramentas\rea`; MCP registrado em `~\.claude.json` (reiniciar o Claude Code para carregar) e skill em `~\.claude\skills\reverse-engineer-anything` |
| Ghidra 12.2 + JDK 25 | `E:\ferramentas\ghidra_12.2_PUBLIC`, `E:\ferramentas\jdk-25.0.5+8` (o Ghidra 12.2 **recusa o JDK 21**, que também ficou em `jdk-21.0.13+9`) |
| Trabalho pronto | `E:\ferramentas\analise\` (ver §2.4) |
| Projeto Ghidra já importado | `E:\ferramentas\analise\goldbright.gpr` (rótulos IL2CPP aplicados) |

Comando da REA pela linha de comando (o MCP só vale depois de reiniciar):
`E:\ferramentas\node-v24.22.3-win-x64\node.exe E:\ferramentas\rea\node_modules\rea-agents\scripts\rea.mjs <comando>`

Gotchas que já custaram tempo:
- **Não decompilar pela REA** (`rea decompile ... --provider ghidra`): no Windows ela reimporta o `GameAssembly.dll` inteiro a cada chamada e estoura o
  prazo de 330 s. Usar o Ghidra headless direto (§2.5), 95 s para 22 métodos.
- `frida` (dependência da REA) tem script de instalação bloqueado de propósito; não aprovar (`npm install-scripts`), não precisamos dele.
- Heredoc com Python no Bash quebrou; escrever o script com a ferramenta Write e chamar `python arquivo.py`.
- Barras invertidas somem ao passar texto pelo shell: escrever caminhos Windows com `String.raw` num arquivo `.js`.

---

## 1. O jogo (arquivos) [lido]

Estrutura: `Gold Bright.exe`, `GameAssembly.dll` (66.155.008 bytes), `UnityPlayer.dll`, `baselib.dll`, `Gold Bright_Data\` (2.468 MB, 65 arquivos).
**Não existe `Managed\`** (IL2CPP): o C# virou código nativo. Pasta `Resources\` só tem `unity default resources` e `unity_builtin_extra`
(nada do jogo). `app.info` = "Aurora Forge Studios / Gold Bright".

### 1.1 Cenas (5, todas feitas à mão no editor) [lido em `globalgamemanagers`]
`Assets/Scenes/MainMenu.unity`, `Tutorial.unity`, `Dormitory.unity`, `Prasnova.unity`, `Epilogue.unity`. Não há `level5+`. A correspondência
`levelN` ↔ cena **não** foi confirmada (precisaria ler o BuildSettings). Mapa fixo, **nada procedural** (nomes `Level1/2/3`, `level2Maps`, `tutorialHouse`,
`sceneBounds`, `scenesToNotBake` [nomes]). Troca de cena com `SceneManager`; carregamento aditivo não confirmado.

### 1.2 Arquivos de dados (MB; entre parênteses o `.resS` de recursos pesados)
`level0` 3,7 (7,7) · `level1` 3,7 (4,1) · `level2` 13,2 (38,1) · `level3` 42,6 (165,1) · `level4` 4,0 (4,7) · `globalgamemanagers` 2,2 ·
`globalgamemanagers.assets` 28,8 (11,7) · `sharedassets0` 133,1 (105,7; `.resource` 19,6) · `sharedassets1` 1,9 (50,1) · `sharedassets2` 14,1 (94,0) ·
`sharedassets3` 46,0 (264,8) · `sharedassets4` 6,9 (14,3) · `resources.assets` 229,9 (258,3). Geometria/texturas/animações estão provavelmente em
`sharedassets0/3` e `resources.assets` (inferido pelos tamanhos) **[não visto]**.

### 1.3 `StreamingAssets`
- `APVStreamingAssets` (~445 MB, 5 pastas com hash, 15 `.bytes`): **iluminação** (Adaptive Probe Volumes do URP), não é mapa nem modelo [nomes `APVDiskStreamingUpdate`, `probeVolumeSceneData`].
- Áudio **FMOD**: `Master.bank` 13,8 KB, `Master.strings.bank` 19,6 KB, `Music.bank` 101,8 MB (+`.private.0` 92,8), `SFX.bank` 194,4 MB (+`.private.0` 152,8).
  O código só cita os barramentos `bus:/Music` e `bus:/SFX`; os nomes dos eventos estão dentro dos `.bank` **[não visto]**. Para ler: FMOD Studio (não instalado).

### 1.4 Terceiros no build [nomes]
Facepunch.Steamworks (702 tipos; só Steam: conquistas, inventário; **nenhum framework de rede** achado: sem `NetworkBehaviour`/Photon.Realtime/Mirror), KWS (209 tipos, sistema de água:
`UseFluidsSimulation`, reflexo, cáustica), CameraShakeAssembly (31), LeanTween (animações por código, `LTDescr`), Unity Input System (`InputSubscription`),
URP (`DecalProjector`), Unity Localization (as frases do jogo ficam em tabelas, não no código). Jogo **single-player**.

---

## 2. A parte compilada

### 2.1 Metadata [lido]
`global-metadata.dat`: **versão 39**, 13.976.732 bytes, magic `0xFAB11BAF`, sha256 `b3108837...c1d447`. Decodificado pela REA (que suporta 24/27/29/31/39) sem rodar o jogo.
Contagens: 87 imagens, 15.500 tipos, 121.341 métodos (**todos com RVA** no `GameAssembly.dll`), 70.417 campos, 23.342 propriedades, 286 eventos, 141.276 parâmetros, 21.175 strings literais.
Binário: PE amd64, `image_base 0x180000000`, 87 code-gen modules, 51.867 tipos.
Só **nomes** saem do metadata; **corpos de método não** (estão no nativo).

Imagens do jogo: **Assembly-CSharp.dll** (670 tipos; 319 classes de topo), Facepunch.Steamworks.Win64 (702), KWS (209), CameraShakeAssembly (31), `__Generated` (5).
O resto das 87 é Unity/.NET.

### 2.2 Catálogo de classes [lido]
Lista completa das 319 classes de topo do Assembly-CSharp (com nº de campos/métodos): `E:\ferramentas\analise\catalogo_classes.txt`.
Campos e métodos das classes de interesse (com RVA): `E:\ferramentas\analise\campos_chave.txt` (Player, Flashlight, GunHandler, Consumable, PlayerInventory, NPC, DamageableObject, PlayerCamera, Distraction, AudioManager, SaveData...).

Mapa por tema (nome da classe; `c/m` = campos/métodos):

| Tema | Classes |
|---|---|
| Armas / tiro | `Gun` (59c), `GunHandler` (149c/64m), `Attachment`/`AttachmentSelector`, `Ammo`, `CameraRecoil`, `WeaponModelRecoil`, `HandShake`, `Distraction`, `NPCProjectile`/`NPCProjectilePool` |
| Jogador / vida | `Player` (129c/65m), `PlayerCamera`, `DamageableObject`, `PlayerInventory`, `InventorySlot`, `AbstractInventoryItem`, `Consumable` |
| Lanterna / bateria | `Flashlight` (31c/14m), `BatteryManager` |
| Inimigos | `NPC` (164c/77m), `ZombieRanged` e soldados (`isSoldier`, `soldierPistol/Shotgun/Rifle/Sniper`) |
| Interação | `Interaction`, `InteractionObject` (99c), `ReadableSwapper`, `Ladder`, portas |
| Sistema | `AudioManager`, `SaveDataManager`/`SaveData`, `SettingsData`/`SettingsMenu`, `AchievementManager`, `TutorialManager`/`TutorialTrigger`, `DifficultyTester` |

### 2.3 Como extrair [lido, comandos que funcionaram]
1. Metadata + endereços + sementes do Ghidra (≈20 s):
   `rea inspect-il2cpp-metadata "E:\jogos\gold bright\gold bright_Data\il2cpp_data\Metadata\global-metadata.dat" --binary "E:\jogos\gold bright\GameAssembly.dll" --ghidra-seeds E:\ferramentas\analise\goldbright_seeds.txt --detail summary --evidence_output E:\ferramentas\analise\il2cpp_ev2.json`
   → `il2cpp_ev2.json` (40 MB, com todos os tipos/campos/métodos/endereços) e `goldbright_seeds.txt` (90.918 linhas `endereço<TAB>function<TAB>Tipo$$Método`).
2. `catalogo.js` (em `E:\ferramentas\analise`) lê o `il2cpp_ev2.json` e regenera os catálogos.

### 2.4 Pasta de trabalho `E:\ferramentas\analise`
`il2cpp_ev2.json`, `goldbright_seeds.txt`, `goldbright.gpr`/`.rep` (projeto Ghidra), `scripts\DecompSelecionados.java` (decompila uma lista de métodos),
`rodar.cmd` (wrapper do `analyzeHeadless`), `decomp\*.c` (22 métodos já decompilados) e `decomp\*.anot.c` (os mesmos com os campos trocados por nome),
`offsets_reais.json` (offsets de campos de Gun, GunHandler, WeaponModelRecoil, CameraRecoil), `anotar2.js` (aplica os nomes), `catalogo.js`,
`catalogo_classes.txt`, `campos_chave.txt`, `layout*.js/json` (primeira tentativa de offsets, **errada**; vale só `offsets_reais.json`).

### 2.5 Decompilar mais métodos [lido; a variante `-process` NÃO foi testada]
O que rodou de fato foi `-import GameAssembly.dll -noanalysis` (95 s para 22 métodos). Para **métodos novos** o projeto já está importado, então `-process GameAssembly.dll -noanalysis` no lugar de `-import` deve ser mais rápido, mas **ainda não foi testado**; se falhar, voltar ao `-import` (ele reimporta e funciona).
`rodar.cmd` chama `analyzeHeadless E:\ferramentas\analise goldbright <argumentos>`; exemplo (PowerShell, `Start-Process`, os nomes alvo separados por vírgula, `$$` literal):
`-process GameAssembly.dll -noanalysis -scriptPath E:\ferramentas\analise\scripts -postScript DecompSelecionados.java E:\ferramentas\analise\goldbright_seeds.txt E:\ferramentas\analise\decomp "Flashlight$$ToggleLight,Player$$TakeDamage"`.
Depois `node anotar2.js` troca `*(T*)(param_1 + 0xNN)` por nomes (só as classes de armas; para outra classe, acrescentar o mapa de offsets em `offsets.js`).
**Como ler o pseudocódigo** (IL2CPP):
- `FUN_180424ee0(0x...)`, `cRam... == '\0'` no começo = inicialização preguiçosa de tipos (ignorar). `lRam... + 0xe4 == 0` = checagem de classe iniciada (ignorar).
- `FUN_180425180(); swi(3)` = lançar `NullReferenceException` (caminho de erro; ignorar). `func_0x000180425130(...)` = criar objeto (`il2cpp_object_new`).
- Campo de instância = `*(tipo *)(param_1 + offset)`; `param_1` = `this`. O offset **não** vem do metadata: vem da tabela `fieldOffsets` do binário
  (ponteiro em `types_field + 40`; índice = nº do tipo; 4 bytes por campo). O `offsets.js` faz isso.
- Corrotinas (`IEnumerator`) viram classes `<Nome>d__N` com `MoveNext()` (é onde está a lógica de espera/passos); campos `<>1__state` etc. são de compilador.
- Constantes `_UNK_182d6...` são floats/doubles num arquivo `.rdata`: ler os bytes no `GameAssembly.dll` (função `off()` do `offsets.js`).

---

## 3. Mecânicas

### 3.1 Armas, tiro, pane, recarga, recuo [lido; detalhe em `gold-bright-armas.md`]
Resumo: pente + câmara (+1 tática), 7 tipos de munição (`pistol, shotgun, smg, rifle, revolver, melee, assaultRifle`), pane 5% (semi) / 1,25% (auto), uma por pente,
só arma de pente; engatilhar na mão em bomba, ferrolho e revólver; recarga em passos com recarga rápida (janela) e falha; pente cai com `balas − 1`; dispersão acumulada com "tiro focado"
(esperar 0,5 s ou laser); recuo separado em câmera (`CameraRecoil`) e modelo (`WeaponModelRecoil`, quadril × mira); `distractionRange` cria barulho (`Distraction.CreateDistraction`);
munição sai de **caixas** (`Ammo.bulletPerBox`, `PlayerInventory.UseAmmo`, caixas vazias são limpas).
Acessórios [nomes]: laser (por modelo de arma), silenciador, choke, empunhadura, pente estendido, freio de boca, luneta, red dot, coronha dobrável, cano estendido; modelos de arma citados: TT-33, OTs-48, SR-3M, RMB-93, PP-91, OTs-20.
Tipos de arma [nomes de campo]: pistola, revólver, SMG, escopeta (bomba e cano duplo), rifle de ferrolho, rifle de assalto, cano de cano (`pipe`), corpo a corpo (`isMeleeWeapon`, `meleeDamageMult`, modelo normal/danificado/quebrado).

**Offsets de `Gun` (instância)**: `0x48 damage, 0x4c penetration, 0x50 rof, 0x54 projectilesPerShot, 0x58 focusedShotMult, 0x5c ammoCount, 0x60 gunType, 0x64 baseAmmoCount, 0x68 baseAmmoCountNormal, 0x6c baseAmmoCountExtended,
0x70 reloadStepWait, 0x84 hasFireGunAnimation, 0x86 isMagazineFed, 0x87 isAutomatic, 0x88 isPumpAction, 0x89 isRevolver, 0x94 spreadAfterPerShot, 0x98 spread, 0x9c holsterTime, 0xa0 distractionRange, 0xa4 isMelee,
0xa8 attackDuration, 0xac attackLandTime, 0xc0 fastReloadWait, 0xc4 tacticalReloadEndWait, 0xc8 reloadMagOutOfGunTime, 0xd0 reloadMagInGunTime, 0xe4 reloadCockTime, 0xec normalCockTime, 0xfc magCheckOutOfGunTime,
0x10c isJammed, 0x10d isJammedThisMag, 0x110 cylinderRotateDelay`. Tabela completa em `offsets_reais.json`.
**`GunHandler`**: `0x20 isSelected, 0x28 currentGun, 0x9c isReloading, 0xa0 reloadStep, 0xa4 reloadWindowActive, 0xa6 isCocked, 0xa7 isAiming, 0xa8 isAttacking, 0xc8 cumulativeSpread, 0x150 focusedShotTimer, 0x1c5 isPlusOneReload,
0x1c8 droppedMagAmmo, 0x1d4 nextFireTime, 0x1d8 moveMult, 0x299 isEmptyChamberReload, 0x29e botchedFastReload, 0x29f canBotchFastReload`.

Métodos de `GunHandler` já decompilados em `decomp\`: `TryShoot`, `JamGun`, `ReloadGun`, `DoFastReload`, `CheckAmmo`, `CockGun`, `StartReloadStep`, `ProceedReloadStep`, `EndReload`, `CanLoadAmmo`, `GetAmmoFromBox`,
`DropMagAmmo`, `EjectMagazine`, `OnReloadPerformed`, `OnUsePressed`, `OnCockGun`, `Update`, mais `CameraRecoil.Fire`, `WeaponModelRecoil.Fire` e as corrotinas `ReloadStepDelay`, `WaitEndReload`, `PlayCheckAmmoRoutine`.
**Não decompilados** (se precisar): `AttackMelee`/`MeleeLand`, `RotateCylinder`, `UpdateBulletModels`, `ActivateAttachments`, `WeaponModelRecoil.Update`, `PlayerCamera`.

### 3.2 Vida e dano [nomes; lógica não lida]
Classe `Player`: `health`, `baseHealth`, `damageTaken`, `damageDealt`, `deathCount`, `IsDead`, limiares de cor `greenHealthThreshold`/`yellowHealthThreshold`/`orangeHealthThreshold`
(`SetHealthColor`/`GetHealthColor`), `TakeDamage(float)`, `LoseHealthFalling(int)`, `ZombieBite(NPC, bool isOnlyPin, float baseDamage)`, `ZombiePunch(NPC, damage, isFlyOff, delay, isSFX, attackCount, isSicken)`,
`GetBitten` (corrotina: o zumbi agarra e morde), `DeathRoutine`, `QuickHeal` (tecla de usar kit; `healRoutine`, `isPreventQuickHeal`, `lastHealTime`),
`healthIndicator`/`backpackHealthRenderer` (vida desenhada **na mochila/no corpo**, sprites, não numa barra clássica), `staminaBar`. Dano por zona: `DamageableObject` (`hitBox`, `bodyPartRigidbodies`, `isArmored`, `armorStatus`).
Armadura existe (`isArmored`). **Não há** sangramento, fratura nem durabilidade de arma [nomes; busca por `bleed|fracture|bandage|durab` sem resultado].

### 3.3 Infecção, veneno, embriaguez [nomes]
`isSicknessMode`, `currentSicknessPercent`, `sicknessGUI` (Image), `SetSicknessGUI`, `CoughRoutine` (tosse), `isPoisonZombieInRange`, `poisonTimer`; `NPCProjectile.isSicken` (projétil que adoece);
tutorial `sickness` e `legSlowdown`. Embriaguez: `IntoxicationAmount`, `drunkPower`, `drunkPowerTarget`, `drunkShakeApplyInterval`, `intoxicatedShakeParams` (tremor de câmera por `CameraShake.BounceShake`).
Consumíveis (enum `Consumable.Type`) [lido]: `morphine, vaccine, painkillers, unused1, unused2, redPill, cannedMeat, cannedFish, condensedMilk, rawPotato, potatoMeal, vodka`.
`DifficultyTester` (ferramenta de balanceamento interna) pesa `foods`, `smallHeals`, `largeHeals`, `largeCures` com `healthWeight`, `sicknessWeight`; limiares `SmallHealHealthThreshold`, `LargeHealHealthThreshold`,
`VaccineSicknessThreshold` ⇒ há **3 níveis de cura** (pequena, grande, cura de doença) e a vacina trata a doença. **Sem valores** (ficam em assets).

### 3.4 Fome / sede [não existe]
Nenhum `hunger`, `thirst`, `nutrition`, temperatura, sono, cozinhar nem receita foi achado nos nomes. A "comida" (`cannedMeat`, `cannedFish`, `condensedMilk`, `rawPotato`, `potatoMeal`)
entra como **cura**. Textos de UI: "Canned Meat", "Canned Fish", "Eat Food". Se quisermos fome/sede, é design nosso (`docs/calculos.md`), não porta.

### 3.5 Lanterna [lido nos campos/métodos; lógica não decompilada]
Classe `Flashlight` (31c/14m): **luz comum do Unity**, não um passe de render próprio: `flashlight` (`UnityEngine.Light`, o foco), `flashPointLight` (luz pontual de preenchimento),
`itemLight`; `flashlightRenderer` + `maxEmission`, `EmissionColorID`, `baseEmissionColor`, `emmisionLerpMult` (o modelo da lanterna brilha por emissão do material, com interpolação `t`);
**vacilar/piscar** (`StartFlicker`, `StopFlicker`, `FlickerRoutine`, `isFlicker`); `ToggleLight`/`TurnOnLight(bool playSFX)`/`TurnOffLight(bool playSFX)`; `npcLayers` (camadas de NPC, provavelmente para
a luz atrair/alertar); balanço da mão igual ao da arma (`swayPosition/Rotation`, `rotationalRecoil`, `holdPosition`, `holdRotation`). Entrada `flashlightSub` (Input System). **Bateria**: `BatteryManager`,
`batteryLevel`, `BatteryStrength`, `batteryIcons`, tipos `BatteryAA/AAA/C/D` [nomes]. Existe também `wasFlashLightOn` (guardar estado ao guardar a arma) e `muzzleFlashLight` (luz do clarão do tiro).
> **Correção de um achado antigo:** os nomes `RenderStencilSpotLights`, `ExtractSpotLightMatrix`, `_SpotLightBias` que apareceram na primeira busca **não são da lanterna**: vêm de um pacote de volumetria/água (KWS)
> ou do URP. Não concluir "passe de render próprio" a partir deles.
Receita para nós: `SpotLight` nativo do Roblox + brilho no modelo + piscar; já temos `server/Lanterna` e `client/Lanterna`. **Números (alcance, ângulo, intensidade, bateria) não foram lidos.**

### 3.6 Comer com a lata [nomes; animação não vista]
Parâmetros de Animator achados nas strings: `Drink`, `Heal`, `Use`, `Throw`, `Flashlight`, `Holster`, `Idle`, `IdleAnim`, `Reload`, `Reload1`, `Reload3`, `ReloadAnimSpeed`, `Fire`, `FireGun`, `CockGun`, `CheckAmmo`, `Pump`, `Jammed`, `IsCocked`,
`IsEmpty`, `IsEndReload`, `IsFast`, `IsLastReload`, `IsReloading`, `IsScoped`, `IsHolster`, `MeleeLand`, `Crouch`, `Sprint`, `Run`, `Jump`, `JumpEnd`, `Climb`, `IsMoving`, `IsOnBike`, `WalkForward/Back/Left/Right (+diagonais)`,
`WalkTime`, `Flashbang`, `DeathAnim`, e de inimigos `AttackFly`, `IsAttacking`, `IsAttackingDoor`, `IsCharging`, `IsCloseRange`, `IsDamaged`, `IsDead`, `IsFlee`, `IsGetUp`, `IsStagger`.
Não há parâmetro chamado `Eat`; comer lata provavelmente passa por `Use`/`Drink`/`Heal` num Animator de item, mas **isso é dedução**. O clipe e o modelo da lata **[não vistos]** (estão nos assets).
Receita para nós: animação própria com a skill `animacao-roblox` (mão leva a lata à boca); `Config/Itens.enlatado` já tem `uso = 3` s.

### 3.7 Tela vermelha de pouca vida [nomes]
`Player.lowHpGUI` (`UI.Image` de tela cheia que aparece com vida baixa), `damagedFlash` e `healedFlash` (`Image` que pisca ao tomar dano/curar, corrotina `FlashRoutine(Image, flashDuration)`),
`lastDamageSfxTime`, `damageSFXName`, `getDamagedRoutine`; há também vinheta de pós-processamento do URP (`Vignette_Color/Opacity`). Limiares de vida `green/yellow/orange` já existem para a cor do indicador.
Os **limiares exatos** em que o `lowHpGUI` liga e a curva do pulso **não foram lidos** (`Player.Update`/`SetHealthColor` não decompilados). Receita para nós: moldura/vinheta vermelha pulsando em `HudVida`.

### 3.8 Inventário, loot, NPCs, câmera, save [nomes]
- Inventário: `PlayerInventory`/`InventorySlot`/`AbstractInventoryItem`; atalhos mochila, cinto e `SLOT1-3` para armas; "Drop Worst Ammo"; **sem containers de loot** como classe do jogo (itens são colocados à mão nas cenas).
- Soldados `NPC`: `AnimateDeath`, `FakeDeath` (finge de morto), `NPCDeadBodyDistraction`, `soldierMophineDrop` (solta morfina), `npcHealth`. 
- Câmera: `PlayerCamera` (42c), `HandShake` (tremor das mãos, 17c), `CameraRecoil`. Save: `SaveDataManager`/`SaveData` (42 campos).

---

## 4. Assets, modelos e animações — o que ainda **NÃO foi visto**

Nada foi extraído nem aberto. Só se conhecem tamanhos (§1.2), a lista de parâmetros de Animator (§3.6) e os nomes de classes.
- **Modelos 3D, texturas, materiais, prefabs, clipes `.anim`, ScriptableObjects e valores numéricos** (dano, cadência, tempos de recarga, números da lanterna): estão nos `level*`, `sharedassets*` e `resources.assets`.
  A REA só lê **UnityFS AssetBundle** (`inspect-artifact`); esses arquivos são *SerializedFile* soltos, que ela **não** garante (a própria documentação diz que objetos de SerializedFile não têm cobertura confirmada).
  Ferramenta provável: **AssetRipper** (ou UABEA), **não baixada** (pedir autorização ao usuário antes).
- **Áudio** (eventos FMOD): dentro dos `.bank`; precisa do FMOD Studio.
- **Localização** (frases como a da checagem de munição): tabelas do Unity Localization, provavelmente em Addressables **[não vistas]**.


---

## 5. Erros e desvios da pesquisa (para não repetir)
1. Primeiro assumi que "o jogo" era o **Project Zomboid** (referência de veículos) e mandei 4 agentes Haiku lá; o jogo era o **Gold Bright**. Os relatórios do PZ **não valem** aqui.
   (Resta só: PZ também tem a lógica de fome no Java compilado e dados de comida/armas em texto; ver `veiculos-pz-referencia` na memória.)
2. Os relatórios dos agentes Haiku sobre o Gold Bright (busca em `metadata_strings.txt`) disseram que **não havia pane nem recuo**: estava **errado**
   (existem `isJammed`, `JamGun`, `recoilKickback*`). Confiar no catálogo (§2.2), não em relatório resumido.
3. O primeiro cálculo de offsets de campo (por alinhamento) estava errado; vale só a tabela `fieldOffsets` do binário.
4. Escrevi que "engatilhar gasta uma bala": **errado**, não gasta (corrigido em `gold-bright-armas.md`).
5. Atribuí a lanterna a um passe de render com stencil: **errado** (§3.5).
6. Servidor da REA no Windows: o Ghidra é "experimental" e o MCP só carrega depois de reiniciar o Claude Code.

---

## 6. Pedidos do usuário ainda não feitos (e o que já se sabe para cada)
| Pedido | Já se sabe | Falta |
|---|---|---|
| Tiro/pane/recarga/HUD de munição | **Feito** (`docs/armas.md` §13), só no Lune | Testar na ZonaTeste; clipes de escopeta; 3ª pessoa |
| Lanterna do Gold Bright | Luz Unity (foco + ponto), emissão no modelo, piscar, bateria (§3.5) | Valores (alcance/ângulo/bateria); decompilar `Flashlight.Update/ToggleLight/FlickerRoutine` ou ler prefab |
| Animação de comer com a lata | Nomes de parâmetros (§3.6); 3 consumíveis de comida em lata | O clipe e o modelo (assets); fazer o nosso |
| Tela vermelha de pouca vida | `lowHpGUI`, `damagedFlash`, `healedFlash`, limiares verde/amarelo/laranja (§3.7) | Limiar de ligar e curva do pulso: decompilar `Player.SetHealthColor`, `SetSicknessGUI`, `Update` |

---

## 7. Próximos passos (em ordem)

1. **Decompilar a lanterna e a tela vermelha** (~2 min cada, receita do §2.5; se o `-process` falhar, usar `-import`). Alvos:
   `Flashlight$$Update`, `Flashlight$$ToggleLight`, `Flashlight$$TurnOnLight`, `Flashlight$$FlickerRoutine` (o `MoveNext` da corrotina `<FlickerRoutine>d__N`),
   `Player$$SetHealthColor`, `Player$$Update`, `Player$$SetSicknessGUI`, `Player$$FlashRoutine` (`MoveNext`), `Player$$TakeDamage`, `Player$$QuickHeal`/`QuickHealRoutine`.
   O que ler: em que vida o `lowHpGUI` liga e como pulsa (curva e velocidade), duração do `damagedFlash`/`healedFlash`, como a lanterna pisca e quando, quanto a bateria gasta.
   Para ler os offsets de `Flashlight` e `Player`, acrescentar essas classes ao `offsets.js` (hoje só cobre Gun, GunHandler, WeaponModelRecoil, CameraRecoil).
2. **Escrever o que saiu** em `pesquisa/gold-bright-lanterna-vida.md` (mesmo formato do `gold-bright-armas.md`: [lido] × [inferido], sem copiar código) e registrar as decisões do usuário em `docs/decisoes.md`.
3. **Implementar no nosso jogo** (pastas já liberadas só para armas; pedir as de lanterna/vida): tela vermelha em `src/client/HudVida.luau`; lanterna em `src/server/Lanterna.luau` + `src/client/Lanterna.luau` + `Config/Lanterna`;
   animação de comer a lata com a skill `animacao-roblox` (mão à boca, `Config/Itens.enlatado.uso = 3` s). Testar na ZonaTeste.
4. **Se o usuário quiser os números reais das armas, da lanterna e dos itens:** baixar o **AssetRipper** (pedir autorização antes; é download) e abrir `sharedassets0/3` e `resources.assets`;
   são os campos serializados dos prefabs (`damage`, `rof`, `reload*`, `spread`, `maxEmission`...). A REA não cobre esse formato.
5. **Pendências do tiro já implementado** (`docs/pendencias-integracao.md`, "Armas do Gold Bright"): testar no Studio, clipes separados de recuo e bombear nas escopetas, animação de engatilhar/checar em 3ª pessoa, som próprio de pane.
6. **Opcional:** ler a localização (frases do jogo) e os eventos FMOD só se o usuário quiser os textos/sons de referência (precisa de ferramenta nova).


---

## 8. Lanterna: lida de verdade (2026-11-16) [lido]
Fonte: componentes `Light` do prefab do Player (`resources.assets`, UnityPy) e `Flashlight.*` decompilado (`E:\ferramentas\analise\decomp3\*.anot.c`;
offsets em `offsets_extra.json`, script `offsets_classes.js <dll> Classe...`; nomes com `<>` vão em arquivo: `DecompSelecionados.java ... @alvos.txt`).
- Fica em `Player/Body/CameraShake/Head/Flashlight`: **presa à cabeça**, não à mão nem à arma. Funciona com qualquer arma na mão.
- 3 luzes, todas **Spot**, branca (1,1,1), sem temperatura de cor:
  | luz | ângulo (miolo) | alcance | intensidade | culling | extra |
  |---|---|---|---|---|---|
  | `Flashlight` (facho) | 55° (40°) | 30 m | 25 | tudo | **cookie** `light_03` 256 px (disco irregular, borda suave, anel + ponto claro), **sombra suave**, 2048, bias 0,05, normalBias 0,4, near 0,2 |
  | `Item Light` | 170° | 5 m | 3 | só a camada 12 (braços/arma) | sem sombra |
  | `Flash Point Light` | 170° | 5 m | 1,8 | só a camada 12 | sem sombra |
  As duas largas iluminam **só as mãos e a arma** (a câmera das armas desenha a camada 12): é o que deixa as mãos claras nas imagens.
- `Start`: as 3 nascem apagadas e com intensidade 0. `TurnOnLight`: liga as 3 e inicia o piscar. `Update`: com a luz ligada a intensidade **sobe
  linear** até o máximo: facho +30/s até 25, ponto +9/s até 1,8, item +8/s até 3 (≈0,8 s para acender). Apagada = 0 na hora.
- Brilho do modelo: `t = lerp(t, intensidade/25, dt*emmisionLerpMult)`; cor de emissão = `baseEmissionColor * t * maxEmission(1)`.
- **Piscar** (`FlickerRoutine`, laço enquanto acesa): espera **25 a 40 s**; pisca **2 a 4 vezes** (apaga as 3 luzes e a emissão por 0,05–0,15 s,
  acende por 0,05–0,2 s); depois fica fraca (12 / 1,08 / 1,8 = 60 %) por 0,1 s, volta a 20 / 1,8 / 3 e o `Update` sobe o facho até 25.
- **Monstros**: com a luz acesa, `SphereCast` do centro da tela (raio 0,3, alcance 25 m) nas camadas `npcLayers` (72); acertando um NPC, soma
  `taxa * 0,03` num contador dele (exposição à luz). Lógica do NPC não lida.
- Campos serializados: `maxEmission = 1`, `npcLayers = 72`, `holdPosition = (-0,35, -0,396, -0,269)`, `holdRotation = (7, 5, 0)` (balanço em `FixedUpdate`, não lido).
