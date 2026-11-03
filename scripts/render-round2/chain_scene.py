"""Proof chain, Cycles scene. Reproducible: blender -b -P chain_scene.py -- --scene desktop --mode base --scale 2 --samples 256 --out out.png

Frame units: desktop is the V5 1400 x 431 px frame; 1 px = 0.01 m. Image x -> +X, image y -> -Y, toward camera -> +Z.
The camera is orthographic, so link, plate and rail positions land on the same pixels the HTML overlay expects.
Modes: base (no carriage, plates at rest), carriage (carriage only over shadow catchers, transparent),
plate (plate N pressed with the selected indicator, over shadow catchers, transparent).
All materials are procedural; lighting is area lights only; no downloaded HDRI or texture.
"""
import bpy, bmesh, math, sys, argparse, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--scene', default='desktop'); ap.add_argument('--mode', default='base')
ap.add_argument('--stage', type=int, default=2); ap.add_argument('--scale', type=float, default=1)
ap.add_argument('--samples', type=int, default=64); ap.add_argument('--out', default='//chain.png')
ap.add_argument('--alt', type=int, default=0)
A = ap.parse_args(argv)
S = 0.01
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def P(x, y, z=0.0):
    return Vector((x * S, -y * S, z * S))

# ---------------- materials ----------------
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

def mat_simple(name, color, metal, rough, aniso=0.0, brushed=0.0, bump=0.0):
    m, nt, b = node_mat(name)
    inp(b, 'Base Color').default_value = (*color, 1); inp(b, 'Metallic').default_value = metal
    inp(b, 'Roughness').default_value = rough
    if aniso:
        # Radial tangent about Y, orthogonalised against a +Z face normal, runs along X: linear grain, not a spun disc.
        inp(b, 'Anisotropic').default_value = aniso
        tg = nt.nodes.new('ShaderNodeTangent'); tg.direction_type = 'RADIAL'; tg.axis = 'Y'
        nt.links.new(tg.outputs[0], inp(b, 'Tangent'))
    if brushed:
        # Brushing: noise stretched along X drives a fine bump and a small roughness spread.
        tc = nt.nodes.new('ShaderNodeTexCoord'); mp = nt.nodes.new('ShaderNodeMapping')
        mp.inputs['Scale'].default_value = (0.25, 140, 2)
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 3; nz.inputs['Detail'].default_value = 10
        nt.links.new(tc.outputs['Object'], mp.inputs[0]); nt.links.new(mp.outputs[0], nz.inputs[0])
        bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = brushed; bp.inputs['Distance'].default_value = 0.0004
        nt.links.new(nz.outputs['Fac'], bp.inputs['Height']); nt.links.new(bp.outputs[0], inp(b, 'Normal'))
        mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value = rough - 0.07; mr.inputs['To Max'].default_value = rough + 0.1
        nt.links.new(nz.outputs['Fac'], mr.inputs['Value']); nt.links.new(mr.outputs[0], inp(b, 'Roughness'))
    return m

