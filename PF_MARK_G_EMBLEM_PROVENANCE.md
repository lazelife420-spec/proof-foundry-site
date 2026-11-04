# PF Mark G emblem and homepage fonts — asset provenance

The V5 homepage adds a raster rendering of PF Mark G (the hero emblem and the Inspect the Mark dialog), a small raster of the bare mark for the homepage header, eight light masks used only for the pointer highlight, and two self-hosted font families. This record covers those files. No existing asset is changed.

## Classification

`GENERATED_BRAND_RENDER`. The emblem is a deterministic, procedurally shaded rendering of the canonical PF Mark G contours, computed in a browser canvas by `scripts/pf-emblem/render-lib.js`. It is not a photograph of a manufactured part and not generated imagery. The machining, welds, fasteners and engraved text are fabrication-inspired design details. Engraved identifiers, including `01010000 01000110` (ASCII `PF`) and `SOURCE / ARTIFACT / RECORD`, are decorative. They are not release evidence, credentials or digests.

## Design authority

The approved design is the claude.ai artifact `https://claude.ai/artifact/Un7bvJd5GVMkPPXDcbDo1C` (Proof Foundry Homepage, V5; page version `1791926499-1806`). The page file read on 2026-10-13 has SHA-256 `d2f4f8172becc361ccdca4d18440716b5b64366013f35e3319410176c52cea7e`. Its bundled emblem, light-mask and font files are byte-identical to the files below.

One bundled V5 image is not shipped: the `weld-hot` overlay belongs to an optional "cooling" variant that V5 renders off by default.

**Superseded on 2026-11-04** (see "Round 3 Blender marks" below): the header now carries `PF_MARK_G_TI_HEADER.webp` on every page and the footer the `PF_MARK_G_TI_BADGE.webp` badge. Before that, the V5 raster header mark was shipped as `brand/emblem/PF_MARK_G_HEADER.webp` (owner ruling, 2026-10-13: preserve the approved V5 design and the canonical PF Mark G). Only the homepage header uses it; the build swaps it in for `index.html` alone. Every other page family, the footer and the favicon keep the shared vector micro mark `brand/PF_HEADER_MARK.svg`, and in forced-colors mode the homepage header falls back to that vector mark.

## Canonical geometry

`render-lib.js` embeds the three path strings of `brand/PF_MARK_G_MASTER.svg` verbatim (master SHA-256 `575d90ae4754216811634d6ab33a3b966b1932e335aff3a04317be03314239a1`) and places them with one transform, `translate(26.16 30.72) scale(.76)`. The seal, chassis, plates and engraving are drawn around them. The Inspect the Mark outlines in `pf-home.js` use the same three strings. `scripts/check-home-receipt-truth.ps1` checks both against the master file.

## Generator and reproduction

| File | Role | SHA-256 |
|---|---|---|
| `scripts/pf-emblem/render-lib.js` | Renderer, byte-identical to the one that produced the approved V5 files | `4cb3996029c123b0e1a4965a04a6d4cdef5835a77555caa01c7a32ada6c67550` |

`scripts/pf-emblem/render.html` is the original harness with its font URLs pointed at `assets/fonts/`. The original harness had SHA-256 `3b6522bed94eb6d04c9fa8e011989f35edba3be60d3826408250901d013bda42`. The font bytes are the same files. `scripts/pf-emblem/render-emblem.mjs` drives Chrome over CDP with the options used for V5, one fresh page load per run: `{ encode: true, hot: true, masks: [eN, eE, eS, eW, bridge, brass, seal, eng] }` for the emblem and masks, and `{ encode: true, markOnly: true, width: 256, q: 0.92 }` for the header mark. Noise is seeded (`20261013`). The script writes only to a new directory you name and compares every output with `brand/emblem/`.

```powershell
node scripts/pf-emblem/render-emblem.mjs <new-output-directory>
```

Reproduction is a manual step: no qualification suite re-renders the files, because WebP bytes depend on the Chrome build. The suites bind each shipped file to the SHA-256 recorded below, and `scripts/test-h9-homepage.ps1` also pins the header mark's SHA-256.

Recorded results (Windows 10): on 2026-10-13 with Chrome 155.0.8059.40, all 9 emblem and mask files were byte-identical to `brand/emblem/`. On 2026-10-13 with Chrome 155.0.8059.41, all 10 files, including the header mark, were byte-identical. Other Chrome builds may encode WebP differently. A byte difference on another build is expected and is not a geometry change.

## Shipped emblem files

