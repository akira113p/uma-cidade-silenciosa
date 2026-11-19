"""Exporta o Rastejador (Rastejador_anim_opus.blend) para FBX com esqueleto + manifesto + animacoes em dados.

Uso (da raiz):
  blender.exe -b --factory-startup -P ferramentas/modelos/exportar_rastejador.py -- --altura 2.908 [--nome rastejador|wrapper|corcunda|monstrops1|florescida] [--saida "modelos 3d/rastejador"]

--nome escolhe o perfil (PERFIS abaixo: entrada .blend, textura, rig, malha, ossos do corpo, nomes dos clipes). Padrao: rastejador.
Wrapper: desde 2026-11-14 le modelos 3d/wrapper/Wrapper_anim.blend (animar_wrapper.py sobre o MonsterPSX.blend): Idle, Walk, Run, Attack,
WallSlam, Sonar, Atordoado, Death (sem Scream). Frente = -Y.
"dados" do perfil = JSON do script de animacao: ciclica, eventos (s) e velocidade nativa por clipe -> manifesto (eventos, nativas_blend).

--altura = altura final em studs (a importacao do Roblox e 1:1 com as unidades do .fbx, medido). Para 1 m com jogador de 1,8 m:
studs = jogadorStuds / 1,8 (Config/Rastejador) = 2.908.
Altura = extensao Z da malha em repouso (2.2 no .blend), pes em z=0.

Saidas em <saida>/:
  rastejador.fbx        malha + armature, no maximo 4 influencias por vertice, sem animacao (bake_anim=False)
  Monster_1.png         textura 256 (copia)
  manifesto.json        dimensoes, caixa do corpo, ossos (pai, head/tail de repouso, matrix_local), escala usada
  anim_blender.json     por acao: fps, ciclica, quadros; por quadro e osso: location + quaternion (basis do pose bone, no
                        referencial do osso). O Luau/Studio converte para Bone.Transform (ver gerar_anim_rastejador.py).
Frente do monstro = -Y no Blender; no FBX sai em -Z (axis_forward='-Z', axis_up='Y').
"""

import json
import os
import shutil
import sys

import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
PERFIS = {
    "rastejador": dict(
        entrada=os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador", "Rastejador_anim_opus.blend"),
        textura=os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador", "Monster_1.png"),
        malha="monster_monster_1_0",
        rig="Rastejador_Rig",
        corpo=("Hips", "Spine", "Chest", "Neck", "Head"),
        acoes=None,  # todas, tirando o prefixo "Rastejador_"
        prefixo_acao="Rastejador_",
        dados=os.path.join(REPO, "modelos 3d", "_ps2", "Rastejador", "Rastejador_anim_opus.json"),
    ),
    # 2026-11-14 (agente D): clipes refeitos por animar_wrapper.py (sem Scream; com Sonar, Atordoado, Death).
    "wrapper": dict(
        entrada=os.path.join(REPO, "modelos 3d", "wrapper", "Wrapper_anim.blend"),
        textura=os.path.join(REPO, "modelos 3d", "wrapper", "MonsterPSX_Diffuse.png"),
        malha="MonsterPSX",
        rig="MonsterPSX_Rig",
        corpo=("hips", "spine", "chest", "torso", "neck", "head"),
        acoes=None,
        prefixo_acao="Wrapper_",
        dados=os.path.join(REPO, "modelos 3d", "wrapper", "Wrapper_anim.json"),
    ),
}


# Moderacao (2026-11-14): a Roblox recusou a textura do Esfolado (sangue). Corcunda e Florescida sobem so a versao "_seguro" (sem vermelho).
# Esfolado fora desta rodada: sem perfil.
TEXTURA_SEGURA = ("Corcunda", "Florescida")


