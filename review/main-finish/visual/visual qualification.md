# Shared-page visual qualification

Isolated headed Chrome, fresh disposable profile; preview http://127.0.0.1:5180; cache disabled; no build, owner browser, deployment, or source edits. Reduced motion; DPR 1; 1000px viewport height.

- Captured 11 routes at 1440 / 768 / 390px: 33 full-page JPGs.
- Cold homepage 1320px: 3/3 guards pass; stylesheet status, MIME, CSSOM and rendered-style assertions recorded in qualification.json. Missing-critical-CSS negative control: correctly fails guard.
- Layout/header/footer/stations/mobile-menu checks: all 33 pass.
- Primary-navigation/footer link sets consistent: true.
- Chain 01–06 links name their destinations: Home → /; Products → /software/; Proof → /proof-standard/; Truth Files → /truth-files/; About → /about/; Support → /support/. These are page-navigation stations, not proof-stage certification. Actual links and hash-target findings are in qualification.json.
- Rendered contrast (1440 and 390px): 2900 text fragments; 2873 conservative passes; 1 require review; 26 effects not measured. Solid surfaces: 2249; gradient/image surfaces: 651. Per-page JSON contains text, colors, bounds, sampled worst ratio, AA threshold and exclusions.

## Method and limits

For contrast, hide text fill only (preserving layout/currentColor), capture the actual background pixels, and compare computed foreground color (including its alpha) against every pixel in each text fragment rectangle. This handles gradients/textures as screenshot measurements rather than flat-background claims; bbox-wide minima are conservative and review results can include adjacent borders/art. CSS opacity/filter/blend/backdrop effects are explicitly unmeasured. Antialiased edge pixels are not treated as foreground colors; WCAG uses the intended foreground. Not an exhaustive interaction/state, imagery-text, SVG, pseudo-element, focus/hover or accessibility certification. Tablet has screenshots/layout checks, not contrast measurements. Screenshots require human inspection; automated geometry does not prove aesthetic quality.
