# Refaz malha, esqueleto, pesos e animações de Corcunda, Esfolado, MonstroPS1 e Florescida (2026-11-13).
# Substitui, para esses quatro, o rig_ps2.py + animar_ps2.py (procedurais, ficaram ruins).
#
#   blender -b --factory-startup -P ferramentas/modelos/refazer_monstros.py -- --etapa prep --nome Corcunda
#   blender -b --factory-startup -P ferramentas/modelos/refazer_monstros.py -- --etapa rig  --nome Corcunda
#   blender -b --factory-startup -P ferramentas/modelos/refazer_monstros.py -- --etapa anim --nome Corcunda
#
# Etapas (cada uma lê a saída da anterior, em modelos 3d/_ps2/<Nome>/):
#   prep -> <Nome>_prep.blend : uma malha só, uma textura (atlas <Nome>_atlas.png), frente em -Y, centro em x=y=0, pés em z=0,
#                               altura 2,2 m. Grupos de vértice do rig original ficam (servem de pesos para MonstroPS1/Florescida).
#   rig  -> <Nome>_rig2.blend : esqueleto padrão (nomes abaixo) nas juntas de JUNTAS[nome], pesos (calor do Blender ou
#                               transferidos do original por MAPA_PESOS), no máximo 4 influências por vértice.
#   anim -> <Nome>_v2.blend   : 5 ações <Nome>_Idle/Walk/Run/Attack/Death em quaternion, ciclo no lugar (quem desloca é o jogo).
#
# Convenção (igual ao Rastejador, que o exportar_rastejador.py e o gerar_anim_rastejador.py esperam): frente = -Y, .L = +X.
# Esqueleto padrão: Hips, Spine, Chest, Neck, Head, [Jaw], [Tail.1..3], UpperArm/LowerArm/Hand.L/R, UpperLeg/LowerLeg/Foot.L/R, [Toe.L/R].

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PS2 = os.path.join(REPO, "modelos 3d", "_ps2")
ALTURA = 2.2
CELULA = 256  # px por textura no atlas
MAX_INFLUENCIAS = 4

# ---------------------------------------------------------------- origem de cada modelo
# arquivo: .blend de entrada; giro: graus em Z que levam a frente original para -Y; tirar: prefixos de malha que não são corpo.
ORIGEM = {
    "Corcunda": dict(arquivo="Corcunda_rig.blend", giro=-90, tirar=("Icosphere",)),
    "Esfolado": dict(arquivo="Esfolado.blend", giro=0, tirar=()),  # base sem filtro (SEM_FILTRO do filtro_ps2.py)
    "MonstroPS1": dict(arquivo="MonstroPS1_rig.blend", giro=0, tirar=()),
    # cartões de pelo (Hair_cards/hair_cards_v2) não têm imagem no original: viravam placas lisas que esticam no passo -> fora
    "Florescida": dict(arquivo="Florescida_rig.blend", giro=180, tirar=(), sem_textura_fora=True),
}
COR_SEM_TEXTURA = (0.27, 0.25, 0.23)  # cabelos da Florescida (Hair_cards sem imagem no original)


def caminho(nome, sufixo):
    return os.path.join(PS2, nome, nome + sufixo)


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return {a[i][2:]: a[i + 1] for i in range(0, len(a) - 1, 2)}


# ================================================================= PREP

def imagem_do_material(mat):
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                return n.image
    return None


def pixels_256(img):
    # devolve array (256, 256, 4) float da imagem redimensionada (cópia; não mexe na original)
    c = img.copy()
    if not c.has_data:
        c.reload()
    if tuple(c.size) != (CELULA, CELULA):
        c.scale(CELULA, CELULA)
    px = np.empty(CELULA * CELULA * 4, dtype=np.float32)
    c.pixels.foreach_get(px)
    bpy.data.images.remove(c)
    return px.reshape(CELULA, CELULA, 4)


def prep(nome):
    o = ORIGEM[nome]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(PS2, nome, o["arquivo"]))
    cena = bpy.context.scene
    for a in cena.objects:
        if a.type == "ARMATURE":
            a.data.pose_position = "REST"
    bpy.context.view_layer.update()
    malhas = [m for m in cena.objects if m.type == "MESH" and len(m.data.polygons) > 0
              and not (o["tirar"] and m.name.startswith(o["tirar"]))
              and not (o.get("sem_textura_fora") and all(imagem_do_material(s.material) is None for s in m.material_slots))]
    # assa a transformação de mundo nos vértices (sem a deformação do esqueleto: em repouso ela é identidade)
    giro = Matrix.Rotation(math.radians(o["giro"]), 4, "Z")
    for m in malhas:
        mw = m.matrix_world.copy()
        for mod in list(m.modifiers):
            m.modifiers.remove(mod)
        m.data = m.data.copy()
        m.data.transform(giro @ mw)
        m.parent = None
        m.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for a in list(cena.objects):
        if a not in malhas:
            bpy.data.objects.remove(a)
    # materiais -> células do atlas (uma por imagem distinta; materiais sem imagem dividem uma célula de cor lisa)
    celulas, mat_cel = [], {}
    for m in malhas:
        for s in m.material_slots:
            img = imagem_do_material(s.material)
            chave = img.name if img else "_liso"
            if chave not in [c[0] for c in celulas]:
                celulas.append((chave, img))
            mat_cel[s.material.name if s.material else "_liso"] = [c[0] for c in celulas].index(chave)
    n = len(celulas)
    col = math.ceil(math.sqrt(n))
    lin = math.ceil(n / col)
    W, H = col * CELULA, lin * CELULA
    atlas = np.zeros((H, W, 4), dtype=np.float32)
    atlas[..., :3] = COR_SEM_TEXTURA
    atlas[..., 3] = 1
    for i, (chave, img) in enumerate(celulas):
        cx, cy = i % col, i // col
        if img:
            atlas[cy * CELULA:(cy + 1) * CELULA, cx * CELULA:(cx + 1) * CELULA] = pixels_256(img)
        atlas[cy * CELULA:(cy + 1) * CELULA, cx * CELULA:(cx + 1) * CELULA, 3] = 1
    # UV: cada face vai para a célula do seu material (UV fora de 0..1 é trazido pela parte inteira do mínimo da face)
    for m in malhas:
        me = m.data
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active.data
        for p in me.polygons:
            s = m.material_slots[p.material_index].material if m.material_slots else None
            i = mat_cel[s.name if s else "_liso"]
            cx, cy = i % col, i // col
            if celulas[i][1] is None:
                for li in p.loop_indices:
                    uv[li].uv = ((cx + 0.5) / col, (cy + 0.5) / lin)
                continue
            us = [uv[li].uv.copy() for li in p.loop_indices]
            fu, fv = math.floor(min(u.x for u in us) + 1e-6), math.floor(min(u.y for u in us) + 1e-6)
            for li, u in zip(p.loop_indices, us):
                x = min(max(u.x - fu, 0.0), 1.0)
                y = min(max(u.y - fv, 0.0), 1.0)
                uv[li].uv = ((cx + x) / col, (cy + y) / lin)
        me.materials.clear()
    # junta tudo numa malha (os grupos de vértice com o mesmo nome se fundem)
    for a in cena.objects:
        a.select_set(a in malhas)
    principal = max(malhas, key=lambda m: len(m.data.vertices))
    bpy.context.view_layer.objects.active = principal
    if len(malhas) > 1:
        bpy.ops.object.join()
    malha = bpy.context.view_layer.objects.active
    malha.name = nome
    malha.data.name = nome
    # solda vértices na mesma posição (o Esfolado vem com cada triângulo solto: sem isso, cada cópia ganha um peso e a malha rasga).
    # A UV fica nos loops, então a costura de textura não muda.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(malha.data)
    antes = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    soldados = antes - len(bm.verts)
    bm.to_mesh(malha.data)
    bm.free()
    # só uma camada UV (a ativa)
    for u in list(malha.data.uv_layers):
        if u != malha.data.uv_layers.active:
            malha.data.uv_layers.remove(u)
    # centro em x=y=0 (pela caixa), pés em z=0, altura 2,2
    V = np.array([v.co[:] for v in malha.data.vertices])
    mn, mx = V.min(0), V.max(0)
    esc = ALTURA / (mx[2] - mn[2])
    malha.data.transform(Matrix.Scale(esc, 4) @ Matrix.Translation(Vector((-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]))))
    # material único com o atlas
    img = bpy.data.images.new(nome + "_atlas", W, H, alpha=False)
    img.pixels.foreach_set(atlas.ravel())
    img.filepath_raw = caminho(nome, "_atlas.png")
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    malha.data.materials.append(mat)
    malha.data.update()
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    V = np.array([v.co[:] for v in malha.data.vertices])
    info = dict(nome=nome, verts=len(V), tris=sum(len(p.vertices) - 2 for p in malha.data.polygons), atlas=[W, H],
                celulas=[c[0] for c in celulas], min=V.min(0).round(3).tolist(), max=V.max(0).round(3).tolist(),
                grupos=len(malha.vertex_groups), soldados=soldados)
    bpy.ops.wm.save_as_mainfile(filepath=caminho(nome, "_prep.blend"))
    return info


