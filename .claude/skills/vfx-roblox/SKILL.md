---
name: vfx-roblox
description: Efeitos visuais do jogo Roblox (explosão, golpe, magia, coleta, brilho, rastro) montados a partir de uma biblioteca de blocos colhida de packs gratuitos, e conferidos por congelamento de fase (início/meio/fim) com screen_capture. Use para criar, ajustar ou revisar qualquer efeito de partícula, Beam ou Trail.
---

# VFX

ParticleEmitter tem muitos parâmetros e é difícil simular fora do Roblox. Por isso, em vez de **gerar** efeito do zero, o fluxo **colhe** efeitos prontos, classifica e combina os blocos. Exemplo: bola de fogo = esfera brilhante + chama + faíscas + rastro.

## 1. Colher (uma vez por pack)
1. O usuário escolhe packs gratuitos de VFX na Creator Store. Inserir com `search_asset`/`insert_asset` dentro de `workspace.Colheita`.
2. **Auditar antes de tudo**: apagar todo `Script`/`LocalScript`/`ModuleScript` que veio junto (backdoor é comum em pack gratuito).
3. `execute_luau` com [scripts/colher.luau](scripts/colher.luau): devolve JSON com cada emissor (textura, cor, vida, velocidade, etc.) e uma classe inicial (fogo, fumaca, faisca, brilho, impacto, raio, rastro, outro).
4. Claude revisa as classes, dá nome a cada bloco e grava em `assets/vfx/biblioteca.json`. Os blocos guardam IDs e parâmetros; as texturas são trabalho de terceiros, então a biblioteca não é publicada.

## 2. Montar um efeito
- Escolher 2–5 blocos da biblioteca, escrever o efeito como dado em `src/shared/Config/Efeitos.luau` (blocos + ajustes: cor, escala, quantidade, atraso de cada um), e um construtor no client que monta Attachments + emissores a partir desse dado.
- Efeito de rajada = `Enabled = false` + `:Emit(n)`. Efeito contínuo = `Rate`.
- Todo efeito tem duração máxima e é destruído (`Debris`/`task.delay`): efeito que não morre vira vazamento de memória.

## 3. Conferir (congelamento de fase)
Bancada: `workspace.Bancada` com fundo neutro e câmera fixa.
1. `execute_luau` com [scripts/congelar_fase.luau](scripts/congelar_fase.luau) (`TEMPO` = início ~0,05 s).
2. `screen_capture`.
3. Repetir para o meio e o fim (≈ 50% e 90% do `Lifetime` máximo).
4. Soltar (`MODO = "soltar"`).
Julgar as três imagens juntas: o efeito é coerente do começo ao fim? Lê bem em tamanho de celular? Cor combina com o tema? Escala certa ao lado de um personagem R15?

## Armadilhas
- `colher.luau` e `congelar_fase.luau` **ainda não rodaram no Studio**. Pontos a confirmar na primeira vez: se `task.wait` funciona dentro do `execute_luau`, se partículas emitidas em modo Edit aparecem no `screen_capture`, e se `TimeScale = 0` segura o quadro entre chamadas.
