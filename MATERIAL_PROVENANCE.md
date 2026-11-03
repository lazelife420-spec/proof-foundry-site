# Material provenance

Website material layers for Home and the shared non-product rooms (About, Support, Proof Standard, Proof, Truth, Truth Files, Founders, Roadmap, Products directory, 404). Product pages and per-product Truth File records are not changed, except their footer. Since Round 2 every page shares the same welded mill-steel footer base, weld and rail.

All four web assets live in `brand/material/`. They were derived locally by `scripts/derive-material-assets.mjs` (Chrome canvas, headless, isolated profile, WebP encoder). No third-party or stock images were used.

| Asset | Size | Bytes | SHA-256 | Source | Transform |
|---|---|---|---|---|---|
| `PF_MILL_STEEL_GROUND_v1.webp` | 1150 × 1920 | 94,640 | `d7367096eeddb04f4229533670631c4738afe9d16436a8f9195fb0c5cd2604fc` | `brand/PF_WELDED_STEEL_v1.webp` (studio-generated 2026-10-05, see FOUNDRY_PREMIUM_DESIGN_CANDIDATE.md; SHA-256 `f3b3a676ae9c8529d147dc2e69842d5cc355032b8987dd03d6dfd19e2d8e3582`, unchanged) | crop x 0–1150 (removes the authored TIG seam at x ≈ 1250 so the ground carries no weld where the page has no join), vertical mirror for an edge-free vertical repeat, quality 0.78 |
| `PF_STAINLESS_BRUSHED_v1.webp` | 1536 × 1024 | 168,392 | `2963072480e003f07e3c4d3088380d6bb4e5925c1170001548fdacc570a6a470` | image generated for this site 2026-11-02 (source PNG SHA-256 `ed1c0dd5aea62166f5e54a9707753b5bc21b7b078615bc79d2a520e2e2535096`) | re-encode, quality 0.80 |
| `PF_PAPER_ARCHIVAL_v1.webp` | 1024 × 683 | 47,592 | `e82da24d6f4c14f2cbd9dca85e6febc0315688a5044e4f4309d15297f9a44410` | image generated for this site 2026-11-02 (source PNG SHA-256 `c5f8df706e5cba9be4c6b31c2f5cf926e2da5931230ad66dee697461418dd9ff`) | scale 0.6667, quality 0.82 |
| `PF_BUTT_WELD_SEAM_v1.webp` | 1164 × 98 | 24,560 | `adbb56db1aaf062689d3591ecd4cc7a189a4e06b4b605a33d4b3375a769bdc3e` | image generated for this site 2026-11-02 (source PNG SHA-256 `b96aaffd9602f0a8e71e1ca18dbf07c4447e7f147bf0226763d9f16625126455`) | crop y 150–500, horizontal mirror, scale 0.28, quality 0.84; displayed at 499 × 42 CSS px (2.3× source density) |

Total added payload: 335,184 bytes. A page downloads only the layers it uses: Home, About (paper intro) and Truth Files ≈ 0.33 MB (all four); Proof Standard and Support ≈ 0.29 MB (no paper). All are CSS backgrounds with a matching solid `background-color`, so they cause no layout shift and the first frame shows the same dark tone before decoding.

Generation prompts (verbatim, constraints included):

