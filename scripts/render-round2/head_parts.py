"""Round 3 head plate hardware, Cycles: the six-key latching bank and the chain that threads it. Reproducible:
blender -b --factory-startup -P head_parts.py -- --part key-rest|key-current|key-pressed|coupler|drop|anchor-l|anchor-r|anchor-t|anchor-b
        --scale 2 --samples N --out x.png

Same canvases, bores and registration as the Round 2 parts in ui_parts.py, so every CSS offset still holds:
- keys 200 x 64 CSS px: ears 0..22 and 178..200 with bores at x 8.5 / 191.5, y 32, r 4.2; housing 16..184;
- coupler 70 x 32: ear bores at x 12 and 58, y 16 (46 apart);
- drop 32 x 100: bores at y 10 and 90 (80 apart), for the snaking layouts;
- anchors 36 x 32: a clevis screwed to the plate and one link into the end key's outer bore (bore at x 28 or 8);
  on phones, where the plate has no side room, anchors 24 x 40 above or below the end key (bore at y 34 or 6).
What changes is how they are built and lit:
- the housings are brushed stainless bezels on the black-oxide head plate, the caps brushed along their length, the current key's cap a
  bead-blasted stainless cap latched 4 px down with its champagne witness line, the pressed key's cap seated 4 px;
- the ears are 3.2 px tongues, so the chain's end links pass down through the bores and round the ear tips, and the
  middle link lies flat between them: the links are threaded, not laid on top;
- every part sits on the head plate (a shadow catcher) and the chain's tongues and housings are occluders, so the
  sprites carry their own contact shadows and the links disappear under the ears where they pass beneath them.
Lighting is ti_common.ti_studio() (all distant), so a 3-sliced key reads the same however far it is stretched. Its
low band reaches the horizon here, so the housings' 45 deg machined edges catch the key light. The
key light casts no shadow here (it would throw them 50 px), so the contact shadows come from the overhead dome.
"""
import bpy, bmesh, math, sys, argparse, os, random
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--part', default='key-rest'); ap.add_argument('--scale', type=float, default=2)
ap.add_argument('--samples', type=int, default=128); ap.add_argument('--out', default='//part.png')
ap.add_argument('--dome', type=float, default=0.62); ap.add_argument('--sun', type=float, default=0.6)
ap.add_argument('--cone', type=float, default=8); ap.add_argument('--rim', type=float, default=1.4)
ap.add_argument('--band-lo', type=float, default=-4.0)
A = ap.parse_args(argv)
bpy.ops.wm.read_factory_settings(use_empty=True)
import ti_common as T
from ti_common import S, P
scn = bpy.context.scene; T.scn = scn
random.seed(31)
PLATE_Z = -10.2

def box(name, x0, y0, z0, x1, y1, z1, mat, bevel=1.0, seg=2):
    bpy.ops.mesh.primitive_cube_add(size=1); ob = bpy.context.active_object; ob.name = name
    ob.location = P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); ob.scale = ((x1 - x0) * S, (y1 - y0) * S, (z1 - z0) * S)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = seg; md.limit_method = 'ANGLE'
    ob.data.materials.append(mat); return ob

def cyl(name, x, y, z0, z1, r, mat, verts=64, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r * S, depth=(z1 - z0) * S, location=P(x, y, (z0 + z1) / 2))
    ob = bpy.context.active_object; ob.name = name
    if bevel:
        md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = 3; md.limit_method = 'ANGLE'
    for pg in ob.data.polygons: pg.use_smooth = True
    if mat: ob.data.materials.append(mat)
    return ob

