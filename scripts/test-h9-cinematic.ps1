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
$canonical = ((& git -C $Root show "${production}:site-manifest.json") -join "`n") | ConvertFrom-Json
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
  # H10 truth consolidation (2026-09-20): narrow manifest fields added as
  # canonical owners for facts pages previously hardcoded —
  # release.sourceCommit / release.companionCandidateVersion (cache-vault) and
  # packageId (forgecast). Production's manifest predates them; drop them on
  # both sides so all other truth still requires byte equality.
  foreach ($pp in $set) {
    if ($pp.release) {
      $pp.release.PSObject.Properties.Remove('companionCandidateVersion')
      $pp.release.PSObject.Properties.Remove('sourceCommit')
    }
    $pp.PSObject.Properties.Remove('packageId')
  }
}
Assert-Cinematic 'authority: complete product objects equal current production (authorized: forgecast copy fields + H10 truth fields only)' ((Json $manifest.products) -ceq (Json $canonical.products))
Assert-Cinematic 'authority: seven registry identities equal production' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($product in $canonical.products) {
  $actual = @($registry.products | Where-Object id -eq $product.id)[0]
  $expectedRelease = [ordered]@{publicVersion=$product.release.publicVersion;candidateVersion=$product.release.candidateVersion;releaseStatus=$product.release.releaseStatus;publishedAt=$product.release.publishedAt}
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
  Assert-Cinematic "$($page.name): owner-selected G favicon retained" ($page.html -match 'href="/brand/PF_MARK_G_MASTER.svg" rel="icon"')
  Assert-Cinematic "$($page.name): concept bitmap excluded" ($page.html -notmatch 'a_dark_cinematic_high_contrast_website_landing_p')
}
Assert-Cinematic 'architecture: unchanged truthful hero headline' ($homeHtml -match 'Useful software\.' -and $homeHtml -match 'On your terms\.')
Assert-Cinematic 'identity: selected G maker object replaces competing old studio bitmap' ($homeHtml -match 'h9-maker-plate' -and $homeHtml -match 'PF_MARK_G_FORGED.svg' -and $homeHtml -notmatch 'forged_pf_emblem_in_smoky_ruins')
Assert-Cinematic 'architecture: Cache Vault, ForgeCast, Reality Gate scenes retain order' ($homeHtml.IndexOf('h9-hero-product') -lt $homeHtml.IndexOf('h9-scene-forgecast') -and $homeHtml.IndexOf('h9-scene-forgecast') -lt $homeHtml.IndexOf('h9-scene-reality'))
Assert-Cinematic 'architecture: catalog controls stay on software route' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"')
foreach ($id in $expectedIds) {
  Assert-Cinematic "discovery: homepage contains $id identity and route" ($homeHtml.Contains('data-product="' + $id + '"') -and $homeHtml.Contains('href="/' + $id + '/"'))
}
foreach ($asset in @('cv-quick-paste.png','v030-today.png','08-ci-run-complete.50deeeef7e10fbe8.png','gl-staged-files.png','cleanroom-review.png','tonight-active-hero.png','workbench-home.png')) {
  Assert-Cinematic "authentic media: homepage preserves source $asset" ($homeHtml.Contains($asset))
}
Assert-Cinematic 'truth: ProofShot public 2.0.0 and historical imagery disclosure' ($homeHtml -match 'Public v2\.0\.0' -and $homeHtml -match 'HyperSnatch|earlier engine|earlier-engine')
Assert-Cinematic 'truth: Cache Vault public 0.2.4 retained' ($homeHtml -match '(?i)Public v0\.2\.4')
Assert-Cinematic 'truth: Reality Gate explicitly remains Developer Pilot' ($homeHtml -match 'Developer Pilot v1\.1\.0')
Assert-Cinematic 'truth: ForgeCast network boundary disclosed' ($homeHtml -match '(?i)network|HTTPS')
Assert-Cinematic 'truth: GhostLayer disk boundary disclosed' ($homeHtml -match '(?i)temporary disk|temporary files|disk copies')
Assert-Cinematic 'truth: prohibited absolute GhostLayer and ProofShot claims absent' ($homeHtml -notmatch '(?i)zero-trace|screen capture|court-certified|malware-free|security-certified')
$cv = @($canonical.products | Where-Object id -eq 'cache-vault')[0]
Assert-Cinematic 'receipt: canonical artifact filename rendered under Artifact' ($homeHtml -match ('<dt>Artifact</dt>\s*<dd[^>]*>' + [regex]::Escape($cv.artifacts[0].filename) + '</dd>'))
Assert-Cinematic 'receipt: canonical 64-hex digest rendered under SHA-256' ($homeHtml -match ('<dt>SHA-256</dt>\s*<dd[^>]*>' + [regex]::Escape($cv.artifacts[0].sha256) + '</dd>'))
Assert-Cinematic 'receipt: source commit separately labelled and correct' ($homeHtml -match '<dt>Source commit</dt>\s*<dd[^>]*>abbd84462a8165068405cbfcddf4bfaf6b8f6f29</dd>')
Assert-Cinematic 'receipt: 40-char commit never labelled SHA-256' ($homeHtml -notmatch '<dt>SHA-256</dt>\s*<dd[^>]*>[a-f0-9]{40}</dd>')
Assert-Cinematic 'receipt: platform, version and status are explicit fields' ($homeHtml -match '<dt>Platform</dt>' -and $homeHtml -match '<dt>Version</dt>' -and $homeHtml -match '<dt>Status</dt>')
$plainHome = [regex]::Replace([regex]::Replace($homeHtml, '<[^>]+>', ' '), '\s+', ' ')
Assert-Cinematic 'proof: Receipts over hype editorial meaning survives line breaks' ($plainHome -match 'Receipts over hype\.')
Assert-Cinematic 'ending: narrative close retains catalog and proof route' ([regex]::Match($homeHtml,'(?s)<section class="h9-final".*?</section>').Value -match 'href="/software/"' -and [regex]::Match($homeHtml,'(?s)<section class="h9-final".*?</section>').Value -match 'href="/proof-standard/"')
$catalogIds = @([regex]::Matches($software, '<article\b[^>]*data-product="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Cinematic 'catalog: exactly seven distinct canonical products' ((($catalogIds | Sort-Object) -join ',') -ceq (($expectedIds | Sort-Object) -join ','))
Assert-Cinematic 'catalog: route-only search/filter UI ships hidden for progressive enhancement' ($software -match 'class="h9-product-finder"[^>]*hidden' -and $software -match 'id="product-search"')
Assert-Cinematic 'catalog: all seven comparison choices remain' (([regex]::Matches($software, 'data-compare=')).Count -eq 7)
Assert-Cinematic 'catalog: product-first heading and job/platform guidance are present' ($software -match '<h1>Find your tool\.</h1>' -and $software -match 'job or platform')
Assert-Cinematic 'catalog: comparison limit is explicitly explained' ($software -match '(?i)up to three tools to compare')
Assert-Cinematic 'catalog: current H9 module uses content-addressed loading' ($software -match '/h9-software\.js\?v=[a-f0-9]{12}')
Assert-Cinematic 'motion: CSS reduced-motion support remains' ((Read-Source 'h9-homepage.css') -match 'prefers-reduced-motion')
Assert-Cinematic 'motion: JS reduced-motion support remains' ((Read-Source 'h9-homepage.js') -match 'prefers-reduced-motion')
Write-Host "=== CURRENT H9 CINEMATIC RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
