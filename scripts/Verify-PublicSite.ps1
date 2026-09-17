param(
    [string]$Targets = "https://theprooffoundry.com,https://www.theprooffoundry.com,https://proof-foundry-site.pages.dev",
    [string]$ManifestPath,
    [string]$ReceiptPath
)

# ---------------------------------------------------------------------------
# Manifest-driven expectations
#
# Product version, download label, artifact hash, and release-state assertions
# are derived from site-manifest.json — the same authoritative source used by
# the site build — so the verifier cannot drift out of sync with the site.
# ---------------------------------------------------------------------------

# Parse the comma-separated target list into an array.  Using a single string
# parameter instead of [string[]] ensures correct binding from both `&` calls
# inside PowerShell and `powershell -File` invocations from the command line,
# where @(...) array literals are not parsed as arrays.
# A separate variable ($TargetUrls) is used because the [string] type
# constraint on $Targets would coerce an array back to a string.
$TargetUrls = $Targets -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) "site-manifest.json"
}
if (-not (Test-Path $ManifestPath)) {
    Write-Host "==> FATAL: site-manifest.json not found at $ManifestPath" -ForegroundColor Red
    exit 2
}
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

function Get-Product($id) {
    return $manifest.products | Where-Object { $_.id -eq $id } | Select-Object -First 1
}

function Get-PrimaryArtifact($p) {
    if ($p.artifacts) {
        foreach ($a in $p.artifacts) {
            if (-not [string]::IsNullOrWhiteSpace($a.sha256)) { return $a }
        }
    }
    return $null
}

function Get-StatusLabel($p) {
    if ($p.productStatus -and $manifest.statusTaxonomy.$($p.productStatus)) {
        return $manifest.statusTaxonomy.$($p.productStatus)
    }
    return $null
}

function Get-StateLabel($p) {
    if ($p.state -and $manifest.stateLabels.$($p.state)) {
        return $manifest.stateLabels.$($p.state)
    }
    return $null
}

function Esc($s) { return [regex]::Escape($s) }

# Derive per-product expectations from the manifest --------------------------

# Cache Vault — final public release: v0.2.3 (previous public v0.2.2; RC candidate lane closed)
$cv = Get-Product "cache-vault"
$cvArtifact = Get-PrimaryArtifact $cv
$cvStatusLabel = Get-StatusLabel $cv
$cvDownloadPattern = Esc $cv.downloadLabel
if ($cv.presentation.downloadUnavailable) {
    $cvDownloadPattern = 'Downloads currently unavailable'
}
$cvArtifactPattern = Esc $cvArtifact.filename
$cvSha256 = $cvArtifact.sha256

# Lights Out — active proof / on hold: public Windows v11.1.2, candidate v11.1.3
# Android public companion v11.1.1 (from release.companionPublicVersion)
$lo = Get-Product "lights-out"
$loPublicVer = "v$($lo.release.publicVersion)"
$loCandidateVer = "v$($lo.release.candidateVersion)"
$loCompanionPublicVer = "v$($lo.release.companionPublicVersion)"

# Cleanroom — public release: public v1.0.7, next/local v1.0.10
$cln = Get-Product "cleanroom"
$clnStatusLabel = Get-StatusLabel $cln
$clnDownloadPattern = Esc $cln.downloadLabel

# ForgeCast — public release v0.3.5, production-signed APK
$fc = Get-Product "forgecast"
$fcArtifact = Get-PrimaryArtifact $fc
$fcPublicVer = "v$($fc.release.publicVersion)"
$fcSha256 = $fcArtifact.sha256
$fcApkUrl = $fcArtifact.downloadUrl
$fcShaUrl = $fcArtifact.sha256Url
$fcTestStatus = $fc.testStatus

# Reality Gate — public release / developer pilot v1.1.0
$rg = Get-Product "reality-gate"
$rgArtifact = Get-PrimaryArtifact $rg
$rgSha256 = $rgArtifact.sha256
$rgStateLabel = Get-StateLabel $rg

