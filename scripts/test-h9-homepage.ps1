$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homeHtml = Get-Content (Join-Path $public 'index.html') -Raw -Encoding UTF8
$software = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$sourceHome = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$modules = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object { Get-Content (Join-Path $_.FullName 'module.json') -Raw -Encoding UTF8 | ConvertFrom-Json })
$eligible = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and $_.homepage.role -eq 'studioPortfolio' -and $_.homepage.visibility -eq 'visible' } | Sort-Object { [int]$_.homepage.order }, { [int]$_.order })
$rendered = @([regex]::Matches($homeHtml, '<article\b[^>]*class="studio-product-card"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$pass = 0; $fail = 0
function Assert-H9([string]$name, [bool]$condition) { if ($condition) { $script:pass++; Write-Host "PASS: $name" } else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red } }
Write-Host '=== H9 STUDIO ROOT + CATALOG GUARD ===' -ForegroundColor Cyan
Assert-H9 'studio proposition and editorial hero render' ($homeHtml -match 'BUILD SOFTWARE\.' -and $homeHtml -match 'KEEP THE RECEIPT\.' -and $homeHtml -match 'studio-hero')
Assert-H9 'hero has local software and proof-standard actions' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof-standard/"')
Assert-H9 'workflow explains Build, Qualify, Record, Publish' ($homeHtml -match 'Build' -and $homeHtml -match 'Qualify' -and $homeHtml -match 'Record' -and $homeHtml -match 'Publish')
Assert-H9 'portfolio order and membership match visible module presentation metadata' (($rendered -join ',') -ceq (($eligible | ForEach-Object id) -join ',') -and $rendered.Count -eq $eligible.Count)
$featuredModules = @($eligible | Where-Object { $_.homepage.presentation -eq 'feature' })
Assert-H9 'exactly one module owns the featured portfolio presentation' ($featuredModules.Count -eq 1 -and ([regex]::Matches($homeHtml, 'data-presentation="feature"')).Count -eq 1)
Assert-H9 'portfolio cards bind route, image, accent, presentation and status to module/state' (@($eligible | Where-Object { $m=$_; $homeHtml -notmatch ('data-module="' + [regex]::Escape([string]$m.id) + '"[^>]*data-presentation="' + [regex]::Escape([string]$m.homepage.presentation) + '"') -or $homeHtml -notmatch [regex]::Escape([string]$m.route) -or $homeHtml -notmatch [regex]::Escape([string]$m.card.media) -or $homeHtml -notmatch [regex]::Escape([string]$m.theme.accent) }).Count -eq 0)
Assert-H9 'secondary proof links remain reachable' ($homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'href="/proof/"')
Assert-H9 'closing studio statement exists' ($homeHtml -match 'Same standard\.' -and $homeHtml -match 'Different tools\.')
Assert-H9 'studio root template contains no fixed product identity or list' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=')
Assert-H9 'generated homepage contains no unresolved template tokens' ($homeHtml -notmatch '\{\{[^}]+\}\}|<!--\s*@studio-')
Assert-H9 'root has no search/comparison catalog controls' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"')
Assert-H9 'software catalog route exists' (Test-Path (Join-Path $public 'software/index.html'))
$catalogIds = @([regex]::Matches($software, '<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$catalogExpected = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and (-not $_.placement -or $_.placement.catalog -ne $false) } | ForEach-Object id | Sort-Object)
Assert-H9 'software catalog entries are registry-derived and complete' ((($catalogIds | Sort-Object) -join ',') -ceq ($catalogExpected -join ',') -and $catalogIds.Count -eq $catalogExpected.Count)
Assert-H9 'catalog controls and comparison enhancement remain on software route' ($software -match 'product-finder|finder-intents' -and $software -match 'compare-choice|data-compare')
Assert-H9 'catalog comparison controls cover every catalog module' (([regex]::Matches($software, 'data-compare=')).Count -eq $catalogExpected.Count)
$missingA11y = 0
foreach ($pageHtml in @($homeHtml, $software)) { $ids = @([regex]::Matches($pageHtml, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }); $missingA11y += @([regex]::Matches($pageHtml, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids }).Count }
Assert-H9 'homepage and catalog accessibility references resolve' ($missingA11y -eq 0)
Assert-H9 'legacy catalog anchor has no generated dead links' (@(Get-ChildItem $public -Recurse -Filter *.html | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'href="/#products"' }).Count -eq 0)
Assert-H9 'no horizontal-scroll primitive or carousel dependency' ($sourceHome -notmatch 'carousel|overflow-x:\s*(scroll|auto)')
Assert-H9 'reduced motion support remains' ((Get-Content (Join-Path $root 'h9-homepage.css') -Raw) -match 'prefers-reduced-motion')

# Evidence must be derived from an eligible canonical public artifact.
$candidateModules = @($modules | Where-Object { $null -ne $_.homepage.evidencePriority } | Sort-Object { [int]$_.homepage.evidencePriority })
$evidence = [regex]::Match($homeHtml, '(?s)<aside class="studio-evidence".*?</aside>').Value
$selected = $null
foreach ($m in $candidateModules) {
  $p = @($manifest.products | Where-Object id -eq $m.id | Select-Object -First 1)[0]
  $artifact = @($p.artifacts | Where-Object { $_.downloadUrl -eq $p.downloadUrl -and $_.sha256 -eq $p.sha256 } | Select-Object -First 1)[0]
  if ($p.release.releaseStatus -eq 'PUBLIC_RELEASE' -and $p.release.publicVersion -and $p.verification.status -eq 'VERIFIED' -and -not $p.presentation.downloadUnavailable -and $p.downloadUrl -and $p.sha256 -match '^[a-fA-F0-9]{64}$' -and $p.sha256Url -and $artifact -and $m.card.media) { $selected = @{module=$m;product=$p;artifact=$artifact}; break }
}
Assert-H9 'evidence component is omitted when no canonical eligible artifact exists, otherwise exactly one is rendered' (($selected -and [regex]::Matches($homeHtml, 'class="studio-evidence"').Count -eq 1) -or (-not $selected -and [regex]::Matches($homeHtml, 'class="studio-evidence"').Count -eq 0))
if ($selected) {
  Assert-H9 'evidence spotlight matches first eligible editorial candidate and canonical artifact facts' ($evidence.Contains([string]$selected.product.name) -and $evidence.Contains([string]$selected.product.release.publicVersion) -and $evidence.Contains([string]$selected.artifact.filename) -and $evidence.Contains([string]$selected.product.sha256) -and $evidence.Contains([string]$selected.product.sha256Url))
}
$rg = @($manifest.products | Where-Object id -eq 'reality-gate' | Select-Object -First 1)[0]
Assert-H9 'withdrawn Reality Gate is excluded from evidence selection and has no root download CTA' ($rg.release.releaseStatus -eq 'WITHDRAWN' -and $evidence -notmatch 'Reality Gate' -and $homeHtml -notmatch 'Download[^<]*Reality Gate')
$proofIndex = Get-Content (Join-Path $public 'proof/index.json') -Raw -Encoding UTF8
Assert-H9 'root narrative keeps raw checksum digests confined to evidence artifact' ($evidence -and $homeHtml -notmatch ('<dd>' + [regex]::Escape([string]$selected.product.sha256) + '</dd>'))
Assert-H9 'homepage release references remain generated from canonical manifest data' ($homeHtml -notmatch '\{\{products\.' -and $proofIndex -match '"products"')

if ($fail -gt 0) { Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Red; exit 1 }
Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
