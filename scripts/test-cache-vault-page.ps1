[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
$passed = 0; $failed = 0
function Check([bool]$ok, [string]$label) {
  if ($ok) { $script:passed++; Write-Host "PASS: $label" }
  else { $script:failed++; Write-Host "FAIL: $label" -ForegroundColor Red }
}
$module = Get-Content (Join-Path $root 'products/cache-vault/module.json') -Raw | ConvertFrom-Json
$content = Get-Content (Join-Path $root 'products/cache-vault/content.html') -Raw
$productPageCss = Get-Content (Join-Path $root 'product-page.css') -Raw
$pagePath = Join-Path $root 'public/cache-vault/index.html'
$page = Get-Content $pagePath -Raw
$truth = Get-Content (Join-Path $root 'public/truth/products/cache-vault.json') -Raw | ConvertFrom-Json
$schema = Get-Content (Join-Path $root 'schemas/product-module-v2.schema.json') -Raw | ConvertFrom-Json
$authorityRegistry = Get-Content (Join-Path $root 'scripts/test-authority-registry.json') -Raw | ConvertFrom-Json
$androidUrl = [regex]::Escape([string]$truth.artifacts[1].downloadUrl)

Check ($module.hero.headline -eq 'Find the clip. Get back to work.' -and $page -match '<h1[^>]*>Find the clip\. Get back to work\.\s*</h1>' -and ([regex]::Matches($page,'<h1\b')).Count -eq 1) 'one clear product promise is rendered as the sole page H1'
Check ($schema.properties.hero.properties.media.properties.mobileSrc.'$ref' -eq '#/$defs/asset' -and $module.hero.media.mobileSrc -eq '/assets/cache-vault/cv-quick-paste-mobile.png' -and $page -match '<picture><source media="\(max-width: 700px\)" srcset="/assets/cache-vault/cv-quick-paste-mobile\.png"/><img src="/assets/cache-vault/cv-quick-paste\.png"') 'responsive hero crop is schema-validated and rendered with a desktop fallback'
Check ($schema.properties.hero.properties.media.properties.anchorId.pattern -eq '^[a-z][a-z0-9-]*$' -and $module.hero.media.anchorId -eq 'quick-paste' -and $page -match '<figure class="app-shot hero-product-shot" id="quick-paste">') 'Quick Paste action resolves to the real hero capture through validated module metadata'
Check (Test-Path (Join-Path $root 'assets/cache-vault/cv-quick-paste-mobile.png')) 'mobile crop asset exists in source'
Check ($content -match 'Website preview · sample clips' -and $content -match 'not connected to the Cache Vault app' -and $page -match 'role="status"') 'interactive vault is explicitly a sample and retains announced status'
Check ($content -match 'pp-story-mobile-stack' -and $page -match 'pp-story-mobile-stack' -and $productPageCss -match 'body\.pp-system \.pp-story \{ grid-template-columns: 1fr; gap: 28px; \}' -and $productPageCss -match 'body\.pp-system \.pp-story-mobile-stack \.story-copy \{ display: contents; \}' -and $productPageCss -match 'body\.pp-system \.pp-story-mobile-stack \.pp-story-evidence-card \{ order: 1; \}') 'mobile cleanup story stacks readable copy and full-column capture before its evidence callout'
Check ($content -match 'id="film"' -and $content.IndexOf('id="try-it"') -lt $content.IndexOf('id="film"') -and $content -match 'preload="none"' -and $page -match 'controls preload="none"') 'authentic silent film follows the product interaction and does not preload media'
Check ($page -match 'id="download"' -and $page -match 'Download v0\.3\.1 \(Windows\)' -and $page -match $androidUrl -and $page -match 'public, release-signed v0\.3\.1 companion APK' -and $page -notmatch 'v0\.2\.1 publication attempt remains on hold') 'public Windows and Android v0.3.1 release links remain accurate'
$releaseSource = [regex]::Escape([string]$truth.release.sourceCommit)
Check ($truth.release.publicVersion -eq '0.3.1' -and $truth.release.companionPublicVersion -eq '0.3.1' -and $null -eq $truth.release.companionCandidateVersion -and $truth.download.sha256 -eq 'd0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45' -and $truth.artifacts[1].sha256 -eq '863f8a5846083cb0372e1046ac1e9363e6203b4880cc2c6a7ca0da8b1b451988' -and $page -match $releaseSource) 'generated page and truth retain distinct v0.3.1 platform digests and source identity'
Check ($page -match 'Safes and Collections' -and $page -match 'Nothing is cleared automatically' -and $page -notmatch '(?i)military.grade|unhackable|encrypted by default|zero.trace') 'organizational Safes and user-reviewed cleanup are described without unsupported security claims'
Check ($page -match 'Optional pairing transfers selected clips directly over local Wi-Fi' -and $page -match 'has not yet been device-proven' -and $page -match 'does not send background telemetry' -and $page -match 'SHA-256 confirms file identity') 'local storage, optional network transfer, telemetry, and checksum limits remain explicit'
Check ($page -match 'Recorded from the v0\.2\.4 Windows release line' -and $page -match 'sample clips only') 'product film stays labeled as a historical v0.2.4 demonstration'
Check ($page -match 'Hosted GitHub CI failed separately' -and $page -match 'debug build' -and $page -match 'shipped APK runtime and paired-PC lane were not device-proven' -and $page -match 'no Reality Gate canonical run') 'qualification limits are not conflated with local tests or published artifacts'
$routes = @('public/cache-vault/index.html','public/proof/index.html','public/truth-files/index.html','public/truth/products/cache-vault.json','public/software/index.html')
$routesExist = @($routes | Where-Object { Test-Path (Join-Path $root $_) }).Count -eq $routes.Count
Check $routesExist 'product, proof, Truth Files, machine-truth, and catalog routes are generated'
$pageAuthority = @($authorityRegistry.authorities | Where-Object { $_.id -eq 'CACHE_VAULT_PAGE' -and $_.script -eq 'test-cache-vault-page.ps1' }).Count -eq 1
Check ($pageAuthority -and $authorityRegistry.qualificationFreeze.name -eq 'PF_WEB_CONTINUOUS_FOUNDRY' -and $authorityRegistry.qualificationFreeze.scriptInventoryCount -eq 25 -and $authorityRegistry.priorQualificationFreezes[0].name -eq 'PF_WEB_REAL_SITE_1' -and $authorityRegistry.qualificationFreeze.historicalReceiptPreserved -eq 'scripts/qualified-source-real-site-1.sha256.txt') 'page gate and current continuous Foundry freeze are registered; historical qualification receipts remain preserved'

Write-Host "CACHE VAULT PAGE: $passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
