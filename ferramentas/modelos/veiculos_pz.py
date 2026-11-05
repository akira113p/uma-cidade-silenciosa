"""M1: corta os modelos de veiculos do Project Zomboid em pecas e exporta FBX + manifesto + renders.

Uso (da raiz do projeto):
  blender.exe -b --python ferramentas/modelos/veiculos_pz.py -- --tipos sedan [--so-render]
  blender.exe -b --python ferramentas/modelos/veiculos_pz.py -- --tipos sedan,suv --medir   (grava "escala" em cortes.json)
Antes de processar: python ferramentas/modelos/pintar_texturas.py (4 PNG opacos por tipo). Depois: --queimado, --roda,
montar_manifesto.py, gerar_config.py.
Saida: modelos 3d/veiculos/<tipo>_inteiro.fbx, <tipo>_queimado.fbx, roda.fbx, manifesto_*.json, renders/.
Nao altera nada fora de modelos 3d/veiculos/. Eixos: Blender Y = frente do carro, Z = cima (a exportacao FBX troca
para frente -Z, cima +Y do Roblox). Unidades: metros do Blender, 1 stud = 0,28 m.
"""
import argparse
import json
import os
import sys

import bmesh
import bpy
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PZ = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media"
SAIDA = os.path.join(RAIZ, "modelos 3d", "veiculos")
M_STUD = 0.28
COMP_SEDAN = 11.0  # studs
COMP_SEDAN_JOGO = 2.617
# Regra de escala por tipo (decisao do usuario, 2026-11-03): o personagem tem de caber sentado.
# Medido no jogo: acima do topo do banco o personagem ocupa 3,55 studs (cabeca a 2,70); abaixo do topo, 0,74.
BANCO_TOPO = 0.8  # studs acima do piso (base do carro)
ALTURA_ACIMA_BANCO = 3.55
FOLGA_CABECA = 0.35
OLHO_ACIMA_BANCO = 2.70
TETO_INTERNO_ALVO = BANCO_TOPO + ALTURA_ACIMA_BANCO + FOLGA_CABECA  # 4,70: lado de dentro do teto, acima do piso
BANCO_ATRAS_VOLANTE = 1.8  # studs do centro do volante ao centro do banco do motorista
ESPACO_FILEIRA = 2.6  # studs entre fileiras de bancos
RAIO_RODA_PZ = 0.15  # unidades do jogo (todos os carros do PZ)
FOLGA_RODA_FRACAO = 0.3  # centro da roda acima da base do carro = 0,3 x raio (altura de rodagem do jogo)
NUM_CORES = 4
ASSENTOS = {"sedan": 4, "compacto": 4, "suv": 4, "pickup": 2, "van": 3, "esportivo": 2}  # Config/Veiculos.tipos[t].assentos
sys.path.insert(0, os.path.dirname(__file__))
import fbx_ascii  # noqa: E402

CORES = {
    "Carroceria": (0.55, 0.55, 0.6),
    "Capo": (0.9, 0.2, 0.2),
    "PortaMalas": (0.2, 0.7, 0.2),
    "PortaE": (0.2, 0.3, 0.95),
    "PortaD": (0.95, 0.85, 0.1),
    "ParaChoque": (0.95, 0.5, 0.1),
    "Vidro_ParaBrisa": (0.1, 0.9, 0.9),
    "Vidro_Traseiro": (0.9, 0.1, 0.9),
    "Vidro_JanelaE": (0.1, 0.5, 0.6),
    "Vidro_JanelaD": (0.6, 0.5, 0.1),
    "Volante": (0.1, 0.1, 0.1),
}


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def carregar_fbx(caminho):
    """Lista de dicts {name, verts, faces, uv} (Z cima, metros nominais). Binario: o Blender le; ASCII: fbx_ascii."""
    with open(caminho, "rb") as f:
        cab = f.read(20)
    if cab.startswith(b"Kaydara"):
        limpar()
        bpy.ops.import_scene.fbx(filepath=caminho, axis_forward="Y", axis_up="Z")
        objs = []
        for ob in bpy.context.scene.objects:
            if ob.type != "MESH":
                continue
            me = ob.data
            m = ob.matrix_world
            verts = [list(m @ v.co) for v in me.vertices]
            faces = [list(p.vertices) for p in me.polygons]
            uvl = me.uv_layers.active
            uv = [list(uvl.data[li].uv) for p in me.polygons for li in p.loop_indices] if uvl else []
            objs.append({"name": ob.name, "verts": verts, "faces": faces, "uv": uv})
        return objs
    return fbx_ascii.convert(caminho)["objects"]


