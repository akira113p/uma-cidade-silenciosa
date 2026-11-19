"""Le ferramentas/audio/enviados.json e escreve src/shared/Config/SonsPSX.luau (gerado). Sem id = lista vazia
(Config/Sons.luau cai nos ids antigos). Uso (da raiz):  python ferramentas/audio/gerar_config_audio.py
"""

import json
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
REGISTRO = Path(__file__).resolve().parent / "enviados.json"
SAIDA = RAIZ / "src" / "shared" / "Config" / "SonsPSX.luau"
SUPERFICIES = ["Concrete", "Dirt", "Grass", "Gravel", "Stairs", "Stone", "Wood", "Metal"]
AMBIENTES = ["Still", "Distant", "Veil", "Hollow", "Blur", "Faded"]


def main():
    enviados = json.loads(REGISTRO.read_text(encoding="utf-8")) if REGISTRO.exists() else {}
    passos = {s: [] for s in SUPERFICIES}
    ambiente = {}
    for nome, reg in sorted(enviados.items()):
        if not reg.get("assetId"):
            continue
        m = re.fullmatch(r"passos/(\w+?)_(\d+)\.ogg", nome)
        if m and m.group(1) in passos:
            passos[m.group(1)].append((int(m.group(2)), reg["assetId"]))
            continue
        m = re.fullmatch(r"ambiente/(\w+)\.ogg", nome)
        if m and m.group(1) in AMBIENTES:
            ambiente[m.group(1)] = reg["assetId"]
    linhas = [
        "-- GERADO por ferramentas/audio/gerar_config_audio.py a partir de ferramentas/audio/enviados.json. NAO EDITAR.",
        "-- Passos e ambiente do CAPTNPHANTOM (40 Free PSX Footsteps, PSX Ambient Pack). Lista vazia = ainda nao enviado",
        "-- (Config/Sons.luau usa os ids antigos). Contrato: docs/audio-psx.md.",
        "",
        "return {",
        "\tpassos = {",
    ]
    for s in SUPERFICIES:
        ids = ", ".join(str(i) for _, i in sorted(passos[s]))
        linhas.append("\t\t%s = { %s }," % (s, ids) if ids else "\t\t%s = {}," % s)
    linhas.append("\t},")
    achados = [a for a in AMBIENTES if a in ambiente]
    if achados:
        linhas.append("\tambiente = {")
        linhas += ["\t\t%s = %d," % (a, ambiente[a]) for a in achados]
        linhas.append("\t},")
    else:
        linhas.append("\tambiente = {},")
    linhas += ["}", ""]
    SAIDA.write_text("\n".join(linhas), encoding="utf-8", newline="\n")
    print("escrito", SAIDA, "(%d passos, %d ambientes com id)" % (sum(len(v) for v in passos.values()), len(ambiente)))


if __name__ == "__main__":
    main()
