# Veículos: contrato

Contrato entre as 3 partes (V1 Regras, V2 Servidor, V3 Cliente), escritas em paralelo. Ninguém depende de ver o código
do outro: só do que está aqui. Faltou algo: não inventar, anotar em `docs/pendencias-integracao.md` e marcar
`-- INTEGRACAO:`. Vale tudo de `docs/arquitetura.md` (§1 princípios, padrão de módulo, §7 regras).
Fonte dos números: `pesquisa/veiculos-pz/numeros.md` (Project Zomboid, só referência).

## Escopo

Entra: dirigir em primeira pessoa, 6 tipos de carro, condição sorteada no mapa (inteiro, avariado, destruído, queimado),
motor quebrado, pneu ok/furado/faltando, vidro ok/quebrado/faltando, peça de carroceria faltando, batida, tiro e golpe
quebrando vidro e furando pneu, porta-malas com loot, ruído que atrai monstro, HUD.
Não entra: conserto, troca de peça, bateria, chave, ligação direta, reboque. Combustível (tanque, posto, mangueira, recipientes, passageiros) entra em 2026-11-05: ver `docs/combustivel.md`.

Nenhum código, modelo ou som do PZ/Viewpoint vai para `src/`: só números de ajuste. Código é escrito do zero.

## Arquivos e dono

| Arquivo | Parte |
|---|---|
| `src/shared/Config/Veiculos.luau`, `src/shared/Regras/Veiculo.luau`, `tests/Veiculo.spec.luau` | V1 |
| Editar `src/shared/Config/Som.luau` (ações), `src/shared/Config/Sons.luau` (sons), `Config/Compartimentos/Comercial.luau` (tabelas `portaMalas`) | V1 |
| `src/server/Veiculos.luau`, `src/server/VeiculoModelo.luau` | V2 |
| Editar `src/shared/Rede.luau`, `server/init.server.luau`, `server/Sons.luau`, `server/Loot.luau`, `server/Armas.luau`, `server/Vida.luau` (só o indicado aqui) | V2 |
| `src/client/Direcao.luau`, `src/client/Cabine.luau`, `src/client/HudVeiculo.luau` | V3 |
| Editar `client/init.client.luau`, `client/Camera.luau` (só se preciso para sentado) | V3 |

## Estado (dados puros, `Regras/Veiculo`, `--!strict`)

```lua
export type Pneu = "ok" | "furado" | "faltando"
export type Vidro = "ok" | "quebrado" | "faltando"
export type Estado = {
	tipo: string,              -- chave de Config/Veiculos.tipos
	condicao: string,          -- chave de Config/Veiculos.condicoes
	queimado: boolean,
	motor: number,             -- 0..100; 0 = quebrado
	carroceria: number,        -- 0..100
	pneus: { [string]: Pneu }, -- FE, FD, TE, TD
	vidros: { [string]: Vidro }, -- ParaBrisa, Traseiro, JanelaE, JanelaD
	faltando: { [string]: boolean }, -- Capo, PortaMalas, PortaE, PortaD, ParaChoque
	amassado: { [string]: boolean }, -- Frente, Tras, Esquerda, Direita
}
```

Funções (todas puras, não mutam a entrada, recebem `cfg` = Config/Veiculos):
```lua
Veiculo.sortear(tipo: string, rng: () -> number, cfg): Estado
Veiculo.podeDirigir(e: Estado): boolean                    -- false se queimado
Veiculo.tentarLigar(e: Estado, rng: () -> number, cfg): boolean -- motor 0 ou queimado nunca; chance sobe com motor
Veiculo.limites(e: Estado, cfg): { velMax: number, torque: number, aderencia: number, puxa: number }
-- velMax em studs/s. puxa: -1..1, o carro desvia para o lado com pneu ruim
Veiculo.dbMotor(e: Estado, fracaoVelocidade: number, cfg): number -- ocioso → máximo, + bônus por motor ruim
Veiculo.direcaoBatida(localX: number, localZ: number): string     -- Frente/Tras/Esquerda/Direita; -Z local é frente
Veiculo.bater(e: Estado, deltaV: number, lado: string, rng, cfg): (Estado, Resultado)
Veiculo.acertar(e: Estado, peca: string, dano: number, rng, cfg): (Estado, Resultado)
-- peca: "Pneu_FE" | "Vidro_ParaBrisa" | "Motor" | "Carroceria"
Veiculo.danoOcupante(deltaV: number, cfg): number
export type Resultado = { vidros: { string }, pneus: { string }, motorQuebrou: boolean, amassou: string? }
```
`bater` abaixo de `cfg.batida.limiarDeltaV` não muda nada. Quebrar é sempre um caminho só: ok → quebrado/furado.
Testes: sortear com `util.seq` determinístico; cada condição respeita o Config; motor 0 nunca liga; 1 pneu furado reduz
velMax e dá `puxa` ≠ 0; pneu faltando reduz mais que furado; batida fraca não muda nada; `acertar` em vidro quebrado não
gera resultado; a entrada nunca é mutada.

