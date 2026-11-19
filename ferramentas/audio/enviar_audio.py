"""Envia build/audio/**/*.ogg pela Open Cloud como Audio (privado, padrao da API). Grava ferramentas/audio/enviados.json
(chave = caminho relativo a build/audio, ex. "passos/Dirt_1.ogg"). Reusa enviar_veiculos.py (mesma API; chave e criador so
do ambiente/.env, nunca impressos). Para no 1o erro 403/429. Nao reenvia o que tem o mesmo sha256.

Uso (da raiz):  python ferramentas/audio/enviar_audio.py --dry-run     (lista o que enviaria)
                python ferramentas/audio/enviar_audio.py               (envia de verdade; so com o usuario autorizando)
Depois:         python ferramentas/audio/gerar_config_audio.py
"""

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "modelos"))
import enviar_veiculos as ev  # noqa: E402

PASTA = ev.RAIZ / "build" / "audio"
REGISTRO = Path(__file__).resolve().parent / "enviados.json"
ev.TIPOS_ARQUIVO = dict(ev.TIPOS_ARQUIVO, **{".ogg": ("Audio", "audio/ogg")})
DESCRICAO = "Audio do jogo Uma Cidade Silenciosa (CAPTNPHANTOM PSX, convertido)"


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    if not PASTA.exists():
        sys.exit("rode antes: python ferramentas/audio/converter_psx.py")
    enviados = json.loads(REGISTRO.read_text(encoding="utf-8")) if REGISTRO.exists() else {}
    n = total = 0
    for caminho in sorted(PASTA.rglob("*.ogg")):
        nome = caminho.relative_to(PASTA).as_posix()
        h = ev.sha256(caminho)
        antigo = enviados.get(nome)
        if antigo and antigo.get("sha256") == h and antigo.get("assetId"):
            print("ja enviado", nome, antigo["assetId"])
            continue
        n += 1
        total += caminho.stat().st_size
        if seco:
            print("enviaria", nome, "(%d bytes)" % caminho.stat().st_size)
            continue
        try:
            tipo, resp = ev.enviar(caminho, chave, criador, DESCRICAO, "PSX " + caminho.stem)
        except RuntimeError as e:
            print("FALHOU", nome, e)
            if "HTTP 403" in str(e) or "HTTP 429" in str(e):
                sys.exit("parei no 1o erro 403/429 (conta moderada ou cota): nada mais enviado")
            sys.exit(1)
        enviados[nome] = {
            "sha256": h,
            "assetId": int(resp["assetId"]),
            "tipo": tipo,
            "revisionId": resp.get("revisionId"),
            "moderacao": resp.get("moderationResult"),
        }
        REGISTRO.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", nome, enviados[nome]["assetId"])
    print("%s %d arquivos, %.2f MB" % ("enviaria" if seco else "enviou", n, total / 1e6))


if __name__ == "__main__":
    main()
