"""Gera src/shared/Config/ArmasMalhas.luau a partir de modelos 3d/armas_roblox/{manifesto,enviados}.json.

Uso (da raiz):  python ferramentas/modelos/gerar_config_armas.py
Formato (docs/armas.md §8): [id] = { partes = { { nome, malha, textura, posicao, tamanho } }, ancoras = {...}, comprimento = studs } ou `false`.
- malha = MeshId (rbxassetid://), NAO o id do Model enviado: lido no Studio com InsertService:LoadAsset(modelo) -> MeshPart.MeshId e gravado
  em enviados.json ("meshId", na entrada do .fbx; em "meshIds" {NomeDaParte: id} se o FBX tiver mais de uma parte).
- textura = id da IMAGEM. Enviada como assetType "Image" (enviar_armas.py --imagem Image): o assetId ja e a imagem. Enviada como Decal: gravar "imagemId"
  na entrada do .png depois de converter (Decal.Texture).
- posicao = centro da caixa da parte em studs, origem na empunhadura; tamanho = Size final (o jogo reescala o MeshPart para isso, entao o
  fator de importacao do Roblox nao importa; medido 1,0 em 2026-11-05).
- `false` quando faltar modelo, meshId ou textura enviada/aprovada: o jogo cai no bloco provisorio de ArmaModelo.
"""

import json
import shutil
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "armas_roblox"
SAIDA = RAIZ / "src" / "shared" / "Config" / "ArmasMalhas.luau"
ORDEM = ["faca", "peDeCabra", "machado", "pistola", "beretta", "ar15", "carabinaM5", "ak74", "escopeta", "escopetaM1912", "lancaFoguetes"]


def n(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") if x != int(x) else str(int(x))


def v3(v):
    return "{ x = %s, y = %s, z = %s }" % (n(v[0]), n(v[1]), n(v[2]))


def id_imagem(entrada):
    if not entrada:
        return None
    if entrada.get("imagemId"):
        return int(entrada["imagemId"])
    if entrada.get("tipo") == "Image":
        return int(entrada["assetId"])
    return None  # Decal sem conversao: nao serve de textura


def main():
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))["armas"]
    env = json.loads((PASTA / "enviados.json").read_text(encoding="utf-8")) if (PASTA / "enviados.json").exists() else {}
    linhas = [
        "-- Malhas das armas (docs/armas.md §8). Origem = empunhadura, cano para -Z, cima +Y, studs.",
        "-- GERADO por ferramentas/modelos/gerar_config_armas.py (manifesto.json + enviados.json). Nao editar a mao.",
        "-- `false` = ainda sem malha enviada: Shared/ArmaModelo cai no bloco provisorio.",
        "return {",
    ]
    excluidas = json.loads((Path(__file__).parent / "armas_modelos.json").read_text(encoding="utf-8")).get("excluidas") or {}
    for id_arma in ORDEM:
        m = man.get(id_arma)
        if id_arma in excluidas:
            linhas.append("	%s = false, -- EXCLUIDA do envio (armas_modelos.json > excluidas)" % id_arma)
            continue
        if not m:
            linhas.append("\t%s = false," % id_arma)
            continue
        fbx = env.get(m["arquivo"])
        tex = id_imagem(env.get(m["textura"]))
        malhas = {}
        if fbx:
            malhas = dict(fbx.get("meshIds") or {})
            if fbx.get("meshId") and len(m["partes"]) == 1:
                malhas[m["partes"][0]["nome"]] = fbx["meshId"]
        if not (fbx and tex and all(malhas.get(p["nome"]) for p in m["partes"])):
            linhas.append("\t%s = false, -- falta enviar/ler meshId/imagem (ver enviados.json)" % id_arma)
            continue
        linhas.append("\t%s = {" % id_arma)
        linhas.append("\t\tcomprimento = %s, -- studs" % n(m["comprimento_studs"]))
        linhas.append("\t\tpartes = {")
        for p in m["partes"]:
            linhas.append(
                '\t\t\t{ nome = "%s", malha = "rbxassetid://%d", textura = "rbxassetid://%d", posicao = %s, tamanho = %s },'
                % (p["nome"], int(malhas[p["nome"]]), tex, v3(p["centro"]), v3(p["tamanho"]))
            )
        linhas.append("\t\t},")
        linhas.append("\t\tancoras = {")
        for k, v in m["ancoras"].items():
            linhas.append("\t\t\t%s = %s," % (k, v3(v)))
        linhas.append("\t\t},")
        linhas.append("\t},")
    linhas.append("}")
    SAIDA.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    stylua = shutil.which("stylua")
    if stylua:
        subprocess.run([stylua, str(SAIDA)], check=False)
    print(SAIDA)


if __name__ == "__main__":
    main()
