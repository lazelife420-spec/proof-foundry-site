"""Round 3: the seven connection joints (brand/connections/<id>.svg) built and rendered as parts. Reproducible:
blender -b --factory-startup -P joint_parts.py -- --joint cache-vault --pass obj|shadow --frames 9 --scale 2 --samples 128
        --out DIR

The SVGs stay the authored designs; this script reads them, it does not redraw them:
- every filled shape becomes a part (a prism of its outline, edge-bevelled), stacked in document order: a part's
  bottom rests on the highest earlier part one of whose outlines' bounding boxes overlaps one of its own, so the
  painter's order of the SVG holds; an outline that crosses itself is split at the crossing into simple loops, all
  filled, as the drawing's nonzero fill shows them;
- its material comes from its fill: the six authored gradient families (graphite, satin, cut, brass, ceramic, glass)
  become blackened steel, brushed satin stainless, polished cut faces, brass, ceramic and glass; solid fills become a
  steel of their own tone; recesses and apertures are matte black voids;
- a gradient stroke on a filled shape (a polished edge, a brass ring) becomes a strip along the outline in that
  material; strokes on open paths (inlays, slots, the cracked seam) become strips of their width;
- the painted light goes: the joint-highlight strokes and the SVG drop shadow (the unused grain pattern in each
  drawing's defs never showed). Light and shadow
  come from ti_common.ti_studio() and, in the shadow pass, a soft contact light, as for every other part;
- the fasteners become pan-head screws with their slots.
Motion: foundry-connections.css moves seven groups on hover by translate, rotate and scale about each group's
fill-box centre. Rotating a rendered part in CSS would turn its light, so the motion is rendered: --frames frames at
even steps of engagement (frame k at k / (frames - 1)), each group moved in the scene exactly as the CSS moves it at
that engagement. The page steps a whole-number frame index through the strip with the CSS's own easing,
cubic-bezier(.2,.72,.16,1), so it moves as the drawing did both ways; frame 0 is the rest state.
Canvas: viewBox x -6..252, y -6..168 (the 240 x 160 design plus room for the contact shadow), --scale px per unit.
--pass obj: the parts under the full studio, the ground a holdout; --pass shadow: only the ground's contact shadow
(the parts cast it but are not seen; glass casts none). sprite_compose.py lays obj over shadow.
"""
import bpy, bmesh, math, sys, argparse, os, re
import xml.etree.ElementTree as ET
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument('--joint', required=True)
ap.add_argument('--svg-dir', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'brand', 'connections'))
ap.add_argument('--pass', dest='pass_', required=True, choices=('obj', 'shadow'))
ap.add_argument('--frames', type=int, default=9); ap.add_argument('--only-frame', type=int, default=-1)
ap.add_argument('--scale', type=float, default=2); ap.add_argument('--samples', type=int, default=128)
ap.add_argument('--out', required=True)
ap.add_argument('--dome', type=float, default=0.62); ap.add_argument('--sun', type=float, default=0.6)
ap.add_argument('--cone', type=float, default=8); ap.add_argument('--rim', type=float, default=1.4)
ap.add_argument('--band-lo', type=float, default=-4.0)
ap.add_argument('--contact-el', type=float, default=62); ap.add_argument('--contact-angle', type=float, default=18)
ap.add_argument('--contact-power', type=float, default=0.4)
A = ap.parse_args(argv)
bpy.ops.wm.read_factory_settings(use_empty=True)
import ti_common as T
from ti_common import S, P
scn = bpy.context.scene; T.scn = scn
X0, Y0, X1, Y1 = -6.0, -6.0, 252.0, 168.0
NS = '{http://www.w3.org/2000/svg}'

