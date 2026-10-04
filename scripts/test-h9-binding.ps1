[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$passed = 0; $failed = 0
function Assert-Binding([string]$name, [bool]$condition) { if ($condition) { $script:passed++; Write-Host "PASS: $name" } else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red } }
function Read-Source([string]$name) { [IO.File]::ReadAllText((Join-Path $Root $name)) }
function Read-Built([string]$name) { [IO.File]::ReadAllText((Join-Path $PublicDir $name)) }
function Json($value) { ConvertTo-Json -InputObject $value -Depth 60 -Compress }
$homeHtml = Read-Built 'index.html'; $software = Read-Built 'software/index.html'
$manifest = (Read-Source 'site-manifest.json') | ConvertFrom-Json
$registry = (Read-Built 'proof/index.json') | ConvertFrom-Json
$truthIndex = (Read-Built 'truth/index.json') | ConvertFrom-Json
$sourceModules = @(Get-ChildItem -LiteralPath (Join-Path $Root 'products') -Directory | ForEach-Object { (Read-Source (Join-Path (Join-Path 'products' $_.Name) 'module.json')) | ConvertFrom-Json })
$publicModules = @($sourceModules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' })
$renderedPortfolio = @([regex]::Matches($homeHtml, '<article class="studio-product-card"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$renderedWithdrawn = @([regex]::Matches($homeHtml, '<article class="studio-withdrawn-product"[^>]*data-module="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Write-Host '=== H9 STUDIO ROOT BINDING GUARD ==='
$base = 'dfcf2d38fd333f86d10c7d3607856349fcbaa518'
& git -C $Root merge-base --is-ancestor $base HEAD; $ancestry = $LASTEXITCODE
Assert-Binding 'candidate preserves exact qualified RG_TRUTH_1 base ancestry' ($ancestry -eq 0)
$moduleIds = @($publicModules | ForEach-Object id | Sort-Object)
$manifestIds = @($manifest.products | Where-Object visible | ForEach-Object id | Sort-Object)
$registryIds = @($registry.products | ForEach-Object id | Sort-Object)
Assert-Binding 'registry identities bind to public module and manifest identities' ((($moduleIds -join ',') -ceq ($manifestIds -join ',')) -and (($registryIds -join ',') -ceq ($manifestIds -join ',')))
$homeSections = @([regex]::Matches($homeHtml, '<section class="(studio-hero|studio-portfolio|studio-proof)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Binding 'Home contains hero and proof only, with no product portfolio or evidence card' (($homeSections -join ',') -ceq 'studio-hero,studio-proof' -and $renderedPortfolio.Count -eq 0 -and $homeHtml -notmatch 'studio-portfolio|studio-evidence|studio-product-tab|data-home-products')
$expectedWithdrawn = @($manifest.products | Where-Object { $_.release.releaseStatus -eq 'WITHDRAWN' })
Assert-Binding 'withdrawn modules do not create a standalone Home scene' ($expectedWithdrawn.Count -gt 0 -and $renderedWithdrawn.Count -eq 0 -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work')
Assert-Binding 'the studio hero uses responsive Open Forge artwork and the established PF mark without a featured product renderer' ($homeHtml -match 'open-forge-scene-1536\.webp' -and $homeHtml -match 'open-forge-scene-960\.webp' -and $homeHtml -match 'proof-foundry-forged-artifact\.png' -and $homeHtml -notmatch 'studio-hero-product|@studio-hero-product|studio-hero-emblem')
Assert-Binding 'root source contains no fixed product list, product identity or product-specific card markup' ((Read-Source 'index.html') -notmatch '(?i)cache vault|reality gate|forgecast|ghostlayer|lights out|cleanroom|proofshot|data-module=')
Assert-Binding 'root structural CSS uses only generic presentation semantics' ((Read-Source 'h9-homepage.css') -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot|data-module="')
$bindingFailures = @($publicModules | Where-Object { $m=$_; $p=@($manifest.products | Where-Object id -eq $m.id | Select-Object -First 1)[0]; $card=[regex]::Match($software, '(?s)<article class="product-card[^>]*data-product="' + [regex]::Escape([string]$m.id) + '".*?</article>').Value; -not $card -or $card -notmatch [regex]::Escape([string]$m.route) -or $card -notmatch [regex]::Escape([string]$m.card.media) -or $card -notmatch [regex]::Escape([string]$m.theme.accent) -or ($p.release.publicVersion -and $card -notmatch ('v' + [regex]::Escape([string]$p.release.publicVersion))) })
Assert-Binding 'Software cards bind route, authentic media, accent and public version to module truth' ($bindingFailures.Count -eq 0)
Assert-Binding 'withdrawn record remains in canonical product and catalog routes' (@($expectedWithdrawn | Where-Object { $m=$_; -not (Test-Path (Join-Path $PublicDir "$($m.id)/index.html")) -or $software -notmatch [regex]::Escape([string]$m.route) }).Count -eq 0)
Assert-Binding 'all product routes, catalog cards and Truth outputs remain reachable off Home' (@($publicModules | Where-Object { $id=$_.id; $homeHtml -match ('data-module="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "$id/index.html")) -or $software -notmatch ('data-product="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "truth/products/$id.json")) }).Count -eq 0)
$missingPublicRoutes = @($manifest.products | Where-Object { $_.visible -and (-not (Test-Path (Join-Path $PublicDir "$($_.id)/index.html")) -or -not (Test-Path (Join-Path $PublicDir "truth/products/$($_.id).json"))) })
Assert-Binding 'every public canonical product retains route and truth output' ($missingPublicRoutes.Count -eq 0)
$truthIds = @($truthIndex.products | ForEach-Object id | Sort-Object)
Assert-Binding 'machine truth enumerates the same public registry identities' (($truthIds -join ',') -ceq ($manifestIds -join ','))
Assert-Binding 'software catalog enumerates the manifest catalog projection' (([regex]::Matches($software, '<article\b[^>]*data-product="').Count) -eq @($manifest.products | Where-Object { $_.visible -and (-not $_.placement -or $_.placement.catalog -ne $false) }).Count)
Assert-Binding 'root has exactly one primary studio heading and main landmark' (([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<main\b')).Count -eq 1)
Assert-Binding 'root heading references resolve' (@([regex]::Matches($homeHtml, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin @([regex]::Matches($homeHtml, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) }).Count -eq 0)
Assert-Binding 'root and catalog contain no unresolved tokens' ($homeHtml -notmatch '\{\{[^}]+\}\}|<!--\s*@studio-' -and $software -notmatch '\{\{[^}]+\}\}')
Assert-Binding 'public navigation keeps software, proof, Truth Files and proof standard paths' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'href="/proof-standard/"')
$rg = @($manifest.products | Where-Object id -eq 'reality-gate' | Select-Object -First 1)[0]
$rgPage = Read-Built 'reality-gate/index.html'
Assert-Binding 'Reality Gate withdrawal truth remains canonical and routed without a download CTA' ($rg.release.releaseStatus -eq 'WITHDRAWN' -and $rg.release.withdrawnVersion -eq '1.1.0' -and $rg.downloadUrl -eq $null -and $rgPage -match 'Withdrawn' -and $rgPage -notmatch '<a[^>]+>\s*Download')
Assert-Binding 'Home proof copy links to canonical records without embedding a product digest' ($homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'does not by itself establish custody or safety' -and @($manifest.products | Where-Object { $_.sha256 -and $homeHtml.Contains([string]$_.sha256) }).Count -eq 0)
$cvManifest = @($manifest.products | Where-Object id -eq 'cache-vault' | Select-Object -First 1)[0]
$cvRegistry = @($registry.products | Where-Object id -eq 'cache-vault' | Select-Object -First 1)[0]
$cvTruth = @($truthIndex.products | Where-Object id -eq 'cache-vault' | Select-Object -First 1)[0]
Assert-Binding 'Cache Vault Windows and Android v0.3.1 stay source-bound across catalogue and public records' ($cvManifest.release.publicVersion -eq '0.3.1' -and $cvManifest.release.companionPublicVersion -eq '0.3.1' -and $cvRegistry.release.publicVersion -eq '0.3.1' -and $cvRegistry.artifacts.Count -ge 2 -and $cvTruth.version -eq '0.3.1' -and $software -match 'data-product="cache-vault"' -and $software -match 'class="card-version">v0\.3\.1')
foreach ($page in @(@{name='homepage';html=$homeHtml},@{name='software';html=$software})) {
  $ids = @([regex]::Matches($page.html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  Assert-Binding "$($page.name): document IDs are unique" (@($ids | Sort-Object -Unique).Count -eq $ids.Count)
  $missing = @([regex]::Matches($page.html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-Binding "$($page.name): accessible heading references resolve" ($missing.Count -eq 0)
  Assert-Binding "$($page.name): one H1 and main landmark" (([regex]::Matches($page.html, '<h1\b')).Count -eq 1 -and ([regex]::Matches($page.html, '<main\b')).Count -eq 1)
  Assert-Binding "$($page.name): no unresolved tokens" ($page.html -notmatch '\{\{[^}]+\}\}')
}
Assert-Binding 'responsive root primitives include mobile layout and reduced-motion support' ((Read-Source 'h9-homepage.css') -match '@media \(max-width: 390px\)' -and (Read-Source 'h9-homepage.css') -match 'prefers-reduced-motion')
Write-Host "=== H9 BINDING RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }; exit 0
