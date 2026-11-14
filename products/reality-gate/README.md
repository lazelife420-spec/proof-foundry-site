# reality-gate product module

- Product id: `reality-gate`.
- Release facts: `site-manifest.json` is authoritative; this module contains presentation only.
- Module assets: add `logo.svg` and media under `media/`; the build packages these at `/assets/products/reality-gate/brand/logo.svg` and `/assets/products/reality-gate/media/`.
- Existing shared assets can also be referenced from `/assets/`.
- Theme: `theme` values map to validated `--product-*` CSS properties; atmosphere values are declared in `schemas/product-module-v2.schema.json`.
- Hero: choose `split`, `centered`, `cinematic`, `console`, `device`, or `immersive`.
- Sections: use shared section objects (`outcomes`, `features`, `gallery`, `copy`) for new pages. Existing detailed copy may continue through `contentSource: content.html` while being migrated.
- Preview: run `npm run dev` and open `/reality-gate/`.
- Validate/build: run `npm run build`; discovery, theme tokens, hero variants, and section types are validated by the build. See `scripts/test-h13-modular-products.ps1` for registry fixture controls.