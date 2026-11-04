"""PF Mark G, the original emblem's assembly milled into the titanium hero plate, Cycles. Reproducible:
blender -b --factory-startup -P ti_emblem.py -- --masks DIR --width 460 --scale 2 --samples N --out x.png

This is the original emblem (scripts/pf-emblem/render-lib.js, the R3 plaque) rebuilt as part of the hero plate rather
than an object on it. It keeps the original's geometry, legends and parts in its own units (the assembly frame x -8..264,
y -8..306), and its finishes:
- the seal floor (r 100) is a pocket milled into the plate, filled with 12K 2x2 twill carbon under a gloss coat;
- the ring band between the floor and the groove at r 114 is a turned face with concentric lathe marks, and the
  groove a round groove turned into the plate; the ring legends, registration ticks, witness marks,
  the hairline at r 102.3 and the two microtext lines are etched into it; four brass compass marks are inlaid;
- the P is satin-machined titanium brushed along x, with temper colours round its two tack welds; the F is brushed
  gold titanium nitride, grain along y, lapped over the P; the bridge is a titanium key across the F stem, tacked to
  the P by two weld beads, with its brass record inlay along its lower edge. P, F and bridge stand at three heights
  with polished chamfers and cast their shadows into the weave;
- the two identification plates are titanium plates inlaid flush in milled pockets, legends engraved, held by two
  socket screws and two rivets.
The flat face is a holdout, so the site's titanium field (ti_plate.py --part field) shows through: the emblem has no
edge of its own. Lighting is ti_common.ti_studio(), plus the same key again for diffuse surfaces only, which gives the
weave its cast shadows without changing any metal.
Masks come from emblem_masks.py; the mark's paths from brand/PF_MARK_G_MASTER.svg under the original's transform
translate(26.16 30.72) scale(.76).
"""
import bpy, bmesh, math, sys, argparse, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--masks', required=True); ap.add_argument('--width', type=float, default=460)
ap.add_argument('--scale', type=float, default=2); ap.add_argument('--samples', type=int, default=128)
ap.add_argument('--out', default='//emblem.png')
ap.add_argument('--dome', type=float, default=0.62); ap.add_argument('--sun', type=float, default=0.6)
ap.add_argument('--cone', type=float, default=8); ap.add_argument('--rim', type=float, default=1.4)
ap.add_argument('--shadow-sun', type=float, default=6.0); ap.add_argument('--denoise', type=int, default=1)
A = ap.parse_args(argv)
bpy.ops.wm.read_factory_settings(use_empty=True)
import ti_common as T
from ti_common import S
scn = bpy.context.scene; T.scn = scn
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

U0, V0, UW, VH = -8.0, -8.0, 272.0, 314.0     # the original's assembly frame, emblem units
R_FLOOR, R_GROOVE = 100.0, 114.0              # the seal floor and the turned groove, as render-lib.js
U = A.width / UW                              # CSS px per emblem unit
WPX, HPX = A.width, VH * U
def X(u): return (u - U0) * U * S
def Y(v): return -(v - V0) * U * S
def Z(u): return u * U * S

# ---------------- the shipped mark, from its own path data ----------------
svg = open(os.path.join(ROOT, 'brand', 'PF_MARK_G_MASTER.svg'), encoding='utf-8').read()
P_D, F_D, BRIDGE_D = re.findall(r'<path d="([^"]+)"', svg)
LT = (26.16, 30.72, 0.76)
def lt(x, y): return (LT[0] + LT[2] * x, LT[1] + LT[2] * y)

def parse(d):
    toks = re.findall(r'[MHVCLZ]|-?\d*\.?\d+', d); i = 0; subs = []; cur = None; pos = (0, 0); start = (0, 0); cmd = None
    def num():
        nonlocal i; v = float(toks[i]); i += 1; return v
    while i < len(toks):
        t = toks[i]
        if t in 'MHVCLZ': cmd = t; i += 1
        if cmd == 'M': pos = (num(), num()); start = pos; cur = [pos]; subs.append(cur); cmd = 'L'
        elif cmd == 'L': pos = (num(), num()); cur.append(('L', pos))
        elif cmd == 'H': pos = (num(), pos[1]); cur.append(('L', pos))
        elif cmd == 'V': pos = (pos[0], num()); cur.append(('L', pos))
        elif cmd == 'C': c1 = (num(), num()); c2 = (num(), num()); pos = (num(), num()); cur.append(('C', c1, c2, pos))
        elif cmd == 'Z': pos = start; cmd = None
    return subs

