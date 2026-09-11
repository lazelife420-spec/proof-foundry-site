# P2-1 TEST RESULTS REPORT (FINAL QUALIFICATION)

**Date:** 2026-09-10
**Gate:** `PF_WEB_P2_1_SUPPORT_CHECKSUM_FINAL_QUALIFICATION_GATE`
**Status:** `ALL GREEN / 100% PASS`

---

## 1. AUTOMATED TEST FREEZE SUMMARY

| Test Suite Script | Assertions Passed | Assertions Failed | Status |
| :--- | :--- | :--- | :--- |
| `scripts/build-site.ps1` | 7 products validated, 11 directory routes | 0 errors | PASS |
| `scripts/test-signature-home.ps1` | 15 passed | 0 failed | PASS |
| `scripts/test-receipts-invariants.ps1` | 54 passed | 0 failed | PASS |
| `scripts/test-release-truth.ps1` | 11 passed | 0 failed | PASS |
| `scripts/test-customer-trust-p2-1.ps1` | 32 passed | 0 failed | PASS |
| `scripts/Verify-PublicSite.ps1` | All target routes green | 0 errors | PASS |
| `git diff --check` | 0 whitespace warnings | 0 errors | PASS |

**Total Suite Assertions:** 112 Passed / 0 Failed

---

## 2. FOCUSED P2-1 TEST BREAKDOWN (`test-customer-trust-p2-1.ps1`)

- **Route Generation:** PASS (`/support/index.html` exists)
- **Header Nav Link:** PASS (Header contains `/support/`)
- **Footer Nav Link:** PASS (Footer contains `/support/`)
- **Product Signposts (7 Products):** PASS (All 7 product pages expose support path)
- **Anchor Structure:** PASS (`#products`, `#windows`, `#android`, `#checksums`, `#downloads`, `#report`)
- **State A Self-Service Rules:** PASS (Disclaimer present, no `<form>`, no submit button, no fake email, no unrendered placeholders, private data warning present)
- **Windows Security Wording:** PASS (`when it is safe to click Run Anyway` denied globally)
- **Checksum Semantics:** PASS (Byte-identity match standard defined, 8-field schema present, `checksum proves safe` / `proves authenticity` denied)
- **Lights Out Link Fix:** PASS (Unlinked "contact the project" text updated to point to `/support/#report`)
- **P1 Regression Protection:** PASS (RG-05 Branch Qualified, Cache Vault unavailable notice intact, Lights Out HOLD state intact, old deployment receipt link absent)
