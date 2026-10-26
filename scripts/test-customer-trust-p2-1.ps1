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
$footerHtml = [regex]::Match($homeHtml, '(?s)<footer\b.*?</footer>').Value
Assert-Condition ($footerHtml -match '<nav\b[^>]*aria-label="Footer"[^>]*>[\s\S]*?<a href="/support/">Support</a>') "Footer nav contains link to /support/"

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

# 5. Report Section — Operational Support Intake
Assert-Condition ($supportHtml -match 'href="mailto:support@theprooffoundry\.com"') "/support/ publishes verified support@theprooffoundry.com mailto link"
Assert-Condition ($supportHtml -match 'href="mailto:security@theprooffoundry\.com"') "/support/ publishes verified security@theprooffoundry.com mailto link"
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
$supportPromiseFound = $false
$channelPlaceholderFound = $false

foreach ($f in $allHtmlFiles) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($content -match 'when it is safe to click Run Anyway') { $runAnywayFound = $true }
    if ($content -match 'checksum proves the file is safe') { $provesSafeFound = $true }
    if ($content -match 'SHA-256 proves authenticity') { $provesAuthFound = $true }
    if ($content -match 'Talk to support|contact the project') { $supportPromiseFound = $true; Write-Host "Forbidden support promise in $($f.Name)" -ForegroundColor Red }
    if ($content -match '\[[^\]<>]{0,80}(channel|address|contact|e-?mail)[^\]<>]{0,80}\]') { $channelPlaceholderFound = $true; Write-Host "Forbidden channel placeholder in $($f.Name)" -ForegroundColor Red }
}

Assert-Condition (-not $runAnywayFound) "Deny 'when it is safe to click Run Anyway' across all generated HTML"
Assert-Condition (-not $provesSafeFound) "Deny 'checksum proves the file is safe' across all generated HTML"
Assert-Condition (-not $provesAuthFound) "Deny unqualified 'SHA-256 proves authenticity' across all generated HTML"
Assert-Condition (-not $supportPromiseFound) "Deny 'Talk to support' and 'contact the project' across all generated HTML (no support channel is published)"
Assert-Condition (-not $channelPlaceholderFound) "Deny bracketed support or security channel placeholders across all generated HTML"

# 7. Checksum Vocabulary & Byte-Identity Standard
Assert-Condition ($supportHtml -match 'SHA-256 match = byte-identity verification against the published digest') "/support/ defines SHA-256 match standard"
Assert-Condition ($supportHtml -match 'The 8-Field Checksum Identity Schema') "/support/ explains the 8-field checksum identity schema"

# 8. Lights Out Dead-End Link Fix
$loHtml = Get-Content (Join-Path $publicDir "lights-out\index.html") -Raw -Encoding UTF8
Assert-Condition ($loHtml -match '<a href="/support/#report">see the support guide</a>' -and $loHtml -notmatch 'contact the project') "Lights Out mismatch link points to /support/#report and names the support guide, not a contact channel"

# 9. P1 Regression Assertions
$rgHtml = Get-Content (Join-Path $publicDir "reality-gate\index.html") -Raw -Encoding UTF8
Assert-Condition ($rgHtml -match '(?s)First-Class CLI &amp; Instance Discovery \(RG-05\).*?Branch Qualified') "P1 Regression: Reality Gate RG-05 remains Branch Qualified"

$cvHtml = Get-Content (Join-Path $publicDir "cache-vault\index.html") -Raw -Encoding UTF8
Assert-Condition ($cvHtml -match 'available from Proof Foundry downloads') "P1 Regression: Cache Vault download availability notice intact"

Assert-Condition ($loHtml -notmatch '/reports/deploy-receipts/2026-06-30-proof-foundry-site.md') "P1 Regression: Lights Out old deployment receipt link remains absent"