# ---------------- motion (foundry-connections.css) ----------------
def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
def m_t(tx, ty): return [[1, 0, tx], [0, 1, ty], [0, 0, 1]]
def m_r(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)   # y points down, so a positive angle turns clockwise, as CSS
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
def m_s(sx, sy): return [[sx, 0, 0], [0, sy, 0], [0, 0, 1]]
def about(m, cx, cy): return mat_mul(m_t(cx, cy), mat_mul(m, m_t(-cx, -cy)))
IDENT = m_t(0, 0)
# class -> the CSS transform at engagement e (applied about the element's fill-box centre)
MOTION = {
    'joint-carriage': lambda e: m_t(10 * e, 0),
    'joint-iris': lambda e: mat_mul(m_r(9 * e), m_s(1 - 0.035 * e, 1 - 0.035 * e)),
    'joint-collar': lambda e: m_r(-5 * e),
    'joint-counterweight': lambda e: m_t(-3 * e, 3 * e),
    'joint-scan-bridge': lambda e: m_t(0, 27 * e),
    'joint-sheet--back': lambda e: m_t(5 * e, -3 * e),
    'joint-sheet--middle': lambda e: m_t(1 * e, -1 * e),
    'joint-sheet--front': lambda e: m_t(-4 * e, 3 * e),
    'joint-lock--layer': lambda e: m_t(-4 * e, 0),
    'joint-diaphragm': lambda e: m_s(1 - 0.035 * e, 1 + 0.04 * e),
    'joint-seal-bar': lambda e: m_t(0, 0.75 * e),
}
def apply(m, pts): return [(m[0][0] * x + m[0][1] * y + m[0][2], m[1][0] * x + m[1][1] * y + m[1][2]) for x, y in pts]

