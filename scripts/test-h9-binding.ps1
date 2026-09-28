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
$rootModules = @($publicModules | Where-Object { $_.homepage -and $_.homepage.role -eq 'studioPortfolio' -and $_.homepage.visibility -eq 'visible' } | Sort-Object { [int]$_.homepage.order }, { [int]$_.order })
$releasedRootModules = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'PUBLIC_RELEASE' })
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
Assert-Binding 'released module metadata → generic portfolio renderer → generated root order agrees' ((($renderedPortfolio -join ',') -ceq ((@($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'PUBLIC_RELEASE' } | ForEach-Object id)) -join ',')) -and $renderedPortfolio.Count -eq @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'PUBLIC_RELEASE' }).Count)
$expectedWithdrawn = @($rootModules | Where-Object { (@($manifest.products | Where-Object id -eq $_.id | Select-Object -First 1)[0]).release.releaseStatus -eq 'WITHDRAWN' })
Assert-Binding 'withdrawn modules render in their own registry-ordered scene' ((($renderedWithdrawn -join ',') -ceq (($expectedWithdrawn | ForEach-Object id) -join ',')) -and $renderedWithdrawn.Count -eq $expectedWithdrawn.Count)
Assert-Binding 'the studio hero is brand-owned and contains no featured product renderer' ($homeHtml -match 'studio-hero-emblem' -and $homeHtml -notmatch 'studio-hero-product|@studio-hero-product')
Assert-Binding 'module presentation metadata selects distinct public card compositions' (@($rootModules | Where-Object { $_.homepage.presentation -eq 'feature' }).Count -ge 1 -and @($rootModules | Where-Object { $_.homepage.presentation -eq 'editorial' }).Count -eq 1 -and ([regex]::Matches($homeHtml, 'data-presentation="feature"')).Count -ge 1 -and ([regex]::Matches($homeHtml, 'data-presentation="editorial"')).Count -eq 1)
$renderer = Read-Source 'scripts/build-site.ps1'
$homeRendererStart = $renderer.IndexOf('function Get-StudioPortfolioEntries')
$homeRendererEnd = $renderer.IndexOf('function Get-PublicCatalogCount')
$homeRenderer = if ($homeRendererStart -ge 0 -and $homeRendererEnd -gt $homeRendererStart) { $renderer.Substring($homeRendererStart, $homeRendererEnd - $homeRendererStart) } else { '' }
Assert-Binding 'role renderer contains no product identity branches' ($homeRenderer.Length -gt 0 -and $homeRenderer -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot')
Assert-Binding 'root source contains no fixed product list, product identity or product-specific card markup' ((Read-Source 'index.html') -notmatch '(?i)cache vault|reality gate|forgecast|ghostlayer|lights out|cleanroom|proofshot|data-module=')
Assert-Binding 'root structural CSS uses only generic presentation semantics' ((Read-Source 'h9-homepage.css') -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot|data-module="')
$bindingFailures = @($releasedRootModules | Where-Object { $m=$_; $media=$m.card.media; $homeHtml -notmatch ('data-module="' + [regex]::Escape([string]$m.id) + '"[^>]*data-presentation="' + [regex]::Escape([string]$m.homepage.presentation) + '"') -or $homeHtml -notmatch [regex]::Escape([string]$m.route) -or $homeHtml -notmatch [regex]::Escape([string]$media) -or $homeHtml -notmatch [regex]::Escape([string]$m.theme.accent) })
Assert-Binding 'generated public cards bind role, route, authentic media and accent to module metadata' ($bindingFailures.Count -eq 0)
Assert-Binding 'withdrawn scene binds media and product route to its module without download controls' (@($expectedWithdrawn | Where-Object { $m=$_; $homeHtml -notmatch ('data-module="' + [regex]::Escape([string]$m.id) + '"') -or $homeHtml -notmatch [regex]::Escape([string]$m.card.media) -or $homeHtml -notmatch [regex]::Escape([string]$m.route) }).Count -eq 0 -and $homeHtml -match 'studio-withdrawn-product' -and $homeHtml -notmatch 'studio-withdrawn-product[^>]*>[\s\S]{0,1200}data-commerce="free"')
$nonRootVisible = @($publicModules | Where-Object { $_.homepage.visibility -eq 'hidden' })
Assert-Binding 'root-hidden modules are omitted from root only while routes/catalog/truth remain present' (@($nonRootVisible | Where-Object { $id=$_.id; $homeHtml -match ('data-module="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "$id/index.html")) -or $software -notmatch ('data-product="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "truth/products/$id.json")) }).Count -eq 0)
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
$eligibleEvidence = @($sourceModules | Where-Object { $null -ne $_.homepage.evidencePriority } | Sort-Object { [int]$_.homepage.evidencePriority })
$selectedEvidence = $null
foreach ($m in $eligibleEvidence) {
  $p = @($manifest.products | Where-Object id -eq $m.id | Select-Object -First 1)[0]
  $artifact = @($p.artifacts | Where-Object { $_.downloadUrl -eq $p.downloadUrl -and $_.sha256 -eq $p.sha256 } | Select-Object -First 1)[0]
  if ($p.release.releaseStatus -eq 'PUBLIC_RELEASE' -and $p.release.publicVersion -and $p.verification.status -eq 'VERIFIED' -and -not $p.presentation.downloadUnavailable -and $p.downloadUrl -and $p.sha256 -match '^[a-fA-F0-9]{64}$' -and $p.sha256Url -and $artifact -and $m.card.media) { $selectedEvidence = $p; break }
}
$evidenceHtml = [regex]::Match($homeHtml, '(?s)<aside class="studio-evidence".*?</aside>').Value
Assert-Binding 'compact evidence selector uses the first canonically eligible public artifact' (($selectedEvidence -and $evidenceHtml -and $evidenceHtml.Contains([string]$selectedEvidence.name) -and $evidenceHtml.Contains([string]$selectedEvidence.release.publicVersion) -and $evidenceHtml.Contains([string]$selectedEvidence.verification.verifiedAt)) -or (-not $selectedEvidence -and -not $evidenceHtml))
Assert-Binding 'homepage ledger links to the canonical release record without duplicating digests or artifact filenames' (($selectedEvidence -and $evidenceHtml.Contains('/proof/#receipt-' + [string]$selectedEvidence.id) -and $homeHtml -notmatch [regex]::Escape([string]$selectedEvidence.sha256) -and $evidenceHtml -notmatch [regex]::Escape([string]$selectedEvidence.artifacts[0].filename)) -or (-not $selectedEvidence -and -not $evidenceHtml))
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
