---
name: teste-no-void
description: Como testar o jogo Uma Cidade Silenciosa no place oficial sem sujar o mapa nem criar outro place - zona de teste Workspace.ZonaTeste no meio do void (6000, 300, 6000), em Play, com plataforma âncora, paredes, limpeza e checagem pós-teste. Use antes de qualquer teste de jogo (monstro, carro, arma, ruído, destruição, item) no Studio.
---

# Teste no void (place oficial)

Regra do usuário (2026-11-05): **todo teste é feito DENTRO do place oficial, longe do mapa, no meio do void.** Nada de `.rbxl` de teste, nada de outro place, nada dentro de `Workspace.Mapa`. Id do place oficial e demais regras: `CLAUDE.md` > "Regras de versão". Conferir `game.PlaceId` antes de escrever.

## Regras
1. **Play, sempre que possível.** Em Play tudo o que o teste cria (no datamodel Server) some ao parar: nada persiste no place. Só ir ao Edit se o teste for inevitavelmente de Edit (ex.: ler propriedade); aí valem as regras do fim.
2. **Zona** = quadrado de 300 x 300 studs em torno de **(6000, 300, 6000)**. O mapa ocupa X/Z de -2008 a 2009 e Y de -50 a 250 (bbox medido; `Config/Mundo.tamanho = 4000`, relevo até ~20 acima do chão). A zona está a mais de 3800 studs de qualquer peça do mapa.
3. Tudo do teste fica sob `Workspace.ZonaTeste` (Folder). A **plataforma âncora** (`Ancora`, Anchored, 4 studs de espessura, topo em Y = 302) é o chão; quatro **paredes invisíveis** (`CanCollide`, 80 de altura) impedem monstros e carros de cair.
4. `Workspace.FallenPartsDestroyHeight` (padrão -500) **não pode alcançar a zona**: tem de ser menor que `300 - 100`. O trecho abaixo para tudo se não for.
5. Monstros, carros e ruído **não saem da zona**: ver "Limites do código" (nada precisa de ajuste). Spawne sempre perto do centro e não use menu de admin com `Invocar` fora da zona.
6. Ao terminar: apagar `Workspace.ZonaTeste` (leva junto `Construcoes` e `Props`), conferir que sumiu (trecho de checagem) e, se houve Edit, que `Workspace.Mapa` não mudou.
7. Teste de **Edit inevitável**: limpar antes de terminar, nunca criar nada em `Workspace.Mapa`, e **não salvar** (nenhuma IA salva/publica sem o usuário pedir).
8. Um Studio só, uma sessão só (`list_roblox_studios`). Studio do usuário com Play ativo: não mexer.

## Criar a zona e levar o jogador (datamodel Server, em Play)
```lua
local CENTRO = Vector3.new(6000, 300, 6000)
local LADO, ESPESSURA, ALTURA_MURO = 300, 4, 80

print("PlaceId:", game.PlaceId) -- comparar com o id de CLAUDE.md > Regras de versão; diferente = parar
assert(workspace.FallenPartsDestroyHeight < CENTRO.Y - 100, "FallenPartsDestroyHeight alcança a zona")
assert(not workspace:FindFirstChild("ZonaTeste"), "ZonaTeste já existe: apagar primeiro")

local zona = Instance.new("Folder")
zona.Name = "ZonaTeste"

local function peca(nome, tamanho, pos, visivel)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = tamanho
	p.Position = pos
	p.Transparency = if visivel then 0 else 1
	p.Material = Enum.Material.Concrete
	p.Color = Color3.fromRGB(90, 90, 95)
	p.CanQuery = visivel -- parede invisível não pega raio de tiro/ruído, mas ainda colide
	p.Parent = zona
	return p
end

peca("Ancora", Vector3.new(LADO, ESPESSURA, LADO), CENTRO, true) -- topo em CENTRO.Y + 2
local meio = LADO / 2
for _, lado in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	local largo = if lado[1] ~= 0 then Vector3.new(2, ALTURA_MURO, LADO) else Vector3.new(LADO, ALTURA_MURO, 2)
	peca("Muro", largo, CENTRO + Vector3.new(lado[1] * meio, ALTURA_MURO / 2, lado[2] * meio), false)
end
zona.Parent = workspace

-- Jogador: esperar o personagem E 1 s (o Spawn.luau recoloca quem nasce longe do pad nos primeiros 0,25 s)
local jogador = game:GetService("Players"):GetPlayers()[1]
local personagem = jogador.Character or jogador.CharacterAdded:Wait()
task.wait(1)
local destino = CENTRO + Vector3.new(0, 6, 0)
pcall(function()
	jogador:RequestStreamAroundAsync(destino) -- StreamingEnabled: carrega a zona antes do salto
end)
personagem:PivotTo(CFrame.new(destino))
```
Depois: `ServerStorage.Teste:Invoke("monstro", nil, "<id>")`, `Invoke("carro")` etc. nascem **na frente do jogador**, ou seja, dentro da zona. Morreu na zona: o `Spawn.luau` renasce o jogador numa vila do mapa; repetir o teleporte (com a espera de 1 s) e verificar que a plataforma ainda existe.

## Limpar
```lua
local z = workspace:FindFirstChild("ZonaTeste")
if z then
	z:Destroy()
end
-- em Play, monstros/carros invocados vivem em Workspace.Monstros e nos modelos de carro: somem ao parar o Play.
-- No Edit não existem (os scripts do jogo não rodam).
```

