# P6 — Owner Approval Boundary

`pf-product freeze <candidate>` creates a local owner-review package only after the candidate is `QUALIFIED_UNPUBLISHED`, its local preview and qualification record still match, and every publisher source file is committed in a clean checkout.

The package is written atomically under `owner-review-package/` inside the external candidate directory. Qualification first regenerates ignored `public/` from the committed source so authorities do not consume stale generated output:

- `candidate-approval.json` — state, identities, deltas, limits, and blockers.
- `candidate-changed-paths.json` — exact proposed source path and byte changes.
- `candidate-artifacts.json` — submitted artifact and evidence inventory with hashes.
- `candidate-qualification.json` — qualification dimensions and authority suite results.
- `candidate-preview.json` — preview payload identity and isolated routes.
- `candidate-source-binding.json` — publisher commit/tree and base site commit/tree.
- `candidate-approval-summary.txt` — deterministic human-readable review summary.

The approval binds `approvalSchemaVersion`, `candidateId`, `publisherCommit/tree`, `baseSiteCommit/tree`, `capsuleSha256`, `candidateDigest`, `candidateStateSha256`, `candidatePayloadSha256`, `productId`, `submissionType`, proposed paths, artifact hashes, qualification results, preview identity/routes, `canonicalStateDelta`, `commerceDelta`, `releaseTruthDelta`, `routeDelta`, homepage and Truth deltas, known limits, publication blockers, and `createdAt`. The deterministic `approvalPackageDigest` excludes `createdAt`; timestamp changes therefore do not change candidate or approval identity.

The seven publication-impact labels are explicit `YES` or `NO`: product presentation, public release truth, artifact, commerce, route, homepage, and generated Truth files. A frozen package has state `FROZEN_FOR_OWNER_REVIEW`. It does not set `APPROVED`, `VERIFIED`, or `PUBLISHED`; `LIVE_PUBLICATION_VALID` remains `NOT_RUN`.

## Future approval record design

Any later owner approval record must bind at least `candidateId`, `candidateDigest`, `capsuleSha256`, `publisherCommit`, `baseSiteCommit`, and the full `artifactSha256` list. The binding is candidate-specific, and any changed candidate bytes, artifact bytes, source commit, or base identity invalidates the old record. A detached `approved=true` flag is not an approval. The record is a design contract only; P6 does not read, accept, or connect an approval record to publication mutation.

## Authority boundary

Freeze is local and read-only with respect to production. It performs no R2 operation, remote preview deployment, Pages deployment, DNS change, GitHub Release, push, tag, release, or canonical-state promotion. P7–P9 remain unimplemented and require separate owner authorization.
