"""Envia pela Open Cloud o FBX (Model) e o atlas PNG (Image) de modelos 3d/personagens/<id>/ e grava enviados.json ali.
Reusa a API de enviar_veiculos.py (chave e dono so do ambiente/.env, nunca impressos). PARA no primeiro erro de HTTP.

Uso (da raiz):  python ferramentas/modelos/enviar_personagens.py --so office_worker [--dry-run]
Depois (no Studio, dona do Studio): InsertService:LoadAsset(modelo) e ler o MeshId de cada uma das 15 MeshParts; gravar em
  modelos 3d/personagens/<id>/enviados.json  {"modelo": N, "textura": N, "meshIds": {"Head": N, ...}}
  e rodar python ferramentas/modelos/gerar_config_personagens.py
Este script grava {"modelo": assetId do FBX, "textura": assetId da Image, "sha256": {...}}; "meshIds" fica para o Studio.
Antes de enviar uma textura, OLHAR a imagem: sangue/gore derruba a conta (2026-11-05, Faca).
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enviar_veiculos as ev  # noqa: E402

PASTA = ev.RAIZ / "modelos 3d" / "personagens"
TIPOS = dict(ev.TIPOS_ARQUIVO)
TIPOS[".png"] = ("Image", "image/png")
ev.TIPOS_ARQUIVO = TIPOS


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    if "--so" not in sys.argv:
        sys.exit("use --so <id>[,<id>] (ex.: --so office_worker)")
    ids = sys.argv[sys.argv.index("--so") + 1].split(",")
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente/.env")
    for pid in ids:
        pasta = PASTA / pid
        arq = pasta / "enviados.json"
        dados = json.loads(arq.read_text(encoding="utf-8")) if arq.exists() else {}
        shas = dados.setdefault("sha256", {})
        for chave_json, nome in (("modelo", pid + ".fbx"), ("textura", pid + ".png")):
            caminho = pasta / nome
            h = ev.sha256(caminho)
            if dados.get(chave_json) and shas.get(nome) == h:
                print("ja enviado", pid, nome, dados[chave_json])
                continue
            if seco:
                print("enviaria", pid, nome, "(%d bytes)" % caminho.stat().st_size)
                continue
            try:
                tipo, resp = ev.enviar(caminho, chave, criador, descricao="Personagem do jogo Uma Cidade Silenciosa", nome="Cidade " + pid + " " + caminho.suffix[1:])
            except RuntimeError as e:
                print("FALHOU", pid, nome, e)
                sys.exit("PARADO no primeiro erro (nao insistir, nao gastar Robux)")
            dados[chave_json] = int(resp["assetId"])
            shas[nome] = h
            dados.setdefault("moderacao", {})[nome] = resp.get("moderationResult")
            arq.write_text(json.dumps(dados, indent=2, ensure_ascii=False), encoding="utf-8")
            print("enviado", pid, nome, dados[chave_json], tipo)


if __name__ == "__main__":
    main()
