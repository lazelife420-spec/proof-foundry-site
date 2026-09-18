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

# 2. Current production release reconciliation: Cache Vault v0.2.4.
$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "Cache Vault exposes explicit download availability notice"
Assert-Condition ($cvHtml -match 'Proof Foundry downloads') "Cache Vault states distribution source"
Assert-Condition ($cvHtml -match 'v0\.2\.4 is the current public Windows release') "Cache Vault leads with final public v0.2.4 release state"
Assert-Condition ($cvHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/cache-vault/v0.2.4/CacheVault-v0.2.4-windows.zip')) "Cache Vault primary CTA resolves to the final v0.2.4 Windows ZIP"
Assert-Condition ($cvHtml -match '717ed13efd3d8d4e5a16d4e412ed5be0fd20b0219918f913d7d2b44f021cae7e') "Cache Vault publishes the final v0.2.4 ZIP SHA-256"
Assert-Condition ($cvHtml -notmatch 'v0\.2\.3-rc1|v0\.2\.3-rc2') "Cache Vault carries no RC1/RC2 candidate strings"
Assert-Condition ($cvHtml -notmatch 'release candidate') "Cache Vault does not present v0.2.4 as a candidate"

# ProofShot's former no-release guard is superseded by the shipped installer.
$psHtml = Get-Content (Join-Path $publicDir 'proofshot\index.html') -Raw -Encoding UTF8
Assert-Condition ($psHtml -match 'Download ProofShot v2\.0\.0') 'ProofShot exposes its public v2.0.0 download'
Assert-Condition ($psHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/proofshot/v2.0.0/ProofShot-Setup-2.0.0.exe')) 'ProofShot installer URL exactly matches current production'
Assert-Condition ($psHtml -match 'fa20dc7e44440f0ed96fa08db67a77339d595f8eb27090e24120104ea6744701') 'ProofShot installer SHA-256 exactly matches current production'
Assert-Condition ($psHtml -notmatch 'no public ProofShot release|no public release package|NOT YET RELEASED') 'ProofShot has no stale unreleased claim'
Assert-Condition ($psHtml -match 'Unsigned build' -and $psHtml -match 'Screenshots predate the rebrand') 'ProofShot signing and legacy-preview disclosures remain explicit'

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
Assert-Condition ($cvRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') "Registry Cache Vault release status is PUBLIC_RELEASE (final public)"
Assert-Condition ($cvRegistry.release.publicVersion -eq '0.2.4') "Registry Cache Vault public version is 0.2.4"
Assert-Condition ($null -eq $cvRegistry.release.candidateVersion) "Registry Cache Vault carries no candidate version (v0.2.4 is final)"
Assert-Condition ($cvRegistry.release.publishedAt -eq '2026-09-17') "Registry Cache Vault publishedAt matches the final release receipt date"

$psRegistry = $registryJson.products | Where-Object { $_.id -eq 'proofshot' }
Assert-Condition ($psRegistry.release.publicVersion -eq '2.0.0') 'Registry ProofShot public version is 2.0.0'
Assert-Condition ($psRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') 'Registry ProofShot is PUBLIC_RELEASE'
Assert-Condition ($null -eq $psRegistry.release.candidateVersion) 'Registry ProofShot carries no candidate version'
Assert-Condition ($psRegistry.release.publishedAt -eq '2026-09-17') 'Registry ProofShot publication date is preserved'

$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'HOLD') "Registry Lights Out release status is HOLD"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
