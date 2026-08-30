param(
    [string[]]$Targets = @("https://theprooffoundry.com", "https://www.theprooffoundry.com", "https://proof-foundry-site.pages.dev"),
    # Must match the canonical downloadUrl/sha256Url in site-manifest.json. These
    # values are echoed into the generated deploy receipt, so a raw provider
    # hostname here republishes itself on every verification run. build-site.ps1
    # rejects raw .r2.dev in canonical manifest URLs for the same reason.
    [string]$ApkUrl = "https://downloads.theprooffoundry.com/forgecast/v0.3.3/ForgeCast-Weather-v0.3.3-android-release.apk",
    [string]$ShaUrl = "https://downloads.theprooffoundry.com/forgecast/v0.3.3/ForgeCast-Weather-v0.3.3-android-release.apk.sha256.txt",
    [string]$ExpectedSha = "50ABE59E52B6DC7E8649C0CA63EB065425F8EDC607187E3844D90CE5F1EED833"
)

$ErrorActionPreference = "Stop"
$script:failedCount = 0
$script:verifiedRoutes = @()

function Write-Fail {
    param(
        [string]$Message,
        [string]$Url
    )
    Write-Host "[FAIL] ($Message)" -ForegroundColor Red
    $script:failedCount++
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL ($Message)" }
}

function Write-Pass {
    param(
        [string]$Message,
        [string]$Url,
        [int]$Status
    )
    Write-Host "[PASS] ($Message)" -ForegroundColor Green
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $Status; Msg = "PASS ($Message)" }
}

function Get-PlaintextContent {
    param(
        [string]$Url
    )
    $contentLines = curl.exe -s -H "Cache-Control: no-cache" -L $Url
    return $contentLines -join "`n"
}

Write-Host "==> Starting Public Site Hardened Verification via curl" -ForegroundColor Cyan
Write-Host "Targets: $($Targets -join ', ')" -ForegroundColor Cyan
Write-Host "APK URL: $ApkUrl" -ForegroundColor Cyan
Write-Host "SHA URL: $ShaUrl" -ForegroundColor Cyan

function Test-UrlContent {
    param(
        [string]$Url,
        [string[]]$ContainsPatterns = @(),
        [string[]]$NotContainsPatterns = @(),
        [bool]$FollowRedirects = $true
    )
    Write-Host "Checking content: $Url (FollowRedirects=$FollowRedirects) ... " -NoNewline
    try {
        # Using curl.exe to follow redirects and fetch content
        $curlArgs = @("-s", "-H", "Cache-Control: no-cache")
        if ($FollowRedirects) { $curlArgs += "-L" }
        $curlArgs += $Url
        $contentLines = & curl.exe @curlArgs
        $content = $contentLines -join "`n"
        
        # Check if curl failed or returned empty content
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "[FAIL] (Empty response from curl)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL (Empty)" }
            return
        }

        # Assertions
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
        $headersText = curl.exe -s -H "Cache-Control: no-cache" -I $Url
        $headersString = $headersText -join "`n"
        
        # Extract Status Code
        if ($headersString -match "HTTP/\S+\s+(\d+)") {
            $status = [int]$Matches[1]
        } else {
            $status = 0
        }
        
        # Extract Location Header
        if ($headersString -match "(?m)^[Ll]ocation:\s*(\S+)") {
            $location = $Matches[1].Trim()
        } else {
            $location = ""
        }

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

    if ($status -ne 200) {
        Write-Fail "Expected status 200, got $status" -Url $Url
        return
    }

    if ($contentType -notlike "*$ExpectedContentType*") {
        Write-Fail "Expected Content-Type '$ExpectedContentType', got '$contentType'" -Url $Url
        return
    }

    if ($contentType -like "*text/html*") {
        Write-Fail "Asset returned text/html (likely fallback to index.html)" -Url $Url
        return
    }

    Write-Pass "$status $contentType" -Url $Url -Status $status
}

