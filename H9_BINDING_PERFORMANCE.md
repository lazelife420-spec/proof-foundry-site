# H9 binding design — measured local performance

The final candidate's measured homepage CLS was 0 at every tested width. The unchanged software route recorded CLS 0.085597 at 1440 px and 0 at 390 px. These are local observations, not a production performance certification.

## Method and evidence

Source: `receipts/h9-binding-20260918/final-browser-v2/capture-report.json`, `performance` records. Each row is one cold-cache Chrome headless run on the local machine over unthrottled loopback, with reduced motion, at the initial viewport before scrolling. Native Paint, Largest Contentful Paint, Layout Shift, Long Task, Navigation and Resource Timing observers supplied the values. The browser runner records the source and all 210 built-file hashes.

This is not Lighthouse, a throttled mobile-device simulation, field Core Web Vitals, INP measurement, or a network deployment test. Fast loopback times do not predict public-network loading. No synthetic score is reported.

| Page / CSS width | FCP ms | LCP ms | CLS | Long tasks | Resource requests | Encoded resource bodies, bytes |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| Homepage / 1440 | 160 | 180 | 0 | 0 | 20 | 1,042,212 |
| Homepage / 1024 | 156 | 176 | 0 | 0 | 19 | 1,041,741 |
| Homepage / 430 | 140 | 140 | 0 | 1 × 65 ms | 13 | 887,243 |
| Homepage / 390 | 136 | 136 | 0 | 0 | 13 | 887,243 |
| Homepage / 360 | 128 | 128 | 0 | 0 | 13 | 887,243 |
| Software / 1440 | 84 | 100 | 0.085597 | 0 | 16 | 1,243,621 |
| Software / 390 | 80 | 80 | 0 | 0 | 15 | 919,586 |

The resource count and encoded bytes exclude the top-level HTML navigation: add 15,443 body bytes for the homepage or 21,574 for software. Resource transfer sizes include browser-recorded overhead; they are retained in the raw evidence. The numbers describe the initial observation window, not a complete scrolled-page transfer budget. Images loaded later during screenshot scrolling are separately checked by the browser qualification.

The hero's `foundry-ledger.webp` was the homepage LCP element at all widths. The software route's desktop LCP was its existing Runroom card image; mobile LCP was a paragraph. The single 65 ms task on the 430 px homepage is reported as observed, without attributing it to a specific script or inventing a TBT result.

## Asset cost and implementation choices

Three new decorative environment assets total **604,130 bytes**:

| Asset | Dimensions | Bytes |
| --- | --- | ---: |
| `foundry-ledger.webp` | 1672 × 941 | 201,594 |
| `weather-horizon.webp` | 1672 × 941 | 161,826 |
| `studio-horizon.webp` | 2172 × 724 | 240,710 |

These are WebP encodings of generated, empty environments. They contain no fabricated application UI. Their dimensions and composition were preserved during encoding. Authentic product screenshots, existing responsive derivatives, brand SVGs and the catalog's images were not rewritten.

The hero image is preloaded. The weather and ending CSS backgrounds are also requested early, including on mobile before those scenes enter the viewport. Thus the cinematic environment has a real initial transfer cost of roughly 604 KB; it is not represented as fully lazy-loaded. Product images use the existing responsive sources and lazy-loading behavior. No new remote font, image host, JavaScript library, video or canvas animation was introduced.

Existing shared styles remain intact to preserve frozen routes. The homepage adds a 33,650-byte CSS file and a 1,664-byte progressive-enhancement script in the measured build. Content is visible without JavaScript; optional reveals finish in 300 ms. Reduced-motion behavior, interruption while motion is active, and eventual visibility were checked separately in the 378-check final browser/HTTP run. The earlier fixed-delay motion sampling failure and its instrumented diagnosis remain included in the review package.

## Practical limits

No measured homepage layout shift remains in these samples. The software desktop shift is a measured limitation of the preserved catalog, whose source and built page are unchanged from this tranche's entry; it is not silently reported as zero. The public site's response compression, cache behavior, mobile CPU cost and real-network loading remain unmeasured because this work did not deploy. The package contains the exact local bytes used for these observations so the owner can assess the visual result and its transfer cost together.
