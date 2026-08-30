#Requires -Version 5.1
<#
    Proves that executable verification/deploy scripts do not default to raw
    storage-provider endpoints.

    Why this exists: scripts/Verify-PublicSite.ps1 echoes its $ApkUrl/$ShaUrl
    values into the deploy receipt it generates, and reports/deploy-receipts/ is
    copied verbatim into public output by scripts/build-site.ps1. A raw
    pub-<id>.r2.dev default therefore republished itself on every verification
    run, which is how the historical receipts acquired provider URLs while
    site-manifest.json was already canonical. build-site.ps1 rejects raw .r2.dev
    in canonical manifest URLs; this suite extends the same policy to the script
    defaults that feed generated public artifacts.

    Detection is AST-based and scoped to parameter default expressions only, so
    a script that merely names ".r2.dev" in a rejection message or comment is
    not a violation. That precision is asserted, not assumed (TEST 5).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $root 'scripts'
$manifestPath = Join-Path $root 'site-manifest.json'

$script:passed = 0
$script:failed = 0

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Red }
        $script:failed++
    }
}

# Returns one record per parameter whose DEFAULT VALUE expression references a
# raw provider endpoint. Scoping to $p.DefaultValue is what keeps a rejection
# message elsewhere in the file from registering as a violation.
function Get-RawProviderDefault {
    param([string]$Path)

    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        return @([pscustomobject]@{
            Parameter = '<unparseable>'
            Value     = "$($parseErrors.Count) parse error(s)"
            Line      = $parseErrors[0].Extent.StartLineNumber
        })
    }

    $found = @()
    if (-not $ast.ParamBlock) { return $found }

    foreach ($p in $ast.ParamBlock.Parameters) {
        if ($null -eq $p.DefaultValue) { continue }
        $text = $p.DefaultValue.Extent.Text
        if ($text -match '\.r2\.dev') {
            $found += [pscustomobject]@{
                Parameter = $p.Name.VariablePath.UserPath
                Value     = $text
                Line      = $p.DefaultValue.Extent.StartLineNumber
            }
        }
    }
    return $found
}

function Get-ParamDefault {
    param([string]$Path, [string]$ParamName)

    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if (-not $ast.ParamBlock) { return $null }

    foreach ($p in $ast.ParamBlock.Parameters) {
        if ($p.Name.VariablePath.UserPath -eq $ParamName) {
            if ($null -eq $p.DefaultValue) { return $null }
            return $p.DefaultValue.Extent.Text.Trim('"', "'")
        }
    }
    return $null
}

Write-Host "==> Distribution endpoint invariants" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
Write-Host "`nTEST 1: no tracked script defaults to a raw provider endpoint"
$allScripts = Get-ChildItem -Path $scriptsDir -Filter *.ps1 -File | Sort-Object Name
Assert-True "scripts/ contains scripts to check" ($allScripts.Count -gt 0) "found $($allScripts.Count)"
foreach ($s in $allScripts) {
    $violations = @(Get-RawProviderDefault -Path $s.FullName)
    $detail = ($violations | ForEach-Object { "line $($_.Line): `$$($_.Parameter) = $($_.Value)" }) -join '; '
    Assert-True "$($s.Name) has no raw .r2.dev parameter default" ($violations.Count -eq 0) $detail
}

# ---------------------------------------------------------------------------
Write-Host "`nTEST 2: Verify-PublicSite.ps1 uses the canonical distribution host"
$vps = Join-Path $scriptsDir 'Verify-PublicSite.ps1'
Assert-True "Verify-PublicSite.ps1 exists" (Test-Path $vps)
foreach ($name in @('ApkUrl', 'ShaUrl')) {
    $val = Get-ParamDefault -Path $vps -ParamName $name
    Assert-True "`$$name default is set" ($null -ne $val)
    Assert-True "`$$name default uses downloads.theprooffoundry.com" ($val -like 'https://downloads.theprooffoundry.com/*') "got: $val"
    Assert-True "`$$name default carries no raw provider host" ($val -notmatch '\.r2\.dev') "got: $val"
}

# ---------------------------------------------------------------------------
Write-Host "`nTEST 3: script defaults agree with canonical manifest URLs"
Assert-True "site-manifest.json exists" (Test-Path $manifestPath)
$manifestText = Get-Content $manifestPath -Raw
$apkDefault = Get-ParamDefault -Path $vps -ParamName 'ApkUrl'
$shaDefault = Get-ParamDefault -Path $vps -ParamName 'ShaUrl'
# Cross-file agreement, not just a hostname check: catches the case where the
# host is corrected but the version silently drifts from the shipped manifest.
Assert-True "ApkUrl default appears verbatim in site-manifest.json" ($manifestText -like "*$apkDefault*") "missing: $apkDefault"
Assert-True "ShaUrl default appears verbatim in site-manifest.json" ($manifestText -like "*$shaDefault*") "missing: $shaDefault"
Assert-True "manifest declares no raw provider download URL" ($manifestText -notmatch '"(downloadUrl|sha256Url)"\s*:\s*"[^"]*\.r2\.dev')

