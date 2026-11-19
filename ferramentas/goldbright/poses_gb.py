"""Extrai do Gold Bright as poses de 1ª pessoa de cada arma (o que o código põe por cima das animações).

Fonte (decompilado em E:\\ferramentas\\analise\\decomp2, ver docs/gold-bright-import.md "Enquadramento"):
  WeaponModelRecoil.Update: nó da arma (Equipment/<arma>).localPosition -> lerp(aimSpeed) para normalPosition (quadril) ou
  aimingPosition + aimingPosition{Scope,IronSight}Offset (mirando). "Recoil Position".localPosition = lerpedPositionOffset +
  positionalRecoil; .localRotation = Euler(sway + rotationalRecoil + aditionalMovementRotation + aimingRotation{IronSight,Scope}Offset).
  lerpedPositionOffset -> runningPositionOffset (parede a < 1,6 m ou correndo) | cantFirePositionOffset (IsCantFireAnim), menos
  pitch/1080 * forward. WeaponModelRecoil.Fire: rotationalRecoil = (-rot.x, ±rot.y, ±rot.z), positionalRecoil = (±kick.x, -kick.y, -kick.z).
Campos serializados lidos dos bytes crus (sem typetree no build): WeaponModelRecoil = 3 PPtr + floats fixos; GunHandler = bloco de
4 Vector3 (runningRotation, runningPositionOffset, cantFirePositionOffset, cantFireRotation) achado pelo padrão que vem depois.

Uso (da raiz): python -I ferramentas/goldbright/poses_gb.py  ->  modelos 3d/gold-bright/poses.json
"""

import json
import os
import struct

import UnityPy

DADOS = r"E:\jogos\gold bright\gold bright_Data"
SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "modelos 3d", "gold-bright", "poses.json")

env = UnityPy.load(os.path.join(DADOS, "resources.assets"), os.path.join(DADOS, "globalgamemanagers.assets"))
res = [f for f in env.files.values() if f.name.endswith("resources.assets")][0]
ggm = [f for f in env.files.values() if f.name.endswith("globalgamemanagers.assets")][0]
O = res.objects
scripts = {}
for pid, o in ggm.objects.items():
    if o.type.name == "MonoScript":
        try:
            scripts[pid] = o.read().m_ClassName
        except Exception:
            pass


def rd(p):
    return O[p].read()


def nome(tr):
    return tr.m_GameObject.read().m_Name


def sob_camera(tr):
    t = tr
    while t.m_Father.m_PathID != 0:
        t = rd(t.m_Father.m_PathID)
        if nome(t) == "Main Camera":
            return True
    return False


def corpo_mb(o):
    raw = o.get_raw_data()
    (nl,) = struct.unpack_from("<i", raw, 28)
    p = (32 + nl + 3) & ~3
    return raw, raw[p:]


def f(corpo, i, n=1):
    v = struct.unpack_from("<" + "f" * n, corpo, i * 4)
    return [round(x, 5) for x in v] if n > 1 else round(v[0], 5)


armas = {}
for pid, o in O.items():
    if o.type.name != "MonoBehaviour":
        continue
    raw, corpo = corpo_mb(o)
    classe = scripts.get(struct.unpack_from("<q", raw, 20)[0])
    if classe not in ("WeaponModelRecoil", "GunHandler"):
        continue
    go = rd(struct.unpack_from("<q", raw, 4)[0])
    tr = rd(go.m_Transform.m_PathID)
    if not sob_camera(tr):
        continue
    a = armas.setdefault(go.m_Name, {})
    if classe == "WeaponModelRecoil":
        a["recoil"] = {
            "normalPosition": f(corpo, 9, 3),
            "aimingPosition": f(corpo, 12, 3),
            "aimingPositionScopeOffset": f(corpo, 15, 3),
            "aimingPositionIronSightOffset": f(corpo, 18, 3),
            "aimingRotationIronSightOffset": f(corpo, 21, 3),
            "useDifferentRotationForScope": struct.unpack_from("<B", corpo, 24 * 4)[0] != 0,
            "aimingRotationScopeOffset": f(corpo, 25, 3),
            "aimSpeed": f(corpo, 28),
            "positionalRecoilSpeed": f(corpo, 29),
            "rotationalRecoilSpeed": f(corpo, 30),
            "positionalNormalizeSpeed": f(corpo, 31),
            "rotationalNormalizeSpeed": f(corpo, 32),
            "rotateToOriginalMultiplier": f(corpo, 33),
            "recoilRotationHipfire": f(corpo, 34, 3),
            "recoilKickbackHipfire": f(corpo, 37, 3),
            "recoilRotationAim": f(corpo, 40, 3),
            "recoilKickbackAim": f(corpo, 43, 3),
            "swayMultPos": f(corpo, 52),
            "swayMultRot": f(corpo, 53),
            "swayMultIronSight": f(corpo, 54),
            "movementSwayY": f(corpo, 55),
            "emptyPosMult": f(corpo, 56),
        }
        # raiz do rig sob a Recoil Position (filho com Animator e Arms_Rig)
        for c in tr.m_Children:
            rp = rd(c.m_PathID)
            if nome(rp) != "Recoil Position":
                continue
            a["recoilPositionLocal"] = [rp.m_LocalPosition.x, rp.m_LocalPosition.y, rp.m_LocalPosition.z]
            a["raizes"] = {}
            for c2 in rp.m_Children:
                t3 = rd(c2.m_PathID)
                lp, lq = t3.m_LocalPosition, t3.m_LocalRotation
                a["raizes"][nome(t3)] = {
                    "pos": [round(lp.x, 5), round(lp.y, 5), round(lp.z, 5)],
                    "rot": [round(lq.x, 5), round(lq.y, 5), round(lq.z, 5), round(lq.w, 5)],
                    "ativo": bool(t3.m_GameObject.read().m_IsActive),
                }
    else:
        n = len(corpo) // 4
        bloco = None
        for j in range(60, n - 6):
            z0, z1, z2 = f(corpo, j), f(corpo, j + 1), f(corpo, j + 2)
            if z0 == 0 and z1 == 0 and z2 == 0 and f(corpo, j + 4) in (1.15, 1.25) and f(corpo, j + 5) == 0.75:
                bloco = j - 12
                break
        if bloco is None:
            print("GunHandler sem bloco de poses:", go.m_Name)
            continue
        a["gunHandler"] = {
            "runningRotation": f(corpo, bloco, 3),
            "runningPositionOffset": f(corpo, bloco + 3, 3),
            "cantFirePositionOffset": f(corpo, bloco + 6, 3),
            "cantFireRotation": f(corpo, bloco + 9, 3),
            "indiceBloco": bloco,
        }

json.dump(armas, open(SAIDA, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
for k, v in armas.items():
    print(k, "recoil" in v, "gunHandler" in v, v.get("recoil", {}).get("normalPosition"), v.get("gunHandler", {}).get("cantFireRotation"))
print("gravado", os.path.abspath(SAIDA))
