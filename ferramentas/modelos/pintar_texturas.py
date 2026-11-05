"""Assa 4 cores por tipo: modelos 3d/veiculos/texturas/<tipo>_cor<n>.png (opacos), de shell + mascara do PZ.

Uso (da raiz do projeto): python ferramentas/modelos/pintar_texturas.py
A shell do PZ tem alfa 0 onde vai a pintura (o RGB ali e so sombreado cinza-esverdeado). Aqui: pintura = cor do Config/Veiculos
(tipos[t].cor, as 4 primeiras; se faltarem, repete as do proprio tipo) x sombreado (luminancia do RGB / media das regioes pintadas).
Cromados, luzes e vidros (alfa 255) ficam como estao. Onde a mascara e transparente (UV sem uso) entra a cor chapada, sem sombreado.
"""

import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
TEX = RAIZ / "modelos 3d" / "veiculos" / "texturas"
CONFIG = RAIZ / "src" / "shared" / "Config" / "Veiculos.luau"
CORTES = Path(__file__).with_name("cortes.json")
N = 4


def cores_do_config(tipo):
    s = CONFIG.read_text(encoding="utf-8")
    i = s.index("\n\t\t%s = {" % tipo)
    j = s.index("cor = {", i) + len("cor = ")
    prof, k = 0, j
    while True:
        prof += {"{": 1, "}": -1}.get(s[k], 0)
        k += 1
        if prof == 0:
            break
    trio = re.findall(r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}", s[j:k])
    lista = [tuple(int(c) for c in t) for t in trio]
    return [lista[n % len(lista)] for n in range(N)]


def main():
    cortes = json.loads(CORTES.read_text(encoding="utf-8"))
    for tipo, cfg in cortes.items():
        if tipo.startswith("_"):
            continue
        shell = np.array(Image.open(TEX / cfg["textura"]).convert("RGBA")).astype(np.float32) / 255
        mask = np.array(Image.open(TEX / cfg["mascara"]).convert("RGBA"))
        a = shell[..., 3:4]
        pintado = a[..., 0] < 0.5
        lum = (shell[..., 0] * 0.3 + shell[..., 1] * 0.59 + shell[..., 2] * 0.11)
        ref = lum[pintado].mean()
        sombra = np.clip(lum / ref, 0.35, 1.6)
        sombra = np.where(mask[..., 3] == 0, 1.0, sombra)[..., None]
        for n, cor in enumerate(cores_do_config(tipo), 1):
            tinta = np.array(cor, dtype=np.float32) / 255
            pintura = np.clip(tinta * sombra, 0, 1)
            out = shell[..., :3] * a + pintura * (1 - a)
            Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(TEX / ("%s_cor%d.png" % (tipo, n)))
        print(tipo, "ok", cores_do_config(tipo))


if __name__ == "__main__":
    main()
