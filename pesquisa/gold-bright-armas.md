# Gold Bright: como funcionam as armas (comportamento, 2026-11-14)

Visão geral de TUDO o que foi levantado do jogo (arquivos, compilado, catálogo de classes, lanterna, vida, assets, erros): `pesquisa/gold-bright.md`.

Referência para reescrever o nosso sistema de armas em Luau. Tirado do jogo **Gold Bright** (Unity 6000.3, IL2CPP) com a REA
(metadata v39 + endereços) e o Ghidra 12.2 headless (só os métodos abaixo, sem análise completa). Aqui está só o **comportamento**,
descrito por mim; nenhum código do jogo foi copiado. Ferramentas e arquivos de trabalho: `E:\ferramentas\analise` (ver memória
`gold-bright-rea`).

**Grau de certeza:** regras marcadas **[lido]** saíram do código decompilado com offsets reais (tabela `fieldOffsets` do binário);
**[inferido]** vem só de nomes de campos/métodos. Os **números por arma** (dano, cadência, dispersão, tempos) ficam nos prefabs e
**não foram lidos**.

## 1. Dados de uma arma (`Gun`)

- Tipo de munição (`Ammo+Type`): `pistol=0, shotgun=1, smg=2, rifle=3, revolver=4, melee=5, assaultRifle=6`. A munição é
  separada por tipo e fica numa reserva (caixas com `bulletPerBox`).
- Flags que mudam o comportamento: `isMagazineFed` (pente), `isAutomatic`, `isPumpAction`, `isRevolver`, `isMelee`.
- Pente: `baseAmmoCount` (normal ou estendido, por acessório) e `ammoCount` (balas na arma, contando a da câmara).
- Tiro: `damage`, `penetration`, `rof` (tiros por segundo), `projectilesPerShot`, `spread`, `spreadAfterPerShot`,
  `focusedShotMult`, `distractionRange` (o raio do barulho).
- Uns 30 tempos de recarga separados: mão no pente, pente fora, pente dentro, engatilhar, última bala, recarga tática e recarga rápida.
- Estado da pane: `isJammed` e `isJammedThisMag`.

## 2. Atirar [lido]

1. **Não sai tiro**, só o clique seco com um tremor da mão, se: a arma está sem balas, **ou** não está engatilhada e não é de pente
   (escopeta de bomba, ferrolho, revólver depois do tiro), **ou** está travada.
2. Tiro aceito: `ammoCount -= 1`, conta o tiro, recuo da arma (modelo) e da câmera, e cria uma **distração** (ruído) no mundo.
3. **Cadência:** o próximo tiro só sai depois de `1 / rof` segundos.
4. **Semiautomática:** solta o gatilho depois de cada tiro. Automática continua enquanto o botão está apertado.
5. **Engatilhamento depois do tiro:** arma de pente continua engatilhada sozinha. Escopeta que não é de bomba (cano duplo) também.
   As outras (bomba, ferrolho, revólver) precisam ser **engatilhadas na mão** antes do próximo tiro.
6. Arma de pente ejeta a cápsula a cada tiro, menos quando trava.

## 3. Pane (arma travada) [lido]

- Sorteio **a cada tiro**: chance de travar = **5%** na semiautomática e **1,25%** na automática (o jogo sorteia um valor de 0 a 1;
  não trava se o valor for ≤ 0,95, ou ≤ 0,9875 na automática).
- Só trava se: a arma é **de pente**, **ainda não travou neste pente** (no máximo uma pane por pente) e **sobrou bala** depois do tiro.
  Revólver e escopeta de tubo **nunca** travam.
- No tutorial a pistola trava de propósito no 3º tiro.
- Travada: a bala presa aparece no modelo, o gatilho só faz clique e a arma fica desengatilhada.
- **Destravar:** engatilhar (tecla de engatilhar) ejeta a bala presa e roda um passo de "engatilhar". No fim, a pane some e a
  arma volta engatilhada (menos bomba e revólver). Recarregar também passa pelo mesmo fim.
- [inferido] `isJammedThisMag` volta a falso quando entra um pente novo; não achei a linha que zera.

