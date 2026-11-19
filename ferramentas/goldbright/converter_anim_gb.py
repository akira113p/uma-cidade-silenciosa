"""anim_blender.json -> anim_roblox.json (Bone.Transform) para os grupos do Gold Bright.

Uso (da raiz):  python -I ferramentas/goldbright/converter_anim_gb.py "modelos 3d/gold-bright/roblox/<grupo>"

Mesma matemática de gerar_anim_rastejador.py + derivar_repouso_roblox.py (repouso do osso no Roblox DERIVADO do manifesto, regra
verificada contra o medido no Studio para o Rastejador e o Wrapper; AQUI AINDA NÃO MEDIDO NO STUDIO):
    CFrame do osso no MeshPart = Tf @ matrix_local, rotação x diag(-1, 1, -1);  Tf = escala x [x'=-x, y'=z-zc, z'=y]
    Transform = Rr^-1 * Gr(pai)^-1 * Gr(osso) * Rr
Diferença: poses ESPARSAS. Cada ação só emite os ossos que ela anima + seus ancestrais; ancestral não animado sai com peso 0
(identidade). Assim o clipe "mãos" e o clipe "arma", que tocam juntos no jogo original, não brigam no Roblox.
Máx. 30 keyframes por ação (contrato do projeto).
"""

import json
import math
import sys
from pathlib import Path

import numpy as np

PASTA = Path(sys.argv[1])
MAX_QUADROS = 30


def quat_mat(q):  # (w, x, y, z)
    w, x, y, z = q
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
    w, x, y, z = w / n, x / n, y / n, z / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def mat_quat(r):
    t = r[0, 0] + r[1, 1] + r[2, 2]
    if t > 0:
        s = math.sqrt(t + 1) * 2
        w, x, y, z = s / 4, (r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s
    elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
        s = math.sqrt(1 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
        w, x, y, z = (r[2, 1] - r[1, 2]) / s, s / 4, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s
    elif r[1, 1] > r[2, 2]:
        s = math.sqrt(1 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
        w, x, y, z = (r[0, 2] - r[2, 0]) / s, (r[0, 1] + r[1, 0]) / s, s / 4, (r[1, 2] + r[2, 1]) / s
    else:
        s = math.sqrt(1 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
        w, x, y, z = (r[1, 0] - r[0, 1]) / s, (r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, s / 4
    return x, y, z, w


def mat4(r, p):
    m = np.eye(4)
    m[:3, :3] = r
    m[:3, 3] = p
    return m


def main():
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))
    anim = json.loads((PASTA / "anim_blender.json").read_text(encoding="utf-8"))
    s = man["escala_blender_para_fbx"]
    zc = (man["dimensoes_blend"]["min"][2] + man["dimensoes_blend"]["max"][2]) / 2
    M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], dtype=float)
    Tf = np.eye(4)
    Tf[:3, :3] = s * M
    Tf[:3, 3] = -s * M @ np.array([0, 0, zc])
    Tfi = np.linalg.inv(Tf)
    C = np.diag([-1.0, 1.0, -1.0])

    ossos = man["ossos"]
    rest_b = {n: np.array(o["matrix_local"]) for n, o in ossos.items()}
    rr = {}
    linhas = ["# DERIVADO do manifesto (converter_anim_gb.py), nao medido no Studio"]
    for n, m in rest_b.items():
        t = Tf @ m
        r = t[:3, :3] / s @ C
        rr[n] = mat4(r, t[:3, 3])
        linhas.append(n + "|" + ",".join(repr(float(x)) for x in (*t[:3, 3], *r.reshape(-1))))
    (PASTA / "rest_roblox_bruto.txt").write_text("\n".join(linhas) + "\n", encoding="utf-8")

    ordem = []

    def visita(n):
        if n not in ordem:
            if ossos[n]["pai"]:
                visita(ossos[n]["pai"])
            ordem.append(n)

    for n in ossos:
        visita(n)

    saida = {}
    for nome, a in anim.items():
        animados = set(a["animados"])
        emitir = set(animados)
        for n in animados:  # ancestrais (peso 0 se não animados)
            p = ossos[n]["pai"]
            while p:
                emitir.add(p)
                p = ossos[p]["pai"]
        total = a["quadros"]
        passo = math.ceil(total / MAX_QUADROS)
        idx = list(range(0, total, passo))
        if idx[-1] != total - 1:
            idx.append(total - 1)
        frames = []
        for i in idx:
            f = a["frames"][i]
            P, G = {}, {}
            for n in ordem:
                b = f.get(n)
                bm = mat4(quat_mat(b["quat"]), b["loc"]) if b else np.eye(4)
                pai = ossos[n]["pai"]
                P[n] = (P[pai] @ (np.linalg.inv(rest_b[pai]) @ rest_b[n]) @ bm) if pai else rest_b[n] @ bm
                G[n] = P[n] @ np.linalg.inv(rest_b[n])
            Gr = {n: Tf @ G[n] @ Tfi for n in ordem}
            osso = {}
            for n in ordem:
                if n not in emitir:
                    continue
                pai = ossos[n]["pai"]
                gp = np.linalg.inv(Gr[pai]) if pai else np.eye(4)
                t = np.linalg.inv(rr[n]) @ gp @ Gr[n] @ rr[n]
                qx, qy, qz, qw = mat_quat(t[:3, :3])
                osso[n] = [round(float(x), 5) for x in (*t[:3, 3], qx, qy, qz, qw)]
            frames.append(osso)
        lista = [n for n in ordem if n in emitir]
        saida[nome] = dict(
            fps=a["fps"],
            ciclica=a["ciclica"],
            tempos=[round(i / a["fps"], 4) for i in idx],
            duracao=round((total - 1) / a["fps"], 4),
            ossos=lista,
            pesos={n: (1 if n in animados else 0) for n in lista},
            frames=frames,
        )
    (PASTA / "anim_roblox.json").write_text(json.dumps(saida, separators=(",", ":")), encoding="utf-8")
    print(PASTA.name, "acoes:", len(saida), "| pior |Transform| em repouso aprox. (conferir):",
          round(max(abs(v) for a in saida.values() for fr in a["frames"][:1] for o in fr.values() for v in o[:3]), 3))


if __name__ == "__main__":
    main()
