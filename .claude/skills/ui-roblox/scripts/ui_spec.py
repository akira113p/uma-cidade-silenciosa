"""
ui_spec.py - uma spec JSON de UI gera três coisas que não podem discordar entre si:
  1. <saida>/<Nome>.luau        ModuleScript que constrói a ScreenGui (via Rojo: src/client/UI/)
  2. <saida>/<Nome>_preview.png  preview nas 4 telas
  3. relatório de checagens (stdout + <saida>/<Nome>_relatorio.json); sai com 1 se houver FALHA

  python .claude/skills/ui-roblox/scripts/ui_spec.py ui/specs/HudPrincipal.json --saida src/client/UI

Formato da spec: ver ../references/formato-spec.md. Requer Pillow.
"""
import argparse
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

TELAS_PADRAO = [("celular pequeno", 667, 375), ("celular grande", 896, 414), ("tablet", 1024, 768), ("PC full HD", 1920, 1080)]
TEMA_PADRAO = {
    "contorno": 3, "canto": 12, "sombra": [0, 5], "corSombra": "#1b2140", "corContorno": "#14142a",
    "fonte": "FredokaOne", "textoMin": 14, "toqueMin": 44, "corTexto": "#ffffff", "insetTopo": 58,
    "gradiente": 0.82,
}
BOTOES = {"TextButton", "ImageButton"}
TEXTOS = {"TextLabel", "TextButton"}
IMAGENS = {"ImageLabel", "ImageButton"}
TIPOS = {"Frame"} | BOTOES | TEXTOS | IMAGENS
EMOJI = re.compile("[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F000-\U0001F2FF\U0000FE0F]")


# ---------- layout ----------

def udim2(v, padrao=(0, 0, 0, 0)):
    v = v if v is not None else padrao
    if len(v) != 4:
        raise ValueError(f"UDim2 precisa de 4 números [xEscala, xOffset, yEscala, yOffset]: {v}")
    return v


def calcular(no, px, py, pw, ph, saida, caminho=""):
    sxs, sxo, sys_, syo = udim2(no.get("tam"), (1, 0, 1, 0))
    pxs, pxo, pys, pyo = udim2(no.get("pos"))
    ax, ay = no.get("ancora", [0, 0])
    w, h = sxs * pw + sxo, sys_ * ph + syo
    if "tamMin" in no:  # UISizeConstraint.MinSize
        w, h = max(w, no["tamMin"][0]), max(h, no["tamMin"][1])
    if "tamMax" in no:  # UISizeConstraint.MaxSize
        w, h = min(w, no["tamMax"][0]), min(h, no["tamMax"][1])
    if "proporcao" in no:  # UIAspectRatioConstraint (FitWithinMaxSize): maior caixa com w/h = proporcao
        r = no["proporcao"]
        w = min(w, h * r)
        h = w / r
    x = px + pxs * pw + pxo - ax * w
    y = py + pys * ph + pyo - ay * h
    nome = f"{caminho}/{no['nome']}"
    saida.append({"no": no, "nome": nome, "x": x, "y": y, "w": w, "h": h, "pai": (px, py, pw, ph)})
    for f in no.get("filhos", []):
        calcular(f, x, y, w, h, saida, nome)
    return saida


# ---------- checagens ----------

