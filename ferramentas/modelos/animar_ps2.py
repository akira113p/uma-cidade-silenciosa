# Animações procedurais dos monstros: Idle, Walk, Run, Attack, Death. Roda sobre <Nome>_rig.blend e grava <Nome>_anim.blend.
# Nada vai ao Roblox. Uso:  blender -b --factory-startup -P ferramentas/modelos/animar_ps2.py -- --nome Corcunda
#
# Como funciona: cada osso gira "a ponta para frente / cima / lado..." (girar), então a mesma receita serve a qualquer
# esqueleto, qualquer orientação de osso. A receita escolhe o osso por PAPEL (quadril, coxa, canela, ombro...) e cada modelo
# traz seu mapa de papéis. Tipos: "biped" (também o Rastejador, que anda de quatro), "quad" (cervo: marcha e trote em
# diagonal) e "pecas" (Pernalta: um osso por peça rígida, só balanço).
# As ações ficam no arquivo (fake user + faixas NLA mudas); para ver, atribua uma ação à armadura.

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PS2 = os.path.join(REPO, "modelos 3d", "_ps2")

# ---- mapas de papéis (nome do osso por papel; L/R = lados) ----
def mapa_meu():
    m = {"hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head"}
    for k, v in (("ul", "UpperLeg"), ("ll", "LowerLeg"), ("ft", "Foot"), ("ua", "UpperArm"), ("la", "LowerArm"), ("hd", "Hand")):
        m[k] = {"L": f"{v}.L", "R": f"{v}.R"}
    return m


def mapa_prefixo(hips, spine, chest, neck, head, ul, ll, ft, toe, ua, la, hd, esq="Left", dir_="Right", tail=()):
    m = {"hips": hips, "spine": spine, "chest": chest, "neck": neck, "head": head, "tail": list(tail)}
    for k, v in (("ul", ul), ("ll", ll), ("ft", ft), ("toe", toe), ("ua", ua), ("la", la), ("hd", hd)):
        m[k] = {"L": v.format(lado=esq), "R": v.format(lado=dir_)}
    return m


MAPAS = {
    "meu": mapa_meu(),
    "carniceiro": mapa_prefixo("AboveMonsterRig:Bind_Hips", "AboveMonsterRig:Bind_Spine", "AboveMonsterRig:Bind_Spine2",
                               "AboveMonsterRig:Bind_Neck", "AboveMonsterRig:Bind_Head",
                               "AboveMonsterRig:Bind_{lado}UpLeg", "AboveMonsterRig:Bind_{lado}Leg", "AboveMonsterRig:Bind_{lado}Foot",
                               "AboveMonsterRig:Bind_{lado}ToeBase", "AboveMonsterRig:Bind_{lado}Arm",
                               "AboveMonsterRig:Bind_{lado}ForeArm", "AboveMonsterRig:Bind_{lado}Hand"),
    "monstro": mapa_prefixo("Character1_Hips", "Character1_Spine", "Character1_Spine2", "Character1_Neck", "Character1_Head",
                            "Character1_{lado}UpLeg", "Character1_{lado}Leg", "Character1_{lado}Foot", "Character1_{lado}ToeBase",
                            "Character1_{lado}Arm", "Character1_{lado}ForeArm", "Character1_{lado}Hand"),
    "florescida": mapa_prefixo("C_Hip_J", "C_spine_01_J", "C_spine_03_J", "C_Neck_J", "C_Head_J",
                               "{lado}_upper_leg_J", "{lado}_knee_J", "{lado}_ankle_J", "{lado}_toe_J",
                               "{lado}_shoulder_J", "{lado}_elbow_J", "{lado}_wrist_J", esq="L", dir_="R",
                               tail=("C_base_tail_J", "C_tail_01_J", "C_tail_02_J")),
}

MODELOS = {
    "Corcunda": dict(tipo="biped", mapa="meu", frente=(1, 0), lean=8, passo=1.2),
    "Esfolado": dict(tipo="biped", mapa="meu", frente=(0, -1), lean=12, passo=0.9),
    "Urchin": dict(tipo="biped", mapa="meu", frente=(0, -1), lean=4, passo=0.9),
    "Mumbler": dict(tipo="biped", mapa="meu", frente=(0, 1), lean=4, passo=0.7, quatro_patas=True),
    "Rastejador": dict(tipo="biped", mapa="meu", frente=(0, -1), lean=15, passo=0.6, quatro_patas=True),
    "Espreitador": dict(tipo="quad", frente=(0, -1)),
    "Pernalta": dict(tipo="pecas", frente=(0, -1)),
    "Carniceiro": dict(tipo="biped", mapa="carniceiro", lean=6, passo=1.0),
    "MonstroPS1": dict(tipo="biped", mapa="monstro", lean=4, passo=1.0, bracos_baixos=75),
    "Florescida": dict(tipo="biped", mapa="florescida", lean=10, passo=0.9),
}