def perfil_v2(nome):
    """Monstros refeitos por refazer_monstros.py: modelos 3d/_ps2/<Nome>/<Nome>_v2.blend (malha <Nome>, rig <Nome>_Rig, ciclos <Nome>_Idle...)."""
    pasta = os.path.join(REPO, "modelos 3d", "_ps2", nome)
    return dict(
        entrada=os.path.join(pasta, nome + "_v2.blend"),
        textura=os.path.join(pasta, nome + ("_atlas_seguro.png" if nome in TEXTURA_SEGURA else "_atlas.png")),
        malha=nome,
        rig=nome + "_Rig",
        corpo=("Hips", "Spine", "Chest", "Neck", "Head"),
        acoes=None,
        prefixo_acao=nome + "_",
        prefixo_anim=nome + "_",  # prefixo do .rbxm/Animation (gerar_config_monstros, montar_anim_rbxm)
        dados=os.path.join(pasta, nome + "_v2.json"),
    )


for _n in ("Corcunda", "MonstroPS1", "Florescida"):
    PERFIS[_n.lower()] = perfil_v2(_n)


def arg(nome, padrao):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return padrao


def fcurves(acao):
    # Blender 5: curvas ficam em camadas/tiras/canais (acoes com slots); antes, em action.fcurves
    if hasattr(acao, "fcurves"):
        return acao.fcurves
    return [fc for l in acao.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves]


def v3(v):
    return [round(float(v[0]), 5), round(float(v[1]), 5), round(float(v[2]), 5)]


