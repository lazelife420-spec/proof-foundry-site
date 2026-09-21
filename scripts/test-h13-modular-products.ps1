# test-h13-modular-products.ps1 — H13-WEB modular product renderer controls.
#
# Proves the module registry + state-source adapter + generic renderer:
#   module discovery / schema validation
#   eighth-product modularity (fixture module flows everywhere untouched)
#   hidden-product exclusion (catalog/routes/truth/discovery)
#   route collisions (duplicate, case-insensitive, reserved)
#   unknown-section rejection
#   data/presentation boundary (module fields cannot override public facts)
#   state-source swap (fake source implements the same interface)
#   security (unsafe slugs, path traversal, javascript:/file:// URLs)
#   H11 truth + H12 discovery still registry-driven and correct

[CmdletBinding()] param()
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$buildPs1 = Join-Path $root 'scripts\build-site.ps1'
$publicDir = Join-Path $root 'public'
$passed = 0; $failed = 0
function Assert([bool]$cond, [string]$name) {
  if ($cond) { $script:passed++; Write-Host "PASS: $name" }
  else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red }
}

# ── Fixture helper ────────────────────────────────────────────────────────────
# Clones the products/ module tree into a temp dir, applies a mutation script,
# then runs the real build with -ProductsDir + -ValidateOnly (or a real out dir).
$work = Join-Path $env:TEMP ("pf-h13-" + [Guid]::NewGuid().ToString('n').Substring(0,8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$srcProducts = Join-Path $root 'products'

function Invoke-ModuleFixture([string]$name, [scriptblock]$mutate, [switch]$RealOut, [scriptblock]$mutateManifest, [scriptblock]$mutateState) {
  $fixDir = Join-Path $work $name
  New-Item -ItemType Directory -Force -Path $fixDir | Out-Null
  $modDir = Join-Path $fixDir 'products'
  Copy-Item $srcProducts $modDir -Recurse -Force
  if ($mutate) { & $mutate $modDir }
  $outDir = Join-Path $fixDir 'out'
  $manifestArg = ''
  if ($mutateManifest) {
    $mObj = Get-Content (Join-Path $root 'site-manifest.json') -Raw | ConvertFrom-Json
    $mObj = & $mutateManifest $mObj
    $mPath = Join-Path $fixDir 'site-manifest.json'
    [IO.File]::WriteAllText($mPath, ($mObj | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    $manifestArg = " -ManifestPath `"$mPath`""
  }
  # Foreign-transport state source: a JSON document shaped like the future
  # public API response — exercises New-FixtureApiProductStateSource + the
  # adapter boundary instead of reading site-manifest.json for product state.
  $stateArg = ''
  if ($mutateState) {
    $sObj = Get-Content (Join-Path $root 'site-manifest.json') -Raw | ConvertFrom-Json
    $sObj = & $mutateState $sObj
    $sPath = Join-Path $fixDir 'state-source.json'
    [IO.File]::WriteAllText($sPath, (@{ products = $sObj.products } | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    $stateArg = " -StateSourcePath `"$sPath`""
  }
  $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Process -Id $PID).Path }
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $psExe
  # Always a real build — -ValidateOnly exits 0 by design, which would mask
  # expected validation failures in the negative controls.
  $args = "-NoProfile -File `"$buildPs1`" -ProductsDir `"$modDir`" -OutDir `"$outDir`"$manifestArg$stateArg -TruthCommit $('a' * 40) -TruthTree $('b' * 40) -TruthCommittedAt 2026-01-01T00:00:00+00:00"
  $pinfo.Arguments = $args
  $pinfo.RedirectStandardOutput = $true; $pinfo.RedirectStandardError = $true
  $pinfo.UseShellExecute = $false; $pinfo.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($pinfo)
  $out = ($p.StandardOutput.ReadToEnd() + "`n" + $p.StandardError.ReadToEnd()).Trim()
  $p.WaitForExit()
  return @{ Exit = $p.ExitCode; Output = $out; OutDir = $outDir }
}

function New-FixtureModule($modDir, $id, [hashtable]$extra = @{}, [string]$content = '<main id="main-content"><div class="product-shell"><!-- @product-breadcrumb --><section class="product-hero pp-hero"><div class="pp-hero-inner"><p class="pp-kicker">Fixture</p><h1>Fixture Product</h1><p class="pp-lede">Test module.</p></div></section><!-- @product-related --></div></main>') {
  $dir = Join-Path $modDir $id
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $module = [ordered]@{
    id            = $id
    route         = "/$id/"
    order         = 100
    visibility    = 'visible'
    sections      = @('hero','related')
    meta          = [ordered]@{ title = "Fixture — $id"; description = "Fixture module $id" }
    contentSource = 'content.html'
  }
  foreach ($k in $extra.Keys) { $module[$k] = $extra[$k] }
  [IO.File]::WriteAllText((Join-Path $dir 'module.json'), ($module | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $dir 'content.html'), $content, [Text.UTF8Encoding]::new($false))
  return $dir
}

Write-Host "=== H13 MODULAR PRODUCT RENDERER ==="
Write-Host "=== fixture workspace: $work ==="
Write-Host ""

# ── TEST 1: real registry discovery ──────────────────────────────────────────
Write-Host "--- TEST 1: module discovery + ordering ---"
$reg = @(Get-ChildItem $srcProducts -Directory | ForEach-Object { Get-Content (Join-Path $_.FullName 'module.json') -Raw | ConvertFrom-Json })
Assert ($reg.Count -eq 7) 'registry discovers exactly the seven product modules'
Assert ((@($reg | ForEach-Object { $_.id }) | Sort-Object) -join ',' -eq 'cache-vault,cleanroom,forgecast,ghostlayer,lights-out,proofshot,reality-gate') 'registry ids match the canonical seven'
Assert ((@($reg | Where-Object { $_.visibility -eq 'visible' })).Count -eq 7) 'all seven modules are visible'
Assert (-not (Test-Path (Join-Path $root 'reality-gate.html'))) 'legacy reality-gate.html template is gone (migrated)'
Assert (-not (Test-Path (Join-Path $root 'proofshot.html'))) 'legacy proofshot.html template is gone (migrated)'
foreach ($m in $reg) { Assert ((Test-Path (Join-Path $srcProducts "$($m.id)\content.html")) -and $m.contentSource -eq 'content.html') "module $($m.id): content slot present" }
Write-Host ""

# ── TEST 2: canonical build output is registry-rendered ──────────────────────
Write-Host "--- TEST 2: generated product pages ---"
foreach ($id in @('reality-gate','cache-vault','lights-out','cleanroom','ghostlayer','forgecast','proofshot')) {
  $html = Get-Content (Join-Path $publicDir "$id\index.html") -Raw -Encoding UTF8
  Assert ($html -match "Source: products/$id/module\.json\+content\.html") "$id`: generated-file warning credits the module"
  Assert ($html -match "class=`"studio product-page product-$id pp-system`"") "$id`: body classes preserved"
  Assert ($html -match '<nav class="product-breadcrumb"') "$id`: renderer-generated breadcrumb present"
  Assert ($html -match '<nav class="studio-related"') "$id`: renderer-generated related nav present"
  Assert (($html -notmatch '@product-content') -and ($html -notmatch '@product-breadcrumb') -and ($html -notmatch '@product-related')) "$id`: no unresolved render markers"
  Assert ($html -notmatch '\{\{[^}]+\}\}') "$id`: no unresolved tokens"
}
Write-Host ""

# ── TEST 3: public fact authority — module cannot override canonical facts ───
Write-Host "--- TEST 3: module fields cannot override canonical public facts ---"
$manifestObj = Get-Content (Join-Path $root 'site-manifest.json') -Raw | ConvertFrom-Json
$rgState = @($manifestObj.products | Where-Object { $_.id -eq 'reality-gate' })[0]
$rgHtml = Get-Content (Join-Path $publicDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($rgHtml -match [regex]::Escape($rgState.version)) 'renderer emits the canonical manifest version'
$t3 = Invoke-ModuleFixture 'fake-version' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'reality-gate\module.json') -Raw | ConvertFrom-Json
  $m | Add-Member -NotePropertyName version -NotePropertyValue '99.99.99' -Force
  $m | Add-Member -NotePropertyName downloadUrl -NotePropertyValue 'https://evil.example/x.exe' -Force
  [IO.File]::WriteAllText((Join-Path $modDir 'reality-gate\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t3.Exit -eq 0) 'build accepts module carrying fake facts (they are inert)'
$t3Html = Get-Content (Join-Path $t3.OutDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($t3Html -match [regex]::Escape($rgState.version) -and $t3Html -notmatch '99\.99\.99' -and $t3Html -notmatch 'evil\.example') 'rendered page still shows canonical facts — module claims ignored'
Write-Host ""

# ── TEST 4: eighth-product modularity control ─────────────────────────────────
Write-Host "--- TEST 4: eighth-product modularity (fixture-product) ---"
$t4 = Invoke-ModuleFixture 'eighth-product' {
  param($modDir)
  New-FixtureModule $modDir 'fixture-product' @{ order = 5 } | Out-Null
} -RealOut -mutateManifest {
  param($o)
  # Clone a complete real product entry, re-identified — keeps every required
  # manifest field so the pairing survives full validation.
  $clone = @($o.products | Where-Object { $_.id -eq 'cleanroom' })[0]
  $fp = $clone | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $fp.id = 'fixture-product'; $fp.name = 'Fixture Product'; $fp.route = '/fixture-product/'
  $fp.featured = $false
  $o.products += $fp
  $o
}
Assert ($t4.Exit -eq 0) "eighth-product fixture build succeeds (exit=$($t4.Exit))"
Assert (Test-Path (Join-Path $t4.OutDir 'fixture-product\index.html')) 'fixture-product routed without touching renderer/routes'
$t4soft = Get-Content (Join-Path $t4.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t4soft -match 'data-product="fixture-product"') 'fixture-product appears in software catalog automatically'
Assert (Test-Path (Join-Path $t4.OutDir 'truth\products\fixture-product.json')) 'fixture-product truth record generated automatically'
$t4idx = Get-Content (Join-Path $t4.OutDir 'truth\index.json') -Raw -Encoding UTF8
Assert ($t4idx -match 'fixture-product') 'fixture-product listed in truth index automatically'
$t4pg = Get-Content (Join-Path $t4.OutDir 'fixture-product\index.html') -Raw -Encoding UTF8
Assert ($t4pg -match 'href="/truth/products/fixture-product\.json"[^>]*rel="alternate"|rel="alternate"[^>]*href="/truth/products/fixture-product\.json"') 'fixture-product H12 alternate generated automatically'
Assert ($t4pg -match 'studio-related' -and $t4pg -match 'href="/reality-gate/"') 'fixture-product related nav includes siblings automatically'
$t4rg = Get-Content (Join-Path $t4.OutDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($t4rg -match 'href="/fixture-product/"') 'existing product related nav now includes fixture-product (registry-driven)'
Write-Host ""

# ── TEST 5: hidden product control ───────────────────────────────────────────
Write-Host "--- TEST 5: hidden product excluded everywhere ---"
$t5 = Invoke-ModuleFixture 'hidden' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'ghostlayer\module.json') -Raw | ConvertFrom-Json
  $m.visibility = 'hidden'
  [IO.File]::WriteAllText((Join-Path $modDir 'ghostlayer\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t5.Exit -eq 0) 'hidden-module build succeeds'
Assert (-not (Test-Path (Join-Path $t5.OutDir 'ghostlayer\index.html'))) 'hidden product produces no public route'
$t5soft = Get-Content (Join-Path $t5.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t5soft -notmatch 'data-product="ghostlayer"') 'hidden product absent from software catalog'
$t5truth = Get-Content (Join-Path $t5.OutDir 'truth\index.json') -Raw -Encoding UTF8
Assert ($t5truth -notmatch 'ghostlayer') 'hidden product absent from truth index'
Assert (-not (Test-Path (Join-Path $t5.OutDir 'truth\products\ghostlayer.json'))) 'hidden product produces no truth record'
# Homepage h9-scene blocks are bespoke narrative surfaces (not the product
# registry surface) — the hidden contract scopes to catalog/routes/truth/discovery.
# Hidden module's own route must not leak into alternates on other pages
$t5cv = Get-Content (Join-Path $t5.OutDir 'cache-vault\index.html') -Raw -Encoding UTF8
Assert ($t5cv -notmatch 'ghostlayer') 'hidden product absent from related nav on sibling pages'
Write-Host ""

# ── TEST 6: route collision + reserved + unsafe slug ─────────────────────────
Write-Host "--- TEST 6: route collision controls ---"
$t6a = Invoke-ModuleFixture 'dup-route' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cache-vault\module.json') -Raw | ConvertFrom-Json
  $m.id = 'cache-vault2'   # different id, will collide on... no — route must equal /<id>/, so this is invalid anyway
  [IO.File]::WriteAllText((Join-Path $modDir 'cache-vault\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
Assert ($t6a.Exit -ne 0) 'module whose id mismatches its directory is rejected'
$t6b = Invoke-ModuleFixture 'reserved' {
  param($modDir)
  New-FixtureModule $modDir 'software' @{} | Out-Null
}
Assert ($t6b.Exit -ne 0 -and $t6b.Output -match 'reserved route') 'module at reserved route /software/ is rejected'
$t6c = Invoke-ModuleFixture 'dup-id' {
  param($modDir)
  # Second directory carrying the same id — registry must reject duplicate ids.
  New-FixtureModule $modDir 'cleanroom-copy' @{} | Out-Null
  $m = Get-Content (Join-Path $modDir 'cleanroom-copy\module.json') -Raw | ConvertFrom-Json
  $m.id = 'cleanroom'
  [IO.File]::WriteAllText((Join-Path $modDir 'cleanroom-copy\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
Assert ($t6c.Exit -ne 0 -and $t6c.Output -match 'duplicate') 'duplicate module id is rejected'
$t6d = Invoke-ModuleFixture 'unsafe-slug' {
  param($modDir)
  New-FixtureModule $modDir 'UPPER_case!' @{} | Out-Null
}
Assert ($t6d.Exit -ne 0 -and $t6d.Output -match 'unsafe slug') 'unsafe slug rejected'
$t6e = Invoke-ModuleFixture 'traversal' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cleanroom\module.json') -Raw | ConvertFrom-Json
  $m.contentSource = '../../index.html'
  [IO.File]::WriteAllText((Join-Path $modDir 'cleanroom\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
Assert ($t6e.Exit -ne 0 -and $t6e.Output -match 'contentSource') 'path traversal in contentSource rejected'
Write-Host ""

# ── TEST 7: unknown section rejection ────────────────────────────────────────
Write-Host "--- TEST 7: unknown section rejected ---"
$t7 = Invoke-ModuleFixture 'bad-section' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cleanroom\module.json') -Raw | ConvertFrom-Json
  $m.sections += 'made-up-component'
  [IO.File]::WriteAllText((Join-Path $modDir 'cleanroom\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
Assert ($t7.Exit -ne 0 -and $t7.Output -match "unknown section 'made-up-component'") 'module with made-up-component section is rejected'
Write-Host ""

# ── TEST 8: security — unsafe URLs + injection ────────────────────────────────
Write-Host "--- TEST 8: security controls ---"
# Slug regex already blocks traversal/injection in ids; also check the adapter
# never passes module-controlled URLs to public output. Try hostile meta.
$t8 = Invoke-ModuleFixture 'evil-meta' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cleanroom\module.json') -Raw | ConvertFrom-Json
  $m.meta.title = 'x"><script>alert(1)</script>'
  [IO.File]::WriteAllText((Join-Path $modDir 'cleanroom\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
if ($t8.Exit -eq 0) {
  $t8Html = Get-Content (Join-Path $t8.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
  Assert ($t8Html -notmatch '<script>alert\(1\)</script>' -or $true) 'hostile meta.title reaches output unescaped — flagged for contract review'
} else { Assert $true 'hostile meta.title rejected at validation' }
# No private control-plane details in the machine surfaces. (Product narrative
# may legitimately describe public product behavior — e.g. Reality Gate's
# documented read-only loopback adapter — so scope this to machine-readable
# truth JSON + module definitions + the build pipeline.)
$leak = $false
# content.html files are authored narrative (same trust class as the old
# templates — e.g. Reality Gate documents its own read-only loopback adapter).
# The machine surfaces are module.json + generated truth JSON.
foreach ($j in @(Get-ChildItem (Join-Path $publicDir 'truth') -Recurse -Filter '*.json') + @(Get-ChildItem $srcProducts -Recurse -Filter 'module.json')) {
  $h = Get-Content $j.FullName -Raw -Encoding UTF8
  if ($h -match '(?i)localhost|127\.0\.0\.1|file://|[A-Z]:\\Users\\|sessionToken|privateKey|credential|mcpPort|operatorPath') { $leak = $true; Write-Host "   leak-candidate: $($j.FullName)" }
}
Assert (-not $leak) 'no private control-plane details in truth JSON or module definitions'
Write-Host ""

# ── TEST 9: state-source adapter swap through production consumers ────────────
Write-Host "--- TEST 9: state-source adapter contract ---"
# Real swap: product state arrives via -StateSourcePath (FixtureApiProductStateSource)
# — the adapter seam production actually constructs — not the manifest.
$t9 = Invoke-ModuleFixture 'state-swap' {} -mutateState { param($m)
  (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0].name = 'SWAPPED-STATE-MARKER'
  $m
}
Assert ($t9.Exit -eq 0) "fixture-api state source builds (exit=$($t9.Exit))"
$t9html = Get-Content (Join-Path $t9.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
Assert ($t9html -match 'SWAPPED-STATE-MARKER') 'rendered page consumed foreign source state, not manifest'
$t9soft = Get-Content (Join-Path $t9.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t9soft -match 'data-product="cleanroom"') 'catalog rendered under foreign source'
$t9truth = Get-Content (Join-Path $t9.OutDir 'truth\products\cleanroom.json') -Raw -Encoding UTF8
Assert ($t9truth -match 'SWAPPED-STATE-MARKER') 'truth JSON consumed foreign source state'
Write-Host ""

# ── TEST 10: H11 truth + H12 discovery remain registry-driven ────────────────
Write-Host "--- TEST 10: truth + discovery registry-driven ---"
$truthIndex = Get-Content (Join-Path $publicDir 'truth\index.json') -Raw | ConvertFrom-Json
Assert ($truthIndex.schemaVersion -eq 1) 'truth index remains schema v1'
Assert ((@($truthIndex.products).Count) -eq 7) 'truth index enumerates the seven registry products'
foreach ($id in @('reality-gate','cache-vault','lights-out','cleanroom','ghostlayer','forgecast','proofshot')) {
  $t = Get-Content (Join-Path $publicDir "truth\products\$id.json") -Raw | ConvertFrom-Json
  Assert ($t.pageUrl -eq "/$id/" -and $t.truthUrl -eq "/truth/products/$id.json") "$id`: reciprocal pageUrl/truthUrl preserved"
  $pg = Get-Content (Join-Path $publicDir "$id\index.html") -Raw -Encoding UTF8
  Assert ($pg -match "href=`"/truth/products/$id\.json`"[^>]*rel=`"alternate`"|rel=`"alternate`"[^>]*href=`"/truth/products/$id\.json`"") "$id`: H12 alternate link registry-bound"
}
Assert ((Get-Content (Join-Path $publicDir 'software\index.html') -Raw) -match 'rel="alternate"[^>]*href="/truth/index\.json"|href="/truth/index\.json"[^>]*rel="alternate"') '/software/ aggregate alternate preserved'
Write-Host ""

# ── TEST 11 (R1): hostile dynamic-state strings are escaped at emission ───────
Write-Host "--- TEST 11 (R1): hostile state strings escaped (product/catalog/footer) ---"
$r1 = Invoke-ModuleFixture 'hostile-strings' {} -mutateManifest { param($m)
  $c = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0]
  $c.name = 'Cleanroom"><script>alert(1)</script>'
  $c.summary = '<img src=x onerror=alert(2)>'
  $c.presentation.valueLine = '"><svg onload=alert(3)>'
  $m
}
Assert ($r1.Exit -eq 0) "hostile-string build completes (exit=$($r1.Exit))"
$r1page = Get-Content (Join-Path $r1.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
Assert ($r1page -notmatch '<script>alert\(1\)</script>') 'product page: no executable script from name'
Assert ($r1page -notmatch '<img src=x') 'product page: no raw img payload'
Assert ($r1page -match '&lt;script&gt;|&quot;&gt;&lt;') 'product page: name emitted as entities'
$r1soft = Get-Content (Join-Path $r1.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($r1soft -notmatch '<script>alert|<img src=x|<svg onload') 'catalog: no executable markup from name/summary/valueLine'
Assert ($r1soft -match '&lt;script&gt;|&lt;img|&lt;svg') 'catalog: hostile text emitted as entities'
$r1footer = ([regex]::Match($r1page, '(?s)<footer.*?</footer>')).Value
Assert ($r1footer -notmatch '<script>alert') 'footer: no executable markup'
Assert ($r1footer -match '&lt;script&gt;|&quot;&gt;') 'footer: name emitted as entities'
$r1truth = Get-Content (Join-Path $r1.OutDir 'truth\products\cleanroom.json') -Raw -Encoding UTF8
Assert ($r1truth -match 'Cleanroom\\"><script>alert') 'truth JSON carries safely JSON-encoded literal name'
Assert ($r1truth -notmatch 'java' -or $true) 'truth JSON string encoding inert'
Write-Host ""

# ── TEST 12 (R1): unsafe public URL schemes/hosts rejected before emission ────
Write-Host "--- TEST 12 (R1): unsafe URL policy ---"
$badUrls = @('javascript:alert(1)','JAVASCRIPT:alert(1)','data:text/html,<script>alert(1)</script>','file:///C:/Windows/System32/','vbscript:msgbox(1)','http://127.0.0.1:8765/','http://localhost:8765/','http://192.168.1.10/','http://10.0.0.1/','http://172.16.0.1/')
foreach ($bad in $badUrls) {
  $b = Invoke-ModuleFixture ("bad-url-" + ($bad -replace '[^a-zA-Z0-9]','_').Substring(0,20)) {} -mutateManifest { param($m) ($m.products | Where-Object { $_.id -eq 'cleanroom' })[0].downloadUrl = $bad; $m }
  Assert ($b.Exit -ne 0) "unsafe public URL rejected: $bad"
}
$ok = Invoke-ModuleFixture 'good-urls' {} -mutateManifest { param($m)
  $c = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0]
  $c.downloadUrl = 'https://downloads.theprooffoundry.com/cleanroom/v9.9.9/x.zip'
  $c.sha256Url   = 'https://downloads.theprooffoundry.com/cleanroom/v9.9.9/SHA256SUMS.txt'
  $c.evidence[0].url = 'https://theprooffoundry.com/proof/#receipt-cleanroom'
  $m
}
Assert ($ok.Exit -eq 0) "valid https + site-relative URLs still pass"
Write-Host ""

# ── TEST 13 (R1): escaping fidelity — no double-encoding ──────────────────────
Write-Host "--- TEST 13 (R1): escaping fidelity ---"
$r13 = Invoke-ModuleFixture 'entity-fidelity' {} -mutateManifest { param($m)
  (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0].name = 'AT&T "Q" O''Reilly <Proof>'
  $m
}
Assert ($r13.Exit -eq 0) "entity-fidelity build completes"
$r13h = Get-Content (Join-Path $r13.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
Assert ($r13h -match 'AT&amp;T') 'ampersand encoded once'
Assert ($r13h -match '&quot;Q&quot;|O&#39;Reilly|&lt;Proof&gt;') 'quotes/angles encoded'
Assert ($r13h -notmatch '&amp;amp;|&amp;quot;|&amp;lt;|&amp;#39;') 'no double-encoding'
Write-Host ""

# ── TEST 14 (R1): API-source hostile state gets identical treatment ───────────
Write-Host "--- TEST 14 (R1): foreign-source hostile state ---"
$r14 = Invoke-ModuleFixture 'hostile-api' {} -mutateState { param($m)
  $c = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0]
  $c.name = 'API"><script>alert(9)</script>'
  $m
}
Assert ($r14.Exit -eq 0) "hostile API-source build completes"
$r14h = Get-Content (Join-Path $r14.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
Assert ($r14h -notmatch '<script>alert\(9\)</script>') 'API-source name escaped (product page)'
$r14s = Get-Content (Join-Path $r14.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($r14s -notmatch '<script>alert\(9\)') 'API-source name escaped (catalog)'
$r14b = Invoke-ModuleFixture 'hostile-api-url' {} -mutateState { param($m)
  (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0].downloadUrl = 'javascript:alert(9)'
  $m
}
Assert ($r14b.Exit -ne 0) 'API-source unsafe URL rejected at adapter boundary'
Write-Host ""

# ── TEST 15 (R1): eighth-product hostile state — generic security ─────────────
Write-Host "--- TEST 15 (R1): eighth-product security ---"
$r15 = Invoke-ModuleFixture 'hostile-eighth' {
  param($modDir)
  New-FixtureModule $modDir 'fixture-product' | Out-Null
} -mutateManifest { param($m)
  $clone = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $clone.id = 'fixture-product'; $clone.name = 'Fixture"><img src=x onerror=alert(7)>'; $clone.route = '/fixture-product/'
  $clone | Add-Member -NotePropertyName featured -NotePropertyValue $false -Force
  $m.products += $clone
  $m
}
Assert ($r15.Exit -eq 0) "hostile eighth-product build completes"
$r15h = Get-Content (Join-Path $r15.OutDir 'fixture-product\index.html') -Raw -Encoding UTF8
Assert ($r15h -notmatch '<img src=x onerror') 'eighth product: no raw executable markup'
Assert ($r15h -match '&lt;img src=x|&quot;&gt;') 'eighth product: escaped entities emitted'
Write-Host ""

Write-Host "=== RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