# ---------------- SVG geometry ----------------
TOK = re.compile(r'[MmLlHhVvZzAaCcSsQqTt]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
def arc_pts(x0, y0, rx, ry, phi, large, sweep, x, y):
    """SVG endpoint arc to points (F.6.5 of the SVG spec); an arc to its own start point is omitted (F.6.2)."""
    if abs(x0 - x) < 1e-9 and abs(y0 - y) < 1e-9: return []
    if rx == 0 or ry == 0: return [(x, y)]
    rx, ry = abs(rx), abs(ry); ph = math.radians(phi); cp, sp = math.cos(ph), math.sin(ph)
    dx, dy = (x0 - x) / 2, (y0 - y) / 2; x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1: rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p; den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx, cy = cp * cxp - sp * cyp + (x0 + x) / 2, sp * cxp + cp * cyp + (y0 + y) / 2
    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0: dt -= 2 * math.pi
    elif sweep and dt < 0: dt += 2 * math.pi
    n = max(4, int(abs(dt) / math.radians(3)))
    out = []
    for i in range(1, n + 1):
        t = t1 + dt * i / n
        out.append((cx + rx * math.cos(t) * cp - ry * math.sin(t) * sp, cy + rx * math.cos(t) * sp + ry * math.sin(t) * cp))
    return out

def path_subpaths(d):
    """-> [(points, closed)] in user units."""
    toks = TOK.findall(d); i = 0; cmd = None; x = y = 0.0; sx = sy = 0.0; subs = []; cur = None
    def num():
        nonlocal i; v = float(toks[i]); i += 1; return v
    def flag():
        # arc flags are single digits and may run into the next number ("0110" is 0, 1, 10)
        nonlocal i; t = toks[i]
        if len(t) > 1 and t[0] in '01': toks[i] = t[1:]; return int(t[0])   # a flag is one character: "1.5" is 1, .5
        i += 1; return int(float(t))
    def start():
        nonlocal cur
        if cur is None: cur = [(x, y)]; subs.append([cur, False])   # a drawing command after z begins at the last start
    while i < len(toks):
        if re.match(r'[A-Za-z]', toks[i]): cmd = toks[i]; i += 1
        elif cmd in ('M', 'm'): cmd = 'L' if cmd == 'M' else 'l'   # extra pairs after a moveto are linetos
        c = cmd
        if c in 'Mm':
            nx, ny = num(), num()
            if c == 'm': nx, ny = x + nx, y + ny
            x, y = nx, ny; sx, sy = x, y; cur = [(x, y)]; subs.append([cur, False])
        elif c in 'Ll':
            start(); nx, ny = num(), num()
            if c == 'l': nx, ny = x + nx, y + ny
            x, y = nx, ny; cur.append((x, y))
        elif c in 'Hh':
            start(); nx = num(); x = x + nx if c == 'h' else nx; cur.append((x, y))
        elif c in 'Vv':
            start(); ny = num(); y = y + ny if c == 'v' else ny; cur.append((x, y))
        elif c in 'Aa':
            start(); rx, ry, phi = num(), num(), num(); la, sw = flag(), flag(); nx, ny = num(), num()
            if c == 'a': nx, ny = x + nx, y + ny
            cur.extend(arc_pts(x, y, rx, ry, phi, int(la), int(sw), nx, ny)); x, y = nx, ny
        elif c in 'Cc':
            start(); a1, b1, a2, b2, nx, ny = (num() for _ in range(6))
            if c == 'c': a1, b1, a2, b2, nx, ny = x + a1, y + b1, x + a2, y + b2, x + nx, y + ny
            for k in range(1, 17):
                t = k / 16; mt = 1 - t
                cur.append((mt ** 3 * x + 3 * mt * mt * t * a1 + 3 * mt * t * t * a2 + t ** 3 * nx,
                            mt ** 3 * y + 3 * mt * mt * t * b1 + 3 * mt * t * t * b2 + t ** 3 * ny))
            x, y = nx, ny
        elif c in 'Zz':
            subs[-1][1] = True; x, y = sx, sy
            cmd = None; cur = None
            if i < len(toks) and not re.match(r'[A-Za-z]', toks[i]): raise ValueError('numbers after z')
            continue
        else: raise ValueError('unsupported path command ' + c)
    out = []
    for pts, closed in subs:
        clean = [pts[0]]
        for p in pts[1:]:
            if abs(p[0] - clean[-1][0]) > 1e-6 or abs(p[1] - clean[-1][1]) > 1e-6: clean.append(p)
        if closed and len(clean) > 2 and abs(clean[0][0] - clean[-1][0]) < 1e-6 and abs(clean[0][1] - clean[-1][1]) < 1e-6: clean.pop()
        if closed and len(clean) > 3: out.extend((q, True) for q in simple_loops(clean))
        else: out.append((clean, closed))
    return out

def _cross(a, b, c, d):
    """Proper intersection point of segments ab and cd, or None."""
    d1x, d1y, d2x, d2y = b[0] - a[0], b[1] - a[1], d[0] - c[0], d[1] - c[1]
    den = d1x * d2y - d1y * d2x
    if abs(den) < 1e-12: return None
    t = ((c[0] - a[0]) * d2y - (c[1] - a[1]) * d2x) / den; u = ((c[0] - a[0]) * d1y - (c[1] - a[1]) * d1x) / den
    if 1e-9 < t < 1 - 1e-9 and 1e-9 < u < 1 - 1e-9: return (a[0] + t * d1x, a[1] + t * d1y)
    return None

def simple_loops(pts, depth=0):
    """Split a closed outline at its first edge crossing into two loops, recursively, until every loop is simple. The
    drawings' crossings make separate lobes (each filled under the nonzero rule), so every loop is kept."""
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1: continue          # the two edges that share the start point
            X = _cross(a, b, pts[j], pts[(j + 1) % n])
            if X is None: continue
            assert depth < 16, 'outline too tangled'
            one = [X] + pts[i + 1:j + 1]; two = [X] + pts[j + 1:] + pts[:i + 1]
            return simple_loops(one, depth + 1) + simple_loops(two, depth + 1)
    return [pts]

def ellipse_pts(cx, cy, rx, ry, n=120): return [(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]

def element_shapes(el):
    tag = el.tag.replace(NS, '')
    g = lambda k: float(el.get(k, 0))
    if tag == 'path': return path_subpaths(el.get('d'))
    if tag == 'circle': return [(ellipse_pts(g('cx'), g('cy'), g('r'), g('r')), True)]
    if tag == 'ellipse': return [(ellipse_pts(g('cx'), g('cy'), g('rx'), g('ry')), True)]
    if tag == 'rect':
        x, y, w, h = g('x'), g('y'), g('width'), g('height'); return [([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], True)]
    if tag == 'polygon':
        v = [float(t) for t in re.findall(r'[-+]?(?:\d*\.\d+|\d+\.?)', el.get('points'))]; return [(list(zip(v[::2], v[1::2])), True)]
    return []

def bbox(shapes):
    xs = [p[0] for s, _ in shapes for p in s]; ys = [p[1] for s, _ in shapes for p in s]
    return (min(xs), min(ys), max(xs), max(ys)) if xs else None
def bunion(a, b):
    if a is None: return b
    if b is None: return a
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))
def boverlap(a, b, pad=0.25): return a[0] < b[2] - pad and b[0] < a[2] - pad and a[1] < b[3] - pad and b[1] < a[3] - pad

