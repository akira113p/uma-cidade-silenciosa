"""Converte assets/lanterna/bruto/lanterna_facho.png (disco de luz sujo, gerado no ChatGPT) na máscara de sujeira da lanterna:
PRETO com alfa (o Roblox não tem textura de luz; a máscara é desenhada por cima da tela, centrada no eixo do facho, e escurece
onde há mancha/digital/poeira e na borda irregular do círculo). Centro limpo = alfa 0.
Saída: assets/lanterna/final/lanterna_cookie.png (1024x1024 RGBA). Uso (da raiz): python -I ferramentas/lanterna/processar_facho.py
Parâmetros no topo; `RAIO_DISCO` (fração da largura onde a borda do disco some) vai para Config/Lanterna.cookie.raioImagem."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

RAIZ = Path(__file__).resolve().parents[2]
ENTRADA = RAIZ / "assets" / "lanterna" / "bruto" / "lanterna_facho.png"
SAIDA = RAIZ / "assets" / "lanterna" / "final" / "lanterna_cookie.png"
LADO = 1024
RAIO_DISCO = 0.46  # medido: a luminância cai a ~0 em r = 0.46 da largura
DESBOQUE = 28  # px (da imagem de 1254): tamanho mínimo da mancha para contar como sujeira (o resto é o degradê do disco)
GANHO_SUJEIRA = 2.6  # realce das manchas (v3: 1.7 quase não aparecia no jogo)
ALFA_MAX = 1.0  # opacidade máxima de uma mancha (antes da força da Config)
FIM_SUJEIRA = 0.42  # r/largura em que a sujeira já sumiu (fora disso alfa 0: nada escurece fora da luz)


def main():
    im = Image.open(ENTRADA).convert("L")
    lum = np.asarray(im, dtype=np.float32) / 255.0
    media = np.asarray(im.filter(ImageFilter.GaussianBlur(DESBOQUE)), dtype=np.float32) / 255.0
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - w / 2, yy - h / 2) / w

    # v2 (2026-11-17): SEM borda (a borda preta virava um anel escuro na tela). Só a sujeira de dentro do disco: manchas finas
    # (desfoque pequeno) + manchas largas (desfoque grande, digitais/borrões), sumindo suave antes da borda do disco.
    larga = np.asarray(im.filter(ImageFilter.GaussianBlur(DESBOQUE * 4)), dtype=np.float32) / 255.0
    fina = np.clip((media - lum) / np.maximum(media, 0.08) * GANHO_SUJEIRA, 0, 1)
    grossa = np.clip((larga - media) / np.maximum(larga, 0.08) * GANHO_SUJEIRA, 0, 1)
    alfa = np.clip(fina + grossa * 1.4, 0, 1) * ALFA_MAX
    alfa *= np.clip((FIM_SUJEIRA - r) / 0.10, 0, 1)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 3] = (alfa * 255).astype(np.uint8)
    saida = Image.fromarray(rgba, "RGBA").resize((LADO, LADO), Image.LANCZOS)
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    saida.save(SAIDA, optimize=True)
    a = np.asarray(saida)[..., 3] / 255.0
    print("salvo", SAIDA, saida.size, "alfa médio", round(float(a.mean()), 3), "máx", round(float(a.max()), 3))

    # prévia: fundo cinza-quente com a máscara por cima (não vai para o jogo)
    fundo = np.zeros((LADO, LADO, 3), dtype=np.float32)
    ys, xs = np.mgrid[0:LADO, 0:LADO]
    rr = np.hypot(xs - LADO / 2, ys - LADO / 2) / LADO
    fundo[...] = (np.clip(1 - rr * 1.6, 0.15, 1)[..., None]) * np.array([0.95, 0.9, 0.8])
    prev = fundo * (1 - a[..., None])
    Image.fromarray((prev * 255).astype(np.uint8)).save(SAIDA.with_name("previa_cookie.png"))


if __name__ == "__main__":
    main()
