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

TI_BASE = (0.53, 0.52, 0.50)

def brush(nt, b, strength=0.04, axis='x', streaks=0.0):
    """Brushing along `axis`: noise stretched 1:60 drives a faint bump and an anisotropic sheen whose tangent follows the
    stroke. `streaks` (0..1) also lays the strokes into the reflectance, the visible grain of a brushed face."""
    N = nt.nodes; L = nt.links.new
    geo = N.new('ShaderNodeNewGeometry'); mp = N.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (4, 240, 1) if axis == 'x' else (240, 4, 1)
    L(geo.outputs['Position'], mp.inputs[0])
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 2.0; nz.inputs['Detail'].default_value = 6; L(mp.outputs[0], nz.inputs[0])
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = strength; bp.inputs['Distance'].default_value = 0.0005
    L(nz.outputs['Fac'], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    inp(b, 'Anisotropic').default_value = 0.35 if not streaks else 0.6
    inp(b, 'Tangent').default_value = (1, 0, 0) if axis == 'x' else (0, 1, 0)
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

def ti_studio(dome=1.0, sun=3.0, cone=22.0, rim=0.0):
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
    lo.inputs['From Min'].default_value = math.sin(math.radians(6)); lo.inputs['From Max'].default_value = math.sin(math.radians(12))
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
