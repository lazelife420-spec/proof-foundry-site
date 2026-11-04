"""Masks for ti_emblem.py, drawn by headless Chrome with the original emblem's own text routine. Reproducible:
python emblem_masks.py <out-dir>   (Chrome at C:/Program Files/Google/Chrome/Application/chrome.exe, or $PF_CHROME)

Every mask covers the original emblem's assembly frame, x -8..264 and y -8..306 emblem units, at 8 px per unit
(2176 x 2512 px), white on black. Geometry, legends, sizes and spacing are those of scripts/pf-emblem/render-lib.js
(glyphRun, lineText and arcText are reproduced verbatim, with assets/fonts IBM Plex Mono):
- mask-etch.png:        engraved into the titanium face: the two ring legends, the registration ticks, the witness
                        marks, the hairline at r 102.3 and the two lines of microtext.
- mask-inlay.png:       the four brass compass inlays round the ring.   mask-inlay-seam.png: their seams.
- mask-id-ink.png:      the identification plates' legends.
- mask-bridge.png:      the bridge's brass record inlay.                mask-bridge-seam.png: its seam.
- temper-color.png:     the temper colours on the P round the two tack welds (straw, bronze, violet, blue), from
                        render-lib.js's hazD bands.     temper-amount.png: their strength (Chrome screenshots are opaque).
"""
import os, subprocess, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT = os.path.abspath(sys.argv[1]); os.makedirs(OUT, exist_ok=True)
CHROME = os.environ.get('PF_CHROME', r'C:/Program Files/Google/Chrome/Application/chrome.exe')
K = 8; W, H = 272 * K, 314 * K
FONTS = 'file:///' + os.path.join(ROOT, 'assets', 'fonts').replace('\\', '/')

COMMON = r'''
const CX = 128, CY = 128;
const LT = { tx: 26.16, ty: 30.72, s: 0.76 };
const lt = (g) => { g.translate(LT.tx, LT.ty); g.scale(LT.s, LT.s); };
function glyphRun(g, text, size, spacing, weight) {
  g.font = `${weight} ${size}px PlexMono`;
  const adv = [...text].map((ch) => g.measureText(ch).width);
  const total = adv.reduce((s, a) => s + a, 0) + spacing * (adv.length - 1);
  return { chars: [...text], adv, total };
}
function lineText(g, text, cx, baseline, size, spacing, weight = 600) {
  const run = glyphRun(g, text, size, spacing, weight);
  let x = cx - run.total / 2;
  run.chars.forEach((ch, i) => { g.fillText(ch, x, baseline); x += run.adv[i] + spacing; });
}
function arcText(g, text, r, centerAngle, dir, size, spacing, weight = 600) {
  const run = glyphRun(g, text, size, spacing, weight);
  let s = -run.total / 2;
  run.chars.forEach((ch, i) => {
    const mid = s + run.adv[i] / 2, phi = centerAngle + dir * mid / r;
    g.save(); g.translate(CX + r * Math.cos(phi), CY + r * Math.sin(phi)); g.rotate(dir > 0 ? phi + Math.PI / 2 : phi - Math.PI / 2);
    g.fillText(ch, -run.adv[i] / 2, 0); g.restore();
    s += run.adv[i] + spacing;
  });
}
const MASKS = {
  'mask-etch': (g) => {
    arcText(g, 'THE PROOF FOUNDRY\u2122', 105.2, -Math.PI / 2, 1, 6.5, 1.3, 600);
    arcText(g, 'BUILD IT. PROVE IT. SHIP IT.', 111.4, Math.PI / 2, -1, 6.0, 1.0, 600);
    g.lineCap = 'butt';
    for (let deg = -30; deg <= 30; deg += 3) for (const side of [0, 180]) {
      const a = (deg + side) * Math.PI / 180, major = deg % 15 === 0;
      const r0 = major ? 102.6 : 104.9, r1 = major ? 111.6 : 109.4;
      g.lineWidth = major ? 0.8 : 0.45;
      g.beginPath(); g.moveTo(CX + r0 * Math.cos(a), CY + r0 * Math.sin(a)); g.lineTo(CX + r1 * Math.cos(a), CY + r1 * Math.sin(a)); g.stroke();
    }
    g.lineWidth = 0.6; g.beginPath(); g.moveTo(113, 14.2); g.lineTo(113, 18); g.moveTo(143, 14.2); g.lineTo(143, 18); g.stroke();
    g.lineWidth = 0.5; g.beginPath(); g.arc(CX, CY, 102.3, 0, Math.PI * 2); g.stroke();
    lineText(g, '01010000 01000110', 128, 2.75, 5.1, 1.05, 500);
    lineText(g, 'IF IT MATTERS, KEEP THE RECEIPT.', 128, 300.15, 3.9, 0.72, 500);
  },
  'mask-inlay': (g) => { g.fillRect(126.75, 7, 2.5, 6.4); g.fillRect(126.75, 242.6, 2.5, 6.4); g.fillRect(7, 126.75, 6.4, 2.5); g.fillRect(242.6, 126.75, 6.4, 2.5); },
  'mask-inlay-seam': (g) => { g.lineWidth = 0.32; g.strokeRect(126.75, 7, 2.5, 6.4); g.strokeRect(126.75, 242.6, 2.5, 6.4); g.strokeRect(7, 126.75, 6.4, 2.5); g.strokeRect(242.6, 126.75, 6.4, 2.5); },
  'mask-id-ink': (g) => { lineText(g, 'SOURCE / ARTIFACT / RECORD', 96, 279.15, 5.4, 1.05, 600); lineText(g, 'RECEIPTS', 208, 275.5, 4.5, 1.0, 600); lineText(g, 'OVER HYPE.', 208, 283.9, 4.5, 1.0, 600); },
  'mask-bridge': (g) => { lt(g); g.fillRect(140.5, 101.2, 43.5, 3.0); },
  'mask-bridge-seam': (g) => { lt(g); g.lineWidth = 0.5; g.strokeRect(140.5, 101.2, 43.5, 3.0); },
};
'''