# ProofShot — public release v2.0.0
$ps = Get-Product "proofshot"
$psStatusLabel = Get-StatusLabel $ps
$psPublicVer = $ps.release.publicVersion

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$script:failedCount = 0
$script:verifiedRoutes = @()
$curlCommand = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $curlCommand) { $curlCommand = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $curlCommand) { throw 'curl is required for public-site verification.' }
$script:CurlPath = $curlCommand.Source

function Write-Fail {
    param([string]$Message, [string]$Url)
    Write-Host "[FAIL] ($Message)" -ForegroundColor Red
    $script:failedCount++
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL ($Message)" }
}

function Write-Pass {
    param([string]$Message, [string]$Url, [int]$Status)
    Write-Host "[PASS] ($Message)" -ForegroundColor Green
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $Status; Msg = "PASS ($Message)" }
}

function Get-PlaintextContent {
    param([string]$Url)
    $contentLines = & $script:CurlPath -s -H "Cache-Control: no-cache" -L $Url
    return $contentLines -join "`n"
}

function Test-UrlContent {
    param(
        [string]$Url,
        [string]$Name = "",
        [string[]]$ContainsPatterns = @(),
        [string[]]$NotContainsPatterns = @(),
        [bool]$FollowRedirects = $true
    )
    $label = if ($Name) { " ($Name)" } else { "" }
    Write-Host "Checking content${label}: $Url (FollowRedirects=$FollowRedirects) ... " -NoNewline
    try {
        $curlArgs = @("-s", "-H", "Cache-Control: no-cache")
        if ($FollowRedirects) { $curlArgs += "-L" }
        $curlArgs += $Url
        $contentLines = & $script:CurlPath @curlArgs
        $content = $contentLines -join "`n"

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "[FAIL] (Empty response from curl)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL (Empty)" }
            return
        }

        foreach ($pattern in $ContainsPatterns) {
            if ($content -notmatch $pattern) {
                Write-Host "[FAIL] (Missing expected content: '$pattern')" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 200; Msg = "FAIL (Missing '$pattern')" }
                return
            }
        }
        foreach ($pattern in $NotContainsPatterns) {
            if ($content -match $pattern) {
                Write-Host "[FAIL] (Found forbidden content: '$pattern')" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 200; Msg = "FAIL (Found '$pattern')" }
                return
            }
        }
        Write-Host "[PASS]" -ForegroundColor Green
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 200; Msg = "PASS (Content)" }
    } catch {
        Write-Host "[FAIL] (Request exception: $_)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL (Exception)" }
    }
}

function Test-UrlRedirect {
    param(
        [string]$Url,
        [int[]]$ExpectedStatus = @(301, 308),
        [string]$ExpectedLocation = "/lights-out/"
    )
    Write-Host "Checking redirect headers: $Url ... " -NoNewline
    try {
        $headersText = & $script:CurlPath -s -H "Cache-Control: no-cache" -I $Url
        $headersString = $headersText -join "`n"

        if ($headersString -match "HTTP/\S+\s+(\d+)") {
            $status = [int]$Matches[1]
        } else { $status = 0 }

        if ($headersString -match "(?m)^[Ll]ocation:\s*(\S+)") {
            $location = $Matches[1].Trim()
        } else { $location = "" }

        if ($ExpectedStatus -notcontains $status) {
            Write-Host "[FAIL] (Expected status $($ExpectedStatus -join '/'), got $status)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Status)" }
            return
        }
        if ($location -ne $ExpectedLocation) {
            Write-Host "[FAIL] (Expected Location '$ExpectedLocation', got '$location')" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Location)" }
            return
        }
        Write-Host "[PASS] (Redirects correctly to $location)" -ForegroundColor Green
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "PASS (Redirect)" }
    } catch {
        Write-Host "[FAIL] (Exception: $_)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL (Exception)" }
    }
}