function Test-Asset {
    param(
        [string]$Url,
        [string]$ExpectedContentType = "image/"
    )
    Write-Host "Checking asset header & content: $Url ... " -NoNewline
    try {
        # Fetch headers
        $headersText = curl.exe -s -H "Cache-Control: no-cache" -I $Url
        $headersString = $headersText -join "`n"
        
        # Status check
        if ($headersString -match "HTTP/\S+\s+(\d+)") {
            $status = [int]$Matches[1]
        } else {
            $status = 0
        }
        
        if ($status -ne 200) {
            Write-Host "[FAIL] (Expected status 200, got $status)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Status)" }
            return
        }
        
        # Content-Type check
        if ($headersString -match "(?m)^[Cc]ontent-[Tt]ype:\s*(\S+)") {
            $contentType = $Matches[1].Trim()
        } else {
            $contentType = ""
        }
        
        if ($contentType -notlike "*$ExpectedContentType*") {
            Write-Host "[FAIL] (Expected Content-Type matches '$ExpectedContentType', got '$contentType')" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Content-Type)" }
            return
        }
        
        # Fetch body content
        $bodyLines = curl.exe -s -H "Cache-Control: no-cache" $Url
        $body = $bodyLines -join "`n"
        
        # Fail loudly if an asset request returns HTML content
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

