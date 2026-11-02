# Remaining qualification contract changes

Scope: H3, H4, H6, H7C only. Existing product pages are preserved, not redesigned.
No shared release authority, production source, generated `public/`, CSS, JS
application code, product modules, release facts, or release permissions were edited
by this worker. The new JavaScript file is a test-only helper. No commit, push,
deployment, credential access, or original/Codex worktree access occurred.

## Assertion-by-assertion changes

| Test / old assertion | Why outdated | Current equivalent contract |
| --- | --- | --- |
| H3 P0: exact `<section class="pp-origin" id="origin">` | Origin now has additional composition classes/data attributes. | Require a semantic `section` with both the `pp-origin` class token and `origin` ID, regardless of attribute order or additional classes. Neither identity may disappear. |
| H3 P0: `.pp-origin {` must be owned by `product-page.css` | Authored Reality Gate composition moved to `product-worlds.css`. | Built page must load `product-worlds.css`; that shipped sheet must define `.product-reality-gate .archive-origin-ledger`. Existing origin copy and obsolete translucent-background checks remain unchanged. |
| H3 P2: `finder-intents` and `data-compare` on Software | Main-site Products uses a searchable grouped directory, not the retired comparison catalog. | Require a search-role directory form, search input, group select, and accessible live result count. |
| H3 P2: “Choose up to three tools to compare.” | Comparison is no longer offered. | Require zero-result guidance and Clear/reset recovery; reject old comparison controls/promises. |
| H3 P2: mobile CTA panel must use `styles.css` margin-top `0.9rem` | Active navigation ownership moved to `pf-foundry-system.css`; the old margin is not a behavior contract. | Require that shipped system sheet to be loaded, its open mobile panel to use `display:flex`, and the actual Support CTA to remain inside shared navigation markup. The separate old `display:none` regression guard is retained. |
| H3 preservation: hero → `ledger-featured` → chain | Home no longer features product cards; browsing belongs in Products. | Require ordered hero → orientation → five-stage proof chain → principle → records → support, with all six sections present, exactly five numbered steps and the chain heading. Old portfolio/evidence markup remains forbidden. |
| H3 preservation: `ledger-button` “Browse software” and exactly seven `product-card`s | Current CTA and editorial lineup differ. | Hero must offer “Browse Products” to `/software/`; directory identity set must be exactly Cache Vault, Lights Out, Cleanroom, GhostLayer, ForgeCast, Hardline Zero, CrossPoint, Reality Gate, Proof Foundry App. ProofShot must remain a historical record, not a featured entry. |
| H3 preservation: exact V5 subtitle/description and `ledger-title` ID | Main-site introduction replaces the V5 markup, not the brand principle. | Inside the hero only, require exact “Real software leaves a record.” and “Useful tools. Deliberately made. Public releases you can inspect.”, a proof-standard link, and no 64-digit release digest. |
| H4 H3 preservation: exact origin opening tag | Same additional-class/attribute issue as H3. | Same semantic section/class-token/ID check as H3. Every canonical, sitemap, robots, redirect, provenance, release-state and freshness assertion remains intact. |
| H6: source and output must contain exact `#526248` kicker declarations (two assertions) | These source constants no longer own the rendered surface. | Render the built, JS-enhanced Cache Vault page in independent headed Chrome. Measure `.archive-demo .kicker` using the actual active cascade and composited ancestor background, at 1440px and 390px. Both must meet 4.5:1. |
| H6: source and output must contain exact `#5a6a50` clip-status declarations (two assertions) | Same source-constant issue; active status paint now belongs to the product world. | Measure actual `.clip-status` foreground/background at both widths, initially and after a real search input event produces zero results. Each must meet 4.5:1 and filtered text must report zero. |
| H6: two ratios calculated from four hardcoded color constants | Arithmetic on unused colors does not verify the site. | Six rendered WCAG checks replace those constant calculations: kicker, initial status, filtered status at each width. RGB/RGBA values come only from `getComputedStyle`, with alpha compositing and sRGB relative luminance. |
| H6: source and output must omit `#586a4f`/`#6b7b60` (two assertions) | A color token elsewhere says nothing about target contrast. | No color blacklist. Actual contrast is authoritative. Hidden/missing targets, unknown colors, unresolved transparent canvas, gradients/images, painted pseudo-elements, opacity/filter/blend uncertainty fail closed rather than claim a pass. |
| H7C: five `body.pp-system.product-*` theme selectors must live in `product-page.css` | Active product themes changed owner and selector shape. | Require actual `.product-lights-out`, `.product-cleanroom`, `.product-ghostlayer`, `.product-forgecast` theme rules in shipped `product-worlds.css`; ProofShot's preserved historical `.product-proofshot` theme remains in shipped `product-page.css`. Every target page must load the product-world sheet; ProofShot must also load its historical theme owner. Body `pp-system` and product identity assertions remain. |
| H7C GhostLayer: features → boundary → preview | The staging preview now precedes features and includes its boundary warning. | Enforce overview → preview → boundary → features → download → onboarding → proof → privacy. Additionally require temporary-disk-copy and interrupted-edit leftover warnings inside the preview, before features. |
| H7C ForgeCast: features → preview → story | Its sample-day workflow and story now lead features. | Enforce overview → preview → story → features → download → onboarding → proof → privacy; no sections removed. Other product hierarchy checks stay unchanged. |
| H7C ProofShot: hero must use `og-image.png`, rejecting every HyperSnatch/build mention | Current preserved history intentionally shows an explicitly historical capture; no current runtime qualification is claimed. | Require exactly the preserved Candidates image, historical HyperSnatch v1.6.18 identity in alt and caption, explicit denial of current ProofShot v2.0.0 runtime capture, and unresolved/unfeatured licensing/media disclosure. Continue rejecting retired workbench images. Installer, unsigned/critical-warning, migration and closed technical evidence guards remain. |
| H7C: Software `products-grid` plus six `data-product` card-presence assertions | Current main-site browsing uses directory entries; ProofShot is not featured. | Require the `pf-directory-grid` results container. Each of nine intended entries must include a heading, purpose, availability and exploration link. ProofShot must be absent from directory entries while retaining historical product and Truth File links. |
| H7C: `studio.css` may not make ForgeCast/ProofShot full-width or tilt ForgeCast (three assertions) | That stylesheet does not own current directory geometry, and ProofShot has no directory card. | Require active `h9-software.css` equal three-column directory tracks and reject a ForgeCast-specific full-width span or 6-degree tilt there. Historical ProofShot preservation replaces its inapplicable card geometry check. |
| H3/H4/H6: fixed `public/` input only | Main agent owns rebuilds and may replace that directory during parallel validation. | Add optional `-PublicDir` without changing defaults; use an independent external build fixture for conclusive validation. H7C already supported this parameter. |

