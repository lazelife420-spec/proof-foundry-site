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

# 2. Current production release reconciliation: Cache Vault v0.3.1.
$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "Cache Vault exposes explicit download availability notice"
Assert-Condition ($cvHtml -match 'Proof Foundry downloads') "Cache Vault states distribution source"
Assert-Condition ($cvHtml -match 'v0\.3\.1 is the current public Windows release') "Cache Vault leads with final public v0.3.1 release state"
Assert-Condition ($cvHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/cache-vault/v0.3.1/CacheVault-v0.3.1-windows.zip')) "Cache Vault primary CTA resolves to the final v0.3.1 Windows ZIP"
Assert-Condition ($cvHtml -match 'd0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45') "Cache Vault publishes the final v0.3.1 ZIP SHA-256"
Assert-Condition ($cvHtml -notmatch 'v0\.2\.3-rc1|v0\.2\.3-rc2') "Cache Vault carries no RC1/RC2 candidate strings"
Assert-Condition ($cvHtml -notmatch 'release candidate') "Cache Vault does not present v0.3.1 as a candidate"

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
Assert-Condition ($loHtml -match 'Windows may show an unrecognized-app or &quot;Windows protected your PC&quot; warning, depending on Windows security and reputation checks') "Lights Out FAQ contains accurate reputation-based SmartScreen copy (HTML-escaped)"

# 5. Machine Registry parity assertion (R01)
$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw | ConvertFrom-Json
Assert-Condition ($registryJson.products.Count -eq 7) "Registry covers all 7 products"

$rgRegistry = $registryJson.products | Where-Object { $_.id -eq 'reality-gate' }
Assert-Condition ($null -eq $rgRegistry.release.publicVersion -and $rgRegistry.release.releaseStatus -eq 'WITHDRAWN' -and $rgRegistry.release.withdrawnVersion -eq '1.1.0') "Registry Reality Gate carries withdrawn v1.1.0 and no current public version"

$cvRegistry = $registryJson.products | Where-Object { $_.id -eq 'cache-vault' }
Assert-Condition ($cvRegistry.verification.status -eq 'VERIFIED') "Registry Cache Vault verification status is VERIFIED"
Assert-Condition ($cvRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') "Registry Cache Vault release status is PUBLIC_RELEASE (final public)"
Assert-Condition ($cvRegistry.release.publicVersion -eq '0.3.1') "Registry Cache Vault public version is 0.3.1"
Assert-Condition ($null -eq $cvRegistry.release.candidateVersion) "Registry Cache Vault carries no candidate version (v0.3.1 is final)"
Assert-Condition ($cvRegistry.release.publishedAt -eq '2026-10-01') "Registry Cache Vault publishedAt matches the final release receipt date"

$psRegistry = $registryJson.products | Where-Object { $_.id -eq 'proofshot' }
Assert-Condition ($psRegistry.release.publicVersion -eq '2.0.0') 'Registry ProofShot public version is 2.0.0'
Assert-Condition ($psRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') 'Registry ProofShot is PUBLIC_RELEASE'
Assert-Condition ($null -eq $psRegistry.release.candidateVersion) 'Registry ProofShot carries no candidate version'
Assert-Condition ($psRegistry.release.publishedAt -eq '2026-09-17') 'Registry ProofShot publication date is preserved'

$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') "Registry Lights Out release status is PUBLIC_RELEASE"
Assert-Condition ($loRegistry.release.publicVersion -eq '11.2.0') "Registry Lights Out public version is 11.2.0"
Assert-Condition ($null -eq $loRegistry.release.candidateVersion) "Registry Lights Out carries no candidate version (v11.2.0 is final)"
Assert-Condition ($loRegistry.release.publishedAt -eq '2026-10-16') "Registry Lights Out publishedAt matches the final release date"
$loTruthJson = Get-Content (Join-Path $publicDir "truth\products\lights-out.json") -Raw | ConvertFrom-Json
Assert-Condition ($loTruthJson.release.companionPublicVersion -eq '11.1.1') "Truth record Lights Out public companion remains 11.1.1"
Assert-Condition ($loTruthJson.download.available -eq $true) "Truth record Lights Out download is available"
Assert-Condition ($loHtml -match [regex]::Escape('https://github.com/lazelife420-spec/Lights-out/releases/download/v11.2.0/Lights-Out-Portable-v11.2.0-win-x64.zip')) "Lights Out download resolves to the published v11.2.0 GitHub release portable ZIP"
Assert-Condition ($loHtml -match '7e855475c3f7a3e65a4921bc7d9237a1a69480514943de597f65ad3cfb273b39') "Lights Out publishes the v11.2.0 portable ZIP SHA-256"
Assert-Condition ($loHtml -match '83c590c3de54b16b26bfeb4961858e44a225dd59c7501e77d72248a5882a37c0') "Lights Out publishes the v11.2.0 installer SHA-256"
Assert-Condition ($loHtml -notmatch 'b4a5f4a4332b53106618433bc1817f4fcc5decede9f97ebb3817b69cef6b7e62' -and $loHtml -notmatch 'dc4ffa82a254820e4946a1056a8b894aea3c39b171c39e79d4a34747a010545a') "Lights Out does not present the superseded v11.1.3 artifact hashes"
Assert-Condition ($loHtml -match 'No Reality Gate receipt is published for v11\.2\.0' -and $loHtml -match '342c11bc-d2d6-4918-8920-a495211ff69b') "Lights Out states no v11.2.0 receipt exists and keeps the earlier receipts historical"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
