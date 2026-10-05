# Foundry website design candidate

Local successor to `f8321599922eae56dc1ecd30324064fa8dd4b260`. The owner requested a full design pass, including Home, matching the accepted PF logo and keeping navigation and typography consistent across pages. This authorizes a visual candidate, not a production deployment.

## Design system

`pf-foundry-system.css` is the shared final presentation sheet for all 25 routes. Georgia remains the editorial heading face; system UI remains body and control type; Consolas remains labels, identifiers and the wordmark. No remote fonts or new JavaScript dependencies.

Home now uses the same header partial as every other page. Software / Proof / Truth Files / About and the Support CTA share exact markup, dimensions and type; only the current-page marker varies. All pages use the full shared footer. Mobile Escape closes navigation and returns focus to its toggle.

The dark hero and colophon surfaces use a low-contrast, real-material welded steel texture. Paper records remain opaque. The Home hero gives the maker plate more space, featured tools use their existing authentic previews with an explicit historical-preview disclosure, and the proof chain, specimen, catalog, product pages, documents, support and footer use the same spacing and surface grammar. Product marks and product-identifying media remain intact.

The shared navigation/footer is a material content event for all indexable routes, so all 24 sitemap lastmod values are `2026-10-05`. These are website material dates; release versions, dates and qualification states are unchanged. The H9 guard now asserts canonical header equality across page families instead of the superseded Home-only header; H11 retains exact sitemap assertions at the new material date. No qualification population is removed or skipped.

H13's module-order mutation now permits the shared Home footer product list to follow registry order. It still compares the complete Home document exactly after normalizing only that list's item order, checks the expected first product and population, refuses unexpected non-item content, and includes negative controls for changing a product link and an unrelated support link. The 200-assertion population is retained. The original full-suite failure and all attempted qualifications are preserved in the review evidence; dependent publisher gates are rerun on the exact repaired candidate.

## Authored authority and protected boundaries

`release-truth.json`, the shared compiler, presentation product records, artifact URLs, hashes, sizes, channels and withdrawal remain unchanged. The sole `site-manifest.json` change adds the Truth Files navigation link; it remains presentation/compatibility data. No signing or installation authority is introduced. Machine projections differ only in independently verified website commit/tree/time provenance.

No push, deployment, master movement, Hardline/RG/connector changes, App/Android work or production key access belongs to this candidate.

## Hidden elements

The accepted PF geometry and its 11 documented maker elements are preserved: pressed circle recess; folded receipt in P counter; gold record crossbar; public ASCII PF binary; symbolic `record(source, artifact)` inscription; SOURCE / ARTIFACT / RECORD microtext; BUILD IT · PROVE IT · SHIP IT microtext; three top notches; four cardinal registration marks; clipped plate corners; four inward-aligned corner fasteners. Refer to `BRAND_SYSTEM_CANDIDATE.md` for the original geometry and meaning. Large-only inscriptions remain absent from the small header icon.

The footer repeats the three source/artifact/record registration notches as a decorative maker's mark, hidden from assistive technology. The welded seam represents careful fabrication; it makes no security or verification claim.

## Generated material asset

Built-in imagegen mode; new raster material, no edits to the vector brand.

Final asset: `brand/PF_WELDED_STEEL_v1.webp`, 1440 × 960, 63,844 bytes. The generated PNG is preserved in the local review evidence; the original generator output is retained. Export only resizes/compresses the selected image for web delivery.

Final prompt:

> Create a brand-new raster material texture for the background of The Proof Foundry, a premium independent software studio website. Use case: photorealistic natural material. Asset type: website background texture, landscape 3:2. Composition: straight-on macro photograph of a large expertly fabricated steel panel, no objects or perspective, nearly black graphite gunmetal with extremely subtle brushed metal grain and authentic fine machining scratches. One narrow precise TIG welded seam runs vertically close to the right edge (around 85% across), with a soft dark heat-affected halo and restrained silver weld ripples. Most of the image, especially the left and center, is quiet uninterrupted dark steel for white text. Lighting: soft broad grazing studio light, low contrast, calm, premium craft, muted neutral cool gray. No sparks, no fire, no rust, no lettering, no symbols, no logo, no border, no screws, no dramatic glare, no glossy chrome. Avoid busy detail. The result must feel like real metal when inspected closely and almost disappear behind website text at ordinary size. Keep all tonal values dark, texture gently visible, no bright areas.

## Qualification

Exact committed candidate results and desktop/mobile review captures are preserved under `C:/Users/KickA/Projects/Context/ProofFoundry/review/pf-foundry-premium-design-20261005`. The final summary is authoritative for test counts; draft screenshots alone are not qualification evidence.
