#!/usr/bin/env python
"""Processa os brutos do ChatGPT (assets/filtro/bruto/) para o contrato de docs/filtro-texturas.md.

Uso:
  python ferramentas/filtro/processar_texturas.py [--entrada PASTA] [--saida PASTA]
  python ferramentas/filtro/processar_texturas.py --verificar [--saida PASTA]   (só mede os finais)

Luminância vira alfa, RGB fica branco (T4 mantém o resíduo de cor). Ausente -> pula com aviso.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# nome -> (tamanho final (L, A), emenda horizontal, borda transparente, preto, branco, gama, manter cor)
# preto/branco: nível de luminância (0..1) que vira alfa 0 e alfa 1; gama < 1 realça os tons fracos.
CONTRATO = {
    # girar: textura de Beam corre na horizontal ao longo do feixe (Attachment0 → Attachment1). "baixo_esquerda" leva a
    # base da mecha (densa) para o começo do feixe (base da coluna); "cima_esquerda" leva a ponta estreita do cone para
    # o começo (lâmpada). Aplicado depois de tudo, na hora de salvar.
    # fade_largura: fração da meia-largura que esmaece até 0 nas laterais do Beam (aplicado depois de girar).
    "neblina_mecha_a": dict(tam=(1024, 1024), emenda=True, borda=None, preto=0.04, branco=0.95, gama=1.0, girar="baixo_esquerda", fade_largura=0.85),
    "neblina_mecha_b": dict(tam=(1024, 1024), emenda=True, borda=None, preto=0.04, branco=0.95, gama=1.0, girar="baixo_esquerda", fade_largura=0.85),
    "neblina_puff": dict(tam=(512, 512), emenda=False, borda="radial", preto=0.04, branco=0.95, gama=1.0),
    "cone_luz": dict(tam=(512, 1024), emenda=False, borda="cone", preto=0.05, branco=0.95, gama=1.0, girar="cima_esquerda"),
    # recortar_banda: o ChatGPT entrega ~3:2 com o ruído numa banda central; corta só as linhas com ruído antes de redimensionar.
    "faixa_tracking": dict(tam=(2048, 128), emenda=True, borda=None, preto=0.03, branco=0.95, gama=1.0, cor=True, recortar_banda=True),
    "poeira_lente": dict(tam=(1920, 1080), emenda=False, borda=None, preto=0.03, branco=0.95, gama=1.0),
}
EXTENSOES = (".png", ".webp", ".jpg", ".jpeg")
EMENDA_FRACAO = 0.15   # largura da mistura cruzada, fração da largura final
BANDA_LIMIAR = 0.02    # luminância média da linha acima da qual ela conta como banda (fundo preto fica < 0.005)
BANDA_MARGEM = 0.15    # margem da banda, fração da altura dela, de cada lado
CONE_TOPO_FADE = 0.03  # o cone nasce forte no topo (lâmpada): só uma rampa curta, ao contrário dos lados e da base
BORDA_FADE = 0.12      # fração do tamanho onde a máscara de borda sobe de 0 a 1 (retângulo) / raio final (radial)
CHAVES_TEXTURAS = None


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def achar(pasta, nome):
    for ext in EXTENSOES:
        p = pasta / (nome + ext)
        if p.exists():
            return p
    return None


def recortar_redimensionar(img, tam, extra_larg=0):
    """Recorte central na proporção do alvo e redimensiona para (L + extra_larg, A)."""
    L, A = tam
    w, h = img.size
    alvo = L / A
    if w / h > alvo:
        nw = round(h * alvo)
        x0 = (w - nw) // 2
        img = img.crop((x0, 0, x0 + nw, h))
    else:
        nh = round(w / alvo)
        y0 = (h - nh) // 2
        img = img.crop((0, y0, w, y0 + nh))
    # com extra_larg, o recorte representa L+extra: mesma altura e escala
    ext = round(L * extra_larg / L) if extra_larg else 0
    return img.resize((L + ext, A), Image.LANCZOS)


def recortar_banda(img, tam):
    """Recorta as linhas com luminância acima do fundo (mais margem), alargadas até a proporção do alvo se a banda for baixa."""
    L, A = tam
    a = np.asarray(img.convert("RGB"), np.float32) / 255
    lin = (a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722).mean(axis=1)
    idx = np.flatnonzero(lin > BANDA_LIMIAR)
    if idx.size == 0:
        return img
    w, h = img.size
    y0, y1 = idx[0], idx[-1] + 1
    marg = round((y1 - y0) * BANDA_MARGEM)
    y0, y1 = y0 - marg, y1 + marg
    falta = round(w * A / L) - (y1 - y0)   # altura que a proporção do alvo pede para não perder largura
    if falta > 0:
        y0, y1 = y0 - falta // 2, y1 + (falta - falta // 2)
    y0, y1 = max(y0, 0), min(y1, h)
    return img.crop((0, y0, w, y1))


def luminancia_para_alfa(img, p):
    rgba = np.asarray(img.convert("RGBA"), np.float32) / 255
    lum = rgba[..., 0] * 0.2126 + rgba[..., 1] * 0.7152 + rgba[..., 2] * 0.0722
    a = np.clip((lum - p["preto"]) / (p["branco"] - p["preto"]), 0, 1) ** p["gama"]
    if rgba[..., 3].min() < 0.999:  # já tem transparência: respeita
        a = np.maximum(a * rgba[..., 3], 0) if lum.max() > 0.02 else rgba[..., 3]
    return a, rgba[..., :3]


def emendar(arr, largura):
    """arr tem largura L + B (B = EMENDA); devolve L colunas sem costura: o início mistura com a sobra do fim."""
    B = arr.shape[1] - largura
    t = smooth(np.arange(B) / max(B - 1, 1)).reshape(1, B, *([1] * (arr.ndim - 2)))
    out = arr[:, :largura].copy()
    # coluna x do início = t*img[x] + (1-t)*img[L+x]; em x=0 vale img[L], vizinha de img[L-1]
    out[:, :B] = t * arr[:, :B] + (1 - t) * arr[:, largura:largura + B]
    return out


def mascara_borda(modo, h, w):
    y = (np.arange(h) + 0.5) / h * 2 - 1
    x = (np.arange(w) + 0.5) / w * 2 - 1
    if modo == "radial":
        xx, yy = np.meshgrid(x, y)
        r = np.hypot(xx, yy)
        m = 1 - smooth((r - (1 - 0.25)) / 0.25)   # começa a sumir a 75% do raio, zero em r=1
        m[r >= 0.98] = 0
        return m
    if modo == "cone":
        mx = smooth((1 - np.abs(x)) / BORDA_FADE)
        my = smooth((1 - y) / BORDA_FADE) * smooth((y + 1) / CONE_TOPO_FADE)   # y=-1 topo, y=+1 base
        m = np.outer(my, mx)
        m[0, :] = m[-1, :] = 0
        m[:, 0] = m[:, -1] = 0
        return m
    if modo == "retangulo":
        fx = BORDA_FADE
        mx = smooth((1 - np.abs(x)) / fx)
        my = smooth((1 - np.abs(y)) / fx)
        m = np.outer(my, mx)
        m[0, :] = m[-1, :] = 0
        m[:, 0] = m[:, -1] = 0
        return m
    return None


def processar(img, p):
    L, A = p["tam"]
    B = round(L * EMENDA_FRACAO) if p["emenda"] else 0
    if p.get("recortar_banda"):
        img = recortar_banda(img, (L, A))
    img = recortar_redimensionar(img, (L, A), 0) if not B else \
        recortar_redimensionar(img, (L + B, A), 0)
    alfa, rgb = luminancia_para_alfa(img, p)
    if B:
        alfa = emendar(alfa, L)
        rgb = emendar(rgb, L)
    m = mascara_borda(p["borda"], A, L)
    if m is not None:
        alfa = alfa * m
    out = np.zeros((A, L, 4), np.uint8)
    if p.get("cor"):
        # resíduo de cor: normaliza pelo brilho para não escurecer; quase neutro mesmo assim
        mx = np.maximum(rgb.max(axis=2, keepdims=True), 1e-3)
        out[..., :3] = np.clip(rgb / mx * 255, 0, 255)
    else:
        out[..., :3] = 255
    out[..., 3] = np.round(alfa * 255)
    return Image.fromarray(out, "RGBA")


def medir(caminho, tileavel, girado=False):
    a = np.asarray(Image.open(caminho).convert("RGBA"))
    al = a[..., 3].astype(np.float32) / 255
    if girado:  # a emenda do bruto (horizontal) virou vertical: gira de volta só para medir
        al = al.T
    bordas = np.concatenate([al[0], al[-1], al[:, 0], al[:, -1]])
    s = f"{caminho.name}: {a.shape[1]}x{a.shape[0]}  alfa medio={al.mean():.3f}  alfa max={al.max():.2f}  borda max={bordas.max():.3f}"
    if tileavel:
        s += f"  dif esq-dir (coluna a coluna)={np.abs(al[:, 0] - al[:, -1]).mean():.4f}  (ref. colunas vizinhas={np.abs(al[:, 1:] - al[:, :-1]).mean():.4f})"
    return s


def main():
    raiz = Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser()
    ap.add_argument("--entrada", default=str(raiz / "assets" / "filtro" / "bruto"))
    ap.add_argument("--saida", default=str(raiz / "assets" / "filtro" / "final"))
    ap.add_argument("--verificar", action="store_true", help="só mede os arquivos finais")
    args = ap.parse_args()
    ent, sai = Path(args.entrada), Path(args.saida)
    if args.verificar:
        for nome, p in CONTRATO.items():
            c = sai / (nome + ".png")
            print(medir(c, p["emenda"], bool(p.get("girar"))) if c.exists() else f"{nome}.png: ausente")
        return
    sai.mkdir(parents=True, exist_ok=True)
    feitos = 0
    for nome, p in CONTRATO.items():
        origem = achar(ent, nome)
        if not origem:
            print(f"AVISO: bruto '{nome}' ausente em {ent}, pulando", file=sys.stderr)
            continue
        out = processar(Image.open(origem), p)
        if p.get("girar") == "baixo_esquerda":
            out = out.transpose(Image.Transpose.ROTATE_270)  # horário: baixo → esquerda
        elif p.get("girar") == "cima_esquerda":
            out = out.transpose(Image.Transpose.ROTATE_90)  # anti-horário: cima → esquerda
        if p.get("fade_largura"):
            # Depois de girar, as linhas da imagem são a largura do Beam: sem isto a coluna vira placa de laterais duras.
            arr = np.asarray(out).astype(np.float32)
            n = arr.shape[0]
            v = np.abs(np.linspace(-1.0, 1.0, n))
            perfil = smooth(np.clip((1.0 - v) / p["fade_largura"], 0.0, 1.0))
            arr[..., 3] *= perfil[:, None]
            out = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
        destino = sai / (nome + ".png")
        out.save(destino, optimize=True)
        print("ok  " + medir(destino, p["emenda"], bool(p.get("girar"))))
        feitos += 1
    print(f"{feitos}/{len(CONTRATO)} processados")


if __name__ == "__main__":
    main()
