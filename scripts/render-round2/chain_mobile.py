"""Proof chain, mobile (160 x 635 px vertical frame), Cycles. Reuses the desktop scene's materials and helpers.
blender -b --factory-startup -P chain_mobile.py -- --scene mobile --mode base|sample|carriage --stage N --scale 2 --samples N --out x.png
The chain hangs vertically in tension (no sag). Parts are the desktop parts scaled by the pitch ratio K.
A vertical V-way runs beside the chain; the carriage pointer reaches left to each checkpoint link with a fixed clearance.
"""
import bpy, sys, math, runpy, os
from mathutils import Matrix, Vector
here = os.path.dirname(os.path.abspath(__file__))
g = runpy.run_path(os.path.join(here, 'chain_scene.py'))   # parses the same argv; --scene mobile is a no-op there
A, S, M, P = g['A'], g['S'], g['M'], g['P']
box, cyl, boolean, cap_screw, link_obj, tapered_finger = g['box'], g['cyl'], g['boolean'], g['cap_screw'], g['link_obj'], g['tapered_finger']
sunk_screw, links, catchers, scn = g['sunk_screw'], g['links'], g['catchers'], g['scn']

W, H = 160, 635
K = 95.08 / 208.6
X = 64.0
CY = [110.3, 205.4, 300.5, 395.5, 490.6]
LR, Lr, La = 42 * K, 20 * K, 37.5 * K
RAIL_X = 126.0

def rot_about(objs, x, y, ang):
    piv = P(x, y); R = Matrix.Translation(piv) @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Translation(-piv)
    for ob in objs: ob.matrix_world = R @ ob.matrix_basis

def build_mobile():
    for i in range(5):
        links.append(link_obj(f'check-{i+1}', X, CY[i], math.pi / 2, -0.1, La, LR, Lr))
        if i < 4: links.append(link_obj(f'connect-{i+1}', X, (CY[i] + CY[i + 1]) / 2, math.pi / 2, math.pi / 2 - 0.2, La, LR, Lr))
    frame = box('frame', 0, 0, -50, W, H, 24, 'housing', bevel=3, seg=3)
    boolean(frame, box('step-cut', 10, 14, 19, W - 10, 596, 40, 'housing', bevel=0))
    boolean(frame, box('bore-cut', 16, 20, -34, W - 16, 590, 40, 'housing', bevel=0))
    floor = box('bore-floor', 16.5, 20.5, -33.9, W - 16.5, 589.5, -33.6, 'bore', bevel=0)
    catchers.extend([frame, floor])
    for (x, y) in [(6, 6), (W - 6, 6), (6, 616), (W - 6, 616)]: catchers.append(sunk_screw(frame, 'frame-screw', x, y, 24, 3.2))
    # End blocks above and below the chain; the clevis assemblies are built along +X at their pins, then turned upright.
    for side, (y0, y1) in ((-1, (24, 58)), (1, (545, 584))):
        blk = box('end-block', X - 36, y0, -34, X + 36, y1, 12, 'housing', bevel=4, seg=4); catchers.append(blk)
        for xx in (X - 24, X + 24): catchers.append(sunk_screw(blk, 'block-screw', xx, (y0 + y1) / 2 + side * -3, 12, 3.6))
        face = y1 if side < 0 else y0
        lc = 0 if side < 0 else 4
        py_axial = CY[lc] + side * 48.0 * K          # pin position along the chain axis
        # Build horizontally: axial coordinate -> x, centred on the real pin so the turn is about the pin.
        px, py = X, py_axial
        ax = lambda a: px + (a - py_axial)            # map an axial (image-y) value to horizontal x
        grp = []
        f = ax(face); yoke = f - side * 46 * K
        x0, x1 = sorted((yoke, px))
        for zc in (-34 * K, 34 * K):
            grp.append(box('clevis-cheek', x0, py - 26 * K, zc - 7 * K, x1, py + 26 * K, zc + 7 * K, 'clevis', bevel=1.4))
            grp.append(cyl('clevis-eye', px, py, zc - 7 * K, zc + 7 * K, 26 * K, 'clevis', bevel=1.4))
        grp.append(box('clevis-yoke', yoke - 16 * K, py - 30 * K, -42 * K, yoke + 16 * K, py + 30 * K, 42 * K, 'clevis', bevel=2.3))
        rx0, rx1 = sorted((f + side * 9, yoke))
        rod = cyl('tension-rod', 0, 0, rx0, rx1, 12 * K, 'pin', axis='X'); rod.location = P((rx0 + rx1) / 2, py, 0); grp.append(rod)
        nx = yoke + side * 23 * K
        nut = cyl('tension-nut', 0, 0, nx - 7 * K, nx + 7 * K, 19 * K, 'screw', axis='X', verts=6); nut.location = P(nx, py, 0); grp.append(nut)
        seat = cyl('rod-seat', 0, 0, f - side * 3.2, f + side * 1, 21 * K, 'pin', bevel=1.8, axis='X'); seat.location = P(f - side * 1.1, py, 0); grp.append(seat)
        grp.append(cyl('clevis-pin', px, py, -46 * K, 46 * K, 11.5 * K, 'pin', bevel=0.3))
        grp.append(cyl('pin-head', px, py, 41 * K, 47 * K, 18 * K, 'pin', bevel=0.7))
        grp.append(cyl('pin-collar', px, py, -47 * K, -41 * K, 16 * K, 'pin', bevel=0.5))
        rot_about(grp, px, py, -math.pi / 2)
        catchers.append(seat)
    # Vertical V-way beside the chain, five engraved registration marks at the checkpoint links.
    rail = box('rail', RAIL_X - 4.6, 70, -14, RAIL_X + 4.6, 530, 2, 'rail', bevel=3, seg=1)
    run = box('rail-running-face', RAIL_X - 5.2, 70.5, -11, RAIL_X - 3.6, 529.5, 0.5, 'ground', bevel=0.2)
    for y in (70, 530):
        so = box('stand-off', RAIL_X - 7, y - 7, -34, RAIL_X + 7, y + 7, -12, 'housing', bevel=1.4); catchers.append(so)
        catchers.append(cap_screw('stand-off-screw', RAIL_X, y, 2, 2.6))
    for i, y in enumerate(CY):
        boolean(rail, box(f'mark-{i}', RAIL_X - 2, y - 0.6, 0.6, RAIL_X + 6, y + 0.6, 6, 'rail', bevel=0))
    catchers.extend([rail, run])