def juntar(objs):
    verts, faces, uv = [], [], []
    for o in objs:
        base = len(verts)
        verts += o["verts"]
        faces += [[i + base for i in f] for f in o["faces"]]
        uv += o["uv"]
    return verts, faces, uv


def carregar_pixels(caminho):
    """Pixels crus (0-1, sem conversao de cor) de um PNG."""
    im = bpy.data.images.load(caminho, check_existing=False)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    px = list(im.pixels)
    bpy.data.images.remove(im)
    return px, w, h


def cor_mascara(px, w, h, u, v):
    x = min(w - 1, max(0, int((u % 1.0) * w)))
    y = min(h - 1, max(0, int((v % 1.0) * h)))  # Blender: origem da imagem embaixo, como a UV
    i = (y * w + x) * 4
    return tuple(int(round(px[i + k] * 255)) for k in range(3))


def casa(r, mc, c):
    if "mask" in r and (mc is None or tuple(r["mask"]) != mc):
        return False
    if "lado" in r and ((c[0] < 0) != (r["lado"] == "E")):
        return False
    if "caixa" in r:
        b = r["caixa"]
        if not (b[0] <= c[0] <= b[1] and b[2] <= c[1] <= b[3] and b[4] <= c[2] <= b[5]):
            return False
    return True


def classificar(verts, faces, uv, cfg_pecas, mascara):
    """Nome da peca por face. verts = coordenadas cruas do conversor (x largura, y comprimento, z altura; a caixa de cortes.json usa elas)."""
    px, w, h = mascara if mascara else (None, 0, 0)
    nomes = []
    ci = 0
    for f in faces:
        n = len(f)
        uvs = uv[ci : ci + n]
        ci += n
        c = [sum(verts[i][k] for i in f) / n for k in range(3)]
        mc = None
        if px is not None and uvs:
            mc = cor_mascara(px, w, h, sum(p[0] for p in uvs) / n, sum(p[1] for p in uvs) / n)
        escolhido = "Carroceria"
        for peca, regras in cfg_pecas.items():
            if any(casa(r, mc, c) for r in regras):
                escolhido = peca
                break
        nomes.append(escolhido)
    return nomes


def normalizar(verts, frente, comp_jogo, escala=1.0):
    """Centra, poe a frente em +Y, base em z=0, escala para metros (studs*0.28) vezes `escala` (cortes.json). Espelho em X se a frente era -Y."""
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    cx, cy, zb = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    comp = max(ys) - min(ys)
    s = (COMP_SEDAN / COMP_SEDAN_JOGO) * comp_jogo / comp * M_STUD * escala
    out = []
    for v in verts:
        x, y, z = (v[0] - cx), (v[1] - cy) * frente, v[2] - zb
        if frente < 0:
            x = -x  # giro de 180 graus em Z = (-x, -y); aqui y ja foi trocado, entao x tambem
        out.append([x * s, y * s, z * s])
    return out


def bvh_studs(verts, faces):
    """BVH com a malha em studs (verts em metros do Blender). Para lancar raios para cima e achar o lado de dentro do teto."""
    from mathutils.bvhtree import BVHTree

    vs = [Vector((v[0] / M_STUD, v[1] / M_STUD, v[2] / M_STUD)) for v in verts]
    return BVHTree.FromPolygons(vs, [tuple(f) for f in faces])


