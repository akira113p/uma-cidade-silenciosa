"""Gera src/shared/Config/PersonagensMalhas.luau a partir dos manifestos de modelos 3d/personagens/<id>/<id>.json.

Uso (da raiz):  python ferramentas/modelos/gerar_config_personagens.py

Formato (docs/personagens.md, Parte M; quem le e shared/PersonagemVisual + Regras/Personagens.malhasCompletas):
  [id] = { modelo = false|"rbxassetid://N", textura = false|"rbxassetid://N", alturaTotalStuds = N,
           partes = { [nomeR15] = { meshId = false|"rbxassetid://N", tamanhoNativo = { x, y, z }, centroMontagem = { x, y, z } } } }
tamanhoNativo e centroMontagem usam os MESMOS eixos do Roblox (ponto = (-x, z, y) do Blender; frente -Z; o lado esquerdo do
personagem fica em -X, o direito em +X), em studs; centroMontagem tem x/z a partir do centro do corpo e y a partir dos pes (= 0).
Ids de envio: NADA e enviado por esta ferramenta. Quando a conta puder enviar, gravar em
`modelos 3d/personagens/<id>/enviados.json`:
  { "modelo": 123, "textura": 456, "meshIds": { "Head": 789, ... 15 pecas } }
e rodar este script de novo: ele preenche modelo/textura/meshId (sem esse arquivo tudo fica `false`).
Personagens cuja licenca no manifesto comeca com "desconhecida" ficam FORA do config (so um comentario avisa).
"""

import json
import shutil
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "personagens"
SAIDA = RAIZ / "src" / "shared" / "Config" / "PersonagensMalhas.luau"
PECAS = [
    "Head",
    "UpperTorso",
    "LowerTorso",
    "LeftUpperArm",
    "LeftLowerArm",
    "LeftHand",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperLeg",
    "LeftLowerLeg",
    "LeftFoot",
    "RightUpperLeg",
    "RightLowerLeg",
    "RightFoot",
]


def n(x):
    r = ("%.4f" % x).rstrip("0").rstrip(".")
    return "0" if r in ("-0", "") else r


def aid(v):
    return '"rbxassetid://%d"' % int(v) if v else "false"


def main():
    entradas = []
    fora = []
    for pasta in sorted(p for p in PASTA.iterdir() if p.is_dir()) if PASTA.exists() else []:
        mf = pasta / (pasta.name + ".json")
        if not mf.exists():
            continue
        m = json.loads(mf.read_text(encoding="utf-8"))
        if str(m.get("licenca", "")).startswith("desconhecida"):
            fora.append(m["id"])
            continue
        env_arq = pasta / "enviados.json"
        env = json.loads(env_arq.read_text(encoding="utf-8")) if env_arq.exists() else {}
        entradas.append((m, env))
    entradas.sort(key=lambda e: e[0]["id"])

    linhas = [
        "-- Malhas dos personagens (docs/personagens.md, Parte M).",
        "-- GERADO por ferramentas/modelos/gerar_config_personagens.py a partir de modelos 3d/personagens/<id>/<id>.json",
        "-- (+ enviados.json, se existir). NAO editar a mao: rode o script de novo.",
        "--",
        "-- Estrutura (uma entrada por id de Config/Personagens):",
        "--   [id] = {",
        '--       modelo = false | "rbxassetid://...",   -- id do Model/FBX inteiro (informativo; false = nada enviado)',
        '--       textura = false | "rbxassetid://...",  -- atlas recortado (<= 256 px), vai no TextureID de cada MeshPart',
        "--       alturaTotalStuds = N,                  -- altura do boneco montado, pes em y = 0",
        "--       partes = {                             -- as 15 pecas R15, todas obrigatorias",
        '--           [nomeR15] = { meshId = false | "rbxassetid://...", tamanhoNativo = { x, y, z }, centroMontagem = { x, y, z } },',
        "--       },",
        "--   }",
        "-- Eixos de tamanhoNativo e centroMontagem: os do Roblox, ponto = (-x, z, y) do Blender (medido). Frente = -Z; o lado esquerdo",
        "-- do personagem fica em -X (LeftUpperArm tem centroMontagem.x < 0) e o direito em +X. x/z a partir do centro do corpo, y dos pes.",
        '-- O visual "malhas" so vale com modelo, textura e as 15 partes preenchidos (Regras/Personagens.malhasCompletas);',
        '-- qualquer falta cai em "bloco". Escala unica para o conjunto: k = altura do R15 / alturaTotalStuds; cada MeshPart recebe',
        "-- Size = tamanhoNativo * k e fica em centroMontagem * k relativo aos pes (nao se estica peca a peca).",
        "-- NADA foi enviado ao Roblox: todos os ids estao `false` ate a conta liberar (Open Cloud 403 User is moderated).",
    ]
    if fora:
        linhas.append(
            "-- FORA do config por licenca desconhecida (confirmar origem com o usuario, ver o manifesto): %s." % ", ".join(fora)
        )
    linhas.append("")
    linhas.append("return {")
    for m, env in entradas:
        mesh_ids = env.get("meshIds") or {}
        linhas.append("\t%s = {" % m["id"])
        linhas.append("\t\tmodelo = %s," % aid(env.get("modelo")))
        linhas.append("\t\ttextura = %s," % aid(env.get("textura")))
        linhas.append("\t\talturaTotalStuds = %s," % n(m["alturaTotalStuds"]))
        linhas.append("\t\tpartes = {")
        for p in PECAS:
            t = m["pecas"][p]["tamanhoNativo"]
            c = m["pecas"][p]["centroMontagem"]
            linhas.append(
                "\t\t\t%s = { meshId = %s, tamanhoNativo = { %s, %s, %s }, centroMontagem = { %s, %s, %s } },"
                % (p, aid(mesh_ids.get(p)), n(t[0]), n(t[1]), n(t[2]), n(c[0]), n(c[1]), n(c[2]))
            )
        linhas.append("\t\t},")
        linhas.append("\t},")
    linhas.append("}")
    SAIDA.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    stylua = shutil.which("stylua")
    if stylua:
        subprocess.run([stylua, str(SAIDA)], check=False)
    print(SAIDA, "-", len(entradas), "personagem(ns); fora por licenca:", fora)


if __name__ == "__main__":
    main()
