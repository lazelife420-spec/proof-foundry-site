# H9 preservation against the inspected current production, not its old base.
# Pinned expectations make coordinated manifest/output drift detectable.
[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$ErrorActionPreference = 'Stop'
$production = '34a291d78fa92f1a18cf76cef3ee56b391186e77'
$pass = 0; $fail = 0
function Assert-Reconciled([string]$name, [bool]$ok) {
  if ($ok) { $script:pass++; Write-Host "PASS: $name" }
  else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red }
}
function Read-Production([string]$path) {
  $value = & git -C $Root show "${production}:$path"
  if ($LASTEXITCODE -ne 0) { throw "Cannot read production $path" }
  return ($value -join "`n").TrimEnd("`r", "`n")
}
function Read-Source([string]$path) {
  return ([IO.File]::ReadAllText((Join-Path $Root $path))).Replace("`r`n", "`n").TrimEnd("`r", "`n")
}
function Sha256([byte[]]$bytes) {
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return [Convert]::ToHexString($algorithm.ComputeHash($bytes)).ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}

Write-Host "=== H9 CURRENT-PRODUCTION RECONCILIATION GUARD ==="
$canonical = (Read-Production 'site-manifest.json') | ConvertFrom-Json
$manifest = (Read-Source 'site-manifest.json') | ConvertFrom-Json
$registry = Get-Content (Join-Path $PublicDir 'proof/index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# ForgeCast decision-first copy tranche 2026-09-19 (owner-authorized): the
# forgecast summary / cardSummary / presentation.valueLine fields carry the
# approved new positioning. Neutralize exactly those copy fields on both
# sides; all release, artifact, signing and availability truth must still be
# byte-identical to the pinned production object.
$manifestProducts = @($manifest.products)
$canonicalProducts = @($canonical.products)
foreach ($set in @($manifestProducts, $canonicalProducts)) {
  $fcP = @($set | Where-Object { $_.id -eq 'forgecast' }) | Select-Object -First 1
  if ($fcP) { $fcP.summary = $null; $fcP.cardSummary = $null; if ($fcP.presentation) { $fcP.presentation.valueLine = $null } }
  # H10 truth consolidation (2026-09-20): three narrow manifest fields were added
  # as canonical owners for facts pages previously hardcoded — release.sourceCommit
  # and release.companionCandidateVersion (cache-vault), packageId (forgecast).
  # Production's manifest predates them; neutralize on both sides so all other
  # release/artifact truth still requires byte equality.
  foreach ($pp in $set) {
    if ($pp.release) {
      $pp.release.PSObject.Properties.Remove('companionCandidateVersion')
      $pp.release.PSObject.Properties.Remove('sourceCommit')
    }
    $pp.PSObject.Properties.Remove('packageId')
  }
}
Assert-Reconciled 'all seven canonical product objects are preserved exactly (authorized: forgecast copy fields + H10 truth fields only)' (($manifestProducts | ConvertTo-Json -Depth 40 -Compress) -ceq ($canonicalProducts | ConvertTo-Json -Depth 40 -Compress))
Assert-Reconciled 'registry covers exactly the canonical product identities' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($p in $canonical.products) {
  $rendered = @($registry.products | Where-Object id -eq $p.id)[0]
  # The public registry intentionally exposes these four release fields;
  # companionPublicVersion remains covered by complete manifest equality above.
  $expectedRelease = [ordered]@{publicVersion=$p.release.publicVersion;candidateVersion=$p.release.candidateVersion;releaseStatus=$p.release.releaseStatus;publishedAt=$p.release.publishedAt}
  Assert-Reconciled "$($p.id): registry public/candidate/release status preserved" (($rendered.release | ConvertTo-Json -Depth 12 -Compress) -ceq ($expectedRelease | ConvertTo-Json -Depth 12 -Compress))
  Assert-Reconciled "$($p.id): registry artifact filenames, public URLs, sizes, signing status and SHA-256 values preserved" (($rendered.artifacts | ConvertTo-Json -Depth 12 -Compress) -ceq ($p.artifacts | ConvertTo-Json -Depth 12 -Compress))
}

# Frozen surfaces are compared to CURRENT production, including its release edits.
# (H10 truth consolidation 2026-09-20 moved the four edited product pages to
# exact source-byte pins below; they intentionally diverge from production.)
$frozen = @('about.html','proof-standard.html','proof.html','founders.html','404.html',
  'styles.css','studio.css','signature.css','experience.css','product-page.css',
  'site.js','scripts/Verify-PublicSite.ps1','partials/header.html','partials/footer.html','partials/product-card.html')
foreach ($path in $frozen) {
  $expected = Read-Production $path
  # Only the accepted homepage CTA expectation may differ from the pinned verifier.
  if ($path -ceq 'scripts/Verify-PublicSite.ps1') { $expected = $expected.Replace('"Explore the software"', '"Explore our software"').Replace('"SkyFoundry"', '"(?<!prooffoundry\.)SkyFoundry"') }
  Assert-Reconciled "${path}: current production source preserved" ((Read-Source $path) -ceq $expected)
}
# roadmap.html carries the owner-approved public roadmap truth repair
# (2026-09-20): stale hardcoded release truth replaced by manifest-driven copy,
# "Available now" / "In progress" grouping, and a closing proof note. The page
# intentionally diverges from pinned production; pin the exact approved source
# bytes (LF-normalized SHA-256) so drift past the approved state still fails.
$roadmapSha = Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source 'roadmap.html')))
Assert-Reconciled 'roadmap.html: owner-approved roadmap truth repair + H10 publish-date tokenization preserved' ($roadmapSha -ceq '968da8807246b02235c9cff1f50a34e59b86bdc3482aa8faa8a40db2cdcd5608')

