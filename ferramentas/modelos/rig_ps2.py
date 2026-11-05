# Rig dos monstros (depois do filtro_ps2.py): cria o esqueleto ajustado à malha e os pesos de skinning.
# Lê modelos 3d/_ps2/<Nome>/<Nome>.blend e grava <Nome>_rig.blend + <Nome>_rig.json na mesma pasta. Nada vai ao Roblox.
#
#   blender -b --factory-startup -P ferramentas/modelos/rig_ps2.py -- --nome Corcunda
#
# Tipos: "biped" (esqueleto humanoide: Hips/Spine/Chest/Neck/Head + braços e pernas .L/.R), "quadrupede" (cervo: coluna,
# pescoço, cauda, 4 patas), "pecas" (um osso por peça rígida), "existente" (já tem esqueleto: só limpa e limita pesos).
# Pesos: inverso da distância ao osso (potência 4), no máximo 4 influências por vértice (limite do Roblox), normalizados.
# Convenção: o personagem olha para "frente"; .L é a esquerda dele (Z × frente), como no Blender.

import json
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PS2 = os.path.join(REPO, "modelos 3d", "_ps2")
MAX_INFLUENCIAS = 4  # limite de skinning do Roblox (por vértice)
POTENCIA = 4.0

# frente = direção XY para onde o monstro olha (conferida nos renders de frente/lado).
# hips/sho/neck = alturas como fração da altura; sh_lat = distância lateral do ombro (m);
# mao = (lateral, adiante, fração de altura) do pulso, ponto de partida que a malha corrige.
def _mumbler_ossos():
    o = [("Hips", None, (0, -0.70, 1.05), (0, -0.45, 1.20)),
         ("Spine", "Hips", (0, -0.45, 1.20), (0, -0.05, 1.50)),
         ("Chest", "Spine", (0, -0.05, 1.50), (0, 0.45, 1.75)),
         ("Neck", "Chest", (0, 0.45, 1.75), (0, 0.50, 1.40)),
         ("Head", "Neck", (0, 0.50, 1.40), (0, 0.50, 0.65))]
    for nome, x in (("L", -1), ("R", 1)):
        o += [(f"UpperArm.{nome}", "Chest", (0.30 * x, 0.0, 1.20), (0.25 * x, 0.05, 0.85)),
              (f"LowerArm.{nome}", f"UpperArm.{nome}", (0.25 * x, 0.05, 0.85), (0.10 * x, 0.25, 0.30)),
              (f"Hand.{nome}", f"LowerArm.{nome}", (0.10 * x, 0.25, 0.30), (0.08 * x, 0.35, 0.02)),
              (f"UpperLeg.{nome}", "Hips", (0.10 * x, -0.60, 0.95), (0.10 * x, -0.68, 0.85)),
              (f"LowerLeg.{nome}", f"UpperLeg.{nome}", (0.10 * x, -0.68, 0.85), (0.10 * x, -0.72, 0.75)),
              (f"Foot.{nome}", f"LowerLeg.{nome}", (0.10 * x, -0.72, 0.75), (0.10 * x, -0.55, 0.72))]
    return o


MUMBLER_OSSOS = _mumbler_ossos()

MODELOS = {
    "Corcunda": dict(tipo="biped", frente=(1, 0), hips=0.48, sho=0.78, neck=0.86, sh_lat=0.30, mao=(0.42, 0.05, 0.46)),
    "Esfolado": dict(tipo="biped", frente=(0, -1), hips=0.52, sho=0.72, neck=0.80, sh_lat=0.30, mao=(0.45, 0.35, 0.40)),
    "Urchin": dict(tipo="biped", frente=(0, -1), hips=0.48, sho=0.80, neck=0.88, sh_lat=0.22, mao=(0.50, 0.85, 0.55)),
    "Rastejador": dict(tipo="biped", frente=(0, -1), hips=0.45, sho=0.65, neck=0.72, sh_lat=0.35, mao=(1.70, 0.90, 0.65), mao_extremo=True),
    "Espreitador": dict(tipo="quadrupede", frente=(0, -1), corpo=0.55),
    "Pernalta": dict(tipo="pecas", frente=(0, -1)),
    "Carniceiro": dict(tipo="existente"),
    "Florescida": dict(tipo="existente"),
    "MonstroPS1": dict(tipo="existente"),
    # O esqueleto original do Mumbler tem os 21 ossos colapsados num ponto: rig manual (nomes do biped, para a animação
    # achar os papéis), em metros, para o corpo curvado que filtro_ps2.posar_mumbler monta (olha para +Y, anda sobre os
    # braços; .L é -X porque Z × frente). Se mudar a pose no filtro, refaça estas coordenadas.
    "Mumbler": dict(tipo="manual", frente=(0, 1), ossos=MUMBLER_OSSOS),
}