# ---------------- materials ----------------
def satin(name, color, metal, rough, brushed=0.0, tangent=False):
    m, nt, b = T.node_mat(name); b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    if brushed: T.brush(nt, b, strength=0.05, axis='x', streaks=brushed, tangent=tangent)
    return m
GRAPHITE = satin('graphite', (0.16, 0.17, 0.19), 1.0, 0.5, brushed=0.6)        # blackened structural steel, a cool grey
SATIN = satin('satin', (0.68, 0.69, 0.68), 1.0, 0.34, brushed=0.9, tangent=True)  # brushed satin stainless
CUT = satin('cut', (0.86, 0.87, 0.85), 1.0, 0.22)                               # a polished cut face
BRASS = satin('brass', (0.8, 0.6, 0.31), 1.0, 0.26)
CERAMIC = satin('ceramic', (0.86, 0.89, 0.86), 0.0, 0.35)
SCREW = satin('screw', (0.1, 0.102, 0.106), 1.0, 0.3)
RECESS = satin('recess', (0.008, 0.009, 0.01), 0.0, 0.9)
# Glass: a pale green sheet, mostly clear (transparent glass) with a frosted tint in it, so it reads over a dark plate as
# the drawing's translucent sheets do (their fills run at 24-55 % opacity). Stacked sheets keep a 0.3 unit clearance:
# glass faces that coincide render opaque.
GLASS, ntg, bg = T.node_mat('glass')
T.inp(bg, 'Transmission Weight', 'Transmission').default_value = 1.0; bg.inputs['Roughness'].default_value = 0.06
bg.inputs['Base Color'].default_value = (0.86, 0.95, 0.91, 1); T.inp(bg, 'IOR').default_value = 1.5
_tint = ntg.nodes.new('ShaderNodeBsdfDiffuse'); _tint.inputs['Color'].default_value = (0.5, 0.64, 0.6, 1)
_mix = ntg.nodes.new('ShaderNodeMixShader'); _mix.inputs['Fac'].default_value = 0.22
_out = [n for n in ntg.nodes if n.type == 'OUTPUT_MATERIAL'][0]
ntg.links.new(bg.outputs[0], _mix.inputs[1]); ntg.links.new(_tint.outputs[0], _mix.inputs[2]); ntg.links.new(_mix.outputs[0], _out.inputs['Surface'])
HOLD = bpy.data.materials.new('holdout'); HOLD.use_nodes = True; HOLD.node_tree.nodes.clear()
HOLD.node_tree.links.new(HOLD.node_tree.nodes.new('ShaderNodeHoldout').outputs[0], HOLD.node_tree.nodes.new('ShaderNodeOutputMaterial').inputs['Surface'])
FAMILY = {'graphite': GRAPHITE, 'satin': SATIN, 'cut': CUT, 'brass': BRASS, 'ceramic': CERAMIC, 'glass': GLASS}
_solid = {}
def solid(hexcol, cls):
    """A solid fill: a void if it is a recess or nearly black, else a steel of the fill's own hue, calibrated as the
    drawing's own families render under this studio: a dark fill (the drawing's slate and graphite tones) brightened
    as the graphite family is, with graphite's finish; a light one brightened toward a polished steel, with brass and
    cut steel's finish. Brightened as a whole, never per channel, so the hue holds."""
    h = hexcol.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    if 'joint-recess' in cls or 'joint-aperture' in cls or max(lin) < 0.004: return RECESS
    if hexcol not in _solid:
        dark = max(lin) < 0.1
        k = min(6.0, 0.95 / max(lin))   # the graphite family's #262f35 average renders from GRAPHITE's base at about 6x
        _solid[hexcol] = satin('steel-' + h, tuple(v * k for v in lin), 1.0, 0.5 if dark else 0.26, brushed=0.4)
    return _solid[hexcol]
