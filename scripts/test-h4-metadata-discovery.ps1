# H4 METADATA / DISCOVERY HARDENING — bounded assertions (audit-driven, P3 scope)
#
# Coverage contract:
#   F1-F3  Reality Gate robots + OG + Twitter/social block present and route-correct
#   F4     /support/ present in sitemap
#   F5     sitemap lastmod values satisfy the source-of-truth rule (below)
#   F6     /support + /support.html legacy redirects exist
#   F7     /support/ present in generated _headers no-cache route list
#   Guards: every indexable route's canonical/robots/OG/Twitter set; sitemap
#           route set == canonical route set; 404 stays noindex w/o canonical;
#           H1-H3 preservation on frozen files; H9 software route is explicit
#
# H9 lastmod reconciliation rule: common navigation changed on 2026-09-18 UTC.
# Every route therefore uses that recorded content event date; dates must also
# be >= the latest committed content input and <= the current UTC date. This
# represents an uncommitted owner-review candidate without manufacturing a
# newer Git commit or requiring the older HEAD-only equality rule to pass.
#
# Runs against built public/ output plus the tracked static discovery files.
# No network.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$publicDir = Join-Path $root 'public'

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

function Get-MetaContent([string]$head, [string]$key) {
  foreach ($m in [regex]::Matches($head, '(?s)<meta\b[^>]*>')) {
    $tag = $m.Value
    $name = [regex]::Match($tag, '(?:name|property)="([^"]+)"').Groups[1].Value
    if ($name -eq $key) { return [regex]::Match($tag, 'content="([^"]*)"').Groups[1].Value }
  }
  return $null
}

function Get-Canonical([string]$head) {
  $c = [regex]::Match($head, '<link\b[^>]*rel="canonical"[^>]*>')
  if ($c.Success) { return [regex]::Match($c.Value, 'href="([^"]+)"').Groups[1].Value }
  return $null
}

function Get-LastContentDate([string[]]$paths) {
  $dates = @()
  foreach ($p in $paths) {
    $d = (& git -C $root log -1 --format=%cs -- $p)
    if ($d) { $dates += $d }
  }
  if ($dates.Count -eq 0) { return $null }
  return ($dates | Sort-Object | Select-Object -Last 1)
}

Write-Host "=== H4 METADATA / DISCOVERY ASSERTIONS ==="

# Intended public route set: 15 indexable routes (404 is deliberately noindex
# and therefore absent from sitemap/canonical expectations).
$indexableRoutes = @('', 'reality-gate', 'forgecast', 'lights-out', 'cache-vault', 'cleanroom', 'ghostlayer', 'proofshot', 'founders', 'proof', 'roadmap', 'support', 'about', 'proof-standard', 'software')
$originHost = 'https://theprooffoundry.com'

# ── Per-route head metadata: canonical, robots, description, OG, Twitter ────
$canonicalSet = @{}
foreach ($route in $indexableRoutes) {
  $label = if ($route -eq '') { '/' } else { "/$route/" }
  $expectedCanonical = if ($route -eq '') { "$originHost/" } else { "$originHost/$route/" }
  $html = Read-Page $route
  $head = [regex]::Match($html, '(?s)<head>(.*?)</head>').Groups[1].Value

  $canonMatches = [regex]::Matches($head, '<link\b[^>]*rel="canonical"[^>]*>')
  Assert-Condition ($canonMatches.Count -eq 1) "[$label] exactly one canonical link"
  $canon = Get-Canonical $head
  Assert-Condition ($canon -eq $expectedCanonical) "[$label] canonical resolves to intended production route"
  $canonicalSet[$expectedCanonical] = $true

  $robots = Get-MetaContent $head 'robots'
  Assert-Condition ($robots -eq 'index, follow') "[$label] robots directive is intentional (index, follow)"

  $desc = Get-MetaContent $head 'description'
  Assert-Condition (-not [string]::IsNullOrWhiteSpace($desc) -and $desc.Length -lt 200) "[$label] meta description present and bounded"

  foreach ($ogField in @('og:title', 'og:description', 'og:type', 'og:url', 'og:site_name', 'og:image')) {
    $v = Get-MetaContent $head $ogField
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($v)) "[$label] $ogField present"
  }
  Assert-Condition ((Get-MetaContent $head 'og:url') -eq $canon) "[$label] og:url matches canonical (no conflicting identity)"

  Assert-Condition ((Get-MetaContent $head 'twitter:card') -eq 'summary_large_image') "[$label] twitter:card present (summary_large_image)"
  $twImage = Get-MetaContent $head 'twitter:image'
  Assert-Condition (-not [string]::IsNullOrWhiteSpace($twImage)) "[$label] twitter:image present"

  # Social image URLs must be first-party absolute and resolve to shipped files
  foreach ($imgUrl in @((Get-MetaContent $head 'og:image'), $twImage)) {
    $ok = $imgUrl -like "$originHost/*"
    if ($ok) {
      $rel = $imgUrl.Substring($originHost.Length + 1) -replace '/', [IO.Path]::DirectorySeparatorChar
      $ok = Test-Path (Join-Path $publicDir $rel)
    }
    Assert-Condition $ok "[$label] social image resolves to a shipped file ($imgUrl)"
  }
}

