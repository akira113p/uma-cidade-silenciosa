# Decisões

## 2026-11-03 · Filtro mais leve, névoa de dia mais longa e lanterna
- Decisão: o grão fica "bem de leve" (referência: Silent Hill 1, grão discreto), porque o filtro causou dor de cabeça no
  playtest; craquelado, poeira, estalos e riscos de filme também ficam bem mais discretos e raros.
- Decisão: a separação de cores do VHS (aberração) some com a distância: forte perto, fraca/nula em casas e prédios longe.
- Decisão: de dia a névoa começa longe (25 studs) e engrossa até 300; a noite continua curta (0–90).
- Decisão: o jogo ganha uma lanterna com luz realista (facho quente em cone, círculo de luz no chão, como na referência
  da foto noturna), equipável pela barra (slot 5 do kit), liga/desliga com F; o facho dos outros jogadores é visível.
- Decisão de fluxo: se o limite de uso da sessão chegar a 85%, pausar todos os agentes. **Limitação**: o assistente não
  consegue ler o percentual de uso; vale o aviso do usuário ou um erro de limite de algum agente.
- Substitui: "lanterna (decisão de design ainda não tomada)" em "Pendentes".

## 2026-11-02 · Fotos-alvo de dia e de noite: noite em sépia, moldura de VHS, imagens do filtro
- Decisão: a noite fica em sépia/marrom, como na foto-alvo da noite; o dia continua cinza frio dessaturado, sem céu azul.
- Decisão: o filtro inclui a moldura de VHS (borda arredondada, vinheta e linhas de glitch).
- Decisão: autorizado gerar as imagens do filtro (ruído, vinheta, moldura) e subir para a conta pelo MCP do Studio.
- Motivo: o usuário comparou as fotos-alvo (dia e noite) com o estado atual e confirmou os três pontos.
- Substitui: só a parte "tom frio dominante" da noite na decisão de referência visual (abaixo); o dia segue frio.
- Ordem prevista: céu cinza + névoa curta, cor por hora, granulação/vinheta/moldura, luzes de poste e lanterna.

## 2026-11-02 · Referência visual: Silent Hill (névoa, granulação, paleta fria)
- Decisão: o visual-alvo é o de Silent Hill 1/Origins (4 capturas de referência + descrição do usuário): névoa densa que
  oculta o horizonte, granulação animada em tela cheia, paleta dessaturada de tom frio dominante (cinza-azulado, bege
  encardido, verde-oliva) com acentos de vermelho (hidrante, sangue), pouca luz e sombras fundas, low-poly com textura de
  baixa resolução.
- Decisão: a névoa sobe e desce com o ciclo dia/noite (já é assim em `Config/Tempo.luz`; os números atuais, dia 40–450 e
  noite 15–160, são mais longos que os das referências e serão encurtados no playtest).
- Decisão: por enquanto as construções NÃO ganham textura de sujeira. O foco é converter os modelos que já temos
  (`modelos 3d`) para o estilo PS1. Textura suja nas construções fica para depois.
- Como fazer: lista em "Pendentes" abaixo e no `docs/plano.md` (seção "Visual: a fazer").

## 2026-11-02 · Modelo dos jogadores, versão 2 (nas proporções da nova referência)
- Decisão: corpo esbelto e alto (escalas R15 largura 0,68, profundidade 0,78, altura 1,05, iguais para todos), cabeça
  cúbica marrom escura com cabelo trançado dourado e rosto (sobrancelhas, olhos, boca, língua), suéter amarelo de
  tricô com bolso e cordões, cinto preto com fivela, bermuda bege de tricô, pernas escuras, tênis rosa de sola branca.
- Substitui: o modelo de 2026-11-01 (suéter mostarda, sem cabelo). Tudo em `Config/Aparencia.luau`.
- NÃO verificado no jogo: as ferramentas do Studio estavam desconectadas; só as 4 checagens de código passaram.

## 2026-11-01 · Modelo dos jogadores
- Decisão: todos os jogadores usam o mesmo modelo em blocos, baseado no personagem de suéter do carro; feito por código
  (sem Blender), por cima do R15. Cores e costura em `Config/Aparencia.luau`.

## 2026-11-01 · Névoa e tecla reserva do admin
- Decisão: a névoa vem de `Lighting.FogStart/FogEnd/FogColor` (a Atmosphere não aparecia no playtest). Dia 40–450 studs,
  noite 15–160, números em `Config/Tempo.luz`; chuva e tempestade encurtam. Medido só dia e noite (chuva não conferida).
- Decisão: o admin abre com **O** ou **K** (`Config/Admin.teclaReserva`); sem o atributo Admin o jogo avisa no Output.

## 2026-11-01 · Segunda rodada de ajustes (mouse, teclas)
- Decisão: o menu de admin abre com a tecla **O** (era F1); trocado por um agente Haiku, como o usuário pediu.
- Decisão: atalhos de menu passam por `client/Teclas.luau` (duas vias + diagnóstico no Output). Teclas reserva: I para o
  inventário e T para a terceira pessoa, caso Tab ou V estejam em conflito no computador do usuário.
