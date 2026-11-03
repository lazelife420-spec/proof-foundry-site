"""Round 2 UI hardware, Cycles: navigation key housings, key coupler, footer rail and panel recess.
blender -b --factory-startup -P ui_parts.py -- --part key-rest|key-current|coupler|coupler-v|footer-rail|footer-panel --scale 2 --samples N --out x.png
Same studio, materials and units as the chain scene (1 CSS px = 0.01 m). Key and panel art is sliced in CSS with
border-image, so everything that must not stretch (ears, screws, markers, corners) sits inside the fixed end slices.
"""
import bpy, sys, math, runpy, os
from mathutils import Matrix, Vector
here = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index('--') + 1:]
part = argv[argv.index('--part') + 1]; argv2 = [a for i, a in enumerate(argv) if a != '--part' and (i == 0 or argv[i - 1] != '--part')]
sys.argv = [sys.argv[0], '--', '--scene', 'none'] + argv2
g = runpy.run_path(os.path.join(here, 'chain_scene.py'))
A, S, M, P, scn = g['A'], g['S'], g['M'], g['P'], g['scn']
box, cyl, boolean, cap_screw, link_obj, sunk_screw = g['box'], g['cyl'], g['boolean'], g['cap_screw'], g['link_obj'], g['sunk_screw']
inp = g['inp']
M['cap'] = g['mat_varied']('satin-cap', (0.055, 0.058, 0.062), 0.85, 0.34, var=0.08, rvar=0.03, scale=6)
# Bead-blasted stainless for the seated cap: partly diffuse so it reads light under the black studio world.
M['satin-ss'] = g['mat_varied']('bead-blasted-stainless', (0.56, 0.56, 0.55), 0.55, 0.42, var=0.04, rvar=0.03, scale=8)
M['blackened'] = g['mat_varied']('blackened-housing', (0.032, 0.033, 0.035), 0.85, 0.42, var=0.15, rvar=0.05, scale=3)

def finish(Wpx, Hpx, transparent=False, k=0.35):
    g['studio'](Wpx / 2 * S, -Hpx / 2 * S, k)
    for n in ('cavity-wash',):
        if n in bpy.data.objects: bpy.data.objects[n].data.energy = 0
    g['camera'](Wpx / 2 * S, -Hpx / 2 * S, Wpx * S, Wpx * A.scale, Hpx * A.scale)
    g['render_setup']()
    if transparent: scn.render.film_transparent = True; scn.render.image_settings.color_mode = 'RGBA'
    bpy.ops.render.render(write_still=True)

if part.startswith('key'):
    # 200 x 64 canvas. Ears 0..20 and 180..200, housing 12..188, recessed control face 22..178.
    W, H = 200, 64; cur = part == 'key-current'
    hs = box('housing', 12, 6, -10, 188, 58, 6, 'blackened', bevel=3, seg=2)
    boolean(hs, box('recess', 22, 13, 0, 178, 51, 20, 'blackened', bevel=0))
    for x0, x1, hx in ((0, 22, 8.5), (178, 200, 191.5)):
        ear = box('ear', x0, 22, -8, x1, 42, 1.5, 'blackened', bevel=2, seg=2)
        boolean(ear, cyl('ear-bore', hx, 32, -20, 10, 4.2, 'pin', bevel=0))
    z0, z1 = (-3.5, 2.2) if cur else (-2, 4.2)
    cap = box('cap', 24, 15, z0, 176, 49, z1, 'satin-ss' if cur else 'cap', bevel=1.6, seg=2)
    for x, y in ((17, 12), (183, 52)): cap_screw('retainer', x, y, 6, 2.4)
    if cur:
        # Seated state: the cap drops onto its stop and a fine champagne witness line marks it, inside the left slice.
        box('marker', 29, 21, z1 - 0.4, 31.2, 43, z1 + 0.3, 'champagne', bevel=0.3)
    box('backer', -20, -20, -40, 220, 84, -39, 'bore', bevel=0).visible_camera = False
    finish(W, H, transparent=True)
elif part == 'coupler':
    # A short forged link pinned through the ears of two neighbouring keys: pin centres 46 px apart.
    W, H = 70, 32
    lk = link_obj('coupler', 35, 16, 0, -0.08, 13.0, 7.5, 3.2); lk.modifiers['forge'].strength = 0.004
    for x in (12, 58): cyl('ear-pin', x, 16, -6, 6.5, 3.2, 'pin', bevel=0.6); cyl('pin-head', x, 16, 5.5, 7.5, 4.6, 'pin', bevel=0.8)
    finish(W, H, transparent=True, k=0.25)
