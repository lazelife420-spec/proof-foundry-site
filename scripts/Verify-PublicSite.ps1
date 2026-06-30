param(
    [string]$TargetUrl = "https://proof-foundry-site.pages.dev"
)

$ErrorActionPreference = "Stop"
$script:failedCount = 0
$script:verifiedRoutes = @()

Write-Host "==> Starting Public Site Verification for: $TargetUrl"

function Assert-Route {
    param(
        [string]$Path,
        [int[]]$ExpectedStatus = @(200),
        [string[]]$ContainsPatterns = @(),
        [string[]]$NotContainsPatterns = @(),
        [string]$ExpectedContentType = ""
    )
    $url = "$TargetUrl$Path"
    Write-Host "Checking: $url ... " -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $status = $response.StatusCode
        $headers = $response.Headers
        $content = $response.Content
    } catch {
        # Check if HTTP status exception occurred
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            $headers = $_.Exception.Response.Headers
            $content = ""
        } else {
            Write-Host "[FAIL] (Request failed: $_)" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = 0; Msg = "FAIL" }
            return
        }
    }

    # Status check
    if ($ExpectedStatus -notcontains $status) {
        Write-Host "[FAIL] (Expected status $($ExpectedStatus -join '/'), got $status)" -ForegroundColor Red
        $script:failedCount++
        $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "FAIL" }
        return
    }

    # Redirect location check if status is 3xx
    if ($status -ge 300 -and $status -lt 400) {
        Write-Host "[PASS] (Redirects to $($headers['Location']))" -ForegroundColor Green
        $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "PASS (Redirect)" }
        return
    }

    # Content Type check
    if ($ExpectedContentType) {
        $contentType = $headers['Content-Type']
        if ($contentType -notlike "*$ExpectedContentType*") {
            Write-Host "[FAIL] (Expected Content-Type '$ExpectedContentType', got '$contentType')" -ForegroundColor Red
            $script:failedCount++
            $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "FAIL (MIME)" }
            return
        }
    }

    # Content checks
    if ($ContainsPatterns.Count -gt 0) {
        foreach ($pattern in $ContainsPatterns) {
            if ($content -notmatch $pattern) {
                Write-Host "[FAIL] (Missing expected pattern: '$pattern')" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "FAIL (Pattern)" }
                return
            }
        }
    }

    if ($NotContainsPatterns.Count -gt 0) {
        foreach ($pattern in $NotContainsPatterns) {
            if ($content -match $pattern) {
                Write-Host "[FAIL] (Found forbidden pattern: '$pattern')" -ForegroundColor Red
                $script:failedCount++
                $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "FAIL (Pattern)" }
                return
            }
        }
    }

    Write-Host "[PASS]" -ForegroundColor Green
    $script:verifiedRoutes += [PSCustomObject]@{ Path = $Path; Status = $status; Msg = "PASS" }
}

# Run the assertions
Assert-Route -Path "/" -ExpectedStatus @(200) -ContainsPatterns @("Lights Out", "Cache Vault", "Cleanroom", "ForgeCast", "HyperSnatch")
Assert-Route -Path "/lights-out/" -ExpectedStatus @(200) -ContainsPatterns @("PowerShell compiled \(SleepTimer.exe\)") -NotContainsPatterns @("Electron packaged")
Assert-Route -Path "/lights-out" -ExpectedStatus @(301, 302, 307, 308)
Assert-Route -Path "/lights-out.html" -ExpectedStatus @(301, 302, 307, 308)
Assert-Route -Path "/forgecast" -ExpectedStatus @(200) -ContainsPatterns @("ForgeCast Weather")
Assert-Route -Path "/founders" -ExpectedStatus @(200)
Assert-Route -Path "/robots.txt" -ExpectedStatus @(200) -ContainsPatterns @("sitemap.xml")
Assert-Route -Path "/sitemap.xml" -ExpectedStatus @(200)
Assert-Route -Path "/assets/lights-out/lights-out-keyart-hero-ui.png" -ExpectedStatus @(200) -ExpectedContentType "image/png"
Assert-Route -Path "/brand/proof-foundry-logo-horizontal.svg" -ExpectedStatus @(200) -ExpectedContentType "image/svg+xml"

if ($script:failedCount -gt 0) {
    Write-Error "Site Verification FAILED with $script:failedCount errors."
    exit 1
} else {
    Write-Host "==> ALL GATES PASSED! Verification complete." -ForegroundColor Green
    
    # Generate verification receipt
    $date = Get-Date -Format "yyyy-MM-dd"
    $receiptDir = Join-Path (Split-Path -Parent $PSScriptRoot) "reports\deploy-receipts"
    if (-not (Test-Path $receiptDir)) {
        New-Item -ItemType Directory -Path $receiptDir -Force | Out-Null
    }
    $receiptPath = Join-Path $receiptDir "$date-proof-foundry-site.md"
    
    $md = @"
# Deployment Verification Receipt — $date

*   **Target Deployment URL**: $TargetUrl
*   **Timestamp**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")
*   **Overall Status**: **PASS**

## Verified Routes

| Path | Status Code | Result |
| :--- | :---: | :---: |
"@
    foreach ($r in $script:verifiedRoutes) {
        $md += "`n| $($r.Path) | $($r.Status) | **$($r.Msg)** |"
    }
    $md += "`n"
    $md | Out-File $receiptPath -Encoding utf8NoBOM
    Write-Host "==> Verification receipt written to: $receiptPath" -ForegroundColor Green
}
