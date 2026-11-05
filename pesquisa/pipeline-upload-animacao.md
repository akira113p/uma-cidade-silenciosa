# Pipeline de upload (Open Cloud) de modelos e animações

Levantado em 2026-11-05 por leitura do repositório. Nada foi executado: sem Blender, sem envio à Open Cloud.
O arquivo `.env` não foi lido. Os nomes das variáveis vêm do código. Referências `arquivo:linha` são de linhas reais (1-based).

---

## A. Modelo (FBX) e textura -> Config

### Variáveis de ambiente (só os nomes)
- `ROBLOX_OPEN_CLOUD_KEY`: chave com permissão de asset. Vai no header `x-api-key` (`ferramentas/modelos/enviar_veiculos.py:84, 93`; lida em `:133`).
- `ROBLOX_CREATOR_ID`: id do dono do asset. Vai em `creationContext.creator.userId` (`enviar_veiculos.py:80`; lida em `:134`).
- Origem: ambiente, ou arquivo `.env` na raiz via `carregar_env()` (`enviar_veiculos.py:117-127`). Variável de ambiente tem prioridade (`setdefault`). `.env` está no `.gitignore`, linha 6.
- Sem as duas e sem `--dry-run`, o script sai com erro (`enviar_veiculos.py:135-136`).

### Endpoints
- `POST https://apis.roblox.com/assets/v1/assets`, `multipart/form-data` (`enviar_veiculos.py:74-86`, POST em `:83`):
  - campo `request` (JSON): `assetType`, `displayName` = `"Cidade " + nome` (máx. 50), `description`, `creationContext.creator.userId`;
  - campo `fileContent` (arquivo com Content-Type).
- Resposta: `{"path": "operations/<id>"}`. Consulta: `GET https://apis.roblox.com/assets/v1/operations/<id>` (`:90-94`), até `done: true`; daí `response.assetId` (`:95-99`).
- Espera: intervalo 2 s e máximo 180 s por operação (`:43-44`). Timeout de cada chamada: 120 s (`:68`).
- Doc citada no código: https://create.roblox.com/docs/cloud/guides/usage-assets (conferida em 2026-11-03, `:10`). Limite: 20 MB por arquivo; Decal menor que 8000x8000 (`:15`).
- Tipos aceitos (`:35-42`): `.fbx` -> `Model` (`model/fbx`); `.png/.jpg/.jpeg/.tga/.bmp` -> `Decal`.

### Comandos (da raiz do projeto)
```
python ferramentas/modelos/montar_manifesto.py
python ferramentas/modelos/enviar_veiculos.py --dry-run
python ferramentas/modelos/enviar_veiculos.py
python ferramentas/modelos/gerar_config.py
```
Monstros: `python ferramentas/modelos/enviar_monstros.py [--dry-run] [--animacoes]` e depois `python ferramentas/modelos/gerar_config_monstros.py`.
(Uso nos docstrings: `enviar_veiculos.py:7-8`, `enviar_monstros.py:5-6`.)

### Idempotência e enviados.json
- Pula o arquivo se o sha256 for igual e já houver `assetId` (`enviar_veiculos.py:153-156`).
- Grava `enviados.json` depois de cada envio bem-sucedido (`:166-173`).
- Formato (docstring `:18`): `{"<arquivo>": {"sha256", "assetId", "tipo", "revisionId", "moderacao"}}`.

