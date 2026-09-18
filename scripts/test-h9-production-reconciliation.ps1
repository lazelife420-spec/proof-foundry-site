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
Assert-Reconciled 'all seven canonical product objects are preserved exactly' (($manifest.products | ConvertTo-Json -Depth 40 -Compress) -ceq ($canonical.products | ConvertTo-Json -Depth 40 -Compress))
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
$frozen = @('about.html','proof-standard.html','proof.html','founders.html',
  'roadmap.html','reality-gate.html','lights-out.html',
  'cleanroom.html','ghostlayer.html','forgecast.html','404.html',
  'styles.css','studio.css','signature.css','experience.css','product-page.css',
  'site.js','scripts/Verify-PublicSite.ps1','partials/header.html','partials/footer.html','partials/product-card.html')
foreach ($path in $frozen) {
  $expected = Read-Production $path
  # Only the accepted homepage CTA expectation may differ from the pinned verifier.
  if ($path -ceq 'scripts/Verify-PublicSite.ps1') { $expected = $expected.Replace('"Explore the software"', '"Explore our software"') }
  Assert-Reconciled "${path}: current production source preserved" ((Read-Source $path) -ceq $expected)
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

# Only these precise stale statements are superseded on frozen shared surfaces.
$supportExpected = (Read-Production 'support.html').Replace('In development; no public release package currently published.', 'Public Windows v{{products.proofshot.publicVersion}} is available from Proof Foundry downloads. The installer is unsigned; verify its SHA-256 before running.')
Assert-Reconciled 'support source differs only by ProofShot public release correction' ((Read-Source 'support.html') -ceq $supportExpected)
$favicon = '<link href="/brand/proof-foundry-mark.svg" rel="icon" type="image/svg+xml"/>' + "`n"
$psExpected = (Read-Production 'proofshot.html').Replace('under its current HyperSnatch branding.', 'in an earlier HyperSnatch-branded preview.').Replace('</head>', $favicon + '</head>')
Assert-Reconciled 'ProofShot source differs only by historical-preview alt and existing-icon metadata' ((Read-Source 'proofshot.html') -ceq $psExpected)
$cvExpected = (Read-Production 'cache-vault.html').Replace('</head>', $favicon + '</head>')
Assert-Reconciled 'Cache Vault source differs only by existing-icon metadata' ((Read-Source 'cache-vault.html') -ceq $cvExpected)
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
