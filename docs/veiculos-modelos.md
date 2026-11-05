# Veículos com modelos do PZ: contrato

Complementa `docs/veiculos.md`. Partes: M0 fontes (Haiku), M1 Blender (Sonnet), M2 código (Sonnet), revisão (Opus).
Decisão não prevista aqui: **não decidir**. Anotar em `docs/pendencias-integracao.md`, seção "Veiculos modelos", e parar nesse ponto.

## Decisões do usuário (2026-11-03)

- Usar os modelos do Project Zomboid. Envio ao Roblox por chave Open Cloud.
- 6 tipos, cada um inteiro + queimado: sedan = `Vehicles_CarNormal`, compacto = `Vehicles_SmallCar`, suv = `Vehicles_SUV`,
  pickup = `Vehicles_PickUpTruck`, van = `Vehicles_Van`, esportivo = `Vehicles_SportsCar`. Mais 1 roda.
- Carroceria cortada no Blender. Malha e textura originais do PZ, sem filtro PS2.
- Interior: cabine do modelo + painel e colunas em blocos por código, mais volante e braços da Cabine.
- Chuva no vidro e limpadores: fora desta rodada.

## Decisões do usuário (2026-11-03, 2ª rodada) e como ficaram

- **Pintura**: 4 PNG opacos por tipo (`pintar_texturas.py`, 24 no total), cores de `Config/Veiculos.tipos[t].cor`. Manifesto: `inteiro.texturas` (lista); `gerar_config.py` grava
  `inteiro.texturas = { "rbxassetid://...", ... }` (`false` onde a imagem ainda não foi enviada, para manter o índice); `VeiculoModelo` sorteia um índice ao nascer e usa a cor de
  blocos de mesmo índice. Queimado: `textura` única.
- **Escala por tipo** (regra: personagem sentado cabe). `veiculos_pz.py --medir` lança um raio para cima sobre o banco do motorista (a 1.8 studs atrás do volante), acha o lado
  de dentro do teto e escolhe a escala para ele ficar a 4.70 do piso (banco 0.8 + 3.55 + 0.35). Grava `escala` e `medida` em `cortes.json`. O FBX já sai na escala nova
  (`dimensoes`, centros, tamanhos e rodas do manifesto também). Olho = banco + 2.70. Bancos: `x`/`z` no manifesto (`bancos`, `olho`, `banco_topo`, `teto_interno`).
- **Rodas**: raio = 0.15 (PZ) x studs por unidade do jogo x escala (sedan 1.14); centro da roda a 0.3 x raio da base. Massa da roda constante (densidade / raio^3); o atributo `Torque`
  sobe com o raio (força no chão = torque / raio) e o freio também: suspensão e massa do chassi ficam como estavam.
- **Sair**: ver `docs/decisoes.md`. `Rede.SairCarro`; `Direcao` liga E (`Config/Veiculos.teclas.sair`) e o botão Sair; `Veiculos` destrói o `SeatWeld` e, quando o `Occupant` vira nil
  (E, pulo, outro), `colocarAoLado` busca chão e espaço livre ao lado do carro.
- **Olho**: atributo `OlhoLocal` (espaço do Chassi) posto por `VeiculoModelo`; `Config/Veiculos.camera` só guarda tremor/roll.
- **Mapa**: `Veiculos.nascerNoMapa` testa a caixa do carro (sem chão, ruas, zonas, pontos, rios, o prop e outros props de carro) e deixa o prop se colidir.
- Ordem das ferramentas: `pintar_texturas.py` → `veiculos_pz.py --medir` → `--tipos <t>` e `--queimado` por tipo → `--roda` → `montar_manifesto.py` → `gerar_config.py`.

## Fluxo

```
FBX do jogo → ferramentas/modelos/ (Blender, sem janela) → modelos 3d/veiculos/*.fbx + manifesto.json
           → enviar_veiculos.py (Open Cloud) → assetId → src/shared/Config/VeiculosMalhas.luau → servidor carrega no início
```

## M1: Blender (`ferramentas/modelos/`)

- `fbx_ascii.py`: conversor FBX ASCII → JSON (base em `C:\Users\cerfr\AppData\Local\Temp\claude\d--programacao-projetos-jogos-roblox-uma-cidade-silenciosa\f9d11498-e7e7-47cf-a0a5-95519b6bd85d\scratchpad\fbx_ascii_to_json.py`).
  FBX ASCII não abre no Blender 5.2. Binário importa direto.
