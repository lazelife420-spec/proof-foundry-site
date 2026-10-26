# scripts/test-h8b-continuity-and-discovery.ps1 — Guard test suite for H8-B Trust, Navigation, Continuity & Discovery
[CmdletBinding()]
param(
  [string]$PublicDir = '',
  [string]$Root = ''
)
if (-not $PublicDir) { $PublicDir = Join-Path $PSScriptRoot '..\public' }
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== H8-B TRUST, NAVIGATION, CONTINUITY & DISCOVERY GUARD ===" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0
function Assert-Condition([bool]$condition, [string]$msg) {
  if ($condition) {
    Write-Host "PASS: $msg" -ForegroundColor Green
    $script:passed++
  } else {
    Write-Host "FAIL: $msg" -ForegroundColor Red
    $script:failed++
  }
}

# 1. Check /proof-standard/ and /about/ HTML output files exist
$psPath = Join-Path $PublicDir 'proof-standard\index.html'
$aboutPath = Join-Path $PublicDir 'about\index.html'

Assert-Condition (Test-Path $psPath) "/proof-standard/index.html exists in public output"
Assert-Condition (Test-Path $aboutPath) "/about/index.html exists in public output"

$psHtml = if (Test-Path $psPath) { [IO.File]::ReadAllText($psPath) } else { '' }
$aboutHtml = if (Test-Path $aboutPath) { [IO.File]::ReadAllText($aboutPath) } else { '' }

# 2. Check Proof Standard page content requirements
Assert-Condition ($psHtml -match 'The Proof Standard') "Proof Standard page contains main title"
Assert-Condition ($psHtml -match 'Proof over rented trust') "Proof Standard page contains core positioning slogan"
Assert-Condition ($psHtml -match 'No fake claims\. No missing receipts\. Ship with proof\.') "Proof Standard page contains founder/engineering standard"
Assert-Condition ($psHtml -match 'If it matters, keep the receipt\.') "Proof Standard page contains general proof rule"
Assert-Condition ($psHtml -match 'Unsigned by Windows') "Proof Standard page contains Windows distribution note"
Assert-Condition ($psHtml -match 'Claim only what was measured') "Proof Standard page contains Principle 1"
Assert-Condition ($psHtml -match 'Separate distinct trust dimensions|Separate trust dimensions') "Proof Standard page contains trust dimensions principle"
Assert-Condition ($psHtml -match 'https://theprooffoundry.com/proof-standard/' -and $psHtml -match 'rel="canonical"') "Proof Standard page has correct canonical URL"

# 3. Check About page content requirements
Assert-Condition ($aboutHtml -match 'About The Proof Foundry') "About page contains main title"
Assert-Condition ($aboutHtml -match 'Useful software\. Receipts included\.') "About page uses the master studio slogan"
Assert-Condition ($aboutHtml -match 'Independent Products') "About page contains independent products principle"
Assert-Condition ($aboutHtml -match 'Local-first where product function permits') "About page contains local-first principles"
Assert-Condition ($aboutHtml -match 'Network-dependent functions such as ForgeCast weather transparently send the data required') "About page contains explicit network disclosure"
Assert-Condition ($aboutHtml -match 'Reality Gate') "About page contains Reality Gate role description"
Assert-Condition ($aboutHtml -match 'https://theprooffoundry.com/about/' -and $aboutHtml -match 'rel="canonical"') "About page has correct canonical URL"

# 4. Check Footer and Link Resolution Guards
$footerPath = Join-Path $Root 'partials\footer.html'
$footerText = [IO.File]::ReadAllText($footerPath)
Assert-Condition ($footerText -match 'href="/proof-standard/"') "Footer links Proof Standard to /proof-standard/"
Assert-Condition ($footerText -notmatch 'href="/#proof-standard"') "Footer does NOT link Proof Standard to /#proof-standard"
Assert-Condition ($footerText -match 'href="/about/"') "Footer links About to /about/"

$homeHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'index.html'))
Assert-Condition ($homeHtml -match 'href="/about/"') "Homepage links 'About the Foundry' to /about/"
Assert-Condition ($homeHtml -notmatch 'href="/founders/">About the Foundry') "Homepage does NOT link 'About the Foundry' to /founders/"
Assert-Condition ($homeHtml -match 'href="/proof-standard/"') "Homepage links Proof Standard to /proof-standard/"

$foundersHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'founders\index.html'))
Assert-Condition ($foundersHtml -match 'href="/proof-standard/"') "Founders page links Proof Standard to /proof-standard/"
Assert-Condition ($foundersHtml -match 'Business Model &amp; Founder Boundary|Business Model & Founder Boundary') "Founders page contains Business Model & Founder Boundary heading"
Assert-Condition ($foundersHtml -notmatch 'Business Model &amp; Founder Terms|Business Model & Founder Terms') "Founders page does NOT use overly broad Founder Terms heading"
Assert-Condition ($foundersHtml -notmatch '\$99|\$49|lifetime license|perpetual update') "Founders page does NOT introduce unbacked commercial price claims"

# 5. Check Support page fixes
$supportHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'support\index.html'))
Assert-Condition ($supportHtml -match 'Structural page-resource capture') "Support page uses structural capture wording for ProofShot"
Assert-Condition ($supportHtml -notmatch 'Visual capture and proof stamp suite') "Support page does NOT use stale visual capture description for ProofShot"
Assert-Condition ($supportHtml -notmatch 'Product-specific privacy and data-flow details are being documented') "Support page removed stale privacy documentation sentence"
Assert-Condition ($supportHtml -match 'href="/proof-standard/"') "Support page links Proof Standard to /proof-standard/"

# 6. Check Roadmap continuity expansions & controls
$roadmapHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'roadmap\index.html'))
Assert-Condition ($roadmapHtml -match 'ProofBound') "Roadmap includes ProofBound lineage"
Assert-Condition ($roadmapHtml -match 'Sound Assist') "Roadmap includes Sound Assist lineage"
Assert-Condition ($roadmapHtml -match 'RECEIPT Desktop') "Roadmap includes RECEIPT Desktop historical lineage"
Assert-Condition ($roadmapHtml -match 'Platform directions') "Roadmap includes Platform directions section"
Assert-Condition ($roadmapHtml -notmatch '<details class="proof-details[^"]*"\s+open') "Roadmap directions details details tag is closed by default"
Assert-Condition ($roadmapHtml -match 'future public Store/catalog direction building on today') "Roadmap contains corrected Website Storefront copy"

# 7. Check Sitemap and Redirects
$sitemapText = [IO.File]::ReadAllText((Join-Path $PublicDir 'sitemap.xml'))
Assert-Condition ($sitemapText -match 'https://theprooffoundry\.com/about/') "Sitemap contains /about/ route"
Assert-Condition ($sitemapText -match 'https://theprooffoundry\.com/proof-standard/') "Sitemap contains /proof-standard/ route"

$requiredRoutes = @('/', '/about/', '/proof-standard/', '/reality-gate/', '/cache-vault/', '/lights-out/', '/cleanroom/', '/ghostlayer/', '/forgecast/', '/proofshot/', '/founders/', '/proof/', '/roadmap/', '/support/')
$sitemapParseable = $true
try { [xml]$sitemapXml = $sitemapText } catch { $sitemapParseable = $false }
Assert-Condition $sitemapParseable "Sitemap parses as XML"
$sitemapEntries = if ($sitemapParseable) { @($sitemapXml.urlset.url) } else { @() }
$sitemapLocs = @($sitemapEntries | ForEach-Object { ([string]$_.loc).Trim() })
Assert-Condition ($sitemapEntries.Count -eq 24) "Sitemap preserves the 24-route inventory"
Assert-Condition (@($sitemapLocs | Sort-Object -Unique).Count -eq $sitemapLocs.Count) "Sitemap route identities contain no duplicates"
$requiredRouteCoverage = $true
foreach ($r in $requiredRoutes) {
  $expectedLoc = "https://theprooffoundry.com$r"
  if (@($sitemapLocs | Where-Object { $_ -ceq $expectedLoc }).Count -ne 1) { $requiredRouteCoverage = $false }
}
Assert-Condition $requiredRouteCoverage "Sitemap preserves required continuity routes"

