# H7A homepage-pilot and GhostLayer contrast regression guard.
# Runs against source and generated output. No network.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$public = Join-Path $root 'public'

$files = @{
  SourceHome = Join-Path $root 'index.html'
  OutputHome = Join-Path $public 'index.html'
  SourceSignature = Join-Path $root 'signature.css'
  OutputSignature = Join-Path $public 'signature.css'
  SourceExperience = Join-Path $root 'experience.css'
  OutputExperience = Join-Path $public 'experience.css'
  CardTemplate = Join-Path $root 'partials\product-card.html'
  SourceExperienceJs = Join-Path $root 'experience.js'
  OutputExperienceJs = Join-Path $public 'experience.js'
}

foreach ($path in $files.Values) {
  if (-not (Test-Path $path)) { throw "Required file missing: $path" }
}

$sourceHome = Get-Content -LiteralPath $files.SourceHome -Raw -Encoding UTF8
$outputHome = Get-Content -LiteralPath $files.OutputHome -Raw -Encoding UTF8
$sourceCatalog = Get-Content (Join-Path $root 'software.html') -Raw -Encoding UTF8
$outputCatalog = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$signature = Get-Content -LiteralPath $files.SourceSignature -Raw -Encoding UTF8
$outputSignature = Get-Content -LiteralPath $files.OutputSignature -Raw -Encoding UTF8
$experience = Get-Content -LiteralPath $files.SourceExperience -Raw -Encoding UTF8
$outputExperience = Get-Content -LiteralPath $files.OutputExperience -Raw -Encoding UTF8
$cardTemplate = Get-Content -LiteralPath $files.CardTemplate -Raw -Encoding UTF8
$experienceJs = Get-Content -LiteralPath $files.SourceExperienceJs -Raw -Encoding UTF8
$outputExperienceJs = Get-Content -LiteralPath $files.OutputExperienceJs -Raw -Encoding UTF8

$script:passed = 0
$script:failed = 0

function Assert-Condition([bool]$condition, [string]$label) {
  if ($condition) {
    $script:passed++
    Write-Host "PASS: $label" -ForegroundColor Green
  } else {
    $script:failed++
    Write-Host "FAIL: $label" -ForegroundColor Red
  }
}

function Get-RelativeLuminance([string]$hex) {
  $channels = @(0, 2, 4 | ForEach-Object {
    [Convert]::ToInt32($hex.Substring($_ + 1, 2), 16) / 255.0
  } | ForEach-Object {
    if ($_ -le 0.04045) { $_ / 12.92 } else { [Math]::Pow(($_ + 0.055) / 1.055, 2.4) }
  })
  return (0.2126 * $channels[0]) + (0.7152 * $channels[1]) + (0.0722 * $channels[2])
}

function Get-ContrastRatio([string]$foreground, [string]$background) {
  $a = Get-RelativeLuminance $foreground
  $b = Get-RelativeLuminance $background
  return ([Math]::Max($a, $b) + 0.05) / ([Math]::Min($a, $b) + 0.05)
}

$layerRatio = Get-ContrastRatio '#969eb5' '#2b2d3b'