def teto_acima(bvh, x, y, z0):
    """Altura (studs) do teto visto de dentro: o ultimo triangulo virado para baixo no raio para cima a partir de (x, y, z0).
    (Antes dele ha banco/painel, virados para cima.) None se nenhum."""
    p = Vector((x, y, z0))
    teto = None
    for _ in range(40):
        loc, nor, _i, _d = bvh.ray_cast(p, Vector((0, 0, 1)))
        if loc is None:
            break
        if nor.z < 0:
            teto = loc.z
        p = loc + Vector((0, 0, 0.001))
    return teto


def centro_peca(verts, faces, nomes, nome):
    """Centro (studs, eixos do Blender) da caixa das faces de uma peca."""
    pts = [verts[i] for f, n in zip(faces, nomes) if n == nome for i in f]
    if not pts:
        return None
    return [(min(p[k] for p in pts) + max(p[k] for p in pts)) / 2 / M_STUD for k in range(3)]


def posicoes_bancos(vol, e, n):
    """Bancos no espaco do carro (Roblox: x direita, z = -frente), studs, escala `e`. vol = centro do volante no Blender a 1x.
    Motorista a esquerda (x < 0), atras do volante; passageiro espelhado; fileiras a cada ESPACO_FILEIRA."""
    xd = vol[0] * e
    yd = vol[1] * e - BANCO_ATRAS_VOLANTE
    lista = []
    for i in range(n):
        fileira, coluna = i // 2, i % 2
        lista.append((xd if coluna == 0 else -xd, -(yd - fileira * ESPACO_FILEIRA)))  # (x, z) Roblox
    return lista


def medir_escala(tipo, cfg):
    """Escala uniforme do tipo: o vao (topo do banco ate o lado de dentro do teto, raio para cima sobre o banco do motorista)
    passa a ser ALTURA_ACIMA_BANCO + FOLGA_CABECA. Itera porque o banco fica a BANCO_ATRAS_VOLANTE studs atras do volante
    (distancia em studs finais). Devolve (escala, detalhes)."""
    objs_src = carregar_fbx(os.path.join(PZ, "models_X", "vehicles", cfg["arquivo"]))
    verts_cru, faces, uv = juntar(objs_src)
    limpar()
    v1 = normalizar(verts_cru, cfg["frente"], cfg["comprimento_jogo"], 1.0)
    mascara = carregar_pixels(os.path.join(SAIDA, "texturas", cfg["mascara"])) if cfg.get("mascara") else None
    nomes = classificar(verts_cru, faces, uv, cfg["pecas"], mascara)
    vol = centro_peca(v1, faces, nomes, "Volante")
    if vol is None:
        raise RuntimeError(tipo + ": sem Volante para posicionar o banco")
    bvh = bvh_studs(v1, faces)
    e = 1.8
    hz = None
    for _ in range(40):
        x = vol[0]
        y = vol[1] - BANCO_ATRAS_VOLANTE / e
        hz = teto_acima(bvh, x, y, (BANCO_TOPO + 0.3) / e)
        if hz is None:
            raise RuntimeError(tipo + ": raio do banco nao achou teto")
        novo = TETO_INTERNO_ALVO / hz
        if abs(novo - e) < 1e-5:
            e = novo
            break
        e = novo
    zmax = max(v[2] for v in v1) / M_STUD
    return e, {"teto_interno_1x": round(hz, 4), "altura_1x": round(zmax, 4), "volante_1x_blender": [round(c, 4) for c in vol]}


