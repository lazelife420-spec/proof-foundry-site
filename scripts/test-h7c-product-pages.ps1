# H7C — Existing product-page preservation & Products directory guard.
# No new product pages or product-page redesign is required by this suite.
[CmdletBinding()]
param(
  [string]$PublicDir = '',
  [string]$Root = ''
)
if (-not $PublicDir) { $PublicDir = Join-Path $PSScriptRoot '..\public' }
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== H7C PRODUCT-PAGE & CATALOG GUARD ===" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0
function Assert-Condition([bool]$condition, [string]$msg) {
  if ($condition) { Write-Host "PASS: $msg" -ForegroundColor Green; $script:passed++ }
  else { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failed++ }
}

$ppCssPath = Join-Path $PublicDir 'product-worlds.css'
$ppCss = if (Test-Path $ppCssPath) { [IO.File]::ReadAllText($ppCssPath) } else { '' }
# H9 moved the functional catalog to /software/; product-page guards stay here.
$catalogPath = Join-Path $PublicDir 'software/index.html'
$catalogHtml = if (Test-Path $catalogPath) { [IO.File]::ReadAllText($catalogPath) } else { '' }

# 1. Product-specific thematic identity in the active product-world owner.
$themes = @(
  '.product-lights-out',
  '.product-cleanroom',
  '.product-ghostlayer',
  '.product-forgecast'
)
foreach ($t in $themes) {
  Assert-Condition ($ppCss -match ([regex]::Escape($t) + '\s*\{')) "product-worlds.css defines theme selector: $t"
}
$historicalCss = [IO.File]::ReadAllText((Join-Path $PublicDir 'product-page.css'))
Assert-Condition ($historicalCss -match '\.product-proofshot\s*\{') 'product-page.css retains the historical ProofShot theme selector'

# 2. Canonical section hierarchy helper
function Test-Order([string]$html, [string[]]$needles, [string]$label) {
  $pos = @()
  foreach ($n in $needles) {
    $i = $html.IndexOf($n)
    if ($i -lt 0) { Assert-Condition $false "$label - missing '$n'"; return }
    $pos += $i
  }
  for ($k = 1; $k -lt $pos.Count; $k++) {
    if ($pos[$k] -le $pos[$k - 1]) { Assert-Condition $false "$label - '$($needles[$k])' out of canonical order"; return }
  }
  Assert-Condition $true "$label - canonical section order holds"
}

# 3. Test each H7C target product page
$h7cProducts = @(
  @{ Name = 'Lights Out'; Slug = 'lights-out'; PublicVer = 'v11.2.0'; CandidateVer = ''; Unreleased = $false },
  @{ Name = 'Cleanroom'; Slug = 'cleanroom'; PublicVer = 'v1.0.7'; CandidateVer = 'v1.0.10'; Unreleased = $false },
  @{ Name = 'GhostLayer'; Slug = 'ghostlayer'; PublicVer = 'v0.4.0'; CandidateVer = 'v0.4.0'; Unreleased = $false },
  @{ Name = 'ForgeCast'; Slug = 'forgecast'; PublicVer = 'v0.3.5'; CandidateVer = 'v0.3.5'; Unreleased = $false },
  @{ Name = 'ProofShot'; Slug = 'proofshot'; PublicVer = 'v2.0.0'; CandidateVer = ''; Unreleased = $false }
)