$registryJson = Get-Content (Join-Path $publicDir "proof\index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$loRegistry = $registryJson.products | Where-Object { $_.id -eq 'lights-out' }
Assert-Condition ($loRegistry.release.releaseStatus -eq 'PUBLIC_RELEASE') "P1 Regression: Lights Out release status is PUBLIC_RELEASE"

# 10. Hardened Support Release-Truth Parity Assertions
Assert-Condition ($supportHtml -match 'Reality Gate[\s\S]*?v1\.1\.0') "Support release truth: Reality Gate v1.1.0"
Assert-Condition ($supportHtml -match 'Cache Vault[\s\S]*?Public Windows v0\.3\.1') "Support release truth: Cache Vault public Windows v0.3.1"
Assert-Condition ($supportHtml -notmatch 'v0\.2\.3-rc') "Support release truth: no RC candidate strings for Cache Vault"
$loSupportCard = [regex]::Match($supportHtml, '(?s)<article class="detail-card">\s*<h3><a href="/lights-out/">.*?</article>').Value
Assert-Condition ((-not [string]::IsNullOrWhiteSpace($loSupportCard)) -and ($loSupportCard -match 'Public Windows v11\.1\.3 available[\s\S]*?Android companion v11\.1\.1') -and ($loSupportCard -notmatch 'on hold|currently unavailable|candidates? on')) "Support release truth: Lights Out public release, companion parity and download availability agree"
Assert-Condition ($supportHtml -match 'Cleanroom[\s\S]*?v1\.0\.7[\s\S]*?v1\.0\.10') "Support release truth: Cleanroom v1.0.7 / candidate v1.0.10"
Assert-Condition ($supportHtml -notmatch 'Cleanroom[\s\S]*?v1\.2\.0') "Support release truth: Cleanroom rejects incorrect v1.2.0"
Assert-Condition ($supportHtml -notmatch 'Cleanroom[\s\S]*?v1\.3\.0') "Support release truth: Cleanroom rejects incorrect v1.3.0"
Assert-Condition ($supportHtml -match 'GhostLayer[\s\S]*?v0\.4\.0') "Support release truth: GhostLayer v0.4.0"
Assert-Condition ($supportHtml -notmatch 'GhostLayer[\s\S]*?v1\.0\.0') "Support release truth: GhostLayer rejects incorrect v1.0.0"
Assert-Condition ($supportHtml -match 'ForgeCast[\s\S]*?v0\.3\.5') "Support release truth: ForgeCast v0.3.5"
Assert-Condition ($supportHtml -match 'ProofShot[\s\S]*?Public Windows v2\.0\.0' -and $supportHtml -notmatch 'no public release package') "Support release truth: ProofShot public Windows v2.0.0"

# 10b. Help-and-safety copy (K13): verified email intake published, no unfulfilled promises, signing sentence bound to release record
$helpSafety = [regex]::Match($supportHtml, '(?s)<section class="support-section" id="help-safety">.*?</section>').Value
$windowsDownloads = @($registryJson.products | ForEach-Object { @($_.artifacts) } | Where-Object { $null -ne $_ -and [string]$_.platform -match 'Windows' -and -not [string]::IsNullOrWhiteSpace([string]$_.downloadUrl) })
$windowsNotUnsigned = @($windowsDownloads | Where-Object { [string]$_.signingStatus -cne 'UNSIGNED' })
Assert-Condition ((-not [string]::IsNullOrWhiteSpace($helpSafety)) -and $helpSafety -match 'Need help or found a security issue\?' -and $helpSafety -match 'support@theprooffoundry\.com' -and $helpSafety -match 'security@theprooffoundry\.com' -and $helpSafety -match 'do not offer live chat' -and $helpSafety -notmatch '24/7 support' -and $helpSafety -match 'Each Windows download offered on this site is not code-signed, according to its release record\.' -and $helpSafety -match 'it is not a guarantee of safety or an independent certification' -and $helpSafety -notmatch 'may lack an Authenticode' -and $windowsDownloads.Count -gt 0 -and $windowsNotUnsigned.Count -eq 0) "/support/ help-and-safety block publishes verified email intake without live promises, and its not-code-signed sentence matches every Windows artifact's UNSIGNED release record"

# 10c. Security disclosure verification (RFC 9116)
$securityTxtPath = Join-Path $publicDir ".well-known\security.txt"
Assert-Condition (Test-Path $securityTxtPath) "Generated /.well-known/security.txt route exists"
$secTxt = Get-Content $securityTxtPath -Raw -Encoding UTF8
Assert-Condition ($secTxt -match '(?m)^Contact:\s*mailto:security@theprooffoundry\.com$') "security.txt contains valid Contact mailto: URI"
$expiresMatch = [regex]::Match($secTxt, '(?m)^Expires:\s*(\S+)$')
$expiresValid = $false
if ($expiresMatch.Success) {
    try {
        $expDate = [DateTime]::Parse($expiresMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        $now = [DateTime]::UtcNow
        $expiresValid = ($expDate -gt $now) -and ($expDate -le $now.AddDays(366))
    } catch { $expiresValid = $false }
}
Assert-Condition $expiresValid "security.txt contains valid future Expires timestamp within 1 year"
$headersContent = Get-Content (Join-Path $publicDir "_headers") -Raw -Encoding UTF8
Assert-Condition ($headersContent -match '(?m)^/\.well-known/security\.txt\s*\r?\n\s+Content-Type:\s*text/plain;\s*charset=utf-8') "_headers serves /.well-known/security.txt as UTF-8 text/plain"
$redirectsContent = Get-Content (Join-Path $publicDir "_redirects") -Raw -Encoding UTF8
Assert-Condition ($redirectsContent -match '(?m)^/security\.txt\s+/\.well-known/security\.txt\s+301') "_redirects maps /security.txt to /.well-known/security.txt"
$androidSection = [regex]::Match($supportHtml, '(?s)<section class="[^"]*" id="android">.*?</section>').Value
Assert-Condition ($androidSection -match 'Phone-native verification steps are not published yet' -and $supportHtml -notmatch 'being prepared on the support hub') "/support/ Android guidance says phone-native steps are not published instead of pointing back to itself"

# 11. Hardened Global Navigation Parity Assertions across all generated surfaces
$allRoutes = @('', 'software', 'reality-gate', 'cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'proofshot', 'proof', 'roadmap', 'founders', 'support', 'about', 'proof-standard')
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