The files are used as published: no resizing, recompression or editing. The light masks are alpha-only WebP at half resolution, applied as CSS masks over the emblem. They are hidden on touch devices, with reduced motion, with the site motion toggle off, and in forced-colors mode. In forced-colors mode the page shows the vector `brand/PF_MAKER_SEAL.svg` in place of the raster emblem.

| File | Dimensions | Bytes | Role | SHA-256 |
|---|---|---|---|---|
| `brand/emblem/PF_MARK_G_EMBLEM.webp` | 1600 × 1849 | 404,190 | Emblem (hero, dialog, loupe) | `8165fe7e753337ab6dfb969fff3f411ea13711165a66dab3c4998502b1d2031d` |
| `brand/emblem/PF_MARK_G_HEADER.webp` | 256 × 262 | 10,194 | Homepage header mark (bare PF Mark G), superseded 2026-11-04 | `eda57d5d1abe27adcfd3d13de0b5ec0b4ffa2a2c3cb3c5d768bc7e2b843936f0` |
| `brand/emblem/LIGHT_NORTH.webp` | 800 × 925 | 20,690 | Upward-facing chamfers | `e9b7a6295bc1d60eab2657034bf4b24adef74c21fb11d2c2b7b9a4b9d2902f86` |
| `brand/emblem/LIGHT_EAST.webp` | 800 × 925 | 18,818 | Right-facing chamfers | `3e1b2cf1874b67e1962746ed77a03876c7c0513466fb1e858d5ca3d5c2121e16` |
| `brand/emblem/LIGHT_SOUTH.webp` | 800 × 925 | 22,852 | Downward-facing chamfers | `35bd9b2b391db13061d7c56d2be4d5b20774fbb3d2176155aeb0c7670ecdf28e` |
| `brand/emblem/LIGHT_WEST.webp` | 800 × 925 | 20,006 | Left-facing chamfers | `6466d6bd6caa191e93f0a2a548a3c9253eaaca2fb7e7e1be49aa18b928e7733a` |
| `brand/emblem/LIGHT_BRIDGE.webp` | 800 × 925 | 2,096 | Bridge key | `98a83dbf67c569b70de617dd2d15ad35905ea0e4931b1ad9146b1bdaf70ee2e9` |
| `brand/emblem/LIGHT_BRASS.webp` | 800 × 925 | 2,584 | Brass F face | `8d78c45404713371a4dfc48de551fb0c9030d1a47baf9829f57b7fb8a3f6f8ec` |
| `brand/emblem/LIGHT_SEAL.webp` | 800 × 925 | 10,466 | Seal ring | `ccb84ea6f1fb8a68caf32050d3943bf1baa9584c72c7fac3024956ec1d1b7f3f` |
| `brand/emblem/LIGHT_ENGRAVING.webp` | 800 × 925 | 12,090 | Engraved text shadow | `cff39514aacd8cd4e3d2ffd6299bd273e6e8648f0a8a76373390648d2ea71e92` |

## Fonts

These are the Latin subsets of the WOFF2 files the V5 artifact bundled, served from `/assets/fonts/` so the homepage makes no third-party font request. The copyright and licence URL below are read from each file's name table. The full SIL Open Font License 1.1 ships beside them in `assets/fonts/OFL-Archivo.txt` and `assets/fonts/OFL-IBM-Plex-Mono.txt`. The renderer uses the same Plex files for the engraved text.

| File | Family, version | Bytes | Copyright | SHA-256 |
|---|---|---|---|---|
| `assets/fonts/archivo-latin.woff2` | Archivo 2.001 (variable weight 400–900, width 62–125%) | 90,104 | Copyright 2020 The Archivo Project Authors | `e3a28eade21a900c7155a247757f4b2834c07bb7ef07ad7efa55cebaac1e8f5e` |
| `assets/fonts/ibm-plex-mono-latin-400.woff2` | IBM Plex Mono 2.3 Regular | 14,708 | Copyright 2017 IBM Corp. | `08949f728dc52d528e69b1667d15c89a5686a4ee9a296ff90983985f99c380f7` |
| `assets/fonts/ibm-plex-mono-latin-500.woff2` | IBM Plex Mono 2.3 Medium | 14,888 | Copyright 2017 IBM Corp. | `01d285447409c8a588692162439a038b8cbd7871309ee20267b0d2d91c6e8e22` |
| `assets/fonts/ibm-plex-mono-latin-600.woff2` | IBM Plex Mono 2.3 SemiBold | 15,620 | Copyright 2017 IBM Corp. | `0d1f0b8d0722224e32e9f28261bdc86c79115be73444ae5eceb73976a1bcdf83` |
| `assets/fonts/ibm-plex-mono-latin-700.woff2` | IBM Plex Mono 2.3 Bold | 14,908 | Copyright 2017 IBM Corp. | `4f84d86cfd060f4ded334358ff8a4c81d4db2ed5addd568359d693f44a87765a` |