def link_right(i, y, half=6):
    o = bpy.data.objects[f'check-{i+1}']; dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg); me = ev.to_mesh()
    xs = [(o.matrix_world @ v.co).x / S for v in me.vertices if abs(-(o.matrix_world @ v.co).y / S - y) < half]
    ev.to_mesh_clear(); return max(xs)

def add_carriage_mobile(stage):
    y = CY[stage]; x = RAIL_X; parts = []
    parts.append(box('carriage-body', x - 11, y - 24, -3, x + 14, y + 24, 15, 'stainless', bevel=2.8, seg=1))
    parts.append(box('carriage-saddle', x - 9, y - 20, -12, x + 11, y + 20, -3, 'stainless', bevel=1))
    for sy in (-1, 1):
        parts.append(box('wiper', x - 7, y + sy * 24 - (3 if sy < 0 else 0), -10, x + 7, y + sy * 24 + (3 if sy > 0 else 0), 10, 'rail', bevel=0.7))
    parts.append(box('gib', x + 7, y - 20, 15, x + 10, y + 20, 16.2, 'rail', bevel=0.4))
    tip = link_right(stage, y) + 6.0
    parts.append(box('finger-boss-lower', x - 9, y - 8, 15, x + 3, y + 8, 17, 'stainless', bevel=0.6))
    parts.append(box('finger-boss-upper', x - 10.5, y - 5, 17, x - 1, y + 5, 19, 'stainless', bevel=0.5))
    fing = tapered_finger('pointer-finger', x, y - (x - tip), y, 18.5, 7, 2.4, 2.4, 'stainless')
    rot_about([fing], x, y, math.pi / 2)
    parts.append(fing)
    for dy in (-16, 16): parts.append(cap_screw('carriage-screw', x + 3, y + dy, 15, 2.8))
    parts.append(box('detent-lever', x + 2, y + 5, 15, x + 6, y + 13, 17, 'rail', bevel=0.5))
    print('FINGER', stage, 'tip', round(tip, 1), 'visible', round(x - 11 - tip, 1))
    return parts

build_mobile()
g['bake_wear'](links)
g['studio'](0.8, -3.175, 0.55)
# Stretch the reflection card's falloff over the tall frame, or its ramp reads as a hard band across the sides.
bpy.data.objects['reflection-card'].scale.y *= 2.6
bpy.data.lights['key-softbox'].size_y *= 3.0
# The desktop bore wash sits at a fixed height that cuts across the tall mobile frame as a hard reflected edge.
bpy.data.lights['cavity-wash'].energy = 0
g['camera'](0.8, -3.175, 1.6, W * A.scale, H * A.scale)
g['render_setup']()
if A.mode == 'sample':
    add_carriage_mobile(A.stage)
elif A.mode == 'carriage':
    scn.render.film_transparent = True; scn.render.image_settings.color_mode = 'RGBA'
    everything = [o for o in scn.objects if o.type == 'MESH']
    keep = set(add_carriage_mobile(A.stage))
    for o in everything:
        if o in keep: continue
        if o.name.startswith(('frame', 'bore-floor', 'rail', 'rail-running-face', 'stand-off')): o.is_shadow_catcher = True
        else: o.visible_camera = False; o.visible_shadow = False
    x0, x1, y0, y1 = 92, 152, CY[A.stage] - 34, CY[A.stage] + 34
    scn.render.use_border = True; scn.render.use_crop_to_border = True
    scn.render.border_min_x = x0 / W; scn.render.border_max_x = x1 / W
    scn.render.border_min_y = 1 - y1 / H; scn.render.border_max_y = 1 - y0 / H
bpy.ops.render.render(write_still=True)
