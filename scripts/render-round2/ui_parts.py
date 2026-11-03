"""Round 2 UI hardware, Cycles: navigation key housings, key coupler, footer rail and panel recess.
blender -b --factory-startup -P ui_parts.py -- --part key-rest|key-current|coupler|coupler-v|footer-rail|footer-panel --scale 2 --samples N --out x.png
Same studio, materials and units as the chain scene (1 CSS px = 0.01 m). Key and panel art is sliced in CSS with
border-image, so everything that must not stretch (ears, screws, markers, corners) sits inside the fixed end slices.
"""
import bpy, sys, math, runpy, os
from mathutils import Matrix
here = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index('--') + 1:]
part = argv[argv.index('--part') + 1]; argv2 = [a for i, a in enumerate(argv) if a != '--part' and (i == 0 or argv[i - 1] != '--part')]
sys.argv = [sys.argv[0], '--', '--scene', 'none'] + argv2
g = runpy.run_path(os.path.join(here, 'chain_scene.py'))
A, S, M, P, scn = g['A'], g['S'], g['M'], g['P'], g['scn']
box, cyl, boolean, cap_screw, link_obj, sunk_screw = g['box'], g['cyl'], g['boolean'], g['cap_screw'], g['link_obj'], g['sunk_screw']
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
    # Drop link for the snaking key layouts (1100 px and below): two forged links hang between the side ears of two
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
elif part == 'footer-panel':
    # Recessed link panel: 240 x 180, corners and screws in 28 px slices; the floor between stretches.
    W, H = 240, 180
    plate = box('plate', -10, -10, -20, 250, 190, 8, 'blackened', bevel=0)
    boolean(plate, box('pocket', 14, 14, 2, 226, 166, 30, 'blackened', bevel=0))
    box('pocket-floor', 14, 14, 1.4, 226, 166, 2.2, 'cap', bevel=0)
    for x, y in ((7, 7), (233, 7), (7, 173), (233, 173)): sunk_screw(plate, 'panel-screw', x, y, 8, 3.2)
    finish(W, H)
