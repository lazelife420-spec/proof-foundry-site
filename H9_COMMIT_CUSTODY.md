# H9 local source landing custody

The owner accepted the binding homepage's desktop/mobile pixels, catalog, release truth and frozen surfaces and granted one local commit using `feat(web): land H9 binding homepage refoundation`. Push, merge, tag, deployment, DNS and mailbox changes remain unauthorized.

Accepted owner package: `PF_H9_BINDING_WEB_DESIGN_OWNER_REVIEW.zip`, SHA-256 `3416bfbd2159c5cb8c1f659062edebf9fbcaf6b44897fd459be050aae2bd1ec8`. Its 392 payload entries matched the internal manifest. The package remains external local evidence, not a repository asset. The accompanying `H9_BINDING_*.md` documents describe that dated precommit acceptance snapshot; their original HEAD, test totals and unstaged-state statements are historical evidence.

## Intended source custody

The landing includes the reconciled homepage/catalog source and build integration, approved canonical release/discovery corrections, selected PF Mark G's four SVG variants, three binding-foundry WebPs, the accepted tracked test updates, three historical H9 test sources, current qualification tools and durable qualification fixtures. Current binding reports preserve asset provenance, release truth, frozen-surface accounting, performance limits and exact historical test adjudication.

No application design, manifest product object, public artifact URL or SHA-256 was changed after owner acceptance. The precommit differences from the accepted source are confined to making qualification reproducible from the committed files, adding the qualification runner/fixtures and this custody note. Git may normalize text CRLF to LF; every such difference is classified separately from content changes in the staged-source evidence.

Review ZIPs, screenshot/comparison exports, local preview tools, caches, logs, `__pycache__`, alternative PF marks/contact sheets and superseded review tools/packages are excluded. Existing tracked historical repository evidence is preserved unchanged; this landing does not delete old files. Untracked local review material is intentionally left in place.

The previous local builder recursively copied 19 unselected brand experiments/contact-sheet files into its public output. They are absent from a build containing only the intended staged files. They are not linked application dependencies. The staged build must preserve every retained public output, apart from recorded text newline normalization/content hash effects and the proof registry's generated timestamp.

## Reproducible qualification

Run from a checkout containing the canonical production history:

```powershell
python scripts/qualify-h9.py
```

Requirements: Python 3, PowerShell 7, Node.js with built-in WebSocket support, and installed Chrome or Edge. The runner builds the site, executes every repository `test-*.ps1`, compares every failure against `scripts/fixtures/h9/historical-guard-binding.json`, then runs the full actual-browser/HTTP qualification. It preserves each script's real exit code and raw output under a fresh ignored `receipts/h9-qualification-*/` directory. Any unexpected failure, stale mapping, missing current guard, browser failure or built-output mutation fails qualification.

The guard fixtures replace dependencies on ignored local review inventories. They retain original accepted hashes, explicit review-only exclusions and bounded migration provenance; text checks normalize only CRLF/LF while binary assets retain exact byte checks. No release-truth, artifact-integrity, download, product-page or frozen-shared-surface semantic assertion is waived. The existing-asset reconciliation check now distinguishes unchanged canonical assets from the exact seven approved new assets and checks each new asset's bytes.

The accepted review run remains 291/291 current and 1475/1493 overall. Portable source qualification counts differ because review-only files are excluded and new asset checks are added; they are reported from the actual staged run, without relabeling the 18 historical presentation failures as passes. See `scripts/fixtures/h9/README.md` for the exact count reconciliation.

For this landing, qualification is run against an isolated export of the actual Git index, with its own index and the canonical history. It cannot consume unstaged source, local preview files or excluded review packages. The exact staged-path manifest records modes, blob IDs, byte sizes and SHA-256 values under ignored local commit evidence. The commit tree must match that qualified staged tree exactly. Working-tree and staging state are checked again after the single local commit.
