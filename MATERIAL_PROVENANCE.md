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

Total payload of the three layers: 310,624 bytes. A page downloads only the layers it uses: Home, About (paper intro) and Truth Files ≈ 0.31 MB (all three); Proof Standard and Support ≈ 0.26 MB (no paper). All are CSS backgrounds with a matching solid `background-color`, so they cause no layout shift and the first frame shows the same dark tone before decoding.

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
