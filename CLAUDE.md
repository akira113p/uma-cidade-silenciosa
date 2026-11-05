# Uma Cidade Silenciosa (título provisório)

Jogo Roblox de sobrevivência PvP numa cidade infestada por monstros cegos que caçam pelo som. Primeira pessoa,
estética PS1. Inspirado no conceito de "Um Lugar Silencioso", com nome e criaturas originais.
Comunicação em português, direta.

## Regras de versão (valem para toda IA, em toda sessão)
**Place oficial: "CIDADE SILENCIOSA", PlaceId `135860309517450`.** Este é o único lugar do texto onde o id é a referência (o outro é `servePlaceIds`
em `default.project.json`). Se o usuário trocar o place, trocar só esses dois.
1. **Um só place oficial.** Proibido criar `.rbxl` novo para testar, abrir outro place ou "montar um place de playtest". `build/place.rbxl` é
   artefato do `checar.ps1`, não se abre.
2. Ao abrir o Studio, antes de escrever nele: conferir `game.PlaceId` (o id acima) e `get_studio_state`. Id diferente = parar e avisar o usuário.
3. `rojo serve default.project.json` só nesse place, porta 34872 (o `servePlaceIds` recusa os outros). **Nunca** `rojo serve build.project.json`
   (tem o mapa, ~155 mil peças, e congela o plugin).
4. O mapa **não passa pelo Rojo**. Muda só por `lune run ferramentas/gerar_mapa.luau -- --final` (grava `mapa/Mapa.rbxm`) + substituição controlada de
   `Workspace.Mapa` no place oficial, com o usuário sabendo. Ninguém edita o mapa à mão no Studio.
5. **Todo teste é dentro do place oficial, mas no void:** `Workspace.ZonaTeste` em (6000, 300, 6000), em Play sempre que possível; nada dentro de
   `Workspace.Mapa`. Receita, limites do código e limpeza: skill `teste-no-void`.
6. **Só uma sessão escreve no Studio por vez.** Antes: `list_roblox_studios`/`get_studio_state`; Studio com Play ativo ou de outra sessão, não mexer.
7. **Toda mudança durável vai para arquivo no repo** (`src/`, `ferramentas/`, `docs/`), nunca só no Studio. O que ficar no place sem vir do repo
   (mapa gerado, malha enviada, ajuste manual) é registrado em `docs/pendencias-integracao.md` > "No place sem vir do repo".
8. **Nenhuma IA salva ou publica o place** (File > Save, Publish) sem o usuário pedir.
9. **Sessão versionada:** começa com `pwsh scripts/sessao.ps1 -Inicio`, termina com `pwsh scripts/sessao.ps1 -Fim -Mensagem "..."` (roda `checar.ps1`,
   atualiza `Config/Versao`, commita, cria a tag `sessao-AAAA-MM-DD-N`, faz push). **Sessões paralelas não fazem `git add -A` às cegas:** passar
   `-Caminhos a,b,c` só com o que é seu; o script imprime a lista do que entrou, e você a confere antes de dar o `-Fim` por bom.

## Estado
- Fase: **corte vertical escrito e integrado em 2026-11-01** (fases 1–8 do `docs/plano.md`). 7 partes escritas em
  paralelo por agentes Sonnet a partir de `docs/arquitetura.md`; integração e correções pelo Opus. `pwsh scripts/checar.ps1`
  verde (25 suítes Lune em 2026-11-05). Playtest pelo MCP num place montado (`build/integracao2.rbxl`, aberto direto, sem Rojo; **método aposentado em 2026-11-05**, ver Regras de versão):
  spawn nas vilas, velocidades 8/16/24, estamina, perna zerada, ruído → monstro investiga/caça, ataque por parte do
  corpo, tiro 110 dB atrai monstros, morte → bolsa → renascer com kit, arma na mão, HUDs. Sem erro de script no console.
- 2026-11-01 (2º dia): ajustes do primeiro playtest do usuário feitos e testados pelo MCP: spawn no chão nas vilas, agachar de
  verdade, cursor só nos menus, inventário no Tab, cidade 750×750, ciclo dia/noite, menu de admin no O, sem disco de ruído
  no chão. Detalhes em `docs/arquitetura.md` §8.
- Visual-alvo (2026-11-02): Silent Hill 1/Origins (névoa densa que varia com o ciclo, granulação animada, paleta fria
  dessaturada, acentos vermelhos). Sem textura de sujeira nas construções por ora; foco em converter os modelos de
  `modelos 3d` para PS1 com script Blender. Lista em `docs/plano.md` ("Visual: a fazer") e `docs/decisoes.md` (Pendentes).
