. "$PSScriptRoot/release-qualification.ps1"
# test-receipts-invariants.ps1 — invariant tests for the canonical Receipts pipeline.
#
# Every test runs the real build against a FIXTURE manifest written to a temp
# directory and renders into a temp output directory. The canonical
# site-manifest.json and public/ tree are never written to, so a failed or
# interrupted run cannot damage canonical data.
#
# Proves:
#   1. derivation      - changing canonical data changes generated output
#   2. resolver newest - latest verification = max date across visible products
#   3. malformed date  - rejected by validation, build fails
#   4. missing data    - cannot render a "Latest" claim
#   5. tie determinism - equal timestamps resolve identically across runs
#   6. registry cover  - every visible product appears in the registry
#   7. links           - no broken internal links in generated output
#   8. receipt         - site verification receipt exists and is self-consistent
#   9. determinism     - byte-identical registry across builds
#  10. digest case     - canonical SHA-256 must be lowercase 64-hex
#  11. template purity - canonical digests cannot be hardcoded into templates
#  12. tracked evidence- public receipt must be tracked by git, not merely on disk
#  13. token integrity - a dangling artifact token fails instead of rendering blank
$ErrorActionPreference = 'Stop'

$root      = (Resolve-Path "$PSScriptRoot/..").Path
$buildPs1  = Join-Path $root 'scripts\build-qualification-fixture.ps1'
$canonical = Join-Path $root 'site-manifest.json'
$work      = Join-Path ([IO.Path]::GetTempPath()) ("pf-invariants-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

$canonicalSha = (Get-FileHash $canonical -Algorithm SHA256).Hash.ToLower()
$pass = 0; $fail = 0
function Assert($name, [bool]$ok, $detail = '') {
  if ($ok) { $script:pass++; Write-Host "PASS: $name" -ForegroundColor Green }
  else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red; if ($detail) { Write-Host "      $detail" -ForegroundColor Red } }
}

