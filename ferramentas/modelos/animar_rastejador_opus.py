# Animações do Rastejador sobre o esqueleto refeito à mão: IK analítica nas quatro patas, gravada quadro a quadro.
# Lê Rastejador_rig.blend (só leitura) e grava Rastejador_anim_opus.blend. O ciclo é no lugar: quem desloca é o jogo.
# Uso:  blender -b --factory-startup -P ferramentas/modelos/animar_rastejador_opus.py
#       blender -b --factory-startup <anim_opus.blend> -P ferramentas/modelos/animar_rastejador_opus.py -- --render <pasta_tmp>
#
# Armadilhas do rig (motivo de quase tudo aqui):
# - malha assada em pose assimétrica (braço L erguido, pata L traseira no ar): a pose neutra é construída, não é a de repouso;
# - UpperLeg.* nasce no JOELHO e os ossos UpperLeg.*.001 (joelho -> quadril) não têm peso: a coxa pesava em UpperLeg;
# - antebraço/mão R tinham peso de UpperLeg.R/LowerLeg.R, e a mão pesava mais no antebraço que em Hand.
#   ajustar_pesos() corrige isso SÓ no arquivo de saída.

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PASTA = os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador")
ENTRADA = os.path.join(PASTA, "Rastejador_rig.blend")
SAIDA = os.path.join(PASTA, "Rastejador_anim_opus.blend")
VIDEOS = os.path.join(PASTA, "videos_opus")

X0 = 0.265  # eixo central do corpo
Z_ALTO = Vector((0, 0, 1))

# Quatro membros. "pe" = ossos rígidos entre si, abaixo do tornozelo/pulso. Frente é -Y; L é +X.
MEMBROS = {
    "FL": dict(a="UpperArm.L", b="LowerArm.L", pe=["Hand.L"], pai="Chest", lado=1, frente=True),
    "FR": dict(a="UpperArm.R", b="LowerArm.R", pe=["Hand.R"], pai="Chest", lado=-1, frente=True),
    "BL": dict(a="UpperLeg.L.001", b="UpperLeg.L", pe=["LowerLeg.L", "Foot.L"], pai="Hips", lado=1, frente=False),
    "BR": dict(a="UpperLeg.R.001", b="UpperLeg.R", pe=["LowerLeg.R", "Foot.R"], pai="Hips", lado=-1, frente=False),
}
# Pose neutra: onde o tornozelo/pulso fica no chão (x relativo ao eixo, y) e giro da mão/pé em relação ao repouso (graus em X).
NEUTRO = {
    "FL": dict(x=1.05, y=-0.80, giro=48),
    "FR": dict(x=1.05, y=-0.80, giro=0),
    "BL": dict(x=0.62, y=1.30, giro=0),
    "BR": dict(x=0.62, y=0.72, giro=0),
}
ORDEM = ("Hips", "Spine", "Chest", "Neck", "Head")
PIVOS = dict(Hips=Vector((X0, 0.75, 1.40)), Spine=Vector((X0, 0.17, 1.66)), Chest=Vector((X0, 0.16, 1.67)))


def S(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def rampa(p, a, b):
    return S((p - a) / (b - a))


def rot(pitch=0.0, roll=0.0, yaw=0.0):
    # pitch > 0 baixa o focinho; roll > 0 tomba para +X; yaw > 0 vira o focinho para +X
    return (Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(roll), 4, "Y")
            @ Matrix.Rotation(math.radians(pitch), 4, "X"))


def em_torno(pivo, m):
    return Matrix.Translation(pivo) @ m @ Matrix.Translation(-pivo)


def quadro(u, v):
    # base ortonormal do plano de dobra (u = segmento 1, v = segmento 2)
    x = u.normalized()
    z = u.cross(v).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


def rigido(p0, base0, p1, base1):
    # transformação rígida que leva o ponto p0 com base0 ao ponto p1 com base1
    r = (base1 @ base0.inverted()).to_4x4()
    return Matrix.Translation(p1) @ r @ Matrix.Translation(-p0)


