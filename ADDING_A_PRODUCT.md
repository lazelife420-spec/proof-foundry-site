# Adding a product to Proof Foundry

The product module is the presentation record. site-manifest.json remains the
only source for public versions, availability, downloads, checksums, and
verification. Import and preview never edit release truth.

## Option A: create a Product Capsule

From the repository root:

~~~powershell
./scripts/New-ProductCapsule.ps1 -Id "example-product" -Name "Example Product" -OutDir ".\draft-products\example-product"
~~~

Replace every TODO in product.json and replace both placeholder assets. Add
screenshots under screenshots/ if available. The starter contains no version,
artifact, checksum, download, or verification claim. The importer rejects
placeholder copy and invalid image bytes.

## Option B: import a capsule you already have

Use the product-capsule/v1 structure:

~~~text
example-product/
  product.json
  brand/
    mark.svg
    logo.svg                 optional horizontal logo
  hero/
    hero.webp
  screenshots/
    01.webp                  optional
  social/
    og.png                   optional
  README.md                  optional
~~~

Then run:

~~~powershell
./scripts/Import-ProductCapsule.ps1 -Path ".\draft-products\example-product"
~~~

The importer creates products/example-product/module.json, logo.svg,
optional wordmark.svg, and normalized media under media/. It does not add a
manifest entry. Imported capsules default to preview and stay hidden from the
production catalog, homepage, route set, and public truth. If product.json
requests public-eligible without matching verified manifest truth, import
downgrades it to preview and prints the remaining publication requirements.

Force only replaces an existing products/<same-id>/ directory whose
module.json identifies that same product. It refuses an unrelated directory.
WhatIf validates and reports the planned import without writing it.

## Option C: hand-author a module

Create products/<id>/module.json, a local mark at logo.svg, and optional
images below media/. Use schemas/product-module-v2.schema.json. Every v2
module must declare:

~~~json
{
  "schemaVersion": 2,
  "id": "example-product",
  "route": "/example-product/",
  "order": 100,
  "visibility": "hidden",
  "lifecycle": "preview"
}
~~~

Also include brand, theme, hero, card, taxonomy, sections, homepage, and meta.
Every module also declares a generic commerce record, for example
`"commerce": { "status": "FREE", "label": "Free download" }`. Use `PAID`
only with an explicit `checkoutUrl`; never infer price or checkout behavior from
a public artifact link. `COMING_SOON`, `UNAVAILABLE`, and `WITHDRAWN` describe
distinct release states. The build checks these labels against canonical
release/download truth. They are presentation metadata; Public Truth v1 keeps
its existing release/download contract and does not publish module-authored
commerce copy.
The renderer escapes all module-authored text. Module JSON does not accept HTML
templates, scripts, arbitrary CSS, or arbitrary component names. Keep
`contentSource: content.html` only when preserving a bespoke legacy section;
new capsule products can use registered structured sections only.

## Capsule fields

Capsule paths are relative POSIX paths; never use URLs, drive letters, ..,
backslashes, or absolute paths. Supported image formats are PNG, JPEG, WebP,
and AVIF. Brand mark and logo files must be passive SVG: no scripts, event
handlers, inline styles, external references, or active elements.

theme.accent and theme.accentSecondary accept hex, rgb(), or rgba().
Atmospheres are archive, night, control-room, weather, carbon, memory, clean,
foundry, and none.

Product page hero variants are split, centered, cinematic, console, device,
and immersive.

Catalog presentation comes from card, taxonomy.category, and taxonomy.jobs.
Platform names, release versions, release status, and download availability
still come from verified manifest records. The existing catalog job filters
recognize memory, everyday, and build job tags; other job tags remain
searchable and visible on the card.

Structured capsule sections are outcomes, features, copy, gallery, faq,
guided-tour, devices, and integrations. Items use plain title, body, optional
note, or (for galleries) local src, alt, and caption fields. All text is
rendered as text, never trusted as markup. Each section type must have a
registered renderer; arbitrary HTML/component names fail validation.

## Optional homepage placement

Use these capsule placement values:

- homepageTier: featured, major, secondary, or hidden (the legacy value none is normalized to hidden)
- homepageVariant: forge-scene, workstation, device, console, wide-screen, or compact
- homepageOrder: integer ordering within the selected tier
- homepageNote: optional short factual qualifier shown with the release status

The homepage renders featured, major, and secondary placements from public
modules. New capsules default to hidden: their product route and catalog/truth
records remain available after promotion, but the homepage does not show them
until you choose a placement tier.
Preview builds also include a local-only homepage placement page at /__preview/;
it never changes the production homepage.

## Preview

~~~powershell
./scripts/Preview-Product.ps1 -Id example-product
~~~

This validates the module, builds to a unique temporary directory, starts a
hidden loopback-only static server, and opens the product preview. It prints
the product route, local homepage placement view, catalog, server PID, and
temporary directory. Stop the server with the printed Stop-Process command.
The preview route and catalog use noindex; no deploy is performed.

## Public eligibility gate

A module is public only when both sides agree:

1. The module says "lifecycle": "public-eligible" and "visibility": "visible".
2. site-manifest.json contains the same ID and route, visible: true,
   release.releaseStatus: "PUBLIC_RELEASE", a non-empty
   release.publicVersion, and verification.status: "VERIFIED".

If these facts are absent or disagree, the build fails closed. Promoting a
presentation does not create or change canonical release truth. A preview
module paired with a public manifest record remains excluded until the module
itself is explicitly promoted.

Run the site builder and the product-module tests after authoring:

~~~powershell
npm run build
pwsh -NoProfile -File scripts/test-h13-modular-products.ps1
pwsh -NoProfile -File scripts/test-product-capsule.ps1
~~~

Common failures include placeholder text, an SVG with active/external content,
an unsupported or mislabeled image file, a duplicate ID/route, a route that
does not match the ID, an invalid theme token or hero variant, and a
public-eligible module without matching verified public truth.

## Existing long-form pages

The seven existing content.html files retain product-specific long-form
narrative, evidence, privacy, onboarding, guided product tours, and (for Lights
Out) an interactive website demo. Shared hero and outcome content moved into
module data. Cache Vault and Lights Out FAQ content also moved into registered
structured FAQ sections. The remaining sections have different structures and
include carefully scoped technical limits and source-specific evidence; they
remain in content.html rather than being flattened into generic copy.
Capsule-authored products do not need content.html.

Baseline-to-current content.html size (UTF-8 bytes; physical lines):

| Product | Before | After |
| --- | ---: | ---: |
| Cache Vault | 221 lines / 22,636 bytes | 149 lines / 15,892 bytes |
| Cleanroom | 115 lines / 15,773 bytes | 115 lines / 12,430 bytes |
| ForgeCast | 141 lines / 17,711 bytes | 141 lines / 13,190 bytes |
| GhostLayer | 181 lines / 17,685 bytes | 181 lines / 14,351 bytes |
| Lights Out | 459 lines / 38,661 bytes | 429 lines / 31,909 bytes |
| ProofShot | 299 lines / 30,936 bytes | 299 lines / 27,513 bytes |
| Reality Gate | 362 lines / 29,956 bytes | 332 lines / 25,781 bytes |

The files remain because each still contains product-specific tours and
technical/evidence/privacy records with distinct behavior or carefully scoped
claims. Lights Out also retains its interactive timer demo. Those pieces do
not yet share a safe structured data shape that preserves their current
behavior. Capsule products use no authored HTML, CSS, or JavaScript.