def paint_mat(paint, cls):
    if not paint or paint == 'none': return None
    m = re.match(r'url\(#[^)]*-(\w+)\)', paint)
    if m: return FAMILY.get(m.group(1), GRAPHITE)
    if paint.startswith('#'): return solid(paint, cls)
    return GRAPHITE

THICK = {'joint-body': 3.0, 'joint-cut': 1.2, 'joint-recess': 0.25, 'joint-aperture': 0.25, 'joint-lock': 2.0,
         'joint-mating': 2.0, 'joint-ceramic': 1.5, 'joint-glass': 1.0, 'joint-archive-door': 1.5,
         'joint-pressure-cap': 1.8, 'joint-iris-blade': 1.0}
def thickness(cls):
    for c in cls:
        if c in THICK: return THICK[c]
    return 1.0

# ---------------- reading the design ----------------
svg = ET.parse(os.path.join(A.svg_dir, A.joint + '.svg')).getroot()
assert svg.get('viewBox') == '0 0 240 160', svg.get('viewBox')
PARTS = []   # dicts: kind, shapes (rest), cls, mat, motion chain [(fn, pivot)], width (strips), order
def walk(el, inh, chain):
    tag = el.tag.replace(NS, '')
    if tag in ('defs', 'title', 'desc') or el.tag is ET.Comment: return
    cls = (el.get('class') or '').split()
    st = dict(inh)
    for k in ('fill', 'stroke', 'stroke-width'):
        if el.get(k) is not None: st[k] = el.get(k)
    if 'joint-highlight' in cls: return            # painted light: the render lights the parts itself
    mine = [MOTION[c] for c in cls if c in MOTION]
    if mine:
        fb = bbox([s for e in el.iter() for s in element_shapes(e)])   # the fill-box: geometry of the element and its children
        piv = ((fb[0] + fb[2]) / 2, (fb[1] + fb[3]) / 2)
        chain = chain + [(mine[0], piv)]
    if tag in ('g', 'svg'):
        for c in el: walk(c, dict(st, _cls=st.get('_cls', '') + ' ' + ' '.join(cls)), chain)
        return
    allcls = cls + st.get('_cls', '').split()
    shapes = element_shapes(el)
    if not shapes: return
    fill, stroke = st.get('fill'), st.get('stroke'); sw = float(st.get('stroke-width', 1))
    if 'joint-fasteners' in allcls:
        if el.tag.replace(NS, '') == 'circle':
            PARTS.append(dict(kind='screw', shapes=shapes, cls=allcls, mat=SCREW, chain=chain, r=float(el.get('r'))))
        else:
            for pts, closed in shapes: PARTS.append(dict(kind='strip', shapes=[(pts, False)], cls=allcls + ['slot'], mat=RECESS, chain=chain, width=0.9))
        return
    closed_any = any(c for _, c in shapes)
    fm = paint_mat(fill, allcls) if closed_any else None
    if fm is not None:
        PARTS.append(dict(kind='solid', shapes=[(p, c) for p, c in shapes if c], cls=allcls, mat=fm, chain=chain))
        if stroke and stroke.startswith('url('):   # a gradient stroke is a finished edge or ring: keep it
            PARTS.append(dict(kind='strip', shapes=[(p, True) for p, c in shapes if c], cls=allcls + ['edge'], mat=paint_mat(stroke, allcls), chain=chain, width=sw))
    elif stroke and stroke != 'none':
        sm = paint_mat(stroke, allcls)
        PARTS.append(dict(kind='strip', shapes=shapes, cls=allcls, mat=sm, chain=chain, width=sw))