def ik2(s, w, a, b, polo):
    # devolve o cotovelo/joelho para o ombro/quadril s e o pulso/tornozelo w
    d = w - s
    dist = min(max(d.length, abs(a - b) + 1e-3), (a + b) * 0.985)
    eixo = d.normalized()
    w = s + eixo * dist
    x = (a * a - b * b + dist * dist) / (2 * dist)
    h = math.sqrt(max(a * a - x * x, 0.0))
    p = polo - eixo * polo.dot(eixo)
    return s + eixo * x + p.normalized() * h, w


class Rig:
    def __init__(self, arm, malha):
        self.arm, self.malha = arm, malha
        self.bones = arm.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in self.bones}
        self.pts = {}
        for k, m in MEMBROS.items():
            ba, bb, pe = self.bones[m["a"]], self.bones[m["b"]], self.bones[m["pe"][0]]
            ini = ba.tail_local.copy() if not m["frente"] else ba.head_local.copy()
            meio = bb.head_local.copy()
            fim = pe.head_local.copy()
            self.pts[k] = (ini, meio, fim)
        # vértices do pé/mão de cada membro, para medir o contato
        idx = {g.name: g.index for g in malha.vertex_groups}
        self.vpe = {}
        for k, m in MEMBROS.items():
            gs = {idx[n] for n in m["pe"] if n in idx}
            self.vpe[k] = [v.index for v in malha.data.vertices
                           if sum(g.weight for g in v.groups if g.group in gs) > 0.5]
        nomes = {g.index: g.name for g in malha.vertex_groups}
        self.vpesos = []
        for v in malha.data.vertices:
            ws = [(nomes[g.group], g.weight) for g in v.groups if g.weight > 1e-4 and nomes[g.group] in self.rest]
            soma = sum(w for _, w in ws)
            self.vpesos.append((v.co.copy(), [(n, w / soma) for n, w in ws]))
        self.base = {}
        for k, c in NEUTRO.items():
            ini, meio, fim = self.pts[k]
            g = em_torno(fim, rot(pitch=c["giro"]))
            piso = min((g @ malha.data.vertices[i].co).z for i in self.vpe[k])
            lado = MEMBROS[k]["lado"]
            self.base[k] = Vector((X0 + lado * c["x"], c["y"], fim.z - piso))
        for _ in range(3):  # calibra: a pose neutra toca o chão de fato, medido na malha deformada
            self.aplicar(self.resolver(estado_neutro(self)))
            pes, _, _ = self.medir()
            for k, z in pes.items():
                self.base[k].z -= z

    def resolver(self, e):
        G = {}
        gp = Matrix.Translation(e.get("mov", Vector())) @ em_torno(PIVOS["Hips"], rot(e.get("pitch", 0), e.get("roll", 0), e.get("yaw", 0)))
        G["Hips"] = gp
        G["Spine"] = gp @ em_torno(PIVOS["Spine"], rot(pitch=e.get("dobra", 0) * 0.5, yaw=e.get("torce", 0) * 0.5))
        G["Chest"] = G["Spine"] @ em_torno(PIVOS["Chest"], rot(pitch=e.get("dobra", 0) * 0.5, yaw=e.get("torce", 0) * 0.5))
        G["Neck"] = G["Chest"] @ em_torno(self.bones["Neck"].head_local, rot(pitch=e.get("pesc_p", 0), yaw=e.get("pesc_y", 0), roll=e.get("pesc_r", 0)))
        G["Head"] = G["Neck"] @ em_torno(self.bones["Head"].head_local, rot(pitch=e.get("cab_p", 0), yaw=e.get("cab_y", 0), roll=e.get("cab_r", 0)))
        for k, m in MEMBROS.items():
            ini, meio, fim = self.pts[k]
            a, b = (meio - ini).length, (fim - meio).length
            mp = e["membros"][k]
            s = G[m["pai"]] @ ini
            lado = m["lado"]
            polo = mp.get("polo") or (Vector((lado * 0.8, 0.5, 0.4)) if m["frente"] else Vector((lado * 0.5, -0.8, 0.35)))
            c, w = ik2(s, mp["alvo"], a, b, polo)
            G[m["a"]] = rigido(ini, quadro(meio - ini, fim - meio), s, quadro(c - s, w - c))
            G[m["b"]] = rigido(meio, quadro(fim - meio, meio - ini), c, quadro(w - c, s - c))
            # o segundo quadro usa (v, u); a dobra é a mesma nos dois lados da igualdade
            gpe = Matrix.Translation(w) @ mp["giro"] @ Matrix.Translation(-fim)
            for n in m["pe"]:
                G[n] = gpe
        return G

    def aplicar(self, G):
        for pb in self.arm.pose.bones:
            nome = pb.name
            c = self.rest[nome]
            pai = pb.parent.name if pb.parent else None
            gpai = G[pai] if pai else Matrix.Identity(4)
            loc, q, _ = (c.inverted() @ gpai.inverted() @ G[nome] @ c).decompose()
            pb.location = loc
            pb.rotation_quaternion = q
        self.G = G

    def medir(self, G=None):
        # Skinning linear em Python, igual ao modificador: em -b o depsgraph devolvia malha velha ao mudar a pose por script.
        G = G or self.G
        zs, ys = {}, {}
        tudo = 9.0
        pos = {}
        for i, (co, ws) in enumerate(self.vpesos):
            p = Vector()
            for n, w in ws:
                p += (G[n] @ co) * w
            pos[i] = p
            tudo = min(tudo, p.z)
        pes = {k: min(pos[i].z for i in l) for k, l in self.vpe.items()}
        ys = {k: sum(pos[i].y for i in l) / len(l) for k, l in self.vpe.items()}
        return pes, tudo, ys


