# CSS Ownership and Material Contract

**Candidate:** branch `codex/pf-modular-html-r1`, isolated worktree `C:\Users\KickA\Projects\Worktrees\pf-modular-r1` (base `0dd208c`, uncommitted owner-review changes on top).
**Directive:** `PF_WEBSITE_20_PASS_MODULAR_HTML_TRUTH_FILES_MASTER_2026-10-26.md` — keep the forged-metal design consistent while each product keeps its identity, and make ownership explicit enough that one page can be edited without breaking another.
**Compiled:** 2026-10-26, Factory, local Windows evidence only.
**Companions:** `EDITING_THE_WEBSITE.md` (workflow), `PAGE_EDIT_MAP.md` (per-section map), `MODULARITY_MUTATION_TESTS.md` (isolation proof).

## 1. The contract in one paragraph

Every route sits inside one gunmetal foundry frame: the same header, footer, navigation and mounting rhythm, owned by `pf-foundry-system.css`. Home retains its master plate and inspector. Product, catalog, studio, support and planning pages use steel surfaces; verification records use mounted paper. Product identity comes from the authored theme variables, media and scene family in `module.json`, rendered through shared presentation rules. The shared owner loads last; page compositions remain scoped to their own family.

## 2. Ownership map

| Stylesheet | Loads on | Owns |
|---|---|---|
| `styles.css` | every route, first | base reset and document baseline |
| `studio.css` | every non-home route | studio scaffolding; generic `.evidence-section` rules that the bespoke `gl-*`, `lo-*`, `ps-*`, `rg-*` families render through; detail cards |
| `experience.css` | software + product pages | interactive product demo blocks |
| `h9-software.css` | software page | finder and product cards on the catalog page |
| `product-page.css` | product pages | product page skeleton; per-product rules must be scoped under `body.product-<id>` |
| `truth-files.css` | truth-files routes | Truth File record layout |
| `pf-home-ledger.css` | home only | the home ledger: welded frame, capture cards, proof chain, mark inspector, release specimen |
| `foundry-world.css`, `pf-site-ledger.css` | every non-home route | inner-route world backdrop and ledger strips |
| `pf-foundry-system.css` | **every route, always last** | the shared owner: material tokens, fonts, header/footer/nav, buttons, focus, skip link, paper sheet mounting, motion, forced-colors, responsive frames |

**Builder-enforced cascade order** (`scripts/build-site.ps1` template processor): page sheets → `foundry-world.css` → `pf-site-ledger.css` → `pf-foundry-system.css`. Home skips the two injected middle sheets. A rule in the shared owner therefore wins any tie against a page sheet — that is the mechanism that keeps the frame identical everywhere.

## 3. Material tokens (the forged-metal vocabulary)

Defined once at `pf-foundry-system.css:10-19`:

| Token | Value | Meaning |
|---|---|---|
| `--pf-black` | `#0b0f14` | world dark |
| `--pf-iron` | `#1c232b` | frame iron |
| `--pf-paper` | `#f4f7f8` | paper sheet |
| `--pf-teal` | `#00d1b2` | link / action accent |
| `--pf-gold` | `#d6a84f` | receipt gold (record edges, marks) |
| `--pf-muted` | `#b5c0c5` | muted text on dark |
| `--pf-rule`, `--pf-paper-rule` | `#ffffff29` / `#0b0f142e` | hairline rules on dark / on paper |
| `--pf-sans` / `--pf-mono` | Archivo / IBM Plex Mono | the two typefaces (self-hosted, latin subsets) |
| `--pf-steel` | `url('/brand/PF_WELDED_STEEL_v1.webp')` | the welded steel world material |
| `--pf-rail` | `min(1280px, …)` | content rail width (narrows at 1200px and 640px breakpoints) |

Per-product accent comes from `products/<id>/module.json` (`theme`/`brand` data), never from a new stylesheet. The approved PF artwork (`brand/PF_MARK_G_MASTER.svg` and derived marks) is never modified by CSS geometry changes.

## 4. The mounting rule: one chassis, purposeful surfaces

