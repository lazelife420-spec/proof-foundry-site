# Lights Out Evidence Link Adjudication (F05)

**Audit Date:** 2026-09-10 (2026-09-11 UTC)

---

## 1. Context

The Lights Out release entry previously contained a `proofLinks` array pointing to `/reports/deploy-receipts/2026-06-30-proof-foundry-site.md`, which is a website deployment receipt rather than the Lights Out v11.1.3 application qualification receipt.

## 2. Adjudication & Resolution Applied

Per Section 8 of the directive, since the internal application qualification receipt (`6b67a712-33ba-4cd6-9c4a-81e66f056750`) is an internal Reality Gate receipt and not published as a standalone web markdown file:

* The misleading website deployment receipt link (`/reports/deploy-receipts/2026-06-30-proof-foundry-site.md`) was removed from `proofLinks` (`proofLinks: []`).
* The evidence label in `site-manifest.json` was updated to `"Qualification summary (Reality Gate receipt 6b67a712...)"` with `url: null`.
* Presentation download notice added: `"Downloads are currently on hold. Checked 9 September 2026; candidate v11.1.3 is in qualification and publication is on hold."`
* Verification status for `PUBLIC_DOWNLOAD` updated to `UNAVAILABLE`.