def checar(spec, tema, telas):
    problemas = []

    def add(nivel, regra, tela, nome, msg):
        problemas.append({"nivel": nivel, "regra": regra, "tela": tela, "elemento": nome, "msg": msg})

    def estatico(no, caminho=""):
        nome = f"{caminho}/{no['nome']}"
        tipo = no.get("tipo")
        if tipo not in TIPOS:
            add("FALHA", "TIPO", "-", nome, f"tipo '{tipo}' não suportado ({sorted(TIPOS)})")
        if EMOJI.search(no.get("texto", "")):
            add("FALHA", "EMOJI", "-", nome, "emoji no texto: usar ícone (ImageLabel) gerado, não emoji")
        if "contorno" in no and no["contorno"] != tema["contorno"]:
            add("FALHA", "CONTORNO", "-", nome, f"contorno {no['contorno']} ≠ tema {tema['contorno']}: espessura única em toda a UI")
        filhos = no.get("filhos", [])
        if (tipo == "Frame" and no.get("cor") and not no.get("profundidade") and len(filhos) == 1
                and filhos[0].get("tipo") in BOTOES):
            add("FALHA", "CAIXA_BOTAO", "-", nome, "Frame com fundo visível só para embrulhar um botão: caixa sobrando em volta do botão")
        if tipo in TEXTOS and no.get("textoTam", 0) < tema["textoMin"] and not no.get("textoAuto"):
            add("FALHA", "TEXTO_MIN", "-", nome, f"textoTam {no.get('textoTam')} < {tema['textoMin']}")
        nomes = [f["nome"] for f in filhos]
        for n in {n for n in nomes if nomes.count(n) > 1}:
            add("FALHA", "NOME_DUPLICADO", "-", nome, f"dois filhos chamados '{n}'")
        for f in filhos:
            estatico(f, nome)

    estatico(spec["raiz"])

    for rotulo, tw, th in telas:
        topo = tema["insetTopo"]
        caixas = calcular(spec["raiz"], 0, topo, tw, th - topo, [])
        por_nome = {c["nome"]: c for c in caixas}
        for c in caixas:
            no, nome = c["no"], c["nome"]
            tipo = no.get("tipo")
            if c["w"] <= 0 or c["h"] <= 0:
                add("FALHA", "TAMANHO", rotulo, nome, f"tamanho {c['w']:.0f}x{c['h']:.0f}")
                continue
            if tipo in BOTOES and (c["w"] < tema["toqueMin"] or c["h"] < tema["toqueMin"]):
                add("FALHA", "TOQUE", rotulo, nome, f"{c['w']:.0f}x{c['h']:.0f}px < {tema['toqueMin']}px (alvo de dedo)")
            if no.get("textoAuto") and tipo in TEXTOS and c["h"] * 0.7 < tema["textoMin"]:
                add("FALHA", "TEXTO_MIN", rotulo, nome, f"texto automático fica ~{c['h'] * 0.7:.0f}px")
            if tipo in TEXTOS and no.get("texto") and not no.get("textoAuto"):
                largura = len(no["texto"]) * no.get("textoTam", 14) * 0.55 + 16
                if largura > c["w"]:
                    add("AVISO", "TEXTO_CABE", rotulo, nome, f"texto estimado em {largura:.0f}px numa caixa de {c['w']:.0f}px")
            px, py, pw, ph = c["pai"]
            if not no.get("vazar"):
                folga = 0.5
                if c["x"] < px - folga or c["y"] < py - folga or c["x"] + c["w"] > px + pw + folga or c["y"] + c["h"] > py + ph + folga:
                    add("FALHA", "FORA", rotulo, nome, "sai da área do pai/tela (marque \"vazar\": true se for intencional)")
            centro = no.get("centro")
            if centro:
                dx = abs((c["x"] + c["w"] / 2) - (px + pw / 2))
                dy = abs((c["y"] + c["h"] / 2) - (py + ph / 2))
                if centro in (True, "x") and dx > 1.5:
                    add("FALHA", "CENTRO", rotulo, nome, f"desvio horizontal {dx:.1f}px > 1,5px")
                if centro in (True, "y") and dy > 1.5:
                    add("FALHA", "CENTRO", rotulo, nome, f"desvio vertical {dy:.1f}px > 1,5px")
        if (rotulo, tw, th) == max(telas, key=lambda t: t[1] * t[2]):
            for c in caixas:
                no = c["no"]
                sxs, _, sys_, _ = udim2(no.get("tam"), (1, 0, 1, 0))
                fixo = sxs == 0 and sys_ == 0 and "proporcao" not in no
                if fixo and no.get("tipo") in BOTOES | TEXTOS | {"Frame"} and no.get("cor") and c["h"] < th * 0.06:
                    add("AVISO", "TAMANHO_FIXO", rotulo, c["nome"],
                        f"{c['h']:.0f}px de altura numa tela de {th}px: tamanho só em offset não cresce; use escala + tamMin/tamMax")
        # sobreposição entre irmãos
        for c in caixas:
            filhos = [por_nome[f"{c['nome']}/{f['nome']}"] for f in c["no"].get("filhos", []) if f"{c['nome']}/{f['nome']}" in por_nome]
            for i, a in enumerate(filhos):
                for b in filhos[i + 1:]:
                    if a["no"].get("sobrepor") or b["no"].get("sobrepor"):
                        continue
                    ix = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
                    iy = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
                    if ix > 0.5 and iy > 0.5:
                        add("FALHA", "SOBREPOSICAO", rotulo, a["nome"], f"encosta/sobrepõe {b['nome']} ({ix:.0f}x{iy:.0f}px)")
    return problemas


