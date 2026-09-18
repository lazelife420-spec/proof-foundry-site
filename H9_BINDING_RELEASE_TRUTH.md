# H9 binding release truth

Source/build inspection: 09/18/2026 07:11:02. **TRUTH = PASS; audited current release/frozen regressions = 0.** This is an independent read-only source/build audit after the final source/build lock, not a product runtime/security audit or deployment approval.

Canonical master and H9 HEAD: `34a291d78fa92f1a18cf76cef3ee56b391186e77`; committed TREE: `0958ee92f974670cb0ae55b2335ec415d09ce49c`. Canonical worktree: `C:/Users/KickA/Projects/Active/proof-foundry-site`; candidate worktree: `C:/Users/KickA/Projects/Active/proof-foundry-site-h9-homepage`; candidate branch: `h9/editorial-homepage-refoundation`. Canonical tracked worktree was clean. These commit/tree identifiers describe the production base, not the uncommitted candidate.

The binding entry is `receipts/h9-binding-20260918/entry-source.zip` (294 files), independently read entry-by-entry against its inventory: **294/294 byte-size and SHA-256 matches**.

- Entry ZIP SHA-256: `9651270bd5e2eaf0d56c80b93f026d2c972b09cb706a42d24450e7e5496d4387`.
- Entry inventory SHA-256: `258d214a37f893f36756558a1403b90de40c888583cbe5f92ca30bd2ea6f55c4`.

## Product authority locked

**PASS: all seven complete `products` objects match canonical master and the canonical sibling working manifest exactly.** Every nested field is included: release status, public/candidate/companion versions, artifact URLs and hashes, signing, limits, public reachability notices, product copy, tests, and presentation. The H9 manifest also remains byte-identical to binding entry.

- Source manifest SHA-256: `e80a7ce72aad3fb847c34c72f8e60241b15c43a8bcd54db3f3a9d54fbf47e828`.
- UTF-8 `JSON.stringify(products)` SHA-256, using existing property order: `2306f129830d50ebeb5b0f81cf9e4011de1daaf50aeeefcda71995becb655115`.
- The whole manifest differs from production in three inherited non-product presentation fields: two catalog links target `/software/`; the old foundry note acknowledges public ProofShot v2.0.0. Those were present at entry and are not product-truth changes.

## Public versus candidate truth

| Product | Public release | Boundary |
| --- | --- | --- |
| Cache Vault | Windows **v0.2.4 PUBLIC**; Android companion v0.2.0 | Android v0.2.1 remains on hold; canonical site says the v0.2.0 GitHub APK link is currently unavailable. Windows unsigned. |
| ProofShot | Windows **v2.0.0 PUBLIC** | Structural page-resource capture; not pixel screenshot capture. Unsigned installer. |
| Reality Gate | Windows **Developer Pilot v1.1.0** | Publication is public while the product remains a Developer Pilot; not an OS security sandbox or mandatory dependency for every tool. |
| Lights Out | Windows **v11.1.2**; Android **v11.1.1** | Windows/Android v11.1.3 candidates remain HOLD. Manifest artifacts below are non-public candidate evidence with null download URLs. Current public download-unavailable disclosure is preserved. |
| Cleanroom | Windows **v1.0.7 PUBLIC** | v1.0.10 is local/next build; not public. |
| GhostLayer | Windows **v0.4.0 PUBLIC** | RAM-first staging; explicit commit/disk boundary; external editing can create temporary disk copies. No zero-trace claim. |
| ForgeCast | Android **v0.3.5 PUBLIC** | Weather requests use network data. No analytics tracking does not mean zero network/location data. |

## Exact canonical artifact ledger

These nine records match both candidate and canonical complete product objects. A preserved public URL is a source record, not a new remote-reachability result. Null candidate URLs are intentionally retained. No installers were downloaded or executed for this report.

### Reality Gate — Reality-Gate-1.1.0-Developer-Pilot.zip