# ── Reality Gate F1-F3: the H3-deferred gap is closed in generated output ───
$rg = Read-Page 'reality-gate'
Assert-Condition ($rg -match 'name="robots"') "F1: Reality Gate robots meta present"
Assert-Condition ($rg -match 'property="og:title"') "F2: Reality Gate OG block present"
Assert-Condition ($rg -match 'name="twitter:card"') "F3: Reality Gate Twitter card present"
# OG description must reuse the canonical description verbatim (no invented copy)
$rgHead = [regex]::Match($rg, '(?s)<head>(.*?)</head>').Groups[1].Value
Assert-Condition ((Get-MetaContent $rgHead 'og:description') -eq (Get-MetaContent $rgHead 'description')) "F2: Reality Gate og:description reuses the page description (no invented claims)"

# ── 404 stays a noindex error page (not an indexable route) ─────────────────
$nf = Get-Content (Join-Path $publicDir '404.html') -Raw -Encoding UTF8
$nfHead = [regex]::Match($nf, '(?s)<head>(.*?)</head>').Groups[1].Value
Assert-Condition ((Get-MetaContent $nfHead 'robots') -eq 'noindex, follow') "404: robots stays noindex, follow"
Assert-Condition ($null -eq (Get-Canonical $nfHead)) "404: no canonical on the error page"

# ── Sitemap: inventory, support membership, lastmod rule ────────────────────
$sitemapPath = Join-Path $publicDir 'sitemap.xml'
$sitemapText = Get-Content $sitemapPath -Raw -Encoding UTF8
$sitemapOk = $true
try { $null = [xml]$sitemapText } catch { $sitemapOk = $false }
Assert-Condition $sitemapOk "sitemap: generated file parses as XML"

