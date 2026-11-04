"""Hero titanium plate, Cycles. Reproducible:
blender -b --factory-startup -P ti_plate.py -- --part field|frame --scale 2 --samples N --out x.png

field: one 640 x 640 CSS px tile of bead-blasted grade 2 titanium. Every noise runs on a torus of the tile's period,
       so the tile wraps exactly in x and y; the CSS repeats it from the plate's padding box and never stretches it.
frame: a 192 x 192 CSS px plate corner set, sliced 48 px in CSS (border-image, no fill). The plate sits flush in a
       chassis pocket: a 1.5 px shadow gap at the outer edge, a 2 px x 35 deg polished chamfer, and four ISO 10642 M4
       titanium countersunk screws 22 px in from both edges. The flat face is a holdout, so the field shows through.
Both use ti_common.ti_studio(), so the face reads the same tone in the field and around the screws.
"""
import bpy, bmesh, math, sys, argparse, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--part', default='field'); ap.add_argument('--scale', type=float, default=1)
ap.add_argument('--samples', type=int, default=64); ap.add_argument('--out', default='//ti.png')
ap.add_argument('--dome', type=float, default=0.62); ap.add_argument('--sun', type=float, default=0.6)
ap.add_argument('--denoise', type=int, default=1); ap.add_argument('--cone', type=float, default=8); ap.add_argument('--rim', type=float, default=1.4)
A = ap.parse_args(argv)
bpy.ops.wm.read_factory_settings(use_empty=True)
import ti_common as T
from ti_common import S, P
scn = bpy.context.scene; T.scn = scn
random.seed(23)

def plane(name, x0, y0, x1, y1, z, mat):
    bpy.ops.mesh.primitive_plane_add(size=1); ob = bpy.context.active_object; ob.name = name
    ob.location = ((x0 + x1) / 2 * S, -(y0 + y1) / 2 * S, z * S); ob.scale = ((x1 - x0) * S, (y1 - y0) * S, 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat); return ob

def holdout(name):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); h = nt.nodes.new('ShaderNodeHoldout'); nt.links.new(h.outputs[0], o.inputs['Surface'])
    return m