foreach ($p in $h7cProducts) {
  $name = $p.Name
  $slug = $p.Slug
  $file = Join-Path $PublicDir "$slug\index.html"
  if (-not (Test-Path $file)) { $file = Join-Path $PublicDir "$slug.html" }
  Assert-Condition (Test-Path $file) "$name - HTML page exists"
  if (-not (Test-Path $file)) { continue }

  $html = [IO.File]::ReadAllText($file)
  Assert-Condition ($html -match 'class="[^"]*pp-system[^"]*"') "$name - body carries pp-system"
  Assert-Condition ($html -match "product-$slug") "$name - body carries product-$slug identity class"
  Assert-Condition ($html -match 'href="/product-worlds\.css[?"]') "$name - generated page loads its product-world stylesheet"
  if ($slug -eq 'proofshot') {
    Assert-Condition ($html -match 'href="/product-page\.css[?"]') "$name - generated page loads its historical theme owner"
  }

  # Hierarchy check
  if ($slug -eq 'proofshot') {
    Test-Order $html @('id="overview"', 'id="features"', 'id="try-it"', 'pp-story', 'id="download"', 'id="identity"', 'id="proof"', 'id="privacy-data-flow"', 'pp-final-cta') "$name hierarchy"
  } elseif ($slug -eq 'ghostlayer') {
    Test-Order $html @('id="overview"', 'id="try-it"', 'layer-boundary', 'id="features"', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"') "$name hierarchy"
    $preview = [regex]::Match($html, '(?s)<section\b[^>]*id="try-it"[^>]*>.*?</section>').Value
    Assert-Condition ($preview -match 'layer-boundary' -and $preview -match 'temporary disk copy' -and $preview -match 'interrupted edits can leave recoverable copies') "$name - staging preview carries the disk-boundary warning before features"
  } elseif ($slug -eq 'forgecast') {
    Test-Order $html @('id="overview"', 'id="try-it"', 'pp-story', 'id="features"', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"') "$name hierarchy"
  } else {
    Test-Order $html @('id="overview"', 'id="features"', 'id="try-it"', 'pp-story', 'id="download"', 'id="onboarding"', 'id="proof"', 'id="privacy-data-flow"') "$name hierarchy"
  }

  # Warning visibility & single canonical verify presentation (for public releases with installer/APK)
  if (-not $p.Unreleased) {
    Assert-Condition ($html -match 'class="pp-warning"') "$name - critical warning visible outside disclosures"
  }

  # Current production keeps the identity/migration tier while shipping v2.0.0.
  if ($slug -eq 'proofshot') {
    Assert-Condition ($html -match 'HyperSnatch' -and $html -match 'Screenshots predate the rebrand') "$name - legacy engine imagery is explicitly disclosed"
    # Historical media is permitted only with explicit lineage/build limits;
    # it must not be passed off as a current ProofShot runtime capture.
    $hero = [regex]::Match($html, '(?s)hero-product-shot.*?</figure>').Value
    Assert-Condition ($hero -match 'src="/assets/proofshot/candidates-plan\.png"' -and $hero -match 'alt="Historical HyperSnatch v1\.6\.18 Candidates screen' -and $hero -match '<figcaption>Historical HyperSnatch v1\.6\.18 Candidates view' -and $hero -match 'No current ProofShot v2\.0\.0 runtime capture is claimed\.' -and $hero -notmatch 'workbench-home|workbench-proof-cards|web-hero\.png' -and $html -match 'historical product remains unfeatured while licensing and current-media findings are unresolved') "$name - historical hero states lineage and build, denies current-runtime qualification, and retains the unresolved hold"
    Assert-Condition ($html -match 'Download ProofShot v2\.0\.0') "$name - real public download CTA present"
    Assert-Condition ($html -match 'ProofShot-Setup-2\.0\.0\.exe' -and $html -notmatch 'Follow development|no public ProofShot release') "$name - current public installer supersedes development-only CTA"
  }

  # Technical evidence disclosure closed by default
  Assert-Condition ($html -match '<details class="proof-details">') "$name - technical verification disclosure present"
  Assert-Condition ($html -notmatch '<details class="proof-details"\s+open>') "$name - technical verification disclosure closed by default"
}

# Generic module commerce state is visible at each product-page acquisition surface.
$commerceModules = @(Get-ChildItem (Join-Path $Root 'products') -Directory | ForEach-Object {
  Get-Content (Join-Path $_.FullName 'module.json') -Raw | ConvertFrom-Json
} | Where-Object { $_.lifecycle -eq 'public-eligible' })
foreach ($module in $commerceModules) {
  $file = Join-Path $PublicDir (($module.route.Trim('/') + '\index.html'))
  if (-not (Test-Path $file)) { $file = Join-Path $PublicDir ($module.route.Trim('/') + '.html') }
  Assert-Condition (Test-Path $file) "$($module.id) - public product route exists for commerce assertion"
  if (-not (Test-Path $file)) { continue }
  $html = [IO.File]::ReadAllText($file)
  $statusSlug = ([string]$module.commerce.status).ToLowerInvariant().Replace('_','-')
  if ($module.commerce.status -eq 'FREE') {
    Assert-Condition ($html -match '<span class="product-commerce-label" data-commerce="free">Free download</span>' -and $html -match 'class="button button-primary"') "$($module.id) - FREE commerce state labels its public acquisition action"
  } elseif ($module.commerce.status -eq 'WITHDRAWN') {
    $decodedHtml = [System.Net.WebUtility]::HtmlDecode($html)
    Assert-Condition ($decodedHtml -match '<span class="product-commerce-label" data-commerce="withdrawn">UNAVAILABLE · WITHDRAWN</span>' -and $html -notmatch 'class="button button-primary" href="https?://') "$($module.id) - withdrawn state is explicit and has no public acquisition action"
  } elseif ($module.commerce.status -eq 'PAID' -and $module.commerce.price) {
    Assert-Condition ($html -match ('data-commerce="' + [regex]::Escape($statusSlug) + '">' + [regex]::Escape([string]$module.commerce.price))) "$($module.id) - explicit module price is rendered without inference"
  } else {
    Assert-Condition ($html -match ('data-commerce="' + [regex]::Escape($statusSlug) + '">')) "$($module.id) - current commerce state is rendered"
  }
}

# 4. Main-site Products directory and preserved historical navigation.
Assert-Condition ($catalogHtml -match 'class="pf-directory-grid" id="directory-results"') "Products directory contains its filter-results grid"
# Visual verdict (2026-11-06): a card's page is a button when every visible card in its group has a page, otherwise a
# plain link. The expected form comes from site-editorial.json, so neither form can stand in for the other.
$linkEditorial = @((Get-Content (Join-Path $Root 'site-editorial.json') -Raw | ConvertFrom-Json).entries | Where-Object { $_.visible })
foreach ($slug in @('cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'hardline-zero', 'crosspoint', 'reality-gate', 'proof-foundry-app')) {
  $entry = [regex]::Match($catalogHtml, '(?s)<article\b[^>]*data-directory-entry="' + [regex]::Escape($slug) + '"[^>]*>.*?</article>').Value
  # Owner decision (2026-11-05): an internal system with no public page declares that instead of a link.
  $ed = @($linkEditorial | Where-Object { $_.id -ceq $slug })[0]
  $linkClass = if (@($linkEditorial | Where-Object { $_.group -ceq $ed.group -and -not $_.destination }).Count -eq 0) { 'button button-secondary' } else { 'text-link directory-link' }
  $path = ($ed.destination -and $entry -match ('<a class="' + $linkClass + '" href="' + [regex]::Escape($ed.destination) + '">') -and ([regex]::Matches($entry, '<a\b')).Count -eq 1) -or (-not $ed.destination -and ($slug -in @('hardline-zero', 'crosspoint', 'proof-foundry-app') -and ($entry -match 'class="directory-availability directory-availability--none">No public installer<' -or $catalogHtml -match 'data-directory-group-note="Foundry systems">None of these has a public installer\.<') -and $entry -notmatch '<a\b'))
  Assert-Condition ($entry -match '<h3>[^<]+</h3>' -and $entry -match 'class="directory-purpose">[^<]+' -and $entry -match 'class="directory-state">[^<]+' -and $path) "$slug - directory entry has identity, purpose, availability and an exploration path (or declares none)"
}
# Owner decision (2026-11-05): the review-inventory history section is withheld; ProofShot's product history stays
# linked from the directory and its Truth File stays listed on /truth-files/.
$truthFilesIndex = Get-Content (Join-Path $PublicDir 'truth-files\index.html') -Raw -Encoding UTF8
Assert-Condition ($catalogHtml -notmatch 'data-directory-entry="proofshot"' -and $catalogHtml -match 'href="/proofshot/">Read ProofShot' -and $truthFilesIndex -match 'href="/truth-files/proofshot/"') "ProofShot is unfeatured but retains its product history path, and its Truth File stays listed"

# Equal directory geometry belongs to h9-software.css, not unloaded studio.css.
$directoryCss = [IO.File]::ReadAllText((Join-Path $PublicDir 'h9-software.css'))
Assert-Condition ($catalogHtml -match 'href="/h9-software\.css[?"]' -and $directoryCss -match '\.pf-directory-grid\s*\{[^}]*grid-template-columns:repeat\(3,minmax\(0,1fr\)\)') "active directory stylesheet gives entries equal three-column tracks"
Assert-Condition ($directoryCss -notmatch '\.directory-entry--forgecast\s*\{[^}]*(?:grid-column:\s*1\s*/\s*-1|rotate\(6deg\))') "active directory stylesheet does not privilege or tilt ForgeCast"

$color = if ($script:failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "=== H7C RESULT: $script:passed passed, $script:failed failed ===" -ForegroundColor $color
if ($script:failed -gt 0) { exit 1 }
