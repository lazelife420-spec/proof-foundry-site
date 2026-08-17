# Reality Gate — Story + Brand Pass Evidence

**Date:** 2026-08-17
**Site repo:** `C:\Users\KickA\Desktop\proof-foundry-site` (master, local-only commit)
**Product repo (read-only this pass):** `C:\Users\KickA\OfflineForge_Sovereign_V2` @ `7a3e471` (branch `investigate/heartbeat`) — only untracked files present; no tracked modifications made.

---

## 1. Source of truth (verified this pass, not doc-derived)

| Fact | Value | How verified |
|---|---|---|
| Product version | Reality Gate **v1.1.0** | real app About panel screenshot; `package.json` |
| Source checkpoint | `7a3e47136341951dcb8365db8c40da8553edd6c5` | repo HEAD; BUILD-INFO; page prior value re-verified |
| Build date | 2026-08-15T23:25:00-07:00 | BUILD-INFO.txt in pilot package |
| Audit date / verdict | 2026-08-15 · **PILOT READY**, no blockers, no overstated claims | REALITY-GATE-PRE-PILOT-AUDIT.md |
| Audit HEAD (post-build audit checkout) | `c78e9d87` | audit doc (distinct from build checkpoint `7a3e471`; page cites the build checkpoint) |
| Artifact hash chain | ZIP = R2 artifact = build manifest = `4A68DE375E592AECF173B4AAAE3FDFAEEDACCE5F821F84F11C25AD345A0B62CB` | sha256 of downloaded ZIP == `.sha256.txt` (strip filename suffix) == manifest value — chain intact |
| Installer EXE SHA-256 | `0B13FD5DA6FA2855B02CC1363068CBE8B684B58B7208291A542968162627387B` | BUILD-INFO.txt (EXE inside ZIP) |
| Test suite (canonical headline) | 269/269 static | audit §NOTE ON STATIC TESTS: same coverage as old 827/827, runner-counting difference only |
| Suite composition | Static 269/269 · Live registry 24/24 (R4 Slice 2 receipt `npm run test:live`) · Installed runtime 20/20 (hardening receipt `tests/hardening_tests.cjs`) | docs/archive/receipts/R4-Slice2-Freeze-Receipt.md; docs/OFFLINEFORGE_V1.2.0_HARDENING_RECEIPT.md |
| Electron security | `nodeIntegration:false`, `contextIsolation:true`, `sandbox:true` | audit §11; main.js |
| CI isolation | `git clone --local --no-hardlinks --no-checkout` into `cache/ci/workspaces`, whitelisted commands only | server.js source; live run console in screenshot |
| Path safety | blocks UNC, drive roots, system dirs, `%LOCALAPPDATA%`/`%TEMP%`; allows home-root paths outside AppData | desktop/projectPathSafety.js; observed live (temp path rejected, home-root path accepted) |
| App accent (identity) | `--accent: #2dd4bf` | web/style.css |
| Known non-blocking bugs | BUG-001 port discrepancy (standalone), BUG-002 IPv4-only loopback binding; neither affects packaged users | audit §7 |
| Captures are real UI | all screenshots produced by the running Electron app in a sandboxed copy of source | see §5 |

## 2. Capability truth table (UI exposed + working standard)

Standard applied: **UI exposed + working > implemented but hidden in code > planned in docs**.