S = lambda x: x * x * (3 - 2 * x)  # suavização 0..1


class Anim:
    """Acumula giros/deslocamentos por osso em coordenadas da armadura e grava quadros-chave."""

    def __init__(self, arm, frente_mundo):
        self.arm = arm
        m3 = arm.matrix_world.to_3x3().inverted()
        up = (m3 @ Vector((0, 0, 1))).normalized()
        f = (m3 @ Vector(frente_mundo)).normalized()
        f = (f - up * f.dot(up)).normalized()
        esq = up.cross(f).normalized()
        self.dirs = {"f": f, "b": -f, "u": up, "d": -up, "l": esq, "r": -esq}
        self.esc = (arm.matrix_world.to_3x3() @ up).length  # metros do mundo por unidade local (armadura pode ter escala)
        self.rest = {}
        for b in arm.data.bones:
            d = b.tail_local - b.head_local
            self.rest[b.name] = (b.matrix_local.to_quaternion(), d.normalized() if d.length > 1e-6 else Vector((0, 0, 1)))
        self.q, self.t = {}, {}

    def girar(self, osso, direcao, graus):
        # a ponta do osso (como está agora) se move 'graus' em direção a 'direcao'
        if not osso or osso not in self.rest:
            return
        q0 = self.q.get(osso, Quaternion())
        d = q0 @ self.rest[osso][1]
        t = self.dirs[direcao]
        t = t - d * d.dot(t)
        if t.length < 1e-4:
            return
        self.q[osso] = Quaternion(d.cross(t.normalized()), math.radians(graus)) @ q0

    def rolar(self, osso, direcao, graus):
        # gira o osso em torno de um eixo fixo (frente/cima/lado), ex.: tombar de lado em torno do eixo da frente
        if osso and osso in self.rest:
            self.q[osso] = Quaternion(self.dirs[direcao], math.radians(graus)) @ self.q.get(osso, Quaternion())

    def mover(self, osso, direcao, metros_mundo):
        if osso and osso in self.rest:
            self.t[osso] = self.t.get(osso, Vector()) + self.dirs[direcao] * (metros_mundo / self.esc)

    def gravar(self, nome, n, fn, ciclica):
        # fn(self, p) com p em 0..1 (ciclo) ou 0..1 (progresso); quadros 1..n(+1 se cíclica)
        quadros = {}
        total = n + 1 if ciclica else n
        for i in range(total):
            self.q, self.t = {}, {}
            fn(self, (i % n) / n if ciclica else i / max(n - 1, 1))
            quadros[i + 1] = ({k: v.copy() for k, v in self.q.items()}, {k: v.copy() for k, v in self.t.items()})
        usados = set()
        for q, t in quadros.values():
            usados |= set(q) | set(t)
        com_t = {k for _, tt in quadros.values() for k in tt}
        act = bpy.data.actions.new(nome)
        self.arm.animation_data_create()
        self.arm.animation_data.action = act
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion()
            pb.location = Vector()
        for frame, (q, t) in quadros.items():
            for osso in usados:
                pb = self.arm.pose.bones[osso]
                rr = self.rest[osso][0]
                pb.rotation_quaternion = rr.inverted() @ q.get(osso, Quaternion()) @ rr
                pb.location = rr.inverted() @ t.get(osso, Vector())
                pb.keyframe_insert("rotation_quaternion", frame=frame)
                if osso in com_t:
                    pb.keyframe_insert("location", frame=frame)
        act.use_fake_user = True
        if hasattr(act, "use_cyclic"):
            act.use_cyclic = ciclica
        self.arm.animation_data.action = None
        faixa = self.arm.animation_data.nla_tracks.new()
        faixa.name = nome
        faixa.strips.new(nome, 1, act)
        faixa.mute = True
        return {"acao": nome, "quadros": total, "ossos": len(usados), "ciclica": ciclica}


# ---------------- receitas ----------------

def tronco(a, R, c, phi, lean):
    a.girar(R["spine"], "f", lean * 0.6)
    a.girar(R["chest"], "f", lean * 0.4)
    a.girar(R["neck"], "b", lean * 0.5)
    a.girar(R["head"], "b", lean * 0.4)


