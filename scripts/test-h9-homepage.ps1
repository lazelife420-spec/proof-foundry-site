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
$forgecastHtml = Get-Content (Join-Path $public 'forgecast/index.html') -Raw -Encoding UTF8
$proofshotHtml = Get-Content (Join-Path $public 'proofshot/index.html') -Raw -Encoding UTF8

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

Write-Host "=== CP-0189 HOMEPAGE & CATALOG GUARD ===" -ForegroundColor Cyan

# 1. Core Composition — the approved ledger page is the homepage authority.
Assert-H9 'approved ledger hero exists' ($homeHtml -match 'ledger-hero')
Assert-H9 'machined emblem hero asset exists' ($homeHtml -match 'PF_MARK_G_TI_460\.webp')
Assert-H9 'record-chain composition exists' ($homeHtml -match 'ledger-chain' -and $homeHtml -match 'pfa-machine')
Assert-H9 'homepage makes no per-product claims' ($homeHtml -notmatch 'data-product="(?:cache-vault|reality-gate|forgecast|lights-out|cleanroom|ghostlayer|proofshot)"')
Assert-H9 'homepage template uses no product placement markers or fixed product markup' (([IO.File]::ReadAllText((Join-Path $root 'index.html')) -notmatch 'data-product="' -and [IO.File]::ReadAllText((Join-Path $root 'index.html')) -notmatch '@homepage-featured|@all-products|@homepage-major-scenes|@homepage-secondary'))
$indexSrc = [IO.File]::ReadAllText((Join-Path $root 'index.html'))
Assert-H9 'the opt-in homepage shelf is the only data-driven product surface' ($indexSrc -match '<!-- @homepage-shelf -->' -and ([regex]::Matches($indexSrc,'@homepage-')).Count -eq 1)
Assert-H9 'release-receipt inspection dialog exists' ($homeHtml -match 'pf-receipt-dialog' -and $homeHtml -match 'data-receipt-open')
Assert-H9 'engraved route-chain navigation exists' ($homeHtml -match 'pf-route-chain' -and $homeHtml -match 'pf-chain-station')

# 2. Status Truth — release facts live on catalog records and product pages.
Assert-H9 'Reality Gate appears as a withdrawn record on the catalog' ($softwareHtml -match 'public v1\.1\.0 withdrawn' -and $softwareHtml -notmatch 'Download Reality Gate')
Assert-H9 'Cache Vault catalog entry advertises public v0.3.1' ($softwareHtml -match 'v0\.3\.1')
Assert-H9 'Lights Out catalog entry advertises v11.2.0 + companion v11.1.1' ($softwareHtml -match 'v11\.2\.0' -and $softwareHtml -match 'v11\.1\.1')
function Test-ProofShotPublic([string]$catalog, [string]$productPage) {
  return ($catalog -match 'href="/proofshot/"' -and $productPage -match 'Public release' -and $productPage -match 'v2\.0\.0' -and $productPage -notmatch 'No public ProofShot release')
}
Assert-H9 'ProofShot public v2.0.0 release reachable from the catalog' (Test-ProofShotPublic $softwareHtml $proofshotHtml)

# 3. /software/ Route — approved directory composition.
Assert-H9 '/software/ route exists' (Test-Path $softwarePath)
$catalogIds = @([regex]::Matches($softwareHtml, 'data-directory-entry="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 '/software/ covers the six public products plus withdrawn Reality Gate' (@(@('cache-vault','forgecast','lights-out','cleanroom','ghostlayer','reality-gate') | Where-Object { $_ -in $catalogIds }).Count -eq 6)
Assert-H9 '/software/ carries the internal foundry-system records' (@(@('hardline-zero','crosspoint','proof-foundry-app') | Where-Object { $_ -in $catalogIds }).Count -eq 3)
Assert-H9 '/software/ contains the finder controls (hidden for progressive enhancement)' ($softwareHtml -match 'data-directory-finder[^>]*hidden' -and $softwareHtml -match 'name="query"')
Assert-H9 '/software/ has no comparison database UI' ($softwareHtml -notmatch 'data-compare|compare-choice')
Assert-H9 '/software/ marks withdrawn Reality Gate with availability=none' ($softwareHtml -match 'data-directory-entry="reality-gate"[^>]*data-availability="none"')
Assert-H9 '/software/ has exactly one active primary-nav item' (([regex]::Matches($softwareHtml, 'aria-current="page"')).Count -eq 1 -and $softwareHtml -match '<a href="/software/" aria-current="page">')
foreach ($page in @(@{Name='homepage';Html=$homeHtml}, @{Name='software';Html=$softwareHtml})) {
  $ids = @([regex]::Matches($page.Html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $missingLabels = @([regex]::Matches($page.Html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-H9 "$($page.Name) aria-labelledby references resolve" ($missingLabels.Count -eq 0)
}
$deadCatalogLinks = @(Get-ChildItem $public -Recurse -Filter *.html | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'href="/#products"' })
Assert-H9 'all generated pages route catalog discovery to /software/ instead of a missing home anchor' ($deadCatalogLinks.Count -eq 0)

# 4. Old Homepage Cleanup
Assert-H9 'homepage database filter/compare UI stays on the catalog' ($homeHtml -notmatch 'data-directory-finder' -and $homeHtml -notmatch 'theater-controls' -and $homeHtml -notmatch 'data-compare')

# 5. Manifest-driven Proof & Integrity
Assert-H9 'manifest-driven release/version/hash substitution remains intact' ($homeHtml -notmatch '\{\{products\.')
Assert-H9 'Proof narrative keeps raw 64-char digests off the homepage' ($homeHtml -notmatch '<dd>[a-f0-9]{64}</dd>')
Assert-H9 'No source commit is rendered or mislabeled on the homepage' ($homeHtml -notmatch '<dt>Source commit</dt>')
Assert-H9 'receipt SHA-256 stays off the homepage narrative' ($homeHtml -notmatch [regex]::Escape($cv.artifacts[0].sha256))
Assert-H9 'receipt source commits stay off the homepage narrative' ($homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29' -and $homeHtml -notmatch 'eddbae7')

# 6. Specific Wording & Liability Bounds — disclosures live on product pages.
Assert-H9 'GhostLayer "zero-trace" claim absent' ($homeHtml -notmatch 'zero-trace' -and $softwareHtml -notmatch 'zero-trace')
Assert-H9 'ProofShot "screen capture" wording absent' ($homeHtml -notmatch 'screen capture' -and $softwareHtml -notmatch 'screen capture')
Assert-H9 'ForgeCast privacy/network wording remains bounded on its product page' ($forgecastHtml -match '(?i)recorded weather|Forecasts use network data|analytics')

# 7. Negative controls exercise the same predicate against mutated in-memory
# content; no source or public file is changed by these controls.
Assert-H9 'NEGATIVE CONTROL: stale ProofShot version is rejected' (-not (Test-ProofShotPublic $softwareHtml ($proofshotHtml.Replace('v2.0.0', 'v1.6.18'))))
Assert-H9 'NEGATIVE CONTROL: unreleased ProofShot state is rejected' (-not (Test-ProofShotPublic $softwareHtml ($proofshotHtml.Replace('v2.0.0', 'No public release'))))
Assert-H9 'NEGATIVE CONTROL: missing ProofShot route is rejected' (-not (Test-ProofShotPublic ($softwareHtml.Replace('href="/proofshot/"', 'href="/removed/"')) $proofshotHtml))

if ($fail -gt 0) {
  Write-Host "=== CP-0189 RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== CP-0189 RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
