# scripts/build-site.ps1 — Manifest-driven static site generator for The Proof Foundry.
#
# Source of truth: site-manifest.json (product identity / status / release facts)
# Shared chrome:    partials/*.html
# Page content:     root *.html files (templates with markers + tokens)
# Output:           public/  (GENERATED — never hand-edit)
#
# Usage:  ./scripts/build-site.ps1
#         ./scripts/build-site.ps1 -ValidateOnly
#
# Markers understood in templates:
#   <!-- @page <id> -->            declares page identity (sets nav active state)
#   <!-- @product <slug> -->       binds this product page to a manifest entry
#   <!-- @include header -->       injects partials/header.html (nav resolved)
#   <!-- @include footer -->       injects partials/footer.html (products resolved)
#   <!-- @products -->             emits one product-card per visible product
#   {{product.<field>}}            bound product fields + computed blocks
#   {{brand}} {{tagline}} {{positioning}}
#
# Computed product tokens:
#   {{product.statusLabel}}   display label from stateLabels[state]
#   {{product.versionLabel}}  "vX.Y.Z" or ""
#   {{product.meta}}          "vX.Y.Z · Platform" or "Platform"
#   {{product.proofStrip}}    full release-status/proof strip (cannot drift from cards)
#   {{product.downloadBlock}} primary CTA (download button or muted "coming soon")
#   {{product.hashBlock}}     SHA-256 code block, or empty
#   {{product.releaseNoteBlock}}  note paragraph, or empty

