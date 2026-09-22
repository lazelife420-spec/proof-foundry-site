# H5 STRUCTURED-DATA / JSON-LD TRUTH — bounded assertions (F9 adjudication)
#
# Coverage contract:
#   F9  No page may emit a schema.org Offer unless canonical manifest truth
#       authorizes a currently downloadable artifact for the bound product:
#       publicVersion non-empty AND >=1 artifact with downloadUrl AND
#       presentation.downloadUnavailable not set. An Offer on a page whose own
#       canonical truth is "no public release / downloads on hold" asserts
#       availability that does not exist (the F9 contradiction).
#   No aggregateRating / review claims anywhere: no first-party rating corpus
#   exists, so such markup could only be fabricated.
#   JSON-LD footprint is exactly {lights-out, proofshot}: structured data must
#   not silently spread without a deliberate, adjudicated tranche.
#   Identity fields that remain (name/OS/category/description/author) must be
#   present and non-empty — the correction removed the false claim, not the
#   truthful identity metadata.
#
# The rule is derived from site-manifest.json at test time; it cannot drift
# from canonical release truth. Runs against built public/ output. No network.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$publicDir = Join-Path $root 'public'
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$script:passed = 0
$script:failed = 0

function Assert-Condition([bool]$cond, [string]$label) {
  if ($cond) { $script:passed++; Write-Host "  PASS: $label" }
  else { $script:failed++; Write-Host "  FAIL: $label" -ForegroundColor Red }
}

function Read-Page([string]$route) {
  $p = if ($route -eq '') { Join-Path $publicDir 'index.html' } else { Join-Path $publicDir "$route\index.html" }
  return Get-Content $p -Raw -Encoding UTF8
}

function Get-JsonLdBlocks([string]$html) {
  return @([regex]::Matches($html, '(?s)<script type="application/ld\+json">(.*?)</script>') | ForEach-Object { $_.Groups[1].Value })
}

function Test-OfferAuthorized($product) {
  # Canonical rule: Offer requires public release + downloadable artifact + not flagged unavailable
  $hasPublic = -not [string]::IsNullOrWhiteSpace("$($product.release.publicVersion)")
  $downloadable = @($product.artifacts | Where-Object { -not [string]::IsNullOrWhiteSpace($_.downloadUrl) }).Count -gt 0
  $available = -not [bool]$product.presentation.downloadUnavailable
  return ($hasPublic -and $downloadable -and $available)
}

Write-Host "=== H5 JSON-LD TRUTH ASSERTIONS ==="

$allRoutes = @('', 'software', 'reality-gate', 'forgecast', 'lights-out', 'cache-vault', 'cleanroom', 'ghostlayer', 'proofshot', 'founders', 'proof', 'roadmap', 'support', 'about', 'proof-standard')
$jsonldRoutes = @()

foreach ($route in $allRoutes) {
  $label = if ($route -eq '') { '/' } else { "/$route/" }
  $html = Read-Page $route
  $blocks = Get-JsonLdBlocks $html
  if ($blocks.Count -gt 0) { $jsonldRoutes += $route }
  # Every JSON-LD block on every page must be valid JSON
  $allValid = $true
  foreach ($b in $blocks) { try { $null = $b | ConvertFrom-Json } catch { $allValid = $false } }
  Assert-Condition $allValid "[$label] all JSON-LD blocks parse as valid JSON"
  # No fabricated reputation claims anywhere
  Assert-Condition ($html -notmatch 'aggregateRating') "[$label] no aggregateRating claim (no first-party rating corpus exists)"
  Assert-Condition ($html -notmatch '"@type"\s*:\s*"Review"') "[$label] no Review claim (no first-party review corpus exists)"
}

# Footprint guard: structured data exists only where adjudicated
Assert-Condition ((($jsonldRoutes | Sort-Object) -join ',') -eq 'lights-out,proofshot') "F9: JSON-LD footprint is exactly {lights-out, proofshot} (no silent spread)"

# The F9 rule, applied to every product page from canonical manifest truth
foreach ($p in $manifest.products) {
  $route = $p.route -replace '^/', '' -replace '/$', ''
  $html = Read-Page $route
  $blocks = Get-JsonLdBlocks $html
  $emitsOffer = [bool]($blocks | Where-Object { $_ -match '"@type"\s*:\s*"Offer"' -or $_ -match '"offers"' })
  if ($emitsOffer) {
    Assert-Condition (Test-OfferAuthorized $p) "F9: $($p.id) emits an Offer and canonical truth authorizes it (public release + downloadable artifact)"
  } else {
    Assert-Condition (-not $emitsOffer) "F9: $($p.id) makes no schema.org Offer claim"
  }
}

