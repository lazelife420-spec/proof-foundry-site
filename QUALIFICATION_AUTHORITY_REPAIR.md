# Release-truth qualification repair

Base production source: `54ef94acab654306664b091a185f10ca779225cb`, tree
`04ac5f39e91fd1682bfb61b1149f8636111dc542`. This is a qualification and intake
successor, not a new public release, authority cutover, or deployment candidate.

Release assertions read `release-truth.json` through the pinned shared reducer.
`site-manifest.json` still supplies presentation, ordering, links and compatibility
configuration. No generated website output is read to author release facts.
Historical route comparisons compile the authored model at the compared revision;
object insertion order is not a content event. The deployed baseline is an exact
commit, not a workstation-specific branch name.

The production generator, model, reducer, schemas, Pages handlers, homepage,
product modules, assets and deployment machinery are unchanged. Fixture controls
start with the shared model's derived compatibility transport, then mutate that
disposable transport to test the unchanged consumer validators. Their output must
remain under the process temporary directory outside the source checkout.
Production's rejection of alternate manifests, registries and transports remains
in force. Fixture output cannot satisfy the sealed strict-v2 deployment gate.

H13 retains all 200 assertions. Unmodified authored transport is built separately
for exact fixture-home byte comparisons. Withdrawal checks name the actual
withdrawn version, and hostile JSON controls assert the literal parsed value.
The old Studio Root homepage assumptions are replaced with the shipped Proof
Ledger structure, accessible plate, release specimen and current stylesheet.
All other public data, escaping, routes, hashes and download controls remain.
H11 tests the stronger sealed-source deployment policy: staged, unstaged and
untracked source all fail closed, and the removed dirty-deploy flag cannot bypass it.

## Active intake disposition

Capsule inspection, unverified validation, presentation-only module import and
local noindex preview remain available. They read canonical release facts through
the shared projection. They do not establish qualification or signing authority.

The legacy publisher's materialization, artifact publication, canonical promotion
and deployment entry points fail
closed with `SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED` under current authored
authority, before creating proposals, accessing signing material, or writing
release facts. This includes presentation submissions through that old publishing
pipeline: its complete shared-authority qualification contract is not yet migrated.
A separately qualified shared-model intake is required to re-enable publishing.

All legacy P3–P6 publishing regression assertions are retained in explicit
temporary compatibility fixtures with no Git remote. Those fixtures are seeded
from the authored model's projection, never from generated production files.
The actual current-authority CLI is checked separately for rejected materialization
and promotion. Legacy fixture PASS is not evidence that shared-model publishing
is enabled. Existing fixture-only P7–P9 cryptographic and publication controls remain.

## Frozen payload qualification

The repair commit identifies engineering/test source. The public payload retains
the already-deployed production source identity above. Two independent builds use
the existing complete `TruthCommit`/`TruthTree`/`TruthCommittedAt` override for that
frozen identity, after proving every public rendering input is unchanged.
Their full 261-file inventories, including sealed Pages functions, must equal the
preserved production payload without normalization or ignored metadata.
Default builds still truthfully identify their own Git HEAD; this repair does not
silently pin or falsify a future deployment's provenance.

The seven products, eleven channels, v1 compatibility, strict v2 semantics,
`installationAuthority = NONE` and `productionSigningAuthority = HOLD` remain.
No master movement, push, deployment, App/Android work, or governance operation
belongs to this tranche.