# ================================================================= RIG
# Juntas em metros, no quadro do _prep.blend (frente -Y, .L = +X). Lidas de fatias de vértices e de vistas com grade
# (2026-11-13); MonstroPS1 e Florescida partem das cabeças dos ossos originais. Lados: chaves "L"/"R".
# Corpo: pelve -> coluna -> peito -> pescoco -> cabeca -> topo. Braço: ombro, cotovelo, pulso, mao. Perna: quadril, joelho, tornozelo, pe [, dedo].


def _lados(L, R):
    return {"L": L, "R": R}


JUNTAS = {
    "Corcunda": dict(
        pelve=(-0.08, 0.10, 1.05), coluna=(-0.10, 0.08, 1.40), peito=(-0.12, 0.0, 1.72), pescoco=(-0.15, -0.22, 1.97),
        cabeca=(-0.15, -0.38, 2.05), topo=(-0.15, -0.68, 1.97),
        braco=_lados(dict(ombro=(0.15, 0.0, 1.70), cotovelo=(0.40, 0.05, 1.35), pulso=(0.52, 0.0, 0.98), mao=(0.55, -0.05, 0.85)),
                     dict(ombro=(-0.40, -0.05, 1.70), cotovelo=(-0.56, -0.05, 1.15), pulso=(-0.55, -0.10, 0.75), mao=(-0.50, -0.50, 0.52))),
        perna=_lados(dict(quadril=(0.04, 0.12, 1.0), joelho=(0.02, 0.02, 0.48), tornozelo=(0.0, 0.52, 0.28), pe=(-0.02, 0.64, 0.03)),
                     dict(quadril=(-0.20, 0.08, 1.0), joelho=(-0.20, -0.08, 0.50), tornozelo=(-0.18, 0.05, 0.12), pe=(-0.18, -0.14, 0.02))),
    ),
    "Esfolado": dict(
        pelve=(0.0, 0.60, 1.30), coluna=(0.0, 0.15, 1.60), peito=(0.0, -0.30, 1.70), pescoco=(0.0, -0.65, 1.75),
        cabeca=(0.0, -0.85, 1.90), topo=(0.0, -1.20, 1.90),
        braco=_lados(dict(ombro=(0.33, -0.15, 1.65), cotovelo=(0.42, 0.20, 1.45), pulso=(0.60, 0.35, 1.10), mao=(0.65, 0.40, 0.85)),
                     dict(ombro=(-0.45, -0.15, 1.60), cotovelo=(-0.50, 0.25, 1.35), pulso=(-0.40, 0.45, 1.0), mao=(-0.37, 0.45, 0.62))),
        perna=_lados(dict(quadril=(0.22, 0.60, 1.10), joelho=(0.26, 0.03, 0.85), tornozelo=(0.24, 0.60, 0.22), pe=(0.28, 0.17, 0.02)),
                     dict(quadril=(-0.22, 0.60, 1.10), joelho=(-0.20, 1.15, 0.92), tornozelo=(-0.38, 0.95, 0.22), pe=(-0.30, 0.68, 0.03))),
    ),
    "MonstroPS1": dict(
        pelve=(-0.094, 0.012, 1.10), coluna=(-0.094, 0.012, 1.40), peito=(-0.094, 0.012, 1.625), pescoco=(-0.094, 0.052, 1.847),
        cabeca=(-0.094, 0.052, 2.085), topo=(-0.094, 0.052, 2.20),
        braco=_lados(dict(ombro=(0.431, 0.056, 1.743), cotovelo=(0.755, 0.056, 1.743), pulso=(1.072, 0.056, 1.743), mao=(1.60, 0.056, 1.743)),
                     dict(ombro=(-0.62, 0.056, 1.743), cotovelo=(-0.943, 0.056, 1.743), pulso=(-1.26, 0.056, 1.743), mao=(-1.66, 0.056, 1.743))),
        perna=_lados(dict(quadril=(0.076, 0.012, 1.031), joelho=(0.076, -0.011, 0.529), tornozelo=(0.076, 0.068, 0.064), pe=(0.076, -0.20, 0.02)),
                     dict(quadril=(-0.264, 0.012, 1.031), joelho=(-0.264, -0.011, 0.529), tornozelo=(-0.264, 0.068, 0.064), pe=(-0.264, -0.20, 0.02))),
        # T-pose: a etapa rig baixa os braços (graus) e grava como repouso, para a malha não ter 3,4 m de largura
        baixar_bracos=70,
    ),
    "Florescida": dict(
        pelve=(0.0, 0.146, 1.437), coluna=(0.0, -0.126, 1.497), peito=(0.0, -0.444, 1.711), pescoco=(0.0, -0.874, 1.638),
        cabeca=(0.0, -1.013, 1.633), topo=(0.0, -1.35, 1.58),
        mandibula=((0.0, -1.047, 1.62), (0.0, -1.32, 1.56)),
        cauda=[(0.0, 0.23, 1.277), (0.0, 0.629, 1.158), (0.0, 1.165, 1.104), (0.0, 1.20, 1.59)],
        braco=_lados(dict(ombro=(0.187, -0.624, 1.701), cotovelo=(0.168, -0.547, 1.087), pulso=(0.159, -0.682, 0.476), mao=(0.20, -0.98, 0.07)),
                     dict(ombro=(-0.192, -0.624, 1.701), cotovelo=(-0.173, -0.553, 1.087), pulso=(-0.17, -0.70, 0.40), mao=(-0.204, -0.99, 0.10))),
        # pata traseira digitígrada: coxa desce até o joelho (baixo, à frente), canela volta para trás até o jarrete, pé desce até o casco
        perna=_lados(dict(quadril=(0.15, 0.12, 1.35), joelho=(0.15, 0.0, 0.53), tornozelo=(0.15, 0.62, 0.64), pe=(0.15, 0.27, 0.06), dedo=(0.15, 0.03, 0.0)),
                     dict(quadril=(-0.14, 0.12, 1.35), joelho=(-0.14, 0.0, 0.53), tornozelo=(-0.14, 0.62, 0.64), pe=(-0.14, 0.27, 0.06), dedo=(-0.14, 0.03, 0.0))),
    ),
}

# Pesos: "calor" = pesos automáticos do Blender (Bone Heat); "mapa" = soma dos grupos originais conforme o prefixo/nome.
PESOS = {"Corcunda": "calor", "Esfolado": "calor", "MonstroPS1": "mapa", "Florescida": "mapa"}


def _mapa_ps1(g):
    for lado, s in (("Left", "L"), ("Right", "R")):
        t = g.replace("Character1_", "")
        if t.startswith(lado):
            t = t[len(lado):]
            return {"Shoulder": "Chest", "Arm": f"UpperArm.{s}", "ForeArm": f"LowerArm.{s}", "Hand": f"Hand.{s}", "Hand_end": f"Hand.{s}",
                    "UpLeg": f"UpperLeg.{s}", "Leg": f"LowerLeg.{s}", "Foot": f"Foot.{s}", "ToeBase": f"Foot.{s}", "ToeBase_end": f"Foot.{s}"}.get(t)
    t = g.replace("Character1_", "")
    return {"Hips": "Hips", "Spine": "Spine", "Spine1": "Spine", "Spine2": "Chest", "Neck": "Neck", "Head": "Head", "Head_end": "Head"}.get(t)


def _mapa_florescida(g):
    t = g.replace("_J", "")
    if t.startswith(("L_", "R_")):
        s, t = t[0], t[2:]
        if t == "shoulder":
            return f"UpperArm.{s}"
        if t == "elbow":
            return f"LowerArm.{s}"
        if t in ("wrist", "hand") or t.split("_")[0] in ("thumb", "index", "middle", "ring", "pinkie"):
            return f"Hand.{s}"
        return {"upper_leg": f"UpperLeg.{s}", "knee": f"LowerLeg.{s}", "ankle": f"Foot.{s}", "heel": f"Foot.{s}", "feet": f"Foot.{s}", "toe": f"Toe.{s}"}.get(t)
    if t in ("C_Hip",):
        return "Hips"
    if t in ("C_base_tail", "C_tail_01"):
        return "Tail.1"
    if t == "C_tail_02" or t in (f"C_Bone_tail_{i:02d}" for i in range(1, 5)):
        return "Tail.2"
    if t.startswith("C_Bone_tail_"):
        return "Tail.3"
    if t in ("C_spine_01", "C_spine_02"):
        return "Spine"
    if t in ("C_spine_03", "C_spine_04"):
        return "Chest"
    if t == "C_Neck":
        return "Neck"
    if t in ("C_Head", "C_Top_skull", "C_Nose_"):
        return "Head"
    if t.startswith(("C_jaw", "C_Tongue")):
        return "Jaw"
    return None


MAPA_PESOS = {"MonstroPS1": _mapa_ps1, "Florescida": _mapa_florescida}
# Pernas traseiras da Florescida: o peso original da coxa puxava a pele do quadril até o joelho (folha rasgada no passo).
# Vértices abaixo de z_max e atrás de y_min são repesados por distância só entre Hips e os ossos da perna do lado.
REPESAR_PERNAS = {"Florescida": dict(z_max=1.30, y_min=-0.25)}


