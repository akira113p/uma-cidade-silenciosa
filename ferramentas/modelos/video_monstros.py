# Vídeo de conferência de um monstro com todos os clipes (vista 3/4, Workbench, chão) + folha de quadros por clipe.
# Uso (da raiz):
#   blender -b --factory-startup <arquivo.blend> -P ferramentas/modelos/video_monstros.py -- --rig <Rig> --prefixo <Nome_> \
#       --nome <Nome> [--malha <obj>] [--folhas Clipe1,Clipe2]
# Saídas: modelos 3d/_ps2/videos/<Nome>_v3.mp4 e modelos 3d/_ps2/videos/folhas/<Nome>_<Clipe>.png (8 quadros, 4x2).
# Quadros temporários na pasta de rascunho do sistema (apagados no fim). Precisa de ffmpeg no PATH e Pillow no python do sistema.

import math
import os
import shutil
import subprocess
import sys
import tempfile

import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VIDEOS = os.path.join(REPO, "modelos 3d", "_ps2", "videos")
ORDEM = ["Idle", "Walk", "Run", "Attack", "Death"]


def arg(n, padrao=None):
    a = sys.argv[sys.argv.index("--") + 1:]
    return a[a.index(n) + 1] if n in a else padrao


def usar_acao(arm, act):
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and getattr(act, "slots", None) and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]


def main():
    nome, prefixo, rig = arg("--nome"), arg("--prefixo"), arg("--rig")
    folhas = [x for x in (arg("--folhas", "") or "").split(",") if x]
    cena = bpy.context.scene
    arm = bpy.data.objects[rig]
    if arm.animation_data is None:
        arm.animation_data_create()
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    arm.data.pose_position = "POSE"
    malha = bpy.data.objects[arg("--malha")] if arg("--malha") else max(
        (o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm), key=lambda o: len(o.data.vertices))
    for o in bpy.data.objects:
        if o.type in ("MESH", "LIGHT", "CAMERA", "FONT") and o not in (malha,):
            o.hide_render = True
    acoes = [a for a in bpy.data.actions if a.name.startswith(prefixo)]
    nomes = sorted((a.name[len(prefixo):] for a in acoes), key=lambda n: (ORDEM.index(n) if n in ORDEM else 99, n))
    # tamanho do monstro para enquadrar
    vs = [malha.matrix_world @ v.co for v in malha.data.vertices]
    alt = max(v.z for v in vs) - min(v.z for v in vs)
    larg = max(max(v.y for v in vs) - min(v.y for v in vs), max(v.x for v in vs) - min(v.x for v in vs), alt)
    cam = bpy.data.cameras.new("camv3")
    cam.lens = 35
    cob = bpy.data.objects.new("camv3", cam)
    cena.collection.objects.link(cob)
    cena.camera = cob
    dist = larg * 1.5 + 0.6
    alvo = Vector((0, 0, alt * 0.45))
    cob.location = alvo + Vector((dist * math.sin(math.radians(40)), -dist * math.cos(math.radians(40)), dist * 0.35))
    cob.rotation_euler = (alvo - cob.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=larg * 8, location=(0, 0, 0))
    chao = bpy.context.object
    mc = bpy.data.materials.new("chao")
    mc.diffuse_color = (0.16, 0.17, 0.18, 1)
    chao.data.materials.append(mc)
    # riscas no chão a cada 0,5 m (referência para ver o pé)
    mr = bpy.data.materials.new("risca")
    mr.diffuse_color = (0.45, 0.45, 0.4, 1)
    for i in range(-8, 9):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, i * 0.5 * larg / 2, 0.001))
        o = bpy.context.object
        o.scale = (larg * 3, 0.012 * larg, 0.001)
        o.data.materials.append(mr)
    txt = bpy.data.curves.new("rotulo", "FONT")
    tob = bpy.data.objects.new("rotulo", txt)
    cena.collection.objects.link(tob)
    txt.size = larg * 0.18
    tob.location = alvo + Vector((-larg * 0.9, larg * 0.6, alt * 0.75))
    tob.rotation_euler = cob.rotation_euler
    tob.data.materials.append(mr)
    cena.render.engine = "BLENDER_WORKBENCH"
    cena.display.shading.light = "STUDIO"
    cena.display.shading.color_type = "TEXTURE"
    cena.display.shading.show_shadows = False
    cena.render.resolution_x, cena.render.resolution_y = 640, 480
    cena.render.image_settings.file_format = "PNG"
    cena.world = bpy.data.worlds.new("w")
    cena.world.color = (0.5, 0.52, 0.56)
    tmp = tempfile.mkdtemp(prefix="vid_" + nome + "_")
    os.makedirs(os.path.join(VIDEOS, "folhas"), exist_ok=True)
    k = 0
    por_clipe = {}
    for n in nomes:
        act = bpy.data.actions[prefixo + n]
        usar_acao(arm, act)
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        ciclica = n in ("Idle", "Walk", "Run", "Arrancada", "Emboscada", "Atordoado")
        txt.body = n
        voltas = (2 if (f1 - f0) > 20 else 4) if ciclica else 1
        por_clipe[n] = []
        for v in range(voltas):
            for f in range(f0, f1 + (0 if ciclica else 1)):
                cena.frame_set(f)
                cena.render.filepath = os.path.join(tmp, f"q{k:05d}.png")
                bpy.ops.render.render(write_still=True)
                if v == 0:
                    por_clipe[n].append(cena.render.filepath)
                k += 1
        if not ciclica:  # segura o último quadro meio segundo
            for _ in range(int(cena.render.fps * 0.5)):
                shutil.copyfile(por_clipe[n][-1], os.path.join(tmp, f"q{k:05d}.png"))
                k += 1
    fps = cena.render.fps
    saida = os.path.join(VIDEOS, f"{nome}_v3.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(tmp, "q%05d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", saida], check=True)
    for n in folhas or nomes:
        q = por_clipe.get(n)
        if not q:
            continue
        idx = [round(i * (len(q) - 1) / 7) for i in range(8)]
        lista = os.path.join(tmp, f"lista_{n}.txt")
        with open(lista, "w") as fp:
            fp.write("\n".join(q[i] for i in idx))
        subprocess.run([sys.executable if False else "python", "-I", "-c",
                        "import sys;from PIL import Image\n"
                        "fs=open(sys.argv[1]).read().split('\\n');ims=[Image.open(f).resize((320,240)) for f in fs]\n"
                        "o=Image.new('RGB',(1280,480))\n"
                        "[o.paste(im,((i%4)*320,(i//4)*240)) for i,im in enumerate(ims)]\n"
                        "o.save(sys.argv[2])", lista, os.path.join(VIDEOS, "folhas", f"{nome}_{n}.png")], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print("##VIDEO## " + saida + " " + ",".join(nomes))


main()
