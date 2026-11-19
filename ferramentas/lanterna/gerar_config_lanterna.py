"""Gera src/shared/Config/LanternaMalha.luau a partir de modelos 3d/PsxFlashLights/roblox/manifesto.json (montar_lanterna.py +
enviar_lanterna.py). Uso (da raiz): python -I ferramentas/lanterna/gerar_config_lanterna.py
"""

import json
import shutil
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
MAN = RAIZ / "modelos 3d" / "PsxFlashLights" / "roblox" / "manifesto.json"
SAIDA = RAIZ / "src" / "shared" / "Config" / "LanternaMalha.luau"


def n(x):
    return repr(round(float(x), 5))


def lv(v):
    return "{ " + ", ".join(n(x) for x in v) + " }"


def main():
    m = json.loads(MAN.read_text(encoding="utf-8"))
    L = [
        "-- Malha da lanterna de peito (pacote PsxFlashLights: " + m["modelo"] + ", " + m["variacao"] + ").",
        "-- GERADO por ferramentas/lanterna/gerar_config_lanterna.py a partir de modelos 3d/PsxFlashLights/roblox/manifesto.json. Não editar à mão.",
        "-- Eixos do Roblox, studs, origem = meio da face de TRÁS do corpo (encosta no peito), lente para -Z. Sem `modelo` = blocos.",
        "return {",
        f"\tmodelo = {m['assetIdModel']}, -- Model (FBX) com as MeshParts Corpo, Lente, Botao, Indicador",
        f'\ttextura = "rbxassetid://{m["assetIdImage"]}",',
        "\t-- o Roblox gira a malha do FBX 180° em Y ao importar (medido no Studio 2026-11-17; igual aos carros,",
        "\t-- VeiculoModelo.VIRAR_IMPORTACAO): cada MeshPart é girada isto em volta do próprio centro para a lente voltar a -Z",
        "\tgiroImportacao = 180,",
        "\tpartes = {",
    ]
    for nome, p in m["partes"].items():
        t = [max(x, 0.001) for x in p["tamanho"]]
        L.append(f"\t\t{nome} = {{ tamanho = {lv(t)}, centro = {lv(p['centro'])} }},")
    L.append("\t},")
    le = m["lente"]
    L.append(f"\tlente = {{ centro = {lv(le['centro'])}, normal = {lv(le['normal'])}, raio = {n(le['raio'])} }},")
    b = dict(m["botao"])
    if isinstance(b["eixo"], str):  # "Y" -> (0, 1, 0)
        b["eixo"] = {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}[b["eixo"].upper()]
    L.append(
        f"\tbotao = {{ eixo = {lv(b['eixo'])}, curso = {n(b['curso'])} }}, -- exportado DESLIGADO; ligado = +curso no eixo"
    )
    L.append("}")
    SAIDA.write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")
    if shutil.which("stylua"):
        subprocess.run(["stylua", str(SAIDA)], cwd=RAIZ)
    print("gravado", SAIDA)


if __name__ == "__main__":
    main()
