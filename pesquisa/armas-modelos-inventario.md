# Inventário das 11 armas em `modelos 3d/_ps2/`

Levantamento somente leitura, 2026-11-05. Fontes: manifesto `<pasta>.json`, listagem de `modelos 3d/_ps2/<pasta>/` e listagem de `modelos 3d/armas/<original>/` (pasta `source` e `textures`). Nenhum arquivo existente foi alterado.

Convenções: números no formato do JSON (ponto decimal). "Posição" = ordem do valor em `dimensoes_m` (1ª, 2ª, 3ª). "Não consta" = dado ausente nos arquivos lidos.

| Arma | Tris antes → depois (teto 1500) | Malhas (nome, tris) | Materiais → textura (px) | Ossos / armadura | dimensoes_m | Maior eixo (valor, posição) | Arquivos na pasta `_ps2` | Source na pasta original | Licença / readme |
|---|---|---|---|---|---|---|---|---|---|
| AK74 | 522 → 522 | 1: `SM_AK-74` (522) | `M_AK-74` → `T_AK74.png` (256×256) | não | [0.046, 0.9, 0.254] | 0.9 (2ª) | `AK74.blend`, `AK74.json`, `T_AK74.png` | `source/PSX_AK-74.glb` (+ `textures/T_AK74_0.png`) | não consta |
| AR15 | 844 → 844 | 1: `Cube.002` (844) | `Material` → `lowresgun1.png.002` (256×256); `glass` → null (sem textura) | não | [0.05, 0.9, 0.243] | 0.9 (2ª) | `AR15.blend`, `AR15.json`, `lowresgun1.png` | `source/PS1 ar15.fbx` (+ `textures/lowresgun1.png`) | não consta |
| Carabina_M5 | 24613 → **2292 (acima do teto)** | 21 (lista na obs. 1) | 6 materiais (`h-190`, `polymer`, `stell`, `brass`, `polycarbonate`, `copper`) → `cor_*.png`; `texturas` vazio, tamanho não consta | não | [0.9, 0.092, 0.365] | 0.9 (1ª) | `Carabina_M5.blend`, `Carabina_M5.blend1`, `Carabina_M5.json`, `cor_brass.png`, `cor_copper.png`, `cor_h_190.png`, `cor_polycarbonate.png`, `cor_polymer.png`, `cor_stell.png` | `source/m5 scw.blend` (sem pasta `textures`) | não consta |
| Escopeta | 532 → 532 | 1: `Body` (532) | `Material.002` → `shotty_C.png.001` (256×256) | não | [0.099, 0.9, 0.227] | 0.9 (2ª) | `Escopeta.blend`, `Escopeta.blend1`, `Escopeta.json`, `shotty_C.png` | `source/Shottytest.obj` (+ `textures/shotty_C.png`, `shotty_N.png`, `shotty_RM.png`) | não consta |
| Escopeta_M1912 | 1361 → 1361 | 8: `v_pump` (264), `v_trigger` (42), `w_bolt` (12), `v_gun` (608), `v_bolt` (9), `w_pump` (86), `w_trigger` (26), `w_gun` (314) | `m_m12_view` → `t_m1912_view.png.001`; `m_m12_world` → `t_m1912_world.png.001` (ambas 256×256) | não | [0.042, 0.9, 0.37] | 0.9 (2ª) | `Escopeta_M1912.blend`, `Escopeta_M1912.blend1`, `Escopeta_M1912.json`, `t_m1912_view.png`, `t_m1912_world.png` | `source/sketchfab_m12.fbx` (+ `textures/t_m1912_view.png`, `t_m1912_world.png`) | não consta |
| Faca | 46 → 46 | 1: `ps1-meyers-knife-a` (46) | `Material #26` → `Map__2.png` (128×32) | não | [0.9, 0.195, 0.046] | 0.9 (1ª) | `Faca.blend`, `Faca.json`, `Map__2.png` | `source/ps1-meyers-knife-a/ps1-meyers-knife-a.fbx` (+ `ps1-meyers-knife-tex.png`); `source/ps1-meyers-knife-a.rar` (conteúdo não listado) | não consta |
| Lanca_Foguetes | 120 → 120 | 2: `rocket` (36), `rpg2` (84) | `Material #26` e `Material #25` → `Map__1.png` (256×128) | não | [0.09, 0.9, 0.258] | 0.9 (2ª) | `Lanca_Foguetes.blend`, `Lanca_Foguetes.json`, `Map__1.png` | `source/1 ck game/rpg2.fbx` (+ `RPG2_tex.png`); `source/1 ck game.rar` (conteúdo não listado) | não consta |
| Machado | 430 → 430 | 1: `Axe` (430) | `AxeMaterial` → `AxeTexture.png.001` (256×256) | não | [0.179, 0.9, 0.564] | 0.9 (2ª) | `Machado.blend`, `Machado.json`, `AxeTexture.png` | `source/Axe/Axe.fbx` (+ `AxeTexture.png`); `source/Axe.zip` (Axe.fbx, AxeTexture.png) | não consta (zip sem readme) |
| Pe_de_Cabra | 158 → 158 | 1: `crowbar` (158) | `Material.001` → `crow_BaseColor.png.001` (256×256) | não | [0.9, 0.033, 0.16] | 0.9 (1ª) | `Pe_de_Cabra.blend`, `Pe_de_Cabra.json`, `crow_BaseColor.png` | `source/melee/melee/crowbar.fbx` (+ 6 PNG em `Textures/`); `source/melee.zip` | não consta (zip sem readme) |
| Pistola | 64 → 64 | 1: `Handgun` (64) | `Handgun` → `T_Handgun.png.001` (128×128) | não | [0.9, 0.089, 0.56] | 0.9 (1ª) | `Pistola.blend`, `Pistola.json`, `T_Handgun.png` | `source/SM_Handgun.fbx` (+ `textures/T_Handgun.png`) | não consta |
| Pistola_Beretta | 548 → 548 | 7: `trigger` (28), `main` (381), `holder` (48), `plane` (6), `side` (53), `ammo` (12), `bullet` (20) | 7 materiais, um por malha, todos 256×256: `trigger__1_.png`, `main__9_.png`, `holder__2_.png`, `plane__1_.png`, `side__3_.png`, `ammo__3_.png`, `bullet__2_.png` | não | [0.9, 0.704, 0.576] | 0.9 (1ª) | `Pistola_Beretta.blend`, `Pistola_Beretta.blend1`, `Pistola_Beretta.json`, + 7 PNG (mesmos nomes acima) | `source/Beretta 92FS Police Special.fbx` (+ 7 PNG em `textures/`, com parênteses, ex.: `main_(9).png`) | não consta |