def vec(a):
    return Vector((float(a[0]), float(a[1]), float(a[2])))


class Quadro:
    """Coordenadas locais (a = esquerda, b = adiante, z = cima) do monstro."""

    def __init__(self, frente):
        f = np.array([frente[0], frente[1], 0.0])
        self.f = f / np.linalg.norm(f)
        self.l = np.cross([0.0, 0.0, 1.0], self.f)

    def para_local(self, V):
        return V @ self.l, V @ self.f, V[:, 2]

    def para_mundo(self, a, b, z):
        return self.l * a + self.f * b + np.array([0.0, 0.0, z])


def vertices_mundo(obj):
    mw = obj.matrix_world
    return np.array([tuple(mw @ v.co) for v in obj.data.vertices]).reshape(-1, 3)


def todas_as_malhas():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def assar_malhas(malhas):
    # Leva a transformação de mundo para os vértices e solta dos pais: o rig nasce em coordenadas limpas.
    for o in malhas:
        mw = o.matrix_world.copy()
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        o.vertex_groups.clear()
        o.data.transform(mw)
        o.parent = None
        o.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()  # sem isso matrix_world fica com o valor antigo e os vértices são lidos transformados 2x


def limpar_cena(manter):
    for o in list(bpy.context.scene.objects):
        if o not in manter:
            bpy.data.objects.remove(o)


def criar_armadura(nome, ossos):
    # ossos: lista de (nome, pai, head, tail) em coordenadas de mundo; a armadura fica na origem.
    dados = bpy.data.armatures.new(nome)
    arm = bpy.data.objects.new(nome, dados)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for n, _, h, t in ossos:
        b = dados.edit_bones.new(n)
        b.head, b.tail = vec(h), vec(t)
        if (b.tail - b.head).length < 0.03:
            b.tail = b.head + Vector((0, 0, 0.03))
    for n, pai, _, _ in ossos:
        if pai:
            dados.edit_bones[n].parent = dados.edit_bones[pai]
    bpy.ops.object.mode_set(mode="OBJECT")
    dados.display_type = "OCTAHEDRAL"
    arm.show_in_front = True
    return arm


def ligar_malha(obj, arm):
    mw = obj.matrix_world.copy()  # preserva a posição no mundo ao trocar de pai
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    obj.matrix_world = mw
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def pesos_por_distancia(obj, segmentos):
    # segmentos: lista de (nome, head, tail) em mundo. Top-4 por inverso da distância^4, normalizados.
    V = vertices_mundo(obj)
    if len(V) == 0:
        return
    H = np.array([s[1] for s in segmentos], dtype=float)
    T = np.array([s[2] for s in segmentos], dtype=float)
    seg = T - H
    comp2 = np.maximum((seg * seg).sum(1), 1e-9)
    t = np.clip(((V[:, None, :] - H[None]) * seg[None]).sum(2) / comp2[None], 0.0, 1.0)
    mais_perto = H[None] + t[:, :, None] * seg[None]
    d = np.linalg.norm(V[:, None, :] - mais_perto, axis=2)
    w = 1.0 / (d + 0.02) ** POTENCIA
    grupos = {s[0]: obj.vertex_groups.get(s[0]) or obj.vertex_groups.new(name=s[0]) for s in segmentos}
    nomes = [s[0] for s in segmentos]
    for i in range(len(V)):
        idx = np.argsort(w[i])[::-1][:MAX_INFLUENCIAS]
        soma = float(w[i][idx].sum())
        for j in idx:
            grupos[nomes[j]].add([i], float(w[i][j] / soma), "REPLACE")


def limitar_influencias(obj):
    # No máximo 4 por vértice e soma 1. Devolve o maior número de influências que sobrou.
    maior = 0
    for v in obj.data.vertices:
        gs = sorted(((g.weight, g.group) for g in v.groups), reverse=True)
        for _, gi in gs[MAX_INFLUENCIAS:]:
            obj.vertex_groups[gi].remove([v.index])
        gs = gs[:MAX_INFLUENCIAS]
        soma = sum(w for w, _ in gs)
        if soma > 0:
            for w, gi in gs:
                obj.vertex_groups[gi].add([v.index], w / soma, "REPLACE")
        maior = max(maior, len(gs))
    return maior


