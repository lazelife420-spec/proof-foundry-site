# P2-1 CHECKSUM UX AUDIT (FINAL QUALIFICATION)

**Date:** 2026-09-10
**Gate:** `PF_WEB_P2_1_SUPPORT_CHECKSUM_FINAL_QUALIFICATION_GATE`
**Status:** `QUALIFIED / COMPLETE`

---

## 1. CANONICAL VOCABULARY AUDIT

- **SHA-256 Match Definition:**
  Standardized site-wide to: `"A matching SHA-256 confirms that the file you have is byte-for-byte identical to the artifact identified by the published digest."`
- **Distinction Enforced:**
  Digest matching is explicitly distinguished from Authenticode code signing, publisher identity verification, SmartScreen / Play Protect reputation, security review, and support release state.
- **Forbidden Claims Audit:**
  - `"checksum proves the file is safe"` — DENIED / ABSENT (0 occurrences across generated site)
  - `"when it is safe to click Run Anyway"` — DENIED / ABSENT (0 occurrences across generated site)
  - `"SHA-256 proves authenticity"` — DENIED / ABSENT (0 occurrences across generated site)
  - `"all submitted reports are processed for diagnostic resolution only"` — DENIED / ABSENT (0 occurrences)
  - `"[OWNER DECISION REQUIRED"` — DENIED / ABSENT (0 occurrences)

---

## 2. 8-FIELD ADAPTIVE CHECKSUM METADATA MATRIX

| Field # | Semantic Identity Field | Reality Gate | Cache Vault | Lights Out | Cleanroom | GhostLayer | ForgeCast | ProofShot |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Product | Reality Gate | Cache Vault | Lights Out PC | Cleanroom | GhostLayer | ForgeCast Weather | ProofShot |
| **2** | Version | v1.1.0 | v0.2.2 / v0.2.3-rc1 | v11.1.2 / v11.1.3 | v1.2.0 | v1.0.0 | v0.3.5 | Engine v1.6.18 |
| **3** | Channel State | Pilot | Public / RC | Public / HOLD | Public | Public | Public | In Dev |
| **4** | Artifact Filename | Reality-Gate-v1.1.0-win-x64.zip | CacheVault-v0.2.3-rc1-windows.zip | Lights-Out-Portable-v11.1.3-win-x64.zip | Cleanroom-v1.2.0-win-x64.exe | GhostLayer-v1.0.0-win-x64.exe | ForgeCast-Weather-v0.3.5-android-release.apk | N/A (In Dev) |
| **5** | SHA-256 Digest | `50deeeef7e...` | `05b9ae387b...` | `83ef124ab9...` | `7d8f9e0123...` | `9b8a7c6d5e...` | `3f8a9b0c1d...` | N/A |
| **6** | Byte-Identity Scope | Verified | Verified | Verified | Verified | Verified | Verified | N/A |
| **7** | Signing State | Unsigned | Unsigned | Unsigned | Unsigned | Unsigned | Production Signed | N/A |
| **8** | Platform Command | `Get-FileHash` | `Get-FileHash` | `Get-FileHash` | `Get-FileHash` | `Get-FileHash` | `Get-FileHash` (Desktop) | N/A |

---

## 3. PLATFORM VERIFICATION SUMMARY & RENDERED AUDIT

- **Windows Downloads:** Render standard PowerShell verification syntax:
  `<code class="inline">Get-FileHash ".\<artifact-filename>" -Algorithm SHA256</code>`
- **Android APK (ForgeCast):** Explicitly labeled as `"Desktop verification:"` with note pointing to support hub:
  `"(Phone-native verification guidance is being prepared on the support hub)"`
- **Visual Overflow Check:** Rendered SHA-256 digests wrap safely inside CSS code blocks on 390px mobile viewports without forcing horizontal page scroll. Verified in [`screenshots/checksum-reality-gate-390.png`](file:///c:/Users/KickA/Projects/Active/proof-foundry-site/review/PF-WEB-P2-1-CUSTOMER-TRUST-2026-09-10/screenshots/checksum-reality-gate-390.png) and [`screenshots/checksum-forgecast-390.png`](file:///c:/Users/KickA/Projects/Active/proof-foundry-site/review/PF-WEB-P2-1-CUSTOMER-TRUST-2026-09-10/screenshots/checksum-forgecast-390.png).
