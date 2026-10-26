// PF Mark G — physically shaded emblem renderer (runs in Chrome; Canvas2D for rasterising, JS for shading).
// Canonical P / F / bridge paths are used verbatim; everything else is the maker's-seal assembly around them.
window.PFRender = (() => {
  'use strict';

  // ---------------------------------------------------------------- frame
  let OX = -26, OY = -26, UW = 308, UH = 356;             // emblem units (V4 seal coordinates)
  let W, H, S, N;
  let accR, accG, accB, accA;                               // premultiplied linear RGBA
  let lm, hot;                                                    // living-metal masks
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const sstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
  const mix = (a, b, t) => a + (b - a) * t;
  const norm3 = (v) => { const l = Math.hypot(v[0], v[1], v[2]); return [v[0] / l, v[1] / l, v[2] / l]; };

  // ---------------------------------------------------------------- canonical PF Mark G (do not edit)
  const P_PATH = 'M42 34H116C157 34 181 56 181 91C181 126 157 148 116 148H82V222H42V34ZM82 70V112H115C132 112 141 104 141 91C141 78 132 70 115 70H82Z';
  const F_PATH = 'M146 34H226V72H186V106H218V143H186V222H146V34Z';
  const B_PATH = 'M138 70H186V106H138Z';
  const LT = { tx: 26.16, ty: 30.72, s: 0.76 };             // canonical -> seal floor
  const lt = (g) => { g.translate(LT.tx, LT.ty); g.scale(LT.s, LT.s); };

  // ---------------------------------------------------------------- assembly geometry (emblem units)
  const MOUNT = 'M6 -8H250L264 6V292L250 306H6L-8 292V6Z';
  const PLATE = 'M17 7H239L249 17V239L239 249H17L7 239V17Z';
  const LP1 = 'M23 262H169L172 265V289L169 292H23L20 289V265Z';
  const LP2 = 'M183 262H233L236 265V289L233 292H183L180 289V265Z';
  const CX = 128, CY = 128, R_FLOOR = 100, R_GROOVE = 114;
  const OBL = [0.30, 0.38];                                  // screen offset per unit of depth (sidewalls)
  const SHD = [0.56, 0.72];                                  // cast-shadow offset per unit of height

  // ---------------------------------------------------------------- lighting rig
  const K = norm3([-0.52, -0.60, 0.60]);                     // key softbox, upper left
  const K2 = norm3([0.86, -0.22, 0.46]);                     // cool rim strip, right
  const AZ0 = Math.atan2(-0.74, -0.67);                      // horizon window azimuth (upper left)
  let rigTilt = [0, 0];                                      // optional: shifts the key for living-metal frames

  function env(rx, ry, rz, ux, uy, rough, out) {
    let L = 0;
    // overhead diffuser at finite distance — flat faces read a soft positional gradient
    if (rz > 0.02) {
      const t = 250 / rz, qx = ux + rx * t, qy = uy + ry * t, s = 45 + rough * 230;
      const wx = sstep(-320 - s, -320 + s, qx) * (1 - sstep(300 - s, 300 + s, qx));
      const wy = sstep(-380 - s, -380 + s, qy) * (1 - sstep(140 - s, 140 + s, qy));
      const grad = 0.66 + 0.34 * clamp((300 - (qx + qy)) / 560, 0, 1);
      L += 0.58 * wx * wy * grad * sstep(0.0, 0.45, rz);
      const sd = 0.7071 * (qx + qy - 228), sw = 15 + rough * 85;
      L += 0.3 * Math.exp(-(sd * sd) / (2 * sw * sw)) * sstep(0.1, 0.6, rz);
    }
    // key softbox
    const kx = K[0] + rigTilt[0], ky = K[1] + rigTilt[1], kl = Math.hypot(kx, ky, K[2]);
    const dk = (rx * kx + ry * ky + rz * K[2]) / kl;
    L += 1.25 * Math.exp(-(1 - dk) / (0.022 + rough * 0.2));
    // horizon window, upper left (chamfers facing the light catch it)
    let da = Math.atan2(ry, rx) - AZ0;
    if (da > Math.PI) da -= 2 * Math.PI; else if (da < -Math.PI) da += 2 * Math.PI;
    const ew = 0.13 + rough * 0.22;
    L += 0.66 * Math.exp(-(da * da) / 0.5) * Math.exp(-((rz - 0.08) * (rz - 0.08)) / (2 * ew * ew));
    // room
    L += 0.04 + 0.05 * Math.max(0, -ry) + 0.025 * Math.max(0, rz);
    // cool rim from the right
    const d2 = rx * K2[0] + ry * K2[1] + rz * K2[2];
    const rim = 0.3 * Math.exp(-(1 - d2) / (0.018 + rough * 0.14));
    out[0] = L + rim * 0.82; out[1] = L + rim * 0.92; out[2] = L + rim;
  }

  // ---------------------------------------------------------------- noise
  function rng(seed) { return () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  const NG = 256, grid = new Float32Array(NG * NG);
  { const r = rng(20261013); for (let i = 0; i < grid.length; i++) grid[i] = r() * 2 - 1; }
  function noise(x, y) {
    const xi = Math.floor(x), yi = Math.floor(y);
    let fx = x - xi, fy = y - yi;
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
    const x0 = xi & 255, y0 = yi & 255, x1 = (x0 + 1) & 255, y1 = (y0 + 1) & 255;
    const a = grid[x0 + y0 * NG], b = grid[x1 + y0 * NG], c = grid[x0 + y1 * NG], d = grid[x1 + y1 * NG];
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }
  const fbm = (x, y) => noise(x, y) * 0.55 + noise(x * 2.03 + 17.1, y * 2.03 + 3.7) * 0.3 + noise(x * 4.1 + 5.3, y * 4.1 + 31.9) * 0.15;

  // ---------------------------------------------------------------- regions & rasterising
  function region(u0, v0, u1, v1, padPx = 4) {
    const x0 = Math.max(0, Math.floor((u0 - OX) * S) - padPx), y0 = Math.max(0, Math.floor((v0 - OY) * S) - padPx);
    const x1 = Math.min(W, Math.ceil((u1 - OX) * S) + padPx), y1 = Math.min(H, Math.ceil((v1 - OY) * S) + padPx);
    return { x0, y0, w: x1 - x0, h: y1 - y0 };
  }
  const mkCanvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
  function raster(R, k, draw) {
    const c = mkCanvas(R.w * k, R.h * k), g = c.getContext('2d', { willReadFrequently: true });
    g.setTransform(S * k, 0, 0, S * k, -k * (OX * S + R.x0), -k * (OY * S + R.y0));
    g.fillStyle = '#fff'; g.strokeStyle = '#fff';
    draw(g);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    const a = new Float32Array(c.width * c.height);
    for (let i = 0, j = 3; i < a.length; i++, j += 4) a[i] = d[j] / 255;
    return a;
  }
  const fillPath = (p, rule) => (g) => g.fill(new Path2D(p), rule || 'nonzero');
  const letter = (p) => (g) => { lt(g); g.fill(new Path2D(p)); };

  // exact Euclidean distance transform (Felzenszwalb & Huttenlocher), squared, in place
  function edt(f, w, h) {
    const n = Math.max(w, h), d = new Float32Array(n), v = new Int32Array(n), z = new Float32Array(n + 1), ff = new Float32Array(n);
    const one = (len) => {
      let k = 0; v[0] = 0; z[0] = -1e20; z[1] = 1e20;
      for (let q = 1; q < len; q++) {
        let s = ((ff[q] + q * q) - (ff[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
        while (s <= z[k]) { k--; s = ((ff[q] + q * q) - (ff[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]); }
        k++; v[k] = q; z[k] = s; z[k + 1] = 1e20;
      }
      k = 0;
      for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; const dq = q - v[k]; d[q] = dq * dq + ff[v[k]]; }
    };
    for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) ff[y] = f[y * w + x]; one(h); for (let y = 0; y < h; y++) f[y * w + x] = d[y]; }
    for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) ff[x] = f[y * w + x]; one(w); for (let x = 0; x < w; x++) f[y * w + x] = d[x]; }
  }
  // distance fields at 2x, returned at 1x in px: din (inside, to edge), dout (outside, to edge), coverage
  function field(R, draw, wantOut) {
    const w2 = R.w * 2, h2 = R.h * 2, c2 = raster(R, 2, draw), f = new Float32Array(w2 * h2);
    const down = () => {
      const o = new Float32Array(R.w * R.h);
      for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
        const i = 2 * y * w2 + 2 * x;
        const s = Math.max(0, Math.sqrt(f[i]) - 0.5) + Math.max(0, Math.sqrt(f[i + 1]) - 0.5) + Math.max(0, Math.sqrt(f[i + w2]) - 0.5) + Math.max(0, Math.sqrt(f[i + w2 + 1]) - 0.5);
        o[y * R.w + x] = s * 0.125;
      }
      return o;
    };
    for (let i = 0; i < f.length; i++) f[i] = c2[i] >= 0.5 ? 1e20 : 0;
    edt(f, w2, h2); const din = down();
    let dout = null;
    if (wantOut) { for (let i = 0; i < f.length; i++) f[i] = c2[i] >= 0.5 ? 0 : 1e20; edt(f, w2, h2); dout = down(); }
    const cov = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) { const i = 2 * y * w2 + 2 * x; cov[y * R.w + x] = (c2[i] + c2[i + 1] + c2[i + w2] + c2[i + w2 + 1]) * 0.25; }
    return { R, cov, din, dout };
  }
  // separable 3-pass box blur ≈ gaussian(sigma px)
  function blur(a, w, h, sigma) {
    const r = Math.max(1, Math.round(sigma)); if (sigma < 0.4) return a;
    const t = new Float32Array(a.length), inv = 1 / (2 * r + 1);
    for (let pass = 0; pass < 3; pass++) {
      for (let y = 0; y < h; y++) { const o = y * w; let s = 0; for (let x = -r; x <= r; x++) s += a[o + clamp(x, 0, w - 1)]; for (let x = 0; x < w; x++) { t[o + x] = s * inv; s += a[o + Math.min(w - 1, x + r + 1)] - a[o + Math.max(0, x - r)]; } }
      for (let x = 0; x < w; x++) { let s = 0; for (let y = -r; y <= r; y++) s += t[clamp(y, 0, h - 1) * w + x]; for (let y = 0; y < h; y++) { a[y * w + x] = s * inv; s += t[Math.min(h - 1, y + r + 1) * w + x] - t[Math.max(0, y - r) * w + x]; } }
    }
    return a;
  }
  // union of a shape swept along the sidewall direction (oblique thickness), minus nothing
  function sweep(R, draw, depthU) {
    return raster(R, 1, (g) => {
      const steps = Math.max(2, Math.ceil(depthU * Math.hypot(OBL[0], OBL[1]) * S / 0.6));
      for (let i = 1; i <= steps; i++) { const t = (depthU * i) / steps; g.save(); g.translate(OBL[0] * t, OBL[1] * t); draw(g); g.restore(); }
    });
  }

  // ---------------------------------------------------------------- compositing
  function shadowPass(R, mask, strength) {
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const s = mask[y * R.w + x] * strength; if (s <= 0.001) continue;
      const gi = (R.y0 + y) * W + R.x0 + x, k = 1 - s;
      accR[gi] *= k; accG[gi] *= k; accB[gi] *= k; accA[gi] = s + accA[gi] * k;
    }
  }
  function castShadow(R, draw, heightU, strength, extraBlurU = 0) {
    const m = raster(R, 1, (g) => { g.translate(SHD[0] * heightU, SHD[1] * heightU); draw(g); });
    blur(m, R.w, R.h, (0.22 * heightU + 0.7 + extraBlurU) * S);
    shadowPass(R, m, strength);
  }
  function contact(R, draw, strength, sigmaU = 1.1) {
    const m = raster(R, 1, (g) => { g.translate(0.25, 0.35); draw(g); });
    blur(m, R.w, R.h, sigmaU * S);
    shadowPass(R, m, strength);
  }
  function put(gi, r, g, b, a) {
    const k = 1 - a; accR[gi] = r * a + accR[gi] * k; accG[gi] = g * a + accG[gi] * k; accB[gi] = b * a + accB[gi] * k; accA[gi] = a + accA[gi] * k;
  }
  function lmPut(arr, gi, v, a) { arr[gi] = v * a + arr[gi] * (1 - a); }

  // ---------------------------------------------------------------- generic surface shader
  // hgt: height field (px). mat(i, x, y, ux, uy) fills M = {r,g,b, rough, diff, ao, emit:[r,g,b]?}
  const M = { r: 0, g: 0, b: 0, rough: 0.4, diff: 0, ao: 1, er: 0, eg: 0, eb: 0 };
  const E = [0, 0, 0];
  function surface(R, cov, hgt, mat, opts = {}) {
    const w = R.w;
    for (let y = 1; y < R.h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x, a = cov[i]; if (a <= 0.003) continue;
      let nx = (hgt[i - 1] - hgt[i + 1]) * 0.5, ny = (hgt[i - w] - hgt[i + w]) * 0.5;
      const inv = 1 / Math.sqrt(nx * nx + ny * ny + 1); nx *= inv; ny *= inv; const nz = inv;
      const ux = (R.x0 + x) / S + OX, uy = (R.y0 + y) / S + OY;
      M.ao = 1; M.diff = 0; M.er = M.eg = M.eb = 0;
      mat(i, x, y, ux, uy, nx, ny, nz);
      env(2 * nz * nx, 2 * nz * ny, 2 * nz * nz - 1, ux, uy, M.rough, E);
      const lam = Math.max(0, nx * K[0] + ny * K[1] + nz * K[2]);
      const dif = M.diff * (0.35 + 0.9 * lam);
      const gi = (R.y0 + y) * W + R.x0 + x;
      put(gi, (M.r * E[0] + dif) * M.ao + M.er, (M.g * E[1] + dif) * M.ao + M.eg, (M.b * E[2] + dif * 1.04) * M.ao + M.eb, a);
      if (opts.edges) {                                            // living-metal: chamfer facets by facing
        const sl = Math.hypot(nx, ny);
        const ch = opts.edges(i) * sstep(0.18, 0.5, sl);
        if (ch > 0.002) {
          const fx = nx / sl, fy = ny / sl;
          lmPut(lm.eN, gi, ch * Math.max(0, -fy) ** 1.4, a); lmPut(lm.eS, gi, ch * Math.max(0, fy) ** 1.4, a);
          lmPut(lm.eW, gi, ch * Math.max(0, -fx) ** 1.4, a); lmPut(lm.eE, gi, ch * Math.max(0, fx) ** 1.4, a);
        } else { lmPut(lm.eN, gi, 0, a); lmPut(lm.eS, gi, 0, a); lmPut(lm.eW, gi, 0, a); lmPut(lm.eE, gi, 0, a); }
      }
      if (opts.lm) for (const k of Object.keys(opts.lm)) lmPut(lm[k], gi, opts.lm[k](i), a);
    }
  }
  // sidewall shader: outward normal from the outside distance field; s = 0 at top edge, 1 at base
  function sidewall(R, sw, topCov, dout, depthU, base, rough, stripes = true) {
    const w = R.w, ol = Math.hypot(OBL[0], OBL[1]), ox = OBL[0] / ol, oy = OBL[1] / ol;
    for (let y = 1; y < R.h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x, a = sw[i] * (1 - topCov[i]); if (a <= 0.003) continue;
      let gx = dout[i + 1] - dout[i - 1], gy = dout[i + w] - dout[i - w]; const gl = Math.hypot(gx, gy) || 1; gx /= gl; gy /= gl;
      const proj = Math.max(0.2, gx * ox + gy * oy), s = clamp(dout[i] / (depthU * ol * S * proj), 0, 1);
      let nx = gx, ny = gy, nz = 0.32; const l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; const nzz = nz / l;
      const ux = (R.x0 + x) / S + OX, uy = (R.y0 + y) / S + OY;
      env(2 * nzz * nx, 2 * nzz * ny, 2 * nzz * nzz - 1, ux, uy, rough, E);
      const tool = stripes ? 1 + 0.07 * Math.sin(s * depthU * S * 2.1) : 1;
      const ao = (1 - 0.62 * Math.pow(s, 1.3)) * tool;
      const lam = Math.max(0, nx * K[0] + ny * K[1] + nzz * K[2]);
      const gi = (R.y0 + y) * W + R.x0 + x;
      put(gi, (base[0] * E[0] + base[3] * lam) * ao, (base[1] * E[1] + base[3] * lam) * ao, (base[2] * E[2] + base[3] * lam) * ao, a);
      for (const k of ['eN', 'eS', 'eW', 'eE']) lmPut(lm[k], gi, 0, a);
    }
  }

  // ---------------------------------------------------------------- text helpers (engraving masks)
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

  // ---------------------------------------------------------------- materials
  const STEEL = [0.74, 0.78, 0.83], BRASS = [0.96, 0.60, 0.20], BLACKENED = [0.036, 0.04, 0.047];
  // sparse handling scratches (decorative wear), deterministic
  function scratches(g, u0, v0, u1, v1, count, seed, maxLen) {
    const r = rng(seed);
    g.lineCap = 'round';
    for (let k = 0; k < count; k++) {
      const x = mix(u0, u1, r()), y = mix(v0, v1, r()), a = r() * Math.PI, l = maxLen * (0.25 + 0.75 * r());
      g.globalAlpha = 0.25 + 0.6 * r(); g.lineWidth = 0.12 + 0.18 * r();
      g.beginPath(); g.moveTo(x, y); g.quadraticCurveTo(x + Math.cos(a) * l * 0.5 + (r() - 0.5) * 2, y + Math.sin(a) * l * 0.5 + (r() - 0.5) * 2, x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke();
    }
    g.globalAlpha = 1;
  }

  // ================================================================= layers
  function dropShadow() {
    const R = { x0: 0, y0: 0, w: W, h: H };
    let m = raster(R, 1, (g) => { g.translate(3.4, 7.0); fillPath(MOUNT)(g); }); blur(m, W, H, 7 * S); shadowPass(R, m, 0.8);
    m = raster(R, 1, (g) => { g.translate(0.9, 1.6); fillPath(MOUNT)(g); }); blur(m, W, H, 1.5 * S); shadowPass(R, m, 0.6);
  }

  function chassis() {
    const R = region(-8, -8, 268, 312, 8), F = field(R, fillPath(MOUNT), true);
    const T = 12, sw = sweep(R, fillPath(MOUNT), T);
    sidewall(R, sw, F.cov, F.dout, T, [0.06, 0.068, 0.078, 0.004], 0.5);
    // laser-marked micro-engraving on the rims
    const marks = raster(R, 1, (g) => {
      g.fillStyle = '#fff';
      lineText(g, '01010000 01000110', 128, 2.75, 5.1, 1.05, 500);
      lineText(g, 'IF IT MATTERS, KEEP THE RECEIPT.', 128, 300.15, 3.9, 0.72, 500);
    });
    const marksB = blur(Float32Array.from(marks), R.w, R.h, 0.6);
    const scr = raster(R, 1, (g) => { scratches(g, -6, -6, 262, 304, 70, 77, 16); });
    const c = 2.7 * S, hgt = new Float32Array(R.w * R.h), wearN = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, d = F.din[i];
      const px = R.x0 + x, py = R.y0 + y;
      hgt[i] = Math.min(d, c) + 0.06 * noise(px / 0.9, py / 0.9) + 0.035 * noise(px / 2.6 + 9, py / 2.6) - 0.45 * marksB[i] - 0.25 * scr[i];
      wearN[i] = fbm(px / 16, py / 16);
    }
    surface(R, F.cov, hgt, (i, x, y, ux, uy) => {
      const px = R.x0 + x, py = R.y0 + y, d = F.din[i];
      const scale = fbm(px / 230 + 3, py / 230);                     // mill-scale mottling under the black oxide
      const mott = 1 + 0.32 * scale + 0.08 * noise(px / 7, py / 7);
      const wear = clamp((1 - sstep(0.2, 3.0, d)) * (0.35 + 0.95 * wearN[i]) + (1 - sstep(0, 2.0, Math.abs(d - c))) * clamp(0.1 + 0.7 * wearN[i], 0, 1) * 0.45, 0, 1) * 0.7;
      const mk = marks[i];
      M.r = mix(BLACKENED[0] * mott, 0.3, wear); M.g = mix(BLACKENED[1] * mott, 0.315, wear); M.b = mix(BLACKENED[2] * mott, 0.34, wear);
      M.rough = mix(0.62, 0.32, wear); M.diff = 0.006;
      const s = scr[i] * 0.55; if (s > 0) { M.r = mix(M.r, 0.16, s); M.g = mix(M.g, 0.17, s); M.b = mix(M.b, 0.185, s); }
      if (mk > 0) { M.r = mix(M.r, 0.045, mk); M.g = mix(M.g, 0.05, mk); M.b = mix(M.b, 0.055, mk); M.diff = mix(M.diff, 0.085, mk); M.rough = mix(M.rough, 0.85, mk); }
    }, { edges: (i) => (F.din[i] < c ? 0.55 : 0), lm: { eng: (i) => marks[i] * 0.6 } });
  }

  function screw(cxU, cyU, rHead, rSink, opts = {}) {
    const R = region(cxU - rSink - 1, cyU - rSink - 1, cxU + rSink + 1, cyU + rSink + 1, 4);
    const cov = new Float32Array(R.w * R.h), hgt = new Float32Array(R.w * R.h), hexD = new Float32Array(R.w * R.h), rr = new Float32Array(R.w * R.h);
    const rs = rSink * S, rh = rHead * S, hx = rHead * 0.42 * S, rot = opts.rot || 0.35;
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x + 0.5, py = R.y0 + y + 0.5;
      const dx = px - (cxU - OX) * S, dy = py - (cyU - OY) * S, r = Math.hypot(dx, dy); rr[i] = r;
      cov[i] = clamp(rs - r + 0.5, 0, 1);
      // hex socket: inside distance of a regular hexagon (apothem a)
      const ang = Math.atan2(dy, dx) - rot, a = hx * Math.cos(Math.PI / 6);
      const sec = ((ang % (Math.PI / 3)) + Math.PI / 3) % (Math.PI / 3) - Math.PI / 6;
      hexD[i] = a - r * Math.cos(sec);
      let h;
      if (r > rh) h = -(rs - r) * 0.9;                                   // countersink seat
      else h = -(rs - rh) * 0.9 - 0.55 + Math.min(0, (r - rh) * -0) + Math.min(0, (rh - r) - 0.9 * S * 0) ;
      if (r <= rh) { h = -(rs - rh) * 0.9 - 0.5 - Math.max(0, r - (rh - 0.45 * S)) * 1.0; if (!opts.rivet && hexD[i] > 0) h -= Math.min(hexD[i] * 2.2, 3.4); }
      if (opts.rivet) h = r < rh ? Math.sqrt(Math.max(0, 1 - (r / rh) ** 2)) * rh * 0.55 : -(rs - r) * 0.5;
      hgt[i] = h + 0.06 * Math.sin(r * 2.4);
    }
    surface(R, cov, hgt, (i) => {
      const r = rr[i];
      if (r > rh + 0.4) { M.r = 0.035; M.g = 0.04; M.b = 0.045; M.rough = 0.45; M.ao = 0.55 + 0.45 * sstep(rh, rs, r); return; }
      const sock = !opts.rivet && hexD[i] > -0.4;
      M.r = 0.52; M.g = 0.55; M.b = 0.58; M.rough = 0.32; M.ao = 1;
      if (sock) { M.r = 0.05; M.g = 0.055; M.b = 0.06; M.ao = 0.45 + 0.55 * (1 - sstep(0, 2.5, hexD[i])); }
    }, { edges: (i) => (rr[i] > rh - 0.5 * S && rr[i] < rh + 0.2 * S ? 0.5 : 0) });
  }

  function idPlates() {
    for (const [p, text] of [[LP1, 'lp1'], [LP2, 'lp2']]) {
      const R = region(text === 'lp1' ? 18 : 178, 259, text === 'lp1' ? 176 : 240, 296, 8);
      castShadow(R, fillPath(p), 3, 0.55, 0.3);
      contact(R, fillPath(p), 0.35, 0.6);
      const F = field(R, fillPath(p), true), T = 3, sw = sweep(R, fillPath(p), T);
      sidewall(R, sw, F.cov, F.dout, T, [0.16, 0.17, 0.18, 0.01], 0.35, false);
      const ink = raster(R, 1, (g) => {
        if (text === 'lp1') lineText(g, 'SOURCE / ARTIFACT / RECORD', 96, 279.15, 5.4, 1.05, 600);
        else { lineText(g, 'RECEIPTS', 208, 275.5, 4.5, 1.0, 600); lineText(g, 'OVER HYPE.', 208, 283.9, 4.5, 1.0, 600); }
      });
      const inkB = blur(Float32Array.from(ink), R.w, R.h, 0.7);
      const c = 0.95 * S, hgt = new Float32Array(R.w * R.h);
      for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
        const i = y * R.w + x, px = R.x0 + x, py = R.y0 + y;
        hgt[i] = Math.min(F.din[i], c) + 0.1 * noise(px / 70, py / 0.7) - 1.6 * inkB[i];
      }
      surface(R, F.cov, hgt, (i, x, y) => {
        const px = R.x0 + x, py = R.y0 + y, st = 1 + 0.06 * noise(px / 90, py / 0.9) + 0.03 * noise(px / 9, py / 40);
        M.r = 0.6 * st; M.g = 0.63 * st; M.b = 0.67 * st; M.rough = 0.3;
        const k = ink[i]; if (k > 0) { M.r = mix(M.r, 0.012, k); M.g = mix(M.g, 0.014, k); M.b = mix(M.b, 0.016, k); M.rough = mix(M.rough, 0.7, k); M.diff = 0.01 * k; }
      }, { edges: (i) => (F.din[i] < c ? 0.6 : 0), lm: { eng: (i) => ink[i] } });
    }
    screw(29, 277, 3.4, 4.25); screw(163, 277, 3.4, 4.25, { rot: 0.9 });
    screw(184.6, 266.6, 1.5, 1.9, { rivet: true }); screw(231.4, 287.4, 1.5, 1.9, { rivet: true });
  }

  function floor() {
    const R = region(CX - R_FLOOR - 2, CY - R_FLOOR - 2, CX + R_FLOOR + 2, CY + R_FLOOR + 2, 4);
    const cov = new Float32Array(R.w * R.h), hgt = new Float32Array(R.w * R.h), ru = new Float32Array(R.w * R.h);
    const cxp = (CX - OX) * S, cyp = (CY - OY) * S;
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x + 0.5, py = R.y0 + y + 0.5, r = Math.hypot(px - cxp, py - cyp), th = Math.atan2(py - cyp, px - cxp);
      ru[i] = r / S; cov[i] = clamp(R_FLOOR * S - r + 0.5, 0, 1);
      hgt[i] = 0.2 * Math.sin(r * 2 * Math.PI / 2.3) + 0.09 * noise(th * r / 60, r / 0.85) + 0.05 * noise(px / 1.2, py / 1.2);
    }
    surface(R, cov, hgt, (i, x, y) => {
      const px = R.x0 + x, py = R.y0 + y;
      const t = 1 + 0.12 * fbm(px / 140 + 40, py / 140);
      M.r = 0.085 * t; M.g = 0.094 * t; M.b = 0.105 * t; M.rough = 0.28;
      M.ao = 1 - 0.5 * Math.exp(-(R_FLOOR - ru[i]) / 6);
    });
  }

  function plate() {
    const R = region(5, 5, 256, 256, 8);
    const plateShape = (g) => { const p = new Path2D(PLATE); p.arc(CX, CY, R_FLOOR, 0, Math.PI * 2, true); g.fill(p, 'nonzero'); };
    // shadows of the plate onto the chassis (outer edge) and into the recess (rim)
    castShadow(R, fillPath(PLATE), 5, 0.6, 0.2);
    contact(R, fillPath(PLATE), 0.4, 0.7);
    {
      const m = raster(R, 1, (g) => { const p = new Path2D(); p.rect(-40, -40, 340, 340); p.arc(CX + SHD[0] * 4, CY + SHD[1] * 4, R_FLOOR, 0, Math.PI * 2, true); g.fill(p); });
      const clip = raster(R, 1, (g) => { g.beginPath(); g.arc(CX, CY, R_FLOOR + 0.5, 0, Math.PI * 2); g.fill(); });
      for (let i = 0; i < m.length; i++) m[i] *= clip[i];
      blur(m, R.w, R.h, 1.6 * S); for (let i = 0; i < m.length; i++) m[i] *= clip[i];
      shadowPass(R, m, 0.72);
    }
    const F = field(R, fillPath(PLATE), true);
    const T = 5, sw = sweep(R, fillPath(PLATE), T);
    sidewall(R, sw, F.cov, F.dout, T, [0.07, 0.078, 0.088, 0.004], 0.4);
    // recess wall (visible on the upper-left inside the rim)
    {
      const RD = 4, cxp = (CX - OX) * S, cyp = (CY - OY) * S, ol = Math.hypot(OBL[0], OBL[1]);
      const wR = region(CX - R_FLOOR - 1, CY - R_FLOOR - 1, CX + R_FLOOR + 1, CY + R_FLOOR + 1, 4);
      const ox = OBL[0] * RD * S, oy = OBL[1] * RD * S, rp = R_FLOOR * S;
      for (let y = 1; y < wR.h - 1; y++) for (let x = 1; x < wR.w - 1; x++) {
        const px = wR.x0 + x + 0.5, py = wR.y0 + y + 0.5, r0 = Math.hypot(px - cxp, py - cyp), r1 = Math.hypot(px - cxp - ox, py - cyp - oy);
        const a = clamp(rp - r0 + 0.5, 0, 1) * clamp(r1 - rp + 0.5, 0, 1); if (a <= 0.003) continue;
        let nx = (cxp - px) / r0, ny = (cyp - py) / r0;
        const proj = Math.max(0.15, nx * OBL[0] / ol + ny * OBL[1] / ol), s = clamp((rp - r0) / (RD * ol * S * proj), 0, 1);
        const nz = 0.3, l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; const nzz = nz / l;
        const ux = px / S + OX, uy = py / S + OY;
        env(2 * nzz * nx, 2 * nzz * ny, 2 * nzz * nzz - 1, ux, uy, 0.35, E);
        const ao = (1 - 0.55 * s) * (1 + 0.06 * Math.sin(s * 40));
        const gi = (wR.y0 + y) * W + wR.x0 + x;
        put(gi, 0.12 * E[0] * ao, 0.13 * E[1] * ao, 0.145 * E[2] * ao, a);
        for (const k of ['eN', 'eS', 'eW', 'eE']) lmPut(lm[k], gi, 0, a);
        lmPut(lm.seal, gi, 0.5, a);
      }
    }
    // engraving: seal arcs, registration ticks, witness marks
    const eng = raster(R, 1, (g) => {
      arcText(g, 'THE PROOF FOUNDRY™', 105.2, -Math.PI / 2, 1, 6.5, 1.3, 600);
      arcText(g, 'BUILD IT. PROVE IT. SHIP IT.', 111.4, Math.PI / 2, -1, 6.0, 1.0, 600);
      g.lineCap = 'butt';
      for (let deg = -30; deg <= 30; deg += 3) for (const side of [0, 180]) {
        const a = (deg + side) * Math.PI / 180, major = deg % 15 === 0;
        const r0 = major ? 102.6 : 104.9, r1 = major ? 111.6 : 109.4;
        g.lineWidth = major ? 0.8 : 0.45;
        g.beginPath(); g.moveTo(CX + r0 * Math.cos(a), CY + r0 * Math.sin(a)); g.lineTo(CX + r1 * Math.cos(a), CY + r1 * Math.sin(a)); g.stroke();
      }
      g.lineWidth = 0.6; g.beginPath(); g.moveTo(113, 14.2); g.lineTo(113, 18); g.moveTo(143, 14.2); g.lineTo(143, 18); g.stroke();
    });
    const engB = blur(Float32Array.from(eng), R.w, R.h, 0.75);
    const inlay = raster(R, 1, (g) => { g.fillRect(126.75, 7, 2.5, 6.4); g.fillRect(126.75, 242.6, 2.5, 6.4); g.fillRect(7, 126.75, 6.4, 2.5); g.fillRect(242.6, 126.75, 6.4, 2.5); });
    const seam = raster(R, 1, (g) => { g.lineWidth = 0.32; g.strokeRect(126.75, 7, 2.5, 6.4); g.strokeRect(126.75, 242.6, 2.5, 6.4); g.strokeRect(7, 126.75, 6.4, 2.5); g.strokeRect(242.6, 126.75, 6.4, 2.5); });
    const top = raster(R, 1, plateShape);
    const cP = 1.7 * S, cL = 0.9 * S, cxp = (CX - OX) * S, cyp = (CY - OY) * S, fcx = (-170 - OX) * S, fcy = (128 - OY) * S;
    const hgt = new Float32Array(R.w * R.h), ru = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x + 0.5, py = R.y0 + y + 0.5, r = Math.hypot(px - cxp, py - cyp), u = r / S; ru[i] = u;
      let h = cP - Math.max(0, cP - F.din[i]) - Math.max(0, cL - (r - R_FLOOR * S));
      h -= 1.7 * Math.max(0, 1 - Math.abs(u - R_GROOVE) / 0.8) + 0.6 * Math.max(0, 1 - Math.abs(u - 102.3) / 0.35);
      if (u < R_GROOVE) h += 0.16 * Math.sin(r * 2 * Math.PI / 2.0) + 0.05 * noise(Math.atan2(py - cyp, px - cxp) * r / 50, r / 0.8);
      else { const df = Math.hypot(px - fcx, py - fcy); h += 0.12 * Math.sin(df * 2 * Math.PI / 3.4) + 0.05 * noise(px / 1.1, py / 1.1); }
      hgt[i] = h - 2.0 * engB[i] - 0.35 * seam[i];
    }
    surface(R, top, hgt, (i, x, y) => {
      const u = ru[i], px = R.x0 + x, py = R.y0 + y, mott = 1 + 0.14 * fbm(px / 160 + 11, py / 160 + 5);
      if (u < R_GROOVE + 0.4) { M.r = 0.15 * mott; M.g = 0.162 * mott; M.b = 0.178 * mott; M.rough = 0.24; }
      else { M.r = 0.085 * mott; M.g = 0.093 * mott; M.b = 0.106 * mott; M.rough = 0.36; }
      const e = eng[i]; if (e > 0) { M.r = mix(M.r, 0.02, e * 0.85); M.g = mix(M.g, 0.022, e * 0.85); M.b = mix(M.b, 0.026, e * 0.85); M.rough = mix(M.rough, 0.6, e); }
      const b = inlay[i]; if (b > 0) { M.r = mix(M.r, BRASS[0] * 0.9, b); M.g = mix(M.g, BRASS[1] * 0.9, b); M.b = mix(M.b, BRASS[2] * 0.9, b); M.rough = mix(M.rough, 0.22, b); }
      if (seam[i] > 0) M.ao = 1 - 0.6 * seam[i];
      const d = F.din[i]; if (d < 2.5) { const wr = (1 - sstep(0.2, 2.5, d)) * 0.4; M.r = mix(M.r, 0.45, wr); M.g = mix(M.g, 0.47, wr); M.b = mix(M.b, 0.5, wr); }
    }, {
      edges: (i) => (F.din[i] < cP ? 0.7 : ru[i] < R_FLOOR + 0.9 ? 0.6 : 0),
      lm: { seal: (i) => (ru[i] < R_GROOVE + 0.6 ? 1 : 0), eng: (i) => eng[i], brass: (i) => inlay[i] * 0.8 },
    });
    for (const [x, y, r] of [[28, 28, 0.2], [228, 28, 0.9], [28, 228, 1.4], [228, 228, 0.6]]) screw(x, y, 4.3, 5.4, { rot: r });
  }

  function lettersAndBridge(opts) {
    const R = region(50, 50, 210, 214, 12);
    const P = letter(P_PATH), Fh = letter(F_PATH), B = letter(B_PATH);
    // --- P (satin-machined steel, brushed along x)
    castShadow(R, P, 10, 0.72); contact(R, P, 0.55, 0.9);
    const fP = field(R, P, true), swP = sweep(R, P, 10);
    sidewall(R, swP, fP.cov, fP.dout, 10, [0.32, 0.34, 0.37, 0.01], 0.32);
    // heat-affected zone of the two tack welds (bridge -> P): distance (units) from each bead's centre line
    const hazD = (ux, uy) => {
      let best = 99;
      for (const yy of [83.92, 111.28]) { const dx = Math.max(0, Math.max(131.6 - ux, ux - 136.8)), dy = uy - yy; best = Math.min(best, Math.hypot(dx, dy * 1.15)); }
      return best;
    };
    const cLet = 1.55 * S;
    let hgt = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x, py = R.y0 + y;
      hgt[i] = Math.min(fP.din[i], cLet) + 0.16 * noise(px / 110, py / 0.75) + 0.07 * noise(px / 30 + 7, py / 0.45);
    }
    surface(R, fP.cov, hgt, (i, x, y, ux, uy) => {
      const px = R.x0 + x, py = R.y0 + y, st = 1 + 0.07 * noise(px / 160, py / 1.2) + 0.035 * noise(px / 12, py / 60);
      M.r = STEEL[0] * st; M.g = STEEL[1] * st; M.b = STEEL[2] * st; M.rough = 0.24;
      const d = fP.din[i]; if (d < cLet + 1.2 && d > cLet - 1.2) { const k = 0.1 * (1 - Math.abs(d - cLet) / 1.2); M.r += k; M.g += k; M.b += k; }
      // temper colours around the tacks, nearest first: straw, bronze, violet, blue — then the untouched steel
      const hd = hazD(ux, uy) + 0.25 * noise(px / 9, py / 9);
      if (hd < 3.4) {
        const band = (c, w) => Math.exp(-((hd - c) * (hd - c)) / (2 * w * w));
        const straw = band(0.75, 0.35), bronze = band(1.35, 0.3), violet = band(1.95, 0.3), blue = band(2.6, 0.38);
        const k = 0.62 * (1 - sstep(2.6, 3.4, hd));
        const wsum = straw + bronze + violet + blue + 1e-6;
        const tr = (0.86 * straw + 0.62 * bronze + 0.42 * violet + 0.34 * blue) / wsum;
        const tg = (0.72 * straw + 0.42 * bronze + 0.28 * violet + 0.45 * blue) / wsum;
        const tb = (0.42 * straw + 0.24 * bronze + 0.5 * violet + 0.72 * blue) / wsum;
        const amt = k * Math.min(1, wsum);
        M.r = mix(M.r, tr, amt); M.g = mix(M.g, tg, amt); M.b = mix(M.b, tb, amt);
      }
    }, { edges: (i) => (fP.din[i] < cLet ? 1 : 0), lm: { faces: () => 0.6 } });

    // --- F (brushed brass, grain along y), lapped over the P as in the master's paint order
    castShadow(R, Fh, 12, 0.72); contact(R, Fh, 0.55, 0.9);
    const fF = field(R, Fh, true), swF = sweep(R, Fh, 12);
    sidewall(R, swF, fF.cov, fF.dout, 12, [0.3, 0.17, 0.06, 0.008], 0.32);
    hgt = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x, py = R.y0 + y;
      hgt[i] = Math.min(fF.din[i], cLet) + 0.16 * noise(px / 0.75, py / 110) + 0.07 * noise(px / 0.45, py / 30 + 3);
    }
    surface(R, fF.cov, hgt, (i, x, y) => {
      const px = R.x0 + x, py = R.y0 + y, st = 1 + 0.08 * noise(px / 1.2, py / 160 + 9) + 0.04 * noise(px / 60, py / 12);
      M.r = BRASS[0] * st; M.g = BRASS[1] * st; M.b = BRASS[2] * st; M.rough = 0.26;
      const d = fF.din[i]; if (d < cLet + 1.2 && d > cLet - 1.2) { const k = 0.12 * (1 - Math.abs(d - cLet) / 1.2); M.r += k; M.g += k * 0.8; M.b += k * 0.45; }
    }, { edges: (i) => (fF.din[i] < cLet ? 1 : 0), lm: { faces: () => 0.6, brass: () => 0.55 } });

    // --- bridge: steel key across the F stem, tacked to the P; brass record inlay along its lower edge
    castShadow(R, B, 3, 0.55, 0.2); contact(R, B, 0.4, 0.6);
    const fB = field(R, B, true), swB = sweep(R, B, 3);
    sidewall(R, swB, fB.cov, fB.dout, 3, [0.34, 0.36, 0.39, 0.01], 0.3, false);
    const inlay = raster(R, 1, (g) => { lt(g); g.fillRect(140.5, 101.2, 43.5, 3.0); });
    const inlaySeam = raster(R, 1, (g) => { lt(g); g.lineWidth = 0.5; g.strokeRect(140.5, 101.2, 43.5, 3.0); });
    const cB = 1.15 * S;
    hgt = new Float32Array(R.w * R.h);
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x, py = R.y0 + y;
      hgt[i] = Math.min(fB.din[i], cB) + 0.15 * noise(px / 100 + 4, py / 0.7) + 0.06 * noise(px / 25, py / 0.45) - 0.4 * inlaySeam[i];
    }
    surface(R, fB.cov, hgt, (i, x, y) => {
      const px = R.x0 + x, py = R.y0 + y, st = 1 + 0.07 * noise(px / 150 + 2, py / 1.1);
      M.r = STEEL[0] * 1.02 * st; M.g = STEEL[1] * 1.02 * st; M.b = STEEL[2] * 1.02 * st; M.rough = 0.22;
      const b = inlay[i]; if (b > 0) { M.r = mix(M.r, BRASS[0], b); M.g = mix(M.g, BRASS[1], b); M.b = mix(M.b, BRASS[2], b); M.rough = mix(M.rough, 0.2, b); }
      if (inlaySeam[i] > 0) M.ao = 1 - 0.5 * inlaySeam[i];
    }, { edges: (i) => (fB.din[i] < cB ? 1 : 0), lm: { bridge: (i) => 1, brass: (i) => inlay[i], faces: () => 0.6 } });

    // --- tack welds: short fillet beads where the bridge's top and bottom edges meet the P ring
    for (const yy of [83.92, 111.28]) weldBead(131.6, 136.8, yy, yy < 100 ? -1 : 1);
    
  }

  function weldBead(u0, u1, v, side) {
    const R = region(u0 - 2, v - 3, u1 + 2, v + 3, 4);
    const cov = new Float32Array(R.w * R.h), hgt = new Float32Array(R.w * R.h);
    const len = (u1 - u0) * S, wid = 1.45 * S, cx = ((u0 + u1) / 2 - OX) * S, cy = (v - OY) * S + side * 0.15 * S;
    for (let y = 0; y < R.h; y++) for (let x = 0; x < R.w; x++) {
      const i = y * R.w + x, px = R.x0 + x + 0.5, py = R.y0 + y + 0.5;
      const ax = (px - cx) / (len / 2), ay = (py - cy) / (wid / 2);
      const e = ax * ax * ax * ax * 0.6 + ax * ax * 0.4 + ay * ay;     // rounded-rectangle bead
      cov[i] = clamp((1 - e) * 6, 0, 1);
      const ripple = 0.35 * Math.cos(((px - cx) / S) * 2 * Math.PI / 0.85 + ay * ay * 2.2);
      hgt[i] = Math.sqrt(Math.max(0, 1 - e)) * wid * 0.42 + ripple * Math.max(0, 1 - e) + 0.12 * noise(px / 1.3, py / 1.3);
    }
    surface(R, cov, hgt, (i, x, y) => {
      const px = R.x0 + x, py = R.y0 + y, t = 0.5 + 0.5 * noise(px / 6, py / 6);
      M.r = mix(0.36, 0.42, t); M.g = mix(0.35, 0.37, t); M.b = mix(0.36, 0.33, t); M.rough = 0.42; M.diff = 0.01;
    }, { edges: () => 0.25 });
  }

  function hotTack() {
    const cx = 134.2, cy = 111.5;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const ux = x / S + OX, uy = y / S + OY; if (Math.abs(ux - cx) > 12 || Math.abs(uy - cy) > 10) continue;
      const dx = Math.max(0, Math.abs(ux - cx) - 2.4), dy = uy - cy, d2 = dx * dx + dy * dy * 1.6;
      const core = Math.exp(-d2 / (2 * 0.55 * 0.55)), halo = Math.exp(-d2 / (2 * 2.4 * 2.4));
      const i = y * W + x;
      hot[i * 4] = Math.min(1, core * 1.0 + halo * 0.95); hot[i * 4 + 1] = Math.min(1, core * 0.78 + halo * 0.32); hot[i * 4 + 2] = Math.min(1, core * 0.4 + halo * 0.07); hot[i * 4 + 3] = Math.min(1, core * 0.95 + halo * 0.55);
    }
  }

  // ================================================================= public
  function toImage(buf4, w, h, type, q) {
    const c = mkCanvas(w, h), g = c.getContext('2d'), id = g.createImageData(w, h);
    id.data.set(buf4); g.putImageData(id, 0, 0);
    return c.toDataURL(type, q);
  }
  function encodeBase(bg) {
    const out = new Uint8ClampedArray(W * H * 4);
    const tone = (v) => Math.pow(1 - Math.exp(-v * 2.1), 1 / 2.05) * 255;
    for (let i = 0; i < W * H; i++) {
      const a = accA[i];
      let r = 0, g = 0, b = 0;
      if (a > 0) { r = accR[i] / a; g = accG[i] / a; b = accB[i] / a; }
      if (bg) {                                                     // flatten onto a background for previews
        const [br, bgc, bb] = bg; const k = 1 - a;
        out[i * 4] = tone(r) * a + br * k; out[i * 4 + 1] = tone(g) * a + bgc * k; out[i * 4 + 2] = tone(b) * a + bb * k; out[i * 4 + 3] = 255;
      } else { out[i * 4] = tone(r); out[i * 4 + 1] = tone(g); out[i * 4 + 2] = tone(b); out[i * 4 + 3] = a * 255; }
    }
    return out;
  }
  function encodeMask(m, scale) {
    const w = Math.round(W * scale), h = Math.round(H * scale), out = new Uint8ClampedArray(w * h * 4);
    const fx = W / w, fy = H / h;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      let s = 0, n = 0;
      for (let yy = Math.floor(y * fy); yy < Math.min(H, Math.floor((y + 1) * fy)); yy++) for (let xx = Math.floor(x * fx); xx < Math.min(W, Math.floor((x + 1) * fx)); xx++) { s += m[yy * W + xx]; n++; }
      const o = (y * w + x) * 4; out[o] = 255; out[o + 1] = 255; out[o + 2] = 255; out[o + 3] = clamp(s / Math.max(1, n), 0, 1) * 255;
    }
    return { buf: out, w, h };
  }

  async function run(opts = {}) {
    const t0 = performance.now();
    await document.fonts.load('600 20px PlexMono'); await document.fonts.load('500 20px PlexMono');
    if (opts.markOnly) { OX = 47; OY = 45; UW = 166; UH = 170; } else { OX = -26; OY = -26; UW = 308; UH = 356; }
    W = opts.width || 1600; S = W / UW; H = Math.round(UH * S); N = W * H;
    accR = new Float32Array(N); accG = new Float32Array(N); accB = new Float32Array(N); accA = new Float32Array(N);
    hot = new Float32Array(N * 4);
    lm = {}; for (const k of ['eN', 'eE', 'eS', 'eW', 'bridge', 'brass', 'seal', 'eng', 'faces']) lm[k] = new Float32Array(N);
    rigTilt = opts.rigTilt || [0, 0];
    const times = {};
    const step = (name, fn) => { const t = performance.now(); fn(); times[name] = Math.round(performance.now() - t); };
    if (!opts.markOnly) {
      step('drop', dropShadow);
      step('chassis', chassis);
      step('idPlates', idPlates);
      step('floor', floor);
      step('plate', plate);
    }
    step('letters', () => lettersAndBridge(opts));
    if (opts.hot) step('hot', hotTack);
    // studio falloff: a soft pool of light from the upper left across the whole assembly
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const i = y * W + x; if (accA[i] <= 0) continue;
      const ux = x / S + OX, uy = y / S + OY, d2 = (ux - 55) * (ux - 55) + (uy - 30) * (uy - 30);
      const f = opts.markOnly ? 1.04 : 0.8 + 0.34 * Math.exp(-d2 / (2 * 200 * 200));
      accR[i] *= f; accG[i] *= f; accB[i] *= f;
    }
    const res = { W, H, S, times };
    const prev = encodeBase(opts.previewBg || [28, 35, 43]);
    res.preview = toImage(prev, W, H, 'image/png');
    res.crops = {};
    for (const c of opts.crops || []) {
      const x0 = Math.round((c.u0 - OX) * S), y0 = Math.round((c.v0 - OY) * S), x1 = Math.round((c.u1 - OX) * S), y1 = Math.round((c.v1 - OY) * S);
      const w = x1 - x0, h = y1 - y0, buf = new Uint8ClampedArray(w * h * 4);
      for (let y = 0; y < h; y++) buf.set(prev.subarray(((y0 + y) * W + x0) * 4, ((y0 + y) * W + x1) * 4), y * w * 4);
      res.crops[c.name] = toImage(buf, w, h, 'image/png');
    }
    if (opts.encode) {
      res.base = toImage(encodeBase(null), W, H, 'image/webp', opts.q || 0.9);
      res.basePng = opts.png ? toImage(encodeBase(null), W, H, 'image/png') : null;
      res.masks = {};
      if (opts.hot) { const b = new Uint8ClampedArray(N * 4); for (let i = 0; i < N * 4; i++) b[i] = hot[i] * 255; res.hot = toImage(b, W, H, 'image/webp', 0.9); }
      for (const k of opts.masks || []) { const m = encodeMask(lm[k], opts.maskScale || 0.5); res.masks[k] = toImage(m.buf, m.w, m.h, 'image/webp', 0.86); }
    }
    res.total = Math.round(performance.now() - t0);
    return res;
  }
  return { run, consts: { OX, OY, UW, UH, LT } };
})();