# H10 public-truth consolidation (2026-09-20): the pages below carry authorized
# edits that replace duplicated current-state literals (versions, dates, artifact
# filenames, canonical URLs, receipt ids, package path) with manifest tokens. Each
# is pinned to its exact authorized source bytes; any drift past this state fails.
$h10Pins = [ordered]@{
  'reality-gate.html' = '5be55df6d237cd451cceec0930f4b6d8891da3ff1ec333a2417405a4cdfc9e43'
  'lights-out.html'   = 'e38c8e7463ae1f546dcbaab3e6026de5ff4b487019a2d68a0513291068ab8132'
  'cleanroom.html'    = 'bc851044e14c7b5c7a684c6d0e36f2a71d51e3f839d371a2184c3a508ce89f0f'
  'ghostlayer.html'   = '25e8ec7f307db8cbfb89b1ff4c9e87a1c8f6a2b0399137740c2ce6707e6925e0'
  'cache-vault.html'  = '3a2dd0d461a93a29668ac0380b283fefc588ce9c6a0475e2043ebbae66b1219d'
  'forgecast.html'    = '038a6fec24e81edd85eea70d3e50d7d70faa71a860d32dec983bb2764aab43d3'
  'proofshot.html'    = '18cd26064f048e8d56a990f9220093053f7eb40b2452d4455a7ac7de5e6ed7fa'
  'support.html'      = '28d93bb322b0371fb3bf2fa845155a6235ab1e29b8252017ad9c55c0bf117bd8'
}
foreach ($p in $h10Pins.Keys) {
  Assert-Reconciled "${p}: H10 truth-consolidation source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $h10Pins[$p])
}
. (Join-Path $Root 'scripts/fixtures/h9/custody.ps1')
$assetCustody = Get-Content (Join-Path $Root 'scripts/fixtures/h9/canonical-assets.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# Check actual source bytes, not the original worktree's index when qualifying an isolated staged tree.
$assetChanges = @($assetCustody.canonical | Where-Object { -not (Test-H9Custody $Root $_) })
Assert-Reconciled 'all existing canonical image and brand assets remain unchanged' ($assetChanges.Count -eq 0)
$excludedReviewPaths = @($assetCustody.excludedReviewArtifacts.path)
$trackedExcludedAssets = @(& git -C $Root ls-files -- $excludedReviewPaths)
Assert-Reconciled 'excluded brand review artifacts are absent from repository custody' ($LASTEXITCODE -eq 0 -and $trackedExcludedAssets.Count -eq 0)
$knownAssetPaths = @($assetCustody.canonical.path) + @($assetCustody.additions.path) + @($assetCustody.excludedReviewArtifacts.path)
$unexpectedAssets = @(foreach ($directory in @('assets','brand')) {
  Get-ChildItem -LiteralPath (Join-Path $Root $directory) -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/')
    if ($relative -cnotin $knownAssetPaths) { $relative }
  }
})
Assert-Reconciled 'new asset paths are limited to the seven approved H9 additions' ($unexpectedAssets.Count -eq 0)
foreach ($asset in $assetCustody.additions) {
  Assert-Reconciled "approved addition: $($asset.path) retains accepted owner-package bytes" (Test-H9Custody $Root $asset)
}