## Config/Veiculos (V1)

Tudo que é número. Velocidades em studs/s; `Config/Som.metrosPorStud` = 0.28.
- `tipos`: `sedan`, `compacto`, `suv`, `pickup`, `van`, `esportivo`. Cada um: `nome`, `modelo` (nome em
  `ServerStorage.Modelos.Veiculos`), `tamanho` (Vector3-compatível `{x,y,z}`, largura ≈ 5.6, comprimento ≈ 11, como o
  prop do mapa), `massa`, `velMax`, `torque`, `dbBase`, `assentos`, `peso` (sorteio), `cor` lista. Números proporcionais aos do PZ.
- `condicoes`: `inteiro`, `avariado`, `destruido`, `queimado`, cada uma com `peso`, faixa de `motor`, faixa de `carroceria`,
  chance de pneu furado/faltando, vidro quebrado/faltando, peça faltando. `inteiro` raro: a maioria não anda bem.
- `maxAtivos` (≈ 40), `distanciaAcordar` (≈ 250: longe disto o carro fica ancorado), `pesoSubstituir`.
- `suspensao`, `batida` (`limiarDeltaV`, escalas), `tiro` (chances), `ruido` (`intervaloMotor` ≈ 1.5 s), `teclas`
  (`ligar = {"G"}`, `buzina = {"H"}`), `queda` por pneu ruim, `camera` (posição do olho no banco).

`Config/Som.acoes` ganha: `carroLigar = 70`, `carroFalhar = 62`, `carroBatida = 88`, `buzina = 95`, `pneuEstouro = 90`.
`carro = 80`, `vidro`, `porta` já existem.
`Config/Sons` ganha (V1 acha ids reais por `search_asset` e confere com `PreloadAsync`; id inventado é proibido; sem achar,
`ids = {}`): `MotorLoop` (`loop = true`), `MotorPartida`, `MotorFalha`, `CarroBatida`, `Buzina`, `PneuEstouro`, `PortaCarro`.
`confirmado = false`.

## Modelo (V2, `VeiculoModelo`)

```lua
VeiculoModelo.criar(estado: Estado, cf: CFrame): Model
VeiculoModelo.aplicar(modelo: Model, estado: Estado): ()   -- reflete o estado; idempotente
```
Usa `ServerStorage.Modelos.Veiculos[tipo.modelo]` (Mesh da carroceria) se existir; senão monta em blocos, sempre com os
mesmos nomes. Hierarquia:
- `Chassi` (PrimaryPart, invisível, com a massa), soldadas nele as peças `Carroceria`, `Capo`, `PortaMalas`, `PortaE`,
  `PortaD`, `ParaChoque`, `Vidro_ParaBrisa`, `Vidro_Traseiro`, `Vidro_JanelaE`, `Vidro_JanelaD`, `Volante`.
- `Banco1` é `VehicleSeat` (motorista); `Banco2..n` são `Seat`.
- `Roda_FE/FD/TE/TD`: cilindros ligados por `SpringConstraint` e `HingeConstraint` (`Motor`) em tração; frente com
  `Attachment` de direção girado por `HingeConstraint` Servo (nomes: `Motor_FE...`, `Dir_FE`, `Dir_FD`, `Mola_FE...`).
Atributos no modelo (o cliente só lê): `Veiculo = true`, `Tipo`, `Queimado`, `MotorLigado`, `Motor`, `Carroceria`,
`VelMax`, `Torque`, `Aderencia`, `Puxa`, `Pneu_FE...`, `Vidro_ParaBrisa...`. Toda peça com alvo tem atributo
`PecaVeiculo` (`"Pneu_FE"`, `"Vidro_ParaBrisa"`, `"Carroceria"`, `"Capo"` → `"Motor"`).
`aplicar`: vidro quebrado = textura rachada por cor + `CanCollide=false`; faltando = invisível sem colisão. Pneu furado baixa
`Mola.FreeLength` por `cfg.queda.furado`; faltando, por `cfg.queda.faltando` e esconde a roda. Peça faltando some.
Queimado: tudo preto/ferrugem `CorrodedMetal`, sem vidro, sem rodas boas, sem bancos, ancorado.
`ModelStreamingMode = Atomic`. Pasta `workspace.Veiculos`.