[CmdletBinding()]
param(
  [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$root = (Resolve-Path "$PSScriptRoot/..").Path
Set-Location $root

$manifestPath = Join-Path $root 'site-manifest.json'
$partialsDir  = Join-Path $root 'partials'
$publicDir    = Join-Path $root 'public'

if (-not (Test-Path $manifestPath)) { throw "site-manifest.json not found at $manifestPath" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────
$allowedStates = @('pilot','available','frozen','testing','proof','coming')
$statesRequiringDownload = @('pilot','available','frozen')
$errors = @()

function StateLabel($state) {
  return $manifest.stateLabels.$state
}

$seenIds = @{}
$seenRoutes = @{}
foreach ($p in $manifest.products) {
  $tag = "[$($p.id)]"
  if ([string]::IsNullOrWhiteSpace($p.id)) { $errors += "$tag missing id"; continue }
  if ($seenIds.ContainsKey($p.id)) { $errors += "duplicate product id: $($p.id)" }
  $seenIds[$p.id] = $true

  if ([string]::IsNullOrWhiteSpace($p.name)) { $errors += "$tag missing name" }
  if ([string]::IsNullOrWhiteSpace($p.route)) { $errors += "$tag missing route" }
  else {
    if ($seenRoutes.ContainsKey($p.route)) { $errors += "duplicate route: $($p.route) (id $($p.id))" }
    $seenRoutes[$p.route] = $true
  }

  if (-not ($allowedStates -contains $p.state)) {
    $errors += "$tag unknown state '$($p.state)'. Allowed: $($allowedStates -join ', ')"
  }

  if ($p.visible) {
    if ([string]::IsNullOrWhiteSpace($p.summary)) { $errors += "$tag visible product missing summary" }
    if ([string]::IsNullOrWhiteSpace($p.cta))     { $errors += "$tag visible product missing cta" }
  }

  # Internal route (starts with /) must have a source template {id}.html
  if ($p.route -like '/*') {
    $src = Join-Path $root ("$($p.id).html")
    if (-not (Test-Path $src)) { $errors += "$tag internal route $($p.route) but no template $($p.id).html" }
  }

  # Released states must have a download URL
  if ($statesRequiringDownload -contains $p.state) {
    if ([string]::IsNullOrWhiteSpace($p.downloadUrl)) {
      $errors += "$tag state '$($p.state)' requires downloadUrl"
    }
  }

  # Version format if present
  if (-not [string]::IsNullOrWhiteSpace($p.version)) {
    if ($p.version -notmatch '^\d+\.\d+\.\d+$') {
      $errors += "$tag malformed version '$($p.version)' (expected X.Y.Z)"
    }
  }

  # CTA must not promise a download when no artifact exists
  if ($p.cta -like 'Download*' -and [string]::IsNullOrWhiteSpace($p.downloadUrl)) {
    $errors += "$tag cta says Download but downloadUrl is empty"
  }

  # A download label that says "Download" must name the version the manifest
  # already knows, so the button and the status chip can never disagree.
  if ($p.downloadLabel -like 'Download*' -and -not [string]::IsNullOrWhiteSpace($p.version)) {
    if ($p.downloadLabel -notlike "*$($p.version)*") {
      $errors += "$tag downloadLabel '$($p.downloadLabel)' omits version $($p.version)"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($p.downloadLabel) -and [string]::IsNullOrWhiteSpace($p.downloadUrl)) {
    $errors += "$tag downloadLabel set but downloadUrl is empty"
  }
}

if ($errors.Count -gt 0) {
  Write-Host "==> MANIFEST VALIDATION FAILED" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "==> Manifest validated: $($manifest.products.Count) products, $($errors.Count) errors" -ForegroundColor Green

if ($ValidateOnly) { exit 0 }

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Read-File($path) { return (Get-Content $path -Raw -Encoding UTF8) }

function VersionLabel($p) {
  # publicVersion is the explicit published-release version (may differ from the
  # legacy 'version' field, which now also holds the published version).
  $v = if (-not [string]::IsNullOrWhiteSpace($p.publicVersion)) { $p.publicVersion }
       elseif (-not [string]::IsNullOrWhiteSpace($p.version))      { $p.version }
       else { return '' }
  return "v$v"
}

function CurrentVersionLabel($p) {
  if ([string]::IsNullOrWhiteSpace($p.currentLocalVersion)) { return '' }
  return "Local v$($p.currentLocalVersion)"
}

function CompanionLabel($p) {
  if ([string]::IsNullOrWhiteSpace($p.companionVersion)) { return '' }
  return "Companion v$($p.companionVersion)"
}

function PlatformLabel($p) {
  # Prefer the platforms array; fall back to the legacy string field.
  if ($p.platforms -is [array] -and $p.platforms.Count -gt 0) {
    return ($p.platforms -join ' + ')
  }
  if (-not [string]::IsNullOrWhiteSpace($p.platform)) {
    return $p.platform
  }
  return ''
}

function TestStatusLabel($p) {
  # testStatus is the canonical field; fall back to testCount for backward compat.
  if (-not [string]::IsNullOrWhiteSpace($p.testStatus)) { return $p.testStatus }
  if (-not [string]::IsNullOrWhiteSpace($p.testCount))  { return $p.testCount }
  return ''
}

function MetaLine($p) {
  $parts = @()
  $vl = VersionLabel $p
  if ($vl) { $parts += $vl }
  $pl = PlatformLabel $p
  if ($pl) { $parts += $pl }
  return ($parts -join ' · ')
}

function Html-Attr($s) { return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

function IsExternalUrl($url) {
  return $url -like 'http://*' -or $url -like 'https://*'
}
function IsFileDownload($url) {
  return $url -like '*.zip' -or $url -like '*.exe' -or $url -like '*.apk'
}

# Resolve computed blocks for a product
function ProductTokens($p) {
  $tokens = @{}
  $tokens['id']                  = $p.id
  $tokens['name']                = $p.name
  $tokens['route']               = $p.route
  $tokens['state']               = $p.state
  $tokens['statusLabel']         = StateLabel $p.state
  $tokens['versionLabel']        = VersionLabel $p
  $tokens['currentVersionLabel'] = CurrentVersionLabel $p
  $tokens['companionLabel']      = CompanionLabel $p
  $tokens['version']             = $p.version
  $tokens['meta']                = MetaLine $p
  $tokens['platform']            = PlatformLabel $p
  $tokens['summary']             = $p.summary
  $tokens['cta']                 = $p.cta
  $tokens['distType']            = $p.distType
  $tokens['build']               = $p.build
  $tokens['testStatus']          = TestStatusLabel $p
  $tokens['testCount']           = $p.testCount
  $tokens['proofStatus']         = $p.proofStatus
  $tokens['lastVerified']        = $p.lastVerified
  $tokens['downloadUrl']         = $p.downloadUrl
  $tokens['downloadLabel']       = $p.downloadLabel
  $tokens['sha256']              = $p.sha256
  $tokens['sha256Url']           = $p.sha256Url
  $tokens['releaseNote']         = $p.releaseNote

  # proofStrip
  $pills = @()
  $pills += "<span class=`"proof-pill`"><strong>Status</strong> $($tokens['statusLabel'])</span>"
  $ver = if ($tokens['versionLabel']) { $tokens['versionLabel'] } else { '&mdash;' }
  $pills += "<span class=`"proof-pill`"><strong>Version</strong> $ver</span>"
  $pills += "<span class=`"proof-pill`"><strong>Platform</strong> $($tokens['platform'])</span>"
  if ($tokens['testStatus']) {
    $pills += "<span class=`"proof-pill`"><strong>Tests</strong> $($tokens['testStatus'])</span>"
  }
  $pills += "<span class=`"proof-pill`"><strong>Proof</strong> $($tokens['proofStatus'])</span>"
  $lv = if ($p.lastVerified) { $p.lastVerified } else { '&mdash;' }
  $pills += "<span class=`"proof-pill`"><strong>Verified</strong> $lv</span>"
  $tokens['proofStrip'] = "<div class=`"proof-strip`">" + ($pills -join "`n          ") + "</div>"

  # downloadBlock
  if ([string]::IsNullOrWhiteSpace($p.downloadUrl)) {
    # Both are the same disabled treatment, but the wording differs on purpose:
    # "coming soon" is a commitment, and an in-proof product has not made one.
    $mutedLabel = if ($p.state -eq 'proof') { 'No public build yet' } else { 'Coming soon' }
    $tokens['downloadBlock'] = "<span class=`"button button-muted`" aria-disabled=`"true`">$mutedLabel</span>"
  } else {
    $url = $p.downloadUrl
    $label = if ($p.downloadLabel) { $p.downloadLabel } else { 'Download' }
    $extAttr = ''
    $dlAttr = ''
    if (IsExternalUrl $url) {
      $extAttr = ' target="_blank" rel="noopener"'
    }
    if (IsFileDownload $url) { $dlAttr = ' download' }
    $tokens['downloadBlock'] = "<a class=`"button button-primary`" href=`"$url`"$extAttr$dlAttr>$label</a>"
    if (-not [string]::IsNullOrWhiteSpace($p.sha256Url)) {
      $tokens['downloadBlock'] += " <a class=`"button button-secondary`" href=`"$($p.sha256Url)`" target=`"_blank`" rel=`"noopener`">SHA-256</a>"
    }
  }

  # hashBlock
  if (-not [string]::IsNullOrWhiteSpace($p.sha256)) {
    $tokens['hashBlock'] = "<div class=`"code-block`">$($p.sha256)</div>"
  } else {
    $tokens['hashBlock'] = ''
  }

  # releaseNoteBlock
  if (-not [string]::IsNullOrWhiteSpace($p.releaseNote)) {
    $tokens['releaseNoteBlock'] = "<p class=`"note`">$($p.releaseNote)</p>"
  } else {
    $tokens['releaseNoteBlock'] = ''
  }

  return $tokens
}

# Apply {{product.X}} substitution to a string given a tokens hashtable
function Replace-ProductTokens($text, $tokens) {
  foreach ($key in $tokens.Keys) {
    $text = $text -replace [regex]::Escape("{{product.$key}}"), $tokens[$key]
  }
  # Strip any leftover product tokens (e.g. on non-product pages)
  $text = $text -replace '\{\{product\.[^}]+\}\}', ''
  return $text
}

# ─────────────────────────────────────────────────────────────────────────────
# Build nav links + footer products
# ─────────────────────────────────────────────────────────────────────────────
function Build-NavLinks($activeId) {
  # Product pages map to the "products" nav item
  $productIds = @()
  foreach ($p in $manifest.products) { $productIds += $p.id }
  if ($productIds -contains $activeId) { $activeId = 'products' }

  $links = @()
  foreach ($item in $manifest.nav) {
    $cur = ''
    if ($item.id -eq $activeId) { $cur = ' aria-current="page"' }
    $links += "<a href=`"$($item.href)`"$cur>$($item.label)</a>"
  }
  return ($links -join "`n        ")
}

function Build-FooterProducts {
  $items = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    $items += "<li><a href=`"$($p.route)`">$($p.name)</a></li>"
  }
  return ($items -join "`n          ")
}

function Build-ProductCards {
  $cardTemplate = Read-File (Join-Path $partialsDir 'product-card.html')
  $cards = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    $t = ProductTokens $p
    $card = $cardTemplate
    $card = $card -replace [regex]::Escape('{{name}}'),         $t['name']
    $card = $card -replace [regex]::Escape('{{route}}'),        $t['route']
    $card = $card -replace [regex]::Escape('{{state}}'),        $t['state']
    $card = $card -replace [regex]::Escape('{{statusLabel}}'),  $t['statusLabel']
    $card = $card -replace [regex]::Escape('{{summary}}'),      $t['summary']
    $card = $card -replace [regex]::Escape('{{meta}}'),         $t['meta']
    $card = $card -replace [regex]::Escape('{{cta}}'),          $t['cta']
    $cards += $card
  }
  return ($cards -join "`n`n          ")
}

function Build-ReceiptCards {
  $cards = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    $t = ProductTokens $p

    # status indicator class
    $ps = if ($p.proofStatus) { $p.proofStatus } else { 'verification pending' }
    $statusClass = ($ps -replace ' ', '-')

    # route link
    if ($p.route -like 'http*') {
      $routeLink = "<a href=`"$($p.route)`" target=`"_blank`" rel=`"noopener`">External link</a>"
    } elseif ($p.route -like '/*') {
      $routeLink = "<a href=`"$($p.route)`">$($p.route)</a>"
    } else {
      $routeLink = '<span style="color:var(--muted);">N/A</span>'
    }

    # version
    $ver = if ($t['versionLabel']) { $t['versionLabel'] } else { '<span style="color:var(--muted);">Unreleased</span>' }

    # sha
    if (-not [string]::IsNullOrWhiteSpace($p.sha256) -and $p.sha256 -match '^[0-9a-fA-F]{64}$') {
      $sha = "<dd class=`"code`" title=`"$($p.sha256)`">$($p.sha256.Substring(0,16))&hellip;</dd>"
    } else {
      $sha = '<dd style="color:var(--muted);">Unreleased</dd>'
    }

    # proof links
    if ($p.proofLinks -and $p.proofLinks.Count -gt 0) {
      $links = @()
      foreach ($link in $p.proofLinks) {
        $base = $link -split '/' | Select-Object -Last 1
        $links += "<a href=`"$link`" target=`"_blank`" rel=`"noopener`">$base</a>"
      }
      $proofLinks = "<dd>$($links -join ', ')</dd>"
    } else {
      $proofLinks = '<dd style="color:var(--muted);">Not listed yet</dd>'
    }

    $lv = if ($p.lastVerified) { $p.lastVerified } else { '<span style="color:var(--muted);">N/A</span>' }

    # download action
    if ([string]::IsNullOrWhiteSpace($p.downloadUrl)) {
      $label = if ($p.state -eq 'proof') { 'No download yet' } else { 'Download coming soon' }
      $action = "<span class=`"button button-muted`" style=`"display:block; text-align:center;`">$label</span>"
    } else {
      $ext = if (IsExternalUrl $p.downloadUrl) { ' target="_blank" rel="noopener"' } else { '' }
      $dl = if (IsFileDownload $p.downloadUrl) { ' download' } else { '' }
      $action = "<a class=`"button button-primary`" style=`"display:block; text-align:center;`" href=`"$($p.downloadUrl)`"$ext$dl>$($t['downloadLabel'])</a>"
    }

    $build = if ($p.build) { $p.build } else { 'Release details coming soon.' }

    $cards += @"
        <article class="receipt-card">
          <div class="receipt-card-head">
            <div>
              <h3>$($t['name'])</h3>
              <span class="platform-badge">$($t['platform'])</span>
            </div>
            <span class="status-indicator $statusClass">$ps</span>
          </div>
          <p class="build-desc">$build</p>
          <dl class="receipt-fields">
            <div><dt>Route</dt><dd>$routeLink</dd></div>
            <div><dt>Latest Version</dt><dd>$ver</dd></div>
            <div><dt>SHA-256 Checksum</dt>$sha</div>
            <div><dt>Proof Link</dt>$proofLinks</div>
            <div><dt>Last Verified</dt><dd>$lv</dd></div>
          </dl>
          <div class="receipt-card-action">$action</div>
        </article>
"@
  }
  return ($cards -join "`n`n          ")
}

# ─────────────────────────────────────────────────────────────────────────────
# Prepare public/ output dir
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "==> Rebuilding public/ from templates + partials + manifest"
if (Test-Path $publicDir) { Remove-Item $publicDir -Recurse -Force }
New-Item -ItemType Directory $publicDir | Out-Null

# ─────────────────────────────────────────────────────────────────────────────
# Process every template
# ─────────────────────────────────────────────────────────────────────────────
# Map: source file  ->  output path under public/
$dirRoutes = @('reality-gate','forgecast','lights-out','cache-vault','cleanroom','proofshot','founders','proof','support-context','foundry-strike')
$rootFiles = @('index.html','404.html')

$headerPartial = Read-File (Join-Path $partialsDir 'header.html')
$footerPartial = Read-File (Join-Path $partialsDir 'footer.html')

function Process-Template($srcPath, $srcName) {
  $html = Read-File $srcPath

  # Extract @page id
  $pageId = ''
  if ($html -match '<!--\s*@page\s+(\S+)\s*-->') { $pageId = $Matches[1] }
  $html = $html -replace '<!--\s*@page\s+\S+\s*-->\s*\r?\n?', ''

  # Extract @product slug (binds product tokens)
  $productSlug = ''
  if ($html -match '<!--\s*@product\s+(\S+)\s*-->') { $productSlug = $Matches[1] }
  $html = $html -replace '<!--\s*@product\s+\S+\s*-->\s*\r?\n?', ''

  # Resolve nav + cta
  $navLinks = Build-NavLinks $pageId
  $navCta = "<a class=`"button button-primary nav-cta`" href=`"$($manifest.navCta.href)`">$($manifest.navCta.label)</a>"
  $header = $headerPartial
  $header = $header -replace [regex]::Escape('{{nav-links}}'), $navLinks
  $header = $header -replace [regex]::Escape('{{nav-cta}}'),   $navCta

  $footer = $footerPartial -replace [regex]::Escape('{{footer-products}}'), (Build-FooterProducts)

  # Inject partials
  $html = $html -replace '<!--\s*@include header\s*-->', $header
  $html = $html -replace '<!--\s*@include footer\s*-->', $footer

  # Inject product cards (homepage)
  $html = $html -replace '<!--\s*@products\s*-->', (Build-ProductCards)

  # Inject receipt cards (receipts page)
  $html = $html -replace '<!--\s*@receipts\s*-->', (Build-ReceiptCards)

  # Brand-level tokens
  $html = $html -replace [regex]::Escape('{{brand}}'),       $manifest.brand
  $html = $html -replace [regex]::Escape('{{tagline}}'),     $manifest.tagline
  $html = $html -replace [regex]::Escape('{{positioning}}'), $manifest.positioning

  # Product tokens (if bound)
  if ($productSlug) {
    $bound = $null
    foreach ($p in $manifest.products) { if ($p.id -eq $productSlug) { $bound = $p; break } }
    if (-not $bound) { throw "Template $srcName binds @product $productSlug but no such product in manifest" }
    $tokens = ProductTokens $bound
    $html = Replace-ProductTokens $html $tokens
  } else {
    $html = Replace-ProductTokens $html @{}
  }

  # Generated-file warning (after doctype)
  $warning = "<!-- GENERATED FILE — DO NOT EDIT. Source: $srcName + site-manifest.json. Run scripts/build-site.ps1 to rebuild. -->`r`n"
  $html = $html -replace '(<!doctype[^>]*>\s*\r?\n)', "`$1$warning"

  return $html
}

# Root files
foreach ($f in $rootFiles) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { continue }
  $out = Process-Template $src $f
  $outPath = Join-Path $publicDir $f
  Set-Content -Path $outPath -Value $out -Encoding UTF8 -NoNewline
}

# Directory-route files
foreach ($slug in $dirRoutes) {
  $src = Join-Path $root "$slug.html"
  if (-not (Test-Path $src)) { continue }
  $out = Process-Template $src "$slug.html"
  $dir = Join-Path $publicDir $slug
  New-Item -ItemType Directory $dir -Force | Out-Null
  Set-Content -Path (Join-Path $dir 'index.html') -Value $out -Encoding UTF8 -NoNewline
}

# ─────────────────────────────────────────────────────────────────────────────
# Copy static assets
# ─────────────────────────────────────────────────────────────────────────────
Copy-Item (Join-Path $root 'styles.css')     $publicDir -Force
if (Test-Path (Join-Path $root 'site.js'))   { Copy-Item (Join-Path $root 'site.js') $publicDir -Force }
Copy-Item (Join-Path $root 'CNAME')          $publicDir -Force
Copy-Item (Join-Path $root 'robots.txt')     $publicDir -Force
Copy-Item (Join-Path $root 'sitemap.xml')    $publicDir -Force
Copy-Item (Join-Path $root 'site-manifest.json') $publicDir -Force
Copy-Item (Join-Path $root 'brand')  $publicDir -Recurse -Force
Copy-Item (Join-Path $root 'assets') $publicDir -Recurse -Force

# Expose deploy receipts publicly
if (Test-Path (Join-Path $root 'reports/deploy-receipts')) {
  $receiptsOut = Join-Path $publicDir 'reports/deploy-receipts'
  New-Item -ItemType Directory $receiptsOut -Force | Out-Null
  Copy-Item -Path (Join-Path $root 'reports/deploy-receipts\*') -Destination $receiptsOut -Recurse -Force
}

# ─────────────────────────────────────────────────────────────────────────────
# Generate _headers
# ─────────────────────────────────────────────────────────────────────────────
$headersContent = @"
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/*.html
  Cache-Control: no-cache, must-revalidate

/reality-gate/
  Cache-Control: no-cache, must-revalidate
/forgecast/
  Cache-Control: no-cache, must-revalidate
/lights-out/
  Cache-Control: no-cache, must-revalidate
/cache-vault/
  Cache-Control: no-cache, must-revalidate
/cleanroom/
  Cache-Control: no-cache, must-revalidate
/proofshot/
  Cache-Control: no-cache, must-revalidate
/founders/
  Cache-Control: no-cache, must-revalidate
/proof/
  Cache-Control: no-cache, must-revalidate
/support-context/
  Cache-Control: no-cache, must-revalidate
/foundry-strike/
  Cache-Control: no-cache, must-revalidate

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/brand/*
  Cache-Control: public, max-age=31536000, immutable
"@
Set-Content -Path (Join-Path $publicDir '_headers') -Value $headersContent -Encoding UTF8

# Copy _redirects from root
Copy-Item (Join-Path $root '_redirects') $publicDir -Force

$productCount = ($manifest.products | Where-Object { $_.visible }).Count
Write-Host "==> Build complete: public/ regenerated. $productCount visible products, $($dirRoutes.Count) directory routes." -ForegroundColor Green
exit 0
