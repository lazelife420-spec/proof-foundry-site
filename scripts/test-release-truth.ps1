. "$PSScriptRoot/release-qualification.ps1"
# PowerShell script for testing P1 Release Truth Invariants
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== P1 RELEASE TRUTH INVARIANTS TEST SUITE ===" -ForegroundColor Cyan

$publicDir = Join-Path $PSScriptRoot "..\public"
$manifestPath = Join-Path $PSScriptRoot "..\site-manifest.json"
$manifest = Get-AuthoredReleaseManifest

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

# 2. Current published release reconciliation: Cache Vault v0.3.1.
$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "Cache Vault exposes explicit download availability notice"
Assert-Condition ($cvHtml -match 'Proof Foundry downloads') "Cache Vault states distribution source"
Assert-Condition ($cvHtml -match 'v0\.3\.1 is the current public Windows release') "Cache Vault leads with current public Windows v0.3.1"
Assert-Condition ($cvHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/cache-vault/v0.3.1/CacheVault-v0.3.1-windows.zip')) "Cache Vault primary CTA resolves to the v0.3.1 Windows ZIP"
Assert-Condition ($cvHtml -match 'd0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45') "Cache Vault publishes the v0.3.1 Windows ZIP SHA-256"
Assert-Condition ($cvHtml -notmatch 'v0\.2\.3-rc1|v0\.2\.3-rc2') "Cache Vault carries no RC1/RC2 candidate strings"
Assert-Condition ($cvHtml -match 'v0\.3\.1 is the current public Windows release' -and $cvHtml -match 'v0\.3\.0 \(2026-09-30\) is the previous public release') "Cache Vault distinguishes current v0.3.1 from prior public v0.3.0"
Assert-Condition ($cvHtml -match 'Recorded from the v0\.2\.4 Windows release line' -and $cvHtml -match 'sample clips only') "Cache Vault keeps the v0.2.4 film historical and sample-labeled"
Assert-Condition ($cvHtml -match 'Hosted GitHub CI failed separately' -and $cvHtml -match 'debug build' -and $cvHtml -match 'No Reality Gate canonical run was performed') "Cache Vault scopes hosted CI, device smoke and canonical qualification"

# ProofShot's former no-release guard is superseded by the shipped installer.
$psHtml = Get-Content (Join-Path $publicDir 'proofshot\index.html') -Raw -Encoding UTF8
Assert-Condition ($psHtml -match 'Download ProofShot v2\.0\.0') 'ProofShot exposes its public v2.0.0 download'
Assert-Condition ($psHtml -match [regex]::Escape('https://downloads.theprooffoundry.com/proofshot/v2.0.0/ProofShot-Setup-2.0.0.exe')) 'ProofShot installer URL exactly matches current production'
Assert-Condition ($psHtml -match 'fa20dc7e44440f0ed96fa08db67a77339d595f8eb27090e24120104ea6744701') 'ProofShot installer SHA-256 exactly matches current production'
Assert-Condition ($psHtml -notmatch 'no public ProofShot release|no public release package|NOT YET RELEASED') 'ProofShot has no stale unreleased claim'
Assert-Condition ($psHtml -match 'Unsigned build' -and $psHtml -match 'Screenshots predate the rebrand') 'ProofShot signing and legacy-preview disclosures remain explicit'
$proofshotManifest = @($manifest.products | Where-Object { $_.id -eq 'proofshot' } | Select-Object -First 1)[0]
Assert-Condition ($proofshotManifest.evidence -contains 'https://theprooffoundry.com/proof/#receipt-proofshot' -and $proofshotManifest.evidence -notcontains 'https://github.com/lazelife420-spec/ProofShot/releases/tag/v2.0.0') 'ProofShot release detail points to the canonical first-party receipt, not the dead upstream tag'
# K7 (A-09 interim): the open licensing finding sits beside the download and next to the 60/60 tests pill.
$psFindingTitle = 'Open finding: licensing authority'
$psFindingText = 'After the v2.0.0 release, a licensing-authority finding was recorded and is still open. Its scope and impact have not been published yet. Until they are, read the 60/60 tamper, authority and migration result as release-time testing only; it does not show that this finding is resolved.'
$psFindingBlocks = @([regex]::Matches($psHtml, '(?s)<p class="pp-warning"[^>]*><strong>' + [regex]::Escape($psFindingTitle) + '</strong><br>(.*?)</p>') | ForEach-Object { $_.Groups[1].Value })
$psDownload = [regex]::Match($psHtml, '(?s)<section class="pp-get" id="download">.*?</section>').Value
$psFindingAt = $psHtml.IndexOf('id="licensing-finding"')
$psBefore = if ($psFindingAt -ge 0) { $psHtml.Substring(0, $psFindingAt) } else { '' }
$psOpenDisclosures = ([regex]::Matches($psBefore, '<details\b')).Count - ([regex]::Matches($psBefore, '</details>')).Count
Assert-Condition ($psFindingAt -gt 0 -and $psOpenDisclosures -eq 0 -and $psDownload -match 'id="licensing-finding"' -and $psDownload.Contains($psFindingTitle) -and $psDownload.Contains($psFindingText)) 'ProofShot shows the open licensing finding in its download section, outside every disclosure'
$psStrip = [regex]::Match($psHtml, '(?s)<div class="proof-strip">(.*?)</div>\s*<p class="pp-warning"><strong>' + [regex]::Escape($psFindingTitle) + '</strong><br>(.*?)</p>')
$psTamper = @($proofshotManifest.tests | Where-Object { $_.label -eq 'Tamper / authority / migration' } | Select-Object -First 1)
Assert-Condition ($psStrip.Success -and $psTamper.Count -eq 1 -and [string]$psTamper[0].result -eq '60/60' -and $psStrip.Groups[1].Value -match ('<strong>Tests</strong>[^<]*' + [regex]::Escape([string]$psTamper[0].result) + ' tamper\+authority\+migration') -and $psStrip.Groups[2].Value -ceq $psFindingText) 'ProofShot places the same finding directly after the proof strip whose tests pill carries the recorded 60/60 result'
Assert-Condition ($psFindingBlocks.Count -eq 2 -and @($psFindingBlocks | Where-Object { $_ -cne $psFindingText }).Count -eq 0 -and @($psFindingBlocks | Where-Object { $_ -match '(?i)\blicen[cs]e\b|legal entity|HyperSnatch Institutional|openOwnerItems' }).Count -eq 0 -and $psHtml -match 'Licensing authority review' -and @($proofshotManifest.limits | Where-Object { $_ -match 'licensing-authority finding remains unresolved' }).Count -eq 1) 'ProofShot shows the interim finding text exactly, twice, without speculating about the release-manifest LICENSE item, and keeps the limitation card and recorded limit'

# 3. Lights Out evidence link assertion (F05)
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw
Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "Lights Out release evidence does not link to site deployment report"

# 4. Lights Out SmartScreen FAQ assertion (F12)
Assert-Condition ($loHtml -notmatch 'Windows shows this warning for any unsigned executable') "Lights Out FAQ does not contain overgeneralized unsigned warning copy"
Assert-Condition ($loHtml -match 'Windows may show an unrecognized-app or &quot;Windows protected your PC&quot; warning, depending on Windows security and reputation checks') "Lights Out FAQ contains accurate reputation-based SmartScreen copy (HTML-escaped)"

# 5. Machine Registry parity assertion (R01)
$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw | ConvertFrom-Json
$canonicalProductCount = @((Get-AuthoredReleaseManifest).products | Where-Object visible).Count
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
Assert-Condition ($experienceJs -match "acquisitionAvailable=document\.body\.dataset\.acquisitionAvailable==='true'" -and $experienceJs -match "availability=acquisitionAvailable\?'Download':'Release status'" -and $experienceJs -notmatch 'Get the pilot') 'sticky product navigation derives its action from generic acquisition eligibility and uses a status label when unavailable'
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
Assert-Condition ($cvSupportTruth.release.publicVersion -eq '0.3.1' -and $cvSupport -match 'Public Windows v0\.3\.1 available') 'Support retains the current public version for an available product'
$cvPage = Get-Content (Join-Path $publicDir 'cache-vault\index.html') -Raw -Encoding UTF8
$cvSource = @($manifest.products | Where-Object { $_.id -eq 'cache-vault' })[0]
$cvCompanion = @($cvSource.artifacts | Where-Object { $_.platform -eq 'Android companion' } | Select-Object -First 1)[0]
$cvCompanionUrl = [string]$cvCompanion.downloadUrl
$cvCompanionHref = [regex]::Escape('href="' + $cvCompanionUrl + '"')
$cvCompanionVersion = [regex]::Escape('v' + [string]$cvSource.release.companionPublicVersion)
Assert-Condition (-not [string]::IsNullOrWhiteSpace($cvCompanionUrl) -and $cvSupportTruth.artifacts[1].downloadUrl -eq $cvCompanionUrl -and $cvSupport -match $cvCompanionHref -and $cvPage -match $cvCompanionHref -and $cvSupport -match "Android companion $cvCompanionVersion" -and $cvPage -match "release-signed $cvCompanionVersion companion APK" -and $cvSupport -notmatch 'unavailable on GitHub' -and $cvSource.presentation.downloadNotice -notmatch 'unavailable on GitHub') 'Support and Cache Vault use the same canonical public Android version and APK URL without a conflicting availability claim'
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
Assert-Condition ($cvRegistry.release.publicVersion -eq '0.3.1' -and $cvSource.release.companionPublicVersion -eq '0.3.1') "Registry and manifest Cache Vault Windows and Android public versions are both 0.3.1"
Assert-Condition ($null -eq $cvRegistry.release.candidateVersion -and $null -eq $cvSource.release.companionCandidateVersion) "Registry and manifest Cache Vault carry no current candidate version"
Assert-Condition ($cvRegistry.release.publishedAt -eq '2026-10-01' -and $cvSource.release.sourceCommit -eq 'eddbae7a2763d1994dae1e43e744ca8225d93eb3') "Registry and manifest Cache Vault date and source match the v0.3.1 release receipt"
Assert-Condition ($cvRegistry.artifacts[0].sha256 -eq 'd0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45' -and $cvRegistry.artifacts[1].sha256 -eq '863f8a5846083cb0372e1046ac1e9363e6203b4880cc2c6a7ca0da8b1b451988') "Registry keeps distinct Windows ZIP and Android APK digests"
Assert-Condition ($cvRegistry.verification.verificationType -notcontains 'REALITY_GATE' -and $cvRegistry.limits -match 'No Reality Gate canonical run') "Registry does not claim a v0.3.1 canonical Reality Gate run"

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
Assert-Condition ($loHtml -match [regex]::Escape('https://github.com/lazelife420-spec/Lights-out/releases/download/v11.2.0/Lights-Out-Portable-v11.2.0-win-x64.zip')) "Lights Out download resolves to the public v11.2.0 GitHub release ZIP"
Assert-Condition ($loHtml -match '7e855475c3f7a3e65a4921bc7d9237a1a69480514943de597f65ad3cfb273b39') "Lights Out publishes the v11.2.0 portable ZIP SHA-256"
Assert-Condition ($loHtml -match '83c590c3de54b16b26bfeb4961858e44a225dd59c7501e77d72248a5882a37c0') "Lights Out publishes the v11.2.0 installer SHA-256"
Assert-Condition ($loHtml -notmatch 'c7872350101906471e83d8c0649e1e65c5f9baa4591e0c02ccfd8780215726d6') "Lights Out does not present the superseded RC4 artifact hash"
Assert-Condition ($loHtml -notmatch 'Receipt</dt><dd>342c11bc' -and $loRegistry.verification.verificationType -notcontains 'REALITY_GATE') "Lights Out v11.2.0 does not borrow the v11.1.3 Reality Gate receipt"

# 6. K2: one withdrawn Reality Gate story on every page (dateless; W/PROPOSAL.md A-01)
function Get-K2Text([string]$html) {
    $t = [regex]::Replace($html, '(?is)<(script|style|template)\b.*?</\1>', ' ')
    $t = [regex]::Replace($t, '<[^>]+>', ' ')
    return ([System.Net.WebUtility]::HtmlDecode(($t -replace '\s+', ' '))).Trim()
}
$rgM = @($manifest.products | Where-Object { $_.id -eq 'reality-gate' } | Select-Object -First 1)[0]
$rgStatement = ([string]$rgM.statusStatement -replace '\s+', ' ').Trim()
Assert-Condition ($rgStatement -match 'was later withdrawn after a security packaging defect' -and $rgStatement -match 'No current public download is offered' -and $rgStatement -match 'does not authorize or certify a successor public release' -and $rgStatement -notmatch '(?i)withdrawn (on|in) ') 'Reality Gate status statement is the dateless withdrawn statement'
$routeFiles = @(Get-ChildItem $publicDir -Recurse -Filter 'index.html' -File | Where-Object { $_.FullName -notmatch '[\\/]__h14[\\/]' }) + @(Get-Item (Join-Path $publicDir '404.html'))
Assert-Condition ($routeFiles.Count -eq 25) "Reality Gate sweep covers all 25 public routes (found $($routeFiles.Count))"
$k2Forbidden = @(
    'Keep GitHub, GitLab, or Forgejo',
    'Local-first developer continuity for the Git workflow you already use',
    'Explore Reality Gate'
)
$k2Hits = @()
foreach ($f in $routeFiles) {
    $decoded = [System.Net.WebUtility]::HtmlDecode([IO.File]::ReadAllText($f.FullName))
    foreach ($phrase in $k2Forbidden) { if ($decoded.Contains($phrase)) { $k2Hits += "$($f.Directory.Name): $phrase" } }
}
Assert-Condition ($k2Hits.Count -eq 0) "no public route presents Reality Gate as an active product ($($k2Hits -join '; '))"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$authoredSources = @(Get-ChildItem $repoRoot -Filter '*.html' -File) + @(Get-ChildItem (Join-Path $repoRoot 'partials') -Filter '*.html' -File) + @(Get-ChildItem (Join-Path $repoRoot 'products') -Recurse -File | Where-Object { $_.Name -in @('content.html', 'module.json') }) + @(Get-Item (Join-Path $repoRoot 'site-manifest.json'))
$staleV111 = @($authoredSources | Where-Object {
    $raw = [IO.File]::ReadAllText($_.FullName)
    if ($_.Name -eq 'site-manifest.json') { $raw = [regex]::Replace($raw, '"anchor"\s*:\s*"[^"]*"', '"anchor": ""') }
    $raw -match 'not proven deployed'
} | ForEach-Object { $_.Name })
Assert-Condition ($authoredSources.Count -gt 10 -and $staleV111.Count -eq 0) "website-authored copy no longer says the v1.1.1 migration was 'not proven deployed' ($($staleV111 -join ', '))"
Assert-Condition ($rgPage -notmatch 'not proven deployed' -and $rgPage -match 'no record that this website ever offered it for download') 'Reality Gate page states the v1.1.1 position in plain words'
Assert-Condition ($rgPage -match 'lists the security disposition as unresolved') 'Reality Gate page keeps the unresolved security disposition visible'
$rgHero = [regex]::Match($rgPage, '(?s)<section class="product-hero\b.*?</section>').Value
$rgHeroText = Get-K2Text $rgHero
Assert-Condition ($rgHeroText.Contains($rgStatement) -and $rgHeroText.Contains('WITHDRAWN · Windows · v1.1.0 · no current download') -and $rgHero -match '</h1><p class="pp-hero-status"') 'Reality Gate hero states WITHDRAWN in words and the statement directly under the headline'
$k2Missing = @(@('about', 'support', 'roadmap', 'truth-files') | Where-Object { -not (Get-K2Text ([IO.File]::ReadAllText((Join-Path $publicDir "$_\index.html")))).Contains($rgStatement) })
Assert-Condition ($k2Missing.Count -eq 0) "About, Support, Roadmap and the Truth Files index carry the one Reality Gate statement ($($k2Missing -join ', '))"
Assert-Condition (([regex]::Matches($rgPage, 'class="availability-notice"')).Count -eq 1) 'Reality Gate page renders exactly one withdrawal notice'
Assert-Condition ($rgPage -notmatch 'aria-disabled="true"' -and $rgPage -match 'No download is offered\.') 'Reality Gate states that no download is offered, without a disabled download button'
$rgFinal = [regex]::Match($rgPage, '(?s)<section class="pp-final-cta">.*?</section>').Value
Assert-Condition ($rgFinal -match 'Historical record' -and $rgFinal -match 'href="/truth-files/reality-gate/"' -and $rgFinal -notmatch 'href="#download"') 'Reality Gate closing block points to the withdrawal record'
$rgFilm = [regex]::Match($rgPage, '(?s)<section class="film-section" id="film">.*?</section>').Value
Assert-Condition ($rgFilm -match 'edited demo run' -and $rgFilm -match 'It does not show a completed recovery drill\.' -and $rgFilm -notmatch 'start to finish|proving bundle integrity|drilling recovery') 'Reality Gate film copy describes only what the recording shows'
Assert-Condition ($rgPage -notmatch 'Every node in this architecture' -and $rgPage -notmatch 'inside that sandbox' -and $rgPage -notmatch 'rg-schematic-wrap' -and $rgPage -match 'inside that isolated clone') 'Reality Gate architecture copy no longer contradicts the Runroom note'
$rgPrivacy = [regex]::Match($rgPage, '(?s)<section\b[^>]*\bid="privacy-data-flow"[^>]*>.*?</section>').Value
$rgScope = [regex]::Match($rgPage, '(?s)<details class="pp-sub" id="development-scope">.*?</details>').Value
Assert-Condition ($rgPrivacy -and $rgPrivacy -notmatch 'MCP|8765' -and $rgScope -match '127\.0\.0\.1:8765') 'Reality Gate lists the MCP adapter under development scope, not the v1.1.0 privacy list'
Assert-Condition ($rgPage -match 'Illustrative sample receipt: the hash values are placeholders, not from a real run\.' -and $rgPage -match 'artifactHashes entry is a placeholder') 'Reality Gate sample receipt is labelled as illustrative with placeholder hashes'
Assert-Condition ($rgPage -match '<h2>What v1\.1\.0 did \(historical\)</h2>') 'Reality Gate capability section is historical and past tense'
$rgCard = [regex]::Match($softwarePage, '(?s)<article class="product-card[^>]*data-product="reality-gate".*?</article>').Value
Assert-Condition ($rgCard -match 'Read the withdrawal record' -and $rgCard -notmatch 'compare-choice|data-compare=' -and ([regex]::Matches($softwarePage, 'class="compare-choice"')).Count -eq (([regex]::Matches($softwarePage, '<article class="product-card')).Count - 1)) 'Software card for withdrawn Reality Gate offers its record, not Compare'
$rgSource = @((Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).products | Where-Object { $_.id -eq 'reality-gate' })[0]
Assert-Condition ($null -eq $rgSource.PSObject.Properties['featured'] -and $rgSource.proofStatus -eq 'withdrawn · historical record' -and $rgPage -match '<strong>Proof</strong> withdrawn · historical record' -and $rgPage -notmatch '<strong>Proof</strong> verified') 'Reality Gate carries no inert featured flag and no "Proof verified" pill'
$rgProofDesc = [regex]::Match($rgProof, '(?s)<article class="receipt-card" id="receipt-reality-gate".*?<p class="build-desc">(.*?)</p>').Groups[1].Value
Assert-Condition ($rgProofDesc -match 'no record that this website ever offered it for download' -and $rgProofDesc -notmatch 'not proven deployed') '/proof/ Reality Gate summary uses the plain v1.1.1 sentence'
$rgTf = [IO.File]::ReadAllText((Join-Path $publicDir 'truth-files\reality-gate\index.html'))
$rgReasonHtml = ([string]$rgM.release.withdrawalReason) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;'
Assert-Condition ($rgTf -match '<dt>Withdrawal</dt>' -and -not [string]::IsNullOrWhiteSpace($rgReasonHtml) -and $rgTf.Contains($rgReasonHtml) -and $rgTf -match 'Withdrawal date: not recorded') 'Reality Gate Truth File shows the recorded withdrawal reason and that no date is recorded'


# K3 (A-03, A-04): describe only the downloads this site offers.
$loSource = @($manifest.products | Where-Object { $_.id -eq 'lights-out' })[0]
$loUnofferedProp = $loSource.presentation.PSObject.Properties['unofferedArtifacts']
$loUnoffered = @(if ($loUnofferedProp) { $loUnofferedProp.Value | ForEach-Object { [int]$_ } })
Assert-Condition ($loUnoffered.Count -eq 1 -and $loUnoffered[0] -eq 1 -and @($loSource.artifacts).Count -eq 2 -and ([string]$loSource.artifacts[1].filename).EndsWith('.exe') -and [string]$loSource.artifacts[0].downloadUrl -eq [string]$loSource.downloadUrl) 'Lights Out presentation withholds only the recorded installer EXE (artifact 1); the offered download is the portable ZIP'
$siteRoutes = @(Get-ChildItem -LiteralPath $publicDir -Recurse -Filter '*.html' -File | Where-Object { $_.FullName -notmatch '[\\/]__(h14|preview)[\\/]' })
$withheldLinks = @()
foreach ($product in @($manifest.products)) {
  $prop = $product.presentation.PSObject.Properties['unofferedArtifacts']
  if (-not $prop) { continue }
  foreach ($index in @($prop.Value)) {
    $artifact = @($product.artifacts)[[int]$index]
    foreach ($route in $siteRoutes) {
      $text = [IO.File]::ReadAllText($route.FullName)
      if (($artifact.downloadUrl -and $text.Contains('href="' + [string]$artifact.downloadUrl + '"')) -or $text -match ('href="[^"]*' + [regex]::Escape([string]$artifact.filename))) { $withheldLinks += "$($route.Directory.Name):$($product.id)[$index]" }
    }
  }
}
Assert-Condition ($siteRoutes.Count -eq 25 -and $withheldLinks.Count -eq 0) "no published route links a recorded file the site does not offer (found: $($withheldLinks -join ', '))"
$loOnboarding = [regex]::Match($loHtml, '(?s)<dl class="onboarding-list">.*?</dl>').Value
Assert-Condition ($loOnboarding -match 'download the portable ZIP' -and $loOnboarding -notmatch '(?i)installer|\bEXE\b|\bAPK\b|Android Settings') 'Lights Out install, update and uninstall describe only the portable ZIP the site offers'
Assert-Condition ($loHtml -match 'Also listed in SHA256SUMS\.txt \(not offered here\)' -and $loHtml -match 'This site does not offer that file' -and $loHtml -match 'also lists an unsigned installer EXE that this site does not offer' -and $loHtml -notmatch '(?i)download the installer EXE|installer EXE or the portable ZIP|installer EXE and the portable ZIP are both') 'Lights Out names the installer EXE only as a listed file the site does not offer'
$custodyLimits = @($manifest.products | ForEach-Object { @($_.limits) } | Where-Object { $_ } | ForEach-Object { $_ -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;' })
$publicCompanionClaims = @()
foreach ($route in $siteRoutes) {
  $text = [IO.File]::ReadAllText($route.FullName)
  foreach ($limit in $custodyLimits) { $text = $text.Replace($limit, '') }
  if ($text -match '(?i)public Android companion') { $publicCompanionClaims += $route.Directory.Name }
}
Assert-Condition ($publicCompanionClaims.Count -eq 0) "website-authored copy no longer calls an unpublished Android companion public; custody-pinned limits keep their wording (found: $($publicCompanionClaims -join ', '))"
$loCompanion = [regex]::Escape('v' + [string]$loTruthJson.release.companionPublicVersion)
$noCompanionDownload = 'This site offers no Android companion download\.'
$recordSentence = "The release record lists Android companion $loCompanion but publishes no companion file or checksum\."
$loSupportCard = [regex]::Match($supportPage, '(?s)<article class="detail-card">\s*<h3><a href="/lights-out/">.*?</article>').Value
$loRoadmap = [regex]::Match($roadmapPage, '(?s)<article>\s*<div>\s*<p class="kicker">[^<]*</p>\s*<h2><a href="/lights-out/">.*?</article>').Value
Assert-Condition ($loHtml -match $noCompanionDownload -and $loHtml -match $recordSentence -and $loSupportCard -match $noCompanionDownload -and $loSupportCard -match $recordSentence -and $loRoadmap -match $noCompanionDownload -and $loRoadmap -match $recordSentence) 'Lights Out page, support and roadmap say the site offers no Android companion download and the record publishes no companion file'
$entriesWithKey = @($registryJson.products | Where-Object { $_.PSObject.Properties['unofferedArtifacts'] })
Assert-Condition ($entriesWithKey.Count -eq 1 -and $entriesWithKey[0].id -eq 'lights-out' -and (@($entriesWithKey[0].unofferedArtifacts) -join ',') -eq '1') 'proof registry carries the withheld-file index for the homepage inspector, for Lights Out only'
$homePage = Get-Content (Join-Path $publicDir 'index.html') -Raw -Encoding UTF8
$loTf = Get-Content (Join-Path $publicDir 'truth-files\lights-out\index.html') -Raw -Encoding UTF8
$cvCompanionPlain = 'companion ' + [regex]::Escape('v' + [string]$cvSource.release.companionPublicVersion)
Assert-Condition ($homePage -match "companion $loCompanion not offered here" -and $loTf -match "Companion $loCompanion · not offered here" -and $homePage -match $cvCompanionPlain -and $homePage -notmatch "$cvCompanionPlain not offered here") 'homepage and Truth File call the Lights Out companion version not offered here; the offered Cache Vault companion version stays plain'

# K4 (A-05, A-11): authored verification words are scoped to their evidence.
$dot = [char]0x00B7
$rec = @{}; foreach ($p in @($manifest.products)) { $rec[[string]$p.id] = $p }
# R1 + pinned wording
$k4Pills = [ordered]@{
  'cache-vault' = "SHA-256 published $dot hosted CI failed"; 'lights-out' = "First-party qualification $dot unsigned"
  'cleanroom' = "SHA-256 published $dot no release receipt"; 'ghostlayer' = "Owner-stamped receipt $dot unsigned"
  'forgecast' = "SHA-256 published $dot production-signed APK"; 'proofshot' = "Licensing finding open $dot unsigned" }
$pillProblems = @()
foreach ($p in @($manifest.products | Where-Object { $_.visible })) {
  $page = Get-Content (Join-Path $publicDir ($p.route.Trim('/') + '\index.html')) -Raw -Encoding UTF8
  $m = [regex]::Match($page, '<span class="proof-pill"><strong>Proof</strong> ([^<]*)</span>')
  $shown = if ($m.Success) { [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) } else { $null }
  if ($shown -cne [string]$p.proofStatus -or $shown -match '(?i)\bverified\b') { $pillProblems += $p.id }
  if ($k4Pills.Contains($p.id) -and [string]$p.proofStatus -cne $k4Pills[$p.id]) { $pillProblems += "$($p.id):wording" }
}
Assert-Condition ($pillProblems.Count -eq 0) "K4: every product Proof pill renders its authored status and none says 'verified' ($($pillProblems -join ', '))"
# R2 record backing for the pill words
$unsignedOk = $true; foreach ($id in @('lights-out','ghostlayer','proofshot')) { if (@($rec[$id].artifacts | Where-Object { $_.signingStatus -ne 'UNSIGNED' }).Count -gt 0) { $unsignedOk = $false } }
Assert-Condition (@($rec['cache-vault'].tests | Where-Object { ([string]$_.result).StartsWith('FAILED') }).Count -ge 1 -and $null -eq $rec['cleanroom'].verification.receiptUrl -and $null -eq $rec['lights-out'].verification.receiptUrl -and [string]$rec['forgecast'].artifacts[0].signingStatus -ceq 'PRODUCTION_SIGNED' -and @($rec['proofshot'].limits | Where-Object { $_ -match 'licensing-authority finding remains unresolved' }).Count -ge 1 -and $unsignedOk) 'K4: each Proof pill word is backed by the release record (CI failure, no receipt, signing state, open finding)'
# R3 one Cleanroom candidate string, backed by the record
$crSource = $rec['cleanroom']
$crProp = $crSource.PSObject.Properties['candidateStatus']
$crExpected = 'Candidate v' + [string]$crSource.release.candidateVersion + ' is on hold and is not an authorized public release.'
$crModel = @((Get-Content (Join-Path $PSScriptRoot '..\release-truth.json') -Raw -Encoding UTF8 | ConvertFrom-Json).products | Where-Object { $_.id -eq 'cleanroom' })[0]
$crChannel = @($crModel.channels | Where-Object { $_.track -eq 'CANDIDATE' })[0]
Assert-Condition ($crProp -and [string]$crProp.Value -ceq $crExpected -and $crChannel.publicationState -eq 'CANDIDATE' -and $null -eq $crChannel.publishedAt -and $crChannel.verification.qualificationState -eq 'NOT_ESTABLISHED' -and $crChannel.verification.note -match 'on hold') 'K4: Cleanroom carries one candidate status string, and the record backs it (on hold, not established, never published)'
# R4 the string reaches every candidate surface
$crPage = Get-Content (Join-Path $publicDir 'cleanroom\index.html') -Raw -Encoding UTF8
$crTf = [System.Net.WebUtility]::HtmlDecode((Get-Content (Join-Path $publicDir 'truth-files\cleanroom\index.html') -Raw -Encoding UTF8))
$crCard = [regex]::Match($softwarePage, '(?s)<article class="product-card card-cleanroom"[^>]*>.*?</article>').Value
$crSupport = [regex]::Match($supportPage, '(?s)<article class="detail-card">\s*<h3><a href="/cleanroom/">.*?</article>').Value
$crRoadmap = [regex]::Match($roadmapPage, '(?s)<article>\s*<div>\s*<p class="kicker">[^<]*</p>\s*<h2><a href="/cleanroom/">.*?</article>').Value
$crMissing = @()
if (([regex]::Matches($crPage, [regex]::Escape($crExpected))).Count -lt 6) { $crMissing += '/cleanroom/' }   # meta, og, download, update, established, release note
if (-not $crCard.Contains('<p class="card-detail">' + $crExpected + '</p>')) { $crMissing += '/software/' }
if (-not $crSupport.Contains($crExpected)) { $crMissing += '/support/' }
if (-not $crRoadmap.Contains($crExpected) -or $crRoadmap -match '\bNext\b') { $crMissing += '/roadmap/' }
if (-not $crTf.Contains('<span class="tf-sub">' + $crExpected + '</span>')) { $crMissing += '/truth-files/cleanroom/' }
Assert-Condition ($crMissing.Count -eq 0) "K4: the Cleanroom candidate string is what every candidate surface says ($($crMissing -join ', '))"
# R5 no second candidate wording anywhere
$k4Second = @(Get-ChildItem -LiteralPath $publicDir -Recurse -Filter '*.html' | Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8) -match '(?i)next build|in evaluation|newer verified release|v1\.0\.10\)? (?:is )?in progress|work on v1\.0\.10' } | ForEach-Object { $_.Name })
Assert-Condition ($k4Second.Count -eq 0) "K4: no second Cleanroom candidate wording (next build, in progress, in evaluation, newer verified release) remains ($($k4Second -join ', '))"
# R6 v1.0.7 limitation and qualified user-file claims, tied to the record
$crV = 'v' + [string]$crSource.release.publicVersion
$crQual = 'as described by Proof Foundry for ' + $crV + '; no release receipt is published'
Assert-Condition ($null -eq $crSource.verification.receiptUrl -and -not $crSource.release.PSObject.Properties['sourceCommit'] -and $crPage.Contains('No release receipt or source commit is published for ' + $crV + '.') -and $crPage.Contains('exact one-click restoration, ' + $crQual) -and $crPage.Contains('explicitly purged by the operator, ' + $crQual) -and $crTf.Contains('custody checks, and rollback, ' + $crQual) -and ($crPage + $rgProof) -notmatch '(?i)provenance attested') 'K4: Cleanroom states that v1.0.7 has no published receipt or source commit, and its user-file claims carry that qualifier'
# R7 Lights Out
$loText = [System.Net.WebUtility]::HtmlDecode($loHtml)
Assert-Condition ($loText.Contains('the installer and the portable build each matched all 614 files recorded in the build manifest') -and $loText.Contains('This is first-party evidence — not an independent or security certification') -and $loText.Contains('No Reality Gate receipt is published for v11.2.0') -and $loHtml -notmatch '(?i)20-step|independently verified|cryptographically signed|live physical-phone' -and @(@('342c11bc-d2d6-4918-8920-a495211ff69b','6323d762-859a-4385-91d7-923cd1bc1610','adff2359-3350-4d6d-9e04-74c295003c58') | Where-Object { -not $loHtml.Contains($_) }).Count -eq 0) "K4: Lights Out scopes v11.2.0 qualification to the release's first-party record, keeps the three historical receipt IDs as text, and claims no independent certification"
# R8 ProofShot
$psText = [System.Net.WebUtility]::HtmlDecode($psHtml)
$psCustody = "a release manifest that names Proof Foundry's internal Reality Gate receipts (the receipts are not published)"
$psVerifier = "with the verifier included in the proof bundle (ProofShot's own code)"
$psTf = [System.Net.WebUtility]::HtmlDecode((Get-Content (Join-Path $publicDir 'truth-files\proofshot\index.html') -Raw -Encoding UTF8))
Assert-Condition ($psText.Contains('a release-time adversarial gate (operator not published) reported green') -and ([regex]::Matches($psText, [regex]::Escape($psCustody))).Count -ge 3 -and [System.Net.WebUtility]::HtmlDecode($roadmapPage).Contains($psCustody) -and ([regex]::Matches($psText, [regex]::Escape($psVerifier))).Count -ge 2 -and $psTf.Contains($psVerifier) -and $psText -notmatch '(?i)independent adversarial|custody receipts|without trust') 'K4: ProofShot names its unpublished Reality Gate receipts, its unnamed gate operator and its own bundled verifier'
# R9 /proof/ state guide
$proofText = [System.Net.WebUtility]::HtmlDecode($rgProof)
Assert-Condition ($proofText.Contains('they are not independent certification') -and $proofText.Contains('A SHA-256 hash shows file identity, not safety.') -and $rgProof -notmatch 'validated against published evidence or gate checks|does not invalidate separately verified dimensions') 'K4: the /proof/ state guide describes the authored record, not validation or certification'
# R10 authored presentation strings (covers data-only surfaces such as /proof/ build-desc and JSON)
$rawPresentation = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$presentationHits = @()
foreach ($p in @($rawPresentation.products)) {
  $strings = @()
  foreach ($f in @('summary','cardSummary','description','build','releaseNote','proofStatus','testStatus','testCount','candidateStatus','distType')) { $prop = $p.PSObject.Properties[$f]; if ($prop -and $prop.Value -is [string]) { $strings += $prop.Value } }
  $pres = $p.PSObject.Properties['presentation']
  if ($pres -and $pres.Value) { foreach ($q in $pres.Value.PSObject.Properties) { if ($q.Value -is [string]) { $strings += $q.Value } } }
  if (@($strings | Where-Object { $_ -match '(?i)independently verified|independent adversarial|custody receipts|without trust|\baudited\b|provenance attested' }).Count -gt 0) { $presentationHits += $p.id }
}
Assert-Condition ($presentationHits.Count -eq 0) "K4: authored presentation strings carry no unbacked independence, custody or audit wording ($($presentationHits -join ', '))"

# K5 (A-06): derived states come only from recorded evidence.
$k5Words = $manifest.labels
$k5Proof = Get-Content (Join-Path $publicDir 'proof\index.html') -Raw -Encoding UTF8
$k5Home = Get-Content (Join-Path $publicDir 'index.html') -Raw -Encoding UTF8
$k5Em = [string][char]0x2014
$k5Rg = [string]$manifest.verificationLabels.REALITY_GATE
foreach ($k5p in @($manifest.products | Where-Object { $_.visible })) {
  $k5Card = [regex]::Match($k5Proof, '(?s)<article class="receipt-card" id="receipt-' + [regex]::Escape($k5p.id) + '".*?</article>').Value
  Assert-Condition ($k5Card.Length -gt 0 -and $k5Card -cnotmatch '>AUTHORIZED<|<dt>Release authority</dt>|>Next v|<strong>Next</strong>') "$($k5p.id): /proof/ derives no release authority and no 'Next' label"
  $k5Page = Get-Content (Join-Path $publicDir (($k5p.route.Trim('/') -replace '/', '\') + '\index.html')) -Raw -Encoding UTF8
  $k5Pill = if ($k5p.verification.verifiedAt) { '<strong>' + [regex]::Escape($k5Words.releaseReportStamp) + '</strong> ' + [regex]::Escape($k5p.verification.verifiedAt) } else { '' }
  Assert-Condition ($k5Page -cnotmatch '<strong>(Verified|Next)</strong>' -and (-not $k5Pill -or $k5Page -cmatch $k5Pill)) "$($k5p.id): product proof strip dates the release report and never says Verified or Next"
  if ($k5p.release.releaseStatus -eq 'WITHDRAWN') {
    $k5Line = [regex]::Escape("$($k5Words.withdrawnVersionCell) v$($k5p.release.withdrawnVersion) $k5Em $($k5Words.withdrawnChecks)")
    $k5Cell = [regex]::Escape("<dd>$($k5Words.withdrawnVersionCell) (v$($k5p.release.withdrawnVersion))</dd>")
    Assert-Condition ($k5Card -cnotmatch 'verification-matrix' -and $k5Card -cmatch $k5Line -and $k5Card -cmatch $k5Cell -and $k5Card -cnotmatch '>Unreleased<') "$($k5p.id): withdrawn release has one historical line and a withdrawn version cell, no matrix"
    $k5Row = [regex]::Match($k5Home, '(?s)<tr data-ledger-product="' + [regex]::Escape($k5p.id) + '".*?</tr>').Value
    Assert-Condition ($k5Row -cmatch ('<span class="ledger-status">' + [regex]::Escape([System.Net.WebUtility]::HtmlEncode($k5Words.withdrawnHomeStatus)) + '</span>') -and $k5Row -cnotmatch '>WITHDRAWN<') "$($k5p.id): Home index row says withdrawn, record only, in words"
    continue
  }
  $k5Classes = if ($k5p.presentation.PSObject.Properties['evidenceClass']) { $k5p.presentation.evidenceClass } else { $null }
  $k5State = @{}
  foreach ($k5d in @('ARTIFACT_CUSTODY', 'RUNTIME_VALIDATION', 'REALITY_GATE')) {
    $k5c = if ($k5Classes -and $k5Classes.PSObject.Properties[$k5d]) { [string]$k5Classes.$k5d } else { 'NONE' }
    $k5State[$k5d] = if (@($k5p.verification.verificationType) -notcontains $k5d) { 'PENDING' } elseif ($k5c -ceq 'PUBLISHED_RECEIPT') { 'VERIFIED' } elseif (@('MANIFEST_ONLY', 'OWNER_STAMPED_UNPUBLISHED', 'ID_ONLY') -contains $k5c) { 'NOT_PUBLISHED' } else { 'PENDING' }
    $k5m = [regex]::Match($k5Card, '<dt>' + [regex]::Escape([string]$manifest.verificationLabels.$k5d) + '</dt><dd class="status-[a-z-]+">([^<]*)</dd><dd class="matrix-evidence">')
    Assert-Condition ($k5m.Success -and $k5m.Groups[1].Value -ceq $k5State[$k5d]) "$($k5p.id): $k5d reads $($k5State[$k5d]) from evidence class $k5c and states its evidence"
  }
  $k5Stamp = if ($k5State['REALITY_GATE'] -ceq 'VERIFIED') { "$k5Rg verified" } elseif ($k5State['ARTIFACT_CUSTODY'] -ceq 'VERIFIED') { $k5Words.artifactVerifiedStamp } else { $k5Words.releaseReportStamp }
  Assert-Condition ($k5Card -cnotmatch '<dt>Public download</dt><dd class="status-[a-z-]+">VERIFIED<' -and (-not $k5p.verification.verifiedAt -or $k5Card.Contains("$k5Stamp $k5Em $($k5p.verification.verifiedAt)")) -and ($k5State['REALITY_GATE'] -ceq 'VERIFIED' -or -not $k5Card.Contains("$k5Rg verified"))) "$($k5p.id): public download is PUBLISHED at most and the date stamp names only a VERIFIED check"
}

# 10. Captions match their images (A-12, K8). Each rewritten figure is bound to its own image by a
# unique marker, and captions that their pictures contradict may not return on any route or in the
# tour data. ASCII-only source: the middle dot is built from its code point.
$a12Dot = [string][char]0x00B7
function Read-A12Decoded([string]$path) { return [System.Net.WebUtility]::HtmlDecode([IO.File]::ReadAllText($path)) }
function Get-A12Figure([string]$html, [string]$marker) {
    return [regex]::Match($html, '(?s)<figure\b(?:(?!</figure>).)*?' + [regex]::Escape($marker) + '.*?</figure>').Value
}
$a12Bindings = @(
    @{ Route = 'lights-out'; Marker = 'hero-product-shot'; Src = '/assets/lights-out/tonight-active-hero.png'; Need = @("CAPTURED $a12Dot Lights Out v11.1.2 dry run") },
    @{ Route = 'lights-out'; Marker = 'aria-labelledby="shot-firstlight-cap"'; Src = '/assets/lights-out/settings-first-light-automations.png'; Need = @('both switched off', "CAPTURED $a12Dot Lights Out v11.1.2") },
    @{ Route = 'lights-out'; Marker = 'aria-labelledby="shot-devices-cap"'; Src = '/assets/lights-out/devices-panel.png'; Need = @('nothing connected yet', "CAPTURED $a12Dot Lights Out v11.1.2 dry run") },
    @{ Route = 'lights-out'; Marker = 'aria-labelledby="shot-lights-cap"'; Src = '/assets/lights-out/settings-smart-lights.png'; Need = @('not yet configured', "CAPTURED $a12Dot Lights Out v11.1.2") },
    @{ Route = 'lights-out'; Marker = 'aria-labelledby="shot-wifi-cap"'; Src = '/assets/lights-out/settings-wifi-guard.png'; Need = @('switched off', 'provider choices are not shown', "CAPTURED $a12Dot Lights Out v11.1.2") },
    @{ Route = 'lights-out'; Marker = 'aria-labelledby="shot-proof-cap"'; Src = '/assets/lights-out/proof-morning-visible.png'; Need = @('not Morning Proof results', "CAPTURED $a12Dot Lights Out v11.1.2") },
    @{ Route = 'cleanroom'; Marker = 'hero-product-shot'; Src = '/assets/cleanroom/cleanroom-review.png'; Need = @('no cleanup candidates found', 'Interface capture from v1.0.6') },
    @{ Route = 'forgecast'; Marker = 'href="/assets/forgecast/v030-widgets.png"'; Src = '/assets/forgecast/v030-widgets.png'; Need = @('not the Android home screen', 'build not shown') },
    @{ Route = 'proofshot'; Marker = 'aria-labelledby="shot-decode-cap"'; Src = '/assets/proofshot/decode-complete.png'; Need = @('HyperSnatch', 'welcome panel covers the workspace') },
    @{ Route = 'proofshot'; Marker = 'aria-labelledby="shot-plan-cap"'; Src = '/assets/proofshot/candidates-plan.png'; Need = @('HyperSnatch', 'no candidate rows or plan are visible') },
    @{ Route = 'cache-vault'; Marker = 'film-shot'; Src = '/assets/cache-vault/cache_vault_trailer.mp4'; Need = @('Recorded from the v0.2.4 Windows release line', 'edited from two recording sessions', 'no build number appears on screen') }
)
foreach ($b in $a12Bindings) {
    $page = Read-A12Decoded (Join-Path $publicDir "$($b.Route)\index.html")
    $fig = Get-A12Figure $page $b.Marker
    $cap = [regex]::Match($fig, '(?s)<figcaption[^>]*>(.*?)</figcaption>').Groups[1].Value
    $missing = @($b.Need | Where-Object { -not $cap.Contains($_) })
    Assert-Condition ($fig.Contains($b.Src) -and $cap.Length -gt 0 -and $missing.Count -eq 0) "A-12: /$($b.Route)/ $([IO.Path]::GetFileName($b.Src)) caption describes what its frame shows"
}
$rgA12 = Read-A12Decoded (Join-Path $publicDir 'reality-gate\index.html')
$rgRecoveryCaption = [regex]::Match($rgA12, 'data-title="Recovery" data-caption="([^"]*)"').Groups[1].Value
Assert-Condition ($rgRecoveryCaption.Contains('AT RISK') -and $rgRecoveryCaption.Contains('no recovery drill receipt is recorded')) 'A-12: Reality Gate Recovery gallery caption states the frame (backup AT RISK, no drill receipt recorded)'
$rgTourCaption = [regex]::Match($rgA12, '<figcaption data-tour-caption[^>]*>([^<]*)</figcaption>').Groups[1].Value
Assert-Condition ($rgTourCaption.Contains('continuity status') -and -not $rgTourCaption.Contains('dependencies')) 'A-12: Reality Gate tour opening caption shows continuity status and claims no dependency view'
$a12Prefix = 'const products = '
$a12ExpLine = @(Get-Content (Join-Path $publicDir 'experience.js') -Encoding UTF8 | Where-Object { $_.StartsWith($a12Prefix) }) | Select-Object -First 1
$a12RgTour = @()
if ($a12ExpLine) { $a12RgTour = @(($a12ExpLine.Substring($a12Prefix.Length).TrimEnd(';') | ConvertFrom-Json).'reality-gate'.tour) }
Assert-Condition ($a12RgTour.Count -eq 4 -and $a12RgTour[0].description -ceq $rgTourCaption -and $a12RgTour[2].description -ceq $rgRecoveryCaption -and $a12RgTour[2].image.alt.Contains('AT RISK')) 'A-12: Reality Gate tour data mirrors the page captions for Orient and Recover'
$a12HomeCard = [regex]::Match([IO.File]::ReadAllText((Join-Path $publicDir 'index.html')), '(?s)<article class="ledger-instrument" data-ledger-feature="lights-out".*?</article>').Value
Assert-Condition ($a12HomeCard.Contains('src="/assets/lights-out/tonight-active-hero.png"') -and -not $a12HomeCard.Contains('tonight-active-hero-card-960')) 'A-12: Home Lights Out card shows the full-frame capture, not the crop that cut its build stamp'
$a12SoftwareCard = [regex]::Match([IO.File]::ReadAllText((Join-Path $publicDir 'software\index.html')), '(?s)<article class="product-card[^>]*data-product="lights-out".*?</article>').Value
Assert-Condition ($a12SoftwareCard.Contains('src="/assets/lights-out/tonight-active-hero.png"') -and -not $a12SoftwareCard.Contains('tonight-active-hero-card-960')) 'A-12: Software Lights Out card shows the full-frame capture, build stamp included'
$a12Retired = @(
    'Morning Proof on the desktop', 'showing Morning Proof results', 'The Automations settings category',
    'every surface Lights Out can talk to', 'provider selection and test-connection gate',
    'TP-Link, ASUS, Netgear, webhook, or local adapter', 'real Android home screen', 'Android home-screen widgets',
    'Recorded bundle details, with their stated outcome', 'recorded recovery drill and bundle details',
    'its dependencies and continuity status', 'cleanup candidates and archive actions',
    'showing scan results and archive actions', 'two scored candidates', 'Two scored candidates',
    'The Workbench intake panel after', 'with the sample workspace panel', 'What you see below is a real SmartDecode run',
    'proving bundle integrity, and drilling recovery', 'bundle integrity check and recovery drill'
)
$a12Hits = @()
foreach ($f in @(Get-ChildItem -Path $publicDir -Recurse -File -Include 'index.html', 'experience.js')) {
    $t = Read-A12Decoded $f.FullName
    foreach ($r in $a12Retired) { if ($t.Contains($r)) { $a12Hits += "$($f.Directory.Name)/$($f.Name): $r" } }
}
Assert-Condition ($a12Hits.Count -eq 0) ("A-12: no retired caption or alt text that its picture contradicts is published" + $(if ($a12Hits.Count -gt 0) { ' (' + ($a12Hits -join '; ') + ')' } else { '' }))

$resultColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "`n=== RESULT: $passed passed, $failed failed ===" -ForegroundColor $resultColor
if ($failed -gt 0) { exit 1 }
