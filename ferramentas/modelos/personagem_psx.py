"""Personagem humanoide PSX -> FBX de 15 malhas (uma por peca R15) + textura + manifesto. Nada vai ao Roblox.

Uso (da raiz do repo):
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --factory-startup -P ferramentas/modelos/personagem_psx.py -- \
      --input "<arquivo.fbx>" --id office_worker [--saida "modelos 3d/personagens"] [--fonte "..."] [--licenca "..."] [--credito "..."]
      [--studs-por-metro 2.9078] [--altura-metros 1.8] [--textura <png>] [--pose baixa|aberta] [--sem-previa]

O que faz (contrato em docs/personagens.md, Parte M):
  1. Importa o FBX, acha a armature, imprime ossos e vertices por osso dominante.
  2. Junta as malhas (cabelo, mochila etc. entram pelo osso delas) e divide por osso dominante -> peca R15:
     Hips->LowerTorso, Spine/Chest->UpperTorso, Head/Neck/Hair->Head, Arm/ForeArm/Hand e UpLeg/Leg/Foot por lado.
  3. Pose "baixa" (padrao): os bracos (rigidos, em T) giram nas juntas ate pender na vertical, como o R15 do Roblox,
     porque o Lua estica cada malha para o tamanho da peca R15 (um braco horizontal esticado numa caixa vertical ficaria torto).
  4. Escala nos DADOS (o Roblox desfaz o global_scale do FBX), pes em z=0, origem de cada peca no CENTRO DA CAIXA dela
     (o MeshPart do Roblox fica centrado na caixa; o objeto guarda a posicao de montagem, entao o FBX monta o boneco inteiro).
  5. Recorta o atlas para a pagina do personagem (<= 256 px), refaz a UV, sem armature, sem animacao, sem pele.
  6. Valida (15 pecas, nao vazias, <= 1000 tris), exporta <saida>/<id>/<id>.fbx + <id>.png + <id>.json,
     reimporta o FBX para conferir nomes/tamanhos e renderiza <id>/previa.png (frente, 3/4, perfil).

Eixos: Blender Z cima, -Y frente (o personagem do psx-people olha para -Y). Ponto no Roblox = (-x, z, y) do Blender (medido
no projeto com a Beretta; frente vira -Z, o lado esquerdo do personagem, +X no Blender, vira -X). tamanhoNativo = (dx, dz, dy) do Blender.
Armadilhas do projeto respeitadas: view_layer.update() antes de ler matrix_world; escala nos vertices, nao no exportador;
FBX (GLB nao entra no Roblox); o original em psx sttuff nunca e alterado (so leitura).
"""

import json
import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))

PECAS = [
    "Head",
    "UpperTorso",
    "LowerTorso",
    "LeftUpperArm",
    "LeftLowerArm",
    "LeftHand",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperLeg",
    "LeftLowerLeg",
    "LeftFoot",
    "RightUpperLeg",
    "RightLowerLeg",
    "RightFoot",
]
MAX_TRIS = 1000
MAX_TEX = 256
ALTURA_JOGADOR_M = 1.8  # Config/Aparencia: 5,234 studs = 1,8 m -> 2,9078 studs por metro
STUDS_POR_METRO = 5.234 / ALTURA_JOGADOR_M

# pares vizinhos para medir folga (buraco) na montagem
VIZINHOS = [
    ("LowerTorso", "UpperTorso"),
    ("UpperTorso", "Head"),
    ("UpperTorso", "LeftUpperArm"),
    ("UpperTorso", "RightUpperArm"),
    ("LeftUpperArm", "LeftLowerArm"),
    ("LeftLowerArm", "LeftHand"),
    ("RightUpperArm", "RightLowerArm"),
    ("RightLowerArm", "RightHand"),
    ("LowerTorso", "LeftUpperLeg"),
    ("LowerTorso", "RightUpperLeg"),
    ("LeftUpperLeg", "LeftLowerLeg"),
    ("LeftLowerLeg", "LeftFoot"),
    ("RightUpperLeg", "RightLowerLeg"),
    ("RightLowerLeg", "RightFoot"),
]


