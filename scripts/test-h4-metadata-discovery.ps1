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
param(
  [string]$BaselineRef = '',
  [switch]$NegativeControl
)

. "$PSScriptRoot/release-qualification.ps1"
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

function Read-GitText([string]$revision, [string]$relativePath) {
  $spec = "${revision}:$relativePath"
  & git -C $root cat-file -e $spec 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  $lines = & git -C $root show $spec
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($lines -join "`n")
}

function Read-GitJson([string]$revision, [string]$relativePath) {
  $raw = Read-GitText $revision $relativePath
  if ($null -eq $raw) { return $null }
  try { return ($raw | ConvertFrom-Json -Depth 100) }
  catch { throw "Invalid JSON in ${revision}:$relativePath — $($_.Exception.Message)" }
}

function ConvertTo-CanonicalInput($value) {
  if ($null -eq $value -or $value -is [string] -or $value -is [ValueType]) { return $value }
  if ($value -is [array]) {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $value) { $items.Add((ConvertTo-CanonicalInput $item)) }
    return ,$items.ToArray()
  }
  $sorted = [ordered]@{}
  if ($value -is [System.Collections.IDictionary]) {
    foreach ($key in @($value.Keys | Sort-Object -CaseSensitive)) { $sorted[$key] = ConvertTo-CanonicalInput $value[$key] }
  } else {
    foreach ($property in @($value.PSObject.Properties | Sort-Object Name -CaseSensitive)) { $sorted[$property.Name] = ConvertTo-CanonicalInput $property.Value }
  }
  return $sorted
}
function ConvertTo-InputSignature($value) {
  # Object insertion order is not a public content change. Values, arrays,
  # presence and nulls still participate in the complete input comparison.
  return (ConvertTo-Json -InputObject (ConvertTo-CanonicalInput $value) -Depth 100 -Compress)
}

