# H2 — PAGE MATERIAL RHYTHM bounded regression checks.
# Runs against the built output in public/ (run scripts/build-site.ps1 first).
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homePath = Join-Path $public 'index.html'
$cssPath = Join-Path $public 'signature.css'

if (-not (Test-Path $homePath)) { throw "Generated homepage missing: $homePath" }
if (-not (Test-Path $cssPath)) { throw "Generated signature stylesheet missing: $cssPath" }

$homeHtml = Get-Content $homePath -Raw -Encoding UTF8
$css = Get-Content $cssPath -Raw -Encoding UTF8
$pass = 0
$fail = 0

function Assert-H2([string]$name, [bool]$condition) {
  if ($condition) {
    $script:pass++
    Write-Host "PASS: $name" -ForegroundColor Green
  } else {
    $script:fail++
    Write-Host "FAIL: $name" -ForegroundColor Red
  }
}

# --- Material-zone tokens / rules present ---
Assert-H2 'iron/slate catalog floor tokens exist' ($css -match '--pf-iron-floor')
Assert-H2 'warmer forged-field tokens exist' ($css -match '--pf-forge-edge')
Assert-H2 'catalog carries the iron/slate field' ($css -match '(?s)\.signature-home \.studio-catalog \{[^}]*--pf-iron-floor')
Assert-H2 'founders signpost carries the warm forged field' ($css -match '(?s)\.signature-home \.founders-signpost \{[^}]*--pf-forge-edge')
Assert-H2 'card family shares the forged-iron surface' ($css -match '(?s)\.signature-home \.product-card \{[^}]*linear-gradient')
Assert-H2 'Cleanroom pale outlier treatment is gone' ($css -notmatch '#c7d5d1')

# --- Seam / index markers present and sequenced ---
Assert-H2 'catalog index marker PF / 02 present' ($homeHtml -match 'zone-index[^>]*>PF / 02')
Assert-H2 'proof standard index marker PF / 03 present' ($homeHtml -match 'zone-index[^>]*>PF / 03')
Assert-H2 'identity index renumbered PF / 04' ($homeHtml -match 'identity-index">PF / 04')
Assert-H2 'founders index marker PF / 05 present' ($homeHtml -match 'zone-index[^>]*>PF / 05')
Assert-H2 'reassurance PF / 01 marker unchanged' ($homeHtml -match 'reassurance-index">PF / 01')

# --- Released-product media states not empty ---
$cardImgs = [regex]::Matches($homeHtml, 'catalog-image-link"[^>]*>\s*<img src="(?<src>/assets/[^"]+)" alt="(?<alt>[^"]+)"')
Assert-H2 'seven catalog cards carry imagery slots (6 grid + featured handled separately)' ($cardImgs.Count -ge 6)
$releasedIds = @('lights-out', 'cleanroom', 'ghostlayer')
foreach ($rid in $releasedIds) {
  $cardBlock = [regex]::Match($homeHtml, "(?s)product-card card-$rid.*?</article>").Value
  $hasImg = $cardBlock -match 'catalog-image-link" href="[^"]+"[^>]*>\s*<img src="/assets/studio/[^"]+"'
  $imgEmpty = $cardBlock -match '<img src=""' -or $cardBlock -match 'catalog-image-link[^>]*>\s*</a>'
  Assert-H2 "$rid media frame carries real imagery" ($hasImg -and -not $imgEmpty)
}
$proofshotBlock = [regex]::Match($homeHtml, '(?s)product-card card-proofshot.*?</article>').Value
Assert-H2 'ProofShot pre-release frame uses the workbench capture deliberately' ($proofshotBlock -match 'workbench-home' -and $proofshotBlock -match 'data-availability="no-public-release-yet"')

# --- Naming consistency (homepage-facing only) ---
Assert-H2 'homepage card/footer labels use Lights Out (not Lights Out PC)' ($homeHtml -notmatch 'Lights Out PC' -and $homeHtml -match 'Lights Out')
Assert-H2 'homepage card/footer labels use ForgeCast (not ForgeCast Weather)' ($homeHtml -notmatch 'ForgeCast Weather' -and $homeHtml -match 'ForgeCast')
$lightsOutPage = Get-Content (Join-Path $public 'lights-out/index.html') -Raw -Encoding UTF8
$forgecastPage = Get-Content (Join-Path $public 'forgecast/index.html') -Raw -Encoding UTF8
Assert-H2 'canonical Lights Out PC naming preserved on its product page' ($lightsOutPage -match 'Lights Out PC')
Assert-H2 'canonical ForgeCast Weather naming preserved on its product page' ($forgecastPage -match 'ForgeCast Weather')

# --- H1 preservation (regression only; H1 remains frozen) ---
Assert-H2 'H1 forged field markup untouched' ($homeHtml -match 'home-forged-field' -and $homeHtml -match 'forged-hero-bg')
Assert-H2 'H1 hero copy untouched' ($homeHtml -match 'Good software\.' -and $homeHtml -match 'On your terms\.')
Assert-H2 'H1 theater controls unchanged (7 products)' (([regex]::Matches($homeHtml, 'data-show-product=')).Count -eq 7)
Assert-H2 'D1 tablet containment override still served' ($css -match '@media \(max-width: 940px\) and \(min-width: 701px\)')
Assert-H2 'H1 hero composition rules intact' ($css -match '(?s)\.signature-home \.studio-home-hero \{[^}]*min-height: 680px')

if ($fail -gt 0) {
  Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
