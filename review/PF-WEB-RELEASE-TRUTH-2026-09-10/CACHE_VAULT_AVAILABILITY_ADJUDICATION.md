# Cache Vault Availability Adjudication (F02 & F03)

**Audit Date:** 2026-09-10 (2026-09-11 UTC)

---

## 1. Context & Disambiguation

Cache Vault v0.2.3-rc1 is a Reality Gate canonical-proven release candidate. Its public download URL returned 404 on 9 September 2026. Cache Vault v0.2.2 remains the last public desktop release.

Previously, the release record matrix presented `Public download: VERIFIED` because the URL field existed in metadata, creating an ambiguity between historical verification and present URL availability.

## 2. Structural Model Applied

We structurally separate historical verification from current availability:

* **Historical Artifact Verification:** `VERIFIED` (`verifiedAt: "2026-09-01"`)
* **Current Download Availability:** `UNAVAILABLE` (`checkedAt: "2026-09-09"`)
* **Verification Status Matrix (`PUBLIC_DOWNLOAD`):** Set to `UNAVAILABLE` when `downloadUnavailable: true` is set.
* **Customer Journey Wording:** Explicitly states: *"Download links are currently unavailable. Checked 9 September 2026; public and candidate release classifications are unchanged."*