Assert-Condition ($signature -match 'H7A.*PROFESSIONAL DESIGN SYSTEM \+ HOMEPAGE PILOT') 'source: H7A design-system layer is present'
Assert-Condition ($outputSignature -match 'H7A.*PROFESSIONAL DESIGN SYSTEM \+ HOMEPAGE PILOT') 'output: H7A design-system layer is present'
Assert-Condition ($signature -match '--h7a-space-7:\s*5\.5rem') 'source: compact spacing scale is defined'
Assert-Condition ($signature -match '--h7a-accent:\s*#e4b85f') 'source: one core brand accent is defined'
Assert-Condition ($signature -match '(?s)\.signature-home \.product-card.*?border-radius:\s*8px') 'source: homepage card radius is deliberate'
Assert-Condition ($signature -match 'H7A-R.*OWNER REFINEMENT: SIMPLER CARDS \+ CURATED MOBILE CATALOG') 'source: H7A-R refinement layer is present'
Assert-Condition ($outputSignature -match 'H7A-R.*OWNER REFINEMENT: SIMPLER CARDS \+ CURATED MOBILE CATALOG') 'output: H7A-R refinement layer survives build'
Assert-Condition ($cardTemplate -match '<details class="card-more"><summary>Details</summary>') 'source: card template puts secondary facts behind native disclosure'
# VR1: platform, release state and version moved into a visible meta row; the
# Details disclosure now only renders when a product carries a caveat line.
Assert-Condition ($cardTemplate -match 'class="h9-card-meta"' -and $cardTemplate -match 'card-platform' -and $cardTemplate -match 'card-availability') 'source: card template exposes platform and release state in a visible meta row'
Assert-Condition ($cardTemplate -notmatch 'card-topline') 'source: card template drops the old topline row'
Assert-Condition (([regex]::Matches($outputCatalog, '<details class="card-more">')).Count -eq ([regex]::Matches($outputCatalog, 'card-detail')).Count) 'output: card details disclosure renders only where a caveat line exists'
Assert-Condition ($outputCatalog -notmatch 'card-topline') 'output: no software card renders the old topline row'
# H9 moves the entire functional catalog to /software/. The old mobile
# curation toggle is replaced by filters; without JS all seven remain visible.
Assert-Condition ($sourceCatalog -match '<form class="directory-finder" data-directory-finder hidden role="search">') 'source: directory filters are hidden progressive enhancement'
Assert-Condition ($outputCatalog -match 'data-directory-finder hidden role="search"' -and $outputCatalog -match 'name="query"' -and $outputCatalog -match 'name="group"') 'output: directory search and group controls survive build'
Assert-Condition ($signature -match '\.signature-home \.catalog-toggle') 'source: catalog toggle styles exist'
Assert-Condition ($signature -match '(?s)@media \(max-width: 700px\)\s*\{\s*\.signature-home \.catalog-toggle') 'source: catalog toggle only appears at small widths'
Assert-Condition ($experienceJs -match 'data-catalog-toggle' -and $experienceJs -match 'matchMedia\(''\(max-width: 700px\)''\)') 'source: mobile curation is runtime-driven and viewport-gated'
Assert-Condition ($outputExperienceJs -match 'data-catalog-toggle') 'output: curation logic survives build'
# No-JS invariants (NC-3): without JavaScript every product stays accessible.
# Curation may only ever happen at runtime; nothing may ship pre-hidden.
Assert-Condition ($cardTemplate -notmatch '<article hidden') 'source: card template never ships pre-hidden products'
Assert-Condition (($outputCatalog -notmatch '<article[^>]*\shidden[\s>][^>]*class="product-card') -and ($outputCatalog -notmatch '<article[^>]*class="product-card[^>]*"[^>]*\shidden[\s>]')) 'output: no generated software card is hidden by default'
$editorial = Get-Content (Join-Path $root 'site-editorial.json') -Raw | ConvertFrom-Json
Assert-Condition ($sourceCatalog -notmatch 'data-catalog-toggle' -and ([regex]::Matches($outputCatalog, 'data-directory-entry="')).Count -eq @($editorial.entries | Where-Object visible).Count) 'source/output: directory ships the complete visible editorial projection without curation'
Assert-Condition ($sourceCatalog -match '<h1>Tools for the work\.<br>Worlds of their own\.</h1>') 'source: directory has the current product-first heading'
Assert-Condition ($sourceHome -match 'id="chain-title"' -and $sourceHome -match 'Record how it was made\.' -and $sourceHome -match 'Keep the qualifications visible\.' -and $sourceHome -notmatch '@studio-evidence') 'source: proof method scopes build evidence and limitations honestly'
Assert-Condition ($sourceHome -match 'class="ledger-hero"[\s\S]*?href="/software/"' -and $sourceHome -notmatch 'studio-portfolio|data-home-products') 'source: Proof Ledger hero invites visitors to the functional catalog without an embedded selector'
Assert-Condition ($sourceHome -notmatch 'hero-signals|home-reassurance') 'source: hero removes competing secondary signals'
Assert-Condition ($sourceHome -notmatch 'theater-controls|product-finder|data-compare=') 'source: functional catalog controls do not compete with H9 editorial scenes'
Assert-Condition ($outputHome -match 'Real software<br>leaves a record\.' -and $outputHome -match 'Browse Products' -and $outputHome -match 'href="/software/"' -and $outputHome -notmatch 'studio-portfolio|studio-evidence') 'output: main-site headline and directory CTA survive build'
# The GhostLayer layer-number rule moved from experience.css to product-worlds.css with new pane colours.
$layerRule = '.product-ghostlayer .layer-number,.product-ghostlayer .layer-state{font:10px var(--pf-mono);color:#bac9cc}'
$worlds = Get-Content (Join-Path $root 'product-worlds.css') -Raw -Encoding UTF8
$outputWorlds = Get-Content (Join-Path $public 'product-worlds.css') -Raw -Encoding UTF8
Assert-Condition ($worlds.Contains($layerRule) -and $experience -notmatch '\.layer-number\{') 'source: GhostLayer layer number has one active colour rule'
Assert-Condition ($outputWorlds.Contains($layerRule)) 'output: GhostLayer layer number colour survives build'
# Panes are #2c3944c9 over a darker page and #34423b; the opaque base is the lower contrast bound.
foreach ($pane in '#2c3944', '#34423b') {
  $ratio = Get-ContrastRatio '#bac9cc' $pane
  Assert-Condition ($ratio -ge 4.5) ("WCAG AA: GhostLayer layer number contrast on {0} is {1:N2}:1 (>= 4.50:1)" -f $pane, $ratio)
}

Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
