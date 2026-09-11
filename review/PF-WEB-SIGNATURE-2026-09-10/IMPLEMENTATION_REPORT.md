# The Proof Foundry Signature Homepage

## Classification

`PARTIAL_IMPLEMENTATION_WITH_NAMED_BLOCKERS`

`OWNER_VISUAL_ACCEPTANCE: PENDING`  
`PRODUCTION_DEPLOYMENT: NOT_AUTHORIZED / NOT_PERFORMED`  
`PRODUCT_RELEASE_AUTHORITY: UNCHANGED`

## Scope

Implemented the local homepage candidate from the 10 September 2026 directive. The change is limited to website presentation, shared card labeling, the static build copy list, and the homepage stage loader. Product source, signing keys, release records, artifact URLs, commercial terms, DNS, and deployment workflows were not changed.

Base repository state: `master` at `92cd03e` before the working-tree changes. The candidate remains uncommitted so the owner can inspect the bounded diff first.

## Exact working-tree custody

An earlier revision of this report listed `signature.css` under both "modified" and "new". That was
wrong. `git status --porcelain=v1 --untracked-files=all` reports exactly:

**Modified, tracked, unstaged (5):**

```
 M experience.js
 M index.html
 M partials/footer.html
 M partials/product-card.html
 M scripts/build-site.ps1
```

**New, untracked (3 paths):**

```
?? signature.css
?? scripts/test-signature-home.ps1
?? review/PF-WEB-SIGNATURE-2026-09-10/
```

`signature.css` is new and untracked. It has never been committed, so it cannot be modified.

Nothing is staged: `git diff --cached --name-status` is empty. `public/` is generated output and is
not tracked. No commit, tag, branch, push, or deployment was created.

## What changed visually

- Made the approved horizontal Foundry lockup a substantial part of the opening composition without changing the compact header mark.
- Reframed the homepage as a brand-led workbench: Foundry identity and one real Cache Vault interface share the first composition.
- Kept the manual seven-product stage selector, but removed the redundant homepage directory strip.
- Added a concise reassurance band for local control and release records.
- Broadened the catalog language to “Find your next tool.”
- Preserved Reality Gate as a distinct featured developer entry.
- Added availability dots and labels to generated regular product cards without changing their canonical release state.
- Added a compact Foundry identity section and restrained Founders Circle signpost below the software.
- Standardized the footer destination label to “Release records.”

## What changed functionally

- Added product-specific “See it in action” links for Cache Vault and Reality Gate, pointing to their existing real product films. The link hides for products without an existing film.
- Kept ordinary product links, release information, filters, comparison, screenshot viewing, and no-JavaScript catalog content in generated HTML.
- Replaced the stage loader’s `decode()`-only wait with a load-event/natural-width guard. This prevents a loaded real screenshot from leaving the stage permanently `aria-busy` in Chromium.
- Added `scripts/test-signature-home.ps1` with 15 focused source/output assertions.

## Preserved product depth and truth

- Cache Vault’s existing workflow and candidate/public distinction were not rewritten or duplicated.
- Lights Out’s public/candidate/hold presentation remains manifest-driven and unchanged.
- Reality Gate remains the featured pilot entry. The disputed terminal/pilot capability was not promoted or resolved without new authoritative release evidence.
- ProofShot remains visibly in development, with its existing HyperSnatch engine qualification left intact.
- No download button, pricing, purchaser claim, support address, or candidate was invented.

## Validation summary

- `npm run build`: PASS, 7 products, 0 manifest errors.
- `pwsh -NoProfile -File scripts/test-receipts-invariants.ps1`: PASS, 54/54.
- `pwsh -NoProfile -File scripts/test-signature-home.ps1`: PASS, 15/15.
- `node --check experience.js; node --check site.js`: PASS.
- `git diff --check`: PASS.
- Chromium local interaction checks: hero selection, keyboard arrow navigation, Android filter, two-product comparison, product-specific film link state, mobile menu toggle, reduced-motion state: PASS.
- Forced image-failure check: prior product remains visible, `aria-busy` clears, fallback message appears: PASS.
- Axe homepage audit: 0 violations, 43 passes, 1 incomplete `color-contrast` result covering 44 nodes
  over the product-stage gradient. That incomplete was adjudicated by hand rather than left open; see
  below and `CONTRAST_ADJUDICATION.md`.
