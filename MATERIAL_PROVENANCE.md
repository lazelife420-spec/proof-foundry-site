# Material provenance

Website material layers for Home and the shared non-product rooms (About, Support, Proof Standard, Proof, Truth, Truth Files, Founders, Roadmap, Products directory, 404). Product pages and per-product Truth File records are not changed.

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

One light source, upper left. Rolled mill steel carries the load (Home is shaded least). Brushed stainless marks surfaces people handle: the five stage plates, the Proof Standard inspection frame, the Support service panel, the Truth Files clamp bar and the About room. Archival paper carries records. The central chassis plate is 1380 px wide, so its recessed joints with the side plates fall outside the 1320 px reading rail; About's stainless cladding sheets are 920 px tall with recessed butt joints. The only weld is the butt weld where the footer base meets the chassis. Movable keys and chain links hang on pins and clevises. Light oxidation appears only at the lower corners of Home's carbon-steel hero plate, where it rests on the chassis ledge. Forced colours remove every material layer.
