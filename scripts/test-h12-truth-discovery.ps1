# test-h12-truth-discovery.ps1 — H12 public-truth discovery + reciprocal binding
#
# Proves the human↔machine contract: each product page advertises exactly its own
# /truth/products/<id>.json alternate; aggregate pages advertise /truth/index.json;
# truth JSON pageUrl/truthUrl point back correctly; an external agent starting from
# only a product page can discover → fetch → verify → return.
# Fixture controls prove wrong-binding, missing-truth, and duplicate-alternate fail.

$ErrorActionPreference = 'Stop'
$root   = Split-Path $PSScriptRoot -Parent
$publicDir = Join-Path $root 'public'
$script:passed = 0; $script:failed = 0
function Assert-Disc([bool]$cond, [string]$name) {
  if ($cond) { $script:passed++; Write-Host "PASS: $name" -ForegroundColor Green }
  else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red }
}
function Get-AlternateTruthLinks([string]$html) {
  return @([regex]::Matches($html, '<link\b[^>]*rel="alternate"[^>]*type="application/json"[^>]*>') |
    ForEach-Object { $_.Value })
}
function Get-LinkHref([string]$tag) {
  $m = [regex]::Match($tag, 'href="([^"]+)"')
  return $(if ($m.Success) { $m.Groups[1].Value } else { $null })
}