# ---------------- pesos: corrige o que faria a pata puxar o braço ----------------

def ajustar_pesos(arm, m):
    vg = m.vertex_groups
    b = arm.data.bones
    ind = {g.name: g for g in vg}
    ind["UpperLeg.L.001"] = vg.new(name="UpperLeg.L.001")
    ind["UpperLeg.R.001"] = vg.new(name="UpperLeg.R.001")
    nomes = {g.index: g.name for g in vg}
    trocas = dict(braco=0, coxa=0, mao=0, ombro=0)

    def seg(p, a, c):
        d = c - a
        t = max(0, min(1, (p - a).dot(d) / d.length_squared))
        return (a + d * t - p).length

    for v in m.data.vertices:
        p = v.co
        w = {nomes[g.group]: g.weight for g in v.groups}
        orig = dict(w)
        # 1. braço R não pode seguir a perna R
        no_braco = (p.x < -0.85 and p.y < 0.4 and p.z > 0.45) or (p.x < -1.1 and p.z < 0.6)
        if no_braco:
            tira = sum(w.pop(n, 0) for n in ("UpperLeg.R", "LowerLeg.R", "Foot.R"))
            if tira:
                w["LowerArm.R"] = w.get("LowerArm.R", 0) + tira
                trocas["braco"] += 1
        # 2. ombro R não pode puxar a coxa
        if p.y > 0.35 and "UpperArm.R" in w:
            w["Hips"] = w.get("Hips", 0) + w.pop("UpperArm.R")
            trocas["ombro"] += 1
        # 3. coxa: parte de UpperLeg passa ao osso .001 perto do segmento joelho-quadril
        for lado in ("L", "R"):
            nome = f"UpperLeg.{lado}"
            if nome in w and not (lado == "R" and no_braco):
                joelho = b[nome].head_local
                quadril = b[nome + ".001"].tail_local
                tornoz = b[f"LowerLeg.{lado}"].head_local
                d1, d2 = seg(p, joelho, quadril), seg(p, joelho, tornoz)
                t = S((d2 - d1) / 0.25 + 0.5)
                if t > 0:
                    w[nome + ".001"] = w[nome] * t
                    w[nome] *= 1 - t
                    trocas["coxa"] += 1
        # 4. mão: a partir do pulso, o que estava no antebraço vai para Hand
        for lado, recuo in (("L", 0.0), ("R", 0.0)):
            n_la, n_h = f"LowerArm.{lado}", f"Hand.{lado}"
            if n_la in w:
                pulso = b[n_h].head_local
                eixo = (pulso - b[n_la].head_local).normalized()
                t = S(((p - pulso).dot(eixo) - recuo) / 0.15)
                if t > 0:
                    w[n_h] = w.get(n_h, 0) + w[n_la] * t
                    w[n_la] *= 1 - t
                    trocas["mao"] += 1
        if w == orig:
            continue
        soma = sum(w.values())
        for n in set(orig) | set(w):
            ind[n].remove([v.index])
        for n, x in w.items():
            if x > 1e-4:
                ind[n].add([v.index], x / soma, "REPLACE")
    return trocas