def cut(target, cutter):
    md = target.modifiers.new('bool', 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.object = cutter; md.solver = 'EXACT'
    mods = target.modifiers
    if 'bev' in mods: mods.move(mods.find('bool'), 0)
    cutter.hide_render = True; cutter.hide_viewport = True

def cap_screw(name, x, y, zface, rh, mat, socket):
    h = cyl(name, x, y, zface, zface + rh * 0.9, rh, mat, bevel=rh * 0.2)
    hx = cyl(name + '-hex', x, y, zface + rh * 0.35, zface + rh * 2, rh * 0.42, None, verts=6); hx.rotation_euler = (0, 0, random.uniform(0, 1))
    cut(h, hx)
    fl = cyl(name + '-floor', x, y, zface + rh * 0.3, zface + rh * 0.4, rh * 0.42, socket, verts=6); fl.rotation_euler = hx.rotation_euler
    return h

def link_obj(name, cx, cy, z, theta, phi, a, R, r, mat):
    """A forged link: two semicircles of radius R joined by straights of length 2a, wire radius r, lying in its own
    xy plane, then turned theta about z and phi about its long axis (phi = pi/2 stands it on edge)."""
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r * S; cu.bevel_resolution = 10
    sp = cu.splines.new('POLY'); pts = []
    n, m = 56, 12
    for i in range(n + 1): t = -math.pi / 2 + math.pi * i / n; pts.append((a + R * math.cos(t), R * math.sin(t)))
    for i in range(1, m): pts.append((a - 2 * a * i / m, R))
    for i in range(n + 1): t = math.pi / 2 + math.pi * i / n; pts.append((-a + R * math.cos(t), R * math.sin(t)))
    for i in range(1, m): pts.append((-a + 2 * a * i / m, -R))
    sp.points.add(len(pts) - 1)
    for pt, (x, y) in zip(sp.points, pts): pt.co = (x * S, y * S, 0, 1)
    sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name + '-c', cu); scn.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob); mo = bpy.data.objects.new(name, me); scn.collection.objects.link(mo)
    for pg in me.polygons: pg.use_smooth = True
    mo.matrix_world = Matrix.Translation(P(cx, cy, z)) @ Matrix.Rotation(-theta, 4, 'Z') @ Matrix.Rotation(phi, 4, 'X')
    tex = bpy.data.textures.get('forge') or bpy.data.textures.new('forge', 'CLOUDS'); tex.noise_scale = 0.16; tex.noise_depth = 2
    dm = mo.modifiers.new('forge', 'DISPLACE'); dm.texture = tex; dm.texture_coords = 'GLOBAL'; dm.strength = 0.004; dm.mid_level = 0.5
    mo.data.materials.append(mat); return mo

# ---------------- materials ----------------
def satin(name, color, metal, rough, brushed=0.0):
    m, nt, b = T.node_mat(name); b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    if brushed: T.brush(nt, b, strength=0.05, axis='x', streaks=brushed)
    return m
HOUSING = satin('bezel-stainless', (0.5, 0.5, 0.49), 1.0, 0.3, brushed=0.9)   # machined, brushed bezel
CAP = satin('cap-brushed', (0.11, 0.112, 0.118), 1.0, 0.3, brushed=1.4)
CAP_ON = satin('cap-stainless', (0.9, 0.9, 0.89), 1.0, 0.24, brushed=0.4)    # bead-blasted, latched
SCREW = satin('screw', (0.1, 0.102, 0.106), 1.0, 0.3)
SOCKET = satin('socket', (0.006, 0.006, 0.007), 0.0, 0.9)
CHAMP = satin('champagne', (0.84, 0.72, 0.52), 1.0, 0.2, brushed=0.4)
PIN = satin('pin', (0.62, 0.62, 0.6), 1.0, 0.22)

def forged(name):
    """Clean forged steel for the chain: blackened stock with bright wear on the crowns that bear."""
    m, nt, b = T.node_mat(name); N = nt.nodes; L = nt.links.new
    b.inputs['Metallic'].default_value = 1.0
    geo = N.new('ShaderNodeNewGeometry'); lw = N.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.35
    crown = N.new('ShaderNodeMapRange'); L(lw.outputs['Facing'], crown.inputs['Value'])
    crown.inputs['From Min'].default_value = 0.0; crown.inputs['From Max'].default_value = 0.55
    crown.inputs['To Min'].default_value = 1.0; crown.inputs['To Max'].default_value = 0.0
    col = N.new('ShaderNodeMix'); col.data_type = 'RGBA'; L(crown.outputs[0], col.inputs['Factor'])
    col.inputs['A'].default_value = (0.09, 0.088, 0.086, 1); col.inputs['B'].default_value = (0.55, 0.54, 0.52, 1)
    L(col.outputs['Result'], b.inputs['Base Color'])
    rr = N.new('ShaderNodeMapRange'); L(crown.outputs[0], rr.inputs['Value']); rr.inputs['To Min'].default_value = 0.42; rr.inputs['To Max'].default_value = 0.2
    L(rr.outputs[0], b.inputs['Roughness'])
    return m
LINK = forged('forged-link')

