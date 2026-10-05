# Public Truth v1 — Contract Versioning & Source-Binding Policy

**Status:** canonical policy for the `/truth/*` public surface (H11, 2026-09-20).
**Contract:** `schemas/public-truth-v1.schema.json`, published at `/truth/schema-v1.json`.

## What `schemaVersion: 1` means

`schemaVersion` identifies the **contract shape** — field names, types,
required/optional status, and semantics — not the facts inside it. Current
facts (versions, checksums, availability, dates, links) change freely without
bumping the version.

## Within schemaVersion 1 — allowed data changes

```text
product added/removed as real catalog state changes
version value changes
release state changes
download availability changes
URLs/checksums/artifacts change
array contents change while conforming to existing schema
source commit/tree/timestamp values change
bug correction to a value while preserving field semantics
```

## Requires a new schema version

Any contract-shape or semantic change, including:

```text
add field
remove field
rename field
change field type
change required/optional status
change field meaning
change enum definition
change URL representation semantics
change nested object shape
change nullability
```

For v2+: publish a new versioned schema path (e.g. `/truth/schema-v2.json`),
increment `schemaVersion`, and **never** silently rewrite `schema-v1.json` to
incompatible semantics. The existing v1 schema path remains the v1 contract.

## Published-source binding doctrine

`source.commit`, `source.tree`, and `source.committedAt` describe the Git
commit the records were generated from.

```text
LOCAL PREVIEW             — any local build may render /truth/* for review.
                            Its source identity reflects the checkout's HEAD,
                            which is review metadata, not a custody claim.
PUBLISHED PUBLIC TRUTH    — is valid only when generated for deployment from
                            a tracked-clean committed checkout, so
                            source.commit/tree are literally true of the
                            bytes served.
```

The deploy guard (`deploy.ps1`) enforces a completely clean candidate commit
and sealed artifact. A production upload requires prior exact served-byte
verification of that same artifact on the immutable preview deployment.
There is no dirty-source override or publication-time rebuild.

Local worktree state is intentionally **not** a public field: whether the
operator's tree was dirty is build-environment information, not product truth.

V1 remains at the existing paths; richer v2 records live at `/truth/v2/`.
V1's `generatedFrom` refers to the derived compatibility manifest. The sole
authored release-fact input is `release-truth.json`, identified in v2 source
provenance. See `SHARED_RELEASE_TRUTH_AUTHORITY.md` for the authority decision
and inherited v1 schema exceptions.