DARK = None
def countersunk(name, x, y, head_r, mat, socket_r, angle):
    """A countersunk head seated flush: a shallow dome face at z 0..0.1 px with a hex socket, and a 0.5 px dark
    countersink ring round it."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=head_r * S, depth=0.6 * S, location=(x * S, -y * S, -0.2 * S))
    hd = bpy.context.active_object; hd.name = name; hd.data.materials.append(mat)
    bv = hd.modifiers.new('edge', 'BEVEL'); bv.width = 0.5 * S; bv.segments = 3; bv.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier='edge')
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=socket_r * S, depth=4 * S, location=(x * S, -y * S, 0))
    sk = bpy.context.active_object; sk.rotation_euler = (0, 0, angle)
    bo = hd.modifiers.new('socket', 'BOOLEAN'); bo.operation = 'DIFFERENCE'; bo.object = sk; bo.solver = 'EXACT'
    bpy.context.view_layer.objects.active = hd; bpy.ops.object.modifier_apply(modifier='socket')
    bpy.data.objects.remove(sk)
    # The socket's floor: a dark hexagon just below the face, so the socket reads as a recess.
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=socket_r * S, depth=0.2 * S, location=(x * S, -y * S, -0.6 * S))
    fl = bpy.context.active_object; fl.rotation_euler = (0, 0, angle); fl.data.materials.append(DARK)
    return hd

if A.part == 'field':
    W = H = 640
    ti = T.mat_titanium('ti-blasted', T=W * S)
    # The plane runs past the frame so the pixel filter at the image edge sees titanium, not the void beyond it;
    # the noise is periodic, so the overhang continues the tile seamlessly.
    plane('field', -32, -32, W + 32, H + 32, 0, ti)
    T.ti_studio(A.dome, A.sun, A.cone, A.rim)
    T.camera(W / 2 * S, -H / 2 * S, W * S, W * A.scale, H * A.scale)
    T.render_setup(A.samples, A.out, denoise=bool(A.denoise))
elif A.part == 'frame':
    W = H = 192; G, CH = 1.5, 2.0
    ti = T.mat_titanium('ti-blasted', T=640 * S); pol = T.mat_titanium('ti-polished', T=640 * S, finish='polished')
    scr = T.mat_titanium('ti-screw', T=640 * S, seed=2.3, finish='lapped')   # grade 5 heads, lapped
    face = holdout('face')
    dark = T.node_mat('gap')[0]; b = dark.node_tree.nodes['Principled BSDF']; globals()['DARK'] = dark
    T.inp(b, 'Base Color').default_value = (0.004, 0.004, 0.0045, 1); T.inp(b, 'Roughness').default_value = 0.8
    # The pocket floor 4 mm down shows in the gap; the chassis outside the canvas is not drawn.
    plane('gap-floor', -4, -4, W + 4, H + 4, -8, dark)
    # The plate: a slab whose top edge is broken by a 35 deg chamfer (2 px across, 1.4 px down), so the upper-left
    # chamfer catches the key light and the lower-right one falls dark.
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=((W - 2 * G) * S, (H - 2 * G) * S, 8 * S), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(W / 2 * S, -H / 2 * S, -4 * S), verts=bm.verts)
    top = [f for f in bm.faces if f.normal.z > 0.99]
    drop = CH * math.tan(math.radians(35))
    # inset_region measures thickness along the slope: this gives exactly CH across.
    ins = bmesh.ops.inset_region(bm, faces=top, thickness=math.hypot(CH, drop) * S, depth=drop * S)
    bmesh.ops.translate(bm, vec=(0, 0, -drop * S), verts=list(bm.verts))
    me = bpy.data.meshes.new('plate'); bm.to_mesh(me); bm.free()
    pl = bpy.data.objects.new('plate', me); scn.collection.objects.link(pl)
    me.materials.append(face); me.materials.append(pol)
    for f in pl.data.polygons:
        f.material_index = 0 if (f.normal.z > 0.999 and f.center.z > -1e-5) else 1
    # Countersink bores through the face, so the heads seat in the plate and their sockets read as recesses.
    for (x, y) in ((22, 22), (W - 22, 22), (22, H - 22), (W - 22, H - 22)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=8.2 * S, depth=2 * S, location=(x * S, -y * S, 0))
        bo = pl.modifiers.new('bore', 'BOOLEAN'); bo.operation = 'DIFFERENCE'; bo.object = bpy.context.active_object; bo.solver = 'EXACT'
        cutter = bpy.context.active_object; bpy.context.view_layer.objects.active = pl; bpy.ops.object.modifier_apply(modifier='bore'); bpy.data.objects.remove(cutter)
    for f in pl.data.polygons:
        f.material_index = 0 if (f.normal.z > 0.999 and f.center.z > -1e-5) else 1
    for i, (x, y) in enumerate(((22, 22), (W - 22, 22), (22, H - 22), (W - 22, H - 22))):
        countersunk(f'screw{i}', x, y, 8, scr, 2.5, random.uniform(0, math.pi))
        bpy.ops.mesh.primitive_torus_add(major_radius=8.25 * S, minor_radius=0.35 * S, location=(x * S, -y * S, -0.15 * S))
        ring = bpy.context.active_object; ring.data.materials.append(dark)
    T.ti_studio(A.dome, A.sun, A.cone, A.rim)
    T.camera(W / 2 * S, -H / 2 * S, W * S, W * A.scale, H * A.scale)
    T.render_setup(A.samples, A.out, transparent=True)
elif A.part == 'oxide-field':
    # The head plate's face: one 512 x 512 CSS px tile of bead-blasted black-oxide steel, wrapping exactly.
    W = H = 512
    plane('field', -32, -32, W + 32, H + 32, 0, T.mat_oxide('oxide', T=W * S))
    T.ti_studio(A.dome, A.sun, A.cone, A.rim)
    T.camera(W / 2 * S, -H / 2 * S, W * S, W * A.scale, H * A.scale)
    T.render_setup(A.samples, A.out, denoise=bool(A.denoise))
elif A.part == 'head-frame':
    # The head plate's edge: a 6 mm black-oxide plate bolted 3 mm proud of the chassis, its top edge broken by a 2 px
    # 35 deg chamfer, an M4 socket cap screw in a counterbore 16 px in from both edges at each corner, and its soft
    # shadow on the chassis in a 6 px margin right and below. 160 x 400 CSS px plus the margin; the CSS uses the top
    # crop on the header and the bottom crop on the key bank, so the two read as one plate. The face is a holdout.
    W, H, MG, CH = 160, 400, 6, 2.0
    ox = T.mat_oxide('oxide', T=512 * S); pol = T.mat_titanium('edge', T=640 * S, finish='polished')
    m_edge, nte, be = T.node_mat('oxide-edge'); be.inputs['Base Color'].default_value = (0.2, 0.205, 0.21, 1)
    be.inputs['Metallic'].default_value = 1.0; be.inputs['Roughness'].default_value = 0.22
    face = holdout('face')
    dark = T.node_mat('socket')[0]; dark.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.006, 0.006, 0.007, 1)
    globals()['DARK'] = dark
    # The chassis below: a shadow catcher, so only the plate's shadow lands on the page's own ground.
    ground = plane('chassis', -40, -40, W + 40, H + 40, -6, dark); ground.is_shadow_catcher = True
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(W * S, H * S, 6 * S), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(W / 2 * S, -H / 2 * S, -3 * S), verts=bm.verts)
    drop = CH * math.tan(math.radians(35))
    bmesh.ops.inset_region(bm, faces=[f for f in bm.faces if f.normal.z > 0.99], thickness=math.hypot(CH, drop) * S, depth=drop * S)
    bmesh.ops.translate(bm, vec=(0, 0, -drop * S), verts=list(bm.verts))
    me = bpy.data.meshes.new('plate'); bm.to_mesh(me); bm.free()
    pl = bpy.data.objects.new('plate', me); scn.collection.objects.link(pl); me.materials.append(face); me.materials.append(m_edge)
    corners = ((16, 16), (W - 16, 16), (16, H - 16), (W - 16, H - 16))
    for (x, y) in corners:
        bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=8.2 * S, depth=10 * S, location=(x * S, -y * S, 0))
        cutter = bpy.context.active_object
        bo = pl.modifiers.new('cb', 'BOOLEAN'); bo.operation = 'DIFFERENCE'; bo.object = cutter; bo.solver = 'EXACT'
        bpy.context.view_layer.objects.active = pl; bpy.ops.object.modifier_apply(modifier='cb'); bpy.data.objects.remove(cutter)
    for f in pl.data.polygons:
        f.material_index = 0 if (f.normal.z > 0.999 and f.center.z > -1e-5) else 1
    scr = T.node_mat('cap')[0]; sb = scr.node_tree.nodes['Principled BSDF']
    sb.inputs['Base Color'].default_value = (0.09, 0.092, 0.096, 1); sb.inputs['Metallic'].default_value = 1; sb.inputs['Roughness'].default_value = 0.28
    for (x, y) in corners:
        # Counterbore floor, then the cap screw seated in it: chamfered head, hex socket, top 0.6 px below the face.
        bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=8.2 * S, depth=0.4 * S, location=(x * S, -y * S, -4.6 * S))
        bpy.context.active_object.data.materials.append(dark)
        bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=7 * S, depth=4.0 * S, location=(x * S, -y * S, -2.6 * S))
        hd = bpy.context.active_object; hd.data.materials.append(scr)
        bv = hd.modifiers.new('e', 'BEVEL'); bv.width = 1.0 * S; bv.segments = 3; bv.limit_method = 'ANGLE'
        bpy.context.view_layer.objects.active = hd; bpy.ops.object.modifier_apply(modifier='e')
        ang = random.uniform(0, math.pi)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=3.0 * S, depth=6 * S, location=(x * S, -y * S, -0.6 * S))
        sk = bpy.context.active_object; sk.rotation_euler = (0, 0, ang)
        bo = hd.modifiers.new('s', 'BOOLEAN'); bo.operation = 'DIFFERENCE'; bo.object = sk; bo.solver = 'EXACT'
        bpy.context.view_layer.objects.active = hd; bpy.ops.object.modifier_apply(modifier='s'); bpy.data.objects.remove(sk)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=3.0 * S, depth=0.2 * S, location=(x * S, -y * S, -3.3 * S))
        fl = bpy.context.active_object; fl.rotation_euler = (0, 0, ang); fl.data.materials.append(dark)
    T.ti_studio(A.dome, A.sun, A.cone, A.rim)
    T.camera((W + MG) / 2 * S, -(H + MG) / 2 * S, (W + MG) * S, (W + MG) * A.scale, (H + MG) * A.scale)
    T.render_setup(A.samples, A.out, transparent=True)
bpy.ops.render.render(write_still=True)