### Textura: do assetId do Decal ao id da imagem (conversão manual)
- O script grava o id devolvido, que é do **Decal**, em `assetId` (`enviar_veiculos.py:168`).
- Não há conversão no repositório: não há `LoadAsset` em `ferramentas/`. A conversão (`InsertService:LoadAsset(decal)` -> `Decal.Texture`) está descrita em `gerar_config_monstros.py:5-6` e `docs/veiculos-modelos.md:79`, mas é feita à mão e registrada no `enviados.json`:
  - **Veículos:** `assetId` passa a ser o id da imagem e o original vai para `decalId`. Exemplo em `modelos 3d/veiculos/enviados.json`, `sedan_cor1.png`: `assetId` 82410002485143, `decalId` 139111564061520.
  - **Monstros:** o id da imagem vai para a chave `imagemId`, e `assetId` continua sendo o do Decal. Exemplo em `modelos 3d/rastejador/enviados.json`, `Monster_1.png`: `assetId` 130923450655011, `decalId` 130923450655011, `imagemId` 120887041573147.
- **Armadilha:** reenviar um PNG alterado regrava a entrada sem `decalId` nem `imagemId` (`enviar_veiculos.py:166-172`; `enviar_monstros.py:63-69`).
  - Veículos: `gerar_config.py` usa `assetId` para textura (`:67-69`, `:73-75`). A textura passa a apontar para o Decal, o erro que `docs/pendencias-integracao.md:212` já prevê.
  - Monstros: `gerar_config_monstros.py:35` lê `imagemId`. Se faltar, a linha `textura` some sem aviso.

### Escala e giro de importação
- **Veículos:** `FATOR_IMPORTACAO = 1 / 0.28` multiplica só `MeshPart.Size` (`src/server/VeiculoModelo.luau:253-255`, `:306-308`). Medido: sedan 5,55 -> 19,83 studs (`docs/veiculos-modelos.md:80`). Confirmado: fator 0,28.
- **Veículos:** `VIRAR_IMPORTACAO = CFrame.Angles(0, math.pi, 0)` (`VeiculoModelo.luau:256-257`), aplicado às posições das peças (`:434`, `:436`). Doc: X e Z das peças vêm negados (`docs/veiculos-modelos.md:80`).
- **Monstros:** não há fator 0,28 nem giro no código.
  - O Roblox importa o FBX 1:1 (1 unidade = 1 stud) e ignora `global_scale`. O exportador escala vértices e ossos nos dados (`docs/rastejador.md:260-261`).
  - A troca de eixos é feita nos dados: x' = -x, y' = z, z' = y (`gerar_anim_rastejador.py:8-10`; `docs/rastejador.md:263`).
  - `server/MonstroModelo.luau:81` não gira a malha.

### Como o jogo carrega a malha
- Sempre `InsertService:LoadAsset(id)` no **servidor**, em `pcall`, uma vez por tipo, com cache em `ServerStorage`. Se falhar, `warn` e o objeto segue em blocos.
- **Veículos:** `src/server/VeiculoModelo.luau:292-318` (`baixarMolde`). `LoadAsset` na linha `:298`. Molde em `ServerStorage.Modelos.Veiculos` (`:260-274`). Textura: `m.TextureID = textura` (`:404`).
- **Monstros:** `src/server/MonstroModelo.luau:38-97` (`montar`). `LoadAsset` na linha `:40`. Molde em `ServerStorage.Modelos.MonstrosMalha` (`:22-36`). Altura da malha conferida contra o Config (`:52-60`). Textura: `malha.TextureID = cfg.textura` (`:80`). `preparar` é chamado antes de nascer monstro (`src/server/Monstros.luau:1010`).

