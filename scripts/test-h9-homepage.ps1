$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homeHtml = Get-Content (Join-Path $public 'index.html') -Raw -Encoding UTF8
$software = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$sourceHome = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$homeCss = Get-Content (Join-Path $root 'h9-homepage.css') -Raw -Encoding UTF8
$worldCss = Get-Content (Join-Path $root 'foundry-world.css') -Raw -Encoding UTF8
$renderer = Get-Content (Join-Path $root 'scripts/build-site.ps1') -Raw -Encoding UTF8
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$modules = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object { Get-Content (Join-Path $_.FullName 'module.json') -Raw -Encoding UTF8 | ConvertFrom-Json })
$rootModules = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and $_.homepage.role -eq 'studioPortfolio' -and $_.homepage.visibility -eq 'visible' } | Sort-Object { [int]$_.homepage.order }, { [int]$_.order })
$publicHomeModules = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'PUBLIC_RELEASE' })
$withdrawnHomeModules = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'WITHDRAWN' })
$renderedPublic = @([regex]::Matches($homeHtml, '<article class="studio-product-card"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$renderedWithdrawn = @([regex]::Matches($homeHtml, '<article class="studio-withdrawn-product"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$pass = 0; $fail = 0
function Assert-H9([string]$name, [bool]$condition) { if ($condition) { $script:pass++; Write-Host "PASS: $name" } else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red } }
Write-Host '=== H9 STUDIO ROOT + CATALOG GUARD ===' -ForegroundColor Cyan

Assert-H9 'studio identity and proposition lead the first scene' ($homeHtml -match 'Useful software\.' -and $homeHtml -match 'On your terms\.' -and $homeHtml -match 'Independent software for a more truthful tomorrow' -and $homeHtml -match 'studio-hero')
$sectionOrder = @([regex]::Matches($homeHtml,'<section class="(studio-hero|studio-portfolio|studio-proof|studio-withdrawn|studio-threshold|studio-close)"') | ForEach-Object { $_.Groups[1].Value })
Assert-H9 'journey proceeds from interior to work, proof, withdrawn state, threshold and exterior' (($sectionOrder -join ',') -ceq 'studio-hero,studio-portfolio,studio-proof,studio-withdrawn,studio-threshold,studio-close')
Assert-H9 'hero uses the cool-metal furnace scene and a mounted Foundry mark' ($homeHtml -match 'studio-forge-workbench' -and $homeHtml -match '/assets/binding-foundry/foundry-ledger\.webp' -and $homeHtml -match 'class="studio-hero-emblem"' -and $homeHtml -match '/brand/PF_MARK_G_FORGED\.svg')
Assert-H9 'hero links to the catalog and proof standard' ($homeHtml -match 'Explore software' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'Read the Proof Standard' -and $homeHtml -match 'href="/proof-standard/"')
Assert-H9 'hero is brand-first and contains no featured product media or identity' ($sourceHome -notmatch '@studio-hero-product|studio-hero-product|data-module=|Cache Vault|GhostLayer|Lights Out|Cleanroom|ProofShot|ForgeCast|Reality Gate' -and $homeHtml -notmatch 'class="studio-hero-product"')
Assert-H9 'studio principles keep the independent, local-first and inspectable claims visible' ($homeHtml -match 'Independent<br/>by design' -and $homeHtml -match 'Local-first<br/>where it fits' -and $homeHtml -match 'Inspectable<br/>release records')
Assert-H9 'editorial section indices remain ordered from PF / 01 through PF / 05' (([regex]::Matches($homeHtml, 'studio-section-index">PF / 0[1-5]')).Count -eq 5)
Assert-H9 'journey transition and final exterior use the threshold and open-door scene' ($homeHtml -match 'THE THRESHOLD / TRANSITION' -and $homeHtml -match 'What leaves the workshop<br/>carries its record with it\.' -and $homeHtml -match "From the workshop<br/><em>to what’s next\.</em>" -and $homeCss -match 'studio-horizon\.webp')

Assert-H9 'all public homepage modules render as work-area cards in registry order' (($renderedPublic -join ',') -ceq (($publicHomeModules | ForEach-Object id) -join ',') -and $renderedPublic.Count -eq $publicHomeModules.Count)
Assert-H9 'withdrawn modules render separately, in registry order, outside the public catalog scene' (($renderedWithdrawn -join ',') -ceq (($withdrawnHomeModules | ForEach-Object id) -join ',') -and $renderedWithdrawn.Count -eq $withdrawnHomeModules.Count)
Assert-H9 'public modules preserve their semantic tier and composition metadata' (@($publicHomeModules | Where-Object { $homeHtml -notmatch ('data-module="' + [regex]::Escape([string]$_.id) + '"[^>]*data-home-role="' + [regex]::Escape([string]$_.homepage.tier) + '"[^>]*data-composition="' + [regex]::Escape([string]$_.homepage.composition) + '"') }).Count -eq 0)
Assert-H9 'all module routes, images, and accent tokens remain bound to module data' (@($rootModules | Where-Object { $m=$_; $html=$homeHtml; $html -notmatch [regex]::Escape([string]$m.route) -or $html -notmatch [regex]::Escape([string]$m.card.media) -or $html -notmatch [regex]::Escape([string]$m.theme.accent) }).Count -eq 0)
Assert-H9 'capture notes disclose historical UI, sample data and the ProofShot pre-rebrand workbench' ($homeHtml -match 'Dry Run capture from v11\.1\.2' -and $homeHtml -match 'Interface capture from v1\.0\.6' -and $homeHtml -match 'Authentic engine workbench &#183; pre-rebrand sample workspace\.' -and $homeHtml -match 'not a live forecast' -and $homeHtml -match 'Demo Widget Service')
Assert-H9 'ProofShot uses its existing authentic workbench and proof-cards capture' ($homeHtml -match '/assets/proofshot/workbench-proof-cards\.png' -and $homeHtml -match 'Underlying HyperSnatch engine v1\.6\.18 workbench before the ProofShot rebrand' -and $homeHtml -notmatch '/assets/proofshot/web-hero\.png' -and $software -notmatch '/assets/proofshot/web-hero\.png')
Assert-H9 'homepage proof copy states only the current inspectable-record promise' ($homeHtml -match 'Public releases are recorded and inspectable\. Current records link to the evidence behind each version\.' -and $homeHtml -notmatch 'No fake claims\.|No missing receipts\.|Every release is recorded')
$ledger = [regex]::Match($homeHtml, '(?s)<aside class="studio-evidence".*?</aside>').Value
Assert-H9 'five selected records use recent-release semantics and retain the complete-ledger link' ($ledger -match 'Recent public releases' -and $ledger -match 'Selected current records\.' -and $ledger -match 'Browse all records' -and ([regex]::Matches($ledger, '<li><a class="studio-ledger-row"')).Count -eq 5)
$commerceCardFailures = @()
foreach ($m in $publicHomeModules) {
  $p = @($manifest.products | Where-Object id -eq $m.id | Select-Object -First 1)[0]
  if ($p.release.releaseStatus -ne 'PUBLIC_RELEASE' -or -not $p.downloadUrl) { continue }
  $artifact = @($p.artifacts | Where-Object { $_.downloadUrl -eq $p.downloadUrl -and $_.sha256 -eq $p.sha256 } | Select-Object -First 1)[0]
  $card = [regex]::Match($homeHtml, '(?s)<article class="studio-product-card"[^>]*data-module="' + [regex]::Escape([string]$m.id) + '".*?</article>').Value
  $action = [regex]::Match($card, '<a class="studio-product-open" href="([^"]+)"([^>]*)>(.*?)</a>')
  $commerceText = 'Free download · ' + [string]$artifact.platform
  $expectedCommerce = '<p class="studio-product-state studio-product-commerce" data-commerce="free" data-platform="' + [string]$artifact.platform + '">Free download &#183; ' + [string]$artifact.platform + '</p>'
  if (-not $artifact -or -not $artifact.platform -or -not $card -or -not $action.Success -or $action.Groups[1].Value -ne $m.route -or $action.Groups[2].Value -match '\sdownload(?:\s|=|>)' -or $action.Groups[3].Value -notmatch ('View ' + [regex]::Escape([string]$p.homeName)) -or $card -notmatch [regex]::Escape($expectedCommerce)) { $commerceCardFailures += $m.id }
}
Assert-H9 'public acquisition cards show free price and exact artifact platform while opening product pages' ($commerceCardFailures.Count -eq 0 -and $commerceCardFailures.Count -lt $publicHomeModules.Count)
Assert-H9 'module identity compositions are generic scene-family and presentation rules' ($homeCss -match 'data-home-role="featured"' -and $homeCss -match 'data-home-role="major"' -and $homeCss -match 'data-home-role="secondary"' -and $homeCss -match 'data-scene-family="weather-instrument"' -and $homeCss -notmatch '(?i)cache-vault|reality-gate|ghostlayer|lights-out|cleanroom|proofshot|forgecast')
Assert-H9 'wide screens receive an expanded content rail and mobile cards recompose without overflow' ($homeCss -match 'width:\s*min\(2800px' -and $homeCss -match 'grid-template-columns:\s*repeat\(12' -and $homeCss -match '@media \(max-width: 760px\)' -and $homeCss -match 'studio-product-card\[data-home-role="secondary"\].*?grid-column:\s*1')
Assert-H9 'ultrawide studio and portfolio rails exceed the legacy 1900px cap' ($worldCss -match '\.studio-root-page \.studio-hero-grid \{ width: min\(2800px, calc\(100% - clamp\(36px, 6vw, 144px\)\)\)' -and $worldCss -match '\.studio-root-page \.studio-portfolio-heading,\.studio-root-page \.studio-portfolio-grid \{ width: min\(2800px, calc\(100% - clamp\(36px, 6vw, 144px\)\)\)')
Assert-H9 'release sequence, Truth Files, standard and canonical receipt routes remain reachable' ($homeHtml -match 'BUILD.*QUALIFY.*RECORD.*PUBLISH' -and $homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'href="/proof/"')
Assert-H9 'withdrawn work distinguishes historical successor evidence from current availability and exposes no download action' ($withdrawnHomeModules.Count -gt 0 -and $homeHtml -match 'Withdrawn · no current public release' -and $homeHtml -match 'v1\.1\.1 Developer Pilot has documented historical release evidence' -and $homeHtml -match 'No current download is authorized' -and $homeHtml -notmatch 'data-commerce="free"[^>]*Reality Gate|Download[^<]*Reality Gate')
Assert-H9 'withdrawn renderer remains generic and contains no product identity branch' ($renderer -match 'function Get-StudioWithdrawnEntries' -and $renderer -match 'function Build-StudioWithdrawn' -and $renderer -notmatch '(?s)function Build-StudioWithdrawn.*?(?=function Get-PublicCatalogCount)(?i:cache-vault|reality-gate|ghostlayer|lights-out|cleanroom|proofshot|forgecast)')
Assert-H9 'studio source contains no fixed product list or product-specific card markup' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=')
Assert-H9 'generated homepage has no unresolved template markers' ($homeHtml -notmatch '\{\{[^}]+\}\}|<!--\s*@studio-')
Assert-H9 'root keeps catalog search and comparison controls on the software page' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"')
Assert-H9 'software catalog route exists' (Test-Path (Join-Path $public 'software/index.html'))

$catalogIds = @([regex]::Matches($software, '<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$catalogExpected = @($modules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' -and (-not $_.placement -or $_.placement.catalog -ne $false) } | ForEach-Object id | Sort-Object)
Assert-H9 'software catalog entries remain registry-derived and complete' ((($catalogIds | Sort-Object) -join ',') -ceq ($catalogExpected -join ',') -and $catalogIds.Count -eq $catalogExpected.Count)
Assert-H9 'catalog search and comparison remain on the software route' ($software -match 'product-finder|finder-intents' -and $software -match 'compare-choice|data-compare')
Assert-H9 'comparison controls cover every catalog module' (([regex]::Matches($software, 'data-compare=')).Count -eq $catalogExpected.Count)
$missingA11y = 0
foreach ($pageHtml in @($homeHtml, $software)) { $ids = @([regex]::Matches($pageHtml, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }); $missingA11y += @([regex]::Matches($pageHtml, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids }).Count }
Assert-H9 'homepage and catalog accessibility references resolve' ($missingA11y -eq 0)
Assert-H9 'no generated legacy catalog anchor points to a missing root target' (@(Get-ChildItem $public -Recurse -Filter *.html | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'href="/#products"' }).Count -eq 0)
Assert-H9 'no horizontal-scroll primitive or carousel dependency' ($sourceHome -notmatch 'carousel|overflow-x:\s*(scroll|auto)')
Assert-H9 'reduced-motion support remains available' ($homeCss -match 'prefers-reduced-motion')

