"""Lay a part over its own contact shadow. Reproducible:
python sprite_compose.py PART_obj.png PART_shadow.png OUT.png

head_parts.py renders each sprite twice: --pass obj (the part under the full studio, with the low rim band that lights
its chamfers; its plate and occluders are holdouts, so it carries no shadow) and --pass shadow (the same scene under
the overhead dome alone, the plate a shadow catcher). The rim band runs from just below the horizon (--band-lo -4) to 30-40 deg up, so the shadows it
throws run 40 px and more and a sprite's canvas cut them off in a hard edge. The shadow pass lights the plate with the
overhead dome and a soft contact light high over the key azimuth (head_parts.py --contact-el/-angle/-power), whose
short shadow fades out inside the canvas.
Both are 16-bit straight-alpha PNGs. Out = obj over shadow: alpha a_o + (1 - a_o) a_s, colour obj (the shadow is black).
"""
import subprocess, sys
import numpy as np
from PIL import Image


def read(path):
    with Image.open(path) as im: w, h = im.size
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgba64le', '-'])
    return np.frombuffer(raw, dtype='<u2').reshape(h, w, 4).astype(np.float64) / 65535


def main(obj, shadow, out):
    o, s = read(obj), read(shadow)
    assert o.shape == s.shape, (o.shape, s.shape)
    ao, as_ = o[..., 3:], s[..., 3:]
    a = ao + (1 - ao) * as_
    rgb = np.where(a > 1e-6, o[..., :3] * ao / np.maximum(a, 1e-6), 0)
    px = np.clip(np.concatenate([rgb, a], axis=2) * 65535 + 0.5, 0, 65535).astype('<u2')
    h, w = px.shape[:2]
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba64le', '-s', f'{w}x{h}', '-i', '-',
                    '-pix_fmt', 'rgba64be', out], input=px.tobytes(), check=True)


if __name__ == '__main__':
    main(*sys.argv[1:4])
