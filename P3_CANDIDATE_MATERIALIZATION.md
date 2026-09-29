# P3 — Candidate Materialization

`pf-product materialize <capsule> [--output-dir <directory>]` validates a Capsule through the P0–P2 CLI and writes an isolated candidate bundle outside the source checkout. The default output base is the operating-system temporary directory. The command rejects output roots inside or containing the checkout or Capsule.

## Candidate contents

Each candidate directory contains:

- `submitted-capsule/` — the validated package bytes.
- `proposed-source/` — only proposed files within `site-manifest.json`, `products/<id>/`, and `assets/<id>/` scope.
- `candidate-state.json` — normalized candidate identity, source binding, proposed state, artifact/evidence inventory, claims, profiles, validation result, and initial `VALID_UNVERIFIED` state.
- `candidate-state-source.json` — the product list consumed through the existing `StateSourcePath` seam.
- `candidate-changed-paths.json` — sorted `ADD`/`MODIFY` operations with pre-image/post-image SHA-256 and authority reason.
- `candidate-artifacts/` and `candidate-evidence/` — local bytes with computed hashes and sizes.
- `materialization-receipt.json` — event metadata including the timestamp.

Candidate identity hashes canonical normalized data: the base commit/tree/manifest hash, Capsule digest, proposed paths, candidate state source, artifact/evidence hashes, and bounded qualification profiles. The event timestamp is not part of the identity. Repeating the command for the same input and base reuses the same candidate ID; a second output root produces the same candidate state and path manifest.

## Submission behavior

- `NEW_PRODUCT` adds a hidden `preview` module and an `UNRELEASED` manifest record without public downloads or verified status.
- `NEW_VERSION` adds only `site-manifest.json` when module, content, and media are unchanged. Genuine copy/media/taxonomy/homepage changes appear as separate proposed paths and generate a warning.
- `PRESENTATION_UPDATE` does not propose a manifest mutation. Release version, artifact facts/URLs, verification, receipt identity, and source commit are sealed against the base record.

Product media is mapped to its existing product asset namespace. An unchanged canonical media file is not reported as a proposed change. Changed HTML is checked for active markup and secret-like content; byte-identical baseline content is inherited without being reclassified as a new submission.

The current Capsule module schema omits `homepage.mediaDisclosure`, although the canonical module files contain it. When an update Capsule validated under that schema omits this field, the candidate preserves the canonical value. This avoids erasing current module presentation during a version-only submission.

Materialization never edits the repository, changes canonical state, or upgrades `VALID_UNVERIFIED`.
