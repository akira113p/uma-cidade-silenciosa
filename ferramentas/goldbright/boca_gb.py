"""Acha a boca do cano de cada .blend do Gold Bright (ponta da malha que não é braço/mão) e grava _blend/<grupo>_boca.json
(espaço do Blender, sem escala). Corpo a corpo: a ponta da arma também serve (rastro/acerto). Uso (da raiz):
  blender -b --factory-startup -P ferramentas/goldbright/boca_gb.py
"""

import glob
import json
import os
import re

import bpy

BASE = os.path.join(os.path.dirname(__file__), "..", "..", "modelos 3d", "gold-bright", "_blend")
BRACO = re.compile(r"Arm|Hand|Index|Middle|Ring|Pinkie|Thumb|Watch|Health|Camera|Raiz|Root|Arms_Rig", re.I)

for blend in sorted(glob.glob(os.path.join(BASE, "*.blend"))):
    bpy.ops.wm.open_mainfile(filepath=blend)
    me = bpy.data.objects["GB_Mesh"]
    nomes = {g.index: g.name for g in me.vertex_groups}
    pts = []
    for v in me.data.vertices:
        if not v.groups:
            continue
        g = max(v.groups, key=lambda x: x.weight)
        if not BRACO.search(nomes[g.group]):
            pts.append(v.co.copy())
    if not pts:
        pts = [v.co.copy() for v in me.data.vertices]
    ymin = min(p.y for p in pts)  # frente = -Y
    ponta = [p for p in pts if p.y < ymin + 0.01]
    c = [sum(p[i] for p in ponta) / len(ponta) for i in range(3)]
    saida = blend[:-6] + "_boca.json"
    json.dump({"boca_blend": c, "vertices_ponta": len(ponta)}, open(saida, "w"))
    print("##BOCA##", os.path.basename(blend), [round(x, 3) for x in c], len(ponta))
