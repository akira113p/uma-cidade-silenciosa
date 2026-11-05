"""Converte FBX ASCII (que o Blender 5.x nao le) em JSON de malhas ja no espaco do Blender.

Saida: lista de {"file", "objects": [{"name", "verts", "faces"}]}, verts em metros, eixo Z para cima.
So le geometria e transformacao de Model (T, PreRotation, R, S). Materiais e UV ficam de fora.
"""
import json
import math
import re
import sys

TOK = re.compile(r'[ \t\r\n]+|;[^\n]*|"(?:[^"\\]|\\.)*"|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?|[{}:,*]|[A-Za-z_][A-Za-z0-9_]*')


def resolve_tex(name):
    return None


def tokenize(text):
    out = []
    pos = 0
    size = len(text)
    while pos < size:
        m = TOK.match(text, pos)
        if not m:
            raise ValueError(f"caractere inesperado {text[pos]!r} na posicao {pos}")
        s = m.group(0)
        pos = m.end()
        c = s[0]
        if c in " \t\r\n;":
            continue
        if c == '"':
            out.append(("S", s[1:-1]))
        elif c in "{}:,*":
            out.append(("P", c))
        elif c.isalpha() or c == "_":
            out.append(("I", s))
        else:
            out.append(("N", float(s)))
    return out


def parse_block(toks, i):
    """Le nos ate um '}' ou o fim. Cada no vira (nome, valores, filhos)."""
    nodes = []
    n = len(toks)
    while i < n:
        kind, val = toks[i]
        if kind == "P" and val == "}":
            break
        if kind != "I":
            raise ValueError(f"esperado nome de no na posicao {i}, achei {toks[i]}")
        name = val
        if toks[i + 1] != ("P", ":"):
            raise ValueError(f"esperado ':' depois de {name} na posicao {i}")
        i += 2
        if i < n and toks[i] == ("P", "*"):
            i += 2  # pula '*' e a contagem do array
        values = []
        while i < n:
            k, v = toks[i]
            if k == "P" and v == ",":
                i += 1
                continue
            if k == "P":
                break  # '{' ou '}'
            if k == "I" and i + 1 < n and toks[i + 1] == ("P", ":"):
                break  # proximo no filho
            values.append(v)
            i += 1
        children = []
        if i < n and toks[i] == ("P", "{"):
            children, i = parse_block(toks, i + 1)
            i += 1  # pula '}'
        nodes.append((name, values, children))
    return nodes, i


def named(nodes, name):
    return [n for n in nodes if n[0] == name]


def first(nodes, name):
    found = named(nodes, name)
    return found[0] if found else None


def props(node):
    """Mapeia Properties70 -> {nome: valores (sem nome/tipo/label/flags)}."""
    out = {}
    p70 = first(node[2], "Properties70")
    if not p70:
        return out
    for p in named(p70[2], "P"):
        vals = p[1]
        out[vals[0]] = vals[4:]
    return out


def mat_mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def ident():
    return [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]


def rot(axis, deg):
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    m = ident()
    if axis == "x":
        m[1][1], m[1][2], m[2][1], m[2][2] = c, -s, s, c
    elif axis == "y":
        m[0][0], m[0][2], m[2][0], m[2][2] = c, s, -s, c
    else:
        m[0][0], m[0][1], m[1][0], m[1][1] = c, -s, s, c
    return m


def euler_xyz(deg):
    # FBX eEulerXYZ: matriz = Rz * Ry * Rx
    return mat_mul(rot("z", deg[2]), mat_mul(rot("y", deg[1]), rot("x", deg[0])))


def trs(t, r, s, pre):
    m = ident()
    m[0][3], m[1][3], m[2][3] = t
    m = mat_mul(m, mat_mul(euler_xyz(pre), mat_mul(euler_xyz(r), mat_scale(s))))
    return m


def mat_scale(s):
    m = ident()
    m[0][0], m[1][1], m[2][2] = s
    return m


def apply(m, p):
    x, y, z = p
    return [
        m[0][0] * x + m[0][1] * y + m[0][2] * z + m[0][3],
        m[1][0] * x + m[1][1] * y + m[1][2] * z + m[1][3],
        m[2][0] * x + m[2][1] * y + m[2][2] * z + m[2][3],
    ]