function Test-AssetHead {
    param(
        [string]$Url,
        [string]$Name = "asset",
        [string]$ExpectedContentType = "application/"
    )
    Write-Host "Checking asset HEAD ($Name): $Url ... " -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -Headers @{ "Cache-Control" = "no-cache" } -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $status = $response.StatusCode
        $contentType = $response.Headers['Content-Type']
    } catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $contentType = $_.Exception.Response.Headers['Content-Type']
        } else {
            Write-Fail "Request failed: $_" -Url $Url
            return
        }
    }
    if ($status -ne 200) { Write-Fail "Expected status 200, got $status" -Url $Url; return }
    if ($contentType -notlike "*$ExpectedContentType*") { Write-Fail "Expected Content-Type '$ExpectedContentType', got '$contentType'" -Url $Url; return }
    if ($contentType -like "*text/html*") { Write-Fail "Asset returned text/html (likely fallback to index.html)" -Url $Url; return }
    Write-Pass "$status $contentType" -Url $Url -Status $status
}

function Test-Asset {
    param([string]$Url, [string]$ExpectedContentType = "image/")
    Write-Host "Checking asset header & content: $Url ... " -NoNewline
    try {
        $headersText = & $script:CurlPath -s -H "Cache-Control: no-cache" -I $Url
        $headersString = $headersText -join "`n"
        if ($headersString -match "HTTP/\S+\s+(\d+)") { $status = [int]$Matches[1] } else { $status = 0 }
        if ($status -ne 200) {
            Write-Host "[FAIL] (Expected status 200, got $status)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Status)" }
            return
        }
        if ($headersString -match "(?m)^[Cc]ontent-[Tt]ype:\s*(\S+)") { $contentType = $Matches[1].Trim() } else { $contentType = "" }
        if ($contentType -notlike "*$ExpectedContentType*") {
            Write-Host "[FAIL] (Expected Content-Type matches '$ExpectedContentType', got '$contentType')" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Content-Type)" }
            return
        }
        $bodyLines = & $script:CurlPath -s -H "Cache-Control: no-cache" $Url
        $body = $bodyLines -join "`n"
        if ($body -match "<!doctype html>" -or $body -match "<html\b" -or $body -match "</html>") {
            Write-Host "[FAIL] (Asset request returned HTML content instead of binary data!)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Returned HTML)" }
            return
        }
        Write-Host "[PASS] (Content-Type: $contentType)" -ForegroundColor Green
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "PASS" }
    } catch {
        Write-Host "[FAIL] (Exception: $_)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL (Exception)" }
    }
}

# ---------------------------------------------------------------------------
# Run the assertions
# ---------------------------------------------------------------------------

Write-Host "==> Starting Public Site Hardened Verification via curl" -ForegroundColor Cyan
Write-Host "Targets: $($TargetUrls -join ', ')" -ForegroundColor Cyan
$manifestRelPath = $ManifestPath.Replace((Split-Path -Parent $PSScriptRoot) + [System.IO.Path]::DirectorySeparatorChar, '')
Write-Host "Manifest: $manifestRelPath" -ForegroundColor Cyan
Write-Host "ForgeCast APK URL: $fcApkUrl" -ForegroundColor Cyan
Write-Host "ForgeCast SHA URL: $fcShaUrl" -ForegroundColor Cyan