## Servidor (V2, `Veiculos`, depois de `Loot` e antes de `Monstros` no init)

```lua
Veiculos.iniciar()
Veiculos.acerto(peca: BasePart, dano: number, atacante: Player?): boolean -- true se a peça é de veículo
Veiculos.estadoDe(modelo: Model): Estado?
```
- Nascimento: espera `workspace.Mapa`, acha os Models de prop `carro` e `carro_destruido` (conferir nome e pasta em
  `ferramentas/mapa/props_urbanos.luau`), sorteia até `maxAtivos`, destrói o prop e cria o carro no mesmo CFrame.
  `carro_destruido` força condição `destruido`/`queimado`. Estado em tabela do servidor, por modelo.
- Sono: sem jogador a `distanciaAcordar`, ancora o Chassi. Acorda ao chegar perto.
- Entrar: `ProximityPrompt` "Entrar" em `PortaE` e `PortaD`/Carroceria; servidor confere vivo, distância, `podeDirigir`, banco
  livre, e faz `banco:Sit(humanoid)`. Som `PortaCarro`, `Ruido.emitirAcao("porta")`. Sair: pulo do Humanoid (padrão).
- Motorista: `SetNetworkOwner` do Chassi para ele, ao sair `nil` e freio. `LigarMotor` (só motorista, `Limite`): `tentarLigar` →
  `MotorLigado`, sons, ruído `carroLigar`/`carroFalhar`.
- Laço a 10 Hz nos carros ocupados: calcula `deltaV` (velocidade do Chassi contra a amostra anterior). Acima do limiar:
  `Veiculo.bater`, `aplicar`, sons (`CarroBatida`, `Vidro`, `PneuEstouro`), ruído, `Vida.dano(ocupante, nil, ..., {tipo="batida"})`.
  Velocidade > `VelMax × 1.3` por 2 s: retoma a posse (anti-trapaça). Motor zerado desliga.
- Ruído do motor: a cada `ruido.intervaloMotor` com motor ligado, `Ruido.emitir(pos, Veiculo.dbMotor(...), "carro", motorista)`.
  **É de propósito**: carro ligado atrai monstro. Som: `Sons.loop` no Chassi, `PlaybackSpeed` pela fração da velocidade a 5 Hz.
- Buzina (`Buzina`, com `Limite`): som + `emitirAcao("buzina")`.
- Porta-malas: `Loot.registrarCompartimento(peca, "portaMalas", "Porta-malas")` se a peça não falta.
- `Teste.registrar`: `"carro"(tipo?, condicao?)` cria na frente do jogador; `"carroEstado"()` imprime o mais próximo;
  `"carroDano"(peca)` chama `acerto`.

Edições pontuais:
- `Rede`: `"LigarMotor"` e `"Buzina"` (c→s, sem argumentos).
- `Sons`: `Sons.loop(nome: string, peca: BasePart, opcoes: {db: number?}?): Sound?` (mesma montagem de `tocar`, `Looped`, sem
  Debris, não dá Play se `ids` vazio). `tocar` com `ids` vazios já avisa e devolve nil: manter, mas avisar uma vez por nome.
- `Loot`: expor `Loot.registrarCompartimento = criarCompartimento`.
- `Armas.acertar`: antes de resolver jogador/monstro, se `Veiculos.acerto(resultado.Instance, cfg.dano, atacante)` for true,
  toca `AcertoMetal` e encerra. Require preguiçoso (Veiculos inicia depois). Conferir que `ehAlvo` deixa passar peça de veículo.
- `Vida`: acrescentar `"batida"` ao tipo `FonteDano`.

## Cliente (V3)

- `Direcao`: ao sentar em `VehicleSeat` de modelo com `Veiculo`: `RenderStepped`/Heartbeat lê `seat.ThrottleFloat`,
  `seat.SteerFloat`, atributos `VelMax`, `Torque`, `Puxa`, e aplica nos `Motor_*` e `Dir_*` localmente (o motorista é dono da
  física). Só com `MotorLigado`; sem isso rodas soltas. Marcha à ré a 40%. Teclas `Config/Veiculos.teclas` por `client/Teclas`.
  Celular: botões `Ligar` e `Buzina`.
