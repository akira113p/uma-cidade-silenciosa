# Som v2: o que se ouve de uma pessoa, e quem ouve (contrato de implementação)

Escrito em 2026-11-14 (Opus) para um agente Sonnet aplicar. Substitui §1 e §2.1 de `docs/calculos.md` (a Fase E troca essas seções por
um resumo + link para cá). Números marcados `PROVISÓRIO` não foram medidos; ficam em `Config/` e se ajustam no playtest. **Nenhum número
solto no código.** Cada comportamento novo que o usuário ainda não aprovou tem um interruptor `ligado` no Config (§11).

Unidades: studs no jogo, metros nas fórmulas (`metrosPorStud = 0,28`). dB = nível a 1 m da fonte.

---

## 0. O que muda, em uma tela

| Hoje | Som v2 |
|---|---|
| Um som = **um número** (dB) | Um som = **3 bandas** (grave, médio, agudo) + **via chão** (vibração) |
| Passo = base do modo + superfície | Passo = **camadas somadas**: pisada, equipamento (carga), respiração (estamina), vegetação |
| Nada no caminho faz barulho | **Detritos no chão** (vidro, lata, garrafa, folhas, galho, entulho, tábua solta), **esbarrar** em móvel/prop, **item caindo** |
| Parede tira 10 dB | Parede tira **por banda**: o grave atravessa, o agudo morre (o "tum-tum" atrás da parede) |
| Ar não absorve nada | O agudo se perde com a distância (de longe só se ouve o grave) |
| Ambiente = 1 número | Ambiente **por banda**: a chuva cobre o agudo, não cobre o grave |
| Audição = margem por nível (0/6/12) | Audição **por espécie**: limiar por banda, sente (ou não) o chão, precisão, atenção que muda com o estado |
| Erro da posição só pela distância | Erro também pela banda: **grave e chão se localizam mal**, agudo se localiza bem |
| Escondido perto do monstro, nada a fazer | **Minigame de segurar a respiração** quando um monstro em busca chega bem perto (§13) |

O que **não** muda: `Regras/Percepcao` (Calmo → Investiga → Caça) continua recebendo um `excesso` em dB; `Ruido.emitir(pos, db, tipo, fonte)`
continua existindo com a mesma assinatura; monstro não ouve monstro de nível igual ou maior; o servidor decide tudo, o cliente só mostra.

---

## 1. Conceito: o que alguém ouve de uma pessoa

Esta seção é o "porquê". As fórmulas (§3) e os números (§4–§7) saem dela.

### 1.1 Uma pessoa andando
Quem escuta alguém andar ouve, em ordem de força:
1. **A pisada.** O calcanhar bate, a ponta empurra. A força é ~1,2× o peso do corpo. O que se ouve depende **do chão**:
   concreto dá um estalo seco (médio e agudo); madeira de casa é oca e **range** (grave e médio, e o piso vibra, passa pelo chão);
   metal ressoa (agudo); cascalho "crocante" (agudo, longo); grama e terra abafam (quase só grave); água espirra.
2. **O que a pessoa carrega.** Chaves, munição, latas na mochila, a arma batendo no corpo: tilintar (agudo). Cresce com a **carga** e com o balanço do passo.
3. **A roupa e a vegetação.** Calça raspando, mato roçando na perna: farfalhar (agudo). Só vira barulho de verdade **dentro de arbusto ou mato alto**.
4. **A respiração.** Em repouso não se ouve. **Cansado**, sim: ofegar é médio e grave.

### 1.2 Agachado e deitado
- **Agachado:** passada curta, o peso desce devagar, o pé "escolhe" onde pisa. A pisada cai muito (−10 dB), o equipamento chacoalha menos,
  e **o chão quase não vibra**. Pisar num detrito agachado ainda faz som, mas pouco (o pé apalpa antes de pôr o peso).
- **Deitado (rastejando):** não há pisada; há **arrasto** contínuo, baixo. Rastejar sobre vidro ou folhas ainda se ouve de perto.

### 1.3 Uma pessoa correndo
- A pisada é 2–3× o peso do corpo, mais curta e mais forte (+15 dB sobre andar), 3 por segundo.
- O equipamento chacoalha muito; a respiração sobe, e **sobe mais quanto menor a estamina**.
- **O chão vibra**: quem sente vibração percebe a corrida de longe, mesmo atrás de parede.
- **Não dá para escolher onde pisar:** todo detrito no caminho é pisado com força total, e o corpo **esbarra** em móveis e props.

### 1.4 Objetos no caminho
- **Detritos no chão** (pisar): vidro quebrado estala, lata é chutada e rola, garrafa quebra (e vira vidro), folhas secas estalam,
  galho quebra (uma vez só), entulho range, tábua solta do assoalho range. **São visíveis**: o jogador atento olha onde pisa (a lanterna ajuda a ver, não muda a regra).
- **Esbarrar** (correndo, às vezes andando): cadeira arrasta, arquivo de metal bate, vitrine treme, carro abandonado ressoa.
- **Item caindo:** o que se larga ou se joga faz barulho onde cai. Isso é **distração**: jogar uma lata longe puxa o monstro para lá.

### 1.5 Quem ouve
Cada monstro é cego e ouve **do seu jeito** (§6): um sente o chão, outro tem ouvido fino para voz e passo, outro é abafado pelo próprio
corpo, o gigante ouve mal de perto mas sente a corrida de longe. Todo ouvido piora quando o dono está correndo (o próprio barulho)
e melhora quando ele para para escutar.

---

## 2. O evento de som

```lua
export type Bandas = { grave: number, medio: number, agudo: number } -- dB a 1 m, por banda

export type EventoRuido = {
	posicao: Vector3,
	db: number,              -- = max(bandas): compatível com o número único de hoje (HUD, Sons.tocar, Flores, Corcunda)
	bandas: Bandas,
	chao: number?,           -- dB da vibração pelo chão; nil = não toca o chão (voz, grito, tiro no ar)
	tipo: string,            -- "passo", "detrito", "esbarrao", "itemCaiu", "respiracao", ou o nome da ação de Config/Som.acoes
	dominante: string?,      -- camada mais forte do passo ("pisada", "equipamento", "respiracao", "vegetacao") ou subtipo do detrito ("vidro", "lata"...)
	fonte: (Player | Model)?,
	ambiente: number,        -- ambiente médio (compat)
	ambienteBandas: Bandas & { chao: number },
	tempo: number,
}
```

**Perfil** = quanto cada banda fica abaixo do nível da camada (offsets ≤ 0 dB; a banda mais forte vale 0). Uma **camada** é `{ nivel, perfil, chao? }`.

---

## 3. Fórmulas (puras, em `Regras/Som`)

