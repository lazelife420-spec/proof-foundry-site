# Proof Ledger frozen render contract

This harness qualifies candidate `dd5763ee5e841e881ebde9fe49cc2fc2bbd1d159`, tree `415391ceca5488969f296453c60fd524f82051ad`, parent `92adc410ebfc32aabc77a04470ca697118879086`. Production source and all existing qualification suites remain byte-for-byte frozen. The eight PNG fixtures are exact copies of the qualified references, pinned by SHA-256. They were not regenerated.

Decoded RGBA and dimensions must be exact outside the derived plate paint envelope. Inside it, each RGB channel may differ by at most one; alpha remains exact everywhere. There is no image similarity threshold or SSIM fallback.

`compare.py` derives the envelope from the frozen `.ledger-plate` border-box, its CDP border quad, and its actual non-inset computed shadows. For an outer shadow `(dx,dy,blur,spread)`, Gaussian sigma is `blur/2` and the finite paint support used here is `3*sigma = 1.5*blur`. The local shadow rectangle is:

```
[dx-spread-1.5*blur, dy-spread-1.5*blur,
 width+dx+spread+1.5*blur, height+dy+spread+1.5*blur]
```

The current outer shadows are `(13,19,18,0)` and `(3,4,2,0)` CSS pixels; the code rejects other declarations. The union of these rectangles and the plate itself is projected through the border-quad homography, translated from viewport to document coordinates, and mapped through screenshot clip, scroll and DPR. Pillow rasterizes those polygons, then applies a single raster pixel dilation for antialiasing/subpixel coverage. Navigation, hero headline/subtitle/description/note/actions and proof-chain DOM boxes, expanded one raster pixel, are subtracted. The mask is clipped to the image; the 200% mid/footer states have an empty envelope. No observed diff rectangle is hard-coded.

Each state has exact guards for the scene, plate, emblem, edge, mark, inlay, name, motto and serial, plus grain. Guards include DOM geometry, text, attributes, critical computed styles, and pseudo-element styles. Five frozen source/asset hashes cover `index.html`, `pf-home-ledger.css`, `homepage-ledger.json`, and both canonical PF SVGs. A guard change fails even when pixels satisfy the tolerance.

`capture.mjs` verifies and reads the approved browser harness without editing it. A disposable copy adds read-only post-screenshot receipts. Full-page receipts wait two animation frames before reading DOM/CDP geometry because scrollbar restoration can otherwise split a snapshot across two layouts. Each receipt binds its own PNG by SHA-256. The independent runner executes the unchanged browser suite separately, then checks both its eight PNGs and the geometry-capture PNGs against the same contract. The geometry capture does not replace any browser assertion or alter any screenshot command/state.

Phase A evidence contains 40 fresh captures (five per state) and 80 pairwise comparisons. All states pass; only desktop full-page varies, by at most 2,353 pixels (0.06118%), with maximum RGB channel delta one and exact alpha. All changes lie inside the derived envelope. Seven required negative controls reject plate movement, mark scaling, plate text edits, a headline pixel edit, plate background changes, alpha drift and a one-channel outside-envelope edit. An extra hash-only asset mutation also rejects. Disposable controls never edit candidate files or reference PNGs.

The initial cohort and its diagnostic instrumentation HOLD are retained in the external raw evidence directory pinned in `manifest.json`. That cohort crossed a transient full-page scrollbar restoration between sequential geometry probes. Complete replacement cohorts, including all five runs for all eight states, were preserved; no failed qualification attempt was erased or selectively rerun.

Usage while the unchanged `public` build is served at `http://127.0.0.1:5187`:

```
node scripts/frozen-render-contract/capture.mjs ROOT APPROVED_BROWSER_HARNESS GEOMETRY_OUTPUT
python scripts/frozen-render-contract/compare.py ROOT PRIMARY_BROWSER_OUTPUT GEOMETRY_OUTPUT REPORT_JSON
```

Python requires NumPy and Pillow. Reports retain per-image deterministic pixels checked, decorative pixels tolerated, maximum deltas, alpha results, envelope polygons, all structural/hash results and explicit failure reasons. Existing approved build normalization remains unchanged. Physical Windows reduced motion remains **NOT TESTED**; browser emulation does not close that coverage gap. This work authorizes no push, merge, master update, release or production deployment.
