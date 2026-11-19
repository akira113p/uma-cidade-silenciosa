"""Extrai do Gold Bright os rigs de braços+arma em 1ª pessoa, malhas com pesos, texturas e clipes de animação.

Licença do jogo (LICENSE.txt na pasta dele): GPLv3+ para código E assets, extração permitida. Uso privado não tem obrigação;
DISTRIBUIR (publicar no Roblox) obriga o resultado a ser GPLv3+ com fonte. Ver docs/gold-bright-import.md.

Uso (da raiz do projeto, SEMPRE com -I, e fora da pasta de dados do jogo):
    python -I ferramentas/goldbright/extrair_gb.py "modelos 3d/gold-bright" [--so GRUPO]

Saída por grupo (pasta `<saida>/<pasta>__<raiz>/`):
    rig.json     nós (ossos) com TRS local em espaço Unity (esquerdo, Y para cima, metros)
    meshes.json  malhas (vértices, normais, uv0, triângulos, ossos+pesos, bindposes, textura)
    clips.json   clipes amostrados a 30 fps por osso (pos/rot/escala locais, espaço Unity)
    tex/*.png    texturas
"""

import json
import math
import os
import struct
import sys
import zlib

import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler

DADOS = r"E:\jogos\gold bright\gold bright_Data"
FPS = 30.0

saida = sys.argv[1]
so = None
if "--so" in sys.argv:
    so = sys.argv[sys.argv.index("--so") + 1]
os.makedirs(saida, exist_ok=True)

env = UnityPy.load(os.path.join(DADOS, "resources.assets"))
objs = {o.path_id: o for o in env.objects}
_cache = {}


def rd(pid):
    if pid not in _cache:
        _cache[pid] = objs[pid].read()
    return _cache[pid]


# ---------------------------------------------------------------- hierarquia
def comps_de(go):
    d = {}
    for c in go.m_Component:
        p = c.component.m_PathID
        if p in objs:
            d.setdefault(objs[p].type.name, []).append(p)
    return d


def filhos(tr):
    return [c.m_PathID for c in tr.m_Children if c.m_PathID in objs]


def construir_nos(raiz_tr_pid):
    nos = []
    idx = {}

    def visita(tr_pid, pai_i, caminho):
        tr = rd(tr_pid)
        go = tr.m_GameObject.read()
        nome = go.m_Name
        cam = nome if pai_i is None else caminho + "/" + nome
        i = len(nos)
        idx[tr_pid] = i
        q, p, s = tr.m_LocalRotation, tr.m_LocalPosition, tr.m_LocalScale
        nos.append(
            {
                "nome": nome,
                "pai": pai_i,
                "caminho": cam,
                "pos": [p.x, p.y, p.z],
                "rot": [q.x, q.y, q.z, q.w],
                "esc": [s.x, s.y, s.z],
                "ativo": bool(go.m_IsActive),
                "comps": {k: v for k, v in comps_de(go).items()},
                "tr_pid": tr_pid,
            }
        )
        for f in filhos(tr):
            visita(f, i, cam)

    visita(raiz_tr_pid, None, "")
    return nos, idx


# ---------------------------------------------------------------- texturas
def textura_de_material(mat_ptr, dir_tex):
    try:
        mat = mat_ptr.read()
    except Exception:
        return None
    nome_mat = mat.m_Name
    escolhida = None
    try:
        envs = {t[0]: t[1] for t in mat.m_SavedProperties.m_TexEnvs}
    except Exception:
        envs = {}
    for chave in ("_BaseMap", "_MainTex", "_BaseColorMap", "_Albedo"):
        if chave in envs and envs[chave].m_Texture.m_PathID != 0:
            escolhida = envs[chave].m_Texture
            break
    cor = None
    try:
        cores = {c[0]: c[1] for c in mat.m_SavedProperties.m_Colors}
        for chave in ("_BaseColor", "_Color"):
            if chave in cores:
                c = cores[chave]
                cor = [c.r, c.g, c.b, c.a]
                break
    except Exception:
        pass
    arq = None
    if escolhida is not None:
        try:
            tex = escolhida.read()
            arq = f"tex/{tex.m_Name}.png"
            caminho = os.path.join(dir_tex, f"{tex.m_Name}.png")
            if not os.path.exists(caminho):
                tex.image.save(caminho)
        except Exception as e:
            arq = None
            print("  textura falhou:", nome_mat, repr(e)[:100])
    return {"material": nome_mat, "textura": arq, "cor": cor}