# ---------------- estado de pose ----------------

def estado_neutro(rig):
    e = dict(mov=Vector((0, 0, -0.12)), membros={})
    for k in MEMBROS:
        e["membros"][k] = dict(alvo=rig.base[k].copy(), giro=rot(pitch=NEUTRO[k]["giro"]))
    return e


def marcha(rig, p, fases, duty, passo, alto, giro_voo):
    # devolve o estado com as patas no ciclo. A pata em apoio recua em velocidade constante; a frente é -Y.
    e = estado_neutro(rig)
    for k, f0 in fases.items():
        u = (p + f0) % 1.0
        mp = e["membros"][k]
        base = NEUTRO[k]["giro"]
        if u < duty:  # apoio
            t = u / duty
            mp["alvo"].y += -passo + 2 * passo * t
        else:  # voo
            t = (u - duty) / (1 - duty)
            s = S(t)
            mp["alvo"].y += passo - 2 * passo * s
            mp["alvo"].z += alto * math.sin(math.pi * t) ** 1.2
            a = giro_voo * math.sin(math.pi * t) * (1.0 if t < 0.5 else 0.6)
            mp["giro"] = rot(pitch=base + (a if MEMBROS[k]["frente"] else -a))
    return e


FASES_WALK = {"BL": 0.0, "FL": 0.25, "BR": 0.5, "FR": 0.75}
FASES_RUN = {"BL": 0.0, "BR": 0.12, "FL": 0.5, "FR": 0.62}
PARAM = dict(Walk=dict(n=32, duty=0.75, passo=0.30), Run=dict(n=16, duty=0.42, passo=0.46))


def walk(rig, p):
    c = PARAM["Walk"]
    e = marcha(rig, p, FASES_WALK, c["duty"], c["passo"], 0.20, 28)
    phi = 2 * math.pi * p
    e["mov"] = Vector((0.03 * math.sin(phi), 0, -0.12 + 0.025 * math.cos(2 * phi)))
    e["roll"] = 2.5 * math.sin(phi)
    e["yaw"] = 3 * math.sin(phi + 0.8)
    e["torce"] = -7 * math.sin(phi + 0.8)
    e["pesc_y"] = 5 * math.sin(phi + 0.8)
    e["cab_y"] = 6 * math.sin(phi)
    e["cab_p"] = 2 * math.sin(2 * phi)
    return e


def run(rig, p):
    c = PARAM["Run"]
    e = marcha(rig, p, FASES_RUN, c["duty"], c["passo"], 0.30, 40)
    phi = 2 * math.pi * p
    e["mov"] = Vector((0, 0.05 * math.cos(phi), -0.20 + 0.07 * math.sin(2 * phi + 0.5)))
    e["pitch"] = 5 * math.sin(phi + 0.6)
    e["dobra"] = 12 * math.sin(phi + 1.4) + 4
    e["roll"] = 2 * math.sin(phi)
    e["pesc_p"] = -5 * math.sin(phi + 0.6) - 4
    e["cab_p"] = -4 * math.sin(phi + 1.0)
    return e


