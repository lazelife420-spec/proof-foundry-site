# Truth Files Public Contract

**Candidate:** branch `codex/pf-modular-html-r1`, isolated worktree `C:\Users\KickA\Projects\Worktrees\pf-modular-r1` (base `0dd208c`, uncommitted owner-review changes on top).
**Directive:** `PF_WEBSITE_20_PASS_MODULAR_HTML_TRUTH_FILES_MASTER_2026-10-26.md` — Truth Files generated from authoritative facts, immutable receipts kept.
**Compiled:** 2026-10-26, Factory, local Windows evidence only.
**Companions:** `schemas/PUBLIC_TRUTH_VERSIONING.md` (schema + source-binding policy — canonical), `SHARED_RELEASE_TRUTH_AUTHORITY.md` (authority decision), `MODULARITY_MUTATION_TESTS.md` (enforcement proof), `PAGE_EDIT_MAP.md` (editing map).

## 1. What a Truth File is

Every product has one public record, published as the same facts in five forms. A Truth File page is the human-readable receipt; the canonical machine record is the v2 JSON. None of the five forms is hand-written: all are generated from the authored release model by one deterministic build, and every form carries the identity of the commit and model it was built from.

## 2. The record stack

**Authority.** `release-truth.json` (authored model) is the sole release authority — versions, states, artifact identities, URLs, hashes, signing, withdrawal. It is held in source custody: `vendor/pf-shared-release-truth/provenance.json` pins its per-file SHA-256 plus a `modelSha256` of the model. The shared reducer (`scripts/shared-release-truth.cjs` + `vendor/pf-shared-release-truth`) is the only code path that turns it into public records.

| Public surface | Path | Role |
|---|---|---|
| Canonical machine record | `/truth/v2/products/<id>.json` (+ `/truth/v2/index.json`) | rich channel facts; schema published at `/truth/schema-v2.json` (`schemas/public-truth-v2.schema.json`) |
| Compatibility record | `/truth/products/<id>.json` (+ `/truth/index.json`) | v1 shape, kept stable per `schemas/PUBLIC_TRUTH_VERSIONING.md`; schema at `/truth/schema-v1.json` |
| Human record | `/truth-files/<id>/` | the Truth File page; carries `<link rel="alternate" type="application/json">` to the v1 record and links both JSONs in its Machine record section |
| Runtime state carrier | `/__h14/static-state.json` | all products' state/download facts for the shadow runtime |
| Presentation + compatibility carrier | `/site-manifest.json` | presentation input and derived fields; **not** a release authority — old "manifest is sole authority" wording in historical docs is superseded |

Every v2 record embeds `source` (`commit`, `tree`, `committedAt`, `releaseFactsSource.modelSha256`, `websiteProjectionSha256`) — the published-source binding doctrine in `schemas/PUBLIC_TRUTH_VERSIONING.md`: local preview builds are review artifacts; published public truth is valid only when generated from a tracked-clean committed checkout, and the deploy guard enforces it with a sealed artifact and served-byte verification.

## 3. What the Truth File page promises

Generated page anatomy (every product record, same skeleton):

| Section | Promise |
|---|---|
| Record hero | product identity + one state chip (Public release / Candidate / Withdrawn) from the model |
| Current truth | version, platform, release state, artifact availability — all model fields, never prose guesses |
| Verified against | release report status and scope, publication state, artifact identity (SHA-256 + signing status + dist type), test gates |
| Known limits | the model's limitation statements, verbatim |
| Record | released/report dates; Evidence and Proof links (only what the authority listed); ledger and product page links; a freshness line naming the source commit the whole site's public truth is bound to |
| Machine record | links to the v1 and canonical v2 JSON; states the doctrine in one line: same facts, same build, deterministic bytes |

Pages carry a `GENERATED FILE - DO NOT EDIT` banner naming their source and the rebuild command.

## 4. State semantics