def flatten(sub):
    pts = [sub[0]]; p0 = sub[0]
    for seg in sub[1:]:
        if seg[0] == 'L': pts.append(seg[1]); p0 = seg[1]; continue
        _, c1, c2, p3 = seg; n = 64
        for k in range(1, n + 1):
            t = k / n; mt = 1 - t
            pts.append((mt**3 * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t**3 * p3[0],
                        mt**3 * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t**3 * p3[1]))
        p0 = p3
    if math.dist(pts[0], pts[-1]) < 1e-6: pts.pop()
    return pts

def prism(name, d, z0, z1, xf=lambda x, y: (x, y)):
    bm = bmesh.new(); edges = []
    for sub in parse(d):
        vs = [bm.verts.new((X(xf(*p)[0]), Y(xf(*p)[1]), Z(z1))) for p in flatten(sub)]
        for a, b in zip(vs, vs[1:] + vs[:1]): edges.append(bm.edges.new((a, b)))
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=True, edges=edges)
    faces = list(bm.faces)
    for f in faces:
        if f.normal.z < 0: f.normal_flip()
    ex = bmesh.ops.extrude_face_region(bm, geom=faces, use_keep_orig=True)
    bmesh.ops.translate(bm, verts=[g for g in ex['geom'] if isinstance(g, bmesh.types.BMVert)], vec=(0, 0, Z(z0) - Z(z1)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); scn.collection.objects.link(ob); return ob

def chamfer(ob, width_u, angle=40):
    bv = ob.modifiers.new('break', 'BEVEL'); bv.width = Z(width_u); bv.segments = 1; bv.limit_method = 'ANGLE'; bv.angle_limit = math.radians(angle)
    bpy.context.view_layer.objects.active = ob; bpy.ops.object.modifier_apply(modifier='break')

def apply_bool(target, cutter, op):
    m = target.modifiers.new('b', 'BOOLEAN'); m.operation = op; m.object = cutter; m.solver = 'EXACT'
    bpy.context.view_layer.objects.active = target; bpy.ops.object.modifier_apply(modifier='b')
    bpy.data.objects.remove(cutter)

def cyl(name, u, v, z0, z1, r_u, verts=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=Z(r_u), depth=Z(z1 - z0), location=(X(u), Y(v), Z((z0 + z1) / 2)))
    ob = bpy.context.active_object; ob.name = name; return ob

# ---------------- masks ----------------
def mask_image(name, color=False):
    p = os.path.join(A.masks, name); assert os.path.exists(p), p
    im = bpy.data.images.load(p); im.colorspace_settings.name = 'sRGB' if color else 'Non-Color'; return im
IM = {n: mask_image(n + '.png') for n in ('mask-etch', 'mask-inlay', 'mask-inlay-seam', 'mask-id-ink', 'mask-bridge', 'mask-bridge-seam', 'temper-amount')}
IM['temper-color'] = mask_image('temper-color.png', color=True)

def sample(nt, img, channel=True):
    N = nt.nodes; L = nt.links.new
    geo = N.new('ShaderNodeNewGeometry'); mp = N.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (1 / (WPX * S), 1 / (HPX * S), 1); mp.inputs['Location'].default_value = (0, 1, 0)
    L(geo.outputs['Position'], mp.inputs[0])
    tx = N.new('ShaderNodeTexImage'); tx.image = IM[img]; tx.interpolation = 'Cubic'; tx.extension = 'CLIP'
    L(mp.outputs[0], tx.inputs[0])
    if not channel: return tx.outputs['Color']
    sp = N.new('ShaderNodeSeparateColor'); L(tx.outputs['Color'], sp.inputs[0]); return sp.outputs[0]

def mixs(nt, fac, a, b):
    m = nt.nodes.new('ShaderNodeMixShader'); nt.links.new(fac, m.inputs['Fac']); nt.links.new(a, m.inputs[1]); nt.links.new(b, m.inputs[2]); return m.outputs[0]

def dark_bsdf(nt, v=0.05, rough=0.6):
    d = nt.nodes.new('ShaderNodeBsdfPrincipled'); d.inputs['Base Color'].default_value = (v, v, v, 1); d.inputs['Metallic'].default_value = 1; d.inputs['Roughness'].default_value = rough
    return d.outputs[0]

# ---------------- materials ----------------
def mat_face():
    """Flat face: holdout. Etched features cut 0.25 u in, matte and darker; the brass compass marks inlaid flush
    with a fine seam round each."""
    m = T.mat_titanium('ti-face', T=640 * S)
    nt = m.node_tree; N = nt.nodes; L = nt.links.new; b = N['Principled BSDF']; out = N['Material Output']
    k = sample(nt, 'mask-etch')
    rough = N.new('ShaderNodeMix'); rough.data_type = 'FLOAT'; L(k, rough.inputs['Factor'])
    if b.inputs['Roughness'].is_linked: L(b.inputs['Roughness'].links[0].from_socket, rough.inputs['A'])
    rough.inputs['B'].default_value = 0.78; L(rough.outputs['Result'], b.inputs['Roughness'])
    bc = b.inputs['Base Color']; src = bc.links[0].from_socket if bc.is_linked else None
    dk = N.new('ShaderNodeMix'); dk.data_type = 'RGBA'; L(k, dk.inputs['Factor'])
    if src: L(src, dk.inputs['A'])
    dk.inputs['B'].default_value = (0.2, 0.195, 0.19, 1); L(dk.outputs['Result'], bc)
    bp = N.new('ShaderNodeBump'); bp.invert = True; bp.inputs['Strength'].default_value = 0.6; bp.inputs['Distance'].default_value = Z(0.25)
    L(k, bp.inputs['Height'])
    if b.inputs['Normal'].is_linked: L(b.inputs['Normal'].links[0].from_socket, bp.inputs['Normal'])
    L(bp.outputs[0], b.inputs['Normal'])
    # The ring band between the seal floor and the groove is turned on a lathe: concentric lathe marks, a sheen that
    # runs round the ring (tangent circumferential) and a finer finish than the blasted face. Opaque.
    geo = N.new('ShaderNodeNewGeometry'); ctr = N.new('ShaderNodeVectorMath'); ctr.operation = 'SUBTRACT'
    L(geo.outputs['Position'], ctr.inputs[0]); ctr.inputs[1].default_value = (X(128), Y(128), 0)
    sp = N.new('ShaderNodeSeparateXYZ'); L(ctr.outputs[0], sp.inputs[0])
    ln = N.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'; L(ctr.outputs[0], ln.inputs[0])
    def band(r0, r1):
        lo = N.new('ShaderNodeMath'); lo.operation = 'GREATER_THAN'; L(ln.outputs['Value'], lo.inputs[0]); lo.inputs[1].default_value = Z(r0)
        hi = N.new('ShaderNodeMath'); hi.operation = 'LESS_THAN'; L(ln.outputs['Value'], hi.inputs[0]); hi.inputs[1].default_value = Z(r1)
        mm = N.new('ShaderNodeMath'); mm.operation = 'MULTIPLY'; L(lo.outputs[0], mm.inputs[0]); L(hi.outputs[0], mm.inputs[1]); return mm.outputs[0]
    ring = band(R_FLOOR + 0.6, R_GROOVE - 0.95)
    tb = N.new('ShaderNodeBsdfPrincipled'); tb.inputs['Base Color'].default_value = (0.78, 0.775, 0.76, 1); tb.inputs['Metallic'].default_value = 1
    tb.inputs['Roughness'].default_value = 0.16; tb.inputs['Anisotropic'].default_value = 0.75
    ng = N.new('ShaderNodeMath'); ng.operation = 'MULTIPLY'; L(sp.outputs['Y'], ng.inputs[0]); ng.inputs[1].default_value = -1
    tv = N.new('ShaderNodeCombineXYZ'); L(ng.outputs[0], tv.inputs[0]); L(sp.outputs['X'], tv.inputs[1])
    tn = N.new('ShaderNodeVectorMath'); tn.operation = 'NORMALIZE'; L(tv.outputs[0], tn.inputs[0]); L(tn.outputs[0], tb.inputs['Tangent'])
    lathe = N.new('ShaderNodeMath'); lathe.operation = 'SINE'
    lf = N.new('ShaderNodeMath'); lf.operation = 'MULTIPLY'; L(ln.outputs['Value'], lf.inputs[0]); lf.inputs[1].default_value = 2 * math.pi / Z(0.42)
    L(lf.outputs[0], lathe.inputs[0])
    lb = N.new('ShaderNodeBump'); lb.inputs['Strength'].default_value = 0.25; lb.inputs['Distance'].default_value = Z(0.05)
    L(lathe.outputs[0], lb.inputs['Height']); L(lb.outputs[0], tb.inputs['Normal'])
    # Etched legends and ticks cut through the turned finish as they do through the face.
    tsurf = mixs(nt, k, tb.outputs[0], dark_bsdf(nt, 0.2, 0.78))
    base = mixs(nt, ring, b.outputs[0], tsurf)
    surf = mixs(nt, sample(nt, 'mask-inlay'), base, T.gold_bsdf(nt).outputs[0])
    surf = mixs(nt, sample(nt, 'mask-inlay-seam'), surf, dark_bsdf(nt))
    # Opaque wherever something is cut or inlaid; the plain face is a holdout.
    sel = N.new('ShaderNodeMath'); sel.operation = 'MAXIMUM'; L(k, sel.inputs[0]); L(sample(nt, 'mask-inlay'), sel.inputs[1])
    sel2 = N.new('ShaderNodeMath'); sel2.operation = 'MAXIMUM'; L(sel.outputs[0], sel2.inputs[0]); L(sample(nt, 'mask-inlay-seam'), sel2.inputs[1])
    sel3 = N.new('ShaderNodeMath'); sel3.operation = 'MAXIMUM'; L(sel2.outputs[0], sel3.inputs[0]); L(ring, sel3.inputs[1])
    gr = N.new('ShaderNodeMapRange'); L(sel3.outputs[0], gr.inputs['Value']); gr.inputs['From Min'].default_value = 0.0; gr.inputs['From Max'].default_value = 0.12
    ho = N.new('ShaderNodeHoldout')
    L(mixs(nt, gr.outputs[0], ho.outputs[0], surf), out.inputs['Surface'])
    return m

def mat_part(name, kind):
    """'p': satin-machined titanium brushed along x, temper colours round the tacks. 'f': brushed gold TiN, grain
    along y. 'bridge': titanium key with its brass record inlay. 'id': the identification plates' brushed titanium
    with engraved legends. '-edge' names are the polished chamfers. 'weld': the tack weld beads."""
    m, nt, b = T.node_mat(name); N = nt.nodes; L = nt.links.new
    T.inp(b, 'Metallic').default_value = 1.0
    edge = name.endswith('-edge')
    T.inp(b, 'Base Color').default_value = (*(T.GOLD if kind == 'f' else (0.8, 0.79, 0.77)), 1)
    if kind == 'weld':
        T.inp(b, 'Base Color').default_value = (0.42, 0.41, 0.4, 1); T.inp(b, 'Roughness').default_value = 0.35
        geo = N.new('ShaderNodeNewGeometry'); wv = N.new('ShaderNodeTexWave'); wv.wave_type = 'BANDS'; wv.bands_direction = 'X'
        wv.inputs['Scale'].default_value = 1 / Z(0.85) / 1.0; L(geo.outputs['Position'], wv.inputs['Vector'])
        bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.5; bp.inputs['Distance'].default_value = Z(0.15)
        L(wv.outputs['Fac'], bp.inputs['Height']); L(bp.outputs[0], b.inputs['Normal'])
        return m
    if kind == 'bridge' and not edge:
        T.inp(b, 'Roughness').default_value = 0.2
        T.brush(nt, b, strength=0.05, axis='x', streaks=0.6)
    elif kind == 'id' and not edge:
        T.inp(b, 'Base Color').default_value = (0.7, 0.695, 0.68, 1); T.inp(b, 'Roughness').default_value = 0.28
        T.brush(nt, b, strength=0.05, axis='x', streaks=1.0)
    else:
        T.inp(b, 'Roughness').default_value = 0.08 if edge else 0.17
        if not edge: T.brush(nt, b, strength=0.08, axis='y' if kind == 'f' else 'x', streaks=1.6)
    if kind == 'p' and not edge:
        bc = b.inputs['Base Color']; src = bc.links[0].from_socket
        tm = N.new('ShaderNodeMix'); tm.data_type = 'RGBA'; L(sample(nt, 'temper-amount'), tm.inputs['Factor'])
        L(src, tm.inputs['A']); L(sample(nt, 'temper-color', channel=False), tm.inputs['B']); L(tm.outputs['Result'], bc)
    surf = b.outputs[0]
    if kind == 'bridge' and not edge:
        surf = mixs(nt, sample(nt, 'mask-bridge'), surf, T.gold_bsdf(nt).outputs[0])
        surf = mixs(nt, sample(nt, 'mask-bridge-seam'), surf, dark_bsdf(nt))
    if kind == 'id' and not edge:
        surf = mixs(nt, sample(nt, 'mask-id-ink'), surf, dark_bsdf(nt, 0.03, 0.7))
    L(surf, N['Material Output'].inputs['Surface'])
    return m

def mat_carbon():
    """12K 2x2 twill under a gloss coat, tow pitch 10 CSS px; contact occlusion darkens it under the parts."""
    m, nt, b = T.node_mat('carbon'); N = nt.nodes; L = nt.links.new
    p = 10 * S
    geo = N.new('ShaderNodeNewGeometry'); sep = N.new('ShaderNodeSeparateXYZ'); L(geo.outputs['Position'], sep.inputs[0])
    def op(o, a, bb=None, c=None):
        n = N.new('ShaderNodeMath'); n.operation = o
        for i, v in enumerate((a, bb, c)):
            if v is None: continue
            if isinstance(v, (int, float)): n.inputs[i].default_value = v
            else: L(v, n.inputs[i])
        return n.outputs[0]
    fx = op('DIVIDE', sep.outputs['X'], p); fy = op('DIVIDE', sep.outputs['Y'], p)
    ix = op('FLOOR', fx); iy = op('FLOOR', fy)
    warp = op('LESS_THAN', op('FLOORED_MODULO', op('ADD', ix, iy), 4.0), 2.0)
    cy = op('FRACT', fy); cx = op('FRACT', fx)
    cross = N.new('ShaderNodeMix'); cross.data_type = 'FLOAT'; L(warp, cross.inputs['Factor']); L(cx, cross.inputs['A']); L(cy, cross.inputs['B'])
    crown = op('SINE', op('MULTIPLY', cross.outputs['Result'], math.pi))
    cell = N.new('ShaderNodeCombineXYZ'); L(ix, cell.inputs[0]); L(iy, cell.inputs[1])
    wn = N.new('ShaderNodeTexWhiteNoise'); wn.noise_dimensions = '3D'; L(cell.outputs[0], wn.inputs['Vector'])
    tone = op('MULTIPLY_ADD', wn.outputs['Value'], 0.16, 0.92)
    gap = op('SMOOTH_MIN', op('MULTIPLY', crown, 6.0), 1.0, 0.4)
    ao = N.new('ShaderNodeAmbientOcclusion'); ao.samples = 16; ao.inputs['Distance'].default_value = Z(7)
    base = op('MULTIPLY', op('MULTIPLY', op('MULTIPLY', tone, gap), 0.07), op('MULTIPLY_ADD', ao.outputs['AO'], 0.8, 0.2))
    col = N.new('ShaderNodeCombineColor'); L(base, col.inputs[0]); L(base, col.inputs[1]); L(op('MULTIPLY', base, 1.06), col.inputs[2])
    L(col.outputs[0], T.inp(b, 'Base Color'))
    T.inp(b, 'Metallic').default_value = 0.6; T.inp(b, 'Roughness').default_value = 0.22; T.inp(b, 'Anisotropic').default_value = 0.85
    tg = N.new('ShaderNodeMix'); tg.data_type = 'VECTOR'; L(warp, tg.inputs['Factor'])
    tg.inputs[4].default_value = (0, 1, 0); tg.inputs[5].default_value = (1, 0, 0); L(tg.outputs[1], T.inp(b, 'Tangent'))
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.5; bp.inputs['Distance'].default_value = 0.6 * S
    L(crown, bp.inputs['Height']); L(bp.outputs[0], T.inp(b, 'Normal'))
    L(op('MULTIPLY_ADD', ao.outputs['AO'], 0.7, 0.3), T.inp(b, 'Coat Weight'))
    T.inp(b, 'Coat Roughness').default_value = 0.03; T.inp(b, 'Coat IOR').default_value = 1.5
    return m

def assign(ob, mats, top_u, ch_u):
    ob.data.materials.clear()
    for mm in mats: ob.data.materials.append(mm)
    for f in ob.data.polygons:
        f.material_index = 1 if (len(mats) > 1 and f.normal.z < 0.999 and f.center.z > Z(top_u) - Z(ch_u) - 1e-4) else 0

# ---------------- build ----------------
face = mat_face(); pol = T.mat_titanium('ti-polished', T=640 * S, finish='polished'); carbon = mat_carbon()
DEPTH, CARBON_TOP = 5.5, -4.0
# Plate slab, face at z 0, running past the frame so the pixel filter never sees past it.
bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); me = bpy.data.meshes.new('plate'); bm.to_mesh(me); bm.free()
plate = bpy.data.objects.new('plate', me); scn.collection.objects.link(plate)
plate.location = (WPX / 2 * S, -HPX / 2 * S, -Z(5)); plate.scale = (WPX * S * 1.04, HPX * S * 1.04, Z(10))
bpy.context.view_layer.objects.active = plate; plate.select_set(True); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
me.materials.append(face); me.materials.append(pol)
# Seal floor: a pocket with a polished 35 deg rim chamfer; the turned groove at r 114.
CH = 0.6; cw = Z(CH) * math.tan(math.radians(35))
cut = cyl('pocket', 128, 128, -DEPTH, 1, R_FLOOR, 256)
bpy.ops.mesh.primitive_cone_add(vertices=256, radius1=Z(R_FLOOR), radius2=Z(R_FLOOR + CH), depth=cw, location=(X(128), Y(128), -cw / 2 + 1e-5)); cone = bpy.context.active_object
capc = cyl('cap', 128, 128, 0, 1, R_FLOOR + CH, 256)
for extra in (cone, capc):
    mm = cut.modifiers.new('u', 'BOOLEAN'); mm.operation = 'UNION'; mm.object = extra; mm.solver = 'EXACT'
    bpy.context.view_layer.objects.active = cut; bpy.ops.object.modifier_apply(modifier='u'); bpy.data.objects.remove(extra)
