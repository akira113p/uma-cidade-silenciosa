# Descoberta inicial (2026-11-01)

Primeira passada. A Fase 0 do plano completa esta lista com assinatura e link de cada API.

## Filtro PS1
- `Lighting.Technology` foi substituído por `LightingStyle` e `PrioritizeLightingQuality`. A doc do enum diz que, para o
  visual antigo (Compatibility, descontinuado), usar iluminação Voxel + `ColorGradingEffect` com o preset **Retro**.
  Fonte: https://create.roblox.com/docs/reference/engine/enums/Technology
- `ResampleMode = Pixelated` (sem suavização) existe só para imagens de UI (`ImageLabel`/`ImageButton`). Textura de
  `MeshPart` sempre tem filtro bilinear; pedidos de recurso abertos no DevForum até ago/2026, sem notícia de lançamento.
  Contorno usado pela comunidade: textura pequena ampliada sem filtro (16 px → 128 px, ou até 1024).
  Fontes: https://create.roblox.com/docs/en-us/reference/engine/enums/ResamplerMode ·
  https://devforum.roblox.com/t/texture-filtering/87698 · https://devforum.roblox.com/t/mesh-texture-pixel-art/2303754/10
- Consequência: pixelado das malhas vem do pipeline Blender; dither de tela vem de uma `ImageLabel` Pixelated em tela cheia.

## Mapa grande
- Sem tamanho máximo oficial. Doc recomenda `ModelStreamingBehavior.Improved`, `StreamingMinRadius` 64 e
  `StreamingTargetRadius` 1024. DevForum: densidade de peças pesa mais que a área.
  Fontes: https://create.roblox.com/docs/workspace/streaming · https://devforum.roblox.com/t/updates-to-streaming-enabled/2391960

## Passos por superfície
- `Humanoid.FloorMaterial` informa o material do chão; ouvir com `GetPropertyChangedSignal("FloorMaterial")`.
  O Roblox não traz som por material: cada superfície precisa do próprio som.
  Fontes: https://devforum.roblox.com/t/2570529 · https://devforum.roblox.com/t/2221267

## A conferir na Fase 0
- Nome exato dos presets e propriedades de `ColorGradingEffect`; valores de `LightingStyle`.
- `AudioEmitter`/`AudioListener` (API de áudio nova) vs `Sound` com `RollOffMaxDistance` para passos 3D.
- `AudioDeviceInput` + `AudioAnalyzer` (voz do jogador como fonte de ruído), se a pendente da voz for aprovada.
