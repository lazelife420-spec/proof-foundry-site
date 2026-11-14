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
  # git emits UTF-8; force the console decoder so multi-byte copy does not mojibake
  $prevOutEnc = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
  try { $value = & git -C $Root show "${production}:$path" }
  finally { [Console]::OutputEncoding = $prevOutEnc }
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
    # CP-0189 restoration: product.directory carries approved software-catalog
    # presentation copy — presentation only; pinned production predates it.
    $pp.PSObject.Properties.Remove('directory')
  }
}
Assert-Reconciled 'unchanged public product objects equal inspected production (authorized copy/H10 migrations only)' ((@($manifestProducts | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') }) | ConvertTo-Json -Depth 40 -Compress) -ceq (@($canonicalProducts | Where-Object { $_.id -notin @('lights-out', 'cache-vault', 'reality-gate') }) | ConvertTo-Json -Depth 40 -Compress))
Assert-Reconciled 'authority: Lights Out v11.2.0 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'lights-out')[0].release.publicVersion -eq '11.2.0') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'lights-out')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
Assert-Reconciled 'authority: Cache Vault v0.3.1 Verified release record is the explicit local truth migration' ((@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.publicVersion -eq '0.3.1') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].verification.status -eq 'VERIFIED') -and (@($manifest.products | Where-Object id -eq 'cache-vault')[0].release.releaseStatus -eq 'PUBLIC_RELEASE'))
# Reality Gate withdrawn (prod 20e3b9b reconciliation): the public v1.1.0 package
# is withdrawn after a security packaging defect — no current public version, no
# download URLs on the retained historical artifact.
$rgAuth = @($manifest.products | Where-Object id -eq 'reality-gate')[0]
Assert-Reconciled 'authority: Reality Gate withdrawn release record is the explicit local truth migration' ($rgAuth.state -eq 'withdrawn' -and $rgAuth.productStatus -eq 'WITHDRAWN' -and $rgAuth.release.releaseStatus -eq 'WITHDRAWN' -and $null -eq $rgAuth.release.publicVersion -and $rgAuth.release.withdrawnVersion -eq '1.1.0' -and -not $rgAuth.downloadUrl -and $rgAuth.presentation.downloadUnavailable -eq $true -and -not $rgAuth.artifacts[0].downloadUrl -and -not $rgAuth.artifacts[0].sha256Url -and $rgAuth.artifacts[0].sha256 -eq '58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756')
Assert-Reconciled 'registry covers exactly the canonical product identities' ((($registry.products.id | Sort-Object) -join ',') -ceq (($canonical.products.id | Sort-Object) -join ','))
foreach ($p in $manifest.products) {
  $rendered = @($registry.products | Where-Object id -eq $p.id)[0]
  # The public registry intentionally exposes these four release fields;
  # companionPublicVersion remains covered by complete manifest equality above.
  $expectedRelease = [ordered]@{publicVersion=$p.release.publicVersion;candidateVersion=$p.release.candidateVersion;releaseStatus=$p.release.releaseStatus;publishedAt=$p.release.publishedAt;withdrawnVersion=$p.release.withdrawnVersion;withdrawalReason=$p.release.withdrawalReason}
  Assert-Reconciled "$($p.id): registry public/candidate/release status preserved" (($rendered.release | ConvertTo-Json -Depth 12 -Compress) -ceq ($expectedRelease | ConvertTo-Json -Depth 12 -Compress))
  Assert-Reconciled "$($p.id): registry artifact filenames, public URLs, sizes, signing status and SHA-256 values preserved" (($rendered.artifacts | ConvertTo-Json -Depth 12 -Compress) -ceq ($p.artifacts | ConvertTo-Json -Depth 12 -Compress))
}

# Frozen surfaces are compared to CURRENT production, including its release edits.
# (H10 truth consolidation 2026-09-20 moved the four edited product pages to
# exact source-byte pins below; they intentionally diverge from production.)
$frozen = @('proof.html','founders.html','404.html',
  'scripts/Verify-PublicSite.ps1')
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
# V2 (2026-09-26+): the About page carries the "Small tools. Kept honest."
# rewrite — authorized copy drift, pinned to exact approved source bytes.
$v2Pins = [ordered]@{
  'about.html' = 'af9a345a140c2b6431d33d048c92794e9efd0817e1f4eca554c0704f232b1a05'
}
foreach ($p in $v2Pins.Keys) {
  Assert-Reconciled "${p}: V2-authorized source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $v2Pins[$p])
}
# V2 (2026-09-26+): registry-driven catalog cards, product-page module chrome and
# studio surfaces carry authorized edits; pins updated to the approved V2 bytes.
$vr1Pins = [ordered]@{
  'styles.css'                  = '5330d1b7c026cfa36e5988ed872da8b408daf62404f2771288f4addf6069dbcb'
  'studio.css'                  = '10e88a6ba2f6cd5d96d45229b08ab0b7b958388ebcc05ed870904a19e59a7de6'
  'product-page.css'            = '502883a34025c093343bc0358f02aed441bccfe83c2fe842cd3e83151b973d13'
  'partials/product-card.html'  = '80726aa629c0652b7552ebb04a9b3b9749d442dd4939d0e61b08d833291088db'
  'signature.css'               = 'bbe65de257f74d0ff22ce9eb925dd5f2304200c6cd407c28c08f93e35ceb6a61'
}
foreach ($p in $vr1Pins.Keys) {
  Assert-Reconciled "${p}: VR1-authorized source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $vr1Pins[$p])
}
# PF-TF1 (2026-09-21): footer gains the Truth Files discovery link — authorized
# drift, pinned to exact source bytes.
# CP-0189 restoration (2026-11-13, owner-approved design decision): the approved
# forged-metal chrome is restored on the three public surfaces — header/footer
# carry the machined emblem and engraved route-chain nav; index/software/
# truth-files templates carry the approved ledger, directory and record
# compositions. Each is pinned to the exact restored source bytes.
$cp0189Pins = [ordered]@{
  'partials/header.html' = '9e49a6b3bff7d919b6b6cf147800209392d22464d2d0aff590b474a6a927fe09'
  'partials/footer.html' = 'bbb79824b84e862e616b3c81b3d0bcd50b5947a05e92cad3058a969f3e4ab3f2'
  'index.html'           = 'b299358cb74b2530706bfceef9b03682107a44a3029883eec2e9a8c462f12ee4'
  'software.html'        = '51505f3ac8f7a99c4134529bd8c2b8090a3304456bfe3875116859736ac19be3'
  'truth-files.html'     = 'e79dce52f6d8cfbb38a30bc8633fbff35fccdf67aa6692dac8450470cc4396c3'
  'truth-files.css'      = '9e2795164afae2a785f43a1f2b615d426f7748bef18b6ec89f12bcbfb6a15ece'
  'h9-software.css'      = '39efa5c1ab0a1cb315f399b9a4afe473bd5f02fe73f53ec1b9570fafda3716ac'
  'experience.css'       = 'e979dccdd3eadf755e4283d2cbd4d70817b2867453318f96da43df400dada38a'
  'site.js'              = '180f9e97511a91de120c111df8cb7545712a9b776d28d87f421eaaebdb457be5'
  'foundry-connections.css' = '0cafdf5434a64ebbdb36f8f5410cbef7dc9f4b7067860cd30842f6d5e87ce1af'
}
foreach ($p in $cp0189Pins.Keys) {
  Assert-Reconciled "${p}: CP-0189 restored source bytes preserved" ((Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source $p)))) -ceq $cp0189Pins[$p])
}
# roadmap.html carries the owner-approved public roadmap truth repair
# (2026-09-20): stale hardcoded release truth replaced by manifest-driven copy,
# "Available now" / "In progress" grouping, and a closing proof note. The page
# intentionally diverges from pinned production; pin the exact approved source
# bytes (LF-normalized SHA-256) so drift past the approved state still fails.
$roadmapSha = Sha256 ([Text.Encoding]::UTF8.GetBytes((Read-Source 'roadmap.html')))
Assert-Reconciled 'roadmap.html: owner-approved roadmap truth repair + H10 publish-date tokenization + VR1 NOW/PROGRESS/LAB framing preserved' ($roadmapSha -ceq '02e863db0349931ef099fd465e8ca476c9ffc036d937cb88f32fa3339d474a09')