def biped_andar(a, R, c, p, corrida):
    k = c["passo"] * (1.5 if corrida else 1.0)
    phi = 2 * math.pi * p
    quatro = c.get("quatro_patas")
    SW, K, AS, EL = 28 * k, 45 * k, (50 if quatro else 25) * k, 25 * k
    lean = c.get("lean", 5) + (10 if corrida else 0)
    tronco(a, R, c, phi, lean)
    a.mover(R["hips"], "d", 0.05 * k * (0.5 + 0.5 * math.cos(2 * phi)))
    a.girar(R["hips"], "l", 4 * math.sin(phi))
    a.girar(R["chest"], "l", -5 * math.sin(phi))
    for lado, off in (("L", 0.0), ("R", math.pi)):
        ph = phi + off
        a.girar(R["ul"][lado], "f", SW * math.sin(ph))
        a.girar(R["ll"][lado], "b", K * max(0.0, math.cos(ph)))
        a.girar(R["ft"][lado], "u", 0.25 * K * max(0.0, math.cos(ph)))
        ap = ph + math.pi
        if c.get("bracos_baixos"):
            a.girar(R["ua"][lado], "d", c["bracos_baixos"])
        a.girar(R["ua"][lado], "f", AS * math.sin(ap))
        a.girar(R["la"][lado], "f", EL + 0.5 * AS * max(0.0, math.cos(ap)))
    for i, osso in enumerate(R.get("tail", [])):
        a.girar(osso, "l", 10 * math.sin(phi - i * 0.6))


def biped_idle(a, R, c, p):
    phi = 2 * math.pi * p
    a.mover(R["hips"], "d", 0.012 * (0.5 + 0.5 * math.cos(phi)))
    a.girar(R["chest"], "f", 2.0 * math.sin(phi))
    a.girar(R["spine"], "f", c.get("lean", 5) * 0.6)
    a.girar(R["neck"], "l", 3 * math.sin(phi * 0.5 + 1))
    a.girar(R["head"], "l", 4 * math.sin(phi * 0.5 + 2))
    for lado, off in (("L", 0.0), ("R", 1.2)):
        if c.get("bracos_baixos"):
            a.girar(R["ua"][lado], "d", c["bracos_baixos"])
        a.girar(R["ua"][lado], "f", 3 * math.sin(phi + off))
        a.girar(R["la"][lado], "f", 6 + 3 * math.sin(phi + off))
    for i, osso in enumerate(R.get("tail", [])):
        a.girar(osso, "l", 6 * math.sin(phi - i * 0.7))


def biped_ataque(a, R, c, p):
    w = S(min(p / 0.33, 1.0)) * (1.0 - S(min(max((p - 0.33) / 0.2, 0.0), 1.0)))  # preparação
    s = S(min(max((p - 0.33) / 0.2, 0.0), 1.0)) * (1.0 - S(min(max((p - 0.6) / 0.4, 0.0), 1.0)))  # golpe
    a.girar(R["spine"], "b", 15 * w)
    a.girar(R["spine"], "f", 40 * s + c.get("lean", 5) * 0.6)
    a.girar(R["chest"], "f", 15 * s)
    a.girar(R["head"], "f", 10 * s)
    a.mover(R["hips"], "f", 0.25 * s)
    for lado in ("L", "R"):
        if c.get("bracos_baixos"):
            a.girar(R["ua"][lado], "d", c["bracos_baixos"])
        a.girar(R["ua"][lado], "u", 85 * w)
        a.girar(R["ua"][lado], "f", 70 * s)
        a.girar(R["la"][lado], "f", 40 * w + 10 * s)
    a.girar(R["ul"]["L"], "f", 25 * s)
    a.girar(R["ll"]["L"], "b", 25 * s)
    a.girar(R["ul"]["R"], "b", 15 * s)


def biped_morte(a, R, c, p, altura_quadril):
    e = S(p)
    a.girar(R["hips"], "l", 85 * e)
    a.mover(R["hips"], "d", max(altura_quadril - 0.2, 0) * e)
    a.girar(R["spine"], "f", 30 * e)
    a.girar(R["head"], "l", 25 * e)
    for lado in ("L", "R"):
        a.girar(R["ul"][lado], "f", 40 * e)
        a.girar(R["ll"][lado], "b", 55 * e)
        if c.get("bracos_baixos"):
            a.girar(R["ua"][lado], "d", c["bracos_baixos"])
        a.girar(R["ua"][lado], "f", 25 * e)
        a.girar(R["la"][lado], "f", 35 * e)


