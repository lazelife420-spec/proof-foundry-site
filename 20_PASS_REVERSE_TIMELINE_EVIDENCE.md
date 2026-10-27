# 20-Pass Reverse-Timeline Evidence Log

**Candidate:** branch `codex/pf-modular-html-r1`, isolated worktree `C:\Users\KickA\Projects\Worktrees\pf-modular-r1` (base `0dd208c`, uncommitted owner-review changes on top).
**Directive:** `PF_WEBSITE_20_PASS_MODULAR_HTML_TRUTH_FILES_MASTER_2026-10-26.md` (owner, 2026-10-26).
**Compiled:** 2026-10-26, Factory, local Windows evidence only.
**Disposition:** owner-review candidate evidence. No push, merge, Pages upload, production change or release-state mutation performed.

Evidence grades: **CODE-OBSERVED** (tracked source/metadata inspected here), **LIVE-OBSERVED** (fresh byte-level observation of the live site or control-plane record), **HISTORIC-DOC / CHAT-RECOVERED** (dossier or prior-session record; context, not current proof), **PROPOSED** (spec only, not yet implemented), **HOLD** (denied/missing).

## 1. Custody and baseline records

| Record | Value | Observation |
|---|---|---|
| Candidate base HEAD | `0dd208c47ef827847d900e2c8e8142c110d166cc` "Restore the forged-materials homepage with a detailed hero PF" (2026-10-26T14:01:51-07:00) | git log, isolated worktree (CODE) |
| Base tree | `67a4a34433762eccbf7d436a75afd9ce52c31f19` | git rev-parse `HEAD^{tree}` (CODE) |
| Prior production source | `0c3043408beee4e99f3da5a1da8117e55bda961b` (2026-10-26T00:40:53-07:00), tree `0841402d7c41412abda0e84642b3cd611aa6a2b8` | git (CODE) |
| Historic forged-H2 | `c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce` (2026-10-04), tree `47445fe7606399780038e5f83e4b6bb71401a68b` | git (CODE) |
| **Live homepage byte parity** | `https://theprooffoundry.com/` == local `public/index.html` built from `0dd208c`: 34,105 bytes, SHA-256 `3CAE2EEED79221349B3EC1610191E2AF4F203A23686E087CFBC9C4965D043C8D`, identical | fresh `curl.exe` fetch + `Get-FileHash`, 2026-10-26 (LIVE+CODE) |
| Owner main checkout | `C:\Users\KickA\Projects\Active\proof-foundry-site`, branch `master`, HEAD `532cae1`, owner's uncommitted unstaged edits present (about.html, h9-homepage.css, h9-software.css, h9-software.js, index.html, more) | Reality Gate `rg_status` read-only observation; **preserved untouched, never stashed/reset** |
| Isolation check | candidate worktree clean before and after baseline build; only gitignored `public/` + `node_modules/` regenerated | git status (CODE) |
| Baseline build | `npm ci` (48 packages) + `pwsh -NoProfile -File scripts/build-site.ps1` -> exit 0; "7 visible products, 9 directory routes" | local run 2026-10-26 (CODE) |
| Builder facts | `scripts/build-site.ps1`: 3,582 lines, 221.4 KB, 83 top-level functions | local measure (CODE) — matches directive §0 |

## 2. The twenty passes, latest to earliest

