"""Exporta um .blend do Gold Bright (montar_blend_gb.py) para FBX (malha + esqueleto) + manifesto + animações em dados.

Uso (da raiz):
  blender -b --factory-startup -P ferramentas/goldbright/exportar_gb.py -- --grupo "TT-33__TT33_With_Anims" [--escala 2.908] [--saida "modelos 3d/gold-bright/roblox/<grupo>"]

Mesma convenção do exportar_rastejador.py (escala nos DADOS, o Roblox desfaz o global_scale do FBX; axis_forward -Z, axis_up Y;
máx. 4 influências), com duas diferenças: escala fixa em studs por metro (2,908 = R15 de 5,234 studs para 1,8 m) em vez de altura,
e as animações guardam SÓ os ossos que cada clipe anima (o clipe "mãos" e o clipe "arma" tocam juntos).
Saídas em <saida>/: <grupo>.fbx, <grupo>_atlas.png, manifesto.json, anim_blender.json.
"""

import json
import os
import shutil
import sys

import bpy
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def arg(nome, padrao=None):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return padrao


def fcurves(acao):
    if hasattr(acao, "fcurves"):
        return acao.fcurves
    return [fc for l in acao.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves]


def v3(v):
    return [round(float(v[0]), 5), round(float(v[1]), 5), round(float(v[2]), 5)]


def main():
    grupo = arg("--grupo")
    escala = float(arg("--escala", "2.908"))
    base = os.path.join(REPO, "modelos 3d", "gold-bright")
    saida = os.path.abspath(arg("--saida", os.path.join(base, "roblox", grupo)))
    os.makedirs(saida, exist_ok=True)
    blend = os.path.join(base, "_blend", grupo + ".blend")
    bpy.ops.wm.open_mainfile(filepath=blend)
    arm = bpy.data.objects["GB_Rig"]
    malha = bpy.data.objects["GB_Mesh"]
    arm.data.pose_position = "REST"
    dados = json.load(open(os.path.join(base, "_blend", grupo + ".json"), encoding="utf-8")).get("acoes", {})

    vs = [v.co.copy() for v in malha.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    ossos = {}
    for b in arm.data.bones:
        ossos[b.name] = dict(
            pai=b.parent.name if b.parent else None,
            head=v3(b.head_local),
            tail=v3(b.tail_local),
            matrix_local=[[round(x, 6) for x in row] for row in b.matrix_local],
        )

    fps = bpy.context.scene.render.fps
    acoes = {}
    for a in bpy.data.actions:
        fcs = fcurves(a)
        animados = []
        for b in arm.data.bones:
            base_dp = f'pose.bones["{b.name}"].'
            if any(fc.data_path.startswith(base_dp) for fc in fcs):
                animados.append(b.name)
        q0, q1 = int(a.frame_range[0]), int(a.frame_range[1])
        quadros = []
        for f in range(q0, q1 + 1):
            osso = {}
            for nome in animados:
                base_dp = f'pose.bones["{nome}"].'
                loc = [0.0, 0.0, 0.0]
                quat = [1.0, 0.0, 0.0, 0.0]
                for fc in fcs:
                    if fc.data_path == base_dp + "location":
                        loc[fc.array_index] = fc.evaluate(f)
                    elif fc.data_path == base_dp + "rotation_quaternion":
                        quat[fc.array_index] = fc.evaluate(f)
                osso[nome] = dict(loc=[round(x, 6) for x in loc], quat=[round(x, 6) for x in quat])
            quadros.append(osso)
        acoes[a.name] = dict(
            fps=fps,
            quadros=len(quadros),
            ciclica=bool(dados.get(a.name, {}).get("ciclica", False)),
            animados=animados,
            frames=quadros,
        )

    # no máximo 4 influências por vértice (limite do Roblox)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = malha
    malha.select_set(True)
    antes = max(len([g for g in v.groups if g.weight > 1e-4]) for v in malha.data.vertices)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    depois = max(len([g for g in v.groups if g.weight > 1e-4]) for v in malha.data.vertices)

    arm.select_set(True)
    malha.select_set(True)
    bpy.context.view_layer.objects.active = arm
    malha.data.transform(Matrix.Scale(escala, 4))
    malha.data.update()
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.head = eb.head * escala
        eb.tail = eb.tail * escala
    bpy.ops.object.mode_set(mode="OBJECT")
    fbx = os.path.join(saida, grupo + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        bake_anim=False,
        use_armature_deform_only=True,
        path_mode="STRIP",
        mesh_smooth_type="FACE",
    )
    atlas = grupo + "_atlas.png"
    shutil.copyfile(os.path.join(base, "_blend", atlas), os.path.join(saida, atlas))

    tris = sum(len(p.vertices) - 2 for p in malha.data.polygons)
    manifesto = dict(
        arquivo=grupo + ".fbx",
        textura=atlas,
        escala_blender_para_fbx=escala,
        triangulos=tris,
        influencias_antes=antes,
        influencias_depois=depois,
        dimensoes_blend=dict(min=v3(mn), max=v3(mx), tamanho=v3(mx - mn)),
        dimensoes_studs=v3((mx - mn) * escala),
        ossos=ossos,
        acoes={k: dict(fps=v["fps"], quadros=v["quadros"], ciclica=v["ciclica"], animados=len(v["animados"])) for k, v in acoes.items()},
    )
    with open(os.path.join(saida, "manifesto.json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, indent=1, ensure_ascii=False)
    with open(os.path.join(saida, "anim_blender.json"), "w", encoding="utf-8") as f:
        json.dump(acoes, f, separators=(",", ":"))
    print("##EXPORT## " + json.dumps(dict(fbx=fbx, tris=tris, studs=v3((mx - mn) * escala), infl=[antes, depois])))


if __name__ == "__main__":
    main()
