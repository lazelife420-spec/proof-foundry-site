# Test Results — P1 Release-Truth Closure Gate

**Audit Date:** 2026-09-10 (2026-09-11 UTC)

---

## 1. Test Suite Executions

### A. Site Rebuild & Manifest Validation (`scripts/build-site.ps1`)
* **Manifest Validation:** 7 products, 0 errors
* **Public Generation:** `public/` regenerated (7 visible products, 10 directory routes)
* **Proof Registry:** `/proof/index.json` generated with 100% manifest parity
* **Exit Code:** `0` (PASS)

### B. Homepage Signature Invariants (`scripts/test-signature-home.ps1`)
* **Results:** `15/15 PASS, 0 FAIL`

### C. Receipt & Invariant Test Suite (`scripts/test-receipts-invariants.ps1`)
* **Results:** `54/54 PASS, 0 FAIL`

### D. Release Truth Invariants (`scripts/test-release-truth.ps1`)
* **Results:** `11/11 PASS, 0 FAIL`
  - PASS: Reality Gate matrix includes RG-05
  - PASS: RG-05 matrix row reports Branch Qualified, resolving F01 contradiction
  - PASS: Cache Vault exposes explicit download unavailable notice
  - PASS: Cache Vault states availability check date
  - PASS: Lights Out release evidence does not link to site deployment report
  - PASS: Lights Out FAQ does not contain overgeneralized unsigned warning copy
  - PASS: Lights Out FAQ contains accurate reputation-based SmartScreen copy
  - PASS: Registry covers all 7 products
  - PASS: Registry Reality Gate version is 1.1.0
  - PASS: Registry Cache Vault verification status is VERIFIED
  - PASS: Registry Lights Out release status is HOLD

### E. Git Diff Check (`git diff --check`)
* **Results:** `PASS` (0 whitespace/formatting errors)