# ---------------------------------------------------------------------------
Write-Host "`nTEST 4: the guard actually fires on a reintroduced raw endpoint"
$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("pf-dist-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
try {
    $single = Join-Path $fixtureDir 'single.ps1'
    Set-Content -Path $single -Encoding utf8 -Value @'
param(
    [string]$ApkUrl = "https://pub-deadbeef.r2.dev/forgecast/v9.9.9/App.apk"
)
Write-Host $ApkUrl
'@
    $v1 = @(Get-RawProviderDefault -Path $single)
    Assert-True "single-string raw default is detected" ($v1.Count -eq 1) "detected $($v1.Count)"
    Assert-True "detection names the offending parameter" ($v1.Count -eq 1 -and $v1[0].Parameter -eq 'ApkUrl')

    $arr = Join-Path $fixtureDir 'array.ps1'
    Set-Content -Path $arr -Encoding utf8 -Value @'
param(
    [string[]]$Targets = @("https://theprooffoundry.com", "https://pub-deadbeef.r2.dev/x")
)
Write-Host $Targets
'@
    $v2 = @(Get-RawProviderDefault -Path $arr)
    Assert-True "raw endpoint hidden inside an array default is detected" ($v2.Count -eq 1) "detected $($v2.Count)"

    # ---------------------------------------------------------------------------
    Write-Host "`nTEST 5: the guard does not false-positive on non-default mentions"
    $msg = Join-Path $fixtureDir 'message.ps1'
    Set-Content -Path $msg -Encoding utf8 -Value @'
param(
    [string]$Url = "https://downloads.theprooffoundry.com/x/App.apk"
)
# A rejection message naming the banned host is policy, not a violation.
if ($Url -match '\.r2\.dev') { throw "canonical public URL still uses raw .r2.dev provider: $Url" }
'@
    $v3 = @(Get-RawProviderDefault -Path $msg)
    Assert-True "rejection message mentioning .r2.dev is not a violation" ($v3.Count -eq 0) "detected $($v3.Count)"

    $cmt = Join-Path $fixtureDir 'comment.ps1'
    Set-Content -Path $cmt -Encoding utf8 -Value @'
param(
    # historical note: this used to point at pub-x.r2.dev before canonicalization
    [string]$Url = "https://downloads.theprooffoundry.com/x/App.apk"
)
Write-Host $Url
'@
    $v4 = @(Get-RawProviderDefault -Path $cmt)
    Assert-True "comment mentioning .r2.dev is not a violation" ($v4.Count -eq 0) "detected $($v4.Count)"

    Write-Host "`nTEST 6: build-site.ps1 keeps its rejection policy while staying clean"
    $bs = Join-Path $scriptsDir 'build-site.ps1'
    $bsText = Get-Content $bs -Raw
    Assert-True "build-site.ps1 still rejects raw .r2.dev canonical URLs" ($bsText -match 'raw \.r2\.dev provider')
    Assert-True "build-site.ps1 itself has no raw provider default" (@(Get-RawProviderDefault -Path $bs).Count -eq 0)
} finally {
    Remove-Item -Path $fixtureDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
Write-Host "`nTEST 7: explicit override capability is preserved"
$vpsErrors = $null
$vpsTokens = $null
$vpsAst = [System.Management.Automation.Language.Parser]::ParseFile($vps, [ref]$vpsTokens, [ref]$vpsErrors)
Assert-True "Verify-PublicSite.ps1 parses with 0 errors" ($null -eq $vpsErrors -or $vpsErrors.Count -eq 0)
$vpsParams = $vpsAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
foreach ($name in @('Targets', 'ApkUrl', 'ShaUrl', 'ExpectedSha')) {
    Assert-True "`$$name remains an overridable parameter" ($vpsParams -contains $name)
}

# ---------------------------------------------------------------------------
Write-Host "`nTEST 8: verifier Cache Vault expectations derive from canonical site data"
$vpsText = Get-Content $vps -Raw
# Comments are stripped before literal checks, for the same reason TEST 5 exists:
# documenting a superseded value is not the same as asserting it. Only executable
# code can make the verifier disagree with the manifest.
function Get-CodeOnlyText {
    param([string]$Path)
    $parseErrors = $null
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    $kept = $tokens | Where-Object { $_.Kind -ne 'Comment' } | ForEach-Object { $_.Text }
    return ($kept -join ' ')
}
$vpsCode = Get-CodeOnlyText -Path $vps
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$cv = $manifest.products | Where-Object { $_.name -eq 'Cache Vault' }
Assert-True "Cache Vault product exists in manifest" ($null -ne $cv)

# The defect this replaces: the verifier carried its own v0.2.0 version and hash
# literals, so it asserted a release the site had already moved past. Any
# independent literal set can drift again, so the invariant is structural.
Assert-True "verifier loads site-manifest.json" ($vpsText -match "site-manifest\.json")
Assert-True "verifier selects the Windows artifact by platform, not array index" ($vpsText -match "platform\s+-eq\s+'Windows'")
Assert-True "verifier code carries no CacheVault artifact filename literal" ($vpsCode -notmatch 'CacheVault-v[0-9]')
Assert-True "verifier code carries no superseded v0.2.0 Cache Vault hash" ($vpsCode -notmatch '84471c92b84b4414dc59b03170321c388cdf70c4a02918b7294af3c8cde12c12')
Assert-True "verifier code carries no Cache Vault download-label literal" ($vpsCode -notmatch 'Download v[0-9.]+ \\\(Windows\\\)')
# Even the CORRECT hash must not be pinned. Pinning today's correct value is
# exactly how the v0.2.0 literal got there, and it would drift again on v0.2.3.
$cvHashNow = ($manifest.products | Where-Object { $_.name -eq 'Cache Vault' }).sha256
Assert-True "verifier code does not pin even the current Cache Vault hash" ($vpsCode -notmatch [regex]::Escape($cvHashNow)) "found pinned: $cvHashNow"

$cvWin = $cv.artifacts | Where-Object { $_.platform -eq 'Windows' }
Assert-True "manifest declares exactly one Windows artifact" (@($cvWin).Count -eq 1)
Assert-True "Windows artifact sha256 is 64 lowercase hex" ($cvWin.sha256 -cmatch '^[0-9a-f]{64}$') "got: $($cvWin.sha256)"
$pubVer = $cv.release.publicVersion
Assert-True "publicVersion is set" (-not [string]::IsNullOrWhiteSpace($pubVer)) "got: $pubVer"
Assert-True "Windows filename carries publicVersion $pubVer" ($cvWin.filename -like "*$pubVer*") "filename: $($cvWin.filename)"
Assert-True "Windows downloadUrl carries publicVersion $pubVer" ($cvWin.downloadUrl -like "*v$pubVer*") "url: $($cvWin.downloadUrl)"
Assert-True "downloadLabel carries publicVersion $pubVer" ($cv.downloadLabel -like "*$pubVer*") "label: $($cv.downloadLabel)"

# The manifest states the Windows hash and URL twice. Both copies must agree, or
# the page and the verifier can disagree while each is internally consistent.
Assert-True "product-level sha256 matches the Windows artifact sha256" ($cv.sha256 -eq $cvWin.sha256)
Assert-True "product-level downloadUrl matches the Windows artifact downloadUrl" ($cv.downloadUrl -eq $cvWin.downloadUrl)
Assert-True "state label is resolvable from stateLabels" ($null -ne $manifest.stateLabels.PSObject.Properties[$cv.state]) "state: $($cv.state)"

Write-Host "`nTEST 9: the anti-literal guard fires on a reintroduced pin"
$fixtureDir2 = Join-Path ([System.IO.Path]::GetTempPath()) ("pf-cv-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $fixtureDir2 -Force | Out-Null
try {
    $regressed = Join-Path $fixtureDir2 'regressed.ps1'
    Set-Content -Path $regressed -Encoding utf8 -Value @'
$manifest = Get-Content 'site-manifest.json' -Raw | ConvertFrom-Json
Test-UrlContent -ContainsPatterns @("CacheVault-v0.2.0-windows.zip", "84471c92b84b4414dc59b03170321c388cdf70c4a02918b7294af3c8cde12c12")
'@
    $rt = Get-Content $regressed -Raw
    Assert-True "reintroduced filename literal is detected" ($rt -match 'CacheVault-v[0-9]')
    Assert-True "reintroduced stale hash is detected" ($rt -match '84471c92b84b4414dc59b03170321c388cdf70c4a02918b7294af3c8cde12c12')
    Assert-True "guard is not satisfied by merely loading the manifest" (($rt -match 'site-manifest\.json') -and ($rt -match 'CacheVault-v[0-9]'))

    # Precision counterpart: documenting a superseded artifact in a comment is
    # legitimate provenance and must not fail the build.
    $commented = Join-Path $fixtureDir2 'commented.ps1'
    Set-Content -Path $commented -Encoding utf8 -Value @'
# Superseded: CacheVault-v0.2.0-windows.zip, hash 84471c92b84b4414dc59b03170321c388cdf70c4a02918b7294af3c8cde12c12
$manifest = Get-Content 'site-manifest.json' -Raw | ConvertFrom-Json
$cv = $manifest.products | Where-Object { $_.name -eq 'Cache Vault' }
Write-Host $cv.sha256
'@
    $cc = Get-CodeOnlyText -Path $commented
    Assert-True "superseded filename in a comment is not a violation" ($cc -notmatch 'CacheVault-v[0-9]')
    Assert-True "superseded hash in a comment is not a violation" ($cc -notmatch '84471c92b84b4414dc59b03170321c388cdf70c4a02918b7294af3c8cde12c12')
} finally {
    Remove-Item -Path $fixtureDir2 -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
$color = if ($script:failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ===" -ForegroundColor $color
if ($script:failed -gt 0) { exit 1 }
