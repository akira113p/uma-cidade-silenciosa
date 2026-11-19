# Lanterna de peito (2026-11-17)

Pedido do usuário: a estética circular da lanterna do Gold Bright na 1ª pessoa, o modelo da imagem de referência (pacote PsxFlashLights)
preso nos personagens, animação de ligar/desligar e, na 3ª pessoa, a luz saindo do modelo. Pesquisa da lanterna original:
`pesquisa/gold-bright.md` §8.

## Como funciona
- **Modelo**: FlashLight_003 + textura Variation2 (escolhido por um agente Sonnet comparando renders com a imagem). Separado em
  `Corpo`, `Lente`, `Botao`, `Indicador`; enviado (Model 115311051324397, Image 125172766930899, aprovados). Arquivos em
  `modelos 3d/PsxFlashLights/roblox/` (manifesto, renders), scripts em `ferramentas/lanterna/`; `gerar_config_lanterna.py` ->
  `src/shared/Config/LanternaMalha.luau`.
- **Vestir** (`server/LanternaPeito`): equipar a lanterna pela barra = o modelo vai para o peito (`UpperTorso`, `Config/Lanterna.peito`),
  mãos livres para qualquer arma (antes ia para a mão esquerda via `ItemNaMao`). Corpo soldado no torso; Lente/Indicador soldados no Corpo;
  Botao num `Motor6D` (`BotaoJunta`). Sem asset, monta em blocos.
- **Animação** (`client/Lanterna`, em cada cliente, para todos os personagens): a chave sobe/desce (`BotaoJunta.Transform`, curso do manifesto),
  a lente vira Neon branca e o indicador vermelho acende; a luz sobe LINEAR em `Config/Lanterna.subida` (0,83 s, como o Gold Bright) e apagar
  corta na hora.
- **Luz**: 1ª pessoa = da cabeça (facho 55° + miolo 40°, branca, PointLight curta para braços/arma). 3ª pessoa e outros jogadores = da lente.
  A peça da luz da cabeça fica no `workspace` (local): **luz em peça filha da Camera não ilumina o mundo** (medido; a lanterna antiga sofria disso).

## Armadilhas medidas no Studio
- O Roblox gira a malha do FBX **180° em Y** ao importar (como os carros): `LanternaMalha.giroImportacao = 180`; cada MeshPart é girada no
  próprio centro e a solda do Corpo leva essa rotação (sem ela a lente foi parar atrás do corpo e a luz apontava para o peito).
- Em 1ª pessoa o corpo real (escondido só para o dono) fica na frente da câmera e bloqueia a sombra do facho: o cliente desliga `CastShadow`
  do próprio corpo (`sombraCorpo`) sempre que o dono está em 1ª pessoa. Isso só resolve em `Realistic`.
- **Realistic, 1ª ativação:** um SpotLight ligado pela primeira vez às vezes renderiza só um halo fraco até o `Enabled` ser desligado e
  religado (medido). `client/Lanterna.ativar(luz, ligada)` faz o aquecimento (liga, desliga e religa nas primeiras ativações). Toda
  atribuição de `Enabled` do arquivo passa por ele.
- **Brilho negativo não existe:** o Roblox zera `Brightness < 0`, então não dá para "escurecer manchas". A lente suja usa camadas positivas.
- Para ver o próprio personagem numa câmera de teste: `BindToRenderStep` em `Last`, `AutoRotate = false`, câmera em posição FIXA do mundo e
  `LocalTransparencyModifier = 0` a cada quadro (o modo 1ª pessoa travada esconde o corpo).

## Iluminação do place (2026-11-17)
- `Lighting.Technology` foi substituída pelo Unified Lighting (não é mais legível por script). Agora vale `Lighting.LightingStyle = Realistic`
  (equivale ao antigo Future: sombra real e cone correto do SpotLight). O Studio foi mudado por script e **o place NÃO foi salvo**;
  `default.project.json` e `build.project.json` já declaram `"LightingStyle": "Realistic"`. Custo de FPS no mapa de ~155 mil peças: **não medido**.
- `primeira.sombra = true` (miolo com sombra) em 1ª pessoa; em `terceira` fica `false`.

## Aparência da luz (afinada 2026-11-17, pedido: mais fraca, branca, lente suja)
- Brilho: 1ª pessoa externo 3,2 / interno 8; 3ª pessoa 2,7 / 6,8 (o original queimava o branco). Cor `{255,250,238}`.
- **Lente suja** (`Config/Lanterna.suja`): o Roblox não tem textura de luz (o `cookie` do Gold Bright é um disco com mancha). Imitação: 4 cones
  finos e levemente coloridos, desviados do eixo, que deixam a borda irregular. Só em qualidade 3. É aproximação, não textura real.

