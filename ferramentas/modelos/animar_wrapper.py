# Animações do Wrapper (2026-11-14, agente D) sobre o rig próprio de MonsterPSX.blend (só leitura), com o Animador do
# refazer_monstros.py (IK de pernas, correção de chão, medidas). Grava modelos 3d/wrapper/Wrapper_anim.blend e Wrapper_anim.json.
#   blender -b --factory-startup -P ferramentas/modelos/animar_wrapper.py
#
# O .blend original tinha restrições IK/COPY_ROTATION nas canelas/antebraços e o exportador lê só as curvas (sem restrição): os clipes
# antigos chegavam ao Roblox sem a IK. Aqui as restrições são tiradas e cada osso que deforma recebe a pose final.
# Clipes: Idle, Walk, Run, Attack (investida de corpo), WallSlam, Sonar (sem boca: o corpo infla e treme), Atordoado (loop), Death.
# Sem Scream (o sonar substitui o grito).

import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import refazer_monstros as R  # noqa: E402
from refazer_monstros import acel, janela, rampa  # noqa: E402

REPO = R.REPO
PASTA = os.path.join(REPO, "modelos 3d", "wrapper")
ENTRADA = os.path.join(PASTA, "MonsterPSX.blend")
SAIDA = os.path.join(PASTA, "Wrapper_anim.blend")

R.ANIM["Wrapper"] = dict(
    tipo="biped",
    nomes={"Hips": "hips", "Spine": "spine", "Chest": "chest", "Neck": "neck", "Head": "head",
           "UpperArm.L": "upper_arm.L", "LowerArm.L": "forearm.L", "Hand.L": "hand.L",
           "UpperArm.R": "upper_arm.R", "LowerArm.R": "forearm.R", "Hand.R": "hand.R",
           "UpperLeg.L": "thigh.L", "LowerLeg.L": "shin.L", "Foot.L": "foot.L",
           "UpperLeg.R": "thigh.R", "LowerLeg.R": "shin.R", "Foot.R": "foot.R"},
    polo=(0, -1, 0.1), y_pe=0.06, x_pe={"L": 0.15, "R": -0.16}, pe_dir={}, descer=0.05,
    # braços enrolados no corpo: quase parados
    braco=dict(base=0, amp=3, cotovelo=0), inclinar=10, cabeca=dict(base=-4, bob=4),
    walk=dict(quadros=30, passo=0.48, altura=0.10, apoio=0.62, bob=0.03, bob_fase=0.08, roll=6, yaw=7, lado=0.035),
    run=dict(quadros=16, passo=0.92, altura=0.18, apoio=0.38, bob=0.06, bob_fase=0.2, roll=5, yaw=8, lado=0.025, inclinar=20, braco_amp=4),
)


