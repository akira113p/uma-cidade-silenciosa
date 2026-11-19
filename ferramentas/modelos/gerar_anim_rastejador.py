"""Converte as animacoes do Blender (anim_blender.json) em Bone.Transform do Roblox -> anim_roblox.json.

Uso (da raiz):  python ferramentas/modelos/gerar_anim_rastejador.py [--nome rastejador|wrapper]
Entradas em modelos 3d/rastejador/: manifesto.json, anim_blender.json (exportar_rastejador.py) e rest_roblox_bruto.txt
(uma linha por osso: "Nome|x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22" = CFrame do osso (Bone.TransformedWorldCFrame sem Transform)
relativo ao MeshPart, medido no Studio depois de importar o FBX enviado; ver docs/rastejador.md §3.2).

Matematica (docs/rastejador.md "Estado"): no Roblox, mundo(osso) = mundo(pai) * Bone.CFrame * Transform. Com Rr = repouso do osso no Roblox
e G = deformacao de mundo do osso (pose * repouso^-1) em Blender, passada ao Roblox por Tf (Blender -> espaco do MeshPart:
x' = -x, y' = z, z' = y, vezes a escala, recentrado na altura do meio):
    Transform = Rr^-1 * Gr(pai)^-1 * Gr(osso) * Rr
Nao depende de os eixos dos ossos baterem com os do Blender.
"""

import json
import math
import sys
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
NOME = sys.argv[sys.argv.index("--nome") + 1] if "--nome" in sys.argv else "rastejador"  # pasta em modelos 3d/
PASTA = RAIZ / "modelos 3d" / NOME
MAX_QUADROS = 30  # keyframes por acao (contrato): passo uniforme = ceil(quadros / MAX)


def quat_mat(q):
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
    return x, y, z, w  # ordem do Roblox/Luau: x, y, z, w


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

    rr = {}
    for linha in (PASTA / "rest_roblox_bruto.txt").read_text(encoding="utf-8").splitlines():
        if "|" not in linha:
            continue
        nome, nums = linha.split("|")
        v = [float(x) for x in nums.split(",")]
        rr[nome] = mat4(np.array(v[3:12]).reshape(3, 3), v[:3])

    ossos = man["ossos"]
    ausentes = [n for n in ossos if n not in rr]
    if ausentes:  # ossos auxiliares (IK) que o FBX nao leva ao Roblox
        print("ignorando ossos sem equivalente no Roblox:", ausentes)
        ossos = {n: o for n, o in ossos.items() if n in rr}
        for o in ossos.values():
            if o["pai"] not in ossos:
                o["pai"] = None
    rest_b = {n: np.array(o["matrix_local"]) for n, o in ossos.items()}
    ordem = []  # pais antes dos filhos
    def visita(n):
        if n not in ordem:
            if ossos[n]["pai"]:
                visita(ossos[n]["pai"])
            ordem.append(n)
    for n in ossos:
        visita(n)

    # O centro do MeshPart no Roblox e o centro da caixa da malha, que nao precisa estar em x=y=0 no Blender (MonstroPS1 com os
    # bracos baixados: 0,151 stud em x, medido 2026-11-14). Acha o deslocamento pelos ossos raiz e corrige o Tf.
    raizes = [n for n in ossos if not ossos[n]["pai"]]
    desl = np.mean([rr[n][:3, 3] - (Tf @ rest_b[n])[:3, 3] for n in raizes], axis=0)
    Tf[:3, 3] += desl
    Tfi = np.linalg.inv(Tf)
    print("deslocamento do centro do MeshPart (studs):", np.round(desl, 4))
    # verificacao: o repouso Blender passado ao Roblox tem a mesma posicao do medido?
    erro_pos = max(np.linalg.norm((Tf @ rest_b[n])[:3, 3] - rr[n][:3, 3]) for n in ossos)

    saida = {}
    for nome, a in anim.items():
        total = a["quadros"]
        passo = math.ceil(total / MAX_QUADROS)
        idx = list(range(0, total, passo))
        if idx[-1] != total - 1:
            idx.append(total - 1)
        # quadros dos eventos (impacto, soltar...) entram sempre: o pico do golpe nao some na decimacao
        for t in (man.get("eventos") or {}).get(nome, {}).values():
            q = min(max(int(round(t * a["fps"])), 0), total - 1)
            if q not in idx:
                idx.append(q)
        idx.sort()
        frames = []
        for i in idx:
            f = a["frames"][i]
            P = {}
            G = {}
            for n in ordem:
                b = f[n]
                bm = mat4(quat_mat(b["quat"]), b["loc"])
                pai = ossos[n]["pai"]
                if pai:
                    P[n] = P[pai] @ (np.linalg.inv(rest_b[pai]) @ rest_b[n]) @ bm
                else:
                    P[n] = rest_b[n] @ bm  # raiz: o pai e o objeto armature (identidade)
                G[n] = P[n] @ np.linalg.inv(rest_b[n])
            Gr = {n: Tf @ G[n] @ Tfi for n in ordem}
            osso = {}
            for n in ordem:
                pai = ossos[n]["pai"]
                gp = np.linalg.inv(Gr[pai]) if pai else np.eye(4)
                t = np.linalg.inv(rr[n]) @ gp @ Gr[n] @ rr[n]
                qx, qy, qz, qw = mat_quat(t[:3, :3])
                osso[n] = [round(float(x), 5) for x in (*t[:3, 3], qx, qy, qz, qw)]
            frames.append(osso)
        saida[nome] = dict(
            fps=a["fps"],
            ciclica=a["ciclica"],
            tempos=[round(i / a["fps"], 4) for i in idx],
            duracao=round((total - 1) / a["fps"], 4),
            ossos=ordem,
            frames=frames,
        )
    (PASTA / "anim_roblox.json").write_text(json.dumps(saida, separators=(",", ":")), encoding="utf-8")
    print("erro de posicao do repouso (studs):", round(float(erro_pos), 5))
    for n, a in saida.items():
        print(n, "keyframes", len(a["frames"]), "duracao", a["duracao"])


if __name__ == "__main__":
    main()
