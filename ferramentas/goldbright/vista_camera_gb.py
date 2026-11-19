"""Renderiza um grupo do Gold Bright visto da câmera original do jogo (confere pose e enquadramento sem o Studio).
Uso (da raiz): blender -b --factory-startup -P ferramentas/goldbright/vista_camera_gb.py -- "<abs>/modelos 3d/gold-bright" <grupo> <fov> [<Acao>]
Saída: _blend/<grupo>_vista_fov<fov>.png (quadro 10 da ação).
"""
import json, os, sys, math
import bpy
from mathutils import Matrix, Vector

base = sys.argv[sys.argv.index("--") + 1]
grupo = sys.argv[sys.argv.index("--") + 2]
fov = float(sys.argv[sys.argv.index("--") + 3])
resto = sys.argv[sys.argv.index("--") + 4 :]
acao = resto[0] if resto else None
quadro = int(resto[1]) if len(resto) > 1 else 10
raiz_na_cam = [float(x) for x in resto[2].split(",")] if len(resto) > 2 else None  # normalPosition + offset da raiz (Unity)
bpy.ops.wm.open_mainfile(filepath=os.path.join(base, "_blend", grupo + ".blend"))
extra = json.load(open(os.path.join(base, grupo, "extra.json")))
cam = extra["camera_na_raiz"]
if raiz_na_cam:
    cam = [[1, 0, 0, -raiz_na_cam[0]], [0, 1, 0, -raiz_na_cam[1]], [0, 0, 1, -raiz_na_cam[2]], [0, 0, 0, 1]]
C3 = Matrix(((-1, 0, 0), (0, 0, -1), (0, 1, 0)))
Ru = Matrix([row[:3] for row in cam[:3]])
pu = Vector([cam[0][3], cam[1][3], cam[2][3]])
pos = C3 @ pu
frente = (C3 @ Ru @ Vector((0, 0, 1))).normalized()
cima = (C3 @ Ru @ Vector((0, 1, 0))).normalized()
direita = frente.cross(cima)
rot = Matrix((direita, cima, -frente)).transposed()  # colunas: X=direita, Y=cima, Z=-frente
cd = bpy.data.cameras.new("c")
cd.sensor_fit = "VERTICAL"
cd.angle_y = math.radians(fov)
cd.clip_start = 0.01
co = bpy.data.objects.new("c", cd)
bpy.context.scene.collection.objects.link(co)
co.matrix_world = Matrix.Translation(pos) @ rot.to_4x4()
cena = bpy.context.scene
cena.camera = co
cena.render.engine = "BLENDER_WORKBENCH"
cena.display.shading.color_type = "TEXTURE"
cena.render.resolution_x = 1600
cena.render.resolution_y = 900
cena.render.resolution_percentage = 50
arm = bpy.data.objects["GB_Rig"]
if acao:
    arm.animation_data.action = bpy.data.actions[acao]
    cena.frame_set(quadro)
cena.render.filepath = os.path.join(base, "_blend", f"{grupo}_vista_fov{int(fov)}_{acao}_{quadro}.png")
bpy.ops.render.render(write_still=True)
print("##OK", cena.render.filepath)
