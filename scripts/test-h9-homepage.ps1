$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homeHtml = Get-Content (Join-Path $public 'index.html') -Raw -Encoding UTF8
$software = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$sourceHome = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$homeCss = Get-Content (Join-Path $root 'h9-homepage.css') -Raw -Encoding UTF8
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$modules = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object { Get-Content (Join-Path $_.FullName 'module.json') -Raw -Encoding UTF8 | ConvertFrom-Json })
$eligible = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and $_.homepage.role -eq 'studioPortfolio' -and $_.homepage.visibility -eq 'visible' } | Sort-Object { [int]$_.homepage.order }, { [int]$_.order })
$rendered = @([regex]::Matches($homeHtml, '<(?:figure|article)\b[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$pass = 0; $fail = 0
function Assert-H9([string]$name, [bool]$condition) { if ($condition) { $script:pass++; Write-Host "PASS: $name" } else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red } }
Write-Host '=== H9 STUDIO ROOT + CATALOG GUARD ===' -ForegroundColor Cyan
Assert-H9 'customer-facing software proposition leads; studio doctrine remains supporting copy' ($homeHtml -match 'USEFUL SOFTWARE\.' -and $homeHtml -match 'ON YOUR TERMS\.' -and $homeHtml -match 'Build software\. Keep the receipt\.' -and $homeHtml -match 'studio-hero')
$sectionOrder = @([regex]::Matches($homeHtml,'<section class="(studio-hero|studio-portfolio|studio-method|studio-proof|studio-close)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'five approved Studio Root beats remain in order' (($sectionOrder -join ',') -ceq 'studio-hero,studio-portfolio,studio-method,studio-proof,studio-close')
Assert-H9 'hero uses the verified responsive forged mark as decorative atmosphere' ($homeHtml -match 'class="studio-forge-workbench" aria-hidden="true"' -and $homeHtml -match 'forged_pf_emblem_in_smoky_ruins-1280\.avif' -and $homeHtml -match 'forged_pf_emblem_in_smoky_ruins-1672\.webp')
Assert-H9 'hero has direct catalog and method actions' ($homeHtml -match 'Find your tool' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'How we work' -and $homeHtml -match 'href="/proof-standard/"')
Assert-H9 'workflow explains Build, Qualify, Record, Publish' ($homeHtml -match 'Build' -and $homeHtml -match 'Qualify' -and $homeHtml -match 'Record' -and $homeHtml -match 'Publish')
Assert-H9 'editorial section indices PF / 01 through PF / 05 follow the approved five-beat sequence' (([regex]::Matches($homeHtml, 'studio-section-index">PF / 0[1-5]')).Count -eq 5 -and $homeHtml -match 'PF / 01' -and $homeHtml -match 'PF / 02' -and $homeHtml -match 'PF / 03' -and $homeHtml -match 'PF / 04' -and $homeHtml -match 'PF / 05')
Assert-H9 'generic hero and portfolio order follow visible tier metadata' (($rendered -join ',') -ceq (($eligible | ForEach-Object id) -join ',') -and $rendered.Count -eq $eligible.Count)
$featuredModules = @($eligible | Where-Object { $_.homepage.tier -eq 'featured' })
$majorModules = @($eligible | Where-Object { $_.homepage.tier -eq 'major' })
$secondaryModules = @($eligible | Where-Object { $_.homepage.tier -eq 'secondary' })
Assert-H9 'exactly one module owns the featured homepage role' ($featuredModules.Count -eq 1 -and ([regex]::Matches($homeHtml, 'class="studio-hero-product"[^>]*data-home-role="featured"')).Count -eq 1)
Assert-H9 'two major and four secondary scenes are selected through generic module tiers' ($majorModules.Count -eq 2 -and $secondaryModules.Count -eq 4 -and ([regex]::Matches($homeHtml, 'class="studio-product-card"[^>]*data-home-role="major"')).Count -eq 2 -and ([regex]::Matches($homeHtml, 'class="studio-product-card"[^>]*data-home-role="secondary"')).Count -eq 4)
Assert-H9 'major composition comes from module layout metadata' (@($majorModules | Where-Object { $_.homepage.composition -notin @('media-left','media-right') }).Count -eq 0 -and $homeHtml -match 'data-composition="media-right"' -and $homeHtml -match 'data-composition="media-left"')
Assert-H9 'hero and cards bind route, authentic image, accent, role, and state to module data' (@($eligible | Where-Object { $m=$_; $media=if($m.homepage.tier -eq 'featured'){$m.hero.media.src}else{$m.card.media}; $homeHtml -notmatch ('data-module="' + [regex]::Escape([string]$m.id) + '"[^>]*data-home-role="' + [regex]::Escape([string]$m.homepage.tier) + '"') -or $homeHtml -notmatch [regex]::Escape([string]$m.route) -or $homeHtml -notmatch [regex]::Escape([string]$media) -or $homeHtml -notmatch [regex]::Escape([string]$m.theme.accent) }).Count -eq 0)
Assert-H9 'major and secondary layouts use generic tier selectors and accent tokens without product-ID styling' ($homeCss -match 'data-home-role="major"' -and $homeCss -match 'data-home-role="secondary"' -and $homeCss -match 'var\(--product-accent\)' -and $homeCss -notmatch '(?i)cache-vault|reality-gate|ghostlayer|lights-out|cleanroom|proofshot|forgecast')
Assert-H9 'major scenes alternate media sides with bounded height and stack cleanly on mobile' ($homeCss -match 'data-composition="media-right"' -and $homeCss -match 'data-composition="media-left"' -and $homeCss -match 'max-height:\s*540px' -and $homeCss -match '(?s)@media \(max-width:\s*760px\).*?data-home-role="major".*?flex-direction:\s*column')
Assert-H9 'each secondary product renders a real module image, status, and route action' (@($secondaryModules | Where-Object { $homeHtml -notmatch [regex]::Escape([string]$_.card.media) -or $homeHtml -notmatch [regex]::Escape([string]$_.route) }).Count -eq 0 -and ([regex]::Matches($homeHtml, 'data-home-role="secondary"')).Count -eq 4)
Assert-H9 'featured app is a direct large image without simulated window chrome' ($homeHtml -match 'class="studio-hero-visual"' -and $homeHtml -notmatch 'studio-hero-windowbar')
Assert-H9 'method stays compact as a sequence heading with one supporting sentence' ($homeHtml -match 'BUILD <span>→</span> QUALIFY <span>→</span> RECORD <span>→</span> PUBLISH' -and $homeHtml -match 'Every public release moves' -and $homeHtml -notmatch 'studio-method-steps|studio-method-sequence')
Assert-H9 'real public release ledger receives its own proof column and stacks on mobile' ($homeCss -match '\.studio-proof \.studio-evidence\s*\{\s*grid-column:\s*2;\s*grid-row:\s*1' -and $homeCss -match '@media \(max-width:\s*760px\)[\s\S]*?\.studio-proof \.studio-evidence\s*\{\s*grid-column:\s*1')
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
Assert-H9 'proof artifact contains four ledger rows with public version, verified state, SHA-256 record marker, date, and links' (([regex]::Matches($evidence, 'class="studio-ledger-row"')).Count -eq 4 -and $evidence -match 'PUBLIC <b>v' -and $evidence -match 'VERIFIED' -and $evidence -match 'SHA-256 on record' -and $evidence -match '<time datetime=' -and $evidence -match 'href="/proof/#receipt-')
if ($selected) {
Assert-H9 'compact evidence matches first eligible public release and keeps raw artifact details on the record page' ($evidence.Contains([string]$selected.product.name) -and $evidence.Contains([string]$selected.product.release.publicVersion) -and $evidence.Contains([string]$selected.product.verification.verifiedAt) -and $evidence.Contains('/proof/#receipt-' + [string]$selected.product.id) -and $homeHtml -notmatch [regex]::Escape([string]$selected.product.sha256) -and $homeHtml -notmatch [regex]::Escape([string]$selected.artifact.filename))
}
$rg = @($manifest.products | Where-Object id -eq 'reality-gate' | Select-Object -First 1)[0]
Assert-H9 'withdrawn Reality Gate is excluded from evidence selection and has no root download CTA' ($rg.release.releaseStatus -eq 'WITHDRAWN' -and $evidence -notmatch 'Reality Gate' -and $homeHtml -notmatch 'Download[^<]*Reality Gate')
$proofIndex = Get-Content (Join-Path $public 'proof/index.json') -Raw -Encoding UTF8
Assert-H9 'root narrative keeps raw checksum digests confined to evidence artifact' ($evidence -and $homeHtml -notmatch ('<dd>' + [regex]::Escape([string]$selected.product.sha256) + '</dd>'))
Assert-H9 'homepage release references remain generated from canonical manifest data' ($homeHtml -notmatch '\{\{products\.' -and $proofIndex -match '"products"')

if ($fail -gt 0) { Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Red; exit 1 }
Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
