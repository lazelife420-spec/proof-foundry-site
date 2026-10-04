$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homeHtml = Get-Content (Join-Path $public 'index.html') -Raw -Encoding UTF8
$software = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$proof = Get-Content (Join-Path $public 'proof/index.html') -Raw -Encoding UTF8
$realityGate = Get-Content (Join-Path $public 'reality-gate/index.html') -Raw -Encoding UTF8
$sourceHome = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$homeCss = Get-Content (Join-Path $root 'h9-homepage.css') -Raw -Encoding UTF8
$homeJs = Get-Content (Join-Path $root 'h9-homepage.js') -Raw -Encoding UTF8
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$modules = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object { Get-Content (Join-Path $_.FullName 'module.json') -Raw -Encoding UTF8 | ConvertFrom-Json })
$rootModules = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and $_.homepage.role -eq 'studioPortfolio' -and $_.homepage.visibility -eq 'visible' } | Sort-Object { [int]$_.homepage.order }, { [int]$_.order })
$publicModules = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'PUBLIC_RELEASE' })
$withdrawnModules = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'WITHDRAWN' })
$renderedPublic = @([regex]::Matches($homeHtml, '<article class="studio-product-card"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$renderedWithdrawn = @([regex]::Matches($homeHtml, '<article class="studio-withdrawn-product"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$pass = 0; $fail = 0
function Assert-H9([string]$name, [bool]$condition) {
  if ($condition) { $script:pass++; Write-Host "PASS: $name" }
  else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red }
}
Write-Host '=== H9 HOMEPAGE-FIRST DESIGN AND TRUTH GUARD ===' -ForegroundColor Cyan

$sections = @([regex]::Matches($homeHtml, '<section class="(studio-hero|studio-portfolio|studio-proof)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'home has one concise hero and one proof route' (($sections -join ',') -ceq 'studio-hero,studio-proof' -and $homeHtml -notmatch 'studio-threshold|studio-close|studio-portfolio|data-home-products')
Assert-H9 'hero keeps useful task copy as HTML over responsive Open Forge artwork' ($homeHtml -match 'Do the work\.' -and $homeHtml -match 'Skip the detours\.' -and $homeHtml -match 'Find a saved clip' -and $homeHtml -match '/assets/binding-foundry/open-forge-scene-1536\.webp' -and $homeHtml -match '/assets/binding-foundry/open-forge-scene-960\.webp' -and $homeHtml -match '/assets/foundry-strike/proof-foundry-forged-artifact\.png')
Assert-H9 'hero sends visitors to dedicated Software and Proof Standard pages' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'Explore software' -and $homeHtml -match 'See how proof works')
Assert-H9 'shared header offers Support rather than duplicate Software action' ($manifest.navCta.href -eq '/support/' -and $manifest.navCta.label -eq 'Support' -and $homeHtml -match 'class="button button-primary nav-cta" href="/support/"' -and $homeHtml -notmatch 'Find your tool')
Assert-H9 'hero is brand-owned and contains no fixed product identity' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=' -and $homeHtml -notmatch 'class="studio-hero-product"')

Assert-H9 'product browsing lives on Software rather than Home' ($publicModules.Count -gt 0 -and $renderedPublic.Count -eq 0 -and $homeHtml -notmatch 'studio-product-tab|role="tablist"|role="tabpanel"|studio-evidence')
Assert-H9 'withdrawn product stays on its record without a standalone Home panel' ($withdrawnModules.Count -gt 0 -and $renderedWithdrawn.Count -eq 0 -and $sourceHome -notmatch '@studio-withdrawn' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work' -and $realityGate -match 'Withdrawn')
Assert-H9 'shared physical PF mark and compact footer appear without glyph arrows' (([regex]::Matches($homeHtml, '<img[^>]*proof-foundry-forged-artifact\.png')).Count -eq 2 -and $homeHtml -match 'class="studio-root-footer"' -and $homeHtml -notmatch '↗|→|←' -and $homeHtml -match 'class="ui-arrow"')

$catalogFailures = @()
foreach ($p in @($manifest.products | Where-Object visible)) {
  $m = @($modules | Where-Object id -eq $p.id | Select-Object -First 1)[0]
  $card = [regex]::Match($software, '(?s)<article class="product-card[^>]*data-product="' + [regex]::Escape([string]$p.id) + '".*?</article>').Value
  if (-not $m -or -not $card -or $card -notmatch [regex]::Escape([string]$p.route) -or $card -notmatch [regex]::Escape([string]$m.card.media) -or ($p.release.publicVersion -and $card -notmatch ('v' + [regex]::Escape([string]$p.release.publicVersion)))) { $catalogFailures += $p.id }
}
Assert-H9 'Software cards retain registry routes, authentic images and public versions' ($catalogFailures.Count -eq 0)
Assert-H9 'Software explains that illustrative and historical previews are not current runtime evidence' ($software -match 'App previews may show earlier builds' -and $software -match "ProofShot's preview retains its earlier HyperSnatch name")
Assert-H9 'scroll depth affects only the artwork and ambient light with a static reduced-motion state' ($homeJs -match 'requestAnimationFrame\(updateForge\)' -and $homeJs -match "prefers-reduced-motion: reduce" -and $homeJs -match 'forge-ambient-y' -and $homeJs -match 'removeProperty\(' -and $homeCss -match 'studio-proof::before' -and $homeCss -match 'transform: none !important')

Assert-H9 'Home proof link scopes hash identity and custody honestly' ($homeHtml -match 'A verified hash establishes artifact identity' -and $homeHtml -match 'does not by itself establish custody or safety' -and $homeHtml -notmatch 'HASH VERIFIED' -and $proof -match 'Artifact custody')
Assert-H9 'dedicated Truth, proof, catalogue and support routes remain reachable' ($homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/support/"')

$ids = @([regex]::Matches($homeHtml, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$missingReferences = @([regex]::Matches($homeHtml, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
Assert-H9 'one main heading and resolved accessible references' (([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<main\b')).Count -eq 1 -and $missingReferences.Count -eq 0)
Assert-H9 'generated home has no unresolved markers' ($homeHtml -notmatch '\{\{[^}]+\}\}|<!--\s*@studio-')
Assert-H9 'search and comparison stay on the full catalogue page' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"' -and $software -match 'product-finder|finder-intents' -and $software -match 'compare-choice|data-compare')
$catalogCards = @([regex]::Matches($software, '(?s)<article class="product-card[^"]*".*?</article>') | ForEach-Object { $_.Value })
Assert-H9 'catalog trims secondary taxonomy while retaining finder data and release facts' ($catalogCards.Count -eq @($manifest.products | Where-Object visible).Count -and @($catalogCards | Where-Object { $_ -match 'class="card-taxonomy"' -or $_ -notmatch 'data-category="[^\"]+"' -or $_ -notmatch 'data-jobs="[^\"]+"' -or $_ -notmatch 'class="h9-card-meta"' -or $_ -notmatch 'class="card-availability"' -or $_ -notmatch 'class="card-commerce"' }).Count -eq 0)
Assert-H9 'home uses responsive and reduced-motion rules without a carousel' ($homeCss -match '@media \(max-width: 390px\)' -and $homeCss -match 'prefers-reduced-motion: reduce' -and $sourceHome -notmatch 'carousel|overflow-x:\s*(scroll|auto)')

Write-Host "=== H9 RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