def repesar_pernas(malha, arm, j, gs, lim):
    # Pesos de calor do Blender (seguem a superfície, não a distância reta) numa cópia da malha; copia só o que é das pernas
    # (vértices abaixo de z_max e atrás de y_min), entre Hips e os ossos da perna do lado. Fora do lado/perna: original.
    B = arm.data.bones
    copia = malha.copy()
    copia.data = malha.data.copy()
    bpy.context.scene.collection.objects.link(copia)
    copia.vertex_groups.clear()
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    copia.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    nomes = {g.index: g.name for g in copia.vertex_groups}
    n = 0
    for v, vc in zip(malha.data.vertices, copia.data.vertices):
        p = v.co
        if p.z > lim["z_max"] or p.y < lim["y_min"]:
            continue
        if p.z > 1.0 and p.y < 0.35 and abs(p.x) < 0.08:  # cauda/ventre perto do centro: não é perna
            continue
        s = "L" if p.x > 0 else "R"
        cand = {"Hips", f"UpperLeg.{s}", f"LowerLeg.{s}", f"Foot.{s}", f"Toe.{s}"}
        ws = [(nomes[g.group], g.weight) for g in vc.groups if nomes[g.group] in cand and g.weight > 1e-3]
        tot = sum(w for _, w in ws)
        if tot < 0.3:  # calor não alcançou (peça solta): fica o original
            continue
        for g in list(v.groups):
            malha.vertex_groups[g.group].remove([v.index])
        for c, w in ws:
            gs[c].add([v.index], w / tot, "REPLACE")
        n += 1
    bpy.data.objects.remove(copia)
    return n


def ossos_padrao(j):
    # lista (nome, pai, head, tail)
    o = [("Hips", None, j["pelve"], j["coluna"]), ("Spine", "Hips", j["coluna"], j["peito"]), ("Chest", "Spine", j["peito"], j["pescoco"]),
         ("Neck", "Chest", j["pescoco"], j["cabeca"]), ("Head", "Neck", j["cabeca"], j["topo"])]
    if "mandibula" in j:
        o.append(("Jaw", "Head", *j["mandibula"]))
    c = j.get("cauda")
    if c:
        for i in range(len(c) - 1):
            o.append((f"Tail.{i + 1}", "Hips" if i == 0 else f"Tail.{i}", c[i], c[i + 1]))
    for s in ("L", "R"):
        b = j["braco"][s]
        o += [(f"UpperArm.{s}", "Chest", b["ombro"], b["cotovelo"]), (f"LowerArm.{s}", f"UpperArm.{s}", b["cotovelo"], b["pulso"]),
              (f"Hand.{s}", f"LowerArm.{s}", b["pulso"], b["mao"])]
        p = j["perna"][s]
        o += [(f"UpperLeg.{s}", "Hips", p["quadril"], p["joelho"]), (f"LowerLeg.{s}", f"UpperLeg.{s}", p["joelho"], p["tornozelo"]),
              (f"Foot.{s}", f"LowerLeg.{s}", p["tornozelo"], p["pe"])]
        if "dedo" in p:
            o.append((f"Toe.{s}", f"Foot.{s}", p["pe"], p["dedo"]))
    return o


def criar_armadura(nome, ossos):
    dados = bpy.data.armatures.new(nome)
    arm = bpy.data.objects.new(nome, dados)
    bpy.context.scene.collection.objects.link(arm)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for n, _, h, t in ossos:
        b = dados.edit_bones.new(n)
        b.head, b.tail = Vector(h), Vector(t)
        if (b.tail - b.head).length < 0.02:
            b.tail = b.head + Vector((0, 0, 0.05))
        b.roll = 0
    for n, pai, _, _ in ossos:
        if pai:
            dados.edit_bones[n].parent = dados.edit_bones[pai]
            dados.edit_bones[n].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    dados.display_type = "OCTAHEDRAL"
    arm.show_in_front = True
    return arm


def pesos_distancia(malha, arm, so_sem_peso=False):
    # inverso da distância^4 ao segmento do osso, top-4. Fallback para vértices que o calor não pegou.
    V = np.array([v.co[:] for v in malha.data.vertices])
    segs = [(b.name, np.array(b.head_local), np.array(b.tail_local)) for b in arm.data.bones]
    H = np.array([s[1] for s in segs]); T = np.array([s[2] for s in segs]); d = T - H
    t = np.clip(((V[:, None] - H[None]) * d[None]).sum(2) / np.maximum((d * d).sum(1), 1e-9)[None], 0, 1)
    dist = np.linalg.norm(V[:, None] - (H[None] + t[..., None] * d[None]), axis=2)
    w = 1 / (dist + 0.02) ** 4
    gs = {s[0]: malha.vertex_groups.get(s[0]) or malha.vertex_groups.new(name=s[0]) for s in segs}
    n = 0
    for i, v in enumerate(malha.data.vertices):
        if so_sem_peso and sum(g.weight for g in v.groups) > 1e-4:
            continue
        idx = np.argsort(w[i])[::-1][:MAX_INFLUENCIAS]
        for k in idx:
            gs[segs[k][0]].add([i], float(w[i][k] / w[i][idx].sum()), "REPLACE")
        n += 1
    return n


def limitar(malha):
    maior = 0
    for v in malha.data.vertices:
        gs = sorted(((g.weight, g.group) for g in v.groups if g.weight > 1e-5), reverse=True)
        for g in v.groups:
            if (g.weight, g.group) not in gs[:MAX_INFLUENCIAS]:
                malha.vertex_groups[g.group].remove([v.index])
        gs = gs[:MAX_INFLUENCIAS]
        s = sum(w for w, _ in gs)
        for w, gi in gs:
            malha.vertex_groups[gi].add([v.index], w / s, "REPLACE")
        maior = max(maior, len(gs))
    return maior


def rig(nome):
    bpy.ops.wm.open_mainfile(filepath=caminho(nome, "_prep.blend"))
    malha = bpy.data.objects[nome]
    j = JUNTAS[nome]
    ossos = ossos_padrao(j)
    arm = criar_armadura(nome + "_Rig", ossos)
    nomes = [o[0] for o in ossos]
    info = dict(nome=nome, ossos=len(nomes), pesos=PESOS[nome])
    if PESOS[nome] == "mapa":
        f = MAPA_PESOS[nome]
        velhos = {g.index: g.name for g in malha.vertex_groups}
        acum = [dict() for _ in malha.data.vertices]
        sem_mapa = set()
        for v in malha.data.vertices:
            for g in v.groups:
                alvo = f(velhos[g.group])
                if alvo is None:
                    sem_mapa.add(velhos[g.group]); continue
                acum[v.index][alvo] = acum[v.index].get(alvo, 0) + g.weight
        malha.vertex_groups.clear()
        gs = {n: malha.vertex_groups.new(name=n) for n in nomes}
        for i, d in enumerate(acum):
            for n, w in d.items():
                if w > 1e-5:
                    gs[n].add([i], w, "REPLACE")
        info["grupos_sem_mapa"] = sorted(sem_mapa)
        if nome in REPESAR_PERNAS:
            info["pernas_repesadas"] = repesar_pernas(malha, arm, j, gs, REPESAR_PERNAS[nome])
        info["sem_peso_preenchidos"] = pesos_distancia(malha, arm, so_sem_peso=True)
        malha.parent = arm
        mod = malha.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    else:
        malha.vertex_groups.clear()
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        malha.select_set(True)
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        info["sem_peso_preenchidos"] = pesos_distancia(malha, arm, so_sem_peso=True)
    info["max_influencias"] = limitar(malha)
    if j.get("baixar_bracos"):
        baixar_bracos(arm, malha, j["baixar_bracos"])
    bpy.ops.wm.save_as_mainfile(filepath=caminho(nome, "_rig2.blend"))
    return info


def baixar_bracos(arm, malha, graus):
    # gira os braços para baixo em torno do ombro, aplica na malha e grava a pose como novo repouso
    for s, sinal in (("L", 1), ("R", -1)):
        pb = arm.pose.bones[f"UpperArm.{s}"]
        b = arm.data.bones[f"UpperArm.{s}"]
        giro_mundo = Matrix.Rotation(math.radians(graus * sinal), 4, "Y")
        local = b.matrix_local.to_3x3().inverted() @ giro_mundo.to_3x3() @ b.matrix_local.to_3x3()
        pb.rotation_quaternion = local.to_quaternion()
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = malha
    malha.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Armature")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = malha.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ================================================================= ANIM
# Cada quadro é montado como deformação de mundo G[osso] (matriz 4x4 que leva o repouso à pose), como no
# animar_rastejador_opus.py: corpo por giros em torno das juntas; pernas (e braços-pata da Florescida) por IK de 2 ossos com
# o pé rígido; braços por giros. Depois vira location/quaternion de cada pose bone. Ciclos no lugar (quem desloca é o jogo).
# Sinais de rot(): pitch > 0 abaixa o que aponta para a frente (-Y) e leva para trás o que pende; roll > 0 tomba para +X.
#
# v3 (2026-11-14, agente D): clipes por TEMPO (segundos) com eventos medidos; correção de chão quadro a quadro (pé e corpo nunca
# abaixo de z=0); calcanhar gira na ponta do pé; quique do quadril na fase certa; galope da Florescida; clipes de habilidade.
# O Animador também serve a rigs de outros nomes (ANIM[nome]["nomes"]: nome lógico -> osso real; ossos sem par seguem o ancestral),
# usado pelo animar_wrapper.py.