foreach ($target in $TargetUrls) {
    Write-Host "`n---> Testing target: $target"

    # 1. Homepage — global nav + full product family + card contract
    # H2: homepage-facing labels normalized to "Lights Out" / "ForgeCast";
    # canonical "ForgeCast Weather" remains asserted on the product/proof pages below.
    Test-UrlContent -Url "$target/" -ContainsPatterns @(
        "Reality Gate", "Lights Out", "Cache Vault", "Cleanroom",
        "ForgeCast", "ProofShot", "Proof Standard", "Explore the software"
    ) -NotContainsPatterns @("SkyFoundry")

    # 2. Lights Out — canonical route: feature checks + manifest-derived version truth
    Test-UrlContent -Url "$target/lights-out/" -Name "product truth" -ContainsPatterns @(
        "Wi-Fi Guard",
        "ForgeCast Weather",
        "Public Windows $(Esc $loPublicVer)",
        "candidate companion.*$(Esc $loCandidateVer)",
        "public Android companion.*$(Esc $loCompanionPublicVer)",
        "Neither the Windows $(Esc $loCandidateVer) candidate nor the Android"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "guided breathing",
        "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift"
    )

    # 3. Lights Out — redirect routes (follow to canonical, basic content check)
    Test-UrlContent -Url "$target/lights-out" -ContainsPatterns @(
        "Wi-Fi Guard", "ForgeCast Weather"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "guided breathing",
        "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift"
    ) -FollowRedirects $true
    Test-UrlContent -Url "$target/lights-out.html" -ContainsPatterns @(
        "Wi-Fi Guard", "ForgeCast Weather"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "guided breathing",
        "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift"
    ) -FollowRedirects $true

    # 4. Redirect headers
    Test-UrlRedirect -Url "$target/lights-out" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"
    Test-UrlRedirect -Url "$target/lights-out.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"

    # 5. ForgeCast landing page — manifest-derived version, hash, test count
    Test-UrlContent -Url "$target/forgecast/" -Name "product truth" -ContainsPatterns @(
        "ForgeCast Weather",
        "$(Esc $fcPublicVer)",
        $fcSha256,
        $fcTestStatus,
        "v030-today.png"
    ) -NotContainsPatterns @(
        "SkyFoundry",
        "v0.2.9/ForgeCast-Weather-v0.2.9",
        "v0.3.2/ForgeCast-Weather-v0.3.2-android-release.apk"
    )
    Test-UrlContent -Url "$target/forgecast" -ContainsPatterns @(
        "ForgeCast Weather", "$(Esc $fcPublicVer)"
    ) -NotContainsPatterns @(
        "SkyFoundry",
        "v0.2.9/ForgeCast-Weather-v0.2.9",
        "v0.3.2/ForgeCast-Weather-v0.3.2-android-release.apk"
    ) -FollowRedirects $true
    if ($target -like "*theprooffoundry.com*") {
        Test-UrlContent -Url "$target/sitemap.xml" -ContainsPatterns @(
            "https://theprooffoundry.com/reality-gate/",
            "https://theprooffoundry.com/cache-vault/",
            "https://theprooffoundry.com/lights-out/",
            "https://theprooffoundry.com/cleanroom/",
            "https://theprooffoundry.com/forgecast/",
            "https://theprooffoundry.com/proofshot/",
            "https://theprooffoundry.com/proof/"
        )
    } else {
        Test-UrlContent -Url "$target/sitemap.xml"
    }

    # 6. Assets
    Test-Asset -Url "$target/assets/lights-out/lights-out-keyart-hero-ui.png" -ExpectedContentType "image/"
    Test-Asset -Url "$target/brand/proof-foundry-logo-horizontal.svg" -ExpectedContentType "image/"

    # 7. 404 page
    Test-UrlContent -Url "$target/this-page-does-not-exist" -ContainsPatterns @(
        "404", "Page Not Found", "The Proof Foundry"
    ) -NotContainsPatterns @("SkyFoundry")

    # 8. Proof/Receipts page
    Test-UrlContent -Url "$target/proof/" -ContainsPatterns @(
        "Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault",
        "Cleanroom", "ForgeCast Weather", "ProofShot"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "Guided breathing",
        "ambient soundscapes", "warm screen shift", "smart light dimming"
    )
    Test-UrlContent -Url "$target/proof" -ContainsPatterns @(
        "Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault",
        "Cleanroom", "ForgeCast Weather", "ProofShot"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "Guided breathing",
        "ambient soundscapes", "warm screen shift", "smart light dimming"
    ) -FollowRedirects $true
    Test-UrlContent -Url "$target/proof.html" -ContainsPatterns @(
        "Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault",
        "Cleanroom", "ForgeCast Weather", "ProofShot"
    ) -NotContainsPatterns @(
        "Electron packaged", "SkyFoundry", "Guided breathing",
        "ambient soundscapes", "warm screen shift", "smart light dimming"
    ) -FollowRedirects $true
    Test-UrlRedirect -Url "$target/proof" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proof/"
    Test-UrlRedirect -Url "$target/proof.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proof/"

    # 9. Reality Gate — manifest-derived artifact hash + state label
    Test-UrlContent -Url "$target/reality-gate/" -ContainsPatterns @(
        "Reality Gate", $rgStateLabel, $rgSha256
    ) -NotContainsPatterns @("SkyFoundry")

    # 10. Cache Vault — manifest-derived status, download label, artifact, hash
    #     The download label, status label, artifact filename, and SHA-256 are
    #     all derived from site-manifest.json so they track the current release
    #     state (final public v0.2.3; the RC candidate lane is closed).
    Test-UrlContent -Url "$target/cache-vault/" -Name "product truth" -ContainsPatterns @(
        "Cache Vault",
        $cvDownloadPattern,
        "$(Esc ('v' + $cv.release.publicVersion)) is the current public Windows release",
        $cvStatusLabel,
        $cvArtifactPattern,
        $cvSha256
    ) -NotContainsPatterns @("SkyFoundry", "Get Cache Vault", "v0\.2\.3-rc1", "v0\.2\.3-rc2", "release candidate")
    Test-UrlContent -Url "$target/cache-vault" -ContainsPatterns @(
        "Cache Vault"
    ) -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/cache-vault" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cache-vault/"
    Test-UrlRedirect -Url "$target/cache-vault.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cache-vault/"

    # 11. Cleanroom — manifest-derived status + download label
    Test-UrlContent -Url "$target/cleanroom/" -ContainsPatterns @(
        "Cleanroom", $clnDownloadPattern, $clnStatusLabel
    ) -NotContainsPatterns @("SkyFoundry")
    Test-UrlContent -Url "$target/cleanroom" -ContainsPatterns @(
        "Cleanroom"
    ) -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/cleanroom" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cleanroom/"
    Test-UrlRedirect -Url "$target/cleanroom.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cleanroom/"

    # 12. ProofShot — manifest-derived release truth (public release since 2026-09-17)
    Test-UrlContent -Url "$target/proofshot/" -ContainsPatterns @(
        "ProofShot", "Download ProofShot v$(Esc $psPublicVer)", (Esc $ps.downloadUrl), (Esc $ps.sha256), $psStatusLabel
    ) -NotContainsPatterns @("SkyFoundry", "no public ProofShot release", "NOT YET RELEASED")
    Test-UrlContent -Url "$target/proofshot" -ContainsPatterns @(
        "ProofShot"
    ) -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/proofshot" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proofshot/"
    Test-UrlRedirect -Url "$target/proofshot.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proofshot/"
}