def segmentos_da_armadura(arm):
    mw = arm.matrix_world
    return [(b.name, np.array(mw @ b.head_local), np.array(mw @ b.tail_local))
            for b in arm.data.bones if b.use_deform and "IK" not in b.name and "Ctrl" not in b.name]


# ---------- esqueleto bípede ----------

def ajustar_biped(V, q, p):
    A, B, Z = q.para_local(V)
    H = float(Z.max())
    a0 = float(np.median(A))

    def centro(z, lado=0, lat=None, larg=0.06):
        m = np.abs(Z - z * H) < larg * H
        if lado:
            m &= lado * (A - a0) > 0.03
        if lat is not None:
            m &= np.abs(A - a0) < lat
        return (float(A[m].mean()), float(B[m].mean())) if m.sum() >= 3 else None

    def ponto(a, b, z):
        return q.para_mundo(a, b, z * H)

    zq, zs, zn = p["hips"], p["sho"], p["neck"]
    z1 = zq + 0.40 * (zs - zq)
    z2 = zq + 0.85 * (zs - zq)
    zh = zn + 0.06
    c = lambda z: (centro(z, lat=0.35) or (a0, float(B.mean())))[1]
    cabeca_topo_b = float(B[Z > 0.93 * H].mean()) if (Z > 0.93 * H).any() else c(zh)
    pts = {
        "pelve": ponto(a0, c(zq), zq),
        "coluna": ponto(a0, c(z1), z1),
        "peito": ponto(a0, c(z2), z2),
        "pescoco": ponto(a0, c(zn), zn),
        "cabeca": ponto(a0, c(zh), zh),
        "topo": ponto(a0, cabeca_topo_b, 1.0),
    }
    ossos = [
        ("Hips", None, pts["pelve"], pts["coluna"]),
        ("Spine", "Hips", pts["coluna"], pts["peito"]),
        ("Chest", "Spine", pts["peito"], pts["pescoco"]),
        ("Neck", "Chest", pts["pescoco"], pts["cabeca"]),
        ("Head", "Neck", pts["cabeca"], pts["topo"]),
    ]
    b_peito = c(z2)
    for lado, nome in ((1, "L"), (-1, "R")):
        # pernas: centroide dos vértices do lado em 3 alturas (quadril, joelho, tornozelo)
        z_tor = 0.06
        z_joe = 0.5 * (zq + z_tor)
        niveis = [zq, z_joe, z_tor]
        c_leg = [centro(z, lado=lado) for z in niveis]
        ref = next((x for x in c_leg if x), (a0 + lado * 0.12, c(zq)))
        c_leg = [x or ref for x in c_leg]
        quadril = ponto(a0 + (c_leg[0][0] - a0) * 0.8, c(zq), zq)
        joelho = ponto(c_leg[1][0], c_leg[1][1], z_joe)
        tornoz = ponto(c_leg[2][0], c_leg[2][1], z_tor)
        lado_pe = (lado * (A - a0) > 0.03) & (Z < 0.07 * H) & (np.linalg.norm(V - tornoz, axis=1) < 0.45)  # só o pé, não a mão no chão
        if lado_pe.any():
            k = int(np.argmax(np.where(lado_pe, B, -1e9)))
            ponta = ponto(A[k], B[k], 0.02)
        else:
            ponta = tornoz + q.f * 0.2
        ossos += [
            (f"UpperLeg.{nome}", "Hips", quadril, joelho),
            (f"LowerLeg.{nome}", f"UpperLeg.{nome}", joelho, tornoz),
            (f"Foot.{nome}", f"LowerLeg.{nome}", tornoz, ponta),
        ]
        # braços: ombro e pulso de partida; o cotovelo e o pulso são puxados para a malha
        ombro = ponto(a0 + lado * p["sh_lat"], b_peito, zs)
        mao = ponto(a0 + lado * p["mao"][0], b_peito + p["mao"][1], p["mao"][2])
        if p.get("mao_extremo"):  # braços abertos: a mão é o extremo lateral da malha
            ext = lado * (A - a0)
            m = (ext > np.percentile(ext, 97)) & (Z > 0.1 * H)
            if m.sum() > 3:
                mao = V[m].mean(0)
        cot = (ombro + mao) / 2

        def puxar(pt, r=0.2, vezes=3):
            for _ in range(vezes):
                d = np.linalg.norm(V - pt, axis=1)
                m = (d < r) & (lado * (A - a0) > 0.1)
                if m.sum() > 5:
                    pt = 0.5 * pt + 0.5 * V[m].mean(0)
            return pt

        cot, mao = puxar(cot), puxar(mao)
        dedos = mao + (mao - cot) / max(np.linalg.norm(mao - cot), 1e-6) * 0.15
        ossos += [
            (f"UpperArm.{nome}", "Chest", ombro, cot),
            (f"LowerArm.{nome}", f"UpperArm.{nome}", cot, mao),
            (f"Hand.{nome}", f"LowerArm.{nome}", mao, dedos),
        ]
    return ossos