| Capability | Claim on page | Evidence |
|---|---|---|
| Passive onboarding / Add repo | Working (passive: read-only registration, no repo mutation) | real run: fresh repo-less launch → onboarding overlay (4 steps) → Add Repo via the app's real `prompt()`-driven dialog → mapping POST accepted at a safe path; repo listed; no git mutation observed (`git status` clean) |
| Dependency map | Working | real run: LOCAL CONTROL for source/commits/branches/history; EXTERNAL_DEPENDENCY for remote push/fetch/clone; project ID + evaluation time shown |
| Continuity card | Working | real run: Work STRONG · Proof NOT TESTED · Recovery NOT TESTED · Custody UNKNOWN · Provider Exposure EXTERNAL_DEPENDENCY (honest pre-drill state shown on page) |
| Continuity drill | Working (honest outcomes) | real run: source PASSED, CI PASSED, build INCONCLUSIVE, recovery INCONCLUSIVE, persistence PASSED → overall **INCONCLUSIVE**, receipt **PERSISTED**; isolation: provider credentials removed, external git remotes absent, offline tooling ENFORCED, observed provider contact NONE |
| Proof Ledger | Working | real run: ledger row `demo-repo · CI_RUN 4728fe950c7c · PASSED · receipt integrity YES` |
| CI pipeline + signed receipts | Working | real run: run `c5d53f98-…` completed PASSED, Runroom trust **VERIFIED**, "VERIFIED RECEIPT" badge, console: isolated workspace + "Run verification receipt cryptographically signed (ECDSA P-256)" |
| Receipt export | Working | run receipt exported to project workspace `.proof/ci/latest-receipt.json` (gitignored in demo) |
| Recovery Vault | Working | real UI: bundle verification + signed receipt path exercised (drill receipt persisted; bundle path under app data) |
| Remote Hub | Working | real run: identity (path, branch `master`, commit, working tree CLEAN), origin (github.com example) + backup (gitlab.com example) remotes, 7 provider cards |
| About v1.1.0 | Working | real run |
| Autonomous failover / provider resurrection | **Absent — not claimed** | page frames downtime capability as prepared continuity/recovery only, per scope approval |
| Pixel/photo capture | n/a (not this product's domain) | no such claim on page |

**Capture caveats (all disclosed):**
- Screenshots run the app under its own documented test-isolation flags (`OFFLINEFORGE_TEST_MODE=1`, `OFFLINEFORGE_TEST_NO_AUTHORITATIVE=1`) with `OFFLINEFORGE_DATA_ROOT` redirected to temp.
- The demo repository is synthetic (`C:\Users\KickA\.rg-capture-workspace\demo-repo`, disposable): README + demo file + synthetic `package.json` manifest, `.forge-ci.json` workflow (`git status --porcelain`, whitelisted), `.gitignore`, commits `646c0ec` → `6060f8d` → `14d16f5` → `4728fe9`, GitHub + GitLab **example** remotes.
- Electron suppresses native `prompt()`; the capture driver shimmed `window.prompt` with a queue to drive the app's real Add-Repo dialog (the app's own code path).
- One drill step-format divergence found during capture: the CI runner honors `{command, args}` while the drill executor's CI phase honors `{cmd, args}`; the demo workflow uses the intersection format so both paths execute the same step. Not a page claim; recorded here for honesty.

## 3. Claims discipline (included / excluded)

Included on the page, each qualified:
- Real receipts replace the previous **illustrative** receipt (explicit: "the illustrative one is gone").
- INCONCLUSIVE drill shown as INCONCLUSIVE, with per-phase states and the reason (nothing executable to build/restore in the demo) — no faked pass.
- Continuity card states shown verbatim, including NOT TESTED / UNKNOWN readings.
- Downtime capability framed as **prepared continuity/recovery**, with an explicit "not autonomous failover" sentence.
- SmartScreen "More info → Run anyway" guidance; pilot-stage caveats listed (Windows-only, no auto-update, no cloud dashboard).
- BUG-001 / BUG-002 disclosed in the limitations list with the packaged-app qualification.
- Screenshot provenance disclosed inline: real app, synthetic demo repo, nothing real touched.
- Verified receipt defined precisely: proves record provenance (which run/commit/machine/outcome, signed, unmodified) — explicitly **not** a code-correctness claim.
- Artifact chain explained (ZIP SHA-256 = checksum file = build manifest), with a local verification command.

Excluded from all copy:
- Autonomous failover, provider resurrection, "can't go down" messaging.
- Any guarantee of future availability (continuity results are evidence of checks).
- Any claim about macOS/Linux builds, auto-update, or a remote dashboard (none exist).
- The runner-counting note (269/269 vs old 827/827) is documented **only** here and in the product audit — not on the page (per scope instructions).
- No mention of the internal SmartDecode-style HTTP bridge or dev shell (ProofShot-exclusive detail; not present on this page).

## 4. Hash chain (verified end to end this pass)

| Link | Value | Status |
|---|---|---|
| R2 artifact (ZIP) SHA-256 | `4a68de375e592aecf173b4aaae3fdfaeedacce5f821f84f11c25ad345a0b62cb` | computed from the published ZIP |
| Published `.sha256.txt` | same digest (strip filename suffix before compare) | match |
| Build manifest / BUILD-INFO | same digest recorded at build time | match |
| Installer EXE inside ZIP | `0B13FD5DA6FA2855B02CC1363068CBE8B684B58B7208291A542968162627387B` | BUILD-INFO, not re-extracted (pilot package on disk) |

