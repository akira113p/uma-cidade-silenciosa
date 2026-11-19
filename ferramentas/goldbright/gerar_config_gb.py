"""Gera src/shared/Config/ArmasGB.luau a partir do que foi enviado (enviados.json) e dos dados de cada grupo do Gold Bright.

Uso (da raiz):  python -I ferramentas/goldbright/gerar_config_gb.py
Por arma: modelo (Model do FBX), textura (Image), câmera e boca no espaço do MeshPart, e estados do Animator original
(Idle, Draw, Fire, Cock, Reload Phase 1..3 [- Empty], Check Ammo [Close], Melee Attack...) -> lista de animações que tocam juntas.
Conversão Unity -> MeshPart: p_r = escala * M * (U2B(p) - centro_blend), M = [x'=-x, y'=z, z'=y] (mesma regra dos monstros),
U2B(x,y,z) = (-x,-z,y); rotação: F R F, F = diag(1,1,-1). O MeshPart do Roblox fica no centro da caixa da malha.
"""

import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from rodar_gb import BASE, GRUPOS  # noqa: E402

RAIZ = AQUI.parents[1]
SAIDA = RAIZ / "src" / "shared" / "Config" / "ArmasGB.luau"
# prefixo do grupo -> id da arma em Config/Armas (armas novas, decisão do usuário 2026-11-15)
ARMA_DO_GRUPO = {
    "TT33": "tt33",
    "MP5": "mp5",
    "PP91": "pp91",
    "OTS20": "ots20",
    "OTS48K": "ots48k",
    "RMB93": "rmb93",
    "SR3M": "sr3m",
    "TOZ34": "toz34",
    "CanoChumbo": "canoChumbo",
}
M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], dtype=float)
F = np.diag([1.0, 1.0, -1.0])
RELOGIO = False  # relógio e cruz de vida tirados do viewmodel (2026-11-16); True volta a gerar `vista.relogio` (precisa da malha Watch)
C_OSSO = np.diag([-1.0, 1.0, -1.0])  # derivar_repouso_roblox: rotação do osso no Roblox = (Tf @ matrix_local)/s @ C
# grupo -> (nó da arma em Equipment, raiz do rig sob a Recoil Position) no prefab do Player (poses.json)
EQUIP = {
    "TT33": ("TT-33", "TT33_With_Anims"),
    "MP5": ("MP5", "MP5_Idle_With_Mesh"),
    "PP91": ("PP-91 Kedr", "PP_91_Idle"),
    "OTS20": ("OTs-20 Gnom", "OTs-20"),
    "OTS48K": ("OTs-48K", "OTs-48K_Rig_With_Idle"),
    "RMB93": ("RMB-93", "RMB-93-Ref"),
    "SR3M": ("SR-3M", "SR-3M"),
    "TOZ34": ("TOZ-34", "TOZ34_Rig"),
    "CanoChumbo": ("Lead Pipe", "Lead_Pipe_Idle"),
}
LUNETA = {"OTS48K"}  # luneta fixa (montar_blend_gb.ACESSORIOS): a mira usa aimingPositionScopeOffset e o retículo em tela cheia
POSES = json.loads((BASE / "poses.json").read_text(encoding="utf-8"))


def qmat(q):
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def mundo_repouso(rig):
    W = []
    for i, n in enumerate(rig):
        L = np.eye(4)
        if i > 0:
            L[:3, :3] = qmat(n["rot"]) * np.array(n["esc"])[None, :]
            L[:3, 3] = n["pos"]
        W.append(L if n["pai"] is None else W[n["pai"]] @ L)
    return W


