"""PF maker's seal mount, Cycles scene. Reproducible:
blender -b --factory-startup -P seal_scene.py -- --option pocket|raised --scale 1|2 --samples N --out out.png

The canonical emblem raster (brand/emblem/PF_MARK_G_EMBLEM_R3.webp, 1600 x 1849) is NOT rendered or modified here.
This scene renders only the mount around it, in the emblem's own pixel frame (1 art px = 0.01 m), with an opaque
stand-in slab where the emblem sits so the gap, contact shadow and occlusion are physically correct. The site places
the unchanged emblem image exactly over the stand-in. Canvas: x -120..1720, y -120..1972 art px (460 x 523 CSS px
when the emblem is 400 CSS px wide, i.e. 0.25 CSS px per art px).
"""
import bpy, bmesh, math, sys, argparse, random
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--option', default='pocket'); ap.add_argument('--scale', type=float, default=1)
ap.add_argument('--samples', type=int, default=64); ap.add_argument('--out', default='//seal.png')
A = ap.parse_args(argv)
S = 0.01; random.seed(11)
X0, X1, Y0, Y1 = -120, 1720, -120, 1972
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
def P(x, y, z=0.0): return Vector((x * S, -y * S, z * S))

def node_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); b = nt.nodes.new('ShaderNodeBsdfPrincipled'); nt.links.new(b.outputs[0], out.inputs['Surface'])
    return m, nt, b
def inp(b, n): return b.inputs[n]

def mat_steel(name, color, metal, rough, var=0.25, rvar=0.08, scale=1.2, edge=0.0, brushed=0.0, aniso=0.0, spec=None):
    """Machined or structural steel: tone/roughness drift, optional linear brushing along X, optional worn convex edges."""
    m, nt, b = node_mat(name); N = nt.nodes; L = nt.links.new
    tc = N.new('ShaderNodeTexCoord')
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = scale; nz.inputs['Detail'].default_value = 8; L(tc.outputs['Object'], nz.inputs[0])
    ramp = N.new('ShaderNodeValToRGB'); e0, e1 = ramp.color_ramp.elements
    e0.position = .3; e0.color = (*[c * (1 - var) for c in color], 1); e1.position = .7; e1.color = (*[c * (1 + var) for c in color], 1)
    L(nz.outputs['Fac'], ramp.inputs['Fac'])
    col = ramp.outputs['Color']
    if edge:
        ao = N.new('ShaderNodeAmbientOcclusion'); ao.inside = True; ao.samples = 8; ao.inputs['Distance'].default_value = 0.05
        em = N.new('ShaderNodeMapRange'); em.inputs['From Min'].default_value = 0.75; em.inputs['From Max'].default_value = 1.0
        em.inputs['To Min'].default_value = edge; em.inputs['To Max'].default_value = 0.0; L(ao.outputs['AO'], em.inputs['Value'])
        mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; L(em.outputs[0], mx.inputs['Factor']); L(col, mx.inputs[6]); mx.inputs[7].default_value = (0.46, 0.45, 0.43, 1)
        col = mx.outputs[2]
    L(col, inp(b, 'Base Color')); inp(b, 'Metallic').default_value = metal
    if spec is not None: inp(b, 'Specular IOR Level').default_value = spec
    mr = N.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value = rough - rvar; mr.inputs['To Max'].default_value = rough + rvar
    src = nz
    if brushed:
        mp = N.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (0.25, 140, 2); L(tc.outputs['Object'], mp.inputs[0])
        bn = N.new('ShaderNodeTexNoise'); bn.inputs['Scale'].default_value = 3; bn.inputs['Detail'].default_value = 10; L(mp.outputs[0], bn.inputs[0])
        bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = brushed; bp.inputs['Distance'].default_value = 0.0004
        L(bn.outputs['Fac'], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal')); src = bn
    L(src.outputs['Fac'], mr.inputs['Value']); L(mr.outputs[0], inp(b, 'Roughness'))
    if aniso:
        inp(b, 'Anisotropic').default_value = aniso
        tg = N.new('ShaderNodeTangent'); tg.direction_type = 'RADIAL'; tg.axis = 'Y'; L(tg.outputs[0], inp(b, 'Tangent'))
    return m

M = {
 # Gen I chassis: older hot-rolled structural steel, mottled, worn on its convex edges.
 'chassis': mat_steel('gen1-chassis', (0.025, 0.025, 0.024), 0.3, 0.58, var=0.16, rvar=0.07, scale=7.0, edge=0.45),
 # Protective frame: black-oxide satin steel. The oxide is treated as mostly dielectric so the frame does not
 # mirror the studio card and stays as dark as the hero surround; only the bevels pick up the key.
 'frame': mat_steel('blackened-frame', (0.022, 0.023, 0.025), 0.2, 0.48, var=0.08, rvar=0.03, scale=6.0, edge=0.0, brushed=0.06),
 'plate-edge': mat_steel('plate-edge', (0.34, 0.335, 0.33), 0.9, 0.42, var=0.05, rvar=0.03, scale=6.0),
 'land': mat_steel('ground-land', (0.05, 0.05, 0.049), 0.3, 0.7, var=0.06, rvar=0.03, scale=8.0, brushed=0.1),
 'pocket': mat_steel('bored-pocket', (0.02, 0.02, 0.021), 0.6, 0.5, var=0.2),
 'standin': mat_steel('emblem-standin', (0.03, 0.03, 0.032), 0.8, 0.4, var=0.0),
 'screw': mat_steel('screw', (0.05, 0.05, 0.052), 1.0, 0.3, var=0.1, edge=0.6),
 'turned': mat_steel('turned-standoff', (0.5, 0.5, 0.49), 1.0, 0.34, var=0.05),
}

def prism(name, poly, z0, z1, mat, bevel=0.0, seg=1, back_off=(0, 0)):
    bm = bmesh.new(); vb = [bm.verts.new(P(x + back_off[0], y + back_off[1], z0)) for x, y in poly]; vt = [bm.verts.new(P(x, y, z1)) for x, y in poly]
    bm.faces.new(list(reversed(vb))); bm.faces.new(vt)
    for i in range(len(poly)): j = (i + 1) % len(poly); bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); ob = bpy.data.objects.new(name, me); scn.collection.objects.link(ob)
    if bevel: md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = seg; md.limit_method = 'ANGLE'
    ob.data.materials.append(M[mat]); return ob