# H8-B enforces the shared date floor and parseability only. H4 owns exact
# route-to-content-input lastmod matching, including module-generated routes.
$parsedLastmods = @()
$allLastmodsParseable = ($sitemapEntries.Count -eq 24)
foreach ($entry in $sitemapEntries) {
  $dateText = ([string]$entry.lastmod).Trim()
  try {
    $parsedDate = [DateTime]::ParseExact($dateText, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    if ($parsedDate.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) -cne $dateText) { $allLastmodsParseable = $false }
    $parsedLastmods += $parsedDate.Date
  } catch {
    $allLastmodsParseable = $false
  }
}
Assert-Condition ($allLastmodsParseable -and $parsedLastmods.Count -eq 24) "Every sitemap route has one parseable ISO lastmod date"
$dateFloor = [DateTime]::ParseExact('2026-09-17', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$todayUtc = [DateTime]::UtcNow.Date
$monotonicDates = ($allLastmodsParseable -and $parsedLastmods.Count -eq 24)
foreach ($date in $parsedLastmods) {
  if ($date -lt $dateFloor -or $date -gt $todayUtc) { $monotonicDates = $false }
}
Assert-Condition $monotonicDates "Sitemap lastmod dates meet the shared freshness floor (2026-09-17) and are not future-dated"

$redirectsText = [IO.File]::ReadAllText((Join-Path $PublicDir '_redirects'))
Assert-Condition ($redirectsText -match '/about\s+/about/') "_redirects contains /about 301 rule"
Assert-Condition ($redirectsText -match '/proof-standard\s+/proof-standard/') "_redirects contains /proof-standard 301 rule"

# 8. Check Lights Out data-nosnippet hardening
$loHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'lights-out\index.html'))
Assert-Condition ($loHtml -notmatch '<div class="evidence-content"\s+data-nosnippet') "Lights Out top evidence-content container does NOT have broad data-nosnippet"
Assert-Condition ($loHtml -match 'id="evidence-release-status"\s+data-nosnippet') "Lights Out candidate release-status container HAS narrow data-nosnippet"