# The pre-H10 transform chains for support.html, forgecast.html, proofshot.html
# and cache-vault.html are superseded by the H10 exact-byte pins declared above:
# those pages now carry manifest tokens instead of duplicated literals, so their
# authorized state is the pinned source bytes rather than production + deltas.
$experienceExpected = (Read-Production 'experience.js').Replace('Capture workbench · in development', 'Structural capture & proof bundles').Replace('A capture workbench, taking shape.', 'Capture context. Keep a verifiable record.').Replace('under its current HyperSnatch branding.', 'in an earlier HyperSnatch-branded preview.')
Assert-Reconciled 'experience logic preserved; only stale ProofShot descriptive strings change' ((Read-Source 'experience.js') -ceq $experienceExpected)

# Exact pre-reconciliation candidate bytes: the current G-mark design is the
# authority, not the older D/E/F owner-review ZIP.
$visualHashes = [ordered]@{
  'h9-homepage.css' = '457bc41c1f736312ac64cbf5f93bf9ee1b4b6d1cfe974aed265b54fd54613523'
  'h9-homepage.js' = 'c897bc8c720ba056965b3a93f5828232cbc0c3d30508a9a9b13c3c6cf59254cc'
  'brand/PF_MARK_G_MASTER.svg' = '575d90ae4754216811634d6ab33a3b966b1932e335aff3a04317be03314239a1'
  'brand/PF_MARK_G_FORGED.svg' = 'da8bbde069ebe205cdf955fd88162f387a24ed1d0bc649da80df062f22fb88fa'
  'brand/PF_MARK_G_MONO_DARK.svg' = '9ebbb300e52016494a63cada1c7aba7d01ecc70c3e6a5ab2227ee2dd28ada6fe'
  'brand/PF_MARK_G_MONO_LIGHT.svg' = '9cdf61259893ae2ed5515a2661dcb20498381a6e913543c080ee4d1c590b1e17'
}
foreach ($path in $visualHashes.Keys) {
  Assert-Reconciled "${path}: pre-reconciliation H9 bytes preserved" ((Get-FileHash (Join-Path $Root $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $visualHashes[$path])
}
$catalogCss = [IO.File]::ReadAllBytes((Join-Path $Root 'h9-software.css'))
$prefixPreserved = $catalogCss.Length -ge 5396 -and (Sha256 ([byte[]]$catalogCss[0..5395])) -ceq '94d7d436ec12dca9f60a25d1bde1233ba0f5edcec304c8ad11b1f5f75f845611'
Assert-Reconciled 'H9 software CSS preserves the complete pre-reconciliation design prefix' $prefixPreserved
$suffix = if ($catalogCss.Length -gt 5396) { [Text.Encoding]::UTF8.GetString($catalogCss, 5396, $catalogCss.Length - 5396).Trim() } else { '' }
Assert-Reconciled 'software CSS append only repairs HTML hidden behavior for filters' ($suffix.Replace("`r`n", "`n") -ceq "/* Filtering and progressive enhancement must honor the HTML hidden state. */`n.software-catalog-page [hidden]{display:none!important}")

$homeHtml = Get-Content (Join-Path $PublicDir 'index.html') -Raw -Encoding UTF8
Assert-Reconciled 'Cache Vault receipt preserves the verified v0.2.4 source commit' ($homeHtml -match '<dt>Source commit</dt><dd>abbd84462a8165068405cbfcddf4bfaf6b8f6f29</dd>')
Assert-Reconciled 'stale v0.2.3 source commit is absent from H9 receipt' ($homeHtml -notmatch '099be3aaaae93519b8959be529f3ec9a53929149')
Write-Host "=== H9 RECONCILIATION RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
exit 0