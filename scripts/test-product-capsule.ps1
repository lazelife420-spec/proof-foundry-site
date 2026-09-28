[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixture = Join-Path $PSScriptRoot 'fixtures/product-capsule-cache-vault'
$importer = Join-Path $PSScriptRoot 'Import-ProductCapsule.ps1'
$builder = Join-Path $PSScriptRoot 'build-site.ps1'
$scaffolder = Join-Path $PSScriptRoot 'New-ProductCapsule.ps1'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$work = Join-Path ([IO.Path]::GetTempPath()) ('proof-capsule-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$passed=0; $failed=0
function Assert([bool]$Condition,[string]$Message) {
  if ($Condition) { $script:passed++; Write-Host "PASS: $Message" }
  else { $script:failed++; Write-Host "FAIL: $Message" -ForegroundColor Red }
}
function Invoke-Pwsh([string]$File,[string[]]$ArgList) {
  $quoted = @($ArgList | ForEach-Object { '"' + ([string]$_).Replace('"','\"') + '"' }) -join ' '
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$script:pwsh
  $info.Arguments='-NoProfile -File "' + $File + '" ' + $quoted
  $info.WorkingDirectory=$script:root
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $process=[Diagnostics.Process]::Start($info)
  $output=$process.StandardOutput.ReadToEnd() + [Environment]::NewLine + $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  return [PSCustomObject]@{ Exit=$process.ExitCode; Output=$output }
}
function Copy-TestCapsule([string]$Name) {
  $destination=Join-Path $script:work $Name
  Copy-Item -LiteralPath $script:fixture -Destination $destination -Recurse
  return $destination
}
function Read-Capsule([string]$Directory) { return Get-Content -LiteralPath (Join-Path $Directory 'product.json') -Raw | ConvertFrom-Json }
function Write-Capsule([string]$Directory,$Document) {
  [IO.File]::WriteAllText((Join-Path $Directory 'product.json'),($Document|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
}

Write-Host '=== PRODUCT CAPSULE V1 ==='
$products=Join-Path $work 'products'
Copy-Item -LiteralPath (Join-Path $root 'products') -Destination $products -Recurse
$sentinelFile=Join-Path $products 'unrelated-preservation-check.txt'
[IO.File]::WriteAllText($sentinelFile,'unrelated')
$manifestHashBefore=(Get-FileHash (Join-Path $root 'site-manifest.json') -Algorithm SHA256).Hash

# Scaffolder creates a clear draft and its placeholders fail import validation.
$starter=Join-Path $work 'new-capsule'
$scaffoldResult=Invoke-Pwsh $scaffolder @('-Id','starter-demo','-Name','Starter Demo','-OutDir',$starter)
Assert ($scaffoldResult.Exit -eq 0 -and (Test-Path (Join-Path $starter 'product.json')) -and (Test-Path (Join-Path $starter 'brand/mark.svg')) -and (Test-Path (Join-Path $starter 'hero/hero.webp')) -and (Test-Path (Join-Path $starter 'screenshots'))) 'scaffolder creates the expected capsule tree'
$starterJson=Read-Capsule $starter
Assert ($starterJson.lifecycle -eq 'draft' -and -not $starterJson.PSObject.Properties['version'] -and -not $starterJson.PSObject.Properties['release']) 'starter has no release truth fields'
Assert ($starterJson.placement.homepageTier -eq 'hidden') 'new capsule defaults to hidden homepage placement'
$placeholderImport=Invoke-Pwsh $importer @('-Path',$starter,'-ProductsRoot',$products)
Assert ($placeholderImport.Exit -ne 0 -and $placeholderImport.Output -match 'placeholder') 'scaffold placeholders fail capsule import'
$whatIfPath=Join-Path $work 'whatif-capsule'
$whatIf=Invoke-Pwsh $scaffolder @('-Id','whatif-demo','-Name','What If','-OutDir',$whatIfPath,'-WhatIf')
Assert ($whatIf.Exit -eq 0 -and -not (Test-Path -LiteralPath $whatIfPath)) 'scaffolder WhatIf performs no writes'

# Import a real-product presentation capsule without creating a manifest record.
$valid=Invoke-Pwsh $importer @('-Path',$fixture,'-ProductsRoot',$products)
$modulePath=Join-Path $products 'cache-vault-capsule-fixture/module.json'
Assert ($valid.Exit -eq 0 -and (Test-Path $modulePath)) 'real-product capsule imports into a v2 module'
$module=Get-Content -LiteralPath $modulePath -Raw | ConvertFrom-Json
Assert ($module.lifecycle -eq 'preview' -and $module.visibility -eq 'hidden' -and -not $module.PSObject.Properties['version']) 'import remains preview-only and invents no release facts'
Assert ($module.commerce.status -eq 'UNAVAILABLE' -and $module.commerce.label -eq 'No public download yet') 'import defaults to a safe non-acquisition state without commercial truth'
Assert ($module.homepage.role -eq 'studioPortfolio' -and $module.homepage.tier -eq 'secondary' -and $module.homepage.presentation -eq 'compact' -and $module.homepage.visibility -eq 'visible' -and -not $module.placement.PSObject.Properties['homepage']) 'capsule placement normalizes into the single module homepage contract'
Assert ((Test-Path (Join-Path $products 'cache-vault-capsule-fixture/logo.svg')) -and (Test-Path (Join-Path $products 'cache-vault-capsule-fixture/media/hero.png')) -and (Test-Path (Join-Path $products 'cache-vault-capsule-fixture/media/screenshots/01.png'))) 'brand, hero, and screenshot assets normalize to module-local paths'
Assert ($valid.Output -match 'Before public eligibility') 'importer prints the remaining publication gate'
Assert ((Get-FileHash (Join-Path $root 'site-manifest.json') -Algorithm SHA256).Hash -eq $manifestHashBefore) 'import leaves canonical manifest unchanged'
$dupe=Invoke-Pwsh $importer @('-Path',$fixture,'-ProductsRoot',$products)
Assert ($dupe.Exit -ne 0 -and $dupe.Output -match 'already exists') 'duplicate ID import is rejected without Force'
$force=Invoke-Pwsh $importer @('-Path',$fixture,'-ProductsRoot',$products,'-Force')
Assert ($force.Exit -eq 0 -and (Test-Path -LiteralPath $sentinelFile)) 'Force replaces only the same module and preserves unrelated files'
$legacyNone=Copy-TestCapsule 'legacy-homepage-none'
$legacyNoneDoc=Read-Capsule $legacyNone; $legacyNoneDoc.id='legacy-hidden-capsule'; $legacyNoneDoc.placement.homepageTier='none'; Write-Capsule $legacyNone $legacyNoneDoc
$legacyNoneResult=Invoke-Pwsh $importer @('-Path',$legacyNone,'-ProductsRoot',$products)
$legacyNoneModule=Get-Content -LiteralPath (Join-Path $products 'legacy-hidden-capsule/module.json') -Raw | ConvertFrom-Json
Assert ($legacyNoneResult.Exit -eq 0 -and $legacyNoneModule.homepage.role -eq 'studioPortfolio' -and $legacyNoneModule.homepage.tier -eq 'secondary' -and $legacyNoneModule.homepage.visibility -eq 'hidden') 'legacy capsule value none normalizes to hidden root visibility'

# Invalid capsules: paths, active SVG, theme, hero, component, extra truth fields.
foreach ($testCase in @(
  @{ Name='unsafe-path'; Change={ param($d) $x=Read-Capsule $d; $x.hero.media='../../outside.png'; Write-Capsule $d $x }; Pattern='safe relative' },
  @{ Name='bad-theme'; Change={ param($d) $x=Read-Capsule $d; $x.theme.accent='red;position:fixed'; Write-Capsule $d $x }; Pattern='Theme colors' },
  @{ Name='bad-hero'; Change={ param($d) $x=Read-Capsule $d; $x.hero.variant='arbitrary'; Write-Capsule $d $x }; Pattern='hero variant' },
  @{ Name='bad-component'; Change={ param($d) $x=Read-Capsule $d; $x.sections[0].type='raw-html'; Write-Capsule $d $x }; Pattern='Unsupported section type' },
  @{ Name='fake-truth'; Change={ param($d) $x=Read-Capsule $d; $x|Add-Member -NotePropertyName version -NotePropertyValue '99.0.0' -Force; Write-Capsule $d $x }; Pattern='unsupported property' }
)) {
  $dir=Copy-TestCapsule $testCase.Name
  & $testCase.Change $dir
  $result=Invoke-Pwsh $importer @('-Path',$dir,'-ProductsRoot',$products)
  Assert ($result.Exit -ne 0 -and $result.Output -match $testCase.Pattern) "$($testCase.Name) is rejected"
}
$unsafeSvg=Copy-TestCapsule 'unsafe-svg'
[IO.File]::WriteAllText((Join-Path $unsafeSvg 'brand/mark.svg'),'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>')
$svgResult=Invoke-Pwsh $importer @('-Path',$unsafeSvg,'-ProductsRoot',$products)
Assert ($svgResult.Exit -ne 0 -and $svgResult.Output -match 'SVG') 'active SVG is rejected'
$unsupported=Copy-TestCapsule 'unsupported-file'
[IO.File]::WriteAllText((Join-Path $unsupported 'bad.exe'),'not an asset')
$unsupportedResult=Invoke-Pwsh $importer @('-Path',$unsupported,'-ProductsRoot',$products)
Assert ($unsupportedResult.Exit -ne 0 -and $unsupportedResult.Output -match 'Unsupported capsule file') 'unsupported capsule files are rejected'
$routeProducts=Join-Path $work 'route-test-products'
Copy-Item -LiteralPath (Join-Path $root 'products') -Destination $routeProducts -Recurse
$routeShadow=Join-Path $routeProducts 'route-shadow-module'
New-Item -ItemType Directory -Path $routeShadow | Out-Null
[IO.File]::WriteAllText((Join-Path $routeShadow 'module.json'),(@{id='route-shadow-module';route='/route-collision-demo/'}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$routeCapsule=Copy-TestCapsule 'duplicate-route'
$routeDoc=Read-Capsule $routeCapsule; $routeDoc.id='route-collision-demo'; Write-Capsule $routeCapsule $routeDoc
$routeResult=Invoke-Pwsh $importer @('-Path',$routeCapsule,'-ProductsRoot',$routeProducts)
Assert ($routeResult.Exit -ne 0 -and $routeResult.Output -match 'Duplicate product id or route') 'duplicate product route is rejected'

# Explicit public request without matching canonical truth is downgraded to preview.
$unlisted=Copy-TestCapsule 'unlisted-public-attempt'
$unlistedDoc=Read-Capsule $unlisted; $unlistedDoc.id='unlisted-capsule-demo'; $unlistedDoc.lifecycle='public-eligible'; Write-Capsule $unlisted $unlistedDoc
$unlistedResult=Invoke-Pwsh $importer @('-Path',$unlisted,'-ProductsRoot',$products)
$unlistedModule=Get-Content -LiteralPath (Join-Path $products 'unlisted-capsule-demo/module.json') -Raw | ConvertFrom-Json
Assert ($unlistedResult.Exit -eq 0 -and $unlistedResult.Output -match 'did not match canonical manifest truth' -and $unlistedModule.lifecycle -eq 'preview' -and $unlistedModule.visibility -eq 'hidden') 'public request without verified manifest truth remains preview'

# A full preview build proves the capsule-to-page/catalog/home-placement round trip.
$out=Join-Path $work 'preview-build'
$buildResult=Invoke-Pwsh $builder @('-ProductsDir',$products,'-PreviewProductId','cache-vault-capsule-fixture','-OutDir',$out,'-TruthCommit',('a'*40),'-TruthTree',('b'*40),'-TruthCommittedAt','2026-01-01T00:00:00+00:00')
Assert ($buildResult.Exit -eq 0) 'capsule preview build succeeds'
if ($buildResult.Exit -ne 0) { Write-Host $buildResult.Output; exit 1 }
$route=Join-Path $out '__preview/cache-vault-capsule-fixture/index.html'
$previewHtml=Get-Content -LiteralPath $route -Raw
$catalogHtml=Get-Content -LiteralPath (Join-Path $out '__preview/software/index.html') -Raw
$homeHtml=Get-Content -LiteralPath (Join-Path $out '__preview/index.html') -Raw
$publicHome=Get-Content -LiteralPath (Join-Path $out 'index.html') -Raw
$publicCatalog=Get-Content -LiteralPath (Join-Path $out 'software/index.html') -Raw
$truth=Get-Content -LiteralPath (Join-Path $out 'truth/index.json') -Raw
Assert ((Test-Path -LiteralPath $route) -and $previewHtml -match 'noindex, nofollow' -and $previewHtml -match 'product-preview') 'preview product route is local-only and noindex'
Assert ($previewHtml -match 'Capture it\. Find it\. Put it to work\.' -and $previewHtml -match 'Multi-Format Capture' -and $previewHtml -match 'Interface capture') 'capsule hero, structured outcomes, and gallery render'
Assert ((Test-Path (Join-Path $out 'assets/products/cache-vault-capsule-fixture/brand/logo.svg')) -and (Test-Path (Join-Path $out 'assets/products/cache-vault-capsule-fixture/media/screenshots/01.png'))) 'imported product assets publish into the preview output'
Assert ($catalogHtml -match 'cache-vault-capsule-fixture' -and $catalogHtml -match 'Open product preview') 'preview catalog discovers the imported module'
Assert ($homeHtml -match 'data-module="cache-vault-capsule-fixture"[^>]*data-presentation="compact"' -and $homeHtml -match 'Capture it\. Find it\. Put it to work\.') 'homepage presentation preview follows normalized module metadata'
Assert (-not (Test-Path (Join-Path $out 'cache-vault-capsule-fixture/index.html')) -and $publicHome -notmatch 'cache-vault-capsule-fixture' -and $publicCatalog -notmatch 'cache-vault-capsule-fixture' -and $truth -notmatch 'cache-vault-capsule-fixture') 'preview product is absent from all production public surfaces'

# Even if a module is manually promoted without canonical truth, a public build fails closed.
$unlistedModulePath=Join-Path $products 'unlisted-capsule-demo/module.json'
$unlistedModule=Get-Content -LiteralPath $unlistedModulePath -Raw | ConvertFrom-Json
$unlistedModule.lifecycle='public-eligible'; $unlistedModule.visibility='visible'
[IO.File]::WriteAllText($unlistedModulePath,($unlistedModule|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
$denied=Invoke-Pwsh $builder @('-ProductsDir',$products,'-OutDir',(Join-Path $work 'denied-build'),'-TruthCommit',('a'*40),'-TruthTree',('b'*40),'-TruthCommittedAt','2026-01-01T00:00:00+00:00')
Assert ($denied.Exit -ne 0 -and $denied.Output -match 'publication gate denied') 'public build denies an unverified/unmanifested module'
Assert ((Get-FileHash (Join-Path $root 'site-manifest.json') -Algorithm SHA256).Hash -eq $manifestHashBefore) 'canonical manifest remains byte-identical after all capsule workflows'
$previewCommand=Invoke-Pwsh (Join-Path $PSScriptRoot 'Preview-Product.ps1') @('-Id','cache-vault','-NoOpen')
$serverMatch=[regex]::Match($previewCommand.Output,'Local server PID: (\d+)')
Assert ($previewCommand.Exit -eq 0 -and $previewCommand.Output -match 'Product preview: http://127\.0\.0\.1:\d+/__preview/cache-vault/' -and $previewCommand.Output -match 'Homepage placement preview') 'one-command preview builds and serves the local route'
if ($serverMatch.Success) { Stop-Process -Id ([int]$serverMatch.Groups[1].Value) -Force -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "=== RESULT: $passed passed, $failed failed ==="
Write-Host "=== fixture workspace: $work ==="
if ($failed -gt 0) { exit 1 }