- Decisão: o mouse é solto forçando `MouseBehavior = Default` depois da câmera; o botão Modal foi removido (não funcionava).
- Decisão: a lista de jogadores do Roblox (Tab) fica desligada.

## 2026-11-01 · Ajustes depois do primeiro playtest do usuário
- Decisão: o ruído aparece só no medidor (HudSom); o disco colorido no chão fica desligado (F8 liga, só no Studio).
- Decisão: o personagem nasce no chão, numa das vilas (SpawnLocation + RespawnLocation), nunca no centro da cidade.
- Decisão: agachar agacha de verdade (pose R15 nos Motor6D + quadril mais baixo, o que encolhe a hitbox).
- Decisão: o cursor fica escondido e preso fora dos menus; livre só com um menu aberto (módulo `client/Mouse.luau`).
- Decisão: Tab abre uma tela de inventário completa (grade, detalhes, usar/equipar/largar, corpo e estado).
- Decisão: a cidade central cai para a metade (750×750, antes 1500×1500).
- Decisão: ciclo de dia e noite de verdade: a luz acompanha a hora (24 min reais por dia, começa às 9h).
- Decisão: menu de admin no O (hora, clima, voar, imortal, curar, qualquer item). Só o Studio e o dono (UserId em
  `Config/Admin.luau`).
- Motivo: feedback do usuário depois de jogar o corte vertical.

## 2026-11-01 · Fluxo de construção
- Decisão: arquitetura detalhada por parte (`docs/arquitetura.md`) escrita primeiro; cada parte entregue a um agente
  Sonnet (esforço alto) trabalhando em paralelo; os bugs mais sérios que o Sonnet não resolver ficam com o Opus.

## 2026-11-01 · Sons
- Decisão: sons já colocados no corte vertical, tirados da biblioteca de sons do Roblox (Creator Store).
- Como ficou: catálogo em `src/shared/Config/Sons.luau`, 60 ids conferidos no place; todos `confirmado = false` até o
  usuário ouvir.

## 2026-11-01 · Tamanho do mapa
- Decisão: 4000×4000 studs, cidade de 1500×1500.
- Substitui (2026-11-01): cidade de 750×750.

## 2026-11-01 · Jogadores por servidor
- Decisão: 12.

## 2026-11-01 · Níveis dos monstros
- Decisão: usuário aprovou as 5 respostas da rodada; o nível de cada modelo ficou com a proposta do Config.
- Como ficou (PROVISÓRIO em `Config/Monstros.luau`): nível 1 Rastejador, Corcunda, Esfolado; nível 2 Espreitador,
  Carniceiro, Florescida; nível 3 Pernalta.

## 2026-11-01 · Voz no microfone
- Decisão: a voz do chat de voz entra no ruído: falar atrai monstros.

## 2026-11-01 · Morte no PvP
- Decisão: perde todo o inventário (vai para uma bolsa no chão).

## 2026-11-01 · Objetivo do jogo
- Decisão: sobreviver. Sem missões. Outros modos podem vir depois.
- Motivo: resposta do usuário na rodada 1 do grilling.

## 2026-11-01 · Multiplayer PvP
- Decisão: multiplayer com PvP; o jogador se preocupa com os outros jogadores e com os monstros.

## 2026-11-01 · Primeiro entregável
- Decisão: corte vertical = som + monstros nível 1 + movimento + HUD (proposta da rodada 1), sem animação para os monstros
  no início.

## 2026-11-01 · Mapa
- Decisão: mapa no tamanho que vai ter no jogo, pode ser menor que 1 km²; construções em blocos, interiores depois.

## 2026-11-01 · Modelos de terceiros
- Decisão: os modelos de `modelos 3d` serão modificados para a estética do jogo.

## 2026-11-01 · Câmera
- Decisão: primeira pessoa como padrão, dinâmica (passos sentidos, tremor), com opção de desativar nas configurações;
  terceira pessoa como opção.
- Substitui: proposta de terceira pessoa como padrão.

## 2026-11-01 · Visual
- Decisão: filtro PS1 desde o início, para a estética ficar parecida.

## 2026-11-01 · Cálculos
- Decisão: usuário pediu os cálculos completos; feitos em `docs/calculos.md` (valores PROVISÓRIO até o playtest).

---

