# PowerShell script for testing P1 Release Truth Invariants
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== P1 RELEASE TRUTH INVARIANTS TEST SUITE ===" -ForegroundColor Cyan

$publicDir = Join-Path $PSScriptRoot "..\public"
$manifestPath = Join-Path $PSScriptRoot "..\site-manifest.json"
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

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
$proofshotManifest = @($manifest.products | Where-Object { $_.id -eq 'proofshot' } | Select-Object -First 1)[0]
Assert-Condition ($proofshotManifest.evidence -contains 'https://theprooffoundry.com/proof/#receipt-proofshot' -and $proofshotManifest.evidence -notcontains 'https://github.com/lazelife420-spec/ProofShot/releases/tag/v2.0.0') 'ProofShot release detail points to the canonical first-party receipt, not the dead upstream tag'

# 3. Lights Out evidence link assertion (F05)
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw
Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "Lights Out release evidence does not link to site deployment report"

# 4. Lights Out SmartScreen FAQ assertion (F12)
Assert-Condition ($loHtml -notmatch 'Windows shows this warning for any unsigned executable') "Lights Out FAQ does not contain overgeneralized unsigned warning copy"
Assert-Condition ($loHtml -match 'Windows may show an unrecognized-app or &quot;Windows protected your PC&quot; warning, depending on Windows security and reputation checks') "Lights Out FAQ contains accurate reputation-based SmartScreen copy (HTML-escaped)"

# 5. Machine Registry parity assertion (R01)
$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw | ConvertFrom-Json
$canonicalProductCount = @((Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).products | Where-Object visible).Count
Assert-Condition ($registryJson.products.Count -eq $canonicalProductCount) 'Registry covers every canonical visible product dynamically'

