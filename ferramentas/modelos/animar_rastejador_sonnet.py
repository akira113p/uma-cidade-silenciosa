# Animações do Rastejador (quatro patas) com IK + malha medida: Idle, Walk, Run, Attack, Death.
# Lê  modelos 3d/_ps2/Rastejador/Rastejador_rig.blend (só leitura) e grava Rastejador_anim_sonnet.blend.
#   blender -b --factory-startup -P ferramentas/modelos/animar_rastejador_sonnet.py -- build
#   blender -b --factory-startup -P ferramentas/modelos/animar_rastejador_sonnet.py -- render   (quadros + mp4)
# Frente do modelo = -Y, esquerda = +X, cima = +Z, chão em Z=0. Cada mão/pé é um alvo de IK preso ao mundo; o script
# mede a malha avaliada e corrige a altura do alvo para a ponta mais baixa da mão/pé tocar Z=0 na pisada.
# Os quadros-chave gravados são só rotações/posição do quadril (as restrições de IK são removidas antes de salvar).

import math
import os
import shutil
import subprocess
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PASTA = os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador")
ENTRADA = os.path.join(PASTA, "Rastejador_rig.blend")
SAIDA = os.path.join(PASTA, "Rastejador_anim_sonnet.blend")
VIDEOS = os.path.join(PASTA, "videos_sonnet")
FFMPEG = shutil.which("ffmpeg") or "D:/ffmpeg/bin/ffmpeg"

S = lambda x: x * x * (3 - 2 * x)
clamp01 = lambda x: min(max(x, 0.0), 1.0)
lerp = lambda a, b, t: a + (b - a) * t

# centro (x, y) do alvo (ponta do osso) de cada pata na postura neutra
LIMBS = {
    "FL": dict(osso="Hand.L", grupo="Hand.L", N=(1.35, -0.90)),
    "FR": dict(osso="Hand.R", grupo="Hand.R", N=(-0.85, -0.90)),
    "HL": dict(osso="Foot.L", grupo="Foot.L", N=(0.95, 1.20)),
    "HR": dict(osso="Foot.R", grupo="Foot.R", N=(-0.55, 0.15)),
}
FRENTE_Y = -1.0  # sinal de "frente" em Y


