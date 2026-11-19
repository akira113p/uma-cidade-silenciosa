"""Separa FlashLight_003 (PsxFlashLights) em Corpo / Lente / Botao / Indicador, escala para studs, centra a origem na
face de tras do corpo, exporta UM FBX e grava manifesto_geom.json.

Uso (da raiz):  blender -b --factory-startup -P ferramentas/lanterna/montar_lanterna.py
Pre: python -I ferramentas/lanterna/preparar_textura.py (gera roblox/Lanterna.png, 256 px).

Quadro de origem (Blender importado): lente aponta +X, cima +Z, lado do botao/indicador +Y.
Quadro do FBX/Roblox: lente -Z, cima +Y, botao/indicador em -X (rotacao propria, sem espelhar).
  Blender export (xb,yb,zb) = (-y, x, z)  ->  Roblox (xb, zb, -yb) = (-y, z, -x)
"""
import json
import os

import bmesh
import bpy
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PASTA = os.path.join(RAIZ, "modelos 3d", "PsxFlashLights")
SAIDA = os.path.join(PASTA, "roblox")
ALTURA_STUDS = 0.38

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(PASTA, "FBX", "FlashLight_003.fbx"))
orig = [o for o in bpy.data.objects if o.type == "MESH"][0]
orig.data.transform(orig.matrix_world)
orig.matrix_world.identity()

bm = bmesh.new()
bm.from_mesh(orig.data)
bm.faces.ensure_lookup_table()


def vb(f):
    ps = [v.co for v in f.verts]
    return [(min(p[k] for p in ps), max(p[k] for p in ps)) for k in range(3)]


def parede_plana(f):
    b = vb(f)
    return abs(b[1][0] - 0.0461) < 2e-4 and abs(b[1][1] - 0.0461) < 2e-4 and max(b[0][1] - b[0][0], b[2][1] - b[2][0]) > 0.004


# --- classificacao (quadro de origem) ---
cand = {f for f in bm.faces if vb(f)[1][0] >= 0.0445 and not parede_plana(f)}
ilhas, visto = [], set()
for f in cand:
    if f in visto:
        continue
    pilha, comp = [f], []
    visto.add(f)
    while pilha:
        x = pilha.pop()
        comp.append(x)
        for e in x.edges:
            for y in e.link_faces:
                if y in cand and y not in visto:
                    visto.add(y)
                    pilha.append(y)
    ilhas.append(comp)
ilhas.sort(key=len, reverse=True)
assert len(ilhas[0]) > 100 and 10 < len(ilhas[1]) < 30, [len(i) for i in ilhas]
slider, indicador = ilhas[0], ilhas[1]  # slider (136 faces), indicador vermelho (15)
EPS = 1e-4
Z_PLACA = (-0.0037, 0.014)  # placa cinza; as hastes (tubos) acima/abaixo ficam no corpo como trilho
botao = [f for f in slider if vb(f)[2][0] >= Z_PLACA[0] - EPS and vb(f)[2][1] <= Z_PLACA[1] + EPS]
ids_botao_set = {f.index for f in botao}
trilho = [f for f in slider if f.index not in ids_botao_set]
lente = [f for f in bm.faces if len(f.verts) == 25 and abs(f.normal.x - 1) < 1e-3 and vb(f)[0][0] > 0.03]
assert len(lente) == 1, len(lente)
ids_botao = ids_botao_set
ids_ind = {f.index for f in indicador}
ids_lente = {f.index for f in lente}
print("##CLASSES##", dict(botao=len(botao), trilho=len(trilho), indicador=len(indicador), lente=len(lente), total=len(bm.faces)))
classe = {}
for f in bm.faces:
    classe[f.index] = "Botao" if f.index in ids_botao else "Indicador" if f.index in ids_ind else "Lente" if f.index in ids_lente else "Corpo"

# trilho do botao no quadro de origem (hastes): curso = trilho - placa
z_trilho = (min(vb(f)[2][0] for f in slider), max(vb(f)[2][1] for f in slider))
curso_old = (z_trilho[1] - z_trilho[0]) - (Z_PLACA[1] - Z_PLACA[0])
desloca_botao = z_trilho[0] - Z_PLACA[0]  # leva a placa ao fundo do trilho (= desligado)
print("##TRILHO##", z_trilho, "curso_old", curso_old, "desloca", desloca_botao)

