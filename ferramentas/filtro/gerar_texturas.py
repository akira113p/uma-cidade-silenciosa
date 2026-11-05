#!/usr/bin/env python
"""Gera as texturas do filtro que precisam de propriedade exata (docs/filtro-texturas.md, P1-P4).

Uso: python ferramentas/filtro/gerar_texturas.py [--saida PASTA]
Saída padrão: assets/filtro/final/. Reprodutível (semente fixa).
"""
import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image

# ---------------------------------------------------------------- parâmetros
SEMENTE = 20261102

# P1 grão
GRAO_TAM = 256
GRAO_QUADROS = 4
GRAO_SIGMA = 0.55      # desvio do ruído gaussiano; alfa = |n| normalizado
GRAO_BLOCO = 2         # grão de N px (blocos NxN com o mesmo valor); TAM tem que ser múltiplo
GRAO_ALFA_MEDIO = 0.30 # alfa médio alvo (0..1); calibrado por escala depois do ruído
GRAO_ESPARSO = 0.25    # fração de blocos com alfa zero (grão mais "pontilhado")

# P5 craquelado
CRA_TAM = 1024
CRA_CELULA = 64        # px por célula de Voronoi (CRA_TAM tem que ser múltiplo)
CRA_JITTER = 0.9       # 0..1 quanto os pontos fogem do centro da célula
CRA_ESPESSURA = 0.8    # px da linha (alfa cheio no meio)
CRA_RUIDO_AMP = 5.0    # px de deformação do traçado
CRA_RUIDO_ESCALA = 24  # px: comprimento de onda do ruído do traçado
CRA_ALFA = (0.4, 0.9)  # alfa nas linhas (varia ao longo delas)
CRA_FALHAS = 0.12      # fração de trechos de linha que quase somem

# P6 riscos de filme
RIS_W, RIS_H = 64, 1024
RIS_ESPESSURA = 1.6    # px
RIS_DERIVA = 6.0       # px: amplitude do passeio horizontal do traçado

# P2 vinheta
VIN_TAM = 512
VIN_RAIO_INICIO = 0.30  # r (0 centro, 1 canto) onde o escurecimento começa
VIN_EXPOENTE = 2.2      # curva: alfa = ALFA_CANTO * smoothstep(t) ** EXPOENTE
VIN_ALFA_CANTO = 0.85

# P3 moldura
MOL_TAM = 256
MOL_MARGEM = 16         # px entre a borda da imagem e o retângulo transparente
MOL_RAIO = 48           # raio dos cantos arredondados do retângulo
MOL_FADE = 12           # px de transição preto -> transparente, para dentro
MOL_FRANJA = 3          # px de largura da franja colorida
MOL_FRANJA_FORCA = 0.30 # mistura da cor da franja (bem sutil)
MOL_FRANJA_POS = 5      # px (para dentro) onde a franja começa dentro do fade
# 9-slice: o canto inteiro (margem + raio = 64 px) fica dentro dos cantos fixos
MOL_SLICE = (64, 64, 192, 192)

# P4 halo
HALO_TAM = 256
HALO_SIGMA = 0.28       # sigma gaussiano relativo ao raio da imagem


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def salvar(arr, caminho):
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(caminho, optimize=True)


def grao(rng):
    """Cada pixel é preto OU branco; o alfa é a intensidade. Soma de alfa dos brancos == soma dos pretos,
    então sobre qualquer cinza 50% o brilho médio não muda (efeito linear em (cor - fundo) * alfa)."""
    quadros = []
    g = GRAO_TAM // GRAO_BLOCO  # blocos por lado; cada bloco vira BLOCOxBLOCO px iguais (tileável)
    n = g * g
    for _ in range(GRAO_QUADROS):
        a = np.abs(rng.normal(0, GRAO_SIGMA, n))
        a = np.clip(a / (3 * GRAO_SIGMA), 0, 1)
        a[rng.random(n) < GRAO_ESPARSO] = 0
        k = 1.0  # calibra a escala para o alfa médio alvo (com clip em 1)
        for _i in range(8):
            k *= GRAO_ALFA_MEDIO / max(np.minimum(a * k, 1).mean(), 1e-9)
        a = np.round(np.minimum(a * k, 1) * 255).astype(np.int64)
        # metade exata dos pixels com alfa>0 vira branco, metade preto
        idx = np.flatnonzero(a > 0)
        rng.shuffle(idx)
        meio = len(idx) // 2
        branco = np.zeros(n, bool)
        branco[idx[:meio]] = True
        # iguala a massa de alfa: troca pixels de lado até a diferença ficar mínima
        sb = int(a[branco].sum())
        sp = int(a[~branco & (a > 0)].sum())
        # remove excesso reduzindo alfa do lado maior em passos de 1 em pixels aleatórios
        lado_maior = branco if sb > sp else (~branco & (a > 0))
        excesso = abs(sb - sp)
        cand = np.flatnonzero(lado_maior & (a > 1))
        rng.shuffle(cand)
        i = 0
        while excesso > 0 and i < len(cand):
            a[cand[i]] -= 1
            excesso -= 1
            i += 1
        rgb = np.where(branco, 255, 0).astype(np.uint8)
        img = np.zeros((n, 4), np.uint8)
        img[:, 0] = img[:, 1] = img[:, 2] = rgb
        img[:, 3] = a.astype(np.uint8)
        img = img.reshape(g, g, 4)
        img = np.repeat(np.repeat(img, GRAO_BLOCO, 0), GRAO_BLOCO, 1)
        quadros.append(img)
    return quadros


