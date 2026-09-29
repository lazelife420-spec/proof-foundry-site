# P0 Current Publishing Architecture

Inventory date: 2026-09-29

Inventory source: commit `d52eedb6fcbf5ead060318e8fee0e60406dc19a2`, tree `32cf38d80988871a9fcd29410bbea2fd0b6d7c0f`

Scope: read-only publishing archaeology for `PF_PRODUCT_PUBLISHER_P0_P2`.

## Baseline binding

The clean managed worktree created for this tranche is based on the slogan production commit above. The live public Truth index at `https://theprooffoundry.com/truth/index.json` independently reports that same source commit and tree, with seven product records. The registered master checkout was not used for changes.

The controlling roadmap supplies deployment ID `203a99e8-de2f-47bc-9888-61108715f11b` and rollback target `09453aff-e5c5-46d5-8fd2-cdd930b4ab5f`. Those identifiers were not independently queried from Cloudflare in this inventory. No Cloudflare credential store or live account configuration was read.

## Current architecture and authorities

| Concern | Current authority | Evidence in this repository |
| --- | --- | --- |
| Product enumeration | `products/*/module.json`, discovered by `Get-ProductRegistry` in `scripts/build-site.ps1` | Registry validates IDs, routes, lifecycle, presentation metadata, assets, and correspondence with visible manifest products. |
| Product presentation | `products/<id>/module.json`, optional `products/<id>/content.html`, and product media/assets | Modules provide generic presentation and lifecycle metadata. Bespoke product sections remain in `content.html`; the current seven products still use it. |
| Public release and artifact facts | `site-manifest.json` | Owns release status, public/withdrawn version, artifact names and URLs, hashes, downloads, verification state, and evidence links. Product modules cannot replace those facts. |
| Build-time state source | `New-ManifestProductStateSource` by default | Exposes `GetAll()`, `GetVisible()`, and `Get(id)`; renderers consume this adapter contract. |
| Alternate state seam | `New-FixtureApiProductStateSource` selected by `-StateSourcePath` | Exercises the same adapter contract with fixture JSON; it is not a production publisher or a second canonical database. |
| Rendering/output | `scripts/build-site.ps1` → generated `public/` | Registry-driven pages, homepage/catalog, product routes, public Truth, discovery, and H14 shadow assets are emitted from existing sources. |

H13's modular-products qualification demonstrates that an eighth module can flow through registry, catalog, route, Truth, and discovery without product-specific edits to the central renderer. Preserve that property.

## Existing Capsule and preview paths

The current `schemas/product-capsule-v1.schema.json` and `scripts/New-ProductCapsule.ps1` / `scripts/Import-ProductCapsule.ps1` define a **presentation-only** capsule. It becomes a Product Module V2 presentation record. It carries no release artifact bytes, source/build provenance, artifact hashes, or release evidence, and it does not write `site-manifest.json`.

The existing importer writes under `products/<id>/`; its `-WhatIf` mode validates without writing. Do not use the importer as the non-mutating publishing inspection/validation CLI, and do not repurpose or break its schema.

For already-materialized modules, `scripts/Preview-Product.ps1 -Id <id>` builds into a unique temporary directory and serves noindex preview routes on loopback. The build also supports `-PreviewProductId`, `/__preview/<id>/`, `/__preview/software/`, and the preview homepage. This is a local preview of an existing module, not a Capsule intake path. Capsule-to-candidate preview belongs to a later phase.

## Public-state runtime and fallback

H14's Pages Function in `functions/__h14/[[path]].js` can consume `PF_PUBLIC_PRODUCT_API_BASE`, but product structure remains tied to the module registry. The build emits `__h14/static-state.json`; runtime code has API, cache/last-good, and static fallback paths. The checked-in `wrangler.toml` declares the Pages project/output directory but no public-state API binding. The roadmap states that current production is operating from static fallback; this source inventory did not query live Cloudflare environment bindings. The H14 API in `scripts/h14/public-state-api.mjs` is a deterministic test fixture.

## Production publication paths

### Pages site

The established production path is direct upload through `deploy.ps1`: require a clean tracked checkout, run `scripts/build-site.ps1`, then call Wrangler Pages Direct Upload for project `proof-foundry-site` on branch `main`, followed by `scripts/Verify-PublicSite.ps1`. `wrangler.toml` identifies `public` as the build output. There is no Git-triggered deployment path in this workflow.

### Product artifacts / R2

The manifest and release-truth documentation bind public download, checksum, receipt, and evidence URLs under `downloads.theprooffoundry.com/<product>/v<version>/...`; historical deploy receipts show public object checks. The roadmap declares the backing namespace as `proof-foundry-downloads/<product>/v<version>/`.

The repository search found **no tracked R2 object upload command, publisher script, or R2 write runbook** (including no `wrangler r2 object put --remote` operation). Thus the current canonical public artifact facts are represented in the manifest, but the operational R2 write path is not encoded in this checkout. That is a later P7 gap, not something P0–P2 should fill with a write operation.

## Existing qualification and safety constraints

- `scripts/test-h13-modular-products.ps1` is the modular registry/renderer compatibility authority.
- `scripts/test-product-capsule.ps1` covers the older presentation capsule: starter placeholders, WhatIf, valid preview-only import, manifest invariance, duplicate IDs/routes, path traversal, invalid fields/theme/hero/components, active SVG, unsupported files, public-request downgrade, and production-surface exclusion.
- `schemas/product-module-v2.schema.json` is the existing module contract; `PRODUCT_MODULE_V2.md` and `ADDING_A_PRODUCT.md` document the presentation workflow and release-truth boundary.
- `scripts/build-site.ps1 -ValidateOnly` exits before `Get-ProductRegistry`; it is not sufficient by itself to prove candidate module/H13 compatibility. A normal build removes its selected output directory before emitting. Candidate validation must therefore stage modules and build into a unique temporary output directory, never the checkout's `public/`.
- The P1 publishing Capsule must be additive and separate from the legacy presentation Capsule. It is an ingestion package only. It must not write the manifest, upload artifacts, deploy Pages, create production API state, or mark a submission VERIFIED.

## Search result

The read-only search covered the requested module, manifest, build, deploy, Wrangler, H14, H13, Capsule schema/test, preview, and publishing-related sources, plus the roadmap's publisher vocabulary. It found the legacy presentation-capsule flow and the H13/H14 adapter seams described above. It found no separate Developer Portal, `PrivatePublisherFlow`, `PrivateCatalogGenerator`, Foundry Key, capsule ingest/publish service, or tracked R2 writer.

Credential stores, gateway files, `.dev.vars`, Wrangler auth state, and Miniflare trace stores were excluded and not opened or searched.