### Arquivos Config gerados
- **`src/shared/Config/VeiculosMalhas.luau`** é gerado por `gerar_config.py` (escrita em `:136`; roda `stylua` se existir, `:137-138`). Primeiras 15 linhas (literais do arquivo):
```lua
-- Malhas dos veículos (visual; a física e os alvos continuam em blocos). Contrato: docs/veiculos-modelos.md.
-- GERADO por ferramentas/modelos/gerar_config.py (manifesto.json + enviados.json). Não editar à mão.
-- Sem `modelo` (assetId) o jogo segue em blocos.
return {
	tipos = {
		compacto = {
			escala = 1.9566,
			inteiro = {
				modelo = 81412098464236,
				texturas = {
					"rbxassetid://137766488911684",
					"rbxassetid://123071738764865",
					"rbxassetid://73157680917217",
					"rbxassetid://136091748777432",
				},
				pecas = {
```
- Estrutura: `tipos.<tipo>` tem `escala`, `inteiro` e `queimado` (cada um com `modelo`, `texturas` e `pecas = { Nome = { tamanho, centro } }`), além de `dimensoes`, `raioRoda`, `folgaRoda`, `bancoTopo`, `tetoInterno`, `olho`, `bancos` e `rodas`. Também existe `roda = {...}` (`gerar_config.py:120-135`).
- **`src/shared/Config/MonstrosMalhas.luau`** é gerado por `gerar_config_monstros.py` (`:52-53`). Arquivo inteiro (20 linhas):
```lua
-- GERADO por ferramentas/modelos/gerar_config_monstros.py. Nao editar a mao.

return {
	Rastejador = {
		modelo = 134924177372078,
		textura = "rbxassetid://120887041573147",
		dimensoes = { x = 9.7829, y = 5.816, z = 10.5841 }, -- studs, no repouso (largura, altura, comprimento)
		corpo = { x = 2.6622, y = 2.9036, z = 5.3217 }, -- caixa de colisao (cabeca + tronco)
		corpoCentro = { x = -0.3275, y = 1.0885, z = 0.6884 }, -- relativo ao centro do MeshPart
		fundoDoCorpo = 2.5447, -- studs do chao ate o fundo do corpo (HipHeight)
		animacoes = {
			Idle = "rbxassetid://75498104488794",
			Walk = "rbxassetid://72375333938634",
			Run = "rbxassetid://134318397938323",
			Attack = "rbxassetid://95860538607052",
			Death = "rbxassetid://118340794455812",
		},
		duracao = { Idle = 2.5, Walk = 1.3333, Run = 0.6667, Attack = 1.4583, Death = 1.9583 }, -- s
	},
}
```
- `montar_manifesto.py` junta os `manifesto_*.json` parciais gerados por `ferramentas/modelos/veiculos_pz.py` (existe no repositório) em `modelos 3d/veiculos/manifesto.json`, e **apaga** os parciais (`montar_manifesto.py:20-23`, `:31-32`). Para rodar de novo, é preciso rodar `veiculos_pz.py` antes.

---

## B. Animação (clipes do Rastejador)

### Cadeia completa (da fonte ao Config)
1. `ferramentas/modelos/animar_rastejador_opus.py` (Blender). IK nas quatro patas, gravada quadro a quadro. Grava `modelos 3d/_ps2/Rastejador/Rastejador_anim_opus.blend` (`:21-23`). Ações: Idle 60, Walk 32, Run 16, Attack 36, Death 48 quadros (`:376-377`). Não envia nada.
2. `ferramentas/modelos/exportar_rastejador.py` (Blender headless). Lê o `.blend` (`:28`) e grava em `modelos 3d/rastejador/`: `rastejador.fbx`, `Monster_1.png`, `manifesto.json` e `anim_blender.json` (docstring `:1-16`; `:159`). Cíclicas: Idle, Walk, Run (`:100`). Altura: `--altura` com padrão 2.908 (`:53`). A versão 2x usa `--altura 5.816` (`docs/rastejador.md:293`).
3. `ferramentas/modelos/gerar_anim_rastejador.py`. `anim_blender.json` -> `anim_roblox.json` (`Bone.Transform` por osso; máximo 30 keyframes por ação, `:23`). Precisa de `rest_roblox_bruto.txt`, medido no Studio depois de importar o FBX (`:4-6`).
4. `lune run ferramentas/modelos/montar_anim_rbxm.luau [aninhado|plano]` -> `modelos 3d/rastejador/anim/Rastejador_<Acao>.rbxm`.
5. `python ferramentas/modelos/enviar_monstros.py --animacoes` -> Open Cloud, e grava `enviados.json`.
6. `python ferramentas/modelos/gerar_config_monstros.py` -> `src/shared/Config/MonstrosMalhas.luau`.

