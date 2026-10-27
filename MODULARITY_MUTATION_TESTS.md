# Modularity Mutation Tests — Isolation and Fail-Closed Proof

**Candidate:** branch `codex/pf-modular-html-r1`, isolated worktree `C:\Users\KickA\Projects\Worktrees\pf-modular-r1` (base `0dd208c`, uncommitted owner-review changes on top).
**Directive:** `PF_WEBSITE_20_PASS_MODULAR_HTML_TRUTH_FILES_MASTER_2026-10-26.md` (owner, 2026-10-26) — prove per-module edit isolation and release-truth fail-closed behavior with mutation tests.
**Compiled:** 2026-10-26, Factory, local Windows evidence only.
**Method:** every mutation was applied to a disposable scratch copy of this candidate under `%TEMP%\pf-mut\`, rebuilt with `scripts/build-site.ps1`, then the entire published tree was SHA-256 hash-diffed against the base build. The candidate worktree and the owner's main checkout were never mutated by these tests.
**Disposition:** owner-review evidence. No push, merge, Pages upload, deploy or release-state change.

## 1. Harness and baseline

| Fact | Value |
|---|---|
| Harness | `%TEMP%\pf-mut-harness.ps1`; log `%TEMP%\pf-mut-run.log`; scratch trees `%TEMP%\pf-mut\{base, m1-story, m2-brand, m3-truth, m4-header, m5-fake-cta, m5b-fake-cta-nolit}` |
| Scratch copy rule | `robocopy` of the candidate source (excluding `node_modules`, `public`, `.wrangler`, `.snapshots`); each test rebuilds from source |
| Diff method | SHA-256 of every file under `public/`, compared file-by-file against the base build |
| Base build | exit 0 — "7 visible products, 9 directory routes"; 280 published files |
| Base model | source `release-truth.json` SHA-256 `737EDEDA475EE63757009F87CDE14A06351FD4E1CA798AAFA7891A4C9E11320B` |

Verdict rule — a test **passes** when changed outputs are limited to (a) the edited product's own routes/assets, (b) pages that legitimately render that product (software/home cards, proof receipts, truth indexes, roadmap/support rows), or (c) global provenance digests. A truly shared component (the header) is expected to change every route by design.

## 2. The four required mutations

### m1 — story content edit (product module → isolated)

Edit: `products/cache-vault/content.html` — prepended `[MUTATION-STORY]` to the lede. Build exit 0.

| Changed output | Why |
|---|---|
| `cache-vault/index.html` | the product's own page |
| `__h14/content/cache-vault.html` | the same story in the H14 shadow asset |

`release-truth.json` unchanged; no other route changed. **PASS — isolated.**

### m2 — brand accent edit (product module → isolated)

Edit: `products/cache-vault/module.json` — accent `#A9C48F` → `#C49A8F`. Build exit 0.

| Changed output | Why |
|---|---|
| `cache-vault/index.html` | the product's own page |
| `software/index.html` | the software card renders the accent |
| `__h14/modules/cache-vault.json` | module shadow asset |
| `__h14/shells/cache-vault.html` | shell shadow asset |

`release-truth.json` unchanged; no other route changed. **PASS — isolated.** Brand is presentation data, so the product page and its aggregate card both change and nothing else does.

### m3 — truth record change (release authority → fail-closed + authorized path)

**Phase 1 — a direct edit fails closed.** Editing `release-truth.json` directly (cleanroom `status=WITHDRAWN`, channel withdrawn, `downloadUrl=''`) without re-pinning custody:

- Build exit 1: `Shared component custody digest mismatch … Shared release truth projection failed; no output is published.`
- Nothing under `public/` is written. **PASS — fail-closed.** The model is pinned by `vendor/pf-shared-release-truth/provenance.json` (per-file SHA-256 + `modelSha256`); a truth change without the custody step cannot publish.

**Phase 2 — the authorized path, three fixture iterations.** A synthetic Cleanroom withdrawal was applied the way the release authority does it (the fixture re-pins the provenance digests and mirrors the real Reality Gate withdrawal). The fixture was tightened in three steps; each step maps to one real surface of the real RG withdrawal, and the same sweep tool (`pf-m3-check.cjs`) counted the withdrawn installer/SHA256SUMS URLs across every published file:

| Fixture | Withdrawal shape applied | URLs remaining in `public/` | Product-page download CTA |
|---|---|---|---|
| v1 | model withdrawal + artifact `downloadUrl`/`sha256Url` null + custody re-pin; model `verification.evidence` and site-manifest `proofLinks` left as authored | 28 occurrences across 7 files (v2 record: `evidence=2`, `proofLinks=2`) | absent |
| v2 | v1 + model `verification.evidence = []` — the real RG record holds `evidence: []` | 14 occurrences across 7 files (v2 record: `evidence=0`, `proofLinks=2`) | absent |
| v3 | v2 + site-manifest `proofLinks = []` and `proofStatus` mirrored from the real RG entry | **0 occurrences — sweep clean** (v2 record: `evidence=0`, `proofLinks=0`) | absent |

Interpretation: the residual URLs in v1/v2 were **fixture gaps, not pipeline leaks** — every remaining occurrence sat in the evidence/proofLinks arrays the fixture had left in the authority files, and each was cleared by mirroring the real RG shape of that surface. In all three iterations every download affordance was already removed: the product-page CTA, the proof receipt action button, and every `downloadUrl`/`sha256Url` field were absent/null from v1 onward, because availability is governed by the model's download block, never by evidence links. The builder is faithful: it renders exactly what the release authority writes.

