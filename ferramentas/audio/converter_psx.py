"""Converte os audios do PSX (passos e ambiente) para OGG Vorbis em build/audio/. Contrato: docs/audio-psx.md.

Origem (so leitura, dados nao confiaveis): C:\\Users\\cerfr\\Downloads\\psx sttuff\\1-audio\\
Saida: build/audio/passos/<Superficie>_<n>.ogg (mono) e build/audio/ambiente/<Nome>.ogg (estereo, 48 kHz, ~192 kbps).
Idempotente: pula o que ja existe e e mais novo que a origem. Falha se algum arquivo passar de 19 MB ou 7 min.

Uso (da raiz):  python ferramentas/audio/converter_psx.py [--forcar]
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(os.environ.get("PSX_AUDIO_ORIGEM", r"C:\Users\cerfr\Downloads\psx sttuff\1-audio"))
PASSOS = ORIGEM / "40 Free PSX Footsteps" / "40 Free PSX Footsteps"
AMBIENTE = ORIGEM / "PSX Ambient Pack" / "Tracks"
SAIDA = RAIZ / "build" / "audio"
FFMPEG_DIR = Path(os.environ.get("FFMPEG_DIR", r"D:\ffmpeg\bin"))
LIMITE_BYTES = 19 * 1024 * 1024
LIMITE_SEG = 7 * 60
SUPERFICIES = ["Concrete", "Dirt", "Grass", "Gravel", "Metal", "Stairs", "Stone", "Wood"]
# Faixa -> filtro extra. Hollow tem pico -0,4 dB (medida); Gravel perde ~2 dB no mono (cancelamento de fase).
AMBIENTES = {"Still": None, "Distant": None, "Veil": None, "Hollow": "volume=-3dB", "Blur": None, "Faded": None}
AJUSTE_PASSO = {"Gravel": "volume=2dB"}


def exe(nome):
    caminho = FFMPEG_DIR / (nome + ".exe")
    return str(caminho) if caminho.exists() else nome


def rodar(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError("falhou: %s\n%s" % (" ".join(args[:3]), r.stderr[-600:]))
    return r.stdout


def duracao(caminho):
    saida = rodar([exe("ffprobe"), "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(caminho)])
    return float(saida.strip())


def numero(caminho):
    m = re.search(r"(\d+)\.ogg$", caminho.name, re.I)
    return int(m.group(1)) if m else 0


def converter(origem, destino, canais, filtro, qualidade, forcar):
    if not forcar and destino.exists() and destino.stat().st_mtime >= origem.stat().st_mtime:
        return "pulou"
    destino.parent.mkdir(parents=True, exist_ok=True)
    args = [exe("ffmpeg"), "-hide_banner", "-loglevel", "error", "-y", "-i", str(origem), "-vn"]
    if filtro:
        args += ["-af", filtro]
    args += ["-ac", str(canais), "-c:a", "libvorbis"] + qualidade + [str(destino)]
    rodar(args)
    return "convertido"


def main():
    forcar = "--forcar" in sys.argv
    if not ORIGEM.exists():
        sys.exit("origem nao encontrada: %s" % ORIGEM)
    tarefas = []  # (origem, destino, canais, filtro, qualidade)
    for sup in SUPERFICIES:
        arqs = sorted((PASSOS / sup).glob("*.ogg"), key=numero)
        if not arqs:
            sys.exit("sem arquivos em " + str(PASSOS / sup))
        for i, a in enumerate(arqs, 1):
            destino = SAIDA / "passos" / ("%s_%d.ogg" % (sup, i))
            tarefas.append((a, destino, 1, AJUSTE_PASSO.get(sup), ["-q:a", "5"]))
    for nome, filtro in AMBIENTES.items():
        tarefas.append((AMBIENTE / (nome + ".wav"), SAIDA / "ambiente" / (nome + ".ogg"), 2, filtro, ["-b:a", "192k", "-ar", "48000"]))
    relatorio = {}
    total = 0
    for origem, destino, canais, filtro, qual in tarefas:
        if not origem.exists():
            sys.exit("falta " + str(origem))
        estado = converter(origem, destino, canais, filtro, qual, forcar)
        tam = destino.stat().st_size
        seg = duracao(destino)
        if tam > LIMITE_BYTES or seg > LIMITE_SEG:
            sys.exit("LIMITE estourado: %s (%d bytes, %.1f s)" % (destino.name, tam, seg))
        total += tam
        relatorio[destino.relative_to(SAIDA).as_posix()] = {"bytes": tam, "segundos": round(seg, 3)}
        print(estado, destino.relative_to(SAIDA).as_posix(), tam, "bytes", "%.2f s" % seg)
    (SAIDA / "relatorio.json").write_text(json.dumps(relatorio, indent=2), encoding="utf-8")
    print("%d arquivos, %.2f MB no total" % (len(relatorio), total / 1e6))


if __name__ == "__main__":
    main()