def mat_varied(name, color, metal, rough, var=0.25, rvar=0.1, scale=1.6):
    """Satin machined or structural steel: large-scale tone and roughness drift so no face is one flat value."""
    m, nt, b = node_mat(name); N = nt.nodes; L = nt.links.new
    tc = N.new('ShaderNodeTexCoord'); nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = scale; nz.inputs['Detail'].default_value = 8
    L(tc.outputs['Object'], nz.inputs[0])
    ramp = N.new('ShaderNodeValToRGB'); e0, e1 = ramp.color_ramp.elements
    e0.position = 0.3; e0.color = (*[c * (1 - var) for c in color], 1); e1.position = 0.7; e1.color = (*[c * (1 + var) for c in color], 1)
    L(nz.outputs['Fac'], ramp.inputs['Fac']); L(ramp.outputs['Color'], inp(b, 'Base Color'))
    mr = N.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value = rough - rvar; mr.inputs['To Max'].default_value = rough + rvar
    L(nz.outputs['Fac'], mr.inputs['Value']); L(mr.outputs[0], inp(b, 'Roughness'))
    inp(b, 'Metallic').default_value = metal
    fine = N.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value = 90; fine.inputs['Detail'].default_value = 6
    L(tc.outputs['Object'], fine.inputs[0])
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.05; bp.inputs['Distance'].default_value = 0.001
    L(fine.outputs['Fac'], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    return m

def mat_forged(name, base=(0.05, 0.048, 0.046), worn=(0.66, 0.64, 0.6), rust=0.0, ao_dist=0.18, general=0.0):
    """Blackened forged steel: dark rough base, mill-scale patches, forging pits, bright metal only where worn.
    rust > 0 adds iron oxide where water and grime sit (see add_rust); contact points stay scrubbed bright."""
    m, nt, b = node_mat(name)
    N = nt.nodes; L = nt.links.new
    tc = N.new('ShaderNodeTexCoord'); oi = N.new('ShaderNodeObjectInfo')
    off = N.new('ShaderNodeVectorMath'); off.operation = 'ADD'
    sc = N.new('ShaderNodeVectorMath'); sc.operation = 'SCALE'; sc.inputs['Scale'].default_value = 37.0
    L(oi.outputs['Random'], sc.inputs[0]); L(tc.outputs['Object'], off.inputs[0]); L(sc.outputs[0], off.inputs[1])
    scale_patch = N.new('ShaderNodeTexNoise'); scale_patch.inputs['Scale'].default_value = 2.2; scale_patch.inputs['Detail'].default_value = 6
    L(off.outputs[0], scale_patch.inputs[0])
    micro = N.new('ShaderNodeTexNoise'); micro.inputs['Scale'].default_value = 60; micro.inputs['Detail'].default_value = 12
    L(off.outputs[0], micro.inputs[0])
    pits = N.new('ShaderNodeTexVoronoi'); pits.inputs['Scale'].default_value = 26
    L(off.outputs[0], pits.inputs[0])
    pitmask = N.new('ShaderNodeMapRange'); pitmask.inputs['From Min'].default_value = 0.0; pitmask.inputs['From Max'].default_value = 0.16
    pitmask.inputs['To Min'].default_value = 1.0; pitmask.inputs['To Max'].default_value = 0.0
    L(pits.outputs['Distance'], pitmask.inputs['Value'])
    # Mill scale: two tones of black oxide, slightly blue-grey vs brown-black.
    ramp = N.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position = 0.38; ramp.color_ramp.elements[1].position = 0.66
    ramp.color_ramp.elements[0].color = (base[0] * 0.65, base[1] * 0.64, base[2] * 0.63, 1)
    ramp.color_ramp.elements[1].color = (base[0] * 1.23, base[1] * 1.25, base[2] * 1.28, 1)
    L(scale_patch.outputs['Fac'], ramp.inputs['Fac'])
    wear = N.new('ShaderNodeAttribute'); wear.attribute_name = 'wear'
    wearc = N.new('ShaderNodeMapRange'); wearc.inputs['From Min'].default_value = 0.35; wearc.inputs['From Max'].default_value = 0.9
    L(wear.outputs['Fac'], wearc.inputs['Value'])
    # Break the wear edge up with micro noise so polished zones are not clean decals.
    wm = N.new('ShaderNodeMath'); wm.operation = 'MULTIPLY'; L(wearc.outputs[0], wm.inputs[0])
    wmn = N.new('ShaderNodeMapRange'); wmn.inputs['To Min'].default_value = 0.55; wmn.inputs['To Max'].default_value = 1.3
    L(micro.outputs['Fac'], wmn.inputs['Value']); L(wmn.outputs[0], wm.inputs[1])
    wcl = N.new('ShaderNodeClamp'); L(wm.outputs[0], wcl.inputs['Value'])
    # Mill-scale flakes: few, small Voronoi cells of blue-black oxide (never tan), slightly rougher than the base.
    fv = N.new('ShaderNodeTexVoronoi'); fv.inputs['Scale'].default_value = 19; L(off.outputs[0], fv.inputs[0])
    fsep = N.new('ShaderNodeSeparateColor'); L(fv.outputs['Color'], fsep.inputs[0])
    flake = N.new('ShaderNodeMapRange'); flake.inputs['From Min'].default_value = 0.978; flake.inputs['From Max'].default_value = 0.984
    L(fsep.outputs[0], flake.inputs['Value'])
    # Forging parting line: a narrow flash seam around the wire's equator, in the link's own plane.
    osep = N.new('ShaderNodeSeparateXYZ'); L(tc.outputs['Object'], osep.inputs[0])
    absz = N.new('ShaderNodeMath'); absz.operation = 'ABSOLUTE'; L(osep.outputs['Z'], absz.inputs[0])
    seam = N.new('ShaderNodeMapRange'); seam.inputs['From Min'].default_value = 0.004; seam.inputs['From Max'].default_value = 0.016
    seam.inputs['To Min'].default_value = 1.0; seam.inputs['To Max'].default_value = 0.0; L(absz.outputs[0], seam.inputs['Value'])
    fcol = N.new('ShaderNodeMix'); fcol.data_type = 'RGBA'; L(flake.outputs[0], fcol.inputs['Factor'])
    L(ramp.outputs['Color'], fcol.inputs[6]); fcol.inputs[7].default_value = (0.018, 0.019, 0.022, 1)
    col = N.new('ShaderNodeMix'); col.data_type = 'RGBA'
    L(wcl.outputs[0], col.inputs['Factor']); L(fcol.outputs[2], col.inputs[6]); col.inputs[7].default_value = (*worn, 1)
    pitcol = N.new('ShaderNodeMix'); pitcol.data_type = 'RGBA'
    pm2 = N.new('ShaderNodeMath'); pm2.operation = 'MULTIPLY'; pm2.inputs[1].default_value = 0.7; L(pitmask.outputs[0], pm2.inputs[0])
    L(pm2.outputs[0], pitcol.inputs['Factor']); L(col.outputs[2], pitcol.inputs[6]); pitcol.inputs[7].default_value = (0.012, 0.011, 0.011, 1)
    L(pitcol.outputs[2], inp(b, 'Base Color'))
    inp(b, 'Metallic').default_value = 1.0
    rough = N.new('ShaderNodeMapRange'); rough.inputs['To Min'].default_value = 0.42; rough.inputs['To Max'].default_value = 0.7
    L(scale_patch.outputs['Fac'], rough.inputs['Value'])
    rmix = N.new('ShaderNodeMix'); rmix.data_type = 'FLOAT'; L(wcl.outputs[0], rmix.inputs['Factor'])
    L(rough.outputs[0], rmix.inputs[2]); rmix.inputs[3].default_value = 0.17
    rf = N.new('ShaderNodeMath'); rf.operation = 'MULTIPLY_ADD'; L(flake.outputs[0], rf.inputs[0]); rf.inputs[1].default_value = 0.12; L(rmix.outputs[0], rf.inputs[2])
    rp = N.new('ShaderNodeMath'); rp.operation = 'ADD'; L(rf.outputs[0], rp.inputs[0])
    rpm = N.new('ShaderNodeMath'); rpm.operation = 'MULTIPLY'; rpm.inputs[1].default_value = 0.2; L(pitmask.outputs[0], rpm.inputs[0]); L(rpm.outputs[0], rp.inputs[1])
    L(rp.outputs[0], inp(b, 'Roughness'))
    # Height: forging undulation, pits pressed in, micro grain.
    h = N.new('ShaderNodeMath'); h.operation = 'SUBTRACT'; L(micro.outputs['Fac'], h.inputs[0]); L(pitmask.outputs[0], h.inputs[1])
    h2 = N.new('ShaderNodeMath'); h2.operation = 'MULTIPLY_ADD'; L(flake.outputs[0], h2.inputs[0]); h2.inputs[1].default_value = 0.35; L(h.outputs[0], h2.inputs[2])
    h3 = N.new('ShaderNodeMath'); h3.operation = 'MULTIPLY_ADD'; L(seam.outputs[0], h3.inputs[0]); h3.inputs[1].default_value = 0.9; L(h2.outputs[0], h3.inputs[2])
    bp = N.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.5; bp.inputs['Distance'].default_value = 0.006
    L(h3.outputs[0], bp.inputs['Height']); L(bp.outputs[0], inp(b, 'Normal'))
    if rust > 0:
        add_rust(nt, b, off, oi, wcl, pitmask, pitcol.outputs[2], rp.outputs[0], h3.outputs[0], bp, rust, ao_dist, general)
    return m

def add_rust(nt, b, off, oi, wcl, pitmask, col_in, rough_in, height_in, bump, amount, ao_dist, general=0.0):
    """Iron oxide where it really forms on hanging chain: in crevices (ambient occlusion: link interlocks, clevis eyes,
    cheek and yoke joints), on the inside of each link's bends ('rust_in', baked), in a ring just outside each contact
    ('rust_gap', baked), at pinned joints (pin_c / pin_rad), more on faces that look down. The contacts themselves stay
    scrubbed bright: rust is kept off the polished-wear zone ('wear', baked). Each object oxidises by its own amount (Object Info random). Dark, rough,
    non-metallic oxide with sparse brighter crust; never a uniform orange coat."""
    N = nt.nodes; L = nt.links.new
    def mr(src, f0, f1, t0, t1, smooth=False):
        r = N.new('ShaderNodeMapRange'); r.clamp = True
        if smooth: r.interpolation_type = 'SMOOTHSTEP'
        r.inputs['From Min'].default_value = f0; r.inputs['From Max'].default_value = f1
        r.inputs['To Min'].default_value = t0; r.inputs['To Max'].default_value = t1
        L(src, r.inputs['Value']); return r.outputs[0]
    def fn(op, a, bb=None, c=None):
        n = N.new('ShaderNodeMath'); n.operation = op
        for i, v in enumerate((a, bb, c)):
            if v is None: continue
            if isinstance(v, (int, float)): n.inputs[i].default_value = v
            else: L(v, n.inputs[i])
        return n.outputs[0]
    ao = N.new('ShaderNodeAmbientOcclusion'); ao.samples = 12; ao.only_local = False
    ao.inputs['Distance'].default_value = ao_dist * RS
    crev = mr(ao.outputs['AO'], 0.42, 0.9, 1.0, 0.0, smooth=True)
    a_in = N.new('ShaderNodeAttribute'); a_in.attribute_name = 'rust_in'
    a_gap = N.new('ShaderNodeAttribute'); a_gap.attribute_name = 'rust_gap'
    geo = N.new('ShaderNodeNewGeometry'); nsep = N.new('ShaderNodeSeparateXYZ'); L(geo.outputs['Normal'], nsep.inputs[0])
    down = mr(nsep.outputs['Y'], 0.0, -1.0, 0.0, 1.0)
    # The contact ring fades where the surface turns edge-on, or it draws a rim-light outline on the link ends.
    lw = N.new('ShaderNodeLayerWeight'); lw.inputs['Blend'].default_value = 0.5
    gap = fn('MULTIPLY', a_gap.outputs['Fac'], mr(lw.outputs['Facing'], 0.55, 0.9, 1.0, 0.15))
    # Pinned joints: a crevice ring where each pin head seats on its clevis, from world position about the pin axis
    # (object properties 'pin_c' and 'pin_rad', set in bake_wear on every clevis part), so cheek and eye carry one
    # continuous ring. Broken into arcs, heavier on the low side, with a short weep below the seat.
    pos = geo.outputs['Position']
    pc = N.new('ShaderNodeAttribute'); pc.attribute_type = 'OBJECT'; pc.attribute_name = 'pin_c'
    prd = N.new('ShaderNodeAttribute'); prd.attribute_type = 'OBJECT'; prd.attribute_name = 'pin_rad'
    dv = N.new('ShaderNodeVectorMath'); dv.operation = 'SUBTRACT'; L(pos, dv.inputs[0]); L(pc.outputs['Vector'], dv.inputs[1])
    dsep = N.new('ShaderNodeSeparateXYZ'); L(dv.outputs[0], dsep.inputs[0])
    rxy = fn('SQRT', fn('ADD', fn('MULTIPLY', dsep.outputs['X'], dsep.outputs['X']), fn('MULTIPLY', dsep.outputs['Y'], dsep.outputs['Y'])))
    rn = fn('DIVIDE', rxy, prd.outputs['Fac'])
    dy = fn('DIVIDE', dsep.outputs['Y'], fn('MAXIMUM', rxy, 1e-5))       # -1 straight below the pin (image down)
    has_pin = mr(prd.outputs['Fac'], 0.0, 1e-4, 0.0, 1.0)
    rnz = N.new('ShaderNodeTexNoise'); rnz.inputs['Scale'].default_value = 10 / RS; rnz.inputs['Detail'].default_value = 3; L(pos, rnz.inputs[0])
    ring_gate = fn('MULTIPLY', mr(rnz.outputs['Fac'], 0.52, 0.62, 0.0, 1.0), mr(dy, 0.3, -0.8, 0.25, 1.0))
    # Round the pin head the crevice term takes the same gaps and low-side weight as the ring; otherwise the occlusion
    # at the pin-head step paints an even copper washer.
    near = fn('MULTIPLY', has_pin, mr(rn, 1.0, 1.3, 1.0, 0.0))
    crev = fn('MULTIPLY', crev, fn('ADD', fn('SUBTRACT', 1.0, near), fn('MULTIPLY', near, ring_gate)))
    if A.scene == 'mobile':
        crev = fn('MULTIPLY', crev, fn('MULTIPLY_ADD', has_pin, -0.8, 1.0))   # see the phone clevis patches below
    pot = fn('MAXIMUM', fn('MAXIMUM', crev, fn('MULTIPLY', a_in.outputs['Fac'], 0.6)), gap)
    pot = fn('MULTIPLY_ADD', down, 0.45, pot)
    ring = fn('MULTIPLY', fn('MULTIPLY', mr(rn, 0.64, 0.74, 0.0, 1.0), mr(rn, 0.95, 1.15, 1.0, 0.0)), ring_gate)
    weep = fn('MULTIPLY', mr(rn, 0.9, 1.6, 1.0, 0.0), mr(dy, -0.6, -0.95, 0.0, 1.0))
    ring = fn('MULTIPLY', fn('MAXIMUM', ring, fn('MULTIPLY', weep, 0.7)), has_pin)
    pot = fn('MAXIMUM', pot, fn('MULTIPLY', ring, 0.35))
    # One random value per part (per clevis assembly for the anchors: 'rust_seed', set in bake_wear), split into two
    # independent draws: one sets how much the part oxidises, the other its general level. Drawing both from the same
    # value left a low-drawn link clean on every face.
    seed = N.new('ShaderNodeAttribute'); seed.attribute_type = 'OBJECT'; seed.attribute_name = 'rust_seed'
    rnd = fn('ADD', fn('MULTIPLY', oi.outputs['Random'], fn('SUBTRACT', 1.0, has_pin)), fn('MULTIPLY', seed.outputs['Fac'], has_pin))
    h1 = fn('FRACT', fn('MULTIPLY_ADD', rnd, 7.31, 0.13))
    h2 = fn('FRACT', fn('MULTIPLY_ADD', rnd, 13.7, 0.61))
    # Every part also oxidises a little on its own account, whichever way it faces, less on faces that look up.
    up = mr(nsep.outputs['Y'], 0.0, 1.0, 0.0, 1.0)
    gen = fn('MULTIPLY', fn('MULTIPLY_ADD', h2, 0.18, general), fn('MULTIPLY_ADD', up, -0.6, 1.0))
    # Noise coordinates: each link keeps its own offset; clevis parts use world position, so one forged clevis (cheeks,
    # eye, yoke) reads as one piece and its small eye cannot fall inside a single blotch of its own.
    wsc = N.new('ShaderNodeVectorMath'); wsc.operation = 'ADD'; L(pos, wsc.inputs[0]); wsc.inputs[1].default_value = (3.7, 1.9, 5.3)
    mixv = N.new('ShaderNodeMix'); mixv.data_type = 'VECTOR'; L(has_pin, mixv.inputs['Factor'])
    L(off.outputs[0], mixv.inputs[4]); L(wsc.outputs[0], mixv.inputs[5]); rco = mixv.outputs[1]
    # Per-part amount and broad blotches, so no two links rust alike and no edge is an even band.
    amt = mr(h1, 0.0, 1.0, 0.9 * amount, 1.15 * amount)
    blot = N.new('ShaderNodeTexNoise'); blot.inputs['Scale'].default_value = 3.2 / RS; blot.inputs['Detail'].default_value = 6
    blot.inputs['Roughness'].default_value = 0.62; L(rco, blot.inputs[0])
    grain = N.new('ShaderNodeTexNoise'); grain.inputs['Scale'].default_value = 140 / RS; grain.inputs['Detail'].default_value = 4
    L(rco, grain.inputs[0])
    # General oxide sits in its own, independent blotches: a face that misses the crevice blotches (an edge-on link's
    # outer flank has no crevice at all) still gets patches of its own.
    gofs = N.new('ShaderNodeVectorMath'); gofs.operation = 'ADD'; L(rco, gofs.inputs[0]); gofs.inputs[1].default_value = (7.1, 3.3, 9.9)
    gblot = N.new('ShaderNodeTexNoise'); gblot.inputs['Scale'].default_value = 2.6 / RS; gblot.inputs['Detail'].default_value = 6
    gblot.inputs['Roughness'].default_value = 0.62; L(gofs.outputs[0], gblot.inputs[0])
    raw = fn('MULTIPLY', fn('ADD', fn('MULTIPLY', pot, mr(blot.outputs['Fac'], 0.4, 0.62, 0.0, 1.8)),
                            fn('MULTIPLY', gen, mr(gblot.outputs['Fac'], 0.4, 0.62, 0.0, 1.8))), amt)
    # Granular edges: two fine noises push the threshold around, so oxide breaks into grains and islands.
    speck = N.new('ShaderNodeTexNoise'); speck.inputs['Scale'].default_value = 420 / RS; speck.inputs['Detail'].default_value = 2
    L(rco, speck.inputs[0])
    raw = fn('MULTIPLY', raw, mr(grain.outputs['Fac'], 0.25, 0.75, 0.5, 1.5))
    raw = fn('MULTIPLY', raw, mr(speck.outputs['Fac'], 0.3, 0.7, 0.75, 1.3))
    mask = mr(raw, 0.48, 0.62, 0.0, 1.0, smooth=True)
    # Pitting rust: a sparse share of the forging pits weep oxide wherever they are, not only in crevices.
    spn = N.new('ShaderNodeTexNoise'); spn.inputs['Scale'].default_value = 9 / RS; spn.inputs['Detail'].default_value = 3
    L(rco, spn.inputs[0])
    spots = fn('MULTIPLY', mr(pitmask.outputs[0], 0.5, 0.85, 0.0, 1.0), mr(spn.outputs['Fac'], 0.56, 0.64, 0.0, 1.0))
    mask = fn('MAXIMUM', mask, fn('MULTIPLY', spots, mr(amt, 0.0, 1.0, 0.4, 0.95)))
    if A.scene == 'mobile':
        # Phone only: the clevis parts are small enough there that the crevice term fills each pin seat and yoke with one
        # even colour (a washer ring, a solid block). Their oxide is drawn instead as broken patches about 3 frame px
        # across (6 px in the 2x image, so the gaps survive), over dark stained steel, at about the links' coverage.
        # The desktop graph is untouched.
        brk = N.new('ShaderNodeTexNoise'); brk.inputs['Scale'].default_value = 14 / RS; brk.inputs['Detail'].default_value = 2
        L(rco, brk.inputs[0])
        keep = fn('ADD', fn('SUBTRACT', 1.0, has_pin), fn('MULTIPLY', has_pin, mr(brk.outputs['Fac'], 0.52, 0.6, 0.0, 1.0)))
        mask = fn('MULTIPLY', mask, keep)
    # Scrubbed contacts stay bright: neither oxide nor its stain where the wear polish shows.
    clean = fn('SUBTRACT', 1.0, wcl.outputs[0])
    stain = fn('MULTIPLY', mr(raw, 0.3, 0.5, 0.0, 0.5), clean)
    mask = fn('MULTIPLY', mask, clean)
    # Oxide colour: mostly dark brown, mid red-brown in patches, a few brighter crust specks where it is thickest.
    tone = N.new('ShaderNodeTexNoise'); tone.inputs['Scale'].default_value = 24 / RS; tone.inputs['Detail'].default_value = 8
    L(rco, tone.inputs[0])
    rc = N.new('ShaderNodeValToRGB'); e = rc.color_ramp.elements
    e[0].position = 0.2; e[0].color = (0.012, 0.0065, 0.004, 1); e[1].position = 0.92; e[1].color = (0.105, 0.05, 0.012, 1)
    rc.color_ramp.elements.new(0.6).color = (0.07, 0.024, 0.008, 1)
    L(tone.outputs['Fac'], rc.inputs['Fac'])
    crust = fn('MULTIPLY', mr(speck.outputs['Fac'], 0.6, 0.72, 0.0, 1.0), mr(mask, 0.85, 1.0, 0.0, 1.0))
    rcol = N.new('ShaderNodeMix'); rcol.data_type = 'RGBA'; L(crust, rcol.inputs['Factor'])
    L(rc.outputs['Color'], rcol.inputs[6]); rcol.inputs[7].default_value = (0.2, 0.09, 0.02, 1)
    # A thin brown stain on the scale around each patch before the oxide proper.
    st = N.new('ShaderNodeMix'); st.data_type = 'RGBA'; L(stain, st.inputs['Factor'])
    L(col_in, st.inputs[6]); st.inputs[7].default_value = (0.018, 0.011, 0.0075, 1)
    out = N.new('ShaderNodeMix'); out.data_type = 'RGBA'; L(fn('MULTIPLY', mask, 0.96), out.inputs['Factor'])
    L(st.outputs[2], out.inputs[6]); L(rcol.outputs[2], out.inputs[7]); L(out.outputs[2], inp(b, 'Base Color'))
    L(fn('MULTIPLY_ADD', mask, -0.92, 1.0), inp(b, 'Metallic'))
    L(fn('MULTIPLY_ADD', mask, -0.3, 0.5), inp(b, 'Specular IOR Level', 'Specular'))
    rr = N.new('ShaderNodeMix'); rr.data_type = 'FLOAT'; L(mask, rr.inputs['Factor'])
    L(rough_in, rr.inputs[2]); rr.inputs[3].default_value = 0.88; L(rr.outputs[0], inp(b, 'Roughness'))
    # Oxide sits proud of the steel as a fine crust.
    L(fn('MULTIPLY_ADD', fn('MULTIPLY', mask, grain.outputs['Fac']), 0.9, height_in), bump.inputs['Height'])

# Rust only in the chain scenes' base and sample renders. ui_parts reuses the link material for the key couplers,
# which stay clean, and the carriage/plate sprite modes keep the 76767e4 material graph, so they render exactly as the
# 76767e4 script does (the shipped carriage masters were made earlier, from Factory's copy of this scene).
RUST = 1.0 if A.scene in ('desktop', 'mobile') and A.mode in ('base', 'sample') else 0.0
# The mobile chain is the desktop chain scaled by chain_mobile's pitch ratio K; rust features scale with it.
RS = 95.08 / 208.6 if A.scene == 'mobile' else 1.0
M = {}
M['link'] = mat_forged('forged-link', rust=RUST, general=0.26)
M['clevis'] = mat_forged('forged-clevis', base=(0.045, 0.044, 0.043), worn=(0.45, 0.44, 0.42), rust=RUST * 1.9, ao_dist=0.16, general=0.3)
M['housing'] = mat_varied('satin-structural', (0.04, 0.042, 0.046), 0.8, 0.4, var=0.22, rvar=0.07, scale=1.4)
M['bore'] = mat_varied('structural-back-wall', (0.034, 0.033, 0.032), 0.6, 0.58, var=0.3, rvar=0.1, scale=2.4)
M['rail'] = mat_simple('blackened-rail', (0.03, 0.03, 0.031), 0.9, 0.34, brushed=0.05)
M['ground'] = mat_simple('ground-face', (0.5, 0.5, 0.5), 1.0, 0.2, brushed=0.12)
M['stainless'] = mat_simple('brushed-stainless', (0.52, 0.52, 0.51), 1.0, 0.24, aniso=0.6, brushed=0.3)
# Stage plates carry engraved labels, so their face is a lighter, partly diffuse brushed stainless: under the black
# studio world a fully metallic face renders too dark for the labels to reach 4.5:1.
M['plate'] = mat_simple('plate-stainless', (0.52, 0.52, 0.51), 0.78, 0.3, aniso=0.55, brushed=0.3)
M['pin'] = mat_simple('turned-pin', (0.42, 0.42, 0.41), 1.0, 0.26, brushed=0.1)
M['screw'] = mat_simple('blackened-screw', (0.05, 0.05, 0.052), 1.0, 0.3)
M['brass'] = mat_simple('brass-witness', (0.82, 0.6, 0.33), 1.0, 0.28)
M['champagne'] = mat_simple('champagne-indicator', (0.84, 0.72, 0.52), 1.0, 0.2, brushed=0.15)
M['lens'] = mat_simple('dark-indicator', (0.075, 0.078, 0.085), 1.0, 0.3, brushed=0.1)
M['engrave'] = mat_simple('engraved-cut', (0.02, 0.02, 0.02), 1.0, 0.55)

# ---------------- geometry helpers ----------------
def link_obj(name, cx, cy, theta, phi, a, R, r):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r * S; cu.bevel_resolution = 10
    sp = cu.splines.new('POLY'); pts = []
    n, m = 56, 12
    for i in range(n + 1): t = -math.pi / 2 + math.pi * i / n; pts.append((a + R * math.cos(t), R * math.sin(t)))
    for i in range(1, m): pts.append((a - 2 * a * i / m, R))
    for i in range(n + 1): t = math.pi / 2 + math.pi * i / n; pts.append((-a + R * math.cos(t), R * math.sin(t)))
    for i in range(1, m): pts.append((-a + 2 * a * i / m, -R))
    sp.points.add(len(pts) - 1)
    for p, (x, y) in zip(sp.points, pts): p.co = (x * S, y * S, 0, 1)
    sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name + '-c', cu); scn.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob); mo = bpy.data.objects.new(name, me); scn.collection.objects.link(mo)
    for pg in me.polygons: pg.use_smooth = True
    mo.matrix_world = Matrix.Translation(P(cx, cy)) @ Matrix.Rotation(-theta, 4, 'Z') @ Matrix.Rotation(phi, 4, 'X')
    # Forging irregularity in the cross-section, sampled in world space so no two links share it.
    tex = bpy.data.textures.get('forge') or bpy.data.textures.new('forge', 'CLOUDS'); tex.noise_scale = 0.16; tex.noise_depth = 2
    dm = mo.modifiers.new('forge', 'DISPLACE'); dm.texture = tex; dm.texture_coords = 'GLOBAL'; dm.strength = 0.03; dm.mid_level = 0.5
    mo.data.materials.append(M['link']); return mo