## R3 hero plaque (adopted 2026-10-15)

On 2026-10-15 the owner adopted a path-traced re-rendering of the same plaque, called R3, after an A/B review. The
homepage hero, the Inspect the Mark dialog and its loupe now use the R3 files below. The V5 files listed above stay in
the repository unchanged and are no longer referenced by the homepage.

**Classification:** `GENERATED_BRAND_RENDER`. R3 is an offline path trace of geometry built from the three canonical
path strings of `brand/PF_MARK_G_MASTER.svg` (master SHA-256 `575d90ae…39a1`), placed with the same transform
`translate(26.16 30.72) scale(.76)`.
- The letters are extruded from those paths. Their chamfers are cut inside the outline, so the silhouette is unchanged.
- The bridge is a separate raised part. The inscriptions are engraved relief rasterised from `assets/fonts` IBM Plex Mono.
- The lighting is the proof chain's light rig.
- As with V5, the machining, fasteners and engraved text are fabrication-inspired design details, not evidence.

**Geometry check (run).** The render's letter-face silhouette was compared with the canonical paths rasterised at
1600 × 1849:

| Measure | Result |
|---|---|
| IoU | 0.99992 |
| Mean boundary distance | 0.023 px |
| p99 boundary distance | 0.10 px |
| Hausdorff distance | 3.23 px, only where the raised bridge meets the F notch |
| Chamfer containment | no chamfer pixel outside the outline beyond 0.05 px antialiasing |

An independent reviewer confirmed it.

**Render provenance.**
- **Run:** headless Chrome 155.0.8059.41 (WebGL2, ANGLE D3D11) on Windows 10; final run `r3-final4`.
- **Passes:** beauty pass at 2048 spp; AOV passes at 256 spp. Seeds are deterministic.
- **Encoding:** WebP through Chrome's canvas encoder, as for V5 (emblem q 0.90, masks q 0.86). Masks are downsampled
  exactly as `render-lib.js`'s `encodeMask`.
- **Source records:** the renderer sources are not part of the public site. They and their hashes are kept with the
  2026-10-15 review package: `SOURCES.sha256` SHA-256 `cebd13045d650e768ebaffc4794cdafdbcc7cd73864765bdb373b6760b326fb7`,
  and scene `scene-r3.json` `54d5211b57d423ee5f651eae353be60826c2ca786c95a82268b49ac043b9787b`.

| File | Dimensions | Bytes | Role | SHA-256 |
|---|---|---|---|---|
| `brand/emblem/PF_MARK_G_EMBLEM_R3.webp` | 1600 × 1849 | 237,692 | Emblem (hero, dialog, loupe) | `900e4e6a5470a94c333fc8107594aca96025ca1a8e890fef2f37ed75e149f871` |
| `brand/emblem/LIGHT_NORTH_R3.webp` | 800 × 925 | 24,768 | Upward-facing chamfers | `89452f826bfafa0066a59bfb6b8ff587154d740852dffd0fcf78a34293c1bc16` |
| `brand/emblem/LIGHT_EAST_R3.webp` | 800 × 925 | 35,042 | Right-facing chamfers | `670ae36126605241e590d4ee431322922f65b032ce0b04d1f4a0c90f1da4ee8f` |
| `brand/emblem/LIGHT_SOUTH_R3.webp` | 800 × 925 | 32,916 | Downward-facing chamfers | `91ac2ab80de3267e3dd2fa24fd02b9450ba3beec2014f869f7feb0e521c7a197` |
| `brand/emblem/LIGHT_WEST_R3.webp` | 800 × 925 | 33,494 | Left-facing chamfers | `b81a80bd709dccf5a1872538eef951817e748ce3913996e92ce40724c421144b` |
| `brand/emblem/LIGHT_BRIDGE_R3.webp` | 800 × 925 | 2,740 | Bridge key | `0746da3cb4fb9addc7379aa1daa4cb181a432798fc56fd7a34895a3fd6789a1c` |
| `brand/emblem/LIGHT_BRASS_R3.webp` | 800 × 925 | 5,036 | Brass F face | `296a2a1e0c31cab725ed5f86da8a0e00cbecbb6c045c9dd84b7b3b8dbaad47a7` |
| `brand/emblem/LIGHT_SEAL_R3.webp` | 800 × 925 | 12,176 | Seal ring | `6775bf65c599e22ad31f8131cd0bc729bc05c55722fcbcbb1f85083aeafd3050` |
| `brand/emblem/LIGHT_ENGRAVING_R3.webp` | 800 × 925 | 13,554 | Engraved text shadow | `2fcfabcd24653d81c12f788b82b68845f74f817d5c78767c966d017eff72ca88` |