walk(svg, {'fill': svg.get('fill', 'black')}, [])

def xform(chain, e):
    m = IDENT
    for fn, (cx, cy) in chain: m = mat_mul(m, about(fn(e), cx, cy))   # outer group first, as nested CSS transforms
    return m

def strip_polys(pts, closed, w):
    """A stroke of width w along a polyline: one quad per segment, extended by w/2 at each end so corners close."""
    out = []; seq = pts + ([pts[0]] if closed else [])
    for (ax, ay), (bx, by) in zip(seq, seq[1:]):
        L = math.hypot(bx - ax, by - ay)
        if L < 1e-6: continue
        ux, uy = (bx - ax) / L, (by - ay) / L; nx, ny = -uy * w / 2, ux * w / 2; ex, ey = ux * w / 2, uy * w / 2
        out.append([(ax - ex + nx, ay - ey + ny), (bx + ex + nx, by + ey + ny), (bx + ex - nx, by + ey - ny), (ax - ex - nx, ay - ey - ny)])
    return out

# Stacking, from the rest state and the engaged state together (a part that slides keeps above what it slides over).
for p in PARTS:
    rest = [(s, c) for s, c in p['shapes']]
    if p['kind'] == 'strip': rest = [(q, True) for s, c in p['shapes'] for q in strip_polys(s, c, p['width'])]
    m1 = xform(p['chain'], 1.0)
    # one box per outline (rest and engaged together), so a part made of separate pieces only rests on what each
    # piece overlaps
    p['boxes'] = [bunion(bbox([(s, c)]), bbox([(apply(m1, s), c)])) for s, c in rest]
    if p['kind'] == 'screw': p['t'] = 1.4
    elif p['kind'] == 'strip': p['t'] = 0.35 if ('slot' in p['cls'] or 'edge' in p['cls']) else 0.45
    else: p['t'] = thickness(p['cls'])
def touches(q, p): return any(boverlap(a, b) for a in q['boxes'] for b in p['boxes'])
tops = []
for i, p in enumerate(PARTS):
    z0 = max([tops[j] for j in range(i) if touches(PARTS[j], p)] + [0.0])
    p['z0'] = z0; tops.append(z0 + p['t'] + (0.3 if p['mat'] == GLASS else 0.0))

# ---------------- building ----------------
coll = bpy.data.collections.new('parts'); scn.collection.children.link(coll)
def prism(name, polys, z0, z1, mat, bevel):
    bm = bmesh.new()
    for pts in polys:
        if len(pts) < 3: continue
        area = sum(pts[k][0] * pts[(k + 1) % len(pts)][1] - pts[(k + 1) % len(pts)][0] * pts[k][1] for k in range(len(pts)))
        if abs(area) < 1e-4: continue
        lo = [bm.verts.new((x * S, -y * S, z0 * S)) for x, y in pts]; hi = [bm.verts.new((x * S, -y * S, z1 * S)) for x, y in pts]
        n = len(pts)
        try:
            bm.faces.new(hi); bm.faces.new(lo[::-1])
            for k in range(n): bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
        except ValueError: pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); coll.objects.link(ob); me.materials.append(mat)
    if bevel > 0:
        md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel * S; md.segments = 3; md.limit_method = 'ANGLE'
        md.angle_limit = math.radians(35); md.use_clamp_overlap = True
    return ob