# --- quadrúpede ---
def quad_andar(a, R, c, p, corrida):
    phi = 2 * math.pi * p
    SW, K = (36 if corrida else 24), (50 if corrida else 38)
    fases = {"B.L": 0.0, "F.L": 0.25, "B.R": 0.5, "F.R": 0.75}
    if corrida:  # trote: diagonais juntas
        fases = {"F.L": 0.0, "B.R": 0.0, "F.R": 0.5, "B.L": 0.5}
    for chave, f0 in fases.items():
        ph = phi + 2 * math.pi * f0
        a.girar(f"UpperLeg.{chave}", "f", SW * math.sin(ph))
        a.girar(f"LowerLeg.{chave}", "b", K * max(0.0, math.cos(ph)))
        a.girar(f"Foot.{chave}", "u", 12 * max(0.0, math.cos(ph)))
    a.mover("Hips", "d", (0.05 if corrida else 0.03) * (0.5 + 0.5 * math.cos(2 * phi)))
    a.girar("Spine", "l", 4 * math.sin(phi))
    a.girar("Chest", "l", -4 * math.sin(phi))
    a.girar("Neck.1", "l", 3 * math.sin(phi))
    a.girar("Neck.1", "d", 3 * math.sin(2 * phi))
    a.girar("Head", "u", 4 * math.sin(2 * phi + 1))
    for i, osso in enumerate(("Tail.1", "Tail.2")):
        a.girar(osso, "l", 14 * math.sin(phi - i * 0.7))


def quad_idle(a, R, c, p):
    phi = 2 * math.pi * p
    a.mover("Hips", "d", 0.01 * (0.5 + 0.5 * math.cos(phi)))
    a.girar("Chest", "u", 1.5 * math.sin(phi))
    a.girar("Neck.1", "d", 5 + 3 * math.sin(phi))
    a.girar("Neck.2", "l", 8 * math.sin(phi * 0.5))
    a.girar("Head", "d", 4 * math.sin(phi * 0.5 + 1))
    for i, osso in enumerate(("Tail.1", "Tail.2")):
        a.girar(osso, "l", 12 * math.sin(phi - i * 0.8))


def quad_ataque(a, R, c, p):
    w = S(min(p / 0.3, 1.0)) * (1.0 - S(min(max((p - 0.3) / 0.2, 0.0), 1.0)))
    s = S(min(max((p - 0.3) / 0.2, 0.0), 1.0)) * (1.0 - S(min(max((p - 0.6) / 0.4, 0.0), 1.0)))
    a.girar("Chest", "u", 20 * w)
    a.girar("Neck.1", "b", 15 * w)
    a.girar("Neck.1", "f", 45 * s)
    a.girar("Neck.2", "f", 25 * s)
    a.girar("Head", "d", 35 * s)
    for lado in ("L", "R"):
        a.girar(f"UpperLeg.F.{lado}", "f", 45 * w)
        a.girar(f"LowerLeg.F.{lado}", "b", 40 * w)
        a.girar(f"UpperLeg.B.{lado}", "b", 15 * s)


def quad_morte(a, R, c, p, altura_quadril):
    e = S(p)
    a.rolar("Hips", "f", 85 * e)  # o osso do quadril aponta para a frente: tombar = rolar em torno dele
    a.mover("Hips", "d", max(altura_quadril - 0.25, 0) * e)
    a.girar("Neck.1", "d", 30 * e)
    a.girar("Head", "d", 30 * e)
    for chave in ("F.L", "F.R", "B.L", "B.R"):
        a.girar(f"UpperLeg.{chave}", "f", 45 * e)
        a.girar(f"LowerLeg.{chave}", "b", 60 * e)


# --- peças rígidas (Pernalta): profundidade na cadeia a partir de uma peça central ---
def pecas_info(arm):
    info = {}
    for b in arm.data.bones:
        lado = "L" if "_L_" in b.name else "R" if "_R_" in b.name else "C"
        prof, x = 0, b
        while x.parent and ("_C_" not in x.name):
            prof += 1
            x = x.parent
        info[b.name] = (lado, prof if lado != "C" else 0)
    return info


def pecas_andar(a, info, p, corrida):
    phi = 2 * math.pi * p
    k = 1.4 if corrida else 1.0
    # Só o corpo todo (osso raiz): girar cada peça rígida sozinha as separa, porque os pivôs não coincidem.
    raiz = next(iter(info))
    a.mover(raiz, "d", 0.04 * k * (0.5 + 0.5 * math.cos(2 * phi)))
    a.girar(raiz, "l", 3 * k * math.sin(phi))
    a.girar(raiz, "f", 2 * k * math.sin(2 * phi))


def pecas_idle(a, info, p):
    phi = 2 * math.pi * p
    for osso, (lado, prof) in info.items():
        a.girar(osso, "l", 1.5 * math.sin(phi + prof))


