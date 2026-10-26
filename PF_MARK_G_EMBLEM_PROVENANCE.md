# PF Mark G emblem and homepage fonts — asset provenance

The V5 homepage adds a raster rendering of PF Mark G (the hero emblem and the Inspect the Mark dialog), a small raster of the bare mark for the homepage header, eight light masks used only for the pointer highlight, and two self-hosted font families. This record covers those files. No existing asset is changed.

## Classification

`GENERATED_BRAND_RENDER`. The emblem is a deterministic, procedurally shaded rendering of the canonical PF Mark G contours, computed in a browser canvas by `scripts/pf-emblem/render-lib.js`. It is not a photograph of a manufactured part and not generated imagery. The machining, welds, fasteners and engraved text are fabrication-inspired design details. Engraved identifiers, including `01010000 01000110` (ASCII `PF`) and `SOURCE / ARTIFACT / RECORD`, are decorative. They are not release evidence, credentials or digests.

## Design authority

The approved design is the claude.ai artifact `https://claude.ai/artifact/Un7bvJd5GVMkPPXDcbDo1C` (Proof Foundry Homepage, V5; page version `1791926499-1806`). The page file read on 2026-10-13 has SHA-256 `d2f4f8172becc361ccdca4d18440716b5b64366013f35e3319410176c52cea7e`. Its bundled emblem, light-mask and font files are byte-identical to the files below.

One bundled V5 image is not shipped: the `weld-hot` overlay belongs to an optional "cooling" variant that V5 renders off by default.

The V5 raster header mark is shipped as `brand/emblem/PF_MARK_G_HEADER.webp` (owner ruling, 2026-10-13: preserve the approved V5 design and the canonical PF Mark G). Only the homepage header uses it; the build swaps it in for `index.html` alone. Every other page family, the footer and the favicon keep the shared vector micro mark `brand/PF_HEADER_MARK.svg`, and in forced-colors mode the homepage header falls back to that vector mark.

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
| `brand/emblem/PF_MARK_G_HEADER.webp` | 256 × 262 | 10,194 | Homepage header mark (bare PF Mark G) | `eda57d5d1abe27adcfd3d13de0b5ec0b4ffa2a2c3cb3c5d768bc7e2b843936f0` |
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

## Boundary

This record establishes source identity, canonical geometry and reproducibility. It is not visual approval and makes no claim about legibility at every size. No product capture, release record or existing brand file changes.
