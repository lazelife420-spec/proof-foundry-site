# Current H9 binding composition and truth contract. Historical tests are intentionally untouched.
[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$production = 'e75466b8c483f60688a9f2f314fc0e63985eb859'
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
$canonical = ((& git -C $Root show "${production}:site-manifest.json") -join "`n") | ConvertFrom-Json
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
  }
}
Assert-Binding 'authority: complete product objects equal current production (authorized: forgecast copy fields + H10 truth fields only)' ((Json $manifest.products) -ceq (Json $canonical.products))
Assert-Binding 'authority: seven registry identities equal production' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($product in $canonical.products) {
  $actual = @($registry.products | Where-Object id -eq $product.id)[0]
  $expectedRelease = [ordered]@{publicVersion=$product.release.publicVersion;candidateVersion=$product.release.candidateVersion;releaseStatus=$product.release.releaseStatus;publishedAt=$product.release.publishedAt}
  Assert-Binding "truth: $($product.id) registry release/status/candidate parity" ((Json $actual.release) -ceq (Json $expectedRelease))
  Assert-Binding "truth: $($product.id) registry artifact URLs/digests/signing/size parity" ((Json $actual.artifacts) -ceq (Json $product.artifacts))
}
# The fixture retains the original baseline hashes and explicitly accounts for excluded review assets.
foreach ($file in $custody.entries) {
  Assert-Binding "custody: entry bytes preserved for $($file.path)" (Test-H9Custody $Root $file)
}
$expectedIds = @('cache-vault','reality-gate','forgecast','lights-out','cleanroom','ghostlayer','proofshot')
foreach ($page in @(@{name='homepage';html=$homeHtml},@{name='software';html=$software})) {
  $ids = @([regex]::Matches($page.html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $missing = @([regex]::Matches($page.html, 'aria-labelledby="([^"]+)"') | ForEach-Object { $_.Groups[1].Value -split '\s+' } | Where-Object { $_ -notin $ids })
  Assert-Binding "$($page.name): unique document IDs" (@($ids | Sort-Object -Unique).Count -eq $ids.Count)
  Assert-Binding "$($page.name): accessible heading references resolve" ($missing.Count -eq 0)
  Assert-Binding "$($page.name): exactly one H1 and main landmark" (([regex]::Matches($page.html, '<h1\b')).Count -eq 1 -and ([regex]::Matches($page.html, '<main\b')).Count -eq 1)
  Assert-Binding "$($page.name): no unresolved template tokens" ($page.html -notmatch '\{\{[^}]+\}\}')
  Assert-Binding "$($page.name): owner-selected G favicon retained" ($page.html -match 'href="/brand/PF_MARK_G_MASTER.svg" rel="icon"')
  Assert-Binding "$($page.name): concept bitmap excluded" ($page.html -notmatch 'a_dark_cinematic_high_contrast_website_landing_p')
}
Assert-Binding 'architecture: unchanged truthful hero headline' ($homeHtml -match 'Useful software\.' -and $homeHtml -match 'On your terms\.')
Assert-Binding 'identity: physical maker composition contains unchanged selected G' ($homeHtml -match 'h9-maker-plate' -and $homeHtml -match 'PF_MARK_G_FORGED.svg')
function Class-Position([string]$className) {
  $pattern = '<[a-z][a-z0-9]*\b[^>]*\bclass="[^"]*(?<![\w-])' + [regex]::Escape($className) + '(?![\w-])[^"]*"'
  $match = [regex]::Match($homeHtml,$pattern)
  if ($match.Success) { return $match.Index }; return -1
}
# VR1 order: hero → product discovery scenes → portfolio strip → proof invitation → close.
# Proof moved after the product journey; raw digests/commits no longer appear on-page.
$composition = @('h9-hero','h9-major-mosaic','h9-scene-cache-vault','h9-scene-forgecast','h9-scene-reality','h9-scene-ghostlayer','h9-secondary-strip','h9-proof','h9-final')
$previousPosition = -1
foreach ($scene in $composition) {
  $position = Class-Position $scene
  Assert-Binding "binding composition: $scene exists after the preceding required scene" ($position -gt $previousPosition -and $position -ge 0)
  $previousPosition = $position
}
Assert-Binding 'binding composition: hero product evidence remains authentic Cache Vault' ([regex]::Match($homeHtml,'(?s)<section\b[^>]*class="h9-hero".*?</section>').Value -match 'cv-quick-paste\.png')
Assert-Binding 'binding composition: four major product identities have distinct scenes' (@('h9-scene-cache-vault','h9-scene-forgecast','h9-scene-reality','h9-scene-ghostlayer' | Where-Object { (Class-Position $_) -lt 0 }).Count -eq 0)
$secondary = [regex]::Match($homeHtml,'(?s)<section\b[^>]*class="[^"]*\bh9-secondary-strip\b[^"]*".*?</section>').Value
$secondaryIds = @([regex]::Matches($secondary,'<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Binding 'binding composition: compact secondary strip contains Lights Out, Cleanroom and ProofShot only' ((($secondaryIds | Sort-Object) -join ',') -ceq 'cleanroom,lights-out,proofshot')
Assert-Binding 'architecture: catalog controls stay on software route' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"')
foreach ($id in $expectedIds) {
  Assert-Binding "discovery: homepage contains $id identity and route" ($homeHtml.Contains('data-product="' + $id + '"') -and $homeHtml.Contains('href="/' + $id + '/"'))
}
foreach ($asset in @('cv-quick-paste.png','v030-today.png','08-ci-run-complete.50deeeef7e10fbe8.png','gl-staged-files.png','cleanroom-activity-ledger.png','tonight-active-hero.png','web-hero.png')) {
  Assert-Binding "authentic media: homepage preserves source $asset" ($homeHtml.Contains($asset))
}
Assert-Binding 'truth: ProofShot public 2.0.0 with verified production brand artwork' ($homeHtml -match 'Public v2\.0\.0' -and $homeHtml -match 'proofshot/web-hero\.png' -and $homeHtml -notmatch 'workbench-home\.png' -and $homeHtml -notmatch 'workbench-proof-cards')
Assert-Binding 'truth: Cache Vault public 0.3.1 retained' ($homeHtml -match '(?i)Public v0\.3\.1')
$realityScene = [regex]::Match($homeHtml,'(?s)<section\b[^>]*data-product="reality-gate".*?</section>').Value
$weatherScene = [regex]::Match($homeHtml,'(?s)<section\b[^>]*data-product="forgecast".*?</section>').Value
$ghostScene = [regex]::Match($homeHtml,'(?s)<section\b[^>]*data-product="ghostlayer".*?</section>').Value
Assert-Binding 'truth: Reality Gate scene explicitly remains Developer Pilot with bounded security language' ($realityScene -match 'Developer Pilot v1\.1\.0' -and $realityScene -match 'Not an (OS|operating-system) security sandbox')
Assert-Binding 'truth: ForgeCast scene discloses network use, no added analytics and recorded weather' ($weatherScene -match '(?i)network|HTTPS' -and $weatherScene -match '(?i)(No|does not add) analytics tracking' -and $weatherScene -match '(?i)recorded weather|recorded state')
Assert-Binding 'truth: GhostLayer scene discloses explicit commit and temporary disk boundary' ($ghostScene -match '(?i)commit boundary' -and $ghostScene -match '(?i)temporary disk|temporary files|disk copies')
Assert-Binding 'truth: prohibited absolute GhostLayer and ProofShot claims absent' ($homeHtml -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified')
$cv = @($canonical.products | Where-Object id -eq 'cache-vault')[0]
$ledgerRows = @([regex]::Matches($homeHtml,'(?s)<div class="h9-ledger-row">.*?<p class="h9-artifact-name">.*?</p></div>') | ForEach-Object Value)
foreach ($productId in @('cache-vault','proofshot')) {
  $product = @($canonical.products | Where-Object id -eq $productId)[0]
  $row = @($ledgerRows | Where-Object { $_ -match ('href="/' + [regex]::Escape($productId) + '/"') })
  Assert-Binding "receipt: $productId row names product, public version/status, artifact, Windows and unsigned status" ($row.Count -eq 1 -and $row[0].Contains($product.name) -and $row[0].Contains('v' + $product.release.publicVersion) -and $row[0].Contains($product.artifacts[0].filename) -and $row[0] -match '>Public<' -and $row[0] -match 'Windows' -and $row[0] -match 'unsigned')
  Assert-Binding "receipt: $productId row keeps its canonical SHA-256 off the primary narrative" ($row.Count -eq 1 -and $row[0] -notmatch [regex]::Escape($product.artifacts[0].sha256))
}
Assert-Binding 'receipt: canonical 64-hex digest stays off the homepage narrative' ($homeHtml -notmatch [regex]::Escape($cv.artifacts[0].sha256))
Assert-Binding 'receipt: source commit stays off the homepage narrative' ($homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29')
Assert-Binding 'receipt: 40-char commit never labelled SHA-256' ($homeHtml -notmatch '<dt>SHA-256</dt>\s*<dd[^>]*>[a-f0-9]{40}</dd>')
$plainHome = [regex]::Replace([regex]::Replace($homeHtml, '<[^>]+>', ' '), '\s+', ' ')
Assert-Binding 'proof: Receipts over hype editorial meaning survives line breaks' ($plainHome -match 'Receipts over hype\.')
$ending = [regex]::Match($homeHtml,'(?s)<section class="h9-final".*?</section>').Value
Assert-Binding 'ending: studio statement and real G identity accompany direct catalog action' ($ending -match 'href="/software/"' -and $ending -match 'PF_MARK_G_FORGED.svg' -and $ending -match 'Same standard\.' -and $ending -match 'Different tools\.')
Assert-Binding 'discovery: Proof Standard, release records, support and studio routes remain accessible' ($homeHtml -match 'href="/proof-standard/"' -and $homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/support/"' -and $homeHtml -match 'href="/about/"')
$catalogIds = @([regex]::Matches($software, '<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Binding 'catalog: exactly seven distinct canonical products' ((($catalogIds | Sort-Object) -join ',') -ceq (($expectedIds | Sort-Object) -join ','))
Assert-Binding 'catalog: route-only search/filter UI ships hidden for progressive enhancement' ($software -match 'class="h9-product-finder"[^>]*hidden' -and $software -match 'id="product-search"')
Assert-Binding 'catalog: all seven comparison choices remain' (([regex]::Matches($software, 'data-compare=')).Count -eq 7)
Assert-Binding 'catalog: product-first heading and job/platform guidance are present' ($software -match '<h1>Find your tool\.</h1>' -and $software -match 'job or platform')
Assert-Binding 'catalog: comparison limit is explicitly explained' ($software -match '(?i)up to three tools to compare')
Assert-Binding 'catalog: current H9 module uses content-addressed loading' ($software -match '/h9-software\.js\?v=[a-f0-9]{12}')
Assert-Binding 'motion: CSS reduced-motion support remains' ((Read-Source 'h9-homepage.css') -match 'prefers-reduced-motion')
Assert-Binding 'motion: JS reduced-motion support remains' ((Read-Source 'h9-homepage.js') -match 'prefers-reduced-motion')
Write-Host "=== CURRENT H9 BINDING RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