$rgRegistry = $registryJson.products | Where-Object { $_.id -eq 'reality-gate' }
Assert-Condition ($rgRegistry.release.releaseStatus -eq 'WITHDRAWN' -and $null -eq $rgRegistry.release.publicVersion) 'Reality Gate has no current public release version'
Assert-Condition ($rgRegistry.release.withdrawnVersion -eq '1.1.0' -and $rgRegistry.productStatus -eq 'WITHDRAWN') 'Reality Gate v1.1.0 is recorded as withdrawn'
$rgTruth = Get-Content (Join-Path $publicDir 'truth\products\reality-gate.json') -Raw | ConvertFrom-Json
Assert-Condition ($rgTruth.download.available -eq $false -and $null -eq $rgTruth.download.url -and @($rgTruth.artifacts | Where-Object { $_.downloadUrl -or $_.sha256Url }).Count -eq 0) 'withdrawn Reality Gate has no machine-readable download URLs'
Assert-Condition ($rgTruth.artifacts[0].filename -eq 'Reality-Gate-1.1.0-Developer-Pilot.zip' -and $rgTruth.artifacts[0].sha256 -eq '58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756') 'historical Reality Gate artifact filename and checksum remain on record'
$rgPage = Get-Content (Join-Path $publicDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert-Condition ($rgPage -match 'Withdrawn.*v1\.1\.0.*not available for download' -and $rgPage -notmatch 'href="https://downloads\.theprooffoundry\.com/reality-gate/v1\.1\.0/') 'Reality Gate route states withdrawal and renders no dead download link'
$experienceJs = Get-Content (Join-Path $publicDir 'experience.js') -Raw -Encoding UTF8
Assert-Condition ($experienceJs -match "acquisitionAvailable=document\.body\.dataset\.acquisitionAvailable==='true'" -and $experienceJs -match "\?\s*\(document\.body\.classList" -and $experienceJs -match ":'Release status'" -and $experienceJs -notmatch 'Get the pilot') 'sticky product navigation derives its action from generic acquisition eligibility and uses a status label when unavailable'
Assert-Condition ($rgPage -match '<body[^>]*data-acquisition-available="false"' -and $rgPage -notmatch 'Get the pilot') 'withdrawn Reality Gate page exposes no acquisition eligibility or stale pilot CTA'
$eligibleProducts = 0
$ineligibleProducts = 0
$noPublicVersionProducts = 0
$noVersionProductsIneligible = $true
foreach ($productTruth in $registryJson.products) {
    $productPagePath = Join-Path $publicDir (($productTruth.route.Trim('/') -replace '/', '\') + '\index.html')
    $productPage = Get-Content $productPagePath -Raw -Encoding UTF8
    $canonicalProduct = $manifest.products | Where-Object { $_.id -eq $productTruth.id } | Select-Object -First 1
    $downloadUnavailable = $false
    if ($canonicalProduct.presentation -and $canonicalProduct.presentation.PSObject.Properties['downloadUnavailable']) { $downloadUnavailable = [bool]$canonicalProduct.presentation.downloadUnavailable }
    $expectedEligible = ($canonicalProduct.release.releaseStatus -eq 'PUBLIC_RELEASE' -and -not [string]::IsNullOrWhiteSpace([string]$canonicalProduct.release.publicVersion) -and $canonicalProduct.verification.status -eq 'VERIFIED' -and -not $downloadUnavailable -and -not [string]::IsNullOrWhiteSpace([string]$canonicalProduct.downloadUrl))
    $renderedEligible = $productPage -match '<body[^>]*data-acquisition-available="true"'
    if ($expectedEligible) { $eligibleProducts++ } else { $ineligibleProducts++ }
    if ([string]::IsNullOrWhiteSpace([string]$productTruth.release.publicVersion)) {
        $noPublicVersionProducts++
        if ($renderedEligible) { $noVersionProductsIneligible = $false }
    }
    Assert-Condition ($renderedEligible -eq [bool]$expectedEligible) "$($productTruth.id): product page acquisition eligibility matches canonical public release, verification, and download state"
}
Assert-Condition ($eligibleProducts -gt 0 -and $ineligibleProducts -gt 0) 'acquisition eligibility covers both public-download and unavailable product states'
Assert-Condition ($noPublicVersionProducts -gt 0 -and $noVersionProductsIneligible) 'products with no public version cannot expose acquisition eligibility'
$supportPage = Get-Content (Join-Path $publicDir 'support\index.html') -Raw -Encoding UTF8
$rgSupport = [regex]::Match($supportPage, '(?s)<article class="detail-card">\s*<h3><a href="/reality-gate/">.*?</article>').Value
$cvSupport = [regex]::Match($supportPage, '(?s)<article class="detail-card">\s*<h3><a href="/cache-vault/">.*?</article>').Value
$cvSupportTruth = $registryJson.products | Where-Object { $_.id -eq 'cache-vault' }
Assert-Condition ($rgRegistry.release.publicVersion -eq $null -and $rgSupport -match 'Withdrawn · no public download' -and $rgSupport -match 'former v1\.1\.0 release is withdrawn and no public download is available') 'Support derives withdrawn status and no-public-version availability from canonical Reality Gate truth'
Assert-Condition ($cvSupportTruth.release.publicVersion -eq '0.2.4' -and $cvSupport -match 'Public Windows v0\.2\.4 available') 'Support retains the current public version for an available product'
Assert-Condition ($supportPage -notmatch '\{\{products\.' -and $rgSupport -notmatch 'Windows Developer Pilot\s+available\.') 'Support renders canonical availability without unresolved tokens or a malformed pilot-available claim'
$rgProof = Get-Content (Join-Path $publicDir 'proof\index.html') -Raw -Encoding UTF8
Assert-Condition ($rgProof -match 'Historical release record: Historical Windows installer ZIP record for v1\.1\.0' -and $rgProof -match 'Downloads currently unavailable') 'release receipt keeps historical evidence and suppresses the download CTA'
$softwarePage = Get-Content (Join-Path $publicDir 'software\index.html') -Raw -Encoding UTF8
Assert-Condition ($softwarePage -match 'Withdrawn · unavailable' -and $softwarePage -match 'v1\.1\.0 withdrawn · no current public download' -and $softwarePage -notmatch 'Reality Gate is a Developer Pilot') 'software catalog exposes withdrawn state and no stale pilot claim'
$roadmapPage = Get-Content (Join-Path $publicDir 'roadmap\index.html') -Raw -Encoding UTF8
Assert-Condition ($roadmapPage -match 'WITHDRAWN' -and $roadmapPage -match 'former v1\.1\.0 release is withdrawn and no public download is available' -and $roadmapPage -notmatch 'public Windows pilot remains available|current pilot download') 'roadmap derives Reality Gate availability from canonical withdrawn state'

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
Assert-Condition ($loRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') "Registry Lights Out release status is PUBLIC_RELEASE"
Assert-Condition ($loRegistry.release.publicVersion -eq '11.1.3') "Registry Lights Out public version is 11.1.3"
Assert-Condition ($null -eq $loRegistry.release.candidateVersion) "Registry Lights Out carries no candidate version (v11.1.3 is final)"
Assert-Condition ($loRegistry.release.publishedAt -eq '2026-09-15') "Registry Lights Out publishedAt matches the final release date"
$loTruthJson = Get-Content (Join-Path $publicDir "truth\products\lights-out.json") -Raw | ConvertFrom-Json
Assert-Condition ($loTruthJson.release.companionPublicVersion -eq '11.1.1') "Truth record Lights Out public companion remains 11.1.1"
Assert-Condition ($loTruthJson.download.available -eq $true) "Truth record Lights Out download is available"
Assert-Condition ($loHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/lights-out/v11.1.3/Lights-Out-Portable-v11.1.3-win-x64.zip')) "Lights Out download resolves to the published v11.1.3 R2 mirror ZIP"
Assert-Condition ($loHtml -match 'b4a5f4a4332b53106618433bc1817f4fcc5decede9f97ebb3817b69cef6b7e62') "Lights Out publishes the final v11.1.3 portable ZIP SHA-256"
Assert-Condition ($loHtml -match 'dc4ffa82a254820e4946a1056a8b894aea3c39b171c39e79d4a34747a010545a') "Lights Out publishes the final v11.1.3 installer SHA-256"
Assert-Condition ($loHtml -notmatch 'c7872350101906471e83d8c0649e1e65c5f9baa4591e0c02ccfd8780215726d6') "Lights Out does not present the superseded RC4 artifact hash"
Assert-Condition ($loHtml -match 'Receipt</dt><dd>342c11bc-d2d6-4918-8920-a495211ff69b') "Lights Out receipt binding is the final-artifact qualification receipt"

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
