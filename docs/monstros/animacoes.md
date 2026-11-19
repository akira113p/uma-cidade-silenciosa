# Animações dos monstros (agente D, 2026-11-14)

Contrato: `docs/monstros/logica.md` §2.4, §3.4, §4.4, §5.6, §6.6, §7.6. Tudo enviado pela Open Cloud (só `Animation`; modelo e textura **não**
foram reenviados: o `.fbx` exportado foi trocado pelo antigo depois da exportação, mesmo sha; esqueleto e escala conferidos iguais).
Config gerado: `src/shared/Config/MonstrosMalhas.luau` agora tem, por monstro, `animacoes`, `duracao` (todos os clipes), `eventos` e `nativas`.

## Como foi feito
- **Corcunda, MonstroPS1, Florescida:** `ferramentas/modelos/refazer_monstros.py --etapa anim` (só a etapa anim; prep/rig intocados). O `Animador`
  ganhou: clipes por **tempo** com eventos; **correção de chão** quadro a quadro (pé e corpo nunca abaixo de z=0, medida na malha deformada em numpy);
  calibração do pé na pose neutra; **calcanhar gira na ponta do pé** (a ponta não arrasta); quique do quadril na fase certa (mais baixo logo depois
  do contato no passo, no meio do apoio na corrida); braço atrasado em relação à perna; Corcunda manca da perna R; **galope** da Florescida
  (um voo por ciclo, coluna flexiona, pitch balança); passos de ajuste sempre pelo ar (`passinho`). Também serve a rigs com outros nomes de osso
  (`ANIM[nome]["nomes"]`), usado pelo Wrapper.
- **Wrapper:** `ferramentas/modelos/animar_wrapper.py` (novo) lê `modelos 3d/wrapper/MonsterPSX.blend` (só leitura), tira as restrições IK e grava
  `Wrapper_anim.blend` + `Wrapper_anim.json`. **Achado:** o `.blend` original animava canelas/antebraços por restrição IK, e o exportador lê só as
  curvas: os clipes antigos chegavam ao Roblox **sem a IK** (pernas erradas). Agora cada osso que deforma recebe a pose final. Scream saiu
  (arquivo `anim/Wrapper_Scream.rbxm` e a linha em `enviados.json` apagados).
- **Rastejador:** `ferramentas/modelos/animar_rastejador_opus.py` (mesmo rig e mesmos ciclos, que já mediam bem) + `Pulso`, `Arrombar`;
  garras do Attack voltavam **arrastando 0,7 m no chão** (escorregão medido 0,085 m/quadro): agora voltam pelo ar (0,0035). Grava `Rastejador_anim_opus.json`.
- **Pipeline:** `exportar_rastejador.py` lê o JSON do script (perfil `dados`) e grava no manifesto `eventos` e `nativas_blend` (e `ciclica` por clipe);
  `gerar_anim_rastejador.py` mantém sempre o quadro de cada evento na decimação (30 keyframes); `montar_anim_rbxm.luau`: prioridade **Core** para
  Idle/Walk/Run/Arrancada, **Action** para todo o resto (Emboscada e Atordoado inclusive); `gerar_config_monstros.py` emite todos os clipes do
  manifesto, `eventos` e `nativas` (studs/s = m/s do .blend × escala). `video_monstros.py` (novo) faz vídeo e folhas.
- Erro do repouso (`gerar_anim_rastejador.py`): 0,0 nos cinco (MonstroPS1 2e-05). `rest_roblox_bruto.txt` de rastejador/wrapper/monstrops1 não foi tocado;
  corcunda/florescida rederivados (saíram idênticos).
- Medidas (de cada clipe, no JSON do script): `zmin_corpo`, `zmin_pes` (m do .blend), `escorregao_max_m_quadro` (deslocamento do ponto de contato
  plantado entre dois quadros, descontada a esteira do ciclo), `emenda_ciclo` (último quadro = primeiro: 0,0 em todos os cíclicos).
- Eventos ficam no quadro mais próximo (30 fps → múltiplos de 0,0333 s; Rastejador 24 fps).

## Por monstro
Velocidades nativas no tamanho final (studs/s). Ids = `rbxassetid` dos `Animation`.

### Rastejador (5,816 studs, 24 fps)
| Clipe | s | Eventos | id |
|---|---|---|---|
| Idle | 2,5 (loop) | | 104438747042041 |
| Walk | 1,333 (loop) | | 118854865410226 |
| Run | 0,667 (loop) | | 101228530234571 |
| Attack | 1,458 | impacto 0,75 | 95282390106880 |
| Death | 1,958 | | 99159905944593 |
| Pulso | 2,0 | encostou 0,583 (medido: 1º quadro com a barriga a < 1,2 cm do chão) | 115212802814725 |
| Arrombar | 0,917 | impacto 0,458 | 138880664417694 |

Nativas: Walk 1,59, Run 8,69. Escorregão: Walk/Run 0,015 m/quadro (1 quadro no toque da pata FR), Attack 0,0035, Arrombar 0,009, Pulso 0,011.
Vídeo `modelos 3d/_ps2/videos/Rastejador_v3.mp4`; folhas `videos/folhas/Rastejador_<Clipe>.png`.

