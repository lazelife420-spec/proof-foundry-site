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

# Runs a sub-check as its own process and re-asserts each of its PASS/FAIL lines
# here. A crash, a non-zero exit, a missing or mismatched footer, or fewer
# checks than its recorded minimum is a failure, never a skip. A minimum may
# only be lowered in the same change that removes checks, with the reason.
function Invoke-SubCheck([string]$label, [string]$exe, [string[]]$arguments, [string]$linePattern, [string]$footerPattern, [int]$minimumPass) {
  $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $output = @(& $exe @arguments 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
  catch { $output = @("$_"); $code = -1 }
  finally { $ErrorActionPreference = $previous }
  $seenPass = 0; $seenFail = 0; $footers = @()
  foreach ($line in $output) {
    if ($line -match $linePattern) { $ok = $Matches[1] -eq 'PASS'; if ($ok) { $seenPass++ } else { $seenFail++ }; Assert-H9 "${label}: $($Matches[2])" $ok }
    elseif ($line -match $footerPattern) { $footers += , @([int]$Matches[1], [int]$Matches[2]) }
  }
  if ($seenPass + $seenFail -eq 0) { $output | Select-Object -Last 5 | ForEach-Object { Write-Host "      $_" } }
  Assert-H9 "${label}: ran to completion: exit $code, one consistent footer, PASS=$seenPass (minimum $minimumPass) FAIL=$seenFail" ($code -eq 0 -and $footers.Count -eq 1 -and $footers[0][0] -eq $seenPass -and $footers[0][1] -eq $seenFail -and $seenPass -ge [Math]::Max(1, $minimumPass) -and $seenFail -eq 0)
}
Write-Host '=== H9 HOMEPAGE-FIRST DESIGN AND TRUTH GUARD ===' -ForegroundColor Cyan

$sections = @([regex]::Matches($homeHtml, '<section class="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'home preserves the exact shipped Proof Ledger section order' (($sections -join ',') -ceq 'ledger-hero,ledger-featured,ledger-chain,ledger-paper ledger-doctrine,ledger-specimen,ledger-paper ledger-index,ledger-position,ledger-close' -and $homeHtml -notmatch 'studio-threshold|studio-portfolio|data-home-products')
# V5 hero (owner ruling, 2026-10-13): the approved headline and copy, scoped to
# the hero itself, replace the page-wide phrase match, which the meta tags also
# satisfied.
function Get-VisibleText([string]$html) { (([regex]::Replace([regex]::Replace($html, '(?i)<br\s*/?>', ' '), '<[^>]+>', ' ')) -replace '\s+', ' ').Trim() }
$hero = [regex]::Match($homeHtml, '(?s)<section class="ledger-hero"[^>]*>.*?(?=<section class="ledger-featured")').Value
$heroH1 = [regex]::Match($hero, '(?s)<h1 id="([^"]+)"[^>]*>(.*?)</h1>')
$heroClaims = (Get-VisibleText $hero) + ' ' + ((@([regex]::Matches($hero, '\s(?:aria-label|aria-description|title|alt|placeholder)\s*=\s*(?:"([^"]*)"|''([^'']*)'')') | ForEach-Object { $_.Groups[1].Value + $_.Groups[2].Value })) -join ' ')
$overclaim = '(?i)\b(verified|certif\w*|secur\w*|safe(ly|ty)?|guarant\w*|trusted|trustworthy|signed|audit\w*|tamper-?proof|proven|bulletproof|unbreakable|unhackable|risk-free)\b'
$heroSubtitle = [regex]::Match($hero, '(?s)<p class="ledger-hero-subtitle">(.*?)</p>')
$heroDescription = [regex]::Match($hero, '(?s)<p class="ledger-hero-description">(.*?)</p>')
Assert-H9 'hero headline is the approved V5 headline, the only h1, and names the hero section' ($heroH1.Success -and $heroH1.Groups[2].Value -ceq 'Real software<br/>leaves a record.' -and (Get-VisibleText $heroH1.Groups[2].Value) -ceq 'Real software leaves a record.' -and $hero -match ('^<section class="ledger-hero" aria-labelledby="' + [regex]::Escape($heroH1.Groups[1].Value) + '"') -and ([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1)
Assert-H9 'hero subtitle and description are the approved V5 copy, in order, with no certification, security, digest or version claim in its text or labels' ($heroSubtitle.Success -and $heroDescription.Success -and (Get-VisibleText $heroSubtitle.Groups[1].Value) -ceq 'Receipts over hype.' -and (Get-VisibleText $heroDescription.Groups[1].Value) -ceq 'Independent software. Public records. Clear limits.' -and $hero.IndexOf($heroH1.Value) -lt $hero.IndexOf($heroSubtitle.Value) -and $hero.IndexOf($heroSubtitle.Value) -lt $hero.IndexOf($heroDescription.Value) -and $heroClaims -notmatch $overclaim -and $hero -notmatch '\b[0-9a-f]{64}\b' -and $heroClaims -notmatch '\bv\d+\.\d+')
$homeHead = [regex]::Match($homeHtml, '(?s)<head>.*?</head>').Value
$metaCopy = @([regex]::Matches($homeHead, '<meta (?:name|property)="(?:description|og:[a-z_:]+|twitter:[a-z_:]+)" content="([^"]*)"') | ForEach-Object { $_.Groups[1].Value }) + @([regex]::Match($homeHead, '(?s)<title>(.*?)</title>').Groups[1].Value)
# Owner rulings 2026-10-14: V5 search and social copy, and a philosophy heading
# that does not repeat the hero subtitle.
$approvedDescription = 'Real software leaves a record. Independent tools, public release receipts, and clear limits.'
Assert-H9 'Home search and social descriptions are the approved V5 copy, and the philosophy heading does not repeat the hero' ($homeHead -cmatch ('<meta name="description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHead -cmatch ('<meta property="og:description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHtml -cmatch '<h2 id="doctrine-title">Show the work\.</h2>' -and ([regex]::Matches($homeHtml, 'Receipts over hype\.')).Count -eq 1)
Assert-H9 'Home title, search and social copy exist and make no certification, security, digest or version claim' ($homeHead -match '<meta name="description" content="[^"]{20,}"' -and $homeHead -match '<meta property="og:description" content="[^"]{20,}"' -and @($metaCopy | Where-Object { $_ -match $overclaim -or $_ -match '\b[0-9a-f]{64}\b' -or $_ -match '\bv\d+\.\d+' }).Count -eq 0)
Assert-H9 'hero emblem is decorative with a forced-colours vector seal, and its inspect control opens the mark dialog' ($hero -match '<div class="ledger-plate-scene" aria-hidden="true">' -and $hero -match '<source media="\(forced-colors: active\)" srcset="/brand/PF_MAKER_SEAL\.svg"/><img class="pf-emblem-image" src="/brand/emblem/PF_MARK_G_EMBLEM_R3\.webp" alt=""' -and $hero -match 'Source / Artifact / Record' -and $hero -match 'class="pf-inspect"[^>]*aria-haspopup="dialog"[^>]*aria-controls="pf-mark-dialog"' -and $homeHtml -match '<dialog [^>]*id="pf-mark-dialog"')
$heroActions = [regex]::Match($hero, '(?s)<div class="ledger-actions">(.*?)</div>').Groups[1].Value
Assert-H9 'hero sends visitors to dedicated Software and Proof Standard pages' ($heroActions -cmatch '^<a class="ledger-button" href="/software/">Browse software <svg' -and $hero -cmatch '<a class="ledger-link ledger-link-mono" href="/proof-standard/">Read the Proof Standard <svg' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof-standard/"')
# Home's header differs from the shared header only by its brand mark: the V5
# PF Mark G render, with the shared micro mark kept for forced colours.
$homeMarkPicture = '<picture class="brand-mark-picture"><source media="(forced-colors: active)" srcset="/brand/PF_HEADER_MARK.svg"/><img class="brand-mark" src="/brand/emblem/PF_MARK_G_HEADER.webp" alt="" width="50" height="51"/></picture>'
$sharedMarkImg = '<img class="brand-mark" src="/brand/PF_HEADER_MARK.svg" alt="" width="42" height="42" />'
$homeHeader = ([regex]::Match($homeHtml, '(?s)<header class="site-header".*?</header>').Value -replace ' aria-current="page"', '')
# V5 refinement F5: Home's header also carries one hidden, aria-hidden, non-focusable inline copy of the canonical micro
# mark, drawn only in forced colours. It is bound here to PF_HEADER_MARK.svg's own geometry, then set aside so the
# parity check below still compares every other byte of the header with the shared header.
$microSource = Get-Content (Join-Path $root 'brand/PF_HEADER_MARK.svg') -Raw -Encoding UTF8
$microStart = $microSource.IndexOf('</style>') + '</style>'.Length
$microBody = ($microSource.Substring($microStart, $microSource.LastIndexOf('</svg>') - $microStart).Trim() -replace '>\s+<', '><')
$homeFcHeaderMark = '<span class="pf-mark-fc pf-mark-fc--header" hidden><svg viewBox="0 0 256 256" aria-hidden="true" focusable="false">' + $microBody + '</svg></span>'
Assert-H9 'Home header: the forced-colours micro mark is one hidden, aria-hidden, non-focusable inline copy of PF_HEADER_MARK.svg, right after the brand picture' ($microStart -gt 8 -and ([regex]::Matches($homeHeader, [regex]::Escape($homeFcHeaderMark))).Count -eq 1 -and $homeHeader.Contains($homeMarkPicture + $homeFcHeaderMark) -and ([regex]::Matches($homeHtml, 'class="pf-mark-fc ')).Count -eq 2)
$canonicalHeader = $homeHeader.Replace($homeFcHeaderMark, '').Replace($homeMarkPicture, $sharedMarkImg)
$headerParity = @($software, $proof, $realityGate | ForEach-Object { ([regex]::Match($_, '(?s)<header class="site-header".*?</header>').Value -replace ' aria-current="page"', '') -ceq $canonicalHeader })
Assert-H9 'all page families share canonical navigation, support CTA and reachable catalog' ($canonicalHeader -match 'href="/software/"' -and $canonicalHeader -match 'href="/proof-standard/"' -and $canonicalHeader -match 'href="/truth-files/"' -and $canonicalHeader -match 'href="/about/"' -and $canonicalHeader -match 'class="button button-primary nav-cta" href="/support/">Support</a>' -and $homeHtml -match 'class="ledger-button" href="/software/"' -and $manifest.navCta.href -eq '/support/' -and $manifest.navCta.label -eq 'Support' -and $headerParity.Count -eq 3 -and @($headerParity | Where-Object { -not $_ }).Count -eq 0)
Assert-H9 'hero is brand-owned and contains no fixed product identity' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=' -and $homeHtml -notmatch 'class="studio-hero-product"')

Assert-H9 'product browsing lives on Software rather than Home' ($publicModules.Count -gt 0 -and $renderedPublic.Count -eq 0 -and $homeHtml -notmatch 'studio-product-tab|role="tablist"|role="tabpanel"|studio-evidence')
Assert-H9 'withdrawn product stays on its record without a standalone Home panel' ($withdrawnModules.Count -gt 0 -and $renderedWithdrawn.Count -eq 0 -and $sourceHome -notmatch '@studio-withdrawn' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work' -and $realityGate -match 'Withdrawn')
$markProvenance = Get-Content (Join-Path $root 'PF_MARK_G_EMBLEM_PROVENANCE.md') -Raw -Encoding UTF8
$headerMarkRow = [regex]::Match($markProvenance, '\|\s*`brand/emblem/PF_MARK_G_HEADER\.webp`\s*\|[^\n]*\|\s*`([0-9a-f]{64})`\s*\|')
$brandLink = [regex]::Match($homeHeader, '(?s)<a class="brand-lockup" href="/">(.*?)</a>')
# The approved V5 header render (eda57d5d…), reproduced by scripts/pf-emblem/render-emblem.mjs.
$headerMarkFile = Join-Path $public 'brand/emblem/PF_MARK_G_HEADER.webp'
$headerMarkSha = if (Test-Path -LiteralPath $headerMarkFile) { (Get-FileHash -LiteralPath $headerMarkFile -Algorithm SHA256).Hash.ToLowerInvariant() } else { 'missing' }
Assert-H9 'Home header carries the approved PF Mark G render, with the vector micro mark for forced colours, inside a named home link' ($brandLink.Success -and $brandLink.Groups[1].Value.Contains($homeMarkPicture) -and ([regex]::Matches($homeHeader, '<img\b')).Count -eq 1 -and (Get-VisibleText $brandLink.Groups[1].Value) -match '^The Proof Foundry\b' -and $headerMarkRow.Success -and $headerMarkSha -ceq 'eda57d5d1abe27adcfd3d13de0b5ec0b4ffa2a2c3cb3c5d768bc7e2b843936f0' -and $headerMarkSha -ceq $headerMarkRow.Groups[1].Value)
$homeFooter = [regex]::Match($homeHtml, '(?s)<footer class="site-footer".*?</footer>').Value
Assert-H9 'shared PF micro mark stays in the footer and unified seal derivatives appear without glyph arrows' (([regex]::Matches($homeFooter, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and $homeHtml -match 'PF_MAKER_SEAL\.svg' -and $homeHtml -match 'PF_RECEIPT_WATERMARK\.svg' -and $homeHtml -notmatch 'pf-stamp-top|PF_MARK_G_MONO_LIGHT\.svg' -and $homeHtml -match 'class="site-footer"' -and $homeHtml -notmatch '↗|→|←' -and $homeHtml -match 'class="ledger-arrow"')

$catalogFailures = @()
foreach ($p in @($manifest.products | Where-Object visible)) {
  $m = @($modules | Where-Object id -eq $p.id | Select-Object -First 1)[0]
  $card = [regex]::Match($software, '(?s)<article class="product-card[^>]*data-product="' + [regex]::Escape([string]$p.id) + '".*?</article>').Value
  if (-not $m -or -not $card -or $card -notmatch [regex]::Escape([string]$p.route) -or $card -notmatch [regex]::Escape([string]$m.card.media) -or ($p.release.publicVersion -and $card -notmatch ('v' + [regex]::Escape([string]$p.release.publicVersion)))) { $catalogFailures += $p.id }
}
Assert-H9 'Software cards retain registry routes, authentic images and public versions' ($catalogFailures.Count -eq 0)
$proofshotSoftwareCard = [regex]::Match($software, '(?s)<article class="product-card[^>]*data-product="proofshot".*?</article>').Value
Assert-H9 'Software explains that app previews may show earlier builds, names no HyperSnatch-era preview, and shows ProofShot by its brand card' ($software -match 'App previews may show earlier builds\.' -and $software -notmatch 'HyperSnatch' -and $proofshotSoftwareCard -match '<img src="/assets/proofshot/og-image\.png"')
$headerMark = Get-Content (Join-Path $public 'brand/PF_HEADER_MARK.svg') -Raw -Encoding UTF8
$makerSeal = Get-Content (Join-Path $public 'brand/PF_MAKER_SEAL.svg') -Raw -Encoding UTF8
$masterPaths = @([regex]::Matches((Get-Content (Join-Path $root 'brand/PF_MARK_G_MASTER.svg') -Raw -Encoding UTF8), '<path[^>]*\sd="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$renderLib = Get-Content (Join-Path $root 'scripts/pf-emblem/render-lib.js') -Raw -Encoding UTF8
Assert-H9 'the vector micro mark and the renderer of the PF Mark G render use the canonical master paths' ($masterPaths.Count -eq 3 -and @($masterPaths | Where-Object { $headerMark.Contains($_) -and $renderLib.Contains($_) }).Count -eq 3)
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


# ── V5 homepage in a real browser (owner ruling, 2026-10-13) ─────────────────
# Layout at six widths, no-JS, keyboard and touch use of both dialogs, exact
# receipt parity per product, every failure and refresh state, reduced motion.
# Runs against public/ over loopback; needs Chrome or Edge (PF_H9_BROWSER).
Invoke-SubCheck 'V5 browser' 'node' @((Join-Path $PSScriptRoot 'test-home-v5-browser.mjs')) '^(PASS|FAIL): (.*)$' '^=== HOME V5 BROWSER RESULT: (\d+) passed, (\d+) failed ===$' 110

Write-Host "=== H9 RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
