"""The connection joints' motion strips. Reproducible:
python joint_strips.py MASTERS_DIR ASSETS_DIR cache-vault [cleanroom ...]

Each joint has nine composed frames, <id>-0.png .. <id>-8.png (joint_parts.py at 2 px per unit, obj over shadow by
sprite_compose.py; 516 x 348, the viewBox -6..252 x -6..168). Each frame is scaled on its own, premultiplied, with
Lanczos to 2/3 (344 x 232, the 2x strip) and 1/3 (172 x 116, the 1x strip), so no frame bleeds into the next, and the
frames are laid left to right, rest first. WebP, quality 90, yuva420p.
"""
import subprocess, sys, os
import numpy as np
from PIL import Image


def read(path):
    with Image.open(path) as im: w, h = im.size
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt', 'rgba64le', '-'])
    return np.frombuffer(raw, dtype='<u2').reshape(h, w, 4).astype(np.float64) / 65535


def scale(px, w, h):
    a = px[..., 3:]; pre = np.concatenate([px[..., :3] * a, a], axis=2)
    out = np.stack([np.asarray(Image.fromarray(np.ascontiguousarray(pre[..., c], dtype=np.float32)).resize((w, h), Image.LANCZOS)) for c in range(4)], axis=2)
    out = np.clip(out, 0, 1); a = out[..., 3:]
    rgb = np.where(a > 1e-6, out[..., :3] / np.maximum(a, 1e-6), 0)
    return np.concatenate([np.clip(rgb, 0, 1), a], axis=2)


def write_webp(px, out):
    h, w = px.shape[:2]
    raw = np.clip(px * 65535 + 0.5, 0, 65535).astype('<u2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba64le', '-s', f'{w}x{h}', '-i', '-',
                    '-pix_fmt', 'yuva420p', '-c:v', 'libwebp', '-quality', '90', '-compression_level', '6', out], input=raw, check=True)


def main(mdir, adir, joints):
    for j in joints:
        frames = [read(os.path.join(mdir, f'{j}-{k}.png')) for k in range(9)]
        assert all(f.shape == (348, 516, 4) for f in frames), [f.shape for f in frames]
        for tag, (w, h) in (('2x', (344, 232)), ('1x', (172, 116))):
            write_webp(np.concatenate([scale(f, w, h) for f in frames], axis=1), os.path.join(adir, f'{j}-{tag}.webp'))
        print(j, 'ok')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
