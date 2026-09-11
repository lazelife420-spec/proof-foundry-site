# Gradient contrast adjudication

## Why this document exists

Earlier passes recorded the homepage axe audit as "0 violations, 1 incomplete gradient contrast
heuristic" and left it there. An incomplete result is not a pass. This document resolves it by
identifying the exact elements, computing WCAG 2.1 contrast ratios by hand against the worst-case
background, and recording the one real defect that was found and corrected.

## What axe actually reported

Run: axe-core 4.12.1 against `http://127.0.0.1:4173/` (generated `public/` output).

| Field | Value |
|---|---|
| violations | 0 |
| incomplete | 1 rule: `color-contrast` |
| incomplete node count | 44 |
| passes | 43 |
| inapplicable | 46 |

Every one of the 44 nodes carried the identical reason:

> Element's background color could not be determined due to a background gradient

All 44 nodes are descendants of `.product-theater`, the homepage product stage. That element's
background is:

```css
background:
  linear-gradient(135deg, rgba(214, 168, 79, .1), transparent 26%),
  radial-gradient(circle at 82% 20%, rgba(83, 121, 99, .22), transparent 48%),
  #17201f;
```

Axe cannot resolve a per-pixel background for text drawn over a gradient, so it declines to score
rather than guessing. This is a limitation of automated scoring, not evidence of a failure, and it
cannot be cleared by any change short of removing the gradient. It therefore has to be adjudicated
by hand.

## Method

1. Read the computed `color`, `font-size`, and `font-weight` of every text-bearing element inside
   `.product-theater` directly from the rendered page.
2. Compute the lightest colour the gradient can produce, because light text on a dark panel is worst
   off over the lightest part of the background:
   - solid base: `#17201f` = `rgb(23, 32, 31)`
   - lightest point of the brass linear gradient: `0.10 x rgb(214,168,79)` over the base
     = `rgb(42, 46, 36)`
   - lightest point of the green radial gradient: `0.22 x rgb(83,121,99)` over the base
     = `rgb(36, 52, 46)`
3. Score each element against whichever of those two produces the lower ratio, using the WCAG 2.1
   relative-luminance and contrast formulas.
4. Apply the correct threshold per element: 3.0:1 for large text (>= 18 px, or >= 14 px bold),
   4.5:1 otherwise.

The calculator used is committed alongside this document as `contrast-calc.js`, and the style
extraction script as `contrast-audit.js`, so the numbers can be reproduced.

## Results before correction

| Element | Foreground | Size / weight | vs solid | vs lightest gradient | Threshold | Verdict |
|---|---|---|---|---|---|---|
| `.theater-top .kicker` | `rgb(192,204,189)` | 10 px / 500 | 9.99:1 | 7.86:1 | 4.5 | PASS |
| `.theater-context` | `rgb(128,144,138)` | 11.2 px / 400 | 4.97:1 | **3.91:1** | 4.5 | **FAIL** |
| `.theater-index` | `rgb(239,201,120)` | 11 px / 400 | 10.53:1 | 8.28:1 | 4.5 | PASS |
| `h2[data-theater-name]` | `rgb(242,238,228)` | 27.2 px / 500 | 14.35:1 | 11.29:1 | 3.0 | PASS |
| `p[data-theater-line]` | `rgb(190,201,193)` | 13.44 px / 400 | 9.75:1 | 7.67:1 | 4.5 | PASS |
| `a[data-theater-link]` | `rgb(242,238,228)` | 12.16 px / 400 | 14.35:1 | 11.29:1 | 4.5 | PASS |
| `.theater-film-link` | `rgb(189,205,189)` | 10.72 px / 400 | 10.00:1 | 7.87:1 | 4.5 | PASS |
| selector button, unpressed | `rgb(170,184,173)` | 10.88 px / 400 | 8.05:1 | 6.33:1 | 4.5 | PASS |
| selector button, pressed | `rgb(24,32,29)` on `rgb(239,201,120)` | 10.88 px / 400 | n/a | 10.53:1 | 4.5 | PASS |

One real defect: `.theater-context`, the line "Select an instrument. See the work.", fell to 3.91:1
over the lightest part of the gradient. It also sat at only 4.97:1 over the solid base, leaving no
margin. Axe had never scored it, so no earlier pass caught it.

## Correction applied

`signature.css`:

```diff
 .signature-home .theater-context {
   margin: 8px 0 0;
-  color: #80908a;
+  color: #98a59e;
   font-size: .74rem;
 }
```

| | Before | After | Threshold |
|---|---|---|---|
| vs solid base | 4.97:1 | 6.50:1 | 4.5 |
| vs lightest gradient point | 3.91:1 | **5.11:1** | 4.5 |

Verified live in the rebuilt output: computed colour is `rgb(152, 165, 158)`.

The change is a single supporting caption lightened within its existing muted grey-green family. It
does not alter the visual hierarchy, and no other token was touched.

## Result after correction

All 44 nodes over the gradient meet WCAG 2.1 AA. Seven of the nine distinct styles also meet AAA
(7.0:1); the two that do not are the corrected caption at 5.11:1 and the unpressed selector labels at
6.33:1. AAA was never a requirement for this candidate.

Axe still reports the same 1 incomplete result, and will continue to, because the gradient is still
there. That is expected and is now backed by the hand adjudication above rather than left open.

## Standing limitation

This adjudication covers the two gradient layers declared in `signature.css` over their declared
solid base. It does not cover text placed over a photographic or screenshot background, because the
candidate places no text over imagery.