- Stainless: photorealistic straight-on macro of a flat No. 4 brushed stainless panel; continuous horizontal brushing; one or two barely visible fingerprints, short scuffs along the grain, a faint water spot; one soft light from the upper left; no edges, screws, welds, rust, text, chrome gloss or bloom.
- Weld: photorealistic straight-on macro of a horizontal butt weld joining two blackened carbon-steel plates; slightly irregular rippled bead; narrow heat-affected zone (straw/bronze to blue-gray); a little fine spatter; very restrained light-brown oxidation in a few patches along the upper toe where moisture collects; soft upper-left light; no sparks, glow, heavy rust, bolts or text.
- Paper: photorealistic straight-on macro of heavy archival uncoated cotton paper, pale cream (≈ #EEECE3), subtle fiber, very low contrast, upper-left light; no folds, stains, edges, writing or text.

Source PNGs are retained outside the published site with the review evidence. Generated images are original works created for The Proof Foundry; they reproduce no third-party image.

## Material logic

One light source, upper left. Rolled mill steel carries the load (Home is shaded least). Brushed stainless marks surfaces people handle: the five stage plates, the Proof Standard inspection frame, the Support service panel, the Truth Files clamp bar and the About room. Archival paper carries records. The central chassis plate is 1380 px wide, so its recessed joints with the side plates fall outside the 1320 px reading rail; About's stainless cladding sheets are 920 px tall with recessed butt joints. The only weld is the butt weld where the footer base meets the chassis. Movable keys and chain links hang on pins and clevises. Light oxidation appears only at the lower corners of Home's carbon-steel hero plate, where it rests on the chassis ledge. Forced colours remove the page ground, the footer base and weld, and all Round 2 hardware. The header steel and the paper behind About's intro and the Founders receipt still keep their material in forced colours, because those resets lose on specificity. That is a known open item; Round 2 did not touch it.

## Round 2 rendered hardware

The Round 2 hardware in `assets/round2/` is rendered, not photographed or generated. Each piece is a procedural Blender scene. It was rendered with Cycles under one shared studio: a warm softbox upper left, a cool rim strip at right, a dim top bounce and a near-black world. There are no downloaded textures, HDRIs, models, add-ons or stock images. The owner's lifting-chain photo was used only as a visual reference for the material. The scene scripts are committed in `scripts/render-round2/`.

- **Blender:** 5.2.3 LTS (build `e13b728c6880`), the portable zip from `https://download.blender.org/release/Blender5.2/blender-5.2.3-windows-x64.zip`.
  - SHA-256 `723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb`, matching blender.org's published `.sha256` file.
  - `blender.exe` carries a valid Authenticode signature from the Blender Foundation.
  - It was run headless with `--factory-startup`. No installer was run, and no registry or PATH change was made.
- **Render settings:** Cycles CPU, OpenImageDenoise, AgX Medium High Contrast, 16-bit PNG masters at 2x, 128 to 160 samples.
- **Encoding:** WebP with ffmpeg libwebp. The chain bases use quality 80 to 82; sprites and UI parts use 85.
- **Reproduction is close, not byte-exact.** Fresh renders of the key, coupler and panel parts differ from the shipped masters by a mean of 0.15 to 1.2 per channel out of 255. Screw-socket angles come from a seeded random, and the denoiser is not bit-exact.

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `chain-desktop-2800.webp` | 2800 × 862 | 57,110 | `d3d01a3c4b9f68d8396282ba7178cf2289b61240600b09dd3fdfda0edc76b370` | `chain_scene.py --scene desktop --mode base`, 160 samples |
| `chain-desktop-1400.webp` | 1400 × 431 | 22,080 | `b8f871a8dc53b45dd334f1899de2d60a7c83e269dd24651cc53faa83ed5eca7c` | the same master, Lanczos to 1400 |
| `chain-mobile-320.webp` | 320 × 1270 | 17,912 | `d0ad530c2165ef0ec47be3143c25736a3a64493b2cf9f527bb195e6653d80338` | `chain_mobile.py --scene mobile --mode base`, 160 samples |
| `carriage-d-s0.webp` … `-s4.webp` | 416 × 220 | 6,564 / 8,008 / 10,868 / 12,442 / 14,918 | `3d50258707f7d0be…`, `ce9978c24c48a8c5…`, `5dc9722f47c22f9c…`, `45267add5b439839…`, `38f4389ca1881fdb…` | `chain_scene.py --mode carriage --stage 0…4`, transparent, 128 samples |
| `plate-d-p0.webp` … `-p4.webp` | 346–347 × 196 | 5,854 / 6,442 / 6,602 / 7,132 / 6,984 | `36566e4e4a02f08f…`, `9baa8b3b4c169383…`, `fbf5aeb193910146…`, `55b6fdfae61834d2…`, `cb93a4c7614ce552…` | `chain_scene.py --mode plate --stage 0…4` (that stage's plate pressed), transparent, 128 samples |
| `carriage-m-s0.webp` … `-s4.webp` | 120 × 135–136 | 4,472 / 3,104 / 2,672 / 2,456 / 2,474 | `02895568135d64d3…`, `b1b77125dc82b823…`, `4c52ca352056a60b…`, `f57f2935d28e5160…`, `1bcbdb605810d440…` | `chain_mobile.py --mode carriage --stage 0…4`, transparent, 128 samples |
| `seal-mount-raised-920.webp` | 920 × 1046 | 15,686 | `8f9efd92f6a7fcba2b09e9e25e2991a0673844e892346a109c3acf5625fad913` | `seal_scene.py --option raised`, 128 samples. The emblem itself is not rendered; it stays `brand/emblem/PF_MARK_G_EMBLEM_R3.webp`, unchanged |
| `seal-mount-raised-460.webp` | 460 × 523 | 5,770 | `2e8396aa80ce69383be0f51ee9d3a76e30817b25eb443b16d6d21bca22879e54` | the same master at 1x |
| `key-rest.webp` | 400 × 128 | 3,260 | `30426b7ff762b10adb656a112d5aef85bb1b0026358eec73d5addd2d271a9c55` | `ui_parts.py --part key-rest`, transparent |
| `key-current.webp` | 400 × 128 | 3,434 | `0cd463500d4c5f23b085d291beafe761d3d20adc8bd20450dbdeb98aed8ce6ee` | `ui_parts.py --part key-current`, transparent |
| `coupler.webp` | 140 × 64 | 1,938 | `39925529bb58980722b8e114dbfaabc6a9e97680041c7c0a6da5e43f1e3632eb` | `ui_parts.py --part coupler`, transparent |
| `coupler-v.webp` | 64 × 200 | 2,500 | `f4156db39a54e143ed9975199cb9542d33c1b75dcb2b9db995c62325d1bafe92` | `ui_parts.py --part coupler-v`, transparent, 128 samples. This is the drop link for the snaking key layouts below 1240 px |
| `footer-panel.webp` | 480 × 360 | 2,320 | `66528eb91c5747f10c97b5a4cf8290f564adde83166f09b3b4eb57b0b99f2740` | `ui_parts.py --part footer-panel` |
| `footer-rail-3840.webp` | 3840 × 104 | 31,182 | `5c4f4cf4f5ba8fbf284764efa7eab3435a66dc97d9eef47d4c4b5f86a810e11e` | `ui_parts.py --part footer-rail`: one 1920 × 64 CSS px strip, transparent, with its shadow cast onto a catcher plane, 128 samples. Cropped to the top 104 rows (the shadow is fully faded by then), quality 80 |
| `footer-rail-1920.webp` | 1920 × 52 | 10,340 | `be22f5c6f9b6d8532ae56e55dc515743b8e9835f215042fc47eb24fc9cc2ac15` | the same master and crop, Lanczos to 1x, quality 85 |

The footer rail replaces Factory's earlier 280 px tile, which never rendered: its CSS was invalid. It is the restrained bolted upper rail that ChatGPT recommended on CP-0183 for owner review. It is a 22 px blackened bar whose top edge tucks under the butt weld that joins the footer base to the chassis. Eight socket screws at 240 px pitch, symmetric about the page centre, fasten it into the base. It is rendered whole at 1920 px, so it has no tile seams.

The chain base downloads only at its own breakpoint: desktop 1x or 2x, or mobile. The selected stage's sprites load with the page, and the others load lazily. Every Round 2 layer is `aria-hidden` and is not drawn in forced colours.

Command form, from the repository root:

```powershell
blender -b --factory-startup -P scripts/render-round2/chain_scene.py -- --scene desktop --mode base --scale 2 --samples 160 --out <master.png>
blender -b --factory-startup -P scripts/render-round2/ui_parts.py -- --part coupler-v --scale 2 --samples 128 --out <master.png>
ffmpeg -i <master.png> -c:v libwebp -quality 85 <asset.webp>
```

The 16-bit masters are kept outside the published site with the review evidence. Their SHA-256 values are in `scripts/render-round2/MASTERS.sha256`.

- The chain, mobile, seal, `key-current`, `coupler-v` and `footer-rail` masters were rendered after the last edit to their script.
- The `key-rest`, `coupler` and `footer-panel` masters predate a later `ui_parts.py` edit, which changed `key-current`. Fresh renders from the committed script match them within the tolerance given above.