# 13. ForgeCast APK and SHA256 availability (R2 / Proof Foundry distribution)
Write-Host "`n---> Testing ForgeCast distribution files"
Test-AssetHead -Url $fcApkUrl -Name "APK" -ExpectedContentType "application/"
Test-UrlContent -Url $fcShaUrl -Name "SHA256" -ContainsPatterns @($fcSha256)

# 13b. ProofShot installer and SHA256 availability (R2 / Proof Foundry distribution)
Write-Host "`n---> Testing ProofShot distribution files"
Test-AssetHead -Url $ps.downloadUrl -Name "ProofShot installer" -ExpectedContentType "application/"
Test-UrlContent -Url $ps.sha256Url -Name "ProofShot SHA256" -ContainsPatterns @($ps.sha256)

# 14. Hash chain: landing page and SHA file both expose the expected SHA
foreach ($target in $TargetUrls) {
    if ($target -like "*theprooffoundry.com*") {
        Write-Host "Checking hash chain for $target/forgecast/ ... " -NoNewline
        try {
            $landingContent = Get-PlaintextContent -Url "$target/forgecast/"
            $rawContent = (Invoke-WebRequest -Uri $fcShaUrl -UseBasicParsing).Content
            $shaFileContent = if ($rawContent -is [string]) { $rawContent.Trim() } else { [System.Text.Encoding]::UTF8.GetString($rawContent).Trim() }

            $landingMatch = $landingContent -match [regex]::Escape($fcSha256)
            $shaMatch = $shaFileContent -match [regex]::Escape($fcSha256)

            if (-not $landingMatch) {
                Write-Host "[FAIL] (Landing page missing expected SHA)" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = "$target/forgecast/"; Status = 200; Msg = "FAIL (SHA missing)" }
            } elseif (-not $shaMatch) {
                Write-Host "[FAIL] (SHA file missing expected SHA)" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = $fcShaUrl; Status = 200; Msg = "FAIL (SHA file bad)" }
            } else {
                Write-Host "[PASS] (Hash chain OK)" -ForegroundColor Green
                $script:verifiedRoutes += [PSCustomObject]@{ Url = "$target/forgecast/"; Status = 200; Msg = "PASS (Hash chain)" }
            }
        } catch {
            Write-Host "[FAIL] (Hash chain check threw: $_)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = "$target/forgecast/"; Status = 0; Msg = "FAIL (Hash chain exception)" }
        }
    }
}

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