def screw(name, cx, cy, r, z0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=r * S, depth=1.4 * S, location=P(cx, cy, z0 + 0.7))
    ob = bpy.context.active_object; ob.name = name
    for c in ob.users_collection: c.objects.unlink(ob)
    coll.objects.link(ob)
    md = ob.modifiers.new('bev', 'BEVEL'); md.width = min(0.9, r * 0.35) * S; md.segments = 4; md.limit_method = 'ANGLE'
    for pg in ob.data.polygons: pg.use_smooth = True
    ob.data.materials.append(SCREW); return ob

def build(e):
    for ob in list(coll.objects): bpy.data.objects.remove(ob, do_unlink=True)
    for i, p in enumerate(PARTS):
        m = xform(p['chain'], e); z0, z1 = p['z0'], p['z0'] + p['t']; name = f'p{i:02d}'
        if p['kind'] == 'screw':
            (pts, _), = p['shapes']; c = apply(m, [(sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts))])[0]
            ob = screw(name, c[0], c[1], p['r'], z0)
        elif p['kind'] == 'strip':
            polys = [apply(m, q) for s, c in p['shapes'] for q in strip_polys(s, c, p['width'])]
            # each segment a hair higher than the last, so overlapping corners never fight
            bm_objs = [prism(f'{name}-{k}', [q], z0 + 0.002 * k, z1 + 0.002 * k, p['mat'], min(0.15, p['width'] * 0.2)) for k, q in enumerate(polys)]
            ob = bm_objs[0] if bm_objs else None
        else:
            ob = prism(name, [apply(m, s) for s, c in p['shapes']], z0, z1, p['mat'], min(0.9, p['t'] * 0.4))
    for ob in coll.objects:
        if A.pass_ == 'shadow':
            ob.visible_camera = False
            if ob.data.materials and ob.data.materials[0] == GLASS: ob.visible_shadow = False

# ---------------- studio, camera, frames ----------------
bpy.ops.mesh.primitive_plane_add(size=1); ground = bpy.context.active_object; ground.name = 'ground'
ground.location = P((X0 + X1) / 2, (Y0 + Y1) / 2, 0); ground.scale = ((X1 - X0 + 40) * S, (Y1 - Y0 + 40) * S, 1)
if A.pass_ == 'obj': ground.data.materials.append(HOLD)
else: ground.data.materials.append(RECESS); ground.is_shadow_catcher = True
sun = T.ti_studio(A.dome, A.sun, A.cone, 0.0 if A.pass_ == 'shadow' else A.rim, A.band_lo); sun.data.use_shadow = False
if A.pass_ == 'shadow':
    cd = bpy.data.lights.new('contact', 'SUN'); cd.energy = A.contact_power; cd.angle = math.radians(A.contact_angle)
    co = bpy.data.objects.new('contact', cd); scn.collection.objects.link(co)
    az, el = math.radians(32), math.radians(A.contact_el)
    to = Vector((-math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el))); co.rotation_euler = (-to).to_track_quat('-Z', 'Y').to_euler()
T.camera((X0 + X1) / 2 * S, -(Y0 + Y1) / 2 * S, (X1 - X0) * S, (X1 - X0) * A.scale, (Y1 - Y0) * A.scale)
os.makedirs(A.out, exist_ok=True)
T.render_setup(A.samples, os.path.join(A.out, 'x.png'), transparent=True)
try: scn.cycles.film_transparent_glass = True
except Exception: pass
n = A.frames
for k in range(n):
    if A.only_frame >= 0 and k != A.only_frame: continue
    e = k / (n - 1) if n > 1 else 0.0
    build(e)
    scn.render.filepath = os.path.join(A.out, f'{A.joint}-{A.pass_}-{k}.png')
    bpy.ops.render.render(write_still=True)
    print(f'frame {k} e={e:.4f} parts={len(PARTS)}')