- `veiculos_pz.py`: roda com `blender.exe -b --python`. Blender em `C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe`.
- `cortes.json`: regiões de corte por tipo, para o corte ser reproduzível e ajustável.
- Eixos e escala de saída: frente do carro em -Z do Roblox, cima +Y, origem no centro da base do carro, escala uniforme até o comprimento de 11 studs
  (van pode passar disso, proporcional). Saber qual ponta é a frente pela geometria (capô/para-brisa) e conferir no render.
- Inteiro: um FBX por tipo com objetos nomeados exatamente `Carroceria`, `Capo`, `PortaMalas`, `PortaE`, `PortaD`, `ParaChoque`,
  `Vidro_ParaBrisa`, `Vidro_Traseiro`, `Vidro_JanelaE`, `Vidro_JanelaD`, e `Volante` se der para isolar. Sem rodas. UV preservada.
  Sem peça que o modelo não tenha: registrar no manifesto.
- Queimado: um FBX com um objeto `Carroceria`, sem corte.
- Roda: um FBX `roda`, eixo em X, raio 1 stud.
- Malha ≤ 20.000 triângulos; textura ≤ 1024×1024 (reduzir cópia, nunca o original).
- `modelos 3d/veiculos/manifesto.json`: para cada arquivo: tipo, estado, textura, por peça `tamanho` e `centro` (studs, espaço do carro), triângulos;
  por tipo `dimensoes` e posição das 4 rodas no eixo do carro.
- Verificação obrigatória: render por tipo com cada peça numa cor, por fora e sem teto, em `modelos 3d/veiculos/renders/`. Olhar as imagens.
  Corte ruim (peça rasgada, buraco grande) é refeito em `cortes.json`.

## M2: código

Mantém os blocos como colisão e alvo: tudo em `docs/veiculos.md` continua valendo. A malha é só visual.

- `src/shared/Config/VeiculosMalhas.luau`: por tipo: `inteiro` e `queimado` (`{ modelo = assetId?, textura = "rbxassetid://..."? }`), `dimensoes`,
  rodas. Sem assetId, o carro segue em blocos, sem erro. Gerado de `manifesto.json` por `ferramentas/modelos/gerar_config.py`.
- `server/VeiculoModelo`: troca `trocarPorMolde`. No início, `InsertService:LoadAsset` de cada `modelo` uma vez, em `pcall`, guardando moldes em
  `ServerStorage.Modelos.Veiculos`. Falhou: blocos e `warn`.
  Em `criar`: cada bloco com malha de mesmo nome fica `Transparency = 1` (`TranspBase = 1`), continua com colisão e `PecaVeiculo`; a malha vira
  `<Nome>_Malha`, `Massless`, `CanCollide/CanQuery/CanTouch = false`, soldada ao Chassi, com `TextureID`.
  `aplicar`: a malha acompanha faltando/quebrado; vidro `ok` transparência 0.5, quebrado 0.25 clara, faltando some. Com malha, não escurece carroceria.
  Queimado usa o molde queimado inteiro e esconde os blocos.
  Rodas: `Roda_XX` invisível + malha `roda` soldada. Posições das rodas e `tamanho` vêm da Config quando existir.
- `client/Cabine`: acrescenta painel e colunas em blocos (locais, cor escura) e usa `dimensoes` do tipo. O volante do modelo fica escondido só para o motorista.
  Nada pode tapar a visão pelo para-brisa.
- `ferramentas/modelos/enviar_veiculos.py`: lê `ROBLOX_OPEN_CLOUD_KEY` e `ROBLOX_CREATOR_ID` do ambiente, nunca do repositório. Envia cada FBX como Model e textura
  como Decal pela API de assets v1, espera a operação, salva `modelos 3d/veiculos/enviados.json` e não reenvia o que já foi. Não executar: só o Opus roda, com a chave do usuário.

`pwsh scripts/checar.ps1` verde. Não publicar nem enviar nada. Sem commit.

## Envio e importação (2026-11-04)
- 44 arquivos enviados pela Open Cloud (`enviar_veiculos.py`, chave e criador lidos do `.env` na raiz, no .gitignore). `enviados.json` guarda `assetId`.
- Textura: o `assetId` devolvido é de um **Decal**; o MeshPart precisa do id da **imagem** (`InsertService:LoadAsset(decal)` → `Decal.Texture`). `enviados.json` guarda `decalId` (original) e `assetId` (imagem, usado por `gerar_config.py`). Reenviar um PNG novo exige repetir a conversão.
- Malha importada vem com **0,28 do tamanho** (FATOR_IMPORTACAO = 1/0,28) e **girada 180° em Y** (X e Z das peças negados; VIRAR_IMPORTACAO). Os dois ajustes estão em `server/VeiculoModelo.luau`. Medido: sedan 5,55 → 19,83 studs.
- Texturas recém-enviadas dão "Asset content representation is being generated" por alguns minutos; depois carregam.