def pecas_ataque(a, info, p):
    w = S(min(p / 0.33, 1.0)) * (1.0 - S(min(max((p - 0.33) / 0.2, 0.0), 1.0)))
    s = S(min(max((p - 0.33) / 0.2, 0.0), 1.0)) * (1.0 - S(min(max((p - 0.6) / 0.4, 0.0), 1.0)))
    raiz = next(iter(info))
    a.girar(raiz, "b", 10 * w)
    a.girar(raiz, "f", 30 * s)


def pecas_morte(a, info, p):
    e = S(p)
    raiz = next(iter(info))
    a.girar(raiz, "l", 85 * e)
    a.mover(raiz, "d", 0.9 * e)


# ---------------- principal ----------------

def frente_do_modelo(arm, c, R):
    if "frente" in c:
        return Vector((c["frente"][0], c["frente"][1], 0))
    # esqueleto existente: horizontal do tornozelo à ponta do pé (ou ao osso do dedo)
    mw = arm.matrix_world
    pe = arm.data.bones[R["ft"]["L"]]
    toe = arm.data.bones[R["toe"]["L"]]
    v = (mw @ toe.tail_local) - (mw @ pe.head_local)
    v.z = 0
    return v.normalized()


def main(nome):
    c = MODELOS[nome]
    pasta = os.path.join(PS2, nome)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(pasta, nome + "_rig.blend"))
    bpy.context.view_layer.update()
    arm = max([o for o in bpy.context.scene.objects if o.type == "ARMATURE"], key=lambda o: len(o.data.bones))
    arm.data.pose_position = "POSE"
    R = MAPAS[c["mapa"]] if c["tipo"] == "biped" else {}
    a = Anim(arm, frente_do_modelo(arm, c, R))
    alt_quadril = (arm.matrix_world @ arm.data.bones[R["hips"] if R else "Hips"].head_local).z if (R or c["tipo"] == "quad") else 1.0
    feitas = []
    if c["tipo"] == "biped":
        feitas += [a.gravar(f"{nome}_Idle", 48, lambda x, p: biped_idle(x, R, c, p), True),
                   a.gravar(f"{nome}_Walk", 24, lambda x, p: biped_andar(x, R, c, p, False), True),
                   a.gravar(f"{nome}_Run", 16, lambda x, p: biped_andar(x, R, c, p, True), True),
                   a.gravar(f"{nome}_Attack", 30, lambda x, p: biped_ataque(x, R, c, p), False),
                   a.gravar(f"{nome}_Death", 40, lambda x, p: biped_morte(x, R, c, p, alt_quadril), False)]
    elif c["tipo"] == "quad":
        feitas += [a.gravar(f"{nome}_Idle", 48, lambda x, p: quad_idle(x, R, c, p), True),
                   a.gravar(f"{nome}_Walk", 32, lambda x, p: quad_andar(x, R, c, p, False), True),
                   a.gravar(f"{nome}_Run", 20, lambda x, p: quad_andar(x, R, c, p, True), True),
                   a.gravar(f"{nome}_Attack", 30, lambda x, p: quad_ataque(x, R, c, p), False),
                   a.gravar(f"{nome}_Death", 40, lambda x, p: quad_morte(x, R, c, p, alt_quadril), False)]
    else:
        info = pecas_info(arm)
        feitas += [a.gravar(f"{nome}_Idle", 48, lambda x, p: pecas_idle(x, info, p), True),
                   a.gravar(f"{nome}_Walk", 32, lambda x, p: pecas_andar(x, info, p, False), True),
                   a.gravar(f"{nome}_Run", 20, lambda x, p: pecas_andar(x, info, p, True), True),
                   a.gravar(f"{nome}_Attack", 30, lambda x, p: pecas_ataque(x, info, p), False),
                   a.gravar(f"{nome}_Death", 40, lambda x, p: pecas_morte(x, info, p), False)]
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 49
    arm.animation_data.action = bpy.data.actions[f"{nome}_Walk"]  # abre pronto para dar play; as outras estão nas faixas NLA
    with open(os.path.join(pasta, nome + "_anim.json"), "w", encoding="utf-8") as f:
        json.dump({"nome": nome, "tipo": c["tipo"], "acoes": feitas}, f, ensure_ascii=False, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(pasta, nome + "_anim.blend"))
    return feitas


if __name__ == "__main__" and "--" in sys.argv:
    i = sys.argv.index("--")
    r = main(sys.argv[i + 2])
    print("##ANIM## " + json.dumps(r, ensure_ascii=False))