def arg(nome, padrao=None):
    if "--" in sys.argv:
        resto = sys.argv[sys.argv.index("--") + 1 :]
        if nome in resto:
            i = resto.index(nome)
            if i + 1 < len(resto) and not resto[i + 1].startswith("--"):
                return resto[i + 1]
            return True
    return padrao


def avisar(msg):
    print("##AVISO## " + msg)


# ---------------------------------------------------------------- osso -> peca R15
def normalizar(nome):
    n = nome.split(":")[-1]  # mixamorig:LeftArm
    return n


def classificar_osso(nome):
    """Nome do osso -> peca R15 ou None. Cobre psx-people (Hips/LeftUpLeg...), Mixamo (mixamorig:LeftArm) e .L/.R."""
    n = normalizar(nome)
    baixo = n.lower()
    lado = None
    m = re.match(r"^(left|right)[_\.\- ]?(.*)$", baixo)
    if m:
        lado, resto = ("Left" if m.group(1) == "left" else "Right"), m.group(2)
    else:
        m = re.match(r"^(.*?)[_\.\- ](l|r|left|right)$", baixo)  # separador obrigatorio: "Hair" nao e lado R
        if m and m.group(1):
            lado, resto = ("Left" if m.group(2) in ("l", "left") else "Right"), m.group(1)
        else:
            resto = baixo
    resto = resto.replace("_", "").replace(".", "").replace("-", "").replace(" ", "")
    if lado:
        if any(k in resto for k in ("forearm", "lowerarm", "elbow")):
            return lado + "LowerArm"
        if any(k in resto for k in ("shoulder", "clavicle", "collar")):
            return "UpperTorso"
        if resto.startswith(("hand", "finger", "thumb", "index", "middle", "ring", "pinky", "wrist", "palm", "f_", "fmiddle", "findex", "fring", "fpinky", "fthumb")):
            return lado + "Hand"
        if any(k in resto for k in ("upleg", "thigh", "upperleg")):
            return lado + "UpperLeg"
        if any(k in resto for k in ("lowerleg", "calf", "shin", "knee")) or resto == "leg":
            return lado + "LowerLeg"
        if resto.startswith(("foot", "toe", "ball", "ankle")):
            return lado + "Foot"
        if resto in ("arm", "upperarm") or resto.startswith("arm") or "upperarm" in resto:
            return lado + "UpperArm"
        return None
    if any(k in resto for k in ("hip", "pelvis", "root")):
        return "LowerTorso"
    if any(k in resto for k in ("spine", "chest", "torso", "backpack", "bag")):
        return "UpperTorso"
    if any(k in resto for k in ("head", "neck", "hair", "jaw", "eye", "hat", "helmet")):
        return "Head"
    return None


