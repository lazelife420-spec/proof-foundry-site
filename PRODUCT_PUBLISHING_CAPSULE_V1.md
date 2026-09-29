# Product Publishing Capsule V1 (P1–P5)

This package is an offline intake envelope for proposing a product or presentation/release update. It carries submitted bytes, hashes, provenance metadata, and evidence references. It is not a replacement for Product Module V2, site-manifest.json, or the site's public-state authority.

The older product-capsule/v1 in schemas/product-capsule-v1.schema.json remains presentation-only and is unchanged. This publishing format is separate and additive.

## Directory shape

~~~text
capsule/
├── capsule.json
├── product/
│   ├── module.json
│   ├── content.html          optional
│   ├── logo.svg              required, passive SVG
│   ├── wordmark.svg          optional, passive SVG
│   └── media/                referenced module media
├── release/
│   ├── release.json
│   ├── artifacts/            submitted artifact bytes
│   ├── SHA256SUMS.txt
│   └── evidence/             receipts and evidence bytes
└── provenance/
    └── source.json
~~~

capsule.json follows schemas/product-publishing-capsule-v1.schema.json. release/release.json follows schemas/product-release-submission-v1.schema.json. product/module.json follows the existing Product Module V2 schema. The CLI requires the source repository and commit to match provenance/source.json.

The envelope records productId, submissionType (NEW_PRODUCT, NEW_VERSION, or PRESENTATION_UPDATE), requestedLifecycle (draft, preview, or public-eligible), source repository and commit, release version, platforms, and artifact references. PRESENTATION_UPDATE carries no artifact references; its version must equal the current canonical version. New products and versions require at least one artifact and an evidence file.

Artifact and evidence paths are relative package paths. They cannot contain absolute paths, traversal, backslashes, query characters, or URL schemes. SHA256SUMS.txt uses one line per declared artifact in the form 64-hex-digest followed by two spaces and release/artifacts/name.ext. The release record also contains evidence IDs and optional claim-to-evidence links. A missing or unlinked evidence claim is reported; the CLI does not adjudicate the claim's truth.

Use Product Module V2 local asset paths for packaged media: /assets/products/<productId>/brand/logo.svg, optional /assets/products/<productId>/brand/wordmark.svg, and /assets/products/<productId>/media/<file>. Include every referenced product-local media file in the package. Shared assets already owned by the current site can be referenced through /assets/... if they exist in the checkout.

No Capsule field grants verification. A package cannot self-assert VERIFIED, publication state, or canonical downloads. `requestedLifecycle: public-eligible` is a request only. Materialization starts at `VALID_UNVERIFIED`. Qualification may record `QUALIFIED_UNPUBLISHED`; it does not change canonical public state. The local state sequence is `INVALID`, `VALID_UNVERIFIED`, `QUALIFIED_UNPUBLISHED`, and `FROZEN_FOR_OWNER_REVIEW`. `APPROVED` and `PUBLISHED` are not defined in this tranche.

## Local commands

~~~powershell
.\pf-product.ps1 inspect .\path\to\capsule
.\pf-product.ps1 validate .\path\to\capsule
node .\scripts\pf-product.mjs materialize .\path\to\capsule
node .\scripts\pf-product.mjs preview .\path\to\candidate
node .\scripts\pf-product.mjs qualify .\path\to\candidate
node .\scripts\pf-product.mjs freeze .\path\to\candidate
~~~

inspect prints the package inventory and local SHA-256 values. validate emits a deterministic JSON report containing the product ID, submission type, module/H13 checks, artifact inventory and hashes, release version, route collisions, missing fields, claim/evidence gaps, privacy/security findings, validation status, unverified items, and exact next action. Exit code is 0 for VALID_UNVERIFIED, 1 for INVALID, and 2 for CLI/setup errors.

`inspect` and `validate` are offline and read-only. Validation builds a staged module with the existing registry/renderer into a unique operating-system temporary directory. It does not alter `products/`, `site-manifest.json`, `public/`, or the Capsule. Scratch output is removed after the check. Raw build diagnostics and detected secret values are withheld from the report.

`materialize` validates the Capsule and creates a deterministic candidate bundle outside the source checkout. Its `candidate-state.json` remains `VALID_UNVERIFIED`; the receipt timestamp is event metadata and is excluded from candidate identity. `candidate-changed-paths.json` records proposed scoped paths and their before/after SHA-256 values. The command never edits the owner source tree.

`preview` uses the existing `build-site.ps1` product registry, preview route, and `StateSourcePath` seam. It writes a local static preview under `/__preview/` and preserves normal public routes, Truth, and sitemap outputs. Candidate artifacts are labelled `PUBLIC_DOWNLOAD = NOT_PUBLISHED`; no future object-storage URL is emitted. Rechecking an existing preview compares its file set and normalized rendered content with a fresh build. The existing renderer emits a build timestamp and nonsemantic ordering of unique product CSS custom properties, so those are normalized during comparison.

`qualify` revalidates the Capsule, materialization, scoped source proposal, local preview, build output, release/receipt/truth projections, and current regression authorities. It writes a qualification record with `QUALIFIED_UNPUBLISHED` only after all non-publication gates pass. `LIVE_PUBLICATION_VALID` is always `NOT_RUN` here. No R2 write, release, tag, push, or deployment is part of P3–P5.

`freeze` requires the qualified candidate and preview to match the exact publisher commit/tree. It emits a local `owner-review-package/` with source binding, artifact and changed-path inventories, qualification results, preview identity, explicit public-impact deltas, blockers, and a deterministic package digest. The timestamp is event metadata and is excluded from that digest. The state becomes `FROZEN_FOR_OWNER_REVIEW`; this is not owner approval and does not enable publication. See `P6_OWNER_APPROVAL_BOUNDARY.md`.

Qualification profiles are bounded identifiers from the Capsule schema; they never execute submitted commands. Claims and supplied evidence remain unadjudicated assertions. The current Capsule module schema omits `homepage.mediaDisclosure`, although canonical modules contain it. For an update Capsule validated under that schema, materialization preserves the canonical baseline value when omitted so a version-only submission does not erase current presentation state.