## 5. Screenshot manifest (all real app UI; all demo data synthetic)

Each 1440×900 PNG staged at `assets/reality-gate/`:

| File | Real content | Beat |
|---|---|---|
| 00-onboarding.png | onboarding overlay, 4 steps (Add repo → Analyze → Continuity → Proof), repo-less fresh launch | Add |
| 01-home-continuity.png | continuity card: Work STRONG · Proof/Recovery NOT TESTED · Provider Exposure EXTERNAL_DEPENDENCY | Continuity |
| 02-dependency-map.png | dependency map: LOCAL CONTROL ×4, provider exposure list, project ID | Understand |
| 03-recovery-drill-receipt.png | drill receipt: drill ID `a5bb7179-…`, INCONCLUSIVE overall, PERSISTED receipt, isolation record | Prove |
| 04-recovery-bundle-verified.png | Recovery Vault drill receipt view | Recovery |
| 05-recovery-prove-passed.png | recovery drill receipt (prove path) | Recovery |
| 06-remote-hub.png | Remote Hub: identity CLEAN @ `4728fe95`, origin+backup remotes, 7 provider cards | Understand |
| 07-about.png | About: REALITY GATE v1.1.0, Proof Foundry product | Release |
| 08-ci-run-complete.png | Runroom: SUCCESS + VERIFIED RECEIPT, console with isolated clone + ECDSA signing line, trust VERIFIED | Verify |
| 09-proof-ledger.png | Proof Ledger row: demo-repo CI_RUN `4728fe950c7c` PASSED, receipt integrity YES | Prove |

`capture-diag.json` (staged alongside): the driver's per-beat DOM snapshots for every capture.

## 6. Build + validation results

- `build-site.ps1 -ValidateOnly`: manifest validated, 0 errors.
- `build-site.ps1`: build complete, 6 visible products, 10 directory routes.
- Responsive sweep (12 routes × 7 widths, real horizontal-scrollability assertion): **85/85 passed**. RG route: no horizontal overflow at 320/375/390/768/1024/1440/3440.
- Image load validation on RG route: 12 document images (10 beat shots + 2 logo mark), 0 broken, 0 console errors at all 5 checked viewports after scroll-through (deliverable captures re-taken with per-image load wait).
- Before-state capture: 0 console errors, no broken images.
- Template hygiene in built output: no leftover `{{product.*}}`, no `ILLUSTRATIVE` receipt string, all 10 shots referenced, proof strip + suite line rendered.
- Visual pixel review by the agent: not performed (image viewing unavailable in this session); correctness is backed by per-beat DOM snapshots in `capture-diag.json` and image-load/HTTP checks. Recommend a human eyeball on `after-desktop-full.png`.

## 7. Before / after (same build pipeline, true states)

| Pair | Before (commit `HEAD`) | After (this pass) |
|---|---|---|
| desktop (1440×900 fold / full-page) | before-desktop-fold.png / before-desktop-full.png | after-desktop-fold.png / after-desktop-full.png |
| mobile (390×844 fold / full-page) | before-mobile-fold.png / before-mobile-full.png | after-mobile-fold.png / after-mobile-full.png |
| 320 / 768 / 3440 fold | — | after-320-fold.png / after-768-fold.png / after-3440-fold.png |

Page height @1440: 5114px (before) → 12191px (after). The old page's illustrative receipt and hardcoded checkpoint are gone; the new page carries real receipts, 10 staged captures, and the suite-composition card.

## 8. Repo state

Changed files this pass:
- `reality-gate.html` (full rewrite: 8 beats, teal primary accent `#2dd4bf`, cyan secondary, real receipts, honest limits, provenance disclosure)
- `site-manifest.json` (reality-gate: summary tightened, build note + releaseNote with suite composition)
- `assets/reality-gate/` (10 screenshots + capture-diag.json — new)
- `reality-gate-story-evidence/` (EVIDENCE.md + 11 before/after PNGs — new)

Untouched: `proofshot.html` (frozen at `a7daabd`), all other product pages, the product source repo.

Local commit only. No push, no deploy. Disposable capture workspace (`C:\Users\KickA\.rg-capture-workspace`), temp sandbox, and temp data roots are removed after this pass.
