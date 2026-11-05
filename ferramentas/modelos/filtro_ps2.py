# Filtro PS2: padroniza um modelo de terceiros (modelos 3d/) para o visual do jogo (Silent Hill era PS2).
# Teto de triângulos, textura de cor só (até 256 px), paleta fria dessaturada que preserva vermelhos, material chapado.
# Não mexe nos originais nem no Roblox: grava em "modelos 3d/_ps2/<nome>/" (.blend + PNGs + manifesto .json).
#
# Ao vivo (MCP do Blender, cena nova visível na janela):
#   f = r"<repo>/ferramentas/modelos/filtro_ps2.py"; g = {"__file__": f, "__name__": "filtro_ps2"}
#   exec(open(f, encoding="utf-8").read(), g); g["converter"](r"<arquivo>", "Corcunda")
# Headless:
#   blender -b -P ferramentas/modelos/filtro_ps2.py -- --input <arquivo> --nome Corcunda [--tipo arma]
# Solda e decimação vêm de .claude/skills/modelo-3d-roblox/scripts/reduzir.py (sem refazer a UV: a textura original fica).

import json
import math
import os
import re
import sys
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "..", ".."))
SAIDA = os.path.join(REPO, "modelos 3d", "_ps2")

# Números do estilo (PROVISÓRIO até o usuário aprovar o piloto)
TETO_TRIS = {"monstro": 4000, "arma": 1500, "outro": 2000}  # por modelo inteiro, dividido entre as malhas
TEXTURA_MAX = 256  # px no maior lado (PS2: 128–256)
SATURACAO = 0.55  # 1 = original
SATURACAO_VERMELHO = 0.9  # vermelhos (sangue, ferrugem) perdem menos cor
TINTA = (0.94, 0.98, 1.04)  # puxa para o frio (cinza-azulado)
CONTRASTE = 1.08
INTERPOLACAO = "Linear"  # PS2 filtrava; "Closest" dá o pixelado do PS1
MUMBLER_BAIXO = Vector((0, -37, -25))  # centro do tronco de baixo (unidades do FBX original: 209 de altura)
MUMBLER_ESC_BAIXO = 0.6
MUMBLER_INCLINACAO = -40  # graus em X; negativo inclina a corcunda para a frente (+Y)
MUMBLER_PIVO_Z = -10
MUMBLER_SOBE = Vector((0, 0, -35))
# EXCEÇÃO (pedido do usuário, 2026-11-04): estes ficam no modelo base. O filtro piorava o visual: sem solda, decimação,
# textura reduzida ou material achatado; só importa, tira luz/câmera e normaliza a altura. Mumbler é o caso especial: aplica posar_mumbler (pose curvada da referência do Miro, Campânula).
SEM_FILTRO = {"Mumbler", "Carniceiro", "Esfolado"}
ALTURA_M = 2.2  # altura do monstro em metros (≈ 8 studs; o jogador R15 tem ≈ 1,4 m). Blender usa metros.
LIMITE_M = 4.9  # nenhuma dimensão passa disso (pedido: menos de 5 m). Se passar, a escala cai até caber.
# Peças que vieram com o arquivo de origem mas não são do monstro (apresentação do Sketchfab/preview).
REMOVER = {"Destare": ("Icosphere",)}


def soldar(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimar(ob, razao):
    # Mesma razão para todas as malhas do modelo: o total cai proporcionalmente, sem piso por peça.
    if razao >= 1.0 or tris(ob) < 4:
        return
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = razao
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)  # antes da Armature, se houver
        bpy.ops.object.modifier_apply(modifier=mod.name)


def graduar(px):
    # px: (n, 4) em espaço de exibição (sRGB), 0..1
    rgb = px[:, :3]
    lum = (rgb @ np.array([0.299, 0.587, 0.114]))[:, None]
    vermelho = np.clip((rgb[:, 0:1] - np.maximum(rgb[:, 1:2], rgb[:, 2:3])) * 3.0, 0.0, 1.0)
    sat = SATURACAO + (SATURACAO_VERMELHO - SATURACAO) * vermelho
    rgb = lum + (rgb - lum) * sat
    rgb = rgb * np.array(TINTA) * (1.0 - vermelho) + rgb * vermelho
    rgb = (rgb - 0.5) * CONTRASTE + 0.5
    px[:, :3] = np.clip(rgb, 0.0, 1.0)
    return px


