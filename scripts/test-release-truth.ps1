# PowerShell script for testing P1 Release Truth Invariants
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== P1 RELEASE TRUTH INVARIANTS TEST SUITE ===" -ForegroundColor Cyan

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

# 1. Reality Gate CLI matrix assertion (F01)
$rgHtml = Get-Content (Join-Path $publicDir "reality-gate\index.html") -Raw
Assert-Condition ($rgHtml -match 'First-Class CLI &amp; Instance Discovery \(RG-05\)') "Reality Gate matrix includes RG-05"
Assert-Condition ($rgHtml -match '(?s)First-Class CLI &amp; Instance Discovery \(RG-05\).*?Branch Qualified') "RG-05 matrix row reports Branch Qualified, resolving F01 contradiction"

# 2. Cache Vault verification & availability assertion (F02, F03)
$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "Cache Vault exposes explicit download availability notice"
Assert-Condition ($cvHtml -match 'Proof Foundry downloads') "Cache Vault states distribution source"

# 3. Lights Out evidence link assertion (F05)
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw
Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "Lights Out release evidence does not link to site deployment report"

# 4. Lights Out SmartScreen FAQ assertion (F12)
Assert-Condition ($loHtml -notmatch 'Windows shows this warning for any unsigned executable') "Lights Out FAQ does not contain overgeneralized unsigned warning copy"
Assert-Condition ($loHtml -match 'Windows may show an unrecognized-app or "Windows protected your PC" warning, depending on Windows security and reputation checks') "Lights Out FAQ contains accurate reputation-based SmartScreen copy"

# 5. Machine Registry parity assertion (R01)
$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw | ConvertFrom-Json
Assert-Condition ($registryJson.products.Count -eq 7) "Registry covers all 7 products"

$rgRegistry = $registryJson.products | Where-Object { $_.id -eq 'reality-gate' }
Assert-Condition ($rgRegistry.release.publicVersion -eq '1.1.0') "Registry Reality Gate version is 1.1.0"

$cvRegistry = $registryJson.products | Where-Object { $_.id -eq 'cache-vault' }
Assert-Condition ($cvRegistry.verification.status -eq 'VERIFIED') "Registry Cache Vault verification status is VERIFIED"

$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'HOLD') "Registry Lights Out release status is HOLD"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