### Como o KeyframeSequence / rbxm é montado
- Lune: `require("@lune/roblox")`, `@lune/fs` e `@lune/serde` (`montar_anim_rbxm.luau:4-6`). Lune 0.10.5 está fixado em `rokit.toml:6`.
- Roda da raiz: o caminho `"modelos 3d/rastejador"` é relativo (`:8`).
- Por ação: `Instance.new("KeyframeSequence")`, `Name = "Rastejador_<Acao>"`, `Loop = ciclica`, `Priority` = `Action` para Attack e Death e `Core` para o resto (`:18-22`).
- Por tempo: `Keyframe` com `Time = tempos[i]` (`:23-26`). Por osso: `Pose` com `CFrame(x,y,z,qx,qy,qz,qw)`, `Weight = 1`, `EasingStyle = Linear` (`:27-35`).
- Modo `aninhado` (padrão, `:9`): cada Pose fica dentro da Pose do pai, pela hierarquia do rig, com pais antes de filhos (`:37-40`). Modo `plano` põe todas as Poses direto no Keyframe. `docs/rastejador.md:252` diz que o aninhado é o que funciona.
- `roblox.serializeModel({ks}, false)` gera os bytes, que vão para `fs.writeFile` (`:43-44`).

### Envio
- `enviar_monstros.py`: `TIPOS[".rbxm"] = ("Animation", "model/x-rbxm")` (`:19`). Clipes só entram com `--animacoes` (`:23-30`, `:43`). Reusa `enviar_veiculos.enviar`, com os mesmos endpoints e polling da seção A.
- **Id volta:** `response.assetId`, gravado em `enviados.json` com a chave `anim/Rastejador_<Acao>.rbxm` e `tipo: "Animation"` (`enviar_monstros.py:63-69`). Ids atuais (`modelos 3d/rastejador/enviados.json`; confirmados em `docs/rastejador.md:294`): Idle 75498104488794, Walk 72375333938634, Run 134318397938323, Attack 95860538607052, Death 118340794455812.
- **Custo:** o código não trata custo. `docs/rastejador.md:18-20` diz que a documentação não cita custo e que, se pedisse Robux, a Fase 0 pararia. `docs/rastejador.md:251` registra que passou sem pedido de Robux, com `moderationState: Approved`.
- `pesquisa/limites-assets-roblox.md:17, 58-61` traz "pacote de animação: 80 Robux por pacote, 1 por dia". É outro produto (pacote, rig R15 padrão, clipes até 10 s, trecho de busca). Custo de animação avulsa: não consta na pesquisa (`:74`).

### Onde fica guardado
- `modelos 3d/rastejador/anim/*.rbxm` (bytes locais, 5 arquivos).
- `modelos 3d/rastejador/enviados.json` (ids e sha256).
- `src/shared/Config/MonstrosMalhas.luau`: tabela `animacoes` (linhas 11-17) e `duracao` (linha 18, `(quadros-1)/fps`, `gerar_config_monstros.py:50`). No Config, a chave é `Rastejador.animacoes`. O contrato em `docs/rastejador.md:80` cita `Config/MonstrosMalhas.animacoes`, que bate com isso.
- Uso no jogo: `src/server/MonstroModelo.luau:129-150` cria `Animation` com o `AnimationId` e chama `Animator:LoadAnimation` (`:141`). O `Animator` fica dentro do Humanoid (`:91`). A escolha da ação está em `src/server/Monstros.luau:568`.

