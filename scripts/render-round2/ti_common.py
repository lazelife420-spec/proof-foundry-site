"""Titanium parts, shared by ti_plate.py and ti_seal.py: the titanium studio, materials and render setup.

Units match chain_scene.py: 1 CSS px = 0.01 m; image x -> +X, image y -> -Y, toward the camera -> +Z.
The titanium studio lights with distant sources only: an overhead dome (emission by ray direction) and one sun from
the chain studio's key direction (upper left). Every point of a flat face is lit the same, so the field tiles, the
frame 9-slices and the seal composites over the field without a visible seam.
"""
import bpy, math
from mathutils import Vector

S = 0.01
scn = bpy.context.scene

def P(x, y, z=0.0):
    return Vector((x * S, -y * S, z * S))

def node_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs[0], out.inputs['Surface'])
    return m, nt, bsdf

def inp(b, *names):
    for n in names:
        if n in b.inputs: return b.inputs[n]
    raise KeyError(names)

def torus4d(nt, T, x0=0.0, y0=0.0):
    """Object-space x, y (metres) -> a 4D noise coordinate on a torus of period T metres in both axes, so any noise
    sampled through it wraps exactly. Returns (vector socket, w socket)."""
    N = nt.nodes; L = nt.links.new
    tc = N.new('ShaderNodeTexCoord'); sep = N.new('ShaderNodeSeparateXYZ'); L(tc.outputs['Object'], sep.inputs[0])
    R = T / (2 * math.pi)
    def ang(src, off):
        a = N.new('ShaderNodeMath'); a.operation = 'MULTIPLY_ADD'; L(src, a.inputs[0])
        a.inputs[1].default_value = 2 * math.pi / T; a.inputs[2].default_value = off; return a.outputs[0]
    def trig(src, op):
        t = N.new('ShaderNodeMath'); t.operation = op; L(src, t.inputs[0])
        m = N.new('ShaderNodeMath'); m.operation = 'MULTIPLY'; L(t.outputs[0], m.inputs[0]); m.inputs[1].default_value = R
        return m.outputs[0]
    ax, ay = ang(sep.outputs['X'], x0), ang(sep.outputs['Y'], y0)
    comb = N.new('ShaderNodeCombineXYZ')
    L(trig(ax, 'COSINE'), comb.inputs[0]); L(trig(ax, 'SINE'), comb.inputs[1]); L(trig(ay, 'COSINE'), comb.inputs[2])
    return comb.outputs[0], trig(ay, 'SINE')

def noise4(nt, vec, w, scale, detail=4, rough=0.5):
    n = nt.nodes.new('ShaderNodeTexNoise'); n.noise_dimensions = '4D'
    n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail; n.inputs['Roughness'].default_value = rough
    nt.links.new(vec, n.inputs['Vector']); nt.links.new(w, n.inputs['W'])
    return n.outputs['Fac']

def map_range(nt, src, f0, f1, t0, t1):
    m = nt.nodes.new('ShaderNodeMapRange'); nt.links.new(src, m.inputs['Value'])
    m.inputs['From Min'].default_value = f0; m.inputs['From Max'].default_value = f1
    m.inputs['To Min'].default_value = t0; m.inputs['To Max'].default_value = t1
    return m.outputs[0]

def torus4d_aniso(nt, T, kx, ky, x0=0.0, y0=0.0):
    """torus4d with each circle's radius scaled (kx, ky), so a noise read through it is kx times as fine along x and ky
    times along y and still wraps exactly on the tile's period T: kx << ky draws streaks along x."""
    N = nt.nodes; L = nt.links.new
    tc = N.new('ShaderNodeTexCoord'); sep = N.new('ShaderNodeSeparateXYZ'); L(tc.outputs['Object'], sep.inputs[0])
    def circle(src, off, k):
        a = N.new('ShaderNodeMath'); a.operation = 'MULTIPLY_ADD'; L(src, a.inputs[0])
        a.inputs[1].default_value = 2 * math.pi / T; a.inputs[2].default_value = off
        outs = []
        for op in ('COSINE', 'SINE'):
            t = N.new('ShaderNodeMath'); t.operation = op; L(a.outputs[0], t.inputs[0])
            m = N.new('ShaderNodeMath'); m.operation = 'MULTIPLY'; L(t.outputs[0], m.inputs[0]); m.inputs[1].default_value = k * T / (2 * math.pi)
            outs.append(m.outputs[0])
        return outs
    (cx, sx), (cy, sy) = circle(sep.outputs['X'], x0, kx), circle(sep.outputs['Y'], y0, ky)
    comb = N.new('ShaderNodeCombineXYZ'); L(cx, comb.inputs[0]); L(sx, comb.inputs[1]); L(cy, comb.inputs[2])
    return comb.outputs[0], sy