## Checagem pós-teste (datamodel Edit, Play parado)
```lua
local problemas = {}
if workspace:FindFirstChild("ZonaTeste") then
	table.insert(problemas, "Workspace.ZonaTeste ainda existe")
end
-- nada solto na região da zona (caixa de 2000 studs em volta do centro, vazia no place oficial)
local sobras = workspace:GetPartBoundsInBox(CFrame.new(6000, 300, 6000), Vector3.new(2000, 2000, 2000))
if #sobras > 0 then
	table.insert(problemas, #sobras .. " peça(s) na região da zona, ex.: " .. sobras[1]:GetFullName())
end
-- Mapa intocado: nenhum filho com nome de teste, e as pastas esperadas continuam lá
local mapa = workspace:FindFirstChild("Mapa")
if not mapa then
	table.insert(problemas, "Workspace.Mapa não existe")
else
	for _, nome in { "Construcoes", "Props", "Pontos", "Chao" } do
		if not mapa:FindFirstChild(nome) then
			table.insert(problemas, "Mapa." .. nome .. " sumiu")
		end
	end
	for _, filho in mapa:GetChildren() do
		if filho.Name:lower():find("teste") then
			table.insert(problemas, "Mapa contém " .. filho.Name)
		end
	end
end
return if #problemas == 0 then "ok: place limpo" else problemas
```
Se der problema, apagar o resíduo (nunca peça do mapa) e rodar a checagem de novo. Resultado `ok` é o que se relata ao usuário.

## Limites do código (conferidos em 2026-11-05, nenhum quebra a zona)
- **`Config/Mundo`** (tamanho 4000, muro de borda) só é lido pelo gerador e pelo checker; o jogo em execução **não** o usa. Sem limite de coordenada no código do jogo.
- **Spawn** (`server/Spawn.luau`): nascimentos só em pads de `Mapa.Pontos`; a rede de segurança recoloca o personagem **só nos primeiros 0,25 s** depois do `CharacterAdded`. Por isso o teleporte espera 1 s. Cada morte volta ao mapa.
- **Despawn por sair do mapa:** não existe. A única destruição por altura é a do motor (`FallenPartsDestroyHeight`, não mexido pelo projeto; padrão -500). A queda de altura machuca pelo `Vida.luau` (dano de aterrissagem), não mata por coordenada.
- **Monstros** (`server/Monstros.luau`): nascem de `Mapa.Pontos` (longe da zona, não interferem); invocados (`Invocar`, `Teste monstro`) nascem com raycast de chão na frente do jogador e **sem ponto de origem**. Caçam o som mais forte até `Config/Som.tetoAlcance` = **600 studs**; o mapa está a mais de 3800: nenhum monstro do mapa ouve a zona e nenhum da zona ouve o mapa. Não há área válida de monstro no código; o navmesh vem da plataforma (as paredes invisíveis seguram quem perseguir além da borda).
- **Raízes de construção (2026-11-05):** `Shared/Raizes.obter("Construcoes" | "Props")` devolve `Workspace.Mapa.<nome>` e, se existir, `Workspace.ZonaTeste.<nome>`, relida a cada chamada (sem cache: a pasta pode surgir ou sumir no jogo). É o que `Destruicao.classificar`, `Monstros.atualizarConstrucoes` (atenuação de ruído por parede) e `MonstroArrombar` consultam. **Para testar destruição, arrombar ou ruído com parede na zona:** crie `ZonaTeste.Construcoes` (e `ZonaTeste.Props` para props) e ponha ali as peças com os mesmos nomes e atributos do mapa (`Parede` `Anchored`, material, `CanQuery = true`; móvel/estrutura com atributo `Movel`/`Estrutura` no Model; prop = Model com atributo `Prop`). O chão `Ancora` e as paredes `Muro` ficam direto em `ZonaTeste` e continuam indestrutíveis e sem atenuar som (não estão em `Construcoes`). Sem ZonaTeste o código se comporta como antes.
- **Ruído** (`server/Ruido.luau`): propaga por distância; a atenuação por parede (raycast Include, em `Monstros.atualizarConstrucoes`) usa `Mapa.Construcoes` + `ZonaTeste.Construcoes`.
- **Destruição** (`server/Destruicao.luau`): destrói peça de `Construcoes`/`Props` do Mapa ou da ZonaTeste (ver "Raízes"); `MonstroArrombar` idem para `Construcoes`. `Veiculos`, `Loot` e `Combustivel` ainda varrem só `Mapa`.
- **Carros** (`server/Veiculos.luau`): carros do mapa só materializam com jogador a menos de 350 studs (`mapa.raioCriar`): na zona não há carro do mapa. Carro invocado nasce 16 studs à frente do jogador; o anti-trapaça de velocidade não depende de posição.
- **Armas/foguete** (`server/Foguete.luau`): o foguete destrói construção do mapa; na zona só atinge o que estiver em `Mapa.*`, ou seja, nada. Evento de explosão vai a quem estiver a menos de 700 studs.
- **StreamingEnabled** está ligado (raio alvo 512): o servidor vê tudo, o cliente só recebe a zona perto de si. `RequestStreamAroundAsync` antes do teleporte; sem isso o personagem pode cair antes de a plataforma carregar.
- **Física:** a 6000 studs a precisão de ponto flutuante ainda é boa; não passar de ~10000 (mudaria o resultado de medidas finas como velocidade/impacto).

## Armadilhas
- `execute_luau` roda em outra VM: `require` de módulo do jogo dá cópia nova (ver Armadilhas em `codigo-roblox`). Usar `ServerStorage.Teste:Invoke` e atributos.
- `PivotTo` logo no `CharacterAdded` é desfeito (motor e `Spawn.luau`): esperar o personagem no workspace e 1 s.
- Destruição, arrombar e ruído com parede cabem no void: monte a parede em `ZonaTeste.Construcoes` (peça solta direto em `ZonaTeste` NÃO conta). Teste que precise de um prédio gerado de verdade (interiores, loot, bomba de combustível) não cabe: não improvisar um place novo, falar com o usuário.
