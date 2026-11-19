"""Roda a cadeia local do Gold Bright para todos os grupos: .blend -> FBX+manifesto -> Bone.Transform -> .rbxm.
Não envia nada ao Roblox (isso é enviar_gb.py, com --dry-run por padrão).

Uso (da raiz):  python -I ferramentas/goldbright/rodar_gb.py [--so TT33] [--sem-blend]
Pré-requisito: python -I ferramentas/goldbright/extrair_gb.py "modelos 3d/gold-bright"
"""

import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
BASE = RAIZ / "modelos 3d" / "gold-bright"
BLENDER = r"C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"

# grupo extraído -> prefixo do Animation (curto; os clipes repetem nomes entre grupos)
GRUPOS = {
    "TT-33__TT33_With_Anims": "TT33",
    "MP5__MP5_Idle_With_Mesh": "MP5",
    "PP-91_Kedr__PP_91_Idle": "PP91",
    "OTs-20_Gnom__OTs-20": "OTS20",
    "OTs-48K__OTs-48K_Rig_With_Idle": "OTS48K",
    "RMB-93__RMB-93-Ref": "RMB93",
    "SR-3M__SR-3M": "SR3M",
    "TOZ-34__TOZ34_Rig": "TOZ34",
    "Lead_Pipe__Lead_Pipe_Idle": "CanoChumbo",
    "FP__Canned_Meat": "LataCarne",
    "FP__Canned_Fish": "LataPeixe",
    "FP__Condensed_Milk": "LeiteCondensado",
    "FP__Pills_Main": "Comprimidos",
    "FP__Morphine_Main": "Morfina",
    "FP__Vaccine_Main": "Vacina",
    "FP__Vodka": "Vodka",
    "FP__Potato_Meal": "BatataCozida",
    "FP__Raw_Potato": "BatataCrua",
}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=RAIZ)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 or "Traceback" in out:
        print(out[-1500:])
        raise SystemExit(f"falhou: {cmd[:6]}")
    return out


def main():
    so = sys.argv[sys.argv.index("--so") + 1] if "--so" in sys.argv else None
    for g, pref in GRUPOS.items():
        if so and so != pref:
            continue
        if "--sem-blend" not in sys.argv:
            run([BLENDER, "-b", "--factory-startup", "-P", "ferramentas/goldbright/montar_blend_gb.py", "--", "--grupo", str(BASE / g)])
        out = run([BLENDER, "-b", "--factory-startup", "-P", "ferramentas/goldbright/exportar_gb.py", "--", "--grupo", g])
        pasta = str(BASE / "roblox" / g)
        run([sys.executable, "-I", "ferramentas/goldbright/converter_anim_gb.py", pasta])
        run(["lune", "run", "ferramentas/goldbright/montar_anim_gb.luau", pasta, pref + "_"])
        n = len(list((BASE / "roblox" / g / "anim").glob("*.rbxm")))
        print(f"{pref:16s} {g:34s} {n:2d} animacoes | {[l for l in out.splitlines() if '##EXPORT##' in l][0][11:100]}")


if __name__ == "__main__":
    main()
