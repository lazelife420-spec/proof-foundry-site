# P4 — Local Product Preview

`pf-product preview <candidate>` verifies the candidate against its Capsule and the frozen source binding, then calls the existing `build-site.ps1` renderer with an isolated product directory and candidate `StateSourcePath`. No second renderer or canonical manifest edit is used.

The assembled static preview contains the baseline public build plus candidate review surfaces under `/__preview/`:

- `/__preview/<id>/` — candidate product page.
- `/__preview/software/` — candidate catalog context.
- `/__preview/` — candidate homepage context when the module requests a visible homepage role.
- `/__preview/<id>/candidate-truth.json` and `candidate-receipt.json` — non-authoritative candidate projections.
- Product-owned candidate assets under the same preview namespace.

Every candidate surface is labelled `PREVIEW`, `UNVERIFIED`, and `NOT PUBLIC`; candidate artifacts use `PUBLIC_DOWNLOAD = NOT_PUBLISHED`. No future R2 URL is generated. Candidate routes do not enter normal public routes, Truth, or sitemap output. The homepage/catalog review notice links to the namespaced candidate routes.

The preview receipt binds the candidate digest, candidate-state hash, routes, baseline public payload digest, and exact preview payload digest. Revalidating an existing preview rebuilds the expected tree and checks for exact path membership and rendered-content parity. The renderer emits a wall-clock `generatedAt` value and can vary the order of unique `--product-*` style declarations; the parity check normalizes only these nonsemantic build variations. It never overwrites a differing preview.

P4 is local/static only. It does not start a server, deploy Pages preview, alter production, or make submitted artifacts public.