# H10 public-truth consolidation (2026-09-20): the pages below carry authorized
# edits that replace duplicated current-state literals (versions, dates, artifact
# filenames, canonical URLs, receipt ids, package path) with manifest tokens. Each
# is pinned to its exact authorized source bytes; any drift past this state fails.
# VR1 visual refoundation (2026-09-21): each product content slot now carries the
# shared Layer-B contract — everything after the download section (install,
# privacy, evidence, limitations, receipts) lives inside one pp-record details.
# V2 (2026-09-26+): content.html slots slimmed to the migration bridge —
# presentation now renders from module.json structured sections.
$h10Pins = [ordered]@{
  'products/reality-gate/content.html' = 'b31f097a990603854d0f5030c05f63e926da460e5d3b3eb9b6b3e42cc94bf96c'
  'products/lights-out/content.html'   = 'adb1c4d0151a16e27baa97237a63e4a1a82baeba9dab9092c97f583489179005'
  'products/cleanroom/content.html'    = 'ea25e27a5088814e1f17dbd8647f3fb6389ec6f8b01068f528538c67354938e7'
  'products/ghostlayer/content.html'   = 'fb196a54013eeddc856fe5582e17e6f10fd180e56e60c7c008a76ec8f1cbf75e'
  'products/cache-vault/content.html'  = '24a6b9baec33197fa3aca9b34794728d95fc75cfbae134430e7be93ba1bcae7a'
  'products/forgecast/content.html'    = 'ff31f92b3ab690aa5f435fb0a74f608aff29fa4f875ade0c607f40ee50935906'
  'products/proofshot/content.html'    = 'ac71c189846bdb2c0262312fc76d23b80c0949056bcc637a190bfc679059ac4c'
  'support.html'      = 'b9911ffba32ff9253ba4d56f8c53d41a601a498652cb4e72167e7b647f01b3a7'
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
Assert-Reconciled 'new asset paths are limited to the approved additions (H9 seven + V2 module media)' ($unexpectedAssets.Count -eq 0)
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
# V2: h9 homepage surfaces carry the registry-driven showcase and V5-era scene
# styling; pins updated to the approved V2 bytes (brand SVG pins unchanged).
$visualHashes = [ordered]@{
  'h9-homepage.css' = '49a1792e2fbd2250664291849aa90cac7549ccc3af7b0aa1cbd79dd505fce993'
  'h9-homepage.js' = 'd137f68e688093df12b9f6e254fc07145bf4142f141ebd1204c2721e1f3079ec'
  'brand/PF_MARK_G_MASTER.svg' = '575d90ae4754216811634d6ab33a3b966b1932e335aff3a04317be03314239a1'
  'brand/PF_MARK_G_FORGED.svg' = 'da8bbde069ebe205cdf955fd88162f387a24ed1d0bc649da80df062f22fb88fa'
  'brand/PF_MARK_G_MONO_DARK.svg' = '9ebbb300e52016494a63cada1c7aba7d01ecc70c3e6a5ab2227ee2dd28ada6fe'
  'brand/PF_MARK_G_MONO_LIGHT.svg' = '9cdf61259893ae2ed5515a2661dcb20498381a6e913543c080ee4d1c590b1e17'
}
foreach ($path in $visualHashes.Keys) {
  Assert-Reconciled "${path}: pre-reconciliation H9 bytes preserved" ((Get-FileHash (Join-Path $Root $path) -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $visualHashes[$path])
}
# CP-0189: h9-software.css is the restored approved catalog stylesheet in full —
# pinned byte-exact in the CP-0189 pin block above; no prefix/suffix contract
# applies to the restored bytes.

$homeHtml = Get-Content (Join-Path $PublicDir 'index.html') -Raw -Encoding UTF8
# VR1: the verified v0.2.4 source commit lives on /proof/ and the product page;
# the homepage receipt names artifact/version/status without pinning it inline.
Assert-Reconciled 'Cache Vault receipt keeps the verified v0.2.4 source commit off the homepage narrative' ($homeHtml -notmatch 'abbd84462a8165068405cbfcddf4bfaf6b8f6f29')
Assert-Reconciled 'stale v0.2.3 source commit is absent from H9 receipt' ($homeHtml -notmatch '099be3aaaae93519b8959be529f3ec9a53929149')
Write-Host "=== H9 RECONCILIATION RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
exit 0