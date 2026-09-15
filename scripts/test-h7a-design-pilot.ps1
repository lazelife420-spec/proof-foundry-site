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
Assert-Condition ($cardTemplate -notmatch 'card-topline') 'source: card template drops the old topline row'
Assert-Condition (([regex]::Matches($outputHome, '<details class="card-more">')).Count -eq 6) 'output: all six cards render the details disclosure'
Assert-Condition ($outputHome -notmatch 'card-topline') 'output: no card renders the old topline row'
Assert-Condition ($sourceHome -match 'data-catalog-toggle') 'source: catalog curation toggle is present'
Assert-Condition ($outputHome -match 'data-catalog-toggle' -and $outputHome -match 'See all 7 tools') 'output: catalog curation toggle survives build'
Assert-Condition ($signature -match '\.signature-home \.catalog-toggle') 'source: catalog toggle styles exist'
Assert-Condition ($signature -match '(?s)@media \(max-width: 700px\)\s*\{\s*\.signature-home \.catalog-toggle') 'source: catalog toggle only appears at small widths'
Assert-Condition ($experienceJs -match 'data-catalog-toggle' -and $experienceJs -match 'matchMedia\(''\(max-width: 700px\)''\)') 'source: mobile curation is runtime-driven and viewport-gated'
Assert-Condition ($outputExperienceJs -match 'data-catalog-toggle') 'output: curation logic survives build'
# No-JS invariants (NC-3): without JavaScript every product stays accessible.
# Curation may only ever happen at runtime; nothing may ship pre-hidden.
Assert-Condition ($cardTemplate -notmatch '<article hidden') 'source: card template never ships pre-hidden products'
Assert-Condition (($outputHome -notmatch '<article[^>]*\shidden[\s>][^>]*class="product-card') -and ($outputHome -notmatch '<article[^>]*class="product-card[^>]*"[^>]*\shidden[\s>]')) 'output: no generated product card is hidden by default'
Assert-Condition ($sourceHome -match 'class="catalog-toggle" data-catalog-toggle aria-expanded="false" aria-controls="products" hidden') 'source: curation toggle ships hidden so no-JS visitors see the full catalog'
Assert-Condition ($sourceHome -match 'Find your next tool\.') 'source: catalog has an editorial product-first heading'
Assert-Condition ($sourceHome -match 'Know what you are downloading\.') 'source: proof is concise and subordinate'
Assert-Condition ($sourceHome -match 'Find the right tool\.') 'source: homepage ends with one clear product invitation'
Assert-Condition ($sourceHome -notmatch 'hero-signals|home-reassurance') 'source: hero removes competing secondary signals'
Assert-Condition ($sourceHome -match 'theater-controls" hidden') 'source: legacy theater choices remain non-competing'
Assert-Condition ($outputHome -match 'Find your next tool\.' -and $outputHome -match 'Find the right tool\.') 'output: product discovery and final CTA survive build'
Assert-Condition ($experience -match '\.layer-number\{font:9px Consolas,monospace;color:#969eb5;letter-spacing:\.14em\}') 'source: GhostLayer contrast color is corrected'
Assert-Condition ($outputExperience -match '\.layer-number\{font:9px Consolas,monospace;color:#969eb5;letter-spacing:\.14em\}') 'output: GhostLayer contrast color survives build'
Assert-Condition ($layerRatio -ge 4.5) ("WCAG AA: GhostLayer layer number contrast is {0:N2}:1 (>= 4.50:1)" -f $layerRatio)

Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