- 2026-11-02 (mapa v2): interiores por código (59 móveis domésticos + 81 comerciais, 40 edifícios-base com paletas), cidade 900×900 com
  centro só de prédios altos, 30+ tipos de construção, relevo de colinas, 3 rios com pontes/passarelas, 2 viadutos, estradas, floresta de pinheiros
  (7000 árvores), props urbanos. 14 módulos em `ferramentas/mapa/` (contrato `docs/mapa-v2.md`); `gerar_mapa.luau --final` + `checar_mapa.luau` verdes;
  4 checagens verdes. Falta playtest humano do mapa novo (FPS com ~155 mil peças, água, interiores): ver `docs/pendencias-integracao.md` "Mapa v2".
- 2026-11-03 (filtro visual): arquitetura em `docs/filtro.md` (céu de névoa por caixa presa à câmera, névoa por altura em
  beams, aberração cromática por FOV em ViewportFrames, lente Glass, grão de média neutra, moldura VHS, postes à noite);
  6 partes escritas por Sonnet, auditadas e testadas pelo MCP. A Atmosphere saiu do Lighting (anulava a névoa). Faltam as
  texturas do ChatGPT (`assets/filtro/prompts-chatgpt.md`, precisa da extensão Claude in Chrome): ver
  `docs/pendencias-integracao.md` "Filtro".
- 2026-11-04 (destruição universal): arquitetura em `docs/destruicao.md` (material → classe e vida por stud; dano por tipo × classe; escurece em 4 estágios e quebra com vão
  permanente; tiro, pé de cabra, machado, garra, carro e atropelo usam o mesmo `Destruicao.dano`; Rastejador migra para ele). Código escrito por Sonnet em fases A/B/C, auditado pelo Opus;
  ver "Estado" do documento. Pendências de design (explosão da bomba, piso, móveis, vidro pelo monstro) em `docs/pendencias-integracao.md` "Destruição".
- 2026-11-04 (Rastejador, agora 2x = 5,8 studs): modelo real com 5 animações (Open Cloud, sem custo), degrau/salto, ataca jogador com impacto no quadro, morde carro ruidoso, arromba parede fechada
  (buraco permanente; migra para a destruição universal de `docs/destruicao.md`). Escala 2,908 studs = 5,234/1,8. Medidas e pendências em `docs/rastejador.md` (Estado) e `docs/pendencias-integracao.md` "Rastejador".
- 2026-11-05 (armas): arquitetura em `docs/armas.md` (11 armas, pente+recarga, 5 calibres, foguete que destrói construção, viewmodel em 1ª pessoa, corpo animado em 3ª). Código escrito por Sonnet
  (A1 regras, A2 servidor, A3 modelos, A4 animação, A5 cliente), `checar.ps1` verde, sem playtest. **Bloqueio:** Open Cloud 403 "User is moderated"; só 3 de 11 malhas enviadas, 0 animações. Ver "Estado" do documento.
- 2026-11-05 (combustível): arquitetura em `docs/combustivel.md` (tanque por carro, consumo, HUD/agulha/etiqueta na tampa, carro com vários ocupantes e troca de banco com F, bombas do posto com mangueira Verlet no cliente e estado no servidor,
  garrafa/galão com ids fixos `garrafaVazia/garrafaGasolina/galaoVazio/galaoGasolina`, bomba infinita). 5 partes escritas por Sonnet em paralelo, `checar.ps1` verde; **ainda não testado no Studio**. Pendências e defaults em `docs/pendencias-integracao.md` "Combustível".
- 2026-11-05 (itens no mundo): modelo de blocos para os 27 itens (`Config/ItensModelos`), item na mão (`ItemNaMao`), itens soltos no chão (`workspace.ItensChao`, sempre ancorados, arremesso balístico próprio),
  Largar põe o modelo no chão, morte espalha, a bolsa deixou de existir, coleta olhando + E, 35% dos 880 pontos Loot. Armas mantêm o `ArmaModelo`. Contrato, estado e pendências em `docs/itens-no-mundo.md` (§6-7).
- 2026-11-05 (sessão e versão): fluxo de versão único, descrito em "Regras de versão" acima: place oficial, `servePlaceIds`, `scripts/sessao.ps1` (-Inicio/-Fim, tag por sessão), testes no void
  (`.claude/skills/teste-no-void`). `checar.sh` usa a mesma build que o `.ps1` e o gerador v1 (legado) não grava mais em `mapa/Mapa.rbxm`. Os `.rbxl` antigos de `build/` ficam como estão (não apagar), mas não se abrem.
