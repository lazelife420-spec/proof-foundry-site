# H9 repository qualification fixtures

These fixtures make the accepted H9 qualification reproducible from a clean checkout containing only repository source. They do not change the homepage, catalog, product facts, browser runner or accepted owner-review package.

Accepted package: `PF_H9_BINDING_WEB_DESIGN_OWNER_REVIEW.zip`, SHA-256 `3416bfbd2159c5cb8c1f659062edebf9fbcaf6b44897fd459be050aae2bd1ec8`. Canonical production baseline: `34a291d78fa92f1a18cf76cef3ee56b391186e77`. Original package artifacts remain external review evidence; qualification does not require ZIPs, ignored receipts, screenshots, local previews or superseded tools.

## Baselines and comparisons

`binding-custody.json` and `cinematic-custody.json` retain the exact raw SHA-256, byte length and provenance of every selected original entry-inventory file. Their metadata pins each original inventory and entry ZIP; every baseline was verified against its entry ZIP when the fixtures were created. Text additionally records its UTF-8 SHA-256 after replacing CRLF with LF. No whitespace trimming, BOM removal, case folding, Unicode normalization or other content normalization is allowed. Binary files must match the exact raw SHA-256. Missing files fail custody.

This permits Git's normal text line-ending conversion without approving content drift. Both accepted raw and normalized hashes remain available for audit. Every retained runtime/product/media baseline remains the originally reviewed value. Four additional current-custody entries are pinned directly to accepted owner-package payloads: the three new environment WebPs and `scripts/capture-h9-binding.mjs`.

The accepted local commit's portability changes affect only the three guard sources listed in `portability-migration.json`. That historical manifest pins their before/after raw and normalized hashes. `portability.patch` records that exact text delta. Where an entry fixture already froze one of those guards, its original baseline remains intact and an explicit `migration` object supplies the new expected hash. The subsequent landing-authority migration is recorded separately below. The current binding guard is new relative to both entry inventories and therefore has its migration recorded without introducing a self-hash cycle.

The changes replace ignored inventory reads with these fixtures and the shared `custody.ps1` helper. All non-custody semantic assertions, canonical product/registry comparisons, receipt fields, catalog behavior requirements and historical failure labels remain unchanged.

## Explicit source exclusions

Every excluded assertion is retained as an object in its fixture's `exclusions` array, including original raw/normalized hashes and the reason. These files remain in local historical review custody but do not belong in the source commit.

- Binding excludes 19 unselected brand experiments/contact-sheet source files and three superseded capture runners: `capture-h9-cinematic.mjs`, `capture-h9-reconciled.mjs`, and `capture-h9-screenshots.mjs`.
- Cinematic excludes the same 19 brand sources plus the ignored raster `brand/PF_MARK_G_CONTACT_SHEET.png`, which appears in its older inventory. The selected four G SVG assets remain mandatory. The older cinematic guard did not freeze capture runners.
- No canonical product, download, artifact digest, authentic app image, shared runtime surface, current catalog source, selected G source, or semantic assertion is excluded.

## Canonical assets and staged qualification

`canonical-assets.json` pins all 136 assets/brand files from the canonical production Git object and all seven approved new H9 assets from the accepted owner package: four selected G SVGs and three binding-foundry WebPs. Reconciliation checks the actual files under `-Root`, so an isolated staged checkout cannot accidentally read the original working tree's index to decide whether its assets changed.

The existing single canonical-asset preservation assertion remains, now backed by those canonical file hashes. Nine assertions are added: one rejects unexpected asset paths, one verifies that none of the explicitly excluded brand artifacts is tracked/staged, and seven require the exact approved additions. The 20 explicitly listed historical brand/contact-sheet artifacts are ignored only for this source-directory inventory; they are not authorized for staging. The staged-path manifest must exclude them, and a clean checkout will not contain them. All new runtime assets are mandatory, not optional exceptions.

Git is used read-only to retrieve the pinned canonical production manifest/source objects and require that the inspected production commit is an ancestor of candidate `HEAD`. A clean staged snapshot must have access to those objects and their ancestry. A legitimate fast-forward landing may advance `master` without invalidating qualification. The guard does not rely on the original repository's index or the current position of `master`.

## Landed ancestry qualification

The original guard required local `master` to remain at the pre-H9 production commit. That assertion became invalid when the accepted H9 commit was legitimately landed. `landing-authority-migration.json` and `landing-authority.patch` record the exact two-guard repair from accepted commit `d571c3b742434b6c400ddde8ece1226d96554731`: `git merge-base --is-ancestor` must succeed for pinned production `34a291d78fa92f1a18cf76cef3ee56b391186e77` and candidate `HEAD`. Every nonzero Git result fails the assertion. No reference is reset or fabricated for qualification.

The pinned manifest comparison, product/artifact truth, assertion totals, historical failure labels and 18 replacement mappings remain unchanged. The binding fixture's cinematic-guard entry retains its original baseline and prior portability migration; only its explicitly documented current migration advances to the repaired guard hash. The binding guard's own transition is recorded separately to avoid self-hashing.

## Production validation repair

Production browser verification exposed missing icon declarations on `/proof/`, `/founders/`, `/cleanroom/`, `/forgecast/` and `/lights-out/`, triggering browser requests for nonexistent `/favicon.ico`. The shared build finalization now supplies the same existing `/brand/proof-foundry-mark.svg` icon only when a rendered HTML head has no icon declaration. Existing selected G and legacy declarations remain untouched, and all five page source files remain frozen. The public-site verifier also still expected `Explore the software` although the accepted H9 homepage says `Explore our software`; that one-word expectation is corrected without changing homepage copy.

`production-validation-migration.json` and `production-validation.patch` pin the three exact source transitions from commit `169b99f778b0169e76b6415d834a8c0ba78d115f`: conditional existing-icon metadata in the shared builder, the verifier's one-word CTA expectation, and the reconciliation guard's allowance for precisely that verifier substitution against the pinned production object. Both custody fixtures retain original baselines and any previous migration while recording the new expected bytes. No page source or other frozen source is relaxed. Assertion counts, canonical manifest/artifact comparisons and all 18 historical failure mappings remain unchanged.

## Honest assertion totals

| Guard | Accepted owner package | Custody exclusions | Added mandatory checks | Portable result |
|---|---:|---:|---:|---:|
| Current binding | 291/291 | 22 | 4 | 273/273 |
| Historical cinematic | 268/271 | 20 | 0 | 248/251 |
| Production reconciliation | 48/52 | 0 | 9 | 57/61 |
| Complete 18-script suite | 1475/1493 | 42 | 13 | 1446/1464 |

The same 18 historical presentation failures remain. No failed assertion is converted to PASS or waived by this portability change. `historical-guard-binding.json` is copied byte-for-byte from `evidence/historical-guard-binding.json` in the accepted owner ZIP. It preserves all 18 exact failure strings and their replacement contracts.

`qualification-contract.json` pins the accepted final summary, exact 18-script roster, adjusted per-script assertion totals and expected unchanged failure count. A runner must reject missing scripts, missing/extra assertions, mismatched exit codes, incomplete result footers, unbound failures and stale bindings. The browser/HTTP contract remains the accepted 378 checks; captures and logs are generated into ignored local receipts during qualification.

Run qualification through `python scripts/qualify-h9.py` after staging into an isolated source checkout. The runner builds, executes every test script, retains original logs and failures, checks exact historical bindings and runs the actual browser qualification. Passing this qualification grants no push, merge, tag or deployment authority.