**m3 v3 results** (build exit 0; 24 changed outputs):

| Class | Outputs | Count |
|---|---|---|
| Cleanroom's own surfaces | `cleanroom/index.html`; `truth-files/cleanroom/index.html`; `truth/products/cleanroom.json`; `truth/v2/products/cleanroom.json`; `__h14/modules/cleanroom.json`; `__h14/shells/cleanroom.html`; `__h14/static-state.json` (all-product state carrier) | 7 |
| Aggregates that render Cleanroom | `index.html` (home card); `software/index.html`; `roadmap/index.html`; `support/index.html`; `proof/index.html`; `proof/index.json`; `truth/index.html`; `truth/index.json`; `truth/v2/index.json`; `truth-files/index.html` | 10 |
| Global provenance digests | `truth/v2/products/{cache-vault, forgecast, ghostlayer, lights-out, proofshot, reality-gate}.json` | 6 |
| Published manifest copy | `site-manifest.json` (cleanroom entry) | 1 |

- The six other products' v2 records were diffed key by key: **only `source.releaseFactsSource.modelSha256` and `websiteProjectionSha256` differ** — global digests that legitimately change with the model. No content key (channels, artifacts, status, evidence, tests, download) differs for any other product.
- Withdrawn rendering verified on every surface: product page (withdrawal marker, no download CTA), software page, home page, Truth File record, proof receipt, `__h14` module JSON and static-state (`state=withdrawn`, `downloadUrl=null`). The `__h14` shell HTML carries no per-product static text by design; it loads the module JSON, which carries the withdrawn state.
- Truth records: v1 record `status=WITHDRAWN`, `download.available=false`, `download.url=null`, checksum retained as the withdrawn-bytes identity (same convention as the real RG record); v2 record `state=withdrawn`, `releaseStatus=WITHDRAWN`, `withdrawalReason` set.

**PASS — an authorized truth change is isolated to the product, its legitimate aggregates, and the global digests; a properly shaped withdrawal leaves zero download URLs and zero download affordances in the published tree.**

### m4 — shared header edit (expected global blast radius)

Edit: `partials/header.html` — `Skip to content` → `Skip to main content`. Build exit 0.

Changed outputs: 26 = all 25 routes + `__h14/partials/header.html`. **PASS — expected global.** The header is the one intentionally shared component; the diff makes that blast radius explicit in a single run, which is exactly what the owner-approved "shared components" contract requires.

## 3. Negative controls — a fake download CTA on the withdrawn product

| Test | Edit | Result |
|---|---|---|
| m5 | `products/reality-gate/content.html` gains a download button whose href hardcodes the artifact filename literal `Reality-Gate-1.1.0-Developer-Pilot.zip` | Build **rejected**: "template hardcodes canonical literal … render it through the matching product token instead so it cannot drift from the manifest" |
| m5b | same CTA without the literal filename | Build succeeds (2 outputs: `reality-gate/index.html` + `__h14/content/reality-gate.html`), but the gate floor `test-h9-binding.ps1` **fails**: "Reality Gate withdrawal truth remains canonical and routed without a download CTA". All other suites pass (release-truth 164, h13 200, truth-files 239, h11 360) |

**PASS — two independent guard layers.** The manifest validator stops canonical-literal drift at build time; the H9 binding floor stops a no-literal fake CTA at test time. A fake download cannot reach the published tree silently.

## 4. Fail-closed layers observed across all tests

1. **Custody digests** — `vendor/pf-shared-release-truth/provenance.json` per-file SHA-256 + `modelSha256` (m3 Phase 1).
2. **Manifest validator canonical-literal ban** (m5).
3. **H9 binding test floor** — withdrawal canonicality (m5b).

During fixture development the shared reducer and the product registry also rejected intermediate malformed shapes before the build completed. The layers stack; none relies on a single check.

## 5. Conclusions for the editing contract

1. **One page, one file holds** — story and brand edits touch only that product's outputs plus the aggregates that render it (m1, m2).
2. **Truth changes are governed** — direct edits fail closed; authorized changes propagate only to the product, its aggregates, and the global provenance digests (m3).
3. **Shared components are the only all-route surface** — by design, and visible in one diff (m4).
4. **A withdrawal is a three-file authority surface** — `release-truth.json` (model: status, channel, withdrawal, artifacts, `verification.evidence`) + `site-manifest.json` (presentation: `proofLinks`, `proofStatus`, `downloadUnavailable`, `downloadLabel`) + `products/<id>/module.json` (commerce). The real Reality Gate record is the reference shape for all three; with that shape the build contains zero download URLs and zero download affordances for the withdrawn product. Encoded in `TRUTH_FILES_PUBLIC_CONTRACT.md`.
5. **Fake CTAs cannot ship silently** — the validator and the test floors each catch a different class of forgery (m5/m5b).

## 6. Evidence artifacts (scratch, disposable)

`%TEMP%\pf-mut-harness.ps1`; `%TEMP%\pf-mut-run.log`; `%TEMP%\pf-m3-fixture-v1.cjs`, `-v2.cjs`, `-v3.cjs` (the three withdrawal shapes); `%TEMP%\pf-m3-check.cjs` (URL sweep + render spot checks); `%TEMP%\pf-m3-vdiff.cjs` (per-key v2 record diff); runners `%TEMP%\pf-m3a-run.ps1` / `pf-m3b-run.ps1` / `pf-m3c-run.ps1`; scratch trees under `%TEMP%\pf-mut\`. None of these are part of the site; the candidate worktree was untouched by every mutation.
