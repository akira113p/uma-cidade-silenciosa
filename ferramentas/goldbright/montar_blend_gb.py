"""Monta um .blend (malha única + armadura + ações) a partir de um grupo extraído pelo extrair_gb.py.

Uso (da raiz do projeto):
  blender -b --factory-startup -P ferramentas/goldbright/montar_blend_gb.py -- --grupo "modelos 3d/gold-bright/TT-33__TT33_With_Anims" [--saida "modelos 3d/gold-bright/_blend"] [--previa]

Decisões (docs/gold-bright-import.md):
  * Espaço Unity (esquerdo, Y cima, +Z frente) -> Blender com frente = -Y (convenção dos monstros): (x,y,z)_U -> (-x, -z, y).
  * A ESCALA dos nós (22,5 no Arms_Rig, 100 em TT33_Rig...) é cozida nos vértices; os ossos ficam só com rotação+translação
    (o Roblox ignora escala de osso). Vale porque a escala dos ossos skinados é uniforme e constante nos clipes.
  * Todas as malhas ativas viram UMA malha (um MeshPart), com UM atlas 2x2 de 512 px (braços + atlas das armas). Acessórios
    (laser, luneta, silenciador, estojos, clarão) ficam de fora: EXCLUIR_NOMES.
  * Ações: uma por clipe, a 30 fps, chaves em location + rotation_quaternion (basis do pose bone), como o exportar_rastejador.py lê.
"""

import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

# "Watch": relógio do pulso esquerdo, tirado a pedido do usuário (2026-11-16); a cruz de vida do relógio saiu junto (gerar_config_gb.RELOGIO)
EXCLUIR_NOMES = ("Cube", "Laser", "Muzzle", "Hollow", "Suppressor", "_NV", "RedDot", "Sniper_Scope", "Casing", "_Damaged", "Scope", "Watch")


def arg(nome, padrao=None):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return padrao


GRUPO = os.path.abspath(arg("--grupo"))
NOME = os.path.basename(GRUPO)
SAIDA = os.path.abspath(arg("--saida", os.path.join(os.path.dirname(GRUPO), "_blend")))
os.makedirs(SAIDA, exist_ok=True)

