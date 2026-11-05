"""Gera src/shared/Config/MonstrosMalhas.luau a partir de modelos 3d/rastejador/{manifesto,enviados}.json.

Uso (da raiz):  python ferramentas/modelos/gerar_config_monstros.py
Medido (docs/rastejador.md Estado): o Roblox importa o FBX 1:1 (1 unidade = 1 stud); as dimensoes saem em studs.
enviados.json: Model = assetId do modelo; textura: o assetId devolvido e de um Decal, o MeshPart precisa da imagem
(InsertService:LoadAsset(decal) -> Decal.Texture); o id da imagem fica em "imagemId" (editado a mao depois da conversao).
"""

import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "rastejador"
SAIDA = RAIZ / "src" / "shared" / "Config" / "MonstrosMalhas.luau"
ACOES = ["Idle", "Walk", "Run", "Attack", "Death"]


def n(x):
    return ("%.4f" % x).rstrip("0").rstrip(".")


def main():
    man = json.loads((PASTA / "manifesto.json").read_text(encoding="utf-8"))
    env = json.loads((PASTA / "enviados.json").read_text(encoding="utf-8"))
    s = man["escala_blender_para_fbx"]
    dim = [v * s for v in man["dimensoes_blend"]["tamanho"]]  # x largura, y comprimento (Blender) , z altura
    cmn, cmx = man["corpo_blend"]["min"], man["corpo_blend"]["max"]
    zc = (man["dimensoes_blend"]["min"][2] + man["dimensoes_blend"]["max"][2]) / 2
    # caixa do corpo no espaco do MeshPart (x' = -x, y' = z - zc, z' = y), em studs; centro relativo ao MeshPart
    corpo_tam = [(cmx[0] - cmn[0]) * s, (cmx[2] - cmn[2]) * s, (cmx[1] - cmn[1]) * s]
    corpo_centro = [-(cmx[0] + cmn[0]) / 2 * s, ((cmx[2] + cmn[2]) / 2 - zc) * s, (cmx[1] + cmn[1]) / 2 * s]
    chao_corpo = (cmn[2]) * s  # fundo do corpo acima do chao
    linhas = ["-- GERADO por ferramentas/modelos/gerar_config_monstros.py. Nao editar a mao.", "", "return {", "\tRastejador = {"]
    mod = env.get(man["arquivo"], {}).get("assetId")
    tex = env.get(man["textura"], {}).get("imagemId")
    if mod:
        linhas.append("\t\tmodelo = %d," % mod)
    if tex:
        linhas.append('\t\ttextura = "rbxassetid://%d",' % tex)
    linhas.append("\t\tdimensoes = { x = %s, y = %s, z = %s }, -- studs, no repouso (largura, altura, comprimento)" % (n(dim[0]), n(dim[2]), n(dim[1])))
    linhas.append("\t\tcorpo = { x = %s, y = %s, z = %s }, -- caixa de colisao (cabeca + tronco)" % tuple(n(v) for v in corpo_tam))
    linhas.append("\t\tcorpoCentro = { x = %s, y = %s, z = %s }, -- relativo ao centro do MeshPart" % tuple(n(v) for v in corpo_centro))
    linhas.append("\t\tfundoDoCorpo = %s, -- studs do chao ate o fundo do corpo (HipHeight)" % n(chao_corpo))
    linhas.append("\t\tanimacoes = {")
    for a in ACOES:
        i = env.get("anim/Rastejador_%s.rbxm" % a, {}).get("assetId")
        if i:
            linhas.append('\t\t\t%s = "rbxassetid://%d",' % (a, i))
    linhas.append("\t\t},")
    linhas.append("\t\tduracao = { " + ", ".join("%s = %s" % (a, n(man["acoes"][a]["quadros"] - 1) if False else n((man["acoes"][a]["quadros"] - 1) / man["acoes"][a]["fps"])) for a in ACOES if a in man["acoes"]) + " }, -- s")
    linhas.append("\t},")
    linhas.append("}")
    SAIDA.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print(SAIDA)


if __name__ == "__main__":
    main()