class Rig:
    def __init__(self):
        self.arm = bpy.data.objects["Rastejador_Rig"]
        self.mesh = bpy.data.objects["monster_monster_1_0"]
        self.arm.data.pose_position = "POSE"
        self.dirs = {"f": Vector((0, -1, 0)), "b": Vector((0, 1, 0)), "u": Vector((0, 0, 1)), "d": Vector((0, 0, -1)),
                     "l": Vector((1, 0, 0)), "r": Vector((-1, 0, 0))}
        self.rest = {}
        for b in self.arm.data.bones:
            d = b.tail_local - b.head_local
            self.rest[b.name] = (b.matrix_local.to_quaternion(), d.normalized())
        self.q, self.t = {}, {}
        self.corr = {k: 0.0 for k in LIMBS}
        self.emp = {}
        coll = bpy.context.scene.collection
        for k in LIMBS:
            e = bpy.data.objects.new("alvo_" + k, None)
            coll.objects.link(e)
            self.emp[k] = e
            pb = self.arm.pose.bones[LIMBS[k]["osso"]]
            c = pb.constraints.new("IK")
            c.target = e
            c.chain_count = 3
            c.use_tail = True
            c.use_stretch = False
            if k.startswith("H"):  # pé chato: mantém a orientação de repouso do osso (que é horizontal)
                e.rotation_mode = "QUATERNION"
                e.rotation_quaternion = self.arm.data.bones[LIMBS[k]["osso"]].matrix_local.to_quaternion()
                c.use_rotation = True
                c.orient_weight = 1.0
        # máscaras de vértices
        me = self.mesh.data
        n = len(me.vertices)
        grupos = {g.index: g.name for g in self.mesh.vertex_groups}
        self.w = {}
        for v in me.vertices:
            for g in v.groups:
                self.w.setdefault(grupos[g.group], np.zeros(n, np.float32))[v.index] = g.weight
        # máscara da pata = vértices ligados (soma dos pesos > 0.5) a mão/pé + canela/antebraço (+ coxa nas pernas)
        self.mask = {}
        for k in LIMBS:
            lado = LIMBS[k]["osso"].split(".")[1]
            nomes = ["Hand", "LowerArm"] if k.startswith("F") else ["Foot", "LowerLeg", "UpperLeg"]
            tot = sum(self.w[f"{nm}.{lado}"] for nm in nomes)
            self.mask[k] = tot > 0.5
        cont = np.zeros(n, bool)
        for m in self.mask.values():
            cont |= m
        self.corpo = ~cont
        self.n = n
        self.hips_z0 = self.arm.data.bones["Hips"].head_local.z

    # ---- corpo (ossos fora do IK) ----
    def girar(self, osso, direcao, graus):
        q0 = self.q.get(osso, Quaternion())
        d = q0 @ self.rest[osso][1]
        t = self.dirs[direcao]
        t = t - d * d.dot(t)
        if t.length < 1e-4:
            return
        self.q[osso] = Quaternion(d.cross(t.normalized()), math.radians(graus)) @ q0

    def rolar(self, osso, direcao, graus):
        self.q[osso] = Quaternion(self.dirs[direcao], math.radians(graus)) @ self.q.get(osso, Quaternion())

    def mover(self, osso, direcao, m):
        self.t[osso] = self.t.get(osso, Vector()) + self.dirs[direcao] * m

    def aplicar_corpo(self):
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            rr = self.rest[pb.name][0]
            pb.rotation_quaternion = rr.inverted() @ self.q.get(pb.name, Quaternion()) @ rr
            pb.location = rr.inverted() @ self.t.get(pb.name, Vector())

    # ---- medição ----
    def medir(self):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.mesh.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(self.n * 3, np.float32)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        z = co.reshape(-1, 3)[:, 2]
        return z

    def resolver(self, corpo_fn, alvos, autodrop=None, iters=5):
        """corpo_fn(rig) define q/t do corpo; alvos {limb: (x, y, zmin)}; zmin = altura desejada da ponta mais baixa."""
        drop = 0.0
        for it in range(iters):
            self.q, self.t = {}, {}
            corpo_fn(self)
            if drop:
                self.mover("Hips", "d", drop)
            self.aplicar_corpo()
            for k, (x, y, zm) in alvos.items():
                self.emp[k].location = (x, y, zm + self.corr[k])
            z = self.medir()
            for k, (x, y, zm) in alvos.items():
                m = float(z[self.mask[k]].min())
                self.corr[k] = min(max(self.corr[k] + (zm - m), -0.8), 0.8)
            # quadril: sobe se alguma parte atravessa o chão; na morte também desce até a malha tocar o chão
            if autodrop is None:
                drop = min(max(drop + float(z.min()), -0.4), 0.0)
            else:  # morte: o tronco desce até tocar o chão (as patas se dobram por IK)
                drop = min(max(drop + min(float(z[self.corpo].min()), float(z.min()) + 0.06), 0.0), autodrop)
        # um último ajuste já aplicado nos alvos: reaplica e mede
        self.q, self.t = {}, {}
        corpo_fn(self)
        if drop:
            self.mover("Hips", "d", drop)
        self.aplicar_corpo()
        for k, (x, y, zm) in alvos.items():
            self.emp[k].location = (x, y, zm + self.corr[k])
        z = self.medir()
        self.ultimo_z = z
        return z

    def pose_final(self):
        # base (rotation/location) de cada osso a partir das matrizes avaliadas (com IK)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.arm.evaluated_get(dg)
        res = {}
        for b in self.arm.data.bones:
            pb = ev.pose.bones[b.name]
            if b.parent:
                rel = b.parent.matrix_local.inverted() @ b.matrix_local
                basis = rel.inverted() @ ev.pose.bones[b.parent.name].matrix.inverted() @ pb.matrix
            else:
                basis = b.matrix_local.inverted() @ pb.matrix
            res[b.name] = (basis.to_quaternion().normalized(), basis.to_translation())
        return res


# ---------------- receitas: devolvem (corpo_fn, alvos, autodrop) ----------------

def pata_marcha(k, p, off, duty, A, H):
    N = LIMBS[k]["N"]
    q = (p - off) % 1.0
    if q < duty:
        s = q / duty
        y = N[1] - A + 2 * A * s
        z = 0.0
    else:
        u = (q - duty) / (1 - duty)
        y = N[1] + A - 2 * A * S(u)
        z = H * math.sin(math.pi * u)
    return (N[0], y, z)