# ---------------------------------------------------------------- malhas
def extrair_malha(mesh_ptr):
    m = mesh_ptr.read()
    h = MeshHandler(m)
    h.process()
    subs = h.get_triangles()
    tris = []
    for s in subs:
        tris.append([list(t) for t in s if len(t) == 3])
    return {
        "nome": m.m_Name,
        "v": [[round(a, 7) for a in v[:3]] for v in h.m_Vertices],
        "n": [[round(a, 5) for a in v[:3]] for v in h.m_Normals] if h.m_Normals else None,
        "uv": [[round(a, 5) for a in v[:2]] for v in h.m_UV0] if h.m_UV0 else None,
        "tris": tris,
        "bi": [list(b) for b in h.m_BoneIndices] if h.m_BoneIndices else None,
        "bw": [[round(a, 5) for a in w] for w in h.m_BoneWeights] if h.m_BoneWeights else None,
        "bind": [
            [getattr(b, f"e{r}{c}") for r in range(4) for c in range(4)] for b in (m.m_BindPose or [])
        ],
    }


# ---------------------------------------------------------------- clipes
def crc(s):
    return zlib.crc32(s.encode("utf-8")) & 0xFFFFFFFF


def decodificar_streamed(dados_u32):
    b = struct.pack("<%dI" % len(dados_u32), *dados_u32)
    pos = 0
    quadros = []
    while pos < len(b):
        t, n = struct.unpack_from("<fi", b, pos)
        pos += 8
        chaves = []
        for _ in range(n):
            (idx,) = struct.unpack_from("<i", b, pos)
            c = struct.unpack_from("<4f", b, pos + 4)
            pos += 20
            chaves.append((idx, c))
        quadros.append((t, chaves))
    return quadros


def avaliar_streamed(quadros, ncurvas, t):
    """valor de cada curva do trecho streamed no tempo t."""
    ultimo = {}
    for tq, chaves in quadros:
        if tq > t:
            break
        base = tq if math.isfinite(tq) else 0.0
        for idx, c in chaves:
            ultimo[idx] = (base, c)
    out = [0.0] * ncurvas
    for idx, (t0, c) in ultimo.items():
        if idx < ncurvas:
            dt = t - t0
            out[idx] = ((c[0] * dt + c[1]) * dt + c[2]) * dt + c[3]
    return out


def dim_binding(bd):
    if bd.typeID == 4:
        return {1: 3, 2: 4, 3: 3, 4: 3}.get(bd.attribute, 1)
    return 1


