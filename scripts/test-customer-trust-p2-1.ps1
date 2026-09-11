# PowerShell script for testing P2-1 Customer Trust Support + Checksum Invariants
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== P2-1 CUSTOMER TRUST SUPPORT & CHECKSUM INVARIANTS TEST SUITE ===" -ForegroundColor Cyan

$publicDir = Join-Path $PSScriptRoot "..\public"
$manifestPath = Join-Path $PSScriptRoot "..\site-manifest.json"

$passed = 0
$failed = 0

function Assert-Condition($condition, $msg) {
    if ($condition) {
        Write-Host "PASS: $msg" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "FAIL: $msg" -ForegroundColor Red
        $script:failed++
    }
}

# 1. Route Generation
$supportPath = Join-Path $publicDir "support\index.html"
Assert-Condition (Test-Path $supportPath) "Generated /support/index.html route exists"

$supportHtml = Get-Content $supportPath -Raw -Encoding UTF8

# 2. Header & Footer Navigation
$homeHtml = Get-Content (Join-Path $publicDir "index.html") -Raw -Encoding UTF8
Assert-Condition ($homeHtml -match '<a href="/support/"') "Header nav contains link to /support/"
Assert-Condition ($homeHtml -match '<li><a href="/support/">Support</a></li>') "Footer nav contains link to /support/"

# 3. Product Support Signposts (All 7 Products)
$products = @('reality-gate', 'cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'proofshot')
foreach ($p in $products) {
    $pHtml = Get-Content (Join-Path $publicDir "$p\index.html") -Raw -Encoding UTF8
    Assert-Condition ($pHtml -match '/support/') "Product $p exposes support path"
}

# 4. Required Anchors on /support/
$requiredAnchors = @('products', 'windows', 'android', 'checksums', 'downloads', 'report')
foreach ($a in $requiredAnchors) {
    Assert-Condition ($supportHtml -match "id=`"$a`"") "/support/ contains anchor id='$a'"
}

# 5. Report Section — State A Self-Service Only Constraints
Assert-Condition ($supportHtml -match 'Direct online support submission is not published yet') "/support/ contains explicit State A disclaimer"
Assert-Condition ($supportHtml -notmatch '<form\s+action') "/support/ does not contain form submission endpoint"
Assert-Condition ($supportHtml -notmatch '<button[^>]*type=["'']submit["'']') "/support/ does not contain submit button"
Assert-Condition ($supportHtml -notmatch '\[OWNER DECISION REQUIRED\]') "/support/ does not expose unrendered placeholder text"
Assert-Condition ($supportHtml -match 'Do not include passwords, API keys, access tokens') "/support/ contains private data warning"
Assert-Condition ($supportHtml -notmatch 'processed for diagnostic resolution only') "/support/ does not claim unfulfilled retention policy"

# 6. Windows Security Wording Controls
$allHtmlFiles = Get-ChildItem -Path $publicDir -Recurse -Filter "*.html"
$runAnywayFound = $false
$provesAuthFound = $false
$provesSafeFound = $false

foreach ($f in $allHtmlFiles) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($content -match 'when it is safe to click Run Anyway') { $runAnywayFound = $true }
    if ($content -match 'checksum proves the file is safe') { $provesSafeFound = $true }
    if ($content -match 'SHA-256 proves authenticity') { $provesAuthFound = $true }
}

Assert-Condition (-not $runAnywayFound) "Deny 'when it is safe to click Run Anyway' across all generated HTML"
Assert-Condition (-not $provesSafeFound) "Deny 'checksum proves the file is safe' across all generated HTML"
Assert-Condition (-not $provesAuthFound) "Deny unqualified 'SHA-256 proves authenticity' across all generated HTML"

# 7. Checksum Vocabulary & Byte-Identity Standard
Assert-Condition ($supportHtml -match 'SHA-256 match = byte-identity verification against the published digest') "/support/ defines SHA-256 match standard"
Assert-Condition ($supportHtml -match 'The 8-Field Checksum Identity Schema') "/support/ explains the 8-field checksum identity schema"

# 8. Lights Out Dead-End Link Fix
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw -Encoding UTF8
Assert-Condition ($loHtml -match '<a href="/support/#report">contact the project</a>') "Lights Out dead-end link updated to point to /support/#report"

# 9. P1 Regression Assertions
$rgHtml = Get-Content (Join-Path $publicDir "reality-gate\index.html") -Raw -Encoding UTF8
Assert-Condition ($rgHtml -match '(?s)First-Class CLI &amp; Instance Discovery \(RG-05\).*?Branch Qualified') "P1 Regression: Reality Gate RG-05 remains Branch Qualified"

$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw -Encoding UTF8
Assert-Condition ($cvHtml -match 'Download links are currently unavailable') "P1 Regression: Cache Vault download unavailable notice intact"

Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "P1 Regression: Lights Out old deployment receipt link remains absent"

$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'HOLD') "P1 Regression: Lights Out release status remains HOLD"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
