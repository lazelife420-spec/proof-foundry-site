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
Assert-Home 'Foundry identity is present in the opening composition' ($homeHtml -match 'home-brand-lockup')
Assert-Home 'real Cache Vault stage is present before enhancement' ($homeHtml -match 'cv-quick-paste-700\.webp')
Assert-Home 'contextual film link is present' ($homeHtml -match 'data-theater-film')
Assert-Home 'catalog heading uses the broader tool framing' ($homeHtml -match 'Find your next tool\.')
Assert-Home 'Reality Gate retains featured hierarchy' ($homeHtml -match 'class="studio-featured" data-product="reality-gate"')
Assert-Home 'all seven product identities remain discoverable' (@('Reality Gate','Cache Vault','Lights Out','Cleanroom','GhostLayer','ForgeCast','ProofShot' | ForEach-Object { $homeHtml -match [regex]::Escape($_) } | Where-Object { -not $_ }).Count -eq 0)
Assert-Home 'all six regular cards expose availability metadata' (([regex]::Matches($homeHtml, 'class="card-availability"')).Count -eq 6)
Assert-Home 'release-record label is consistent in the footer' ($homeHtml -match '>Release records<')
Assert-Home 'Foundry identity section is present' ($homeHtml -match 'id="identity-title"')
Assert-Home 'Founders preview remains secondary' ($homeHtml -match 'class="founders-signpost"')
Assert-Home 'redundant homepage directory strip is removed' ($homeHtml -notmatch 'class="catalog-nav"')
Assert-Home 'image switching uses load-safe fallback logic' ($js -match 'function waitForImage')
Assert-Home 'product-specific film destinations are bounded' (($js -match '"/cache-vault/#film"') -and ($js -match '"/reality-gate/#film"'))

if ($fail -gt 0) {
  Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