### 3.1 Composição (somar camadas)
Soma de energia, banda a banda:
```
E_b    = 10·log10( Σ_c 10^((nivel_c + perfil_c[b]) / 10) )        b ∈ {grave, medio, agudo}
E_chao = 10·log10( Σ_c 10^(chao_c / 10) )                         só camadas com chao; nenhuma → nil
db     = max(E_grave, E_medio, E_agudo)
```
Duas camadas iguais somam +3 dB; uma camada 10 dB abaixo soma +0,4 dB (some no meio da mais forte).

### 3.2 Propagação pelo ar
```
m   = max(1, distancia_studs × 0,28)
R_b = E_b − 20·log10(m) − absorcao_b × m − parede_b × min(paredes, maxParedes)
```
`absorcao` (dB/m): grave 0, médio 0,01, agudo 0,03. `parede_b` (dB): grave 6, médio 10, agudo 14. `maxParedes = 3`. `PROVISÓRIO`.

### 3.3 Propagação pelo chão
```
R_chao = E_chao − 40·log10(m) − (|Δy| > chao.alturaMesmoPiso ? chao.outroPiso : 0)
```
Cai duas vezes mais rápido que o ar (12 dB por dobro de distância) e **ignora parede**. Outro andar (|Δy| > 10 studs) tira 20 dB. `PROVISÓRIO`.

### 3.4 Mascaramento (ambiente por banda)
| Condição | grave | médio | agudo | chão |
|---|---|---|---|---|
| noite | 20 | 20 | 18 | 0 |
| dia | 25 | 25 | 22 | 2 |
| chuva | 32 | 40 | 44 | 2 |
| tempestade | 50 | 55 | 55 | 8 |

`ambiente` (compat) = o médio. Escolha da condição: igual a hoje (`Som.condicao`).

### 3.5 Ouvir (excesso)
Para um ouvinte com limiar `L_b`, `L_chao` (§6) e atenção `T` (§6.3):
```
X_b    = R_b    − (A_b    + L_b    + T)
X_chao = R_chao − (A_chao + L_chao + T)       só se o ouvinte sente o chão (L_chao ~= nil) e o evento tem chao
excesso = max(X_grave, X_medio, X_agudo, X_chao);   banda = a que deu o máximo
```
`excesso >= 0` → ouviu; o resto segue `Percepcao.ouvir` como hoje (Investiga < 10 ≤ Caça; 2 sons em 5 s → Caça).

### 3.6 Alcance (para HUD, debug e `RollOffMaxDistance`)
`Som.alcanceEvento(bandas, chao, ambienteBandas, limiar)` = maior distância (studs) em que `excesso >= 0`, sem paredes, teto 600.
Com absorção não há fórmula fechada: **busca binária** em 0..600 studs, 20 iterações, sobre a função monótona `excesso(d)`.
O HUD e os sons 3D usam o **ouvinte de referência** (limiar 0 em todas as bandas, sem chão) = o nível 1 de hoje.

### 3.7 Erro da posição estimada
`raio = distancia × erroPorDistancia(espécie) × erroBanda[banda]`, `erroBanda`: grave 1,5, médio 1,0, agudo 0,8, chão 2,0. `PROVISÓRIO`.
(Grave e vibração dizem "tem alguém ali", não "exatamente ali".)

---

## 4. Passo do jogador (camadas)

O laço de hoje (`Ruido.amostrar`, 10 Hz, acumulador de passos) continua. A cada passo, em vez de `Som.emitido(modo, superficie)`, monta as
camadas com a regra pura nova `Regras/Passo.camadas(estado, cfg)` e compõe (§3.1). **Um evento por passo** (como hoje).

`estado = { modo, superficie, carga (kg), estamina (0..100), vegetacao: boolean }`. Modo novo: **`deitado`** (hoje deitado conta como
agachado; `Som.modoPasso` ganha o argumento `deitado` e devolve `"deitado"` antes de `"agachado"`).

### 4.1 Camadas
| Camada | Nível (dB) | Perfil {g, m, a} | Chão |
|---|---|---|---|
| **pisada** | `pisada[modo] + superficie.pisada` | `superficie.perfil` | `pisada[modo] + superficie.pisada + chaoModo[modo] + superficie.chao` |
| **equipamento** | `equip[modo] + 10·log10(1 + carga / cargaRef)` | {−12, −3, 0} | — |
| **respiração** | `resp[modo] + respCansaco × (1 − estamina/100)` | {−3, 0, −9} | — |
| **vegetação** | `vegetacao[modo]` (só se dentro de arbusto/mato) | {−15, −3, 0} | — |

| Modo | pisada | chaoModo | equip | resp | vegetacao | passos/s |
|---|---|---|---|---|---|---|
| deitado | 20 | −25 | 10 | 12 | 18 | 1 |
| agachado | 30 | −20 | 16 | 14 | 24 | 1,5 |
| andar | 40 | −4 | 24 | 18 | 36 | 2 |
| correr | 55 | +4 | 36 | 30 | 46 | 3 |

`cargaRef = 10` kg, `respCansaco = 22`. As pisadas são as bases de hoje: **sem carga e descansado, o alcance de referência fica igual ao de hoje**
(conferido em §8). Tudo `PROVISÓRIO`.

### 4.2 Superfícies (substitui `superficies` de Config/Som; mesmas listas de materiais)
| Superfície | pisada | perfil {g, m, a} | chao | Observação |
|---|---|---|---|---|
| carpete | −8 | {−6, 0, −12} | −10 | |
| gramaBaixa | −5 | {−6, 0, −6} | −8 | |
| terra | −3 | {0, −3, −12} | −6 | |
| concreto (padrão) | 0 | {−6, 0, −3} | 0 | |
| pedra | +2 | {−6, 0, −2} | 0 | |
| madeira | +3 | {0, 0, −8} | **+6** | piso oco: passa pelo chão |
| gramaAlta | +5 | {−12, −3, 0} | −8 | |
| cascalho | +6 | {−12, −3, 0} | −4 | |
| agua | +6 | {−6, 0, −3} | −10 | |
| metal | +8 | {−3, −3, 0} | +8 | |
| vidro (novo; tira `Glass` de `agua`) | +6 | {−15, −4, 0} | −4 | |

### 4.3 Carga
Campo novo **`peso`** (kg) em cada item de `Config/Itens` (o `peso` das tabelas de loot é outra coisa: é chance de sorteio; o campo novo
fica no item, ao lado de `nome`). Sem campo = 0,5 kg. Armas: o peso entra pela entrada da arma em `Config/Itens`. `carga` = Σ (peso × qtd)
do inventário. Função nova `Inventario.carga(jogador): number` (lê os slots, sem custo de rede). Valores de referência `PROVISÓRIO`:
comida/bebida 0,4, bandagem 0,1, kit 1, lanterna 0,5, faca 0,3, pé de cabra 2, machado 2,5, pistola 1, escopeta/fuzil 3,5–4,5, munição 0,02 por unidade,
galão cheio 4, garrafa cheia 1.