## 4. Engatilhar [lido]

- Não funciona durante a recarga.
- Sem balas: só clique e um tranco pequeno na arma.
- Já engatilhada e sem pane: não faz nada.
- Senão: ejeta a bala da câmara (menos no revólver, que gira o tambor), marca engatilhada e roda o passo de engatilhar.
  **Engatilhar NÃO gasta bala:** o contador `ammoCount` só muda no tiro e na recarga; a bala ejetada é só visual
  (conferido nos métodos decompilados; uma versão anterior deste texto dizia o contrário, estava errada).

## 5. Recarregar [lido + inferido]

- **Pode recarregar** se: o pente não está cheio (com câmara carregada cabe **+1**: `baseAmmoCount + 1`) **e** há munição
  daquele tipo na reserva.
- A recarga é feita em **passos** (`reloadStep`), cada um com tempo e som próprios: tirar o pente, pôr o pente, engatilhar. Escopeta
  e revólver colocam bala por bala. O contador pode subir durante os passos (`updateAmmoDuringReloadSteps`).
- **Recarga rápida e tática:** apertar recarregar de novo **dentro de uma janela** do passo (`reloadWindowActive`), numa arma de pente,
  dispara a recarga rápida: o pente velho cai no chão com as balas que tinha (`droppedMagAmmo`). Apertar **fora** da janela
  marca a recarga como **falha** (`botchedFastReload`), e aí ela fica mais lenta.
- Pente sem bala na câmara (`isEmptyChamberReload`) precisa engatilhar no fim; com bala na câmara (recarga tática) não precisa.
- [inferido] "Drop Worst Ammo" no menu: larga a munição pior. "got {0} ammo from reserve of {1}" é um log de debug.

## 6. Ver a munição [lido + inferido]

- **Não há contador numérico fixo no HUD.** Há uma ação **checar munição** (`CheckAmmo`): a animação tira o pente (ou mostra o
  tambor), as **balas aparecem no modelo** (`UpdateBulletModels`, com modelos normal, escuro e estendido) e uma **frase traduzida**
  aparece na tela (`LocalizationManager` + `String.Format`, chave `CheckAmmo`). O texto exato está nas tabelas de localização,
  que não foram lidas.
- Com o pente abaixo de **60%** do total o tutorial sugere recarregar. Com menos de 2 balas, sugere checar.

## 7. Dispersão e mira [lido]

- `cumulativeSpread` cresce `spreadAfterPerShot` a cada tiro (com teto) e diminui com o tempo.
- **Tiro focado:** se o jogador espera um pouco entre tiros (o timer volta para 0,5 s a cada tiro) ou tem **mira laser**, a dispersão
  é multiplicada por `focusedShotMult` (primeiro tiro mais preciso). Revólver tem um multiplicador próprio.
- Andar aumenta a dispersão (`moveMult`). Luneta e laser também usam esse fator.
- Recuo em duas partes: **câmera** (`CameraRecoil`: rotação alvo que volta ao normal, menor mirando) e **modelo da arma**
  (`WeaponModelRecoil`: tranco de posição e rotação, separado para quadril e mira, com balanço ao andar).

## 8. Acessórios [inferido]

Laser, silenciador, choke, empunhadura, pente estendido, freio de boca, luneta, red dot, coronha dobrável e cano estendido, cada um
por modelo de arma (TT-33, OTs-48, SR-3M, RMB-93, PP-91 e OTs-20 aparecem nos nomes). O efeito numérico de cada um não foi lido.

## 9. O que falta para portar

1. **Números por arma** (prefabs): extrair com AssetRipper, ou definir os nossos em `Config/Armas.luau`.
2. Decidir com o usuário (`docs/decisoes.md`): chance de pane, se a nossa pistola, os rifles e as escopetas seguem as classes
   acima, se trocamos o contador do HUD pela checagem, e quais acessórios entram.
3. Adaptar ao nosso servidor: o servidor sorteia a pane, valida engatilhar e recarregar e decide o ruído (a distração vira
   `Ruido.emitir`). O cliente só pede e anima.