| Model state | Renders as | Download |
|---|---|---|
| `PUBLIC_RELEASE` | "Public release" | available: artifact `downloadUrl`/`sha256Url`, download block present |
| `CANDIDATE` | "Candidate" | none (candidate qualification does not transfer; publication on hold) |
| `WITHDRAWN` | "Withdrawn" | never: `download.available=false`, all URLs null, withdrawal reason shown, scope `HISTORICAL_WITHDRAWN_RELEASE` |

Two standing conventions: a retained checksum on a withdrawn record identifies the withdrawn bytes and is not a code signature (the real Reality Gate record states this); qualification is scoped reported evidence and grants no installation or signing authority.

## 5. The withdrawal surface (three files, one shape)

A withdrawal is complete only when all three authority files carry the withdrawn shape. The real Reality Gate withdrawal is the reference for each:

| File | RG reference shape |
|---|---|
| `release-truth.json` (model) | `status=WITHDRAWN`; channel `track=WITHDRAWN` + `withdrawal` object; artifact `downloadUrl`/`sha256Url` null; `verification.scope=HISTORICAL_WITHDRAWN_RELEASE`; `verification.evidence=[]` |
| `site-manifest.json` (presentation) | top-level `proofLinks=[]`; `proofStatus="withdrawn · historical record"`; `presentation.downloadUnavailable=true`; `downloadLabel=null` |
| `products/<id>/module.json` (commerce) | the withdrawn commerce shape (copied from RG in the mutation fixture) |

Proven in `MODULARITY_MUTATION_TESTS.md` m3: with the full shape, a withdrawn product's download URLs appear **zero** times in the published tree and no download affordance renders anywhere; the builder is faithful — if the authority leaves an evidence URL behind, the site renders it as a passive historical link, so completeness is the authority's data decision, enforced by the RG shape as the checklist.

## 6. Enforcement (negative controls, all proven)

| Tamper | Outcome |
|---|---|
| Edit `release-truth.json` directly, no custody re-pin | build fails closed on the custody digest; nothing is published (m3 Phase 1) |
| Withdraw a product through the custody path | builds; changes only that product's records, its aggregates, and the global source digests; other products' v2 records change in `modelSha256`/`websiteProjectionSha256` only (m3 Phase 2) |
| Add a download CTA hardcoding an artifact filename literal | manifest validator rejects the template (m5) |
| Add the same CTA without the literal | build succeeds but the H9 binding gate fails: withdrawal truth remains canonical, no download CTA (m5b) |
| Hand-edit anything under `public/` | erased: the tree is regenerated from source on every build; the two-build byte diff in the qualification record proves deterministic bytes |

## 7. What consumers may rely on

1. Stable record URLs and published schemas (`/truth/schema-v1.json`, `/truth/schema-v2.json`); facts change freely within a schema, shape changes require a new `schemaVersion`, and v1 is never silently rewritten (`schemas/PUBLIC_TRUTH_VERSIONING.md`).
2. One fact, one source: every surface is derived from the same model in the same build; disagreeing copies are a bug, not a feature.
3. Deterministic bytes for the same model + commit; every record names its `source` identity.
4. `downloadUrl: null` plus `download.available: false` means no public download is offered, on every surface, in every form.
5. `evidenceIds` (e.g. `shipped-site-manifest`) identify where the evidence lives — the published site manifest — rather than restating it.

## 8. Editing rules

- **Any release fact** (version, download, checksum, status, withdrawal): the governed `release-truth.json` workflow only (`SHARED_RELEASE_TRUTH_AUTHORITY.md`). Never an HTML, `module.json` or `site-manifest.json` release-field edit.
- **Truth Files layout or wording**: `truth-files.html`, `truth-files.css`, or the Truth Files renderer in `scripts/build-site.ps1` — then rebuild; never the generated `public/truth-files/` pages.
- **A new published release receipt**: a new, properly authorized receipt; existing receipt bytes are never edited.
