# H9 preservation against the inspected current production, not its old base.
# Pinned expectations make coordinated manifest/output drift detectable.
[CmdletBinding()]
param([string]$PublicDir = '', [string]$Root = '')
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot/..").Path }
if (-not $PublicDir) { $PublicDir = Join-Path $Root 'public' }
$ErrorActionPreference = 'Stop'
$production = 'e75466b8c483f60688a9f2f314fc0e63985eb859'
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
  # VR1 visual refoundation (2026-09-21): ProofShot's catalog card image moved
  # from the pre-rebrand HyperSnatch workbench capture to the current-brand
  # proof-card capture. Neutralize exactly those presentation fields on both
  # sides; all release, artifact and availability truth still compares exactly.
  $psP = @($set | Where-Object { $_.id -eq 'proofshot' }) | Select-Object -First 1
  if ($psP -and $psP.presentation) {
    $psP.presentation.cardImage = $null
    $psP.presentation.cardImageAlt = $null
    $psP.presentation.cardImageWidth = $null
    $psP.presentation.cardImageHeight = $null
  }
  # H10 truth consolidation (2026-09-20): three narrow manifest fields were added
  # as canonical owners for facts pages previously hardcoded — release.sourceCommit
  # and release.companionCandidateVersion (cache-vault), packageId (forgecast).
  # Production's manifest predates them; neutralize on both sides so all other
  # release/artifact truth still requires byte equality.
  foreach ($pp in $set) {
    if ($pp.release) {
      $pp.release.PSObject.Properties.Remove('companionCandidateVersion')
      $pp.release.PSObject.Properties.Remove('sourceCommit')
      $pp.release.PSObject.Properties.Remove('companionPublicVersion')
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
$frozen = @('about.html','proof.html','founders.html','404.html',
  'signature.css','experience.css',
  'site.js','scripts/Verify-PublicSite.ps1','partials/header.html')
foreach ($path in $frozen) {
  $expected = Read-Production $path
  # Only the accepted homepage CTA expectation may differ from the pinned verifier.
  if ($path -ceq 'scripts/Verify-PublicSite.ps1') { $expected = $expected.Replace('"Explore the software"', '"Explore our software"').Replace('"SkyFoundry"', '"(?<!prooffoundry\.)SkyFoundry"') }
  Assert-Reconciled "${path}: current production source preserved" ((Read-Source $path) -ceq $expected)
}

# VR1 visual refoundation (2026-09-21): shared shell and presentation surfaces
# carry authorized edits — nav-toggle focus state, card meta row, Layer-B record
# styling, proof-standard brief block. They intentionally diverge from pinned
# production; pin the exact approved source bytes so drift past this state fails.
$vr1Pins = [ordered]@{
  'styles.css'                  = '5330d1b7c026cfa36e5988ed872da8b408daf62404f2771288f4addf6069dbcb'
  'studio.css'                  = '1aa4f5b64f63f5ebfb67da45ecd11d07d39a33fb82ef87c208cc7a4c6746982e'
  'product-page.css'            = '66aee224f6b5429c15d15cfe1efebd0f3dd2d952e72631dc8ab2a4444dd87095'
  'partials/product-card.html'  = 'f9ba0c456d1888628f9a888bd29243171967a2601f3c328e4a84d00e1fe15439'
}
foreach ($p in $vr1Pins.Keys) {
  Assert-Reconciled "${p}: VR1-authorized source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $vr1Pins[$p])
}
# PF-TF1 (2026-09-21): footer gains the Truth Files discovery link — authorized
# drift, pinned to exact source bytes.
$tf1Pins = [ordered]@{
  'partials/footer.html' = 'be908af8cc92ad2afe7ad6ee90e860c96b77e5e6784d7c2725264c7fdbe6a47b'
}
foreach ($p in $tf1Pins.Keys) {
  Assert-Reconciled "${p}: TF1-authorized source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $tf1Pins[$p])
}
# roadmap.html carries the owner-approved public roadmap truth repair
# (2026-09-20): stale hardcoded release truth replaced by manifest-driven copy,
# "Available now" / "In progress" grouping, and a closing proof note. The page
# intentionally diverges from pinned production; pin the exact approved source
# bytes (LF-normalized SHA-256) so drift past the approved state still fails.
$roadmapSha = Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source 'roadmap.html')))
Assert-Reconciled 'roadmap.html: owner-approved roadmap truth repair + H10 publish-date tokenization + VR1 NOW/PROGRESS/LAB framing preserved' ($roadmapSha -ceq 'c759439cb4088bf499f6eb104daf1c8b504c616cc962579f143c2796b9da8c81')