FPS = 30
# Membros com IK: a/b = os dois ossos, pe = ossos rígidos abaixo do fim, pai = osso de onde sai o membro.
MEMBROS_BIPED = {s: dict(a=f"UpperLeg.{s}", b=f"LowerLeg.{s}", pe=[f"Foot.{s}"], pai="Hips", lado=1 if s == "L" else -1) for s in "LR"}
MEMBROS_QUAD = {
    "FL": dict(a="UpperArm.L", b="LowerArm.L", pe=["Hand.L"], pai="Chest", lado=1),
    "FR": dict(a="UpperArm.R", b="LowerArm.R", pe=["Hand.R"], pai="Chest", lado=-1),
    "BL": dict(a="UpperLeg.L", b="LowerLeg.L", pe=["Foot.L", "Toe.L"], pai="Hips", lado=1),
    "BR": dict(a="UpperLeg.R", b="LowerLeg.R", pe=["Foot.R", "Toe.R"], pai="Hips", lado=-1),
}

# Estilo de cada monstro. passo/altura em metros do .blend; quadros = duração do ciclo; apoio = fração do ciclo com o pé no chão.
# pe_dir: direção (em mundo) para onde o pé aponta na pose neutra (só onde o repouso tem o pé torto); polo: para onde o joelho dobra.
# bob_fase: fração do ciclo (depois do contato do pé L) em que o quadril está mais baixo.
ANIM = {
    "Corcunda": dict(
        tipo="biped", polo=(0, -1, 0.15), y_pe=0.05, x_pe={"L": 0.04, "R": -0.20}, pe_dir={"L": (0, -0.19, -0.10)}, descer=0.07,
        braco=dict(base=-8, amp=20, cotovelo=-18), inclinar=6, cabeca=dict(base=0, bob=5),
        walk=dict(quadros=30, passo=0.62, altura=0.13, apoio=0.62, bob=0.04, bob_fase=0.08, roll=5, yaw=6, lado=0.045, manca=0.35),
        run=dict(quadros=18, passo=1.20, altura=0.22, apoio=0.40, bob=0.07, bob_fase=0.2, roll=5, yaw=8, lado=0.03, inclinar=22, braco_amp=42),
    ),
    "MonstroPS1": dict(
        tipo="biped", polo=(0, -1, 0.0), y_pe=0.04, x_pe={"L": 0.08, "R": -0.27}, pe_dir={}, descer=0.08,
        # braços pendurados (repouso 70° abaixo da horizontal), lâminas balançando perto do chão
        braco=dict(base=8, amp=14, cotovelo=-12), inclinar=14, cabeca=dict(base=-6, bob=5),
        walk=dict(quadros=34, passo=0.60, altura=0.11, apoio=0.62, bob=0.035, bob_fase=0.08, roll=5, yaw=7, lado=0.05),
        run=dict(quadros=20, passo=1.20, altura=0.20, apoio=0.40, bob=0.07, bob_fase=0.2, roll=5, yaw=9, lado=0.03, inclinar=18, braco_amp=26,
                 braco_base=30),
        # corrida baixa com as lâminas arrastando atrás (o ângulo do braço é procurado quadro a quadro: ponta da lâmina a 3 cm do chão)
        arrancada=dict(quadros=18, passo=1.30, altura=0.16, apoio=0.42, bob=0.05, bob_fase=0.2, roll=3, yaw=5, lado=0.02, inclinar=26,
                       descer_extra=0.24, braco_amp=0, arrastar=0.03),
    ),
    "Florescida": dict(
        tipo="quad", polo={"FL": (0, 1, 0), "FR": (0, 1, 0), "BL": (0, -1, 0), "BR": (0, -1, 0)}, descer=0.12,
        # coxa traseira = folha de pele grande: passo menor (e apoio na mesma proporção, para o pé não patinar)
        escala_passo={"BL": 0.6, "BR": 0.6}, dedo_cima=0,
        inclinar=0, cabeca=dict(base=0, bob=5),
        walk=dict(quadros=40, passo=0.70, altura=0.16, apoio=0.72, bob=0.03, bob_fase=0.1, roll=3, yaw=4,
                  fase={"BL": 0.0, "FL": 0.25, "BR": 0.5, "FR": 0.75}),
        # galope rotativo: um tempo de voo por ciclo; nativo ~60 studs/s no tamanho final (escala 7,27)
        run=dict(quadros=15, passo=1.10, altura=0.28, apoio=0.27, bob=0.10, bob_fase=0.3, roll=2, yaw=3, galope=True,
                 fase={"BL": 0.0, "BR": 0.10, "FL": 0.42, "FR": 0.52}, inclinar=0),
    ),
}


def S(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def rampa(p, a, b):
    return S((p - a) / (b - a))


def acel(p, a, b):
    # entra devagar e chega rápido (golpe: a velocidade é máxima no impacto)
    x = max(0.0, min(1.0, (p - a) / (b - a)))
    return x * x


def janela(p, a, b, c, d):
    return rampa(p, a, b) * (1 - rampa(p, c, d))


def rot(pitch=0.0, roll=0.0, yaw=0.0):
    return (Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(roll), 4, "Y")
            @ Matrix.Rotation(math.radians(pitch), 4, "X"))


def em_torno(pivo, m):
    return Matrix.Translation(pivo) @ m @ Matrix.Translation(-pivo)


def base_dobra(u, v):
    x = u.normalized()
    z = u.cross(v).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


def rigido(p0, b0, p1, b1):
    return Matrix.Translation(p1) @ (b1 @ b0.inverted()).to_4x4() @ Matrix.Translation(-p0)


def ik2(s, w, a, b, polo):
    d = w - s
    dist = min(max(d.length, abs(a - b) + 1e-3), (a + b) * 0.985)
    eixo = d.normalized()
    w = s + eixo * dist
    x = (a * a - b * b + dist * dist) / (2 * dist)
    h = math.sqrt(max(a * a - x * x, 0.0))
    p = polo - eixo * polo.dot(eixo)
    if p.length < 1e-6:
        p = Vector((0, -1, 0))
    return s + eixo * x + p.normalized() * h, w


