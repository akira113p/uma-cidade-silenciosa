# Limites e custos de assets no Roblox

Pesquisado em 2026-11-03. Fontes oficiais lidas direto nas páginas do Creator Hub (marcadas como **lida**). Itens marcados como **trecho de busca** vieram só de resumos de busca e precisam ser conferidos na página.

## Resumo por tipo

| Tipo | Limite principal | Custo | Quota | Fonte |
|---|---|---|---|---|
| Áudio (.mp3, .ogg, .wav, .flac) | até 20 MB e 7 min; uma faixa; até 48 kHz; mono, estéreo, 2.0, 3.0 ou 5.1 | grátis (página não cita taxa) | 2.000 por 30 dias se verificado por ID; 100 se não verificado | **lida** |
| Malha (.fbx, .obj, .gltf) | até 20.000 triângulos por malha; até 4 ossos por vértice | não citado | sem quota | **lida** (specs) |
| Textura separada no Studio (.png, .jpg, .tga, .bmp) | até 4096×4096 | não citado | não citada | **lida** |
| Mapa UV (textura de malha) | até 1024×1024 | - | - | **lida** |
| Decal / imagem via API (.png, .jpeg, .bmp, .tga) | até 20 MB por chamada; menor que 8000×8000 | não citado | sem quota | **lida** (Usage guide) |
| Miniatura de jogo (.jpg, .gif, .png, .tga, .bmp) | ideal 1920×1080, 16:9; até 3 MB | - | - | trecho de busca |
| Vídeo (.mp4, .mov) | até 5 min; até 4096×2160; até 3,75 GB; sem canal alfa | **2.000 Robux por vídeo** | 20 por dia; 13+ e verificado por ID | **lida** |
| Animação (.rbxm, .rbxmx) | até 20 MB por chamada | não citado | sem quota | trecho de busca |
| Pacote de animação | clipes até 10 s, rig R15 padrão, CurveAnimation | **80 Robux por pacote** | 1 pacote por dia | trecho de busca |
| Fonte | não pode ser importada; usar as da Creator Store | - | - | trecho de busca |

## Áudio (detalhes)

- Formatos: .mp3, .ogg, .wav, .flac. Precisa ser uma faixa só.
- Tamanho e duração: menos de 20 MB e até 7 minutos.
- Taxa de amostragem: até 48 kHz. Canais: mono ou estéreo (2.0, 3.0 ou 5.1).
- Quota por 30 dias: 2.000 para contas com verificação de ID, 100 para contas sem. A página diz que o limite diário foi substituído por um mensal simplificado.
- Custo: a página não menciona taxa em Robux para importar áudio. Os 10 Robux por upload que aparecem em sites são de fontes fracas e não batem com a documentação.
- Transcodificação: o Studio converte o áudio ao salvar. Arquivos com cabeçalho ou frames inválidos podem ser rejeitados.
- Moderação: o áudio precisa passar pela moderação antes de ser reutilizado. Efeitos sonoros vão para o Creator Store; músicas precisam passar por verificações de direitos autorais e outros requisitos para aparecer na página do jogo.
- Pré-visualização: o jogador ouve 15 segundos na página de música.
- Direitos: você precisa ter direito legal sobre o áudio.

Consequência para o projeto: passos, tiros, sons de monstro e ambiente em loop cabem nos limites. Ambiente com mais de 7 minutos precisa ser dividido.

## Malhas e modelos

- Limite de triângulos: **20.000 por malha** (página de especificações gerais, **lida**). Um guia antigo de personagens fala em 10.000 por parte de malha. Usar 20.000 como teto e 10.000 como alvo seguro.
- Vértice: no máximo 4 ossos.
- Animação exportada com a malha: só uma trilha por malha ou modelo.
- Formatos do Importer: .fbx, .obj, .gltf. A página do importer também cita .glb numa seção de glTF. Somente .fbx e .gltf suportam vários objetos, texturas PBR, rig, animação e cores de vértice.
- Acessórios de avatar têm orçamento próprio (acessório em camadas até 4k triângulos; corpo completo cerca de 10.742). Não se aplicam a monstros.
- Não encontrei limite de tamanho de arquivo de FBX.

## Texturas e materiais

- Texturas importadas separadamente no Studio: até 4096×4096.
- Mapa UV: até 1024×1024. Esses dois números estão na mesma página e não estão explicados lá.
- Tamanho recomendado: 256×256 para objetos de 5×5 studs; 512×512 para 10×10; 1024×1024 para 20×20.
- PBR (SurfaceAppearance): albedo RGB 24 bits; normal RGB 24 bits, só em formato OpenGL; rugosidade, metalicidade e máscara emissiva em tons de cinza de 8 bits.
- Cada malha aceita um material só.
- Decal via API: menor que 8000×8000 (a página do Creator Store diz que decals acima de 1024×1024 são reduzidos; isso não é documentação oficial).

## Vídeo

- Custo: **2.000 Robux por vídeo** (**lida**). A página não diz data de vigência.
- Limite: 20 vídeos por dia.
- Requisitos: .mp4 ou .mov, até 5 min, até 4096×2160, até 3,75 GB, sem canal alfa, usuário 13+ com verificação de ID, e a função Video Uploads ativada em File > Beta Features.

## Pacote de animação

- Custo: **80 Robux por pacote** (trecho de busca).
- Uma vez por dia por criador; clipes de até 10 s; rig R15 padrão; CurveAnimation.

## Conflitos entre fontes

- **Triângulos por malha:** 20.000 (especificações gerais) x 10.000 (guia antigo de personagens). Prevalece o mais novo, 20.000.
- **Textura:** 4096 (importação no Studio) x 1024 (mapa UV) na mesma página. Não resolvido.
- **Vídeo, tamanho:** 20 MB por chamada da API x 3,75 GB no limite de vídeo. Provavelmente o de 20 MB vale para outros tipos. Não resolvido.
- **Vídeo, diário:** 20 por dia para qualquer conta verificada (página de vídeo) x só 13+ e verificado (guia de assets). Vale o requisito mais restritivo até confirmar.
- **Áudio, custo:** página oficial diz gratuito dentro da quota; sites antigos citam Robux. Vale a página oficial.

## Pendente de conferir

- Fonte de FBX: limite de tamanho de arquivo.
- Custo de upload de áudio, textura, malha e animação na janela de upload do Studio (a documentação não cita).
- Se fontes podem ser importadas por código ou só usadas da Creator Store.
- Limite exato de ossos e vértices para monstros com rig próprio.

## Fontes

- [Audio assets](https://create.roblox.com/docs/audio/assets) (lida)
- [Usage guide for assets](https://create.roblox.com/docs/cloud/guides/usage-assets) (lida)
- [General specifications](https://create.roblox.com/docs/art/modeling/specifications) (lida)
- [Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications) (lida)
- [Video frames](https://create.roblox.com/docs/ui/video-frames) (lida)
- [Importer](https://create.roblox.com/docs/studio/importer) (lida)
- [Create and publish animation packs](https://create.roblox.com/docs/avatar/animation-packs) (trecho de busca)
- [Custom characters](https://create.roblox.com/docs/resources/beyond-the-dark/custom-characters) (trecho de busca, guia antigo)