### O que deu errado / está aberto
- `docs/rastejador.md:286-287` lista ids da versão 1x (FBX 91445481804236, Walk 140643199639650 etc.). Não batem com `enviados.json` nem com `MonstrosMalhas.luau` (versão 2x). Fonte válida: `enviados.json`.
- `exportar_rastejador.py:53` tem `--altura` padrão 2.908, que é o 1x. Rodar sem `--altura 5.816` volta ao 1x e diverge de `MonstrosMalhas.dimensoes` (y = 5.816).
- `rest_roblox_bruto.txt` é medição manual no Studio (`gerar_anim_rastejador.py:4-6`). Um FBX novo exige nova medição (inferência a partir do mesmo docstring).
- Textura do monstro: `imagemId` é editado à mão. `gerar_config_monstros.py:35` omite `textura` sem aviso se faltar (ver seção A).
- Patinação: Walk precisa de 3,8x e `velMax` é 2,5, então patina cerca de 34% (`docs/rastejador.md:293`). Run dá 1,61x, ok. Decisão pendente (`docs/pendencias-integracao.md`, seção "Rastejador").
- Sem marcador "Impacto" no clipe. O golpe usa tempo fixo `golpe.atrasoImpacto = 0,75 s` (`docs/rastejador.md:255`).
- Death não foi visto com a IA real (`docs/rastejador.md:273`).
- Custo do Animator no servidor com dezenas de monstros: não medido (`docs/rastejador.md:284`).
- Attack: 36 quadros no script (`animar_rastejador_opus.py:377`; `duracao` 1,4583 s em `MonstrosMalhas`) contra 35 na doc (`docs/rastejador.md:255`). Diferença pequena.
- Um envio de teste com conteúdo inválido falhou e não gerou asset (`docs/rastejador.md:287`).

---

## C. Personagem (Aparência, câmera, braços)

- **R15:** exigido em runtime. `src/server/Aparencia.luau:316-323` avisa e não aplica se for R6 ("o visual só funciona em R15 (Game Settings > Avatar > R15)"). O tipo de avatar vem de Game Settings no Studio; não consta no `default.project.json`.
- **Animate (script padrão):** não consta no repositório. `default.project.json:27-34` declara só `Sound` em `StarterCharacterScripts` (vazio de propósito, substitui `RbxCharacterSounds`). Se o place tiver `Animate`, vem do Studio. Não verificado.
- **Primeira pessoa:** `CameraMode = LockFirstPerson` em `default.project.json:17`. A tecla V alterna para `Classic` (`src/client/Camera.luau:93-103`). A cabine só monta com `LockFirstPerson` (`src/client/Cabine.luau:300-306`).
- **Braços na primeira pessoa:** pelo código, os braços aparecem. Só a cabeça é escondida:
  - `src/client/Aparencia.luau:14-23` põe `LocalTransparencyModifier = 1` e desliga os SurfaceGui nas partes com a tag `AparenciaCabeca` (`src/shared/Config/Aparencia.luau:89`), quando a câmera está a menos de 1,6 studs da Head (`Config/Aparencia.luau:90`; `client/Aparencia.luau:32-38`).
  - `src/server/Aparencia.luau:280` põe `Transparency = 1` nas peças R15 originais, para todo jogador. Cada peça ganha um bloco colorido soldado (`:244-281`), sem tag. Esses blocos (braços e mãos incluídos) não são escondidos pelo cliente. Cores: `Config/Aparencia.luau:57-62`.
  - Não verificado no Studio nesta leitura.
- **Regras que escondem partes do corpo:**
  1. Cabeça na primeira pessoa (`client/Aparencia.luau`, acima).
  2. Dentro de veículo na primeira pessoa: `src/client/Cabine.luau:135-148` põe `LocalTransparencyModifier = 1` em **todas** as BasePart do personagem e no volante. Reaplica a cada quadro (`:322-333`) e restaura ao sair (`:122-133`). A cabine desenha braços próprios em blocos (`Cabine.luau:197`, `Vector3.new(0.3, 0.3, 0.5)`).
  3. Volante do modelo some só para o motorista (`Cabine.luau:146`, `:331`; `docs/veiculos-modelos.md`).
  4. Peças R15 originais com `Transparency = 1` para todo jogador (`server/Aparencia.luau:280`). O visual é o bloco.
