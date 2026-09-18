# Focused regression checks for the signature homepage source/output contract.
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homePath = Join-Path $public 'index.html'
$cssPath = Join-Path $public 'signature.css'
$jsPath = Join-Path $public 'experience.js'

if (-not (Test-Path $homePath)) { throw "Generated homepage missing: $homePath" }
if (-not (Test-Path $cssPath)) { throw "Generated signature stylesheet missing: $cssPath" }
if (-not (Test-Path $jsPath)) { throw "Generated experience script missing: $jsPath" }

$homeHtml = Get-Content $homePath -Raw -Encoding UTF8
$catalogHtml = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$css = Get-Content $cssPath -Raw -Encoding UTF8
$js = Get-Content $jsPath -Raw -Encoding UTF8
$pass = 0
$fail = 0

function Assert-Home([string]$name, [bool]$condition) {
  if ($condition) {
    $script:pass++
    Write-Host "PASS: $name" -ForegroundColor Green
  } else {
    $script:fail++
    Write-Host "FAIL: $name" -ForegroundColor Red
  }
}

Assert-Home 'signature stylesheet is linked with a content version' ($homeHtml -match 'href="/signature\.css\?v=[0-9a-f]{12}"')
Assert-Home 'generated signature stylesheet contains the workbench system' ($css -match '\.signature-home \.product-theater')
# H9 supersedes the signature theater with editorial scenes and a separate
# catalog. Preserve discovery and authentic media against that new contract.
Assert-Home 'Foundry identity is present in the opening composition' ($homeHtml -match 'h9-studio-chip' -and $homeHtml -match 'PF_MARK_G_MASTER\.svg')
Assert-Home 'real Cache Vault stage is present before enhancement' ($homeHtml -match 'cv-quick-paste\.png')
Assert-Home 'Cache Vault scene leads to its product details' ($homeHtml -match 'href="/cache-vault/"')
Assert-Home 'software catalog uses the broader tool framing' ($catalogHtml -match 'Choose the one for the job\.')
Assert-Home 'Reality Gate retains a major editorial scene' ($homeHtml -match 'class="h9-scene h9-scene-reality" data-product="reality-gate"')
Assert-Home 'all seven product identities remain discoverable' (@('Reality Gate','Cache Vault','Lights Out','Cleanroom','GhostLayer','ForgeCast','ProofShot' | ForEach-Object { $homeHtml -match [regex]::Escape($_) } | Where-Object { -not $_ }).Count -eq 0)
Assert-Home 'all seven software cards expose availability metadata' (([regex]::Matches($catalogHtml, 'class="card-availability"')).Count -eq 7)
Assert-Home 'release-record label is consistent in the footer' ($homeHtml -match '>Release records<')
Assert-Home 'Foundry identity destination remains discoverable' ($homeHtml -match 'href="/about/"')
Assert-Home 'Founders destination remains in shared navigation' ($homeHtml -match 'href="/founders/"')
Assert-Home 'redundant homepage directory strip is removed' ($homeHtml -notmatch 'class="catalog-nav"')
Assert-Home 'image switching uses load-safe fallback logic' ($js -match 'function waitForImage')
Assert-Home 'product-specific film destinations are bounded' (($js -match '"/cache-vault/#film"') -and ($js -match '"/reality-gate/#film"'))

if ($fail -gt 0) {
  Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
