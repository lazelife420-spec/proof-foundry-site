# Material provenance

Website material layers for Home and the shared non-product rooms (About, Support, Proof Standard, Proof, Truth, Truth Files, Founders, Roadmap, Products directory, 404). Product pages and per-product Truth File records are not changed, except their footer. Since Round 2 every page shares the same welded mill-steel footer base, weld and rail.

The three web assets below live in `brand/material/`. They were derived locally by `scripts/derive-material-assets.mjs` (Chrome canvas, headless, isolated profile, WebP encoder). No third-party or stock images were used. The butt weld is no longer a material layer: it is rendered hardware, `assets/round2/weld-seam-*.webp` (see Round 2 rendered hardware).

| Asset | Size | Bytes | SHA-256 | Source | Transform |
|---|---|---|---|---|---|
| `PF_MILL_STEEL_GROUND_v1.webp` | 1150 × 1920 | 94,640 | `d7367096eeddb04f4229533670631c4738afe9d16436a8f9195fb0c5cd2604fc` | `brand/PF_WELDED_STEEL_v1.webp` (studio-generated 2026-10-05, see FOUNDRY_PREMIUM_DESIGN_CANDIDATE.md; SHA-256 `f3b3a676ae9c8529d147dc2e69842d5cc355032b8987dd03d6dfd19e2d8e3582`, unchanged) | crop x 0–1150 (removes the authored TIG seam at x ≈ 1250 so the ground carries no weld where the page has no join), vertical mirror for an edge-free vertical repeat, quality 0.78 |
| `PF_STAINLESS_BRUSHED_v1.webp` | 1536 × 1024 | 168,392 | `2963072480e003f07e3c4d3088380d6bb4e5925c1170001548fdacc570a6a470` | image generated for this site 2026-11-02 (source PNG SHA-256 `ed1c0dd5aea62166f5e54a9707753b5bc21b7b078615bc79d2a520e2e2535096`) | re-encode, quality 0.80 |
| `PF_PAPER_ARCHIVAL_v1.webp` | 1024 × 683 | 47,592 | `e82da24d6f4c14f2cbd9dca85e6febc0315688a5044e4f4309d15297f9a44410` | image generated for this site 2026-11-02 (source PNG SHA-256 `c5f8df706e5cba9be4c6b31c2f5cf926e2da5931230ad66dee697461418dd9ff`) | scale 0.6667, quality 0.82 |

Retired on 2026-11-03, at the owner's request ("real weld beads"): `PF_BUTT_WELD_SEAM_v1.webp`.

- **What it was:** an image generated for this site, 1164 × 98, 24,560 bytes, SHA-256 `adbb56db1aaf062689d3591ecd4cc7a189a4e06b4b605a33d4b3375a769bdc3e`, source PNG `b96aaffd9602f0a8e71e1ca18dbf07c4447e7f147bf0226763d9f16625126455`.
- **How it was shown:** cropped, mirrored and repeated at 499 × 42 CSS px, so the same bead and a mirror seam came back every 499 px.
- **What replaced it:** the rendered `weld-seam-2560.webp` / `weld-seam-5120.webp`. The file and its `--pf-mat-weld` token are removed.

Total payload of the three layers: 310,624 bytes. A page downloads only the layers it uses: About (paper intro) and Truth Files ≈ 0.31 MB (all three); Proof Standard and Support ≈ 0.26 MB (no paper). Home loads none of them since Round 3 (see "Round 3 rendered ground, shadows and light"): every layer it used is overridden by a Blender render. All are CSS backgrounds with a matching solid `background-color`, so they cause no layout shift and the first frame shows the same dark tone before decoding.

Generation prompts (verbatim, constraints included):

