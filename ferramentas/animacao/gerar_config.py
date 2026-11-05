"""Gera src/shared/Config/ArmasAnim.luau a partir de assets/animacoes/armas/*.json (duracao, marcadores, ik, mao.json) e
ferramentas/animacao/enviados.json (ids das Animation enviadas pela Open Cloud, ver enviar_animacoes.py).
Clipe sem id enviado fica com false (o jogo segue sem aquela animacao). Uso (da raiz):  python ferramentas/animacao/gerar_config.py
"""

import json
import subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
JSONS = RAIZ / "assets" / "animacoes" / "armas"
ENVIADOS = RAIZ / "ferramentas" / "animacao" / "enviados.json"
SAIDA = RAIZ / "src" / "shared" / "Config" / "ArmasAnim.luau"


def num(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") if x != int(x) else str(int(x))


def cframe(v):
    rx, ry, rz, px, py, pz = (list(v) + [0] * 6)[:6]
    return "CFrame.new(%s, %s, %s) * CFrame.fromEulerAnglesYXZ(math.rad(%s), math.rad(%s), math.rad(%s))" % (
        num(px), num(py), num(pz), num(rx), num(ry), num(rz))


def main():
    enviados = json.loads(ENVIADOS.read_text(encoding="utf-8")) if ENVIADOS.exists() else {}
    mao = json.loads((JSONS / "mao.json").read_text(encoding="utf-8"))
    classes = {}
    for arq in sorted(JSONS.glob("*.json")):
        if arq.name == "mao.json":
            continue
        d = json.loads(arq.read_text(encoding="utf-8"))
        classes[d["classe"]] = d
    L = [
        "-- GERADO por ferramentas/animacao/gerar_config.py (assets/animacoes/armas/*.json + ferramentas/animacao/enviados.json).",
        "-- Nao editar a mao: mude o JSON e rode o gerador. Contrato: docs/armas.md §9 (animacao do corpo, 3a pessoa).",
        "-- animacoes[classe][clipe] = id da Animation (false = ainda nao enviada: o clipe nao toca). duracao = duracao NATIVA do clipe (s);",
        "-- ArmasTerceira ajusta a velocidade (AdjustSpeed) para casar com Config/Armas (recarga.tempo, cadencia).",
        "-- mao.C0 = CFrame do Motor6D RightHand -> Cabo da arma (palma segura o Cabo); porClasse sobrepoe por classe.",
        "return {",
        "\tmao = {",
        "\t\tC0 = " + cframe(mao["C0"]) + ",",
        "\t\tporClasse = {",
    ]
    for c in sorted(mao["porClasse"]):
        L.append("\t\t\t%s = %s," % (c, cframe(mao["porClasse"][c])))
    L += ["\t\t},", "\t},", "\tanimacoes = {"]
    for c, d in classes.items():
        L.append("\t\t%s = {" % c)
        for nome in sorted(d["clipes"]):
            chave = "%s_%s.rbxm" % (c, nome)
            aid = enviados.get(chave, {}).get("assetId")
            L.append("\t\t\t%s = %s," % (nome, ('"rbxassetid://%d"' % aid) if aid else "false"))
        L.append("\t\t},")
    L += ["\t},", "\tduracao = {"]
    for c, d in classes.items():
        L.append("\t\t%s = {" % c)
        for nome in sorted(d["clipes"]):
            L.append("\t\t\t%s = %s," % (nome, num(d["clipes"][nome]["duracao"])))
        L.append("\t\t},")
    L += ["\t},", "\t-- instante (s, na velocidade nativa) do marcador \"Impacto\" dos golpes; tem de bater com Config/Armas.atrasoImpacto", "\timpacto = {"]
    for c, d in classes.items():
        itens = []
        for nome, cl in sorted(d["clipes"].items()):
            for q in cl["quadros"]:
                if "Impacto" in q.get("marcadores", []):
                    itens.append("%s = %s" % (nome, num(q["t"])))
        if itens:
            L.append("\t\t%s = { %s }," % (c, ", ".join(itens)))
    L += ["\t},", "\t-- mao esquerda por IKControl: clipes em que o IK fica desligado (a mao anima) e janelas (s) dentro do clipe", "\tik = {"]
    for c, d in classes.items():
        ik = d.get("ik")
        if not ik:
            continue
        desl = ", ".join("%s = true" % n for n in ik.get("desligar", []))
        jan = ", ".join("%s = { %s, %s }" % (n, num(v[0]), num(v[1])) for n, v in sorted(ik.get("janelas", {}).items()))
        L.append("\t\t%s = { desligar = { %s }, janelas = { %s } }," % (c, desl, jan))
    L += [
        "\t},",
        "\t-- camada de mira (pitch da camera): fracao do angulo que cada junta leva e limites, em graus",
        "\tmira = {",
        "\t\talcance = 150, -- studs: so personagens ate esta distancia da camera recebem a mira",
        "\t\thz = 8, -- envio do evento Mira",
        "\t\tcintura = 0.35,",
        "\t\tpescoco = 0.65,",
        "\t\tombros = 0.65, -- so em arma de fogo (duas maos: os dois ombros; uma mao: so o direito)",
        "\t\tmaxCintura = 30,",
        "\t\tmaxPescoco = 50,",
        "\t\tmaxOmbro = 55,",
        "\t\tsuavizar = 12, -- 1/s, para o pitch replicado dos outros jogadores",
        "\t},",
        "}",
    ]
    SAIDA.write_text("\n".join(L) + "\n", encoding="utf-8")
    try:
        subprocess.run(["stylua", str(SAIDA)], check=False)
    except FileNotFoundError:
        pass
    vazios = sum(1 for c, d in classes.items() for n in d["clipes"] if not enviados.get("%s_%s.rbxm" % (c, n), {}).get("assetId"))
    print("gravado", SAIDA, "| clipes sem id:", vazios)


if __name__ == "__main__":
    main()