def ruido_periodico(rng, n, escala):
    """Ruído suave periódico n x n (filtrado no espectro), normalizado para ~[-1, 1]. escala = comprimento de onda px."""
    r = np.fft.fft2(rng.normal(size=(n, n)))
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r *= np.exp(-(fx ** 2 + fy ** 2) / (2 * (0.5 / escala) ** 2))
    out = np.real(np.fft.ifft2(r))
    return out / (np.abs(out).max() + 1e-9)


def craquelado(rng):
    """Voronoi tileável (vizinhança com wrap) com traçado deformado por ruído periódico."""
    n = CRA_TAM
    g = n // CRA_CELULA
    pts = (np.stack(np.meshgrid(np.arange(g), np.arange(g)), -1) + 0.5
           + (rng.random((g, g, 2)) - 0.5) * CRA_JITTER) * CRA_CELULA
    c = np.arange(n) + 0.5
    X, Y = np.meshgrid(c, c)
    X = X + ruido_periodico(rng, n, CRA_RUIDO_ESCALA) * CRA_RUIDO_AMP * 2
    Y = Y + ruido_periodico(rng, n, CRA_RUIDO_ESCALA) * CRA_RUIDO_AMP * 2
    gx = np.floor(X / CRA_CELULA).astype(int)
    gy = np.floor(Y / CRA_CELULA).astype(int)
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            cx, cy = gx + dx, gy + dy
            px = pts[cy % g, cx % g, 0] + (cx // g) * n
            py = pts[cy % g, cx % g, 1] + (cy // g) * n
            d = np.hypot(X - px, Y - py)
            menor = d < d1
            d2 = np.where(menor, d1, np.minimum(d2, d))
            d1 = np.where(menor, d, d1)
    forma = np.clip(1 - (d2 - d1) / (2 * CRA_ESPESSURA), 0, 1) ** 1.5
    var = ruido_periodico(rng, n, 40) * 0.5 + 0.5
    var2 = ruido_periodico(rng, n, 120) * 0.5 + 0.5
    alfa = CRA_ALFA[0] + (CRA_ALFA[1] - CRA_ALFA[0]) * np.clip(var * 0.6 + var2 * 0.4 + 0.1, 0, 1)
    falhas = smooth((ruido_periodico(rng, n, 30) - (1 - 2 * CRA_FALHAS * 1.4)) / 0.15)
    alfa = alfa * (1 - 0.85 * falhas)
    img = np.zeros((n, n, 4), np.uint8)
    img[..., 3] = np.round(np.clip(forma * alfa, 0, 1) * 255)
    return img


def riscos(rng):
    """Um risco vertical irregular, branco, que some nas pontas."""
    w, h = RIS_W, RIS_H
    y = np.arange(h)
    ruido = np.convolve(np.cumsum(rng.normal(size=h)), np.ones(40) / 40, mode="same")
    ruido -= np.linspace(ruido[0], ruido[-1], h)
    cx = w / 2 + ruido / (np.abs(ruido).max() + 1e-9) * RIS_DERIVA
    env = np.sin(np.pi * (y + 0.5) / h) ** 0.6
    var = np.convolve(rng.random(h), np.ones(25) / 25, mode="same")
    var = np.clip(var / var.max(), 0.35, 1)
    d = np.abs((np.arange(w) + 0.5)[None, :] - cx[:, None])
    a = np.clip(1 - d / RIS_ESPESSURA, 0, 1) * (env * var)[:, None]
    img = np.full((h, w, 4), 255, np.uint8)
    img[..., 3] = np.round(np.clip(a, 0, 1) * 255)
    return img


def vinheta():
    n = VIN_TAM
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    r = np.sqrt(x * x + y * y) / math.sqrt(2)  # 1 nos cantos
    t = smooth((r - VIN_RAIO_INICIO) / (1 - VIN_RAIO_INICIO))
    a = VIN_ALFA_CANTO * t ** VIN_EXPOENTE
    img = np.zeros((n, n, 4), np.uint8)
    img[..., 3] = np.round(a * 255)
    return img


def sdf_retangulo_arredondado(n, margem, raio):
    """Distância com sinal (px) ao retângulo [margem, n-margem] com cantos de raio `raio`; negativa dentro."""
    c = np.arange(n) + 0.5
    x, y = np.meshgrid(c, c)
    meio = n / 2
    metade = meio - margem
    qx = np.abs(x - meio) - (metade - raio)
    qy = np.abs(y - meio) - (metade - raio)
    ext = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    intr = np.minimum(np.maximum(qx, qy), 0)
    return ext + intr - raio, x, y


def moldura():
    n = MOL_TAM
    d, x, y = sdf_retangulo_arredondado(n, MOL_MARGEM, MOL_RAIO)
    # alfa 1 fora (d>=0); dentro, cai de 1 para 0 ao longo de MOL_FADE px
    prof = np.clip(-d, 0, None)
    a = 1 - smooth(prof / MOL_FADE)
    a[d >= 0] = 1.0
    # franja: normal horizontal do SDF (gradiente), vermelha à esquerda, ciano à direita
    gy, gx = np.gradient(d)
    norma = np.hypot(gx, gy) + 1e-9
    nx = gx / norma
    banda = smooth((prof - MOL_FRANJA_POS) / 1.5) * (1 - smooth((prof - MOL_FRANJA_POS - MOL_FRANJA) / 1.5))
    banda = np.where(d < 0, banda, 0)
    esq = np.clip(-nx, 0, 1)  # normal aponta para fora; borda esquerda tem nx < 0
    dir_ = np.clip(nx, 0, 1)
    vermelho = np.array([255, 40, 40], float)
    ciano = np.array([40, 230, 255], float)
    w_e = (banda * esq * MOL_FRANJA_FORCA)[..., None]
    w_d = (banda * dir_ * MOL_FRANJA_FORCA)[..., None]
    rgb = vermelho * w_e + ciano * w_d  # sobre preto
    # a franja precisa ser visível mesmo com alfa baixo, então garante alfa mínimo onde há cor
    a = np.maximum(a, np.clip((w_e + w_d)[..., 0] * 0.9, 0, 1))
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255)
    img[..., 3] = np.round(a * 255)
    return img


def halo():
    n = HALO_TAM
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    r = np.hypot(x, y)
    g = np.exp(-(r / HALO_SIGMA) ** 2 / 2)
    e0 = math.exp(-(1 / HALO_SIGMA) ** 2 / 2)
    a = np.clip((g - e0) / (1 - e0), 0, 1)
    a[r >= 1] = 0
    img = np.full((n, n, 4), 255, np.uint8)
    img[..., 3] = np.round(a * 255)
    return img


def main():
    raiz = Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", default=str(raiz / "assets" / "filtro" / "final"))
    args = ap.parse_args()
    saida = Path(args.saida)
    saida.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEMENTE)
    for i, q in enumerate(grao(rng), 1):
        salvar(q, saida / f"grao_{i}.png")
    salvar(vinheta(), saida / "vinheta.png")
    salvar(moldura(), saida / "moldura_vhs.png")
    salvar(halo(), saida / "halo_luz.png")
    salvar(craquelado(rng), saida / "craquelado.png")
    salvar(riscos(rng), saida / "riscos_filme.png")
    print(f"Geradas em {saida}")
    print("SliceCenter da moldura_vhs.png (px, Rect(minX, minY, maxX, maxY)): "
          f"Rect.new{MOL_SLICE}  -> ImageLabel.SliceCenter = Rect.new{MOL_SLICE}, ScaleType = Slice")


if __name__ == "__main__":
    main()