def idle(rig, p):
    e = estado_neutro(rig)
    phi = 2 * math.pi * p
    r = math.sin(phi)
    e["mov"] = Vector((0.025 * math.sin(phi + 0.5), 0.015 * math.sin(2 * phi), -0.13 - 0.02 * math.cos(2 * phi)))
    e["roll"] = 1.5 * math.sin(phi + 0.5)
    e["dobra"] = 2.0 * math.cos(2 * phi)  # respiração
    # cabeça cega à escuta: varre devagar e inclina
    e["pesc_y"] = 7 * r
    e["cab_y"] = 13 * math.sin(phi - 0.5)
    e["cab_r"] = 10 * math.sin(phi + 0.9)
    e["cab_p"] = -3 + 3 * math.sin(3 * phi)
    return e


def attack(rig, p):
    e = estado_neutro(rig)
    prep = rampa(p, 0.02, 0.34) * (1 - rampa(p, 0.34, 0.46))
    bote = rampa(p, 0.34, 0.47) * (1 - rampa(p, 0.62, 0.98))
    golpe = rampa(p, 0.42, 0.52) * (1 - rampa(p, 0.62, 0.98))
    ergue = rampa(p, 0.20, 0.42) * (1 - rampa(p, 0.45, 0.54))
    e["mov"] = Vector((0, 0.34 * prep - 0.60 * bote, -0.12 - 0.26 * prep + 0.12 * bote))
    e["pitch"] = 6 * prep - 12 * ergue + 6 * golpe
    e["dobra"] = -8 * prep - 4 * ergue + 8 * golpe
    e["pesc_p"] = -14 * prep - 10 * ergue + 16 * golpe
    e["cab_p"] = -12 * ergue + 10 * golpe
    tremor = 2.5 * math.sin(p * 70) * prep
    e["roll"] = tremor
    for k in ("FL", "FR"):
        mp = e["membros"][k]
        lado = MEMBROS[k]["lado"]
        atras = 0.05 if k == "FL" else -0.05  # uma garra chega antes da outra
        q = p + atras
        e_e = rampa(q, 0.20, 0.42) * (1 - rampa(q, 0.45, 0.54))
        g = rampa(q, 0.42, 0.52) * (1 - rampa(q, 0.62, 0.98))
        mp["alvo"] += Vector((-lado * 0.30 * e_e, -0.75 * e_e - 0.72 * g, 1.15 * e_e))
        mp["giro"] = rot(pitch=NEUTRO[k]["giro"] - 60 * e_e)
    return e


def death(rig, p):
    # Tranco para trás, as patas cedem, a barriga bate no chão, quica pouco e a cabeça tomba de lado. Morre de bruços.
    e = estado_neutro(rig)
    tranco = rampa(p, 0.0, 0.14) * (1 - rampa(p, 0.14, 0.34))
    cai = rampa(p, 0.22, 0.60) ** 1.6
    fim = rampa(p, 0.68, 1.0)
    quica = 0.09 * math.sin(math.pi * rampa(p, 0.60, 0.74))
    e["mov"] = Vector((-0.10 * cai, 0.24 * tranco - 0.10 * cai, -0.12 + 0.22 * tranco - 0.92 * cai + quica))
    e["pitch"] = -14 * tranco + 5 * cai
    e["roll"] = -9 * cai
    e["dobra"] = -16 * tranco + 8 * cai
    e["pesc_p"] = -18 * tranco + 10 * cai
    e["pesc_y"] = 20 * cai
    e["pesc_r"] = -12 * cai
    e["cab_p"] = -14 * tranco + 6 * cai
    e["cab_y"] = 16 * rampa(p, 0.45, 0.8)
    e["cab_r"] = -38 * rampa(p, 0.45, 0.8)
    atrasos = dict(FR=0.0, BR=0.05, FL=0.03, BL=0.09)
    abre = dict(FL=(0.75, -0.45), FR=(0.70, -0.25), BL=(0.55, 0.40), BR=(0.70, 0.55))
    for k, m in MEMBROS.items():
        mp = e["membros"][k]
        q = rampa(p, 0.24 + atrasos[k], 0.62 + atrasos[k])
        # espasmo final de uma pata só, sem erguer do chão
        esp = 0.05 * math.sin(p * 34) * (1 - fim) * rampa(p, 0.62, 0.72) if k == "BL" else 0.0
        mp["alvo"] += Vector((m["lado"] * abre[k][0] * q, abre[k][1] * q + esp, 0))
    return e