# origem: centro da face de tras do corpo
corpo_faces = [f for f in bm.faces if classe[f.index] == "Corpo"]
xmin = min(v.co.x for f in corpo_faces for v in f.verts)
tras = [v.co for f in corpo_faces for v in f.verts if v.co.x < 0.0]  # caixa (sem o aro da lente, que sai para +X)
yc = (min(p.y for p in tras) + max(p.y for p in tras)) / 2
zc = (min(p.z for p in tras) + max(p.z for p in tras)) / 2
zmin = min(v.co.z for f in corpo_faces for v in f.verts)
zmax = max(v.co.z for f in corpo_faces for v in f.verts)
S = ALTURA_STUDS / (zmax - zmin)
print("##TRAS##", min(p.y for p in tras), max(p.y for p in tras), min(p.z for p in tras), max(p.z for p in tras))
print("##ORIGEM##", dict(x=xmin, y=yc, z=zc, escala=S, altura_corpo_m=zmax - zmin))


def para_export(p):
    """quadro de origem (m) -> quadro Blender de exportacao (studs), origem na face de tras."""
    x, y, z = p.x - xmin, p.y - yc, p.z - zc
    return Vector((-y * S, x * S, z * S))


def roblox(pb):
    return (pb.x, pb.z, -pb.y)


# --- material com a textura de 256 px ---
img = bpy.data.images.load(os.path.join(SAIDA, "Lanterna.png"))
mat = bpy.data.materials.new("Lanterna")
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

# --- cria um objeto por classe ---
objs = {}
for nome in ("Corpo", "Lente", "Botao", "Indicador"):
    b2 = bm.copy()
    b2.faces.ensure_lookup_table()
    apagar = [f for f in b2.faces if classe[f.index] != nome]
    bmesh.ops.delete(b2, geom=apagar, context="FACES")
    soltos = [v for v in b2.verts if not v.link_faces]
    bmesh.ops.delete(b2, geom=soltos, context="VERTS")
    for v in b2.verts:
        co = v.co.copy()
        if nome == "Botao":
            co.z += desloca_botao
        v.co = para_export(co)
    for f in b2.faces:
        f.smooth = False
    me = bpy.data.meshes.new(nome)
    b2.to_mesh(me)
    b2.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    objs[nome] = ob
bm.free()
bpy.data.objects.remove(orig)


# --- medidas (quadro Roblox, studs) ---
def medir(ob):
    ps = [Vector(roblox(v.co)) for v in ob.data.vertices]
    mn = [min(p[k] for p in ps) for k in range(3)]
    mx = [max(p[k] for p in ps) for k in range(3)]
    return dict(
        tamanho=[round(mx[k] - mn[k], 4) for k in range(3)],
        centro=[round((mx[k] + mn[k]) / 2, 4) for k in range(3)],
        minimo=[round(m, 4) for m in mn],
        maximo=[round(m, 4) for m in mx],
        triangulos=sum(len(p.vertices) - 2 for p in ob.data.polygons),
    )


partes = {n: medir(o) for n, o in objs.items()}
lf = objs["Lente"].data
cl = sum((Vector(roblox(v.co)) for v in lf.vertices), Vector()) / len(lf.vertices)
raio = sum((Vector(roblox(v.co)) - cl).length for v in lf.vertices) / len(lf.vertices)
normal = [round(x, 4) for x in roblox(lf.polygons[0].normal)]  # normal no quadro Roblox
print("##LENTE##", [round(x, 4) for x in cl], raio, normal)

curso = curso_old * S
manifesto = dict(
    unidade="studs",
    eixos_roblox="+X direita do arquivo, +Y cima, -Z frente (lente). Botao e indicador ficam em -X (lado direito de quem olha a lente de frente).",
    origem="centro da face de tras do corpo (onde prende no peito)",
    escala_m_para_studs=round(S, 5),
    altura_corpo_studs=partes["Corpo"]["tamanho"][1],
    partes=partes,
    lente=dict(centro=[round(x, 4) for x in cl], normal=normal, raio=round(raio, 4)),
    botao=dict(
        eixo="Y",
        curso=round(curso, 4),
        desligado_deslocamento=[0, 0, 0],
        ligado_deslocamento=[0, round(curso, 4), 0],
        nota="a malha do Botao ja esta exportada na posicao DESLIGADO (fundo do trilho); ligado = subir 'curso' studs em +Y. Trilho = hastes que ficam no Corpo.",
        trilho_studs=round((z_trilho[1] - z_trilho[0]) * S, 4),
        altura_placa_studs=round((Z_PLACA[1] - Z_PLACA[0]) * S, 4),
    ),
)
with open(os.path.join(SAIDA, "manifesto_geom.json"), "w", encoding="utf-8") as fh:
    json.dump(manifesto, fh, indent=2, ensure_ascii=False)

# --- exporta ---
bpy.ops.object.select_all(action="DESELECT")
for o in objs.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = objs["Corpo"]
fbx = os.path.join(SAIDA, "Lanterna.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx,
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
print("##EXPORT##", fbx, os.path.getsize(fbx))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "Lanterna_montada.blend"))