- **Altura:** 5,234 studs (bounding box do R15 escalado, com cabelo), medido no Studio (`src/shared/Config/Rastejador.luau:6`; `docs/rastejador.md:266`). `docs/mapa-v2.md:82` diz "R15 ≈ 5". A referência de 1,8 m é premissa do monstro (`docs/rastejador.md:14, 203`), não do personagem.
- **Escalas do corpo** (`src/shared/Config/Aparencia.luau:10-12`): `BodyHeightScale 1.05`, `BodyWidthScale 0.68`, `BodyDepthScale 0.78`. Cabeça: largura = tronco x 1,14 (`Config/Aparencia.luau:41`).
- **Tamanho dos braços em studs:** não consta. Os blocos copiam `original.Size` da peça R15 (`server/Aparencia.luau:262-263`). O tamanho vem do motor, não do repositório.

---

## D. Rede e atributos

### Eventos de `src/shared/Rede.luau` (`EVENTOS`, linhas 9-35): 23 no total
Cliente -> servidor (15):
- `Agachar` (boolean, `:11`), `Correr` (boolean, `:12`), `SalvarPreferencias` (`:13`), `Voz` (number, `:14`).
- `Equipar` (slot?, `:15`), `Atacar` (origem, direção, `:16`), `UsarItem` (`:17`), `LargarItem` (`:18`).
- `AbrirCaixa` (`:19`), `PegarItem` (`:20`), `Lanterna` (ligada: boolean, `:21`).
- `LigarMotor` (`:22`), `Buzina` (`:23`), `SairCarro` (`:24`, dupla: cliente pede e servidor devolve o CFrame), `Admin` (`:25`).

Servidor -> cliente (8):
- `MeuRuido` (`:27`), `RuidoDebug` (`:28`), `Dano` (`:29`), `Inventario` (`:30`).
- `ConteudoCaixa` (`:31`), `Acerto` (`:32`), `Aviso` (`:33`), `Morreu` (`:34`).

### Como adicionar um evento
1. Incluir o nome em `EVENTOS` (`src/shared/Rede.luau:9-35`), com o comentário dos argumentos.
2. `Rede.evento(nome)` dá `assert` se o nome não estiver na lista (`Rede.luau:53-54`).
3. O servidor cria todos no início com `Rede.criarTodos()` (`Rede.luau:70-75`), chamado em `src/server/init.server.luau:7`.
4. No servidor, validar e limitar frequência com `server/Limite.luau` (`docs/arquitetura.md:140`).
5. Registrar na tabela da seção 4 de `docs/arquitetura.md` (linhas 125-138).
- Regra: nenhum outro arquivo cria `RemoteEvent` (`Rede.luau:2`).
- **Discrepância:** a tabela da seção 4 de `docs/arquitetura.md` não lista `Lanterna`, `LigarMotor`, `Buzina`, `SairCarro` nem `Admin`.

### Atributos do Player que envolvem arma / uso (`docs/arquitetura.md:90-103` e código)
- `Usando` (bool). Dono: Inventario (`arquitetura.md:94`). Escrito em `server/Inventario.luau:112, 342, 362, 370, 406, 426`. Bloqueia ataque (Armas).
- `ArmaEquipada` (string?, id de `Config/Armas`). Dono: Armas (`arquitetura.md:102`). Escrito em `server/Armas.luau:116, 179`.
- **`ArmaSlot`**: **não consta na tabela** de `arquitetura.md`. Escrito em `server/Armas.luau:117, 180`.
- `BracoZerado` (bool). Dono: Vida (`arquitetura.md:99`). Escrito em `server/Vida.luau:62` (`Corpo.bracoZerado`).
- `Vida_Cabeca`, `Vida_Torso`, `Vida_BracoE`, `Vida_BracoD`, `Vida_PernaE`, `Vida_PernaD` (number). Dono: Vida (`arquitetura.md:96`). Escritos em `server/Vida.luau:58`.
- `Morto` (bool). Dono: Vida (`arquitetura.md:100`). Escrito em `server/Vida.luau:69, 86`.
- `MultVelocidade` e `PodeCorrer` (Vida, `arquitetura.md:97-98`): afetam movimento, não arma.

