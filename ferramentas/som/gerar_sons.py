"""Gera os sons novos dos monstros (docs/monstros/logica.md §5.5 e §9) em assets/som/ogg/.

Duas origens:
  1. Falas do Corcunda: Kenney "Voiceover Pack #1" (CC0, voz masculina de Jeffrey M. Smith), baixado de
     https://opengameart.org/sites/default/files/Voiceover%20Pack.zip para assets/som/fontes/. Tratamento (estetica PS1):
     mono, 22,05 kHz, pitch -8% (asetrate), passa-baixa 3,5 kHz, bitcrush leve, normalizado.
  2. Sons sinteticos (autoria nossa, sem licenca de terceiros), por aevalsrc do ffmpeg: onda do sonar, aviso detectado/passou,
     grito abafado (sem boca), pulso no chao, raspar de laminas, flor plantar/estalar.

Uso (da raiz):  python ferramentas/som/gerar_sons.py [--forcar]
Depois:         python ferramentas/som/enviar_som.py [--dry-run]
Saida: assets/som/ogg/<Nome>.ogg  (mono, 22,05 kHz, Vorbis). Espectrogramas em assets/som/espectro/ (para olhar).
"""

import io
import os
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / "assets" / "som" / "fontes"
SAIDA = RAIZ / "assets" / "som" / "ogg"
ESPECTRO = RAIZ / "assets" / "som" / "espectro"
FFMPEG_DIR = Path(os.environ.get("FFMPEG_DIR", r"D:\ffmpeg\bin"))
URL_KENNEY = "https://opengameart.org/sites/default/files/Voiceover%20Pack.zip"
TAXA = 22050
LIMITE_FALA = 2.0  # s (contrato §5.5)

# Nome no catalogo -> arquivo do pacote Kenney (voz masculina). Sem violencia: so chamados e avisos.
FALAS = [
    ("VozCorcunda_1", "Male/war_medic.ogg"),  # "Medic!"
    ("VozCorcunda_2", "Male/war_look_out.ogg"),  # "Look out!"
    ("VozCorcunda_3", "Male/war_get_down.ogg"),  # "Get down!"
    ("VozCorcunda_4", "Male/war_cover_me.ogg"),  # "Cover me!"
    ("VozCorcunda_5", "Male/war_watch_my_back.ogg"),  # "Watch my back!"
    ("VozCorcunda_6", "Male/war_call_for_backup.ogg"),  # "Call for backup!"
    ("VozCorcunda_7", "Male/hurry_up.ogg"),  # "Hurry up!"
    ("VozCorcunda_8", "Male/go.ogg"),  # "Go!"
    ("VozCorcunda_9", "Male/war_go_go_go.ogg"),  # "Go, go, go!"
    ("VozCorcunda_10", "Male/ready.ogg"),  # "Ready?"
]

# Nome -> (duracao s, expressao aevalsrc, filtros depois). Ruido: (random(0)-0.5)*2. t = tempo em s.
RUIDO = "((random(0)-0.5)*2)"
SINTESE = {
    # Onda grave que sobe devagar (1,6 s), cauda longa. Cliente, 2D.
    "SonarOnda": (
        1.6,
        "0.7*sin(2*PI*(60*t+45*t*t))*exp(-0.9*t)*min(1,t*12)+0.12*" + RUIDO + "*exp(-3*t)",
        "lowpass=f=900,acrusher=bits=10:mix=0.3:mode=lin",
    ),
    # Alto e seco: dois tons curtos (cliente, 2D).
    "SonarDetectado": (
        0.45,
        "0.6*sin(2*PI*(if(lt(t,0.14),780,1170))*t)*exp(-6*mod(t,0.14))*min(1,t*200)",
        "acrusher=bits=8:mix=0.5:mode=lin",
    ),
    # Baixo e curto: algo passou sem te achar.
    "SonarPassou": (
        0.5,
        "0.8*sin(2*PI*(95-40*t)*t)*exp(-7*t)*min(1,t*150)",
        "lowpass=f=300",
    ),
    # Grito abafado, sem boca: serra com harmonicos subindo de 170 para 300 Hz, vibrato, passa-baixa forte (parece atras de pano).
    "GritoAbafado": (
        1.7,
        "(0.5*sin(2*PI*(170*t+38*t*t)+1.2*sin(2*PI*6*t))"
        "+0.25*sin(4*PI*(170*t+38*t*t)+1.2*sin(2*PI*6*t))"
        "+0.14*sin(6*PI*(170*t+38*t*t)+1.2*sin(2*PI*6*t))"
        "+0.18*" + RUIDO + ")"
        "*min(1,t*7)*exp(-0.9*max(0,t-0.9))*(0.8+0.2*sin(2*PI*9*t))",
        "lowpass=f=650,acrusher=bits=9:mix=0.35:mode=lin",
    ),
    # Raspar grave no chao do pulso do Rastejador.
    "PulsoChao": (
        2.0,
        "(0.5*sin(2*PI*48*t)*exp(-1.4*t)+0.55*" + RUIDO + "*(0.5+0.5*sin(2*PI*7*t)))*min(1,t*20)*exp(-1.1*t)",
        "lowpass=f=420,highpass=f=35,acrusher=bits=9:mix=0.3:mode=lin",
    ),
    # Laminas arrastando: ruido agudo modulado + zunido metalico. Sem decaimento (e laco).
    "RasparLaminas": (
        2.0,
        "(0.55*" + RUIDO + "*(0.6+0.4*sin(2*PI*17*t))+0.12*sin(2*PI*2300*t)*(0.5+0.5*sin(2*PI*5*t)))",
        "highpass=f=1200,lowpass=f=5200,acrusher=bits=8:mix=0.4:mode=lin",
    ),
    # Flor surgindo: sopro curto + nota baixa que sobe.
    "FlorPlantar": (
        0.6,
        "(0.4*sin(2*PI*(200+160*t)*t)*exp(-5*t)+0.3*" + RUIDO + "*sin(PI*min(1,t/0.6)))*min(1,t*60)",
        "lowpass=f=2500,acrusher=bits=9:mix=0.3:mode=lin",
    ),
    # Flor estalando: estalo seco + ruido curto.
    "FlorEstalo": (
        0.4,
        "(0.7*sin(2*PI*(700-1400*t)*t)*exp(-22*t)+0.5*" + RUIDO + "*exp(-30*t))*min(1,t*400)",
        "highpass=f=120,acrusher=bits=8:mix=0.4:mode=lin",
    ),
}