- `Cabine`: primeira pessoa dentro: olho em `Config/Veiculos.camera`, gira `Volante` pelo steer (só local), braços de bloco na cor de
  `Config/Aparencia` indo dos ombros ao volante (viewmodel local por código). Tremor por velocidade respeitando `Pref_Tremor`.
  Sem animação enviada ao Roblox: tudo procedural. Conferir como `client/Camera.luau` se comporta com Humanoid sentado.
- `HudVeiculo`: ScreenGui só no carro: km/h (studs/s × `metrosPorStud` × 3.6), motor, 4 pneus, vidros, dica de tecla.

## Verificação

`pwsh scripts/checar.ps1` verde. Studio só por quem revisar, não pelos escritores (só leitura e `search_asset`).
Stylua nos seus arquivos. Fim: resumo com arquivos, o que não foi testado e pendências.

## Armadilhas (achadas no playtest, 2026-11-03)

- `VehicleSeat` não herda de `Seat`: `IsA("Seat")` deixa o motorista de fora.
- Massa pequena sob mola rígida diverge para NaN e arremessa o carro quando ele acorda: `Suporte` e `Cubo` são pesados de propósito, e `c·dt/m` precisa ficar < 1.
- Direção: TargetAngle positivo vira à esquerda, com Attachment0 no lado fixo.
- Verificado em chão plano, sem mapa. Falta testar nascimento pelos props, sono com 40 carros, porta-malas, Cabine e HUD.


- Sem motorista o carro fica ancorado. Devolver a física ao servidor com o carro solto faz as rodas explodirem (voaram 490 studs). O sono por distância saiu; `distanciaAcordar` não é mais usado.
- Sair: o cliente é dono do personagem, então PivotTo só no servidor é desfeito. O servidor manda o ponto por `SairCarro` e o cliente aplica. Sentado, o personagem fica no grupo `VeiculoOcupante`, sem colidir com o carro, até 0,6 s depois de sair.
- Medir a largura por `Chassi.Size`, nunca por `GetExtentsSize`.


## Menu de admin: invocar carros e monstros (2026-11-04)

Tecla O, seções "Carros" e "Monstros" (`client/Admin.luau`). O cliente só pede pelo evento `Admin`; `server/Admin.luau` repassa a
`Veiculos.invocar` e `Monstros.invocar`. Nascem em fila a `Config/Admin.invocar.distancia` (32 studs) na frente do jogador, no chão.
- **Carro:** tipo (6) + preset (`Config/Admin.presetsCarro`) ou montagem peça por peça: motor (100/50/0), carroceria, queimado, 4 pneus
  (ok/furado/faltando), 4 vidros (ok/quebrado/faltando), 5 peças (presente/falta). "Invocar este carro", "Um de cada tipo" (com a
  configuração montada) e "Limpar meus carros". `Regras/Veiculo.montar` valida tudo (testado em `tests/Veiculo.spec.luau`).
- **Monstro:** uma espécie qualquer do Config (inclusive nível 2 e 3) × quantidade (1/3/5/10), "Uma de cada espécie", "Limpar meus
  monstros". Invocados não renascem.
- Tetos por admin (`maxCarros` 12, `maxMonstros` 24): passando disso o mais antigo some. Marcados com o atributo `Invocado`.
- Comando de teste `carros(preset?)` usa o mesmo caminho.

## Armadilhas: subida e degraus (2026-11-04)
- **Torque**: força por roda = `torque` do Config; com o torque do PZ x 3 a picape tinha 12% do peso (rampa do viaduto = 1:7, 8° = 14%) e travava no pé da rampa. Agora `torque = massa x 19,6` (4 rodas = 40% do peso, sobe ~22°). A aceleração continua pela rampa de velocidade da Direcao, não pelo torque.
- **Suspensão**: a mola nascia com comprimento livre = distância de montagem e comprimia ~0,5 stud sob o peso; o assoalho ficava a 0,15 do chão e um degrau de 0,6 prendia a picape. Agora `FreeLength = comprimento + peso da roda / rigidez + suspensao.alturaExtra` (atributo `CompressaoMola` do modelo; `aplicar` usa o mesmo valor ao encurtar por pneu ruim). Vão medido: 0,9–1,35 studs. Degrau de 1,0 passa (menos a van), 1,5 só o esportivo.
- **Teste na rampa/degrau**: `Veiculos.invocar(jogador, tipo, false, {})` pelo servidor; para girar o personagem use o CLIENTE (o servidor não consegue, o cliente é dono) e gire a câmera também; mover carro com PivotTo exige ancorar, zerar velocidade e esperar ~1 s.