class Animador:
    def __init__(self, nome, arm, malha):
        self.nome, self.arm, self.malha = nome, arm, malha
        self.cfg = ANIM[nome]
        self.quad = self.cfg["tipo"] == "quad"
        self.membros = MEMBROS_QUAD if self.quad else MEMBROS_BIPED
        B = arm.data.bones
        self.B = B
        self.re = dict(self.cfg.get("nomes") or {b.name: b.name for b in B})  # lógico -> real
        self.lo = {v: k for k, v in self.re.items()}
        self.rest = {k: B[v].matrix_local.copy() for k, v in self.re.items()}
        self.cab = {k: B[v].head_local.copy() for k, v in self.re.items()}
        self.ordem = list(self.rest)

        def logico(real):
            b = B.get(real)
            while b is not None and b.name not in self.lo:
                b = b.parent
            return self.lo[b.name] if b is not None else None

        self.logico = logico
        nomes = {g.index: logico(g.name) for g in malha.vertex_groups}
        N = len(malha.data.vertices)
        self.V = np.ones((N, 4))
        self.W = np.zeros((N, len(self.ordem)))
        col = {n: i for i, n in enumerate(self.ordem)}
        for v in malha.data.vertices:
            self.V[v.index, :3] = v.co[:]
            for g in v.groups:
                n = nomes.get(g.group)
                if n and g.weight > 1e-4:
                    self.W[v.index, col[n]] += g.weight
        s = self.W.sum(1)
        s[s == 0] = 1
        self.W /= s[:, None]
        self.col = col

        def grupo(nomes_log, lim=0.5):
            ids = [col[n] for n in nomes_log if n in col]
            return np.where(self.W[:, ids].sum(1) > lim)[0] if ids else np.array([], dtype=int)

        self.grupo = grupo
        self.pts, self.giro0, self.base, self.vpe, self.ponta = {}, {}, {}, {}, {}
        for k, m in self.membros.items():
            ini, meio, fim = self.cab[m["a"]], self.cab[m["b"]], self.cab[m["pe"][0]]
            self.pts[k] = (ini, meio, fim)
            g = Matrix.Identity(4)
            alvo = self.cfg.get("pe_dir", {}).get(k)
            if alvo:
                ult = B[self.re[m["pe"][-1]]]
                d0 = (ult.tail_local - fim).normalized()
                g = d0.rotation_difference(Vector(alvo).normalized()).to_matrix().to_4x4()
            self.giro0[k] = g
            idx = grupo(m["pe"])
            if self.quad and k.startswith("F"):
                # pata da frente: o casco pesa no antebraço e na mão; vale o que está abaixo do pulso
                cand = grupo([m["b"]] + m["pe"])
                idx = cand[self.V[cand, 2] < fim.z]
            self.vpe[k] = idx
            gpe = em_torno(fim, g)
            P = np.array([(gpe @ Vector(self.V[i, :3])) for i in idx]) if len(idx) else np.array([[fim.x, fim.y, fim.z - 0.05]])
            piso = P[:, 2].min()
            # ponta do pé: o vértice mais à frente entre os que tocam o chão (pivô do calcanhar)
            perto = P[P[:, 2] < piso + 0.04]
            q = perto[np.argmin(perto[:, 1])]
            self.ponta[k] = Vector((q[0], q[1], piso)) - fim
            if self.quad:
                x, y = fim.x, fim.y
            else:
                x, y = self.cfg["x_pe"][k], self.cfg["y_pe"]
            self.base[k] = Vector((x, y, fim.z - piso + 0.005))
        # vértices que podem tocar o chão sem erguer o corpo (braços do bípede; pés)
        self.vbraco = grupo([f"{a}.{s}" for a in ("UpperArm", "LowerArm", "Hand") for s in "LR"]) if not self.quad else np.array([], dtype=int)
        self.vmao = {s: grupo([f"LowerArm.{s}", f"Hand.{s}"]) for s in "LR"}  # antebraço + mão (a lâmina pesa no antebraço)
        self.vcab = grupo(["Head", "Jaw"])
        mask = np.ones(N, dtype=bool)
        for idx in self.vpe.values():
            mask[idx] = False
        if len(self.vbraco):
            mask[self.vbraco] = False
        self.vcorpo = np.where(mask)[0]
        for _ in range(3):  # calibra: na pose neutra o pé toca o chão de fato (medido na malha deformada)
            P = self.posicoes(self.resolver(self.neutro()))
            for k, idx in self.vpe.items():
                if len(idx):
                    self.base[k].z -= float(P[idx, 2].min()) - 0.005

    # ---- corpo: e = dict de ângulos/deslocamentos; e["membros"][k] = dict(alvo=Vector, giro=Matrix)
    def resolver(self, e):
        G = {}
        c = self.cab
        G["Hips"] = Matrix.Translation(e.get("mov", Vector())) @ em_torno(c["Hips"], rot(e.get("pitch", 0), e.get("roll", 0), e.get("yaw", 0)))
        dob, tor = e.get("dobra", 0), e.get("torce", 0)
        G["Spine"] = G["Hips"] @ em_torno(c["Spine"], rot(dob * 0.5, e.get("roll_t", 0) * 0.5, tor * 0.5))
        G["Chest"] = G["Spine"] @ em_torno(c["Chest"], rot(dob * 0.5, e.get("roll_t", 0) * 0.5, tor * 0.5))
        G["Neck"] = G["Chest"] @ em_torno(c["Neck"], rot(e.get("pesc_p", 0), e.get("pesc_r", 0), e.get("pesc_y", 0)))
        G["Head"] = G["Neck"] @ em_torno(c["Head"], rot(e.get("cab_p", 0), e.get("cab_r", 0), e.get("cab_y", 0)))
        if "Jaw" in c:
            G["Jaw"] = G["Head"] @ em_torno(c["Jaw"], rot(e.get("boca", 0)))
        for i in (1, 2, 3):
            n = f"Tail.{i}"
            if n in c:
                G[n] = G["Hips" if i == 1 else f"Tail.{i - 1}"] @ em_torno(c[n], rot(e.get("cauda_p", 0) * i / 2, 0, e.get("cauda_y", 0) * i / 2))
        if not self.quad:
            for s in "LR":
                br = e["bracos"][s]
                G[f"UpperArm.{s}"] = G["Chest"] @ em_torno(c[f"UpperArm.{s}"], rot(br.get("p", 0), br.get("r", 0), br.get("y", 0)))
                G[f"LowerArm.{s}"] = G[f"UpperArm.{s}"] @ em_torno(c[f"LowerArm.{s}"], rot(br.get("cot", 0)))
                G[f"Hand.{s}"] = G[f"LowerArm.{s}"] @ em_torno(c[f"Hand.{s}"], rot(br.get("mao", 0)))
        for k, m in self.membros.items():
            ini, meio, fim = self.pts[k]
            a, b = (meio - ini).length, (fim - meio).length
            mp = e["membros"][k]
            s = G[m["pai"]] @ ini
            polo = self.cfg["polo"][k] if isinstance(self.cfg["polo"], dict) else self.cfg["polo"]
            polo = (G[m["pai"]].to_3x3() @ Vector(polo)) if mp.get("polo_corpo") else Vector(polo)
            cot, w = ik2(s, mp["alvo"], a, b, polo)
            G[m["a"]] = rigido(ini, base_dobra(meio - ini, fim - meio), s, base_dobra(cot - s, w - cot))
            G[m["b"]] = rigido(meio, base_dobra(fim - meio, meio - ini), cot, base_dobra(w - cot, s - cot))
            gp = Matrix.Translation(w) @ mp.get("giro", Matrix.Identity(4)) @ self.giro0[k] @ Matrix.Translation(-fim)
            for n in m["pe"]:
                if n in self.cab:
                    G[n] = gp
        for n in self.ordem:  # ossos lógicos não tratados acima (não deveria haver): seguem o pai
            if n not in G:
                b = self.B[self.re[n]].parent
                while b is not None and b.name not in self.lo:
                    b = b.parent
                G[n] = G.get(self.lo[b.name], Matrix.Identity(4)) if b is not None else Matrix.Identity(4)
        return G

    def posicoes(self, G):
        Gs = np.array([np.array(G[n]) for n in self.ordem])
        return np.einsum("nb,bij,nj->ni", self.W, Gs, self.V)[:, :3]

    def piso(self, G, idx=None):
        P = self.posicoes(G)
        return float(P[:, 2].min() if idx is None else P[idx, 2].min())

    def assentar(self, e, voltas=10):
        # pé e corpo nunca abaixo do chão: ergue o alvo de cada pé que afunda e, se o corpo (sem braços/pés) afundar, o corpo todo
        for _ in range(voltas):
            G = self.resolver(e)
            P = self.posicoes(G)
            mexeu = False
            for k, idx in self.vpe.items():
                if len(idx):
                    z = P[idx, 2].min()
                    if z < -1e-3:
                        e["membros"][k]["alvo"] = e["membros"][k]["alvo"] + Vector((0, 0, -z))
                        mexeu = True
            z = P[self.vcorpo, 2].min() if len(self.vcorpo) else 0
            if z < -1e-3:
                e["mov"] = e.get("mov", Vector()) + Vector((0, 0, -z))
                mexeu = True
            if not mexeu:
                return G
        return self.resolver(e)

    def gravar(self, G, quadro, ant):
        for pb in self.arm.pose.bones:
            n = self.logico(pb.name)
            gn = G[n] if n else Matrix.Identity(4)
            pai = self.logico(pb.parent.name) if pb.parent else None
            gpai = G[pai] if pai else Matrix.Identity(4)
            r = pb.bone.matrix_local
            loc, q, _ = (r.inverted() @ gpai.inverted() @ gn @ r).decompose()
            if pb.name in ant:
                q.make_compatible(ant[pb.name])
            ant[pb.name] = q
            pb.location = loc
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=quadro)
            pb.keyframe_insert("rotation_quaternion", frame=quadro)

    # ---- estados base
    def neutro(self):
        cfg = self.cfg
        e = dict(mov=Vector((0, 0, -cfg.get("descer", 0))), pitch=cfg.get("inclinar", 0), cab_p=cfg["cabeca"]["base"],
                 membros={k: dict(alvo=self.base[k].copy()) for k in self.membros})
        if not self.quad:
            br = cfg["braco"]
            e["bracos"] = {s: dict(p=br["base"], cot=br["cotovelo"]) for s in "LR"}
        return e

    def braco(self, e, s, p=None, cot=None, r=None, y=None, w=1.0):
        # mistura o braço s para o alvo (graus absolutos) com peso w
        b = e["bracos"][s]
        for chave, v in (("p", p), ("cot", cot), ("r", r), ("y", y)):
            if v is not None:
                b[chave] = b.get(chave, 0) * (1 - w) + v * w

    def passinho(self, e, k, dy, t, a, b, c, d, altura=0.06):
        # pé k recua dy entre a..b e volta entre c..d, sempre erguido enquanto se move (pé no chão não escorrega)
        ida, volta = rampa(t, a, b), rampa(t, c, d)
        z = altura * (math.sin(math.pi * max(0.0, min(1.0, (t - a) / (b - a)))) + math.sin(math.pi * max(0.0, min(1.0, (t - c) / (d - c)))))
        e["membros"][k]["alvo"] = e["membros"][k]["alvo"] + Vector((0, dy * ida * (1 - volta), z))

    def ciclo(self, p, modo):
        cfg = self.cfg
        c = cfg[modo]
        e = self.neutro()
        e["pitch"] = e["pitch"] + c.get("inclinar", 0)
        e["mov"] = e["mov"] - Vector((0, 0, c.get("descer_extra", 0)))
        t2 = 2 * math.pi * p
        for k in self.membros:
            fase = c["fase"][k] if self.quad else (0.0 if k == "L" else 0.5)
            ps = (p + fase) % 1.0
            b = self.base[k]
            esc = cfg.get("escala_passo", {}).get(k, 1.0)
            passo, apoio = c["passo"] * esc, c["apoio"] * esc
            if ps < apoio:
                u = ps / apoio
                dy, dz = -passo / 2 + passo * u, 0.0
                pt = -14 * rampa(u, 0.7, 1.0)  # calcanhar sobe no fim do apoio (gira na ponta do pé)
            else:
                u = (ps - apoio) / (1 - apoio)
                dy = passo / 2 - passo * S(u)
                dz = c["altura"] * esc ** 0.5 * math.sin(math.pi * u) ** 0.6
                pt = -14 * (1 - S(u * 2.5)) + cfg.get("dedo_cima", 10) * rampa(u, 0.45, 0.75) * (1 - rampa(u, 0.75, 0.92))
            alvo = Vector((b.x, b.y + dy, b.z + dz))
            R = rot(pitch=-pt)
            if -pt > 0:  # calcanhar subindo: o tornozelo gira em volta da ponta (a ponta não arrasta)
                d = self.ponta[k]
                alvo = alvo + d - (R.to_3x3() @ d)
            e["membros"][k] = dict(alvo=alvo, giro=em_torno(Vector(), R))
        bf = c.get("bob_fase", 0.0)
        if c.get("galope"):
            # um voo por ciclo: corpo sobe depois do impulso das traseiras, balança em pitch e a coluna flexiona/estende
            e["mov"] = e["mov"] + Vector((0, 0, -c["bob"] * 0.5 * (1 + math.cos(t2 - 2 * math.pi * bf))))
            e["pitch"] += 7 * math.sin(t2 + 0.6)
            e["dobra"] = 12 * math.sin(t2 + 2.2)
            e["pesc_p"] = -8 * math.sin(t2 + 0.9)
            e["cauda_p"] = -10 + 8 * math.sin(t2 + 1.5)
            e["cauda_y"] = 3 * math.sin(t2)
            e["boca"] = 10 + 6 * math.sin(t2)
            e["roll"] = c["roll"] * math.sin(t2)
            return e
        e["mov"] = e["mov"] + Vector((c.get("lado", 0) * math.sin(t2), 0, -c["bob"] * 0.5 * (1 + math.cos(2 * t2 - 4 * math.pi * bf))))
        e["roll"] = c["roll"] * math.sin(t2)
        e["yaw"] = c["yaw"] * math.sin(t2)
        e["torce"] = -c["yaw"] * 1.5 * math.sin(t2)
        e["cab_p"] = e["cab_p"] + cfg["cabeca"]["bob"] * 0.5 * math.cos(2 * t2 - 4 * math.pi * bf - 0.6)
        e["cab_y"] = -c["yaw"] * 0.8 * math.sin(t2)
        if c.get("manca"):  # Corcunda: manca da perna R (afunda mais no apoio da R)
            e["mov"] = e["mov"] + Vector((0, 0, -0.03 * c["manca"] * max(0.0, -math.sin(t2))))
            e["roll"] += 3 * c["manca"] * math.sin(t2)
        if self.quad:
            e["cauda_y"] = 10 * math.sin(t2 + 1.0)
            e["cauda_p"] = 4 * math.cos(2 * t2)
            e["pesc_p"] = 4 * math.cos(2 * t2 + 0.6)
        else:
            amp = c.get("braco_amp", cfg["braco"]["amp"])
            for s, sinal in (("L", 1), ("R", -1)):
                if "braco_base" in c:
                    e["bracos"][s]["p"] = c["braco_base"]
                e["bracos"][s]["p"] += sinal * amp * math.cos(t2 - 0.5)  # braço atrasa um pouco a perna (peso)
                e["bracos"][s]["cot"] += -abs(amp) * 0.4 * (0.5 + 0.5 * sinal * math.cos(t2 - 0.5))
        return e

    def arrastar_bracos(self, e, alvo_z, osc=0.0):
        # procura (pitch, roll) do braço esticado que deixa a ponta da lâmina em alvo_z, o mais para trás possível
        for s in "LR":
            idx = self.vmao[s]
            if not len(idx):
                continue
            base = dict(e["bracos"][s], cot=0)
            sinal = -1 if s == "L" else 1
            melhor, pior = None, (9.0, base)
            for pa in range(-40, 150, 5):
                for ra in range(0, 70, 10):
                    cand = dict(base, p=pa, r=sinal * ra)
                    e["bracos"][s] = cand
                    z = self.piso(self.resolver(e), idx)
                    if z < pior[0]:
                        pior = (z, cand)
                    if alvo_z - 0.01 <= z <= alvo_z + 0.04 and (melhor is None or pa > melhor["p"]):
                        melhor = cand
            e["bracos"][s] = dict(melhor or pior[1])
            e["bracos"][s]["p"] += osc
        return e

    def idle(self, p):
        e = self.neutro()
        t2 = 2 * math.pi * p
        e["dobra"] = 3 * math.sin(t2)  # respira
        e["mov"] = e["mov"] + Vector((0.01 * math.sin(t2 + 0.4), 0, -0.015 * (0.5 + 0.5 * math.sin(t2))))
        e["pesc_y"] = 12 * math.sin(t2 + 0.5)
        e["cab_r"] = 7 * math.sin(2 * t2)  # cabeça inclina como quem escuta
        e["cab_p"] = e["cab_p"] + 3 * math.sin(t2 * 2 + 1.0)
        e["roll"] = 1.5 * math.sin(t2 + 0.4)
        if self.quad:
            e["cauda_y"] = 9 * math.sin(t2)
            e["cauda_p"] = 3 * math.sin(2 * t2)
            e["boca"] = 6 * (0.5 + 0.5 * math.sin(2 * t2))
        else:
            for s, sinal in (("L", 1), ("R", -1)):
                e["bracos"][s]["p"] += 4 * math.sin(t2 + sinal)
                e["bracos"][s]["r"] = sinal * 2 * math.sin(t2)
        return e

    # ---- golpe padrão (Attack): antecipação, golpe acelerado até o impacto, segura, volta
    def ataque(self, t, ti=0.45, D=0.9):
        e = self.neutro()
        prep = rampa(t, 0.0, ti - 0.14) * (1 - acel(t, ti - 0.14, ti))
        golpe = acel(t, ti - 0.14, ti) * (1 - rampa(t, ti + 0.12, D))
        e["pitch"] += -12 * prep + 22 * golpe
        e["mov"] = e["mov"] + Vector((0, 0.10 * prep - 0.24 * golpe, -0.04 * prep - 0.08 * golpe))
        e["dobra"] = -10 * prep + 14 * golpe
        e["cab_p"] = e["cab_p"] - 15 * prep + 10 * golpe
        if self.quad:
            e["pitch"] = -16 * prep + 12 * golpe
            e["pesc_p"] = -28 * prep + 32 * golpe
            e["cab_p"] = -10 * prep + 8 * golpe
            e["boca"] = 38 * prep * (1 - golpe) + 38 * (1 - acel(t, ti - 0.06, ti)) * golpe  # abre e fecha no impacto
            e["cauda_p"] = -18 * prep + 6 * golpe
        else:
            br = self.cfg["braco"]
            for s in "LR":
                e["bracos"][s]["p"] = br["base"] + (-135 - br["base"]) * prep + (-35 - br["base"]) * golpe
                e["bracos"][s]["cot"] = br["cotovelo"] - 45 * prep + 20 * golpe
                e["bracos"][s]["r"] = (-10 if s == "L" else 10) * prep
        return e

    def morte(self, k, piso_final):
        # 1) tranco, os joelhos cedem e o tronco desaba; 2) o corpo todo tomba de lado; 3) assenta com um quique pequeno
        e = self.neutro()
        tranco = janela(k, 0.0, 0.10, 0.12, 0.28)
        cai = rampa(k, 0.12, 0.5) ** 1.4
        e["mov"] = e["mov"] + Vector((0, 0.06 * tranco, 0.05 * tranco - 0.30 * cai))
        e["pitch"] += -10 * tranco + 20 * cai
        e["dobra"] = -12 * tranco + 25 * cai
        e["cab_p"] = e["cab_p"] - 20 * tranco + 25 * cai
        e["pesc_p"] = 10 * cai
        if self.quad:
            e["boca"] = 30 * tranco + 25 * cai
            e["cauda_p"] = 20 * cai
        else:
            for s in "LR":
                e["bracos"][s]["p"] = e["bracos"][s]["p"] * (1 - cai) + 25 * cai - 40 * tranco
                e["bracos"][s]["cot"] = -30 * cai
        G = self.resolver(e)
        tomba = rampa(k, 0.35, 0.82) ** 1.5
        quica = 3 * math.sin(math.pi * rampa(k, 0.82, 0.95))
        T = em_torno(Vector((0.3 if self.quad else 0.35, 0, 0)), rot(roll=80 * tomba - quica, pitch=0 if self.quad else 8 * tomba))
        G = {n: T @ g for n, g in G.items()}
        if piso_final is not None:
            sobe = Matrix.Translation(Vector((0, 0, -piso_final * rampa(k, 0.3, 0.82))))
            G = {n: sobe @ g for n, g in G.items()}
            z = self.piso(G)
            if z < 0:  # nenhum quadro atravessa o chão
                G = {n: Matrix.Translation(Vector((0, 0, -z))) @ g for n, g in G.items()}
        return G

    # ================= Corcunda
    def empurrao(self, t, ti=0.35, D=0.7):
        e = self.neutro()
        prep = rampa(t, 0.0, 0.22) * (1 - acel(t, 0.22, ti))
        golpe = acel(t, 0.22, ti) * (1 - rampa(t, 0.47, D))
        e["pitch"] += -8 * prep + 14 * golpe
        e["dobra"] = -6 * prep + 8 * golpe
        e["mov"] = e["mov"] + Vector((0, 0.08 * prep - 0.18 * golpe, -0.06 * prep - 0.04 * golpe))
        e["cab_p"] = e["cab_p"] - 6 * prep + 6 * golpe
        for s in "LR":
            self.braco(e, s, p=-55, cot=-105, r=(8 if s == "L" else -8), w=prep)
            self.braco(e, s, p=-88, cot=-4, r=0, w=golpe)
        # pé de trás empurra o chão: o R recua um pouco para dar base
        self.passinho(e, "R", 0.10, t, 0.02, 0.18, 0.48, D)
        return e

    def abrir_porta(self, t, ti=0.40, D=0.8):
        e = self.neutro()
        estica = rampa(t, 0.05, 0.30) * (1 - rampa(t, 0.52, D))
        empurra = acel(t, 0.28, ti) * (1 - rampa(t, 0.48, 0.7))
        e["pitch"] += 4 * estica + 6 * empurra
        e["mov"] = e["mov"] + Vector((0, -0.05 * estica - 0.08 * empurra, 0))
        e["torce"] = -10 * estica
        e["cab_y"] = -8 * estica
        e["cab_p"] = e["cab_p"] - 6 * estica
        self.braco(e, "R", p=-72, cot=-30, r=-4, w=estica)
        self.braco(e, "R", p=-84, cot=-6, w=empurra)
        self.braco(e, "L", p=4, cot=-25, w=estica * 0.6)
        return e

    def emboscada(self, p):
        # loop: agachado, quieto, respira devagar; a cabeça vira de leve escutando
        e = self.neutro()
        t2 = 2 * math.pi * p
        e["mov"] = e["mov"] + Vector((0, 0.08, -0.30 - 0.015 * (0.5 + 0.5 * math.sin(t2))))
        e["pitch"] += 22
        e["dobra"] = 22 + 3 * math.sin(t2)
        e["pesc_p"] = -18
        e["cab_p"] = e["cab_p"] - 10 + 2 * math.sin(t2 + 0.8)
        e["cab_y"] = 10 * math.sin(t2 + 1.2)
        e["cab_r"] = 5 * math.sin(t2 * 2)
        for s, sinal in (("L", 1), ("R", -1)):
            self.braco(e, s, p=-20 + 2 * math.sin(t2 + sinal), cot=-30, r=(-6 if s == "L" else 6))
        for k in "LR":
            e["membros"][k]["alvo"] = e["membros"][k]["alvo"] + Vector((0.06 * (1 if k == "L" else -1), 0, 0))
        return e

    def imitar(self, t, D=1.5):
        # cabeça treme e o pescoço/mandíbula batem como quem fala (sem osso de mandíbula: pescoço e cabeça em sílabas)
        e = self.idle(t / 2.0)
        a = rampa(t, 0.0, 0.18) * (1 - rampa(t, D - 0.25, D))
        silabas = abs(math.sin(2 * math.pi * 2.5 * t)) * (0.6 + 0.4 * math.sin(2 * math.pi * 1.3 * t))
        e["pesc_p"] = e.get("pesc_p", 0) - 8 * a + 9 * a * silabas
        e["cab_p"] = e["cab_p"] - 10 * a * silabas
        e["cab_r"] = e.get("cab_r", 0) * (1 - a) + a * (5 * math.sin(2 * math.pi * 5 * t) + 10 * math.sin(2 * math.pi * 0.7 * t))
        e["cab_y"] = a * 6 * math.sin(2 * math.pi * 3.5 * t + 1)
        e["dobra"] = e.get("dobra", 0) + 3 * a * silabas
        return e

    # ================= MonstroPS1
    def golpe_duplo(self, t, t1=0.35, t2=0.65, D=1.0):
        e = self.neutro()
        sobeR = rampa(t, 0.0, t1 - 0.12) * (1 - acel(t, t1 - 0.12, t1))
        corteR = acel(t, t1 - 0.12, t1) * (1 - rampa(t, t1 + 0.1, D - 0.1))
        sobeL = rampa(t, 0.25, t2 - 0.12) * (1 - acel(t, t2 - 0.12, t2))
        corteL = acel(t, t2 - 0.12, t2) * (1 - rampa(t, t2 + 0.1, D))
        e["torce"] = 22 * sobeR - 18 * corteR - 22 * sobeL + 18 * corteL
        e["yaw"] = 6 * (sobeR - corteR - sobeL + corteL)
        e["pitch"] += -6 * (sobeR + sobeL) + 12 * (corteR + corteL) * 0.7
        e["mov"] = e["mov"] + Vector((0, -0.10 * corteR - 0.12 * corteL, -0.05 * (corteR + corteL)))
        self.braco(e, "R", p=-130, cot=-40, r=12, w=sobeR)
        self.braco(e, "R", p=-25, cot=-5, r=-25, w=corteR)
        self.braco(e, "L", p=-130, cot=-40, r=-12, w=sobeL)
        self.braco(e, "L", p=-25, cot=-5, r=25, w=corteL)
        return e

    def arrancada(self, p):
        e = self.ciclo(p, "arrancada")
        e["cab_p"] = e["cab_p"] - 18  # olha para a frente com o tronco baixo
        return self.arrastar_bracos(e, self.cfg["arrancada"]["arrastar"], osc=3 * math.sin(2 * math.pi * 2 * p))

    def lancar(self, t, ts=0.45, D=0.8):
        e = self.neutro()
        arma = rampa(t, 0.0, 0.30) * (1 - acel(t, 0.30, ts))
        lanca = acel(t, 0.30, ts) * (1 - rampa(t, ts + 0.1, D))
        e["torce"] = 28 * arma - 22 * lanca
        e["pitch"] += -8 * arma + 14 * lanca
        e["roll"] = 4 * arma - 3 * lanca
        e["mov"] = e["mov"] + Vector((0, 0.06 * arma - 0.10 * lanca, -0.03 * arma))
        self.braco(e, "R", p=40, cot=-70, r=-25, w=arma)
        self.braco(e, "R", p=-100, cot=-5, r=-5, w=lanca)
        self.braco(e, "L", p=-30, cot=-20, r=-10, w=arma * 0.7)
        self.passinho(e, "R", 0.12, t, 0.03, 0.22, 0.55, D)
        return e

    # ================= Florescida
    def _frente(self, e, dy=0.0, dz=0.0, so=None):
        for k in (so or ("FL", "FR")):
            e["membros"][k]["alvo"] = e["membros"][k]["alvo"] + Vector((0, dy, dz))

    def rugido(self, t, ti=0.9, D=1.6):
        # empina (as patas da frente sobem e pedalam), desce com força e bate as duas no chão no impacto; ruge depois
        e = self.neutro()
        empina = rampa(t, 0.0, 0.60) * (1 - acel(t, 0.66, ti))
        ruge = rampa(t, ti - 0.05, ti + 0.15) * (1 - rampa(t, 1.3, D))
        e["pitch"] = -30 * empina + 6 * ruge
        e["mov"] = e["mov"] + Vector((0, 0.10 * empina, -0.08 * empina - 0.06 * ruge))
        e["dobra"] = -10 * empina + 6 * ruge
        e["pesc_p"] = -20 * empina - 18 * ruge
        e["cab_p"] = -10 * ruge
        e["boca"] = 20 * empina + 45 * ruge
        e["cauda_p"] = 15 * empina - 10 * ruge
        ped = math.sin(2 * math.pi * 2.5 * t) * empina
        for k, sinal in (("FL", 1), ("FR", -1)):
            e["membros"][k]["alvo"] = e["membros"][k]["alvo"] + Vector((0, -0.25 * empina - 0.12 * ruge, 1.0 * empina + 0.12 * sinal * ped))
        return e

    def cauda(self, t, ti=0.45, D=0.9):
        e = self.neutro()
        arma = rampa(t, 0.0, 0.30) * (1 - acel(t, 0.30, ti))
        chicote = acel(t, 0.30, ti) * (1 - rampa(t, ti + 0.1, D))
        e["cauda_y"] = -45 * arma + 55 * chicote
        e["cauda_p"] = -25 * arma + 12 * chicote
        e["yaw"] = 6 * arma - 8 * chicote
        e["roll"] = -3 * arma + 4 * chicote
        e["pesc_y"] = -12 * arma + 10 * chicote
        e["cab_y"] = -8 * arma
        e["pitch"] = 4 * arma + 4 * chicote  # baixa a frente para erguer o quadril
        return e

    def florescer(self, t, tp=0.9, D=1.5):
        e = self.neutro()
        baixa = rampa(t, 0.0, 0.70) * (1 - rampa(t, 1.08, D))
        crava = janela(t, 0.80, tp, tp, 1.0)
        e["pitch"] = self.pitch_chao * baixa
        e["mov"] = e["mov"] + Vector((0, 0.05 * baixa, -0.25 * baixa))
        e["pesc_p"] = self.pesc_chao * baixa + 4 * crava
        e["cab_p"] = 20 * baixa + 6 * crava
        e["boca"] = 8 * baixa
        e["cauda_p"] = -6 * baixa
        return e

    def arrancar_fachada(self, t, ti=0.8, D=1.8):
        e = self.neutro()
        prep = rampa(t, 0.0, 0.45) * (1 - acel(t, 0.48, ti))
        bote = acel(t, 0.48, ti) * (1 - rampa(t, 1.2, D))
        puxa = rampa(t, ti + 0.02, 1.30) * (1 - rampa(t, 1.40, D))
        e["mov"] = e["mov"] + Vector((0.08 * puxa, 0.12 * prep - 0.24 * bote + 0.20 * puxa, -0.05 * prep))
        e["pitch"] = -10 * prep + 8 * bote - 4 * puxa
        e["pesc_p"] = -22 * prep + 22 * bote - 8 * puxa
        e["pesc_y"] = 50 * puxa
        e["cab_y"] = 15 * puxa
        e["cab_r"] = 18 * puxa
        e["yaw"] = 14 * puxa
        e["roll"] = -5 * puxa
        e["boca"] = 40 * prep + 40 * bote * (1 - acel(t, ti - 0.06, ti)) * (1 - puxa) + 6 * puxa
        e["cauda_y"] = -20 * puxa
        e["cauda_p"] = -12 * prep
        return e