def box(name, x0, y0, z0, x1, y1, z1, mat, bevel=2.0, seg=3):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.active_object; ob.name = name
    ob.location = P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2); ob.scale = ((x1 - x0) * S, (y1 - y0) * S, (z1 - z0) * S)
    bpy.ops.object.transform_apply(scale=True)
    if bevel: md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = seg; md.limit_method = 'ANGLE'; md.harden_normals = False
    ob.data.materials.append(M[mat]); return ob

def cyl(name, x, y, z0, z1, rad, mat, bevel=0.8, axis='Z', verts=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=rad * S, depth=abs(z1 - z0) * S, vertices=verts)
    ob = bpy.context.active_object; ob.name = name
    if axis == 'Z': ob.location = P(x, y, (z0 + z1) / 2)
    else: ob.rotation_euler = (0, math.pi / 2, 0); ob.location = P((z0 + z1) / 2, y, x)
    if bevel: md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = 3; md.limit_method = 'ANGLE'
    for pg in ob.data.polygons: pg.use_smooth = True
    ob.data.materials.append(M[mat]); return ob

def boolean(target, cutter, op='DIFFERENCE'):
    md = target.modifiers.new('bool', 'BOOLEAN'); md.operation = op; md.object = cutter; md.solver = 'EXACT'
    # Bevel after boolean so the cut edges get the same machined chamfer.
    mods = target.modifiers
    if 'bev' in mods: mods.move(mods.find('bool'), 0)
    cutter.hide_render = True; cutter.hide_viewport = True