**Known limit:** on the shadow side the letter sidewalls render nearly black. A later re-render may lift them.

## Round 3 titanium hero emblem (adopted 2026-11-03)

On 2026-11-03 the owner asked for the maker's mark to be "etched into titanium and carbon fibre … part of the background", with "the original details and intricacy … like original but even better", and chose the gold F. The homepage hero now shows the original R3 plaque's assembly rebuilt as part of the titanium hero plate. The Inspect the Mark dialog and its loupe still use the R3 files above, and the dialog says so.

**Classification:** `GENERATED_BRAND_RENDER`. It is an offline Cycles render (Blender 5.2.3) made by `scripts/render-round2/ti_emblem.py`.
- **Geometry:** the letters are extruded from the three path strings of `brand/PF_MARK_G_MASTER.svg` (master SHA-256 `575d90ae…39a1`), read at run time, under R3's own transform `translate(26.16 30.72) scale(.76)`.
- **Layout:** the original's units, parts and proportions (the assembly frame x −8..264, y −8..306).
- **Masks:** the legends, ticks, witness marks, inlays and temper colours are drawn by `scripts/render-round2/emblem_masks.py`. It reproduces `render-lib.js`'s `glyphRun`, `lineText` and `arcText` verbatim and uses the `assets/fonts` IBM Plex Mono files.
- **Materials:**
  - the seal floor is a pocket filled with 2×2 twill carbon;
  - the ring band is turned titanium;
  - the P is brushed titanium with temper colours round its two tack welds;
  - the F is brushed gold titanium nitride;
  - the bridge is a titanium key with its brass record inlay;
  - the two identification plates are inlaid titanium with engraved legends, held by two screws and two rivets.
- **The plate face:** its flat face is a holdout, so the titanium field (`ti_plate.py --part field`, `MATERIAL_PROVENANCE.md`) shows through. The emblem has no edge of its own.
- **Not evidence:** as with V5 and R3, the machining, welds, fasteners and engraved text are fabrication-inspired design details, not evidence.

**Living metal:** the pointer highlight runs again on the hero, and its light is rendered.
- **How:** `ti_emblem.py --glint N|E|S|W` renders the hero emblem as shipped (256 samples), plus one low, cool distant light (20° up, 10° wide) from that side of the plate. `scripts/render-round2/emblem_glints.py` takes `glint − base`, premultiplied, so the transparent plate face adds nothing. That difference is what the light adds: the chamfers, ring walls, gold edges and turned band that face it. It is kept off the etched legends and the plates' engraving (`emblem_masks.py`'s `mask-etch` and `mask-id-ink`, grown by 1 px): their floors are drawn in the emblem while the plate around them is the page's own titanium, which the light does not reach, so a glint there would wash the letters out.
- **On the page:** pf-home.js sets `--lN/--lE/--lS/--lW` from the side of the seal the pointer is on. Each pass is added over the emblem with `mix-blend-mode: plus-lighter` at that opacity, so two neighbouring passes blend into a light from in between.
- **What went:** the CSS gradients, the R3 masks and the seal, bridge, brass and engraving layers. Reduced motion, motion off and forced colours still hide every layer.

| File | Dimensions | Bytes | Role | SHA-256 |
|---|---|---|---|---|
| `brand/emblem/PF_MARK_G_TI_GLINT_N.webp` | 920 × 1062 | 132,598 | Light from the north side | `40aa5075ff7d4f7dc0b53ed8fd57ced3ce8f4b8481e0935204c100ee2b4d6369` |
| `brand/emblem/PF_MARK_G_TI_GLINT_E.webp` | 920 × 1062 | 135,416 | Light from the east side | `27ff4c49e33b561e0877bdf0be1a82791cb0afbe8adf92108b2bbb3a62c0164f` |
| `brand/emblem/PF_MARK_G_TI_GLINT_S.webp` | 920 × 1062 | 127,850 | Light from the south side | `d107ded56446a629904fa6c22907200d733f6ba7d4f15702f9ce1a01ef37ac5d` |
| `brand/emblem/PF_MARK_G_TI_GLINT_W.webp` | 920 × 1062 | 136,426 | Light from the west side | `c4d204f1779a258b2b0fd69c5658d875a3586630dafe4b4a9f3152da0a3aa9ef` |

