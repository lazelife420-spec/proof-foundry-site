# Proof Foundry site brand alignment candidate

This local successor extends the approved-for-review PF geometry and the
homepage's Proof Ledger design to the rest of the website. It does not publish
or deploy the candidate. Visual owner approval remains pending.

## Shared design

`pf-site-ledger.css` follows the existing `pf-home-ledger.css` palette: neutral
steel `#0b0f14` / `#1c232b`, paper `#f4f7f8`, teal `#00d1b2`, and restrained
maker-mark gold `#d6a84f`. Paper actions use dark teal `#00685b` with light text.
Serif editorial headings, monospace record labels and consistent header/footer
marks connect the pages. The late stylesheet adapts the older presentation
sheets while preserving their product-specific media and composition rules.
Its URL is content-hashed by the existing template pipeline.

The catalog's furnace image is replaced by the same pressed maker plate used
on Home. Product pages keep their authentic icons, media and accent identities,
within neutral steel surroundings. Secondary information pages and every Truth
File use the paper record treatment. Mobile navigation, catalog search,
comparison, galleries, disclosures, checksum copying and existing links remain
under their existing runtime.

The compact footer and generated-page favicons now use `PF_HEADER_MARK.svg`.
The Founders receipt preview uses `PF_RECEIPT_WATERMARK.svg` as a maker's mark;
it does not imply a verified purchase. Its reserved/claim semantics are intact.
The micro mark still omits large-size inscriptions. All hidden geometry and
maker marks remain documented in `BRAND_SYSTEM_CANDIDATE.md`.

## Media and reproducibility

`brand/PF_SOCIAL_CARD.svg` is the self-contained authored share-card source. Its
embedded plate is the existing candidate SVG, without edits. The committed
1200×630 PNG is its browser-rendered derivative. `PF_HEADER_TOUCH.png` is the
same micro mark at 130×130 centered on an opaque 180×180 steel tile. Neither
uses external imagery. Original brand assets remain preserved.

The controlled rendering recipe and media hashes are in the local evidence
directory `pf-site-brand-alignment-20261005`, alongside qualification logs and
desktop/mobile renders. Ordinary builds copy these fixed media assets; they
do not depend on a browser or font rendering to recreate them. Two fresh
ordinary builds must produce identical static bytes at the same committed
source. The homepage body and its stylesheet are preserved; only its share-card
metadata changes in this successor.

## Authority and scope

No page copy, release fact, artifact identity, qualification claim or acquisition
link changes. `release-truth.json` remains the authored release-fact source.
Seven products, eleven channels, Truth v1 compatibility and strict Truth v2
remain intact. The withdrawal, public/candidate and platform distinctions remain
visible. Installation authority stays `NONE`; production signing stays `HOLD`.

No master movement, push, deployment, App/Android changes or governance repair is
part of this candidate. Qualification results and exact commit/tree identity are
reported separately after testing the committed source.
