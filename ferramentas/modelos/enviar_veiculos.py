"""Envia os FBX e texturas de modelos 3d/veiculos/ ao Roblox pela Open Cloud (Assets API v1) e grava enviados.json.

NAO RODAR sem a chave do usuario. Chave e dono vem do ambiente ou do arquivo .env na raiz (no .gitignore), nunca do repositorio:
  ROBLOX_OPEN_CLOUD_KEY  chave com a permissao "asset: read/write" (header x-api-key)
  ROBLOX_CREATOR_ID      id do usuario dono dos assets (creationContext.creator.userId)

Uso (da raiz do projeto):  python ferramentas/modelos/enviar_veiculos.py [--dry-run]
Depois:                     python ferramentas/modelos/gerar_config.py

Doc oficial conferida (2026-11-03): https://create.roblox.com/docs/cloud/guides/usage-assets
  POST https://apis.roblox.com/assets/v1/assets, multipart/form-data com os campos
    request     = JSON {"assetType", "displayName", "description", "creationContext": {"creator": {"userId"}}}
    fileContent = o arquivo, com Content-Type (FBX: model/fbx; PNG: image/png; JPEG: image/jpeg; TGA: image/tga; BMP: image/bmp)
  Resposta: {"path": "operations/<id>"}. GET https://apis.roblox.com/assets/v1/operations/<id> ate "done": true;
  entao "response" traz "assetId". Limite de 20 MB por arquivo; Decal menor que 8000x8000.
  assetType usados: "Model" (FBX) e "Decal" (textura), como no contrato docs/veiculos-modelos.md.

enviados.json: {"<arquivo>": {"sha256", "assetId", "tipo", "revisionId", "moderacao"}}. Arquivo com o mesmo sha256 ja enviado
nao e reenviado. Manifesto: ver gerar_config.py (campos "arquivos[].arquivo" e "arquivos[].textura").
"""

import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "veiculos"
API = "https://apis.roblox.com/assets/v1"
TIPOS_ARQUIVO = {
    ".fbx": ("Model", "model/fbx"),
    ".png": ("Decal", "image/png"),
    ".jpg": ("Decal", "image/jpeg"),
    ".jpeg": ("Decal", "image/jpeg"),
    ".tga": ("Decal", "image/tga"),
    ".bmp": ("Decal", "image/bmp"),
}
ESPERA_MAX = 180  # s por operacao
INTERVALO = 2  # s entre consultas da operacao


def sha256(caminho):
    h = hashlib.sha256()
    h.update(caminho.read_bytes())
    return h.hexdigest()


def multipart(campos_texto, arquivo_nome, arquivo_tipo, arquivo_bytes):
    limite = "----cidade" + uuid.uuid4().hex
    corpo = bytearray()
    for nome, valor in campos_texto.items():
        corpo += ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (limite, nome, valor)).encode("utf-8")
    corpo += (
        '--%s\r\nContent-Disposition: form-data; name="fileContent"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
        % (limite, arquivo_nome, arquivo_tipo)
    ).encode("utf-8")
    corpo += arquivo_bytes + b"\r\n--%s--\r\n" % limite.encode()
    return "multipart/form-data; boundary=" + limite, bytes(corpo)


def chamar(req):
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError("HTTP %d: %s" % (e.code, e.read().decode("utf-8", "replace")[:500]))


def enviar(caminho, chave, criador):
    tipo_asset, tipo_mime = TIPOS_ARQUIVO[caminho.suffix.lower()]
    pedido = {
        "assetType": tipo_asset,
        "displayName": ("Cidade " + caminho.stem)[:50],
        "description": "Veiculo do jogo Uma Cidade Silenciosa",
        "creationContext": {"creator": {"userId": str(criador)}},
    }
    ctype, corpo = multipart({"request": json.dumps(pedido)}, caminho.name, tipo_mime, caminho.read_bytes())
    req = urllib.request.Request(API + "/assets", data=corpo, method="POST")
    req.add_header("x-api-key", chave)
    req.add_header("Content-Type", ctype)
    op = chamar(req)
    path = op.get("path")
    if not path:
        raise RuntimeError("resposta sem path: %r" % op)
    fim = time.time() + ESPERA_MAX
    while time.time() < fim:
        consulta = urllib.request.Request(API + "/" + path)  # path = "operations/<id>"
        consulta.add_header("x-api-key", chave)
        estado = chamar(consulta)
        if estado.get("done"):
            resposta = estado.get("response")
            if not resposta or "assetId" not in resposta:
                raise RuntimeError("operacao terminou sem assetId: %r" % estado)
            return tipo_asset, resposta
        time.sleep(INTERVALO)
    raise RuntimeError("tempo esgotado esperando " + path)


def arquivos_do_manifesto():
    manifesto = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))
    a = manifesto.get("arquivos", [])
    if isinstance(a, dict):
        a = [dict(v, arquivo=v.get("arquivo", k)) for k, v in a.items()]
    nomes = []
    for item in a:
        for n in [item.get("arquivo"), item.get("textura")] + list(item.get("texturas") or []):
            if n and n not in nomes:
                nomes.append(n)
    return nomes


def carregar_env():
    """Le KEY=valor de .env na raiz do projeto (ignorado pelo git). Variavel do ambiente tem prioridade."""
    arq = Path(__file__).resolve().parents[2] / ".env"
    if not arq.exists():
        return
    for linha in arq.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        k, v = linha.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def main():
    carregar_env()
    seco = "--dry-run" in sys.argv
    chave = os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    criador = os.environ.get("ROBLOX_CREATOR_ID")
    if not seco and not (chave and criador):
        sys.exit("defina ROBLOX_OPEN_CLOUD_KEY e ROBLOX_CREATOR_ID no ambiente")
    caminho_enviados = PASTA / "enviados.json"
    enviados = json.loads(caminho_enviados.read_text(encoding="utf-8")) if caminho_enviados.exists() else {}
    falhas = 0
    for nome in arquivos_do_manifesto():
        caminho = PASTA / nome
        if not caminho.exists():
            caminho = PASTA / "texturas" / nome  # PNG ficam em texturas/
        if not caminho.exists():
            print("FALTA", nome)
            falhas += 1
            continue
        if caminho.suffix.lower() not in TIPOS_ARQUIVO:
            print("tipo nao suportado", nome)
            falhas += 1
            continue
        hash_atual = sha256(caminho)
        antigo = enviados.get(nome)
        if antigo and antigo.get("sha256") == hash_atual and antigo.get("assetId"):
            print("ja enviado", nome, antigo["assetId"])
            continue
        if seco:
            print("enviaria", nome, "(%d bytes)" % caminho.stat().st_size)
            continue
        try:
            tipo_asset, resposta = enviar(caminho, chave, criador)
        except RuntimeError as e:
            print("FALHOU", nome, e)
            falhas += 1
            continue
        enviados[nome] = {
            "sha256": hash_atual,
            "assetId": int(resposta["assetId"]),
            "tipo": tipo_asset,
            "revisionId": resposta.get("revisionId"),
            "moderacao": resposta.get("moderationResult"),
        }
        caminho_enviados.write_text(json.dumps(enviados, indent=2, ensure_ascii=False), encoding="utf-8")
        print("enviado", nome, enviados[nome]["assetId"])
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