if ($script:failedCount -gt 0) {
    Write-Host "==> VERIFICATION FAILED with $script:failedCount error(s). Check output above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n==> ALL GATES PASSED! Verification complete." -ForegroundColor Green

    # Generate verification receipt
    # Verification is an event after publication. Keep its output outside the
    # tracked inputs of that publication and never overwrite a previous event.
    $eventUtc = (Get-Date).ToUniversalTime()
    $date = $eventUtc.ToString('yyyy-MM-dd')
    if ([string]::IsNullOrWhiteSpace($ReceiptPath)) {
        $eventId = $eventUtc.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N')
        $ReceiptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "receipts/deploy-verification/$eventId.md"
    }
    $ReceiptPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReceiptPath)
    if (Test-Path $ReceiptPath) { throw "Refusing to overwrite verification receipt: $ReceiptPath" }
    $receiptDir = Split-Path -Parent $ReceiptPath
    if (-not (Test-Path $receiptDir)) {
        New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
    }
    $commitHash = "unknown"
    $treeHash = "unknown"
    try {
        $commitHash = (git -C (Split-Path -Parent $PSScriptRoot) rev-parse HEAD 2>$null)
        $treeHash = (git -C (Split-Path -Parent $PSScriptRoot) rev-parse 'HEAD^{tree}' 2>$null)
        if (-not $commitHash) { $commitHash = "unknown" }
    } catch { $commitHash = "unknown" }

    $apkStatus = if ($script:verifiedRoutes | Where-Object { $_.Url -eq $fcApkUrl -and $_.Msg -like "PASS*" }) { "OK" } else { "FAIL" }
    $shaStatus = if ($script:verifiedRoutes | Where-Object { $_.Url -eq $fcShaUrl -and $_.Msg -like "PASS*" }) { "OK" } else { "FAIL" }

    $md = @"
# Deployment Verification Receipt — $date

*   **Site Commit**: $commitHash
*   **Site Tree**: $treeHash
*   **Verified Targets**: $($TargetUrls -join ', ')
*   **Manifest**: $manifestRelPath
*   **ForgeCast APK URL**: $fcApkUrl
*   **ForgeCast SHA URL**: $fcShaUrl
*   **Expected SHA**: $fcSha256
*   **APK Status**: $apkStatus
*   **SHA Status**: $shaStatus
*   **Timestamp**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")
*   **Overall Status**: **PASS**

## Verified Routes

| Url / Path | Status Code | Result |
| :--- | :---: | :---: |
"@
    foreach ($r in $script:verifiedRoutes) {
        $md += "`n| $($r.Url) | $($r.Status) | **$($r.Msg)** |"
    }
    $md += "`n"
    $receiptStream = [System.IO.File]::Open($ReceiptPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    $receiptWriter = [System.IO.StreamWriter]::new($receiptStream, [System.Text.UTF8Encoding]::new($false))
    try { $receiptWriter.Write($md) } finally { $receiptWriter.Dispose() }
    Write-Host "==> Verification receipt written to: $receiptPath" -ForegroundColor Green
}
