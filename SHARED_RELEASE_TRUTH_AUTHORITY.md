# Website release authority

The sole authored release-fact input is `release-truth.json`, byte-pinned to
the shared foundation in private App custody at `c5df5bb805f88af41456351e3a648063f3da03c8`.
The reducer and canonical serializer retain those exact custody bytes.
`site-manifest.json` authors website presentation, ordering, navigation and
website evidence wording; its products cannot author release facts or versions.
Selectors choose a channel, never a literal version. No generated output is
read back into an authored input.

The foundation's embedded authority metadata describes its historical
reconciliation against shipped commit `c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce`.
It is not a current website adoption claim. Website v2 source provenance names
the actual authored input and scopes that foundation metadata as historical.
The unmodified internal foundation projection is retained in qualification
evidence; it is not published with an ambiguous current-authority assertion.

## Compatibility and richer facts

The existing `/truth/index.json` and `/truth/products/*.json` remain v1.
Their strict schema is unchanged. Their `generatedFrom: site-manifest.json`
names the **derived** compatibility manifest, materialized in memory from
the authored model plus presentation and emitted as `/site-manifest.json`.
That emitted manifest is marked `DERIVED_V1_COMPATIBILITY` and is never used
as an upstream input. The root authored presentation file has no duplicated
release facts. V1 keeps all existing product semantics and shape.

`/truth/v2/index.json`, `/truth/v2/products/*.json` and `/truth/schema-v2.json`
name `release-truth.json` as their authored authority. Product records preserve
all channels, scoped qualification reports, artifact identity/signing state,
unknown package fields, and withdrawal reasons. Cleanroom public 1.0.7 and
candidate 1.0.10 remain distinct. Lights Out Windows public 11.1.3, Android
public 11.1.1 and Android built-only 11.1.3 remain distinct. Reality Gate
withdrawn 1.1.0 has no public version or download.

The shipped v1 schema already rejects two unchanged null URLs: Lights Out's
label-only evidence URL and Reality Gate's withdrawn artifact URL. This
migration preserves the existing data and schema; it does not invent URLs
or weaken the withdrawn state. V2 explicitly supports these unknown/absent
URLs. Qualification records the two inherited v1 exceptions separately.

`/proof/index.json` retains release/artifact semantics and adds source
provenance. Website views retain their design. Only visible authority-source
wording on proof/truth pages and the committed-source label on Truth Files
change. The current homepage release facts and design remain identical.

## Publication gate and rollback

Two fresh builds from the clean candidate commit must produce identical
files, including the compiled unchanged Pages function bundle and routes.
The qualification receipt binds their complete inventory to exact commit/tree,
seven-product parity, 11 channels, visual parity and the pinned rollback.
`deploy.ps1 -Mode stage` uploads that artifact to a preview branch without
rebuilding it. Production additionally requires a receipt verifying every
servable byte and actual Pages runtime parity at that immutable preview URL.
The 29 H14 helper assets are deliberately intercepted by the existing Worker
router, and remain sealed internal upload inputs. Their runtime products and
index are exercised directly. The 228 public assets are verified byte-for-byte;
the four Pages control inputs are sealed with the complete artifact inventory.
Production uploads the same artifact using pinned Wrangler 4.105.0 and
`--no-bundle`. Uploads with an unknown outcome are inspected, never retried
automatically.

Rollback is the c7d8a499 Proof Ledger production state, Cloudflare deployment
`fbc586a2-2146-4db8-8052-0a074fc28276`. Its source and frozen generated artifact
are preserved outside the checkout; a restoration upload can serve those
same facts and source binding if a rollback is needed.

Install execution remains blocked. Artifact signing facts grant no signing
authority. Production signing authority remains HOLD. Windows frozen custody,
Android RC4, and the old dirty local website checkout are outside this tranche.