# ---------- preview ----------

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fonte(tam):
    for nome in ("arialbd.ttf", "DejaVuSans-Bold.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(nome, max(6, int(tam)))
        except OSError:
            continue
    return ImageFont.load_default()


def desenhar_tela(spec, tema, tw, th, falhos):
    img = Image.new("RGB", (tw, th))
    d = ImageDraw.Draw(img)
    for yy in range(th):  # "mundo" atrás da UI, para julgar contraste
        t = yy / th
        d.line([(0, yy), (tw, yy)], fill=(int(110 + 40 * t), int(150 + 30 * t), int(190 - 50 * t)))
    d.rectangle([0, 0, tw, tema["insetTopo"]], fill=(30, 30, 30))
    caixas = calcular(spec["raiz"], 0, tema["insetTopo"], tw, th - tema["insetTopo"], [])
    canto, contorno = tema["canto"], tema["contorno"]
    sx, sy = tema["sombra"]
    for c in caixas:
        no = c["no"]
        x0, y0, x1, y1 = c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]
        if x1 <= x0 or y1 <= y0:
            continue
        r = min(canto, c["w"] / 2, c["h"] / 2) if no.get("profundidade") else 0
        if no.get("cor"):
            base = hex_rgb(no["cor"])
            if no.get("profundidade"):
                d.rounded_rectangle([x0 + sx, y0 + sy, x1 + sx, y1 + sy], r, fill=hex_rgb(tema["corSombra"]))
                faixa = Image.new("RGB", (max(1, int(c["w"])), max(1, int(c["h"]))))
                fd = ImageDraw.Draw(faixa)
                for yy in range(faixa.height):
                    k = 1 - (1 - tema["gradiente"]) * (yy / max(1, faixa.height - 1))
                    fd.line([(0, yy), (faixa.width, yy)], fill=tuple(int(v * k) for v in base))
                mascara = Image.new("L", faixa.size, 0)
                ImageDraw.Draw(mascara).rounded_rectangle([0, 0, faixa.width - 1, faixa.height - 1], r, fill=255)
                img.paste(faixa, (int(x0), int(y0)), mascara)
                d.rounded_rectangle([x0, y0, x1, y1], r, outline=hex_rgb(tema["corContorno"]), width=contorno)
            else:
                d.rectangle([x0, y0, x1, y1], fill=base)
        if no.get("tipo") in IMAGENS:
            d.rectangle([x0, y0, x1, y1], outline=(255, 255, 255), width=1)
            d.line([x0, y0, x1, y1], fill=(255, 255, 255))
            d.line([x0, y1, x1, y0], fill=(255, 255, 255))
        if no.get("texto"):
            tam = c["h"] * 0.7 if no.get("textoAuto") else no.get("textoTam", 14)
            f = fonte(tam)
            cor = hex_rgb(no.get("corTexto", tema["corTexto"]))
            alinhar = no.get("alinhar", "centro")
            bx = d.textbbox((0, 0), no["texto"], font=f)
            tw_, th_ = bx[2] - bx[0], bx[3] - bx[1]
            tx = x0 + 8 if alinhar == "esquerda" else (x1 - 8 - tw_ if alinhar == "direita" else (x0 + x1 - tw_) / 2)
            ty = (y0 + y1 - th_) / 2 - bx[1]
            d.text((tx, ty), no["texto"], font=f, fill=cor, stroke_width=1, stroke_fill=(20, 20, 40))
        if c["nome"] in falhos:
            d.rectangle([x0, y0, x1, y1], outline=(255, 0, 0), width=3)
    return img


