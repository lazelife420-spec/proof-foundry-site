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

Assert-Home 'foundry stylesheet layers are linked with a content version' ($homeHtml -match 'href="/pf-foundry-system\.css\?v=[0-9a-f]{12}"')
Assert-Home 'generated signature stylesheet contains the workbench system' ($css -match '\.signature-home \.product-theater')
# CP-0189 restores the approved forged-metal identity: machined emblem in the
# header and on the homepage plate, engraved route-chain nav, and the approved
# software directory for product discovery.
Assert-Home 'Foundry identity is present in the opening composition' ($homeHtml -match 'brand-lockup' -and $homeHtml -match 'PF_MARK_G_TI_HEADER\.webp')
Assert-Home 'homepage emblem plate is present' ($homeHtml -match 'pf-emblem' -and $homeHtml -match 'PF_MARK_G_TI_460\.webp')
Assert-Home 'real Cache Vault catalog art is present' ($catalogHtml -match 'cv-quick-paste-card-960\.png')
Assert-Home 'Cache Vault directory entry leads to its product details' ($catalogHtml -match 'data-directory-entry="cache-vault"' -and $catalogHtml -match 'href="/cache-vault/"')
Assert-Home 'software catalog uses the approved directory framing' ($catalogHtml -match 'Find your way in\.')
Assert-Home 'Reality Gate retains a foundry-systems record entry' ($catalogHtml -match 'data-directory-entry="reality-gate"')
Assert-Home 'all product identities remain discoverable' (@('Reality Gate','Cache Vault','Lights Out','Cleanroom','GhostLayer','ForgeCast','ProofShot' | ForEach-Object { $catalogHtml -match [regex]::Escape($_) } | Where-Object { -not $_ }).Count -eq 0)
Assert-Home 'directory entries expose availability metadata' (([regex]::Matches($catalogHtml, 'data-availability=')).Count -ge 9)
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