### 4.4 Respiração parado (`respiracao.ligado`, padrão ligado)
Parado com estamina baixa também ofega: a cada `respiracao.intervalo = 2` s, se `resp.parado (10) + respCansaco × (1 − estamina/100) >= respiracao.minimo (25)`
(estamina abaixo de ~32%), emite evento `"respiracao"` (perfil da camada, sem chão). Lê o atributo `Estamina` do Player (já existe, 0..100).

### 4.5 Aterrissagem
`"aterrissar"` ganha perfil {0, 0, −6} e chão = `50 + superficie.chao + 10·log10(altura / 3)`; o nível também soma `10·log10(altura/3)` (cair de 12 studs = +6 dB).

---

## 5. Objetos no caminho

### 5.1 Detritos no chão (módulo novo `server/Detritos.luau`)
**Onde nascem:** em tempo de execução, como as Portas e o Loot (**o arquivo do mapa não muda**, regra 4). No `iniciar`, um `Random.new(semente fixa)`
sorteia pontos dentro das partes de `Mapa.Zonas` (atributo `Zona`), faz raycast para baixo (filtro Include: `Mapa.Chao`, `Mapa.Ruas`, `Mapa.Construcoes`),
aceita se `normal.Y > 0,9` e se não há móvel/prop em cima (`GetPartBoundsInBox` pequeno), e põe o detrito ali. Em lotes com `task.wait()`.
Pasta `workspace.Detritos`. Peças: 1–3 `Part` por detrito, `Anchored`, `CanCollide/CanQuery/CanTouch = false`, `CastShadow = false`, cores PS1 sem textura.

**Quanto:** `detritos.total = 5000` `PROVISÓRIO`, repartido por zona e tipo (tabela abaixo). Dentro de construção (o raycast bateu em `Construcoes`)
só vidro, lata, garrafa, entulho e tábua (tábua só se o material do piso for madeira).

**Detecção (sem Touched):** grade espacial no servidor (célula 8 studs, mesma ideia das Flores). A cada passo do jogador, procura detritos a
≤ `raioPe (1,2) + raio do detrito` do pé (posição do HRP − altura do quadril). Para cada um achado: sorteia `chance[modo]`; se acionou e o detrito não acionou para
esse jogador há < 1,5 s, emite **um evento separado** `tipo = "detrito"`, `dominante = <tipo do detrito>`, na posição do detrito, `fonte = jogador`, e toca o som.

| Detrito | deitado | agachado | andar | correr | perfil {g, m, a} | chão | Depois de acionar | Zonas (peso) |
|---|---|---|---|---|---|---|---|---|
| vidro | 22 | 30 | 50 | 62 | {−15, −4, 0} | — | fica | cidade 3, fábrica 2, vila 1 |
| lata | 18 | 28 | 48 | 60 | {−12, −3, 0} | — | chutada: anda 2–5 studs na direção do passo; correndo rola: 2º evento 45 dB 0,6 s depois, no ponto final | cidade 3, vila 2, fábrica 1 |
| garrafa | 20 | 30 | 52 | 66 | {−15, −4, 0} | — | correndo **quebra** e vira vidro; senão rola como a lata | cidade 2, vila 2 |
| folhas | 15 | 22 | 38 | 48 | {−12, −2, 0} | — | fica | floresta 5, vila 2 |
| galho | 20 | 32 | 50 | 58 | {−6, 0, −2} | 30 | **quebra** e some | floresta 4, vila 1 |
| entulho | 18 | 26 | 44 | 56 | {−3, 0, −6} | 36 | fica | cidade 2, fábrica 3 |
| tábua | 20 | 34 | 46 | 52 | {0, 0, −10} | 40 | fica (range sempre) | interior de casa com piso de madeira |

`chance`: deitado 1,0, agachado 0,6, andar 0,9, correr 1,0. Tudo `PROVISÓRIO`. Sons novos em `Config/Sons`: `DetritoVidro`, `DetritoLata`,
`DetritoLataRolar`, `DetritoGarrafa`, `DetritoFolhas`, `DetritoGalho`, `DetritoEntulho`, `DetritoTabua` (ids vazios por ora; `Sons.tocar` já avisa uma vez e segue).

### 5.2 Esbarrar em móveis e props (módulo novo `server/Obstaculos.luau`)
Os móveis do mapa têm o atributo **`Movel`** (nome em `ferramentas/mapa/mobilia_tamanhos.luau`) e os props têm **`Prop`** (nome em `props_tamanhos.luau`).
Nada é preciso mudar no mapa.

**Detecção:** no mesmo laço de 10 Hz, só em `andar` e `correr`, uma caixa à frente do movimento: centro = HRP + direção horizontal × 2, à altura
do pé + 1,5, tamanho (2,2; 2; 1,2) virada para a direção; `GetPartBoundsInBox` com Include `{Mapa.Construcoes, Mapa.Props, ZonaTeste}` (use `Raizes`).
Para cada parte, sobe até 4 ancestrais procurando um `Model` com `Movel` ou `Prop`. Se é **contato novo** (não estava na caixa da amostra anterior)
e o par (jogador, objeto) não esbarrou há < 2 s: correndo, sempre; andando, com chance `esbarrar.chanceAndar = 0,25`. Emite evento `"esbarrao"`,
`dominante = classe`, na posição do contato.

| Classe | correr | andar | perfil {g, m, a} | chão | Movel/Prop (lista inicial; o resto cai em `padrao`) |
|---|---|---|---|---|---|
| madeiraLeve | 58 | 44 | {−6, 0, −4} | — | cadeira, banqueta, mesa_centro, criado_mudo, cadeira_escritorio, carteira_escolar, mesa_dobravel, cabideiro, luminaria_chao, planta_vaso, cesto_lixo, caixa_papelao, cesto_roupa, cone, palete |
| madeiraPesada | 50 | 38 | {0, −2, −10} | 40 | mesa_jantar, mesa_cozinha, mesa_escritorio, mesa_reuniao, guarda_roupa, comoda, estante_livros, aparador, bau, balcao_loja, balcao_bar, balcao_caixa, banco_igreja, banco_praca |
| metalOco | 66 | 52 | {−8, −2, 0} | — | arquivo, arquivo_alto, armario_escola, armario_medico, armario_armas, prateleira_mercado, prateleira_loja, prateleira_garagem, estante_industrial, carrinho_compras, lixeira_rua, cacamba, tambor_oleo, barril, maquina_venda, bicicleta, caixa_ferramentas, galao, cadeira_rodas, cela_grade |
| vidro | 70 | 56 | {−15, −4, 0} | — | vitrine, geladeira_expositora, espelho_parede, espelho_banheiro, box_chuveiro |
| estofado | 30 | 22 | {−6, 0, −15} | — | sofa, sofa_pequeno, sofa_recepcao, poltrona, cama_casal, cama_solteiro, beliche, cama_campanha, fardo_feno, fardo_feno_ext, saco_areia |
| eletro | 54 | 42 | {−3, 0, −6} | — | geladeira, fogao, maquina_lavar, microondas, freezer_horizontal, computador, copiadora, jukebox, bebedouro, gerador, compressor |
| piano | 72 | 60 | {0, 0, −2} | — | piano, orgao |
| veiculo | 62 | 48 | {0, −2, −4} | 50 | carro, carro_destruido, caminhao, onibus, trator, trailer |
| padrao | 46 | 36 | {0, 0, −6} | — | qualquer outro `Movel`/`Prop` |

