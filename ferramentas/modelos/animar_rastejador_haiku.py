# Animações do Rastejador (quatro patas). Lê Rastejador_rig.blend (só leitura) e grava Rastejador_anim_haiku.blend.
# Nada vai ao Roblox. Uso:
#   blender -b --factory-startup -P ferramentas/modelos/animar_rastejador_haiku.py -- --construir
#   blender -b --factory-startup -P ferramentas/modelos/animar_rastejador_haiku.py -- --render PASTA_PNG
#
# Como funciona: cada pata é uma cadeia de 3 ossos (ombro/quadril -> cotovelo/joelho -> pulso/tornozelo -> pata).
# O pulso/tornozelo segue um alvo no chão (Z=0) por IK de duas juntas; a pata fica plana, apontando para a frente.
# O corpo (quadril, coluna, peito, pescoço, cabeça) recebe giros em torno da própria cabeça do osso.
# Depois de cada quadro mede-se o ponto mais baixo da malha (já deformada pela armadura): nunca abaixo de Z=0.
# Frente do modelo = -Y (o osso Head aponta para -Y). Lado L = +X.

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ".", "..", ".."))
PASTA = os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador")
ENTRADA = os.path.join(PASTA, "Rastejador_rig.blend")
SAIDA = os.path.join(PASTA, "Rastejador_anim_haiku.blend")
FPS = 12

F = Vector((0, -1, 0))  # frente
U = Vector((0, 0, 1))
X = Vector((1, 0, 0))  # lado L = +X
POLO = Vector((0, 1, 0.3))  # cotovelo apontam para trás
POLO_PATRAS = Vector((0, 0.6, 1.0))  # joelho traseiro dobra para trás e para cima (o jarrete fica acima do chão)

HIPS, SPINE, CHEST, NECK, HEAD = "Hips", "Spine", "Chest", "Neck", "Head"
PERNAS = {  # (osso alto, osso médio, osso da pata)
    "FL": ("UpperArm.L", "LowerArm.L", "Hand.L"),
    "FR": ("UpperArm.R", "LowerArm.R", "Hand.R"),
    "HL": ("UpperLeg.L", "LowerLeg.L", "Foot.L"),
    "HR": ("UpperLeg.R", "LowerLeg.R", "Foot.R"),
}
NEUTRO = {  # pontos de apoio no chão, simétricos em torno de X=0.265 (centro do rig)
    "FL": Vector((1.115, -0.75, 0)), "FR": Vector((-0.585, -0.75, 0)),
    "HL": Vector((1.115, 0.75, 0)), "HR": Vector((-0.585, 0.75, 0)),
}
# fase de cada pata no ciclo: marcha = lateral (HR, FR, HL, FL); trote = diagonais juntas
FASE = {
    False: {"HR": 0.0, "FR": 0.25, "HL": 0.5, "FL": 0.75},
    True: {"HR": 0.0, "FL": 0.0, "HL": 0.5, "FR": 0.5},
}
MARCHA = {  # T quadros; beta = fração do ciclo com a pata no chão; S = curso (m do modelo); H = altura do passo
    False: dict(T=24, beta=0.6, S=0.5, H=0.2, bob=0.02, arco=1.5, cab=3.0),
    True: dict(T=16, beta=0.42, S=0.8, H=0.35, bob=0.04, arco=3.0, cab=8.0),
}

ZAS = {n: 0.0 for n in PERNAS}  # altura do tornozelo/pulso de cada pata quando ela toca o chão (calibrada em calibrar())
_metricas = {}
_POR_PATA = None
ZAS_BASE = {n: 0.0 for n in PERNAS}
TETO_CORPO = 0.35  # quanto o corpo pode subir para tirar partes (jarrete) do chão; acima disso as patas perdem alcance