def receita_andar(p, corrida):
    phi = 2 * math.pi * p
    if corrida:
        duty, Ah, Af, H = 0.5, 0.62, 0.52, 0.42
        offs = {"HL": 0.0, "FR": 0.0, "FL": 0.5, "HR": 0.5}
    else:
        duty, Ah, Af, H = 0.75, 0.40, 0.34, 0.24
        offs = {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}
    alvos = {}
    for k in LIMBS:
        A = Ah if k.startswith("F") else Af
        alvos[k] = pata_marcha(k, p, offs[k], duty, A, H * (1.0 if k.startswith("F") else 0.8))

    def corpo(a):
        bob = 0.07 if corrida else 0.03
        a.mover("Hips", "u", bob * math.cos(4 * phi + (0.4 if corrida else 1.0)))
        a.mover("Hips", "l", (0.07 if corrida else 0.05) * math.sin(phi + 0.5))
        tw = 9 if corrida else 6
        a.girar("Spine", "l", tw * math.sin(phi))
        a.girar("Chest", "l", -tw * 0.8 * math.sin(phi + 0.4))
        a.girar("Spine", "u", (6 if corrida else 2) * math.sin(2 * phi + 0.8))
        if corrida:
            a.girar("Chest", "f", 8)
        a.girar("Neck", "l", 5 * math.sin(phi + 1.0))
        a.girar("Head", "l", 4 * math.sin(phi + 1.6))
        a.girar("Head", "u", 4 * math.sin(2 * phi + 2.0))
    return corpo, alvos, None


def receita_idle(p):
    phi = 2 * math.pi * p
    alvos = {k: (LIMBS[k]["N"][0], LIMBS[k]["N"][1], 0.0) for k in LIMBS}
    # a mão esquerda coça o chão de leve uma vez por ciclo
    g = max(0.0, math.sin(phi)) ** 2
    alvos["FL"] = (LIMBS["FL"]["N"][0] - 0.12 * g, LIMBS["FL"]["N"][1] - 0.10 * g, 0.10 * g)

    def corpo(a):
        a.mover("Hips", "u", 0.02 * math.sin(phi))
        a.mover("Hips", "l", 0.015 * math.sin(phi + 1.0))
        a.girar("Spine", "u", 2.5 * math.sin(phi))
        a.girar("Chest", "u", 3.0 * math.sin(phi + 0.4))
        a.girar("Spine", "l", 2.0 * math.sin(phi + 2.0))
        a.girar("Neck", "l", 9 * math.sin(phi + 1.0))
        a.girar("Head", "l", 10 * math.sin(phi + 2.0))
        a.girar("Head", "u", 4 * math.sin(2 * phi))
    return corpo, alvos, None


def receita_ataque(p):
    wa = S(clamp01(p / 0.33))
    ks = S(clamp01((p - 0.33) / 0.14))
    kr = S(clamp01((p - 0.56) / 0.44))
    W = {"FL": (1.55, -0.15, 1.35), "FR": (-1.05, -0.15, 1.25)}
    St = {"FL": (0.85, -2.05, 0.05), "FR": (-0.30, -2.05, 0.05)}
    alvos = {}
    for k in LIMBS:
        N = LIMBS[k]["N"]
        n3 = (N[0], N[1], 0.0)
        if k in W:
            delay = 0.0 if k == "FL" else 0.06
            ks2 = S(clamp01((p - 0.33 - delay) / 0.14))
            p0 = tuple(lerp(n3[i], W[k][i], wa) for i in range(3))
            p1 = tuple(lerp(p0[i], St[k][i], ks2) for i in range(3))
            p2 = tuple(lerp(p1[i], n3[i], kr) for i in range(3))
            alvos[k] = p2
        else:
            alvos[k] = n3

    def corpo(a):
        a.mover("Hips", "u", 0.28 * wa * (1 - ks) - 0.10 * ks * (1 - kr))
        a.mover("Hips", "b", 0.25 * wa * (1 - ks))
        a.mover("Hips", "f", 0.60 * ks * (1 - kr))
        a.girar("Spine", "u", 14 * wa * (1 - ks))
        a.girar("Chest", "u", 14 * wa * (1 - ks))
        a.girar("Chest", "f", 22 * ks * (1 - kr))
        a.girar("Neck", "u", 15 * wa * (1 - ks))
        a.girar("Head", "u", 25 * wa * (1 - ks))
        a.girar("Head", "d", 30 * ks * (1 - kr))
    return corpo, alvos, None