- Próximo: Fase 9 (playtest humano de 20 min com 3+ clientes, ajustar números), ouvir e confirmar os sons, decidir
  pendências de `docs/pendencias-integracao.md`.
- Rodar: `rojo serve default.project.json` (porta 34872, sem o mapa) + Connect, **só no place oficial** (ver Regras de versão); o mapa vem do place. Nunca abrir `.rbxl` de teste nem
  `rojo serve build.project.json`. Mapa: `lune run ferramentas/gerar_mapa.luau -- --final` + `lune run ferramentas/checar_mapa.luau`, e a substituição no place é controlada (regra 4). Testes de
  jogo: Play no place oficial, dentro de `Workspace.ZonaTeste` (skill `teste-no-void`). Comandos de teste: `ServerStorage.Teste:Invoke("lista")` no datamodel Server. Sessão: `scripts/sessao.ps1`.
- Fontes do conceito: board Miro (texto em `../teste1/exportar-miro/01-texto-completo-miro.md`), reaproveitamento do
  teste1 em `../teste1/exportar-miro/02-reaproveitamento.md`.
- Modelos de terceiros em `modelos 3d/` (monstros, armas, outros): temporários, serão modificados para a estética.

## Documentos
| Arquivo | Conteúdo |
|---|---|
| `docs/plano.md` | fases 0–9 do corte vertical, cada uma com verificação |
| `docs/arquitetura.md` | contrato entre as 7 partes: arquivos, funções públicas, atributos, rede, mapa |
| `docs/rastejador.md` | contrato e estado do Rastejador (modelo, animação, degrau, carro, arrombar) |
| `docs/preset-monstro.md` | preset do Rastejador (IA, animação, pipeline, números) como receita para monstros novos |
| `docs/mapa-v2.md` | contrato do gerador de mapa v2: módulos, dono, ctx, catálogo de edifícios, mobília, props |
| `docs/pendencias-integracao.md` | o que cada parte deixou para as outras / para decidir |
| `.claude/skills/teste-no-void/SKILL.md` | como testar no place oficial sem sujar o mapa: ZonaTeste, limites do código, limpeza |
| `scripts/sessao.ps1` | início/fim de sessão: pull, checagens, versão, commit, tag `sessao-AAAA-MM-DD-N`, push |
| `docs/combustivel.md` | combustível: tanque, posto, mangueira, recipientes, passageiros, HUD |
| `docs/itens-no-mundo.md` | modelo de blocos dos itens, mão, itens soltos no chão, largar/morte, coleta |
| `docs/destruicao.md` | sistema universal de dano a construções: materiais, dano por tipo, escurecer, quebrar, carro, integração |
| `docs/calculos.md` | todas as fórmulas e números (som, monstros, corpo, sobrevivência, câmera, PvP) |
| `docs/decisoes.md` | decisões do usuário + pendentes (skill `registrar-decisao`) |
| `pesquisa/` | APIs conferidas e fontes |

## Decisões tomadas
Sobreviver, sem missões. Multiplayer PvP. Corte vertical: som + monstros nível 1 sem animação + movimento + HUD.
Mapa no tamanho final com construções em blocos (interiores depois). Primeira pessoa dinâmica (tremor desativável),
terceira pessoa opcional. Filtro PS1 desde o início. Histórico em `docs/decisoes.md`.

## Regras do fluxo (herdadas do teste1)
- Código em arquivos via Rojo; números em `src/shared/Config`; rede em `src/shared/Rede.luau`; regras puras testáveis
  em `src/shared/Regras`. 4 checagens: `rojo build`, testes Lune, selene, stylua.
- Servidor decide ruído, dano e acerto. O cliente só pede.
- Quando algo der errado, a correção vira linha em "Armadilhas" na skill da área, com o motivo.

- **Exceção do filtro PS2 (2026-11-04):** Mumbler, Carniceiro e Esfolado ficam no modelo base (o Mumbler com a pose curvada da referência) (original, sem solda,
  decimação nem textura reduzida; só normaliza a altura). Lista `SEM_FILTRO` em `ferramentas/modelos/filtro_ps2.py`.
  Não rodar rig/animação do script neles; usar o esqueleto original. `modelos 3d/_ps2/todos_base.blend` = os 10 lado a lado.

## Studio / MCP
Mesmas regras do `../teste1/CLAUDE.md` (MCP oficial do Studio, confirmar o place antes de escrever, Blender MCP oficial
do Blender Lab).