def decodificar_clip(clip):
    mc = clip.m_MuscleClip
    cl = mc.m_Clip.data
    bind = clip.m_ClipBindingConstant.genericBindings
    s_clip, d_clip, c_clip = cl.m_StreamedClip, cl.m_DenseClip, cl.m_ConstantClip
    n_stream = s_clip.curveCount
    n_dense = d_clip.m_CurveCount
    quadros = decodificar_streamed(list(s_clip.data)) if s_clip.data else []
    dur = float(mc.m_StopTime)
    n_frames = max(2, int(round(dur * FPS)) + 1)
    tempos = [min(dur, i / FPS) for i in range(n_frames)]
    stream_vals = [avaliar_streamed(quadros, n_stream, t) for t in tempos] if n_stream else None
    const = list(c_clip.data) if c_clip.data else []
    dense = list(d_clip.m_SampleArray) if d_clip.m_SampleArray else []
    d_rate = float(d_clip.m_SampleRate) if d_clip.m_SampleRate else FPS
    d_begin = float(d_clip.m_BeginTime)

    def valor(ci, fi):
        if ci < n_stream:
            return stream_vals[fi][ci]
        ci -= n_stream
        if ci < n_dense:
            f = (tempos[fi] - d_begin) * d_rate
            f0 = max(0, min(d_clip.m_FrameCount - 1, int(math.floor(f))))
            f1 = min(d_clip.m_FrameCount - 1, f0 + 1)
            a = f - f0
            return dense[f0 * n_dense + ci] * (1 - a) + dense[f1 * n_dense + ci] * a
        ci -= n_dense
        return const[ci]

    saida_c = {}
    ci = 0
    for bd in bind:
        d = dim_binding(bd)
        if bd.typeID == 4 and bd.attribute in (1, 2, 3, 4):
            chave = {1: "pos", 2: "rot", 3: "esc", 4: "euler"}[bd.attribute]  # Unity: 1 pos, 2 quaternion, 3 escala, 4 euler
            seq = []
            for fi in range(n_frames):
                seq.append([valor(ci + k, fi) for k in range(d)])
            saida_c.setdefault(bd.path, {})[chave] = seq
        ci += d
    return {"fps": FPS, "dur": dur, "n": n_frames, "loop": bool(mc.m_LoopTime), "tempos": tempos, "trilhas": saida_c}



# ---------------------------------------------------------------- câmera e boca (para posicionar o viewmodel)
def _mat(pos, q, esc):
    import numpy as np

    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    r = np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )
    m = np.eye(4)
    m[:3, :3] = r * np.array(esc)[None, :]
    m[:3, 3] = pos
    return m


def _fov(cam):
    for a in ("m_FieldOfView", "field_of_view", "m_FocalLength"):
        if hasattr(cam, a):
            return float(getattr(cam, a))
    return None


def extra_camera(raiz_tr, nos):
    """Main Camera no referencial da raiz do grupo (4x4 Unity), FOV das câmeras e a boca do cano (nó *Muzzle*) na raiz."""
    import numpy as np

    cadeia = np.eye(4)  # raiz -> câmera
    tr = rd(raiz_tr)
    cam_go = None
    while True:
        go = tr.m_GameObject.read()
        if go.m_Name == "Main Camera":
            cam_go = go
            break
        p, q, s = tr.m_LocalPosition, tr.m_LocalRotation, tr.m_LocalScale
        cadeia = _mat([p.x, p.y, p.z], [q.x, q.y, q.z, q.w], [s.x, s.y, s.z]) @ cadeia
        pai = tr.m_Father
        if pai is None or pai.m_PathID == 0:
            break
        tr = rd(pai.m_PathID)
    fovs = {}
    if cam_go is not None:
        for nome_tipo, pids in comps_de(cam_go).items():
            if nome_tipo == "Camera":
                fovs["Main Camera"] = _fov(rd(pids[0]))
        for f in filhos(rd(cam_go.m_Transform.m_PathID)):
            g2 = rd(f).m_GameObject.read()
            if "Camera" in comps_de(g2):
                fovs[g2.m_Name] = _fov(rd(comps_de(g2)["Camera"][0]))
    camera_na_raiz = np.linalg.inv(cadeia) if cam_go is not None else None
    # mundo de repouso de cada nó (raiz = identidade) para achar a boca
    W = []
    for i, n in enumerate(nos):
        L = np.eye(4) if i == 0 else _mat(n["pos"], n["rot"], n["esc"])
        W.append(L if n["pai"] is None else W[n["pai"]] @ L)
    boca = None
    for i, n in enumerate(nos):
        if "muzzle" in n["nome"].lower() and "brake" not in n["nome"].lower():
            boca = [float(x) for x in W[i][:3, 3]]
            break
    return {
        "camera_na_raiz": None if camera_na_raiz is None else [[float(x) for x in l] for l in camera_na_raiz],
        "fovs": fovs,
        "boca_na_raiz": boca,
        "encontrou_camera": cam_go is not None,
    }

