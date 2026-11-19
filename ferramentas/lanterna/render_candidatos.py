import bpy, os, math, mathutils
raiz = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
base = os.path.join(raiz, "modelos 3d", "PsxFlashLights")
saida = os.environ.get("LANT_OUT")
os.makedirs(saida, exist_ok=True)

def preparar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = 480; sc.render.resolution_y = 480
    sc.display.shading.light = 'FLAT'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.background_type = 'WORLD'
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.02,0.02,0.02)
    sc.view_settings.view_transform = 'Standard'
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam

def render(sc, cam, obj, nome, direcoes):
    # centro e tamanho
    cs = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    c = sum(cs, mathutils.Vector())/8
    r = max((v-c).length for v in cs)
    for tag, d in direcoes.items():
        d = mathutils.Vector(d).normalized()
        cam.data.type='ORTHO'; cam.data.ortho_scale = r*2.3
        cam.location = c + d*5
        cam.rotation_euler = (-d).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath = os.path.join(saida, f"{nome}_{tag}.png")
        bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    for n in (1,2,3):
        for v in (1,2):
            sc, cam = preparar()
            bpy.ops.import_scene.fbx(filepath=os.path.join(base,"FBX",f"FlashLight_00{n}.fbx"))
            o = [o for o in bpy.data.objects if o.type=='MESH'][0]
            img = bpy.data.images.load(os.path.join(base,"Texture",f"Variation{v}",f"FlashLight_{n}_.png"))
            m = o.data.materials[0]; m.use_nodes=True
            nt = m.node_tree
            for nd in list(nt.nodes): nt.nodes.remove(nd)
            tx = nt.nodes.new('ShaderNodeTexImage'); tx.image=img; tx.interpolation='Closest'
            bs = nt.nodes.new('ShaderNodeBsdfPrincipled'); out = nt.nodes.new('ShaderNodeOutputMaterial')
            nt.links.new(tx.outputs[0], bs.inputs[0]); nt.links.new(bs.outputs[0], out.inputs[0])
            m.node_tree.nodes.active = tx
            bpy.context.view_layer.update()
            render(sc, cam, o, f"c{n}_v{v}", {"x+":(1,0,0),"x-":(-1,0,0),"y+":(0,1,0),"y-":(0,-1,0),"z+":(0,0,1),"3q":(1,-1,0.7)})
