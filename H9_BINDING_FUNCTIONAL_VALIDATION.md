# H9 binding design — functional validation

Date: 2026-09-18. Result: **378/378 final browser/HTTP assertions pass**, comprising **286 browser assertions and 92 HTTP assertions**. The new current source guard separately passes **291/291**. Historical test exceptions are fully disclosed in `H9_BINDING_GUARD_BINDING.md`.

Final authoritative browser evidence is `receipts/h9-binding-20260918/final-browser-v2/capture-report.json`. The run used Chrome 153.0.8010.50 in a fresh isolated headless profile against a temporary loopback server, from `2026-09-18T07:15:06.683Z` to `2026-09-18T07:15:47.726Z`. All 13 recorded source hashes and all 210 built-file hashes stayed unchanged throughout the run. The runner blocks third-party requests and records actual local navigation and network results.

## Capture and visual review

The final set contains 23 native PNGs. All 23 were opened and inspected at original resolution by the qualification reviewer; the hashed inventory is `receipts/h9-binding-20260918/manual-capture-review.json`.

- Seven homepage captures: 1440 first/full, 1024 full, 430 full, 390 first/full and 360 full.
- Eight closeups: hero, proof artifact, Cache Vault, ForgeCast, Reality Gate, secondary products, ending, and PF mark/navigation.
- Six catalog captures: default, filtered and comparison states at 1440 and 390.
- One actual shipped G SVG sheet at 16, 24, 32 and 64 CSS pixels, in master and mono variants.
- One native 1024 Runroom viewport diagnostic, preserving actual nested scrollbars and paint.

The pixel review found no remaining blocking defect in those captures. It verified the physical hero and authentic foreground app, immediate two-release ledger, dense four-scene grid, compact secondary strip, environmental ending, responsive navigation, readable provenance and current public versions. At 1024 all three secondary provenance captions stay within their scene. Mobile Runroom copy and capture no longer collide; mobile headlines retain spaces; the ProofShot purpose no longer crosses its media; the ForgeCast phone and recorded-weather caption remain visible.

For full-page captures, the runner expands the native CDP paint viewport to avoid offscreen nested-scroller culling, while checking that CSS viewport dimensions and scene geometry remain unchanged. Closeups use actual element bounds. No screenshot pixels are assembled or edited. First-fold and the separate Runroom diagnostic use the native viewport directly.

## Exercised behavior

At 1440, 1024, 430, 390 and 360 CSS-pixel widths, live checks require the binding scene order, proof immediately after hero, two-by-two major composition on desktop, exact three-product strip, viewport containment and successful image decoding. Actual focus on the Runroom scroll region must not shift neighboring text or its containing scene; ArrowRight must move the intended inner viewport. Captions and text boundary regressions found during iteration have dedicated geometry/text checks.

The catalog is unchanged in this binding tranche. Requalification covers all seven default cards; keyboard search; exact `2.0.0` returning ProofShot alone; AND-token search; job/platform intersections; truthful visible counts; no-results state; both reset controls; restored search focus; and all seven products returning after reset. Comparison checks cover disabled single selection, the three-product maximum, current Cache Vault/ProofShot versions, Enter to open, initial focus, Tab containment, Escape close/focus restoration, selection clearing and the filtered-away-selection focus fallback.

Keyboard checks cover skip-link focus and activation, mobile menu operation and catalog interactions. Both routes are checked with JavaScript disabled. Both routes also pass an equivalent 200% reflow configuration of 720 CSS pixels at DPR 2; this is browser emulation of the content geometry, not a claim that native browser-menu zoom was exercised. Heading/landmark/label/alt checks, minimum control geometry, decoded brand sizes and sampled contrast are included. These are bounded checks, not a complete assistive-technology or WCAG conformance audit.

The local HTTP pass checks route responses, local references, expected redirects, missing-page behavior, MIME types and byte-range handling. Console, JavaScript, failed-asset and third-party-request checks pass for exercised states. This validates the candidate's local generated tree; it does not download or install the public product binaries.

## Motion failure retained and resolved rigorously

The first final run remains in `final-browser/` with **376/377**, including its failed normal-motion assertion. It is not the accepted final evidence. That predicate sampled after a fixed 300 ms, equal to the actual reveal duration, and could observe an animation still active.

Three independent diagnostic runs in `motion-probe/capture-report.json` passed **20/20**. Recorded samples showed active 300 ms animations settling on subsequent observations. The revised runner records computed opacity and each element's real Web Animations state, then requires two consecutive observations with visible content and zero pending/running animations, within a bounded timeout. It separately reloads normal motion, proves that real finite animations are active, changes to reduced motion during those animations, and requires stable visible content with no active animations again.

In the accepted final run, four real 300 ms animations were active before the dynamic preference change. The first reduced-motion observation showed visible content while cancellation was pending; approximately 62 ms after the original active observation, all were canceled, and the following observation confirmed that state. The complete fresh final run then passed **378/378**. No application source change was needed for this test-timing defect.

## Two serious refinements and their evidence

`pass-one-browser/` passed 351 assertions but pixel review identified undersized ledger facts, mobile copy/media overlap, weather artwork that read as workshop furniture and a focus/containment risk around Runroom. Refinement one increased and labelled ledger facts, separated mobile copy and media, used clipping containment, bounded Runroom and made its full-capture link visible. `refinement-one-browser/` passed 358 assertions and its new focus checks, while native review still found word joins from hidden line breaks, a crowded ProofShot headline, tight Runroom note spacing and insufficiently distinct weather scenery.

Refinement two introduced the outdoor weather environment, explicit word spacing, a shorter ProofShot purpose, greater Runroom separation, a continuous mobile hero environment and removal of a blank footer band. `refinement-two-browser/` passed 367 assertions. Final polish corrected intermediate-width provenance clipping, GhostLayer note spacing, the 430-pixel phone cap and the visible ProofShot capture-kind label. The final v2 evidence binds that built result. Earlier logs and captures remain available, including intermediate failed predicates.

## Contrast and performance limits

Live computed contrast samples include body text 12.83:1, gold primary-button text at a minimum gradient-stop candidate of 5.25:1, secondary-button text 16.64:1, ledger labels 9.42:1 and ledger values 10.86:1 at the recorded desktop sample. The calculation composites computed colors and CSS gradient candidates. It excludes raster backgrounds, pseudo-element pixels, antialiasing and backdrop sampling; native pixel review supplements it. No blanket conformance claim follows.

The runner records one cold-cache, unthrottled loopback sample per viewport before scrolling, using browser PerformanceObserver/ResourceTiming. Homepage FCP ranges 128–160 ms and observed LCP 128–180 ms, with CLS 0 in those samples. The 430 sample contains one long task. The unchanged desktop catalog sample reports CLS 0.0855966; mobile catalog CLS is 0. These are local observations, not Lighthouse results, real-user Core Web Vitals or measured INP. Full resource details and exact timing scope are in the final report; broader performance interpretation belongs to the accompanying performance report.

The candidate is technically qualified for owner pixel review under the current binding contract. Pixel acceptance, landing and deployment remain outside this qualification result.
