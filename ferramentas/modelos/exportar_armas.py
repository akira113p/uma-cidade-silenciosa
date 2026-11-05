"""Exporta as 11 armas de modelos 3d/_ps2/<Pasta>/<Pasta>.blend para FBX + atlas PNG + manifesto + renders (docs/armas.md §8).

Uso (da raiz):
  blender.exe -b --factory-startup -P ferramentas/modelos/exportar_armas.py -- [--arma id,id] [--fator 1.0] [--saida "modelos 3d/armas_roblox"]

Nunca altera os .blend de entrada (abre, le e fecha sem salvar). Dados por arma: ferramentas/modelos/armas_modelos.json.
Saida por arma, em <saida>/<id>/: <id>.fbx, <id>.png (atlas unico, ate 512 px), e em <saida>/: manifesto.json, renders/<id>_lado.png e <id>_3q.png
(com marcadores nos pontos de ancoragem: magenta = punho/origem, vermelho = Boca, amarelo = Ejecao, verde = ApoioEsquerdo, ciano = Mira).

Orientacao: o modelo sai em studs, origem na empunhadura, cano para -Z, cima +Y (Roblox). A importacao do Roblox e 1 unidade = 1 stud
(medido nos monstros e nos carros) e troca os eixos assim: x' = -x, y' = z, z' = y (Blender -> Roblox). Por isso a malha e escrita
no Blender como B = (-a, c, b) para o ponto Roblox (a, b, c); `--fator` compensa qualquer escala medida no envio de teste.
Atlas: cada material vira uma celula (imagem reduzida ou cor chapada) numa textura so, com os UV refeitos; se algum UV passar do
quadrado 0..1 alem da tolerancia, o manifesto registra `atlas.uv_fora` (o atlas continua, o usuario decide).
"""

import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
ENTRADAS = os.path.join(REPO, "modelos 3d", "_ps2")
DADOS = os.path.join(REPO, "ferramentas", "modelos", "armas_modelos.json")
ATLAS_MAX = 512
GUTTER = 2  # px replicados em volta de cada celula (evita sangrar cor vizinha nos mipmaps)
EIXOS = {"+X": (1, 0, 0), "-X": (-1, 0, 0), "+Y": (0, 1, 0), "-Y": (0, -1, 0), "+Z": (0, 0, 1), "-Z": (0, 0, -1)}


def arg(nome, padrao):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return padrao


def arredonda(v, n=4):
    return [round(float(x), n) for x in v]


# ------------------------------------------------------------------------------------------------- leitura das malhas
def casa(nome, padroes):
    return any(re.search(p, nome) for p in padroes)


def malhas_da_arma(cfg):
    """Devolve {parte: [(objeto, vertices_mundo, triangulos, uv, material_por_tri, materiais)]}, ja so com os objetos pedidos."""
    sel = [o for o in bpy.data.objects if o.type == "MESH"]
    if cfg.get("incluir"):
        sel = [o for o in sel if casa(o.name, cfg["incluir"])]
    if cfg.get("excluir"):
        sel = [o for o in sel if not casa(o.name, cfg["excluir"])]
    partes_cfg = cfg.get("partes") or {"Corpo": [".*"]}
    dg = bpy.context.evaluated_depsgraph_get()
    saida = {}
    usados = set()
    for parte, padroes in partes_cfg.items():
        lista = []
        for o in sel:
            if o.name in usados or not casa(o.name, padroes):
                continue
            usados.add(o.name)
            eo = o.evaluated_get(dg)
            me = bpy.data.meshes.new_from_object(eo)
            me.calc_loop_triangles()
            m = np.array(o.matrix_world, dtype=np.float64)
            n = len(me.vertices)
            co = np.empty(n * 3, dtype=np.float64)
            me.vertices.foreach_get("co", co)
            co = co.reshape(n, 3)
            vmundo = co @ m[:3, :3].T + m[:3, 3]
            nt = len(me.loop_triangles)
            tv = np.empty(nt * 3, dtype=np.int64)
            tl = np.empty(nt * 3, dtype=np.int64)
            tm = np.empty(nt, dtype=np.int64)
            me.loop_triangles.foreach_get("vertices", tv)
            me.loop_triangles.foreach_get("loops", tl)
            me.loop_triangles.foreach_get("material_index", tm)
            if me.uv_layers.active is None:
                raise RuntimeError("sem UV: " + o.name)
            nl = len(me.uv_layers.active.data)
            uvs = np.empty(nl * 2, dtype=np.float64)
            me.uv_layers.active.data.foreach_get("uv", uvs)
            uvs = uvs.reshape(nl, 2)
            tri_uv = uvs[tl].reshape(nt, 3, 2)
            tri_v = tv.reshape(nt, 3)
            if np.linalg.det(m[:3, :3]) < 0:  # espelhado: inverte o enrolamento
                tri_v = tri_v[:, ::-1]
                tri_uv = tri_uv[:, ::-1]
            mats = [mt for mt in me.materials]
            lista.append(dict(nome=o.name, v=vmundo, tri=tri_v, uv=tri_uv, mat=tm, mats=mats))
        if lista:
            saida[parte] = lista
    if not saida:
        raise RuntimeError("nenhum objeto selecionado")
    return saida


