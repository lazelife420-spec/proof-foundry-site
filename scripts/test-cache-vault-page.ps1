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
Check ($page -match 'id="download"' -and $page -match 'Download v0\.2\.4 \(Windows\)' -and $page -match $androidUrl -and $page -match 'v0\.2\.1 remains on hold') 'public Windows and Android release links remain accurate; held Android candidate is not promoted'
$releaseSource = [regex]::Escape([string]$truth.release.sourceCommit)
Check ($truth.release.publicVersion -eq '0.2.4' -and $truth.release.companionPublicVersion -eq '0.2.0' -and $truth.release.companionCandidateVersion -eq '0.2.1' -and $truth.download.sha256 -eq '717ed13efd3d8d4e5a16d4e412ed5be0fd20b0219918f913d7d2b44f021cae7e' -and $page -match $releaseSource) 'generated page and truth retain canonical public versions, digest, and source release identity'
Check ($page -match 'Safes and Collections' -and $page -match 'Nothing is cleared automatically' -and $page -notmatch '(?i)military.grade|unhackable|encrypted by default|zero.trace') 'organizational Safes and user-reviewed cleanup are described without unsupported security claims'
Check ($page -match 'selected text clips and URLs are sent to the paired phone over your local Wi-Fi network' -and $page -match 'does not send background telemetry' -and $page -match 'SHA-256 confirms file identity') 'local storage, optional network transfer, telemetry, and checksum limits remain explicit'
$routes = @('public/cache-vault/index.html','public/proof/index.html','public/truth-files/index.html','public/truth/products/cache-vault.json','public/software/index.html')
$routesExist = @($routes | Where-Object { Test-Path (Join-Path $root $_) }).Count -eq $routes.Count
Check $routesExist 'product, proof, Truth Files, machine-truth, and catalog routes are generated'
$pageAuthority = @($authorityRegistry.authorities | Where-Object { $_.id -eq 'CACHE_VAULT_PAGE' -and $_.script -eq 'test-cache-vault-page.ps1' }).Count -eq 1
Check ($pageAuthority -and $authorityRegistry.qualificationFreeze.name -eq 'PF_WEB_REAL_SITE_2' -and $authorityRegistry.qualificationFreeze.scriptInventoryCount -eq 25 -and $authorityRegistry.priorQualificationFreezes[0].name -eq 'PF_WEB_REAL_SITE_1' -and $authorityRegistry.qualificationFreeze.historicalReceiptPreserved -eq 'scripts/qualified-source-real-site-1.sha256.txt') 'page gate and current Real Site 2 freeze are registered; Real Site 1 source receipt remains preserved'

Write-Host "CACHE VAULT PAGE: $passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
