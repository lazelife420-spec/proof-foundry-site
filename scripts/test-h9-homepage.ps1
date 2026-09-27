$ErrorActionPreference = 'Stop'

$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homePath = Join-Path $public 'index.html'
$softwarePath = Join-Path $public 'software/index.html'

if (-not (Test-Path $homePath)) { throw "Generated homepage missing: $homePath" }
if (-not (Test-Path $softwarePath)) { throw "Generated software route missing: $softwarePath" }

$homeHtml = Get-Content $homePath -Raw -Encoding UTF8
$softwareHtml = Get-Content $softwarePath -Raw -Encoding UTF8
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cv = $manifest.products | Where-Object id -eq 'cache-vault'
$moduleFiles = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object {
  Get-Content (Join-Path $_.FullName 'module.json') -Raw -Encoding UTF8 | ConvertFrom-Json
})

$pass = 0
$fail = 0

function Assert-H9([string]$name, [bool]$condition) {
  if ($condition) {
    $script:pass++
    Write-Host "PASS: $name" -ForegroundColor Green
  } else {
    $script:fail++
    Write-Host "FAIL: $name" -ForegroundColor Red
  }
}

Write-Host "=== H9 HOMEPAGE & CATALOG GUARD ===" -ForegroundColor Cyan

# 1. Core Composition
Assert-H9 'H9 editorial hero exists' ($homeHtml -match 'h9-hero-product')
Assert-H9 'authentic Cache Vault hero media exists' ($homeHtml -match 'cv-quick-paste\.png')
$publicHomepageModules = @($moduleFiles | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' })
$expectedHomepageIds = @(
  @($publicHomepageModules | Where-Object { $_.homepage.tier -eq 'featured' } | Sort-Object { [int]$_.homepage.order } | ForEach-Object id)
  @($publicHomepageModules | Where-Object { $_.homepage.tier -eq 'major' } | Sort-Object { [int]$_.homepage.order } | ForEach-Object id)
  @($publicHomepageModules | Where-Object { $_.homepage.tier -eq 'secondary' } | Sort-Object { [int]$_.homepage.order } | ForEach-Object id)
)
$renderedHomepageIds = @([regex]::Matches($homeHtml, '<(?:section|article)\b(?=[^>]*\bh9-auto-(?:featured|scene|mini)\b)[^>]*\bdata-product="([^"]+)"[^>]*>') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'homepage product placements match module tiers and ordering' (($renderedHomepageIds -join ',') -eq ($expectedHomepageIds -join ','))
Assert-H9 'homepage index uses generic registry placement markers without fixed product markup' (([IO.File]::ReadAllText((Join-Path $root 'index.html')) -match '@homepage-featured') -and $renderedHomepageIds.Count -eq $expectedHomepageIds.Count -and [IO.File]::ReadAllText((Join-Path $root 'index.html')) -notmatch 'data-product="(?:cache-vault|reality-gate|forgecast|lights-out|cleanroom|ghostlayer|proofshot)"')
$forgecastCompact = [regex]::Match($homeHtml, '(?s)<article\b[^>]*data-product="forgecast"[^>]*>.*?</article>').Value
Assert-H9 'ForgeCast is the final compact homepage card' ($renderedHomepageIds[-1] -eq 'forgecast' -and $forgecastCompact -match 'h9-mini h9-auto-mini' -and $forgecastCompact -notmatch 'h9-auto-scene')

# 2. Status Truth
function Test-ProofShotPublic([string]$html) {
  $card = [regex]::Match($html, '(?s)<article\b[^>]*data-product="proofshot".*?</article>').Value
  return ($card -match 'Public v2\.0\.0' -and $card -match 'href="/proofshot/"' -and $card -notmatch 'No public release|Explore development')
}
Assert-H9 'ProofShot homepage card advertises public v2.0.0' (Test-ProofShotPublic $homeHtml)
Assert-H9 'Cache Vault hero advertises public v0.2.4' ($homeHtml -match 'PUBLIC v0\.2\.4')
Assert-H9 'Reality Gate remains featured with withdrawn availability and no download CTA' ($homeHtml -match 'Reality Gate' -and $homeHtml -match 'Withdrawn' -and $homeHtml -match 'downloads currently unavailable' -and $homeHtml -notmatch 'Download Developer Pilot')

# 3. New /software/ Route
Assert-H9 '/software/ route exists' (Test-Path $softwarePath)
$catalogIds = @([regex]::Matches($softwareHtml, '<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$expectedIds = @('cache-vault','reality-gate','forgecast','lights-out','cleanroom','ghostlayer','proofshot')
Assert-H9 '/software/ contains exactly seven distinct product cards' ((($catalogIds | Sort-Object) -join ',') -eq (($expectedIds | Sort-Object) -join ','))
Assert-H9 '/software/ contains filtering controls' ($softwareHtml -match 'product-finder' -or $softwareHtml -match 'finder-intents')
Assert-H9 '/software/ contains comparison UX' ($softwareHtml -match 'compare-choice' -and $softwareHtml -match 'data-compare')
Assert-H9 '/software/ exposes all seven products for comparison' (([regex]::Matches($softwareHtml, 'data-compare=')).Count -eq 7)
Assert-H9 '/software/ ProofShot card uses public release state' ([regex]::Match($softwareHtml, '(?s)<article\b[^>]*data-product="proofshot".*?</article>').Value -match 'data-availability="public-release"')
Assert-H9 '/software/ has exactly one active primary-nav item' (([regex]::Matches($softwareHtml, 'aria-current="page"')).Count -eq 1 -and $softwareHtml -match '<a href="/software/" aria-current="page">Software</a>')
foreach ($page in @(@{Name='homepage';Html=$homeHtml}, @{Name='software';Html=$softwareHtml})) {
  $ids = @([regex]::Matches($page.Html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $missingLabels = @([regex]::Matches($page.Html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-H9 "$($page.Name) aria-labelledby references resolve" ($missingLabels.Count -eq 0)
}
$deadCatalogLinks = @(Get-ChildItem $public -Recurse -Filter *.html | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'href="/#products"' })
Assert-H9 'all generated pages route catalog discovery to /software/ instead of a missing home anchor' ($deadCatalogLinks.Count -eq 0)

# 4. Old Homepage Cleanup
Assert-H9 'old homepage filter/compare database UI is not on /' ($homeHtml -notmatch 'catalog-nav' -and $homeHtml -notmatch 'theater-controls')

# 5. Manifest-driven Proof & Integrity
Assert-H9 'manifest-driven release/version/hash substitution remains intact' ($homeHtml -notmatch '\{\{products\.')
# VR1: the homepage receipt ledger keeps artifact/version/status but raw digests
# and source commits live on the release records and product pages, not here.
Assert-H9 'Proof narrative keeps raw 64-char digests off the homepage' ($homeHtml -notmatch '<dd>[a-f0-9]{64}</dd>')
Assert-H9 'No source commit is rendered or mislabeled on the homepage' ($homeHtml -notmatch '<dt>Source commit</dt>')
Assert-H9 'receipt filename matches current canonical Cache Vault artifact' ($homeHtml -match [regex]::Escape($cv.artifacts[0].filename))
Assert-H9 'receipt SHA-256 stays off the homepage narrative' ($homeHtml -notmatch [regex]::Escape($cv.artifacts[0].sha256))
Assert-H9 'receipt v0.2.4 source commit stays off the homepage narrative' ($homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29')

# 6. Specific Wording & Liability Bounds
Assert-H9 'GhostLayer "zero-trace" claim absent' ($homeHtml -notmatch 'zero-trace')
Assert-H9 'ProofShot "screen capture" wording absent' ($homeHtml -notmatch 'screen capture')
Assert-H9 'ForgeCast privacy/network wording remains bounded' ($homeHtml -match '(?i)recorded weather' -and $homeHtml -match '(?i)network data' -and $homeHtml -match '(?i)no analytics tracking')

# 7. Negative controls exercise the same predicate against mutated in-memory
# content; no source or public file is changed by these controls.
Assert-H9 'NEGATIVE CONTROL: stale ProofShot version is rejected' (-not (Test-ProofShotPublic ($homeHtml.Replace('Public v2.0.0', 'Public v1.6.18'))))
Assert-H9 'NEGATIVE CONTROL: old unreleased ProofShot state is rejected' (-not (Test-ProofShotPublic ($homeHtml.Replace('Public v2.0.0', 'Development · No public release'))))
Assert-H9 'NEGATIVE CONTROL: missing ProofShot product card is rejected' (-not (Test-ProofShotPublic ($homeHtml.Replace('data-product="proofshot"', 'data-product="removed"'))))

if ($fail -gt 0) {
  Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