ACOES = [("Idle", 60, idle, True), ("Walk", PARAM["Walk"]["n"], walk, True), ("Run", PARAM["Run"]["n"], run, True),
         ("Attack", 36, attack, False), ("Death", 48, death, False)]


def corrigir_e_coletar(rig, fn, n, ciclica):
    """Resolve os quadros; ergue cada pata (e o corpo, se preciso) o tanto que a malha afunda em Z=0. Duas passadas."""
    total = n
    ps = [(i / n) if ciclica else (i / max(n - 1, 1)) for i in range(total)]
    sobe = [{k: 0.0 for k in MEMBROS} for _ in ps]
    corpo = [0.0 for _ in ps]
    estados = None
    for passada in range(3):
        estados = []
        pior = 0.0
        for i, p in enumerate(ps):
            e = fn(rig, p)
            e["mov"] = e.get("mov", Vector()) + Vector((0, 0, corpo[i]))
            for k in MEMBROS:
                e["membros"][k]["alvo"].z += sobe[i][k]
            G = rig.resolver(e)
            rig.aplicar(G)
            pes, tudo, _ = rig.medir()
            for k, z in pes.items():
                if z < 0:
                    sobe[i][k] += -z
            if tudo < min(pes.values()) - 1e-4 and tudo < 0:
                corpo[i] += -tudo
            pior = min(pior, tudo)
            estados.append(G)
        if pior > -1e-3:
            break
    return estados, pior


def gravar(rig, nome, n, fn, ciclica):
    Gs, pior = corrigir_e_coletar(rig, fn, n, ciclica)
    arm = rig.arm
    act = bpy.data.actions.new(f"Rastejador_{nome}")
    arm.animation_data_create()
    arm.animation_data.action = act
    ant = {}
    total = n + 1 if ciclica else n
    for i in range(total):
        rig.aplicar(Gs[i % len(Gs)])
        for pb in arm.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in ant:
                q.make_compatible(ant[pb.name])
            ant[pb.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=i + 1)
            pb.keyframe_insert("location", frame=i + 1)
    act.use_fake_user = True
    if hasattr(act, "use_cyclic"):
        act.use_cyclic = ciclica
    arm.animation_data.action = None
    faixa = arm.animation_data.nla_tracks.new()
    faixa.name = act.name
    faixa.strips.new(act.name, 1, act)
    faixa.mute = True
    for pb in arm.pose.bones:
        pb.location = Vector()
        pb.rotation_quaternion = Quaternion()
    return dict(acao=act.name, quadros=total, ciclica=ciclica, zmin_corrigido=round(pior, 4))


def main():
    bpy.ops.wm.open_mainfile(filepath=ENTRADA)
    arm = bpy.data.objects["Rastejador_Rig"]
    m = bpy.data.objects["monster_monster_1_0"]
    arm.data.pose_position = "POSE"
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    print("##PESOS## ", ajustar_pesos(arm, m))
    rig = Rig(arm, m)
    r = [gravar(rig, *a) for a in ACOES]
    cena = bpy.context.scene
    cena.frame_start, cena.frame_end, cena.frame_current = 1, PARAM["Walk"]["n"] + 1, 1
    arm.animation_data.action = bpy.data.actions["Rastejador_Walk"]
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    print("##ANIM## " + json.dumps(r, ensure_ascii=False))


# ---------------- verificação: quadros de lado, medidas e mp4 a 12 fps ----------------

