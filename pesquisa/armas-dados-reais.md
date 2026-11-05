# Armas: dados reais para balancear o jogo

Pesquisa de 2026-11-05 (WebSearch e WebFetch). Regra aplicada: número sem fonte confiável está como "não achei". Cada número traz a fonte entre colchetes, `[Sn]`, e a URL está na seção 7. Varejistas e blogs estão marcados como "varejo" (fonte fraca). Quando a Wikipedia dá um número sem citação, isso está dito.

## Alertas (ler primeiro)

1. **Escala do Roblox: a conta está certa, mas contradiz a escala oficial.** 5,234 / 1,8 = 2,908 studs por metro (correto). Isso implica 1 stud = 1,8 / 5,234 = **0,344 m**. A página oficial da Creator Hub diz **1 stud = 28 cm** [S43], ou seja 1 m = 3,571 studs. Com 0,28 m, 5,234 studs dão 1,47 m (não 1,8 m) e 1,8 m dá 6,43 studs. As duas premissas não podem valer juntas. Não alterei nada: a escolha é sua (ver seção 6).
2. **"Colt M5 SCW":** SCW = *Sub-Compact Weapon* (nome usado pela Colt e pelo varejo) [S7][S8][S9]. Calibre **5,56×45 mm NATO** (o varejo também lista ".223 Rem") [S8][S9]. "M5" = *M5 Enhanced Carbine 5.56 mm* [S12]. Não confirmei que seja variante do M4/M16: a fonte só diz "M5 Enhanced Carbine 5.56 mm".
3. **Conversão errada na fonte do SCW:** o DefenseReview diz "6,75 lb (2,98 kg)". 6,75 lb = **3,06 kg**. Usei 3,06 kg.
4. **Sem fonte confiável:** cadência prática de pistola e escopeta, tempo de recarga (pente e por cartucho), dispersão a 10 m, dano relativo das armas brancas, e a vida de jogador em Project Zomboid.

## 1. Armas de fogo

Ordem das colunas: calibre · carregador · cadência cíclica · cadência prática semiautomática · velocidade de boca (V0) · recarga do pente · alcance efetivo · massa · comprimento total · energia de boca · nível de pressão do disparo.