def preview(spec, tema, telas, problemas, caminho):
    celula_w = 760
    quadros = []
    for rotulo, tw, th in telas:
        falhos = {p["elemento"] for p in problemas if p["nivel"] == "FALHA" and p["tela"] in (rotulo, "-")}
        img = desenhar_tela(spec, tema, tw, th, falhos)
        k = celula_w / tw
        img = img.resize((celula_w, int(th * k)), Image.LANCZOS)
        quadros.append((f"{rotulo} {tw}x{th}", img))
    colunas = 2
    linhas = math.ceil(len(quadros) / colunas)
    alt = max(q[1].height for q in quadros) + 30
    folha = Image.new("RGB", (celula_w * colunas + 30, alt * linhas + 10), (24, 24, 28))
    d = ImageDraw.Draw(folha)
    for i, (rot, img) in enumerate(quadros):
        x, y = 10 + (i % colunas) * (celula_w + 10), 10 + (i // colunas) * alt
        d.text((x, y), rot, fill=(230, 230, 230), font=fonte(16))
        folha.paste(img, (x, y + 22))
    folha.save(caminho)


# ---------- Luau ----------

def lua_str(s):
    return json.dumps(s, ensure_ascii=False)


def udim2_lua(xs, xo, ys, yo):
    # selene (roblox_manual_fromscale_or_fromoffset) reclama de UDim2.new só com escala ou só com offset.
    if xo == 0 and yo == 0:
        return f"UDim2.fromScale({xs}, {ys})"
    if xs == 0 and ys == 0:
        return f"UDim2.fromOffset({xo}, {yo})"
    return f"UDim2.new({xs}, {xo}, {ys}, {yo})"


def gerar_luau(spec, tema, origem):
    nome_tela = spec["nome"]
    L = [
        "--!strict",
        f"-- GERADO por ui_spec.py a partir de {origem}. Não editar à mão: edite a spec e gere de novo.",
        "",
        "local Construir = {}",
        "",
        "local function profundidade(alvo: GuiObject)",
        f"\tlocal canto = Instance.new(\"UICorner\")",
        f"\tcanto.CornerRadius = UDim.new(0, {tema['canto']})",
        "\tcanto.Parent = alvo",
        "\tlocal contorno = Instance.new(\"UIStroke\")",
        f"\tcontorno.Thickness = {tema['contorno']}",
        f"\tcontorno.Color = Color3.fromHex({lua_str(tema['corContorno'].lstrip('#'))})",
        "\tcontorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border",
        "\tcontorno.Parent = alvo",
        "\tlocal gradiente = Instance.new(\"UIGradient\")",
        f"\tgradiente.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new({tema['gradiente']}, {tema['gradiente']}, {tema['gradiente']}))",
        "\tgradiente.Rotation = 90",
        "\tgradiente.Parent = alvo",
        "end",
        "",
        "local function sombra(alvo: GuiObject)",
        "\tlocal s = Instance.new(\"Frame\")",
        "\ts.Name = alvo.Name .. \"_Sombra\"",
        "\ts.Size = alvo.Size",
        f"\ts.Position = alvo.Position + UDim2.fromOffset({tema['sombra'][0]}, {tema['sombra'][1]})",
        "\ts.AnchorPoint = alvo.AnchorPoint",
        f"\ts.BackgroundColor3 = Color3.fromHex({lua_str(tema['corSombra'].lstrip('#'))})",
        "\ts.BorderSizePixel = 0",
        "\ts.ZIndex = alvo.ZIndex - 1",
        "\tfor _, filho in alvo:GetChildren() do",
        "\t\tif filho:IsA(\"UISizeConstraint\") or filho:IsA(\"UIAspectRatioConstraint\") then",
        "\t\t\tfilho:Clone().Parent = s",
        "\t\tend",
        "\tend",
        "\tlocal canto = Instance.new(\"UICorner\")",
        f"\tcanto.CornerRadius = UDim.new(0, {tema['canto']})",
        "\tcanto.Parent = s",
        "\ts.Parent = alvo.Parent",
        "end",
        "",
        "function Construir.criar(pai: Instance): ScreenGui",
        "\tlocal tela = Instance.new(\"ScreenGui\")",
        f"\ttela.Name = {lua_str(nome_tela)}",
        "\ttela.ResetOnSpawn = false",
        "\ttela.ZIndexBehavior = Enum.ZIndexBehavior.Sibling",
        "\ttela.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets",
    ]
    contador = [0]

    def emitir(no, pai_var):
        contador[0] += 1
        v = f"e{contador[0]}"
        tipo = no["tipo"]
        L.append(f"\tlocal {v} = Instance.new({lua_str(tipo)})")
        L.append(f"\t{v}.Name = {lua_str(no['nome'])}")
        sxs, sxo, sys_, syo = udim2(no.get("tam"), (1, 0, 1, 0))
        L.append(f"\t{v}.Size = {udim2_lua(sxs, sxo, sys_, syo)}")
        pxs, pxo, pys, pyo = udim2(no.get("pos"))
        L.append(f"\t{v}.Position = {udim2_lua(pxs, pxo, pys, pyo)}")
        ax, ay = no.get("ancora", [0, 0])
        L.append(f"\t{v}.AnchorPoint = Vector2.new({ax}, {ay})")
        L.append(f"\t{v}.BorderSizePixel = 0")
        if no.get("cor"):
            L.append(f"\t{v}.BackgroundColor3 = Color3.fromHex({lua_str(no['cor'].lstrip('#'))})")
            L.append(f"\t{v}.BackgroundTransparency = {no.get('transparencia', 0)}")
        else:
            L.append(f"\t{v}.BackgroundTransparency = 1")
        if no.get("profundidade"):
            L.append(f"\t{v}.ZIndex = 2")
        if tipo in TEXTOS:
            L.append(f"\t{v}.Text = {lua_str(no.get('texto', ''))}")
            L.append(f"\t{v}.FontFace = Font.fromEnum(Enum.Font.{no.get('fonte', tema['fonte'])})")
            L.append(f"\t{v}.TextColor3 = Color3.fromHex({lua_str(no.get('corTexto', tema['corTexto']).lstrip('#'))})")
            L.append(f"\t{v}.TextStrokeTransparency = 0.4")
            if no.get("textoAuto"):
                L.append(f"\t{v}.TextScaled = true")
            else:
                L.append(f"\t{v}.TextSize = {no.get('textoTam', 14)}")
            alinhar = {"esquerda": "Left", "direita": "Right"}.get(no.get("alinhar"), "Center")
            L.append(f"\t{v}.TextXAlignment = Enum.TextXAlignment.{alinhar}")
        if tipo in IMAGENS:
            L.append(f"\t{v}.Image = {lua_str(no.get('imagem', ''))}")
            L.append(f"\t{v}.ScaleType = Enum.ScaleType.Fit")
        if tipo in BOTOES:
            L.append(f"\t{v}.AutoButtonColor = true")
        if "tamMin" in no or "tamMax" in no:
            mn = no.get("tamMin", [0, 0])
            mx = no.get("tamMax", ["math.huge", "math.huge"])
            L.append(f"\tlocal {v}_lim = Instance.new(\"UISizeConstraint\")")
            L.append(f"\t{v}_lim.MinSize = Vector2.new({mn[0]}, {mn[1]})")
            L.append(f"\t{v}_lim.MaxSize = Vector2.new({mx[0]}, {mx[1]})")
            L.append(f"\t{v}_lim.Parent = {v}")
        if "proporcao" in no:
            L.append(f"\tlocal {v}_prop = Instance.new(\"UIAspectRatioConstraint\")")
            L.append(f"\t{v}_prop.AspectRatio = {no['proporcao']}")
            L.append(f"\t{v}_prop.Parent = {v}")
        L.append(f"\t{v}.Parent = {pai_var}")
        if no.get("profundidade"):
            L.append(f"\tprofundidade({v})")
            L.append(f"\tsombra({v})")
        for f in no.get("filhos", []):
            emitir(f, v)

    emitir(spec["raiz"], "tela")
    L += ["\ttela.Parent = pai", "\treturn tela", "end", "", "return Construir", ""]
    return "\n".join(L)


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # console do Windows é cp1252 e quebra com ≠, ç, emoji
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("spec")
    p.add_argument("--saida", required=True, help="pasta do .luau (ex.: src/client/UI)")
    p.add_argument("--preview", help="pasta do preview/relatório (padrão: a mesma de --saida)")
    a = p.parse_args()
    with open(a.spec, encoding="utf-8") as f:
        spec = json.load(f)
    tema = {**TEMA_PADRAO, **spec.get("tema", {})}
    telas = [tuple(t) for t in spec.get("telas", [])] or TELAS_PADRAO
    nome = spec["nome"]
    os.makedirs(a.saida, exist_ok=True)
    pasta_prev = a.preview or a.saida
    os.makedirs(pasta_prev, exist_ok=True)

    problemas = checar(spec, tema, telas)
    falhas = [p for p in problemas if p["nivel"] == "FALHA"]
    preview(spec, tema, telas, problemas, os.path.join(pasta_prev, f"{nome}_preview.png"))
    with open(os.path.join(pasta_prev, f"{nome}_relatorio.json"), "w", encoding="utf-8") as f:
        json.dump(problemas, f, ensure_ascii=False, indent=2)
    if not falhas:
        with open(os.path.join(a.saida, f"{nome}.luau"), "w", encoding="utf-8", newline="\n") as f:
            f.write(gerar_luau(spec, tema, os.path.basename(a.spec)))

    for pr in problemas:
        print(f"{pr['nivel']:5} {pr['regra']:14} {pr['tela']:16} {pr['elemento']}: {pr['msg']}")
    print(f"{nome}: {len(falhas)} falha(s), {len(problemas) - len(falhas)} aviso(s). "
          + ("Luau NÃO gerado." if falhas else f"Luau em {os.path.join(a.saida, nome + '.luau')}"))
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