## Pendentes
- **Visual (referência Silent Hill)**, por ordem:
  1. Encurtar a névoa em `Config/Tempo.luz` (alvo a testar: dia ~60–150, noite ~25–70 studs) e fixar um tom dominante frio;
     comparar 2–3 variações por `screen_capture`.
  2. Granulação animada em `client/FiltroPS1.luau` (ruído deslocado/girado a ~12–15 quadros/s, no lugar do dither estático;
     scanlines opcionais). Conferir o id do dither (é Decal, não Image).
  3. Script de conversão dos modelos de `modelos 3d` para o estilo PS1 (Blender, em lote): reduzir triângulos, encaixar
     vértices numa grade, textura 64–128 px com paleta de 15 bits + dither e ampliar sem suavização para 512 px, material
     simples, exportar FBX + manifesto.
  4. Acentos de vermelho (hidrantes, sangue) como regra de paleta.
  5. Depois: textura de sujeira nas construções; lanterna (decisão de design ainda não tomada).
- Nome do jogo (título provisório "Uma Cidade Silenciosa").
- As "exceções" dos monstros que o Miro diz que vão ser explicadas.
- Ouvir e confirmar cada som do catálogo (trocar os de origem HL2/CSGO/SCP antes de publicar).
- `Players.MaxPlayers = 12` é configuração do jogo publicado (Game Settings), não do código.

## 2026-11-03: carros com modelos do Project Zomboid
Usar os modelos do PZ, enviados por chave Open Cloud. 6 tipos (sedan, compacto, SUV, pickup, Vehicles_Van, esportivo), inteiro + queimado.
Carroceria cortada no Blender, malha e textura originais, sem filtro PS2. Interior: cabine do modelo + painel e colunas em blocos.
Chuva no vidro e limpadores ficam para depois. Contrato: `docs/veiculos-modelos.md`.

## 2026-11-03: carros, pintura, escala e sair do carro
1. **Pintura**: assar 4 cores por tipo (24 PNG opacos `modelos 3d/veiculos/texturas/<tipo>_cor<n>.png`): pintura onde a shell do PZ tem alfa 0, com o sombreado do RGB;
   cromados, luzes e vidros intactos. Cores = as 4 primeiras de `Config/Veiculos.tipos[t].cor` (faltando, repete as do tipo). O jogo sorteia uma por carro ao nascer.
   Queimados mantêm a textura deles.
2. **O personagem cabe sentado**: acima do topo do banco ele ocupa 3.55 studs (cabeça a 2.70), abaixo 0.74. Escala uniforme POR TIPO para o vão (topo do banco até o lado
   de dentro do teto, medido na malha) ser 3.55 + 0.35. Banco baixo (topo a 0.8 do piso): cada carro com cerca de 5 de altura, sedan com cerca de 20 de comprimento.
   Olho = topo do banco + 2.70.
3. **Entrar e sair**: entrar por prompt e nas portas. Sair: tecla E dentro do carro (evento `SairCarro`), pulo também; o servidor põe o jogador ao lado da porta, em lugar livre
   (esquerdo primeiro para o motorista; bloqueado, o direito). Celular: botão Sair. HUD: E sair, G ligar, H buzina.
4. **Mapa**: carros maiores substituem props de 11 studs só se não colidirem com construção (o prop fica se colidir).

## 2026-11-04: destruição universal das construções
- Decisão: **um sistema único** de dano a construções. Tiro, golpe (pé de cabra, machado; marreta no futuro), garra de monstro e carro dão dano ao **material**
  da peça; ela **escurece** conforme leva dano e depois **quebra**, abrindo buraco permanente. Carro que bate em monstro ou construção também dá dano e se quebra.
  O Rastejador passa a usar o mesmo sistema (sem lógica própria de buraco). Contrato: `docs/destruicao.md`; números em `docs/calculos.md` §7 (PROVISÓRIO).
- Materiais considerados: concreto, tijolo, madeira, vidro/janela, metal, bomba de combustível (grupo).
- Pendentes (não decididos, ver `pendencias-integracao.md` "Destruição"): explosão da bomba/tanque, piso e cofre destrutíveis, móveis com loot, monstro quebrar vidro
  para entrar, carro pegar fogo/explodir, carro perder velocidade ao atravessar parede.

## 2026-11-05: itens com modelo 3d e itens soltos no mundo
1. **Modelo**: todo item de `Config/Itens` ganha modelo próprio de blocos (Parts simples, PS1), usado na mão (arma, lanterna, comida/cura durante o uso) e no chão.
2. **Largar e morrer**: o botão Largar põe o modelo do próprio item no chão, arremessado em arco; na morte cada item do inventário vira um modelo espalhado em volta do corpo.
   **A bolsa marrom deixa de existir** (some `workspace.Bolsas`, `Inventario.conteudoBolsa/retirarDaBolsa`).
3. **Coleta**: olhar para o item (até 8 studs) e apertar E; o cliente destaca e mostra nome e tecla. Sem ProximityPrompt por item.
4. **Itens no mapa**: nascem nos 880 pontos Loot já existentes (`workspace.Mapa.Pontos`), cada um com 35% de chance, usando a `Tabela` do ponto. Pegado, volta (sorteio novo) após 15 min.
   Móveis com compartimento continuam como estão.
Contrato: `docs/itens-no-mundo.md`.