apply_bool(plate, cut, 'DIFFERENCE')
bpy.ops.mesh.primitive_torus_add(major_segments=256, minor_segments=24, major_radius=Z(R_GROOVE), minor_radius=Z(0.95), location=(X(128), Y(128), 0))
apply_bool(plate, bpy.context.active_object, 'DIFFERENCE')
# Identification plate pockets: the plates' outlines, 0.6 u larger, milled 1.2 u deep.
LP1 = 'M23 262H169L172 265V289L169 292H23L20 289V265Z'; LP2 = 'M183 262H233L236 265V289L233 292H183L180 289V265Z'
def grow(d, k):
    # Outline offset for these convex chamfered rectangles: scale about the centre by k units each way.
    pts = [p for s in parse(d) for p in flatten(s)]; xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    cx, cy, hw, hh = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2
    return lambda x, y: (cx + (x - cx) * (hw + k) / hw, cy + (y - cy) * (hh + k) / hh)
for d in (LP1, LP2):
    apply_bool(plate, prism('id-pocket', d, -1.2, 1.0, grow(d, 0.6)), 'DIFFERENCE')
for f in plate.data.polygons:
    f.material_index = 0 if (f.normal.z > 0.999 and f.center.z > -1e-4) else 1
cf = cyl('carbon', 128, 128, -DEPTH, CARBON_TOP, R_FLOOR - 0.01, 256); cf.data.materials.append(carbon)
objs = [plate, cf]
# The mark: P, F lapped over it, and the bridge key across the F stem, at three heights.
for kind, d, top, ch in (('p', P_D, -0.3, 1.55), ('f', F_D, 0.9, 1.55), ('bridge', BRIDGE_D, 2.1, 1.15)):
    ob = prism(kind, d, -DEPTH, top, lt); chamfer(ob, ch)
    assign(ob, [mat_part(kind, kind), mat_part(kind + '-edge', kind)], top, ch); objs.append(ob)