def main():
    altura = float(arg("--altura", "2.908"))
    nome_monstro = arg("--nome", "rastejador")
    perfil = PERFIS[nome_monstro]
    CORPO = perfil["corpo"]
    saida = os.path.abspath(arg("--saida", os.path.join(REPO, "modelos 3d", nome_monstro)))
    os.makedirs(saida, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=perfil["entrada"])
    arm = bpy.data.objects[perfil["rig"]]
    if perfil["malha"]:
        malha = bpy.data.objects[perfil["malha"]]
    else:
        malhas = [o for o in bpy.data.objects if o.type == "MESH" and len(o.data.vertices) > 0]
        malha = max(malhas, key=lambda o: len(o.data.vertices))
    arm.data.pose_position = "REST"

    # dados de repouso (antes de qualquer mudanca)
    vs = [v.co.copy() for v in malha.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    altura_blend = mx.z - mn.z
    escala = altura / altura_blend
    nomes = {g.index: g.name for g in malha.vertex_groups}
    corpo = [v.co for v in malha.data.vertices if v.groups and nomes[max(v.groups, key=lambda g: g.weight).group] in CORPO]
    cmn = Vector((min(c.x for c in corpo), min(c.y for c in corpo), min(c.z for c in corpo)))
    cmx = Vector((max(c.x for c in corpo), max(c.y for c in corpo), max(c.z for c in corpo)))
    ossos = {}
    for b in arm.data.bones:
        ossos[b.name] = dict(
            pai=b.parent.name if b.parent else None,
            head=v3(b.head_local),
            tail=v3(b.tail_local),
            matrix_local=[[round(x, 6) for x in row] for row in b.matrix_local],
        )

    # dados do script de animacao: ciclica, eventos (s) e velocidade nativa (m/s do .blend) por clipe
    dados = {}
    if perfil.get("dados") and os.path.exists(perfil["dados"]):
        with open(perfil["dados"], encoding="utf-8") as f:
            dados = json.load(f).get("acoes", {})

    # animacoes em dados (basis de cada pose bone, a cada quadro gravado)
    fps = bpy.context.scene.render.fps
    acoes = {}
    for a in bpy.data.actions:
        if perfil["acoes"] is None:
            nome = a.name.replace(perfil["prefixo_acao"], "")
        else:
            nome = next((v for k, v in perfil["acoes"].items() if a.name.startswith(k)), None)
            if nome is None:
                continue  # take que o jogo nao usa
        q0, q1 = int(a.frame_range[0]), int(a.frame_range[1])
        quadros = []
        for f in range(q0, q1 + 1):
            osso = {}
            for b in arm.data.bones:
                base = f'pose.bones["{b.name}"].'
                loc = [0.0, 0.0, 0.0]
                quat = [1.0, 0.0, 0.0, 0.0]
                for fc in fcurves(a):
                    if fc.data_path == base + "location":
                        loc[fc.array_index] = fc.evaluate(f)
                    elif fc.data_path == base + "rotation_quaternion":
                        quat[fc.array_index] = fc.evaluate(f)
                osso[b.name] = dict(loc=[round(x, 6) for x in loc], quat=[round(x, 6) for x in quat])
            quadros.append(osso)
        ciclica = dados.get(nome, {}).get("ciclica", nome in ("Idle", "Walk", "Run"))
        acoes[nome] = dict(fps=fps, quadros=len(quadros), ciclica=ciclica, frames=quadros)

    # no maximo 4 influencias por vertice (limite do Roblox); so na copia em memoria
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = malha
    malha.select_set(True)
    antes = max(len([g for g in v.groups if g.weight > 1e-4]) for v in malha.data.vertices)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    depois = max(len([g for g in v.groups if g.weight > 1e-4]) for v in malha.data.vertices)

    # Escala nos DADOS (vertices e ossos), nao no exportador: o Roblox desfaz o global_scale do FBX (medido: 2.2 ficou 2.2).
    arm.select_set(True)
    malha.select_set(True)
    bpy.context.view_layer.objects.active = arm
    from mathutils import Matrix

    malha.data.transform(Matrix.Scale(escala, 4))
    malha.data.update()
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.head = eb.head * escala
        eb.tail = eb.tail * escala
    bpy.ops.object.mode_set(mode="OBJECT")
    fbx = os.path.join(saida, nome_monstro + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
        bake_anim=False,
        use_armature_deform_only=True,
        path_mode="STRIP",
        mesh_smooth_type="FACE",
    )
    textura = os.path.basename(perfil["textura"])
    if os.path.abspath(perfil["textura"]) != os.path.abspath(os.path.join(saida, textura)):
        shutil.copyfile(perfil["textura"], os.path.join(saida, textura))

    tris = sum(len(p.vertices) - 2 for p in malha.data.polygons)
    manifesto = dict(
        arquivo=nome_monstro + ".fbx",
        prefixo_anim=perfil.get("prefixo_anim"),
        textura=textura,
        escala_blender_para_fbx=round(escala, 6),
        altura_fbx=altura,
        altura_blend=round(altura_blend, 5),
        triangulos=tris,
        influencias_antes=antes,
        influencias_depois=depois,
        dimensoes_blend=dict(min=v3(mn), max=v3(mx), tamanho=v3(mx - mn)),
        corpo_blend=dict(min=v3(cmn), max=v3(cmx), tamanho=v3(cmx - cmn)),
        ossos=ossos,
        acoes={k: dict(fps=v["fps"], quadros=v["quadros"], ciclica=v["ciclica"]) for k, v in acoes.items()},
        eventos={k: d["eventos"] for k, d in dados.items() if d.get("eventos") and k in acoes},
        nativas_blend={k: d["velocidade_nativa_m_s"] for k, d in dados.items() if d.get("velocidade_nativa_m_s") and k in acoes},
    )
    with open(os.path.join(saida, "manifesto.json"), "w", encoding="utf-8") as f:
        json.dump(manifesto, f, indent=1, ensure_ascii=False)
    with open(os.path.join(saida, "anim_blender.json"), "w", encoding="utf-8") as f:
        json.dump(acoes, f, separators=(",", ":"))
    print("##EXPORT## " + json.dumps(dict(fbx=fbx, tris=tris, escala=escala, infl=[antes, depois], tamanho_blend=v3(mx - mn))))


if __name__ == "__main__":
    main()
