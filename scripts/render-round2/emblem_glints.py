"""The milled seal's pointer light ("living metal"), as the light's own contribution. Reproducible:
blender -b --factory-startup -P ti_emblem.py -- --masks EMASKS --scale 2 --samples 256 --out base.png
blender -b --factory-startup -P ti_emblem.py -- --masks EMASKS --scale 2 --samples 256 --glint N|E|S|W --out N.png ...
python emblem_glints.py DIR EMASKS    (writes DIR/PF_MARK_G_TI_GLINT_{N,E,S,W}.png)

The hero emblem (PF_MARK_G_TI_920) rendered as shipped, and again with one low, cool distant light from each side of
the plate. glint - base (premultiplied, so the plate's transparent face adds nothing) is what that light adds: the
chamfers, the ring walls, the gold F's edges and the turned band that face it. Above 1/255 of residual noise it is
kept, except on the etched legends and the plates' engraving (emblem_masks.py's mask-etch and mask-id-ink, grown by
1 px): their floors are drawn in the emblem while the plate around them is the page's own titanium, which the light
does not reach, so a glint there would lift the letters to the plate's tone and wash them out. It is stored as
straight-alpha RGBA at 920 x 1062, alpha the brightest channel, so the pass only ever adds light, even where a
browser cannot blend it. pf-home.js sets --lN/--lE/--lS/--lW from the pointer's side of the seal, and
pf-home-ledger.css adds each pass over the emblem with mix-blend-mode: plus-lighter at that opacity, so two
neighbouring passes blend into a light from in between.
"""
import os, subprocess, sys
import numpy as np
from PIL import Image, ImageFilter


def read(path):
    with Image.open(path) as im: w, h = im.size
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgba64le', '-'])
    a = np.frombuffer(raw, dtype='<u2').reshape(h, w, 4).astype(np.float64) / 257
    return a[..., :3] * a[..., 3:] / 255


def legends(emasks, w, h):
    m = None
    for n in ('mask-etch', 'mask-id-ink'):
        with Image.open(os.path.join(emasks, n + '.png')) as im:
            a = im.convert('L').resize((w, h), Image.LANCZOS).filter(ImageFilter.MaxFilter(3))
        a = np.asarray(a).astype(np.float64) / 255
        m = a if m is None else np.maximum(m, a)
    return np.clip(m * 1.5, 0, 1)


def rgba(add):
    a = add.max(axis=2, keepdims=True)
    col = np.where(a > 0, add * 255 / np.maximum(a, 1e-6), 0)
    return np.clip(np.concatenate([col, a], axis=2) + 0.5, 0, 255).astype(np.uint8)


def main(d, emasks):
    base = read(os.path.join(d, 'base.png'))
    keep = 1 - legends(emasks, base.shape[1], base.shape[0])[..., None]
    for side in 'NESW':
        add = np.clip(read(os.path.join(d, f'{side}.png')) - base - 1.0, 0, 255) * keep
        Image.fromarray(rgba(add)).save(os.path.join(d, f'PF_MARK_G_TI_GLINT_{side}.png'))
        print(side, add.shape[1::-1], 'added mean %.2f p99 %.1f max %.1f' % (add.mean(), np.percentile(add, 99), add.max()))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