def receita_morte(p):
    e = S(p)
    e2 = S(clamp01((p - 0.12) / 0.88))
    alvos = {
        "FR": (lerp(LIMBS["FR"]["N"][0], -1.55, e), lerp(LIMBS["FR"]["N"][1], -1.45, e), 0.0),
        "FL": (lerp(LIMBS["FL"]["N"][0], 1.80, e2), lerp(LIMBS["FL"]["N"][1], -1.35, e2), 0.0),
        "HR": (lerp(LIMBS["HR"]["N"][0], -1.00, e), lerp(LIMBS["HR"]["N"][1], 0.75, e), 0.0),
        "HL": (lerp(LIMBS["HL"]["N"][0], 1.55, e2), lerp(LIMBS["HL"]["N"][1], 1.35, e2), 0.0),
    }

    def corpo(a):
        a.rolar("Hips", "f", 55 * e2)
        a.girar("Spine", "d", 10 * e)
        a.girar("Neck", "d", 20 * e)
        a.girar("Head", "l", 30 * e)
    return corpo, alvos, 1.2 * e


# ---------------- gravação ----------------

def gravar(rig, nome, n, receita, ciclica):
    total = n + 1 if ciclica else n
    rig.corr = {k: 0.0 for k in LIMBS}
    res = {}
    passes = 2 if ciclica else 3  # aquece as correções (primeira volta descartada)
    for pas in range(passes):
        res = {}
        for i in range(total):
            p = (i % n) / n if ciclica else i / max(n - 1, 1)
            corpo, alvos, drop = receita(p)
            z = rig.resolver(corpo, alvos, drop)
            r = rig.pose_final()
            r["_minz"] = float(z.min())
            iv = int(z.argmin())
            r["_quem"] = max(self.w and rig.w, key=lambda g: rig.w[g][iv]) if False else max(rig.w, key=lambda g: rig.w[g][iv])
            r["_hipsz"] = rig.arm.evaluated_get(bpy.context.evaluated_depsgraph_get()).pose.bones["Hips"].head.z
            r["_alvos"] = {k: tuple(rig.emp[k].location) for k in LIMBS}
            res[i + 1] = r
    if ciclica:
        res[total] = res[1]
    return res


def inserir(rig, nome, res, ciclica):
    arm = rig.arm
    act = bpy.data.actions.new(nome)
    arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_slot is None and getattr(act, "slots", None):
        arm.animation_data.action_slot = act.slots[0]
    for frame, r in res.items():
        for b in arm.data.bones:
            pb = arm.pose.bones[b.name]
            pb.rotation_mode = "QUATERNION"
            q, t = r[b.name]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if b.name == "Hips":
                pb.location = t
                pb.keyframe_insert("location", frame=frame)
    act.use_fake_user = True
    if hasattr(act, "use_cyclic"):
        act.use_cyclic = ciclica
    return act


def construir():
    bpy.ops.wm.open_mainfile(filepath=ENTRADA)
    arm0 = bpy.data.objects["Rastejador_Rig"]
    bpy.context.view_layer.objects.active = arm0  # o arquivo do usuário foi salvo com a armadura em modo de edição
    if arm0.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    rig = Rig()
    receitas = [("Idle", 48, receita_idle, True), ("Walk", 24, lambda p: receita_andar(p, False), True),
                ("Run", 16, lambda p: receita_andar(p, True), True), ("Attack", 30, receita_ataque, False),
                ("Death", 40, receita_morte, False)]
    todos = {}
    for nome, n, fn, cic in receitas:
        todos["Rastejador_" + nome] = (gravar(rig, nome, n, fn, cic), cic)
    # remove IK e alvos antes de inserir chaves (as chaves já são a pose final)
    for k in LIMBS:
        pb = rig.arm.pose.bones[LIMBS[k]["osso"]]
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        bpy.data.objects.remove(rig.emp[k])
    for pb in rig.arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    stats = {}
    for nome, (res, cic) in todos.items():
        act = inserir(rig, nome, res, cic)
        frames = sorted(res)
        pior = min(res.values(), key=lambda r: r["_minz"])
        stats[nome] = dict(quadros=len(frames), min_z=round(pior["_minz"], 3), quem=pior["_quem"],
                           ciclica=cic, abaixo_de_menos_2cm=[f for f, r in res.items() if r["_minz"] < -0.02][:12])
    rig.arm.animation_data.action = bpy.data.actions["Rastejador_Walk"]
    if hasattr(rig.arm.animation_data, "action_slot") and rig.arm.animation_data.action_slot is None:
        rig.arm.animation_data.action_slot = bpy.data.actions["Rastejador_Walk"].slots[0]
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 25
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    for nome, s in stats.items():
        print("##STAT##", nome, s)


