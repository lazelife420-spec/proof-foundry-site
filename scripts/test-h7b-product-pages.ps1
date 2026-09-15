# H7B — Shared product-page system guard (pilots: Reality Gate, Cache Vault)
# Runs against BUILT output. -PublicDir allows negative controls to point at
# mutated copies without touching the real build.
[CmdletBinding()]
param(
  [string]$PublicDir = (Join-Path $PSScriptRoot '..\public'),
  [string]$Root = (Join-Path $PSScriptRoot '..')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== H7B PRODUCT-PAGE SYSTEM GUARD ===" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0
function Assert-Condition([bool]$condition, [string]$msg) {
  if ($condition) { Write-Host "PASS: $msg" -ForegroundColor Green; $script:passed++ }
  else { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failed++ }
}

$rg = [IO.File]::ReadAllText((Join-Path $PublicDir 'reality-gate\index.html'))
$cv = [IO.File]::ReadAllText((Join-Path $PublicDir 'cache-vault\index.html'))
$ppCssPath = Join-Path $Root 'product-page.css'
$ppCss = if (Test-Path $ppCssPath) { [IO.File]::ReadAllText($ppCssPath) } else { '' }

function Test-Order([string]$html, [string[]]$needles, [string]$label) {
  $pos = @()
  foreach ($n in $needles) {
    $i = $html.IndexOf($n)
    if ($i -lt 0) { Assert-Condition $false "$label - missing '$n'"; return }
    $pos += $i
  }
  for ($k = 1; $k -lt $pos.Count; $k++) {
    if ($pos[$k] -le $pos[$k - 1]) { Assert-Condition $false "$label - '$($needles[$k])' out of canonical order"; return }
  }
  Assert-Condition $true "$label - canonical section order holds"
}

$pages = @(
  @{ Name = 'Reality Gate'; Html = $rg },
  @{ Name = 'Cache Vault'; Html = $cv }
)

foreach ($p in $pages) {
  $name = $p.Name
  $html = $p.Html

  # --- system wiring ---
  Assert-Condition ($html -match 'class="[^"]*pp-system') "$($name) - body carries pp-system"
  Assert-Condition ($html -match '/product-page\.css\?v=[a-f0-9]{12}') "$($name) - product-page.css linked with content version token"

  # --- canonical hierarchy ---
  Test-Order $html @('id="overview"', 'id="film"', 'id="features"', 'id="try-it"', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"', 'pp-final-cta') "$name hierarchy"

  # --- hero answers ---
  Assert-Condition ($html -match 'class="pp-status"') "$($name) - hero carries product status/availability row"
  Assert-Condition ([regex]::Match($html, '(?s)id="overview".*?button button-primary.*?href="#download"').Success) "$($name) - hero primary CTA points at the get block"

  # --- evidence hierarchy ---
  Assert-Condition ($html -match '<details class="proof-details">') "$($name) - technical verification disclosure present"
  Assert-Condition ($html -notmatch '<details class="proof-details"[^>]*\sopen') "$($name) - technical verification disclosure closed by default"
  Assert-Condition ($html -notmatch '<details class="pp-sub"[^>]*\sopen') "$($name) - sub-disclosures closed by default"

  # --- onboarding is a visible tier before the technical tier ---
  $onb = $html.IndexOf('id="onboarding"')
  $prf = $html.IndexOf('id="proof"')
  Assert-Condition ($onb -gt 0 -and $prf -gt 0 -and $onb -lt $prf) "$($name) - onboarding tier precedes technical verification tier"
  $onbRegion = $html.Substring($onb, [Math]::Min(6000, $html.Length - $onb))
  Assert-Condition ($onbRegion -match '<dl class="onboarding-list">') "$($name) - onboarding list is directly visible"

  # --- critical warnings never inside a closed disclosure ---
  $dl = $html.IndexOf('id="download"')
  $dlEnd = $html.IndexOf('id="onboarding"')
  $getRegion = $html.Substring($dl, $dlEnd - $dl)
  Assert-Condition ($getRegion -match 'class="pp-warning"') "$($name) - get block carries a visible availability/warning line"
  $warnIdx = $getRegion.IndexOf('class="pp-warning"')
  $firstDetails = $getRegion.IndexOf('<details')
  Assert-Condition ($firstDetails -lt 0 -or $warnIdx -lt $firstDetails) "$($name) - warning line renders outside any disclosure"

  # --- final CTA present with action + support ---
  Assert-Condition ([regex]::Match($html, '(?s)pp-final-cta.*?href="#download".*?href="/support/"').Success) "$($name) - final CTA carries download action and support link"

  # --- no inline styles on pilot pages ---
  $hasInlineStyles = $html -match 'style="'
  Assert-Condition (-not $hasInlineStyles) "$($name) - zero inline style attributes"

  # --- disclosure semantics ---
  $dCount = ([regex]::Matches($html, '<details')).Count
  $sCount = ([regex]::Matches($html, '<summary')).Count
  Assert-Condition ($dCount -eq $sCount) "$($name) - details/summary parity ($dCount details, $sCount summaries)"

  # --- visual media panel & evidence card integrity guard ---
  Assert-Condition ($html -match 'class="pp-story-evidence-card"') "$($name) - story evidence card present"
  Assert-Condition ([regex]::Match($html, '(?s)pp-story-evidence-card.*?pp-evidence-badge.*?pp-evidence-meta').Success) "$($name) - story evidence card renders non-empty badge and metadata"
  Assert-Condition ([regex]::Match($html, '(?s)<figure class="[^"]*story-shot[^"]*">\s*<a[^>]*>\s*<img[^>]*src="[^"]+"[^>]*alt="[^"]+"[^>]*loading="eager"').Success) "$($name) - story media panel contains eager-loaded screenshot"
  if ($html -match 'class="[^"]*guided-tour') {
    Assert-Condition ([regex]::Match($html, '(?s)<div class="tour-screen">\s*<figure class="app-shot">\s*<a[^>]*>\s*<img[^>]*src="[^"]+"[^>]*alt="[^"]+"[^>]*loading="eager"').Success) "$($name) - guided tour panel contains eager-loaded interface screenshot"
  } elseif ($html -match 'class="[^"]*archive-demo') {
    Assert-Condition ([regex]::Match($html, '(?s)<div class="archive-workspace">.*?<div class="sample-clips">').Success) "$($name) - archive demo contains interactive sample workspace"
  }
}

# --- pilot-specific evidence containment ---
Assert-Condition ($rg.IndexOf('Capability &amp; Public Status Matrix') -gt $rg.IndexOf('<details class="proof-details">')) "RG - capability matrix lives inside the technical disclosure"
Assert-Condition (([regex]::Matches($rg, '<details class="pp-sub"')).Count -ge 5) "RG - at least 5 named sub-disclosures in technical tier"
Assert-Condition ($rg -match 'id="origin"') "RG - origin narrative retained"
Assert-Condition ($rg.IndexOf('id="origin"') -gt $rg.IndexOf('id="try-it"')) "RG - origin narrative no longer precedes how-it-works"
Assert-Condition ($cv.IndexOf('Current limitations &amp; release state') -gt $cv.IndexOf('<details class="proof-details">')) "CV - limitations live inside technical disclosure"
Assert-Condition (([regex]::Matches($cv, '<details class="pp-sub"')).Count -ge 2) "CV - at least 2 named sub-disclosures in technical tier"
Assert-Condition ($cv -match 'id="faq"') "CV - FAQ retained in support tier"
Assert-Condition ($cv.IndexOf('id="faq"') -gt $cv.IndexOf('id="download"')) "CV - FAQ sits in support tier after get block"

# --- truth anchoring ---
Assert-Condition ($cv -match 'https://downloads\.theprooffoundry\.com/cache-vault/v0\.2\.3/CacheVault-v0\.2\.3-windows\.zip') "CV - v0.2.3 Windows ZIP URL intact"
$cvShaMatches = ([regex]::Matches($cv, '28262e491ad1f7b3f6f4c9f28eabfe2899a61af7c7a26c17c4915d604e00371d')).Count
Assert-Condition ($cvShaMatches -eq 2) "CV - v0.2.3 SHA-256 rendered by exactly one canonical verify block"
Assert-Condition ($cv -match 'v0\.2\.3 is the current public Windows release') "CV - final public release state intact"
Assert-Condition ($rg -match 'Download v1\.1\.0 Developer Pilot') "RG - canonical pilot download action intact"

# --- shared stylesheet integrity ---
Assert-Condition ($ppCss -match '(?s)@media \(max-width: 700px\).*?\.pp-onboard \.onboarding-list') "product-page.css - mobile single-column onboarding rule present"
Assert-Condition ($ppCss -match '(?s)@media \(max-width: 900px\).*?\.pp-hero-layout') "product-page.css - mobile single-column hero rule present"
Assert-Condition ($ppCss -match 'word-break: break-all') "product-page.css - hash values wrap instead of overflowing"
Assert-Condition ($ppCss -match '\.pp-sub > summary:focus-visible') "product-page.css - keyboard focus-visible styles present"

$passCount = $script:passed
$failCount = $script:failed
$resultColor = if ($failCount -eq 0) { 'Green' } else { 'Red' }
Write-Host "=== H7B RESULT: $passCount passed, $failCount failed ===" -ForegroundColor $resultColor
if ($failCount -gt 0) { exit 1 }
exit 0
