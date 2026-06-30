param(
    [string[]]$Targets = @("https://theprooffoundry.com", "https://www.theprooffoundry.com", "https://proof-foundry-site.pages.dev")
)

$ErrorActionPreference = "Stop"
$script:failedCount = 0
$script:verifiedRoutes = @()

Write-Host "==> Starting Public Site Hardened Verification"

function Test-UrlContent {
    param(
        [string]$Url,
        [string[]]$ContainsPatterns = @(),
        [string[]]$NotContainsPatterns = @(),
        [bool]$FollowRedirects = $true
    )
    Write-Host "Checking content: $Url (FollowRedirects=$FollowRedirects) ... " -NoNewline
    try {
        # Using curl.exe -L -s to follow redirects and fetch content
        $args = @("-s")
        if ($FollowRedirects) { $args += "-L" }
        $args += $Url
        $content = & curl.exe @args
        
        # Check if curl failed or returned empty content
        if ([string]::IsNullOrEmpty($content)) {
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
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $status = $response.StatusCode
        $headers = $response.Headers
    } catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $headers = $_.Exception.Response.Headers
        } else {
            Write-Host "[FAIL] (Request failed: $_)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL" }
            return
        }
    }

    if ($ExpectedStatus -notcontains $status) {
        Write-Host "[FAIL] (Expected status $($ExpectedStatus -join '/'), got $status)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Status)" }
        return
    }

    $location = $headers['Location']
    if ($location -ne $ExpectedLocation) {
        Write-Host "[FAIL] (Expected Location '$ExpectedLocation', got '$location')" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Location)" }
        return
    }

    Write-Host "[PASS] (Redirects correctly to $location)" -ForegroundColor Green
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "PASS (Redirect)" }
}

function Test-Asset {
    param(
        [string]$Url,
        [string]$ExpectedContentType = "image/"
    )
    Write-Host "Checking asset header & content: $Url ... " -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -ErrorAction SilentlyContinue
        $status = $response.StatusCode
        $headers = $response.Headers
        $content = $response.Content
    } catch {
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $headers = $_.Exception.Response.Headers
            $content = ""
        } else {
            Write-Host "[FAIL] (Request failed: $_)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = 0; Msg = "FAIL" }
            return
        }
    }

    if ($status -ne 200) {
        Write-Host "[FAIL] (Expected status 200, got $status)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Status)" }
        return
    }

    $contentType = $headers['Content-Type']
    if ($contentType -notlike "*$ExpectedContentType*") {
        Write-Host "[FAIL] (Expected Content-Type matches '$ExpectedContentType', got '$contentType')" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Content-Type)" }
        return
    }

    # Fail loudly if an asset request returns HTML content
    if ($content -match "<!doctype html>" -or $content -match "<html" -or $content -match "The Proof Foundry") {
        Write-Host "[FAIL] (Asset request returned HTML content instead of binary data!)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "FAIL (Returned HTML)" }
        return
    }

    Write-Host "[PASS] (Content-Type: $contentType)" -ForegroundColor Green
    $script:verifiedRoutes += [PSCustomObject]@{ Url = $Url; Status = $status; Msg = "PASS" }
}

# Run the assertions
foreach ($target in $Targets) {
    Write-Host "`n---> Testing target: $target"
    
    # 1. Homepage content check
    Test-UrlContent -Url "$target/" -ContainsPatterns @("Lights Out", "Cache Vault", "Cleanroom", "ForgeCast", "HyperSnatch")
    
    # 2. Lights Out canonical slash check
    Test-UrlContent -Url "$target/lights-out/" -ContainsPatterns @("PowerShell compiled \(SleepTimer.exe\)", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry")
    
    # 3. Lights Out redirect content check (follows redirect to canonical route)
    Test-UrlContent -Url "$target/lights-out" -ContainsPatterns @("PowerShell compiled \(SleepTimer.exe\)", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry") -FollowRedirects $true
    Test-UrlContent -Url "$target/lights-out.html" -ContainsPatterns @("PowerShell compiled \(SleepTimer.exe\)", "ForgeCast Weather") -NotContainsPatterns @("Electron packaged", "SkyFoundry") -FollowRedirects $true
    
    # 4. Redirect headers checks
    Test-UrlRedirect -Url "$target/lights-out" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"
    Test-UrlRedirect -Url "$target/lights-out.html" -ExpectedStatus @(301, 302, 307, 308) -ExpectedLocation "/lights-out/"
    
    # 5. Robots/Sitemap check
    Test-UrlContent -Url "$target/robots.txt" -ContainsPatterns @("sitemap.xml")
    if ($target -like "*theprooffoundry.com*") {
        Test-UrlContent -Url "$target/sitemap.xml" -ContainsPatterns @("https://theprooffoundry.com/lights-out/")
    } else {
        Test-UrlContent -Url "$target/sitemap.xml"
    }

    # 6. Assets content-type and payload check
    Test-Asset -Url "$target/assets/lights-out/lights-out-keyart-hero-ui.png" -ExpectedContentType "image/"
    Test-Asset -Url "$target/brand/proof-foundry-logo-horizontal.svg" -ExpectedContentType "image/"
}

if ($script:failedCount -gt 0) {
    Write-Error "Site Verification FAILED with $script:failedCount errors."
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
    
    $md = @"
# Deployment Verification Receipt — $date

*   **Verified Targets**: $($Targets -join ', ')
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
    $md | Out-File $receiptPath -Encoding utf8NoBOM
    Write-Host "==> Verification receipt written to: $receiptPath" -ForegroundColor Green
}