# Clipes por monstro: (nome, duração s, gerador, cíclico, eventos {nome: s}). Cíclicos: gerador recebe a fase 0..1; os outros, o tempo em s.
def clipes(A):
    cfg = A.cfg
    base = [("Idle", 2.0, A.idle, True, {}),
            ("Walk", cfg["walk"]["quadros"] / FPS, lambda p: A.ciclo(p, "walk"), True, {}),
            ("Run", cfg["run"]["quadros"] / FPS, lambda p: A.ciclo(p, "run"), True, {}),
            ("Attack", 0.9, lambda t: A.ataque(t, 0.45, 0.9), False, {"impacto": 0.45})]
    extra = {
        "Corcunda": [("Empurrao", 0.7, A.empurrao, False, {"impacto": 0.35}),
                     ("AbrirPorta", 0.8, A.abrir_porta, False, {"porta": 0.40}),
                     ("Emboscada", 3.0, A.emboscada, True, {}),
                     ("Imitar", 1.5, A.imitar, False, {})],
        "MonstroPS1": [("GolpeDuplo", 1.0, A.golpe_duplo, False, {"impacto1": 0.35, "impacto2": 0.65}),
                       ("Arrancada", cfg.get("arrancada", {}).get("quadros", 18) / FPS, A.arrancada, True, {}),
                       ("Lancar", 0.8, A.lancar, False, {"soltar": 0.45})],
        "Florescida": [("Rugido", 1.6, A.rugido, False, {"impacto": 0.9}),
                       ("Cauda", 0.9, A.cauda, False, {"impacto": 0.45}),
                       ("Florescer", 1.5, A.florescer, False, {"plantar": 0.9}),
                       ("ArrancarFachada", 1.8, A.arrancar_fachada, False, {"impacto": 0.8})],
    }
    return base + extra.get(A.nome, [])