# Build against a fixture. Returns @{ Exit; Output; ProofHtml; Registry; OutDir }
function Invoke-FixtureBuild([string]$name, [scriptblock]$mutate, [switch]$ValidateOnly, [scriptblock]$mutateModules) {
  $fixDir = Join-Path $work $name
  New-Item -ItemType Directory -Force -Path $fixDir | Out-Null
  $fixManifest = Join-Path $fixDir 'site-manifest.json'
  $outDir = Join-Path $fixDir 'out'

  $obj = Get-AuthoredReleaseManifest
  if ($mutate) { $obj = & $mutate $obj }
  $json = $obj | ConvertTo-Json -Depth 12
  [IO.File]::WriteAllText($fixManifest, $json, (New-Object System.Text.UTF8Encoding $false))

  $valOpt = if ($ValidateOnly) { ' -ValidateOnly' } else { '' }
  $productsOpt = ''
  if ($mutateModules) {
    $fixtureProducts = Join-Path $fixDir 'products'
    Copy-Item (Join-Path $root 'products') $fixtureProducts -Recurse
    & $mutateModules $fixtureProducts
    $productsOpt = " -ProductsDir `"$fixtureProducts`""
  }
  $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Process -Id $PID).Path }
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $psExe
  $pinfo.Arguments = "-NoProfile -File `"$buildPs1`" -ManifestPath `"$fixManifest`" -OutDir `"$outDir`"$valOpt$productsOpt"
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($pinfo)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  $code = $p.ExitCode
  $out = ($stdout + "`n" + $stderr).Trim()

  $proofHtml = $null; $registry = $null
  $ph = Join-Path $outDir 'proof\index.html'
  $rj = Join-Path $outDir 'proof\index.json'
  if (Test-Path $ph) { $proofHtml = [IO.File]::ReadAllText($ph) }
  if (Test-Path $rj) { $registry = Get-Content $rj -Raw -Encoding UTF8 | ConvertFrom-Json }
  return @{ Exit = $code; Output = ($out -join "`n"); ProofHtml = $proofHtml; Registry = $registry; OutDir = $outDir }
}

Write-Host "=== fixture workspace: $work ===" -ForegroundColor Cyan
Write-Host ""

# ── TEST 1: derivation ───────────────────────────────────────────────────────
# Change a canonical version to a sentinel; the generated pages and registry must
# follow. If any surface kept a hardcoded literal, the sentinel would be absent.
Write-Host "--- TEST 1: generated output derives from canonical data ---"
# The fixture models a coherent withdrawn-history correction: current release
# availability stays withdrawn while the historic version label is changed.
$t1 = Invoke-FixtureBuild 'derive' {
  param($o)
  $rg = $o.products | Where-Object { $_.id -eq 'reality-gate' }
  $rg.release.withdrawnVersion = '9.9.9'
  $rg.downloadLabel = $null
  $bump = { param($s) if ($s) { $s -replace '1\.1\.0', '9.9.9' } else { $s } }
  foreach ($a in $rg.artifacts) {
    $a.filename    = & $bump $a.filename
  }
  $rg.build = & $bump $rg.build
  $rg.releaseNote = & $bump $rg.releaseNote
  $rg.release.withdrawalReason = & $bump $rg.release.withdrawalReason
  $rg.presentation.downloadNotice = & $bump $rg.presentation.downloadNotice
  $rg.limits = @($rg.limits | ForEach-Object { & $bump $_ })
  $o
}
Assert 'build succeeds with sentinel version' ($t1.Exit -eq 0) $t1.Output
if ($t1.Exit -eq 0) {
  Assert 'proof page shows sentinel v9.9.9'        ($t1.ProofHtml -match 'v9\.9\.9')
  Assert 'proof page no longer shows old v1.1.0'   ($t1.ProofHtml -notmatch 'v1\.1\.0')
  $rgEntry = $t1.Registry.products | Where-Object { $_.id -eq 'reality-gate' }
  Assert 'registry shows sentinel withdrawn version' ($rgEntry.release.withdrawnVersion -eq '9.9.9' -and $null -eq $rgEntry.release.publicVersion) "got '$($rgEntry.release.withdrawnVersion)'"
  $homeHtml = [IO.File]::ReadAllText((Join-Path $t1.OutDir 'index.html'))
  Assert 'homepage does not present a withdrawn historical version as current availability' ($homeHtml -notmatch 'v9\.9\.9' -and $homeHtml -notmatch 'v1\.1\.0')
  $prodHtml = [IO.File]::ReadAllText((Join-Path $t1.OutDir 'reality-gate\index.html'))
  Assert 'product page shows sentinel v9.9.9'      ($prodHtml -match 'v9\.9\.9')
}
Write-Host ""

# ── TEST 2: resolver picks the newest valid record ───────────────────────────
Write-Host "--- TEST 2: latest-verification resolver selects the newest date ---"
$t2 = Invoke-FixtureBuild 'newest' {
  param($o)
  ($o.products | Where-Object { $_.id -eq 'cleanroom' }).verification.verifiedAt = '2026-12-31'
  $o
}
Assert 'build succeeds' ($t2.Exit -eq 0) $t2.Output
if ($t2.Exit -eq 0) {
  Assert 'resolver selects the newest date 2026-12-31' ($t2.ProofHtml -match '2026-12-31')
  Assert 'resolver names the product holding it'       ($t2.ProofHtml -match 'Cleanroom')
}
Write-Host ""

# ── TEST 3: malformed timestamp is rejected ─────────────────────────────────
Write-Host "--- TEST 3: malformed verifiedAt is rejected by validation ---"
$t3 = Invoke-FixtureBuild 'malformed' {
  param($o)
  ($o.products | Where-Object { $_.id -eq 'cache-vault' }).verification.verifiedAt = 'Aug-28-2026'
  $o
} -ValidateOnly
Assert 'build exits non-zero'                      ($t3.Exit -ne 0) "exit=$($t3.Exit)"
Assert 'error names the malformed field'           ($t3.Output -match 'malformed verification\.verifiedAt') $t3.Output
Assert 'error names the offending product'         ($t3.Output -match '\[cache-vault\]')
Write-Host ""

# ── TEST 4: missing data cannot render a "Latest" claim ─────────────────────
Write-Host "--- TEST 4: unprovable data cannot render a Latest claim ---"
$t4 = Invoke-FixtureBuild 'nodate' {
  param($o)
  foreach ($p in $o.products) {
    if ($p.verification) { $p.verification.verifiedAt = $null; $p.verification.status = 'PENDING' }
    if ($p.release) { $p.release.publishedAt = $null }
    if ($p.PSObject.Properties.Name -contains 'lastVerified') { $p.lastVerified = $null }
  }
  $o
} -mutateModules {
  param($productsDir)
  # Unverified records cannot remain production-eligible under the current
  # publication gate. Keep the presentation in the preview lifecycle so this
  # fixture can exercise the site's no-date fallback without public emission.
  Get-ChildItem -LiteralPath $productsDir -Filter 'module.json' -File -Recurse | ForEach-Object {
    $module = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    $module.lifecycle = 'preview'; $module.visibility = 'hidden'
    [IO.File]::WriteAllText($_.FullName, ($module | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
  }
}
Assert 'build succeeds with no dates' ($t4.Exit -eq 0) $t4.Output
if ($t4.Exit -eq 0) {
  Assert 'renders the explicit no-verification fallback' ($t4.ProofHtml -match 'No verified site verification event')
  Assert 'does not claim a Latest verification event'    ($t4.ProofHtml -notmatch 'Latest verification event:')
}
Write-Host ""

# ── TEST 5: tie determinism ─────────────────────────────────────────────────
# Two products share the same maximum date. The documented rule is that the first
# match in manifest order wins (the resolver uses a strict -gt comparison), so the
# result must be identical across repeated builds.
Write-Host "--- TEST 5: equal timestamps resolve deterministically ---"
$tieMutate = {
  param($o)
  # The previous 2026-09-09 fixture ceased to be the maximum after later releases.
  # Make every non-target event earlier so the test truly exercises a tie.
  foreach ($p in $o.products) {
    if ($p.verification.verifiedAt) { $p.verification.verifiedAt = '2026-01-01' }
    if ($p.release.publishedAt) { $p.release.publishedAt = '2026-01-01' }
    if ($p.lastVerified) { $p.lastVerified = '2026-01-01' }
  }
  ($o.products | Where-Object { $_.id -eq 'cache-vault' }).verification.verifiedAt = '2026-12-30'
  ($o.products | Where-Object { $_.id -eq 'ghostlayer' }).verification.verifiedAt = '2026-12-30'
  $o
}
$r1 = Invoke-FixtureBuild 'tie1' $tieMutate
$r2 = Invoke-FixtureBuild 'tie2' $tieMutate
Assert 'both tie builds succeed' (($r1.Exit -eq 0) -and ($r2.Exit -eq 0)) "$($r1.Exit)/$($r2.Exit)"
if (($r1.Exit -eq 0) -and ($r2.Exit -eq 0)) {
  $m1 = [regex]::Match($r1.ProofHtml, 'Latest verification event:\s*<strong>(.*?)</strong>')
  $m2 = [regex]::Match($r2.ProofHtml, 'Latest verification event:\s*<strong>(.*?)</strong>')
  Assert 'tie resolves to a named product'   ($m1.Success -and $m2.Success)
  Assert 'tie resolves identically each run' ($m1.Groups[1].Value -eq $m2.Groups[1].Value) "run1='$($m1.Groups[1].Value)' run2='$($m2.Groups[1].Value)'"
  Assert 'tie winner is first in manifest order (cache-vault)' ($m1.Groups[1].Value -match 'Cache Vault') "got '$($m1.Groups[1].Value)'"
  Assert 'tie date is the shared maximum'    ($r1.ProofHtml -match 'Latest verification event:.*?<time datetime="2026-12-30">')
}
Write-Host ""

# ── TEST 6: registry coverage of every visible product ──────────────────────
Write-Host "--- TEST 6: registry covers every visible product ---"
$t6 = Invoke-FixtureBuild 'coverage' { param($o) $o }
Assert 'build succeeds' ($t6.Exit -eq 0) $t6.Output
if ($t6.Exit -eq 0) {
  $canonicalObj = Get-Content $canonical -Raw -Encoding UTF8 | ConvertFrom-Json
  $visible = @($canonicalObj.products | Where-Object { $_.visible } | ForEach-Object { $_.id })
  $inReg   = @($t6.Registry.products | ForEach-Object { $_.id })
  $missing = @($visible | Where-Object { $_ -notin $inReg })
  Assert "every visible product is in the registry ($($visible.Count))" ($missing.Count -eq 0) "missing: $($missing -join ', ')"
  Assert 'registry productCount matches record count' ($t6.Registry.productCount -eq $inReg.Count)
  Assert 'ghostlayer is present'                      ('ghostlayer' -in $inReg)
  # Every registry hash must be 64 hex chars, case-insensitively valid.
  $badSha = @()
  foreach ($p in $t6.Registry.products) {
    foreach ($a in $p.artifacts) {
      if ($a.sha256 -and $a.sha256 -notmatch '^(?i)[0-9a-f]{64}$') { $badSha += "$($p.id)/$($a.filename)" }
    }
  }
  Assert 'every registry sha256 is 64 hex chars' ($badSha.Count -eq 0) "bad: $($badSha -join ', ')"
}
Write-Host ""

# ── TEST 7: every internal link in generated output resolves ────────────────
Write-Host "--- TEST 7: generated internal links resolve to real output ---"
$t7 = Invoke-FixtureBuild 'links' { param($o) $o }
Assert 'build succeeds' ($t7.Exit -eq 0) $t7.Output
if ($t7.Exit -eq 0) {
  $brokenLinks = @()
  foreach ($f in (Get-ChildItem $t7.OutDir -Recurse -Filter *.html)) {
    $c = [IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($c, 'href="(/[^"#?]*)"')) {
      $href = $m.Groups[1].Value
      $p = Join-Path $t7.OutDir ($href.TrimStart('/') -replace '/', [IO.Path]::DirectorySeparatorChar)
      if (-not ((Test-Path $p) -or (Test-Path (Join-Path $p 'index.html')))) {
        $brokenLinks += "$($f.Name) -> $href"
      }
    }
  }
  Assert 'no broken internal links in generated output' ($brokenLinks.Count -eq 0) ($brokenLinks | Select-Object -First 8 | Out-String)
}
Write-Host ""

# ── TEST 8: site verification receipt must exist and be self-consistent ─────
Write-Host "--- TEST 8: site verification receipt invariants ---"
$t8a = Invoke-FixtureBuild 'receipt-missing' {
  param($o)
  $o.siteVerification.receiptPath = '/reports/deploy-receipts/2099-01-01-proof-foundry-site.md'
  $o.siteVerification.receiptDate = '2099-01-01'
  $o
} -ValidateOnly
Assert 'missing receipt file fails the build'  ($t8a.Exit -ne 0) "exit=$($t8a.Exit)"
Assert 'error names the missing receipt path'  ($t8a.Output -match 'receiptPath does not exist')

$t8b = Invoke-FixtureBuild 'receipt-mismatch' {
  param($o)
  $o.siteVerification.receiptDate = '2026-08-27'
  $o
} -ValidateOnly
Assert 'receiptDate/receiptPath mismatch fails' ($t8b.Exit -ne 0) "exit=$($t8b.Exit)"
Assert 'error explains the mismatch'            ($t8b.Output -match 'does not match receiptPath')
Write-Host ""

# ── TEST 9: registry output is deterministic ────────────────────────────────
# Same manifest in, byte-identical registry out (apart from generatedAt). Guards
# against unordered hashtables reappearing and making the registry undiffable.
Write-Host "--- TEST 9: proof registry is byte-deterministic ---"
$d1 = Invoke-FixtureBuild 'det1' { param($o) $o }
$d2 = Invoke-FixtureBuild 'det2' { param($o) $o }
Assert 'both determinism builds succeed' (($d1.Exit -eq 0) -and ($d2.Exit -eq 0)) "$($d1.Exit)/$($d2.Exit)"
if (($d1.Exit -eq 0) -and ($d2.Exit -eq 0)) {
  $j1 = [IO.File]::ReadAllText((Join-Path $d1.OutDir 'proof\index.json')) -replace '"generatedAt"\s*:\s*"[^"]*"', 'GEN'
  $j2 = [IO.File]::ReadAllText((Join-Path $d2.OutDir 'proof\index.json')) -replace '"generatedAt"\s*:\s*"[^"]*"', 'GEN'
  Assert 'registry identical across builds (ignoring generatedAt)' ($j1 -eq $j2)
  $keys = ($d1.Registry.products[0].PSObject.Properties.Name) -join ','
  Assert 'product key order is the declared canonical order' ($keys -eq 'id,name,displayName,productStatus,release,platform,route,artifacts,verification,tests,evidence,limits,summary') "got: $keys"
  $b = [IO.File]::ReadAllBytes((Join-Path $d1.OutDir 'proof\index.json'))
  Assert 'registry has no UTF-8 BOM' (-not (($b[0] -eq 239) -and ($b[1] -eq 187) -and ($b[2] -eq 191)))
}
Write-Host ""

# ── TEST 10: canonical digests must be lowercase 64-hex ─────────────────────
# Hex is case-insensitive as a value, so uppercase is the *same* digest — which is
# exactly why nothing caught it before. It still breaks string comparison against
# sha256sum / Get-FileHash output and against the JSON registry.
Write-Host "--- TEST 10: canonical SHA-256 representation is lowercase-only ---"
$t10a = Invoke-FixtureBuild 'sha-upper-artifact' {
  param($o)
  $rg = $o.products | Where-Object { $_.id -eq 'reality-gate' }
  $rg.artifacts[0].sha256 = $rg.artifacts[0].sha256.ToUpperInvariant()
  $o
} -ValidateOnly
Assert 'uppercase artifact digest fails the build'   ($t10a.Exit -ne 0) "exit=$($t10a.Exit)"
Assert 'error says lowercase is canonical'           ($t10a.Output -match 'must be lowercase hex')

$t10b = Invoke-FixtureBuild 'sha-upper-display' {
  param($o)
  $rg = $o.products | Where-Object { $_.id -eq 'reality-gate' }
  $rg.sha256 = $rg.sha256.ToUpperInvariant()
  $o
} -ValidateOnly
Assert 'uppercase display-node digest fails the build' ($t10b.Exit -ne 0) "exit=$($t10b.Exit)"
Assert 'display-node error also names lowercase rule'  ($t10b.Output -match 'must be lowercase hex')

$t10c = Invoke-FixtureBuild 'sha-truncated' {
  param($o)
  $rg = $o.products | Where-Object { $_.id -eq 'reality-gate' }
  $rg.artifacts[0].sha256 = 'deadbeef'
  $o
} -ValidateOnly
Assert 'malformed-length digest still fails'         ($t10c.Exit -ne 0) "exit=$($t10c.Exit)"
Assert 'length error is distinct from case error'    ($t10c.Output -match '64 hex chars')
Write-Host ""

# ── TEST 11: live templates must not hardcode canonical digests ─────────────
# The rule is "a literal equal to a canonical digest", so it needs no filename or
# hash allowlist. This fixture declares an artifact digest equal to a hash that
# genuinely appears in a real template as an illustrative example — which is
# exactly the collision the rule must catch.
Write-Host "--- TEST 11: canonical digests cannot be hardcoded in templates ---"
$illustrative = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$t11 = Invoke-FixtureBuild 'template-literal' {
  param($o)
  $rg = $o.products | Where-Object { $_.id -eq 'reality-gate' }
  $rg.artifacts[0].sha256 = $illustrative
  $rg.sha256 = $illustrative
  $o
} -ValidateOnly
Assert 'digest duplicated into a template fails the build' ($t11.Exit -ne 0) "exit=$($t11.Exit)"
Assert 'error names the offending template'                ($t11.Output -match '\[template\] products/reality-gate/content\.html')
Assert 'error prescribes the artifact-indexed token'       ($t11.Output -match '\{\{product\.artifacts\.\d+\.sha256\}\}')
Assert 'canonical data itself produces no template errors' ($d1.Output -notmatch '\[template\]')
Write-Host ""

# ── TEST 12: public evidence must be tracked by git, not just present ───────
# A receipt that exists only on the machine that built the site would 404 in a
# fresh clone. Filesystem presence is therefore not a sufficient check.
Write-Host "--- TEST 12: site verification receipt must be git-tracked ---"
$tmpDir  = Join-Path $root '.snapshots\invariant-tmp'
$tmpName = 'untracked-receipt-2026-01-02.md'
try {
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $tmpDir $tmpName), "# untracked probe receipt`n")
  $t12 = Invoke-FixtureBuild 'receipt-untracked' {
    param($o)
    $o.siteVerification.receiptPath = "/.snapshots/invariant-tmp/$tmpName"
    $o.siteVerification.receiptDate = '2026-01-02'
    $o
  } -ValidateOnly
  Assert 'receipt present but untracked fails the build' ($t12.Exit -ne 0) "exit=$($t12.Exit)"
  Assert 'error states it is not tracked by git'         ($t12.Output -match 'NOT tracked by git')
  Assert 'error gives the exact remedy command'          ($t12.Output -match 'git add ')
} finally {
  Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
Assert 'canonical receipt passes the tracked check' ($d1.Exit -eq 0) "canonical build exit=$($d1.Exit)"
Write-Host ""

# ── TEST 13: an unresolved product token is a failure, not a blank ──────────
# Templates address artifacts by index. If the manifest later declares fewer
# artifacts, the reference dangles — and silently rendering an empty checksum
# block would be the worst outcome, because the build would still report success.
Write-Host "--- TEST 13: dangling artifact token fails instead of erasing evidence ---"
$t13 = Invoke-FixtureBuild 'dangling-token' {
  param($o)
  $lo = $o.products | Where-Object { $_.id -eq 'lights-out' }
  $lo.artifacts = @($lo.artifacts[0])
  $o
}
Assert 'dropping a referenced artifact fails the build' ($t13.Exit -ne 0) "exit=$($t13.Exit)"
Assert 'error names the unresolved token'               ($t13.Output -match 'Unresolved product token')
Assert 'error lists the artifact token that dangled'    ($t13.Output -match 'artifacts\.1\.sha256')
if ($t13.Exit -ne 0) {
  $loOut = Join-Path $t13.OutDir 'lights-out\index.html'
  $rendered = if (Test-Path $loOut) { [IO.File]::ReadAllText($loOut) } else { '' }
  Assert 'no page was published with an empty checksum block' ($rendered -notmatch '<div class="code-block">\s*</div>')
}
Write-Host ""

# ── canonical data untouched ─────────────────────────────────────────────────
$afterSha = (Get-FileHash $canonical -Algorithm SHA256).Hash.ToLower()
Assert 'canonical site-manifest.json byte-identical after all tests' ($afterSha -eq $canonicalSha) "before=$canonicalSha after=$afterSha"

Write-Host ""
Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { exit 1 }
exit 0