| Arma | Calibre | Carregador / tubo | Cíclica (rpm) | Prática semi (rpm) | V0 (m/s) | Recarga pente (s) | Alcance efetivo (m) | Massa (kg) | Comprimento (m) | Energia boca (J) | dB do disparo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **AK-74** | 5,45×39 mm [S1] | 30, caixa (RPK-74: 45; tambor 96) [S1] | 650 [S1] | 100 [S1] | 880–900 [S1] | não achei | 500 (alvo pontual) / 800 (área) [S1] | 3,07 (sem dizer se tem carregador) [S1]; AK-74M 3,4 sem carregador [S1] | 0,943 (coronha estendida) / 0,700 (dobrada) [S1] | 1.328 (7N6) [S6] | não achei |
| **AR-15 civil** (semi). Dados do M16, a família de referência | .223 Rem / 5,56×45 NATO [S2] | 20 (Colt original) [S2]; 30 (padrão militar) [S3] | Civil: não se aplica. M16: 800 [S4]; 700–900 para M16A2/A3 [S3] | 45 semi (figura militar do M16A2) [S4]; sustentada 12–15 [S4] | M193: 991–993 [S3][S5]; M855: 948 [S5]; uma fonte do fas.org diz 853 [S4] (conflito) | não achei | 550 (alvo pontual) / 800 (área) [S3][S4] | 3,40 (M16A2, sem carregador e sem alça) [S3]; 3,99 com carregador de 30 [S4] | 1,007 (M16A2) [S3] | M193: 1.755; M855: 1.797 [S5] | não achei para 5,56. Referência de fuzil .308 sem supressor: 169–171 dB pSPL [S32] |
| **Colt M5 SCW** (5,56) | 5,56×45 NATO [S8][S9] | 30 (varejo; não confirmado no fabricante) | Versão militar tem tiro automático (sem número) [S7]. Civil: só semi, vendido como SBR [S10] | não achei | não achei. Cano 10,3 pol. = 0,262 m [S7] | não achei | não achei | 3,06 (6,75 lb, versão militar; ver alerta 3) [S7]; 2,95 (6,5 lb, civil) [S10]; 2,81 sem carregador (6,2 lb) [S11] | 0,724 (coronha recolhida), 0,768 (estendida), 0,579 (dobrada) [S7]. Civil: 0,660–0,749 [S11] | não achei (ver 5,56 acima) | não achei |
| **Escopeta pump 12** (referência: Remington 870, família) | 12 ga, cartucho 2¾" [S13] | Tubo 3+1 a 7+1 [S13] | não se aplica | não achei (fontes conflitantes: 240 e 80 rpm; nenhuma serve) | 404 com 00 buck, 1.325 fps (varejo Winchester) [S29] | por cartucho: não achei | cerca de 35 com buckshot [S24] | 3,2–3,6 (família) [S13] | 0,670–1,280 (família) [S13] | por pellet 00 buck: cerca de 289 (cálculo meu, seção 2) | 151,5 (cano 28 pol.) a 161,5 (cano 18,5 pol.) [S30]; medição de varejista: 155,4 dBA [S31] |
| **Winchester Model 1912** (trench gun, 12 ga) | 12 ga [S14] | Tubo 6+1 (2¾") [S14] | não se aplica | não achei ("slam fire", sem número) [S14] | não achei | por cartucho: não achei | não achei | 3,6 (7,9 lb) ou 3,9 (8,6 lb), vazia. Fontes conflitantes [S15] | total 1,003–1,017; cano 0,508–0,524 (20 pol. nominal) [S15] | não achei | não achei (ver 12 ga) |
| **Beretta 92FS** | 9×19 mm [S16] | 15 padrão [S17]; variantes até 32 [S16] | não se aplica (semi) | não achei | 381 (1.250 fps; infobox da Wikipedia, sem fonte) [S16]; 124 gr = 410 (Norma) [S20] | não achei | 50 (infobox, sem fonte) [S16] | 0,950 descarregada (Small Arms Survey) [S19]; 0,944 (33,3 oz) [S18]; 0,970 (34,2 oz, M9) [S17] | 0,217 total; cano 0,125 [S16][S18] | 675 (124 gr, 410 m/s) [S20]; cálculo com 381 m/s: cerca de 580 (cálculo meu) | não achei |
| **Glock 17** (genérica 9×19) | 9×19 mm [S21] | 17 padrão; 19 com +2; 24 e 33 opcionais [S21] | não se aplica (semi) | não achei | 360–410 (9×19 genérico: 115 gr = 360; 124 gr = 410) [S20] | não achei | não achei | 0,625 sem carregador (Glock EUA, modelo Gen4 MOS) [S22]; faixa da família 0,548–0,785 [S23] | 0,202 total; cano 0,114 [S22] | 481–675 (9×19 genérico) [S20] | não achei |

Notas da tabela:
- **Glock 17:** a página oficial Gen5 (us.glock.com/en/Pistols/G17-Gen5-FS-US) deu 404. Usei a Gen4 MOS, que é variante próxima.
- **Beretta 92FS:** a página oficial da Beretta veio vazia. Os números são de Wikipedia, Small Arms Survey e American Rifleman, que concordam em cano (125 mm), comprimento (217 mm) e peso (33–34 oz).
- **Cadência semi do M16 (45 rpm) é uma figura militar,** não é tiro civil medido.

## 2. Escopetas: carga 00 buckshot

| Item | Valor | Fonte |
|---|---|---|
| Projéteis (pellets) por cartucho 00 | **9** (especificação militar exige 9); varejo Winchester também 9 | [S26][S29] |
| Faixa geral de 12 ga | 8 a 18 pellets por cartucho (sem especificar tipo) | [S25] |
| Pellets por onça, #00 | 8 (logo, cerca de 3,54 g por pellet) | [S24] |
| Diâmetro do pellet #00 | 0,330 pol. (8,38 mm) | [S24] |
| V0 | 1.325 fps = **404 m/s** (varejo; faixa de mercado 1.200–1.350 fps, sem fonte oficial) | [S29] |
| Energia de boca por pellet | cerca de 289 J (cálculo meu: ½ × 0,00354 kg × 404²). Total de 9 pellets: cerca de 2,6 kJ, mas não chega todo ao alvo | cálculo meu, [S24][S29] |
| Dispersão a 10 m | **não achei**. Padrão de referência: % dos pellets em círculo de 30 pol. a 40 jardas [S27]. Especificação militar: ≥65% em 30 pol. a 40 jd, cano full choke [S26]. Teste de varejo: padrões de 6,5 a 14 pol. a 25 jd, o que contradiz a regra de 1 pol. por jarda [S28] | [S26][S27][S28] |
| Alcance efetivo com buckshot | cerca de 35 m (a Wikipedia cita Chuck Hawks, rem870.com e Britannica) | [S24] |
| Recarga por cartucho | não achei | — |

Por fonte:
- Nível do disparo: 151,5 dB (cano 28 pol.), 156,1 dB (26 pol.), 161,5 dB (18,5 pol.) [S30]. É um folheto de protetor auricular: fonte com viés. Medição de varejista: 155,4 dBA com microfone a 1 m [S31].

## 3. Lança-foguetes RPG-7 (PG-7VL)

| Item | Valor | Fonte |
|---|---|---|
| Calibre | 40 mm (1,6 pol.) | [S33] |
| Velocidade | impulso 115 m/s; voo 300 m/s | [S33] |
| Alcance efetivo | 330 m (PG-7V); máximo 700 m (OG-7V); autodestruição em cerca de 920 m | [S33] |
| Massa | lançador 6,3 kg sem mira (7 kg com PGO-7); granada PG-7VL 2,6 kg; total carregado: 8,9 kg (cálculo meu) | [S33] |
| Comprimento | 0,950 m (lançador) | [S33] |
| Penetração | acima de 500 mm de aço RHA (PG-7VL, tabela do fabricante citada pela Wikipedia) | [S33] |
| Raio letal | PG-7VL: **não achei** (é carga oca anticarro, HEAT). A Wikipedia dá 7 m "contra colete" para o OG-7V (fragmentação) e 10 m para o TBG-7V (termobárica), sem definir o critério | [S33] |
| Cadência e recarga | cadência: não achei. Tempo de recarga: não achei (a Wikipedia diz só que o lançador é recarregável) | [S33] |

## 4. Armas brancas

| Arma | Comprimento | Massa | Dano relativo |
|---|---|---|---|
| **Faca de combate** (referência: KA-BAR USMC 1217, varejo) | lâmina 7,00 pol. = **0,178 m**; total 11,875 pol. = **0,302 m** [S34] | 0,65 lb = **0,295 kg** (número do fabricante, segundo The Gadgeteer) [S35]; varejo: 0,70 lb [S34] | não achei |
| **Machado de lenhador/bombeiro** | não achei | não achei | não achei. A Wikipedia "Axe" não traz medidas [S37]. A Estwing "Fireside Friend" (14 pol., cerca de 4 lb) é rachador/marreta, não machado de bombeiro [S36] |
| **Pé de cabra** (referência: Stanley 55-118, varejo) | 18 pol. = **0,457 m** [S38] | cerca de 2,11 lb = **0,957 kg** [S38]. Outra listagem diz 4 lb: conflito, não usar | não achei. A Wikipedia "Crowbar" não traz medidas [S39] |

Nenhuma das três armas brancas tem dano relativo com fonte confiável. A Wikipedia "Combat knife" também não traz medidas [S40].

## 5. Jogos de sobrevivência: dano por tiro versus vida

| Jogo | Vida máxima | Dano por tiro | Fonte |
|---|---|---|---|
| **DayZ** | **100** de Health; morte em **0** Health. Sangue máximo 5.000 (a página não diz que é o teto de sangue) | Não achei dano por bala em fonte oficial (fica em CfgAmmo). Tabela de lesões: ferimento de bala tira em média **31** Health | [S41] |
| **Escape from Tarkov** | Por parte do corpo. Cabeça **35** (um guia). Estômago 70 (um guia). Braços 60 cada (um guia). Tórax: **80** em um guia e 85 no pedido; conflito. Pernas 65: não confirmado. Total **440** segundo win.gg | Não achei dano por munição (a wiki do jogo bloqueou o acesso). Cabeça ou tórax destruídos = morte imediata [S42] | [S42][S47] |
| **Project Zomboid** | Vida do jogador: **não achei**. A PZwiki bloqueou o acesso. Na página Bite, a saúde aparece como faixas (90–100% = "dano leve") [S44] | Terceiros, build 42.19 (não comparável sem a vida do jogador): pistola 0,6–1,6; espingarda 1,2–2,2; fuzil 1,2–2,0 [S45] | [S44][S45] |

Leitura: só o DayZ tem vida 100 confirmada com fonte. Os outros dois não permitem comparar tiro com vida.

## 6. Roblox: studs para metros

- Premissa do projeto (sua): 1 stud ≈ 0,28 m; 5,23 studs = 1,8 m.
- Conta: 5,234 / 1,8 = **2,908 studs/m**. Correta.
- Oficial: **1 stud = 28 cm** (tabela da Creator Hub) [S43]. Isso dá 3,571 studs/m.
- Diferença: 0,344 m contra 0,28 m, 23%. Não dá para ter as duas premissas.
- Fórum da Roblox: há posts com 0,30 m e outros com 0,35 m por stud [S46].
- Altura de 5,23 studs: não confirmada. A página oficial não traz altura de personagem [S43].

**Decisão para você:** escolher 0,28 m (oficial) ou manter 2,908 studs/m (o que implica 0,344 m por stud). Não mudei nada. Se a escolha for 0,28, a altura de 1,8 m vira 6,43 studs.

## 7. O que não achei (sem fonte confiável)

- Cadência prática de pistola (Beretta, Glock) e de escopeta de bomba.
- Tempo de recarga de pente (qualquer arma) e por cartucho (escopeta, Model 1912).
- Dispersão de escopeta a 10 m.
- Velocidade e energia da Colt M5 SCW (cano de 10,3 pol.).
- Dano relativo de faca, machado e pé de cabra.
- Dano por munição no Tarkov e no DayZ.
- Vida do jogador no Project Zomboid.
- Raio letal do PG-7VL (carga anticarro).
- Medidas do machado de bombeiro e do pé de cabra em fabricante (Estwing e Stanley não abriram).
- Peças do PDF oficial da Colt: o arquivo veio binário e ilegível.

## 8. Fontes

| ID | URL | Usado para |
|---|---|---|
| S1 | https://en.wikipedia.org/wiki/AK-74 | AK-74: calibre, carregador, cíclica, prática, V0, alcance, massa, comprimento |
| S2 | https://en.wikipedia.org/wiki/AR-15_style_rifle | Calibre .223/5,56; carregador histórico de 20 |
| S3 | https://en.wikipedia.org/wiki/M16_rifle | M16: cíclica (Rottman 2011), massa 3,40 kg, comprimento, alcance; carregadores (infobox, sem citação) |
| S4 | https://man.fas.org/dod-101/sys/land/m16.htm | Cíclica 800, semi 45, sustentada 12–15, burst 90; 853 m/s (conflito); 3,99 kg com carregador; 1,0066 m; 800 área / 550 pontual |
| S5 | https://en.wikipedia.org/wiki/5.56%C3%9745mm_NATO | M193 993 m/s (991 no texto), M855 948 m/s; energias 1.755 e 1.797 J |
| S6 | https://en.wikipedia.org/wiki/5.45%C3%9739mm | 7N6: 880 m/s, 1.328 J |
| S7 | https://defensereview.com/?p=10299 | Colt SCW: 10,3 pol. de cano; peso 6,75 lb (conversão errada na fonte); comprimentos. Resultado de busca, não aberto |
| S8 | https://botach.com/colt-m5-scw-sub-compact-weapon-5-56mm-semi-auto-cqb-rifle-10-3-barrel/ | Nome "Sub Compact Weapon", 5,56 (varejo) |
| S9 | https://armsunlimited.com/colt-m5-scw-sub-compact-weapon-556-semi-auto-10-barrel-cqb-rifle | Idem (varejo) |
| S10 | https://blackstoneshooting.com/colt-m5-scw-sbr-5-56-nato-10-30-barrel-black/ | Civil: 6,5 lb, SBR (atribuição pelo título da página, não confirmada) |
| S11 | https://soldiersystems.net/2024/08/23/colt-scw-available-from-arms-unlimited/ | Versão civil: 26 e 29,5 pol.; 6,2 lb sem carregador |
| S12 | https://www.armyrecognition.com/archives/archives-land-defense/land-defense-2017/colt-introduces-its-new-m5-5-56mm-enhanced-carbine-at-bidec-2017 | "M5 Enhanced Carbine 5.56 mm" |
| S13 | https://en.wikipedia.org/wiki/Remington_Model_870 | Família 870: tubo 3+1 a 7+1, 3,2–3,6 kg, 670–1.280 mm |
| S14 | https://en.wikipedia.org/wiki/Winchester_Model_1912 | Tubo de 6 + 1; "slam fire" sem número |
| S15 | https://lsbauctions.com/?p=108361 e https://old.weaponsystems.net/weaponsystem/AA03%20-%20Model%2012.html | Trench gun: cano de 20 pol. (leilão); peso e comprimento em tabelas de fonte fraca, com conflito |
| S16 | https://en.wikipedia.org/wiki/Beretta_92 | 92: 381 m/s, 950 g, 217 mm, cano 125 mm, 50 m (sem citação) |
| S17 | https://en.wikipedia.org/wiki/M9_(pistol) | 15 padrão; 970 g descarregada (34,2 oz) |
| S18 | https://americanrifleman.org/articles/2012/9/10/beretta-92fs | 92FS: 33,3 oz; cano 4,9 pol.; comprimento 8,5 pol. |
| S19 | https://www.smallarmssurvey.org/sites/default/files/SAS_weapons-pistols-Beretta92.pdf | 92: 950 g descarregada |
| S20 | https://en.wikipedia.org/wiki/9%C3%9719mm_Parabellum | 9×19: 115 gr = 360 m/s, 481 J (Federal); 124 gr = 410 m/s, 675 J (Norma) |
| S21 | https://en.wikipedia.org/wiki/Glock_17 | 17 padrão; +2 = 19; 24 e 33 opcionais |
| S22 | https://us.glock.com/en/Pistols/G17-Gen4-MOS | 625 g sem carregador; cano 114 mm; comprimento 202 mm (Gen4 MOS, não Gen5) |
| S23 | https://www.smallarmssurvey.org/sites/default/files/SAS_weapons-pistols-Glock.pdf | Família Glock: 548–785 g; 160–225 mm; 88–153 mm |
| S24 | https://en.wikipedia.org/wiki/Buckshot | #00: 8 por onça, 0,330 pol.; alcance efetivo cerca de 35 m |
| S25 | https://en.wikipedia.org/wiki/Shotgun_cartridge | 12 ga: 8 a 18 pellets por cartucho (00 sem especificar) |
| S26 | https://ammunitionthrough30mm.emilspec.com/MIL-PRF-48656/page3.html | Especificação militar: 9 pellets; ≥65% em 30 pol. a 40 jd; cano full choke 29 ± 2,5 pol. |
| S27 | https://saami.org/glossary/pattern/ | Definição de padrão: 30 pol. a 40 jd |
| S28 | https://athlonoutdoors.com/article/00-buckshot-ammo-test/ | Teste de varejo: 6,5–14 pol. a 25 jd. Resultado de busca, não aberto |
| S29 | https://mail.ableammo.com/catalog/winchester-super-buckshot-xb1200-gauge-234-pellets-1325-fps-buffered-lead-buckshot-rdbx-p-73308.html | Winchester XB1200: 9 pellets, 1.325 fps (varejo) |
| S30 | https://earinc.com/wp-content/uploads/2019/04/Gunfire-Noise-Level-Chart-EAR-Customized-Hearing-Flyer.pdf | Escopeta: 151,5 / 156,1 / 161,5 dB por comprimento de cano (folheto de protetor auricular) |
| S31 | https://www.wideners.com/blog/?p=18146 | Escopeta: 155,4 dBA, medição de varejista; OSHA 140 dB pico |
| S32 | https://en.wikipedia.org/wiki/Suppressor | Fuzil .308 sem supressor: 169 e 171 dB pSPL; pistola .22 LR: acima de 160 dB |
| S33 | https://en.wikipedia.org/wiki/RPG-7 | Calibre 40 mm; velocidades; alcances; massas; penetração; raio letal do OG-7V e TBG-7V |
| S34 | https://www.kygunco.com/product/ka-bar-1217-fightingutility-knife-usmc-straight-edge | Faca KA-BAR 1217: lâmina 7 pol., total 11,875 pol., 0,70 lb (varejo) |
| S35 | https://the-gadgeteer.com/?p=521980 | KA-BAR: 0,65 lb (10,4 oz), número do fabricante segundo a matéria |
| S36 | https://www.kmstools.com/estwing-fireside-friend-splitting-tool-4-lb.html | Estwing Fireside Friend: 14 pol., 4 lb (varejo; não é machado de bombeiro) |
| S37 | https://en.wikipedia.org/wiki/Axe | Sem medidas de machado |
| S38 | https://www.acmetools.com/stanley-18-in-wrecking-bar-55-118/076174551181.html | Stanley 55-118: 18 pol., 2,11 lb (varejo) |
| S39 | https://en.wikipedia.org/wiki/Crowbar | Sem medidas de pé de cabra |
| S40 | https://en.wikipedia.org/wiki/Combat_knife | Sem medidas de faca |
| S41 | https://dayz.wiki.gg/wiki/Health | DayZ: Health 0–100, morte em 0; sangue 0–5.000; ferimento de bala em média 31 |
| S42 | https://www.gamepressure.com/escape-from-tarkov/health-and-injuries/z1cf2f | Tarkov: cabeça e tórax destruídos = morte imediata; sem números de HP |
| S43 | https://create.roblox.com/docs/physics/units | Roblox: 1 stud = 28 cm (oficial) |
| S44 | https://pzwiki.net/wiki/Bite | PZ: saúde em faixas qualitativas, sem números |
| S45 | https://pzfans.com/what-is-the-best-firearm-weapon-in-project-zomboid/ | PZ: dano por hit, build 42.19 (terceiro; resultado de busca, não aberto) |
| S46 | https://devforum.roblox.com/t/how-many-studs-is-there-in-a-meter/103417 | Fórum Roblox: 0,30 m e 0,35 m por stud (não é oficial) |
| S47 | https://win.gg/news/the-ultimate-tarkov-healing-guide-2024/ | Tarkov: total de 440 HP (resultado de busca, não aberto) |

Tarkov: os valores de HP por parte (cabeça 35, estômago 70, braços 60, tórax 80 ou 85) vêm de guias que apareceram na busca. Não consegui abrir nenhum guia com esses números, então confirme no jogo antes de usar.

Failed fetches (não usados): colt.com spec sheet (PDF ilegível), glock.com Gen5 (404), beretta.com (vazia), escapefromtarkov.fandom.com e wiki.gg (402/401), pzwiki.net/wiki/Health (403), globalsecurity.org (403).
