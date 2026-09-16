# H7C — Shared product-page system & catalog geometry guard
# Targets: Lights Out, Cleanroom, GhostLayer, ForgeCast, ProofShot + Homepage Catalog
[CmdletBinding()]
param(
  [string]$PublicDir = '',
  [string]$Root = ''
)
if (-not $PublicDir) { $PublicDir = Join-Path $PSScriptRoot '..\public' }
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== H7C PRODUCT-PAGE & CATALOG GUARD ===" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0
function Assert-Condition([bool]$condition, [string]$msg) {
  if ($condition) { Write-Host "PASS: $msg" -ForegroundColor Green; $script:passed++ }
  else { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failed++ }
}

$ppCssPath = Join-Path $Root 'product-page.css'
$ppCss = if (Test-Path $ppCssPath) { [IO.File]::ReadAllText($ppCssPath) } else { '' }
$homePath = Join-Path $PublicDir 'index.html'
$homeHtml = if (Test-Path $homePath) { [IO.File]::ReadAllText($homePath) } else { '' }

# 1. Product-specific thematic identity tokens in product-page.css
$themes = @(
  'body.pp-system.product-lights-out',
  'body.pp-system.product-cleanroom',
  'body.pp-system.product-ghostlayer',
  'body.pp-system.product-forgecast',
  'body.pp-system.product-proofshot'
)
foreach ($t in $themes) {
  Assert-Condition ($ppCss -match [regex]::Escape($t)) "product-page.css defines theme selector: $t"
}

# 2. Canonical section hierarchy helper
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

# 3. Test each H7C target product page
$h7cProducts = @(
  @{ Name = 'Lights Out'; Slug = 'lights-out'; PublicVer = 'v11.1.2'; CandidateVer = 'v11.1.3'; Unreleased = $false },
  @{ Name = 'Cleanroom'; Slug = 'cleanroom'; PublicVer = 'v1.0.7'; CandidateVer = 'v1.0.10'; Unreleased = $false },
  @{ Name = 'GhostLayer'; Slug = 'ghostlayer'; PublicVer = 'v0.4.0'; CandidateVer = 'v0.4.0'; Unreleased = $false },
  @{ Name = 'ForgeCast'; Slug = 'forgecast'; PublicVer = 'v0.3.5'; CandidateVer = 'v0.3.5'; Unreleased = $false },
  @{ Name = 'ProofShot'; Slug = 'proofshot'; PublicVer = ''; CandidateVer = 'v1.6.18'; Unreleased = $true }
)

foreach ($p in $h7cProducts) {
  $name = $p.Name
  $slug = $p.Slug
  $file = Join-Path $PublicDir "$slug\index.html"
  if (-not (Test-Path $file)) { $file = Join-Path $PublicDir "$slug.html" }
  Assert-Condition (Test-Path $file) "$name - HTML page exists"
  if (-not (Test-Path $file)) { continue }

  $html = [IO.File]::ReadAllText($file)
  Assert-Condition ($html -match 'class="[^"]*pp-system[^"]*"') "$name - body carries pp-system"
  Assert-Condition ($html -match "product-$slug") "$name - body carries product-$slug identity class"

  # Hierarchy check
  if ($p.Unreleased) {
    Test-Order $html @('id="overview"', 'id="features"', 'id="try-it"', 'pp-story', 'id="download"', 'id="identity"', 'id="proof"', 'id="privacy-data-flow"', 'pp-final-cta') "$name hierarchy"
  } elseif ($slug -eq 'ghostlayer') {
    Test-Order $html @('id="overview"', 'id="features"', 'layer-boundary', 'id="try-it"', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"') "$name hierarchy"
  } else {
    Test-Order $html @('id="overview"', 'id="features"', 'id="try-it"', 'pp-story', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"') "$name hierarchy"
  }

  # Warning visibility & single canonical verify presentation (for public releases with installer/APK)
  if (-not $p.Unreleased) {
    Assert-Condition ($html -match 'class="pp-warning"') "$name - critical warning visible outside disclosures"
  }

  # ProofShot specific truth check
  if ($p.Unreleased) {
    Assert-Condition ($html -match 'HyperSnatch') "$name - engine truth HyperSnatch preserved"
    Assert-Condition ($html -notmatch 'Download ProofShot') "$name - no fake download CTA"
    Assert-Condition ($html -match 'Follow development') "$name - truthful roadmap development CTA present"
  }

  # Technical evidence disclosure closed by default
  Assert-Condition ($html -match '<details class="proof-details">') "$name - technical verification disclosure present"
  Assert-Condition ($html -notmatch '<details class="proof-details"\s+open>') "$name - technical verification disclosure closed by default"
}

# 4. Homepage catalog geometry & card consistency checks
Assert-Condition ($homeHtml -match 'class="products-grid"') "Homepage contains products-grid container"
Assert-Condition ($homeHtml -match 'data-product="cache-vault"') "Homepage card present for Cache Vault"
Assert-Condition ($homeHtml -match 'data-product="lights-out"') "Homepage card present for Lights Out"
Assert-Condition ($homeHtml -match 'data-product="cleanroom"') "Homepage card present for Cleanroom"
Assert-Condition ($homeHtml -match 'data-product="ghostlayer"') "Homepage card present for GhostLayer"
Assert-Condition ($homeHtml -match 'data-product="forgecast"') "Homepage card present for ForgeCast"
Assert-Condition ($homeHtml -match 'data-product="proofshot"') "Homepage card present for ProofShot"

# Unbiased card geometry: ForgeCast & ProofShot do not force 2-column grid span in studio.css
$studioCss = [IO.File]::ReadAllText((Join-Path $PublicDir 'studio.css'))
Assert-Condition ($studioCss -notmatch '\.card-forgecast\{[^}]*grid-column:\s*1\s*/\s*-1') "studio.css does not force full-width grid-column span on ForgeCast card"
Assert-Condition ($studioCss -notmatch '\.card-proofshot\{[^}]*grid-column:\s*1\s*/\s*-1') "studio.css does not force full-width grid-column span on ProofShot card"
Assert-Condition ($studioCss -notmatch 'rotate\(6deg\)') "studio.css does not force tilted 6deg transform on ForgeCast card"

$color = if ($script:failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "=== H7C RESULT: $script:passed passed, $script:failed failed ===" -ForegroundColor $color
if ($script:failed -gt 0) { exit 1 }
