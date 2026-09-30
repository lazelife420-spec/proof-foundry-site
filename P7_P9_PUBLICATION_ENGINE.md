# P7–P9 publication engine

This layer consumes a P6 `FROZEN_FOR_OWNER_REVIEW` package through a separate, signed owner decision. The approval schema is `schemas/product-owner-approval-v1.schema.json`. The record uses Ed25519 and binds the approval package digest, candidate/capsule identity, publisher and base site commit/tree, product, submission type, artifact hashes, approval time, and the exact allowed actions. A public key is supplied separately with `--owner-public-key`; there is no detached `approved=true` switch.

## Commands

```text
pf-product publish-artifacts <approval-package> --owner-approval <record> --owner-public-key <key> (--dry-run | --fixture --fixture-dir <directory>)
pf-product promote <approval-package> <artifact-publication-receipt> --owner-approval <record> --owner-public-key <key> --fixture --fixture-dir <directory> [--output-dir <directory>]
pf-product qualify <promoted-payload>
pf-product deploy-site <approval-package> <qualified-payload> --owner-approval <record> --owner-public-key <key> (--dry-run | --fixture --fixture-dir <directory>) --production-truth <snapshot>
pf-product verify-live <publication-record> --owner-approval <record> --owner-public-key <key> (--fixture --fixture-dir <directory> | --live-read-only)
```

`approvedActions` are consumed per stage: `PUBLISH_ARTIFACTS`, `PROMOTE_CANONICAL_STATE`, `DEPLOY_SITE`, and `VERIFY_LIVE`. Each stage may use a separately signed approval record. The artifact receipt embeds its signed publish approval; promotion re-verifies that signature and fetches every planned object again from the fixture's public-origin tree before accepting the receipt. A narrow artifact-only approval cannot promote canonical state or deploy the site.

## P7 artifact handling

The artifact plan freezes the `proof-foundry-downloads/<product>/v<version>/` keys, source paths relative to the frozen candidate, byte lengths, SHA-256 values, content types, dispositions, cache policy, public URLs, object count, and the corresponding Wrangler commands. Every planned write command contains `--remote`. Existing objects are accepted only when bytes and metadata are identical; conflicting versioned keys are held. A fixture upload is followed by a public-origin byte fetch and digest check for every object.

Partial writes produce `PARTIAL_PUBLICATION_HOLD`, `artifact-publication-receipt.json`, and `public-object-ledger.json`. Successful immutable objects are never removed automatically. No receipt reaches `ARTIFACTS_PUBLISHED_VERIFIED` until all required public bytes match. A `PRESENTATION_UPDATE` has an explicit zero-object receipt.

## P8 candidate source and payload

Promotion rechecks all frozen input digests and base pre-images, applies only the candidate's approved product paths and `site-manifest.json` in a local clone of the approved base, then derives public release fields from the signed Capsule, owner action, and verified artifact receipt. The clone creates an isolated source commit with the approved time as its commit time. It is never pushed or merged into the publisher checkout. The current registry, manifest state source, and `scripts/build-site.ps1` produce the payload. The payload manifest lists every byte path, length, and SHA-256 and binds the candidate source commit/tree and manifest digest. Qualification freezes those bytes; deploy re-hashes them and refuses any difference.

The approved base may be a later committed site correction on the frozen root's linear history. Promotion clones that exact commit, preserving corrected site content. Deployment still requires the supplied production truth snapshot to identify the same predecessor commit and tree; a local correction alone cannot satisfy that check.

At package load, P7–P9 recompute the current committed site base with the P3–P6 resolver. A signed package from an earlier site base is stale and stops before artifact publication, promotion, or deployment, even if its publisher commit remains an ancestor of HEAD. The signed approval, source-binding file, and candidate state must all identify the selected base commit, tree, and committed manifest hash.

`pf-product qualify <promoted-payload>` refreshes ignored canonical `public/`, then runs the publisher, legacy capsule, P7/P8/P9, H13, H11, H12, Truth Files, release truth, receipts, H9 binding, H9 homepage, and `git diff --check` authorities. All must pass before the state becomes `SITE_PAYLOAD_QUALIFIED_UNDEPLOYED`.

## PAGES and live closure

Pages plans always target project `proof-foundry-site`, branch `main`. The generated Direct Upload command is `wrangler pages deploy "<qualified-public-dir>" --project-name proof-foundry-site --branch main`, with the candidate source `--commit-hash` and a fixed candidate message. A fixture upload copies the exact frozen bytes. If upload succeeds and byte verification fails, the state is `DEPLOYED_UNVERIFIED`; an existing deployment receipt blocks any second upload attempt.

Deploy requires an explicit production truth snapshot and compares its source commit/tree to the signed predecessor. This tranche's dry-run and fixture transports do not query or mutate Cloudflare. `verify-live --live-read-only` is the only real-origin path; it uses GET requests to the two fixed public hosts, disallows redirects, and never writes. Fixture mode reads the local `site/` and `proof-foundry-downloads/` trees.

P9 checks the complete candidate sitemap route set, truth source commit/tree/count, product Truth File projection, product/catalog/Truth File pages, release record, artifact bytes, unrelated product projections and commerce labels, homepage bytes, and cross-surface version/URL consistency. Only all-pass produces `PUBLISHED_VERIFIED`, `publication-receipt.json`, `publication-closure.md`, and `live-verification.json`.

## Runtime boundary and rollback

`LIVE_MUTATION_ENABLED` is deliberately `false` in this tranche. There is no live R2 or Pages adapter, and `--live` fails closed. Normal commands require either `--dry-run` or a local `--fixture` transport. No command calls Wrangler. The exact command strings are plans only.

Rollback is planning only and separates three actions: retain immutable R2 objects, restore canonical source from the approved predecessor in an isolated checkout, and plan a new Direct Upload of a known predecessor payload. No delete, canonical production rollback, redeploy, or Cloudflare control-plane call is automated.