| Pass | Window | Local verification in this candidate | Grade |
|---:|---|---|---|
| 01 | Oct 26 production | Live `/` byte-identical to the `0dd208c` build (§1). Cloudflare deployment `32d954aa-30ec-4c91-9895-dba5be5b7125` cited from directive; live bytes independently confirm `0dd208c` content is what production serves. Control-plane API not re-queried in this slice. | LIVE+CODE |
| 02 | Oct 26 owner verdict | Owner rejection of `0dd208c` restoration and cross-page discontinuity recorded in the directive; drives Slices 2-3. | CHAT-RECOVERED |
| 03 | Oct 26 regression `0c30434..0dd208c` | `git diff --stat`: 10 files, +488/-799 (index.html 44, pf-home-ledger.css 1099, build-site.ps1 26, check-home-receipt-truth.ps1 19, h3/h9/release tests, sitemap). User value to recover: home mark inspector, real preview cards (replaced by compact rows), weakened asset/receipt floors. | CODE |
| 04 | Oct 26 previous production | `0c30434` present, tree recorded; used as the better-before comparison in visual review. | CODE |
| 05 | Oct 26 re-ports | Commits verified present: `26bdb90` (Lights Out v11.2.0 onto V5 truth), `994a015` (PF Mark G header, About rewrite), `c49941e` (LO historical receipts as unlinked evidence), `17a1d4f` (unified test authority), `6d184c5` (v11.2.0 gate pins, LO pill wording), `72698ed` (Support 320px overflow), `1629ef0` (verifier v11 pipeline). | CODE |
| 06 | Oct 25-26 V5 recovery | `48e3e4e` "reconstruct V5 live production base (verified output parity)" + `V5_LIVE_BASE_CUSTODY.md`; `3a56218` git object confirmed NOT fetchable locally (as documented). | CODE |
| 07 | Oct 21-22 V5 cutover | `review/V5-CONTINUITY-REVIEW-1.md`, `-2.md` tracked in repo. Automated continuity reports did not replace design review. | HISTORIC-DOC |
| 08 | Oct 13-20 receipts/limits | `scripts/check-home-receipt-truth.ps1` present (modified by `0dd208c`); 64-hex digest identity preserved in generated truth outputs (re-verified in Slice 5). | CODE |
| 09 | Oct 7-8 governed mutation | Earlier candidate rejection reasons and the tool-scope denial/PATCH_INVALID record carried in the directive. | CHAT-RECOVERED |
| 10 | Oct 5-7 fabricated chassis | `FOUNDRY_PREMIUM_DESIGN_CANDIDATE.md` + `BRAND_SYSTEM_CANDIDATE.md` tracked at repo root. | CODE |
| 11 | Oct 4 H2 forged baseline | `c7d8a49` "Qualify frozen Proof Ledger renders with bounded plate paint contract" + `dd5763e`; H2 reference also at `C:\Users\KickA\Projects\Context\ProofFoundry\review\H2-MATERIAL-RHYTHM-2026-09-12`. Design witness only. | CODE |
| 12 | Oct 1-4 Truth Files | `043dc5d` "fix(truth-files): restore Cleanroom link and focus contrast", `c44a703` "establish Open Forge homepage and shared theme" verified. | CODE |
| 13 | Sep 29-30 Product Publisher | `719df66` (offline capsule pipeline), `7ce94dd` (fixture-only P7-P9), `199171c` (governed publisher integration) verified; `P0_CURRENT_PUBLISHING_ARCHITECTURE.md`, `PRODUCT_PUBLISHING.md`, P3-P9 docs tracked. Legacy publisher remains fixture-only (see §4). | CODE |
| 14 | Sep 27-28 unified site | `23a3292` (forge material identity), `b4bb76e` (corpus site v2), `cba419f` (continuous homepage journey), `06c7ac6` (ultimate continuous homepage) verified. Owner rule: continuity at site level, distinction at product level. | CODE |
| 15 | Sep 26-27 Product Module V2 | `97e70c7` (render product placements from module roles) verified; `PRODUCT_MODULE_V2.md` + `ADDING_A_PRODUCT.md` tracked; 7 real modules with content.html sizes: cache-vault 16.2 KB, cleanroom 11.4 KB, forgecast 13.0 KB, ghostlayer 14.1 KB, lights-out 31.4 KB, proofshot 24.8 KB, reality-gate 23.8 KB. | CODE |
| 16 | Sep 24-27 truth/proof/API delineation | Delineation recorded in directive; no extra local artifact required. | CHAT-RECOVERED |
| 17 | Sep 22 TF1 launch | `87c1328` "feat(site): publish Truth Files" verified; `/truth-files/` + 7 per-product records generated in baseline build. | CODE |
| 18 | Sep 21-22 registry/H14 | `7e7af7f` (registry-driven product rendering), `54e8de2` (visual refoundation) verified; baseline build emits `/__h14/` shells + modules + config, `/truth/` v1 + v2 JSON. | CODE |
| 19 | Sep 10-18 signature/H9 | `review/PF-WEB-SIGNATURE-2026-09-10/` + `H9_BINDING_*` docs tracked in repo. | CODE |
| 20 | Aug-Jun modular/storefront model | `README.md` / `DEPLOY.md` contain accurate history mixed with superseded instructions (see §3). No SPA/CMS reinvention performed. | HISTORIC-DOC |

## 3. Supersession rulings (restated from directive §2, confirmed against source)