def processar_imagem(img, pasta, feitas):
    if img.name in feitas:
        return feitas[img.name]
    nova = img.copy()
    w, h = img.size
    if w == 0 or h == 0:
        feitas[img.name] = img
        return img
    k = min(1.0, TEXTURA_MAX / max(w, h))
    if k < 1.0:
        nova.scale(max(1, round(w * k)), max(1, round(h * k)))
    w, h = nova.size
    px = np.empty(w * h * 4, dtype=np.float32)
    nova.pixels.foreach_get(px)
    nova.pixels.foreach_set(graduar(px.reshape(-1, 4)).ravel())
    nome = "".join(c if c.isalnum() or c in "-_" else "_" for c in os.path.splitext(img.name)[0]) + ".png"
    nova.name = nome
    nova.filepath_raw = os.path.join(pasta, nome)
    nova.file_format = "PNG"
    nova.save()
    feitas[img.name] = nova
    return nova


def imagem_da_cor(mat):
    # A textura ligada (direto ou por nós intermediários) na Base Color do Principled; senão, a primeira imagem.
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        fila = [l.from_node for l in bsdf.inputs["Base Color"].links]
        while fila:
            n = fila.pop(0)
            if n.type == "TEX_IMAGE" and n.image:
                return n.image, bsdf
            fila += [l.from_node for i in n.inputs for l in i.links]
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image), None)
    return (tex.image if tex else None), bsdf


def raiz_do_modelo(caminho):
    # Pasta do monstro em modelos 3d/monstros/<Nome> (o FBX pode estar em source/ ou mais fundo).
    p = os.path.abspath(caminho)
    partes = p.split(os.sep)
    for pasta_raiz in ("monstros", "armas", "outros"):
        if pasta_raiz in partes:
            return os.sep.join(partes[: partes.index(pasta_raiz) + 2])
    return os.path.dirname(os.path.dirname(p))


def candidatas_de_cor(raiz):
    # Texturas de cor soltas na pasta do monstro (FBX com o material desligado da imagem).
    # Imagens da pasta que podem ser cor: tudo, menos mapas que claramente não são cor (normal, rugosidade...).
    nao = ("normal", "rough", "metal", "emiss", "height", "scatter", "opacity", "mixed", "-ao", "_ao", "_ao.", "(ao")
    achadas = []
    for r, _, nomes in os.walk(raiz):
        for n in nomes:
            b = n.lower()
            if b.endswith((".png", ".jpg", ".jpeg")) and not any(k in b for k in nao):
                achadas.append(os.path.join(r, n))
    return achadas


def textura_para(mat, candidatas):
    # 1) nome do material contido no nome da imagem (só letras: "Deer_body1" x "deer_body_12_Deer_body_BaseColor");
    # 2) imagem com mais palavras em comum ("m_m12_view" x "t_m1912_view" → "view");
    # 3) a única candidata, se só houver uma. Sem nada parecido, fica sem textura.
    letras = lambda s: re.sub(r"[^a-z]", "", s.lower())
    palavras = lambda s: {p for p in re.split(r"[^a-z0-9]+", s.lower()) if len(p) >= 3}
    nome = mat.name.split(":")[-1]
    if re.search(r"glass|vidro|light|lights|luz|lens|emiss", nome.lower()):  # vidro e luz são cor lisa, não a textura da peça
        return None
    for c in candidatas:
        if letras(nome) and letras(nome) in letras(os.path.splitext(os.path.basename(c))[0]):
            return c
    pm = palavras(nome)
    melhor, nota = None, 0
    for c in candidatas:
        n = len(pm & palavras(os.path.splitext(os.path.basename(c))[0]))
        if n > nota:
            melhor, nota = c, n
    if melhor:
        return melhor
    return candidatas[0] if len(candidatas) == 1 else None


