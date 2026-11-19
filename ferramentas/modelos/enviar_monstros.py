"""Envia pela Open Cloud os arquivos de modelos 3d/rastejador/ (FBX como Model, PNG como Decal) e, com --animacoes,
os clipes .rbxm de modelos 3d/rastejador/anim/ como Animation. Grava enviados.json. Reusa enviar_veiculos.py
(mesma API, mesmas regras: chave e criador so do ambiente/.env, sem reenviar o que tem o mesmo sha256).

Uso (da raiz):  python ferramentas/modelos/enviar_monstros.py [--nome rastejador|wrapper|corcunda|monstrops1|florescida] [--sem-textura] [--imagem] [--dry-run] [--animacoes]
Depois:         python ferramentas/modelos/gerar_config_monstros.py
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enviar_veiculos as ev  # noqa: E402

NOME = sys.argv[sys.argv.index("--nome") + 1] if "--nome" in sys.argv else "rastejador"  # pasta em modelos 3d/
PASTA = ev.RAIZ / "modelos 3d" / NOME
TIPOS = dict(ev.TIPOS_ARQUIVO)
TIPOS[".rbxm"] = ("Animation", "model/x-rbxm")
if "--imagem" in sys.argv:  # PNG como Image: o assetId ja e o id da imagem (sem converter Decal -> imagem no Studio)
    TIPOS[".png"] = ("Image", "image/png")
ev.TIPOS_ARQUIVO = TIPOS  # enviar() consulta este dicionario


def arquivos(com_animacoes):
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))
    nomes = [man["arquivo"]] + ([] if "--sem-textura" in sys.argv else [man["textura"]])  # --sem-textura: segura a textura (moderacao)
    if com_animacoes:
        anim = PASTA / "anim"
        if anim.exists():
            nomes += ["anim/" + p.name for p in sorted(anim.glob("*.rbxm"))]
    return nomes


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    caminho_env = PASTA / "enviados.json"
    enviados = json.loads(caminho_env.read_text(encoding="utf-8")) if caminho_env.exists() else {}
    falhas = 0
    for nome in arquivos("--animacoes" in sys.argv):
        caminho = PASTA / nome
        if not caminho.exists():
            print("FALTA", nome)
            falhas += 1
            continue
        h = ev.sha256(caminho)
        antigo = enviados.get(nome)
        if antigo and antigo.get("sha256") == h and antigo.get("assetId"):
            print("ja enviado", nome, antigo["assetId"])
            continue
        if seco:
            print("enviaria", nome, "(%d bytes)" % caminho.stat().st_size)
            continue
        try:
            tipo, resp = ev.enviar(caminho, chave, criador)
        except RuntimeError as e:
            print("FALHOU", nome, e)
            falhas += 1
            continue
        enviados[nome] = {
            "sha256": h,
            "assetId": int(resp["assetId"]),
            "tipo": tipo,
            "revisionId": resp.get("revisionId"),
            "moderacao": resp.get("moderationResult"),
        }
        if tipo == "Image":
            enviados[nome]["imagemId"] = int(resp["assetId"])
        caminho_env.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", nome, enviados[nome]["assetId"])
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
