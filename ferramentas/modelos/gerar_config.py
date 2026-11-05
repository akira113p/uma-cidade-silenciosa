"""Gera src/shared/Config/VeiculosMalhas.luau a partir de manifesto.json (M1) e enviados.json (enviar_veiculos.py).

Uso: python ferramentas/modelos/gerar_config.py   (da raiz do projeto)

Formato esperado de modelos 3d/veiculos/manifesto.json (contrato docs/veiculos-modelos.md; os nomes exatos dos campos
são uma SUPOSIÇÃO da M2, ver docs/pendencias-integracao.md "Veiculos modelos"). Vetores podem ser [x,y,z] ou {"x","y","z"}:
{
  "tipos": { "sedan": { "escala", "raio_roda", "folga_roda", "banco_topo", "teto_interno", "olho": [x,y,z], "bancos": [{x,z}], "dimensoes": [x,y,z], "rodas": { "FE": [x,y,z], "FD": ..., "TE": ..., "TD": ... } } },
  "arquivos": [ { "arquivo": "sedan_inteiro.fbx", "tipo": "sedan", "estado": "inteiro" | "queimado",
                  "textura": "sedan.png", "triangulos": 1234,
                  "pecas": { "Carroceria": { "tamanho": [x,y,z], "centro": [x,y,z] } } },
                { "arquivo": "roda.fbx", "tipo": "roda", "textura": "roda.png" } ]
}
("arquivos" também pode ser um objeto {nome_do_arquivo: {...}}.)
enviados.json: {"<arquivo>": {"sha256": "...", "assetId": 123, "tipo": "Model"|"Decal"}}. Sem enviados.json, o Luau sai sem assetId
(o jogo segue em blocos).
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "veiculos"
SAIDA = RAIZ / "src" / "shared" / "Config" / "VeiculosMalhas.luau"
ORDEM_RODAS = ["FE", "FD", "TE", "TD"]


def vetor(v):
    if isinstance(v, dict):
        v = [v.get("x"), v.get("y"), v.get("z")]
    if not isinstance(v, (list, tuple)) or len(v) != 3:
        raise ValueError(f"vetor invalido: {v!r}")
    return [float(c) for c in v]


def luau_vetor(v):
    x, y, z = vetor(v)
    return "{ x = %s, y = %s, z = %s }" % (num(x), num(y), num(z))


def num(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") if x != int(x) else str(int(x))


def carregar(caminho):
    if not caminho.exists():
        return {}
    return json.loads(caminho.read_text(encoding="utf-8"))


def lista_arquivos(manifesto):
    a = manifesto.get("arquivos", [])
    if isinstance(a, dict):
        return [dict(v, arquivo=v.get("arquivo", k)) for k, v in a.items()]
    return a


def entrada(arq, enviados):
    partes = []
    asset = enviados.get(arq.get("arquivo", ""), {}).get("assetId")
    if asset:
        partes.append("modelo = %d" % int(asset))
    tex = arq.get("textura")
    tex_id = enviados.get(tex, {}).get("assetId") if tex else None
    if tex_id:
        partes.append('textura = "rbxassetid://%d"' % int(tex_id))
    # inteiro: 1 textura por cor (cor1..cor4 = Config/Veiculos.tipos[t].cor); `false` onde ainda nao foi enviada (mantem o indice)
    texs = arq.get("texturas")
    if texs:
        ids = [enviados.get(t, {}).get("assetId") for t in texs]
        if any(ids):
            partes.append("texturas = { " + ", ".join('"rbxassetid://%d"' % int(i) if i else "false" for i in ids) + " }")
    pecas = arq.get("pecas") or {}
    if pecas:
        linhas = []
        for nome in sorted(pecas):
            p = pecas[nome]
            linhas.append(
                "\t\t\t\t\t%s = { tamanho = %s, centro = %s }," % (nome, luau_vetor(p["tamanho"]), luau_vetor(p["centro"]))
            )
        partes.append("pecas = {\n" + "\n".join(linhas) + "\n\t\t\t\t}")
    if not partes:
        return "{}"
    sep = "," + chr(10) + chr(9) * 4
    return "{" + chr(10) + chr(9) * 4 + sep.join(partes) + "," + chr(10) + chr(9) * 3 + "}"


def main():
    manifesto = carregar(PASTA / "manifesto.json")
    enviados = carregar(PASTA / "enviados.json")
    tipos = {}
    roda = {}
    for arq in lista_arquivos(manifesto):
        tipo = arq.get("tipo")
        if tipo == "roda":
            roda = entrada(arq, enviados)
            continue
        estado = arq.get("estado")
        if estado not in ("inteiro", "queimado"):
            print("aviso: estado desconhecido em", arq.get("arquivo"), file=sys.stderr)
            continue
        tipos.setdefault(tipo, {})[estado] = entrada(arq, enviados)
    for nome, dados in (manifesto.get("tipos") or {}).items():
        t = tipos.setdefault(nome, {})
        if "dimensoes" in dados:
            t["dimensoes"] = luau_vetor(dados["dimensoes"])
        for chave, campo in (("escala", "escala"), ("raio_roda", "raioRoda"), ("folga_roda", "folgaRoda"), ("banco_topo", "bancoTopo"), ("teto_interno", "tetoInterno")):
            if dados.get(chave) is not None:
                t[campo] = num(float(dados[chave]))
        if "olho" in dados:
            t["olho"] = luau_vetor(dados["olho"])
        if "bancos" in dados:
            t["bancos"] = "{ " + ", ".join("{ x = %s, z = %s }" % (num(b["x"]), num(b["z"])) for b in dados["bancos"]) + " }"
        if "rodas" in dados:
            t["rodas"] = "{ " + ", ".join("%s = %s" % (k, luau_vetor(dados["rodas"][k])) for k in ORDEM_RODAS if k in dados["rodas"]) + " }"

    out = [
        "-- Malhas dos veículos (visual; a física e os alvos continuam em blocos). Contrato: docs/veiculos-modelos.md.",
        "-- GERADO por ferramentas/modelos/gerar_config.py (manifesto.json + enviados.json). Não editar à mão.",
        "-- Sem `modelo` (assetId) o jogo segue em blocos.",
        "return {",
        "\ttipos = {",
    ]
    for nome in sorted(tipos):
        out.append("\t\t%s = {" % nome)
        for campo in ("escala", "inteiro", "queimado", "dimensoes", "raioRoda", "folgaRoda", "bancoTopo", "tetoInterno", "olho", "bancos", "rodas"):
            if campo in tipos[nome]:
                out.append("\t\t\t%s = %s," % (campo, tipos[nome][campo]))
        out.append("\t\t},")
    out.append("\t},")
    out.append("\troda = %s," % (roda or "{}"))
    out.append("}")
    SAIDA.write_text("\n".join(out) + "\n", encoding="utf-8")
    if shutil.which("stylua"):  # o scripts/checar.ps1 confere o formato
        subprocess.run(["stylua", str(SAIDA)], check=False)
    print("escrito", SAIDA, "com", len(tipos), "tipos")


if __name__ == "__main__":
    main()