# ---------- esqueleto quadrúpede (cervo) ----------

def ajustar_quadrupede(V, q, p):
    A, B, Z = q.para_local(V)
    H = float(Z.max())
    a0 = float(np.median(A))
    zc = p["corpo"]
    corpo = (np.abs(Z - zc * H) < 0.10 * H) & (np.abs(A - a0) < 0.5)
    b_min, b_max = float(B[corpo].min()), float(B[corpo].max())
    L = b_max - b_min

    def centro(z, mask=None, larg=0.06):
        m = np.abs(Z - z * H) < larg * H
        if mask is not None:
            m &= mask
        return (float(A[m].mean()), float(B[m].mean())) if m.sum() >= 3 else None

    def ponto(a, b, z):
        return q.para_mundo(a, b, z * H)

    estreito = np.abs(A - a0) < 0.3
    pelve = ponto(a0, b_min + 0.15 * L, zc)
    coluna = ponto(a0, b_min + 0.50 * L, zc + 0.02)
    peito = ponto(a0, b_max - 0.20 * L, zc + 0.04)
    n1 = centro(0.72, estreito) or (a0, b_max)
    n2 = centro(0.86, estreito) or n1
    cab = centro(0.94, estreito) or n2
    pescoco1, pescoco2 = ponto(a0, n1[1], 0.72), ponto(a0, n2[1], 0.86)
    cabeca, topo = ponto(a0, cab[1], 0.93), ponto(a0, cab[1], 1.0)
    ossos = [
        ("Hips", None, pelve, coluna),
        ("Spine", "Hips", coluna, peito),
        ("Chest", "Spine", peito, pescoco1),
        ("Neck.1", "Chest", pescoco1, pescoco2),
        ("Neck.2", "Neck.1", pescoco2, cabeca),
        ("Head", "Neck.2", cabeca, topo),
    ]
    cauda_b = float(B[(Z > 0.3 * H) & (Z < 0.8 * H)].min())
    t1 = ponto(a0, b_min + 0.02 * L, zc + 0.03)
    t2 = ponto(a0, (b_min + cauda_b) / 2, zc)
    t3 = ponto(a0, cauda_b, zc - 0.05)
    ossos += [("Tail.1", "Hips", t1, t2), ("Tail.2", "Tail.1", t2, t3)]
    meio = b_min + 0.5 * L
    for lado, nl in ((1, "L"), (-1, "R")):
        for frente, nf, pai, b_ref in ((True, "F", "Chest", b_max - 0.15 * L), (False, "B", "Hips", b_min + 0.20 * L)):
            m = (lado * (A - a0) > 0.02) & ((B > meio) if frente else (B < meio))
            zs = [zc - 0.05, 0.5 * (zc - 0.05 + 0.05), 0.05]
            cs = [centro(z, m) for z in zs]
            ref = next((x for x in cs if x), (a0 + lado * 0.1, b_ref))
            cs = [x or ref for x in cs]
            ombro = ponto(cs[0][0], b_ref, zs[0])
            joelho = ponto(cs[1][0], cs[1][1], zs[1])
            pata = ponto(cs[2][0], cs[2][1], zs[2])
            casco = pata + np.array([0, 0, -zs[2] * H + 0.02]) * 1.0 + q.f * 0.05
            ossos += [
                (f"UpperLeg.{nf}.{nl}", pai, ombro, joelho),
                (f"LowerLeg.{nf}.{nl}", f"UpperLeg.{nf}.{nl}", joelho, pata),
                (f"Foot.{nf}.{nl}", f"LowerLeg.{nf}.{nl}", pata, casco),
            ]
    return ossos


