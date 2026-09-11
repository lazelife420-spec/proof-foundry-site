# Signature Homepage QA Results

## Environment

- Repository: local `proof-foundry-site`
- Browser: Chromium through the Factory embedded CDP session
- Local URL: `http://127.0.0.1:4173/`
- Build: PowerShell generator, generated `public/`
- Source base: `master` at `92cd03e`
- Date: 2026-09-10

## Executed checks

| Check | Result | Evidence |
|---|---|---|
| Local manifest-driven build | PASS | build output: 7 products, 0 errors |
| Existing receipt invariants | PASS | 54/54 in `test-receipts-invariants.ps1` |
| Signature source/output checks | PASS | 15/15 in `test-signature-home.ps1` |
| JavaScript syntax | PASS | `node --check experience.js`, `node --check site.js` |
| Diff whitespace | PASS | `git diff --check` |
| Homepage accessibility audit | 0 violations; incomplete adjudicated in pass three | axe 4.12.1: 0 violations, 26 passes, 1 incomplete gradient-background contrast heuristic. That follow-up is done: `CONTRAST_ADJUDICATION.md`, one real failure found and fixed |
| Hero pointer/state switching | PASS | Cache Vault → Reality Gate; name, line, route, alt, pressed state updated |
| Hero keyboard arrow switching | PASS | Cache Vault → Reality Gate; focus and stage state updated |
| Contextual film action | PASS | Reality Gate and Cache Vault link to `#film`; Lights Out hides the link |
| Android filter | PASS | 3 products: Cache Vault, Lights Out, ForgeCast |
| Two-product comparison | PASS | dialog open, two comparison columns, close control present |
| Browser console | PASS | no introduced console output observed in local session |
| Generated route existence | PASS | homepage, proof, seven products, Founders, Roadmap |

## Evidence files

### First pass (embedded CDP)

- `screenshots/before/home-390x844.png`
- `screenshots/after/home-390x844-fixed.png`
- `screenshots/after/home-390x844-final.png`
- `screenshots/states/hero-reality-gate-390x844-fixed.png`
- `screenshots/states/filter-android.png`
- `screenshots/states/comparison-two-tools.png`

The wide desktop screenshots from the first pass are retained, but the embedded CDP capture showed repeated/tiled content at the requested wide viewport. They are not used as proof of desktop visual acceptance.

### Second qualification pass (clean Chrome headless)

- `screenshots/qualification/home-1920x1080.png`
- `screenshots/qualification/home-1536x864.png`
- `screenshots/qualification/home-1440x900.png`
- `screenshots/qualification/home-1366x768.png`
- `screenshots/qualification/home-1024x768.png`
- `screenshots/qualification/home-820x1180.png`
- `screenshots/qualification/home-430x932.png`
- `screenshots/qualification/home-390x844.png`
- `screenshots/qualification/home-360x800.png`
- `screenshots/qualification/home-wrapper-430.png`
- `screenshots/qualification/home-wrapper-390.png`
- `screenshots/qualification/home-wrapper-360.png`

Clean Chrome captures resolved the first-pass desktop tiling artifact. Nine direct viewport captures span 360–1920 width. Three wrapped phone captures at 360, 390, and 430 confirm correct rendering inside the review iframe at device scale.

## Second qualification pass

| Check | Result | Evidence |
|---|---|---|
| Clean Chrome viewport captures | PASS | 9 captures at 360, 390, 430, 820, 1024, 1366, 1440, 1536, 1920 |
| Wrapped phone captures | PASS | 3 captures at 360, 390, 430 inside review iframe |
| Asset content-type/MIME audit | PASS | 61/61 assets served with correct type via plain static server |
| Accessibility re-check (axe) | 0 violations; incomplete adjudicated in pass three | 0 violations, 26 passes, 1 incomplete gradient contrast heuristic, resolved in pass three (`CONTRAST_ADJUDICATION.md`) |
| Hero keyboard switching | PASS | Arrow keys update stage atomically |
| Mobile menu toggle | PASS | Opens and closes correctly |
| Android filter | PASS | 3 products: Cache Vault, Lights Out, ForgeCast |
| Two-product comparison | PASS | Dialog opens with two columns, close control present |
| Reduced-motion state | PASS | Page is usable with reduced-motion preference |
| Forced image failure | PASS | Prior product remains visible, `aria-busy` clears, fallback message appears |

The clean Chrome captures resolved the first-pass desktop tiling artifact that was caused by the embedded CDP harness, not by page overflow. Apparent mobile clipping in the first pass was confirmed to be host/device-scale artifact, not a page layout issue.

## Third qualification pass

This pass exists because the previous two reported "0 violations, 1 incomplete" and treated that as
finished. An incomplete result is not a pass, so the incomplete was adjudicated by hand, and the
checks that had been deferred were actually run.

| Check | Result | Evidence |
|---|---|---|
| Gradient contrast, adjudicated by hand | PASS after correction | 44 nodes scored; one real failure found at 3.91:1 and fixed to 5.11:1; see `CONTRAST_ADJUDICATION.md` |
| 200% browser zoom | PASS | 640 x 360 CSS px: 0 px horizontal overflow, 0 overflowing elements |
| 400% reflow (WCAG 2.1 SC 1.4.10) | PASS | 320 x 256 CSS px: 0 px horizontal overflow, single-column reflow |
| Phone widths 390 / 360 / 320 | PASS | 0 px horizontal overflow measured at each |
| JavaScript disabled | PASS | 16/16 content assertions on generated HTML; renders verified at 1280 and 390 |
| Layout is CSS-only, not JS-gated | PASS | no init-time class or style on `body`/`html` affects layout |
| Image loading | PASS | 11/11 content images resolve; 12th is `.gallery-full`, the on-demand viewer, empty by design |
| Asset content signatures, all output | 144/147 PASS | 3 pre-existing failures outside this candidate, see below |
| Second browser, same engine (Edge 152, Blink) | PASS | render matches Chrome 153 |
| Full-page owner review captures | PASS | 1920, 1440, 1024, 820, 390 with all images resolved |