## Bola branca e luz "gasta" (2026-11-17, 2ª rodada, testado na ZonaTeste)
- O usuário mandou print de uma bola branca que apagava a parede. Causas medidas: (1) os 4 cones de `suja` (sem sombra) somavam no
  centro e faziam o branco e o anel arco-íris: `suja = {}`; (2) as luzes da cabeça, depois de muitas trocas de `Enabled` (piscar/apagar/religar),
  deixavam de iluminar parede a menos de ~15 studs, enquanto uma SpotLight nova no mesmo lugar iluminava. Agora `criarLuzesCabeca` cria luzes
  novas a cada acender e `luzCabecaApagada` as destrói; na piscada só o brilho vai a 0. As luzes da LENTE (3ª pessoa/outros) ainda usam `ativar`.
- De perto a luz pesa muito mais: `primeira.compensacao` multiplica o brilho por (distância no centro do facho / 22) ^ 0,5 (raycast por quadro,
  suavizado; `Regras/Lanterna.fatorDistancia`, testado). Base 6 / 1,4 a 22 studs (4,5 fraco, 8 estoura). Visto: tijolos aparecem a 9 e a 23 studs.
- Armadilha de teste: com as falhas ligadas (20–50 s, 25% apagar) quase toda captura caía numa falha. Para medir, subir `falha.intervalo`
  TEMPORARIAMENTE e conferir `LanternaLigada` junto de cada captura.

## Cookie: máscara de sujeira do facho (2026-11-17)
v1 (com borda preta) foi reprovada: virava um anel escuro na tela. v3 em uso (`88627567096322`): só manchas/digitais/poeira de dentro do disco,
alfa 0 fora dele, manchas reforçadas (no jogo aparecem como borrões escuros dentro do círculo). Texto abaixo: como foi feito.
- Textura gerada no ChatGPT por agente Sonnet: `assets/lanterna/bruto/lanterna_facho.png` (disco de luz sujo) e `lente_suja.png` (grime
  de lente, ainda sem uso). `ferramentas/lanterna/processar_facho.py` transforma o facho em `assets/lanterna/final/lanterna_cookie.png`
  (1024², PRETO com alfa: manchas/digitais/poeira escurecem, centro limpo, borda irregular), `enviar_cookie.py` sobe pela Open Cloud
  (id `111900406477515`, Approved, em `assets/lanterna/final/enviados.json`).
- Como entra: o Roblox não tem textura em luz. `client/Lanterna` (`criarCookie`/`atualizarCookie`) desenha uma `ImageLabel` preta
  (ScreenGui `LanternaCookie`, DisplayOrder 1) centrada onde o eixo do facho cai na tela, com raio = tan(55°/2)/tan(FOV/2) * metade da altura.
  Visto do vértice do SpotLight o cone é um círculo na tela em QUALQUER geometria, então a máscara casa com o mundo. Opacidade = `forca` * fator
  da luz (piscar/apagar/dia mexem junto). Só 1ª pessoa do dono; 3ª pessoa e outros jogadores não têm a máscara (continuam com os cones da `suja`).
- Config: `Config/Lanterna.cookie` (`imagem`, `raioImagem` = 0.46, `anguloTela`, `forca`, `minNivel`). Afinar `anguloTela` por captura se a borda
  da máscara não coincidir com a borda da luz. Os 4 cones de `suja` podem ser reduzidos/removidos se a máscara bastar.

## Falhas da lanterna (piscar, falhar, apagar)
- **Servidor decide** (`server/Lanterna`): com a lanterna acesa, a cada `Config/Lanterna.falha.intervalo` (20–50 s) sorteia uma falha:
  `piscar` (2–4 piscadas) ou, com chance `chanceApagar` (25%), `apagar` (tremida e fica apagada; o jogador recebe o Aviso e religa com **F**).
  Ao ligar, `chanceFalharAoLigar` (15%) faz um `ligar` (falha antes de acender de vez).
- Atributos no personagem: `LanternaFalhaTipo`, `LanternaFalhaT` (GetServerTimeNow) e, por último, `LanternaFalhaSemente`. Todo cliente deriva o
  mesmo padrão da semente (`Regras/Lanterna.padraoFalha`, LCG determinístico, testado em `tests/Lanterna.spec.luau`), então todos veem igual.
- O cliente aplica `Regras.fatorFalha` ao brilho de tudo (facho, lente, anel de sujeira).

## Pendente
- Playtest humano: a frequência e a intensidade das falhas (25% apagar) são números iniciais.
- O primeiro acendimento depende do aquecimento `ativar` (acima): confirmar em Play real que o círculo aparece de primeira.
- Salvar o place para guardar `LightingStyle = Realistic` (o Rojo já o pede, mas só ao conectar).