# Cache Vault expectations are derived from site-manifest.json instead of pinned
# here. The previous hardcoded set drifted to v0.2.0 while the manifest and the
# product repo had both moved to v0.2.2, so the verifier would have failed a
# correct site. Product-repo authority for v0.2.2 was re-proven independently:
# annotated tag v0.2.2 peels to 20bb01e, the published GitHub release carries
# CacheVault-v0.2.2-windows.zip, and that artifact hashes to the manifest sha256.
$siteRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $siteRoot 'site-manifest.json'
if (-not (Test-Path $manifestPath)) {
    Write-Host "==> VERIFICATION ABORTED: site-manifest.json not found at $manifestPath" -ForegroundColor Red
    exit 1
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$cacheVault = $manifest.products | Where-Object { $_.name -eq 'Cache Vault' }
if (-not $cacheVault) {
    Write-Host "==> VERIFICATION ABORTED: no 'Cache Vault' product in site-manifest.json" -ForegroundColor Red
    exit 1
}
# Selected by platform rather than array position so adding an artifact cannot
# silently repoint the Windows assertions at the Android companion.
$cvWindows = $cacheVault.artifacts | Where-Object { $_.platform -eq 'Windows' }
if (-not $cvWindows -or -not $cvWindows.filename -or -not $cvWindows.sha256) {
    Write-Host "==> VERIFICATION ABORTED: Cache Vault Windows artifact incomplete in site-manifest.json" -ForegroundColor Red
    exit 1
}
$cvStateLabel = $manifest.stateLabels.PSObject.Properties[$cacheVault.state].Value
# Last two URL segments give the versioned release path, e.g. v0.2.2/CacheVault-v0.2.2-windows.zip
$cvReleasePath = ($cvWindows.downloadUrl -split '/' | Select-Object -Last 2) -join '/'
$cvExpected = @(
    [regex]::Escape($cacheVault.name)
    [regex]::Escape($cacheVault.downloadLabel)
    [regex]::Escape($cvStateLabel)
    [regex]::Escape($cvReleasePath)
    [regex]::Escape($cvWindows.sha256)
)
Write-Host "Cache Vault expectations (from manifest): v$($cacheVault.release.publicVersion), $($cvWindows.filename)" -ForegroundColor Cyan

# Run the assertions
foreach ($target in $Targets) {
    Write-Host "`n---> Testing target: $target"
    
    # 1. Homepage content check — global nav + full product family + card contract
    Test-UrlContent -Url "$target/" -ContainsPatterns @("Reality Gate", "Lights Out", "Cache Vault", "Cleanroom", "ForgeCast Weather", "ProofShot", "Proof Standard", "View product") -NotContainsPatterns @("SkyFoundry")
    
    # 2. Lights Out canonical slash check
    Test-UrlContent -Url "$target/lights-out/" -ContainsPatterns @("Wi-Fi Guard", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "guided breathing", "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift")
    
    # 3. Lights Out redirect content check (follows redirect to canonical route)
    Test-UrlContent -Url "$target/lights-out" -ContainsPatterns @("Wi-Fi Guard", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "guided breathing", "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift") -FollowRedirects $true
    Test-UrlContent -Url "$target/lights-out.html" -ContainsPatterns @("Wi-Fi Guard", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "guided breathing", "breathing ritual", "ambient soundscapes", "soundscapes", "screen shift") -FollowRedirects $true
    
    # 4. Redirect headers checks
    Test-UrlRedirect -Url "$target/lights-out" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"
    Test-UrlRedirect -Url "$target/lights-out.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"
    
    # 5. ForgeCast landing page
    Test-UrlContent -Url "$target/forgecast/" -ContainsPatterns @("ForgeCast Weather", "v0.3.3", "50ABE59E52B6DC7E8649C0CA63EB065425F8EDC607187E3844D90CE5F1EED833", "724/724", "v030-today.png") -NotContainsPatterns @("SkyFoundry", "v0.2.9/ForgeCast-Weather-v0.2.9", "v0.3.2/ForgeCast-Weather-v0.3.2-android-release.apk")
    Test-UrlContent -Url "$target/forgecast" -ContainsPatterns @("ForgeCast Weather", "v0.3.3") -NotContainsPatterns @("SkyFoundry", "v0.2.9/ForgeCast-Weather-v0.2.9", "v0.3.2/ForgeCast-Weather-v0.3.2-android-release.apk") -FollowRedirects $true
    if ($target -like "*theprooffoundry.com*") {
        Test-UrlContent -Url "$target/sitemap.xml" -ContainsPatterns @("https://theprooffoundry.com/reality-gate/", "https://theprooffoundry.com/cache-vault/", "https://theprooffoundry.com/lights-out/", "https://theprooffoundry.com/cleanroom/", "https://theprooffoundry.com/forgecast/", "https://theprooffoundry.com/proofshot/", "https://theprooffoundry.com/proof/")
    } else {
        Test-UrlContent -Url "$target/sitemap.xml"
    }

    # 6. Assets content-type and payload check
    Test-Asset -Url "$target/assets/lights-out/lights-out-keyart-hero-ui.png" -ExpectedContentType "image/"
    Test-Asset -Url "$target/brand/proof-foundry-logo-horizontal.svg" -ExpectedContentType "image/"

    # 7. 404 page check — should return a branded HTML page
    Test-UrlContent -Url "$target/this-page-does-not-exist" -ContainsPatterns @("404", "Page Not Found", "The Proof Foundry") -NotContainsPatterns @("SkyFoundry")

    # 8. Proof/Receipts page checks — generated from the same manifest
    Test-UrlContent -Url "$target/proof/" -ContainsPatterns @("Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault", "Cleanroom", "ForgeCast Weather", "ProofShot") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "Guided breathing", "ambient soundscapes", "warm screen shift", "smart light dimming")
    Test-UrlContent -Url "$target/proof" -ContainsPatterns @("Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault", "Cleanroom", "ForgeCast Weather", "ProofShot") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "Guided breathing", "ambient soundscapes", "warm screen shift", "smart light dimming") -FollowRedirects $true
    Test-UrlContent -Url "$target/proof.html" -ContainsPatterns @("Proof Foundry Receipts", "Reality Gate", "Lights Out", "Cache Vault", "Cleanroom", "ForgeCast Weather", "ProofShot") -NotContainsPatterns @("Electron packaged", "SkyFoundry", "Guided breathing", "ambient soundscapes", "warm screen shift", "smart light dimming") -FollowRedirects $true
    
    # Redirect headers checks for proof page
    Test-UrlRedirect -Url "$target/proof" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proof/"
    Test-UrlRedirect -Url "$target/proof.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proof/"

    # 9. New internal product routes (canonical, no off-site jumps)
    Test-UrlContent -Url "$target/reality-gate/" -ContainsPatterns @("Reality Gate", "Developer Pilot", "58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756") -NotContainsPatterns @("SkyFoundry")
    # Product name, versioned download action, state label, versioned download
    # target, and published hash, all derived from the manifest above.
    # "Get Cache Vault" was the v0.1.9 CTA and must not return.
    Test-UrlContent -Url "$target/cache-vault/" -ContainsPatterns $cvExpected -NotContainsPatterns @("SkyFoundry", "Get Cache Vault")
    Test-UrlContent -Url "$target/cache-vault" -ContainsPatterns @("Cache Vault") -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/cache-vault" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cache-vault/"
    Test-UrlRedirect -Url "$target/cache-vault.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cache-vault/"

    Test-UrlContent -Url "$target/cleanroom/" -ContainsPatterns @("Cleanroom", "Download v1.0.7", "Public release") -NotContainsPatterns @("SkyFoundry")
    Test-UrlContent -Url "$target/cleanroom" -ContainsPatterns @("Cleanroom") -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/cleanroom" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cleanroom/"
    Test-UrlRedirect -Url "$target/cleanroom.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/cleanroom/"

    Test-UrlContent -Url "$target/proofshot/" -ContainsPatterns @("ProofShot", "Rebrand in progress", "In proof") -NotContainsPatterns @("SkyFoundry")
    Test-UrlContent -Url "$target/proofshot" -ContainsPatterns @("ProofShot") -NotContainsPatterns @("SkyFoundry") -FollowRedirects $true
    Test-UrlRedirect -Url "$target/proofshot" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proofshot/"
    Test-UrlRedirect -Url "$target/proofshot.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/proofshot/"
}

