"""Reduz a textura da lanterna (FlashLight_3_.png, Variation2) para 256 px, sem filtro (vizinho mais proximo).
Uso: python -I ferramentas/lanterna/preparar_textura.py   (precisa de Pillow no Python do sistema)"""
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "modelos 3d" / "PsxFlashLights"
origem = PASTA / "Texture" / "Variation2" / "FlashLight_3_.png"
destino = PASTA / "roblox" / "Lanterna.png"
destino.parent.mkdir(parents=True, exist_ok=True)
im = Image.open(origem).convert("RGBA")
print("original", im.size)
if max(im.size) > 256:
    im = im.resize((256, 256), Image.NEAREST)
im.save(destino, optimize=True)
print("gravado", destino, im.size, destino.stat().st_size, "bytes")