The passes are encoded from 8-bit straight-alpha PNGs (alpha the brightest channel, so a pass only ever adds light, even where a browser cannot blend it) with ffmpeg libwebp at quality 88, `yuva420p`.

**Masters:** the 16-bit master and the masks are hashed in `scripts/render-round2/MASTERS.sha256`. Encoding is WebP with ffmpeg libwebp: the 2x master as rendered at quality 88, and the 1x Lanczos-downscaled at quality 90, both with alpha.

| File | Dimensions | Bytes | Role | SHA-256 |
|---|---|---|---|---|
| `brand/emblem/PF_MARK_G_TI_920.webp` | 920 × 1062 | 62,722 | Titanium hero emblem, 2x | `044dc8eaf9cdfd6cfc0a6f366d9ae3dc29c8d11ef0f11cc303a8a9fe26d565b9` |
| `brand/emblem/PF_MARK_G_TI_460.webp` | 460 × 531 | 32,674 | Titanium hero emblem, 1x | `86fa2e101e0cfd10403afcc2cc6dfa22a9dc48d83acce2bfc759bca28e56d268` |

## Round 3 Blender marks: the header, Inspect the Mark and the footer (adopted 2026-11-04)

On 2026-11-04 the owner chose to re-render the header mark and the Inspect the Mark plaque in Blender, to match the titanium hero, and to render the footer logo as a machined badge.
- **Supersedes:** the 2026-10-13 decision to keep the V5 header render, and the R3 WebGL plaque adopted on 2026-10-15. `PF_MARK_G_HEADER.webp` and `PF_MARK_G_EMBLEM_R3.webp` stay in the repository, no longer referenced.
- **Classification:** `GENERATED_BRAND_RENDER`, offline Cycles renders (Blender 5.2.3). They come from the hero emblem's own geometry, legends and materials (`ti_emblem.py`, the sections above), in one of three modes:
  - `--mode plaque`: the hero emblem on an opaque titanium coupon (u −18..274, v −18..322; a 1.5 u 35° chamfer, inset evenly; four flush titanium socket screws). It is framed in R3's own frame (u −26..282, v −26..330, 1600 × 1849), so pf-home.js's pins, notes and loupe stay registered. It is rendered at the hero's own scale (`--width 520.8823529 --scale 3.0717054`), so the weave, brushing and blast keep their size against the letters. The dialog's notes and intro now describe the titanium mark.
  - `--mode mark`: the P, F, bridge and tack welds alone, standing on the head plate, centred in its frame (u 46.7..209.3, v 44.8..211.2). 50 × 51 CSS px, with a contact shadow from a 55° light inside the image (a lift of about 1–2 CSS px), so the CSS drop shadow is gone. The vector micro mark stays for forced colours.
  - `--mode badge`: the same P, F and bridge on a small black-oxide plate (u 43..213, chamfer inset evenly), centred in its frame (u 37..219), the footer logo at 34 × 34 CSS px, with the same 55° contact light. The inline vector micro mark stays for forced colours.
- **Shadows:** each mode is rendered in two passes and combined by `sprite_compose.py`: `--pass obj` (the shadow catcher a holdout) and `--pass shadow` (the overhead dome and the soft contact light, no rim band). `sprite_compose.py` drops the one stray shadow-catcher pixel Cycles leaves at each canvas's top-right corner.
- **Settings:** 256 samples. The plaque is `--width 520.8823529 --scale 3.0717054`. The header is rendered at 512 × 524 and the badge at 204 × 204, each Lanczos-downscaled to its size. Encoding is ffmpeg libwebp with alpha (quality 88 for the plaque, 90 for the others). The masters and passes are in `MASTERS.sha256`.

| File | Dimensions | Bytes | Role | SHA-256 |
|---|---|---|---|---|
| `brand/emblem/PF_MARK_G_TI_PLAQUE.webp` | 1600 × 1849 | 178,942 | Inspect the Mark plaque | `4f2b9987ae54e53c38422ad43647df0157d55e2c61dc71ed0f8214b70440f83f` |
| `brand/emblem/PF_MARK_G_TI_HEADER.webp` | 256 × 262 | 9,020 | Header mark, every page | `d38f7992058ca349534d3858dc761985666605a30b523c3a5523aa0679976f87` |
| `brand/emblem/PF_MARK_G_TI_BADGE.webp` | 102 × 102 | 2,728 | Footer badge, every page | `231664b5c9755b764ed25dfbe82cfd67c1b774d11ea17a053ff0b60398568af6` |

## Boundary

This record establishes source identity, canonical geometry and reproducibility. It is not visual approval and makes no claim about legibility at every size. No product capture, release record or existing brand file changes.