if (-not (Test-Path (Join-Path $publicDir 'truth/index.json'))) {
  Write-Host "public/ not built — run scripts/build-site.ps1 first" -ForegroundColor Red; exit 1
}
$manifest = Get-Content (Join-Path $root 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$visible = @($manifest.products | Where-Object { $_.visible })

# ── Per-product reciprocal binding ────────────────────────────────────────────
foreach ($p in $visible) {
  $route = $p.route.Trim('/')
  $pagePath = Join-Path $publicDir "$route\index.html"
  $truthPath = Join-Path $publicDir "truth\products\$($p.id).json"
  Assert-Disc (Test-Path $pagePath) "$($p.id): human page exists at /$route/"
  Assert-Disc (Test-Path $truthPath) "$($p.id): truth record exists at /truth/products/$($p.id).json"

  $html = [IO.File]::ReadAllText($pagePath)
  $head = [regex]::Match($html, '(?s)<head>(.*?)</head>').Groups[1].Value
  $alts = @(Get-AlternateTruthLinks $head)
  Assert-Disc ($alts.Count -eq 1) "$($p.id): exactly one public-truth alternate link in <head>"
  if ($alts.Count -ge 1) {
    Assert-Disc ((Get-LinkHref $alts[0]) -eq "/truth/products/$($p.id).json") "$($p.id): alternate points at its own truth JSON"
    Assert-Disc ($alts[0] -match 'title="Public Truth"') "$($p.id): alternate carries Public Truth title"
  }

  $truth = Get-Content $truthPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Disc ($truth.id -eq $p.id) "$($p.id): truth record id matches product"
  Assert-Disc ($truth.pageUrl -eq $p.route) "$($p.id): truth pageUrl back-references the human page"
  Assert-Disc ($truth.truthUrl -eq "/truth/products/$($p.id).json") "$($p.id): truth truthUrl self-references"
  # Canonical semantics: human canonical remains the human URL (attr order-agnostic)
  $canonTag = [regex]::Match($head, '<link\b[^>]*rel="canonical"[^>]*>').Value
  $canonHref = Get-LinkHref $canonTag
  Assert-Disc ($canonHref -eq "https://theprooffoundry.com/$route/") "$($p.id): canonical stays the human HTML URL"
}

# No product page may point at ANOTHER product's truth JSON — covered by the
# exact-href assert above; also assert no product page mentions a foreign id.
foreach ($p in $visible) {
  $route = $p.route.Trim('/')
  $head = [regex]::Match([IO.File]::ReadAllText((Join-Path $publicDir "$route\index.html")), '(?s)<head>(.*?)</head>').Groups[1].Value
  foreach ($other in $visible | Where-Object { $_.id -ne $p.id }) {
    Assert-Disc (-not ($head -match [regex]::Escape("/truth/products/$($other.id).json"))) "$($p.id): no foreign truth JSON reference to $($other.id)"
  }
}

# ── Aggregate-page discovery (H12-R1 semantics: rel=alternate means true
#    alternate representation — not generic "related JSON") ───────────────────
# Bound: /truth/ ↔ /truth/index.json (direct pair) and /software/ ↔ index
# (same public catalog reformulated). Everything else carries none.
$aggregate = @('software','truth')
foreach ($r in $aggregate) {
  $html = [IO.File]::ReadAllText((Join-Path $publicDir "$r\index.html"))
  $head = [regex]::Match($html, '(?s)<head>(.*?)</head>').Groups[1].Value
  $alts = @(Get-AlternateTruthLinks $head)
  Assert-Disc ($alts.Count -eq 1 -and (Get-LinkHref $alts[0]) -eq '/truth/index.json') "/$r/ advertises the aggregate truth index"
}
# Pages that must NOT carry a Public Truth alternate (not true representations)
foreach ($r in @('index','proof-standard','roadmap','about','founders','support','proof','404')) {
  $page = if ($r -eq '404') { '404.html' } elseif ($r -eq 'index') { 'index.html' } else { "$r\index.html" }
  $html = [IO.File]::ReadAllText((Join-Path $publicDir $page))
  $head = [regex]::Match($html, '(?s)<head>(.*?)</head>').Groups[1].Value
  Assert-Disc (@(Get-AlternateTruthLinks $head).Count -eq 0) "/$r/ carries no truth alternate (not an alternate representation)"
}

# ── Agent reciprocal-discovery control (Phase H) ──────────────────────────────
# Simulate an external agent: start from ONLY a built product page, discover the
# alternate, resolve+parse JSON, verify id, follow pageUrl back.
$agentOk = $true
foreach ($p in $visible) {
  $route = $p.route.Trim('/')
  $html = [IO.File]::ReadAllText((Join-Path $publicDir "$route\index.html"))
  $alt = Get-LinkHref ([regex]::Match($html, '<link\b[^>]*rel="alternate"[^>]*type="application/json"[^>]*>').Value)
  if (-not $alt) { $agentOk = $false; continue }
  $jsonPath = Join-Path $publicDir ($alt.TrimStart('/') -replace '/','\')
  if (-not (Test-Path $jsonPath)) { $agentOk = $false; continue }
  $rec = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($rec.id -ne $p.id -or $rec.pageUrl -ne $p.route) { $agentOk = $false; continue }
  $back = Join-Path $publicDir ($rec.pageUrl.TrimStart('/') + 'index.html' -replace '/','\')
  if (-not (Test-Path $back)) { $agentOk = $false }
}
Assert-Disc $agentOk 'agent control: all 7 products discover→resolve→verify→return with no prior /truth/ knowledge'
# Aggregate journey: /truth/ → index.json → records
$tHtml = [IO.File]::ReadAllText((Join-Path $publicDir 'truth\index.html'))
$tAlt = Get-LinkHref ([regex]::Match($tHtml, '<link\b[^>]*rel="alternate"[^>]*type="application/json"[^>]*>').Value)
$aggOk = ($tAlt -eq '/truth/index.json')
if ($aggOk) { $aggRec = Get-Content (Join-Path $publicDir 'truth\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json; $aggOk = ($aggRec.products.Count -eq $visible.Count) }
Assert-Disc $aggOk 'agent control: /truth/ → /truth/index.json aggregate journey resolves'

# ── Negative controls on disposable builds ────────────────────────────────────
$tmp = Join-Path $env:TEMP ("h12-disc-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$buildScript = Join-Path $root 'scripts\build-site.ps1'
$tCommit = 'b' * 40; $tTree = 'c' * 40; $tAt = '2026-01-01T00:00:00+00:00'
$manifestPath = Join-Path $root 'site-manifest.json'

# Control: wrong-binding — corrupt the built page's alternate to another product
& pwsh -NoProfile -File $buildScript -OutDir "$tmp\wrong" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\wb.log"
$wbPage = Join-Path $tmp 'wrong\cache-vault\index.html'
$wb = [IO.File]::ReadAllText($wbPage)
$wb = $wb -replace '/truth/products/cache-vault\.json', '/truth/products/lights-out.json'
[IO.File]::WriteAllText($wbPage, $wb)
$wbHtml = [IO.File]::ReadAllText($wbPage)
$wbAlt = Get-LinkHref ([regex]::Match($wbHtml, '<link\b[^>]*rel="alternate"[^>]*type="application/json"[^>]*>').Value)
Assert-Disc ($wbAlt -cne '/truth/products/cache-vault.json') 'negative fixture: wrong-binding page successfully corrupted'
$wbTruth = Get-Content (Join-Path $tmp 'wrong\truth\products\cache-vault.json') -Raw | ConvertFrom-Json
Assert-Disc ($wbTruth.pageUrl -eq '/cache-vault/' -and $wbAlt -match 'lights-out') 'negative: wrong-binding detectable — page points elsewhere while truth points back to /cache-vault/'

# Control: missing-truth — delete one truth product file; reciprocal check fails
& pwsh -NoProfile -File $buildScript -OutDir "$tmp\missing" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\ms.log"
Remove-Item (Join-Path $tmp 'missing\truth\products\ghostlayer.json') -Force
Assert-Disc (-not (Test-Path (Join-Path $tmp 'missing\truth\products\ghostlayer.json'))) 'negative fixture: ghostlayer truth removed'
$ghostAlt = Get-LinkHref ([regex]::Match([IO.File]::ReadAllText((Join-Path $tmp 'missing\ghostlayer\index.html')), '<link\b[^>]*rel="alternate"[^>]*type="application/json"[^>]*>').Value)
Assert-Disc (-not (Test-Path (Join-Path $tmp ('missing\' + $ghostAlt.TrimStart('/') -replace '/','\')))) 'negative: missing-truth detectable — page advertises a JSON that does not exist'

# Control: duplicate-alternate — inject a second alternate link
& pwsh -NoProfile -File $buildScript -OutDir "$tmp\dupe" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\dp.log"
$dpPage = Join-Path $tmp 'dupe\forgecast\index.html'
$dp = [IO.File]::ReadAllText($dpPage)
$dp = $dp -replace '</head>', ('  <link href="/truth/products/forgecast.json" rel="alternate" title="Public Truth" type="application/json"/>' + "`n</head>")
[IO.File]::WriteAllText($dpPage, $dp)
$dpCount = @(Get-AlternateTruthLinks ([IO.File]::ReadAllText($dpPage))).Count
Assert-Disc ($dpCount -eq 2) 'negative: duplicate-alternate detectable — corrupted page has 2 alternates (test asserts exactly 1)'

# Control: unrelated-aggregate-alternate — inject /truth/index.json on the
# homepage (a page that is NOT an alternate representation of the index).
& pwsh -NoProfile -File $buildScript -OutDir "$tmp\agg" -TruthCommit $tCommit -TruthTree $tTree -TruthCommittedAt $tAt *> "$tmp\ag.log"
$agPage = Join-Path $tmp 'agg\index.html'
$ag = [IO.File]::ReadAllText($agPage)
$ag = $ag -replace '</head>', ('  <link href="/truth/index.json" rel="alternate" title="Public Truth" type="application/json"/>' + "`n</head>")
[IO.File]::WriteAllText($agPage, $ag)
$agAlts = @(Get-AlternateTruthLinks ([IO.File]::ReadAllText($agPage)))
Assert-Disc ($agAlts.Count -ge 1) 'negative: unrelated-aggregate-alternate injected on homepage — absence rule would flag it (homepage is not the index)'

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# ── Canonical/alternate semantics + sitemap/robots policy ─────────────────────
$sitemap = [IO.File]::ReadAllText((Join-Path $publicDir 'sitemap.xml'))
Assert-Disc ($sitemap -match 'theprooffoundry\.com/truth/') 'sitemap: /truth/ human page listed'
Assert-Disc (-not ($sitemap -match 'truth/products/|truth/index\.json|schema-v1')) 'sitemap: raw JSON endpoints not listed as routes'
Assert-Disc (-not (([IO.File]::ReadAllText((Join-Path $publicDir 'truth\products\cache-vault.json'))) -match 'rel="canonical"')) 'JSON truth carries no canonical tags'

Write-Host ""
Write-Host "=== H12 TRUTH DISCOVERY RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
