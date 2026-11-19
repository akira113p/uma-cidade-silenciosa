"""Reimporta roblox/Lanterna.fbx e renderiza conferencias (Workbench): textura e cor por parte; frente, 3/4, lado.
Uso: LANT_OUT=<pasta> blender -b --factory-startup -P ferramentas/lanterna/render_final.py
Tambem imprime as dimensoes que o Blender le do FBX (devem ser os studs do manifesto)."""
import os

import bpy
import mathutils

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA = os.path.join(RAIZ, "modelos 3d", "PsxFlashLights", "roblox")
OUT = os.environ.get("LANT_OUT", os.path.join(SAIDA, "renders"))
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = 600
sc.render.resolution_y = 600
sc.display.shading.light = "FLAT"
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.03, 0.03, 0.03)
sc.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"

bpy.ops.import_scene.fbx(filepath=os.path.join(SAIDA, "Lanterna.fbx"))
objs = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == "MESH"}
for n, o in objs.items():
    print("##DIM##", n, tuple(round(x, 4) for x in o.dimensions), tuple(round(x, 4) for x in o.location))

img = bpy.data.images.load(os.path.join(SAIDA, "Lanterna.png"))
mat = bpy.data.materials.new("tex")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = img
tx.interpolation = "Closest"
bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
sd = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(tx.outputs[0], bs.inputs[0])
nt.links.new(bs.outputs[0], sd.inputs[0])
cores = {"Corpo": (0.5, 0.5, 0.5, 1), "Lente": (1, 1, 0, 1), "Botao": (0, 0.6, 1, 1), "Indicador": (1, 0, 0, 1)}
cmats = {}
for n, c in cores.items():
    m = bpy.data.materials.new("c_" + n)
    m.diffuse_color = c
    cmats[n] = m


def usar(modo):
    for n, o in objs.items():
        o.data.materials.clear()
        o.data.materials.append(tex_mat if modo == "tex" else cmats[n])
    sc.display.shading.color_type = "TEXTURE" if modo == "tex" else "MATERIAL"


tex_mat = mat
# centro/raio de todos
cs = [o.matrix_world @ mathutils.Vector(c) for o in objs.values() for c in o.bound_box]
c0 = sum(cs, mathutils.Vector()) / len(cs)
r = max((v - c0).length for v in cs)

# No quadro do Blender reimportado a lente aponta para +Y (Roblox -Z), cima +Z, botao em -X.
vistas = {
    "frente": (0, 1, 0),
    "tres_quartos": (-0.8, 1, 0.55),
    "lado_botao": (-1, 0, 0),
    "lado_oposto": (1, 0, 0),
    "tras": (0, -1, 0),
    "topo": (0, 0, 1),
}
for modo in ("tex", "cor"):
    usar(modo)
    for nome, d in vistas.items():
        d = mathutils.Vector(d).normalized()
        cam.data.ortho_scale = r * 2.2
        cam.location = c0 + d * 5
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (modo, nome))
        bpy.ops.render.render(write_still=True)
print("##OK##", OUT)
