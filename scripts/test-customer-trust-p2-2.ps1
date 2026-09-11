# PowerShell script for testing P2-2 Customer Trust Privacy & Data Flow Invariants
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== P2-2 CUSTOMER TRUST PRIVACY & DATA FLOW INVARIANTS TEST SUITE ===" -ForegroundColor Cyan

$publicDir = Join-Path $PSScriptRoot "..\public"
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

$products = @('reality-gate', 'cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'proofshot')

# 1. Product Privacy & Data Flow Disclosure Section Presence (All 7 products)
foreach ($p in $products) {
    $pPath = Join-Path $publicDir "$p\index.html"
    Assert-Condition (Test-Path $pPath) "Route $p/index.html exists"
    $pHtml = Get-Content $pPath -Raw -Encoding UTF8
    Assert-Condition ($pHtml -match 'id="privacy-data-flow"') "Product $p contains Privacy & Data Flow section (id='privacy-data-flow')"
    Assert-Condition ($pHtml -match 'Privacy &amp; Data Flow') "Product $p contains Privacy & Data Flow kicker"
}

# 2. Cache Vault LAN Disclosure Assertion
$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw -Encoding UTF8
Assert-Condition ($cvHtml -match 'local Wi-Fi network') "Cache Vault discloses local Wi-Fi / LAN companion transfer"
Assert-Condition ($cvHtml -notmatch 'clipboard history never leaves your device') "Cache Vault rejects universal 'never leaves your device' claim"
Assert-Condition ($cvHtml -notmatch 'clipboard data never leaves this device') "Cache Vault rejects 'clipboard data never leaves this device'"

# 3. Lights Out Network Options & Local-Only Wording Repair
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw -Encoding UTF8
Assert-Condition ($loHtml -match 'Core local automation') "Lights Out discloses core local automation"
Assert-Condition ($loHtml -match 'Optional LAN, smart lights, and webhook integrations') "Lights Out discloses optional LAN/Hue/webhook integrations"
Assert-Condition ($loHtml -notmatch '<li>Local-only operation — no cloud, no account, no telemetry</li>') "Lights Out rejects unqualified universal local-only bullet"

# 4. ForgeCast Weather API HTTPS Egress Disclosure
$fcHtml = Get-Content (Join-Path $publicDir "forgecast\index.html") -Raw -Encoding UTF8
Assert-Condition ($fcHtml -match 'Fetches weather forecasts over HTTPS') "ForgeCast discloses HTTPS weather forecast API queries"
Assert-Condition ($fcHtml -notmatch 'ForgeCast is an offline weather app') "ForgeCast rejects 'offline weather app' claim"

# 5. GhostLayer Temporary Editor Disk File Disclosure
$glHtml = Get-Content (Join-Path $publicDir "ghostlayer\index.html") -Raw -Encoding UTF8
Assert-Condition ($glHtml -match '%TEMP%\\GhostLayer\\') "GhostLayer discloses temporary editor files in %TEMP%\GhostLayer\"
Assert-Condition ($glHtml -notmatch 'GhostLayer never writes to disk') "GhostLayer rejects universal 'never writes to disk' claim"
Assert-Condition ($glHtml -notmatch 'never touches disk') "GhostLayer rejects 'never touches disk' claim"

# 6. ProofShot Staged Network Pipeline Wording Repair
$psHtml = Get-Content (Join-Path $publicDir "proofshot\index.html") -Raw -Encoding UTF8
Assert-Condition ($psHtml -match 'SmartDecode parses page structure from supplied HTML locally') "ProofShot discloses local SmartDecode HTML analysis"
Assert-Condition ($psHtml -match 'fetches page resources over HTTPS') "ProofShot discloses HTTPS target URL resource intake during capture"
Assert-Condition ($psHtml -match 'verified 100% offline') "ProofShot discloses offline bundle verification"
Assert-Condition ($psHtml -notmatch 'reads what the target actually contains — offline') "ProofShot rejects contradictory 'reads target URL offline' claim"
Assert-Condition ($psHtml -notmatch 'with no account and no network dependency') "ProofShot rejects unqualified 'no network dependency' claim for extraction pipeline"

# 7. Reality Gate Local Core vs User-Directed Remote Boundary
$rgHtml = Get-Content (Join-Path $publicDir "reality-gate\index.html") -Raw -Encoding UTF8
Assert-Condition ($rgHtml -match '127\.0\.0\.1:8765') "Reality Gate discloses loopback 127.0.0.1:8765 MCP adapter"
Assert-Condition ($rgHtml -match 'system Git CLI') "Reality Gate discloses user-directed system Git sync"

# 8. Cleanroom Local Reversible Archive Disclosure
$crHtml = Get-Content (Join-Path $publicDir "cleanroom\index.html") -Raw -Encoding UTF8
Assert-Condition ($crHtml -match '%APPDATA%\\Cleanroom\\Archive\\') "Cleanroom discloses %APPDATA%\Cleanroom\Archive\ local storage"
Assert-Condition ($crHtml -notmatch 'Cleanroom can never use the network') "Cleanroom rejects universal 'never use the network' claim"

# 9. Support Privacy & Data Flow Navigation Section
$spHtml = Get-Content (Join-Path $publicDir "support\index.html") -Raw -Encoding UTF8
Assert-Condition ($spHtml -match 'id="privacy"') "Support page contains Privacy section (id='privacy')"
Assert-Condition ($spHtml -match 'Privacy &amp; Data Flow disclosures') "Support page contains Privacy & Data Flow heading"
foreach ($p in $products) {
    Assert-Condition ($spHtml -match "/$p/#privacy-data-flow") "Support page links to $p privacy disclosure"
}

# 10. Forbidden Overclaim Pass across all generated HTML files
$allHtmlFiles = Get-ChildItem -Path $publicDir -Recurse -Filter "*.html"
$overclaimFound = $false

foreach ($f in $allHtmlFiles) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($content -match 'nothing leaves your device') { $overclaimFound = $true; Write-Host "Forbidden: 'nothing leaves your device' in $($f.Name)" -ForegroundColor Red }
    if ($content -match 'never leaves your device') { $overclaimFound = $true; Write-Host "Forbidden: 'never leaves your device' in $($f.Name)" -ForegroundColor Red }
    if ($content -match 'zero network capability') { $overclaimFound = $true; Write-Host "Forbidden: 'zero network capability' in $($f.Name)" -ForegroundColor Red }
    if ($content -match 'completely anonymous') { $overclaimFound = $true; Write-Host "Forbidden: 'completely anonymous' in $($f.Name)" -ForegroundColor Red }
    if ($content -match 'guaranteed private') { $overclaimFound = $true; Write-Host "Forbidden: 'guaranteed private' in $($f.Name)" -ForegroundColor Red }
}
Assert-Condition (-not $overclaimFound) "Forbidden overclaim sweep passed across all generated HTML"

# 11. P1 & P2-1 Regression Controls
Assert-Condition ($spHtml -match 'SHA-256 match = byte-identity verification against the published digest') "P2-1 Checksum byte-identity standard intact"
Assert-Condition ($rgHtml -match '(?s)First-Class CLI &amp; Instance Discovery \(RG-05\).*?Branch Qualified') "P1 Reality Gate RG-05 status intact"
Assert-Condition ($cvHtml -match 'Download links are currently unavailable') "P1 Cache Vault download unavailable notice intact"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== P2-2 TEST RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
