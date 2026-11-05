"""Envia pela Open Cloud os clipes de arma (build/anim_armas/*.rbxm, montados por montar_armas.luau) como Animation e grava
ferramentas/animacao/enviados.json {"<classe>_<Clipe>.rbxm": {sha256, assetId, tipo, revisionId, moderacao}}.
Reusa ferramentas/modelos/enviar_veiculos.py (mesma API; chave e criador so do ambiente/.env, nunca impressos).
PARA no primeiro erro de HTTP (ex.: 403 "User is moderated", pedido de Robux/preco): nao insiste, nao gasta Robux.
Uso (da raiz):
  lune run ferramentas/animacao/montar_armas.luau
  python ferramentas/animacao/enviar_animacoes.py [--dry-run]
  python ferramentas/animacao/gerar_config.py       # preenche src/shared/Config/ArmasAnim.luau com os ids
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "modelos"))
import enviar_veiculos as ev  # noqa: E402

ENTRADA = ev.RAIZ / "build" / "anim_armas"
ENVIADOS = ev.RAIZ / "ferramentas" / "animacao" / "enviados.json"
TIPOS = dict(ev.TIPOS_ARQUIVO)
TIPOS[".rbxm"] = ("Animation", "model/x-rbxm")
ev.TIPOS_ARQUIVO = TIPOS


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    enviados = json.loads(ENVIADOS.read_text(encoding="utf-8")) if ENVIADOS.exists() else {}
    for caminho in sorted(ENTRADA.glob("*.rbxm")):
        nome = caminho.name
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
            sys.exit("PARADO no primeiro erro (nao insistir; ver docs/pendencias-integracao.md, secao Armas)")
        enviados[nome] = {
            "sha256": h,
            "assetId": int(resp["assetId"]),
            "tipo": tipo,
            "revisionId": resp.get("revisionId"),
            "moderacao": resp.get("moderationResult"),
        }
        ENVIADOS.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", nome, enviados[nome]["assetId"])


if __name__ == "__main__":
    main()
