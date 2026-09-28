# Product Module v2

## 1. Current architecture audit

`scripts/build-site.ps1` discovers `products/*/module.json` and joins public
candidates to canonical release state by ID. Public routes, catalog cards,
homepage placement, related links, truth records, and discovery links derive
from the registry. Draft/preview modules can exist without a manifest record
and stay out of production. The manifest remains the source for release
state, versions, artifacts, hashes, downloads, and evidence.

## 2. V1 limitation

V1 still required `contentSource: content.html` for every module. The generic renderer wrapped that file but did not render the product presentation itself. Modules could not express safe theme tokens, a typed hero, reusable structured sections, product-scoped media, or taxonomy.

## 3. V2 module shape

The executable constraints are documented in [`schemas/product-module-v2.schema.json`](schemas/product-module-v2.schema.json) and enforced in the registry loader in `scripts/build-site.ps1`. V2 modules can define:

- `brand`: accessible name, mark, wordmark, and monochrome asset paths.
- `theme`: validated accent, secondary accent, background, surface, glow, text, muted, and a controlled atmosphere name.
- `hero`: a registered variant, kicker, headline, lede, local media, and local/fragment actions.
- `card`: catalog tagline and media.
- `taxonomy`: category and job tags, with room for platform and audience tags.
- `lifecycle` and `homepage`: publication readiness plus a tier (`featured`, `major`, `secondary`, or `hidden`), variant, order, and copy. `major` renders a scene; `secondary` renders a compact card. `hidden` keeps the public product route/catalog/truth while omitting it from the homepage. Homepage placement is controlled only by this tier.
- `commerce`: a generic `FREE`, `PAID`, `COMING_SOON`, `UNAVAILABLE`, or `WITHDRAWN` state and visitor-facing label. Canonical release truth must agree with the state; paid offers require an explicit checkout URL. The catalog renders the label. Public Truth v1 keeps its existing schema and release/download fields; no price is inferred from a download link.
- `sections`: known component names or structured section objects.
- `contentSource: content.html` as a migration bridge; it is optional for fully structured/capsule-authored modules.

The V2 eighth-product fixture has no `content.html` and is kept under `scripts/fixtures/product-module-v2/`, outside canonical discovery.

## 4–7. Renderer, theme, hero, and component registries

The static builder uses the existing shell and shared header/footer. V2 hero
variants are `split`, `centered`, `cinematic`, `console`, `device`, and
`immersive`. Theme fields map only to `--product-*` custom properties after
color-format validation; atmosphere values come from an allowlist. Asset and
hero-action paths are local-only. Structured renderers cover outcomes,
features, how/onboarding, guided tour, devices, integrations, FAQ, story/get,
identity, evidence, privacy, related, final CTA, gallery, copy, download,
and technical record. Unknown structured types fail validation. Module-authored
text is escaped at output.

## 8–9. Catalog and homepage discovery

`software.html` is a shell with generated catalog markers. Cards enumerate
eligible public modules; copy, image, category, jobs, logo, accent, and alt
text come from module presentation. Version, platforms, release availability,
downloads, and public status still come from canonical manifest state. The
commercial/acquisition label is module-authored but build-validated against
that release state. There is no ID-specific job map in `h9-software.js`.

The generated product showcase markers in `index.html` are registry-driven.
The builder groups products by the module's homepage tier and orders each
group by module metadata. Modules choose from controlled homepage variants;
CSS keeps the cinematic scenes and provides reusable variants. Adding a
capsule does not require editing either page or the renderer.

## 10. Publication safety

Modules use `draft`, `preview`, or `public-eligible`. Only a public-eligible
module that also has a matching visible route and verified `PUBLIC_RELEASE`
manifest record with a public version emits a production route, catalog/home
entry, or truth record. A public candidate without matching canonical truth
fails the build. Draft and preview modules stay outside those production
surfaces. An explicit preview build writes a separate noindex route, catalog,
and homepage placement page.

Import and preview do not write `site-manifest.json`. Presentation cannot
author release status, version, platform facts, checksums, or downloads.
Module IDs/routes and local media paths are validated; theme colors,
atmospheres, hero variants, section types, and action hrefs are constrained.
SVG assets reject active/external content. Module media is copied under
`/assets/products/<id>/...`.

## 11. Capsule intake and local preview