### axe counts, this run

| Field | Value |
|---|---|
| violations | 0 |
| incomplete | 1 rule (`color-contrast`), 44 nodes |
| passes | 43 |
| inapplicable | 46 |

The pass count differs from the 26 recorded in the first pass because rule applicability varies with
what is rendered at audit time. The figure that matters is unchanged: 0 violations. The single
incomplete is the gradient limitation described in `CONTRAST_ADJUDICATION.md`, and it will persist for
as long as the gradient does.

### Defect found and corrected in this pass

`.theater-context` ("Select an instrument. See the work.") measured 3.91:1 against the lightest point
of the product-stage gradient, below the 4.5:1 AA threshold for normal text. Axe had never scored it,
so the two previous passes did not catch it. Corrected in `signature.css` from `#80908a` to `#98a59e`,
which measures 5.11:1 against the same worst-case background. Verified live in the rebuilt output.

### Defect found and deliberately not corrected

Three files served as `.png` contain JPEG data: `companion-active.png`, `companion-reconnected.png`,
`companion-snoozed.png` under `assets/lights-out/`. They are pre-existing, git-tracked, unmodified by
this candidate, byte-equal to the live site, and referenced only by the Lights Out product page. The
homepage does not request them. Fixing it means re-encoding or renaming product assets and editing a
page outside this candidate, so it is raised for the owner instead. Detail in
`ASSET_CONTENT_TYPE_AUDIT.md`.

### Screenshot quality control

The first full-page captures showed empty image frames, because a full-page capture does not trigger
`loading="lazy"` images below the fold. Those captures were defective and were discarded, not kept.
Every full-page capture now in the evidence set was taken after forcing lazy images to eager,
scrolling the page, and confirming 11/11 content images report `complete` with a non-zero
`naturalWidth`. Three superseded captures from the first attempt at these checks
(`home-nojs-1280x900.png`, `home-zoom200-1280x720.png`, `home-reflow-320x2560.png`) were removed so
they cannot be mistaken for evidence.

## Acceptance matrix subset

| ID | Result | Note |
|---|---|---|
| UX-01 | PASS | Foundry identity, promise, action, and real stage exist in the opening |
| UX-03 | PASS | Phone action precedes the long product stage |
| UX-04 | PASS | Stage selection coupled to name, media, caption, route, and selection state |
| UX-05 | PASS | Outer stage geometry remains stable during switching |
| UX-06 | PASS | No auto-rotation or unsolicited film playback |
| UX-07 | PASS | Existing real film destinations are contextual |
| UX-09 | PASS | JavaScript-disabled render verified at 1280 and 390; 16/16 content assertions on generated HTML |
| UX-10 | PASS | Purpose/platform filter state and count checked |
| UX-13 | PASS | Two-product comparison opened; existing three-product limit retained |
| UX-15 | PASS | Public/no-public labels remain manifest-derived; candidate detail remains separate |
| UX-18 | PASS | Release records label is consistent across nav/footer |
| UX-24 | PASS | Hero arrow navigation checked; full page keyboard traversal not run but no issues observed |
| UX-26 | PASS | 0 axe violations; the 1 incomplete gradient heuristic was adjudicated by hand, one real failure found and corrected, all 44 nodes now meet AA |
| UX-27 | PASS | Nine fold captures at 360–1920 plus five full-page captures at 390–1920, all with images resolved |
| UX-29 | PASS | Reduced-motion state exercised and confirmed usable |
| UX-32 | PASS | No local console errors observed |
| UX-33 | PASS | Source build reproduces generated output |
| UX-34 | PASS | Existing manifest invariants plus 15 signature checks |
| UX-36 | NOT_PERFORMED | No comparable lab performance run retained |
| UX-38 | PASS | Existing invariants plus focused suite plus MIME audit |
| UX-39 | PASS | No product source, secrets, dependency migration, or deployment change |
| UX-40 | PARTIAL | Local source/output identity recorded; no commit created |

## Not performed

The following were not performed, and no result should be read as covering them:

- **Independent browser engine.** Only Chromium-family browsers exist on this machine. Chrome 153 and
  Edge 152 were both exercised, but they share Blink, so this proves build consistency and nothing
  about Gecko or WebKit. Firefox is not installed; installing one was outside the change boundary.
- **Physical-device testing.** All phone and tablet results are emulated viewport widths.
- **Field performance and Web Vitals.** No comparable baseline was retained, so a number here would
  not be interpretable.
- **Full page keyboard traversal.** Hero arrow navigation, the phone menu, filters, and the comparison
  dialog were exercised; a complete tab-order sweep of every interactive element was not.
- **Production download verification, public-site verification, and deployment.** Nothing has been
  deployed.
- **Owner visual acceptance.** No automated check substitutes for it. `OWNER_VISUAL_REVIEW.html`
  exists to make that review possible.
