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
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "P1 Regression: Cache Vault download availability notice intact"

Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "P1 Regression: Lights Out old deployment receipt link remains absent"

$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'HOLD') "P1 Regression: Lights Out release status remains HOLD"

# 10. Hardened Support Release-Truth Parity Assertions
Assert-Condition ($supportHtml -match 'Reality Gate[\s\S]*?v1\.1\.0') "Support release truth: Reality Gate v1.1.0"
Assert-Condition ($supportHtml -match 'Cache Vault[\s\S]*?v0\.2\.2[\s\S]*?v0\.2\.3-rc1') "Support release truth: Cache Vault v0.2.2 / v0.2.3-rc1"
Assert-Condition ($supportHtml -match 'Lights Out[\s\S]*?v11\.1\.2[\s\S]*?v11\.1\.3[\s\S]*?v11\.1\.1') "Support release truth: Lights Out v11.1.2 / v11.1.3 / Android v11.1.1"
Assert-Condition ($supportHtml -match 'Cleanroom[\s\S]*?v1\.0\.7[\s\S]*?v1\.0\.10') "Support release truth: Cleanroom v1.0.7 / candidate v1.0.10"
Assert-Condition ($supportHtml -notmatch 'Cleanroom[\s\S]*?v1\.2\.0') "Support release truth: Cleanroom rejects incorrect v1.2.0"
Assert-Condition ($supportHtml -notmatch 'Cleanroom[\s\S]*?v1\.3\.0') "Support release truth: Cleanroom rejects incorrect v1.3.0"
Assert-Condition ($supportHtml -match 'GhostLayer[\s\S]*?v0\.4\.0') "Support release truth: GhostLayer v0.4.0"
Assert-Condition ($supportHtml -notmatch 'GhostLayer[\s\S]*?v1\.0\.0') "Support release truth: GhostLayer rejects incorrect v1.0.0"
Assert-Condition ($supportHtml -match 'ForgeCast[\s\S]*?v0\.3\.5') "Support release truth: ForgeCast v0.3.5"
Assert-Condition ($supportHtml -match 'ProofShot[\s\S]*?no public release package') "Support release truth: ProofShot no public release package"

# 11. Hardened Global Navigation Parity Assertions across all generated surfaces
$allRoutes = @('', 'reality-gate', 'cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'proofshot', 'proof', 'roadmap', 'founders')
foreach ($r in $allRoutes) {
    $rPath = if ($r -eq '') { Join-Path $publicDir "index.html" } else { Join-Path $publicDir "$r\index.html" }
    if (Test-Path $rPath) {
        $rContent = Get-Content $rPath -Raw -Encoding UTF8
        Assert-Condition ($rContent -match 'href="/support/"') "Navigation parity: Route '$r' contains header/footer link to /support/"
    }
}

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