## Carros do mapa: todos nossos (2026-11-04)
- `nascerNoMapa` troca TODO prop `carro`/`carro_destruido` (sem teto `maxAtivos` nem sorteio `pesoSubstituir`, removidos do Config). Se o tipo sorteado bate em construção/árvore, tenta os outros 5; se nenhum cabe, o prop fica (medido: 13 de 216). Prop tombado vira carro nosso DEITADO e destruído (`pivoDeitado`: rotação da maior peça).
- Pose parada pelo estado (`VeiculoModelo.assentar`, chamado em `nascer`): queimado desce `raio - folga` (sem rodas, no chão); pneu furado/faltando baixa e inclina o canto (`Cfg.queda`). Depois `VeiculoModelo.encostar` põe o ponto visível mais baixo no chão (raycast): nunca flutua. Medido: 203 carros, variação ±0,05 stud; as exceções são carros queimados empilhados sobre props no ferro-velho.
- Sem efeito visual parado com a malha: amassado, carroceria baixa, motor (só atributo/som).
- Spawn de ~200 carros leva ~35 s no servidor ao iniciar (ancorados).

## Carros do mapa sob demanda (2026-11-04)
- `coletarProps` varre `Mapa.Props` e `Mapa.Construcoes` (pula as pastas gigantes Chao, Ruas, Vegetacao, Zonas, Pontos, Rios, Bordas). Todo prop `carro`/`carro_destruido` vira uma VAGA `{cf, estado, deitado, destruido}`; o prop de blocos é destruído na hora. Nenhum prop de carro fica como bloco.
- Estado decidido uma vez, na abertura, e guardado na vaga (recriar usa o MESMO estado): `carro` normal que pode andar = operacional (4 pneus ok, motor 60-100, carroceria 70-100, nada faltando, vidros ok, via `Regra.montar`); `carro_destruido`, tombado, preso ou sem espaço = destruido/queimado (`sortearEstado`).
- Preso: `podeSair` faz `workspace:Blockcast` (caixa 0,9 do tamanho, a 1,2 do chão, 25 studs para frente e para trás, ignora Chao/Ruas/Zonas/Pontos/Rios, Terrain e os outros props de carro). Bloqueio a menos de 6 studs nos DOIS sentidos = preso, vira destruido. Se nenhum dos 6 tipos cabe (`colideComMapa`), nasce o compacto destruido na pose do prop, caixa relaxada a 0,7; sobreposição leve é aceita e contada.
- Materialização: laço a cada 1,5 s. Cria (função `nascer`) a vaga com jogador a menos de `Cfg.mapa.raioCriar` (350), no máximo `criarPorCiclo` (4) por ciclo; remove (Destroy) se nenhum jogador a menos de `raioRemover` (450) e o carro nunca foi mexido. Mexido = atributo `Mexido=true` (alguém sentou, dano/tiro/batida) ou solto da âncora: nunca removido nem recriado. Carro destruído por outro sistema vira vaga morta. Sem jogadores nada é criado. Invocados pelo admin ficam fora do laço.
- Números: ver "Medidas" abaixo.

Medidas (Studio, 2026-11-04): abertura decide 241 vagas (de 241 props em Props+Construcoes) em 16,8 s (antes ~35 s criando 202 carros; ~23 mil instâncias). 174 operacionais, 67 destruidos/queimados (25 tombados), 0 presos, 16 não couberam (3 ainda sobrepostos com a caixa a 0,7), 0 props de carro sobrando. Logo após a abertura: 6 carros / 685 instâncias; com o jogador a >450 studs de tudo: 0 instâncias. Teleporte a posto, garagem e ferro-velho: carros aparecem em <6 s, flutuação máxima 0,00 (limite 0,1), operacionais com 4 pneus ok e motor 60-100; ao se afastar, os não mexidos somem. Teste de direção (motores ligados pelo servidor, dono de rede nil): sedan do posto andou 103 studs em 5 s. Um van de garagem marcado operacional não se mexeu (parede/mureta a ~6 studs dos dois lados): o teste de preso usa 6 studs e só enxerga bloqueio dos dois sentidos.