# Unity -> Blender (frente -Y): (x, y, z) -> (-x, -z, y)
C3 = np.array([[-1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=float)
C4 = np.eye(4)
C4[:3, :3] = C3
C4i = np.linalg.inv(C4)

bpy.ops.wm.read_factory_settings(use_empty=True)
rig = json.load(open(os.path.join(GRUPO, "rig.json"), encoding="utf-8"))
malhas = json.load(open(os.path.join(GRUPO, "meshes.json"), encoding="utf-8"))
clipes = json.load(open(os.path.join(GRUPO, "clips.json"), encoding="utf-8"))
N = len(rig)


def quat_mat(q):  # q = (x, y, z, w) Unity
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def euler_zxy_mat(e):  # graus, ordem ZXY do Unity
    ex, ey, ez = [math.radians(a) for a in e]
    cx, sx, cy, sy, cz, sz = math.cos(ex), math.sin(ex), math.cos(ey), math.sin(ey), math.cos(ez), math.sin(ez)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rz @ ry @ rx  # canais Euler dos clipes (FBX, ordem XYZ): conferido contra o repouso do prefab, erro < 0,01 (as outras ordens erram até 1,9)


def trs(p, r3, s):
    m = np.eye(4)
    m[:3, :3] = r3 * np.array(s)[None, :]
    m[:3, 3] = p
    return m


def mundo(frame_locais):
    W = [None] * N
    for i in range(N):
        W[i] = frame_locais[i] if rig[i]["pai"] is None else W[rig[i]["pai"]] @ frame_locais[i]
    return W


rest_local = []
for i, n in enumerate(rig):
    if i == 0:
        rest_local.append(np.eye(4))
    else:
        rest_local.append(trs(n["pos"], quat_mat(n["rot"]), n["esc"]))
W_rest = mundo(rest_local)

# ---------------------------------------------------------------- quais nós viram ossos
# Acessórios por grupo: no jogo eles nascem desligados (o AttachmentSelector liga o que o jogador equipa); aqui fica fixo o que
# a arma do nosso jogo usa. OTs-48K = fuzil de luneta (imagem de referência do usuário): luneta e tubo entram; lentes (vidro e a
# RenderTexture "Scope", sem textura fora do jogo) saem para dar para ver pelo tubo; mira de ferro e silenciador saem.
ACESSORIOS = {
    "OTs-48K__OTs-48K_Rig_With_Idle": {"incluir": ("Sniper_Scope",), "excluir": ("IronSight", "Suppressor")},
}


def incluir_malha(m):
    regra = ACESSORIOS.get(NOME, {})
    tem_textura = any(x.get("textura") for x in (m.get("materiais") or []))
    if any(t in m["nome"] for t in regra.get("excluir", ())):
        return False
    if any(m["nome"].startswith(t) for t in regra.get("incluir", ())):
        return m["ativo"] and tem_textura
    return m["ativo"] and not any(t in m["nome"] for t in EXCLUIR_NOMES)


malhas = [m for m in malhas if incluir_malha(m)]
osso_set = set()


def com_ancestrais(i):
    while i is not None:
        osso_set.add(i)
        i = rig[i]["pai"]


for m in malhas:
    if m.get("ossos"):
        for b in m["ossos"]:
            if b >= 0:
                com_ancestrais(b)
    else:
        pai = rig[m["no"]]["pai"]
        com_ancestrais(pai)
osso_set.add(0)  # nós só animados, sem malha, não viram osso (o rig não incha)
ossos = sorted(osso_set)  # ordem DFS preservada
osso_idx = {n: k for k, n in enumerate(ossos)}


def pai_osso(i):
    p = rig[i]["pai"]
    while p is not None and p not in osso_set:
        p = rig[p]["pai"]
    return p


def nome_osso(i):
    return rig[i]["nome"] if i != 0 else "Raiz"


nomes_usados = set()
nome_b = {}
for i in ossos:
    n = nome_osso(i)
    base, k = n, 2
    while n in nomes_usados:
        n = f"{base}_{k}"
        k += 1
    nomes_usados.add(n)
    nome_b[i] = n


def sem_escala(W):
    """tira a escala (uniforme) de um 4x4 mundo, devolve (RT, escala)."""
    s = np.linalg.norm(W[:3, 0])
    RT = W.copy()
    if s > 1e-9:
        RT[:3, :3] = W[:3, :3] / s
    return RT, s


RT_rest = {}
ESC_rest = {}
for i in ossos:
    RT_rest[i], ESC_rest[i] = sem_escala(W_rest[i])

# ---------------------------------------------------------------- atlas e geometria

tiles = []  # lista de ("arquivo", caminho) ou ("cor", rgba)
tile_de = {}


def tile_para(mat):
    if mat is None:
        chave = ("cor", (128, 128, 128, 255))
    elif mat.get("textura"):
        arq = os.path.join(GRUPO, mat["textura"])
        if "bloody" in arq.lower():  # moderação do Roblox recusou sangue antes: usa o braço limpo
            arq = os.path.join(os.path.dirname(GRUPO), "TT-33__TT33_With_Anims", "tex", "arms.png")
        chave = ("arq", arq)
    else:
        c = mat.get("cor") or [0.5, 0.5, 0.5, 1]
        chave = ("cor", tuple(int(max(0, min(1, x)) * 255) for x in c))
    if chave not in tile_de:
        tile_de[chave] = len(tiles)
        tiles.append(chave)
    return tile_de[chave]


verts, norms, uvs, tris_all = [], [], [], []
juntas, pesos = [], []  # por vértice: lista [(osso_i, peso)]
base_v = 0
for m in malhas:
    V = np.array(m["v"], dtype=float)
    Nn = np.array(m["n"], dtype=float) if m.get("n") else np.zeros_like(V)
    nv = len(V)
    Vh = np.concatenate([V, np.ones((nv, 1))], axis=1)
    if m.get("ossos"):
        bi = np.array(m["bi"]).reshape(nv, -1)
        if m.get("bw"):
            bw = np.array(m["bw"], dtype=float).reshape(nv, -1)
        else:  # um osso só por vértice (o Unity grava sem pesos)
            bw = np.ones((nv, 1))
        if bi.shape[1] < 4:
            bi = np.concatenate([bi, np.zeros((nv, 4 - bi.shape[1]), dtype=bi.dtype)], axis=1)
        if bw.shape[1] < 4:
            bw = np.concatenate([bw, np.zeros((nv, 4 - bw.shape[1]))], axis=1)
        bind = [np.array(b).reshape(4, 4) for b in m["bind"]]
        mats = []
        for k, b in enumerate(m["ossos"]):
            mats.append(W_rest[b] @ bind[k] if b >= 0 else np.eye(4))
        P = np.zeros((nv, 3))
        Nw = np.zeros((nv, 3))
        for j in range(4):
            Mj = np.stack([mats[int(k)] for k in bi[:, j]])
            P += bw[:, j : j + 1] * np.einsum("nij,nj->ni", Mj, Vh)[:, :3]
            Nw += bw[:, j : j + 1] * np.einsum("nij,nj->ni", Mj[:, :3, :3], Nn)
        jj = []
        ww = []
        for vi in range(nv):
            d = {}
            for j in range(4):
                if bw[vi, j] > 1e-5:
                    b_node = m["ossos"][int(bi[vi, j])]
                    d[b_node] = d.get(b_node, 0.0) + bw[vi, j]
            jj.append(list(d.items()))
    else:
        Wm = W_rest[m["no"]]
        P = (Wm @ Vh.T).T[:, :3]
        Nw = (Wm[:3, :3] @ Nn.T).T
        dono = m["no"]
        if dono not in osso_set:
            dono = pai_osso(dono)
        jj = [[(dono, 1.0)] for _ in range(nv)]
    # Unity -> Blender
    Pb = (C3 @ P.T).T
    Nb = (C3 @ Nw.T).T
    ln = np.linalg.norm(Nb, axis=1, keepdims=True)
    Nb = Nb / np.where(ln < 1e-9, 1, ln)
    tile_idx = tile_para(m["materiais"][0] if m.get("materiais") else None)
    uv = np.array(m["uv"], dtype=float) if m.get("uv") else np.zeros((nv, 2))
    verts.append(Pb)
    norms.append(Nb)
    uvs.append(np.concatenate([uv, np.full((nv, 1), tile_idx)], axis=1))
    for sub in m["tris"]:
        for a, b, c in sub:
            tris_all.append((a + base_v, c + base_v, b + base_v))  # reflexão inverte o enrolamento
    juntas.extend(jj)
    base_v += nv

verts = np.concatenate(verts)
norms = np.concatenate(norms)
uvs = np.concatenate(uvs)

# atlas 2x2 de 512 px (API de imagem do Blender; o Python dele não traz Pillow)
ntiles = max(1, len(tiles))
cols = 2 if ntiles > 1 else 1
lin = (ntiles + cols - 1) // cols
TS = 512
W_A, H_A = TS * cols, TS * lin
atl = np.empty((H_A, W_A, 4), dtype=np.float32)
atl[:] = (0.5, 0.5, 0.5, 1.0)
for t, (tipo, val) in enumerate(tiles):
    if tipo == "arq":
        im = bpy.data.images.load(val)
        im.scale(TS, TS)
        buf = np.empty(TS * TS * 4, dtype=np.float32)
        im.pixels.foreach_get(buf)
        bloco = buf.reshape(TS, TS, 4)
        bpy.data.images.remove(im)
    else:
        bloco = np.empty((TS, TS, 4), dtype=np.float32)
        bloco[:] = [x / 255.0 for x in val]
    col, row = t % cols, t // cols  # row 0 = topo do atlas; no Blender a linha 0 do array é a de baixo
    y0 = (lin - 1 - row) * TS
    atl[y0 : y0 + TS, col * TS : (col + 1) * TS] = bloco
caminho_atlas = os.path.join(SAIDA, NOME + "_atlas.png")
img_atlas = bpy.data.images.new("atlas", W_A, H_A, alpha=True)
img_atlas.pixels.foreach_set(atl.reshape(-1))
img_atlas.filepath_raw = caminho_atlas
img_atlas.file_format = "PNG"
img_atlas.save()
tx = uvs[:, 2].astype(int)
u = (tx % cols + uvs[:, 0]) / cols
v = ((lin - 1 - tx // cols) + uvs[:, 1]) / lin  # Blender: origem embaixo; linha 0 do atlas = topo
uv_final = np.stack([u, v], axis=1)

# ---------------------------------------------------------------- cena Blender
cena = bpy.context.scene
cena.render.fps = 30

me = bpy.data.meshes.new("GB_Mesh")
me.from_pydata([tuple(p) for p in verts], [], [tuple(t) for t in tris_all])
me.update()
# normais customizadas por vértice (corner normals)
me.uv_layers.new(name="UVMap")
uvl = me.uv_layers[0]
for li, loop in enumerate(me.loops):
    uvl.data[li].uv = tuple(uv_final[loop.vertex_index])
obj = bpy.data.objects.new("GB_Mesh", me)
cena.collection.objects.link(obj)

mat = bpy.data.materials.new("GB_Atlas")
mat.use_nodes = True
nt = mat.node_tree
nt.nodes.clear()
sal = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(caminho_atlas)
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(bsdf.outputs["BSDF"], sal.inputs["Surface"])
me.materials.append(mat)

# armadura
arm_d = bpy.data.armatures.new("GB_Rig")
arm = bpy.data.objects.new("GB_Rig", arm_d)
cena.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
filho_dist = {}
for i in ossos:
    p = pai_osso(i)
    if p is not None:
        d = np.linalg.norm(RT_rest[i][:3, 3] - RT_rest[p][:3, 3])
        filho_dist[p] = min(filho_dist.get(p, 1e9), d) if d > 1e-4 else filho_dist.get(p, 1e9)
RTB = {}  # RT de repouso em Blender
for i in ossos:
    RTB[i] = C4 @ RT_rest[i] @ C4i
    eb = arm_d.edit_bones.new(nome_b[i])
    pos = RTB[i][:3, 3]
    L = filho_dist.get(i, 0.02)
    L = max(0.004, min(0.05, L * 0.8 if L < 1e8 else 0.02))
    eb.head = Vector(pos)
    eb.tail = Vector(pos + RTB[i][:3, 1] * L)
    eb.matrix = Matrix([list(r) for r in RTB[i]])
    eb.length = L
for i in ossos:
    p = pai_osso(i)
    if p is not None:
        arm_d.edit_bones[nome_b[i]].parent = arm_d.edit_bones[nome_b[p]]
bpy.ops.object.mode_set(mode="OBJECT")

# vertex groups
grupos = {i: obj.vertex_groups.new(name=nome_b[i]) for i in ossos}
for vi, lst in enumerate(juntas):
    soma = sum(w for _, w in lst) or 1.0
    for b_node, w in lst:
        no = b_node
        if no not in osso_set:
            no = pai_osso(no)
        if no is None or no not in grupos:
            continue
        grupos[no].add([vi], w / soma, "ADD")
mod = obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm
obj.parent = arm

# normais personalizadas
try:
    me.normals_split_custom_set_from_vertices([tuple(n) for n in norms])
except Exception as e:  # versões sem a API
    print("normais:", e)

# ---------------------------------------------------------------- ações
def basis_de(P_b, i):
    """P_b: dict osso->4x4 RT mundo (Blender) neste quadro. Devolve (loc, quat) do pose bone."""
    p = pai_osso(i)
    if p is None:
        rel_rest = RTB[i]
        rel_pose = P_b[i]
    else:
        rel_rest = np.linalg.inv(RTB[p]) @ RTB[i]
        rel_pose = np.linalg.inv(P_b[p]) @ P_b[i]
    B = np.linalg.inv(rel_rest) @ rel_pose
    q = Matrix([list(r) for r in B[:3, :3]]).to_quaternion()
    return B[:3, 3], q


arm.animation_data_create()
ordem_acoes = []
for nome_clipe, c in clipes.items():
    nome_a = re.sub(r"[^A-Za-z0-9_]+", "_", nome_clipe).strip("_")
    act = bpy.data.actions.new(nome_a)
    act.use_fake_user = True
    arm.animation_data.action = act
    n_f = c["n"]
    for f in range(n_f):
        locais = []
        for i in range(N):
            if i == 0:
                locais.append(np.eye(4))
                continue
            tr = c["trilhas"].get(str(i), {})
            p = rig[i]["pos"]
            r3 = quat_mat(rig[i]["rot"])
            s = rig[i]["esc"]
            if "pos" in tr:
                p = tr["pos"][f]
            if "rot" in tr:
                r3 = quat_mat(tr["rot"][f])
            elif "euler" in tr:
                r3 = euler_zxy_mat(tr["euler"][f])
            if "esc" in tr:
                s = tr["esc"][f]
            locais.append(trs(p, r3, s))
        W = mundo(locais)
        P_b = {}
        for i in ossos:
            RT, _ = sem_escala(W[i])
            P_b[i] = C4 @ RT @ C4i
        for i in ossos:
            if str(i) not in c["trilhas"]:
                continue  # osso que o clipe não anima: fica de fora (o clipe "mãos" e o "arma" tocam juntos no original)
            loc, q = basis_de(P_b, i)
            pb = arm.pose.bones[nome_b[i]]
            pb.rotation_mode = "QUATERNION"
            pb.location = Vector(loc)
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    act.use_frame_range = True
    act.frame_start = 0
    act.frame_end = n_f - 1
    ordem_acoes.append((nome_a, c["loop"], c["dur"]))
# volta ao repouso
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
arm.animation_data.action = None

dados = {"acoes": {a: {"ciclica": bool(l), "duracao": d} for a, l, d in ordem_acoes}}
json.dump(dados, open(os.path.join(SAIDA, NOME + ".json"), "w", encoding="utf-8"), indent=1)
caminho_blend = os.path.join(SAIDA, NOME + ".blend")
bpy.ops.wm.save_as_mainfile(filepath=caminho_blend)
print("##BLEND##", json.dumps({"blend": caminho_blend, "ossos": len(ossos), "verts": len(verts), "tris": len(tris_all), "tiles": len(tiles), "acoes": len(ordem_acoes)}))

# ---------------------------------------------------------------- prévia
if "--previa" in sys.argv:
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.display.shading.light = "STUDIO"
    cena.display.shading.color_type = "TEXTURE"
    cena.render.resolution_x = 900
    cena.render.resolution_y = 600
    cena.render.film_transparent = False
    mn = verts.min(axis=0)
    mx = verts.max(axis=0)
    centro = (mn + mx) / 2
    tam = float(np.linalg.norm(mx - mn))
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = tam * 1.05
    cam = bpy.data.objects.new("cam", cam_d)
    cena.collection.objects.link(cam)
    cena.camera = cam

    def foto(nome, dir_cam, up=(0, 0, 1)):
        d = Vector(dir_cam).normalized()
        cam.location = Vector(centro) + d * tam * 2
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cena.render.filepath = os.path.join(SAIDA, f"{NOME}_{nome}.png")
        bpy.ops.render.render(write_still=True)

    foto("lado", (1, 0, 0.2))
    foto("cima", (0.2, 0, 1))
    foto("tras", (0, 1, 0.3))

    # quadros de conferência de animação: --pose Acao:quadro[,Acao:quadro...]
    if arg("--pose"):
        for item in arg("--pose").split(","):
            nome_a, quadro = item.split(":")
            arm.animation_data.action = bpy.data.actions[nome_a]
            cena.frame_set(int(quadro))
            bpy.context.view_layer.update()
            foto(f"pose_{nome_a}_{quadro}", (1, 0, 0.2))