def cham_rect(x0, y0, x1, y1, ct, cb, grow=0.0):
    """Rectangle with 45-degree corner cuts (ct top legs, cb bottom legs), grown outward by `grow`."""
    x0 -= grow; y0 -= grow; x1 += grow; y1 += grow; k = grow * (math.sqrt(2) - 1)
    ct += k; cb += k
    return [(x0 + ct, y0), (x1 - ct, y0), (x1, y0 + ct), (x1, y1 - cb), (x1 - cb, y1), (x0 + cb, y1), (x0, y1 - cb), (x0, y0 + ct)]

def cyl(name, x, y, z0, z1, rad, mat, bevel=0.8, verts=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=rad * S, depth=abs(z1 - z0) * S, vertices=verts)
    ob = bpy.context.active_object; ob.name = name; ob.location = P(x, y, (z0 + z1) / 2)
    if bevel: md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = 3; md.limit_method = 'ANGLE'
    for pg in ob.data.polygons: pg.use_smooth = True
    ob.data.materials.append(M[mat]); return ob

def boolean(target, cutter):
    md = target.modifiers.new('bool', 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.object = cutter; md.solver = 'EXACT'
    if 'bev' in target.modifiers: target.modifiers.move(target.modifiers.find('bool'), 0)
    cutter.hide_render = True; cutter.hide_viewport = True

def sunk_screw(target, x, y, zface, rh, wear_turn):
    cut = cyl('cb', x, y, zface - rh * 0.7, zface + 60, rh + 5, 'screw', bevel=0); boolean(target, cut)
    h = cyl('screw', x, y, zface - rh * 0.7, zface + rh * 0.2, rh, 'screw', bevel=rh * 0.18)
    bpy.ops.mesh.primitive_cylinder_add(radius=rh * 0.42 * S, depth=rh * 0.9 * S, vertices=6)
    hx = bpy.context.active_object; hx.location = P(x, y, zface + rh * 0.2); hx.rotation_euler = (0, 0, wear_turn); boolean(h, hx)

# Emblem footprint measured from the raster's alpha: x 93..1564, y 93..1795, top corner cuts ~73 px, bottom ~112 px.
EM = (93, 93, 1564, 1795, 73, 112)
foot = cham_rect(*EM)

chassis = prism('chassis', [(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)], -120, 0, 'chassis', bevel=6, seg=1)
if A.option == 'pocket':
    # Pocketed seal: the emblem sits in a bored pocket; a 10 px shadow gap separates it from the frame's machined edge.
    pocket = cham_rect(*EM, grow=10)
    boolean(chassis, prism('pocket-cut', pocket, -30, 60, 'pocket', 0))
    prism('pocket-floor', pocket, -30, -29.5, 'pocket')
    frame_open = pocket
    standin = prism('standin', foot, -29, 10, 'standin', 0)
    frame_z = 24
else:
    # Raised inspection plate: the emblem stands 40 px proud of the chassis on four turned stand-offs behind its own
    # printed corner screws, so its shadow falls lower right onto a machined land.
    frame_open = cham_rect(*EM, grow=60)
    prism('land', frame_open, -1, 1, 'land', 0)
    # Turned stand-offs at the four corners; the plate's corner chamfers expose about half of each post and its
    # captive screw, so the fixing is readable without touching the emblem area.
    for (x, y, r) in [(104, 104, 34), (1553, 104, 34), (110, 1778, 40), (1547, 1778, 40)]:
        cyl('standoff', x, y, 0, 64, r, 'turned', bevel=2.5)
        sunk_screw(cyl('standoff-cap', x, y, 64, 70, r * 0.92, 'turned', bevel=1.5), x, y, 70, r * 0.5, random.uniform(0, 1))
    # Plate body: the back face is offset down-right, so the orthographic camera sees a narrow machined side wall on
    # the shadow side (plate thickness) while the front face stays exactly on the emblem footprint. The front is grown
    # 4 art px with a chamfer that catches the key light as a hairline on the lit edges.
    standin = prism('plate-body', cham_rect(*EM, grow=4), 70, 100, 'plate-edge', bevel=4, seg=1, back_off=(10, 13))
    frame_z = 24
# Protective outer frame: separate part, restrained 45-degree chamfers, a 3 px reveal to the chassis edge, four screws.
fr = prism('frame', cham_rect(X0 + 22, Y0 + 22, X1 - 22, Y1 - 22, 30, 30), 0, frame_z, 'frame', bevel=7, seg=1)
boolean(fr, prism('frame-open', frame_open, -10, 80, 'frame', 0))
for i, (x, y) in enumerate([(X0 + 62, Y0 + 62), (X1 - 62, Y0 + 62), (X0 + 62, Y1 - 62), (X1 - 62, Y1 - 62)]):
    sunk_screw(fr, x, y, frame_z, 20, 0.35 + i * 0.41)

def area(name, loc, target, size, power, color, spec=1.0):
    ld = bpy.data.lights.new(name, 'AREA'); ld.shape = 'RECTANGLE'; ld.size = size[0]; ld.size_y = size[1]; ld.energy = power; ld.color = color
    ld.specular_factor = spec
    ob = bpy.data.objects.new(name, ld); scn.collection.objects.link(ob); ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

cx, cy, k = (X0 + X1) / 2 * S, -(Y0 + Y1) / 2 * S, 1.5
area('key-softbox', (cx - 5 * k, cy + 8 * k, 3.6 * k), (cx + 1 * k, cy - 1.5 * k, 0), (4.5 * k, 1.6 * k), 8000 * k * k, (1.0, 0.94, 0.85))
area('rim-strip', (cx + 9.5 * k, cy + 1.5 * k, 5 * k), (cx + 3 * k, cy, 0), (0.5 * k, 6 * k), 900 * k * k, (0.9, 0.95, 1.0))
if A.option == 'raised':
    # Compact key from upper left at about 50 degrees: a soft but directional contact shadow from the 70 px air gap.
    area('shadow-key', (cx - 6.5, cy + 7.5, 9.5), (cx, cy, 0), (2.2, 2.2), 1000, (1.0, 0.95, 0.88))
area('top-bounce', (cx, cy + 9 * k, 3 * k), (cx, cy, 0), (14 * k, 2 * k), 1000 * k * k, (1.0, 0.98, 0.95))
bpy.ops.mesh.primitive_plane_add(size=1); card = bpy.context.active_object
card.location = (cx, cy + 0.8 * k, 24 * k); card.scale = (40 * k, 22 * k, 1); card.rotation_euler = (math.pi, 0, 0)
cm, nt, b = node_mat('card'); nt.nodes.remove(b)
em = nt.nodes.new('ShaderNodeEmission'); tcn = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
rmp = nt.nodes.new('ShaderNodeValToRGB'); e0, e1 = rmp.color_ramp.elements; e0.position = 0.4; e0.color = (0, 0, 0, 1); e1.position = 0.62; e1.color = (0.8, 0.79, 0.77, 1)
nt.links.new(tcn.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Y'], rmp.inputs['Fac']); nt.links.new(rmp.outputs['Color'], em.inputs['Color'])
# The camera-facing reflection card is kept weak here: at the chain's 0.45 it turns the flat black-oxide frame light grey.
em.inputs['Strength'].default_value = 0.12; nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface']); card.data.materials.append(cm)
card.visible_camera = False; card.visible_shadow = False; card.visible_diffuse = False
w = bpy.data.worlds.new('black'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.002, 0.002, 0.0022, 1); scn.world = w

cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = (X1 - X0) * S; cd.sensor_fit = 'HORIZONTAL'
cam = bpy.data.objects.new('cam', cd); scn.collection.objects.link(cam); cam.location = (cx, cy, 40); scn.camera = cam
scn.render.resolution_x = int((X1 - X0) * 0.25 * A.scale); scn.render.resolution_y = int(round((Y1 - Y0) * 0.25 * A.scale)); scn.render.resolution_percentage = 100
scn.render.engine = 'CYCLES'; c = scn.cycles; c.samples = A.samples; c.use_denoising = True; c.denoiser = 'OPENIMAGEDENOISE'
c.max_bounces = 10; c.glossy_bounces = 6
scn.view_settings.view_transform = 'AgX'; scn.view_settings.look = 'AgX - Medium High Contrast'
# The mount sits in the dark hero surround (about sRGB 25-30); at the chain studio's exposure the black-oxide frame reads
# light grey, because the studio is built to lift dark steel. -1.8 EV puts the frame just above the surround.
scn.view_settings.exposure = -1.8
scn.render.image_settings.file_format = 'PNG'; scn.render.image_settings.color_depth = '16'; scn.render.filepath = A.out
bpy.ops.render.render(write_still=True)
