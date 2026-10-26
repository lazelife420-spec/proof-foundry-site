# V5 Live Base Custody Record

This commit reconstructs the source of the production deploy of theprooffoundry.com
whose original Git objects are lost. It records exactly what was deployed, what was
lost, how this content was verified, and what remains unproven.

## Deployed production identity (recorded, unrecoverable as Git objects)

- Commit: `3a5621807b428bc7d068527859acb858ac71ad81`
- Tree: `1ace6f3c05b5edc01ec9396c6e09bed6cd0bdfae`
- Parent: `54a32fb51e0497660ede6c22ff01beaf90c14ff2` (predecessor line: K13 `15d17c4eb2919589404c663f745f084ac1d02b85`)
- Committed: 2026-10-21T16:49:36-07:00, on local branch `pf-v5-continuity-reconciled`
- Cloudflare Pages production deployment `8284128e-a860-4dfc-9b51-26aba11998ba`,
  2026-10-22T00:13:46Z (Oct 21, 17:13:46 PDT), ad-hoc Direct Upload, result success.
- Cloudflare account audit event `01a160f4-ec02-71d5-a68f-efba35865da4`, actor: founder
  account via OAuth. Deploy authorization: recorded owner approval of the V5 cutover.
- Live truth records (`/truth/index.json`, `/truth/v2/index.json`) pin the same commit
  and tree and declare `websiteSourceBaseCommit` `c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce`
  — the ancestor this branch is based on.

## What was lost

The deployed commit's repository lived at `C:\Users\KickA\pfv5-trust-repair-20261020\work`
with linked worktrees `C:\Users\KickA\pf-v5-continuity` (the cutover worktree) and
`C:\Users\KickA\pf-v5-k13-contact`. The hosting folder was deleted; both worktrees are
orphaned. Recovery attempts on 2026-10-25 found the objects in none of: Recycle Bin
(empty), volume shadow copies (none), Windows File History (not configured), either
GitHub site repository (`3a56218` returns 422 in both), the local main clone's object
store, or the one on-disk Git bundle (`Downloads/PF_V5_QUALIFICATION_4b75b15.bundle`,
an unrelated Foundry DNA lineage, imported under `refs/recovery/v5/*`).

## How this content is verified

The cutover worktree `C:\Users\KickA\pf-v5-continuity` survived with its full file
content. On 2026-10-25 it was rebuilt with `scripts/build-site.ps1` using the recorded
identity overrides (`-TruthCommit 3a56218… -TruthTree 1ace6f3c… -TruthCommittedAt
2026-10-21T16:49:36-07:00`) into a scratch directory, and every emitted file was
downloaded from the live site and SHA-256 compared:

- 246 of 246 directly comparable files are byte-identical to production, including all
  25 routes, `/truth/` v1+v2 records, `/truth-files/`, `/proof/index.json`, sitemap,
  and all CSS/JS/image assets. The asset version stamp (`?v=384d08ccf100`) matches live.
- The 33 non-identical fetches are fully explained by edge behavior, not source drift:
  Cloudflare's managed robots.txt block (markers `BEGIN/END Cloudflare Managed content`),
  Scrape Shield email obfuscation on `/support/` (`/cdn-cgi/l/email-protection#…`), and
  the Pages Function `functions/__h14/[[path]].js` intercepting all `/__h14/*` requests.
- Independent review pins in `review/V5-CONTINUITY-REVIEW-1.md` and
  `review/V5-CONTINUITY-REVIEW-2.md` (both APPROVED the deployed commit) match this
  content, including the quoted `test-release-truth.ps1` assertion and the quoted
  `experience.js` acquisition-availability expressions.

## Scope of the guarantee, and known residue

Output parity proves the build-relevant content byte-equivalent to what production
serves. Files that produce no build output (documentation, tests, tools, review
evidence) are included exactly as found in the cutover worktree and may contain
post-deploy local additions; notably `review/CONTINUITY_CAPTURES/`,
`review/V5-CONTINUITY-REVIEW-*.md`, and `tools/*continuity*` postdate the deployed
commit and are preserved here as cutover evidence. The exact tree `1ace6f3c…` could
not be reproduced because the commit's precise tracked-file set is unrecoverable;
judgment calls made: `receipts/*` kept (tracked in ancestor `c7d8a49`, files identical
in both locations), `review/Proof-Foundry-Visual-Review.pdf` kept (`.gitattributes`
declares the approved visual-review artifact tracked), `brand/*.png` kept despite the
`.gitignore` note because the build copies them into `public/brand/` and all four serve
live byte-identically (proof they were present at deploy), `public/` and
`node_modules/` excluded (generated).

No push, tag, preview, or deployment is authorized by this record.
