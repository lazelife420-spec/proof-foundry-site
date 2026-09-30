# Product publishing operator workflow

This is the operator guide for the Proof Foundry Product Publisher. It describes the local, fixture-first path from a submitted Product Capsule to an owner-reviewed publication candidate. It does not add a public website workflow or change product release truth.

## Authority boundaries

- Product Capsules are unpacked submission directories. `inspect` and `validate` are offline and read-only.
- `site-manifest.json` remains the authority for public release state, versions, artifacts, downloads, hashes, and verification. Product modules provide presentation and registry metadata; they cannot grant release authority.
- Candidate files, builds, previews, and fixture publication data remain isolated from production sources. Candidate routes use `/__preview/<id>/`, `/__preview/software/`, and, when needed, `/__preview/`.
- The existing `scripts/build-site.ps1` registry, renderer, and `ProductStateSource` seam are used. There is no second renderer, canonical manifest, or production API activation in this workflow.
- Freeze creates `FROZEN_FOR_OWNER_REVIEW`; it does not approve, verify, or publish. Each later publication stage requires an owner-signed Ed25519 decision bound to the exact frozen candidate and allowed action.
- P7–P9 live mutation is disabled. Use only `--dry-run` and local `--fixture --fixture-dir` transports here. This integration does not call Wrangler or write R2/Pages.

## Candidate lifecycle

Run the commands from the website repository with an unpacked Capsule directory:

```powershell
.\pf-product.ps1 inspect <capsule-directory>
.\pf-product.ps1 validate <capsule-directory>
.\pf-product.ps1 materialize <capsule-directory>
.\pf-product.ps1 preview <candidate-directory>
.\pf-product.ps1 qualify <candidate-directory>
.\pf-product.ps1 freeze <candidate-directory>
```

`materialize` writes an external candidate directory under the operating-system temporary directory by default. An explicit `--output-dir` must also be outside the checkout and Capsule. `preview` calls the existing site renderer with staged product files and candidate state through `-StateSourcePath`; candidate pages stay in the noindex preview namespace. `qualify` revalidates the Capsule, hashes, proposed paths, preview, build, and registered website authorities. It regenerates canonical ignored build output from source before running public-surface checks, so stale `public/` contents are not an input authority.

The submission types have distinct boundaries:

- `NEW_PRODUCT` proposes a hidden preview module and an `UNRELEASED` manifest record. It does not create public downloads or verified status.
- `NEW_VERSION` proposes canonical release-manifest changes. Module, copy, and media changes must be explicit; they are not silently inferred as part of the version update.
- `PRESENTATION_UPDATE` does not mutate the release manifest. Its release version, artifact facts, verification, receipt identity, and source binding remain sealed to the base record.

The states mean:

| State | Meaning |
| --- | --- |
| `INVALID` | Capsule or candidate validation failed. Correct findings and restart from inspection. |
| `VALID_UNVERIFIED` | Offline Capsule validation/materialization passed. Claims and release evidence are not independently authoritative. |
| `QUALIFIED_UNPUBLISHED` | Candidate and website qualification passed; nothing has been published. |
| `FROZEN_FOR_OWNER_REVIEW` | Candidate bytes and impact report are packaged for review. Freeze does not approve or publish. |
| `OWNER_APPROVED` | An owner supplied a valid signed decision bound to this frozen candidate and the specific next action. Approval is never inferred from freeze. |
| `ARTIFACTS_PUBLISHED_VERIFIED` | Fixture/public-origin byte checks match the signed artifact plan and receipt. In this tranche this state is exercised with fixtures only. |
| `SITE_PAYLOAD_QUALIFIED_UNDEPLOYED` | Promoted canonical site payload passed the required checks and is frozen, but has not been deployed. |
| `DEPLOYED_UNVERIFIED` | A deployment action was recorded but its expected live bytes were not verified. Do not retry a real upload from this state without owner adjudication. |
| `PUBLISHED_VERIFIED` | Publication record chain and verification checks passed. In this tranche, use fixture transports; no live mutation is available. |

## Owner-reviewed publication stages

The owner decision is a separate signed record, not a CLI flag. It binds the approval-package digest, Capsule/candidate identities, publisher and base-site source identities, artifact hashes, approval time, and allowed actions. Approvals are action-specific; approval for artifact publication does not authorize canonical promotion or site deployment.

```powershell
.\pf-product.ps1 publish-artifacts <approval-package> --owner-approval <record> --owner-public-key <public-key> --dry-run
.\pf-product.ps1 publish-artifacts <approval-package> --owner-approval <record> --owner-public-key <public-key> --fixture --fixture-dir <fixture-directory>
.\pf-product.ps1 promote <approval-package> <artifact-receipt> --owner-approval <record> --owner-public-key <public-key> --fixture --fixture-dir <fixture-directory>
.\pf-product.ps1 qualify <promoted-payload>
.\pf-product.ps1 deploy-site <approval-package> <qualified-payload> --owner-approval <record> --owner-public-key <public-key> --dry-run --production-truth <snapshot>
.\pf-product.ps1 deploy-site <approval-package> <qualified-payload> --owner-approval <record> --owner-public-key <public-key> --fixture --fixture-dir <fixture-directory> --production-truth <snapshot>
.\pf-product.ps1 verify-live <publication-record> --owner-approval <record> --owner-public-key <public-key> --fixture --fixture-dir <fixture-directory>
```

P7 plans immutable artifact objects and verifies fixture bytes. P8 rechecks the frozen inputs and applies only approved product paths and `site-manifest.json` in an isolated clone of the approved base. P9 qualifies the resulting site payload, then exercises deployment and verification against fixture transports. The P9 fixture set must include the `site/` payload and `proof-foundry-downloads/` object tree. `--live` fails closed; `--live-read-only` is a separate GET-only verification option and is outside this fixture qualification run.

## Qualification and source boundary

Candidate source binding starts at the frozen P0–P2 site receipt and follows a linear first-parent history. Publisher-only commits keep the existing site base; a later committed site change becomes the new base. The working manifest must match that commit, and non-publisher source must be clean. The owner-review package records the site base and publisher commit separately. A candidate created against an earlier base must be rematerialized after the base advances.

The publisher suites are `scripts/test-pf-product.mjs`, `scripts/test-pf-product-source-base.mjs`, `scripts/test-pf-product-p3-p5.mjs`, `scripts/test-pf-product-p6.mjs`, `scripts/test-pf-product-p7.mjs`, `scripts/test-pf-product-p8.mjs`, and `scripts/test-pf-product-p9.mjs`. Website qualification also covers the legacy Capsule flow, H13, H11, H12, Truth Files, release truth, receipts, H9 binding, H9 homepage, and `git diff --check`.

Candidate test fixtures use synthetic identities and bytes only. Do not create a real Capsule for a held product in this workflow. `CACHE_VAULT_ANDROID_0_2_1` and `REALITY_GATE_1_1_1` remain separate product-level holds; this website integration does not adjudicate or alter them.