LOCOMOCAO = {"Walk": "walk", "Run": "run", "Arrancada": "arrancada"}


def medir(A, Gs, ciclica, v_quadro):
    # medido na malha deformada (skinning em numpy): chão de cada pé e do corpo, escorregão do pé plantado, emenda do ciclo
    zmin, zpe = 9.0, 9.0
    hist = {k: [] for k in A.membros}
    for G in Gs:
        P = A.posicoes(G)
        zmin = min(zmin, float(P[A.vcorpo, 2].min()))
        for k, idx in A.vpe.items():
            z = float(P[idx, 2].min())
            zpe = min(zpe, z)
            hist[k].append((z, P[idx]))
    desliz = 0.0
    for k, h in hist.items():
        for i in range(len(h) - 1):
            if h[i][0] < 0.012 and h[i + 1][0] < 0.012:
                j = int(np.argmin(h[i][1][:, 2]))  # o ponto de contato deste quadro, seguido até o próximo
                dx, dy = h[i + 1][1][j, 0] - h[i][1][j, 0], h[i + 1][1][j, 1] - h[i][1][j, 1]
                desliz = max(desliz, math.hypot(dx, dy - v_quadro))
    emenda = 0.0
    if ciclica:
        a, b = A.posicoes(Gs[0]), A.posicoes(Gs[-1])
        emenda = float(np.abs(a - b).max())
    return dict(zmin_corpo=round(zmin, 4), zmin_pes=round(zpe, 4), escorregao_max_m_quadro=round(desliz, 4), emenda_ciclo=round(emenda, 5))