# ---------- peças rígidas ----------

def rig_pecas(malhas, q):
    # Um osso por peça (do ponto baixo ao alto do eixo mais longo). Pai = osso mais próximo já colocado, a partir da peça maior.
    dados = []
    for o in malhas:
        V = vertices_mundo(o)
        mn, mx = V.min(0), V.max(0)
        ext = mx - mn
        ax = int(np.argmax(ext))
        c = (mn + mx) / 2
        h, t = c.copy(), c.copy()
        h[ax], t[ax] = mn[ax], mx[ax]
        if ax != 2 and h[2] > t[2]:
            h, t = t, h
        dados.append((o, h, t, float(np.prod(np.maximum(ext, 0.01)))))
    dados.sort(key=lambda x: -x[3])
    colocados, ossos, mapa = [], [], {}
    for i, (o, h, t, _) in enumerate(dados):
        centro = (h + t) / 2
        a, b, z = q.para_local(centro[None])
        nome = f"P{i:02d}_{'L' if a[0] > 0.05 else 'R' if a[0] < -0.05 else 'C'}_z{int(z[0] * 100):03d}"
        pai = None
        if colocados:
            pai = min(colocados, key=lambda c: np.linalg.norm(c[2] - h) if np.linalg.norm(c[2] - h) < np.linalg.norm(c[1] - h) else np.linalg.norm(c[1] - h))[0]
        ossos.append((nome, pai, h, t))
        colocados.append((nome, h, t))
        mapa[o.name] = nome
    return ossos, mapa


# ---------- principal ----------

def main(nome):
    cfg = MODELOS[nome]
    pasta = os.path.join(PS2, nome)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(pasta, nome + ".blend"))
    bpy.context.view_layer.update()
    info = {"nome": nome, "tipo": cfg["tipo"]}
    malhas = todas_as_malhas()
    if cfg["tipo"] == "existente":
        arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
        arm = max(arms, key=lambda o: len(o.data.bones))
        segs = segmentos_da_armadura(arm)
        for o in malhas:
            if not any(m.type == "ARMATURE" for m in o.modifiers):
                ligar_malha(o, arm)
            if len(o.vertex_groups) == 0:
                pesos_por_distancia(o, segs)
        nomes_ossos = [b.name for b in arm.data.bones]
    else:
        if cfg["tipo"] == "biped" and nome == "Corcunda":  # Icospheres = formas de osso do Sketchfab, não são geometria
            malhas = [o for o in malhas if not o.name.startswith("Icosphere")]
        assar_malhas(malhas)  # antes de apagar os pais: a matriz de mundo ainda inclui a transformação deles
        limpar_cena(set(malhas))
        V = np.concatenate([vertices_mundo(o) for o in malhas])
        q = Quadro(cfg["frente"])
        if cfg["tipo"] == "pecas":
            ossos, mapa = rig_pecas(malhas, q)
        elif cfg["tipo"] == "manual":
            ossos = cfg["ossos"]
        else:
            ossos = ajustar_biped(V, q, cfg) if cfg["tipo"] == "biped" else ajustar_quadrupede(V, q, cfg)
        arm = criar_armadura(nome + "_Rig", ossos)
        segs = [(n, np.array(h), np.array(t)) for n, _, h, t in ossos]
        for o in malhas:
            if cfg["tipo"] == "pecas":
                g = o.vertex_groups.new(name=mapa[o.name])
                g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
            else:
                pesos_por_distancia(o, segs)
            ligar_malha(o, arm)
        nomes_ossos = [s[0] for s in segs]
    maior = max((limitar_influencias(o) for o in malhas), default=0)
    info.update({"ossos": len(nomes_ossos), "nomes": nomes_ossos, "malhas": len(malhas), "max_influencias": maior})
    with open(os.path.join(pasta, nome + "_rig.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(pasta, nome + "_rig.blend"))
    return info


if __name__ == "__main__" and "--" in sys.argv:
    nome = sys.argv[sys.argv.index("--") + 2] if sys.argv[sys.argv.index("--") + 1] == "--nome" else None
    r = main(nome)
    print("##RIG## " + json.dumps({k: v for k, v in r.items() if k != "nomes"}, ensure_ascii=False))
