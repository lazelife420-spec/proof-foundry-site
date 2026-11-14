# Current H9 binding composition and truth contract. Historical tests are intentionally untouched.
[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$production = '34a291d78fa92f1a18cf76cef3ee56b391186e77'
$passed = 0; $failed = 0
function Assert-Binding([string]$name, [bool]$condition) {
  if ($condition) { $script:passed++; Write-Host "PASS: $name" }
  else { $script:failed++; Write-Host "FAIL: $name" }
}
function Read-Source([string]$name) { return [IO.File]::ReadAllText((Join-Path $Root $name)) }
function Read-Built([string]$name) { return [IO.File]::ReadAllText((Join-Path $PublicDir $name)) }
function Json($value) { return ConvertTo-Json -InputObject $value -Depth 50 -Compress }
function Digest([string]$name) { return (Get-FileHash -LiteralPath (Join-Path $Root $name) -Algorithm SHA256).Hash.ToLowerInvariant() }
$homeHtml = Read-Built 'index.html'
$software = Read-Built 'software/index.html'
$manifest = (Read-Source 'site-manifest.json') | ConvertFrom-Json
# git emits UTF-8; force the console decoder so multi-byte manifest copy does not mojibake
$prevOutEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
try { $canonical = ((& git -C $Root show "${production}:site-manifest.json") -join "`n") | ConvertFrom-Json }
finally { [Console]::OutputEncoding = $prevOutEnc }
$registry = (Read-Built 'proof/index.json') | ConvertFrom-Json
. (Join-Path $Root 'scripts/fixtures/h9/custody.ps1')
$custody = (Read-Source 'scripts/fixtures/h9/binding-custody.json') | ConvertFrom-Json
Write-Host '=== CURRENT H9 BINDING GUARD ==='
# The reviewed production object stays pinned; a legitimate landing advances master.
& git -C $Root merge-base --is-ancestor $production HEAD
$productionAncestryExit = $LASTEXITCODE
Assert-Binding 'authority: inspected production commit is an ancestor of candidate HEAD' ($productionAncestryExit -eq 0)
# ForgeCast decision-first copy tranche 2026-09-19 (owner-authorized): the
# forgecast summary / cardSummary / presentation.valueLine fields carry the
# approved new positioning. Neutralize exactly those copy fields on both
# sides; all release, artifact, signing and availability truth must still be
# byte-identical to the pinned production object.
foreach ($set in @(@($manifest.products), @($canonical.products))) {
  $fcP = @($set | Where-Object { $_.id -eq 'forgecast' }) | Select-Object -First 1
  if ($fcP) { $fcP.summary = $null; $fcP.cardSummary = $null; if ($fcP.presentation) { $fcP.presentation.valueLine = $null } }
  # VR1 visual refoundation (2026-09-21): ProofShot's catalog card image moved
  # from the pre-rebrand HyperSnatch workbench capture to the current-brand
  # proof-card capture. Neutralize exactly those presentation fields on both
  # sides; release, artifact and availability truth still compares exactly.
  $psP = @($set | Where-Object { $_.id -eq 'proofshot' }) | Select-Object -First 1
  if ($psP -and $psP.presentation) {
    $psP.presentation.cardImage = $null
    $psP.presentation.cardImageAlt = $null
    $psP.presentation.cardImageWidth = $null
    $psP.presentation.cardImageHeight = $null
  }
  # H10 truth consolidation (2026-09-20): narrow manifest fields added as
  # canonical owners for facts pages previously hardcoded —
  # release.sourceCommit / release.companionCandidateVersion (cache-vault) and
  # packageId (forgecast). Production's manifest predates them; drop them on
  # both sides so all other truth still requires byte equality.
  foreach ($pp in $set) {
    if ($pp.release) {
      $pp.release.PSObject.Properties.Remove('companionCandidateVersion')
      $pp.release.PSObject.Properties.Remove('sourceCommit')
      $pp.release.PSObject.Properties.Remove('companionPublicVersion')
    }
    $pp.PSObject.Properties.Remove('packageId')
    # CP-0189 restoration: product.directory = approved catalog presentation
    # copy only; pinned production predates it.
    $pp.PSObject.Properties.Remove('directory')
  }
}
Assert-Binding 'authority: unchanged public product objects equal inspected production (authorized copy/H10 migrations only)' ((Json @($manifest.products | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') })) -ceq (Json @($canonical.products | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') })))
Assert-Binding 'authority: Lights Out v11.2.0 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'lights-out')[0].release.publicVersion -eq '11.2.0') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
Assert-Binding 'authority: Cache Vault v0.3.1 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.publicVersion -eq '0.3.1') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
Assert-Binding 'authority: seven registry identities equal production' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($product in $manifest.products) {
  $actual = @($registry.products | Where-Object id -eq $product.id)[0]
  $expectedRelease = [ordered]@{publicVersion=$product.release.publicVersion;candidateVersion=$product.release.candidateVersion;releaseStatus=$product.release.releaseStatus;publishedAt=$product.release.publishedAt;withdrawnVersion=$product.release.withdrawnVersion;withdrawalReason=$product.release.withdrawalReason}
  Assert-Binding "truth: $($product.id) registry release/status/candidate parity" ((Json $actual.release) -ceq (Json $expectedRelease))
  Assert-Binding "truth: $($product.id) registry artifact URLs/digests/signing/size parity" ((Json $actual.artifacts) -ceq (Json $product.artifacts))
}
# The fixture retains the original baseline hashes and explicitly accounts for excluded review assets.
foreach ($file in $custody.entries) {
  Assert-Binding "custody: entry bytes preserved for $($file.path)" (Test-H9Custody $Root $file)
}
$expectedIds = @($canonical.products | ForEach-Object { [string]$_.id })
$sourceModules = @(Get-ChildItem -LiteralPath (Join-Path $Root 'products') -Directory | ForEach-Object {
  (Read-Source (Join-Path (Join-Path 'products' $_.Name) 'module.json')) | ConvertFrom-Json
})
$publicIds = @($canonical.products | Where-Object { $_.visible } | ForEach-Object { [string]$_.id } | Sort-Object)
$registryIds = @($registry.products | ForEach-Object { [string]$_.id } | Sort-Object)
Assert-Binding 'source/registry binding: public module identities match authoritative manifest identities' ((($sourceModules | Where-Object { $_.visibility -eq 'visible' -and $_.lifecycle -eq 'public-eligible' } | ForEach-Object id | Sort-Object) -join ',') -ceq ($publicIds -join ',') -and ($registryIds -join ',') -ceq ($publicIds -join ','))
$missingPublicRoutes = @($canonical.products | Where-Object {
  if (-not $_.visible) { return $false }
  $productRoute = Join-Path $PublicDir (Join-Path ([string]$_.id) 'index.html')
  $truthRecord = Join-Path $PublicDir (Join-Path 'truth/products' ([string]$_.id + '.json'))
  -not (Test-Path $productRoute) -or -not (Test-Path $truthRecord)
})
Assert-Binding 'visibility/truth binding: every public manifest product retains a generated route and truth record' ($missingPublicRoutes.Count -eq 0)
foreach ($page in @(@{name='homepage';html=$homeHtml},@{name='software';html=$software})) {
  $ids = @([regex]::Matches($page.html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $missing = @([regex]::Matches($page.html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-Binding "$($page.name): unique document IDs" (@($ids | Sort-Object -Unique).Count -eq $ids.Count)
  Assert-Binding "$($page.name): accessible heading references resolve" ($missing.Count -eq 0)
  Assert-Binding "$($page.name): exactly one H1 and main landmark" (([regex]::Matches($page.html, '<h1\b')).Count -eq 1 -and ([regex]::Matches($page.html, '<main\b')).Count -eq 1)
  Assert-Binding "$($page.name): no unresolved template tokens" ($page.html -notmatch '\{\{[^}]+\}\}')
  Assert-Binding "$($page.name): owner-selected G favicon retained" ($page.html -match 'rel="icon"[^>]*/brand/PF_HEADER_MARK\.svg' -or $page.html -match 'href="/brand/PF_HEADER_MARK.svg"[^>]*rel="icon"')
  Assert-Binding "$($page.name): concept bitmap excluded" ($page.html -notmatch 'a_dark_cinematic_high_contrast_website_landing_p')
}
# CP-0189 restoration: the approved ledger page is the homepage authority.
Assert-Binding 'architecture: approved truthful hero headline' ($homeHtml -match 'Real software' -and $homeHtml -match 'leaves a record\.')
Assert-Binding 'identity: machined PF emblem remains on the homepage' ($homeHtml -match 'PF_MARK_G_TI_460\.webp')
Assert-Binding 'identity: engraved route-chain navigation restored' ($homeHtml -match 'pf-route-chain' -and $homeHtml -match 'pf-chain-station' -and $homeHtml -match 'pf-route-coupler')
Assert-Binding 'architecture: catalog controls stay on software route' ($homeHtml -notmatch 'data-directory-finder|data-compare=|id="product-search"')
# The restored homepage is authored narrative: no per-product claims render on
# it, so no surface can disagree with release truth.
Assert-Binding 'generated template: homepage carries no per-product claims' ((Read-Source 'index.html') -notmatch 'data-product="(?:cache-vault|reality-gate|forgecast|lights-out|cleanroom|ghostlayer|proofshot)"' -and $homeHtml -notmatch 'data-product="(?:cache-vault|reality-gate|forgecast|lights-out|cleanroom|ghostlayer|proofshot)"')
Assert-Binding 'composition: approved proof-chain and emblem plate present' ($homeHtml -match 'ledger-chain' -and $homeHtml -match 'pfa-machine' -and $homeHtml -match 'pf-emblem')
Assert-Binding 'composition: inspect-the-mark dialog restored' ($homeHtml -match 'pf-mark-dialog' -and $homeHtml -match 'data-mark-open')
$receiptDialog = [regex]::Match($homeHtml,'(?s)<dialog class="pf-dialog pf-receipt-dialog".*?</dialog>').Value
Assert-Binding 'receipt: release-receipt dialog restored with product scope' ($receiptDialog -match 'data-receipt-products="[^"]*cache-vault' -and $homeHtml -match 'data-receipt-open="cache-vault"')
$cv = @($manifest.products | Where-Object id -eq 'cache-vault')[0]
Assert-Binding 'receipt: canonical 64-hex digest stays off the homepage narrative' ($homeHtml -notmatch [regex]::Escape($cv.artifacts[0].sha256))
Assert-Binding 'receipt: source commit stays off the homepage narrative' ($homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29')
Assert-Binding 'receipt: 40-char commit never labelled SHA-256' ($homeHtml -notmatch '<dt>SHA-256</dt>\s*<dd[^>]*>[a-f0-9]{40}</dd>')
Assert-Binding 'proof: record-chain editorial meaning survives' ($homeHtml -match 'A record, all the way through\.')
Assert-Binding 'ending: studio statement and real G identity accompany direct catalog action' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'PF_MARK_G_TI|pf-emblem' -and $homeHtml -match 'Browse Products')
Assert-Binding 'discovery: Proof Standard, release records, support and studio routes remain accessible' ($homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/support/"' -and $homeHtml -match 'href="/about/"')
# Catalog discovery moved to the approved directory: each public product is
# reachable from /software/ with its release state.
foreach ($id in $publicIds) {
  # ProofShot is the approved history route, not a directory entry.
  if ($id -eq 'proofshot') { continue }
  Assert-Binding "discovery: catalog contains $id identity and route" ($software.Contains('data-directory-entry="' + $id + '"') -and $software.Contains('href="/' + $id + '/"'))
}
Assert-Binding 'truth: ProofShot history route preserved off the directory grid' ($software -match 'href="/proofshot/"' -and $software -notmatch 'data-directory-entry="proofshot"')
Assert-Binding 'truth: Reality Gate directory entry shows the withdrawn record without a download' (($software -match 'data-directory-entry="reality-gate"[^>]*data-availability="none"') -and ($software -match 'public v1\.1\.0 withdrawn'))
Assert-Binding 'truth: Lights Out directory entry states v11.2.0 public + v11.1.1 companion' ($software -match 'v11\.2\.0' -and $software -match 'v11\.1\.1')
Assert-Binding 'truth: prohibited absolute GhostLayer and ProofShot claims absent' ($homeHtml -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified' -and $software -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified')
$catalogIds = @([regex]::Matches($software, 'data-directory-entry="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Binding 'catalog: every canonical product appears in the directory' (@($expectedIds | Where-Object { $_ -in $catalogIds }).Count -eq @($expectedIds | Where-Object { $_ -ne 'proofshot' }).Count -and 'reality-gate' -in $catalogIds)
Assert-Binding 'catalog: approved directory composition restored' ($software -match 'h9-software-hero' -and $software -match 'pf-directory-grid' -and $software -match 'Find your way in\.')
Assert-Binding 'catalog: route-only finder UI ships hidden for progressive enhancement' ($software -match 'data-directory-finder[^>]*hidden' -and $software -match 'name="query"' -and $software -match 'name="group"' -and $software -match 'name="availability"')
Assert-Binding 'catalog: internal systems have no public installer' (([regex]::Matches($software, 'data-availability="none"')).Count -ge 4 -and $software -match 'Internal product')
Assert-Binding 'catalog: finder explains availability filtering' ($software -match 'Available downloads' -and $software -match 'No public installer')
Assert-Binding 'catalog: mechanical navigation uses content-addressed loading' ($software -match '/foundry-navigation\.js\?v=[a-f0-9]{12}')
Assert-Binding 'motion: CSS reduced-motion support remains' ((Read-Source 'h9-homepage.css') -match 'prefers-reduced-motion')
Assert-Binding 'motion: JS reduced-motion support remains' ((Read-Source 'h9-homepage.js') -match 'prefers-reduced-motion')
Write-Host "=== CURRENT H9 BINDING RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
