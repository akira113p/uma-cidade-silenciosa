"""Envia assets/som/ogg/*.ogg pela Open Cloud como Audio (privado) e gera src/shared/Config/SonsMonstros.luau.
Reusa ferramentas/modelos/enviar_veiculos.py (mesma API; chave e criador so do ambiente/.env, nunca impressos).
Registro: assets/som/enviados.json {arquivo: {sha256, assetId, tipo, revisionId, moderacao}}. Nao reenvia o mesmo sha256.
Para no 1o erro 403/429 (conta moderada ou cota). Limites (memoria roblox-limites-assets): 20 MB, 7 min, cota 2.000/30 dias.

Uso (da raiz):  env -u ROBLOX_OPEN_CLOUD_KEY python -I ferramentas/som/enviar_som.py [--dry-run | --so-config]
"""

import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / "ferramentas" / "modelos"))
import enviar_veiculos as ev  # noqa: E402

PASTA = RAIZ / "assets" / "som" / "ogg"
REGISTRO = RAIZ / "assets" / "som" / "enviados.json"
CONFIG = RAIZ / "src" / "shared" / "Config" / "SonsMonstros.luau"
ev.TIPOS_ARQUIVO = dict(ev.TIPOS_ARQUIVO, **{".ogg": ("Audio", "audio/ogg")})
DESCRICAO = "Audio do jogo Uma Cidade Silenciosa (monstros)"


def chave_ordem(caminho):
    # falas primeiro (prioridade se a cota/moderacao parar o envio), depois os sons de jogo
    return (0 if caminho.stem.startswith("VozCorcunda_") else 1, caminho.stem)


def gerar_config(enviados):
    ids = {Path(k).stem: v["assetId"] for k, v in enviados.items() if v.get("assetId")}
    falas = sorted((n for n in ids if n.startswith("VozCorcunda_")), key=lambda n: int(n.split("_")[1]))
    outros = sorted(n for n in ids if not n.startswith("VozCorcunda_"))
    linhas = [
        "-- GERADO por ferramentas/som/enviar_som.py a partir de assets/som/enviados.json. NAO EDITAR.",
        "-- Sons novos dos monstros (docs/monstros/logica.md §9). Origem e licenca de cada um: docs/creditos.md.",
        "",
        "return {",
        "\tVozCorcunda = { " + ", ".join(str(ids[n]) for n in falas) + " },",
        "\tsons = {",
    ]
    for n in outros:
        linhas.append("\t\t%s = %d," % (n, ids[n]))
    linhas += ["\t},", "}", ""]
    CONFIG.write_text("\n".join(linhas), encoding="utf-8", newline="\n")
    print("config:", CONFIG.name, "(%d falas, %d sons)" % (len(falas), len(outros)))


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    enviados = json.loads(REGISTRO.read_text(encoding="utf-8")) if REGISTRO.exists() else {}
    if "--so-config" in sys.argv:
        gerar_config(enviados)
        return
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente/.env")
    n = 0
    for caminho in sorted(PASTA.glob("*.ogg"), key=chave_ordem):
        nome = caminho.name
        h = ev.sha256(caminho)
        antigo = enviados.get(nome)
        if antigo and antigo.get("sha256") == h and antigo.get("assetId"):
            print("ja enviado", nome, antigo["assetId"])
            continue
        n += 1
        if seco:
            print("enviaria", nome, "(%d bytes)" % caminho.stat().st_size)
            continue
        try:
            tipo, resp = ev.enviar(caminho, chave, criador, DESCRICAO, "Cidade " + caminho.stem)
        except RuntimeError as e:
            print("FALHOU", nome, str(e)[:300])
            if "HTTP 403" in str(e) or "HTTP 429" in str(e):
                gerar_config(enviados)
                sys.exit("parei no 1o erro 403/429 (conta moderada ou cota): o resto fica pendente")
            continue
        enviados[nome] = {
            "sha256": h,
            "assetId": int(resp["assetId"]),
            "tipo": tipo,
            "revisionId": resp.get("revisionId"),
            "moderacao": resp.get("moderationResult"),
        }
        REGISTRO.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", nome, enviados[nome]["assetId"], enviados[nome]["moderacao"])
    print("%s %d arquivos" % ("enviaria" if seco else "enviou", n))
    if not seco:
        gerar_config(enviados)


if __name__ == "__main__":
    main()