### Wrapper (5,99 studs, 30 fps)
| Clipe | s | Eventos | id |
|---|---|---|---|
| Idle | 2,0 (loop) | | 95122845712418 |
| Walk | 1,0 (loop) | | 134675669413644 |
| Run | 0,533 (loop) | | 125185595075666 |
| Attack (investida de corpo, pé L dá o passo) | 1,0 | impacto 0,467 | 95839174890160 |
| WallSlam (ombro R) | 1,2 | impacto 0,5 | 75482192805357 |
| Sonar (arqueia, estufa, treme, solta) | 1,2 | onda 0,5 | 140102825284485 |
| Atordoado (loop, cambaleia e ajeita o pé R) | 2,0 (loop) | | 135079606792996 |
| Death (novo) | 1,5 | | 77536866292055 |

Nativas: Walk 2,65, Run 15,54 (caça 22 → Run a 1,4x). Escorregão ≤ 0,0003 nos ciclos. Vídeo `videos/Wrapper_v3.mp4`.

### Corcunda (5,816 studs)
| Clipe | s | Eventos | id |
|---|---|---|---|
| Idle | 2,0 (loop) | | 133201526418737 |
| Walk (manca da R) | 1,0 (loop) | | 100534892548685 |
| Run | 0,6 (loop) | | 121394558844883 |
| Attack | 0,9 | impacto 0,467 | 104200579813262 |
| Death | 1,5 | | 102747171727482 |
| Empurrao | 0,7 | impacto 0,333 | 127014390383821 |
| AbrirPorta (braço R) | 0,8 | porta 0,4 | 123278156859336 |
| Emboscada (loop) | 3,0 (loop) | | 71846367883726 |
| Imitar | 1,5 | | 71217902943780 |

Nativas: Walk 2,64, Run 13,22. Escorregão ≤ 0,0033; chão ≥ -0,002. Sem osso de mandíbula: o Imitar fala com pescoço/cabeça. Vídeo `videos/Corcunda_v3.mp4`.

### MonstroPS1 (5,816 studs)
| Clipe | s | Eventos | id |
|---|---|---|---|
| Idle | 2,0 (loop) | | 82206332851050 |
| Walk | 1,133 (loop) | | 72930579440713 |
| Run | 0,667 (loop) | | 83775484510519 |
| Attack | 0,9 | impacto 0,467 | 98282272832236 |
| Death | 1,5 | | 109433537588825 |
| GolpeDuplo (R depois L) | 1,0 | impacto1 0,333, impacto2 0,667 | 99132481199199 |
| Arrancada (loop, lâminas na ponta do chão) | 0,6 (loop) | | 77180601899698 |
| Lancar (mão R) | 0,8 | soltar 0,467 | 133607389220492 |

Nativas: Walk 2,26, Run 11,9, **Arrancada 13,64** (também em `nativas`). Na Arrancada o ângulo de cada braço é procurado quadro a quadro para a ponta da
lâmina ficar a ~3 cm do chão. Escorregão ≤ 0,0003. Vídeo `videos/MonstroPS1_v3.mp4`.

### Florescida (16 studs)
| Clipe | s | Eventos | id |
|---|---|---|---|
| Idle | 2,0 (loop) | | 74721051908770 |
| Walk | 1,333 (loop) | | 73527479399990 |
| Run (galope) | 0,5 (loop) | | 86479738624616 |
| Attack (mordida) | 0,9 | impacto 0,467 | 121875563300223 |
| Death | 1,5 | | 97065954411889 |
| Rugido | 1,6 | impacto 0,9 | 114588831768435 |
| Cauda | 0,9 | impacto 0,467 | 126030945096058 |
| Florescer | 1,5 | plantar 0,9 | 135170153372261 |
| ArrancarFachada | 1,8 | impacto 0,8 | 91230632196194 |

Nativas: Walk 5,3, **Run 59,26** (alvo ≈ 60). Florescer: busca de pitch/pescoço que leva a cabeça a 3,8 cm do chão (pitch 40°, pescoço 84°).
Vídeo `videos/Florescida_v3.mp4`.

## Abaixo do esperado / pendências
- **Nada foi visto no Roblox**: conferido só no Blender (medidas + vídeo/folhas). Falta tocar no place (ZonaTeste) e conferir os eventos com o golpe.
- Eventos caem no quadro mais próximo: Attack 0,467 (alvo 0,45), Empurrao 0,333 (alvo 0,35), Lancar 0,467 (alvo 0,45), Cauda 0,467 (alvo 0,45).
- Florescida: o casco da frente pesa no antebraço (pesos herdados do original): no passo o casco oscila até ~2,5 cm acima do chão e 1 quadro do
  Walk escorrega 4,6 cm no toque (FR). Florescer deixa o quadril alto (precisa pitch 40° para a cabeça chegar ao chão). Galope a 59 studs/s com apoio curto
  (27% do ciclo): no jogo, em velocidades baixas de caça (27) o Run toca a ~0,45x.
- MonstroPS1 GolpeDuplo: os braços nascem abertos para o lado (repouso 70° abaixo da horizontal), então os cortes saem mais horizontais que verticais.
- Rastejador: ciclos e Death mantidos do script anterior (só medidos); Death escorrega as patas abertas no chão (0,075 m/quadro), é corpo caindo.
- Wrapper: braços enrolados no corpo quase parados (é o conceito). O vídeo do Wrapper sai com fundo preto (mundo do `.blend` original), sem rótulo.
- `refazer_monstros.py` não tem mais estilo para o Esfolado (fora desta rodada por moderação); `--etapa anim --nome Esfolado` falha.