Paredes, chão e construções (sem `Movel`/`Prop`) não fazem som de esbarrão. Sons: `EsbarrarMadeira`, `EsbarrarMetal`, `EsbarrarVidro`, `EsbarrarEstofado`,
`EsbarrarPiano`, `EsbarrarVeiculo` (padrão e madeiraPesada usam `EsbarrarMadeira`; eletro usa `EsbarrarMetal`). `PROVISÓRIO`.

### 5.3 Vegetação
A mesma consulta da §5.2, com `Mapa.Vegetacao` no Include, marca `vegetacao = true` no estado do passo se alguma parte achada for de arbusto/mato
(nome ou ancestral contém `arbusto`, `moita` ou `cerca_viva`; **conferir os nomes reais em `ferramentas/mapa/floresta.luau` e `props_urbanos.luau`**
e listar em `Config/Som.vegetacao.nomes`). Material `LeafyGrass` sob o pé também conta. Para isso a consulta roda também em `deitado` e `agachado`
(caixa menor, só para vegetação: sem esbarrão).

### 5.4 Item caindo (`ItensChao`)
Quando um item solto termina o arremesso/queda (`Regras/Arremesso` pousa), emite `"itemCaiu"` **na posição do pouso**, `fonte = quem largou/jogou`:
`nivel = queda[classe] + 10·log10(max(1, altura / 3))`. Classe = campo novo opcional `classeQueda` no item; sem ele, pelo `tipo`:

| classe | dB | perfil | Itens (padrão) |
|---|---|---|---|
| metal | 55 | {−8, −2, 0} | armas, pé de cabra, machado, lata (enlatado), galão |
| vidro | 62 | {−15, −4, 0} | garrafas, água, refrigerante (o item **não** quebra, é só o som) |
| macio | 30 | {−6, 0, −12} | bandagem, kit, comida embalada |
| padrao | 40 | {0, 0, −6} | resto |

Morte espalhando itens também gera o som (um evento por item, no máximo 4 por morte). `itemCaiu.ligado` (padrão ligado). `PROVISÓRIO`.

---

## 6. Audição por espécie (`Config/Audicao.luau`, novo)

### 6.1 Perfil
```lua
porEspecie = {
	[id] = {
		limiar = { grave = n, medio = n, agudo = n }, -- dB acima do ambiente para ouvir; menor = ouve melhor
		chao = n?,           -- limiar da vibração; nil = não sente o chão
		erroPorDistancia = n, -- substitui Config/Monstros.estados.erroPorDistancia para esta espécie
	},
},
porNivel = { [1] = 0, [2] = 6, [3] = 12 }, -- espécie sem perfil: limiar plano = margem do nível (= hoje), sem chão, erro padrão
```

| Espécie | grave | médio | agudo | chão | erro | Por quê (ficha em `docs/monstros/`) |
|---|---|---|---|---|---|---|
| Rastejador | 0 | 2 | 6 | 14 | 0,15 | rente ao chão: ouvido bom de grave; **o Pulso** baixa o chão (§6.4) |
| Wrapper | 2 | 6 | 10 | — | 0,10 | corpo envolto abafa o ouvido (pior no agudo); compensa com o sonar |
| Corcunda | 6 | −4 | 0 | — | 0,08 | ouvido fino de **médio** (passo, voz, porta: o que ele imita) e sabe de onde veio |
| MonstroPS1 | 2 | 4 | 8 | — | 0,20 | barulhento; o próprio raspar o atrapalha (§6.4) |
| Florescida | 6 | 12 | 16 | 4 | 0,15 | gigante (nível 3): ouve mal de perto, **sente a corrida pelo chão** de longe; as flores ouvem por ela |
| Esfolado, Espreitador, Carniceiro, Pernalta | `porNivel` | | | | | não nascem hoje |

Tudo `PROVISÓRIO`. Com perfil plano {0, 0, 0} e sem chão o resultado é idêntico ao de hoje (teste de regressão na §9).

### 6.2 Como o servidor usa (`Monstros.processarRuido`)
1. Mesmos cortes de hoje: imitação ignorada; nível da fonte ≥ nível do ouvinte ignorado; fora de 600 studs ignorado.
2. `perfil = Audicao.perfil(especie.id, nivel, Config)`. Calcula o excesso **sem paredes** (§3.5). Se `< 0` em todas as bandas **e** no chão → pula (não paga raycast).
3. Se só o ar poderia ser ouvido e há construções, conta paredes (mesmo `contarParedes`, mesmo orçamento `raycastsPorFrame`) e recalcula as bandas.
   O chão não depende de parede: se `X_chao >= 0` não precisa raycast.
4. `excesso >= 0` → `Percepcao.estimar` com o raio da §3.7 e `ouvirSom(d, excesso, pos, agora, info)`. `info` ganha `banda` e `via` (`"ar"`/`"chao"`).

### 6.3 Atenção (estado do ouvinte)
`T` soma ao limiar de todas as bandas: Calmo 0, Investiga −2, Caça +4, Ataque +10; **parado** (velocidade horizontal < 1) mais −3.
Quem corre ouve pior (o próprio barulho); quem para escuta melhor. `PROVISÓRIO`.

**Pausa de escuta** (`pausaEscuta.ligado`, **padrão desligado**, a confirmar): em Investiga, ao chegar ao ponto estimado sem ouvir nada, o monstro
fica parado `duracao = 2` s (ganha o −3 de parado). Dá ao jogador um sinal claro: monstro congelado = escutando.

