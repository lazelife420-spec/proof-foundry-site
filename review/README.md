# Local visual review - 9 September 2026

Not deployed. The 18-page visual review shows all eight requested pages at desktop and mobile widths, including their interactive sections, plus comparison and screenshot-gallery views. All 36 images are actual browser captures.

- Reviewed 1440 x 900 and 390 x 844 CSS iframe viewports in Chrome. Desktop captures are scaled to 88% for the browser surface; mobile captures are 1:1. This is responsive CSS validation, not physical-device Safari testing.
- All 32 page/section viewport checks: zero page-level horizontal overflow, broken loaded images or pending visible images. Real product UI appears in every first viewport.
- All 21 curated gallery screens decode and link to the correct original. Thumbnails, previous/next, keyboard navigation, desktop original-resolution zoom/fit and Escape verified. Gallery and comparison have no horizontal overflow at mobile width.
- Comparison works with two or three products, limits selection to three, clears selection and closes with Escape. Availability was checked for Cache Vault, Cleanroom, Reality Gate, Lights Out and ProofShot. Windows and Android Lights Out versions are explicitly separated.
- Product section navigation has product-appropriate availability labels. ProofShot's status action reaches its development-only message; its proof shortcut opens the preserved expandable material.
- Homepage keyboard Home/End selection, actual image changes and matching product links checked. Existing seven preview workflows, all screen tours, filters, mobile menu and motion controls were exercised in the preceding pass; see dynamic-browser-validation.json. All seven proof sections were expanded and checked at mobile width in that pass.
- No application-origin console errors observed. Browser extension diagnostics are outside the site.
- Existing release-integrity suite: 54 passed, zero failed.
- Static validation: 12 pages, 552 local references, 82 decoded HTML raster images. No missing target, duplicate ID, dangling fragment, unresolved token, invalid structured data or missing required metadata. All 21 gallery entries additionally have valid original, preview and thumbnail files.
- Every canonical product field outside presentation is unchanged from the uploaded source.
- Original live/source/build comparison: 14 checked routes/assets were byte-identical before redesign. See live-source-parity.json. The improved source has not been published.
- Dated distribution checks remain in download-checks.json. Reality Gate, Cleanroom, GhostLayer and ForgeCast public artifacts returned 200; Cache Vault's candidate and companion URLs returned 404. Availability CTAs avoid broken primary downloads without changing release authority.
- First-view product images total about 7-77 KB on mobile, with the homepage loading one 25 KB screenshot. Galleries request original-resolution PNGs only for zoom or the original-image link. See image-performance.json for exact selected resources.

Build and local-preview instructions are in the root README. The archive preserves the existing history for the evidence-custody gate. When integrating into another checkout, preserve that checkout's own Git directory and subsequent work.