def catcher_plate(x0, y0, x1, y1):
    bpy.ops.mesh.primitive_plane_add(size=1); pl = bpy.context.active_object; pl.name = 'plate'
    pl.location = P((x0 + x1) / 2, (y0 + y1) / 2, PLATE_Z); pl.scale = ((x1 - x0) * S, (y1 - y0) * S, 1)
    pl.data.materials.append(SOCKET); pl.is_shadow_catcher = True; return pl

def occluder(ob):
    """A part another sprite draws: it hides what is behind it and takes shadows, but adds no pixels of its own."""
    ob.is_shadow_catcher = True; return ob

def key(state, render=True):
    """The key body. Ears are 3.2 px tongues at z -4.0..-0.8 so links can pass through the bores."""
    hs = box('housing', 16, 6, PLATE_Z, 184, 58, 6, HOUSING, bevel=2.4, seg=3)
    cut(hs, box('recess', 22, 13, 0, 178, 51, 20, HOUSING, bevel=0))
    ears = []
    for x0, x1, hx in ((0, 24, 8.5), (176, 200, 191.5)):
        ear = box('ear', x0, 22, -4.0, x1, 42, -0.8, HOUSING, bevel=1.2, seg=2)
        cut(ear, cyl('bore', hx, 32, -20, 10, 4.2, None, bevel=0)); ears.append(ear)
    z0, z1 = (-3.5, 2.2) if state in ('current', 'pressed') else (-2.0, 4.2)
    box('cap', 24, 15, z0, 176, 49, z1, CAP_ON if state == 'current' else CAP, bevel=1.6, seg=3)
    for x, y in ((19, 12), (181, 52)): cap_screw('retainer', x, y, 6, 2.4, SCREW, SOCKET)
    if state == 'current':
        box('marker', 29, 21, z1 - 0.4, 31.2, 43, z1 + 0.3, CHAMP, bevel=0.3)
    return hs, ears

def finish(W, H):
    sun = T.ti_studio(A.dome, A.sun, A.cone, A.rim, A.band_lo); sun.data.use_shadow = False
    T.camera(W / 2 * S, -H / 2 * S, W * S, W * A.scale, H * A.scale)
    T.render_setup(A.samples, A.out, transparent=True)
    bpy.ops.render.render(write_still=True)

LINK_A, LINK_R, LINK_r = 3.75, 4.5, 2.0       # inside 12.5 x 5, outside 20.5 x 13, wire 4

if A.part.startswith('key'):
    key(A.part.split('-')[1]); catcher_plate(-20, -20, 220, 84); finish(200, 64)
elif A.part == 'coupler':
    # Three links between bores 46 px apart: the end links stand on edge, pass down through each bore and round the
    # ear tip; the middle link lies flat between them. Both keys' ears and housings are occluders.
    W, H = 70, 32
    for off in (12 - 191.5, 58 - 8.5):       # the left key's right ear, the right key's left ear
        x0, x1, hx = (176, 200, 191.5) if off < 0 else (0, 24, 8.5)
        ear = occluder(box('ear', x0 + off, 6, -4.0, x1 + off, 26, -0.8, HOUSING, bevel=1.2, seg=2))
        cut(ear, cyl('bore', hx + off, 16, -20, 10, 4.2, None, bevel=0))
        occluder(box('housing', 16 + off, -10, PLATE_Z, 184 + off, 42, 6, HOUSING, bevel=2.4))
    zc = -2.4
    link_obj('end-l', 22.45, 16, zc, 0, math.pi / 2 - 0.2, LINK_A, LINK_R, LINK_r, LINK)
    link_obj('mid', 34.95, 16, zc - 0.6, 0, -0.08, LINK_A, LINK_R, LINK_r, LINK)
    link_obj('end-r', 47.45, 16, zc, 0, math.pi / 2 + 0.2, LINK_A, LINK_R, LINK_r, LINK)
    catcher_plate(-40, -40, 110, 72); finish(W, H)