- Stainless: photorealistic straight-on macro of a flat No. 4 brushed stainless panel; continuous horizontal brushing; one or two barely visible fingerprints, short scuffs along the grain, a faint water spot; one soft light from the upper left; no edges, screws, welds, rust, text, chrome gloss or bloom.
- Weld (retired tile): photorealistic straight-on macro of a horizontal butt weld joining two blackened carbon-steel plates; slightly irregular rippled bead; narrow heat-affected zone (straw/bronze to blue-gray); a little fine spatter; very restrained light-brown oxidation in a few patches along the upper toe where moisture collects; soft upper-left light; no sparks, glow, heavy rust, bolts or text.
- Paper: photorealistic straight-on macro of heavy archival uncoated cotton paper, pale cream (≈ #EEECE3), subtle fiber, very low contrast, upper-left light; no folds, stains, edges, writing or text.

Source PNGs are retained outside the published site with the review evidence. Generated images are original works created for The Proof Foundry; they reproduce no third-party image.

## Material logic

One light source, upper left. Rolled mill steel carries the load (Home is shaded least). Brushed stainless marks surfaces people handle: the five stage plates, the Proof Standard inspection frame, the Support service panel, the Truth Files clamp bar and the About room. Archival paper carries records. The central chassis plate is 1380 px wide, so its recessed joints with the side plates fall outside the 1320 px reading rail; About's stainless cladding sheets are 920 px tall with recessed butt joints. The only weld is the butt weld where the footer base meets the chassis. Movable keys and chain links hang on pins and clevises. Iron oxide appears at the lower corners of Home's carbon-steel hero plate, where it rests on the chassis ledge, and on the proof chain's forged links and clevises (the rust pass below). The pins, the stainless carriage and the stage plates stay clean. Forced colours remove the page ground, the footer base and weld, and all Round 2 hardware. The header steel and the paper behind About's intro and the Founders receipt still keep their material in forced colours, because those resets lose on specificity. That is a known open item; Round 2 did not touch it.

## Round 2 rendered hardware

The Round 2 hardware in `assets/round2/` is rendered, not photographed or generated. Each piece is a procedural Blender scene. It was rendered with Cycles under one studio layout: a warm softbox upper left, a cool rim strip at right, a dim top bounce and a near-black world. The seal uses its own copy of that layout: a smaller key, an added contact-shadow key, a weaker reflection card and -1.8 EV exposure. There are no downloaded textures, HDRIs, models, add-ons or stock images. The owner's lifting-chain photo was used only as a visual reference for the material. The scene scripts are committed in `scripts/render-round2/`.

- **Blender:** 5.2.3 LTS (build `e13b728c6880`), the portable zip from `https://download.blender.org/release/Blender5.2/blender-5.2.3-windows-x64.zip`.
  - SHA-256 `723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb`, matching blender.org's published `.sha256` file.
  - `blender.exe` carries a valid Authenticode signature from the Blender Foundation.
  - Every master was rendered with that portable `blender.exe`: `pf-site-main-finish-design-options/tools/blender/blender-5.2.3-windows-x64/blender.exe`, SHA-256 `e546b2a0d81ae19bd5b306b668733102d91d23db2e2be02d68b7ecbe548af0a1`. It was run headless with `--factory-startup`.
  - The portable zip needs no installer. Separately, Blender 5.2.3 was also installed system-wide on this workstation on 2026-11-02 at 16:32. That install was a winget MSI, which added an uninstall entry, `C:\Program Files\Blender Foundation\` and a `.blend` association, with no PATH change. It was not used for these renders.
- **Render settings:** Cycles CPU, OpenImageDenoise, AgX Medium High Contrast, 16-bit PNG masters at 2x. Samples per asset are in the table: 160 for the chain bases, 128 for the sprites, seal, drop link and rail, and 64 (the script default) for the key, coupler and panel parts.
- **Encoding:** WebP with ffmpeg libwebp, with the quality given per row. The 1x copies are Lanczos-downscaled from the 2x master. Encoding the hashed masters reproduces the shipped files.
- **Reproduction is exact.** Re-rendering `key-rest` and `coupler` from the committed script at their own 64 samples gives pixel-identical images: a difference of 0. Screw-socket angles come from a seeded random, so they repeat. The PNG files differ only in metadata.

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `chain-desktop-2800.webp` | 2800 × 862 | 67,590 | `f8807e0581fa534d8d3abdc8d9450aaa10175b0e629d665beb79891c60b7185e` | `chain_scene.py --scene desktop --mode base` (with the rust pass), 160 samples, quality 80 |
| `chain-desktop-1400.webp` | 1400 × 431 | 25,752 | `e8cd24d123b581e189ca6284f86675abed210204824354fda77ba514dc020d78` | the same master, Lanczos to 1400, quality 82 |
| `chain-mobile-320.webp` | 320 × 1270 | 18,738 | `5a2f4de130cce7d3ab94e05ba8452f81209686abd2dadc4d5872c19555b91eb8` | `chain_mobile.py --scene mobile --mode base` (with the rust pass and the phone anchor correction), 160 samples, quality 82 |
| `carriage-d-s0.webp` … `-s4.webp` | 416 × 220 | 6,564 / 8,008 / 10,868 / 12,442 / 14,918 | `3d50258707f7d0be…`, `ce9978c24c48a8c5…`, `5dc9722f47c22f9c…`, `45267add5b439839…`, `38f4389ca1881fdb…` | `chain_scene.py --mode carriage --stage 0…4`, transparent, 128 samples, quality 85 |
| `plate-d-p0.webp` … `-p4.webp` | 346–347 × 196 | 5,528 / 6,060 / 6,414 / 6,844 / 6,824 | `f8c7689971a44fa1…`, `3d40ea781ab4a549…`, `0afcda7644c6a5bb…`, `04378cd7b7f5a0fc…`, `5cd1d6d5e567c2da…` | `chain_scene.py --mode plate --stage 0…4` (that stage's plate pressed), transparent, 128 samples, quality 85 |
| `carriage-m-s0.webp` … `-s4.webp` | 120 × 135–136 | 4,472 / 3,104 / 2,672 / 2,456 / 2,474 | `02895568135d64d3…`, `b1b77125dc82b823…`, `4c52ca352056a60b…`, `f57f2935d28e5160…`, `1bcbdb605810d440…` | `chain_mobile.py --scene mobile --mode carriage --stage 0…4`, transparent, 128 samples, quality 85 |
| `seal-mount-raised-920.webp` | 920 × 1046 | 15,686 | `8f9efd92f6a7fcba2b09e9e25e2991a0673844e892346a109c3acf5625fad913` | `seal_scene.py --option raised`, 128 samples, quality 82. The emblem itself is not rendered; it stays `brand/emblem/PF_MARK_G_EMBLEM_R3.webp`, unchanged |
| `seal-mount-raised-460.webp` | 460 × 523 | 5,770 | `2e8396aa80ce69383be0f51ee9d3a76e30817b25eb443b16d6d21bca22879e54` | the same master, Lanczos to 460, quality 82 |
| `key-rest.webp` | 400 × 128 | 3,260 | `30426b7ff762b10adb656a112d5aef85bb1b0026358eec73d5addd2d271a9c55` | `ui_parts.py --part key-rest`, transparent, 64 samples, quality 85 |
| `key-current.webp` | 400 × 128 | 3,434 | `0cd463500d4c5f23b085d291beafe761d3d20adc8bd20450dbdeb98aed8ce6ee` | `ui_parts.py --part key-current`, transparent, 64 samples, quality 85 |
| `coupler.webp` | 140 × 64 | 1,938 | `39925529bb58980722b8e114dbfaabc6a9e97680041c7c0a6da5e43f1e3632eb` | `ui_parts.py --part coupler`, transparent, 64 samples, quality 85 |
| `coupler-v.webp` | 64 × 200 | 2,500 | `f4156db39a54e143ed9975199cb9542d33c1b75dcb2b9db995c62325d1bafe92` | `ui_parts.py --part coupler-v`, transparent, 128 samples, quality 85. This is the drop link for the snaking key layouts below 1240 px |
| `footer-panel.webp` | 480 × 360 | 2,320 | `66528eb91c5747f10c97b5a4cf8290f564adde83166f09b3b4eb57b0b99f2740` | `ui_parts.py --part footer-panel`, 64 samples, quality 85 |
| `footer-rail-3840.webp` | 3840 × 104 | 31,182 | `5c4f4cf4f5ba8fbf284764efa7eab3435a66dc97d9eef47d4c4b5f86a810e11e` | `ui_parts.py --part footer-rail`: one 1920 × 64 CSS px strip, transparent, with its shadow cast onto a catcher plane, 128 samples. Cropped to the top 104 rows (the shadow is fully faded by then), quality 80 |
| `footer-rail-1920.webp` | 1920 × 52 | 10,340 | `be22f5c6f9b6d8532ae56e55dc515743b8e9835f215042fc47eb24fc9cc2ac15` | the same master and crop, Lanczos to 1x, quality 85 |
| `weld-seam-5120.webp` | 5120 × 84 | 32,264 | `7cf4080ee34bbbcd3c1a878c56b281d6749a64a918e45d0940e430d5c9e7673e` | `ui_parts.py --part weld-seam`: one 2560 × 42 CSS px strip, opaque, 160 samples, seed 1183, quality 82 |
| `weld-seam-2560.webp` | 2560 × 42 | 14,030 | `582573d0ddb5bfb8b9155c6bf67950ce86414e0811b0fa645ddbf5da15239cc8` | the same master, Lanczos to 1x, quality 84 |

The stage plates use their own `plate-stainless` material, a lighter and partly diffuse brushed stainless. Factory's plates shared the fully metallic carriage stainless. Under the black studio world that rendered their faces at a luminance of about 103 to 118, and the engraved labels reached only 3.1 to 3.8:1. The re-rendered faces measure about 159 to 167, which puts the label ink at 6.6 to 7.2:1 on every plate. The chain base and the five pressed-plate sprites were re-rendered for this. The carriage sprites are unchanged.

The footer rail replaces Factory's earlier 280 px tile, which never rendered: its CSS was invalid. It is the restrained bolted upper rail that ChatGPT recommended on CP-0183 for owner review. It is a 22 px blackened bar whose top edge tucks under the butt weld that joins the footer base to the chassis. Eight socket screws at 240 px pitch, symmetric about the page centre, fasten it into the base. It is rendered whole at 1920 px, so it has no tile seams.

The chain base downloads only at its own breakpoint: desktop 1x or 2x, or mobile. Every sprite is lazy. The selected stage's sprite for the layout on screen is fetched when the chain initialises, and another stage's sprite is fetched when that stage is chosen. Each is swapped in only once decoded. The other breakpoint's sprites are never fetched. Every Round 2 layer is `aria-hidden` and is not drawn in forced colours.

**Rust pass and rendered weld, 2026-11-03.** The owner asked for visible, physically believable rust on the chain and for real weld beads.

- **Rust: materials only.** The forged-link and forged-clevis materials gained procedural iron oxide (`add_rust` in `chain_scene.py`); geometry, camera and lights are unchanged.
  - **Where it forms:** in crevices (ambient occlusion), inside the bends and in a ring just outside each contact (baked from the same distances as the wear map), at the pinned joints and on downward faces. Each part also carries general patches in its own blotch field.
  - **What stays clean:** the bearing contacts stay polished, because rust is faded out by the wear map. The pins, stainless and plates stay clean.
  - **Mobile:** the rust scales with the mobile chain (factor 95.08/208.6).
  - **Phone anchors:** on the phone only, the clevis oxide is drawn as broken patches about 6 px across in the 2x image, over dark stained steel, with the crevice term largely removed. At phone size that term filled each pin seat and yoke with one even colour. The desktop graph is unchanged and re-renders pixel-identically.
  - **Scope:** rust is on only in the base and sample renders. The carriage and plate sprite modes build the same material graph as before, so the sprites are unchanged: plate 2 and carriage 2 re-render pixel-identical at 16 bits.
- **Weld: a heightfield bead** (`ui_parts.py --part weld-seam`). Crescent ripples are laid in runs that end in craters and restart proud over them, with a wetted toe, porosity, spatter, and heat tint in the carbon-steel order.
  - **Light:** a level area strip along the seam, a dim fill and a soft sun from the upper left. Brightness is flat along the seam within 9%.
  - **Repeat:** the ends meet inside a crater, so the image repeats only on screens wider than 2560 px, and the join reads as one more restart.
  - **CSS:** the strip keeps its mask and 34% darkening. It draws a plain 1x `url()` first, then `image-set()`, as the footer rail does.
- **Review:** the owner review, with same-camera before/after close-ups and measurements, is in `review/main-finish/rust-weld-pass/` (local, untracked).

The previous V5 chain renders (`assets/proof-chain/`) are no longer referenced by any page. They are kept on purpose, so a rollback to the earlier chain needs no asset restore.

Command form, from the repository root:

```powershell
blender -b --factory-startup -P scripts/render-round2/chain_scene.py -- --scene desktop --mode base --scale 2 --samples 160 --out <master.png>
blender -b --factory-startup -P scripts/render-round2/ui_parts.py -- --part coupler-v --scale 2 --samples 128 --out <master.png>
ffmpeg -i <master.png> -c:v libwebp -quality 85 <asset.webp>
```

The 16-bit masters are kept outside the published site with the review evidence. Their SHA-256 values are in `scripts/render-round2/MASTERS.sha256`.

Each master was rendered by the branch of the committed script that draws it, and that branch has not changed since the render.

- **The rust pass:** it changed only the base branches of `chain_scene.py` and `chain_mobile.py` and added the `weld-seam` part to `ui_parts.py`. The chain bases and the weld were rendered from the committed scripts.
- **Sprites:** the carriage and plate sprites render the same pixels from the committed script. The shipped carriage masters date from Factory's earlier copy of the scene, whose carriage branch is identical.
- **Other ui_parts edits:** earlier edits to `ui_parts.py` touched only other parts (`key-current`, `coupler-v`, `footer-rail`). The two pixel-identical re-renders above confirm it for `key-rest` and `coupler`.

## Round 3 titanium hero plate

On 2026-11-03 the owner asked for the Home hero plate to "blend in … titanium or something", and approved this plate from stills. It is rendered with Cycles, like the Round 2 hardware, using the same Blender build.

**The titanium studio:** both scripts share `scripts/render-round2/ti_common.py`, so the plate face and the emblem cut into it read one tone everywhere. Its lights are all distant:
- an overhead dome within 8° of the zenith;
- one sun from the chain studio's key direction (azimuth 32° left of image-up, elevation 18°, angle 6°);
- a low band toward that key that lights only the edge breaks facing it.

**The material:** bead-blasted grade 2 titanium, from noise run on a torus of the tile's period, so the field wraps exactly.

**The field tile:**
- **Tone:** mean sRGB 51, brightest 99.9th-percentile pixel 60. That keeps the hero's lightest small text above AA contrast.
- **Overhang:** the rendered plane runs past the image, so the pixel filter never darkens the tile's edges. A first render had a dark 1 px border that showed as a seam at every repeat.
- **1x tile:** resampled from a 3 × 3 tiling, so the filter wraps too.
- **Encoding:** ffmpeg libwebp. The fine blast grain survives at quality 92, not at 80.

The frame is a 9-slice of the plate's edge. The flat face is a holdout, so the field shows through it.

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `assets/round3/ti-field-1280.webp` | 1280 × 1280 | 97,970 | `9287235737d87aa78bca4fad5ceebc2ca5551dd2ceed0007f3a48cd0d0bb7514` | `ti_plate.py --part field --scale 2`, 384 samples, no denoise, quality 92; repeated at 640 CSS px from the plate's padding box |
| `assets/round3/ti-field-640.webp` | 640 × 640 | 17,528 | `fa81c3f2f89f5ba0c41a422c32a61658bd856056e86efda58698cfaeb9237178` | the same master, Lanczos to 1x from a 3 × 3 tiling, quality 95 |
| `assets/round3/ti-frame-384.webp` | 384 × 384 | 6,312 | `39b081f9cdb0647f08c29c9445f0f0941e7131b11aac68b7a7b8f9bec8447d53` | `ti_plate.py --part frame --scale 2`: 1.5 px shadow gap, 2 px 35° polished chamfer, four ISO 10642 M4 titanium countersunk screws 22 px in; transparent, 256 samples, quality 88; sliced 96 / 48 px |

The emblem cut into the plate is recorded in `PF_MARK_G_EMBLEM_PROVENANCE.md`.

## Round 3 head plate

On 2026-11-03 the owner asked for the navigation to be "way better, real built" and chose a bolted head plate that scrolls with the page.

**The plate:** the header and the key bank are one black-oxide steel plate.
- The face is a tiling field (`ti_plate.py --part oxide-field`), mean sRGB 40, one step darker than the titanium hero.
- The edge (`ti_plate.py --part head-frame --margin 24`) has:
  - a 2 px 35° chamfer;
  - four M4 socket cap screws in counterbores;
  - the plate's shadow on the chassis, in a 24 px margin so the key light's shadow fades out inside the art (its outer 8 device px fade to zero, where Cycles' pixel filter leaves a faint last column).
- The edge is cropped into a top half for the header and a bottom half for the key bank.

**The keys and chain** (`head_parts.py`) keep the Round 2 canvases, bores and registration, so every CSS offset still lands a pin in its bore:
- brushed stainless bezels and brushed dark caps;
- the current key's bead-blasted stainless cap latched 4 px down, and a pressed state;
- 3.2 px ear tongues, so the chain truly threads: the end links pass down through the bores and round the ear tips;
- a clevis anchor at each end of the chain: sideways from 701 px, above and below the end keys on phones.

**Rendering:** all parts use the titanium studio, whose low band reaches the horizon here so the bezels' machined edges catch the key light. The key light casts no shadow in these sprites; their contact shadows come from the overhead dome.

**Contrast:** the lit key's legend (#11191e) reads 6.5:1 against the darkest pixel of its cap.

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `assets/round3/oxide-field-1024.webp` | 1024 × 1024 | 28,170 | `92baf251ad86937c4bf5abacfbc08ed2b6cf9cf75ea37830496a78bde98e69ee` | `ti_plate.py --part oxide-field --scale 2`, 384 samples, no denoise, quality 92; repeated at 512 CSS px |
| `assets/round3/oxide-field-512.webp` | 512 × 512 | 9,374 | `9fc8ab47e5fa7e38435ff509e9a333bd575ec2e98c78dfb016530ebb37d38f59` | the same master, Lanczos to 1x from a 3 × 3 tiling, quality 95 |
| `assets/round3/head-frame-top.webp` | 368 × 200 | 8,152 | `a727a6f732016493e9fb77456dc944bde305e479dd8191c434268b0cc23e944c` | `ti_plate.py --part head-frame --margin 24 --scale 2`, 128 samples, outer 8 device px faded: rows 0–200 of the 368 × 848 master, quality 90 |
| `assets/round3/head-frame-bottom.webp` | 368 × 248 | 11,028 | `66e67992178e53ec9d0176d64750292c6cfad8bcf16c6a14d841719738561251` | the same master, rows 600–848, quality 90 |
| `assets/round3/key-rest.webp` | 400 × 128 | 5,206 | `4a6aeea34aaa1c3548ada68a8303588e7ab12dbda133b2d3ca8392bf9e56ca50` | `head_parts.py --part key-rest --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/key-current.webp` | 400 × 128 | 5,598 | `10ec6e29e9570ea41f35dd6cad70e003c572aea3af0e127b8f9d2cff29ca023e` | `head_parts.py --part key-current --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/key-pressed.webp` | 400 × 128 | 5,314 | `de5afee47e8bad79746d863367279cd0ba3a2c7cd4e4dd0c7f5f78b38a2ddde2` | `head_parts.py --part key-pressed --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/coupler.webp` | 140 × 64 | 2,682 | `1e82a938da1ce7ed3647c04b5c9092c0da4836995af276a59d9ff96fd01936d6` | `head_parts.py --part coupler --rim 2.5`: three links threaded through the ear bores, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/drop.webp` | 64 × 200 | 3,308 | `10f4c1e3200eb8e16bf03d46281cbc021913a5c445fc77e31885025aae1306cd` | `head_parts.py --part drop --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/anchor-l.webp` | 72 × 64 | 1,676 | `172e79847f420014e4f2709612e039b5f4bb09c43528ee5ac38736d6f94c316f` | `head_parts.py --part anchor-l --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/anchor-r.webp` | 72 × 64 | 1,768 | `5eb9ef9535ccc68dc83225565f96f5de373cf184efb8785e2f4996a5095e09ad` | `head_parts.py --part anchor-r --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/anchor-t.webp` | 48 × 80 | 1,472 | `57b397754db663e3e47865f69529a05ca3faac28a88ca2d750f19c9dd08a842f` | `head_parts.py --part anchor-t --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/anchor-b.webp` | 48 × 80 | 1,520 | `6cd67f260db6d0e8e78dce74c36c700b7e80a040e2a490aef3c8a2c45e88f352` | `head_parts.py --part anchor-b --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |

The Round 2 key, coupler and drop-link files stay in `assets/round2/` and are no longer referenced.

## Round 3 Home hardware

On 2026-11-03 the owner asked that on Home "each background each screen should feel like it's there for a reason". The remaining CSS-drawn hardware on Home is now rendered, from the same stock as the head plate and the hero:
- **The proof machine's tray and the phone carrier** are black-oxide plates of the head plate's stock: the tiled oxide face and the head frame's full edge (four M4 socket cap screws, chamfer, shadow), 9-sliced. They replace a CSS navy slab and a CSS carrier, each with gradient screws.
- **The phone stage plates** are rendered brushed stainless with two lapped M3 socket screws on washers; the selected plate carries the current key's champagne witness line, inlaid. They replace CSS gradient plates.
- **Paper is clamped:** a brushed stainless bar, an M4 socket cap screw on a washer through each end, holds the top edge of the inspection record and of the studio-principle sheet. The principle is now a sheet on the chassis instead of a band across it.
- **The records links** are titanium index plates of the hero's stock: the tiled titanium field, and the hero frame's build at 96 CSS px with M2.5 countersunk titanium screws.
- **Home's buttons** (Browse Products, Visit Support, the inspection toggle) are the nav keys' build without the chain ears. The primary button carries the latched key's bead-blasted stainless cap. The toggle latches down while it is pressed.

**Rendering:** the same titanium studio as the rest of Round 3. Faces that a 3- or 9-slice stretches (the clamp bar, the stage plate) take a constant brush tangent (`ti_common.brush(tangent=True)`). Without it the Principled BSDF fans the sheen out from each part's centre, which a slice would stretch into a visible sweep. The buttons keep the keys' materials unchanged.

**Contrast**, measured on the 16-bit masters against the single worst pixel anywhere on the face under the text (the whole tile, for the tiled faces):

| Text | Surface | Ratio |
|---|---|---|
| #11191e | primary cap, rest / pressed | 6.4:1 / 6.3:1 |
| #e6e2d8 | button cap | 12.0:1 |
| #9aa0a2 | locked cap (`button-locked`), disabled toggle | 6.8:1 |
| #192026 | stage plate | 6.6:1 |
| #d3dadd | oxide tray | 8.1:1 |
| #d2cdc0 | titanium index plate | 6.2:1 |
| #dcc597 | titanium index plate, arrow | 5.8:1 |

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `assets/round3/oxide-frame.webp` | 368 × 448 | 18,762 | `c7aed9d943e5511cedfb7df78f2186541e483124b87bc55144493daa74d58cbf` | the same master, rows 0–200 over rows 600–848 (the rows between are plain sides), quality 90 |
| `assets/round3/stage-plate.webp` | 320 × 192 | 3,480 | `be32bff9622d4f9aabc0aeba02e39e54fe354055c87ce7b10db7350bfe2a4259` | `head_parts.py --part stage-plate --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/stage-plate-on.webp` | 320 × 192 | 3,686 | `52cded95000d3b254302f0ae34e11da55d57f618a6c46f1ea4c03f6ce7b15cac` | `head_parts.py --part stage-plate-on --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/clamp.webp` | 320 × 60 | 2,350 | `025be720c721691185e29b6adca59adb4c441c1c373f21b16d7c26970e826be4` | `head_parts.py --part clamp --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90; 3-sliced 36 px |
| `assets/round3/ti-frame-sm.webp` | 192 × 192 | 3,336 | `80c12fba3d7982d253fbb84b535abd064d2173d7ccd56110f004655dcb4066ee` | `ti_plate.py --part frame --size 96 --screw-in 12 --head-r 4.5 --socket-r 1.4`, 128 samples, quality 90; sliced 24 px |
| `assets/round3/button-rest.webp` | 240 × 120 | 2,992 | `db51a1e2e5bed9e90efbab87f718069a41d43cc536f66152360f42e78b3b5d3f` | `head_parts.py --part button-rest --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90; 9-sliced 28 px, 4 px outset |
| `assets/round3/button-pressed.webp` | 240 × 120 | 3,136 | `e1f2de62fbe8a555571e5a01ce8291540ec5e01eb1ccd410336a07f6bcb1ba08` | `head_parts.py --part button-pressed --rim 2.5`, as above |
| `assets/round3/button-primary.webp` | 240 × 120 | 3,020 | `40c1eeceff2246d4d043ac6c604762037c078ce4e99378e31eb9a1ce6e0ba124` | `head_parts.py --part button-primary --rim 2.5`, as above |
| `assets/round3/button-primary-pressed.webp` | 240 × 120 | 3,228 | `32349bc213994e55682d05a50a5c98311141d8e27386abf55c1a8733e047866b` | `head_parts.py --part button-primary-pressed --rim 2.5`, as above |

**Forced colours:** the tray, the plates and the index plates become Canvas with a CanvasText frame, the selected stage plate takes a 3 px Highlight frame, the buttons become system buttons, and the clamps are hidden.

## Round 3 rendered ground, shadows and light

On 2026-11-03 the owner said "use adobe tools or blender". No Adobe creative application is installed on this workstation; everything below is rendered in Blender 5.2.3. An audit of Home (nine agents, adversarially verified) listed what was still drawn by CSS or came from generated images; this pass replaces it.
- **The ground.** Home's chassis plate and every page's footer base were a generated mill-steel image (`PF_MILL_STEEL_GROUND_v1.webp`, above). They are now hot-rolled mild steel rendered as tiles that wrap exactly (`ti_common.mat_mill_steel`: mill scale, rolling streaks and lines along x, flakes and a fine grain on a torus of the tile's period).
  - The chassis tile is 690 px, half the 1380 px plate, so the joints with the side plates fall on tile edges. Mean sRGB 34, the tone the shaded image had.
  - The footer base has its own seed and a darker tone (mean 18).
  - The plate joints are rendered strips: a 1 px 35° chamfer on each plate and the 2 px gap between, lit by the key light (`chassis-joint-l/-r`). They replace CSS stripes.
  - The CSS light falloff on the chassis, the cool pool behind the hero, and the footer's darkening gradient, inset shadow and bottom band are gone: light belongs to the rendered parts. The weld strip is unchanged (owner decision, 2026-11-03).
  - The other rooms keep the generated image for now; only Home and the shared footer move.
- **Paper.** Home's sheets (the studio principle, the inspection record, the no-script stage list and the receipt) were a generated paper image under cream washes (`PF_PAPER_ARCHIVAL_v1.webp`). They are now archival cotton paper rendered as a 512 px tile (`ti_common.mat_paper`: mottled formation, long fibres both ways, a fine tooth). Mean sRGB 233/230/224, the old sheet's tone.
  - Each sheet's edge is rendered (`sheet-edge`, on all four sheets): the sheet lies on the chassis and its lower edge lifts 1.2 px, so the soft contact light from 45° casts the short shadow a thin sheet throws, about 1 px down its right edge and a soft 2–3 px band under its lower edge, in place of the CSS outline and 26 px blur.
  - The receipt's sheet takes the same clamp bar as the other two.
- **Contact shadows.** The low rim band of the studio throws shadows 40 px and more. Each sprite's canvas cut them off, so every key, link, anchor and button ended in a hard dark box. Every `head_parts.py` sprite is now rendered twice and combined by `sprite_compose.py`:
  - **`--pass obj`:** the part under the full studio, with its plate and occluders as holdouts;
  - **`--pass shadow`:** the plate's contact shadow, under the overhead dome and a soft contact light high over the key azimuth (80° up, 18° wide; `--contact-el/-angle/-power`), so it is short and soft and fades out inside the canvas; the paper sheet's edge takes that light from 45°. `sprite_compose.py` drops the one stray shadow-catcher pixel Cycles leaves at each canvas's top-right corner.
  - The canvases, bores and offsets are unchanged.
  - The head plate's edge is re-rendered with a 24 px margin, so the key light's shadow on the chassis fades out inside the art, where it used to be cut off at 6 px. The proof tray and the phone carrier use the same edge.
- **Light.** The proof chain's inspection light was a CSS radial gradient over the chain render.
  - It is now what a small cool spot (1500 W, 16° cone, blend 0.95, colour 0.84/0.9/1.0, 5 m above the checkpoint link) adds to the same scene. Each stage's light-pool box is rendered with and without the spot at the base's 160 samples and differenced (`chain_light.py`). The difference is kept above 1.5/255 of residual noise, faded to zero over the box's outer 10 CSS px, and stored as straight-alpha RGBA (alpha the brightest channel), then added over the unchanged chain art with `mix-blend-mode: plus-lighter`. Where a browser cannot blend it, or the chain has not loaded, it still only adds light.
  - The CSS light sweep across the nav keys on hover is gone.
- **States.** The inspection toggle's locked state ("Motion off") is its own render: the cap held down, with a dull finish.

**Contrast on the ground**, against the single worst pixel of each tile (the brightest for light text, the darkest for dark):

| Text | Surface | Ratio |
|---|---|---|
| #c0cbc5 / #eef0e7 | chassis (body text / headings) | 7.4:1 / 10.8:1 |
| #aebbaf | chassis (the hash scope note) | 6.2:1 |
| #d3bb92 | chassis (hero kicker) | 6.7:1 |
| #c3ccd0 / #aab6bb | footer base | 10.0:1 / 7.9:1 |
| #9aa0a2 | footer base (locked motion switch) | 6.2:1 |
| #1b292d / #26363a | paper (text) | 11.2:1 / 9.4:1 |
| #3e5054 | paper (record label) | 6.3:1 |
| #6a5b42 | paper (kicker) | 4.9:1 |

| Asset | Pixels | Bytes | SHA-256 | Scene and mode |
|---|---|---|---|---|
| `assets/round3/chassis-field-1380.webp` | 1380 × 1380 | 42,050 | `4d4fcfe965613b4d3e2c057360536440dbd3239a87fa45d807e1007f5fc0e7f9` | `ti_plate.py --part mill-field --tile 690 --tone 0.27 --seed 0 --scale 2`, 384 samples, no denoise, quality 90; repeated at 690 CSS px |
| `assets/round3/chassis-field-690.webp` | 690 × 690 | 10,984 | `6e19eeebfd26cabddbf74ac36b2a4d1cab17d02af17c5e5f9d66c082644b0794` | the same master, Lanczos to 1x from a 3 × 3 tiling, quality 92 |
| `assets/round3/chassis-joint-l.webp` | 24 × 1024 | 2,262 | `050c4687a34aead263d7ce87d89f7bb76e304ec6a60e8005ac0d14548dabfe0e` | `ti_plate.py --part chassis-joint-l --scale 2`, 128 samples, quality 90; repeat-y at the plate's left edge |
| `assets/round3/chassis-joint-r.webp` | 24 × 1024 | 2,198 | `75e3d20513bc0cafbd253ae478bb8ad6f399b3ea3487879435de884ff91716d9` | `ti_plate.py --part chassis-joint-r --scale 2`, as above, at its right edge |
| `assets/round3/footer-field-1024.webp` | 1024 × 1024 | 15,136 | `b6ed6f73c543270447e49f42ab4e64c8d9bc7915e246c606658dca9309541ba1` | `ti_plate.py --part mill-field --tile 512 --tone 0.13 --seed 3.7 --scale 2`, 384 samples, no denoise, quality 90 |
| `assets/round3/footer-field-512.webp` | 512 × 512 | 4,060 | `5e9b57ad71239d745d9c22962938c23897c2b3b834c9b9f5a72936dd012a15c6` | the same master, Lanczos to 1x from a 3 × 3 tiling, quality 92 |
| `assets/round3/paper-field-1024.webp` | 1024 × 1024 | 19,876 | `3a7476673b98219aa637fbddff98a2bb4e0a635c3d70170038ddf9d754d6303c` | `ti_plate.py --part paper-field --tile 512 --seed 0 --exposure 4.1 --scale 2`, 384 samples, no denoise, quality 92 |
| `assets/round3/paper-field-512.webp` | 512 × 512 | 7,856 | `b3e3765db7cae672c619d9c637193e386b063431b68bdba12b5a7f158d0b725a` | the same master, Lanczos to 1x from a 3 × 3 tiling, quality 94 |
| `assets/round3/sheet-edge.webp` | 320 × 320 | 4,886 | `7e7333e26d412cce5ab30632996da3a4edd1894f2d5b46ae7a0325bfeea7c264` | `head_parts.py --part sheet-edge --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 (contact light from 45°); 9-sliced 8/16/32/8 px with a 4/8/8/4 px outset, no fill |
| `assets/round3/button-locked.webp` | 240 × 120 | 3,104 | `d3f7803bd8d1f6912263b846d8911ef89e9fc188ab7482c91ee38bf2c3f9358a` | `head_parts.py --part button-locked --rim 2.5`, two passes (`--pass obj` and `--pass shadow`, `sprite_compose.py`), 128 samples, quality 90 |
| `assets/round3/chain-light-s0.webp` | 465 × 324 | 61,730 | `7ad481cc549274a6e45458a4a76f953710762bcd5e96f2a0dff1014a1ff2a3ef` | `chain_scene.py --scene desktop --mode base --scale 2 --samples 160 --crop 0`, with and without `--lit 0`, differenced by `chain_light.py` (RGBA), quality 88 |
| `assets/round3/chain-light-s1.webp` | 465 × 317 | 50,460 | `fdb61835e7a00d0c7e211d13105fcc9ac698660ce3c07d84b120a44c306ac468` | `chain_scene.py --scene desktop --mode base --scale 2 --samples 160 --crop 1`, with and without `--lit 1`, differenced by `chain_light.py` (RGBA), quality 88 |
| `assets/round3/chain-light-s2.webp` | 466 × 315 | 54,380 | `531ccea38da1b3a4a218614747563f9b33a74cb2e9459d12ba455b83b3c6189d` | `chain_scene.py --scene desktop --mode base --scale 2 --samples 160 --crop 2`, with and without `--lit 2`, differenced by `chain_light.py` (RGBA), quality 88 |
| `assets/round3/chain-light-s3.webp` | 465 × 319 | 59,894 | `d6bc2e26197934ce369b706a49312537cb41207fcab681e9883912df06573cd1` | `chain_scene.py --scene desktop --mode base --scale 2 --samples 160 --crop 3`, with and without `--lit 3`, differenced by `chain_light.py` (RGBA), quality 88 |
| `assets/round3/chain-light-s4.webp` | 465 × 324 | 56,714 | `801834ed8403316717bde1d0ce397d32d96bd1bb01e834b249301f0dd8db877d` | `chain_scene.py --scene desktop --mode base --scale 2 --samples 160 --crop 4`, with and without `--lit 4`, differenced by `chain_light.py` (RGBA), quality 88 |
