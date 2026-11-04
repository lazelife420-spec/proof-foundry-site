"""The proof chain's inspection light, as the light's own contribution. Reproducible:
for N in 0..4:
  blender -b --factory-startup -P chain_scene.py -- --scene desktop --mode base --scale 2 --samples 160 --crop N --out sN-off.png
  blender -b --factory-startup -P chain_scene.py -- --scene desktop --mode base --scale 2 --samples 160 --crop N --lit N --out sN-on.png
python chain_light.py DIR    (writes DIR/chain-light-sN.png)

Each stage's crop is its light-pool box in the 1400 x 431 frame (chain_scene.POOL, the CSS stage vars), rendered with the
same scene, studio and samples as the shipped base (chain-desktop-*.webp), once as it is and once with the inspection
light: a small cool spot above that stage's checkpoint link. on - off is what the light adds. It is kept where it is
above the two renders' residual noise (1.5/255) and feathered to zero over the box's outer 10 CSS px, so no edge can
show (the spot's own falloff does most of that; the feather removes the rest). It is stored as straight-alpha RGBA,
alpha the brightest channel: the page adds it over the base with mix-blend-mode: plus-lighter, so the shipped chain art
itself never changes, and where a browser cannot blend it (or the chain has not loaded) it still only adds light.
"""
import os, subprocess, sys
import numpy as np
from PIL import Image


def read(path):
    with Image.open(path) as im: w, h = im.size
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgb48le', '-'])
    return np.frombuffer(raw, dtype='<u2').reshape(h, w, 3).astype(np.float64) / 257


def main(d):
    for n in range(5):
        on, off = read(os.path.join(d, f's{n}-on.png')), read(os.path.join(d, f's{n}-off.png'))
        add = np.clip(on - off - 1.5, 0, 255)
        h, w = add.shape[:2]; f = 20.0   # 10 CSS px at 2x
        wy = np.clip(np.minimum(np.arange(h), np.arange(h)[::-1]) / f, 0, 1); wx = np.clip(np.minimum(np.arange(w), np.arange(w)[::-1]) / f, 0, 1)
        win = (np.sin(np.minimum(wy[:, None], wx[None, :]) * np.pi / 2)) ** 2
        add *= win[..., None]
        a = add.max(axis=2, keepdims=True); col = np.where(a > 0, add * 255 / np.maximum(a, 1e-6), 0)
        Image.fromarray(np.clip(np.concatenate([col, a], axis=2) + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(d, f'chain-light-s{n}.png'))
        print(f's{n}', (w, h), 'added mean %.2f max %.1f' % (add.mean(), add.max()))


if __name__ == '__main__':
    main(sys.argv[1])