def _mul(nt, a, b):
    m = nt.nodes.new('ShaderNodeMath'); m.operation = 'MULTIPLY'
    for i, v in enumerate((a, b)):
        if isinstance(v, (int, float)): m.inputs[i].default_value = v
        else: nt.links.new(v, m.inputs[i])
    return m.outputs[0]

def mat_mill_steel(name, T=6.9, seed=0.0, tone=0.06):
    """Hot-rolled mild steel plate as it leaves the mill: a dark, partly metallic mill scale with soft clouds, darker
    scale flakes, rolling streaks and fine bright rolling lines along x, and a fine grain. All noise runs on a torus of period T metres, so the field
    tiles exactly. `tone` is the linear albedo before the variations; the chassis and the footer base differ only in
    tone and seed."""
    m, nt, b = node_mat(name); L = nt.links.new
    inp(b, 'Metallic').default_value = 0.6
    vec, w = torus4d(nt, T, seed, seed * 1.7)
    svec, sw = torus4d_aniso(nt, T, 0.012, 1.0, seed + 2.1, seed * 0.6 + 0.4)
    lvec, lw = torus4d_aniso(nt, T, 0.004, 1.0, seed + 4.7, seed * 0.3 + 1.9)
    grain = noise4(nt, vec, w, 1 / 0.004, detail=1, rough=0.5)
    cloud = noise4(nt, vec, w, 1 / 0.7, detail=3, rough=0.55)
    flake = noise4(nt, vec, w, 1 / 0.18, detail=4, rough=0.62)
    streak = noise4(nt, svec, sw, 1 / 0.035, detail=3, rough=0.6)
    line = noise4(nt, lvec, lw, 1 / 0.012, detail=2, rough=0.5)
    k = _mul(nt, map_range(nt, grain, 0.3, 0.7, 0.86, 1.12), map_range(nt, cloud, 0.35, 0.65, 0.82, 1.14))
    k = _mul(nt, k, map_range(nt, streak, 0.3, 0.7, 0.8, 1.16))
    ln = nt.nodes.new('ShaderNodeMapRange'); L(line, ln.inputs['Value']); ln.clamp = True
    ln.inputs['From Min'].default_value = 0.66; ln.inputs['From Max'].default_value = 0.72
    ln.inputs['To Min'].default_value = 1.0; ln.inputs['To Max'].default_value = 1.35
    k = _mul(nt, k, ln.outputs[0])
    fl = nt.nodes.new('ShaderNodeMapRange'); L(flake, fl.inputs['Value']); fl.clamp = True
    fl.inputs['From Min'].default_value = 0.6; fl.inputs['From Max'].default_value = 0.7
    fl.inputs['To Min'].default_value = 1.0; fl.inputs['To Max'].default_value = 0.86
    base = _mul(nt, _mul(nt, k, fl.outputs[0]), tone)
    col = nt.nodes.new('ShaderNodeCombineColor'); L(base, col.inputs[0]); L(_mul(nt, base, 1.02), col.inputs[1])
    L(_mul(nt, base, 1.06), col.inputs[2]); L(col.outputs[0], inp(b, 'Base Color'))
    L(map_range(nt, cloud, 0.3, 0.7, 0.62, 0.48), inp(b, 'Roughness'))
    inp(b, 'Anisotropic').default_value = 0.3
    tv = nt.nodes.new('ShaderNodeCombineXYZ'); tv.inputs[0].default_value = 1.0; L(tv.outputs[0], inp(b, 'Tangent'))
    h = nt.nodes.new('ShaderNodeMath'); h.operation = 'ADD'; L(grain, h.inputs[0]); L(_mul(nt, streak, 0.6), h.inputs[1])
    bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.05; bp.inputs['Distance'].default_value = 0.002
    L(h.outputs[0], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    return m

def mat_paper(name, T=5.12, seed=0.0, tone=(0.885, 0.84, 0.655)):
    """Archival cotton paper: matte, a faint sheen, and two scales of fibre (long fibres laid both ways, short fibres
    and a fine tooth) in the albedo and a shallow bump. Torus noise of period T, so the sheet's field tiles exactly."""
    m, nt, b = node_mat(name); L = nt.links.new
    inp(b, 'Metallic').default_value = 0.0; inp(b, 'Roughness').default_value = 0.88
    inp(b, 'Sheen Weight').default_value = 0.12
    vec, w = torus4d(nt, T, seed, seed * 1.3)
    hx, hw = torus4d_aniso(nt, T, 0.12, 1.0, seed + 1.1, seed + 0.7)
    vx, vw = torus4d_aniso(nt, T, 1.0, 0.12, seed + 2.3, seed + 1.9)
    tooth = noise4(nt, vec, w, 1 / 0.006, detail=2, rough=0.5)
    cloud = noise4(nt, vec, w, 1 / 0.9, detail=3, rough=0.5)
    fh = noise4(nt, hx, hw, 1 / 0.02, detail=3, rough=0.6); fv = noise4(nt, vx, vw, 1 / 0.02, detail=3, rough=0.6)
    fib = nt.nodes.new('ShaderNodeMath'); fib.operation = 'MAXIMUM'; L(fh, fib.inputs[0]); L(fv, fib.inputs[1])
    mott = noise4(nt, vec, w, 1 / 0.08, detail=3, rough=0.6)
    k = _mul(nt, map_range(nt, tooth, 0.3, 0.7, 0.92, 1.06), map_range(nt, cloud, 0.35, 0.65, 0.9, 1.07))
    k = _mul(nt, k, map_range(nt, mott, 0.35, 0.65, 0.91, 1.06))
    k = _mul(nt, k, map_range(nt, fib.outputs[0], 0.5, 0.8, 1.0, 0.82))
    col = nt.nodes.new('ShaderNodeCombineColor')
    for i in range(3): L(_mul(nt, k, tone[i]), col.inputs[i])
    L(col.outputs[0], inp(b, 'Base Color'))
    h = nt.nodes.new('ShaderNodeMath'); h.operation = 'ADD'; L(tooth, h.inputs[0]); L(_mul(nt, fib.outputs[0], 0.8), h.inputs[1])
    bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.25; bp.inputs['Distance'].default_value = 0.002
    L(h.outputs[0], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    return m

TI_BASE = (0.53, 0.52, 0.50)

def brush(nt, b, strength=0.04, axis='x', streaks=0.0, tangent=False):
    """Brushing along `axis`: noise stretched 1:60 drives a faint bump and an anisotropic sheen. `streaks` (0..1) also
    lays the strokes into the reflectance, the visible grain of a brushed face.
    The Principled BSDF ignores an unlinked Tangent's value and uses the radial tangent round the object's z axis, so
    by default the sheen fans out from the part's centre (unnoticeable on the small Round 3 key and seal parts, kept so
    their masters still reproduce). tangent=True links a constant tangent along the stroke: use it for any flat face
    that a 3- or 9-slice stretches, where a fanned sheen would stretch into a visible sweep."""
    N = nt.nodes; L = nt.links.new
    geo = N.new('ShaderNodeNewGeometry'); mp = N.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (4, 240, 1) if axis == 'x' else (240, 4, 1)
    L(geo.outputs['Position'], mp.inputs[0])
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 2.0; nz.inputs['Detail'].default_value = 6; L(mp.outputs[0], nz.inputs[0])
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = strength; bp.inputs['Distance'].default_value = 0.0005
    L(nz.outputs['Fac'], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    inp(b, 'Anisotropic').default_value = 0.35 if not streaks else 0.6
    inp(b, 'Tangent').default_value = (1, 0, 0) if axis == 'x' else (0, 1, 0)
    if tangent:
        tv = N.new('ShaderNodeCombineXYZ'); tv.inputs[0].default_value = 1.0 if axis == 'x' else 0.0
        tv.inputs[1].default_value = 0.0 if axis == 'x' else 1.0; L(tv.outputs[0], inp(b, 'Tangent'))
    if streaks:
        bc = inp(b, 'Base Color'); base = bc.default_value[:]
        k = N.new('ShaderNodeMapRange'); L(nz.outputs['Fac'], k.inputs['Value'])
        k.inputs['From Min'].default_value = 0.35; k.inputs['From Max'].default_value = 0.65
        k.inputs['To Min'].default_value = 1 - 0.12 * streaks; k.inputs['To Max'].default_value = 1 + 0.08 * streaks
        mx = N.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs['Factor'].default_value = 1.0
        if bc.is_linked: L(bc.links[0].from_socket, mx.inputs['A'])
        else: mx.inputs['A'].default_value = base
        kc = N.new('ShaderNodeCombineColor'); L(k.outputs[0], kc.inputs[0]); L(k.outputs[0], kc.inputs[1]); L(k.outputs[0], kc.inputs[2])
        L(kc.outputs[0], mx.inputs['B']); L(mx.outputs['Result'], bc)

def mat_titanium(name, T=6.4, finish='blasted', seed=0.0):
    """Grade 2 titanium. finish 'blasted': bead-blasted face, roughness 0.50 +- 0.03 in 20-60 px blotches, a fine
    blast-pit bump and a sub-pixel speckle in the reflectance (the grain survives the denoiser through the albedo
    pass). 'lapped': the islands' lapped tops, roughness about 0.16. 'polished': chamfers and edge breaks.
    Noise runs on a torus of period T metres (the field tile), with a seed offset, so the field tiles exactly."""
    m, nt, b = node_mat(name); L = nt.links.new
    inp(b, 'Base Color').default_value = (*TI_BASE, 1); inp(b, 'Metallic').default_value = 1.0
    vec, w = torus4d(nt, T, seed, seed * 1.7)
    blot = noise4(nt, vec, w, 1 / 0.4, detail=2)
    if finish == 'blasted':
        L(map_range(nt, blot, 0.3, 0.7, 0.44, 0.56), inp(b, 'Roughness'))
        pits = noise4(nt, vec, w, 1 / 0.012, detail=3, rough=0.6)
        bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.08; bp.inputs['Distance'].default_value = 0.002
        L(pits, bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
        # Reflectance: a sub-pixel blast grain times a soft 30-80 px cloud, the way a blasted sheet reads under light.
        grain = noise4(nt, vec, w, 1 / 0.005, detail=1, rough=0.5)
        cloud = noise4(nt, vec, w, 1 / 0.55, detail=3, rough=0.55)
        gr = map_range(nt, grain, 0.3, 0.7, 0.8, 1.15); cl = map_range(nt, cloud, 0.35, 0.65, 0.93, 1.06)
        k = nt.nodes.new('ShaderNodeMath'); k.operation = 'MULTIPLY'; L(gr, k.inputs[0]); L(cl, k.inputs[1])
        col = nt.nodes.new('ShaderNodeMix'); col.data_type = 'RGBA'; col.blend_type = 'MULTIPLY'; col.inputs['Factor'].default_value = 1.0
        col.inputs['A'].default_value = (*TI_BASE, 1)
        kc = nt.nodes.new('ShaderNodeCombineColor'); L(k.outputs[0], kc.inputs[0]); L(k.outputs[0], kc.inputs[1]); L(k.outputs[0], kc.inputs[2])
        L(kc.outputs[0], col.inputs['B']); L(col.outputs['Result'], inp(b, 'Base Color'))
    elif finish == 'lapped':
        # A lapped top is satin, not mirror: its roughness drifts in soft clouds and fine lapping scratches, so the
        # flat island shows a sheen rather than one flat value under the distant lights.
        cloud = noise4(nt, vec, w, 1 / 0.6, detail=2, rough=0.5)
        L(map_range(nt, cloud, 0.3, 0.7, 0.15, 0.21), inp(b, 'Roughness'))
        inp(b, 'Base Color').default_value = (0.44, 0.43, 0.41, 1)
        brush(nt, b)
    else:
        L(map_range(nt, blot, 0.3, 0.7, 0.12, 0.18), inp(b, 'Roughness'))
    return m

def mat_oxide(name, T=5.12, seed=0.0):
    """Bead-blasted mild steel with a black-oxide finish: a dark, satin, partly metallic conversion coat, soft
    blast clouds and a fine grain. Noise on a torus of period T metres, so the field tiles exactly."""
    m, nt, b = node_mat(name); L = nt.links.new
    inp(b, 'Metallic').default_value = 0.75
    vec, w = torus4d(nt, T, seed, seed * 1.3)
    L(map_range(nt, noise4(nt, vec, w, 1 / 0.4, detail=2), 0.3, 0.7, 0.3, 0.42), inp(b, 'Roughness'))
    grain = noise4(nt, vec, w, 1 / 0.005, detail=1, rough=0.5); cloud = noise4(nt, vec, w, 1 / 0.6, detail=3, rough=0.55)
    k = nt.nodes.new('ShaderNodeMath'); k.operation = 'MULTIPLY'
    L(map_range(nt, grain, 0.3, 0.7, 0.8, 1.16), k.inputs[0]); L(map_range(nt, cloud, 0.35, 0.65, 0.9, 1.1), k.inputs[1])
    base = nt.nodes.new('ShaderNodeMath'); base.operation = 'MULTIPLY'; L(k.outputs[0], base.inputs[0]); base.inputs[1].default_value = 0.2
    col = nt.nodes.new('ShaderNodeCombineColor'); L(base.outputs[0], col.inputs[0]); L(base.outputs[0], col.inputs[1])
    bb = nt.nodes.new('ShaderNodeMath'); bb.operation = 'MULTIPLY'; L(base.outputs[0], bb.inputs[0]); bb.inputs[1].default_value = 1.07
    L(bb.outputs[0], col.inputs[2]); L(col.outputs[0], inp(b, 'Base Color'))
    pits = noise4(nt, vec, w, 1 / 0.012, detail=3, rough=0.6)
    bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.06; bp.inputs['Distance'].default_value = 0.002
    L(pits, bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    return m

GOLD = (0.80, 0.53, 0.15)

def gold_bsdf(nt, T=6.4):
    """Gold titanium nitride (PVD) over a lapped titanium substrate: the same satin roughness drift as the lap."""
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); L = nt.links.new
    b.inputs['Base Color'].default_value = (*GOLD, 1); b.inputs['Metallic'].default_value = 1.0
    vec, w = torus4d(nt, T, 3.1, 5.3)
    L(map_range(nt, noise4(nt, vec, w, 1 / 0.6, detail=2, rough=0.5), 0.3, 0.7, 0.18, 0.25), b.inputs['Roughness'])
    brush(nt, b)
    return b

def mat_tin_gold(name):
    m, nt, b = node_mat(name)
    g = gold_bsdf(nt); nt.links.new(g.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    return m

def ti_studio(dome=1.0, sun=3.0, cone=22.0, rim=0.0, band_lo=6.0):
    """Overhead dome (ray directions within `cone` deg of zenith, a smooth edge of a quarter of that) plus one sun from
    the chain studio's key direction: azimuth 32 deg left of image-up, elevation 18 deg, angle 6 deg."""
    w = bpy.data.worlds.new('ti-dome'); w.use_nodes = True; nt = w.node_tree; N = nt.nodes; L = nt.links.new
    bg = N['Background']; tc = N.new('ShaderNodeTexCoord'); sep = N.new('ShaderNodeSeparateXYZ')
    L(tc.outputs['Generated'], sep.inputs[0])
    edge = N.new('ShaderNodeMapRange'); edge.interpolation_type = 'SMOOTHSTEP'; L(sep.outputs['Z'], edge.inputs['Value'])
    edge.inputs['From Min'].default_value = math.cos(math.radians(cone * 1.27)); edge.inputs['From Max'].default_value = math.cos(math.radians(cone))
    # A low band toward the key (elevation 10-32 deg, weighted to the key's azimuth): it lights the chamfers and
    # edge breaks that face the upper left and leaves the lower-right ones dark. Flat faces never see it.
    def m(op, a, b=None):
        n = N.new('ShaderNodeMath'); n.operation = op
        for i, v in enumerate((a, b)):
            if v is None: continue
            if isinstance(v, (int, float)): n.inputs[i].default_value = v
            else: L(v, n.inputs[i])
        return n.outputs[0]
    lo = N.new('ShaderNodeMapRange'); lo.interpolation_type = 'SMOOTHSTEP'; L(sep.outputs['Z'], lo.inputs['Value'])
    lo.inputs['From Min'].default_value = math.sin(math.radians(band_lo)); lo.inputs['From Max'].default_value = math.sin(math.radians(band_lo + 6))
    hi = N.new('ShaderNodeMapRange'); hi.interpolation_type = 'SMOOTHSTEP'; L(sep.outputs['Z'], hi.inputs['Value'])
    hi.inputs['From Min'].default_value = math.sin(math.radians(30)); hi.inputs['From Max'].default_value = math.sin(math.radians(40))
    band = m('MULTIPLY', lo.outputs[0], m('SUBTRACT', 1.0, hi.outputs[0]))
    kx, ky = -math.sin(math.radians(32)), math.cos(math.radians(32))
    flat = m('SQRT', m('ADD', m('MULTIPLY', sep.outputs['X'], sep.outputs['X']), m('MULTIPLY', sep.outputs['Y'], sep.outputs['Y'])))
    facing = m('DIVIDE', m('ADD', m('MULTIPLY', sep.outputs['X'], kx), m('MULTIPLY', sep.outputs['Y'], ky)), m('MAXIMUM', flat, 1e-4))
    az = m('POWER', m('MAXIMUM', facing, 0.0), 3.0)
    rim_k = m('MULTIPLY', m('MULTIPLY', band, az), rim / max(dome, 1e-6))
    tot = m('ADD', edge.outputs[0], rim_k)
    col = N.new('ShaderNodeMix'); col.data_type = 'RGBA'; L(tot, col.inputs['Factor']); col.clamp_factor = False
    col.inputs['A'].default_value = (0, 0, 0, 1); col.inputs['B'].default_value = (1.0, 0.99, 0.97, 1)
    L(col.outputs['Result'], bg.inputs['Color']); bg.inputs['Strength'].default_value = dome
    scn.world = w
    ld = bpy.data.lights.new('ti-sun', 'SUN'); ld.energy = sun; ld.angle = math.radians(6); ld.color = (1.0, 0.96, 0.9)
    ob = bpy.data.objects.new('ti-sun', ld); scn.collection.objects.link(ob)
    az, el = math.radians(32), math.radians(18)
    to_light = Vector((-math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    ob.rotation_euler = (-to_light).to_track_quat('-Z', 'Y').to_euler()
    return ob

def camera(cx, cy, width_bu, w_px, h_px):
    cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = width_bu; cd.sensor_fit = 'HORIZONTAL'
    cam = bpy.data.objects.new('cam', cd); scn.collection.objects.link(cam); cam.location = (cx, cy, 30); scn.camera = cam
    scn.render.resolution_x = int(w_px); scn.render.resolution_y = int(h_px); scn.render.resolution_percentage = 100

def render_setup(samples, out, transparent=False, seed=5, denoise=True):
    scn.render.engine = 'CYCLES'; c = scn.cycles; c.samples = samples; c.use_denoising = denoise; c.seed = seed
    try: c.denoiser = 'OPENIMAGEDENOISE'
    except Exception: pass
    c.max_bounces = 10; c.glossy_bounces = 6; c.transparent_max_bounces = 8
    try:
        scn.view_settings.view_transform = 'AgX'; scn.view_settings.look = 'AgX - Medium High Contrast'
    except Exception: pass
    scn.view_settings.exposure = 0.0
    scn.render.image_settings.file_format = 'PNG'; scn.render.image_settings.color_depth = '16'
    if transparent:
        scn.render.film_transparent = True; scn.render.image_settings.color_mode = 'RGBA'
    scn.render.filepath = out