def cabine_final(verts, faces, nomes, e, n_assentos):
    """Medidas finais (escala aplicada) para o manifesto: bancos (x, z), teto interno e folga da cabeca de cada banco."""
    vol = centro_peca(verts, faces, nomes, "Volante")
    bvh = bvh_studs(verts, faces)
    bancos = []
    for x, z in posicoes_bancos([c / e for c in vol], e, n_assentos):
        teto = teto_acima(bvh, x, -z, BANCO_TOPO + 0.3)
        folga = None if teto is None else round(teto - BANCO_TOPO - ALTURA_ACIMA_BANCO, 3)
        bancos.append({"x": round(x, 3), "z": round(z, 3), "teto_interno": None if teto is None else round(teto, 3), "folga_cabeca": folga})
    return bancos


def tex_cor(tipo, n):
    return os.path.join(SAIDA, "texturas", f"{tipo}_cor{n}.png")


def imagem_material(nome, caminho_png):
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(caminho_png)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def criar_objeto(nome, verts, faces, uv, idx, mat):
    me = bpy.data.meshes.new(nome)
    vmap, vs, fs, cantos = {}, [], [], []
    ci = 0
    for fi, f in enumerate(faces):
        n = len(f)
        if fi in idx:
            nf = []
            for vi in f:
                if vi not in vmap:
                    vmap[vi] = len(vs)
                    vs.append(verts[vi])
                nf.append(vmap[vi])
            fs.append(nf)
            cantos += uv[ci : ci + n]
        ci += n
    me.from_pydata(vs, [], fs)
    if cantos:
        layer = me.uv_layers.new(name="UVMap")
        k = 0
        for p in me.polygons:
            for li in p.loop_indices:
                layer.data[li].uv = cantos[k]
                k += 1
    me.update()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def bbox(ob):
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return [min(v[k] for v in vs) for k in range(3)], [max(v[k] for v in vs) for k in range(3)]


def para_roblox_studs(mn, mx):
    """Tamanho e centro em studs, eixos do Roblox (x, y cima, z = -frente)."""
    tam = [mx[0] - mn[0], mx[2] - mn[2], mx[1] - mn[1]]
    ce = [(mx[0] + mn[0]) / 2, (mx[2] + mn[2]) / 2, -(mx[1] + mn[1]) / 2]
    return [round(t / M_STUD, 3) for t in tam], [round(c / M_STUD, 3) for c in ce]


def render(objs, nome_base, pasta, sem_teto=False, textura=False, so_vistas=None):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE" if textura else "OBJECT"
    sc.display.shading.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y = 900, 600
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.9, 0.9, 0.92)
    for ob in objs:
        ob.color = (*CORES.get(ob.name.split(".")[0], (0.5, 0.5, 0.5)), 1)
    usar = list(objs)
    ocultos = []
    if sem_teto:
        usar = []
        for ob in objs:
            if ob.name == "Carroceria":
                bm = bmesh.new()
                bm.from_mesh(ob.data)
                zmax = max(v.co.z for v in bm.verts)
                rm = [f for f in bm.faces if f.calc_center_median().z > zmax * 0.7 and f.normal.z > 0.5]
                bmesh.ops.delete(bm, geom=rm, context="FACES")
                me = bpy.data.meshes.new("cut")
                bm.to_mesh(me)
                bm.free()
                nob = bpy.data.objects.new("cutroof", me)
                nob.color = ob.color
                sc.collection.objects.link(nob)
                ob.hide_render = True
                ocultos.append(ob)
                usar.append(nob)
            else:
                usar.append(ob)
    allv = [ob.matrix_world @ Vector(c) for ob in usar for c in ob.bound_box]
    ctr = sum(allv, Vector()) / len(allv)
    size = max(max(v[k] for v in allv) - min(v[k] for v in allv) for k in range(3))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.2
    cam.data.clip_end = 1000
    sc.collection.objects.link(cam)
    sc.camera = cam
    vistas = {
        "frente34": (1.0, 1.1, 0.8),
        "tras34": (-1.0, -1.1, 0.8),
        "lado": (1.0, 0.0, 0.1),
        "topo": (0.0, 0.0001, 1.0),
    }
    if textura:
        vistas = {"tex_frente34": (1.0, 1.1, 0.8), "tex_tras34": (-1.0, -1.1, 0.8), "tex_lado": (1.0, 0.0, 0.1)}
    if sem_teto:
        vistas = {"semteto_topo": (0.0, 0.0001, 1.0), "semteto_34": (-0.9, 0.9, 0.9), "semteto_tras": (0.9, -0.9, 0.9)}
    if so_vistas:
        vistas = {k: v for k, v in vistas.items() if k in so_vistas}
    for nv, d in vistas.items():
        d = Vector(d).normalized()
        cam.location = ctr + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(pasta, f"{nome_base}.png" if so_vistas else f"{nome_base}_{nv}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    for ob in list(bpy.data.objects):
        if ob.name.startswith("cutroof"):
            bpy.data.objects.remove(ob)
    for ob in ocultos:
        ob.hide_render = False


def exportar(objs, caminho):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=caminho,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        path_mode="AUTO",
        embed_textures=False,
        bake_anim=False,
        add_leaf_bones=False,
    )


