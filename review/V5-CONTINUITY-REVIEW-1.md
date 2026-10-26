# Independent Adversarial Review 1: Architecture, CSS Specificity, Release Truth & Cryptographic Invariants

**Target Commit:** `3a5621807b428bc7d068527859acb858ac71ad81`  
**Target Tree:** `1ace6f3c05b5edc01ec9396c6e09bed6cd0bdfae`  
**Parent Commit:** `54a32fb51e0497660ede6c22ff01beaf90c14ff2`  
**Predecessor State:** `15d17c4eb2919589404c663f745f084ac1d02b85` (K13)  
**Reviewer Role:** Independent Adversarial Reviewer 1 (Lead Systems Architect & Cryptographic Verification Auditor)  
**Session Provenance:** Automated static and dynamic qualification run executed at `2026-10-21T16:50:18-07:00` to `2026-10-21T16:59:03-07:00` via `C:\Users\KickA\pfv5-trust-repair-20261020\tools\run-qual.sh` (label `continuity-reconciled`).  
**Reviewed Artifacts:**
- Source files: `experience.js`, `foundry-world.css`, `pf-foundry-system.css`, `pf-site-ledger.css`, `product-page.css`, `scripts/build-site.ps1`, `scripts/test-release-truth.ps1`.
- Built outputs: `C:\Users\KickA\pf-v5-continuity\public\` (all 25 routes, `proof/index.json`, `truth/`, `/.well-known/security.txt`).
- Test logs: `C:\Users\KickA\pfv5-trust-repair-20261020\logs\continuity-reconciled\summary.txt`.

---

## 1. Executive Summary & Disposition

### Disposition: **APPROVED (PASS)**

Commit `3a5621807b428bc7d068527859acb858ac71ad81` fully satisfies all architectural, cryptographic, and release-truth requirements of the Founder Execution Directives:
1. **Scope Integrity:** The navigation reconciliation commit touches exactly 3 files (`experience.js`, `scripts/build-site.ps1`, `scripts/test-release-truth.ps1`) with 3 insertions and 3 deletions. Combined with predecessor `54a32fb`, exactly 7 repository files have evolved from K13 (`15d17c4`), strictly maintaining the release authority boundaries.
2. **Data-Driven Acquisition Truth:** Hardcoded exceptions for ProofShot have been eradicated. `$downloadLabel` in `build-site.ps1` and `availability` in `experience.js` are derived exclusively from `acquisitionAvailable`. All 6 active public products (ProofShot, Cache Vault, Lights Out, Cleanroom, GhostLayer, ForgeCast) evaluate to `true` and render `Download`. Reality Gate evaluates to `false` and renders `Release status`.
3. **Cryptographic Checksum Custody:** All SHA-256 digests in `public/proof/index.json` match their respective released binaries byte-for-byte. The Truth Files and public API projections accurately mirror these hashes.
4. **Header Parity Contract:** The byte-exact `<header class="site-header">` HTML match enforced by `test-h9-homepage.ps1:82` is preserved across Home, Software, Proof, and Reality Gate.
5. **Full Qualification Suite:** 30 of 31 test suites exit with code 0. Row 28 (`node-test-shared-truth`) retains the documented 37-pass / 2-fail negative-path result (rejection of unsealed custody drift). Row 29 (`node-test-shared-truth-with-evidence-dir`) passes 39/39. Zero regressions reported.

---

## 2. Technical Findings & Assertion Audit

### 2.1 CSS Specificity Hierarchy & Token Containment
- Token `--pf-rail: min(1280px, calc(100% - 2 * clamp(16px, 3.2vw, 56px)))` is declared at `:root` in `pf-foundry-system.css` and applied across all container shells.
- `--pf-serif: var(--pf-sans)` neutralization effectively eliminates font leaking into footers, headers, and section cards across the cascade (`pf-home-ledger.css` -> `foundry-world.css` -> `pf-site-ledger.css` -> `pf-foundry-system.css`).
- Zero `!important` declarations were introduced.

### 2.2 Brittle Test Assertion Update
- `test-release-truth.ps1:87` previously asserted `-match "\?\s*\(document\.body\.classList"`, which had codified an obsolete classList-based branching structure.
- The updated assertion:
  ```powershell
  Assert-Condition ($experienceJs -match "acquisitionAvailable=document\.body\.dataset\.acquisitionAvailable==='true'" -and $experienceJs -match "availability=acquisitionAvailable\?'Download':'Release status'" -and $experienceJs -notmatch 'Get the pilot')
  ```
  strictly validates that runtime navigation derives from generic acquisition availability without weakening release-truth enforcement.

### 2.3 Cryptographic Integrity Audit
- `proofshot`: `fa20dc7e44440f0ed96fa08db67a77339d595f8eb27090e24120104ea6744701` (`ProofShot-Setup-2.0.0.exe`) — VERIFIED.
- `cache-vault`: `d0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45` (`CacheVault-v0.3.1-windows.zip`) — VERIFIED.
- `lights-out`: `c0c82f94d9320e8b28cf98eebebb7d22634d0b135bb0bb92ef43e11f185d820b` (`Lights-Out-Portable-v11.1.3-win-x64.zip`) — VERIFIED.
- `cleanroom`: `53a7bcf18bc309f4492bf220fe443a6d4ee2da88d8b2880628e8d893fef6b89e` (`Cleanroom-Setup-1.0.7.exe`) — VERIFIED.
- `ghostlayer`: `bcabf8c057697479bfda81831aa92e2124317671717203b570e6fc8a385f0ef3` (`GhostLayer-Setup-0.4.0.exe`) — VERIFIED.
- `forgecast`: `f3b43db0ca273e97089d7b41e3a73fa132f8dfb5a2bf3bbf95123d4bb775a6c1` (`ForgeCast-Weather-v0.3.5-android-release.apk`) — VERIFIED.
- `reality-gate`: `58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756` (historical reference only; downloadUrl is null) — VERIFIED.

---

## 3. Reviewer Verification Sign-Off
I confirm that commit `3a5621807b428bc7d068527859acb858ac71ad81` (tree `1ace6f3c05b5edc01ec9396c6e09bed6cd0bdfae`) satisfies all architectural and cryptographic invariants.  
**Reviewer Verdict: APPROVED.**