def exe(nome):
    caminho = FFMPEG_DIR / (nome + ".exe")
    return str(caminho) if caminho.exists() else nome


def rodar(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError("falhou: %s\n%s" % (" ".join(args[:4]), r.stderr[-700:]))
    return r.stderr


def duracao(caminho):
    r = subprocess.run(
        [exe("ffprobe"), "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(caminho)],
        capture_output=True,
        text=True,
    )
    return float(r.stdout.strip())


def baixar_kenney():
    FONTES.mkdir(parents=True, exist_ok=True)
    alvo = FONTES / "kenney-voiceover"
    if (alvo / "Male" / "war_medic.ogg").exists():
        return alvo
    req = urllib.request.Request(URL_KENNEY, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        dados = r.read()
    with zipfile.ZipFile(io.BytesIO(dados)) as z:
        for nome in z.namelist():
            if nome.startswith("Male/") or nome in ("License.txt", "Credits.txt"):
                z.extract(nome, alvo)
    return alvo


def espectro(ogg, nome):
    ESPECTRO.mkdir(parents=True, exist_ok=True)
    rodar([exe("ffmpeg"), "-y", "-v", "error", "-i", str(ogg), "-lavfi", "showspectrumpic=s=640x240:legend=0",
           str(ESPECTRO / (nome + ".png"))])


def codificar(entrada_args, filtros, saida, entrada_lavfi=False):
    cadeia = filtros + ",loudnorm=I=-18:TP=-2:LRA=7,aresample=%d" % TAXA
    rodar([exe("ffmpeg"), "-y", "-v", "error"] + entrada_args + ["-af", cadeia, "-ac", "1", "-ar", str(TAXA),
          "-c:a", "libvorbis", "-q:a", "4", str(saida)])


def main():
    forcar = "--forcar" in sys.argv
    SAIDA.mkdir(parents=True, exist_ok=True)
    pasta = baixar_kenney()
    for nome, rel in FALAS:
        saida = SAIDA / (nome + ".ogg")
        if saida.exists() and not forcar:
            continue
        # pitch -8%: asetrate a 92% da taxa (alonga ~8%) -> passa-baixa 3,5 kHz -> bitcrush leve
        filtros = "aresample=44100,asetrate=%d,aresample=%d,lowpass=f=3500,acrusher=bits=10:mix=0.35:mode=lin" % (
            int(44100 * 0.92), TAXA)
        codificar(["-i", str(pasta / rel)], filtros, saida)
        d = duracao(saida)
        if d > LIMITE_FALA:
            raise RuntimeError("%s tem %.2f s (> %.1f s)" % (nome, d, LIMITE_FALA))
        espectro(saida, nome)
        print("fala", nome, "%.2f s" % d)
    for nome, (dur, expr, filtros) in SINTESE.items():
        saida = SAIDA / (nome + ".ogg")
        if saida.exists() and not forcar:
            continue
        codificar(["-f", "lavfi", "-i", "aevalsrc='%s':s=%d:d=%s" % (expr, TAXA, dur)], filtros, saida)
        espectro(saida, nome)
        print("sintese", nome, "%.2f s" % duracao(saida))


if __name__ == "__main__":
    main()