def page(name, body):
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:PlexMono;font-weight:500;src:url({FONTS}/ibm-plex-mono-latin-500.woff2) format('woff2')}}
@font-face{{font-family:PlexMono;font-weight:600;src:url({FONTS}/ibm-plex-mono-latin-600.woff2) format('woff2')}}
html,body{{margin:0;background:#000}}canvas{{display:block}}</style></head><body>
<canvas id="c" width="{W}" height="{H}"></canvas><script>
{COMMON}
(async () => {{
  await document.fonts.load('600 20px PlexMono'); await document.fonts.load('500 20px PlexMono');
  const c = document.getElementById('c'), g = c.getContext('2d');
  {body}
}})();
</script></body></html>'''

MASK_BODY = '''g.fillStyle = '#000'; g.fillRect(0, 0, c.width, c.height);
  g.setTransform({k}, 0, 0, {k}, 8 * {k}, 8 * {k}); g.fillStyle = '#fff'; g.strokeStyle = '#fff';
  MASKS['{name}'](g);'''
TEMPER_BODY = '''g.clearRect(0, 0, c.width, c.height);
  const img = g.createImageData(c.width, c.height), d = img.data;
  // render-lib.js hazD: distance (units) from each bead's centre line, beads at y 83.92 and 111.28, x 131.6..136.8.
  const hazD = (ux, uy) => { let best = 99; for (const yy of [83.92, 111.28]) { const dx = Math.max(0, Math.max(131.6 - ux, ux - 136.8)), dy = uy - yy; best = Math.min(best, Math.hypot(dx, dy * 1.15)); } return best; };
  const sstep = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  for (let y = 0; y < c.height; y++) for (let x = 0; x < c.width; x++) {
    const ux = x / {k} - 8, uy = y / {k} - 8, hd = hazD(ux, uy); if (hd >= 3.4) continue;
    const band = (cc, w) => Math.exp(-((hd - cc) * (hd - cc)) / (2 * w * w));
    const straw = band(0.75, 0.35), bronze = band(1.35, 0.3), violet = band(1.95, 0.3), blue = band(2.6, 0.38);
    const k2 = 0.62 * (1 - sstep(2.6, 3.4, hd)), ws = straw + bronze + violet + blue + 1e-6;
    const tr = (0.86 * straw + 0.62 * bronze + 0.42 * violet + 0.34 * blue) / ws, tg = (0.72 * straw + 0.42 * bronze + 0.28 * violet + 0.45 * blue) / ws, tb = (0.42 * straw + 0.24 * bronze + 0.5 * violet + 0.72 * blue) / ws;
    const i = (y * c.width + x) * 4, amt = k2 * Math.min(1, ws);
    if (MODE === 'color') { d[i] = tr * 255; d[i + 1] = tg * 255; d[i + 2] = tb * 255; } else { d[i] = d[i + 1] = d[i + 2] = 255 * amt; }
    d[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);'''

jobs = {n: MASK_BODY.format(k=K, name=n) for n in ('mask-etch', 'mask-inlay', 'mask-inlay-seam', 'mask-id-ink', 'mask-bridge', 'mask-bridge-seam')}
jobs['temper-color'] = "const MODE = 'color';\n  " + TEMPER_BODY.replace('{k}', str(K))
jobs['temper-amount'] = "const MODE = 'amount';\n  " + TEMPER_BODY.replace('{k}', str(K))
for name, body in jobs.items():
    html = os.path.join(OUT, name + '.html'); open(html, 'w', encoding='utf-8').write(page(name, body))
    png = os.path.join(OUT, name + '.png')
    if os.path.exists(png): os.remove(png)
    args = [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--allow-file-access-from-files',
            '--virtual-time-budget=8000', f'--window-size={W},{H}', f'--screenshot={png}', 'file:///' + html.replace('\\', '/')]
    subprocess.run(args, check=True, capture_output=True, timeout=180)
    assert os.path.exists(png), png
    print('ok', png)