# ---------------------------------------------------------------- achar grupos
print("achando grupos (SkinnedMeshRenderer de braços)...", flush=True)
grupos = {}
for o in env.objects:
    if o.type.name != "SkinnedMeshRenderer":
        continue
    d = o.read()
    try:
        go = d.m_GameObject.read()
    except Exception:
        continue
    if not go.m_Name.startswith("Arms_Mesh"):
        continue
    # caminho do GO até a raiz
    partes = []
    tr = rd(go.m_Transform.m_PathID)
    while True:
        g = tr.m_GameObject.read()
        partes.append((g.m_Name, tr.object_reader.path_id))
        pai = tr.m_Father
        if pai is None or pai.m_PathID == 0:
            break
        tr = rd(pai.m_PathID)
    partes.reverse()
    nomes = [p[0] for p in partes]
    if "Equipment" in nomes:
        i = nomes.index("Equipment")
        pasta = nomes[i + 1]
        if "Recoil Position" not in nomes[i:]:
            continue
        raiz_i = nomes.index("Recoil Position", i) + 1
    elif "FP Animations" in nomes:
        i = nomes.index("FP Animations")
        pasta = "FP"
        raiz_i = i + 1
    else:
        continue
    raiz = nomes[raiz_i]
    chave = f"{pasta}__{raiz}".replace(" ", "_")
    if raiz_i >= len(partes) - 1:
        continue
    g = grupos.setdefault(chave, {"raiz_tr": partes[raiz_i][1], "n": 0, "pasta": pasta, "raiz": raiz})
    g["n"] += 1
print(len(grupos), "grupos:", ", ".join(sorted(grupos)), flush=True)

# ---------------------------------------------------------------- clipes (decodifica todos uma vez)
print("decodificando clipes...", flush=True)
clipes = {}
for o in env.objects:
    if o.type.name != "AnimationClip":
        continue
    c = o.read()
    try:
        if c.m_Legacy:
            continue
        clipes[o.path_id] = (c.m_Name, c)
    except Exception:
        pass

