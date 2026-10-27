# Focused continuity checks

These tests are separate from the 29 protected qualification scripts. They use the real generated website, its existing CSS stack and an isolated local Chrome profile. No dependency installation, deployment or authority change is required.

Build the site normally, then run:

```
node scripts/continuity/check-contracts.cjs --root public --out <evidence>/responsive.json
node scripts/continuity/check-components.cjs --root public --out <evidence>/components.json
node scripts/continuity/check-layout.cjs --root public --out <evidence>/layout.json
node scripts/continuity/check-editing.cjs --root public --out <evidence>/editing.json
```

The editing check requires a fresh evidence filename/directory. It preserves a remote-free disposable source checkout, runs the normal builder with its existing authority and changes only the fixture narrative. It also changes one control token and one existing responsive declaration in browser memory. The working source remains untouched.

Product layout and responsive variants belong to `product-page.css`; ordinary button geometry, paint and states belong to `pf-foundry-system.css`; catalog assembly belongs to `h9-software.css`; inner-page compositions and the error notice belong to `pf-site-ledger.css`. Preserve media-query context when moving a rule. The component specimen is injected into actual product, catalog and document contexts; it has no second theme or public route.

Passing capture, overflow, computed-style or functional checks is not owner visual acceptance. Contrast and browser forced-color emulation have separately documented scope.