### 6.4 Habilidades que mexem na audição
Campo novo no `Dados` do monstro: `d.audicaoExtra: { grave, medio, agudo, chao }?` (somado ao limiar; negativo = ouve melhor). Quem liga, desliga.
- **Rastejador, Pulso:** hoje é um caso especial (`Regras.Habilidades.pulsoDetecta`: andar a ≤ 25 studs conta). Passa a ser **audição**: durante a janela
  do pulso, `d.audicaoExtra = { chao = pulso.bonusChao (−12) }`. Com os números da §4, andar no concreto é sentido pelo chão até ~25 studs (igual a hoje,
  conferido em §8); agachado até ~6 studs. Para manter a regra atual ("agachado e deitado não contam"), `pulso.ignorarAgachado = true` (**padrão**):
  durante o pulso, evento de passo `agachado`/`deitado` não usa a via chão para esse monstro. A varredura `pulsoDetecta` sai; a posição
  vem do evento (com o erro da via chão). `pulso.raio` deixa de ser usado (fica no Config com comentário "legado").
- **MonstroPS1, raspar (Calmo):** enquanto raspa, `d.audicaoExtra = { grave = 6, medio = 6, agudo = 6 }` (`raspar.surdez`). Dá para se aproximar dele enquanto raspa.
- **Corcunda:** a memória de imitação recebe os tipos novos (`detrito`, `esbarrao`, `itemCaiu`, `respiracao`) se a lista dele for fechada: conferir `Habilidades/Corcunda.aoOuvir`.
- **Flores, Wrapper (sonar), gritos, rugido, lâminas:** nada muda (usam `Ruido.emitir`, que ganha perfil pelo tipo, §7.2).

---

## 7. Servidor e rede

### 7.1 `server/Ruido.luau`
- `Ruido.emitirSom(ev: { posicao, bandas, chao?, tipo, dominante?, fonte? })`: a função principal. Preenche `db`, `ambiente`, `ambienteBandas`, `tempo` e
  chama os ouvintes (como hoje).
- `Ruido.emitir(pos, db, tipo, fonte)` **continua** (todos os chamadores atuais: Armas, Veiculos, Portas, Destruicao, Combustivel, Inventario, Loot, Foguete,
  habilidades). Monta as bandas com `Config/Som.perfisAcao[tipo]` (perfil e chão relativo); tipo sem entrada = perfil plano {0, 0, 0}, sem chão.
- `Ruido.emitirAcao` igual.
- `amostrar`: monta `estado` do passo (modo com `deitado`, superfície, `Inventario.carga`, atributo `Estamina`, vegetação de `Obstaculos`), compõe, emite
  `"passo"` com `dominante`; depois chama `Detritos.aoPasso(jogador, pe, modo, direcao)` e `Obstaculos.amostrar(jogador, ...)`.
- Respiração parado (§4.4) e aterrissagem (§4.5).
- `MeuRuido` (cliente) ganha um 4º argumento: `dominante` (string ou nil). `alcance` passa a ser `Som.alcanceEvento` com o ouvinte de referência.

### 7.2 `Config/Som.perfisAcao` (perfil das ações que já existem) `PROVISÓRIO`
| Tipos | perfil {g, m, a} | chão (dB relativo ao nível; nil = sem) |
|---|---|---|
| pistola, fuzil, arma | {−2, 0, 0} | nil |
| carro, carroLigar, carroFalhar | {0, −4, −10} | −10 |
| carroBatida, pneuEstouro | {0, 0, −4} | −6 |
| carroDerrapar | {−10, −3, 0} | nil |
| buzina | {−8, 0, −2} | nil |
| porta, portaAbrir, portaFechar | {−4, 0, −6} | nil |
| portaBater | {0, 0, −6} | −10 |
| vidro | {−15, −4, 0} | nil |
| golpe, paredeQuebrando, batidaCorpo | {0, −2, −8} | −8 |
| gritoMonstro, sonar, rugido | {−6, 0, −3} / {−6, 0, −3} / {0, −2, −10} | nil / nil / −6 |
| pulsoChao, raspar | {0, −6, −12} / {−10, −3, 0} | −4 / nil |
| voz | {−8, 0, −4} | nil |
| abrirCaixa, comer, beber, bandagem, kit | {−6, 0, −4} | nil |
| abastecer, encher, despejar | {−4, 0, −8} | nil |

### 7.3 Cliente
- `HudSom`: igual + um rótulo curto com o `dominante` do último ruído ("passo", "equipamento", "respiração", "mato", "vidro!", "lata!", "esbarrão!",
  "item caiu"). Mapa nome → texto em `Config/Som.medidor.rotulos`. Cor continua pelo `db` contra o ambiente.
- `DebugRuido` (só Studio): o raio continua sendo o alcance de referência; a cor do círculo passa a indicar a banda dominante (grave azul, médio branco, agudo amarelo, chão marrom).
- Sons 3D (`Sons.tocar`): `RollOffMaxDistance` com `Som.alcanceEvento` quando receber `bandas` em `opcoes`; senão como hoje.

### 7.4 Testes no Studio (`ServerStorage.Teste`)
- `audicao`: imprime, para cada espécie, o alcance (studs) de andar/correr/agachado no concreto com o ambiente atual (a tabela da §8 ao vivo).
- `detritos <n>`: põe n detritos de cada tipo em fila em `Workspace.ZonaTeste` (skill `teste-no-void`), para pisar e ouvir.

---

## 8. Números conferidos (noite, concreto, carga 5 kg, estamina cheia, sem parede, monstro Calmo andando)

Bandas compostas (§3.1, §4): **andar** g 34,1 / m 40,1 / a 37,3, chão 36; **correr** g 49,0 / m 55,1 / a 52,2, chão 59; **agachado** g 24,3 / m 30,2 / a 27,5, chão 10.
(Conferido em 2026-11-14 com um script à parte: soma de energia + busca binária, as mesmas fórmulas da §3.)

Alcance (studs), pela banda que vence:

| Ouvinte | agachado | andar | correr | Hoje (nível 1) |
|---|---|---|---|---|
| Referência (limiar 0) | 12 | 36 | ~190 | 11 / 36 / 200 |
| Rastejador | 9 | 29 | ~153 | |
| Rastejador no Pulso (só a via chão, limiar 2) | (6, ignorado) | 25 (chão) | — | 25 (raio do pulso) |
| Wrapper | 6 | 18 | ~98 | |
| Corcunda | 18 | 56 | ~292 | |
| MonstroPS1 | 7 | 23 | ~124 | |
| Florescida | 5 (chão) | 23 (chão) | 85 (chão) | |

Atrás de **2 paredes**, correndo, Rastejador: médio 13 dB acima → 16 studs; grave 17 dB → **25 studs**: o grave atravessa e vence.
Os valores com `~` dependem da absorção; o teste aceita ±2 studs. Os outros, ±1.

---

## 9. Fases para o Sonnet

Leia antes: este documento, `docs/arquitetura.md` §5, `docs/monstros/logica.md` §1 e §3 (Pulso), `src/server/Ruido.luau`, `src/server/Monstros.luau`
(Ruído, ~linhas 420–580), `src/shared/Regras/Som.luau`, skill `codigo-roblox`. Regras de versão do `CLAUDE.md` valem (em especial 6, 7 e 9).

