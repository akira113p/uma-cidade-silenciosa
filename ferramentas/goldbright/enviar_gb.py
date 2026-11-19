"""Envia pela Open Cloud os grupos do Gold Bright: FBX como Model, atlas como Image (o id já é o da imagem), .rbxm como Animation.
Grava modelos 3d/gold-bright/roblox/<grupo>/enviados.json (não reenvia o que tem o mesmo sha256). Chave e criador só do ambiente/.env.

Uso (da raiz):  python -I ferramentas/goldbright/enviar_gb.py [--dry-run] [--so TT33] [--sem-animacoes | --so-animacoes]
Depois:         python -I ferramentas/goldbright/gerar_config_gb.py
Licença: o usuário aceitou publicar sob GPLv3+ (2026-11-15), ver docs/gold-bright-import.md.
"""

import json
import os
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI.parent / "modelos"))
sys.path.insert(0, str(AQUI))
import enviar_veiculos as ev  # noqa: E402
from rodar_gb import BASE, GRUPOS  # noqa: E402

TIPOS = dict(ev.TIPOS_ARQUIVO)
TIPOS[".rbxm"] = ("Animation", "model/x-rbxm")
TIPOS[".png"] = ("Image", "image/png")
ev.TIPOS_ARQUIVO = TIPOS
DESCRICAO = "Uma Cidade Silenciosa - assets do Gold Bright (GPLv3+)"


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    so = sys.argv[sys.argv.index("--so") + 1] if "--so" in sys.argv else None
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    falhas = 0
    for g, pref in GRUPOS.items():
        if so and so != pref:
            continue
        pasta = BASE / "roblox" / g
        man = json.loads((pasta / "manifesto.json").read_text(encoding="utf-8"))
        # --so-animacoes: malha e atlas não mudam quando só os clipes são refeitos (o FBX reexportado muda de bytes à toa)
        nomes = [] if "--so-animacoes" in sys.argv else [man["arquivo"], man["textura"]]
        if "--sem-animacoes" not in sys.argv:
            nomes += ["anim/" + p.name for p in sorted((pasta / "anim").glob("*.rbxm"))]
        caminho_env = pasta / "enviados.json"
        enviados = json.loads(caminho_env.read_text(encoding="utf-8")) if caminho_env.exists() else {}
        for nome in nomes:
            caminho = pasta / nome
            h = ev.sha256(caminho)
            antigo = enviados.get(nome)
            if antigo and antigo.get("sha256") == h and antigo.get("assetId"):
                continue
            if seco:
                print("enviaria", pref, nome, "(%d bytes)" % caminho.stat().st_size)
                continue
            rotulo = "GB " + pref + " " + (Path(nome).stem if nome.startswith("anim/") else Path(nome).suffix[1:])
            try:
                tipo, resp = ev.enviar(caminho, chave, criador, descricao=DESCRICAO, nome=rotulo)
            except RuntimeError as e:
                print("FALHOU", pref, nome, str(e)[:300], flush=True)
                falhas += 1
                if "moderated" in str(e).lower():
                    sys.exit("conta moderada na Open Cloud: parando")
                continue
            enviados[nome] = {
                "sha256": h,
                "assetId": int(resp["assetId"]),
                "tipo": tipo,
                "revisionId": resp.get("revisionId"),
                "moderacao": resp.get("moderationResult"),
            }
            caminho_env.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
            print("enviado", pref, nome, enviados[nome]["assetId"], (resp.get("moderationResult") or {}).get("moderationState"), flush=True)
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
