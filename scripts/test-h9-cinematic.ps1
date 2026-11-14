# Current H9 cinematic contract. Historical tests are intentionally untouched.
[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$production = '34a291d78fa92f1a18cf76cef3ee56b391186e77'
$passed = 0; $failed = 0
function Assert-Cinematic([string]$name, [bool]$condition) {
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
$custody = (Read-Source 'scripts/fixtures/h9/cinematic-custody.json') | ConvertFrom-Json
Write-Host '=== CURRENT H9 CINEMATIC GUARD ==='
# The reviewed production object stays pinned; a legitimate landing advances master.
& git -C $Root merge-base --is-ancestor $production HEAD
$productionAncestryExit = $LASTEXITCODE
Assert-Cinematic 'authority: inspected production commit is an ancestor of candidate HEAD' ($productionAncestryExit -eq 0)
# ForgeCast decision-first copy tranche 2026-09-19 (owner-authorized): the
# forgecast summary / cardSummary / presentation.valueLine fields carry the
# approved new positioning. Neutralize exactly those copy fields on both
# sides; all release, artifact, signing and availability truth must still be
# byte-identical to the pinned production object.
foreach ($set in @(@($manifest.products), @($canonical.products))) {
  $fcP = @($set | Where-Object { $_.id -eq 'forgecast' }) | Select-Object -First 1
  if ($fcP) { $fcP.summary = $null; $fcP.cardSummary = $null; if ($fcP.presentation) { $fcP.presentation.valueLine = $null } }
  # VR1 visual refoundation (2026-09-21): proofshot.presentation.cardImage*
  # moved the catalog card to the current-brand proof-card capture.
  $psP = @($set | Where-Object { $_.id -eq 'proofshot' }) | Select-Object -First 1
  if ($psP -and $psP.presentation) {
    $psP.presentation.cardImage = $null; $psP.presentation.cardImageAlt = $null
    $psP.presentation.cardImageWidth = $null; $psP.presentation.cardImageHeight = $null
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
Assert-Cinematic 'authority: unchanged public product objects equal inspected production (authorized copy/H10 migrations only)' ((Json @($manifest.products | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') })) -ceq (Json @($canonical.products | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') })))
Assert-Cinematic 'authority: Lights Out v11.2.0 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'lights-out')[0].release.publicVersion -eq '11.2.0') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
Assert-Cinematic 'authority: Cache Vault v0.3.1 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.publicVersion -eq '0.3.1') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
Assert-Cinematic 'authority: seven registry identities equal production' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($product in $manifest.products) {
  $actual = @($registry.products | Where-Object id -eq $product.id)[0]
  $expectedRelease = [ordered]@{publicVersion=$product.release.publicVersion;candidateVersion=$product.release.candidateVersion;releaseStatus=$product.release.releaseStatus;publishedAt=$product.release.publishedAt;withdrawnVersion=$product.release.withdrawnVersion;withdrawalReason=$product.release.withdrawalReason}
  Assert-Cinematic "truth: $($product.id) registry release/status/candidate parity" ((Json $actual.release) -ceq (Json $expectedRelease))
  Assert-Cinematic "truth: $($product.id) registry artifact URLs/digests/signing/size parity" ((Json $actual.artifacts) -ceq (Json $product.artifacts))
}
# The fixture retains the original baseline hashes and explicitly accounts for excluded review assets.
foreach ($file in $custody.entries) {
  Assert-Cinematic "custody: entry bytes preserved for $($file.path)" (Test-H9Custody $Root $file)
}
$expectedIds = @('cache-vault','reality-gate','forgecast','lights-out','cleanroom','ghostlayer','proofshot')
foreach ($page in @(@{name='homepage';html=$homeHtml},@{name='software';html=$software})) {
  $ids = @([regex]::Matches($page.html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $missing = @([regex]::Matches($page.html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-Cinematic "$($page.name): unique document IDs" (@($ids | Sort-Object -Unique).Count -eq $ids.Count)
  Assert-Cinematic "$($page.name): accessible heading references resolve" ($missing.Count -eq 0)
  Assert-Cinematic "$($page.name): exactly one H1 and main landmark" (([regex]::Matches($page.html, '<h1\b')).Count -eq 1 -and ([regex]::Matches($page.html, '<main\b')).Count -eq 1)
  Assert-Cinematic "$($page.name): no unresolved template tokens" ($page.html -notmatch '\{\{[^}]+\}\}')
  Assert-Cinematic "$($page.name): owner-selected G favicon retained" ($page.html -match 'rel="icon"[^>]*/brand/PF_HEADER_MARK\.svg' -or $page.html -match 'href="/brand/PF_HEADER_MARK.svg"[^>]*rel="icon"')
  Assert-Cinematic "$($page.name): concept bitmap excluded" ($page.html -notmatch 'a_dark_cinematic_high_contrast_website_landing_p')
}
# CP-0189 restoration: the approved ledger page is the homepage authority.
Assert-Cinematic 'architecture: approved truthful hero headline' ($homeHtml -match 'Real software' -and $homeHtml -match 'leaves a record\.')
Assert-Cinematic 'identity: machined emblem replaces competing old studio bitmap' ($homeHtml -match 'PF_MARK_G_TI_460\.webp' -and $homeHtml -notmatch 'forged_pf_emblem_in_smoky_ruins')
# Approved composition order: hero -> record chain -> records section.
$cLedgerIdx = $homeHtml.IndexOf('class="ledger-hero')
$cChainIdx = $homeHtml.IndexOf('class="ledger-chain')
$cRecordsIdx = $homeHtml.IndexOf('class="home-records')
Assert-Cinematic 'architecture: hero, record chain and records section retain order' ($cLedgerIdx -ge 0 -and $cLedgerIdx -lt $cChainIdx -and $cChainIdx -lt $cRecordsIdx)
Assert-Cinematic 'architecture: catalog controls stay on software route' ($homeHtml -notmatch 'data-directory-finder|data-compare=|id="product-search"')
# CP-0189: product discovery moves to the approved directory; the homepage
# itself makes no per-product claims.
Assert-Cinematic 'composition: homepage makes no per-product claims' ($homeHtml -notmatch 'data-product="(?:cache-vault|reality-gate|forgecast|lights-out|cleanroom|ghostlayer|proofshot)"')
foreach ($id in @($expectedIds | Where-Object { $_ -ne 'proofshot' })) {
  Assert-Cinematic "discovery: catalog contains $id identity and route" ($software.Contains('data-directory-entry="' + $id + '"') -and $software.Contains('href="/' + $id + '/"'))
}
Assert-Cinematic 'truth: ProofShot history route preserved off the directory grid' ($software -match 'href="/proofshot/"' -and $software -notmatch 'data-directory-entry="proofshot"')
Assert-Cinematic 'truth: Reality Gate directory entry shows the withdrawn record without a download' (($software -match 'data-directory-entry="reality-gate"[^>]*data-availability="none"') -and ($software -match 'public v1\.1\.0 withdrawn') -and ($software -notmatch 'Download v1\.1\.0 Developer Pilot'))
Assert-Cinematic 'truth: Lights Out directory states public + companion releases' ($software -match 'v11\.2\.0' -and $software -match 'v11\.1\.1')
Assert-Cinematic 'truth: prohibited absolute GhostLayer and ProofShot claims absent' ($homeHtml -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified' -and $software -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified')
$cv = @($manifest.products | Where-Object id -eq 'cache-vault')[0]
# CP-0189: receipt inspection lives in the pf-receipt-dialog; raw digests and
# the source commit stay off the primary narrative.
Assert-Cinematic 'receipt: release-receipt dialog restored with product scope' ($homeHtml -match 'pf-receipt-dialog' -and $homeHtml -match 'data-receipt-products="[^"]*cache-vault')
Assert-Cinematic 'receipt: raw digest and source commit stay off the homepage narrative' ($homeHtml -notmatch [regex]::Escape($cv.artifacts[0].sha256) -and $homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29')
Assert-Cinematic 'receipt: ledger links to the release record' ($homeHtml -match 'href="/proof/"')
$plainHome = [regex]::Replace([regex]::Replace($homeHtml, '<[^>]+>', ' '), '\s+', ' ')
Assert-Cinematic 'proof: record-chain editorial meaning survives line breaks' ($plainHome -match 'A record, all the way through\.')
Assert-Cinematic 'ending: narrative close retains catalog and proof route' ($homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof/"')
$catalogIds = @([regex]::Matches($software, 'data-directory-entry="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Cinematic 'catalog: every canonical product appears in the directory' (@($expectedIds | Where-Object { $_ -ne 'proofshot' } | Where-Object { $_ -in $catalogIds }).Count -eq @($expectedIds | Where-Object { $_ -ne 'proofshot' }).Count)
Assert-Cinematic 'catalog: approved directory composition restored' ($software -match 'h9-software-hero' -and $software -match 'pf-directory-grid' -and $software -match 'Find your way in\.')
Assert-Cinematic 'catalog: route-only finder UI ships hidden for progressive enhancement' ($software -match 'data-directory-finder[^>]*hidden' -and $software -match 'name="query"' -and $software -match 'name="group"')
Assert-Cinematic 'catalog: internal systems have no public installer' (([regex]::Matches($software, 'data-availability="none"')).Count -ge 4)
Assert-Cinematic 'catalog: finder explains availability filtering' ($software -match 'Available downloads' -and $software -match 'No public installer')
Assert-Cinematic 'catalog: mechanical navigation uses content-addressed loading' ($software -match '/foundry-navigation\.js\?v=[a-f0-9]{12}')
Assert-Cinematic 'motion: CSS reduced-motion support remains' ((Read-Source 'h9-homepage.css') -match 'prefers-reduced-motion')
Assert-Cinematic 'motion: JS reduced-motion support remains' ((Read-Source 'h9-homepage.js') -match 'prefers-reduced-motion')
Write-Host "=== CURRENT H9 CINEMATIC RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
