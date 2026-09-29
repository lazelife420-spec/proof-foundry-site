# test-h11-public-truth.ps1 — H11 Public Truth Surface gates.
#
# Covers: output inventory, structural schema conformance, manifest consistency,
# route resolution, sanitization negative controls, drift control, determinism.
# Fixture builds use -ManifestPath/-OutDir/-TruthCommit overrides so the canonical
# manifest and public/ tree are never mutated by controls.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$publicDir = Join-Path $root 'public'
$script:passed = 0; $script:failed = 0
function Assert-Truth([bool]$cond, [string]$name) {
  if ($cond) { $script:passed++; Write-Host "PASS: $name" -ForegroundColor Green }
  else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red }
}

$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$schema = Get-Content (Join-Path $root 'schemas/public-truth-v1.schema.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$truthDir = Join-Path $publicDir 'truth'
$truthIndex = Get-Content (Join-Path $truthDir 'index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$truthFiles = Get-ChildItem (Join-Path $truthDir 'products') -Filter '*.json'

# ── Output inventory ──────────────────────────────────────────────────────────
Assert-Truth (Test-Path (Join-Path $truthDir 'index.json')) 'truth index exists at /truth/index.json'
Assert-Truth (Test-Path (Join-Path $truthDir 'schema-v1.json')) 'public schema exists at /truth/schema-v1.json'
Assert-Truth (Test-Path (Join-Path $truthDir 'index.html')) 'human truth page exists at /truth/index.html'
Assert-Truth (($schema.'$schema' -match 'json-schema') -and $schema.'$defs'.truthIndex -and $schema.'$defs'.productTruth) 'schema file is valid JSON Schema with index+product defs'

# ── Index consistency (Phase J) ───────────────────────────────────────────────
$visible = @($manifest.products | Where-Object { $_.visible })
Assert-Truth ($truthIndex.schemaVersion -eq 1) 'index: schemaVersion = 1'
Assert-Truth ($truthIndex.generatedFrom -eq 'site-manifest.json') 'index: generatedFrom is site-manifest.json'
Assert-Truth ($truthIndex.source.commit -match '^[0-9a-f]{40}$' -and $truthIndex.source.tree -match '^[0-9a-f]{40}$') 'index: source commit+tree are 40-hex git identities'
$indexRaw = [IO.File]::ReadAllText((Join-Path $truthDir 'index.json'))
Assert-Truth ($indexRaw -match '"committedAt":\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 'index: source committedAt is a stable commit timestamp (ISO-8601 string in JSON)'
Assert-Truth (-not $truthIndex.PSObject.Properties['generatedAt']) 'index: no wall-clock generatedAt field (determinism)'
Assert-Truth ($truthIndex.productCount -eq $visible.Count) 'index: productCount equals visible manifest products'
Assert-Truth ($truthIndex.products.Count -eq $visible.Count) 'index: product entries equal visible manifest products'

# Every manifest product has exactly one truth file; no extras
Assert-Truth ($truthFiles.Count -eq $visible.Count) 'exactly one truth file per manifest product'
foreach ($p in $visible) {
  Assert-Truth (Test-Path (Join-Path $truthDir "products/$($p.id).json")) "truth file exists for $($p.id)"
}
$truthIds = @($truthFiles | ForEach-Object { $_.BaseName })
$manifestIds = @($visible | ForEach-Object { $_.id })
Assert-Truth (-not @($truthIds | Where-Object { $_ -notin $manifestIds }).Count) 'no orphan truth files for removed/invisible products'

# Index entries reference real routes + truth files
foreach ($e in $truthIndex.products) {
  Assert-Truth (Test-Path (Join-Path $publicDir "$($e.id)/index.html")) "index entry $($e.id): product page exists at $($e.pageUrl)"
  Assert-Truth (Test-Path (Join-Path $truthDir "products/$($e.id).json")) "index entry $($e.id): truthUrl target exists"
  Assert-Truth ($e.pageUrl -ceq "/$($e.id)/" -and $e.truthUrl -ceq "/truth/products/$($e.id).json") "index entry $($e.id): urls follow canonical shape"
}

# ── Per-product truth vs manifest (Phase J) ───────────────────────────────────
foreach ($p in $visible) {
  $t = Get-Content (Join-Path $truthDir "products/$($p.id).json") -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Truth ($t.schemaVersion -eq 1 -and $t.id -ceq $p.id) "$($p.id): identity"
  Assert-Truth ($t.state -ceq $p.state -and $t.status -ceq $p.productStatus) "$($p.id): state/status match manifest"
  Assert-Truth ($t.version -ceq $p.release.publicVersion) "$($p.id): version matches release.publicVersion"
  Assert-Truth ($t.download.available -eq (-not [string]::IsNullOrWhiteSpace($p.downloadUrl))) "$($p.id): download.available matches manifest"
  if ($p.downloadUrl) {
    Assert-Truth ($t.download.url -ceq $p.downloadUrl -and $t.download.sha256 -ceq $p.sha256 -and $t.download.sha256Url -ceq $p.sha256Url) "$($p.id): download url/sha256/sha256Url match manifest"
  } else {
    Assert-Truth ($null -eq $t.download.url -and $t.download.available -eq $false) "$($p.id): no download url while unavailable"
  }
  Assert-Truth (@($t.artifacts).Count -eq @($p.artifacts).Count) "$($p.id): artifact count matches"
  for ($i = 0; $i -lt @($p.artifacts).Count; $i++) {
    $a = $p.artifacts[$i]; $ta = $t.artifacts[$i]
    Assert-Truth ($ta.filename -ceq $a.filename -and $ta.sha256 -ceq $a.sha256 -and $ta.downloadUrl -ceq $a.downloadUrl -and $ta.sha256Url -ceq $a.sha256Url) "$($p.id): artifact[$i] filename/sha256/urls match manifest"
  }
  $manProof = @($p.proofLinks); $trProof = @($t.proofLinks)
  Assert-Truth (($manProof.Count -eq $trProof.Count) -and (-not @(0..[Math]::Max(0,$manProof.Count-1) | Where-Object { $manProof[$_] -cne $trProof[$_] }).Count)) "$($p.id): proofLinks match manifest"
  $manEv = @($p.evidence | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.url } })
  $trEv = @($t.evidence | ForEach-Object { $_.url })
  Assert-Truth (($manEv.Count -eq $trEv.Count) -and (-not @(0..[Math]::Max(0,$manEv.Count-1) | Where-Object { $manEv[$_] -cne $trEv[$_] }).Count)) "$($p.id): evidence urls match manifest"
  $manTests = @($p.tests | ForEach-Object { "$($_.label)::$($_.result)" })
  $trTests = @($t.tests | ForEach-Object { "$($_.label)::$($_.result)" })
  Assert-Truth (($manTests.Count -eq $trTests.Count) -and (-not @(0..[Math]::Max(0,$manTests.Count-1) | Where-Object { $manTests[$_] -cne $trTests[$_] }).Count)) "$($p.id): tests match manifest"
  Assert-Truth ($t.source.commit -ceq $truthIndex.source.commit -and $t.source.tree -ceq $truthIndex.source.tree) "$($p.id): product source identity equals index identity"
  # Sanitization: presentation/internal fields must not leak into truth output
  foreach ($bad in @('summary','cardSummary','description','releaseNote','limits','cta','presentation','markSvg','cardImage','displayName','homeName','nav','navCta','visible','featured','lastVerified','build','proofStatus','testStatus','testCount','limits','currentLocalVersion')) {
    Assert-Truth (-not $t.PSObject.Properties[$bad]) "$($p.id): presentation/internal field '$bad' absent from truth"
  }
}

# ── Route gates (Phase K) ─────────────────────────────────────────────────────
Assert-Truth (Test-Path (Join-Path $publicDir 'truth/index.html')) 'route /truth/ resolves to built page'
Assert-Truth (Test-Path (Join-Path $publicDir 'truth/index.json')) 'route /truth/index.json resolves'
Assert-Truth (Test-Path (Join-Path $truthDir 'schema-v1.json')) 'route /truth/schema-v1.json resolves'
$redirects = [IO.File]::ReadAllText((Join-Path $publicDir '_redirects'))
Assert-Truth ($redirects -match '(?m)^/truth\s+/truth/\s+301' -and $redirects -match '(?m)^/truth\.html\s+/truth/\s+301') '_redirects covers /truth and /truth.html 301s'
$headers = [IO.File]::ReadAllText((Join-Path $publicDir '_headers'))
Assert-Truth ($headers -match '(?m)^/truth/\s*\r?\n\s+Cache-Control') '_headers carries /truth/ no-cache policy'
$sitemap = [IO.File]::ReadAllText((Join-Path $publicDir 'sitemap.xml'))
Assert-Truth ($sitemap -match 'https://theprooffoundry\.com/truth/') 'sitemap contains /truth/ (human page only — JSON endpoints excluded by design)'
Assert-Truth (-not ($sitemap -match 'truth/products/|truth/index\.json|schema-v1')) 'sitemap does not list raw JSON endpoints'

# Human page renders truth data, not literals
$truthHtml = [IO.File]::ReadAllText((Join-Path $publicDir 'truth/index.html'))
foreach ($p in $visible) {
  Assert-Truth ($truthHtml.Contains("/truth/products/$($p.id).json")) "truth page links to $($p.id) record"
}
Assert-Truth (-not ($truthHtml -match '\{\{')) 'truth page contains no unresolved tokens'

# ── H11-R1: worktreeDirty removed from public v1 ──────────────────────────────
$schemaRaw = [IO.File]::ReadAllText((Join-Path $root 'schemas/public-truth-v1.schema.json'))
Assert-Truth (-not $schemaRaw.Contains('worktreeDirty')) 'schema: worktreeDirty absent from public v1 schema'
Assert-Truth (-not $schemaRaw.Contains('"dirty"') -and -not $schemaRaw.Contains('workspaceStatus') -and -not $schemaRaw.Contains('"candidate"')) 'schema: no renamed local-state field snuck back in'
Assert-Truth (-not ([IO.File]::ReadAllText((Join-Path $truthDir 'index.json'))).Contains('worktreeDirty')) 'index: worktreeDirty absent'
foreach ($p in $visible) {
  Assert-Truth (-not ([IO.File]::ReadAllText((Join-Path $truthDir "products/$($p.id).json"))).Contains('worktreeDirty')) "$($p.id): worktreeDirty absent from truth output"
}
Assert-Truth ([bool]$truthIndex.source.commit -and [bool]$truthIndex.source.tree -and [bool]$truthIndex.source.committedAt) 'index: source identity = commit+tree+committedAt only'

# ── H11-R1: versioning policy + public discoverability ────────────────────────
Assert-Truth (Test-Path (Join-Path $root 'schemas/PUBLIC_TRUTH_VERSIONING.md')) 'versioning policy document exists (schemas/PUBLIC_TRUTH_VERSIONING.md)'
$pol = [IO.File]::ReadAllText((Join-Path $root 'schemas/PUBLIC_TRUTH_VERSIONING.md'))
Assert-Truth ($pol -match 'schemaVersion' -and $pol -match 'LOCAL PREVIEW' -and $pol -match 'PUBLISHED PUBLIC TRUTH') 'versioning policy defines breaking-change rule + preview/published distinction'
Assert-Truth ($truthHtml -match 'id="versioning"' -and $truthHtml -match 'schemaVersion') 'truth page carries contract-versioning section at /truth/#versioning'
Assert-Truth ($truthIndex.schemaVersion -eq 1 -and $truthIndex.schemaUrl -eq '/truth/schema-v1.json') 'index: schemaVersion=1 and schema-v1 path'

# ── H11-R1: sitemap truth — changed routes bumped, untouched routes keep HEAD ─
$lastmodByLoc = @{}
foreach ($mm in [regex]::Matches($sitemap, '<loc>([^<]+)</loc>\s*<lastmod>([^<]+)</lastmod>')) { $lastmodByLoc[$mm.Groups[1].Value] = $mm.Groups[2].Value }
$headSitemap = (git -C $root show 'HEAD:sitemap.xml') -join "`n"
$headLastmod = @{}
foreach ($mm in [regex]::Matches($headSitemap, '<loc>([^<]+)</loc>\s*<lastmod>([^<]+)</lastmod>')) { $headLastmod[$mm.Groups[1].Value] = $mm.Groups[2].Value }
Assert-Truth ($lastmodByLoc['https://theprooffoundry.com/truth/'] -eq '2026-09-20') 'sitemap: /truth/ carries H11 date (new route)'
Assert-Truth ($lastmodByLoc['https://theprooffoundry.com/proof-standard/'] -eq '2026-09-20') 'sitemap: /proof-standard/ carries H11 date (H11 changed the page)'
foreach ($kv in $headLastmod.GetEnumerator()) {
  if ($kv.Key -eq 'https://theprooffoundry.com/proof-standard/') { continue }
  if ($kv.Key -eq 'https://theprooffoundry.com/') {
    Assert-Truth ($lastmodByLoc[$kv.Key] -eq '2026-09-28') 'sitemap: homepage lastmod reflects this homepage tranche'
    continue
  }
  Assert-Truth ($lastmodByLoc[$kv.Key] -eq $kv.Value) "sitemap: $($kv.Key) retains HEAD lastmod ($($kv.Value)) — H11 did not change it"
}

# ── Sanitization negative controls (Phase L) — disposable fixture builds ──────
$tmp = Join-Path $env:TEMP ("pf-h11-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path "$tmp\public" | Out-Null
Copy-Item (Join-Path $root 'site-manifest.json') "$tmp\manifest.json"
$tCommit = 'a' * 40; $tTree = 'b' * 40; $tAt = '2026-09-20T00:00:00+00:00'
$buildScript = Join-Path $root 'scripts/build-site.ps1'

# Inject internal/private-shaped fields into a fixture manifest
$fm = Get-Content "$tmp\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$fm.products[0] | Add-Member -NotePropertyName internalNotes -NotePropertyValue 'operator-only note' -Force
$fm.products[0] | Add-Member -NotePropertyName localPath -NotePropertyValue 'C:\Users\KickA\secret\thing' -Force
$fm.products[0].release | Add-Member -NotePropertyName internalBranch -NotePropertyValue 'dev/experimental' -Force
$fm.products[0].artifacts[0] | Add-Member -NotePropertyName buildToken -NotePropertyValue 'Bearer abc123def456' -Force
$fmJson = $fm | ConvertTo-Json -Depth 30
[IO.File]::WriteAllText("$tmp\manifest.json", $fmJson)

& pwsh -NoProfile -File $buildScript -ManifestPath "$tmp\manifest.json" -OutDir "$tmp\public" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\build.log"
$prodTruth = Get-Content "$tmp\public\truth\products\reality-gate.json" -Raw
Assert-Truth (-not $prodTruth.Contains('internalNotes')) 'negative: internalNotes field absent from truth output'
Assert-Truth (-not $prodTruth.Contains('C:\Users\KickA')) 'negative: local Windows path absent from truth output'
Assert-Truth (-not $prodTruth.Contains('internalBranch')) 'negative: internal release field absent from truth output'
Assert-Truth (-not $prodTruth.Contains('abc123def456')) 'negative: credential-like value absent from truth output'
Assert-Truth ($LASTEXITCODE -eq 0) 'fixture build with injected private fields still completes (exclusion, not crash)'

# Sanitization on values that DO pass through the allowlist — a canonical field
# carrying an unsafe value must still be refused by the safety scan.
$fm2 = Get-Content "$tmp\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$fm2.products[0].downloadUrl = 'file:///C:/Users/KickA/evil.zip'
$fm2.products[0].artifacts[0].downloadUrl = 'file:///C:/Users/KickA/evil.zip'
[IO.File]::WriteAllText("$tmp\manifest2.json", ($fm2 | ConvertTo-Json -Depth 30))
& pwsh -NoProfile -File $buildScript -ManifestPath "$tmp\manifest2.json" -OutDir "$tmp\public2" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\build2.log"
$blocked = ((Get-Content "$tmp\build2.log" -Raw) -match 'Manifest validation failed|Refusing to emit|hardcodes|malformed|unsafe')
Assert-Truth ($LASTEXITCODE -ne 0 -or $blocked) 'negative: file:// downloadUrl in a canonical field is refused by validation or the truth safety scan'

# ── Drift negative control (Phase M) ──────────────────────────────────────────
# Coherent drift: bump the withdrawn historical version and its embedded copies
# while keeping current publicVersion null and downloads unavailable.
$fm3 = Get-Content "$tmp\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$fm3.products[0].release.withdrawnVersion = '9.9.9'
$fm3.products[0].artifacts[0].sha256 = '0' * 64
$fm3.products[0].sha256 = '0' * 64
[IO.File]::WriteAllText("$tmp\manifest3.json", (($fm3 | ConvertTo-Json -Depth 30) -replace '1\.1\.0', '9.9.9'))
& pwsh -NoProfile -File $buildScript -ManifestPath "$tmp\manifest3.json" -OutDir "$tmp\public3" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\build3.log"
$drifted = Get-Content "$tmp\public3\truth\products\reality-gate.json" -Raw | ConvertFrom-Json
Assert-Truth ($drifted.version -eq $null -and $drifted.release.publicVersion -eq $null -and $drifted.release.withdrawnVersion -ceq '9.9.9' -and $drifted.release.releaseStatus -ceq 'WITHDRAWN') 'drift: withdrawn version flows into truth without becoming current'
Assert-Truth ($drifted.artifacts[0].sha256 -ceq ('0' * 64)) 'drift: artifact checksum change flows into truth output automatically'

# ── Determinism control (Phase N) — same inputs, two builds, identical bytes ──
& pwsh -NoProfile -File $buildScript -ManifestPath "$tmp\manifest.json" -OutDir "$tmp\det1" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\det1.log"
& pwsh -NoProfile -File $buildScript -ManifestPath "$tmp\manifest.json" -OutDir "$tmp\det2" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\det2.log"
$detMatch = $true
foreach ($f in (Get-ChildItem "$tmp\det1\truth" -Recurse -File)) {
  $rel = $f.FullName.Substring("$tmp\det1\truth".Length)
  $other = Join-Path "$tmp\det2\truth" $rel
  if (-not (Test-Path $other) -or (Get-FileHash $f.FullName).Hash -cne (Get-FileHash $other).Hash) { $detMatch = $false }
}
Assert-Truth $detMatch 'determinism: two builds of identical input produce byte-identical truth outputs'

# Canonical public/ truth also deterministic: rebuild canonical output and
# compare truth bytes to the pre-test build.
$preHash = (Get-FileHash (Join-Path $truthDir 'index.json')).Hash
& pwsh -NoProfile -File (Join-Path $root 'scripts/build-site.ps1') *> "$tmp\canon.log"
$postHash = (Get-FileHash (Join-Path $truthDir 'index.json')).Hash
Assert-Truth ($preHash -ceq $postHash) 'determinism: canonical rebuild produces identical truth bytes'

# ── H11-R1: untracked non-source material cannot alter public source identity ──
# (owner-review defect: worktreeDirty fired on any untracked file; with the field
# removed, identity must remain commit/tree/committedAt regardless of scratch files)
$scratch = Join-Path $root 'h11-scratch-untracked.tmp'
[IO.File]::WriteAllText($scratch, 'untracked scratch — must not affect truth identity')
try {
  & pwsh -NoProfile -File (Join-Path $root 'scripts/build-site.ps1') *> "$tmp\scratch.log"
  $scratchIndex = [IO.File]::ReadAllText((Join-Path $truthDir 'index.json'))
  $scratchObj = $scratchIndex | ConvertFrom-Json
  Assert-Truth ($scratchObj.source.commit -ceq $truthIndex.source.commit -and $scratchObj.source.tree -ceq $truthIndex.source.tree -and $scratchObj.source.committedAt -ceq $truthIndex.source.committedAt) 'source identity: untracked scratch file does not alter commit/tree/committedAt'
  Assert-Truth (-not $scratchIndex.Contains('worktreeDirty') -and -not $scratchIndex.Contains('scratch')) 'source identity: untracked material absent from truth output'
} finally {
  Remove-Item $scratch -Force -ErrorAction SilentlyContinue
}

# ── H11-R1: deploy preflight — tracked-dirty can NEVER publish ────────────────
# Disposable committed repo containing the candidate deploy.ps1. Assert that
# tracked changes (staged AND unstaged) are blocked even with -AllowDirtyDeploy,
# while untracked-only material passes the preflight under the flag. Wrangler is
# never reached on the negative path; on the untracked path the guard is proven
# by the warning line, then the script may fail later — that is out of scope.
$drepo = Join-Path $tmp 'deployrepo'
New-Item -ItemType Directory -Force -Path $drepo | Out-Null
foreach ($p in @('deploy.ps1','scripts\build-site.ps1','site-manifest.json','schemas')) {
  $dest = Join-Path $drepo $p
  if ((Get-Item (Join-Path $root $p)).PSIsContainer) { robocopy (Join-Path $root $p) $dest /E /NFL /NDL /NJH /NJS /NP | Out-Null }
  else { New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null; Copy-Item (Join-Path $root $p) $dest }
}
Push-Location $drepo
try {
  git init -q 2>$null; git add -A 2>$null; git -c user.email=t@t -c user.name=t commit -qm base 2>$null | Out-Null
  # Control A: tracked unstaged mutation — deploy must fail even with the flag
  Add-Content 'site-manifest.json' "`n" -NoNewline
  & pwsh -NoProfile -File '.\deploy.ps1' -AllowDirtyDeploy *> "$tmp\dep-a.log"
  $logA = Get-Content "$tmp\dep-a.log" -Raw
  Assert-Truth ($LASTEXITCODE -eq 1 -and $logA -match 'tracked source is not clean') 'deploy guard: tracked unstaged change blocked even with -AllowDirtyDeploy'
  git checkout -- 'site-manifest.json' 2>$null
  # Control B: staged tracked mutation — same block
  Add-Content 'site-manifest.json' "`n" -NoNewline; git add 'site-manifest.json' 2>$null
  & pwsh -NoProfile -File '.\deploy.ps1' -AllowDirtyDeploy *> "$tmp\dep-b.log"
  $logB = Get-Content "$tmp\dep-b.log" -Raw
  Assert-Truth ($LASTEXITCODE -eq 1 -and $logB -match 'tracked source is not clean') 'deploy guard: staged tracked change blocked even with -AllowDirtyDeploy'
  git reset -q --hard 2>$null
  # Control C: untracked-only — preflight passes under the flag (build proceeds;
  # later wrangler step may fail for creds — irrelevant to the guard).
  # NB: absolute path — .NET file APIs ignore Push-Location.
  [IO.File]::WriteAllText((Join-Path $drepo 'review-note.tmp'), 'custody evidence')
  & pwsh -NoProfile -File '.\deploy.ps1' -AllowDirtyDeploy *> "$tmp\dep-c.log"
  $logC = Get-Content "$tmp\dep-c.log" -Raw
  Assert-Truth ($logC -match 'WARNING: -AllowDirtyDeploy set' -and $logC -match 'Building public/') 'deploy guard: untracked-only material passes preflight under -AllowDirtyDeploy'
  # Control D: untracked-only without the flag still blocks (conservative default)
  & pwsh -NoProfile -File '.\deploy.ps1' *> "$tmp\dep-d.log"
  $logD = Get-Content "$tmp\dep-d.log" -Raw
  Assert-Truth ($LASTEXITCODE -eq 1 -and $logD -match 'untracked files present') 'deploy guard: untracked-only still requires -AllowDirtyDeploy (conservative default)'
} finally {
  Pop-Location
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== H11 PUBLIC TRUTH RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