# Post-correction specifics: identity preserved, false claim removed
$lo = Read-Page 'lights-out'
$loBlock = @(Get-JsonLdBlocks $lo)[0]
$loJson = $loBlock | ConvertFrom-Json
Assert-Condition ($loBlock -notmatch '"offers"') "F9: Lights Out JSON-LD no longer emits offers"
Assert-Condition ($loJson.name -eq 'Lights Out') "F9: Lights Out JSON-LD identity (name) preserved"
Assert-Condition ($loJson.author.name -eq 'The Proof Foundry') "F9: Lights Out JSON-LD author preserved"
Assert-Condition (-not [string]::IsNullOrWhiteSpace($loJson.description)) "F9: Lights Out JSON-LD description preserved"
Assert-Condition ($lo -match 'downloads are currently on hold|currently unavailable|on hold') "F9: Lights Out visible copy still states hold/unavailability truth"

$ps = Read-Page 'proofshot'
$psBlock = @(Get-JsonLdBlocks $ps)[0]
$psJson = $psBlock | ConvertFrom-Json
Assert-Condition ($psBlock -notmatch '"offers"') "F9: ProofShot JSON-LD no longer emits offers"
Assert-Condition ($psJson.name -eq 'ProofShot') "F9: ProofShot JSON-LD identity (name) preserved"
Assert-Condition ($psJson.author.name -eq 'The Proof Foundry') "F9: ProofShot JSON-LD author preserved"
Assert-Condition (-not [string]::IsNullOrWhiteSpace($psJson.description)) "F9: ProofShot JSON-LD description preserved"
Assert-Condition ($ps -match 'Download ProofShot v2\.0\.0' -and $ps -notmatch 'No public ProofShot release') "F9: ProofShot visible copy states its public v2.0.0 release"
Assert-Condition ($ps -match 'href="#release-status"' -and $ps -match 'id="release-status"' -and $ps -notmatch 'no changelog yet') "H3 guard: ProofShot release-details path replaces the no-release statement"

# Meta-layer consistency: meta descriptions must not contradict structured data
Assert-Condition (@(Get-JsonLdBlocks $ps)[0] -notmatch 'available|in stock|InStock') "F9: ProofShot JSON-LD carries no availability language"
Assert-Condition (@(Get-JsonLdBlocks $lo)[0] -notmatch 'InStock') "F9: Lights Out JSON-LD carries no availability language"

# H4/H3 preservation on shared surfaces
$rg = Read-Page 'reality-gate'
Assert-Condition ($rg -match 'property="og:title"') "H4 guard: Reality Gate OG block intact"
Assert-Condition ($rg -match 'name="robots"') "H4 guard: Reality Gate robots meta intact"
Assert-Condition ($lo -match 'Install, update, uninstall &amp; leftover data') "H3 guard: Lights Out onboarding block intact"
Assert-Condition ($lo -match 'href="#release-note"') "H3 guard: Lights Out what-changed link intact"

# H9 may change navigation while all current production product truth is frozen.
# A git-clean check would reject every authorized uncommitted review candidate.
# Authorized drift (site copy tranche 2026-09-19, owner-authorized ForgeCast
# decision-first repositioning): forgecast summary / cardSummary /
# presentation.valueLine carry approved copy. Those three copy fields are
# neutralized on both sides before comparison; every other field — release,
# sha256, artifacts, downloads — must still match the pinned baseline exactly.
$canonical = (git -C $root show 34a291d78fa92f1a18cf76cef3ee56b391186e77:site-manifest.json) -join "`n" | ConvertFrom-Json
$workProducts = @($manifest.products)
$baseProducts = @($canonical.products)
foreach ($set in @($workProducts, $baseProducts)) {
  $fc = @($set | Where-Object { $_.id -eq 'forgecast' }) | Select-Object -First 1
  if ($fc) { $fc.summary = $null; $fc.cardSummary = $null; if ($fc.presentation) { $fc.presentation.valueLine = $null } }
  # VR1 visual refoundation (2026-09-21): proofshot.presentation.cardImage*
  # fields moved the catalog card to the current-brand proof-card capture.
  $ps = @($set | Where-Object { $_.id -eq 'proofshot' }) | Select-Object -First 1
  if ($ps -and $ps.presentation) {
    $ps.presentation.cardImage = $null; $ps.presentation.cardImageAlt = $null
    $ps.presentation.cardImageWidth = $null; $ps.presentation.cardImageHeight = $null
  }
  # H10 truth consolidation (2026-09-20): narrow manifest fields added as
  # canonical owners for facts pages previously hardcoded —
  # release.sourceCommit / release.companionCandidateVersion (cache-vault) and
  # packageId (forgecast). Pinned production predates them; drop on both sides.
  foreach ($pp in $set) {
    if ($pp.release) {
      $pp.release.PSObject.Properties.Remove('companionCandidateVersion')
      $pp.release.PSObject.Properties.Remove('sourceCommit')
      $pp.release.PSObject.Properties.Remove('companionPublicVersion')
    }
    $pp.PSObject.Properties.Remove('packageId')
  }
}
Assert-Condition (($workProducts | ConvertTo-Json -Depth 30 -Compress) -ceq ($baseProducts | ConvertTo-Json -Depth 30 -Compress)) "truth: every product equals current production, except authorized ForgeCast copy fields (summary, cardSummary, presentation.valueLine) and H10 truth fields"

Write-Host ""
Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
