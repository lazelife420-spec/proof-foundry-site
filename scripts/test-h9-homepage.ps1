. "$PSScriptRoot/release-qualification.ps1"
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homeHtml = Get-Content (Join-Path $public 'index.html') -Raw -Encoding UTF8
$software = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$proof = Get-Content (Join-Path $public 'proof/index.html') -Raw -Encoding UTF8
$realityGate = Get-Content (Join-Path $public 'reality-gate/index.html') -Raw -Encoding UTF8
$sourceHome = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$homeCss = Get-Content (Join-Path $root 'pf-home-ledger.css') -Raw -Encoding UTF8
$homeJs = Get-Content (Join-Path $root 'h9-homepage.js') -Raw -Encoding UTF8
$manifest = Get-AuthoredReleaseManifest
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

$sections = @([regex]::Matches($homeHtml, '<section class="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'home preserves the exact shipped Proof Ledger section order' (($sections -join ',') -ceq 'ledger-hero,ledger-chain,ledger-paper ledger-doctrine,ledger-featured,ledger-specimen,ledger-paper ledger-index,ledger-position,ledger-close' -and $homeHtml -notmatch 'studio-threshold|studio-portfolio|data-home-products')
Assert-H9 'hero keeps the shipped headline as accessible HTML beside the decorative plate' ($homeHtml -match '<h1 id="ledger-title">Real software<br/>leaves a record\.</h1>' -and $homeHtml -match 'Useful tools\. Verifiable releases\. Clear limits\.' -and $homeHtml -match 'class="ledger-plate-scene" aria-hidden="true"' -and $homeHtml -match 'Source / Artifact / Record')
Assert-H9 'hero sends visitors to dedicated Software and Proof Standard pages' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'Browse Software' -and $homeHtml -match 'Read the Proof Standard')
$canonicalHeader = ([regex]::Match($homeHtml, '(?s)<header class="site-header".*?</header>').Value -replace ' aria-current="page"', '')
$headerParity = @($software, $proof, $realityGate | ForEach-Object { ([regex]::Match($_, '(?s)<header class="site-header".*?</header>').Value -replace ' aria-current="page"', '') -ceq $canonicalHeader })
Assert-H9 'all page families share canonical navigation, support CTA and reachable catalog' ($canonicalHeader -match 'href="/software/"' -and $canonicalHeader -match 'href="/proof-standard/"' -and $canonicalHeader -match 'href="/truth-files/"' -and $canonicalHeader -match 'href="/about/"' -and $canonicalHeader -match 'class="button button-primary nav-cta" href="/support/">Support</a>' -and $homeHtml -match 'class="ledger-button" href="/software/"' -and $manifest.navCta.href -eq '/support/' -and $manifest.navCta.label -eq 'Support' -and $headerParity.Count -eq 3 -and @($headerParity | Where-Object { -not $_ }).Count -eq 0)
Assert-H9 'hero is brand-owned and contains no fixed product identity' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=' -and $homeHtml -notmatch 'class="studio-hero-product"')

Assert-H9 'product browsing lives on Software rather than Home' ($publicModules.Count -gt 0 -and $renderedPublic.Count -eq 0 -and $homeHtml -notmatch 'studio-product-tab|role="tablist"|role="tabpanel"|studio-evidence')
Assert-H9 'withdrawn product stays on its record without a standalone Home panel' ($withdrawnModules.Count -gt 0 -and $renderedWithdrawn.Count -eq 0 -and $sourceHome -notmatch '@studio-withdrawn' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work' -and $realityGate -match 'Withdrawn')
Assert-H9 'shared PF micro mark and unified seal derivatives appear without glyph arrows' (([regex]::Matches($homeHtml, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 2 -and $homeHtml -match 'PF_MAKER_SEAL\.svg' -and $homeHtml -match 'PF_RECEIPT_WATERMARK\.svg' -and $homeHtml -notmatch 'pf-stamp-top|PF_MARK_G_MONO_LIGHT\.svg' -and $homeHtml -match 'class="site-footer"' -and $homeHtml -notmatch '↗|→|←' -and $homeHtml -match 'class="ledger-arrow"')

$catalogFailures = @()
foreach ($p in @($manifest.products | Where-Object visible)) {
  $m = @($modules | Where-Object id -eq $p.id | Select-Object -First 1)[0]
  $card = [regex]::Match($software, '(?s)<article class="product-card[^>]*data-product="' + [regex]::Escape([string]$p.id) + '".*?</article>').Value
  if (-not $m -or -not $card -or $card -notmatch [regex]::Escape([string]$p.route) -or $card -notmatch [regex]::Escape([string]$m.card.media) -or ($p.release.publicVersion -and $card -notmatch ('v' + [regex]::Escape([string]$p.release.publicVersion)))) { $catalogFailures += $p.id }
}
Assert-H9 'Software cards retain registry routes, authentic images and public versions' ($catalogFailures.Count -eq 0)
Assert-H9 'Software explains that illustrative and historical previews are not current runtime evidence' ($software -match 'App previews may show earlier builds' -and $software -match "ProofShot's preview retains its earlier HyperSnatch name")
$headerMark = Get-Content (Join-Path $public 'brand/PF_HEADER_MARK.svg') -Raw -Encoding UTF8
$makerSeal = Get-Content (Join-Path $public 'brand/PF_MAKER_SEAL.svg') -Raw -Encoding UTF8
Assert-H9 'active ledger preserves motion limits and actual SVG forced-color support' ($homeCss -match 'prefers-reduced-motion:reduce' -and $homeCss -match 'animation:none!important' -and $homeCss -match 'forced-colors:active' -and $homeCss -match 'background:Canvas' -and $headerMark -match 'forced-colors:active' -and $headerMark -match 'fill:CanvasText' -and $makerSeal -match 'fill:CanvasText' -and $makerSeal -match 'stroke:CanvasText')

Assert-H9 'Home proof link scopes hash identity and custody honestly' ($homeHtml -match 'A verified hash establishes artifact identity' -and $homeHtml -match 'does not by itself establish custody or safety' -and $homeHtml -notmatch 'HASH VERIFIED' -and $proof -match 'Artifact custody')
Assert-H9 'dedicated Truth, proof, catalogue and support routes remain reachable' ($homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/support/"')

$ids = @([regex]::Matches($homeHtml, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$missingReferences = @([regex]::Matches($homeHtml, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
Assert-H9 'one main heading and resolved accessible references' (([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<main\b')).Count -eq 1 -and $missingReferences.Count -eq 0)
Assert-H9 'generated home has no unresolved markers' ($homeHtml -notmatch '\{\{[^}]+\}\}|<!--\s*@studio-')
Assert-H9 'search and comparison stay on the full catalogue page' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"' -and $software -match 'product-finder|finder-intents' -and $software -match 'compare-choice|data-compare')
$catalogCards = @([regex]::Matches($software, '(?s)<article class="product-card[^"]*".*?</article>') | ForEach-Object { $_.Value })
Assert-H9 'catalog trims secondary taxonomy while retaining finder data and release facts' ($catalogCards.Count -eq @($manifest.products | Where-Object visible).Count -and @($catalogCards | Where-Object { $_ -match 'class="card-taxonomy"' -or $_ -notmatch 'data-category="[^\"]+"' -or $_ -notmatch 'data-jobs="[^\"]+"' -or $_ -notmatch 'class="h9-card-meta"' -or $_ -notmatch 'class="card-availability"' -or $_ -notmatch 'class="card-commerce"' }).Count -eq 0)
Assert-H9 'home uses active responsive and reduced-motion rules without a carousel' ($homeCss -match '@media\s*\(max-width:640px\)' -and $homeCss -match 'prefers-reduced-motion:reduce' -and $sourceHome -notmatch 'carousel|overflow-x:\s*(scroll|auto)')

Write-Host "=== H9 RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