The completion pass on 2026-10-26 makes the inner-route `body.studio` the backplate: `min(1560px, 100% - 2*gutter)`, 12px joints stepping down to 6px, paired inset rails and the same contact shadows as Home. Header, main and footer mount inside that surround. This uses the existing HTML partial structure without adding wrapper coupling.

- Proof, Proof Standard, Truth and all Truth Files remain opaque paper sheets, with a restrained top clamp and brass joint outside the reading column.
- About, Support, Roadmap and Founders have explicit `pf-room-*` presentation classes. Their main surfaces re-scope the dark text tokens. The Founders receipt remains paper within its steel room.
- Product heroes retain their authored geometry and accent variables. Real screenshots sit within a common machined lip; no texture is drawn over the image. Existing approved artwork and product imagery are unchanged.
- Mobile navigation is an in-flow inset backplate containing distinct steel keys. The no-JavaScript fallback exposes all five destinations and hides the inert toggle.
- Header/footer declarations were removed from `pf-home-ledger.css` and the duplicated chrome block in `pf-site-ledger.css`; `pf-foundry-system.css` owns their normal and responsive presentation. Home's mark inspector, proof chain, raised lettering and section mounting stay in its page sheet.

Current visual evidence: `C:\Users\KickA\Projects\Context\ProofFoundry\review\pf-forge-visual-completion-20261026\compare.html`. This supersedes earlier material-depth deferrals; visual approval remains pending and commit/production remain on HOLD.

## 5. Accessibility floors owned by the shared sheet

| Floor | Where | Rule |
|---|---|---|
| Focus | `:25-26` | 3px solid teal outline, 5px offset, on every interactive element |
| Skip link | `:27` | visible on focus, teal on black |
| Forced colors | `:432-438` (`site-header/footer/nav-panel`, ledger instruments), `:527-530` (workbench, support fields), `:640-657` (the full material reset) | every hero, ledger section, mounted paper `main` — including `body.studio.secondary-page:not(.tf-page)` and `body.studio.tf-page` — product cards, Support plates, status indicators: `background:Canvas; color:CanvasText; border-color:CanvasText; box-shadow:none`; plate decorations off; brand picture falls back to the forced-colors SVG source; the mobile menu bars render as `ButtonText` on every route (previously only the home ledger had this, so inner-route menu buttons were empty boxes) |
| Motion | `:428-431` + `html[data-motion="off"]` (`:318-319`) | `prefers-reduced-motion` and the footer motion toggle both disable animation/transition and hover transforms |
| Responsive frames | `:321`, `:334`, `:354`, `:428` | rail and nav re-mount at 1200/900/640px; nav collapses to the toggle panel under 900px; at 420px and below the Truth File title steps down (one-word product names cannot wrap) so nothing overflows at 320px |

## 6. Header and footer DOM parity (verified against the candidate base build)

Method: every `.html` file in the built tree (44 files) was scanned; header and footer DOM were extracted, whitespace-normalized, and hash-grouped (`%TEMP%\pf-parity.cjs`, `pf-parity2.cjs`).

**Footer — one shape everywhere.** All 25 visible routes render a byte-identical footer DOM (same product list, same brand lockup, same hidden inline mark fallback). The `__h14/partials/footer.html` shadow variant is intentionally simpler (text lockup, no forced-colors picture, no hidden inline mark) — it is the template form for the shadow layer, not drift.

**Header — one structure everywhere.** All 25 visible routes share the identical header DOM (brand lockup with `PF_MARK_G_HEADER.webp` + forced-colors SVG source + hidden inline `pf-mark-fc` fallback, nav toggle, nav panel, nav links Software / Proof / Truth Files / About, Support CTA). The only per-route difference is which element carries `aria-current`:

| Routes | `aria-current` on |
|---|---|
| product pages + `/software/` | Software |
| `/truth/` + `/truth-files/*` | Truth Files |
| `/proof/` + `/proof-standard/` | Proof |
| `/about/` | About |
| `/support/` | the Support CTA |
| `/`, `/404`, `/founders/`, `/roadmap/` | none (no nav destination) |