# 8. APK and SHA256 availability (R2 distribution)
Write-Host "`n---> Testing ForgeCast distribution files"
Test-AssetHead -Url $ApkUrl -Name "APK" -ExpectedContentType "application/"
Test-UrlContent -Url $ShaUrl -Name "SHA256" -ContainsPatterns @($ExpectedSha)

# 9. Hash chain: landing page and SHA file both expose the expected SHA
foreach ($target in $Targets) {
    if ($target -like "*theprooffoundry.com*") {
        Write-Host "Checking hash chain for $target/forgecast/ ... " -NoNewline
        try {
            $landingContent = Get-PlaintextContent -Url "$target/forgecast/"
            $rawContent = (Invoke-WebRequest -Uri $ShaUrl -UseBasicParsing).Content
            $shaFileContent = if ($rawContent -is [string]) { $rawContent.Trim() } else { [System.Text.Encoding]::UTF8.GetString($rawContent).Trim() }

            $landingMatch = $landingContent -match [regex]::Escape($ExpectedSha)
            $shaMatch = $shaFileContent -match [regex]::Escape($ExpectedSha)

            if (-not $landingMatch) {
                Write-Host "[FAIL] (Landing page missing expected SHA)" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = "$target/forgecast/"; Status = 200; Msg = "FAIL (SHA missing)" }
            } elseif (-not $shaMatch) {
                Write-Host "[FAIL] (SHA file missing expected SHA)" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Url = $ShaUrl; Status = 200; Msg = "FAIL (SHA file bad)" }
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

if ($script:failedCount -gt 0) {
    Write-Host "==> VERIFICATION FAILED with $script:failedCount error(s). Check output above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n==> ALL GATES PASSED! Verification complete." -ForegroundColor Green
    
    # Generate verification receipt
    $date = Get-Date -Format "yyyy-MM-dd"
    $receiptDir = Join-Path (Split-Path -Parent $PSScriptRoot) "reports\deploy-receipts"
    if (-not (Test-Path $receiptDir)) {
        New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
    }
    $receiptPath = Join-Path $receiptDir "$date-proof-foundry-site.md"
    
    $commitHash = "unknown"
    try {
        $commitHash = (git -C (Split-Path -Parent $PSScriptRoot) rev-parse --short HEAD 2>$null)
        if (-not $commitHash) { $commitHash = "unknown" }
    } catch { $commitHash = "unknown" }

    $apkStatus = if ($script:verifiedRoutes | Where-Object { $_.Url -eq $ApkUrl -and $_.Msg -like "PASS*" }) { "OK" } else { "FAIL" }
    $shaStatus = if ($script:verifiedRoutes | Where-Object { $_.Url -eq $ShaUrl -and $_.Msg -like "PASS*" }) { "OK" } else { "FAIL" }

    $md = @"
# Deployment Verification Receipt — $date

*   **Site Commit**: $commitHash
*   **Verified Targets**: $($Targets -join ', ')
*   **APK URL**: $ApkUrl
*   **SHA URL**: $ShaUrl
*   **Expected SHA**: $ExpectedSha
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
    # Out-File -Encoding utf8 emits a BOM on Windows PowerShell 5.1; the receipts
    # are served as plain text, so write UTF-8 without one on every host.
    [System.IO.File]::WriteAllText($receiptPath, $md, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "==> Verification receipt written to: $receiptPath" -ForegroundColor Green
}