# ---------------------------------------------------------------- utilitarios
def tris_de(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def bbox_mesh(me, mat=None):
    cs = [(mat @ v.co) if mat else v.co for v in me.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
    return mn, mx


def v3(v):
    return [round(float(v[0]), 5), round(float(v[1]), 5), round(float(v[2]), 5)]


def roblox_eixos(v):
    """Vetor/tamanho em eixos do Blender (x,y,z) -> eixos do Roblox para tamanhos (x, z, y)."""
    return [round(float(v[0]), 4), round(float(v[2]), 4), round(float(v[1]), 4)]


def roblox_ponto(v):
    """Ponto no Blender -> ponto no Roblox. Medido no projeto (docs/pendencias-integracao.md, Beretta): R = (-x, z, y)
    (o Roblox gira o FBX 180 graus em Y; frente -Y do Blender vira -Z, lado esquerdo +X vira -X)."""
    return [round(-float(v[0]), 4), round(float(v[2]), 4), round(float(v[1]), 4)]


def distancia_caixas(a, b):
    """Folga entre duas AABB (0 se encostam/sobrepoem); devolve (distancia, folga por eixo)."""
    gaps = []
    for i in range(3):
        g = max(a[0][i] - b[1][i], b[0][i] - a[1][i], 0.0)
        gaps.append(g)
    return math.sqrt(sum(g * g for g in gaps)), gaps


# ---------------------------------------------------------------- etapas
def importar(caminho):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=caminho, axis_forward="-Z", axis_up="Y")
    bpy.context.view_layer.update()  # armadilha: matrix_world em cache
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not arms:
        raise SystemExit("Sem armature no FBX: o script nao serve para este personagem.")
    arm = arms[0]
    malhas = [
        o
        for o in bpy.data.objects
        if o.type == "MESH" and (o.parent == arm or any(m.type == "ARMATURE" for m in o.modifiers)) and o.vertex_groups
    ]
    if not malhas:
        raise SystemExit("Nenhuma malha pesada ao esqueleto.")
    return arm, malhas


def relatorio_ossos(arm, malhas):
    print("##OSSOS## armature", arm.name, "ossos:", len(arm.data.bones))
    por_osso = {}
    for o in malhas:
        nomes = {g.index: g.name for g in o.vertex_groups}
        for v in o.data.vertices:
            if v.groups:
                g = max(v.groups, key=lambda g: g.weight)
                por_osso[nomes[g.group]] = por_osso.get(nomes[g.group], 0) + 1
            else:
                por_osso["(sem peso)"] = por_osso.get("(sem peso)", 0) + 1
    for b in arm.data.bones:
        print(
            "##OSSO## %-16s pai=%-12s -> %-14s verts=%d"
            % (b.name, b.parent.name if b.parent else "-", classificar_osso(b.name), por_osso.get(b.name, 0))
        )
    print("##MALHAS## " + ", ".join("%s(%d verts, %d tris)" % (o.name, len(o.data.vertices), tris_de(o.data)) for o in malhas))
    return por_osso


def assar_e_juntar(arm, malhas):
    """Congela cada malha na pose de repouso (dados originais), em coordenadas de mundo, e junta numa so."""
    arm.data.pose_position = "REST"
    if arm.animation_data:
        arm.animation_data_clear()
    bpy.context.view_layer.update()
    for o in malhas:
        o.data.transform(o.matrix_world)  # vertices em mundo (dados de repouso, sem deformacao)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                o.modifiers.remove(m)
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in malhas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = malhas[0]
    if len(malhas) > 1:
        bpy.ops.object.join()
    junto = bpy.context.view_layer.objects.active
    # normais personalizadas giram mal com a pose dos bracos: usa as da geometria (liso/chato continua por face)
    if junto.data.has_custom_normals:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        bpy.ops.object.mode_set(mode="OBJECT")
    return junto


def ossos_posicoes(arm):
    """nome -> (head, tail) em mundo, repouso."""
    mw = arm.matrix_world
    return {b.name: (mw @ b.head_local, mw @ b.tail_local) for b in arm.data.bones}


def atribuir_pecas(junto, arm):
    """Retorna dict face_index -> peca, e a tabela osso -> peca realmente usada."""
    me = junto.data
    nomes = {g.index: g.name for g in junto.vertex_groups}
    tabela = {}
    for b in arm.data.bones:
        p = classificar_osso(b.name)
        tabela[b.name] = p
        if p is None:
            avisar("osso sem peca R15: %s (vertices dele irao para a peca mais proxima)" % b.name)
    vpeca = []
    for v in me.vertices:
        peca = None
        if v.groups:
            g = max(v.groups, key=lambda g: g.weight)
            peca = tabela.get(nomes[g.group])
        vpeca.append(peca)
    # centroides das pecas conhecidas, para vertices sem peca
    soma, cont = {}, {}
    for v, p in zip(me.vertices, vpeca):
        if p:
            soma[p] = soma.get(p, Vector()) + v.co
            cont[p] = cont.get(p, 0) + 1
    centros = {p: soma[p] / cont[p] for p in soma}
    faltam = [p for p in PECAS if p not in centros]
    if faltam:
        raise SystemExit("Sem vertices para as pecas: %s. O rig nao cobre o humanoide R15." % faltam)
    sem = 0
    for i, p in enumerate(vpeca):
        if p is None:
            sem += 1
            vpeca[i] = min(centros, key=lambda k: (centros[k] - me.vertices[i].co).length)
    if sem:
        avisar("%d vertices sem peso/osso mapeado foram para a peca mais proxima" % sem)
    faces = {}
    for poly in me.polygons:
        votos = {}
        for vi in poly.vertices:
            votos[vpeca[vi]] = votos.get(vpeca[vi], 0) + 1
        faces[poly.index] = max(votos, key=votos.get)
    # osso principal de cada peca (o que tem mais vertices) para a pose
    return faces, tabela


def dividir(junto, faces):
    objs = {}
    for peca in PECAS:
        obj = junto.copy()
        obj.data = junto.data.copy()
        obj.name = peca
        obj.data.name = peca
        bpy.context.collection.objects.link(obj)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        apagar = [f for f in bm.faces if faces[f.index] != peca]
        bmesh.ops.delete(bm, geom=apagar, context="FACES")
        soltos = [v for v in bm.verts if not v.link_faces]
        if soltos:
            bmesh.ops.delete(bm, geom=soltos, context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        objs[peca] = obj
    bpy.data.objects.remove(junto, do_unlink=True)
    return objs


def osso_principal(peca, tabela, por_osso):
    cands = [n for n, p in tabela.items() if p == peca]
    if not cands:
        return None
    return max(cands, key=lambda n: por_osso.get(n, 0))


def posar_bracos(objs, tabela, pos, por_osso, modo):
    """Gira cada braco (rigido, em T) ate pender na vertical, cadeia FK: ombro->cotovelo->punho. Devolve texto de log."""
    if modo != "baixa":
        return "pose aberta (T/A do original)"
    log = []
    for lado in ("Left", "Right"):
        cadeia = [lado + "UpperArm", lado + "LowerArm", lado + "Hand"]
        ossos = [osso_principal(p, tabela, por_osso) for p in cadeia]
        if None in ossos:
            avisar("braco %s sem os tres ossos; pose nao aplicada" % lado)
            continue
        heads = [pos[o][0] for o in ossos]
        tail_mao = pos[ossos[2]][1]
        baixo = Vector((0, 0, -1))
        novo_head = heads[0].copy()
        for i, peca in enumerate(cadeia):
            if i < 2:
                direc = heads[i + 1] - heads[i]
                comp = direc.length
            else:
                direc = tail_mao - heads[2]
                comp = direc.length
            R = direc.normalized().rotation_difference(baixo).to_matrix().to_4x4()
            # v' = novo_head + R (v - head)
            M = Matrix.Translation(novo_head) @ R @ Matrix.Translation(-heads[i])
            objs[peca].data.transform(M)
            log.append("%s: giro de %.0f graus" % (peca, math.degrees(direc.normalized().angle(baixo))))
            novo_head = novo_head + baixo * comp
    # afasta o braco do tronco se a caixa invadir o UpperTorso
    for lado, sinal in (("Left", 1), ("Right", -1)):
        tor = objs["UpperTorso"].data
        braco = objs[lado + "UpperArm"].data
        bmn, bmx = bbox_mesh(braco)
        z0, z1 = bmn.z, bmx.z
        xs = [abs(v.co.x) for v in tor.vertices if z0 - 0.02 <= v.co.z <= z1 + 0.02]
        if not xs:
            continue
        tor_max = max(xs)
        interno = min(abs(bmn.x), abs(bmx.x)) if bmn.x * bmx.x > 0 else 0.0
        dx = tor_max - interno
        if dx > 1e-4:
            dx = min(dx, 0.12)
            for peca in (lado + "UpperArm", lado + "LowerArm", lado + "Hand"):
                objs[peca].data.transform(Matrix.Translation(Vector((sinal * dx, 0, 0))))
            log.append("%s: bracos afastados %.3f m do tronco" % (lado, dx))
    return "; ".join(log)


def normalizar_escala_e_origens(objs, studs_por_metro, altura_alvo_m=None):
    # pes em z=0 e centro em x=0 (pelo conjunto), depois escala em studs nos dados
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs.values():
        a, b = bbox_mesh(o.data)
        mn = Vector((min(mn.x, a.x), min(mn.y, a.y), min(mn.z, a.z)))
        mx = Vector((max(mx.x, b.x), max(mx.y, b.y), max(mx.z, b.z)))
    cx = (mn.x + mx.x) / 2
    altura_m = mx.z - mn.z
    if altura_alvo_m:
        studs_por_metro = studs_por_metro * altura_alvo_m / altura_m  # normaliza a altura total ao alvo
    for o in objs.values():
        o.data.transform(Matrix.Scale(studs_por_metro, 4) @ Matrix.Translation(Vector((-cx, 0, -mn.z))))
        o.data.update()
    for o in objs.values():
        a, b = bbox_mesh(o.data)
        c = (a + b) / 2
        o.data.transform(Matrix.Translation(-c))
        o.data.update()
        o.location = c
        o.rotation_euler = (0, 0, 0)
        o.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    return altura_m, altura_m * studs_por_metro, studs_por_metro


def recortar_textura(objs, ident, pasta, arquivo_origem, textura_extra=None):
    """Recorta a pagina do atlas usada pelas UVs das 15 pecas, refaz a UV e grava <id>.png (<= 256 px)."""
    import numpy as np

    img = None
    if textura_extra:
        img = bpy.data.images.load(os.path.abspath(textura_extra))
    for m in bpy.data.materials:
        if img:
            break
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0:
                    img = n.image
                    break
        if img:
            break
    if img is None:
        for cand in (
            os.path.join(os.path.dirname(arquivo_origem), "..", "textures", "atlas.png"),
            os.path.join(os.path.dirname(arquivo_origem), "textures", "atlas.png"),
        ):
            if os.path.exists(cand):
                img = bpy.data.images.load(os.path.abspath(cand))
                break
    if img is None:
        avisar("sem imagem de textura no FBX; peca sem textura")
        return None
    W, H = img.size
    umin = vmin = 1e9
    umax = vmax = -1e9
    for o in objs.values():
        for layer in o.data.uv_layers[:1]:
            for d in layer.data:
                umin, umax = min(umin, d.uv[0]), max(umax, d.uv[0])
                vmin, vmax = min(vmin, d.uv[1]), max(vmax, d.uv[1])
    x0 = max(0, int(math.floor(umin * W / 16.0) * 16))
    x1 = min(W, int(math.ceil(umax * W / 16.0) * 16))
    y0 = max(0, int(math.floor(vmin * H / 16.0) * 16))  # v de baixo para cima, como as linhas do buffer do Blender
    y1 = min(H, int(math.ceil(vmax * H / 16.0) * 16))
    cw, ch = x1 - x0, y1 - y0
    buf = np.empty(W * H * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    buf = buf.reshape(H, W, 4)[y0:y1, x0:x1, :]
    passo = max(1, int(math.ceil(max(cw, ch) / float(MAX_TEX))))
    if passo > 1:
        buf = buf[::passo, ::passo, :]
    nh, nw = buf.shape[0], buf.shape[1]
    for o in objs.values():
        for layer in o.data.uv_layers:
            for d in layer.data:
                d.uv = ((d.uv[0] * W - x0) / cw, (d.uv[1] * H - y0) / ch)
    novo = bpy.data.images.new(ident, nw, nh, alpha=True)
    novo.pixels.foreach_set(np.ascontiguousarray(buf).reshape(-1))
    novo.filepath_raw = os.path.join(pasta, ident + ".png")
    novo.file_format = "PNG"
    novo.save()
    return dict(arquivo=ident + ".png", tamanho=[nw, nh], recorteNoAtlas=dict(x=x0, y=y0, largura=cw, altura=ch, atlas=[W, H], reducao=passo)), novo


def montar_material(objs, imagem, ident):
    mat = bpy.data.materials.new(ident)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = imagem
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for o in objs.values():
        o.data.materials.clear()
        o.data.materials.append(mat)
    return mat


def limpar_pele(objs):
    for o in objs.values():
        o.vertex_groups.clear()
        for m in list(o.modifiers):
            o.modifiers.remove(m)


def exportar(objs, caminho):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(objs.values()))
    bpy.ops.export_scene.fbx(
        filepath=caminho,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
        mesh_smooth_type="FACE",
    )


def reimportar_e_conferir(caminho_fbx, manifesto_pecas, pasta, ident, png, previa):
    """Reimporta o FBX num cenario limpo: confere nomes, tris e tamanhos; renderiza a previa."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=caminho_fbx, axis_forward="-Z", axis_up="Y")
    bpy.context.view_layer.update()
    obs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    nomes = sorted(obs)
    # o importador pode sufixar .001 se houver colisao; aqui o cenario esta vazio
    ok_nomes = sorted(PECAS) == nomes
    dif = []
    for p in PECAS:
        o = obs.get(p)
        if not o:
            continue
        mn, mx = bbox_mesh(o.data)
        tam = roblox_eixos(mx - mn)
        esp = manifesto_pecas[p]["tamanhoNativo"]
        dif.append(max(abs(a - b) for a, b in zip(tam, esp)))
    conferencia = dict(
        nomesExatos=ok_nomes,
        nomesEncontrados=nomes,
        maiorDiferencaTamanhoNativo=round(max(dif), 4) if dif else None,
        trisReimportados={p: tris_de(obs[p].data) for p in PECAS if p in obs},
    )
    if not previa or not ok_nomes:
        return conferencia
    # material com o PNG gravado
    img = bpy.data.images.load(png)
    img.alpha_mode = "NONE"
    mat = bpy.data.materials.new("previa")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for o in obs.values():
        o.data.materials.clear()
        o.data.materials.append(mat)
    # tres copias: frente, 3/4, perfil (parente vazio gira o conjunto)
    todos_mn = Vector((1e9, 1e9, 1e9))
    todos_mx = Vector((-1e9, -1e9, -1e9))
    for o in obs.values():
        todos_mn = Vector((min(todos_mn.x, o.location.x), min(todos_mn.y, o.location.y), min(todos_mn.z, o.location.z)))
        todos_mx = Vector((max(todos_mx.x, o.location.x), max(todos_mx.y, o.location.y), max(todos_mx.z, o.location.z)))
    altura = todos_mx.z + 1.0
    espaco = altura * 0.55
    angs = [0, 40, 90]
    for i, ang in enumerate(angs):
        vazio = bpy.data.objects.new("v%d" % i, None)
        bpy.context.collection.objects.link(vazio)
        vazio.location = ((i - 1) * espaco, 0, 0)
        vazio.rotation_euler = (0, 0, math.radians(ang))
        for p, o in obs.items():
            c = o.copy()
            c.parent = vazio
            c.location = o.location
            bpy.context.collection.objects.link(c)
    for o in obs.values():
        bpy.data.objects.remove(o, do_unlink=True)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = espaco * 3.1
    cam.location = (0, -20, altura * 0.5)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_object_outline = False
    sc.render.resolution_x = 1500
    sc.render.resolution_y = max(400, int(1500 * altura * 1.15 / (espaco * 3.1)))
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    w.color = (0.22, 0.24, 0.27)
    sc.world = w
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = previa
    bpy.ops.render.render(write_still=True)
    conferencia["previa"] = os.path.relpath(previa, REPO)
    return conferencia


# ---------------------------------------------------------------- principal
def main():
    entrada = arg("--input")
    ident = arg("--id")
    if not entrada or not ident:
        raise SystemExit("Uso: ... -- --input <fbx> --id <id> [--saida <pasta>]")
    entrada = os.path.abspath(entrada)
    raiz = os.path.abspath(arg("--saida", os.path.join(REPO, "modelos 3d", "personagens")))
    pasta = os.path.join(raiz, ident)
    os.makedirs(pasta, exist_ok=True)
    studs_por_metro = float(arg("--studs-por-metro", STUDS_POR_METRO))
    pose = arg("--pose", "baixa")
    fonte = arg("--fonte", entrada)
    licenca = arg("--licenca", "desconhecida: confirmar origem com o usuario")
    credito = arg("--credito", "")
    sem_previa = bool(arg("--sem-previa", False))

    arm, malhas = importar(entrada)
    por_osso = relatorio_ossos(arm, malhas)
    malhas_originais = {o.name: dict(verts=len(o.data.vertices), tris=tris_de(o.data)) for o in malhas}
    pos = ossos_posicoes(arm)
    junto = assar_e_juntar(arm, malhas)
    faces, tabela = atribuir_pecas(junto, arm)
    ossos_info = {n: dict(peca=tabela.get(n), verticesDominantes=por_osso.get(n, 0)) for n in pos}
    objs = dividir(junto, faces)
    for o in list(bpy.data.objects):  # armature, cubo, camera e luz do FBX original ficam de fora
        if o.name not in objs:
            bpy.data.objects.remove(o, do_unlink=True)

    log_pose = posar_bracos(objs, tabela, pos, por_osso, pose)
    antes_caixas = {p: bbox_mesh(o.data) for p, o in objs.items()}
    altura_alvo = arg("--altura-metros")
    altura_m, altura_studs, studs_por_metro = normalizar_escala_e_origens(objs, studs_por_metro, float(altura_alvo) if altura_alvo else None)
    caixas = {}
    for p, o in objs.items():
        mn, mx = bbox_mesh(o.data, Matrix.Translation(o.location))
        caixas[p] = (mn, mx)
    res_tex = recortar_textura(objs, ident, pasta, entrada, arg("--textura"))
    if res_tex:
        info_tex, imagem = res_tex
        montar_material(objs, imagem, ident)
    else:
        info_tex = None
    limpar_pele(objs)

    # validacao
    problemas = []
    pecas = {}
    for p in PECAS:
        o = objs[p]
        t = tris_de(o.data)
        if t == 0:
            problemas.append("%s vazia" % p)
        if t > MAX_TRIS:
            problemas.append("%s tem %d tris (> %d)" % (p, t, MAX_TRIS))
        mn, mx = bbox_mesh(o.data)
        pecas[p] = dict(
            triangulos=t,
            vertices=len(o.data.vertices),
            tamanhoNativo=roblox_eixos(mx - mn),
            centroMontagem=roblox_ponto(o.location),
        )
    folgas = {}
    for a, b in VIZINHOS:
        d, g = distancia_caixas(caixas[a], caixas[b])
        folgas["%s|%s" % (a, b)] = dict(distanciaStuds=round(d, 3), porEixoBlender=[round(x, 3) for x in g])
    ex = [f for f in folgas.values() if f["distanciaStuds"] > 0.15]
    if ex:
        avisar("folgas > 0,15 stud entre vizinhas: " + ", ".join(k for k, f in folgas.items() if f["distanciaStuds"] > 0.15))

    fbx = os.path.join(pasta, ident + ".fbx")
    exportar(objs, fbx)
    png = os.path.join(pasta, ident + ".png")
    conf = reimportar_e_conferir(fbx, pecas, pasta, ident, png, os.path.join(pasta, "previa.png") if not sem_previa else None)
    if not conf["nomesExatos"]:
        problemas.append("nomes no FBX reimportado nao batem: %s" % conf["nomesEncontrados"])

    cmn = Vector((min(c[0].x for c in caixas.values()), min(c[0].y for c in caixas.values()), min(c[0].z for c in caixas.values())))
    cmx = Vector((max(c[1].x for c in caixas.values()), max(c[1].y for c in caixas.values()), max(c[1].z for c in caixas.values())))
    manifesto = dict(
        id=ident,
        arquivo=ident + ".fbx",
        textura=info_tex,
        fonte=fonte,
        licenca=licenca,
        credito=credito,
        studsPorMetro=round(studs_por_metro, 5),
        alturaMetrosOriginal=round(altura_m, 4),
        alturaTotalStuds=round(altura_studs, 4),
        caixaTotalStuds=roblox_eixos(cmx - cmn),
        pose=pose,
        logPose=log_pose,
        eixos="Roblox (medido): ponto = (-x, z, y) do Blender; frente -Z; tamanhoNativo = (x, y, z) em studs; centroMontagem = posicao do centro da caixa no boneco montado, pes em y=0",
        malhasOriginais=malhas_originais,
        ossos=ossos_info,
        pecas=pecas,
        folgas=folgas,
        conferenciaReimportacao=conf,
        problemas=problemas,
        triangulosTotais=sum(v["triangulos"] for v in pecas.values()),
        observacoes=[
            "Cor sombreada vem de cor de vertice (atributo Col) no FBX; se o Roblox ignorar, a textura sozinha fica sem sombreado.",
            "Peca R15 e esticada pelo Lua ao Size da peca original; as folgas acima sao medidas antes do esticamento.",
        ],
    )
    with open(os.path.join(pasta, ident + ".json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, indent=1, ensure_ascii=False)
    print("##RESULTADO## " + json.dumps(dict(id=ident, tris={p: pecas[p]["triangulos"] for p in PECAS}, altura=round(altura_studs, 3), problemas=problemas, conf=conf), ensure_ascii=False))
    if problemas:
        raise SystemExit("Problemas: %s" % problemas)


if __name__ == "__main__":
    main()