**Pode mexer:** `src/shared/Regras/{Som,Passo,Audicao}.luau`, `src/shared/Config/{Som,Audicao,Itens,Sons,PresetsMonstro}.luau`, `src/server/{Ruido,Detritos,Obstaculos,Monstros,ItensChao,Inventario}.luau`,
`src/server/Habilidades/{Rastejador,MonstroPS1,Corcunda}.luau`, `src/client/{HudSom,DebugRuido}.luau`, `src/shared/Rede.luau` (`MeuRuido` e os eventos da §13),
`src/shared/Regras/Respiracao.luau`, `src/shared/Config/Respiracao.luau`, `src/server/Respiracao.luau`, `src/client/RespiracaoMinigame.luau`, `src/shared/Config/Movimento.luau` (só a tecla nova), `tests/`,
`docs/{som,calculos,arquitetura,pendencias-integracao}.md`. Fora disso, pergunte.

Cada fase termina com `pwsh scripts/checar.ps1` verde. Ao fim de cada fase, atualize "Estado" (§12).

**A. Regras puras + Config** (sem tocar no servidor)
- `Regras/Som`: `somar`, `compor`, `propagarAr`, `propagarChao`, `ambienteBandas`, `alcanceEvento`; `modoPasso` com `deitado`. **Manter** `emitido`, `recebido`,
  `alcance`, `excesso` (os testes atuais continuam passando).
- `Regras/Passo.camadas(estado, cfg)`; `Regras/Audicao`: `perfil`, `excesso(evento, perfil, distancia, paredes, dy, atencao, extra) -> (excesso, banda)`, `erroBanda`, `precisaParedes`.
- `Config/Som` (bandas, superfícies novas, passo, detritos, esbarrar, vegetação, respiração, queda, perfisAcao, rótulos); `Config/Audicao`; `peso` em `Config/Itens`.
- Testes Lune: `tests/Som.spec.luau` (compor: 2 camadas iguais = +3; −10 dB = +0,4; propagação por banda; paredes por banda), `tests/Passo.spec.luau`
  (bandas da §8), `tests/Audicao.spec.luau` (**toda** a tabela da §8 com as tolerâncias; perfil plano = resultado de hoje; Pulso com/sem `ignorarAgachado`).

**B. Servidor: emitir e ouvir**
- `Ruido` (§7.1), `Inventario.carga`, `Monstros.processarRuido` (§6.2), atenção (§6.3), `d.audicaoExtra`, `info.banda/via`.
- Rastejador Pulso → audição (§6.4); MonstroPS1 raspar → surdez; Corcunda: tipos novos.
- `HudSom` rótulo, `MeuRuido` 4º argumento, `DebugRuido` cor por banda, `Sons.tocar` com bandas.

**C. Objetos no caminho**
- `Detritos.luau` (§5.1), `Obstaculos.luau` (§5.2, §5.3), `ItensChao` (§5.4), sons novos no catálogo (ids vazios), comandos `audicao` e `detritos`.
- Medir o custo: tempo de colocação dos 5000 detritos e o custo por amostra de `Obstaculos` com 10 jogadores simulados (escrever no Estado).

**D. Teste no Studio** (só a sessão **dona do Studio**, regra 6; senão, deixar a lista em `docs/pendencias-integracao.md` "Som v2")
Na `ZonaTeste`, em Play: andar/correr/agachar perto de um Rastejador e conferir a distância em que ele reage contra a §8; pisar em cada detrito;
correr contra uma cadeira e um arquivo; jogar uma lata e ver o monstro ir ao pouso; Pulso com o jogador andando e agachado; console sem erro.

**F. Segurar a respiração** (§13; depende de B)
- `Regras/Respiracao` (pura) + `tests/Respiracao.spec.luau`, `Config/Respiracao`, `server/Respiracao.luau`, `Monstros.proximos`, eventos de rede,
  `client/RespiracaoMinigame.luau` (UI pela skill `ui-roblox`), corte da camada de respiração no `Ruido`. Teste no Studio só pela dona (fase D).

**E. Documentos**
- `docs/calculos.md` §1 e §2.1: trocar pelo resumo de 5 linhas + link para cá (as tabelas antigas saem). `docs/arquitetura.md` §5: `EventoRuido` novo e `emitirSom`.
- `docs/pendencias-integracao.md`: seção "Som v2" (sons sem id, números a medir, decisões da §11 ainda abertas).

---

## 10. Armadilhas
- **Não quebrar quem chama `Ruido.emitir` com número.** São ~20 chamadas; nenhuma precisa mudar na fase B.
- **`CfgSom.acoes.<x>` é lido como número** em vários lugares (`Monstros.gritar`, `Ruido` aterrissar, `Sons.tocar`). Não transformar `acoes` em tabela; o perfil vai em `perfisAcao`.
- **Raycast só para quem pode ouvir.** O corte sem paredes (§6.2 passo 2) é o que mantém o custo de hoje. Via chão nunca paga raycast.
- **Uma consulta espacial por jogador por amostra**, no máximo (esbarrão + vegetação na mesma caixa). Detritos usam a grade, não consulta física.
- **Detritos não são mapa.** Nada vai para `mapa/Mapa.rbxm` nem para `Workspace.Mapa`; ficam em `workspace.Detritos`, recriados a cada servidor.
- **Excesso de detrito/esbarrão conta para `somsParaCaca`.** Pisar numa lata e dar um passo = 2 sons em 5 s = Caça, se ambos forem ouvidos. É de propósito.
- **Monstro não ouve monstro de nível ≥** continua valendo para todos os tipos novos.

---

## 11. Decisões (padrões aprovados pelo usuário em 2026-11-14: "perfeito")

Todos os padrões abaixo valem como estão. A pausa de escuta fica **desligada**; ligá-la é decisão nova. Os interruptores ficam para o playtest.

| # | Decisão | Padrão aplicado | Interruptor |
|---|---|---|---|
| 1 | Detritos nascem em tempo de execução (não no gerador do mapa) | sim | `detritos.ligado` |
| 2 | Pulso do Rastejador continua ignorando agachado/deitado (pela física, agachado seria sentido a ~6 studs) | ignora | `pulso.ignorarAgachado` |
| 3 | Ofegar parado com estamina baixa faz barulho | sim | `respiracao.ligado` |
| 4 | Item largado/jogado faz barulho onde cai (distração) | sim | `itemCaiu.ligado` |
| 5 | Pausa de escuta em Investiga | **não** | `pausaEscuta.ligado` |
| 6 | Perfis de audição da §6.1 (Corcunda ouve passo a ~56 studs; Florescida sente corrida a ~85) | como na tabela | números em `Config/Audicao` |
| 7 | Itens ganham peso (kg) e a carga aumenta o barulho | sim | `equipamento.ligado` |
| 8 | Esbarrar andando (25% de chance), não só correndo | sim | `esbarrar.chanceAndar` |