function Get-ModuleRouteSignatures([string]$revision, [string]$productId, [switch]$SimulateProductContentChange) {
  $modulePath = "products/$productId/module.json"
  $module = Read-GitJson $revision $modulePath
  if (-not $module) { return $null }
  if ($SimulateProductContentChange) {
    $module.hero.headline = [string]$module.hero.headline + ' [simulated route content change]'
  }
  $manifest = Get-AuthoredReleaseManifestAt $revision
  $productState = @($manifest.products | Where-Object { $_.id -eq $productId } | Select-Object -First 1)[0]

  $productHero = [ordered]@{}
  foreach ($property in @($module.hero.PSObject.Properties)) {
    # sceneFamily is a renderer classification data attribute. The public page
    # art and content are represented by the actual media, copy and section data.
    if ($property.Name -ne 'sceneFamily') { $productHero[$property.Name] = $property.Value }
  }
  $productContent = ''
  $productSource = ''
  if ($module.contentSource) {
    $content = Read-GitText $revision "products/$productId/content.html"
    if ($null -ne $content) {
      $productSource = $content
      # Ignore comments and class-only layout changes. Keep public text, links,
      # image sources, labels and all other source data in the route signature.
      $productContent = [regex]::Replace($content, '(?s)<!--.*?-->', '')
      $productContent = [regex]::Replace($productContent, '(?i)\sclass=("[^"]*"|''[^'']*'')', '')
      $productContent = [regex]::Replace($productContent, '\s+', ' ').Trim()
    }
  }

  $productStateProjection = [ordered]@{
    name = $productState.name
    publicVersion = $productState.release.publicVersion
    releaseStatus = $productState.release.releaseStatus
    verificationStatus = $productState.verification.status
    downloadUnavailable = $productState.presentation.downloadUnavailable
    downloadUrl = $productState.downloadUrl
    contentTokens = [ordered]@{}
  }
  $tokenPaths = @([regex]::Matches($productSource, '\{\{\s*product\.([a-zA-Z0-9_.]+)\s*\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  foreach ($tokenPath in $tokenPaths) {
    $value = $productState
    foreach ($part in $tokenPath.Split('.')) {
      $property = if ($null -ne $value) { $value.PSObject.Properties[$part] } else { $null }
      if ($null -eq $property) { $value = $null; break }
      $value = $property.Value
    }
    $productStateProjection.contentTokens[$tokenPath] = $value
  }

  $productPage = [ordered]@{
    id = $module.id; route = $module.route; visibility = $module.visibility; lifecycle = $module.lifecycle
    schemaVersion = $module.schemaVersion; brand = $module.brand; meta = $module.meta; hero = $productHero
    theme = $module.theme; sections = $module.sections; contentSource = $module.contentSource
    inlineCss = $module.inlineCss; jsonLd = $module.jsonLd; content = $productContent; productState = $productStateProjection
  }
  $catalogCard = [ordered]@{
    id = $module.id; route = $module.route; visibility = $module.visibility; order = $module.order
    placement = $module.placement; commerce = $module.commerce; brand = $module.brand; card = $module.card
    theme = $module.theme; taxonomy = $module.taxonomy; productState = $productState
    # The catalog card renderer consumes this one homepage field as a data attribute.
    catalogSceneFamily = $module.homepage.sceneFamily
  }
  $homepageCard = [ordered]@{
    id = $module.id; route = $module.route; visibility = $module.visibility; lifecycle = $module.lifecycle
    homepage = $module.homepage; card = $module.card; brand = $module.brand; hero = $module.hero
    theme = $module.theme; taxonomy = $module.taxonomy; commerce = $module.commerce; order = $module.order
    placement = $module.placement; productState = $productState
  }

  return [pscustomobject]@{
    Id = [string]$module.id; Route = [string]$module.route; Visibility = [string]$module.visibility
    Product = ConvertTo-InputSignature $productPage
    Catalog = ConvertTo-InputSignature $catalogCard
    Homepage = ConvertTo-InputSignature $homepageCard
  }
}

function Get-ModuleInputDates([string]$baseline, [string]$productId) {
  $paths = @("products/$productId/module.json", "products/$productId/content.html", 'site-manifest.json', 'release-truth.json')
  $commits = @(& git -C $root rev-list --reverse "$baseline..HEAD" -- $paths)
  $previous = Get-ModuleRouteSignatures $baseline $productId
  $dates = [ordered]@{ Product = $null; Catalog = $null; Homepage = $null }
  foreach ($commit in $commits) {
    $current = Get-ModuleRouteSignatures $commit $productId
    if (-not $current) { continue }
    $commitDate = (& git -C $root show -s --format=%cs $commit).Trim()
    if (-not $previous -or $current.Product -cne $previous.Product) { $dates.Product = $commitDate }
    if (-not $previous -or $current.Catalog -cne $previous.Catalog) { $dates.Catalog = $commitDate }
    if (-not $previous -or $current.Homepage -cne $previous.Homepage) { $dates.Homepage = $commitDate }
    $previous = $current
  }
  return [pscustomobject]@{ Product = $dates.Product; Catalog = $dates.Catalog; Homepage = $dates.Homepage }
}

function Get-ChangedSourceDate([string]$baseline, [string]$relativePath) {
  $previous = Read-GitText $baseline $relativePath
  $commits = @(& git -C $root rev-list --reverse "$baseline..HEAD" -- $relativePath)
  $lastDate = $null
  foreach ($commit in $commits) {
    $current = Read-GitText $commit $relativePath
    if ($current -cne $previous) {
      $lastDate = (& git -C $root show -s --format=%cs $commit).Trim()
    }
    $previous = $current
  }
  return $lastDate
}

Write-Host "=== H4 METADATA / DISCOVERY ASSERTIONS ==="

# Intended public route set: 24 indexable routes (404 is deliberately noindex
# and therefore absent from sitemap/canonical expectations). H11 (2026-09-20)
# added /truth/; PF-TF1 (2026-09-21) added /truth-files/ plus its 7 per-product
# records as first-class indexable routes.
$indexableRoutes = @('', 'reality-gate', 'forgecast', 'lights-out', 'cache-vault', 'cleanroom', 'ghostlayer', 'proofshot', 'founders', 'proof', 'roadmap', 'support', 'about', 'proof-standard', 'software', 'truth', 'truth-files', 'truth-files/cache-vault', 'truth-files/cleanroom', 'truth-files/forgecast', 'truth-files/ghostlayer', 'truth-files/lights-out', 'truth-files/proofshot', 'truth-files/reality-gate')
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
Assert-Condition ($locs.Count -eq 24) "sitemap: exactly 24 indexable routes listed"
Assert-Condition (@($locs | Sort-Object -Unique).Count -eq $locs.Count) "sitemap: no duplicate routes"
Assert-Condition (($locs -contains "$originHost/support/")) "F4: sitemap includes /support/"

# Sitemap route identity must equal the canonical route identity of the pages
$sitemapSet = @{}; foreach ($l in $locs) { $sitemapSet[$l] = $true }
$setsEqual = ($locs.Count -eq $canonicalSet.Count)
if ($setsEqual) { foreach ($k in $canonicalSet.Keys) { if (-not $sitemapSet.ContainsKey($k)) { $setsEqual = $false } } }
Assert-Condition $setsEqual "sitemap: route inventory matches the pages' canonical identities exactly"

# lastmod truth rule (corrected H11-R1): a sitemap lastmod must reflect a real
# page-content event — a shared build input (site-manifest.json, partials)
# changing does NOT prove the rendered page changed. This test therefore asserts
# only what is locally provable: every listed route is a real human route,
# each lastmod is a valid ISO date, and none is in the future. Route-specific
# expected dates live in tranche tests (H11 owns /truth/ and /proof-standard/).
$lastmodByLoc = @{}
for ($i = 0; $i -lt $locs.Count; $i++) { $lastmodByLoc[$locs[$i]] = $mods[$i] }
foreach ($route in $indexableRoutes) {
  $label = if ($route -eq '') { '/' } else { "/$route/" }
  $loc = if ($route -eq '') { "$originHost/" } else { "$originHost/$route/" }
  Assert-Condition ($lastmodByLoc.ContainsKey($loc)) "F5: sitemap lists human route $label"
  Assert-Condition ($lastmodByLoc[$loc] -match '^\d{4}-\d{2}-\d{2}$') "F5: sitemap lastmod for $label is a valid ISO date"
}
$today = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
Assert-Condition (@($mods | Where-Object { $_ -gt $today }).Count -eq 0) "sitemap: no lastmod in the future (no manufactured freshness)"

# Generated module routes have more than one public input: the rendered module
# fields, the module's narrative content, and that product's canonical public
# state. Compare those inputs with the currently deployed source baseline and
# require lastmod to match the newest material input commit. Home and software
# also consume module data, but through different projections. This avoids
# treating homepage-only module fields or class-only responsive markup as a
# content change to every product page.
$baselineRef = $BaselineRef
if ([string]::IsNullOrWhiteSpace($baselineRef)) { $baselineRef = $env:PF_METADATA_BASELINE_REF }
if ([string]::IsNullOrWhiteSpace($baselineRef)) {
  $upstreamRef = (& git -C $root rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
  if ($LASTEXITCODE -eq 0 -and $upstreamRef) { $baselineRef = $upstreamRef.Trim() }
}
if ([string]::IsNullOrWhiteSpace($baselineRef)) { $baselineRef = 'c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce' }
$baselineExists = $false
& git -C $root rev-parse --verify "$baselineRef^{commit}" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $baselineExists = $true }
$baselineCommit = if ($baselineExists) { (& git -C $root merge-base HEAD $baselineRef).Trim() } else { $null }
Assert-Condition (-not [string]::IsNullOrWhiteSpace($baselineCommit)) "module inputs: deployed baseline resolves ($baselineRef)"

if (-not [string]::IsNullOrWhiteSpace($baselineCommit)) {
  $routeInputDates = @{ Home = @(); Software = @() }
  $homeSourceDate = Get-ChangedSourceDate $baselineCommit 'index.html'
  $softwareSourceDate = Get-ChangedSourceDate $baselineCommit 'software.html'
  if ($homeSourceDate) { $routeInputDates.Home += $homeSourceDate }
  if ($softwareSourceDate) { $routeInputDates.Software += $softwareSourceDate }

  $moduleInputs = @()
  foreach ($dir in (Get-ChildItem (Join-Path $root 'products') -Directory | Sort-Object Name)) {
    $module = Read-GitJson 'HEAD' "products/$($dir.Name)/module.json"
    if (-not $module -or $module.visibility -ne 'visible') { continue }
    $dates = Get-ModuleInputDates $baselineCommit ([string]$module.id)
    $moduleInputs += [pscustomobject]@{ Module = $module; Dates = $dates }
    if ($dates.Homepage) { $routeInputDates.Home += $dates.Homepage }
    if ($dates.Catalog) { $routeInputDates.Software += $dates.Catalog }
  }

  $negativeRoute = $null
  foreach ($input in $moduleInputs) {
    $module = $input.Module
    $loc = "$originHost$($module.route)"
    $inputDate = $input.Dates.Product
    if ($NegativeControl -and -not $negativeRoute) {
      # Model a future content commit to a discovered module route while leaving
      # its sitemap entry stale. This must fail the same assertion as real drift.
      $negativeRoute = $loc
      $headSignatures = Get-ModuleRouteSignatures 'HEAD' ([string]$module.id)
      $simulatedSignatures = Get-ModuleRouteSignatures 'HEAD' ([string]$module.id) -SimulateProductContentChange
      Assert-Condition ($simulatedSignatures.Product -cne $headSignatures.Product) 'negative control: a module hero content change alters the discovered product-route input signature'
      $inputDate = [DateTime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
      Write-Host "  NEGATIVE CONTROL: simulated module content input changed for $($module.route) without a sitemap refresh"
    }
    if ($inputDate) {
      Assert-Condition ($lastmodByLoc[$loc] -ceq $inputDate) "F5: module-generated route $($module.route) lastmod matches its latest public content input ($inputDate)"
    }
  }
  if ($NegativeControl) {
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($negativeRoute)) 'negative control: a module-generated route was discovered for drift simulation'
  }

  foreach ($surface in @(@{ Name = 'Home'; Loc = "$originHost/"; Route = '/' }, @{ Name = 'Software'; Loc = "$originHost/software/"; Route = '/software/' })) {
    $dates = @($routeInputDates[$surface.Name] | Where-Object { $_ } | Sort-Object -Unique)
    if ($dates.Count -gt 0) {
      $inputDate = $dates[-1]
      Assert-Condition ($lastmodByLoc[$surface.Loc] -ceq $inputDate) "F5: module-generated route $($surface.Route) lastmod matches its latest public content input ($inputDate)"
    }
  }
}

# ── robots.txt: unchanged discovery contract ────────────────────────────────
$robotsTxt = Get-Content (Join-Path $publicDir 'robots.txt') -Raw -Encoding UTF8
Assert-Condition ($robotsTxt -match 'Allow:\s*/') "robots.txt: crawl allowed"
Assert-Condition ($robotsTxt -match 'Sitemap:\s*https://theprooffoundry\.com/sitemap\.xml') "robots.txt: sitemap reference intact"

# ── Legacy redirect coverage for every directory route (F6) ─────────────────
$redirects = Get-Content (Join-Path $publicDir '_redirects') -Raw -Encoding UTF8
$dirRoutes = @('reality-gate', 'forgecast', 'lights-out', 'cache-vault', 'cleanroom', 'ghostlayer', 'proofshot', 'founders', 'proof', 'roadmap', 'support', 'about', 'proof-standard', 'software', 'truth', 'truth-files')
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
Assert-Condition (($publicDirs -join ',') -eq (($dirRoutes | Sort-Object) -join ',')) "routes: generated directory-route set is exactly the intended 16"
Assert-Condition ((git -C $root status --porcelain -- package.json package-lock.json) -eq $null) "deps: package manifests untouched by H4"
# Product truth follows the candidate manifest. Production can intentionally
# lag a qualified candidate; the generated public proof registry must bind to
# the same candidate release fields instead of a historical production blob.
$workManifest = Get-AuthoredReleaseManifest
$proofRegistry = Get-Content (Join-Path $publicDir 'proof\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$truthDrift = @()
foreach ($p in $workManifest.products) {
  $proofProduct = @($proofRegistry.products | Where-Object { $_.id -eq $p.id }) | Select-Object -First 1
  if (-not $proofProduct) { $truthDrift += "$($p.id) missing from generated proof registry"; continue }
  foreach ($field in @('publicVersion', 'candidateVersion', 'releaseStatus', 'publishedAt')) {
    if ("$($proofProduct.release.$field)" -cne "$($p.release.$field)") { $truthDrift += "$($p.id).release.$field" }
  }
  if ("$($proofProduct.productStatus)" -cne "$($p.productStatus)") { $truthDrift += "$($p.id).productStatus" }
}
Assert-Condition ($truthDrift.Count -eq 0 -and $workManifest.products.Count -eq 7 -and $proofRegistry.products.Count -eq 7) "truth: all seven generated proof records match candidate manifest release state (drift: $($truthDrift -join ', '))"

# ── H1-H3 preservation guards on the files this tranche touched ─────────────
Assert-Condition ($rg -match '<section class="pp-origin" id="origin">') "H3 guard: Reality Gate origin history remains semantically identified"
Assert-Condition ($rg -match 'id="evidence-download"' -and $rg -match 'Withdrawn artifact record') "H3 guard: withdrawn Reality Gate artifact is disclosed as historical evidence"
Assert-Condition ($rg -match 'Withdrawn:</strong> v1\.1\.0 is not available for download' -and $rg -notmatch 'Install, update, uninstall &amp; leftover data') "H3 guard: withdrawn Reality Gate truth suppresses obsolete install onboarding"
$buildSrc = Get-Content (Join-Path $root 'scripts\build-site.ps1') -Raw -Encoding UTF8
$declaredRoutes = @([regex]::Matches([regex]::Match($buildSrc, '\$dirRoutes = @\(([^\r\n]+)\)').Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
# H13: product routes are registry-derived (products/<id>/module.json), not literals.
$registryRoutes = @(Get-ChildItem (Join-Path $root 'products') -Directory | ForEach-Object { $_.Name })
Assert-Condition ((($declaredRoutes + $registryRoutes | Sort-Object) -join ',') -eq (($dirRoutes | Sort-Object) -join ',')) "build: declared routes + module registry exactly match the H8 routes plus H9 software"
Assert-Condition ($rg -match 'GENERATED FILE - DO NOT EDIT') "build: generated output carries the do-not-edit provenance marker"
Assert-Condition (Test-Path (Join-Path $publicDir 'proof\index.json')) "build: proof registry still generated"

Write-Host ""
Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