def achatar_material(mat, pasta, feitas, candidatas=()):
    if not mat or not mat.use_nodes:
        return None
    img, bsdf = imagem_da_cor(mat)
    caminho_ok = img is not None and os.path.exists(bpy.path.abspath(img.filepath_raw or img.filepath))
    if img is None or not caminho_ok:  # imagem com caminho quebrado conta como sem imagem
        achada = textura_para(mat, candidatas)
        if achada:
            img = bpy.data.images.load(achada)
    cor = tuple(bsdf.inputs["Base Color"].default_value) if bsdf else (0.5, 0.5, 0.5, 1)
    # Opaco sempre: o canal alfa do GLB deixava o corpo translúcido. Modo Blend/Hashed do GLB é trocado por Opaque.
    mat.blend_method = "OPAQUE"  # por último: definir surface_render_method antes reescreve isto para HASHED
    nt = mat.node_tree
    nt.nodes.clear()
    saida = nt.nodes.new("ShaderNodeOutputMaterial")
    novo = nt.nodes.new("ShaderNodeBsdfPrincipled")
    novo.inputs["Roughness"].default_value = 1.0
    novo.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in novo.inputs:
        novo.inputs["Specular IOR Level"].default_value = 0.0
    nt.links.new(novo.outputs["BSDF"], saida.inputs["Surface"])
    if img:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = processar_imagem(img, pasta, feitas)
        tex.interpolation = INTERPOLACAO
        nt.links.new(tex.outputs["Color"], novo.inputs["Base Color"])
        return tex.image.name
    px = graduar(np.array([cor], dtype=np.float32))
    if PROCEDURAL and not re.search(r"glass|vidro|light|lights|luz|lens|emiss", mat.name.lower()):
        # Original sem imagem (só cor): gera uma textura suja em blocos, no estilo PS2, com a mesma cor.
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = textura_suja(px[0, :3], mat.name, pasta)
        tex.interpolation = INTERPOLACAO
        nt.links.new(tex.outputs["Color"], novo.inputs["Base Color"])
        return tex.image.name
    novo.inputs["Base Color"].default_value = tuple(px[0])
    return None