# The homepage ledger must exactly follow currently eligible canonical receipts.
$candidateModules = @($modules | Where-Object { $null -ne $_.homepage.evidencePriority } | Sort-Object { [int]$_.homepage.evidencePriority })
$expectedEvidence = @()
foreach ($m in $candidateModules) {
  $p = @($manifest.products | Where-Object id -eq $m.id | Select-Object -First 1)[0]
  if (-not $p) { continue }
  $artifact = @($p.artifacts | Where-Object { $_.downloadUrl -eq $p.downloadUrl -and $_.sha256 -eq $p.sha256 } | Select-Object -First 1)[0]
  if ($p.release.releaseStatus -eq 'PUBLIC_RELEASE' -and $p.release.publicVersion -and $p.verification.status -eq 'VERIFIED' -and -not $p.presentation.downloadUnavailable -and $p.downloadUrl -and $p.sha256 -match '^[a-fA-F0-9]{64}$' -and $p.sha256Url -and $artifact -and $m.card.media) { $expectedEvidence += @{module=$m;product=$p;artifact=$artifact} }
}
$evidence = [regex]::Match($homeHtml, '(?s)<aside class="studio-evidence".*?</aside>').Value
$ledgerRows = [regex]::Matches($evidence, 'class="studio-ledger-row"')
$hashVerifiedLabels = [regex]::Matches($evidence, '<span class="studio-ledger-status"><i aria-hidden="true"></i> HASH VERIFIED</span>')
Assert-H9 'evidence is omitted only when no eligible current public artifact exists' (($expectedEvidence.Count -gt 0 -and [regex]::Matches($homeHtml, 'class="studio-evidence"').Count -eq 1) -or ($expectedEvidence.Count -eq 0 -and [regex]::Matches($homeHtml, 'class="studio-evidence"').Count -eq 0))
Assert-H9 'release ledger includes every eligible current receipt and only manifest-backed values' ($ledgerRows.Count -eq $expectedEvidence.Count -and $hashVerifiedLabels.Count -eq $expectedEvidence.Count -and $evidence -match 'PUBLIC <b>v' -and $evidence -match 'SHA-256 on record' -and $evidence -match '<time datetime=' -and $evidence -match 'href="/proof/#receipt-')
foreach ($selected in $expectedEvidence) {
  $p = $selected.product
  $displayName = if ($p.homeName) { [string]$p.homeName } else { [string]$p.name }
  Assert-H9 "ledger binds $displayName to its current version and receipt" ($evidence.Contains($displayName) -and $evidence.Contains([string]$p.release.publicVersion) -and $evidence.Contains([string]$p.verification.verifiedAt) -and $evidence.Contains('/proof/#receipt-' + [string]$p.id) -and $evidence -notmatch [regex]::Escape([string]$p.sha256) -and $evidence -notmatch [regex]::Escape([string]$selected.artifact.filename))
}
$proofIndex = Get-Content (Join-Path $public 'proof/index.json') -Raw -Encoding UTF8
Assert-H9 'homepage release references are generated from canonical manifest data' ($homeHtml -notmatch '\{\{products\.' -and $proofIndex -match '"products"')
$loLedger = [regex]::Match($evidence, '(?s)<li><a class="studio-ledger-row" href="/proof/#receipt-lights-out">.*?</a></li>').Value
$proofHtml = Get-Content (Join-Path $public 'proof/index.html') -Raw -Encoding UTF8
$loProof = [regex]::Match($proofHtml, '(?s)<article class="receipt-card" id="receipt-lights-out".*?</article>').Value
Assert-H9 'Lights Out ledger narrows verification to hash while proof retains pending custody' ($loLedger -match ' HASH VERIFIED</span>' -and $loProof -match '<dt>Artifact hash verified</dt><dd class="status-verified">VERIFIED</dd>' -and $loProof -match '<dt>Artifact custody</dt><dd class="status-pending">PENDING</dd>')

if ($fail -gt 0) { Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Red; exit 1 }
Write-Host "=== H9 RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