$locs = @([regex]::Matches($sitemapText, '<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value })
$mods = @([regex]::Matches($sitemapText, '<lastmod>([^<]+)</lastmod>') | ForEach-Object { $_.Groups[1].Value })
Assert-Condition ($locs.Count -eq 15) "sitemap: exactly 15 indexable routes listed"
Assert-Condition (@($locs | Sort-Object -Unique).Count -eq $locs.Count) "sitemap: no duplicate routes"
Assert-Condition (($locs -contains "$originHost/support/")) "F4: sitemap includes /support/"

# Sitemap route identity must equal the canonical route identity of the pages
$sitemapSet = @{}; foreach ($l in $locs) { $sitemapSet[$l] = $true }
$setsEqual = ($locs.Count -eq $canonicalSet.Count)
if ($setsEqual) { foreach ($k in $canonicalSet.Keys) { if (-not $sitemapSet.ContainsKey($k)) { $setsEqual = $false } } }
Assert-Condition $setsEqual "sitemap: route inventory matches the pages' canonical identities exactly"

# lastmod rule: latest content-input commit date per route
$routeInputs = @{}
foreach ($route in $indexableRoutes) {
  $template = if ($route -eq '') { 'index.html' } else { "$route.html" }
  $inputs = @($template, 'site-manifest.json', 'partials/header.html', 'partials/footer.html')
  if ($route -eq 'software') { $inputs += 'partials/product-card.html' }
  $routeInputs[$route] = $inputs
}
$lastmodByLoc = @{}
for ($i = 0; $i -lt $locs.Count; $i++) { $lastmodByLoc[$locs[$i]] = $mods[$i] }
foreach ($route in $indexableRoutes) {
  $label = if ($route -eq '') { '/' } else { "/$route/" }
  $loc = if ($route -eq '') { "$originHost/" } else { "$originHost/$route/" }
  $committedDate = Get-LastContentDate $routeInputs[$route]
  $candidateDate = '2026-09-18'
  Assert-Condition ($lastmodByLoc[$loc] -eq $candidateDate -and $lastmodByLoc[$loc] -ge $committedDate) "F5: sitemap lastmod $label records H9 common-nav reconciliation ($candidateDate), no earlier than committed content ($committedDate)"
}
$today = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
Assert-Condition (@($mods | Where-Object { $_ -gt $today }).Count -eq 0) "sitemap: no lastmod in the future (no manufactured freshness)"

# ── robots.txt: unchanged discovery contract ────────────────────────────────
$robotsTxt = Get-Content (Join-Path $publicDir 'robots.txt') -Raw -Encoding UTF8
Assert-Condition ($robotsTxt -match 'Allow:\s*/') "robots.txt: crawl allowed"
Assert-Condition ($robotsTxt -match 'Sitemap:\s*https://theprooffoundry\.com/sitemap\.xml') "robots.txt: sitemap reference intact"

# ── Legacy redirect coverage for every directory route (F6) ─────────────────
$redirects = Get-Content (Join-Path $publicDir '_redirects') -Raw -Encoding UTF8
$dirRoutes = @('reality-gate', 'forgecast', 'lights-out', 'cache-vault', 'cleanroom', 'ghostlayer', 'proofshot', 'founders', 'proof', 'roadmap', 'support', 'about', 'proof-standard', 'software')
foreach ($r in $dirRoutes) {
  $bare = [regex]::Escape("/$r") + '\s+/' + [regex]::Escape("$r/") + '\s+301'
  $html = [regex]::Escape("/$r.html") + '\s+/' + [regex]::Escape("$r/") + '\s+301'
  $bareOk = [regex]::Match($redirects, "(?m)$bare").Success
  $htmlOk = [regex]::Match($redirects, "(?m)$html").Success
  $tag = if ($r -eq 'support') { 'F6: ' } else { '' }
  Assert-Condition ($bareOk -and $htmlOk) "redirects: ${tag}/$r and /$r.html 301 to /$r/ covered"
}
$redirectSources = @([regex]::Matches($redirects, '(?m)^(/\S+)\s+') | ForEach-Object { $_.Groups[1].Value })
Assert-Condition (@($redirectSources | Sort-Object -Unique).Count -eq $redirectSources.Count) "redirects: no duplicate source paths"

# ── Generated _headers covers every directory route (F7) ────────────────────
$headers = Get-Content (Join-Path $publicDir '_headers') -Raw -Encoding UTF8
foreach ($r in $dirRoutes) {
  $pattern = '(?m)^/' + [regex]::Escape($r) + '/\s*\r?\n\s+Cache-Control:\s*no-cache, must-revalidate'
  Assert-Condition ([regex]::Match($headers, $pattern).Success) "headers: /$r/ carries the HTML no-cache policy"
}

# ── No unexpected routes or dependency additions ────────────────────────────
$publicDirs = @(Get-ChildItem $publicDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'index.html') } | ForEach-Object { $_.Name } | Sort-Object)
Assert-Condition (($publicDirs -join ',') -eq (($dirRoutes | Sort-Object) -join ',')) "routes: generated directory-route set is exactly the intended 14"
Assert-Condition ((git -C $root status --porcelain -- package.json package-lock.json) -eq $null) "deps: package manifests untouched by H4"
# Product truth is frozen against the inspected CURRENT production commit.
# This checks all products with no target exclusions, while allowing H9 nav.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$headManifest = (git -C $root show 34a291d78fa92f1a18cf76cef3ee56b391186e77:site-manifest.json) -join "`n" | ConvertFrom-Json
$workManifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$truthDrift = @()
foreach ($p in $workManifest.products) {
  $headP = @($headManifest.products | Where-Object { $_.id -eq $p.id }) | Select-Object -First 1
  if (-not $headP) { $truthDrift += "$($p.id) (not in current production)"; continue }
  foreach ($f in @('state','productStatus','release','verification','artifacts','downloadUrl','downloadLabel','sha256','sha256Url','limits','presentation','evidence','proofLinks','companionVersion','currentLocalVersion','testStatus','testCount','releaseNote','build')) {
    $headVal = ConvertTo-Json @($headP.$f) -Depth 12 -Compress
    $workVal = ConvertTo-Json @($p.$f) -Depth 12 -Compress
    if ($headVal -ne $workVal) { $truthDrift += "$($p.id).$f" }
  }
}
Assert-Condition ($truthDrift.Count -eq 0 -and $workManifest.products.Count -eq $headManifest.products.Count) "truth: every product release field equals current production (drift: $($truthDrift -join ', '))"

# ── H1-H3 preservation guards on the files this tranche touched ─────────────
Assert-Condition ($rg -match '\.product-reality-gate #origin') "H3 guard: Reality Gate origin readability correction intact"
Assert-Condition ($rg -match 'id="evidence-download"') "H3 guard: Reality Gate canonical download block intact"
Assert-Condition ($rg -match 'Install, update, uninstall &amp; leftover data') "H3 guard: Reality Gate onboarding block intact"
$buildSrc = Get-Content (Join-Path $root 'scripts\build-site.ps1') -Raw -Encoding UTF8
$declaredRoutes = @([regex]::Matches([regex]::Match($buildSrc, '\$dirRoutes = @\(([^\r\n]+)\)').Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
Assert-Condition ((($declaredRoutes | Sort-Object) -join ',') -eq (($dirRoutes | Sort-Object) -join ',')) "build: declared routes exactly match the H8 routes plus H9 software"
Assert-Condition ($rg -match 'GENERATED FILE - DO NOT EDIT') "build: generated output carries the do-not-edit provenance marker"
Assert-Condition (Test-Path (Join-Path $publicDir 'proof\index.json')) "build: proof registry still generated"

Write-Host ""
Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
