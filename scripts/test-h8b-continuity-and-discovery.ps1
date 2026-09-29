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
Assert-Condition ($aboutHtml -match 'Build it\. Prove it\. Ship it\.') "About page contains studio slogan"
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
$sitemapValid = $true
foreach ($r in $requiredRoutes) {
  $escapedR = [regex]::Escape($r)
  $matches = [regex]::Matches($sitemapText, "<loc>https://theprooffoundry\.com$escapedR</loc>\s*<lastmod>(\d{4}-\d{2}-\d{2})</lastmod>")
  if ($matches.Count -ne 1) {
    $sitemapValid = $false
  } else {
    $dateStr = $matches[0].Groups[1].Value
    if ($dateStr -lt '2026-09-17' -and ($r -in @('/', '/about/', '/proof-standard/', '/founders/', '/roadmap/', '/proof/', '/support/', '/lights-out/'))) {
      $sitemapValid = $false
    }
  }
}
Assert-Condition $sitemapValid "Sitemap contains valid monotonic lastmod dates (>= 2026-09-17 baseline for modified routes)"
$freshnessMatches = [regex]::Matches($sitemapText, '(?s)<loc>(https://theprooffoundry\.com/?)</loc>\s*<lastmod>(\d{4}-\d{2}-\d{2})</lastmod>')
$freshHomeOnly = $freshnessMatches.Count -eq 1 -and $freshnessMatches[0].Groups[2].Value -eq '2026-09-28' -and ([regex]::Matches($sitemapText, '<lastmod>2026-09-28</lastmod>')).Count -eq 1
Assert-Condition $freshHomeOnly "Sitemap freshness updates only the homepage route for this tranche"

$redirectsText = [IO.File]::ReadAllText((Join-Path $PublicDir '_redirects'))
Assert-Condition ($redirectsText -match '/about\s+/about/') "_redirects contains /about 301 rule"
Assert-Condition ($redirectsText -match '/proof-standard\s+/proof-standard/') "_redirects contains /proof-standard 301 rule"

# 8. Check Lights Out data-nosnippet hardening
$loHtml = [IO.File]::ReadAllText((Join-Path $PublicDir 'lights-out\index.html'))
Assert-Condition ($loHtml -notmatch '<div class="evidence-content"\s+data-nosnippet') "Lights Out top evidence-content container does NOT have broad data-nosnippet"
Assert-Condition ($loHtml -match 'id="evidence-release-status"\s+data-nosnippet') "Lights Out candidate release-status container HAS narrow data-nosnippet"

# 9. Output Hygiene check
$publicFiles = Get-ChildItem -Path $PublicDir -Recurse -File
$leaks = @()
foreach ($file in $publicFiles) {
  if ($file.Extension -in @('.html','.js','.css','.json','.xml')) {
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($content -match 'file:///' -or $content -match 'C:\\Users\\') {
      $leaks += $file.FullName
    }
  }
}
Assert-Condition ($leaks.Count -eq 0) "Public output contains zero file:/// or C:\Users\ local path leaks"

$fgColor = if ($script:failed -eq 0) { "Green" } else { "Red" }
Write-Host "=== H8-B RESULT: $script:passed passed, $script:failed failed ===" -ForegroundColor $fgColor

if ($script:failed -gt 0) {
  exit 1
}
