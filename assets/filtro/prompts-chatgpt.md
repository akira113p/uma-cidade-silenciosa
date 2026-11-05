# Prompts do ChatGPT para as texturas T1-T5

Contrato: `docs/filtro-texturas.md`. Salvar tudo em `D:\programacao\projetos\jogos\roblox\uma cidade silenciosa\assets\filtro\bruto\<nome>.png`.
Nota: o ChatGPT não deixa escolher pixels exatos. Proporção certa basta (1:1, 1:2, 16:9, faixa larga); o redimensionamento é feito depois.

Cada prompt é autocontido. Cole inteiro, em chat novo.

---

## T1a - `neblina_mecha_a.png` (quadrada 1:1)

Prompt:
```
Generate a square 1:1 seamless-tile texture asset for a video game (not a scene, not an illustration). Content: soft wisps and streaks of white fog/smoke, drifting horizontally, abstract and formless. The background is pure solid black (#000000). The fog is white and neutral gray only, no color. The fog is densest in the bottom half of the image and thins out gradually toward the top, fading to pure black at the top edge. The texture must tile seamlessly horizontally: the left edge and right edge must match exactly so that placing copies side by side shows no seam. No hard edges, no recognizable shapes or objects, no text, no watermark, no frame, no border, no vignette. Flat texture map, front view, high contrast between fog and black background.
```

Correção:
```
Wrong. Redo it: the left and right edges must match each other exactly (seamless horizontally), the fog must be densest at the bottom and fade to pure black at the top, and the background must be pure black #000000 with no color.
```

Checagem visual:
1. Imagem quadrada, fundo preto, só neblina branca/cinza (sem cor).
2. Metade de baixo mais densa/clara que a de cima; o topo fica quase preto.
3. A borda esquerda e a direita parecem iguais (nenhum corte vertical visível no meio da neblina que encosta nas laterais).
4. Sem texto, moldura, marca d'água ou objeto reconhecível.

---

## T1b - `neblina_mecha_b.png` (quadrada 1:1, variação diferente)

Prompt:
```
Generate a square 1:1 seamless-tile texture asset for a video game (not a scene, not an illustration). Content: thick, slow-rolling banks of white fog with a few thin trailing wisps, abstract and formless, a different pattern from a typical cloud photo. The background is pure solid black (#000000). The fog is white and neutral gray only, no color. The fog is densest in the bottom half of the image and fades gradually to pure black toward the top edge. The texture must tile seamlessly horizontally: the left edge and right edge must match exactly so that placing copies side by side shows no seam. Soft edges only, no recognizable shapes or objects, no text, no watermark, no frame, no border, no vignette. Flat texture map, front view, high contrast between fog and black background.
```

Correção:
```
Wrong. Redo it: the left and right edges must match each other exactly (seamless horizontally), the fog must be densest at the bottom and fade to pure black at the top, and the background must be pure black #000000 with no color.
```

Checagem visual:
1. Quadrada, fundo preto, só branco/cinza.
2. Densa embaixo, topo quase preto.
3. Laterais casam entre si.
4. Padrão claramente diferente de T1a (formas de mecha diferentes). Sem texto/moldura/marca d'água.

---

## T2 - `neblina_puff.png` (quadrada 1:1)

Prompt:
```
Generate a square 1:1 particle texture asset for a video game (not a scene, not an illustration). Content: one single soft, irregular puff of white fog/smoke, centered in the image, with uneven wispy edges and a denser core. The puff fades smoothly to pure black well before the borders: nothing may touch the edge of the image, and the outer 15% of the image on every side is pure black. The background is pure solid black (#000000). White and neutral gray only, no color. No recognizable shapes or objects, no text, no watermark, no frame, no border. Flat texture map, front view, high contrast between the puff and the black background.
```

Correção:
```
Wrong. Redo it: the edges must fade to pure black; nothing may touch the border. One single centered puff only, white/gray on pure black #000000, no color.
```

Checagem visual:
1. Quadrada, fundo preto, uma única nuvem branca macia no centro.
2. Nenhum branco encosta nas 4 bordas (margem preta ao redor).
3. Sem cor, sem texto, moldura ou marca d'água.
4. Bordas da nuvem irregulares e suaves (não um círculo perfeito).

---

## T3 - `cone_luz.png` (retrato 1:2)

Prompt:
```
Generate a portrait-orientation 1:2 texture asset (width half of height) for a video game (not a scene, not an illustration). Content: a volumetric light beam seen from the side, as light passing through fog: narrow and bright at the top, widening and fading gradually toward the bottom, like a cone. Soft glowing side edges that fade smoothly to black. A few very subtle tiny dust specks inside the beam. The beam is white/neutral gray only, no color. The background is pure solid black (#000000). The beam must not touch the left or right borders. No lamp, no light fixture, no pole, no ground, no recognizable objects, no text, no watermark, no frame, no border. Flat texture map, high contrast between the beam and the black background.
```

Correção:
```
Wrong. Redo it: portrait 1:2, only the beam on pure black #000000, narrow and strong at the top, wider and weaker at the bottom, soft side edges that fade to black, no lamp and no pole, no color.
```