---

## E. Testes e checagens

### Rodar tudo (da raiz)
`pwsh scripts/checar.ps1`. Passos, nesta ordem (`scripts/checar.ps1`):
1. `rojo build build.project.json -o build/place.rbxl` (`:10`).
2. "projetos iguais": `default.project.json` deve ser igual a `build.project.json` sem `Workspace.Mapa` (`:11-18`).
3. Testes: `lune run tests/<X>.spec.luau` para cada `tests/*.spec.luau`, parando no primeiro erro (`:19-25`).
4. `selene src` (`:26`).
5. `stylua --check src tests` (`:27`).
- Sai com código 1 se algum passo falhar (`:29-33`).

### Um teste isolado
`lune run tests/Armas.spec.luau` (da raiz). Imprime `Armas.spec ok` no fim (`tests/Armas.spec.luau:77`) e falha em qualquer `assert`.

### Ferramentas e configs
- Versões fixadas em `rokit.toml:3-6`: rojo 7.7.1, selene 0.31.0, stylua 2.5.2, lune 0.10.5. O comentário em `rokit.toml:1` manda usar `rokit install`.
- `selene.toml` na raiz: `std = "roblox"`.
- `stylua.toml` na raiz: `column_width = 120`, `line_endings = "Unix"`, `indent_type = "Tabs"`, `indent_width = 4`, `quote_style = "AutoPreferDouble"`, `call_parentheses = "Always"`.
- Selene só analisa `src` (`checar.ps1:26`). Stylua verifica `src` e `tests` (`:27`).
- Número de suítes: há 18 arquivos `tests/*.spec.luau`. O `CLAUDE.md` diz "9 suítes Lune", que era o estado de 2026-11-01.
- Não há teste automatizado para os scripts de upload (`enviar_*.py`, `gerar_config*.py`, `montar_anim_rbxm.luau`). Só o `--dry-run`.

### tests/Armas.spec.luau
Não há funções de teste com nome. São 7 blocos separados por comentário, cada um com `assert` (a mensagem é o "nome" do caso):
1. **Cadência** (`:6-12`): "primeiro ataque sempre pode", "exatamente na cadência pode", "antes da cadência não pode", "relógio voltando não pode", "NaN não pode", "agora NaN não pode".
2. **Origem contra a cabeça** (`:14-23`): "origem na cabeça", "origem a 5 studs", "origem forjada a 20 studs", "origem NaN", "origem inf".
3. **Direção** (`:25-32`): "magnitude 1.2 aceita" (com normalização para `z = -1`), "magnitude 0.4 rejeitada", "magnitude 2 rejeitada", "NaN rejeitado", "zero rejeitado".
4. **Espalhamento** (`:34-55`): "graus 0 mantém a direção"; 500 direções aleatórias com "unitário" e "dentro do cone"; "cone na vertical"; "desvio máximo ≈ cone".
5. **Dano** (`:57-62`): "pistola no torso" (25), "pistola na cabeça ×2" (50), "faca no braço" (18), "machado na cabeça" (80).
6. **Espalhamento com braço zerado** (`:64-66`): "braço ok" (1), "braço zerado ×2" (2).
7. **Configuração coerente** (`:68-75`): para cada arma de `Config/Armas`: "tipo", "números positivos", "fogo precisa de munição e espalhamento".
- Não há teste para `server/Armas` (`Equipar`, `Atacar`) nem para o fluxo de rede.