def vista_cfg(g, pref, s, centro, man):
    """Poses do jogo (Unity, metros, graus) -> espaço da câmera do Roblox (studs). Posição: s*(x, y, -z). Rotação Euler do Unity
    (Quaternion.Euler: Z, depois X, depois Y) -> Roblox CFrame.fromEulerAnglesYXZ(-x, -y, z) (conjugação por F = diag(1,1,-1))."""
    nome_equip, nome_raiz = EQUIP[pref]
    pz = POSES[nome_equip]
    rc, gh = pz["recoil"], pz.get("gunHandler", {})

    def P(v):
        return [s * v[0], s * v[1], -s * v[2]]

    def R(v):
        return [-v[0], -v[1], v[2]]

    luneta = pref in LUNETA
    mira = np.array(rc["aimingPosition"]) + np.array(
        rc["aimingPositionScopeOffset"] if luneta else rc["aimingPositionIronSightOffset"]
    )
    usa_rot_luneta = luneta and rc["useDifferentRotationForScope"]
    rot_mira = rc["aimingRotationScopeOffset"] if usa_rot_luneta else rc["aimingRotationIronSightOffset"]
    raiz = pz["raizes"][nome_raiz]
    rig = json.loads((BASE / g / "rig.json").read_text(encoding="utf-8"))
    W = mundo_repouso(rig)
    idx = {n["nome"]: i for i, n in enumerate(rig)}
    # profundidade das mãos no quadril (emular a câmera das armas de FOV 55): normal + Recoil Position + raiz + mão
    mao = W[idx["Hand_R"]][:3, 3]
    prof = (rc["normalPosition"][2] + pz["recoilPositionLocal"][2] + raiz["pos"][2] + mao[2]) * s
    # malha a partir da raiz: MeshPart = raiz * CFrame.new(k), k = s*M*centro_blend
    k = s * M @ centro
    # mostrador do relógio (cruz de vida): lado +Z do nó Watch, preso ao osso mais próximo que existe no rig do Roblox
    relogio = None
    if RELOGIO and "Watch" in idx:
        wi = idx["Watch"]
        Ww = W[wi]
        p_u = (Ww @ np.array([0, 0, 0.000313, 1.0]))[:3]
        Rw = Ww[:3, :3] / np.linalg.norm(Ww[:3, :3], axis=0)
        osso_i = rig[wi]["pai"]
        while osso_i is not None and rig[osso_i]["nome"] not in man["ossos"]:
            osso_i = rig[osso_i]["pai"]
        if osso_i is not None:
            nome_osso = rig[osso_i]["nome"]
            ml = np.array(man["ossos"][nome_osso]["matrix_local"])
            osso_pos = s * M @ (ml[:3, 3] - centro)
            osso_rot = M @ ml[:3, :3] @ C_OSSO
            face_pos = s * F @ p_u - k
            face_rot = F @ Rw @ F
            off_pos = osso_rot.T @ (face_pos - osso_pos)
            off_rot = osso_rot.T @ face_rot
            diametro = float(np.linalg.norm(Ww[:3, 0])) * 0.0006 * s  # malha do relógio: +-0,0003 no nó
            relogio = {"osso": nome_osso, "cf": [*off_pos, *off_rot.reshape(-1)], "diametro": diametro}
    return {
        "quadril": P(rc["normalPosition"]),
        "mira": P(mira),
        "rotMira": R(rot_mira),
        "recoilPosition": P(pz["recoilPositionLocal"]),
        "raiz": P(raiz["pos"]),
        "malhaNaRaiz": list(k),
        "corrida": {"pos": P(gh.get("runningPositionOffset", [0, 0, 0])), "rot": R(gh.get("runningRotation", [0, 0, 0]))},
        "naoAtira": {"pos": P(gh.get("cantFirePositionOffset", [0, 0, 0])), "rot": R(gh.get("cantFireRotation", [0, 0, 0]))},
        "velMira": rc["aimSpeed"],
        "velRecuoPos": rc["positionalRecoilSpeed"],
        "velRecuoRot": rc["rotationalRecoilSpeed"],
        "voltaPos": rc["positionalNormalizeSpeed"],
        "voltaRot": rc["rotationalNormalizeSpeed"],
        "coiceRotQuadril": rc["recoilRotationHipfire"],
        "coicePosQuadril": [s * x for x in rc["recoilKickbackHipfire"]],
        "coiceRotMira": rc["recoilRotationAim"],
        "coicePosMira": [s * x for x in rc["recoilKickbackAim"]],
        "swayPos": rc["swayMultPos"],
        "swayRot": rc["swayMultRot"],
        "profundidade": prof,
        "luneta": luneta,
        "relogio": relogio,
        "escala": s,
    }


def san(nome):
    return re.sub(r"[^A-Za-z0-9_]+", "_", nome).strip("_")


def num(x):
    return repr(round(float(x), 5))


def grupo_cfg(g, pref):
    pasta_x = BASE / g
    pasta_r = BASE / "roblox" / g
    man = json.loads((pasta_r / "manifesto.json").read_text(encoding="utf-8"))
    env_p = pasta_r / "enviados.json"
    env = json.loads(env_p.read_text(encoding="utf-8")) if env_p.exists() else {}
    anim = json.loads((pasta_r / "anim_roblox.json").read_text(encoding="utf-8"))
    animadores = json.loads((pasta_x / "animadores.json").read_text(encoding="utf-8"))
    extra = json.loads((pasta_x / "extra.json").read_text(encoding="utf-8"))
    boca_b = json.loads((BASE / "_blend" / (g + "_boca.json")).read_text(encoding="utf-8"))["boca_blend"]
    s = man["escala_blender_para_fbx"]
    d = man["dimensoes_blend"]
    centro = (np.array(d["min"]) + np.array(d["max"])) / 2

    def ponto(b):
        return s * M @ (np.array(b) - centro)

    modelo = (env.get(man["arquivo"]) or {}).get("assetId")
    textura = (env.get(man["textura"]) or {}).get("assetId")
    cam = np.array(extra["camera_na_raiz"])
    cu = cam[:3, 3]
    cam_p = ponto([-cu[0], -cu[2], cu[1]])
    cam_r = F @ cam[:3, :3] @ F
    estados = {}
    for a in animadores:
        for estado, clipe in a["estados"].items():
            nome = san(clipe)
            if nome not in anim:
                continue
            ent = env.get(f"anim/{pref}_{nome}.rbxm")
            if not ent:
                continue
            lst = estados.setdefault(estado, [])
            if any(x["id"] == ent["assetId"] for x in lst):
                continue
            lst.append({"id": ent["assetId"], "dur": anim[nome]["duracao"], "loop": anim[nome]["ciclica"], "clipe": nome})
    return {
        "vista": vista_cfg(g, pref, s, centro, man) if pref in EQUIP else None,
        "modelo": modelo,
        "textura": textura,
        "camera": [*cam_p, *cam_r.reshape(-1)],
        "boca": ponto(boca_b),
        "tamanho": [x * s for x in d["tamanho"]],
        "fov": extra["fovs"],
        "estados": estados,
    }