class AnimadorWrapper(R.Animador):
    def idle(self, p):
        e = super().idle(p)
        t2 = 2 * math.pi * p
        e["roll"] = 3 * math.sin(t2)  # balança o corpo como quem escuta
        e["pesc_y"] = 8 * math.sin(t2 + 0.5)
        return e

    def ataque(self, t, ti=0.45, D=1.0):
        # investida de corpo: agacha e recua, se joga com o peito e a cabeça na frente (o pé L dá um passo), segura e volta
        e = self.neutro()
        prep = rampa(t, 0.0, 0.28) * (1 - acel(t, 0.28, ti))
        bote = acel(t, 0.28, ti) * (1 - rampa(t, 0.6, D))
        e["mov"] = e["mov"] + Vector((0, 0.10 * prep - 0.40 * bote, -0.10 * prep - 0.06 * bote))
        e["pitch"] += -8 * prep + 28 * bote
        e["dobra"] = -6 * prep + 10 * bote
        e["pesc_p"] = -10 * prep + 6 * bote
        e["cab_p"] = e["cab_p"] - 8 * prep
        self.passinho(e, "L", -0.36, t, 0.26, ti, 0.62, 0.92, altura=0.08)
        return e

    def wallslam(self, t, ti=0.5, D=1.2):
        # ombro R na frente, se joga de lado contra a parede, ricocheteia e se recompõe
        e = self.neutro()
        arma = rampa(t, 0.0, 0.33) * (1 - acel(t, 0.33, ti))
        bate = acel(t, 0.33, ti) * (1 - rampa(t, 0.55, 0.75))
        volta = janela(t, 0.5, 0.62, 0.7, D)
        e["torce"] = 30 * arma + 35 * bate + 10 * volta
        e["yaw"] = 10 * arma + 15 * bate
        e["roll"] = 8 * arma - 14 * bate + 6 * volta
        e["mov"] = e["mov"] + Vector((0.06 * arma - 0.14 * bate + 0.04 * volta, -0.12 * bate + 0.10 * volta, -0.06 * arma))
        e["cab_r"] = -15 * bate + 10 * volta
        e["cab_p"] = e["cab_p"] + 12 * volta
        self.passinho(e, "R", 0.0, t, 0.3, ti, 0.6, 0.9, altura=0.05)
        return e

    def sonar(self, t, to=0.5, D=1.2):
        # sem boca: o corpo estufa (arqueia, peito e cabeça para cima), treme cada vez mais, solta a onda e murcha
        e = self.neutro()
        infla = rampa(t, 0.0, to - 0.02) * (1 - rampa(t, to, to + 0.12))
        solta = janela(t, to - 0.02, to + 0.04, to + 0.10, 0.75)
        treme = infla * (0.4 + 0.6 * infla)
        f = 2 * math.pi * 6 * t  # <= 7 Hz: o clipe vai ao Roblox com 15 keyframes/s
        e["dobra"] = -20 * infla + 14 * solta
        e["pitch"] += -10 * infla + 8 * solta
        e["pesc_p"] = -22 * infla + 10 * solta
        e["cab_p"] = e["cab_p"] - 10 * infla + 6 * solta
        e["mov"] = e["mov"] + Vector((0, 0, 0.03 * infla - 0.05 * solta))
        e["roll"] = 3 * treme * math.sin(f)
        e["cab_r"] = 6 * treme * math.sin(f * 1.3 + 1)
        e["cab_y"] = 4 * treme * math.sin(f * 0.9)
        for s, sinal in (("L", 1), ("R", -1)):
            self.braco(e, s, p=-6, r=-sinal * 8, w=infla)
        return e

    def atordoado(self, p):
        # loop de 2 s: cambaleia, cabeça pendendo, pé R se ajeita (sobe, sai e volta) para não cair
        e = self.neutro()
        t2 = 2 * math.pi * p
        e["roll"] = 8 * math.sin(t2)
        e["pitch"] += 6 + 5 * math.sin(2 * t2 + 1)
        e["yaw"] = 6 * math.sin(t2 + 0.7)
        e["mov"] = e["mov"] + Vector((0.05 * math.sin(t2), 0.02 * math.sin(2 * t2), -0.05 - 0.02 * math.cos(2 * t2)))
        e["dobra"] = 8 + 4 * math.sin(t2 + 2)
        e["pesc_p"] = 15 + 8 * math.sin(t2 + 1.5)
        e["cab_r"] = 18 * math.sin(t2 + 0.8)
        e["cab_p"] = e["cab_p"] + 10 * math.sin(2 * t2)
        # pé R: passo para fora em 0,2..0,35, volta em 0,7..0,85 (sempre no ar enquanto se move)
        for a, b, dx in ((0.20, 0.35, 1), (0.70, 0.85, -1)):
            u = max(0.0, min(1.0, (p - a) / (b - a)))
            e["membros"]["R"]["alvo"] = e["membros"]["R"]["alvo"] + Vector((0, 0, 0.06 * math.sin(math.pi * u)))
        lado = rampa(p, 0.20, 0.35) * (1 - rampa(p, 0.70, 0.85))
        e["membros"]["R"]["alvo"] = e["membros"]["R"]["alvo"] + Vector((-0.10 * lado, 0, 0))
        return e


def clipes(A):
    c = A.cfg
    return [("Idle", 2.0, A.idle, True, {}),
            ("Walk", c["walk"]["quadros"] / R.FPS, lambda p: A.ciclo(p, "walk"), True, {}),
            ("Run", c["run"]["quadros"] / R.FPS, lambda p: A.ciclo(p, "run"), True, {}),
            ("Attack", 1.0, A.ataque, False, {"impacto": 0.45}),
            ("WallSlam", 1.2, A.wallslam, False, {"impacto": 0.5}),
            ("Sonar", 1.2, A.sonar, False, {"onda": 0.5}),
            ("Atordoado", 2.0, A.atordoado, True, {})]


def main():
    bpy.ops.wm.open_mainfile(filepath=ENTRADA)
    arm = bpy.data.objects["MonsterPSX_Rig"]
    malha = bpy.data.objects["MonsterPSX"]
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        pb.rotation_mode = "QUATERNION"
    arm.data.pose_position = "POSE"
    info = R.animar("Wrapper", arm, malha, os.path.join(PASTA, "Wrapper_anim.json"), "Wrapper_", AnimadorWrapper, clipes)
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    print("##WRAPPER## " + json.dumps(info, ensure_ascii=False))


if __name__ == "__main__":
    main()