1. `release-truth.json` + pinned shared reducer (`scripts/shared-release-truth.cjs`, `vendor/pf-shared-release-truth`) is the sole authority for versions, states, artifact identities, URLs, hashes, signing/withdrawal. `site-manifest.json` is presentation input + derived compatibility carrier only. Old "manifest is sole release authority" passages in `README.md`, `P0_CURRENT_PUBLISHING_ARCHITECTURE.md`, `ADDING_A_PRODUCT.md`, `PRODUCT_PUBLISHING.md` are historical.
2. Embedded historical markers `authority.adoption = RECONCILED_CANDIDATE`, `cutover = NOT_PERFORMED` in the authored model are foundation evidence, not current deployment truth; not "corrected" by this design tranche.
3. Lights Out current public release is Windows v11.2.0 (re-ported Oct 25); Reality Gate public record remains WITHDRAWN / no public download. Version strings render from the model only.
4. `deploy.ps1` sealed-artifact interface supersedes `DEPLOY.md` operational wording. No deploy executed in this tranche.

## 4. Gated boundaries observed (all left closed)

- **Legacy product publisher:** `SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED` present at `scripts/release-inputs.cjs:12-13`, `scripts/legacy-intake-fixture.mjs:18-19`, `scripts/pf-product-p3-p5.mjs:627`; described in `QUALIFICATION_AUTHORITY_REPAIR.md:39`, `PRODUCT_PUBLISHING.md:7`. No bypass attempted; P7-P9 remain fixture-only.
- **Reality Gate:** project `proof-foundry-site` = managed/available. `rg_test` = `SESSION_SCOPE_DENIED` (recorded from the prior session; boundary left closed, **not retried** per stop conditions). `rg_status` used read-only to observe the owner's dirty main checkout.
- **Cloudflare Pages:** production untouched; no preview, stage or production deploy started.

## 5. Generated route inventory and CSS cascade order (baseline `0dd208c` build)

25 public routes. Builder injects `foundry-world.css` + `pf-site-ledger.css` on all non-home routes and `pf-foundry-system.css` **last on every route** (`scripts/build-site.ps1:3000-3015`), so the shared system layer wins cascade ties everywhere. `styles.css` is first everywhere.

| Route (public/) | Body class | Stylesheet order |
|---|---|---|
| index.html | `pf-ledger-page` | styles.css -> pf-home-ledger.css -> **pf-foundry-system.css** |
| software/ | `studio storefront software-catalog-page` | styles.css -> studio.css -> experience.css -> h9-software.css -> foundry-world.css -> pf-site-ledger.css -> **pf-foundry-system.css** |
| about/ | `studio secondary-page product-page` | styles.css -> studio.css -> foundry-world.css -> pf-site-ledger.css -> **pf-foundry-system.css** |
| support/ | `studio secondary-page product-page product-support` | same as about/ |
| roadmap/ | `studio product-page product-roadmap` | same as about/ |
| proof/ | `studio secondary-page` | same as about/ |
| proof-standard/ | `studio secondary-page product-page` | same as about/ |
| founders/ | `studio secondary-page` | same as about/ |
| truth/ | `studio secondary-page product-page` | same as about/ |
| truth-files/ (+7 product records) | `studio secondary-page [product-page] tf-index|tf-page product-<id>` | styles.css -> studio.css -> truth-files.css -> foundry-world.css -> pf-site-ledger.css -> **pf-foundry-system.css** |
| 7 product routes (`cache-vault/` etc.) | `studio product-page product-<id> pp-system` | styles.css -> studio.css -> experience.css -> product-page.css -> foundry-world.css -> pf-site-ledger.css -> **pf-foundry-system.css** |
| 404.html | `studio secondary-page` | styles.css -> studio.css -> foundry-world.css -> pf-site-ledger.css -> **pf-foundry-system.css** |

Machine outputs: `/truth/index.json`, `/truth/products/<id>.json`, `/truth/schema-v1.json`, `/truth/v2/*`, `/proof/index.json`, `site-manifest.json`, `/__h14/*` runtime adapter (template markers there are by design, not leaks).

## 6. Holds and gaps

- **HOLD — Forged Continuity brief:** `PF_FACTORY_FORGED_CONTINUITY_MASTER_DIRECTIVE_2026-10-26.md`, referenced by master directive §6 as governing visual materials, was **not found on disk** (searched Downloads and `Projects\Context\ProofFoundry`). Visual work proceeds from master directive §6 + §10 rubric + historic H2 reference + live captures. If the owner supplies the brief, re-qualify before release.
- `3a56218` (lost V5 commit) and `a32e2211` (Cloudflare deployment ID, not a git object) are not fetchable locally; custody narratives in `V5_LIVE_BASE_CUSTODY.md` govern.
- Cloudflare control-plane deployment record for `32d954aa` is directive-cited; live byte parity independently confirms the served content matches `0dd208c`.
- Pre-existing suite failures at base: `test-pf-product-p3-p5.mjs` / `p6.mjs` fail identically at `0c30434` and `0dd208c` (legacy-intake fixture expectations; documented in QUALIFICATION_AND_CUSTODY.md).