elif part == 'coupler-v':
    # Drop link for the snaking key layouts (below 1240 px): two forged links hang between the side ears of two
    # stacked keys. Rendered upright under the same studio so it is never rotated in CSS. Drawn at its CSS size
    # (56 px keys, 24 px row gap): ear bores 80 px apart, at y 10 and 90 of a 32 x 100 canvas. The wire and pins match
    # the horizontal coupler as it is drawn at that layout (0.758 of its art).
    W, H = 32, 100
    k = 0.758; r = 3.2 * k; R = 7.5 * k
    # Each link's outer bow rests on its pin as in the horizontal coupler (pin 0.7 px inside the outer edge); the two
    # links thread at mid-height, so centre-to-centre equals the inner length: 80 + 1.4 = 4 * (a + R).
    L = (80 + 1.4) / 4; a = L - R
    top = 10 + L + r - 0.7; bot = 90 - L - r + 0.7
    upper = link_obj('drop-upper', 16, top, math.pi / 2, -0.08, a, R, r); upper.modifiers['forge'].strength = 0.004
    lower = link_obj('drop-lower', 16, bot, math.pi / 2, math.pi / 2 - 0.2, a, R, r); lower.modifiers['forge'].strength = 0.004
    for y in (10, 90): cyl('ear-pin', 16, y, -6, 6.5, 3.2 * k, 'pin', bevel=0.6); cyl('pin-head', 16, y, 5.5, 7.5, 4.6 * k, 'pin', bevel=0.8)
    finish(W, H, transparent=True, k=0.25)
elif part == 'footer-rail':
    # Upper rail of the footer base: one restrained 22 px blackened bar, 1920 px long, rendered whole (no tile seams) and
    # centred in CSS. Its top edge tucks under the butt weld that joins the base to the chassis, and eight socket screws
    # at 240 px pitch, symmetric about the page centre, fasten it into the base below. Shadow only, on a transparent film.
    W, H = 1920, 64
    M['rail-steel'] = g['mat_simple']('rail-blackened-steel', (0.045, 0.047, 0.05), 0.9, 0.36, brushed=0.12)
    bar = box('rail', 6, 3, -2, 1914, 25, 4, 'rail-steel', bevel=2.2, seg=2)
    for d in (-840, -600, -360, -120, 120, 360, 600, 840): sunk_screw(bar, 'rail-screw', 960 + d, 14, 4, 4.0)
    g['as_catcher']([box('base', -20, -20, -3.6, 1940, 90, -2.6, 'bore', bevel=0)])
    finish(W, H, transparent=True, k=1.0)