---

## 12. Estado
- 2026-11-14: arquitetura escrita (Opus). Padrões da §11 aprovados. Minigame de respiração (§13) pedido pelo usuário e especificado.
- 2026-11-14 (Sonnet): **fases A, B, C e F implementadas; `pwsh scripts/checar.ps1` verde (38 suítes Lune, selene e stylua sem avisos). Fase D (Studio) NÃO feita**: lista em `docs/pendencias-integracao.md` "Som v2". Fase E (documentos) feita.
  - **A:** `Regras/{Som,Passo,Audicao}` + `Config/{Som,Audicao}` + `peso`/`classeQueda` em `Config/Itens`. `tests/Som.spec` (novos blocos §9), `tests/Passo.spec` (bandas da §8) e `tests/Audicao.spec` (toda a tabela da §8 com ±1 e ±2 nos `~`, 2 paredes, Pulso com/sem `ignorarAgachado`, regressão do perfil plano) passam com as fórmulas da doc, sem ajustar nenhum número. `Config/Som.acoes` continua com números; `Som.modoPasso` aceita `deitado` como 4º argumento opcional; superfícies ganharam `perfil`/`chao` (o `db` da superfície é a `pisada` da doc) e `vidro` (saiu de `agua`, com `PassoVidro`).
  - **B:** `Ruido.emitirSom` (função principal), `emitir`/`emitirAcao` com a mesma assinatura (bandas de `Config/Som.perfisAcao`), passo em camadas (`Inventario.carga`, `Estamina`, vegetação), ofego parado, aterrissagem por `Passo.aterrissagem`; `Monstros.processarRuido` por `Regras/Audicao` (cortes iguais, excesso sem paredes, `precisaParedes`, erro por banda, `info.banda/via`), atenção do estado, `d.audicaoExtra`; Pulso do Rastejador virou audição pelo chão (`pulsoDetecta` ficou na regra só para o teste antigo; `pulso.raio` é legado), surdez de raspar do MonstroPS1, tipos novos na imitação do Corcunda; `HudSom` com rótulo, `MeuRuido` com 4º argumento, `DebugRuido` com cor por banda. **Não feito:** `Sons.tocar` com bandas (arquivo fora da lista; ver pendências).
  - **C:** `server/Detritos.luau` (5000 em runtime com semente fixa, grade de 8 studs, 7 tipos, lata chutada/rolando, garrafa que vira vidro, galho que quebra), `server/Obstaculos.luau` (esbarrão e vegetação, uma consulta por jogador por amostra), `ItensChao` (som do pouso, até 4 por morte; `Inventario` passa o jogador a `espalhar`), sons novos no catálogo com ids vazios, comandos `audicao`, `detritos`, `contardetritos`, `custoobstaculos`. **Custo: não medido** (sem Studio); estimativas e instrumentação em `docs/pendencias-integracao.md` "Som v2".
  - **F:** `Regras/Respiracao` + `tests/Respiracao.spec` (§13.6: sem apertar arfa antes de 3 s; o bot sem atraso passa 15 s em 10 de 10 sementes com proximidade 0 e 1; largura, tensão >= 0, borda zera a velocidade; mais as decisões `podeAbrir`/`motivoFim`), `Config/Respiracao`, `server/Respiracao.luau` (laço de 5 Hz, `Monstros.proximos`, fins do servidor, atributo `PrendendoRespiracao` que corta a camada de respiração do passo, `RespiracaoFalhou`), `client/RespiracaoMinigame.luau`, tecla `prenderRespiracao = { "F" }`, comando `respiracao`. O payload de "iniciar" ganhou `estamina` (o cliente acelera a zona com estamina baixa) e o fim `"morreu"`.
  - Desvios e lacunas: ver "O que o Som v2 não fez" e "Números a medir" em `docs/pendencias-integracao.md` "Som v2" (init não editado, UI sem a skill `ui-roblox`, pausa de escuta sem código atrás do interruptor, `MeuRuido` com a chave do rótulo).
- 2026-11-14 (revisão Opus): código conferido contra a doc (`Regras/Audicao`, `Regras/Passo`, `Monstros.processarRuido`, `Ruido.amostrar`, `server/Respiracao`, cliente do minigame, `Obstaculos`). Sem erro de lógica.
  Corrigido: detritos nasciam no leito dos rios (o raio ignora água); agora o ponto é rejeitado se cai na caixa de uma Part `Agua` de `Mapa.Rios`. `checar.ps1` verde depois da correção.
  Aceito como está: Detritos/Obstaculos/Respiracao iniciados pelo `Ruido.iniciar` (funciona; mover para a `ORDEM` do init quando a sessão dona desses arquivos puder).
  Aceito: o cliente pode nunca mandar a falha (§13.4).
- 2026-11-14 (fase D, Opus como dona do Studio, Play no place oficial, ZonaTeste, noite):
  - Ok, sem erro de script: início (5000 detritos em 4,3 s) e comando `audicao` (bate com as fórmulas).
  - Rastejador parado (atenção −3): reagiu a quem anda a **38 studs**, contra os ~40 esperados (passo a cada 8 studs).
  - Minigame:
    - abriu com Rastejador em Investiga a **10,5** e **10,9 studs**;
    - sem apertar, arfou em **3,0 s** (58 dB) e o monstro foi para Ataque.
  - Detritos:
    - agachado: galho 32 (quebrou), garrafa 30, vidro 30;
    - correndo: vidro 62, lata 60 (chutada, andou 4 studs) e depois 45 rolando, entulho 56.
    - Andando por cima de uma fila, só uma parte é pisada, porque a detecção é por passo.
  - Esbarrão correndo: cadeira **58**, arquivo **66**.
  - Place limpo depois.
  - **Achado:** a tecla F já é a **lanterna** (`Teclas_lanterna`). A §13.2 estava errada ao dizer que o F só é usado no carro. O usuário escolheu o **Espaço**; trocado (prioridade alta + Sink).
  - **Não testado:** segurar a tecla de fato. A ferramenta de teclado do MCP não segura tecla e `VirtualInputManager` é bloqueado, então o caminho de sucesso precisa de um humano.

---

## 13. Segurar a respiração (minigame)

Pedido do usuário (2026-11-14): quando um monstro **em busca** está **bem perto**, o jogador escondido segura a respiração num minigame
**simples e meio difícil**. Errar = arfar alto. Conceito: §1.1 item 4 (respirar se ouve de perto; cansado, mais).

