"""Envia pela Open Cloud os FBX (Model) e atlas PNG (Decal ou Image) de modelos 3d/armas_roblox/ e grava enviados.json ali.
Reusa a API e as regras de enviar_veiculos.py (chave e dono so do ambiente/.env, sem reenviar o que tem o mesmo sha256).
Se a API pedir Robux ou der erro de preco/permissao, o envio para: nada e gasto sem ordem do usuario.

Uso (da raiz):  python ferramentas/modelos/enviar_armas.py [--dry-run] [--so beretta,ak74] [--imagem Decal|Image]
Depois:         (no Studio) ler MeshId e TextureID de cada modelo com InsertService:LoadAsset e gravar em enviados.json
                ("meshId", "imagemId"); entao python ferramentas/modelos/gerar_config_armas.py

enviados.json: {"<id>/<id>.fbx": {sha256, assetId, tipo, revisionId, moderacao, meshId?}, "<id>/<id>.png": {..., decalId?, imagemId?}}.
Armadilha (igual a veiculos/monstros): o assetId devolvido para a textura e do Decal; o MeshPart precisa do id da IMAGEM.
Reenviar um PNG alterado regrava a entrada sem decalId/imagemId.
"""

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import enviar_veiculos as ev  # noqa: E402

PASTA = ev.RAIZ / "modelos 3d" / "armas_roblox"
RAIZ_DADOS = Path(__file__).resolve().parent  # armas_modelos.json (lista `excluidas`)


def arg(nome, padrao):
    return sys.argv[sys.argv.index(nome) + 1] if nome in sys.argv else padrao


def enviar(caminho, chave, criador, tipo_imagem):
    tipo_asset, tipo_mime = ev.TIPOS_ARQUIVO[caminho.suffix.lower()]
    if tipo_asset == "Decal":
        tipo_asset = tipo_imagem
    pedido = {
        "assetType": tipo_asset,
        "displayName": ("Cidade arma " + caminho.stem)[:50],
        "description": "Arma do jogo Uma Cidade Silenciosa",
        "creationContext": {"creator": {"userId": str(criador)}},
    }
    ctype, corpo = ev.multipart({"request": json.dumps(pedido)}, caminho.name, tipo_mime, caminho.read_bytes())
    req = urllib.request.Request(ev.API + "/assets", data=corpo, method="POST")
    req.add_header("x-api-key", chave)
    req.add_header("Content-Type", ctype)
    op = ev.chamar(req)
    path = op.get("path")
    if not path:
        raise RuntimeError("resposta sem path: %r" % op)
    fim = time.time() + ev.ESPERA_MAX
    while time.time() < fim:
        consulta = urllib.request.Request(ev.API + "/" + path)
        consulta.add_header("x-api-key", chave)
        estado = ev.chamar(consulta)
        if estado.get("done"):
            resposta = estado.get("response")
            if not resposta or "assetId" not in resposta:
                raise RuntimeError("operacao terminou sem assetId: %r" % estado)
            return tipo_asset, resposta
        time.sleep(ev.INTERVALO)
    raise RuntimeError("tempo esgotado esperando " + path)


def main():
    ev.carregar_env()
    seco = "--dry-run" in sys.argv
    tipo_imagem = arg("--imagem", "Decal")
    so = [a for a in arg("--so", "").split(",") if a]
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))["armas"]
    caminho_env = PASTA / "enviados.json"
    enviados = json.loads(caminho_env.read_text(encoding="utf-8")) if caminho_env.exists() else {}
    falhas = 0
    dados = json.loads((RAIZ_DADOS / "armas_modelos.json").read_text(encoding="utf-8"))
    excluidas = dados.get("excluidas") or {}
    for id_arma, m in man.items():
        if id_arma in excluidas:
            print("excluida (nao enviar):", id_arma, "-", excluidas[id_arma])
            continue
        if so and id_arma not in so:
            continue
        for nome in (m["arquivo"], m["textura"]):
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
                tipo, resp = enviar(caminho, chave, criador, tipo_imagem)
            except RuntimeError as e:
                print("FALHOU", nome, e)
                falhas += 1
                if "402" in str(e) or "ayment" in str(e) or "obux" in str(e):
                    print("PARAR: o envio pede pagamento. Nada mais sera enviado.")
                    sys.exit(2)
                continue
            enviados[nome] = {
                "sha256": h,
                "assetId": int(resp["assetId"]),
                "tipo": tipo,
                "revisionId": resp.get("revisionId"),
                "moderacao": resp.get("moderationResult"),
            }
            caminho_env.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
            print("enviado", nome, enviados[nome]["assetId"], tipo)
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