- Platform: Windows; signing: `UNSIGNED`; size: not recorded.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/reality-gate/v1.1.0/Reality-Gate-1.1.0-Developer-Pilot.zip).
- Checksum: [canonical checksum URL](https://downloads.theprooffoundry.com/reality-gate/v1.1.0/Reality-Gate-1.1.0-Developer-Pilot.zip.sha256.txt).
- SHA-256: `58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756`.

### Cache Vault — CacheVault-v0.2.4-windows.zip

- Platform: Windows; signing: `UNSIGNED`; size: 43262453 bytes.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/cache-vault/v0.2.4/CacheVault-v0.2.4-windows.zip).
- Checksum: [canonical checksum URL](https://downloads.theprooffoundry.com/cache-vault/v0.2.4/SHA256SUMS.txt).
- SHA-256: `717ed13efd3d8d4e5a16d4e412ed5be0fd20b0219918f913d7d2b44f021cae7e`.

### Cache Vault — CacheVault-Mobile-v0.2.0-android.apk

- Platform: Android companion; signing: `PRODUCTION_SIGNED`; size: 12887895 bytes.
- Download: [canonical artifact URL](https://github.com/lazelife420-spec/CacheVault/releases/download/v0.2.0/CacheVault-Mobile-v0.2.0-android.apk).
- Checksum: [canonical checksum URL](https://github.com/lazelife420-spec/CacheVault/releases/download/v0.2.0/SHA256SUMS.txt).
- SHA-256: `fb6c5a3034b1d25be55db2da8842e17cfb48a0f40d8c479441faf389040524ad`.

### Lights Out — Lights-Out-Portable-v11.1.3-win-x64.zip

- Platform: Windows; signing: `UNSIGNED`; size: 158683782 bytes.
- Download: `null` — not published.
- Checksum: `null` — no separate checksum URL recorded.
- SHA-256: `c7872350101906471e83d8c0649e1e65c5f9baa4591e0c02ccfd8780215726d6`.

### Lights Out — Lights-Out-v11.1.3-rc4-Reality-Gate-ProofBundle.zip

- Platform: Windows; signing: `UNSIGNED`; size: 158534697 bytes.
- Download: `null` — not published.
- Checksum: `null` — no separate checksum URL recorded.
- SHA-256: `2b7b15b3e7138185617a3263f6435572d8160948dd533420c0893f18aa75e192`.

### Cleanroom — Cleanroom-Setup-1.0.7.exe

- Platform: Windows; signing: `UNSIGNED`; size: not recorded.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/cleanroom/v1.0.7/Cleanroom-Setup-1.0.7.exe).
- Checksum: [canonical checksum URL](https://downloads.theprooffoundry.com/cleanroom/v1.0.7/SHA256SUMS.txt).
- SHA-256: `2cd6953015ce0b8e429c869564be11ad10504332aded10b442a58ea2b990a76e`.

### GhostLayer — GhostLayer-Setup-0.4.0.exe

- Platform: Windows; signing: `UNSIGNED`; size: not recorded.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/ghostlayer/v0.4.0/GhostLayer-Setup-0.4.0.exe).
- Checksum: `null` — no separate checksum URL recorded.
- SHA-256: `5c0f00fb7e6e58526f400e25a0f05e9f948c503479c82d6be4eb7d0aa9f06251`.

### ForgeCast — ForgeCast-Weather-v0.3.5-android-release.apk

- Platform: Android; signing: `PRODUCTION_SIGNED`; size: 77331690 bytes.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/forgecast/v0.3.5/ForgeCast-Weather-v0.3.5-android-release.apk).
- Checksum: [canonical checksum URL](https://downloads.theprooffoundry.com/forgecast/v0.3.5/ForgeCast-Weather-v0.3.5-android-release.apk.sha256.txt).
- SHA-256: `a28db27cd16b3e45f3e75cc0d7c7a4b101646573de9954ec40dbf03e5439bea1`.

### ProofShot — ProofShot-Setup-2.0.0.exe

- Platform: Windows; signing: `UNSIGNED`; size: 121733716 bytes.
- Download: [canonical artifact URL](https://downloads.theprooffoundry.com/proofshot/v2.0.0/ProofShot-Setup-2.0.0.exe).
- Checksum: [canonical checksum URL](https://downloads.theprooffoundry.com/proofshot/v2.0.0/SHA256SUMS.txt).
- SHA-256: `fa20dc7e44440f0ed96fa08db67a77339d595f8eb27090e24120104ea6744701`.

## Receipt, imagery and claim requirements

- The supported Cache Vault source commit is `abbd84462a8165068405cbfcddf4bfaf6b8f6f29` (40 hexadecimal characters), from current canonical product source. Its Windows artifact SHA-256 is `717ed13efd3d8d4e5a16d4e412ed5be0fd20b0219918f913d7d2b44f021cae7e` (64 characters). These must remain separately labeled.
- The ProofShot installer SHA-256 is `fa20dc7e44440f0ed96fa08db67a77339d595f8eb27090e24120104ea6744701`. The existing canonical abbreviated source identifier `6e7fc6bf` is not an artifact checksum and is not expanded by inference.
- Product screens are authentic existing captures, not fresh recordings of every current binary. ProofShot shows the earlier HyperSnatch v1.6.18 engine; Cleanroom includes an earlier v1.0.6 interface; Lights Out shows a dry-run/focus state; Reality Gate uses a synthetic demo repository in the real application; Cache Vault/GhostLayer use samples; ForgeCast weather is recorded, not live.
- The cinematic environmental artwork is decorative studio imagery. It must not supply invented UI, versions, hashes, weather, receipts or claims. The four supplied design references bind composition, not product facts.
- No new test totals, verification timestamps, artifact sizes, signer status or release approvals may be inferred from the visual design. Hashes/receipts do not certify malware freedom, Microsoft approval, legal admissibility, court certification or zero risk.

## Verified binding homepage and generated output

The independent audit in `receipts/h9-binding-20260918/release-truth-frozen-audit.json` passes **337/337 source/build/frozen assertions**, zero failures. This count is separate from repository guards, browser assertions and HTTP checks.

- All seven complete product objects remain exact across canonical master, canonical sibling, H9 source and generated manifest. The entire generated manifest also equals the source manifest. Registry artifacts preserve all nine exact URL/hash/size/signing records; each product's four exposed release fields match canonical truth. Companion public truth remains covered by full-manifest parity.
- All **15 current homepage manifest tokens** resolve to canonical values and their values occur in built output. No unresolved product/include marker remains. Seven unique product identities each have a direct canonical route and their correct public version; Reality Gate's own scene explicitly says Developer Pilot. Cache Vault appears in both hero and featured mosaic, without inventing an eighth product.
- The visible ProofShot scene labels its scope as structural page-resource capture. The ProofShot and Cache Vault ledger rows each contain the exact canonical artifact filename and 64-character SHA-256, plus Windows/unsigned labels supported by their primary artifact records. Cache Vault's source identifier remains separately labeled Source commit and is supported by canonical product source. Its checksum link remains exact.
- Lights Out's literal Android v11.1.1 label was independently compared with canonical `release.companionPublicVersion` and agrees. The frozen Lights Out page still distinguishes public versions from held v11.1.3 candidates and unavailable downloads; the homepage offers Explore rather than a candidate-download action.
- ForgeCast retains recorded-weather/network/no-analytics bounds; GhostLayer retains the explicit commit and external temporary-disk-copy bounds; Reality Gate says it is not an OS security sandbox. The release ledger explicitly distinguishes checksums from signing/security guarantees. No positive zero-trace, malware-free, Microsoft-approved, universal-security or court-certification claim was introduced.
- Earlier/sample-interface disclosures are present in actual generated homepage and catalog: ProofShot's earlier engine/HyperSnatch preview, Cleanroom's earlier v1.0.6 interface, Lights Out sample dry run, Runroom sample repository, Cache Vault sample clips and recorded ForgeCast weather. Canonical product pages and authentic capture bytes remain untouched.

Generated-output comparison independently read the preceding owner ZIP, not a summary: **203/207 existing generated files are byte-identical; 4 differ** (homepage HTML/CSS/JS and the proof registry's ordinary generatedAt field only); **3 decorative environment WebPs are added**; **0 files are missing**. The current built tree contains 210 files. See `receipts/h9-binding-20260918/frozen-generated-audit.json` and the frozen-surfaces report.

**Current truth conflicts: 0. Actual release/frozen regressions: 0. Unadjudicated failures in this audit: 0.** Runtime/browser/visual acceptance remains separately evidenced. These machine records bind the observed source/build snapshot; any later homepage/source rebuild requires refreshing affected hashes before packaging.