resumo = {}
for chave, g in sorted(grupos.items()):
    if so and so not in chave:
        continue
    pasta = os.path.join(saida, chave)
    os.makedirs(os.path.join(pasta, "tex"), exist_ok=True)
    nos, idx = construir_nos(g["raiz_tr"])
    json.dump(extra_camera(g["raiz_tr"], nos), open(os.path.join(pasta, "extra.json"), "w", encoding="utf-8"), indent=1)
    # malhas
    malhas = []
    for i, n in enumerate(nos):
        cs = n["comps"]
        mesh_ptr = None
        mats = []
        smr = None
        if "SkinnedMeshRenderer" in cs:
            smr = rd(cs["SkinnedMeshRenderer"][0])
            mesh_ptr = smr.m_Mesh
            mats = list(smr.m_Materials)
        elif "MeshFilter" in cs and "MeshRenderer" in cs:
            mesh_ptr = rd(cs["MeshFilter"][0]).m_Mesh
            mats = list(rd(cs["MeshRenderer"][0]).m_Materials)
        if mesh_ptr is None or mesh_ptr.m_PathID == 0:
            continue
        if n["nome"].startswith("9x18mm_") and not n["nome"].endswith("_01"):
            continue  # 30 balas do pente do PP-91: manter só uma
        try:
            ma = extrair_malha(mesh_ptr)
        except Exception as e:
            print("  malha falhou", n["nome"], repr(e)[:120])
            continue
        ma["no"] = i
        ma["ativo"] = n["ativo"]
        ma["materiais"] = [textura_de_material(m, os.path.join(pasta, "tex")) for m in mats]
        if smr is not None:
            ossos = []
            for b in smr.m_Bones:
                ossos.append(idx.get(b.m_PathID, -1) if b.m_PathID else -1)
            ma["ossos"] = ossos
            ma["raiz_osso"] = idx.get(smr.m_RootBone.m_PathID, -1) if smr.m_RootBone.m_PathID else -1
        malhas.append(ma)
    # clipes: só os das controllers dos Animators do grupo (override resolve o clipe real de cada estado)
    animadores = []
    pids_clipe = {}
    for i, n in enumerate(nos):
        for apid in n["comps"].get("Animator", []):
            an = rd(apid)
            ptr = an.m_Controller
            if ptr is None or ptr.m_PathID == 0 or ptr.m_PathID not in objs:
                continue
            ctrl = ptr.read()
            info = {"no": i, "controlador": ctrl.m_Name, "tipo": objs[ptr.m_PathID].type.name, "estados": {}}
            if info["tipo"] == "AnimatorOverrideController":
                base = ctrl.m_Controller.read()
                info["base"] = base.m_Name
                over = {}
                for par in ctrl.m_Clips:
                    o = par.m_OriginalClip
                    v = par.m_OverrideClip
                    if o.m_PathID in objs:
                        over[o.m_PathID] = v.m_PathID if v.m_PathID in objs else None
                for cp in base.m_AnimationClips:
                    if cp.m_PathID not in objs:
                        continue
                    real = over.get(cp.m_PathID, cp.m_PathID) or cp.m_PathID
                    info["estados"][rd(cp.m_PathID).m_Name] = rd(real).m_Name
                    pids_clipe[real] = i
            else:
                for cp in ctrl.m_AnimationClips:
                    if cp.m_PathID in objs:
                        info["estados"][rd(cp.m_PathID).m_Name] = rd(cp.m_PathID).m_Name
                        pids_clipe[cp.m_PathID] = i
            animadores.append(info)
    bases = sorted({a["no"] for a in animadores} | {0})
    mapas = {}
    for bi in bases:
        pref = nos[bi]["caminho"]
        mp = {0: bi}
        for j, nj in enumerate(nos):
            if j != bi and nj["caminho"].startswith(pref + "/"):
                mp[crc(nj["caminho"][len(pref) + 1 :])] = j
        mapas[bi] = mp
    meus = {}
    sem_casar = []
    for pid in sorted(pids_clipe):
        if pid not in clipes:
            continue
        nome, c = clipes[pid]
        bind = c.m_ClipBindingConstant.genericBindings
        hs = {b.path for b in bind if b.typeID == 4 and b.attribute in (1, 2, 3, 4)}
        if not hs:
            continue
        melhor = max(bases, key=lambda bi: sum(1 for h in hs if h in mapas[bi]))
        casa = sum(1 for h in hs if h in mapas[melhor]) / len(hs)
        if casa < 0.6:
            sem_casar.append((nome, round(casa, 2)))
            continue
        try:
            dc = decodificar_clip(c)
        except Exception as e:
            print("  clipe falhou", nome, repr(e)[:120])
            continue
        dc.pop("tempos", None)
        dc["trilhas"] = {
            str(mapas[melhor][h]): {k: [[round(x, 5) for x in q] for q in v] for k, v in tr.items()}
            for h, tr in dc["trilhas"].items()
            if h in mapas[melhor]
        }
        dc["base"] = melhor
        dc["cobertura"] = round(casa, 2)
        k = nome
        while k in meus:
            k += "#2"
        meus[k] = dc
    if sem_casar:
        print("  clipes sem casar:", sem_casar)
    for n in nos:
        n.pop("comps", None)
    json.dump(nos, open(os.path.join(pasta, "rig.json"), "w", encoding="utf-8"), ensure_ascii=False)
    json.dump(malhas, open(os.path.join(pasta, "meshes.json"), "w", encoding="utf-8"), ensure_ascii=False)
    json.dump(meus, open(os.path.join(pasta, "clips.json"), "w", encoding="utf-8"), separators=(",", ":"))
    json.dump(animadores, open(os.path.join(pasta, "animadores.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    resumo[chave] = {"nos": len(nos), "malhas": [m["nome"] for m in malhas], "clipes": sorted(meus)}
    print(chave, "nos", len(nos), "malhas", len(malhas), "clipes", len(meus), flush=True)
json.dump(resumo, open(os.path.join(saida, "resumo.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("pronto")
