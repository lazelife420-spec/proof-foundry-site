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
Assert-H9 'ForgeCast major scene exists' ($homeHtml -match 'v030-today\.png')
Assert-H9 'Reality Gate major scene exists' ($homeHtml -match '08-ci-run-complete\.50deeeef7e10fbe8\.png')
Assert-H9 'all four secondary products exist' (($homeHtml -match 'data-product="ghostlayer"') -and ($homeHtml -match 'data-product="cleanroom"') -and ($homeHtml -match 'data-product="lights-out"') -and ($homeHtml -match 'data-product="proofshot"'))

# 2. Status Truth
function Test-ProofShotPublic([string]$html) {
  $card = [regex]::Match($html, '(?s)<article\b[^>]*data-product="proofshot".*?</article>').Value
  return ($card -match 'Public v2\.0\.0' -and $card -match 'href="/proofshot/"' -and $card -notmatch 'No public release|Explore development')
}
Assert-H9 'ProofShot homepage card advertises public v2.0.0' (Test-ProofShotPublic $homeHtml)
Assert-H9 'Cache Vault hero advertises public v0.2.4' ($homeHtml -match 'PUBLIC v0\.2\.4')
Assert-H9 'Reality Gate remains Developer Pilot' ($homeHtml -match 'Reality Gate' -and $homeHtml -match 'Developer Pilot')

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
Assert-H9 'Proof artifact contains real 64-char SHA-256' ($homeHtml -match '<dd>[a-f0-9]{64}</dd>')
Assert-H9 'Git commit is not mislabeled SHA-256' ($homeHtml -match '<dt>Source commit</dt><dd>[a-f0-9]{40}</dd>')
Assert-H9 'receipt filename matches current canonical Cache Vault artifact' ($homeHtml -match ('<dt>Artifact</dt><dd>' + [regex]::Escape($cv.artifacts[0].filename) + '</dd>'))
Assert-H9 'receipt SHA-256 matches current canonical Cache Vault artifact' ($homeHtml -match ('<dt>SHA-256</dt><dd>' + [regex]::Escape($cv.artifacts[0].sha256) + '</dd>'))
Assert-H9 'receipt source commit matches v0.2.4 canonical receipt' ($homeHtml -match '<dt>Source commit</dt><dd>abbd84462a8165068405cbfcddf4bfaf6b8f6f29</dd>')

# 6. Specific Wording & Liability Bounds
Assert-H9 'GhostLayer "zero-trace" claim absent' ($homeHtml -notmatch 'zero-trace')
Assert-H9 'ProofShot "screen capture" wording absent' ($homeHtml -notmatch 'screen capture')
Assert-H9 'ForgeCast privacy/network wording remains bounded' ($homeHtml -match 'network data where required; the app does not add analytics tracking')

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