## Observações

**Problemas**

1. **Carabina_M5 acima do teto.** 2292 tris depois (teto 1500), reduzido de 24613. São 21 malhas: `m5scw upper` (134), `m5scw trigga` (22), `m5scw stock` (68), `m5scw selector` (40), `m5scw mag catch R` (12), `m5scw mag catch L` (4), `m5scw lower` (190), `m5scw iron sights` (102), `m5scw handguard` (972), `m5scw grip` (36), `m5scw flash hider` (80), `m5scw dust cover` (62), `m5scw charging handle` (78), `m5scw bolt catch R` (4), `m5scw bolt catch L` (8), `m5scw bolt` (123), `m5scw 10.3in barrel ` (65, nome com espaço no fim), `55645 case` (20), `55645 ar15 30rnd mag empty (pmag)` (98), `55645 ar15 30rnd mag (pmag)` (150), `55645` (24). A soma confere com 2292. `handguard` sozinho tem 972 tris (42%).
2. **Textura citada com sufixo que não existe na pasta.** O manifesto cita `nome.png.001` (ou `.002`), e a pasta tem `nome.png`. Afeta AR15, Escopeta, Escopeta_M1912 (duas texturas), Machado, Pe_de_Cabra e Pistola. Não consta a causa. Conferir o nome dentro do `.blend` antes de usar o manifesto como referência.
3. **Carabina_M5 sem textura no manifesto.** `texturas` está vazio. Os 6 materiais apontam para `cor_*.png` (3 a 4 KB cada), e o tamanho em px não consta.
4. **AR15:** material `glass` com `null` (sem textura). Malha com nome genérico `Cube.002`.
5. **Texturas não quadradas:** Faca (`Map__2.png`, 128×32) e Lanca_Foguetes (`Map__1.png`, 256×128). Em Lanca_Foguetes, dois materiais usam a mesma textura.
6. **Pistola_Beretta:** 7 texturas de 256×256, uma por malha. É o maior número de texturas do grupo.
7. **Escopeta_M1912:** as malhas têm prefixos `v_` e `w_`, e os materiais se chamam `m_m12_view` e `m_m12_world`. A função dos prefixos não consta no manifesto.

**Eixo e escala (só o que o JSON permite)**

- Em todas as 11, o maior valor de `dimensoes_m` é 0.9, e `limitado_a_5m` é false em todas.
- O 0.9 está na 2ª posição em 6 armas (AK74, AR15, Escopeta, Escopeta_M1912, Lanca_Foguetes, Machado) e na 1ª em 5 (Carabina_M5, Faca, Pe_de_Cabra, Pistola, Pistola_Beretta).
- O JSON não diz qual eixo do modelo corresponde a cada posição, nem onde fica a boca do cano. A direção do cano não foi determinada.
- `normalizacao.altura_original` × `escala` dá o 3º valor de `dimensoes_m` em 10 das 11 armas, com arredondamento. Carabina_M5 não bate: 0.1405 × 2.60956 = 0.3666, e o manifesto diz 0.365. O 3º valor é sempre menor que 0.9, então o campo `altura` nunca é o maior eixo.
- Escala de normalização: de 0.019 (Lanca_Foguetes) a 4.5439 (Pistola).

**Ossos e armadura**

- Nenhuma das 11 tem armadura nem grupo de ossos (`armaduras` vazio e `ossos_grupos` 0 em todas as malhas).

**Triângulos**

- Só a Carabina_M5 mudou de contagem (24613 → 2292). Nas demais, antes = depois. A maior fora da Carabina é a Escopeta_M1912, com 1361, dentro do teto.

**Licença e readme**

- Busca por `licen`, `readme`, `leia`, `.txt`, `.md`, `.pdf`, `credit` e `autor` em `modelos 3d/armas/`: nenhum resultado. Autor e licença: não consta para as 11.
- Os zips `Machado/source/Axe.zip` e `Pé de Cabra/source/melee.zip` foram listados, e não têm readme nem licença.
- Os `.rar` de Faca (`ps1-meyers-knife-a.rar`) e Lança-Foguetes (`1 ck game.rar`) não foram listados, porque não há ferramenta de .rar instalada (unrar, 7z e bsdtar ausentes). Conteúdo não consta.

**Arquivos extras**

- `.blend1` (backup do Blender) existe em Carabina_M5, Escopeta, Escopeta_M1912 e Pistola_Beretta. O manifesto não os usa.
- A pasta `_ps2` traz só a textura citada no manifesto. As originais têm mais arquivos (ex.: Pé de Cabra tem 6 PNG em `Textures/`, Escopeta tem `shotty_N.png` e `shotty_RM.png`).
