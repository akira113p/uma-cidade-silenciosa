"""Junta os manifesto_*.json parciais de veiculos_pz.py em modelos 3d/veiculos/manifesto.json (formato lido por gerar_config.py).

Uso: python ferramentas/modelos/montar_manifesto.py   (da raiz do projeto)
"""
import glob
import json
import os

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V = os.path.join(RAIZ, "modelos 3d", "veiculos")
ORDEM = ["sedan", "compacto", "suv", "pickup", "van", "esportivo"]
Y_RODA = 1.0  # so se o tipo nao trouxer folga_roda

saida = {
    "unidades": "studs (1 stud = 0,28 m); eixos do Roblox: x direita, y cima, z = -frente; centro/tamanho no espaco do carro (origem = centro da base)",
    "nota_rodas_y": "y das rodas e estimativa (1 stud); x e z vem de numeros do PZ convertidos para a escala (sedan = 11 studs)",
    "tipos": {},
    "arquivos": [],
}
for f in sorted(glob.glob(os.path.join(V, "manifesto_*.json"))):
    d = json.load(open(f, encoding="utf-8"))
    saida["tipos"].update(d["tipos"])
    saida["arquivos"] += d["arquivos"]
for t in saida["tipos"].values():
    for r in t["rodas"].values():
        r[1] = t.get("folga_roda", Y_RODA)
saida["tipos"] = {k: saida["tipos"][k] for k in ORDEM if k in saida["tipos"]}
rank = {k: i for i, k in enumerate(ORDEM + ["roda"])}
saida["arquivos"].sort(key=lambda a: (rank[a["tipo"]], a.get("estado", "")))
json.dump(saida, open(os.path.join(V, "manifesto.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
for f in glob.glob(os.path.join(V, "manifesto_*.json")):
    os.remove(f)
print("manifesto.json:", len(saida["arquivos"]), "arquivos")