`schemas/product-capsule-v1.schema.json` defines the portable presentation
format. `scripts/New-ProductCapsule.ps1` creates a TODO-marked starter;
`scripts/Import-ProductCapsule.ps1` validates and normalizes it into a V2
module. Import validates IDs, routes, path containment, supported files,
image signatures, SVG behavior, theme, hero variant, section allowlist, and
the release-truth boundary. `-WhatIf` validates without writing. `-Force`
can replace only the existing module with the same explicit ID.

An imported capsule defaults to preview. A public-eligible request without
matching verified manifest truth is downgraded to preview and reports what
remains. `scripts/Preview-Product.ps1 -Id <id>` builds into a unique temp
folder, serves it on loopback, and prints the noindex product, homepage, and
catalog routes. It does not deploy. See [ADDING_A_PRODUCT.md](ADDING_A_PRODUCT.md)
for the full authoring guide.

## 12. Migration results

All seven modules now contain their shared hero copy/media and outcomes; their
source heroes no longer embed product mark SVG. Cache Vault and Lights Out FAQ
copy also moved to structured `faq` sections. Remaining long-form content
preserves custom tours, product narrative, version-sensitive technical,
evidence/privacy claims, onboarding, and download details. Lights Out also
retains its interactive timer demo. These bespoke sections remain in
`content.html` rather than being flattened into generic cards.

`content.html` baseline → current size (physical lines / UTF-8 bytes):

| Product | Before | After |
| --- | ---: | ---: |
| Cache Vault | 221 / 22,636 | 149 / 15,892 |
| Cleanroom | 115 / 15,773 | 115 / 12,430 |
| ForgeCast | 141 / 17,711 | 141 / 13,190 |
| GhostLayer | 181 / 17,685 | 181 / 14,351 |
| Lights Out | 459 / 38,661 | 429 / 31,909 |
| ProofShot | 299 / 30,936 | 299 / 27,513 |
| Reality Gate | 362 / 29,956 | 332 / 25,781 |

## 13. Fixture proof

The Cache Vault capsule fixture is derived from real presentation data. The
round-trip test imports it as a separate preview module, builds its themed
route and assets, discovers it in the preview catalog and homepage placement,
verifies exclusion from production route/catalog/homepage/truth, and confirms
the canonical manifest is byte-identical. A one-command preview smoke check
also runs.

## 14. Test results

Completion run:

- `npm run build`: passed; seven visible products generated.
- `scripts/test-h13-modular-products.ps1`: 158 passed, 0 failed.
- `scripts/test-product-capsule.ps1`: 30 passed, 0 failed.
- `scripts/test-h11-public-truth.ps1`: 345 passed, 0 failed.
- `scripts/test-h12-truth-discovery.ps1`: 126 passed, 0 failed.
- `scripts/test-release-truth.ps1`: 39 passed, 0 failed. Its SmartScreen assertion now checks the correctly escaped FAQ text.
- `scripts/test-receipts-invariants.ps1`: 54 passed, 0 failed. Its no-date fixture explicitly uses preview modules while the manifest has pending verification.
- Chrome rendered all seven products at 1440×900 and 390×844: 14/14 passed with no horizontal overflow, broken sourced images, HTTP errors, or JavaScript/console errors. Results and viewport screenshots are in `review/PRODUCT_FACTORY_COMPLETION_VISUALS_2026-09-26/`. Six pages contain an empty `.gallery-full` image target used by the click-to-open gallery; it has no source until a gallery item is selected.

## 15. Source size / duplication

The seven `content.html` files remain as a bridge for the bespoke sections
named above. They have not been eliminated. The documented extraction is
shared hero/outcome data for all seven and structured FAQ data for Cache Vault
and Lights Out. New capsule products need no authored page HTML or per-product
stylesheet.

## 16. Add product #8

1. Run `./scripts/New-ProductCapsule.ps1 -Id "example-product" -Name "Example Product" -OutDir ".\draft-products\example-product"`.
2. Replace TODO copy, mark, and hero image in the capsule; add optional screenshots and edit `product.json`.
3. Import with `./scripts/Import-ProductCapsule.ps1 -Path ".\draft-products\example-product"`.
4. Preview using `./scripts/Preview-Product.ps1 -Id example-product`.
5. After approval, add canonical verified truth through the normal process and explicitly promote the module. No catalog/homepage HTML edits are needed.

## 17. Remaining exceptions

- All seven current pages still use `content.html` for bespoke content. Further migration needs section-specific models and parity review.
- Selected homepage composition remains curated through module metadata; product scene markup is generated by the registry.
- Rare guided tours, product films, and technical evidence remain product-specific until structured models can preserve their behavior and claims.