def suave(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


class Esqueleto:
    """Pose por ossos: guarda o 'basis' de cada osso e calcula a matriz da armadura por cinemática direta."""

    def __init__(self, arm):
        self.arm = arm
        self.rest, self.pai, self.restrel, self.comp = {}, {}, {}, {}
        for b in arm.data.bones:
            self.rest[b.name] = b.matrix_local.copy()
            self.pai[b.name] = b.parent.name if b.parent else None
            self.comp[b.name] = b.length
        for n in self.rest:
            p = self.pai[n]
            self.restrel[n] = self.rest[p].inverted() @ self.rest[n] if p else self.rest[n].copy()
        self.basis, self.cache = {}, {}
        self.fora = 0.0  # quanto alguma pata ficou fora do alcance (m)

    def reset(self):
        self.basis, self.cache = {}, {}
        self.fora = 0.0

    def fk(self, n):
        if n is None:
            return Matrix.Identity(4)
        if n not in self.cache:
            self.cache[n] = self.fk(self.pai[n]) @ self.restrel[n] @ self.basis.get(n, Matrix.Identity(4))
        return self.cache[n]

    def set_mat(self, n, M):
        ref = self.fk(self.pai[n]) @ self.restrel[n]
        self.basis[n] = ref.inverted() @ M
        self.cache = {}

    def rot(self, n, eixo, graus):
        # gira o osso 'n' em torno da própria cabeça, eixo em coordenadas da armadura (positivo = cabeça para baixo se eixo=X)
        if abs(graus) < 1e-9:
            return
        M = self.fk(n)
        h = M.translation
        R = Matrix.Rotation(math.radians(graus), 4, eixo.normalized())
        self.set_mat(n, Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M)

    def mover(self, n, vetor):
        M = self.fk(n)
        self.set_mat(n, Matrix.Translation(vetor) @ M)

    def _mat_dir(self, n, origem, direcao):
        r = self.rest[n].to_3x3()
        y0 = Vector(r.col[1]).normalized()
        rot = y0.rotation_difference(direcao.normalized()).to_matrix().to_4x4()
        return Matrix.Translation(origem) @ rot @ r.to_4x4()

    def ik(self, alto, medio, pata, alvo, polo):
        # duas juntas (alto + médio) levam o pulso/tornozelo ao 'alvo'; a pata fica plana, apontando para frente
        R = (self.fk(self.pai[alto]) @ self.restrel[alto]).translation
        L1, L2 = self.comp[alto], self.comp[medio]
        v = alvo - R
        if v.length > L1 + L2:
            self.fora = max(self.fora, v.length - (L1 + L2))
        d = min(max(v.length, abs(L1 - L2) + 1e-3), L1 + L2 - 1e-3)
        u = v.normalized()
        T = R + u * d
        a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
        h = math.sqrt(max(L1 * L1 - a * a, 0.0))
        pp = (polo - u * polo.dot(u)).normalized()
        E = R + u * a + pp * h
        self.set_mat(alto, self._mat_dir(alto, R, (E - R)))
        self.set_mat(medio, self._mat_dir(medio, E, (T - E)))
        self.set_mat(pata, self._mat_dir(pata, T, F))

    def aplicar(self, arm_pb):
        for pb in arm_pb:
            m = self.basis.get(pb.name, Matrix.Identity(4))
            pb.rotation_mode = "QUATERNION"
            pb.location = m.to_translation()
            pb.rotation_quaternion = m.to_quaternion()
        forcar_pose(self.arm)


def forcar_pose(arm):
    # Em -b, a malha só reavalia a pose depois de um ciclo Pose -> Objeto (medido: sem isso a malha fica na pose de repouso)
    vl = bpy.context.view_layer
    vl.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    vl.update()


def indices_patas(malha):
    # vértices com peso >= 0.3 no osso da pata (garra/pé): só eles são checados contra o chão nas ações de pé
    por_pata = {}
    for nome, (_, _, pata) in PERNAS.items():
        idx = set()
        for v in malha.data.vertices:
            if sum(g.weight for g in v.groups if malha.vertex_groups[g.group].name == pata) >= 0.3:
                idx.add(v.index)
        por_pata[nome] = idx
    return por_pata


def malha_zmin(malha, indices=None):
    # ponto mais baixo da malha já deformada (em coordenadas do mundo); indices limita a conjuntos de vértices
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = malha.evaluated_get(dg)
    me = ev.to_mesh()
    zs = [(ev.matrix_world @ me.vertices[i].co).z for i in (indices if indices is not None else range(len(me.vertices)))]
    ev.to_mesh_clear()
    return min(zs)


def passo(q, c):
    # q em 0..1 (fase da pata). Apoio: curso linear para trás. Balanço: volta suave com arco.
    b, S, H = c["beta"], c["S"], c["H"]
    if q < b:
        return S / 2 - S * (q / b), 0.0
    v = (q - b) / (1 - b)
    return -S / 2 + S * suave(v), H * math.sin(math.pi * v)


# ---------------- ações ----------------

def pose_pernas(e, alvos):
    for nome, (alto, medio, pata) in PERNAS.items():
        e.ik(alto, medio, pata, alvos[nome], POLO_PATRAS if nome.startswith("H") else POLO)


def f_marcha(e, c, corrida):
    def f(p, dz):
        ph = 2 * math.pi * p
        e.mover(HIPS, U * (dz + c["bob"] * math.cos(2 * ph)))
        e.rot(HIPS, F, c["arco"] * math.sin(ph))
        e.rot(CHEST, F, -c["arco"] * math.sin(ph))
        e.rot(CHEST, X, c["cab"])
        e.rot(NECK, U, 3 * math.sin(ph + 1))
        e.rot(HEAD, U, 3 * math.sin(ph + 2))
        alvos = {}
        for nome in PERNAS:
            q = (p + FASE[corrida][nome]) % 1.0
            s, lift = passo(q, c)
            alvos[nome] = NEUTRO[nome] + F * s + U * (ZAS[nome] + lift)
        pose_pernas(e, alvos)
    return f


def f_parado(e):
    def f(p, dz):
        ph = 2 * math.pi * p
        e.mover(HIPS, U * (dz + 0.01 * (0.5 + 0.5 * math.cos(ph))))
        e.rot(CHEST, X, 1.2 * math.sin(ph))
        e.rot(NECK, U, 4 * math.sin(ph * 0.5 + 1))
        e.rot(HEAD, U, 4 * math.sin(ph * 0.5 + 2))
        e.rot(HEAD, X, 2 * math.sin(ph + 0.5))
        alvos = {n: NEUTRO[n] + U * ZAS[n] for n in PERNAS}
        pose_pernas(e, alvos)
    return f


def f_ataque(e):
    def f(p, dz):
        w = suave(min(p / 0.33, 1.0)) * (1.0 - suave(min(max((p - 0.33) / 0.2, 0.0), 1.0)))  # armar
        s = suave(min(max((p - 0.33) / 0.2, 0.0), 1.0)) * (1.0 - suave(min(max((p - 0.6) / 0.4, 0.0), 1.0)))  # golpe
        e.mover(HIPS, U * dz)
        e.rot(CHEST, X, -10 * w + 8 * s)
        e.rot(NECK, X, -15 * w + 35 * s)
        e.rot(HEAD, X, -10 * w + 25 * s)
        alvos = {n: NEUTRO[n] + U * ZAS[n] for n in PERNAS}
        for n in ("FL", "FR"):
            alvos[n] = NEUTRO[n] + F * (0.6 * s) + U * (ZAS[n] + 0.6 * w)
        pose_pernas(e, alvos)
    return f


def f_morte(e):
    def f(p, dz):
        k = suave(p)
        e.mover(HIPS, U * dz)
        eixo = Vector(e.rest[HIPS].to_3x3().col[1]).normalized()
        e.rot(HIPS, eixo, 85 * k)
        e.rot(NECK, X, 25 * k)
        e.rot(HEAD, X, 10 * k)
        alvos = {
            "FL": NEUTRO["FL"] + X * (0.4 * k) + U * ZAS["FL"],
            "FR": NEUTRO["FR"] - X * (0.4 * k) + U * ZAS["FR"],
            "HL": NEUTRO["HL"] + X * (0.3 * k) + U * ZAS["HL"],
            "HR": NEUTRO["HR"] - X * (0.3 * k) + U * ZAS["HR"],
        }
        pose_pernas(e, alvos)
    return f


def resolver(e, malha, fn, p, modo):
    # Por quadro: (1) cada perna sobe o próprio alvo do pulso/tornozelo até a garra ficar em Z>=0;
    # (2) o corpo sobe pouco (até 0.15) se alguma parte ainda estiver abaixo do chão. 'contato' (morte): o ponto
    # mais baixo do corpo vai para Z=0 nos dois sentidos.
    base = dict(ZAS_BASE)
    delta = {n: 0.0 for n in PERNAS}
    dz, mp, mg = 0.0, {}, 0.0
    for _ in range(8):
        for n in PERNAS:
            ZAS[n] = base[n] + delta[n]
        e.reset()
        fn(p, dz)
        e.aplicar(e.arm.pose.bones)
        mp = {n: malha_zmin(malha, sorted(_POR_PATA[n])) for n in PERNAS}
        mg = malha_zmin(malha)
        mexeu = False
        for n in PERNAS:
            if mp[n] < -2e-4:
                delta[n] += -mp[n]
                mexeu = True
        if modo == "contato" and abs(mg) > 2e-4:
            dz += -mg
            mexeu = True
        elif modo == "subir" and mg < -2e-4 and dz < TETO_CORPO:
            dz += min(-mg, 0.05)
            mexeu = True
        if not mexeu:
            break
    return dz, mp, mg


def gravar(e, malha, nome, n, ciclica, fn, modo):
    arm = e.arm
    quadros = {}
    total = n + 1 if ciclica else n
    zs, dzs, zg = [], [], []
    for i in range(total):
        p = (i % n) / n if ciclica else i / max(n - 1, 1)
        dz, mp, mg = resolver(e, malha, fn, p, modo)
        zs.append(min(mp.values()))
        dzs.append(dz)
        zg.append(mg)
        snap = {}
        for osso in e.rest:
            m = e.basis.get(osso, Matrix.Identity(4))
            snap[osso] = (m.to_translation(), m.to_quaternion())
        quadros[i + 1] = snap
        _metricas.setdefault(nome, {})["fora_alcance_m"] = round(e.fora, 4)
    act = bpy.data.actions.new(nome)
    arm.animation_data_create()
    arm.animation_data.action = act
    prev = {}
    for frame, snap in quadros.items():
        for osso, (loc, q) in snap.items():
            pb = arm.pose.bones[osso]
            if osso in prev and prev[osso].dot(q) < 0:
                q = -q
            prev[osso] = q
            pb.rotation_mode = "QUATERNION"
            pb.location = loc
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    act.use_fake_user = True
    if hasattr(act, "use_cyclic"):
        act.use_cyclic = ciclica
    arm.animation_data.action = None
    faixa = arm.animation_data.nla_tracks.new()
    faixa.name = nome
    faixa.strips.new(nome, 1, act)
    faixa.mute = True
    _metricas[nome].update({
        "quadros": total, "ciclica": ciclica,
        "zmin_patas_min": round(min(zs), 5), "zmin_patas_max": round(max(zs), 5), "zmin_todo_corpo_min": round(min(zg), 5),
        "ajuste_corpo_max": round(max(dzs), 4), "ajuste_corpo_min": round(min(dzs), 4),
    })
    return act


def calibrar(e, malha):
    # Por pata: a parte mais baixa das garras/pés (indices_patas) fica em Z=0 com o pulso/tornozelo no apoio.
    global ZAS, ZAS_BASE, _POR_PATA
    ZAS = {n: 0.0 for n in PERNAS}
    _POR_PATA = indices_patas(malha)
    e.reset()
    pose_pernas(e, {n: NEUTRO[n] for n in PERNAS})
    e.aplicar(e.arm.pose.bones)
    for nome in PERNAS:
        ZAS[nome] = -malha_zmin(malha, sorted(_POR_PATA[nome]))
    ZAS_BASE = dict(ZAS)
    return ZAS


def construir():
    bpy.ops.wm.open_mainfile(filepath=ENTRADA)
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = FPS, 1.0
    arm = bpy.data.objects["Rastejador_Rig"]
    malha = bpy.data.objects["monster_monster_1_0"]
    arm.data.pose_position = "POSE"
    e = Esqueleto(arm)
    zas = calibrar(e, malha)
    _metricas["_altura_pernas"] = {k: round(v, 5) for k, v in zas.items()}
    gravar(e, malha, "Rastejador_Idle", 48, True, f_parado(e), "subir")
    gravar(e, malha, "Rastejador_Walk", 24, True, f_marcha(e, MARCHA[False], False), "subir")
    gravar(e, malha, "Rastejador_Run", 16, True, f_marcha(e, MARCHA[True], True), "subir")
    gravar(e, malha, "Rastejador_Attack", 30, False, f_ataque(e), "subir")
    gravar(e, malha, "Rastejador_Death", 40, False, f_morte(e), "contato")
    # deslize: no apoio o pé anda o curso S em (beta*T) quadros; sem movimento de raiz, isso é o deslize na animação
    for nome, c in ((("Rastejador_Walk"), MARCHA[False]), (("Rastejador_Run"), MARCHA[True])):
        tempo = c["beta"] * c["T"] / FPS
        _metricas[nome]["deslize_apoio_m_por_s"] = round(c["S"] / tempo, 3)
    e.reset()
    e.aplicar(arm.pose.bones)
    arm.animation_data.action = bpy.data.actions["Rastejador_Walk"]
    sc.frame_start, sc.frame_end = 1, MARCHA[False]["T"] + 1
    sc.frame_set(1)
    os.makedirs(os.path.join(PASTA, "videos_haiku"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    print("##RASTEJADOR## " + json.dumps(_metricas, ensure_ascii=False))


def renderizar(pasta):
    bpy.ops.wm.open_mainfile(filepath=SAIDA)
    sc = bpy.context.scene
    arm = bpy.data.objects["Rastejador_Rig"]
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = 640, 360
    sc.render.image_settings.file_format = "PNG"
    cam_d = bpy.data.cameras.new("CamLado")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 5.6
    cam = bpy.data.objects.new("CamLado", cam_d)
    sc.collection.objects.link(cam)
    cam.location = (8.0, 0.0, 1.2)
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))  # olha para -X: cabeça (−Y) à esquerda
    sc.camera = cam
    chao = bpy.data.meshes.new("Chao")
    chao.from_pydata([(-4, -4, 0), (4, -4, 0), (4, 4, 0), (-4, 4, 0)], [], [(0, 1, 2, 3)])
    ch = bpy.data.objects.new("Chao", chao)
    sc.collection.objects.link(ch)
    ch.display_type = "WIRE"
    os.makedirs(pasta, exist_ok=True)
    for nome in ("Idle", "Walk", "Run", "Attack", "Death"):
        act = bpy.data.actions[f"Rastejador_{nome}"]
        arm.animation_data.action = act
        n = int(act.frame_range[1] - act.frame_range[0]) + 1
        if act.use_cyclic if hasattr(act, "use_cyclic") else False:
            n = n - 1
        for f in range(1, n + 1):
            sc.frame_set(f)
            forcar_pose(arm)
            sc.render.filepath = os.path.join(pasta, f"{nome}_{f:03d}.png")
            bpy.ops.render.render(write_still=True)
        print(f"##RENDER## {nome} {n} quadros")
    # Morte vista de frente: o tombamento (giro em torno do eixo do corpo) não aparece de lado
    cam.location = (0.0, -8.0, 1.2)
    cam.rotation_euler = (math.radians(90), 0, 0)
    arm.animation_data.action = bpy.data.actions["Rastejador_Death"]
    for f in range(1, 41):
        sc.frame_set(f)
        forcar_pose(arm)
        sc.render.filepath = os.path.join(pasta, f"DeathFrente_{f:03d}.png")
        bpy.ops.render.render(write_still=True)
    print("##RENDER## DeathFrente 40 quadros")
    arm.animation_data.action = None


if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    if args and args[0] == "--construir":
        construir()
    elif len(args) >= 2 and args[0] == "--render":
        renderizar(args[1])
