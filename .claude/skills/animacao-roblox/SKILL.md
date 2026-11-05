---
name: animacao-roblox
description: Animações para personagens R15/R6 do jogo Roblox escritas como dados (que junta gira quanto em que instante), construídas como KeyframeSequence e revisadas por folha de quadros antes de publicar. Use para criar ou ajustar animação de ataque, emote, ferramenta, idle ou NPC.
---

# Animação

É a disciplina mais difícil para Claude, e o próprio vídeo admite: julgar movimento por imagens estáticas é fraco, e boa parte sai "não parecendo Roblox" nas primeiras tentativas. Por isso o fluxo é **dado → construir → folha de quadros → ajuste**, aprendendo com animações de referência.

## 1. Pose como dado
`assets/animacoes/<Nome>.json`:
```json
{
  "rig": "R15", "duracao": 0.6, "loop": false, "prioridade": "Action",
  "quadros": [
    { "t": 0.0,  "juntas": { "RightShoulder": [0, 0, 0] } },
    { "t": 0.2,  "juntas": { "RightShoulder": [-120, 0, 20], "Waist": [0, 25, 0] }, "easing": "Cubic-Out" },
    { "t": 0.6,  "juntas": { "RightShoulder": [0, 0, 0], "Waist": [0, 0, 0] } }
  ]
}
```
Ângulos em graus (X, Y, Z) relativos à pose de descanso, por Motor6D do R15 (`Root`, `Waist`, `Neck`, `LeftShoulder`, `RightShoulder`, `LeftElbow`, `RightElbow`, `LeftWrist`, `RightWrist`, `LeftHip`, `RightHip`, `LeftKnee`, `RightKnee`, `LeftAnkle`, `RightAnkle`).

## 2. Construir
No Studio, via `execute_luau`: montar `KeyframeSequence` (`Keyframe` com `Time` + `Pose` por parte, `CFrame.Angles` dos graus) num rig R15 de teste em `workspace.Bancada`. Para testar sem publicar: `KeyframeSequenceProvider:RegisterKeyframeSequence` dá um id temporário para usar no playtest.

## 3. Olhar
Folha de quadros: em playtest, tocar a animação no rig e fazer `screen_capture` em 6–8 instantes, sempre com a mesma câmera, depois montar a folha (Pillow). Julgar: antecipação antes do golpe, exagero no auge, recuperação, pé que não desliza, silhueta legível de lado e de frente.

## 4. Aprender o estilo
Antes da primeira animação de verdade: pegar 3–5 animações de jogos populares do gênero (emotes/ataques públicos), extrair os quadros-chave (`KeyframeSequenceProvider:GetKeyframeSequenceAsync`) e anotar em `docs/estilo-animacao.md` os padrões (duração típica, quanto gira o tronco, quantos quadros de antecipação). As animações novas seguem esse documento.

## 5. Publicar
Salvar a KeyframeSequence e publicar pelo Animation Editor (o usuário confirma), ou pelo Open Cloud quando houver API key. O id final vai para `src/shared/Config/Animacoes.luau`.

## Armadilhas
- Skill **ainda não exercitada**. Muitas tentativas são esperadas: registrar aqui cada correção de estilo que funcionar.
- Animação de personagem precisa ser do dono do jogo (usuário ou grupo) para tocar em jogo publicado.
- Sessões paralelas do mesmo projeto: em 2026-10-12 duas sessões receberam o mesmo pedido (esquema de andar) e uma sobrescreveu o `server/Rig.luau` da outra. Antes de escrever em `src/`, rodar `ListAgents` e olhar arquivos novos (`find src -newermt ...`); um `Write` que diz "updated" num arquivo que você não conhecia é o sinal de colisão.
- Esquema de andar do projeto: `Config/Animacao` (planos como dado) + `Regras/Marcha` (conta pura, testada) + `client/Animador` (aplica no Transform dos Motor6D) + `server/Rig` (liga as peças). Peça com o nome da junta e a origem NA junta (no Blender, `ob.location` = junta). Plano novo = entrada em `Animacao.planos` com a junta `Corpo`.
