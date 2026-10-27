# Editing the website

One page, one file. This is the whole workflow for routine changes. You never edit anything in `public/` — it is rebuilt from the files below every time, and hand edits there are erased.

## Which file do I change?

| I want to change… | Edit this | Never edit for this |
|---|---|---|
| Home headline, doctrine, position, closing call | `index.html` | `public/index.html` |
| Home featured cards, specimen, software index rows | Product `module.json` (`card.*`, `homepage.*`) — the rows are generated from the product registry | a hand-typed product list in `index.html` |
| Home materials (plate, chain, paper) | `pf-home-ledger.css` | `brand/PF_MARK_G_MASTER.svg` geometry (needs separate approval) |
| Software page intro and finder wording | `software.html` | generated cards in `public/software/` |
| One product's story, demo, screenshots, captions, FAQ | `products/<id>/content.html` (story/demo/sections) or `products/<id>/module.json` (`sections` outcomes + faq) | any other product folder |
| One product's hero, label, accent colour, card image | `products/<id>/module.json` (`hero`, `theme`, `card`, `brand`) | `release-truth.json` |
| One product's demo styling | `product-page.css` under `body.product-<id>` or `experience.css` for its demo block | `pf-foundry-system.css` (that restyles every page) |
| About, Support, Roadmap, Founders, Proof Standard, Truth | `about.html`, `support.html`, `roadmap.html`, `founders.html`, `proof-standard.html`, `truth.html` | product renderer or release model |
| Header menu or footer | `partials/header.html`, `partials/footer.html`; shared styling in `pf-foundry-system.css` | copies of the header in pages |
| Fonts, colours, rail width, buttons, focus, paper sheet mounting | `pf-foundry-system.css` (the shared owner — loads last on every page) | the same property in a page stylesheet |
| Truth Files layout or wording | `truth-files.html`, `truth-files.css`, Truth Files renderer in `scripts/build-site.ps1` | generated `/truth-files/` pages |
| **A public version, download, checksum, status or withdrawal** | **Not an HTML edit.** Governed `release-truth.json` workflow only (see `SHARED_RELEASE_TRUTH_AUTHORITY.md`) | product HTML, `module.json`, `site-manifest.json` release fields |
| A published release receipt | A new, properly authorized receipt | existing receipt bytes |

Version numbers, hashes and download links inside product pages come from tokens such as `{{product.downloadBlock}}`, `{{product.hashBlock}}`, `{{products.<id>.statusStatement}}`. Keep those tokens exactly as written; never type a version number in their place.

## Edit, preview, check

From the candidate worktree (PowerShell):

```powershell
code .\products\cache-vault\content.html      # 1. edit one file
npm run build                                  # 2. rebuild public/ (about 10 s)
npm run dev                                    # 3. preview at the printed local URL
pwsh -NoProfile -File .\scripts\test-h13-modular-products.ps1   # 4. focused product check
```

Look at the changed page at desktop and phone width (the local preview supports `/__review?page=/cache-vault/&width=390`). That is enough for a copy, caption or image change. The full gate suite runs once, before a candidate is published, not for every paragraph.

## What needs more than one file

- **New section that needs new styling:** the product's `content.html` plus scoped rules in `product-page.css` (`body.product-<id> …`). Do not touch `scripts/build-site.ps1`.
- **Shared header/footer/material change:** run the cross-route screenshots and the full gates; it affects all 25 routes.
- **New product:** `scripts/New-ProductCapsule.ps1` → `Import-ProductCapsule.ps1 -WhatIf` → `Preview-Product.ps1`. A preview is noindex and never creates a public release.

## Publishing

Editing and building are local and safe. Publishing is a separate, owner-approved step through `deploy.ps1` (sealed artifact, qualification receipt, stage receipt). `DEPLOY.md` describes an older flow and is superseded.

Detailed section-by-section map: `PAGE_EDIT_MAP.md`.
