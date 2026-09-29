# P5 — Candidate Qualification

`pf-product qualify <candidate>` revalidates the Capsule, candidate file inventory, proposed path manifest, artifact/evidence bytes, public-state invariants, local preview, source scope, and candidate build. Before the public-surface authorities run, it rebuilds ignored `public/` from the frozen site source. This prevents H9, H11, H13, and release-truth checks from depending on stale generated output. The canonical output is regenerated in the isolated worktree and is not source or approval payload. It then runs the current authority suites registered for this tranche:

- `test-pf-product.mjs`
- legacy Capsule suite
- H9 binding and homepage
- H13 modular products
- release truth
- receipts invariants
- Truth Files
- H11 public truth
- H12 truth discovery
- `git diff --check`

The qualifier returns independent verdicts for Capsule, materialization, module, public state, artifact declaration/hash, presentation, routes, discovery, truth projection, receipt projection, build, source scope, regression, and live publication. This tranche always reports `LIVE_PUBLICATION_VALID = NOT_RUN`; it does not count as failure.

When every non-publication gate passes, the command writes `qualification-record.json` with candidate/Capsule/source identity, proposed-content digest, artifact hashes, changed paths, qualification dimensions, suite counts, preview identity/payload digest, candidate build digest, claim/evidence assessments, known limits, and publication blockers. Its state is `QUALIFIED_UNPUBLISHED`. Existing records are recomputed and compared before reuse.

Claim/evidence links remain `UNRESOLVED` or `UNSUPPORTED` and non-authoritative. No supplied metadata can grant `VERIFIED`, `SAFE`, `SECURE`, `PROVEN`, or `PUBLIC_RELEASE`. No R2 operations, release/tag/push, canonical-state promotion, or Pages deployment are implemented. P6 adds only `FROZEN_FOR_OWNER_REVIEW`; it does not define `APPROVED` or `PUBLISHED`.

The qualification state is `QUALIFIED_UNPUBLISHED`. The separate owner-review freeze is documented in `P6_OWNER_APPROVAL_BOUNDARY.md`.
