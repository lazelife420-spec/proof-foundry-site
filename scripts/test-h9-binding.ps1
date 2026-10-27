[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
. "$PSScriptRoot/release-qualification.ps1"
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$passed = 0; $failed = 0
function Assert-Binding([string]$name, [bool]$condition) { if ($condition) { $script:passed++; Write-Host "PASS: $name" } else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red } }
function Read-Source([string]$name) { [IO.File]::ReadAllText((Join-Path $Root $name)) }
function Read-Built([string]$name) { [IO.File]::ReadAllText((Join-Path $PublicDir $name)) }
function Json($value) { ConvertTo-Json -InputObject $value -Depth 60 -Compress }

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
    if ($line -match $linePattern) { $ok = $Matches[1] -eq 'PASS'; if ($ok) { $seenPass++ } else { $seenFail++ }; Assert-Binding "${label}: $($Matches[2])" $ok }
    elseif ($line -match $footerPattern) { $footers += , @([int]$Matches[1], [int]$Matches[2]) }
  }
  if ($seenPass + $seenFail -eq 0) { $output | Select-Object -Last 5 | ForEach-Object { Write-Host "      $_" } }
  Assert-Binding "${label}: ran to completion: exit $code, one consistent footer, PASS=$seenPass (minimum $minimumPass) FAIL=$seenFail" ($code -eq 0 -and $footers.Count -eq 1 -and $footers[0][0] -eq $seenPass -and $footers[0][1] -eq $seenFail -and $seenPass -ge [Math]::Max(1, $minimumPass) -and $seenFail -eq 0)
}
$homeHtml = Read-Built 'index.html'; $software = Read-Built 'software/index.html'
$manifest = Get-AuthoredReleaseManifest
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
$homeSections = @([regex]::Matches($homeHtml, '<section class="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Binding 'Home preserves all eight Proof Ledger sections and excludes the obsolete portfolio renderer' (($homeSections -join ',') -ceq 'ledger-hero,ledger-featured,ledger-chain,ledger-paper ledger-doctrine,ledger-specimen,ledger-paper ledger-index,ledger-position,ledger-close' -and $renderedPortfolio.Count -eq 0 -and $homeHtml -notmatch 'studio-portfolio|studio-evidence|studio-product-tab|data-home-products')
$expectedWithdrawn = @($manifest.products | Where-Object { $_.release.releaseStatus -eq 'WITHDRAWN' })
Assert-Binding 'withdrawal appears only as an unavailable record in the release index' ($expectedWithdrawn.Count -eq 1 -and $renderedWithdrawn.Count -eq 0 -and $homeHtml -match 'data-release-status="WITHDRAWN"' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work')
Assert-Binding 'Proof Ledger uses its unified plate and micro PF derivative without a featured-product renderer' ($homeHtml -match 'ledger-plate-scene' -and $homeHtml -match 'PF_HEADER_MARK\.svg' -and $homeHtml -match 'PF_MAKER_SEAL\.svg' -and $homeHtml -match 'PF_RECEIPT_WATERMARK\.svg' -and $homeHtml -notmatch 'PF_MARK_G_MONO_LIGHT\.svg|pf-stamp-top' -and $homeHtml -match '/pf-home-ledger\.css' -and $homeHtml -notmatch 'studio-hero-product|@studio-hero-product|studio-hero-emblem')
Assert-Binding 'root source contains no fixed product list, product identity or product-specific card markup' ((Read-Source 'index.html') -notmatch '(?i)cache vault|reality gate|forgecast|ghostlayer|lights out|cleanroom|proofshot|data-module=')
Assert-Binding 'active root CSS uses generic presentation semantics' ((Read-Source 'pf-home-ledger.css') -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot|data-module="')
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
$specimen = @($manifest.products | Where-Object id -eq 'proofshot')[0]
# Digest option A (owner, 2026-10-13): the opened receipt inspector shows every
# product's full SHA-256, read from /truth/ when opened; the static homepage
# keeps only the specimen's digest.
Assert-Binding 'Static homepage release specimen binds its digest and version to the authored ProofShot record, and the page carries no primary digest of any other product' ($homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'Checksums identify exact files' -and (Read-Built 'proof/index.html') -match 'Artifact custody' -and $homeHtml -match 'data-ledger-specimen="proofshot"' -and $homeHtml.Contains([string]$specimen.sha256) -and $homeHtml.Contains('v' + [string]$specimen.release.publicVersion) -and @($manifest.products | Where-Object { $_.sha256 -and $homeHtml.Contains([string]$_.sha256) }).Count -eq 1)
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
Assert-Binding 'active responsive root primitives include mobile layout and reduced-motion support' ((Read-Source 'pf-home-ledger.css') -match '@media\s*\(max-width:640px\)' -and (Read-Source 'pf-home-ledger.css') -match 'prefers-reduced-motion:reduce')

# ── Homepage receipt inspector (owner ruling, 2026-10-13) ────────────────────
# The receipt checks run inside this gate so the qualified inventory stays at 25
# test-*.ps1 scripts. check-home-receipt-truth validates every /truth/ record
# with two validators and binds the inspector to the records, /proof/ and
# release-truth.json. The external parity regressions run unchanged.
Invoke-SubCheck 'receipt truth' (Get-Command pwsh).Source @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'check-home-receipt-truth.ps1'), '-PublicDir', $PublicDir) '^(PASS|FAIL): (.*)$' '^=== HOMEPAGE RECEIPT TRUTH RESULT: (\d+) passed, (\d+) failed ===$' 168
$parityScript = Join-Path $Root 'vendor/pf-v5-receipt-parity/PF_V5_RECEIPT_PARITY_REGRESSIONS.mjs'
$parityPinned = $false
try {
  $parityProvenance = (Read-Source 'vendor/pf-v5-receipt-parity/provenance.json') | ConvertFrom-Json
  $parityPinned = (Test-Path -LiteralPath $parityScript) -and $parityProvenance.sha256 -ceq '476bdd3bb6dae3190d7e696252da350d2e04a72ec6222fa3a6de7d4ce7d03771' -and (Get-FileHash -LiteralPath $parityScript -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $parityProvenance.sha256
} catch { Write-Host "      $_" }
Assert-Binding 'receipt parity regressions are the reviewed external file, byte for byte' $parityPinned
# The file reads <root>/pf-truth-receipt.js and <root>/built/{truth,proof}; give
# it exactly this gate's source module and -PublicDir records.
$parityRoot = Join-Path ([IO.Path]::GetTempPath()) ('pf-receipt-parity-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
try {
  foreach ($rel in 'truth/schema-v1.json', 'truth/index.json', 'truth/products/proofshot.json', 'proof/index.json') {
    $dest = Join-Path (Join-Path $parityRoot 'built') $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PublicDir $rel) -Destination $dest
  }
  Copy-Item -LiteralPath (Join-Path $Root 'pf-truth-receipt.js') -Destination (Join-Path $parityRoot 'pf-truth-receipt.js')
  Invoke-SubCheck 'receipt parity regressions' 'node' @($parityScript, $parityRoot) '^(PASS|FAIL)  (.*)$' '^RESULT: (\d+) passed, (\d+) failed$' 10
} catch {
  Assert-Binding "receipt parity regressions: inputs could be staged ($_)" $false
} finally { Remove-Item -LiteralPath $parityRoot -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "=== H9 BINDING RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }; exit 0