def cap_screw(name, x, y, zface, rh, mat='screw'):
    """Socket head cap screw: chamfered head, hex socket, slight wear on the crown edge from the driver."""
    h = cyl(name, x, y, zface, zface + rh * 0.9, rh, mat, bevel=rh * 0.18)
    bpy.ops.mesh.primitive_cylinder_add(radius=rh * 0.42 * S, depth=rh * 0.8 * S, vertices=6)
    hx = bpy.context.active_object; hx.location = P(x, y, zface + rh * 0.9); hx.rotation_euler = (0, 0, random.uniform(0, 1))
    boolean(h, hx); return h

def tapered_finger(name, x, y_tip, y_base, z, w_base, w_tip, t, mat):
    bm = bmesh.new()
    pts = [(-w_base / 2, y_base), (w_base / 2, y_base), (w_tip / 2, y_tip + 2), (0, y_tip), (-w_tip / 2, y_tip + 2)]
    vf = [bm.verts.new(P(x + px, py, z + t / 2)) for px, py in pts]; vb = [bm.verts.new(P(x + px, py, z - t / 2)) for px, py in pts]
    bm.faces.new(vf); bm.faces.new(list(reversed(vb)))
    for i in range(len(pts)): j = (i + 1) % len(pts); bm.faces.new((vf[j], vf[i], vb[i], vb[j]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.normals_split_custom_set(None) if False else None
    ob = bpy.data.objects.new(name, me); scn.collection.objects.link(ob)
    md = ob.modifiers.new('bev', 'BEVEL'); md.width = 0.9 * S; md.segments = 3; md.limit_method = 'ANGLE'
    ob.data.materials.append(M[mat]); return ob

# ---------------- desktop scene ----------------
# Plate and mark x positions are the V5 alignment data; the HTML stage buttons sit on these plates.
CX = [247.9, 456.5, 666.2, 876.0, 1085.1]
PLX = [169, 378, 588, 797.4, 1006.4]; PLATE_W = 157.1; PLATE_Y0, PLATE_Y1 = 317, 397
RAIL_Y = 272
MARKS = [p + PLATE_W / 2 for p in PLX]
MID, HALF, SAG, YEND = 666.2, 418.9, 34.0, 148.0
def chain_y(x):
    # Slight gravity sag between the anchors (parabolic approximation of the catenary).
    return YEND + SAG * (1 - ((x - MID) / HALF) ** 2)
def chain_slope(x):
    return -2 * SAG * (x - MID) / HALF ** 2
CY = [chain_y(x) for x in CX]
LINK_R, LINK_r, LINK_a = 42, 20, 37.5
PHI_FACE, PHI_EDGE = -0.1, math.pi / 2 - 0.2   # face-on checkpoint links; connecting links nearly edge-on
links, catchers, plate_parts = [], [], {}

def sunk_screw(target, name, x, y, zface, rh, mat='screw'):
    """Socket screw seated in a counterbore, so its head reads with depth and a shadowed ring."""
    cut = cyl(name + '-cb', x, y, zface - rh * 0.75, zface + 30, rh + 1.4, 'screw', bevel=0); boolean(target, cut)
    return cap_screw(name, x, y, zface - rh * 0.75, rh, mat)

def build_desktop():
    for i in range(5):
        links.append(link_obj(f'check-{i+1}', CX[i], CY[i], math.atan(chain_slope(CX[i])), PHI_FACE, LINK_a, LINK_R, LINK_r))
        if i < 4:
            mx = (CX[i] + CX[i + 1]) / 2
            links.append(link_obj(f'connect-{i+1}', mx, chain_y(mx), math.atan(chain_slope(mx)), PHI_EDGE, LINK_a, LINK_R, LINK_r))
    # Housing: one machined frame, stepped and bored, a few purposeful fasteners, a pocket for each plate.
    frame = box('frame', 0, 0, -110, 1400, 431, 50, 'housing', bevel=6, seg=3)
    boolean(frame, box('step-cut', 26, 30, 42, 1374, 310, 80, 'housing', bevel=0))
    boolean(frame, box('bore-cut', 40, 44, -72, 1360, 300, 80, 'housing', bevel=0))
    for i, x in enumerate(PLX):
        boolean(frame, box(f'pocket-{i}', x - 2.5, PLATE_Y0 - 2.5, 45, x + PLATE_W + 2.5, PLATE_Y1 + 2.5, 80, 'housing', bevel=0))
    floor = box('bore-floor', 40.5, 44.5, -71.9, 1359.5, 299.5, -71.5, 'bore', bevel=0)
    catchers.extend([frame, floor])
    for (x, y) in [(15, 15), (1385, 15), (15, 416), (1385, 416)]: catchers.append(sunk_screw(frame, 'frame-screw', x, y, 50, 6.5))
    # End blocks: heavy chamfered blocks with counterbored screws and a bored cross-pin that captures the tension rod.
    for side in (-1, 1):
        lc = 0 if side < 0 else 4
        th = math.atan(chain_slope(CX[lc]))
        px = CX[lc] + side * 48.0 * math.cos(th); py = CY[lc] + side * 48.0 * math.sin(th)
        bx0, bx1 = (46, 128) if side < 0 else (1212, 1352)
        blk = box('end-block', bx0, 56, -72, bx1, 284, 24, 'housing', bevel=8, seg=4); catchers.append(blk)
        sx = bx0 + 24 if side < 0 else bx1 - 24
        for yy in (86, 254): catchers.append(sunk_screw(blk, 'block-screw', sx, yy, 24, 7.5))
        face = bx1 if side < 0 else bx0
        rod_y = py - (px - face) * math.tan(th) * (1 if side < 0 else 1)
        cpx = (bx0 + bx1) / 2 if side < 0 else bx0 + 34
        boolean(blk, cyl('cross-bore', cpx, rod_y, 10, 40, 15, 'pin', bevel=0))
        cyl('cross-pin', cpx, rod_y, 4, 16, 10, 'pin', bevel=1.4)
        # Spherical seat on the block face where the tension rod enters its bore: the visible end of the load path.
        seat = cyl('rod-seat', 0, 0, face - side * 7, face + side * 2, 21, 'pin', bevel=4, axis='X'); seat.location = P(face - side * 2.5, rod_y, 0)
        catchers.append(seat)
        # Forged clevis assembly, built level at the pin and then turned to the chain's end tangent.
        group = []
        yoke_x = px + side * -0.0 + (-1 if side < 0 else 1) * -0.0
        yoke_x = face - side * 46
        x0, x1 = sorted((yoke_x, px))
        for zc in (-34, 34):
            group.append(box('clevis-cheek', x0, py - 26, zc - 7, x1, py + 26, zc + 7, 'clevis', bevel=3))
            group.append(cyl('clevis-eye', px, py, zc - 7, zc + 7, 26, 'clevis', bevel=3))
        group.append(box('clevis-yoke', yoke_x - 16, py - 30, -42, yoke_x + 16, py + 30, 42, 'clevis', bevel=5))
        rx0, rx1 = sorted((face + side * 20, yoke_x))
        rod = cyl('tension-rod', 0, 0, rx0, rx1, 12, 'pin', axis='X'); rod.location = P((rx0 + rx1) / 2, py, 0); group.append(rod)
        nut_x = yoke_x + side * 23
        nut = cyl('tension-nut', 0, 0, nut_x - 7, nut_x + 7, 19, 'screw', axis='X', verts=6); nut.location = P(nut_x, py, 0); group.append(nut)
        group.append(cyl('clevis-pin', px, py, -46, 46, 11.5, 'pin', bevel=0.6))
        group.append(cyl('pin-head', px, py, 41, 47, 18, 'pin', bevel=1.6))
        group.append(cyl('pin-collar', px, py, -47, -41, 16, 'pin', bevel=1.2))
        bpy.ops.mesh.primitive_torus_add(major_radius=13.5 * S, minor_radius=1.6 * S, major_segments=48, minor_segments=8)
        clip = bpy.context.active_object; clip.location = P(px, py, -49); clip.data.materials.append(M['pin']); group.append(clip)
        piv = P(px, py)
        R = Matrix.Translation(piv) @ Matrix.Rotation(-th, 4, 'Z') @ Matrix.Translation(-piv)
        for ob in group: ob.matrix_world = R @ ob.matrix_basis
    # Exposed V-way: blackened bar with deep 45-degree chamfers, ground running face, five engraved registration marks.
    rail = box('rail', 150, RAIL_Y - 10, -18, 1190, RAIL_Y + 10, 6, 'rail', bevel=6.5, seg=1)
    run = box('rail-running-face', 151, RAIL_Y - 11, -14, 1189, RAIL_Y - 8.4, 3, 'ground', bevel=0.4)
    for x in (150, 1190):
        so = box('stand-off', x - 16, RAIL_Y - 15, -72, x + 16, RAIL_Y + 15, -14, 'housing', bevel=3); catchers.append(so)
        catchers.append(cap_screw('stand-off-screw', x, RAIL_Y, 6, 5.5))
    for i, mx in enumerate(MARKS):
        boolean(rail, box(f'mark-{i}', mx - 0.9, RAIL_Y - 6, 3.6, mx + 0.9, RAIL_Y + 11, 9, 'rail', bevel=0))
    catchers.extend([rail, run])
    # Stage plates: 9.5px thick linear-brushed stainless in their pockets, two diagonal screws, an indicator
    # window with a dark steel flag; RELEASE carries an inset brass witness plug.
    for i, x in enumerate(PLX):
        yc = (PLATE_Y0 + PLATE_Y1) / 2; top = 56.0
        plate = box(f'plate-{i}', x, PLATE_Y0, 46.5, x + PLATE_W, PLATE_Y1, top, 'plate', bevel=3.2, seg=1)
        # Shallow window with the flag nearly flush, so an unselected plate reads finished rather than slotted.
        boolean(plate, box(f'window-{i}', x + 9, yc - 17, top - 1.5, x + 28, yc + 17, top + 5, 'stainless', bevel=0))
        parts = [plate]
        parts.append(box('flag', x + 10.4, yc - 15.6, top - 2.4, x + 26.6, yc + 15.6, top - 0.35, 'lens', bevel=0.6))
        parts.append(cap_screw('plate-screw', x + 9, PLATE_Y0 + 9, top, 3.8))
        parts.append(cap_screw('plate-screw', x + PLATE_W - 9, PLATE_Y1 - 9, top, 3.8))
        if i == 3:
            boolean(plate, cyl('witness-cb', x + PLATE_W - 19, yc, top - 2.2, top + 5, 7.2, 'brass', bevel=0))
            parts.append(cyl('brass-witness', x + PLATE_W - 19, yc, top - 2.4, top - 0.5, 6.0, 'brass', bevel=0.5))
        plate_parts[i] = parts

FINGER_CLEAR = 6.0
def link_low(i, x, half=14):
    """Lowest image-y of checkpoint link i within +/-half px of x, measured on the evaluated (displaced) mesh."""
    o = bpy.data.objects[f'check-{i+1}']; dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg); me = ev.to_mesh()
    ys = [-(o.matrix_world @ v.co).y / S for v in me.vertices if abs((o.matrix_world @ v.co).x / S - x) < half]
    ev.to_mesh_clear(); return max(ys)

def add_carriage(x, stage):
    """Machined stainless carriage on the V-way: chamfered block, wipers where the rail enters, gib strip with
    adjusting screws, a stepped boss carrying the pointer finger, sprung detent lever."""
    y = RAIL_Y; parts = []
    # The sagging chain leaves only ~16 px between the middle link and the rail, so the body's upper edge sits
    # 11 px above the rail axis; the finger tip is set per stage to a fixed clearance below that stage's link.
    parts.append(box('carriage-body', x - 88, y - 11, -6, x + 88, y + 25, 34, 'stainless', bevel=6, seg=1))
    parts.append(box('carriage-saddle', x - 80, y - 11, -26, x + 80, y + 20, -6, 'stainless', bevel=2))
    for sx in (-1, 1):
        parts.append(box('wiper', x + sx * 88 - (0 if sx > 0 else 6), y - 10, -22, x + sx * 88 + (6 if sx > 0 else 0), y + 15, 22, 'rail', bevel=1.5))
    parts.append(box('gib', x - 74, y + 14, 34, x + 74, y + 21, 36.5, 'rail', bevel=0.8))
    for gx in (-52, 52): parts.append(cap_screw('gib-screw', x + gx, y + 17.5, 36.5, 2.6))
    tip = link_low(stage, x) + FINGER_CLEAR
    parts.append(box('finger-boss-lower', x - 17, y - 9, 34, x + 17, y + 8, 38, 'stainless', bevel=1.2, seg=1))
    parts.append(box('finger-boss-upper', x - 11, y - 11, 38, x + 11, y + 3, 42, 'stainless', bevel=1.0, seg=1))
    parts.append(cap_screw('finger-screw', x, y + 4.5, 38, 2.4))
    parts.append(tapered_finger('pointer-finger', x, tip, y - 4, 41, 15, 4.5, 5, 'stainless'))
    parts.append(box('detent-lever', x + 22, y + 1, 34, x + 46, y + 8, 38, 'rail', bevel=1.2))
    parts.append(cap_screw('detent-pivot', x + 26, y + 4.5, 38, 2.6, 'pin'))
    for dx in (-62, 62): parts.append(cap_screw('carriage-screw', x + dx, y + 4, 34, 6))
    print('FINGER', stage, round(tip, 1), 'visible', round(y - 11 - tip, 1))
    return parts
# ---------------- wear attribute ----------------
def bake_wear(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    trees = {}
    for o in objs:
        me = o.data
        trees[o.name] = BVHTree.FromPolygons([o.matrix_world @ v.co for v in me.vertices], [list(p.vertices) for p in me.polygons])
    pins = [o for o in scn.objects if o.name.startswith('clevis-pin')]
    for o in pins:
        ev = o.evaluated_get(dg); me = ev.to_mesh()
        trees[o.name] = BVHTree.FromPolygons([o.matrix_world @ v.co for v in me.vertices], [list(p.vertices) for p in me.polygons])
        ev.to_mesh_clear()
    # Each clevis part learns its pin's axis and the eye radius, for the pinned-joint rust ring.
    eyes = [o for o in scn.objects if o.name.startswith('clevis-eye')]
    for o in scn.objects:
        if o.name.startswith(('clevis-cheek', 'clevis-eye', 'clevis-yoke')) and pins and eyes:
            c = o.matrix_world @ (sum((Vector(bb) for bb in o.bound_box), Vector()) / 8)
            pin = min(pins, key=lambda q: (q.matrix_world.translation - c).length)
            eye = min(eyes, key=lambda q: (q.matrix_world.translation - pin.matrix_world.translation).length)
            o['pin_c'] = list(pin.matrix_world.translation)
            o['pin_rad'] = max(math.hypot(v.co.x, v.co.y) for v in eye.data.vertices)
            pw = pin.matrix_world.translation; o['rust_seed'] = abs(pw.x * 0.37 + pw.y * 0.61) * 7.13 % 1.0   # one per assembly
    for o in objs:
        me = o.data; mw = o.matrix_world
        attr = me.color_attributes.new('wear', 'FLOAT_COLOR', 'POINT')
        # Rust maps from the same distances. The link is built flat in its local XY plane, so its stadium centre line
        # (half-length a, bend radius R) and wire radius r follow from the undisplaced mesh's extent.
        r_in = me.color_attributes.new('rust_in', 'FLOAT_COLOR', 'POINT')
        r_gap = me.color_attributes.new('rust_gap', 'FLOAT_COLOR', 'POINT')
        xs = [abs(v.co.x) for v in me.vertices]; ys = [abs(v.co.y) for v in me.vertices]; zs = [abs(v.co.z) for v in me.vertices]
        wr = max(zs); Rb = max(ys) - wr; ah = max(xs) - max(ys)
        for v in me.vertices:
            wp = mw @ v.co; best = 1e9
            for n2, t in trees.items():
                if n2 == o.name: continue
                hit = t.find_nearest(wp)
                if hit[0] is not None: best = min(best, hit[3])
            w = max(0.0, 1.0 - best / (14 * S))
            attr.data[v.index].color = (w, w, w, 1)
            # Inside of the bend: how far the surface point faces the link's eye (1 innermost), strongest on the bows
            # where the next link bears and water collects.
            x, y = v.co.x, v.co.y
            if abs(x) <= ah:
                nx, ny, cx, cy = 0.0, (1.0 if y >= 0 else -1.0), x, (Rb if y >= 0 else -Rb)
            else:
                ox = ah if x > 0 else -ah; dx, dy = x - ox, y; d = math.hypot(dx, dy) or 1.0
                nx, ny, cx, cy = dx / d, dy / d, ox + Rb * dx / d, Rb * dy / d
            tb = max(0.0, min(1.0, (abs(x) - ah + 0.3 * Rb) / (0.6 * Rb))); bow = 0.3 + 0.7 * tb * tb * (3 - 2 * tb)
            inner = -((x - cx) * nx + (y - cy) * ny) / max(wr, 1e-6)
            ri = max(0.0, min(1.0, inner)) * bow
            r_in.data[v.index].color = (ri, ri, ri, 1)
            # A ring just outside each contact: oxide builds where the joint traps moisture but nothing rubs. In wire
            # radii, so it scales with the link (desktop r = 20 px: 6-9 px rising, 14-28 px falling).
            bp = best / wr
            gp = max(0.0, min(1.0, (bp - 0.3) / 0.15)) * max(0.0, min(1.0, (1.4 - bp) / 0.7))
            r_gap.data[v.index].color = (gp, gp, gp, 1)

# ---------------- lights, camera, render ----------------
def area(name, loc, target, size, power, color, shape='RECTANGLE'):
    ld = bpy.data.lights.new(name, 'AREA'); ld.shape = shape; ld.size = size[0]; ld.size_y = size[1]
    ld.energy = power; ld.color = color
    if name == 'cavity-wash':
        ld.specular_factor = 0.0
    ob = bpy.data.objects.new(name, ld); scn.collection.objects.link(ob); ob.location = loc
    d = (Vector(target) - Vector(loc)); ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); return ob

def studio(cx, cy, k=1.0):
    # One studio: big warm softbox upper left, cool strip at right, dim top bounce, low front scrim. World is black.
    # Raked steeply from above so its long specular tail does not wash camera-facing plate; curved tops still catch it.
    area('key-softbox', (cx - 5 * k, cy + 8 * k, 3.6 * k), (cx + 1 * k, cy - 1.5 * k, 0), (9 * k, 3.2 * k), 9000 * k * k, (1.0, 0.94, 0.85))
    area('rim-strip', (cx + 9.5 * k, cy + 1.5 * k, 5 * k), (cx + 3 * k, cy, 0), (0.5 * k, 6 * k), 900 * k * k, (0.9, 0.95, 1.0))
    area('top-bounce', (cx, cy + 9 * k, 3 * k), (cx, cy, 0), (14 * k, 2 * k), 1000 * k * k, (1.0, 0.98, 0.95))
    # Reflection card behind the lens: invisible to the camera, it gives faces that look straight at the camera a
    # soft top-to-bottom falloff (bright edge high, dark low) instead of a flat value.
    bpy.ops.mesh.primitive_plane_add(size=1); card = bpy.context.active_object; card.name = 'reflection-card'
    card.location = (cx, cy + 0.8 * k, 24 * k); card.scale = (40 * k, 22 * k, 1); card.rotation_euler = (math.pi, 0, 0)
    cm, nt, b = node_mat('card'); nt.nodes.remove(b)
    em = nt.nodes.new('ShaderNodeEmission'); tcn = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    rmp = nt.nodes.new('ShaderNodeValToRGB'); e0, e1 = rmp.color_ramp.elements
    e0.position = 0.4; e0.color = (0.0, 0.0, 0.0, 1); e1.position = 0.62; e1.color = (0.8, 0.79, 0.77, 1)
    nt.links.new(tcn.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Y'], rmp.inputs['Fac'])
    nt.links.new(rmp.outputs['Color'], em.inputs['Color']); em.inputs['Strength'].default_value = 0.45
    nt.links.new(em.outputs[0], nt.nodes['Material Output'].inputs['Surface']); card.data.materials.append(cm)
    card.visible_camera = False; card.visible_shadow = False; card.visible_diffuse = False
    # Weak wash inside the bore so the floor keeps a soft falloff instead of going to black.
    # Spill through the bore opening: just inside the front lip, aimed down at the floor, so the cavity reads with depth.
    area('cavity-wash', (cx + 1.5 * k, cy + 1.45 * k, 0.3 * k), (cx + 1.5 * k, cy - 2.6 * k, -0.72 * k), (9 * k, 1.2 * k), 130 * k * k, (0.9, 0.94, 1.0))
    w = bpy.data.worlds.new('black'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.002, 0.002, 0.0022, 1)
    scn.world = w

def camera(cx, cy, width_bu, w_px, h_px):
    cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = width_bu; cd.sensor_fit = 'HORIZONTAL'
    cam = bpy.data.objects.new('cam', cd); scn.collection.objects.link(cam); cam.location = (cx, cy, 30); scn.camera = cam
    scn.render.resolution_x = int(w_px); scn.render.resolution_y = int(h_px); scn.render.resolution_percentage = 100

def render_setup():
    scn.render.engine = 'CYCLES'; c = scn.cycles; c.samples = A.samples; c.use_denoising = True
    try: c.denoiser = 'OPENIMAGEDENOISE'
    except Exception: pass
    c.max_bounces = 10; c.glossy_bounces = 6; c.transparent_max_bounces = 8
    try:
        scn.view_settings.view_transform = 'AgX'; scn.view_settings.look = 'AgX - Medium High Contrast'
    except Exception: pass
    scn.view_settings.exposure = 0.0
    scn.render.image_settings.file_format = 'PNG'; scn.render.image_settings.color_depth = '16'
    scn.render.filepath = A.out

def as_catcher(obs):
    for o in obs: o.is_shadow_catcher = True

if A.scene == 'desktop':
    build_desktop()
    bake_wear(links)
    studio(7.0, -2.155)
    camera(7.0, -2.155, 14.0, 1400 * A.scale, 431 * A.scale)
    render_setup()
    if A.mode == 'sample':
        add_carriage(MARKS[A.stage], A.stage)
        for ob in plate_parts[A.stage]: ob.location.z -= 1.6 * S
        flag = [o for o in plate_parts[A.stage] if o.name.startswith('flag')][0]
        flag.data.materials[0] = M['champagne']; flag.location.z += 1.0 * S
    elif A.mode == 'base':
        pass
    elif A.mode in ('carriage', 'plate'):
        scn.render.film_transparent = True; scn.render.image_settings.color_mode = 'RGBA'
        everything = [o for o in scn.objects if o.type == 'MESH']
        if A.mode == 'carriage':
            mine = add_carriage(MARKS[A.stage], A.stage); keep = set(mine)
            x0, x1, y0, y1 = MARKS[A.stage] - 104, MARKS[A.stage] + 104, 196, 306
        else:
            mine = plate_parts[A.stage]
            for o in mine: o.location.z -= 1.6 * S
            flag = [o for o in mine if o.name.startswith('flag')][0]; flag.data.materials[0] = M['champagne']; flag.location.z += 1.0 * S
            keep = set(mine); x = PLX[A.stage]; x0, x1, y0, y1 = x - 8, x + PLATE_W + 8, PLATE_Y0 - 8, PLATE_Y1 + 10
        # Only the surfaces that receive the part's contact shadow stay as shadow catchers; every other object is
        # camera-invisible, so the sprite carries just the part plus its shadow on transparent film.
        catcher_names = ('frame', 'bore-floor', 'rail', 'rail-running-face', 'stand-off')
        for o in everything:
            if o in keep: continue
            if o.name.startswith(catcher_names): o.is_shadow_catcher = True
            else:
                o.visible_camera = False
                o.visible_shadow = False  # the base render already carries the chain's shadows
        scn.render.use_border = True; scn.render.use_crop_to_border = True
        scn.render.border_min_x = x0 / 1400; scn.render.border_max_x = x1 / 1400
        scn.render.border_min_y = 1 - y1 / 431; scn.render.border_max_y = 1 - y0 / 431
    bpy.ops.render.render(write_still=True)