elif part == 'weld-seam':
    # The butt weld that joins the footer base to the chassis, under the CSS strip's fade. Real bead geometry, rendered
    # whole at 2560 px so it does not repeat on screens up to 2560 px wide: a convex cap with crescent ripples at an
    # irregular pitch, laid in runs (first stop 80-300 px in, then 260-520 px, the last one ending at W; with seed 1183:
    # 118, then 281-403 px); each run ends in a dished crater and the next restarts proud over it.
    # Fine spatter either side, a narrow heat tint on the plates, dark slag at the toes. Seeded, so reproducible.
    import numpy as np
    W, H = 2560, 42
    rng = np.random.default_rng(1183)
    def vnoise(t, seed, oct=3):
        out = np.zeros_like(t); amp = 1.0; tot = 0.0
        for o in range(oct):
            r = np.random.default_rng(seed + 97 * o); tt = t * (2 ** o)
            lat = r.uniform(-1, 1, int(tt.max()) + 3); i = np.floor(tt).astype(int); f = tt - i; f = f * f * (3 - 2 * f)
            out += amp * (lat[i] * (1 - f) + lat[i + 1] * f); tot += amp; amp *= 0.5
        return out / tot
    def vnoise2(x, y, seed, scale, oct=3):
        # 2D value noise (bilinear on a random lattice, smoothstepped), so surface texture has no direction.
        out = np.zeros_like(x); amp = 1.0; tot = 0.0
        for o in range(oct):
            r = np.random.default_rng(seed + 131 * o); gx = x / scale * (2 ** o); gy = y / scale * (2 ** o)
            lat = r.uniform(-1, 1, (int(gy.max()) + 3, int(gx.max()) + 3))
            ix = np.floor(gx).astype(int); iy = np.floor(gy).astype(int); fx = gx - ix; fy = gy - iy
            fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
            top = lat[iy, ix] * (1 - fx) + lat[iy, ix + 1] * fx; bot = lat[iy + 1, ix] * (1 - fx) + lat[iy + 1, ix + 1] * fx
            out += amp * (top * (1 - fy) + bot * fy); tot += amp; amp *= 0.5
        return out / tot
    # Grid: 0.25 px along the seam; rows dense across the bead and coarse on the plates.
    xs = np.arange(0, W + 0.001, 0.25)
    ys = np.unique(np.concatenate([np.arange(0, 9, 1.0), np.arange(9, 33.01, 0.25), np.arange(34, H + 0.01, 1.0)]))
    X, Y = np.meshgrid(xs, ys)
    # Both ends meet the same bead: a crater at x = W and a restart at x = 0, so a screen wider than 2560 px sees the
    # wrap as one more stop and restart rather than a cut.
    edge = np.clip(np.minimum(xs, W - xs) / 40.0, 0, 1); edge = edge * edge * (3 - 2 * edge)
    yc = 21 + edge * 0.9 * vnoise(xs / 170 + 2, 11)             # the bead wanders slightly
    hw0 = 9.0 + edge * 1.5 * vnoise(xs / 55 + 5, 12)            # half-width 7.5-10.5 px
    hcap = 3.6 + edge * 0.5 * vnoise(xs / 80 + 9, 13)           # crown height
    # First stop 80-300 px in, then runs of 260-520 px; the last one stops exactly at W and the first restarts at 0.
    # Each restart overlaps the previous crater by 3 px.
    ends, x = [], rng.uniform(80, 300)
    while x < W - 200: ends.append(x); x += rng.uniform(260, 520)
    ends.append(float(W))
    run = np.searchsorted(np.array(ends), xs - 3.0)            # which run lays each column
    # Ripple pitch about 6.4 px with roughly 20% scatter from ripple to ripple.
    spacing = 6.4 * (1 + 0.14 * vnoise(xs / 45 + 7, 14) + 0.1 * vnoise(xs / 6 + 4, 16, 1))
    phase = np.cumsum(0.25 / spacing)
    starts = np.concatenate([[0.0], np.array(ends) - 3.0])
    offs = rng.uniform(0, 1, len(starts) + 1)
    s_idx = np.searchsorted(xs, starts)
    phase = phase - phase[np.minimum(s_idx[run], len(xs) - 1)] + offs[run]   # each run starts its own ripple train
    # Ripple fronts are round at the crown and sweep back only near the toes, so their arms never join into strands.
    front = lambda u, h: 0.45 * h * (1 - np.sqrt(np.clip(1 - u ** 2, 0, 1)))
    # Every puddle freezes a little wider at the toe, so the toe line scallops with the ripples.
    ph_toe = np.interp(xs - 0.45 * hw0, xs, phase); ft = ph_toe - np.floor(ph_toe)
    hw = hw0 + edge * (0.6 * (0.5 + 0.5 * np.cos(2 * np.pi * ft)) - 0.3)
    U = (Y - yc[None, :]) / hw[None, :]
    inside = np.clip(1 - U ** 2, 0, None)
    ph = np.interp(X - front(U, hw[None, :]), xs, phase)
    f = ph - np.floor(ph)
    # Gentle rise, then the frozen edge; the fall is spread over the last 14% so no grid step carries all of it.
    t = np.clip((f - 0.86) / 0.14, 0, 1)
    rip = f ** 2.4 * (1 - t * t * (3 - 2 * t)) - 0.27
    # Craters about half a bead wide, dished, just before each stop; the restart sits proud for about a bead width.
    crater = np.zeros_like(xs); proud = np.zeros_like(xs)
    for e in ends:
        d = (xs - e + W / 2) % W - W / 2                      # periodic: the image repeats past 2560 px
        crater += np.exp(-((d + 4.0) / 7.0) ** 2)
        proud += np.exp(-((d - 9.0) / 9.0) ** 2)
    tt = np.clip((np.abs(U) - 0.55) / 0.45, 0, 1); tt = tt * tt * (3 - 2 * tt)
    profile = inside ** 0.55 * (1 - tt) + inside ** 1.6 * tt
    Z = hcap[None, :] * (1 + 0.35 * proud[None, :] - 0.5 * crater[None, :]) * profile
    # Ripple depth wanders with the welder's hand, and each ripple differs from its neighbours.
    ramp_amp = 1.4 * (0.95 + edge * (0.3 * vnoise(xs / 14 + 6, 17) + 0.35 * vnoise(xs / 5.5 + 2, 18, 1)))[None, :]
    Z += ramp_amp * (1 - 0.5 * U ** 2) * rip * (inside > 0)
    Z -= 1.4 * crater[None, :] * np.exp(-(U / 0.5) ** 2)       # the crater's dish, about a third of the crown
    # Weld-metal surface: fine roughness and a few porosity pits on the bead; the plates stay nearly flat.
    Z += (inside > 0) * 0.14 * vnoise2(X, Y, 19, 1.5)
    for px_, py_, pr in zip(rng.uniform(0, W, 40), rng.uniform(-0.6, 0.6, 40), rng.uniform(0.35, 0.8, 40)):
        xi = min(int(px_ / 0.25), len(xs) - 1)
        Z -= 0.45 * np.exp(-(((X - px_) ** 2 + (Y - yc[xi] - py_ * hw[xi]) ** 2) / pr ** 2))
    Z = np.where(inside > 0, np.maximum(Z, 0), 0) + 0.03 * vnoise2(X, Y, 15, 8.0, 2)
    # One quad grid straight from the arrays: row-major over (ys, xs), faces wound to look at the camera (+Z).
    ny, nx = Y.shape
    co = np.stack([X * S, -Y * S, Z * S], axis=-1)
    me = bpy.data.meshes.new('weld-seam'); me.vertices.add(ny * nx); me.vertices.foreach_set('co', co.ravel())
    idx = np.arange(ny * nx).reshape(ny, nx)
    q = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], axis=-1).reshape(-1, 4)
    me.loops.add(q.size); me.loops.foreach_set('vertex_index', q.ravel())
    me.polygons.add(len(q)); me.polygons.foreach_set('loop_start', np.arange(0, q.size, 4))
    me.update(calc_edges=True)
    me.polygons.foreach_set('use_smooth', np.ones(len(q), dtype=bool))
    seam = bpy.data.objects.new('weld-seam', me); scn.collection.objects.link(seam)
    def pattr(name, vals):
        a = me.attributes.new(name, 'FLOAT', 'POINT'); a.data.foreach_set('value', np.asarray(vals, dtype=np.float32).ravel())
    tdist = np.abs(Y - yc[None, :]) - hw[None, :]                 # px from the toe, negative on the bead
    pattr('bead', np.clip(inside * 2.2, 0, 1))
    pattr('valley', np.where(inside > 0, 1 - f ** 2.4, 0))
    hz_w = (8.0 + edge * 3.5 * vnoise(xs / 70 + 3, 21) + 4.0 * np.clip(crater + proud, 0, 1))[None, :]
    hz_w = np.where(Y > yc[None, :], np.minimum(hz_w, 2.5), hz_w)
    pattr('haz', np.clip(1 - np.maximum(tdist, 0) / hz_w, 0, 1))
    pattr('toe', np.exp(-(tdist / 0.6) ** 2))
    # Materials: weld metal a little brighter than the plates, oxide in the ripple valleys, a few dark silica islands, slag at
    # the toes; plates are mill steel with a narrow straw-to-blue heat tint that fades within 9 px of the toe.
    m, nt, b = g['node_mat']('weld'); N = nt.nodes; Lk = nt.links.new
    def at(n):
        a = N.new('ShaderNodeAttribute'); a.attribute_name = n; a.attribute_type = 'GEOMETRY'; return a.outputs['Fac']
    tc = N.new('ShaderNodeTexCoord')
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 7; nz.inputs['Detail'].default_value = 8; Lk(tc.outputs['Object'], nz.inputs[0])
    isl = N.new('ShaderNodeTexVoronoi'); isl.inputs['Scale'].default_value = 11; Lk(tc.outputs['Object'], isl.inputs[0])
    plate = N.new('ShaderNodeValToRGB'); pe = plate.color_ramp.elements
    pe[0].color = (0.022, 0.022, 0.021, 1); pe[1].color = (0.043, 0.042, 0.04, 1); Lk(nz.outputs['Fac'], plate.inputs['Fac'])
    tint = N.new('ShaderNodeValToRGB'); te = tint.color_ramp.elements
    # Temper order on carbon steel, coolest to hottest: faint straw far out, then purple-blue, then dark blue-grey
    # oxide at the toe.
    te[0].position = 0.0; te[0].color = (0.035, 0.035, 0.033, 1); te[1].position = 1.0; te[1].color = (0.026, 0.03, 0.045, 1)
    for pos, c in ((0.3, (0.13, 0.085, 0.04)), (0.55, (0.075, 0.045, 0.07)), (0.75, (0.05, 0.062, 0.11))):
        tint.color_ramp.elements.new(pos).color = (*c, 1)
    Lk(at('haz'), tint.inputs['Fac'])
    hazmix = N.new('ShaderNodeMix'); hazmix.data_type = 'RGBA'; Lk(plate.outputs['Color'], hazmix.inputs[6]); Lk(tint.outputs['Color'], hazmix.inputs[7])
    hz = N.new('ShaderNodeMath'); hz.operation = 'MULTIPLY'; hz.inputs[1].default_value = 0.75; Lk(at('haz'), hz.inputs[0]); Lk(hz.outputs[0], hazmix.inputs['Factor'])
    metal = N.new('ShaderNodeMix'); metal.data_type = 'RGBA'; Lk(at('valley'), metal.inputs['Factor'])
    metal.inputs[6].default_value = (0.05, 0.049, 0.047, 1); metal.inputs[7].default_value = (0.007, 0.0068, 0.0065, 1)
    sil = N.new('ShaderNodeMapRange'); sil.inputs['From Min'].default_value = 0.965; sil.inputs['From Max'].default_value = 0.975
    sep = N.new('ShaderNodeSeparateColor'); Lk(isl.outputs['Color'], sep.inputs[0]); Lk(sep.outputs[0], sil.inputs['Value'])
    beadcol = N.new('ShaderNodeMix'); beadcol.data_type = 'RGBA'; Lk(sil.outputs[0], beadcol.inputs['Factor'])
    Lk(metal.outputs[2], beadcol.inputs[6]); beadcol.inputs[7].default_value = (0.022, 0.015, 0.01, 1)
    # Sparse light-brown oxide in the ripple valleys and along the upper toe, the chain's iron-oxide palette.
    oxn = N.new('ShaderNodeTexNoise'); oxn.inputs['Scale'].default_value = 9; oxn.inputs['Detail'].default_value = 5; Lk(tc.outputs['Object'], oxn.inputs[0])
    oxm = N.new('ShaderNodeMapRange'); oxm.inputs['From Min'].default_value = 0.56; oxm.inputs['From Max'].default_value = 0.66; Lk(oxn.outputs['Fac'], oxm.inputs['Value'])
    oxv = N.new('ShaderNodeMath'); oxv.operation = 'MULTIPLY'; Lk(oxm.outputs[0], oxv.inputs[0]); Lk(at('valley'), oxv.inputs[1])
    oxc = N.new('ShaderNodeMix'); oxc.data_type = 'RGBA'; Lk(oxv.outputs[0], oxc.inputs['Factor'])
    Lk(beadcol.outputs[2], oxc.inputs[6]); oxc.inputs[7].default_value = (0.055, 0.026, 0.01, 1)
    col = N.new('ShaderNodeMix'); col.data_type = 'RGBA'; Lk(at('bead'), col.inputs['Factor'])
    Lk(hazmix.outputs[2], col.inputs[6]); Lk(oxc.outputs[2], col.inputs[7])
    # A faint heat tint on the bead itself, so the crown is not one grey.
    btn = N.new('ShaderNodeTexNoise'); btn.inputs['Scale'].default_value = 5.5; btn.inputs['Detail'].default_value = 4; Lk(tc.outputs['Object'], btn.inputs[0])
    btr = N.new('ShaderNodeValToRGB'); be = btr.color_ramp.elements
    be[0].position = 0.35; be[0].color = (0.05, 0.055, 0.075, 1); be[1].position = 0.65; be[1].color = (0.1, 0.085, 0.06, 1)
    Lk(btn.outputs['Fac'], btr.inputs['Fac'])
    btm = N.new('ShaderNodeMix'); btm.data_type = 'RGBA'; btm.inputs['Factor'].default_value = 0.5
    Lk(col.outputs[2], btm.inputs[6]); Lk(btr.outputs['Color'], btm.inputs[7])
    beadmask = N.new('ShaderNodeMix'); beadmask.data_type = 'RGBA'; Lk(at('bead'), beadmask.inputs['Factor'])
    Lk(col.outputs[2], beadmask.inputs[6]); Lk(btm.outputs[2], beadmask.inputs[7])
    tf = N.new('ShaderNodeMath'); tf.operation = 'MULTIPLY'; tf.inputs[1].default_value = 0.6; Lk(at('toe'), tf.inputs[0])
    slag = N.new('ShaderNodeMix'); slag.data_type = 'RGBA'; Lk(tf.outputs[0], slag.inputs['Factor'])
    Lk(beadmask.outputs[2], slag.inputs[6]); slag.inputs[7].default_value = (0.03, 0.027, 0.024, 1); Lk(slag.outputs[2], inp(b, 'Base Color'))
    rgh = N.new('ShaderNodeMapRange'); Lk(at('valley'), rgh.inputs['Value'])
    rgh.inputs['To Min'].default_value = 0.5; rgh.inputs['To Max'].default_value = 0.75; Lk(rgh.outputs[0], inp(b, 'Roughness'))
    inp(b, 'Metallic').default_value = 0.92
    fine = N.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value = 160; fine.inputs['Detail'].default_value = 6; Lk(tc.outputs['Object'], fine.inputs[0])
    bmp = N.new('ShaderNodeBump'); bmp.inputs['Strength'].default_value = 0.12; bmp.inputs['Distance'].default_value = 0.0015
    Lk(fine.outputs['Fac'], bmp.inputs['Height']); Lk(bmp.outputs[0], inp(b, 'Normal'))
    me.materials.append(m)
    # Spatter: fine balls fused to the plates near the bead, more on the downhand side.
    M['spatter'] = g['mat_simple']('spatter', (0.03, 0.022, 0.016), 0.6, 0.75)
    sx = np.sort(rng.uniform(0, W, 50)); side = np.where(rng.uniform(0, 1, 50) < 0.62, -1, 1)   # more on the upper side
    for i, x in enumerate(sx):
        xi = min(int(x / 0.25), len(xs) - 1)
        y = yc[xi] + side[i] * (hw[xi] + 2.0 + rng.uniform(0, 8.0)); r = rng.uniform(0.6, 1.2)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r * S, segments=12, ring_count=6, location=P(x, y, r * 0.25))
        sp = bpy.context.active_object; sp.scale = (rng.uniform(0.8, 1.3), rng.uniform(0.8, 1.3), 0.35); sp.data.materials.append(M['spatter'])
    # Lighting for a long strip: one long key raking from the upper side (the site's light is upper left), a dim cool
    # fill from below, black world. The studio's single central softbox would light 2560 px unevenly.
    cx, cy = W / 2 * S, -H / 2 * S
    # Strips turned about X only, so each runs the full length of the seam (a tracked light would turn diagonal).
    def strip(name, dy, dz, size_y, power, color):
        ld = bpy.data.lights.new(name, 'AREA'); ld.shape = 'RECTANGLE'; ld.size = W * S * 1.4; ld.size_y = size_y
        ld.energy = power; ld.color = color
        ob = bpy.data.objects.new(name, ld); scn.collection.objects.link(ob)
        ob.location = (cx, cy + dy, dz); ob.rotation_euler = (-math.atan2(dy, dz), 0, 0)
    strip('weld-key', 2.6, 1.4, 0.8, 2600, (1.0, 0.95, 0.88))
    sun = bpy.data.lights.new('weld-sun', 'SUN'); sun.energy = 4.0; sun.angle = math.radians(8); sun.color = (1.0, 0.95, 0.88)
    so = bpy.data.objects.new('weld-sun', sun); scn.collection.objects.link(so)
    so.rotation_euler = Vector((0.82, -0.28, -0.42)).to_track_quat('-Z', 'Y').to_euler()   # from the upper left, raking across the ripples
    strip('weld-fill', -2.6, 1.6, 0.5, 700, (0.88, 0.94, 1.0))
    wd = bpy.data.worlds.new('black'); wd.use_nodes = True
    wd.node_tree.nodes['Background'].inputs[0].default_value = (0.002, 0.002, 0.0022, 1); scn.world = wd
    g['camera'](cx, cy, W * S, W * A.scale, H * A.scale)
    g['render_setup']()
    bpy.ops.render.render(write_still=True)
elif part == 'footer-panel':
    # Recessed link panel: 240 x 180, corners and screws in 28 px slices; the floor between stretches.
    W, H = 240, 180
    plate = box('plate', -10, -10, -20, 250, 190, 8, 'blackened', bevel=0)
    boolean(plate, box('pocket', 14, 14, 2, 226, 166, 30, 'blackened', bevel=0))
    box('pocket-floor', 14, 14, 1.4, 226, 166, 2.2, 'cap', bevel=0)
    for x, y in ((7, 7), (233, 7), (7, 173), (233, 173)): sunk_screw(plate, 'panel-screw', x, y, 8, 3.2)
    finish(W, H)