The seven hash groups reduce to exactly this. The `__h14/content/*` fragments carry no header/footer by design; `__h14/partials/header.html` is the template form with `{{nav-links}}`/`{{nav-cta}}` tokens.

**Dormant partial:** `partials/footer-compact.html` is read by the builder (`scripts/build-site.ps1:2873`) but `@include compact-footer` emits the standard footer, so no route uses a compact footer. Left in place.

## 6b. Measured cascade ownership (R1 continuation audit, 2026-10-26)

DOM parity (§6) proves the markup is shared; it does not prove the *computed styles* are. A CDP audit captured computed values, rects, and every declaring stylesheet per property for header/nav/footer/h1/h2/p/buttons on `/`, `/software/`, `/about/`, `/support/`, `/lights-out/`, `/truth-files/lights-out/`, `/proof-standard/` at 1440/390/320 plus open-menu states — on the candidate, on `0c30434`, and on `0dd208c`. Every conflict found was first verified byte-identical in the approved `0c30434` (pre-existing, not a candidate regression), then fixed with a minimal edit in the one shared owner. No new stylesheet, no `@layer`, no `!important`.

| # | Conflict (measured, pre-existing) | Fix |
|---|---|---|
| 1 | `pf-site-ledger.css` grouped `body` rule re-declared `font-family: system-ui,…`, overriding the shared Archivo token on secondary/product routes while its own h1/h2 used Archivo — body copy and headings were different typefaces on those pages | removed the font-family declaration from that grouped rule |
| 2 | `.nav-toggle` computed to UA-default Arial 13.33px on routes without `experience.css` | shared sheet now sets `font:600 16px/1 var(--pf-sans)` on the toggle |
| 3 | current-page nav color had two competing scene owners (`pf-site-ledger.css`, `studio.css`) | one shared `… .top-nav a[aria-current="page"] { color:#fff }` rule |
| 4 | `.brand-mark` padding 4px at ≤640px shrank the mark on inner routes only (Home already overrode to 0) | 0 in the shared sheet |
| 5 | two ≤900px menu blocks in the shared sheet disagreed on link size (16px vs 15px; Home ledger 16px) | later block aligned to 16px. The two-block structure (in-flow variant refined to absolute overlay) is deterministic by source order and capture-verified; merging the blocks is deferred as non-minimal |

Post-fix re-audit: Archivo body on all 7 routes × 3 widths; toggle Archivo 16px everywhere; mark padding 0 everywhere; zero 320px horizontal overflow. Remaining drift is intentional: Home header/footer are inset inside the ledger plate (1347px vs full-bleed 1440 on inner routes) — identical to approved `0c30434`, the master-plate framing; `aria-current` placement differs by route by definition; page-family content typography differs by design while the shell (fonts, rail, chrome, menu, buttons, focus, forced-colors) is shared.

## 7. Known gaps (documented, deliberately not changed here)

- Bespoke class families (`gl-*`, `lo-*`, `ps-*`, most `rg-*`) render through the generic `.evidence-section` rules in `studio.css`; styling them means adding scoped rules in `product-page.css` under `body.product-<id>`.
- Classes emitted but styled nowhere: `storefront`, `support-studio`, `roadmap-unavailable`, `standard-principles-section`, `standard-boundary-section`, `standard-routes-section`, `limit-note`.

These are dead weight, not breakage. Per the owner's rule to stop adding complexity, this candidate removes no CSS and adds no new bespoke styling; fold both cleanups into future per-product edits, one product at a time.

## 8. Editing rules implied by the contract

1. Want to change the frame (fonts, colors, rail, buttons, focus, sheet mounting)? Edit `pf-foundry-system.css` — and run the cross-route screenshot set, because it touches all 25 routes (see `MODULARITY_MUTATION_TESTS.md` m4).
2. Want to change one page's content look? Edit that page's sheet, scoped to its own classes.
3. Want to change one product's identity? Edit `products/<id>/module.json` data — the accent propagates to that product's surfaces only (m2).
4. Never restate a shared-owner property in a page sheet; the shared owner loads last and will win the tie anyway.