def convert(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    toks = tokenize(text)
    top, _ = parse_block(toks, 0)

    unit = 1.0
    gs = first(top, "GlobalSettings")
    if gs:
        unit = props(gs).get("UnitScaleFactor", [1.0])[0]
    scale_m = unit * 0.01  # unidade FBX (cm por padrao) -> metros

    objects = first(top, "Objects")[2]
    models = {}
    geoms = {}
    for node in objects:
        if node[0] == "Model":
            models[node[1][0]] = node
        elif node[0] == "Geometry":
            geoms[node[1][0]] = node

    parent_of = {}   # filho -> pai (ids)
    geom_model = {}  # geometria -> modelo
    mat_ids = {n[1][0] for n in objects if n[0] == "Material"}
    tex_file = {}
    for n in objects:
        if n[0] == "Texture" and first(n[2], "FileName"):
            tex_file[n[1][0]] = first(n[2], "FileName")[1][0]
    model_mats = {}  # modelo -> materiais ligados, na ordem do arquivo
    mat_tex = {}     # material -> arquivo da textura difusa
    conns = first(top, "Connections")
    if conns:
        for c in named(conns[2], "C"):
            kind, child, parent = c[1][0], c[1][1], c[1][2]
            if kind == "OP":
                if child in tex_file and parent in mat_ids:
                    mat_tex[parent] = tex_file[child]
                continue
            if kind != "OO":
                continue
            if child in geoms and parent in models:
                geom_model[child] = parent
            elif child in mat_ids and parent in models:
                model_mats.setdefault(parent, []).append(child)
            elif child in models:
                parent_of[child] = parent

    world_cache = {}

    def world(mid):
        if mid in world_cache:
            return world_cache[mid]
        if mid not in models:
            return ident()
        node = models[mid]
        pr = props(node)
        local = trs(
            pr.get("Lcl Translation", [0.0, 0.0, 0.0]),
            pr.get("Lcl Rotation", [0.0, 0.0, 0.0]),
            pr.get("Lcl Scaling", [1.0, 1.0, 1.0]),
            pr.get("PreRotation", [0.0, 0.0, 0.0]),
        )
        parent = parent_of.get(mid)
        result = mat_mul(world(parent), local) if parent is not None and parent in models else local
        world_cache[mid] = result
        return result

    # FBX Y-up -> Blender Z-up: rotacao de +90 em X (y -> z)
    to_blender = mat_mul(rot("x", 90.0), mat_scale([scale_m, scale_m, scale_m]))

    out_objects = []
    for gid, geom in geoms.items():
        mid = geom_model.get(gid)
        if mid is None:
            continue
        vert_node = first(geom[2], "Vertices")
        idx_node = first(geom[2], "PolygonVertexIndex")
        if not vert_node or not idx_node:
            continue
        flat = vert_node[2][0][1]
        raw_idx = [int(v) for v in idx_node[2][0][1]]
        m = mat_mul(to_blender, world(mid))
        verts = []
        for i in range(0, len(flat) - 2, 3):
            verts.append([round(c, 6) for c in apply(m, (flat[i], flat[i + 1], flat[i + 2]))])
        faces = []
        poly = []
        for v in raw_idx:
            if v < 0:
                poly.append(-v - 1)
                faces.append(poly)
                poly = []
            else:
                poly.append(v)
        if poly:
            faces.append(poly)

        # UV por canto (mesma ordem dos cantos em faces)
        corner_uv = []
        uv_node = first(geom[2], "LayerElementUV")
        if uv_node:
            uv_flat = first(uv_node[2], "UV")[2][0][1]
            uv_pairs = [(uv_flat[i], uv_flat[i + 1]) for i in range(0, len(uv_flat) - 1, 2)]
            uv_index = [int(v) for v in first(uv_node[2], "UVIndex")[2][0][1]]
            mode = first(uv_node[2], "MappingInformationType")[1][0]
            for k, v in enumerate(raw_idx):
                vert = -v - 1 if v < 0 else v
                slot = vert if mode == "ByVertice" else k
                u, w = uv_pairs[uv_index[slot]]
                corner_uv.append([round(u, 6), round(w, 6)])

        # textura por face, a partir do material ligado ao modelo
        face_tex = [None] * len(faces)
        mat_node = first(geom[2], "LayerElementMaterial")
        slots = model_mats.get(mid, [])
        if mat_node and slots:
            mmode = first(mat_node[2], "MappingInformationType")[1][0]
            idx_node = first(mat_node[2], "Materials")
            ids = [int(v) for v in idx_node[2][0][1]] if idx_node and idx_node[2] else [0]
            for f in range(len(faces)):
                si = ids[0] if mmode == "AllSame" else (ids[f] if f < len(ids) else 0)
                tex = mat_tex.get(slots[si]) if si < len(slots) else None
                if tex:
                    face_tex[f] = tex.replace("\\", "/").split("/")[-1]

        tex_paths = {}
        for t in set(face_tex):
            if t:
                tex_paths[t] = resolve_tex(t)

        name = models[mid][1][1].replace("Model::", "") or geom[1][1]
        out_objects.append({
            "name": name,
            "verts": verts,
            "faces": faces,
            "uv": corner_uv,
            "face_tex": face_tex,
            "tex_paths": tex_paths,
        })

    return {"file": path, "objects": out_objects}


if __name__ == "__main__":
    out_path = sys.argv[1]
    paths = sys.argv[2:]
    result = []
    errors = []
    for p in paths:
        try:
            result.append(convert(p))
        except Exception as exc:  # registra e segue
            errors.append({"file": p, "erro": str(exc)})
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump({"ok": result, "erros": errors}, fh)
    print(f"convertidos={len(result)} erros={len(errors)}")
    for e in errors:
        print("ERRO", e["file"], e["erro"])
