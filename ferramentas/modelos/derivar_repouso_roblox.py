"""Deriva rest_roblox_bruto.txt do manifesto.json SEM o Studio (usado quando o place oficial nao esta aberto).

Regra (verificada contra o repouso MEDIDO no Studio do Rastejador e do Wrapper, todos os ossos, erro < 0,005 studs / 1e-6 na rotacao):
  CFrame do osso no MeshPart = Tf @ matrix_local, com a rotacao multiplicada a direita por diag(-1, 1, -1)
  (Tf = escala x [x'=-x, y'=z-zc, z'=y]; ver gerar_anim_rastejador.py).
Uso:  python ferramentas/modelos/derivar_repouso_roblox.py --nome corcunda [--conferir]   (--conferir compara com o rest_roblox_bruto.txt existente)
O arquivo gerado e marcado como DERIVADO na primeira linha (gerar_anim_rastejador.py ignora linhas sem "|"). Substituir pela medida do Studio quando der.
"""

import json
import sys
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
NOME = sys.argv[sys.argv.index("--nome") + 1]
PASTA = RAIZ / "modelos 3d" / NOME


def repouso():
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))
    s = man["escala_blender_para_fbx"]
    zc = (man["dimensoes_blend"]["min"][2] + man["dimensoes_blend"]["max"][2]) / 2
    M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], dtype=float)
    Tf = np.eye(4)
    Tf[:3, :3] = s * M
    Tf[:3, 3] = -s * M @ np.array([0, 0, zc])
    C = np.diag([-1.0, 1.0, -1.0])
    out = {}
    for n, o in man["ossos"].items():
        t = Tf @ np.array(o["matrix_local"])
        r = t[:3, :3] / s @ C
        out[n] = (t[:3, 3], r)
    return out


def main():
    rep = repouso()
    if "--conferir" in sys.argv:
        pior_p = pior_r = 0.0
        for linha in (PASTA / "rest_roblox_bruto.txt").read_text(encoding="utf-8").splitlines():
            if "|" not in linha:
                continue
            n, nums = linha.split("|")
            v = [float(x) for x in nums.split(",")]
            if n not in rep:
                continue
            pior_p = max(pior_p, float(np.linalg.norm(rep[n][0] - np.array(v[:3]))))
            pior_r = max(pior_r, float(np.abs(rep[n][1] - np.array(v[3:12]).reshape(3, 3)).max()))
        print("pior erro posicao (studs):", round(pior_p, 5), "| rotacao:", round(pior_r, 6))
        return
    linhas = ["# DERIVADO do manifesto (derivar_repouso_roblox.py), nao medido no Studio"]
    for n, (p, r) in rep.items():
        linhas.append(n + "|" + ",".join(repr(float(x)) for x in (*p, *r.reshape(-1))))
    (PASTA / "rest_roblox_bruto.txt").write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print("gravado", PASTA / "rest_roblox_bruto.txt", len(rep), "ossos")


if __name__ == "__main__":
    main()
