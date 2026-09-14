# The Proof Foundry website

A static software-studio storefront, built from root HTML templates, shared partials and `site-manifest.json`. The redesigned source is locally validated and **has not been deployed**.

## Review locally

Use PowerShell 7, Git and Node.js 20.19+ (or Node.js 22.12+). From this repository:

```powershell
pwsh -NoProfile -File scripts/build-site.ps1
npm ci
npm run dev
```

Open the local address printed by Vite. `npm run dev` only starts a local preview. The production build remains the PowerShell generator; do not edit `public/` directly.

```powershell
pwsh -NoProfile -File scripts/test-receipts-invariants.ps1
```

The existing suite verifies canonical version derivation, evidence custody, checksum integrity, routes and deterministic output. The final run passed 54 assertions.

## Source map

- Root HTML files: product and studio copy; manifest tokens resolve at build time.
- `partials/`: shared navigation, footer and catalog cards.
- `studio.css`: storefront and distinct product layouts, including mobile.
- `styles.css`: existing base and secondary evidence styles.
- `experience.css` and `experience.js`: the wide real-screen product selector, purpose/platform finder, two- or three-product comparison, distinct product previews, section navigation, guided screenshot tours, and motion preferences.
- `site.js`: mobile menu, screenshot gallery with thumbnails and full-resolution zoom, expandable proof deep links and checksum copy fallback.
- `assets/studio/`: responsive WebP derivatives of the existing real screenshots. Original PNGs remain available through the screenshot viewer.
- `site-manifest.json`: canonical product truth. Product release, artifact, verification and authority fields are unchanged. Presentation fields describe visitor-facing copy and download availability.
- `review/`: local validation evidence and the visual review. These files are not copied into the generated website.

## Distribution observations

Cache Vault's RC-era Windows candidate and Android companion links returned HTTP 404 on 9 September 2026 (historical observation). As of the final public v0.2.3 release (live-checked 14 September 2026), the storefront presents the final Windows ZIP download from Proof Foundry downloads; the Android companion GitHub APK link remains unavailable. Canonical URLs and digests remain in the source record; `presentation.downloadUnavailable` controls this display independently of release classification. Recheck the URLs before changing that flag.

Lights Out's public Windows release remains v11.1.2 and its public Android companion remains v11.1.1. The v11.1.3 candidates remain on hold. No public ProofShot release is claimed; the underlying engine remains v1.6.18.

## Using the delivered archive

Extract to a separate folder for review. It contains the existing Git history, the changed working files and a rebuilt `public/` directory. Machine caches, dependency folders and old untracked capture folders are omitted. To integrate into the original Windows checkout, copy the working source files while preserving that checkout's own `.git` directory and any subsequent work.

Production deployment requires explicit owner approval of the final visuals. No deployment command is part of build or preview.

## Interactive studio pass

The homepage product selector loads a real screenshot on demand and updates its product link after the image decodes. Full product names and arrow-key navigation make the seven tools easy to browse. The catalog combines purpose and platform filters, with an explicit empty state and reset. Select two or three tools to compare their purpose, platform and current availability; comparison content comes from the same manifest-rendered catalog cards.

Each product has a curated gallery of real interface captures, with captions, thumbnails, keyboard navigation, fit-to-screen viewing and optional original-resolution zoom. Original PNGs load only when requested. A compact section navigator appears after the product hero and links to the interactive preview, availability and deeper proof.

Each product has its own interaction: Reality Gate and ProofShot use tours of actual recorded interfaces; Cache Vault has searchable, pinnable sample clips; Lights Out has a working short countdown; Cleanroom models archive/restore; GhostLayer models explicit commit/discard; ForgeCast has a sample-day timeline. Website previews are labelled as samples and never access user files, clipboard, device controls, or live weather. They do not imply that development candidates are publicly available.

The progressive enhancements use no new runtime dependencies. Core pages, navigation, screenshots and release information remain available without JavaScript. The motion preference is local to the browser and follows the operating system reduced-motion setting. No analytics, tracking or network APIs were added.