def verificar(tmp):
    cena = bpy.context.scene
    arm = bpy.data.objects["Rastejador_Rig"]
    m = bpy.data.objects["monster_monster_1_0"]
    rig = Rig(arm, m)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 5.2
    cob = bpy.data.objects.new("cam", cam)
    cena.collection.objects.link(cob)
    cena.camera = cob
    cob.location = (-9, 0.3, 1.0)
    cob.rotation_euler = (math.radians(90), 0, math.radians(-90))
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, -0.005))
    mc = bpy.data.materials.new("chao")
    mc.diffuse_color = (0.12, 0.12, 0.14, 1)
    bpy.context.object.data.materials.append(mc)
    mm = bpy.data.materials.new("marca")
    mm.diffuse_color = (0.9, 0.9, 0.3, 1)
    marcas = []
    for i in range(12):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
        o = bpy.context.object
        o.scale = (6, 0.08, 0.004)
        o.data.materials.append(mm)
        marcas.append(o)
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.display.shading.color_type = "TEXTURE"
    cena.display.shading.light = "STUDIO"
    cena.display.shading.show_shadows = False
    cena.render.resolution_x, cena.render.resolution_y = 640, 480
    cena.render.film_transparent = False
    cena.render.image_settings.file_format = "PNG"
    bpy.context.scene.world = bpy.data.worlds.new("w")
    bpy.context.scene.world.color = (0.55, 0.57, 0.6)
    rel = {}
    for nome, n, fn, ciclica in ACOES:
        act = bpy.data.actions[f"Rastejador_{nome}"]
        arm.animation_data.action = act
        total = n + 1 if ciclica else n
        v = 0.0
        if nome in PARAM:
            c = PARAM[nome]
            v = 2 * c["passo"] / (c["duty"] * c["n"])  # unidades por quadro
        zmin, tmin = 9.0, 0
        hist = {k: [] for k in MEMBROS}
        for f in range(1, total + 1):
            cena.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            pose = arm.evaluated_get(dg).pose.bones  # lê o que foi gravado, não o que foi calculado
            pes, tudo, ys = rig.medir({b.name: b.matrix @ rig.rest[b.name].inverted() for b in pose})
            if tudo < zmin:
                zmin, tmin = tudo, f
            for k in MEMBROS:
                hist[k].append((pes[k], ys[k]))
        desliz = 0.0
        ao_ar = {k: 0 for k in MEMBROS}
        if v:
            for k, h in hist.items():
                for i in range(len(h) - 1):
                    apoio = h[i][0] < 0.015 and h[i + 1][0] < 0.015
                    if apoio:
                        desliz = max(desliz, abs((h[i + 1][1] - h[i][1]) - v))
                    else:
                        ao_ar[k] += 1
        salto = 0.0
        if ciclica:
            cena.frame_set(1)
            a = [pb.matrix.copy() for pb in arm.pose.bones]
            cena.frame_set(total)
            b = [pb.matrix.copy() for pb in arm.pose.bones]
            salto = max((x.translation - y.translation).length for x, y in zip(a, b))
        rel[nome] = dict(zmin=round(zmin, 4), quadro_zmin=tmin, vel_un_por_quadro=round(v, 4), salto_ciclo=round(salto, 5),
                         erro_desliz_max=round(desliz, 4), quadros_no_ar=ao_ar)
        pasta = os.path.join(tmp, nome)
        os.makedirs(pasta, exist_ok=True)
        passo_f = 2  # 24 fps da cena -> 12 fps no vídeo
        voltas = 3 if ciclica else 1
        k = 0
        for vv in range(voltas):
            for f in range(1, total if ciclica else total + 1, passo_f):
                cena.frame_set(f)
                d = v * (vv * n + f)
                for i, o in enumerate(marcas):
                    o.location = (X0, ((i * 0.75 + d) % 9) - 4.2, 0.0)
                cena.render.filepath = os.path.join(pasta, f"f{k:03d}.png")
                bpy.ops.render.render(write_still=True)
                k += 1
    cob.location, cob.rotation_euler = (X0, -9, 1.0), (math.radians(90), 0, 0)
    for nome, f in (("Walk", 9), ("Attack", 20), ("Death", 48)):
        arm.animation_data.action = bpy.data.actions[f"Rastejador_{nome}"]
        cena.frame_set(f)
        cena.render.filepath = os.path.join(tmp, f"frente_{nome}.png")
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = bpy.data.actions["Rastejador_Walk"]
    print("##VERIF## " + json.dumps(rel, ensure_ascii=False))


if __name__ == "__main__":
    if "--render" in sys.argv:
        verificar(sys.argv[sys.argv.index("--render") + 1])
    else:
        main()