# 9. Output Hygiene check
$publicFiles = @(Get-ChildItem -LiteralPath $PublicDir -Recurse -File -Force)
$publicRoot = (Resolve-Path -LiteralPath $PublicDir).Path.TrimEnd('\', '/')
function Get-PublicRelativePath([IO.FileInfo]$file) { return $file.FullName.Substring($publicRoot.Length).TrimStart('\', '/').Replace('\', '/') }
$textExtensions = @('.html', '.js', '.css', '.json', '.xml', '.txt', '.md', '.svg', '')
$leaks = @()
foreach ($file in $publicFiles) {
  if ($file.Extension.ToLowerInvariant() -in $textExtensions) {
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($content -match 'file:///' -or $content -match '(?i)[a-z]:(?:\\|/)+users(?:\\|/)') {
      $leaks += (Get-PublicRelativePath $file)
    }
  }
}
Assert-Condition ($leaks.Count -eq 0) "Public output contains zero file:/// or C:\Users\ local path leaks"

# K1 (C-01): 25 captures that showed a workstation identifier (a Windows
# user-profile path or the machine name) were retired. None may be published
# again, under its own path, its file name or its source stem, or as the same
# bytes under another name, and no published text may reference one by path or
# stem. 'cases' is too generic for a stem match, so cases.png is held by its
# path, file name and digest. Every raster must be what its extension says.
$retiredCaptures = [ordered]@{
  'assets/proofshot/workbench-proof-cards.png'         = 'd18c63f872a56eb593d97cf523357cd73c41a2b26bd6d3839fa1ab91c9d8f3e6'
  'assets/proofshot/workbench-proof-cards.webp'        = '80bd8137f7d8e9f301626f801d8b25afef581e40d27a4c4d5129b910360132f4'
  'assets/studio/workbench-proof-cards-480.webp'       = '19f412a08bfcaea8cb491560d914fdca589924658c628d982eba92887c05a1dd'
  'assets/studio/workbench-proof-cards-960.webp'       = '180a1ff1298d987ab6dda9e1bbd727af12b2ba7fe9c3bbe99a6e630c20b0d2d5'
  'assets/studio/workbench-proof-cards-1440.webp'      = '071cc1b8a88dc1cb6ca7fba81180622a0b083a7e6f9ac07466d815f6fa638ddb'
  'assets/proofshot/workbench-home.png'                = '33ca336d7eecc517a9a1e6caa7ac46f97da8b630342dc6b19477ca57d5baee80'
  'assets/studio/workbench-home-480.webp'              = '3a4a86b881c3fc4a7c6cab9c1272b6684be665b31abd01c264186bfc74933b41'
  'assets/studio/workbench-home-960.webp'              = '10503a6c027905089c1ba4d4c526de467aeafbe4b370000d511b70b5fef6eedd'
  'assets/studio/workbench-home-1440.webp'             = 'ceeceea851270476cee28c54c490de87e358568ee228b0d0334956bfa7414e0f'
  'assets/studio/workbench-home-card-960.png'          = 'fe390305617449c16347708617be38518a538c3bb601eb44ebf825b38e1bdbd3'
  'assets/proofshot/export-complete.png'               = '151c663af9ad2b8d666b45b28492f401fd106869e7934c433c469ba9b307342e'
  'assets/studio/export-complete-480.webp'             = '8afabf7808977f2eb13b61096da9d0d97c6e72c133dd4a6c0aa107e8f87b775e'
  'assets/studio/export-complete-960.webp'             = '059513e3cfe9215d4cac34c80f6cd81b0d3f497fd006b12ac9a4836918b7b6bc'
  'assets/studio/export-complete-1440.webp'            = '08fb0acbeff5f1cecf994d2a7164ebbc940c8427686ddbce3b8a8972d7600dbd'
  'assets/proofshot/prove-again.png'                   = '1bfcf6038c60f01ee9cdade207944d75ddbfcf1af8983dd3cb810e64accf545e'
  'assets/proofshot/cases.png'                         = '9ec331f1f3fdddc760955ccc718eefb4f133bea1f6855d413e30b355b541041d'
  'assets/proofshot/tamper-trial.png'                  = '4dcbf5ad8ed936300b05640a9091a83120469b219bd5eb690e7544a0118c3899'
  'assets/cleanroom/cleanroom-activity-ledger.png'     = '6fce31f77ed39496e679912bff260b451a9fcbffe96e68ff77a2ca5ceccad65e'
  'assets/studio/cleanroom-activity-ledger-480.webp'   = '28380cdbde3e28e7f78f5fec4c70a2016170e5b2ff24492c4827aae40943dcab'
  'assets/studio/cleanroom-activity-ledger-960.webp'   = '89c9ba91eba9bcf20b6b014d98a97cffcb3bef920a23a6d49c82e0419a592059'
  'assets/studio/cleanroom-activity-ledger-1280.webp'  = 'ac400f06d757a6bc3d276fa1c8297bf97261d443149e08150cf7e78e2299bf04'
  'assets/lights-out/companion-active.png'             = '121c248557713b48bd12e82cfb2eb2ce29092347d83647e773a18b027b2c9587'
  'assets/studio/companion-active-390.webp'            = '2681e3e3e426cb1659ac59927e6a558b66f38e21066c9aea05e34290610d3f10'
  'assets/lights-out/companion-reconnected.png'        = 'cd92ae548b4a369bb38619b1e816018b83a99518d569c0226e2f7f1fc8ed76cf'
  'assets/lights-out/companion-snoozed.png'            = '925617342c0cce32494475545179380b8599da649c6fcfaef5fa03ef9bb8ea8d'
}
$retiredPaths = @($retiredCaptures.Keys)
$retiredDigests = @($retiredCaptures.Values)
Assert-Condition ($retiredPaths.Count -eq 25 -and @($retiredPaths | Sort-Object -Unique).Count -eq 25 -and @($retiredDigests | Where-Object { $_ -cmatch '^[0-9a-f]{64}$' } | Sort-Object -Unique).Count -eq 25) "Retired-capture denylist holds 25 distinct paths and 25 distinct SHA-256 values"
$retiredNames = @($retiredPaths | ForEach-Object { ($_ -split '/')[-1] })
$retiredStems = 'workbench-proof-cards|workbench-home|export-complete|prove-again|tamper-trial|cleanroom-activity-ledger|companion-active|companion-reconnected|companion-snoozed'
$retiredStemFilePattern = '(?i)(?:^|/)(?:' + $retiredStems + ')[^/]*$'
$retiredStemTextPattern = '(?i)(?:' + $retiredStems + ')[-.\w]*\.(?:png|webp|jpe?g|avif|gif)'
$retiredByPath = @($publicFiles | ForEach-Object { Get-PublicRelativePath $_ } | Where-Object { ($retiredPaths -contains $_) -or ($retiredNames -contains (($_ -split '/')[-1])) -or ($_ -match $retiredStemFilePattern) })
if ($retiredByPath.Count -gt 0) { $retiredByPath | ForEach-Object { Write-Host "  retired capture published: $_" } }
Assert-Condition ($publicFiles.Count -gt 0 -and $retiredByPath.Count -eq 0) "Public output publishes none of the 25 retired captures by path, file name or stem"
$retiredByBytes = @($publicFiles | Where-Object { $retiredDigests -contains (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() } | ForEach-Object { Get-PublicRelativePath $_ })
if ($retiredByBytes.Count -gt 0) { $retiredByBytes | ForEach-Object { Write-Host "  retired capture bytes published as: $_" } }
Assert-Condition ($publicFiles.Count -gt 0 -and $retiredByBytes.Count -eq 0) "Public output publishes none of the 25 retired captures by SHA-256, under any name"
$retiredReferences = @()
foreach ($file in $publicFiles) {
  if ($file.Extension.ToLowerInvariant() -in $textExtensions) {
    $content = [IO.File]::ReadAllText($file.FullName)
    foreach ($path in $retiredPaths) {
      if ($content.IndexOf($path, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $retiredReferences += ((Get-PublicRelativePath $file) + ' -> ' + $path) }
    }
    if ($content -match $retiredStemTextPattern) { $retiredReferences += ((Get-PublicRelativePath $file) + ' -> stem') }
  }
}
if ($retiredReferences.Count -gt 0) { $retiredReferences | ForEach-Object { Write-Host "  retired capture referenced: $_" } }
Assert-Condition ($retiredReferences.Count -eq 0) "No published text references a retired capture path or stem"

function Get-AsciiAt([byte[]]$bytes, [int]$offset, [int]$length) {
  if ($bytes.Length -lt $offset + $length) { return '' }
  return [Text.Encoding]::ASCII.GetString($bytes, $offset, $length)
}
function Test-RasterSignature([string]$extension, [byte[]]$head) {
  switch ($extension.ToLowerInvariant()) {
    '.png'  { return ($head.Length -ge 8 -and $head[0] -eq 0x89 -and (Get-AsciiAt $head 1 3) -ceq 'PNG' -and $head[4] -eq 0x0D -and $head[5] -eq 0x0A -and $head[6] -eq 0x1A -and $head[7] -eq 0x0A) }
    '.jpg'  { return ($head.Length -ge 3 -and $head[0] -eq 0xFF -and $head[1] -eq 0xD8 -and $head[2] -eq 0xFF) }
    '.jpeg' { return ($head.Length -ge 3 -and $head[0] -eq 0xFF -and $head[1] -eq 0xD8 -and $head[2] -eq 0xFF) }
    '.webp' { return ((Get-AsciiAt $head 0 4) -ceq 'RIFF' -and (Get-AsciiAt $head 8 4) -ceq 'WEBP') }
    '.avif' { return ((Get-AsciiAt $head 4 4) -ceq 'ftyp' -and (Get-AsciiAt $head 8 4) -cin @('avif', 'avis')) }
    '.gif'  { return ((Get-AsciiAt $head 0 6) -cin @('GIF87a', 'GIF89a')) }
  }
  return $false
}
$pngHead = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D)
$jpegHead = [byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01)
$webpHead = [byte[]](0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50)
Assert-Condition ((Test-RasterSignature '.png' $pngHead) -and -not (Test-RasterSignature '.png' $jpegHead) -and (Test-RasterSignature '.jpg' $jpegHead) -and (Test-RasterSignature '.webp' $webpHead) -and -not (Test-RasterSignature '.webp' $pngHead) -and -not (Test-RasterSignature '.png' ([byte[]]::new(0)))) "Raster signature check accepts PNG, JPEG and WebP headers and rejects JPEG bytes named .png (self-test)"
$rasterExtensions = @('.png', '.webp', '.jpg', '.jpeg', '.avif', '.gif')
$rasters = @($publicFiles | Where-Object { $_.Extension.ToLowerInvariant() -in $rasterExtensions })
$rasterMismatches = @()
foreach ($file in $rasters) {
  $bytes = [IO.File]::ReadAllBytes($file.FullName)
  $head = [byte[]]::new([Math]::Min(12, $bytes.Length))
  [Array]::Copy($bytes, $head, $head.Length)
  if (-not (Test-RasterSignature $file.Extension $head)) { $rasterMismatches += (Get-PublicRelativePath $file) }
}
if ($rasterMismatches.Count -gt 0) { $rasterMismatches | ForEach-Object { Write-Host "  raster signature mismatch: $_" } }
Write-Host "  rasters checked: $($rasters.Count)"
Assert-Condition ($rasters.Count -gt 0 -and $rasterMismatches.Count -eq 0) "Every published raster's leading bytes match its extension"

$fgColor = if ($script:failed -eq 0) { "Green" } else { "Red" }
Write-Host "=== H8-B RESULT: $script:passed passed, $script:failed failed ===" -ForegroundColor $fgColor

if ($script:failed -gt 0) {
  exit 1
}