def textura_suja(cor, nome, pasta, n=128):
    # Blocos de ruído (manchas) + riscos escuros esparsos, multiplicados pela cor do material. Semente = nome.
    rng = np.random.default_rng(zlib.crc32(nome.encode()))
    bloco = rng.random((16, 16))
    manchas = np.kron(bloco, np.ones((n // 16, n // 16)))
    manchas = 0.8 + 0.4 * (manchas - 0.5)
    riscos = (rng.random((n, n)) > 0.985).astype(np.float64)
    fator = manchas * (1.0 - 0.35 * riscos)
    # Piso de luz: o original tem preto quase puro (polímero, cano). Sobe tudo um pouco para a peça continuar lida.
    base = 0.12 + 0.88 * np.asarray(cor, dtype=np.float64)
    rgb = np.clip(base[None, None, :] * fator[..., None], 0.0, 1.0)
    rgba = np.ones((n, n, 4), dtype=np.float32)
    rgba[..., :3] = rgb
    nome_img = "cor_" + "".join(c if c.isalnum() else "_" for c in nome)
    img = bpy.data.images.new(nome_img, n, n, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(pasta, nome_img + ".png")
    img.file_format = "PNG"
    img.save()
    return img


def limites(cena):
    # Caixa em espaço de mundo (considera a escala dos pais). Usa os vértices no repouso.
    pts = []
    for o in cena.objects:
        if o.type == "MESH":
            pts += [o.matrix_world @ v.co for v in o.data.vertices]
    if not pts:
        return None
    return [(min(p[k] for p in pts), max(p[k] for p in pts)) for k in range(3)]


def normalizar(cena, altura_m, maior_m=None):
    # Aplica a escala que leva a altura (Z, que é "para cima" no Blender) a altura_m e põe a base dos pés em Z = 0,
    # centrado em X e Y. Armas e itens usam maior_m: o maior lado (qualquer eixo) vira esse valor.
    # Escala e posição ficam nas raízes; os filhos seguem.
    bpy.context.view_layer.update()
    caixa = limites(cena)
    if not caixa or caixa[2][1] - caixa[2][0] <= 0:
        return None
    altura_original = caixa[2][1] - caixa[2][0]
    if maior_m:
        s = maior_m / max(caixa[k][1] - caixa[k][0] for k in range(3))
    else:
        s = altura_m / altura_original
    maior = max(caixa[k][1] - caixa[k][0] for k in range(3)) * s
    limitado = maior > LIMITE_M
    if limitado:
        s *= LIMITE_M / maior
    raizes = [o for o in cena.objects if o.parent is None]
    for o in raizes:
        o.scale = o.scale * s
        o.location = o.location * s
    bpy.context.view_layer.update()
    caixa = limites(cena)
    deslocamento = Vector((-(caixa[0][0] + caixa[0][1]) / 2, -(caixa[1][0] + caixa[1][1]) / 2, -caixa[2][0]))
    for o in raizes:
        o.location += deslocamento
    bpy.context.view_layer.update()
    return {"escala": round(s, 4), "altura_original": round(altura_original, 5), "limitado_a_5m": limitado}


def posar_mumbler(cena):
    # O FBX do Mumbler traz as peças no corpo "de pé e esmagado": o tronco de baixo (bone01 + bone10..15) fica enfiado entre
    # os braços e a corcunda (bone02 + cabeça bone03) fica reta. A referência do Miro (Campânula) é curvada: corcunda
    # inclinada para a frente, tronco de baixo menor e recuado, braços finos pendendo até o chão. Mexe nos vértices
    # (o esqueleto original é inútil: 21 ossos no mesmo ponto), antes de normalizar.
    for ob in cena.objects:
        if ob.type != "MESH" or not ob.vertex_groups:
            continue
        nomes = {g.index: g.name for g in ob.vertex_groups}
        dono = {}
        for v in ob.data.vertices:
            gs = [(g.weight, nomes[g.group]) for g in v.groups]
            dono[v.index] = max(gs)[1] if gs else None
        baixo = {"bone01", "bone10", "bone11", "bone12", "bone13", "bone14", "bone15"}
        ids = [i for i, d in dono.items() if d in baixo]
        if not ids:
            continue
        c = sum((ob.data.vertices[i].co for i in ids), Vector()) / len(ids)
        for i in ids:
            ob.data.vertices[i].co = MUMBLER_BAIXO + (ob.data.vertices[i].co - c) * MUMBLER_ESC_BAIXO
        piv = Vector((0, 0, MUMBLER_PIVO_Z))
        rot = Matrix.Rotation(math.radians(MUMBLER_INCLINACAO), 3, "X")
        for i, d in dono.items():
            if d in ("bone02", "bone03"):
                ob.data.vertices[i].co = piv + rot @ (ob.data.vertices[i].co - piv) + MUMBLER_SOBE
        ob.data.update()


def importar(caminho):
    ext = os.path.splitext(caminho)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=caminho)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=caminho)
    elif ext == ".blend":  # arquivo do Blender: traz só as malhas (câmera e luz da cena de origem ficam de fora)
        with bpy.data.libraries.load(caminho, link=False) as (de, para):
            para.objects = list(de.objects)
        for o in para.objects:
            if o is None:
                continue
            if o.type == "MESH":
                bpy.context.scene.collection.objects.link(o)
            else:
                bpy.data.objects.remove(o)
    else:
        raise ValueError("formato não suportado: " + ext)
    relinkar_texturas(caminho)
    for o in bpy.context.scene.objects:  # pose de repouso: sem isso o modelo abre na pose do 1º quadro da animação
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    for o in bpy.context.scene.objects:  # a animação do original sobrescreve escala/posição a cada atualização: solta a ação
        ad = o.animation_data
        if ad and ad.action:
            ad.action.use_fake_user = True  # continua no arquivo, para religar depois
            ad.action = None


def relinkar_texturas(caminho):
    # FBX de terceiros aponta para caminhos de outra máquina. As texturas ficam numa pasta irmã (textures/),
    # então procuramos pelo nome dentro da pasta do monstro (pai de source/).
    pasta = raiz_do_modelo(caminho)
    indice = {}

    def chave(nome):
        # "main (9).png" e "main_(9).png" são o mesmo arquivo: compara só letras e dígitos
        return re.sub(r"[^a-z0-9]", "", nome.lower())

    for raiz, _, nomes in os.walk(pasta):
        for n in nomes:
            indice.setdefault(chave(n), os.path.join(raiz, n))
    for img in bpy.data.images:
        if img.source != "FILE" or not img.filepath or os.path.exists(bpy.path.abspath(img.filepath)):
            continue
        achado = indice.get(chave(os.path.basename(img.filepath.replace("\\", "/"))))
        if achado:
            img.filepath = achado
            img.reload()


PROCEDURAL = False  # True enquanto se converte uma arma: material só de cor ganha textura suja gerada


def converter(caminho, nome, tipo="monstro", altura_m=None, maior_m=None):
    # monstro: altura 2,2 m · arma: maior lado 0,9 m · outro (item): altura 1,2 m
    global PROCEDURAL
    PROCEDURAL = tipo == "arma"
    if tipo == "arma":
        maior_m = maior_m or 0.9
    elif tipo == "outro":
        altura_m = altura_m or 1.2
    else:
        altura_m = altura_m or ALTURA_M
    pasta = os.path.join(SAIDA, nome)
    os.makedirs(pasta, exist_ok=True)
    janela = bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None
    # Refazer o mesmo modelo: tira a cena antiga e as imagens órfãs, para não duplicar nomes (.001).
    antiga = bpy.data.scenes.get(nome + "_PS2")
    if antiga:
        if janela and janela.scene == antiga:
            janela.scene = bpy.data.scenes.get("Scene") or bpy.data.scenes[0]
        bpy.data.scenes.remove(antiga)
    bpy.data.orphans_purge(do_recursive=True)
    cena = bpy.data.scenes.new(nome + "_PS2")
    if janela:
        janela.scene = cena
    with bpy.context.temp_override(window=janela, scene=cena, view_layer=cena.view_layers[0]):
        importar(caminho)
        for o in list(cena.objects):  # luzes, câmeras e peças de apresentação (base, esfera) não são do modelo
            if o.type in ("LIGHT", "CAMERA") or o.name in REMOVER.get(nome, ()):
                bpy.data.objects.remove(o)
        if nome == "Mumbler":
            posar_mumbler(cena)
        escala = normalizar(cena, altura_m, maior_m)
        malhas = [o for o in cena.objects if o.type == "MESH"]
        total = sum(tris(o) for o in malhas) or 1
        teto = TETO_TRIS[tipo]
        feitas, mats = {}, {}
        if nome not in SEM_FILTRO:
            for ob in malhas:
                soldar(ob)
            razao = min(1.0, teto / total)
            for ob in malhas:
                decimar(ob, razao)
            candidatas = candidatas_de_cor(raiz_do_modelo(caminho))
            for ob in malhas:
                for m in ob.data.materials:
                    if m and m.name not in mats:
                        mats[m.name] = achatar_material(m, pasta, feitas, candidatas)
        bpy.ops.outliner.orphans_purge(do_recursive=True)
    relatorio = {
        "nome": nome,
        "origem": caminho,
        "tipo": tipo,
        "tris_antes": total,
        "tris_depois": sum(tris(o) for o in malhas),
        "teto": teto,
        "malhas": [{"nome": o.name, "tris": tris(o), "ossos_grupos": len(o.vertex_groups)} for o in malhas],
        "armaduras": [{"nome": o.name, "ossos": len(o.data.bones)} for o in cena.objects if o.type == "ARMATURE"],
        "materiais": mats,
        "texturas": {i.name: list(i.size) for i in feitas.values()},
        "normalizacao": escala,
        "dimensoes_m": [round(b[1] - b[0], 3) for b in limites(cena)] if limites(cena) else None,
    }
    with open(os.path.join(pasta, nome + ".json"), "w", encoding="utf-8") as f:
        json.dump(relatorio, f, ensure_ascii=False, indent=2)
    if janela:  # enquadra o modelo na vista 3D para quem estiver olhando
        for area in janela.screen.areas:
            if area.type == "VIEW_3D":
                regiao = next(r for r in area.regions if r.type == "WINDOW")
                with bpy.context.temp_override(window=janela, area=area, region=regiao, scene=cena):
                    bpy.ops.view3d.view_all()
                area.spaces[0].shading.type = "MATERIAL"
    # .blend normal (abre direto pelo File > Open). Na sessão ao vivo ele leva todas as cenas abertas; para um arquivo
    # com só este modelo, rode headless (bloco abaixo).
    if bpy.app.background:  # headless: o arquivo fica só com a cena do modelo, que é a que abre
        for s in list(bpy.data.scenes):
            if s != cena:
                bpy.data.scenes.remove(s)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(pasta, nome + ".blend"), copy=True)
    return relatorio


if __name__ == "__main__" and "--" in sys.argv:
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--nome", required=True)
    p.add_argument("--tipo", default="monstro", choices=list(TETO_TRIS))
    a = p.parse_args(sys.argv[sys.argv.index("--") + 1 :])
    for o in list(bpy.data.objects):  # cena padrão (cubo, câmera, luz) fora do arquivo
        bpy.data.objects.remove(o)
    print("##JSON##" + json.dumps(converter(os.path.abspath(a.input), a.nome, a.tipo), ensure_ascii=False))
