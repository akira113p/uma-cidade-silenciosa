"""
exportar_roblox.py - roda DENTRO do Blender. Valida e exporta meshes para o Roblox.

  python .claude/skills/blender-lpm-skill/scripts/bl.py --script .claude/skills/modelo-3d-roblox/scripts/exportar_roblox.py \
      -- --input assets/modelos/Bau/Bau.blend --out assets/roblox/Bau

Entrada: .blend, .glb/.gltf, .fbx ou .obj. Saída: <out>.fbx + <out>.roblox.json (manifesto).
Imprime "##JSON##{...}" com o resultado. Sai com código 1 se algum portão falhar.

Portões (doc oficial create.roblox.com/docs/art/modeling/specifications):
  - no máximo 20.000 triângulos por mesh (cada objeto vira uma MeshPart)
  - textura no máximo 1024 px de lado
  - malha sem buracos (arestas não-manifold viram AVISO, não falha: props low-poly abertos por baixo são comuns)
Objetos terminados em _COL são ignorados: no Roblox a colisão é CollisionFidelity da MeshPart.
"""
import argparse
import json
import os
import sys

import bmesh
import bpy

LIMITE_TRIS = 20000
LIMITE_TEXTURA = 1024
METROS_POR_STUD = 0.28  # create.roblox.com/docs/physics/units: "1 stud = 28 cm"


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", help="arquivo a abrir/importar (omitir se o .blend já foi aberto com bl.py --blend)")
    p.add_argument("--out", required=True, help="caminho de saída sem extensão")
    p.add_argument("--limite", type=int, default=LIMITE_TRIS, help="orçamento de triângulos por mesh")
    p.add_argument("--colecao", help="exportar só os objetos desta coleção (ex.: LOW depois do reduzir.py + bake)")
    return p.parse_args(argv)


def carregar(caminho):
    ext = os.path.splitext(caminho)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=caminho)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=caminho)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=caminho)
    else:
        sys.exit(f"formato não suportado: {ext}")


def medir(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    nao_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    ngons = sum(1 for f in bm.faces if len(f.verts) > 4)
    bm.free()
    return tris, nao_manifold, ngons


def texturas(ob):
    grandes = []
    for slot in ob.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and max(n.image.size) > LIMITE_TEXTURA:
                grandes.append(f"{n.image.name} {tuple(n.image.size)}")
    return grandes


def main():
    a = args()
    if a.input:
        carregar(os.path.abspath(a.input))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.endswith("_COL")]
    if a.colecao:
        meshes = [o for o in meshes if a.colecao in {c.name for c in o.users_collection}]
    if not meshes:
        sys.exit("nenhuma mesh na cena")

    relatorio, falhas, avisos = [], [], []
    for ob in meshes:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        tris, nao_manifold, ngons = medir(ob)
        d = ob.dimensions  # Blender: Z para cima. Roblox: Y para cima.
        tamanho_studs = [round(d.x / METROS_POR_STUD, 3), round(d.z / METROS_POR_STUD, 3), round(d.y / METROS_POR_STUD, 3)]
        item = {"nome": ob.name, "tris": tris, "dims_m": [round(v, 4) for v in d], "size_studs_xyz": tamanho_studs}
        if tris > a.limite:
            falhas.append(f"{ob.name}: {tris} tris > {a.limite}")
        if nao_manifold:
            avisos.append(f"{ob.name}: {nao_manifold} arestas não-manifold (buracos)")
        if ngons:
            avisos.append(f"{ob.name}: {ngons} n-gons (o FBX triangula; prefira quads)")
        for t in texturas(ob):
            falhas.append(f"{ob.name}: textura {t} > {LIMITE_TEXTURA}px")
        relatorio.append(item)

    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    resultado = {"ok": not falhas, "falhas": falhas, "avisos": avisos, "meshes": relatorio,
                 "metros_por_stud": METROS_POR_STUD, "fbx": None, "manifesto": out + ".roblox.json"}
    if not falhas:
        bpy.ops.object.select_all(action="DESELECT")
        for ob in meshes:
            ob.select_set(True)
        # Export conforme create.roblox.com/docs/art/modeling/export-requirements:
        # Path Mode = Copy, Embed Textures, Apply Scalings = FBX Unit Scale.
        bpy.ops.export_scene.fbx(
            filepath=out + ".fbx", use_selection=True, object_types={"MESH"},
            apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
            mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True,
            bake_anim=False, add_leaf_bones=False,
        )
        resultado["fbx"] = out + ".fbx"
    with open(out + ".roblox.json", "w", encoding="utf-8") as f:
        json.dump(resultado, f, ensure_ascii=False, indent=2)
    print("##JSON##" + json.dumps(resultado, ensure_ascii=False))
    if falhas:
        sys.exit(1)


main()