Checagem visual:
1. Imagem em pé (altura = 2x largura), fundo preto.
2. Feixe estreito e forte em cima, largo e fraco embaixo.
3. Laterais suaves, sem tocar a borda esquerda/direita; sem lâmpada, poste ou chão.
4. Só branco/cinza; sem texto, moldura ou marca d'água.

---

## T4 - `faixa_tracking.png` (faixa larga 16:1)

Prompt:
```
Generate a very wide, thin horizontal strip texture asset with aspect ratio 16:1 (for example 2048 by 128 pixels) for a video game (not a scene, not an illustration). Content: VHS tape tracking-error noise: thin white horizontal streaks, static snow, small horizontally displaced dashes and glitch lines, filling the strip. The background is pure solid black (#000000). Elements are white and neutral gray, with at most a very faint red or cyan tint on a few streaks. The strip must tile seamlessly horizontally: the left end and right end must match exactly. No recognizable objects, no text, no watermark, no frame, no border. Flat texture map, high contrast between the noise and the black background.
```

Correção:
```
Wrong. Redo it: a very wide thin strip with 16:1 aspect ratio, VHS tracking noise in white on pure black #000000, left and right ends must match exactly (seamless horizontally), almost no color.
```

Checagem visual:
1. Faixa bem larga e baixa (cerca de 16:1), fundo preto.
2. Riscos horizontais brancos finos e chuvisco; sem formas reconhecíveis.
3. Quase sem cor (no máximo leve vermelho/ciano nos riscos).
4. Extremidades esquerda e direita parecem casar. Sem texto, moldura ou marca d'água.

Obs.: se o ChatGPT não entregar 16:1, aceite a mais larga que ele fizer (ex.: 3:2 ou 16:9) e anote no relatório; o recorte é feito depois.

---

## T5 - `poeira_lente.png` (16:9)

Prompt:
```
Generate a 16:9 landscape overlay texture asset for a video game (not a scene, not an illustration). Content: sparse dust specks, tiny lint fibers and thin scratch lines, like dust and scratches on a camera lens or old film. Elements are white and neutral gray only, no color. The background is pure solid black (#000000). The elements are sparse and cover less than 5% of the image area, and they are more concentrated near the edges and corners than in the center, with the center mostly empty black. No recognizable objects, no text, no watermark, no frame, no border. Flat texture map, high contrast between the elements and the black background.
```

Correção:
```
Wrong. Redo it: 16:9, pure black #000000 background, only sparse small white dust specks, fibers and thin scratches covering under 5% of the area, concentrated near the edges, center mostly empty, no color.
```

Checagem visual:
1. Imagem 16:9 horizontal, fundo preto.
2. Poucos pontos, fiapos e riscos finos brancos (muito preto sobrando).
3. Mais elementos nas bordas/cantos que no centro.
4. Sem cor, texto, moldura ou marca d'água.

---

## Operação (agente do navegador)

Fazer uma imagem por vez, na ordem T1a, T1b, T2, T3, T4, T5. Para CADA imagem:

1. Abrir uma aba nova em `https://chatgpt.com/` e iniciar um CHAT NOVO (botão "New chat"). Nunca reutilizar o chat de outra imagem.
2. Copiar o texto do bloco "Prompt" da imagem (só o texto de dentro do bloco, sem as três crases) e colar na caixa de mensagem. Enviar.
3. Esperar até a imagem terminar de gerar (o indicador de carregamento some e a imagem aparece inteira). Pode levar 1 a 2 minutos. Não enviar mais nada antes disso.
4. Olhar a imagem e conferir os itens da "Checagem visual" daquela imagem, um por um.
5. Se algum item falhar: colar no mesmo chat o texto do bloco "Correção" daquela imagem e enviar. Esperar terminar e conferir de novo. Fazer isso NO MÁXIMO 2 vezes. Se ainda falhar na 2ª correção, baixar a melhor versão mesmo assim e anotar no relatório qual item falhou.
6. Baixar a imagem (abrir a imagem, clicar no botão de download). Se o arquivo vier em outro formato (webp/jpg), tudo bem: o processamento converte, mas salve com o nome indicado e a extensão original se não conseguir PNG.
7. Mover/renomear o arquivo baixado para `D:\programacao\projetos\jogos\roblox\uma cidade silenciosa\assets\filtro\bruto\<nome>.png` (nome conforme o título da seção: `neblina_mecha_a`, `neblina_mecha_b`, `neblina_puff`, `cone_luz`, `faixa_tracking`, `poeira_lente`).
8. Confirmar que o arquivo existe nessa pasta antes de passar para a próxima imagem.

Regras:
- Não pedir pixels exatos; proporção certa basta. O redimensionamento é feito depois.
- Não alterar o texto dos prompts.
- Se o ChatGPT recusar ou pedir login, parar e relatar.

Relatório final: lista das 6 imagens com "ok" ou "ok com ressalva (item X falhou)" e o caminho de cada arquivo.
