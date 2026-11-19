"""Envia assets/lanterna/final/lanterna_cookie.png (Image) pela Open Cloud e grava assets/lanterna/final/enviados.json.
Chave e criador só do ambiente/.env, nunca impressos. Não reenvia arquivo com o mesmo sha256.
Uso (da raiz):  python -I ferramentas/lanterna/enviar_cookie.py [--dry-run]"""
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / "ferramentas" / "modelos"))
import enviar_veiculos as ev  # noqa: E402

ev.TIPOS_ARQUIVO = dict(ev.TIPOS_ARQUIVO)
ev.TIPOS_ARQUIVO[".png"] = ("Image", "image/png")
PASTA = RAIZ / "assets" / "lanterna" / "final"
DESCRICAO = "Uma Cidade Silenciosa - mascara de sujeira do facho da lanterna"


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    arq = PASTA / "enviados.json"
    enviados = json.loads(arq.read_text(encoding="utf-8")) if arq.exists() else {}
    nome = "lanterna_cookie.png"
    caminho = PASTA / nome
    h = ev.sha256(caminho)
    antigo = enviados.get(nome)
    if antigo and antigo.get("sha256") == h and antigo.get("assetId"):
        print("ja enviado", nome, antigo["assetId"])
        return
    if seco:
        print("enviaria", nome, caminho.stat().st_size, "bytes")
        return
    try:
        tipo, resp = ev.enviar(caminho, chave, criador, descricao=DESCRICAO, nome="Lanterna cookie sujeira")
    except RuntimeError as e:
        sys.exit("FALHOU " + str(e)[:300])
    enviados[nome] = {
        "sha256": h,
        "assetId": int(resp["assetId"]),
        "tipo": tipo,
        "revisionId": resp.get("revisionId"),
        "moderacao": resp.get("moderationResult"),
    }
    arq.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
    print("enviado", nome, tipo, enviados[nome]["assetId"], (resp.get("moderationResult") or {}).get("moderationState"))


if __name__ == "__main__":
    main()