# ------------------------------------------------------------------------------------------------------------ orientacao
def vetor_eixo(txt):
    return Vector(EIXOS[txt])


def pca_cabo(todos):
    """Machado (cabo diagonal): eixo principal = cabo; a ponta com mais espalhamento lateral e a cabeca; gume = maior desvio lateral."""
    c = todos.mean(axis=0)
    q = todos - c
    w, vec = np.linalg.eigh(q.T @ q)
    a = vec[:, np.argmax(w)]
    p = q @ a
    n = len(p)
    ordem = np.argsort(p)
    k = max(8, n // 5)
    baixo, alto = ordem[:k], ordem[-k:]

    def lateral(idx):
        r = q[idx] - np.outer(p[idx], a)
        return np.linalg.norm(r, axis=1)

    if lateral(alto).mean() < lateral(baixo).mean():
        a = -a
        p = -p
        alto = baixo
    r = q[alto] - np.outer(p[alto], a)
    i = int(np.argmax(np.linalg.norm(r, axis=1)))
    e = r[i] / np.linalg.norm(r[i])
    return Vector(a), Vector(e)


def quadro(cfg, todos):
    """Devolve (f, u, r): frente, cima, direita no espaco do .blend (mundo)."""
    fr, ar = cfg["frente"], cfg["arriba"]
    if fr == "cabeca":
        f, e = pca_cabo(todos)
        f = f.normalized()
        u = -(e - f * e.dot(f))
        u.normalize()
    else:
        f = vetor_eixo(fr)
        u = vetor_eixo(ar)
        u = u - f * u.dot(f)
        u.normalize()
    r = f.cross(u)
    return f, u, r


def para_roblox(v, f, u, r):
    """Mundo do .blend -> (a, b, c) do Roblox: a = direita, b = cima, c = -frente. v: (N,3) numpy."""
    fa = np.array(f)
    ua = np.array(u)
    ra = np.array(r)
    return np.stack([v @ ra, v @ ua, -(v @ fa)], axis=1)


# ---------------------------------------------------------------------------------------------------------------- atlas
def imagem_do_material(mt, pasta):
    """(imagem bpy | None, cor rgba) do material."""
    cor = (0.5, 0.5, 0.5, 1.0)
    if mt is None:
        return None, cor
    if mt.use_nodes and mt.node_tree:
        for nd in mt.node_tree.nodes:
            if nd.type == "BSDF_PRINCIPLED":
                bc = nd.inputs["Base Color"].default_value
                cor = (bc[0], bc[1], bc[2], 1.0)
        for nd in mt.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image is not None:
                return nd.image, cor
    else:
        cor = tuple(mt.diffuse_color[:3]) + (1.0,)
    return None, cor


def pixels_da_imagem(img, pasta):
    """Array (h, w, 4) float, linha 0 = base. Tenta o arquivo da pasta se a imagem nao carregou."""
    if img.size[0] == 0 or img.size[1] == 0:
        base = re.sub(r"\.\d{3}$", "", os.path.basename(img.filepath or img.name))
        for cand in (base, base.replace(" ", "_")):
            p = os.path.join(pasta, cand)
            if os.path.exists(p):
                img = bpy.data.images.load(p)
                break
    if img.size[0] == 0:
        return None
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    return arr.reshape(h, w, 4)


def reduz(arr, w, h):
    """Reduz/amplia (h, w, 4) para (h2, w2) por media de blocos ou vizinho mais proximo (PS1: nitidez vale mais que suavidade)."""
    h0, w0 = arr.shape[:2]
    if (w, h) == (w0, h0):
        return arr
    ys = (np.arange(h) * h0 / h + h0 / (2 * h)).astype(int).clip(0, h0 - 1)
    xs = (np.arange(w) * w0 / w + w0 / (2 * w)).astype(int).clip(0, w0 - 1)
    if w0 >= w and h0 >= h:  # media por blocos quando reduz
        fy, fx = h0 // h, w0 // w
        if fy >= 1 and fx >= 1 and h0 % h == 0 and w0 % w == 0:
            return arr.reshape(h, fy, w, fx, 4).mean(axis=(1, 3))
    return arr[ys][:, xs]


def empacotar(tamanhos, largura):
    """Prateleiras: tamanhos [(w, h)] (ja com gutter) -> ([(x, y)], altura). Mais altos primeiro."""
    ordem = sorted(range(len(tamanhos)), key=lambda i: -tamanhos[i][1])
    pos = [None] * len(tamanhos)
    x = y = alt = 0
    for i in ordem:
        w, h = tamanhos[i]
        if x + w > largura:
            x, y, alt = 0, y + alt, 0
        pos[i] = (x, y)
        x += w
        alt = max(alt, h)
    return pos, y + alt


def montar_atlas(partes, pasta, id_arma, saida_png):
    """Refaz os UV de todas as partes para um atlas unico. Devolve dict de info. Poe p['uv_novo'] em cada malha."""
    chaves = []  # um por material distinto (imagem ou cor)

    def chave(mt):
        img, cor = imagem_do_material(mt, pasta)
        k = ("img", img.name) if img is not None else ("cor", tuple(round(c, 3) for c in cor[:3]))
        if k not in [c[0] for c in chaves]:
            chaves.append((k, img, cor))
        return [c[0] for c in chaves].index(k)

    for lista in partes.values():
        for p in lista:
            p["cel"] = np.array([chave(p["mats"][i] if i < len(p["mats"]) else None) for i in range(max(1, len(p["mats"])))])
    n = len(chaves)
    pix = []
    chapada = []
    for k, img, cor in chaves:
        arr = pixels_da_imagem(img, pasta) if img is not None else None
        if arr is None:
            arr = np.tile(np.array(cor, dtype=np.float32), (4, 4, 1))
        plana = arr.shape[0] <= 4 or float(arr[..., :3].std(axis=(0, 1)).max()) < 0.02  # imagem de uma cor so vira celula minima
        if plana:
            arr = np.tile(arr[..., :3].mean(axis=(0, 1)).tolist() + [1.0], (4, 4, 1)).astype(np.float32)
        pix.append(arr)
        chapada.append(plana)
    gut = GUTTER if n > 1 else 0  # sem vizinhas, sem gutter: a textura unica sai como veio
    # escala das imagens: a maior (1, 1/2, 1/4...) que cabe em ATLAS_MAX x ATLAS_MAX
    divisor = 1
    while True:
        tam = []
        for arr, plana in zip(pix, chapada):
            h0, w0 = arr.shape[:2]
            w, h = (4, 4) if plana else (max(4, w0 // divisor), max(4, h0 // divisor))
            tam.append((w, h))
        pos, alt = empacotar([(w + 2 * gut, h + 2 * gut) for w, h in tam], ATLAS_MAX)
        if alt <= ATLAS_MAX or divisor >= 8:
            break
        divisor *= 2
    larg = max(x + w + 2 * gut for (x, y), (w, h) in zip(pos, tam))
    w_at, h_at = int(larg), int(alt)
    atlas = np.zeros((h_at, w_at, 4), dtype=np.float32)
    atlas[..., 3] = 1
    celulas = []
    for arr, (w, h), (x, y) in zip(pix, tam, pos):
        cel = reduz(arr, w, h) if (w, h) != arr.shape[1::-1] else arr
        cel = np.pad(cel, ((gut, gut), (gut, gut), (0, 0)), mode="edge")
        atlas[y : y + h + 2 * gut, x : x + w + 2 * gut] = cel
        celulas.append((x + gut, y + gut, w, h))
    atlas[..., 3] = 1.0
    uv_fora = 0
    for lista in partes.values():
        for p in lista:
            uv = p["uv"]
            cel_idx = p["cel"][np.clip(p["mat"], 0, len(p["cel"]) - 1)]
            novo = np.empty_like(uv)
            for t in range(len(uv)):
                cx, cy, cw, ch = celulas[cel_idx[t]]
                tri = uv[t]
                if chapada[cel_idx[t]]:
                    tri = np.full_like(tri, 0.5)  # cor chapada: centro da celula
                else:
                    tri = tri - np.floor(tri.min(axis=0) + 1e-4)
                    if tri.max() > 1.02 or tri.min() < -0.02:
                        uv_fora += 1
                    tri = tri.clip(0, 1)
                novo[t] = np.stack([(cx + tri[:, 0] * cw) / w_at, (cy + tri[:, 1] * ch) / h_at], axis=1)
            p["uv_novo"] = novo
    img = bpy.data.images.new("atlas_" + id_arma, w_at, h_at, alpha=False)
    img.pixels.foreach_set(atlas.reshape(-1))
    img.filepath_raw = saida_png
    img.file_format = "PNG"
    img.save()
    return dict(
        largura=w_at,
        altura=h_at,
        materiais=n,
        divisor_resolucao=divisor,
        celulas=[dict(chave=str(c[0]), px=list(map(int, cel)), cor_chapada=bool(pl)) for c, cel, pl in zip(chaves, celulas, chapada)],
        uv_fora=int(uv_fora),
        imagem=img,
    )


# ------------------------------------------------------------------------------------------------------- geometria final
def ponto(frac, bb, lado_padrao=0.5):
    (amin, bmin, cmin), (amax, bmax, cmax) = bb
    s = frac.get("s", lado_padrao)
    return np.array([amin + s * (amax - amin), bmin + frac["h"] * (bmax - bmin), cmax - frac["t"] * (cmax - cmin)])


def construir(cfg, id_arma, saida_dir, fator, studs_m):
    pasta = os.path.join(ENTRADAS, cfg["pasta"])
    bpy.ops.wm.open_mainfile(filepath=os.path.join(pasta, cfg["pasta"] + ".blend"))
    partes = malhas_da_arma(cfg)
    # montagem extra (ex.: foguete dentro do tubo): deslocamento em metros do .blend, antes da orientacao
    for nome, d in (cfg.get("montar") or {}).items():
        for p in partes.get(nome, []):
            p["v"] = p["v"] + np.array([d.get("dx", 0.0), d.get("dy", 0.0), d.get("dz", 0.0)])
    todos = np.concatenate([p["v"] for l in partes.values() for p in l])
    f, u, r = quadro(cfg, todos)
    rob = para_roblox(todos, f, u, r)
    comp_m = float(rob[:, 2].max() - rob[:, 2].min())  # extensao na direcao do cano (metros do .blend)
    escala = cfg["comprimento_m"] * studs_m / comp_m * fator
    bb = (rob.min(axis=0) * escala, rob.max(axis=0) * escala)
    punho = ponto(cfg["punho"], bb)
    comp_studs = float(bb[1][2] - bb[0][2])
    # pontos de ancoragem (studs, origem = punho)
    ancoras = {}
    if cfg.get("boca") == "auto":
        c = rob[:, 2] * escala
        m = c < c.min() + 0.04 * comp_studs
        ancoras["Boca"] = (rob[m].mean(axis=0) * escala) - punho
    elif cfg.get("boca"):
        ancoras["Boca"] = ponto(cfg["boca"], bb) - punho
    for chave_json, nome in (("ejecao", "Ejecao"), ("apoio", "ApoioEsquerdo"), ("mira", "Mira")):
        if cfg.get(chave_json):
            ancoras[nome] = ponto(cfg[chave_json], bb) - punho
    # atlas
    os.makedirs(saida_dir, exist_ok=True)
    png = os.path.join(saida_dir, id_arma + ".png")
    atlas = montar_atlas(partes, pasta, id_arma, png)
    # limpa a cena e cria os objetos finais
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    mat = bpy.data.materials.new("M_" + id_arma)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = atlas["imagem"]
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    info_partes = []
    tris_total = 0
    objs = []
    for nome, lista in partes.items():
        vs, fs, uvs = [], [], []
        base = 0
        for p in lista:
            rb = (para_roblox(p["v"], f, u, r) * escala) - punho  # (a, b, c) em studs, origem no punho
            B = np.stack([-rb[:, 0], rb[:, 2], rb[:, 1]], axis=1)  # ponto do Blender que o Roblox vira (a, b, c)
            vs.append(B)
            fs.append(p["tri"] + base)
            uvs.append(p["uv_novo"])
            base += len(B)
        V = np.concatenate(vs)
        F = np.concatenate(fs)
        UV = np.concatenate(uvs)
        me = bpy.data.meshes.new(nome)
        me.from_pydata(V.tolist(), [], F.tolist())
        me.update()
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", UV.reshape(-1))  # loops = 3 por triangulo, na ordem de F
        me.materials.append(mat)
        ob = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
        a = V.min(axis=0), V.max(axis=0)
        rbmin = np.array([-a[1][0], a[0][2], a[0][1]])  # volta de B para (a, b, c): a = -x, b = z, c = y
        rbmax = np.array([-a[0][0], a[1][2], a[1][1]])
        centro = (rbmin + rbmax) / 2
        info_partes.append(
            dict(
                nome=nome,
                triangulos=len(F),
                centro=arredonda(centro),
                tamanho=arredonda(rbmax - rbmin),
                minimo=arredonda(rbmin),
                maximo=arredonda(rbmax),
            )
        )
        tris_total += len(F)
    # exporta
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    fbx = os.path.join(saida_dir, id_arma + ".fbx")
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
    tam_total = (np.array(bb[1]) - np.array(bb[0])).tolist()
    # a caixa total no referencial do punho
    cx = [(np.array(p["minimo"])) for p in info_partes]
    cy = [(np.array(p["maximo"])) for p in info_partes]
    caixa_min = np.min(cx, axis=0)
    caixa_max = np.max(cy, axis=0)
    man = dict(
        arquivo=id_arma + "/" + id_arma + ".fbx",
        textura=id_arma + "/" + id_arma + ".png",
        pasta_origem=cfg["pasta"],
        objetos_usados=[p["nome"] for l in partes.values() for p in l],
        triangulos=tris_total,
        comprimento_m=cfg["comprimento_m"],
        comprimento_studs=round(comp_studs, 4),
        escala_blend_para_studs=round(float(escala), 5),
        fator_importacao_assumido=fator,
        dimensoes_studs=arredonda(caixa_max - caixa_min),
        caixa_minimo=arredonda(caixa_min),
        caixa_maximo=arredonda(caixa_max),
        partes=info_partes,
        ancoras={k: arredonda(v) for k, v in ancoras.items()},
        atlas={k: v for k, v in atlas.items() if k != "imagem"},
        frente_blend=arredonda(f),
        cima_blend=arredonda(u),
    )
    return man, objs, ancoras, atlas


# -------------------------------------------------------------------------------------------------------------- renders
def esfera(nome, pos_B, raio, cor):
    me = bpy.data.meshes.new(nome)
    import bmesh

    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=raio)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    ob.location = pos_B
    mt = bpy.data.materials.new(nome)
    mt.diffuse_color = cor
    me.materials.append(mt)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def renderizar(id_arma, man, ancoras, saida_renders):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE"
    sc.display.shading.show_object_outline = False
    sc.render.resolution_x = 900
    sc.render.resolution_y = 600
    w = bpy.data.worlds.new("w")
    w.use_nodes = False
    w.color = (0.42, 0.44, 0.5)
    sc.world = w
    raio = man["comprimento_studs"] / 70
    cores = dict(Boca=(1, 0, 0, 1), Ejecao=(1, 0.9, 0, 1), ApoioEsquerdo=(0, 1, 0, 1), Mira=(0, 1, 1, 1))
    esfera("punho", (0, 0, 0), raio * 1.3, (1, 0, 1, 1))
    for nome, v in ancoras.items():
        a, b, c = v
        esfera(nome, (-a, c, b), raio, cores[nome])
    cmin, cmax = np.array(man["caixa_minimo"]), np.array(man["caixa_maximo"])
    centro_rb = (cmin + cmax) / 2
    centro_B = Vector((-centro_rb[0], centro_rb[2], centro_rb[1]))
    L = man["comprimento_studs"]
    cam = bpy.data.cameras.new("c")
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    os.makedirs(saida_renders, exist_ok=True)
    # lado direito do Roblox (+X) olhando para -X; a frente (-Z) fica a direita da imagem. No Blender: camera em -X olhando +X.
    cam.type = "ORTHO"
    cam.ortho_scale = max(L, float(cmax[1] - cmin[1]) * 1.5) * 1.15
    co.location = centro_B + Vector((-30, 0, 0))
    co.rotation_euler = (math.radians(90), 0, math.radians(-90))
    sc.render.filepath = os.path.join(saida_renders, id_arma + "_lado.png")
    bpy.ops.render.render(write_still=True)
    # tres quartos: de cima, da direita e da frente
    cam.type = "PERSP"
    cam.lens = 50
    d = Vector((-0.9, -1.0, 0.8)).normalized() * (L * 2.0)
    co.location = centro_B + d
    direcao = centro_B - co.location
    co.rotation_euler = direcao.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(saida_renders, id_arma + "_3q.png")
    bpy.ops.render.render(write_still=True)


def main():
    dados = json.load(open(DADOS, encoding="utf-8"))
    saida = os.path.abspath(arg("--saida", os.path.join(REPO, "modelos 3d", "armas_roblox")))
    fator = float(arg("--fator", "1.0"))
    so = arg("--arma", "")
    excluidas = dados.get("excluidas") or {}
    quais = [a for a in so.split(",") if a] or [a for a in dados["armas"].keys() if a not in excluidas]
    mpath = os.path.join(saida, "manifesto.json")
    manifesto = json.load(open(mpath, encoding="utf-8")) if os.path.exists(mpath) else {"armas": {}}
    for id_arma in quais:
        cfg = dados["armas"][id_arma]
        man, objs, ancoras, atlas = construir(cfg, id_arma, os.path.join(saida, id_arma), fator, dados["studs_por_metro"])
        renderizar(id_arma, man, ancoras, os.path.join(saida, "renders"))
        manifesto["armas"][id_arma] = man
        print("##EXPORT## " + json.dumps(dict(arma=id_arma, tris=man["triangulos"], comp=man["comprimento_studs"], dim=man["dimensoes_studs"], uv_fora=man["atlas"]["uv_fora"], atlas=[man["atlas"]["largura"], man["atlas"]["altura"]])))
    manifesto["studs_por_metro"] = dados["studs_por_metro"]
    os.makedirs(saida, exist_ok=True)
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(manifesto, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