New helper: `scripts/test-h6-rendered-contrast.mjs`. It uses Node's native HTTP,
WebSocket and child-process APIs, an ephemeral loopback server/CDP port and a new
temporary Chrome profile. Chrome is **headed**, never attaches to desktop/9331,
blocks non-fixture page requests, closes its own browser and removes only its own
temporary profile. `PF_TEST_CHROME` optionally supplies a Chrome executable.
H6 `-NegativeControl` forces foreground to the computed background in the browser
DOM only. No built file or application source is changed by that control.

## Exact validation

Worktree: `C:\Users\KickA\Projects\Active\pf-site-main-finish`

Branch: `factory/pf-main-site-finish`

Isolated output:
`C:\Users\KickA\AppData\Local\Temp\pf-remaining-contracts-20261102-01`

Build (exit 0):

```powershell
pwsh -NoProfile -File C:\Users\KickA\Projects\Active\pf-site-main-finish\scripts\build-site.ps1 -OutDir C:\Users\KickA\AppData\Local\Temp\pf-remaining-contracts-20261102-01
```

Each row used `pwsh -NoProfile -File <worktree>\scripts\<script> -PublicDir <isolated-output>`:

| Script / options | Result |
| --- | --- |
| `test-h3-trust-to-action.ps1` | exit 0; 60 passed, 0 failed |
| `test-h4-metadata-discovery.ps1` | exit 1; 465 passed, 9 failed; genuine freshness defect below |
| `test-h6-p4-polish.ps1` | exit 0; 6 passed, 0 failed |
| `test-h7c-product-pages.ps1` | exit 0; 78 passed, 0 failed |
| `test-h6-p4-polish.ps1 -NegativeControl` | expected exit 1; 0 passed, 6 failed; all six actual ratios 1.00:1 |
| `test-h4-metadata-discovery.ps1 -NegativeControl` | expected exit 1; 467 passed, 9 failed; simulated Cache Vault content date 2026-11-03 is rejected by the unchanged freshness assertion |

Actual rendered colors at **both** widths:

* Kicker: RGB(201,176,131) over RGB(23,27,26), **8.295007517353259:1**.
* Initial/filtered clip status: RGB(75,94,67) over RGB(227,230,217),
  **5.563627772002623:1**. Search changed “6 sample clips” to “0 sample clips”.

Scoped `git diff --check` on the four assigned PowerShell tests exits 0.
An unscoped check also surfaced unrelated concurrently edited files; no changes
were made to those files by this worker.

## Genuine source defect for parent coordination (not waived)

H4's previously valid latest-public-content date checks now detect the real
2026-11-01 content changes in commit `2338db3`. The authored sitemap still carries
older dates. All nine require reconciliation to their real content event
(currently **2026-11-01** according to the unchanged committed-input derivation):

| Route | Current built/authored lastmod |
| --- | --- |
| `/` | 2026-10-27 |
| `/software/` | 2026-10-25 |
| `/cache-vault/` | 2026-10-20 |
| `/cleanroom/` | 2026-10-20 |
| `/forgecast/` | 2026-10-20 |
| `/ghostlayer/` | 2026-10-20 |
| `/lights-out/` | 2026-10-25 |
| `/proofshot/` | 2026-10-20 |
| `/reality-gate/` | 2026-10-20 |

Parent must coordinate the authored `sitemap.xml` correction and rebuild, then
rerun H4. This worker did **not** edit sitemap/build/application/product source
or change freshness expectations to obtain a green result.
