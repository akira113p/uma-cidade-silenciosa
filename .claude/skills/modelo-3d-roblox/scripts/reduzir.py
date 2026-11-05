"""
reduzir.py - roda DENTRO do Blender. Prepara um modelo denso (gerado por IA, escaneado, esculpido)
para o bake: original vai para a coleção HIGH, uma cópia decimada vai para LOW, com UV nova.

  python .claude/skills/blender-lpm-skill/scripts/bl.py --script .claude/skills/modelo-3d-roblox/scripts/reduzir.py \
      -- --input bruto/estatua.glb --alvo 6000 --save assets/modelos/Estatua/Estatua_master.blend

Depois, devolver o detalhe como textura (normal + cor) com o bake da skill blender-image-to-3d:
  ... bl.py --script .claude/skills/blender-image-to-3d/scripts/bake_maps.py -- --blend <master> \
      --low LOW --high HIGH --res 1024 --maps normal,ao,basecolor --out <pasta>/tex --rebuild-material --save <baked.blend>
e exportar com exportar_roblox.py (só a coleção LOW vai para o FBX: apague/oculte HIGH antes, ver SKILL.md).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy


def soldar(ob):
    # glTF/FBX de geradores chegam com os vértices de cada face separados. Sem soldar, o Decimate
    # trabalha em "ilhas" de 1 face e deixa centenas de milhares de arestas soltas.
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()


def limpar_soltos(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_edges], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--alvo", type=int, default=6000, help="triângulos por objeto LOW (Roblox aceita até 20000)")
    p.add_argument("--save", required=True)
    return p.parse_args(argv)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def colecao(nome):
    c = bpy.data.collections.get(nome) or bpy.data.collections.new(nome)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def mover(ob, destino):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    destino.objects.link(ob)


def main():
    a = args()
    caminho = os.path.abspath(a.input)
    ext = os.path.splitext(caminho)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=caminho)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        {".glb": bpy.ops.import_scene.gltf, ".gltf": bpy.ops.import_scene.gltf,
         ".fbx": bpy.ops.import_scene.fbx}.get(ext, lambda filepath: bpy.ops.wm.obj_import(filepath=filepath))(filepath=caminho)

    high, low = colecao("HIGH"), colecao("LOW")
    fontes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name not in low.objects]
    relatorio = []
    for ob in fontes:
        mover(ob, high)
        copia = ob.copy()
        copia.data = ob.data.copy()
        copia.name = ob.name.removesuffix("_HIGH") + "_LOW"
        ob.name = ob.name.removesuffix("_HIGH") + "_HIGH"
        low.objects.link(copia)
        soldar(copia)
        antes = tris(copia)
        if antes > a.alvo:
            mod = copia.modifiers.new("Decimate", "DECIMATE")
            mod.decimate_type = "COLLAPSE"
            mod.ratio = a.alvo / antes
            bpy.context.view_layer.objects.active = copia
            bpy.ops.object.select_all(action="DESELECT")
            copia.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        limpar_soltos(copia)
        # UV nova: a UV do modelo denso não sobrevive à decimação.
        bpy.ops.object.select_all(action="DESELECT")
        copia.select_set(True)
        bpy.context.view_layer.objects.active = copia
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        relatorio.append({"high": ob.name, "low": copia.name, "tris_high": tris(ob), "tris_low": tris(copia)})

    destino = os.path.abspath(a.save)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=destino)
    print("##JSON##" + json.dumps({"save": destino, "objetos": relatorio}, ensure_ascii=False))


main()