def lv(v):
    return "{ " + ", ".join(num(x) for x in v) + " }"


def luau_vista(v):
    t3, t4 = "\t" * 3, "\t" * 4
    L = [t3 + "-- Poses do jogo original (poses_gb.py: WeaponModelRecoil + GunHandler), em studs e eixos do Roblox (espaço da câmera)."]
    L.append(t3 + "vista = {")
    for chave in ("quadril", "mira", "rotMira", "recoilPosition", "raiz", "malhaNaRaiz", "coiceRotQuadril", "coicePosQuadril", "coiceRotMira", "coicePosMira"):
        L.append(f"{t4}{chave} = {lv(v[chave])},")
    for chave in ("corrida", "naoAtira"):
        L.append(f"{t4}{chave} = {{ pos = {lv(v[chave]['pos'])}, rot = {lv(v[chave]['rot'])} }},")
    for chave in ("velMira", "velRecuoPos", "velRecuoRot", "voltaPos", "voltaRot", "swayPos", "swayRot", "profundidade", "escala"):
        L.append(f"{t4}{chave} = {num(v[chave])},")
    L.append(f"{t4}luneta = {str(v['luneta']).lower()},")
    if v["relogio"]:
        r = v["relogio"]
        L.append(f'{t4}relogio = {{ osso = "{r["osso"]}", cf = {lv(r["cf"])}, diametro = {num(r["diametro"])} }},')
    L.append(t3 + "},")
    return L


def luau_entrada(chave, pref, c):
    L = [f"\t\t{chave} = {{"]
    L.append(f'\t\t\tgrupo = "{pref}",')
    L.append(f"\t\t\tmodelo = {c['modelo'] or 'nil'}, -- Model (FBX); nil = ainda não enviado")
    L.append("\t\t\ttextura = " + (f'"rbxassetid://{c["textura"]}",' if c["textura"] else "nil,"))
    L.append("\t\t\t-- CFrame da câmera original no espaço do MeshPart (x, y, z, R00..R22): MeshPart.CFrame = câmera * ajuste * camera:Inverse()")
    L.append("\t\t\tcamera = { " + ", ".join(num(x) for x in c["camera"]) + " },")
    L.append("\t\t\tboca = { " + ", ".join(num(x) for x in c["boca"]) + " }, -- ponta da arma no espaço do MeshPart")
    L.append("\t\t\ttamanho = { " + ", ".join(num(x) for x in c["tamanho"]) + " }, -- studs (x, z do Blender) só para conferência")
    if c.get("vista"):
        L += luau_vista(c["vista"])
    L.append("\t\t\tfovOriginal = " + num(c["fov"].get("OverlayCam") or c["fov"].get("Main Camera") or 70) + ",")
    L.append("\t\t\testados = {")
    for estado in sorted(c["estados"]):
        itens = ", ".join(
            f'{{ id = "rbxassetid://{x["id"]}", dur = {num(x["dur"])}, loop = {str(x["loop"]).lower()} }}'
            for x in c["estados"][estado]
        )
        L.append(f'\t\t\t\t["{estado}"] = {{ {itens} }}, -- ' + ", ".join(x["clipe"] for x in c["estados"][estado]))
    L.append("\t\t\t},")
    L.append("\t\t},")
    return L


def main():
    L = [
        "-- Viewmodel do Gold Bright (braços + arma animados em 1ª pessoa). Contrato: docs/gold-bright-import.md.",
        "-- GERADO por ferramentas/goldbright/gerar_config_gb.py (enviados.json + dados extraídos). Não editar à mão.",
        "-- Assets do Gold Bright: GPLv3+ (aceito pelo usuário em 2026-11-15). Sem `modelo` a arma usa o viewmodel de blocos.",
        "return {",
        "\tarmas = {",
    ]
    itens = []
    for g, pref in GRUPOS.items():
        c = grupo_cfg(g, pref)
        if pref in ARMA_DO_GRUPO:
            L += luau_entrada(ARMA_DO_GRUPO[pref], pref, c)
        else:
            itens.append((pref, c))
    L.append("\t},")
    L.append("\t-- Comer/beber/remédio: enviados, ainda não ligados ao uso dos itens (estado \"Pills\" = o clipe do item).")
    L.append("\titens = {")
    for pref, c in itens:
        L += luau_entrada(pref, pref, c)
    L.append("\t},")
    L.append("}")
    SAIDA.write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")  # o projeto é LF (stylua)
    stylua = shutil.which("stylua")
    if stylua:
        subprocess.run([stylua, str(SAIDA)], cwd=RAIZ)
    print("gravado", SAIDA)


if __name__ == "__main__":
    main()