- 200% browser zoom: PASS. 640 x 360 CSS px, 0 px horizontal overflow, 0 overflowing elements.
- 400% reflow, WCAG 2.1 SC 1.4.10: PASS. 320 x 256 CSS px, 0 px horizontal overflow, single column.
- Phone widths 390, 360, 320: PASS. 0 px horizontal overflow at each.
- JavaScript disabled: PASS. 16/16 content assertions against the generated HTML, plus verified renders
  at 1280 and 390. Responsive layout is CSS-only; no init-time class or style gates it.
- Asset content signatures across all 147 generated files: 144 PASS, 3 pre-existing failures outside
  this candidate. All 61 homepage-requested assets PASS.
- Second browser, same engine: Edge 152 (Blink) matches Chrome 153. This confirms build consistency,
  not engine independence.
- Owner review captures: 5 full-page captures at 1920, 1440, 1024, 820, 390 with every content image
  confirmed loaded, plus 9 fold captures at 360 to 1920 and 3 wrapped phone captures.

## Defect found and corrected during qualification

The gradient contrast result had been reported twice as "0 violations, 1 incomplete" and treated as
finished. Scoring the 44 unscored nodes by hand found one genuine WCAG AA failure that axe had never
evaluated:

`.theater-context`, the caption "Select an instrument. See the work.", measured **3.91:1** against the
lightest point of the product-stage gradient, below the 4.5:1 threshold for normal text. Corrected in
`signature.css` from `#80908a` to `#98a59e`, measuring **5.11:1** against the same worst-case
background, and verified live in the rebuilt output. All 44 nodes now meet AA.

## Defect found and deliberately left alone

Three files served as `.png` contain JPEG data: `companion-active.png`, `companion-reconnected.png`,
and `companion-snoozed.png` under `assets/lights-out/`. They are pre-existing, git-tracked, unmodified
by this candidate, byte-equal to the live site since `308d2f1`, and referenced only by the Lights Out
product page. The homepage does not request them. Correcting it means re-encoding or renaming product
assets and editing a page outside this candidate, so it is raised for the owner rather than folded
into this diff.

## Named blockers and limits

- **Owner visual acceptance is the outstanding gate.** `OWNER_VISUAL_REVIEW.html` in this directory is
  a self-contained local board holding every capture and an acceptance checklist. Open it from the
  filesystem; it is never published.
- **No independent browser engine was tested.** Only Chromium-family browsers exist on this machine.
  Chrome 153 and Edge 152 were both exercised and agree, but they share Blink. Gecko and WebKit
  rendering is unverified. Firefox is not installed and installing one sat outside the change boundary.
- **No physical device was tested.** Every phone and tablet result is an emulated viewport width.
- **No field performance or Web Vitals data.** No comparable baseline was retained, so any number
  produced here would not be interpretable.
- **No complete keyboard traversal sweep.** Hero arrow navigation, the phone menu, filters, and the
  comparison dialog were exercised; a full tab-order pass over every interactive element was not.
- **Three mislabelled `.png` files remain unfixed** on the Lights Out page, by decision, as described
  above.
- No new approved support destination was found, so no support link or contact form was added.
- The earlier first-pass embedded-CDP desktop captures were tiled and unusable. They are retained only
  as a record of that artefact and are not evidence. Clean Chrome captures superseded them.
- `PRODUCTION_DEPLOYMENT` remains not authorised and not performed.

## Evidence

- **Owner review board: `OWNER_VISUAL_REVIEW.html`** &mdash; open this first
- Contrast adjudication and the corrected defect: `CONTRAST_ADJUDICATION.md`
- Asset content-type audit and the mislabelled-PNG finding: `ASSET_CONTENT_TYPE_AUDIT.md`
- Detailed checks and the acceptance matrix: `QA_RESULTS.md`
- Design tokens and usage: `DESIGN_SYSTEM.md`
- Claim and asset boundaries: `CLAIM_AND_ASSET_REGISTER.md`
- Source/output identity and exact git state: `CUSTODY_MANIFEST.json`
- File hashes: `SHA256SUMS.txt`
- Captures: `screenshots/before/`, `screenshots/after/`, `screenshots/states/`,
  `screenshots/qualification/`
- Reproducible measurement scripts: `contrast-audit.js`, `contrast-calc.js`, `layout-probe.js`,
  `image-readiness.js`