elif A.part == 'drop':
    # Two links between the side ears of two stacked keys, bores 80 px apart at y 10 and 90 on a 32 x 100 canvas, drawn
    # at 0.758 of the coupler's link, threaded as the coupler: the upper link on edge, the lower one flat.
    W, H = 32, 100; k = 0.758
    for yb in (10, 90):
        ear = occluder(box('ear', 4, yb - 10 * k, -4.0 * k, 28, yb + 10 * k, -0.8 * k, HOUSING, bevel=1.0))
        cut(ear, cyl('bore', 16, yb, -20, 10, 4.2 * k, None, bevel=0))
    R, r = LINK_R * k, LINK_r * k
    L_ = (80 + 1.4) / 4; a = L_ - R
    link_obj('drop-upper', 16, 10 + L_ + r - 0.7, -2.4 * k, math.pi / 2, math.pi / 2 - 0.2, a, R, r, LINK)
    link_obj('drop-lower', 16, 90 - L_ - r + 0.7, -2.4 * k - 0.5, math.pi / 2, -0.08, a, R, r, LINK)
    catcher_plate(-40, -40, 72, 140); finish(W, H)
elif A.part in ('anchor-l', 'anchor-r'):
    # The chain's end: a forged clevis screwed to the plate by two M3 socket screws, a turned pin, and one link from
    # the pin into the end key's outer bore. anchor-l sits left of a key's left ear (bore at canvas x 28); anchor-r
    # right of a key's right ear (bore at canvas x 8). 36 x 32 CSS px.
    W, H = 36, 32; left = A.part == 'anchor-l'
    bx = 28 if left else 8
    ear_x0, ear_x1 = (bx - 8.5, bx + 15.5) if left else (bx - 15.5, bx + 8.5)
    ear = occluder(box('ear', ear_x0, 6, -4.0, ear_x1, 26, -0.8, HOUSING, bevel=1.2, seg=2))
    cut(ear, cyl('bore', bx, 16, -20, 10, 4.2, None, bevel=0))
    px = bx - 19.7 if left else bx + 19.7
    cl = box('clevis', px - 5, 5, PLATE_Z, px + 5, 27, -1.0, HOUSING, bevel=1.2)
    cut(cl, box('slot', px - 6, 13, -7.5, px + 6, 19, 2, HOUSING, bevel=0))
    for sy in (8.5, 23.5): cap_screw('m3', px, sy, -1.0, 2.2, SCREW, SOCKET)
    cyl('pin', px, 16, -9.0, -1.4, 2.6, PIN, bevel=0.4)
    lx = (px + bx) / 2
    # Its inside reaches from round the pin to round the ear tip: 19.7 + 2.6 + 4.3 = 26.6 = 2a + 2(R - r).
    link_obj('anchor-link', lx, 16, -2.4, 0, math.pi / 2 - (0.2 if left else -0.2), (26.6 - 2 * (LINK_R - LINK_r)) / 2, LINK_R, LINK_r, LINK)
    catcher_plate(-40, -40, 76, 72); finish(W, H)
elif A.part in ('anchor-t', 'anchor-b'):
    # Phones: the clevis stands above the first key's left ear (anchor-t, bore at canvas y 34) or below the last key's
    # right ear (anchor-b, bore at y 6), and its link runs down or up into the bore. 24 x 40 CSS px.
    W, H = 24, 40; top = A.part == 'anchor-t'
    by = 34 if top else 6
    ear = occluder(box('ear', 12 - 8.5, by - 10, -4.0, 12 + 15.5, by + 10, -0.8, HOUSING, bevel=1.2, seg=2)) if top else           occluder(box('ear', 12 - 15.5, by - 10, -4.0, 12 + 8.5, by + 10, -0.8, HOUSING, bevel=1.2, seg=2))
    cut(ear, cyl('bore', 12, by, -20, 10, 4.2, None, bevel=0))
    py = by - 19.7 if top else by + 19.7
    cl = box('clevis', 5, py - 5, PLATE_Z, 19, py + 5, -1.0, HOUSING, bevel=1.2)
    cut(cl, box('slot', 9, py - 6, -7.5, 15, py + 6, 2, HOUSING, bevel=0))
    for sx in (7.5, 16.5): cap_screw('m3', sx, py, -1.0, 1.9, SCREW, SOCKET)
    cyl('pin', 12, py, -9.0, -1.4, 2.6, PIN, bevel=0.4)
    link_obj('anchor-link', 12, (py + by) / 2, -2.4, math.pi / 2, math.pi / 2 - 0.2, (26.6 - 2 * (LINK_R - LINK_r)) / 2, LINK_R, LINK_r, LINK)
    catcher_plate(-40, -40, 64, 80); finish(W, H)