# H10 public-truth consolidation (2026-09-20): the pages below carry authorized
# edits that replace duplicated current-state literals (versions, dates, artifact
# filenames, canonical URLs, receipt ids, package path) with manifest tokens. Each
# is pinned to its exact authorized source bytes; any drift past this state fails.
# VR1 visual refoundation (2026-09-21): each product content slot now carries the
# shared Layer-B contract — everything after the download section (install,
# privacy, evidence, limitations, receipts) lives inside one pp-record details.
$h10Pins = [ordered]@{
  'products/reality-gate/content.html' = '714b6d77d84450530866529f2708b962073d33cb6abe9dd4f258811449bae107'
  'products/lights-out/content.html'   = '5277b088e6d086eb1edb8c528add3b2005a8416eeff28be0ae76633e7045a257'
  'products/cleanroom/content.html'    = 'e9e1e8efeb0da85c74d3edaab2e7b9456d9f4e79e04f68d193f64a85af843df9'
  'products/ghostlayer/content.html'   = 'ad93b63396d8a91f9f9cf5993b6b7bc59b67e796c26c94ac6e94cfc6fb4fa1cf'
  'products/cache-vault/content.html'  = 'f7bf72458a0911a1627291d19cbe148272ca166961d635db1df695818c601dd7'
  'products/forgecast/content.html'    = '8cb15b966760354e6bc03d65ede8984a895ff95d24cae61b8405ac76a7b3c873'
  'products/proofshot/content.html'    = '43104ca30793a63990e658858b1775518b76735d7af88599fe98e7de69409674'
  'support.html'      = '28d93bb322b0371fb3bf2fa845155a6235ab1e29b8252017ad9c55c0bf117bd8'
}
# H13 modular renderer (2026-09-20): the seven product pages migrated from
# per-product {id}.html templates to products/<id>/{module.json,content.html}.
# The authorized source bytes are now the extracted content slots — any drift
# past this state fails.
foreach ($p in $h10Pins.Keys) {
  Assert-Reconciled "${p}: authorized product-page source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $h10Pins[$p])
}
# H11 public-truth surface (2026-09-20): proof-standard.html carries one
# authorized edit — a Public Truth discovery card in the related-routes grid.
# It intentionally diverges from pinned production; pin the exact approved
# source bytes so drift past the approved state still fails.
# VR1: proof-standard.html additionally carries the concise "standard in brief"
# lead ahead of the doctrine; the H11 discovery card is unchanged.
$h11Pins = [ordered]@{
  'proof-standard.html' = 'f6639753bcd7d826e6b99b6f24bf7980f8ca5cc9b969f8739df66d663d26a6a0'
}
foreach ($p in $h11Pins.Keys) {
  Assert-Reconciled "${p}: H11 public-truth discovery link preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $h11Pins[$p])
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
  'h9-homepage.css' = '7410cb1b65ea5616766e45170ead75104cd5f77f4c2b141610a4b647d4d6ef96'
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
# VR1-R1: the bespoke pseudo-element brand lockup was removed from inside the
# prefix zone (owner visual review fix 1 — one shared header identity). The pin
# is updated to the authorized post-R1 prefix bytes.
$prefixPreserved = $catalogCss.Length -ge 5396 -and (Sha256 ([byte[]]$catalogCss[0..5395])) -ceq 'd5b5512fd1afbe772e9598b20688237808def02bf51c783d54deeb3a59410044'
Assert-Reconciled 'H9 software CSS preserves the authorized VR1-R1 design prefix' $prefixPreserved
$suffix = if ($catalogCss.Length -gt 5396) { [Text.Encoding]::UTF8.GetString($catalogCss, 5396, $catalogCss.Length - 5396).Trim() } else { '' }
# VR1: the card meta-row styles are appended at EOF; the pinned tail contract is
# "appends only" — the [hidden] repair must remain and the file must end with the
# VR1 block. (The design prefix pin above predates later sanctioned additions.)
Assert-Reconciled 'software CSS appends only: [hidden] repair present, VR1 card meta row is the tail' ($suffix.Contains('.software-catalog-page [hidden]{display:none!important}') -and $suffix.TrimEnd().EndsWith('.software-catalog-page .h9-card-meta{margin:0 0 12px}'))

$homeHtml = Get-Content (Join-Path $PublicDir 'index.html') -Raw -Encoding UTF8
# VR1: the verified v0.3.1 source commit lives on /proof/ and the product page;
# the homepage receipt names artifact/version/status without pinning it inline.
Assert-Reconciled 'Cache Vault receipt keeps the verified v0.3.1 source commit off the homepage narrative' ($homeHtml -notmatch 'eddbae7a2763d1994dae1e43e744ca8225d93eb3')
Assert-Reconciled 'stale v0.2.3 source commit is absent from H9 receipt' ($homeHtml -notmatch '099be3aaaae93519b8959be529f3ec9a53929149')
Write-Host "=== H9 RECONCILIATION RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
exit 0