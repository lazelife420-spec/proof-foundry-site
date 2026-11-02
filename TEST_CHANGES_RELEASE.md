# Release/runtime test changes

Scope: test-only successor contracts. No authored truth, product page, CSS/JS, build source, commit, push or deployment changes by this worker.

## Source defect requiring main-agent coordination

Current isolated output `/software/` presents Lights Out as `Windows · v11.2.0 / Android · v11.1.1` with no adjacent `not offered here` or `no companion download`. Canonical release data still records no companion file/checksum, and the product, Support, Roadmap and Truth File explicitly say no companion download is offered. The replacement companion test deliberately remains failing until the directory qualifies that Android version. Do not change release truth to fix this presentation defect.

## Edit ledger (old assertion → reason → replacement)

1. `test-receipts-invariants.ps1`, TEST 7: scan every generated HTML asset for filesystem destinations → `__h14` partials/content/shells are Function renderer inputs, not published static documents → scan public static documents outside `__h14`, assert at least 25 are included. Runtime navigation coverage is explicitly transferred to the actual Pages Function checks in H14 below; no dummy static destinations created.
2. `test-h14-runtime-state.ps1`, build setup: rebuild shared `public/`, then copy it → races concurrent qualification/source work → build with `-OutDir` in the suite's unique temp directory, assert exit 0 and expected shadow assets, then copy only that output.
3. H14 runtime navigation: regex-only link presence → static-scanner successor must prove actual Function resolution → collect unique rendered `/__h14/` links from catalog and product documents (shared header/footer included), request each through Wrangler Pages, require 200, live/cache provenance, revision A, resolved real page content or schema-v1 JSON with matching revision, plus catalog/product identity markers. Static placeholders cannot pass.
4. H14 revisionSeq negatives: `$rn.Content -notmatch $case[2]` with unescaped versions → `9.9.1` matches unrelated SVG path bytes → escape exact version and apply numeric/dot boundaries to decoded visible text; additionally require rejected revision not adopted in response headers. All original malformed-sequence cases remain.
5. `test-release-truth.ps1` and `test-truth-files.ps1`, fixed `public/` input → isolated runs otherwise require mutating shared output → optional `-PublicDir`, default unchanged. Truth Files assertions unchanged.
6. Release withdrawal directory: exact old card chips `Withdrawn · unavailable` / `v1.1.0 withdrawn · no current public download` → directory now distinguishes internal development from a historical public channel → require the actual Reality Gate directory entry to say public v1.1.0 withdrawn, and software to state no public successor; stale Developer Pilot claim still forbidden.
7. Release sweep: globally forbid `Explore Reality Gate` → product exploration is not itself a public-download claim when adjacent state explicitly says withdrawn/internal → retain obsolete active-product claims ban; independently require directory withdrawal/internal context and record-only destination (items 6, 10).
8. Reality Gate hero: exact full canonical paragraph and attribute-free status tag directly after h1 → current hero uses concise equivalent availability summary and `data-release-status` → require explicit WITHDRAWN/Windows/v1.1.0/no-current-download status immediately after headline plus separate-internal-work/no-public-download statement. Full canonical statement remains required verbatim on About, Support, Roadmap, Truth Files.
9. Reality Gate film: exact `<section class="film-section" id="film">` → additional composition classes and attributes made an empty match → identify section semantically by `id="film"`; retain all recording-scope assertions unchanged.
10. Reality Gate card: old product-card markup and compare-checkbox count → directory has no comparison UI → require actual directory entry links to its scoped system record, no comparison/download link, system record says Withdrawn/do not distribute/no public successor and links to Reality Gate history.
11. Companion: require Home release-index companion labels → Home no longer enumerates releases → require Home main content makes no Android/companion claims, Truth File retains `Companion v11.1.1 · not offered here`, actual directory qualifies Lights Out Android as unoffered and keeps Cache Vault Android v0.3.1 available. This exposes the real directory defect above rather than waiving it.
12. Cleanroom candidate: old card repeats exact candidate paragraph → directory labels website v1.0.7 current and newer GitHub version unreconciled → require actual Cleanroom directory entry has that current version, unreconciled warning and product route, and software release context explicitly says v1.0.7/v1.0.10 unreconciled, no promotion proposed. Exact canonical on-hold candidate wording remains required on product, Support, Roadmap, Truth File; candidate record NOT_ESTABLISHED/unpublished checks unchanged.
13. Withdrawn Home row: require obsolete release-index table row → Home has no product release table → require Home does not promote withdrawn product via direct product route or old row, does link directory, and actual directory entry explicitly says withdrawn. Historical proof-card assertions unchanged.
14. Lights Out hero caption: exact `CAPTURED · Lights Out v11.1.2 dry run` → truthful expanded hero caption changed wording → still bind original full-frame image and require v11.1.2, dry-run countdown, historical-image disclaimer, distinct public v11.2.0.
15. Cleanroom hero caption: exact `no cleanup candidates found` / `Interface capture from v1.0.6` → current caption is more explicit → still bind same image and require v1.0.6, completed scan with no candidates, no restore history, and no populated-archive/v1.0.10 demonstration claim.
16. Home full-frame card: require obsolete Lights Out featured card → Home contains no product capture → require no Lights Out image/cropped stamp/old featured-card markup and reachable directory.
17. Software full-frame card: old `product-card data-product` selector → actual directory uses `data-directory-entry` → same original full-frame PNG requirement and cropped filename ban against the real Lights Out entry.

## Results

Initial current isolated build: exit 0. Baseline release: 152 passed / 12 failed.

Executed on branch `factory/pf-main-site-finish`:

| Suite | Result |
|---|---|
| `test-receipts-invariants.ps1` | 74 passed / 0 failed; exit 0 |
| `test-h14-runtime-state.ps1` | 89 passed / 0 failed; exit 0 |
| `test-truth-files.ps1 -PublicDir C:\Users\KickA\AppData\Local\Temp\pf-release-worker-current` | 239 passed / 0 failed; exit 0 |
| `test-release-truth.ps1 -PublicDir C:\Users\KickA\AppData\Local\Temp\pf-release-worker-current` | 163 passed / 1 failed; exit 1 |

H14 followed eleven unique actual rendered Function destinations, including catalog, all seven products and three Truth endpoints. All five malformed revisionSeq controls pass. Temporary H14 and invariant fixtures were cleaned by their suites; isolated current release output remains available at `C:\Users\KickA\AppData\Local\Temp\pf-release-worker-current`. Shared `public/` was not built or overwritten by this worker. `git diff --check` for all four assigned tests exits 0.

Remaining failure: `Home makes no companion claim; directory and Truth File distinguish the unoffered Lights Out companion from available Cache Vault Android`. Main must qualify the directory Lights Out Android version as unoffered, then rebuild isolated output and rerun release/truth qualification. No change to authored truth is necessary or permitted.