### 13.1 Quando começa (o servidor decide)
Laço de 5 Hz em `server/Respiracao.luau`. Abre o minigame para o jogador se **tudo** vale:
- vivo, fora de carro, sem minigame ativo, e passaram `recarga = 6` s desde o último;
- modo `parado`, `agachado` ou `deitado` (quem anda ou corre já está fazendo barulho);
- existe monstro vivo em **busca** (`d.perc.estado == "Investiga"`, ou a Busca do Rastejador ativa) a ≤ `raio = 12` studs na horizontal e |Δy| ≤ 8.
  Monstro em `Caca`/`Ataque` não abre: ele já sabe onde você está. Função nova `Monstros.proximos(pos, raio): { Dados }`.
O monstro escolhido é o mais perto. `PROVISÓRIO`.

### 13.2 Como se joga
Uma barra vertical pequena à direita do centro da tela. Nela, uma **faixa clara** (a zona) se move sozinha para cima e para baixo, e um
**marcador** (o pulmão) cai sem parar. **Segurar a tecla** empurra o marcador para cima; **soltar** deixa ele cair. Manter o marcador dentro da faixa.
Fora dela, a **tensão** sobe; tensão cheia = **arfou**.

Tecla: `teclas.prenderRespiracao = { "Space" }` em `Config/Movimento`. Decisão do usuário em 2026-11-14: o F, que estava escrito aqui, é a lanterna.
Durante o minigame a ação tem prioridade alta e engole o Espaço (não pula); fora dele, o Espaço é o pulo. No celular: um botão "Segurar" na tela.

Regra pura `Regras/Respiracao.passo(estado, segurando, dt, rng, cfg) -> estado` (o cliente roda; os testes simulam):
```
v += (segurando ? empurrao : -gravidade) · dt ;  v *= (1 − amortecimento · dt) ;  p = clamp(p + v·dt, 0, 1)  (bateu na borda → v = 0)
zona: a cada [trocaMin, trocaMax] s sorteia um alvo em [w/2, 1 − w/2]; o centro anda até ele a velZona/s
w = lerp(larguraLonge, larguraPerto, proximidade)      proximidade = 1 − clamp((dist − 4) / (raio − 4), 0, 1)
tensao += (dentro ? −alivio : +subida) · dt   (mínimo 0) ;  tensao >= 1 → "falhou"
```
| Número | Valor | | Número | Valor |
|---|---|---|---|---|
| empurrao | 2,6 /s² | | larguraLonge / larguraPerto | 0,26 / 0,24 |
| gravidade | 1,8 /s² | | trocaMin / trocaMax | 0,8 / 1,6 s |
| amortecimento | 2,5 /s | | velZona | 0,35 /s (× 1,4 com estamina < 30%) |
| p e zona no início | 0,5 | | subida / alivio | **0,2** / 0,25 por s |

Assim: quem ficar fora da faixa o tempo todo arfa em **5 s** (1 / 0,2); quem não aperta nada arfa em ~5,5 s (o marcador leva ~1 s para sair da faixa). Era 0,55 (1,8 s); o usuário pediu +4 s em 2026-11-14. Tudo `PROVISÓRIO`.
Simulado em 2026-11-14 (script à parte, 100 sementes, 15 s, "bot" com reação humana de 0,25 s): **~81% passa** na borda do raio e **~57% colado**
(com 0,2 s de reação: 94% / 80%; com 0,3 s: 62% / 39%). Com `larguraPerto = 0,18` colado caía para 10%, por isso 0,24.

**Fôlego:** dura no máximo `10 + 8 × estamina/100` s (o servidor conta). Quem corre e depois se esconde aguenta menos, de propósito.

### 13.3 Como termina
| Fim | Quem decide | Som |
|---|---|---|
| Monstro se afastou (> raio + 4) ou voltou a Calmo | servidor | nenhum (soltou o ar devagar) |
| Monstro entrou em Caça/Ataque | servidor | nenhum (o minigame só some) |
| Jogador começou a andar/correr ou entrou em carro | servidor | nenhum; os passos já contam |
| **Fôlego acabou** | servidor | `"respiracao"` 28 dB, perfil da camada de respiração (§4.1): soltar o ar, baixo mas arriscado colado |
| **Arfou** (tensão cheia) | cliente avisa | `"arfar"` **58 dB**, perfil {−3, 0, −6}, na cabeça, `fonte = jogador`, som `Arfar`; estamina −10 |

Enquanto o minigame está ativo, a **camada de respiração do passo (§4.1) e a respiração parado (§4.4) somem** (`estado.prendendo = true` em `Regras/Passo`).
Essa é a recompensa: silêncio total parado.

### 13.4 Rede e confiança
- Servidor → cliente `Respiracao` (evento): `("iniciar", { duracao, proximidade })`, `("proximidade", n)` a cada 0,5 s (a faixa estreita quando o monstro chega perto), `("fim", motivo)`.
- Cliente → servidor `RespiracaoFalhou` (evento): sem argumentos. O servidor só aceita com minigame ativo, no máximo 1 por minigame, e só depois de 0,3 s do início.
- O servidor **não** aceita "venci" do cliente: o sucesso só vem dos fins do servidor (§13.3). Um trapaceiro pode nunca mandar a falha. Aceito: o ganho
  é ficar mudo parado (o mesmo que respirar baixo), e passos/detritos continuam com o servidor.

### 13.5 Cliente (`RespiracaoMinigame.luau`)
UI pela skill `ui-roblox` (spec JSON → preview → módulo). Durante o minigame: vinheta escurecendo com a tensão, batimento cardíaco (som `Coracao`, mais rápido com a proximidade)
e áudio do jogo abafado (`EqualizerSoundEffect` no `SoundGroup` "Efeitos", agudo −12 dB) para vender a tensão. Aviso de 1 linha na primeira vez: "Segure F para prender a respiração".
Cursor não aparece (é segurar tecla, não clicar). Sons `Arfar`, `Coracao`, `SoltarAr` no catálogo (ids vazios por ora).

### 13.6 Testes
- `tests/Respiracao.spec.luau`: sem apertar → falha antes de 3 s; um "bot" sem atraso que segura quando `p < centro da zona − v × 0,25` → passa 15 s em 10 de 10 sementes, com `proximidade` 0 e 1;
  largura no extremo; tensão nunca < 0; borda zera velocidade.
- Comando de teste `respiracao`: abre o minigame para quem chamou, com um monstro fictício a 8 studs, para testar na `ZonaTeste`.
  - 2026-11-14 (usuário): `subida` 0,55 → 0,2 (fora da faixa o tempo todo = 5 s até arfar). Simulado: com a tensão lenta o bot de reação 0,25 s passa **100%** (era 81% / 57%): o minigame ficou fácil; se quiser dificuldade de volta, apertar a faixa ou a velocidade dela em vez da subida.