def render_cores(tipo, objs, mat):
    """Um render do carro texturizado com cada uma das NUM_CORES cores (renders/<tipo>_cor<n>.png)."""
    tex = next((n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
    if tex is None:
        return
    for n in range(1, NUM_CORES + 1):
        if not os.path.exists(tex_cor(tipo, n)):
            continue
        tex.filepath = tex_cor(tipo, n)
        tex.reload()
        render(objs, f"{tipo}_cor{n}", os.path.join(SAIDA, "renders"), textura=True, so_vistas=["tex_frente34"])


def processar(tipo, cfg, manifesto, so_render):
    os.makedirs(os.path.join(SAIDA, "renders"), exist_ok=True)
    esc = cfg.get("escala", 1.0)
    objs_src = carregar_fbx(os.path.join(PZ, "models_X", "vehicles", cfg["arquivo"]))
    verts, faces, uv = juntar(objs_src)
    limpar()
    verts_cru = verts
    verts = normalizar(verts, cfg["frente"], cfg["comprimento_jogo"], esc)
    mascara = carregar_pixels(os.path.join(SAIDA, "texturas", cfg["mascara"])) if cfg.get("mascara") else None
    nomes = classificar(verts_cru, faces, uv, cfg["pecas"], mascara)
    cores_ok = [n for n in range(1, NUM_CORES + 1) if os.path.exists(tex_cor(tipo, n))]
    textura_png = tex_cor(tipo, 1) if cores_ok else os.path.join(SAIDA, "texturas", cfg["textura"])
    mat = imagem_material(tipo + "_mat", textura_png)
    ausentes = dict(cfg.get("ausentes", {}))
    pecas = {}
    for nome in ["Carroceria"] + list(cfg["pecas"].keys()):
        idx = {i for i, n in enumerate(nomes) if n == nome}
        if not idx:
            ausentes.setdefault(nome, "nenhuma face casou com as regras de cortes.json")
            continue
        pecas[nome] = criar_objeto(nome, verts, faces, uv, idx, mat)
    lst = list(pecas.values())
    info = {}
    amn, amx = [1e9] * 3, [-1e9] * 3
    for nome, ob in pecas.items():
        mn, mx = bbox(ob)
        amn = [min(a, b) for a, b in zip(amn, mn)]
        amx = [max(a, b) for a, b in zip(amx, mx)]
        tam, cen = para_roblox_studs(mn, mx)
        info[nome] = {"tamanho": tam, "centro": cen, "triangulos": tris(ob)}
    dim, _ = para_roblox_studs(amn, amx)
    render(lst, tipo + "_inteiro", os.path.join(SAIDA, "renders"))
    render(lst, tipo + "_inteiro", os.path.join(SAIDA, "renders"), sem_teto=True)
    render(lst, tipo + "_inteiro", os.path.join(SAIDA, "renders"), textura=True)
    if cores_ok:
        render_cores(tipo, lst, mat)
    k = COMP_SEDAN / COMP_SEDAN_JOGO * esc  # studs por unidade do jogo (PZ), na escala final
    raio_roda = round(RAIO_RODA_PZ * k, 3)
    folga_roda = round(FOLGA_RODA_FRACAO * raio_roda, 3)
    rodas = {n: [round(gx * k, 3), folga_roda, round(-gz * k, 3)] for n, (gx, gz) in cfg["rodas_jogo"].items()}
    bancos = cabine_final(verts, faces, nomes, esc, ASSENTOS.get(tipo, 4))
    if not so_render:
        exportar(lst, os.path.join(SAIDA, f"{tipo}_inteiro.fbx"))
    arquivo = {
        "arquivo": f"{tipo}_inteiro.fbx",
        "tipo": tipo,
        "estado": "inteiro",
        "triangulos": sum(p["triangulos"] for p in info.values()),
        "pecas": info,
        "ausentes": ausentes,
        "mascara": cfg.get("mascara"),
    }
    if cores_ok:
        arquivo["texturas"] = [f"{tipo}_cor{n}.png" for n in cores_ok]
    else:
        arquivo["textura"] = cfg["textura"]
    manifesto["arquivos"].append(arquivo)
    d = bancos[0]
    manifesto["tipos"][tipo] = {
        "escala": round(esc, 4),
        "dimensoes": dim,
        "raio_roda": raio_roda,
        "folga_roda": folga_roda,
        "rodas": rodas,
        "banco_topo": BANCO_TOPO,
        "olho": [d["x"], round(BANCO_TOPO + OLHO_ACIMA_BANCO, 3), d["z"]],
        "teto_interno": d["teto_interno"],
        "bancos": bancos,
        "frente_blender": "+Y" if cfg["frente"] > 0 else "-Y",
    }
    return pecas


def processar_queimado(tipo, cfg, manifesto, so_render):
    objs_src = carregar_fbx(os.path.join(PZ, "models_X", "vehicles", cfg["queimado"]))
    verts, faces, uv = juntar(objs_src)
    limpar()
    verts = normalizar(verts, cfg.get("frente_queimado", cfg["frente"]), cfg["comprimento_jogo_queimado"], cfg.get("escala", 1.0))
    mat = imagem_material(tipo + "_queimado_mat", os.path.join(SAIDA, "texturas", cfg["textura_queimado"]))
    ob = criar_objeto("Carroceria", verts, faces, uv, set(range(len(faces))), mat)
    mn, mx = bbox(ob)
    tam, cen = para_roblox_studs(mn, mx)
    render([ob], tipo + "_queimado", os.path.join(SAIDA, "renders"))
    render([ob], tipo + "_queimado", os.path.join(SAIDA, "renders"), textura=True)
    if not so_render:
        exportar([ob], os.path.join(SAIDA, f"{tipo}_queimado.fbx"))
    manifesto["arquivos"].append(
        {
            "arquivo": f"{tipo}_queimado.fbx",
            "tipo": tipo,
            "estado": "queimado",
            "textura": cfg["textura_queimado"],
            "triangulos": tris(ob),
            "pecas": {"Carroceria": {"tamanho": tam, "centro": cen, "triangulos": tris(ob)}},
            "ausentes": {"_tudo": "queimado: um objeto Carroceria, sem corte (contrato)"},
        }
    )


def processar_roda(manifesto, so_render):
    """Roda a partir do dump ASCII Vehicles_Wheel.txt (cilindro de 12 lados, eixo em X), raio 1 stud."""
    linhas = open(os.path.join(PZ, "models", "Vehicles_Wheel.txt"), encoding="utf-8").read().splitlines()
    i = linhas.index("# Vertex Buffer:")
    n = int(linhas[linhas.index("# Vertex Count:") + 1])
    verts, uvs = [], []
    for k in range(n):
        a = [float(x) for x in linhas[i + 1 + k * 3].split(",")]
        b = [float(x) for x in linhas[i + 2 + k * 3].split(",")]
        c = [float(x) for x in linhas[i + 3 + k * 3].split(",")]
        verts.append((a, b))
        uvs.append(c)
    j = linhas.index("# Face Data:")
    nf = int(linhas[linhas.index("# Number of Faces:") + 1])
    faces = [[int(x) for x in linhas[j + 1 + k].split(",")] for k in range(nf)]
    raio = max(v[0][1] for v in verts)
    s = 1.0 / raio * M_STUD  # raio 1 stud
    limpar()
    vs = [[p[0] * s, p[1] * s, p[2] * s] for p, _ in verts]
    # a face do dump pode estar com a ordem invertida: confere com a normal do vertice e desvira se precisar
    fs = []
    virados = 0
    for f in faces:
        a, b, c = (Vector(vs[x]) for x in f)
        nn = (b - a).cross(c - a)
        nm = sum((Vector(verts[x][1]) for x in f), Vector())
        if nn.dot(nm) < 0:
            f = [f[0], f[2], f[1]]
            virados += 1
        fs.append(f)
    me = bpy.data.meshes.new("roda")
    me.from_pydata(vs, [], fs)
    layer = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for li in p.loop_indices:
            layer.data[li].uv = uvs[me.loops[li].vertex_index]
    me.update()
    ob = bpy.data.objects.new("roda", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(imagem_material("roda_mat", os.path.join(SAIDA, "texturas", "vehicle_wheel.png")))
    mn, mx = bbox(ob)
    tam, cen = para_roblox_studs(mn, mx)
    render([ob], "roda", os.path.join(SAIDA, "renders"), textura=True)
    if not so_render:
        exportar([ob], os.path.join(SAIDA, "roda.fbx"))
    manifesto["arquivos"].append(
        {"arquivo": "roda.fbx", "tipo": "roda", "textura": "vehicle_wheel.png", "triangulos": tris(ob), "pecas": {"roda": {"tamanho": tam, "centro": cen, "triangulos": tris(ob)}}, "faces_viradas": virados}
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tipos", default="sedan")
    ap.add_argument("--so-render", action="store_true")
    ap.add_argument("--queimado", action="store_true")
    ap.add_argument("--roda", action="store_true")
    ap.add_argument("--medir", action="store_true", help="calcula a escala por tipo e grava em cortes.json")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    cortes = json.load(open(os.path.join(os.path.dirname(__file__), "cortes.json"), encoding="utf-8"))
    manifesto = {"tipos": {}, "arquivos": []}
    if a.medir:
        caminho = os.path.join(os.path.dirname(__file__), "cortes.json")
        for tipo in a.tipos.split(","):
            e, det = medir_escala(tipo, cortes[tipo])
            cortes[tipo]["escala"] = round(e, 4)
            cortes[tipo]["medida"] = det
            print("MEDIDO", tipo, "escala", round(e, 4), det)
        json.dump(cortes, open(caminho, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
        print("OK cortes.json")
        return
    if a.roda:
        processar_roda(manifesto, a.so_render)
    else:
        for tipo in a.tipos.split(","):
            if a.queimado:
                processar_queimado(tipo, cortes[tipo], manifesto, a.so_render)
            else:
                processar(tipo, cortes[tipo], manifesto, a.so_render)
    out = os.path.join(SAIDA, "manifesto_" + ("roda" if a.roda else a.tipos.replace(",", "_") + ("_q" if a.queimado else "")) + ".json")
    json.dump(manifesto, open(out, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print("OK", out)


if __name__ == "__main__":
    main()