def animar(nome, arm, malha, saida_json, prefixo, classe=None, lista=None):
    """Grava todas as ações no arm; devolve o info (também gravado em saida_json). classe/lista: Animador e clipes de outro rig."""
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    A = (classe or Animador)(nome, arm, malha)
    if A.quad:  # ângulo do pescoço que põe a cabeça no chão (Florescer)
        melhor = (99, 0, 0)
        for pit in range(10, 41, 5):
            for ang in range(0, 91, 3):
                e = A.neutro()
                e.update(pitch=pit, mov=e["mov"] + Vector((0, 0.05, -0.25)), cab_p=20, pesc_p=ang)
                z = A.piso(A.assentar(e), A.vcab)
                if abs(z - 0.03) < abs(melhor[0] - 0.03) - 0.005:  # menor inclinação que chega
                    melhor = (z, ang, pit)
        A.pesc_chao, A.pitch_chao = melhor[1], melhor[2]
        info_chao = dict(pesc=melhor[1], pitch=melhor[2], cabeca_z=round(melhor[0], 3))
    arm.animation_data_create()
    cena = bpy.context.scene
    cena.render.fps = FPS
    info = dict(nome=nome, fps=FPS, acoes={})
    if A.quad:
        info["florescer_chao"] = info_chao
    for rotulo, D, gerar, ciclica, eventos in (lista or clipes)(A):
        n = round(D * FPS)
        act = bpy.data.actions.new(f"{prefixo}{rotulo}")
        act.use_fake_user = True
        arm.animation_data.action = act
        Gs = []
        for f in range(n):
            x = f / n if ciclica else f / FPS
            Gs.append(A.assentar(gerar(x)))
        if ciclica:
            Gs.append(Gs[0])
        else:
            Gs.append(A.assentar(gerar(n / FPS)))
        ant = {}
        for f, G in enumerate(Gs):
            A.gravar(G, f, ant)
        act.frame_range = (0, n)
        modo = LOCOMOCAO.get(rotulo)
        v = 0.0
        d = dict(quadros=n + 1, ciclica=ciclica, duracao=round(n / FPS, 4))
        if eventos:
            d["eventos"] = {k: round(round(s * FPS) / FPS, 4) for k, s in eventos.items()}
        if modo:
            c = A.cfg[modo]
            v = c["passo"] / (c["apoio"] * c["quadros"])  # m por quadro
            d["velocidade_nativa_m_s"] = round(v * FPS, 3)
        d["medidas"] = medir(A, Gs, ciclica, v)
        info["acoes"][rotulo] = d
    # morte: tomba e assenta no chão
    nD = round(1.5 * FPS)
    piso = A.piso(A.morte(1.0, None))
    act = bpy.data.actions.new(f"{prefixo}Death")
    act.use_fake_user = True
    arm.animation_data.action = act
    Gs = [A.morte(f / nD, piso) for f in range(nD + 1)]
    ant = {}
    for f, G in enumerate(Gs):
        A.gravar(G, f, ant)
    act.frame_range = (0, nD)
    info["acoes"]["Death"] = dict(quadros=nD + 1, ciclica=False, duracao=round(nD / FPS, 4), medidas=medir(A, Gs, False, 0.0))
    arm.animation_data.action = bpy.data.actions[f"{prefixo}Walk"]
    cena.frame_start, cena.frame_end = 0, A.cfg["walk"]["quadros"]
    with open(saida_json, "w", encoding="utf-8") as fp:
        json.dump(info, fp, ensure_ascii=False, indent=1)
    return info


def anim(nome):
    bpy.ops.wm.open_mainfile(filepath=caminho(nome, "_rig2.blend"))
    arm = bpy.data.objects[nome + "_Rig"]
    malha = bpy.data.objects[nome]
    info = animar(nome, arm, malha, caminho(nome, "_v2.json"), nome + "_")
    bpy.ops.wm.save_as_mainfile(filepath=caminho(nome, "_v2.blend"))
    return info


# ================================================================= principal

if __name__ == "__main__" and "--" in sys.argv:
    a = args()
    etapa, nome = a["etapa"], a["nome"]
    r = globals()[etapa](nome)
    print("##REFAZER## " + json.dumps(r, ensure_ascii=False))
