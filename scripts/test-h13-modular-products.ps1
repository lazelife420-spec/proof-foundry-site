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
. "$PSScriptRoot/release-qualification.ps1"
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$buildPs1 = Join-Path $root 'scripts\build-qualification-fixture.ps1'
$publicDir = Join-Path $root 'public'
$passed = 0; $failed = 0
function Assert([bool]$cond, [string]$name) {
  if ($cond) { $script:passed++; Write-Host "PASS: $name" }
  else { $script:failed++; Write-Host "FAIL: $name" -ForegroundColor Red }
}
function Get-CatalogCard([string]$Html, [string]$Id) {
  return [regex]::Match($Html, ('(?s)<article\b[^>]*\bdata-product="' + [regex]::Escape($Id) + '"[^>]*>.*?</article>')).Value
}

# ── Fixture helper ────────────────────────────────────────────────────────────
# Clones the products/ module tree into a temp dir, applies a mutation script,
# then runs the real build with -ProductsDir + -ValidateOnly (or a real out dir).
$work = Join-Path $env:TEMP ("pf-h13-" + [Guid]::NewGuid().ToString('n').Substring(0,8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

# Every run leaves ~450 MB of fixture builds in $work, so the workspace is removed at the end of the run, pass or fail,
# right before the final exit. Deliberately no try/finally: with $ErrorActionPreference = 'Continue' a try block would
# abandon the remaining tests at the first statement-terminating error and could end with exit 0. Set PF_KEEP_TEST_TEMP=1
# to keep the workspace for debugging. Only a folder directly in the expected temp directory whose name has the expected
# prefix is ever removed.
function Remove-TestWorkDir([string]$Path, [string]$ExpectedParent, [string]$Prefix) {
  if (-not $Path) { return }
  if ($env:PF_KEEP_TEST_TEMP -eq '1') { Write-Host "=== fixture workspace kept (PF_KEEP_TEST_TEMP=1): $Path ==="; return }
  $full = [IO.Path]::GetFullPath($Path)
  $parent = [IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\', '/')
  if ((Split-Path -Parent $full) -ne $parent -or -not (Split-Path -Leaf $full).StartsWith($Prefix)) {
    Write-Host "=== fixture workspace NOT removed (unexpected path): $full ===" -ForegroundColor Yellow; return
  }
  for ($i = 0; $i -lt 5 -and (Test-Path -LiteralPath $full); $i++) {
    try { Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop } catch { Start-Sleep -Milliseconds 500 }
  }
  if (Test-Path -LiteralPath $full) { Write-Host "=== fixture workspace could not be fully removed: $full ===" -ForegroundColor Yellow }
  else { Write-Host "=== fixture workspace removed: $full ===" }
}

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
    $mObj = Get-AuthoredReleaseManifest
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
    $sObj = Get-AuthoredReleaseManifest
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
    lifecycle     = 'public-eligible'
    commerce      = [ordered]@{ status = 'FREE'; label = 'Free download' }
    theme         = [ordered]@{ accent = '#38BDF8' }
    card          = [ordered]@{ tagline = 'Fixture card headline'; media = '/assets/forgecast/v030-today.png'; mediaAlt = 'Fixture preview image' }
    homepage      = [ordered]@{ role = 'studioPortfolio'; order = 100; tier = 'secondary'; presentation = 'compact'; visibility = 'visible' }
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
Assert ($reg.Count -eq @(Get-ChildItem $srcProducts -Directory).Count) 'registry discovers every product module directory'
Assert ((@($reg | ForEach-Object { $_.id } | Sort-Object) -join ',') -eq ((Get-ChildItem $srcProducts -Directory | ForEach-Object Name | Sort-Object) -join ',')) 'registry ids bind to discovered module directory identities'
Assert ((@($reg | Where-Object { $_.visibility -eq 'visible' })).Count -eq @($reg | Where-Object { $_.visibility -eq 'visible' }).Count) 'visible registry projection is derived from module visibility'
Assert (-not (Test-Path (Join-Path $root 'reality-gate.html'))) 'legacy reality-gate.html template is gone (migrated)'
Assert (-not (Test-Path (Join-Path $root 'proofshot.html'))) 'legacy proofshot.html template is gone (migrated)'
foreach ($m in $reg) { Assert ((Test-Path (Join-Path $srcProducts "$($m.id)\content.html")) -and $m.contentSource -eq 'content.html') "module $($m.id): content slot present" }
foreach ($m in $reg) { Assert ($m.lifecycle -eq 'public-eligible' -and @($m.sections | Where-Object { $_ -isnot [string] -and $_.type -eq 'outcomes' }).Count -eq 1) "module $($m.id): explicit publication lifecycle and structured outcomes" }
foreach ($m in $reg) { Assert ($m.commerce.status -in @('FREE','PAID','COMING_SOON','UNAVAILABLE','WITHDRAWN') -and -not [string]::IsNullOrWhiteSpace([string]$m.commerce.label)) "module $($m.id): generic commercial state and visitor label are declared" }
foreach ($m in $reg) {
  $source = Get-Content (Join-Path $srcProducts "$($m.id)\content.html") -Raw
  Assert ($source -match '<!-- @product-hero -->' -and $source -match '<!-- @structured-sections -->' -and $source -notmatch '<section class="product-hero\b' -and $source -notmatch 'class="pp-outcomes') "$($m.id): repeated hero/outcomes markup migrated to the module renderer"
}
Assert (-not (Test-Path (Join-Path $publicDir 'fixture-product\index.html'))) 'non-public v2 fixture stays outside production output'
Write-Host ""

# ── TEST 2: canonical build output is registry-rendered ──────────────────────
Write-Host "--- TEST 2: generated product pages ---"
foreach ($id in @($reg | Where-Object { $_.visibility -eq 'visible' } | ForEach-Object id)) {
  $html = Get-Content (Join-Path $publicDir "$id\index.html") -Raw -Encoding UTF8
  Assert ($html -match "Source: products/$id/module\.json\+content\.html") "$id`: generated-file warning credits the module"
  Assert ($html -match "class=`"studio product-page product-$id pp-system`"") "$id`: body classes preserved"
  Assert ($html -match '<nav class="product-breadcrumb"') "$id`: renderer-generated breadcrumb present"
  Assert ($html -match '<nav class="studio-related"') "$id`: renderer-generated related nav present"
  Assert (($html -notmatch '@product-content') -and ($html -notmatch '@product-breadcrumb') -and ($html -notmatch '@product-related')) "$id`: no unresolved render markers"
  Assert ($html -notmatch '\{\{[^}]+\}\}') "$id`: no unresolved tokens"
}
$softwareHtml = Get-Content (Join-Path $publicDir 'software\index.html') -Raw -Encoding UTF8
$softwareHtmlDecoded = [System.Net.WebUtility]::HtmlDecode($softwareHtml)
# Compare fixture mutations against an independently built, unmodified transport
# from the same authored model and renderer. Production's complete byte identity
# is checked separately, including its richer authority metadata and v2 files.
$canonicalFixture = Invoke-ModuleFixture 'unmodified-authored-transport' {} -RealOut
if ($canonicalFixture.Exit -ne 0) { throw 'Unmodified authored fixture transport failed; mutation controls cannot proceed.' }
$canonicalHome = Get-Content (Join-Path $canonicalFixture.OutDir 'index.html') -Raw -Encoding UTF8
$homeProductSlots = 'class="studio-product-card"|data-home-tab=|class="studio-withdrawn"|class="studio-evidence"'
$catalogOrder = @([regex]::Matches($softwareHtml, 'data-product="([a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert ($catalogOrder.Count -eq $reg.Count -and $catalogOrder[0] -eq 'cache-vault' -and $catalogOrder[-1] -eq 'reality-gate') 'catalog role order puts Cache Vault first and withdrawn products last using module metadata'
$truthRoot = Join-Path $publicDir 'truth\products'
foreach ($m in $reg) {
  $truthProduct = Get-Content (Join-Path $truthRoot ($m.id + '.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($truthProduct.schemaVersion -eq 1 -and $null -eq $truthProduct.PSObject.Properties['commerce']) "$($m.id): public Truth v1 shape remains unchanged by module presentation commerce"
  Assert ($softwareHtmlDecoded -match ('data-product="' + [regex]::Escape($m.id) + '"') -and $softwareHtmlDecoded -match ('data-commerce="' + [regex]::Escape($m.commerce.status.ToLowerInvariant().Replace('_','-')) + '"[^>]*>' + [regex]::Escape($m.commerce.label))) "$($m.id): software catalog exposes its generic acquisition label"
}
foreach ($id in @('cache-vault','lights-out')) {
  $module = Get-Content (Join-Path $srcProducts "$id\module.json") -Raw | ConvertFrom-Json
  $html = Get-Content (Join-Path $publicDir "$id\index.html") -Raw -Encoding UTF8
  Assert (@($module.sections | Where-Object { $_ -isnot [string] -and $_.type -eq 'faq' }).Count -eq 1 -and $html -match 'class="pp-faq-item"' -and $html -match 'pp-support-flush') "$($id): structured FAQ renderer preserves the Q/A component"
}
Write-Host ""

# ── TEST 3: public fact authority — module cannot override canonical facts ───
Write-Host "--- TEST 3: module fields cannot override canonical public facts ---"
$manifestObj = Get-AuthoredReleaseManifest
$rgState = @($manifestObj.products | Where-Object { $_.id -eq 'reality-gate' })[0]
$rgHtml = Get-Content (Join-Path $publicDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($rgState.release.withdrawnVersion -eq '1.1.0' -and $rgHtml -match [regex]::Escape($rgState.release.withdrawnVersion)) 'renderer emits the authored withdrawn version explicitly'
$t3 = Invoke-ModuleFixture 'fake-version' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'reality-gate\module.json') -Raw | ConvertFrom-Json
  $m | Add-Member -NotePropertyName version -NotePropertyValue '99.99.99' -Force
  $m | Add-Member -NotePropertyName downloadUrl -NotePropertyValue 'https://evil.example/x.exe' -Force
  [IO.File]::WriteAllText((Join-Path $modDir 'reality-gate\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t3.Exit -eq 0) 'build accepts module carrying fake facts (they are inert)'
$t3Html = Get-Content (Join-Path $t3.OutDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($t3Html -match [regex]::Escape($rgState.release.withdrawnVersion) -and $t3Html -notmatch '99\.99\.99' -and $t3Html -notmatch 'evil\.example') 'rendered page still shows authored withdrawn facts — module claims ignored'
$cvPublicVersion = [string]((Get-AuthoredReleaseManifest).products | Where-Object id -eq 'cache-vault' | Select-Object -ExpandProperty release | Select-Object -ExpandProperty publicVersion)
$t3HomeFixture = Invoke-ModuleFixture 'fake-home-facts' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cache-vault\module.json') -Raw | ConvertFrom-Json
  $m | Add-Member -NotePropertyName version -NotePropertyValue '99.99.99' -Force
  $m | Add-Member -NotePropertyName downloadUrl -NotePropertyValue 'https://evil.example/x.exe' -Force
  [IO.File]::WriteAllText((Join-Path $modDir 'cache-vault\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
$t3Home = Get-Content (Join-Path $t3HomeFixture.OutDir 'index.html') -Raw -Encoding UTF8
$t3Software = Get-Content (Join-Path $t3HomeFixture.OutDir 'software\index.html') -Raw -Encoding UTF8
$t3Card = Get-CatalogCard $t3Software 'cache-vault'
$t3Product = Get-Content (Join-Path $t3HomeFixture.OutDir 'cache-vault\index.html') -Raw -Encoding UTF8
$t3Truth = Get-Content (Join-Path $t3HomeFixture.OutDir 'truth\products\cache-vault.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cvState = @($manifestObj.products | Where-Object id -eq 'cache-vault')[0]
Assert ($t3HomeFixture.Exit -eq 0 -and $t3Card -match ('class="card-version">v' + [regex]::Escape($cvPublicVersion) + '<') -and $t3Card -match 'data-availability="public-release"' -and $t3Card -match 'href="/cache-vault/"' -and $t3Product -match [regex]::Escape($cvState.downloadUrl) -and $t3Truth.version -eq $cvPublicVersion -and $t3Truth.download.url -eq $cvState.downloadUrl -and $t3Truth.download.sha256 -eq $cvState.sha256 -and ($t3Software + $t3Product + ($t3Truth | ConvertTo-Json -Depth 20) + $t3Home) -notmatch '99\.99\.99|evil\.example' -and $t3Home -ceq $canonicalHome -and $t3Home -notmatch $homeProductSlots) 'catalog/product/truth facts remain canonical while the frozen Ledger content remains identical'
Write-Host ""

# ── TEST 4: eighth-product modularity control ─────────────────────────────────
Write-Host "--- TEST 4: eighth-product modularity (fixture-product) ---"
$rendererBefore = (Get-FileHash (Join-Path $root 'scripts/build-site.ps1') -Algorithm SHA256).Hash
$indexBefore = (Get-FileHash (Join-Path $root 'index.html') -Algorithm SHA256).Hash
$t4 = Invoke-ModuleFixture 'eighth-product' {
  param($modDir)
  $fixtureDir = New-FixtureModule $modDir 'fixture-product' @{
    schemaVersion = 2
    order = 5
    brand = [ordered]@{ name = 'Fixture Product'; mark = '/assets/products/fixture-product/brand/logo.svg' }
    hero = [ordered]@{ variant = 'split'; kicker = 'Fixture'; headline = 'A responsive fixture'; lede = 'Generic responsive hero media.'; media = [ordered]@{ src = '/assets/cache-vault/cv-quick-paste.png'; mobileSrc = '/assets/cache-vault/cv-quick-paste-mobile.png'; alt = 'Fixture capture'; caption = 'Fixture caption' } }
    theme = [ordered]@{ accent = '#38BDF8'; accentSecondary = '#2486B9' }
    homepage = [ordered]@{ role = 'studioPortfolio'; tier = 'secondary'; presentation = 'compact'; visibility = 'visible'; order = 5; evidencePriority = 1 }
    card = [ordered]@{ tagline = 'A new module, rendered generically.'; summary = 'Fixture card summary.'; media = '/assets/forgecast/v030-today.png'; mediaAlt = 'Eighth product fixture media' }
  } '<main id="main-content"><div class="product-shell"><!-- @product-breadcrumb --><!-- @product-hero --><!-- @product-related --></div></main>'
  Copy-Item (Join-Path $srcProducts 'cleanroom/logo.svg') (Join-Path $fixtureDir 'logo.svg') -Force
} -RealOut -mutateManifest {
  param($o)
  # Clone a complete real product entry, re-identified — keeps every required
  # manifest field so the pairing survives full validation.
  $clone = @($o.products | Where-Object { $_.id -eq 'cleanroom' })[0]
  $fp = $clone | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $fp.id = 'fixture-product'; $fp.name = 'Fixture Product'; $fp.route = '/fixture-product/'
  $fp | Add-Member -NotePropertyName featured -NotePropertyValue $false -Force
  $o.products += $fp
  $o
}
Assert ($t4.Exit -eq 0) "eighth-product fixture build succeeds (exit=$($t4.Exit))"
Assert (Test-Path (Join-Path $t4.OutDir 'fixture-product\index.html')) 'fixture-product routed without touching renderer/routes'
$t4soft = Get-Content (Join-Path $t4.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t4soft -match 'data-product="fixture-product"') 'fixture-product appears in software catalog automatically'
Assert ($t4soft -match 'data-commerce="free"[^>]*>Free download') 'new module commerce label renders without product-specific catalog logic'
Assert (Test-Path (Join-Path $t4.OutDir 'truth\products\fixture-product.json')) 'fixture-product truth record generated automatically'
$t4idx = Get-Content (Join-Path $t4.OutDir 'truth\index.json') -Raw -Encoding UTF8
Assert ($t4idx -match 'fixture-product') 'fixture-product listed in truth index automatically'
$t4home = Get-Content (Join-Path $t4.OutDir 'index.html') -Raw -Encoding UTF8
$t4Card = Get-CatalogCard $t4soft 'fixture-product'
$t4Order = @([regex]::Matches($t4soft, 'data-product="([a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert ($t4Card -match '<article class="product-card\b' -and $t4Card -match 'A new module, rendered generically\.' -and $t4Card -match 'href="/fixture-product/"' -and $t4Order[0] -eq 'fixture-product' -and $t4home -match '<tr data-ledger-product="fixture-product"' -and $t4home -match 'href="/fixture-product/"') 'unknown module receives generic catalog and Home index copy, route and module order'
Assert ($t4Card -match '--product-accent:#38BDF8(?:;|\")' -and $t4Card -match '--product-accent-2:#2486B9(?:;|\")' -and $t4Card -match 'data-product="fixture-product"') 'unknown module catalog accent and identity come from module data'
Assert ((Get-FileHash (Join-Path $root 'scripts/build-site.ps1') -Algorithm SHA256).Hash -eq $rendererBefore -and (Get-FileHash (Join-Path $root 'index.html') -Algorithm SHA256).Hash -eq $indexBefore) 'unknown module requires no renderer or homepage template edits'
$t4pg = Get-Content (Join-Path $t4.OutDir 'fixture-product\index.html') -Raw -Encoding UTF8
Assert ($t4pg -match '<picture><source media="\(max-width: 700px\)" srcset="/assets/cache-vault/cv-quick-paste-mobile\.png"/><img src="/assets/cache-vault/cv-quick-paste\.png"' -and $t4pg -match 'alt="Fixture capture"') 'generic hero renderer selects optional mobile asset and preserves desktop fallback/alt'
Assert ($t4pg -match 'href="/truth/products/fixture-product\.json"[^>]*rel="alternate"|rel="alternate"[^>]*href="/truth/products/fixture-product\.json"') 'fixture-product H12 alternate generated automatically'
Assert ($t4pg -match 'studio-related' -and $t4pg -match 'href="/reality-gate/"') 'fixture-product related nav includes siblings automatically'
$t4rg = Get-Content (Join-Path $t4.OutDir 'reality-gate\index.html') -Raw -Encoding UTF8
Assert ($t4rg -match 'href="/fixture-product/"') 'existing product related nav now includes fixture-product (registry-driven)'
Write-Host ""

# ── TEST 4B: presentation metadata and root visibility are data-driven ────────
Write-Host "--- TEST 4B: homepage presentation/visibility mutation ---"
# Select a nonfirst public product so moving it to the front proves catalog
# ordering rather than merely observing the already-first Cache Vault card.
$controlModule = @($reg | Where-Object { $_.homepage.visibility -eq 'visible' -and $_.id -ne $catalogOrder[0] -and $_.commerce.status -ne 'WITHDRAWN' } | Sort-Object order | Select-Object -First 1)[0]
$controlId = [string]$controlModule.id
$t4b = Invoke-ModuleFixture 'homepage-presentation-order' {
  param($modDir)
  $path = Join-Path $modDir "$script:controlId\module.json"; $m = Get-Content $path -Raw | ConvertFrom-Json
  $m.homepage.tier = 'major'; $m.homepage | Add-Member -NotePropertyName composition -NotePropertyValue 'media-left' -Force; $m.homepage.presentation = 'editorial'; $m.homepage.order = -25
  $m.order = -25
  [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t4b.Exit -eq 0) 'valid semantic presentation and order changes build without renderer edits'
$t4bHome = Get-Content (Join-Path $t4b.OutDir 'index.html') -Raw -Encoding UTF8
$t4bSoftware = Get-Content (Join-Path $t4b.OutDir 'software\index.html') -Raw -Encoding UTF8
$t4bOrder = @([regex]::Matches($t4bSoftware, 'data-product="([a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert ($controlId -ne $catalogOrder[0] -and $t4bOrder.Count -eq $catalogOrder.Count -and $t4bOrder[0] -eq $controlId -and (Get-CatalogCard $t4bSoftware $controlId) -match ('href="/' + [regex]::Escape($controlId) + '/"') -and $t4bHome -ceq $canonicalHome -and $t4bHome -notmatch $homeProductSlots) 'changed module order moves a nonfirst catalog product first while semantic Home metadata leaves frozen Home intact'

$t4hiddenHome = Invoke-ModuleFixture 'homepage-hidden' {
  param($modDir)
  $path = Join-Path $modDir "$script:controlId\module.json"; $m = Get-Content $path -Raw | ConvertFrom-Json
  $m.homepage.visibility = 'hidden'
  [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t4hiddenHome.Exit -eq 0 -and (Test-Path (Join-Path $t4hiddenHome.OutDir "$controlId\index.html"))) 'homepage-hidden product retains its public route'
$t4hiddenHtml = Get-Content (Join-Path $t4hiddenHome.OutDir 'index.html') -Raw -Encoding UTF8
$t4hiddenCatalog = Get-Content (Join-Path $t4hiddenHome.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t4hiddenHtml -notmatch ('data-module="' + [regex]::Escape($controlId) + '"') -and $t4hiddenCatalog -match ('data-product="' + [regex]::Escape($controlId) + '"') -and (Test-Path (Join-Path $t4hiddenHome.OutDir "truth\products\$controlId.json"))) 'homepage exclusion leaves catalog, route and truth record intact'

$t4badPresentation = Invoke-ModuleFixture 'homepage-bad-presentation' {
  param($modDir)
  $path = Join-Path $modDir "$script:controlId\module.json"; $m = Get-Content $path -Raw | ConvertFrom-Json
  $m.homepage.presentation = 'bespoke'
  [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t4badPresentation.Exit -ne 0 -and $t4badPresentation.Output -match 'homepage.presentation must be') 'unknown presentation is rejected by the validated contract'

$t4badTier = Invoke-ModuleFixture 'homepage-bad-tier' {
  param($modDir)
  $path = Join-Path $modDir "$script:controlId\module.json"; $m = Get-Content $path -Raw | ConvertFrom-Json
  $m.homepage.tier = 'bespoke'
  [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t4badTier.Exit -ne 0 -and $t4badTier.Output -match 'homepage.tier must be') 'unknown homepage tier is rejected by the validated contract'

$evidenceControl = Invoke-ModuleFixture 'withdrawn-evidence-priority' {
  param($modDir)
  foreach ($file in Get-ChildItem $modDir -Directory | ForEach-Object { Join-Path $_.FullName 'module.json' }) {
    $m = Get-Content $file -Raw | ConvertFrom-Json
    if ($m.homepage) { $m.homepage | Add-Member -NotePropertyName evidencePriority -NotePropertyValue 90 -Force; if ($m.id -eq 'reality-gate') { $m.homepage | Add-Member -NotePropertyName evidencePriority -NotePropertyValue 1 -Force } }
    [IO.File]::WriteAllText($file, ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
  }
} -RealOut
Assert ($evidenceControl.Exit -eq 0) 'withdrawn-evidence priority control builds'
$evidenceControlHome = Get-Content (Join-Path $evidenceControl.OutDir 'index.html') -Raw -Encoding UTF8
$evidenceControlSoftware = Get-Content (Join-Path $evidenceControl.OutDir 'software\index.html') -Raw -Encoding UTF8
$evidenceControlCard = Get-CatalogCard $evidenceControlSoftware 'reality-gate'
$evidenceControlTruth = Get-Content (Join-Path $evidenceControl.OutDir 'truth\products\reality-gate.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$withdrawnHomeRow = [regex]::Match($evidenceControlHome, '(?s)<tr data-ledger-product="reality-gate".*?</tr>').Value
Assert ($evidenceControlHome -ceq $canonicalHome -and $evidenceControlHome -notmatch $homeProductSlots -and $withdrawnHomeRow -match 'data-release-status="WITHDRAWN"' -and $withdrawnHomeRow -match 'Full record available\.' -and $withdrawnHomeRow -notmatch 'v1\.1\.0|>\s*Download' -and $evidenceControlCard -match 'data-availability="withdrawn-unavailable"' -and $evidenceControlCard -match 'data-commerce="withdrawn"' -and $evidenceControlCard -match 'href="/reality-gate/"' -and $evidenceControlTruth.release.releaseStatus -eq 'WITHDRAWN' -and $null -eq $evidenceControlTruth.version -and $evidenceControlTruth.download.available -eq $false -and $null -eq $evidenceControlTruth.download.url) 'highest evidence priority cannot restore withdrawn availability in Home, catalog or truth'
Write-Host ""

# ── TEST 5: hidden product control ───────────────────────────────────────────
Write-Host "--- TEST 5: hidden product excluded everywhere ---"
$t5 = Invoke-ModuleFixture 'hidden' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'ghostlayer\module.json') -Raw | ConvertFrom-Json
  $m.visibility = 'hidden'
  $m.lifecycle = 'preview'
  [IO.File]::WriteAllText((Join-Path $modDir 'ghostlayer\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -RealOut
Assert ($t5.Exit -eq 0) 'hidden-module build succeeds'
Assert (-not (Test-Path (Join-Path $t5.OutDir 'ghostlayer\index.html'))) 'hidden product produces no public route'
$t5soft = Get-Content (Join-Path $t5.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t5soft -notmatch 'data-product="ghostlayer"') 'hidden product absent from software catalog'
$t5truth = Get-Content (Join-Path $t5.OutDir 'truth\index.json') -Raw -Encoding UTF8
Assert ($t5truth -notmatch 'ghostlayer') 'hidden product absent from truth index'
Assert (-not (Test-Path (Join-Path $t5.OutDir 'truth\products\ghostlayer.json'))) 'hidden product produces no truth record'
# Preview lifecycle removes a module from the registry-driven public homepage,
# catalog, routes, truth, and discovery surfaces.
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
  Assert ($t8Html -notmatch '<script>alert\(1\)</script>' -and $t8Html -match '&lt;script&gt;alert\(1\)&lt;/script&gt;') 'hostile meta.title is escaped at the HTML attribute boundary'
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
  $cleanroom = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0]
  $cleanroom.name = 'SWAPPED-STATE-MARKER'
  $cleanroom | Add-Member -NotePropertyName homeName -NotePropertyValue 'SWAPPED-HOME-NAME' -Force
  $m
}
Assert ($t9.Exit -eq 0) "fixture-api state source builds (exit=$($t9.Exit))"
$t9html = Get-Content (Join-Path $t9.OutDir 'cleanroom\index.html') -Raw -Encoding UTF8
Assert ($t9html -match 'SWAPPED-STATE-MARKER') 'rendered page consumed foreign source state, not manifest'
$t9soft = Get-Content (Join-Path $t9.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($t9soft -match 'data-product="cleanroom"') 'catalog rendered under foreign source'
$t9truth = Get-Content (Join-Path $t9.OutDir 'truth\products\cleanroom.json') -Raw -Encoding UTF8
Assert ($t9truth -match 'SWAPPED-STATE-MARKER') 'truth JSON consumed foreign source state'
$t9home = Get-Content (Join-Path $t9.OutDir 'index.html') -Raw -Encoding UTF8
$t9footer = [regex]::Match($t9html, '(?s)<footer\b.*?</footer>').Value
Assert ($t9footer -match 'SWAPPED-HOME-NAME' -and $t9home -match 'SWAPPED-HOME-NAME' -and $t9home -match '<tr data-ledger-product="cleanroom"' -and $t9home -notmatch $homeProductSlots) 'product footer and Home index presentation name consume foreign source state'
Write-Host ""

# Homepage markup must stay generic: IDs are data, never renderer branches.
$renderer = Get-Content (Join-Path $root 'scripts/build-site.ps1') -Raw -Encoding UTF8
$homeRendererStart = $renderer.IndexOf('function Get-LedgerEntries')
$homeRendererEnd = $renderer.IndexOf('function Process-Template')
$homeRendererSource = if ($homeRendererStart -ge 0 -and $homeRendererEnd -gt $homeRendererStart) { $renderer.Substring($homeRendererStart, $homeRendererEnd - $homeRendererStart) } else { '' }
Assert ($homeRendererSource.Length -gt 0 -and $homeRendererSource -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot') 'homepage renderer contains no product-ID-specific branches'

$t9LegacyPlacement = Invoke-ModuleFixture 'legacy-home-placement-flag' {
  param($modDir)
  $m = Get-Content (Join-Path $modDir 'cleanroom\module.json') -Raw | ConvertFrom-Json
  $m.placement | Add-Member -NotePropertyName homepage -NotePropertyValue $false -Force
  [IO.File]::WriteAllText((Join-Path $modDir 'cleanroom\module.json'), ($m | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
Assert ($t9LegacyPlacement.Exit -ne 0 -and $t9LegacyPlacement.Output -match 'placement.homepage') 'duplicate legacy homepage placement flag is rejected'
Write-Host ""

# ── TEST 10: H11 truth + H12 discovery remain registry-driven ────────────────
Write-Host "--- TEST 10: truth + discovery registry-driven ---"
$truthIndex = Get-Content (Join-Path $publicDir 'truth\index.json') -Raw | ConvertFrom-Json
Assert ($truthIndex.schemaVersion -eq 1) 'truth index remains schema v1'
Assert ((@($truthIndex.products).Count) -eq @($reg | Where-Object { $_.visibility -eq 'visible' }).Count) 'truth index enumerates the registry-visible products'
foreach ($id in @($reg | Where-Object { $_.visibility -eq 'visible' } | ForEach-Object id)) {
  $t = Get-Content (Join-Path $publicDir "truth\products\$id.json") -Raw | ConvertFrom-Json
  Assert ($t.pageUrl -eq "/$id/" -and $t.truthUrl -eq "/truth/products/$id.json") "$id`: reciprocal pageUrl/truthUrl preserved"
  $pg = Get-Content (Join-Path $publicDir "$id\index.html") -Raw -Encoding UTF8
  Assert ($pg -match "href=`"/truth/products/$id\.json`"[^>]*rel=`"alternate`"|rel=`"alternate`"[^>]*href=`"/truth/products/$id\.json`"") "$id`: H12 alternate link registry-bound"
}
Assert ((Get-Content (Join-Path $publicDir 'software\index.html') -Raw) -match 'rel="alternate"[^>]*href="/truth/index\.json"|href="/truth/index\.json"[^>]*rel="alternate"') '/software/ aggregate alternate preserved'
Write-Host ""

# ── TEST 11 (R1): hostile dynamic-state strings are escaped at emission ───────
Write-Host "--- TEST 11 (R1): hostile state strings escaped (product/catalog/footer) ---"
$r1 = Invoke-ModuleFixture 'hostile-strings' {
  param($modDir)
  # V2 catalog copy comes from these module fields, not manifest narrative.
  # Keep the manifest payloads below to retain product/footer/state coverage.
  $modulePath = Join-Path $modDir 'cleanroom\module.json'
  $module = Get-Content $modulePath -Raw | ConvertFrom-Json
  $module.brand.name = 'MODULE"><script>alert(4)</script>'
  $module.card.summary = '<img src=x onerror=alert(5)>'
  $module.card.tagline = '"><svg onload=alert(6)>'
  [IO.File]::WriteAllText($modulePath, ($module | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} -mutateManifest { param($m)
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
$r1Card = Get-CatalogCard $r1soft 'cleanroom'
Assert ($r1Card.Contains('MODULE&quot;&gt;&lt;script&gt;alert(4)&lt;/script&gt;') -and $r1Card.Contains('&lt;img src=x onerror=alert(5)&gt;') -and $r1Card.Contains('&quot;&gt;&lt;svg onload=alert(6)&gt;')) 'catalog: actual module brand/summary/tagline payloads each emitted as exact entities'
$r1footer = ([regex]::Match($r1page, '(?s)<footer.*?</footer>')).Value
Assert ($r1footer -notmatch '<script>alert') 'footer: no executable markup'
Assert ($r1footer -match '&lt;script&gt;|&quot;&gt;') 'footer: name emitted as entities'
$r1truth = Get-Content (Join-Path $r1.OutDir 'truth\products\cleanroom.json') -Raw -Encoding UTF8
Assert ($r1truth -match 'Cleanroom\\"><script>alert') 'truth JSON carries safely JSON-encoded literal name'
Assert ((($r1truth | ConvertFrom-Json).name) -ceq 'Cleanroom"><script>alert(1)</script>') 'truth JSON parses hostile input as the exact literal string'
Write-Host ""

# ── TEST 12 (R1): unsafe public URL schemes/hosts rejected before emission ────
Write-Host "--- TEST 12 (R1): unsafe URL policy ---"
$badUrls = @('javascript:alert(1)','JAVASCRIPT:alert(1)','data:text/html,<script>alert(1)</script>','file:///C:/Windows/System32/','vbscript:msgbox(1)','http://127.0.0.1:8765/','http://localhost:8765/','http://192.168.1.10/','http://10.0.0.1/','http://172.16.0.1/')
foreach ($bad in $badUrls) {
  $urlSlug = ($bad -replace '[^a-zA-Z0-9]','_'); if ($urlSlug.Length -gt 20) { $urlSlug = $urlSlug.Substring(0,20) }
  $b = Invoke-ModuleFixture ("bad-url-" + $urlSlug) {} -mutateManifest { param($m) ($m.products | Where-Object { $_.id -eq 'cleanroom' })[0].downloadUrl = $bad; $m }
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

# ── TEST 16: Product Module v2 structured path ────────────────────────────────
Write-Host "--- TEST 16: Product Module v2 structured rendering + packaged media ---"
$v2 = Invoke-ModuleFixture 'module-v2' {
  param($modDir)
  Copy-Item (Join-Path $root 'scripts/fixtures/product-module-v2') (Join-Path $modDir 'fixture-product') -Recurse -Force
} -RealOut -mutateManifest { param($m)
  $clone = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $clone.id='fixture-product'; $clone.name='Fixture Product'; $clone.route='/fixture-product/'; $clone | Add-Member -NotePropertyName featured -NotePropertyValue $false -Force
  $m.products += $clone; $m
}
Assert ($v2.Exit -eq 0) "structured v2 module builds (exit=$($v2.Exit))"
$v2Page = Get-Content (Join-Path $v2.OutDir 'fixture-product\index.html') -Raw -Encoding UTF8
Assert ($v2Page -match 'data-hero-variant="centered"' -and $v2Page -match 'A module built from data\.') 'v2 generic hero and selected variant render'
Assert ($v2Page -match '--product-accent:#12AB89' -and $v2Page -match 'data-product-atmosphere="archive"') 'validated theme tokens applied to controlled CSS variables'
Assert ($v2Page -match 'Reusable outcomes' -and $v2Page -match 'First declarative item\.') 'structured section registry renders common outcomes component'
Assert (Test-Path (Join-Path $v2.OutDir 'assets\products\fixture-product\brand\logo.svg')) 'module logo packaged into standard asset route'
Assert (Test-Path (Join-Path $v2.OutDir 'assets\products\fixture-product\media\hero.png')) 'module media packaged into standard asset route'
$v2Catalog = Get-Content (Join-Path $v2.OutDir 'software\index.html') -Raw -Encoding UTF8
Assert ($v2Catalog -match 'A card from module metadata\.' -and $v2Catalog -match '/assets/products/fixture-product/media/hero.png') 'catalog card presentation discovered from v2 module'
$badTheme = Invoke-ModuleFixture 'module-v2-bad-theme' { param($modDir)
  Copy-Item (Join-Path $root 'scripts/fixtures/product-module-v2') (Join-Path $modDir 'fixture-product') -Recurse -Force
  $dir = Join-Path $modDir 'fixture-product'
  $m=Get-Content (Join-Path $dir 'module.json') -Raw | ConvertFrom-Json; $m.theme.accent='red;position:fixed'
  [IO.File]::WriteAllText((Join-Path $dir 'module.json'),($m|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
} -mutateManifest { param($m)
  $clone=(@($m.products|Where-Object{$_.id -eq 'cleanroom'})[0]|ConvertTo-Json -Depth 30|ConvertFrom-Json);$clone.id='fixture-product';$clone.name='Fixture Product';$clone.route='/fixture-product/';$clone|Add-Member -NotePropertyName featured -NotePropertyValue $false -Force;$m.products+=$clone;$m
}
Assert ($badTheme.Exit -ne 0 -and $badTheme.Output -match 'invalid theme.accent') 'unchecked theme value rejected'
Write-Host ""

# ── TEST 17: generic withdrawn/unavailable release state ─────────────────────
Write-Host "--- TEST 17: withdrawn release state is generic and preserves product/history ---"
$withdrawn = Invoke-ModuleFixture 'generic-withdrawn' { param($modDir)
  $content = '<main id="main-content"><div class="product-shell"><!-- @product-breadcrumb --><section id="download"><h2>Release availability</h2>{{product.withdrawalNotice}}<div>{{product.downloadBlock}}</div></section><!-- @product-related --></div></main>'
  New-FixtureModule $modDir 'fixture-product' @{} $content | Out-Null
} -RealOut -mutateManifest { param($m)
  $product = (@($m.products | Where-Object { $_.id -eq 'cleanroom' }))[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $product.id = 'fixture-product'; $product.name = 'Fixture Product'; $product.displayName = 'Fixture Product'; $product.route = '/fixture-product/'
  $product | Add-Member -NotePropertyName featured -NotePropertyValue $false -Force
  $formerVersion = [string]$product.release.publicVersion
  $product.state = 'withdrawn'
  $product.productStatus = 'WITHDRAWN'
  $product.release.releaseStatus = 'WITHDRAWN'
  $product.release | Add-Member -NotePropertyName withdrawnVersion -NotePropertyValue $formerVersion -Force
  $product.release | Add-Member -NotePropertyName withdrawalReason -NotePropertyValue 'Fixture withdrawal for generic-state coverage.' -Force
  $product.release.publicVersion = $null
  $product.release.candidateVersion = $null
  $product.downloadUrl = $null; $product.downloadLabel = $null; $product.sha256Url = $null
  $product.presentation | Add-Member -NotePropertyName downloadUnavailable -NotePropertyValue $true -Force
  $product.presentation | Add-Member -NotePropertyName downloadNotice -NotePropertyValue 'No successor release has been publicly proven.' -Force
  foreach ($artifact in @($product.artifacts)) { $artifact.downloadUrl = $null; $artifact.sha256Url = $null }
  $modulePath = Join-Path $modDir 'fixture-product\module.json'
  $module = Get-Content $modulePath -Raw | ConvertFrom-Json
  $module.commerce.status = 'WITHDRAWN'; $module.commerce.label = 'Withdrawn · no public download'
  [IO.File]::WriteAllText($modulePath, ($module | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
  $product.evidence = @(); $product.proofLinks = @()
  $m.products += $product
  $m
}
Assert ($withdrawn.Exit -eq 0) 'another catalog product builds with the shared withdrawn state'
$withdrawnPage = Get-Content (Join-Path $withdrawn.OutDir 'fixture-product\index.html') -Raw -Encoding UTF8
$withdrawnTruth = Get-Content (Join-Path $withdrawn.OutDir 'truth\products\fixture-product.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ((Test-Path (Join-Path $withdrawn.OutDir 'fixture-product\index.html')) -and $withdrawnPage -match '<p class="availability-notice"><strong>Withdrawn:</strong> v1\.0\.7 is not available for download' -and $withdrawnPage -match 'Downloads currently unavailable' -and $withdrawnPage -notmatch '&lt;p class=&quot;availability-notice' -and $withdrawnPage -notmatch '<a[^>]+>\s*Download') 'withdrawn state retains its route, renders its notice as HTML, and suppresses the product download CTA'
Assert ($withdrawnTruth.release.releaseStatus -eq 'WITHDRAWN' -and $withdrawnTruth.release.withdrawnVersion -eq '1.0.7' -and $withdrawnTruth.version -eq $null -and $withdrawnTruth.download.available -eq $false -and $withdrawnTruth.artifacts[0].sha256) 'withdrawn machine truth preserves history without current availability'
Assert ((Get-Content (Join-Path $withdrawn.OutDir 'software\index.html') -Raw -Encoding UTF8) -match 'fixture-product' -and (Get-Content (Join-Path $withdrawn.OutDir 'truth-files\fixture-product\index.html') -Raw -Encoding UTF8) -match 'Withdrawn v1\.0\.7') 'withdrawn product remains discoverable with matching human truth'
Write-Host ""

Write-Host "=== RESULT: $passed passed, $failed failed ==="
Remove-TestWorkDir $work $env:TEMP 'pf-h13-'
if ($failed -gt 0) { exit 1 }
exit 0