# Tack welds: two short beads where the bridge's top and bottom edges meet the P, as on the original.
weld = mat_part('weld', 'weld')
for vv in (83.92, 111.28):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0, location=(X(134.2), Y(vv), Z(-0.3)))
    bd = bpy.context.active_object; bd.name = 'tack'; bd.scale = (Z(2.6), Z(0.75), Z(0.55)); bd.data.materials.append(weld); objs.append(bd)
# Identification plates, inlaid: tops 0.35 u proud, polished edge break; two socket screws and two rivets.
for d in (LP1, LP2):
    ob = prism('id', d, -1.2, 0.35); chamfer(ob, 0.5)
    assign(ob, [mat_part('id', 'id'), mat_part('id-edge', 'id')], 0.35, 0.5); objs.append(ob)
scr = T.mat_titanium('id-screw', T=640 * S, seed=4.1, finish='lapped')
DARK = T.node_mat('socket')[0]; DARK.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.01, 0.01, 0.011, 1)
for (u, v, rh, rot) in ((29, 277, 3.4, 0.0), (163, 277, 3.4, 0.9)):
    hd = cyl('screw', u, v, 0.0, 0.9, rh); hd.data.materials.append(scr)
    bv = hd.modifiers.new('e', 'BEVEL'); bv.width = Z(0.45); bv.segments = 3; bv.limit_method = 'ANGLE'
    bpy.context.view_layer.objects.active = hd; bpy.ops.object.modifier_apply(modifier='e')
    hx = cyl('hex', u, v, 0.3, 2.0, rh * 0.42, 6); hx.rotation_euler = (0, 0, rot); apply_bool(hd, hx, 'DIFFERENCE')
    fl = cyl('socket-floor', u, v, 0.25, 0.35, rh * 0.42, 6); fl.rotation_euler = (0, 0, rot); fl.data.materials.append(DARK)
    objs += [hd, fl]
for (u, v) in ((184.6, 266.6), (231.4, 287.4)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0, location=(X(u), Y(v), Z(0.35)))
    rv = bpy.context.active_object; rv.name = 'rivet'; rv.scale = (Z(1.5), Z(1.5), Z(0.7)); rv.data.materials.append(scr); objs.append(rv)

key = T.ti_studio(A.dome, A.sun, A.cone, A.rim)
# The same key again, for diffuse surfaces only: the metals have no diffuse lobe, so they read exactly as in the field,
# while the weave takes the parts' cast shadows, as the original emblem's floor does.
sd = bpy.data.lights.new('shadow-sun', 'SUN'); sd.energy = A.shadow_sun; sd.angle = key.data.angle; sd.color = key.data.color
so = bpy.data.objects.new('shadow-sun', sd); scn.collection.objects.link(so); so.rotation_euler = key.rotation_euler
so.visible_glossy = False; so.visible_transmission = False
T.camera(WPX / 2 * S, -HPX / 2 * S, WPX * S, round(WPX * A.scale), round(HPX * A.scale))
T.render_setup(A.samples, A.out, transparent=True, denoise=bool(A.denoise))
bpy.ops.render.render(write_still=True)
