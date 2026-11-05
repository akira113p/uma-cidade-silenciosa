# Uma Cidade Silenciosa (título provisório)

Jogo de sobrevivência PvP para Roblox, em primeira pessoa com estética PS1/PS2, numa cidade infestada por monstros cegos
que caçam pelo som. Cada passo, porta, tiro e motor faz barulho, e o barulho atrai monstros e outros jogadores.
O conceito é inspirado em "Um Lugar Silencioso"; nome, criaturas e mundo são originais.

O visual-alvo é névoa densa, granulação, paleta fria dessaturada e acentos vermelhos.

## Estado

Corte vertical escrito e integrado (fases 1 a 8 de `docs/plano.md`), com sistemas posteriores em cima dele:

- som e percepção dos monstros, movimento, estamina, corpo por partes, inventário, morte e bolsa;
- mapa v2 de 900x900 studs gerado por código (interiores, rios, pontes, viadutos, floresta, relevo);
- filtro visual (névoa, grão, aberração cromática, moldura VHS);
- destruição universal de construções, o monstro Rastejador, carros e combustível, armas (11) com viewmodel.

Ainda falta o playtest humano com 3 ou mais clientes, o ajuste de números, e parte do que foi escrito (armas,
combustível) nunca rodou no Studio. O estado detalhado e as pendências estão em `CLAUDE.md` e
`docs/pendencias-integracao.md`.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `src/shared` | `Config` (todos os números), `Rede.luau` (toda a rede) e `Regras` (lógica pura, testável fora do Roblox) |
| `src/server` | regras autoritativas: ruído, dano, monstros, itens, veículos, destruição |
| `src/client` | câmera, controles, HUD, viewmodel, filtro visual |
| `tests` | suítes Lune (`*.spec.luau`) |
| `mapa` | `Mapa.rbxm`, a fonte do mapa v2 |
| `ferramentas` | gerador e checagem do mapa (Lune), scripts Blender/Python de modelos, filtro e animação |
| `assets` | texturas do filtro e dados de animação de armas |
| `docs` | arquitetura, plano, decisões, contratos de cada sistema |
| `pesquisa` | APIs conferidas e fontes |
| `scripts` | `checar.ps1` e `checar.sh` |
| `.claude/skills` | skills do fluxo de trabalho com o Claude Code |

Fora do repositório (ignorados): `modelos 3d/` (modelos de terceiros, temporários), `pesquisa/veiculos-pz/` (material
de referência de terceiros, não redistribuível), `build/`, `.env` e arquivos `.blend`/`.rbxl`.

## Requisitos

- [Rokit](https://github.com/rojo-rbx/rokit) para instalar as ferramentas nas versões fixadas em `rokit.toml`:
  Rojo, Selene, StyLua e Lune. Rode `rokit install`.
- Roblox Studio com o plugin do Rojo.
- PowerShell (`pwsh`) para `scripts/checar.ps1`.
- Opcional: Blender (scripts de `ferramentas/modelos`) e Python 3.

## Como rodar

```
rojo serve default.project.json
```

A porta é a 34872. No Studio, abra o place do jogo e clique em Connect no plugin do Rojo.

O mapa **não** passa pelo Rojo: ele é grande e trava a extensão. Por isso `default.project.json` não inclui o mapa;
ele vem do place aberto no Studio. Para gerar ou regenerar o mapa:

```
lune run ferramentas/gerar_mapa.luau
lune run ferramentas/checar_mapa.luau
```

Para gerar um place completo (código + mapa), que pode ser aberto direto:

```
rojo build build.project.json -o build/place.rbxl
```

## Checagens

```
pwsh scripts/checar.ps1
```

Roda as quatro checagens: `rojo build`, testes Lune, selene e stylua. Todas precisam passar antes de o Studio ver
qualquer código.

## Documentação

Comece por `docs/plano.md` (fases) e `docs/arquitetura.md` (contrato entre as partes). Os demais documentos
cobrem cada sistema: `docs/mapa-v2.md`, `docs/destruicao.md`, `docs/armas.md`, `docs/combustivel.md`,
`docs/rastejador.md`, `docs/filtro.md`, `docs/calculos.md` (todas as fórmulas), `docs/decisoes.md` e
`docs/pendencias-integracao.md`.

## Licenças de terceiros

As skills de `.claude/skills` vêm de autores diversos; as que trazem licença mantêm o arquivo `LICENSE` na própria
pasta, e as do Matt Pocock estão em `.claude/skills/LICENSE-mattpocock-skills.txt`.
