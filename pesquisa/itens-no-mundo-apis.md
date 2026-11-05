# Itens no mundo: APIs conferidas (2026-11-05)

Fonte: documentação oficial em create.roblox.com/docs. Quando a página de classe trazia só assinaturas, li a versão `.md` que ela indica ("For Agents"). "Não confirmado" quer dizer que a doc lida não diz; não é recomendação. `pesquisa/` não tinha material destes temas (só streaming em `00-descoberta.md` e assets em `limites-assets-roblox.md`).

## 1. Física e network ownership
Resposta: o sono automático já para a simulação; Anchored=true é alternativa manual; SetNetworkOwner(nil) evita manipulação pelo cliente, com aviso de jitter. Confirmado.
- Confirmado: assembly sem movimento nem aceleração deixa de ser simulada. Limiares: 0,33 studs/s (linear) e 0,42 (rotacional). Acorda ao colidir com assembly acima de 1 stud/s, ao mudar propriedade física ou com ApplyImpulse. ([Sleep system](https://create.roblox.com/docs/physics/sleep-system))
- Confirmado: não há API para ler nem forçar o estado de sono (mesma fonte).
- Confirmado: Anchored=true torna a peça imóvel por física. Em item com várias partes, ancore só a raiz; ancorar todas cria mais assemblies. ([Assemblies](https://create.roblox.com/docs/physics/assemblies))
- Não confirmado: custo de 200-400 peças soltas. Nenhuma página dá número.
- Confirmado: por padrão o servidor concede ownership de partes soltas a clientes com personagem perto. ([Segurança](https://create.roblox.com/docs/scripting/security/network-ownership))
- Confirmado: SetNetworkOwner(nil) devolve ao servidor; a doc recomenda para objetos críticos ao gameplay e avisa que pode causar física "jittery" nos clientes. ([Network ownership](https://create.roblox.com/docs/physics/network-ownership))
- Confirmado: peça ancorada é sempre do servidor. Dono cliente pode disparar Touched e alterar movimento (mesma fonte de segurança).
- Existe SetNetworkOwnershipAuto(), só com assinatura, sem descrição na referência de BasePart.

## 2. Item na mão (primeira pessoa e outros jogadores)
Resposta: para Model próprio, WeldConstraint com a peça posicionada antes de habilitar o weld. Para o padrão do Roblox, Tool. Motor6D não serve para item fixo.
- Confirmado: Tool usa uma BasePart chamada Handle, presa à RightHand (R15) ou Right Arm (R6). Empunhadura: `Grip` (CFrame), com `GripPos` (posição) e `GripForward/Right/Up` (rotação). ([Tool](https://create.roblox.com/docs/reference/engine/classes/Tool.md))
- Confirmado: com várias partes chamadas Handle, o engine escolhe uma ao acaso. As outras partes entram presas ao Handle com WeldConstraint. ([In-game tools](https://create.roblox.com/docs/players/tools))
- Não confirmado: se o weld do Handle é automático e se a Tool replica para outros jogadores. A página não diz.
- Confirmado: WeldConstraint mantém a posição relativa que as peças têm quando são habilitadas; pode unir peças sem encostar. ([WeldConstraint](https://create.roblox.com/docs/reference/engine/classes/WeldConstraint.md))
- Confirmado: Motor6D é junta animável (C0/C1, Transform); a página diz que AnimationConstraint o substitui em rigs de personagem. ([Motor6D](https://create.roblox.com/docs/reference/engine/classes/Motor6D.md))
- Confirmado: Massless faz a peça não contar na massa da assembly enquanto estiver soldada a parte com massa. ([BasePart](https://create.roblox.com/docs/reference/engine/classes/BasePart.md))
- Confirmado: CanQuery só tem efeito com CanCollide desligado; nesse caso, Raycast e GetPartBoundsInBox ignoram peças com CanQuery falso.
- Inferência (doc não exige): arma na mão com Massless=true, CanCollide=false, CanQuery=false e CanTouch=false, para não bloquear o próprio tiro nem gerar Touched.

## 3. ProximityPrompt
Resposta: centenas de prompts são possíveis, mas o custo não está documentado. Distância e linha de visão são controláveis; nome e tecla vêm de ObjectText e KeyboardKeyCode.
- Confirmado: o prompt aparece só dentro de MaxActivationDistance (padrão não dado na página). ([ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt.md))
- Confirmado: RequiresLineOfSight exige caminho livre da câmera ao objeto; a parte ou Model pai é excluída do teste.
- Confirmado: Exclusivity: OnePerButton (padrão), OneGlobally (um prompt só), AlwaysShow (sempre que no alcance e visível). ([enum](https://create.roblox.com/docs/reference/engine/enums/ProximityPromptExclusivity.md))
- Confirmado: ObjectText (nome, padrão vazio), ActionText (padrão "Interact"), KeyboardKeyCode (padrão E), ClickablePrompt (clique).
- Confirmado: MaxIndicatorDistance (padrão 0 = desligado) mostra indicador antes do prompt completo. ProximityPromptService.MaxIndicatorsVisible: padrão 16, faixa 0-64. Existe MaxPromptsVisible, sem padrão declarado. ([ProximityPromptService](https://create.roblox.com/docs/reference/engine/classes/ProximityPromptService.md))
- Não confirmado: custo de centenas de prompts no mapa.

## 4. Highlight e SelectionBox
Resposta: o limite é 255 Highlights, não 31. Use só nos itens perto do jogador e destrua ao sair do alcance.
- Confirmado: no máximo 255 Highlights ativos por vez no cliente; o excedente é ignorado em silêncio. ([Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight.md))
- Confirmado: Highlight desativado também ocupa vaga; a doc recomenda destruir o que não será usado.
- Confirmado: DepthMode AlwaysOnTop ou Occluded; FillTransparency padrão 0.
- Confirmado: SelectionBox desenha caixa em volta do Adornee; SurfaceTransparency padrão 1 (faces invisíveis); LineThickness em studs. Sem limite declarado. ([SelectionBox](https://create.roblox.com/docs/reference/engine/classes/SelectionBox.md))

## 5. StreamingEnabled
Resposta: sim, itens em workspace.Mapa entram no streaming. ModelStreamingMode é propriedade de Model, não atributo; para item com várias partes, Atomic é o indicado (inferência).
- Confirmado: StreamingEnabled vem ligado em places novos e scripts não o alteram. O streaming só vale para descendentes de Workspace. ([Streaming](https://create.roblox.com/docs/workspace/streaming))
- Confirmado: Part e MeshPart são streamadas mesmo fora de Model (mesma fonte).
- Confirmado: modos Atomic (descendentes entram e saem juntos), Persistent (enviado após entrar, nunca sai), PersistentPerPlayer e Nonatomic. ([enum](https://create.roblox.com/docs/reference/engine/enums/ModelStreamingMode.md))
- Conflito não resolvido: a página de streaming diz padrão Nonatomic; o enum diz Default (0), "subject to change".
- Confirmado: StreamingMinRadius recomendado 64; StreamingTargetRadius recomendado 1024.

## 6. CollisionGroups
Resposta: PhysicsService está deprecated; use Workspace:RegisterCollisionGroup e Workspace:CollisionGroupSetCollidable. Grupo Itens que colide com o mundo mas não com Personagens/Monstros é desenho recomendado (inferência).
- Confirmado: RegisterCollisionGroup, CollisionGroupSetCollidable e demais métodos do PhysicsService estão marcados Deprecated ([PhysicsService](https://create.roblox.com/docs/reference/engine/classes/PhysicsService)). WorldRoot não os marca ([WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot.md)).
- Confirmado: grupos são configurados em Workspace; Default não pode ser renomeado nem removido; toda BasePart começa nele; por padrão, todos os grupos colidem entre si. ([Collisions](https://create.roblox.com/docs/workspace/collisions))
- Confirmado: exemplo oficial usa workspace:RegisterCollisionGroup("Characters"), workspace:CollisionGroupSetCollidable("Characters", "Characters", false) e BasePart.CollisionGroup nas partes do personagem no CharacterAdded (mesma fonte).
- Inferência: criar Itens, Personagens e Monstros; CollisionGroupSetCollidable("Itens", "Personagens", false) e ("Itens", "Monstros", false); deixar Itens com Default ligado. Personagens e monstros precisam de CollisionGroup atribuído.
- Confirmado: Raycast com CollisionGroup ignora peças de grupos que não colidem com ele. ([RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams.md))

## 7. Raycast
Resposta: use ExcludeInstances (FilterType está superseded). Origem em piso+1 com raio para baixo: o teto fica acima da origem e não entra no caminho (dedução de geometria).
- Confirmado: FilterType e FilterDescendantsInstances estão superseded por ExcludeInstances e IncludeInstances. Exclusão tem prioridade sobre inclusão. ([RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams.md))
- Confirmado: RaycastFilterType.Exclude considera todas as BaseParts, exceto descendentes da lista. Blacklist e Whitelist não aparecem na página: não confirmado.
- Confirmado: Workspace:Raycast(origin, direction, params). O comprimento de direction importa, peças além dele não são testadas; máximo 15000 studs. Raycast não tem lista de ignorar própria. ([WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot.md))
- Não confirmado: comportamento quando a origem está dentro de uma peça.
- Dedução (não doc): objetos entre a origem e o chão (mesa, tapete) são atingidos antes do piso.
- Recomendado: ExcludeInstances com personagens e itens; comprimento de uns 3 studs.

## Não confirmado (resumo)
- Custo de 200-400 peças soltas e de centenas de ProximityPrompt.
- Padrão de MaxActivationDistance e de RespectCanCollide.
- Se Tool e weld replicam para outros jogadores.
- Blacklist e Whitelist do RaycastFilterType.
- Padrão real de ModelStreamingMode (conflito entre páginas).
- Como consultar ou forçar o sono de uma assembly.