# ---------------- verificação: quadros e vídeos a partir do arquivo salvo ----------------

def preparar_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "OBJECT"
    sc.display.shading.show_cavity = False
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w") if not sc.world else sc.world
    sc.world.color = (0.85, 0.88, 0.95)
    bpy.data.objects["monster_monster_1_0"].color = (0.78, 0.74, 0.62, 1)
    bpy.data.objects["Rastejador_Rig"].hide_render = True
    # chão em Z=0 com faixas a cada 0.5 m em Y e uma marca de X=0
    me = bpy.data.meshes.new("chao")
    me.from_pydata([(x, y, z) for z in (0, -0.3) for (x, y) in ((-6, -6), (6, -6), (6, 6), (-6, 6))], [],
                   [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    ch = bpy.data.objects.new("chao", me)
    ch.color = (0.28, 0.33, 0.28, 1)
    sc.collection.objects.link(ch)
    for i in range(-10, 11):
        m2 = bpy.data.meshes.new("l")
        y = i * 0.5
        w = 0.025
        m2.from_pydata([(-6, y - w, 0.004), (6, y - w, 0.004), (6, y + w, 0.004), (-6, y + w, 0.004)], [], [(0, 1, 2, 3)])
        o = bpy.data.objects.new("l", m2)
        o.color = (0.9, 0.9, 0.9, 1) if i % 2 == 0 else (0.6, 0.6, 0.6, 1)
        sc.collection.objects.link(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    return cam


def renderizar(so_quadros=False):
    bpy.ops.wm.open_mainfile(filepath=SAIDA)
    cam = preparar_render()
    arm = bpy.data.objects["Rastejador_Rig"]
    sc = bpy.context.scene
    os.makedirs(VIDEOS, exist_ok=True)
    tmp = os.path.join(VIDEOS, "_q")
    for nome in ("Idle", "Walk", "Run", "Attack", "Death"):
        act = bpy.data.actions["Rastejador_" + nome]
        arm.animation_data.action = act
        if getattr(arm.animation_data, "action_slot", None) is None and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        cic = nome in ("Idle", "Walk", "Run")
        if cic:
            f1 -= 1
        vistas = [("lado", (14, 0.3, 1.1), (90, 0, 90), 6.2)] + ([] if so_quadros else [("topo", (0.3, 0.3, 14), (0, 0, 0), 6.2)])
        for vn, loc, rot, esc in vistas:
            cam.location = loc
            cam.rotation_euler = [math.radians(r) for r in rot]
            cam.data.ortho_scale = esc
            d = os.path.join(tmp, f"{nome}_{vn}")
            shutil.rmtree(d, ignore_errors=True)
            os.makedirs(d)
            for f in range(f0, f1 + 1):
                sc.frame_set(f)
                sc.render.filepath = os.path.join(d, f"{f - f0:03d}.png")
                bpy.ops.render.render(write_still=True)
            n = f1 - f0 + 1
            # folha de quadros
            passo = max(1, -(-n // 12))
            sel = os.path.join(d, "folha.png")
            subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-framerate", "1", "-i", os.path.join(d, "%03d.png"),
                            "-vf", f"select='not(mod(n,{passo}))',scale=320:-1,tile=4x3", "-frames:v", "1", sel], check=False)
            if vn == "lado":
                loops = ["-stream_loop", "2"] if cic else []
                subprocess.run([FFMPEG, "-y", "-loglevel", "error", *loops, "-framerate", "12", "-i", os.path.join(d, "%03d.png"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", os.path.join(VIDEOS, f"Rastejador_{nome}.mp4")], check=False)
    print("##RENDER## ok")


if __name__ == "__main__" and "--" in sys.argv:
    modo = sys.argv[sys.argv.index("--") + 1]
    if modo == "build":
        construir()
    else:
        renderizar(so_quadros=(modo == "quadros"))
